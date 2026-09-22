# /kill — Reset dev environment

Stop all Astro dev servers (ports 4321–4329) and all CF/wrangler ports (8787–8799), clear node + astro + vite caches, run `bun install`, then `bun run dev`.

Use when HMR is broken, Vite re-optimization desyncs deps (duplicate React `useContext` is null, `createRoot` not exported with two `?v=hash` URLs), ghost ports refuse to release, or the user says "kill", "nuke", "reset dev", or "full clean rebuild".

Scope is `one.ie/web/` only.

## ⛔ NEVER DELETE — local database lives here

**`.wrangler/` must NEVER be deleted.** It contains the local database:

| Path | Contains |
|------|----------|
| `.wrangler/state/v3/d1/` | Local D1 SQLite databases |
| `.wrangler/state/v3/kv/` | Local KV store |
| `.wrangler/state/v3/r2/` | Local R2 buckets |
| `.wrangler/state/v3/do/` | Durable Object storage |
| `.wrangler/state/v3/workflows/` | Workflow state |

Deleting `.wrangler/` wipes all local data. There is no undo. Do not include it in any `rm` command, ever — not even in a "full nuke".

## What it does (in order)

1. **Kill** any process bound to ports 4321–4329 (Astro) and 8787–8799 (wrangler/CF Workers), plus lingering `astro dev` / `wrangler dev` / `vite` / `workerd` / `miniflare` processes
2. **Clear** caches only — `.astro`, `node_modules/.vite`, `node_modules/.astro`, `dist` — nothing else
3. **Reinstall** via `bun install`
4. **Start all three servers** in background:
   - `bun run dev` — Astro on 4321
   - `bun run dev:gateway` — local gateway on 8788 (use the plain script, not `dev:gateway:bg`: the `:bg` variant self-forks and returns immediately, so a `run_in_background: true` Bash call would report "done" while the gateway is still booting)
   - `bun run dev:wrangler` — CF Worker on 8787 (requires build; slow ~30s)

## One-shot command

Run the kill + reinstall first, then start all three servers. Each server starts in background (`run_in_background: true`).

⚠️ The port sweep below also hits other projects' dev servers parked in 4321–4329 (e.g. `apps/one/site` on 4322). If a neighbour project is running, drop its port from the list — and never re-add blanket `pkill -f "astro dev"`-style patterns; they kill every Astro/vite on the machine across all sessions.

**Step 1 — kill + reinstall:**
```bash
cd /Users/toc/Server/one-ie/one.ie/web && \
  (lsof -ti:4321,4322,4323,4324,4325,4326,4327,4328,4329,8787,8788,8789,8790,8791,8792,8793,8794,8795,8796,8797,8798,8799 2>/dev/null | xargs kill -9 2>/dev/null; \
   pkill -f "one\.ie/web.*(astro|vite|workerd|miniflare|wrangler)" 2>/dev/null; true) && \
  rm -rf .astro node_modules/.vite node_modules/.astro dist && \
  bun install
```

**Step 2 — start all servers (each as a separate background Bash call):**
```bash
# Astro
cd /Users/toc/Server/one-ie/one.ie/web && bun run dev

# Gateway
cd /Users/toc/Server/one-ie/one.ie/web && bun run dev:gateway

# CF Worker (requires build — starts slower)
cd /Users/toc/Server/one-ie/one.ie/web && bun run dev:wrangler
```

Confirm Astro is up on 4321, gateway is up, and wrangler is up on 8787 by checking logs.

## When NOT to use

- Cache-only fix would do → `rm -rf node_modules/.vite .astro && bun run dev` (~3s); this is ~30s
- Production / deploy issues → use `/deploy` (there is no `/build` command — the build step lives inside `/deploy`, or run `cd one.ie/web && bun run build`)
- TypeScript errors only → `cd one.ie/web && bun run typecheck` (there is no `/typecheck` command); cache reset won't fix code
- Dependency version drift suspected → manually `rm -rf node_modules bun.lock && bun install` (this command preserves both)

## Diagnostic order (cheapest first)

1. `rm -rf node_modules/.vite .astro && bun run dev` — clears Vite + Astro cache only (~3s)
2. **This command** — kills servers + clears caches + reinstall (~30s)
3. Full nuke: `rm -rf node_modules bun.lock .astro dist && bun install && bun run dev` (~90s) — only if dependency tree itself is suspect. **Never include `.wrangler/`.**
