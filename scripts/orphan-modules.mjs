#!/usr/bin/env node
/**
 * orphan-modules.mjs — every module under src/ must be reachable from something
 * that is not a test.
 *
 * WHY THIS EXISTS. On 2026-08-26 an audit found that `693ba76b4` ("land nine
 * fleets' work") took 35 of 70 files — keeping 12/19 tests but only 10/40
 * source. Two failure modes came out of it:
 *
 *   dropped CALLEE  -> red test          visible, three suites caught it
 *   dropped CALLER  -> green test, dead  INVISIBLE to every gate that existed
 *
 * The second is what this catches. `foundation/derive.ts`, `executor.ts` and
 * `execute-skill.ts` all landed, all have passing tests, and NOTHING in src/
 * imports any of them — their only caller was dropped. The suite went green
 * over a dead feature. Measured: the test suite caught roughly a TENTH of the
 * 28 missing files.
 *
 * The tempting check is test-import-integrity. The data refutes it: it misses
 * the wallet case (master-wiring reads source as TEXT, so there are no imports
 * to resolve) and it misses the foundation case (those imports resolve fine).
 * Reachability is the property that actually distinguishes live from dead.
 *
 * SUBSTRING MATCHING IS NOT ENOUGH and was the first thing tried — grepping for
 * `derive` matched 216 files. This resolves real import specifiers.
 *
 *   node .claude/scripts/orphan-modules.mjs            # report orphans
 *   node .claude/scripts/orphan-modules.mjs --check     # exit 1 if any
 *   node .claude/scripts/orphan-modules.mjs --check-red # prove it can fail
 */
