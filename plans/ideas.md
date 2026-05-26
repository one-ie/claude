# Ideas — the seed backlog

The human/git mirror of the idea backlog. Each row is a **seed**: a weak idea captured to KV
(`seed:<id>`, TTL'd). A seed promotes to a durable path on its first `mark` and is then ranked
by `path.strength`; an unmarked seed fades by TTL expiry — **fade is the cleanup, no pruning job**.
TypeDB (the truth layer, off the hot path) only ever holds promoted ideas; the scheduled sync
worker carries promoted marks D1 → TypeDB.

Lifecycle: `seed (KV, weak)` → `mark` → `promoted (durable path)` → … → `shipped`. See
`one.ie/web/src/lib/substrate.ts` (`seed` · `getSeed` · `promoteSeed` · `listSeeds`) and
`.claude/commands/do.md` INTAKE.

| id | idea | state | captured |
|----|------|-------|----------|
| _example_ | operators can see token spend per cycle | shipped (cost:cycle) | 2026-05-26 |

> Rows are a convenience view. The KV seed is the source for unpromoted ideas; the substrate
> path is the source once promoted. `listSeeds()` regenerates the unpromoted set.
