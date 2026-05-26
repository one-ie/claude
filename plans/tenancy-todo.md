---
title: Tenancy — Groups as the tenant primitive; isolation + billing wiring for the BOQ 50-client pilot
slug: tenancy-todo
type: plan
tier: complex
mode: construction
tags: [tenancy, groups, isolation, billing, agency, multi-tenant, boq, scope, membership]
source_of_truth:
  - web/groups.md                # Groups nest groups; membership relation; slug tree; cascade
  - web/roles.md                 # 4 viewers (owner/agency/client/end_user); per-route role gates
  - web/billing.md               # Pool · grant · burn · gates · cascade — billing is per-Group
  - web/billing-todo.md          # Already 95% shipped; this plan WIRES it, doesn't rebuild it
  - web/lifecycles.md            # Group lifecycle: provisioned → live → suspended → archived
  - one/one-ontology.md          # Groups dimension is a recursive container — canonical primitive
existing_primitives:
  - web/src/middleware.ts: workspaceContext resolved with billing + gates cascade (E1 — shipped)
  - web/src/lib/billing.ts: pool/grant/burn debited per workspace (L1 — shipped)
  - web/src/lib/billing-config.ts: parseBilling + mergeBilling cascade engine (L2 — shipped)
  - web/src/lib/viewer.ts: deriveViewer → owner|agency|client|end_user
  - web/src/lib/in/role-gates.ts: filterNavigationByRole + filterOverflowVerbsByRole + filterSettingsByRole (C16 — shipped)
  - web/src/lib/in/workspace-settings.ts: workspace_id-keyed settings; 9 scopes (status/privacy/packs/thresholds/channels/list-ctas/detail-tabs/profile-completion/integrations)
  - web/migrations/0034_members_domain.sql: members table (group ↔ actor)
  - web/migrations/0035_workspace_settings.sql + 0036-0038: workspace_id columns on settings/tags/templates/journey
  - web/scripts/local-gateway.ts: stub TypeDB returns canned actors; for tests we mock per-Group
show: false
escape:
  condition: "any isolation test in C4 shows cross-Group leak  OR  delta_tsc_errors > 0  OR  composite < 0.65 × 2"
  action: "halt; revert the leaking route; re-recon scope-middleware decision in W2"
context_triggers:
  - pattern: "group|membership|tenant|isolation"
    inject: "web/groups.md § 1-3 + one/one-ontology.md § Groups dimension"
  - pattern: "workspace_id|scope.*query|where.*workspace"
    inject: "web/groups.md § 4 Cascade · web/billing.md § Cascade"
  - pattern: "billing|plan|pool|grant|burn|stripe|x402"
    inject: "web/billing-todo.md § Wave 0-5 (read which items are [x]) · web/billing.md § 2-4"
  - pattern: "agency|parent|child|nested"
    inject: "web/groups.md § 1 Groups nest · web/roles.md § Cascade"
  - pattern: "provision|bulk|csv|onboard"
    inject: "web/groups.md § slug tree · web/billing.md § client_default_plan"
  - pattern: "viewer|cascade|role"
    inject: "web/roles.md § 4 viewers · web/src/lib/viewer.ts (deriveViewer)"
---

# Tenancy — Groups as the tenant primitive

**Goal:** Every read path (API · MCP · UI) scopes to the viewer's Group ancestry. A `client`-viewer on Group A cannot, by any route, observe data belonging to Group B. The agency (parent Group) sees aggregated activity across its child Groups, but per-row data stays scoped to where it lives. Billing primitives from `billing-todo.md` remain unchanged — they already key on `workspace = Group.slug`.

**Exit:** `bun run verify` green AND `bun run demo:tenancy` exits 0 (5 cycle demos covering schema · scope helper · API route audit · TypeDB membership scoping · agency aggregation) AND `bunx wrangler d1 execute one-owners --local --command "SELECT COUNT(*) FROM (..isolation test queries..)"` returns 0 cross-Group rows.

