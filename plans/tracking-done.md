# Tracking — what's shipped, tested, and live

Repo: `one-ie/stage/web/` · Last verified: 2026-05-18 · Worker: `one-demo` → `app.one.ie`

This document is the ground truth for what ONE's tracking pipeline actually does
today. Every claim is backed by a test or a live endpoint you can hit right now.
Run the commands in each section to verify independently.

---

## How to verify

```bash
# Unit tests — 500 tests, all should pass
cd one-ie/one/web && npx vitest run

# Live smoke — copy-paste into terminal, expect the status codes shown
```

---

## 1. Event ingest — `POST /api/events`

**What it does.** Receives a typed AgentEvent from any source (web pixel,
email pixel, channel adapter, SDK, ESP webhook). Writes to D1 `agent_events_warm`.
Broadcasts to the workspace Durable Object for realtime watchers.
Enriches `visitor_hash` via identity ladder if not provided.
Rate-limits at 100 events/hour per visitor (KV, silent 204 on exceed).
Enforces GPC consent server-side (`Sec-GPC: 1` → `consent_state: 'denied'`).
Populates `region` from `CF-IPCountry` when client omits it.

**Source.** `web/src/pages/api/events.ts`

**Live check.**
```bash
curl -s -X POST https://app.one.ie/api/events \
  -H 'content-type: application/json' \
  -d '{
    "id": "'"$(node -e 'console.log(crypto.randomUUID())')"'",
    "ts": '"$(date +%s000)"',
    "slug": "one-demo",
    "agent_id": null,
    "event": "pageview",
    "source": "pixel",
    "visitor_hash": "",
    "consent_state": "unknown",
    "region": "",
    "payload": {"path": "/"}
  }'
# Expect: {"ok":true,"id":"..."}  HTTP 200
```

---

## 2. Pageview pixel — auto-fires on every page load

**What it does.** Inline `<script is:inline>` injected by `Layout.astro` into
every server-rendered page. Fires `POST /api/events` with `event: 'pageview'`
on `DOMContentLoaded`. Patches `history.pushState` to fire on SPA navigation.
Checks `navigator.globalPrivacyControl` for browser-level GPC consent.
Server enforces `Sec-GPC` header regardless of client value.

**Source.** `web/src/layouts/Layout.astro` (pixel `<script is:inline>` block)

**Live check.**
```bash
# Open any app.one.ie page in a browser — /api/events receives a pageview
# immediately. Check D1 agent_events_warm for slug='one-demo', event='pageview'.
curl -s https://app.one.ie/ -o /dev/null -w "%{http_code}"
# Expect: 200 (page loads; pixel fires client-side)
```

---

## 3. Web tracking pixel — `/p/one.js`

**What it does.** IIFE script tag. Reads `data-ws` + `data-agent` from the
script element. Sets `_one` UUID cookie (2-year, SameSite=Lax, Secure).
Fires `POST /api/events` for: pageview (pathname + referrer), click
(elements with `data-track` attribute), form submit, scroll-50%, page exit
(via `sendBeacon`).

**Usage.**
```html
<script async src="/p/one.js" data-ws="your-slug" data-agent="agent-id"></script>
```

**Source.** `web/public/p/one.js`

**Live check.**
```bash
curl -s -o /dev/null -w "%{http_code}" https://app.one.ie/p/one.js
# Expect: 200
```

---

## 4. Email open pixel — `GET /o/:token.gif`

**What it does.** Returns a 1×1 transparent GIF (no-cache). Looks up the
`tracked_links` row for `token` in D1. Writes `email-open` AgentEvent to
`agent_events_warm`. Broadcasts to workspace DO with tags
`["actor:<id>", "channel:email"]`. Respects `Sec-GPC: 1` header (→ `consent_state: 'denied'`).
Populates `region` from `CF-IPCountry`. Used as `<img src="/o/<link_id>.gif">`
in outbound emails.

**Source.** `web/src/pages/o/[token].gif.ts`

**Live check.**
```bash
curl -s -o /dev/null -w "%{http_code}" https://app.one.ie/o/nonexistent.gif
# Expect: 200 (always returns GIF — invalid token silently ignored)
curl -s -I https://app.one.ie/o/nonexistent.gif | grep -i content-type
# Expect: content-type: image/gif
```

