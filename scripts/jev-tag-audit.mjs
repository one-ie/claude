#!/usr/bin/env node
// jev-tag-audit.mjs — which signal emit sites wake no department, and which one they should wake.
//
// manifest: monorepo-only  (the env read IS indirected, but the audit greps
//                        one.ie/web/src/lib/resolvers, one.ie/web/src/pages/api and
//                        channels/src with `|| true` — absent, it reports ZERO orphans
//                        and reads as all-clean. Corrected from needs-env 2026-09-21:
//                        a silent false green is worse than an absent script.)
//
// WHY. Measured 2026-09-21: `emitPaySignal` (api/pay/webhook.ts) tags a captured payment
// ['pay', <rail>, 'accept'], and FN_TAGS.sales stakes on ['sql','opportunity','won','lost','sales'].
// The intersection is EMPTY, `tagsIntersect` returns false, and the signal matches zero
// subscribers — money lands and the sales room is never told. That is worse than an untagged
// signal, which at least falls to lane 3 and lands stamped `unrouted: true`.
//
// THE SHAPE. bash gathers, Jev decides, nothing is written:
//   1. grep every `tags: [...]` literal under resolvers/ , pages/api/ and channels/src
//   2. intersect each against FN_TAGS (lib/in/spaces.ts) — deterministic, no model
//   3. for the ones that reach NO department, ask Jev which department should be woken
//
// Step 2 needs no key and is the audit. Step 3 is the proposal and is skipped without a key.
// READ-ONLY: proposes, never edits. --json for the machine-readable form.
//
//   node .claude/scripts/jev-tag-audit.mjs [--json] [--no-jev]
//
// Exit 0 = ran. Exit 1 = could not read the tree. A site reaching no department is a FINDING,
// not a failure — the gate that makes it a failure is text/jev.md row 17.
import { readFileSync, existsSync } from 'node:fs'
import { execSync } from 'node:child_process'

const ROOT = execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim()
const JSON_OUT = process.argv.includes('--json')
const NO_JEV = process.argv.includes('--no-jev')

// Mirrored from one.ie/web/src/lib/in/spaces.ts FN_TAGS. If that file moves or grows a
// department, this drifts — which is precisely what row 17's test is for. Keep them together.
const FN_TAGS = {
  marketing: ['lead', 'mql', 'sql', 'marketing'],
  sales: ['sql', 'opportunity', 'won', 'lost', 'sales'],
  service: ['open', 'pending', 'service'],
  education: ['education'],
  engineering: ['engineering', 'do-event', 'memory', 'recall', 'intelligence'],
  staff: ['staff'],
}
const DEPT = {
  marketing: 'demand generation — leads, campaigns, copy, landing pages, anything that brings strangers in',
  sales: 'revenue — a deal moving, money landing, a purchase completing, pricing, won or lost',
  service: 'an existing customer needs help — tickets, support, something open or pending for them',
  education: 'teaching a customer or user — onboarding, courses, training',
  engineering: 'the build itself — code, schema, receivers, deploys, reviews, the substrate',
  none: 'genuinely internal plumbing that no business department should be woken by',
}
// Column lists and option arrays that the grep cannot tell from a tag array. Narrow and named,
// so a real emit site can never be silently excluded by a broad pattern.
const NOISE = new Set(['name', 'st', 'u', 'notes'])

function envVar(k) {
  if (process.env[k]) return process.env[k]
  const f = process.env.ONE_ENV_FILE || process.env.DO_ENV_FILE || `${ROOT}/one.ie/web/.env`
  if (!existsSync(f)) return ''
  const m = readFileSync(f, 'utf8').split('\n').find((l) => l.startsWith(`${k}=`))
  return m ? m.slice(k.length + 1).trim().replace(/^"|"$/g, '') : ''
}

function emitSites() {
  let raw = ''
  try {
    raw = execSync(
      `grep -rn --include=*.ts -E "tags: \\[" one.ie/web/src/lib/resolvers one.ie/web/src/pages/api channels/src || true`,
      { cwd: ROOT, encoding: 'utf8', maxBuffer: 8 << 20 },
    )
  } catch { return [] }
  const out = []
  for (const line of raw.split('\n')) {
    if (!line || line.includes('.test.') || line.includes('/tests/')) continue
    const m = /^([^:]+):(\d+):\s*(.*)$/.exec(line)
    if (!m) continue
    const code = m[3].trim()
    const tags = [...code.matchAll(/['"]([a-z0-9:_-]+)['"]/g)].map((x) => x[1])
    if (!tags.length || tags.some((t) => NOISE.has(t))) continue
    out.push({ file: m[1], line: Number(m[2]), tags, code: code.slice(0, 110) })
  }
  return out
}

async function jev(questions, state, key) {
  for (let i = 0; i < 6; i++) {
    const res = await fetch('https://api.typesafe.ai/v1/systemone', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ state, model: 'jev-latest', questions }),
    })
    if (res.ok) return res.json()
    // 529 system_overloaded is routine on early access — four in a row, measured 2026-09-21.
    if (res.status === 529 && i < 5) { await new Promise((r) => setTimeout(r, 5000 * (i + 1))); continue }
    throw new Error(`typesafe ${res.status}: ${(await res.text()).slice(0, 200)}`)
  }
}

const sites = emitSites()
if (!sites.length) { console.error('jev-tag-audit: no emit sites found — wrong cwd?'); process.exit(1) }
for (const s of sites) s.depts = Object.entries(FN_TAGS).filter(([, v]) => v.some((t) => s.tags.includes(t))).map(([d]) => d)
const orphans = sites.filter((s) => !s.depts.length)

const key = NO_JEV ? '' : envVar('TYPESAFE_API_KEY')
if (key && orphans.length) {
  for (let b = 0; b < orphans.length; b += 13) {
    const chunk = orphans.slice(b, b + 13)
    const state = 'Signal emit sites in the ONE codebase. Which business department should be woken when each fires?\n\n'
      + chunk.map((m, i) => `${i + 1}. file=${m.file}:${m.line}  tags=${JSON.stringify(m.tags)}\n   code: ${m.code}`).join('\n')
    const qs = Object.fromEntries(chunk.map((_, i) =>
      [`d${i + 1}`, { type: 'choice', instructions: `Department that should receive emit site ${i + 1}.`, criteria: DEPT }]))
    const r = await jev(qs, state, key)
    chunk.forEach((m, i) => { const a = r.answers[`d${i + 1}`]; m.proposed = a.choice; m.confidence = a.confidence })
  }
}

if (JSON_OUT) { console.log(JSON.stringify({ total: sites.length, orphans: orphans.length, sites }, null, 1)); process.exit(0) }
console.log(`jev-tag-audit — ${sites.length} emit sites, ${orphans.length} reach NO department\n`)
const act = orphans.filter((o) => o.proposed && o.proposed !== 'none' && o.confidence >= 0.5)
for (const o of orphans.slice().sort((a, b) => (b.confidence ?? 0) - (a.confidence ?? 0))) {
  const p = o.proposed ? `${o.confidence >= 0.5 ? 'ADD' : 'ask'} ${o.proposed.padEnd(11)} ${o.confidence.toFixed(2)}` : '(no key — audit only)'
  console.log(`  ${p}  ${o.file.replace('one.ie/web/src/', '')}:${o.line}  ${JSON.stringify(o.tags)}`)
}
console.log(`\nactionable (conf >= 0.50, not "none"): ${act.length}`)
console.log('Proposals only — this script never edits. The gate that makes an orphan a FAILURE is text/jev.md row 17.')
