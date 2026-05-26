---
title: CRM — tags, subscriptions, pheromone (17 cycles)
slug: crm
type: plan
tier: complex
mode: construction
tags: [crm, in, signals, subscriptions, tags, pheromone]
source_of_truth:
  - web/crm.md
  - one/signals.md          # the substrate contract: subscriptions are tags + pheromone
  - web/tracking.md
  - web/agent-analytics.md
  - one/marketing-ontology.md
  - web/roles.md
surface_code:
  - web/src/pages/in/[groupId].astro
  - web/src/components/in/Inbox.tsx
  - web/src/components/in/EntityDetail.tsx
  - web/src/components/in/EntityCard.tsx
  - web/src/data/in-types.ts
narrative_truth: text/12-crm.md
show: false
escape:
  condition: "any cycle W4 fails delta_tsc > 0 twice OR consent gate test fails"
  action: "halt; re-read crm.md §0 (tag-pattern table) + signals.md §Subscriptions; reconcile before retrying"
context_triggers:
  - pattern: "consent|suppression|frequency.cap"
    inject: "one/marketing-ontology.md § Consent + Suppression"
  - pattern: "subscribe|sub:|topic|fan.out"
    inject: "one/signals.md § Subscribe"
  - pattern: "identity|same-as|merge|visitor_hash"
    inject: "web/tracking.md § Identity ladder"
  - pattern: "holdout|attribution|incremental"
    inject: "web/agent-analytics.md § Attribution + Holdout"
  - pattern: "pii|vault|reveal|forget"
    inject: "web/crm.md § 11 Privacy posture"
  - pattern: "role|owner|agency|client|end_user"
    inject: "web/roles.md § Cascade"
  - pattern: "tag|namespace|taxonomy"
    inject: "web/crm.md § 5 Tag taxonomy"
---

# CRM — tags, subscriptions, pheromone (17 cycles)

**Reframe (2026-05-15).** The CRM is tags + subscriptions + pheromone
per [`one/signals.md`](../plans/signals.md). Every feature I previously
planned as its own UI cycle collapses into one of three primitives:
**subscriptions** (the sidebar), **a universal composer** (the only
input surface), or **signal templates** (data, not UI).

What was 34 cycles is now **17**. The substrate provides 80%.

**Goal:** Ship the 17 cycles. After all land:
- 3-column `/in` works as Apple+Discord composite (subscriptions ·
  inbox · detail+composer)
- marketer / sales / service all open `/in`, land on their default
  subscription pack, work standard CRM workflows via the universal
  composer + signal templates
- humans + agents collaborate by subscribing to the same tags
- LLMs operate the inbox via 9 MCP tools
- the 12-CRM marketing promises are end-to-end verifiable

**Critical path** (~8 cycles): CS · CV · CSub · CComp · CTagMgr ·
CTpl · CK · CPerf. The rest layer integrations, privacy, identity,
analytics, and external surface.

---

## What was dropped (collapsed into substrate primitives)

These 17 cycles are no longer needed. Their value moved into the
remaining cycles or into substrate primitives.

| Dropped | Now lives in | Why |
| --- | --- | --- |
| CChannels | CSub | channel = `sub:<tag>` |
| CSplits | CSub | split = a subscription with a label |
| CDate | CGroupBy | `group_by=ts:day` |
| CThread | CGroupBy | `group_by=actor+channel` |
| CReact | CComp + CTagMgr | reaction = `react:<emoji>` tag |
| CMention | CComp + CTagMgr | mention = signal with `mention:<from>` tag |
| CMergeUI | CV | merge UI is a detail-pane variant |
| CInlineEdit | CV | inline edit is a detail-pane behaviour |
| CLens | CSub | lens = subscription pack |
| CSeq | CTpl + CJ | sequence = chained signal templates run by CJ |
| CMail | CTpl + CComp | bulk email = template with `sub:` receiver |
| CTask | CTpl | task = template with `direct:me` + `remind-at` |
| CCal | CTpl | meeting = template with `kind:meeting` |
| CKb | CTpl | KB = thing with `kind:knowledge` + tag search |
| CSat | CTpl | CSAT = template with `kind:csat-request` |
| CSla | CTpl + CS | SLA = computed tag from signal age |
| CTeam | CSub | team = `sub:team:<x>` |
| CAssign | CComp + CTagMgr | owner = `owner:<actor>` tag |
| CInternal | CComp + CTagMgr | internal = `visibility:internal` tag |
| CCollab | CSub | agents subscribe like humans |
| CSnooze | CTpl | snooze/send-later/remind = signal time attributes |

---

## Dependency graph

```
CTagMgr ──┐
          │
CS ───────┼──→ CSub ─┐
          │          ├──→ CComp ──→ CTpl ──→ CJ
CV ───────┘          │
                     ├──→ CK ──→ CPerf
                     │
                     └──→ CGroupBy

CMcpInbox  ──→ depends on CComp + CSub stable
CP         ──→ depends on CS + signal stream
CSP        ──→ depends on W11 endpoints (or stubs)
CX  ──→ CH ──→ depend on W7 (identity rungs for HubSpot dedup)
W7  ──→ parallel
W11 ──→ parallel
```

