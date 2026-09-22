#!/usr/bin/env bun
// thread-name-backfill.ts — name the threads that were written before there was a
// name to write.
//
// manifest: monorepo-only  (binds the `one-owners` D1 by name through wrangler and
//                           imports the namer out of one.ie/web/src)
//
// MEASURED 2026-09-13, production D1 `one-owners`: 1042 of 1053 threads in workspace
// `one` and 125 of 132 in `ehc` carry an empty `name`, so the inbox renders their KEY
// (`space:ehc`, `ehc-chairman`) or a hex id. The write door now names every thread it
// mints (lib/threads.ts) — this is the other half, for the rows already written.
//
// IT APPLIES EXACTLY THE SAME FUNCTION THE LIVE PATH DOES — `deriveThreadName` from
// one.ie/web/src/lib/in/thread-name.ts. A backfill with its own naming rules is a
// second vocabulary for the same keys, and the day they disagree nobody can tell
// which row was named by which.
//
// FOUR SAFETIES, and each is a thing that can go wrong once and not be undone:
//   1. DRY RUN IS THE DEFAULT. `--apply` is required to write, and it is not a flag
//      any read-only session should pass.
//   2. It only ever writes `name`. A thread KEY is identity — `listThreads` filters
//      `agent_id = ?` exactly, and rewriting one orphans the conversation.
//   3. `WHERE name IS NULL OR name = ''` appears in the SELECT **and again in the
//      UPDATE**, so a name a human typed between the two is never overwritten, and
//      running it twice changes nothing the second time.
//   4. Batched by `--limit`, one workspace at a time — and the APPLY is a generated
//      SQL FILE (`--out`, chunked by `--chunk`), run with `wrangler … --file`, not
//      one `--command` spawn per row. 411 sequential remote calls is ~15-30 minutes
//      during which a concurrent writer can change a row read in the SELECT above;
//      a handful of file round trips is not. The SQL is generated on a DRY RUN too,
//      so the operator reads statements rather than a description of them, and the
//      ids are written beside it because a rollback cannot be re-derived: run the
//      namer again later and it names rows this pass never touched.
//
// A task thread's name is its TITLE, which no key can supply. Titles come from the
// D1 `entity_meta` overlay (written by tasks:create/subtask/rename) and, for tasks
// created before that landed, from an offline `--titles <file.json>` map of
// `{ "<tid>": "<title>" }`. Rows with neither are COUNTED AND LEFT, never guessed at.
//
// USAGE
//   bun .claude/scripts/thread-name-backfill.ts --slug one                 # dry run
//   bun .claude/scripts/thread-name-backfill.ts --slug one --limit 500
//   bun .claude/scripts/thread-name-backfill.ts --slug one --titles t.json
//   bun .claude/scripts/thread-name-backfill.ts --slug one --out .backfill --chunk 400
//   bun .claude/scripts/thread-name-backfill.ts --slug one --apply         # runs the SQL
//   …add --local to work against the miniflare copy instead of production.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { spawnSync } from 'node:child_process'
import { deriveThreadName, taskIdOf } from '../../one.ie/web/src/lib/in/thread-name.ts'

const DB = 'one-owners'
const WEB = new URL('../../one.ie/web', import.meta.url).pathname

const argv = process.argv.slice(2)
const flag = (name: string, fallback = ''): string => {
  const i = argv.indexOf(`--${name}`)
  return i >= 0 && argv[i + 1] && !argv[i + 1]!.startsWith('--') ? argv[i + 1]! : fallback
}
const has = (name: string) => argv.includes(`--${name}`)

const slug = flag('slug')
const limit = Number(flag('limit', '200'))
const chunk = Number(flag('chunk', '400'))
const outDir = resolve(new URL('../..', import.meta.url).pathname, flag('out', '.backfill'))
const apply = has('apply')
const remote = !has('local')
const titlesFile = flag('titles')

if (!slug || !Number.isFinite(limit) || limit <= 0 || !Number.isFinite(chunk) || chunk <= 0) {
  console.error('usage: bun .claude/scripts/thread-name-backfill.ts --slug <workspace> [--limit N] [--chunk N] [--out DIR] [--titles f.json] [--local] [--apply]')
  process.exit(2)
}

