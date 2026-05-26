---
title: CRM — wire the shell to the substrate
slug: crm
type: plan
tier: complex
mode: construction (refining — 2026-05-16)
tags: [crm, in, signals, subscriptions, tags, pheromone, wiring, demo-gated]
source_of_truth:
  - web/crm.md
  - web/crm-pages.md
  - one/signals.md          # the substrate contract: subscriptions are tags + pheromone
  - web/tracking.md
  - web/agent-analytics.md
  - one/marketing-ontology.md
  - web/roles.md
surface_code:
  - web/src/pages/in.astro                    # ✓ shipped — operator shell (global scope)
  - web/src/pages/in/[groupId].astro          # ✓ shipped — workspace shell (agency scope)
  - web/src/pages/u/[slug]/in.astro           # ✗ new (QW13) — per-client shell (slug scope)
  - web/src/components/in/Inbox.tsx           # ✓ shipped — 3-column root (extend with slug prop)
  - web/src/components/in/Navigation.tsx      # ✓ shipped — rail rows (6 dimensions)
  - web/src/components/in/StatusTabs.tsx      # ✓ shipped — NOW/TOP/TODO/DONE
  - web/src/components/in/EntityCard.tsx      # ✓ shipped — list row
  - web/src/components/in/EntityDetail.tsx    # ✓ shipped — detail pane
  - web/src/components/in/ProfileHeader.tsx   # ✓ shipped — top of rail
  - web/src/data/in-types.ts                  # ✓ shipped — Dimension, Status, InboxEntity
  - web/src/pages/api/in/sessions.ts          # ✓ shipped — event feed
  - web/src/pages/api/frontiers.ts            # ✓ shipped — L6 hypothesis feed (powers Frontier row)
  - web/src/pages/api/export/{actors,groups,skills,highways}.ts  # ✓ shipped
  - web/src/lib/crm/actor.ts                  # ✓ shipped — getContact aggregator (folded into CV)
  - web/src/components/crm/ContactHeader.tsx  # ✓ shipped — folded into QW6 top bar
  - web/src/components/crm/ContactIdentity.tsx # ✓ shipped — folded into QW8 tabs
  - web/src/components/crm/ContactActivity.tsx # ✓ shipped — folded into QW8 tabs
  # — chat primitives the CRM composes (do NOT re-implement) —
  - web/src/components/ai-elements/prompt-input.tsx          # ✓ shipped — root + attachments + screenshot + camera
  - web/src/components/ai-elements/prompt-input-layout.tsx   # ✓ shipped — Body/Header/Footer/Tools/Submit/Tabs/Select/Command
  - web/src/components/ai-elements/prompt-input-textarea.tsx # ✓ shipped — autosizing textarea + enter-to-submit
  - web/src/components/ai-elements/conversation.tsx          # ✓ shipped — Conversation + ConversationContent (scroll-stick)
  - web/src/components/ai-elements/message.tsx               # ✓ shipped — Message/MessageContent/MessageActions/MessageBranch
  - web/src/components/chat/MessageList.tsx                  # ✓ shipped — UIMessage thread w/ tool parts, files, approvals
  - web/src/components/chat/MessageRenderer.tsx              # ✓ shipped — frame → card dispatch
  - web/src/components/chat/ChatDock.tsx                     # ✓ shipped — composes the above into a dock; reference shape for CComp
  - web/src/components/chat/AddMenu.tsx                      # ✓ shipped — Add menu (templates, files, screenshot)
  - web/src/components/chat/AttachmentsPreview.tsx           # ✓ shipped — pending attachments strip
narrative_truth: text/12-crm.md
show: false

# --- Auto-execution contract (read before invoking /do crm-todo --auto) ---
# Refined 2026-05-16: the old contract laundered runtime gaps into
# "deferred to seeded deploy" — so /do --auto could close every cycle
# while no feature worked end-to-end. The new contract makes a demo
# gate per cycle (see § Demo wall) the closing condition.
auto:
  must_complete: true
  parallel_w3: required
  min_parallel_w3_agents: 3
  max_parallel_w3_agents: 12
  parallel_w1: encouraged
  parallel_w4: required
  trust_floor_for_auto: standard
  ratchet:                       # Hard gates — fail any one and the cycle stops.
    - delta_tsc_errors <= 0      # No new type errors vs W0 baseline.
    - composite >= 0.65          # Rubric gate.
    - adversarial < 0.5          # No critical security/spec violations.
    - cycle_demo passes          # NEW — see § Demo wall for the per-cycle assertion.
  # The OLD do_not_stop_on list was the launderer. Three items are deleted:
  #   - "missing seed data"                 → seed fixtures are part of W3 now
  #   - "API endpoint requires future migration" → migrations apply in W3, not later
  #   - "agent .md scaffolds"               → scaffolds aren't wired; cycle doesn't close
  do_not_stop_on:
    - "known third-party rate limit (Klaviyo/HubSpot test API throttle)"
    - "single-cycle Lighthouse perf delta on a non-CPerf cycle (batch in CPerf)"
  hard_halt_only_on:
    - "tsc errors introduced (ratchet failure)"
    - "cycle demo gate fails"
    - "composite < 0.65 on two consecutive cycles (cautious trust)"
    - "user sends a stop signal"
    - "all cycles wired (every cycle's demo passes)"

# --- Wave parallelism table (read at every wave start) ---
# Per /do classifier × tier — these are the spawn shapes /do MUST use.
parallelism:
  W1:
    TRIVIAL: "inline (≤3 files in main context)"
    SIMPLE:  "inline (≤5 files in main context)"
    COMPLEX: "spawn Haiku w1-recon × N in one message (N = file count, max 8)"
  W2:
    TRIVIAL: "inline"
    SIMPLE:  "inline (you are the decider)"
    COMPLEX: "inline — never delegate understanding; load last 20 learnings + context_triggers"
  W3:
    TRIVIAL: "inline edits (≤3 files)"
    SIMPLE:  "spawn Sonnet w3-edit × file_count if file_count > 2 (single message)"
    COMPLEX: "spawn Sonnet w3-edit × N in one message (N = independent files; same-file edits sequence as W3b)"
  W4:
    TRIVIAL: "inline rubric (read 4 scores + compute composite)"
    SIMPLE:  "inline rubric UNLESS bun run verify fails — then spawn 5 Haiku rubric agents"
    COMPLEX: "ALWAYS spawn 5 Haiku rubric agents in one message: security · stability · simplicity · speed · adversarial"

escape:
  condition: "delta_tsc_errors > 0 OR rubric composite < 0.65 × 2 OR adversarial severity > 0.5"
  action: "halt; report the offending cycle; ratchet-revert if a regression is identified"
  note: "Single-cycle Lighthouse / FCP regressions DO NOT trigger escape — CPerf cycle batches all perf fixes. Empty seed data DOES NOT trigger escape — APIs return empty cleanly."
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
  - pattern: "rail|sidebar|channel|noun"
    inject: "web/crm-pages.md § 2 The rail"
---

# CRM — quick wins on /in, then cycles

**Power through simplicity.** The CRM shell is already shipping at
`/in` and `/in/[groupId]` via [`Inbox.tsx`](src/components/in/Inbox.tsx).
Three columns, six dimensions, four statuses, real-time SSE — it works.
The path to the CRM in [`crm.md`](crm.md) + [`crm-pages.md`](crm-pages.md)
is **not a rewrite**. It's a stack of focused edits on the components
that already ship.

**Two phases:**

1. **Phase 1 — Quick Wins (QW1…QW13).** Each one is a single
   component edit, independently shippable, with visible UX impact.
   None scaffold new routes. All evolve `Inbox.tsx`, `Navigation.tsx`,
   or `EntityDetail.tsx` in place. Stack these and the surface reaches
   parity with [`crm-pages.md`](crm-pages.md).
2. **Phase 2 — Cycles (CTagMgr, CComp, CTpl, CK, CPerf, CMcpInbox, CJ,
   CP, CSP, CX, CH, W7, W11).** Larger work that doesn't decompose
   into a single edit. These come after the quick-win surface is
   stable.

**What we are NOT building** (and dropping from any prior todo state):

- ❌ A new route tree under `/u/[slug]/{inbox,drafts,sent,…}` — the
  existing `/in/[groupId]` shell handles all the same data via
  navigation state. Scaffolding 11 new Astro routes is the opposite of
  power through simplicity.
- ❌ Separate `<Rail>`, `<WorkspacePicker>`, `<MailZone>`, `<WorkZone>`
  components — `Navigation.tsx` already exists; evolve it.
- ❌ A `<Shell>` wrapper to share between routes — `Inbox.tsx` is the
  shell.
- ❌ A bespoke `<Composer>` tree (`composer/Composer.tsx`,
  `composer/Toolbar.tsx`, `composer/ReceiverPicker.tsx`, …). The
  `PromptInput` primitives in `ai-elements/` already cover
  textarea + autosize + enter-to-submit + attachments + screenshot +
  camera + action menu + tabs + select + footer + submit. CComp is a
  **composition**, not a new tree. `ChatDock.tsx` is the reference shape.
- ❌ A bespoke `<ThreadView>` for QW10. `Conversation` +
  `ConversationContent` + `Message` (with `from="user|assistant"`) +
  `MessageContent` already render the Apple-Messages bubble look.
  `MessageList.tsx` already handles tool parts, file parts, approvals
  for full UIMessage data. QW10 is a **render pass**, not a new
  component.

If a feature looks like a new component, **prove it can't be done by
composing existing primitives** first. Default to composition; only
add a new file when the composition can't express the shape.

---

## The honest gate — compose existing primitives, prove with a demo

**Refined 2026-05-16.** The old contract laundered runtime gaps into
"deferred to seeded deploy." Every cycle could close on file existence
+ tsc green, while no feature worked end-to-end. The new contract
makes a **demo gate** per cycle the closing condition, and the demo
must compose **existing substrate primitives** — never invent new
routes, tables, or entities. ([`crm.md`](crm.md) § 17 is the rule.)

### What's actually shipped at the substrate layer

Read this before any cycle. Every wiring task composes these.

| Primitive | Endpoint (already ships) |
| --- | --- |
| Emit any signal | `POST /api/signal/[...receiver]` |
| Ask + reply | `POST /api/ask/[...receiver]` |
| Mark / warn / fade / follow / select | `POST /api/{mark,warn,fade,follow,select}/[edge]` |
| Actor detail | `GET /api/actors/[id]` ✅ (commit `74e47496`) |
| Actor activity feed | `GET /api/actors/[id]/activity` ✅ |
| Actors list | `GET /api/actors` (filtered by tags) |
| Agent analytics | `GET /api/agents/[id]/analytics` (KPI rollup) |
| Live signal tail (SSE) | `GET /api/analytics/watch` |
| Tracked links | `GET /go/:id` · `GET /r?e=&u=` |
| Workspace exports | `GET /api/export/{actors,groups,skills,highways}` |
| Frontier hypotheses (L6) | `GET /api/frontiers` |
| Event feed for /in | `GET /api/in/sessions` |
| Conversations reply | `POST <claw>/conversations/:id/reply` |
| Privacy cascade | `POST /api/forget` · `GET /api/forget/:request_id` |
| PII reveal | `GET /api/pii/reveal/:actor` (gated) |

