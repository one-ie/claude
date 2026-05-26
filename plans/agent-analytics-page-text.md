# Agent Analytics — Landing Page Copy

All feature text for the agent analytics landing page. Written so a
non-technical marketer can read the bold lines and walk away with the
pitch — and a technical reader can drop into the code blocks and see
it's real. Companion to `agent-page-text.md`.

---

## Hero

**Headline**
Know exactly where your agent loses people.

**Subheadline**
Funnel analytics, A/B testing, and conversion optimisation — all
declared in the agent's markdown file. No tracking code. No SQL. No
data team required.

**Body**
Every stage your visitors move through is measured. Every drop-off is
visible. Every optimisation technique — idle nudges, abandonment
recovery, A/B variants, social proof — is a short config block you
flip on. The dashboard shows what works. The system learns from it.

**CTA**
See your funnel → `/u/<slug>/agents/<id>/analytics`

---

## Feature 1 — Funnel Tracking

**Headline**
See exactly where visitors drop off.

**Subheadline**
Every stage of your agent's journey is a measurable step. Completion
rates, drop-off bars, time-to-conversion — all in one view.

**Body**
Define a funnel by listing your goals in the agent file. The runtime
measures everything automatically. **No tracking code to install. No
events to wire up.** Set a goal; the system measures it.

```
Discovery       1,247 visits  ████████████████████████████  100%
Intro           1,089 (87%)   █████████████████████████      87%
Stage start       742 (59%)   █████████████████              59%
Stage complete    398 (32%)   █████████                      32%  ← biggest drop
Goal              224 (18%)   █████                          18%
```

Click any bar to segment it — by variant, locale, referrer, or device.
The drop-off you see is the drop-off worth fixing.

**Define a goal in one block:**
```yaml
funnel:
  goals:
    - id: brief-locked
      name: Brief Locked
      stage: brief
      event: artifact-saved
      value: 1.0
      window: 600s
```

That's the whole configuration. The runtime handles the rest.

---

## Feature 2 — KPIs that load instantly

**Headline**
Nine metrics. All computed. All pre-aggregated.

**Subheadline**
Dashboard loads in under 100ms. The system reads numbers that have
already been counted — not raw events that have to be scanned. Numbers
you can act on.

**Body**
Every KPI has a precise definition and a pre-computed source. You're
not eyeballing charts — you're reading verified numbers.

| KPI | What it measures, in plain English |
|---|---|
| **Stage Completion Rate** | Of everyone who started this stage, how many finished? |
| **Drop-off** | The opposite — where the funnel leaks |
| **Time-to-Conversion** | Typical time (and worst-case time) from start to goal — where it's slow |
| **Chip CTR** | Which suggested replies actually get clicked — what language works |
| **Artifact Rate** | How many visitors saved something — how productive visits are |
| **Return Rate 7d** | Who came back within a week — retention signal |
| **Variant Lift** | Variant B vs variant A — the A/B winner margin |
| **Conversion Value** | Total value of all goals hit — weighted composite score |
| **Path Strength** | How the substrate values your agent — high rank = more peer calls |

Every KPI responds to the same date-range picker. Default is the
rolling 7 days.

---

## Feature 3 — A/B Testing

**Headline**
Test two versions. Pick the winner. The substrate remembers.

**Subheadline**
Stable arm assignment per visitor. Statistically rigorous lift
calculation. Sample-size guard so you never act on noise.

**Body**
Declare two versions (arms) in the funnel block. Each visitor gets one
version, pinned to their cookie so they always see the same thing. The
dashboard shows which one converts better — **but only after both have
enough data**. Until then it says "not enough data" instead of showing
a misleading delta.

```yaml
optimization:
  variants:
    assignment: cookie
    arms:
      A: { weight: 0.5, prompt: "Help me lock the brief…" }
      B: { weight: 0.5, prompt: "I have a half-baked idea. Tell me where to start." }
    goalForWinner: brief-locked
    minSampleSize: 100
```

