#!/usr/bin/env node
// The React-free block vocabulary — text/blocks-todo.md C5 deliverable.
//
// Reads the (post-cut, C4) registry via the same tsx-import technique
// blocks-usage.mjs uses (bunx tsx against the absolute config.tsx path, so
// the file's own `@/` imports resolve exactly as they do in the app), pulls
// `pagesUsing` from the committed block-usage.json so the manifest carries a
// usage-ranked list, and writes one.ie/web/src/lib/puck/block-manifest.json —
// a plain-data file `channels/` can import with zero React/Puck runtime deps.
//
// Three artifacts, one build, all three checked: the manifest (the whole
// vocabulary, read by tooling), channels/src/generated/block-enum.ts (what the
// model is told), and one.ie/web/src/lib/puck/block-schema.generated.ts (what
// the browser normalises the streaming preview against).
//
// --check: regenerate in memory and diff against the committed file. No
// network access — everything it reads is local (config.tsx, block-usage.json).
//
// Usage:
//   node .claude/scripts/blocks-manifest.mjs           # write the file
//   node .claude/scripts/blocks-manifest.mjs --check    # diff, no write

import { execFileSync } from 'node:child_process'
import { writeFileSync, readFileSync, existsSync, mkdirSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const REPO_ROOT = path.resolve(__dirname, '../..')
const WEB_DIR = path.join(REPO_ROOT, 'one.ie/web')
const CONFIG_PATH = path.join(WEB_DIR, 'src/lib/puck/config.tsx')
const FAMILIES_PATH = path.join(WEB_DIR, 'src/lib/puck/families.ts')
const USAGE_PATH = path.join(WEB_DIR, 'src/lib/puck/block-usage.json')
const OUT_PATH = path.join(WEB_DIR, 'src/lib/puck/block-manifest.json')
const ENUM_PATH = path.join(REPO_ROOT, 'channels/src/generated/block-enum.ts')
const SCHEMA_PATH = path.join(WEB_DIR, 'src/lib/puck/block-schema.generated.ts')

const args = process.argv.slice(2)
const CHECK = args.includes('--check')

// Chat-fit mapping mirrors src/lib/puck/chat-fit.ts's CHAT_FITS exactly — this
// script has no `@/` alias of its own to import that module from, and the
// fallback here matches chatFitFor's fallback ('compact' for anything unknown).
const CHAT_FITS = {
  atomic: 'inline',
  container: 'compact',
  'social-preview': 'compact',
  app: 'compact',
  section: 'full',
}

function readRegistry() {
  const tmp = mkdtempSync(path.join(tmpdir(), 'blocks-manifest-'))
  const runner = path.join(tmp, 'entries.mjs')
  writeFileSync(
    runner,
    [
      `import { puckConfig, PRE_COLLAPSE_COMPONENTS } from ${JSON.stringify(CONFIG_PATH)}`,
      `import { BLOCK_FAMILIES } from ${JSON.stringify(FAMILIES_PATH)}`,
      // A prop whose legal values are a closed set is only usable by an agent
      // if the set travels with the name. `type: select | radio` is exactly
      // that shape in Puck, so every one of them publishes its values — a
      // rule, not a special case for `variant`.
      'const optionValuesOf = (fields) => {',
      '  const out = {}',
      '  for (const [key, f] of Object.entries(fields || {})) {',
      '    if (!f || (f.type !== "select" && f.type !== "radio")) continue',
      '    if (!Array.isArray(f.options) || f.options.length === 0) continue',
      // Values are published RAW, not stringified: a select over booleans
      // (`featured`) or numbers is legal in Puck, and "false" is not false.
      '    out[key] = f.options.map((o) => {',
      '      const v = o && typeof o === "object" ? o.value : o',
      '      return typeof v === "string" || typeof v === "number" || typeof v === "boolean" ? v : String(v)',
      '    })',
      '  }',
      '  return out',
      '}',
      // The reachable variant vocabulary of a COLLAPSED family is its
      // families.ts member list, NOT the collapsed block's own
      // `fields.variant.options`. collapseFamilies spreads `canonicalDef.fields`
      // LAST, so on any family whose canonical member already declared a
      // `variant` select of its own, the canonical's values overwrite the
      // family's — measured on Hero, Features, Stats and Cta (2026-08-18).
      // Those overwritten values are NOT reachable: collapse's render is
      // `byVariant[variant] ?? canonicalDef` with `variant` stripped, so
      // Hero/"agency" renders the default Hero and the picked value is lost.
      // BLOCK_FAMILIES is the declaration of record; the manifest publishes it.
      // A member whose OWN fields carry a `type: "slot"` is unreachable from a
      // chat turn (see buildManifest's note) — publishing its variant would
      // advertise a value the model can pick and nothing can render. Only a
      // REGISTERED member is tested: an absent one has no fields to read, and
      // dropping it here would be a second, unrelated cut.
      'const hasSlotDef = (def) => Object.values(def?.fields || {}).some((f) => f && f.type === "slot")',
      'const familyVariants = {}',
      'for (const family of Object.values(BLOCK_FAMILIES)) {',
      '  const usable = Object.entries(family.members)',
      '    .filter(([member]) => !hasSlotDef(PRE_COLLAPSE_COMPONENTS[member]))',
      '    .map(([, variant]) => variant)',
      '  familyVariants[family.canonical] = [...new Set(usable)]',
      '}',
      // The per-VARIANT field sets — the half of the vocabulary the collapsed
      // registration destroys. `collapseFamilies` unions every member's fields
      // into one registration, so `declaredProps` on a family is a SUPERSET of
      // what any single member's render reads: Hero declares both `headline`
      // (HeroVideoDialog) and `heading` (every other member), and a model that
      // fills `headline` on variant 'centered' gets silent default copy —
      // measured 2026-08-19 on a real prod turn, where every one of six
      // generated fields was invisible. What renders is `byVariant[variant]`,
      // so what an agent must be told is that member's OWN fields.
      'const CHROME = new Set(["bgEffect", "bgPattern", "bgToken", "variant"])',
      'const fieldSpecs = (def) => {',
      '  const out = {}',
      '  for (const [key, f] of Object.entries(def?.fields || {})) {',
      '    if (CHROME.has(key)) continue',
      // A slot field needs Puck's DropZone pipeline — unfillable from a chat
      // turn, same rule buildManifest applies to a whole slot-carrying block.
      '    if (!f || f.type === "slot") continue',
      '    const spec = { type: typeof f.type === "string" ? f.type : "text" }',
      '    if (f.type === "array") spec.of = Object.keys(f.arrayFields || {})',
      '    if (f.type === "select" || f.type === "radio") {',
      '      const values = optionValuesOf({ [key]: f })[key]',
      '      if (values) spec.options = values',
      '    }',
      '    out[key] = spec',
      '  }',
      '  return out',
      '}',
      // Mirrors collapse.ts canonicalVariantOf exactly: a member literally
      // carrying 'default' wins, else the first member declared.
      'const canonicalVariantOf = (members) => {',
      '  const values = Object.values(members)',
      '  return values.includes("default") ? "default" : values[0]',
      '}',
      'const familyOf = {}',
      'for (const family of Object.values(BLOCK_FAMILIES)) familyOf[family.canonical] = family',
      'const variantSchema = (name) => {',
      '  const family = familyOf[name]',
      '  if (!family) return { canonicalVariant: null, variants: { "": { fields: fieldSpecs(PRE_COLLAPSE_COMPONENTS[name]), semantics: PRE_COLLAPSE_COMPONENTS[name]?.metadata?.semantics || {}, renders: PRE_COLLAPSE_COMPONENTS[name]?.metadata?.renders || {} } } }',
      '  const variants = {}',
      '  for (const [member, variant] of Object.entries(family.members)) {',
      '    const def = PRE_COLLAPSE_COMPONENTS[member]',
      '    if (!def) continue',
      // Same filter as familyVariants above, and it has to be the same: BLOCK_SCHEMA
      // (built from `variants`) is what normalizeBlockProps maps a payload against,
      // and it falls back to canonicalVariant for a variant it does not know. Leaving
      // a slot member in `variants` while dropping it from `options.variant` would
      // publish it in BLOCK_FIELD_DOC and normalise props onto it while the enum
      // rejected the value — the two halves of one generated file disagreeing.
      '    if (hasSlotDef(def)) continue',
      '    variants[variant] = { fields: fieldSpecs(def), semantics: def.metadata?.semantics || {}, renders: def.metadata?.renders || {} }',
      '  }',
      '  return { canonicalVariant: canonicalVariantOf(family.members), variants }',
      '}',
      'const out = {}',
      // Whether a block can enter the chat vocabulary at all. For a non-family
      // block this is exactly the old rule (its own fields carry no slot). For a
      // COLLAPSED family the old rule was wrong: the union inherits a slot from
      // any one member, so ProductDetail's `children` hid all nine Product
      // renders. What renders is byVariant[variant], so the question is asked of
      // the members — the family enters as long as it has a slot-free member to
      // publish AND its canonical member is one of them (a slot-carrying
      // canonical would make a no-variant call unrenderable, and it is the value
      // normalizeBlockProps falls back to; no family is in that shape today).
      'const memberForVariant = (family, variant) => (Object.entries(family.members).find(([, v]) => v === variant) || [])[0]',
      'const chatableOf = (name, block, vs) => {',
      '  const family = familyOf[name]',
      '  if (!family) return !Object.values(block.fields || {}).some((f) => f && f.type === "slot")',
      '  if (hasSlotDef(PRE_COLLAPSE_COMPONENTS[memberForVariant(family, vs.canonicalVariant)])) return false',
      '  return Object.keys(vs.variants).length > 0',
      '}',
      'for (const [name, block] of Object.entries(puckConfig.components)) {',
      '  const m = block.metadata || {}',
      '  const vs = variantSchema(name)',
      '  const options = optionValuesOf(block.fields)',
      '  if (familyVariants[name]) options.variant = familyVariants[name]',
      '  out[name] = {',
      '    category: typeof m.category === "string" ? m.category : "content",',
      '    icon: typeof m.icon === "string" ? m.icon : "Square",',
      '    description: typeof m.description === "string" ? m.description : "",',
      '    surface: typeof m.surface === "string" ? m.surface : null,',
      '    declaredProps: Object.keys(block.fields || {}).sort(),',
      '    options,',
      '    ...vs,',
      '    chatable: chatableOf(name, block, vs),',
      '  }',
      '}',
      'console.log(JSON.stringify(out))',
    ].join('\n'),
  )
  try {
    const out = execFileSync('bunx', ['tsx', runner], { cwd: WEB_DIR, encoding: 'utf8' })
    return JSON.parse(out.trim())
  } finally {
    rmSync(tmp, { recursive: true, force: true })
  }
}

function readUsage() {
  if (!existsSync(USAGE_PATH)) return {}
  return JSON.parse(readFileSync(USAGE_PATH, 'utf8')).blocks ?? {}
}

function buildManifest() {
  const registry = readRegistry()
  const usage = readUsage()
  const blocks = {}
  for (const [name, entry] of Object.entries(registry)) {
    // A `type: 'slot'` field (Columns, Grid) needs Puck's own <Render> DropZone
    // pipeline to resolve — outside a real page it stays a raw array and
    // BlockFrame throws. Nothing to stream into an empty layout container in
    // one chat turn anyway, so it never enters the chat vocabulary. Decided
    // per MEMBER for a collapsed family (`chatableOf` in the runner above),
    // because the collapsed field union inherits a slot from any one of them.
    if (!entry.chatable) continue
    const { chatable: _drop, ...rest } = entry
    blocks[name] = {
      ...rest,
      chatFit: entry.surface ? (CHAT_FITS[entry.surface] ?? 'compact') : 'compact',
      pagesUsing: usage[name]?.pagesUsing ?? 0,
    }
  }
  return {
    measuredAt: new Date().toISOString().slice(0, 10),
    count: Object.keys(blocks).length,
    blocks,
  }
}

function diffManifests(committed, fresh) {
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
    const sameProps = JSON.stringify(a.declaredProps) === JSON.stringify(b.declaredProps)
    // `options` carries the legal values — the half of the vocabulary an agent
    // cannot guess. Leaving it out of the diff would let it rot silently,
    // which is the exact defect publishing it exists to close.
    const sameOptions = JSON.stringify(a.options ?? {}) === JSON.stringify(b.options ?? {})
    // `variants` carries the per-member field sets — the vocabulary an agent
    // fills a block WITH. Same rule as `options`: out of the diff means it
    // rots silently, and a rotted field name renders default copy in chat with
    // nothing red anywhere.
    const sameVariants = JSON.stringify(a.variants ?? {}) === JSON.stringify(b.variants ?? {})
    if (
      !sameOptions ||
      !sameVariants ||
      a.canonicalVariant !== b.canonicalVariant ||
      a.category !== b.category ||
      a.icon !== b.icon ||
      a.description !== b.description ||
      a.surface !== b.surface ||
      a.chatFit !== b.chatFit ||
      a.pagesUsing !== b.pagesUsing ||
      !sameProps
    ) {
      lines.push(`~ ${name} committed=${JSON.stringify(a)} fresh=${JSON.stringify(b)}`)
    }
  }
  if (committed.count !== fresh.count) lines.push(`~ count committed=${committed.count} fresh=${fresh.count}`)
  return lines
}

