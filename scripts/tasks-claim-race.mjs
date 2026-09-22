// tasks-claim-race.mjs — the atomicity proof for tasks:claim. BOTH halves.
//
// Answers, empirically, the one question the whole task-loop design rests on:
// does TypeDB refuse the second of two concurrent guarded claims?
//
// Requires a REAL TypeDB (never mock it — repo rule). Default target is a
// throwaway `racetest` database on a LOCAL server; it never touches `one`.
//
//   docker run -d --name one-tdb-probe -p 8000:8000 typedb/typedb:3.12.1
//   node .claude/scripts/tasks-claim-race.mjs
//
// Exit 0 only when BOTH halves hold:
//   GREEN — the guarded single-pipeline claim: 1 winner, 1 refusal, 1 `@` tag.
//   RED   — the old read-then-decide shape: 2 winners, 2 `@` tags (the bug).
// A checker that cannot demonstrate its own red half is not a checker.
const BASE = process.env.TYPEDB_URL || 'http://127.0.0.1:8000'
const DB = process.env.RACE_DB || 'racetest'
const USER = process.env.TYPEDB_USERNAME || 'admin'
const PASS = process.env.TYPEDB_PASSWORD || 'password'
const RUNS = Number(process.env.RACE_RUNS || 5)
if (!/127\.0\.0\.1|localhost/.test(BASE)) {
  console.error(`REFUSING: ${BASE} is not local. This harness races WRITES; point it at a throwaway server.`)
  process.exit(2)
}
let TOKEN = ''
const api = (p, init) => fetch(`${BASE}/v1${p}`, init)
async function q(query, tt = 'read') {
  const r = await api('/query', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${TOKEN}` },
    body: JSON.stringify({ query, databaseName: DB, transactionType: tt, commit: tt !== 'read' }),
  })
  let body
  try { body = await r.json() } catch { body = {} }
  return { status: r.status, rows: body.answers ?? [], code: body.code, message: body.message }
}
const tags = async (tid) =>
  (await q(`match $t isa thing, has tid "${tid}", has tag $g; select $g;`)).rows
    .map((a) => a.data?.g?.value).filter(Boolean).sort()

async function main() {
  TOKEN = (await (await api('/signin', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: USER, password: PASS }),
  })).json()).token
  if (!TOKEN) throw new Error('signin failed')
  await api(`/databases/${DB}`, { method: 'DELETE', headers: { Authorization: `Bearer ${TOKEN}` } })
  await api(`/databases/${DB}`, { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}` } })
  // Same cardinalities as schema/one.tql: tid @key, tag @card(0..),
  // task-status and updated-at-ms single-valued.
  await q(`define entity thing, owns tid @key, owns task-status @card(0..1), owns tag @card(0..), owns updated-at-ms @card(0..1);
    attribute tid value string; attribute task-status value string;
    attribute tag value string; attribute updated-at-ms value integer;`, 'schema')

  const reset = async (tid) => {
    await q(`match $t isa thing, has tid "${tid}"; delete $t;`, 'write')
    await q(`insert $t isa thing, has tid "${tid}", has task-status "open", has updated-at-ms 1;`, 'write')
  }
  // The SHIPPED shape — one transaction, guard in the match, tag in the insert.
  const guarded = (tid, who) =>
    q(`match $t isa thing, has tid "${tid}", has task-status $s; $s == "open"; delete $s of $t;` +
      ` insert $t has task-status "picked", has tag "@${who}";` +
      ` update $t has updated-at-ms ${Date.now()}; select $t;`, 'write')

  let fail = 0
  // ── half 1: zero-match must be observable, not a silent success ──────────
  await reset('obs')
  const hit = await guarded('obs', 'alice')
  const miss = await guarded('obs', 'bob')
  const observable = hit.status === 200 && hit.rows.length === 1 && miss.status === 200 && miss.rows.length === 0
  console.log(`[observable] match rows=${hit.rows.length} (${hit.status}) · no-match rows=${miss.rows.length} (${miss.status}) -> ${observable ? 'OK' : 'FAIL'}`)
  if (!observable) fail++

  // ── half 2: GREEN — concurrent guarded claims ────────────────────────────
  for (let i = 0; i < RUNS; i++) {
    const tid = `g${i}`
    await reset(tid)
    const [a, b] = await Promise.all([guarded(tid, 'alice'), guarded(tid, 'bob')])
    const winners = [a, b].filter((r) => r.status === 200 && r.rows.length === 1).length
    const t = await tags(tid)
    const loser = [a, b].find((r) => r.status !== 200)
    const ok = winners === 1 && t.length === 1
    console.log(`[green run${i}] winners=${winners} tags=${JSON.stringify(t)} loser=${loser ? `${loser.status} ${loser.code}` : 'none'} -> ${ok ? 'OK' : 'FAIL'}`)
    if (loser?.message) console.log(`            "${loser.message.split('\n')[0]}"`)
    if (!ok) fail++
  }

  // ── half 3: RED — the old read-then-decide shape must still double-claim ─
  const legacy = async (tid, who) => {
    const rd = await q(`match $t isa thing, has tid "${tid}", has task-status $s; try { $t has tag $g; }; select $s, $g;`)
    const blob = JSON.stringify(rd.rows)
    const other = blob.match(/"@(\w+)"/)
    if (blob.includes('"picked"') && other && other[1] !== who) return { error: 'already-claimed' }
    await q(`match $t isa thing, has tid "${tid}", has task-status $s; delete $s of $t; insert $t has task-status "picked";`, 'write')
    await q(`match $t isa thing, has tid "${tid}"; insert $t has tag "@${who}";`, 'write')
    return { ok: true, claimant: who }
  }
  await reset('red')
  const [l1, l2] = await Promise.all([legacy('red', 'alice'), legacy('red', 'bob')])
  const redTags = await tags('red')
  const redProven = !!l1.ok && !!l2.ok && redTags.length === 2
  console.log(`[red] legacy shape: both-ok=${!!l1.ok && !!l2.ok} tags=${JSON.stringify(redTags)} -> ${redProven ? 'RED PROVEN' : 'FAIL (checker cannot go red)'}`)
  if (!redProven) fail++

  console.log(fail === 0 ? '\nPASS — guarded claim is atomic; the checker proved its own red half.' : `\nFAIL — ${fail} check(s) failed.`)
  process.exit(fail === 0 ? 0 : 1)
}
main().catch((e) => { console.error('harness error:', e.message); process.exit(2) })
