---
title: Tracking pipeline — one pipeline, all interactions
slug: tracking
type: plan
tier: complex
mode: construction
tags: [tracking, analytics, ingest, durable-object, identity, typedb, realtime]
source_of_truth:
  - web/tracking.md
  - web/tracking-realtime.md
  - web/src/workers/analytics-relay.ts
  - web/src/lib/analytics-client.ts
  - web/src/pages/api/analytics/stream.ts
show: false
escape:
  condition: "C2 W4 delta_tsc > 0 twice"
  action: "halt; re-scope C2 — check WorkspaceDO TypeScript compatibility before retrying"
context_triggers:
  - pattern: "AgentEvent|agent_events|ingest"
    inject: "web/tracking.md § 0. The contract"
  - pattern: "WorkspaceDO|durable.object|DurableObject"
    inject: "web/tracking.md § 12. Workspace Durable Objects"
  - pattern: "identity.ladder|visitor_hash|actor_id"
    inject: "web/tracking.md § 1. The identity ladder"
  - pattern: "snapshotForActor|useWatch|realtime"
    inject: "web/tracking-realtime.md § Tier 1"
---

# Tracking pipeline

**Goal:** Ship the full tracking pipeline — typed `AgentEvent` ingest, Workspace Durable Object with in-RAM rollups and hibernating WebSocket fan-out, identity ladder, and the six substrate primitives that power the 25 realtime use cases in `tracking-realtime.md`.

**Exit:** `POST /api/events` returns 200, DO stores rollup, `GET /api/analytics/stream?slug=x&agentId=y` delivers events over SSE, `bun run verify` passes.

---

## Dependency graph

### Cycle-level

```
C1:schema ──→ C2:workspace-do
C1:schema ──→ C3:identity
                C2:workspace-do ──→ C4:typedb-brain
                C2:workspace-do ──→ C5:durability
                              C4:typedb-brain ──→ C6:realtime
```

`C1 → C2` because `WorkspaceDO.accept(events)` types depend on the `AgentEvent` interface C1 defines in `src/lib/tracking-types.ts`.
`C1 → C3` because identity enrichment writes `visitor_hash` / `actor_id` onto `AgentEvent` rows.
`C2 → C4` because TypeDB-in-RAM lives inside the DO and C4 adds the in-RAM TypeDB shard to it.
`C2 → C5` because the WAL flush loop is part of the DO.
`C4 → C6` because `snapshotForActor()` reads the in-RAM TypeDB populated by C4.

C3 runs in parallel with C2. C5 runs in parallel with C4.

### W3 agent parallelism map (per cycle)

```
C1 W3a — parallel:
  agent-1  → src/lib/tracking-types.ts        # new AgentEvent interface + verb taxonomy
  agent-2  → src/pages/api/events.ts           # new ingest endpoint (replaces /api/agent-events)
  agent-3  → migrations/0031_agent_events_warm.sql  # D1 schema: agent_events_warm
  agent-4  → web/tracking.md § 0              # verify shape matches spec (doc touch)

C1 W3b — sequential (after W3a, edits events.ts):
  agent-5  → src/lib/analytics-client.ts      # update trackEvent() to use /api/events + AgentEvent shape

C2 W3a — parallel:
  agent-1  → src/workers/analytics-relay.ts   # rewrite → WorkspaceDO (rollups, WS fan-out, WAL stub)
  agent-2  → wrangler.toml                    # bind new DO class, keep AnalyticsRelay export alias

C3 W3a — parallel:
  agent-1  → src/lib/identity.ts              # new: cookie_id, visitor_hash, identity-ladder helpers
  agent-2  → src/pages/go/[id].ts             # new: /go/:id tracked redirect Worker
  agent-3  → migrations/0032_tracked_links.sql # D1: tracked_links table + test fixture

C4 W3a — parallel:
  agent-1  → src/workers/analytics-relay.ts   # add in-RAM TypeDB shard + topic computation
  agent-2  → src/lib/pheromone.ts             # vendored in-RAM world (mark/warn/sense/follow/select/highways)

C5 W3a — parallel (all touch different files):
  agent-1  → src/workers/analytics-relay.ts   # add WAL flush → D1 (5s), KV snapshot (60s) loops
  agent-2  → migrations/0033_rollup_counters.sql # D1: rollup_counters table for hourly aggregates

C6 W3a — parallel:
  agent-1  → src/workers/analytics-relay.ts   # add snapshotForActor() RPC method
  agent-2  → src/lib/use-watch.ts             # new: useWatch() React hook (SSE fallback)
  agent-3  → src/pages/api/analytics/watch.ts # new: SSE /api/analytics/watch endpoint
```

