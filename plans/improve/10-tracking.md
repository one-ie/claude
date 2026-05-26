# 10-tracking — gap analysis

Marketing surface: `text/10-tracking.md` (titled "One inbox. Every channel.")
Spec: `web/tracking.md` (Parts I-III, 1568 lines), `web/tracking-realtime.md`,
`web/send-link.md`. Implementation lives in `web/src/`.

## Promise

From `text/10-tracking.md` and the cross-referenced specs:

- **One record per customer across every channel.** WhatsApp, Discord,
  Telegram, iMessage, web chat, email, API, MCP all land in the same
  thread, attributed to the same Sara.
- **5-rung identity ladder, >95% resolution rate, auto-stitched** via
  hashes (device → email → phone → account → linked external IDs) with
  `same-as` rows + auditable provenance.
- **Every claim is drillable to the conversation that earned it** —
  revenue, loss, campaign, voice, response time, drop-off all link
  back to threads.
- **Privacy: collect deeply, hold lightly, KMS-shred on a click.**
  Vault-segregated raw PII, audited reveals, 30-day delete cascade
  with per-tier receipt.
- **Tracking IS the substrate.** Every event marks tag-pair pheromone;
  L6 KNOWLEDGE promotes highways to hypotheses; the inbox routes the
  next message to the team that closed the last one.
- **Realtime watchers** see the live feed at <50ms via hibernating
  WebSockets on workspace DOs.
- **One pixel tag** (`<script src="https://one.ie/p/one.js">`) wires
  pageview/click/submit/scroll/idle/exit + SPA + link-rewrite + GPC/TCF
  consent + same-day adapter for any new channel.

## Code reality

What ships today (commit `05ca5164`, baseline + tuning waves T1):

| Surface | File | State |
|---|---|---|
| Event schema (locked AgentEvent) | `web/src/lib/tracking-types.ts` | shipped |
| Ingest `POST /api/events` | `web/src/pages/api/events.ts` | shipped, idempotent ULID, broadcasts to DO |
| Tracked redirect `/go/:id` | `web/src/pages/go/[id].ts` | shipped — HMAC missing, cookie + visitor_hash + `aid`/`greet` query + pre-warm snapshot |
| Link CRUD `POST /api/links` | `web/src/pages/api/links.ts` | shipped — actor-bound, expiry, greeting, no auth |
| Link UI | `web/src/components/crm/SendLinkSheet.tsx` | shipped (CRM contact panel) |
| Workspace DO | `web/src/workers/analytics-relay.ts` | shipped — rollups, WAL→D1 (5s), KV snap (60s), hibernating WS, tag-pair pheromone, agent triggers, funnel rescue |
| Identity rung 0/1 (cookie + visitor hash) | `web/src/lib/identity.ts` | shipped |
| Identity rung 2/3 (email/phone hash + merge) | `web/src/lib/identity/{ladder,merge}.ts` + `/api/identity/merge.ts` | shipped, wired into `/api/events` |
| Delete (`/api/forget/[id]`) + audit | `web/src/pages/api/forget/[id].ts`, migrations 0040/0041/0046 | shipped (vault + audit + group scope) |
| Reveal (`/api/pii/reveal`) | exists | shipped |
| Realtime watch hook | `web/src/lib/use-watch.ts`, `/api/analytics/watch.ts` (SSE) | shipped |
| Attribution (first/last/linear) | `web/src/lib/funnel/attribution.ts` | shipped, in-process; no holdout/lift |
| Funnel rollups | migrations 0024/0025/0026/0047 + `funnel-baseline.ts` + cron | shipped |
| Tracked-link → chat actor stitch | `chat.ts` reads `_one_link` cookie, `index.astro` skips redirect when `?aid` or `?greet`, `actor-snapshot.ts` calls DO `/snapshot` | shipped |
| Tag-pair pheromone (`tags[i]→tags[i+1]`) + tag-pair mark | `analytics-relay.ts` accept() | shipped |
| Web pixel `one.js` | **nothing in `web/public/`** | **MISSING** |
| Email open pixel `/o/:token.gif` | **no route** | **MISSING** |
| Long-form forward `/r?u=…&c=…&e=…` | **no route** | **MISSING** |
| ESP webhook ingest (Postmark/Resend/SES) | **none** | **MISSING** |
| Ad-platform CAPI fan-out (Meta/Google/TikTok) | **none** | **MISSING** |
| Channel adapter ingest (Telegram/Discord/SMS → AgentEvent) | **none in `web/`** (lives in `claw/` as chat ingress only — no AgentEvent emission to `/api/events`) | **MISSING** |
| Consent gate (TCF v2 / GPC) on ingest | **none** | **MISSING** |
| Suppression table check on outbound | **none** | **MISSING** |
| HMAC signature on `/go/:id` | **plaintext id lookup** | **MISSING** |
| Per-session rate limit (§17.1) | **none** | **MISSING** |
| Workspace token verification on `/api/events` | **no `x-ws`/`x-sig`** | **MISSING** |
| Browser-side batching (L1) | `analytics-client.ts` is one `fetch` per event | **MISSING** |
| Analytics Engine firehose | **no AE binding** | **MISSING** |
| R2 parquet cold tier | **no R2 writer** | **MISSING** |
| Sharding coordinator DO | one DO per slug, no fan-in | **MISSING** |
| Importer agents (Clearbit/Apollo/Stripe/Shopify/etc.) | **none** | **MISSING** |
| Reveal audit emission (`pii.read` event) | reveal route exists; emission not verified | partial |
| Tier-aware fan-out (free=SSE poll, paid=WS) | SSE bridge only | partial |
| Identity-resolution-rate KPI + warn | **no metric, no agent warn** | **MISSING** |
| L6 KNOWLEDGE promotion to TypeDB hypotheses | pheromone marks but no hardening loop in web/ | **MISSING** |