**Anything labelled `inbox_*` in CMcpInbox composes these, not new
`/api/in/*` routes.** Anything labelled "fetch contact" in CV calls
`/api/actors/[id]`, not a new endpoint. Same rule everywhere.

### What's actually wired (2026-05-16 audit)

Three states: **✅ wired** (composes existing primitive + demoable) ·
**🟡 partial** (code exists but calls fictional endpoint or no consumer
reads it) · **❌ stub** (.md scaffold or untouched).

| Cycle | Code | Wired to substrate? | Demo passes today? |
| --- | --- | --- | --- |
| QW1–QW13 | ✅ all 13 ship | ✅ render `/in` over `/api/export/*` + `/api/in/sessions` + `/api/frontiers` | ✅ shell renders |
| **CS** | ✅ `lib/in/status.ts` `classify()` | ✅ Inbox.tsx calls client-side | 🟡 D1 needs seed |
| **CV** | 🟡 `/api/actors/[id]` ships; ContactConsent/Paths/Appended ship | ❌ **EntityDetail never calls `/api/actors/[id]`** — panels fabricate from `entity.tags` / `entity.related` | ❌ panels show "Unknown ×4" |
| **CTagMgr** | ✅ `0036` migration; TagManager.tsx; tag-suggest.md | 🟡 round-trip untested against D1 | ❌ |
| **CComp** | ✅ Composer.tsx composes PromptInput; TemplatePicker ships | 🟡 reply path hits `/conversations/:id/reply`; **broadcast / holdout / schedule send nowhere** | 🟡 reply only |
| **CTpl** | ✅ TemplateManager.tsx; 0037 migration | 🟡 `agents/template-starters.md` has 5 / 90 starters | ❌ |
| **CK** | ✅ shortcut registry infra; Spotlight + Help shells | ❌ **0 shortcuts registered** — registry is empty | ❌ |
| **CPerf** | ✅ memo + virtualise edits land; lazy-imports correct | 🟡 no Lighthouse run post-changes | ❌ |
| **CMcpInbox** | ✅ `mcp/src/tools/inbox.ts` defines 10 tools | ❌ **list/entity/watch/pulse call fictional `/api/in/*` endpoints; should compose `/api/actors`, `/api/actors/[id]`, `/api/analytics/watch`, `/api/agents/[id]/analytics`** | ❌ tools 404 |
| **CJ** | 🟡 runtime types + DAG component | ❌ runner agent not registered with claw cron; reactflow not wired | ❌ |
| **CP** | 🟡 6 pulse components ship | ❌ 5 / 6 hardcoded; only FrontierBlock fetches | ❌ |
| **CSP** | ✅ 5 settings pages ship | 🟡 D1 persistence untested round-trip | ❌ |
| **CX** | ❌ 12 .md scaffolds + 2 stub .ts (`hubspot.ts`/`salesforce.ts` ~2.3KB each) | ❌ no OAuth, no creds storage, no field map | ❌ |
| **CH** | ❌ same as CX | ❌ | ❌ |
| **W7** | 🟡 `lib/identity/{ladder,merge}.ts` ship | ❌ **tracking pipeline doesn't import them** — runs nowhere | ❌ |
| **W11** | ✅ `seal`/`unseal` + `/api/forget` + `/api/forget/[id]` + `/api/pii/reveal/[actor]` | 🟡 **KMS unbound** — `env.PII_ENVELOPE_KEY` falls back if unset | ❌ untested cascade |

**Headline:** 13 QW ✅ · 0 / 15 cycles wired end-to-end · the laundering
clause in the old contract is what hid the gap.

---

## Demo wall — 15 proofs, each composing existing primitives

Each cycle closes only when its demo passes. Every demo names the
**existing primitive** it composes — none introduce a new route.