CS + CV + CTagMgr are the data foundation. CSub + CComp are the UI
foundation. CTpl turns the substrate into a productised CRM. The rest
layer outward.

---

## Status

**Foundation (data + UI):**
- [ ] CS — Status semantics (tag-driven) · W0 W1 W2 W3 W4
- [ ] CV — Actor detail-pane (tag panels + inline edit + merge UI) · W0 W1 W2 W3 W4
- [ ] CTagMgr — Workspace tag taxonomy + ACL + suggestions · W0 W1 W2 W3 W4
- [ ] CSub — Subscription sidebar (pinned + pheromone sort) + packs · W0 W1 W2 W3 W4
- [ ] CComp — Universal composer (receiver picker + tag picker + body + schedule) · W0 W1 W2 W3 W4
- [ ] CTpl — Signal templates + 30 starters per role + quick-pick row · W0 W1 W2 W3 W4
- [ ] CGroupBy — `group_by=<attr>` URL param (date · thread · lifecycle · owner) · W0 W1 W2 W3 W4

**Speed:**
- [ ] CK — Keyboard contract (⌘K + 30 shortcuts + `?` overlay) · W0 W1 W2 W3 W4
- [ ] CPerf — <100ms per-action budget · W0 W1 W2 W3 W4

**Analytics:**
- [ ] CJ — Journey runtime · W0 W1 W2 W3 W4
- [ ] CP — Pulse (12 KPI tiles) · W0 W1 W2 W3 W4

**External surface:**
- [ ] CMcpInbox — `@oneie/mcp` `inbox_*` tools (9 verbs) · W0 W1 W2 W3 W4

**Settings + integration + privacy:**
- [ ] CSP — Settings hub (`/settings/{privacy,packs,templates,tags,status}`) · W0 W1 W2 W3 W4
- [ ] CX — Remaining exports + importers · W0 W1 W2 W3 W4
- [ ] CH — HubSpot write-through · W0 W1 W2 W3 W4
- [ ] W7 — Identity rungs 2–5 · W0 W1 W2 W3 W4
- [ ] W11 — PII vault + `/api/forget` · W0 W1 W2 W3 W4

---

## CS — Status semantics  [tier: simple]

**Exit:** `web/src/data/in-types.ts` derives status from per-dimension
tag rules per [`web/crm.md`](crm.md) §3. Rules editable at
`/settings/status` (admin page comes via CSP). 9 example URLs in
crm.md §1 return correct entity lists on seeded data.

### W1 — Recon  [Haiku · parallel]

- `web/src/data/in-types.ts` — current `InboxEntity.status` assignment
- `one/marketing-ontology.md` — threshold attributes (high-value, EV)
- `web/crm.md` §3 — locked rule table

### W2 — Decide  [Sonnet]

- Compute at API or client? (API — small wire, cacheable)
- Threshold storage: D1 `workspace_settings` JSON
- Rule DSL: simple `tag-match + threshold` or full predicate? (simple)

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/data/in-types.ts` — `assignStatus(entity, rules)`
- [ ] `web/src/lib/in/thresholds.ts` — workspace threshold reader
- [ ] `web/src/pages/api/export/{actors,groups,skills,highways}.ts` — apply status
- [ ] `web/src/pages/api/in/sessions.ts` — apply status for events
- [ ] `web/src/pages/api/frontiers.ts` — apply for learning
- [ ] `migrations/0NNN_workspace_settings.sql` — thresholds + rules JSON
- [ ] `web/crm.md` — mark CS ✅

### W4 — Verify  [Haiku×4]

- [ ] `bun run verify` green
- [ ] All 9 example URLs return ≥ 1 entity on seeded data
- [ ] Threshold change re-classifies on next read
- [ ] Status is a pure function of (entity, rules, time)
- [ ] Rubric ≥ 0.65

---

## CV — Actor detail-pane  [tier: simple]

**Exit:** `EntityDetail` rendering an `actor` shows tag-driven panels
(consent · lifecycle chip · same-as with confidence bars + split
button · paths · appended grouped by source). Click any field →
inline edit; signal fires `actor:update.<field>`; optimistic UI.
Variants for signal · thing · path also implemented.

### W1 — Recon  [Haiku · parallel]

- `web/src/components/in/EntityDetail.tsx` — current shape
- `web/src/lib/crm/actor.ts` — getContact aggregator (shipped C1)
- `web/src/components/crm/{ContactHeader,ContactIdentity,ContactActivity}.tsx` — existing components to fold in
- W7 merge engine output shape (for same-as panel)

### W2 — Decide  [Sonnet]

- Reuse existing `crm/Contact*` components or rewrite? (reuse)
- Inline-edit field types: text · select · tags · datetime
- Same-as: auto-merge ≥ 0.95, queue 0.6–0.95, drop < 0.6
- Action bar verbs per entity type (actor: reply/mark/warn/broadcast/enrich/forget)

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/components/in/EntityDetail.tsx` — branch on entity type
- [ ] `web/src/components/in/EditableField.tsx` — new (text/select/tags/datetime)
- [ ] `web/src/components/in/EntityActionBar.tsx` — new per-type verb bar
- [ ] `web/src/components/crm/ContactConsent.tsx` — consent matrix
- [ ] `web/src/components/crm/ContactPaths.tsx` — strongest paths
- [ ] `web/src/components/crm/ContactAppended.tsx` — appended attributes
- [ ] `web/src/components/crm/ContactSameAs.tsx` — same-as + split (from CMergeUI absorbed)
- [ ] `web/src/lib/in/edit.ts` — optimistic field edit
- [ ] `web/crm.md` — mark CV ✅
- [ ] `web/tests/entity-detail.spec.ts`

