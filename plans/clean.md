# Clean Architecture — ONE Agents

> One runtime. One soul per workspace. Web is a UI shell. Channels is the brain.

---

## The Problem

Two workers both run LLM logic:

| Worker | Entry point | Lines |
|--------|-------------|-------|
| `agents/` (channels) | `src/index.ts` | 493 |
| `one.ie/web/` | `src/pages/api/chat.ts` | 1,226 |

Same soul lookup. Same provider routing. Same tool execution pattern. Written twice, drifting apart. When one changes, agents behave differently on web vs Telegram with no visible reason.

The root cause: `channels` was designed as a single-tenant bot (one `WORKSPACE_SLUG` env var per deployment). The web worker filled the gap for multi-tenant web chat. They became parallel runtimes by accident, not design.

---

## The Fix: One Runtime

`channels` already has everything it needs to be the single agent runtime:

- `ONE_DB` — the shared D1 with `workspace_settings` (the soul)
- `DB` — message + path storage
- `KV` — context cache, memory store
- Hono router, AI SDK v6, substrate tools, composio, orchestration

The only thing missing: `CONTENT` (R2) for per-slug agent files. Add that binding and `channels` can serve every surface.

The single-tenant constraint is one line: `env.WORKSPACE_SLUG ?? 'claw'`. Change it to read `slug` from the request body and `channels` becomes multi-tenant. `BOT_PERSONA` still works as a worker-level default for dedicated bot deployments.

---

## The Architecture

```
                        ┌─────────────────────────────┐
  Telegram / Discord ──→│                             │
  HTTP peer signals ──→│      channels worker        │──→ TypeDB (via api.one.ie)
  Web browser      ──→│   (one runtime, all surfaces) │──→ D1 · KV · R2
  Orchestrator     ──→│                             │
                        └─────────────────────────────┘
                                      ↑
                        one.ie/web proxies /api/chat here
                        (20 lines — auth + fetch)
```

`one.ie/web` becomes a UI shell: Astro renders pages, React handles interaction, auth lives here. Zero LLM code. Every agent turn goes through `channels`.

---

## What Goes Where

### `channels/` — the agent runtime

Handles all surfaces. Multi-tenant per request — `slug` comes from the message body.

```
channels/src/
├── index.ts          ← Hono router — /message, /webhook, /signal, /orchestrate, /stream
├── agents/builder.ts ← makeAgent() — ToolLoopAgent per persona
├── tools/
│   ├── substrate.ts  ← mark, warn, signal, fade, follow (always present)
│   ├── web.ts        ← emit_card, emit_section, emit_chips (web channel only)
│   └── workspace.ts  ← compile, patch_agent, billing, eval (owner channel only)
├── ingress.ts        ← Telegram + Discord normalize/send (was channels.ts — see naming below)
├── middleware.ts     ← provider routing + substrateMiddleware
├── personas.ts       ← worker-level defaults (BOT_PERSONA opt-in)
├── context.ts        ← slug → soul → system prompt (replaces prompt.ts + loadContext)
├── orchestrate.ts    ← parallel/race/jury
└── types.ts
```

Tools are layered by channel:

| Layer | Tools | When active |
|-------|-------|-------------|
| Substrate | mark, warn, signal, fade, follow | Always |
| Web | emit_card, emit_section, emit_chips, cro | `channel = 'web'` |
| Workspace | compile, patch_agent, billing, eval | `channel = 'web'` + authenticated owner |
| Skills | loaded from KV per userId | When userId present |
| Composio | fallback toolkit | When COMPOSIO_API_KEY + userId |

### `one.ie/web/` — the UI shell

No LLM logic. No tool definitions. No soul injection.

```
one.ie/web/src/pages/api/chat.ts   ← ~20 lines
  1. verify auth (requireAuth or visitor cookie)
  2. resolve CHANNELS_URL from env
  3. proxy: fetch(CHANNELS_URL + '/message', { body: { slug, group, messages } })
  4. stream the response back
```

Everything else in `one.ie/web/` stays: Astro pages, React components, auth, sessions, CRO decisions (computed client-side or in middleware, not in the agent loop), x402 payment verification at the route level.

### `packages/sdk/src/soul.ts` — the one shared primitive

```ts
// Single source of truth for workspace soul injection.
// Used by channels worker. Imported by @oneie/sdk.
export async function readWorkspaceSoul(db: D1Database, slug: string): Promise<string>
```