## Gaps

Ranked by distance from the promise:

1. **No web pixel.** `text/10-tracking.md` and `web/tracking.md` §2.1/§24
   describe a `<script async src="/p/one.js">` tag that's the entire
   acquisition story for clients that aren't building on the SDK.
   Without it, the only browser events that reach `/api/events` are the
   ones a developer hand-instruments. The "one tag, all features" promise
   does not exist as code. This blocks the whole "agency stitches a new
   client's site in 60s" pitch.

2. **No email tracking.** The promise headline is "every channel" with
   email pictured top of the channel table; reality is no open pixel
   (`/o/:token.gif`), no ESP webhook (`source:'webhook' channel:'email'`),
   no link rewrite at send. The only email path that lands events is a
   user clicking a `/go/:id` link that some other system already wrote.
   Bounce/complaint/unsub aren't tracked.

3. **No channel-adapter ingest.** WhatsApp/Telegram/Discord/iMessage are
   shipped as **chat ingress to `claw`** but `claw` does not emit
   `AgentEvent` rows to `/api/events`. There is no `source:'channel'`
   stream in `agent_events_warm`. The "same Sara on WhatsApp, Discord,
   web, paid in 47s" trace is not reconstructible from the event store
   today.

4. **`/go/:id` is unsigned.** No HMAC verify (spec §2.2 step 1), no
   expiry check beyond `expires_at` DB column, no integrity protection
   on `link_id`. Anyone who guesses a 16-char id can fabricate clicks.

5. **No consent / suppression gate.** §8.1's three gates are spec-only.
   `/api/events` accepts whatever `consent_state` string the client
   sends; outbound suppression is not checked. GDPR-compliant launch in
   EU/UK requires this.

6. **No verified ingest auth.** `/api/events` accepts any POST. The
   `x-ws` workspace + `x-sig` HMAC from §24 isn't enforced. Combined
   with §17.1 (per-session rate limit) being absent, the ingest is
   trivially DoSable and trivially attributable to the wrong workspace.