### W4 — Verify  [Haiku×5]

- [ ] All 5 panels render on seeded actor
- [ ] Click name → input → blur commits → signal lands → row updates in <2s
- [ ] Server rejection rolls back UI; toast surfaces error
- [ ] Same-as split round-trip preserves provenance
- [ ] All action-bar verbs emit `emitClick('ui:in:<verb>')`
- [ ] Lighthouse perf ≥ 90
- [ ] Rubric ≥ 0.65

---

## CTagMgr — Tag taxonomy + ACL  [tier: simple]

**Exit:** `/settings/tags` shows workspace tag namespaces with usage
count · ACL · colour. Owner can add/edit/lock namespaces. Claw
suggests new tag promotions from frequent ad-hoc tags. Tag pickers
across the app pull from this registry.

### W1 — Recon  [Haiku]

- `one/marketing-ontology.md` — locked namespaces
- TypeDB tag schema — current shape
- claw embedding/clustering for tag suggestion

### W2 — Decide  [Sonnet]

- Storage: D1 `tag_namespace` table (namespace, values JSON, acl, colour, locked)
- Locked namespaces: `lifecycle:*` · `iab/*` · `gdpr` · `ccpa` · `status:*` · `sla:*` (computed)
- ACL: `{ read: roles[], write: roles[] }` per namespace
- Suggestion cadence: nightly clustering on ad-hoc tags; threshold 20 uses

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/pages/settings/tags.astro` — admin page
- [ ] `web/src/components/settings/TagManager.tsx` — namespace table + CRUD
- [ ] `web/src/lib/in/tags.ts` — `listNamespaces`, `createNamespace`, `lockNamespace`
- [ ] `web/src/pages/api/tags/index.ts` — CRUD
- [ ] `web/src/pages/api/tags/suggest.ts` — claw-driven promotion suggestions
- [ ] `migrations/0NNN_tag_namespace.sql` — new
- [ ] `web/agents/tag-suggest.md` — nightly clustering agent
- [ ] `web/crm.md` — mark CTagMgr ✅

### W4 — Verify  [Haiku×3]

- [ ] Owner creates `campaign:*` namespace → appears in pickers
- [ ] Locked `lifecycle:*` rejects edit attempt; logs `tag.write.denied`
- [ ] Suggestion: 20 ad-hoc `vip-pricing` tags → namespace promotion suggested
- [ ] Non-owner ACL fail: 403
- [ ] Rubric ≥ 0.65

---

## CSub — Subscription sidebar  [tier: complex]

**Exit:** Left column renders subscriptions: pinned (manual
drag-to-reorder) on top, then by pheromone strength. `+` to subscribe
to any tag (autocomplete from CTagMgr). `★` on any list-view URL or
tag pill saves as a sub. `✕` unsubs. Unread counts live via SSE.
Default packs (marketer / sales / service) preload on first open;
`⌘L` switches pack.

### W1 — Recon  [Haiku · parallel]

- `one/signals.md` §Subscribe + Implementation — `subscribeTopic` + `load()` shape
- `web/src/components/in/Navigation.tsx` + `Inbox.tsx` — current sidebar
- KV per-user state (for sub order overrides)
- `useWatch()` SSE for live counts

### W2 — Decide  [Opus]

- Storage: `sub:<x>` tag on the user's actor row (already-supported substrate path) + KV for per-user pin order
- Pheromone-sort source: `bridge(sub-tag, user)` strength reads, refreshed per tick
- Pack switching: write pack tags + remove non-pack tags? OR additive? (additive — user's manual subs preserved)
- Faded threshold: hide subs below pheromone 0.1; or just visually fade?

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/components/in/SubscriptionSidebar.tsx` — new (replaces Navigation)
- [ ] `web/src/components/in/SubscribeButton.tsx` — new (`+` and `★`)
- [ ] `web/src/lib/in/subscriptions.ts` — new — `listSubs(user)`, `subscribe(user, tag)`, `unsubscribe(user, tag)`, `applyPack(user, pack)`
- [ ] `web/src/lib/in/packs.ts` — new — pack definitions (marketer/sales/service)
- [ ] `web/src/pages/api/in/subs/index.ts` — CRUD
- [ ] `web/src/pages/api/in/packs.ts` — read packs + apply
- [ ] `web/src/pages/settings/packs.astro` — owner-edits packs (via CSP)
- [ ] `web/src/components/in/Inbox.tsx` — swap in SubscriptionSidebar; preload pack on first open
- [ ] `migrations/0NNN_sub_pin_order.sql` — KV-equivalent for per-user order
- [ ] `web/crm.md` — mark CSub ✅
- [ ] `web/tests/subs.spec.ts`

### W4 — Verify  [Haiku×5]

