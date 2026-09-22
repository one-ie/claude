#!/usr/bin/env bun
// signal-meta-backfill.ts — stamp the envelope onto the rows written before there
// was an envelope to stamp.
//
// manifest: monorepo-only  (binds the `one-owners` D1 by name through wrangler and
//                           imports the shipped parsers out of one.ie/web/src)
//
// WHY THIS EXISTS. `lib/in/speaker.ts`'s `looksSessionPosted` decides whether a
// `staff` row was TYPED by the operator or POSTED by a session through his key, and
// it decides it from prose. Measured 2026-09-13 on the two production dumps: 367
// such rows, 345 machine / 22 human, and the tuned rule still reads 12 of his own 22
// messages as "Claude session". `SignalMeta.machine` states the fact at write time
// and `MessageList.tsx`'s `drawnOf` asks the envelope FIRST — so every row that
// carries one takes the heuristic out of the loop. This is the other half: the rows
// already written. Stamp enough of them and the heuristic becomes scaffolding
// somebody can delete, instead of a permanent component of who-said-what.
//
// THE ONE RULE THAT SHAPES EVERYTHING BELOW: NEVER GUESS A HUMAN.
// A row that matches no machine shape gets NO meta — never `machine:false`. The two
// errors are not equal (speaker.ts says so at length): a machine row left to the
// heuristic is the status quo, while a HUMAN row stamped `machine:true` is the
// operator's own words filed under a bot's name, permanently, in the one surface he
// reads most — and `drawnOf` would then refuse to let any later tuning reach it.
// Abstention is always available and always cheap.
//
// IT REUSES THE SHIPPED PARSERS, it does not re-implement them:
//   `parseTaskAnnounce`  (one.ie/web/src/lib/chat/task-refs.ts)
//   `classifyMessage`    (one.ie/web/src/lib/chat/message-shapes.ts)
//   `readSignalMeta`     (one.ie/web/src/lib/signal-meta.ts) — the real read gate
// A third copy of "what does this body look like" is exactly the drift this repo
// keeps paying for. The four residual shapes the two parsers do not cover live in
// RULES below, in this file, because they are backfill evidence and not a rendering
// rule — nothing in `src/` should grow a branch for them.
//
// WHAT A STAMPED ROW LOOKS LIKE, and how it is told apart from a live one:
// every envelope this script writes carries `backfill: "signal-meta-backfill@1"`.
// `SignalMeta` does not declare that key and every reader is an allow-list
// extraction, so it is inert to the UI — and it is the exact predicate a rollback
// needs. `source` names the receiver ONLY where the body states it unambiguously
// (a bare announce IS `tasks:announce`'s own output); every other row's source is
// the backfill itself, because inferring a write door from a body shape is a guess
// and this file does not make guesses it cannot show.
//
// THE WRITE IS ONE BATCHED FILE, NOT 567 SPAWNS. The first cut ran one
// `wrangler d1 execute --command` per row: ~15-30 minutes of sequential remote calls
// against a live table, and every one of those minutes is a window in which a
// concurrent writer changes a row that was read in a paged SELECT. The apply now
// GENERATES SQL to disk (`--out`, chunked by `--chunk`) and runs each chunk with
// `--file`, so the whole pass is a handful of round trips and the operator can read
// the statements before any of them run. The generation happens on a DRY RUN too —
// that is the point of it.
//
// AND THE STATEMENT PATCHES, IT DOES NOT REPLACE. `json_set(content_json, '$.meta',
// json('…'))` adds one key to whatever the row holds AT THE MOMENT THE WRITE RUNS, so
// a message edited between the read and the apply keeps its edit — where a statement
// carrying the whole re-serialised body would silently overwrite it. The cost is that
// SQLite re-serialises the JSON (compact, key order preserved); the values do not
// change, the bytes may.
//
// SAFETIES, each one a thing that cannot be undone twice:
//   1. DRY RUN IS THE DEFAULT. `--apply` is required to run the generated SQL.
//   2. THE GUARDS ARE IN THE WHERE CLAUSE, not in this process's memory:
//      `json_type(content_json) = 'object' AND json_extract(content_json,'$.meta') IS
//      NULL`. Re-running the same file is a no-op; a row a live writer stamped first
//      is skipped, never clobbered.
//   3. A row that already carries a readable envelope is never even planned — the
//      live writer's fact always outranks a derived one.
//   4. Every derived envelope is round-tripped through the REAL `readSignalMeta`
//      before it is counted. A derivation the reader would discard is reported as
//      discarded, never as a row this script "would fix".
//   5. Every stamped row carries `meta.backfill`, and the ids are written beside the
//      SQL, so the rollback names exactly the rows this pass touched.
//
// USAGE
//   bun .claude/scripts/signal-meta-backfill.ts                     # dry run, every workspace
//   bun .claude/scripts/signal-meta-backfill.ts --slug one          # one workspace
//   bun .claude/scripts/signal-meta-backfill.ts --limit 500 --max 2000
//   bun .claude/scripts/signal-meta-backfill.ts --out .backfill --chunk 400
//   bun .claude/scripts/signal-meta-backfill.ts --slug one --apply  # runs the generated SQL
//   …add --local to work against the miniflare copy instead of production.

