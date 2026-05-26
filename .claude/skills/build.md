---
name: build
description: Build the ONE Astro app (`one.ie/web/`) for production via `bun run build` — emits `dist/` for CF Workers Static Assets. Use when the user asks to "build for production", "check bundle size", or as the pre-deploy gate. Scope is `one.ie/web/` only; the four Workers (agents/api/sync/backup) build via wrangler — use /cloudflare instead.
user-invocable: true
allowed-tools: Bash
---

# Build ONE web (one.ie/web)

**Skills:** `/deploy` (wraps this as step 3 of the 8-step pipeline) · `/astro` (bundle-size rules — `markdown.syntaxHighlight: false`, `ssr.external`, keeps the CF Worker bundle under 10 MiB)

Build the Astro + React 19 project for production.

## Command

```bash
cd /Users/toc/Server/one-ie/one.ie/web && bun run build
```

## Expected Output

```
╭────────────────────────────────────────────────╮
│  BUILD RESULTS                                 │
├────────────────────────────────────────────────┤
│  ✓ Astro build complete                        │
│  ✓ React components bundled                    │
│  ✓ Static pages generated                      │
│  ✓ Output: dist/                               │
╰────────────────────────────────────────────────╯
```

## Build Artifacts

- `dist/` - Production build output
- `dist/_astro/` - Bundled assets (JS, CSS)
- `dist/index.html` - Entry page

## Error Handling

If build fails:
1. Check TypeScript errors with `bun run build` output
2. Verify all imports resolve correctly
3. Check for missing dependencies

## Preview Production Build

```bash
bun preview
```

Opens at http://localhost:4321
