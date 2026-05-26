# 09-teams — gap analysis

## Promise

From `text/09-teams.md`:

- **The frame (line 7):** ship a complete Marketing department, a complete Sales department, and a complete Service department to every client the day the contract signs. Three departments. 27 named roles. £2M payroll replaced day-one, not over time.
- **Three org charts spelled out:**
  - **Marketing (lines 21-35):** Marketing Director + 11 specialists — Brand Manager, Copywriter, SEO Lead, Advertising Manager, Media Buyer, Social Media Manager, Designer, PR/Comms, Email/Lifecycle, Events, Marketing Analyst.
  - **Sales (lines 52-61):** Sales Director + 7 specialists — SDR/Qualifier, Outbound Rep, AE, Solutions Engineer, Deal Desk, Customer Success Lead, Sales Analyst.
  - **Service (lines 80-88):** Service Director + 6 specialists — Tier-1 Support, Tier-2 Specialist, Onboarding, Complaint Handler, Knowledge Curator, Service Analyst.
- **One human per team (line 162):** the client hires only CMO / VP Sales / Head of CS. Each manages one Director. Director manages the specialists. CEO is the only human at the top.
- **Cross-team handoffs are signals (lines 102-145):** lead → Marketing Director → Sales SDR → AE → Service Director → Onboarding → CS. No CRM update, no Slack message. The signal fires; the next agent receives.
- **Markdown is the org chart (lines 270-311):** every agent is a markdown file with `reports_to:`, `manages:`, `approval_threshold: { spend: 1000, currency: GBP, require_human: true }`, and `voice: { contract: brand-voice, gate: 0.65 }` frontmatter fields. Changing the chart is a markdown edit.
- **Voice training, week one (lines 222-247):** four calibration questions → voice contract → every outbound message passes the 0.65 gate. After 8 weeks repeat queries drop 40-60%.
- **Approval gate (line 313):** when spend > £1k, Director routes signal to CEO inbox rather than auto-approving. Default 24h window or held.
- **Director chat (line 429):** CEO can DM the Director agent like any team member.
- **Pricing (lines 251-262):** £3,500/mo client retainer, < £500/mo substrate cost, 85%+ margin. Credits burn per workspace; high burn = activity, low burn = renewal risk.
- **Extendable to R&D / Finance / Ops (lines 376-392):** same pattern — Director + specialists + reports_to + voice contract + approval threshold.
- **Cross-references (lines 467-475):** §05 Agents (markdown spec), §06 Skills (per-role packs), §08 Memory (corpus stays with agency), §13 Learning (pheromone hardens highways).

## Code reality

### Marketing

- **Director agent exists in templates only:** `agents/templates/marketing/director.md` (1) — has 4 skills (`strategize / allocate / brief / review`), names 4 reports (writer, seo, social, ads), `sensitivity: 0.7`. **No `reports_to:`, no `manages:` array, no `approval_threshold:`, no `voice:` block.** The body lists the team in prose, but no machine-readable wiring.
- **Specialists:** `agents/templates/marketing/writer.md`, `seo.md`, `social.md`, `ads.md`. Four roles, not eleven. **Missing:** Brand Manager, Advertising Manager (vs Media Buyer split), Media Buyer, Designer, PR/Comms, Email/Lifecycle, Events Manager, Marketing Analyst.
- **Standalone marketing strategist:** `agents/templates/marketing-strategist.md` and `agents/marketing-strategist.md` exist as separate single-file agents, not slotted into the Director's chart.
- **Marketing ontology spec:** `one/marketing-ontology.md` defines a "23-agent department" with persona schema, KPI ladder, attribution model, and 7 learning loops. Schema is `one/marketing-schema.tql`. The schema and the template org are **disconnected** — no code reads marketing-schema.tql and instantiates the 23-agent department.
- **Campaigns surface:** `web/campaigns.md:11,57,182,356` describes a "cmo agent" that "breaks the work into pieces and hands them out to the marketing department." That is the closest thing in the repo to the promised Director→specialist routing — but `web/campaigns-todo.md` and the campaigns page do not yet ship the multi-agent fan-out (campaigns.md:182 says "self-improvement L5 ships in a follow-up plan").