- [ ] First open with role=marketer → marketer pack pre-subscribed
- [ ] Star a tag pill → new sidebar entry (sorted into pheromone section)
- [ ] Drag-reorder pinned: persists across reload
- [ ] Subscribed to `sub:#leads`: new signal tagged `#leads` increments badge in <2s
- [ ] `⌘L` switches pack: pack tags added, manual subs retained
- [ ] Pheromone fade: 14-day-untouched sub drops below 0.1, visually faded
- [ ] Rubric ≥ 0.65

---

## CComp — Universal composer  [tier: complex]

**Exit:** One composer handles every CRM "feature". Receiver picker
(direct / `world:` / `all:` / `sub:`), tag picker (from CTagMgr),
body editor (text + `@mention` + `/snippet` + tracked-link),
schedule (now or `send-at`), holdout (none or %). Templates
(from CTpl) pre-fill all five fields with one click.

### W1 — Recon  [Haiku · parallel]

- `web/src/components/in/Inbox.tsx` `BroadcastBar` — current composer
- `one/signals.md` §Grammar — 5 receiver modes
- claw text-expansion + mention parsing already-shipped
- Postmark MJML email render path

### W2 — Decide  [Opus]

- Single composer component or per-mode variants? (single — modes are tabs)
- Rich-edit toggle: text default; MJML when receiver mode = `sub:` AND channel includes `email`
- Tag picker: chip row with autocomplete; recent + canonical at top
- Send-time optimisation: claw scores per-actor best hour from 30d engagement
- Holdout assignment: deterministic hash(actor + campaign) % 100

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/components/in/Composer.tsx` — new (universal)
- [ ] `web/src/components/in/ReceiverPicker.tsx` — new (direct/world/all/sub)
- [ ] `web/src/components/in/TagPicker.tsx` — new (autocomplete from CTagMgr)
- [ ] `web/src/components/in/MjmlEditor.tsx` — new (6 blocks: hero/text/image/button/divider/footer)
- [ ] `web/src/lib/in/compose.ts` — new — build + send signal
- [ ] `web/src/lib/in/send-time.ts` — new — per-actor optimal hour
- [ ] `web/src/lib/in/holdout.ts` — new — deterministic split
- [ ] `web/src/pages/api/compose/send.ts` — new
- [ ] `web/src/components/in/EntityDetail.tsx` — swap in Composer at bottom
- [ ] `web/src/components/in/Inbox.tsx` — replace BroadcastBar with Composer
- [ ] `web/crm.md` — mark CComp ✅
- [ ] `web/tests/compose.spec.ts` — 8 workflow cases (reply · internal note · broadcast · self-task · sequence step · meeting · CS handoff · world-route)

### W4 — Verify  [Haiku×6]

- [ ] All 8 workflow cases from crm.md §4 table produce correct signal shapes
- [ ] Receiver mode `sub:seg:trial-d7` (412 actors): fanout in <30s; holdout 10 untouched
- [ ] Internal-note (`visibility:internal`): outbound adapter skips; logs to activity
- [ ] `@ada` mention: signal fires to ada with `mention:<from>`
- [ ] Template apply: 5 fields fill from chosen template
- [ ] Send-time optimisation: 100-actor batch fans across 100 distinct hours
- [ ] Rubric ≥ 0.65 — security ≥ 0.85 (consent gate + suppression)

---

## CTpl — Signal templates  [tier: complex]

**Exit:** `/settings/templates` (via CSP) lists 30 starter templates
per role (90 total). Each template = receiver-mode + tags + body
shell + schedule + holdout defaults. `★` makes a template appear in
the composer's quick-pick row. Authoring UI: clone-and-edit pattern.

### W1 — Recon  [Haiku · parallel]

- `web/crm.md` §6 — template table shape
- `one/marketing-ontology.md` — locked tags for templates
- claw template-fill agent (token replacement)
- Starter content for 30 × 3 = 90 templates (marketing draft from text/12-crm.md)

### W2 — Decide  [Opus]

- Storage: D1 `signal_template` table
- Tokens in body: `{first_name}` style; claw fills from actor attrs
- Quick-pick row: per-user stars (KV); workspace defaults
- Sequence steps: each step = a template + `then` rule (advance on signal pattern OR after N delay)

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/in/templates.ts` — new — CRUD + apply + token-fill
- [ ] `web/src/components/in/TemplateLibrary.tsx` — new — gallery + clone
- [ ] `web/src/components/in/QuickPickRow.tsx` — new — pinned templates above composer
- [ ] `web/src/pages/api/templates/index.ts` — CRUD
- [ ] `web/src/pages/api/templates/[id]/apply.ts` — fill composer
- [ ] `web/templates/marketer/` — 30 YAML files (welcome / re-engage / trial / cold / bulk / abandoned-cart / event / win-back / …)
- [ ] `web/templates/sales/` — 30 YAML files (intro / discovery / proposal / quote / followup / handoff / …)
- [ ] `web/templates/service/` — 30 YAML files (apology / kb-link / escalation / csat-request / sla-warn / refund / …)
- [ ] `migrations/0NNN_signal_template.sql`
- [ ] `web/crm.md` — mark CTpl ✅
- [ ] `web/tests/templates.spec.ts`

### W4 — Verify  [Haiku×5]

