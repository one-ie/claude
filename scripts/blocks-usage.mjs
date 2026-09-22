#!/usr/bin/env node
// The census, regenerable — text/blocks.md deliverable 2.
//
// Reads every row of the `pages` table (D1, --remote by default, --local on
// request), resolves each page's block list EXACTLY the way production does
// (data column when present, else componentsToPuck(parseComponents(components))
// — see one.ie/web/src/pages/u/[slug]/p/[pageSlug].astro), tallies pagesUsing
// (distinct pages with >=1 instance) and instances (total instances) per
// registered block name, cross-references nonPageRefs (uses of the name
// outside one.ie/web/src/lib/puck/), and writes
// one.ie/web/src/lib/puck/block-usage.json.
//
// --check: regenerate in memory and diff against the committed file's
// `blocks` map (measuredAt excluded from the diff). Runs with NO network/D1
// access as long as the committed file already exists.
//
// Usage:
//   node .claude/scripts/blocks-usage.mjs              # --remote, write the file
//   node .claude/scripts/blocks-usage.mjs --local       # read local D1 instead
//   node .claude/scripts/blocks-usage.mjs --check        # diff, no write, no D1 unless file missing

import { execFileSync } from 'node:child_process'
import { writeFileSync, readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const REPO_ROOT = path.resolve(__dirname, '../..')
const WEB_DIR = path.join(REPO_ROOT, 'one.ie/web')
const CONFIG_PATH = path.join(WEB_DIR, 'src/lib/puck/config.tsx')
const OUT_PATH = path.join(WEB_DIR, 'src/lib/puck/block-usage.json')
const PUCK_LIB_DIR = path.join(WEB_DIR, 'src/lib/puck')
// GENERATED and gitignored — `src/data/promises.json` is built from text/*.md by
// the promise-manifest step, so every block name written into a PROMISE lands in
// `src/` and reads as a code reference. It is not one: a block named in a
// marketing contract is not a block anything can reach. Counting it made
// `--check` go red on a DOC edit (measured 2026-08-19: naming HeroCentered and
// PricingSection in text/blocks.md moved ten blocks and flipped one from
// unchosen to chosen), and worse, made the archive verdict depend on prose.
// Redundant since the scan intersects with `git ls-files` (the file is
// gitignored, so it is never tracked) — kept as a backstop against a stray
// `git add -f` making prose count again.
const PROMISES_JSON = path.join(WEB_DIR, 'src/data/promises.json')

const args = process.argv.slice(2)
const CHECK = args.includes('--check')
const LOCAL = args.includes('--local')

function readRegisteredNames() {
  const tmp = mkdtempSync(path.join(tmpdir(), 'blocks-census-'))
  const runner = path.join(tmp, 'names.mjs')
  writeFileSync(
    runner,
    `import { puckConfig } from ${JSON.stringify(CONFIG_PATH)}\nconsole.log(JSON.stringify(Object.keys(puckConfig.components)))\n`,
  )
  try {
    const out = execFileSync('bunx', ['tsx', runner], { cwd: WEB_DIR, encoding: 'utf8' })
    return JSON.parse(out.trim())
  } finally {
    rmSync(tmp, { recursive: true, force: true })
  }
}

// The census must measure the RETIRED names too, not just the 130 that survive
// collapseFamilies. Stored pages still carry `LandingHero`, and it resolves to
// Hero through BLOCK_ALIASES at render — so if the census only knows canonicals,
// every collapsed family measures 0 demand and the usage-ordered palette ranks
// them last. Measured 2026-08-18 on the first true regeneration since the cut:
// Hero fell to pagesUsing=0 and palette-order's family-inheritance test went red.
function readAliasNames() {
  const tmp = mkdtempSync(path.join(tmpdir(), 'blocks-alias-'))
  const runner = path.join(tmp, 'aliases.mjs')
  writeFileSync(
    runner,
    `import { BLOCK_ALIASES } from ${JSON.stringify(path.join(WEB_DIR, 'src/lib/puck/families.ts'))}\nconsole.log(JSON.stringify(Object.keys(BLOCK_ALIASES ?? {})))\n`,
  )
  try {
    const out = execFileSync('bunx', ['tsx', runner], { cwd: WEB_DIR, encoding: 'utf8' })
    return JSON.parse(out.trim())
  } finally {
    rmSync(tmp, { recursive: true, force: true })
  }
}

function readPagesRows() {
  const flag = LOCAL ? '--local' : '--remote'
  const out = execFileSync(
    'bunx',
    ['wrangler', 'd1', 'execute', 'one-owners', flag, '--json', '--command', 'SELECT slug, workspace, components, data FROM pages'],
    { cwd: WEB_DIR, encoding: 'utf8', maxBuffer: 1024 * 1024 * 256 },
  )
  const parsed = JSON.parse(out)
  return parsed[0]?.results ?? []
}

// Mirrors one.ie/web/src/pages/u/[slug]/p/[pageSlug].astro's resolution order:
// data column wins when present and parseable; else derive from legacy
// components via componentsToPuck(parseComponents(...)).
function resolveBlockNames(row) {
  const names = []
  let content = null
  if (row.data) {
    try {
      const parsed = JSON.parse(row.data)
      content = Array.isArray(parsed?.content) ? parsed.content : null
    } catch {
      content = null
    }
  }
  if (!content) {
    let sections = []
    try {
      const raw = typeof row.components === 'string' ? JSON.parse(row.components) : row.components
      if (Array.isArray(raw)) {
        sections = raw.filter((e) => e && typeof e === 'object' && typeof e.component === 'string')
      }
    } catch {
      sections = []
    }
    content = sections.map((s) => ({ type: s.component }))
  }
  for (const block of content) {
    const type = block && typeof block === 'object' ? block.type : null
    if (typeof type === 'string') names.push(type)
  }
  return names
}

function computeUsage(rows, registered) {
  const pagesUsing = new Map()
  const instances = new Map()
  for (const name of registered) {
    pagesUsing.set(name, 0)
    instances.set(name, 0)
  }
  for (const row of rows) {
    const names = resolveBlockNames(row)
    const seenOnThisPage = new Set()
    for (const name of names) {
      if (!instances.has(name)) continue // not a registered block (dead name, alias, etc.)
      instances.set(name, instances.get(name) + 1)
      seenOnThisPage.add(name)
    }
    for (const name of seenOnThisPage) {
      pagesUsing.set(name, pagesUsing.get(name) + 1)
    }
  }
  return { pagesUsing, instances }
}

// nonPageRefs: how many files OUTSIDE lib/puck/ mention this component name
// (social composer, mail renderer, etc.) — a block reachable from there is
// CHOSEN even at zero page instances.
function computeNonPageRefs(registered) {
  const result = new Map()
  for (const name of registered) result.set(name, 0)
  let out
  try {
    out = execFileSync(
      'grep',
      ['-rl', '-E', `\\b(${registered.map(escapeRe).join('|')})\\b`, path.join(WEB_DIR, 'src')],
      { encoding: 'utf8', maxBuffer: 1024 * 1024 * 64 },
    )
  } catch (err) {
    // grep exits 1 when nothing matches — that's a valid empty result, not an error.
    out = err.stdout ?? ''
  }
  const tracked = trackedSourceFiles()
  const files = out
    .split('\n')
    .filter(Boolean)
    .filter((f) => tracked.has(f))
    .filter((f) => !f.startsWith(PUCK_LIB_DIR + path.sep) && f !== CONFIG_PATH && f !== PROMISES_JSON)
    .filter((f) => !f.includes('.test.') && !f.includes('/tests/'))
  for (const file of files) {
    let text
    try {
      text = readFileSync(file, 'utf8')
    } catch {
      continue
    }
    for (const name of registered) {
      const re = new RegExp(`\\b${escapeRe(name)}\\b`)
      if (re.test(text)) result.set(name, result.get(name) + 1)
    }
  }
  return result
}

function escapeRe(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

// The census is a claim about the REPO, so the scan must read what git tracks,
// not what happens to be sitting on disk. A regenerate run during a neighbour's
// half-finished work otherwise records references that do not exist in the
// repo — measured 2026-08-19: an uncommitted src/components/speed/SpeedMetrics.tsx
// from a concurrent session contributed Timeline and Stats refs to the committed
// census. Locally-MODIFIED tracked files still count: the bar is tracked, not
// clean, because a modified file is still a file the repo has.
function trackedSourceFiles() {
  let out
  try {
    out = execFileSync('git', ['ls-files', '-z', '--', 'src'], {
      cwd: WEB_DIR,
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 64,
    })
  } catch (err) {
    throw new Error(`blocks-usage: git ls-files failed — cannot tell tracked from untracked: ${err.message}`)
  }
  const files = new Set(
    out
      .split('\0')
      .filter(Boolean)
      .map((rel) => path.join(WEB_DIR, rel)),
  )
  // A broken sensor must never degrade quietly: an empty or implausibly small
  // tracked set would zero every nonPageRefs and read as "archive everything".
  // 2474 files were tracked under one.ie/web/src when this floor was measured.
  if (files.size < 500) {
    throw new Error(`blocks-usage: git ls-files returned only ${files.size} files under one.ie/web/src — refusing to census a repo this scan cannot see`)
  }
  return files
}

function buildCensus() {
  const registered = readRegisteredNames().sort()
  // registered ∪ retired-but-reachable — see readAliasNames above
  const measured = [...new Set([...registered, ...readAliasNames()])].sort()
  const rows = readPagesRows()
  const { pagesUsing, instances } = computeUsage(rows, measured)
  const nonPageRefs = computeNonPageRefs(measured)
  const blocks = {}
  let chosen = 0
  for (const name of measured) {
    const pu = pagesUsing.get(name) ?? 0
    const inst = instances.get(name) ?? 0
    const npr = nonPageRefs.get(name) ?? 0
    blocks[name] = { pagesUsing: pu, instances: inst, nonPageRefs: npr }
    if (pu > 0 || npr > 0) chosen++
  }
  return {
    measuredAt: new Date().toISOString().slice(0, 10),
    registered: registered.length,
    measured: measured.length,
    chosen,
    unchosen: measured.length - chosen,
    blocks,
  }
}

function diffBlocks(committed, fresh) {
  const lines = []
  const names = new Set([...Object.keys(committed.blocks ?? {}), ...Object.keys(fresh.blocks)])
  for (const name of [...names].sort()) {
    const a = committed.blocks?.[name]
    const b = fresh.blocks[name]
    if (!a) {
      lines.push(`+ ${name} ${JSON.stringify(b)}`)
      continue
    }
    if (!b) {
      lines.push(`- ${name} ${JSON.stringify(a)}`)
      continue
    }
    if (a.pagesUsing !== b.pagesUsing || a.instances !== b.instances || a.nonPageRefs !== b.nonPageRefs) {
      lines.push(`~ ${name} committed=${JSON.stringify(a)} fresh=${JSON.stringify(b)}`)
    }
  }
  if (committed.registered !== fresh.registered) lines.push(`~ registered committed=${committed.registered} fresh=${fresh.registered}`)
  if (committed.chosen !== fresh.chosen) lines.push(`~ chosen committed=${committed.chosen} fresh=${fresh.chosen}`)
  if (committed.unchosen !== fresh.unchosen) lines.push(`~ unchosen committed=${committed.unchosen} fresh=${fresh.unchosen}`)
  return lines
}

function main() {
  if (CHECK) {
    if (!existsSync(OUT_PATH)) {
      console.error(`blocks-usage --check: ${OUT_PATH} does not exist — run without --check first to seed it.`)
      process.exit(1)
    }
    const committed = JSON.parse(readFileSync(OUT_PATH, 'utf8'))
    const fresh = buildCensusOffline(committed)
    const diff = diffBlocks(committed, fresh)
    if (diff.length > 0) {
      console.error('blocks-usage --check: drift detected')
      for (const line of diff) console.error(line)
      process.exit(1)
    }
    console.log('blocks-usage --check: ok (no drift)')
    process.exit(0)
  }

  const census = buildCensus()
  writeFileSync(OUT_PATH, JSON.stringify(census, null, 2) + '\n')
  console.log(`wrote ${OUT_PATH} — registered=${census.registered} chosen=${census.chosen} unchosen=${census.unchosen}`)
}

// In --check mode, re-derive registered names + nonPageRefs from the committed
// file's OWN key set. This lets --check run with zero D1/network access when
// the caller doesn't need a live page-usage recompute (i.e. it trusts the
// committed pagesUsing/instances numbers and only re-verifies name/ref shape).
// If a live D1 recheck is wanted, delete block-usage.json and re-run without
// --check first.
function buildCensusOffline(committed) {
  // --check runs with no D1: it re-derives only the source-scanned half
  // (nonPageRefs) and trusts the committed D1 half. The name set is therefore
  // whatever the committed file measured — registered UNION retired — so it
  // must NOT be reported as `registered`, which counts actual registrations.
  const measuredNames = Object.keys(committed.blocks ?? {}).sort()
  const nonPageRefs = computeNonPageRefs(measuredNames)
  const blocks = {}
  let chosen = 0
  for (const name of measuredNames) {
    const pu = committed.blocks[name]?.pagesUsing ?? 0
    const inst = committed.blocks[name]?.instances ?? 0
    const npr = nonPageRefs.get(name) ?? 0
    blocks[name] = { pagesUsing: pu, instances: inst, nonPageRefs: npr }
    if (pu > 0 || npr > 0) chosen++
  }
  return {
    measuredAt: committed.measuredAt,
    registered: committed.registered,
    measured: measuredNames.length,
    chosen,
    unchosen: measuredNames.length - chosen,
    blocks,
  }
}

main()