### Sales

- **One template agent:** `agents/templates/sales-discovery.md` (1). Skills: `qualify / discovery / objection / proposal`. **No Sales Director.** No SDR, AE, SE, Deal Desk, CS Lead, or Sales Analyst as distinct agents — `sales-discovery` mashes SDR + AE responsibilities into one file.
- **`sequence-todo.md`** at root is the closest thing to an outbound-rep build. It is a sequencing plan, not a department.
- **No `agents/templates/sales/` folder.** Marketing and community have folders; sales does not.
- **No sales-ontology, no sales-schema.tql.** Only `one/marketing-ontology.md` and `one/education-ontology.md` exist.

### Service

- **One template agent:** `agents/templates/support-tier1.md` (1). Skills: `triage / resolve / escalate / knowledge`. Sensitivity 0.4.
- **Community templates partially overlap:** `agents/templates/community/director.md`, `community/support.md`, `community/moderator.md` — "community" here means *user community* (forum/Discord moderation), not customer service. The README (`agents/templates/README.md:14-19`) names the community director as a peer of the marketing director, not a service director.
- **Missing:** Service Director, Tier-2 Specialist, Onboarding Agent, Complaint Handler, Knowledge Curator, Service Analyst as distinct templates.
- **No `agents/templates/service/` folder.** No `service-ontology.md`.

### Org-chart machinery

- **Frontmatter contract (`agents/CLAUDE.md:18-32`)** defines `name / model / channels / group / skills / sensitivity / wallet / tools / lifecycle` — **no `reports_to`, no `manages`, no `approval_threshold`, no `voice` block.** The promised fields are not in the spec.
- **Zero hits in source for `reports_to` or `manages:`** across `web/src/` and `sdk/` and `claw/`. The substrate cannot currently route a roll-up signal up a chart it does not represent.
- **Group dimension is in TypeDB** — `web/roles.md:106-112` shows `team: marketing / engineering / support` as Group-tier entities, with `membership` relations binding actors to teams. The Groups primitive exists; the **3-department shipping bundle on top of it does not**.
- **UI:** `web/src/pages/agents.astro` lists agents flat (`listAgents()` returns all, filterable only by `journey / skills / theme` query param). No grouping by department, no org-chart view, no "Marketing Director's team" panel. `web/src/components/agents/` contains `AgentDrawer.tsx`, `AgentForm.tsx`, `VerifiedBadge.tsx` — no org-chart component.
- **Studio surfaces** (`web/src/pages/studio/`) are per-agent — `[agent].astro`, `discovery-dashboard.astro`, `field-service-dashboard.astro`, `ptcorp-dashboard.astro`. No `/studio/marketing`, `/studio/sales`, `/studio/service` department dashboards.

### Voice contract + approval gates

- **No voice-contract code.** Zero hits for `voice_contract`, `voice-contract`, `voice:` in repo.
- **No quality gate at 0.65 wired to outbound messages.** `one/rubrics.md` defines a 0.65 gate for `/do` cycle close — not for per-message brand-voice checks.
- **No approval_threshold runtime.** The frontmatter field is not parsed; nothing in `claw/` or `web/` halts a tool call on £1,000 spend or routes the signal to a CEO inbox.
- **`/in/[groupId].astro`** exists as the workspace inbox but is not wired as a "Director-to-CEO summary" feed.

### Friday-5pm roll-up

- **No "weekly summary at 17:00" cron** for a Marketing Director agent. `claw/` has agent loops; none scheduled per department. The L1-L7 loops in `.claude/rules/engine.md` are runtime loops, not weekly client briefs.

## Gaps