---

## Status

- [x] C1 — AgentEvent schema + ingest endpoint
  - [x] W0 baseline
  - [x] W1 recon
  - [x] W2 decide
  - [x] W3 edit
  - [x] W4 verify
- [x] C2 — Workspace Durable Object (rollups + WS fan-out)
  - [x] W0 baseline
  - [x] W1 recon
  - [x] W2 decide
  - [x] W3 edit
  - [x] W4 verify
- [x] C3 — Identity ladder + tracked redirect
  - [x] W0 baseline
  - [x] W1 recon
  - [x] W2 decide
  - [x] W3 edit
  - [x] W4 verify
- [x] C4 — TypeDB-in-RAM brain inside DO
  - [x] W0 baseline
  - [x] W1 recon
  - [x] W2 decide
  - [x] W3 edit
  - [x] W4 verify
- [x] C5 — Durability: WAL → D1, KV snapshot
  - [x] W0 baseline
  - [x] W1 recon
  - [x] W2 decide
  - [x] W3 edit
  - [x] W4 verify
- [x] C6 — Realtime surfaces: snapshotForActor + useWatch
  - [x] W0 baseline
  - [x] W1 recon
  - [x] W2 decide
  - [x] W3 edit
  - [x] W4 verify

---

## C1 — AgentEvent schema + ingest endpoint  [tier: simple]

**Exit:** `POST /api/events` with a valid `AgentEvent` body returns `{ok:true,id}`. `bun run verify` green. `agent_events_warm` D1 migration applies without error.

### W1 — Recon  [Haiku · parallel]

- `web/src/lib/analytics-client.ts` — current `trackEvent()` shape; which fields are missing vs `tracking.md §0`
- `web/src/pages/api/analytics/stream.ts` — current streaming handler; whether it reads `agent_events` or `agent_events_warm`
- `web/tracking.md` — §0 AgentEvent interface (all required fields) + §3 verb taxonomy
- `web/src/workers/analytics-relay.ts` — current DO: does it accept raw events or just broadcast?

### W2 — Decide  [Sonnet]

- Where does `AgentEvent` interface live — `src/lib/tracking-types.ts` (new) or extend `src/lib/types.ts`?
- Which fields are required vs optional on the ingest endpoint (minimal viable set for C1)?
- Does D1 `agent_events_warm` replace the existing `agent_events` table or coexist?
- Is HMAC verify needed in C1 or deferred to C3 (identity) when the signed-cookie shape is clearer?

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (spawned in one message):**
- [ ] `web/src/lib/tracking-types.ts` — new file: full `AgentEvent` interface from `tracking.md §0`, verb union type, source union type, consent_state type
- [ ] `web/src/pages/api/events.ts` — new ingest endpoint: validate body, write to D1 `agent_events_warm`, call `broadcast` on WorkspaceDO stub
- [ ] `web/migrations/0031_agent_events_warm.sql` — create `agent_events_warm` table (all `AgentEvent` columns + created_at index on ts + visitor_hash index)

**W3b — dependent (after W3a, analytics-client imports from tracking-types):**
- [ ] `web/src/lib/analytics-client.ts` — update `trackEvent()` to POST to `/api/events` and include the new required fields (visitor_hash stub = `''` until C3 wires identity, source: 'web')

### W4 — Verify  [inline composite]

- [ ] `bun run verify` green (biome + tsc + vitest)
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `curl -X POST /api/events -d '{"id":"01HX...","ts":...,"slug":"test","event":"pageview","source":"web","visitor_hash":"","consent_state":"unknown","region":"IE","payload":{}}' -H 'content-type: application/json'` returns `{"ok":true,"id":"01HX..."}`
- [ ] Rubric composite ≥ 0.65

Targets: security ≥ 0.90 (no PII leak in response) · stability ≥ 0.85 · simplicity ≥ 0.85 · speed ≥ 0.80

Report: `delta_tsc=±N  delta_loc=±N  compress_orphans=N`

---

## C2 — Workspace Durable Object (rollups + WS fan-out)  [tier: complex]

**Exit:** A WebSocket client subscribing to `ws://.../api/analytics/connect?slug=x&agentId=y` receives events within 100ms of `POST /api/events` for the same `{slug, agentId}`. `bun run verify` green.

