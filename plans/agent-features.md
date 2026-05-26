# agent-features.md — the complete agent + builder spec

One `.md` file describes a complete agent on ONE: system prompt, skills,
journey, page sections, chat UI, theme, layout, persistence, analytics,
i18n, and uAgents compile target.

Authors edit markdown; the platform renders the studio, hosts the chat,
persists conversations, measures the funnel, and publishes to four
runtimes (web, uAgents, MCP, SKILL.md). Every feature listed here is
either shipped or planned in `agent-features-todo.md`.

---

## The four audiences

| Audience | What they need | Surface |
| --- | --- | --- |
| **Partner authors** | Author `.md`, validate, preview, publish, version, fork templates, measure outcomes, run in CI | CLI `oneie agent *`, SDK, MCP, `/studio/<id>` dev banner, `/u/<slug>/agents/<id>/analytics`, VSCode extension |
| **Workspace owners** | List, audit, roll back, gate, moderate, set pricing, see revenue | `/u/<slug>/agents`, `/u/<slug>/billing`, history/rollback, moderation queue |
| **End users** | Visit, chat, resume, share, print, complete journeys — on any device, any language | `/studio/<id>`, `/chat?agent=<id>&thread=<tid>`, `/share/<tid>`, iframe widgets, mobile-first layout, a11y |
| **Platform** | Rate-limit, audit, bill, gate, moderate, verify, replicate | `/api/agents/*`, middleware, substrate signals, Sigstore, status page |

---

## The single source

```
agent.md
├── identity      name · title · description · model · group · tags · sensitivity · lifecycle
├── i18n          locales[] · translations{} ([planned])
├── persona       starters · skills · tools · system prompt (body)
├── composition   bureau[] · subAgents{} ([planned web — exists uAgents])
├── uAgents       seed · port · mailbox · agentverse · intervals · endpoints
├── payments      wallet · accepts (x402) · price · currency
├── billing       publishTier · meterChat · revenueShare ([planned])
├── theme         primary · secondary · tertiary · background · foreground · font
├── branding      favicon · ogImage · socialCard ([planned])
├── ui
│   ├── hero        image · eyebrow · typewriter · false (opt-out, [planned])
│   ├── covers      url + label, marquee row
│   ├── starters    icon · tone · title · subtitle · seed · id
│   ├── quickReplies label · prompt · icon (Lucide)
│   ├── messages    placeholder · streaming · empty · error · welcome
│   ├── labels      send · speak · stop · approve · deny · share · save ([extend])
│   ├── voice       alloy | echo | fable | onyx | nova | shimmer
│   ├── layout      chat (wide|rail|icon|none|below) · chatLock · sidebar · mobile{} ([extend])
│   ├── avatar      image · name
│   ├── send        icon (Lucide) · label
│   ├── animation   typewriterSpeedMs · typewriterPauseMs · stageStaggerMs · sectionFadeMs ([extend])
│   ├── focusMode   single key to toggle, hides everything except chat ([planned])
│   ├── shortcuts   {key → action} ([planned])
│   └── print       enable · css · header · footer ([planned])
├── journey       intro · stages[] · pills[]
│   └── stages    id · num · phase · title · subtitle · bullets · time · tone
│                 · longPrompt · seed · sections[] · continuations[]
├── sections      kind (stat | card | grid | list | compare | cta | embed | code
│                       | timeline | hotel | form | testimonial | faq | gallery)
│                                  └─── 5 shipped ───┘ └─── 9 planned ───┘
├── analytics     events[] · funnel{} ([planned])
├── persistence   threadTtl · shareable · resumable ([planned])
├── moderation    blockList · sensitivityCap ([planned])
└── evals         cases[] · rubric{} ([extend])
```

uAgents compilation reads only the fields it cares about; web-only blocks
are silently ignored. Same file → four runtimes.

---

## Shipped today (don't rework)

### Authoring
- ✅ `parseAgentMd()` — js-yaml + Zod schema, two-tier issues (error / warn)
- ✅ Validation issues surface in: dev console, `/studio/<id>` red banner, CLI `validate`/`lint`
- ✅ CLI: `agent {new, validate, lint, compile, serve, publish, pull, unpublish, sign, verify, eval, diff}`
- ✅ Round-trip endpoints: `POST/GET/DELETE /api/agents/publish` with Bearer auth
- ✅ SDK: `client.{publishAgent, pullAgent, unpublishAgent}`
- ✅ MCP: `publish_agent`, `pull_agent`, `unpublish_agent`
- ✅ `compileAgent` targets: `python | mcp | skill | web | uagents | a2a | erc8004`

