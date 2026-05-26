# Marketing Ontology

6 dimensions. Tags are the spine. Signals are the verbs. Campaigns are programs. Same substrate as [100-lines.md](100-lines.md). Marketing is a tag dialect.

**See Also:** [one-ontology.md](one-ontology.md) — the 6 dimensions. [100-lines.md](100-lines.md) — the substrate (schema + engine). [dictionary.md](dictionary.md) — names. This doc specialises them for marketing without adding new primitives.

> Marketing is a world. The world contains audiences (groups).
> Audiences contain people (actors), content (things), funnels (paths),
> touches (events), and personas (learning).
>
> Tags categorise. Signals execute. Pheromone learns.
> A campaign is code. The substrate runs it.

A campaign is not a new dimension — it's a `group`.
A funnel is not a new dimension — it's a `path` with stages.
A persona is not a new dimension — it's a `group` of type `persona`.
An offer is not a new dimension — it's a `thing` of subtype `offer`.
**Nothing in marketing requires a new entity. Everything is composition.**

---

## The Principle

```
        TAGS (the spine)              SIGNALS (the verbs)
        ─────────────────              ─────────────────────
        categorise everything         execute everything
        IAB, GA4, OpenRTB, schema.org impressions, clicks, sends
        persona traits                campaign programs
        offer levers                  attribution flows
        standards-compatible          Turing-complete
                       ↘            ↙
                        ONE substrate
                        100 lines schema · 100 lines engine
                        Marketing inherits.
```

Every concept in this doc reduces to: **tagged entities + signals between them**. Every standard plugs in as a tag namespace. Every campaign is a signal program. Every KPI is a query.

---

## 6 Dimensions — Marketing View

| # | Dimension     | Marketing meaning                                | Example                              | Biology      |
|---|---------------|--------------------------------------------------|--------------------------------------|--------------|
| 1 | **Groups**    | Audiences, segments, channels, campaigns, personas | "EU SaaS founders", "Q4 launch"   | Colony       |
| 2 | **Actors**    | Prospects, leads, customers, advocates, agents   | Anon visitor → lead → customer       | Foragers     |
| 3 | **Things**    | Content, offers, creative, products, keywords    | Landing page, ad creative, coupon    | Food sources |
| 4 | **Paths**     | Funnels, journeys, ladders, attribution chains   | Awareness → Consideration → Buy      | Trails       |
| 5 | **Events**    | Impressions, clicks, signups, purchases, churns  | `view`, `click`, `purchase`          | Foraging     |
| 6 | **Learning**  | Personas, ICPs, attribution weights, patterns    | "Founders convert on day 3 emails"   | Highways     |

```
AUDIENCE (group)
 ├── people/      anon, lead, customer, advocate, churned, partner
 ├── content/     posts, ads, emails, pages, offers, products, knowledge
 ├── funnels/     weighted journeys (CTR, conv-rate, drop-off)
 ├── touches/     impressions, clicks, opens, purchases, refunds, citations
 └── personas/    discovered ICPs, LTV bands, attribution truths, patterns
```

---

## The Schema (extends one.tql)

No new entities. New attributes layered onto existing 3 entities + 5 relations. Two new relations only: `same-as` (identity) and `derived-from` (lookalike). The substrate stays substrate.

```tql
define

# ── 1. GROUPS ─────────────────────────────────────────────────────────────
attribute lifecycle-stage, value string;     # awareness | consideration | decision | retention | advocacy
attribute audience-size, value long;
attribute geo, value string;                  # ISO-3166
attribute locale, value string;               # BCP47
attribute budget, value double;
attribute spend, value double;
attribute start-at, value datetime;
attribute end-at, value datetime;
attribute holdout-fraction, value double;     # 0..1 — incrementality
attribute north-star, value string;           # the one KPI it moves
attribute cap-impressions, value long;        # frequency cap per actor per window
attribute cap-window-ms, value long;

# ── 2. ACTORS ─────────────────────────────────────────────────────────────
attribute lifecycle, value string;            # anonymous | lead | mql | sql | customer | advocate | churned
attribute first-seen, value datetime;
attribute last-seen, value datetime;
attribute ltv, value double;
attribute cac, value double;
attribute consent-channels, value string @card(0..);  # email, sms, push, call, postal
attribute consent-source, value string;
attribute consent-given-at, value datetime;
attribute consent-revoked-at, value datetime;
attribute suppression-reason, value string;   # bounce | spam | unsub | gdpr | tcpa
attribute email-hash, value string;           # SHA-256 — never raw PII
attribute phone-hash, value string;
attribute committee-role, value string;       # ABM: champion | economic-buyer | user | influencer | blocker
attribute fit-score, value double;            # 0..1 persona fit
attribute dormancy-state, value string;       # active | warming | cold | reactivated | lost
attribute merged-into, value string;          # surviving aid after identity merge

relation same-as, relates actor, relates other,
    owns same-as-confidence, owns merged-at;

# ── 3. THINGS ─────────────────────────────────────────────────────────────
attribute thing-subtype, value string;        # post | ad | email | page | offer | sku | keyword | knowledge | pattern | hack
attribute creative-id, value string;
attribute headline, value string;
attribute cta, value string;
attribute variant, value string;              # A | B | C…
attribute workflow-state, value string;       # draft | review | approved | scheduled | published | live | archived
attribute publish-at, value datetime;
attribute expire-at, value datetime;
attribute approver, value string @card(0..);

# Offer-specific (Hormozi value equation)
attribute dream-outcome, value string;
attribute dream-magnitude, value double;      # 0..1
attribute likelihood-pct, value double;       # 0..1
attribute time-to-value-ms, value long;
attribute effort-score, value double;         # 0..1
attribute value-score, value double;          # computed
attribute value-to-price, value double;       # value-score / price
attribute scarcity-qty, value long;
attribute urgency-deadline, value datetime;
attribute guarantee, value string;
attribute guarantee-type, value string;       # money-back | better-than | service | conditional | reverse
attribute awareness-required, value long;     # 1..5 Schwartz
attribute sophistication-required, value long;# 1..5 Schwartz
attribute hook, value string;
attribute story, value string;
attribute big-domino, value string;

# Paid media
attribute spend, value double;
attribute cpm, value double;
attribute cpc, value double;
attribute cpa, value double;
attribute roas, value double;
attribute bid-amount, value double;
attribute bid-strategy, value string;         # manual | target-cpa | target-roas | maximize-conv | maximize-value
attribute floor-price, value double;

# ── 4. PATHS ──────────────────────────────────────────────────────────────
attribute stage, value string;                # awareness | consideration | decision | retention | advocacy
attribute conversion-rate, value double;
attribute drop-off-rate, value double;
attribute time-to-convert, value long;

relation funnel, relates entry, relates exit,
    owns stage @card(1..), owns conversion-rate, owns time-to-convert;

relation attribution, relates touch, relates conversion,
    owns weight, owns model, owns window-ms;

relation loop, relates input, relates output,
    owns loop-type, owns coefficient, owns cycle-time-ms;
# loop-type: viral | content | paid | sales | retention | reputation | ugc
# coefficient: k-factor — ≥1 viral, <1 leaky

relation stack, relates offer, relates bonus,
    owns objection-killed, owns ordinal;

relation derived-from, relates derivative, relates seed,
    owns similarity, owns method;
# method: lookalike-1pct | predictive-ltv | propensity | embedding-knn

# ── 5. EVENTS ─────────────────────────────────────────────────────────────
attribute touch-type, value string;
# impression | view | engage | click | open | submit | purchase | subscribe
# | renew | refund | cancel | churn | unsub | review | referral | handoff
# | offline-event | offline-call | offline-meet | ai-citation | conflict
attribute revenue, value double;
attribute currency, value string;
attribute device, value string;               # desktop | mobile | tablet | ctv | audio
attribute placement, value string;            # feed | story | reels | search | display | in-stream
attribute referrer, value string;
attribute utm-source, value string;
attribute utm-medium, value string;
attribute utm-campaign, value string;
attribute ai-engine, value string;            # perplexity | chatgpt-search | google-aio | claude-search
attribute citation-rank, value long;
attribute warn-type, value string;            # performance | trust | compliance | technical
attribute incident-severity, value double;

# ── 6. LEARNING ───────────────────────────────────────────────────────────
attribute statement-type, value string;
# persona | attribution | creative | timing | channel | pricing | lifecycle | pattern
attribute persona-cluster, value string;
attribute icp-fit, value double;
attribute lift, value double;
attribute lift-confidence, value double;      # 1 - p-value
attribute incremental-revenue, value double;
attribute observations, value long;

# Survey signals
attribute nps-score, value long;              # 0..10
attribute csat-score, value long;             # 1..5
attribute ces-score, value long;              # customer-effort 1..7
attribute verbatim, value string;
```