---

## 5. ESP webhook — `POST /api/webhook/email`

**What it does.** Inbound webhook from email providers. Normalizes
SendGrid / Mailgun / Postmark event formats into `agent_events_warm`.
Maps ESP event types to ONE event names:

| ESP event | ONE event |
|-----------|-----------|
| bounce | `email-bounce` |
| delivered | `email-delivered` |
| open | `email-open` |
| click | `email-click` |
| spamreport | `email-spam` |
| unsubscribe | `email-unsubscribe` |

Auth: `?secret=<WEBHOOK_EMAIL_SECRET>`. ESP must include custom fields
`one_slug`, `one_campaign`, `one_actor` in outbound messages (SendGrid
`custom_args`, Mailgun `user-variables`, Postmark `Metadata`).

**Source.** `web/src/pages/api/webhook/email.ts`

**Webhook URL.**
```
https://app.one.ie/api/webhook/email?secret=<WEBHOOK_EMAIL_SECRET>
```
Secret stored in `.dev.vars`, `.env`, and Cloudflare Worker secrets.

---

## 6. Tracked redirect — `GET /go/:id`

**What it does.** D1 lookup by link id. Sets `_one` visitor cookie and
`_one_actor` cookie (for actor-bound links). Writes `click` AgentEvent.
Broadcasts to DO. Pre-warms DO actor snapshot. Adds `?oid=<visitor_hash>`,
`?aid=<actor_id>`, `?greet=<greeting>` to destination URL. 302 redirect.

**HMAC protection.** If `?sig=<16-char-hex>` is present, verifies
HMAC-SHA256(id, SERVER_SECRET) with constant-time compare. Returns 401 on
bad sig. Links without `?sig=` are allowed (grace period for legacy links).

**Source.** `web/src/pages/go/[id].ts` · `web/src/lib/link-hmac.ts`

**Live check.**
```bash
curl -s -o /dev/null -w "%{http_code}" https://app.one.ie/go/nonexistent
# Expect: 404
curl -s -o /dev/null -w "%{http_code}" "https://app.one.ie/go/someid?sig=badbadbadbadbad"
# Expect: 401 (bad signature rejected)
```

---

## 7. Link creation — `POST /api/links`

**What it does.** Creates an actor-bound tracked link. Computes HMAC sig
for the link id. Returns `{ id, sig, url }` where `url` already includes
`?sig=` so callers can send it directly.

**Source.** `web/src/pages/api/links.ts`

**Fields accepted.** `actorId` (required), `slug` (required), `destination`,
`context`, `greeting`, `expiresInDays`, `campaignId`, `createdBy`.

---

## 8. Channel ingest — claw → `/api/events`

**What it does.** Every inbound Telegram/Discord/web message processed by
the claw worker emits a `message:in` AgentEvent to `ONE_EVENTS_URL/api/events`
(fire-and-forget). Every outbound reply emits `message:out`. No-ops when
`ONE_EVENTS_URL` is unset.

**Source.** `claw/src/lib/emit-event.ts` · `claw/src/index.ts` (webhook handler)

**Config.** Set these secrets on the claw worker:
```bash
wrangler secret put ONE_EVENTS_URL   # e.g. https://app.one.ie
wrangler secret put WORKSPACE_SLUG  # e.g. one-demo
```

---

## 9. Identity — cookie, visitor hash, email/phone hash, merge

**What it does.**

| Rung | Name | Mechanism |
|------|------|-----------|
| 0 | cookie | `_one` UUID, 2-year, SameSite=Lax |
| 1 | visitor_hash | SHA-256(cookieId:salt), 32 hex chars, never logs raw id |
| 2 | email_hash | SHA-256(lower(trim(email))), matched in `same_as` |
| 3 | phone_hash | SHA-256(E.164 stripped), matched in `same_as` |
| 4 | auth_provider_sub | linked via auth session |
| 5 | custom_id | import / MCP binding |

Merge engine: confidence ≥ 0.95 → auto-merge; 0.6–0.95 → queue for review;
< 0.6 → dropped. Deterministic signals (same email hash) always confidence 1.

**Source.** `web/src/lib/identity.ts` · `web/src/lib/identity/ladder.ts`
· `web/src/lib/identity/merge.ts`

