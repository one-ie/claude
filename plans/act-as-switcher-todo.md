---
title: Act-As from the profile menu + dedup the sidebar switchers
slug: act-as-switcher
type: plan
tier: complex
mode: construction
tags: [sidebar, impersonation, act-as, groups, middleware, viewer]

# ─── GOAL CONTRACT ───────────────────────────────────────────────────
goal: "An operator can act as any actor in their group hierarchy from the sidebar profile menu — the session actually swaps server-side, a persistent banner shows it, and the workspace list stops being duplicated in two places."
outcome: "cd one.ie/web && bun run verify && bun vitest run tests/e2e/act-as-switcher.test.ts"
outcome_asserts: "tree endpoint returns members per org node; AuthButton renders a hierarchy-grouped person picker that POSTs /api/act-as with a reason chip; middleware verifies the act-as cookie, swaps the effective uid, and blocks non-GET in read mode; Layout renders the banner from locals."

deliverables:
  - api:       GET /api/groups/tree — each org/client node carries members[] {uid,name,role} (C1)
  - middleware: src/middleware.ts — verifies session-act-as cookie, sets locals.actingAs, swaps effective uid, blocks non-GET in read mode (C2)
  - component: web/src/components/auth/AuthButton.tsx — workspace list removed; "Switch user" hierarchy picker + reason-chip confirm → POST /api/act-as (C3)
  - component: web/src/layouts/Layout.astro + ActAsBanner.tsx — banner mounts from locals.actingAs; target avatar gets a ring while acting (C4)

ux_before: "Operator switches workspace in TWO places (top GroupSwitcher and bottom AuthButton), and there is no way to impersonate a user — the act-as backend exists but nothing triggers it or honors it."
ux_after: "Top switcher = where you are; bottom menu = who you are + 'Switch user'. One click on a person (one reason chip) enters a read-only session as them; a red banner shows it and ends it."
ux_delta: "Impersonation goes from impossible (backend was a no-op) to two clicks; the redundant workspace list is gone."

# ─── PARALLELISM ─────────────────────────────────────────────────────
parallel_budget:
  haiku:   12
  sonnet:  8
  opus:    2

batches:
  - [C1, C2]          # foundation: data feed + server enforcement (independent)
  - [C3, C4]          # UI: picker (needs C1 members) + banner (needs C2 locals)

shared_recon:
  - plans/role-switcher.md
  - one.ie/web/src/lib/act-as.ts
  - one.ie/web/src/pages/api/groups/tree.ts
  - one.ie/web/src/components/auth/AuthButton.tsx
  - one.ie/web/src/middleware.ts

source_of_truth:
  - plans/role-switcher.md
  - one.ie/web/src/lib/act-as.ts
existing_primitives:
  - one.ie/web/src/lib/act-as.ts: verifyActAsCookie/signActAsCookie/checkAllowMatrix/buildActAs/clear cookie headers — C2 composes verify, C3's POST target already uses sign
  - one.ie/web/src/pages/api/act-as/index.ts: POST /api/act-as (allow-matrix, tier caps, audit signal) — C3 calls it; do NOT reimplement
  - one.ie/web/src/pages/api/act-as/end.ts: POST /api/act-as/end — ActAsBanner already calls it; C4 reuses
  - one.ie/web/src/components/sidebar/ActAsBanner.tsx: full banner component, currently unmounted — C4 mounts it, no rewrite
  - one.ie/web/src/pages/api/groups/tree.ts: tree forest + peopleCount query — C1 extends the existing membership-count query to also return members
  - one.ie/web/src/components/auth/AuthButton.tsx: bottom profile menu — C3 edits in place (remove workspace block, add picker)
show: false
escape:
  condition: "C2 W4 fails: middleware swap breaks an unauthenticated route (home/chat 500s) twice"
  action: "halt; the uid swap must be gated on a verified cookie only — re-scope C2 to never touch locals when no act-as cookie present"
