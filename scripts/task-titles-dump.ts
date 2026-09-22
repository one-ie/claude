#!/usr/bin/env bun
// task-titles-dump.ts — the offline `{ tid: title }` map the thread-name backfill reads.
//
// manifest: monorepo-only  (reads this repo's one.ie/web/.dev.vars and calls one.ie's
//                           own receivers by name)
//
// WHY IT EXISTS. A task thread's name is the task's TITLE, and the D1 `entity_meta`
// overlay that will carry it is written by `tasks:create`/`subtask`/`rename` FROM NOW
// ON — measured 2026-09-13, production's overlay held 2 rows and 0 titles. So for
// every task that already exists the title lives only in the brain, and
// `thread-name-backfill.ts --titles` is the door. Without a map it names 15 of 1055
// rows in `one`; with one it names 411.
//
// READ-ONLY, AND IT NEVER TOUCHES THE BRAIN DIRECTLY. Two shipped receivers over
// HTTP: `tasks:everywhere` once, only to learn which BARE tags this workspace
// actually uses, then `tasks:list` per tag — the one door that returns every row for
// a tag with no cap. `tasks:board` would answer in a single call and is the right
// door the day it reaches production; it dissolves as `unknown_receiver` there today
// (measured 2026-09-13), which is the whole reason this unions tag pages instead.
//
// THE COUNT IS A FLOOR, NOT A TOTAL, and the file says so. `tasks:everywhere` on
// production still clamps at 200 rows with no `total`/`truncated` beside it, so the
// TAG SET it yields is whatever those 200 rows carry — a tag used only by older rows
// is invisible, and its tasks are simply absent from the map. A thread whose title is
// missing is COUNTED AND LEFT by the backfill, never guessed at, so an incomplete map
// under-names and never mis-names. Add `--tag <t>` to force one in.
//
// USAGE
//   bun .claude/scripts/task-titles-dump.ts --slug ehc --out .backfill/titles-ehc.json
//   bun .claude/scripts/task-titles-dump.ts --slug one --tag legacy --tag archived

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

const ROOT = new URL('../..', import.meta.url).pathname
const API = process.env['ONE_API_URL'] || 'https://one.ie'

const argv = process.argv.slice(2)
const flag = (name: string, fallback = ''): string => {
  const i = argv.indexOf(`--${name}`)
  return i >= 0 && argv[i + 1] && !argv[i + 1]!.startsWith('--') ? argv[i + 1]! : fallback
}
const flags = (name: string): string[] =>
  argv.reduce<string[]>((acc, a, i) => (a === `--${name}` && argv[i + 1] && !argv[i + 1]!.startsWith('--') ? [...acc, argv[i + 1]!] : acc), [])

const slug = flag('slug')
const out = resolve(ROOT, flag('out', `.backfill/titles-${slug}.json`))
const extraTags = flags('tag')

if (!slug) {
  console.error('usage: bun .claude/scripts/task-titles-dump.ts --slug <workspace> [--out FILE] [--tag <bare-word>]…')
  process.exit(2)
}

// The service key prod accepts is the one in `.dev.vars`; the copy in `.env` is
// REFUSED by production (measured 2026-09-06). Never printed.
const devVars = readFileSync(`${ROOT}/one.ie/web/.dev.vars`, 'utf8')
const KEY = (devVars.match(/^GATEWAY_API_KEY=(.*)$/m)?.[1] ?? '').trim().replace(/^"|"$/g, '')
if (!KEY) {
  console.error('no GATEWAY_API_KEY in one.ie/web/.dev.vars — stopping rather than calling the door unauthenticated')
  process.exit(3)
}

async function ask<T>(receiver: string, data: unknown): Promise<T | null> {
  const res = await fetch(`${API}/api/ask/${receiver}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ data }),
  })
  // BOTH refusals answer HTTP 200 — success is `outcome=='result'` AND `result.ok`.
  const body = (await res.json()) as { outcome?: string; result?: { ok?: boolean } & T; reason?: string }
  if (body.outcome !== 'result' || !body.result?.ok) {
    console.error(`  ${receiver} refused: ${body.outcome ?? res.status}${body.reason ? ` (${body.reason})` : ''}`)
    return null
  }
  return body.result as T
}

// ── which tags this workspace uses ──────────────────────────────────────────
const seed = await ask<{ tasks?: Array<{ tags?: string[] }> }>('tasks:everywhere', { workspace: slug, limit: 5000 })
const tags = new Set(extraTags)
for (const t of seed?.tasks ?? []) {
  // BARE words only. A namespaced tag is a routing lane, not a tag, and `tasks:list`
  // filters on the bare word.
  for (const g of t.tags ?? []) if (!g.includes(':') && !g.startsWith('@')) tags.add(g)
}
console.log(`${slug}: ${seed?.tasks?.length ?? 0} seed row(s) → ${tags.size} bare tag(s)`)

// ── one page per tag, unioned ───────────────────────────────────────────────
const titles: Record<string, string> = {}
let refused = 0
for (const tag of [...tags].sort()) {
  const page = await ask<{ tasks?: Array<{ tid?: string; name?: string }> }>('tasks:list', { workspace: slug, tag })
  if (!page) { refused++; continue }
  for (const t of page.tasks ?? []) if (t.tid && t.name) titles[t.tid] = t.name
}

mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, `${JSON.stringify(titles, null, 1)}\n`, 'utf8')
console.log(`${Object.keys(titles).length} title(s) → ${out}${refused ? `   (${refused} tag page(s) refused — the map is short by however many rows they held)` : ''}`)
console.log('This is a FLOOR: a tag absent from the seed page contributes nothing, and a missing title is left unnamed by the backfill rather than guessed.')