---

## 10. Analytics Relay — workspace Durable Object

**What it does.** One DO per workspace slug. Accepts events via `/broadcast`
(single) or `/accept` (batch). Maintains in-RAM:
- Rolling ring buffer of 10,000 most recent events
- Rollup counters by event type
- Pheromone world (tag-pair marks on consecutive tags in each event)
- Per-actor snapshot (last 20 events + persona tags)

Flushes WAL → D1 every 5 seconds via alarm. Writes KV snapshot every 60
seconds. Loads funnel baselines from D1 every 5 minutes. Failed flush
restores events to WAL front and retries next alarm. WebSocket `/connect`
endpoint for realtime watchers (<50ms fan-out). Auto-builds rescue responders
from `stage-start` events (C5). Pushes persona to `actor:` topic WebSocket
subscribers (C4).

**Source.** `web/src/workers/analytics-relay.ts`

---

## 11. Agent triggers — write path + evaluation

**What it does.**

*Write path (C2):* When an owner agent `.md` has a `triggers:` frontmatter
array, `chat.ts` fires the trigger list to the workspace DO `/triggers`
endpoint on every chat request (fire-and-forget). The DO persists the
registry to KV (`trg:<slug>`) with a 24hr TTL and loads it from KV on startup.

*Evaluation:* `evalTriggers(event, triggers, recent, state, now)` is a pure
stateful evaluator. Returns `AgentTriggerHit[]` matching on `surface`,
`min_visits`, `dwell_ms`, and per-actor cooldown (default 30 min).

**Source.** `web/src/lib/agent-triggers.ts` · `web/src/workers/analytics-relay.ts`
· `web/src/pages/api/chat.ts`

**Agent MD usage.**
```yaml
triggers:
  - surface: /pricing
    dwell_ms: 30000
    min_visits: 2
    cooldown_ms: 1800000
```

---

## 12. Attribution — first-touch / last-touch / linear

**What it does.** Takes a list of AgentEvents with a target goal event type
and a goal value. Groups by `visitor_hash`. For each visitor journey, assigns
credit to events before the goal using the chosen model.

**Source.** `web/src/lib/funnel/attribution.ts`

---

## 13. Analytics client — `trackEvent()`

**What it does.** Client-side fire-and-forget helper that sends a typed
AgentEvent to `/api/events`. No throw on failure. Generates a unique event id
per call. Leaves `visitor_hash` empty for server-side enrichment.

**Source.** `web/src/lib/analytics-client.ts`

---

## 14. KV rate limit — 100 events/hour per visitor

**What it does.** Before writing to D1, `POST /api/events` reads a KV key
`rate:evt:<visitor_hash>`. If count ≥ 100, returns HTTP 204 (silent — pixels
stop retrying on 2xx without revealing the limit). Counter TTL is 3600 seconds.

**Source.** `web/src/pages/api/events.ts` lines 62-71

---

## 15. Actor snapshot — chat-knows-you

**What it does.** Before streaming a chat reply, the chat handler calls
`fetchActorSnapshot(env, slug, actorId, 50)` to pull the visitor's recent
activity from the workspace DO. Returns `null` within 50ms if the DO is
unavailable. `formatSnapshotForPrompt(snap)` converts the snapshot to a
plain-English suffix (≤800 chars) injected as the 6th layer of the system
prompt: actorId in Title Case, last 10 events, first 3 persona tags, first
3 pheromone highways.

**Source.** `web/src/lib/actor-snapshot.ts`

---

## 16. Follow API — pheromone read endpoint

**What it does.** `GET /api/follow/[from]?slug=<workspace>` is a thin proxy
to the workspace DO `/follow` endpoint. Returns `{ from, to, strength }` with
`Cache-Control: public, max-age=5`.

**Source.** `web/src/pages/api/follow/[from].ts`

**Live check.**
```bash
curl -s "https://app.one.ie/api/follow/chat?slug=one-demo"
# Expect: {"from":"chat","to":"<strongest-next-node>","strength":<number>}  HTTP 200
```

---

## 17. Personalization — persona-driven hero variant