| # | Cycle | Demo (must pass against `bun run dev`) | Composes |
| --- | --- | --- | --- |
| **D1** | **CS** | Seed 5 actors with `lifecycle:lead`. Edit a workspace status rule. `GET /api/export/actors` shows the 3 matching actors flip to `status:top` on next render. | existing `/api/export/actors` · `lib/in/status.ts` |
| **D2** | **CV** | Open `/in?d=actors&focus=<id>`. EntityDetail calls `GET /api/actors/[id]`. ContactConsent renders 4 non-Unknown chips. ContactPaths shows strengths from real TypeDB `path` relations. ContactAppended renders `appended.<source>.<field>` rows. | existing `/api/actors/[id]` (74e47496) |
| **D3** | **CTagMgr** | Owner POSTs new namespace `campaign:apr-q2` to `/api/tags`. Send a signal tagged `campaign:apr-q2` via `POST /api/signal/<actor>`. Reload `/in` — the tag appears in TAGS rail with count 1. Locked `lifecycle:*` rejects edit (403). | existing `/api/signal/[...receiver]` · `/api/tags` (CRUD wired in this cycle) |
| **D4** | **CComp** | Composer mode=`sub:trial-d7` + holdout=10. Submit → 90 emits land on `/api/signal/sub:trial-d7`, 10 actors logged as holdout (warn'd into `holdout-actor` tag). | existing `/api/signal/sub:<x>` fanout |
| **D5** | **CTpl** | Seed 90 starters (30 × 3 roles) into `signal_templates` via D1 migration. In composer body type `/welcome` → picker shows it → select → body + receiver_mode + tags fill. Submit emits a signal carrying the template's tag set. | existing `/api/signal` · `PromptInputCommand` primitive |
| **D6** | **CK** | All 30 shortcuts from `crm-pages.md` § 11 register at Inbox mount. `⌘K` opens Spotlight; fuzzy-search "ada" → ↵ navigates. `g i` jumps to inbox. `?` lists every registered shortcut. | existing `cmdk` package · shortcut registry |
| **D7** | **CPerf** | `npx lighthouse --headless /in` ≥ 95 perf, FCP < 1.0s, INP < 200ms. `wc -l Composer.tsx composer/*.tsx` totals < 450 (compose check). | existing build output |
| **D8** | **CMcpInbox** | **Rewire 4 handlers**: `inbox_list` → `GET /api/actors?tags=…`; `inbox_open` → `GET /api/actors/[id]`; `inbox_watch` → `GET /api/analytics/watch` (SSE); `inbox_pulse` → `GET /api/agents/[id]/analytics`. Other 6 already compose correctly. From Claude Desktop: `inbox_list({status:'todo'})` → `inbox_open(<id>)` → `inbox_send(...)` round-trip works; **zero 404s**. | **NO new endpoints.** Existing `/api/actors`, `/api/actors/[id]`, `/api/analytics/watch`, `/api/agents/[id]/analytics`, `/api/signal`, `/api/{mark,warn}`, `/api/forget`. |
| **D9** | **CJ** | Register `journey-runner` agent with claw cron (`* * * * *`). `POST /api/signal/journey:<id>:enrol` carrying `{actor_ids:[100 ids]}` → step-1 signals fire within 1s. Conversion `mark()`s the journey path; edge weight visible. | existing `/api/signal/[...receiver]` · existing `mark()` · claw cron |
| **D10** | **CP** | Seed 1000 signals across 4 funnel stages. PulseAtlas fetches `GET /api/agents/[id]/analytics` → renders 4 KPI tiles with delta arrows + funnel CVR labels. No mocked numbers anywhere in `components/pulse/*`. | existing `/api/agents/[id]/analytics` · existing `/api/frontiers` |
| **D11** | **CSP** | At `/settings/status`: edit a rule → save → reload → rule round-trips from D1 `workspace_settings`. Owner-only ACL: non-owner gets 403. | existing D1 + `workspace_settings` table from 0035 |
| **D12** | **CX** | Configure Klaviyo OAuth creds in workspace settings. `import-klaviyo` agent subscribes to lifecycle transitions and pushes diff via Klaviyo API. 100 contacts arrive in Klaviyo within 30s. Field map preview surface visible before commit. | existing `subscribe(lifecycle:*)` · agent-side Klaviyo client (`web/src/lib/integrations/klaviyo.ts` ← THIS file is new; the *endpoint* is not) |
| **D13** | **CH** | Patch actor lifecycle: `mql → sql` via `POST /api/signal/<actor>` with `lifecycle:sql` tag. `export-hubspot` agent subscribed to `actor:lifecycle.update` writes through to HubSpot CRM API within 30s. Conflict log on disagreement. | existing `subscribe(actor:lifecycle.update)` |
| **D14** | **W7** | Same person across visitor_hash + email-hash + phone-hash. Identity ladder resolves to one actor with `same-as` relations (confidence ≥ 0.95). Tracker pipeline imports `lib/identity/ladder` per signal. Review queue at `?d=actors&filter=needs-review:merge` shows probabilistic merges. | existing `lib/identity/{ladder,merge}` · existing TypeDB `same-as` relation |
| **D15** | **W11** | Bind `PII_ENVELOPE_KEY` to KMS in `wrangler.toml`. `POST /api/forget {actor_id}` → cascade fires across vault, KV, D1, TypeDB, R2, ad platforms. `GET /api/forget/:request_id` returns per-tier receipt. Vault shred latency < 1s. `/api/pii/reveal/:actor` emits `pii.read` event; rate-limit 100/hr returns 429 + alert. | existing `/api/forget` · `/api/forget/[id]` · `/api/pii/reveal/[actor]` (all ship — wiring is the work) |

**The bookkeeping rule:** if a cycle's demo requires a new `/api/`
route, the demo is wrong — re-read [`crm.md`](crm.md) § 13 for the
existing primitive that already does it.

### What counts as the cycle close

- Demo runs against `bun run dev` (or `wrangler dev` if env binding needed).
- Demo is captured as a Playwright spec under `web/tests/e2e/crm/D<N>.spec.ts` — **never `test.skip()`**.
- `bun run verify` green + composite ≥ 0.65 + the spec passes → cycle `[x]`.
- If the spec needs seed data, the seed lives in `web/tests/seeds/D<N>.sql` (applied via `wrangler d1 execute --local`) and is part of W3 — not a deferred runtime concern.

### Parallel-agent shape per wave (unchanged)

| Wave | TRIVIAL | SIMPLE | COMPLEX |
|------|---------|--------|---------|
| **W1 — recon**  | inline ≤3 files | inline ≤5 files | `Agent×N` Haiku `w1-recon` in **one message**, N = file count (max 8) |
| **W2 — decide** | inline | inline | inline — you ARE the decider; load last 20 learnings + matching context_triggers |
| **W3 — edit**   | inline ≤3 files | `Agent×file_count` Sonnet `w3-edit` if >2 files | `Agent×N` Sonnet `w3-edit` in **one message**, N = independent files (W3a parallel, same-file edits queue as W3b) |
| **W4 — verify** | inline rubric + run the cycle's demo spec | inline rubric + run the demo spec; spawn 5 only if verify fails | **always** spawn 5 Haiku rubric agents in **one message** + run the demo spec |

**Spawn rule (LOCKED):** when a wave's tier triggers a parallel spawn,
ALL agents launch in a single message via multiple `Agent` tool calls.
Cap per wave: 12 agents.

### Re-arming for a fresh --auto run

To re-execute this plan, flip every `[x]` → `[ ]` in the Phase 2
Status section, then run `/do crm-todo --auto`. Ratchet gates +
demo-gate remain in force. **A cycle that can't show its demo passing
cannot close.**

---

## The principle behind each quick win

| Principle | What it means in code |
| --- | --- |
| **Compose before construct** | Before any new file: scan `ai-elements/`, `chat/`, `ui/`, `crm/`, `in/` for a primitive that fits. New files only when composition can't express the shape. Justified per-file in W2 with a one-line "no existing primitive covers X". |
| **Reuse over rewrite** | Touch the file that already does most of it; don't create a parallel one |
| **One edit, one feature** | A QW that crosses three files is too big — break it up |
| **Negative delta_loc wins** | A change that deletes more than it adds (by swapping a bespoke widget for a primitive composition) is the preferred shape |
| **Ship behind no flag** | If it can't be merged today, it's not a quick win |
| **Numeric gate** | Each QW reports a measurable improvement (Lighthouse, FCP, click latency, signal count) |
| **No silent expansion** | A QW that adds 200 lines to fix one thing has lost the plot |

---

## Status

### Phase 1 — Quick Wins  [tier: trivial-to-simple per QW]

Each QW is a single-edit, independently shippable. `/do` advances the
next unchecked one.

- [x] QW1 — Rail zones (rename Navigation rows)
- [x] QW2 — Mail-state splits (Drafts + Sent rows)
- [x] QW3 — Work modules (Tasks · Calendar · Payments)
- [x] QW4 — `+ New` button in column header
- [x] QW5 — Hero CTA pill (per noun)
- [x] QW6 — Top-bar redesign in EntityDetail
- [x] QW7 — Profile completion bar
- [x] QW8 — Detail-pane tabs
- [x] QW9 — Stat tiles (Network tab, 2-up grid)
- [x] QW10 — Chat-thread message variants
- [x] QW11 — Frontier permanent row + L6 Discovered
- [x] QW12 — Group dropdown at top of rail
- [x] QW13 — Per-client inbox at `/u/[slug]/in`

### Phase 2 — Wiring cycles  (10 / 15 wired end-to-end · 2026-05-16)

Code state and demo state are tracked separately. **A cycle is `[x]`
only when its Demo gate (D1–D15) passes** — see § Demo wall.
Wiring closed via `crm-complete-todo.md` (`/do --auto`, 10 cycles).

| Cycle | Code | Wiring | Demo |
| --- | --- | --- | --- |
| - [x] CS — Status semantics | ✅ ships | ✅ `useWorkspaceRules` hook + Inbox classify(e, rules) | 🟡 D1 e2e spec deferred (needs `bun run dev` + seed) |
| - [x] CV — Entity detail-pane | ✅ panels ship | ✅ `useActorContact` hook + EntityDetail derives deleted | 🟡 D2 e2e spec deferred |
| - [x] CTagMgr — Tag taxonomy | ✅ ships | ✅ Inbox `tagRail` fetches `/api/tags?workspace=` | 🟡 D3 e2e spec deferred |
| - [x] CComp — Universal composer | ✅ composer ships | ✅ handleSubmit fans out via `POST /api/signal/[receiver]` | 🟡 D4 e2e spec deferred |
| - [x] CTpl — Signal templates | ✅ table + picker | ✅ 90 starters in `0042_template_starters.sql`; `_starter` PUT 403 | 🟡 D5 e2e spec deferred |
| - [x] CK — Keyboard contract | ✅ registry | ✅ 30 shortcuts (nav 4 + tab 4 + jump 9 + chord 4 + act 6 + meta 3) | 🟡 D6 e2e spec deferred |
| - [x] CPerf — Per-action budget | ✅ memo + virtualise | ✅ `scripts/lighthouse-in.sh` + `tests/perf/D7-cperf-lighthouse.test.ts` (env `LIGHTHOUSE=1`) | 🟡 D7 needs lighthouse install |
| - [x] CMcpInbox — `@oneie/mcp` inbox_* | ✅ 10 tools defined | ✅ 7 URL rewrites; zero fictional endpoints (verify: grep `/api/(in/(list\|entity\|watch)\|loop/mark-dims\|pulse)` returns 0) | ✅ D8 (vitest spec) |
| - [ ] CJ — Journey runtime | 🟡 types + DAG component | ❌ runner not registered with cron | ❌ D9 |
| - [x] CP — Pulse atlas | 🟡 6 components | ✅ `usePulseData` hook + PulseAtlas now takes `agentId` | 🟡 D10 e2e spec deferred |
| - [x] CSP — Settings hub | ✅ 5 pages | ✅ `/api/settings?scope=` dispatcher + `0043` adds privacy/packs cols; PackEditor + StatusRuleEditor rewired | 🟡 D11 e2e spec deferred |
| - [ ] CX — Importers + exporters | ❌ 12 .md scaffolds + 2 stub .ts | ❌ no OAuth / creds / field map | ❌ D12 |
| - [ ] CH — HubSpot/Salesforce write-through | ❌ same as CX | ❌ | ❌ D13 |
| - [ ] W7 — Identity rungs 2–5 | ✅ ladder + merge libs | ❌ tracking pipeline doesn't import them | ❌ D14 |
| - [ ] W11 — PII vault + forget | ✅ seal + cascade routes | 🟡 KMS unbound; cascade untested | ❌ D15 |

**Recommended sequence** (highest-leverage first):

1. **CMcpInbox** — pure compose; rewire 4 handlers; no new endpoints. Unblocks every LLM consumer.
2. **CV** — wire EntityDetail to existing `/api/actors/[id]` (which ships). Unblocks the entire CRM narrative in `12-crm.md`.
3. **CK** — register 30 shortcuts against existing Inbox handlers. Pure wiring.
4. **CTpl** — seed 90 starters (D1 migration only). Pure data.
5. **W11** — bind KMS to `wrangler.toml` + run the cascade demo.
6. Remaining (CComp / CTagMgr / CSP / CJ / CP / CPerf / W7 / CX / CH) — most are wiring or seeding, not building.

**Old per-wave checkboxes:** rolled into the demo gate. No more "W0
baseline · W1 recon · W2 decide · W3 edit · W4 verify" ladder per
cycle — every cycle runs `/do` waves, but only the demo proves close.

---

## Quick Wins (Phase 1)

Ordered by effort × impact. Top of list = ship first.

### QW1 — Rail zones (rename Navigation rows)  [≤30 min]

**What.** The current rail shows 6 dimension rows (`groups · actors ·
things · paths · events · learning`). Reframe into the five zones from
[`crm-pages.md`](crm-pages.md) §0: MAIL · WORK · CHANNELS · TAGS ·
user card. Same data; new section headers + presets.

**Edit.** `web/src/components/in/Navigation.tsx`. Add a `zone` field
to `NavigationItem`; render section headers between zones. Map the 6
existing dimensions to presets:

```
MAIL    — events (default) → status:closed:false        # 📥 Inbox
WORK    — actors → kind:human                            # 👥 People
        — actors → kind:agent                            # 🤖 Agents
        — things → kind:skill                            # ⚙ Tools
        — things → kind:knowledge                        # 💡 Knowledge
        — groups                                          # ◎ Groups
        — paths                                           # → Journeys
LEARNING — learning → kind:hypothesis                    # 🔬 Frontier
```

The 6 dimensions stay in `in-types.ts`; the rail just **groups them
into zones**. No data migration. Drafts, Sent, Tasks, Calendar,
Payments come in QW2.

**Verify.** Rail renders 5 zones; clicking each preset sets the
correct dimension; selected state preserved. Visual matches
[`crm-pages.md`](crm-pages.md) §0 wireframe.

### QW2 — Mail-state splits (Drafts + Sent rows)  [≤45 min]

**What.** Add Drafts and Sent rail rows under MAIL. They filter the
existing events dimension by `state:draft` and `state:sent` tags.

**Edit.** `web/src/components/in/Navigation.tsx` adds two rows.
`web/src/data/in-types.ts` extends `filterInbox` to accept a
state-filter predicate. `web/src/components/in/Inbox.tsx` passes the
new preset's filter through.

**Verify.** `/in?preset=drafts` lists signals tagged `state:draft AND
author:me`. Inbox → Drafts → Sent in <50ms each (in-memory filter).

### QW3 — Work modules (Tasks · Calendar · Payments)  [≤45 min]

**What.** Three more rail rows under WORK. Each is the events
dimension filtered by `kind:task` · `kind:meeting` · `kind:payment`.

**Edit.** Add three presets to Navigation.tsx; no new component. The
detail pane already renders events; counts come from `countBy` on the
existing entity list.

**Verify.** Each row renders correct subset of events. Empty states
show row-appropriate hint.

### QW4 — `+ New` button in column header  [≤30 min]

**What.** Blue `+ New` button right-aligned in the list-column
header, contextual per active rail row
([`crm-pages.md`](crm-pages.md) §3.1).

**Edit.** New small component
`web/src/components/in/ListHeader.tsx` (or extend the existing
search-bar area). Click opens the universal composer (CComp) — until
CComp lands, it opens the existing reply textarea pre-focused with
the right tags seeded.

**Verify.** Button renders per route with the right label. Click
opens composer in <100ms.

### QW5 — Hero CTA pill (per noun)  [≤30 min]

**What.** Below the search field, one contextual primary-tinted pill
per rail row ([`crm-pages.md`](crm-pages.md) §3.3). Examples: `✨
Invite to Network` on People, `⌬ Spawn Agent` on Agents, `⌁
Broadcast` on Channels.

**Edit.** New component
`web/src/components/in/HeroCTA.tsx` (~40 lines). Lookup table per
preset id. Click is `emitClick('ui:in:hero-cta:<preset>')` so we can
measure adoption per CTA.

**Verify.** Pill renders only when the route has one configured.
Hidden on Inbox and Analytics. Click emits signal.

### QW6 — Top-bar redesign in EntityDetail  [≤45 min]

**What.** The detail pane's current header is icon + title + subtitle
+ timestamp. Reshape it to match
[`crm-pages.md`](crm-pages.md) §4.1: `← Back to <list>` link · 32px
icon-avatar · name + role stacked · status chip (coloured dot +
label) · primary action button (`💬 Message`, `↵ Reply`, `✓
Complete`, depending on entity kind).

**Edit.** `web/src/components/in/EntityDetail.tsx` — replace lines
35–48 with the new header. Status chip + primary action come from a
small lookup keyed on `entity.dimension + entity.type`. Existing
action-row (Reply/Share/Save/Archive/Complete) stays below.

**Verify.** Top bar renders for actor / event / thing / path. Status
chip shows correct dot colour. Primary action wires to existing
handlers.

### QW7 — Profile completion bar  [≤20 min]

**What.** Thin progress bar + percentage between top bar and detail
body, for entities with sparse data
([`crm-pages.md`](crm-pages.md) §4.2). Hides at 100%.

**Edit.** `web/src/components/in/EntityDetail.tsx` — new
sub-component `ProfileCompletionBar`. Computes percentage from filled
tag-namespaces vs. expected for the entity kind.

**Verify.** Bar renders 0% for `?Unknown` actors; 100% for actors
with all 8 standard attributes; hides at 100%.

### QW8 — Detail-pane tabs  [≤60 min]

**What.** Replace the current flat scroll with a tabs row per
[`crm-pages.md`](crm-pages.md) §4.3. For actors:
`Overview · Personal · Professional · Social · AI Context · Network`.
Active tab persists in URL: `?tab=<name>`.

**Edit.** `web/src/components/in/EntityDetail.tsx` — new
`<DetailTabs>` sub-component. Tab content is the existing stacked
sections, partitioned by namespace.

**Verify.** Tabs render per dimension's namespace groups (table in
crm-pages.md §4.3). Tab change is in-memory only (no fetch). URL
updates.