- [ ] 90 starter templates load on first workspace open
- [ ] Clone-to-workspace: tokens replaced (logo, sender); new template editable
- [ ] Quick-pick: 5 starred templates show in composer; click fills 5 fields
- [ ] Sequence: 5-step template chain runs end-to-end via CJ
- [ ] Bulk email template: 500-actor send completes <30s
- [ ] Rubric ≥ 0.65

---

## CGroupBy — `group_by=<attr>` URL param  [tier: simple]

**Exit:** URL `?group_by=<attr>` renders attr-specific layouts:
`date` (Apple-Mail sticky sections), `actor+channel` (Apple-Mail
threads), `lifecycle` (pipeline columns), `owner` (Discord-style
swim-lanes), `ts:hour` (timeline). Other attrs render generic
grouped lists.

### W1 — Recon  [Haiku]

- `web/src/components/in/Inbox.tsx` — current entity list rendering
- Existing scroll/sticky patterns in repo

### W2 — Decide  [Sonnet]

- Renderer dispatch: lookup table or one parameterised `GroupedList`?
- Pipeline columns: horizontal scroll; min-width per column
- Empty groups: hide
- Sort within group: pheromone × recency

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/in/group-by.ts` — `groupBy(entities, attr)` + renderer dispatch
- [ ] `web/src/components/in/GroupedList.tsx` — root
- [ ] `web/src/components/in/groups/DateSections.tsx`
- [ ] `web/src/components/in/groups/ThreadCards.tsx`
- [ ] `web/src/components/in/groups/PipelineColumns.tsx`
- [ ] `web/src/components/in/groups/OwnerLanes.tsx`
- [ ] `web/src/components/in/Inbox.tsx` — branch on `group_by`
- [ ] `web/crm.md` — mark CGroupBy ✅
- [ ] `web/tests/group-by.spec.ts`

### W4 — Verify  [Haiku×4]

- [ ] `group_by=date` → 4 sticky sections
- [ ] `group_by=actor+channel` → 10-signal thread collapses to 1 card
- [ ] `group_by=lifecycle` → 6 horizontal columns; drag-to-advance writes signal
- [ ] `group_by=owner` → swim-lanes per assignee
- [ ] Rubric ≥ 0.65

---

## CK — Keyboard contract  [tier: complex]

**Exit:** Every shortcut in [`web/crm.md`](crm.md) §3 / §4 wired and
visible in `?` overlay. `⌘K` spotlight fuzzy-searches entities + URLs
+ verbs + templates. Lighthouse perf ≥ 95.

### W1 — Recon  [Haiku · parallel]

- `web/src/components/in/Inbox.tsx` — current j/k handler
- Existing keyboard infra
- `cmdk` package

### W2 — Decide  [Sonnet]

- Spotlight lib: `cmdk` (5kb, used by Vercel/Linear)
- Chord buffer + 1s timeout for `g i`, `g v`
- Central `useShortcuts()` hook; per-component register

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/in/shortcuts.ts` — central registry; emits `ui:in:shortcut:<id>` signal
- [ ] `web/src/components/in/Spotlight.tsx` — cmd-K overlay
- [ ] `web/src/components/in/ShortcutHelp.tsx` — `?` overlay from registry
- [ ] `web/src/hooks/useShortcuts.ts`
- [ ] `web/src/components/in/Inbox.tsx` — wire spotlight; replace j/k
- [ ] `web/src/components/in/EntityDetail.tsx` — r/e/w/h/s/b/@/:/i/f/o/.
- [ ] `web/tests/shortcuts.spec.ts` — 30-shortcut coverage
- [ ] `web/crm.md` — mark CK ✅

### W4 — Verify  [Haiku×4]

- [ ] All 30 shortcuts in `?` match crm.md verbatim
- [ ] `⌘K` finds seeded actor in <50ms
- [ ] Two-key chords honour 1s buffer
- [ ] Each shortcut emits `ui:in:shortcut:<id>` per `.claude/rules/ui.md`
- [ ] Rubric ≥ 0.65 — speed ≥ 0.90 hard target

---

## CPerf — <100ms per-action budget  [tier: complex]

**Exit:** Every keystroke produces visible feedback in <100ms (95th
%ile, CI-asserted). Detail pre-fetches on hover. mark/warn/reply
optimistic. `/api/in/quick/*` low-latency endpoints skip TypeDB
round-trip for hot-path reads.

### W1 — Recon  [Haiku · parallel]

- Current latency baseline (instrument)
- Slow paths (TypeDB on actor detail, signal write on mark)
- DO RAM hot-path readiness

### W2 — Decide  [Opus]

