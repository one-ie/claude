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
├── channels.ts       ← Telegram + Discord normalize/send
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

Four steps. Each is independently shippable.

### Step 1 — `packages/sdk/src/soul.ts`
Extract the soul function. Nothing breaks. Both workers still use their own copy until Step 2/3 land.

### Step 2 — Make `channels` multi-tenant
Change `loadContext` to accept `slug` from the request body. Fall back to `WORKSPACE_SLUG` env for dedicated bot deployments. Add `CONTENT` R2 binding to `wrangler.toml`.

### Step 3 — Move web tools into `channels`
Copy `chat.ts` tool definitions into `channels/src/tools/web.ts` and `tools/workspace.ts`. Wire them into `makeAgent` behind the `channel = 'web'` guard. Delete the tool definitions from `chat.ts`.

### Step 4 — Replace `chat.ts` with a proxy
Once Step 3 is verified, replace `chat.ts` with the 20-line proxy. Add `CHANNELS_URL` env var to `one.ie/web/wrangler.toml`.

**Data note:** `channels:${group}` substrate prefix replaces `claw:${group}`. Check D1 + TypeDB for existing rows before deploying Step 2.

---

## What Not To Do

- **Don't keep two LLM runtimes.** Every tool added to `chat.ts` is tech debt — it should go in `channels`.
- **Don't make `channels` know about Astro or React.** It emits JSON. The browser renders it.
- **Don't put CRO decisions in the agent loop.** Variant selection and idle-nudge are request-level concerns — handle them in web middleware before the proxy call.
- **Don't lose `BOT_PERSONA`.** Dedicated bot deployments (one workspace, one Telegram bot) still work — `WORKSPACE_SLUG` + `BOT_PERSONA` env vars override per-request resolution.

---

## After

```
channels/        ← one runtime, all surfaces, ~900 lines
one.ie/web/      ← UI shell + auth proxy, zero LLM code
packages/sdk/    ← readWorkspaceSoul — one soul function
one.ie/agents/   ← agent definitions — data, not code
```

1,719 lines of parallel runtimes → 900 lines of one. Same capability. Half the surface area.
