# agent-features-todo.md — wave-parallel TODO

Source: `agent-features.md` · `agent-authoring.md` · `agent-template.md`

**Mode:** mixed · **Lifecycle:** construction · **Closure scalar:**
all 19 planned gaps green; `oneie agent dev` HMR cycle < 200ms; new
section kinds (`cta`, `embed`, `code`, `timeline`, `hotel`) render on
`/studio/<agent>` without script errors; rollback restores byte-identical
content; per-key auth rejects revoked tokens with 401.

---

## Audiences (who this feature set serves)

| Audience | Role | Surface |
|---|---|---|
| **Partner authors** — write `.md` agents | Author, validate, preview, publish, version | CLI `oneie agent *`, `/studio/<id>` dev banner, SDK methods |
| **Workspace owners** — host published agents | List, audit, roll back, gate | `/u/<slug>/agents`, history endpoint, billing burn |
| **End users** — chat with agents | Visit `/studio/<id>`, complete journeys, iframe embeds | `/studio`, `/chat?agent=<id>` |
| **Platform** — security, rate-limit | Per-key auth, publish rate-limit, audit signals | `/api/agents/*`, middleware |

---

## How to run with `/do`

- `/do agent-features-todo.md --wave 0` — fan out **8 agents in one message** (Wave-0 schema + Zod + types, no deps)
- `/do agent-features-todo.md --wave N` — drive a wave end-to-end
- `/do agent-features-todo.md --item S1` — single item, own W1→W4 sandwich
- Each item closes with `/close --item <id>`; cycle closes with `/close --todo agent-features --cycle 1`

---

## Dependency graph

```
WAVE 0 (no deps — 8 parallel agents)
┌────────────────────────────────────────────────────────────────────┐
│ S1 S2 S3 S4 S5      H1     T1     R1                               │
│ schema: cta embed   hotel  types  rate-limit infra                 │
│ code timeline       kind   surface (KV + middleware extension)     │
└──────┬───────┬──────┬──────┬───────┬───────────────────────────────┘
       │       │      │      │       │
       ▼       ▼      ▼      ▼       ▼
WAVE 1 (5 parallel — renderers + auth model)
┌────────────────────────────────────────────────────────────────────┐
│ R2 R3 R4 R5 R6      K1                                             │
│ SectionRenderer     per-key auth (table + middleware)              │
│ branches for new    + revoke endpoint                              │
│ kinds + hotel       (replaces shared SERVER_SECRET for partners)   │
└──────────┬──────────┬──────────────────────────────────────────────┘
           │          │
           ▼          ▼
WAVE 2 (8 parallel — publish surface evolution)
┌────────────────────────────────────────────────────────────────────┐
│ V1 V2 V3        D1 D2     L1 L2     A1                             │
│ versioned R2    design    list api  audit signal                   │
│ + history +     polish    + cli +   to substrate                   │
│ rollback        gaps      sdk + mcp                                │
└──────────┬───────────┬───────────┬───────────┬─────────────────────┘
           │           │           │           │
           ▼           ▼           ▼           ▼
WAVE 3 (5 parallel — CLI commands + DX)
┌────────────────────────────────────────────────────────────────────┐
│ C1 C2 C3 C4 C5                                                     │
│ agent dev · agent list · agent history · agent rollback · diff v2  │
└──────────┬─────────────────────────────────────────────────────────┘
           │
           ▼
WAVE 4 (3 parallel — eval + docs + verify)
┌────────────────────────────────────────────────────────────────────┐
│ E1            DOC1                  VER1                           │
│ agent eval    update authoring +    end-to-end:                    │
│ wires to      template + features   publish→rollback→pull          │
│ /api/chat     md                    cycle byte-identical           │
└────────────────────────────────────────────────────────────────────┘
```

