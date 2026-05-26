# tracking-realtime.md — the brain at the edge, applied

Companion to [`tracking.md`](tracking.md). Tracking lands events. This
doc is what we **do** with them in the same tick they land. Twenty
use cases, ranked by impact × novelty × the latency it would cost
anyone else to copy us.

**Substrate live as of 2026-05-14:** `POST /api/events` → WorkspaceDO (rollups, WAL, pheromone world) → `useWatch()` SSE → client. Six primitives (`mark/warn/sense/follow/select/highways`) + `snapshotForActor()` RPC operational. Identity rungs 0-1 wired (`cookieId`, `visitorHash`). `/go/:id` tracked redirect live. Use cases below marked ✅ are unblocked by the baseline.

The whole doc rests on one primitive:

> Because TypeDB lives in RAM inside the same Durable Object that
> accepted the event and holds the WebSocket fan-out, "who is this
> actor, what path are they on, what should we do next" is an **O(1)
> read in the same process that just accepted the write**. No
> warehouse round-trip. No feature store. No ML service hop.

Every other CRM has to **export** to do realtime. We don't.

---

## The realtime architecture, in one picture

```
   event lands
        │   (HMAC, consent gate — 3 ms)
        ▼
   Workspace DO (RAM)
        │
        ├── TypeDB.apply(event)         O(1)  — graph + paths updated
        ├── rollups.bump(key)           O(1)  — counters bumped
        ├── pheromone.mark(edges)       O(1)  — tag pairs strengthened
        │
        ├──▶ watchers waking            (chat agent, page island, ad fan-out)
        │
        ├──▶ world.follow(tag_path)     O(log n) — next-best-action returned
        │
        └──▶ world.highways(prefix)     O(log n) — segments / recs returned

   total wall-clock event-to-personalized-response: < 50 ms p99
```

Six primitives do all the work. They are already in the substrate
(`engine.md` rules, `world.ts`):

```ts
world.mark(edge, w?)         // strengthen path on success
world.warn(edge, w?)         // weaken on failure
world.sense(edge)            // current strength
world.follow(from)           // deterministic best-next edge
world.select(from)           // probabilistic, pheromone-weighted (ant-like)
world.highways(prefix?, n?)  // top-N edges, optionally tag-prefix-filtered
```

If you can spell your use case as a combination of those six, it runs
at edge speed.

---

## The ranking — five tiers

Each use case scored 1–5 on four axes:

```
  Impact     revenue / UX delta if shipped well
  Novelty    "does any current CRM/CDP do this realtime?"
  Latency    how badly it NEEDS sub-100ms (vs. could be batched)
  Ready      primitives + storage already in tracking.md
```

The sum picks the tier. The tier picks the order to ship.

---

# Tier 1 — Transformative (sum ≥ 18)

The five use cases that make ONE not-comparable to other CRMs.
Each leans on the brain-at-the-edge primitive in a way that's
*structurally impossible* for a warehouse-based stack to copy.

### #1 — Chat that already knows you · score 20  ✅ SHIPPED

**Impact 5 · Novelty 5 · Latency 5 · Ready 5**

> **Status:** shipped via `web/src/lib/actor-snapshot.ts` + `web/src/pages/api/chat.ts`.
> System-prompt composition appends a `\n\nRecent activity: …` suffix derived
> from `AnalyticsRelay./snapshot` (50 ms p99 budget, silent degrade on timeout).
> Demo gate: `bun vitest run tests/e2e/tracking-realtime/c1-snapshot-chat.test.ts` — 7/7.

When a visitor opens `/chat`, the agent's system prompt is hydrated
from the DO in a single RPC: identity-ladder rung, last 10 events,
current campaign, persona tags, suppression state, `appended.stripe.*`
LTV, `appended.clearbit.*` firmographics, last 3 conversations.

```ts
const ctx = await workspaceDO.snapshotForActor(actorId)
// ctx = { ladder, recent, campaign, persona, lifecycle, append, threads }

const systemPrompt = compose(basePrompt, ctx)
// agent first reply lands < 200ms after page-open — already personalized
```

**Primitives:** `snapshotForActor()` (new RPC on the DO — reads
TypeDB + rollups + recent in one pass). Already serializable from RAM.

