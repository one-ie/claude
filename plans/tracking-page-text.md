# Every touch. Every channel. One graph. $0.30 per million.

**The customer data platform your warehouse wishes it was.** Stitch
identity across email, web, ads, SMS, and chat. Attribute revenue to
the channel that earned it. Personalise in the same heartbeat the
visitor lands. Delete a person from everywhere in under a second.

**40 millisecond response time. $0.30 per million events. Built so
your DPO sleeps at night and your growth team gets attribution back.**

[ Install in 60s ]    [ See the live pulse ]    [ Read the spec ]

---

## The choice your stack keeps forcing on you

Every marketing data tool makes you pick one of these. Both hurt.

| | What you get | What it costs you |
| --- | --- | --- |
| **Collect everything** (Segment → warehouse) | Rich attributes, every join you want | No consent dial, no audit trail, GDPR exposure your DPO won't sign off on |
| **Collect nothing real** (privacy-first SDKs) | Compliance peace of mind | No identity stitching, no enrichment, no LTV, no journeys — half-blind |

We refuse both. Our promise instead:

> **Collect deeply. Encrypt aggressively. Audit every read. Forget on a click.**

In plain English: we keep the rich data your growth team needs to run
attribution and lifecycle, but the actual names, emails, and phone
numbers live in a sealed vault. The pipeline works on **hashes**
(scrambled fingerprints) — useful for joining, useless if leaked. Every
time someone reads a real value, we log who, when, and why. And when a
person asks to be forgotten, we destroy the key in under a second —
making every copy of their data mathematically unreadable, everywhere,
at once.

Compliance signs off. Growth gets attribution back. Engineering doesn't
have to build it.

---

## What lands as a signal

Eight sources of data feed one pipeline. Web pageviews, email opens
and clicks, server-side events, chat conversations, ad-platform
webhooks, SMS, AI agents using your API — they all arrive in the same
shape. **Humans and agents are both first-class customers.**

```
web pixel    ─┐
tracked link ─┤              ┌──────────────────────┐
email open   ─┤              │  Event arrives       │── stored forever (cheap)
email click  ─┤              │  1. verify it's real │
server SDK   ─┼─── batch ───▶│  2. figure out who   │── working memory (fast)
AI tool call ─┤              │  3. resolve identity │     ├── live counts
CLI command  ─┤              │  4. apply consent    │     ├── live updates to UI
channel bot  ─┤              │  5. write + signal   │     └── archive to cold store
ad webhook   ─┘              └──────────────────────┘
```

**3 milliseconds on the hot path.** Everything else happens in the
background — but the visitor never waits.

---

## The 10 capabilities that change what your team can ship

Each capability below starts with what a marketer can finally do, then
explains how it works underneath. Read the bold line; dive in if you're
curious.

### 1. The Identity Ladder — never lose a visitor again

**What it means for marketing:** your last-touch attribution finally
has a join key that survives logged-out sessions, Apple's ITP, and
incognito browsing. The same person on desktop yesterday, mobile today,
and your email tomorrow shows up as one record — not three.

A visitor climbs five rungs as you learn more about them. Each rung is
a **deterministic hash** — a one-way scrambled fingerprint we can
match against future events, but can't reverse back to the original.

```
rung 0   device       cookie_id                       first hit, 2y
rung 1   visitor      hash(cookie + workspace salt)    every event
rung 2   email        hash(lowercase email)            on open / click / form
rung 3   phone        hash(e164 phone)                 on sms or form
rung 4   account      actor_id (a unique account ID)   on signup / verify
rung 5   linked       account ↔ Stripe customer, OAuth subs
```

Old events are never rewritten — we add a "this device is the same as
this account" link with a confidence score and a merged-at timestamp.
**Better than 95% identity resolution. Fully auditable. Reversible if wrong.**

### 2. Cross-Device — the magic of tracked links

**What it means for marketing:** your email campaign finally gets
credit for the mobile-Safari conversion that Google Analytics will
swear came from "direct / none."

When you put a tracked link in an email, a click crosses device
boundaries automatically. A logged-out user opens it on their phone;
our redirect (a tiny edge server that sits between the click and the
destination) recognises them, sets a cookie tied to the same account,
and forwards them to the page. Next mobile pageview unifies with the
desktop session that started the journey.

```
https://one.ie/r?e=<email-hash>&c=apr-q2&u=/pricing&s=<signature>
```

**Under 50 milliseconds on the redirect.** Verify the link is genuine,
identify the person, set the cookie, log the event, forward to the
page. Done.

