#!/usr/bin/env node
// fleet-manifest.mjs — project the fleet board into one JSON the web app can import.
//
// WHY A GENERATOR AND NOT A GLOB: the fleet docs live in text/, which is OUTSIDE
// the Astro root. `import.meta.glob('../../../../text/*.md')` is denied by vite's
// server.fs.allow ("Denied ID /Users/toc/Server/one-ie/text/analyst.md?raw",
// measured 2026-08-26), and text/ holds 1,568 files / 50MB — inlining any part of
// it fights the 3 MiB gzip CF Worker ceiling astro.config.mjs already stubs
// packages to stay under. Same precedent as promise-manifest.mjs.
//
// This file is the SINGLE SOURCE of the fleet -> doc map. `.claude/scripts/
// fleet-status.sh` reads the generated JSON, so the CLI board and the web board
// can never disagree about which fleets exist.
//
// Usage: node .claude/scripts/fleet-manifest.mjs [--check]
//        --check exits 3 if the committed output is stale (no write).

import { readFileSync, writeFileSync, existsSync, statSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const OUT = resolve(ROOT, 'one.ie/web/src/data/fleets.json')

// fleet -> doc path (null = running, no doc written yet).
const FLEETS = [
  ['security', 'text/auth-enforcement-todo.md'],
  ['wallet', 'text/wallet-durability.md'],
  ['keys', 'text/keys.md'],
  ['skill-engine', 'text/skill-engine.md'],
  ['analytics', 'text/journey-analytics.md'],
  ['analyst', 'text/analyst.md'],
  ['departments', 'text/departments.md'],
  ['colony', 'text/colony.md'],
  ['dev-env', 'text/dev-environment.md'],
  ['marketing', null],
  ['sales', null],
  ['service', null],
  ['engineering', null],
  ['tasks', null],
  ['vespio', null],
]

// Exactly what `grep -ci 'NOT WIRED\|NOT MEASURED\|DARK —'` counts: MATCHING
// LINES, not occurrences. Diverging here would make the page a second source.
const OPEN_RE = /NOT WIRED|NOT MEASURED|DARK —/i

const board = FLEETS.map(([name, doc]) => {
  if (!doc) return { name, doc: null, lines: null, open: null, updated: null }
  const abs = resolve(ROOT, doc)
  if (!existsSync(abs)) return { name, doc, lines: null, open: null, updated: null }
  const body = readFileSync(abs, 'utf8')
  const lines = body.split('\n')
  // `wc -l` counts newline terminators; the trailing "" from split is not a line.
  const wcl = body.endsWith('\n') ? lines.length - 1 : lines.length
  return {
    name,
    doc,
    lines: wcl,
    open: lines.filter((l) => OPEN_RE.test(l)).length,
    updated: new Date(statSync(abs).mtimeMs).toISOString(),
  }
})

const manifest = { generatedAt: new Date().toISOString(), board }

// Compare ignoring generatedAt so --check does not go red on the clock alone.
const stable = (m) => JSON.stringify(m.board)
const next = JSON.stringify(manifest, null, 2) + '\n'

if (process.argv.includes('--check')) {
  if (!existsSync(OUT)) {
    console.error('fleet-manifest: missing ' + OUT)
    process.exit(3)
  }
  const cur = JSON.parse(readFileSync(OUT, 'utf8'))
  if (stable(cur) !== stable(manifest)) {
    console.error('fleet-manifest: STALE — run `node .claude/scripts/fleet-manifest.mjs`')
    process.exit(3)
  }
  console.log('fleet-manifest: up to date (' + board.length + ' fleets)')
  process.exit(0)
}

// Do not rewrite an unchanged board. fleet-status.sh calls this on every run,
// and an always-write generator would leave a tracked file dirty in the shared
// main tree each time somebody looks at the board — the exact sweep hazard
// .claude/CLAUDE.md warns about with concurrent windows. `generatedAt` alone is
// not a change.
if (existsSync(OUT)) {
  try {
    if (stable(JSON.parse(readFileSync(OUT, 'utf8'))) === stable(manifest)) {
      console.log('fleet-manifest: unchanged (' + board.length + ' fleets)')
      process.exit(0)
    }
  } catch {
    // unreadable/corrupt output — fall through and rewrite it
  }
}

writeFileSync(OUT, next)
console.log(
  'fleet-manifest: wrote ' +
    board.length +
    ' fleets (' +
    board.filter((f) => f.doc).length +
    ' with a doc) -> src/data/fleets.json',
)
