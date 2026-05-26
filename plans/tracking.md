# tracking.md — every interaction is a signal

Companion to [`crm.md`](crm.md), [`crm-pages.md`](crm-pages.md),
[`agent-analytics.md`](agent-analytics.md). Tracking is **not a
separate system**. Every observed interaction — a click, an open, an
email reply, an agent tool-call, a webhook from Stripe — lands as the
same `AgentEvent` row, hashed to the same `visitor_hash`, stitched to
the same `actor_id`, written to the same store, and broadcast to the
same realtime watchers.

One pipeline. Five identity ladders. Every output ends as a signal
the substrate can `mark`, `warn`, or `fade`.

```
                                ┌──────────────────────┐
   web pixel    ─┐              │  POST /api/events    │
   /go/:id      ─┤              │                      │── Analytics Engine (firehose)
   email open   ─┤              │  1. verify (HMAC,    │
   email click  ─┤              │     cookie, sig)     │── Workspace DO (TypeDB in RAM)
   server SDK   ─┼─── batch ───▶│  2. derive visitor   │     ├── rollups O(1)
   MCP tool     ─┤              │  3. resolve actor    │     ├── WebSocket fan-out
   CLI verb     ─┤              │  4. apply consent    │     └── WAL → D1 / KV / R2
   channel bot  ─┤              │  5. write + emit     │
   ad webhook   ─┘              │     signal           │── D1 warm (14d)
                                └──────────────────────┘── R2 parquet (2y)
                                            │              TypeDB snapshot (∞)
                                            ▼
                            substrate signal { receiver, data }
                            → mark / warn on path · fade · follow
```

Three parts:

| Part | Covers |
| --- | --- |
| **I — model** | The contract: event shape, identity, sources, verbs, append, attribution, privacy. *What we record.* |
| **II — pipeline** | Workspace DOs, TypeDB-in-RAM, realtime watchers, storage tiers, failure modes, budget. *How the bytes move.* |
| **III — tuning** | 11 levers to halve cost and latency, with tradeoffs named. *How fast and how cheap.* |

---

# PART I — model

## 0. The contract

```ts
// agent-analytics.md AgentEvent shape — extended, not replaced
interface AgentEvent {
  id: string                 // ULID, client-generated, idempotency key
  ts: number                 // epoch ms
  slug: string               // page/agent/skill/route slug
  agent_id: string | null    // when the event involves an agent
  event: string              // verb taxonomy below
  variant?: string           // A/B variant id
  visitor_hash: string       // sha256(cookie_id + workspace_salt)
  thread_id?: string         // for conversational events
  actor_id?: string          // resolved actor (if known)
  actor_type?: 'human' | 'agent' | 'anonymous'
  source: 'web' | 'sdk' | 'mcp' | 'cli' | 'email' | 'channel' | 'webhook' | 'pixel'
  channel?: string           // telegram | discord | email | sms | web | …
  campaign?: string          // campaign id
  link_id?: string           // /go/:id when it came from a tracked link
  referrer?: string          // domain only
  user_agent_class?: string  // 'mobile-ios' | 'desktop-chrome' | 'bot' …
  locale?: string            // BCP47
  payload: Record<string, unknown>   // event-specific data
  consent_state: string      // 'granted' | 'denied' | 'implied' | 'unknown'
  region: string             // ISO-3166 country, geo-IP coarse only
}
```

This shape is **append-only**. Renaming a field breaks aggregations.
Add a column with a default, deprecate the old one with an `until`
date. See `agent-analytics.md` §"Compatibility invariants".

---

## 1. The identity ladder

A visitor walks up the ladder as we learn more. Each rung is a
deterministic hash with provenance, never raw PII in stored joins.

```
rung 0   device       cookie_id                                   set on first hit, 2y
rung 1   visitor      visitor_hash = sha256(cookie + ws_salt)     written on every event
rung 2   email        email_hash   = sha256(lowercase + global)   set on email open/click/form
rung 3   phone        phone_hash   = sha256(e164 + global)        set on sms or form
rung 4   account      actor_id     = ULID                         on signup / verify / merge
rung 5   linked       (actor_id ⟷ external_id)                    stripe_cus_*, oauth subs
```

**Merge rule** — when a new rung resolves on an existing visitor_hash,
a `same-as` relation is written with `confidence` and `merged-at`.
Past events are **not** rewritten; queries union via `same-as`.
Auditable.

**KPI** — `identity-resolution-rate > 95%` (from `agent-analytics.md`
KPI ladder). Below threshold, the `crm` agent warns.

---

## 2. Sources — what fires, where

Every source produces the same `AgentEvent` shape. The `source` field
tells you which pipeline. Nothing else differs.

### 2.1 Web pixel — `one.js` (≤4KB, one tag)

```html
<script async src="https://one.ie/p/one.js" data-ws="acme"></script>
```

What it does, in order:

```
1. Read/set `_one` cookie    → cookie_id (uuid v7)
2. Derive visitor_hash        → sha256(cookie + workspace_salt)
3. Read URL params            → utm_*, campaign, oid, ref
4. Read consent state         → __tcfapi, gpc, custom flag
5. POST /api/events           → pageview event with the above
6. Bind handlers              → click, submit, scroll-depth, idle, exit
7. Tracked-link interception  → rewrite same-host links with link_id
8. SPA support                → patch history.pushState + popstate
```

The pixel emits:

| Event | When | Payload |
| --- | --- | --- |
| `pageview` | every navigation | `{path, title, referrer, dwell?}` |
| `click` | element with `data-track` or external link | `{target, text, href, link_id?}` |
| `submit` | form submit, with consent | `{form_id, fields_hashed, fields_raw?}` |
| `scroll` | 25/50/75/100% depth | `{pct}` |
| `idle` | 30s no input | `{lastEvent}` |
| `exit` | beforeunload | `{durationMs, max_scroll}` |
| `engage` | first meaningful interaction | `{eventType}` |
| `error` | window.error in instrumented region | `{message_hash}` |

**Two modes, set by consent (§8.1).**

- *Pseudonymous mode* (denied / unknown consent): the pixel hashes
  email, phone, name client-side before POST. Raw values never leave
  the browser. `fields_hashed` only.
- *Identified mode* (granted consent, workspace mode ≥ balanced): the
  pixel POSTs raw values over TLS alongside their hashes. The ingest
  Worker writes hashes to the event row and routes raw values straight
  to the vault (§8.3) — they never appear in the event stream, in
  parquet, in logs, or in any join-mode query. `fields_raw` is
  consumed and discarded at the ingest boundary; only the vault row
  retains it, KMS-sealed.

Credentials, government-IDs, and Art-9 special-category fields are
always rejected at the ingest gate (§8.7) regardless of mode.

### 2.2 Tracked redirect — `/go/:id` and `/r`

The link Worker. From `crm.md` §4 — restated for completeness:

```
/go/:id          short, HMAC-signed, opaque
/r?u=…&c=…&e=…   long, email-hash-keyed, for forwards

Worker hot path (target < 50ms):
  1. HMAC verify              → reject tampered ids
  2. Resolve (actor, campaign, channel, link_id) from id
  3. Set `_one` cookie if absent
  4. Write event: source='pixel', event='click', link_id, …
  5. 302 to destination with ?oid=<visitor_hash> appended
```

The redirect is the only place a **previously-unknown email** can
become a known `email_hash` without a form submit — because the long
form embeds it directly.

```
https://one.ie/r?e=<email-hash>&c=apr-q2&u=/pricing&s=<hmac>
```

When the destination page loads, `oid` is read by the pixel and posted
on the next event. The visitor is now bound to that email_hash.

### 2.3 Email — open pixel + rewritten links

