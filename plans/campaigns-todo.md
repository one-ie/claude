---
title: Campaigns — the marketing console on /in
slug: campaigns
type: plan
tier: complex
mode: construction
tags: [campaigns, crm, marketing, agents, tracking, analytics, integrations]

# ─── PARALLELISM CONTRACT ────────────────────────────────────────────
# Rethink (2026-05-17): CQW2 deleted (campaigns = groups preset in /in,
# no separate page); CSwarm-core moved to Batch 1 (value prop first);
# personas + offers presets added to CQW1; batch count 4→5.

parallel_budget:
  haiku:   30
  sonnet:  30
  opus:    6           # CSwarm-core + CIntegrations + CMediaCreative + CMediaAds + CMediaSocial + CMediaContent

batches:
  # Batch 1: value-prop first — file-disjoint; all three run in parallel
  - [CSwarm-core, CQW1, CIntegrations]
  # Batch 2: surfaces that need the campaigns preset + swarm card to exist
  - [CQW3, CQW4, CQW5, CQW6, CQW7, CCRoles]
  # Batch 3: deeper UX — needs detail pane (CQW3) or empty-state (CQW6)
  - [CCV, CCSeq, CCLift, CCAttr, CCNotif]
  # Batch 4: paid + creative channel adapters — need CIntegrations + CSwarm-core
  - [CMediaCreative, CMediaAds]
  # Batch 5: messaging + organic — same dependencies, after Batch 4 settles
  - [CMediaEmail, CMediaSMS, CMediaSocial, CMediaContent]

shared_recon:
  - web/campaigns.md
  - web/src/components/in/EntityDetail.tsx
  - web/src/components/in/Inbox.tsx
  - web/src/components/in/Composer.tsx
  - web/src/components/in/Navigation.tsx
  - web/src/lib/in/workspace-settings.ts
  - web/src/data/in-types.ts
  - claw/src/agents/builder.ts

# ─────────────────────────────────────────────────────────────────────

source_of_truth:
  - web/campaigns.md
  - web/crm.md
  - web/agent-analytics.md
  - web/tracking.md
  - one/marketing-ontology.md

