---
name: astro
description: Build pages, layouts and API routes in `one.ie/web` — Astro 6 + React 19 islands on Cloudflare Workers. Covers the real astro.config.mjs shape, adapter v13, SSR vs prerender, the `(await import('cloudflare:workers')).env` access pattern, and the LOCKED bundle-size rules. Use when editing `.astro` files, `astro.config.mjs`, or `src/pages/api/**`. For the `template/` tree use `template:astro` (Astro 7) instead.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Astro 6 on Cloudflare Workers — `one.ie/web`

**Which tree:** this skill describes `one.ie/web` only — Astro 6, single Cloudflare
adapter. `template/site` is a **different major** (Astro 7) with its own conventions;
use the `template:astro` skill there. Every claim below was checked against
`one.ie/web/astro.config.mjs` and `one.ie/web/package.json` on 2026-08-02.

Server-rendered pages with strategic React islands, on `@astrojs/cloudflare@13` +
Workers with Static Assets (the Pages era is retired).

## Stack

| Package | Declared (2026-08-02) | Role |
|---|---|---|
| `astro` | `^6.2.2` (6.3.7 installed) | Framework |
| `@astrojs/cloudflare` | `^13.3.1` | Workers adapter (no longer supports Pages) |
| `@astrojs/react` | `^5.0.4` | React 19 islands |
| `@astrojs/node` | `^10.0.6` | Declared but **unused** — not imported by `astro.config.mjs` |
| `wrangler` | `^4.14.0` | Workers CLI |

`@astrojs/node` is a leftover dependency. There is no dev/prod adapter swap in this
tree — don't add one back on the strength of the package being present.

## Works With

| Skill      | Load when                                                                             |
|------------|---------------------------------------------------------------------------------------|
| `/react19` | React components inside islands — pick `client:load` / `client:visible` / `client:only`. |
| `/cloudflare` | `wrangler.toml`, `[assets]` binding, secrets, `wrangler tail`, Workers+Assets semantics. |
| `/signal`  | `src/pages/api/*.ts` — every API route is the substrate's HTTP surface.                |
| `/shadcn`  | shadcn components live inside islands; dark-theme tokens + hydration strategy.         |
| `/sui`     | SSR pages reading on-chain data — use `client:only="react"` to keep the worker small.  |
| `/typedb`  | SSR data fetching — pages call `typedbQuery()` from `src/lib/substrate.ts`.            |

Auto-loads on `*.astro`: `.claude/rules/astro.md`. The deploy pipeline (8 steps,
Astro build is step 3) is the `/deploy` **command**, not a skill:
`.claude/commands/deploy.md`.

## The Config (the ONE shape)

One adapter, always Cloudflare. `astro.config.mjs` is ~200 lines — three Vite plugins,
a large `optimizeDeps` block, and a Durable-Object export plugin. **Read the file for
the rest; the load-bearing shape is:**

```js
// astro.config.mjs — the parts this skill's rules depend on
export default defineConfig({
  output: 'server',                    // all routes SSR unless prerender=true
  adapter: cloudflare({
    prerenderEnvironment: 'node',      // prerender under node, not workerd
    imageService: 'passthrough',
    sessions: false,
    remoteBindings: false,
    // NOT { enabled: true } — loading [env.production] during build sync
    // makes Miniflare evaluate the DO before the export plugin runs
    platformProxy: { environment: undefined },
  }),
  integrations: [react(), devWarmupIntegration()],
  build: { inlineStylesheets: 'auto' },   // LOCKED — never 'always'
  markdown: { syntaxHighlight: false },   // LOCKED — keeps Shiki out of the worker
  security: { checkOrigin: false },
  vite: { /* ssr.external, ssr.noExternal, optimizeDeps, plugins — see the file */ },
})
```

**Don't copy a `vite.ssr` list out of this skill.** `astro.config.mjs` §
`vite.ssr.external` is the authority (`.claude/skills/deploy/REFERENCE.md` Rule 2 says so
explicitly: *never reconcile that file to a doc*). Note the direction — `recharts`,
Stripe, `@xyflow/react`, `motion`, `media-chrome` and the 100ms packages are
**external**; `react`, `react-dom`, `@astrojs/react`, `better-auth` and `kysely` are
**noExternal**. Getting that backwards breaks the build.

A companion `ssrExternalPlugin()` also swaps three packages for tiny SSR stubs
(`pusher-js`, `media-chrome/react`, `@mux/mux-player-react` → `src/lib/stubs/`).

## Adapter v13 — What Changed from Astro 5/v12

