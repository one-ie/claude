# 11-analytics — gap analysis

## Promise

`text/11-analytics.md` promises a renewal-ready analytics surface built on three artefacts:

1. **The one-page monthly client report** — six blocks (Revenue, Pipeline, Retention, Learning, Quality, One Recommendation). One click, four-second PDF, white-labelled in client brand, every number drillable to the conversation that produced it.
2. **The live dashboard** — same numbers as the report, refreshed in seconds. Revenue by campaign / team / channel / skill, retention trend, quality scores. Three-click drill from any number → list of conversations → single conversation transcript + payment receipt. Two-tier view (client / agency-ops) controlled by the §01 cascade.
3. **The improvement loop** — platform-generated monthly recommendation backed by month-over-month numbers; learning report shows which agents improved, which routes hardened, which new question clusters appeared (the surfacing of L5/L6/L7 loops).

Plus: six standard reports (Monthly perf, Pipeline drop-off, Retention curve, Channel comparison, Skill contribution, Learning report), cohort + channel views without a data team, scheduled export to client BI tools, client-configurable quality gate, agency-vs-client cascade visibility.

## Code reality

**Dashboard surface (CEO-style, exists).** `web/src/pages/dashboard.astro` + `web/src/components/dashboard/Dashboard.tsx` ship a polished four-persona dashboard (CEO / Mktg / Sales / Service) with HeroNumber, RingTriple, OneThingToday alert, RightNow event trail, MonthSummary, top customers/channels, ThisWeek bullets, FunnelRibbon, HotAccounts, ResponseGauge, AccountHeatStrip, PipelineBar. PrivacyFooter shows data freshness. Persona persisted to localStorage. Lighthouse-tuned (recent commit `55dfae7d feat(dashboard): close all gaps — Lighthouse 100/100 desktop + mobile`).

**Per-agent analytics (rich, exists).** `web/src/pages/u/[slug]/agents/[id]/analytics.astro` is the most-built surface. Eleven parallel API calls assemble: stage CVR, drop-off, time-to-convert, chip CTR, artifact save rate, return rate, composite value, A/B variant lift, path strength, audience by type + identified actors, top conversion paths, acquisition sources, retention cohort grid (real weekly cohorts!), stage timing (median/p90), tool-call success rate, DAU engagement trend, live event stream (WebSocket), CSV + JSON export per agent.

**Workspace analytics (thin, exists).** `web/src/pages/u/[slug]/analytics.astro` — totals, audience breakdown, per-agent table with drill link. Date-range filter via query string.

**Substrate exports (partial).** `/api/export/{actors,groups,skills,highways,conversations,people,group-rollup}` exist; `highways.ts` queries TypeDB live (paths/strength/traversals). Inbox-shaped.

**Loop surfacing.** None of L4–L7 are user-facing analytics. Highways export exists raw, but there is no "what improved this month" view. No agent-version-change log surfaced. No new-question-cluster (frontier loop L7) view.

## Gaps

**G1 — No monthly client PDF report. Anywhere.** Searched `web/src/pages/api/` and components. `/api/report` is an abuse-flag endpoint. There is no PDF generator, no six-block layout, no white-labelled brand-token render, no one-click trigger, no client-brand colour selection. The single most-promised artefact in the whole doc does not exist.

**G2 — Revenue is fake.** `Dashboard.tsx` hero revenue is `totalRevenue || 1840` — `totalRevenue` is initialised to 0 and never read from D1 in `queries.ts` (only event counts are queried). `topCustomers` and `topChannels` fall back to hard-coded fixtures (Acme / Wave LLC / North & Co). MonthSummary MRR `$52,180 ↑ 8%` is a literal. `web/src/pages/api/agents/[id]/revenue.ts` is an explicit stub: `// x402 KV doesn't have queryable history per Q3 recon` → returns `{ total: '0', txs: [] }`. The "cash, not sessions" promise has no implementation.

**G3 — No revenue-per-skill.** The doc dedicates a sub-section to this as "the metric that changes the conversation." There is no skill→payment join anywhere in `/api/export/skills.ts` or the agent analytics endpoints. Skill invocation logs are not joined to payment records.

**G4 — No quality scores in the dashboard or report.** No security/stability/simplicity/speed axis is computed or displayed anywhere in the web surface. `one/rubrics.md` defines them; no API surfaces them per agent/per workspace; no UI renders them. The "0.71 → 0.84" trend story has nothing to render.

**G5 — Three-click drill doesn't exist.** Numbers on the dashboard are not anchored to a list-of-conversations route. `RankedList`'s `showAllHref` points to `/u/<slug>/people` or `/u/<slug>/analytics` — not to the conversations that produced the number. No `?source=metric&value=X` filter in the conversations list. Verification chain is broken.

**G6 — No learning report.** The L5 (agent evolution), L6 (knowledge promotion), L7 (frontier detection) loops run in TypeDB but never surface as a "what improved this month" block. No agent version delta UI; no hardened-route UI; no new-question-cluster UI.

**G7 — No platform-generated recommendation.** "One recommendation" block has no producer. No code path generates a month-over-month gap analysis and proposes a single next action. The `OneThingToday` alert is hand-written `rawAlerts` literals in `queries.ts`.

**G8 — No scheduled export / BI connector.** Per-agent export is download-only (CSV / JSON via static links). No webhook destination, no storage-bucket sink, no schedule config in workspace settings, no read-only DB view for client BI.