Replaces `readSoulSuffix` in `agents/src/prompt.ts` and `buildCompanyContextSuffix` in `one.ie/web/src/lib/in/workspace-settings.ts`.

### `one.ie/agents/` — agent definitions (unchanged)

Markdown files. Data, not code. Consumed by `channels` (via `personas.ts` + R2) and `@oneie/sdk` (parse → TypeDB).

---

## Every Agent Turn

```
Request arrives (any channel)
  │
  ├─ slug from body (web) or WORKSPACE_SLUG env (bot deployment)
  │
  ▼
context.ts
  ├─ readWorkspaceSoul(ONE_DB, slug)       ← soul
  ├─ recall(KV/TypeDB, group, userId)      ← memory pack
  └─ load persona (R2 or personas.ts)      ← identity
  │
  ▼
makeAgent(env, persona, group, userId)
  ├─ substrate tools (always)
  ├─ web/workspace tools (channel = 'web')
  ├─ skill tools (userId present)
  └─ composio fallback (COMPOSIO_API_KEY)
  │
  ▼
ToolLoopAgent → LLM → tools → LLM → ...
  │
  ▼
close the loop
  ├─ mark() on success
  └─ warn() on failure
```

---

## The Migration

Seven steps. Each is independently shippable.

### Step 1 — Rename `agents/` directory → `channels/`
The runtime directory and the wrangler worker name should match. After this, `agents/` unambiguously means definitions (`one.ie/agents/`). The runtime is `channels/`.

```bash
mv agents/ channels/
# update wrangler.toml: name = "channels"
# update package.json: "name": "channels"
# update root README and any CI scripts referencing agents/
```

### Step 2 — Rename `channels/src/channels.ts` → `ingress.ts`
A file called `channels.ts` inside a worker called `channels/` is a naming trap. The file normalizes inbound signals from Telegram and Discord — it's an ingress normalizer, not a channel definition. Rename it and update the single import in `index.ts`.

### Step 3 — Delete `channels/src/adapters/`
602 lines of Shopify, Stripe, HubSpot, Salesforce, Klaviyo, and GHL adapters. Not imported anywhere in the worker — confirmed dead code. Delete the directory.

### Step 4 — `packages/sdk/src/soul.ts`
Extract the soul function. Nothing breaks. Both workers still use their own copy until Step 5/6 land.

### Step 5 — Make `channels` multi-tenant
Change `loadContext` to accept `slug` from the request body. Fall back to `WORKSPACE_SLUG` env for dedicated bot deployments. Add `CONTENT` R2 binding to `wrangler.toml`. Import `readWorkspaceSoul` from `@oneie/sdk`.

### Step 6 — The proxy contract (the keystone)
chat.ts's tools read Astro `locals` (session, workspaceContext, viewer); `channels` has no `locals`. So before any tool can move, the `/message` contract must carry that data as JSON: `viewer{id,role,owner}`, `surface`, `agentId`, `channel`. Thread these through `CallOptions` + `makeAgent.prepareCall` so tool `execute` reads them. No tools move yet — this is the data spine the rest hangs off.

### Step 7 — Tools are a thin skin over the substrate (two layers, zero callbacks)
chat.ts's ~15 tools resolve against the substrate `channels` already owns — never a fetch back into web:
- **Pure output envelopes** (`emit_card/section/chips/boq/event`) → `tools/web.ts`, gated `channel='web'`. `emit_card` already exists — reuse it.
- **Owner ops** (`patch_agent/patch_theme/delegate/field-service/skill/compile/import_skill/draft_social/action`) → `tools/workspace.ts`, gated `channel='web' + viewer.owner`, each resolving natively: D1 writes (`patch_agent`→`agents.frontmatter`, `patch_theme`→`themes.tokens`, `field-service`→`field_service_bookings`, `draft_social`→reuse), `CONTENT` R2 (`skill`/`import` + ported pure `compile`/agent-md parse), or a substrate `signal()` (`delegate`; heavy `eval`→`signal('skill:eval')`).

**The rule:** `channels` never fetches `web`. The cross-worker mechanism is the substrate `signal()`/`ask()` receiver namespace — the documented API — not bespoke HTTP. The old "web-callbacks via `WEB_URL`" idea was a cycle (web→channels→web); it's deleted. `delegate_to` was *already* a signal wearing an HTTP disguise.