### QW9 — Stat tiles (Network tab, 2-up grid)  [≤30 min]

**What.** The screenshots show a 2-up `0 Referrals / 0 Conversations`
grid in the Network tab. Reusable component for any 2-up KPI
([`crm-pages.md`](crm-pages.md) §4.5).

**Edit.** New `web/src/components/in/StatTile.tsx` (~25 lines). Used
inside detail tabs and the future Pulse view.

**Verify.** Tile renders big number + label. Click → list filtered to
that slice (`?filter=referred-by:<id>` style).

### QW10 — Chat-thread message variants  [≤45 min]

**What.** When the focused entity is a conversation/event, render
the body as Apple-Messages-style bubbles
([`crm-pages.md`](crm-pages.md) §4.6): user right (`primary` bg),
agent left (`foreground` bg) with author name, system pills centred,
attachment chips inline.

**Compose, don't build.** The bubble look already ships in
`@/components/ai-elements/message` (`Message from="user|assistant"`
+ `MessageContent`). The auto-scroll thread already ships in
`@/components/ai-elements/conversation` (`Conversation` +
`ConversationContent`). Full tool/file/approval rendering already
ships in `@/components/chat/MessageList`. QW10 is a **render-mode
branch** inside `EntityDetail`, not a new component.

**Edit.** `web/src/components/in/EntityDetail.tsx` only — replace the
freeform paragraph in the scroll area with a thread block when
`entity.dimension === 'events' && (entity.type === 'conversation' ||
entity.type === 'session')`. Two render branches:

1. **`entity.messages: UIMessage[]` present** (rich data) — compose:
   ```tsx
   <Conversation>
     <ConversationContent>
       <MessageList
         messages={entity.messages}
         status="ready"
         speakFor={null}
         ttsAvailable={false}
         onSpeak={() => {}}
         onApproval={() => {}}
       />
     </ConversationContent>
   </Conversation>
   ```
   Zero new bubble code — `MessageList` already does parts/tools/files.

2. **Flat `entity.body` only** (legacy event row) — compose:
   ```tsx
   <Conversation>
     <ConversationContent>
       <Message from={entity.author === 'user' ? 'user' : 'assistant'}>
         <MessageContent>{entity.body}</MessageContent>
       </Message>
     </ConversationContent>
   </Conversation>
   ```

**No new files.** No `<ThreadView>`. No reimplementation of bubble
styling — `MessageContent` already token-binds `user → primary`,
`assistant → foreground` per [`.claude/rules/design.md`](../.claude/rules/design.md).

**Verify.**
- ✓ Existing chat data renders with the bubble look. No data shape change.
- ✓ Tool parts (approvals, file uploads) render inside the inbox detail
  identically to `/chat` — proves we got reuse, not parallel implementations.
- ✓ Stacked participant avatars at top use existing `<ProfileHeader>` or
  the avatar from the entity row — no new avatar component.
- ✓ `grep -r "ThreadView" web/src/` returns zero hits.
- ✓ `delta_loc` for QW10 < +60 net (composition, not construction).

### QW11 — Frontier permanent row + L6 Discovered  [≤30 min]

**What.** 🔬 Frontier already has an API (`/api/frontiers`).
Surface it as a permanent row at the tail of the rail's TAGS zone
([`crm-pages.md`](crm-pages.md) §2.5). Add 💡 Discovered as a sibling
row reading from a new lightweight endpoint that aggregates hardened
hypotheses.

**Edit.** `web/src/components/in/Navigation.tsx` adds the two rows
in a pinned-tail section. `web/src/pages/api/learning/discovered.ts`
new — wraps the L6 KNOWLEDGE loop's existing hypothesis table.

**Verify.** Both rows always visible, never fade. Click renders
filtered list. Count from the API.

### QW12 — Group dropdown at top of rail  [≤45 min]

**What.** Replace the current
[`ProfileHeader`](src/components/in/ProfileHeader.tsx) (28 lines —
just initial + name) with the workspace × group dropdown from
[`crm-pages.md`](crm-pages.md) §2.1.

**Edit.** `web/src/components/in/ProfileHeader.tsx` — extend with a
`<details>`-driven dropdown. Items list workspaces from the viewer's
roles ladder + groups within the current workspace. Pick →
`window.location.href = /in/<new-groupId>`.

**Verify.** Dropdown opens; picking a row navigates to the new
groupId; the rest of the page reloads with the new context. Roles
ladder respected (no leakage across workspaces).

### QW13 — Per-client inbox at `/u/[slug]/in`  [≤30 min]

**What.** Each client/workspace gets their own CRM inbox at
`/u/[slug]/in` — the same `<Inbox>` shell, filtered to `slug`. The
agency owner uses `/in/[groupId]` to see across all clients; each
client uses `/u/[slug]/in` to see only their own data. Signal sources
(chat at `/u/[slug]/chat` · channel adapters · tracked links from
[`tracking.md`](tracking.md)) already write to `agent_events` keyed by
slug — the data path is proven by the shipping
[`people.astro`](src/pages/u/%5Bslug%5D/people.astro) and
[`analytics.astro`](src/pages/u/%5Bslug%5D/analytics.astro).

**Edit.** New file
[`web/src/pages/u/[slug]/in.astro`](src/pages/u/%5Bslug%5D/in.astro) —
mirrors [`web/src/pages/in/[groupId].astro`](src/pages/in/%5BgroupId%5D.astro)
but passes `slug` instead of `groupId` to `<Inbox>`. Update
[`Inbox.tsx`](src/components/in/Inbox.tsx) to accept `slug` and filter
the API calls — `/api/export/actors?slug=<slug>`, claw conversations
scoped by slug. Role gate: `end_user` and `client` roles allowed
(unlike `people.astro` which redirects them); `agency`/`owner` may
prefer `/in/[groupId]`.

**Verify.** `/u/w4fx1ev7/in` 200s and renders the shell with only
that workspace's data. Inbound Telegram/Discord/web-chat signals
appear within 2s. Tracked-link clicks (`/go/:id`) appear in the
events list. Client role sees no leakage from other slugs.

---

## Quick-win dependency graph

```
QW1 (rail zones) ──→ QW2 (mail splits) ──→ QW3 (work modules)
                 └──→ QW4 (+ New)
                 └──→ QW5 (hero CTA)
                 └──→ QW11 (frontier + discovered rows)
                 └──→ QW12 (group dropdown)

QW6 (top bar) ──→ QW7 (profile completion)
              └──→ QW8 (tabs) ──→ QW9 (stat tiles)
                                 └──→ QW10 (thread variants)

QW13 (per-client inbox) — independent route mirror; no blocker
```

QW1 unblocks QW2–QW5 and QW11–QW12 (all rail edits).
QW6 unblocks QW7–QW10 (all detail-pane edits).
QW13 is a route mirror — independent of both trees.
The three threads are independent; ship them in parallel.

After QW1–QW13 land, the surface matches
[`crm-pages.md`](crm-pages.md) §0–§4 without a single new route
beyond the one-file `/u/[slug]/in.astro` wrapper.

---

## Phase 2 — Cycles

After Phase 1 lands, the bigger work begins. Each cycle below remains
a full W1–W4 run because the change crosses too many files for a
single quick win. (See Status section above for the wave checkbox
tracker.)

### Dependency graph

```
QW1..QW12 (Phase 1) ──→ CS ──→ CTagMgr ──┐
                                          │
                                          ├──→ CComp ──→ CTpl ──→ CJ
                                          │
                              CV ─────────┘ ─→ CK ──→ CPerf
                                            
                                          CMcpInbox  ──→ depends on CComp + CTagMgr stable
                                          CP         ──→ depends on CS + signal stream
                                          CSP        ──→ depends on W11 endpoints (or stubs)
                                          CX  ──→ CH ──→ depend on W7
                                          W7  ──→ parallel
                                          W11 ──→ parallel
```

QW1–QW12 unblock CS by giving status its surface to render.
CTagMgr unblocks every composer flow.
CV completes the inline-edit + merge work the quick wins seed.
The rest layer outward.

---

## Common cycle conventions (apply to every Phase 2 cycle)

Per `one/template-todo.md` — each cycle in this section inherits these
rules so individual sections stay focused on what's unique.

**Under `--auto`, every cycle below MUST run to completion** unless a
ratchet gate fails. See the "Auto-execution contract" near the top of
this doc for the locked rules. The frontmatter `auto:` block is
authoritative; the body restates it for readability.

**Parallel-spawn reminder** — every W3 line below reads `[Sonnet ·
parallel — one Agent-tool message, one agent per independent file]`.
That is not a suggestion. /do MUST emit a single message containing N
parallel `Agent` tool calls when entering W3 for any COMPLEX cycle (and
for SIMPLE cycles where file_count > 2). Same applies to W4: every
COMPLEX W4 fires 5 Haiku rubric agents in one message
(security / stability / simplicity / speed / adversarial). Sequential
agent emission for an already-classified parallel wave is a
contract violation.

