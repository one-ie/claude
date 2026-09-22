#!/usr/bin/env node
// classification: portable
// Red proof for factory-executor.js — the trace, the slug and the close.
//
// WHY THIS IS DIFFERENT FROM factory-review-check.mjs: that checker defines OLD
// and NEW as two inline string copies and never opens the executor, so it stays
// green whether or not the file is fixed. It proves a shape. THIS one READS THE
// FILE for every assertion, and lifts the two behavioural tables (slugFor, the
// close status re-parse) OUT of the source with new Function so they cannot
// drift from what ships. Revert any one of the three fixes and this goes red.
//
// Usage:  node .claude/scripts/factory-executor-check.mjs [path]
// Exit 0 = all green. Exit 1 = at least one assertion failed.

import { readFileSync } from 'node:fs'

const F = process.argv[2] || '.claude/workflows/factory-executor.js'
const src = readFileSync(F, 'utf8')

const fails = []
function check(name, pass, detail) {
  if (!pass) fails.push(name)
  console.log(`  ${pass ? ' ok ' : 'RED '}  ${name}${detail ? `  — ${detail}` : ''}`)
}

// Lift a `const <name> = ...` block out of the source by balanced braces, so the
// behavioural tables below exercise THE FILE and not a copy of it.
function lift(startPat) {
  const i = src.search(startPat)
  if (i < 0) return null
  const open = src.indexOf('{', i)
  if (open < 0) return null
  let depth = 0
  for (let j = open; j < src.length; j++) {
    if (src[j] === '{') depth++
    else if (src[j] === '}') { depth--; if (depth === 0) return src.slice(i, j + 1) }
  }
  return null
}

console.log(`factory-executor-check: ${F}\n`)

// ── 1. THE TRACE — the emit is issued at both boundaries of all six stages ──
//
// ON THE NUMBER: the brief asked for "12 factory-emit.sh occurrences". That is
// the plan's RUNTIME boundary count per job (6 stages × start/end, minus Ready's
// start, minus Prove's when the review refutes, plus the repair's build+review
// pair) mis-stated as a static grep. Statically there is exactly ONE
// `factory-emit.sh` literal — inside the emitStage helper — and N emitStage CALL
// SITES. Inlining the curl twelve times to satisfy a grep would reintroduce the
// very divergence the slugFor fix removes: one command, many renderings. So the
// count is reported, and COVERAGE is what is asserted.
console.log('1. the trace — stage emit coverage')

