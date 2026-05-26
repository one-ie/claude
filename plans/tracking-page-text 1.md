# Track everything. Forget on a click. Pay $0.30 per million.

**One pixel. One pipeline. One brain at the edge.** Every click, open,
email reply, agent tool-call, webhook from Stripe — same shape, same
store, same realtime stream. **$0.30 per million events at 40ms p99.**

[ Install in 60s ]    [ See the live pulse ]    [ Read the spec ]

---

## The pitch in one breath

Most analytics tools choose: **collect-and-stare** (no opt-out, no key
custody, no audit) or **hash-and-forget** (no raw value, no enrichment,
no content). We pick neither.

> **Collect deeply. Encrypt aggressively. Audit every read. Forget on a click.**

The richest model of every interaction — cross-channel, cross-device,
humans and agents in the same graph — is the moat. Pseudonymous hashes
are the universal join key. Raw values live in an encrypted vault you
hold the key to. Every read is audited. Delete cascades atomically
across every tier in under a second.

---

## What lands as a signal

Web pixel · tracked redirect · email opens & clicks · server SDK ·
MCP tool-calls · CLI verbs · channel bots (Telegram, Discord, SMS) ·
ad-platform webhooks (Meta, Google, TikTok).

Eight sources. One event shape. The pipeline doesn't care where the
event came from — humans and agents are both first-class actors.

```
web pixel    ─┐
/go/:id      ─┤              ┌──────────────────────┐
email open   ─┤              │  POST /api/events    │── Analytics Engine (firehose)
email click  ─┤              │  1. verify (HMAC,    │
server SDK   ─┼─── batch ───▶│     cookie, sig)     │── Workspace DO (TypeDB in RAM)
MCP tool     ─┤              │  2. derive visitor   │     ├── rollups O(1)
CLI verb     ─┤              │  3. resolve actor    │     ├── WebSocket fan-out
channel bot  ─┤              │  4. apply consent    │     └── WAL → D1 / KV / R2
ad webhook   ─┘              │  5. write + signal   │
                             └──────────────────────┘
```

3ms on the hot path. Everything else is async.

---

## The 10 groundbreaking features

### 1. The Identity Ladder — every visitor walks up it

A visitor climbs five rungs as we learn more. Each rung is a
deterministic hash with provenance — never raw PII in stored joins.

```
rung 0   device       cookie_id                       first hit, 2y
rung 1   visitor      sha256(cookie + ws_salt)        every event
rung 2   email        sha256(lowercase + global)      on open / click / form
rung 3   phone        sha256(e164 + global)           on sms or form
rung 4   account      actor_id = ULID                 on signup / verify
rung 5   linked       (actor_id ↔ stripe_cus_*, oauth subs)
```

Past events are never rewritten — a `same-as` relation joins them with
`confidence` + `merged-at`. **Auditable. Reversible. >95% identity
resolution.**

### 2. Cross-Device — the magic of tracked links

A tracked link in an email crosses device boundaries the moment a
logged-out user opens it on their phone. The redirect sets a cookie
keyed to the same actor. Next mobile pageview unifies.

```
https://one.ie/r?e=<email-hash>&c=apr-q2&u=/pricing&s=<hmac>
```

The single most powerful identity technique in a cookieless world.
**< 50ms target on the redirect Worker** — HMAC verify, resolve, set
cookie, write event, 302 — done.

### 3. The PII Vault — collect deeply, hold lightly

Raw PII never travels in the event stream. The pipeline writes the
**hash** to events. The **raw value** goes to a per-workspace,
KMS-sealed vault keyed by `actor_id`.

| Mode | Key location | Who can decrypt |
| --- | --- | --- |
| `one-managed` | one.ie KMS, region-bound | one.ie services with audit row |
| `customer-managed` | your KMS (AWS/GCP/Azure) | only when your key is presented |
| `bring-your-own` | never leaves your infra | only via remote-attested enclave |

**Two read modes, only one decrypts:**

- **join mode** — return hashes, ids, derived attributes. No decrypt,
  no audit row, no PII leaves the warehouse. Most CRM ops live here.
- **reveal mode** — `GET /api/pii/reveal/:actor_id` returns decrypted
  fields. Emits a `pii.read` audit event. Rate-limited 100/hour/admin.

Every reveal is observable. Anomalies (one admin reading 100 emails
at 3am) trigger a compliance agent warn.

### 4. KMS-Shred — forget in under a second

```
POST /api/forget    { actor_id | email_hash | visitor_hash }

cascade:
  pii_vault          →  KMS-shred row immediately (unreadable in <1s)
  KV visitor_state   →  immediate delete by key
  agent_events_warm  →  rows redacted: hashes kept, payload nulled, < 5m
  TypeDB             →  actor + same-as redacted, paths fade naturally
  R2 parquet         →  next compaction rewrites (≤ 30d)
  ad platforms       →  outbound DELETE to Meta/Google/TikTok/Klaviyo
  audit log          →  preserved with forget.cascade per tier

receipt: { actor_id, requested_at, completed_at, deleted_counts_per_tier }
```

