#!/usr/bin/env node
// Measures the gap between what a Puck block DECLARES and what it READS.
//
// A `fields` declaration is the EDITOR's form, not the render's prop list, so a
// component can read a prop it never declared — and that prop is then invisible
// to every static reader of the registry (block-manifest.json, BLOCK_SCHEMA,
// the emit_block tool description). No analysis of `fields` can find it; the
// only oracle is the rendered output. Known instance: PricingSection renders
// `tiers[].features` and declares no such item field.
//
// The technique is blocks-manifest.mjs's: `bunx tsx` against the absolute
// config.tsx path from a temp runner, so the file's own `@/` imports resolve
// exactly as they do in the app. Nothing is written to the repo — this script
// only measures, and prints.
//
// Usage:
//   node .claude/scripts/blocks-render-probe.mjs               # human summary
//   node .claude/scripts/blocks-render-probe.mjs --json        # machine form
//   node .claude/scripts/blocks-render-probe.mjs --only Hero   # one family/block
//   node .claude/scripts/blocks-render-probe.mjs --limit 20    # first N members
//   node .claude/scripts/blocks-render-probe.mjs --control     # positive control
//   node .claude/scripts/blocks-render-probe.mjs --extra tone,badge  # widen the set
//
// Redirect stdout to a file rather than piping it — a full run's JSON is large
// enough to hit the SIGPIPE-141 trap documented in .claude/CLAUDE.md.

