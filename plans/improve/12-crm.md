# 12-crm — gap analysis

## Promise

From `text/12-crm.md` (CRM marketing surface, Anthony's voice):

- Actor row IS the contact record — no separate CRM database, no sync.
- 8 actor attrs live (`name email phone lifecycle fit-score ltv consent-channels channels`), enrichment adds 40+ across Clearbit / Apollo / Stripe / Shopify / GA4 / identity ladder.
- Five CRM surfaces shipped or in build: `/crm/c/:actor` (live), `/crm/g/:group` (segments), `/crm/j/:journey`, `/crm/b/new` (broadcast), `/crm/pulse` (analytics).
- Two endpoints shipped (commit `74e47496`): `GET /api/actors/[id]` + `GET /api/actors/[id]/activity`. Enrichment aggregator `enrichActor()` in `web/src/lib/crm/actor.ts` (commit `79fd203c`).
- Signal-driven lifecycle transitions: `anonymous → lead → mql → sql → customer → advocate` (+ `churned`); orthogonal dormancy `active | warming | cold | reactivated | lost` driven by L3 fade.
- Identity ladder resolves visitor_hash ↔ email-hash ↔ phone ↔ provider IDs, target >95%, with `same-as` relation + confidence + `split()` reversal.
- Enrichment is event-driven, lands `appended.<source>.<field>` with provenance, manual override wins over imports.
- Write-through to HubSpot / Salesforce — substrate updates push back via export agents; client can keep HubSpot during transition.
- Inbox at `/crm/inbox` is a reverse-segment, sorts by LTV desc, aggregates escalations across all client workspaces.
- Privacy: `POST /api/forget` cascades vault + KV + D1 + TypeDB + R2 + ad platforms; receipt at `GET /api/forget/:request_id`, vault shred <1s.
- 8 enrichment integrations specified, 8 export integrations, diff push for audiences.
- Performance: contact detail <100ms from D1, tracked link <50ms edge, segment count <200ms, broadcast 10k contacts <30s.
- "Open the actor view — it's already the CRM."

## Code reality

**People surface (people-todo.md — 5 cycles all checked done):**
- `web/src/lib/crm/actor.ts` — `Person` type with full ontology (identity, contact, professional, social links, address, consent, derived). `ContactHeader = Person` alias preserved. `getContact()` returns `Contact` with header + identity + groups + paths + appended.
- `web/src/pages/u/[slug]/in.astro` + `web/src/pages/u/[slug]/people.astro` — workspace inbox + people page live.
- `web/src/components/in/` — `Inbox`, `PeopleCard`, `PeopleKanban`, `BulkBar`, `EntityDetail`, `ListHeader`, `MergeReviewDrawer`, `ImportCSVForm`.
- `web/src/components/crm/` — `PersonHero`, `ContactActivity`, `ContactAppended`, `ContactConsent`, `ContactIdentity`, `ContactMessages`, `ContactNotes`, `ContactPaths`, `ContactSameAs`, `SendLinkSheet`.
- `web/src/pages/api/actors/[id]/index.ts` + `[id]/activity.ts` — shipped.
- `web/src/pages/api/export/actors.ts` + `people.ts` (CSV download) — shipped, scoped by `workspaceContext`.
- `web/src/pages/api/forget.ts` + `forget/[id].ts` + `web/src/lib/pii/forget.ts` + `vault.ts` + `cascade.ts` — forget endpoint and cascade builder live.
- `web/src/lib/in/writethrough.ts` — payload builders for HubSpot + Salesforce. `claw/src/agents/export-hubspot.ts` + `export-salesforce.ts` — subscriber agents polling `pending_writethroughs`. `claw/src/adapters/hubspot.ts` — wire adapter.
- `web/src/pages/api/crm/hot-accounts.ts` — single API stub under `/api/crm`.

**TypeDB schema:** `one/contact-schema.tql` declares missing attrs (per Cycle 1 plan); `marketing-schema.tql` is the base.

**Signal-driven mechanics:** lifecycle stage update is wired via `POST /api/signal/:uid:lifecycle` from `PeopleKanban` drag; consent gates exist in `lib/in/compliance.ts`; tag/status rules in `lib/in/status.ts` include `dormancy:warming`.

## Gaps

1. **The 5 promised CRM routes don't exist.** Marketing names `/crm/c/:actor`, `/crm/g/:group`, `/crm/j/:journey`, `/crm/b/new`, `/crm/pulse`. Only `/crm/c/[actor].astro` exists (a thin SSR shell still rendering deprecated `ContactHeader`, not `PersonHero`). No `/crm/g/`, no `/crm/j/`, no `/crm/b/`, no `/crm/pulse`. No `/crm/inbox` (the inbox lives at `/u/:slug/in`). The product is at `/u/:slug/people` and `/u/:slug/in` — fine, but the marketing copy will 404 every reader who clicks.
2. **The standalone `/crm/c/:actor` page is stale.** It imports `ContactHeader` (deprecated in Cycle 3) instead of `PersonHero`, doesn't render the 10 tabs, doesn't poll D1 activity past the initial 50. The rich detail panel lives only inside the `/u/:slug/in` `Inbox` component.
3. **Enrichment is plumbing without engines.** `appended: []` is hardcoded in `getContact()` (`actor.ts:278`). No `import-clearbit`, `import-apollo`, `import-stripe`, `import-shopify`, `import-ga4` agents in `claw/src/agents/`. The contract is in the marketing page; the code is `appended: [], // wired in C6 importers` — C6 never landed.
4. **Identity ladder is stubbed.** `actor.ts:208-211` comment: "same-as relation isn't in world.tql — alias linking will be wired with the…" then `sameAs: string[] = []` returns empty. No identity resolution. No `split(a, b)` reversal endpoint. No confidence scoring. No probabilistic merge engine. `MergeReviewDrawer.tsx` exists in `in/` but the merge backend is absent.
5. **Signal-driven lifecycle transitions aren't classified.** The kanban drag manually fires `:lifecycle`, but there is no NLU/intent classifier in `claw/` (only `classify.ts` general router) that detects `intent:proposal-request` → advance to `sql`. The "pipeline writes itself" mechanic is human drag only.
6. **Dormancy stages don't exist.** Marketing names `active | warming | cold | reactivated | lost`. Only `warming` appears once in `lib/in/status.ts`. No L3 fade computing dormancy on `last-seen`. No reactivation routing.
7. **Journeys + Broadcasts are unbuilt.** No `/crm/j/:journey` runtime, no `/crm/b/new` composer, no `/crm/j/discovered` (the L6 KNOWLEDGE-loop discovered-journeys page named in cross-references). No broadcast send pipeline, no consent-gate enforcement at broadcast time (the consent attrs exist, the broadcaster doesn't).
8. **Segments are saved-search drafts, not first-class.** Cycle 5 saved segments via `PUT /api/in/drafts` with `entityId: 'segment:*'` and splice into tagRail. There is no `/crm/g/:group` page, no live segment count endpoint, no segment-as-audience export to ad platforms.
9. **Pulse / analytics surface for CRM is missing.** Marketing: "`/crm/pulse` shows CRM KPIs filtered to CRM verbs." Built: `/u/:slug/analytics` exists (agent-funnel-focused), no CRM KPI lens, no `funnel_daily` / `rollup_counters` CRM filter view.
10. **Export integrations are 2 of 8.** Marketing claims 8 (Meta CA, Google CM, TikTok, Klaviyo, HubSpot, Salesforce, + 2). Built: HubSpot + Salesforce only (write-through, not audience push). No diff-push to ad platforms.
11. **Importer ingestion is partial.** `web/src/lib/in/import.ts` + `ImportCSVForm` exist for CSV. No Salesforce/Klaviyo API import path, no field-mapper UI surfacing `appended.<source>.<field>` for HubSpot custom properties.
12. **`/api/actors/export` (full workspace JSON/Parquet) is absent.** Marketing: "`GET /api/actors/export` returns the full workspace in one call." Built: `/api/export/actors` and `/api/export/people` (CSV/Inbox shape). No JSON/Parquet workspace dump.
13. **Override + provenance audit trail unimplemented.** Marketing promises every stage transition logs the rule that fired, override is one keystroke, `appended.manual.<field>` wins over imports. Code has no rule registry, no override signal, no provenance preference layer.
14. **`PeopleCard` consent dots cite values that the export query may not return.** `EXPECTED_FIELDS.actors` includes `personMeta`, but `api/export/actors.ts` Phase 2 query collects raw attrs — verify each `consent-{email,sms,push,call}` actually maps into `personMeta.consent` for the rendered dots.

## Recommended improvements

Two tracks: (1) **stop lying about the routes**, (2) **land enrichment + identity + journeys** so the marketing copy is true.

**Track 1 — make the marketing-named URLs work (low effort, high honesty).**

- Add redirect shims so `/crm/inbox`, `/crm/g/...`, `/crm/c/...`, `/crm/j/...`, `/crm/b/...`, `/crm/pulse` either resolve under `/u/:slug/...` for the viewer's default workspace, or render the page directly under `/crm/...`. Pick one structure. Today: copy says `/crm`, code lives under `/u/:slug`.
- Upgrade `/crm/c/[actor].astro` to mount the `EntityDetail` + `PersonHero` + 10-tab island used by `Inbox`, instead of the deprecated `ContactHeader` shell. Single source of truth for the contact view.

**Track 2 — close the 4 mechanic gaps the marketing leans on.**

- **Enrichment engines (Cycle 6 of `people-todo.md`).** One importer agent per source: `claw/src/agents/import-clearbit.ts` (event: `lifecycle:lead`), `import-apollo.ts`, `import-stripe.ts`, `import-ga4.ts`. Each writes `appended.<source>.<field>` rows; `getContact()` reads from a new `appended` D1 table or TypeDB relation. Include a "Last enriched" timestamp on the Sources tab (already wired in `EntityDetail`).
- **Identity ladder.** Materialise `same-as` in `marketing-schema.tql`, write a merge candidate detector (email-hash, phone-hash, visitor_hash matches → write `same-as` with confidence), expose `POST /api/actors/:id/merge` + `POST /api/actors/:id/split`, populate `ContactSameAs.tsx` from real data not `[]`.
- **Intent-driven stage transitions.** Add a `crm-classify.ts` agent in `claw/src/agents/` that listens on inbound message signals, classifies (model call, returns intent + confidence), and if intent matches a workspace-configured rule (`mql_to_sql_patterns`), fires `:lifecycle` signal with `rule_fired` provenance. UI shows the rule in the activity tab. Override = manual stage change with `override:true` tag.
- **Dormancy as a derived attribute.** Compute from `last-seen` + path-strength fade tick (already runs in `substrate.ts:fade`). Surface as a 5th lifecycle-orthogonal column on the kanban + a segment filter.

**Track 3 — journeys + broadcasts + segments (the unbuilt half of the CRM).**

- `/crm/g/:group` segment runtime: live count, member preview, "send broadcast" CTA, "export to audience" diff-push.
- `/crm/b/new` broadcast composer: channel picker (consent-gated), audience selector (segment), holdout %, schedule, preview, throttle. Send goes through `:broadcast` signal → consent gate → per-channel send agent.
- `/crm/j/:journey` journey runtime + `/crm/j/discovered`: render `JourneyDAG` (already exists) hydrated from path-strength data + materialise-with-one-click into a configured journey.
- `/crm/pulse`: CRM KPI tiles (new leads / stage velocity / consent rate / dormancy curve) over the existing `funnel_daily` and `rollup_counters`.

**Track 4 — pre-flight before the marketing page goes live.**

- Audit `text/12-crm.md` against shipped reality — strip claims that have no code (8 enrichment sources, 8 export integrations, 95% identity resolution, NBA banner, `appended.manual.*` precedence, `GET /api/actors/export` JSON/Parquet). Either build or remove.

## Files to touch

**Honesty / route alignment:**
- `web/src/pages/crm/c/[actor].astro` — replace `ContactHeader` mount with `EntityDetail` island; or redirect to `/u/:slug/people/:actorId`.
- `web/src/pages/crm/inbox.astro` (new) or middleware redirect → `/u/:slug/in`.
- `web/src/pages/crm/g/[group].astro` (new), `crm/j/[journey].astro` (new), `crm/b/new.astro` (new), `crm/pulse.astro` (new).
- `text/12-crm.md` — strike unbuilt claims or move them to "in build."

**Enrichment + identity:**
- `claw/src/agents/import-clearbit.ts` · `import-apollo.ts` · `import-stripe.ts` · `import-ga4.ts` · `import-shopify.ts` (new).
- `web/src/lib/crm/actor.ts:208-211, 278` — replace stubbed `sameAs: []` and `appended: []` with real reads.
- `one/marketing-schema.tql` or `one/contact-schema.tql` — declare `same-as` relation + `confidence` attr; declare `appended` relation/entity.
- `web/src/pages/api/actors/[id]/merge.ts` + `split.ts` (new).
- `web/src/pages/api/actors/[id]/enrich.ts` (new) — fires importer agents on demand for Sources tab Enrich button.

**Lifecycle classifier:**
- `claw/src/agents/crm-classify.ts` (new) — listens on inbound message signals, classifies, fires `:lifecycle` with `rule_fired` tag.
- `web/src/lib/in/lifecycle-rules.ts` (new) — workspace-configurable intent → stage map.
- `web/src/components/crm/ContactActivity.tsx` — render `rule_fired` in event row.

**Dormancy:**
- `web/src/lib/substrate.ts:fade` — extend to emit `dormancy:warming|cold|reactivated|lost` tags on actors based on last-seen + strength.
- `web/src/lib/in/status.ts` — wire dormancy as a status dimension.

**Journeys / broadcasts / segments / pulse:**
- `web/src/pages/api/segments/[id].ts` (new) — live count + members + first-class segment storage (lift out of `drafts`).
- `web/src/pages/api/broadcasts/index.ts` + `[id].ts` (new) — compose, schedule, send (consent-gated).
- `web/src/pages/api/journeys/[id].ts` + `discovered.ts` (new).
- `web/src/components/crm/JourneyComposer.tsx`, `BroadcastComposer.tsx`, `SegmentPanel.tsx` (new).
- `web/src/pages/api/crm/pulse.ts` (new) — CRM KPI rollups.

**Audience exports (diff push):**
- `claw/src/agents/export-meta-ca.ts` · `export-google-cm.ts` · `export-tiktok.ts` · `export-klaviyo.ts` (new) — each diff push from segment membership.

**Workspace dump:**
- `web/src/pages/api/actors/export.ts` (new) — JSON + Parquet of full actor table for current workspace; reuse `scopeToGroup`.

**Override + provenance:**
- `web/src/lib/crm/provenance.ts` (new) — `appended.manual.*` wins helper used by `getContact()`.
- `web/src/components/crm/ContactAppended.tsx` — render manual pinned values distinctly; pin/unpin control.