const sq = (s: string) => `'${s.replace(/'/g, "''")}'`

function wrangler(mode: '--command' | '--file', value: string): Array<Record<string, unknown>> {
  const args = ['wrangler', 'd1', 'execute', DB, remote ? '--remote' : '--local', '--json', mode, value]
  const r = spawnSync('bunx', args, { cwd: WEB, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 })
  if (r.status !== 0) {
    // A failed READ must never read as "no rows to name" — that is the shape that
    // turns an outage into a clean-looking pass. Stop instead.
    console.error(r.stderr || r.stdout)
    throw new Error(`d1 command failed (exit ${r.status})`)
  }
  const start = r.stdout.indexOf('[')
  if (start < 0) return []
  const parsed = JSON.parse(r.stdout.slice(start)) as Array<{ results?: Array<Record<string, unknown>> }>
  return parsed[0]?.results ?? []
}

// ── titles ──────────────────────────────────────────────────────────────────
const titles = new Map<string, string>()
if (titlesFile) {
  const raw = JSON.parse(readFileSync(titlesFile, 'utf8')) as Record<string, string>
  for (const [tid, t] of Object.entries(raw)) if (typeof t === 'string' && t.trim()) titles.set(tid, t.trim())
}
// The overlay the live writers mirror to — the same source `tasks:comment` reads.
for (const row of wrangler('--command', `SELECT entity_id, meta FROM entity_meta WHERE workspace_slug = ${sq(slug)}`)) {
  const id = String(row['entity_id'] ?? '')
  if (!id || titles.has(id)) continue
  try {
    const m = JSON.parse(String(row['meta'] ?? '{}')) as Record<string, unknown>
    if (typeof m['title'] === 'string' && m['title'].trim()) titles.set(id, m['title'].trim())
  } catch { /* a malformed overlay row names nothing */ }
}

// ── the nameless ────────────────────────────────────────────────────────────
const rows = wrangler('--command',
  `SELECT id, slug, agent_id, name FROM threads WHERE slug = ${sq(slug)} AND (name IS NULL OR name = '') ORDER BY last_msg_at DESC LIMIT ${limit}`,
)

type Plan = { id: string; key: string | null; name: string; via: string }
const planned: Plan[] = []
const unnamed: Array<{ id: string; key: string | null; why: string }> = []

for (const r of rows) {
  const id = String(r['id'] ?? '')
  const key = r['agent_id'] === null || r['agent_id'] === undefined ? null : String(r['agent_id'])
  if (!id) continue
  if (key && key.startsWith('task:')) {
    // Both stored shapes resolve to one tid, so a `task:task:` row and a `task:` row
    // find the same title.
    const tid = taskIdOf(key)
    const title = titles.get(tid) ?? titles.get(`task:${tid}`) ?? ''
    if (title) planned.push({ id, key, name: title.slice(0, 200), via: 'task title' })
    else unnamed.push({ id, key, why: 'no title for this tid in the overlay or --titles' })
    continue
  }
  const derived = deriveThreadName(key, slug)
  if (derived) planned.push({ id, key, name: derived, via: 'key' })
  else unnamed.push({ id, key, why: key ? 'key shape carries no name' : 'null key — the client derives from the body' })
}

// ── report ──────────────────────────────────────────────────────────────────
console.log(`${apply ? 'APPLY' : 'DRY RUN'} · workspace ${slug} · ${remote ? 'remote' : 'local'} · limit ${limit}`)
console.log(`nameless rows read: ${rows.length}   nameable: ${planned.length}   left unnamed: ${unnamed.length}`)
console.log(`titles available: ${titles.size}`)
console.log('\n── would name (sample) ──')
for (const p of planned.slice(0, 15)) console.log(`  ${p.id}  ${String(p.key ?? '<null>').padEnd(34)} ''  →  '${p.name}'   [${p.via}]`)
if (planned.length > 15) console.log(`  … ${planned.length - 15} more`)
if (unnamed.length) {
  console.log('\n── left unnamed (sample) ──')
  for (const u of unnamed.slice(0, 10)) console.log(`  ${u.id}  ${String(u.key ?? '<null>').padEnd(34)} ${u.why}`)
  if (unnamed.length > 10) console.log(`  … ${unnamed.length - 10} more`)
}

