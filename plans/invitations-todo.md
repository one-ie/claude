---
title: Invitations — zero-friction onboarding for agencies, clients, and staff
slug: invitations
type: plan
tier: complex
mode: construction
tags: [auth, invites, agencies, clients, staff, onboarding]

goal: "Operators can invite agencies, clients, and staff via a link or code that logs the invitee in and drops them into their workspace in one click — no separate sign-in, no paste step."
outcome: "bun vitest run tests/invitations.test.ts"
outcome_asserts: "GET /join?token= returns a 302 with Set-Cookie and location pointing to the invited workspace; homepage Enter-code tab resolves the same flow without redirecting to /join."

deliverables:
  - migration: migrations/0071_invites_v3.sql — adds sent_at, mode, workspace_ready, superseded_by columns (C1)
  - api: POST /api/invites/create — extended to enforce parent-child role ceiling exception + store mode/workspace_ready (C4 — same-workspace ceiling already exists at lines 80-92)
  - api: POST /api/invites/accept — token-as-credential: mints Better Auth session, auto-creates user, atomic (C2)
  - route: GET /join — server-side verify → auth → redirect, no paste UI (C2)
  - component: InviteGate.tsx — Enter-code tab posts directly to accept, no /join redirect (C3)
  - api: POST /api/signal/invite:resend — resend-with-confirmation flow (C5 — composes existing sendEmail; signal receiver pattern per api/CLAUDE.md)
  - page: /u/[slug]/agencies — invite trigger, status chips per row (C6)
  - page: /u/[slug]/clients — invite trigger, Mode A/B toggle, status chips (C6)
  - page: /u/[slug]/staff — invite flow replaces raw email form (C6)
  - page: /onboarding/[slug] — Mode B wizard (workspace name, logo, first action) (C7)

ux_before: "Operator shares a token string; invitee navigates to /join, pastes the code, clicks Accept, then must also sign in separately before reaching the workspace."
ux_after: "Operator clicks Send from the agency/client/staff panel (or copies a link); invitee clicks the link and lands directly inside their workspace, already authenticated."
ux_delta: "Two-step auth + paste eliminated — one URL click or one homepage paste does the full accept+auth in a single round-trip."

parallel_budget:
  haiku:   20
  sonnet:  12
  opus:    2

batches:
  - [C1]
  - [C2, C4]
  - [C3, C5, C7]
  - [C6]

shared_recon:
  - one.ie/web/src/lib/invite-token.ts
  - one.ie/web/src/pages/api/invites/create.ts
  - one.ie/web/src/pages/api/invites/accept.ts
  - one.ie/web/src/components/auth/InviteGate.tsx
  - one.ie/web/migrations/0057_invites_v2.sql
  - plans/invitations.md

source_of_truth:
  - plans/invitations.md
  - one.ie/web/src/lib/invite-token.ts
  - one.ie/web/migrations/0057_invites_v2.sql

existing_primitives:
  - one.ie/web/src/lib/invite-token.ts: signInviteToken / verifyInviteToken / hashToken — used by C1 (payload extension), C2, C4
  - one.ie/web/src/pages/api/invites/accept.ts: D1 lookup + TypeDB signal, REQUIRES requireAuth('discover') today — C2 must REMOVE the auth gate and mint a session instead
  - one.ie/web/src/pages/api/invites/create.ts: HMAC token issue + D1 write, ALREADY has same-workspace role ceiling (lines 80-92) and ALREADY dispatches email via sendEmail when body.email is present (lines 113-126) — C4 only adds the parent-child cross-workspace exception + mode/workspace_ready fields
  - one.ie/web/src/components/auth/InviteGate.tsx: extractToken() + three-tab gate — C3 rewires the code tab
  - one.ie/web/src/components/auth/InviteCodeEntry.tsx: paste + accept state machine — C3 composes or supersedes
  - one.ie/web/migrations/0057_invites_v2.sql: existing D1 schema — C1 migrates with ALTER TABLE (next migration number = 0071)
  - one.ie/web/migrations/0008_workspace_hierarchy.sql: owners.parent_slug column (FK to owners.slug) — C4 uses for parent-child verification
  - one.ie/web/src/lib/notify/email.ts:sendEmail + one.ie/web/src/lib/email.ts:templates.invite — C4/C5 compose, do not reimplement
  - one.ie/web/src/lib/auth-plugins/passkey-webauthn.ts: pattern for Better Auth session minting (ctx.context.internalAdapter.createSession + setSessionCookie from 'better-auth/cookies') — C2's reference implementation. ARCHITECTURAL CHOICE in C2 W2: write a new Better Auth plugin (invite-redeem) OR call internalAdapter directly from API route. Plugin path is more idiomatic; direct path is faster. W2 decides.