```
open pixel:   <img src="https://one.ie/o/<token>.gif" width="1" height="1" />
links:        every <a href> rewritten → /go/:id before send
```

Open is a 1×1 transparent gif served from `/o/:token.gif`. Token
encodes `(actor_id, message_id, campaign_id, hmac)`. Headers force
no-cache. Single 200, no redirect. Event row written before bytes
return.

```
mail-tracking events: open, click, soft-bounce, hard-bounce, complaint, unsub
```

Soft/hard-bounce, complaint, unsub come from the ESP webhook
(Postmark / Resend / SES) — same shape, `source: 'webhook'`,
`channel: 'email'`.

### 2.4 Server SDK — `@oneie/sdk`

```ts
import { one } from '@oneie/sdk'
await one.track({
  actor: 'ada',
  event: 'subscription.started',
  payload: { plan: 'pro', amount: 79 },
})
```

Server events skip the pixel; they're signed with the workspace key.
The SDK batches every 100ms or 100 events, whichever first. Failures
buffer to disk (in Workers, Durable Object state).

### 2.5 MCP tool — every tool-call is a track

Any MCP server built on `@oneie/mcp` auto-emits `tool.invoked` and
`tool.completed` events with `actor_type: 'agent'`. The substrate
treats agent tool-calls as first-class interactions — `mark` on
success, `warn` on failure, pheromone on the path.

### 2.6 CLI verb — every command is a track

The `oneie` CLI emits `cli.command` events tagged with verb + args
hash + exit code. Lets you measure DevRel funnels the same way you
measure marketing funnels.

### 2.7 Channel adapters — Telegram/Discord/SMS

Inbound messages, reactions, joins, leaves → events.
Outbound sends, deliveries, read-receipts → events.
Both ends, same shape, `source: 'channel'`.

### 2.8 Ad platform webhooks — pixel + CAPI

Server-side conversions go **both ways**:

- **Pixel events from platforms** (Meta Pixel, GA4 collect, TikTok
  pixel) → normalized to `AgentEvent`, source `webhook`.
- **Conversions API push** — when an `event: 'purchase'` fires, we
  also POST to Meta CAPI / Google Enhanced Conversions / TikTok
  Events API with hashed email + phone. Closes the attribution loop
  on platforms that lost cookies to ITP/ATT.

```
purchase event fires
  ─▶ write AgentEvent (local truth)
  ─▶ fan out: meta-capi, google-ec, tiktok-events, klaviyo, hubspot
  ─▶ each writes a child event: 'attribution.sent' { platform, status }
```

---

## 3. Verb taxonomy

The verbs from `crm.md` and `marketing-ontology.md`, normalized to one
table. Append-only.

```
view          impression / pageview / open
engage        meaningful interaction (scroll≥50, dwell>10s, hover-card)
click         link, button, CTA, tracked-link redirect
submit        form, intake, signup
identify      email/phone/account bound to visitor
subscribe     newsletter, push, plan
purchase      payment success
renew         subscription cycle
refund        refund / chargeback
cancel        subscription end
churn         no engagement > N days (synthetic)
unsub         opt-out from channel
complaint     spam-mark, abuse report
bounce        delivery failure (soft/hard)
reply         inbound message
mention       social mention with handle/email match
referral      explicit referral submission
review        review/rating submission
nps           NPS / CSAT / CES submission
ai-citation   agent cited by external LLM (tracked via UTM + ref)
offline-call  CRM-logged phone call
offline-meet  CRM-logged meeting
handoff       human → agent or agent → human pass
tool.invoked  agent called a tool
tool.completed agent tool returned
journey.entered  enrolled in a journey
journey.advanced moved to next stage
journey.dropped  drop trigger fired
broadcast.sent   message delivered
attribution.sent CAPI/EC/Events push out
conflict       contradictory signals (e.g. unsub + purchase same actor)
brand-safety   adjacency / content-safety flag
```

Weights in `marketing-ontology.md` §Touch verbs are the defaults; any
agent can override per-campaign in the broadcast definition.

### 3.1 Weight variations — amplify what matters

Default deposit weight is `1`. Four overrides bend the substrate
toward the signals worth more:

| Scenario | Weight | Why |
| --- | --- | --- |
| Normal call | `1` | baseline — most events |
| Error / partial outcome | `0.5` | something was attempted; half-credit |
| Success carrying a rubric score | `rubric_avg × 5` | amplify verified quality |
| Payment settlement | `amount × 10` | economic signals are rare and valuable |

```ts
// after a successful mark with rubric scores
emit('mark', ['rubric'], {
  edge: 'a→b',
  rubric: { fit: 0.9, form: 0.8, truth: 0.95, taste: 0.85 },
  weight: 0.875 * 5,   // rubric avg × 5 = 4.375
})

// payment settled for $79
emit('purchase', ['channel:web'], { amount: 79, weight: 790 })
```

Why this matters: the L4 ECONOMIC loop becomes self-tuning. Paths
that move money outweigh paths that only move attention by 10× per
event. Highways that emerge from amount-weighted paths are revenue
paths, not vanity paths.

---

## 4. Append — third-party data, one-way, event-driven

Tracking is not just recording — it's **enriching what we record**.
When the identity ladder climbs a rung, importer agents subscribe and
write attributes back onto the actor.

```
visitor → identify (email)  → emits actor.lifecycle:lead
                              ─▶ import-clearbit         (firmographic)
                              ─▶ import-apollo           (org graph)
                              ─▶ import-fullcontact      (social handles)

actor → lifecycle:customer    ─▶ import-stripe           (billing)
                              ─▶ import-shopify          (orders)
                              ─▶ import-zendesk          (support tickets)
                              ─▶ import-segment          (legacy CDP migration)

actor → channel:meta linked   ─▶ import-meta-pixel       (off-site clicks)
actor → channel:ga4 linked    ─▶ import-ga4              (session data)
```

**Namespace** — every appended attribute lives at
`appended.<source>.<field>`. Provenance preserved: agent id,
fetched-at, confidence, raw response hash. Re-import does `fade()`
first then write — never silently overwrites.

**Trigger** — importers subscribe to substrate signals via
`world.on('actor.lifecycle.changed', …)`. No cron, no polling, no
queue. The substrate's signal stream **is** the job queue.

---

## 5. Identity stitching — five strategies

In order of confidence (`marketing-ontology.md` § Identity merge).

### 5.1 Deterministic — confidence 1.0

- **Auth-provider sub match** (`oauth.sub == oauth.sub`)
- **Verified email-hash match**
- **Verified phone-hash match**
- **Cookie inheritance via tracked link** (`/go/:id` → `oid`)

### 5.2 Probabilistic — confidence 0.6–0.95

- **first-name + last-name + IP-prefix + 24h window**
- **device fingerprint stable across N events** (UA class + locale + tz)
- **shared household IP** (lowered confidence, marked household-not-person)
- **temporal proximity** (signup ts within 60s of last visit ts on same IP)

### 5.3 Declared — confidence 1.0

- User claims an existing email in an account settings page
- Admin manually merges in `/crm/c/:actor` (`.` → merge)

### 5.4 Cross-device — via tracked links

The single most powerful technique: a tracked link in an email crosses
device boundaries the moment a logged-out user opens it on their phone.
The redirect sets a `_one` cookie keyed to the same actor_id; the next
mobile pageview unifies.

### 5.5 Server-side seal — the close

When an authenticated session sees a known cookie, the SDK calls
`one.identify(actor_id)` and seals the binding server-side. Cookie
becomes immutable for that actor; future devices add via auth match.

---

## 6. Cross-channel attribution

Every event carries `channel`, `campaign`, `link_id`. The
`attribution` relation joins them to outcomes:

```
attribution(touch, conversion, weight, model, window-ms)
  models: last-touch | first-touch | linear | time-decay | position-based | shapley
  window: per-campaign override; default 14d
```