context_triggers:
  - pattern: "middleware|locals|swap|uid"
    inject: "plans/role-switcher.md § B1"
  - pattern: "members|aid|membership"
    inject: "plans/role-switcher.md § 7"
---

# Act-As from the profile menu + dedup the sidebar switchers

## Goal, outcome, deliverables, UX

### Goal

An operator can act as any actor in their group hierarchy from the sidebar profile menu — the session actually swaps server-side, a persistent banner shows it, and the workspace list stops being duplicated.

### Outcome (kill-switch)

```bash
cd one.ie/web && bun run verify && bun vitest run tests/e2e/act-as-switcher.test.ts
```

**What passing proves:** tree returns members; AuthButton renders the hierarchy picker and POSTs `/api/act-as` with a reason; middleware verifies the cookie, swaps the uid, blocks non-GET in read mode; Layout renders the banner.

### Deliverables

| Kind | Path | What the user sees / can do | Cycle |
|---|---|---|---|
| api | `GET /api/groups/tree` | org/client nodes carry `members[]` | C1 |
| middleware | `src/middleware.ts` | act-as cookie honored: uid swap + read-mode gate | C2 |
| component | `auth/AuthButton.tsx` | no dup workspace list; "Switch user" picker + reason chips | C3 |
| component | `Layout.astro` + `ActAsBanner.tsx` | banner while acting; target avatar ring | C4 |

### Before → after

| | Today | After |
|---|---|---|
| Who | owner / agency admin | same |
| Goal | see/fix a child account | same |
| Steps | impossible (no trigger; cookie ignored) | open profile menu → Switch user → pick person → tap reason chip |
| Friction | act-as backend is a dead end | two clicks, audit captured via chip |
| Feedback | none | red banner naming real→as + scope, one-click End |

**ux_delta:** Impersonation goes from non-functional to two clicks; the redundant workspace list is removed.

**Proof artifact:**

```
POST /api/act-as {target_uid:"rae", scope_gid:"group:foo", reason:"support", mode:"read"} → 200 {acting_as:"rae",exp,mode:"read"}
GET /u/foo/dashboard (as rae)  → page renders as rae; banner: "Viewing as Rae West · Foo Corp · read-only [End]"
POST /api/anything             → 403 act_as_read_only
```

---

## Reuse contract

The act-as backend (`lib/act-as.ts`, both API routes) and `ActAsBanner.tsx` are **shipped and unused** — every cycle composes them. No new endpoint (the POST/end routes exist). No new banner. The only genuinely new code is: a members field on the tree query (C1), a cookie-verify block in middleware (C2), the picker UI inside AuthButton (C3), and a one-line banner mount (C4).

**Compose-or-construct:** zero new files expected. C3 may add a small `PersonPicker` sub-component inside `auth/` only if AuthButton exceeds ~260 LOC; default is inline.

---

## Testing

One vitest e2e file `tests/e2e/act-as-switcher.test.ts` covers all four cycles (msw for the API contract, @testing-library/react for AuthButton, pure unit for the middleware verify+gate). ≤150 LOC. No Playwright.

---

## Status

```
Batch 1
  - [ ] C1 — tree members feed                     state: ready
    - [ ] W1 · W2 · W3 · W4
  - [ ] C2 — middleware act-as enforcement         state: ready
    - [ ] W1 · W2 · W3 · W4

Batch 2 (fires when C1+C2 close)
  - [ ] C3 — AuthButton dedup + person picker       state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4
  - [ ] C4 — banner mount + acting avatar           state: blocked-on-C2
    - [ ] W1 · W2 · W3 · W4
  - [ ] demo batch (vitest run act-as-switcher.test.ts)

Plan close
  - [ ] outcome command exits 0
  - [ ] every deliverable reachable
  - [ ] ux_after walkable; paste proof artifact
  - [ ] docs: role-switcher.md S14/S15/S16 marked shipped; learnings append
  - [ ] plan rubric ≥ 0.65
```

---

## C1 — tree members feed  [tier: simple · batch: 1]

