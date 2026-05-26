---
title: Dashboard — operator + portfolio views with beautiful funnels
slug: dashboard
type: plan
tier: complex
mode: construction
tags: [dashboard, analytics, agency, portfolio, funnel, charts]

goal: "Owners see most-important business info at a glance on /u/{slug}/dashboard; agency owners get a portfolio view of all client businesses with drill-down to each."
outcome: "cd one.ie/web && bun run verify && bun vitest run tests/e2e/dashboard-portfolio.test.ts tests/e2e/dashboard-operator.test.ts"
outcome_asserts: "Both dashboard views render with real data — operator view shows the 6-stage lifecycle funnel from agent_events_warm; portfolio view shows a per-client card grid with status, sparkline, and drill-in link."

deliverables:
  - route: /u/{slug}/dashboard — operator view (client company) with real lifecycle funnel promoted from /analytics — owns C2
  - route: /u/{slug}/dashboard — portfolio view (agency owner) with per-client card grid — owns C4
  - component: web/src/components/dashboard/ClientCard.tsx — single-client card (status dot · sparkline · heat strip · drill-in) — owns C3
  - component: web/src/components/dashboard/MiniFunnel.tsx — small-multiples mini-funnel for per-client funnel grid — owns C3
  - lib: web/src/lib/dashboard/queries.ts — extended with fetchPortfolio(parentSlug) aggregating across child workspaces — owns C1
  - lib: web/src/lib/dashboard/detect-view.ts — chooses operator|portfolio from owners.parent_slug + plan — owns C1
  - delete: web/src/components/dashboard/FunnelRibbon.tsx — superseded by LifecycleFunnel — owns C5
  - doc: plans/dashboard.md — spec (already written, kept in sync with W3) — owns C5

ux_before: "Owners land on a generic persona dashboard with synthetic funnel ribbon and no view of their child clients; they must visit /analytics, /clients, /in separately to assemble the picture."
ux_after: "Owners land on a dashboard that auto-shapes to their role — client-company owners see their real lifecycle funnel + hot accounts + inbox triage in one view; agency owners see a portfolio grid of every client with status colour, sparkline, and one-click drill-in."
ux_delta: "Three separate page visits collapse into one dashboard load; agency owners gain a portfolio view that does not exist today."

parallel_budget:
  haiku:   12
  sonnet:  8
  opus:    2

batches:
  - [C1]
  - [C2, C3]
  - [C4]
  - [C5]

shared_recon:
  - one.ie/web/src/pages/u/[slug]/dashboard.astro
  - one.ie/web/src/pages/u/[slug]/analytics.astro
  - one.ie/web/src/pages/u/[slug]/clients.astro
  - one.ie/web/src/pages/u/[slug]/agencies/index.astro
  - one.ie/web/src/pages/u/[slug]/in.astro
  - one.ie/web/src/lib/dashboard/queries.ts
  - one.ie/web/src/components/dashboard/Dashboard.tsx
  - plans/dashboard.md

source_of_truth:
  - plans/dashboard.md
  - one.ie/web/src/lib/dashboard/types.ts
  - one.ie/web/src/lib/dashboard/queries.ts
  - one.ie/web/src/components/funnel/LifecycleFunnel.tsx
  - one.ie/web/src/components/dashboard/Dashboard.tsx

existing_primitives:
  - one.ie/web/src/components/funnel/LifecycleFunnel.tsx: real 6-stage funnel — C2 promotes to dashboard, C4 aggregates
  - one.ie/web/src/components/dashboard/Sparkline.tsx: tiny line chart — C3 reuses per client card
  - one.ie/web/src/components/dashboard/AccountHeatStrip.tsx: 7-day activity squares — C3 reuses per client card
  - one.ie/web/src/components/dashboard/HotAccounts.tsx: ranked accounts by signal weight — C2 keeps in operator view
  - one.ie/web/src/components/dashboard/RankedList.tsx: ranked list with sparkline — C2 keeps for top channels/agents
  - one.ie/web/src/components/dashboard/DashboardHeader.tsx: persona tabs + workspace switcher — C2 extends with date-range picker
  - one.ie/web/src/lib/dashboard/queries.ts: fetchDashboard + fetchViewerTitle — C1 extends with fetchPortfolio
  - one.ie/web/src/lib/slug.ts: getSlugOwner + resolveIdentity — C1 reuses for child workspace discovery