### Rendering
- ✅ `/studio/<id>` — generic studio for any registered or R2-published agent
- ✅ 5 section primitives: `stat`, `card`, `grid` (incl. affiliate), `list`, `compare`
- ✅ Journey funnel: stage strip + cards + pills
- ✅ Theme injection: 6 CSS custom properties scoped to the page
- ✅ Hero + cover marquee + starter cards (Lucide icons) + quick-reply chips
- ✅ Custom avatar, voice, send-button icon, label overrides, welcome banner

### Chat
- ✅ ai-sdk v6 streaming, tool approval, file attachments
- ✅ Owner-agent vs public-demo routing (Groq vs Workers AI)
- ✅ Chip vocabulary auto-derived from journey, replaces existing block in place
- ✅ Stop label flips to `ui.labels.stop` while streaming
- ✅ Trailing `<chips>` parser for cheap rich UI without tool calls

### Platform features (`features:` frontmatter)
- ✅ `field-service` — enables `emit_field_service_card` tool (10 card kinds: service-selector, map, scoping, quote, calendar, product, cart, severity, dispatch, job-tracker); API at `/api/field-service/[slug]/`; ops dashboard at `/studio/field-service-dashboard`; see `field-service.md`
- ✅ `field-service-dispatch` — extends `field-service` with dispatch description, auto-booking detection (calendar card JSON → D1), ref injection into system prompt
- ✅ `discovery-pipeline` — enables `emit_boq_card` tool (4 card kinds: boq-package, boq-discovery, boq-quote, boq-onboarding); discovery card confirms persist to `discovery_calls` D1 table via `/api/discovery/[slug]` (multi-tenant, `client_slug` partitioned); pipeline dashboard at `/studio/discovery-dashboard?slug=`; see `boq.md`

### Compatibility
- ✅ uAgents Python, MCP wrap, SKILL.md emit — same `.md`
- ✅ R2-published agents loaded at request time
- ✅ Build-time skills registry hydrates inline + ref skills

### Operational
- ✅ Anonymous chat burn from owner pool with IP rate-limit
- ✅ Workspace-scoped Bearer (`<slug>:<token>`) prevents cross-tenant writes
- ✅ 64KB content cap on publish

---

## Phase 1 — 19 gaps (in agent-features-todo.md, Waves 0-4)

Already triaged. Brief recap:

| Theme | Count | Examples |
| --- | --- | --- |
| **Section primitives** | 4 | `cta`, `embed`, `code`, `timeline` |
| **Hotel cleanup** | 1 | Promote affiliate grid to dedicated `hotel` kind |
| **Authoring loop** | 4 | `agent dev`, `agent list`, `agent diff` v2, `agent eval` real |
| **Versioning + history** | 4 | R2 versioned writes, `agent history`, `agent rollback`, audit signal |
| **Design polish** | 4 | Hero opt-out, banner amber/red, source badge, stage time skip |
| **Operational/security** | 2 | Per-key auth, publish rate-limit |

These are Wave 0-4 of `agent-features-todo.md`. After they ship, **the
agent builder is complete for solo partners.** Phase 2 + 3 unblock teams,
ecosystems, scale.

---

## Phase 1.5 — Skills + tools integrity (NEW, Wave 4.5 of TODO)

The skill execution path works end-to-end (verified on dev): agent →
chat → `skill` tool → R2 load → body returned. But six real gaps in
the existing flow only surface once an author actually publishes.

| # | Gap | Cause | Fix |
| --- | --- | --- | --- |
| 19a | **`tools:` allowlist declared but never enforced** | `api/chat.ts` builds the tools object unconditionally; never reads `agent.tools` | Filter `tools` against `agent.tools` (when set) before passing to `streamText`. Empty array = none; absent = all. |
| 19b | **Skills not enumerated in the system prompt** | LLM only sees a generic `skill` tool description | Append `Available skills: voice-of-brand (rewrite copy), draft-email ($0.05, marketing email), ...` to the assembled system prompt |
| 19c | **Skill body returns as raw markdown but doesn't auto-loop** | `kind: 'skill-content'` ends the turn at `finishReason: 'tool-calls'` | Force a continuation step: re-call `streamText` with the skill body as additional system context for the same turn |
| 19d | **No skill list/discover endpoint** | Skills are write-only via `import`; no `GET /api/skills/workspace?slug=` | Add list endpoint mirroring `/api/agents/list` shape |
| 19e | **No skill delete/unimport** | `/api/skill/import` writes only | Add `DELETE /api/skill/[name]?slug=` |
| 19f | **Web path doesn't use Composio external tools** | `claw/` integrates Composio for OAuth tools (Gmail, Discord, etc.) — web has only 10 platform tools | Port `claw/src/composio.ts` to web; `tools:` allowlist can include `composio:gmail`, `composio:slack`, etc. |