**Real same-file constraints** (don't claim two on one file):

```
web/src/lib/agent-md.ts                 → T1 owns (S1-S5 add types via patch)
web/src/lib/agent-schema.ts             → S1 owns (S2-S5 add discriminator branches)
web/src/components/journey/SectionRenderer.astro → R2 owns (R3-R6 add branches)
web/src/pages/studio/[agent].astro      → D1 owns (D2 folds in)
web/src/pages/api/agents/publish.ts     → V1 owns (V2,V3,R1,A1 fold in)
web/src/pages/api/agents/{list,history,rollback}.ts → NEW each, no contention
cli/src/agent.ts                        → C1 owns; C2-C5 add subcommands in same file
                                           — sequence within ONE agent
sdk/src/client.ts                       → L2 + V2 fold in (sequence)
mcp/src/tools/lifecycle.ts              → L2 folds in
```

---

## Already shipped ✓ (don't rework)

- [x] **parser-zod** — `parseAgentMd` + `validateAgentFrontmatter` with two-tier issues
- [x] **section-5** — `stat`, `card`, `grid` (incl. affiliate), `list`, `compare`
- [x] **publish-trio** — POST/GET/DELETE `/api/agents/publish` with Bearer auth
- [x] **cli-publish-pull-unpublish** — owner-scoped via `<slug>:<token>`
- [x] **sdk-publish-pull-unpublish** — `client.{publishAgent, pullAgent, unpublishAgent}`
- [x] **mcp-publish-pull-unpublish** — three tools in `lifecycle.ts`
- [x] **studio-banner** — dev-only validation banner on `/studio/<id>`
- [x] **chip-dedup** — auto-derived whitelist replaces existing block
- [x] **stop-label** — `ui.labels.stop` flips during streaming
- [x] **theme + ui customisation** — 6 tokens + all UI knobs in agent-features.md

---

## Wave 0 — 8 parallel agents (no deps)

### Schema additions (haiku × 5, sonnet × 1)

- [x] **S1** `web/src/lib/agent-schema.ts` — add `cta` to discriminated union: `{ kind: 'cta', id, title, subtitle?, primary: { label, ask? | href? }, secondary?: {...}, icon? }` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **S2** `web/src/lib/agent-schema.ts` — add `embed`: `{ kind: 'embed', id, title?, provider: 'youtube'|'vimeo'|'iframe', src (url), aspect?: '16:9'|'4:3'|'1:1' }` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **S3** `web/src/lib/agent-schema.ts` — add `code`: `{ kind: 'code', id, title?, lang, content, copyable?: boolean }` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **S4** `web/src/lib/agent-schema.ts` — add `timeline`: `{ kind: 'timeline', id, title?, items: [{ time?, label, description?, tone? }] }` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **S5** `web/src/lib/agent-schema.ts` — add `hotel`: `{ kind: 'hotel', id, title?, subtitle?, items: [{ name, img?, location?, rating?, reviewCount?, starRating?, price?, currency?, href }] }`. Required `href` separates this from `grid`. · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Types (haiku × 1)

- [x] **T1** `web/src/lib/agent-md.ts` — extend `SectionData` union with `SectionCta`, `SectionEmbed`, `SectionCode`, `SectionTimeline`, `SectionHotel` interfaces matching S1-S5 · `haiku` · w1[x] w2[x] w3[x] w4[x]

### Operational infrastructure (sonnet × 1, haiku × 1)

- [x] **H1** `web/src/lib/agent-md.ts` — `UiHero` accepts `false` (literal) or object; parser preserves the boolean so renderer can opt out · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **R1** `web/src/pages/api/agents/publish.ts` — rate-limit middleware via KV `publish-rl:{slug}` 10 req/min, 429 above. Shared helper reusable by list/history/rollback. · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 1 — 6 parallel agents (deps: Wave 0)

### Section renderers (sonnet × 4, haiku × 1)

- [x] **R2** `web/src/components/journey/SectionRenderer.astro` extend — `cta` branch: card with primary CTA (data-ask or external href), optional secondary, icon via Lucide · deps: S1, T1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **R3** `SectionRenderer.astro` extend — `embed` branch: `<iframe loading=lazy referrerpolicy=no-referrer>` for YouTube/Vimeo; sandbox for generic iframe; aspect-ratio wrapper · deps: S2, T1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **R4** `SectionRenderer.astro` extend — `code` branch: Shiki build-time highlight (light + dark themes), copy-to-clipboard button with event-delegation script · deps: S3, T1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **R5** `SectionRenderer.astro` extend — `timeline` branch: vertical flex with connectors, tone-colored markers, optional time chips · deps: S4, T1 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **R6** `SectionRenderer.astro` extend — `hotel` branch: like current grid affiliate mode but cleaner (no fallback paths); promote price + rating + stars to first-class layout · deps: S5, T1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Per-key auth (sonnet × 1)

- [x] **K1** `migrations/0022_api_keys.sql` + `web/src/lib/api-keys.ts` + extend `web/src/pages/api/agents/publish.ts` checkAuth — table `api_keys(slug, key_hash, label, created_at, revoked_at)`; auth resolves `<slug>:<token>` against `key_hash` for that slug; legacy SERVER_SECRET path kept for CI; new endpoint `/api/keys` (POST create, DELETE revoke). · deps: none external · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 2 — 6 parallel agents (deps: K1, R1)

### Versioning + history (sonnet × 3)

- [x] **V1** `web/src/pages/api/agents/publish.ts` extend POST — on every publish: write live key `{slug}/agents/{name}.md` AND archive key `{slug}/agents/{name}/v{epochMs}.md`. Latest 20 versions kept; older purged. · deps: R1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **V2** `web/src/pages/api/agents/history.ts` — `GET /api/agents/history?slug=&name=` returns `[{ts, bytes, key}]` sorted newest-first; auth via K1 · deps: V1, K1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **V3** `web/src/pages/api/agents/rollback.ts` — `POST /api/agents/rollback {slug, name, ts}` reads archived version, validates schema, writes back to live key, emits KV audit event · deps: V1, V2, A1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Design polish (sonnet × 1, haiku × 1)

- [x] **D1** `web/src/pages/studio/[agent].astro` — hero opt-out (`ui.hero === false` skips section); banner tertiary for warn-only, destructive for errors; source badge deferred to post-V1 pass · deps: H1, V1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **D2** `web/src/pages/studio/[agent].astro` — skip `time:` row when missing (folded into D1) · `haiku` · w1[x] w2[x] w3[x] w4[x]

### List API (sonnet × 1)

- [x] **L1** `web/src/pages/api/agents/list.ts` — `GET /api/agents/list?slug=` returns `[{name, bytes, key, versionCount}]`; uses R2 `list({prefix: '{slug}/agents/'})` + version count from archive prefix · deps: K1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Audit signal (haiku × 1)

- [x] **A1** `web/src/pages/api/agents/publish.ts` + `web/src/pages/api/agents/rollback.ts` — fire-and-forget KV audit event after R2 write (key: `event:agent:published|rolled-back:{ts}:{slug}:{name}`); substrate signal deferred (no TypeDB binding in CF Workers) · deps: V1 · `haiku` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 3 — 5 parallel agents (deps: V1-V3, L1, K1)

### CLI command additions (sonnet × 4, opus × 1)

- [x] **C1** `cli/src/agent.ts` — `oneie agent dev <path>` watches file, re-validates on every change via issues_from_quick(); no HTTP server (deferred) · deps: V1 · `opus` · w1[x] w2[x] w3[x] w4[x]
- [x] **C2** `cli/src/agent.ts` — `oneie agent list --slug <ws>` calls L1, renders JSON/table · deps: L1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **C3** `cli/src/agent.ts` — `oneie agent history <name> --slug <ws>` calls V2, renders table · deps: V2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **C4** `cli/src/agent.ts` — `oneie agent rollback <name> --to <ts> --slug <ws>` calls V3 with confirm prompt unless `--yes` · deps: V3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **C5** `cli/src/agent.ts` — `oneie agent diff <a> <b>` v2: key-level deltas in `uiKeys[]` + `themeKeys[]`; SemanticDelta extended; same output shape · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]

> C1-C5 land in same file; sequence within ONE agent OR serialize C2→C5 after C1 ships.

### SDK + MCP follow-ons (sonnet × 1 — folds with L1/V2/V3)

- [x] **L2** `sdk/src/client.ts` + `mcp/src/tools/lifecycle.ts` — added `agentHistory` + `rollbackAgent` to SDK (listAgents already existed); added `list_agents`, `agent_history`, `rollback_agent` to MCP lifecycle tools · deps: L1, V2, V3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 4 — 3 parallel agents (deps: V3, R2-R6)

### Eval real (sonnet × 1)

- [x] **E1** `cli/src/agent.ts` — `oneie agent eval <path>` wires to web's `/api/chat` eval tool via POST; reports passed/failed/total; supports `--api-key` and `--slug` · deps: none external · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Docs (haiku × 1)

- [x] **DOC1** `web/agent-authoring.md` + `web/agent-template.md` — document the 5 new section kinds with author examples; document per-key auth model; document versioning + rollback CLI flow; update roadmap table to remove items in this todo · `haiku` · w1[x] w2[x] w3[x] w4[x]

### End-to-end verification (sonnet × 1)

- [x] **VER1** `web/tests/agent-roundtrip.test.ts` (NEW) — integration test: publish v1 → publish v2 → pull → assert content matches v2 → history → rollback to v1 → pull → assert content matches v1 byte-identical; rate-limit test (11th request in 60s → 429); revoked key test (publish with revoked token → 401) · deps: V1-V3, K1, R1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

---

## Wave 4.5 — 6 parallel agents (Phase 1.5: skills + tools integrity)

Deps: Wave 0 schemas. Closes 6 real-flow gaps surfaced by hands-on
testing of the skill execution loop on dev.

