---
title: Role UI — Clients Page, Org Creation, and Auth Flow
slug: role-ui
type: plan
tier: complex
mode: construction
tags: [groups, roles, clients, hierarchy, auth, onboarding, switcher]

parallel_budget:
  haiku:   20
  sonnet:  10
  opus:    2

batches:
  - [C1, C2, C4, C6, C7, C8]   # foundation — all independent
  - [C3, C5]                    # compose — both need C4; C5 also needs C1

shared_recon:
  - plans/role-ui.md
  - one.ie/web/src/middleware.ts
  - one.ie/web/src/lib/viewer.ts
  - one.ie/web/src/lib/menu.ts
  - one.ie/web/src/components/sidebar/GroupSwitcher.tsx
  - one.ie/web/src/pages/api/groups/index.ts
  - one.ie/web/src/pages/u/[slug]/people.astro
  - one.ie/web/src/pages/u/[slug]/onboarding.astro

source_of_truth:
  - plans/role-ui.md
  - one.ie/web/src/lib/viewer.ts
  - one.ie/web/src/lib/menu.ts
  - one.ie/web/src/pages/api/groups/index.ts

existing_primitives:
  - one.ie/web/src/components/sidebar/GroupSwitcher.tsx: switcher shell with footer — C3 wires the buttons
  - one.ie/web/src/components/ui/Drawer.tsx: drawer primitive — C4 composes this, does not reimplement
  - one.ie/web/src/pages/api/groups/index.ts: POST /api/groups — C1 extends with parent_gid + invite_email
  - one.ie/web/src/pages/api/groups/tree.ts: GET /api/groups/tree — C2 extends with depth + counts
  - one.ie/web/src/pages/u/[slug]/onboarding.astro: onboarding page — C7 extends, does not replace
  - one.ie/web/src/components/org/OrgChartView.tsx: org tree rendering — C5 composes for the clients table
  - one.ie/web/src/lib/invite-token.ts: HMAC-SHA256 signed tokens, 7-day TTL — C8 uses, does NOT reimplement
  - one.ie/web/src/pages/api/invites/create.ts: POST /api/invites/create — fully built; sends email to /join?token=
  - one.ie/web/src/pages/api/invites/accept.ts: POST /api/invites/accept — fully built; verifies token, writes membership, enrolls teams

show: true

escape:
  condition: "C1 W4 fails security rubric < 0.90 twice (parent_gid auth is security-critical)"
  action: "halt; review POST /api/groups auth against plans/groups.md §Security Invariants"

context_triggers:
  - pattern: "parent_gid|manage_clients|hierarchy"
    inject: "plans/role-ui.md § The Hierarchy"
  - pattern: "invite|/join|landing"
    inject: "plans/role-ui.md § Anonymous → Identified → Authenticated"
  - pattern: "onboarding|org-type|agency.*steps"
    inject: "plans/role-ui.md § Page Sketches — Onboarding"
---

# Role UI — Clients Page, Org Creation, and Auth Flow

**Goal:** Owner and agency can create child orgs (agencies and clients) from the switcher or `/clients` page, see them in a managed list, and invite owners who land on a working invite page.

**Exit:**
- `bun vitest run tests/api/groups-create.test.ts` — POST /api/groups with parent_gid creates child org and writes manage_clients capability
- `bun vitest run tests/ui/clients-page.test.tsx` — `/clients` renders child orgs; sub-agency rows expand; client tier sees no /clients nav item
- `bun vitest run tests/ui/create-org-drawer.test.tsx` — drawer submits correct payload; slug auto-generates from name
- `GET /join?token=` returns invite landing HTML with org name + inviter name

---

## Reuse contract

Every cycle composes before constructing. The drawer is shadcn `Drawer`. The clients table rows compose `OrgChartView` or `MenuItem` primitives. No new modal stack, no bespoke input, no reimplemented fetch helper.

---

## Cycle DAG

```
C1 (POST /api/groups — parent_gid)
C2 (GET /api/groups/tree — depth + counts)      ← independent of C1
C4 (CreateOrgDrawer component)                  ← independent of C1
C6 (people.astro — reconcile events vs members) ← independent
C7 (onboarding — org-type steps)                ← independent
C8 (anon→auth — chat CTA + invite landing)      ← independent

         C1 ──→ C5 (clients page needs parent_gid API)
         C4 ──→ C3 (switcher footer needs drawer)
         C4 ──→ C5 (clients page uses drawer)
```