After 19a-f ship, `tools:` is real, skills are discoverable, execution
loops without manual prompting, and OAuth-gated external tools work on
web agents. **This is what makes the skills builder feel professional.**

---

## Phase 1.6 — Substrate API unification (Wave 4.6 of TODO)

The 58 legacy `/api/*` paths predate the substrate vocabulary. They
work, but they fragment the same DSL into REST CRUD that's
inconsistent with `dsl.md` / `dictionary.md` / `one-ontology.md`.

**[agent-api.md](agent-api.md)** redesigns the surface from those
canonical docs — **8 write verbs, 6 read dimensions, 5 addressing
modes, 4 outcomes**. Legacy paths forward into the verbs behind a thin
shim during the migration window.

| # | Gap | What ships |
| --- | --- | --- |
| API1 | No URL-addressed signal | `POST /signal/{receiver}` accepts the 5-mode addressing grammar verbatim |
| API2 | No URL-addressed ask | `POST /ask/{receiver}?timeout=` returns the 4-outcome union |
| API3 | No URL-addressed mark/warn | `POST /mark/{edge}` + `POST /warn/{edge}` with `source→target:task` syntax |
| API4 | No /fade verb | `POST /fade { trailRate, resistanceRate }` |
| API5 | No /sub | `POST /sub { actor, tag, scope, secret? }` — actors include external HTTPS URLs (= webhooks) |
| API6 | No /follow + /select | `GET /follow?type=` deterministic, `GET /select?type=&exploration=` stochastic |
| API7 | No 6-dimension read surface | `GET /groups`, `/actors`, `/things`, `/paths`, `/events`, `/learning` — one path per dimension |
| API8 | Identity via people/fingerprints duplicate | `/actors/{id}` covers all actor types; `world:identify` signal merges visitorHash → human actor — no `/people` table |
| API9 | No webhook delivery worker | Outbound subs deliver via canonical envelope: `Webhook-Id`, `Webhook-Timestamp`, `Webhook-Signature` (HMAC), retry curve |
| API10 | No OpenAPI 3.1 spec | Hand-written `public/openapi.yaml`; `x-substrate-verb` + `x-dimension` extensions; redocly build in CI |
| API11 | No idempotency / pagination / version negotiation conventions | `Idempotency-Key` middleware (24h KV); cursor pagination shared lib; `Accept: vnd.one.v1+json` |
| API12 | Errors aren't RFC 9457 | `lib/problem.ts` returns `application/problem+json` with stable `type:` URIs at `https://errors.one.ie/*` |
| API13 | No trace correlation | `lib/trace.ts` propagates a ulid through every handler; surfaces as `X-Trace-Id` + `traceId` in problem responses + substrate event row |
| API14 | Legacy paths don't forward | Shims at the 58 legacy paths translate into substrate verbs and emit `Deprecation: true` + `Sunset:` headers; clients have 6 months to migrate |
| API15 | No SDK type generation | `openapi-typescript` step in `sdk/` build; CI fails if generated types drift from hand-written ones |
| API16 | No API changelog | `web/api-changelog.md` + `/api/changelog` route; entries auto-derived from spec diffs |

After Phase 1.6 → the API **speaks the substrate**. Every URL maps to
a DSL verb; every read maps to a dimension; every outcome is one of
four; every webhook is a signed signal. Partners can generate clients
from the OpenAPI spec and the spec itself reads like the dictionary.

---

## Phase 2 — UX & DX gaps (Waves 5-7 of TODO)

The studio renders beautifully today. But authors can't *measure*, users
can't *resume*, and the build loop ends at "publish." Phase 2 closes those.

### Conversation persistence (4 items)

| # | Feature | Surface |
| --- | --- | --- |
| 20 | **Thread storage** — every chat session persists to D1 keyed by `(slug, agentId, threadId)`; user resumes via cookie or `?thread=<tid>` | `migrations/00XX_threads.sql`, `lib/threads.ts`, `api/chat.ts` extend |
| 21 | **Share link** — `/share/<tid>` renders a read-only thread; copy button in chat surfaces a URL | `api/share/[tid].ts`, `pages/share/[tid].astro` |
| 22 | **Resume banner** — if user has a thread for this agent, show "Resume your last conversation" CTA | `Chat.tsx`, reads from cookie |
| 23 | **Export thread** — markdown / .docx / JSON; one-click from the thread header | `api/threads/[tid]/export.ts` |

### Analytics + measurement (5 items)

Authors can't improve what they can't see. Each chip click, stage start,
chat message → substrate event. Authors get a per-agent dashboard.

Basic events + dashboard live here as Phase 2 foundation. Two dedicated
companion specs go deep:

- **[agent-lifecycle.md](agent-lifecycle.md)** — funnel, goals, CRO techniques (Phase 2.5)
- **[agent-analytics.md](agent-analytics.md)** — event taxonomy, D1 schemas, query patterns, attribution, segmentation, statistical rigour, retention, exports, privacy (Phase 2.6 — new wave)