**Why structural:** every other tool would have to query Snowflake +
HubSpot + Stripe + Intercom and stitch. We have one tick.

---

### #2 — Surface-aware agent triggers · score 20  ✅ SHIPPED (substrate)

**Impact 5 · Novelty 5 · Latency 5 · Ready 5**

> **Status:** substrate shipped via `web/src/lib/agent-triggers.ts` (pure
> `evalTriggers` with cooldown state) + `web/src/workers/analytics-relay.ts`
> trigger registry + per-event eval in `accept()` + `agent:<id>` topic
> broadcast. Production loads `triggers:` from agent.md frontmatter via R2;
> tests inject via `setTriggerRegistry()`. Demo gate:
> `bun vitest run tests/e2e/tracking-realtime/c2-agent-trigger.test.ts` — 6/6.
> **Deferred:** Chat.tsx unsolicited-message UI — frame already arrives on
> `agent:<id>` SSE; client-side rendering can ship in a follow-up cycle
> without re-touching the DO.

The agent has a live watcher on every visitor it's been introduced to.
The DO tells it 50ms after the pageview lands. The agent appears
contextually:

```
visitor on /pricing for the 3rd time this week, stalled 30s
  → DO emits agent-trigger:{actor_id, surface:'/pricing', dwell:30s, visits:3}
  → agent: "I see you're back on pricing — want me to walk through tiers?"

visitor abandoned a form mid-fill, exit-intent fired
  → DO emits agent-trigger:{actor_id, form_id, fields_filled:3, exit:true}
  → agent: "Want me to save that for later? You filled in name + company."
```

**Primitives:** Watcher topic `agent:<agent_id>` filtered by surface
events; trigger predicate evaluated in the DO before fan-out so cold
triggers cost nothing.

**Why structural:** other tools fire emails ten minutes after exit.
We fire an agent in the page in the same tick the visitor stalls.

---

### #3 — Next-best-action without a model call · score 19  ✅ SHIPPED

**Impact 5 · Novelty 5 · Latency 4 · Ready 5**

> **Status:** shipped via `web/src/pages/api/follow/[from].ts` — thin Astro proxy
> over `AnalyticsRelay./follow` + `/sense` returning `{from, to, strength}`.
> `Cache-Control: max-age=5, stale-while-revalidate=30`. Demo gate:
> `bun vitest run tests/e2e/tracking-realtime/c3-follow-api.test.ts` — 6/6.

`world.follow(visitor_tag_path)` returns the highest-strength outgoing
edge from the visitor's current position. **That IS the
recommendation** — pheromone strength is the score.

```ts
// visitor's current tags: [persona:founder, channel:telegram, campaign:apr-q2]
const next = world.follow('persona:founder')
// → 'thing:doc:quickstart-go'  (strength 0.84)

// returned in <1ms, no LLM call, no API call to a recs service
```

The LLM only runs for **new** cases the substrate hasn't seen yet. The
well-trodden paths are pure graph lookups. Inverts the cost shape of
every recommender — cheapest case is the most common.

**Primitives:** `world.follow()` / `world.select()` — already in
`engine.md`. Tag conventions enforced by ingest order rule (§9.1 of
tracking.md).

**Why structural:** the recommender *is* the analytics database.
There's no separate feature pipeline to keep in sync.

---

### #4 — Live page personalization · score 19  ✅ SHIPPED (substrate; index.astro swap deferred)

**Impact 5 · Novelty 4 · Latency 5 · Ready 5**

Astro island calls `useWatch('actor:<visitor_hash>')` on first paint.
The DO already has this visitor's tag-path and current rollups →
returns hero copy variant, CTA wording, pricing tier in the same
WebSocket message that primes the watcher.

```tsx
const { actor, recommendations } = useWatch(`actor:${visitorHash}`)
// arrives in < 100ms from first paint

return (
  <Hero
    headline={actor.persona === 'founder' ? FOUNDER_COPY : DEFAULT_COPY}
    cta={recommendations.next_cta}
    pricing={actor.lifecycle === 'lead' ? PRICING_TIER : DEFAULT_TIER}
  />
)
```