When a purchase fires, the attribution agent walks back along
`same-as`-unioned events within the window, applies the model, writes
weighted `attribution` rows. Total weight per conversion = 1.0.

**Holdout** — every broadcast can mark a fraction as control. The
`analyst` agent computes lift as
`(treatment_cvr - control_cvr) / control_cvr` with `p-value` via
two-proportion z-test. Below `p < 0.05` the lift is reported but the
journey doesn't auto-promote the variant.

### 6.1 Mined workflows — the substrate finds your funnels

Attribution looks back from a known conversion. **Workflow mining
looks forward** from a tag and finds the sequences that lead anywhere
interesting. Every event chain whose pheromone strength exceeds a
threshold becomes a candidate journey.

```
path chains with strength > 50 (24h window):
  cli:init     → cli:agent      → cli:deploy        (new-project flow)
  sdk:discover → sdk:hire       → sdk:pay           (marketplace flow)
  view:/docs   → click:install  → sdk.init          (DevRel funnel)
  view:/pricing → submit:trial  → identify:email    → purchase
  ui:chat:send  → ui:chat:copy                       (chat satisfaction)
```

The L6 KNOWLEDGE loop runs hourly: any chain with strength above
threshold and at least two outcome events at the tail gets promoted
to a **hypothesis** in TypeDB (`learning` dimension). The CRM surface
shows them at `/crm/j/discovered` — one click to materialize a
hypothesis as a live journey with goals + holdout + variants.

Why this matters: you don't have to **design** the funnels you measure.
The pipeline finds them. The CRM shows them to you. You accept the
ones that look like real workflows; the rest stay as observations.

---

## 7. Agent tracking — agents are first-class

The CRM doesn't distinguish humans from agents. The pipeline doesn't
either. An agent that uses your API gets:

- `actor_id` like any human
- `same-as` rows when its API key, OAuth client, or session_token rotates
- pheromone on its inbound paths (which docs page led to its first
  tool-call? which onboarding step produced the most retained agents?)
- enrolment in journeys (`onboarding-agent-d7`)

The events that matter are slightly different:

```
agent verbs (additive, not replacing human verbs):
  sdk.init            first SDK construction with a fresh key
  api.call            authed HTTP hit
  tool.invoked        MCP tool call
  tool.completed      with success/failure
  capability.bound    accepted a published capability
  capability.priced   set price on a published capability
  signal.sent         emitted into the bus
  ask.resolved        ask() returned a non-timeout
  evolve.triggered    self-rewrote system prompt (L5)
  harden.promoted     a hypothesis was hardened (L6)
```

The DevRel funnel becomes measurable the same way the marketing funnel
is: visit docs → SDK install → first init → first API call → first
tool.invoked → first conversion of *its* user.

---

## 8. Privacy and consent — collect deeply, hold lightly, forget on a click

**This is where we compete.** Most CRMs choose: collect-and-stare (no
opt-out, no key custody, no audit) **or** hash-and-forget (no raw
value, no enrichment, no content). We pick neither: **collect deeply,
encrypt aggressively, audit every read, forget on a click.**

The richest model of every interaction — cross-channel, cross-device,
cross-actor (humans and agents in the same graph) — is the moat.
Pseudonymous hashes are the universal join key; raw values live in an
encrypted vault the customer holds the key to; every read is audited;
delete cascades atomically across every tier.

### 8.1 The three gates — consent unlocks rich collection

Three gates apply **before** an event is written. Failure = the event
falls back to pseudonymous mode (hashes only); only `dropped.event`
is counted, never silently lost.

```
gate 1   consent_state ∈ { granted, implied-where-legal }
         granted    → unlock: full collection (§8.2)
         implied    → unlock where lawful (region-by-region)
         denied     → pseudonymous mode (hashes + essential set only)
         unknown    → pseudonymous mode

gate 2   region rules
         EU/UK: implied not enough for raw collection; need granted
         CA: GPC honoured as opt-out of cross-workspace stitching
         US: state-by-state (CCPA, CPRA, VCDPA, …)

gate 3   suppression
         actor.suppression-reason ∈ {bounce, spam, unsub, gdpr, tcpa}
            → outbound blocked; inbound still recorded (lawful basis)
```

**Consent provenance** — the event that established consent (signup
checkbox, double-opt-in click, TCF v2 string) is itself an event
with a `consent.captured` verb. Auditable trail from any collected
field back to its permission.

### 8.2 What we collect (with consent) — the competitive surface

| Class | Examples | Why we want it |
| --- | --- | --- |
| **identity** | raw email, phone, name, address | join across channels without ladder approximation |
| **network** | full IP, ASN, precise geolocation | fraud detection, household graph, GeoIP-less attribution |
| **content** | message bodies, form fields, transcript turns | RAG over customer history, intent inference, agent training data |
| **device** | canvas hash, WebGL, audio context, font enum | cross-device de-dup in the post-cookie era |
| **behavioral** | mouse trace, scroll velocity, dwell heatmap | engagement quality beyond raw event counts |
| **cross-workspace** | shared `actor_id` across the customer's deployments | one identity per human or agent across the whole product |
| **append-deep** | full Clearbit/Apollo/ZoomInfo enrichment | firmographic graph, buying-committee inference |

Each class is a separately-toggleable collection mode (§8.4). A
workspace starts at **balanced** (identity + content + append) and
can scale up to **forensic** (everything) or down to **minimal**
(hashes only).

### 8.3 How we protect — vault + key custody + audited reads

Raw PII never travels in the event stream. The pipeline writes the
**hash** to the event (the universal join key); the **raw value**
goes to a per-workspace, KMS-sealed vault keyed by `actor_id`.

```
event           agent_events_warm.payload      → email_hash, phone_hash, ip_hash, …
vault           pii_vault[workspace][actor_id] → encrypted blob (KMS-sealed)
                                                  fields: email, phone, ip,
                                                          content, fingerprint
key             customer-managed or one-managed   (workspace setting, §8.3.1)
read audit      every reveal → pii.read event    (who, when, which field, why)
```

The vault is one row per actor, encrypted with a per-workspace data
key derived from a root key the customer can rotate at any time.
Rotation re-wraps the data keys without re-encrypting payloads.
Destruction of the root key renders every vault row in that workspace
mathematically unreadable in milliseconds (`KMS-shred`).

#### 8.3.1 Key custody

| Mode | Key location | Who can decrypt |
| --- | --- | --- |
| `one-managed` (default) | one.ie KMS, region-bound | one.ie services with audit row |
| `customer-managed` | customer KMS (AWS/GCP/Azure) | only when customer key is presented at read time |
| `bring-your-own` | customer-provided, never leaves their infra | only via remote-attested enclave |

#### 8.3.2 Read modes — two paths, only one decrypts

```
join mode     SELECT … FROM agent_events ae
                JOIN actors a USING (actor_id)
              returns: hashes, ids, derived attributes
              no decrypt, no audit row, no PII leaves the warehouse

reveal mode   GET /api/pii/reveal/:actor_id?fields=email,phone
              returns: decrypted fields
              requires: scope=pii:read, presented customer key (if BYOK)
              emits: pii.read event with reader_id, field list, justification
              rate-limited: 100 reveals/hour/admin
```

Most CRM operations never need reveal — they need to **match**, not
to **read**. The vault makes deep collection cheap operationally
because the read path is segregated and observable.

### 8.4 Per-workspace, per-actor controls — fine-grained dials

Three layers of override, each more specific than the last:

