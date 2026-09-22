#!/usr/bin/env node
// The generated id inventory — text/story-todo.md C1 deliverable, and the
// source `id:resolve` (C4) projects its metadata card from.
//
// Tony asked for seven id families. Seven hand-maintained registries is the
// measured 1% failure seven times over (text/story-factory-plan.md § 2), so
// there is ONE inventory with a generated `kind` discriminator. Every field
// here is READ from a source that already exists; nothing is hand-declared.
//
// Five kinds are counted from the repo. Two — `workflow` and `thing` — live in
// the graph, so they carry `provenance:"graph"`, `count:null` and a stated
// reason. `count:0` would be a lie: an unrun count is not a zero. The seventh
// kind is `thing`, the LOCKED dimension-3 word — never `object`
// (text/story-factory-plan.md § 2, § 0b).
//
// Two artifacts, one build, BOTH checked — the rule blocks-manifest.mjs states
// in its own header: an emitted file that nothing compares is a file that rots.
//   one.ie/web/src/data/id-inventory.json  the seven kinds and their entries
//   one.ie/web/src/data/story.json         the metadata card of the story family
//
// Usage:
//   node .claude/scripts/id-inventory.mjs           # write both files
//   node .claude/scripts/id-inventory.mjs --check    # diff, no write

import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync, readdirSync, writeFileSync, mkdirSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const REPO_ROOT = path.resolve(__dirname, '../..')
const R = (...p) => path.join(REPO_ROOT, ...p)

const OUT_INVENTORY = R('one.ie/web/src/data/id-inventory.json')
const OUT_STORY = R('one.ie/web/src/data/story.json')
const STORY_MD = R('text/story.md')

const CHECK = process.argv.slice(2).includes('--check')

// ── the stamp ───────────────────────────────────────────────────────────────
// git HEAD, never wall-clock: a wall-clock stamp makes every regeneration a
// diff, so `--check` could never distinguish a stale artifact from a fresh one.
// It is DELIBERATELY excluded from the --check comparison (`stripStamp` below),
// the same way blocks-manifest.mjs's diffManifests never compares `measuredAt`.
// Comparing it would red this check on the very commit that lands the artifact:
// you generate at sha X, commit (minting sha Y), and X !== Y forever.
function headSha() {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { cwd: REPO_ROOT, encoding: 'utf8' }).trim()
  } catch {
    return 'unknown'
  }
}

// ── frontmatter, the two fields every source here declares ──────────────────
// Deliberately not a YAML parser: `name` and `description` are single-line
// scalars in every SKILL.md and doc in this tree, and a dependency would put a
// build step in front of a script that must run from a bare checkout.
function frontmatter(file) {
  const text = readFileSync(file, 'utf8')
  if (!text.startsWith('---')) return {}
  const end = text.indexOf('\n---', 3)
  if (end === -1) return {}
  const out = {}
  for (const line of text.slice(4, end).split('\n')) {
    const m = line.match(/^([a-zA-Z][a-zA-Z0-9_-]*):\s*(.*)$/)
    if (!m) continue
    let v = m[2].trim()
    if (
      (v.startsWith('"') && v.endsWith('"') && v.length > 1) ||
      (v.startsWith("'") && v.endsWith("'") && v.length > 1)
    ) {
      v = v.slice(1, -1)
    }
    if (v) out[m[1]] = v
  }
  return out
}

// ── kind: signal ────────────────────────────────────────────────────────────
// Counted the way signals-parity.ts counts — `Object.keys(RECEIVERS).length`
// off the registry itself (packages/sdk/scripts/signals-parity.ts:21-22), not a
// grep. A grep over receivers.ts counts whatever the current formatting is; the
// import counts what the system actually ships.
function signals() {
  const runner = [
    `import { RECEIVERS } from ${JSON.stringify(R('packages/sdk/src/receivers.ts'))}`,
    'const out = Object.entries(RECEIVERS).map(([name, r]) => ({',
    '  name, summary: typeof r?.summary === "string" ? r.summary : "",',
    '  source: "packages/sdk/src/receivers.ts",',
    '}))',
    'out.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))',
    'console.log(JSON.stringify(out))',
  ].join('\n')
  const raw = execFileSync('bun', ['-e', runner], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  })
  return JSON.parse(raw.trim())
}