Destroy the root key → every vault row in that workspace becomes
mathematically unreadable in milliseconds. Article 17, CCPA delete,
customer requests — same endpoint, same SLA.

### 5. Tags Become Paths — the substrate learns by itself

This is the connective tissue. Every event's tags are an ordered list,
and **each consecutive pair becomes a path edge** with a pheromone
deposit.

```
event tags:  [touch:click, channel:telegram, campaign:apr-q2, persona:founder, region:us]

paths marked (+weight each):
  touch:click      → channel:telegram
  channel:telegram → campaign:apr-q2
  campaign:apr-q2  → persona:founder
  persona:founder  → region:us
```

After N events the graph has accumulated strength on every observed
pair. The substrate now knows — **without any analyst writing a query** —
that telegram drove `apr-q2`, that `apr-q2` skewed founder, that
founder skewed US. Queryable as `world.highways()` or by tag prefix.

**No separate analytics database. Tag co-occurrence IS the analytics.**

### 6. Workflow Mining — the substrate finds your funnels

Attribution looks back from a known conversion. **Workflow mining
looks forward** from a tag and finds the sequences that lead anywhere
interesting.

```
path chains with strength > 50 (24h window):
  cli:init     → cli:agent      → cli:deploy        (new-project flow)
  sdk:discover → sdk:hire       → sdk:pay           (marketplace flow)
  view:/docs   → click:install  → sdk.init          (DevRel funnel)
  view:/pricing → submit:trial  → identify:email    → purchase
```

The L6 KNOWLEDGE loop runs hourly. Any chain with sustained strength
+ two outcome events at the tail gets promoted to a **hypothesis** in
TypeDB. The CRM surfaces them at `/crm/j/discovered` — one click to
materialize as a live journey with goals, holdout, and variants.

**You don't have to design the funnels you measure. The pipeline finds them.**

### 7. Weighted Signals — economics outweigh attention 10×

Default deposit weight is `1`. Four overrides bend the substrate
toward the signals worth more:

| Scenario | Weight | Why |
| --- | --- | --- |
| Normal call | `1` | baseline — most events |
| Error / partial | `0.5` | something was attempted; half-credit |
| Rubric-scored success | `rubric_avg × 5` | amplify verified quality |
| Payment settlement | `amount × 10` | economic signals are rare |

```ts
// payment settled for $79
emit('purchase', ['channel:web'], { amount: 79, weight: 790 })
```

Highways that emerge from amount-weighted paths are **revenue paths**,
not vanity paths.

### 8. Hibernating WebSockets — realtime that doesn't bill while idle

Every CRM screen subscribes to a topic on the workspace Durable Object.
A tab left open in a background browser **pays nothing** until an event
arrives. Cloudflare wakes the connection on inbound at no duration cost.

```ts
ws.subscribe({
  workspace: 'acme',
  topic: 'actor:ada' | 'segment:ent-trial-d7' | 'journey:trial-rescue-d14'
       | 'pulse:kpi' | 'inbox:open' | 'global'
})
```

**Coalesce window: 50ms.** A burst of 200 pageviews on the same page
becomes one WebSocket message, not 200. Fan-out billing drops 20–200×
under bursts.

**Backpressure into summary mode.** If a watcher's outbound buffer
exceeds 256KB, the DO stops sending raw events and sends rollup deltas
only. The UI degrades to the same shape Pulse uses. Nothing breaks.

### 9. The Brain at the Edge — TypeDB in RAM, per workspace

One Durable Object per workspace. Inside lives:

```
typedb:   in-memory entities + relations + attributes   (50–500 MB working set)
rollups:  per-stage, per-channel, per-day counters       O(1) writes
recent:   last 10k events for live tail                  O(1)
watchers: active WebSocket subscriptions                 O(1) topic match
wal:      unflushed writes, drained every 5s             durable on first flush
```

**Why DOs.** Pin compute + RAM to a single location, so all writes for
one workspace are serialised without locks. TypeDB's transactional
semantics map cleanly onto DO single-threadedness.

**Cold start targets:** < 80ms (≤10k events/day) · < 300ms (≤1M
events/day) · sharded above (256-way by `visitor_hash[0..1]`, with a
fan-in coordinator). Sharding kicks in automatically — no flag.

### 10. Server-Side Conversions — the loop closes both ways

```
purchase event fires
  ─▶ write AgentEvent (local truth)
  ─▶ fan out: meta-capi, google-ec, tiktok-events, klaviyo, hubspot
  ─▶ each writes a child event: 'attribution.sent' { platform, status }
```

When `event: 'purchase'` lands, we POST to Meta CAPI, Google Enhanced
Conversions, TikTok Events API — hashed email + phone. **Closes the
attribution loop on platforms that lost cookies to ITP/ATT.**

Inbound ad-platform pixel events normalize back into the same shape.
One graph. Both directions.

---

## The cost shape, end to end

50M-events workspace, baseline → tuned (11 levers):

