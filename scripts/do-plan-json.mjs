// do-plan-json.mjs — parse a /do plan into JSON, deterministically. No LLM.
//
// WHY (2026-08-31): do-engine.js runs with no filesystem access, so it asked an
// LLM agent for "the raw, verbatim content of text/<slug>-todo.md". An LLM will
// not return a 30KB file verbatim — it returned 6.8KB ending "(Full todo text
// continues...)". The guard reading open cycles out of that text saw NONE, and
// four launches burned ~3M subagent tokens building nothing.
//
// The plan is a deterministic fact on disk. Reading it through a probabilistic
// channel is the defect. This is the deterministic channel; the agent's only job
// becomes "run this, paste stdout". Same discipline as do-auto.sh's _remaining(),
// which is grep and has never had this failure.
//
// Exits non-zero and emits NOTHING when the plan is unreadable — a partial plan
// must never read as a runnable one.
import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'

const slug = process.argv[2]
if (!slug) { console.error('usage: do-plan-json.mjs <slug>'); process.exit(2) }

const repo = path.resolve(new URL('../..', import.meta.url).pathname)

// READ THE TODO THE ENGINE WRITES.
//
// do-tick.sh runs inside the plan WORKTREE, so a closed cycle is ticked in
// .do-worktrees/<slug>/text/<slug>-todo.md. This parser read main's copy, where
// those cycles are still `- [ ]` until the branch merges. So a relaunch computed
// openCycles from main and rebuilt work the worktree had already proven --
// measured 2026-09-01: a relaunch of `lifecycle` re-ran C0, C2 and C3 (all three
// closed and committed on do/lifecycle) before it could reach the C1/C5 it was
// launched for.
//
// Same read/write divergence that stalled the engine this morning, one level up:
// the tick and the reader were looking at two different files. The worktree copy
// is the live record while a plan is in flight; main's is the record after merge.
// Prefer the worktree when it exists, and SAY which one was read so a surprising
// openCycles is one line of output away from being explained.
const wtTodo = path.join(repo, '.do-worktrees', slug, 'text', `${slug}-todo.md`)
const mainTodo = path.join(repo, 'text', `${slug}-todo.md`)
const todo = (process.env.DO_PLAN_TODO) || (fs.existsSync(wtTodo) ? wtTodo : mainTodo)
if (!fs.existsSync(todo)) { console.error(`do-plan-json: no such plan: text/${slug}-todo.md`); process.exit(3) }

const t = fs.readFileSync(todo, 'utf8')
const fail = (m) => { console.error(`do-plan-json: ${m}`); process.exit(4) }

const fm = t.match(/^---\n([\s\S]*?)\n---/)
if (!fm) fail('no frontmatter')
const F = fm[1]

