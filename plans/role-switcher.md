# role-switcher.md — Top-Left Group Switcher

**Where:** `Sidebar.tsx` header (top-left, replaces / wraps the profile logo block).
**What:** one control that lets an actor pivot between every group they are a member of, with permission and visibility derived entirely from existing `membership` + `hierarchy` + `member-role` + `group.plan`. No new schema. The switcher is a *lens* over dimension 1 (Groups), not a new dimension.

> The substrate already knows who can see whom. The switcher is the UI projection of `membership ∩ hierarchy-closure ∩ visibility`. We are not adding ACLs — we are rendering the ones already written.

**Contract with `roles.md`:** every behavior in this doc is the runtime manifestation of a rule already locked in `roles.md`. The switcher is not allowed to invent a 5th tier, a 7th cascade layer, or a new locked-property semantic. If a behavior here disagrees with `roles.md`, `roles.md` wins and this doc is patched. See §A at the bottom for the explicit verification matrix.

---

## 1. The mental model

Every signed-in actor lives in a forest of memberships. The switcher exposes that forest, scoped to what they can see.

```
┌─ Personal (always 1, frozen, private)
│    group:tony            role: chairman
│    └── sub-groups (writing, family, ...)
│
├─ Orgs (0..n — joined via invite or self-created)
│    acme (org, plan: agency)
│      ├── acme-marketing  (team)         ← auto-added on signup if plan includes it
│      ├── acme-sales      (team)
│      ├── acme-service    (team)
│      └── acme-community  (team)
│
├─ Clients (agency-plan only — children of an org you own/admin)
│    acme/startup-1  (org, parent=acme)
│      └── teams (marketing/sales/service/community)
│    acme/startup-2  (org, parent=acme)
│
├─ Worlds (public; e.g. group:one) — opt-in
└─ Communities / DAOs — opt-in
```