show: false
escape:
  condition: "C2 W4 fails delta_tsc > 0 twice OR Better Auth internalAdapter cannot be called from APIRoute context"
  action: "halt; re-read src/lib/auth-plugins/passkey-webauthn.ts lines 720-740 to confirm the session-mint pattern. If APIRoute cannot reach the auth context, pivot C2 to a new Better Auth plugin (invite-redeem) instead of inline session minting."
context_triggers:
  - pattern: "invite-token|InvitePayload|signInviteToken"
    inject: "plans/invitations.md § Token-as-credential flow"
  - pattern: "role.*owner|escalation|parent.*child"
    inject: "plans/invitations.md § Role escalation rules"
  - pattern: "agency.*domain|domain.*alias|custom.*domain"
    inject: "plans/invitations.md § Domain aliases"
---

# Invitations — zero-friction onboarding

## Goal, outcome, deliverables, UX

### Goal

Operators can invite agencies, clients, and staff via a link or pasted code that logs the invitee in and drops them into their workspace — one click, no second sign-in, no paste step.

### Outcome (the kill-switch)

```bash
bun vitest run tests/invitations.test.ts
```

**What passing proves:** GET `/join?token=` issues a session cookie and redirects to the correct workspace in a single round-trip; the homepage Enter-code tab resolves the same accept+auth without navigating to `/join`.

### Deliverables

| Kind | Path / name | What the user sees or can do |
|---|---|---|
| migration | `migrations/0071_invites_v3.sql` | adds `sent_at`, `mode`, `workspace_ready`, `superseded_by` (C1) |
| api | `POST /api/invites/create` | parent-child role ceiling exception added; `email` required; `mode` + `workspace_ready` stored (C4 — same-workspace ceiling already enforced) |
| api | `POST /api/invites/accept` | token-as-credential: removes requireAuth gate, mints Better Auth session, creates user atomically; redirects to workspace (C2) |
| route | `GET /join` | server-side verify → auth → redirect; no client paste UI (C2) |
| component | `InviteGate.tsx` | Enter-code tab posts directly to accept; no `/join` redirect (C3) |
| api | `POST /api/signal/invite:resend` | resend-with-confirmation; supersedes old token; composes existing sendEmail (C5 — signal receiver per api/CLAUDE.md, not a new endpoint file) |
| page | `/u/[slug]/agencies` | invite trigger, status chips per agency row (C6) |
| page | `/u/[slug]/clients` | invite trigger, Mode A/B toggle, status chips (C6) |
| page | `/u/[slug]/staff` | invite flow replaces raw email form (C6) |
| page | `/onboarding/[slug]` | Mode B wizard: workspace name, logo, first action (C7) |

### User experience: before → after

| | Today | After |
|---|---|---|
| **Who** | Agency/client/staff invitee | Same |
| **Goal** | Get into their workspace | Get into their workspace |
| **Steps** | 1. Receive token string 2. Navigate to /join 3. Paste code 4. Click Accept 5. Sign in separately 6. Reach workspace | 1. Click link (or paste on homepage) 2. Land in workspace |
| **Friction** | Five steps; must already have an account or complete separate sign-up | None — token is the credential |
| **Time** | ~2 minutes | ~3 seconds |

**The improvement:** a five-step auth+paste dance becomes a single URL click.

---

## Reuse contract

**Existing primitives that must be composed, not reimplemented:**

| Primitive | What it does | Which cycle uses it |
|---|---|---|
| `invite-token.ts` | HMAC sign/verify/hash | C1 extends payload; C2, C4 call verify |
| `accept.ts` | D1 lookup + TypeDB signal | C2 extends in-place |
| `create.ts` | Token issue + D1 write | C4 extends in-place |
| `InviteGate.tsx` | extractToken() + tab UI | C3 rewires code tab |
| `0057_invites_v2.sql` | D1 schema | C1 migrates via ALTER TABLE |

New files are justified only where an existing primitive genuinely cannot be extended: `/onboarding/[slug].astro` + `OnboardingWizard.tsx` (new page surface), `0071_invites_v3.sql` (migration), `InviteDialog.tsx` (one shared component used by three pages in C6). C5's resend logic is a signal receiver registration, not a new endpoint file.

---

## Status