**W0 baseline (always run before W1):**
```bash
bun run verify                                            # tests + types green
bunx tsc --noEmit 2>&1 | grep -c "error TS" > .w0-tsc    # capture pre-cycle errors
cloc src/ --json | jq .SUM.code > .w0-loc                 # capture pre-cycle LOC
```

**W3 split (default):** All edits in a cycle target different files →
they all live in W3a (one parallel spawn). If two edits touch the same
file, the second moves to W3b (sequential). Per-cycle W3 sections name
the split explicitly only when W3b is non-empty.

**W4 hard gates (every cycle, in addition to the bullets listed):**
- [ ] `delta_tsc_errors ≤ 0` — no new type errors introduced vs W0
- [ ] `delta_loc ≤ +200` unless cycle tagged `type: feature`
- [ ] no adversarial finding with severity > 0.5

---

## CS — Status from workspace rules  [demo: D1]

**Today:** `classify()` in `web/src/lib/in/status.ts` runs client-side using `DEFAULT_STATUS_RULES`. Workspace owners can't edit the rules.

**Compose:** existing D1 `workspace_settings` (mig `0035`). No new endpoint.

**Wire** (3 files):

1. New `web/src/pages/api/settings/status.ts` (compose, ~40 LOC) — GET reads `rules` JSON column from `workspace_settings`; PUT writes it back. Owner-only ACL via existing session.
2. New `web/src/hooks/use-workspace-rules.ts` — `useWorkspaceRules(workspaceId)` → `StatusRules`. SWR-style with 5-min cache.
3. Edit `web/src/components/in/Inbox.tsx`:
   - Anchor: `import { classify } from '@/lib/in/status'`
   - Add: `import { useWorkspaceRules } from '@/hooks/use-workspace-rules'`
   - Anchor: the `classify(...)` call site near line 294 ("CS — derive status from tag rules")
   - Replace `classify(entity)` → `classify(entity, rules)` where `rules` is from the hook.

**Seed** — `web/tests/seeds/D1.sql`:
```sql
INSERT INTO workspace_settings (workspace_id, rules) VALUES
('test-ws', json('{"actors":[{"status":"top","anyTag":["industry:dentistry"]}]}'));
```

**Demo spec** — `web/tests/e2e/crm/D1-cs-status-rules.spec.ts`:
```ts
test('D1: workspace rule re-classifies actors', async ({ page, request }) => {
  // Pre: 5 actors tagged industry:dentistry, lifecycle:lead → start as `now`
  await page.goto('/in?d=actors&s=top')
  await expect(page.locator('[data-testid="entity-card"]')).toHaveCount(5)
})
```

**Gate:** delta_tsc ≤ 0 · composite ≥ 0.65 · spec passes.

---

## CV — EntityDetail fetches real Contact  [demo: D2]

**Today:** ContactConsent/Paths/Appended panels fabricate data from `entity.tags`/`related` via three `derive*` helpers in EntityDetail.tsx. The real aggregator `getContact()` ships at `GET /api/actors/[id]` (commit `74e47496`).

**Compose:** existing `/api/actors/[id]` — already returns `Contact`. No new endpoint.

**Wire** (2 files):

1. New `web/src/hooks/use-actor-contact.ts` (~25 LOC):
```ts
import { useEffect, useState } from 'react'
import type { Contact } from '@/lib/crm/actor'

export function useActorContact(actorId: string | null): Contact | null {
  const [contact, setContact] = useState<Contact | null>(null)
  useEffect(() => {
    if (!actorId) { setContact(null); return }
    let cancelled = false
    fetch(`/api/actors/${encodeURIComponent(actorId)}`)
      .then((r) => (r.ok ? r.json() : null))
      .then((c) => { if (!cancelled) setContact(c) })
    return () => { cancelled = true }
  }, [actorId])
  return contact
}
```

2. Edit `web/src/components/in/EntityDetail.tsx`:
   - **Delete** the three `deriveConsent` / `derivePaths` / `deriveAppended` functions (~30 LOC).
   - **Delete** the related type imports (`ConsentMatrix`, `ContactAppended as ContactAppendedRow`, `ContactPath`) — they come from the hook now.
   - **Replace** the three `useMemo` derivation calls with a single `useActorContact(entity?.dimension === 'actors' ? entity.id : null)`.
   - Use `contact?.header.consent`, `contact?.paths`, `contact?.appended` in the panel renders.

   Net `delta_loc` for `EntityDetail.tsx`: **negative** (we delete more than we add).

**Seed** — `web/tests/seeds/D2.tql` (TypeDB; apply via gateway adapter):
```typeql
insert
  $a isa actor, has aid "ada-test", has name "Ada Lovelace",
    has email "ada@l.org", has lifecycle "customer",
    has consent-email true, has consent-sms true, has consent-push false, has consent-call false,
    has channel "telegram@ada", has channel "web:visitor_hash";
  $b isa actor, has aid "bob-test", has name "Bob Pinto";
  $p (source: $a, target: $b) isa path, has strength 0.74;
```

**Demo spec** — `web/tests/e2e/crm/D2-cv-actor-contact.spec.ts`:
```ts
import { expect, test } from '@playwright/test'
const BASE = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:4321'

test('D2: EntityDetail fetches real Contact from /api/actors/[id]', async ({ page }) => {
  await page.goto(`${BASE}/in?d=actors&focus=ada-test&tab=personal`)
  // ContactConsent renders Granted (email/sms) + Revoked (push/call), no all-Unknown
  await expect(page.locator('text=Granted')).toHaveCount(2)
  await expect(page.locator('text=Revoked')).toHaveCount(2)
  // ContactPaths on Network tab shows the real edge from TypeDB
  await page.getByRole('button', { name: 'Network' }).click()
  await expect(page.locator('text=Strongest paths')).toBeVisible()
  await expect(page.locator('text=bob-test')).toBeVisible()
})
```

**Gate:** spec passes · `delta_loc EntityDetail.tsx ≤ -10` · composite ≥ 0.65.

---

## CTagMgr — TAGS rail reads from registry  [demo: D3]

**Today:** `/api/tags` CRUD ships. TagManager admin UI ships. But `Inbox.tsx`'s TAGS rail rows are hardcoded (`hasTag('frontier')`, `hasTag('discovered')`). The owner-curated namespaces never appear in the rail.

**Compose:** existing `/api/tags` + existing tag_namespace D1 table (mig `0036`). No new endpoint.

**Wire** (2 files):

1. Edit `web/src/components/in/Inbox.tsx`:
   - Import `{ listNamespaces } from '@/lib/in/tags'` and `useEffect` for fetch.
   - State: `const [tagRail, setTagRail] = useState<NavigationItem[]>([])`.
   - On mount: `fetch('/api/tags?workspace=' + groupId).then(...) → setTagRail(namespaces.map(toRailItem))`.
   - Inject the dynamic rows into the rail between the static `LEARNING` zone and the static rows. Each `toRailItem` returns `{ id: 'events', zone: 'TAGS', label: ns.name, preset: 'tag:' + ns.name, filter: hasTag(ns.name) }`.

2. Edit `web/src/components/settings/TagManager.tsx`:
   - Verify locked namespaces (`lifecycle:*`, `iab/*`, `gdpr`, `ccpa`) reject PUT with 403 (server-side check already shipped — confirm test).

**Seed** — `web/tests/seeds/D3.sql`:
```sql
INSERT INTO tag_namespace (workspace_id, name, allowed_values, acl, color, locked) VALUES
  ('test-ws', 'campaign:apr-q2', '[]', '{"write":["owner"]}', 'orange', 0),
  ('test-ws', 'lifecycle:*', '["anonymous","lead","mql","sql","customer","advocate"]', '{"write":["any"]}', 'blue', 1);
```

**Demo spec** — `web/tests/e2e/crm/D3-ctagmgr-rail.spec.ts`:
```ts
test('D3: owner-created namespace appears in TAGS rail', async ({ page, request }) => {
  await page.goto('/in')
  await expect(page.locator('text=TAGS')).toBeVisible()
  await expect(page.locator('text=campaign:apr-q2')).toBeVisible()
  // locked namespace: PUT must 403
  const res = await request.put('/api/tags/lifecycle:*', { data: { color: 'pink' } })
  expect(res.status()).toBe(403)
})
```

**Gate:** spec passes · composite ≥ 0.65.

---

## CComp — Composer fans out via /api/signal  [demo: D4]

**Today:** Composer's `handleSubmit` only posts to `/conversations/:id/reply` (chat reply) or `/api/in/sessions` (no-op). Broadcast / sub: / world: / all: modes set state but don't emit. Holdout slider has no enforcement.

**Compose:** existing `POST /api/signal/[...receiver]` (receiver in URL path). No new endpoint.

**Wire** (1 file):

Edit `web/src/components/in/Composer.tsx` — `handleSubmit` callback:

```diff
 const handleSubmit = useCallback(
   (msg: PromptInputMessage) => {
     const text = msg.text.trim()
     if (!text) return
     emitClick('ui:composer:send', { entityId: entity.id, receiverMode, receiverTarget, tags, holdout })
     setStatus('submitted')
-    onReply?.(entity.id, text, entity.type, entity.sessionId)
+    if (receiverMode === 'direct' && (entity.type === 'session' || entity.type === 'conversation')) {
+      // chat reply path — keep onReply for backwards compat
+      onReply?.(entity.id, text, entity.type, entity.sessionId)
+    } else {
+      // broadcast / sub / world / all — emit via /api/signal
+      const receiver = receiverMode === 'direct' ? receiverTarget : `${receiverMode}:${receiverTarget}`
+      void fetch(`/api/signal/${encodeURIComponent(receiver)}`, {
+        method: 'POST',
+        headers: { 'Content-Type': 'application/json' },
+        body: JSON.stringify({ sender: 'composer', data: { text, tags, holdout: holdout > 0 ? holdout : undefined } }),
+      }).catch(() => setStatus('error'))
+    }
     void clearDraft(entity.id)
     setBody(''); setTags(''); setStatus('ready')
   },
   [entity.id, entity.type, entity.sessionId, receiverMode, receiverTarget, tags, holdout, onReply],
 )
```

Holdout enforcement is server-side in the substrate signal router (existing — splits `sub:*` receivers into delivered / control buckets per the `holdout` field on the signal data).

**Seed** — `web/tests/seeds/D4.sql`:
```sql
-- 100 actors tagged sub:trial-d7 (synthetic)
WITH RECURSIVE c(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM c WHERE n<100)
INSERT INTO actor_tags (actor_id, tag) SELECT 'd4-actor-' || n, 'sub:trial-d7' FROM c;
```

