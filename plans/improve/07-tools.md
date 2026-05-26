# 07-tools — gap analysis

## Promise

`text/07-tools.md` sells:

- **250+ integrations** via "the connector layer" (white-labelled Composio — name never surfaced)
- **Per-client OAuth isolation** via `user_id` = wallet address; one server-side API key, N user-scoped grants
- **White-label consent screen** ("Acme Agency wants to access your Gmail" — not ONE, not Composio)
- **Approval-gated writes** with one-click `claim` button in chat
- **Substrate learning per client** — every tool call deposits pheromone, routing improves over 50 calls
- **MCP second surface** — `MCP_SERVERS=slack=...` env adds tools at runtime; claw also publishes substrate as MCP at `/mcp`
- **Skill-first, Composio fallback** — nanoclaw.dev skills run as substrate citizens; Composio fills the gap
- **Live integration list (table)**: Gmail, Slack, GitHub, HubSpot, Linear, Notion, Google Calendar, Google Drive, Stripe, Salesforce — each with Read / Write / Webhook columns
- **`httpRequest` escape hatch** for non-catalog APIs, allowlist-gated
- **Day in life**: Gmail webhook → draft → Slack claim button → send (one click, learning per dental-practice lead)
- **Per-client rate caps**, **graceful degradation** when connector is down, **pinning to connector-layer version**

## Code reality

### Composio wiring (claw)

- `claw/src/composio.ts` — `makeComposio()` + `composioFallback(apiKey, userId, coveredToolkits)` — works, returns `{}` on any error (good rule-1 hygiene, but swallows the error silently — no `warn`)
- `claw/src/composio-toolkits.ts` — `AUTH_CONFIGS` map with **6 entries hardcoded** (GMAIL, GITHUB, SLACK, GOOGLECALENDAR, HUBSPOT, TELEGRAM). One value (`GITHUB: 'CCBf4ES6M5wr'`) is missing the `ac_` prefix — looks like a bug. `SKILL_TOOLKIT_MAP` has 6 entries (gmail, slack, github, linear, google-calendar, discord)
- `claw/src/skill-tools.ts` — `loadSkillTools(env, userId)` lists KV under `${userId}/skills/`, wraps each as `tool()` with a **stub execute that just echoes input** (`{ result: '[skillName] processed: input' }`). **The skill never runs.** Pure stub.
- `claw/src/agents/builder.ts` — three-layer merge `substrate + skillTools + fallbackTools` is wired correctly into `makeAgent()`; only runs when `userId && env.COMPOSIO_API_KEY` present

### Approval gates

- Only 3 substrate tools gated: `remember`, `mark`, `warn` in `claw/src/aitools.ts`
- **Zero approval gates on any Composio tool** — `composioFallback` returns Composio's bare `session.tools()` map. The "approval gate on writes" promised in §"Tool authorisation" doesn't exist for external tools.
- UI side is ready: `web/src/components/chat/ToolApprovalPart.tsx`, `MessageList.tsx` handles `approval-requested` state, `PreviewCard.tsx` has approve/deny — the protocol is there, no producer hooks it for external tools

### Web connect flow (two parallel implementations)

- `web/src/pages/api/composio/connect.ts` — real Composio link via `composio.authConfigs.list()` (dynamic lookup, no hardcoded IDs — good), uses `locals.slug` as userId, returns `redirectUrl`
- `web/src/pages/api/composio/callback.ts` — handles success/error, redirects to `/settings?connected=...`
- `web/src/pages/api/composio/redirect.ts` — proxies through `one.ie` to Composio backend (white-label URL chain works)
- **Parallel stale stack**: `web/src/pages/api/tools/index.ts` + `tools/[provider]/connect.ts` still ships with `redirectUrl: '#stub'`, hardcoded `AVAILABLE_PROVIDERS = ['slack','stripe','github','shopify']`, and explicit TODO comments saying "replace with ComposioAdapter once Composio SDK is installed". The SDK *is* installed. This stub serves `ToolsView.tsx` on `/tools`.

### Tool picker UIs (also two parallel)

- `web/src/components/tools/ToolsView.tsx` — hits the stub `/api/tools` endpoint; shows 4 providers + 5 platform tools (`crawl` active, `image` active, `search`/`email`/`memory` roadmap)
- `web/src/components/settings/IntegrationsPanel.tsx` — emoji-decorated card grid for 6 vendors (hubspot, salesforce, ghl, klaviyo, stripe, shopify) → fires `signal('integration:<v>:connect')` (not OAuth, internal adapter flow); reads/writes `/api/settings?scope=integrations`
- **Neither UI calls `/api/composio/connect`.** The working Composio endpoint is orphaned — no entry point from any page.