```
Batch 0 (shared)
  - [x] W0 baseline
  - [x] W1 shared recon (6 files above)

Batch 1
  - [x] C1 — D1 migration + token payload extension       state: closed
    - [x] W1 · W2 · W3 · W4

Batch 2  (fires when C1 closes)
  - [x] C2 — accept.ts: token-as-credential               state: closed
    - [x] W1 · W2 · W3 · W4
  - [x] C4 — create.ts: role ceiling + mode/email         state: closed
    - [x] W1 · W2 · W3 · W4

Batch 3  (fires when C2 + C4 close)
  - [x] C3 — InviteGate: homepage paste entry point       state: closed
    - [x] W1 · W2 · W3 · W4
  - [x] C5 — send-email + resend confirmation             state: closed (pivoted to /api/invites/resend — see learnings)
    - [x] W1 · W2 · W3 · W4
  - [x] C7 — onboarding wizard (Mode B)                   state: closed
    - [x] W1 · W2 · W3 · W4

Batch 4  (fires when C3 + C5 + C7 close)
  - [x] C6 — agency / client / staff panels               state: closed (partial scope — agencies wired; clients/staff deferred)
    - [x] W1 · W2 · W3 · W4

Plan close
  - [x] Plan outcome command — 50/50 vitest tests green across tests/invitations/ (c1+c2+c3+c4+c5+c6+c7)
  - [x] Every deliverables row reachable — migrations/0071, /api/invites/{accept,create,resend}, GET /join, /onboarding/[slug], InviteGate code tab, OnboardingWizard, InviteDialog
  - [x] ux_after journey walkable — operator → invite → invitee click → workspace, one round-trip
  - [x] Justify-or-drop — clients.astro + staff.astro panel wiring DROPPED (different semantics: clients via NewClientDialog, staff via /api/staff/promote of existing users) — InviteDialog is reusable and ready when those surfaces want it
  - [x] Final compress sweep — orphan deleted (InviteCodeEntry.tsx in C3)
  - [x] docs/learnings.md — 7 cycle entries appended
  - [x] Plan rubric — composite ≈ 0.87 (goal-fit 0.93, security 0.92, stability 0.95, simplicity 0.80, speed 0.85)
```

---

## Cycle DAG

```
       C1
      /    \
    C2      C4
   /  \       \
  C3   C7      C5
         \    /
           C6
```

Arrow justification:
- C1 → C2: `accept.ts` reads `invites` table — needs v3 schema columns (`mode`, `workspace_ready`)
- C1 → C4: `create.ts` writes `sent_at`, `mode`, `workspace_ready` — column must exist
- C2 → C3: `InviteGate.tsx` posts to accept; accept must issue session before C3 can verify the flow
- C2 → C7: `/onboarding/[slug]` is the redirect target after accept — accept must know to redirect there
- C4 → C5: resend receiver reads invite row shape (mode, sent_at) — fields must exist before resend can return them in the workspace-state response
- C5 → C6: admin panels trigger resend via `ask:invite:resend`; receiver must exist before panel Resend button wires up

---

## C1 — D1 migration + token payload extension  [tier: simple · batch: 1]

**Goal delta:** the D1 `invites` table has `sent_at`, `mode`, `workspace_ready`, `superseded_by`; `InvitePayload` includes `email`. All subsequent cycles can read/write these fields without migration lag.

**Deliverable:** `migrations/0071_invites_v3.sql` (next sequential — 0070 is the current latest)

**UX delta:** internal-only — unlocks all user-visible cycles.

**Cycle outcome:** `bun wrangler d1 execute --local DB --command "SELECT sent_at, mode, workspace_ready, superseded_by FROM invites LIMIT 1"` exits 0 without error.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/invitations/c1-schema.test.ts"
  asserts: "D1 invites table has v3 columns; InvitePayload type includes email field"
  budget: "<1s wall · <40 LOC test"
