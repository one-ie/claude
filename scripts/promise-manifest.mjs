#!/usr/bin/env node
// promise-manifest.mjs — project text/<slug>.md promise frontmatter into the two
// JSON reads the Promise view needs (text/factory-promise-view.md §6).
//
// The promise files live in git and the web app is a CF Worker with no filesystem,
// so the contract has to be projected at build time. Same shape as the precedent
// at src/data/factory-check.json, which /factory imports.
//
// Two outputs, split so the bundle cost is bounded:
//   src/data/promises-index.json   slug · title · counts. imported by the route.
//   src/data/promises.json         full detail. imported ONLY by the API route.
//
// NOT written to public/ — a public JSON carrying accept: bodies would make the
// shared lens's redaction (§4) cosmetic, and would be unauthenticated for every
// workspace forever the moment a tenant writes a promise.
//
// Usage: node .claude/scripts/promise-manifest.mjs [--check]
//        --check exits 3 if the committed output is stale (no write).

import { readFileSync, readdirSync, writeFileSync, existsSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse as parseYaml } from '../../one.ie/web/node_modules/yaml/dist/index.js'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const TEXT = resolve(ROOT, 'text')
const OUT = resolve(ROOT, 'one.ie/web/src/data')

// A promise is the bare slug — text/<feature>.md. Every suffixed sibling is derived
// from it (text/CLAUDE.md § File naming) and carries its own frontmatter that is NOT
// a contract; a -todo.md's `outcome:` is the promise's proof, not a second promise.
const DERIVED = /-(plan|todo|docs|ui|features|tutorial|how-to|reference|agents|agents-docs|humans|lifecycle)\.md$/

function splitFrontmatter(src) {
  if (!src.startsWith('---\n')) return null
  const end = src.indexOf('\n---', 4)
  if (end === -1) return null
  return { fm: src.slice(4, end), body: src.slice(end + 4) }
}

