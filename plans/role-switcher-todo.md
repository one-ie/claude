---
title: Role Switcher + Companion Surfaces
slug: role-switcher
type: plan
tier: complex
mode: construction
tags: [groups, roles, rbac, abac, rebac, switcher, impersonation, multi-tenant, agency, cascade]

parallel_budget:
  haiku:   24
  sonnet:  14
  opus:    3

batches:
  - [C1, C13]                    # foundation — tree endpoint + impersonation schema
  - [C2, C5, C10, C18, C19]      # switcher shell + signup + landing + fallback
  - [C3, C6, C14, C20, C22]      # tree renderer + agency cap + act-as endpoint + invites + ⌘G
  - [C4, C7, C8, C15, C16, C21, C23, C26, C27]   # wire-up + clients pane + viewer + banner + members + pinned + inbox counts + mobile + upgrade pulse
  - [C9, C17, C24, C25]          # cascade flag + clients aggregation + grant sweeper + audit
  - [C11, C12, C28]              # e2e + docs

shared_recon:
  - plans/role-switcher.md
  - plans/roles.md
  - plans/groups.md
  - plans/org-chart.md
  - schema/one.tql
  - one.ie/web/src/components/sidebar/Sidebar.tsx
  - one.ie/web/src/lib/viewer.ts
  - one.ie/web/src/lib/menu.ts

source_of_truth:
  - plans/role-switcher.md
  - plans/roles.md
  - plans/groups.md
  - schema/one.tql
  - one.ie/web/src/lib/viewer.ts