// ── kind: skill ─────────────────────────────────────────────────────────────
// `<dir>/<name>/SKILL.md`, ONE level deep, because that is what the running
// system treats as a skill: one.ie/web/src/lib/skill-catalog.ts:11 globs
// `../../ai/skills/*/SKILL.md`, skills-publish.sh:72 iterates `*/` and requires
// `$d/SKILL.md`, and asi-walk.sh:172 names the same shape. A recursive walk
// finds 325 SKILL.md under one.ie/ai/skills, but the 172 nested ones are not
// addressable as skill ids anywhere in the system — counting them would publish
// an id `id:resolve` could never resolve.
function skills() {
  const out = []
  for (const dir of ['one.ie/ai/skills', '.claude/skills']) {
    const abs = R(dir)
    if (!existsSync(abs)) continue
    for (const name of readdirSync(abs).sort()) {
      const file = path.join(abs, name, 'SKILL.md')
      if (!existsSync(file)) continue
      const fm = frontmatter(file)
      out.push({
        name: fm.name || name,
        summary: fm.description || '',
        source: `${dir}/${name}/SKILL.md`,
      })
    }
  }
  return out
}

// ── kind: component ─────────────────────────────────────────────────────────
// `jq '.count'`, NOT `jq 'length'` — the manifest is {measuredAt, count, blocks}
// so `length` is 3 and has been mistaken for the block count before
// (text/story-todo.md C1). The block vocabulary is itself generated, by
// .claude/scripts/blocks-manifest.mjs — this reads its artifact, never the
// Puck registry, so there is one generator per source.
function components() {
  const file = R('one.ie/web/src/lib/puck/block-manifest.json')
  const manifest = JSON.parse(readFileSync(file, 'utf8'))
  const entries = Object.entries(manifest.blocks ?? {}).map(([name, b]) => ({
    name,
    summary: typeof b?.description === 'string' ? b.description : '',
    source: 'one.ie/web/src/lib/puck/block-manifest.json',
  }))
  entries.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))
  // The manifest's own declared count is the oracle. If the blocks object and
  // the count disagree, the manifest is stale and this inventory must not
  // launder that into a confident number of its own.
  if (typeof manifest.count === 'number' && manifest.count !== entries.length) {
    throw new Error(
      `block-manifest.json is stale: count=${manifest.count} but blocks=${entries.length}. Run: node .claude/scripts/blocks-manifest.mjs`,
    )
  }
  return entries
}

// ── kind: doc ───────────────────────────────────────────────────────────────
// The `docs` CONTENT COLLECTION, not text/. text/ is the plan-and-promise
// surface (a `doc` id addresses a published page); the collection is what
// one.ie actually renders (text/story-factory-plan.md § 2).
function docs() {
  const dir = R('one.ie/web/src/content/docs')
  if (!existsSync(dir)) return []
  const out = []
  for (const name of readdirSync(dir).sort()) {
    if (!/\.mdx?$/.test(name)) continue
    const slug = name.replace(/\.mdx?$/, '')
    const fm = frontmatter(path.join(dir, name))
    out.push({
      name: slug,
      title: fm.title || slug,
      summary: fm.description || '',
      source: `one.ie/web/src/content/docs/${name}`,
    })
  }
  return out
}