**The math is shown, not hidden.** Every lift report includes how many
visitors saw each version, the range of likely true lift (the 95%
confidence interval — what we're 95% sure the real number is between),
and a significance score (the p-value — below 0.05 means we're
confident the difference isn't random). **If the result isn't
significant, the dashboard won't let you declare a winner early.**

**Holdout.** Set `holdout: 0.10` and 10% of visitors are excluded from
the test entirely — they see the default. Lift is also reported
against this group. CRO claims are validated, not just measured.

**The substrate learns from winners.** When variant B converts better,
the winning prompt path gets a strength boost. Future agent-evolution
cycles favour it. A/B isn't just a dashboard feature — it feeds the
learning loop.

---

## Feature 4 — CRO Techniques

**Headline**
Eight optimisation techniques. Each one a short config block.

**Subheadline**
Idle nudges. Abandonment recovery. Social proof. Variable rewards. All
configurable, all measured, none requires code.

**Body**
Every technique is independent. Enable what fits your agent. Disable
what doesn't. Each has its own impact card in the dashboard showing
whether it's working — and a recommended action if it isn't.

---

### Idle Re-engagement

**What it does:** After N seconds of chat silence, the agent sends a
gentle re-engagement message. Caps at `maxFires` so it doesn't nag.

**When to use:** Stage has high dwell time but low completion.
Visitors are thinking, not converting.

**Config:**
```yaml
idleReengagement:
  enabled: true
  after: 30s
  maxFires: 2
  prompt: "Still working on this? Want to see an example?"
```

**How you know it's working:** Recovery rate = replies within the
window ÷ nudges fired. Below 10% → raise the threshold or disable.

---

### Abandonment Recovery

**What it does:** When a visitor returns and a prior thread exists
within the window, a "Welcome back — pick up where you left off?"
banner appears. One click resumes exactly where they left off.

**When to use:** High drop-off at the goal stage. Visitors start but
don't finish in one session.

**Config:**
```yaml
abandonmentRecovery:
  enabled: true
  windowDays: 14
  banner: "Welcome back — pick up where you left off?"
```

**How you know it's working:** Banner click-through × the conversion
rate of resumed threads. Lifts Return Rate 7d directly.

---

### Social Proof

**What it does:** Shows "247 users completed this this week" below the
hero. Pulled from real goal counts over the rolling window. Floors at
`minCount` — so it never shows single digits that feel creepy.

**When to use:** Visitors are hesitating at intro → first action.
Credibility gap.

**Config:**
```yaml
socialProof:
  enabled: true
  minCount: 50
  windowDays: 7
  anonymise: true
```

**How you know it's working:** A/B-test the badge. Measure the lift in
intro → first-action clicks.

---

### Variable Reward

**What it does:** Surprises visitors with an unlock at a milestone.
"Free headline-variants skill unlocked." Powerful because it's
unexpected — the surprise is the hit, not the reward itself.

**When to use:** Retention is low. Visitors complete once but don't
return.

**Config:**
```yaml
variableReward:
  enabled: true
  triggers:
    - after: brief-locked
      unlock: free-headline-skill
    - after: campaign-shipped
      unlock: founder-pack
```

**How you know it's working:** Return rate for visitors who hit the
trigger vs those who didn't.

---

### Friction Reduction

**What it does:** On a returning visitor's second visit, prior answers
are pre-filled. The agent asks "Audience was 'solo founder' last time
— still right?" instead of starting over.

**When to use:** Returning visitors convert worse than new ones —
re-entry friction is the cause.

**Config:**
```yaml
frictionReduction:
  enabled: true
  preFillFromThread: true
  preFillFields: [audience, outcome, channels]
```

**How you know it's working:** Time-to-conversion for returning
visitors drops.

---

### Progressive Disclosure

**What it does:** Visually disables later stages until earlier goals
fire. Reduces choice overload — but adds friction. Default off.

**When to use:** Multi-stage funnels where visitors skip ahead and
fail. Forced sequencing is the fix.

**Config:**
```yaml
progressiveDisclosure:
  enabled: false
  stages: [draft, review, ship]
```

**How you know it's working:** When conversion-per-attempt rises but
total attempts drop, it's working. When both drop, it's just friction
— disable it.

---

### Personalisation

**What it does:** Adapts the agent's behaviour to visitor signals.
Returning visitors get a different opening prompt. Vietnamese visitors
get Vietnamese quick replies.

**When to use:** Your audience is diverse. One-size-fits-all prompts
are leaving segments behind.

**Config:**
```yaml
personalisation:
  enabled: true
  rules:
    - when: returning
      seedPrompt: "Continue where you left off, or start fresh?"
    - when: variant=B
      quickReplies: ["Half-baked idea", "Show me an example"]
    - when: locale=vi
      quickReplies: ["Bắt đầu", "Cho tôi xem ví dụ"]
```

**How you know it's working:** Filter the dashboard by the rule's
condition. Compare conversion before and after the rule applied.

---

### Scarcity

**What it does:** "Premium template — 3 spots left this week." Use
sparingly — degrades trust if abused. Always tie to a real constraint.

**Config:**
```yaml
scarcity:
  enabled: false
  messages:
    - "Premium template — 3 spots left this week"
```

**Caution:** Lifts immediate conversion. Can hurt return rate and
word-of-mouth if perceived as fake. Always track both.

---

## Feature 5 — Segmentation

**Headline**
Slice any metric by any dimension.

**Subheadline**
Variant, locale, device, referrer, source, UTM, returning vs new. No
extra config — every event captures these automatically.

**Body**
Every event is tagged at the moment it lands. Every KPI responds to a
"Segment by…" dropdown. No extra tracking required.

| Dimension | What it slices |
|---|---|
| **Variant** | A vs B arm performance |
| **Locale** | Language-by-language conversion |
| **Device** | Desktop vs mobile vs tablet |
| **Source** | Web vs SDK vs MCP vs CLI |
| **Referrer** | Which domains send converting visitors |
| **UTM** | Campaign-level attribution |
| **Returning vs new** | How cohort behaviour differs |

Cross-cuts up to two dimensions (e.g. variant × locale). Beyond that
the matrix gets too sparse to be useful, and the dashboard says so.

---

## Feature 6 — Attribution

**Headline**
Know which touchpoint earned the conversion.

**Subheadline**
First-touch, last-touch, or linear. Configured per agent. Computed
automatically.

**Body**
Customer journeys cross multiple events. Attribution decides which one
gets the credit.

| Model | Credits | When to use |
|---|---|---|
| **First-touch** | The first event in the visitor's first session | Top-of-funnel research; where awareness comes from |
| **Last-touch** | The final event before the goal | Bottom-of-funnel; what tipped the decision |
| **Linear** | Equal share across all events in the journey | Multi-step funnels; no single touchpoint dominates |

```yaml
analytics:
  attribution: linear
```

Default is `linear`. The dashboard shows attributed value per
touchpoint, per referrer, per UTM campaign — so you know where to put
budget.

---

## Feature 7 — Agent-to-Agent (A2A) Analytics

**Headline**
The same funnel — for when other agents call yours.

**Subheadline**
Inbound peer calls, skill success rate, latency at the 95th percentile
(your SLA), path strength rank. The metrics that matter when your
visitors are bots.

**Body**
When your agent serves both humans **and** other agents (`visitorTypes:
[human, agent]`), the dashboard adds a second view — the A2A funnel.
Same goals, same event model. Different KPIs.

| KPI | What it measures |
|---|---|
| **Inbound peer calls** | How many other agents are calling yours |
| **Skill success rate** | Successful calls ÷ total calls — quality signal |
| **p95 latency** | Worst-case response time for 95% of calls — your SLA proof |
| **Outbound mark rate** | Paths your agent marks as successful — how well you route |
| **Payment completion** | Verified payments ÷ paid calls that succeeded |
| **Path strength rank** | Your agent's rank on the system's highway list |

Agents that score well rank higher in peer routing. **More calls → more
marks → stronger paths → more calls.** The loop compounds.

```yaml
funnel:
  visitorTypes: [human, agent]
  a2a:
    discoverable: true
    capabilities: [draft-email, headline-variants]
    pricing:
      currency: USDC
      rate: 0.05
    sla:
      p95LatencyMs: 4000
      successRate: 0.90
    pheromoneTags: [marketing, copy]
```

---

## Feature 8 — Retention

**Headline**
See who comes back, and when.

**Subheadline**
Weekly cohort heatmap. Eight cohorts × seven weeks. One number per
cell — dark means retained.

**Body**
Every visitor is grouped by the week they first arrived. The grid
shows what fraction of each weekly cohort came back in week 1, week 2,
week 3 — up to week 6. Week 0 is always 100% (the cohort itself).
Everything after that is the retention signal.

```
         W0     +1w    +2w    +3w    +4w    +5w    +6w
2026-W13  100%   42%    31%    24%    19%    14%    11%
2026-W14  100%   38%    27%    21%    17%    —      —
2026-W15  100%   44%    —      —      —      —      —
```

Dark cells = high retention. Fading rows = normal. A row that stays
dark longer than average is a cohort worth understanding — **what was
different that week?**

**Retention is a signal the substrate uses too.** Return visits
strengthen the entry path. Over time the system strengthens routes
that bring back loyal visitors and weakens one-shot traffic sources.

---

## Feature 8b — Top Paths to Conversion

**Headline**
Know exactly which route converts best.

**Subheadline**
The actual sequences your visitors walk through, ranked by sessions
and conversion rate. (What Mixpanel calls "Flows" — but computed for
free.)

**Body**
The analytics surface computes the actual paths users walk — not just
stage-by-stage conversion, but the full sequences.

```
[Qualify] → [Project Brief] → [Book Call]   31 sessions · 73% CVR  ████████
[Qualify] → [Send a Spec]   → [Book Call]    9 sessions · 44% CVR  ████
[Qualify] → [Pricing]                        7 sessions · 14% CVR  ██
```

Each row shows the sequence as human-readable chips, the number of
sessions that took that route, and the conversion rate. The colour of
the CVR badge tells you at a glance: **green = strong, amber =
developing, red = needs attention.**

**The substrate already knew.** These paths are exactly what the
system's "highways" encode internally — frequently-taken, high-success
routes. The analytics surface just makes them readable.

---

## Feature 8c — Acquisition

**Headline**
Know which sources send converting visitors.

**Subheadline**
Top referrer domains, ranked by sessions. Conversion rate per source.
**No UTM setup required.**

**Body**
Every event captures the referring URL at the moment it lands. The
acquisition breakdown groups visitors by first-touch domain and shows
what fraction completed a journey.

```
google.com        ███████████████   142 visits   31% CVR
direct            ████████████      98 visits    24% CVR
linkedin.com      ████████          67 visits    41% CVR  ← highest CVR
twitter.com       ████              31 visits    12% CVR
```

Two bars per row: session volume (track) and conversions (fill). The
fill colour scales with conversion rate. **Useful for budget
decisions: high-volume low-CVR sources may not be worth the spend.**

---

## Feature 8d — Stage Timing

**Headline**
See where users slow down.

**Subheadline**
Typical time and worst-case time per stage. Measured automatically. No
config.

**Body**
Every `stage-complete` event records how long it took. The timing card
aggregates per stage: median duration (what most users experience) and
p90 (the long tail — the slowest 10%).

```
Project Brief   median 2m 14s   p90 8m 40s   ██████░░░░░░░░░░░
Qualify         median 0m 45s   p90 2m 10s   ███░░░░░░░░░░░░░░
Book Call       median 1m 02s   p90 3m 30s   ████░░░░░░░░░░░░░
```

**A stage with a long p90 relative to its median has a heavy tail —
some users are struggling.** That's the stage to simplify, not the one
with the low completion rate.

---

## Feature 8e — Tool Call Analytics

**Headline**
Know which AI tools are working.

**Subheadline**
Per-tool call counts and success rates. **Uniquely AI-native — no
traditional analytics platform tracks this.**

**Body**
Every time the AI calls a tool (a web search, a CRM lookup, a
generation function), two events fire: one for the call, one for the
result. The analytics surface aggregates these per tool name.

```
search_web          calls: 247   ✓ 231   ✗ 16   93% success  ████████████
fetch_company_data  calls: 189   ✓ 156   ✗ 33   83% success  ██████████
generate_brief      calls:  94   ✓  91   ✗  3   97% success  ████████████
send_to_crm         calls:  12   ✓   7   ✗  5   58% success  ██████
```

A tool with < 80% success rate is a reliability problem. A tool that's
called rarely but converts at high rates is a candidate for more
exposure. **This is the layer that makes AI agents measurably
improvable — not just "it worked" but "which tools worked, and at what
rate."**

---

## Feature 8f — Audience Identity

**Headline**
Know exactly who's using your agent.

**Subheadline**
Human, agent, or anonymous — each with their own breakdown. Identified
users listed by name.

**Body**
Every event is tagged with an actor type at the moment it lands:

- **Human** — a logged-in user (their workspace name is stored)
- **Agent** — another agent calling via SDK or MCP (identified by API key)
- **Anonymous** — an unauthenticated web visitor

The audience card shows the split as a stacked bar and a breakdown
table. Identified actors — logged-in users and named API callers —
appear in a sortable list with event count and last-seen time.

```
████████████████████████░░░░  Human (47%)     34 sessions
████████░░░░░░░░░░░░░░░░░░░░  Agent (19%)     14 sessions
░░░░░░░░░░░░░░░░░░░░░░░░░░░░  Anonymous (34%) 25 sessions

Identified actors:
  tony@one.ie          Human    142 events   2m ago
  api:ptcorp-advisor   Agent     87 events   5m ago
  brad@ptcorp.ie       Human     31 events   1h ago
```

When agents are significant consumers of your agent, **the A2A funnel
metrics become the relevant KPIs**, not the human funnel. This view
tells you which audience you're actually serving.

---

## Feature 9 — Event Taxonomy

**Headline**
Every interaction is an event. Every event is a row.

**Subheadline**
Four tiers of events. All captured automatically. All append-only —
nothing ever gets overwritten.

**Body**
**You don't emit most of these.** The runtime fires them. The four
tiers cover every layer of what an agent does.

**Tier 1 — Visitor lifecycle** *(fires automatically)*
`intro-shown` · `stage-card-impression` · `stage-start` ·
`stage-complete` · `stage-drop` · `chip-impression` · `chip-click` ·
`chat-message` · `chat-reply` · `chat-tool-call` · `artifact-saved` ·
`share-link-copied` · `thread-resumed` · `journey-complete` ·
`download`

**Tier 2 — CRO events** *(fires when optimisation techniques activate)*
`idle-nudge-fired` · `idle-nudge-recovered` ·
`abandonment-banner-shown` · `abandonment-resumed` ·
`social-proof-shown` · `variant-assigned` · `unlock-granted` ·
`friction-prefill` · `personalisation-rule-applied`

**Tier 3 — Agent-to-agent events** *(fires on peer-routed calls)*
`peer-discovery-query` · `peer-route-selected` · `peer-call-issued` ·
`peer-call-result` · `pheromone-mark` · `pheromone-warn` ·
`x402-receipt-verified` · `escrow-locked` · `escrow-released`

**Tier 4 — Custom events** *(you define these)*
```yaml
emit_event({ name: "persona-locked", payload: { personaId: "founder", confidence: 0.9 } })
```
Or via SDK: `client.emitAgentEvent(agentId, 'persona-locked', payload)`.
Names are namespaced `custom:<your-name>` and validated against a
schema you define.

---

## Feature 10 — Privacy

**Headline**
No personal data. Ever.

**Subheadline**
Opaque visitor hashes (scrambled fingerprints). No IP storage. No
fingerprinting. Per-workspace isolation.

**Body**
Visitor identification uses `sha256(cookie_id + workspace_salt)` — a
one-way scramble of the cookie plus a workspace-specific secret. The
salt is per-workspace, so **the same cookie produces different hashes
across workspaces.** No cross-workspace tracking is possible.

**What is never stored:**
- Email addresses
- IP addresses (used only for a 60-second rate-limit window, then discarded)
- Full browser strings (user-agents)
- Geolocation data

**What is stored:**
- Device class (desktop / mobile / tablet / bot) — bucketed, not raw
- Locale (`en`, `vi`, `ja` — first 2 chars of `Accept-Language`, no geolocation database)
- The opaque visitor hash

**GDPR delete:** `DELETE /api/visitor/<visitor_hash>` removes that
visitor's rows across every tier within 30 days. **Deletion by hash is
purely operational — no name, no email needed.**

Public data exports never include visitor hashes — only derived counts.

---

## Feature 11 — Tiered Storage and Exports

**Headline**
Raw events for 14 days. Aggregates for 90. Archives for 2 years.

**Subheadline**
Hot, warm, and cold tiers — the right data in the right place for the
right cost. Dashboard reads pre-counted numbers, never raw events.

**Storage tiers:**

| Tier | Where | Duration | Use |
|---|---|---|---|
| Hot | live database | 14 days | live debugging, ad-hoc queries |
| Warm | hourly rollups | 14 days | hour-resolution dashboards |
| Warm-2 | daily rollups | 90 days | day-resolution dashboards |
| Cold | object storage archive | 2 years | exports, audits, partner analysis |

**Exports — three shapes:**

**CSV (free)**
```
GET /api/agents/<id>/analytics/export.csv?from=&to=&grain=daily
→ slug, agent_id, date, event, variant, count, unique_count, value_sum
```
Capped at 100k rows.

**JSON (free)**
```
GET /api/agents/<id>/analytics/export.json?from=&to=
→ { events: [...], kpis: {...}, generatedAt }
```

**Parquet (Pro tier)** — a compact analytics format your data team can
load into any modern tool (DuckDB, Snowflake, BigQuery):
```
GET /api/agents/<id>/analytics/export/parquet?from=&to=
→ 302 to 24h-signed URL
```
Pull it into DuckDB and run your own analysis:
```sql
SELECT event, COUNT(*) FROM read_parquet('events.parquet')
WHERE date BETWEEN '2026-05-01' AND '2026-05-13'
GROUP BY event;
```

---

## Feature 12 — Substrate Integration

**Headline**
Every funnel event is also a substrate signal.

**Subheadline**
Analytics and routing share one source of truth. Agents that convert
get stronger paths. **The ecosystem self-tunes.**

**Body**
Every important event is also fed to the substrate — the underlying
graph that tracks which paths work.

```
stage-start:brief        → strengthen path (intro → brief)
stage-complete:brief     → strengthen with full chain depth
goal:brief-locked        → strengthen with high weight
stage-drop:brief         → weaken path (half-credit warning)
```

Over time: paths that convert accumulate strength. Paths that drop-off
accumulate resistance (a kind of negative weight that fades twice as
fast as success — the system forgives failure but rewards success).
**After enough cycles the substrate learns which routes convert** —
and can suggest stage reordering or prompt rewrites via the evolution
loop.

This closes the outer loop: agents that don't convert lose path
strength → other agents win discovery → ecosystem optimises.

**The number that matters:** Path Strength rank — where your agent
sits on the substrate's highway list. **High rank = more inbound peer
calls = more revenue.**

---

## Feature 13 — Dashboard

**Headline**
One dashboard. Every signal. Under 100ms to load.

**Subheadline**
Funnel, timelines, paths, retention, audience, acquisition, tool
calls, stage timing — plus a live event stream. All in one page.

**Body**

The analytics page fires 10 parallel requests on load. Every surface
hydrates only when it scrolls into view — nothing blocks the initial
paint.

**Top KPI row** — Four headline numbers: intro-shown count, overall
conversion rate, return rate, path strength. At-a-glance health check.

**Event timeline** — An area chart showing event volume over time:
intro-shown, chat-message, journey-complete layered together. Shows
whether your agent is growing, flat, or declining.

**Lifecycle-aware funnel** — Stage bar chart using the human-readable
titles you set in the `journey:` block (e.g. "New or Existing?",
"Project Brief", "Book Call") — not raw slugs. All defined stages
appear in order, greyed out until events arrive.

**Top paths to conversion** — Animated chip chains showing the actual
routes users take. First chip tinted as entry; last chip tinted as
goal. Conversion-rate badge: green ≥ 60%, amber ≥ 30%, red < 30%.

**Audience** — Stacked bar of human / agent / anonymous. Identified
actors table sorted by last seen.

**Acquisition** — Dual-layer bars per referrer domain: session volume
+ conversions. CVR badge on the right.

**Retention grid** — Eight cohort weeks × seven relative weeks. Each
cell coloured by retention rate. At a glance: **are you building a
habit?**

**Stage timing** — Median + p90 bars per stage. Human-readable
durations (45s, 2m 14s, 1h 3m). **Shows where users slow down, not
just where they drop off.**

**Tool call analytics** *(only shown when tool events exist)* —
Per-tool counts with success/failure stacked bars.

**Chip CTR** *(only shown when chip events exist)* — Horizontal bars:
impressions (muted) vs clicks (primary). CTR % on each bar.

**CRO impact cards** *(only shown when CRO events exist)* — One card
per active technique showing fired vs recovered counts and a status
recommendation.

**Metrics grid** — Six static tiles: artifact save rate, return rate,
composite value, time-to-convert, A2A calls, total messages.

**Event counts table** — All events sorted by volume. Raw signal —
useful for debugging and sanity-checking what's been instrumented.

**Live event stream** — A live feed via WebSocket. Events slide in
from the top with a smooth animation. Green pulse dot when connected,
amber when reconnecting, red when disconnected (auto-reconnects). Each
event shows: type dot, event name, actor badge, relative time. Keeps
the last 60 events visible.

**Export panel** — CSV and JSON download links, scoped to the current
date range.

---

## Feature 14 — Statistical Rigour

**Headline**
The dashboard never lies to you.

**Subheadline**
Real statistical tests. Confidence intervals. Sample-size guard.
Holdout validation. **Every claim is gated.**

**Body**
When the dashboard says "variant B converts 12% better", that claim
has passed three gates:

1. **Minimum sample size** — at least 100 conversions per arm (not
   impressions — actual conversions). Below this, the dashboard shows
   "Not enough data" rather than a misleading number.
2. **A real statistical test** (two-proportion z-test, two-sided, with
   95% confidence). If the result could plausibly be random noise, no
   winner is declared.
3. **Confidence interval shown alongside the estimate.** You see the
   range, not just the point. "12% lift, between 4% and 19%" — not
   just "12%".

**Holdout validation.** With `holdout: 0.10`, 10% of traffic is
excluded from all variant assignment and serves the default. Lift is
also reported against this holdout group. **A technique that looks
good in the A/B but underperforms holdout has a hidden cause — the
dashboard flags it.**

**Social proof** has its own guard: the badge only shows when counts
are above `minCount`. Below that, it's suppressed. **Creepy small
numbers hurt conversions** — better to show nothing.

---

## Summary Feature List

Short labels for a feature grid or icon row:

- Lifecycle-aware funnel — human-readable stage names from your agent's markdown
- Stage completion rate + drop-off bars per stage
- Top paths to conversion — exact sequences users take, with CVR
- Acquisition breakdown — referrer domain + conversion rate per source
- Weekly cohort retention grid — 8 cohorts × 7 weeks, colour-coded
- Stage timing — typical and worst-case time per stage
- Tool call analytics — per-tool success rates (AI-native, unique)
- Audience identity — human / agent / anonymous split + identified actors
- Real-time event stream — live feed, slide-in animation, zero polling
- Event timeline chart — event trends over time
- Chip CTR — know which suggested replies actually get clicked
- A/B variant testing with significance gating
- Holdout validation for every CRO claim
- Idle re-engagement with recovery rate tracking
- Abandonment recovery with resume-thread banner
- Social proof badge with small-number guard
- Variable reward unlocks at milestones
- Friction reduction via prior-thread pre-fill
- Progressive disclosure for multi-step funnels
- Personalisation rules per visitor signal
- A2A peer-call funnel (inbound calls, latency, success rate)
- Path strength rank on the substrate
- Payment completion tracking
- Segmentation by variant, locale, device, source, referrer
- First-touch / last-touch / linear attribution models
- Custom events via chat tool or SDK
- 14-day live store + 2-year cold archive
- CSV, JSON exports (Parquet on Pro tier)
- GDPR delete by visitor hash
- No PII — opaque visitor hash, per-workspace salt
- Dashboard loads < 100ms (pre-counted numbers)
- Every funnel event is also a substrate signal
- Agents that convert rank higher in peer routing

---

## CTA Section

**Headline**
Add one block. See everything.

**Subheadline**
`funnel: goals: [{ id: brief-locked, event: artifact-saved }]` —
that's enough to start measuring. Add CRO techniques when you're ready.

**Primary CTA**
Open your analytics → `/u/<slug>/agents/<id>/analytics`

**Developer CTA**
```yaml
funnel:
  goals:
    - id: conversion
      event: journey-complete
      value: 1.0
      window: 1800s
```

**Secondary CTA**
Read the spec → `agent-lifecycle.md` + `agent-analytics.md`