---

## Status

```
Batch 0 (shared)
  - [x] W0 baseline (tsc=0 loc=107916)
  - [x] W1 shared recon (8 files)

Batch 1                                           state: complete
  - [x] C1 — POST /api/groups parent_gid       (7 tests)
  - [x] C2 — GET /api/groups/tree depth+counts (4 tests)
  - [x] C4 — CreateOrgDrawer                   (5 tests)
  - [x] C6 — people.astro reconcile            (Members + Visitors tabs)
  - [x] C7 — onboarding org-type steps         (5 tests)
  - [x] C8 — anon→auth chat CTA + /join landing (4 tests)

Batch 2                                           state: complete
  - [x] C3 — switcher footer wired             (4 tests)
  - [x] C5 — /clients page + nav item          (4 tests)

Plan close
  - [x] Final compress sweep
  - [x] docs/learnings.md append
  - [x] Plan rubric ≥ 0.65 (composite ≈ 0.91)
```

---

## C1 — `POST /api/groups` — parent_gid + invite_email  [tier: complex · batch: 1]

**Exit:** `POST /api/groups { name, slug, type: "agency", parent_gid: "acme-gid" }` creates child org under ACME, writes `manage_clients` capability for agency type, and returns `{ gid, slug }`. Auth rejects requests where actor does not hold `manage_clients` for the given `parent_gid`.

```yaml
demo:
  command: "bun vitest run tests/api/groups-create.test.ts"
  asserts: "child org created with correct parent; manage_clients written for agency type; 403 when actor lacks manage_clients for parent"
  budget: "<500ms · ≤100 LOC"
```

### W1 — Recon

1. Existing-code recon
   - [ ] `one.ie/web/src/pages/api/groups/index.ts` — current POST shape, auth pattern, what it currently creates
   - [ ] `one.ie/web/src/lib/enrollment.ts` — does it already handle manage_clients provisioning?
   - [ ] `one.ie/web/src/middleware.ts` — how manage_clients is read from session
   - [ ] `schema/one.tql` — hierarchy relation, capability relation, manage_clients cap

2. Primitive inventory
   - [ ] `one.ie/web/src/pages/api/groups/join.ts` — how parent scoping is currently handled
   - [ ] `one.ie/web/src/lib/kv.ts` — invalidateTreeCache export (must be called on create)

### W2 — Decide  [Opus]

- [ ] Auth gate: verify actor holds `manage_clients` on `parent_gid` before creating child — TypeQL query or session flag?
- [ ] `manage_clients` provisioning: extend `lib/enrollment.ts` `enrollPlanTeams()` or separate function?
- [ ] D1 write: `parent_slug` column already exists on `owners` table (migration 0008); C1 must `UPDATE owners SET parent_slug = ? WHERE slug = ?` after TypeDB hierarchy write — middleware reads this column to resolve workspace hierarchy on every request
- [ ] `invite_email`: wire to existing `POST /api/invites/create` (already built — signs HMAC token, sends email, writes D1 invites row) in same handler, or as a separate client call?
- [ ] Slug uniqueness: check D1 `owners` table for slug collision, return 409 if taken
- [ ] Compose-or-construct verdict for any new files
- [ ] Diff specs output

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `one.ie/web/src/pages/api/groups/index.ts` — accept `parent_gid`, `type`, `invite_email`; auth gate; call enrollment; write `parent_slug` to D1 `owners`
- [ ] `one.ie/web/src/lib/enrollment.ts` — extend `enrollPlanTeams()` to write manage_clients for agency type
- [ ] `one.ie/web/src/lib/kv.ts` — ensure `invalidateTreeCache` called on create
- [ ] `tests/api/groups-create.test.ts` — demo gate

**W3b:**
- [ ] `one.ie/web/src/pages/api/groups/index.ts` — wire invite send via existing `/api/invites/create` logic after org creation (depends on W3a shape)

### W4

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo passes
- [ ] Auth test: 403 when actor has no manage_clients for parent_gid
- [ ] Slug collision returns 409
- [ ] Tree cache invalidated on create
- [ ] security ≥ 0.90 · composite ≥ 0.65

---

## C2 — `GET /api/groups/tree` — section labels + depth + counts  [tier: simple · batch: 1]