```
workspace.collection_mode  ∈ { minimal, balanced, forensic }
   minimal:    hashes + essential only         (matches old §8.1 promise)
   balanced:   identity + content + append, no fingerprint
   forensic:   everything in §8.2

workspace.collect.<class>  ∈ { on, off }
   override individual classes regardless of mode:
     collect.content     = off    (no message bodies stored)
     collect.fingerprint = on     (force-enable in balanced)

actor.collect_override     ∈ { default, minimal, forensic }
   per-actor opt-out:
     when a contact requests minimal collection, ONLY their events
     drop to hash-only — the rest of the workspace continues normal
```

Each level is reversible. Switching from `forensic → minimal` flushes
the vault rows the new level no longer permits (audited as
`collection.downgraded`). Switching the other way doesn't backfill —
you collect at the new level going forward.

UI: `/settings/privacy` exposes every dial as a toggle, with a live
counter of how many actor rows would be affected by a change before
the change applies.

### 8.5 How we forget — one click, KMS-shred immediate, cascade in 30 days

```
delete request  POST /api/forget
                body: { actor_id? | email_hash? | visitor_hash? }
                scope: this-actor | this-workspace-actors-matching

cascade:
  pii_vault          →  KMS-shred row immediately (unreadable in <1s)
  KV visitor_state   →  immediate delete by key
  agent_events_warm  →  rows redacted: hashes kept, payload nulled, within 5m
  TypeDB             →  actor + same-as rows redacted, paths fade naturally
  R2 parquet         →  next compaction rewrites without rows (≤30d)
  ad platforms       →  outbound DELETE to Meta/Google/TikTok/Klaviyo
  audit log          →  preserved with `forget.cascade` events per tier

receipt: { actor_id, requested_at, completed_at, deleted_counts_per_tier }
```

KMS-shred is the load-bearing primitive: the encrypted vault row
becomes mathematically unreadable the moment its key is destroyed,
even before parquet compaction catches up. The 30-day window is for
parquet/R2 propagation, not for the vault (immediate).

**Reversibility audit** — `GET /api/forget/:request_id` returns the
cascade status across every tier. Customers see the same view DPAs
see. No black box.

GDPR Article 17, CCPA delete, and customer-initiated delete all
flow through this endpoint. Cascade completion within 30 days is
the SLA.

### 8.6 Audit — every reveal is observable

Every read of raw PII is itself an event:

```
pii.read   { actor_id, field, reader_id, reader_kind,
             scope, justification, customer_key_presented }
```

The Pulse page shows reveal volume by reader, by field, by hour.
Anomalies (one admin reading 100 emails at 3am) trigger a
`compliance` agent warn. Customer admins can subscribe to their
own reveal audit log via webhook — they see exactly what one.ie
sees.

### 8.7 What still never lands, regardless of mode

Even at `forensic`, three categories never enter any tier:

- **Credentials** — the ingest Worker pattern-matches secrets
  (`/[A-Za-z0-9_-]{20,}/` + entropy threshold) and rejects payloads
  containing them with `ingest.rejected.credential`.
- **Government-ID-class fields** — SSN, passport, national ID,
  bank-account-number patterns. Rejected at the same gate as
  credentials.
- **Special-category data under GDPR Art 9** unless an explicit
  workspace-level legal-basis declaration is in place (health, racial
  origin, biometric, sexual orientation, religious belief, etc.).

These are the only hard exclusions. Everything else is a dial.

---

## 9. Tag namespaces — speak every standard

Repeated from `crm.md` §7 because tracking is where they enter:

```
iab/content/v3/<id>       content category on a pageview
iab/audience/v1/<id>      audience taxonomy on a visitor
openrtb/v2.6/<field>      bidstream field on an impression
ga4/event/<name>          GA4-shaped event passthrough
meta/event/<name>         Meta event passthrough
meta/audience/<id>        membership in a Meta custom audience
google/match/<list>       Customer Match list
schema.org/Person etc.    structured-data echo
tcf/v2/<purpose>          consent purpose
gpc | ccpa | gdpr | tcpa  jurisdiction flags
canspam                   marketing-email regime
```

When a Meta Pixel event arrives, it's stored with both its native verb
(`ViewContent`) **and** its mapped one (`view`). Queries can use either.

### 9.1 Tags become paths — how tracking learns

This is the connective tissue between *tracking* and the substrate's
learning loops. Every event's tags are not a flat dimension — they
are an ordered list, and **each consecutive pair becomes a path
edge** that gets a pheromone deposit of the event's weight.

```
event tags:  [touch:click, channel:telegram, campaign:apr-q2, persona:founder, region:us]

paths marked (+weight each):
  touch:click     → channel:telegram
  channel:telegram → campaign:apr-q2
  campaign:apr-q2  → persona:founder
  persona:founder  → region:us
```

After N events, the graph has accumulated strength on every observed
pair. The substrate now knows — without any analyst writing a query —
that telegram drove `apr-q2`, that `apr-q2` skewed founder-persona,
that founder-persona skewed US. Those facts are pheromone weights
on real edges in TypeDB, queryable as `world.highways()` or by tag
prefix.

```
hypotheses where tag starts with "channel:":
  channel:telegram → campaign:apr-q2   strength 0.78
  channel:email    → campaign:apr-q2   strength 0.42
  channel:telegram → campaign:winback  strength 0.31
```

Three consequences:

1. **No separate analytics database.** Tag co-occurrence IS the
   analytics. Counts are pheromone strength; trends are strength
   over time; segments are tag-prefix queries.
2. **L6 KNOWLEDGE promotes highways to hypotheses automatically.**
   `channel:telegram → campaign:apr-q2 strength 0.78` becomes a
   hardened pattern after sustained traffic. The CRM surfaces it.
3. **Tag order matters.** Authors should order tags from general to
   specific (`touch:* → channel:* → campaign:* → persona:* → region:*`).
   The ingest Worker enforces canonical order before writing, so
   pair-pheromone is consistent across sources.

The L3 FADE loop applies asymmetrically (strength fades 1×, resistance
fades 2×, per `marketing-ontology.md`) so wrong patterns forget faster
than right ones. Tracking + learning is one mechanism.

---

# PART II — pipeline

## 10. The cost shape we escape

Naïve ingest writes every event straight to D1. At 1B events / month:

```
D1 writes        1,000M × $1/M    = $1,000
D1 reads (dash)  500M × $0.001/M  = ~$0.50
D1 storage       ~250 GB × $0.75  = $187      (3KB/event compressed)
Workers req      1,000M × $0.30/M = $300
Total                              ≈ $1,500 / month
```

It works but it's stupid. We pay D1 for write-once, never-overwrite
event rows where we don't need transactional semantics. Worse, every
dashboard tile re-aggregates the same rows.

**The fix is two-stage:**

```
hot stage   ──▶  Analytics Engine (sampled, $0.25/M writes)
                 + Durable Object RAM (per workspace shard)
warm stage  ──▶  D1 events_warm   (rolled-up + sampled raw, 14d)
cold stage  ──▶  R2 parquet       (full fidelity, 2y, $0.015/GB)
brain       ──▶  TypeDB-in-RAM    (DO-resident, snapshot to KV+R2)
```

Same 1B events:

```
Workers req           1,000M × $0.30/M    = $300
Analytics Engine      1,000M × $0.25/M    = $250
DO requests           ~50M × $0.15/M      = $7.50    (1 per batch of 20)
DO duration           coalesced            = $30
D1 writes (rolled)    ~20M × $1/M          = $20     (warm + hourly rollups)
R2 writes             ~1M × $4.50/M        = $4.50   (parquet flush)
R2 storage            ~30 GB × $0.015      = $0.45
WebSocket out         ~500M msg × $1/M     = $500    (∝ watcher count)
Total                                      ≈ $1,100 (no watchers: ~$610)
```

WebSocket fan-out is the next cost driver — Part III §18 covers how
to hold it down without losing realtime.

---

## 11. The pipeline, end to end