import { spawnSync } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { normalizeTid, parseTaskAnnounce } from '../../one.ie/web/src/lib/chat/task-refs.ts'
import { classifyMessage } from '../../one.ie/web/src/lib/chat/message-shapes.ts'
import { readSignalMeta, type SignalMeta } from '../../one.ie/web/src/lib/signal-meta.ts'
import { looksSessionPosted } from '../../one.ie/web/src/lib/in/speaker.ts'
import { taskIdOf } from '../../one.ie/web/src/lib/in/thread-name.ts'

const DB = 'one-owners'
const WEB = new URL('../../one.ie/web', import.meta.url).pathname
const STAMP = 'signal-meta-backfill@1'

const argv = process.argv.slice(2)
const flag = (name: string, fallback = ''): string => {
  const i = argv.indexOf(`--${name}`)
  return i >= 0 && argv[i + 1] && !argv[i + 1]!.startsWith('--') ? argv[i + 1]! : fallback
}
const has = (name: string) => argv.includes(`--${name}`)

const slug = flag('slug')
const limit = Number(flag('limit', '500'))
const max = Number(flag('max', '0'))
const chunk = Number(flag('chunk', '400'))
const outDir = resolve(new URL('../..', import.meta.url).pathname, flag('out', '.backfill'))
const apply = has('apply')
const remote = !has('local')

if (!Number.isFinite(limit) || limit <= 0 || !Number.isFinite(max) || max < 0 || !Number.isFinite(chunk) || chunk <= 0) {
  console.error('usage: bun .claude/scripts/signal-meta-backfill.ts [--slug <workspace>] [--limit N] [--max N] [--chunk N] [--out DIR] [--local] [--apply]')
  process.exit(2)
}

const sq = (s: string) => `'${s.replace(/'/g, "''")}'`

function wrangler(mode: '--command' | '--file', value: string): Array<Record<string, unknown>> {
  const args = ['wrangler', 'd1', 'execute', DB, remote ? '--remote' : '--local', '--json', mode, value]
  const r = spawnSync('bunx', args, { cwd: WEB, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 })
  if (r.status !== 0) {
    // A failed READ must never read as "no rows to stamp" — that is the shape that
    // turns an outage into a clean-looking pass. Stop instead.
    console.error(r.stderr || r.stdout)
    throw new Error(`d1 command failed (exit ${r.status})`)
  }
  const start = r.stdout.indexOf('[')
  if (start < 0) return []
  const parsed = JSON.parse(r.stdout.slice(start)) as Array<{ results?: Array<Record<string, unknown>> }>
  return parsed[0]?.results ?? []
}

// ── the evidence ─────────────────────────────────────────────────────────────
// Each rule answers one question: does this row carry a structure that only a
// machine writes? Ordered most-specific first; the first match wins and the rest
// are not consulted, so a bare announce is never also counted as prose.

interface Row {
  id: string
  ws: string
  key: string | null
  content: string
}

interface Stored {
  text: string
  tags?: string[]
  sender?: string
  authorKind?: string
  meta?: unknown
}

interface Verdict {
  rule: string
  meta: SignalMeta & { backfill: string }
}

/** The dotted kind vocabulary `notifyActor` already writes — one word per shape. */
function envelope(kind: string, source: string, rest: Partial<SignalMeta> = {}): SignalMeta & { backfill: string } {
  return { v: 1, kind, source, machine: true, ...rest, backfill: STAMP }
}

/**
 * `[<kind>] <text>` — `notifyActor` (resolvers/messaging.ts:411) prefixes every
 * notify whose kind is not the bare word `message`, and it is reachable ONLY from a
 * server call site, never from a composer. The kind is dotted there
 * (`kind.replace(/[:\-]+/g, '.')`) and dotted here, so a backfilled notify and a
 * live one land in one vocabulary. The bracket must open the body and hold one
 * lowercase word — a prose sentence that happens to contain a bracket is not this.
 */
const NOTIFY_LEAD = /^\[([a-z][a-z0-9:_-]{1,40})\]\s/