1. **The three departments do not exist as shipping bundles.** Marketing has 5 templates (1 director + 4 specialists). Sales has 1 hybrid template. Service has 1 template (tier-1). Promised: 27 distinct roles in 3 named folders. Shipped: 6 roles, partial folders.
2. **`reports_to`, `manages`, `approval_threshold`, `voice` frontmatter fields are not in the spec.** `agents/CLAUDE.md` does not list them; no parser reads them; no runtime acts on them. The "markdown is the org chart" claim is currently aspirational.
3. **No org-chart UI.** No `/teams/marketing`, `/teams/sales`, `/teams/service` route. No component renders the reporting hierarchy. `agents.astro` is a flat list.
4. **No voice-contract pipeline.** Week-one calibration → contract → 0.65 gate on every outbound message is fully unimplemented.
5. **No spend-approval signal.** £1,000 threshold → CEO-inbox routing → 24h hold is unimplemented; no code path in `web/src/pages/api/` matches.
6. **No Director→CEO weekly digest.** Friday 17:00 summary signal is not scheduled; no per-department analyst → director → CEO chain wired.
7. **Cross-team handoff signals are not modelled.** The marketing→sales→service flow in promise lines 102-145 has no concrete `signal({ receiver: 'sales:sdr', from: 'marketing:director' })` wiring. The substrate supports it; no department code emits it.
8. **No Sales or Service ontology / schema.** Only `marketing-ontology.md` exists. The promise treats the three departments as symmetric peers.
9. **Cost / credit-burn dashboard per department is absent.** `web/billing.md` covers credits at workspace level; not per-department burn rates that map to the £500/mo substrate-cost claim.
10. **CEO chat-to-Director surface is not differentiated.** `chat.astro` is the universal chat; there is no "DM the Marketing Director" entry-point that pins the conversation to the Director agent with the Director's voice contract.

## Recommended improvements

1. **Add the three folders with the 27 templates.** Create `agents/templates/marketing/` (extend from 5 to 12), `agents/templates/sales/` (new, 8 files), `agents/templates/service/` (new, 7 files). Each director file declares `reports_to: ceo` and `manages: [<id>...]`. Each specialist declares `reports_to: <director-id>`.
2. **Extend the agent frontmatter contract.** Add `reports_to`, `manages`, `approval_threshold`, `voice` to `agents/CLAUDE.md` Frontmatter contract section and to the parser in `web/src/engine/agent-md.ts`. Add the corresponding TypeDB attributes (likely `reports_to` as a membership-relation role attribute; `approval_threshold` and `voice` as actor-attached structs).
3. **Build `/teams/[dept]` org-chart routes.** Three new pages (`marketing.astro`, `sales.astro`, `service.astro`) that read agents by `group` + `manages` chain and render Director → specialists tree. Reuse `AgentDrawer.tsx`. Add a `/teams` index that links to all three.
4. **Implement the voice-contract pipeline as a skill + middleware.** New skill `voice-check` (in `agents/templates/marketing/brand-manager.md` first), invoked by `substrateMiddleware` in `claw/` on every outbound message. Reuses the `one/rubrics.md` 0.65 gate machinery.
5. **Implement approval-threshold routing in the substrate middleware.** Read `approval_threshold` from director frontmatter; when a `tool` call exceeds threshold, emit `signal({ receiver: 'ceo:inbox', data: { request, rationale, hold_until } })` instead of executing. Holds in D1; expires after configured window.
6. **Schedule the Friday-17:00 digest.** Cron in `claw/` that runs each `*-analyst` agent → emits to `*-director` → emits to `ceo:inbox`. Reuses `signal` only; no new endpoints.
7. **Wire cross-team handoffs.** Add named `handoff` skills (`marketing→sales:sdr`, `sales→service:onboarding`) using existing `signal()` primitive. Mark/warn on each handoff so pheromone hardens the highway path described in `text/09-teams.md:134`.
8. **Add `one/sales-ontology.md` and `one/service-ontology.md`** as peers of `marketing-ontology.md`, plus `sales-schema.tql` and `service-schema.tql`. Symmetry across the three departments unlocks the §13 Learning loops at department level.
9. **Per-department credit-burn widget** added to `web/src/pages/u/[slug]/billing.astro`. Reads from existing credit ledger; groups by department via `group` field.
10. **Department-pinned chat entries.** In `/u/[slug]/chat`, add three persistent starters: "Marketing Director", "Sales Director", "Service Director". Each pins the conversation to the right Director agent with its voice contract pre-loaded. Reuses `ChatHost.tsx` + starter conventions already in use.