// The channels-side enum. `z.enum()` needs a LITERAL TUPLE, so this is a .ts
// source rather than a second JSON copy — a JSON import types as string[] and
// would need a cast at the tool boundary. Emitting it here also means channels
// never imports across the web bundle root, which is what keeps `wrangler
// deploy --dry-run` green by construction rather than by luck.
//
// Ranked pagesUsing DESC then name ASC: the model reads the blocks people
// actually choose first, which is the whole point of ranking rather than
// truncating (a rare block stays reachable, it is just further down).
function buildEnumSource(manifest) {
  const names = Object.entries(manifest.blocks)
    .sort((a, b) => b[1].pagesUsing - a[1].pagesUsing || (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0))
    .map(([name]) => name)
  // The variant vocabulary rides along in the SAME generated file. A block's
  // `variant` names WHICH of a collapsed family's members renders, and an
  // undeclared value is not an error anywhere downstream — collapseFamilies
  // falls back to the canonical member, so a wrong guess renders a
  // plausible-looking wrong block in silence. Publishing the legal values here
  // is what lets emit_block reject one loudly instead.
  const variants = Object.entries(manifest.blocks)
    .map(([name, entry]) => [name, entry.options?.variant])
    .filter(([, values]) => Array.isArray(values) && values.length > 0 && values.every((v) => typeof v === 'string'))
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0))
  // The per-variant field schema. `variant` picks WHICH member renders, and
  // that member reads its OWN fields — the collapsed registration's union is a
  // superset, so a prop that survives the union filter can still be invisible.
  // Measured 2026-08-19 against a real prod turn: the model wrote six fields of
  // hero copy (`headline`, `subheadline`, `primaryCta`, `badge`, …) and the
  // browser rendered HeroCentered's defaults — 0 of 6 visible. This table is
  // what closes that: it is the truth `emit_block` normalises and rejects
  // against, and the truth the tool description publishes.
  const schemaEntries = Object.entries(manifest.blocks)
    .filter(([, e]) => e.variants && Object.keys(e.variants).length > 0)
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0))

  // The vocabulary the MODEL reads, one line per renderable member:
  //   Hero/centered: badgeLabel heading subheading primaryCtaLabel …
  //   Faq/default: title faqs[q|a]
  // Array fields publish their item keys inline, because those are the half no
  // agent can guess (`Faq/default` takes `faqs[q|a]`, `Faq/simple` takes
  // `items[question|answer]` — same family, incompatible payloads).
  const docLines = []
  for (const [name, entry] of schemaEntries) {
    for (const [variant, spec] of Object.entries(entry.variants)) {
      const fields = Object.entries(spec.fields ?? {})
      if (fields.length === 0) continue
      // A `fields` entry is the EDITOR's form; `metadata.renders` names what the
      // RENDER reads and the form cannot express (Puck has no nested string-array,
      // so `PricingSection` renders `tiers[].features` and can never declare it).
      // The model has no such constraint, so the published item list is the union
      // — measured by .claude/scripts/blocks-render-probe.mjs, 2026-08-20.
      const renders = spec.renders ?? {}
      const body = fields
        .map(([key, f]) => {
          if (f.type !== 'array') return key
          const items = [...(f.of ?? []), ...(renders[key] ?? [])]
          return `${key}[${items.join('|')}]`
        })
        .join(' ')
      docLines.push(`${variant ? `${name}/${variant}` : name}: ${body}`)
    }
  }

  return [
    '// GENERATED by .claude/scripts/blocks-manifest.mjs — do not edit by hand.',
    '// Every block in the Puck registry, ranked by pagesUsing (desc), then name.',
    `// count=${names.length}`,
    '',
    'export const BLOCK_NAMES = [',
    ...names.map((name) => `  '${name}',`),
    '] as const',
    '',
    `// The legal \`variant\` values per block — ${variants.length} of the ${names.length} take one.`,
    '// Source: BLOCK_FAMILIES (one.ie/web/src/lib/puck/families.ts) for a collapsed',
    "// family, the field's own options for a block that just has a variant select.",
    'export const BLOCK_VARIANTS: Record<string, readonly string[]> = {',
    ...variants.map(([name, values]) => `  ${name}: [${values.map((v) => `'${v}'`).join(', ')}],`),
    '}',
    '',
    'export interface BlockFieldSpec {',
    "  /** Puck field type — 'text' | 'textarea' | 'array' | 'select' | 'radio' | 'number' | … */",
    '  type: string',
    '  /** For `type: "array"` — the keys each ITEM object takes. */',
    '  of?: readonly string[]',
    '  /** For `type: "select" | "radio"` — the legal values. */',
    '  options?: readonly (string | number | boolean)[]',
    '}',
    '',
    'export interface BlockVariantSpec {',
    '  /** The fields the member that renders this variant actually reads. */',
    '  fields: Record<string, BlockFieldSpec>',
    "  /** The block's own role -> prop declaration (heading/body/cta/image). */",
    '  semantics: Record<string, string>',
    '  /** Props the RENDER reads that the editor\'s fields cannot express, keyed',
    '   * by the array field they belong to (Puck has no nested string-array, so',
    '   * PricingSection renders tiers[].features and can never declare it). */',
    '  renders?: Record<string, readonly string[]>',
    '}',
    '',
    'export interface BlockSchemaEntry {',
    '  /** The variant that renders when none is sent. null for a non-family block. */',
    '  canonicalVariant: string | null',
    "  /** Keyed by variant value; the single key '' for a non-family block. */",
    '  variants: Record<string, BlockVariantSpec>',
    '}',
    '',
    '// What each variant\'s RENDERING MEMBER reads. The collapsed registration',
    '// unions every member\'s fields, so a prop can be declared on the family and',
    '// still invisible on the member that renders — this is the per-member truth.',
    'export const BLOCK_SCHEMA: Record<string, BlockSchemaEntry> = {',
    ...schemaEntries.map(([name, entry]) => `  ${JSON.stringify(name)}: ${JSON.stringify({ canonicalVariant: entry.canonicalVariant ?? null, variants: entry.variants })},`),
    '}',
    '',
    `// The same table as prose, for the tool description the model reads — ${docLines.length} members.`,
    'export const BLOCK_FIELD_DOC = ' + JSON.stringify(docLines.join('\n')),
    '',
  ].join('\n')
}