**Exit:** tree response includes `section` field per node (`"personal" | "agencies" | "clients" | "public"`), `people_count`, and `clients_count`. `?depth=2` returns grandchildren.

```yaml
demo:
  command: "bun vitest run tests/api/groups-tree.test.ts"
  asserts: "nodes have section field; depth=2 returns grandchildren; counts present"
  budget: "<500ms · ≤60 LOC"
```

### W1 — Recon

- [ ] `one.ie/web/src/pages/api/groups/tree.ts` — current response shape and TypeQL queries
- [ ] `one.ie/web/src/components/sidebar/GroupSwitcher.tsx` — how nodes are currently grouped for display

### W2 — Decide  [Sonnet]

- [ ] `section` field: derived server-side from group-type + relationship, or client-side from node properties?
- [ ] Counts: TypeQL aggregation in the tree query or separate queries?
- [ ] `depth` param: default 1, opt-in to 2 for clients page

### W3 — Edit  [Sonnet]

**W3a:**
- [ ] `one.ie/web/src/pages/api/groups/tree.ts` — add section, counts, depth param
- [ ] `tests/api/groups-tree.test.ts` — extend existing test

### W4

- [ ] `bun run verify` green
- [ ] Demo passes
- [ ] section field present on all nodes
- [ ] depth=2 returns grandchildren only when requested
- [ ] composite ≥ 0.65

---

## C4 — `CreateOrgDrawer` component  [tier: simple · batch: 1]

**Exit:** drawer opens with Type toggle (Agency / Client), auto-generates slug from name, submits to `POST /api/groups`, closes on success and fires `onCreated(gid)` callback.

```yaml
demo:
  command: "bun vitest run tests/ui/create-org-drawer.test.tsx"
  asserts: "slug auto-fills from name input; submit fires POST with correct payload; drawer closes on 200"
  budget: "<1s · ≤80 LOC"
```

### W1 — Recon

- [ ] `one.ie/web/src/components/ui/Drawer.tsx` — shadcn drawer API
- [ ] `one.ie/web/src/components/ui/` — Input, Button, RadioGroup primitives available
- [ ] `one.ie/web/src/components/sidebar/GroupSwitcher.tsx` — footer slot where buttons will live

### W2 — Decide  [Sonnet]

- [ ] Compose-or-construct: compose shadcn `Drawer` + `Input` + `RadioGroup` — no new primitives
- [ ] Slug generation: `name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '')` inline
- [ ] `onCreated` callback vs router.push — let the parent decide navigation
- [ ] Slot map

### W3 — Edit  [Sonnet]

**W3a:**
- [ ] `one.ie/web/src/components/org/CreateOrgDrawer.tsx` — new component
- [ ] `tests/ui/create-org-drawer.test.tsx` — demo gate

### W4

- [ ] `bun run verify` green
- [ ] Demo passes
- [ ] No reimplementation of Drawer, Input, or RadioGroup (grep check)
- [ ] `wc -l CreateOrgDrawer.tsx` ≤ 120
- [ ] composite ≥ 0.65

---

## C3 — Switcher footer wired  [tier: trivial · batch: 2]

**Exit:** `[+ New agency]` and `[+ New client]` buttons in `GroupSwitcher` footer open `CreateOrgDrawer` pre-set to the correct type; `[+ Join via invite]` is unchanged.

```yaml
demo:
  command: "bun vitest run tests/ui/switcher-footer.test.tsx"
  asserts: "click New agency → drawer opens with type=agency; click New client → type=client; viewer=client → no create buttons"
  budget: "<500ms · ≤40 LOC"
```

### W1 — Recon (inline — 2 files)

- [ ] `GroupSwitcher.tsx` — current footer render, how viewer + activeGroup.plan are available
- [ ] `CreateOrgDrawer.tsx` (from C4) — props contract

### W2 — Decide  [inline]

- [ ] Import `CreateOrgDrawer` into `GroupSwitcher`; manage `drawerOpen` + `drawerType` state locally
- [ ] Footer visibility: `viewer === 'owner' || hasManageClients` → show create buttons

### W3 — Edit  [Sonnet]

**W3a:**
- [ ] `one.ie/web/src/components/sidebar/GroupSwitcher.tsx` — wire footer buttons
- [ ] `tests/ui/switcher-footer.test.tsx`

### W4

- [ ] `bun run verify` green · demo passes · composite ≥ 0.65

---