import { readFileSync, readdirSync, statSync, existsSync, writeFileSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs'
import { join, resolve, dirname, relative, extname } from 'node:path'
import { tmpdir } from 'node:os'

const MODE = process.argv[2] ?? ''

// Entry points are reached by the FRAMEWORK, not by an import, so an
// un-imported one is correct rather than orphaned. Getting this list wrong in
// the permissive direction hides real orphans; wrong in the strict direction
// produces noise nobody will read. Keep it narrow and justified.
const ENTRY = [
  /^src\/pages\//,          // Astro routes + API routes
  /^src\/middleware\.ts$/,  // Astro middleware
  /^src\/workers\//,        // CF worker entry points
  /^src\/env\.d\.ts$/,
  /^src\/types\//,          // ambient/type-only, erased at runtime
  /^src\/content\//,        // content collections
  /^src\/styles\//,
]
const SRC_EXT = new Set(['.ts', '.tsx', '.astro', '.mjs'])

function walk(dir, out = []) {
  for (const e of readdirSync(dir)) {
    if (e === 'node_modules' || e === 'dist' || e.startsWith('.')) continue
    const p = join(dir, e)
    if (statSync(p).isDirectory()) walk(p, out)
    else if (SRC_EXT.has(extname(e))) out.push(p)
  }
  return out
}

// Import specifiers: static imports, `export ... from`, dynamic import(), and
// Astro frontmatter (which is just TS between the fences).
const SPEC_RE = /(?:import|export)\s[^;]*?from\s*['"]([^'"]+)['"]|import\s*\(\s*['"]([^'"]+)['"]\s*\)|import\s*['"]([^'"]+)['"]/g

function specifiersOf(file) {
  const src = readFileSync(file, 'utf8')
  const out = []
  for (const m of src.matchAll(SPEC_RE)) out.push(m[1] ?? m[2] ?? m[3])
  return out.filter(Boolean)
}

/** Resolve a specifier to a real file, honouring the `@/` alias and extensionless imports. */
function resolveSpec(spec, fromFile, root) {
  let base
  if (spec.startsWith('@/')) base = join(root, 'src', spec.slice(2))
  else if (spec.startsWith('.')) base = resolve(dirname(fromFile), spec)
  else return null // bare package
  // TS lets you write .js for a .ts file
  const stripped = base.replace(/\.js$/, '')
  for (const c of [base, stripped,
                   ...['.ts', '.tsx', '.astro', '.mjs'].flatMap(e => [stripped + e, join(stripped, 'index' + e)])]) {
    if (existsSync(c) && statSync(c).isFile()) return c
  }
  return null
}

function analyse(root) {
  const files = walk(join(root, 'src'))
  const rel = f => relative(root, f).split('\\').join('/')
  const isTest = f => /\.(test|spec)\.[tj]sx?$/.test(f) || rel(f).includes('/tests/')
  const isEntry = f => ENTRY.some(re => re.test(rel(f)))

  // Reached by a NON-TEST file. A module imported only by its own test is
  // exactly the dead-feature shape, so tests must not count as reachability.
  const reached = new Set()
  for (const f of files) {
    if (isTest(f)) continue
    for (const s of specifiersOf(f)) {
      const t = resolveSpec(s, f, root)
      if (t && t !== f) reached.add(t)
    }
  }
  const orphans = files.filter(f => !isTest(f) && !isEntry(f) && !reached.has(f)).map(rel).sort()
  return { total: files.length, orphans }
}

// ── --check-red: prove the checker can fail ──────────────────────────────────
// A checker you have only ever seen pass is not evidence (doctrine: prove RED).
if (MODE === '--check-red') {
  const tmp = mkdtempSync(join(tmpdir(), 'orphan-red-'))
  try {
    const s = join(tmp, 'src')
    for (const d of ['lib', 'pages']) mkdirSync(join(s, d), { recursive: true })
    writeFileSync(join(s, 'lib', 'used.ts'), 'export const a = 1\n')
    writeFileSync(join(s, 'lib', 'orphan.ts'), 'export const b = 2\n')
    writeFileSync(join(s, 'pages', 'index.astro'), '---\nimport { a } from "@/lib/used"\n---\n<p>{a}</p>\n')
    let fails = 0
    const r1 = analyse(tmp)
    if (r1.orphans.includes('src/lib/orphan.ts')) console.log('  arm orphan present     caught')
    else { console.log('  arm orphan present     MISSED'); fails++ }
    if (!r1.orphans.includes('src/lib/used.ts')) console.log('  arm used module        not flagged (correct)')
    else { console.log('  arm used module        FALSE POSITIVE'); fails++ }
    if (!r1.orphans.includes('src/pages/index.astro')) console.log('  arm entry point        exempt (correct)')
    else { console.log('  arm entry point        FALSE POSITIVE'); fails++ }
    // a module imported ONLY by a test is still an orphan — the whole point
    writeFileSync(join(s, 'lib', 'testonly.ts'), 'export const c = 3\n')
    mkdirSync(join(tmp, 'tests'), { recursive: true })
    writeFileSync(join(tmp, 'tests', 'x.test.ts'), 'import { c } from "@/lib/testonly"\n')
    const r2 = analyse(tmp)
    if (r2.orphans.includes('src/lib/testonly.ts')) console.log('  arm test-only import   caught (the dead-feature shape)')
    else { console.log('  arm test-only import   MISSED — this is the shape it exists for'); fails++ }
    console.log(fails === 0
      ? 'check-red: all four arms behaved — the checker CAN go red, and does not cry wolf'
      : `check-red: ${fails} assertion(s) failed`)
    process.exit(fails === 0 ? 0 : 1)
  } finally { rmSync(tmp, { recursive: true, force: true }) }
}

const root = resolve(process.argv.includes('--root')
  ? process.argv[process.argv.indexOf('--root') + 1]
  : join(dirname(new URL(import.meta.url).pathname), '..', '..', 'one.ie', 'web'))

if (!existsSync(join(root, 'src'))) {
  console.error(`orphan-modules: no src/ at ${root} — this is UNMEASURED, not ok`)
  process.exit(2)
}

const { total, orphans } = analyse(root)
console.log(`orphan-modules: ${total} files scanned, ${orphans.length} orphan(s)`)
for (const o of orphans) console.log(`  ${o}`)
// A RATCHET, not a hard gate. 178 orphans exist today and some are reached in
// ways this resolver cannot see (a registry map, a Puck block table, a string
// key). Gating on zero would cry wolf on day one and be muted by day three.
// Gating on "no NEW orphan" is the same monotonic shape /do already runs: the
// count can only fall. That is what catches the next dropped caller.
const BASELINE = join(dirname(new URL(import.meta.url).pathname), 'orphan-baseline.json')
if (MODE === '--check') {
  let base = { count: Infinity, files: [] }
  if (existsSync(BASELINE)) base = JSON.parse(readFileSync(BASELINE, 'utf8'))
  const known = new Set(base.files ?? [])
  const fresh = orphans.filter(o => !known.has(o))
  if (fresh.length) {
    console.log(`\nRED — ${fresh.length} NEW orphan(s) since the baseline:`)
    for (const f of fresh) console.log(`  + ${f}`)
    console.log('\nA new orphan means a module landed with no caller — the shape that')
    console.log('dropped 28 files on 2026-08-26 and showed GREEN the whole time.')
    console.log('Wire it, delete it, or add it to ENTRY with a reason.')
    process.exit(1)
  }
  if (orphans.length < base.count) {
    console.log(`ratchet ROSE: ${base.count} -> ${orphans.length}. Re-baseline with --baseline.`)
  }
  console.log(`ok — no new orphans (baseline ${base.count})`)
}
if (MODE === '--baseline') {
  writeFileSync(BASELINE, JSON.stringify({ count: orphans.length, files: orphans, at: new Date().toISOString().slice(0,10) }, null, 2) + '\n')
  console.log(`baseline written: ${orphans.length} orphan(s)`)
}