show: true

escape:
  condition: "C4 W4 fails delta_tsc > 0 twice OR portfolio query >2s on test fixture"
  action: "halt C4; re-scope to defer per-client mini-funnels to a follow-up cycle"

context_triggers:
  - pattern: "viewer\\s*===?\\s*['\"](agency|owner|client|end_user)"
    inject: "plans/dictionary.md § Viewer roles"
  - pattern: "agent_events_warm"
    inject: "one.ie/web/migrations § agent_events_warm schema"
---

# Dashboard — two views, beautiful funnels, one route

## Goal, outcome, deliverables, UX

### Goal

Owners see the most-important business info at a glance on `/u/{slug}/dashboard`; agency owners get a portfolio view of every client business with drill-down to each.

### Outcome (the kill-switch)

```bash
cd one.ie/web && bun run verify && bun vitest run tests/e2e/dashboard-portfolio.test.ts tests/e2e/dashboard-operator.test.ts
```

**What passing proves:** Both dashboard views render with real data. Operator view shows the 6-stage lifecycle funnel sourced from `agent_events_warm`. Portfolio view shows a per-client card grid with status colour, sparkline, and a drill-in link to that client's operator dashboard.

**Contract:** runs after every batch's W4. Plan does not close until exit 0.

### Deliverables

| Kind | Path | What the user sees / can do | Cycle |
|---|---|---|---|
| route | `/u/{slug}/dashboard` (operator) | Real lifecycle funnel + hero KPI + hot accounts + inbox triage in one view | C2 |
| route | `/u/{slug}/dashboard` (portfolio) | Per-client card grid with status, sparkline, drill-in | C4 |
| component | `web/src/components/dashboard/ClientCard.tsx` | One card per client — status dot, hero metric, sparkline, heat strip, drill-in link | C3 |
| component | `web/src/components/dashboard/MiniFunnel.tsx` | Six-bar mini-funnel for the per-client funnel grid | C3 |
| lib | `web/src/lib/dashboard/queries.ts` | `fetchPortfolio(parentSlug)` aggregates across child workspaces | C1 |
| lib | `web/src/lib/dashboard/detect-view.ts` | Pure function chooses `operator` \| `portfolio` from owners + plan | C1 |
| delete | `web/src/components/dashboard/FunnelRibbon.tsx` | Removed — superseded by `LifecycleFunnel` | C5 |
| doc | `plans/dashboard.md` | Spec stays in sync with shipped UI | C5 |

### User experience: before → after

**Client company owner**

|  | Today | After this plan |
|---|---|---|
| **Goal** | "What happened in my business today?" | Same |
| **Steps** | 1. Open `/dashboard` → synthetic ribbon · 2. Open `/analytics` for real funnel · 3. Open `/in` for inbox · 4. Open `/people` for hot accounts | 1. Open `/dashboard` — all four visible |
| **Friction** | 3 extra page loads; synthetic vs real numbers disagree | One page; one date range; one source of truth |
| **Time** | 90s of clicking + reading | 10s glance |

**Agency owner**

|  | Today | After this plan |
|---|---|---|
| **Goal** | "Which client is growing? Which is stuck?" | Same |
| **Steps** | 1. Open `/dashboard` (own metrics only) · 2. Open `/clients` (table, no metrics) · 3. Click each client one by one to assess | 1. Open `/dashboard` — portfolio grid with status colour + sparkline per client · 2. Click the one that needs attention |
| **Friction** | N clicks (one per client); no at-a-glance status | One screen; status colour does the triage |
| **Time** | N × 30s | 5s glance + targeted drill-in |

**ux_delta:** Three separate page visits collapse into one dashboard load; agency owners gain a portfolio view that does not exist today.

**Proof artefact (after-state observable):**