// The BROWSER half of the same schema. `MessageList` draws the model's PARTIAL
// tool input through `BlockFrame` while it streams — before `emit_block.execute`
// and its normalisation have run — so a mis-named prop painted placeholder copy
// for the length of the stream and snapped to the real text when the output
// frame landed. `BlockFrame` now runs the SAME `normalizeBlockProps` against
// this table, so both frames show the same copy.
//
// Slim on purpose: only the four things normalizeBlockProps reads —
// `canonicalVariant`, `variants[v].fields[name].type`, `.of`, and
// `variants[v].semantics`. `options`, descriptions, categories and icons stay
// in block-manifest.json (407,908 bytes, measured 2026-09-21 — it read 202,196
// on 2026-08-19, so re-measure before quoting it). That file is imported by
// exactly ONE `src/` module and it is SERVER-ONLY: `lib/resolvers/blocks.ts`,
// the `blocks:list` / `blocks:schema` door, which never reaches a browser
// bundle. Keep it that way — THIS module ships in the chat island on every
// page, which is the whole reason it stays slim.
//
// Emitted as a .ts source, not JSON, so it carries the SDK's `BlockSchema`
// type and a shape drift fails tsc instead of failing silently at render.
function buildSchemaSource(manifest) {
  const entries = Object.entries(manifest.blocks)
    .filter(([, e]) => e.variants && Object.keys(e.variants).length > 0)
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0))

  let members = 0
  const rows = entries.map(([name, entry]) => {
    const variants = {}
    for (const [variant, spec] of Object.entries(entry.variants)) {
      members++
      const fields = {}
      for (const [key, f] of Object.entries(spec.fields ?? {})) {
        // `of` is the only per-field detail the normaliser uses beyond the
        // name — it remaps ARRAY ITEM keys (`faqs[q|a]` vs `items[question|
        // answer]`). `options` is a tool-description concern, not a render one.
        fields[key] = f.type === 'array' ? { type: f.type, of: f.of ?? [] } : { type: f.type }
      }
      // Always emitted, empty or not: `BlockVariantSpec.semantics` is required,
      // so omitting it would need a cast and lose the type check this file is
      // emitted as .ts to get.
      variants[variant] = { fields, semantics: spec.semantics ?? {} }
    }
    return `  ${JSON.stringify(name)}: ${JSON.stringify({
      canonicalVariant: entry.canonicalVariant ?? null,
      variants,
    })},`
  })

  return [
    '// GENERATED by .claude/scripts/blocks-manifest.mjs — do not edit by hand.',
    '// The fields each variant\'s RENDERING MEMBER reads, for the streaming',
    '// preview. Puck\'s family collapse UNIONS every member\'s fields into one',
    '// registration, so a prop can be declared on the family and still be',
    '// invisible on the member that renders — this is the per-member truth.',
    `// blocks=${entries.length} members=${members}`,
    '',
    "import type { BlockSchema } from '@oneie/sdk/blocks'",
    '',
    'export const BLOCK_SCHEMA: BlockSchema = {',
    ...rows,
    '}',
    '',
  ].join('\n')
}

