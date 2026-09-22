#!/usr/bin/env node
// classification: portable
// Red proof for factory-executor.js's Review predicate — and it READS THE FILE.
//
// The first version of this checker defined OLD and NEW as two inline lambdas
// and never opened the executor. It stayed green through two merges on
// 2026-09-06 while the executor's own line was fail-open (`0*2 > 1` = false
// for zero survivors). A checker that cannot see its subject proves nothing;
// this one lifts the predicate out of the source with new Function, drives it
// over the jury table beside the OLD shape, and fails closed if the lines it
// expects are not in the file.
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const file = process.argv[2] || join(here, '..', 'workflows', 'factory-executor.js')
const src = readFileSync(file, 'utf8')

// Lift the two lines that ARE the predicate. Anchored on the const names, not
// on the arithmetic, so a wrong formula is caught by the table, not by the regex.
const mAgainst = src.match(/^\s*const against = (.+)$/m)
const mRefuted = src.match(/^\s*const refuted = (.+)$/m)
if (!mRefuted) {
  console.log(`RED  could not lift the Review predicate from ${file} — expected a \`const refuted = …\` line`)
  process.exit(1)
}
// A pre-fix file has no `against` line; derive it so the OLD shape is DRIVEN and
// fails on the table (a wrong verdict), rather than tripping the regex (a miss).
const againstExpr = mAgainst ? mAgainst[1] : 'votes.filter((v) => v.refuted).length'
let LIFTED
try {
  LIFTED = new Function('votes', `const against = ${againstExpr}; return ${mRefuted[1]};`)
} catch (e) {
  console.log(`RED  lifted predicate does not parse: ${e.message}`); process.exit(1)
}
const OLD = (v) => v.filter(x => x.refuted).length * 2 > Math.max(1, v.length)

const R = { refuted: true }, A = { refuted: false }
const cases = [
  ['zero survivors (every lens threw)', [],            true,  'THE BUG: nobody voted, so nobody objected'],
  ['1 lens, refutes',                   [R],           true,  'lone lens must bite'],
  ['1 lens, approves',                  [A],           false, 'lone lens approves'],
  ['2 lenses split 1-1',                [R, A],        true,  'a split jury is not an acquittal'],
  ['2 lenses both refute',              [R, R],        true,  'unanimous against'],
  ['2 lenses both approve',             [A, A],        false, 'unanimous for'],
  ['3 lenses, 1 refutes',               [R, A, A],     false, 'a lone dissenter is not a majority'],
  ['3 lenses, 2 refute',                [R, R, A],     true,  'majority against'],
]
let oldFails = 0, fileFails = 0
console.log(`predicate lifted from ${file}\n  against = ${againstExpr}${mAgainst ? '' : '  (derived — file has no against line)'}\n  refuted = ${mRefuted[1]}\n`)
console.log('case                                  want   OLD    FILE')
for (const [name, votes, want, why] of cases) {
  const o = OLD(votes), f = LIFTED(votes)
  if (o !== want) oldFails++
  if (f !== want) fileFails++
  console.log(`${name.padEnd(36)} ${String(want).padEnd(6)} ${o === want ? ' ok  ' : 'RED  '} ${f === want ? ' ok' : 'RED'}   ${f !== want ? '<- FILE WRONG: ' + why : ''}`)
}
console.log(`\nOLD shape: ${oldFails} failure(s)  <- must be > 0 or this proof is worthless`)
console.log(`FILE:      ${fileFails} failure(s)  <- must be 0`)
process.exit(oldFails > 0 && fileFails === 0 ? 0 : 1)
