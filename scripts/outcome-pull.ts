#!/usr/bin/env bun
/**
 * outcome-pull.ts — pull production path weights into text/task-paths.json's `prod`
 * field, provenance-tagged, never touching the local `strength`/`resistance`/`closed`
 * fields `--mark`/`--sync-closes` own (do-rank.py). Part of text/self-improving-outcome.md.
 *
 * Reads LOCAL D1 only (`one-owners`, mirrored from prod by `bun run db:sync` — see
 * hook:db-sync in .claude/settings.json, which runs this script right after). Never
 * touches the network directly — do-rank.py's zero-network invariant is preserved by
 * construction: this script is the only one that shells out, and only to local wrangler.
 *
 * Three prod sources, three mappers (text/self-improving-outcome-plan.md § Evidence):
 *   1. a settled promise         — claw_paths  source="promise:<slug>" target="proof"
 *   2. a /do cycle that closed   — entity_tags  tags ⊇ ["do:learn","slug:<slug>"]
 *   3. a graded delivery         — claw_paths  source="tag:<board>:slug:<slug>"
 * `shape→model` do-event marks are deliberately NOT mapped — verified slug-free.
 *
 * Usage:
 *   bun .claude/scripts/outcome-pull.ts             # pull local D1 → text/task-paths.json
 *   bun .claude/scripts/outcome-pull.ts --selftest   # offline fixture proof, no D1/network
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'

const ROOT = join(dirname(new URL(import.meta.url).pathname), '..', '..')
const WEB_DIR = join(ROOT, 'one.ie', 'web')
const TASK_PATHS = join(ROOT, 'text', 'task-paths.json')
const D1_BIN = process.env.D1_BIN ?? 'one-owners'

export interface ClawPathRow {
  source: string
  target: string
  strength: number
  resistance: number
  traversals: number
}

export interface EntityTagRow {
  entity_id: string
  tags: string // JSON array string, e.g. '["do:learn","slug:foo"]'
}

export interface MappedOutcome {
  slug: string
  strength: number
  resistance: number
  traversals: number
  source: string
}

// ─── the three pure mappers (fixture-tested by --selftest) ─────────────────

export function mapPromiseProof(row: ClawPathRow): MappedOutcome | null {
  const m = /^promise:(.+)$/.exec(row.source)
  if (!m || row.target !== 'proof') return null
  return { slug: m[1]!, strength: row.strength, resistance: row.resistance, traversals: row.traversals, source: 'promise:proof' }
}

export function mapDoEventLearn(row: EntityTagRow): MappedOutcome | null {
  let tags: unknown
  try {
    tags = JSON.parse(row.tags)
  } catch {
    return null
  }
  if (!Array.isArray(tags)) return null
  const has = (t: string) => tags.includes(t)
  if (!has('do:learn')) return null
  const slugTag = tags.find((t): t is string => typeof t === 'string' && t.startsWith('slug:'))
  if (!slugTag) return null
  // Presence of a prod-recorded close is the signal — the composite score embedded in
  // doEventTitle's display text is UI prose, not a stable machine field (plan § Decisions).
  return { slug: slugTag.slice('slug:'.length), strength: 0.5, resistance: 0, traversals: 1, source: 'do:learn' }
}

export function mapWorldOutcome(row: ClawPathRow): MappedOutcome | null {
  const m = /^tag:[^:]+:slug:(.+)$/.exec(row.source)
  if (!m) return null
  return { slug: m[1]!, strength: row.strength, resistance: row.resistance, traversals: row.traversals, source: 'world:outcome' }
}

// ─── the merge law: `prod` is a full overwrite per pull, local fields untouched ────

type TaskPaths = Record<string, Record<string, unknown>>

export function mergeIntoTaskPaths(existing: TaskPaths, mapped: MappedOutcome[], pulledAt: string): TaskPaths {
  const out: TaskPaths = JSON.parse(JSON.stringify(existing))
  const bySlug = new Map<string, { strength: number; resistance: number; traversals: number; sources: Set<string> }>()
  for (const m of mapped) {
    const acc = bySlug.get(m.slug) ?? { strength: 0, resistance: 0, traversals: 0, sources: new Set<string>() }
    acc.strength += m.strength
    acc.resistance += m.resistance
    acc.traversals += m.traversals
    acc.sources.add(m.source)
    bySlug.set(m.slug, acc)
  }
  for (const [slug, acc] of bySlug) {
    const key = `task:${slug}`
    const entry = out[key] ?? { closed: 0, strength: 0, resistance: 0, traversals: 0 }
    entry.prod = {
      strength: round3(acc.strength),
      resistance: round3(acc.resistance),
      traversals: acc.traversals,
      sources: [...acc.sources].sort(),
      pulled_at: pulledAt,
    }
    out[key] = entry
  }
  return out
}

function round3(n: number): number {
  return Math.round(n * 1000) / 1000
}

// ─── local D1 read (never network — reads the mirror db:sync already wrote) ────

async function d1Query(sql: string): Promise<Array<Record<string, unknown>>> {
  const proc = Bun.spawn(
    ['bunx', 'wrangler', 'd1', 'execute', D1_BIN, '--local', '--json', '--command', sql],
    { cwd: WEB_DIR, stdout: 'pipe', stderr: 'pipe' },
  )
  const out = await new Response(proc.stdout).text()
  if ((await proc.exited) !== 0) throw new Error(`d1 execute failed: ${await new Response(proc.stderr).text()}`)
  const parsed = JSON.parse(out)
  return (parsed?.[0]?.results ?? []) as Array<Record<string, unknown>>
}

async function pull(): Promise<void> {
  let mapped: MappedOutcome[] = []
  try {
    const promiseRows = (await d1Query(
      `SELECT source, target, strength, resistance, traversals FROM claw_paths WHERE source LIKE 'promise:%' AND target = 'proof'`,
    )) as unknown as ClawPathRow[]
    const outcomeRows = (await d1Query(
      `SELECT source, target, strength, resistance, traversals FROM claw_paths WHERE source LIKE 'tag:%:slug:%'`,
    )) as unknown as ClawPathRow[]
    const learnRows = (await d1Query(
      `SELECT entity_id, tags FROM entity_tags WHERE tags LIKE '%"do:learn"%' AND tags LIKE '%"slug:%'`,
    )) as unknown as EntityTagRow[]
    mapped = [
      ...promiseRows.map(mapPromiseProof),
      ...outcomeRows.map(mapWorldOutcome),
      ...learnRows.map(mapDoEventLearn),
    ].filter((m): m is MappedOutcome => m !== null)
  } catch (err) {
    // Best-effort — matches hook:db-sync's own posture (session start must never block
    // on an offline/unreachable local D1). No crash, no partial write.
    console.error(`[outcome-pull] local D1 unreachable, skipping: ${(err as Error).message}`)
    return
  }
  const existing: TaskPaths = existsSync(TASK_PATHS) ? JSON.parse(readFileSync(TASK_PATHS, 'utf8')) : {}
  const merged = mergeIntoTaskPaths(existing, mapped, new Date().toISOString())
  writeFileSync(TASK_PATHS, JSON.stringify(sortKeys(merged), null, 2) + '\n')
  console.log(`[outcome-pull] merged prod outcomes for ${new Set(mapped.map((m) => m.slug)).size} slug(s) from ${mapped.length} row(s)`)
}

// Recursive — matches do-rank.py's `json.dumps(sort_keys=True)`, which sorts every nested
// level. A top-level-only sort would make the two writers emit different byte order for
// the same data (nested `prod`/etc. keys), causing spurious diffs on every session.
function sortKeys<T>(value: T): T {
  if (Array.isArray(value)) return value.map(sortKeys) as unknown as T
  if (value !== null && typeof value === 'object') {
    const out: Record<string, unknown> = {}
    for (const k of Object.keys(value as Record<string, unknown>).sort()) {
      out[k] = sortKeys((value as Record<string, unknown>)[k])
    }
    return out as T
  }
  return value
}

// ─── offline selftest — the only mode the promise's proof: runs ────────────

function selftest(): void {
  let pass = 0
  let fail = 0
  const check = (name: string, cond: boolean) => {
    if (cond) {
      pass++
    } else {
      fail++
      console.error(`FAIL: ${name}`)
    }
  }

  // 1. mapPromiseProof — direct slug extraction, rejects non-proof targets.
  check(
    'mapPromiseProof: extracts slug from promise:<slug>→proof',
    mapPromiseProof({ source: 'promise:self-improving-outcome', target: 'proof', strength: 4, resistance: 0, traversals: 1 })?.slug === 'self-improving-outcome',
  )
  check(
    'mapPromiseProof: rejects non-proof target',
    mapPromiseProof({ source: 'promise:foo', target: 'other', strength: 1, resistance: 0, traversals: 1 }) === null,
  )
  check(
    'mapPromiseProof: rejects non-promise source',
    mapPromiseProof({ source: 'shape:foo', target: 'proof', strength: 1, resistance: 0, traversals: 1 }) === null,
  )

  // 2. mapDoEventLearn — requires BOTH do:learn and a slug: tag; ignores other stages.
  check(
    'mapDoEventLearn: extracts slug from a learn-tagged row',
    mapDoEventLearn({ entity_id: 'conv:do-foo-c1', tags: JSON.stringify(['do:learn', 'do:cycle', 'tier:feature', 'slug:foo', 's:security']) })?.slug === 'foo',
  )
  check(
    'mapDoEventLearn: rejects a non-learn stage (do:wave)',
    mapDoEventLearn({ entity_id: 'conv:do-foo-c1', tags: JSON.stringify(['do:wave', 'slug:foo']) }) === null,
  )
  check(
    'mapDoEventLearn: rejects a learn row with no slug tag',
    mapDoEventLearn({ entity_id: 'conv:x', tags: JSON.stringify(['do:learn']) }) === null,
  )
  check(
    'mapDoEventLearn: tolerates malformed tags JSON',
    mapDoEventLearn({ entity_id: 'conv:x', tags: 'not-json' }) === null,
  )

  // 3. mapWorldOutcome — tag-node source, world:outcome's tagNode() shape.
  check(
    'mapWorldOutcome: extracts slug from tag:<board>:slug:<slug>',
    mapWorldOutcome({ source: 'tag:acme:slug:foo', target: 'model:sonnet', strength: 1, resistance: 0, traversals: 1 })?.slug === 'foo',
  )
  check(
    'mapWorldOutcome: rejects a shape→model row (verified slug-free, plan § Evidence)',
    mapWorldOutcome({ source: 'shape:do:feature', target: 'model:sonnet', strength: 1, resistance: 0, traversals: 1 }) === null,
  )
  check(
    'mapWorldOutcome: rejects a non-slug tag',
    mapWorldOutcome({ source: 'tag:acme:vip', target: 'actor:x', strength: 1, resistance: 0, traversals: 1 }) === null,
  )

  // 4. mergeIntoTaskPaths — the merge law: outcome-weight (marked contributes, warned
  //    contributes to resistance), provenance (sources tagged), idempotent re-pull,
  //    and — the load-bearing one — LOCAL fields are never touched by a pull.
  const local: TaskPaths = {
    'task:foo': { closed: 1.2, strength: 0.4, resistance: 0.1, traversals: 3 },
  }
  const mapped: MappedOutcome[] = [
    { slug: 'foo', strength: 2, resistance: 0, traversals: 1, source: 'promise:proof' },
    { slug: 'foo', strength: 0.5, resistance: 0, traversals: 1, source: 'do:learn' },
  ]
  const merged = mergeIntoTaskPaths(local, mapped, '2026-07-08T00:00:00.000Z')
  check('merge: prod.strength sums same-slug rows within one pull', (merged['task:foo'] as any).prod.strength === 2.5)
  check('merge: prod.sources carries provenance for both mappers', JSON.stringify((merged['task:foo'] as any).prod.sources) === JSON.stringify(['do:learn', 'promise:proof']))
  check('merge: LOCAL strength untouched by the pull', (merged['task:foo'] as any).strength === 0.4)
  check('merge: LOCAL resistance untouched by the pull', (merged['task:foo'] as any).resistance === 0.1)
  check('merge: LOCAL closed untouched by the pull', (merged['task:foo'] as any).closed === 1.2)

  // merge law, other direction: a re-pull with different rows OVERWRITES prod, never adds.
  const rePulled = mergeIntoTaskPaths(merged, [{ slug: 'foo', strength: 1, resistance: 0, traversals: 1, source: 'promise:proof' }], '2026-07-09T00:00:00.000Z')
  check('merge: re-pull overwrites prod.strength, does not accumulate across pulls', (rePulled['task:foo'] as any).prod.strength === 1)
  check(
    'merge: two identical pulls are idempotent (byte-identical prod block)',
    JSON.stringify(mergeIntoTaskPaths(local, mapped, 'T')['task:foo']) === JSON.stringify(mergeIntoTaskPaths(local, mapped, 'T')['task:foo']),
  )

  // warned outcome (resistance-only) — the "warned lowers rank" half of outcome-weight.
  const warned = mergeIntoTaskPaths({}, [{ slug: 'bar', strength: 0, resistance: 2, traversals: 1, source: 'promise:proof' }], 'T')
  check('merge: a warned outcome lands entirely in prod.resistance, not prod.strength', (warned['task:bar'] as any).prod.resistance === 2 && (warned['task:bar'] as any).prod.strength === 0)

  // outcome-weight: a slug the world marked outranks an identical one the world warned —
  // proven here at the merge layer (do-rank.py's own selftest proves it again at the
  // path_momentum layer — two independent proofs of the same law, per plan § Pre-mortem).
  const markedNet = ((merged['task:foo'] as any).closed) + ((merged['task:foo'] as any).strength) + ((merged['task:foo'] as any).prod.strength) - ((merged['task:foo'] as any).resistance) - ((merged['task:foo'] as any).prod.resistance)
  const warnedNet = ((warned['task:bar'] as any).closed ?? 0) + ((warned['task:bar'] as any).strength ?? 0) + ((warned['task:bar'] as any).prod.strength) - ((warned['task:bar'] as any).resistance ?? 0) - ((warned['task:bar'] as any).prod.resistance)
  check('outcome-weight: a marked prod outcome nets strictly above a warned one', markedNet > warnedNet)

  console.log(`SELFTEST: ${pass}/${pass + fail} pass (mapPromiseProof · mapDoEventLearn · mapWorldOutcome · merge-law · provenance · outcome-weight)`)
  if (fail > 0) process.exit(1)
}

// ─── entry ───────────────────────────────────────────────────────────────

if (process.argv.includes('--selftest')) {
  selftest()
} else {
  await pull()
}
