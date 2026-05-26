# /kill — Reset dev environment

Stop all Astro dev servers (ports 4321–4329) and wrangler (8787), clear node + astro + vite + wrangler caches, run `bun install`, then `bun run dev`.

Use when HMR is broken, Vite re-optimization desyncs deps (duplicate React `useContext` is null, `createRoot` not exported with two `?v=hash` URLs), ghost ports refuse to release, or the user says "kill", "nuke", "reset dev", or "full clean rebuild".

Scope is `one.ie/web/` only.

## What it does (in order)

1. **Kill** any process bound to ports 4321–4329 (Astro) and 8787 (wrangler), plus lingering `astro dev` / `wrangler dev` / `vite` / `workerd` processes
2. **Clear** caches only — `.astro`, `node_modules/.vite`, `node_modules/.astro`, `dist` (preserves `node_modules` + `bun.lock` so install is fast; preserves `.wrangler/state` to keep local KV/D1/R2/DO data)
3. **Reinstall** via `bun install`
4. **Start** `bun run dev`

## One-shot command

Run this exactly:

```bash
cd /Users/toc/Server/one-ie/one.ie/web && \
  (lsof -ti:4321,4322,4323,4324,4325,4326,4327,4328,4329,8787 2>/dev/null | xargs kill -9 2>/dev/null; \
   pkill -f "astro dev" 2>/dev/null; \
   pkill -f "wrangler dev" 2>/dev/null; \
   pkill -f "vite" 2>/dev/null; \
   pkill -f "workerd" 2>/dev/null; true) && \
  rm -rf .astro node_modules/.vite node_modules/.astro dist && \
  bun install && \
  bun run dev
```

Start the final `bun run dev` in the background (`run_in_background: true`) so you can monitor logs and confirm the server is up on 4321.

## When NOT to use

- Cache-only fix would do → `rm -rf node_modules/.vite .astro && bun run dev` (~3s); this is ~30s
- Production / deploy issues → use `/deploy` or `/build`
- TypeScript errors only → use `/typecheck`; cache reset won't fix code
- Dependency version drift suspected → manually `rm -rf node_modules bun.lock && bun install` (this command preserves both)

## Diagnostic order (cheapest first)

1. `rm -rf node_modules/.vite .astro && bun run dev` — clears Vite + Astro cache only (~3s)
2. **This command** — kills servers + clears caches + reinstall (~30s)
3. Full nuke: `rm -rf node_modules bun.lock .astro dist && bun install && bun run dev` (~90s) — only if dependency tree itself is suspect