```
   browser / bot / SDK
        │
        ▼
   navigator.sendBeacon (POST /api/events)            ◀── < 4 KB, batched
        │
        ▼
   Workers edge ingest (regional)
        │   ↳ HMAC verify, schema, dedup ULID
        │   ↳ consent gate, suppression check
        │   ↳ derive visitor_hash, climb identity ladder
        │
        ├──▶ Analytics Engine  (hot, sampled, raw)        $0.25/M
        │
        └──▶ Workspace Durable Object  (per workspace)
                  │
                  ├── in-RAM TypeDB shard (writes apply instantly)
                  ├── in-RAM rollup counters (per stage, per channel)
                  ├── WebSocket fan-out (hibernating watchers)
                  ├── flush loop:
                  │       every 5s   → D1 events_warm + rollup tables
                  │       every 60s  → KV snapshot of TypeDB delta
                  │       every 10m  → R2 parquet append
                  │       every 1h   → consolidate TypeDB snapshot to R2
                  └── on DO eviction:
                          → drain WAL to D1, snapshot to R2, mark cold
```

Three things are **on the hot path**: HMAC verify, consent gate, write
to Analytics Engine + DO. That's it. Everything else is asynchronous.

---

## 12. Workspace Durable Objects — RAM as the hot store

One DO per workspace (sharded for very large workspaces — see §13).
Inside lives:

```ts
class WorkspaceDO {
  // in-memory state, restored on first access from KV snapshot + WAL
  typedb: InMemoryTypeDB          // entities + relations + attributes
  rollups: Map<RollupKey, Counter> // per-stage, per-channel, per-day
  recent: RingBuffer<AgentEvent>   // last 10k events for /pulse live tail
  watchers: Map<WatcherId, Sub>    // active WebSocket subscriptions
  wal: WAL                          // unflushed writes, drained every 5s

  async accept(events: AgentEvent[]) {
    // 1) write to in-memory TypeDB (causal graph, identity merge)
    for (const e of events) {
      this.typedb.apply(e)            // O(1) — RAM
      this.rollups.bump(rollupKey(e)) // O(1) — RAM
      this.recent.push(e)             // O(1) — RAM
      this.wal.append(e)              // O(1) — RAM, durable on first flush
    }
    // 2) fan out to watchers (hibernation-safe)
    this.broadcast(events)
    // 3) maybe trigger flush (size or time bound)
    if (this.wal.size >= 1000 || this.now - this.wal.lastFlush > 5000) {
      this.scheduleFlush()           // async, never blocks accept
    }
  }
}
```

**Why DOs.** They pin compute + RAM to a single location, so all
writes for one workspace are serialised without locks. TypeDB's
transactional semantics map cleanly onto DO single-threadedness.

**Why TypeDB-in-RAM.** The brain holds **just enough state to answer
the questions a watcher asks** — recent events, current rollups, the
causal subgraph of the last hour. Cold history lives in D1 + R2 and
is queried only when a user scrolls back. The working set per
workspace is typically 50–500 MB; well within the 128 MB soft +
bursty cap of a single DO instance, with shard split (§13) when it
exceeds.

**Cold start.** On first access after eviction, the DO loads its
TypeDB snapshot from KV (last hour) + replays the WAL diff from D1.
Targets:

| Workspace size | Cold start |
| --- | --- |
| ≤ 10k events/day | < 80ms |
| ≤ 1M events/day | < 300ms |
| > 1M events/day | sharded (§13), no single cold-start matters |

After cold start the DO stays warm under load (DOs hibernate, not
evict, while messages flow). Hibernating DOs cost only storage — RAM
state survives the nap, so re-warm is instant.

---

## 13. Sharding very large workspaces

Most workspaces (95%+) fit in one DO. The ones that don't get sharded
by a stable key — `visitor_hash[0..1]` (256 shards) — with a fan-in
coordinator DO that owns global rollups.

```
       events for ws=acme
              │
              ▼
       hash(visitor_hash[0..1])
       ┌──────┬──────┬──────┐
       │ DO00 │ DO01 │ ...  │     256 shards × (RAM 50–500 MB each)
       └──┬───┴──┬───┴──┬───┘
          │      │      │
          └──────┴──────┴──▶ ws-coordinator DO
                              global rollups (per-channel, per-stage)
                              global watchers (segment counts, KPI tiles)
```

Per-actor watchers (contact page) hit the actor's shard directly.
Workspace-level watchers (pulse, segment count) hit the coordinator,
which aggregates incoming deltas from shards over a single WebSocket
mesh. Sharding kicks in automatically when a DO crosses 256 MB RAM or
2k events/sec sustained — no manual sharding flag.

---

## 14. Realtime watching — hibernating WebSockets

Every CRM screen subscribes to a topic on the workspace DO:

```ts
ws.subscribe({
  workspace: 'acme',
  topic: 'actor:ada' | 'segment:ent-trial-d7' | 'journey:trial-rescue-d14'
       | 'pulse:kpi' | 'inbox:open' | 'global'
})
```

Topics are computed from the event at write time and matched in O(1)
against the watcher map. The DO never re-queries TypeDB to decide who
to notify.

**The cost lever — Hibernatable WebSockets.** A CRM tab left open in
a background browser tab pays nothing until an event arrives. The DO
hibernates the connection; CF wakes it on inbound message at no
duration cost. With 10k watchers and 1B events / month, the fan-out
math becomes a function of *interesting* events, not connection count.

```ts
// inside the DO
broadcast(events: AgentEvent[]) {
  // group events by the topics they touch (computed in-RAM)
  const byTopic = bucketByTopic(events)
  for (const [topic, batch] of byTopic) {
    const subs = this.watchers.byTopic.get(topic) ?? []
    const payload = JSON.stringify({ topic, events: batch }) // batched!
    for (const sub of subs) sub.ws.send(payload)             // wakes hibernation
  }
}
```

**Coalesce.** Outbound messages are batched per (workspace, topic, 50ms
tick). A burst of 200 pageviews on the same page becomes one WebSocket
message, not 200. WebSocket-out billing drops 50–200×.

**Backpressure.** If a watcher's outbound buffer exceeds 1 MB, the DO
switches it to **summary mode** — it stops sending raw events and
sends rollup deltas only (counters, last-N events). The UI degrades to
the same shape Pulse uses; nothing breaks.

**Heartbeat / cleanup.** Every 30s the DO emits a `{ topic, watermark }`
heartbeat so clients can detect gaps and re-sync. A watcher with no
ping for 60s is considered dead and removed.

### 14.1 The watch contract (client side)

```ts
// SDK
import { one } from '@oneie/sdk'
const sub = one.watch({
  topic: 'actor:ada',
  onEvent: (e) => updateActivityFeed(e),
  onSummary: (s) => updateCounters(s),        // arrives in summary mode
  onGap: (since, until) => refetch(since, until), // heartbeat reported gap
})
sub.close()

// Astro / React island
const { events, summary, gap } = useWatch('segment:ent-trial-d7')
```

Under the hood: one persistent WebSocket per browser tab to the
nearest workspace DO. Multiplexed topics. Auto-resubscribe on
reconnect; replays missed events via the watermark.

For non-WebSocket environments (server CRON, edge tasks): SSE fallback
on `GET /watch?topic=…` — same payload shape, same coalescing.

---

## 15. Sampling and dedup — paying only for signal

Not every event needs to survive forever at full fidelity.

```
class                example verbs            sampling
─────                ───────────────          ────────
critical             purchase, refund,        100%, always durable
                     identify, consent,
                     unsub, complaint
business             click, submit, reply,    100% to AE + DO,
                     subscribe                100% to D1 warm
diagnostic           pageview, view, engage   100% AE, 100% DO RAM,
                                              1% raw to D1, 100% rollup
firehose             scroll, idle, mousemove  100% AE (sampled at AE
                     (if ever enabled)         level), never D1, never DO
```