| Change | v12 (old) | v13 (current) | Action |
|---|---|---|---|
| Pages support | ✓ | **removed** | Deploy target is Workers + Static Assets only |
| `output: "hybrid"` | ✓ | **removed** | Use `"server"` + `prerender = true` per-page, or `"static"` + `prerender = false` |
| `Astro.locals.runtime` | populated | **removed** | Use `cloudflare:workers` (see below) |
| `prerenderEnvironment` | n/a | `workerd` default | ONE sets `'node'` — prerender breaks under workerd here |
| `imageService` default | `"compile"` | `"cloudflare-binding"` | ONE overrides to `'passthrough'` — no IMAGES binding needed |
| `sessionKVBindingName` | n/a | default `"SESSION"` | ONE sets `sessions: false`; the `SESSION` KV is used directly |
| `workerEntryPoint` | option | **removed** | Adapter emits the bundled entry; `dist/server/wrangler.json` injects it |
| `cloudflareModules` | option | **removed** | Use Vite's built-in WASM/text imports |

**Migration memory:** check adapter + deploy-target compatibility BEFORE bumping
Astro major. Astro 6's `@astrojs/cloudflare@13` dropped Pages in a single minor jump;
~8-commit cascade to fix.

## Output Modes (Astro 6)

```astro
// Per-page opt-in / opt-out (works under any output mode)
export const prerender = true   // force static — skips worker
export const prerender = false  // force SSR  — runs in worker
```

| `output` | Default per page | Use when |
|---|---|---|
| `"static"` | prerendered | Mostly-static sites with few dynamic pages |
| `"server"` | SSR | ONE's choice — most routes are dynamic; static pages opt in |
| `"hybrid"` | — | **removed** in Astro 6; use `"server"` + per-page `prerender = true` |

**ONE's rule:** `output: "server"`. Static shell pages export `prerender = true` AND
load heavy islands with `client:only="react"`, so the worker ships no React for them.
Current split in `src/pages`: 53 files `prerender = true`, 601 `prerender = false`.

## cloudflare:workers — The Canonical Env Import

**Always the dynamic form.** A top-level `import { env } from "cloudflare:workers"`
is not used anywhere in this tree (0 files under `src/`); the dynamic import is (407 files). The
static import resolves at module-eval time, which breaks prerender and any non-worker
context that touches the module.

```ts
// src/pages/api/whatever.ts (SSR API route)
import type { APIRoute } from "astro";

type Env = { DB?: D1Database; SESSION?: KVNamespace }

async function getEnv(): Promise<Env> {
  return (await import('cloudflare:workers' as string)).env as Env
}

export const GET: APIRoute = async () => {
  const env = await getEnv()
  if (!env.DB) return Response.json({ error: 'no_db' }, { status: 503 })
  const { results } = await env.DB.prepare("SELECT * FROM signals LIMIT 10").all();
  return Response.json({ signals: results });
};
```

**Typing.** There is no `worker-configuration.d.ts` in this tree and `wrangler types`
is not wired into any script. Bindings are typed by hand in `src/env.d.ts` — the
`Runtime` interface lists every binding (`DB`, `CONTENT`, `SESSION`, `CHAT_CACHE`,
`ANALYTICS_HUB`, `WORKFLOW_RUN`, …) alongside `App.Locals`. Add a new binding there
when you add it to `wrangler.toml`. Routes that declare a narrow local `Env` type (as
above) are the prevailing pattern.

### Legacy `Astro.locals.runtime.env` (compat shim)

`src/env.d.ts` still declares `runtime?: Runtime` on `App.Locals`, and 7 files read
`locals?.runtime?.env?.*` from the Astro 5 era. **New code uses the dynamic
`cloudflare:workers` import** — it survives the shim's removal.

## Hydration Directives (unchanged in Astro 6)

```astro
client:load       → Hydrate immediately (above-fold, critical)
client:idle       → Hydrate on requestIdleCallback (non-critical widgets)
client:visible    → Hydrate when scrolled into view (below-fold)
client:only="react" → Client-only, skip SSR entirely (heavy deps, keeps worker bundle small)
client:media="(min-width: 768px)" → Hydrate on media query match
```

**Bundle rule (LOCKED):** heavy components (shiki, recharts, Stripe, 100ms, Puck)
MUST be `client:only="react"` OR listed in `vite.ssr.external`. Both together is the
common case — `ssr.external` is only safe when the package never executes on the
server path, and `client:only` is what guarantees that. 216 `client:only="react"`
uses across pages and components today.