**Primitives:** Hibernating WebSocket + topic `actor:*` + DO-side
`personalize()` RPC that wraps `follow()` calls with content lookups.

**Why structural:** no SSR re-render, no flash-of-default-content;
the personalization flows in the first hydration packet.

---

### #5 — Predictive prefetch · score 18

**Impact 4 · Novelty 5 · Latency 4 · Ready 5**

`world.follow()` tells you the **most likely next page**. The Worker
server-pushes it before the user clicks.

```
pageview /pricing lands
  ↓
DO: world.follow('thing:page:/pricing') → 'thing:page:/buy/pro'
  ↓
Worker emits HTTP/2 Server-Push for /buy/pro (HTML + critical CSS)
  ↓
user clicks 8 seconds later
  ↓
page renders instantly — already in the browser cache
```

**Primitives:** `world.follow()` + Cloudflare's Early Hints (`103`)
+ `<link rel="prefetch">` injected into the current response. Both
already supported on Workers.

**Why structural:** the prediction quality compounds with traffic.
Every conversion strengthens the path; every prefetch hit shortens
the next user's session by ~1s.

---

# Tier 2 — High-impact (sum 15–17)

The next eight use cases. Each is a flagship feature in some existing
SaaS — but ours is real-time and free because the primitives are already
in the pipeline.

### #6 — Bandit-style A/B without a bandit service · score 17

**Impact 4 · Novelty 5 · Latency 3 · Ready 5**

Replace deterministic variant hashing with `world.select(variant_tag)` —
probabilistic, pheromone-weighted. Variants with stronger paths to
conversion automatically get more traffic. Underperformers fade.

```ts
// instead of: variant = hash(actor_id) % 2
const variant = world.select('variant:hero')  // → 'variant:hero:bold' (p=0.71)
```

L3 FADE = exploration rate. L4 ECONOMIC weight (amount × 10) =
exploitation pressure. **The substrate is the bandit.** No separate
`/experiments` service, no manual statistical-significance gate.

**Holdout still possible** via tagged-population segments per §6
of tracking.md.

---

### #7 — Ad targeting on the threshold-crossing event · score 17

**Impact 5 · Novelty 4 · Latency 3 · Ready 5**

CAPI loops in other tools batch on cron. Here, the DO fires
`attribution.sent → meta-capi` in the same tick a tag's path strength
crossed a threshold.

```
strength('persona:founder' → 'purchase') just crossed 100
  ↓
DO emits: meta-capi-rebuild:{audience:'founders-likely-to-buy', members:[...]}
  ↓
Meta lookalike seed updates in < 30s
  ↓
ad impressions to similar visitors next minute, not next day
```

**Primitives:** L6 KNOWLEDGE loop already promotes high-strength
paths to hypotheses; same hook publishes to ad platforms.

---

### #8 — Recommendations as tag-prefix queries · score 16

**Impact 4 · Novelty 4 · Latency 3 · Ready 5**

Same `world.highways()` primitive, different prefix:

```ts
world.highways({ from: visitorTags, to_prefix: 'thing:doc:' })     // docs recs
world.highways({ from: visitorTags, to_prefix: 'thing:product:' }) // product recs
world.highways({ from: visitorTags, to_prefix: 'thing:skill:' })   // skill recs
world.highways({ from: visitorTags, to_prefix: 'thing:agent:' })   // agent recs
```

One primitive serves every surface. Co-occurrence strength is the
score. Cold-start handled by tag-prefix shortening — fewer matching
tags → broader query.

---

### #9 — In-session funnel rescue · score 16  ✅ SHIPPED

**Impact 5 · Novelty 4 · Latency 4 · Ready 3**

When a visitor stalls at a known funnel step beyond a learned-normal
threshold, the agent appears with contextual help.

```
funnel-mined: /pricing → /buy/pro → /checkout (typical dwell: 12s, 35s, 90s)
visitor X: on /checkout for 180s, no progress, mouse idle
  ↓
DO emits: rescue-trigger:{actor_id, surface:/checkout, dwell:180s, stage:'payment'}
  ↓
agent message: "Stuck on the payment step? I can answer questions or
                offer a different plan if pro is too much right now."
```

