# Permissions & Roles Optimisation

**Status:** assessment + design (pre-todo)
**Date:** 2026-05-29
**Source of truth:** `plans/roles.md` · `plans/groups.md` · `plans/auth.md` · `schema/one.tql`
**Sibling gap-docs:** `plans/improve/02-agency.md` · `plans/improve/09-teams.md` · `plans/tenancy-todo.md` (shipped)

---

## Goal

Make the four-tier authority chain — **owner → agency → client → user** — and the six-role permission model **simple to operate**, so that the everyday flows just work:

- An **agency** sets up a **client** workspace in one move.
- An owner/agency can **act-as** (impersonate, login-as) any actor in scope, time-boxed and audited.
- A **client admin** can add someone to the **marketing team** and that person **only sees marketing** — nothing else in the org.

**The roles are locked. We are not renaming them.** The six member-roles stay exactly as the schema defines them:

```
owner | admin | member | viewer | agent | auditor
```

This plan does **not** touch the vocabulary. It closes the gap between "the substrate already supports this" and "an operator can do it in two clicks without reading docs."

---

## The two axes (do not collapse them)

The system already separates two orthogonal things. Keeping them separate is what makes everything else simple. **Optimisation = making the UI and APIs honour this split, not flatten it.**

| Axis | Question it answers | Where it lives | Values |
|---|---|---|---|
| **Viewer tier** | *What surfaces/nav do I see?* | `one.ie/web/src/lib/viewer.ts` — computed per-request, never stored | `owner · agency · client · end_user` |
| **Member role** | *What can I DO inside a group?* | `schema/one.tql` `membership.member-role` | `owner · admin · member · viewer · agent · auditor` |

> Viewer tier is **UI shell** (derived from session + workspace slug). Member role is **substrate permission** (stored in the `membership` relation, enforced by `requireAuth(action)`). The user's authority chain (owner→agency→client→user) is the **viewer-tier** story; the per-group `admin/member/viewer` is the **member-role** story. Both already exist.

---

## Current state — verified (2026-05-29)

### What is shipped and wired ✅

| Capability | Where | Notes |
|---|---|---|
| 6 member-roles, 30+ frozen actions, permission matrix | `one.ie/web/src/lib/role-check.ts` (PERMISSIONS, lines ~167-237) | `role-grant` matrix in TypeDB overrides hardcoded fallback |
| 4 viewer tiers, per-request | `one.ie/web/src/lib/viewer.ts` | `owner` via `staffRole`; `agency` via ownership or `manage_clients` capability |
| Group + recursive hierarchy | `schema/one.tql` `hierarchy` relation + `ancestors-of()` fn | every orphan group descends from `group:one` root (migration `0031_root_group.tql`) |
| Membership with role | `schema/one.tql` `membership` (relates group, member; owns member-role) | multiple `owner`s per group allowed (co-founders/agencies) |
| **Impersonation (act-as)** — full | `lib/act-as.ts`, `api/act-as/index.ts`, `api/act-as/end.ts`, `components/auth/ActAsConfirm.tsx`, `components/sidebar/ActAsBanner.tsx` | HMAC-signed cookie; allow-matrix (staff 8h / agency 4h / agency-client 2h); read-mode gate; no nesting; TypeDB `impersonation` audit relation |
| Scope isolation on reads | `scopeToGroup(viewer, baseClause)` wired across API routes | `plans/tenancy-todo.md` C1-C5 shipped; audit = 0 leaks |
| Capability grants (time-boxed, scoped) | `lib/capability-grant.ts` → D1 `capability` table + `role-cache.ts` | `grantCapability(grantee, actions, scope, from, to, granter)` |
| Invite-as-credential | `plans/invitations.md`; `api/invites/*` | single-use token writes membership; role-escalation gate enforced server-side |
| Auth bridge | `lib/api-auth.ts` `requireAuth(action)` → `Principal{user,slug,group,role,actions,bypass}` | Better Auth (D1) for *who*; TypeDB for *what-can-do* |

### Persona → mechanism map

