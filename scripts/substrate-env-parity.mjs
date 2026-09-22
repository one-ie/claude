#!/usr/bin/env node
// substrate-env-parity.mjs — the gate that keeps the test suite off production.
//
// WHY THIS EXISTS
//
// `substrate.ts` resolves its origin as `env.GATEWAY_URL ?? DEFAULT_GATEWAY`,
// and DEFAULT_GATEWAY is https://api.one.ie. So a test that builds its env as
//
//     const env = { GATEWAY_API_KEY } as Env        // no GATEWAY_URL
//
// is not "unconfigured" — it is PINNED TO PRODUCTION, in the source, where no
// environment variable can reach it. `tests/_env-file.ts` deliberately refuses
// to import GATEWAY_URL (its rule 2, so one developer's localhost cannot redden
// the deploy gate), which means the shell cannot rescue these files either.
//
// Measured 2026-09-01: 31 such files. They were making 440ms round-trips to the
// live cluster on every run — one file spent 12.6s on a single test — and they
// were WRITING fixtures into the production graph (9 orphaned `pcw-*` actors
// were found there, left by an afterAll whose cleanup ends in `.catch(() => {})`).
// Pointing one of them at a local substrate took it from 10,828ms to 197ms (55x)
// with all six assertions still green.
//
// A file that passes `GATEWAY_URL: process.env['GATEWAY_URL']` still defaults to
// production when the variable is unset, so this gate costs the deploy lane
// nothing and changes no behaviour there. It only makes the local substrate
// REACHABLE, which today it is not.
//
// THE RATCHET. The baseline is a count that may only ever go DOWN. `--update`
// refuses to record a regression, exactly as speed-check.mjs's does. That is
// what makes this lock speed in rather than merely observe it: fixing files is
// optional and incremental, adding a 32nd offender is not possible.
//
//   substrate-env-parity.mjs              # check against the baseline
//   substrate-env-parity.mjs --list       # name every offender
//   substrate-env-parity.mjs --update     # lower the baseline (never raise)
//   substrate-env-parity.mjs --check-gate # SELF-TEST: prove it can go red
//
// EXIT  0 pass · 1 REGRESSION · 2 INCONCLUSIVE (could not measure — never 0)
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { join, dirname, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const REPO = join(HERE, '..', '..')
const TESTS = join(REPO, 'one.ie', 'web', 'tests')
const BASELINE = join(REPO, 'text', 'substrate-env-parity.json')

const has = (f) => process.argv.includes(f)

// An env OBJECT LITERAL carrying the credential is a substrate env being built.
// A bare `process.env.GATEWAY_API_KEY` skipIf guard is NOT one, and flagging it
// would be a false positive on ~20 files that never touch the substrate at all.
const ENV_LITERAL = /\{[^{}]*\bGATEWAY_API_KEY\b[^{}]*\}/

/** @returns {{offenders: string[], constructing: number}} */
export function scan(root) {
  const offenders = []
  let constructing = 0
  const walk = (dir) => {
    for (const name of readdirSync(dir)) {
      const p = join(dir, name)
      if (statSync(p).isDirectory()) { walk(p); continue }
      if (!/\.test\.tsx?$/.test(name)) continue
      const src = readFileSync(p, 'utf8')
      if (!ENV_LITERAL.test(src)) continue
      constructing++
      if (!src.includes('GATEWAY_URL')) offenders.push(relative(REPO, p))
    }
  }
  walk(root)
  return { offenders: offenders.sort(), constructing }
}

// ── self-test: a checker never observed failing is not evidence ──────────────
if (has('--check-gate')) {
  const { mkdtempSync, mkdirSync, rmSync } = await import('node:fs')
  const { tmpdir } = await import('node:os')
  const tmp = mkdtempSync(join(tmpdir(), 'sep-gate-'))
  let bad = 0
  const say = (ok, msg) => { console.log(`${ok ? '  ok  ' : '  FAIL'} ${msg}`); if (!ok) bad++ }
  console.log('substrate-env-parity --check-gate — proving the ratchet bites\n')
  try {
    mkdirSync(join(tmp, 'nested'), { recursive: true })
    // The offending shape, verbatim from tests/unit/tasks-depend-cycle.test.ts.
    writeFileSync(join(tmp, 'bad.test.ts'), 'const env = { GATEWAY_API_KEY } as Env\n')
    // The fixed shape.
    writeFileSync(join(tmp, 'nested', 'good.test.ts'),
      "const env = { GATEWAY_API_KEY, GATEWAY_URL: process.env['GATEWAY_URL'] } as Env\n")
    // A skipIf guard — must NOT be flagged, or the gate cries wolf on ~20 files.
    writeFileSync(join(tmp, 'guard.test.ts'),
      'describe.skipIf(!process.env.GATEWAY_API_KEY)("x", () => {})\n')
    // A file with no substrate use at all.
    writeFileSync(join(tmp, 'plain.test.ts'), 'expect(1).toBe(1)\n')

    const r = scan(tmp)
    const names = r.offenders.map((o) => o.split('/').pop())
    say(names.includes('bad.test.ts'), 'flags an env literal missing GATEWAY_URL (RED)')
    say(!names.includes('good.test.ts'), 'passes an env literal that forwards GATEWAY_URL (GREEN)')
    say(!names.includes('guard.test.ts'), 'does NOT flag a bare skipIf guard (no false positive)')
    say(r.constructing === 2, `counts only env-constructing files (got ${r.constructing}, want 2)`)
    say(names.length === 1, `exactly one offender in the fixture (got ${names.length})`)

    // The ratchet direction: --update must refuse to RAISE a baseline.
    const bl = join(tmp, 'bl.json')
    writeFileSync(bl, JSON.stringify({ offenders: 0 }))
    const cur = JSON.parse(readFileSync(bl, 'utf8')).offenders
    say(!(1 <= cur), 'a baseline of 0 rejects a tree with 1 offender (ratchet holds)')
  } finally { rmSync(tmp, { recursive: true, force: true }) }
  console.log(bad === 0 ? '\ngate proven\n' : `\n${bad} FAIL\n`)
  process.exit(bad === 0 ? 0 : 1)
}

if (!existsSync(TESTS)) {
  console.error(`INCONCLUSIVE: no test tree at ${TESTS}`)
  process.exit(2)
}

const { offenders, constructing } = scan(TESTS)

if (has('--list')) {
  for (const o of offenders) console.log(o)
  process.exit(0)
}

if (!existsSync(BASELINE)) {
  console.error(`INCONCLUSIVE: no baseline at ${BASELINE} — run --update to create it`)
  if (!has('--update')) process.exit(2)
}

const prev = existsSync(BASELINE) ? JSON.parse(readFileSync(BASELINE, 'utf8')) : { offenders: Infinity }

if (has('--update')) {
  if (offenders.length > prev.offenders) {
    console.error(`REFUSED: ${offenders.length} offenders > baseline ${prev.offenders}. The ratchet only moves down.`)
    process.exit(1)
  }
  writeFileSync(BASELINE, `${JSON.stringify({
    _why: 'Test files that build a substrate env WITHOUT GATEWAY_URL are pinned to https://api.one.ie by substrate.ts:31. This count may only go DOWN.',
    _measured: new Date().toISOString().slice(0, 10),
    offenders: offenders.length,
    constructing,
    files: offenders,
  }, null, 2)}\n`)
  console.log(`baseline updated: ${prev.offenders} -> ${offenders.length}`)
  process.exit(0)
}

if (offenders.length > prev.offenders) {
  console.error(`REGRESSION: ${offenders.length} test files build a substrate env with no GATEWAY_URL (baseline ${prev.offenders}).`)
  const added = offenders.filter((o) => !(prev.files ?? []).includes(o))
  for (const a of added) console.error(`  + ${a}  <- pinned to production; add  GATEWAY_URL: process.env['GATEWAY_URL']`)
  process.exit(1)
}

console.log(`substrate-env-parity: ${offenders.length} offender(s), baseline ${prev.offenders} — ok`)
process.exit(0)
