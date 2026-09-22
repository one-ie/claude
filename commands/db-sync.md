# /db-sync — Sync production D1 → local miniflare

Mirror the production `one-owners` D1 database into the local miniflare SQLite state.
Run this any time local data goes missing (after a `git clean`, fresh checkout, or new worktree).

## What it does

1. Exports the remote `one-owners` D1 via `wrangler d1 export --remote`
2. Drops all non-`_cf_` tables in the local SQLite file
3. Imports the prod SQL dump via `sqlite3` (bypasses wrangler's SQLITE_TOOBIG limit)
4. Re-inserts the local-only `one` workspace seed row (not in prod)

## Prerequisites

`CLOUDFLARE_EMAIL` and `CLOUDFLARE_GLOBAL_API_KEY` must reach `process.env`. Both
are declared in `one.ie/web/.env`, and Bun auto-loads `.env` from the working
directory — which is why every command below `cd`s into `one.ie/web` first. Run
it from anywhere else and the script exits with
`ERROR: CLOUDFLARE_EMAIL and CLOUDFLARE_GLOBAL_API_KEY must be set in env.`

## One-shot command

```bash
cd /Users/toc/Server/one-ie/one.ie/web && bun scripts/sync-from-prod.ts --only=d1
```

Or via the npm script:

```bash
cd /Users/toc/Server/one-ie/one.ie/web && bun run db:sync
```

To also sync R2 content and KV namespaces (SESSION, CHAT_CACHE, THREADS) — slower, ~5–10 min:

```bash
cd /Users/toc/Server/one-ie/one.ie/web && bun run db:sync:all
```

## After sync

No migrations to apply — the D1 export from prod includes the migration ledger and all schema.
Local state will reflect prod exactly, plus the seeded `one` workspace row.

Verify with:

```bash
sqlite3 /Users/toc/Server/one-ie/one.ie/web/.wrangler/state/v3/d1/miniflare-D1DatabaseObject/*.sqlite \
  "SELECT 'owners', COUNT(*) FROM owners UNION SELECT 'messages', COUNT(*) FROM messages UNION SELECT 'threads', COUNT(*) FROM threads;" 2>/dev/null | grep -v metadata
```

## Why data gets lost

`.wrangler/` is gitignored — it does not survive `git clean -fd`, a fresh worktree (`git worktree add`), or a fresh clone. The `/kill` command explicitly preserves it, but `git clean` doesn't know that.

Run `/db-sync` whenever local feels stale or empty.