3 entities. 5 + 4 = 9 relations. ~120 added attributes. The substrate stays substrate.

---

## Tags — The Single Source of Truth

Every entity carries `tag @card(0..)`. Tags are immutable once written, inheritable down hierarchy, composable in queries, and the only categorisation mechanism in the system. Standards plug in as namespaces.

```
tag-format = namespace ":" path
namespace  = ascii-lowercase, no dots, no spaces
path       = "/" or ":" delimited segments
```

Examples: `lifecycle:customer`, `persona:founder-eu/funded`, `iab/content/v3:business/finance/banking`, `awareness:3`, `consent:email,sms`, `offer:lever:scarcity`, `attribution:model:linear`.

### Rules

1. **Immutable** — once on an entity, stays unless explicitly removed (audit logged).
2. **Inheritable** — tag on group propagates to members; tag on actor to their signals.
3. **Composable** — query is `intersection ∧ exclusion`.
4. **Versioned** — `iab/v3:...` lets standards evolve without breaking queries.
5. **Standards-as-namespaces** — IAB, OpenRTB, GA4, schema.org all become tag prefixes; nothing else changes.

### Built-in namespaces

| Namespace | Values | Purpose |
|--|--|--|
| `lifecycle` | anonymous, lead, mql, sql, customer, advocate, churned | actor stage |
| `consent` | email, sms, push, call, postal | what they allow |
| `awareness` | 1..5 | Schwartz |
| `sophistication` | 1..5 | Schwartz |
| `intent` | informational, navigational, commercial, transactional, brand | search/buy intent |
| `funnel` | awareness, consideration, decision, retention, advocacy | stage |
| `ladder-rung` | tripwire, core, profit-max, continuity, high-ticket | Brunson |
| `persona` | <cluster-id> | which persona |
| `campaign` | <campaign-id> | which campaign |
| `channel` | meta, google, tiktok, linkedin, x, email, sms, organic, seo, pr, ai-search | distribution |
| `creative` | <id>, variant-a, variant-b, control, treatment | which asset |
| `offer:lever` | reciprocity, commitment, social-proof, authority, liking, scarcity, unity | Cialdini |
| `offer:framework` | hormozi, brunson, miller, schwartz, dunford, moesta, kennedy, abraham | lineage |
| `attribution:model` | first-touch, last-touch, linear, time-decay, position, data-driven | crediting |
| `attribution:window` | 7d-click, 1d-view, 28d-click, 24h-engaged | look-back |
| `touch` | impression, view, click, open, submit, purchase, refund, churn, ai-citation, offline-* | event verb |
| `device` | desktop, mobile, tablet, ctv, audio | hardware |
| `placement` | feed, story, reels, search, display, in-stream, native | where shown |
| `geo` | <iso-3166> | country/region |
| `locale` | <bcp47> | en-US, de-DE |
| `experiment` | <id>, control, treatment | A/B |
| `holdout` | yes, no | incrementality |
| `safety` | brand-safe, age-gated, sensitive, blocked | brand safety |
| `workflow` | draft, review, approved, scheduled, published, live, archived | content state |
| `loop` | viral, content, paid, sales, retention, reputation, ugc | growth loop |
| `fit` | market-product, product-channel, channel-model, model-market | Balfour 4 fits |
| `hack` | dropbox-referral, hotmail-ps, exit-intent, scarcity-waitlist, … | growth hacks |

### External standards (plug in as namespaces)

| Namespace | Source | Use |
|--|--|--|
| `iab/content/v3` | IAB Content Taxonomy | what content is about |
| `iab/audience/v1` | IAB Audience Taxonomy | who the audience is |
| `iab/category/v3` | IAB Categories | sector |
| `openrtb/v2.6` | IAB OpenRTB | RTB bid request |
| `ga4/event` | GA4 | event names |
| `ga4/parameter` | GA4 | event params |
| `liveramp/seg` | LiveRamp | 3rd-party audience |
| `acxiom/personicx` | Acxiom | 3rd-party persona |
| `meta/audience` | Meta Custom Audiences | exportable list |
| `google/match` | Google Customer Match | exportable list |
| `tiktok/audience` | TikTok | exportable list |
| `linkedin/match` | LinkedIn Matched Audiences | exportable list |
| `klaviyo/list` | Klaviyo | sync target |
| `hubspot/list` | HubSpot | sync target |
| `salesforce/campaign` | Salesforce | sync target |
| `tcf/v2` | IAB TCF | GDPR consent |
| `gpc` | Global Privacy Control | opt-out signal |
| `canspam` | CAN-SPAM | email compliance |
| `tcpa` | TCPA | SMS/phone compliance |
| `casl` | CASL | Canadian compliance |
| `ccpa` | CCPA | California opt-out |
| `schema.org` | schema.org/Product, /Offer, /Event | structured data |

### Tag query examples

```
# All EU founders we can email, who reached awareness 3+
where tags ⊇ {persona:founder-eu, consent:email, awareness:3+}

# Audiences we can export to Meta
where tags ⊇ {meta/audience:eligible, consent:email, lifecycle:customer}

# Brand-safe inventory only
where tags ⊇ {safety:brand-safe} ∧ tags ⊉ {safety:sensitive}

# High-ROI patterns proven for B2B SaaS founders
where entity-type = pattern
  ∧ tags ⊇ {persona:founder-eu, framework:*}
  ∧ pattern_roi(this, persona) > 5
```

---

## Actor / Group / Thing / Path / Event Types

### Actor types

| Type | What | Example |
|--|--|--|
| `human` | Person | a prospect, a customer |
| `agent` | AI agent | cmo, copywriter, paid-meta |
| `brand` | Brand-as-actor | publishes, partners, sponsors |
| `world` | Federated world | another ONE world (CRM, ad platform) |

### Group types

| Type | What | Example |
|--|--|--|
| `audience` | Trait-defined target | "EU SaaS founders 50–500 ARR" |
| `segment` | Behaviour sub-audience | "abandoned cart, last 7 days" |
| `cohort` | Time-bounded segment | "Signed up Jan 2026" |
| `persona` | Cluster + inner world | see § Personas |
| `campaign` | Coordinated effort + budget + dates | "Q4 launch", "Black Friday" |
| `channel` | Distribution surface | "email", "google-ads", "tiktok-organic" |
| `list` | Static membership | CRM list, Klaviyo list |
| `account` | B2B account (org) + buying committee | "Acme Corp" |
| `market` | Geo + category | "Germany / B2B SaaS" |
| `team` | Marketing org | dept of agents |
| `program` | Multi-campaign initiative | "Inbound 2026" |