```
ingest worker
  HMAC, consent, dedup, identity     ~3 ms p50,  12 ms p99

analytics engine
  50M writes × $0.25/M               = $12.50

workspace DO
  RAM working set                    ~120 MB (one shard)
  flush to D1 every 5s
  KV snapshot every 60s
  R2 parquet every 10m

websocket fan-out                    ~1.5M msg / month = $1.50

D1 + R2 + DO duration + workers      ≈ $40

baseline total                       $53 / mo  →  $0.30/M events tuned
```

**11 tuning levers** — client batching, Cache API for the pixel,
deterministic DO routing, Smart Placement co-location, aggressive
WebSocket coalescing, tier-aware fan-out, DO RPC, HTTP/3 + 0-RTT.
Each is independent. Each has a named tradeoff. Stacked: **3.5×
cheaper, 2.4× faster.**

```
$ / M events       $0.30        ── 3.5× cheaper than baseline
p50 ingest         6 ms         ── 2× faster
p99 ingest         45 ms        ── 2.4× faster
p99 watcher        60 ms        ── 1.8× faster
```

---

## What you get out of the box

| Surface | What it shows |
| --- | --- |
| **Pulse** | Live KPI tiles, firehose tail, degradation panel |
| **CRM contact** | Activity feed, identity ladder, appended attributes, reveal audit |
| **Segments** | Tag-prefix queries, live counts via hibernating watchers |
| **Journeys** | Design + holdout + variants + lift with p-value |
| **Discovered** | Mined workflows from the substrate, one-click promotion |
| **Privacy** | Live counter of how many rows a downgrade would affect, before you apply |
| **Reveal audit** | Who read which field, when, with what justification |

Every screen is a topic subscription. Every screen is realtime by default.

---

## Privacy as a competitive moat

Three layers of dials, each more specific than the last:

```
workspace.collection_mode  ∈ { minimal, balanced, forensic }
   minimal:    hashes + essential only
   balanced:   identity + content + append, no fingerprint  ← default
   forensic:   everything (full IP, device, mouse trace, content body)

workspace.collect.<class>  ∈ { on, off }
   override individual classes regardless of mode

actor.collect_override     ∈ { default, minimal, forensic }
   per-actor opt-out — ONLY their events drop to hash-only
```

**What still never lands, regardless of mode:**

- Credentials (entropy + length pattern match → rejected at the gate)
- Government-ID-class fields (SSN, passport, bank account)
- Special-category GDPR Art 9 data (health, biometric, religious, etc.)
  unless an explicit workspace legal-basis declaration is in place

---

## Agents are first-class

The CRM doesn't distinguish humans from agents. The pipeline doesn't
either. An agent that uses your API gets an `actor_id`, `same-as` rows
when its keys rotate, pheromone on its inbound paths, and enrollment
in journeys like `onboarding-agent-d7`.

```
agent verbs (additive, not replacing human verbs):
  sdk.init            first SDK construction with a fresh key
  api.call            authed HTTP hit
  tool.invoked        MCP tool call
  tool.completed      with success/failure
  capability.bound    accepted a published capability
  signal.sent         emitted into the bus
  ask.resolved        ask() returned a non-timeout
  evolve.triggered    self-rewrote system prompt
  harden.promoted     a hypothesis was hardened
```

The DevRel funnel becomes measurable the same way the marketing funnel
is: visit docs → SDK install → first init → first API call → first
`tool.invoked` → first conversion of *its* user.

---

## Install in 60 seconds

```html
<script async src="https://one.ie/p/one.js"
        data-ws="acme"
        data-consent="auto"
        data-link-rewrite="on"
        data-spa="auto"></script>
```

≤ 4KB gzipped. No third-party calls. `data-consent="auto"` reads
`__tcfapi` + GPC. `data-link-rewrite="on"` makes outbound clicks
tracked automatically.

**Server SDK:**

```ts
import { one } from '@oneie/sdk'
one.init({ workspace: 'acme', key: env.ONE_KEY })
await one.track({ event: 'purchase', actor: 'ada', payload: { amount: 79 } })
```

**CLI:**

```
oneie track --event purchase --actor ada --amount 79 --workspace acme
```

**MCP servers** built on `@oneie/mcp` auto-emit `tool.invoked` and
`tool.completed` with `actor_type: 'agent'`. Zero config.

---

## The one-line summary

> Tracking is the act of writing a typed event with a hashed identity
> to a single store, gating by consent, and emitting a substrate signal
> so paths can `mark`, `warn`, or `fade`. Workers eat HMAC + consent in
> 3ms and write the firehose to Analytics Engine for $0.25/M. A copy
> goes to a workspace Durable Object where TypeDB lives in RAM, rollups
> are O(1), and hibernating WebSockets fan out to watchers without
> paying per idle connection. D1 holds the warm 14-day window; R2
> holds full fidelity at parquet prices. The brain is at the edge. The
> watchers are free until something interesting happens. Tuned, the
> receipt is **$0.30 per million events at 40ms p99**.

---

[ Install the pixel ]    [ Read the full spec ](tracking.md)    [ Talk to us ]

*One pipeline. Five identity rungs. Eight sources. One graph. Zero drift.*