## C5 — `/u/[slug]/clients` page + nav item  [tier: complex · batch: 2]

**Exit:** `/u/acme/clients` renders child orgs from `GET /api/groups/tree?depth=2`; sub-agency rows expand in place; `Clients` nav item visible only when `hasManageClients`; client tier gets 403 redirect.

```yaml
demo:
  command: "bun vitest run tests/ui/clients-page.test.tsx"
  asserts: "agency viewer → clients table renders; sub-agency row expands to show children; client viewer → 403 redirect; Clients nav item absent for client tier"
  budget: "<1s · ≤100 LOC"
```

### W1 — Recon

- [ ] `one.ie/web/src/components/org/OrgChartView.tsx` — can it render a flat table or only graph?
- [ ] `one.ie/web/src/lib/menu.ts` — getUserMenu signature, how to add Clients item conditionally
- [ ] `one.ie/web/src/pages/u/[slug]/people.astro` — page structure to replicate

### W2 — Decide  [Sonnet]

- [ ] Compose-or-construct: new `ClientsTable.tsx` or extend `OrgChartView`? Verdict from recon.
- [ ] `Clients` nav item gating: `viewer` alone or `viewer + hasManageClients`? hasManageClients is correct — a `viewer=agency` without manage_clients has no children.
- [ ] Expandable rows: `useState` local expand or URL query param? Local state preferred.
- [ ] `···` menu: reuse `DropdownMenu` from ui/
- [ ] Diff specs

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `one.ie/web/src/pages/u/[slug]/clients.astro` — new page; auth gate; pass tree data
- [ ] `one.ie/web/src/components/org/ClientsTable.tsx` — new component; composes OrgChartView or MenuItem rows
- [ ] `one.ie/web/src/lib/menu.ts` — add Clients item with manage_clients gate
- [ ] `tests/ui/clients-page.test.tsx` — demo gate

**W3b:**
*(empty)*

### W4

- [ ] `bun run verify` green
- [ ] Demo passes
- [ ] client tier → 403 checked
- [ ] Clients nav item absent for client tier
- [ ] composite ≥ 0.65

---

## C6 — Reconcile `/people` (events vs members)  [tier: simple · batch: 1]

**Exit:** `/people` page label and content clearly distinguish between "identified visitors" (current: agent_events) and "members" (membership roster). Nav label and page heading updated to match. Members roster accessible from the page.

```yaml
demo:
  command: "bun vitest run tests/ui/people-page.test.tsx"
  asserts: "page renders two sections: Members (from /api/groups/members) and Visitors (from agent_events); heading matches nav label"
  budget: "<500ms · ≤60 LOC"
```

### W1 — Recon

- [ ] `one.ie/web/src/pages/u/[slug]/people.astro` — what it currently queries and renders
- [ ] `one.ie/web/src/pages/api/groups/members.ts` — members roster API shape (from role-switcher C16)

### W2 — Decide  [Sonnet]

- [ ] One page with two tabs (Members / Visitors) or rename existing page to Visitors and add separate Members page?
- [ ] Two-tab approach is simpler — keeps nav item count stable

### W3 — Edit  [Sonnet]

**W3a:**
- [ ] `one.ie/web/src/pages/u/[slug]/people.astro` — add Members tab using `/api/groups/members`; rename Visitors tab

### W4

- [ ] `bun run verify` green · demo passes · composite ≥ 0.65

---

## C7 — Onboarding org-type awareness  [tier: simple · batch: 1]

**Exit:** onboarding steps vary by org type: agency sees Name + Brand + Domain + Invite (4 steps); client sees Name + Invite (2 steps). Step list rendered from a config derived from the org's `type` field in D1.

```yaml
demo:
  command: "bun vitest run tests/ui/onboarding.test.tsx"
  asserts: "type=agency → 4 steps rendered; type=client → 2 steps rendered; step 2 for agency shows brand colour picker"
  budget: "<500ms · ≤60 LOC"
```

### W1 — Recon

- [ ] `one.ie/web/src/pages/u/[slug]/onboarding.astro` — how it reads org data; what OnboardingFlow receives
- [ ] `one.ie/web/src/components/onboarding/` — existing OnboardingFlow component shape

### W2 — Decide  [Sonnet]

- [ ] Step config: `const STEPS = { agency: [...], client: [...] }` — static config in OnboardingFlow
- [ ] Where does `type` come from? D1 `owners` table `type` column or derived from plan?