### Thing subtypes

| Subtype | Notes |
|--|--|
| `post` | Blog, social, podcast, video |
| `ad` | Paid creative — has spend/cpm/cpc/cpa/roas |
| `email` | Single send or flow step |
| `page` | Landing, PDP, pricing |
| `offer` | Discount, trial, bundle, grand-slam |
| `sku` | Sellable variant |
| `keyword` | SEO/SEM target |
| `creative-asset` | Image, video, audio |
| `experiment` | A/B container; variants are linked things |
| `knowledge` | Scraped book/video chunk (see § Knowledge) |
| `pattern` | Tagged claim with evidence + lift |
| `hack` | Reusable growth-hack template |

### Path types (named, all `relates source/target`)

| Subtype | Edge meaning |
|--|--|
| `funnel` | Stage transition (entry → exit, ordered) |
| `journey` | Multi-touch sequence per actor |
| `attribution` | Touch chain crediting one conversion (with window) |
| `loop` | Self-reinforcing cycle (k-factor measured) |
| `ladder` | Value-ladder rung-to-rung |
| `referral` | Actor → actor (multi-hop with decay) |
| `handoff` | Marketing → sales transfer |
| `same-as` | Identity merge (symmetric) |
| `derived-from` | Lookalike / predictive cluster |
| `stack` | Offer → bonus |
| `committee` | Account → stakeholder roles (ABM) |

### Event types — the marketing verb table

| `touch-type` | Direction | Default `weight` |
|--|--|--|
| `impression` | inbound | 0.1 |
| `view` | inbound | 0.2 |
| `engage` | inbound | 0.3 |
| `click` | inbound | 0.5 |
| `open` | inbound | 0.3 |
| `submit` | inbound | 1.0 |
| `purchase` | inbound | revenue |
| `subscribe` | inbound | mrr × 12 |
| `renew` | inbound | mrr |
| `refund` | inbound | -revenue |
| `cancel` | inbound | -mrr × expected-remaining |
| `churn` | inferred | -ltv |
| `unsub` | inbound | -0.3 |
| `review` | inbound | +1.0 |
| `referral` | inbound | +1.0 |
| `handoff` | internal | 1.0 |
| `ai-citation` | inbound | 1.5 (citation = endorsement) |
| `offline-event` | inbound | requires bridge — else warn(0.5) |
| `offline-call` | inbound | 0.7 |
| `offline-meet` | inbound | 1.5 |
| `conflict` | system | flagged for review (CRM ↔ ONE divergence) |
| `brand-safety` | system | warn(2) — fades 4× slower than performance warns |

Negative events become `warn()`. Positive become `mark(weight)`. Substrate handles asymmetric fade automatically.

### Learning types (`statement-type`)

| Type | Claims | Hardens when |
|--|--|--|
| `persona` | "Actors with traits X convert on path Y" | confidence × observations ≥ threshold |
| `attribution` | "Touch X deserves weight W" | windowed-coverage ≥ 90% |
| `creative` | "Variant X beats Y for segment Z" | p-value ≤ 0.05, sample ≥ 1k |
| `timing` | "Send at time T to segment S" | open-rate uplift ≥ 30% over baseline |
| `channel` | "Channel C saturates at spend S" | marginal-roas → 1 |
| `pricing` | "Price P maximises LTV for S" | observed across cohorts |
| `lifecycle` | "Stage transition rate proves health" | cohort consistency ≥ 0.7 |
| `pattern` | "Strategy X lifts KPI Y by Z%" | lift validated ≥ 2 cycles |

---

## Operational Invariants — the floor of correctness

Five things the substrate MUST enforce. Violation = `warn(2)` (double penalty). Get these right, KPI math is sound. Wrong, every number above is misleading.

### 1. Identity — one actor, many surfaces

Cookies, emails, phones, wallets — same person. The `same-as` relation merges.

- Deterministic merge (email-hash / phone-hash / wallet match): confidence 1.0, instant.
- Probabilistic merge (device + IP + behaviour pattern): confidence ≥ 0.6, flagged for review.
- Survivor = lowest aid + highest confidence; pheromone collapses; history retained via `same-as` edges.

**KPI:** `identity-resolution-rate` = merged_actors / unique_signatures. Target > 95%. Below 80% = blind attribution.

### 2. Consent — what they permit

Every outbound signal checks `consent-channels` for the channel + scope. Sending without consent = `warn(2)` plus a `compliance` incident.

**KPI:** `consented-rate` per channel. `suppression-rate` < 0.5%.

### 3. Frequency caps — how often we touch

`group:campaign` declares `cap-impressions` per `cap-window-ms` per `actor × channel`. Substrate counts; over-cap signals `dissolve`.

**KPI:** `cap-hit-rate` per campaign. > 5% = audience too small for spend (broaden or cut budget).

### 4. Attribution windows — how far back we credit

Every `attribution` relation owns `window-ms`. Touches outside the window contribute zero weight. Defaults: 7-day-click, 1-day-view, 28-day-click for high-ticket, 24-hour-engaged for video.

**KPI:** `attribution-coverage` = converted actors with ≥1 in-window touch / total converted. Target > 90%. Below means windows too narrow.

### 5. Holdouts — proof marketing caused it

Spend > $X campaigns must declare `holdout-fraction > 0`. Lift = (test-conv − holdout-conv) / holdout-conv. Without holdout, ROAS confidence capped at 0.5. The hypothesis owns `lift-confidence` (1 − p-value) and `incremental-revenue`.

**KPI:** `incremental-ROAS` = incremental-revenue / spend. The only ROAS that defends a budget review.

---

## Personas — The Deep Model

A persona is a `group` of type `persona`. Actors join via `membership` with `fit-score`. The persona group carries the cluster's full inner world. **Every campaign names exactly one persona. Campaigns that don't are broadcasting blindly.**

### Persona dimensions (attributes on `group:persona`)

```
# IDENTITY (Brunson — attractive character)
identity-now              # how they see themselves today
identity-aspired          # who they want to become
status-now                # current position
status-aspired            # target position

# JTBD (Bob Moesta — 4 forces)
jtbd-functional           # task to get done
jtbd-emotional            # feeling sought
jtbd-social               # signal to peers
force-push                # what's wrong with current
force-pull                # appeal of new
anxiety                   # concern about new
habit                     # inertia holding back

# INNER WORLD (Hormozi / Brunson / Miller)
dream-outcome             # what they want
hope                      # what they're optimistic about
fear                      # what they're afraid of
frustration               # current pain
belief-true               # truths that help
belief-false              # limiting beliefs to break
objection                 # reasons not to buy

# PROBLEMS (StoryBrand — 3 layers)
problem-external          # the visible problem
problem-internal          # how it makes them feel
problem-philosophical     # why it's wrong this exists

# TRIGGERS & VEHICLES
trigger-event             # creates buying urgency
vehicle                   # mechanism they want
solutions-tried           # failed alternatives
information-source        # who they trust

# AWARENESS (Schwartz)
awareness-level           # 1..5
sophistication-level      # 1..5

# VOICE
vocabulary                # words they use (literal)
watering-hole             # where they hang out

# ECONOMICS
willingness-to-pay
purchase-cycle-ms
typical-ltv
typical-cac-ceiling       # max CAC for unit economics to clear
```

### Worked example — `persona:founder-eu/funded`