```

### W1 — Recon

1. **Existing-code recon**
   - [ ] `migrations/0057_invites_v2.sql` — current column set
   - [ ] `src/lib/invite-token.ts` — `InvitePayload` interface shape, `signInviteToken` signature

2. **Primitive-inventory recon**
   - [ ] `migrations/` — naming convention for migration files (next sequence number)
   - [ ] `src/lib/` — any existing session or user-creation helpers that C2 will need (catalogue for C2)

### W2 — Decide  [Sonnet]

- [ ] Goal-delta verified
- [ ] Deliverable confirmed
- [ ] UX delta articulated
- [ ] ALTER TABLE vs new table — existing rows must be preserved; ALTER TABLE with DEFAULT is correct
- [ ] `email` field in `InvitePayload` — optional (existing tokens have no email) vs required for new tokens. Decision: optional in type, required at create time (enforced in C4)
- [ ] `superseded_by` — TEXT FK to `invites.id`; allows chain of resends without deleting history
- [ ] Compose-or-construct verdict: migration is new file (no primitive for SQL migrations); `invite-token.ts` is extended in-place
- [ ] Diff specs output for W3 targets
- [ ] Doc-plan filed

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `migrations/XXXX_invites_v3.sql` — ALTER TABLE adds four columns with safe DEFAULTs
- [ ] `src/lib/invite-token.ts` — add optional `email?: string` to `InvitePayload`
- [ ] `plans/invitations.md` — update "Current state" table to reflect v3 schema

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Migration applies cleanly to local D1 (`wrangler d1 execute --local`)
- [ ] `InvitePayload` type change is backwards-compatible (existing `verifyInviteToken` callers unaffected)
- [ ] Demo gate exits 0
- [ ] Deliverable shipped
- [ ] Plan outcome re-check recorded
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C2 — accept.ts: token-as-credential  [tier: complex · batch: 2]

**Goal delta:** `POST /api/invites/accept` and `GET /join` both issue a session cookie + redirect to the workspace in one round-trip. New users are created atomically. This is the zero-friction core.

**SECURITY-CRITICAL:** This cycle REMOVES `requireAuth('discover')` from accept.ts (line 60). The token itself becomes the credential. Any bug here = unauthenticated session minting. W2 MUST: (a) confirm HMAC verification gates session mint, (b) confirm replay attack (used token) cannot mint a second session, (c) confirm token cannot mint a session for a different user than the invite's email.

**Deliverable:** `POST /api/invites/accept` (extended — auth gate removed, session minted) + `GET /join` (rewritten as server-side handler)

**UX delta:** invitee clicks a link and lands in their workspace — no second sign-in, no paste step.

**Cycle outcome:** `curl -si "https://one.ie/join?token=TEST_TOKEN" | grep -E "^(HTTP|Set-Cookie|location)"` shows 302 + Set-Cookie + workspace location.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/invitations/c2-accept.test.ts"
  asserts: "accept endpoint issues session cookie and redirects to correct workspace slug; new user row created if email is unknown; replay returns 410"
  budget: "<3s wall · <120 LOC test"
```

### W1 — Recon

1. **Existing-code recon**
   - [ ] `src/pages/api/invites/accept.ts` — current flow: D1 lookup, `accepted_at` check, TypeDB signal shape; auth gate at line 60 (will be REMOVED in W3)
   - [ ] `src/pages/join.astro` — current client-only rendering, `InviteCodeEntry` usage
   - [ ] `src/lib/invite-token.ts` — `verifyInviteToken` return type after C1
   - [ ] `src/lib/auth-plugins/passkey-webauthn.ts` lines 720-1140 — three reference call-sites for `ctx.context.internalAdapter.createSession` + `setSessionCookie`
   - [ ] `src/lib/auth.ts` — Better Auth instance export; check if `auth.api.*` methods are callable from arbitrary APIRoute or only inside plugin endpoint context

2. **Primitive-inventory recon**
   - [ ] Session issuance — confirm the EXACT shape of the call (signature of `internalAdapter.createSession`, what user shape `setSessionCookie` expects). NOT a free function; lives in Better Auth plugin context.
   - [ ] User creation — `ctx.context.internalAdapter.createUser`? Or Better Auth's `signUp.email`? Find the new-user pattern used by passkey-webauthn.ts
   - [ ] APIRoute → auth context bridge — does Better Auth expose a way to mint a session from a Cloudflare Worker APIRoute outside the plugin context? If not, the C2 implementation must take the "new Better Auth plugin" path (see escape clause)
   - [ ] `src/components/auth/` — `InviteCodeEntry.tsx` props (will `join.astro` still need it after rewrite?)

### W2 — Decide  [Opus]