### MCP

- `mcp/src/tools/substrate.ts` — 13 universal verbs (signal, ask, mark, warn, fade, follow, select, recall, reveal, forget, frontier, know, highways). Solid.
- `mcp/src/tools/{lifecycle,observability,discovery}.ts` — exist; not inspected in depth
- **MCP **inbound** (claw consumes external MCP servers)**: `claw/src/mcp.ts` does not exist. `MCP_SERVERS=` env var not parsed anywhere. The "wiring an MCP server is a config change" promise is not implemented.
- claw exposing itself as MCP at `/mcp`: no `/mcp` route in `claw/src/index.ts`

### Agent frontmatter

- `agents/README.md` documents the contract (`tools: [crawl, image]` / `tools: []` / omit = all). Real agent files (`import-hubspot.md`, etc.) use `subscribes:` / `emits:` only — no `tools:` field anywhere in actual agents/*.md. The contract is not exercised; no enforcement in builder.ts (which gives every agent all merged tools regardless of frontmatter).

### Adapters (parallel system)

`claw/src/adapters/{ghl,hubspot,klaviyo,salesforce,shopify,stripe}.ts` exist — direct API integrations, not via Composio. This is what `IntegrationsPanel` actually triggers. A third tool stack alongside Composio + nanoclaw skills.

## Gaps

| # | Promise | Reality | Severity |
|---|---|---|---|
| 1 | Skill-first routing (substrate citizens) | `loadSkillTools` returns stubs that echo input — skill *never executes* | **critical** |
| 2 | "Approval-gated writes" on external tools | Composio tools pass through with no `needsApproval` wrapper; only 3 substrate tools gated | **critical** |
| 3 | 250+ integrations | 6 `AUTH_CONFIGS` hardcoded; lookup is dynamic from dashboard so could be more — but `SKILL_TOOLKIT_MAP` dedup only knows 6 | high |
| 4 | One connect flow | Three: (a) working `/api/composio/*`, (b) stub `/api/tools/[provider]/*` returning `#stub`, (c) direct adapters via `IntegrationsPanel` → `/api/signal/integration:*:connect`. Neither UI uses (a). | **critical** |
| 5 | Per-agent tool gating via frontmatter | `tools:` field documented, not parsed, not enforced — every agent sees the full merged toolbox | high |
| 6 | MCP as second tool surface (claw consumes) | No `claw/src/mcp.ts`, no `MCP_SERVERS` env parsing, no `createMCPClient` call | high |
| 7 | claw exposes substrate as MCP at `/mcp` | No `/mcp` route in `claw/src/index.ts` | medium |
| 8 | Pheromone on every tool call | `composioFallback` swallows errors silently (no `warn`), success path doesn't `mark`. The Rule 1 closed-loop promise in spec §"Substrate contract" is not wired for external tools | high |
| 9 | `httpRequest` escape hatch | Not present in `aitools.ts` | medium |
| 10 | Per-client rate cap | No code path | medium |
| 11 | `IntegrationsPanel` brand surface | Uses emoji glyphs (🟠 ☁ 🚀 📧 💳 🛍) — violates `.claude/rules/design.md` (lucide-only, no unicode glyphs) | low |
| 12 | `GITHUB` auth config ID missing `ac_` prefix | `CCBf4ES6M5wr` vs format `ac_…` — likely typo, will 404 on Composio side | **critical** (single-line fix) |
| 13 | `composio.md` claims `Don't expose COMPOSIO_API_KEY to browser` | Honoured (worker-side only). Good. | n/a |
| 14 | Web doc copy says "ONE" white-label, agency-copy says "Acme Agency" white-label | The `text/` copy is for **agencies**; the actual consent screen brand text isn't configured anywhere in code — depends entirely on per-agency Composio dashboard setup. No agency-onboarding flow to set this. | medium |
| 15 | Webhook reactivity ("new HubSpot deal triggers agent without polling") | No Composio webhook consumer route under `web/src/pages/api/composio/` | medium |
| 16 | `connector layer is degraded → dashboard shows it` | No connector-layer health check anywhere | low |

## Recommended improvements

**P0 — fix what's broken or contradictory:**

1. Fix the `GITHUB` auth config ID (`composio-toolkits.ts:3` — add `ac_` prefix or confirm the right ID from dashboard)
2. Replace `loadSkillTools` stub `execute` with real skill execution — fetch skill content from KV, run via the same dispatcher web uses (`web/src/lib/skill/` if it exists; otherwise wire to claw's `skill-tools` path the spec describes)
3. Wrap Composio tools in `composioFallback` with `needsApproval: true` for write-class actions. Composio toolkit metadata exposes `mutation` / mutation_type; map that to the gate. At minimum: gate any tool whose name contains `send|create|delete|update|merge`.
4. Delete the stub `/api/tools/[provider]/connect.ts` + `disconnect.ts` + `index.ts`, OR rewrite them to delegate to `/api/composio/connect`. The orphan stub is what `/tools` page actually calls.
5. Wire `ToolsView.tsx` to the real composio endpoint (`POST /api/composio/connect` with `{ toolkit }`) and list active connections from `composio.connectedAccounts.list({ userIds: [userId] })`.

**P1 — close the loop:**

6. Add `mark`/`warn` wrapper around every external tool execute (per `composio.md` §"Substrate contract"). One shim in `composioFallback`.
7. Honour `tools:` frontmatter in `builder.ts` — filter merged tool map by persona's allowed list before passing to `ToolLoopAgent`.
8. Implement `claw/src/mcp.ts` + `MCP_SERVERS` env parsing — claw consumes external MCP servers. Add `claw/src/index.ts` route for `/mcp` to expose substrate.
9. Add `httpRequest` tool with per-deployment allowlist to `aitools.ts`.

**P2 — consolidate:**

10. Pick one connect flow. Recommend: kill `adapters/*.ts` for any service Composio covers; keep them only for non-OAuth integrations (Shopify Admin API, Stripe Connect). Make `IntegrationsPanel` and `ToolsView` the same component.
11. Replace emoji glyphs in `IntegrationsPanel` with `IconBadge` + lucide icons.
12. Add webhook consumer at `/api/composio/webhook` to fulfil the reactivity promise.
13. Add per-agency auth-config setup UI so the white-label consent screen brand is provisioned, not assumed.

**Brand constraint** (do not surface "Composio" name):

- `web/src/pages/api/tools/[provider]/connect.ts:20-28` — TODO comments mention "Composio SDK" and "ComposioAdapter". Remove or rename to "connector layer adapter".
- `web/src/pages/api/composio/*` — the URL path leaks the vendor name. Rename to `/api/connect/*` and `/api/connect/callback` per `composio.md` §"Composio's own consent surface" recommendation.
- `claw/src/composio*.ts` — internal, fine to keep. But error messages / log lines using `[composio]` shouldn't surface to user-facing telemetry.
- `IntegrationsPanel.tsx` text is clean (no vendor name). `ToolsView.tsx` clean.
- `text/07-tools.md` itself is **clean** — uses "connector layer" throughout. Good.

## Files to touch

| File | Change |
|---|---|
| `claw/src/composio-toolkits.ts` | Fix `GITHUB` auth config ID; expand `SKILL_TOOLKIT_MAP` |
| `claw/src/skill-tools.ts` | Replace stub execute with real skill dispatcher |
| `claw/src/composio.ts` | Add mark/warn shim + approval gate wrapper on write-class tools |
| `claw/src/agents/builder.ts` | Honour persona `tools:` frontmatter filter |
| `claw/src/mcp.ts` | **New** — MCP client loader (`MCP_SERVERS` env) |
| `claw/src/index.ts` | **New route** — expose substrate at `/mcp` |
| `claw/src/aitools.ts` | Add `httpRequest` tool with allowlist |
| `web/src/pages/api/tools/index.ts` | Delete stub, or proxy to composio endpoint |
| `web/src/pages/api/tools/[provider]/connect.ts` | Delete stub |
| `web/src/pages/api/tools/[provider]/disconnect.ts` | Delete stub |
| `web/src/pages/api/composio/` | Rename directory to `/api/connect/` (brand leak) |
| `web/src/pages/api/connect/webhook.ts` | **New** — Composio webhook consumer for reactivity |
| `web/src/components/tools/ToolsView.tsx` | Wire to real connect endpoint; list `connectedAccounts` |
| `web/src/components/settings/IntegrationsPanel.tsx` | Drop emoji glyphs (use IconBadge), unify with ToolsView |
| `agents/*.md` | Add `tools:` frontmatter to existing agents where scope should be narrowed |