| Persona (user's words) | Viewer tier | Typical member-role | Mechanism |
|---|---|---|---|
| **owner** (us / platform) | `owner` | `owner` of `group:one` | `staffRole=true` → authority cascades from root |
| **agency** | `agency` | `owner`/`admin` of their workspace group | `manage_clients` capability; parent of client groups via `hierarchy` |
| **client** | `client` | `owner`/`admin` of their own group (child of agency) | sub-group of agency; isolated by `scopeToGroup` |
| **user** (team member) | `end_user` / `client` | `member` / `viewer` / `agent` of a team sub-group | membership in the specific sub-group only |

**The mechanisms all exist.** The chain is real today.

---

## Deep analysis — verified findings (Sonnet, 2026-05-29)

A second-pass code read corrected three assumptions. **The headline flow is not as safe as the first pass claimed.** Build on these facts, not the optimistic version.

### Finding 1 — Scope isolation is NOT hard-enforced at TypeDB ⚠️ (the critical one)

`scopeToGroup` lives in `one.ie/web/src/lib/in/scope.ts` and *computes* a correct filter — but in the actual read routes the computed pattern is **thrown away**. Evidence:

- `api/export/actors.ts`, `api/export/people.ts`: the `scope` result is used **only** for the `kind === 'deny'` check. The real filter injected into the query is a **SQL comment** `/* scope:group:${groupSlug} */`. Enforcement is delegated entirely to the gateway parsing that comment. If the gateway ignores it → **zero** TypeDB-level isolation.
- `api/frontiers.ts`: queries hypotheses with **no scope filter at all** — every authenticated viewer sees the top 50 hypotheses across all tenants. It is an intended discovery feed, so the fix is **global+local** (confirmed 2026-05-29): show `scope:"public"` **OR** own-group hypotheses — NOT a blanket `scopeToGroup` (that would break global discovery). It leaks another tenant's *private/group* hypotheses today. Auth-gated (anonymous 403s via the `end_user` deny-check, despite a stale `// PUBLIC` comment) and returns `[]` when TypeDB is unconfigured — so not a panic, but C0's first fix.
- `schema/one.tql` has `ancestors-of()` but **no `descendants-of()`**. "Parent sees children" relies on a D1 query (`SELECT slug FROM owners WHERE parent_slug = ?`) that is **one level deep** — grandchildren are invisible to agency rollups.

**Verdict:** A marketing `viewer` is isolated from `sales` on D1-backed routes (the `group_id = ?` filter applies), but on **TypeDB-backed routes the isolation depends on the gateway honoring a comment**, and `/api/frontiers` leaks regardless. C6 is therefore not "extend a passing audit" — it must **harden the enforcement mechanism first**, then prove it.

### Finding 2 — `Principal.group` is a single group, set at login

`api-auth.ts`: `Principal.group.gid = session.user.activeGroupId ?? personalGroupOf(slug)`. There is **no union** across an actor's memberships. This actually *helps* sibling isolation (a marketing-scoped session sees only marketing), but means: switching which group you're "in" requires an **active-group switch**, and capability grants are read against `activeGroupId` only (see Finding 3). The 4-tier `Viewer` (owner/agency/client/end_user) is set in `middleware.ts` by **string equality** `slug === workspaceSlug` — *not* by group membership. Keep these two facts visible; they explain most "why can't I see X" surprises.

### Finding 3 — Act-as delegation already works, with one caveat

`grantCapability(adminUid, ["act_as"], agencyScope, …)` makes an agency admin pass **both** gates today — *provided the admin's `activeGroupId === agencyScope`*. `foldCapabilities` (`api-auth.ts:259-271`) reads capabilities against the single `activeGroupId`. If the admin is scoped to a different group, the grant isn't found. No-nesting guard is a hard `409` at handler entry. **C7 is mostly a UX surface + this active-group caveat**, not an architecture change — unless we want group-agnostic capability lookup (then change `foldCapabilities` to fold across the user's groups).

### Finding 4 — Most write paths compose cleanly; one is nearly free

- `api/groups/members.ts` is **GET-only** → `changeRole` + `removeMember` are net-new (no write surface to extend).
- `POST /api/groups` **already** accepts `parent_gid`, seeds owner membership atomically, **and** has an `invite_email` branch that creates group + parent edge + seeds admin + issues invite in one call. → **C4 may need no new endpoint** — it's a thin wrapper (or pure SDK sugar) over `POST /api/groups` with `{ parent_gid, invite_email }`.
- SDK `createGroup` just needs a `parent_gid?` param — the server already handles it. **Zero server change** (G6 is trivial).
- `changeRole` TypeQL = **delete + reinsert** (TypeDB 3.x has no UPDATE for owned attributes). Exact pattern exists in `schema/migrations/0029-tony-chairman-to-owner.tql`. Reuse it (swap `unit/uid` → `actor/aid`).
- `hasAuthorityOver` (the `ancestors-of` authority walk) is a **private fn in `api/groups/index.ts`** → extract to `lib/` so `changeRole`/`removeMember` reuse it verbatim, not reinvent.
- Escalation guard = `ROLE_ORDER` map + cross/same-workspace rules in `api/invites/create.ts`. Reuse for `changeRole`.

---

## Gaps — what makes it *not yet simple*

These are the optimisation targets. None require schema or role changes; they are wiring + UX + a couple of write-path endpoints.

### G1 — No "change role" write path
`role-check.ts` can *read* a role; there is no clean API/SDK method to *change* one. SDK has `inviteMember(gid, uid, role)` but no `changeRole(gid, uid, role)`. Owner/admin can't promote a member to admin or demote without a manual TypeDB write.
→ **Add `PUT /api/groups/members` + `SubstrateClient.changeRole()`**, gated by `change_role` action, with the same escalation guard invitations use.

### G2 — No revocation / membership-removal UI
Capability grants are revocable in code (`capability-grant.ts` soft-delete + cache invalidate) but there is no UI, and no `removeMember` flow. Operators can add but not cleanly remove.
→ **Add `DELETE /api/groups/members` + revoke-capability UI** in the members panel.

### G3 — "Add to marketing team, see only marketing" is not a one-action flow
Today this requires: create sub-group → set membership → trust that `scopeToGroup` filters reads. There is no single operator action ("Add Sarah to Marketing as viewer") and **no verification that a sub-group `viewer` truly sees only that sub-group's things**.
→ This is the **headline flow**. See worked example below. Needs: (a) team sub-group templates, (b) one add-member action that creates membership in the sub-group, (c) an audit test proving a marketing `viewer` cannot read sales/finance.

### G4 — Agency → client provisioning is multi-step
`oneie group bulk-create --csv` exists (tenancy C6) but the single-client "set up a new client" happy path (create child group + brand + seed admin + invite link) is not a one-call endpoint.
→ **Add `POST /api/clients` (agency-scoped)**: creates child group under agency, seeds a client-`owner`/`admin`, returns an invite credential. Wraps existing primitives.

### G5 — Impersonation can only be *started* by owner/agency; not delegated
Allow-matrix permits staff + agency + agency-client tiers, but an agency owner cannot grant "can act-as clients" to one of their own admins. The `act_as` action exists on the matrix but there's no delegation path below owner.
→ **Allow `grantCapability(adminUid, ["act_as"], agencyScope, ...)`** to surface in UI; allow-matrix already reads capabilities.

### G6 — `createGroup` (SDK) doesn't take `parent_gid`
Sub-group creation from the SDK is blind to hierarchy; the API route supports `parent_gid` (`api/groups/index.ts` `hasAuthorityOver`) but the SDK method doesn't pass it.
→ **Thread `parent_gid` through `SubstrateClient.createGroup()`.**

### G7 — No operator-facing "who can see what" view
There is no single screen that answers "for this group, who is a member, at what role, and what can they see?" — the data is all in `membership` + `role-grant` but unsurfaced.
→ **Members panel = the optimisation surface.** One table per group: actor · role · scope · last act-as. This is where G1/G2/G5 land.

---

## Navigation & group-switching — the Discord/enterprise model (verified 2026-05-29)

The ontology already expresses the Discord model with **two relations** — and more elegantly than Discord, which needs a separate per-channel permission-overwrite system. ONE doesn't: *what you see = what you're a member of*, and a channel is *a group with a parent*.

| Discord | ONE substrate | Status |
|---|---|---|
| Server (guild) | `group` (type `org`) | ✅ |
| Category / Channel | sub-`group` (type `team`), child via `hierarchy` | ✅ schema · ❌ no create-UI; `POST /api/groups` hardcodes `group-type "org"` |
| Role (per server) | `membership.member-role` | ✅ 6 roles, per-group |
| Channel visibility | membership-scoping in `api/groups/tree.ts` (`$me has aid` → only groups you're in) | ✅ **already correct** |
| Switch server | `components/sidebar/GroupSwitcher.tsx` (⌘G, 3-level popover) | ⚠️ navigates URL only |
| Server→channel tree | `GroupSwitcherTree.tsx` | ❌ built, **dead code** (unimported) |

**Enterprise shape, stated as ontology rules:**
- Org = `group` type `org`. Departments (Marketing/Sales/Service) = child `group`s type `team`. Sub-teams = children of departments — arbitrary depth via `hierarchy`.
- **Visibility = your memberships + their descendants.** Org-level member sees all departments (needs `descendants-of` — C0). Marketing-only member sees only Marketing (membership-scoping — already live in `tree.ts`).
- **Role is per-membership.** You can be `admin` of Marketing and `viewer` of the org. No global role.

### Verified surfaces

| Route | Gate | Data model | Status |
|---|---|---|---|
| `/u/[slug]/agencies` (+`/new`) | owner/agency | D1 `owners` where `parent_slug` + `plan='agency'` | ✅ wired |
| `/u/[slug]/clients` | owner/agency | TypeDB `hierarchy` descendants, `plan != 'agency'` | ✅ wired |
| `/u/[slug]/staff` | `staffRole` (else 404) | D1 `user` where `staff_role=1` (not a group/role — an auth flag) | ✅ wired |
| `/u/[slug]/people` | owner/agency | TypeDB `membership` (members) + D1 `agent_events` (visitors) | ✅ wired |
| `/in/[groupId]/*` | viewer-branched in island | generic group inbox/board/kanban | ✅ shell, island-driven |

### The four navigation gaps

### G8 — `activeGroupId` has no write path (the keystone bug)
The D1 `active_group_id` column exists and `requireAuth` reads it (`Principal.group = session.user.activeGroupId ?? personalGroupOf(slug)`), but **nothing writes it after login**. This creates a read/write context split:
- **Reads** scope by the **URL** (`/u/{slug}` → `workspaceContext.workspace`).
- **Writes** authorize by **`activeGroupId`** (frozen at login → personal group).

`GroupSwitcher` does `window.location = /u/{slug}` and never re-scopes. So "switch to Marketing" moves the URL (reads follow) but a *write* still resolves your role in your login group. Same root cause as C7's act-as caveat (capabilities fold against `activeGroupId`).
→ **`POST /api/groups/active` (or `settings?scope=active-group`)** writes `active_group_id`; `GroupSwitcher` calls it so read-context and write-context agree. **This is the most important gap — it makes "switch company › marketing" real.**

### G9 — No "create team sub-group" UI; API can't make a team
`CreateOrgDrawer`/`AgencyForm`/`NewClientDialog` all pass `parent_gid` correctly, but create `org`/`agency`/`client` — and `POST /api/groups` **hardcodes `group-type "org"`** regardless of the `type` field. Teams are only auto-provisioned by `enrollment.ts` (pro/agency/enterprise). No form to add a custom "Marketing".
→ **Create-team form** (passes `parent_gid` + `type:team`) + **API honours `group-type`** instead of hardcoding `org`.

### G10 — The group tree is dead code
`GroupSwitcherTree` (recursive parent→child, per-type icons, `MAX_DEPTH=3`) is built but unimported; the live switcher shows flat category buckets, not an org›department drill-down. `DivisionSwitcher` is also dead.
→ **Wire `GroupSwitcherTree` into `GroupSwitcher`** so switching drills org → Marketing/Sales/Service; delete `DivisionSwitcher`.

### G11 — `group-type` is decorative in the UI
Only an icon distinguishes `org`/`team`/`world`. No route or section branches on type.
→ Minor; fold into G10 (tree renders type-aware) — no separate cycle unless departments need distinct surfaces.

---

## Navigation & impersonation model — top × bottom (the elegant cut)

Two controls, two questions, one composition. The sidebar **top** answers *where
am I?* and the **bottom** answers *who am I?* — and the bottom always reflects the
top.

| | **Top — GroupSwitcher** | **Bottom — AuthButton act-as** |
|---|---|---|
| Question | *Where am I?* — which group/tenant | *Who am I?* — which user, inside this group |
| Action | switch group context (re-scopes auth, C8) | impersonate a member of the **current** group |
| Browse | your subtree: agencies → their clients → their teams, drill + search | the current group's members (bounded; search when large) |
| Scope | membership-scoped — you only ever see your own subtree | members of the active group; act-as gated (allow-matrix, time-boxed, audited, no nesting) |

**The coupling rule (the elegance):** the bottom list *is* the top's current
group. Switch the room (top) → the people in it change (bottom). One mental
model: pick the room, then pick whose eyes you look through.

### The journeys this serves

1. **Agency onboards a client, then "views the agency as the client."** Provision
   the client in one call (C4) → **switch** into the client group (top → C8
   re-scopes reads *and* writes) → the **bottom** now lists the client's staff →
   **act-as** the client owner → you now see exactly the client's surfaces.
   Switching gives you the client's *context with your authority*; act-as makes
   you *see precisely what they see* — use act-as to verify/support, switch to
   manage.

2. **Owner checks a marketing viewer can't see support.** Switch to the marketing
   group (top) → the bottom shows marketing's people → act-as a marketing
   `viewer` → navigate: support is absent. This is the **human face of C0/C6** —
   the database enforces the isolation and a test proves it for CI; act-as lets a
   person *witness* it. **Verification > presence.**

### Why we need it

- **Trust by witnessing, not asserting.** Isolation is enforced at TypeDB (C0)
  and proven by the audit (C6); act-as lets an operator see it with their own
  eyes. The test reassures CI; act-as reassures the human.
- **Support.** Agencies fix client problems by walking in as them.
- **Onboarding QA.** Set up a client, walk in as them, confirm before handover.
- **Safety by physics.** Act-as is time-boxed, single-group-scoped, read-default,
  audited, non-nesting — "become someone" is a supervised session, never a
  privilege grant.

### Scale — small and large, same model

- **Small:** top is a short drill (you + a few agencies + their clients); bottom
  is a handful of users. No search needed.
- **Large (100s of clients):** top drills level-by-level with per-level search
  (agency → search its clients), loading only your subtree lazily — never a flat
  list of the world. Bottom stays bounded to the current group's members + search.

### The gap to close (what makes it real)

1. **Bottom = current group's members.** Today `AuthButton` fetches
   `/api/export/actors` bare. Scope it to the active group so "in a group → its
   users at the bottom" is literally true and follows every switch.
2. **Top = parent→child drill + search**, re-scoping on select (C8, wired). A
   true hierarchy drill (agencies → clients → teams) so the browse path matches
   the authority chain.
3. Both already ride the enforcement: C8 makes writes follow the switch; C0
   guarantees the impersonated marketing viewer truly cannot see support.

## The simplest target model

One sentence per layer. If a proposed feature doesn't fit one of these sentences, it's scope creep.

1. **A group is a tenant.** An actor can only act where it is a member (`plans/groups.md` §1). Sub-groups (e.g. "Marketing") are children via `hierarchy`.
2. **Membership carries exactly one role.** `owner/admin/member/viewer/agent/auditor` — the role decides the action set via the matrix. No per-feature flags.
3. **Visibility = your group + its descendants, never its siblings.** A `viewer` of `group:acme/marketing` sees marketing things; they cannot see `group:acme/sales`. Enforced by `scopeToGroup`, proven by audit.
4. **Authority flows down the hierarchy.** owner (root) → agency (parent) → client (child) → team (grandchild). An actor with authority over an ancestor has authority over descendants (`ancestors-of`).
5. **Act-as is the only "become someone else."** Time-boxed, scoped to one group, read-mode by default, always audited. No nesting.
6. **Capabilities are the only exception to roles.** A scoped, expiring grant of specific actions. Everything else is role + membership.

Six sentences. Everything in the system should reduce to these.

---

## Worked example — the headline flow

> *"A client adds someone to the marketing team and they can only see marketing-related things."*

**Setup (already possible):**
- Agency `acme-agency` (group, viewer-tier `agency`) is parent of client `acme` (group, child via `hierarchy`).
- Client `acme` has sub-groups: `acme/marketing`, `acme/sales`, `acme/finance`.

**The flow we want to make one action:**
1. Client admin opens the **Marketing** team members panel.
2. Clicks "Add member", enters `sarah@acme.com`, picks role **viewer**.
3. System: creates `sarah` actor (if new) → writes `membership(group: acme/marketing, member: sarah, member-role: viewer)` → issues invite credential.
4. Sarah signs in. Her `Principal.group = acme/marketing`. Every read is `scopeToGroup`'d to that group + descendants.
5. **She sees marketing signals/things. She cannot see `acme/sales` or `acme/finance`** — they are siblings, not descendants.

**What we must prove (W4 audit gate):** a `viewer` of `acme/marketing`, across every read route, returns **0 rows** from sibling sub-groups — **enforced at TypeDB, not via a gateway comment**.

**What's missing today (corrected by deep analysis):**
- **Enforcement itself (C0).** Isolation holds on D1-backed routes but on TypeDB-backed export routes it relies on the gateway honoring a `/* scope */` comment, and `/api/frontiers` leaks across groups entirely. This must be hardened before the flow is safe.
- Steps 2-3 as a single operator action (C1/C5).
- The sibling-isolation audit case (C6).

---

## Proposed work (todo sketch)

Expanded into `plans/roles-optimisation-todo.md` from `plans/template-todo.md`. Each cycle composes existing primitives — **construct only where recon proves no reuse.**

Order changed after deep analysis: **scope-hardening (C0) comes first** — it's a live leak and the headline flow's safety depends on it. The cheap wins (C1/C5/C6) land next; act-as delegation (C7) is mostly UX.

| Cycle | Deliverable | Composes | Demo gate |
|---|---|---|---|
| **C0** ⚠️ | **Harden scope enforcement** — embed `scope.pattern` (TypeQL) into the actual `match` clauses in `export/actors.ts`, `export/people.ts`; add a group filter to `api/frontiers.ts`; add `descendants-of()` to `schema/one.tql` | `lib/in/scope.ts` (already returns the pattern — just *use* it), `ancestors-of` mirror | `frontiers` returns 0 cross-group rows; export routes filter at TypeDB, not via comment |
| **C1** | Members panel — one table per group (actor · friendly role · scope); add-member form + inline role picker (default Viewer) | `api/groups/members.ts` (GET exists), `role-check.ts`, new `lib/role-labels.ts` | panel renders members with friendly labels; add form defaults to Viewer |
| **C2** | `changeRole` write path (API + SDK), wired to inline picker | delete+reinsert TypeQL (pattern from migration `0029`), `hasAuthorityOver` extracted to `lib/`, `ROLE_ORDER` escalation guard | change role inline; promote/demote works; escalation (raise ≥ own rank) blocked |
| **C3** | `removeMember` + revoke-capability (API + UI) | `capability-grant.ts` soft-delete; new DELETE on `members.ts` | remove member; revoked capability denies action within 60s cache TTL |
| **C4** (small) | Agency provisions client in one call — thin wrapper or SDK sugar over `POST /api/groups` `{ parent_gid, invite_email }` (no new endpoint expected) | existing `POST /api/groups` invite_email branch | one call → child group + parent edge + seeded admin + invite link |
| **C5** (small) | Team sub-group + headline flow (G3); thread `parent_gid` through SDK `createGroup` (zero server change) | `hierarchy`, `membership`, `POST /api/groups` | add viewer to `acme/marketing` in one action |
| **C6** | **Sibling-isolation audit** (the proof) — depends on C0 | extend `tenancy` audit matrix to sub-group siblings | marketing `viewer` reads 0 rows from sales/finance across **every** route, TypeDB-enforced |
| **C7** (UX) | Act-as delegation below owner (G5) — surface `grantCapability(…, ["act_as"], agencyScope)` in UI; document the active-group caveat (admin must be scoped to `agencyScope`) | existing allow-matrix + `foldCapabilities` (works as-is) | agency admin (granted, in agency scope) can act-as a client; ungranted admin gets 403; no nesting |
| **C8** ⚠️ | **Active-group switch** (G8) — `POST /api/groups/active` writes `active_group_id`; `GroupSwitcher` calls it so switching re-scopes auth, not just the URL; reconcile read(URL)/write(activeGroupId) | `GroupSwitcher.tsx`, `api-auth.ts`, D1 `active_group_id` (exists) | switching to Marketing sets activeGroupId; a write then authorizes in Marketing, not the login group |
| **C9** | **Create team sub-group** (G9) — create-team form (`parent_gid` + `type:team`); `POST /api/groups` honours `group-type` instead of hardcoding `org` | `CreateOrgDrawer.tsx`, `POST /api/groups` | operator adds "Marketing" under the org in one action; it renders as a `team` |
| **C10** | **Wire the group tree** (G10/G11) — activate `GroupSwitcherTree` in `GroupSwitcher` (org›dept drill-down, type-aware icons); delete dead `DivisionSwitcher` | `GroupSwitcherTree.tsx` (built), `/api/groups/tree` (returns parent_gid) | switcher shows org → Marketing/Sales/Service as a tree; net LOC negative |

**C0 is the new critical gate** — it's a live cross-tenant leak (`/api/frontiers`) and without it C6 cannot pass honestly. C1 is the operator surface the write cycles hang off. Nothing in C5/C6 ships if a sub-group viewer can see a sibling.

---

## Threat model (per motif — what it defends, what it accepts)

| Surface | Defends | Accepts |
|---|---|---|
| Member role | action set per group via matrix; owner actions audited before commit (fail-closed) | a compromised `owner` session within one group (mitigated by audit, not prevented) |
| Sub-group visibility | siblings cannot read each other — **once C0 embeds the filter at TypeDB** (today it leans on a gateway comment; `/api/frontiers` leaks); proven by C6 audit | a parent/ancestor admin *can* read descendants — intended authority flow |
| Act-as | time-box, single-scope, read-default, no nesting, full audit relation | the real human is trusted; act-as is not a privilege grant, it's a supervised session |
| Role escalation | same-workspace owner-grant blocked; cross-workspace only if child-of-inviter | an owner can always escalate within their own group — that's what owner means |
| Capability grant | scoped + expiring; revocable with cache invalidation | up to 60s stale window on revoke (role-cache TTL) |

---

## Decisions (locked 2026-05-29)

1. **Friendly labels.** Client-facing UI shows friendly names mapped 1:1 to the locked substrate roles; owner/agency tooling may show raw names. The substrate value never changes.

   | Substrate role | Client-facing label |
   |---|---|
   | `owner` | Owner |
   | `admin` | Admin |
   | `member` | Editor |
   | `viewer` | Viewer |
   | `agent` | Agent |
   | `auditor` | Auditor |

   Label map lives in one place (`one.ie/web/src/lib/role-labels.ts`, new) — single import, no scattered strings.

2. **Default `viewer`, but role is in the add-member form.** When adding a teammate the role defaults to **Viewer**, and the add form carries a role picker so the operator can pick any role at add time — and **change it inline later** from the same members panel (C1 + C2). Changing a role is a one-control action, not a separate flow.

3. **Act-as delegation ships (C7).** Confirmed important — an agency owner can grant `act_as` (scoped, expiring) to one of their admins so the admin can support clients without being a full owner. Allow-matrix already reads capabilities; C7 surfaces the grant + the delegated start path.

---

## Non-goals

- No new roles, no renamed roles, no new dimensions or verbs (locked).
- No rearchitecting of auth, sessions, or the viewer/role split.
- No calendar-time planning — cycles and waves only.

---

*The substrate already knows how to do all of this. This plan is the thin operator skin that lets a human do it in two clicks — and the audit that proves the marketing viewer never sees sales.*