**Goal delta:** `/api/groups/tree` returns `members[]` on org/client nodes, so the picker can list reachable actors without an N+1 fan-out.
**Deliverable:** `GET /api/groups/tree` — members per node.
**UX delta:** internal — unblocks C3's picker.
**Cycle outcome:** `bun vitest run` asserts a tree node in `agencies`/`clients` section has `members: [{uid,name,role}]`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/act-as-switcher.test.ts -t 'tree members'"
  asserts: "org node carries members[] with uid+name+role"
  budget:  "<2s · part of the shared test file"
```

### W1 — Recon
1. Existing-code
   - [ ] `src/pages/api/groups/tree.ts` — the `countsRows` membership query (~L163) is the extension point; `TreeNode` interface (~L29); `buildNode` (~L181)
   - [ ] `src/lib/substrate.ts` — `typedbQuery` row shape; actor `aid` + `name` selection pattern
2. Primitive-inventory
   - [ ] confirm no existing per-group members endpoint (grep `members` under `pages/api/groups`)

### W2 — Decide
- [ ] Extend the existing `countsRows` query to also `select $aid, $mname, $mrole` (one query, not a new one) — reuse the membership scan that already runs for people-count.
- [ ] Scope: attach `members[]` ONLY to nodes whose `section ∈ {agencies, clients}` (the groups the caller parents). Skip `personal` and `public` to bound payload (a public world may have thousands). Cap each node's members at 50; sort owner/admin first.
- [ ] Add `members: { uid: string; name: string; role: string }[]` to `TreeNode`. KV cache value changes shape → bump the cache key suffix so stale entries don't break the picker.
- [ ] Compose-or-construct: no new file.

### W3 — Edit
**W3a:**
- [ ] `src/pages/api/groups/tree.ts` — widen membership query, build `membersOf` map, set `members` in `buildNode`, add field to `TreeNode`, bump cache key
- [ ] `tests/e2e/act-as-switcher.test.ts` — add `tree members` case (create file; other cycles append)

**W3b:** *(empty)*

### W4 — Verify
- [ ] `bun run verify` green
- [ ] `delta_tsc ≤ 0`
- [ ] `tree members` test passes
- [ ] deploy-surface check: `curl /api/groups/tree?depth=3` returns 200/401 (not 500)
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C2 — middleware act-as enforcement  [tier: complex · batch: 1]

**Goal delta:** the `session-act-as` cookie stops being a no-op — middleware verifies it, swaps the effective uid so pages render as the target, exposes `locals.actingAs`, and blocks mutations in read mode. This is what makes "act as" actually work.
**Deliverable:** `src/middleware.ts` act-as resolution.
**UX delta:** after entering a session the whole app renders as the target (read-only).
**Cycle outcome:** vitest: given a valid read-mode cookie, the resolver returns `{real, as, scope, mode}` and a non-GET request is rejected 403; given no cookie, locals untouched.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/act-as-switcher.test.ts -t 'middleware act-as'"
  asserts: "valid cookie swaps uid + sets locals.actingAs; read-mode blocks non-GET; absent cookie is inert"
  budget:  "<2s · shared file"
```

### W1 — Recon
1. Existing-code
   - [ ] `src/middleware.ts` — where `locals.user`/`locals.session`/`slug`/`workspaceContext` are set (L98–166, 186–327); the request-method + path available there
   - [ ] `src/lib/act-as.ts` — `verifyActAsCookie(cookie, secret)`, `COOKIE_NAME`, `ActAsPayload`, `clearActAsCookieHeader`
   - [ ] `src/env.d.ts` — `App.Locals` shape (add `actingAs?`)
2. Primitive-inventory
   - [ ] `src/pages/api/act-as/end.ts` — confirm its path is the read-mode exception

