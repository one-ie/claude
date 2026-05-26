---
title: Send Link — CRM contact personalisation link
slug: send-link
type: plan
tier: complex
mode: construction
tags: [crm, send-link, personalisation, tracking, identity, actors]
source_of_truth:
  - web/send-link.md              # full spec + applications
  - web/crm.md                   # CRM shell contract
  - web/tracking.md              # identity ladder + event pipeline
context_triggers:
  - pattern: "actor_id|identity|rung"
    inject: "web/tracking.md § Identity ladder"
  - pattern: "tracked_links|link_id|destination"
    inject: "web/send-link.md § Delta"
show: false
escape:
  condition: "delta_tsc_errors > 0 OR rubric composite < 0.65"
  action: "halt; report offending cycle"
---

# Send Link — TODO

> One-click CRM action: generate a tracked URL bound to a contact's actor_id.
> Click → rung-4 identity → snapshot pre-warm → personalised page + seeded chat.

## Status

| Cycle | Status | Gate |
|-------|--------|------|
| C1 — Backend | - [x] | `/api/links` returns URL; `/go/:id` sets actor_id cookie |
| C2 — Frontend | - [x] | SendLinkSheet renders + copies URL; verb in EntityActionBar |

---

## C1 — Backend

**Goal**: `POST /api/links` creates an actor-bound tracked link. `/go/:id` elevates identity to rung 4 when `actor_id` is set on the link.

**Files**:
- `web/migrations/0048_send_link.sql` — add columns to `tracked_links`
- `web/src/pages/api/links.ts` — new POST endpoint
- `web/src/pages/go/[id].ts` — extend to set actor_id cookie + pre-warm snapshot

**Exit**: `bun vitest run tests/send-link-c1.test.ts`

**Verify**:
- [ ] W0 — `bun run verify` green
- [ ] W1 — recon tracked_links migration + `/go/[id].ts` + identity helpers
- [ ] W2 — diff specs for all 3 files
- [ ] W3 — edits applied
- [ ] W4 — test passes, delta_tsc ≤ 0

---

## C2 — Frontend

**Goal**: "Send Link" verb appears in the actor action bar. Clicking it opens `SendLinkSheet` which calls `/api/links` and shows a copy-ready URL.

**Files**:
- `web/src/components/crm/SendLinkSheet.tsx` — new sheet component
- `web/src/components/in/EntityActionBar.tsx` — add `send-link` to actors verbs
- `web/src/components/in/EntityDetail.tsx` — handle send-link verb, render sheet

**Exit**: `bun vitest run tests/send-link-c2.test.ts`

**Verify**:
- [ ] W0 — `bun run verify` green
- [ ] W1 — recon EntityActionBar + EntityDetail + CRM component patterns
- [ ] W2 — diff specs for all 3 files
- [ ] W3 — edits applied
- [ ] W4 — test passes, delta_tsc ≤ 0