// ── kind: function ──────────────────────────────────────────────────────────
// `fn:`, never `fun:` — text/story-factory-plan.md § 0b, the sibling board's
// ruling, which this file is read through.
//
// The name charclass MUST carry `-`: TypeQL fun names are hyphenated
// (`fun strong-reach(...)`, roles.tql:39) and a `[a-zA-Z0-9_]*` pattern silently
// undercounts by 44 across schema/ — measured. The `^\s*fun\s+<name>\s*(` anchor
// also keeps `entity funnel`, `owns funnel-slug` and every `# fun ...` comment
// out; verified by inspecting every non-matching line containing "fun".
const FUN_RE = /^[ \t]*fun[ \t]+([a-zA-Z_][a-zA-Z0-9_-]*)[ \t]*\(/
function functions() {
  const dir = R('schema')
  const out = []
  for (const name of readdirSync(dir).sort()) {
    if (!name.endsWith('.tql')) continue
    const lines = readFileSync(path.join(dir, name), 'utf8').split('\n')
    lines.forEach((line, i) => {
      const m = line.match(FUN_RE)
      if (!m) return
      out.push({
        name: m[1],
        summary: '',
        source: `schema/${name}:${i + 1}`,
      })
    })
  }
  return out
}

// ── the inventory ───────────────────────────────────────────────────────────
// Seven kinds, always seven, in the order text/story-factory-plan.md § 2 lists
// them. Five carry a number read from the repo; two carry null and say why.
const GRAPH_REASON_WORKFLOW =
  'the graph, not the repo — workflows are rows the substrate holds, and a committed artifact cannot walk them. Count it through workflow:list, never here.'
const GRAPH_REASON_THING =
  'dimension 3, the graph — a substrate query. `thing` is the LOCKED word and the catch-all kind; `object` is refused.'

function buildInventory() {
  const counted = {
    signal: signals(),
    skill: skills(),
    component: components(),
    doc: docs(),
    function: functions(),
  }
  const sources = {
    signal: 'packages/sdk/src/receivers.ts',
    skill: 'one.ie/ai/skills/*/SKILL.md + .claude/skills/*/SKILL.md',
    component: "one.ie/web/src/lib/puck/block-manifest.json (jq '.count')",
    doc: 'one.ie/web/src/content/docs',
    function: 'schema/*.tql',
  }
  // The address is COMPOSED, never stored. An entry carries `name`; the id is
  // `<id_prefix>:<name>` — and `id_prefix` is published here, bare and without
  // its colon, so the grammar travels with the data instead of being retyped in
  // the resolver.
  //
  // Storing the composed string is what this artifact must NOT do, and the
  // reason is a law, not a lint: this repo's tags are BARE words, and
  // one.ie/web/tests/unit/in/namespace-parity.test.ts greps src/ for any
  // literal starting `(fn|ticket|kind|state|status|topic|lifecycle):`. A stored
  // `fn:<name>` is indistinguishable from a classification tag — to that grep
  // and to a human reading the file — so materialising 213 of them in src/data
  // published 213 tag-shaped strings into a tree whose central law forbids
  // them. Measured: the gate went red on exactly those 213.
  //
  // `signal` has no prefix: a receiver's name IS its address (`factory:size`),
  // which is why null is the honest value rather than an empty string.
  const idPrefix = { signal: null, skill: 'skill', component: 'component', doc: 'doc', function: 'fn' }
  const kinds = [
    ...['signal', 'skill', 'component', 'doc', 'function'].map((kind) => ({
      kind,
      provenance: 'generated',
      count: counted[kind].length,
      id_prefix: idPrefix[kind],
      source: sources[kind],
    })),
    { kind: 'workflow', provenance: 'graph', count: null, id_prefix: 'workflow', source: 'the substrate', reason: GRAPH_REASON_WORKFLOW },
    { kind: 'thing', provenance: 'graph', count: null, id_prefix: 'thing', source: 'the substrate', reason: GRAPH_REASON_THING },
  ]
  return { generated_at: headSha(), kinds, entries: counted }
}

// ── the story family card (text/story.md's `family` deliverable) ────────────
// The eleven paths are PARSED OUT of text/story.md's own accept line, never
// re-typed here. That accept is `ls <paths…> 2>/dev/null | wc -l` compared
// `-eq 11`; reading the list from the promise is what makes `jq '.files |
// length'` and that `-eq` unable to disagree. A hand-copied list is exactly the
// hand-declared metadata this whole rung exists to replace.
function familyPaths() {
  const md = readFileSync(STORY_MD, 'utf8')
  const line = md.split('\n').find((l) => l.includes('accept:') && /ls\s+text\/story\.md/.test(l))
  if (!line) throw new Error(`could not find the family accept line in ${STORY_MD}`)
  const m = line.match(/ls\s+((?:\S+\s+)*?)2>\/dev\/null/)
  if (!m) throw new Error(`the family accept line is not the expected \`ls … 2>/dev/null\` shape`)
  const paths = m[1].trim().split(/\s+/).filter(Boolean)
  const declared = line.match(/-eq\s+(\d+)/)
  if (declared && Number(declared[1]) !== paths.length) {
    throw new Error(
      `text/story.md's family accept disagrees with itself: it lists ${paths.length} paths and asserts -eq ${declared[1]}`,
    )
  }
  return paths
}

// One of the seven kinds for each family file, decided by a RULE, not by an
// eleven-row hand-written table — the same law the inventory above obeys.
//
// Nothing in the family maps to `signal`, and that is the honest answer rather
// than a gap: the family's signal side is `story:chain` and `id:resolve`, which
// live in packages/sdk/src/receivers.ts and are addressed as `story:chain`, not
// as a story-named file. Seven of the eleven land on `thing`, the dimension-3
// catch-all — a data artifact, a library, a page, a Move object, an agent and a
// test are all Things, and stretching one of them onto `component` or
// `function` would put a lie in the card `id:resolve` projects.
const KIND_RULES = [
  [(p) => path.basename(p) === 'SKILL.md', 'skill', 'a SKILL.md is a skill'],
  [(p) => p.endsWith('.tql') && /\/workflows\//.test(p), 'workflow', 'a .tql under */workflows/ is a workflow'],
  [(p) => p.endsWith('.tql') && p.startsWith('schema/'), 'function', 'a .tql under schema/ declares funs'],
  [(p) => p.endsWith('.tsx') && /\/components\//.test(p), 'component', 'a .tsx under */components/ is a component'],
  [(p) => p.endsWith('.md') && p.startsWith('text/'), 'doc', 'a .md under text/ is a document'],
]
function kindOf(p) {
  for (const [test, kind, rule] of KIND_RULES) if (test(p)) return { kind, rule }
  return { kind: 'thing', rule: 'the dimension-3 catch-all — never `object`' }
}

// This card is itself one of the eleven, and it is written LAST — so a plain
// existsSync said `exists:false` for `one.ie/web/src/data/story.json` at the
// instant that very file was being written, and the next --check went red
// reporting `committed=thing/false fresh=thing/true` forever (measured). The
// file's presence is what running this script guarantees, so the self-reference
// answers true. Every other path is probed on disk.
const SELF = path.relative(REPO_ROOT, OUT_STORY)

function buildStory() {
  const paths = familyPaths()
  const files = paths.map((p) => {
    const { kind, rule } = kindOf(p)
    return { path: p, kind, rule, exists: p === SELF ? true : existsSync(R(p)) }
  })
  return {
    slug: 'story',
    name: 'Story',
    summary:
      'One slug, every technology — the eleven files text/story.md promises, each the best of its own technology. A told story generates this family for the teller\'s own slug.',
    source: 'text/story.md',
    generated_at: headSha(),
    count: files.length,
    present: files.filter((f) => f.exists).length,
    files,
  }
}

// ── check ───────────────────────────────────────────────────────────────────
const stripStamp = (o) => {
  const { generated_at: _drop, ...rest } = o
  return rest
}

function diffOne(label, outPath, fresh) {
  if (!existsSync(outPath)) {
    return [`- ${outPath} does not exist — run without --check first to seed it.`]
  }
  const committed = JSON.parse(readFileSync(outPath, 'utf8'))
  if (JSON.stringify(stripStamp(committed)) === JSON.stringify(stripStamp(fresh))) return []
  const lines = [`~ ${outPath} out of date — run: node .claude/scripts/id-inventory.mjs`]
  // Say WHICH kind moved. A bare "out of date" makes the reader diff a 300KB
  // file by hand, which is how a generated artifact stops being regenerated.
  if (label === 'inventory') {
    const byKind = (o) => Object.fromEntries((o.kinds ?? []).map((k) => [k.kind, k.count]))
    const a = byKind(committed)
    const b = byKind(fresh)
    for (const kind of new Set([...Object.keys(a), ...Object.keys(b)])) {
      if (a[kind] !== b[kind]) lines.push(`  ~ ${kind}: committed=${a[kind]} fresh=${b[kind]}`)
    }
    // A kind whose COUNT is unchanged can still have drifted — a receiver
    // whose summary was reworded moves no number. Report it, or the reader
    // reads "out of date" against seven identical counts and assumes a bug.
    for (const kind of Object.keys(fresh.entries ?? {})) {
      const ca = (committed.entries ?? {})[kind]
      const cb = (fresh.entries ?? {})[kind]
      if (ca && cb && a[kind] === b[kind] && JSON.stringify(ca) !== JSON.stringify(cb)) {
        lines.push(`  ~ ${kind}: same count (${b[kind]}), different entries`)
      }
    }
  } else {
    const byPath = (o) => Object.fromEntries((o.files ?? []).map((f) => [f.path, `${f.kind}/${f.exists}`]))
    const a = byPath(committed)
    const b = byPath(fresh)
    for (const p of new Set([...Object.keys(a), ...Object.keys(b)])) {
      if (a[p] !== b[p]) lines.push(`  ~ ${p}: committed=${a[p] ?? '(absent)'} fresh=${b[p] ?? '(absent)'}`)
    }
  }
  // The per-item loops above key on a SUBSET of each file (a kind's count, a
  // file's kind+exists). Anything outside that key — `rule`, `present`, `slug`,
  // `summary`, `source`, `id_prefix` — differs without producing a line, and the
  // reader gets a bare "out of date" header and diffs a 285KB file by hand.
  // Whatever the comparator missed, name the top-level fields that moved.
  if (lines.length === 1) {
    const keys = new Set([...Object.keys(committed), ...Object.keys(fresh)])
    const moved = [...keys]
      .filter((k) => k !== 'generated_at')
      .filter((k) => JSON.stringify(committed[k]) !== JSON.stringify(fresh[k]))
    lines.push(
      moved.length > 0
        ? `  ~ fields differ (below the per-item comparator): ${moved.join(', ')}`
        : `  ~ differs only in key ORDER or in generated_at handling — regenerate`,
    )
  }
  return lines
}

function main() {
  const inventory = buildInventory()
  const story = buildStory()

  if (CHECK) {
    const diff = [
      ...diffOne('inventory', OUT_INVENTORY, inventory),
      ...diffOne('story', OUT_STORY, story),
    ]
    if (diff.length > 0) {
      console.error('id-inventory --check: drift detected')
      for (const line of diff) console.error(line)
      process.exit(1)
    }
    const counts = inventory.kinds.map((k) => `${k.kind}=${k.count ?? 'graph'}`).join(' ')
    console.log(`id-inventory --check: ok (no drift) — kinds=${inventory.kinds.length} ${counts} story.files=${story.count} present=${story.present}`)
    process.exit(0)
  }

  mkdirSync(path.dirname(OUT_INVENTORY), { recursive: true })
  writeFileSync(OUT_INVENTORY, JSON.stringify(inventory, null, 2) + '\n')
  writeFileSync(OUT_STORY, JSON.stringify(story, null, 2) + '\n')
  const counts = inventory.kinds.map((k) => `${k.kind}=${k.count ?? 'graph'}`).join(' ')
  console.log(`wrote ${OUT_INVENTORY} — kinds=${inventory.kinds.length} ${counts}`)
  console.log(`wrote ${OUT_STORY} — files=${story.count} present=${story.present}`)
}

main()