```
GET /u/acme/dashboard (agency owner)  →  HTML containing:
  <main data-view="portfolio">
    <HeroNumber value="12,348 conversions across 14 clients" />
    <LifecycleFunnel ... aggregated />
    <section data-grid="clients">
      <ClientCard slug="brand-a" status="growing" metric="2,103 visitors/wk" />
      <ClientCard slug="brand-b" status="at-risk" metric="↓ 38% wk-over-wk" />
      ...
    </section>
  </main>
```

---

## Reuse contract

### Compose-or-construct verdicts

| Proposed file | Closest primitive | Gap | Verdict |
|---|---|---|---|
| `dashboard/ClientCard.tsx` | `dashboard/HotAccounts.tsx` row | renders one account row, lacks status dot + per-client heat strip composition | **compose** (Sparkline + AccountHeatStrip + status dot — no new primitives) |
| `dashboard/MiniFunnel.tsx` | `funnel/LifecycleFunnel.tsx` | full-width, animated, labelled; wrong shape for small-multiples | **new** (≤60 LOC wrapper — 6 token-tinted divs) |
| `lib/dashboard/queries.ts::fetchPortfolio` | `fetchDashboard` | single-workspace only | **extend** (add fn to existing module) |
| `lib/dashboard/detect-view.ts` | `lib/slug.ts::getSlugOwner` | returns owner row, not view verdict | **new** (≤30 LOC pure fn — keep slug.ts focused on identity) |

Anti-patterns rejected on sight: no new Card primitive (use existing card pattern from `design.md`), no new chart lib, no new funnel primitive (compose `LifecycleFunnel` + `MiniFunnel`).

### Reuse audit (W4 hard gate)

- [ ] All new files in this plan total < 220 LOC
- [ ] `delta_loc_net ≤ -50` (FunnelRibbon deletion + synthetic rightNow removal offsets new components)
- [ ] No reimplementation of `Sparkline`, `AccountHeatStrip`, `LifecycleFunnel`, `Card`, `Icon` (per-cycle grep)

---

## Testing

| Cycle | Demo gate | Tool | Budget |
|---|---|---|---|
| C1 | `bun vitest run tests/unit/detect-view.test.ts tests/unit/fetch-portfolio.test.ts` | Vitest pure + miniflare D1 | ≤80 LOC |
| C2 | `bun vitest run tests/e2e/dashboard-operator.test.ts` | Vitest + @testing-library/react | ≤100 LOC |
| C3 | `bun vitest run tests/unit/client-card.test.ts tests/unit/mini-funnel.test.ts` | Vitest + @testing-library/react | ≤80 LOC |
| C4 | `bun vitest run tests/e2e/dashboard-portfolio.test.ts` | Vitest + @testing-library/react + msw | ≤120 LOC |
| C5 | `grep -r FunnelRibbon one.ie/web/src` returns 0 hits AND `bun run verify` green | bash | ≤20 LOC |

---

## Parallel execution plan

### Cycle DAG

```
       C1 (data layer + view detector)
      ╱  ╲
    C2    C3        ← operator route + new shared components, file-disjoint
      ╲  ╱
       C4 (portfolio route — composes C1+C3 outputs)
        │
       C5 (delete FunnelRibbon + sync plans/dashboard.md)
```

| Arrow | File reason |
|---|---|
| C1 → C2 | C2 imports `detectView` from `web/src/lib/dashboard/detect-view.ts` which C1 creates |
| C1 → C3 | C3's ClientCard prop types reference `PortfolioClient` interface which C1 defines in `lib/dashboard/types.ts` |
| C1 → C4 | C4 calls `fetchPortfolio` from `web/src/lib/dashboard/queries.ts` which C1 adds |
| C3 → C4 | C4 imports `ClientCard` and `MiniFunnel` from files C3 creates |
| C4 → C5 | C5's deletion of `FunnelRibbon` must follow operator+portfolio routes shipping, otherwise type-check breaks |

### Batches

| Batch | Cycles | Notes |
|---|---|---|
| 0 | (shared W0 + W1) | baseline + read of all `shared_recon:` files in one Haiku spawn |
| 1 | C1 | data + view detector — foundation |
| 2 | C2, C3 | operator route + new components run in parallel (file-disjoint) |
| 3 | C4 | portfolio route composes C1 + C3 outputs |
| 4 | C5 | cleanup — delete FunnelRibbon, sync docs |

---

## Status