AE is the lossy-but-cheap firehose. D1 warm is the **sampled raw + full
rollup** mid-tier. R2 parquet is full-fidelity cold. The TypeDB graph
holds **only causal events** — the ones that move an actor up the
funnel or change a path's strength.

**Idempotency.** Every event carries a client-generated `id` (ULID).
DO dedup window = 60s. Beyond that the dedup falls to D1's PRIMARY
KEY on `id`. Retry-safe end-to-end.

---

## 16. Storage tiers and TypeDB persistence

| Layer | What it holds | Persistence |
| --- | --- | --- |
| Analytics Engine | sampled raw firehose | 90 days (CF default) |
| DO RAM | TypeDB working set, rollups, last 10k events | ephemeral |
| DO storage (KV-backed) | TypeDB snapshot + WAL since snapshot | survives eviction |
| KV `typedb_snap/{ws}/{ts}` | hourly compacted snapshots | 30 days |
| R2 `typedb/{ws}/{day}.tdb` | daily consolidated, full graph | indefinite |
| D1 `agent_events_warm` | sampled raw events + hot rollups | 14 days |
| R2 `events/{ws}/{day}.parquet` | full-fidelity events | 2 years |

TypeDB-in-RAM is fast but ephemeral. Truth lives in the durable
layers above. The DO writes its WAL into DO Storage on every flush —
even if the DO process dies mid-burst, no in-memory state is lost
beyond the WAL window.

**Reconstruction.** Any workspace's graph at any past moment =
`R2 daily snapshot + KV hourly diffs + D1 warm rows`. Replayable.
Auditable. Matches GDPR's "rectification on request" cleanly.

**Snapshot strategy.** Copy-on-write. While the DO accepts new writes
into version `v+1`, the snapshotter serialises version `v` to KV
without blocking. Single-threaded model → no locks → bounded latency.

---

## 17. Cost ceilings — the budget

Hard ceilings, enforced by the ingest Worker. Above the ceiling, the
Worker degrades (it never errors — degrades).

| Tier | Events/mo | DO RAM | WS watchers | Hard cap |
| --- | --- | --- | --- | --- |
| free | 100k | 64 MB | 5 | sampled diagnostic 10% |
| pro  | 10M  | 256 MB | 50 | sampled diagnostic 100%, firehose 1% |
| scale | 1B | 2 GB (sharded) | 1k | full fidelity, all tiers |
| enterprise | 10B+ | sharded | 10k+ | dedicated DO class, custom retention |

Per-workspace knobs:

```
ingest.max_eps              events / sec (token bucket on the Worker)
ingest.max_payload          bytes / request
ingest.sample.diagnostic    0..1
ingest.sample.firehose      0..1
realtime.coalesce_ms        0..500
realtime.summary_threshold  0..N (bytes before summary mode)
```

Defaults sit at pro tier. Overages emit `ingest.throttled` events with
the dropped count, so dashboards show degradation explicitly rather
than silently losing data.

### 17.1 Per-session rate limit — cheap DoS protection at the edge

Above the per-workspace token bucket, a **per-session** cap stops a
single rogue browser tab or runaway agent loop from dominating the
pipeline.

```
session limit:    100 signals / hour / sessionId   (silent drop)
session id:       16 chars (browser: crypto.randomUUID().slice(0,16);
                            server:  sha256(randomBytes).slice(0,16))
counter store:    KV with TTL=3600, key=`rate:session:<id>`
exceed action:    Worker returns 204 immediately, increments
                  `ingest.rate_limited.session` metric, no DO call
```

100/hour is generous for humans (a heavy CRM session emits ~200
events/hour total across all sources). It's a hard wall for runaway
loops. A polite client that hits the wall sees no error — events
just stop landing. The metric is visible on the Pulse degradation
panel.

Defense in depth:

```
edge cap        session  100/hr  KV TTL counter, free-tier safe
workspace cap   token bucket per tier (§17)
DO cap          RAM size + EPS triggers shard split (§13)
```

Each layer protects the next. The cheapest layer absorbs the most
attacks.

---

## 18. Failure modes, by name

| Failure | Detected | Mitigation |
| --- | --- | --- |
| AE write fails | Worker return | drop event with `ingest.lost` metric (rare; AE has 99.99% SLO) |
| DO unavailable | Worker timeout 500ms | enqueue in CF Queue, retry; emit `ingest.deferred` |
| WAL flush fails | DO `tryFlush` | hold in RAM until 64 MB cap, then shed oldest non-critical |
| KV snapshot fails | snapshot loop | retry exponential; never block accept loop |
| R2 parquet append fails | flush loop | hold rows in D1 warm; retry next interval |
| WebSocket overload | watcher buffer > 1 MB | switch sub to summary mode; emit `realtime.summary_started` |
| TypeDB shard OOM | DO RAM > 256 MB | split shard (§13); migrate hottest 50% of `visitor_hash` range |
| Workspace burst | EPS > tier cap | token bucket drops + emits `ingest.throttled` (count + sampled keys) |
| Replay desync | heartbeat watermark gap | client calls `onGap` callback with `(since, until)` for fetch |

Every failure mode emits an event into the same pipeline it tries to
protect — so the dashboard reflects its own health. The substrate
watches itself.

---

## 19. Backfilling and rebuilds

When we add a new rollup, a new KPI, or fix an event mapping, we don't
re-ingest the firehose. We replay from R2 parquet.

```
rebuild job:
  R2 parquet (last N days)
    ─▶ stream into a transient DO ('replay-{ws}-{job}')
    ─▶ apply to TypeDB in batches of 10k
    ─▶ emit rollup writes to D1 + R2
  on completion: swap snapshot pointers atomically
```

A rebuild for a 1B-events workspace takes ~30 minutes on a single DO
shard, hours sharded — and never touches live ingest. Cost = a few R2
reads + DO duration, no AE charges, no double-billing.

---

## 20. Worked example — 50M-events workspace (baseline)

Concrete shape, end to end. Workspace `acme`, 50M events / month,
~20 events / sec average, 1k peak EPS, ~200 simultaneous watchers
(mostly CRM tabs and a Pulse dashboard on a wall TV).

```
ingest worker
  HMAC, consent, dedup, identity     ~3 ms p50,  12 ms p99

analytics engine
  50M writes × $0.25/M               = $12.50

workspace DO
  RAM working set                    ~120 MB (one shard, no split)
  in-memory writes                   ~20 / s avg, batched into 50ms ticks
  flush to D1 every 5s               6 K rollup rows / day → 50M event/mo at 1%
                                     sampled raw = 500k rows / month
  KV snapshot every 60s              ~5 MB each, 1.5 GB / month rolling 30d
  R2 parquet every 10m               ~30 MB / day, ~900 MB / month

websocket fan-out
  ~200 watchers × ~1 msg/200 events (coalesced 50ms)
  = ~50k msg / day to clients = ~1.5M msg / month
  cost = $1.50

D1
  writes ~1M / month (warm sample + rollups)  = $1.00
  reads ~50M / month (dashboards via cache)   = $0.05
  storage ~10 GB                              = $7.50

R2
  writes ~150k / month                        = $0.70
  storage ~22 GB over 2y                      = $4.00

durable object
  requests ~3M / month                        = $0.45
  duration ~50 GB-s                           = $10
  storage ~2 GB                               = $0.40

workers requests                              ~50M / month = $15

Total monthly                                 ≈ $53
```

Per million events: ~$1.06. Per watcher-month: ~$0.0075. Realtime
update latency p50 35ms, p99 110ms.

Part III shows how to halve both.

---

# PART III — tuning