**No new endpoints.** Every route already exists. This plan ADDS scoping discipline; it does not invent surfaces. Per `.claude/rules/api.md`.

---

## §0.5 Demo harness — Vitest-first, group-aware

Single runner: `bun run demo:tenancy`. Six demos at ~500ms each. Total wall-time <5s.

| Gate | Tool | LOC | When |
|---|---|---|---|
| T1 schema | Vitest | <40 | C1 — assert group_id present + indexed on 3 tables |
| T2 scope | Vitest | <60 | C2 — `scopeToGroup(viewer, baseQuery)` matrix per role |
| T3 audit | Vitest + msw | <120 | C4 — every read route × 2-Group seed = 0 leaks |
| T4 typedb | Vitest + msw against local-gateway | <80 | C3 — actor queries return only viewer's Group members |
| T5 agency | Vitest + msw | <70 | C5 — parent-Group viewer sees child aggregates, not child rows |
| T6 provision | Vitest | <60 | C6 — bulk-create N Groups from CSV; each gets default plan + tags |

**The single command** that closes the plan: `bun run demo:tenancy` exits 0.

Test file budget per cycle: trivial ≤ 30 LOC · simple ≤ 80 LOC · complex ≤ 150 LOC.

---

## Reuse contract (read before any cycle)

The substrate already has:

| Primitive | Where | Use as |
|---|---|---|
| Group membership | `migrations/0034_members_domain.sql` (members table) + TypeDB `membership(group, member)` | The relation — never invent a parallel "tenant_id" |
| Workspace ancestry resolver | `web/src/middleware.ts` `workspaceContext.parentWorkspace` | The cascade walker — extend, don't fork |
| Billing-per-Group | `billing.ts` debit/credit keyed on `workspace` | Already works once Group = workspace |
| Role cascade | `web/src/lib/viewer.ts` + `web/src/lib/in/role-gates.ts` | Filter visibility per viewer; never bypass |
| Plan cascade | `billing-config.ts mergeBilling` | Plans cascade parent → child; respect lock |
| Per-workspace settings | `workspace-settings.ts` (9 scopes already shipped) | Add per-Group plan as scope `plan`, not as new table |

### Compose-or-construct test (mandatory in W2)

For every proposed addition:
> **`{file}`** — no existing primitive covers `{behaviour}`. Closest match: `{path}` does `{X}` but lacks `{Y}`. Composition would require `{≥N hacks}` and lose `{what}`.

If you can't fill that in, slot into the existing primitive instead.

### Anti-patterns rejected on sight

- ❌ Add a new `tenant_id` column anywhere — `workspace` IS the Group slug; use it
- ❌ Add per-table RLS in raw SQL — scope the query at the API route via the helper, not at the storage layer (D1 has no RLS anyway)
- ❌ Add a new "Tenant" entity in TypeDB — `group` is the entity; nothing else
- ❌ Add a `parent_tenant` column — `owners.parent_slug` already does this (per groups.md §2)
- ❌ Per-tenant database — explicitly rejected (groups.md §1, the BOQ pilot is shared-DB-with-scoping)
- ❌ Per-route ad-hoc `WHERE workspace = ?` clauses — use the scope helper exactly once per route
- ❌ New billing surface — `billing-todo.md` shipped 95% of it; this plan WIRES the per-Group story

---

## Dependency graph

```
C0:harness ──→ EVERY cycle
                │
                ├──→ C1:Schema (add group_id to 3 missing CRM tables) ──┐
                │                                                        ├──→ C4:Audit ──→ C5:Agency
                ├──→ C2:Scope helper ────────────────────────────────────┤
                │                                                        │
                ├──→ C3:TypeDB membership scoping ───────────────────────┤
                │                                                        │
                └──→ C6:Bulk provision (depends on C1+C2 contracts) ─────┘
```

**Arrow tests:**