### 3. The PII Vault — collect deeply, hold lightly

**What it means for marketing:** your CRM has full names, emails, and
phone numbers when you need them, but day-to-day queries never touch
the raw data. The reports your team builds are GDPR-safe by default.

Raw personal data never travels in the event stream. The pipeline
writes the **hash** to events; the real value goes to a sealed vault
(encrypted with a key managed in a hardware security module — KMS)
keyed by the account ID.

| Where the key lives | Who can decrypt |
| --- | --- |
| **one-managed** — our KMS, region-locked | Our services, with an audit row for every read |
| **customer-managed** — your AWS/GCP/Azure KMS | Only when your key is presented |
| **bring-your-own** — never leaves your infrastructure | Only via a remote-attested secure enclave |

**Two ways to read data, only one decrypts:**

- **Join mode** — return hashes, IDs, and derived attributes. No
  decryption, no audit row, no real PII leaves the warehouse. Most CRM
  work lives here.
- **Reveal mode** — explicitly request the decrypted value. Every
  reveal logs who, when, and why. Rate-limited to 100/hour per admin.

Unusual patterns (one admin reading 100 emails at 3am) trigger an alert.

### 4. KMS-Shred — Article 17 in under a second

**What it means for marketing:** a Right-To-Be-Forgotten request stops
being a quarterly engineering project. Press a button, get a receipt.
The audience shrinks in Meta and Google **today**, not after the next
30-day refresh.

```
POST /api/forget    { account or email-hash or visitor-hash }

cascade:
  PII vault          →  destroy encryption key — unreadable in <1s
  live state         →  immediate delete
  warm event store   →  hashes kept, payload nulled, < 5 minutes
  identity graph     →  account redacted, paths fade naturally
  cold archive       →  next compaction rewrites (≤ 30 days)
  ad platforms       →  outbound DELETE to Meta/Google/TikTok/Klaviyo
  audit log          →  preserved with a "forget happened" entry

receipt: { account_id, requested_at, completed_at, per-tier counts }
```

GDPR Article 17, CCPA, customer DSAR — same endpoint, same receipt,
same SLA.

### 5. Tags Become Paths — the substrate learns your attribution model

**What it means for marketing:** multi-touch attribution stops being a
quarterly project. The pipeline itself becomes the model.

Every event you send has tags — a list like
`[click, telegram, apr-q2, founder, US]`. The pipeline takes each
consecutive pair of tags and **strengthens a connection between them**
(like a well-worn path getting wider every time someone walks it).

```
event tags:  [touch:click, channel:telegram, campaign:apr-q2, persona:founder, region:us]

connections strengthened:
  click            → telegram
  telegram         → apr-q2
  apr-q2           → founder
  founder          → US
```

After enough events, the graph knows — **without an analyst writing a
query** — that telegram drove the apr-q2 campaign, that apr-q2 skewed
founder, that founders skewed US. Query it like any database, or just
ask for "the strongest paths from X."

### 6. Workflow Mining — the substrate finds your funnels for you

**What it means for marketing:** stop hand-building funnels and
guessing which ones to measure. The pipeline tells you which sequences
are actually leading to conversion.

Traditional attribution looks **backward** from a known purchase.
Workflow mining looks **forward** from any tag and finds the sequences
that lead anywhere interesting.

```
sequences with strong traffic (last 24 hours):
  cli:init     → cli:agent     → cli:deploy        (new project flow)
  sdk:discover → sdk:hire      → sdk:pay           (marketplace flow)
  view:/docs   → click:install → sdk.init          (DevRel funnel)
  view:/pricing → submit:trial → identify:email → purchase
```

Once an hour, a background job promotes any strong sequence with a
real outcome at the end into a **hypothesis**. The CRM shows them at
`/crm/journeys/discovered` — one click materialises it as a live
journey with goals, a holdout group, and A/B variants.

### 7. Weighted Signals — revenue outweighs vanity 10×

**What it means for marketing:** your channel-mix optimisation starts
from dollars, not pageviews.

By default every event contributes equally. But you can dial up the
ones that matter more.

| Scenario | Weight | Why |
| --- | --- | --- |
| Normal call | `1` | baseline — most events |
| Error / partial | `0.5` | something attempted; half-credit |
| High-quality outcome | `quality × 5` | amplify verified wins |
| Payment settlement | `amount × 10` | revenue is rare and should dominate |