/** `/do close — <slug>` — written by do-signal.sh:348 through the comment door. */
const DO_CLOSE = /^\/do\s+(close|cycle|wave)\b/

/** Bare words only — a namespaced tag matches zero subscribers, so it is dropped. */
const bare = (tags: readonly string[]) => tags.filter((t) => !t.includes(':'))

function verdictFor(row: Row, stored: Stored): Verdict | null {
  const body = stored.text.trim()
  // Both key shapes collapse to one tid, and the subject carries the SAME prefixed
  // form `parseTaskAnnounce` produces — two rules naming one task two ways is the
  // drift this file is trying not to add.
  const tid = row.key && taskIdOf(row.key) ? normalizeTid(row.key) : ''

  // The remote-origin marker sits on the ROW, not in the prose. It is the LAST rule
  // rather than the first, and that ordering is the whole finding of the first dry
  // run: it fired on 93 rows in `ehc` that are bare announces, and the envelope it
  // wrote carried no subject, no title and no tags. A row's origin is the weakest
  // thing you can say about it — say it only when nothing stronger is true.
  const originOnly = stored.tags?.some((t) => t.startsWith('untrusted'))
    ? { rule: 'untrusted-tag', meta: envelope('remote', `backfill:${STAMP}`, { ...(bare(stored.tags ?? []).length ? { tags: bare(stored.tags ?? []) } : {}) }) }
    : null

  if (!body) return originOnly

  // The announce door's own output: a tag-path header and nothing but `k: v` lines.
  // `parseTaskAnnounce` returns null for anything with a line of prose in it, so
  // this cannot fire on a person quoting an announce.
  const announce = parseTaskAnnounce(body)
  if (announce) {
    return {
      rule: 'task-announce',
      meta: envelope('task.announce', 'tasks:announce', {
        subject: { type: 'task', id: announce.tid, ...(announce.title ? { title: announce.title } : {}) },
        ...(bare(announce.tags).length ? { tags: bare(announce.tags) } : {}),
      }),
    }
  }

  const shape = classifyMessage(body)
  if (shape.kind === 'triage') {
    return {
      rule: 'triage-receipt',
      meta: envelope('triage', `backfill:${STAMP}`, {
        ...(tid ? { subject: { type: 'task' as const, id: tid, ...(shape.to ? { title: shape.to } : {}) } } : {}),
      }),
    }
  }
  if (shape.kind === 'status') {
    return {
      rule: 'status-post',
      meta: envelope('status', `backfill:${STAMP}`, {
        actor: { id: shape.who, kind: 'agent' },
        ...(tid ? { subject: { type: 'task' as const, id: tid } } : {}),
      }),
    }
  }

  const notify = body.match(NOTIFY_LEAD)
  if (notify) {
    return { rule: 'notify-line', meta: envelope(notify[1].replace(/[:_-]+/g, '.'), 'notify') }
  }

  if (DO_CLOSE.test(body)) {
    return {
      rule: 'do-close',
      meta: envelope('close', `backfill:${STAMP}`, { ...(tid ? { subject: { type: 'task' as const, id: tid } } : {}) }),
    }
  }

  // Nothing in the body matched. The row's own origin marker is all that is left,
  // and where there is not one either this is the abstention the file exists for.
  return originOnly
}

// ── the read ─────────────────────────────────────────────────────────────────

const where = slug ? `WHERE t.slug = ${sq(slug)}` : ''
const rows: Row[] = []
for (let offset = 0; ; offset += limit) {
  const page = wrangler('--command',
    `SELECT m.id AS id, t.slug AS ws, t.agent_id AS key, m.content_json AS content
       FROM messages m JOIN threads t ON t.id = m.thread_id
       ${where}
       ORDER BY m.ts DESC LIMIT ${limit} OFFSET ${offset}`,
  )
  for (const r of page) {
    rows.push({
      id: String(r['id'] ?? ''),
      ws: String(r['ws'] ?? ''),
      key: r['key'] === null || r['key'] === undefined ? null : String(r['key']),
      content: String(r['content'] ?? ''),
    })
  }
  if (page.length < limit) break
  if (max && rows.length >= max) break
}

// ── the classification ───────────────────────────────────────────────────────

interface Planned extends Verdict {
  row: Row
  body: string
}

const planned: Planned[] = []
const byRule = new Map<string, number>()
const byWorkspace = new Map<string, { read: number; stamped: number }>()
let alreadyMeta = 0
let notAnObject = 0
let discardedByReader = 0
let abstained = 0
// Comparison only, never a decision: how the prose heuristic would have read the
// same rows. Reported so the gap between "stated" and "guessed" is a number.
let heuristicSaysMachine = 0
let contestedCohort = 0
/** The only cohort worth reading by hand: rows this script claims and the prose rule does not. */
const disputed: Array<{ id: string; ws: string; rule: string; body: string }> = []