```
identity-now:        "scrappy operator surviving on willpower"
identity-aspired:    "respected technical leader of a category-defining company"
status-now:          "post-Series-A, 12mo runway, growing 8% mom"
status-aspired:      "Series-B leader, 15% mom, sleeping through the night"
jtbd-functional:     "convert pipeline to closed revenue without hiring more reps"
jtbd-emotional:      "feel in control of growth, not at mercy of channels"
jtbd-social:         "be the founder peers cite as 'the one who figured it out'"
force-push:          "outbound plateauing, inbound unpredictable"
force-pull:          "AI agents that run growth on their own"
anxiety:             "another tool I'll abandon in 6 weeks"
habit:               "running every experiment manually with team on Slack"
dream-outcome:       "MQL→SQL on autopilot, CAC down 40%, founder back on product"
hope:                "this time AI finally compounds"
fear:                "burning runway on something that doesn't work"
frustration:         "every vendor demo is a deck, not a result"
belief-true:         ["compounding > ad spend", "ICP clarity drives everything"]
belief-false:        ["only humans do creative", "AI marketing tools are toys"]
objection:           ["needs my data", "can't replace team's judgment", "too new to bet on"]
problem-external:    "growth efficiency declining as channels saturate"
problem-internal:    "constantly behind, never proactive, dread the board update"
problem-philosophical:"marketing shouldn't need 12 SaaS subs and 3 contractors"
trigger-event:       ["Series-A close", "first churned cohort", "VP hire fails"]
vehicle:             "autonomous marketing agents inside one substrate"
solutions-tried:     ["HubSpot+Marketo+ZoomInfo+6sense+Clearbit", "agency", "growth hire who left"]
awareness-level:     3       # solution-aware, comparing options
sophistication-level: 4      # AI-saturated market — must show better mechanism
vocabulary:          ["compounding", "unit economics", "LTV:CAC", "GTM motion", "PLG"]
watering-hole:       ["YC slacks", "First Round Review", "Lenny's Newsletter", "founder X-list"]
information-source:  ["other Series-A founders", "Lenny", "operators not consultants"]
willingness-to-pay:  $24000/yr
purchase-cycle-ms:   1814400000   # 21 days median
typical-ltv:         $96000
typical-cac-ceiling: $9600        # 10:1 LTV:CAC, 24mo payback
```

### Persona → KPI map

Every persona attribute drives a KPI choice. Wrong attribute → wrong campaign → wasted spend.

| Attribute | Drives | KPI |
|--|--|--|
| `awareness-level` | hook depth, ad register | hook-through rate |
| `jtbd-*` | feature emphasis | message-resonance |
| `objection` | bonus selection, FAQ | story-through rate |
| `trigger-event` | retargeting timing | trigger-conv rate |
| `willingness-to-pay` | offer ceiling | AOV |
| `typical-ltv` | CAC budget | LTV:CAC |
| `watering-hole` | channel mix | channel-fit |
| `vocabulary` | SEO/ad literal | match-quality |
| `vehicle` | core mechanism positioning | mechanism-fit |

### Persona evolution (L6 — every hour)

Personas are hypotheses. Hardens when fit-scored actors converge on common paths. Confidence < 0.5 = provisional. < 0.3 after 100 actors = dissolve and re-cluster.

---

## Offers — One Framework, Many Lineages

Six lineages, one schema. An offer is a `thing` of subtype `offer`. Each offer composes:

1. **Core** — one thing they get
2. **Stack** — N bonuses, each killing one named persona objection
3. **Guarantee** — risk reversal
4. **Scarcity + Urgency** — action levers
5. **Hook + Story + CTA** — entry to attention, belief, action
6. **Persona binding** — locked to one awareness × sophistication level

### The unified value equation (Hormozi)

```
VALUE = (Dream Outcome × Likelihood) / (Time × Effort)
```

```
dream-outcome             # what they get
dream-magnitude           # 0..1 how big
likelihood-pct            # 0..1 perceived chance of success
time-to-value-ms          # delay until result
effort-score              # 0..1 effort required
value-score               # computed
value-to-price            # value-score / price
```

**Rule:** `value-to-price < 5` → `warn(0.5)` at planning. Don't ship.

### Offer stack (Hormozi — grand slam)

`relation stack, relates offer, relates bonus, owns objection-killed, owns ordinal;`

Every bonus must kill one named persona objection. Bonuses without an objection mapping are deletable.

```
scarcity-qty              # how many available
scarcity-reason           # why limited
urgency-deadline          # when offer ends
urgency-reason            # why deadline
guarantee                 # specific risk reversal
guarantee-type            # money-back | better-than | service | conditional | reverse
```

### Naming (Hormozi — MAGIC formula)

```
name-magnetic | name-avatar | name-goal | name-interval | name-container
```

`"The 30-Day Founder Funnel Sprint"` → magnetic=Sprint, avatar=Founder, goal=Funnel, interval=30-Day, container=Sprint.

### Hook-Story-Offer (Brunson)

```
hook                      # pattern interrupt
story                     # bridge to belief
story-arc                 # epiphany | origin | objection | testimonial
big-domino                # the one belief that, when fallen, brings the rest
new-opportunity           # what's possible they didn't know
```

### Awareness × Offer (Schwartz — the most-used decision)

| Awareness | Offer must lead with |
|--|--|
| 1 unaware | the problem (just name it) |
| 2 problem-aware | a solution category exists |
| 3 solution-aware | why this solution is best |
| 4 product-aware | why this product over competitors |
| 5 most-aware | price + urgency + deal |

**Rule:** offer addressed to actor at awareness level lower than `awareness-required` → `dissolve`. Mismatch is the #1 reason ad spend doesn't convert.

### Sophistication × Offer (Schwartz)

| Sophistication | Offer must do |
|--|--|
| 1 direct | "lose 20 lbs" |
| 2 bigger | "lose 20 lbs in 14 days" |
| 3 mechanism | "because of the keto principle" |
| 4 better mechanism | "new: keto + intermittent fasting" |
| 5 identification | "for the founder who's tried everything" |

In a saturated market, offers below market sophistication → `warn(1)`.

### StoryBrand 7-part (Donald Miller)

```
sb-character              # = persona.identity-now
sb-problem-external | -internal | -philosophical
sb-guide-empathy | -authority
sb-plan-step              # 3 steps
sb-cta-direct             # buy/book
sb-cta-transitional       # opt-in/read
sb-failure                # what they avoid
sb-success                # transformation
```

### JTBD forces (Moesta) — applied to offer

```
force-push-leveraged | force-pull-provided | anxiety-disarmed | habit-broken
```

### Cialdini levers (tags)

`offer:lever:reciprocity | commitment | social-proof | authority | liking | scarcity | unity`

Each offer pulls 3–5. <2 = thin. >5 = manipulative; trust risk.

### Positioning (Dunford)

```
category-frame            # how we're filed in their mind
alternatives              # what they'd otherwise pick
unique-attributes         # only-we-do
unique-value              # the so-what
best-fit-customer         # = persona.identity-now
```

### Message-Market-Media match (Kennedy)

`relation match, relates message, relates market, relates media, owns fit-score;`
`fit-score < 0.7` → don't ship.

### Value ladder (Brunson) — tags

`offer:ladder-rung:tripwire | core | profit-max | continuity | high-ticket`

A ladder is a `path` from rung to rung. Strength = upsell-rate.

### Offer KPIs

| KPI | Formula |
|--|--|
| value-to-price | value-score / price |
| hook-through | engage / impression |
| story-through | view-end / view-start |
| offer-through | submit / view-end |
| stack-effect | conv-rate(stack) − conv-rate(core-only) |
| guarantee-cost | refund-rate × revenue |
| ladder-velocity | mean(rung-to-rung time) |
| awareness-fit | conv-rate among matched-awareness / overall |