function main() {
  if (CHECK) {
    if (!existsSync(OUT_PATH)) {
      console.error(`blocks-manifest --check: ${OUT_PATH} does not exist — run without --check first to seed it.`)
      process.exit(1)
    }
    const committed = JSON.parse(readFileSync(OUT_PATH, 'utf8'))
    const fresh = buildManifest()
    const diff = diffManifests(committed, fresh)
    // The enum is part of the same artifact: emitting it without checking it
    // builds a file that silently rots, which is exactly what the manifest
    // exists to prevent.
    const enumFresh = buildEnumSource(fresh)
    const enumCommitted = existsSync(ENUM_PATH) ? readFileSync(ENUM_PATH, 'utf8') : ''
    if (enumCommitted !== enumFresh) {
      diff.push(`~ ${ENUM_PATH} out of date — run: node .claude/scripts/blocks-manifest.mjs`)
    }
    // Same rule for the web-side schema: an emitted file that nothing compares
    // is a file that rots, and a rotted field name here renders default copy in
    // the streaming preview with nothing red anywhere.
    const schemaFresh = buildSchemaSource(fresh)
    const schemaCommitted = existsSync(SCHEMA_PATH) ? readFileSync(SCHEMA_PATH, 'utf8') : ''
    if (schemaCommitted !== schemaFresh) {
      diff.push(`~ ${SCHEMA_PATH} out of date — run: node .claude/scripts/blocks-manifest.mjs`)
    }
    if (diff.length > 0) {
      console.error('blocks-manifest --check: drift detected')
      for (const line of diff) console.error(line)
      process.exit(1)
    }
    console.log('blocks-manifest --check: ok (no drift)')
    process.exit(0)
  }

  const manifest = buildManifest()
  writeFileSync(OUT_PATH, JSON.stringify(manifest, null, 2) + '\n')
  mkdirSync(path.dirname(ENUM_PATH), { recursive: true })
  writeFileSync(ENUM_PATH, buildEnumSource(manifest))
  writeFileSync(SCHEMA_PATH, buildSchemaSource(manifest))
  console.log(`wrote ${OUT_PATH} — count=${manifest.count}`)
  console.log(`wrote ${ENUM_PATH}`)
  console.log(`wrote ${SCHEMA_PATH}`)
}

main()