```
Batch 0 (shared)
  - [x] W0 baseline
  - [x] W1 shared recon

Batch 1
  - [x] C1 — data layer + view detector              state: shipped
    - [x] W1 · W2 · W3 · W4

Batch 2
  - [x] C2 — operator view (real funnel promoted)    state: shipped
    - [x] W1 · W2 · W3 · W4
  - [x] C3 — ClientCard + MiniFunnel components      state: shipped
    - [x] W1 · W2 · W3 · W4
  - [x] demo batch (vitest run c2 + c3 tests)

Batch 3
  - [x] C4 — portfolio view (agency owner)           state: shipped
    - [x] W1 · W2 · W3 · W4

Batch 4
  - [x] C5 — delete FunnelRibbon + doc sync          state: shipped
    - [x] W1 · W2 · W3 · W4

Plan close
  - [x] Outcome command exits 0 (verify=green; e2e operator + portfolio specs both pass)
  - [x] Every deliverable row shipped and reachable
  - [x] Both ux_after journeys walkable (operator + portfolio)
  - [x] Final compress sweep (FunnelRibbon.tsx + narrate-funnel.ts deleted as orphans)
  - [x] Final docs/improvements.md append
  - [x] Plan rubric ≥ 0.65 (composite ≈ 0.85)
```

---

## C1 — Data layer + view detector  [tier: simple · batch: 1]

**Goal delta:** After C1, `fetchPortfolio(parentSlug)` returns aggregated per-child metrics and `detectView(owner)` returns `'operator' | 'portfolio'` — every downstream cycle reads them.

**Deliverable:** `lib: web/src/lib/dashboard/queries.ts (fetchPortfolio)` + `lib: web/src/lib/dashboard/detect-view.ts`.

**UX delta:** Internal-only. Justified because C2 and C4 cannot ship UI without the data shapes this cycle defines.

**Cycle outcome:** `bun vitest run tests/unit/detect-view.test.ts tests/unit/fetch-portfolio.test.ts` exits 0.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bun vitest run tests/unit/detect-view.test.ts tests/unit/fetch-portfolio.test.ts"
  asserts: "detectView returns 'portfolio' when owner.plan='agency' and parent has >=1 child; fetchPortfolio returns one row per child with {slug, status, weeklyDelta, sparkline[]}."
  budget:  "<2s wall · ≤80 LOC test"
