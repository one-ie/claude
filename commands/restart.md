# /restart — Fast dev server restart

Kill Astro (4321–4329), gateway (8788), and channels (8787) servers, then start fresh + sync D1. No cache clearing, no reinstall — just stop and go.

Use when: you want a clean restart without the full `/kill` overhead. Takes ~15s vs ~30s.

## What it does

```
1. Kill all three servers (ports 4321–4329, 8787–8799)
2. Sync prod D1 → local miniflare
3. Start Astro (4321) + gateway (8788) + channels (8787) in parallel
```

## Steps

**Step 1 — kill:**
```bash
cd /Users/toc/Server/one-ie/one.ie/web && \
  (lsof -ti:4321,4322,4323,4324,4325,4326,4327,4328,4329,8787,8788,8789,8790,8791,8792,8793,8794,8795,8796,8797,8798,8799 2>/dev/null | xargs kill -9 2>/dev/null; \
   pkill -f "one\.ie/web.*(astro|wrangler|local-gateway)" 2>/dev/null; true)
```

**Step 2 — db-sync (blocking, must finish before servers start):**
```bash
cd /Users/toc/Server/one-ie/one.ie/web && bun run db:sync
```

**Step 3 — start three servers (three separate background Bash calls, all in parallel):**
```bash
# Astro — web UI
cd /Users/toc/Server/one-ie/one.ie/web && bun run dev

# Gateway — TypeDB-backed local gateway on 8788
cd /Users/toc/Server/one-ie/one.ie/web && bun run dev:gateway

# Channels worker — wrangler on 8787 (`bun run dev` = bare `wrangler dev`)
cd /Users/toc/Server/one-ie/channels && bun run dev
```

`/kill` puts `one.ie/web`'s `dev:wrangler` on 8787 instead. Only one of the two
can hold that port — don't run both; the second bind fails.

Poll `http://localhost:4321/` until 200, then confirm all three up:
- Astro: http://localhost:4321 → 200
- Gateway: http://localhost:8788 → 404 (expected)
- Channels: http://localhost:8787 → 401 (expected)

## When to use /kill instead

- HMR broken / duplicate React hooks → `/kill` (clears Vite cache)
- Dep version drift → `/kill` (reinstalls)
- Ghost port won't release → `/kill`