**What it does.** `pickHeroVariant(personaTags)` reads the visitor's persona
tags from the DO actor snapshot and returns one of four hero variants:
`default`, `founder`, `agency`, `developer`. Matches on `persona:` prefix
(case-insensitive). First match wins. `HERO_VARIANTS` holds the full
`{ eyebrow, headline, highlight, sub, cta }` shape for each variant.
The DO alarm pushes updated persona to `actor:` WebSocket subscribers (C4).

**Source.** `web/src/lib/personalize-map.ts`

---

## 18. Funnel rescue — p95 dwell baseline + stall detection

**What it does.** Three pure functions:

`quantile(values, q)` — sorts a copy, returns the value at position
`floor(q × (length-1))`. Returns 0 for empty input.

`computeBaselinesFromPairs(slug, pairs, now)` — groups `{ stage_id, dwell_ms }`
pairs by stage, skips stages with <3 samples, emits one `BaselineRow` per
stage with rounded p50/p95 dwell in ms.

`detectStalls(entries, baselines, responders, state, now, multiplier=3, cooldownMs=30min)` —
for each open `StageEntry`, checks if dwell > `baseline.p95 × multiplier`.
If so, and if the actor hasn't been rescued within `cooldownMs`, emits a
`RescueHit` and mutates `state.lastFired`.

Baselines are computed from `agent_events_warm` (fixed — previously read wrong
table `agent_events`). Cron refreshes baselines hourly across all slugs.
DO alarm loads baselines from D1 every 5 minutes.

**Source.** `web/src/lib/funnel-baseline.ts` · `web/src/workers/funnel-aggregate-cron.ts`

---

## 19. Event vocabulary — 36 canonical event names

**What it does.** Three typed const arrays covering every event ONE emits:

| Tier | Count | Examples |
|------|-------|---------|
| `STANDARD_EVENTS` | 16 | `stage-start`, `stage-complete`, `chip-click`, `journey-complete` |
| `CRO_EVENTS` | 11 | `rescue-trigger`, `agent-trigger`, `variant-assigned`, `personalisation-rule-applied` |
| `A2A_EVENTS` | 9 | `pheromone-mark`, `x402-receipt-verified`, `peer-call-issued` |

`isKnownEvent(name)` — type guard against ALL_EVENTS (36 total).
`isValidEventName(name)` — true for known events OR `custom:<suffix>`.

**Source.** `web/src/lib/event-vocabulary.ts`

---

## 20. Funnel resolution engine

**What it does.** Pure functions that evaluate events against an agent's
funnel configuration:

`resolveStages`, `resolveGoal`, `conversionRate`, `stageDropOff`,
`signalFunnelEvent` — see feature 18 above for full descriptions.

**Source.** `web/src/lib/funnel.ts`

---

## Unit test suite

Run all 500 tests:

```bash
cd one-ie/one/web
bun run verify
```

### Results (2026-05-18)

```
Test Files  61 passed | 2 skipped (63)
     Tests  500 passed | 3 skipped (503)
  Duration  ~5s
```

### Tracking-specific test files

| File | Tests | What's covered |
|------|-------|----------------|
| `identity.test.ts` | 31 | `readCookieId`, `visitorHash`, `climbLadder`, cookie headers |
| `funnel.test.ts` | 33 | `resolveStages`, `resolveGoal`, `conversionRate` (null on zero), `stageDropOff` |
| `pheromone.test.ts` | 29 | `mark/sense`, `warn`, `follow`, `select`, `highways`, `fade`, serialize/restore |
| `analytics-relay.test.ts` | 28 | `/broadcast`, `/accept`, `/rollups`, `/recent`, `/snapshot`, WAL flush |
| `funnel-baseline.test.ts` | 26 | `quantile`, `computeBaselinesFromPairs`, `detectStalls`, `createRescueState` |
| `funnel-aggregate-cron.test.ts` | 14 | `computeBaselines` (DB path), `upsertBaselines`, cron C5 round-trip |
| `event-vocabulary.test.ts` | 20 | Set sizes, `isKnownEvent`, `isValidEventName`, custom: prefix |
| `merge.test.ts` | 19 | `disposeMerge`, `scoreCandidate`, `mergeReceiver`, `splitReceiver` |
| `ladder.test.ts` | 17 | `sha256`, `emailHash`, `phoneHash`, `RUNG_NAME` |
| `agent-triggers.test.ts` | 16 | `evalTriggers` — surface, visits, dwell, cooldown, multi-agent |
| `actor-snapshot.test.ts` | 15 | `formatSnapshotForPrompt` — kebab→Title Case, last-10, caps, truncation |
| `link-hmac.test.ts` | 13 | `signLinkId`, `verifyLinkId` — deterministic, tamper rejection, round-trip |
| `personalize-map.test.ts` | 12 | `HERO_VARIANTS` shape, `pickHeroVariant` — all variants, case-insensitive |
| `personalized-hero.test.tsx` | 7 | `<Hero variant=...>`, `<PersonalizedHero>` SSR shell, EventSource stub |
| `attribution.test.ts` | 10 | `attributeJourney` (first/last/linear), `attributeEvents` |
| `analytics-client.test.ts` | 8 | POST shape, required fields, no-throw, unique ids |

