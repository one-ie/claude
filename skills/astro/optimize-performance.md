# Optimize Astro Performance

**Category:** astro
**Version:** 2.0.0
**Used By:** `astro` skill · `/do` W4 verify wave

## Purpose

Cut worker bundle size and page latency in `one.ie/web`. Two separate budgets: the
**upload** (gzip, gated at deploy) and the **request** (TTFB, measured in
`text/speed.md`).

## Recommendations

Bundle — the 5 LOCKED rules, authority `.claude/skills/deploy/REFERENCE.md § Bundle Size Rules`
(moved there from `.claude/commands/deploy.md` on 2026-09-17, verbatim):

- `markdown: { syntaxHighlight: false }` — keeps ~5.8 MiB of Shiki grammars out.
- `vite.ssr.external` for heavy client-only packages. **`astro.config.mjs` is the
  authority for that list** — never trim it to match a snippet in a doc.
- `export const prerender = true` + `client:only="react"` on shell pages, so the worker
  ships no React for them.
- `build: { inlineStylesheets: 'auto' }` — **never `'always'`** (~8 MiB at 100+ routes).
- `react-dom/server` → `react-dom/server.edge` alias in production.

Runtime:

- Pick the cheapest hydration directive that works: `client:visible` below the fold,
  `client:only="react"` for heavy trees, `client:load` only above the fold.
- Smart Placement is on (`[placement] mode = "smart"` in `wrangler.toml`) — the isolate
  runs near D1/R2/DO instead of at the visitor's PoP. Don't remove it; it was dropped
  once in a config rewrite and cost ~1s of pre-flight per chat turn.
- `optimizeDeps.include` / `ssr.optimizeDeps.include` in `astro.config.mjs` pre-bundle
  React and friends at boot. Mid-session re-optimisation produces two `?v=` hashes for
  react-dom and breaks hydration — add new hot deps to the list rather than debugging
  the symptom.
- Static assets come from the `[assets]` binding and don't count against request quota.

Measure, don't guess: `text/speed.md` carries the real table (routing <0.005ms, KV read
<10ms, `ask()` 50–200ms, chat TTFB p50 ~97ms, first SSE token ~500ms). Run
`.claude/skills/deploy/REFERENCE.md § Bundle Size Diagnosis` before optimising a bundle.

**Not applicable here:** `@astrojs/image` — deprecated and not a dependency of this
repo. Astro's built-in `astro:assets` replaces it.

## Version History

- **2.0.0** (2026-08-02): Replaced generic advice with the 5 LOCKED bundle rules, Smart
  Placement, the optimizeDeps trap, and the real speed table; dropped `@astrojs/image`.
- **1.0.0** (2025-10-18): Initial implementation