- Optimistic UI: write local + signal in background; revert on failure
- Hover prefetch: 100ms delay
- Caching strategy
- Quick-API verbs: list, open, mark, warn, react

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/in/optimistic.ts` — apply local + revert on failure
- [ ] `web/src/pages/api/in/quick/list.ts` — DO-RAM only
- [ ] `web/src/pages/api/in/quick/mark.ts` — WAL + 200 + drain
- [ ] `web/src/components/in/EntityCard.tsx` — hover prefetch
- [ ] `web/src/lib/in/perf.ts` — measure + emit `ui:in:perf` signal
- [ ] `web/crm.md` — mark CPerf ✅
- [ ] `web/tests/perf.spec.ts` — 30-shortcut budget

### W4 — Verify  [Haiku×5]

- [ ] 95th %ile keystroke-to-feedback <100ms (CI assertion)
- [ ] Hover prefetch eliminates wait on detail open
- [ ] Optimistic mark: row gone in <50ms
- [ ] Lighthouse perf ≥ 95
- [ ] Rubric ≥ 0.65 — speed ≥ 0.92 hard target

---

## CJ — Journey runtime  [tier: complex]

**Exit:** Sequence-template chains (CTpl) execute end-to-end as
journeys: enrol → step → wait → step → exit conditions → mark
convert. 10% holdout untouched. Stage counts visible in `funnel_hourly`.
Discovered journeys (`?d=learning&s=todo`) materialise to live
journeys via one-click.

### W1 — Recon  [Haiku · parallel]

- `web/agent-lifecycle.md` § funnel — existing runner shape
- `web/src/pages/api/funnel/[id]/` — current endpoints
- `web/src/lib/in/compose.ts` (CComp) — send path
- `migrations/funnel_hourly` schema

### W2 — Decide  [Opus]

- Journey def: template chain rows in D1 with `then` rules
- Stage transition: signal-tag match (e.g. step 1 done when receiver acks `touch:click`)
- Runner cadence: tick (L1) + scheduled drain for `send-at` waits
- Idle exit: 48h default (`dropSignal: { idleAfter: 48h }`)
- Holdout: deterministic hash, persistent

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/crm/journey.ts` — `createJourney`, `enrolActor`, `evaluateStage`, `materialiseFromCandidate`
- [ ] `web/src/lib/crm/journey-runner.ts` — tick handler
- [ ] `web/src/pages/api/journey/[id]/enrol.ts`
- [ ] `web/journeys/trial-rescue-d14.yaml` — seed example
- [ ] `web/src/components/in/EntityDetail.tsx` — extend `path` branch
- [ ] `web/crm.md` — mark CJ ✅
- [ ] `web/tests/journey.spec.ts`

### W4 — Verify  [Haiku×4]

- [ ] 50-actor seeded journey: counts match (45/30/12/5)
- [ ] Attribution path strength on `invite→nudge→convert` non-zero
- [ ] Materialise from `?d=learning&s=todo` → live journey created
- [ ] Idle-48h drop: untouched actors exit
- [ ] Rubric ≥ 0.65

---

## CP — Pulse  [tier: simple]

**Exit:** `?d=pulse` (7th nav) renders 12 KPI tiles from
[`web/agent-analytics.md`](agent-analytics.md): identity-resolution-rate
· consent-coverage · mql→sql · time-to-convert · CAC · LTV · LTV:CAC ·
ROAS · Incremental-ROAS · cap-hit-rate · attribution-coverage ·
holdout-lift. Reveal-audit panel at `?d=events&filter=type:pii.read`.

### W1 — Recon  [Haiku · parallel]

- `web/agent-analytics.md` — KPI math
- `web/src/pages/api/agents/[id]/{analytics,…}` — endpoints to reuse
- `web/src/components/in/Inbox.tsx` — wire 7th nav

### W2 — Decide  [Sonnet]