### Step 8 — Persona: unify the lookup, keep the fallback
`channels` resolves a per-slug agent from its `.md` in `CONTENT` R2 (`${slug}/agents/${id}.md` → `parseAgentMd`), falling back to `personas[BOT_PERSONA]` then `personas.one`. **`personas.ts` is kept** — `one`/`concierge` have no `.md`, so deleting it would lose the web default. Port `parseAgentMd`/`buildPersonaSystem` into channels (no `@oneie/sdk` dep — channels stays standalone).

### Step 9 — chat.ts → gates + proxy
Replace chat.ts's LLM/tool/soul block with a `fetch(CHANNELS_URL/message, enrichedBody)` + SSE passthrough (channels already emits the UIMessage SSE the web client expects). **The request-gates stay** — auth, billing pool, rate-limit, x402 receipt, CRO variant+cookie are request-level, not agent logic. chat.ts ends ~80-120 lines of gates around a proxy, not 20. Add `CHANNELS_URL` to `one.ie/web/wrangler.toml`.

**Data note:** the `claw:${group}` substrate prefix is **kept literal** (decoupled from the directory/worker name — the goal is one runtime serving many slugs, not a data-namespace migration). No D1/TypeDB row migration.

---

## Longer Term — Personas from Markdown

`channels/src/personas.ts` defines `one`, `concierge`, `cmo`, `strategist`, `copywriter`, `analyst` as hardcoded TypeScript objects. The same roles exist as `.md` files in `one.ie/agents/`. Two sources of truth for the same thing.

The endpoint: `personas.ts` is deleted. `channels` loads personas at startup by parsing the agent `.md` files from R2 (or the bundled `one.ie/agents/` directory). `BOT_PERSONA` becomes a key into the parsed `.md` inventory rather than a key into a hardcoded map.

This makes "agent definitions are data, not code" true for *per-slug* agents — a workspace's own agents live as `.md` in R2 and drive its turns.

**What actually happens (revised — see Step 8):**
- `parseAgentMd`/`buildPersonaSystem` are ported into `channels` (no `@oneie/sdk` dep — channels stays standalone)
- `channels` resolves a per-slug agent from `${slug}/agents/${id}.md` in `CONTENT` R2 at request time (KV-cached)
- **`personas.ts` is KEPT** as the typed worker-default fallback. The lookup is: per-slug `.md` (R2) → `personas[BOT_PERSONA]` → `personas.one`
- Why not delete it: `one` (the web default) and `concierge` have **no `.md`** — deleting personas.ts would lose the default agent. Unify the *lookup*, keep the *fallback*.

The elegance is one resolution path with a safe floor, not zero embedded content at the cost of a broken default.

---

## What Not To Do

- **Don't keep two LLM runtimes.** Every tool added to `chat.ts` is tech debt — it should go in `channels`.
- **Don't make `channels` know about Astro or React.** It emits JSON. The browser renders it.
- **Don't put CRO decisions in the agent loop.** Variant selection and idle-nudge are request-level concerns — handle them in web middleware before the proxy call.
- **Don't lose `BOT_PERSONA`.** Dedicated bot deployments (one workspace, one Telegram bot) still work — `WORKSPACE_SLUG` + `BOT_PERSONA` env vars override per-request resolution.

---

## After

```
channels/            ← one runtime, all surfaces, ~900 lines (was agents/)
  src/ingress.ts     ← was channels.ts
  src/tools/         ← substrate + web + workspace, layered by channel
  src/context.ts     ← slug → soul → identity → system prompt
  wrangler.toml      ← name = "channels", CONTENT R2 bound
one.ie/web/          ← UI shell + auth proxy, zero LLM code
  src/pages/api/chat.ts  ← 20-line proxy to channels /message
packages/sdk/        ← readWorkspaceSoul — one soul function
one.ie/agents/       ← agent definitions — data, not code, loaded by channels at runtime
```

1,719 lines of parallel runtimes → ~900 lines of one. 602 lines of dead adapters gone. Same capability. Half the surface area.

**Longer term:** per-slug agents load from `.md` in `CONTENT` R2 (KV-cached); `personas.ts` stays as the typed worker-default fallback. "Agent definitions are data, not code" becomes true for workspace agents, with a safe floor for the defaults.