## Files to touch

**Promise / spec docs:**
- `/Users/toc/Server/one-ie/one/agents/CLAUDE.md` — add 4 frontmatter fields (`reports_to`, `manages`, `approval_threshold`, `voice`) to contract
- `/Users/toc/Server/one-ie/one/one/dictionary.md` — name the 27 roles, the 3 departments, the voice-contract term, the approval-threshold term
- `/Users/toc/Server/one-ie/one/web/agent-authoring.md` — extend authoring contract with org-chart blocks
- `/Users/toc/Server/one-ie/one/one/sales-ontology.md` — new
- `/Users/toc/Server/one-ie/one/one/service-ontology.md` — new
- `/Users/toc/Server/one-ie/one/one/sales-schema.tql` — new
- `/Users/toc/Server/one-ie/one/one/service-schema.tql` — new

**Agent templates (markdown):**
- `/Users/toc/Server/one-ie/one/agents/templates/marketing/` — extend with `brand-manager.md`, `media-buyer.md`, `designer.md`, `pr.md`, `email-lifecycle.md`, `events.md`, `analyst.md` (existing `director.md` `writer.md` `seo.md` `social.md` `ads.md` need `reports_to:` + `voice:` added)
- `/Users/toc/Server/one-ie/one/agents/templates/sales/` — new folder: `director.md`, `sdr.md`, `outbound.md`, `ae.md`, `solutions-engineer.md`, `deal-desk.md`, `customer-success.md`, `analyst.md` (8 files)
- `/Users/toc/Server/one-ie/one/agents/templates/service/` — new folder: `director.md`, `tier1.md`, `tier2.md`, `onboarding.md`, `complaint.md`, `knowledge-curator.md`, `analyst.md` (7 files)
- `/Users/toc/Server/one-ie/one/agents/templates/README.md` — update org chart diagram (currently shows marketing + community; needs marketing + sales + service + community)

**Parser / substrate:**
- `/Users/toc/Server/one-ie/one/web/src/engine/agent-md.ts` (or `sdk/src/parse.ts` — whichever owns frontmatter parsing) — read 4 new fields, write to TypeDB
- `/Users/toc/Server/one-ie/one/claw/src/agents/builder.ts` — wire `approval_threshold` gate into tool-call middleware; wire `voice` gate into outbound message middleware
- `/Users/toc/Server/one-ie/one/claw/` — new cron handler for Friday-17:00 director digest

**UI (web):**
- `/Users/toc/Server/one-ie/one/web/src/pages/teams/index.astro` — new (list of departments)
- `/Users/toc/Server/one-ie/one/web/src/pages/teams/marketing.astro` — new
- `/Users/toc/Server/one-ie/one/web/src/pages/teams/sales.astro` — new
- `/Users/toc/Server/one-ie/one/web/src/pages/teams/service.astro` — new
- `/Users/toc/Server/one-ie/one/web/src/components/teams/OrgChart.tsx` — new (reads `manages:` chain, renders tree)
- `/Users/toc/Server/one-ie/one/web/src/components/teams/DirectorCard.tsx` — new
- `/Users/toc/Server/one-ie/one/web/src/pages/u/[slug]/billing.astro` — per-department burn-rate widget
- `/Users/toc/Server/one-ie/one/web/src/pages/u/[slug]/chat.astro` (or starter config) — 3 pinned director starters
- `/Users/toc/Server/one-ie/one/web/src/lib/agents.ts` — add `groupByDepartment()` / `manages()` traversal helpers

**Skills:**
- `/Users/toc/Server/one-ie/one/agents/templates/marketing/brand-manager.md` (new) ships the `voice-check` skill
- `/Users/toc/Server/one-ie/one/agents/skills/voice-contract.md` — new shared skill for all directors
- `/Users/toc/Server/one-ie/one/agents/skills/approve-spend.md` — new shared skill, used by all directors

**Roles / cascade:**
- `/Users/toc/Server/one-ie/one/web/roles.md:106-112` — extend the "Pattern C — Team" example with the three named departments (`marketing`, `sales`, `service`) as canonical team types