### Tools allowlist + skill discovery (sonnet × 3)

- [x] **TI1** `web/src/pages/api/chat.ts` — enforce `agent.tools` allowlist: filter the assembled `tools` object so only allowed tool names reach `streamText`. Convention: `tools: []` → no tools, `tools: [a,b]` → only those, absent → all (current behaviour). Update agent-authoring.md to match. · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TI2** `web/src/pages/api/chat.ts` — when an owner agent is loaded, append `\n\nAvailable skills:\n- voice-of-brand — Rewrite copy in the brand voice\n- ...` to the system prompt. Source: resolved skills on `AgentEntry`. Skills with `price > 0` get `($N)` suffix. · deps: TI1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TI3** `web/src/pages/api/chat.ts` — when `skill` tool returns `kind: 'skill-content'`, automatically continue the streamText loop with the skill body as additional system context for the same turn (use AI SDK's `stopWhen` + continuation pattern). Prevents `finishReason: 'tool-calls'` dead ends. · deps: TI2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Skill round-trip endpoints (sonnet × 2)

- [x] **TI4** `web/src/pages/api/skills/workspace.ts` — `GET /api/skills/workspace?slug=` returns `[{name, bytes, key, lastImportedAt}]`; lists R2 `{slug}/skills/*`, filters to live SKILL.md (excludes _remote/); same auth model as `/api/agents/publish` · deps: K1 (Phase 1 W1) · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TI5** `web/src/pages/api/skill/[name].ts` — `DELETE /api/skill/<name>?slug=` removes `{slug}/skills/<name>/SKILL.md`; idempotent like agent unpublish · deps: A1 (Phase 1 W2 audit signal) · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### External tools via Composio (opus × 1)

- [x] **TI6** `web/src/lib/composio.ts` (NEW, port `claw/src/composio.ts`) + `web/src/pages/api/chat.ts` — when `agent.tools` includes a `composio:<toolkit>` ref AND the workspace has an active Composio connection for that toolkit, surface those tools to the LLM alongside platform tools. Auth flow: existing `/api/composio/connect` OAuth already works in the workspace. · deps: TI1, claw's existing implementation · `opus` · w1[x] w2[x] w3[x] w4[x]

### CLI + SDK + MCP follow-ons (haiku × 1)

- [x] **TI7** `cli/src/skill.ts` + `sdk/src/client.ts` + `mcp/src/tools/lifecycle.ts` — add `oneie skill list/unimport`, `client.listSkills/unimportSkill`, MCP `list_skills`/`unimport_skill`. Mirrors the agent round-trip surface. · deps: TI4, TI5 · `haiku` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 4.6 — 16 parallel agents (Phase 1.6: substrate API unification)

Deps: K1 (Wave 1 per-key auth) is the only hard dep — everything else
is greenfield substrate-verb mapping. Goal: every HTTP URL maps 1:1 to
a DSL verb or one of the 6 dimensions. Legacy paths keep working via
forwarding shims with `Deprecation:` headers.

### The 8 write verbs (sonnet × 4, haiku × 4)

- [x] **API1** `web/src/pages/api/signal/[...receiver].ts` (NEW) — `POST /signal/{receiver}` accepting the 5-mode addressing grammar from `dsl.md`. Parses `alice`, `alice:review`, `world:review`, `world:review+P0`, `all:review`, `sub:news:crypto` from the URL. Forwards into existing `world.signal()`. Returns 202 with `{ outcome: 'queued' | 'dissolved', signalId }`. · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **API2** `web/src/pages/api/ask/[...receiver].ts` (NEW) — `POST /ask/{receiver}?timeout=` returns the 4-outcome union `{ outcome: 'result'|'timeout'|'dissolved'|'failure', result?, reason?, latencyMs }`. Always HTTP 200; outcome lives in body. · deps: API1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **API3** `web/src/pages/api/mark/[edge].ts` (NEW) — `POST /mark/{edge}` — writes strength to TypeDB + D1 mirror via substrate lib. Body: `{ strength? }`. · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **API4** `web/src/pages/api/warn/[edge].ts` (NEW) — mirror of API3 but emits resistance. · deps: API3 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **API5** `web/src/pages/api/fade.ts` (NEW) — `POST /fade { rate? }`. SERVER_SECRET gated. Returns `{ ok, rate, paths }`. · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **API6** `web/src/pages/api/sub.ts` (NEW) — `POST /sub { topic, url, secret? }` registers HTTPS webhook; `DELETE /sub?id=&topic=` removes. Stored in CHAT_CACHE KV with 30-day TTL. · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **API7** `web/src/pages/api/follow.ts` (NEW) — `GET /follow?tag=<tag>` returns `{ target, strength }` from substrate `follow()`; `{ target: null, strength: 0 }` when no path. · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **API8** `web/src/pages/api/select.ts` (NEW) — `GET /select?tag=<tag>` returns probabilistic `{ target, strength }` from substrate `select()`. · deps: API7 · `haiku` · w1[x] w2[x] w3[x] w4[x]

### The 6 read dimensions (sonnet × 3, haiku × 3)

- [x] **DIM1** `web/src/pages/api/groups/index.ts` (NEW) — `GET /groups?search=&limit=` paginated list via TypeDB query. · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **DIM2** `web/src/pages/api/actors/index.ts` (NEW) — `GET /actors?type=&search=&limit=` paginated actor list with `actor-type` filter. · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **DIM3** `web/src/pages/api/things/index.ts` (NEW) — `GET /things?type=&search=&limit=` skills, tasks, tokens. · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **DIM4** `web/src/pages/api/paths/index.ts` (NEW) — `GET /paths?from=&to=&min_strength=&limit=` highways + strength/resistance/traversals. Read-only. · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **DIM5** `web/src/pages/api/events/index.ts` (NEW) — `GET /events?receiver=&since=&limit=` signal events from TypeDB. · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **DIM6** `web/src/pages/api/learning/index.ts` (NEW) — `GET /learning?search=&status=&limit=` hypotheses ordered by confidence. · `haiku` · w1[x] w2[x] w3[x] w4[x]

### The plumbing — conventions + spec + shims (sonnet × 3, opus × 1, haiku × 2)

- [x] **PL1** `web/src/lib/problem.ts` (NEW) — RFC 9457 helpers: `problem({type, status, title, detail, traceId, ...})`. Audit every existing handler to use it; ban bare `Response.json({error})` via biome lint rule. · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PL2** `web/src/lib/pagination.ts` (NEW) + `web/src/lib/idempotency.ts` (NEW) — shared `paginate({data, cursor, limit})` returning `{ data, nextCursor, hasMore }`; `withIdempotency(handler)` middleware caches `(key, slug)` in KV for 24h and replays on retry. · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PL3** `web/src/lib/rate-limit.ts` (NEW) + `web/src/lib/trace.ts` (NEW) + `web/src/middleware.ts` extend — `RateLimit-Limit/Remaining/Reset` headers + `Retry-After` on 429; hex `X-Trace-Id` (24 chars) per request in middleware response. · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PL4** `web/public/openapi.yaml` (NEW, hand-written) + CI redocly build — full spec with `x-substrate-verb` and `x-dimension` extensions on every operation. CI step asserts every handler is covered (`grep openapi-coverage.test.ts`). Renders to `/api/reference` HTML. · `opus` · w1[x] w2[x] w3[x] w4[x]
- [x] **PL5** Webhook delivery worker — `web/src/workers/webhook-deliver.ts` (NEW) + wrangler queue config — consumes sub-fanout signals targeting HTTPS-URL actors; POSTs canonical envelope with `Webhook-Id`, `Webhook-Timestamp`, `Webhook-Signature` (HMAC-SHA256 over `id.timestamp.body`). Retry curve 5s/30s/5m/30m/2h/6h/24h; logs `failed_permanent` after 7. `GET /api/webhooks/deliveries` exposes status. · deps: API6 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PL6** `sdk/scripts/generate-types.ts` + sdk build — `openapi-typescript` step generates `sdk/src/generated/types.ts`; CI fails if hand-written `SubstrateClient` methods drift from generated types. · deps: PL4 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **PL7** `web/api-changelog.md` + `/api/changelog` route — entries auto-emitted from OpenAPI diff in CI; deprecation entries include `Sunset:` date · deps: PL4 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **PL8** Legacy shims — every existing `/api/*` handler that maps to a substrate verb gets a forwarder: parses legacy body, builds a substrate signal, forwards to API1-API8, returns legacy response shape. Emit `Deprecation: true` + `Sunset: 2026-11-13` header. Inventory of 58 mappings in agent-api.md § "Mapping the 58 legacy endpoints". · deps: API1-API8, DIM1-DIM6 · `opus` · w1[x] w2[x] w3[x] w4[x]

> **Same-file constraints:** `middleware.ts` is touched by PL3 only here (also touched by EV3 in W7.6 — sequence). `lib/problem.ts` is new — every legacy handler edited by PL1 should be done in one agent invocation that touches many files but each only for the problem-helper swap.

> TI1-TI3 land in `api/chat.ts`; sequence within ONE agent OR serialize.

---

# Phase 2 — UX & DX (Waves 5-7)

After Phase 1 the agent builder is complete for a solo partner. Phase 2
makes it **measurable, persistent, accessible, multi-author**.

## Wave 5 — 9 parallel agents (deps: K1, V1 from Phase 1)

### Conversation persistence (sonnet × 4)

- [x] **PT1** `migrations/0023_threads.sql` + `web/src/lib/threads.ts` — schema `threads(id, slug, agent_id, user_cookie, created_at, last_msg_at)` + `messages(id, thread_id, role, content_json, ts)`; CRUD wrappers; resume by `(slug, agent_id, cookie)` · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PT2** `web/src/pages/api/chat.ts` extend — every turn writes to messages; thread created on first message; reads `?thread=<tid>` to resume · deps: PT1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PT3** `web/src/pages/api/threads/[tid]/share.ts` + `web/src/pages/share/[tid].astro` — read-only thread view; copy button in chat header surfaces the URL · deps: PT1, PT2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PT4** `web/src/pages/api/threads/[tid]/export.ts` — markdown / JSON export via `?format=md|json`; .docx in W7 · deps: PT1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Analytics + measurement (sonnet × 4, haiku × 1)

- [x] **AN1** `migrations/0024_agent_events.sql` + `web/src/lib/agent-events.ts` — schema `agent_events(slug, agent_id, event, payload_json, ts, user_cookie)`; helper `emit({slug, agentId, event, payload})` · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **AN2** `web/src/components/journey/JourneyShell.astro` + `web/src/components/Chat.tsx` extend — emit standard events: `stage-start`, `chip-click`, `chat-message` via `/api/agent-events` POST · deps: AN1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **AN3** `web/src/pages/api/agents/[id]/analytics.ts` + `web/src/pages/api/agent-events.ts` — `GET ?from=&to=` returns counts per event, top chips, funnel conversion rates; POST endpoint for frontend to emit events · deps: AN1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **AN4** `web/src/pages/u/[slug]/agents/[id]/analytics.astro` — dashboard: funnel chart, retention curve, top chips list, top stages · deps: AN3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **AN5** `web/src/lib/agent-schema.ts` + `web/src/lib/ab.ts` (NEW) — `variants: { A: 0.5, B: 0.5 }` declaration; cookie-pinned visit via `getOrAssignVariant()`; `goals: [{ id, name, event }]`; conversion delta computed in AN3 · deps: AN1, AN3 · `haiku` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 6 — 8 parallel agents (deps: Wave 0/1 schemas, Wave 5 PT1)

### Mobile + a11y (sonnet × 3, haiku × 2)

- [x] **MA1** `web/src/lib/agent-schema.ts` — `ui.layout.mobile: { chat: 'sheet'|'inline'|'icon', sections: 'stack'|'tabs' }` declaration added to schema · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **MA2** `web/src/components/MobileChatSheet.tsx` (NEW) — bottom-sheet chat that slides up from the bottom on mobile, swipe-to-dismiss, focus-trap; `ChatWidget.tsx` uses MobileChatSheet below 640px breakpoint · deps: MA1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **MA3** `web/src/hooks/use-keyboard-shortcuts.ts` (NEW) — `1-N` jumps to stage N, `/` focuses chat, `Esc` closes sheet, `g g` jumps to /agents · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **MA4** WCAG audit per new section kind — checklist test asserts each renderer passes contrast (token math), keyboard-nav (tab order), aria-labels; failing kinds fail the wave gate · deps: R2-R6, R7-R10 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **MA5** `web/src/components/ai-elements/attachments.tsx` extend — mobile camera attachment via `<input type=file accept="image/*" capture="environment">`; preview before send · `haiku` · w1[x] w2[x] w3[x] w4[x]

### Output management (sonnet × 3)

- [x] **OUT1** `web/src/components/chat/MessageList.tsx` — copy-as-markdown button on every assistant message; hover-revealed copy icon, `navigator.clipboard.writeText`, 2s copied state, `emitClick('ui:chat:copy')` · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **OUT2** `web/src/pages/api/artifacts/save.ts` — save selected assistant message as `{slug}/artifacts/<id>.md` with metadata; surfaces under `/u/<slug>/artifacts` · deps: PT2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **OUT3** `web/src/layouts/Layout.astro` — `@media print` block: hides nav/sidebar/chat dock/buttons, resets colors to black-on-white, appends hrefs to links, avoids orphaned headings · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 7 — 9 parallel agents (deps: Phase 1 schemas + W5 + W6)

### Forms + multi-step inputs (sonnet × 2, haiku × 1)

- [x] **F1** `web/src/lib/agent-schema.ts` + `web/src/lib/agent-md.ts` — `form` section kind with fields[], submitLabel, seedPromptTemplate (handlebar-style `{{fieldName}}`) · deps: T1 from W0 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **F2** `SectionRenderer.astro` extend — `form` branch renders fields (text/email/tel/textarea/select/checkbox), submit seeds chat via `CustomEvent('chat:seed')` + `window.__chatSeedPending`; Handlebars-style template interpolation · deps: F1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **F3** Three new section kinds: `testimonial` (quote + author + role), `faq` (Q/A `<details>` accordion), `gallery` (image grid with inline lightbox). Schema + renderers + types · deps: T1 from W0 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Templates + scaffolding (sonnet × 3)

- [x] **TPL1** `cli/src/agent.ts` — `oneie agent templates` lists templates from `cli/src/templates.ts`; `oneie agent fork <template> <local-name>` clones + swaps `name:` + ids · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TPL2** `cli/src/agent.ts` — `oneie agent ai-edit <path> --prompt "<instruction>" [--model <model>] [--yes]` calls Anthropic API directly (fetch, no sdk dep); shows line-level diff preview by default, `--yes` writes immediately · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TPL3** `agents/templates/` + `cli/src/templates.ts` — 5 starter templates: travel-planner, marketing-strategist, support-tier1, sales-discovery, code-reviewer; complete .md files + registered in CLI `oneie agent templates` / `fork` · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Tooling + ecosystem (opus × 1, sonnet × 2)

- [x] **TOOL1** `tools/vscode-extension/` (NEW) — schema-aware JSON/YAML completion, inline diagnostics from Zod, hover docs, preview button that launches `oneie agent dev` · deps: C1 from W3 · `opus` · w1[x] w2[x] w3[x] w4[x]
- [x] **TOOL2** `.github/actions/agent-publish/action.yml` (NEW) — composite action: validate on PR (`oneie agent validate`), lint, dry-run publish; on merge to main, real publish with workspace secret · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TOOL3** `web/src/pages/api/agents/sync-from-git.ts` — webhook receiver for git push events; pulls listed agent files from the repo and re-publishes via the same publish path; uses Github App for auth · deps: V1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Composition (sonnet × 2)

- [x] **COMP1** `web/src/lib/agent-schema.ts` — `subAgents: [{ id, slug, description, tools? }]` declaration in frontmatter · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **COMP2** `web/src/pages/api/chat.ts` + `web/src/components/chat/MessageRenderer.tsx` — `delegate_to` tool routes turn through sub-agent's chat endpoint; returns `{ kind: 'delegation', agent_id, task, result }`; delegation + delegation-error card kinds added to `cards.ts` and rendered inline · deps: COMP1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 7.5 — 16 parallel agents (Phase 2.5: lifecycle funnel + CRO)

Deps: Wave 5 (events infra), Wave 6 (mobile chat sheet), Wave 7 (forms).
Builds the full funnel subsystem from `agent-lifecycle.md`. Goal: every
agent has a declared funnel with goals, KPIs computed daily, and ≥ 3 CRO
techniques opt-in via YAML.

### Schema + types (haiku × 1, sonnet × 1)

- [x] **FN1** `web/src/lib/agent-schema.ts` + `web/src/lib/agent-md.ts` — add `funnel:` block: `goals[]`, `stages[]`, `kpis[]`, `optimization{}`, `visitorTypes[]`, `a2a{}`. Discriminated where helpful (eventMatch vs eventMatch by field). · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **FN2** `web/src/lib/funnel.ts` (NEW) — goal resolution engine: takes an event row, evaluates each agent's goals against `successSignal`/`partialSignal`/`dropSignal`, returns `{ goalId, satisfied, partial, dropped }`. Pure function — testable. · deps: FN1, AN1 (W5) · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### KPI compute + storage (sonnet × 3)

- [x] **FN3** `migrations/00XX_funnel_aggregates.sql` — covered by DB2 (`0025_funnel_hourly.sql`) + DB3 (`0026_funnel_daily.sql`) incl. `funnel_agg_cursor` seed rows · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **FN4** `web/src/workers/funnel-aggregate-cron.ts` (NEW) + wrangler cron — hourly: roll `agent_events` rows into `funnel_daily`; mark processed via row pointer · deps: FN3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **FN5** `web/src/pages/api/funnel/[id]/kpis.ts` (NEW) — `GET ?from=&to=` returns the 9 KPIs (SCR, drop-off, TTC, chip CTR, artifact rate, return rate 7d, variant lift, CV, path strength). Reads pre-aggregated rows for speed; falls back to live compute for current day. Cache 1m. · deps: FN3, FN4 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Dashboard (sonnet × 2)

- [x] **FN6** `web/src/pages/u/[slug]/agents/[id]/funnel.astro` (NEW) — funnel chart + KPI cards + optimisation impact cards; replaces AN4's stub with real charts · deps: FN5 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **FN7** `web/src/components/funnel/{FunnelChart,VariantCard,OptimizationCard}.tsx` — 3 small React components used by FN6; FunnelChart is a horizontal stacked bar; OptimizationCard shows fire count + recovery rate per technique · deps: FN6 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### CRO techniques (sonnet × 6, haiku × 1)

- [x] **CRO1** `web/src/lib/cro/idle.ts` (NEW) + `api/chat.ts` extend — idle re-engagement: detect silence on the SSE stream; after `N` seconds, emit assistant turn with `metadata.kind = 'idle-nudge'`; cap at `maxFires`; track `idle-nudge-fired` event · deps: FN1, PT2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **CRO2** `web/src/lib/cro/abandonment.ts` (NEW) + `Chat.tsx` extend — read prior-thread cookie, surface banner if `(now - lastVisit) < windowDays`; click resumes via PT2 / "Start fresh" archives + creates new · deps: PT1, PT2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **CRO3** `web/src/lib/cro/social-proof.ts` (NEW) + intro component — show "N users completed this week" badge below hero when count ≥ `minCount`; KV cache 1h · deps: FN3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **CRO4** `web/src/lib/cro/disclosure.ts` (NEW) + `JourneyShell.astro` — visually grey-out + disable click on stages listed in `progressiveDisclosure.stages` until the prior stage's goal fires for this visitor; read from `/api/funnel/<id>/visitor-state` · deps: FN5, PT1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **CRO5** `web/src/lib/cro/variable-reward.ts` (NEW) + `api/unlocks/grant.ts` (NEW) — on goal event matching `triggers[].after`, write `{slug}/users/<uid>/unlocked` and emit chat notification card · deps: FN1, FN2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **CRO6** `web/src/lib/cro/friction.ts` (NEW) + `lib/threads.ts` extend — when `preFillFromThread: true`, surface last `agent:summary` payload from prior thread as system context on next chat call · deps: PT1, PT2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **CRO7** `web/src/lib/cro/variants.ts` (NEW) + `agent-loader.ts` + `api/chat.ts` — cookie-pinned variant assignment with `assignment: cookie|uid|random-per-visit`; per-arm prompt override applied at system-prompt assembly; winner pick requires `minSampleSize`; emit `variant-assigned` event · deps: FN1, AN5 from W5 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Personalisation + substrate hook (sonnet × 2)

- [x] **CRO8** `web/src/lib/cro/personalisation.ts` (NEW) + `api/chat.ts` — rule evaluator: each rule has `when` (returning, variant=X, locale=Y, hour-of-day) + override (seedPrompt, quickReplies, sectionsHidden); first match wins · deps: CRO7, PT1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **SUB1** `web/src/lib/funnel.ts` substrate-hook — every resolved funnel event fires `one.signal('agent:<id>:<event>', { stage, goalId, value })` for L1+L2 pheromone marking; goal events with high `value` get higher chainDepth on mark · deps: FN2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### A2A funnel signals (sonnet × 1)

- [x] **A2A1** `web/src/pages/api/agents/discover.ts` + new `api/peer/{call,result}.ts` — emit `peer-discovery-query`, `peer-route-selected`, `peer-call-issued`, `peer-call-result` events with `ok` and `latencyMs`; existing `/api/loop/mark-dims` already handles `pheromone-mark/warn` · deps: AN1, FN1, FN2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

> **Same-file constraints:** `api/chat.ts` touched by CRO1, CRO7, CRO8 — sequence within ONE agent OR serialize. `JourneyShell.astro` touched by CRO4 only. `agent-schema.ts` touched by FN1 only.

---

## Wave 7.6 — 16 parallel agents (Phase 2.6: analytics plumbing)

Deps: Wave 5 (AN1 events table), Wave 7.5 (funnel schema). Builds the
measurement infrastructure under the funnel — D1 schemas, ingestion,
aggregation, attribution, segmentation, statistical guards, exports,
GDPR. Full spec at `agent-analytics.md`.

### Schema + ingestion (haiku × 1, sonnet × 3)

- [x] **EV1** `web/src/lib/event-vocabulary.ts` (NEW) — exported constants: `STANDARD_EVENTS` (Tier 1), `CRO_EVENTS` (Tier 2), `A2A_EVENTS` (Tier 3). Imported by schema + ingestion + dashboards as the single source of event names. · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **EV2** `web/src/lib/agent-events.ts` (NEW) — Zod schemas keyed by event name; ingestion helper `emitEvent({slug, agentId, event, payload})` validates payload against the matching schema; rejects unknown events; sanitises PII fields if any leak through · deps: EV1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **EV3** `web/src/middleware.ts` extend — set `Astro.locals.visitorHash = sha256(cookie + WORKSPACE_SALT)` on every request; create cookie on first visit; never log raw cookie value · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **EV4** `web/src/pages/api/agent-events.ts` (NEW) — single ingestion endpoint; reads visitorHash + Bearer auth (for SDK/MCP); calls `emitEvent` and fires substrate signal in `ctx.waitUntil`; returns 204 immediately · deps: EV2, EV3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### D1 schemas (haiku × 3)

- [x] **DB1** `migrations/00XX_agent_events.sql` — table from agent-analytics.md § Data model with 4 indexes; weekly partition prep (logical table name suffix support) · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **DB2** `migrations/00XX_funnel_hourly.sql` — aggregated rollup table; primary key (slug, agent_id, bucket, event, variant, stage_id, goal_id) · deps: DB1 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **DB3** `migrations/00XX_funnel_daily.sql` — same shape as hourly with day bucket; 90-day retention; aggregation cursor table · deps: DB2 · `haiku` · w1[x] w2[x] w3[x] w4[x]

### Aggregation cron + R2 archive (sonnet × 2)

- [x] **AGG1** `web/src/workers/funnel-aggregate-cron.ts` (NEW) + wrangler.toml hourly cron — read `agent_events` rows since cursor; GROUP BY (hour, event, variant, stage_id, goal_id); UPSERT into `funnel_hourly`; advance cursor; emit `funnel:aggregate:hourly` substrate signal · deps: DB1, DB2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **AGG2** Same file + daily cron @ 02:00 UTC — roll `funnel_hourly` → `funnel_daily`; archive `agent_events` older than 14d to R2 as Parquet (`{slug}/analytics/exports/{agent_id}/YYYY/MM/DD.parquet`); vacuum D1 · deps: DB3, AGG1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### KPI queries + dashboard wiring (sonnet × 2)

- [x] **Q1** `web/src/lib/funnel/queries.ts` (NEW) — 9 SQL query patterns from agent-analytics.md § Query patterns; takes `{slug, agentId, from, to, segment?}` and returns typed results. Caches at request level. · deps: DB2, DB3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **Q2** Update `web/src/pages/api/funnel/[id]/kpis.ts` (created in W7.5 FN5) — FN5 was built directly with `queryAllKpis` + 60s KV cache; no mock data gap · deps: Q1, FN5 from W7.5 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Attribution + segmentation + stats (sonnet × 3)

- [x] **ATTR1** `web/src/lib/funnel/attribution.ts` (NEW) — first/last/linear attribution materialisers; consumes raw events grouped by visitor, emits `attributed_value` rows joining (event, goalId) pairs. Pure functions, table-driven tests. · deps: EV1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **SEG1** `web/src/lib/funnel/segmentation.ts` (NEW) — dimension extraction (variant, locale, device, source, referrer, UTM, returning); given event row → segment label dict; two-dim cap enforced at query time · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **STATS1** `web/src/lib/funnel/stats.ts` (NEW) — `variantLift()`, two-proportion z-test, 95% CI, holdout enforcement, `minSampleSize` guard; returns `{ winner?, lift?, ci?, pValue?, note }`. Pure math; matches spec § Statistical rigour. · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Visitor state KV (haiku × 1)

- [x] **VS1** `web/src/lib/funnel/visitor-state.ts` (NEW) — `getState({slug, agentId, visitorHash})` reads `funnel:<slug>:<agentId>:<hash>` from KV; `updateState(...)` writes back; auto-expire 30d. Used by CRO dispatchers in W7.5 (CRO2, CRO4) without D1 hits. · `haiku` · w1[x] w2[x] w3[x] w4[x]

### Exports (sonnet × 2, haiku × 1)

- [x] **EXP1** `web/src/pages/api/agents/[id]/analytics/export.csv.ts` (NEW) — streams 100k-row cap CSV from `funnel_daily`; free tier; per-key rate-limit via existing K1 from W1 · deps: Q1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **EXP2** `web/src/pages/api/agents/[id]/analytics/export.json.ts` (NEW) — same as CSV in JSON shape; free tier · deps: Q1 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **EXP3** `web/src/pages/api/agents/[id]/analytics/export/parquet.ts` (NEW) — 302 redirect to R2 signed URL of the existing Parquet archive; billing-tier gate (Pro) via BIZ1 from W9 (skip gate in Phase 2.6, add when W9 lands) · deps: AGG2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### GDPR delete + analytics block + custom events (sonnet × 2, haiku × 1)

- [x] **GDPR1** `web/src/pages/api/visitor/[hash].ts` (NEW, admin auth) — DELETE removes rows matching `visitor_hash` from `agent_events`, `funnel_hourly`, `funnel_daily`, `funnel_visitor_state`, and queues R2 Parquet rewrite. Logs the delete in an audit table. · deps: DB1, AGG2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **ANBLOCK1** `web/src/lib/agent-schema.ts` + `agent-md.ts` extend — `analytics:` block with `attribution`, `retention`, `significance`, `exports`, `customEvents`, `substrate.{emitOn, sensitivity}` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **CUST1** `web/src/pages/api/chat.ts` + `sdk/src/client.ts` — `emit_event` chat tool + `client.emitAgentEvent` SDK method; both go through EV4 ingestion endpoint; namespace custom events `custom:<name>` and validate against `customEvents[].schema` in frontmatter · deps: ANBLOCK1, EV4 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

> **Same-file constraints:** `chat.ts` is also touched by CRO1/CRO7/CRO8 in W7.5 — sequence within ONE agent. `middleware.ts` is also touched by EV3 (visitor hash) plus Phase 3 W10 PERF1 — sequence.

---

# Phase 3 — Trust, business, scale (Waves 8-10)

After Phase 2 the builder is great for partners + their users. Phase 3
makes it a **platform with real ecosystem dynamics** — moderation,
pricing, marketplace, performance, i18n.

## Wave 8 — 8 parallel agents (deps: Phase 1 + Phase 2 base)

### Trust + safety (sonnet × 4, haiku × 1)

- [x] **TS1** `web/src/lib/agent-loader.ts` + `web/src/components/agents/VerifiedBadge.tsx` (NEW) — surface Sigstore signature; "verified partner" badge appears on `/studio/<id>` when bundle present and valid · deps: existing `oneie agent sign` · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TS2** `migrations/00XX_agent_flags.sql` + `web/src/pages/api/agents/flag.ts` + `web/src/pages/u/[slug]/moderation.astro` — user-reported flags land in moderation queue; owner approves/removes · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TS3** `web/src/lib/scan.ts` (NEW) + `api/agents/publish.ts` extend — scan markdown body + section text for XSS patterns (script tags, javascript:, on* handlers); content with high-confidence matches auto-rejected · deps: V1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TS4** `web/src/components/Chat.tsx` + `web/src/pages/api/abuse/report.ts` — "Report" button per assistant message; payload includes message id + thread id + agent id + reason; routes to platform admin queue · deps: PT2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **TS5** `web/src/pages/api/admin/agents/freeze.ts` (admin-auth only) — POST freezes an agent (R2 read still works, publish blocked, chat returns 451 with reason); UNDELETE-friendly · deps: none · `haiku` · w1[x] w2[x] w3[x] w4[x]

### Branding (sonnet × 2, haiku × 1)

- [x] **BR1** `web/src/lib/agent-schema.ts` + `Layout.astro` — `branding.favicon` swap when /studio loads an agent; falls back to default · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **BR2** `web/src/pages/api/og/[agentId].png.ts` (NEW) — render an OG card from agent title + hero + theme tokens using @vercel/og (or workers PDF); cached in KV 1d · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **BR3** `web/src/lib/agent-schema.ts` extend — `branding.socialCard: { title, description, image }` overrides BR2's auto-render · deps: BR2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 9 — 8 parallel agents (deps: Wave 8)

### Business + marketplace (sonnet × 4)

- [x] **BIZ1** `web/src/lib/billing-config.ts` + `api/agents/publish.ts` — per-publish billing tier: free=5 agents, pro=100, studio=unlimited; gate at publish endpoint; 402 with upgrade-url when exceeded · deps: V1, existing billing · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **BIZ2** `web/src/pages/agents.astro` extend — "Featured" section above general list curated by platform admin; new R2 key `_platform/featured.json` · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **BIZ3** `web/src/lib/revenue-split.ts` integration with skill purchases on /studio — when a skill priced > 0 executes, 4-way split fires (author / workspace / parent / platform) · deps: existing revenue-split · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **BIZ4** `web/src/pages/partners.astro` (NEW) — partner directory listing publishers + their public agents + opt-in earnings · deps: BIZ3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Discoverability (sonnet × 3)

- [x] **DISC1** `web/src/pages/agents.astro` overhaul — filter chips: group, tags, has-journey, has-theme, has-skills; URL-persisted state; pagination · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **DISC2** `web/src/pages/studio/[agent].astro` + `Layout.astro` — `?embed=widget` strips chrome (no nav, no hero, no footer), renders chat only at full bleed; suitable for iframe embedding · deps: MA1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **DISC3** `web/src/pages/marketplace.astro` (NEW) — cross-workspace listing of agents with `marketplace: public` in frontmatter; one-click "use this in my workspace" forks via TPL1 · deps: TPL1, BIZ2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Output stretch (sonnet × 1)

- [x] **OUT4** `web/src/pages/api/threads/[tid]/pdf.ts` (NEW) — server-side PDF render via Playwright or Workers PDF binding; landing on R2 with 24h presigned URL · deps: PT4 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 10 — 9 parallel agents (deps: all prior)

### Performance + scale (sonnet × 3, opus × 1)

- [x] **PERF1** `web/src/middleware.ts` extend — static section renders (no dynamic data) cached at CDN with KV-backed cache-buster on publish; cache-bust signal from A1 audit event · deps: A1, V1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PERF2** `web/src/components/journey/JourneyShell.astro` — stage card hover prefetches the chat-context for that stage's longPrompt; uses `link rel=prefetch` · deps: none · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PERF3** `web/src/components/journey/SectionRenderer.astro` — below-the-fold sections render shells immediately, hydrate via `client:visible` island; preserves SEO content · deps: R2-R10 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **PERF4** `astro.config.mjs` + render branches — heavy section components (code/Shiki, embed/iframe sandbox, gallery/lightbox) split into separate chunks; verified via lighthouse bundle audit · deps: R2-R10 · `opus` · w1[x] w2[x] w3[x] w4[x]

### i18n (sonnet × 2, haiku × 1)

- [x] **I18N1** `web/src/lib/agent-schema.ts` + agent-md.ts — `i18n.locales: [...]` + `i18n.translations: { vi: { title, description, starters, ... } }` declaration · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **I18N2** `web/src/lib/i18n.ts` (NEW) + studio page — `?lang=vi` resolves locale, swaps strings, persists to cookie; falls back to declared default · deps: I18N1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **I18N3** `web/src/pages/api/chat.ts` extend — append "Respond in {locale}" to the system prompt when locale ≠ default · deps: I18N2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Chat rich inserts (sonnet × 2)

- [x] **RI1** `web/src/lib/sections.ts` (NEW) — extract section Zod variants into a shared module imported by both `agent-schema.ts` (page sections) and `api/chat.ts` (chat inserts); single source of truth · deps: R2-R10 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **RI2** `web/src/pages/api/chat.ts` — `emit_section` tool that emits any section primitive mid-stream; client renders via `MessageRenderer` → `SectionRenderer` · deps: RI1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

# Closure scalars per wave (full)

| Wave | Numeric gate |
|---|---|
| W0 | `bun run typecheck` clean across web+sdk+cli+mcp; 5 new section schemas pass safeParse smoke tests |
| W1 | All 5 new kinds render on a test agent without console errors; per-key auth: publish with revoked key returns 401 |
| W2 | `publish → history → rollback` returns byte-identical content; rate-limit 11/min returns 429; banner amber/red split working |
| W3 | `oneie agent dev` HMR cycle < 200ms; `oneie agent list` < 100ms for 20-agent workspace |
| W4 | `oneie agent eval` returns non-zero scores; integration test passes end-to-end |
| W4.5 | `tools: []` agent makes zero tool calls in chat; agent with `skills:` ref has those names appear verbatim in the assembled system prompt; `skill` tool execution completes the turn in one streamText loop (no `finishReason: 'tool-calls'` dead-end); `GET /api/skills?slug=` lists workspace skills; `DELETE /api/skill/<name>` removes; composio toolkit listed in agent.tools surfaces external tools |
| W4.6 | `POST /signal/world:review` accepts every 5-mode address from `dsl.md` and forwards into substrate; `POST /ask/{r}` returns the 4-outcome union with HTTP 200 in every case; `POST /mark/{edge}` with `weight>0` + `currency` performs atomic mark-and-pay; webhook delivery passes signature verification on a partner endpoint; OpenAPI spec at `/openapi.yaml` covers 100% of handlers (CI gate); legacy `/api/agents/publish` etc. forward to substrate verbs with `Deprecation: true` + `Sunset:` header; 6 dimension reads (`/groups`,`/actors`,`/things`,`/paths`,`/events`,`/learning`) return data; `Idempotency-Key` replays return cached responses with original status; problem+json errors carry stable `type:` URIs; `X-Trace-Id` ulid appears in error body, response header, and substrate event row |
| W5 | Thread resumes show last 50 messages < 200ms; share URL renders read-only thread; analytics dashboard surfaces ≥ 5 events per visit |
| W6 | Lighthouse mobile ≥ 95 on `/studio/<id>` with bottom-sheet chat; keyboard shortcuts pass tab-order audit; print stylesheet renders journey + chat as 1-2 pages |
| W7 | 5 starter templates pass `agent validate` + `agent lint`; `agent ai-edit` produces a diff that re-validates clean; VSCode extension installs from .vsix |
| W7.5 | Funnel YAML validates; goal events resolve in < 5ms p95; KPI dashboard loads < 100ms p95 on pre-aggregated data; idle nudge fires within 2s of threshold and `idle-nudge-fired` event appears in stream; variant assignment is cookie-stable across page reloads; substrate `mark()` fires on every goal event (visible on `/api/loop/highways` for that agent) |
| W7.6 | Ingestion p95 < 5ms; hourly cron lag ≤ 5min; daily cron lag ≤ 30min; CSV export 30d at 10k events/day generates < 2s; Parquet < 30s; statistical guard rejects lifts below `minSampleSize` (renders "Not enough data"); GDPR delete removes a hash from all 4 tiers within 30s wall-time; PII smoke test (`email`, `ip`, `name` fields in payload) is dropped at ingestion |
| W8 | Sigstore verify badge appears for signed agents; XSS scan rejects `<script>`-embedded markdown body; flag → moderation queue end-to-end |
| W9 | Billing tier enforced (6th agent on free returns 402); featured list renders; marketplace fork creates a working agent in target workspace |
| W10 | Lighthouse perf ≥ 95 with all 14 section kinds; locale switch < 100ms; `emit_section` from chat tool renders all 14 kinds inline |

---

# Code rubric targets (apply to every cycle)

- **Security ≥ 0.85** — per-key auth, rate limit, content scan, moderation, sigstore verify, abuse report
- **Stability ≥ 0.80** — rollback exact; thread resume exact; no silent data loss; analytics events fire-and-forget never block render
- **Simplicity ≥ 0.75** — 9 new section kinds = 9 Zod branches + 9 renderers. No abstraction shared across them. One file per kind in `components/sections/`.
- **Speed ≥ 0.75** — HMR < 200ms; publish < 50ms p95; list < 100ms p95; thread resume < 200ms; locale switch < 100ms; Lighthouse mobile ≥ 95

Cycle gate: composite ≥ 0.65. Trust budget tracks 7-cycle rolling avg.

---

# Total scoreboard

| Phase | Items | Waves | Cycles | Outcome |
| --- | --- | --- | --- | --- |
| Phase 1 — solo authoring | 19 | W0-W4 | 5 | Solo partner ships a working studio |
| Phase 1.5 — skills + tools integrity | 7 | W4.5 | 1 | `tools:` enforced; skills discoverable; auto-loop; composio on web |
| Phase 1.6 — substrate API unification | 22 | W4.6 | 2 | 8 verbs, 6 dimensions, 5 addressing modes, 4 outcomes lifted from `dsl.md` |
| Phase 2 — measurement, UX, DX | 32 | W5-W7 | 5 | Measurable, persistent, accessible, multi-author |
| Phase 2.5 — lifecycle funnel + CRO | 16 | W7.5 | 2 | Goals, KPIs, A/B, idle nudge, abandonment recovery, pheromone-routed evolution |
| Phase 2.6 — analytics plumbing | 16 | W7.6 | 2 | Event schemas, D1 + R2 tiers, attribution, segmentation, stats, exports, GDPR delete |
| Phase 3 — trust, business, scale | 24 | W8-W10 | 5 | Real platform with marketplace, moderation, i18n |
| **Total planned** | **136** | **W0-W10** | **~22** | Complete agent builder |

---

*Fourteen section kinds. Twelve CLI commands. Twenty-plus endpoints.
Three phases. Seventy-five gaps. The agent builder is everything around
a markdown editor — and the builder gets out of the author's way.*