### W1 — Recon  [Haiku · parallel]

- `web/src/workers/analytics-relay.ts` — current DO structure; hibernation support, broadcast implementation
- `web/tracking.md` — §12 WorkspaceDO contract: `accept()`, rollups, `recent` ring buffer, WAL stub, WebSocket fan-out
- `web/tracking.md` — §14 hibernating WebSocket + coalescing (50ms tick)
- `web/wrangler.toml` — current DO binding name + class export

### W2 — Decide  [Opus]

- Rewrite `AnalyticsRelay` in-place (keep class name for Wrangler compat) or rename to `WorkspaceDO` and update bindings?
- Does C2 include the WAL + flush loop or defer to C5? (C2 should stub WAL as in-memory only; C5 adds flush)
- Topic computation at write time: derive from `{slug}:{agentId}` or from `AgentEvent` fields directly? How does fan-out match topics to subscribers?
- Coalescing: 50ms timer per topic or single global timer per DO tick?

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/workers/analytics-relay.ts` — rewrite: add `accept(events: AgentEvent[])` RPC, in-RAM `rollups` Map, `recent` RingBuffer(10k), `watchers` topic map, hibernating WS fan-out with 50ms coalesce timer, WAL stub (array, not yet flushed)
- [ ] `web/wrangler.toml` — update DO class export if renamed; ensure `WS_DO` binding exists

**W3b — sequential:**
*(empty — all edits independent)*

### W4 — Verify  [Haiku×5]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] WebSocket roundtrip test: POST event → DO fan-out → subscriber receives within 150ms (playwright or vitest ws client)
- [ ] Rollup counter increments on each accepted event (unit test on DO in-memory state)
- [ ] Rubric composite ≥ 0.65

Targets: security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.80 · speed ≥ 0.85

Report: `delta_tsc=±N  delta_loc=±N  compress_orphans=N`

---

## C3 — Identity ladder + tracked redirect  [tier: simple]

**Exit:** A request to `GET /go/test-link-id` (HMAC-verified test fixture) sets `_one` cookie, writes a `click` event to D1, and redirects to the destination. `bun run verify` green.

### W1 — Recon  [Haiku · parallel]

- `web/tracking.md` — §1 identity ladder (5 rungs), §2.2 `/go/:id` Worker hot path, §5 identity stitching
- `web/src/lib/analytics-client.ts` — current cookie handling (does any cookie logic exist?)
- `web/src/pages/api/events.ts` — (after C1) ingest endpoint: where does visitor_hash currently come from?

### W2 — Decide  [Sonnet]

- Where does `cookie_id` get set — middleware, the `/api/events` handler, or a dedicated `/p/init` endpoint?
- `visitor_hash = sha256(cookie + ws_salt)` — where is `ws_salt` stored? KV per-workspace or env var for now?
- Does C3 need the full 5-rung ladder or just rungs 0-1 (device → visitor)?
- `/go/:id` — store link metadata in D1 or KV? Short link generation API or manually seeded fixtures?

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/lib/identity.ts` — new: `cookieId()` (read/set `_one` uuid v7 cookie), `visitorHash(cookieId, salt)` (sha256), `climbLadder(event, cookies)` → populates `visitor_hash` + `actor_id` on AgentEvent
- [ ] `web/src/pages/go/[id].ts` — new: `/go/:id` Worker: HMAC verify → resolve link from D1 → set `_one` cookie → write click event → 302 to destination

**W3b — sequential (after W3a, events.ts imports climbLadder):**
- [ ] `web/src/pages/api/events.ts` — wire `climbLadder()` into ingest: read `_one` cookie from request headers, enrich incoming event before D1 write