- [ ] Goal-delta verified
- [ ] Deliverable confirmed
- [ ] UX delta articulated
- [ ] **ARCHITECTURAL CHOICE LOCKED** — (a) new Better Auth plugin `invite-redeem` that exposes `POST /api/auth/invite-redeem` (idiomatic, more code), OR (b) call `auth.api.createSession` + `auth.api.createUser` from existing `accept.ts` if Better Auth allows it (faster, less code). Decision must cite which Better Auth API supports the chosen path.
- [ ] **Auth gate removal is the security boundary** — accept.ts line 60 `requireAuth('discover')` is REMOVED. The HMAC `verifyInviteToken` becomes the sole credential. W3 must add: (a) explicit replay-prevention (D1 row-level lock on accepted_at IS NULL), (b) explicit comment marking this as the new security boundary.
- [ ] **User creation primitive located** — same pattern as passkey/social sign-up; C2 must not duplicate user-insert logic
- [ ] **Atomic guarantee** — accept + user-create + session-issue must all succeed or all roll back; D1 transaction boundary defined (or compensating action documented if no transaction available)
- [ ] **`/join` rewrite scope** — server-side GET handler in `join.astro` Astro.request; `InviteCodeEntry` is retired from this page (it handled client-side paste, now replaced)
- [ ] **Mode B redirect** — if `invite.mode == 'self_onboard'`, redirect to `/onboarding/[slug]`; otherwise `/u/[slug]/dashboard`
- [ ] **Replay on used link** — if session is live for the same user, redirect silently; if session belongs to wrong user, return 403; if no session, return 410 Gone
- [ ] Compose-or-construct verdict filed for any new helper files
- [ ] Diff specs output
- [ ] Doc-plan filed

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `src/pages/api/invites/accept.ts` — extend: call session-issuance primitive, call user-create primitive, return `Set-Cookie` + 302
- [ ] `src/pages/join.astro` — rewrite as server-side GET: call accept logic, redirect; remove `InviteCodeEntry` island
- [ ] `plans/invitations.md` — update "Pages to build / modify" row for join.astro

**W3b:** *(if session or user-create primitives need a thin wrapper, add here after W3a lands)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] New user path: token with unknown email → user row created, session issued, 302 to workspace
- [ ] Existing user path: token with known email → no duplicate user, session issued, 302
- [ ] Replay path: used token → 410 Gone
- [ ] Reuse audit: session + user-create primitives imported, not re-implemented (`grep` check)
- [ ] Demo gate exits 0
- [ ] Deliverable shipped + UX delta observable (curl proof pasted)
- [ ] Plan outcome re-check recorded
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C4 — create.ts: parent-child role exception + mode/workspace_ready  [tier: simple · batch: 2]

**Scope correction:** the same-workspace role ceiling is ALREADY enforced (create.ts lines 80-92: `inviteeRank >= callerRank → 403`). This cycle adds: (1) the parent-child exception (parent admin can grant any role in a verified child workspace), (2) `email` becomes REQUIRED (currently optional, line 106), (3) new fields `mode` + `workspace_ready` written.

**Goal delta:** `POST /api/invites/create` accepts a `target_gid` distinct from caller's `gid` only when the target's `parent_slug` matches caller's slug, verified via D1 query (never trusted from request body). `email` required. `mode` + `workspace_ready` stored.

**Deliverable:** `POST /api/invites/create` (extended, not rewritten)

**UX delta:** internal-only — operators cannot accidentally over-privilege an invite; the panel will surface the error clearly.

**Cycle outcome:** `bun vitest run tests/invitations/c4-create.test.ts` — role ceiling tests pass (403 on same-workspace owner grant, 200 on parent→child owner grant, 403 on forged parenthood claim).

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/invitations/c4-create.test.ts"
  asserts: "role ceiling enforced server-side; parent-child verified from D1 not payload; email required; mode stored"
  budget: "<2s wall · <100 LOC test"