**Primitives:** Workflow mining (§6.1 tracking.md) gives "typical
dwell." Stall detection = compare live dwell to mined baseline.

**Ready=3** because mined-baseline storage in TypeDB needs explicit
attribute support. Small lift.

---

### #10 — Live segment membership · score 16

**Impact 4 · Novelty 4 · Latency 3 · Ready 5**

Segments are **reactive queries**, not snapshots. A visitor enters /
leaves the `ent-trial-d7` segment in real-time. Watchers on
`segment:*` topics see joins/leaves as events.

```ts
useWatch('segment:ent-trial-d7')
// → { count, recent_joins: [...], recent_leaves: [...], drift: +5/min }
```

Email send / ad audience / Slack alert can all subscribe to segment
membership changes directly, no polling.

---

### #11 — Cohort-aware copy · score 15

**Impact 4 · Novelty 3 · Latency 3 · Ready 5**

A/B variants chosen by lifecycle stage, not by random hash:

```ts
const copy =
  actor.lifecycle === 'cold'       ? COLD_HOOK :
  actor.lifecycle === 'engaged'    ? PROOF_POINT :
  actor.lifecycle === 'evaluating' ? PRICING_DETAIL :
  actor.lifecycle === 'customer'   ? RETENTION_VALUE :
                                     DEFAULT
```

Same realtime hydration as #4; just a different read on the same
snapshot.

---

### #12 — Onboarding step-skipping · score 15

**Impact 4 · Novelty 4 · Latency 2 · Ready 5**

If a visitor's identity ladder reveals prior signals showing
competence (CLI verbs from another workspace, GitHub stars on
related repos, SDK init events on a sibling actor), skip the
tutorial.

```
new signup ada@example.com → email_hash matches:
  - cli.command(oneie agent new) × 12   (another workspace, 30d ago)
  - sdk.init × 4
  ↓
onboarding: skip "what is an agent" intro, jump straight to "deploy yours"
```

Counter to most CRMs that re-pitch the basics to every new account.

---

### #13 — Email send-time at engagement peak · score 15

**Impact 4 · Novelty 4 · Latency 1 · Ready 5**

The DO already holds `engage` event timestamps per actor. Bucket by
hour-of-week in RAM → send-time = `argmax(engage_strength)` for that
actor.

```
ada's hourly engage histogram (rolling 28d):
  mon 09: 12   mon 17: 28  ← peak
  tue 09: 18   tue 17: 22
  ...

next broadcast to ada → schedule for next Monday 17:00 local
```

**Latency=1** because batch-OK — but lookup is still RAM.

---

# Tier 3 — Specialized but powerful (sum 12–14)

Niche wins that compound when stacked with Tier 1.

### #14 — Live LTV scoring · score 14

**Impact 4 · Novelty 4 · Latency 2 · Ready 4**

Pheromone strength × economic weight = realtime LTV estimate. Updates
on every event:

```
ltv(actor) ≈ Σ (sense('persona:X' → 'purchase') × avg_purchase_size)
           + appended.stripe.mrr × expected_months_remaining

displayed live in /crm/c/:actor — moves while the user watches
```

---

### #15 — Cross-actor influence · score 14

**Impact 4 · Novelty 4 · Latency 2 · Ready 4**

"People like Ada (same persona+region+lifecycle) just did X" — pheromone
on shared tag prefix. The substrate already knows.

```
agent to ada: "3 other founders in your region just started trials this
              week — typical next step is deploying your first agent.
              Want me to walk you through it?"
```

Social proof, generated from the live tag graph, not a "trending now"
table.

---

### #16 — Predictive churn intervention · score 14

**Impact 5 · Novelty 3 · Latency 1 · Ready 5**

Inverse of journey enrollment. When `engage` pheromone decays below a
threshold (L3 FADE asymmetric), fire a rescue journey.

```
ada's engage strength: 0.82 → 0.71 → 0.58 → 0.41 (now)
  ↓ crosses churn_risk threshold
DO emits: churn-trigger:{actor_id, last_engage:8d_ago}
  ↓ enrols in journey 'win-back-d14'
```

---