## Page Patterns

### Pure-shell pre-rendered page

```astro
---
// src/pages/about.astro — stays out of the worker entirely
import Layout from "@/layouts/Layout.astro";
import HeavyChart from "@/components/HeavyChart";
export const prerender = true;
---
<Layout title="About">
  <HeavyChart client:only="react" />
</Layout>
```

### SSR page reading CF bindings

```astro
---
// src/pages/dashboard.astro
import Layout from "@/layouts/Layout.astro";
import Dashboard from "@/components/Dashboard";

const { env } = await import('cloudflare:workers' as string);
const paths = (await env.CHAT_CACHE?.get("paths.json", "json")) ?? [];
---
<Layout title="Dashboard">
  <Dashboard client:load paths={paths} />
</Layout>
```

### API route (signal receiver)

```ts
// src/pages/api/signal.ts
import type { APIRoute } from "astro";

export const prerender = false

export const POST: APIRoute = async ({ request }) => {
  const { env } = await import('cloudflare:workers' as string);
  const signal = await request.json();
  await env.CHAT_CACHE.put(`signal:${Date.now()}`, JSON.stringify(signal));
  return Response.json({ received: true });
};
```

## Bundle-Size Rules (LOCKED — do not revert)

Wrangler reports both `Total Upload` (uncompressed) and `gzip` — only gzip counts.
The documented ceiling is **3 MiB gzipped** free tier / 10 MiB paid, but this
account's real ceiling is **unconfirmed**: deploys at 3.22 MiB (2026-07-08) and
4.43 MiB (2026-07-19) both succeeded. Treat the current number as a floor to watch,
not a hard gate, and re-run the diagnosis if it keeps climbing.
`.claude/skills/deploy/REFERENCE.md § Bundle Size Rules` + § Verified Bundle Numbers is the
authority — reconcile to it, not to this table.

