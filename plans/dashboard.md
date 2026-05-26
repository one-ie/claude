# Dashboard

The operating cockpit for `/u/{slug}/dashboard`. One surface, two views, ten seconds to the answer.

---

## Principle

**Most-important-thing first, drill-down second.** The dashboard answers one question per persona in <2 seconds: *is my business growing or stuck?* Everything else — funnels, agents, accounts — is a drill-down from that answer. We do not duplicate `/analytics`, `/in`, `/agencies`, `/clients`; we *summarise* them and link out.

## Two views, one route

Viewer role (resolved by middleware → `Astro.locals.workspaceContext.viewer`) selects the view:

| Viewer | View | What they see first |
|---|---|---|
| `owner` of a client company (no descendants, or `plan != 'agency'`) | **Operator view** | Their own business: funnel, hero KPI, hot accounts, inbox triage |
| `owner` of an agency (has child workspaces via `parent_slug` or TypeDB `hierarchy`) | **Portfolio view** | All client businesses at once: portfolio totals, per-client cards, attention list |
| `agency` (staff in agency workspace) | **Portfolio view** | Same as owner, scoped to the agencies they manage |
| `client` / `end_user` | redirected to `/chat` (unchanged) | n/a |

Switching is automatic — derived from data (`SELECT COUNT(*) FROM owners WHERE parent_slug=?`), not a toggle. An owner whose only client just churned drops back to operator view next page load.

---

## The information hierarchy

Both views obey the same three-band layout. Only the *content* of each band changes.

```
┌─────────────────────────────────────────────────────────────┐
│  NOW BAND      hero number + trend + triage chips           │
│                "is the line going up right now?"            │
├─────────────────────────────────────────────────────────────┤
│  FUNNEL BAND   real lifecycle funnel (6 stages) + audience  │
│                "where are people getting stuck?"            │
├─────────────────────────────────────────────────────────────┤
│  PORTFOLIO     who I serve (agencies · clients · accounts)  │
│  BAND          "which relationships need me today?"         │
└─────────────────────────────────────────────────────────────┘
```

A single `from`/`to` date-range picker in the header governs every chart on the page. Persisted in the URL so links are sharable. Persona tabs (CEO/Mktg/Sales/Service) keep working in operator view; portfolio view adds a fifth tab: **Portfolio**.

---

## Operator view (client company)

### Now band
- **Hero number** — persona-selected (CEO=revenue / Mktg=visitors / Sales=pipeline / Service=response-p50). Pulled from `agent_events_warm` totals via `fetchDashboard`, not synthetic. Big number + sparkline + comparison vs previous range.
- **Ring triple** — three secondary KPIs alongside hero (e.g. CVR · activation · retention).
- **Triage chips** — unread inbox count → `/in`, alerts open → `/in?tab=alerts`, agents needing review → `/agents`. Each chip is a one-click triage.

### Funnel band
- **Lifecycle funnel** — the six-stage funnel from `/analytics` (Arrive → Engage → Get value → Sign up → Deploy → Convert), promoted to first-class. Bar widths proportioned to counts, drop-off % per stage, tap a stage to filter the page below.
- **Audience breakdown** — human / agent / anonymous sessions as a stacked mini-bar with counts.
- **Top channels** — ranked list with sparklines (existing `RankedList` primitive).

### Portfolio band (operator)
- **Hot accounts** — ranked by signal weight (existing `HotAccounts`). Tap → `/u/{slug}/people`.
- **Top agents** — per-agent CVR table (moved here from `/analytics`), top 5 only, "View all →" → `/analytics`.
- **One Thing Today** — existing `OneThingToday` card, the highest-priority alert.

---

## Portfolio view (agency owner)

The agency owner wants to answer two questions before drilling in: *which client is growing?* and *which client is stuck?* The portfolio view foregrounds both.

### Now band — portfolio totals
- **Hero number** — aggregate across all child workspaces (sum of conversions or active visitors). Sparkline shows portfolio momentum.
- **Ring triple** — # clients · # at-risk clients (no events in 7d) · # growing clients (week-over-week ↑).
- **Triage chips** — clients needing onboarding · invites pending · billing alerts.

### Funnel band — portfolio funnel
- **Aggregate lifecycle funnel** — same 6 stages, summed across all clients. Honest portfolio view.
- **Per-client mini-funnels** — small-multiples grid (one row per client) — six tiny bars each. Pattern-spotting at a glance. Tap a row → scope page to that client.

### Portfolio band — the client grid
The hero of portfolio view. Replaces the `/clients` table with a richer card grid:

| Card slot | Content |
|---|---|
| Client name + slug | `display_name` from `owners`, slug as monospace |
| Status dot | green=growing · amber=flat · red=churning (computed from week-over-week delta) |
| Hero metric | Their primary KPI: visitors-this-week, conversions, or revenue if billed |
| Sparkline | 30d trend, dense and small |
| Heat strip | 7-day activity squares (existing `AccountHeatStrip` primitive) |
| Footer | "Open dashboard →" links to `/u/{client-slug}/dashboard` (owner-of-agency impersonation) |

Sort: at-risk first, then growing, then steady. Filter chips: all · at-risk · growing · onboarding · paused.