### W3 — Edit  [Sonnet]

**W3a:**
- [ ] `one.ie/web/src/components/onboarding/OnboardingFlow.tsx` — add type-based step config
- [ ] `one.ie/web/src/pages/u/[slug]/onboarding.astro` — pass org type to component
- [ ] `tests/ui/onboarding.test.tsx`

### W4

- [ ] `bun run verify` green · demo passes · composite ≥ 0.65

---

## C8 — Anonymous → Authenticated: chat CTA + invite landing  [tier: simple · batch: 1]

**Scope note:** Invite token signing, D1 invites table, email sending, and `POST /api/invites/accept` are **fully built** (see `existing_primitives`). C8 builds only: (a) the `/join` landing page that reads `?token=` and shows org name + CTA, and (b) the chat sign-in nudge for end_users. Do not rebuild what exists.

**Exit:** (a) end_user sees "Sign in · Save conversation" link in chat footer; (b) `GET /join?token=` renders invite landing with org name + "Set up account" CTA; (c) expired/invalid token → 410; after passkey register, `POST /api/invites/accept` (already built) is called to write membership.

```yaml
demo:
  command: "bun vitest run tests/ui/invite-landing.test.tsx tests/ui/chat-signin-cta.test.tsx"
  asserts: "end_user viewer → sign-in CTA rendered in chat; /join?token= renders org name; expired token → 410; valid token → accept button calls existing POST /api/invites/accept"
  budget: "<1s · ≤80 LOC"
```

### W1 — Recon

1. Existing-code recon
   - [ ] `one.ie/web/src/pages/u/[slug]/chat.astro` — how viewer is passed to chat; where footer renders
   - [ ] `one.ie/web/src/lib/invite-token.ts` — `verifyInviteToken` return shape (gid, role, exp)
   - [ ] `one.ie/web/src/pages/api/invites/create.ts` — confirm invite URL pattern is `/join?token=`
   - [ ] `one.ie/web/src/pages/go/[id].ts` — confirm this is NOT an invite landing (it handles tracked redirects from `tracked_links` table)

2. Primitive inventory
   - [ ] `one.ie/web/src/components/auth/` — existing sign-in components that `/join` can reuse

### W2 — Decide  [Sonnet]

- [ ] Chat CTA: inline in `chat.astro` or a small React island receiving `viewer` prop? (island preferred — viewer is runtime-derived)
- [ ] `/join` page: `src/pages/join.astro` reads `?token=` query param, calls `verifyInviteToken` server-side; on invalid/expired → 410; on valid → render org name + "Set up account" CTA
- [ ] Post-passkey flow: after registration completes, page calls `POST /api/invites/accept { token }` (already built) then redirects to `/u/[slug]/dashboard`
- [ ] Expired token: 410 status with a simple "invite expired" message
- [ ] Compose-or-construct verdicts
- [ ] Diff specs

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `one.ie/web/src/pages/join.astro` — invite landing page; server-side token verify; renders org name + CTA; 410 on bad token
- [ ] `one.ie/web/src/components/chat/ChatSignInCta.tsx` — sign-in nudge for end_user (new, small)
- [ ] `one.ie/web/src/pages/u/[slug]/chat.astro` — render ChatSignInCta when viewer=end_user
- [ ] `tests/ui/invite-landing.test.tsx` + `tests/ui/chat-signin-cta.test.tsx`

**W3b:** *(empty — accept.ts already built)*

### W4

- [ ] `bun run verify` green
- [ ] Demo passes
- [ ] Expired/invalid token returns 410
- [ ] Valid token shows org name (not generic copy)
- [ ] end_user → no CTA click → no disruption to chat
- [ ] No reimplementation of invite-token.ts, invites create/accept (grep check)
- [ ] security ≥ 0.90 (token read server-side only; not exposed to client)
- [ ] composite ≥ 0.65

---

## See also

- `plans/role-ui.md` — design doc this todo executes
- `plans/role-switcher.md` — switcher, Act As, members roster (C16)
- `plans/roles.md` — surface matrix, cascade model
- `plans/groups.md` — RBAC/ReBAC security invariants
- `one.ie/web/src/lib/viewer.ts` — deriveViewer()
- `one.ie/web/src/lib/menu.ts` — getUserMenu()
- `plans/dictionary.md` — canonical names
- `plans/rubrics.md` — scoring bands