## 21. The tuning levers

Same architecture, sharper knobs. Eleven levers, each independent —
adopt the ones that fit, skip the rest. Order is rough cost-impact
descending. **Tradeoff is named** for every lever so you can roll it
back if a workload doesn't fit.

**Tuned target** (compared to §20):

```
$ / M events       $0.30        ── 3.5× cheaper than $1.06
p50 ingest         6 ms         ── 2× faster
p99 ingest         45 ms        ── 2.4× faster
p50 watcher        15 ms        ── 2.3× faster
p99 watcher        60 ms        ── 1.8× faster
```

### L1 · Browser-side batching — fewer requests, more events per request

The pixel buffers up to 20 events or 250ms, flushes via
`navigator.sendBeacon`. Critical events bypass the buffer.

```ts
// inside one.js
const buf: Event[] = []
let timer: number | null = null
function emit(e: Event) {
  if (CRITICAL.has(e.event)) return flush([e])
  buf.push(e)
  if (buf.length >= 20) flush(buf.splice(0))
  else timer ??= setTimeout(() => flush(buf.splice(0)), 250) && (timer = null)
}
function flush(batch: Event[]) {
  navigator.sendBeacon('/api/events', JSON.stringify({ batch }))
}
addEventListener('pagehide', () => buf.length && flush(buf.splice(0)))
```

Workers requests collapse ~10×. **-$270/mo at 1B events.**
Tradeoff: up to 250ms client-side staleness on diagnostic events.

### L2 · Tail Worker for Analytics Engine

The ingest Worker emits raw events via `console.log`. A Tail Worker
consumes the log stream and writes to AE asynchronously. p99 ingest
drops ~25ms. Tail invocations add ~$15/mo at 1B — roughly cost-neutral,
latency-positive.

### L3 · Pixel + 1×1 gif served from Cache API — zero-CPU pageviews

`GET /p/one.js` and `GET /o/<token>.gif` matched in Cache API first.
Cache-hit Worker bills ~0.05ms CPU. Event write happens entirely in
`ctx.waitUntil()` with the response already on the wire.

```ts
const cache = caches.default
const hit = await cache.match(req)
if (hit) return hit                                  // ~0 CPU billed
ctx.waitUntil(workspaceDO(env, ws).accept([openEvent(token)]))
return new Response(GIF_BYTES, { headers: GIF_HEADERS })
```

Workers GB-s drops ~40% for pixel-heavy workloads. **-$10–40/mo.**
Tradeoff: must purge CF cache on pixel version bump (deploy hook).

### L4 · Browser → DO direct over WebSocket — skip Worker per event

After the first POST, the pixel upgrades to a WebSocket directly to
the workspace DO. Subsequent events flow at DO message cost (~$1/M)
without a Worker invocation each.

```
session start    POST /api/events  → Worker hot path (HMAC, deriv)
                      ↓
                 Worker returns { ws_url, token }
                      ↓
session steady   WSS /ws/:ws?token=…
                      ↓
                 DO accepts messages directly (verifies HMAC itself)
```

Workers requests collapse to **one per session**. Tradeoff: long-lived
WSs cost connection-hours. Heuristic — upgrade only when ≥3 events
fire in the first 10s; else stay on POST.

### L5 · Stateless verify — no KV read on the hot path

Workspace tokens are signed JWTs with workspace id + sample rate +
tier baked in. The Worker verifies with a key loaded once at cold
start. KV op cost disappears; p99 ingest -5–25ms.

```ts
const { ws, tier, sample } = await verifyToken(req.headers.get('x-ws-token'), env.HMAC_KEY)
```

Tradeoff: token rotation needs a 30-day overlap window where both old
and new keys validate.

### L6 · Deterministic DO routing — no lookup, no rebalance

Workspace DO id = `idFromName(ws_slug)`. Shard id =
`idFromName(ws_slug + ':' + visitor_hash[0..1])`. No directory
lookup, no rebalancing on cold start. **-10ms p99.**

```ts
const shardId = env.WS_DO.idFromName(`${ws}:${visitorHash.slice(0, 2)}`)
const stub = env.WS_DO.get(shardId, { locationHint: 'wnam' })  // optional pinning
```

### L7 · Smart Placement + region pinning — collapse Worker↔DO RTT

Enable Smart Placement on the ingest Worker. For workspaces with a
known centroid, set `locationHint` on the DO stub so subsequent
invocations co-locate.

```toml
# wrangler.toml
[placement]
mode = "smart"
```

Worker→DO RTT drops from 30–80ms (transcontinental) to 1–5ms (same
datacenter). **p50 ingest -8ms, p99 -40ms.** Tradeoff: pinning trades
TTFB for the minority of users far from the centroid. Auto mode tunes.

### L8 · Aggressive WebSocket coalescing + summary mode — largest win

```
coalesce window         50 ms          (was 0 in some PoCs)
per-watcher cap         200 events/s   (else switch to summary mode)
summary heartbeat       1 s            (counters only, no events)
hibernate idle          10 s           (was 30 s)
backpressure threshold  256 KB         (was 1 MB)
```

Most CRM screens don't need every raw event. Journey edges are
summaries. Pulse tiles are counters. Only contact detail benefits
from raw events, and even there 50ms coalesce is imperceptible.

WebSocket messages collapse ~20× under bursts. **At 1B events with
1k watchers, fan-out drops $500 → $50 = -$450/mo.** Tradeoff: up to
50ms perceived latency on the activity feed (sub-perceptible).

### L9 · Tier-aware fan-out — only paying customers get the WebSocket

Free-tier workspaces use a 5s polling SSE endpoint. Paid tier gets
WebSockets.

```
free tier:    GET /poll?topic=…&since=…   every 5s
                response: { rollups, events: [], watermark }

paid tier:    WSS /ws  (hibernating, coalesced)
```

Free tier is ~80% of workspaces but ~10% of revenue. Pulling them off
WS drops fan-out cost dramatically. **-$200–400/mo.** Tradeoff: free
tier sees up to 5s staleness — part of the upgrade conversation.

### L10 · DO RPC (not fetch) — drop request framing

Use Workers RPC bindings between the ingest Worker and the workspace
DO. Skip the `fetch(req)` framing inside the DO.

```ts
// instead of: await stub.fetch('/accept', { method: 'POST', body: ... })
const result = await stub.accept(events)   // typed RPC, structured args
```