// The one-sentence claim — the largest thing on the rendered page, so a wrong pick
// is loud. Prefer the section written to BE the claim (`## The promise`, or a
// `## Who this is for` where the promise family uses that heading); otherwise the
// first prose paragraph anywhere after the H1. Headings are skipped, not bailed on:
// 56 of 79 promises open with a section heading immediately under the H1, so
// stopping at the first heading returned an empty lead for most of the corpus.
function firstProse(lines, from) {
  for (let i = from; i < lines.length; i++) {
    const l = lines[i].trim()
    if (!l) continue
    if (/^(#{1,6}\s|>\s|[-*+]\s|\d+\.\s|```|\||---|\*\*Status|<)/.test(l)) continue
    // A one-line paragraph is the shape we want; join a wrapped one up to its break.
    const buf = [l]
    for (let j = i + 1; j < lines.length && lines[j].trim(); j++) {
      const nxt = lines[j].trim()
      if (/^(#{1,6}\s|>\s|[-*+]\s|\d+\.\s|```|\|)/.test(nxt)) break
      buf.push(nxt)
    }
    return buf.join(' ')
  }
  return ''
}

// Only from a section written to BE the claim. Measured over the 79-file corpus:
// falling back to "first prose after the H1" returned a lead for all 79, but the
// leads were wrong — `affiliate-escrow-multichain` yielded "`resolveAffiliateLeg`
// in pay/backend/src/routes/escrow.ts computes an AffiliateSplit…", which is
// implementation detail presented as the headline claim. A confident wrong sentence
// at the top of a contract is worse than no sentence, so the fallback is gone: the
// TITLE carries the claim (they are written that way — "Affiliate escrow, every
// chain — EVM and Solana pay the referral for real") and this is the optional
// second line under it.
function leadSentence(body) {
  const lines = body.split('\n')
  // `## The promise` ONLY. `## Who this is for` was tried and dropped: it is an
  // audience section, and its opening prose is routinely implementation detail
  // (affiliate-escrow-multichain opens it with a function name and a file path).
  const at = lines.findIndex((l) => /^##+\s+The promise\b/i.test(l.trim()))
  if (at === -1) return ''
  const lead = firstProse(lines, at + 1)
  // One sentence, not the whole section.
  return lead ? (lead.match(/^.*?[.!?](?=\s|$)/)?.[0] ?? lead).slice(0, 320) : ''
}

// "Out of scope — not promised, by law" — the block the doc says gets equal weight
// and must survive to the Delivery state. Bullets only; prose in the section is
// context for us, not a scope line for the reader.
function outOfScope(body) {
  const m = body.match(/^##+\s+Out of scope[^\n]*\n([\s\S]*?)(?=\n##\s|\n---\s*\n|$)/m)
  if (!m) return []
  return m[1].split('\n')
    .map((l) => l.trim())
    .filter((l) => /^[-*+]\s+/.test(l))
    .map((l) => l.replace(/^[-*+]\s+/, '').replace(/^\*\*(.+?)\*\*\s*/, '$1 — ').trim())
    .filter(Boolean)
}

function toList(v) {
  if (!v) return []
  return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : []
}

const promises = []
const broken = []
for (const file of readdirSync(TEXT).sort()) {
  if (!file.endsWith('.md') || DERIVED.test(file)) continue
  if (file.startsWith('template-')) continue
  const src = readFileSync(resolve(TEXT, file), 'utf8')
  const split = splitFrontmatter(src)
  if (!split) continue

  let fm
  try {
    fm = parseYaml(split.fm)
  } catch (err) {
    // An unparseable head is not a contract — UNLESS it was meant to be one. A file
    // that declares `deliverables:` and then fails to parse is a promise the site
    // would drop on the floor, silently, forever (text/urls.md vanished this way:
    // an unescaped `"` inside a double-quoted accept:). Loud, not skipped.
    if (/^deliverables:/m.test(split.fm)) {
      broken.push({ file, message: String(err.message || err).split('\n')[0] })
    }
    continue
  }
  if (!fm || typeof fm !== 'object') continue
  const rows = Array.isArray(fm.deliverables) ? fm.deliverables : []
  if (rows.length === 0) continue                        // no schedule = not a promise

  const slug = typeof fm.slug === 'string' && fm.slug ? fm.slug : file.replace(/\.md$/, '')
  promises.push({
    slug,
    title: typeof fm.title === 'string' ? fm.title : slug,
    status: typeof fm.status === 'string' ? fm.status.split('\n')[0].trim() : '',
    lead: leadSentence(split.body),
    deliverables: rows
      .filter((r) => r && typeof r.item === 'string')
      .map((r) => ({ item: r.item, accept: typeof r.accept === 'string' ? r.accept : '' })),
    assumes: toList(fm.assumes),
    // `proof:` is deliberately NOT carried. By the schedule ⊆ proof law it is the
    // verbatim `&&`-join of every accept: above (do-promise-lint.sh enforces the
    // inclusion), so shipping it doubles the payload to say nothing new — it cost
    // 190 KB of the first cut. The view renders verdicts, never the command.
    outOfScope: outOfScope(split.body),
  })
}

if (broken.length) {
  console.error(
    `[promise-manifest] ${broken.length} promise file(s) declare deliverables: but their\n` +
      `frontmatter does not parse — each would be MISSING from the site, silently:\n` +
      broken.map((b) => `  text/${b.file} — ${b.message}`).join('\n') +
      `\nFix the YAML (usually an unescaped " or \\ inside a double-quoted accept:,\n` +
      `or an unquoted title: containing ": "). Nothing was written.`,
  )
  process.exit(4)
}

// The index carries the claim and the count and nothing else — it is imported by
// the Astro route, so every field costs worker bundle on every tasks request.
const index = promises.map((p) => ({
  slug: p.slug,
  title: p.title,
  count: p.deliverables.length,
}))

const detail = Object.fromEntries(promises.map((p) => [p.slug, p]))

const files = [
  [resolve(OUT, 'promises-index.json'), index],
  [resolve(OUT, 'promises.json'), detail],
]

if (process.argv.includes('--check')) {
  for (const [path, data] of files) {
    const want = JSON.stringify(data, null, 2) + '\n'
    const have = existsSync(path) ? readFileSync(path, 'utf8') : ''
    if (want !== have) {
      console.error(`[promise-manifest] STALE: ${path.replace(ROOT + '/', '')} — run node .claude/scripts/promise-manifest.mjs`)
      process.exit(3)
    }
  }
  console.log(`[promise-manifest] fresh — ${promises.length} promises`)
  process.exit(0)
}

for (const [path, data] of files) {
  writeFileSync(path, JSON.stringify(data, null, 2) + '\n')
  console.log(`[promise-manifest] ${path.replace(ROOT + '/', '')} — ${(JSON.stringify(data).length / 1024).toFixed(1)} KB`)
}
console.log(`[promise-manifest] ${promises.length} promises · ${promises.reduce((n, p) => n + p.deliverables.length, 0)} deliverables`)