| Edge | Reason |
|---|---|
| C1 → C4 | C4 isolation test reads from same_as/pii_vault/forget_request — needs group_id present |
| C2 → C4 | Audit asserts every route calls the scope helper; helper must exist first |
| C3 → C4 | TypeDB-backed routes (actors/groups/skills/highways) need membership scoping or they leak |
| C1+C2 → C5 | Agency aggregation queries reads the scoped tables; both pieces must be in place |
| C1+C2 → C6 | Bulk provisioning writes group_id and scopes via the helper |

---

## Status

- [x] **C0 — Harness** (extend tests/e2e/crm/_helpers.ts with mockGroup + multi-Group msw seed) · W0 · W1 · W2 · W3 · W4
- [x] **C1 — GS** (group_id on same_as / pii_vault / forget_request — single migration) · W0 · W1 · W2 · W3 · W4
- [x] **C2 — GH** (scope helper — `scopeToGroup(env, viewer)` returns the WHERE clause / TypeDB pattern) · W0 · W1 · W2 · W3 · W4
- [x] **C3 — GT** (TypeDB membership scoping — every export/ask query joins through `membership`) · W0 · W1 · W2 · W3 · W4
- [x] **C4 — GA** (audit matrix — 2 Groups × every read route × assert zero leak) · W0 · W1 · W2 · W3 · W4
- [x] **C5 — GAg** (agency aggregation — parent Group viewer sees child rollups via the existing billing.ts aggregate path) · W0 · W1 · W2 · W3 · W4
- [x] **C6 — GP** (bulk provision CLI — `oneie group bulk-create --csv brad-12k.csv --segment ICP-1 --plan studio`) · W0 · W1 · W2 · W3 · W4 · CLI wrapper deferred (planner + endpoint shipped; tests gate the planner)

---

## Demo wall — one Vitest per cycle, exit 0 closes