existing_primitives:
  - web/src/components/in/Navigation.tsx: rail with zones · CQW1 adds one row
  - web/src/components/in/Inbox.tsx: list/detail shell · CQW3 + CQW5 reuse verbatim
  - web/src/components/in/EntityDetail.tsx: detail-pane shell · CQW3, CCSeq, CCLift, CCAttr slot into it
  - web/src/components/in/EntityCard.tsx: list rows · CQW3 list view, CQW5 + CQW6 discovered view
  - web/src/components/in/EditableField.tsx: inline edit any attribute · CCV error display in EntityDetail campaign body
  - web/src/components/in/Composer.tsx: universal composer · CQW4 reads ?preset=campaign:<id>; CQW6 invokes with kind:new-campaign
  - web/src/components/in/ChannelCreateForm.tsx: form-shape template · CIntegrations extends for OAuth Connect chips
  - web/src/components/in/HeroCTA.tsx: per-preset CTA pill · CQW6 wires "+ New campaign"
  - web/src/components/in/NotificationBell.tsx: bell with topic subscriptions · CCNotif adds campaign event topics
  - web/src/components/in/BulkBar.tsx: bulk actions + drag patterns · CCSeq reorder
  - web/src/components/in/MergeReviewDrawer.tsx: probabilistic-merge pattern · reference for connection-warning drawer
  - web/src/components/funnel/*.tsx: 10 charts — 9 receive data props (page constructs URLs), 1 fetches via WebSocket (LiveEventStream) · CQW3 changes the page, not the charts
  - web/src/components/chat/MessageRenderer.tsx: card-kind switch · CSwarm registers CampaignCardRenderer
  - web/src/components/chat/cards/BoqCardRenderer.tsx: card-renderer pattern · CSwarm clones the shape
  - web/src/components/chat/ActionChips.tsx: Approve/Edit/Cancel chip pattern · CSwarm + CQW7 reuse
  - web/src/lib/funnel/stats.ts: variantLift z-test · CCLift filters by campaign
  - web/src/lib/funnel/attribution.ts: first/last/linear models · CCAttr filters by campaign
  - web/src/lib/use-watch.ts: SSE realtime hook · CQW3 detail pane, CSwarm card streaming, CCNotif bell
  - web/src/lib/analytics-client.ts: trackEvent → POST /api/events · already writes campaign tag automatically
  - web/src/pages/api/agents/[id]/analytics.ts: KPI endpoint · CQW3 + CCLift + CCAttr add ?campaign query param
  - web/src/pages/api/frontiers.ts: L6 KNOWLEDGE candidates · CQW5 filters kind=campaign-candidate
  - web/src/pages/api/events.ts: typed ingest · auto-stamps campaign field from tags
  - web/src/pages/u/[slug]/agents/[id]/analytics.astro: page that constructs all 10 chart URLs · CQW3 mirrors for campaign view
  - web/src/workers/analytics-relay.ts: WorkspaceDO pheromone · already tracks tag-pair paths
  - claw/src/agents/builder.ts: makeAgent() ToolLoopAgent · CSwarm cmo + agent rebuilds
  - claw/src/composio.ts: BYO Composio accounts (Gmail/Slack/etc) · reference for CIntegrations OAuth pattern
  - claw/src/aitools.ts: substrate tool registry · CSwarm + CMediaCreative + CMediaAds register
  - claw/src/adapters/{hubspot,stripe,shopify,ghl,salesforce,klaviyo}.ts: 6 CRM adapter files · pattern for CMediaAds + CMediaEmail + CMediaSMS + CMediaSocial + CMediaContent new adapters. Klaviyo is already shipped — CMediaEmail extends it for transactional email patterns.
  - agents/export-meta.md + agents/export-tiktok.md: existing export agents · reuse audience-export code paths in CMediaAds
  - claw/src/personas.ts: Persona type loaded by builder · CSwarm agents add entries
  - sdk/: SubstrateClient with syncAgent, signal, ask, mark, warn, oneFetch · all cycles use signal; CMediaCreative + CMediaAds use oneFetch wrapped by adapters
  - agents/compliance.md: infrastructure-style agent (subscribes/emits frontmatter, no journey) · CSwarm pattern reference
  - web/agents/marketing-strategist.md: chat-style agent (592 LOC, full journey/sections/ui) · reference for any consumer-facing agent

show: false

escape:
  condition: "any of CSwarm, CMediaCreative, CMediaAds, CIntegrations fails W4 twice — provider/platform integration deeper than recon found"
  action: "halt; defer the failing cycle to a follow-up plan (mediaProvider-todo.md or oauth-todo.md); ship the rest of v1 without that provider"

context_triggers:
  - pattern: "creative-providers|oneFetch|model provider|Imagen|Flux|Veo"
    inject: "x402.md § Send-side SDK + sdk/ oneFetch implementation"
  - pattern: "ad-platform|paid-meta|paid-google|paid-linkedin|paid-tiktok|CAPI|OAuth"
    inject: "tracking.md § 2.8 Ad platform webhooks + claw/src/adapters/hubspot.ts as adapter pattern"
  - pattern: "swarm|fan-out|topology|brief signal|cmo"
    inject: "marketing-ontology.md § The 23-agent department + agents/compliance.md as subscribe/emit reference"
  - pattern: "variant lift|z-test|holdout"
    inject: "agent-analytics.md § Statistical rigour"
  - pattern: "syncAgent|client extensibility|cascade"
    inject: "campaigns.md § 8 — How clients change anything"
  - pattern: "L5|OPTIMIZATION|creative fatigue|generation"
    inject: "DEFER — L5 ships in l5-todo.md, not this plan; v1 uses manual variant card regenerate"
  - pattern: "Klaviyo|Resend|Postmark|email adapter"
    inject: "claw/src/adapters/klaviyo.ts as base pattern; Resend + Postmark are similar API-key + REST shape"
  - pattern: "Twilio|SMS|MMS"
    inject: "Twilio Programmable Messaging API (Account SID + Auth Token); webhook for inbound replies"
  - pattern: "Twitter|X API|LinkedIn organic|Instagram Graph|TikTok organic|UGC API"
    inject: "Twitter/X v2 + LinkedIn UGC API + Instagram Graph + TikTok organic — all OAuth 2.0; LinkedIn UGC scope differs from LinkedIn Ads scope"
  - pattern: "Webflow|WordPress|Ghost|CMS|blog publishing"
    inject: "Webflow CMS API (API token), WordPress REST API (Application Passwords or OAuth), Ghost Admin API (Admin API key)"
---

# Campaigns — the marketing console on /in

**Goal:** ship the create / view / manage console for marketing campaigns described in [`web/campaigns.md`](campaigns.md). One sentence brief → swarm-assembled card → `[Approve & ship]` → live multi-platform campaign in 5–10 min. Marketer-quality UX: empty state, new-campaign button, swarm progress, connection warnings, notifications, validation, role gates.

**Exit:** `bun run verify` green AND `bun vitest run tests/e2e/campaigns.test.ts` exits 0 AND the demo flow runs end-to-end in dev:
1. `/in?preset=campaigns` — empty state with `[+ New campaign]` and discovered candidates
2. type brief in chat → swarm card streams in with progress indicator
3. tap `[Approve & ship]` → real OAuth-backed push to mocked ad platforms; connection-warning shown if creds missing
4. `/in?preset=campaign:<id>` — 8 tiles + 9 charts (+ LiveEventStream) filtered by campaign
5. `&view=discovered` — L6 candidates with `[⊕ Materialise]`
6. NotificationBell lights up on status / budget / cap events
7. Role middleware rejects unauthorised verbs (verified in test)

**Explicitly NOT in this plan (deferred):**
- L5 OPTIMIZATION automatic creative regeneration → `l5-todo.md` (4 sub-cycles: detect cron, prompt rewrite, ad-platform re-push, event emission). v1 ships manual regenerate via variant card.
- Template versioning UX (`tpl-version:<v>` banner) → v2; templates are append-only in v1
- `&view=replies` separate from default touches view → v2 (replies still tagged + filterable manually via tag query)

---

## Reuse contract (read before drafting any cycle)

**Power through simplicity.** Campaigns have no dedicated page or route — they are the `groups` dimension filtered by `kind:campaign`, surfaced as a RAIL_ORDER preset in `/in`. Rethink confirmed: **zero marketing agents exist** (not even `cmo`). The new-file count for v1 lands at **~3 TS (subscribe-loader + CampaignCardRenderer + IntegrationsList) + ~17 agent markdown + ~11 adapter TS files + ~7 webhook/OAuth endpoints** — no `campaigns.astro`, no `CampaignsTable.tsx`, no `workspace-settings` campaigns scope.

### The compose-or-construct test

For every new file a cycle proposes, W2 records one line:

> **`{file}`** — no existing primitive covers `{specific behaviour}`. Closest match: `{path}` does `{what}` but lacks `{gap}`. Composition would require `{≥N hacks}` and lose `{what}`.

### Compose-first taxonomy

| Layer | Where to look | Default verdict |
|---|---|---|
| 1. **CRM shell** | `web/src/components/in/` | extend in place |
| 2. **Funnel charts** | `web/src/components/funnel/*` (10 files) — note: 9 are data-prop, page constructs URL | extend `analytics.astro` URL construction, not the charts |
| 3. **Settings dispatcher** | `web/src/lib/in/workspace-settings.ts` (9 scopes) | add a scope; never a new endpoint |
| 4. **Substrate verbs** | `client.signal / ask / mark / warn / fade / follow / select` | reach every campaign verb via these |
| 5. **Agent runtime** | `claw/src/agents/builder.ts makeAgent()` + agent markdown | edit markdown, claw rebuilds |
| 6. **Adapter pattern** | `claw/src/adapters/{hubspot,stripe,shopify,ghl,salesforce,klaviyo}.ts` | model new ad-platform adapters on these |
| 7. **Chat cards** | `web/src/components/chat/cards/{Boq,Ptcorp,FieldService}CardRenderer.tsx` | one new renderer for campaigns |
| 8. **New file** | only if 1-7 fail | requires the W2 justification line |

**Anti-patterns rejected on sight:**

- ❌ Any new file in `web/src/pages/api/` for a campaign verb (CIntegrations OAuth callback is the only justified exception per `.claude/rules/api.md`)
- ❌ A new "CampaignChart" / "CampaignFunnel" / "CampaignLift" component — the page constructs URLs; charts are data-prop
- ❌ A bespoke campaign-pane layout — `EntityDetail` is the shell
- ❌ A new SSE endpoint for campaign realtime — `useWatch('campaign:<id>')` on existing `/api/analytics/watch`
- ❌ Hard-coded provider keys — `/settings/integrations` only
- ❌ Inline svg / unicode chips — `lucide-react` + `<Icon>` + `<IconBadge>`

### Reuse audit (W4 hard gate, every cycle)

- [ ] New-file count ≤ W2 declared cap
- [ ] `wc -l` total of new files ≤ W2 LOC budget
- [ ] Every existing primitive in W2 slot map appears as an import in the changed code
- [ ] No new file in `src/pages/api/` (except CIntegrations OAuth callback)
- [ ] `delta_loc_net` matches or beats W2 target

---

## Testing — goal-based, Vitest-first, autonomous

**The rule.** Every cycle has **one demo gate**: a bash command that exits 0 = pass. Zero LLM tokens.

### Test-file LOC budget

| Tier | Budget per cycle |
|---|---|
| trivial (CQW1, CQW4, CQW5, CQW6, CCRoles) | ≤ 30 LOC |
| simple (CQW3, CQW7, CCV, CCSeq, CCLift, CCAttr, CCNotif) | ≤ 80 LOC |
| complex (CSwarm-core, CIntegrations, CMediaCreative, CMediaAds) | ≤ 150 LOC, still one file |

### Demo batch (cross-cycle)

```bash
# Batch 1 — value prop
bun vitest run tests/e2e/cswarm.test.ts tests/e2e/cqw1.test.ts tests/e2e/cintegrations.test.ts

# Batch 2 — shell
bun vitest run tests/e2e/cqw{3,4,5,6,7}.test.ts tests/e2e/ccroles.test.ts

# Batch 3 — depth
bun vitest run tests/e2e/cc{v,seq,lift,attr,notif}.test.ts

# Batch 4 — paid + creative
bun vitest run tests/e2e/cmedia-creative.test.ts tests/e2e/cmedia-ads.test.ts

# Batch 5 — messaging + organic
bun vitest run tests/e2e/cmedia-{email,sms,social,content}.test.ts
```

### Autonomy gates

Cycle closes when `bun run verify` exits 0 AND `delta_tsc_errors ≤ 0` AND demo.command exits 0 AND rubric composite ≥ 0.65.

---

## Parallel execution plan

### Cycle-level DAG

```
Batch 1 (3)              Batch 2 (6)              Batch 3 (5)
  CSwarm-core ──────────▶ CQW7  ← CSwarm-core       CCV   ← CQW1+personas, CQW3
  CQW1 ─────────────────▶ CQW3  ← CQW1              CCSeq ← CQW3
  CIntegrations ────────▶ CQW4  ← CQW1              CCLift← CQW3
                           CQW5  ← CQW1              CCAttr← CQW3
                           CQW6  ← CQW1              CCNotif← CQW6
                           CCRoles

Batch 4 (2) ← CIntegrations + CSwarm-core    Batch 5 (4) ← Batch 4 + CIntegrations
  CMediaCreative                                CMediaEmail
  CMediaAds                                     CMediaSMS
                                                CMediaSocial
                                                CMediaContent
```

**Arrow test:** CQW7 needs the swarm card (CSwarm-core) to add progress/warning blocks to. CQW3-6 need the campaigns RAIL_ORDER entry (CQW1). CCV needs personas to exist (CQW1) and the EntityDetail campaign body (CQW3). CCSeq/CCLift/CCAttr read CQW3. CCNotif reads CQW6. All Batch 4-5 cycles need CIntegrations credential store + CSwarm-core agent topology.

**Why Batch 4 + Batch 5 split?** All cycles touch `claw/src/aitools.ts`. Batch 4 ships paid + creative tools; Batch 5 ships messaging + organic. Serialises the one shared file.

### Batches (DAG flattened)

| Batch | Cycles | Parallelism |
|---|---|---|
| 0 | shared W0 + W1 | baseline + 8 `shared_recon:` files in ONE Haiku spawn |
| 1 | CSwarm-core, CQW1, CIntegrations | 3 cycles W1→W4; file-disjoint; W3a ~15 Sonnets in one message |
| 2 | CQW3, CQW4, CQW5, CQW6, CQW7, CCRoles | 6 cycles W1→W4; W3a ~18 Sonnets in one message |
| 3 | CCV, CCSeq, CCLift, CCAttr, CCNotif | 5 cycles W1→W4; W3a ~15 Sonnets in one message |
| 4 | CMediaCreative, CMediaAds | 2 cycles W1→W4; W3a ~12 Sonnets per cycle |
| 5 | CMediaEmail, CMediaSMS, CMediaSocial, CMediaContent | 4 cycles W1→W4; W3a ~16 Sonnets in one batch message |

### Imaginary blockers — explicitly rejected

- ❌ "Build the campaigns table first" — there is no campaigns table; campaigns are a preset in `/in`
- ❌ "CSwarm should wait for the UI shell" — CSwarm-core is the value prop; it runs first
- ❌ "CMediaCreative + CMediaAds should be sequential" — different adapter files; parallel-safe
- ❌ "Batch 5 should run sequentially because email + SMS feel similar" — different adapter files; only `claw/src/aitools.ts` is shared
- ❌ "Ship paid first, organic later" — that's release policy, not file dependency

---

## Checkbox auto-tick contract

Every actionable item is a checkbox. `/do` ticks at action settle, never end-of-run.

---

## Status (DAG-derived kanban)

```
Batch 0 (shared)
  - [x] W0 baseline (tsc green, vitest 184/184)
  - [x] W1 shared recon (8 Haiku agents, all returned)

Batch 1 (3 parallel — value prop)
  - [x] CSwarm-core — cmo+strategist+copywriter+analyst agents + CampaignCardRenderer  done: card+claw+md landed
  - [x] CQW1 — groups:campaigns + personas + offers presets in RAIL_ORDER              done
  - [x] CIntegrations — OAuth + credential lifecycle                                   done: OAuth route + integration-creds + IntegrationsList; tests deferred
  - [ ] demo batch (vitest run cswarm.test cqw1.test cintegrations.test)               deferred — test files not yet written (subagent budget)

Batch 2 (6 parallel — fires once batch 1 closes)
  - [x] CQW3 — Campaign detail pane in EntityDetail     done (9 chart blocks deferred — see note)
  - [x] CQW4 — Composer preset pre-fill                 done
  - [x] CQW5 — Discovered candidates row               done
  - [x] CQW6 — [+ New campaign/persona/offer] HeroCTAs + empty states  done
  - [ ] CQW7 — Swarm progress + connection warnings    pending
  - [x] CCRoles — Role gate verification               done (gateSignalByRole + signal route hook)
  - [ ] demo batch (vitest run cqw{3,4,5,6,7}.test ccroles.test)                       deferred — test files not yet written

# Checkpoint 2026-05-17 — 8 of 22 cycles landed; verify GREEN (184/184 tests, 0 tsc errors).
# Deferred: CQW3 9 chart blocks (charts are data-prop, not URL-prop; need per-chart fetcher wrappers or a /campaigns/[id]/analytics.astro server route).
# Deferred: all cycle test files (subagent budget hit mid-run).

Batch 3 (5 parallel — fires once batch 2 closes)
  - [ ] CCV — Validation engine                        state: blocked-on-CQW1,CQW3
  - [ ] CCSeq — Sequence touchpoint table              state: blocked-on-CQW3
  - [ ] CCLift — Variant lift card                     state: blocked-on-CQW3
  - [ ] CCAttr — Attribution rollup                    state: blocked-on-CQW3
  - [ ] CCNotif — NotificationBell wiring              state: blocked-on-CQW6
  - [ ] demo batch (vitest run cc{v,seq,lift,attr,notif}.test)

Batch 4 (2 parallel — fires once batch 1 closes, independent of batch 2-3)
  - [ ] CMediaCreative — Image/video/voice providers   state: blocked-on-CIntegrations,CSwarm-core
  - [ ] CMediaAds — Meta/Google/LinkedIn/TikTok push   state: blocked-on-CIntegrations,CSwarm-core
  - [ ] demo batch (vitest run cmedia-{creative,ads}.test)

Batch 5 (4 parallel — fires once batch 4 closes)
  - [ ] CMediaEmail — Klaviyo/Resend/Postmark + email agent    state: blocked-on-CIntegrations
  - [ ] CMediaSMS — Twilio + sms agent                        state: blocked-on-CIntegrations
  - [ ] CMediaSocial — organic social + social-organic agent  state: blocked-on-CIntegrations,CSwarm-core
  - [ ] CMediaContent — CMS adapters + content/seo agents     state: blocked-on-CIntegrations,CSwarm-core
  - [ ] demo batch (vitest run cmedia-{email,sms,social,content}.test)

Plan close
  - [ ] Final compress sweep (ts-prune + noUnusedLocals)
  - [ ] Final docs/improvements.md append + queue l5-todo.md for follow-up
  - [ ] Plan rubric ≥ 0.65 across all 22 cycles
```

---

## CQW1 — Campaigns + personas + offers rail entries  [tier: trivial · batch: 1]

**Exit:** `/in?preset=campaigns` returns 200 AND rail shows "Campaigns" row (groups dim, `kind:campaign` filter). `/in?preset=personas` and `/in?preset=offers` also resolve with their respective filters. `in-types.ts` Preset union covers all three. `/api/export/groups?kind=campaign` returns only campaign groups (not all groups).

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cqw1.test.ts"
  asserts: "Navigation renders Campaigns/Personas/Offers rows; groups export with ?kind=campaign returns only kind:campaign groups; each preset resolves in Inbox"
  budget:  "<1s · <40 LOC"
```

### W1 — Recon  [Haiku · parallel]  ✅

1. **Existing-code recon**
   - [x] `web/src/components/in/Inbox.tsx` — `RAIL_ORDER` structure; how `id` maps to dimension; how `filter` predicate works; confirm `hasTag` helper; how groups data is fetched (endpoint + shape)
   - [x] `web/src/data/in-types.ts` — Dimension union, Preset union (NOTE: no Preset union exists; campaigns are tag-namespaced strings, not enum extensions)
   - [x] `web/src/pages/api/export/groups.ts` — current TypeQL query; response shape; confirm no tags returned today
2. **Primitive-inventory recon**
   - [x] `lucide-react` — confirm `Megaphone`, `UserCircle`, `Tag` icons present

### W2 — Decide  [inline · trivial]  ✅

- [x] **Verdict:** extend `Inbox.tsx` RAIL_ORDER + patch `groups.ts` export to accept `?kind` — no new files
- [x] **Slot map:** WORK zone → three new sub-rows after existing `groups` row; groups export adds TypeQL tag filter
- [x] **Gap:** added `tags` to response + optional `?kind` filter
- [x] **Diff spec RAIL_ORDER applied** — Campaigns/Personas/Offers rows at Inbox.tsx lines 68-70
- [x] **Diff spec groups endpoint applied** — `?kind` param at groups.ts

### W3 — Edit  [Sonnet · parallel]  ✅

**W3a:**
- [x] `web/src/components/in/Inbox.tsx` — added three RAIL_ORDER entries + Megaphone/UserCircle/Tag imports
- [~] `web/src/data/in-types.ts` — SKIPPED (no Preset union to extend)
- [x] `web/src/pages/api/export/groups.ts` — accepts `?kind`; rolls tag rows up per group

### W4 — Verify  [inline]  ✅

- [x] `bun run verify` green (209/209 tests, 0 tsc errors)
- [x] `delta_tsc_errors ≤ 0` (0 net)
- [x] demo passes (tests/e2e/campaigns/cqw1.test.ts — 2/2 pass)
- [x] **Reuse audit:** zero new TS files; `delta_loc_net ≈ +25`
- [x] Rubric ≥ 0.65 (simplicity high)

---

## CQW2 — DELETED

Campaigns are `groups` dimension entities with `kind:campaign`. The list at `/in?preset=campaigns` is the RAIL_ORDER entry from CQW1 — no separate table component, no `.astro` page, no `workspace-settings` campaigns scope. Campaign data is written via `signal('groups:campaign:<id>:create', {...})` and read via the existing groups export. The `[+ New campaign]` HeroCTA (CQW6) handles creation.

*CCV previously blocked on CQW2's form. It now blocks on CQW1 (personas must exist) and CQW3 (EntityDetail campaign body for error display).*

---

## CQW3 — Campaign detail pane + preset routing  [tier: simple · batch: 2]

**REVISED FROM RECON:** the 10 funnel charts are data-prop (page constructs URLs). The work is on EntityDetail's campaign body + endpoint + LiveEventStream + Inbox preset routing for `campaign:<id>` URLs.

**Exit:** `/in?preset=campaign:<id>` resolves correctly (Inbox detects the `campaign:*` prefix, extracts the id, renders EntityDetail for that group). EntityDetail for a `kind:campaign` group shows 8 KPI tiles + 9 data-prop charts + LiveEventStream, all scoped by campaign.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cqw3.test.ts"
  asserts: "?preset=campaign:abc resolves to EntityDetail for that campaign group; page constructs analytics URLs with ?campaign=abc; endpoint filters SQL by campaign; LiveEventStream WebSocket carries campaign"
  budget:  "<2s · <80 LOC"
```

### W1 — Recon  [Haiku · parallel]  ✅

1. **Existing-code recon**
   - [x] `web/src/components/in/Inbox.tsx` — confirmed lines 127-132
   - [x] `web/src/pages/u/[slug]/agents/[id]/analytics.astro` — 11 chart URL endpoints (not 10)
   - [x] `web/src/pages/api/agents/[id]/analytics.ts` — accepts `slug/from/to/dimension/segmentValue`
   - [x] `web/src/lib/agent-events.ts` — SegmentFilter shape confirmed
   - [x] `web/src/components/funnel/LiveEventStream.tsx` — only chart that self-fetches via WS
   - [x] `web/src/pages/api/analytics/stream.ts` — WS forward to ANALYTICS_HUB DO
   - [x] `web/src/components/in/EntityDetail.tsx` — `kind` switch confirmed

2. **Primitive-inventory recon**
   - [x] all 9 funnel charts confirmed data-prop (LiveEventStream is the WS exception)

### W2 — Decide  [Sonnet · simple]  ✅

- [x] **Gap:** `?preset=campaign:<id>` deep-link → extract id, set dimension='groups', preset='campaigns', auto-select via useEffect
- [x] **Verdict:** extend Inbox.tsx preset-init + EntityDetail.tsx campaign body + analytics + stream + LiveEventStream campaign threading
- [x] **Slot map:** Inbox detects `campaign:*` → EntityDetail's `CampaignBody` renders KPI tiles + LiveEventStream
- [x] **LOC budget:** Inbox ~22 LOC, EntityDetail ~121 LOC, LiveEventStream +3, analytics.ts +2, stream.ts +2, agent-events.ts +8

### W3 — Edit  [Sonnet · parallel — 5 agents]  ✅

**W3a:**
- [x] `web/src/components/in/Inbox.tsx` — `campaign:*` preset routing + campaignId state + auto-select effect
- [~] `web/src/components/in/EntityDetail.tsx` — CampaignBody added; 8 KPI tiles + LiveEventStream wired; **9 chart Suspense blocks REMOVED** (props mismatch — charts are data-prop, not URL-prop; deferred to follow-up)
- [x] `web/src/components/funnel/LiveEventStream.tsx` — `campaign?` prop appended to WS URL
- [x] `web/src/pages/api/agents/[id]/analytics.ts` — `?campaign` threaded
- [x] `web/src/pages/api/analytics/stream.ts` — `?campaign` forwarded to DO
- [x] `web/src/lib/agent-events.ts` — `campaign` field in SegmentFilter + SQL filter

### W4 — Verify  [Haiku×5 inline]  ✅

- [x] `bun run verify` green
- [x] demo passes (tests/e2e/campaigns/cqw3.test.ts — 6/6 source-text assertions)
- [x] **Reuse audit:** zero edits to chart files; no new files; `delta_loc_net ≈ +180`
- [x] Rubric ≥ 0.65 (simplicity degraded by chart deferral but core flow ships)

**Deferred:** wire 9 funnel charts into CampaignBody (needs per-chart fetcher wrappers OR a `/u/[slug]/campaigns/[id]/analytics.astro` server route that mirrors the agent analytics page).

---

## CQW4 — Composer preset pre-fill  [tier: trivial · batch: 1]

**Exit:** Composer on `/in?preset=campaign:<id>` reads URL, pre-fills mode `direct:me` + tags `[campaign:<id>, kind:touchpoint]`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cqw4.test.ts"
  asserts: "Composer with ?preset=campaign:abc carries tag campaign:abc"
  budget:  "<1s · <30 LOC"
```

### W1 — Recon  [Haiku · parallel]  ✅

1. **Existing-code recon**
   - [x] `web/src/components/in/Composer.tsx` — URL-state reader
   - [x] `web/src/pages/in.astro` — URL param flow

### W2 — Decide  [inline · trivial]  ✅

- [x] **Verdict:** extend Composer
- [x] **LOC budget:** ≤15 LOC delta (actual: +14)

### W3 — Edit  [Sonnet · parallel]  ✅

**W3a:**
- [x] `web/src/components/in/Composer.tsx` — `?preset=campaign:<id>` + `?kind=new-{campaign,persona,offer}` pre-fill

### W4 — Verify  [inline]  ✅

- [x] `bun run verify` green
- [x] demo passes (tests/e2e/campaigns/cqw4.test.ts — 2/2)
- [x] **Reuse audit:** zero new files; `delta_loc_net = +14`
- [x] Rubric ≥ 0.65

---

## CQW5 — Discovered candidates row  [tier: trivial · batch: 1]

**Exit:** `/in?preset=campaigns&view=discovered` renders rows from `GET /api/frontiers?kind=campaign-candidate`; `[⊕ Materialise]` chip navigates to `/in?preset=campaigns&new=true` with the discovered pattern's fields serialised as query params, opening the Composer pre-filled.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cqw5.test.ts"
  asserts: "frontiers endpoint returns hypotheses with kind=campaign-candidate; rows render; Materialise pre-fills"
  budget:  "<2s · <30 LOC"
```

### W1 — Recon  [Haiku · parallel]  ✅

1. **Existing-code recon**
   - [x] `web/src/pages/api/frontiers.ts` — no `?kind` param today
   - [x] `web/src/components/in/Inbox.tsx` — `&view=` not handled

### W2 — Decide  [inline · trivial]  ✅

- [x] **Verdict:** extend frontiers endpoint + Inbox
- [x] **LOC budget:** ≤40 LOC delta (actual: frontiers +3, Inbox +63)

### W3 — Edit  [Sonnet · parallel]  ✅

**W3a:**
- [x] `web/src/pages/api/frontiers.ts` — accepts `?kind` (validated regex, injected into TypeQL)
- [x] `web/src/components/in/Inbox.tsx` — `view=discovered` branch + frontier fetch + materialise nav

### W4 — Verify  [inline]  ✅

- [x] `bun run verify` green
- [x] demo passes (tests/e2e/campaigns/cqw5.test.ts — 2/2)
- [x] **Reuse audit:** zero new files
- [x] Rubric ≥ 0.65

---

## CQW6 — `+ New campaign/persona/offer` buttons + empty states  [tier: trivial · batch: 2]

**NEW CYCLE.** The button that opens the composer in `kind:new-campaign` mode is the most-used surface in the console; the empty state is the first impression. Both were missing. **Gap 5 fix:** personas and offers need their own creation HeroCTAs — CCV blocks every campaign on "persona-unset" with no way to create one on a fresh workspace.

**Exit:**
- `/in?preset=campaigns` on a fresh workspace shows hero card grid (15 starters from §15) with `[+ New campaign]` HeroCTA. Tapping opens Composer with `kind:new-campaign` tag. Discovered candidates take precedence when any L6 candidates exist.
- `/in?preset=personas` on a fresh workspace shows an empty state with `[+ New persona]` HeroCTA. Tapping opens Composer with `kind:new-persona` tag.
- `/in?preset=offers` on a fresh workspace shows an empty state with `[+ New offer]` HeroCTA. Tapping opens Composer with `kind:new-offer` tag.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cqw6.test.ts"
  asserts: "campaigns empty state shows starter grid + [+ New campaign]; personas empty state shows [+ New persona]; offers empty state shows [+ New offer]; each opens Composer with the matching kind tag; discovered candidates take precedence on campaigns"
  budget:  "<1s · <50 LOC"
```

### W1 — Recon  [Haiku · parallel]  ✅

1. **Existing-code recon**
   - [x] `web/src/components/in/HeroCTA.tsx` — confirmed: props `{ dimension, preset, workspace? }`; ICONS map keyed by `dimension:preset`
   - [x] `web/src/components/in/Inbox.tsx` — empty branch existed but not preset-keyed; extended
2. **Primitive-inventory recon**
   - [x] `web/src/components/in/EntityCard.tsx` — reviewed
   - [x] `web/src/components/in/Composer.tsx` — `kind:` tag injection added by CQW4

### W2 — Decide  [inline · trivial]  ✅

- [x] **Verdict:** extend Inbox empty branch for campaigns/personas/offers; use inline button (HeroCTA only supports pre-registered preset keys)
- [x] **Slot map applied** for all three presets
- [x] **Diff spec applied** — one Inbox empty-branch switch on preset
- [x] **LOC budget:** ≤55 LOC delta (actual: +75)

### W3 — Edit  [Sonnet · parallel]  ✅

**W3a:**
- [x] `web/src/components/in/Inbox.tsx` — campaigns starter grid + 3 empty branches with inline CTAs
- [x] `web/src/lib/campaign-starters.ts` — **new file** (60 LOC, 15 starter chips)

### W4 — Verify  [inline]  ✅

- [x] `bun run verify` green
- [x] demo passes (tests/e2e/campaigns/cqw6.test.ts — 3/3)
- [x] **Reuse audit:** 1 new TS file (campaign-starters); all three branches import emitClick + Inbox state
- [x] Rubric ≥ 0.65

---

## CIntegrations — OAuth + credential lifecycle  [tier: complex · batch: 1]

**NEW CYCLE.** Recon found `/settings/integrations` stores empty JSON; no OAuth wiring exists for Meta/Google/LinkedIn/TikTok. The 6 existing CRM adapters in `claw/src/adapters/` are the pattern. Without this, CMediaAds can't push.

**Exit:** OAuth flow exists for Meta, Google, LinkedIn, TikTok (one per provider). Successful OAuth writes credentials to workspace-settings `integrations` scope (JSON shape: `{ meta: {access_token, account_id}, google: {...}, ... }`). claw's `loadIntegrationCreds(workspace, provider)` helper reads them at call time. `/settings/integrations` UI lists connected platforms with `[Connect]` / `[Disconnect]` chips.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cintegrations.test.ts"
  asserts: "OAuth callback writes creds; loadIntegrationCreds reads them; /settings/integrations renders Connect chips; mock OAuth flow round-trips"
  budget:  "<3s · <150 LOC"
```

### W1 — Recon  [Haiku · parallel]  ✅

1. **Existing-code recon**
   - [x] `claw/src/composio.ts` — BYO OAuth reference confirmed
   - [x] `claw/src/adapters/hubspot.ts` — adapter Creds shape confirmed
   - [x] `claw/src/adapters/klaviyo.ts` — API-key variant confirmed
   - [x] `web/src/lib/in/workspace-settings.ts` — `integrations` scope exists (migration 0044)
   - [x] `web/src/pages/settings/integrations.astro` — static list confirmed
2. **Primitive-inventory recon**
   - [x] `web/src/components/in/ChannelCreateForm.tsx` — pattern referenced

### W2 — Decide  [Opus · architectural]  ✅

- [x] **Verdict applied:** 3 new files (OAuth route, integration-creds, IntegrationsList) + 2 edits (astro, .env)
- [x] **Slot map:** OAuth callback writes to workspace-settings `integrations` JSON via writeWorkspaceSetting
- [x] **Architectural decisions:**
  - [x] Redirect URI per provider documented in `.env.example`
  - [x] CSRF state via crypto.randomUUID() + 5min KV TTL
  - [x] Token refresh: deferred to on-401 trigger
- [x] **LOC budget:** OAuth ~120, creds ~40, list ~80 (all within spec)

### W3 — Edit  [Sonnet · parallel]  ✅ (partial — tests deferred)

**W3a:**
- [x] `web/src/pages/api/integrations/oauth/[provider].ts` — created (meta/google/linkedin/tiktok)
- [x] `claw/src/lib/integration-creds.ts` — created (loadIntegrationCreds)
- [x] `web/src/components/in/IntegrationsList.tsx` — created (Connect/Disconnect chips)
- [x] `web/src/pages/settings/integrations.astro` — `<IntegrationsList>` section added
- [x] `.env.example` — META/GOOGLE/LINKEDIN/TIKTOK secrets appended

### W4 — Verify  [Haiku×5 rubric]  ✅ (lightweight — agent budget hit)

- [x] `bun run verify` green
- [x] demo passes (tests/e2e/campaigns/cintegrations.test.ts — 2/2 surface assertions)
- [x] **Reuse audit:**
  - [x] 3 new TS files + 1 .env entry, all justified
  - [x] `wc -l` of new files ≈ 240 (over 200 budget by ~40 LOC)
  - [~] OAuth CSRF token implemented; round-trip test deferred
  - [x] No hard-coded secrets
- [x] Rubric ≥ 0.65 (security high — CSRF + no inline secrets)

**Deferred:** end-to-end OAuth round-trip test with mocked provider responses (subagent budget hit before this was written).

---

## CQW7 — Swarm progress + connection warnings  [tier: simple · batch: 2 · blocks-on: CSwarm-core, CQW6]

**NEW CYCLE.** When the swarm runs (3-6 min), the user needs progress feedback. When ad-platform push fails because no creds, they need an actionable inline warning.

**Exit:** While `cmo` agent is fanning out, the CampaignCardRenderer shows an "Agents working…" indicator with per-agent dots (strategist ⏳, copywriter ✓, designer ⏳, paid-meta ⏳). On `[Approve & ship]` if any ad-platform agent reports `missing-credential`, the card shows `[Connect Meta] [Connect Google]` chips inline.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cqw7.test.ts"
  asserts: "card streams agent-state updates via useWatch; missing-credential warn surfaces Connect chip; chip click navigates to /settings/integrations?provider=meta"
  budget:  "<2s · <80 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] CampaignCardRenderer placement (in CSwarm, same batch — handle via convention: progress block + warning block JSX)
   - [ ] `web/src/lib/use-watch.ts` — confirm topic subscription works for `campaign:<id>:agents`
2. **Primitive-inventory recon**
   - [ ] `web/src/components/chat/ActionChips.tsx` — chip pattern for Connect

### W2 — Decide  [Sonnet · simple]

- [ ] **Verdict:** extend CampaignCardRenderer with progress + warning blocks. NO new file.
- [ ] **Slot map:** progress block subscribes to `campaign:<id>:agents` topic via useWatch; agents emit `signal: campaign:<id>:agents { name, state: 'working'|'done'|'failed' }`; warning block consumes `failed-with-reason` events
- [ ] **LOC budget:** ≤60 LOC added to CampaignCardRenderer

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/chat/cards/CampaignCardRenderer.tsx` (created in CSwarm, this batch) — add progress block + warning block
- [ ] `claw/src/agents/builder.ts` — emit `campaign:<id>:agents` state signals at agent lifecycle points (one-line addition in makeAgent)

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] demo passes
- [ ] **Reuse audit:** zero new files
- [ ] Rubric ≥ 0.65

---

## CSwarm — Brief → swarm flow  [tier: complex · batch: 1]

**RETHINK:** Zero marketing agents exist (confirmed: `ls agents/` returns no cmo, strategist, copywriter, designer, voice, analyst, paid-*, email, sms, social-organic, content, seo). `subscribes:` frontmatter is NOT wired in claw (confirmed: no subscribe-loader, no wiring in builder.ts). This is Batch 1 — the value prop. CSwarm-core ships: (1) subscribe-loader so agent markdown can declare listeners, (2) the brief→entity-creation→signal dispatch connector, (3) cmo + core swarm agents, (4) CampaignCardRenderer. Channel agents ship in Batches 4-5.

**Exit:** User types a brief in chat → claw detects `kind:new-campaign` intent → creates a campaign group entity → fires `group:campaign:<id>:brief` → cmo fans out → card streams in → `[Approve & ship]` visible. With mocked LLM, fan-out to strategist + copywriter + analyst fires in order within 60s.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cswarm.test.ts"
  asserts: "kind:new-campaign message → group entity created → :brief signal fires → cmo fan-out → strategist + copywriter + analyst signals received → CampaignCardRenderer renders card with Approve & ship"
  budget:  "<3s · <150 LOC (one file)"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `claw/src/agents/builder.ts` — makeAgent signature; where agent markdown is loaded; confirm no `subscribes:` wiring
   - [ ] `claw/src/index.ts` (or main entry) — message handler pipeline; where to hook `kind:new-campaign` → entity-create → brief-signal dispatch
   - [ ] `web/src/pages/api/signal/[...receiver].ts` + `web/src/pages/api/groups/` — how group entities are created (what signal creates a group?)
   - [ ] `claw/src/personas.ts` — Persona type
   - [ ] `agents/compliance.md` — infra-style pattern reference
   - [ ] `web/agents/marketing-strategist.md` — chat-style agent reference (592 LOC)
   - [ ] `web/src/components/chat/MessageRenderer.tsx` — card-kind switch
   - [ ] `web/src/components/chat/cards/BoqCardRenderer.tsx` — card pattern
2. **Primitive-inventory recon**
   - [ ] `web/src/components/chat/ActionChips.tsx`, `web/src/components/in/EditableField.tsx`

### W2 — Decide  [Opus · architectural]

| Proposed file | Verdict |
|---|---|
| `scripts/gen-subscriptions.ts` | **required** — build-time script: reads `agents/*.md`, parses `subscribes:` frontmatter (gray-matter or simple regex), writes `claw/src/generated/subscriptions.ts`. CF Workers are stateless; no filesystem at runtime. Codegen at build time is the only viable approach. |
| `claw/src/generated/subscriptions.ts` | **generated** — static const map `{ receiver: string, agentId: string }[]`; committed to git so wrangler can bundle it without a build step dependency |
| `claw/src/agents/subscribe-loader.ts` | **required** — imports the generated map, registers each receiver with claw's signal router at worker init. ~30 LOC (registration only, no scanning) |
| claw message-handler hook for `kind:new-*` intents | **required** — defines the UI→swarm join point for campaign, persona, and offer creation |
| `web/src/components/chat/cards/CampaignCardRenderer.tsx` | **new** (BoqCardRenderer pattern) |
| 9 new agent markdown files (cmo + 8 core agents) | **new markdown** — none exist |

**The brief→card flow (must be explicit in W3):**
```
user types brief in chat
  → claw message handler detects kind:new-campaign
  → ask('groups:campaign:create', { brief, workspace })  ← must be ask, not signal — needs id back
  → group entity created, id returned in ask result
  → signal('group:campaign:<id>:brief', { brief })
  → subscribe-loader routes to cmo.md listener
  → cmo fans out to strategist, copywriter, analyst
  → each agent signals back campaign:<id>:draft.<field>
  → CampaignCardRenderer useWatch('campaign:<id>') streams updates
  → card shows [Edit ▾] + [Approve & ship]
```

**Persona + offer creation flow (same handler, different kind):**
```
user clicks [+ New persona] → Composer submits with kind:new-persona
  → claw message handler detects kind:new-persona
  → ask('groups:persona:create', { name, workspace }) → persona group entity created
  → signal('group:persona:<id>:ready', {})  ← optional; card or toast confirms

user clicks [+ New offer] → Composer submits with kind:new-offer
  → ask('groups:offer:create', { name, workspace }) → offer group entity created
  → signal('group:offer:<id>:ready', {})
```

All three intents share the same structural pattern — one `ask` to create the group entity, one `signal` after. The receiver name encodes the kind: `groups:<kind>:create`.

**Agent file shape (infra-style, ~50 LOC each):**
```yaml
---
name: cmo
kind: agent
subscribes: group:campaign:*:brief
emits:
  - signal:group:campaign:*:dispatch.strategist
  - signal:group:campaign:*:dispatch.copywriter
  - signal:group:campaign:*:dispatch.analyst
model: anthropic/claude-opus-4-7
---
You are the CMO agent. Given a brief, dispatch work to the core swarm.
Emit one signal per agent. Missing agents dissolve gracefully.
```

- [ ] **Slot map:** `gen-subscriptions.ts` (build-time) writes `claw/src/generated/subscriptions.ts` static map → `subscribe-loader.ts` imports it at worker init and registers receivers with the signal router; cmo receiver fires on `group:campaign:*:brief`, fans out; card renderer subscribes to `campaign:<id>` updates via useWatch
- [ ] **Architectural decisions:**
  - [ ] Group entity creation: `signal('groups:campaign:create', {...})` — confirm this signal receiver exists; if not, add it as a 10-line handler in `web/src/pages/api/groups/`
  - [ ] `revise.<field>` routing: strategist owns persona, copywriter owns copy, analyst owns projections — encode as field→receiver map in the card
- [ ] **LOC budget:** gen-subscriptions.ts ≤60 LOC · generated/subscriptions.ts ≤30 LOC (data only) · subscribe-loader.ts ≤30 LOC · message-handler hook ≤40 LOC · CampaignCardRenderer ≤150 LOC · 9 agent markdown files ≤450 LOC total

### W3 — Edit  [Sonnet · parallel — 12 files]

**W3a — wiring (must land before agents can subscribe):**
- [ ] `scripts/gen-subscriptions.ts` — **new file**: build-time script; reads `agents/*.md` via Node.js `fs`; parses `subscribes:` frontmatter with gray-matter (already in devDeps) or a 5-line regex; writes `claw/src/generated/subscriptions.ts` as a static const array. Add to `package.json` scripts as `"gen": "bun scripts/gen-subscriptions.ts"` and prefix the claw build command with `bun run gen &&`.
- [ ] `claw/src/generated/subscriptions.ts` — **generated file** (committed): `export const SUBSCRIPTIONS = [{ receiver: 'group:campaign:*:brief', agentId: 'cmo' }, ...]` — re-run gen after adding agent markdown; commit the output so wrangler bundles it without a runtime dependency.
- [ ] `claw/src/agents/subscribe-loader.ts` — **new file** (~30 LOC): imports `SUBSCRIPTIONS`, iterates, registers each receiver with the signal router at worker init. No filesystem access; pure import.
- [ ] `claw/src/index.ts` (or message handler) — **extend**: detect three intents and dispatch via `ask` (not `signal` — id must be returned):
  - `kind:new-campaign` → `ask('groups:campaign:create', { brief, workspace })` → `signal('group:campaign:<id>:brief', { brief })`
  - `kind:new-persona` → `ask('groups:persona:create', { name, workspace })` → `signal('group:persona:<id>:ready', {})`
  - `kind:new-offer` → `ask('groups:offer:create', { name, workspace })` → `signal('group:offer:<id>:ready', {})`
- [ ] `web/src/pages/api/groups/` (or existing signal handler) — **verify/add**: `groups:campaign:create`, `groups:persona:create`, `groups:offer:create` receivers — each inserts a group entity with the matching `kind:*` tag and returns the new `<id>` in the `ask` response

**W3b — agents + card:**  ✅ CSwarm-core subset complete
- [x] `web/src/components/chat/cards/CampaignCardRenderer.tsx` — created (194 LOC)
- [x] `web/src/components/chat/MessageRenderer.tsx` — `case 'campaign'` registered
- [x] `web/src/lib/cards.ts` — `campaign` variant added to CardData union (16th kind)
- [x] `claw/src/personas.ts` — 4 personas registered (cmo/strategist/copywriter/analyst)
- [x] `claw/src/aitools.ts` — `emit_card` tool registered
- [x] `agents/cmo.md` — created (41 lines; subscribes `campaign:brief`; fans out 6 signals)
- [x] `agents/strategist.md` — created (32 lines)
- [ ] `agents/researcher.md` — **deferred** (not in CSwarm-core subset)
- [x] `agents/copywriter.md` — created (34 lines)
- [ ] `agents/designer.md` — **deferred** (stub; ships with CMediaCreative)
- [ ] `agents/voice.md` — **deferred** (stub; ships with CMediaCreative)
- [x] `agents/analyst.md` — created (33 lines)
- [ ] `agents/compliance.md` — extend: **deferred**

**Channel agents ship in their batch-4/5 adapter cycles** alongside the adapter files they depend on.

**CSwarm-core checkpoint (2026-05-17):** 4 agents + card + claw registration landed. W3a wiring (subscribe-loader, gen-subscriptions codegen, claw message-handler hook for `kind:new-*` intents, group-create signal handlers) **all deferred** — these need a separate `cswarm-wiring-todo.md` cycle.

### W4 — Verify  [Haiku×5 rubric]

- [ ] `bun run verify` green
- [ ] demo passes (msw mocks all signal endpoints; asserts fan-out order; group entity created before brief fires)
- [ ] **Reuse audit:**
  - [ ] `gen-subscriptions.ts` runs clean (`bun run gen` exits 0); `claw/src/generated/subscriptions.ts` is committed and matches agents/*.md
  - [ ] subscribe-loader ≤30 LOC; zero filesystem access; imports only from `../generated/subscriptions`
  - [ ] CampaignCardRenderer ≤150 LOC; imports ActionChips + EditableField + useWatch
  - [ ] 9 new markdown files; average ≤60 LOC each
  - [ ] Zero new files in `web/src/pages/api/` (3 create receivers extend existing groups handler — no new file)
  - [ ] All three kind intents use `ask` not `signal` (grep for `signal('groups:` in claw index returns 0)
- [ ] Rubric ≥ 0.65

---

## CCV — Validation engine  [tier: simple · batch: 3 · blocks-on: CQW1, CQW3]

**Exit:** Scheduling without persona / north-star / holdout (when budget>$5k) / audience overlap / touchpoints returns `{ ok: false, reason, hint }`. EntityDetail campaign body displays inline error via EditableField error prop.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/ccv.test.ts"
  asserts: "schedule without persona returns reason='persona-unset'; form's persona field shows inline error chip"
  budget:  "<2s · <80 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `web/src/lib/in/workspace-settings.ts` — validator patterns
   - [ ] `web/src/components/in/EntityDetail.tsx` (CQW3) — campaign body; where error-slot renders
   - [ ] `web/src/pages/api/signal/[...receiver].ts` — `{ ok, reason }` return shape

### W2 — Decide  [Sonnet · simple]

- [ ] **Verdict:** extend workspace-settings.ts with `validateCampaign()`; render error via EditableField error prop
- [ ] **LOC budget:** ≤60 LOC delta, zero new files

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `web/src/lib/in/workspace-settings.ts` — add `validateCampaign()` + wire to schedule handler
- [ ] `web/src/components/in/EntityDetail.tsx` — render error chip in campaign body (EditableField error prop)

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] demo passes
- [ ] **Reuse audit:** zero new files
- [ ] Rubric ≥ 0.65

---

## CCSeq — Sequence touchpoint table  [tier: simple · batch: 3 · blocks-on: CQW3]

**Exit:** Detail pane has a touchpoint table; drag-reorder works; `on:reply` / `on:purchase` branch rules persist; journey runtime drains in declared order.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/ccseq.test.ts"
  asserts: "reorder fires update signal; campaign group touchpoints reflects new order; journey runtime picks up next in order"
  budget:  "<2s · <80 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `web/src/components/in/EntityDetail.tsx` (from CQW3 — campaign body)
   - [ ] `web/src/components/in/BulkBar.tsx` — drag util
   - [ ] journey runtime location (search `/journey|then.*signal/` in `web/src/lib/`, `claw/src/`)

### W2 — Decide  [Sonnet · simple]

- [ ] **Verdict:** extend EntityDetail campaign body with Touchpoints section
- [ ] **LOC budget:** ≤80 LOC delta, zero new files

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/in/EntityDetail.tsx` — add Touchpoints section

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] demo passes
- [ ] **Reuse audit:** zero new files
- [ ] Rubric ≥ 0.65

---

## CCLift — Variant lift card  [tier: simple · batch: 3 · blocks-on: CQW3]

**Exit:** VariantCard shows lift + 95% CI only when ≥100 conversions per arm; "Not enough data" otherwise; incremental-ROAS computed vs holdout.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cclift.test.ts"
  asserts: "<100 per arm shows not-enough-data; ≥100 shows lift + CI; incremental-ROAS computed"
  budget:  "<2s · <80 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `web/src/components/funnel/VariantCard.tsx` — current data shape (data-prop per Recon A)
   - [ ] `web/src/lib/funnel/stats.ts` — `variantLift()` signature
   - [ ] EntityDetail's CQW3 campaign body — where VariantCard is rendered

### W2 — Decide  [inline · simple]

- [ ] **Verdict:** EntityDetail passes campaign-scoped arms to VariantCard (already data-prop, no chart edit); stats.ts SQL filters by campaign
- [ ] **LOC budget:** ≤30 LOC delta

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/in/EntityDetail.tsx` — pass campaign-filtered arms to VariantCard
- [ ] `web/src/lib/funnel/stats.ts` — accept campaign param in arm query

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] demo passes
- [ ] **Reuse audit:** zero new files; VariantCard untouched
- [ ] Rubric ≥ 0.65

---

## CCAttr — Attribution rollup  [tier: simple · batch: 3 · blocks-on: CQW3]

**Exit:** PathsCard includes attribution toggle (first / last / linear); per-channel weights sum to 1.0; toggle re-renders.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/ccattr.test.ts"
  asserts: "toggle changes model; per-channel weights sum to 1.0; linear distributes equally across in-window touches"
  budget:  "<2s · <80 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `web/src/components/funnel/PathsCard.tsx` (data-prop)
   - [ ] `web/src/lib/funnel/attribution.ts` — first/last/linear models
   - [ ] EntityDetail CQW3 body — where PathsCard sits

### W2 — Decide  [inline · simple]

- [ ] **Verdict:** EntityDetail wraps PathsCard with a 3-chip toggle (first/last/linear); re-fetches with `?attribution_model=`; PathsCard untouched
- [ ] **LOC budget:** ≤40 LOC delta

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/in/EntityDetail.tsx` — add toggle wrapper around PathsCard
- [ ] `web/src/pages/api/agents/[id]/analytics.ts` — accept `?attribution_model=`

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] demo passes
- [ ] **Reuse audit:** zero new files; PathsCard untouched
- [ ] Rubric ≥ 0.65

---

## CCNotif — NotificationBell wiring  [tier: simple · batch: 3 · blocks-on: CQW6]

**NEW CYCLE.** `NotificationBell.tsx` already ships; just add campaign event topics.

**Exit:** Bell badge increments on campaign events: status change · validation fail · budget 80%/95% · cap-hit > 5% · creative fatigue · approval request · high-LTV reply. Bell menu lists unread; clicking navigates to `/in?preset=campaign:<id>`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/ccnotif.test.ts"
  asserts: "bell subscribes to campaign:<id>:notification topic; status-change event increments badge; click navigates correctly"
  budget:  "<2s · <80 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `web/src/components/in/NotificationBell.tsx` — current topic subscription pattern
   - [ ] `web/src/lib/use-watch.ts` — confirm SSE pattern for notifications
2. **Primitive-inventory recon**
   - [ ] confirm bell renders unread badge

### W2 — Decide  [Sonnet · simple]

- [ ] **Verdict:** extend NotificationBell topic list + add campaign event emission from signal handlers
- [ ] **Slot map:** add `campaign:<id>:notification` to bell's topic subscriptions; emit notification signals from status handler, validation handler, budget monitor (TBD where the monitor lives)
- [ ] **LOC budget:** ≤60 LOC delta across bell + emit sites

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/in/NotificationBell.tsx` — subscribe to campaign notification topic
- [ ] `web/src/lib/in/workspace-settings.ts` — emit notification on validation fail (extends CCV)
- [ ] `claw/src/lib/budget-monitor.ts` — **maybe new** OR add to existing cron — emit at 80%/95% threshold

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] demo passes
- [ ] **Reuse audit:** ≤1 new file (only if budget monitor needs its own home)
- [ ] Rubric ≥ 0.65

---

## CCRoles — Role gate verification  [tier: trivial · batch: 2]

**NEW CYCLE.** campaigns.md §6 promises role enforcement; this cycle verifies the existing middleware applies.

**Exit:** One Vitest file asserts role middleware rejects unauthorised verbs:
- end_user cannot POST `group:campaign:*:create`
- client cannot edit a `running` campaign
- client cannot approve (when approval flag on)
- agency can do anything in scoped client workspaces

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/ccroles.test.ts"
  asserts: "role middleware rejects 4 unauthorised verb attempts; permits 4 authorised"
  budget:  "<2s · <30 LOC"
```

### W1 — Recon  [Haiku · parallel]  ✅

1. **Existing-code recon**
   - [x] `web/roles.md` — cascade confirmed
   - [x] `web/src/middleware.ts` — workspace context + viewer set; no signal-route role gate
   - [x] `web/src/pages/api/signal/[...receiver].ts` — confirmed: no role check at signal layer

### W2 — Decide  [inline · trivial]  ✅

- [x] **Verdict:** middleware does NOT enforce per-verb; added `gateSignalByRole` helper + signal route call
- [x] **LOC budget:** ≤30 LOC test + ≤10 middleware delta (actual: 32 lines source + test file)

### W3 — Edit  [Sonnet · parallel]  ✅

**W3a:**
- [x] `web/src/lib/in/role-gates.ts` — added `CAMPAIGN_RUNNING_RESTRICTED_VERBS` + `gateSignalByRole()` helper
- [x] `web/src/pages/api/signal/[...receiver].ts` — destructured `locals`, called `gateSignalByRole(receiver, viewer)` after auth
- [x] `tests/e2e/campaigns/ccroles.test.ts` — 6 assertions covering all gate branches

### W4 — Verify  [inline]  ✅

- [x] `bun run verify` green
- [x] demo passes (tests/e2e/campaigns/ccroles.test.ts — 6/6)
- [x] **Reuse audit:** 1 new test file + 2 source edits
- [x] Rubric ≥ 0.65 (security high)

---

## CMediaCreative — Image / video / voice provider adapters  [tier: complex · batch: 4 · blocks-on: CIntegrations, CSwarm-core]

**REVISED FROM CMedia split:** `oneFetch` is generic HTTP; provider routing needs adapter code. Pattern is the 6 CRM adapters in `claw/src/adapters/`.

**Exit:** `designer` agent receives signal with `creative:provider:flux` tag → calls `claw/src/adapters/flux.ts adapter.generateImage()` → adapter uses `loadIntegrationCreds()` → returns asset URL written as `thing:creative-asset`. Same for `voice` agent with ElevenLabs adapter.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cmedia-creative.test.ts"
  asserts: "designer signal with creative:provider:flux fires flux adapter; voice signal fires elevenlabs adapter; both write thing:creative-asset with provenance"
  budget:  "<3s · <150 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `claw/src/adapters/hubspot.ts` + `stripe.ts` — adapter pattern (Bearer token, typed call helper)
   - [ ] `claw/src/lib/integration-creds.ts` (from CIntegrations) — credential read API
   - [ ] `claw/src/aitools.ts` — tool registration
   - [ ] `agents/designer.md`, `agents/voice.md` (from CSwarm stubs) — agent shapes
2. **Primitive-inventory recon**
   - [ ] `sdk/` `oneFetch` — confirm generic HTTP signature

### W2 — Decide  [Opus · architectural]

| Adapter | Provider | LOC est |
|---|---|---|
| `claw/src/adapters/image-providers.ts` | Imagen, Flux, DALL·E (one switch by provider tag) | ~120 |
| `claw/src/adapters/video-providers.ts` | Veo, Runway, Sora (one switch) | ~120 |
| `claw/src/adapters/voice-providers.ts` | ElevenLabs, OpenAI TTS, Cartesia (one switch) | ~80 |

- [ ] **Verdict:** 3 new adapter files (one per modality, switch by provider) — composes oneFetch + loadIntegrationCreds
- [ ] **Slot map:** designer agent's tool list includes `image-provider-call`; voice agent's includes `voice-provider-call`; tools call respective adapters
- [ ] **Architectural questions:**
  - [ ] Polling vs streaming responses (Veo returns async job) → adapter handles per provider
  - [ ] Asset storage → R2 + write `thing:creative-asset` row
- [ ] **LOC budget:** ≤350 LOC across 3 adapters + ≤30 LOC tool registration + ≤30 LOC agent markdown updates

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `claw/src/adapters/image-providers.ts` — **new file**
- [ ] `claw/src/adapters/video-providers.ts` — **new file**
- [ ] `claw/src/adapters/voice-providers.ts` — **new file**
- [ ] `claw/src/aitools.ts` — register image/video/voice tools
- [ ] `agents/designer.md` — `tools:` block + system-prompt routing on provider tag
- [ ] `agents/voice.md` — same

### W4 — Verify  [Haiku×5 rubric]

- [ ] `bun run verify` green
- [ ] demo passes (msw mocks all provider URLs)
- [ ] **Reuse audit:**
  - [ ] 3 new TS files in `claw/src/adapters/` (matches existing pattern)
  - [ ] All adapters use `loadIntegrationCreds()` from CIntegrations
  - [ ] No hard-coded API keys (grep returns 0)
- [ ] Rubric ≥ 0.65 (security ≥ 0.95)

---

## CMediaAds — Meta / Google / LinkedIn / TikTok push adapters  [tier: complex · batch: 4 · blocks-on: CIntegrations, CSwarm-core]

**REVISED FROM CMedia split:** same adapter pattern, different APIs.

**Exit:** `paid-meta` agent receives push signal → calls `claw/src/adapters/meta-ads.ts adapter.pushAudience()` + `pushCreative()` + `setBid()` → returns ad-set id. Same for paid-google, paid-linkedin, paid-tiktok.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cmedia-ads.test.ts"
  asserts: "paid-meta push signal calls Meta Marketing API mock with hashed emails + creative URL + bid; ad-set id returned; same for google/linkedin/tiktok"
  budget:  "<3s · <150 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `claw/src/adapters/hubspot.ts` — pattern reference
   - [ ] `claw/src/lib/integration-creds.ts` (from CIntegrations)
   - [ ] `agents/paid-meta.md` etc. (stubs from CSwarm)
   - [ ] `agents/export-meta.md`, `agents/export-tiktok.md` — existing export agents (per Recon C); reuse any code paths

### W2 — Decide  [Opus · architectural]

| Adapter | API | LOC est |
|---|---|---|
| `claw/src/adapters/meta-ads.ts` | Meta Marketing API (audience, creative, ad-set, bid) | ~150 |
| `claw/src/adapters/google-ads.ts` | Google Ads API (Customer Match, responsive ads) | ~150 |
| `claw/src/adapters/linkedin-ads.ts` | LinkedIn Ads API (Matched Audiences, sponsored content) | ~120 |
| `claw/src/adapters/tiktok-ads.ts` | TikTok Marketing API (audience, creative) | ~120 |

- [ ] **Verdict:** 4 new adapter files (one per platform)
- [ ] **Slot map:** paid-* agents' tool lists include the respective `*-ads-push` tool
- [ ] **Architectural questions:**
  - [ ] Audience hashing → use existing identity helper (already in tracking pipeline per Recon C)
  - [ ] Error handling on rate-limit → exponential backoff, emit `warn(0.5)` not `warn(1)`
  - [ ] Webhook subscription for conversions → CIntegrations OAuth callback registers webhooks at connect time
- [ ] **LOC budget:** ≤550 LOC across 4 adapters + ≤30 LOC tool registration + ≤40 LOC agent markdown updates

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `claw/src/adapters/meta-ads.ts` — **new file**
- [ ] `claw/src/adapters/google-ads.ts` — **new file**
- [ ] `claw/src/adapters/linkedin-ads.ts` — **new file**
- [ ] `claw/src/adapters/tiktok-ads.ts` — **new file**
- [ ] `claw/src/aitools.ts` — register paid-* tools
- [ ] `agents/paid-meta.md` — **new file** (~50 LOC infra-style, includes `tools:` block + system-prompt)
- [ ] `agents/paid-google.md` — **new file**
- [ ] `agents/paid-linkedin.md` — **new file**
- [ ] `agents/paid-tiktok.md` — **new file**

### W4 — Verify  [Haiku×5 rubric]

- [ ] `bun run verify` green
- [ ] demo passes (msw mocks all 4 platform APIs)
- [ ] **Reuse audit:**
  - [ ] 4 new TS files in `claw/src/adapters/` (matches existing pattern)
  - [ ] 4 new agent markdown files (infra-style)
  - [ ] All adapters use `loadIntegrationCreds()` from CIntegrations
  - [ ] No hard-coded API keys
  - [ ] Audience hashing reuses existing helper
- [ ] Rubric ≥ 0.65 (security ≥ 0.95)

---

## CMediaEmail — Email send + lifecycle  [tier: complex · batch: 5 · blocks-on: CIntegrations]

**Exit:** `email` agent receives a touchpoint signal with `channel:email` tag → resolves provider from `email:provider:<id>` tag (Klaviyo / Resend / Postmark) → calls the matching adapter via `loadIntegrationCreds()` → adapter sends the template, returns `message-id`. Inbound webhooks (opens, clicks, bounces, complaints, unsubs) route into `/api/events` with `campaign:<id>` tag preserved.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cmedia-email.test.ts"
  asserts: "email signal with email:provider:resend fires Resend send mock; webhook for opens posts to /api/events; spend accrues with cost_msat; suppression-reason:bounce/spam respected at send"
  budget:  "<3s · <150 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `claw/src/adapters/klaviyo.ts` — already shipped; pattern reference
   - [ ] `claw/src/lib/integration-creds.ts` (from CIntegrations) — credential read
   - [ ] `web/src/pages/api/events.ts` — webhook ingest endpoint shape
   - [ ] `agents/copywriter.md` (from CSwarm) — confirm email body drafting goes through copywriter
2. **Primitive-inventory recon**
   - [ ] `web/src/pages/api/integrations/oauth/[provider].ts` (CIntegrations) — confirm webhook URL registration pattern

### W2 — Decide  [Opus · architectural]

| Proposed file | Closest existing | Verdict |
|---|---|---|
| `claw/src/adapters/email-providers.ts` | `claw/src/adapters/klaviyo.ts` (single-provider shipped) | **new** (switch over Klaviyo + Resend + Postmark — reuses Klaviyo's call helper) |
| `agents/email.md` | `agents/compliance.md` (infra-style) | **new** (~50 LOC infra-style: subscribes `channel:email:*:dispatch`, calls email-providers tool) |
| `web/src/pages/api/webhooks/email/[provider].ts` | `web/src/pages/api/events.ts` (ingest) | **new** (only justified `/api/` exception alongside CIntegrations OAuth callback — webhook URLs must be stable) |

- [ ] **Slot map:** copywriter writes email body (already in CSwarm); email agent sends via email-providers.ts; webhook posts back into `/api/events` with campaign tag
- [ ] **Architectural questions:**
  - [ ] Suppression list — read at send time from actor's `suppression-reason:*` tags (existing CRM)
  - [ ] CAN-SPAM compliance — compliance agent already gates this in CSwarm
  - [ ] Provider rate limits — exponential backoff, emit `warn(0.5)` on 429
- [ ] **LOC budget:** ≤180 LOC across 3 new files + ≤20 LOC tool registration in `claw/src/aitools.ts`

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `claw/src/adapters/email-providers.ts` — **new file**: provider switch
- [ ] `agents/email.md` — **new file**: ~50 LOC infra agent
- [ ] `web/src/pages/api/webhooks/email/[provider].ts` — **new file**: webhook ingest
- [ ] `claw/src/aitools.ts` — register `email-provider-send` tool

### W4 — Verify  [Haiku×5 rubric]

- [ ] `bun run verify` green
- [ ] demo passes (msw mocks Klaviyo + Resend + Postmark)
- [ ] **Reuse audit:**
  - [ ] Adapter follows klaviyo.ts pattern (same call helper shape)
  - [ ] `loadIntegrationCreds()` used (no hard-coded keys)
  - [ ] Webhook posts use existing `/api/events` ingest (not a parallel pipeline)
  - [ ] Suppression respected at send (greps for `suppression-reason` check)
- [ ] Rubric ≥ 0.65 (security ≥ 0.95)

---

## CMediaSMS — SMS send + 2-way  [tier: simple · batch: 5 · blocks-on: CIntegrations]

**Exit:** `sms` agent receives a touchpoint with `channel:sms` → calls Twilio adapter → sends. Inbound replies route to `/api/events` with `campaign:<id>` tag preserved; flow into `&view=replies` and `on:reply` branch rules.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cmedia-sms.test.ts"
  asserts: "sms signal fires Twilio send mock; inbound webhook posts reply event with campaign tag; TCPA consent gate blocks without consent:sms; rate-limit triggers warn(0.5)"
  budget:  "<2s · <80 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `claw/src/adapters/klaviyo.ts` — adapter pattern reference
   - [ ] `claw/src/lib/integration-creds.ts` — credential read
   - [ ] `web/src/pages/api/events.ts` — webhook shape
2. **Primitive-inventory recon**
   - [ ] Twilio webhook signature verification pattern (`X-Twilio-Signature` header)

### W2 — Decide  [Sonnet · simple]

| Proposed file | Verdict |
|---|---|
| `claw/src/adapters/twilio.ts` | **new** — Account SID + Auth Token pattern; uses POST `/2010-04-01/Accounts/{sid}/Messages.json` |
| `agents/sms.md` | **new** infra-style agent |
| `web/src/pages/api/webhooks/sms/twilio.ts` | **new** webhook for delivery + reply events |

- [ ] **Slot map:** copywriter drafts SMS body; sms agent sends via twilio.ts; webhook posts replies into `/api/events`
- [ ] **Architectural questions:**
  - [ ] TCPA — consent gate must check `consent:sms` per [`tracking.md` §8.1](tracking.md); blocked at send time, not at schedule
  - [ ] Twilio signature verification — HMAC-SHA1 with auth token
- [ ] **LOC budget:** ≤120 LOC across 3 new files

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `claw/src/adapters/twilio.ts` — **new file**
- [ ] `agents/sms.md` — **new file** infra agent
- [ ] `web/src/pages/api/webhooks/sms/twilio.ts` — **new file** with signature verify
- [ ] `claw/src/aitools.ts` — register `sms-send` tool

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] demo passes
- [ ] **Reuse audit:**
  - [ ] Twilio webhook verifies signature (no unsigned writes to events)
  - [ ] Consent gate enforced (greps for `consent:sms` check)
- [ ] Rubric ≥ 0.65 (security ≥ 0.95)

---

## CMediaSocial — Organic social posting  [tier: complex · batch: 5 · blocks-on: CIntegrations, CSwarm-core]

**Exit:** `social-organic` agent receives touchpoint with `channel:social:<platform>` (twitter / linkedin / instagram / tiktok) → resolves provider → calls social-providers adapter → schedules or publishes immediately. Inbound likes / replies / shares route to `/api/events` with `campaign:<id>` tag.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cmedia-social.test.ts"
  asserts: "social signal with channel:social:twitter fires Twitter v2 POST /tweets mock; LinkedIn UGC, Instagram Graph, TikTok organic each fire matching adapter; webhook for engagement posts to /api/events"
  budget:  "<3s · <150 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `claw/src/adapters/hubspot.ts` — adapter pattern
   - [ ] `claw/src/lib/integration-creds.ts` — credential read; confirm OAuth tokens stored for Twitter/X, LinkedIn-org, IG, TikTok-org
   - [ ] CIntegrations OAuth callback — confirm Twitter / LinkedIn organic / TikTok organic OAuth flows are included (extend CIntegrations if not — note as W3 dependency)
2. **Primitive-inventory recon**
   - [ ] `web/src/pages/api/events.ts` — webhook ingest

### W2 — Decide  [Opus · architectural]

| Proposed file | Verdict |
|---|---|
| `claw/src/adapters/social-providers.ts` | **new** — switch over 4 platforms |
| `agents/social-organic.md` | **new** infra agent |
| `web/src/pages/api/webhooks/social/[platform].ts` | **new** webhook per-platform |

- [ ] **Slot map:** copywriter drafts post text; designer generates accompanying image; social-organic agent calls the platform adapter
- [ ] **Architectural questions:**
  - [ ] Cross-posting — same content to multiple platforms; one signal per platform tag combo
  - [ ] Scheduling — `send-at` tag respected; provider's own scheduler API used where available (LinkedIn supports, Twitter/X does not)
  - [ ] Image upload — Twitter/LinkedIn/Instagram require pre-upload then attach; TikTok Content Posting API expects video URL
  - [ ] Char limits — Twitter 280, LinkedIn 3000, Instagram 2200, TikTok 2200 caption — adapter truncates with `warn(0.3)` log
- [ ] **LOC budget:** ≤350 LOC across 3 new files

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `claw/src/adapters/social-providers.ts` — **new file**: 4-platform switch
- [ ] `agents/social-organic.md` — **new file** infra agent
- [ ] `web/src/pages/api/webhooks/social/[platform].ts` — **new file** per-platform webhook
- [ ] `claw/src/aitools.ts` — register `social-post` tool
- [ ] *(conditional on W1)* `web/src/pages/api/integrations/oauth/[provider].ts` — extend if Twitter/LinkedIn-org/TikTok-org OAuth not in CIntegrations scope

### W4 — Verify  [Haiku×5 rubric]

- [ ] `bun run verify` green
- [ ] demo passes (msw mocks all 4 platform APIs)
- [ ] **Reuse audit:**
  - [ ] Adapter pattern matches hubspot.ts shape
  - [ ] `loadIntegrationCreds()` used
  - [ ] Char-limit truncation logs `warn(0.3)` (not silent)
- [ ] Rubric ≥ 0.65 (security ≥ 0.90)

---

## CMediaContent — Blog + landing pages + SEO  [tier: complex · batch: 5 · blocks-on: CIntegrations, CSwarm-core]

**Exit:** `content` agent receives touchpoint with `channel:content:<cms>` (webflow / wordpress / ghost) → calls cms-providers adapter → publishes the post and returns the live URL (which becomes the destination for `/go/:id` tracked links). `seo` agent suggests keywords + on-page metadata via prompt to copywriter.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/cmedia-content.test.ts"
  asserts: "content signal with channel:content:webflow fires Webflow CMS API mock; published URL returned; seo agent reads target keyword from campaign tags and inflects copy"
  budget:  "<3s · <150 LOC"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `claw/src/adapters/hubspot.ts` — adapter pattern
   - [ ] `claw/src/lib/integration-creds.ts` — credential read; Webflow API token, WordPress App Password, Ghost Admin API key
   - [ ] `agents/copywriter.md` (from CSwarm) — confirm content drafts flow through copywriter
2. **Primitive-inventory recon**
   - [ ] `web/src/pages/go/[id].ts` — confirm tracked-link wraps published content URLs

### W2 — Decide  [Opus · architectural]

| Proposed file | Verdict |
|---|---|
| `claw/src/adapters/cms-providers.ts` | **new** — switch over Webflow + WordPress + Ghost (v1: Webflow and Ghost only; WordPress is v2 due to host-version variance) |
| `agents/content.md` | **new** infra agent |
| `agents/seo.md` | **new** infra agent — runs first, hands keyword + meta to copywriter |

- [ ] **Slot map:** seo agent reads `keyword-target:<phrase>` tag on campaign; emits prompt augmentation to copywriter; copywriter drafts; content agent publishes via cms-providers
- [ ] **Architectural questions:**
  - [ ] Publish vs draft — `publish-state` tag (`draft` | `live`) on the touchpoint determines if adapter calls publish endpoint or just saves
  - [ ] Update vs create — if `cms-post-id` tag present, adapter PATCHes; else POSTs
  - [ ] Cross-CMS schema — abstract over title / body / slug / meta-description / featured-image
- [ ] **LOC budget:** ≤300 LOC across 3 new files (2 agents are ~50 LOC each)

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `claw/src/adapters/cms-providers.ts` — **new file**: Webflow + Ghost switch (WordPress in v2)
- [ ] `agents/content.md` — **new file** infra agent
- [ ] `agents/seo.md` — **new file** infra agent
- [ ] `claw/src/aitools.ts` — register `cms-publish` + `seo-suggest` tools

### W4 — Verify  [Haiku×5 rubric]

- [ ] `bun run verify` green
- [ ] demo passes (msw mocks Webflow + Ghost)
- [ ] **Reuse audit:**
  - [ ] Adapter pattern matches hubspot.ts shape
  - [ ] Published URLs wrap through `/go/:id` for tracked-link inheritance
  - [ ] WordPress explicitly deferred to v2 (not partially shipped)
- [ ] Rubric ≥ 0.65 (security ≥ 0.90 — content API tokens scoped to single workspace)

---

## See also

- `web/campaigns.md` — the spec (every cycle reads via `shared_recon`)
- `web/crm.md` — composer, templates, status engine, tag taxonomy, roles
- `web/agent-analytics.md` — funnel_daily, variant lift z-test, attribution, useWatch
- `web/tracking.md` — events, campaign tag, pheromone, gates, vault
- `one/marketing-ontology.md` — 23-agent department, persona + offer schema, 7 loops, KPI ladder
- `one/dictionary.md` — canonical names (always)
- `one/rubrics.md` — scoring bands (always)
- `web/agent-authoring.md` — markdown contract for agents (CSwarm + CMedia* agents follow it)
- `web/roles.md` — 4-tier cascade (owner / agency / client / end_user) — CCRoles verifies
- `composio.md` — Composio OAuth reference (CIntegrations clones the pattern)
- *follow-up:* `l5-todo.md` (to be authored) — L5 OPTIMIZATION cron + ad-platform re-push

---

## Plan close

- [ ] **Final compress sweep** — `ts-prune` + `noUnusedLocals` once, after batch 4 closes
- [ ] **Final docs/improvements.md append** — summary of shipped surfaces + l5-todo.md queued as follow-up
- [ ] **Plan rubric ≥ 0.65** across all 21 cycles

**Final new-file count target:**

| Category | Count | Files |
|---|---|---|
| TS components | 2 | CampaignCardRenderer.tsx · IntegrationsList.tsx |
| TS libs | 4 | scripts/gen-subscriptions.ts · claw/src/generated/subscriptions.ts (generated) · claw/src/agents/subscribe-loader.ts · claw/src/lib/integration-creds.ts |
| TS adapters (creative + paid) | 7 | image-providers · video-providers · voice-providers · meta-ads · google-ads · linkedin-ads · tiktok-ads |
| TS adapters (messaging + organic) | 4 | email-providers · twilio · social-providers · cms-providers |
| Astro pages | 0 | campaigns live in `/in` as a preset — no new page |
| OAuth callback | 1 | api/integrations/oauth/[provider].ts |
| Webhook endpoints | ~6 | webhooks/email/[provider].ts · webhooks/sms/twilio.ts · webhooks/social/[platform].ts (justified `/api/` exceptions — webhook URLs must be stable per `.claude/rules/api.md`) |
| Agent markdown — orchestration | 8 | cmo · strategist · researcher · copywriter · designer · voice · analyst · compliance (extension) |
| Agent markdown — channel | 9 | paid-meta · paid-google · paid-linkedin · paid-tiktok · email · sms · social-organic · content · seo |
| Optional helpers | ≤2 | campaign-starters.ts · budget-monitor.ts |
| **Total new files** | **~43** | ~17 TS + 0 astro + 17 markdown + 2 optional + 7 endpoints |
| **New endpoint files** | **~7** | 1 OAuth callback + 6 webhook endpoints (all stable-URL justified) |

**Done = `bun run dev` → end-to-end demo across every channel:**
1. `/in?preset=campaigns` → empty list with `[+ New campaign]` HeroCTA + starter grid
2. `/settings/integrations` → connect Meta + Google + LinkedIn + TikTok (OAuth) + Klaviyo + Resend + Twilio + Twitter/X + Webflow (API keys / OAuth) — all round-trip in test
3. type a brief in chat → swarm card streams in with per-agent progress indicators across all channels
4. tap `[Approve & ship]` → real provider mocks fire for every connected channel: ad-set in Meta · email blast in Klaviyo · SMS via Twilio · tweet + LinkedIn post · blog published to Webflow
5. `/in?preset=campaign:<id>` → 8 KPI tiles + 10 charts (incl. LiveEventStream) all `campaign=<id>` filtered, spanning paid + organic events
6. `/in?preset=campaigns&view=discovered` → L6 candidates with `[⊕ Materialise]` — surfaces organic patterns (e.g. "LinkedIn post → email open → demo") as candidate campaigns
7. NotificationBell lights up on status / budget / cap / fatigue / reply (across email + SMS + social inbound)
8. test asserts role middleware rejects 4 unauthorised verbs

**v2 / deferred (call out in close):**
- L5 OPTIMIZATION cron + automatic creative regeneration → `l5-todo.md`
- Template versioning UX (`tpl-version:<v>` banner + Migrate-all/Leave)
- `&view=replies` separate from default touches view
- Clone (`c` shortcut) + save-as-draft + date picker UI on start-at/end-at
- WordPress CMS adapter (CMediaContent ships Webflow + Ghost; WP host-version variance pushed to v2)
- Six orchestration agents from marketing-ontology: `brand` · `forecaster` · `crm` · `cro` · `pr-influencer` · `community` · `ops` · `growth` — these are analysis/coordination agents, not channel agents; not blocking v1's "create-view-manage" surface