**-2ms p99**, more under load. Requires Wrangler v3.79+ and
`compatibility_date` ≥ 2024-04-03 (we're past both).

### L11 · Compression, HTTP/3, 0-RTT, preconnect — free wins

```toml
compatibility_flags = ["http_compression"]
```

```ts
const body = await deflate(JSON.stringify(batch))
navigator.sendBeacon('/api/events', new Blob([body], { type: 'application/octet-stream;encoding=deflate' }))
```

```html
<link rel="preconnect" href="https://one.ie">
<link rel="dns-prefetch" href="https://one.ie">
```

CF terminates HTTP/3 + 0-RTT automatically when clients support it.
First event of a return visit lands in **<5ms** wall-clock. Bandwidth
~5× smaller. First-event latency **-20–50ms.**

---

## 22. Stacked impact

50M-events workspace, baseline (§20) → tuned:

```
baseline                          $53.00 / mo
  L1 client batching              -$5.40   →  $47.60
  L2 tail-worker AE               +$0.75   →  $48.35
  L3 cache pixel + gif            -$1.50   →  $46.85
  L4 browser→DO WS                -$0.65   →  $46.20
  L5 stateless verify             -$0.25   →  $45.95
  L6 deterministic routing         $0      →  $45.95
  L7 Smart Placement              -$0.50 (latency mainly)
  L8 WS coalesce + summary        -$22.50  →  $23.45      ← largest single win
  L9 tier-aware fan-out           -$8.00   →  $15.45
  L10 DO RPC                      -$0.15   →  $15.30
  L11 compression / HTTP3         -$0.30   →  $15.00

total                             $15.00 / mo            ── 3.5× cheaper
per-million events                $0.30
```

Latency, p99 ingest path:

```
baseline           110 ms
  L1 (no change — batch is parallel)
  L2 -25 ms        85 ms
  L3 -5 ms         80 ms     (cache-hit pixel CPU)
  L5 -10 ms        70 ms
  L6 -10 ms        60 ms
  L7 -15 ms        45 ms     (Worker↔DO co-located)
  L10 -2 ms        43 ms
  L11 -3 ms        40 ms     (HTTP/3 0-RTT amortised)

stacked                       40–45 ms p99
```

Watcher latency, p99:

```
baseline           110 ms
  L7 (Worker↔DO)   -15 ms
  L8 coalesce       0 (adds 50ms but smooths spikes by 60ms+)
  L11 HTTP/3       -10 ms
  WS proximity     -25 ms (DO at user's region for paid tier)

stacked                       60 ms p99
```

---

## 23. What we deliberately did NOT optimise

Things that look like wins but break the model. Listed so we don't
re-litigate.

| Idea | Why we skipped |
| --- | --- |
| Skip Analytics Engine entirely | Lose the firehose for ML / ad-hoc replay. AE is $0.25/M; cheaper than rebuilding from R2. |
| Write events straight to D1 from the browser | No HMAC verify, no consent gate — trivially DoSable, and we'd pay $1/M D1 writes for diagnostic events that don't need them. |
| Replace DO with KV | KV is eventually consistent + no compute. Realtime watchers need a single-threaded RAM target. |
| Replace WebSocket with WebTransport | Sub-50ms wins on the wire, but client support is uneven and CF support is preview. Revisit 2026 H2. |
| Skip the open-pixel gif and use 204 | A 204 doesn't render in `<img>` — breaks email clients that pre-fetch images. |
| Inline event in the script GET (Server-Timing trailer) | Exotic, breaks under SRI, breaks the cache. |
| Cookie-encoded consent | Tempting (-1 verify hop) but the consent string is too large after TCF v2, breaks at 4 KB cookie cap. |

---

## 24. The one tag, all features

```html
<script async src="https://one.ie/p/one.js"
        data-ws="acme"
        data-consent="auto"
        data-link-rewrite="on"
        data-spa="auto"></script>
```

The pixel ships behind a CDN, ≤4KB gzipped, no third-party calls.
`data-consent="auto"` reads `__tcfapi` and GPC; `manual` defers to
your CMP. `data-link-rewrite="on"` makes outbound clicks tracked
links automatically (with attr `data-no-track` as opt-out).

Server-side equivalents:

```ts
// Workers / Node / Bun
import { one } from '@oneie/sdk'
one.init({ workspace: 'acme', key: env.ONE_KEY })
one.track({ event: 'purchase', actor: 'ada', payload: { amount: 79 } })

// HTTP
POST https://one.ie/api/events
Headers: x-ws: acme, x-sig: <hmac>
Body:    { event, payload, … }   // or array of up to 100
```

CLI equivalent (`oneie cli`):

```
oneie track --event purchase --actor ada --amount 79 --workspace acme
```

---

## 25. Implementation order

**Baseline (C1–C6) shipped 2026-05-14.** All cycles green, tsc=0.

| Wave | Ships | Closes loop on | Status |
| --- | --- | --- | --- |
| C1 | `src/lib/tracking-types.ts` · `POST /api/events` · `migrations/0031_agent_events_warm.sql` · `analytics-client.ts` updated | typed ingest, idempotent write | ✅ |
| C2 | `src/workers/analytics-relay.ts` rewrite — rollups Map, WAL stub, 50ms alarm coalesce, topic fan-out, WS hibernate | live counters, WS fan-out | ✅ |
| C3 | `src/lib/identity.ts` (cookieId/visitorHash/climbLadder) · `src/pages/go/[id].ts` · `migrations/0032_tracked_links.sql` | rung 0-1 identity, tracked redirect | ✅ |
| C4 | `src/lib/pheromone.ts` vendored world · DO `/highways` `/follow` `/sense` `/snapshot` RPCs · tag-pair mark deposits | in-RAM pheromone, snapshotForActor | ✅ |
| C5 | DO WAL→D1 batch flush (5s) · KV snapshot (60s) · cold-start restore · `migrations/0033_rollup_counters.sql` | durability tier | ✅ |
| C6 | `src/lib/use-watch.ts` SSE hook · `src/pages/api/analytics/watch.ts` WS→SSE bridge | realtime client surface | ✅ |
| W6 | Email open pixel + ESP webhook ingest (Postmark) + link rewrite at send | email lifecycle | ⬜ deferred |
| W7 | Identity ladder rungs 2–5: email-hash → actor_id, `same-as` writes | identity-resolution-rate | ⬜ deferred |
| W8 | Importer agents: clearbit, stripe, ga4 | `appended.<src>.*` namespace | ⬜ deferred |
| W9 | Ad platform CAPI (Meta, Google Enhanced Conversions) | server-side attribution loop | ⬜ deferred |
| W10 | Channel adapter ingest: telegram, discord, sms | unified cross-channel events | ⬜ deferred |
| W11 | Consent gate + suppression enforcement + `DELETE /api/visitor/:hash` | GDPR Article 17 | ⬜ deferred |
| W12 | Attribution agent + holdout lift computation | incremental-ROAS reporting | ⬜ deferred |
| W13 | Sharding (256-way) + coordinator DO | very large workspaces | ⬜ deferred |
| W16 | Replay-from-R2 rebuild job | new rollups without re-ingest | ⬜ deferred |

**Tuning waves** (Part III), shipped after baseline lands:

| Wave | Levers | Why grouped |
| --- | --- | --- |
| T1 | L11 (HTTP/3, preconnect), L6 (deterministic routing) | Pure config, no risk |
| T2 | L1 (client batching), L3 (Cache API for static) | Browser-side + static-asset wins, low blast radius |
| T3 | L8 (coalesce + summary), L9 (tier-aware fan-out) | Largest cost wins; ship behind a flag, A/B by workspace |
| T4 | L7 (Smart Placement), L10 (DO RPC) | Worker-side wins, require deploy + compat date check |
| T5 | L5 (stateless verify), L2 (Tail Worker AE) | Refactors the hot path; ship last |
| T6 | L4 (browser→DO WS) | Highest complexity, smallest cost win; revisit only if WS volume is the bottleneck |

Each wave exits with the same exit scalar: **`$/M events × p99 ingest
× p99 watcher`** compared to the previous wave. The product is a
single number; if it goes up, roll the wave back.

---

## 26. The one-line summary

> Tracking is the act of writing a typed event with a hashed identity
> to a single store, gating by consent, and emitting a substrate
> signal so that paths can `mark`, `warn`, or `fade`. Workers eat
> HMAC + consent in 3ms and write the firehose to Analytics Engine
> for $0.25/M, then hand a copy to a workspace Durable Object where
> TypeDB lives in RAM, rollups are O(1), and hibernating WebSockets
> fan out to watchers without paying per idle connection. D1 holds
> the warm 14-day window; R2 holds full fidelity at parquet prices.
> The brain is at the edge. The watchers are free until something
> interesting happens. Tuned, the receipt is **$0.30 per million
> events at 40ms p99**.

---

*Built on `web/agent-analytics.md` (event store, tiers, KPI ladder),
`one/signals.md` (signal grammar), `one/marketing-ontology.md`
(consent, suppression, attribution windows), `crm.md` (tracked link
shape). No new tables. No new privacy regime. No second pipeline.*