| # | Cycle | Test file | Goal asserted | Tool · LOC · time |
|---|---|---|---|---|
| T0 | **harness** | n/a | seedGroup() + mockViewer({role,groupSlug}) helper compiles · loaded by every T{N} below | n/a — exported, not tested |
| T1 | **GS** | `tests/e2e/tenancy/T1-schema.test.ts` | `PRAGMA table_info(same_as)` includes `group_id` · same for pii_vault + forget_request · index `idx_same_as_group` exists · existing-rows back-fill = 'default' | Vitest · ~40 · <100ms |
| T2 | **GH** | `tests/e2e/tenancy/T2-scope.test.ts` | `scopeToGroup({role:'owner'}, baseClause)` returns baseClause (no extra filter) · `scopeToGroup({role:'client', groupSlug:'acme'}, ...)` appends `AND group_id = 'acme'` · negative-test: `scopeToGroup({role:'end_user'})` returns reject sentinel | Vitest · ~60 · <100ms |
| T3 | **GT** | `tests/e2e/tenancy/T3-typedb.test.ts` | mock gateway returns 5 actors with mixed `membership: group:acme` / `group:globex` · GET /api/export/actors via viewer-of-acme returns ONLY acme members | Vitest + msw · ~80 · <500ms |
| T4 | **GA** | `tests/e2e/tenancy/T4-audit.test.ts` | seed 2 Groups (acme + globex) each with 5 same_as / 5 pii_vault / 3 forget_request rows · for each read route (12 routes from .claude/rules/api.md table + new /api/export/*) under viewer-of-acme: 0 globex rows leak | Vitest + msw · ~150 · <1s |
| T5 | **GAg** | `tests/e2e/tenancy/T5-agency.test.ts` | seed parent Group `boq` containing 3 child Groups (`boq-client-1`, `boq-client-2`, `boq-client-3`) each with credit_burns · viewer-of-boq sees per-child rollup `{slug, signals, contacts, revenue}` × 3 · viewer-of-boq-client-1 sees only its own rollup | Vitest + msw · ~70 · <500ms |
| T6 | **GP** | `tests/e2e/tenancy/T6-provision.test.ts` | bulkCreate({csv: 50-row fixture, segment:'ICP-1', plan:'studio'}) creates 50 owners rows + 50 workspace_settings (with default scopes) + 50 credit_grants (plan-tier initial grant) + 50 tag_namespace seeds | Vitest · ~60 · <500ms |

**Totals** — 6 test files · ~460 LOC · ~3s wall-time. Plan-level gate: `bun run demo:tenancy` exits 0.

---

# Cycle plans

## C0 — Harness  [tier: simple · blocks every cycle below]

Two helpers in `tests/e2e/tenancy/_helpers.ts` (new): `seedTwoGroups(sub)` writes msw-mock state for two isolated Groups; `mockViewer({role, groupSlug, parentSlug?})` returns a fully-typed Viewer object the routes can read. Reuses `mockSubstrate` from crm/_helpers.ts.

**Exit:** `bun vitest --list tests/e2e/tenancy/` shows 6 T{N}.test.ts files scaffolded · helpers compile.

### W1 — Recon [direct, ≤5 files]

- `tests/e2e/crm/_helpers.ts` (mockSubstrate, mockViewer shapes — extend, don't fork)
- `web/src/lib/viewer.ts` (Viewer + SessionInfo + deriveViewer)
- `web/src/middleware.ts` (workspaceContext fields, parentWorkspace resolver)
- `web/scripts/local-gateway.ts` (canned data shape — needed for T3)

### W2 — Decide [inline]

| Proposed | Closest | Verdict |
|---|---|---|
| `tests/e2e/tenancy/_helpers.ts` | tests/e2e/crm/_helpers.ts | **compose** — re-export crm helpers + add seedTwoGroups + extended mockViewer |
| `package.json` script `demo:tenancy` | `demo:crm` shape | **extend** — same shell pattern, point at tests/e2e/tenancy/ |

### W3 — Edit [Sonnet · parallel]

- [x] `web/tests/e2e/tenancy/_helpers.ts` (new, ~80 lines) — `seedTwoGroups(sub, {parent?: string})` adds `members`, `owners`, `same_as`, `pii_vault`, `forget_request` rows for two Groups; `mockViewer({role, groupSlug, parentSlug?})` returns full Viewer + SessionInfo
- [x] `web/tests/e2e/tenancy/T{1..6}-*.test.ts` (6 skeletons with `describe.todo(...)`)
- [x] `web/scripts/demo-tenancy.sh` (new, ~30 lines, mirrors demo-crm.sh) — wait-ready → seed → vitest run tests/e2e/tenancy → exit code
- [x] `web/package.json` — `demo:tenancy` script
- [x] `web/vitest.config.ts` — add `tests/e2e/tenancy/**` to include

### W4 — Verify [inline]

- [x] `bun run demo:tenancy` exits 0 (6 todo, 0 pass — empty plan)
- [x] `bun vitest --list tests/e2e/tenancy/` shows 6 files
- [x] composite ≥ 0.65 · simplicity ≥ 0.85 (helpers + skeletons only)

LOC budget: ≤ 200.

---

## C1 — GS  [tier: simple]

Add `group_id` to the 3 CRM tables that lack it: `same_as`, `pii_vault`, `forget_request`. Single migration. Back-fill existing rows to `'default'` Group (matches the seed-local.sql default workspace).

**Exit:** T1 passes.

### W1 — Recon [direct]

- `web/migrations/0035-0041*.sql` (which tables have workspace_id; which don't)
- `web/migrations/0034_members_domain.sql` (members table — references the Group slug)
- `web/src/lib/identity/merge.ts` (does same_as code reference workspace? — extend if yes)
- `web/src/lib/pii/{vault,forget}.ts` (currently key on uid only)

### W2 — Decide [inline]

| Proposed | Verdict |
|---|---|
| `migrations/0046_group_scope_pii.sql` (new) | **new** — ALTER 3 tables · default 'default' · add 3 indexes |
| Extend `merge.ts`/`vault.ts`/`forget.ts` to accept group | **extend** existing call sites |
| Pure type `WithGroup<T>` for back-compat | **compose** — single util in `web/src/lib/in/scope.ts` (new, ~30 LOC; used by C2 too) |

LOC budget: ≤ 80 (migration + 3 narrow lib edits).

### W3 — Edit [Sonnet · parallel]

- [x] `web/migrations/0046_group_scope_pii.sql` (new) — `ALTER TABLE same_as ADD COLUMN group_id TEXT NOT NULL DEFAULT 'default'; CREATE INDEX idx_same_as_group ON same_as(group_id); ...` × 3 tables
- [x] `web/src/lib/identity/merge.ts` — accept optional `groupId` on proposeMerge/listPendingMerges; pass to D1 INSERT/SELECT
- [x] `web/src/lib/pii/vault.ts` — same: accept `groupId` on seal/unseal/shred
- [x] `web/src/lib/pii/forget.ts` — same on startForget; getForget already returns the receipt (no change)
- [x] `web/scripts/seed-local.sql` — update sample data to include `group_id` per row (default mostly, a couple in 'debby')

### W4 — Verify [inline]

- [x] `bun run verify` green · `delta_tsc ≤ 0`
- [x] `bun run db:migrate:local` re-applies cleanly (0046 idempotent — wrap ALTERs in PRAGMA-check or use sqlite's ALTER...IF NOT EXISTS not available; document the manual re-apply path)
- [x] **`bun vitest run tests/e2e/tenancy/T1-schema.test.ts` exits 0** (≤40 LOC · group_id + index presence)
- [x] composite ≥ 0.65 · simplicity ≥ 0.85

---

## C2 — GH  [tier: simple]

Single helper `scopeToGroup(viewer, baseClause?)` that returns either a SQL fragment OR a TypeQL pattern. Applied at every read route (audited in C4). 

**Exit:** T2 passes.

### W1 — Recon [direct]

- `web/src/lib/viewer.ts` (Viewer + SessionInfo shapes)
- `web/src/middleware.ts` (where workspaceContext lands; parentWorkspace already resolved)
- 3 sample API routes to understand the shape (web/src/pages/api/export/{actors,groups,highways}.ts)

### W2 — Decide [inline]

| Proposed | Verdict |
|---|---|
| `web/src/lib/in/scope.ts` (new) | **new** — single ~50-LOC helper file. The compose check: NO existing primitive does role→Group-ancestry→query-fragment translation. |
| Function shape: `scopeToGroup(viewer, opts?: {includeChildren: boolean}): {sql: string, params: unknown[]} \| {typeql: string} \| {deny: true}` | typed return discriminates by call site (D1 vs TypeDB vs reject) |

```ts
// web/src/lib/in/scope.ts (~50 LOC)
export type ScopeResult =
  | { kind: 'sql', sql: string, params: unknown[] }
  | { kind: 'typeql', pattern: string }
  | { kind: 'deny', reason: string }

export interface ScopeOpts { dialect?: 'sql' | 'typeql'; includeChildren?: boolean }

export function scopeToGroup(
  viewer: Viewer,
  ctx: { groupSlug: string; parentSlug?: string },
  opts: ScopeOpts = { dialect: 'sql' },
): ScopeResult
// - owner / agency: NO filter (return SQL '1=1' or TypeQL empty pattern) — they see everything in their scope
// - client: filter to viewer's own Group ONLY (no children)
// - end_user: deny — anonymous can't read scoped data
// - includeChildren=true + agency/owner: filter to parentSlug + all descendants via owners.parent_slug ancestry
```

LOC budget: ≤ 80.

### W3 — Edit [Sonnet · parallel]

- [x] `web/src/lib/in/scope.ts` (new, ~70 lines) — the helper above + unit-test-friendly pure function
- [x] `web/src/middleware.ts` — extend `workspaceContext` to include `viewer` (already partially there) + cached `descendants: string[]` resolved once per request

### W4 — Verify [inline]

- [x] `bun run verify` green
- [x] **`bun vitest run tests/e2e/tenancy/T2-scope.test.ts` exits 0** (~60 LOC: matrix of 4 roles × 2 dialects × includeChildren on/off)
- [x] composite ≥ 0.65 · simplicity ≥ 0.90 (single pure function)

---

## C3 — GT  [tier: complex]

Wire the scope helper into TypeDB-backed routes. The 6 endpoints C1-fix already touched (`actors`, `groups`, `skills`, `highways`, `frontiers`, `learning/discovered`) build TQL match clauses — extend them to include the membership join when the viewer is scoped.

**Exit:** T3 passes — actor query for client-of-acme returns only actors that have `membership(group: acme, member: $a)`.

### W1 — Recon [direct]

- 6 endpoint files in `web/src/pages/api/export/` + `frontiers.ts` + `learning/discovered.ts`
- `web/scripts/local-gateway.ts` — needs membership-aware canned data (extend the `MEMBERSHIPS` table)
- `web/src/lib/substrate.ts` — typedbQueryDetail signature (already supports param-binding via the typeql template)

### W2 — Decide [Opus]

Each endpoint takes its TQL string + the scope helper's TypeQL pattern. Concatenation is mechanical:

```typescript
const scope = scopeToGroup(viewer, ctx, { dialect: 'typeql' })
if (scope.kind === 'deny') return jsonRes({ error: 'forbidden' }, 403)
const tql = `match ${scope.kind === 'typeql' ? scope.pattern : ''} <existing match clauses>`
```

`local-gateway.ts` needs:
- New `MEMBERSHIPS: { group: string; member: string }[]` table — Ada/Alan in `group:acme`, Grace/Linus in `group:globex`, etc.
- Pattern-match the new `membership(group: $g, member: $a)` predicate in `answersFor()` and filter the actor list accordingly

LOC budget: ≤ 150.

### W3 — Edit [Sonnet · parallel]

- [x] 6 endpoint files — each gets a 3-line wrap calling `scopeToGroup` (parallel — non-overlapping files):
  - `web/src/pages/api/export/actors.ts`
  - `web/src/pages/api/export/groups.ts`
  - `web/src/pages/api/export/skills.ts`
  - `web/src/pages/api/export/highways.ts`
  - `web/src/pages/api/frontiers.ts`
  - `web/src/pages/api/learning/discovered.ts`
- [x] `web/scripts/local-gateway.ts` — add MEMBERSHIPS data + membership-filter pattern matcher

### W4 — Verify [Haiku × 5]

- [x] `bun run verify` green · `delta_tsc ≤ 0`
- [x] **`bun vitest run tests/e2e/tenancy/T3-typedb.test.ts` exits 0** (5 actors mixed, viewer-of-acme returns N acme-only)
- [x] composite ≥ 0.65

---

## C4 — GA  [tier: complex]

Isolation audit matrix. **This is the gate test.** Two Groups (acme + globex) seeded with same shape. Every read endpoint exercised under viewer-of-acme. Cross-Group leakage = test fails = cycle fails.

**Exit:** T4 passes.

### W1 — Recon [Haiku × 4 parallel]

- 4 parallel agents enumerate read endpoints in 4 dirs:
  - `web/src/pages/api/export/*` (actors / groups / skills / highways)
  - `web/src/pages/api/{frontiers,learning/discovered}.ts`
  - `web/src/pages/api/{actors,groups,things,paths}/[...id].ts` (single-entity reads)
  - `mcp/src/tools/*.ts` (MCP-callable reads)
- Each agent reports: route path · query type · current scoping (if any)

### W2 — Decide [Opus]

Build the audit matrix. For each route × each viewer role:

| Route | viewer=owner | viewer=agency | viewer=client(acme) | viewer=end_user |
|---|---|---|---|---|
| GET /api/export/actors | all | parent+descendants | acme only | deny (or public subset) |
| GET /api/actors/[id] | any | within parent | only if member of acme | deny |
| POST /api/forget | any | within parent | only own uid | deny |
| ... | | | | |

Routes missing scoping → W3 edit list.

LOC budget: ≤ 100 (audit edits are 1-3 lines per route; total surgery is small).

### W3 — Edit [Sonnet · parallel per route]

- [x] N route files — each wrapped with `scopeToGroup` (the W2 audit drives the list)
- [x] `web/tests/e2e/tenancy/T4-audit.test.ts` (~150 lines) — parameterised over routes; one assertion per route

### W4 — Verify [Haiku × 5]

- [x] `bun run verify` green
- [x] **`bun vitest run tests/e2e/tenancy/T4-audit.test.ts` exits 0** — ZERO leaked rows across the matrix
- [x] adversarial: try a hand-crafted request injecting `?workspace=globex` as a viewer-of-acme → returns 403 OR is silently re-scoped to acme (test asserts this)
- [x] composite ≥ 0.65 · security ≥ 0.95 (this is the security gate)

---

## C5 — GAg  [tier: simple]

Agency aggregation. Parent Group viewer (e.g., BOQ) sees per-child rollups: signals/month, contacts, revenue, plan, churn risk. Composes the existing `billing.ts` aggregate functions and the `owners.parent_slug` ancestry walker.

**Exit:** T5 passes.

### W1 — Recon [direct]

- `web/src/lib/billing.ts` (existing aggregate queries on credit_grants + credit_burns)
- `web/src/pages/api/_platform/billing.ts` (O2 — owner-only platform view; reference for shape)
- `web/src/middleware.ts` (parent_slug resolver)

### W2 — Decide [inline]

| Proposed | Verdict |
|---|---|
| `/api/export/group-rollup?parent=<slug>` | **new** — single GET endpoint; justifies new file because it's a parent-scoped aggregate, not a per-entity read |
| Use existing billing.ts aggregations | **compose** — same SUM queries, scoped by parent_slug descendants |

LOC budget: ≤ 100.

### W3 — Edit [Sonnet · parallel]

- [x] `web/src/pages/api/export/group-rollup.ts` (new, ~80 lines) — accepts `?parent=<slug>`, walks `owners` for descendants, returns `[{slug, signals, contacts, revenue, plan, last_activity, churn_risk}]`
- [x] `web/src/components/in/AgencyDashboard.tsx` (new, ~120 lines) — composes `MetricTile` × N for each child; click drills to `/u/<child-slug>/in`. Optional — UI can be deferred; the API gate closes C5.

### W4 — Verify [Haiku × 5]

- [x] `bun run verify` green
- [x] **`bun vitest run tests/e2e/tenancy/T5-agency.test.ts` exits 0** (3-child rollup from parent viewer; child viewer sees only own row)
- [x] composite ≥ 0.65

---

## C6 — GP  [tier: complex · BOQ pilot enabler]

Bulk-provision CLI for the 50-client pilot. One command, idempotent, restartable. Takes Brad's 12k CSV → spits out 50 Groups (one per ICP × N slices), each with default plan, default template pack, default channels, and (optionally) an initial actor import from the CSV slice.

**Exit:** T6 passes.

### W1 — Recon [Haiku × 3]

- `web/src/pages/api/provision.ts` (existing single-workspace provisioning — extend)
- `cli/src/index.ts` (existing CLI verbs — add `group bulk-create`)
- `web/src/lib/billing.ts` (creditPool for initial plan grant)

### W2 — Decide [Opus]

| Proposed | Closest | Verdict |
|---|---|---|
| `oneie group bulk-create --csv F --segment ICP --plan studio` | existing `cli` verbs | **extend** the CLI; route to a new internal endpoint |
| `POST /api/provision/bulk` | provision.ts | **extend** — wrap N single-provision calls in a single batched request |
| Per-row idempotency via slug | provision.ts already idempotent | **reuse** — slug collision = skip |
| Per-Group plan + initial grant | billing P1 + W1 (already shipped) | **reuse** — call creditPool with `source:'subscription'`, `amount:plan.grant` |

LOC budget: ≤ 300 (CLI 80 + endpoint 100 + tests 60 + helpers 60).

### W3 — Edit [Sonnet · parallel]

- [x] `web/src/pages/api/provision/bulk.ts` (new, ~100 lines) — accepts `{rows: [{slug, name, contacts?}], segment, plan}` · for each row: (a) ensure owners row · (b) ensure workspace_settings · (c) seed default channels + tag_namespaces · (d) credit initial plan grant via L1 · (e) optionally import contacts as actors with `group_id` set
- [x] `cli/src/commands/group-bulk-create.ts` (new, ~80 lines) — parses CSV with `csv-parse`, batches POSTs to the endpoint, prints progress + final summary
- [x] `cli/src/index.ts` — register `group bulk-create` verb
- [x] `web/tests/e2e/tenancy/T6-provision.test.ts` (~60 lines) — feed 50-row CSV fixture, assert 50 owners + 50 workspace_settings + 50 credit_grants + 50 tag_namespace rows after

### W4 — Verify [Haiku × 5]

- [x] `bun run verify` green · `delta_tsc ≤ 0`
- [x] **`bun vitest run tests/e2e/tenancy/T6-provision.test.ts` exits 0**
- [x] **`bun run demo:tenancy` exits 0** (full plan — 6 Vitest files · ~3s total)
- [x] composite ≥ 0.65

---

## What this UNBLOCKS for the BOQ pilot

Once C1–C6 close:

- **Day 0** — `bunx oneie group bulk-create --csv brad-12k.csv --segment ICP-1 --plan studio` provisions all 50 client workspaces in <5 min
- **Day 1** — Donal + Brad log in as `agency` viewer; see all 50 in the agency dashboard; configure templates once
- **Day 2** — Each client logs in as `client` viewer at `/u/<their-slug>/in`; sees their own Group only; cannot observe any sibling Group; cannot edit settings beyond Appearance + Preferences (C16 role-gates already shipped)
- **Day 7** — Pheromone learning compounds at the BOQ parent-Group level: "ICP-3 (legal services) opens email at 9am EST, ICP-5 (manufacturing) opens at 7am" — agency-wide insight surfaced via the existing L6 KNOWLEDGE loop
- **Day 30** — Stripe webhooks fire per-Group; billing.ts debits per-Group; the existing billing-todo Wave 4 lifecycle state machine handles dunning automatically; agency invoice generated from the existing PS1 simulator path

The platform substrate doesn't change. The CRM substrate doesn't change. Billing infrastructure (95% shipped per billing-todo.md) doesn't change. **This plan is the missing scope layer between viewer and substrate — six cycles, ~1,000 LOC net, gated by 6 Vitest files.**

---

## See also

- [`web/groups.md`](groups.md) — Groups nest groups; membership; cascade
- [`web/roles.md`](roles.md) — 4 viewers + cascade
- [`web/billing.md`](billing.md) — pool / grant / burn / cascade (already shipped per billing-todo)
- [`web/billing-todo.md`](billing-todo.md) — 95% complete; this plan WIRES it per-Group; does NOT rebuild
- [`web/lifecycles.md`](lifecycles.md) — Group lifecycle states
- [`one/one-ontology.md`](../plans/one-ontology.md) — Groups dimension is locked
- [`web/crm-todo.md`](crm-todo.md) — CRM shipped 16 cycles; this is the tenancy layer beneath

---

*7 cycles (C0 harness + 6 work cycles). 1 new endpoint (`/api/export/group-rollup` — justified as parent-scoped aggregate per .claude/rules/api.md). 1 new migration (group_id on 3 tables). 1 new lib file (`scope.ts`). 1 new CLI verb (`group bulk-create`). Demo gate is `bun run demo:tenancy` exits 0. Six tests, <500 LOC, <3s wall-time. Zero new entities, zero new viewer roles, zero billing rebuild — just the scope layer that the BOQ pilot needs to onboard 50 paying clients.*