- 7th nav `?d=pulse` vs strip overlay (recommend: nav, consistent)
- Filter chrome (workspace + date + campaign + channel) — URL contract
- SSE live updates

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/crm/kpis.ts` — 12 KPI computations
- [ ] `web/src/components/in/PulseStrip.tsx` — tile grid
- [ ] `web/src/components/in/RevealAudit.tsx`
- [ ] `web/src/data/in-types.ts` — add `pulse` dimension
- [ ] `web/src/pages/api/in/kpis.ts`
- [ ] `web/crm.md` — mark CP ✅

### W4 — Verify  [Haiku×3]

- [ ] 12 tiles render > 0 on seeded data; math matches `kpis.spec.ts`
- [ ] Holdout lift = treatment_strength − control_strength
- [ ] Rubric ≥ 0.65

---

## CMcpInbox — `@oneie/mcp` `inbox_*` tools  [tier: complex]

**Exit:** `@oneie/mcp` ships 9 `inbox_*` tools per
[`web/crm.md`](crm.md) §13 table. Claude Desktop fixture round-trip:
`inbox_list` → `inbox_open` → `inbox_send` → entity closes in /in UI
within 5s.

### W1 — Recon  [Haiku · parallel]

- `mcp/` — tool registration shape
- `web/crm.md` §13 MCP table — 9 verbs
- Superhuman MCP shape for naming reference

### W2 — Decide  [Opus]

- Tool names: `inbox_*` (server namespace = oneie)
- Filter object shape (LLM-friendly)
- Streaming `inbox_watch` via MCP notifications
- Permission model: MCP session = workspace scope

### W3 — Edit  [Sonnet · parallel — one tool per agent]

- [ ] `mcp/src/tools/inbox_list.ts`
- [ ] `mcp/src/tools/inbox_open.ts`
- [ ] `mcp/src/tools/inbox_send.ts`
- [ ] `mcp/src/tools/inbox_subscribe.ts`
- [ ] `mcp/src/tools/inbox_mark.ts` + `inbox_warn.ts`
- [ ] `mcp/src/tools/inbox_react.ts`
- [ ] `mcp/src/tools/inbox_forget.ts`
- [ ] `mcp/src/tools/inbox_pulse.ts`
- [ ] `mcp/src/tools/inbox_watch.ts`
- [ ] `mcp/src/index.ts` — register
- [ ] `mcp/README.md` — document
- [ ] `mcp/tests/inbox.spec.ts`
- [ ] `web/crm.md` — mark CMcpInbox ✅

### W4 — Verify  [Haiku×9]

- [ ] Each tool: schema validated · happy-path test green · error path
- [ ] E2E: Claude Desktop fixture → list → open → send → entity closes in /in <5s
- [ ] Rubric ≥ 0.65

---

## CSP — Settings hub  [tier: simple]

**Exit:** Five small admin pages under `/settings/`:
- `/settings/privacy` — collection mode + key custody (W11)
- `/settings/packs` — subscription pack editor per role (CSub)
- `/settings/templates` — template gallery + author (CTpl)
- `/settings/tags` — tag namespaces (CTagMgr)
- `/settings/status` — status rule editor (CS)

Owner gate per [`web/roles.md`](roles.md).

### W1 — Recon  [Haiku]

- `web/roles.md` § cascade — owner gate
- Existing settings page pattern
- Each underlying lib (privacy / packs / templates / tags / status)

### W2 — Decide  [Sonnet]

- Storage shared: `workspace_settings` JSON column where possible
- Each page: thin shell wrapping the underlying lib UI
- Single layout `SettingsShell.astro`

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/layouts/SettingsShell.astro`
- [ ] `web/src/pages/settings/privacy.astro`
- [ ] `web/src/pages/settings/packs.astro`
- [ ] `web/src/pages/settings/templates.astro`
- [ ] `web/src/pages/settings/tags.astro`
- [ ] `web/src/pages/settings/status.astro`
- [ ] each underlying API (already specced in CS, CTagMgr, CSub, CTpl, W11)
- [ ] `web/crm.md` — mark CSP ✅

### W4 — Verify  [Haiku×5]

- [ ] All 5 pages render for owner; 403 for non-owner
- [ ] Each page's CRUD round-trips against API
- [ ] Lighthouse perf ≥ 90 per page
- [ ] Rubric ≥ 0.65 — security ≥ 0.90

---

## CX — Remaining exports + importers  [tier: complex]

**Exit:** {google · tiktok · klaviyo · salesforce} export +
{clearbit · apollo · stripe · shopify · ga4} importer each have an
adapter, signal-receiver wiring, fixture round-trip test. Exports
selectable from `EntityActionBar` on `group` entities (CV).
Importers fire on `lifecycle:lead` transition.

### W1 — Recon  [Haiku · parallel — 9 agents]

- Shipped Meta export — template to copy
- Each platform's API auth + rate-limit + hash format
- `web/crm.md` §14 standards table

### W2 — Decide  [Opus]

- Shared `Exporter` interface
- Importer subscription model: `signal('lifecycle:lead')` event-driven
- Provenance: `appended.<source>.<field>` lock
- Rate-limit / retry: shared util

### W3 — Edit  [Sonnet · parallel — 9 agents]

- [ ] `web/src/lib/crm/exporter.ts`
- [ ] `web/src/lib/integrations/google.ts` · `tiktok.ts` · `klaviyo.ts` · `salesforce.ts`
- [ ] `web/src/lib/integrations/clearbit.ts` · `apollo.ts` · `stripe.ts` · `shopify.ts` · `ga4.ts`
- [ ] `web/agents/import-*.md` × 5
- [ ] `web/crm.md` — mark CX ✅

### W4 — Verify  [Haiku×9]

- [ ] Each integration: fixture round-trip green
- [ ] Importer: seeded `lifecycle:lead` → `appended.*.*` write within 5s
- [ ] Rubric ≥ 0.65

---

## CH — HubSpot write-through  [tier: complex]

**Exit:** `export-hubspot` agent subscribes to `actor:lifecycle`
transitions, calls HubSpot CRM API within 30s. Both export-audience
+ write-through paths. `import-hubspot` maps 1k-contact CSV in one
pass; custom props → `appended.hubspot.<field>`; dedup via
identity-ladder.

### W1 — Recon  [Haiku · parallel]

- `web/crm.md` §16 — migration contract
- `text/12-crm.md` — promise-level requirements
- HubSpot CRM API (OAuth + 10 req/s limits)

### W2 — Decide  [Opus]