// batches: `- [C0, C2]` rows under `batches:`
//
// DEFECT this shape exists to prevent (measured 2026-09-08 on text/ads-loop-todo.md):
// the capture used to be /^batches:\n((?:[ \t]+- \[.*\]\n?)+)/m. A trailing
// `# comment` after the closing `]` is legal YAML and carried by most plans in
// text/ — it leaves text after `]`, so `\n?` matched empty, the `+` quantifier
// stopped at that row, and EVERY batch from there on was dropped. Nothing
// called fail(): the script still exited 0 and still emitted a well-formed
// object. ads-loop parsed as [["C1"…"C9"]] instead of [["C1"…"C9"],["C10"]],
// so /do would have run nine cycles of a ten-cycle plan and reported complete.
//
// Two changes, and the second is the load-bearing one:
//   1. a row may carry a trailing comment and trailing whitespace;
//   2. the block is delimited by INDENTATION (YAML's own rule) and every line
//      inside it must parse — a line that does not is a REFUSAL, never a
//      shorter list. Comment-tolerance alone would leave the next unreadable
//      row failing in exactly the same silent way.
// Blank lines and whole-line `#` comments inside the block are legal and skipped.
// Inline flow style (`batches: [[C0]]`) still yields [] and fails at the
// `no batches:` invariant below, exactly as before.
const BATCH_ROW = /^[ \t]+-[ \t]*\[([^\]]*)\][ \t]*(?:#.*)?$/
const fLines = F.split('\n')
const bStart = fLines.findIndex((l) => /^batches:[ \t]*$/.test(l))
let batches = []
if (bStart >= 0) {
  const rows = []
  const bad = []
  for (let i = bStart + 1; i < fLines.length; i++) {
    const line = fLines[i]
    if (!line.trim()) continue          // blank line inside the block
    if (!/^[ \t]/.test(line)) break     // a column-0 line is the next key: block over
    if (/^[ \t]*#/.test(line)) continue // whole-line comment
    const m = line.match(BATCH_ROW)
    if (m) rows.push(m[1])
    else bad.push(line)
  }
  if (bad.length) {
    fail(
      `\`batches:\` carries ${bad.length} row(s) this parser cannot read. ` +
      'Refusing: a truncated batch list must never read as a complete one. ' +
      `A row is \`- [C1, C2]\` with an optional trailing # comment. First offender: ${JSON.stringify(bad[0])}`,
    )
  }
  batches = rows.map((r) => r.split(',').map((s) => s.trim()).filter(Boolean))
}

// outcome: the kill-switch. A YAML double-quoted scalar carries \" and \\ escapes;
// stripping the outer quotes WITHOUT unescaping leaves a stray backslash that
// JSON.stringify then doubles, emitting invalid JSON (measured: lifecycle-money,
// lifecycle-human, both of whose outcomes contain a quoted grep pattern).
// A YAML scalar may carry a trailing `# comment`, and text/template-todo.md puts one
// on EVERY key a plan copies — `anchor: "" # filled by do-board.sh`,
// `board_workspace: one # where the rows live…`. The old body tested
// `endsWith('"')`, which a commented value fails, so it returned the raw line
// INCLUDING the comment. Measured 2026-09-12: boardAnchor came back as
// `"task:01a0…"   # filled by do-board.sh` and do-board handed that to
// tasks:subtask as `parent`, dying `{"error":"invalid parent"}` — a message that
// never names the anchor. boardWorkspace was worse and silent: the whole comment
// became the workspace name, so rows would be minted somewhere that does not exist.
// A comment starts at `#` only when it is outside quotes and preceded by
// whitespace (or begins the value); inside quotes `#` is data.
function unquote(raw) {
  const q = raw[0]
  if ((q === '"' || q === "'") && raw.length > 1) {
    // walk to the matching close quote; everything after it is comment/whitespace
    for (let i = 1; i < raw.length; i++) {
      if (q === '"' && raw[i] === '\\') { i++; continue }
      if (raw[i] !== q) continue
      if (q === "'" && raw[i + 1] === "'") { i++; continue }   // '' is an escaped quote
      const body = raw.slice(1, i)
      return q === '"' ? body.replace(/\\(["\\])/g, '$1') : body.replace(/''/g, "'")
    }
    return raw   // unterminated quote — hand it back verbatim rather than guess
  }
  // plain scalar: a comment needs leading whitespace, so `a#b` stays `a#b`
  const c = raw.search(/[ \t]#/)
  return (c === -1 ? raw : raw.slice(0, c)).trim()
}
let outcome = ''
const om = F.match(/^outcome:[ \t]*(?:\|[-+]?|>[-+]?)?[ \t]*(.*)$/m)
if (om) {
  if (om[1].trim()) outcome = unquote(om[1].trim())
  else {
    const rest = F.slice(F.indexOf(om[0]) + om[0].length)
    const blk = rest.match(/^\n((?:[ \t]+.*\n?)+)/)
    if (blk) outcome = blk[1].split('\n').map((l) => l.trim()).filter(Boolean).join(' ')
  }
}

// The Status kanban — the same fact do-auto.sh's _remaining() greps.
const openCycles = []
for (const m of t.matchAll(/^[ \t]*- \[[ ~]\] \*{0,2}(C\d+)\*{0,2} —/gm)) {
  if (!openCycles.includes(m[1])) openCycles.push(m[1])
}

// closed + deps — the REAL DAG, so a scheduler can stream instead of marching.
// `batches:` is the author's flattening of this graph into rounds, and a round
// costs its slowest member: a cycle whose own dependencies closed an hour ago
// still waits at the barrier for an unrelated sibling. The edges themselves live
// in the kanban's `state: blocked-on-C1,C2` clause. Emitting them lets the engine
// start a cycle the moment ITS dependencies pass. Same source do-next.sh reads.
const closedCycles = []
for (const m of t.matchAll(/^[ \t]*- \[x\] \*{0,2}(C\d+)\*{0,2} —/gm)) {
  if (!closedCycles.includes(m[1])) closedCycles.push(m[1])
}
const deps = {}
for (const m of t.matchAll(/^[ \t]*- \[[x ~]\] \*{0,2}(C\d+)\*{0,2} —(.*)$/gm)) {
  const d = m[2].match(/blocked-on-([C0-9,]+)/)
  deps[m[1]] = d ? d[1].split(',').map((x) => x.trim()).filter(Boolean) : []
}

// Cycle headers: "## C3 — title  ⚡/★ marker"
const cycles = {}
const heads = [...t.matchAll(/^##[ \t]+(C\d+)[ \t]+—[ \t]+(.+)$/gm)]
heads.forEach((m, i) => {
  const body = t.slice(m.index, i + 1 < heads.length ? heads[i + 1].index : t.length)
  // Repo-relative paths named anywhere in the cycle body — W1's recon list.
  // ALWAYS repo-relative: an absolute path double-prefixes ${WT} downstream, and
  // an LLM asked for "the file list" returns absolute paths about half the time.
  const files = [...new Set(
    [...body.matchAll(/(?<![\w/.-])((?:one\.ie|packages|channels|api|schema|pay|sync|backup|text|\.claude)\/[A-Za-z0-9._\/\[\]-]+\.[a-z]{2,5})/g)]
      .map((f) => f[1].replace(/[.,)`]+$/, '')),
  )]
    // A path is only a recon hint if it EXISTS. Plan prose abbreviates
    // ("api/events.ts" for one.ie/web/src/pages/api/events.ts), and a hint that
    // resolves to nothing sends W1 hunting for a file that was never there.
    // Existence-filtering makes the list self-validating instead of plausible.
    .filter((f) => fs.existsSync(path.join(repo, f)))
    .slice(0, 12)
  cycles[m[1]] = {
    title: m[2].replace(/\s*[⚡★].*$/, '').trim(),
    // schema tier: touches persistent/irreversible shape (same patterns as do-tier.sh)
    schema: /\.tql\b|migrations\/\d|\.sql\b|\.move\b|\.sol\b/.test(body),
    fableMandatory: /\[Fable\s*—\s*mandatory\]/i.test(body),
    files,
  }
})

// Invariants — refuse to emit a plan that cannot be run.
if (!batches.length) fail('frontmatter has no `batches:` — nothing to schedule')
if (!openCycles.length) {
  fail('no open cycles in the Status kanban. Lines must match /^[ \\t]*- \\[[ ~]\\] C<n> — /; ' +
       'a "Batch N  - [ ] C0 — ..." prefix breaks the ^ anchor and hides the cycle')
}
const orphan = batches.flat().filter((c) => !cycles[c])
if (orphan.length) fail(`batches name cycles with no "## Cn —" header: ${orphan.join(', ')}`)
if (!outcome) fail('frontmatter has no `outcome:` kill-switch')

// shared_recon: the author's own explicit file list, existence-checked the same way.
const srm = F.match(/^shared_recon:\n((?:[ \t]+- .*\n?)+)/m)
const sharedRecon = srm
  ? srm[1].trim().split('\n').map((l) => l.replace(/^[\s-]+/, '').trim())
      .filter((f) => f && fs.existsSync(path.join(repo, f)))
  : []

// ── the BOARD CONTRACT ──────────────────────────────────────────────────────
// A plan's cycles and the board's rows are the same work twice, and until this
// block existed nothing joined them: `batches:` held the ordering in markdown,
// D1 held it in `blocks` edges, and they drifted silently.
//
// It matters because `tasks:claim` is BLOCKER-GATED and reads the very `blocks`
// edge `tasks:depend` writes. A plan mirrored onto the board cannot be claimed
// out of order; an unmirrored one hands every agent every cycle at once.
//
// So emit both renderings and let the caller SEE the drift. `boardDrift` names
// every cycle the plan schedules that has no row — the ones invisible to every
// agent but the one running /do. It is reported, never fatal: a plan may be
// deliberately off-board, and a parser that refused would block that.
const anchorM = F.match(/^anchor:[ \t]*(.*)$/m)
const boardAnchor = anchorM ? unquote(anchorM[1].trim()) : ''
const bwM = F.match(/^board_workspace:[ \t]*(.*)$/m)
const boardWorkspace = bwM && bwM[1].trim() ? unquote(bwM[1].trim()) : 'one'

// cycle_rows: either inline flow (`cycle_rows: []`) or a block of
// `  - {cycle: C1, tid: "task:…"}` rows. Tolerant on purpose — this list is
// written back by a script and by hand, and a shape it cannot read must read as
// "no row" (surfaced in boardDrift) rather than crash a plan that is otherwise
// runnable.
const cycleRows = {}
const crStart = fLines.findIndex((l) => /^cycle_rows:[ \t]*$/.test(l))
if (crStart !== -1) {
  for (let i = crStart + 1; i < fLines.length; i++) {
    const l = fLines[i]
    if (!/^[ \t]+-/.test(l)) { if (l.trim() && !/^[ \t]/.test(l)) break; else continue }
    const c = l.match(/cycle:[ \t]*['"]?(C\d+)['"]?/)
    const tid = l.match(/tid:[ \t]*['"]?(task:[0-9a-f]{24})['"]?/)
    if (c && tid) cycleRows[c[1]] = tid[1]
  }
}
const boardDrift = batches.flat().filter((c) => !cycleRows[c])

process.stdout.write(JSON.stringify({
  slug,
  sharedRecon,
  todo: path.relative(repo, todo),
  todoSource: todo === mainTodo ? 'main' : 'worktree',
  worktree: path.join(repo, '.do-worktrees', slug),
  outcome,
  batches,
  boardAnchor,
  boardWorkspace,
  cycleRows,
  boardDrift,
  openCycles,
  closedCycles,
  deps,
  cycles,
  sha256: crypto.createHash('sha256').update(t).digest('hex').slice(0, 16),
}, null, 2) + '\n')