### W4 — Verify  [inline composite]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `GET /go/<test-fixture-id>` returns 302, sets `_one` cookie, event row in D1 has `visitor_hash` populated
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  compress_orphans=N`

---

## C4 — TypeDB-in-RAM brain inside DO  [tier: complex]

**Exit:** After `POST /api/events` with tag-bearing events, `world.highways({ prefix: 'channel:' })` called on the DO returns edges with non-zero strength. `bun run verify` green.

### W1 — Recon  [Haiku · parallel]

- `web/src/workers/analytics-relay.ts` — (after C2) current DO structure; where TypeDB shard would slot in
- `web/tracking.md` — §9.1 tags become paths: consecutive tag pairs → pheromone deposit
- `web/tracking-realtime.md` — six primitives: mark/warn/sense/follow/select/highways + snapshotForActor
- `one-ie/one/web/src/lib/pheromone.ts` — does any existing world primitive file exist? (shipped as `pheromone.ts`, not `substrate.ts`)

### W2 — Decide  [Opus]

- TypeDB-in-RAM implementation: import `world()` from `@oneie/sdk` or vendor the substrate primitives into the DO bundle? (DO bundle size constraint ~1MB compressed)
- Tag order enforcement: where does canonical tag ordering happen — at ingest (C1) or in the DO at write time?
- Topic computation at DO write time: derive from tag pairs or from `{slug}:{agentId}` tuples?
- `snapshotForActor()` RPC shape: what fields does it return for C6 chat hydration? (identity-ladder rung, recent events, campaign, persona tags, lifecycle, LTV hint)

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/workers/analytics-relay.ts` — add `typedb: InMemoryWorld` field (using `world()` from substrate or vendored); wire `typedb.mark(edge)` on each tag-pair in accepted events; expose `highways()`, `follow()`, `select()`, `sense()` as typed RPC methods
- [ ] `web/src/lib/pheromone.ts` — vendored in-RAM world exposing `mark`, `warn`, `follow`, `select`, `highways`, `sense`; called by DO and SSR pages

**W3b:**
*(empty)*

### W4 — Verify  [Haiku×5]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Integration test: POST event with `tags: ['channel:telegram', 'campaign:apr-q2']` → DO `highways({ prefix: 'channel:' })` returns edge `channel:telegram → campaign:apr-q2` with strength > 0
- [ ] Bundle size check: DO worker bundle ≤ 1 MB compressed (wrangler build output)
- [ ] Rubric composite ≥ 0.65

Targets: security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.80 · speed ≥ 0.85

Report: `delta_tsc=±N  delta_loc=±N  compress_orphans=N`

---

## C5 — Durability: WAL → D1, KV snapshot  [tier: simple]

**Exit:** After the DO WAL reaches 1000 events OR 5s elapses, events appear in D1 `agent_events_warm` and a KV key `typedb_snap/{ws}/{ts}` is written. `bun run verify` green.

### W1 — Recon  [Haiku · parallel]

- `web/src/workers/analytics-relay.ts` — (after C2) WAL stub: what's the current array structure?
- `web/tracking.md` — §11 flush loop timings (5s D1, 60s KV, 10m R2), §16 storage tiers
- `web/wrangler.toml` — current D1 binding name (`DB`?), KV binding name

### W2 — Decide  [Sonnet]

- D1 flush: batch insert (one statement per 1k rows) or individual inserts?
- KV snapshot: JSON-serialize `typedb.highways(500)` + top rollup counters, or full graph dump?
- R2 parquet flush: defer to a separate tuning cycle (Part III, T-waves) or include minimal stub in C5?
- Failure mode: if D1 flush fails, how many retries before shedding oldest non-critical events?

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/workers/analytics-relay.ts` — add `scheduleFlush()`: batch-insert WAL rows to D1 every 5s; write KV snapshot of top-500 highways every 60s; retry exponential on fail, never block `accept()`
- [ ] `web/migrations/0033_rollup_counters.sql` — create `rollup_counters` table: `(workspace, date, event, channel, count, updated_at)` for hourly aggregations

**W3b:**
*(empty)*

### W4 — Verify  [inline composite]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] After injecting 1001 events via DO test harness, D1 query `SELECT COUNT(*) FROM agent_events_warm` returns 1001
- [ ] KV key `typedb_snap/test-ws/{ts}` exists after 60s flush tick (integration test with fake timer)
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  compress_orphans=N`

---

## C6 — Realtime surfaces: snapshotForActor + useWatch  [tier: simple]

**Exit:** `const { events } = useWatch('actor:<hash>')` in a React island receives a live event within 200ms of `POST /api/events` with that visitor_hash. `bun run verify` green.

### W1 — Recon  [Haiku · parallel]

- `web/src/workers/analytics-relay.ts` — (after C4) current RPC surface; what DO methods are already exposed?
- `web/tracking-realtime.md` — §R1: `snapshotForActor()` RPC shape; §14.1 watch contract (SDK + Astro island)
- `web/src/pages/api/analytics/stream.ts` — current SSE endpoint; does it already connect to the DO?
- `web/src/lib/analytics-client.ts` — current client; can `useWatch` import from here?

### W2 — Decide  [Sonnet]