### W2 — Decide  [Opus · high — security-critical]
- [ ] Read cookie via `COOKIE_NAME`; if absent → do nothing (inert path must be zero-risk — escape condition guards this).
- [ ] On valid payload: set `locals.actingAs = { real, as, scope, mode, reason, exp }`; set the effective acting uid used by downstream slug/workspaceContext resolution to `payload.as` (the target), while keeping `payload.real` for audit. Decide the exact insertion point so the existing viewer/workspace resolution runs against the swapped uid.
- [ ] Read-mode gate: if `mode === 'read'` and `request.method !== 'GET'` and path is NOT `/api/act-as/end` → return `403 {error:'act_as_read_only'}` before the handler runs.
- [ ] Invalid/expired cookie → clear it (`clearActAsCookieHeader`) and proceed as the real user.
- [ ] SERVER_SECRET source: same env access pattern as the POST route.
- [ ] Compose-or-construct: no new file — all logic is a block in `middleware.ts` reusing `act-as.ts`.

### W3 — Edit
**W3a:**
- [ ] `src/env.d.ts` — add `actingAs?: { real; as; scope; mode; reason; exp }` to `App.Locals`
- [ ] `tests/e2e/act-as-switcher.test.ts` — add `middleware act-as` cases (verify swap, read-mode 403, inert when absent)

**W3b (after W3a — needs the locals type):**
- [ ] `src/middleware.ts` — insert cookie-verify + uid-swap + read-mode gate block

### W4 — Verify
- [ ] `bun run verify` green
- [ ] `delta_tsc ≤ 0`
- [ ] `middleware act-as` cases pass
- [ ] security: no-cookie path leaves `locals.actingAs` undefined and never 403s a GET
- [ ] deploy-surface check: `for p in / /chat; do curl -s -o /dev/null -w "%{http_code}" "https://one.ie$p?_t=$(date +%s)"; done` → 200/302 (swap must not break anon routes)
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65 · security ≥ 0.90 (hard)

---

## C3 — AuthButton dedup + person picker  [tier: complex · batch: 2]

**Goal delta:** the bottom menu loses its redundant workspace list and gains "Switch user" — a hierarchy-grouped person picker that, on one reason chip, POSTs `/api/act-as`.
**Deliverable:** `auth/AuthButton.tsx`.
**UX delta:** owner/agency can start an act-as session in two clicks; workspace switching is now only the top switcher.
**Cycle outcome:** RTL: menu has no "Workspaces" block; "Switch user" reveals members grouped by org; clicking a person then the "Support" chip fires `POST /api/act-as` with `{target_uid, scope_gid, reason:'support', mode:'read'}`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/act-as-switcher.test.ts -t 'auth picker'"
  asserts: "no workspace list; grouped picker; chip click POSTs /api/act-as with reason"
  budget:  "<2s · shared file"