| # | Feature | Surface |
| --- | --- | --- |
| 24 | **Event emission contract** — every interactive emits `agent:<id>:<event>` via `emitClick`; 14 standard events (intro-shown, stage-start, stage-complete, stage-drop, chip-impression, chip-click, chat-message, chat-tool-call, artifact-saved, share-link-copied, journey-complete, idle-nudge-fired, variant-assigned). Full list in agent-lifecycle.md. | `JourneyShell.astro`, `Chat.tsx` |
| 25 | **Funnel API** — `GET /api/agents/<id>/analytics?from=&to=` returns counts per event + conversion rates | `api/agents/[id]/analytics.ts` |
| 26 | **Analytics dashboard** — `/u/<slug>/agents/<id>/analytics` charts funnel, retention, top chips | `pages/u/[slug]/agents/[id]/analytics.astro` |
| 27 | **A/B variant declaration** — `variants: { A: 0.5, B: 0.5 }` in frontmatter; each visit pinned via cookie; winning variant earns pheromone | `agent-md.ts` extend, `Chat.tsx`, `agent-loader.ts` |
| 28 | **Goal definition** — `goals: [{ id, name, event }]` in frontmatter; analytics reports conversion to each goal | `agent-schema.ts` extend, dashboard |

### Mobile + accessibility (5 items)

The current layout is desktop-first; `ui.layout.chat: wide` doesn't
collapse cleanly on phones.

| # | Feature | Surface |
| --- | --- | --- |
| 29 | **Responsive layout** — `ui.layout.mobile: { chat: 'sheet'|'inline'|'icon', sections: 'stack'|'tabs' }` | Layout.astro, Chat.tsx |
| 30 | **Bottom-sheet chat on mobile** — slides up from bottom, swipe-to-dismiss | new `MobileChatSheet.tsx`, Chat.tsx swap |
| 31 | **WCAG AA audit per section kind** — every new render branch (cta, embed, code, timeline, hotel, form, testimonial, faq, gallery) verified for contrast + keyboard nav + screen reader | tests + design rule |
| 32 | **Keyboard shortcuts** — `1-6` for stages, `/` to focus chat, `Esc` to close sheet, `g g` to jump to agents list | new `useKeyboardShortcuts` hook |
| 33 | **Camera attachment on mobile** — phone camera button on attachments input; permission flow | `attachments.tsx`, navigator.mediaDevices |

### Output management (4 items)

Drafts and plans are the artifact. They need to leave the chat.

| # | Feature | Surface |
| --- | --- | --- |
| 34 | **Copy-as-markdown** — chat message → clipboard as md including images | `MessageRenderer.tsx`, copy button |
| 35 | **Save thread as artifact** — store the assistant's response as a named artifact under `{slug}/artifacts/<id>.md` | `api/artifacts/save.ts` |
| 36 | **Print stylesheet** — `@media print` rules for /studio + chat, plus `ui.print.header/footer` overrides | Layout.astro, `print.css` |
| 37 | **PDF export** — server-side render to PDF via Playwright (or workers PDF API when available) | `api/threads/[tid]/pdf.ts` |

### Forms + multi-step inputs (3 items)

Some journeys (Hanoi: budget/dates/party-size; marketing: brief-fill)
need actual structured input, not freeform chat.

| # | Feature | Surface |
| --- | --- | --- |
| 38 | **`form` section kind** — `{ kind: 'form', fields: [{ name, label, type: 'text'|'number'|'date'|'select', options? }], submitLabel, seedPromptTemplate }` | agent-schema.ts, agent-md.ts, SectionRenderer.astro |
| 39 | **Form submit → chat seed** — submitting the form interpolates field values into a prompt template and seeds the chat | new `FormSection.tsx` client component |
| 40 | **Field validation** — Zod-driven client-side validation per field; aria-invalid + error message | FormSection.tsx |

### Templates + scaffolding (4 items)

`oneie agent new` exists but the profile system is invisible. A gallery
of forkable templates dramatically lowers the cold-start cost.

| # | Feature | Surface |
| --- | --- | --- |
| 41 | **Template gallery** — `oneie agent templates` lists available templates with description + preview URL | CLI extend, registry in `templates.json` |
| 42 | **Fork command** — `oneie agent fork <template-or-url> <local-name>` clones the template, swaps `name:` and ids | CLI extend |
| 43 | **`oneie agent ai-edit <path>` — prompt-driven edit** — the CLI uses Claude/Groq to apply a high-level instruction ("add a hotels grid for Tokyo") to the .md | CLI + ai-sdk |
| 44 | **5 starter templates** — travel-planner, marketing-strategist, support-tier1, sales-discovery, code-reviewer | `agents/templates/` |