- `snapshotForActor()` RPC: returns `{ ladder, recent: AgentEvent[], campaign?, persona?, lifecycle?, llm_hint? }` — which fields are populated from in-RAM TypeDB vs D1 warm fallback?
- `useWatch()` hook: SSE-only for now (polling fallback for free tier, §L9) or WebSocket from the start?
- SSE endpoint `GET /api/analytics/watch?topic=actor:X`: does it open a persistent SSE stream to the DO or poll D1 on interval?
- Topic namespace for C6: `actor:<visitor_hash>` only, or also `segment:*` and `pulse:kpi`?

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/workers/analytics-relay.ts` — add `snapshotForActor(actorId)` RPC: read `typedb.recall(actorId)` + last 20 from `recent` ring buffer + persona/lifecycle tags; return typed snapshot
- [ ] `web/src/lib/use-watch.ts` — new: `useWatch(topic)` React hook; opens SSE to `/api/analytics/watch?topic=`; returns `{ events, summary, gap }` with auto-reconnect
- [ ] `web/src/pages/api/analytics/watch.ts` — new SSE endpoint: upgrade connection, subscribe to DO topic via WebSocket (internal), fan out to SSE client

**W3b:**
*(empty — all touch different files)*

### W4 — Verify  [inline composite]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `/browser --send "track event" --screenshot` confirms SSE stream opens and delivers first event on `/studio/test` page with `useWatch` wired
- [ ] `snapshotForActor('test-visitor')` returns `{ recent: [...], persona: [...] }` (vitest unit test with DO mock)
- [ ] Rubric composite ≥ 0.65

Targets: security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.85 · speed ≥ 0.80

Report: `delta_tsc=±N  delta_loc=±N  compress_orphans=N`

---

## Tuning backlog (T-waves, post-baseline)

Not in scope for the cycles above. Ship baseline (C1→C6) first.

| Wave | Levers | tracking.md ref |
| --- | --- | --- |
| T1 | L11 (HTTP/3 + preconnect) + L6 (deterministic DO routing) | §L11, §L6 |
| T2 | L1 (pixel batching 20 events / 250ms) + L3 (Cache API for one.js + email gif) | §L1, §L3 |
| T3 | L8 (WS coalesce + summary mode) + L9 (tier-aware fan-out) | §L8, §L9 |
| T4 | L7 (Smart Placement) + L10 (DO RPC vs fetch) | §L7, §L10 |
| T5 | L5 (stateless JWT verify) + L2 (Tail Worker AE) | §L5, §L2 |
| T6 | L4 (browser→DO direct WS after session start) | §L4 |

Exit scalar per tuning wave: `$/M events × p99 ingest × p99 watcher` vs previous wave. If product increases, roll back.

---

## Features deferred (post-T-waves)

From `tracking.md §25`:
- W6: Email open pixel (`/o/:token.gif`) + ESP webhook (Postmark)
- W7: Full identity ladder rungs 2–5 (email_hash, phone_hash, actor_id, linked)
- W8: Importer agents (Clearbit, Stripe, GA4)
- W9: Ad platform CAPI (Meta, Google Enhanced Conversions)
- W10: Channel adapter ingest (Telegram, Discord, SMS)
- W11: Consent gate + suppression enforcement + `POST /api/forget` multi-key cascade (extends shipped `DELETE /api/visitor/[hash]`) + `pii_vault` table + collection-mode dials
- W12: Attribution agent + holdout lift computation
- W13: DO sharding (256-way + coordinator DO)
- W16: Replay-from-R2 rebuild job

From `tracking-realtime.md`:
- R2: Agent surface-aware triggers (use case #2)
- R4: Ad-platform fan-out on threshold crossing (use case #7)
- R5: Segment topic computation (use case #10)
- R8: LTV + churn predicates (use cases #14, #16)
- R9: Anomaly + fraud + moderation predicates
- R10: Voice surface adapter (Twilio)

---

## See also

- `web/tracking.md` — full spec: AgentEvent shape, identity ladder, pipeline, cost model, tuning levers
- `web/tracking-realtime.md` — 25 realtime use cases ranked by impact × novelty × latency × readiness
- `web/agent-analytics.md` — event store, D1 tiers, KPI ladder (extended by this plan, not replaced)
- `one/dictionary.md` — canonical names (always)
- `one/rubrics.md` — scoring bands (always)
- `web/src/workers/analytics-relay.ts` — current DO (baseline for C2 rewrite)