for (const row of rows) {
  const ws = byWorkspace.get(row.ws) ?? { read: 0, stamped: 0 }
  ws.read++
  byWorkspace.set(row.ws, ws)

  let stored: Stored | null = null
  try {
    const parsed = JSON.parse(row.content) as unknown
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed) && 'text' in (parsed as Record<string, unknown>)) {
      const o = parsed as Record<string, unknown>
      stored = {
        text: String(o['text'] ?? ''),
        ...(Array.isArray(o['tags']) ? { tags: (o['tags'] as unknown[]).map(String) } : {}),
        ...(typeof o['sender'] === 'string' ? { sender: o['sender'] } : {}),
        ...(typeof o['authorKind'] === 'string' ? { authorKind: o['authorKind'] } : {}),
        meta: o['meta'],
      }
    }
  } catch {
    stored = null
  }
  // An array-of-parts or a bare string row has no object to put `meta` on — the
  // reader looks for `content_json.meta` and nowhere else, so writing one here
  // would change the row's shape as well as its content. Left alone.
  if (!stored) { notAnObject++; continue }
  if (readSignalMeta(stored.meta)) { alreadyMeta++; continue }

  const contested = stored.authorKind === 'staff'
  if (contested) {
    contestedCohort++
    if (looksSessionPosted(stored.text)) heuristicSaysMachine++
  }

  const verdict = verdictFor(row, stored)
  if (!verdict) { abstained++; continue }
  // THE READER IS THE JUDGE. A derivation `readSignalMeta` discards is not a row
  // this script would fix — it is a row it would write meta into that nothing reads.
  if (!readSignalMeta(verdict.meta)) { discardedByReader++; continue }

  planned.push({ ...verdict, row, body: stored.text })
  byRule.set(verdict.rule, (byRule.get(verdict.rule) ?? 0) + 1)
  ws.stamped++
  if (contested && !looksSessionPosted(stored.text)) disputed.push({ id: row.id, ws: row.ws, rule: verdict.rule, body: stored.text })
}

// ── report ───────────────────────────────────────────────────────────────────

const one = (s: string, n = 84) => {
  const t = s.replace(/\s+/g, ' ').trim()
  return t.length > n ? `${t.slice(0, n - 1)}…` : t
}

console.log(`${apply ? 'APPLY' : 'DRY RUN'} · ${slug ? `workspace ${slug}` : 'every workspace'} · ${remote ? 'remote' : 'local'} · page ${limit}${max ? ` · max ${max}` : ''}`)
console.log(`rows read: ${rows.length}`)
console.log(`  already carry a readable envelope: ${alreadyMeta}   (never touched)`)
console.log(`  content_json is not an object:     ${notAnObject}   (no place to put one)`)
console.log(`  matched no machine shape:          ${abstained}   (ABSTAINED — no meta, never machine:false)`)
console.log(`  derived but the reader discards:   ${discardedByReader}`)
console.log(`  WOULD STAMP:                       ${planned.length}`)

console.log('\n── by rule ──')
for (const [rule, n] of [...byRule.entries()].sort((a, b) => b[1] - a[1])) console.log(`  ${rule.padEnd(18)} ${n}`)

console.log('\n── by workspace ──')
for (const [ws, n] of [...byWorkspace.entries()].sort((a, b) => b[1].stamped - a[1].stamped)) {
  if (!n.stamped && !slug) continue
  console.log(`  ${ws.padEnd(16)} read ${String(n.read).padStart(5)}   would stamp ${String(n.stamped).padStart(5)}`)
}

console.log('\n── against the heuristic this replaces (comparison only — it decides nothing) ──')
console.log(`  authorKind staff rows read:                 ${contestedCohort}`)
console.log(`  …looksSessionPosted would call MACHINE:     ${heuristicSaysMachine}`)
console.log(`  …this script states machine:true:           ${[...byWorkspace.values()].reduce((a, b) => a + b.stamped, 0)} (all rows, not only staff)`)
console.log(`  staff rows stamped where the heuristic says HUMAN: ${disputed.length}`)
console.log('  (the last line is the only risky cohort: a row this script claims and the prose rule does not.')
console.log('   every one of them is printed below, in full-ish, so the decision is made on the rows and not on a count.)')
for (const d of disputed) console.log(`    ${d.id}  ${d.ws.padEnd(12)} [${d.rule}] ${d.body.replace(/\s+/g, ' ').trim().slice(0, 180)}`)

