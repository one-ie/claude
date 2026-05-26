---
title: Master sequence — ranked work streams, one execution order
slug: master-sequence
type: plan
tier: complex
mode: construction
tags: [boq, crm, chat, analytics, polish, sequencing]
source_of_truth:
  - boq-todo.md
  - web/crm-complete-todo.md
  - web/agent-analytics-todo.md
  - one/governance-todo.md
existing_primitives:
  - web/src/actions/: 13-file action layer (defineAction, actionsForSurfaceWithPattern, ALL_ACTIONS registry) — C5 done
  - web/src/components/chat/cards/: all 10 BOQ card components shipped — C1 done
  - web/src/pages/api/field-service/[slug]/: book, checkout, slots, jobs/[ref] — C1 done
  - web/src/workers/analytics-relay.ts: WorkspaceDO with /accept route, /connect WS, /broadcast — C3 partial
  - web/src/pages/api/tags/index.ts + templates/index.ts: D1-wired CRUD — CRM base done
show: false
escape:
  condition: "C4 W4 delta_tsc > 0 twice"
  action: "halt; re-read crm-complete-todo.md failing cycle, check D-spec exit scalar before retrying"
context_triggers:
  - pattern: "boq|ptcorp|field.service"
    inject: "boq-todo.md § Wave 4"
  - pattern: "crm|inbox|mcp.*tool|pulse|actor.contact"
    inject: "web/crm-complete-todo.md § existing_primitives"
  - pattern: "snapshotForActor|analytics.relay|useWatch"
    inject: "web/agent-analytics-todo.md § C4"
---

# Master sequence — ranked work streams

**Goal:** Close the remaining real gaps — BOQ demo verified, CRM new files and MCP tools shipped, analytics snapshotForActor wired, governance settings wired — then unlock the CRX track. No new endpoint files anywhere — signal/ask/mark/warn/settings cover everything.

**Exit:** BOQ demo script passes end-to-end; CRM `bun test mcp/tests/D8-mcp-inbox-compose.test.ts` passes (10 sub-tests); `snapshotForActor('test-visitor')` returns `{recent:[…]}` in vitest; `GET /api/settings?scope=world-config` returns world config; `bun run verify` green throughout.

---

## Code audit (2026-05-16) — what actually shipped

| Cycle | Status | Evidence |
|---|---|---|
| C1 BOQ demo | ✅ Built — demo run pending | 3 agent MDs, 10 card components, field-service/ + ptcorp/ APIs, ptcorp-dashboard.astro, chat.ts qualifier routing all exist |
| C2 Agency-CEO PDF | ✅ Complete | All 17 pages with rubric ≥ 0.90 (opus); verify.sh present |
| C3 Analytics wire | ⚠️ 2 gaps | DO wired (/accept, /broadcast, /connect), cron + exports done; `snapshotForActor()` absent; no smoke test |
| C4 CRM substrate | ✅ Complete — 42/42 D-spec tests pass | tags/templates/classify/Inbox.tsx/hooks/PulseAtlas all shipped; inbox.ts correctly absent per D8 assertion; 16/16 test files pass |
| C5 Chat-integrated | ✅ Complete | `web/src/actions/` 13 files; chat.ts + ChatHost.tsx + Layout.astro fully wired |
| C6 Governance | ⚠️ 2 settings scopes + UI | `scope=world-config` and `scope=members` not yet wired in settings.ts; Chairman UI missing; cross-org deferred |
| C6 Rich messages | ✅ Code shipped | C1-C3 cycles done; only verification checkboxes open |
| C6 Design system | ✅ Code shipped | 56/56 tests pass; only gate verification open |
| C6 UI signals | ✅ Code shipped | emitClick exported; C1-C2 done; C3 prefetch deferred |
| C6 Client UI | ✅ Code shipped | All cycles done; only gate verification open |
| C6 Speed chat | ✅ TTFT targets met | T1-T4 targets achieved; 3 items deferred, 1 blocked on CF auth |
| C7 CRX | 🔓 Unlocked | C5 done → action API locked; 250 items, not yet started |

---

## Dependency graph

```
C1-verify (BOQ demo run) ─── no file deps
C3-gaps  (snapshotForActor + smoke test) ─── no file deps
C6-gov (governance APIs) ─── no file deps
C7 (CRX) ─── no blocking deps — start planning now
```

**C4 is complete.** All 42 D-spec tests pass. `inbox.ts` was never the plan — D8 explicitly asserts it must not exist. CRX calls substrate.ts `signal`/`ask` verbs with receiver namespacing; no CRM-specific MCP file needed.

**All four remaining streams are parallel** — C1-verify, C3-gaps, C6-gov, and C7 recon can run simultaneously.

---

## Status

- [ ] C1-verify — BOQ end-to-end demo run
- [ ] C3-gaps — analytics `snapshotForActor` + smoke test (2 files)
- [x] C4 — CRM substrate — 42/42 D-spec tests pass; all hooks/components/MCP tools shipped
- [ ] C6-gov — governance world-config API + role-assignment write API
- [ ] C7 — CRX planning + execution (250 items, long horizon)