---

## Growth — Loops, Experiments, K-Factor

Growth ≠ marketing. Growth is **systemic loop design** + **high-tempo testing**. Funnels end; loops compound.

### Loop > funnel (Reforge)

```
relation loop, relates input, relates output,
    owns loop-type, owns coefficient, owns cycle-time-ms;
```

Coefficient ≥ 1 = viral. < 1 = leaky. Cycle-time = how long one full traversal takes.

### Canonical growth loops

| Loop | Input | Action | Output | Compounds when |
|--|--|--|--|--|
| Viral | new user | invites friends | new users | k > 1 |
| Content | search demand | publish | rank → traffic → user → publish more | SEO compounds |
| Paid | revenue | reinvest in ads | new users | CAC ≤ LTV/3 |
| Sales | meeting | close → expand → referral | new meetings | account-led |
| Retention | active user | engages → habit → tells others | long LTV | sticky compound |
| UGC | user | creates content | new user discovery | TikTok/Reddit/Instagram |
| Reputation | review | trust score → CTR ↑ | acquisition lift | g2/trustpilot/reviews |

### North Star + Activation

```
north-star                # the one number for the world
activation-event          # the aha moment
activation-window-ms      # time-to-aha
time-to-value-ms          # time to first outcome
```

**Rule:** every campaign declares which loop it feeds. Campaigns without a loop = one-shot, dissolve from the strategy view.

### Growth experiments (Sean Ellis)

```
entity experiment,
    owns xid @key,
    owns hypothesis-statement,         # "if X then Y because Z"
    owns metric-target,                # which KPI moves
    owns expected-lift,
    owns sample-size-needed,
    owns ice-impact, owns ice-confidence, owns ice-ease,
    owns ice-score,                    # I × C × E
    owns experiment-status,            # backlog | running | shipped | killed | inconclusive
    owns observed-lift,
    owns p-value,
    owns started-at, owns ended-at;
```

### High-tempo testing KPIs

| KPI | Target |
|--|--|
| experiments-shipped per cycle | ≥ 4/wk |
| win-rate | ≥ 30% |
| mean-lift on winners | ≥ 5% |
| time-from-idea-to-result-ms | ≤ 14d |
| cumulative-lift | quarterly compounded |

### Brian Balfour 4 fits

`fit:market-product | product-channel | channel-model | model-market`

Every hypothesis tags which fit it tests. Misalignment surfaces fast.

### Andrew Chen growth model

```
GROWTH = ACQUISITION × ACTIVATION × RETENTION × MONETIZATION × REFERRAL
```

Each multiplicand is a path/loop. Multiplicatively compounded — fix the worst term first.

### Growth hacks (tagged playbooks, ROI-scored)

```
hack:dropbox-referral             # space-for-friend-invited
hack:hotmail-ps                    # "PS sent from Hotmail"
hack:airbnb-cl-crosspost           # platform leverage
hack:linkedin-endorsement          # social-credit triggers
hack:product-hunt-launch           # one-day spike
hack:scarcity-waitlist             # demand-signaling
hack:viral-coefficient-loop        # k > 1 design
hack:reverse-trial                 # full-access then downgrade
hack:freemium-with-anchor          # premium beside free
hack:embedded-share                # output carries logo
hack:exit-intent-popup             # last-touch capture
hack:cold-email-sequence           # warm-by-relevance
hack:lookalike-from-converted      # paid amplification
hack:competitor-comparison-page    # bottom-funnel intent
hack:freemium-paywall-upsell       # usage-triggered
hack:public-changelog              # newsroom for retention
hack:referral-double-sided-reward  # net new + activated
hack:content-skyscraper            # outrank by depth
hack:linkbait-tool                 # free tool → backlinks
hack:pinned-tweet-funnel           # one tweet → opt-in
```

Each hack is a `thing` of subtype `hack`. ROI = mean(observed-lift) × prob(applies-to-this-persona) − cost.

### Growth-team rituals (substrate-encoded)

| Ritual | Loop | Cadence |
|--|--|--|
| Stand-up | L1 (per cycle) | every working cycle |
| Experiment review | L4 (per result) | per shipped experiment |
| Cumulative-lift report | L6 (every hour-equivalent) | per growth cycle |
| Loop audit | L7 (frontier) | per quarter-equivalent |

---

## Agents & Skills — The Autonomous Marketing Org

A marketing department is a `group:team` containing 23 agent actors. Each owns specific KPIs and skills. Skills are `thing:skill`; agents own them via `capability` relation; invocation is a signal.

### The 23-agent department

| Agent | Owns KPI | Top skills |
|--|--|--|
| `cmo` | revenue, LTV:CAC, payback | budget-allocate, hypothesis-rank, narrative |
| `strategist` | persona-fit, win-rate | positioning, ICP-mining, message-test |
| `researcher` | persona-confidence, voc-coverage | interview, transcript-cluster, voc-mine |
| `analyst` | report-cadence, attribution-coverage | attribution, cohort, dashboard |
| `forecaster` | plan-vs-actual variance | model, scenario, what-if |
| `copywriter` | CTR, conv-rate | hook, long-form, ad-copy, email, sms |
| `designer` | engage-rate, save-rate | image, motion, video, ad-creative |
| `brand` | brand-health, recall, share-of-voice | voice-doc, audit, consistency |
| `seo` | organic-sessions, keyword-rank | keyword, content-plan, on-page, link |
| `paid-meta` | ROAS-meta | audience, creative, bid, pacing |
| `paid-google` | ROAS-google | keyword, ad, lp, bid |
| `paid-tiktok` | ROAS-tiktok | UGC-brief, hook-test |
| `paid-linkedin` | ROAS-linkedin (B2B) | account-target, doc-ad |
| `social-organic` | reach, engage-rate | calendar, post, respond |
| `email` | open, ctr, rev-per-send | flow, broadcast, segment |
| `sms-push` | ctr-sms, opt-in-rate | flow, broadcast, micro-copy |
| `crm` | mql-sql-rate, lead-hygiene | scoring, routing, dedup |
| `cro` | lp-conv-rate, AOV | A/B, page, checkout |
| `pr-influencer` | mentions, share-of-voice | outreach, brief, contract |
| `community` | NPS, referral-rate | discord, forum, ambassador |
| `compliance` | incidents, suppression-rate | consent, brand-safety, legal-review |
| `ops` | budget-utilisation, calendar-on-time | budget, calendar, hand-off |
| `growth` | experiments-shipped, cumulative-lift | ICE, test-design, loop-engineering |

### Skill schema

```
attribute skill-input, value string;
attribute skill-output, value string;
attribute skill-tool, value string;        # platform/api
attribute skill-cost-msat, value long;     # LLM cost in micro-satoshis
attribute skill-latency-ms, value long;
attribute skill-quality, value double;     # rolling rubric score
```

A skill is invokable: agent receives a signal, runs the skill, emits output signals, marks paths.

### Swarm patterns (all are path topologies — substrate runs them)

```
PARALLEL FAN-OUT: cmo → [strategist, researcher, analyst]
SEQUENTIAL CHAIN: researcher → copywriter → designer → paid-meta → cro
ESCALATION:       paid-meta(ROAS<1) → analyst → cro → copywriter
CONSENSUS:        N agents propose → analyst scores → cmo decides
DEBATE:           strategist ⇄ growth → cmo arbitrates
GROWTH-LOOP:      cro → email → cro → email (recursive on retention)
ABM-ORCHESTRA:    [paid-linkedin, email, pr, sales] → account → committee
PERSONA-MINING:   researcher(voc) → strategist(cluster) → cmo(approve) → all-agents(adopt)
```