console.log('\n── sample: before → after (5 per rule) ──')
for (const rule of byRule.keys()) {
  const sample = planned.filter((p) => p.rule === rule).slice(0, 5)
  console.log(`\n  [${rule}]`)
  for (const p of sample) {
    console.log(`    ${p.row.id}  ${p.row.ws}`)
    console.log(`      body : ${one(p.body)}`)
    console.log(`      meta : ${one(JSON.stringify(p.meta), 160)}`)
  }
}

// ── generate the SQL ─────────────────────────────────────────────────────────
// ALWAYS, dry run included. The operator decides by reading statements, not a
// description of statements.

/**
 * One statement per row. `json_set` PATCHES the row as it stands at write time —
 * it never carries the body back, so a message edited between the read and the
 * apply keeps its edit. The two guards live in the WHERE clause, which is what
 * makes re-running the file a no-op and a row a live writer stamped first untouched.
 */
const statementFor = (p: Planned) =>
  `UPDATE messages SET content_json = json_set(content_json, '$.meta', json(${sq(JSON.stringify(p.meta))}))\n` +
  `  WHERE id = ${sq(p.row.id)} AND json_type(content_json) = 'object' AND json_extract(content_json, '$.meta') IS NULL;`

const scope = slug || 'all'
mkdirSync(outDir, { recursive: true })
const files: string[] = []
for (let i = 0; i < planned.length; i += chunk) {
  const slice = planned.slice(i, i + chunk)
  const path = `${outDir}/signal-meta-${scope}-${String(i / chunk + 1).padStart(3, '0')}.sql`
  writeFileSync(
    path,
    `-- signal-meta-backfill ${STAMP} · ${scope} · rows ${i + 1}-${i + slice.length} of ${planned.length}\n` +
      `-- Re-runnable: every statement carries its own guard. Rollback predicate:\n` +
      `--   json_extract(content_json, '$.meta.backfill') = '${STAMP}'\n\n` +
      slice.map(statementFor).join('\n'),
    'utf8',
  )
  files.push(path)
}
// The id list beside the SQL, so a rollback names the rows this pass touched
// instead of re-deriving them from a rule that may have moved since.
//
// A RUN THAT PLANS NOTHING WRITES NOTHING HERE. Measured 2026-09-13, minutes after
// the real apply: re-running the same command to PROVE idempotence planned 0 rows,
// and this line truncated the rollback list of the 195 rows the first run had just
// stamped — the no-op proof destroyed the undo for the work it was proving. The
// guards held in the database and the evidence died on disk, which is the worse half
// to lose. An empty plan now leaves the file exactly as it is.
const idsPath = `${outDir}/signal-meta-${scope}.ids.txt`
if (planned.length) writeFileSync(idsPath, `${planned.map((p) => `${p.row.id}\t${p.row.ws}\t${p.rule}`).join('\n')}\n`, 'utf8')

console.log(`\n── generated SQL (${planned.length} statements, ${files.length} file(s) of ≤${chunk}) ──`)
for (const f of files) console.log(`  ${f}`)
console.log(
  planned.length
    ? `  ${idsPath}   (id, workspace, rule — the rollback's row list)`
    : `  nothing to do — ${idsPath} and any SQL already in ${outDir} were LEFT AS THEY WERE (an earlier pass's rollback list is not this run's to overwrite)`,
)
if (planned.length) {
  console.log('\n  first statement:')
  for (const line of statementFor(planned[0]).split('\n')) console.log(`    ${one(line, 200)}`)
}

if (!apply) {
  console.log('\nDRY RUN — nothing was written to the database. Read the SQL above, then re-run with --apply.')
  console.log(`Rollback after an apply: the rows are listed in ${idsPath}, and every one carries`)
  console.log(`  json_extract(content_json, '$.meta.backfill') = '${STAMP}'  —  remove with`)
  console.log(`  UPDATE messages SET content_json = json_remove(content_json, '$.meta')`)
  console.log(`    WHERE json_extract(content_json, '$.meta.backfill') = '${STAMP}';`)
  process.exit(0)
}

// ── write ────────────────────────────────────────────────────────────────────
// One round trip per FILE, not per row. The per-row form measured ~15-30 minutes
// of sequential remote calls for this corpus, and every minute of it was a window
// in which a concurrent writer could change a row read in an earlier page.

for (const f of files) {
  wrangler('--file', f)
  console.log(`  ran ${f}`)
}
console.log(`\nran ${files.length} file(s), ${planned.length} guarded statement(s). Rollback list: ${idsPath}`)