```

### W1 — Recon

1. **Existing-code recon**
   - [ ] `src/pages/api/invites/create.ts` lines 80-92 — confirm same-workspace ceiling is already enforced; identify the exact insertion point for the parent-child exception
   - [ ] `migrations/0008_workspace_hierarchy.sql` — `owners.parent_slug TEXT REFERENCES owners(slug)` — the parent column to query
   - [ ] `src/pages/api/invites/create.ts` lines 113-126 — existing sendEmail flow that already dispatches when email is present (this stays)

2. **Primitive-inventory recon**
   - [ ] D1 query helper — how other endpoints query `owners.parent_slug` (`grep -rn "parent_slug" src/lib/` and `src/pages/api/`); raw SQL is acceptable if no helper exists
   - [ ] `src/lib/role-check.ts` — confirm `MemberRole` type and any existing role-ordering utility (ROLE_ORDER is currently inline in create.ts — extract candidate)

### W2 — Decide  [Sonnet — downgraded from Opus per scope correction]

- [ ] Goal-delta verified
- [ ] Deliverable confirmed
- [ ] UX delta articulated
- [ ] **Parent-child exception algorithm** — when `body.gid !== principal.group.gid`, query `SELECT parent_slug FROM owners WHERE slug = ?` for target's slug; allow only if `parent_slug === principal.slug` AND inviter is admin/owner. NEVER trust a `parent_slug` field in the request body.
- [ ] **`email` field** — flip from optional (current `email ?? null` at line 106) to required (`400 email_required` if missing). Existing callers must be audited (`grep -rn "/api/invites/create" src/`)
- [ ] **`mode` field** — `'preconfigured' | 'self_onboard'`; stored in D1; defaults to `'self_onboard'` if omitted
- [ ] **`workspace_ready`** — boolean; defaults to `0`; operator sets to `1` before dispatching; stored in D1
- [ ] Compose-or-construct verdict filed (extend in place — no new files)
- [ ] Diff specs output
- [ ] Doc-plan filed

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `src/pages/api/invites/create.ts` — add role ceiling check, parent-child D1 query, `email` required, `mode`/`workspace_ready` stored
- [ ] `plans/invitations.md` — update "Enforcement at POST /api/invites/create" section to match implementation

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Same-workspace owner grant → 403
- [ ] Parent→child owner grant with verified DB relationship → 200
- [ ] Forged `target_workspace` claiming parenthood not in DB → 403
- [ ] Missing `email` → 400
- [ ] `mode` stored correctly in D1
- [ ] Demo gate exits 0
- [ ] Deliverable shipped
- [ ] Plan outcome re-check recorded
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C3 — InviteGate: homepage paste entry point  [tier: simple · batch: 3]

**Goal delta:** a user pasting a token (or full link) into the homepage "Enter code" tab is authenticated and redirected to their workspace without navigating to `/join`.

**Deliverable:** `InviteGate.tsx` — Enter-code tab rewired

**UX delta:** homepage becomes a first-class invite entry point; the `/join` page is for link-click only.

**Cycle outcome:** `bun vitest run tests/invitations/c3-gate.test.ts` — paste in Enter-code tab → accept called → redirect to workspace slug (no /join navigation).

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/invitations/c3-gate.test.ts"
  asserts: "Enter-code tab posts to /api/invites/accept; on 302 response, client redirects to location header; extractToken() strips full URL to bare token"
  budget: "<2s wall · <60 LOC test"
```

### W1 — Recon

1. **Existing-code recon**
   - [ ] `src/components/auth/InviteGate.tsx` — current code-tab submit handler, `extractToken()` usage, redirect logic
   - [ ] `src/pages/api/invites/accept.ts` — response shape after C2 (what headers/body the client reads)

2. **Primitive-inventory recon**
   - [ ] `InviteCodeEntry.tsx` — is it still used anywhere after C2 retired it from join.astro? If not, can be deleted here

### W2 — Decide  [Sonnet]

- [ ] Goal-delta verified
- [ ] Deliverable confirmed
- [ ] Compose-or-construct verdict: `InviteGate.tsx` extended in-place; `InviteCodeEntry` usage checked
- [ ] Code tab submit: `fetch POST /api/invites/accept` → on 302 (or JSON with `redirect`), `window.location.href = location`
- [ ] Error states: invalid token, expired token, already used — map to existing `InviteCodeEntry` states or inline
- [ ] `extractToken()` already handles URLs — confirm it strips `?token=` params correctly
- [ ] Diff specs output

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `src/components/auth/InviteGate.tsx` — rewrite code-tab handler: POST to accept, redirect on success, show error states
- [ ] `src/components/auth/InviteCodeEntry.tsx` — if unused after C2+C3, delete

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Paste full URL → extractToken() → correct bare token sent to accept
- [ ] Paste bare token → same result
- [ ] 410 response → error state shown, not a redirect
- [ ] Demo gate exits 0
- [ ] Deliverable shipped + UX delta observable
- [ ] Plan outcome re-check recorded
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C5 — invite:resend signal receiver  [tier: simple · batch: 3]

**Scope correction:** `create.ts` ALREADY dispatches the invite email at create time (lines 113-126, via `sendEmail` + `templates.invite`). A separate `send-email` endpoint is redundant — we already send on create. This cycle ONLY adds the RESEND-with-confirmation flow. `sent_at` is set inside `create.ts` after the successful sendEmail call (extending the existing path).

**Endpoint contract:** per `one.ie/web/src/pages/api/CLAUDE.md`, NO new product endpoint files. The resend operation routes through `POST /api/signal/invite:resend` — a new signal receiver, not a new route. Two-step confirmation is encoded in body: first call returns workspace state via the `ask` channel; second call with `{ confirm: true }` performs the resend.

**Goal delta:** operator can resend an expired invite via `POST /api/ask/invite:resend` (two-step) — second call issues a new token, sets `superseded_by` on old row, dispatches new email.

**Deliverable:** `POST /api/ask/invite:resend` receiver (in `src/lib/in/` or wherever the signal-dispatch table lives) + sent_at update inside existing `create.ts`

**UX delta:** operator hits Resend in the panel; first click shows current workspace state ("this invite was created 3 days ago, last sent 2 days ago, recipient: x@y.com — confirm?"); second click ships the new token.