7. **No CAPI / Conversions API fan-out.** §2.8 — purchase event fires
   locally but nothing pushes to Meta CAPI / Google EC / TikTok Events.
   Closes the iOS-ATT attribution loop in the spec; missing in code.

8. **No identity-resolution-rate KPI.** §1 promises ">95%, with warn
   below threshold." There is no metric collected, no agent watching,
   no surface displaying it.

9. **No browser batching / Cache-API pixel / Smart-Placement / WS upgrade.**
   T2/T4/T6 tuning waves are unimplemented. `analytics-client.ts` is
   one `fetch` per call. The "$0.30/M @ 40ms p99" Tuned Target is
   spec-only.

10. **No Analytics Engine / R2 cold tier / sharding.** Storage tier table
    (§16) shows AE + R2 parquet + sharded DOs; only the warm tier
    (D1) and DO RAM exist. Backfill/rebuild (§19) and >1M-events-per-day
    workspaces (§13) cannot run.

11. **Append/import is unimplemented.** §4 promised
    `import-clearbit/apollo/stripe/shopify/zendesk/segment`; none exist
    in `web/src/`.

12. **Reveal-audit + read-mode separation under-specified in code.**
    `pii/reveal` route exists but the spec's `pii.read` event emission,
    rate limit (100/hour/admin), and customer-key-presented audit
    column aren't verifiable from the codebase.

## Recommended improvements

In execution order (each row is a lean cycle in the §0 classifier
sense — spec is locked, files are known, exit scalar is a single
verifiable count or check).

| # | Cycle | Exit scalar |
|---|---|---|
| 1 | Add HMAC signing + verify to `/go/:id` (sign `id|exp` with `SERVER_SECRET`; reject tampered) | `/go/<tampered>` returns 401, `/go/<valid>` continues to 302; vitest covers both |
| 2 | Ship `one.js` (≤4KB) at `web/public/p/one.js` + `/api/events` workspace verification (`x-ws` + `x-sig` HMAC) | pixel emits `pageview`/`click`/`submit`/`scroll`/`exit`; lighthouse a11y unchanged; events land in D1 with correct `visitor_hash` |
| 3 | Email open pixel `/o/[token].gif` + link rewrite helper in send pipeline | one open + one click row in `agent_events_warm` per test send |
| 4 | ESP webhook ingest `/api/in/email/[provider]` for bounce/complaint/unsub (Postmark first) | webhook → AgentEvent with `source:'webhook'` `channel:'email'` |
| 5 | Channel adapter event emission: extend `claw` to POST `AgentEvent` to `/api/events` on inbound/outbound for telegram, discord, web chat | one row per message, both directions, `source:'channel'` |
| 6 | Consent gate on `/api/events`: enforce `consent_state ∈ {granted, implied-where-legal}` → full payload; else strip `payload` to allowlist | row stored either way; degraded mode visible in `dropped.event` counter |
| 7 | Per-session rate limit (§17.1) — KV `rate:session:<id>` TTL 3600, 100/hour, silent 204 over cap | vitest: 101st event in same hour returns 204 with no D1 write |
| 8 | Identity-resolution-rate KPI: nightly cron computes `actors_with_actor_id / actors_total` per workspace, writes to `kpi_rollups`, agent warns < 0.95 | dashboard tile shows percentage; warn signal visible in DO |
| 9 | Browser batching (L1) in `analytics-client.ts` — buffer 20 events / 250ms, `sendBeacon`, critical bypass | network panel shows ≤1 request per 250ms under burst |
| 10 | CAPI fan-out: on `purchase` event, queue → Meta CAPI + Google EC. Emit `attribution.sent` child event | one purchase produces N+1 rows (1 local, N platform); platform 2xx in CI mock |
| 11 | Analytics Engine binding + dual-write from `accept()` | AE write count == accepted event count over 1k sample |
| 12 | R2 parquet writer + hourly compaction cron | day's parquet readable; replay-from-R2 job stub returns same rollup as D1 |
| 13 | Importer scaffolding (`import-stripe` first, since Stripe is already wired for payments) | on `actor.lifecycle.changed:customer`, `appended.stripe.*` namespace populated |
| 14 | Workspace sharding (256-way by `visitor_hash[0..1]`) + coordinator DO for global rollups | DO RAM stays below 256 MB at 1k EPS in load test |