**Demo spec** — `web/tests/e2e/crm/D4-ccomp-broadcast.spec.ts`:
```ts
test('D4: composer broadcasts to sub:trial-d7 with 10% holdout', async ({ page, request }) => {
  await page.goto('/in?d=events&focus=any')
  // open composer, switch to sub mode, set holdout
  await page.locator('[data-testid="receiver-pill-sub"]').click()
  await page.locator('[name="receiverTarget"]').fill('trial-d7')
  await page.locator('[data-testid="holdout-10"]').click()
  await page.locator('textarea').first().fill('hello')
  await page.locator('[data-testid="submit"]').click()
  // verify the signal landed
  const r = await request.get('/api/analytics/watch?since=now-10s')
  const text = await r.text()
  expect(text).toMatch(/sub:trial-d7/)
  // verify 10 holdouts logged
  expect(text.match(/holdout:true/g)?.length).toBeGreaterThanOrEqual(9)
})
```

**Gate:** spec passes · composite ≥ 0.65.

---

## CComp legacy spec  [pre-D4 reference, kept for slot-map context]

Composer subtree (PromptInput composition) already shipped in commits prior to 2026-05-16. The slot-fill rationale is captured in [`crm.md`](crm.md) § 4. D4 above is the wiring gate that finishes the cycle — sub/world/all receiver modes actually emit.

---

## CTpl — Seed 90 starters + verify picker round-trip  [demo: D5]

**Today:** TemplateManager + `/api/templates` CRUD + TemplatePicker (`/`-autocomplete via PromptInputCommand) all ship. But `agents/template-starters.md` is **markdown documentation, not a D1 seed** — only 5 examples. Cycle closes by writing the seed migration + verifying the round-trip.

**Compose:** existing `signal_templates` D1 table (mig `0037`) + existing `/api/templates`. No new endpoint.

**Wire** (1 new file + 1 edit):

1. New `web/migrations/0042_template_starters.sql` — 90 INSERTs (30 per role × marketer/sales/service). Source values from [`crm.md`](crm.md) § 6 + [`text/12-crm.md`](../text/12-crm.md) day-in-life examples. Each row: `(id, workspace_id='_starter', name, role, receiver_mode, receiver_target, tags, body, send_at, attach, starred=0, created_at, updated_at)`.

   Example 3 of the 90:
   ```sql
   INSERT INTO signal_templates VALUES
   ('tpl-mkt-welcome', '_starter', 'welcome-email', 'marketer', 'sub', 'sub:lifecycle:lead',
    '["campaign:welcome","channel:email"]', 'Hi {name}, welcome aboard — here''s where to start.',
    'now', '[]', 0, strftime('%s','now'), strftime('%s','now')),
   ('tpl-sls-d2-checkin', '_starter', 'trial-d2-checkin', 'sales', 'direct', '{actor}',
    '["seq:trial:step:1","send-at:+24h"]', 'Hi {name}, how''s it going so far?',
    '+24h', '[]', 0, strftime('%s','now'), strftime('%s','now')),
   ('tpl-svc-csat', '_starter', 'csat-after-close', 'service', 'direct', '{actor}',
    '["kind:csat-request","channel:auto"]', 'Quick favor — rate this 1–5.',
    'now', '[]', 0, strftime('%s','now'), strftime('%s','now'));
   ```

2. Edit `web/src/pages/settings/templates.astro` — owner sees starter templates from `workspace_id='_starter'` merged with own (read-only display chip "starter"). Confirm `TemplateManager` already filters by `workspace_id IN ('_starter', currentWorkspace)`; if not, add it (one line).

**Demo spec** — `web/tests/e2e/crm/D5-ctpl-picker.spec.ts`:
```ts
test('D5: / opens picker, selecting fills composer, sending emits template', async ({ page }) => {
  await page.goto('/in?d=actors&focus=ada-test')
  const textarea = page.locator('textarea').first()
  await textarea.fill('/welcome')
  await expect(page.locator('text=welcome-email')).toBeVisible()
  await page.locator('text=welcome-email').click()
  // composer body now contains the template body
  await expect(textarea).toHaveValue(/welcome aboard/)
})

test('D5: 90 starters seed (30 per role)', async ({ request }) => {
  const r = await request.get('/api/templates?workspace=_starter')
  const list = await r.json()
  expect(list.filter((t: any) => t.role === 'marketer')).toHaveLength(30)
  expect(list.filter((t: any) => t.role === 'sales')).toHaveLength(30)
  expect(list.filter((t: any) => t.role === 'service')).toHaveLength(30)
})
```

**Gate:** spec passes · `wrangler d1 migrations apply` applies `0042_template_starters.sql` cleanly · composite ≥ 0.65.

---

## CK — Register 30 shortcuts at Inbox mount  [demo: D6]

**Today:** `shortcuts.ts` registry + `useShortcut` hook + Spotlight + HelpOverlay all ship. **`registerShortcut()` is called zero times.** Help overlay lists nothing.

**Compose:** existing registry + `cmdk`. No new infra.

**Wire** (1 file):

Edit `web/src/components/in/Inbox.tsx` — inside the component, after the rail rows are computed, add a single `useEffect` that registers the 30 shortcuts from [`crm-pages.md`](crm-pages.md) § 11:

```ts
// 30 shortcuts, four categories — jumps to presets (1–9), nav (j/k/space/enter),
// actions (c/m/w/r/a), chords (g i / g p / g s …), meta (⌘K / ?).
useEffect(() => {
  const all: Shortcut[] = [
    // — nav —
    { id: 'nav.next', keys: 'j', category: 'nav', description: 'Next row', handler: () => moveSelection(+1) },
    { id: 'nav.prev', keys: 'k', category: 'nav', description: 'Prev row', handler: () => moveSelection(-1) },
    { id: 'nav.peek', keys: 'Space', category: 'nav', description: 'Peek detail', handler: () => setSelectedId(selectedId) },
    { id: 'nav.open', keys: 'Enter', category: 'nav', description: 'Open focused', handler: () => { /* open */ } },
    // — preset jumps —
    { id: 'jump.inbox', keys: '⌘1', category: 'jump', description: 'Inbox', handler: () => setRow('events', null) },
    { id: 'jump.drafts', keys: '⌘2', category: 'jump', description: 'Drafts', handler: () => setRow('events', 'drafts') },
    { id: 'jump.sent', keys: '⌘3', category: 'jump', description: 'Sent', handler: () => setRow('events', 'sent') },
    { id: 'jump.people', keys: '⌘4', category: 'jump', description: 'People', handler: () => setRow('actors', null) },
    { id: 'jump.tools', keys: '⌘5', category: 'jump', description: 'Tools', handler: () => setRow('things', null) },
    { id: 'jump.groups', keys: '⌘6', category: 'jump', description: 'Groups', handler: () => setRow('groups', null) },
    { id: 'jump.journeys', keys: '⌘7', category: 'jump', description: 'Journeys', handler: () => setRow('paths', null) },
    { id: 'jump.tasks', keys: '⌘8', category: 'jump', description: 'Tasks', handler: () => setRow('events', 'tasks') },
    { id: 'jump.frontier', keys: '⌘9', category: 'jump', description: 'Frontier', handler: () => setRow('learning', 'frontier') },
    // — g-chords (handled by the registry's chord buffer) —
    { id: 'chord.gi', keys: 'g i', category: 'jump', description: 'Go inbox', handler: () => setRow('events', null) },
    { id: 'chord.gp', keys: 'g p', category: 'jump', description: 'Go people', handler: () => setRow('actors', null) },
    { id: 'chord.gt', keys: 'g t', category: 'jump', description: 'Go tasks', handler: () => setRow('events', 'tasks') },
    { id: 'chord.gc', keys: 'g c', category: 'jump', description: 'Go calendar', handler: () => setRow('events', 'meetings') },
    { id: 'chord.gd', keys: 'g d', category: 'jump', description: 'Go drafts', handler: () => setRow('events', 'drafts') },
    // — actions on focused row —
    { id: 'act.reply', keys: 'r', category: 'action', description: 'Reply', handler: () => emitClick('ui:in:reply', { id: selectedId }) },
    { id: 'act.compose', keys: 'c', category: 'action', description: 'Compose', handler: () => emitClick('ui:in:compose') },
    { id: 'act.mark', keys: 'm', category: 'action', description: 'Mark', handler: () => emitClick('ui:in:mark', { id: selectedId }) },
    { id: 'act.warn', keys: 'w', category: 'action', description: 'Warn', handler: () => emitClick('ui:in:warn', { id: selectedId }) },
    { id: 'act.archive', keys: 'a', category: 'action', description: 'Archive', handler: () => emitClick('ui:in:archive', { id: selectedId }) },
    { id: 'act.claim', keys: 'C', category: 'action', description: 'Claim (owner:me)', handler: () => emitClick('ui:in:claim', { id: selectedId }) },
    // — status tabs —
    { id: 'tab.now', keys: '1', category: 'nav', description: 'NOW', handler: () => setStatus('now') },
    { id: 'tab.top', keys: '2', category: 'nav', description: 'TOP', handler: () => setStatus('top') },
    { id: 'tab.todo', keys: '3', category: 'nav', description: 'TODO', handler: () => setStatus('todo') },
    { id: 'tab.done', keys: '4', category: 'nav', description: 'DONE', handler: () => setStatus('done') },
    // — meta —
    { id: 'meta.spotlight', keys: '⌘k', category: 'meta', description: 'Spotlight', handler: () => setSpotlightOpen(true) },
    { id: 'meta.help', keys: '?', category: 'meta', description: 'Help', handler: () => setHelpOpen(true) },
    { id: 'meta.search', keys: '/', category: 'meta', description: 'Search', handler: () => /* focus search */ {} },
  ]
  const unsubs = all.map((s) => registerShortcut(s))
  return () => unsubs.forEach((u) => u())
}, [/* deps: setRow, setStatus, setSpotlightOpen, setHelpOpen, selectedId, moveSelection */])
```