const EMIT_CALL = /emitStage\(\s*[^,]+,\s*'(\w+)'\s*,\s*([\s\S]*?),\s*\{/g

// COVERAGE IS PER CODE PATH, NOT PER STAGE NAME. A union over the stage name
// scores `build` as covered when the MAIN path has lost its fail emit but the
// REPAIR path still carries one — absent evidence defaulting to benign, in the
// checker written to stop that. So each emitting path gets its own lane, keyed
// off the options object: `repair:` (the repair build), `pass: N` (review pass 1
// vs 2), else `main`. Every lane must carry both boundaries.
function optionsAfter(idx) {
  let depth = 0
  for (let j = idx; j < src.length; j++) {
    if (src[j] === '{') depth++
    else if (src[j] === '}') { depth--; if (depth === 0) return src.slice(idx, j + 1) }
  }
  return ''
}
const lanes = new Map()
let m
while ((m = EMIT_CALL.exec(src))) {
  const [, stage, statusExpr] = m
  const opts = optionsAfter(src.lastIndexOf('{', EMIT_CALL.lastIndex))
  const lane = /\brepair:/.test(opts) ? 'repair' : (opts.match(/\bpass:\s*(\d+)/) || [, null])[1] ? `pass${opts.match(/\bpass:\s*(\d+)/)[1]}` : 'main'
  const key = `${stage}:${lane}`
  if (!lanes.has(key)) lanes.set(key, new Set())
  for (const st of (statusExpr.match(/'(start|ok|fail)'/g) || []).map((q) => q.slice(1, -1))) lanes.get(key).add(st)
}

// FAIL CLOSED on a partial parse. If the regex misses a call, coverage would be
// computed from a subset and a missing boundary could read as present-elsewhere.
const rawCalls = (src.match(/emitStage\(/g) || []).length - 1 // minus the definition
const parsedCalls = (src.match(EMIT_CALL) || []).length
check(
  'every emitStage call site was parsed (a partial parse cannot score coverage)',
  rawCalls > 0 && parsedCalls === rawCalls,
  `${parsedCalls} parsed of ${rawCalls} call site(s)`,
)

// The invariant is one EXECUTED rendering, not one mention: the name also
// appears in a comment, a schema description and the operator hint in EMITS
// DARK. What must never be duplicated is the line that BUILDS AND RUNS the
// command — two of those is the slugFor disease with a different subject.
const runSites = (src.match(/factory-emit\.sh \$\{parts\.join/g) || []).length
check('exactly one EXECUTED factory-emit.sh rendering — one command, one builder', runSites === 1,
  `${runSites} executed of ${(src.match(/factory-emit\.sh/g) || []).length} total mention(s) (the rest are comments, a schema description and the DARK hint)`)

// Every lane the pipeline actually has. Named explicitly so a lane that
// DISAPPEARS is red too — a missing key cannot be scored by iterating what is
// present.
const REQUIRED_LANES = [
  ['claim:main', 'the claim'],
  ['build:main', 'the first build'],
  ['build:repair', 'the repair build'],
  ['review:pass1', 'review pass 1'],
  ['review:pass2', 'review pass 2 (after the repair)'],
  ['prove:main', 'the walk'],
  ['close:main', 'the close'],
]
for (const [key, what] of REQUIRED_LANES) {
  const s = lanes.get(key)
  check(`${key}: start + ok + fail  (${what})`, !!s && s.has('start') && s.has('ok') && s.has('fail'), s ? `[${[...s].sort().join(' ')}]` : 'LANE ABSENT')
}
// Ready is the deliberate asymmetry: the read happens BEFORE any tid is known,
// so a per-job `start` would be invented rather than observed.
const ready = lanes.get('ready:main') || new Set()
check('ready: ok, and NO start (a start before any tid is known is invented, not observed)', ready.has('ok') && !ready.has('start'), `[${[...ready].sort().join(' ')}]`)

// A stage that did not run must be ABSENT — there is no `skip` in the vocabulary.
const refutedBranch = lift(/if \(review\.refuted\) \{/)
check('the refuted-review branch emits NO prove frame (absent, never "skipped")', refutedBranch !== null && !refutedBranch.includes('emitStage'))

check('EMITS DARK is keyed on attempts, not only on failures', /emitStats\.pushed === 0/.test(src) && /EMITS DARK/.test(src),
  'zero pushed and zero failed must not read as a clean turn')

// ── 2. THE CLOSE — status is a copy out of a script line, never a belief ────
console.log('\n2. the close — status is read back, not asserted')

const closeSchema = lift(/const CLOSE_SCHEMA = /)
check('CLOSE_SCHEMA exists', closeSchema !== null)
check("CLOSE_SCHEMA requires 'checkLine'", !!closeSchema && /required:\s*\[[^\]]*'checkLine'[^\]]*\]/.test(closeSchema))
check('CLOSE_SCHEMA still requires tagged + status (no field lost)',
  !!closeSchema && /'tagged'/.test(closeSchema) && /'status'/.test(closeSchema))
check('closePrompt tells the agent to run factory-close-check.sh', /factory-close-check\.sh/.test(src))

// A stage agent that THROWS propagates out of the stage; the item is then dropped
// by `out.filter(Boolean)` and lands in NEITHER results NOR skipped — a job that
// built, reviewed and walked disappears from the turn's own summary. Both agents
// that can throw after work has been done must be caught.
check('the Close agent is .catch()-guarded (a thrown Close must not vanish the job)',
  /schema: CLOSE_SCHEMA \}\)\s*\n\s*\.catch\(\(\) => null\)/.test(src))
check('the repair agent is .catch()-guarded (a thrown repair must not leave the row picked with no close)',
  /repairPrompt\(t, b, r1\.findings\)[\s\S]{0,220}?\.catch\(\(\) => null\)/.test(src))

// Lift the executor's OWN four-line derivation and drive it. The first factory
// run is the fixture: task:01a07591e5c350a306c93933 is still `picked` while the
// Close agent returned {"status":"done"}.
const deriveSrc = src.match(/ +const line = c &&[\s\S]*?const status = [^\n]*\n/)
check('the status derivation is present in the file and liftable', deriveSrc !== null)
if (deriveSrc) {
  const NEW = new Function('c', `${deriveSrc[0]}\nreturn status`)
  const OLD = (c) => (c && c.status) || 'unknown' // the pre-fix line
  const cases = [
    ['THE BUG: agent said done, board said picked', { status: 'done', checkLine: 'CLOSE tid=task:01a07591e5c350a306c93933 lane=none verdict=red status=picked' }, 'unverified'],
    ['an honest close: both say done', { status: 'done', checkLine: 'CLOSE tid=x lane=fast verdict=ok status=done' }, 'done'],
    ['the script failed, no CLOSE line', { status: 'unverified', checkLine: 'factory-close-check.sh: row not found' }, 'unverified'],
    ['checkLine absent entirely', { status: 'done' }, 'unverified'],
    ['the close agent was lost', null, 'unverified'],
  ]
  let oldFails = 0, newFails = 0
  for (const [name, input, want] of cases) {
    const o = OLD(input), n = NEW(input)
    if (o !== want) oldFails++
    if (n !== want) newFails++
    console.log(`         ${name.padEnd(46)} want=${String(want).padEnd(11)} OLD=${String(o).padEnd(11)} NEW=${n}${n === want ? '' : '   <-- NEW WRONG'}`)
  }
  check('the pre-fix line fails the cases this fix exists for', oldFails > 0, `OLD: ${oldFails} failure(s) — must be > 0 or the proof is worthless`)
  check("the file's own derivation passes every case", newFails === 0, `NEW: ${newFails} failure(s)`)
}

// ── 3. THE SLUG — one function, zero re-derivations ────────────────────────
console.log('\n3. the slug — one function, no second sanitiser')

check('exactly one slugFor definition', (src.match(/const slugFor\s*=/g) || []).length === 1)
// NOTE THE SCOPING: `${t.tid}` legitimately appears in labels, receiver payloads
// and prompt prose. What must be zero is the RENDERED SLUG — the git/branch/
// worktree/receipt-path shape the first run's builder had to hand-patch.
const rawSlugSites = (src.match(/task-\$\{t\.tid\}/g) || []).length
check('zero raw `task-${t.tid}` renderings in the git/branch/worktree lines', rawSlugSites === 0, `${rawSlugSites} found (was 8 across 6 lines)`)
check('the prompts render the slug through slugFor', (src.match(/\$\{slugFor\(t\.tid\)\}/g) || []).length >= 8)

const slugSrc = lift(/const slugFor = /)
check('slugFor is liftable from the file', slugSrc !== null)
if (slugSrc) {
  const slugFor = new Function(`${slugSrc}\nreturn slugFor`)()
  const cases = [
    // The directory the first run ACTUALLY built in.
    ['task:01a07591e5c350a306c93933', 'task-01a07591e5c350a306c93933', 'the first run’s own tid'],
    ['01a07591e5c350a306c93933', 'task-01a07591e5c350a306c93933', 'a bare id gets the prefix once'],
    ['task/abc', 'task-abc', 'a slash separator'],
    ['task:a b:c', 'task-a-b-c', 'spaces and colons collapse'],
  ]
  let bad = 0
  for (const [tid, want, why] of cases) {
    const got = slugFor(tid)
    if (got !== want) bad++
    console.log(`         slugFor(${JSON.stringify(tid).padEnd(30)}) = ${String(got).padEnd(30)} want ${want}${got === want ? '' : '   <-- WRONG'}   (${why})`)
  }
  check('slugFor maps every case to the directory the walk will be told to check', bad === 0)
  // Empty is a stop, not a default: `task-` shared by N jobs is one worktree,
  // one branch and one receipt for all of them, silently.
  let threw = false
  try { slugFor(':::') } catch { threw = true }
  check('a tid with no slug-safe characters THROWS (it must not collapse to `task-`)', threw)
}

// ── 4. THE ARITHMETIC — one site, and this workstream did not move it ──────
// The hoist is the point: pass 1 and pass 2 must not be able to disagree.
console.log('\n4. the review jury — one arithmetic site, so two passes cannot drift')
const arith = src.match(/const refuted = votes[^\n]*/g) || []
check('exactly one vote-arithmetic site', arith.length === 1, arith.length === 1 ? arith[0].trim() : `${arith.length} sites`)

// ── 5. THE CLOSE STATUS TABLE — the board status the close ASKED FOR ───────
// `closeOk = w.verdict === 'ok' && status !== 'unverified'` accepted ANY board
// status the read-back reported honestly. The shape that got through: a NON-UI
// task, verdict ok, `tasks:status` refused, factory-close-check.sh prints
// `status=picked`, the agent copies `picked`, both words agree → closeOk true →
// close emits `ok` → event.ts writes **workflow:done** on a row the board reads
// `picked`. The expected status is a function of (verdict, t.ui) and is known at
// the call site, so this drives THE FILE's own derivation against that table.
console.log('\n5. the close — expected status is derived from (verdict, ui), and tagged:false is not a close')

// Lifted through `const closeOk`, and it returns ONLY closeOk on purpose: a body
// that returns {status, expectedStatus, tagged} would THROW on the pre-fix file
// (`expectedStatus is not defined`) and the RED rows would arrive as a crash
// instead of as a wrong answer. A crash is not a red proof; a wrong answer is.
const closeSrc = src.match(/ +const line = c &&[\s\S]*?\n +const closeOk = [^\n]*\n/)
check('the closeOk derivation is liftable from the file (a lift miss must be RED, never skipped)', closeSrc !== null)
if (closeSrc) {
  const NEW = new Function('c', 'w', 't', `${closeSrc[0]}\nreturn closeOk`)
  // The pre-fix line, verbatim from a60084d09.
  const OLD = (c, w) => {
    const line = c && typeof c.checkLine === 'string' ? c.checkLine : ''
    const m = /\bstatus=([a-z]+)\b/.exec(line)
    const claimed = (c && typeof c.status === 'string' && c.status) || ''
    const status = m && m[1] === claimed ? m[1] : 'unverified'
    return w.verdict === 'ok' && status !== 'unverified'
  }
  const cl = (st) => ({ status: st, checkLine: `CLOSE tid=x lane=fast verdict=ok status=${st}`, tagged: true })
  const cases = [
    // THE FINDING, as reported: non-UI, walk ok, board still picked.
    ['non-UI ok, board says picked — tasks:status was refused', cl('picked'), { verdict: 'ok' }, { ui: false }, false],
    // A UI task is SUPPOSED to stay picked: a person has not looked yet.
    ['UI ok, board says picked — that is the asked-for status', cl('picked'), { verdict: 'ok' }, { ui: true }, true],
    // tagged:false is tasks:notes refusing — the row carries no lane/verdict.
    ['non-UI ok, board says done, but tagged:false', { status: 'done', checkLine: 'CLOSE tid=x lane=fast verdict=ok status=done', tagged: false }, { verdict: 'ok' }, { ui: false }, false],
    // The honest close, which must stay green or the fix has broken the loop.
    ['non-UI ok, board says done, tagged true', cl('done'), { verdict: 'ok' }, { ui: false }, true],
    // A UI task must never be counted closed on `done`: nobody looked.
    ['UI ok, board says done — nobody looked, so that is wrong too', cl('done'), { verdict: 'ok' }, { ui: true }, false],
    // A red verdict closes `fail` whatever the row says (event.ts: a close ok is
    // workflow:done, so a red that emits ok makes the trace contradict the board).
    ['red verdict, board says picked', cl('picked'), { verdict: 'red' }, { ui: false }, false],
    // `tagged` unsaid is not `tagged:false` — it must not read as a refusal.
    ['non-UI ok, done, tagged unsaid (agent omitted it)', { status: 'done', checkLine: 'CLOSE tid=x lane=fast verdict=ok status=done' }, { verdict: 'ok' }, { ui: false }, true],
    // The original divergence fixture: the words disagree → status unverified.
    ['agent said done, board said picked', { status: 'done', checkLine: 'CLOSE tid=task:01a07591e5c350a306c93933 lane=none verdict=red status=picked', tagged: true }, { verdict: 'ok' }, { ui: false }, false],
    // A lost Close agent: no line, nothing known.
    ['the close agent was lost', null, { verdict: 'ok' }, { ui: false }, false],
  ]
  let oldFails = 0, newFails = 0
  for (const [name, c, w, t, want] of cases) {
    let o, n
    try { o = OLD(c, w) } catch (e) { o = `threw:${e.message}` }
    try { n = NEW(c, w, t) } catch (e) { n = `threw:${e.message}` }
    if (o !== want) oldFails++
    if (n !== want) newFails++
    console.log(`         ${name.padEnd(58)} want=${String(want).padEnd(6)} OLD=${String(o).padEnd(6)} NEW=${n}${n === want ? '' : '   <-- NEW WRONG'}`)
  }
  check('the pre-fix closeOk line fails the rows this fix exists for', oldFails > 0,
    `OLD: ${oldFails} failure(s) — must be > 0 or the proof is worthless`)
  check("the file's own closeOk derivation passes every row", newFails === 0, `NEW: ${newFails} failure(s)`)
}

// The reason line has to NAME the two words, or a `fail` frame is unactionable.
check('the close fail reason names expected vs actual board status',
  /expected \$\{expectedStatus\}/.test(src), 'the frame must say which status it wanted')
check('status, expectedStatus, tagged and closeOk are carried into the result',
  /status, expectedStatus, tagged, closeOk, checkLine: line,/.test(src))
check('the turn line counts closeOk, not the walk verdict',
  /const ok = results\.filter\(\(r\) => r\.closeOk\)\.length/.test(src),
  'a green walk whose close was refused is not an ok job')
check('a walked-ok-but-unclosed job is counted, not lost between ok and red',
  /const held = results\.filter\(\(r\) => r\.verdict === 'ok' && !r\.closeOk\)\.length/.test(src))

// ── 6. THE LOST JURY — zero survivors is not a green review step ───────────
// `runReview` does `.filter(Boolean)`, so a lens that throws leaves lenses:0 —
// and the vote line computes `0 * 2 > Math.max(1, 0)` = false, i.e. NOT refuted
// (measured; a repair-pass finding asserted the opposite). The review emit then
// recorded `step:done` with reason undefined and detail {lenses:0, attempted:1}.
// Fixed at the emit, both passes, without touching the arithmetic (§4).
console.log('\n6. the review emit — a jury with zero survivors emits fail, both passes')

const lostSites = src.match(/'review',\s*r(\d)\.refuted \|\| r\1\.lenses === 0 \? 'fail' : 'ok'/g) || []
check('both review emit sites fail closed on lenses === 0', lostSites.length === 2,
  `${lostSites.length} of 2 site(s) — pass 1 and pass 2 must not disagree about what a lost jury is`)
const lostReasons = src.match(/no lens survived \(\$\{r\d\.attempted\} attempted\)/g) || []
check("the reason names the lost jury — 'no lens survived (N attempted)'", lostReasons.length === 2,
  `${lostReasons.length} of 2 reason(s)`)
// The arithmetic itself FAILS CLOSED: zero survivors ⇒ refuted, `>=` on the tie.
// The previous version of this check asserted the line was UNTOUCHED — a scope
// guard that kept `0*2 > 1` fail-open through two merges on 2026-09-06. The
// behavioural proof lives in factory-review-check.mjs, which lifts this line
// out of the file; here we only assert the fail-open shape is gone.
const arith2 = src.match(/const refuted = votes[^\n]*/g) || []
check('the vote arithmetic fails closed (zero survivors ⇒ refuted; no Math.max(1, …) fail-open shape)',
  arith2.length === 1 && /votes\.length === 0 \? true/.test(arith2[0]) && !/Math\.max\(1, votes\.length\)/.test(arith2[0]),
  arith2[0] || 'no `const refuted = votes…` line found')

// ── 7. THE EMIT CONTRACT — factory-emit.sh takes --detail k=v, not JSON ────
// Measured 2026-09-06 against the merged script: `--detail '{"slug":"x"}'` dies
// `--detail wants k=v` at EXIT 2, because its parser is
// `case "$kv" in *=*)` and a JSON blob carries no `=`. Every emit with a detail
// object — Build, Review, Prove, Close — wrote NO frame and was counted as a
// receiver rejection. A newline inside a value splits the script's own
// newline-joined heredoc and kills the whole emit the same way.
console.log('\n7. the emit contract — read off .claude/scripts/factory-emit.sh')

check('no JSON blob is passed to --detail (the script refuses it, exit 2)',
  !/--detail \$\{shq\(JSON\.stringify/.test(src))
check('--detail is rendered as repeated k=v pairs', /--detail \$\{shq\(`\$\{k\}=\$\{val\}`\)\}/.test(src))
check('detail values are whitespace-collapsed (a newline splits the script\'s heredoc and kills the emit)',
  src.includes("String(v).replace(/\\s+/g, ' ').trim()"))
check('an empty detail value is dropped, not posted as `k=`', /if \(!val\) continue/.test(src))
check('a detail key that would mis-split is dropped BY NAME, not silently',
  /dropped detail key/.test(src))
check('the header comment states the real flag set, not `--detail <json>`',
  /\[--detail k=v\]\.\.\./.test(src) && !/\[--detail <json>\]/.test(src))
check('EMIT_SCHEMA names factory-emit.sh\'s own exit codes', /0 emitted · 2 bad arguments · 3 no credential · 4 the receiver refused/.test(src))

// ── 8. READY — one frame per turn, and the slug guard runs first ───────────
// The emits were pushed one per row, before round 1 and before the slugFor
// guard: `agent()` is eager and these sit outside `parallel`, so a full page
// (200 rows) spawned 200 haiku agents ahead of the barrier that prices memory —
// and a turn about to throw on a malformed tid had already written N `ready ok`
// frames for jobs that never started.
console.log('\n8. ready — one frame per turn, after the slug guard')

const readyCalls = src.match(/emitStage\([^\n]*'ready'[^\n]*/g) || []
check('exactly one ready emit site', readyCalls.length === 1, `${readyCalls.length} site(s)`)
check('the ready emit is NOT inside a per-row loop', readyCalls.length === 1 && !/^for \(/.test(readyCalls[0].trim()),
  readyCalls.length === 1 ? readyCalls[0].trim().slice(0, 80) : 'unparsed')
check('the ready frame carries the row count', readyCalls.length === 1 && /count: tasks\.length/.test(readyCalls[0]))
const guardIdx = src.indexOf('for (const t of tasks) slugFor(t.tid)')
const readyIdx = readyCalls.length === 1 ? src.indexOf(readyCalls[0]) : -1
check('the slugFor guard runs BEFORE the ready emit (a turn that throws must not have emitted first)',
  guardIdx > 0 && readyIdx > guardIdx, `guard@${guardIdx} ready@${readyIdx}`)

// ── 9. THE JURY, DRIVEN — the arithmetic is EXECUTED, not described ────────
// §4 counts the sites and §6 asserts the fail-open SHAPE is gone. Both are
// string reads: they pass on any line that merely looks right. The fail-open
// expression survived two merges on 2026-09-06 under exactly that kind of
// guard, so this lane lifts the two vote lines OUT of the file and RUNS them
// over the two juries the old line got wrong — an empty one (every lens threw)
// and a tied one. `refuted` must be true for both. Absent evidence is a
// refusal, not consent.
console.log('\n9. the jury — the vote arithmetic is executed over the juries it used to acquit')

// A second site would let this lane lift a fail-closed line while a fail-open
// one ships beside it: §4's red would not stop this lane printing ok.
const voteSites = src.match(/const refuted = votes[^\n]*/g) || []
check('exactly one vote-arithmetic site to drive (a second site makes this lane meaningless)',
  voteSites.length === 1, `${voteSites.length} site(s)`)
if (voteSites.length === 1) {
  // The `against` line is SYNTHESISED when absent rather than failing the lift:
  // the pre-fix file is one self-contained line, and a lift miss would report
  // this as "skipped" instead of as the wrong answer it is (the file's own
  // doctrine at §5 — a crash is not a red proof; a wrong answer is).
  const mAgainst = src.match(/ +const against = votes[^\n]*/)
  const mRefuted = src.match(/ +const refuted = votes[^\n]*/)
  const voteSrc = `${mAgainst ? mAgainst[0] : '  const against = votes.filter((v) => v.refuted).length'}\n${mRefuted[0]}`
  let NEW = null
  try { NEW = new Function('votes', `${voteSrc}\nreturn refuted`) } catch (e) {
    check('the lifted vote arithmetic parses', false, e.message)
  }
  if (NEW) {
    // The exact pre-fix expression, kept so the lane proves it can reach RED.
    const OLD = (votes) => votes.filter((v) => v.refuted).length * 2 > Math.max(1, votes.length)
    const R = { refuted: true, findings: ['x'] }
    const A = { refuted: false, findings: [] }
    const juries = [
      ['an empty jury — every lens threw', [], true],
      ['a tied jury — one refutes, one acquits', [R, A], true],
      ['a tied jury — two and two', [R, A, R, A], true],
      ['a unanimous refutation', [R, R], true],
      ['a lone dissenter among three', [R, A, A], false],
      ['a unanimous acquittal', [A, A, A], false],
    ]
    let oldBad = 0
    let newBad = 0
    for (const [why, votes, want] of juries) {
      let o
      let n
      try { o = OLD(votes) } catch { o = 'THREW' }
      try { n = NEW(votes) } catch { n = 'THREW' }
      if (o !== want) oldBad++
      if (n !== want) newBad++
      console.log(`         ${why.padEnd(40)} want=${String(want).padEnd(6)} OLD=${String(o).padEnd(6)} NEW=${String(n)}${n === want ? '' : '   <-- WRONG'}`)
    }
    check('the pre-fix vote line fails the juries this fix exists for', oldBad > 0,
      `OLD: ${oldBad} failure(s) — must be > 0 or the proof is worthless`)
    check('a tied or empty jury is REFUTED — the file\'s own arithmetic, driven', newBad === 0,
      `NEW: ${newBad} failure(s) over ${juries.length} juries`)
  }
}

// ── 10. THE TRUST RATCHET, DRIVEN — the halt decision is EXECUTED ──────────
// A4. The round loop had NO ratchet: `grep -ci 'trust|cautious|halt'` over this
// executor returned 2, and both hits were incidental prose (":167", ":615" —
// "rather than trusting the pair"). A refuted Review left the row `picked` and
// the loop took the next task, forever — a turn could refute every job it built
// and report a clean `turn: N built` line.
//
// This lane does what §9 does, for the ratchet: it LIFTS the two decision consts
// out of the file and RUNS them over synthetic verdict sequences. A string read
// ("the file mentions trust-cautious") would pass on a comment; the fail-open
// vote expression survived two merges under exactly that kind of guard.
//
// WHAT THIS LANE DOES NOT PROVE, stated out loud: the fold below is the
// CHECKER's loop, not the executor's — control flow inside an `await pipeline`
// cannot be driven by `new Function`. So the arithmetic is driven, and the
// WIRING is asserted structurally instead: exactly one call site, INSIDE the
// round loop body, with a `break` on that path. Lift a helper nobody calls and
// the three checks below go red rather than green.
console.log('\n10. the trust ratchet — the halt decision is driven over a run of refuted Reviews')

const streakSites = src.match(/ *const nextRefutedStreak = [^\n]*/g) || []
const floorSites = src.match(/ *const trustCautious = [^\n]*/g) || []
check('exactly one streak-fold site and one floor site to drive (a second site makes this lane meaningless)',
  streakSites.length === 1 && floorSites.length === 1, `${streakSites.length} fold(s), ${floorSites.length} floor(s)`)

// The WIRING. A driven expression in a dead helper is a lane that proves nothing
// about what the turn does — the exact defect §9's first check exists for, in the
// other direction. The call must be inside the round loop and must `break` it.
const roundBody = lift(/for \(let round = 0;/)
// `trustCautious(` matches CALLS only: the declaration reads `const trustCautious = (`,
// with ` = ` between the name and the paren. Subtracting the declaration count here was
// this lane's own first RED — it reported `0 call site(s)` against a wired call.
const callSites = (src.match(/trustCautious\(/g) || []).length
check('the floor is called exactly once, and from INSIDE the round loop', callSites === 1 && !!roundBody && /trustCautious\(/.test(roundBody),
  `${callSites} call site(s), round loop ${roundBody ? 'lifted' : 'NOT FOUND'}`)
check('the halt path BREAKS the round loop and names its reason', !!roundBody && /trustCautious\([\s\S]*?\n {4}break\n/.test(roundBody) && /halt reason=trust-cautious/.test(roundBody),
  roundBody ? undefined : 'round loop not lifted')

// THE INPUT, NOT ONLY THE ARITHMETIC. Everything above drives synthetic booleans;
// nothing above touches how `refuted` is EXTRACTED from a job. The fold reads
// `r.review && r.review.refuted`, and `review` is one key among ten on the close
// stage's result object. Drop it there and `r.review` is undefined, the fold
// scores `false` for every job, the streak never advances — and every check above
// still prints ok. A ratchet reading green while wired to nothing is the exact
// defect this batch exists to remove, so both ends of the wire are asserted.
check('the fold reads the job\'s own review verdict (not a field it invents)',
  !!roundBody && /nextRefutedStreak\(refutedStreak, !!\(r\.review && r\.review\.refuted\)\)/.test(roundBody),
  roundBody ? undefined : 'round loop not lifted')
check('the close stage still carries `review` into the result, so the fold has an input',
  /\n +review, humanBlock:/.test(src),
  'drop this key and the streak silently never advances')

if (streakSites.length === 1 && floorSites.length === 1) {
  let NEW = null
  try {
    NEW = new Function('verdicts', `${streakSites[0]}\n${floorSites[0]}
let streak = 0
for (const refuted of verdicts) { streak = nextRefutedStreak(streak, refuted); if (trustCautious(streak)) return true }
return false`)
  } catch (e) {
    check('the lifted ratchet parses', false, e.message)
  }
  if (NEW) {
    // The pre-fix behaviour, kept so the lane proves it can reach RED. There was
    // no expression to copy — the round loop simply had no halt, so OLD is the
    // honest transcription of that: it never stops, whatever comes back.
    const OLD = () => false
    const runs = [
      ['two refuted Reviews back to back', [true, true], true],
      ['one refuted Review alone — not a pattern', [true], false],
      ['refuted, good, refuted — the streak RESETS', [true, false, true], false],
      ['a good run', [false, false, false], false],
      ['a clean start, then two refuted', [false, true, true], true],
      ['a reset, then two refuted', [true, false, true, true], true],
      ['nothing built at all', [], false],
    ]
    let oldBad = 0
    let newBad = 0
    for (const [why, verdicts, want] of runs) {
      let o
      let n
      try { o = OLD(verdicts) } catch { o = 'THREW' }
      try { n = NEW(verdicts) } catch { n = 'THREW' }
      if (o !== want) oldBad++
      if (n !== want) newBad++
      console.log(`         ${why.padEnd(46)} halt want=${String(want).padEnd(6)} OLD=${String(o).padEnd(6)} NEW=${String(n)}${n === want ? '' : '   <-- WRONG'}`)
    }
    check('the pre-fix round loop — no ratchet at all — fails the runs this fix exists for', oldBad > 0,
      `OLD: ${oldBad} failure(s) — must be > 0 or the proof is worthless`)
    check('two consecutive refuted Reviews halt the round, and one good job resets the streak', newBad === 0,
      `NEW: ${newBad} failure(s) over ${runs.length} runs`)
  }
}

console.log(`\nfactory-executor-check: ${fails.length ? `${fails.length} RED` : 'all green'}`)
if (fails.length) for (const f of fails) console.log(`  RED  ${f}`)
process.exit(fails.length ? 1 : 0)