Below the grid, two compact cards:
- **Agencies** (if this owner has sub-agencies, white-label) — plan + count summary, link to `/agencies`.
- **Attention queue** — clients with the loudest alert (no signup in 14d, hero metric down 30%, billing failure). Each row is a one-click drill-in.

### Drill-in
Tapping a client card switches the dashboard to operator view scoped to that client's slug (URL becomes `/u/{client-slug}/dashboard`). The header carries an "← Back to portfolio" chip that returns to the agency owner's dashboard.

---

## Chart inventory (the "beautiful" promise)

All charts use the 6-token palette (`primary` · `secondary` · `tertiary` for series) and existing primitives. No new charting libraries.

| Chart | Component | Status |
|---|---|---|
| Hero sparkline | `Sparkline.tsx` | exists |
| Ring triple | `RingTriple.tsx` | exists |
| 6-stage funnel | `LifecycleFunnel` | exists in `/analytics`, promote to dashboard |
| Stacked audience bar | inline composition of token-tinted `<div>`s | new (≤30 LOC) |
| Per-client sparklines | `Sparkline.tsx` ×N in a grid | reuse |
| Heat strip (7d squares) | `AccountHeatStrip.tsx` | exists |
| Small-multiples mini-funnels | `<MiniFunnel>` — thin wrapper, 6 token-tinted bars | new (≤60 LOC) |
| Client card | `<ClientCard>` — composes Sparkline + AccountHeatStrip + status dot | new (≤80 LOC) |
| Ranked list with sparkline | `RankedList.tsx` | exists |

**Net new components:** 2 wrappers (`MiniFunnel`, `ClientCard`) plus one inline audience bar. Everything else composes.

---

## Data sources

| Field | Source |
|---|---|
| Visitors / events / conversions | `agent_events_warm` (D1) via `fetchDashboard` + new `fetchPortfolio` aggregator |
| Funnel stages | `agent_events_warm` events: `message-send`, `chip-click`, `stage-start`, `stage-complete`, `journey-complete`, `actor_type='human'` |
| Audience breakdown | `agent_events_warm.actor_type` |
| Child clients | `owners.parent_slug` (D1) + TypeDB `hierarchy` (reuse query from `clients.astro`) |
| Child agencies | `owners WHERE parent_slug=? AND plan='agency'` (reuse from `agencies.astro`) |
| Inbox unread / alerts | `GET /api/export/all` (reuse from `in.astro`), aggregate counts only |
| Persona default | `fetchViewerTitle` → `personaDefault` (exists) |
| Client status (growing/flat/churning) | `agent_events_warm` week-over-week delta in `fetchPortfolio` |

Portfolio aggregation: one new query per band — `SELECT slug, COUNT(...) FROM agent_events_warm WHERE slug IN (?,?,...) GROUP BY slug`. D1 handles `IN (?,?,…)` to ~100 — sufficient since agencies cap at ~100 clients per workspace.

---

## What we delete

| Today | Tomorrow |
|---|---|
| `FunnelRibbon.tsx` (synthetic data) | **Deleted in C5.** Replaced by `LifecycleFunnel` (real data sourced from `agent_events_warm` via `fetchFunnel`). |
| Synthetic `data.rightNow` events in `fetchDashboard` | Replaced by real inbox-derived events |
| Per-agent CVR table on `/analytics` (top-5 only on dashboard) | Promoted to dashboard "Top agents" card; `/analytics` keeps the full table |

`/analytics`, `/in`, `/agencies`, `/clients` remain. They become **deep tools** linked from dashboard summaries. The dashboard is the index; they are the chapters.

---

## Non-goals

- Not a BI tool. No SQL editor, no custom dashboards, no widget library.
- No new chart libraries. Recharts is SSR-externalised; we stay with `Sparkline` + token-tinted divs.
- No real-time WebSocket. Server-rendered page; "live" = a header `freshnessMs` and a refresh button. WebSocket lives in `/in`.
- No per-user layout customisation. Persona tabs are the only variable. Personalisation is `personaliseOrder` in `belowFoldOrder` (existing) — no new editor.

---

## See also

- `plans/dashboard-todo.md` — implementation cycles (W1-W4)
- `one.ie/web/src/pages/u/[slug]/dashboard.astro` — current entry
- `one.ie/web/src/pages/u/[slug]/analytics.astro` — source of the lifecycle funnel + per-agent table
- `one.ie/web/src/pages/u/[slug]/clients.astro` — TypeDB hierarchy query reused for portfolio grid
- `one.ie/web/src/pages/u/[slug]/agencies.astro` — `owners.parent_slug` query reused for agency band
- `one.ie/web/src/lib/dashboard/queries.ts` — `fetchDashboard`, `fetchFunnel`, `fetchPortfolio` (shipped)
- `one.ie/web/src/lib/dashboard/detect-view.ts` — pure fn `detectView(owner, childCount) → 'operator' | 'portfolio'` (shipped)
- `one.ie/web/src/components/dashboard/ClientCard.tsx` — per-client card with status dot · sparkline · heat strip · drill-in (shipped)
- `one.ie/web/src/components/dashboard/MiniFunnel.tsx` — 6-bar small-multiples funnel for per-client grids (shipped)
- `plans/dictionary.md` — canonical names (viewer roles, dimensions)