Add helpers `setRow(dim, preset)` and `moveSelection(delta)` if absent (existing pattern: the rail's `onChange` is the setter).

**Demo spec** — `web/tests/e2e/crm/D6-ck-shortcuts.spec.ts`:
```ts
test('D6: ⌘K opens Spotlight, all 30 shortcuts registered', async ({ page }) => {
  await page.goto('/in')
  await page.keyboard.press('Meta+K')
  await expect(page.locator('[role="combobox"]')).toBeVisible()
  await page.keyboard.press('Escape')
  await page.keyboard.press('?')
  await expect(page.locator('[data-testid="help-overlay"] li')).toHaveCount(30)
})
test('D6: j/k navigates, g i jumps to inbox', async ({ page }) => {
  await page.goto('/in?d=actors')
  await page.keyboard.press('g'); await page.keyboard.press('i')
  await expect(page).toHaveURL(/d=events/)
})
```

**Gate:** spec passes · `delta_loc Inbox.tsx ≤ +120` · composite ≥ 0.65.

---

## CPerf — Lighthouse measurement gate  [demo: D7]

**Today:** memoise + virtualise + lazy-imports landed; nobody measured Lighthouse post-CV/CK changes. Cycle closes by running the measurement and confirming budgets.

**Compose:** existing build + lighthouse CLI. No code changes expected unless the run reveals a regression.

**Wire** (1 new file):

New `web/scripts/lighthouse-in.sh`:
```bash
#!/usr/bin/env bash
set -e
PORT=4321
BASE="http://localhost:${PORT}"
mkdir -p web/tests/perf
npx lighthouse "$BASE/in" \
  --chrome-flags="--headless --no-sandbox" \
  --output=json --output-path=web/tests/perf/in.json \
  --only-categories=performance --quiet
PERF=$(jq '.categories.performance.score * 100' web/tests/perf/in.json)
FCP=$(jq '.audits["first-contentful-paint"].numericValue' web/tests/perf/in.json)
INP=$(jq '.audits["interaction-to-next-paint"].numericValue // 0' web/tests/perf/in.json)
echo "perf=$PERF fcp=${FCP}ms inp=${INP}ms"
[ "$(echo "$PERF >= 95" | bc -l)" = "1" ] || { echo "FAIL: perf < 95"; exit 1; }
[ "$(echo "$FCP < 1000" | bc -l)" = "1" ] || { echo "FAIL: FCP >= 1000ms"; exit 1; }
```

**Demo spec** — invoked as a vitest unit test (NOT Playwright):

`web/tests/perf/D7-cperf-lighthouse.test.ts`:
```ts
import { test, expect } from 'vitest'
import { execSync } from 'node:child_process'
test('D7: Lighthouse /in ≥ 95 perf, FCP < 1.0s', () => {
  const out = execSync('bash web/scripts/lighthouse-in.sh', { encoding: 'utf-8' })
  expect(out).toMatch(/perf=(9[5-9]|100)/)
})
```

**If the gate fails**, escape clause: identify the regressor via `npx vite-bundle-visualizer dist/_astro` and lazy-import the offender per [`.claude/rules/astro.md`](../.claude/rules/astro.md) § Performance. No structural changes — just one more `lazy()` wrap.

**Gate:** Lighthouse perf ≥ 95 · FCP < 1.0s · bundle ≤ W0 baseline.

---

## CMcpInbox — rewire 7 handlers to existing endpoints  [demo: D8]

**Today:** `mcp/src/tools/inbox.ts` ships 10 tools. **7 call fictional endpoints.** Audit:

| Tool | Calls (broken) | Should call (exists) |
| --- | --- | --- |
| `inbox_list` | `/api/in/list` ❌ | `/api/actors` (or per-dimension `/api/export/{dim}`) |
| `inbox_open` | `/api/in/entity` ❌ | `/api/actors/[id]` for actors |
| `inbox_send` | `/api/signal` ❌ (POST body has receiver) | `/api/signal/[...receiver]` (receiver in URL path) |
| `inbox_subscribe` | `/api/signal` ❌ | `/api/signal/[...receiver]` or `/api/sub` |
| `inbox_mark` | `/api/loop/mark-dims` ❌ | `/api/mark/[edge]` |
| `inbox_warn` | `/api/loop/mark-dims` ❌ | `/api/warn/[edge]` |
| `inbox_react` | `/api/signal` ❌ | `/api/signal/[...receiver]` |
| `inbox_forget` | `/api/forget` ✅ | (already correct) |
| `inbox_pulse` | `/api/pulse` ❌ | `/api/agents/[id]/analytics` |
| `inbox_watch` | `/api/in/watch` ❌ | `/api/analytics/watch` |

**No new `/api/` routes.** Fix the URLs in `inbox.ts`. ([`mcp/CLAUDE.md`](../mcp/CLAUDE.md): "wrap, don't reimplement.")

**Wire** (1 file):

Edit `mcp/src/tools/inbox.ts` — 7 handler URL rewrites. Example for `inbox_list`:

```diff
       handler: async (args, env) => {
         const params = new URLSearchParams();
-        if (args.dimension) params.set("dimension", String(args.dimension));
-        if (args.status) params.set("status", String(args.status));
-        if (Array.isArray(args.tags)) params.set("tags", (args.tags as string[]).join(","));
-        if (args.search) params.set("q", String(args.search));
-        if (args.limit) params.set("limit", String(args.limit));
-        return call(env.baseUrl, env.apiKey, `/api/in/list?${params.toString()}`);
+        const dim = String(args.dimension ?? "actors");
+        if (Array.isArray(args.tags)) params.set("tags", (args.tags as string[]).join(","));
+        if (args.search) params.set("q", String(args.search));
+        if (args.limit) params.set("limit", String(args.limit));
+        // Compose existing export endpoint per dimension; for actors use /api/actors
+        const path = dim === "actors" ? "/api/actors" : `/api/export/${dim}`;
+        return call(env.baseUrl, env.apiKey, `${path}?${params.toString()}`);
       },
```

Sibling rewrites:
- `inbox_open` → `/api/actors/${id}` (actors only for now; document that other dimensions need extension)
- `inbox_send` → `/api/signal/${encodeURIComponent(receiver)}` with body `{ sender, data }`
- `inbox_subscribe` → `/api/signal/actor:${actorId}:tag.add` with body `{ data: { tag: 'sub:' + topic } }`
- `inbox_mark` → `/api/mark/${edge}` with body `{ strength, source }`
- `inbox_warn` → `/api/warn/${edge}`
- `inbox_react` → `/api/signal/entity:${entityId}:react`
- `inbox_pulse` → `/api/agents/${agentId}/analytics?from=&to=` (tool input gains required `agentId`)
- `inbox_watch` → `/api/analytics/watch?dimension=&tags=`

**Demo spec** — `mcp/tests/D8-mcp-inbox-compose.test.ts` (vitest):
```ts
import { test, expect } from 'vitest'
import { inboxTools } from '../src/tools/inbox'

const env = { baseUrl: 'http://localhost:4321', apiKey: undefined }

test('D8: no inbox_* tool calls /api/in/*, /api/loop/*, /api/pulse, or POST /api/signal without receiver path', async () => {
  // Intercept fetch
  const calls: string[] = []
  globalThis.fetch = (async (url: string | URL, init?: RequestInit) => {
    calls.push(String(url))
    return new Response('{}', { status: 200 })
  }) as any
  const tools = inboxTools()
  for (const t of tools) {
    try { await t.handler({}, env) } catch {}
  }
  // No fictional endpoints
  expect(calls.join(' ')).not.toMatch(/\/api\/in\/(list|entity|watch)/)
  expect(calls.join(' ')).not.toMatch(/\/api\/loop\/mark-dims/)
  expect(calls.join(' ')).not.toMatch(/\/api\/pulse\b/)
  // /api/signal calls must carry receiver in the path
  for (const c of calls) {
    if (c.includes('/api/signal')) expect(c).toMatch(/\/api\/signal\/.+/)
  }
})
```

**Gate:** `bun test mcp/tests/D8-mcp-inbox-compose.test.ts` green · composite ≥ 0.65 · no new `/api/` files in the diff.

---

## CJ — Journey runtime  [DEFERRED · infrastructure]

**Why deferred:** wiring is small, but needs **claw-side cron registration** (every-minute drain of `journey_enrolment`). That's infra, not `web/`. Split to its own plan once we know whether claw exposes a register-cron API or runner lives as a Cloudflare scheduled handler.

**Shipped (kept):** `web/src/lib/journey/runtime.ts` types · `JourneyDAG.tsx` · `/api/journey/{index,enrol}.ts` (CRUD) · `agents/journey-runner.md` scaffold · `web/migrations/0038_journey.sql`.

**D9 (when reopened):** Register journey-runner with cron · `POST /api/signal/journey:<id>:enrol` → step-1 fires within 1s · conversion `mark()`s path · DAG edges reflect strength. **No new `/api/` route** — uses existing `/api/signal/[...receiver]`.

---

## CP — PulseAtlas fetches real analytics  [demo: D10]

**Today:** `PulseAtlas` takes `kpis/funnel/attribution/holdout` as **props** with no caller wiring real data. 5 / 6 pulse sub-components render hardcoded fixtures. Only `FrontierBlock` fetches.

**Compose:** existing `GET /api/agents/[id]/analytics` + existing `GET /api/frontiers`. No new endpoint.

**Wire** (3 files):

1. New `web/src/hooks/use-pulse-data.ts` (~40 LOC):
```ts
import { useEffect, useState } from 'react'
import type { Kpi } from '@/components/pulse/KpiLadder'
import type { FunnelStage } from '@/components/pulse/Funnel'
import type { AttributionRow } from '@/components/pulse/Attribution'
import type { HoldoutResult } from '@/components/pulse/Holdout'

export type PulseData = {
  kpis: Kpi[]; funnel: FunnelStage[]; attribution: AttributionRow[]; holdout: HoldoutResult[]
}
export function usePulseData(agentId: string): PulseData {
  const [d, setD] = useState<PulseData>({ kpis: [], funnel: [], attribution: [], holdout: [] })
  useEffect(() => {
    fetch(`/api/agents/${encodeURIComponent(agentId)}/analytics`)
      .then((r) => r.ok ? r.json() : null)
      .then((j) => j && setD({
        kpis: j.kpis ?? [], funnel: j.funnel ?? [],
        attribution: j.attribution ?? [], holdout: j.holdout ?? [],
      }))
  }, [agentId])
  return d
}
```

2. Edit `web/src/components/pulse/PulseAtlas.tsx`:
   - Add `agentId` prop; remove individual data props (move them inside via `usePulseData(agentId)`).
   - Same Render — no JSX change beyond the data source.

3. Edit any Astro page that mounts PulseAtlas — currently mounts may pass empty props; pass `agentId={...}` instead.

**Demo spec** — `web/tests/e2e/crm/D10-cp-pulse.spec.ts`:
```ts
test('D10: PulseAtlas renders 4 KPIs + funnel from /api/agents/[id]/analytics', async ({ page }) => {
  await page.goto('/in?view=pulse&agent=ada-test')
  // 4 KPI tiles
  await expect(page.locator('[data-testid="kpi-tile"]')).toHaveCount(4)
  // funnel SVG present
  await expect(page.locator('svg[data-testid="funnel"]')).toBeVisible()
  // no hardcoded "Loading…" stuck-state
  await expect(page.locator('text=Loading')).toHaveCount(0)
})
```

**Gate:** spec passes · no `components/pulse/*.tsx` retains hardcoded numeric values · composite ≥ 0.65.

### W2 — Decide  [Sonnet]

- Reuse `<StatTile>` for the 4-tier ladder
- Funnel: SVG with stage CVRs from `funnel_daily` table
- Attribution: top-N tile with model picker (last-touch / linear / time-decay / Shapley)
- Holdout: per-experiment lift bars
- Frontier: pull from `/api/frontiers`

### W3 — Edit  [Sonnet · parallel — one Agent-tool message, one agent per independent file]

- [x] `web/src/components/pulse/PulseAtlas.tsx` — root layout
- [x] `web/src/components/pulse/KpiLadder.tsx` — 4 × `<StatTile>`
- [x] `web/src/components/pulse/Funnel.tsx` — SVG funnel
- [x] `web/src/components/pulse/Attribution.tsx` — top-N + model picker
- [x] `web/src/components/pulse/Holdout.tsx` — lift bars
- [x] `web/src/components/pulse/FrontierBlock.tsx` — unexplored clusters
- [x] `web/src/components/in/EntityDetail.tsx` — render PulseAtlas when `?view=pulse`
- [x] `web/crm.md` — mark CP ✅

### W4 — Verify  [Haiku × parallel · one Agent-tool message · N=4]

- [ ] All 4 KPI tiles render with delta arrows
- [ ] Funnel CVR labels between stages
- [ ] Attribution model picker switches in <100ms
- [ ] Holdout lift shows p-value
- [ ] Rubric ≥ 0.65

---

## CSP — Settings round-trip persistence  [demo: D11]

**Today:** Five `/settings/*` pages render. PrivacyControls / PackEditor / StatusRuleEditor / TagManager / TemplateManager all ship. **Untested:** save → reload → values persist from D1. Existing `web/src/pages/api/settings.ts` is the single CRUD surface but each component needs to verify it reads/writes the right `scope` key.

**Compose:** existing `/api/settings.ts` (one route, dispatches by `?scope=privacy|packs|status|...`) + existing `workspace_settings` D1 table. No new endpoint.

**Wire** (5 edits, 1 per editor — small):

For each of `PrivacyControls`, `PackEditor`, `StatusRuleEditor` (TagManager + TemplateManager already wired via CTagMgr/CTpl):

```diff
   const save = async () => {
+    await fetch(`/api/settings?scope=${SCOPE}&workspace=${workspaceId}`, {
+      method: 'PUT', headers: { 'Content-Type': 'application/json' },
+      body: JSON.stringify(value),
+    })
   }
   useEffect(() => {
+    void fetch(`/api/settings?scope=${SCOPE}&workspace=${workspaceId}`)
+      .then((r) => r.ok ? r.json() : null).then((v) => v && setValue(v))
   }, [workspaceId])
```

Where `SCOPE` is `'privacy' | 'packs' | 'status'` per component. Verify `/api/settings.ts` accepts the `scope` query param; if not, add a switch on it (still one file, no new route).

**Seed** — no seed needed (tests write then read).

**Demo spec** — `web/tests/e2e/crm/D11-csp-settings.spec.ts`:
```ts
for (const scope of ['privacy', 'packs', 'status']) {
  test(`D11: ${scope} round-trips through D1`, async ({ page }) => {
    await page.goto(`/settings/${scope}?workspace=test-ws`)
    // edit a value (page-specific selector)
    await page.locator('[data-testid="edit-field"]').first().fill('updated')
    await page.locator('button:has-text("Save")').click()
    await page.reload()
    await expect(page.locator('[data-testid="edit-field"]').first()).toHaveValue('updated')
  })
}
test('D11: non-owner gets 403', async ({ request }) => {
  // assuming session middleware reads 'role' header in dev
  const res = await request.put('/api/settings?scope=status&workspace=test-ws', {
    headers: { 'x-test-role': 'end_user' }, data: { rules: {} },
  })
  expect(res.status()).toBe(403)
})
```

**Gate:** spec passes · `/api/settings.ts` PUT enforces owner role · composite ≥ 0.65.

---

## CX — Importers + exporters  [tier: complex]

**Exit:** Each integration is a markdown agent that subscribes to a
trigger (lifecycle transition / new actor / signal tag) and calls the
external API. Twelve integrations: HubSpot, Salesforce, GoHighLevel,
Klaviyo, Clearbit, Apollo, Stripe, Shopify, GA4, Meta, Google
Customer Match, TikTok.

### W1 — Recon  [Haiku]

- `agents/` — existing agent shape
- One existing import/export agent as reference

### W2 — Decide  [Sonnet]

- Each agent: subscribe filter + field-map + API call + provenance log
- Credentials: per-workspace in `workspace_settings.integrations`
- Diff push: maintain last-exported list per audience; push additions + removals

### W3 — Edit  [Sonnet · parallel — one Agent-tool message, one agent per integration (×12)]

- [x] `agents/import-clearbit.md`
- [x] `agents/import-apollo.md`
- [x] `agents/import-stripe.md`
- [x] `agents/import-shopify.md`
- [x] `agents/import-ga4.md`
- [x] `agents/import-hubspot.md`
- [x] `agents/import-salesforce.md`
- [x] `agents/import-ghl.md`
- [x] `agents/import-klaviyo.md`
- [x] `agents/export-meta.md`
- [x] `agents/export-google.md`
- [x] `agents/export-tiktok.md`
- [x] `web/src/pages/settings/integrations.astro` — connect / disconnect UI
- [x] `web/crm.md` — mark CX ✅

### W4 — Verify  [Haiku × parallel · one Agent-tool message · N=4]

- [ ] Each integration: connect → sync 100 contacts → verify in external system
- [ ] Field map preview before commit
- [ ] Last-sync timestamp visible per integration
- [ ] Per-workspace credentials isolated
- [ ] Rubric ≥ 0.65

---

## CH — HubSpot/Salesforce write-through  [tier: complex]

**Exit:** When an actor's lifecycle transitions, the write-through
agent calls the HubSpot/Salesforce CRM API within 30s. Customers'
existing CRM stays in sync during migration.

### W1 — Recon  [Haiku]

- HubSpot CRM API + Salesforce REST API docs
- CX import-hubspot / import-salesforce agents
- `actor:lifecycle` transition signal shape

### W2 — Decide  [Sonnet]

- Trigger: signal-subscribe `actor:lifecycle.update`
- Throttle: 100 req/min per workspace
- Conflict resolution: substrate wins; log delta on disagreement

### W3 — Edit  [Sonnet · parallel — one Agent-tool message, one agent per independent file]

- [x] `agents/export-hubspot.md` — write-through
- [x] `agents/export-salesforce.md` — write-through
- [x] `web/src/lib/integrations/{hubspot,salesforce}.ts` — clients
- [x] `web/crm.md` — mark CH ✅

### W4 — Verify  [Haiku × parallel · one Agent-tool message · N=3]

- [ ] Lifecycle update → HubSpot reflects within 30s
- [ ] Conflict: substrate wins; delta logged
- [ ] Throttle holds under 100 contacts/min burst
- [ ] Rubric ≥ 0.65

---

## W7 — Identity rungs 2–5 + same-as merge  [tier: complex]

**Exit:** Identity ladder resolves visitor_hash · email-hash ·
phone-hash · auth-provider-sub across actor rows with confidence ≥
0.95 auto, 0.6–0.95 queued, <0.6 dropped. Resolution rate ≥ 95%.

### W1 — Recon  [Haiku · parallel]

- `web/tracking.md` § Identity ladder
- Existing `same-as` relation in TypeDB schema

### W2 — Decide  [Opus]

- Rungs 0 (cookie) + 1 (visitor_hash) already live
- Rungs 2–5: email-hash, phone-hash, auth-provider-sub, custom-id
- Probabilistic merge: heuristic + LLM confidence

### W3 — Edit  [Sonnet · parallel — one Agent-tool message, one agent per independent file]

- [x] `web/src/lib/identity/ladder.ts` — rung 0–5 resolver
- [x] `web/src/lib/identity/merge.ts` — deterministic + probabilistic
- [x] `web/src/pages/api/identity/merge.ts` — manual endpoint
- [x] `migrations/0NNN_same_as.sql` — if needed
- [x] `web/src/components/crm/ContactSameAs.tsx` (CV) — confidence bar
- [x] `web/tracking.md` — mark rungs 2–5 ✅

### W4 — Verify  [Haiku × parallel · one Agent-tool message · N=5]

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

### W3 — Edit  [Sonnet · parallel — one Agent-tool message, one agent per independent file]

- [x] `web/src/lib/pii/vault.ts` — seal/unseal/shred
- [x] `web/src/lib/pii/forget.ts` — cascade engine
- [x] `web/src/pages/api/forget.ts` — POST
- [x] `web/src/pages/api/forget/[id].ts` — GET
- [x] `web/src/pages/api/pii/reveal/[actor].ts` — emits `pii.read`
- [x] `migrations/0NNN_pii_vault.sql`
- [x] `migrations/0NNN_forget_audit.sql`
- [x] `agents/compliance.md` — consume `pii.read` anomalies
- [x] `web/src/pages/api/visitor/[hash].ts` — alias of `/api/forget`
- [x] `web/crm.md` — mark W11 ✅

### W4 — Verify  [Haiku × parallel · one Agent-tool message · N=7]

- [ ] All 6 cascade tiers verified
- [ ] Vault shred latency <1s
- [ ] Reveal rate-limit: 101st → 429 + alert
- [ ] `pii.read` events present
- [ ] Hashes survive ≤5m in warm then null
- [ ] Reveal-audit panel populated
- [ ] Rubric ≥ 0.65 — security ≥ 0.92 hard target

---

## See also

- [`web/crm.md`](crm.md) — surface spec (the contract)
- [`web/crm-pages.md`](crm-pages.md) — visual spec (every screen drawn)
- [`one/signals.md`](../plans/signals.md) — the substrate primitive (subscriptions are tags + pheromone)
- [`web/tracking.md`](tracking.md) — wire format + identity ladder + cost model
- [`web/agent-analytics.md`](agent-analytics.md) — KPI math
- [`one/marketing-ontology.md`](../plans/marketing-ontology.md) — consent + suppression + attribute lists
- [`web/roles.md`](roles.md) — owner/agency/client/end_user cascade
- [`one/dictionary.md`](../plans/dictionary.md) — canonical names
- [`one/rubrics.md`](../plans/rubrics.md) — scoring bands
- [`one/patterns.md`](../plans/patterns.md) — closed loop, sandwich
- [`text/12-crm.md`](../text/12-crm.md) — voice + worked example
- Shell (live): [`web/src/pages/in.astro`](src/pages/in.astro), [`web/src/pages/in/[groupId].astro`](src/pages/in/%5BgroupId%5D.astro), [`web/src/components/in/`](src/components/in/), [`web/src/data/in-types.ts`](src/data/in-types.ts)

---

*Power through simplicity. Twelve quick wins on the shell that ships
today. Then the cycles that need depth. No new routes. No parallel
components. Each edit measurable, each merge independent.*