### #17 — Inventory-aware product recs · score 13

**Impact 4 · Novelty 3 · Latency 3 · Ready 3**

Combine pheromone with live stock attributes. `world.highways()` with
a post-filter:

```ts
const recs = world.highways({ to_prefix: 'thing:product:' })
  .filter(edge => stock(edge.to) > 0)
  .slice(0, 5)
```

**Ready=3** because stock attributes need a sync from the source of
truth (Shopify importer already exists per §4 tracking.md).

---

### #18 — Knowledge base re-ranking · score 13

**Impact 3 · Novelty 4 · Latency 3 · Ready 4**

Search results re-ordered by which docs convert THIS persona. Same
`world.highways()` primitive scoped to tag `thing:doc:`, intersected
with the keyword match set.

```
search: "deploy"
  → static matches: [deploy.md, deploy-cli.md, deploy-cf.md]
  → reorder by world.sense('persona:founder' → 'thing:doc:<id>')
  → result: deploy-cli.md (0.71), deploy.md (0.42), deploy-cf.md (0.18)
```

---

### #19 — Predictive multi-agent handoff · score 12

**Impact 4 · Novelty 4 · Latency 2 · Ready 3**

Agent A sees an opportunity for agent B based on actor tags; passes
the actor with context. The substrate has been measuring which agents
succeed with which persona-tags.

```
support agent finishes ada's ticket; her tags now include
  [persona:founder, intent:expansion, lifecycle:engaged]
  ↓
world.follow('intent:expansion') from this agent → 'agent:sales:enterprise'
  ↓
context-packed handoff signal sent to sales:enterprise agent
```

---

### #20 — Voice / phone agent personalization · score 12

**Impact 4 · Novelty 3 · Latency 3 · Ready 2**

Twilio inbound webhook → DO read. The voice agent's opener is
`snapshotForActor()` like #1, but routed by phone-hash → actor lookup.

```
incoming call from +1-555-0123 → phone_hash → actor_id = ada
  ↓ DO snapshot
voice agent: "Hi Ada — I see you're on the Pro plan since March,
              and just opened a ticket about billing. Is that what
              you're calling about?"
```

**Ready=2** because the voice surface and Twilio integration aren't
in tracking.md yet.

---

# Tier 4 — Defensive / operational (sum 10–11)

Not customer-facing wins, but the substrate makes them free.

### #21 — Anomaly-driven alerts · score 11

When a path's strength **suddenly inverts** (your hero CTA stopped
converting at 3pm), the substrate notices before anyone refreshes a
dashboard.

```ts
// L3 FADE applies expected decay; an actual delta beyond that = alert
if (Δstrength > expected_fade × 5) emit('anomaly.detected', { edge, delta })
```

### #22 — Fraud blocking at the edge · score 11

The per-session token bucket already lives in the ingest Worker.
Extend with: "if this visitor's fingerprint matches a known-bad
cluster in RAM, return 204 before the event ever lands." Sub-ms.

### #23 — Live moderation · score 10

Inbound message content hashes matched against a bad-content cluster
in the same tick → route to human, mark `complaint`, don't deliver.

### #24 — Competitor intelligence routing · score 10

Known-competitor IP/ASN → different content surface. Tag
`actor:competitor:*` lives in the DO already; renderer reads it.

### #25 — Live consent re-prompt at value moment · score 10

When a visitor's path indicates they're about to convert, but their
consent is `denied` (so we lost rich context), show a contextual
re-prompt — "Want us to remember this for next time?"

---

# The complete ranking

```
Tier 1 — Transformative (sum ≥ 18)
  1.  Chat that already knows you            20
  2.  Surface-aware agent triggers           20
  3.  Next-best-action without a model       19
  4.  Live page personalization              19
  5.  Predictive prefetch                    18

Tier 2 — High-impact (sum 15–17)
  6.  Bandit-style A/B without a service     17
  7.  Ad targeting on threshold-crossing     17
  8.  Recommendations as tag-prefix queries  16
  9.  In-session funnel rescue               16
 10.  Live segment membership                16
 11.  Cohort-aware copy                      15
 12.  Onboarding step-skipping               15
 13.  Email send-time at engagement peak     15

Tier 3 — Specialized but powerful (sum 12–14)
 14.  Live LTV scoring                       14
 15.  Cross-actor influence                  14
 16.  Predictive churn intervention          14
 17.  Inventory-aware product recs           13
 18.  Knowledge-base re-ranking              13
 19.  Predictive multi-agent handoff         12
 20.  Voice / phone agent personalization    12

Tier 4 — Defensive / operational (sum 10–11)
 21.  Anomaly-driven alerts                  11
 22.  Fraud blocking at the edge             11
 23.  Live moderation                        10
 24.  Competitor intelligence routing        10
 25.  Live consent re-prompt at value moment 10
```