- Field mapping: 7 standard hardcoded + JSON column for custom
- Substrate-is-source: conflict policy = substrate wins, log
- Stage mapping table in `hubspot.ts`
- OAuth tokens in vault (CSP+W11)

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/integrations/hubspot.ts` — both paths
- [ ] `web/agents/export-hubspot.md` — write-through subscriber
- [ ] `web/agents/import-hubspot.md` — CSV + API
- [ ] `web/src/pages/api/integrations/hubspot/connect.ts` — OAuth
- [ ] `web/src/pages/api/integrations/hubspot/webhook.ts` — inbound
- [ ] `migrations/0NNN_integration_tokens.sql` — vault-sealed
- [ ] `web/tests/integrations/hubspot.spec.ts`
- [ ] `web/crm.md` — mark CH ✅

### W4 — Verify  [Haiku×5]

- [ ] Substrate `lead → mql → sql` → HubSpot within 30s
- [ ] CSV (1k): one pass; custom props in `appended.hubspot.*`
- [ ] Conflict: HubSpot-side edit → webhook → `lifecycle.conflict` signal; substrate wins
- [ ] Rate-limit: 50-actor batch no 429
- [ ] Rubric ≥ 0.65

---

## W7 — Identity rungs 2–5  [tier: complex]

**Exit:** Email/phone/account/linked rungs land on incoming signals;
`same-as` relations created with confidence; identity-resolution-rate
≥ 95% on seeded multi-rung dataset.
`?d=actors&s=todo&filter=needs-review:merge` surfaces probabilistic
candidates.

### W1 — Recon  [Haiku · parallel]

- `web/tracking.md` § identity ladder rungs 2–5
- Existing rungs 0–1 impl
- `web/crm.md` §12 — merge rules

### W2 — Decide  [Opus]

- Auto-merge threshold (≥ 0.95)
- Cascade re-point: sync vs lazy?
- Phone normalisation: E.164 before SHA-256
- Auth-provider sub: Google via Better Auth

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/identity/ladder.ts` — extend to rungs 2–5
- [ ] `web/src/lib/identity/merge.ts` — deterministic + probabilistic
- [ ] `web/src/pages/api/identity/merge.ts` — manual endpoint
- [ ] `migrations/0NNN_same_as.sql` — if needed
- [ ] `web/src/components/crm/ContactSameAs.tsx` (CV) — confidence bar
- [ ] `web/tracking.md` — mark rungs 2–5 ✅

### W4 — Verify  [Haiku×5]

- [ ] 1000-actor 30%-dup seed → resolution-rate ≥ 95%
- [ ] Merge round-trip: path strength sums on canonical
- [ ] No silent overwrite
- [ ] Review queue populated by probabilistic candidates
- [ ] Rubric ≥ 0.65

---

## W11 — PII vault + `/api/forget` + `pii.read`  [tier: complex]

**Exit:** `POST /api/forget` returns cascade receipt id; vault row
KMS-shredded < 1s; KV/D1/TypeDB/R2/ad-platforms follow;
`GET /api/forget/:request_id` returns per-tier status. Every
`/api/pii/reveal/:actor` emits `pii.read` event; rate-limited 100/hr.

### W1 — Recon  [Haiku · parallel]

- `web/crm.md` §11 vault + forget tables
- Existing `DELETE /api/visitor/:hash` impl
- KMS adapter (or create)
- Ad-platform DELETE endpoints

### W2 — Decide  [Opus]

- Default KMS: Cloudflare-managed
- `pii_vault` schema
- Cascade ordering (parallel after vault)
- Reveal scopes: `pii:read` only initially

### W3 — Edit  [Sonnet · parallel]

- [ ] `web/src/lib/pii/vault.ts` — seal/unseal/shred
- [ ] `web/src/lib/pii/forget.ts` — cascade engine
- [ ] `web/src/pages/api/forget.ts` — POST
- [ ] `web/src/pages/api/forget/[id].ts` — GET
- [ ] `web/src/pages/api/pii/reveal/[actor].ts` — emits `pii.read`
- [ ] `migrations/0NNN_pii_vault.sql`
- [ ] `migrations/0NNN_forget_audit.sql`
- [ ] `web/agents/compliance.md` — consume `pii.read` anomalies
- [ ] `web/src/pages/api/visitor/[hash].ts` — alias of `/api/forget`
- [ ] `web/crm.md` — mark W11 ✅

### W4 — Verify  [Haiku×7]

- [ ] All 6 cascade tiers verified
- [ ] Vault shred latency <1s
- [ ] Reveal rate-limit: 101st → 429 + alert
- [ ] `pii.read` events present
- [ ] Hashes survive ≤5m in warm then null
- [ ] Reveal-audit panel populated
- [ ] Rubric ≥ 0.65 — security ≥ 0.92 hard target

---

## See also

- [`web/crm.md`](crm.md) — surface spec (the contract — collapsed to ~500 lines)
- [`one/signals.md`](../plans/signals.md) — the substrate primitive (subscriptions are tags + pheromone)
- [`web/tracking.md`](tracking.md) — wire format + identity ladder + cost model
- [`web/agent-analytics.md`](agent-analytics.md) — KPI math
- [`one/marketing-ontology.md`](../plans/marketing-ontology.md) — consent + suppression + attribute lists
- [`web/roles.md`](roles.md) — owner/agency/client/end_user cascade
- [`one/dictionary.md`](../plans/dictionary.md) — canonical names
- [`one/rubrics.md`](../plans/rubrics.md) — scoring bands
- [`one/patterns.md`](../plans/patterns.md) — closed loop, sandwich
- [`text/12-crm.md`](../text/12-crm.md) — voice + worked example
- Surface code: [`web/src/pages/in/[groupId].astro`](src/pages/in/[groupId].astro), [`web/src/components/in/`](src/components/in/), [`web/src/data/in-types.ts`](src/data/in-types.ts)