### Agent self-improvement (L5)

Same trigger as substrate. Marketing-specific:
- copywriter: CTR < baseline × 0.5 over 1k impressions
- designer: engage-rate < baseline × 0.5
- paid-*: ROAS < 1 over 7d-equivalent
- email: open-rate < baseline × 0.5

Prompt rewrites; generation increments; A/B vs prior generation; substrate adopts winner.

---

## Campaigns as Programs — Turing-Complete Execution

A campaign is **executable code** on the substrate. The substrate's signal/path/queue gives the four primitives required for Turing-completeness.

### The substrate satisfies the rule of computation

| Primitive | Marketing analog |
|--|--|
| Memory | pheromone strengths (writable, readable map) |
| Branching | `select(type)` (probabilistic) / `follow(type)` (deterministic) |
| Iteration | queue + `.then()` continuation |
| Recursion | unit signals itself or anything else |
| Halt | `dissolve` (no receiver) or strength→0 |
| Function call | `signal({ receiver })` |
| Parallel | multiple `emit()` from one task |
| Universal interpreter | a unit can interpret signals as code (LLM agents do this natively) |

Any campaign expressible as a flowchart, state machine, or program is expressible as signal flow + paths + units. **The marketing OS is Turing-complete because the substrate is.**

### Campaign primitive

```
entity campaign,
    owns cid @key, owns name,
    owns budget, owns spend, owns start-at, owns end-at,
    owns north-star,                   # the KPI it moves
    owns expected-lift,
    owns holdout-fraction,
    owns campaign-status,              # draft | scheduled | running | paused | shipped | killed
    plays membership:group;            # campaign IS a group
```

### Campaign-as-code — worked example

```typescript
// "Q4 Founder Funnel Launch" — autonomous
const c = campaign('q4-founder-launch')
  .tag('persona:founder-eu/funded')
  .tag('north-star:mql-rate')
  .tag('holdout:5%')
  .budget(50_000, 'USD')

// Step 1: paid-meta agent generates and ships ads
agent('paid-meta')
  .on('launch', async (data, emit) => {
    const audience = await match.audience({
      tags: ['persona:founder-eu/funded', 'consent:meta/audience:eligible']
    })
    const creatives = await designer.generate({ persona, count: 5 })
    for (const creative of creatives) {
      emit({ receiver: 'meta:ad-set',
             data: { audience, creative, bid: 'target-cpa', cpa: 200 } })
    }
  })

// Step 2: lead capture → enrichment → routing
agent('lead-magnet')
  .on('capture', async (data, emit) => {
    const enriched = await crm.enrich(data.email)
    emit({ receiver: icpFit(enriched) > 0.7 ? 'email-flow:nurture' : 'email-flow:standard' })
  })

// Step 3: nurture flow
agent('email-flow')
  .on('nurture', sendEmail('persona-founder/email-1'))
  .then('nurture', r => ({ receiver: 'email-flow:case-study', after: '3d' }))
  .on('case-study', sendEmail('persona-founder/email-2'))
  .then('case-study', r => ({ receiver: 'email-flow:offer', after: '4d' }))
  .on('offer', sendEmail('offer:30-day-sprint'))

// Step 4: outcome closes the loop
agent('checkout')
  .on('purchase', (data, emit) => {
    net.mark('q4-founder-launch', data.revenue)
    emit({ receiver: 'community:welcome', data })
  })
```

The campaign IS the program. Substrate runs it. Pheromone learns.

### Built-in campaign templates (parameterised signal-programs)

```
template:lead-magnet              # opt-in → 5-email nurture → offer → buy
template:tripwire                 # cheap entry → upsell → core
template:webinar-perfect          # registration → webinar → offer → close
template:high-ticket-application  # ad → VSL → application → call → close
template:product-launch-formula   # 3 pre-launch videos → cart open → close
template:viral-referral           # invite → reward both sides → loop
template:reactivation             # dormant → pattern-interrupt → win-back
template:abm-account-pursuit      # account → committee → orchestrated touches → meeting
template:content-loop             # search demand → publish → rank → traffic → publish more
template:ugc-flywheel             # creator → content → audience → creator (recursive)
template:enterprise-pilot         # case study → outbound → POC → expand
template:partner-co-marketing     # joint webinar → list-share → cross-sell
template:influencer-affiliate     # sponsored content → tracked link → revenue share
template:freemium-paywall         # free use → usage cap → upsell
template:newsletter-sponsor       # sponsor slot → traffic → conversion
```

Inject persona + offer + budget; substrate runs.

---

## Standards Integration — Interop with the Ad Ecosystem

Every standard is **a tag namespace + an importer/exporter agent**. Nothing in the substrate changes.

### Audience exporters (push to ad managers)

| Agent | Format | Tag prefix |
|--|--|--|
| `export-meta` | CSV with SHA-256 emails | `meta/audience:exported` |
| `export-google` | Customer Match CSV | `google/match:exported` |
| `export-tiktok` | Audience CSV | `tiktok/audience:exported` |
| `export-linkedin` | Matched Audiences | `linkedin/match:exported` |
| `export-klaviyo` | List sync via API | `klaviyo/list:synced` |
| `export-hubspot` | List sync | `hubspot/list:synced` |
| `export-salesforce` | Campaign sync | `salesforce/campaign:synced` |
| `export-liveramp` | Segment push | `liveramp/seg:exported` |

Each takes a tag query, produces platform-specific format, marks the export path.

### Audience importers (pull into substrate)

| Agent | Source | Adds tags |
|--|--|--|
| `import-iab-taxonomy` | IAB Tech Lab | `iab/audience/v1:*`, `iab/content/v3:*` |
| `import-acxiom-personicx` | Acxiom | `acxiom/personicx:*` |
| `import-clearbit` | Clearbit | `clearbit/*` |
| `import-zoominfo` | ZoomInfo | `zoominfo/*` |
| `import-shopify` | Shopify | orders → signals + tags |
| `import-stripe` | Stripe | payments → signals + revenue |
| `import-ga4` | Google Analytics 4 | events → signals + `ga4/event:*` |
| `import-meta-pixel` | Meta Pixel | events → signals |
| `import-segment` | Segment CDP | events → signals + `segment/*` |
| `import-rudderstack` | Rudderstack | events → signals |

### Real-time bidding (OpenRTB)

```
bid-amount | bid-strategy | auction-context | floor-price
```

`bid-strategy: manual | target-cpa | target-roas | maximize-conv | maximize-value`

A bid is a signal `paid-meta` → `meta:auction`. Win → `mark`. Loss → `warn(0.2)`. Saturation (L7) detects when bid hikes stop converting.

### Compliance namespaces (enforced before send)

```
tcf/v2:purpose:1..10            # GDPR consent purposes
gpc:opt-out                     # Global Privacy Control
canspam:physical-address-included
canspam:unsub-link
tcpa:consent-on-file
casl:express-consent
ccpa:do-not-sell
dma/gdpr:data-processor-agreement
```

`agent('compliance')` blocks outbound signal if required tags missing.

### Schema.org (for SEO + AI search)

```
schema.org/Product
schema.org/Offer
schema.org/Event
schema.org/Article
schema.org/FAQPage
schema.org/Review
schema.org/HowTo
schema.org/Course
```

`agent('schema-emit')` produces JSON-LD on every public page from existing tags. AI-search engines (Perplexity, Google AIO, Claude search) cite structured pages 3–5× more often.

---