```

### W1 — Recon
1. Existing-code
   - [ ] `src/components/auth/AuthButton.tsx` — the `groups` block (L92–121) to remove; menu structure; `/api/groups/tree` fetch (L48–54)
   - [ ] `src/components/sidebar/GroupSwitcher.tsx` — `sectionOf` grouping logic to mirror for the picker
   - [ ] `src/pages/api/act-as/index.ts` — request body contract `{target_uid, scope_gid, reason, mode}`
2. Primitive-inventory
   - [ ] `@/lib/ui-signal` `emitClick`; `lucide-react` icons via `@/components/ui/Icon`; design tokens (no hex)

### W2 — Decide
- [ ] Remove the Workspaces block entirely (top switcher owns it). If a fast path is wanted, replace with a single "Switch workspace (⌘G)" link — DECIDE: default is full removal per the agreed "one canonical place".
- [ ] "Switch user" entry visible only when the tree returns any node with non-empty `members[]` (i.e., the caller parents someone) OR `staffRole`. Server allow-matrix is the real gate; this is just display.
- [ ] Picker = a second view inside the existing menu (back button), grouped by org node, members nested, search filter. Reuse `sectionOf`-style grouping. Row → inline confirm with chips **Setup · Support · Billing** (Support preselected) + "Act as" button → `POST /api/act-as`, then reload.
- [ ] `target_uid = member.uid`, `scope_gid = node.gid`, `mode:'read'`.
- [ ] Compose-or-construct: extend AuthButton in place; extract `PersonPicker` into `auth/` only if file > ~260 LOC.

### W3 — Edit
**W3a:**
- [ ] `src/components/auth/AuthButton.tsx` — remove workspace block; add Switch-user view + grouped picker + reason-chip confirm + POST/reload
- [ ] `tests/e2e/act-as-switcher.test.ts` — add `auth picker` cases (msw mocks tree + act-as)

**W3b:** *(empty)*

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] `auth picker` cases pass
- [ ] design-check hook passes (no hex, tokens only, lucide via Icon)
- [ ] reuse audit: no second workspace-list render; `emitClick` on the act-as trigger (`ui:auth:act-as`)
- [ ] `delta_loc_net` ≤ +120 (removing the workspace block offsets the picker)
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C4 — banner mount + acting avatar  [tier: simple · batch: 2]

**Goal delta:** while acting-as, the shipped `ActAsBanner` renders globally from `locals.actingAs`, and the bottom avatar shows the target with a ring — the bridge that ties identity (bottom) to context (top).
**Deliverable:** `Layout.astro` + `ActAsBanner.tsx` (mount only) + AuthButton ring.
**UX delta:** the operator always sees who they're acting as and can end in one click.
**Cycle outcome:** SSR test/snapshot: when `locals.actingAs` set, Layout output contains the banner with the target name + scope; when unset, no banner.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/act-as-switcher.test.ts -t 'banner'"
  asserts: "banner renders from locals.actingAs and is absent otherwise"
  budget:  "<2s · shared file"
```

### W1 — Recon
1. Existing-code
   - [ ] `src/layouts/Layout.astro` — body root (L121–136); how `Astro.locals` is read in frontmatter
   - [ ] `src/components/sidebar/ActAsBanner.tsx` — props `{actingAs, mode}`; already calls `/api/act-as/end` + reload
2. Primitive-inventory
   - [ ] confirm banner needs the target's display NAME — if `locals.actingAs.as` is a uid, resolve a name (reuse C1 members or `/api/auth/me`-style lookup); DECIDE in W2

### W2 — Decide
- [ ] Mount `<ActAsBanner client:load actingAs={name} mode={mode} />` above `<Sidebar>` in `Layout.astro`, gated on `Astro.locals.actingAs`. Banner is server-gated (can't be hidden client-side) per role-switcher §B1 rule 4.
- [ ] Name resolution: if only uid is in locals, pass uid for v1 (banner still works) and note name-enrichment as a follow-up — do NOT add a query on every request. Prefer threading the name through the act-as cookie? No (cookie carries uid only, by rule 2). Pass uid; acceptable.
- [ ] AuthButton: when `actingAs` present, show target avatar + ring. Source the flag from a small SSR-provided prop or a `/api/auth/me`-style read — DECIDE cheapest; default: Layout passes an `actingAs` boolean prop down.
- [ ] Compose-or-construct: no new file.

### W3 — Edit
**W3a:**
- [ ] `src/layouts/Layout.astro` — read `Astro.locals.actingAs`, conditionally mount banner
- [ ] `src/components/auth/AuthButton.tsx` — ring on avatar when acting (small additive edit; coordinate with C3's file — see W3b note)
- [ ] `tests/e2e/act-as-switcher.test.ts` — add `banner` case

**W3b:** *(AuthButton ring edit runs after C3's AuthButton rewrite settles — same file, different anchor)*

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] `banner` case passes
- [ ] deploy-surface: `curl /chat` 200/302 with no act-as cookie (banner absent, no regression)
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## See also

- `plans/role-switcher.md` § B1 — Act-As spec (this plan ships S15/S16 from its sequence, plus the missing middleware honor step)
- `one.ie/web/src/lib/act-as.ts` — sign/verify/allow-matrix (composed, never reimplemented)
- `.claude/rules/design.md` · `.claude/rules/ui.md` — C3/C4 token + emitClick gates