import { execFileSync } from 'node:child_process'
import { writeFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const REPO_ROOT = path.resolve(__dirname, '../..')
const WEB_DIR = path.join(REPO_ROOT, 'one.ie/web')
const CONFIG_PATH = path.join(WEB_DIR, 'src/lib/puck/config.tsx')
const FAMILIES_PATH = path.join(WEB_DIR, 'src/lib/puck/families.ts')

const args = process.argv.slice(2)
const JSON_OUT = args.includes('--json')
const onlyAt = args.indexOf('--only')
const ONLY = onlyAt >= 0 ? (args[onlyAt + 1] ?? '') : ''
const limitAt = args.indexOf('--limit')
const LIMIT = limitAt >= 0 ? Number(args[limitAt + 1] ?? 0) : 0
// The positive control. A probe that finds nothing proves nothing until it is
// shown able to find something: --control re-runs the identical machinery
// against each member's OWN DECLARED text fields, which the render is supposed
// to read. Its detection rate is the ceiling on what the real run could have
// seen — every point below 100% is a member the probe is partly blind to.
const CONTROL = args.includes('--control')
// The candidate set is the ceiling on what this can find, so it has to be
// extendable without editing the snapshot below.
const extraAt = args.indexOf('--extra')
const EXTRA = extraAt >= 0 ? (args[extraAt + 1] ?? '').split(',').map((s) => s.trim()).filter(Boolean) : []

// Snapshot of the two candidate tables in packages/sdk/src/blocks.ts — the
// KEY_ROLE keys (every name a model has been OBSERVED to reach for) plus the
// ROLE_FIELDS values (the real repo field names those roles resolve to).
// Copied rather than imported because neither is exported from that module, so
// this is a snapshot: a name added to blocks.ts does not appear here by itself.
const COMMON_CANDIDATES = [
  'headline', 'heading', 'title', 'header', 'h1', 'name',
  'subheadline', 'subheading', 'subhead', 'subtitle', 'subline',
  'description', 'body', 'text', 'copy', 'blurb', 'summary', 'tagline', 'content',
  'eyebrow', 'kicker', 'overline',
  'badge', 'badgetext', 'badgelabel', 'pill', 'tag',
  'cta', 'ctatext', 'ctalabel', 'buttontext', 'buttonlabel',
  'primarycta', 'primaryctatext', 'primaryctalabel', 'action',
  'secondarycta', 'secondaryctatext', 'secondaryctalabel',
  'href', 'url', 'link', 'ctahref', 'primaryctahref', 'secondaryctahref',
  'image', 'imageurl', 'imagesrc', 'img', 'photo', 'src', 'picture', 'avatar', 'avatarurl',
  'icon', 'price', 'amount', 'cost', 'value', 'role', 'company',
  'question', 'q', 'answer', 'a',
  'label', 'detail', 'quote', 'trustLabel', 'badgeLabel',
  'primaryCtaLabel', 'ctaLabel', 'submitLabel', 'playLabel', 'primaryCta', 'ctaText',
  'secondaryCtaLabel', 'secondaryCta', 'ctaHref', 'primaryCtaHref', 'secondaryCtaHref', 'href2',
  'imageUrl', 'imageSrc', 'mediaImage', 'mockupImage', 'thumbnailImage', 'visual',
  'avatarUrl', 'coverImage', 'monthlyPrice', 'position',
]

// No template literals and no `${` inside this body — it is itself interpolated
// into the runner file, and only the two import paths may cross that boundary.
const RUNNER_BODY = String.raw`
const CHROME = new Set(['bgToken', 'bgPattern', 'bgEffect', 'variant', 'children', 'puck', 'id', 'editMode'])
const ONLY = process.env.PROBE_ONLY || ''
const LIMIT = Number(process.env.PROBE_LIMIT || 0)
const COMMON = JSON.parse(process.env.PROBE_CANDIDATES || '[]')
const CONTROL = process.env.PROBE_MODE === 'control'
const isTextField = (spec) => spec && (spec.type === 'text' || spec.type === 'textarea')

// React logs an unknown-prop warning per probe render; at ~10k renders that is
// the slowest thing in the run and none of it is a result.
console.error = () => {}
console.warn = () => {}

let seq = 0
const nextSentinel = () => 'ZQP' + (++seq).toString(36) + 'QZ'
const stripTags = (html) => html.replace(/<[^>]*>/g, ' ')

// A canary is a name no component could plausibly read. If its value reaches
// the markup, the member spreads unknown props onto a DOM element and every
// candidate would "land" — the member is unprobeable, not clean. Only a STRING
// canary is sensitive: React drops non-string values from a DOM spread, so an
// array-shaped canary can go quiet on a member that genuinely spreads.
const CANARY_KEYS = ['zqCanaryAlphaProp', 'zqCanaryBetaProp']

const familyOf = {}
for (const family of Object.values(BLOCK_FAMILIES)) {
  for (const [member, variant] of Object.entries(family.members)) {
    familyOf[member] = { canonical: family.canonical, variant, members: Object.keys(family.members) }
  }
}

const defOf = (name) => PRE_COLLAPSE_COMPONENTS[name]
const fieldsOf = (name) => (defOf(name) && defOf(name).fields) || {}

function renderOf(def, props) {
  return renderToStaticMarkup(createElement(def.render, props))
}

function tryRender(def, props) {
  try {
    return { html: renderOf(def, props), threw: null }
  } catch (err) {
    return { html: null, threw: String((err && err.message) || err).slice(0, 200) }
  }
}

// Shape ladder. A candidate whose value the component never coerces to a child
// (an array field handed a bare string) renders nothing and would read as
// "absent"; trying the plausible shapes in turn is what separates the two.
const OBJ = (s) => ({ label: s, text: s, title: s, name: s, value: s, href: '/' + s })
const TOP_SHAPES = [
  ['string', (s) => s],
  ['array-of-string', (s) => [s]],
  ['array-of-object', (s) => [OBJ(s)]],
  ['object', (s) => OBJ(s)],
]
const ITEM_SHAPES = [
  ['string', (s) => s],
  ['array-of-string', (s) => [s]],
  ['object', (s) => OBJ(s)],
]

/** One candidate, walked down the shape ladder against each base. Stops at the
 *  first combination whose sentinel reaches the markup.
 *
 *  Two bases, because a component that reads 'props.title ?? props.heading' is
 *  invisible to a probe run against defaultProps — the declared 'heading' is
 *  already set, so the fallback never fires and the undeclared 'title' reads as
 *  absent. The STRIPPED base removes every declared text field, which is what
 *  lets that read site answer. */
function probeOne(def, buildProps, candidate, shapes, bases) {
  for (const [baseName, baseProps] of bases) {
    for (const [shapeName, make] of shapes) {
      const sentinel = nextSentinel()
      const { html, threw } = tryRender(def, buildProps(baseProps, candidate, make(sentinel)))
      if (threw || !html) continue
      if (html.includes(sentinel)) {
        return { shape: shapeName, base: baseName, visible: stripTags(html).includes(sentinel) }
      }
    }
  }
  return null
}

/** A copy of props with every declared text/textarea key removed. */
function stripText(props, specs) {
  const out = { ...props }
  for (const [k, spec] of Object.entries(specs || {})) if (isTextField(spec)) delete out[k]
  return out
}

const results = []
let names = Object.keys(PRE_COLLAPSE_COMPONENTS)
if (ONLY) {
  names = names.filter((n) => n === ONLY || (familyOf[n] && familyOf[n].canonical === ONLY))
}
if (LIMIT > 0) names = names.slice(0, LIMIT)

let done = 0
for (const name of names) {
  done++
  if (done % 20 === 0) process.stderr.write('[probe] ' + done + '/' + names.length + '\n')
  const def = defOf(name)
  const fam = familyOf[name]
  const block = fam ? fam.canonical : name
  const variant = fam ? fam.variant : ''
  const key = fam ? block + '/' + variant : block
  const fields = fieldsOf(name)
  const declared = Object.keys(fields)
  const row = { key, block, variant, member: name, findings: [], skipped: null, arrayFieldsProbed: 0, arrayFieldsSkipped: {} }

  if (typeof def.render !== 'function') {
    row.skipped = 'no-render'
    results.push(row)
    continue
  }
  if (Object.values(fields).some((f) => f && f.type === 'slot')) {
    // A slot needs Puck's own DropZone pipeline; outside a page BlockFrame throws.
    row.skipped = 'slot-field'
    results.push(row)
    continue
  }

  const base = def.defaultProps || {}
  const baseline = tryRender(def, base)
  if (baseline.threw) {
    row.skipped = 'baseline-threw'
    row.detail = baseline.threw
    results.push(row)
    continue
  }
  // A lazy() block unwraps to <Suspense fallback={null}> and renders '' without
  // throwing (_block-oracle.ts). It answered nothing; it is not clean.
  if (!baseline.html || baseline.html.length < 20) {
    row.skipped = 'empty-baseline'
    results.push(row)
    continue
  }

  const canaryProps = { ...base }
  const canarySentinels = []
  for (const k of CANARY_KEYS) {
    const s = nextSentinel()
    canarySentinels.push(s)
    canaryProps[k] = s
  }
  const canary = tryRender(def, canaryProps)
  if (canary.html && canarySentinels.some((s) => canary.html.includes(s))) {
    row.skipped = 'spreads-unknown-props'
    results.push(row)
    continue
  }

  // Candidate source (a): every OTHER member's declared field names in the
  // same family. (c): the common-name snapshot from packages/sdk/src/blocks.ts.
  const siblingFields = new Set()
  if (fam) {
    for (const sib of fam.members) {
      if (sib === name) continue
      for (const f of Object.keys(fieldsOf(sib))) siblingFields.add(f)
    }
  }
  const declaredSet = new Set(declared)
  const topCandidates = []
  if (CONTROL) {
    for (const [c, spec] of Object.entries(fields)) {
      if (CHROME.has(c) || !isTextField(spec)) continue
      topCandidates.push(c)
    }
  } else {
    for (const c of [...siblingFields, ...COMMON]) {
      if (declaredSet.has(c) || CHROME.has(c)) continue
      if (topCandidates.includes(c)) continue
      topCandidates.push(c)
    }
  }
  row.candidates = topCandidates.length

  const topBases = [['default', base]]
  const stripped = stripText(base, fields)
  if (Object.keys(stripped).length !== Object.keys(base).length) {
    const sr = tryRender(def, stripped)
    if (!sr.threw && sr.html && sr.html.length >= 20) topBases.push(['stripped', stripped])
  }

  for (const c of topCandidates) {
    const hit = probeOne(def, (b, k, v) => ({ ...b, [k]: v }), c, TOP_SHAPES, topBases)
    if (hit) {
      row.findings.push({
        prop: c,
        where: 'top',
        shape: hit.shape,
        base: hit.base,
        visible: hit.visible,
        declaredElsewhereInFamily: siblingFields.has(c),
      })
    }
  }

  // (b) — array ITEM keys, where the known case lives. The item vocabulary is
  // 'arrayFields', and that is the editor's item form, not the item's prop list.
  for (const [fieldName, spec] of Object.entries(fields)) {
    if (!spec || spec.type !== 'array') continue
    const itemKeys = Object.keys(spec.arrayFields || {})
    const seedItem = Array.isArray(base[fieldName]) && base[fieldName][0] && typeof base[fieldName][0] === 'object'
      ? base[fieldName][0]
      : {}
    const baseItem = { ...seedItem }
    for (const k of itemKeys) if (!(k in baseItem)) baseItem[k] = 'ZQFILL'

    const siblingItemKeys = new Set()
    if (fam) {
      for (const sib of fam.members) {
        if (sib === name) continue
        const sf = fieldsOf(sib)[fieldName]
        if (sf && sf.type === 'array') for (const k of Object.keys(sf.arrayFields || {})) siblingItemKeys.add(k)
      }
    }
    const itemDeclared = new Set(itemKeys)
    const itemCandidates = []
    if (CONTROL) {
      for (const [c, ispec] of Object.entries(spec.arrayFields || {})) {
        if (CHROME.has(c) || !isTextField(ispec)) continue
        itemCandidates.push(c)
      }
    } else {
      for (const c of [...siblingItemKeys, ...COMMON]) {
        if (itemDeclared.has(c) || CHROME.has(c)) continue
        if (itemCandidates.includes(c)) continue
        itemCandidates.push(c)
      }
    }
    // Accounting happens BELOW the three skips, not here: a candidate on a
    // field that was never probed is not a candidate probed, and a member with
    // an unprobeable array field is not a member that answered clean.
    const skipField = (why) => {
      row.arrayFieldsSkipped[why] = (row.arrayFieldsSkipped[why] ?? 0) + 1
    }
    if (itemCandidates.length === 0) {
      skipField('no-item-candidates')
      continue
    }

    const itemCanaryItem = { ...baseItem }
    const itemCanarySentinels = []
    for (const k of CANARY_KEYS) {
      const s = nextSentinel()
      itemCanarySentinels.push(s)
      itemCanaryItem[k] = s
    }
    const itemCanary = tryRender(def, { ...base, [fieldName]: [itemCanaryItem] })
    if (itemCanary.html && itemCanarySentinels.some((s) => itemCanary.html.includes(s))) {
      skipField('item-spreads-unknown-keys')
      continue
    }

    const itemBaseline = tryRender(def, { ...base, [fieldName]: [baseItem] })
    if (itemBaseline.threw || !itemBaseline.html) {
      skipField('item-baseline-empty-or-threw')
      continue
    }

    row.arrayFieldsProbed++
    row.candidates = (row.candidates ?? 0) + itemCandidates.length

    const itemBases = [['default', baseItem]]
    const strippedItem = stripText(baseItem, spec.arrayFields)
    if (Object.keys(strippedItem).length !== Object.keys(baseItem).length) {
      const sr = tryRender(def, { ...base, [fieldName]: [strippedItem] })
      if (!sr.threw && sr.html) itemBases.push(['stripped', strippedItem])
    }

    for (const c of itemCandidates) {
      const hit = probeOne(
        def,
        (b, k, v) => ({ ...base, [fieldName]: [{ ...b, [k]: v }] }),
        c,
        ITEM_SHAPES,
        itemBases,
      )
      if (hit) {
        row.findings.push({
          prop: fieldName + '[].' + c,
          where: 'item',
          field: fieldName,
          itemKey: c,
          shape: hit.shape,
          base: hit.base,
          visible: hit.visible,
          declaredElsewhereInFamily: siblingItemKeys.has(c),
        })
      }
    }
  }

  results.push(row)
}

process.stdout.write(JSON.stringify({ members: names.length, results }))
`

function buildRunner() {
  // The runner lives in a temp dir, so a bare `react` specifier has no
  // node_modules to walk up to. createRequire rooted at one.ie/web resolves the
  // SAME files config.tsx's own ESM imports resolve to (node caches a CJS module
  // by path, so there is one React instance and hooks still work).
  return [
    "import { createRequire } from 'node:module'",
    `const require = createRequire(${JSON.stringify(path.join(WEB_DIR, 'package.json'))})`,
    "const { renderToStaticMarkup } = require('react-dom/server')",
    "const { createElement } = require('react')",
    `import { PRE_COLLAPSE_COMPONENTS } from ${JSON.stringify(CONFIG_PATH)}`,
    `import { BLOCK_FAMILIES } from ${JSON.stringify(FAMILIES_PATH)}`,
    RUNNER_BODY,
  ].join('\n')
}

function runProbe() {
  const tmp = mkdtempSync(path.join(tmpdir(), 'blocks-render-probe-'))
  const runner = path.join(tmp, 'probe.mjs')
  writeFileSync(runner, buildRunner())
  try {
    const out = execFileSync('bunx', ['tsx', runner], {
      cwd: WEB_DIR,
      encoding: 'utf8',
      maxBuffer: 512 * 1024 * 1024,
      stdio: ['ignore', 'pipe', 'inherit'],
      env: {
        ...process.env,
        PROBE_ONLY: ONLY,
        PROBE_LIMIT: String(LIMIT || 0),
        PROBE_MODE: CONTROL ? 'control' : 'gap',
        PROBE_CANDIDATES: JSON.stringify([...new Set([...COMMON_CANDIDATES, ...EXTRA])]),
      },
    })
    return JSON.parse(out.trim())
  } finally {
    rmSync(tmp, { recursive: true, force: true })
  }
}

const HIGH_TRAFFIC = new Set(['Hero', 'Pricing', 'Faq', 'Features', 'Testimonials', 'Stats', 'Cta'])

function report(raw) {
  const rows = raw.results
  const probed = rows.filter((r) => !r.skipped)
  const withFindings = probed.filter((r) => r.findings.length > 0)
  const skippedBy = {}
  for (const r of rows) if (r.skipped) skippedBy[r.skipped] = (skippedBy[r.skipped] ?? 0) + 1

  const findings = []
  for (const r of withFindings) for (const f of r.findings) findings.push({ ...f, key: r.key, member: r.member })
  const visible = findings.filter((f) => f.visible)

  const out = {
    measuredAt: new Date().toISOString().slice(0, 10),
    candidateSet: {
      source: [
        '(a) every OTHER member declared field name in the same BLOCK_FAMILIES family',
        '(b) other members same-named array field arrayFields item keys',
        '(c) snapshot of KEY_ROLE keys + ROLE_FIELDS values from packages/sdk/src/blocks.ts',
      ],
      commonNames: COMMON_CANDIDATES.length,
      extra: EXTRA,
    },
    members: raw.members,
    probed: probed.length,
    couldNotProbe: rows.length - probed.length,
    couldNotProbeBy: skippedBy,
    membersWithUndeclaredProps: withFindings.length,
    findings: findings.length,
    findingsVisibleAsText: visible.length,
    highTrafficAffected: [...new Set(withFindings.map((r) => r.block).filter((b) => HIGH_TRAFFIC.has(b)))].sort(),
    results: rows,
  }

  out.mode = CONTROL ? 'control' : 'gap'
  out.candidatesProbed = probed.reduce((n, r) => n + (r.candidates ?? 0), 0)
  // Field-level three-state. The member-level buckets say nothing about an
  // array field that was skipped inside an otherwise-probed member, and every
  // finding so far has been an array ITEM key — so an unreported skip here is
  // exactly where a missed case would hide.
  out.arrayFieldsProbed = probed.reduce((n, r) => n + (r.arrayFieldsProbed ?? 0), 0)
  out.arrayFieldsSkipped = {}
  for (const r of probed) {
    for (const [why, n] of Object.entries(r.arrayFieldsSkipped ?? {})) {
      out.arrayFieldsSkipped[why] = (out.arrayFieldsSkipped[why] ?? 0) + n
    }
  }
  if (CONTROL) {
    out.controlDetectionRate = out.candidatesProbed
      ? Number((findings.length / out.candidatesProbed).toFixed(3))
      : 0
  }

  if (JSON_OUT) {
    process.stdout.write(JSON.stringify(out, null, 2) + '\n')
    return
  }

  if (CONTROL) {
    const blind = probed
      .filter((r) => (r.candidates ?? 0) > 0 && r.findings.length < r.candidates)
      .sort((a, b) => (b.candidates - b.findings.length) - (a.candidates - a.findings.length))
    const lines = []
    lines.push('blocks-render-probe --control — can the probe see a DECLARED text field?')
    lines.push('')
    lines.push('probed members          ' + probed.length)
    lines.push('declared text fields    ' + out.candidatesProbed)
    lines.push('detected in the markup  ' + findings.length + '  (rate ' + out.controlDetectionRate + ')')
    lines.push('')
    lines.push('members the probe is partly blind to (declared field never reached the markup):')
    for (const r of blind.slice(0, 40)) {
      const found = new Set(r.findings.map((f) => f.prop))
      lines.push('  ' + r.key.padEnd(34) + (r.candidates - r.findings.length) + ' of ' + r.candidates + ' unseen')
    }
    if (blind.length > 40) lines.push('  … ' + (blind.length - 40) + ' more')
    process.stdout.write(lines.join('\n') + '\n')
    return
  }

  const lines = []
  lines.push('blocks-render-probe — props a block RENDERS but never DECLARES')
  lines.push('')
  lines.push('members seen            ' + raw.members)
  lines.push('probed                  ' + probed.length)
  lines.push('could not probe         ' + out.couldNotProbe + '  ' + JSON.stringify(skippedBy))
  lines.push('candidates probed       ' + out.candidatesProbed)
  lines.push('array fields probed     ' + out.arrayFieldsProbed + '  skipped ' + JSON.stringify(out.arrayFieldsSkipped))
  lines.push('members with a finding  ' + withFindings.length + ' of ' + probed.length + ' probed')
  lines.push('undeclared props found  ' + findings.length + ' (' + visible.length + ' visible as text, rest attribute-only)')
  lines.push('high-traffic families   ' + (out.highTrafficAffected.join(' ') || 'none'))
  lines.push('')
  for (const r of withFindings.sort((a, b) => b.findings.length - a.findings.length)) {
    const body = r.findings
      .map((f) => f.prop + (f.visible ? '' : '~attr') + (f.declaredElsewhereInFamily ? '*' : ''))
      .join(' ')
    lines.push(r.key.padEnd(34) + body)
  }
  lines.push('')
  lines.push('* = the prop IS declared by a sibling variant (a fields entry closes it);')
  lines.push('  no star = absent from the published vocabulary entirely.')
  lines.push('~attr = the sentinel reached an HTML attribute, not visible text.')
  process.stdout.write(lines.join('\n') + '\n')
}

report(runProbe())