## Knowledge Harvesting — Books → Patterns → Strategies

We've scraped 1000s of marketing books, videos, podcasts, courses. The substrate makes them queryable, comparable, executable.

### Ingestion pipeline

```
source → chunk → embed → tag with marketing-ontology tags → store as `thing:knowledge`
```

```
thing:knowledge attributes:
  title, author, medium (book|video|podcast|course|post|thread),
  chunk-text, embedding, source-url, published-at,
  chunk-tags (the marketing-ontology tags it carries),
  evidence-type (case-study | data | anecdote | theory)
```

Tagging is automatic: an embedding-classifier maps chunks to namespace tags. A chunk discussing offer stacking gets `framework:hormozi`, `offer:lever:scarcity`, `awareness:4`, `sophistication:3`.

### Pattern extraction

A **pattern** is a tagged claim with evidence + outcome. Stored as `thing:pattern`.

```
thing:pattern attributes:
  claim                       # "tripwire offer increases LTV by X% for SMB SaaS"
  claim-tags                  # framework:brunson, ladder-rung:tripwire, ...
  expected-lift, lift-confidence
  evidence-count
  persona-fit-tags            # which personas this works for
  conditions                  # required preconditions
  cost-estimate
  pattern-status              # candidate | validated | refuted | retired
```

### ROI scoring

```
fun pattern_roi($p: pattern, $persona: group) -> double:
    match $p has expected-lift $l, has lift-confidence $c, has cost-estimate $cost;
          $p has persona-fit-tags $pft;
          $persona has tag $pt;
    return ($l * $c * persona_match($pft, $pt)) / $cost;
```

### Decision framework

Given a `persona`, a `north-star` KPI, and a `budget`, the substrate returns:

- top-N patterns ranked by `pattern_roi`
- a campaign program composing them
- expected lift + confidence interval
- prerequisites (data, consent, channels needed)

```
fun recommend_strategy($persona: group, $kpi: string, $budget: double) -> { pattern }:
    match $p isa pattern, has pattern-status "validated";
          fit-score($p, $persona) >= 0.6;
          $p moves $kpi;
          cumulative-cost($p) <= $budget;
    sort pattern_roi($p, $persona) desc;
    limit 10;
    return { $p };
```

### Seeded pattern catalog (selected)

```
hormozi:value-equation              hormozi:offer-stack
hormozi:naming-magic                hormozi:risk-reversal
hormozi:scarcity-urgency            hormozi:lead-magnet-4-types
brunson:hook-story-offer            brunson:value-ladder
brunson:perfect-webinar             brunson:dream-100
brunson:vehicle-new-opportunity     brunson:big-domino
miller:storybrand-7                 schwartz:awareness-5
schwartz:sophistication-5           schwartz:channel
dunford:positioning-canvas          moesta:jtbd-4-forces
cialdini:7-levers                   kennedy:message-market-media
abraham:strategy-of-preeminence     suby:halo-strategy
ellis:high-tempo-testing            ellis:north-star
balfour:4-fits                      chen:cold-start-problem
chen:network-effects                sheridan:big-5-content
godin:permission-marketing          godin:purple-cow
moore:crossing-the-chasm            ries:positioning-mind
collier:robert-collier-letter      ogilvy:headlines-rules
halbert:dollar-bill-letter         hopkins:scientific-advertising
sugarman:axioms                     caples:tested-headlines
mackay:swim-with-sharks             cardone:10x
ammirati:idea-to-execution         buffett:moat-thinking
… (1000s more)
```

The library learns from itself: validated patterns lift, refuted ones retire, frontier (L7) finds untouched combinations.

### Loop closes both ways

- Patterns inform campaigns (decision framework)
- Campaigns produce results (mark/warn)
- Results validate or refute patterns (L6)
- Patterns harden into ICPs, channel weights, offer formulas
- The library compounds quarter over quarter

---

## KPI Ladder — Every Action Ties to a Number

Four levels. Every signal lands at one. Vanity metrics are paths that don't connect upward — substrate prunes them automatically.

```
LEVEL 4 — IMPACT (board)
  revenue, gross-margin, LTV, NRR, CAC, payback-period, brand-equity, market-share
                                ↑
LEVEL 3 — OUTCOME (per channel/program)
  ROAS, CPA, conv-rate, MQL→SQL rate, retention, churn, k-factor, win-rate, lift
                                ↑
LEVEL 2 — OUTPUT (per asset)
  impressions, clicks, opens, signups, MQLs, sessions, ranks, bookings
                                ↑
LEVEL 1 — ACTIVITY (per skill invocation)
  posts published, ads launched, emails sent, briefs written, experiments shipped
```

### Propagation rule

| Up | Pheromone source |
|--|--|
| L1 → L2 | activity-to-output paths |
| L2 → L3 | output-to-outcome paths |
| L3 → L4 | outcome-to-impact paths (windowed) |
| L4 → strategy | hypotheses harden into ICPs, channel weights, offer formulas, pattern catalog |

A skill that only moves L1 numbers without lifting L2-4 = theater. Substrate fades it.

### Per-agent KPI ownership (excerpt)

| Agent | L1 Activity | L2 Output | L3 Outcome | L4 Impact |
|--|--|--|--|--|
| copywriter | drafts/cycle | CTR | conv-rate | revenue |
| paid-meta | ad-sets/cycle | impressions, clicks | ROAS | CAC, revenue |
| seo | posts/cycle | rank, sessions | organic-conv-rate | revenue |
| email | sends/cycle | open, click | rev-per-send | LTV |
| crm | leads/cycle | lead-score | mql→sql rate | sales-cycle-ms |
| cro | tests/cycle | lp-conv-rate | AOV | revenue |
| growth | experiments/cycle | observed-lift | win-rate | cumulative-lift |
| brand | audits/cycle | recall, sentiment | share-of-voice | brand-equity |

Every cell connects to a path. Every path compounds with `mark()`.

---

## The 7 Loops — Marketing Edition

Same loops as `engine.md`. Marketing names them.

```
L1 TOUCH        per event       impression/click/open → mark or warn
L2 ATTRIBUTION  per conversion  spread weight across windowed touch chain
L3 FATIGUE      every 5 min     creative decays; resistance accumulates 2× faster
L4 ECONOMIC     per purchase    revenue mark on channel/creative path
L5 OPTIMIZATION every 10 min    rewrite copy / pause ad-sets below threshold
L6 PERSONA      every hour      cluster + harden ICPs from converted paths
L7 FRONTIER     every hour      detect untouched audience tags, surface new channels
```

### Creative Self-Improvement (L5)

`thing:ad` carries `model`, `prompt`, `generation`. When mark/warn ratio drops below threshold over N impressions:

```
needs_evolution(ad) → conv-rate < baseline × 0.5, impressions ≥ 1000
↓
ad.prompt = rewrite(ad.prompt, recent_failures, winning_variants)
ad.generation += 1
ad.variant = next_variant_id()
```

Two layers of marketing learning:
- **Substrate** — pheromone on the funnel. The market gets smarter.
- **Creative** — copy/headline/image evolves. The asset gets smarter.
- **Pattern catalog** — third layer. The library gets smarter.

---

## Universal Mapping