---

## C1-verify — BOQ demo run  [tier: trivial]

**What's built:** Agent MDs (ptcorp-qualifier/sales/service + ptcorp.md), all 10 card components, `/api/field-service/[slug]/` endpoints (book/checkout/slots/jobs/[ref]), ptcorp-dashboard.astro, qualifier routing and `emit_field_service_card` tool in chat.ts, `fieldServiceCardSchema` Zod union.

**What needs verifying:** The 15-min demo script runs end-to-end without console errors.

**Exit:** Act 1 (MDU lead → 7 cards → Stripe test checkout → D1 booking → dashboard shows booking) AND Act 2 (emergency → SeverityCard → Critical → DispatchCard with ETA → JobTrackerCard) complete without errors at `localhost:4321/studio/ptcorp`.

### W1 — Recon  [inline]

- `web/agents/ptcorp.md` — confirm `journey:` starters match demo script Act 1/2/3 trigger phrases
- `web/src/pages/api/field-service/[slug]/book.ts` vs `web/src/pages/api/ptcorp/book.ts` — confirm chat.ts calls the field-service route, not the ptcorp route; the ptcorp/ namespace may be a legacy stub

### W2 — Decide  [inline]

- Does `/studio/ptcorp` render and load ptcorp.md agent correctly?
- Does qualifier routing (ptcorp-qualifier → ptcorp-sales or ptcorp-service) actually fire in chat.ts line 290-313?
- Does Stripe test checkout session redirect in test mode?

### W3 — Edit  [Sonnet if gaps found · else skip]

Fix any routing gaps found in W1. If field-service/ and ptcorp/ duplicate each other, remove the stale namespace.

### W4 — Verify  [inline]

- [ ] `/browser http://localhost:4321/studio/ptcorp --screenshot` renders without JS errors
- [ ] "I need fiber for a 300-unit condo" → routes to sales bot (ptcorp-sales in chat context)
- [ ] `emit_field_service_card` tool fires and renders ServiceSelectorCard in response
- [ ] `POST /api/field-service/ptcorp/book` → `{ref, confirmation}` (curl test)
- [ ] Stripe test checkout: session created, redirect works
- [ ] Act 2: "fiber is down, 40 businesses affected" → SeverityCard → Critical → DispatchCard
- [ ] Brad's dashboard: booking + order visible

Report: `acts_passed=3  console_errors=0  booking_ref_present=1`

---

## C3-gaps — Analytics `snapshotForActor` + smoke test  [tier: simple]

**What's built:** AnalyticsRelay DO with `/accept`, `/broadcast`, `/connect` routes; cron triggers; events.ts ingest; watch.ts SSE; useWatch() hook; all migrations (0031-0033).

**1 real gap:**
- No analytics smoke test (only `substrate-retry.test.ts` in `web/tests/unit/`)

`/snapshot` POST route already ships in `analytics-relay.ts` lines 105-113 — filters `this.recent` by `actorId`, returns `{recent, persona, highways}`. Nothing to add there.

**Exit:** `bun vitest run web/tests/unit/analytics-smoke.test.ts` passes 3 sub-tests; `POST /api/events` → SSE delivers event within 200ms; DO `/snapshot` → `{recent:[…], persona:[…]}` non-empty.

### W1 — Recon  [inline]

- `web/src/workers/analytics-relay.ts` lines 44-230 — current `/accept` route, in-RAM state structure, what data is available for a snapshot
- `web/src/lib/use-watch.ts` — does it call snapshotForActor? What does it expect back?
- `web/tracking-realtime.md § R1` — snapshotForActor return shape spec

### W2 — Decide  [Sonnet]

- snapshotForActor input: `actorId: string` (visitor hash) → reads `recent` ring buffer + `typedb` highways; returns `{ladder, recent: AgentEvent[], persona: string[], lifecycle?: string, llm_hint?: string}`
- Route: add `/snapshot` POST route to analytics-relay.ts; call via fetch stub in snapshotForActor API helper
- Smoke test tool: Vitest + msw (preferred; no Playwright needed)

### W3 — Edit  [Sonnet · parallel]

**W3 — 1 file only:**
- [ ] `web/tests/unit/analytics-smoke.test.ts` — new: (1) POST to /api/events → expect D1 write (msw mock); (2) GET /api/analytics/watch → expect SSE event delivered within 200ms; (3) DO /snapshot → returns non-empty `{recent, persona}` (route ships at analytics-relay.ts:105)

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run web/tests/unit/analytics-smoke.test.ts` exits 0 (3 sub-tests)
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=0  new_files=1  tests_added=3`

---

## C4 — CRM substrate  [COMPLETE ✅]

**Verified 2026-05-16:** All 16 D-spec test files pass, 42/42 tests. All hooks, components, and MCP tools shipped. `inbox.ts` correctly absent — D8 asserts it must not exist; inbox actions route via substrate `signal`/`ask` with receiver namespacing. No further work in this cycle.

**Evidence:** `bun vitest run web/tests/e2e/crm/` → `Test Files 16 passed (16) · Tests 42 passed (42)`