```ts
emit('purchase', ['channel:web'], { amount: 79, weight: 790 })
```

The "highways" that emerge from amount-weighted paths are **revenue
paths**, not pageview paths.

### 8. Realtime that doesn't cost while idle

**What it means for marketing:** open as many live dashboards as your
team wants. A tab left running in a background browser pays nothing
until something actually happens.

Every CRM screen subscribes to a topic — a specific live feed like
"this customer" or "this segment." When nothing's happening, the
connection sleeps (it **hibernates**) and the bill is zero. When an
event lands that you care about, it wakes up instantly.

**Coalesce window: 50ms.** A burst of 200 pageviews on the same page
arrives as one update, not 200. Fan-out costs drop 20–200× during traffic spikes.

**Backpressure into summary mode.** If a watcher falls behind, the
server switches to sending summary deltas instead of raw events. The
UI degrades gracefully — nothing breaks.

### 9. The Brain at the Edge — where the magic actually happens

**What it means for marketing:** the personalisation, segmentation,
and recommendations are computed in the same place the event lands —
not after a 30-second hop through a warehouse and a "feature store" and
an ML service. That's why the chat already knows the visitor.

Each of your workspaces gets a tiny dedicated server (a **Durable
Object**, in Cloudflare's terms) pinned to one location, holding the
identity graph and live counters in working memory:

```
identity graph     all accounts, their attributes, who's the same as whom
live counters      per stage, per channel, per day — updated instantly
recent feed        last 10,000 events for the live activity tail
active watchers    every dashboard/screen waiting for updates
unflushed writes   buffer drained every 5 seconds for durability
```

Cold start: under 80ms for small workspaces, under 300ms for ones with
a million events a day. Above that we shard automatically — no flag,
no migration.

### 10. Server-Side Conversions — close the loop both ways

**What it means for marketing:** Meta CAPI, Google Enhanced
Conversions, TikTok Events — wired up the day you install. Attribution
flows back to the ad platforms that lost cookies to ITP and ATT, so
their algorithms see your real conversions.

```
purchase event fires
  → write the event (your local source of truth)
  → fan out to Meta CAPI, Google EC, TikTok Events, Klaviyo, HubSpot
  → each writes back a child event saying "attribution sent, status OK"
```

Inbound ad-platform pixel events normalise back into the same shape.
One graph. Both directions.

---

## What the brain at the edge actually *does* — 25 realtime surfaces

Eight sources land. One graph lights up. Inside the same heartbeat the
event arrives — usually under 100 milliseconds — the system decides
who this visitor is, what path they're on, and what should happen
next. **No warehouse round-trip. No feature store. No ML service hop.**

Six simple verbs do all the work:

| Verb | What it does in plain English |
| --- | --- |
| `mark` | "This worked — strengthen this path." |
| `warn` | "This failed — weaken this path." |
| `sense` | "How strong is this path right now?" |
| `follow` | "What's the most likely next step from here?" |
| `select` | "Pick a next step, weighted by what's worked best." |
| `highways` | "Show me the top routes through this part of the graph." |

If a surface can be built from those six, it runs at edge speed.

### Tier 1 — the five that make us not-comparable to other CRMs

**1. Chat that already knows the visitor.** They open `/chat`; before
the agent says hello, it already has their identity rung, last 10
events, current campaign, persona tags, suppression state, Stripe
LTV, firmographics, and last 3 conversations. **First reply in under
200ms, fully personalised.**

Every other tool would query Snowflake + HubSpot + Stripe + Intercom
and stitch the answers together. We have one heartbeat.

**2. Surface-aware agent triggers.** The agent watches every visitor
it's been introduced to. The pipeline tells it 50ms after the
pageview lands. The agent appears in context:

```
visitor on /pricing for the 3rd time this week, stalled 30s
  → agent: "I see you're back on pricing — want me to walk through tiers?"

visitor abandoned a form mid-fill, exit intent fired
  → agent: "Want me to save that for later? You filled in name + company."
```

Other tools fire emails ten minutes after exit. We fire an agent in
the page in the same heartbeat the visitor stalls.

**3. Next-best-action without an AI call.** Ask `follow` from the
visitor's current position; you get the highest-strength outgoing
path. **That is the recommendation** — path strength is the score.
Under 1ms. The LLM only runs for genuinely new cases. **This inverts
the cost shape of every recommender — the cheapest case is the most
common one.**

**4. Live page personalisation.** A page first paints, asks the
pipeline for the visitor's current state, and gets back hero copy, CTA
wording, and pricing tier in the **same message** that connects the
live feed. No re-render, no flash-of-default-content.

**5. Predictive prefetch.** `follow` tells you the most likely next
page; the server quietly pushes it to the browser via Early Hints
before the user clicks. **Prediction quality compounds with traffic.**
Every conversion strengthens the path; every prefetch hit shortens the
next user's session.

### Tier 2 — eight high-impact, all free because the wiring already exists

| # | Surface | What it does |
| --- | --- | --- |
| 6 | **Bandit A/B without buying a bandit service** | `select` picks variants weighted by what's converting. The substrate IS the bandit. Underperformers fade automatically. |
| 7 | **Threshold-crossing ad targeting** | A path strength crosses 100 → CAPI fires in the same heartbeat → Meta lookalike updates in under 30 seconds, not next-day cron |
| 8 | **Recommendations as tag-prefix queries** | One verb (`highways`), every surface — docs, products, skills, agents. Cold start handled by shortening the prefix. |
| 9 | **In-session funnel rescue** | Compare live dwell to learned-normal dwell → detect stall → agent appears with contextual help |
| 10 | **Live segment membership** | Segments are reactive queries, not snapshots. Joins/leaves stream to your screen — no polling. |
| 11 | **Cohort-aware copy** | Variant chosen by lifecycle stage (cold, engaged, evaluating, customer), not by random hash |
| 12 | **Onboarding step-skipping** | New signup's email matches old CLI/SDK signals → skip the "what is an agent" intro |
| 13 | **Send-time at the engagement peak** | Hourly engagement histogram per customer → broadcast scheduled at their personal peak |

### Tier 3 — specialised but powerful

| # | Surface | What it does |
| --- | --- | --- |
| 14 | **Live LTV** | Updates while the user watches. Path strength × purchase size + Stripe MRR × expected months. |
| 15 | **Cross-actor influence** | "3 other founders in your region just started trials this week" — social proof from the live graph, not a static table |
| 16 | **Predictive churn** | Engagement fades past a threshold → auto-enrol in win-back journey |
| 17 | **Inventory-aware recs** | Recommendations filtered by live stock |
| 18 | **Knowledge-base re-ranking** | Search results reordered by what's converted *this* persona |
| 19 | **Multi-agent handoff** | Support agent finishes a ticket → `follow` finds the right specialist → context-packed handoff |
| 20 | **Voice personalisation** | Twilio inbound → phone hash → snapshot → voice agent's opener already knows the caller |

### Tier 4 — defensive / operational (free because the wiring is already there)

Anomaly alerts (when a path inverts before anyone refreshes a
dashboard) · fraud blocking at the edge · live moderation ·
competitor-IP content swap · contextual consent re-prompt at the value
moment.

### What we promise on speed

| Tier | First response (worst case) |
| --- | --- |
| Tier 1 | under 100ms — **must** |
| Tier 2 | under 500ms — should |
| Tier 3 | under 2 seconds — fine |
| Tier 4 | under 30 seconds — eventually-correct is fine |

The line between Tier 1 and Tier 2 is the line **above** which the
brain-at-the-edge architecture is the reason it works. Below it, a
normal warehouse stack would also fit. Most marketing tools live below
it. We live above it.

### What we are NOT promising

| The thing | Why we're honest about it |
| --- | --- |
| Sub-100ms LLM responses | The LLM call itself is our floor — but the substrate-only surfaces (#3, #6, #8) genuinely are sub-100ms because no LLM is invoked |
| Lossless cross-region order | Per-customer ordering is preserved. Across customers, ordering is best-effort. |
| Cold-start no-data personalisation | A brand-new visitor with zero history gets defaults until rung 1 lands |
| Pheromone replacing rigorous ML | Path strength is a strong baseline that gets the obvious cases right cheaply. Hard cases still warrant a model — the substrate just stops paying for the easy ones. |

---

## What it costs, end to end

A workspace doing 50 million events a month, before and after tuning:

```
event ingestion                3ms typical, 12ms worst case

raw event storage              50M events × $0.25 per million   = $12.50

live brain (Durable Object)    ~120 MB working memory, one shard
                               flush to durable storage every 5 seconds
                               snapshot every 60 seconds
                               archive to cold storage every 10 minutes

realtime fan-out               ~1.5M messages per month         = $1.50

everything else                ≈ $40

baseline total                 $53 / month  →  tuned: $0.30 per million events
```

Stacked, the tuning levers (client batching, edge caching, deterministic
routing, smart co-location, aggressive coalescing) give us **3.5×
cheaper, 2.4× faster**.

```
$ per million events    $0.30        ── 3.5× cheaper than baseline
ingest latency, p50     6 ms         ── 2× faster
ingest latency, p99     45 ms        ── 2.4× faster
watcher latency, p99    60 ms        ── 1.8× faster
```

Compare to Segment at the Business tier (~$120 per million events),
Rudderstack self-hosted (where the warehouse is the real cost), or any
"$1k per seat" CDP.

---

## What you get out of the box

| Surface | What it shows |
| --- | --- |
| **Pulse** | Live KPI tiles, firehose tail, degradation panel |
| **CRM contact** | Activity feed, identity ladder, appended attributes, reveal audit |
| **Segments** | Tag-prefix queries, live counts |
| **Journeys** | Design + holdout + variants + lift with p-value |
| **Discovered** | Mined workflows from the substrate, one-click promotion |
| **Privacy** | Live counter of how many rows a downgrade would affect, **before** you apply |
| **Reveal audit** | Who read which field, when, with what justification |

Every screen is realtime by default.

---

## Privacy as a competitive moat

Three layers of dials, each more specific than the last:

```
workspace collection mode   ∈ { minimal, balanced, forensic }
   minimal:    hashes + essential only
   balanced:   identity + content + appended attributes, no fingerprint  ← default
   forensic:   everything (full IP, device, mouse trace, content body)

per-class override         each data class can be turned off regardless of mode

per-person override        a specific customer's data drops to hash-only
```

**What never lands, regardless of mode:**

- Credentials (we detect them by entropy and length pattern and reject at the gate)
- Government-ID-class fields (SSN, passport, bank account)
- Special-category GDPR Article 9 data (health, biometric, religious)
  unless an explicit legal-basis declaration is on file

Your DPO's RFP becomes a five-minute conversation.

---

## Agents are first-class — your DevRel funnel finally has numbers

The CRM doesn't distinguish humans from agents. The pipeline doesn't
either. An AI agent that uses your API gets an account, "same as"
links when its keys rotate, path strength on its inbound routes, and
enrolment in journeys like `onboarding-agent-d7`.

```
agent verbs (added to your existing human verbs):
  sdk.init            first SDK construction with a fresh key
  api.call            authenticated HTTP hit
  tool.invoked        MCP tool call
  tool.completed      with success/failure
  capability.bound    accepted a published capability
  signal.sent         emitted into the bus
  ask.resolved        ask returned a non-timeout
  evolve.triggered    self-rewrote its system prompt
  harden.promoted     a hypothesis was hardened
```

Your DevRel funnel becomes measurable the same way your marketing
funnel is: visit docs → install SDK → first init → first API call →
first tool invocation → first conversion of *its* user.

---

## Install in 60 seconds

```html
<script async src="https://one.ie/p/one.js"
        data-ws="acme"
        data-consent="auto"
        data-link-rewrite="on"
        data-spa="auto"></script>
```

Under 4KB compressed. No third-party calls. `data-consent="auto"`
reads the IAB consent framework and Global Privacy Control automatically.
`data-link-rewrite="on"` makes every outbound link tracked.

**Server SDK:**

```ts
import { one } from '@oneie/sdk'
one.init({ workspace: 'acme', key: env.ONE_KEY })
await one.track({ event: 'purchase', actor: 'ada', payload: { amount: 79 } })
```

**Command line:**

```
oneie track --event purchase --actor ada --amount 79 --workspace acme
```

**AI agents** built on `@oneie/mcp` automatically emit their tool
calls. Zero config.

---

## The one-paragraph summary

> Send events with the names and emails scrambled. The pipeline figures
> out who's who, builds a live identity graph, watches the paths each
> customer takes, and personalises the next page, the next message, the
> next ad — in the same heartbeat the event lands. The chat already
> knows the visitor. The page personalises before it paints. The
> recommender is the analytics database. The bandit is the substrate.
> The CAPI fires while the user is still on the page. When a customer
> asks to be forgotten, every copy of their data becomes mathematically
> unreadable in under a second. Tuned, the bill is **$0.30 per million
> events at 40ms p99.**

---

[ Install the pixel ]    [ Read the full spec ](tracking.md)    [ See all 25 realtime applications ](tracking-realtime.md)    [ Talk to us ]

*Eight sources. Five identity rungs. Six verbs. One graph. Twenty-five surfaces. Zero drift.*
