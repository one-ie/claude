# agent-lifecycle.md — the funnel, KPIs, and conversion optimisation

Every agent walks a visitor through a **funnel** — a sequence of stages
that ends in one or more **goals** (artifacts produced, payments made,
shares sent). The funnel is measured by **KPIs** and tuned by **CRO
techniques** declared in the agent's `.md` and computed server-side.

The visitor can be a **human** (a person on `/studio/<id>`) or another
**agent** (peer routing via `/api/agents/discover` and pheromone). Same
funnel shape, different signal sources.

**Two-doc split:** *this* doc owns *what* the funnel is and *how* to
tune it (stages · goals · CRO knobs · KPI definitions). The companion
**[agent-analytics.md](agent-analytics.md)** owns *the measurement
plumbing underneath* (event taxonomy · D1 schemas · query patterns ·
attribution · segmentation · statistical rigour · retention · exports).
Two ends of the same wire — change an event name in one, update the
other.

Also distinct: **`agents-lifecycle.md`** documents the *agent's own
state machine* (draft → live → paused → evolving → archived). Different
layer; both lifecycles co-exist on the same agent.

---

## The mental model

```
                    ┌──── Discovery ────┐
                    ▼                   │
                Interest ─┐     return  │
                    │     │ ←────────── │
                    ▼     ▼             │
                Consideration ─ idle ──→│
                    │                   │
                    ▼                   │
                Activation ─ abandon ──→│
                    │                   │
                    ▼                   │
                Engagement ─ stall ────→│
                    │                   │
                    ▼                   │
                Goal / Conversion ─────→ Retention
                    │                       │
                    ▼                       ▼
                Advocacy ────────────── Referral
```

Each transition is a **measurable event**. Each event can fire **CRO
optimisations** (idle re-engagement, abandonment recovery, social proof).
Each path through the funnel earns or loses **pheromone** so the
substrate learns which routes convert.

---

## Frontmatter — the `funnel:` block