---

## C6-gov — Governance settings wiring  [tier: simple]

**Sub-todo:** `one/governance-todo.md` — 3 open items; C1 and C2 cycles complete.

**What's missing:**
1. `web/src/lib/in/workspace-settings.ts` — add `world-config` and `members` to `WorkspaceScope` union + `SCOPE_COLUMN` + `SCOPE_FIELD` records (~6 lines). Without this, `isWorkspaceScope()` returns false and `settings.ts` 400s before hitting any handler.
2. `web/src/pages/api/settings.ts` — add TypeDB-backed GET/PUT branches for these two scopes (D1 generic dispatch won't work — world-config and members live in TypeDB, not the workspace_settings D1 table).
3. Chairman dashboard UI that calls them.

No new endpoint files. Cross-org discovery deferred.

**Exit:** `GET /api/settings?scope=world-config&workspace=test` returns `{sensitivity, fadeRate, toxicityThreshold}`; `PUT /api/settings?scope=members` updates role on membership relation in TypeDB; Chairman dashboard UI sliders and role table submit without JS errors.

### W1 — Recon  [Haiku · parallel]

- `web/src/lib/in/workspace-settings.ts` — current `WorkspaceScope` union; does it already contain `world-config` or `members`?
- `web/src/pages/api/settings.ts` — current scope dispatch: does it have any TypeDB-backed branches, or is it purely D1 generic dispatch?
- `web/src/schema/one.tql` — membership relation shape; which attributes hold sensitivity, fade rate, toxicity threshold on the workspace entity
- `one/governance-todo.md § C3` — exact exit scalar for the 3 open items
- `web/src/pages/u/[slug]/` — where the Chairman dashboard page lives; what it currently renders

### W2 — Decide  [Sonnet]

- Resolved: both scopes go into existing `settings.ts` — no new files, no new namespace. Settings endpoint already exists and dispatches by `?scope=`.
- `scope=world-config`: GET reads three TypeDB attributes off the workspace entity; PUT writes them back.
- `scope=members`: PUT updates actor role on the membership relation (actorId + newRole in body).
- Cross-org discovery: confirm deferred, no code, no stub.

### W3 — Edit  [Sonnet · parallel]

**W3a — 3 agents in one message:**
- [ ] `web/src/lib/in/workspace-settings.ts` — add `'world-config'` and `'members'` to `WorkspaceScope` union; add entries to `SCOPE_COLUMN` (`world_config`, `members`) and `SCOPE_FIELD` (`worldConfig`, `members`) records; ~6 lines
- [ ] `web/src/pages/api/settings.ts` — add TypeDB-backed `scope=world-config` GET/PUT branch (reads/writes sensitivity, fadeRate, toxicityThreshold from TypeDB workspace entity) + `scope=members` PUT branch (updates actor role on TypeDB membership relation); ~30 LOC total; must come before the generic D1 dispatch path so D1 doesn't try to handle TypeDB-only scopes
- [ ] Chairman dashboard page — add World Config section (3 sliders: sensitivity, fade rate, toxicity threshold 0–1) + Role Assignment table (actors list + role picker); both call existing `GET/PUT /api/settings?scope=world-config|members` — no new fetch patterns

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `GET /api/settings?scope=world-config&workspace=test` returns `{sensitivity, fadeRate, toxicityThreshold}`
- [ ] `PUT /api/settings?scope=members` → TypeDB membership role updated
- [ ] `/browser --screenshot` on Chairman dashboard: sliders render, role table renders, submit buttons present
- [ ] Rubric composite ≥ 0.65
- [ ] `grep -r "governance/" web/src/pages/api/` returns 0 — no new namespace created

Report: `delta_tsc=±N  new_files=0  settings_scopes_added=2  lines_added_to_settings=~30`

---

## C7 — Chrome extension  [tier: complex · now unblocked]

**Unblocked by:** C5 (chat-integrated action layer) is complete — `web/src/actions/` is the stable API surface the extension calls.

**Sub-todo:** `web/crx-todo.md` — 250 items, 0 closed.

**Before starting:** Run `/do web/crx-todo.md --wave 0` (W1 recon only) to validate the action API surface assumptions in the extension spec against the shipped `web/src/actions/index.ts` exports. If CRX spec references non-existent actions, update the spec first.

**No blocking deps.** C4 is complete and `inbox.ts` won't exist — CRX calls substrate `signal`/`ask` with receiver namespacing. Start recon now in parallel with C1/C3/C6.

**Exit:** TBD from crx-todo.md W2 once W1 recon maps the action surface correctly.

---

## See also

- `boq-todo.md` — BOQ demo full spec (C1-verify reference)
- `web/crm-complete-todo.md` — CRM wiring spec with D-item exit scalars (C4)
- `web/agent-analytics-todo.md` — analytics wire-up (C3-gaps reference)
- `one/governance-todo.md` — governance C3 exact exit scalar (C6-gov)
- `web/crx-todo.md` — chrome extension 250 items (C7)
- `one/dictionary.md` — canonical names (always)
- `one/rubrics.md` — scoring bands (always)