| Rule | Where | Saves |
|---|---|---|
| `markdown: { syntaxHighlight: false }` | `astro.config.mjs` | ~5.8 MiB (Shiki grammars/WASM) |
| `vite.ssr.external` for heavy packages | `astro.config.mjs` | Bare imports — safe only if the package never runs server-side (shiki's callers are all `client:only`) |
| `prerender = true` + `client:only="react"` on shell pages | per-page | Page handler collapses to a stub; no React in the worker |
| `build: { inlineStylesheets: 'auto' }` — **NEVER `'always'`** | `astro.config.mjs` | ~8 MiB at 100+ routes. `'always'` inlines the full Tailwind stylesheet into every route's manifest entry. `'auto'` ships one external `<link>`. |
| `react-dom/server` → `react-dom/server.edge` alias, production only | `astro.config.mjs` `vite.resolve.alias` | Ships the edge build instead of the Node build |

Verified deltas:
- 2026-04-15: 21 MiB Pages → 9.5 MiB Worker (Rules 1-3). Pages deploy FAILED → Workers ✓.
- 2026-05-22: worker-entry 9.5 MiB → 672 KiB (Rule 4). gzip 3.3 MiB → 2.1 MiB.

## Dev Commands

```bash
bun run dev          # localhost:4321 — regenerates playbook meta + promises, then astro dev
bun run build        # builds @oneie/sdk, astro build, patches dist/server/wrangler.json
bun run preview      # astro preview (NOT wrangler — see dev:wrangler for production shape)
bun run dev:wrangler # build + wrangler dev against dist/server/wrangler.json on :8787
bun run check        # astro check
bun run typecheck    # tsc --noEmit
bun run verify       # build SDK + typecheck + vitest — the gate

# Bindings against real CF resources
bun wrangler dev --remote    # production KV/D1 — use with care
```

There is no `wrangler types` step. Bindings are hand-typed in `src/env.d.ts`.

## Dynamic Routes

Real routes in this tree:

```
src/pages/
  p/[slug].astro             → /p/my-landing-page
  studio/[agent].astro       → /studio/donal
  u/[slug]/[...path].astro   → catch-all under a workspace
  go/[id].ts                 → a dynamic API-shaped route (.ts, not .astro)
  tasks/[...view].astro      → catch-all
```

```astro
---
// src/pages/studio/[agent].astro
export const prerender = false
const { agent } = Astro.params;
if (!agent) return new Response(null, { status: 404 });
---
<Layout title={`Studio: ${agent}`}>
  <AgentCard client:load agentId={agent} />
</Layout>
```

## File Locations

| Type | Location |
|------|----------|
| Pages | `src/pages/*.astro` |
| API routes | `src/pages/api/**/*.ts` |
| Layouts | `src/layouts/*.astro` |
| React islands | `src/components/**/*.tsx` |
| Content collections | `src/content.config.ts` + `src/content/` |
| Astro config | `astro.config.mjs` |
| Worker config | `wrangler.toml` (`main` intentionally omitted) |
| Binding + Locals types | `src/env.d.ts` |

## Performance Budgets (from `text/speed.md`)

| Metric | Measured |
|---|---|
| Routing decision (in-memory) | <0.005ms (320 tests) |
| KV read / highway cache (edge) | <10ms |
| `ask()` round-trip (no LLM) | 50–200ms |
| Chat TTFB p50 (browser) | ~97ms — gate ≤100ms |
| Agent first SSE token (end-to-end) | ~500ms |

Static pages served from the `[assets]` binding don't count against request quota —
pre-render anything that doesn't need SSR.

## Common Tasks

Five sub-workflows live beside this file: `create-page.md`, `create-component.md`,
`add-content-collection.md`, `check-build.md`, `optimize-performance.md`.

### Add a new page

1. Create `src/pages/<name>.astro` with a Layout import
2. If mostly static → `export const prerender = true`
3. If it needs CF bindings → `await import('cloudflare:workers')` in frontmatter
4. React islands: default to `client:visible`; `client:load` only for above-fold critical UI

### Add an API route

1. Create `src/pages/api/<name>.ts`, `export const prerender = false`
2. Export `GET` / `POST` / `PUT` / `DELETE` as `APIRoute`
3. Read bindings via `(await import('cloudflare:workers')).env`
4. Authorize before touching workspace data (`authorizeWorkspace` from `@/lib/analytics/authz`)
5. Return `Response.json(...)` or `new Response(...)`

### Convert static component to interactive

1. Create `.tsx` in `src/components/`
2. Import into the `.astro` page
3. Pick directive: above-fold → `client:load`, below-fold → `client:visible`, heavy → `client:only="react"`

### Type a new binding

1. Add the binding to `wrangler.toml` (`[[kv_namespaces]]`, `[[d1_databases]]`, etc.)
2. Add the field to the `Runtime.env` interface in `src/env.d.ts` (by hand — no codegen)
3. Narrow it in the route's local `Env` type where you read it

## Gotchas

- **Dev and prod both run the Cloudflare adapter**, but dev goes through Vite +
  Miniflare. Behaviour still diverges — `bun run dev:wrangler` for a production-shape smoke.
- **A top-level `import { env } from "cloudflare:workers"` breaks prerender.** Always
  the dynamic form. Zero files in this tree use the static one.
- **`import.meta.env.*`** is build-time only. Runtime secrets/bindings come from `env`.
- **Shiki will crash your deploy** if imported from SSR. All callers must be `client:only="react"`.
- **`output: "hybrid"`** throws in Astro 6. Replace with `"server"` + per-page `prerender = true`.
- **Never delete a `vite.ssr.external` entry to match a doc snippet** — the config file is
  the authority and the list is longer than any snippet.
- **A `{/* … */}` comment in ATTRIBUTE position inside an opening tag is parsed as
  an expression.** Any backtick in the prose opens a template literal, and
  `astro check` then reports `Unterminated string literal` **at EOF**, blaming the
  closing tag while the source looks fine. `tsc` ignores `.astro`, so
  `check:ratchet` is the only gate that catches this class (measured 2026-09-14).
  Put such prose in the frontmatter as `//` comments.
- **`platformProxy: { enabled: true }`** is wrong here. This tree uses
  `{ environment: undefined }` so `astro build` doesn't make Miniflare evaluate the
  Durable Object before `durableObjectExportsPlugin` has run.

## References

- [Astro Cloudflare adapter](https://docs.astro.build/en/guides/integrations-guide/cloudflare/) — authoritative for v13
- [CF Workers framework guide — Astro](https://developers.cloudflare.com/workers/frameworks/framework-guides/astro/)
- `.claude/commands/deploy.md` — the pipeline, the gates, rollback · `.claude/skills/deploy/REFERENCE.md` — the 5 LOCKED bundle rules + verified numbers (split out 2026-09-17)
- `.claude/rules/astro.md` — auto-loaded on `*.astro` edits
- `one.ie/web/astro.config.mjs` — the authority for adapter options and every `vite.ssr` list

---

**Version**: 3.0.0 — reconciled against `one.ie/web` (2026-08-02)
**Previous**: 2.0.0 (2026-04-18, described a dual-adapter config this tree never had)