### Tooling + ecosystem (4 items)

The CLI is the developer surface. To scale, authors need to author from
their editor and ship from their CI.

| # | Feature | Surface |
| --- | --- | --- |
| 45 | **VSCode extension** — schema-aware autocomplete, inline validation, preview button, hover docs for every field | `tools/vscode-extension/` (NEW) |
| 46 | **GitHub Action** — `oneie/agent-publish-action@v1` validates on PR + publishes on merge | `.github/actions/agent-publish/` |
| 47 | **Git-based workflow** — partner repo points at agents/, platform polls + pulls on webhook | `api/agents/sync-from-git.ts` |
| 48 | **LSP server** — language server providing the same validation surface for any editor | `tools/agent-md-lsp/` |

### Composition (3 items)

Today `bureau:` is uAgents-only. On web, an agent can't delegate to
sub-agents in chat.

| # | Feature | Surface |
| --- | --- | --- |
| 49 | **Sub-agents in frontmatter** — `subAgents: [{ name, when, agent }]` declares delegate routes | agent-schema.ts |
| 50 | **Delegation tool in chat** — when the LLM emits `delegate_to(<sub-agent>, <task>)`, the chat splits a thread and routes through the sub-agent's prompt | api/chat.ts, new `delegate` tool |
| 51 | **Multi-agent thread visualization** — chat shows which sub-agent handled which turn | MessageRenderer.tsx |

---

## Phase 2.5 — Lifecycle funnel + CRO (Wave 7.5 of TODO)

The full funnel subsystem from **[agent-lifecycle.md](agent-lifecycle.md)** —
turns Phase 2's raw analytics into a closed-loop optimisation system.

| # | Feature | Surface |
| --- | --- | --- |
| 51a | **`funnel:` frontmatter block** — `goals`, `stages`, `kpis`, `optimization`, `visitorTypes`, `a2a` | `agent-schema.ts` extend, types in `agent-md.ts` |
| 51b | **Goal resolution engine** — `lib/funnel.ts` evaluates `successSignal`/`partialSignal`/`dropSignal` against event stream; tags each event with which goal(s) it satisfied | `lib/funnel.ts` (NEW) |
| 51c | **KPI compute** — 9 KPIs (SCR, drop-off, TTC, chip CTR, artifact rate, return rate 7d, variant lift, CV, path strength); D1 query + KV cache | `api/funnel/[id]/kpis.ts` (NEW) |
| 51d | **Funnel dashboard** — funnel chart, KPI cards, optimisation impact cards, A/B compare | `pages/u/[slug]/agents/[id]/funnel.astro` + 3 React components |
| 51e | **Daily aggregation cron** — pre-computes hourly + daily rollups for fast dashboard | `workers/funnel-aggregate-cron.ts` + migration |
| 51f | **CRO: idle re-engagement** — silent N seconds → server emits a nudge through the chat stream; capped by `maxFires` | `lib/cro/idle.ts` (NEW), `api/chat.ts` extend |
| 51g | **CRO: abandonment recovery** — return within `windowDays` → resume banner with thread restore | `lib/cro/abandonment.ts`, `Chat.tsx` |
| 51h | **CRO: social proof** — "N users completed this week" badge, KV-cached, `minCount` floor | `lib/cro/social-proof.ts`, intro component |
| 51i | **CRO: progressive disclosure** — visually-gated stages until prior goal fires; client reads stage-completion API | `lib/cro/disclosure.ts`, `JourneyShell.astro` |
| 51j | **CRO: variable reward** — unlock free skill / template at milestone | `lib/cro/variable-reward.ts`, `api/unlocks/grant.ts` |
| 51k | **CRO: friction reduction** — pre-fill from prior thread's last summary | `lib/cro/friction.ts`, `lib/threads.ts` extend |
| 51l | **A/B variant engine** — cookie-pinned assignment, per-arm prompt override, sample-size-guarded winner pick | `lib/cro/variants.ts`, `agent-loader.ts` extend |
| 51m | **Personalisation rules** — `when` conditions (returning/variant=B/locale/etc.) → seed prompt / quick replies / sections override | `lib/cro/personalisation.ts`, `api/chat.ts` |
| 51n | **A2A funnel signals** — `peer-discovery-query`, `peer-call-issued`, `pheromone-mark/warn`, `x402-receipt-verified` fire as events | `api/agents/discover.ts` + `api/peer/*` extend |
| 51o | **Substrate pheromone integration** — every funnel event → `one.signal('agent:<id>:<event>', ...)` → L1+L2 marks on edges; L5 evolution can rewrite poorly-converting prompts | `lib/funnel.ts` substrate hook |
| 51p | **"Apply this change" CTAs on optimization cards** — prefills a PR / agent-edit diff for the partner | dashboard + git integration (depends on TOOL3) |