**G9 — Client-configurable quality gate missing.** No `quality_gate` field in workspace settings. Default 0.65 is documented but not enforced or surfaced.

**G10 — Cascade visibility partial.** Dashboard route gates `end_user` out and falls through to a single workspace; but there is no two-tier ops-vs-client overlay (markup, credit consumption, recommended actions) on the same surface. The "agency sees one extra layer" promise is unwired.

**G11 — Cohort + channel views split by surface.** Retention cohort grid exists per-agent only (`RetentionGrid` in `[id]/analytics.astro`); no workspace-level cohort view; no channel-vs-channel comparison with quality-score and platform-benchmark columns.

**G12 — No payment-receipt-attached-to-conversation render.** Even if payments existed, no UI shows the receipt inside the conversation transcript drill.

## Recommended improvements

Ordered by leverage on the renewal claim:

1. **Wire real revenue** — replace fixture data in `queries.ts` and `revenue.ts`. Source: x402 payment events in D1 + conversation attribution. Without this, every other gap is moot.
2. **Build the monthly PDF report** — new `/api/reports/monthly?slug=&month=` endpoint that emits a six-block HTML→PDF (Workers can render via `@react-pdf/renderer` or a print-CSS HTML snapshot). Token-driven brand colours via workspace settings. Cache result. One button on the dashboard: "Generate monthly report." Track click as `ui:dashboard:report-generate`.
3. **Add revenue-per-skill join** — `/api/export/skills.ts` extended to include `revenueLast30d`, `invocations`, `conversionRate`. Backfill from `signal` + payment events tagged with active-skill id.
4. **Surface rubric scores** — new `/api/agents/[id]/quality.ts` returning `{security, stability, simplicity, speed}` per axis with month series. UI block in agent analytics + roll-up tile on dashboard. Per-workspace gate stored in `workspace_settings`.
5. **Make every dashboard number drillable** — add `?source=<metric>&value=<v>` filter to `/u/<slug>/in` (or a new `/u/<slug>/conversations` index). Click HeroNumber → filtered conversation list → single conversation with payment receipt inline.
6. **Learning report block** — new `/api/learning/monthly?slug=&month=` aggregating: agents whose `system-prompt` generation incremented (L5), highways whose strength crossed harden threshold (L6), tag clusters that appeared this month and weren't in prior month (L7). Renders as section in dashboard + monthly PDF.
7. **Platform recommendation generator** — compare current month vs prior month across the five other blocks; pick the metric with largest negative delta or largest positive trend that can be amplified; emit one sentence + one number. Reviewable by agency before client sees it (already implied by report-gen access being agency-only by default).
8. **Cascade ops overlay** — `?view=ops` query param on `/u/<slug>/dashboard` adds markup / credit-consumption / agency-recommendation row, gated to `agency` viewer.
9. **Workspace-level cohort + channel comparison** — promote `RetentionGrid` to workspace level; add channel comparison table with quality + platform-median columns.
10. **Scheduled export** — workspace setting `analytics.export = { destination, schedule }` → cron Worker pushes structured snapshot to webhook / R2 / DB view.

## Files to touch

**Stub endpoints to fill:**
- `web/src/pages/api/agents/[id]/revenue.ts` — read from D1 payment events, not return `0`
- `web/src/lib/dashboard/queries.ts` — replace `totalRevenue || 1840`, `topCustomers` fixtures, `topChannels` fixtures, hand-written `rawAlerts`, hard-coded MRR `$52,180` with D1 reads

**New endpoints:**
- `web/src/pages/api/reports/monthly.ts` — PDF generator, six blocks, brand-tokenised
- `web/src/pages/api/learning/monthly.ts` — L5/L6/L7 surfacing
- `web/src/pages/api/agents/[id]/quality.ts` — four-axis rubric scores + trend
- `web/src/pages/api/recommendations/monthly.ts` — month-over-month gap → single suggestion

**New components / extensions:**
- `web/src/components/dashboard/ReportButton.tsx` (new) — one-click "Generate monthly report"
- `web/src/components/dashboard/QualityScores.tsx` (new) — four-axis tile + sparkline
- `web/src/components/dashboard/LearningBlock.tsx` (new) — what improved
- `web/src/components/reports/MonthlyReport.tsx` (new) — six-block PDF layout
- `web/src/components/dashboard/RankedList.tsx` — `showAllHref` rewrite to filtered conversations route
- `web/src/components/dashboard/HeroNumber.tsx` — click → drill route

**Drill destination:**
- `web/src/pages/u/[slug]/in/index.astro` (or new `conversations.astro`) — accept `?source=`, `?metric=`, `?value=` filters; payment receipt inline on detail panel

**Workspace settings:**
- `web/src/pages/u/[slug]/settings.astro` — add `quality.gate`, `analytics.export.destination`, `analytics.export.schedule` (use the four-universal `settings?scope=analytics` endpoint per `.claude/rules/api.md` — no new files)

**Cascade overlay:**
- `web/src/pages/dashboard.astro` + `Dashboard.tsx` — accept `view=ops` for agency viewer

**Substrate join:**
- `web/src/pages/api/export/skills.ts` — extend to include revenue + invocation data

**Docs to reconcile in the same commit:**
- `text/11-analytics.md` — mark "monthly PDF" as roadmap until shipped; clarify what's live today
- `web/agent-analytics.md` + `web/agent-analytics-todo.md` — already named integration; extend with the report + learning + recommendation slices
- `one/rubrics.md` — confirm quality-score formula since UI now consumes it