The funnel block is the contract. Everything below is optional except
`goals` (you can't measure without a goal).

```yaml
funnel:
  # ── Goals ──────────────────────────────────────────────────────────
  # Each goal is one conversion definition. Multiple goals = multi-step
  # funnel where every goal is a milestone, not a binary outcome.
  goals:
    - id: brief-locked                # kebab-case, used as event name
      name: Brief Locked              # human label for dashboard
      stage: brief                    # journey stage this goal belongs to
      event: artifact-saved           # trigger event (from analytics events)
      eventMatch:                     # optional filter
        artifactType: brief
      value: 1.0                      # weight in composite conversion score
      window: 600s                    # max time from stage-start to count

    - id: campaign-shipped
      name: Campaign Shipped
      stage: ship
      event: chip-click
      eventMatch: { id: ship-it }
      value: 5.0                      # higher value goal
      window: 1800s

    - id: artifact-shared
      name: Artifact Shared           # downstream goal
      event: share-link-copied
      value: 3.0
      window: 86400s

  # ── Stage configuration ────────────────────────────────────────────
  # Extends journey.stages by id. Adds funnel semantics — what counts as
  # success vs partial vs drop-off, and how long the window is.
  stages:
    - id: brief
      window: 300s                    # expected duration of this stage
      goal: brief-locked              # the goal that closes this stage
      successSignal:
        event: artifact-saved
        within: 300s                  # signal must arrive within window
      partialSignal:                  # not full conversion but engaged
        event: chip-click
        chipId: refine
      dropSignal:
        idleAfter: 60s                # silent for 60s → drop-off recorded

  # ── KPIs ────────────────────────────────────────────────────────────
  # Which metrics to compute and surface on the dashboard. All are
  # computed by default if `kpis:` is omitted; this lets authors trim.
  kpis:
    - stageCompletionRate
    - timeToConversion
    - dropOffByStage
    - chipCtr
    - artifactRate
    - returnRate7d
    - variantLift
    - pathStrength                    # only meaningful for A2A funnels

  # ── Optimisation — CRO knobs ────────────────────────────────────────
  # Each technique opts in via `enabled: true`. Defaults are conservative.
  optimization:

    idleReengagement:                 # silent for N seconds → nudge
      enabled: true
      after: 30s                      # silence threshold
      maxFires: 2                     # don't nag past this
      prompt: "Still working on this? Want to see an example?"

    abandonmentRecovery:              # return after exit → resume thread
      enabled: true
      windowDays: 14                  # how stale a thread can be
      banner: "Welcome back — pick up where you left off?"

    socialProof:                      # "247 users completed this today"
      enabled: true
      minCount: 50                    # don't show below this (creepy)
      windowDays: 7                   # rolling window for the count
      anonymise: true                 # never expose identifiable counts

    progressiveDisclosure:            # gate stage N until stage N-1 done
      enabled: false                  # default off — adds friction
      stages: [draft, review, ship]   # only these gated; earlier always open

    variableReward:                   # surprise unlock at milestone
      enabled: true
      triggers:
        - after: brief-locked
          unlock: free-headline-skill # gives the user a paid skill free
        - after: campaign-shipped
          unlock: founder-pack

    frictionReduction:                # pre-fill from prior thread
      enabled: true
      preFillFromThread: true
      preFillFields: [audience, outcome, channels]

    scarcity:                         # use sparingly
      enabled: false
      messages:
        - "Premium template — 3 spots left this week"

    variants:                         # A/B testing
      assignment: cookie              # cookie | uid | random-per-visit
      arms:
        A: { weight: 0.5, prompt: "Help me lock the brief…" }
        B: { weight: 0.5, prompt: "I have a half-baked idea. Tell me where to start." }
      goalForWinner: brief-locked     # which goal decides the winner
      minSampleSize: 100              # don't pick a winner under this

    personalisation:                  # adapt to visitor signals
      enabled: true
      rules:
        - when: returning              # has prior thread
          seedPrompt: "Continue where you left off, or start fresh?"
        - when: variant=B
          quickReplies: ["Half-baked idea", "Show me an example"]

  # ── Visitor type — human vs agent ──────────────────────────────────
  # Default: visitorTypes: [human]. Add agent for peer-routed funnels.
  visitorTypes: [human, agent]

  # ── A2A-specific (only used when visitorTypes includes agent) ──────
  a2a:
    discoverable: true                # listed in /api/agents/discover
    capabilities: [draft-email, headline-variants]  # advertised skills
    pricing:
      currency: USDC
      rate: 0.05                      # per skill execution
    pheromoneTags: [marketing, copy]  # for routing
    sla:
      p95LatencyMs: 4000              # promise
      successRate: 0.90               # minimum acceptable
```

The funnel block is **schema-validated** like everything else — the
agent loads even when partial, but the dashboard surfaces warnings
where signals can't be resolved.

---

## KPI definitions (the math)

Every KPI is computed from `agent_events` rows. Definitions:

| KPI | Formula | Surface |
| --- | --- | --- |
| **Stage Completion Rate (SCR)** | `count(successSignal) / count(stage-start)` per stage | Funnel chart |
| **Drop-off** | `1 - SCR` per stage | Funnel chart (red bars) |
| **Time-to-Conversion (TTC)** | `successAt - stage-startAt`, percentiles | Histogram |
| **Chip CTR** | `count(chip-click of id X) / count(chip impressions of id X)` | Top-chips table |
| **Artifact Rate** | `count(artifact-saved) / count(unique visitors)` | Headline number |
| **Return Rate 7d** | `count(uid with visits ≥ 2 in 7d) / count(uid with visit 1 in 7d)` | Cohort line |
| **Variant Lift** | `(B goal rate / A goal rate) - 1`, with sample-size check | A/B card |
| **Conversion Value (CV)** | `Σ goalValue × goalCount` | Headline number |
| **Path Strength** | pheromone strength on edges entering this agent (A2A) | Agents graph |

All KPIs share a `from`/`to` query param. Default window = last 7 days
rolling. Daily aggregates are pre-computed via a cron (`billing-cron`
pattern) so dashboards load < 100ms.

---

## Standard events the agent emits

The runtime fires these automatically. Custom events can be added via
`emit_event` chat tool (planned).

| Event | When | Payload |
| --- | --- | --- |
| `intro-shown` | Studio loads, hero visible | `{ agentId }` |
| `stage-card-impression` | Stage card enters viewport | `{ agentId, stageId }` |
| `stage-start` | User clicks a stage card | `{ agentId, stageId }` |
| `stage-complete` | `successSignal` fires within `window` | `{ agentId, stageId, durationMs }` |
| `stage-drop` | `dropSignal` triggers (idle, navigated away) | `{ agentId, stageId, reason }` |
| `chip-impression` | Chip appears in chat trail | `{ chipId, stageId }` |
| `chip-click` | User clicks chip | `{ chipId, stageId }` |
| `chat-message` | User sends a turn | `{ agentId, role, threadId }` |
| `chat-tool-call` | LLM calls a tool | `{ tool, threadId }` |
| `chat-tool-output` | Tool returns | `{ tool, ok, threadId }` |
| `artifact-saved` | Output saved via OUT2 endpoint | `{ artifactId, artifactType, threadId }` |
| `share-link-copied` | User copies a share URL | `{ threadId }` |
| `journey-complete` | All declared goals fire | `{ agentId, durationMs }` |
| `idle-nudge-fired` | CRO idle-reengagement fired | `{ stageId, fireCount }` |
| `variant-assigned` | Visitor assigned to A or B | `{ variant, stageId }` |

For **A2A funnels**, additional events:

| Event | When |
| --- | --- |
| `peer-discovery-query` | This agent queries `/api/agents/discover` |
| `peer-route-selected` | Pheromone routing picks a peer |
| `peer-call-issued` | This agent calls another agent's skill |
| `peer-call-result` | Result returned (with `ok` and `latency`) |
| `pheromone-mark` | Path strengthened (success) |
| `pheromone-warn` | Path weakened (failure) |
| `x402-receipt-verified` | Payment settled |

---

## CRO techniques — what each one actually does

### 1. Idle re-engagement

After `N` seconds of chat silence on a stage, the server emits a
re-engagement message into the chat stream as an `assistant` turn (with
`metadata: { kind: 'idle-nudge' }` so the client can dim or icon it).
Caps at `maxFires` so the agent doesn't nag.

**Implementation:** WebSocket / SSE keep-alive on the chat stream
detects silence; runs `prompt` through the LLM as a continuation seed.

**KPI impact:** measure `recovered-after-idle / total-idle-nudges`.
If < 10%, the nudge is annoying — recommend disabling.

### 2. Abandonment recovery

When a visitor returns and a thread exists within `windowDays`, the
intro shows a banner with the `banner` text. Click → resume the thread.
Click "Start fresh" → archive prior and create new.

**Implementation:** cookie `agent:<id>:lastThread = <tid>:<ts>`; banner
on intro when `(now - ts) < windowDays`.

**KPI impact:** lifts `returnRate7d` directly; measured as banner CTR
× resumed-thread-conversion-rate.

### 3. Social proof

Below the hero: "247 users locked their brief this week." Pulled from
the goal event count over `windowDays`, ≥ `minCount` floor to avoid
creepy small numbers.

**Implementation:** D1 aggregation cached in KV 1h.

**KPI impact:** lifts intro→stage-start CTR. Measure delta in the
funnel chart with/without the badge (A/B).

### 4. Progressive disclosure

Stages listed in `stages: [draft, review, ship]` are visually disabled
(grey card) until the previous stage's goal fires. Reduces choice
overload but adds friction — default off.

**Implementation:** client reads `analytics.stageCompletions` from a
session-scoped endpoint, hides locked stages.

**KPI impact:** when conversion-per-attempt rises but attempts drop,
this is the right tool. Otherwise it's friction.

### 5. Variable reward

Surprise unlock at a milestone — e.g. "🎁 Free headline-variants skill
unlocked." Powerful because the reward isn't promised, so the surprise
is the dopamine hit.

**Implementation:** when `after` event fires, write a row to
`{slug}/users/<uid>/unlocked` and surface in chat as a notification.

**KPI impact:** lifts retention. Measure via cohort returns.

### 6. Friction reduction

When `preFillFromThread: true`, the second visit's chat opens with the
prior thread's last-known field values pre-injected as system context.
The agent can ask "Audience was 'solo founder' last time — still
right?" instead of starting over.

**Implementation:** lib/threads.ts surfaces last `agent:summary` event
payload to the next chat call as a system message.

**KPI impact:** drops TTC for returning users.

### 7. Scarcity

"Premium template — 3 spots left." Use sparingly; degrades trust if
abused. Always tie to a real constraint (limited license count,
time-boxed campaign).

**Implementation:** simple counter in KV; UI surfaces the count.

**KPI impact:** lifts immediate conversion but can hurt
return/advocacy if perceived as manipulation. Track both.

### 8. A/B variants

Per-visit cookie pins the visitor to arm A or B. Each arm has its own
`prompt`, `seedPrompt`, or `quickReplies`. Winner is the arm with
higher `goalForWinner` rate over `minSampleSize`.

**Implementation:** `agent-loader.ts` assigns + persists variant; chat
endpoint reads cookie and rewrites system prompt accordingly.

**KPI impact:** Variant Lift KPI; substrate marks the winning prompt
path so future evolution favours it.

### 9. Multivariate (planned, Phase 3+)

Different variants per stage, independently optimised. E.g. arm A's
brief stage + arm B's ship stage. Computed as 2^N combinations.

### 10. Personalisation

Rules like "if returning, swap seed prompt." Each rule has a `when`
condition (returning, variant=B, locale=vi, hour-of-day, etc.) and an
override. Server applies rules in order; first match wins.

**Implementation:** `lib/personalisation.ts` evaluates rules against
the visitor context object.

**KPI impact:** lifts conversion for the targeted cohort; measure
holdout to confirm.

---

## The dashboard — `/u/<slug>/agents/<id>/analytics`

Three views:

### 1. Funnel — top section

```
Discovery   1,247 visits  ████████████████████████████  100%
Intro       1,089 (87%)    █████████████████████████      87%
Stage start   742 (59%)    █████████████████              59%
Stage compl.  398 (32%)    █████████                      32%   ← biggest drop
Goal          224 (18%)    █████                          18%
```

Click a bar → segmented view (variant, locale, referrer).

### 2. KPIs — middle section

Headline numbers with sparklines: CV, Artifact Rate, Return Rate 7d,
top chip CTR, variant lift.

### 3. Optimization — bottom section

Per-technique impact card:

```
┌─ Idle re-engagement ─────────────────────────────┐
│ Fired: 84 times  ·  Recovered: 12 (14%)          │
│ Status: ⚠ Below 15% — consider raising threshold │
└──────────────────────────────────────────────────┘
```

Each card has an "Apply this change" CTA that prefills a PR against
the agent's `.md` (when the partner has Git integration via TOOL3).

---

## Human funnels vs A2A funnels

**Human funnel** — measures clicks, dwell time, conversions.
Optimisations: nudges, banners, social proof.

**A2A funnel** — measures peer calls, payment volume, path strength.
Optimisations: pricing, SLA, capability advertisement.

Both run on the same goal/event model. The dashboard switches view
based on `visitorTypes`. An agent that serves both gets two funnels
side-by-side.

For **A2A**, the funnel question is: "do other agents successfully use
me?" The proxy KPIs are:

| KPI | Math | Why it matters |
| --- | --- | --- |
| **Inbound peer calls** | `count(peer-call-issued WHERE target=me)` | Demand |
| **Skill success rate** | `count(peer-call-result WHERE ok=true) / count(peer-call-issued)` | Quality |
| **p95 latency** | from `peer-call-issued` to `peer-call-result` | SLA proof |
| **Outbound mark rate** | `count(pheromone-mark from me) / total calls from me` | Path quality |
| **Payment completion** | `count(x402-receipt-verified) / count(peer-call-result OK & priced)` | Revenue |
| **Path strength rank** | this agent's rank on `/api/loop/highways` | Substrate value |

If `pheromoneTags` is set, the dashboard groups by tag — useful for
agents that serve multiple capability domains.

---

## Substrate integration — pheromone routing

Every funnel event fires a substrate signal:

```
agent:<id>:intro-shown        → mark edge (referrer → agent)
agent:<id>:stage-start:brief  → mark edge (intro → brief)
agent:<id>:stage-complete:brief → mark edge with full chainDepth
agent:<id>:goal:brief-locked  → mark with high weight
agent:<id>:stage-drop:brief   → warn edge (0.5)
```

Cumulative effect: paths that convert get stronger; paths that drop
get resistance. After enough cycles the substrate **learns the agent's
optimal funnel shape** and can suggest stage reordering, prompt
rewrites (via L5 evolution loop), or partner-agent introductions.

This closes the substrate's outer loop: agents that don't convert lose
strength → other agents win discovery → ecosystem self-tunes.

---

## Files this spec touches

```
NEW
  web/src/lib/funnel.ts                  → goal resolution, KPI compute, CRO dispatch
  web/src/lib/cro/*.ts                   → one file per technique (idle, abandonment, social-proof, ...)
  web/src/pages/api/funnel/[id]/kpis.ts  → KPI compute endpoint
  web/src/pages/api/funnel/[id]/events.ts → event ingestion (extends AN1)
  web/src/pages/u/[slug]/agents/[id]/funnel.astro → dashboard (extends AN4)
  web/src/components/funnel/FunnelChart.tsx
  web/src/components/funnel/VariantCard.tsx
  web/src/components/funnel/OptimizationCard.tsx
  migrations/00XX_funnel_aggregates.sql  → daily roll-up table for fast dashboard

MODIFIED
  web/src/lib/agent-schema.ts            → add `funnel:` block schema
  web/src/lib/agent-md.ts                → add types
  web/src/lib/agent-loader.ts            → variant assignment
  web/src/pages/api/chat.ts              → personalisation rules, idle nudge dispatch
  web/src/components/Chat.tsx            → idle detection, abandonment banner, social proof badge
  web/src/components/journey/JourneyShell.astro → progressive disclosure visual states
  agent-features.md                      → reference this doc
  agent-features-todo.md                 → add Phase 2.5 wave
```

---

## Compatibility invariants (don't break)

1. **Funnel is optional.** Agents without `funnel:` still load; dashboard shows only basic event counts.
2. **Events are append-only.** Never edit or delete event rows; aggregations recompute from source.
3. **CRO techniques are independent.** Disabling one doesn't affect another.
4. **Privacy first.** No PII in event payloads. Visitor identification via opaque cookie hash; no IP, no email.
5. **Sample-size guard.** Variants don't pick a winner under `minSampleSize`. Social proof doesn't display under `minCount`.
6. **Pheromone marks fire-and-forget.** Funnel events never block chat response.
7. **Same schema, human + agent.** The funnel block doesn't bifurcate; only `visitorTypes` and `a2a:` change behaviour.

---

## What "lifecycle complete" means

| Dimension | Target |
| --- | --- |
| Goal resolution | < 5ms per event |
| KPI dashboard load | < 100ms p95 (pre-aggregated) |
| Variant assignment | < 1ms (cookie read + write) |
| Idle nudge latency | within 2s of threshold |
| Event ingestion | < 30s lag from emit to dashboard |
| Aggregation freshness | hourly roll-up max |
| A2A peer-call SLA | matches advertised p95 |

If any regress when a feature ships, the feature fails the rubric.

---

*Funnel as code. Goals as events. CRO as YAML. Every conversion is a
pheromone signal. Every agent learns its own optimal shape — and the
substrate routes to the agents that convert.*