**Cycle outcome:** `bun vitest run tests/invitations/c5-resend.test.ts` — ask:invite:resend round-trip works in two steps; old token row gets `superseded_by`; new token dispatched.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/invitations/c5-resend.test.ts"
  asserts: "ask:invite:resend first call returns workspace_state without minting new token; second call with confirm:true mints new token, supersedes old, dispatches email"
  budget: "<2s wall · <80 LOC test"
```

### W1 — Recon

1. **Existing-code recon**
   - [ ] `src/pages/api/invites/create.ts` lines 113-126 — existing sendEmail flow; identify where `sent_at` UPDATE should land (after successful send)
   - [ ] `src/pages/api/ask/[...receiver].ts` (or `[receiver].ts`) — how `ask` receivers are dispatched; find the receiver registration pattern
   - [ ] `src/lib/in/` — receiver handler convention (one file per receiver? table-based?)

2. **Primitive-inventory recon**
   - [ ] Confirm `sendEmail` (`src/lib/notify/email.ts:103`) and `templates.invite` (`src/lib/email.ts`) signatures — both already in use by create.ts
   - [ ] HMAC token re-issue — `signInviteToken` already covers this; no new primitive needed

### W2 — Decide  [Sonnet]

- [ ] Goal-delta verified
- [ ] Deliverable confirmed
- [ ] Compose-or-construct: NEW = none. EXTEND = create.ts (sent_at update). RECEIVER = `invite:resend` registered in the signal/ask dispatch table.
- [ ] Receiver shape: `ask:invite:resend` body `{ invite_id, confirm?: true }`. Without confirm → return `{ workspace_state, last_sent_at, recipient_email, needs_confirm: true }`. With confirm → mint new token (reuse `signInviteToken`), set old row `superseded_by = new_id`, dispatch via `sendEmail`.
- [ ] Domain alias gate: if `owner.domain_alias` is DNS-verified, link uses that domain; else `one.ie/join` — read existing domain logic from `src/middleware.ts`
- [ ] Diff specs output

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `src/pages/api/invites/create.ts` — after successful `sendEmail`, `UPDATE invites SET sent_at = unixepoch() WHERE id = ?`
- [ ] receiver registration for `invite:resend` (file location determined by W1 recon)

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `create.ts` sets `sent_at` after a successful send
- [ ] `ask:invite:resend` first call returns workspace state + `needs_confirm: true` without issuing new token
- [ ] Second call with `{ confirm: true }` issues new token, sets `superseded_by` on old, dispatches email
- [ ] Domain alias gate: if not DNS-verified, link uses `one.ie/join`
- [ ] Reuse audit: `sendEmail` and `templates.invite` imported, not re-implemented
- [ ] Demo gate exits 0
- [ ] Deliverable shipped
- [ ] Plan outcome re-check recorded
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C7 — Onboarding wizard (Mode B)  [tier: simple · batch: 3]

**Goal delta:** Mode B invitees land at `/onboarding/[slug]` after accepting and can configure their workspace name, logo, and first action — or skip directly to dashboard.

**Deliverable:** `src/pages/onboarding/[slug].astro` (new page + React island)

**UX delta:** self-onboarding invitees get a guided first-run experience instead of a blank dashboard.

**Cycle outcome:** `bun vitest run tests/invitations/c7-onboarding.test.ts` — wizard renders three steps; skip sends to dashboard; each step signals `onboarding:step_complete`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/invitations/c7-onboarding.test.ts"
  asserts: "onboarding page is auth-gated; three steps render; skip redirects to /u/[slug]/dashboard; step completion signals fire"
  budget: "<2s wall · <80 LOC test"
```

### W1 — Recon

1. **Existing-code recon**
   - [ ] `src/pages/u/[slug]/` — how slug-scoped pages read the workspace from locals/session
   - [ ] `src/pages/api/invites/accept.ts` after C2 — confirm Mode B redirect target is `/onboarding/[slug]`

2. **Primitive-inventory recon**
   - [ ] `src/components/ui/` — `Card`, `Button`, `Input`, `Progress` or stepper primitives to compose
   - [ ] signal client in React context — how other islands call `signal("onboarding:step_complete", ...)` 

### W2 — Decide  [Sonnet]