| System | Groups | Actors | Things | Paths | Events | Learning |
|--|--|--|--|--|--|--|
| ONE Marketing | audiences, campaigns, personas | prospects, customers | content, offers, knowledge | funnels, loops | touches | personas, patterns |
| HubSpot | lists, campaigns | contacts, companies | deals, content | pipelines | activities | reports |
| Marketo | smart-lists, programs | leads | assets, tokens | engagement-programs | activities | RCM |
| Klaviyo | segments, lists | profiles | flows, campaigns | flow-paths | metrics | predictive |
| Shopify | collections, segments | customers | products, discounts | checkouts | orders | analytics |
| Meta Ads | audiences, campaigns | users | ads, creatives | conversion-paths | impressions+clicks | optimization |
| Google Ads | audiences, campaigns | users | ads, keywords | search-paths | impressions+clicks | smart-bidding |
| Salesforce | accounts, campaigns | leads, contacts | opportunities | sales-stages | activities | Einstein |
| GA4 | audiences | users | content groups | conversion paths | events | insights |
| Braze | segments, canvases | users | content blocks | canvases | custom events | predictive |
| Segment | sources, audiences | users | events | journeys | tracks | personas |

Every marketing platform reduces to the same 6 dimensions. Names differ. Shape doesn't.

---

## Marketing KPIs as Derivations

Nothing new. KPIs are aggregations over `signal`, `path`, and `actor`.

| KPI | Definition |
|--|--|
| **CAC** | Σ `spend` / count(actor lifecycle: anonymous → customer) |
| **LTV** | Σ `revenue` per actor over lifetime |
| **LTV:CAC** | actor.ltv / actor.cac |
| **ROAS** | Σ `revenue` attributed to channel / channel.spend |
| **Incremental ROAS** | (test-revenue − holdout-revenue) / spend |
| **CTR** | count(click) / count(impression) per creative |
| **CVR** | count(submit ∨ purchase) / count(click) |
| **AOV** | mean(purchase.revenue) per cohort |
| **Churn rate** | count(churn) / count(customer) per period |
| **NRR** | (start MRR + expand − contract − churn) / start MRR |
| **Funnel velocity** | mean(time-to-convert) per stage |
| **Creative half-life** | time until conversion-rate < 50% of peak |
| **Saturation** | spend at which marginal ROAS → 1 |
| **K-factor** | viral coefficient = invitations × invite-conv-rate |
| **Activation rate** | count(reached activation-event) / count(signup) |
| **AI-citation share** | our citations / category citations |
| **Identity-resolution rate** | merged / unique signatures |
| **Attribution coverage** | converted with ≥1 in-window touch / total converted |
| **Cap-hit rate** | freq-blocked sends / attempted sends |
| **Lift confidence** | 1 − p-value on test vs holdout |
| **Cumulative lift** | Π(1 + lift_i) − 1 across shipped winners |

All computed as TypeQL aggregations. No new schema.

---

## Template Directory

Every marketing world follows this structure:

```
my-marketing-world/
  world.md                         # brand, mission, ICP guess
  groups/
    audiences/
    campaigns/
    channels/
    personas/                      # one .md per persona — full deep model
  actors/
    cmo.md
    copywriter.md
    paid-meta.md                   # one per agent
    …                              # 23 total
  things/
    content/
    ads/
    offers/                        # each offer applies the unified framework
    products/
    knowledge/                     # scraped books/videos
    patterns/                      # extracted strategies
    hacks/                         # growth playbooks
  paths/
    funnel-aaarrr.json
    funnel-b2b.json
    attribution.json
    loops.json                     # viral, content, paid, retention, ugc
  events/                          # webhook configs (Stripe, GA4, Meta, Klaviyo)
  learning/
    persona-founder.md
    persona-buyer.md
    pattern-catalog.md
  campaigns/                       # campaign-as-code (executable)
    q4-founder-launch.ts
    tripwire-evergreen.ts
    abm-acme-corp.ts
  exports/                         # audience exports per ad platform
    meta-audiences.csv.gen
    google-match.csv.gen
```

Merge into ONE: `bun run scripts/sync-world.ts --dir ./my-marketing-world`

---

## Why these 6 — for marketing

| # | Dimension | Why marketing breaks without it |
|--|--|--|
| 1 | Groups | No audiences = broadcast = no targeting = no relevance |
| 2 | Actors | No people = no one to convert = ghosts |
| 3 | Things | No content/offers = nothing to give = no value exchange |
| 4 | Paths | No funnels/loops = random touches = no compounding |
| 5 | Events | No touches = no proof = campaigns become opinions |
| 6 | Learning | No personas/patterns = every quarter starts from zero |

Remove any one and the marketing org becomes vibes. Add more and you've reinvented the same primitives at higher cost.

---

## Closed Loop — The Marketing Rule Restated

Every marketing signal closes its loop. Same Rule 1 as the engine.

```ts
const { result, timeout, dissolved } = await net.ask({ receiver: 'audience:eu-founders' })
if (result)        net.mark(edge, weight)   // converted → strengthen path
else if (timeout)  /* neutral — outside attribution window */
else if (dissolved) net.warn(edge, 0.5)     // audience didn't exist / list expired
else               net.warn(edge, 1)        // touched but didn't convert
```

A campaign that fires 1M impressions and never closes the loop teaches nothing. A campaign that fires 1k impressions and marks every conversion compounds forever. **Width without `mark()` is spend without learning.**

---

## The Journey

```
Lines 1–60      THE PRINCIPLE
                Tags spine + signals + 6 dimensions = Turing-complete marketing OS

Lines 61–200    THE SCHEMA
                ~120 attributes layered on substrate. Two new relations.
                3 entities + 9 relations total.

Lines 201–320   TAGS — single source of truth
                Built-in namespaces + external standards (IAB/OpenRTB/GA4/…)
                One mechanism for all categorisation.

Lines 321–400   TYPES
                Actor / group / thing / path / event / learning subtypes
                The marketing vocabulary, dense.

Lines 401–470   OPERATIONAL INVARIANTS
                Identity / consent / frequency / windows / holdouts.
                The five things that, wrong, make every other number lie.

Lines 471–600   PERSONAS — the deep model
                IDENTITY · JTBD · INNER WORLD · PROBLEMS · TRIGGERS
                AWARENESS · VOICE · ECONOMICS — full founder-EU example.

Lines 601–760   OFFERS — six lineages, one schema
                Hormozi · Brunson · Miller · Schwartz · Dunford · Moesta · Cialdini · Kennedy
                Value equation, stack, MAGIC, hook-story-offer, awareness × sophistication,
                StoryBrand 7, JTBD forces, levers, positioning, ladder.

Lines 761–840   GROWTH — loops, experiments, k-factor
                Loop > funnel. North star. ICE. Balfour 4 fits. Hack catalog.

Lines 841–910   AGENTS & SKILLS
                23-agent org. Skill schema. 8 swarm patterns. Self-improvement.

Lines 911–1010  CAMPAIGNS AS PROGRAMS — Turing-complete
                Substrate primitives map to computation primitives.
                Worked example. 15 templates.

Lines 1011–1080 STANDARDS INTEGRATION
                Audience export/import. OpenRTB. Compliance. Schema.org.

Lines 1081–1170 KNOWLEDGE HARVESTING
                Books/videos → chunks → patterns → strategies.
                ROI scoring. Decision framework. Library compounds.

Lines 1171–1240 KPI LADDER
                4 levels. Propagation rule. Per-agent ownership.

Lines 1241–end  LOOPS · UNIVERSAL MAPPING · DERIVATIONS · TEMPLATE · CLOSED LOOP
                The marketing world inherits the substrate's compounding.
```

---

*Tags categorise. Signals execute. Pheromone learns. Standards interop. Books harden into strategies. Campaigns are programs. Marketing is a Turing-complete swarm — same substrate, same 100 lines, same 6 dimensions. The marketing department is a swarm of 23 agents running campaigns as code on a tag-spined signal substrate, and every action ties to a number on the KPI ladder.*