The switcher **always shows the personal group at the top**, then orgs the actor belongs to, then a "Clients" pane (visible only if the active org has `plan: agency` and the actor's `member-role` ∈ `{owner, admin}`), then worlds/communities.

### 1a. Coverage of the five `roles.md §3` patterns

Every pattern below must render correctly out of the same `/api/groups/tree` payload — no per-pattern UI branching.

| Pattern (roles.md §3) | What the switcher shows | Tier on switch |
|---|---|---|
| **A — Solo** | Personal only (`group:alice`). If `alice` is also the workspace, she is `chairman` there. No org row, no Clients pane. | `agency` (in her own workspace) / `chairman` (in personal) |
| **B — Agency** | Personal + the agency org (`acme`) with 4 sub-teams + **Clients pane** with `startup-1`, `startup-2`, …. Each client is a child `group-type: org` with its own 4 sub-teams. | `agency` in `acme` and in each client (via `manage_clients`); `chairman` in personal |
| **C — Team** | Personal + `bigco` org + `bigco-marketing`, `bigco-engineering`, `bigco-support` as `group-type: team` children. No Clients pane unless plan includes agency. | `agency` if owner/admin of `bigco`, else `client` per team |
| **D — Enterprise** | Personal + `enterprise` org + division sub-workspaces (`eu-ops`, `us-ops` — `group-type: org`, parent=enterprise) each with their own brand/domain badge + their own 4 sub-teams. Switching to a division applies that division's `WorkspaceConfig` (own brand tokens, own domain). | `owner` in `enterprise`, `agency` in each division they admin, `client` in divisions where they are members |
| **E — Network** | Each independent agency appears as a separate top-level org. Hierarchy queries are rooted per-agency → siblings cannot see siblings' clients (enforced by `hierarchy*(parent: my-org, …)` in §7). Shared world-level catalog (`group:one`) appears once under Public. | Per-agency; no cross-agency leakage |

The Enterprise case is the load-bearing test — it proves the switcher handles the full cascade depth (`world → enterprise → division → team`) and the per-node brand/domain swap.

---

## 2. Signup → membership matrix

Sign-up writes the minimum that gives a coherent first switcher render. Plan-driven sub-team enrollment runs the same instant the actor joins an org (either at signup-with-invite, or later on `/api/groups/join` / `/api/invites/accept`).

| Event | Writes |
|---|---|
| `POST /api/auth/agent` (any signup) | `actor` + `group:{uid}` (personal, private) + `membership(group:{uid}, member:{uid}, role:chairman)` |
| Joins org with `plan: starter` | `membership(org, uid, role: member)` only |
| Joins org with `plan: growth` | + `membership(org-marketing, uid, role: member)` + `membership(org-sales, uid, role: member)` |
| Joins org with `plan: scale` | growth + `membership(org-service, uid, role: member)` + `membership(org-community, uid, role: member)` |
| Joins org with `plan: agency` | scale + grants `manage_clients` capability (see §6) |
| Invited with explicit roles | Invite token carries `roles: ["marketing:admin", "sales:member"]` → those memberships written, plan defaults skipped |

The four canonical sub-teams (marketing, sales, service, community) map 1:1 to `org-chart.md` pods. They are created as `group-type: team` children of the org via `hierarchy(parent: org, child: team)` the moment the org is provisioned — not lazily on first invite. That keeps the switcher tree stable.

**Frozen rule:** plan upgrades are additive at the membership layer. Downgrade does **not** silently strip memberships — it marks them `role: viewer` (read-only) so the actor retains audit visibility. Re-upgrade restores prior roles from the audit row.

---

## 3. UI shape (top-left)

```
┌──────────────────────────────┐
│ [LOGO] Acme ▾                │  ← active group; arrow opens switcher popover
└──────────────────────────────┘
   │
   ▼ (Popover, max-h-[80vh], scrollable, search at top)
┌──────────────────────────────────────────┐
│ 🔍 Filter groups…                        │
├──────────────────────────────────────────┤
│ ● group:tony   chairman      (personal)  │
├──────────────────────────────────────────┤
│ ACME (org · agency plan)                 │
│   ├── ● acme            admin            │  ← clicking sets active = acme
│   ├──   marketing       member           │
│   ├──   sales           member           │
│   ├──   service         viewer           │
│   └──   community       member           │
├──────────────────────────────────────────┤
│ ▾ Clients (12)            [+ Add client] │  ← only if active=acme & role∈{owner,admin}
│   ├──   startup-1        agency (in-acme)│
│   │     ├── marketing    member          │  ← agency staff cross-mounted
│   │     └── sales        member          │
│   ├──   startup-2        agency (in-acme)│
│   └── … (paginated)                      │
├──────────────────────────────────────────┤
│ Public                                   │
│   ●   group:one          member          │
├──────────────────────────────────────────┤
│ [+ Create org]    [+ Join via invite]    │
└──────────────────────────────────────────┘
```

- Active group rendered with a filled dot; the surface logo + brand tokens cascade from it (existing `resolveConfig()` in middleware — see `roles.md §11`).
- Switching navigates to `/u/<gid>/<currentRoute>` (preserving the route segment after `/u/<slug>/`); middleware recomputes `ctx.locals.workspaceContext` server-side. No client-side trust, no `?slug=` query param (slug is path-resident per `roles.md §11`).
- Indent depth follows `hierarchy(parent, child)`; max 3 levels in the popover (deeper teams reachable from Settings → Teams).
- Each row shows a **domain badge** when the group has a custom domain set (e.g. `acme.com`, `eu.enterprise.com` per `roles.md §10 Identity → domain`). Clicking the badge opens the workspace on its own domain in a new tab instead of switching in-place — required for Pattern D where divisions live under different hostnames.
- Each row shows a **brand swatch** (`primary` token) so locked-cascade colors (`roles.md §9`) are visible at-a-glance before the switch happens. Hovering a row pre-resolves the config in a tooltip ("Brand: ACME green, locked by acme").
- L4 user prefs from `roles.md §10 [L4]` (`theme`, `sidebar-pinned`, `chat-mode`) live in `localStorage` and **persist across switches** — switching changes Layers 1–3 only. The user never has to re-pin their sidebar after pivoting.

---

## 4. Component file plan

```
one.ie/web/src/components/sidebar/
  GroupSwitcher.tsx          ← new — popover trigger, tree, search, "Create"/"Join"
  GroupSwitcherTree.tsx      ← new — recursive renderer with role chips
  ClientsPane.tsx            ← new — agency-plan-only sub-pane; lazy-loads when expanded
  Sidebar.tsx                ← edit — hosts <GroupSwitcher /> as the header element
```

API surface used (all already live per `groups.md §10 — API Surface ✓ Live`):

| Need | Endpoint |
|---|---|
| List my memberships + roles + group tree | `GET /api/groups` (returns rows with `role`, `group-type`, `parent_gid`) |
| List clients of active org | `GET /api/groups?parent=<gid>&group-type=org` (server filters by `manage_clients` cap) |
| Switch active group | `GET /u/<gid>/dashboard` (server reads slug, rebuilds config) |
| Create new org / client | `POST /api/groups` (existing) |
| Join via invite | `POST /api/invites/accept` (existing) |

One new convenience endpoint is worth adding to avoid a fan-out on every render:

- **`GET /api/groups/tree`** — returns the entire forest the calling actor can see, in one TypeQL fetch, shaped as `{ nodes: [{gid, name, type, role, parent_gid, plan, badges[]}] }`. Cached per session in KV (60 s TTL) — invalidated by any `/api/groups*`, `/api/invites/accept`, `/api/groups/:gid/role` write.

---

## 5. Permission cascade — the rule, not a table

The switcher does not *check* permissions; it *displays the result* of one query the substrate already supports. The rule (locked):

```
visible(actor a, group g) ≡
     membership(g, a)                                                 # direct
  ∨ (hierarchy*(parent: g, child: any)  ∧  membership(child, a))      # see ancestor of any group I'm in
  ∨ (g.visibility = "public")                                         # discoverable
  ∨ (capability(a, "manage_clients") ∧ hierarchy*(parent: a.org, child: g))  # agency-staff sees client orgs
```

`role` at the rendered node is `MAX(membership.member-role)` over the actor's direct memberships in `g` *and* in any ancestor of `g`, with the partial order `viewer < member < auditor < agent < admin < owner` (matches `one.tql:270` and `roles.md §3`). Cascade direction: **downward only** — an `admin` of `acme` is an effective `admin` in `acme-marketing` unless an explicit lower role is written on that child membership (the explicit row wins, lower or higher).

Three concrete cascade examples:

| Actor | Membership rows | Effective in `acme-marketing` |
|---|---|---|
| Tony (platform owner) | `membership(group:one, tony, owner)` + `staffRole=true` | `owner` (platform tier overrides) |
| Alice (acme admin) | `membership(acme, alice, admin)` | `admin` (inherits down via hierarchy) |
| Bob (acme marketer) | `membership(acme-marketing, bob, member)` | `member` |
| Carol (acme service lead) | `membership(acme, carol, member)` + `membership(acme-service, carol, admin)` | `member` in marketing (no override), `admin` in service |
| Dana (client of acme) | `membership(acme/startup-1, dana, owner)` | not visible — different sub-tree |

All four ABAC/RBAC/ReBAC layers in `groups.md §Security` still run on every action — the switcher just changes which `g` becomes the implicit scope for subsequent signals.

---

## 6. Agency plan — the client lens

`plan: agency` on an org grants a single non-schema capability: `manage_clients`. Implementation:

- A capability row: `(provider: org, offered: thing("manage_clients"))`
- A role grant per actor: `role-grant(actor, group: org, governance-role: admin|owner, role-action: "manage_clients")` — already supported by `entity role-grant` (`one.tql:190`).

Effects:

| Surface | Behavior when `manage_clients` is granted to active actor in active org |
|---|---|
| Switcher | "Clients" pane appears under the active org. Lists children where `group-type=org` AND `hierarchy.parent = active-org`. |
| `/api/groups` POST | Allows creating a child org under the active org (`parent_gid` defaults to active). New client org is auto-provisioned with the 4 sub-teams. |
| `/api/groups/:client/invite` | Allowed — the agency can invite end-users into a client org without being a chairman of that client. |
| Switching INTO a client | Same as switching into any org, but viewer tier resolves to `agency` (per `roles.md §2`, `ownerSlug === workspaceSlug`-style check is replaced by `manage_clients ∧ hierarchy*(parent: active-org-of-session, child: switched-into-org)`). |
| Switching OUT of agency context | Returns to the agency org (or personal if no agency org is active). |

End-user visibility (clients of clients of clients) is bounded: an agency can only see one hierarchy level of clients by default. Multi-level reseller chains require explicit cascade — set on the parent org by an `owner`-role action (`PATCH /api/groups/:gid { cascade_clients: true }`). Default is `false` to keep the ReBAC blast radius small.

---

## 7. Switcher data flow

```
mount Sidebar
  │
  ▼
GroupSwitcher fetches /api/groups/tree
  → server runs:
       match
         (group: $g, member: $me) isa membership, has role $r;
         $me has aid <session.uid>;
         { (parent: $p, child: $g) isa hierarchy; } or { not { (parent: $_, child: $g); }; };
       fetch $g.gid, $g.name, $g.group-type, $g.plan, $g.visibility, $r, $p.gid;
  → plus the "agency lens" query (only if session has `manage_clients`):
       match
         $me has aid <uid>;
         (provider: $org, offered: $cap) isa capability;
         $cap has name "manage_clients";
         (group: $org, member: $me) isa membership;
         (parent: $org, child: $client) isa hierarchy;
         $client has group-type "org";
       fetch $client.gid, $client.name, $client.plan;
  │
  ▼
client renders tree (sorted: personal → orgs by recency → clients → public)
  │
  ▼
user clicks group
  → router.push(`/u/${gid}/dashboard`)
  → middleware re-resolves viewer tier + workspaceConfig
  → Layout.astro receives new cascade
```

Two writes that invalidate the KV cache: any `/api/groups*` mutation, and `/api/invites/accept`. Cache key = `tree:<uid>`.

---

## 8. The 4-tier viewer still rules — switcher just changes the *active group*

The switcher does **not** change the actor's tier. Tier is per-(actor, group) and is recomputed on switch:

```
viewer = resolveViewer({
  staffRole: session.staffRole,
  actorUid:  session.uid,
  activeGid: <switched-to gid>,
})

  → staffRole               → 'owner'      (platform)
  → ownerSlug = activeGid   → 'agency'     (running their own workspace)
  → manage_clients ∧ active is client of mine → 'agency'  (acting on behalf of client)
  → membership(activeGid)   → 'client'
  → none                    → 'end_user'
```

This is the same `viewer.ts` resolver already in `src/lib/viewer.ts` (per roles-todo.md item `viewer ✓`) — extended only to consult the `manage_clients` capability when computing `agency` tier across hierarchy.

### 8a. Nav matrix per tier — what each switched-into context actually shows

The switcher does not redraw the sidebar nav itself; it just changes `viewer` + `gid`, and `getUserMenu(slug, viewer, …)` (already shipped, roles-todo `menu ✓`) re-filters. The contract — locked by `roles.md §6` — is reproduced here so the e2e in S11 can assert against a single table:

| Route | owner | agency | client | end_user |
|---|:-:|:-:|:-:|:-:|
| `@slug` (profile) | ✓ | ✓ | ✓ | ✓ |
| `/chat` | ✓ | ✓ | ✓ | ✓ |
| `/dashboard` | ✓ | ✓ | ✓ | — |
| `/agents` | ✓ | ✓ | ✓ | — |
| `/skills` | ✓ | ✓ | — | — |
| `/tools` | ✓ | ✓ | ✓ | — |
| `/payments` | ✓ | ✓ | — | — |
| `/settings` | ✓ | ✓ | ✓ | — |
| `/design` | ✓ | ✓ (own ws only) | — | — |

Switcher-specific cases: end_user landing on `/u/<slug>/agents` after a switch attempt is redirected to `/u/<slug>/chat` per `roles.md §6` note. The redirect happens in middleware **before** the page renders so the flash is never visible.

### 8b. Surface matrix on switch — `roles.md §7` deltas the switcher must honor

When the active group flips, every surface re-resolves from `WorkspaceConfig`. The switcher does not bypass any locked property:

- **Chrome** — logo/tokens/font/favicon resolved from the new group's cascade; locked at any layer freezes downward (`roles.md §9`).
- **Chat** — welcome / placeholder / agent persona / starter chips come from the new group's `chat.*` block. Voice + attachments toggle per `roles.md §7 Chat`.
- **Agents** — `agents.visible` filter applies; "Create" CTA hidden for `client` tier even if the actor had it visible in the previous group.
- **Skills** — entire surface hidden from `client` tier per `roles.md §7 Skills` (matches §8a nav).
- **Payments** — revenue dashboard shows own-workspace scope only for `agency`, own-billing only for `client`.
- **Design** — `/design` accessible only at `owner` / `agency` tier in their own workspace; switching into a client org as an agency-staffer **does** open `/design` for that client (one of agency's selling points).

---

## 9. Schema diff — one new relation

Every primitive for **the switcher itself** is already in `schema/one.tql` (zero changes). **Act As** (§B1) adds exactly one relation — it is the only schema delta in this whole plan.

**Already present:**

- `group`, `group-type`, `plan`, `visibility` — `one.tql:17-23, 285`
- `membership` + `member-role` — `one.tql:162-165, 270`
- `hierarchy(parent, child)` — `group plays hierarchy:parent/child` (line 27)
- `capability(provider, offered)` — pre-existing
- `role-grant` with `expires-at` — `one.tql:190` (re-used for time-bounded grants in §B11)
- `actor.owner` for personal-group ownership — `one.tql:73`
- `signal` — re-used for `verb ∈ {join, leave, role-change, act-as-start, act-as-end}` audit (§B14)

**New (added by S13):**

```tql
relation impersonation,
    relates actor    @card(1),         # the human actually logged in
    relates as       @card(1),         # the actor being acted-as
    relates scope    @card(1),         # group the act-as is bounded to
    owns started-at,
    owns expires-at,                   # default 1h, hard max 8h
    owns reason,                       # required, audited
    owns mode;                         # "read" | "write"
```

No D1 migrations needed for the switcher. KV holds the per-uid tree snapshot (`MEMORY.md → project_data_layers`). Act-As session cookie is signed/verified in-process, no DB row needed (the `impersonation` relation is the audit row).

---

## 10. Build sequence (S1–S28, batched by data deps)

Each item is a self-contained `/do` cycle. Sequence respects only file/data dependencies — see `role-switcher-todo.md` for the full batched DAG and W1–W4 breakdown per cycle.

| # | Item | Model | Deps |
|---|---|---|---|
| **S1** | `GET /api/groups/tree` endpoint + TypeQL queries + KV cache | sonnet | — |
| **S2** | `GroupSwitcher.tsx` (popover shell, search, role chips, active dot, brand swatch, domain badge) | sonnet | S1 |
| **S3** | `GroupSwitcherTree.tsx` recursive renderer with hierarchy indent | sonnet | S2 |
| **S4** | Wire into `Sidebar.tsx` header — replace static profile block when `viewer ≠ end_user` | haiku | S3 |
| **S5** | Plan → sub-team auto-enrollment in `/api/groups/join` + `/api/invites/accept` (4 canonical teams) | sonnet | S1 |
| **S6** | `manage_clients` capability grant on `plan: agency` org provisioning | sonnet | S5 |
| **S7** | `ClientsPane.tsx` (lazy-load, agency-lens query, "+ Add client" → POST `/api/groups` with `parent_gid`) | sonnet | S6 |
| **S8** | `resolveViewer()` extended — `agency` tier via `manage_clients ∧ hierarchy*`; per-active-group, not per-session | opus | S6 |
| **S9** | Multi-level cascade flag (`cascade_clients` on group) — `PATCH /api/groups/:gid` accepts + `/tree` honors | sonnet | S7 |
| **S10** | Downgrade-safety: `member-role` demote-to-viewer on plan reduction, audit row written | sonnet | S5 |
| **S11** | Playwright e2e: switcher across all 5 `roles.md §3` patterns (Solo/Agency/Team/Enterprise/Network) | sonnet | S1–S9 |
| **S12** | Docs sync: `groups.md §Sign-Up`, `roles.md §6/§14`, `org-chart.md §10` row "Who sees what?" → point here | haiku | S11 |
| **S13** | `relation impersonation` added to `schema/one.tql` + TypeDB migration script | haiku | — |
| **S14** | `POST /api/act-as` + `POST /api/act-as/end` + signed `session-act-as` cookie + allow-matrix enforcement | opus | S13 |
| **S15** | Global non-dismissible Act-As red banner in `Layout.astro` + signal audit writer | sonnet | S14 |
| **S16** | `/u/<gid>/members` roster surface — list, search, role chips, `…` menu with Act As | sonnet | S14 |
| **S17** | `/u/<gid>/members?view=clients` aggregation across client sub-orgs (agency tier) | sonnet | S16 |
| **S18** | Default-landing per tier (`/dashboard` / `/u/.../dashboard` / `/u/.../chat`) + `KV: session:last-group` | haiku | S1 |
| **S19** | Removed-while-active fallback in middleware → redirect to personal + toast | haiku | S1 |
| **S20** | Pending-invites pane + switcher header badge from `/api/invites` | sonnet | S1 |
| **S21** | Pinned + Recent groups (drag-pin, `KV: pins:<uid>`, last-5 recency under Personal) | sonnet | S1 |
| **S22** | ⌘G keyboard shortcut + a11y (focus trap, arrow nav, Esc close) | haiku | S2 |
| **S23** | Per-group inbox counts — `/api/inbox/counts` aggregation + KV 15s TTL | sonnet | S1 |
| **S24** | Time-bounded `role-grant` sweeper in `sync/` worker (cron) | haiku | S6 |
| **S25** | `/u/<gid>/audit` surface — membership/role/switch/act-as events from `signal` relation | sonnet | S15 |
| **S26** | Mobile bottom-sheet variant of `GroupSwitcher` (per `roles.md §6`) | sonnet | S2 |
| **S27** | End-user → client upgrade pulse on `/api/invites/accept` (toast + switcher pulse) | haiku | S20 |
| **S28** | Playwright e2e: Act-As across every row of the allow-matrix (B1) + audit visibility from target side | sonnet | S14–S17, S25 |

---

## 10a. Cascade integration — switching is a Layer 1–3 swap

`roles.md §4` and `groups.md §4` define a 6-layer cascade:

```
L0 platform defaults  ← never touched by switcher
L1 parent workspace   ← changes when active group is in a different parent
L2 workspace          ← always changes on switch
L3 team / sub-group   ← changes if switching into a team-level node
L4 client override    ← changes if switching into a client sub-workspace
L5 localStorage       ← never touched by switcher (user prefs persist)
```

`resolveConfig({ slug, viewerSlug, groupId, env })` (per `roles.md §11`) is called by middleware on every navigation. The switcher's only job is to set `slug` + `groupId` correctly so the merge re-runs. Three rules the switcher must obey:

1. **Locked-property propagation is the merge function's job, not the switcher's.** Switcher never tries to "preview" an unlocked override — it shows the swatch from the resolved value at the destination group. Locks set with the `-locked` suffix (`roles.md §9`) freeze downward regardless of which group you switch to.
2. **A layer can only lock properties it has set** (`roles.md §9`). The switcher must therefore reject any "Create client" form submission that attempts to lock a property the actor's tier did not set — server-side check in `POST /api/groups` (already enforced; switcher just hides the lock UI from `client` tier).
3. **Re-resolving on switch is server-authoritative.** The client-side switcher does **not** memoize `WorkspaceConfig` across switches — the middleware response is the only truth. KV cache (§4) is for the *tree shape*, not the resolved config.

---

## 11. Invariants (verified in S11)

| Invariant | Where enforced |
|---|---|
| Personal group always first in switcher, never removable | `GroupSwitcher.tsx` sort + `/api/groups/leave` guard |
| Switching to a group I am not a member of is impossible | server-side slug check in middleware — switcher only shows allowed gids, attempt to URL-hack returns 403 |
| Plan downgrade preserves audit trail | `audit_row(uid, prev_role, new_role: "viewer", reason: "plan_downgrade")` |
| Agency cannot see sibling agencies' clients | `/tree` agency-lens query is `hierarchy*(parent: my-org, ...)` — siblings have a different parent |
| Personal group never appears in any other actor's switcher | `visibility: private` + chairman-only membership; `/tree` query filters `group-type: personal` to `member = me` |
| Switching does not leak signals — `scope: private` still per-group | unchanged; switcher only changes `ctx.locals.workspaceContext.gid` |
| Cache invalidation: `/tree` KV row dropped on every membership write | `invalidateTreeCache(uid)` in `/api/groups`, `/api/invites/accept`, `/api/groups/:gid/role` handlers |
| Pattern E isolation: agency A cannot see agency B's clients | `/tree` agency-lens query is `hierarchy*(parent: my-org, …)` — sibling roots are unreachable |
| Locked properties survive any switch — `client` tier cannot override locked agency tokens | merge in `parseSite()` honors `-locked` regardless of destination (`roles.md §9`) |
| `/design` access flips correctly per tier on switch | middleware sees new `viewer`; `getUserMenu()` omits `/design` for `client`/`end_user` |
| Custom domains (`acme.com`, `eu.enterprise.com`) navigate via badge, not in-place switch | `<a href="https://{domain}/…" target="_blank">` on the domain badge — switching in-place stays on the canonical `{slug}.one.ie` host |
| L4 prefs (theme, sidebar-pinned, chat-mode) persist across switches | `localStorage` keys are uid-scoped, not group-scoped (`roles.md §10 [L4]`) |

---

## 12. Open question — surfaced, not decided

**Cross-org agent loan.** When Alice is in `group:alice` *and* `acme` and *also* an agency staffer in `acme/startup-1`, her personal agent `writer-bot` should be reachable from each switcher context. Three patterns from `groups.md §Bringing agents into orgs` already cover this (copy / loan / service). The switcher itself does **not** make this choice — it surfaces the actor's group; the agent picker in `/agents` reads `actor.owner` and the active `gid` to decide which agents to render. Listed here so it doesn't sneak into the switcher scope later.

---

## 13. References

- `plans/groups.md` — the rule, the API surface, security invariants
- `plans/roles.md` — 4 tiers, surface matrix, cascade model
- `plans/org-chart.md §3-7` — marketing/sales/service/community pod definitions
- `plans/roles-todo.md` — viewer, menu, sidebar, plan column (all ✓)
- `schema/one.tql:17-285` — `group`, `membership`, `member-role`, `plan`, `role-grant`, `capability`
- `one.ie/web/src/components/sidebar/Sidebar.tsx` — host
- `one.ie/web/src/lib/viewer.ts` — tier resolver to extend in S8

---

*The substrate already says who you are in every group. This doc just gives you a button to live the answer.*

---

## §B. Companion surfaces — what makes the views perfect

The switcher pivots the *active group*. Six adjacent surfaces make each role's view complete: **Act As** (impersonation), **Members roster**, **Audit**, **Invites**, **Pinned/Recent**, **Default-landing**. Plus eight smaller refinements that close edge cases. Together they ensure every role sees the right people, the right context, and the right entry point on every sign-in or switch.

### B1. Act As (impersonation) — the missing primitive

Switching shows you a group you are *already* a member of. **Act As** is the missing peer: assume another actor's session for support, debugging, or agency-on-behalf-of-client work, without knowing their credentials.

**Canonical term:** *impersonation*. **UI label:** *Act As {Name}* (lower-alarm for end-clients reading audit trails). Industry analogues: Salesforce "Login As", Stripe "View as", Intercom "Login as user", Auth0 "impersonation grant" (deprecated), Okta "assume session".

**Schema** — no new entities; uses existing `actor` + `role-grant` + `signal`:

```
relation impersonation,
    relates actor    @card(1),         # the human actually logged in
    relates as       @card(1),         # the actor being acted-as
    relates scope    @card(1),         # group the act-as is bounded to
    owns started-at,
    owns expires-at,                   # default 1h, hard max 8h
    owns reason,                       # free text, required, audited
    owns mode;                         # "read" | "write"
```

> Add to `schema/one.tql` after `relation role-grant`. Plays into `signal.actor` via a virtual rewrite: every signal during an act-as carries both `actor: <as>` and `acting-via: <real>` so the audit trail never loses the real human.

**Who can Act As whom — the matrix** (enforced server-side in a new `POST /api/act-as`):

| Real-actor tier | Target | Allowed | Mode default | Max duration |
|---|---|---|---|---|
| `owner` (platform) | any actor | ✓ | `read` | 8h |
| `agency` (org owner/admin) | any member of own org | ✓ | `read` (write requires `act-as-write` capability) | 4h |
| `agency` (org owner/admin) with `manage_clients` | any member of a client org under their hierarchy | ✓ | `read` | 2h |
| `client` | any member of own org | ✗ (out of scope v1; can be added later for client-admins-of-sub-orgs in Pattern D) | — | — |
| `end_user` | — | ✗ | — | — |

**Hard rules:**

1. **No nesting.** Act-As cannot itself Act As. Server rejects `POST /api/act-as` if `ctx.locals.acting-via` is set.
2. **No credential exposure.** Act-As mints a short-lived session cookie (`session-act-as`) signed with the real actor's session + target uid + expiry. The target's API keys, passkeys, wallets, and secrets are **never** loaded into the impersonator's context.
3. **No financial / destructive actions in read mode.** `mode: "read"` blocks all `POST/PATCH/DELETE` except `POST /api/act-as/end`. `mode: "write"` requires the impersonator to also hold an explicit `act-as-write` capability granted by an `owner`.
4. **Always banner.** A persistent red top-bar renders globally while acting-as: *"Acting as Bob Smith — return to your account"* with a one-click exit. Banner is rendered by `Layout.astro` from `ctx.locals.acting-via`, cannot be dismissed.
5. **Always audited.** Every signal during act-as writes `(signal, acting-via, real-actor, reason)`. Available to the target via `GET /api/audit/act-as?as=<uid>` — the impersonated actor sees who acted as them, when, and why.
6. **Auto-expire.** Session cookie hard-expires at `expires-at`. Re-up requires fresh reason + fresh confirmation.

**UI placement:** entry point is **not** in the switcher popover (which is for groups you *are*). It's in the **members list** of a group (§B3) — each row has a `…` menu with "Act As" when allowed. While acting-as, the switcher itself shows a second "(acting-via Alice)" line in the header so the impersonator always knows their real identity.

### B2. Default landing per tier on first sign-in / on switch

`roles.md §6` notes the convention but the switcher needs to honor it explicitly.

| Tier | Lands on (no last-active) | Lands on (with last-active) |
|---|---|---|
| `owner` | `/dashboard` (platform aggregate) | last-active route within last-active group |
| `agency` | `/u/<own-org>/dashboard` | last-active |
| `client` | `/u/<active-org>/chat` | last-active |
| `end_user` | `/u/<workspace>/chat` | `/u/<workspace>/chat` (always — no other route allowed) |

**Default-group rule on sign-in:** (a) last-active group from `KV: session:last-group:<uid>` if still a member; else (b) most-recently-joined org; else (c) personal group.

### B3. Members surface — owners see staff, clients see their staff

Switcher is for pivoting between groups; **roster** is the separate surface that answers "who is in this group with me, in what role". This is what "agency sees their clients' staff" actually means.

**Route:** `/u/<gid>/members` (new). Accessible to `viewer ∈ {owner, agency, client}` per `roles.md §7 Settings → Team management`.

**Columns:** Name · Email (masked for `client` tier) · Role · Last active · Sub-team memberships (chips) · `…` menu (Invite, Change role, Remove, **Act As**).

**Cascade:** members of a parent org are visible to admins of any child sub-team (read-only); members of a sub-team are visible only to that team's members + org admins. Matches the same MAX-role partial order from §5.

**Agency client-roster:** when active group is an agency org, `/u/<agency-gid>/members?view=clients` aggregates members across every client sub-org. This is the "agency sees every client's staff in one screen" view. Columns gain a `client-org` chip.

### B4. Removed-while-active fallback

If an actor is removed from their currently-active group (or the group is deleted) mid-session, middleware redirects to personal group on the next navigation and surfaces a toast: *"Your access to {name} ended."* If personal was the active group (impossible — chairman can only `DELETE`, see `groups.md`), redirect to sign-in.

### B5. Pending invites indicator

Switcher header shows a badge with count of pending `/api/invites` for the actor's email. Clicking opens an Invites pane (separate from the group tree) listing each pending invite with Accept / Decline. Accepting writes the membership + invalidates `/tree` KV.

### B6. Recently used + pinned groups

For actors with 20+ memberships (agency staff servicing many clients), the tree gains:

- **Pinned** section at the very top (max 5, drag to pin/unpin, persisted in `KV: pins:<uid>`).
- **Recent** sub-section under Personal showing last 5 visited groups by mtime.
- Full tree below, filterable by the existing search box.

### B7. Keyboard shortcut

`⌘G` (Cmd-G / Ctrl-G) opens the switcher popover with focus on the search box. `⌘K` is reserved for global command-palette. Selection with arrow keys + Enter. Esc closes.

### B8. Inbox counter per group

`/api/inbox/:uid` (exists per `groups.md §API Surface`) is fanned out per group: each switcher row shows an unread badge sourced from `GET /api/inbox/:uid?group=<gid>`. Single `/api/inbox/counts` aggregation endpoint added to avoid N+1; cached in KV with 15s TTL.

### B9. Cross-pollination role edge case

When an actor holds, e.g., `member` of `acme` (client tier in acme) but `admin` of `acme-marketing` (agency tier in that team), the switcher renders **the effective tier per row**, not a single session tier. Switching into `acme` → tier=`client`; switching into `acme-marketing` → tier=`agency`. `resolveViewer()` (§8) is called per active-group, not once per session. Already implicit in §5; promoting to invariant in §11.

### B10. Mobile switcher

Per `roles.md §6` mobile is a bottom sheet. `GroupSwitcher.tsx` renders inside `<Sheet>` on `<md` viewports — same tree component, full-height sheet, search pinned to top, "Act As" entry from members list opens a confirm dialog instead of a `…` menu.

### B11. Time-bounded capability grants

`manage_clients` (and any future capability) should support `expires-at` on `role-grant` — already supported by the schema if we use it. Plan: every `role-grant` written by the switcher / Act As flow sets `expires-at` (default null = permanent for `manage_clients`, mandatory for Act As). Cron job (`sync/`) sweeps expired grants nightly.

### B12. SSO / SAML role mapping (deferred — call out as future)

Enterprise plan: IdP groups → ONE memberships mapping table (`saml_role_map(idp_group, gid, member-role)`). Not in v1 build sequence but the switcher already tolerates it because memberships are read from TypeDB regardless of how they were written.

### B13. End-user → client upgrade UX

When `end_user` accepts an invite, middleware sees the new membership on next request, switcher rebuilds, and a one-time onboarding toast points at the switcher: *"You now have access to {org}. Switch contexts here."* Implementation: `signal({verb: "join", scope: "private"})` on accept; `Sidebar.tsx` reads unseen-joins from KV and pulses the switcher trigger.

### B14. Audit log surface

New route `/u/<gid>/audit` (viewer: `owner` / `agency`). Lists every membership change, role change, switch event, and Act As session in the group's hierarchy. Backed by existing `signal` relation with `verb ∈ {join, leave, role-change, act-as-start, act-as-end}` filtered by `scope = active gid` and hierarchy descendants.

### Invariants — additional rows (append to §11)

| Invariant | Where enforced |
|---|---|
| Act As cannot nest | `POST /api/act-as` rejects if `acting-via` already set |
| Act As never exposes target credentials / wallets / API keys | session-act-as cookie carries uid only; secret loaders gate on `ctx.locals.acting-via == null` |
| Act As read-mode blocks all mutations | middleware gate on `mode === "read"` for non-GET methods (except `/api/act-as/end`) |
| Acting-as banner is non-dismissible | banner DOM is in `Layout.astro` body root; no `display:none` toggle exposed |
| Acting-as expires server-side | cookie `exp` claim checked on every request; expired = 401 + redirect to real session |
| Every Act As writes `signal{verb:"act-as-start"}` and `verb:"act-as-end"` | `/api/act-as` handlers |
| Impersonated actor can see who acted as them | `GET /api/audit/act-as?as=<uid>` filtered by `signal.actor = uid` |
| Effective tier is per-active-group, never per-session | `resolveViewer()` called in middleware on every navigation |
| Removed-while-active never leaves the user in a 403 loop | middleware sees missing membership → 302 to personal |
| Time-bounded grants are swept | `sync/` cron sets `member-role = "viewer"` or deletes grant past `expires-at` |

---

## §A. roles.md feature × switcher verification matrix

Every load-bearing claim in `roles.md` is paired with the switcher behavior that proves it works. S11 (Playwright e2e) asserts every row.

| `roles.md` § | Feature | Switcher behavior | Assertion in S11 |
|---|---|---|---|
| §1 | Group dimension is the UI lens | `/api/groups/tree` returns dimension-1 entities only | tree response has only `group-type ∈ {personal, world, org, team, community, dao, friends}` |
| §2 | 4 tiers: owner/agency/client/end_user | `resolveViewer()` returns exactly one of these post-switch | switch → assert `Astro.locals.viewer` matches expected per-group |
| §2 | Tiers additive downward | `owner ⊃ agency ⊃ client ⊃ end_user` per `roles.md §2` | owner-tier session sees every group end_user-tier session sees, plus strictly more |
| §3 A Solo | Single-person pattern | personal-only tree, no Clients pane | new-signup tree has 1 node |
| §3 B Agency | Agency + clients | Clients pane appears when active org has `plan: agency` + `manage_clients` | switch into `acme` → Clients pane visible; switch into `group:alice` → not visible |
| §3 C Team | Internal teams under org | 4 sub-teams render as `group-type: team` children | join `bigco` on `plan: scale` → 4 team rows appear |
| §3 D Enterprise | Divisions = sub-workspaces with own brand/domain | switching into `eu-ops` swaps brand tokens + offers domain badge to `eu.enterprise.com` | post-switch DOM has `--primary` from `eu-ops`, badge has correct href |
| §3 E Network | Independent agencies cannot see each other's clients | sibling-agency query returns 0 rows | session-as-agency-A → tree has 0 nodes from agency-B's subtree |
| §4 | 6-layer cascade | switcher swaps L1–L3 only; L0 + L5 stable | switch + assert `localStorage.theme` unchanged; `WorkspaceConfig.tokens` re-resolved |
| §5 | `WorkspaceConfig` fields | resolved config has all §5 fields after switch | response includes name/tagline/logo/favicon/tokens/locked/font/features/nav/chat/roles |
| §6 | Nav per tier | post-switch sidebar matches §8a matrix | filter `<nav a>` by route, compare to matrix per tier |
| §6 | Custom nav items | agency-set `nav.items` render below standard items | seed `site.md` with custom item, assert order |
| §6 | Sidebar geometry mini/full/hidden | active group's `sidebar` setting applied on switch | switch into a `sidebar: hidden` group → no `<aside>` |
| §7 Chrome | Logo/tokens/font/favicon swap on switch | DOM `<link rel="icon">` + CSS vars swap | snapshot favicon href + `--primary` before/after switch |
| §7 Chat | Welcome/starters/persona swap | `<ChatHost>` receives new props | assert opening message text matches new group's `chat.welcome` |
| §7 Agents | "Create" CTA hidden for client tier | post-switch DOM has no `[data-cta="agent-create"]` for client | switch as client into agency-owned org → assert absence |
| §7 Skills | Surface hidden from client tier | `/u/<client>/skills` returns 404/redirect | tier=client GET /skills → 3xx to /chat |
| §7 Payments | Revenue dashboard scope per tier | agency sees own ws only; client sees own billing only | seed two-tenant data, assert response row counts |
| §7 Settings | Workspace branding visible to agency, not client | post-switch /settings tree visibility | tier=client → no branding section |
| §7 Design | `/design` owner+agency only, own ws | post-switch `/design` access | tier=client → 403; tier=agency in own ws → 200; tier=agency in client sub-ws → 200 |
| §8 | White-label chain end-to-end | end-user on a client sub-ws never sees ONE branding | E2E: visit `startup-1.acme.com` anon → no "ONE" text in DOM (except attribution if not locked off) |
| §9 | Locked grammar `-locked` | client cannot override locked agency token | seed `primary-locked: true` on acme → switch into client sub-ws → attempt PATCH /api/settings primary → 403 |
| §9 | A layer can only lock what it set | `/api/groups` rejects locking unset properties | POST with lock on unset prop → 422 |
| §10 Identity | Custom domain per group | domain badge in switcher row | seed `domain: acme.com` → badge renders with that href |
| §10 [L4] | localStorage user prefs only | switching does not clear theme / pin / chat-mode | set prefs, switch 3x, assert prefs intact |
| §11 | `resolveConfig` runs in middleware | every switched route hits middleware before render | network log: 1 SSR request per switch, no client-side merge |
| §12 | Viewer propagated as prop, not fetched | components receive `viewer` from `Astro.locals` | grep components/* for `fetch.*viewer` — should be 0 |
| §13 | Ontology↔UI mapping | switcher is the dimension-1 UI surface | doc check: this file linked from `roles.md §13 Groups` row |
| §14 step 1 (done) | 4-tier viewer + menu filter | reused, not duplicated | S2 imports `getUserMenu` + `Viewer` from existing modules |
| §14 step 2 | `resolveConfig()` cascade | switcher relies on it | S1 middleware path traced in tests |
| §14 step 3 | Locked properties parser | enforced through cascade on switch | covered by §9 row above |
| §14 step 4 | Per-client override file | switching into client loads `clients/{clientSlug}.md` | seed file, switch, assert applied |
| §14 step 5 | Per-team config file | switching into team loads `teams/{gid}.md` | seed file, switch, assert applied |
| §14 step 6 | Client manager in Settings | "+ Add client" in switcher Clients pane links to it | click → land on `/settings#clients` with form open |
| §14 step 7 | Team manager in Settings | "+ Add team" appears for org owner/admin | tier=agency → button present |
| §14 step 8 | Nav override UI | agency-set custom items survive switch | covered by §6 custom nav row |
| §14 step 9 | Chat config UI | covered by §7 chat row | — |
| §14 step 10 | Mobile feature gates | mobile sheet menu respects same matrix as desktop | viewport=375px → §8a matrix still holds |

Any row that fails in S11 blocks the cycle. Doc-sync (S12) updates `roles.md §6` Nav table and `§14` step list to note the switcher as the rendering surface.