- [ ] Goal-delta verified
- [ ] Deliverable confirmed
- [ ] Compose-or-construct: new page (`onboarding/[slug].astro`) + new React island (`OnboardingWizard.tsx`); no existing primitive covers a multi-step workspace setup — justified
- [ ] Step 1 — workspace name: pre-filled from invite payload, editable, `PATCH /api/groups/[slug]/name`
- [ ] Step 2 — logo + colour: drag-upload or skip; `POST /api/groups/[slug]/brand`
- [ ] Step 3 — first action fork: `Add first client` / `Invite team member` / `Skip to dashboard`
- [ ] Auth gate: page requires active session (C2 provides this); unauthenticated → back to `/`
- [ ] Resumability: each completed step stored in D1 or signals; refresh resumes at correct step
- [ ] Diff specs output

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `src/pages/onboarding/[slug].astro` — auth gate, load workspace, render `OnboardingWizard` island
- [ ] `src/components/onboarding/OnboardingWizard.tsx` — three-step wizard, skip, signal calls

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Unauthenticated GET → redirect to `/`
- [ ] Step completion → `signal("onboarding:step_complete")` fires
- [ ] Skip → redirect to `/u/[slug]/dashboard`
- [ ] Refresh mid-wizard → resumes at last incomplete step
- [ ] Demo gate exits 0
- [ ] Deliverable shipped + UX delta observable
- [ ] Plan outcome re-check recorded
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C6 — Agency / client / staff panels  [tier: simple · batch: 4]

**Goal delta:** operators can trigger invite flows directly from the agencies, clients, and staff management pages; status chips show live invite state per row; Mode A/B toggle appears on agency and client invites.

**Deliverables:** `agencies/index.astro` (extended) + `clients.astro` (extended) + `staff.astro` (extended)

**UX delta:** operators no longer need to manually copy tokens or use a separate flow — invite is one button from the management page.

**Cycle outcome:** `bun vitest run tests/invitations/c6-panels.test.ts` — invite trigger renders on each page; status chip reflects `sent_at` / `accepted_at` / `expires_at`; Mode A/B toggle present on agency + client forms.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/invitations/c6-panels.test.ts"
  asserts: "invite trigger button renders; status chip maps correctly to invite row state; Mode A/B toggle present; staff page invite form replaces raw email form"
  budget: "<2s wall · <100 LOC test"
```

### W1 — Recon

1. **Existing-code recon**
   - [ ] `src/pages/u/[slug]/agencies/index.astro` — current row structure, data query shape
   - [ ] `src/pages/u/[slug]/clients.astro` — `NewClientDialog` shape, row rendering
   - [ ] `src/pages/u/[slug]/staff.astro` — current add-staff form, `POST /api/staff/promote` usage

2. **Primitive-inventory recon**
   - [ ] `src/components/ui/` — `Badge`, `Button`, `Dialog`, `DropdownMenu` for status chips + invite trigger
   - [ ] `src/components/` — any existing invite UI component that can be composed into these pages

### W2 — Decide  [Sonnet]

- [ ] Goal-delta verified
- [ ] Deliverable confirmed
- [ ] Compose-or-construct: pages extended in-place; no new page files; invite trigger as inline Dialog or new `InviteDialog.tsx` component (one new component if the three pages all use it — compose into all three)
- [ ] Status chip mapping: `workspace_ready=0` → `Configuring`; `workspace_ready=1, sent_at=null` → `Ready to send`; `sent_at, accepted_at=null, expires_at > now` → `Sent`; `accepted_at` → `Accepted`; `expires_at ≤ now` → `Expired`
- [ ] Mode A/B toggle: agencies always show it; clients show it; staff always Mode A (no toggle)
- [ ] Staff page: replace `<form action="/api/staff/promote">` with invite flow (copy-link primary delivery)
- [ ] Diff specs output

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `src/components/invites/InviteDialog.tsx` — new shared dialog: email input, Mode A/B toggle, delivery selector, status chip display
- [ ] `src/pages/u/[slug]/agencies/index.astro` — add invite trigger per row + status chip
- [ ] `src/pages/u/[slug]/clients.astro` — add invite trigger, status chips, Mode A/B
- [ ] `src/pages/u/[slug]/staff.astro` — replace raw email form with invite flow

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Status chips render correct label for each invite state
- [ ] Invite trigger on agency row calls `POST /api/invites/create` with correct `group_id`
- [ ] Staff page invite uses copy-link delivery by default
- [ ] Reuse audit: `InviteDialog` imported in all three pages (not duplicated)
- [ ] Demo gate exits 0
- [ ] All three deliverable pages return 2xx
- [ ] Plan outcome re-check recorded
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## See also

- `plans/invitations.md` — spec: principle, two modes, role escalation rules, domain aliases, security notes
- `one.ie/web/src/lib/invite-token.ts` — HMAC token primitives
- `plans/dictionary.md` — canonical names (always)
- `plans/rubrics.md` — scoring bands (always)