```

### W1 — Recon

- [ ] `one.ie/web/src/lib/dashboard/queries.ts` — current `fetchDashboard` shape + D1 access pattern
- [ ] `one.ie/web/src/lib/dashboard/types.ts` — existing `DashboardData` interface, where to add `PortfolioData`
- [ ] `one.ie/web/src/lib/slug.ts` — `getSlugOwner` return shape (does it expose `plan`?)
- [ ] `one.ie/web/src/pages/u/[slug]/agencies/index.astro` — exact SQL for child-workspace query
- [ ] `one.ie/web/src/pages/u/[slug]/clients.astro` — TypeDB hierarchy query for descendants
- [ ] `one.ie/web/migrations/*agent_events*.sql` — `agent_events_warm` column list

### W2 — Decide

- [ ] Compose-or-construct verdict filed (table above)
- [ ] Slot map: `detect-view.ts` is pure — no slot. `fetchPortfolio` slots into existing `queries.ts`.
- [ ] Decide: `PortfolioClient.status` enum — `'growing' | 'flat' | 'at-risk' | 'onboarding' | 'paused'`. Threshold: at-risk = no events in 7d OR weekly delta < −20%.
- [ ] Decide: D1 `IN (?,?,…)` cap = 100. If more children, paginate (defer to follow-up — flag in W4).
- [ ] Diff specs output for `queries.ts`, `types.ts`, new `detect-view.ts`

### W3 — Edit

**W3a:**
- [ ] `one.ie/web/src/lib/dashboard/types.ts` — add `PortfolioClient`, `PortfolioData`, `DashboardView` types
- [ ] `one.ie/web/src/lib/dashboard/detect-view.ts` — NEW pure fn `detectView(owner, childCount) → 'operator' | 'portfolio'`
- [ ] `one.ie/web/src/lib/dashboard/queries.ts` — add `fetchPortfolio({db, parentSlug, rangeFrom, rangeTo})` returning `PortfolioData`
- [ ] `one.ie/web/tests/unit/detect-view.test.ts` — NEW
- [ ] `one.ie/web/tests/unit/fetch-portfolio.test.ts` — NEW (miniflare D1 fixture)

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate exits 0
- [ ] Reuse audit: no reimplementation of `fetchDashboard` patterns
- [ ] `wc -l` new files ≤ 200 total
- [ ] Outcome re-check
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C2 — Operator view (real funnel promoted)  [tier: complex · batch: 2]

**Goal delta:** After C2, a client-company owner opening `/u/{slug}/dashboard` sees the real 6-stage lifecycle funnel + hero KPI + hot accounts + inbox triage on one screen — no need to visit `/analytics`, `/in`, `/people` separately.

**Deliverable:** `route: /u/{slug}/dashboard` (operator branch).

**UX delta:** Three page loads collapse into one.

**Cycle outcome:** `bun vitest run tests/e2e/dashboard-operator.test.ts` exits 0; route returns 200 with a `<LifecycleFunnel>` containing 6 stages sourced from `agent_events_warm`.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bun vitest run tests/e2e/dashboard-operator.test.ts"
  asserts: "Operator view renders LifecycleFunnel with 6 stages, hero number, audience bar, triage chips for unread/alerts; FunnelRibbon does not appear."
  budget:  "<3s wall · ≤100 LOC test"
```

### W1 — Recon

- [ ] `one.ie/web/src/pages/u/[slug]/dashboard.astro` — current entry, `fetchDashboard` usage
- [ ] `one.ie/web/src/components/dashboard/Dashboard.tsx` — composition + persona switch
- [ ] `one.ie/web/src/components/funnel/LifecycleFunnel.tsx` — props + how it's consumed by `/analytics`
- [ ] `one.ie/web/src/pages/u/[slug]/analytics.astro` lines 91-140 — lifecycle stage queries to lift up
- [ ] `one.ie/web/src/pages/u/[slug]/in.astro` — `GET /api/export/all` shape (for triage chips)

### W2 — Decide

- [ ] Compose verdict: LifecycleFunnel slot-in, kill FunnelRibbon usage
- [ ] Slot map: `Dashboard.tsx` band 2 = `<LifecycleFunnel>` + new audience bar div; band 1 keeps `HeroNumber` + `RingTriple` + new triage chips inline
- [ ] Decide: triage chips component or inline? → inline (3 chips, ≤30 LOC; new component is overkill)
- [ ] Decide: extract lifecycle stage queries from `analytics.astro` to `lib/dashboard/queries.ts::fetchFunnel(slug, range)` so both pages share. (Coordinate with C1 — fetchFunnel can also live in C1 if W1 timing aligns.)
- [ ] Diff specs for `Dashboard.tsx`, `dashboard.astro`

### W3 — Edit

**W3a:**
- [ ] `one.ie/web/src/lib/dashboard/queries.ts` — extract `fetchFunnel(db, slug, from, to)` from analytics.astro
- [ ] `one.ie/web/src/pages/u/[slug]/dashboard.astro` — call `detectView` → if operator, fetch dashboard+funnel+inbox-counts; pass to `Dashboard`
- [ ] `one.ie/web/src/components/dashboard/Dashboard.tsx` — replace `<FunnelRibbon>` with `<LifecycleFunnel>`; add audience bar; add triage chips row
- [ ] `one.ie/web/src/pages/u/[slug]/analytics.astro` — call `fetchFunnel` instead of inline stage queries
- [ ] `one.ie/web/tests/e2e/dashboard-operator.test.ts` — NEW

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate exits 0
- [ ] `grep -r FunnelRibbon one.ie/web/src/components/dashboard/Dashboard.tsx` returns 0 hits
- [ ] Reuse audit: `LifecycleFunnel` imported, not reimplemented; no new Card or chart primitive
- [ ] `wc -l` new test ≤ 100
- [ ] Live check: dev server `curl /u/demo/dashboard` returns 200 with `LifecycleFunnel` markup present
- [ ] Outcome re-check
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C3 — ClientCard + MiniFunnel components  [tier: simple · batch: 2]

**Goal delta:** After C3, the two new building blocks for portfolio view exist as testable components with no route wiring. C4 imports and arranges them.

**Deliverable:** `component: ClientCard.tsx` + `component: MiniFunnel.tsx`.

**UX delta:** Internal-only — justified because C4 (visible deliverable) imports both.

**Cycle outcome:** `bun vitest run tests/unit/client-card.test.ts tests/unit/mini-funnel.test.ts` exits 0.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bun vitest run tests/unit/client-card.test.ts tests/unit/mini-funnel.test.ts"
  asserts: "ClientCard renders status dot in correct token colour, embeds Sparkline + AccountHeatStrip, links to /u/{slug}/dashboard; MiniFunnel renders 6 bars proportioned to counts."
  budget:  "<2s wall · ≤80 LOC test"
```

### W1 — Recon

- [ ] `one.ie/web/src/components/dashboard/Sparkline.tsx` — props + sizing
- [ ] `one.ie/web/src/components/dashboard/AccountHeatStrip.tsx` — props for 7-day shape
- [ ] `one.ie/web/src/components/dashboard/HotAccounts.tsx` — existing card row pattern to mirror
- [ ] `one.ie/web/src/components/funnel/LifecycleFunnel.tsx` — confirm too heavy for small-multiples (justifies MiniFunnel)
- [ ] `.claude/rules/design.md` — card pattern (header/body/footer; bg-background outer, bg-foreground inner)

### W2 — Decide

- [ ] Compose verdicts (table above)
- [ ] Slot map: ClientCard outer = `<article bg-background>`; body = composed Sparkline + AccountHeatStrip; footer = drill-in link
- [ ] Decide: status dot — 3 token colours: `tertiary` (growing) / `secondary` (flat) / `destructive` (at-risk). Matches `.claude/rules/design.md`.
- [ ] Decide: MiniFunnel widths — % of max stage (clearest at-a-glance)
- [ ] Diff specs for both new files + their tests

### W3 — Edit

**W3a:**
- [ ] `one.ie/web/src/components/dashboard/ClientCard.tsx` — NEW (≤80 LOC)
- [ ] `one.ie/web/src/components/dashboard/MiniFunnel.tsx` — NEW (≤60 LOC)
- [ ] `one.ie/web/tests/unit/client-card.test.ts` — NEW
- [ ] `one.ie/web/tests/unit/mini-funnel.test.ts` — NEW

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate exits 0
- [ ] Reuse audit: Sparkline + AccountHeatStrip imported, not reimplemented; no hex literals; no `text-zinc-*`; `emitClick` on the drill-in link
- [ ] `wc -l ClientCard.tsx MiniFunnel.tsx` ≤ 150 combined
- [ ] Outcome re-check
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C4 — Portfolio view (agency owner)  [tier: complex · batch: 3]

**Goal delta:** After C4, an agency owner opening `/u/{slug}/dashboard` sees a per-client card grid with status colour, sparkline, and a drill-in to each client's operator dashboard — replacing N separate `/clients` clicks.

**Deliverable:** `route: /u/{slug}/dashboard` (portfolio branch).

**UX delta:** Agency owner gains a view that does not exist today.

**Cycle outcome:** `bun vitest run tests/e2e/dashboard-portfolio.test.ts` exits 0; route returns 200 with `data-view="portfolio"` and ≥1 `<ClientCard>`.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bun vitest run tests/e2e/dashboard-portfolio.test.ts"
  asserts: "Portfolio view renders aggregate hero + aggregate LifecycleFunnel + client grid (one ClientCard per child) sorted at-risk-first; drill-in link href is /u/{child-slug}/dashboard."
  budget:  "<3s wall · ≤120 LOC test"
```

### W1 — Recon

- [ ] `one.ie/web/src/pages/u/[slug]/dashboard.astro` (post-C2) — operator branch already in place
- [ ] `one.ie/web/src/pages/u/[slug]/clients.astro` — TypeDB hierarchy query shape (already a primitive)
- [ ] `one.ie/web/src/components/dashboard/Dashboard.tsx` (post-C2) — where to branch on view
- [ ] `one.ie/web/src/lib/dashboard/queries.ts` (post-C1) — `fetchPortfolio` signature

### W2 — Decide

- [ ] Compose verdict: Portfolio renders inside same `Dashboard.tsx` via `view` prop branch (avoids prop drilling, persona tabs reusable)
- [ ] Slot map: portfolio band 1 = `HeroNumber` (aggregate) + `RingTriple` (3 portfolio KPIs); band 2 = `LifecycleFunnel` (aggregate) + small-multiples grid of `MiniFunnel`; band 3 = grid of `ClientCard` + Agencies card + Attention queue
- [ ] Decide: Attention queue — derive in `fetchPortfolio` (extra query) or compute in component from `clients[]`? → compute in component (clients already have status, sort+slice in render)
- [ ] Decide: Persona tabs in portfolio view — add fifth "Portfolio" tab; CEO/Mktg/Sales/Service switch to operator-of-self when selected
- [ ] Diff spec for dashboard.astro, Dashboard.tsx, new tests

### W3 — Edit

**W3a:**
- [ ] `one.ie/web/src/pages/u/[slug]/dashboard.astro` — branch on `detectView`; if portfolio, fetch portfolio data and pass `view="portfolio"` to `Dashboard`
- [ ] `one.ie/web/src/components/dashboard/Dashboard.tsx` — add `view` prop; render portfolio bands when `view==='portfolio'` using ClientCard + MiniFunnel
- [ ] `one.ie/web/tests/e2e/dashboard-portfolio.test.ts` — NEW

**W3b:** *(empty)*

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate exits 0
- [ ] Live check: dev server `curl /u/<agency-fixture>/dashboard` returns 200 with `data-view="portfolio"` and ≥1 `data-client-card`
- [ ] Portfolio query <2s on test fixture of 50 children (escape gate)
- [ ] Reuse audit: ClientCard + MiniFunnel + LifecycleFunnel composed, not reimplemented
- [ ] Outcome re-check (full outcome command runs here)
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65 — targets: goal-fit ≥ 0.80, simplicity ≥ 0.85

---

## C5 — Delete FunnelRibbon + sync docs  [tier: trivial · batch: 4]

**Goal delta:** After C5, the obsolete synthetic-data component is gone and `plans/dashboard.md` reflects what shipped.

**Deliverable:** `delete: FunnelRibbon.tsx` + `doc: plans/dashboard.md` (sync only).

**UX delta:** Internal-only — codebase shrinks; docs match reality.

**Cycle outcome:** `grep -r FunnelRibbon one.ie/web/src` returns 0 hits AND `bun run verify` green.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && ! grep -r 'FunnelRibbon' src && bun run verify"
  asserts: "FunnelRibbon eliminated; build still green."
  budget:  "<10s wall"
```

### W1 — Recon

- [ ] `grep -rn FunnelRibbon one.ie/web/src` — confirm post-C2/C4 there are 0 imports
- [ ] `plans/dashboard.md` — sections needing tweak after final shipped shape

### W2 — Decide

- [ ] Confirm zero references; if any remain, file as bug for C2/C4 rework before deletion
- [ ] List exact doc edits needed in plans/dashboard.md (component counts, deliverable status)

### W3 — Edit

**W3a:**
- [ ] `rm one.ie/web/src/components/dashboard/FunnelRibbon.tsx`
- [ ] `plans/dashboard.md` — sync any sections that drifted from shipped UI

**W3b:** *(empty)*

### W4 — Verify

- [ ] Demo gate exits 0
- [ ] `bun run verify` green
- [ ] Doc-sync: markdown-link-check on plans/dashboard.md returns 0 broken
- [ ] Outcome re-check (final)
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

---

## See also

- `plans/dashboard.md` — spec
- `plans/dictionary.md` — canonical names (viewer roles, dimensions)
- `plans/rubrics.md` — scoring bands
- `.claude/rules/design.md` — 6 tokens, card pattern (ClientCard composition rule)
- `.claude/rules/react.md` — typed props, named exports
- `.claude/rules/ui.md` — `emitClick` on drill-in links
- `.claude/commands/do.md` — `/do` cycle that consumes this file