// ── generate the SQL ────────────────────────────────────────────────────────
// ALWAYS, dry run included — the apply runs a FILE, not 411 `--command` spawns,
// and the operator reads the statements before any of them run. The blank
// predicate is repeated in every statement, not only in the SELECT above:
// between the read and the write a human may have named the row, and a backfill
// that clobbers a human is worse than one that leaves an id on screen.
const now = Math.floor(Date.now() / 1000)
const statementFor = (p: Plan) =>
  `UPDATE threads SET name = ${sq(p.name)}, updated_at = ${now}\n` +
  `  WHERE id = ${sq(p.id)} AND (name IS NULL OR name = '');`

mkdirSync(outDir, { recursive: true })
const files: string[] = []
for (let i = 0; i < planned.length; i += chunk) {
  const slice = planned.slice(i, i + chunk)
  const path = `${outDir}/thread-name-${slug}-${String(i / chunk + 1).padStart(3, '0')}.sql`
  writeFileSync(
    path,
    `-- thread-name-backfill · ${slug} · rows ${i + 1}-${i + slice.length} of ${planned.length}\n` +
      `-- Re-runnable: every statement keeps the blank predicate, so a name typed since is never clobbered.\n` +
      `-- Rollback: the ids this pass would write are listed beside this file.\n\n` +
      slice.map(statementFor).join('\n'),
    'utf8',
  )
  files.push(path)
}
// THE ROLLBACK CANNOT BE DERIVED, so it is written down. Re-running the namer
// later would name rows this pass never touched, and could not tell a name this
// wrote from one a human typed afterwards. The id list is the only honest undo.
//
// AND A RUN THAT PLANS NOTHING WRITES NOTHING HERE. Measured 2026-09-13, minutes
// after the real apply: re-running the same command to PROVE idempotence read 8
// nameless rows, planned 0, and truncated the list of the 107 rows the first run had
// just named — the no-op proof destroyed the undo for the work it was proving.
// Recovering it meant parsing the ids back out of the generated `.sql`. An empty
// plan now leaves the file exactly as it is.
const idsPath = `${outDir}/thread-name-${slug}.ids.txt`
if (planned.length) writeFileSync(idsPath, `${planned.map((p) => `${p.id}\t${p.via}\t${p.name}`).join('\n')}\n`, 'utf8')

console.log(`\n── generated SQL (${planned.length} statements, ${files.length} file(s) of ≤${chunk}) ──`)
for (const f of files) console.log(`  ${f}`)
console.log(
  planned.length
    ? `  ${idsPath}   (id, via, name — the rollback's row list)`
    : `  nothing to do — ${idsPath} and any SQL already in ${outDir} were LEFT AS THEY WERE (an earlier pass's rollback list is not this run's to overwrite)`,
)
if (planned.length) {
  console.log('\n  first statement:')
  for (const line of statementFor(planned[0]).split('\n')) console.log(`    ${line.slice(0, 200)}`)
}

if (!apply) {
  console.log('\nDRY RUN — nothing was written to the database. Read the SQL above, then re-run with --apply.')
  console.log(`Rollback after an apply: UPDATE threads SET name = '' WHERE id IN (<the ids in ${idsPath}>);`)
  process.exit(0)
}

// ── write ───────────────────────────────────────────────────────────────────
for (const f of files) {
  wrangler('--file', f)
  console.log(`  ran ${f}`)
}
const after = wrangler('--command',
  `SELECT COUNT(*) AS n FROM threads WHERE slug = ${sq(slug)} AND (name IS NULL OR name = '')`,
)
console.log(`\nran ${files.length} file(s), ${planned.length} guarded statement(s). still nameless in ${slug}: ${after[0]?.['n'] ?? '?'}`)
console.log(`Rollback list: ${idsPath}`)