After Phase 2.5 → an agent has a measurable funnel, declared goals,
pre-baked CRO techniques the partner toggles via YAML, and the substrate
routes more traffic to agents that convert. **This is the closed loop.**

---

## Phase 2.6 — Analytics plumbing (Wave 7.6 of TODO)

The infrastructure layer that powers Phase 2.5's funnel. Full spec at
**[agent-analytics.md](agent-analytics.md)**.

| # | Feature | Surface |
| --- | --- | --- |
| 51q | **Event vocabulary module** — shared constants source consumed by schema + ingestion + dashboards | `lib/event-vocabulary.ts` (NEW) |
| 51r | **Per-event Zod schemas** — payload validation per event name at ingestion | `lib/agent-events.ts` (NEW) |
| 51s | **Visitor hash + middleware** — `Astro.locals.visitorHash` set from `sha256(cookie + workspace_salt)` | `middleware.ts` extend |
| 51t | **Hourly + daily aggregation** — `funnel_hourly` + `funnel_daily` D1 tables, cron-populated | `migrations/*`, `workers/funnel-aggregate-cron.ts` |
| 51u | **R2 archival** — daily Parquet exports beyond 14-day hot window | cron extend |
| 51v | **9 SQL query patterns** — funnel, variant lift, chip CTR, retention cohort, A2A path strength, etc. | `lib/funnel/queries.ts` (NEW) |
| 51w | **Attribution models** — first-touch / last-touch / linear, configurable via `analytics.attribution` | `lib/funnel/attribution.ts` |
| 51x | **Segmentation engine** — variant × locale × device × referrer × UTM | `lib/funnel/segmentation.ts` |
| 51y | **Statistical guard rails** — two-proportion z-test + CI + holdout enforcement on variant comparisons | `lib/funnel/stats.ts` |
| 51z | **Per-visitor KV state** — `funnel_visitor_state` for CRO dispatch without D1 hits | `lib/funnel/visitor-state.ts` |
| 51aa | **Three export endpoints** — CSV (free), JSON (free), Parquet (Pro, R2 signed URL) | `api/agents/[id]/analytics/export.{csv,json,parquet}.ts` |
| 51bb | **GDPR delete** — admin endpoint removing visitor rows across all tiers within 30 days | `api/visitor/[hash].ts` |
| 51cc | **`analytics:` frontmatter block** — attribution + retention + significance + exports + custom events + substrate sensitivity | `agent-schema.ts` extend |
| 51dd | **Custom events via tool** — `emit_event({ name: 'persona-locked', payload })` chat tool + SDK `client.emitAgentEvent` | `api/chat.ts` extend, `sdk/src/client.ts` |
| 51ee | **Real-time SSE stream** (Phase 3) — `/api/funnel/<id>/live` pushes new events for live dashboards | `api/funnel/[id]/live.ts` |
| 51ff | **7 React chart components** — FunnelChart, KpiCardRow, SegmentSelector, VariantComparison, OptimizationImpact, CohortHeatmap, ExportPanel | `components/funnel/*.tsx` |

After Phase 2.6 → the data pipeline is real, queries are sub-100ms,
attribution is configurable, statistical claims are gated on sample
size, exports work end-to-end, and PII never reaches storage.

---

## Phase 3 — Trust, business, scale (Waves 8-10 of TODO)

Phase 1 + 2 ship a great single-tenant builder. Phase 3 makes it a
platform with real ecosystem dynamics.

### Trust + safety (5 items)

| # | Feature | Surface |
| --- | --- | --- |
| 52 | **Sigstore verified-partner badge** — `oneie agent sign` already exists; surface verification on `/studio/<id>` | sigstore verify in agent-loader, badge in studio |
| 53 | **Moderation queue** — agents flagged by users land in `/u/<slug>/moderation`; owner approves/removes | `api/agents/flag.ts`, queue page |
| 54 | **Content scan on publish** — markdown body + section fields scanned for XSS/injection patterns; auto-reject high-confidence matches | `api/agents/publish.ts` extend with scanner |
| 55 | **Abuse reporting** — every chat surface has a "report" button → routes to platform admin | `Chat.tsx`, `api/abuse/report.ts` |
| 56 | **Takedown handler** — admin endpoint to remove + freeze agents pending review | `api/admin/agents/freeze.ts` (admin auth) |

### Branding (3 items)

| # | Feature | Surface |
| --- | --- | --- |
| 57 | **Custom favicon per agent** — `branding.favicon: <url>` swaps for the studio page | Layout.astro reads from agent.branding |
| 58 | **Open Graph card generator** — `/og/<agentId>` returns a PNG built from the agent's title + hero + theme tokens | `api/og/[agentId].png.ts` via @vercel/og or wasm-pdf |
| 59 | **Social card override** — `branding.socialCard: { title, description, image }` for fine control | agent-schema.ts |