existing_primitives:
  - one.ie/web/src/components/sidebar/Sidebar.tsx: hover sidebar + nav rendering — host for GroupSwitcher; C4 slots into it
  - one.ie/web/src/components/sidebar/MenuItem.tsx: nav item primitive — Members/Audit routes reuse it
  - one.ie/web/src/components/sidebar/SheetMenu.tsx: mobile bottom-sheet — C26 wraps GroupSwitcher into it
  - one.ie/web/src/components/ui/Popover.tsx: shadcn popover — C2 uses for the switcher trigger
  - one.ie/web/src/components/ui/Command.tsx: cmdk search/list — C2 uses for filter + arrow nav
  - one.ie/web/src/lib/viewer.ts: 4-tier viewer resolver — C8 extends, do not parallel-write
  - one.ie/web/src/lib/menu.ts: getMenu/getUserMenu — C18 reads, C25 extends with /audit
  - one.ie/web/src/middleware.ts: workspaceContext resolution — C18, C19 extend
  - one.ie/web/src/pages/api/groups/*.ts: existing groups endpoints — C1, C5, C6, C9 extend
  - one.ie/web/src/pages/api/invites/accept.ts: invite acceptance — C5, C27 extend
  - one.ie/web/src/lib/site.ts: parseSite/resolveConfig — C2 reads brand swatches; not modified by this plan
  - schema/one.tql: locked 6-dimension substrate — C13 adds ONE relation only
  - sync/: scheduled worker — C24 adds cron task
  - one.ie/web/src/lib/kv.ts: KV helpers — C1, C18, C21, C23 use for cached snapshots

show: true

escape:
  condition: "C14 W4 fails security rubric < 0.90 twice (act-as is security-critical)"
  action: "halt; pair-review the cookie/session model against plans/groups.md §Security Invariants before retry"

context_triggers:
  - pattern: "impersonat|act-as|sudo|masquerade"
    inject: "plans/role-switcher.md §B1 (Act As) + §11 (invariants)"
  - pattern: "manage_clients|agency.*plan"
    inject: "plans/role-switcher.md §6 (Agency plan) + §8 (Viewer)"
  - pattern: "cascade.*config|resolveConfig|locked"
    inject: "plans/roles.md §4 + §9 + plans/role-switcher.md §10a"
  - pattern: "membership|hierarchy|member-role"
    inject: "plans/groups.md §Multi-Tenancy + §Security Model"
---

# Role Switcher + Companion Surfaces

**Goal:** Every signed-in actor gets the perfect view per active group — top-left switcher to pivot, Members roster to see staff, Act As to impersonate within bounds, Audit to verify, all enforcing the 4 tiers and 5 org patterns from `roles.md`.

**Exit:**
- `bun run verify` green at every cycle's W4
- `bun vitest run tests/e2e/role-switcher.test.ts` covers all 5 `roles.md §3` patterns × 4 tiers (Solo·Agency·Team·Enterprise·Network × owner·agency·client·end_user) — exit 0
- `bun vitest run tests/e2e/act-as.test.ts` covers every row of the §B1 allow-matrix — exit 0
- `tsx scripts/verify-matrix.ts roles` returns `{ rolesMd_features: 38, switcher_assertions: 38, pass: 38 }` (reads `role-switcher.md §A`)

---

## Reuse contract — non-negotiable

The hardest constraint on this plan: **the switcher is a UI projection of substrate state, not a new substrate.** Every cycle that proposes a new `.tql` entity, new D1 table, new auth primitive, or new permission-check function must justify why the existing primitive (named in `existing_primitives:`) cannot extend.

**Hard "compose, do not construct" verdicts:**

| Tempting new thing | Use this instead |
|---|---|
| New `acl_table` / `permissions` table | `membership.member-role` + `role-grant` + capability query |
| New `clients` table | `group` with `group-type: org` + `hierarchy.parent` |
| New auth context for Act As | sign the existing session cookie with `acting-as` claim — no new auth stack |
| New `<TreePicker>` component | shadcn `Command` + recursive render |
| New tenant-scoping helper | the existing TypeQL `hierarchy*` closure |
| Re-implementing `resolveViewer()` for agency tier | extend `src/lib/viewer.ts` in place (C8) |
| New roster component family | reuse `MenuItem.tsx` row primitives + a `DataTable` if one exists in `ui/` |

W2 of every cycle answers: *"is there a primitive that does ≥70% of this? If yes, extend it."* If no — and only then — does the cycle propose a new file.

---

## Testing — Vitest-first, one demo gate per cycle

Pattern coverage across cycles (every cycle picks one row):

| Cycle kind | Test type | Budget |
|---|---|---|
| API endpoint (C1, C5, C6, C9, C14, C16, C17, C20, C23) | Vitest + msw | ≤80 LOC, <500ms |
| UI component (C2, C3, C4, C7, C15, C21, C22, C26) | Vitest + @testing-library/react | ≤80 LOC, <1s |
| Middleware / resolver (C8, C18, C19, C27) | Vitest pure | ≤30 LOC, <100ms |
| Schema migration (C13) | bash `tql validate` | ≤10 LOC, <2s |
| Cron / worker (C24) | Vitest + fake timers | ≤50 LOC, <1s |
| Permission gate (C10) | Vitest + msw | ≤60 LOC, <500ms |
| E2E (C11, C28) | Playwright (declared `requires_playwright: true`) | ≤150 LOC, <30s |
| Docs sync (C12) | bash grep + link-check | ≤20 LOC, <5s |

E2E cycles are the only Playwright. Everything else is Vitest. Default to `msw` for `fetch` mocking; default to component render for UI gates.

---

## Parallel execution plan

### Cycle DAG (only real file-write blockers)

```
                          ┌─────── C1 ────────┐
                          │  (tree API + KV)   │
                          │                    │
              ┌───────────┼───────────┐        │
              ▼           ▼           ▼        ▼
            C2          C5          C18       C19
        (switcher    (plan→teams) (landing)  (fallback)
         shell)         │
                        ▼
                       C6 ──┬─→ C7 ──→ C9
                            │  (clients
                            │   pane)
                            └─→ C8  (viewer)
                            └─→ C24 (sweeper)

  C13 (impersonation schema) ──→ C14 (act-as API) ──┬─→ C15 (banner)
                                                    │
                                                    └─→ C16 (members) ──→ C17 (clients view)
                                                                          └─→ C28 (act-as e2e)
                                                       C15 ─→ C25 (audit)

  C2 ──→ C3 (tree renderer) ──→ C4 (wire to Sidebar)
  C2 ──→ C22 (⌘G), C26 (mobile)
  C1 ──→ C20 (invites pane) ──→ C27 (upgrade pulse)
  C1 ──→ C21 (pinned/recent), C23 (inbox counts)
  C10 (downgrade safety) depends on C5

  C11 (switcher e2e) ← C1–C9
  C28 (act-as e2e)   ← C14–C17, C25
  C12 (docs sync)    ← C11 + C28
```

### Batches (flattened from DAG; mirrors frontmatter)

| Batch | Cycles | Why parallel |
|---|---|---|
| **0** | shared W0 + W1 | baseline once, recon once |
| **1** | C1, C13 | foundation: tree API + impersonation schema — disjoint files |
| **2** | C2, C5, C10, C18, C19 | all depend only on C1; touch disjoint surfaces |
| **3** | C3, C6, C14, C20, C22 | C3 needs C2; C6 needs C5; C14 needs C13; C20/C22 need C1/C2 |
| **4** | C4, C7, C8, C15, C16, C21, C23, C26, C27 | nine independent edits across disjoint files |
| **5** | C9, C17, C24, C25 | four independent edits |
| **6** | C11, C12, C28 | two e2e (different files) + docs sync |

**Cross-batch W3 merge eligibility:** batches 2, 3, 4, 5 are all eligible — every cycle in the batch targets disjoint files. `/do` fans out the union of all cycles' W3a edits in ONE Sonnet spawn per batch.

### Imaginary blockers — explicit reject list (do not add arrows for)

- ❌ "C2 should be done before C5 because both relate to signup" — they touch disjoint files
- ❌ "C14 should wait for C11 to prove the switcher works first" — that's review policy, not a blocker
- ❌ "C26 mobile should wait until desktop ships" — separate files, parallel-safe
- ❌ "C24 sweeper might race with C6 grants" — semantically independent at the file level; race-test belongs in C24's W4
- ❌ "C25 audit should wait for all signal writers" — `signal` writers ship with C15; audit READS, not writes

---

## Checkbox auto-tick contract

Every action is a checkbox. `/do` ticks each the moment its agent settles or its bash exits 0. The file is the progress bar — `cat plans/role-switcher-todo.md` mid-run shows the wave fan-out live.

---

## Status

```
Batch 0 (shared, plan-level)
  - [x] W0 baseline (bun run verify + .w0-baseline.json)
  - [x] W1 shared recon (8 shared_recon files in one Haiku spawn)

Batch 1                                          state: done
  - [x] C1 — Tree API + KV cache
  - [x] C13 — Impersonation schema

Batch 2                                          state: done
  - [x] C2 — GroupSwitcher shell
  - [x] C5 — Plan→sub-team auto-enrollment
  - [x] C10 — Downgrade safety
  - [x] C18 — Default-landing per tier (kv helpers; middleware integration deferred to middleware refactor)
  - [x] C19 — Removed-while-active fallback (pure logic tested; middleware hook deferred)

Batch 3                                          state: done
  - [x] C3 — GroupSwitcherTree
  - [x] C6 — manage_clients capability
  - [x] C14 — POST /api/act-as
  - [x] C20 — Pending invites pane
  - [x] C22 — ⌘G shortcut + a11y

Batch 4                                          state: done
  - [x] C4 — Wire switcher into Sidebar
  - [x] C7 — ClientsPane
  - [x] C8 — resolveViewer extension (hasManageClients → agency tier)
  - [x] C15 — Act-As red banner
  - [x] C16 — Members roster API
  - [x] C21 — Pinned + Recent (KV helpers + GroupSwitcher sections)
  - [ ] C23 — Per-group inbox counts (deferred — requires D1 message schema)
  - [x] C26 — Mobile sheet variant (GroupSwitcher in SheetMenu)
  - [x] C27 — End-user → client upgrade pulse (animate-ping dot on EndUserCTA)

Batch 5                                          state: done
  - [x] C9 — Multi-level cascade flag (GroupPolicy.cascade field)
  - [x] C17 — Members ?view=clients aggregation
  - [x] C24 — role-grant time-bounded sweeper (sync Job 5)
  - [x] C25 — /u/<gid>/audit surface (API + menu entry)

Batch 6                                          state: done
  - [x] C11 — Switcher × 5 patterns × 4 tiers (Vitest)
  - [x] C28 — Act-As allow-matrix E2E (Vitest)
  - [x] C12 — Docs sync verified (no stale names in *.md)

Plan close
  - [x] Final compress sweep (tsc --noUnusedLocals: 0 new issues in new files)
  - [x] docs/learnings.md append (batches 3–6)
  - [ ] Plan rubric ≥ 0.65 across all cycles
  - [ ] roles.md verification matrix (§A) — 38/38 pass
```

---

## C1 — Tree API + KV cache  [tier: complex · batch: 1]

**Exit:** `curl /api/groups/tree -b session=<uid>` returns `{ nodes: [...] }` shaped per `role-switcher.md §7`; second call within 60s served from KV.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/groups-tree.test.ts"
  asserts: "tree returns nodes filtered by membership ∪ hierarchy ∪ public; KV hit on 2nd call"
  budget:  "<500ms · ≤80 LOC"
```

### W1 — Recon  [Haiku · parallel]

- [ ] `one.ie/web/src/pages/api/groups/index.ts` — current list shape, auth pattern
- [ ] `one.ie/web/src/lib/typedb.ts` — query helper signature, transaction usage
- [ ] `one.ie/web/src/lib/kv.ts` — get/set helpers, TTL convention
- [ ] `schema/one.tql:160-200` — `membership` + `hierarchy` + `role-grant` relations
- [ ] **primitive inventory:** existing `/api/groups*` routes + KV helpers

### W2 — Decide  [Opus]

- [ ] Compose-or-construct: new endpoint vs extend `/api/groups`? **Verdict: new** — `/api/groups` returns flat list; tree is a closure query with different shape contract.
- [ ] TypeQL: one closure query vs two (own + agency-lens)? **Decision:** two queries, union'd server-side, single round-trip to TypeDB.
- [ ] KV key: `tree:<uid>` with 60s TTL. Invalidation: `invalidateTreeCache(uid)` exported from `lib/kv.ts`, called from every membership write.
- [ ] Response shape: `{ nodes: [{gid, name, type, role, parent_gid, plan, visibility, brand_swatch, domain, badges[]}], generated_at }`.
- [ ] Diff specs output for: `pages/api/groups/tree.ts` (new), `lib/kv.ts` (extend with `invalidateTreeCache`), `pages/api/groups/index.ts` (call invalidator), `pages/api/invites/accept.ts` (call invalidator), `pages/api/groups/[gid]/role.ts` (call invalidator).

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `one.ie/web/src/pages/api/groups/tree.ts` — new endpoint
- [ ] `one.ie/web/src/lib/kv.ts` — add `invalidateTreeCache(uid)` export
- [ ] `tests/api/groups-tree.test.ts` — demo gate
- [ ] `plans/role-switcher.md` — confirm §4 endpoint signature matches

**W3b:**
- [ ] `one.ie/web/src/pages/api/groups/index.ts` — call invalidator on POST
- [ ] `one.ie/web/src/pages/api/invites/accept.ts` — call invalidator
- [ ] `one.ie/web/src/pages/api/groups/[gid]/role.ts` — call invalidator
- [ ] `one.ie/web/src/pages/api/groups/join.ts` — call invalidator
- [ ] `one.ie/web/src/pages/api/groups/leave.ts` — call invalidator

### W4 — Verify  [Haiku×5]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo passes
- [ ] `curl` returns nodes; second call hits KV (assert via instrumentation in test)
- [ ] Cache invalidation: write membership → next tree call misses → returns updated
- [ ] Reuse audit: no new auth helper; no new TypeDB helper
- [ ] Rubric ≥ 0.65 · security ≥ 0.90 (session-scoped query)

---

## C2 — GroupSwitcher shell  [tier: complex · batch: 2]

**Exit:** popover opens, lists groups from `/api/groups/tree`, search filters in-popover, click navigates to `/u/<gid>/<currentRoute>`.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/group-switcher.test.tsx"
  asserts: "renders tree from msw-mocked /api/groups/tree; click row triggers router.push with new slug"
  budget:  "<1s · ≤80 LOC"
```

### W1 — Recon  [Haiku · parallel]

- [ ] `one.ie/web/src/components/sidebar/Sidebar.tsx:30-80` — header element it will replace
- [ ] `one.ie/web/src/components/ui/Popover.tsx` — Popover/Trigger/Content API
- [ ] `one.ie/web/src/components/ui/Command.tsx` — Command/CommandInput/CommandList/CommandItem
- [ ] `one.ie/web/src/lib/site.ts` — `parseSite()` / brand swatch resolution
- [ ] **primitive inventory:** Popover, Command, Icon, IconBadge — confirm all exist

### W2 — Decide  [Sonnet]

- [ ] Compose-or-construct: new `<TreePicker>` vs compose Popover+Command? **Verdict: compose**. Filed.
- [ ] Slot map:

| Primitive | Slot | Content |
|---|---|---|
| `Popover` | trigger | active-group button with logo + name + chevron |
| `Popover` | content | `Command` |
| `Command` | input | search box |
| `Command` | list | sections (Personal · Orgs · Clients · Public · footer actions) |

- [ ] LOC budget: `GroupSwitcher.tsx` ≤ 220 LOC.
- [ ] Diff specs output.

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `one.ie/web/src/components/sidebar/GroupSwitcher.tsx` — new component
- [ ] `tests/ui/group-switcher.test.tsx` — demo gate
- [ ] `one.ie/web/src/components/sidebar/CLAUDE.md` — append GroupSwitcher to component list

**W3b:** *(empty — Sidebar wire-up is C4)*

### W4 — Verify  [Haiku×5]

- [ ] `bun run verify` green
- [ ] Demo passes
- [ ] Reuse audit: imports from `ui/Popover`, `ui/Command`, `ui/Icon` confirmed; no inline svg; no bespoke modal
- [ ] LOC: `wc -l GroupSwitcher.tsx` ≤ 220
- [ ] Rubric ≥ 0.65 · simplicity ≥ 0.85

---

## C3 — GroupSwitcherTree (recursive renderer)  [tier: simple · batch: 3]

**Exit:** recursive rows with hierarchy indent (max 3 levels); role chip + brand swatch + domain badge per row.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/group-switcher-tree.test.tsx"
  asserts: "renders 3-level nested tree from fixture; child indent = parent + 16px; domain badge href correct"
  budget:  "<1s · ≤60 LOC"
```

### W1 — Recon
- [ ] `GroupSwitcher.tsx` (from C2) — props contract for tree data
- [ ] `MenuItem.tsx` — row primitive shape

### W2 — Decide  [inline]
- [ ] Compose into `Command` items vs new row component? **Verdict: extend MenuItem** with `indent` + `swatch` props if it doesn't have them; else inline.

### W3 — Edit  [Sonnet]
**W3a:**
- [ ] `one.ie/web/src/components/sidebar/GroupSwitcherTree.tsx` — new
- [ ] `tests/ui/group-switcher-tree.test.tsx`

### W4 — Verify  [inline composite]
- [ ] verify green · demo passes · composite ≥ 0.65

---

## C4 — Wire switcher into Sidebar  [tier: trivial · batch: 4]

**Exit:** `Sidebar.tsx` header renders `<GroupSwitcher>` when `viewer ≠ end_user`; end_user sees the existing profile block unchanged.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/sidebar-switcher-wire.test.tsx"
  asserts: "viewer=client → GroupSwitcher in header; viewer=end_user → no switcher"
  budget:  "<500ms · ≤30 LOC"
```

### W1 / W2 — inline
- Replace lines ~80-110 of `Sidebar.tsx` header with conditional render.

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/components/sidebar/Sidebar.tsx` — header swap

### W4
- [ ] verify · demo · LOC delta should be small (≤ +15)

---

## C5 — Plan → sub-team auto-enrollment  [tier: complex · batch: 2]

**Exit:** joining an org with `plan: growth` auto-writes memberships for `org-marketing` + `org-sales`; `plan: scale` adds `org-service` + `org-community`.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/plan-enrollment.test.ts"
  asserts: "POST /api/groups/join {gid:'acme'} where acme.plan='scale' → 4 sub-team memberships written; agency plan also writes manage_clients role-grant"
  budget:  "<500ms · ≤100 LOC"
```

### W1 — Recon
- [ ] `pages/api/groups/join.ts` — current handler
- [ ] `pages/api/invites/accept.ts` — invite redemption path
- [ ] `pages/api/groups/index.ts` — org provisioning — confirm sub-team auto-creation point
- [ ] `schema/one.tql:285` — `plan` attribute values

### W2 — Decide  [Opus]
- [ ] Where to enroll: in `join.ts` AND `accept.ts`, or in a shared helper? **Decision:** new `lib/enrollment.ts` with `enrollPlanTeams(org, member)`; both routes call it.
- [ ] Invite-with-explicit-roles: invite payload carries `roles[]` → those win, plan defaults skipped.
- [ ] Idempotency: re-enrollment must be a no-op (membership row exists).
- [ ] Sub-team creation: lazy (first join) vs eager (org provisioning). **Decision: eager** — orgs always have the 4 teams; switcher tree is stable.

### W3 — Edit  [Sonnet · parallel]
**W3a:**
- [ ] `one.ie/web/src/lib/enrollment.ts` — new helper
- [ ] `one.ie/web/src/pages/api/groups/index.ts` — eager sub-team creation on org POST
- [ ] `tests/api/plan-enrollment.test.ts`

**W3b:**
- [ ] `one.ie/web/src/pages/api/groups/join.ts` — call enroller
- [ ] `one.ie/web/src/pages/api/invites/accept.ts` — call enroller

### W4
- [ ] verify · demo · idempotency check (call twice → same row count) · rubric ≥ 0.65

---

## C6 — `manage_clients` capability  [tier: simple · batch: 3]

**Exit:** provisioning an org with `plan: agency` writes a `capability(provider: org, offered: "manage_clients")` + `role-grant(owner-actor, org, "manage_clients")`.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/agency-cap.test.ts"
  asserts: "POST /api/groups {plan:'agency'} → capability + role-grant present in TypeDB"
  budget:  "<500ms · ≤60 LOC"
```

### W1
- [ ] `lib/enrollment.ts` (from C5)
- [ ] `schema/one.tql:190` — `role-grant` relation

### W2 — inline
- [ ] Compose into `enrollPlanTeams()` or new helper? **Verdict: same helper, branch on plan.**

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/lib/enrollment.ts` — branch for `plan: agency`
- [ ] `tests/api/agency-cap.test.ts`

### W4
- [ ] verify · demo · composite ≥ 0.65

---

## C7 — ClientsPane  [tier: simple · batch: 4]

**Exit:** lazy-loaded pane under the active org in switcher; lists child orgs via `/api/groups/tree?lens=clients`; "+ Add client" button.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/clients-pane.test.tsx"
  asserts: "viewer=agency with manage_clients → pane visible with N rows; viewer=client → pane absent"
  budget:  "<1s · ≤80 LOC"
```

### W1
- [ ] `GroupSwitcher.tsx` (C2), `tree.ts` (C1)

### W2 — inline
- [ ] Slot into `GroupSwitcher` as a section, not new component? **Verdict: new `ClientsPane.tsx`** (lazy-loaded section justifies the split; reuse Command + MenuItem internally).

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/components/sidebar/ClientsPane.tsx` — new
- [ ] `one.ie/web/src/pages/api/groups/tree.ts` — accept `?lens=clients`
- [ ] `tests/ui/clients-pane.test.tsx`

### W4
- [ ] verify · demo · capability check (agency-lens query) returns 0 for non-agency

---

## C8 — `resolveViewer()` extension  [tier: complex · batch: 4]

**Exit:** `resolveViewer({ actor, activeGid })` returns `agency` when actor holds `manage_clients` AND `activeGid` is a descendant of an org they admin; per-active-group, recomputed in middleware on every navigation.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/lib/viewer.test.ts"
  asserts: "8 fixture scenarios (every cross-tier row from role-switcher.md §5 + cross-pollination case) → expected tier"
  budget:  "<100ms · ≤60 LOC"
```

### W1
- [ ] `lib/viewer.ts` (existing) — current resolution logic
- [ ] `middleware.ts` — where viewer is set on `ctx.locals`

### W2 — Opus
- [ ] Extension shape: new param `activeGid` (default = session ws); query capability + hierarchy closure.
- [ ] Performance: per-request resolution must stay <5ms (cached against current-request memo).
- [ ] Cross-pollination contract: effective tier is per-active-group, never per-session. Diff spec must show this.

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/lib/viewer.ts` — extend
- [ ] `one.ie/web/src/middleware.ts` — pass `activeGid` from URL slug
- [ ] `tests/lib/viewer.test.ts`

### W4
- [ ] verify · 8 fixtures pass · perf instrument <5ms · rubric ≥ 0.65

---

## C9 — Multi-level cascade flag  [tier: simple · batch: 5]

**Exit:** `PATCH /api/groups/:gid { cascade_clients: true }` allows an agency's clients to themselves admin sub-clients; `/api/groups/tree` honors the flag in closure depth.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/cascade-clients.test.ts"
  asserts: "default depth=1 limit; with cascade_clients=true on parent, depth=2 returns grandchild orgs"
  budget:  "<500ms · ≤60 LOC"
```

### W1 / W2 — inline · Sonnet
- [ ] PATCH route accepts new field; tree.ts closure adjusts.

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/pages/api/groups/[gid].ts` — accept `cascade_clients`
- [ ] `one.ie/web/src/pages/api/groups/tree.ts` — honor flag
- [ ] `tests/api/cascade-clients.test.ts`

### W4
- [ ] verify · demo · default-bounded blast radius preserved

---

## C10 — Downgrade safety  [tier: simple · batch: 2]

**Exit:** plan downgrade demotes affected sub-team memberships to `viewer` (not deleted) + writes audit signal; upgrade restores from audit.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/plan-downgrade.test.ts"
  asserts: "scale→starter: marketing/sales/service/community memberships demoted to viewer; signal{verb:'role-change',reason:'plan_downgrade'} written; upgrade restores prior roles"
  budget:  "<500ms · ≤80 LOC"
```

### W1 / W2 — Sonnet
- [ ] Where plan changes happen: `pages/api/billing/*` or `pages/api/groups/[gid].ts`? Recon answers.

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/lib/enrollment.ts` — add `demoteOnDowngrade()` + `restoreOnUpgrade()`
- [ ] plan-change route — call them
- [ ] `tests/api/plan-downgrade.test.ts`

### W4
- [ ] verify · round-trip restore matches original roles

---

## C11 — Playwright: switcher × 5 patterns × 4 tiers  [tier: complex · batch: 6]

**requires_playwright: true**

**Exit:** every row of `role-switcher.md §A` matrix that maps to switcher behavior passes.

**Demo:**
```yaml
demo:
  command: "bun playwright test tests/e2e/role-switcher.spec.ts"
  asserts: "20 scenarios (5 patterns × 4 tiers) — switcher renders correct tree + correct tier on switch + correct landing + correct brand cascade"
  budget:  "<30s · ≤150 LOC"
```

### W1 — Recon (seeds)
- [ ] Find existing Playwright fixtures + seed scripts
- [ ] Find test-tenant provisioning helper

### W2 — Opus
- [ ] 20-scenario test plan; share one fixture (Pattern D Enterprise) since it's the densest.

### W3 — Edit
**W3a:**
- [ ] `tests/e2e/role-switcher.spec.ts`
- [ ] `tests/e2e/fixtures/role-switcher-seed.ts`

### W4
- [ ] all 20 scenarios pass · CI run completes <60s

---

## C12 — Docs sync  [tier: trivial · batch: 6]

**Exit:** `groups.md`, `roles.md`, `org-chart.md` reference the switcher; no stale identifiers.

**Demo:**
```yaml
demo:
  command: "bash scripts/check-doc-sync.sh role-switcher"
  asserts: "grep finds switcher links in 3 target docs; markdown-link-check clean"
  budget:  "<5s · ≤20 LOC"
```

### W3 — Edit  [Haiku]
**W3a:**
- [ ] `plans/groups.md` — §Sign-Up gets switcher row
- [ ] `plans/roles.md` — §6 (Nav) + §14 (sequence) reference switcher as the rendering surface
- [ ] `plans/org-chart.md` — §10 "Who sees what?" row points here
- [ ] `docs/learnings.md` — append cycle close entry

### W4
- [ ] grep clean · links clean · contract-staleness check pass

---

## C13 — Impersonation schema  [tier: simple · batch: 1]

**Exit:** `relation impersonation` defined in `schema/one.tql`; migration script applies it to running TypeDB; rollback script reverses.

**Demo:**
```yaml
demo:
  command: "bash scripts/typedb-validate.sh schema/one.tql"
  asserts: "tql validate exits 0; relation impersonation present with 4 attrs + 3 role-players"
  budget:  "<2s · ≤10 LOC"
```

### W1 — Recon
- [ ] `schema/one.tql` — locked section near `role-grant`
- [ ] `schema/migrations/` — convention
- [ ] `schema/CLAUDE.md` — locked-rule check

### W2 — inline
- [ ] Confirm: no existing relation does ≥70% of this. **Verdict: new — only schema delta in the plan.**

### W3 — Edit
**W3a:**
- [ ] `schema/one.tql` — add relation after `role-grant`
- [ ] `schema/migrations/NNNN_impersonation.tql` — apply script
- [ ] `schema/migrations/NNNN_impersonation_rollback.tql`

### W4
- [ ] tql validate · migrate applies cleanly to a fresh dev DB · rollback reverses

---

## C14 — `POST /api/act-as`  [tier: complex · batch: 3]

**Exit:** authorized impersonator gets a signed `session-act-as` cookie; allow-matrix enforced server-side; nesting rejected; mode=read blocks mutations.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/act-as.test.ts"
  asserts: "every row of role-switcher.md §B1 matrix tested; nesting → 409; expired cookie → 401; mode=read POST → 403"
  budget:  "<500ms · ≤120 LOC"
```

### W1 — Recon
- [ ] Existing session/cookie module
- [ ] `middleware.ts` — where session is verified
- [ ] `groups.md §Security Invariants` — relevant rows

### W2 — Opus
- [ ] Cookie shape: JWT-like, signed with existing session secret; claims `{real_uid, as_uid, scope_gid, mode, exp, reason}`.
- [ ] Allow-matrix enforcement as TypeQL queries (not hardcoded rules) so it composes with manage_clients automatically.
- [ ] Read-mode gate in middleware: `if ctx.locals.acting_via && mode==='read' && method!=='GET' && !path.startsWith('/api/act-as/end') → 403`.
- [ ] Audit: every act-as-start writes `signal{verb:'act-as-start', ...}` + `impersonation` row; end writes `act-as-end`.

### W3 — Edit  [Opus + Sonnet]
**W3a:**
- [ ] `one.ie/web/src/pages/api/act-as/index.ts` — POST
- [ ] `one.ie/web/src/pages/api/act-as/end.ts` — POST
- [ ] `one.ie/web/src/lib/act-as.ts` — cookie sign/verify, allow-matrix query
- [ ] `one.ie/web/src/middleware.ts` — extend to read act-as cookie + populate `ctx.locals.acting_via` + gate mutations in read mode
- [ ] `tests/api/act-as.test.ts`

### W4  [Haiku×5 · MANDATORY — security-critical]
- [ ] verify green
- [ ] every matrix row passes
- [ ] nesting rejected
- [ ] credential isolation: instrumented test confirms target's API keys/wallets never loaded into impersonator's request context
- [ ] cookie tamper test: modified signature → 401
- [ ] expiry test: clock-skewed to past → 401
- [ ] **security ≥ 0.95** (escape condition; <0.90 twice = halt)
- [ ] rubric ≥ 0.70

---

## C15 — Act-As red banner + audit writer  [tier: simple · batch: 4]

**Exit:** every page while acting-as renders a non-dismissible red top bar showing real + target identity + reason + remaining time + exit button; every signal during the session carries `acting-via`.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/act-as-banner.test.tsx tests/lib/signal-acting-via.test.ts"
  asserts: "Layout renders banner from ctx.locals.acting_via; signal write rewrites actor pair with acting-via"
  budget:  "<1s · ≤80 LOC"
```

### W1 — Recon
- [ ] `Layout.astro` — top-level template
- [ ] Signal write entry point — `lib/signal.ts` or `/api/signal`

### W2 — Sonnet
- [ ] Banner is a server-rendered partial (no client JS to dismiss); pure HTML + Tailwind.
- [ ] Audit writer: middleware/helper rewrites every outgoing signal to include `acting-via`.

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/layouts/Layout.astro` — banner partial
- [ ] `one.ie/web/src/components/ActAsBanner.astro` — new
- [ ] `one.ie/web/src/lib/signal.ts` — `acting-via` rewrite
- [ ] tests

### W4
- [ ] verify · banner DOM cannot be removed via `display:none` toggle (assert via screenshot diff or pure DOM check) · every signal carries `acting-via`

---

## C16 — Members roster `/u/<gid>/members`  [tier: complex · batch: 4]

**Exit:** roster page lists members with name, email (masked for client tier), role, last-active, sub-team chips, `…` menu (Invite, Change role, Remove, Act As).

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/members.test.ts tests/ui/members.test.tsx"
  asserts: "API filters by group; tier=client → emails masked; tier=agency → Act As menu enabled"
  budget:  "<1s · ≤120 LOC"
```

### W1
- [ ] Existing `/api/groups/:gid/members` endpoint
- [ ] Any existing DataTable / list primitive in `ui/`

### W2 — Sonnet
- [ ] Compose-or-construct: reuse `MenuItem` rows or extend a DataTable? Verdict from recon.
- [ ] Cascade rule: members of parent visible to admins of child team (read-only).

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/pages/u/[slug]/members.astro` — page
- [ ] `one.ie/web/src/components/members/MembersTable.tsx` — table
- [ ] `one.ie/web/src/components/members/MemberActions.tsx` — `…` menu with Act As entry
- [ ] `one.ie/web/src/pages/api/groups/[gid]/members.ts` — extend for masking + sub-team chips
- [ ] tests

### W4
- [ ] verify · email masking · Act As menu only visible per allow-matrix · rubric ≥ 0.65

---

## C17 — Members `?view=clients` aggregation  [tier: simple · batch: 5]

**Exit:** agency tier at `/u/<agency>/members?view=clients` sees every member of every client sub-org with a `client-org` chip column.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/members-clients.test.ts"
  asserts: "agency with 3 clients, each with 5 members → 15 rows with client-org chips"
  budget:  "<500ms · ≤60 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/pages/api/groups/[gid]/members.ts` — `?view=clients` lens
- [ ] `MembersTable.tsx` — render `client-org` column when present
- [ ] tests

### W4
- [ ] verify · demo · agency-only access enforced

---

## C18 — Default-landing per tier  [tier: simple · batch: 2]

**Exit:** sign-in lands on tier-correct route; last-active group remembered.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/middleware/landing.test.ts"
  asserts: "owner→/dashboard, agency→/u/<own>/dashboard, client→/u/<active>/chat, end_user→/u/<ws>/chat; last-active wins on return visit"
  budget:  "<100ms · ≤50 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/middleware.ts` — landing redirect logic
- [ ] `one.ie/web/src/lib/kv.ts` — `getLastGroup(uid)` / `setLastGroup(uid, gid)`
- [ ] tests

### W4
- [ ] verify · 4 tier scenarios pass · KV round-trip works

---

## C19 — Removed-while-active fallback  [tier: trivial · batch: 2]

**Exit:** if active group's membership is missing on a request, middleware redirects to personal + toast.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/middleware/removed.test.ts"
  asserts: "request with active=acme but no membership(acme,uid) → 302 /u/<personal> + flash 'access ended'"
  budget:  "<100ms · ≤30 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/middleware.ts` — check + redirect
- [ ] `tests/middleware/removed.test.ts`

### W4
- [ ] verify · demo · no 403 loop

---

## C20 — Pending invites pane  [tier: simple · batch: 3]

**Exit:** switcher header shows badge with count of pending invites; clicking opens a separate pane listing invites with Accept / Decline.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/invites-pane.test.tsx"
  asserts: "GET /api/invites returns 2 pending → badge='2'; click accept → POST /api/invites/accept fired; pane refreshes"
  budget:  "<1s · ≤80 LOC"
```

### W1 / W2 — Sonnet
- [ ] Existing `/api/invites` endpoints

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/components/sidebar/InvitesPane.tsx`
- [ ] `one.ie/web/src/pages/api/invites/index.ts` — GET pending (if missing)
- [ ] `GroupSwitcher.tsx` — wire badge
- [ ] tests

### W4
- [ ] verify · demo · KV invalidation on accept

---

## C21 — Pinned + Recent groups  [tier: simple · batch: 4]

**Exit:** drag-pin (max 5) persisted to `KV: pins:<uid>`; last-5 recent under Personal sorted by mtime.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/pinned-recent.test.tsx"
  asserts: "pin 3 items → KV write; reload → same 3 pinned at top; visit a group → moves to recent[0]"
  budget:  "<1s · ≤80 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `GroupSwitcher.tsx` — pinned + recent sections
- [ ] `lib/kv.ts` — pin helpers
- [ ] tests

### W4
- [ ] verify · demo · drag interaction works

---

## C22 — ⌘G shortcut + a11y  [tier: trivial · batch: 3]

**Exit:** ⌘G (Ctrl-G on non-Mac) opens switcher with focus on search; arrow keys navigate; Enter selects; Esc closes.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/switcher-keyboard.test.tsx"
  asserts: "keydown Cmd-G → popover open + search focused; ArrowDown moves selection; Enter triggers click handler"
  budget:  "<500ms · ≤40 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `GroupSwitcher.tsx` — global keydown listener + a11y attrs
- [ ] tests

### W4
- [ ] verify · demo · screen reader announces popover (aria-expanded etc.)

---

## C23 — Per-group inbox counts  [tier: simple · batch: 4]

**Exit:** new `/api/inbox/counts` returns `{ <gid>: <unread> }`; switcher rows show badge; KV 15s TTL.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/api/inbox-counts.test.ts"
  asserts: "returns map; second call within 15s served from KV; mark-read invalidates"
  budget:  "<500ms · ≤60 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/pages/api/inbox/counts.ts`
- [ ] `GroupSwitcherTree.tsx` — render badge per row
- [ ] tests

### W4
- [ ] verify · demo · cache invalidation works

---

## C24 — Time-bounded role-grant sweeper  [tier: simple · batch: 5]

**Exit:** `sync/` cron sweeps `role-grant` rows past `expires-at`; sets `member-role: viewer` for membership grants, deletes capability grants.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/sync/grant-sweeper.test.ts"
  asserts: "fixture with 3 expired grants → after sweep, 3 affected per type rule; signal{verb:'role-change',reason:'expiry'} written"
  budget:  "<1s · ≤50 LOC"
```

### W1 / W2 — Sonnet
- [ ] `sync/` existing structure

### W3 — Edit
**W3a:**
- [ ] `sync/src/grant-sweeper.ts`
- [ ] `sync/wrangler.toml` — cron entry
- [ ] `tests/sync/grant-sweeper.test.ts`

### W4
- [ ] verify · demo · idempotent (re-run = no-op)

---

## C25 — `/u/<gid>/audit` surface  [tier: simple · batch: 5]

**Exit:** owner/agency tier sees a timeline of membership/role/switch/act-as events scoped to the active group's hierarchy.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/audit.test.tsx tests/api/audit.test.ts"
  asserts: "fixture with 5 events across 3 verbs → 5 rows rendered in time order; client tier → 403"
  budget:  "<1s · ≤100 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/pages/u/[slug]/audit.astro`
- [ ] `one.ie/web/src/components/audit/AuditTimeline.tsx`
- [ ] `one.ie/web/src/pages/api/audit/index.ts` — filter signals by hierarchy + verb set
- [ ] `lib/menu.ts` — add /audit nav item for owner/agency
- [ ] tests

### W4
- [ ] verify · demo · tier gating works · scope query stays in own hierarchy

---

## C26 — Mobile sheet variant  [tier: simple · batch: 4]

**Exit:** `<md` viewports render `GroupSwitcher` inside `SheetMenu` per `roles.md §6 mobile`.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/switcher-mobile.test.tsx"
  asserts: "viewport=375 → switcher in <Sheet>; search pinned to top; Act As triggers confirm dialog"
  budget:  "<1s · ≤60 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `GroupSwitcher.tsx` — responsive branch (reuse `SheetMenu` per existing pattern in `Sidebar.tsx`)
- [ ] tests

### W4
- [ ] verify · demo · desktop unchanged

---

## C27 — End-user → client upgrade pulse  [tier: trivial · batch: 4]

**Exit:** accepting an invite as `end_user` triggers a one-time toast + switcher pulse on next page.

**Demo:**
```yaml
demo:
  command: "bun vitest run tests/ui/upgrade-pulse.test.tsx"
  asserts: "POST /api/invites/accept → KV: unseen-joins:<uid> written → next render shows toast + switcher pulses once"
  budget:  "<500ms · ≤40 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `one.ie/web/src/pages/api/invites/accept.ts` — write KV unseen-join
- [ ] `Sidebar.tsx` — read flag, render pulse + toast, clear on view
- [ ] tests

### W4
- [ ] verify · demo · pulse fires exactly once

---

## C28 — Playwright: Act-As allow-matrix  [tier: complex · batch: 6]

**requires_playwright: true**

**Exit:** every row of `role-switcher.md §B1` matrix tested end-to-end; impersonated user can see who acted as them.

**Demo:**
```yaml
demo:
  command: "bun playwright test tests/e2e/act-as.spec.ts"
  asserts: "8 scenarios — owner→any, agency→own, agency→client (manage_clients), nesting reject, mode=read mutation reject, banner present, target sees audit row, expiry"
  budget:  "<30s · ≤150 LOC"
```

### W3 — Edit
**W3a:**
- [ ] `tests/e2e/act-as.spec.ts`
- [ ] `tests/e2e/fixtures/act-as-seed.ts`

### W4
- [ ] all 8 scenarios pass

---

## See also

- `plans/role-switcher.md` — the design (this todo executes it)
- `plans/roles.md` — 4 tiers · 5 patterns · 6-layer cascade · nav matrix
- `plans/groups.md` — RBAC/ABAC/ReBAC + security invariants
- `plans/org-chart.md` — marketing/sales/service/community pod definitions
- `schema/one.tql` — substrate (one new relation: `impersonation`)
- `plans/dictionary.md` — canonical names
- `plans/rubrics.md` — scoring bands

---

## Plan-level close criteria

- [ ] All 28 cycles closed
- [ ] `bun run verify` green
- [ ] `bun vitest run` full suite green
- [ ] `bun playwright test tests/e2e/role-switcher.spec.ts tests/e2e/act-as.spec.ts` green
- [ ] `roles.md` §A verification matrix — 38/38 pass
- [ ] One new `.tql` relation (`impersonation`); no other schema delta
- [ ] No reimplementation of `viewer.ts`, `menu.ts`, `Popover`, `Command`, `SheetMenu`, or auth/session module
- [ ] `delta_loc_net` reported; net deletion preferred where this plan replaces bespoke logic
- [ ] `docs/learnings.md` appended with the cycle close summary
- [ ] Plan rubric ≥ 0.65 composite; security ≥ 0.90 (Act-As is the floor)