---

## What is NOT tested by unit tests (integration only)

| Feature | Code path | Gap |
|---------|-----------|-----|
| Email open pixel handler | `web/src/pages/o/[token].gif.ts` | D1 + DO — integration only |
| ESP webhook ingest | `web/src/pages/api/webhook/email.ts` | Route handler — integration only |
| Channel emit from claw | `claw/src/lib/emit-event.ts` | No vitest in claw package |
| HMAC rate-limit (KV 100/hr) | `events.ts` lines 62-71 | Route handler — integration only |
| `/go/:id` redirect + cookie set | `go/[id].ts` | Route handler — integration only |
| `fetchActorSnapshot` DO call | `actor-snapshot.ts` | Needs real DO stub — integration only |
| WAL→D1 schema | SQL in `analytics-relay.ts` | Direct D1 execute |

---

## Production deployment (2026-05-18)

```
Worker:   one-demo → app.one.ie
Version:  2c63ea23-e3ad-4e5b-b9d1-3d6832de8a96
Tests:    500/500 pass
Build:    15.8s
Deploy:   13.3s
```

**Live checks:**
```bash
# Health
curl -s https://app.one.ie/api/health
# {"status":"ok","agent":"one-demo","model":"meta-llama/llama-4-maverick","hasOpenRouter":true}

# Event ingest
curl -s -X POST https://app.one.ie/api/events \
  -H 'content-type: application/json' \
  -d '{"id":"smoke-'$(date +%s)'","ts":'$(date +%s000)',"slug":"one-demo","agent_id":null,"event":"pageview","source":"pixel","visitor_hash":"","consent_state":"unknown","region":"","payload":{"path":"/test"}}'
# {"ok":true,"id":"smoke-..."}  HTTP 200

# GPC enforcement
curl -s -X POST https://app.one.ie/api/events \
  -H 'content-type: application/json' -H 'Sec-GPC: 1' \
  -d '{"id":"gpc-test","ts":'$(date +%s000)',"slug":"one-demo","agent_id":null,"event":"pageview","source":"pixel","visitor_hash":"","consent_state":"granted","region":"","payload":{}}'
# {"ok":true} — event written with consent_state='denied' regardless of body value

# Email open pixel
curl -s -o /dev/null -w "%{http_code}" https://app.one.ie/o/test.gif
# 200

# HMAC rejection
curl -s -o /dev/null -w "%{http_code}" "https://app.one.ie/go/test?sig=0000000000000000"
# 401

# Follow API
curl -s "https://app.one.ie/api/follow/chat?slug=one-demo"
# {"from":"chat","to":"...","strength":...}  HTTP 200
```

---

## What still needs building (not claimed as shipped)

| Gap | Impact |
|-----|--------|
| Cross-channel trace UI | Events in D1 but no UI to reconstruct Sara's WhatsApp→Discord→web→payment thread |
| Identity resolution rate KPI | No metric emitted; no alarm when resolution rate drops below 95% |
| Ad-platform CAPI fan-out (Meta / Google / TikTok) | No outbound CAPI — events stay local to D1 |
| Per-workspace cost cap | `RATE_PROVISION` is IP-based only; no per-workspace event budget |
| L6 KNOWLEDGE promotion to TypeDB | Pheromone marks accumulate but no hardening loop |