## Files to touch

Hot path (cycles 1-7 above):

- `/Users/toc/Server/one-ie/one/web/src/pages/go/[id].ts` — HMAC verify
- `/Users/toc/Server/one-ie/one/web/src/pages/api/links.ts` — emit HMAC-signed id
- `/Users/toc/Server/one-ie/one/web/src/lib/link-hmac.ts` — **new** (sign/verify helper)
- `/Users/toc/Server/one-ie/one/web/public/p/one.js` — **new** (≤4KB pixel)
- `/Users/toc/Server/one-ie/one/web/src/pages/p/one.js.ts` — **new** alternative if served dynamically with Cache API
- `/Users/toc/Server/one-ie/one/web/src/pages/o/[token].gif.ts` — **new** (email open)
- `/Users/toc/Server/one-ie/one/web/src/pages/r.ts` — **new** (long forward)
- `/Users/toc/Server/one-ie/one/web/src/pages/api/events.ts` — workspace HMAC verify, consent gate, rate limit
- `/Users/toc/Server/one-ie/one/web/src/pages/api/in/email/[provider].ts` — **new** ESP webhook
- `/Users/toc/Server/one-ie/one/web/src/lib/analytics-client.ts` — buffer + sendBeacon + critical bypass
- `/Users/toc/Server/one-ie/one/web/src/lib/identity.ts` — add `setCookieHeader` HMAC option
- `/Users/toc/Server/one-ie/one/web/migrations/0032_tracked_links.sql` — add `hmac_version` column for rotation
- `/Users/toc/Server/one-ie/one/web/migrations/00NN_workspace_tokens.sql` — **new**
- `/Users/toc/Server/one-ie/one/web/migrations/00NN_suppression.sql` — **new**

Channel ingest (cycle 5):

- `/Users/toc/Server/one-ie/one/claw/src/**` — emit `AgentEvent` POST on every inbound/outbound (telegram, discord, web chat adapters). Reuses existing thread/agent ids.
- `/Users/toc/Server/one-ie/one/web/src/pages/api/events.ts` — accept `source:'channel'` from authenticated claw

KPI / attribution / append (cycles 8, 10, 13):

- `/Users/toc/Server/one-ie/one/web/src/workers/identity-resolution-cron.ts` — **new**
- `/Users/toc/Server/one-ie/one/web/src/lib/capi/{meta,google,tiktok}.ts` — **new**
- `/Users/toc/Server/one-ie/one/web/src/workers/capi-fanout.ts` — **new** queue consumer
- `/Users/toc/Server/one-ie/one/web/src/lib/import/stripe.ts` — **new** (Stripe already wired for payments)

Cold tier / sharding (cycles 11, 12, 14):

- `/Users/toc/Server/one-ie/one/web/wrangler.toml` — add `analytics_engine_datasets`, `r2_buckets`, sharded DO namespace
- `/Users/toc/Server/one-ie/one/web/src/workers/analytics-relay.ts` — add AE write + R2 flush + shard split path
- `/Users/toc/Server/one-ie/one/web/src/workers/ws-coordinator.ts` — **new**

Spec reconciliation:

- `/Users/toc/Server/one-ie/one/web/tracking.md` §25 — update Wave status: C1-C6 ✅, W6-W16 still deferred; add T1-T6 status row
- `/Users/toc/Server/one-ie/one/text/10-tracking.md` — once W6 lands, update the channel table footnote to remove email's implied-via-`/go/:id`-only caveat