### Business + marketplace (4 items)

| # | Feature | Surface |
| --- | --- | --- |
| 60 | **Per-publish billing tier** — free (5 agents), pro (100), studio (unlimited) — enforced at `api/agents/publish.ts` | `lib/billing-config.ts` extend, gate in publish |
| 61 | **Featured agents on `/agents`** — curated section above general list | `/agents` page extend |
| 62 | **Revenue share for skills** — skills priced > 0 split between author + workspace + platform via existing 4-way split | `lib/revenue-split.ts` integration |
| 63 | **Partner directory** — `/partners` lists active publishers with their agents + earnings (opt-in) | new page + opt-in flag |

### Discoverability (3 items)

| # | Feature | Surface |
| --- | --- | --- |
| 64 | **Enriched `/agents`** — filter by tags / group / has-journey / has-theme / has-skills | `/agents.astro` overhaul |
| 65 | **Iframe embed mode** — `/studio/<id>?embed=widget` strips chrome, fits any host page | studio template extend |
| 66 | **Cross-workspace marketplace** — agents published with `marketplace: public` discoverable from `/marketplace` regardless of workspace | new `marketplace.astro` |

### Performance + scale (4 items)

| # | Feature | Surface |
| --- | --- | --- |
| 67 | **Edge cache for static section renders** — sections with no dynamic data cached at CDN (KV-backed) with cache-buster on publish | middleware cache header logic |
| 68 | **Prefetch likely next routes** — stage card hover → prefetch the chat-context for that stage | JourneyShell.astro inline script |
| 69 | **Lazy load below-the-fold sections** — sections render shells immediately, fill in via `client:visible` islands | SectionRenderer.astro |
| 70 | **Bundle splitting** — heavy section renderers (`code` with Shiki, `embed` with iframe sandbox) become separate chunks | astro.config.mjs route hints |

### i18n (3 items)

| # | Feature | Surface |
| --- | --- | --- |
| 71 | **Locales declaration** — `i18n.locales: [en, vi, ja]` + `i18n.translations: { vi: { title: ..., starters: [...] } }` | agent-schema.ts |
| 72 | **Locale switcher** — `/studio/<id>?lang=vi` swaps frontmatter strings; persists to cookie | studio template + middleware locale resolution |
| 73 | **System prompt locale** — chat instructs the model to respond in the resolved locale | api/chat.ts |

### Chat rich inserts (2 items, was stretch)

| # | Feature | Surface |
| --- | --- | --- |
| 74 | **Unified section schema for chat inserts** — the same Zod variants used for page sections also valid as mid-conversation cards; one schema, two render paths | `lib/sections.ts` (NEW shared) |
| 75 | **Tool: `emit_section`** — chat tool that emits any section primitive into the stream | `api/chat.ts` extend tools |

---

## Total scoreboard

| Phase | Gap count | Wave range | Estimated cycles |
| --- | --- | --- | --- |
| Phase 1 — solo authoring | 19 | W0-W4 | 5 |
| Phase 1.5 — skills + tools integrity | 6 | W4.5 | 1 |
| Phase 1.6 — substrate API unification | 22 | W4.6 | 2 |
| Phase 2 — measurement, UX, DX | 32 | W5-W7 | 5 |
| Phase 2.5 — lifecycle funnel + CRO | 16 | W7.5 | 2 |
| Phase 2.6 — analytics plumbing | 16 | W7.6 | 2 |
| Phase 3 — trust, business, scale | 24 | W8-W10 | 5 |
| **Total planned** | **135** | **W0-W10** | **~22** |

After Phase 1 → solo partner ships a working studio. After Phase 1.5 →
skills and tools actually behave as the schema claims. After Phase 2 →
measurable, persistent, accessible, multi-author, multi-editor. After
Phase 2.5 → **closed-loop CRO** — goals, KPIs, A/B testing, idle nudges,
abandonment recovery, pheromone-routed evolution. After Phase 2.6 →
the data layer underneath is real (D1 + R2 tiers, attribution,
segmentation, exports, statistical rigour, GDPR delete). After Phase 3 →
real platform with marketplace, moderation, i18n.

---

## Files this spec touches

Phase 1 files already enumerated in agent-features-todo.md. Phase 2 + 3:

```
NEW
  migrations/00XX_threads.sql          → thread persistence
  migrations/00XX_api_keys.sql         → per-key auth (Phase 1 W1)
  migrations/00XX_agent_events.sql     → analytics events
  migrations/00XX_agent_flags.sql      → moderation queue
  web/src/lib/threads.ts               → thread CRUD
  web/src/lib/sections.ts              → shared section schema
  web/src/lib/i18n.ts                  → locale resolution
  web/src/lib/scan.ts                  → publish content scanner
  web/src/pages/api/threads/*          → thread endpoints (export, share, pdf)
  web/src/pages/api/agents/[id]/analytics.ts
  web/src/pages/api/agents/flag.ts
  web/src/pages/api/admin/agents/freeze.ts
  web/src/pages/api/og/[agentId].png.ts
  web/src/pages/api/abuse/report.ts
  web/src/pages/share/[tid].astro
  web/src/pages/marketplace.astro
  web/src/pages/partners.astro
  web/src/pages/u/[slug]/agents/[id]/analytics.astro
  web/src/components/MobileChatSheet.tsx
  web/src/components/FormSection.tsx
  web/src/components/sections/Code.tsx
  web/src/components/sections/Embed.tsx
  web/src/components/sections/Hotel.tsx
  web/src/components/sections/Timeline.tsx
  web/src/components/sections/Form.tsx
  web/src/components/sections/Testimonial.tsx
  web/src/components/sections/Faq.tsx
  web/src/components/sections/Gallery.tsx
  web/src/components/sections/Cta.tsx
  web/src/hooks/useKeyboardShortcuts.ts
  tools/vscode-extension/                → VSCode extension
  tools/agent-md-lsp/                    → LSP server
  agents/templates/{travel,marketing,support,sales,code-review}/  → starters

MODIFIED
  web/src/lib/agent-md.ts            → add 9 new section types + branding + i18n + variants + goals
  web/src/lib/agent-schema.ts        → add 9 section kinds + i18n + variants + composition
  web/src/lib/agent-loader.ts        → variant pinning + i18n resolution + sigstore verify
  web/src/lib/agents.ts              → expose .issues, .variants, .branding
  web/src/components/Chat.tsx        → thread resume + share + report + delegation viz
  web/src/components/journey/SectionRenderer.astro → 9 new render branches + lazy + edge cache
  web/src/pages/studio/[agent].astro → mobile layout + a11y + i18n + favicon
  web/src/pages/api/chat.ts          → thread storage + delegation + analytics events + emit_section
  web/src/pages/api/agents/publish.ts → content scan + billing gate + variant validation
  web/src/layouts/Layout.astro       → favicon override + OG card + print styles + locale
  web/src/middleware.ts              → locale resolution + edge cache logic
  cli/src/agent.ts                   → templates, fork, ai-edit, sync-from-git
  .github/actions/agent-publish/     → CI integration
```

---

## Compatibility invariants (don't break)

1. **uAgents target reads only known fields.** New web-only blocks (`analytics`, `persistence`, `i18n`, `subAgents`, `branding`, `variants`, `goals`, `moderation`) must not break `compileAgent(md, { target: 'uagents' })`.
2. **Build-time registry remains the fast path.** New features that need I/O (versioning, analytics, persistence) gate on R2 path only.
3. **Schema is two-tier — errors load anyway.** A single bad field never blanks the whole agent.
4. **YAML stays the source.** No code-gen, no codegen-only fields. Sibling JSON files (`{slug}/agents/{name}.metadata.json`, `{slug}/agents/{name}/analytics.json`) for runtime data.
5. **One section kind, one Zod variant, one renderer.** No partial implementations across kinds.
6. **Mobile + a11y are not afterthoughts.** Every new section kind must ship with a mobile layout + keyboard nav + WCAG AA verified.
7. **i18n strings never block initial render.** Default to declared `title`/`description`; localised strings hydrate on locale resolution.
8. **Sigstore signing is opt-in but, when present, surfaced.** A signed agent shows the verified-partner badge; unsigned agents don't show "unverified" — they show nothing (no negative signal).

---

## Quality bar — what "feature complete" means

| Dimension | Target |
| --- | --- |
| **Lighthouse mobile** | 95+ on `/studio/<id>` for every new section kind |
| **WCAG AA** | All interactive surfaces pass contrast + keyboard nav |
| **Cold start** | TTFB < 100ms p95 globally for the studio page |
| **HMR (dev)** | `oneie agent dev` reload cycle < 200ms |
| **Publish** | `<` 50ms p95 round-trip including R2 write |
| **Analytics ingest** | Lag < 30s from event to dashboard |
| **Thread resume** | Last 50 messages within 200ms |
| **i18n switch** | < 100ms perceived (cached locale bundles) |

If any of these regress when a feature ships, the feature fails the
rubric and reverts. Numbers, not vibes.

---

*One file, four runtimes, six tokens, fourteen section kinds, three
phases, seventy-five gaps. The agent builder is a markdown editor — and
every piece of the experience around it.*