---

## What every use case actually leans on

A pleasing observation: 25 use cases, **six primitives** behind them
all. Multiplicity is in the *composition*, not in the implementation.

```
primitive             used by use cases
─────────             ─────────────────
follow / select       3, 5, 6, 8, 12, 14, 15, 17, 18, 19
highways              8, 10, 14, 15, 17, 18
sense                 11, 13, 14, 16, 21
mark / warn           every event (the input side of the others)
fade                  16, 21 (decay is the signal)
snapshotForActor      1, 4, 11, 20  (new RPC, composes the above)
```

Ship the six. The 25 use cases fall out.

---

## Latency budget per tier — what we promise

```
Tier 1   first response < 100 ms p99   (must)
Tier 2   first response < 500 ms p99   (should)
Tier 3   first response <   2 s  p99   (ok)
Tier 4   detection      < 30 s  p99   (eventually-correct fine)
```

The latency drop between Tier 1 and Tier 2 is the line above which the
brain-at-the-edge architecture **is the reason it works** — below it,
a normal warehouse stack would also fit.

---

## Implementation order

| Wave | Ships | Use cases unlocked |
| --- | --- | --- |
| R1 | `snapshotForActor()` RPC on workspace DO | 1, 4, 11, 20 |
| R2 | Trigger predicates inside DO + `agent:*` topic | 2, 9, 25 |
| R3 | `follow()` / `select()` / `highways()` exposed via Workers RPC | 3, 5, 6, 8, 12, 18 |
| R4 | Ad-platform fan-out on threshold crossing | 7 |
| R5 | Segment topic computation at write time | 10 |
| R6 | Lifecycle attribute hydration in DO | 11, 16 |
| R7 | Send-time histograms in DO RAM | 13 |
| R8 | LTV + churn predicates from sense + decay | 14, 16 |
| R9 | Anomaly + fraud + moderation predicates | 21, 22, 23 |
| R10 | Voice surface adapter (Twilio webhook → DO) | 20 |

R1 → R3 unlocks Tier 1 entirely. Every subsequent wave is
additive — none invalidates earlier shipped use cases.

---

## What we are NOT promising

| Anti-claim | Why |
| --- | --- |
| Sub-100ms LLM responses | The LLM call is OUR floor — but the substrate-only paths (#3, #6, #8) genuinely are sub-100ms because no LLM is invoked. |
| Lossless cross-region order | Per-actor causality is preserved (DO single-threaded). Across actors, ordering is best-effort. |
| Cold-start no-data personalization | The first event from a new visitor has no path. Until rung 1 lands, personalization falls back to defaults. |
| Pheromone replacing rigorous ML | Pheromone is a **strong baseline** that gets the obvious cases right cheaply. Hard cases still warrant a model — the substrate just stops paying for the easy ones. |

---

## The one-line summary

> Tracking writes typed events with hashed identity into a single
> store. Realtime turns that store into a brain at the edge: in the
> same Durable Object tick that accepted the event, six pheromone
> primitives — mark, warn, sense, follow, select, highways — produce
> the next action, the next page, the next message, the next ad. The
> chat already knows you. The page personalizes before it paints.
> The recommender is the analytics database. The bandit is the
> substrate. The CAPI fires while the user is still on the page.
> Twenty-five surfaces, six primitives, fifty milliseconds.

---

*Built on `tracking.md` Parts I–III, `engine.md` substrate verbs,
`world.ts` runtime. No new pipeline. No new store. The brain we
already have, applied to every surface that touches a visitor.*
