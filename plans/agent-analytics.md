# agent-analytics.md — measurement, attribution, and reporting

How we **capture, store, query, attribute, and export** every event an
agent generates. Companion to [`agent-lifecycle.md`](agent-lifecycle.md):
that doc defines *what* the funnel looks like and *how* to optimise it;
this doc defines *the data plumbing underneath*.

| Doc | Owns |
| --- | --- |
| `agent-lifecycle.md` | Funnel stages · goals · CRO techniques · KPI definitions |
| `agent-analytics.md` (this) | Event taxonomy · storage · queries · attribution · segmentation · retention · exports · privacy |

---

## Design principles

1. **Append-only** — events are immutable; aggregations recompute from source. No `UPDATE` on `agent_events`.
2. **Privacy by default** — opaque cookie hash, no PII, no IP retained beyond rate-limit window.
3. **Fire-and-forget** — emitting an event MUST NEVER block the chat response. `waitUntil` ingestion.
4. **Tiered storage** — hot (D1, last 14d) · warm (R2 daily rollups, 90d) · cold (R2 monthly archives, 2y).
5. **Pre-aggregated for read** — dashboards never scan raw events; they hit `funnel_daily` and `funnel_hourly` views.
6. **Statistical rigour** — every comparison reports sample size, p-value, and confidence interval.
7. **Holdout-aware** — A/B tests reserve 10% holdout; CRO claims are validated against it.
8. **Substrate-coupled** — every goal event also fires a pheromone signal; analytics and routing share the same source of truth.

---

## Event taxonomy

Three event surfaces, one shape. Canonical type: `src/lib/tracking-types.ts`.

```typescript
// src/lib/tracking-types.ts — live as of 2026-05-14
import type { AgentEvent, EventSource, ConsentState, ActorType } from '@/lib/tracking-types'

// AgentEvent — append-only; never rename a field
interface AgentEvent {
  id: string                       // ULID, client-generated, idempotency key
  ts: number                       // epoch ms
  slug: string                     // workspace slug
  agent_id: string | null          // which agent (null for pixel-only events)
  event: string                    // verb from taxonomy below
  variant?: string                 // A/B variant id
  visitor_hash: string             // sha256(cookie_id + workspace_salt) — rung 1
  thread_id?: string               // for conversational events
  actor_id?: string                // resolved actor ULID (rung 4+)
  actor_type?: 'human' | 'agent' | 'anonymous'
  source: 'web' | 'sdk' | 'mcp' | 'cli' | 'email' | 'channel' | 'webhook' | 'pixel'
  channel?: string                 // telegram | discord | email | sms | web | …
  campaign?: string                // campaign id
  link_id?: string                 // /go/:id when from a tracked link
  referrer?: string                // domain only (no path, no PII)
  user_agent_class?: string        // 'mobile-ios' | 'desktop-chrome' | 'bot' …
  locale?: string                  // BCP47
  payload: Record<string, unknown> // event-specific data
  consent_state: 'granted' | 'denied' | 'implied' | 'unknown'
  region: string                   // ISO-3166 country, geo-IP coarse only
  tags?: string[]                  // topic tags for pheromone routing
}
```

**Identity ladder** (rung 0-1 live; 2-5 deferred):

| Rung | Name | How set | Status |
| --- | --- | --- | --- |
| 0 | device | `_one` uuid cookie (2y), `src/lib/identity.ts cookieId()` | ✅ live |
| 1 | visitor | `sha256(cookie_id + ws_salt)` → `visitor_hash` | ✅ live |
| 2 | email | `sha256(lowercase_email + global_salt)` | ⬜ W7 |
| 3 | phone | `sha256(e164 + global_salt)` | ⬜ W7 |
| 4 | account | `actor_id` ULID on signup/verify | ⬜ W7 |
| 5 | linked | `actor_id ↔ external_id` (`same-as` relation) | ⬜ W7 |

Every event in the schema below maps 1:1 to a substrate signal of the
same name. The substrate gets pheromone; analytics get rows.

### Tier 1 — visitor lifecycle events (Phase 2)

Fire automatically from runtime. No author config.

| Event | When | Payload |
| --- | --- | --- |
| `intro-shown` | Studio loads, hero visible | `{}` |
| `stage-card-impression` | Stage card enters viewport | `{ stageId }` |
| `stage-start` | User clicks a stage card or its seed | `{ stageId, source: 'click' \| 'seed' \| 'continuation' }` |
| `stage-complete` | `successSignal` resolves within window | `{ stageId, durationMs, goalId }` |
| `stage-drop` | `dropSignal` triggers (idle, navigated away) | `{ stageId, reason: 'idle' \| 'navigated' \| 'closed' }` |
| `chip-impression` | Chip appears in chat trail (intersection observer) | `{ chipId, stageId? }` |
| `chip-click` | User clicks a chip | `{ chipId, stageId? }` |
| `chat-message` | User sends a turn | `{ role: 'user', threadId, charCount }` |
| `chat-reply` | Assistant turn streamed | `{ threadId, durationMs, tokenCount, hadToolCall: bool }` |
| `chat-tool-call` | LLM invoked a tool | `{ tool, threadId }` |
| `chat-tool-result` | Tool returned | `{ tool, ok, latencyMs, threadId }` |
| `artifact-saved` | Output saved to `{slug}/artifacts/<id>.md` (OUT2) | `{ artifactId, artifactType, threadId, bytes }` |
| `share-link-copied` | Share button clicked | `{ threadId }` |
| `thread-resumed` | Visitor opened a prior thread | `{ threadId, daysSinceLastVisit }` |
| `journey-complete` | All declared goals fired | `{ durationMs }` |
| `download` | PDF / md export | `{ format, threadId, bytes }` |

### Tier 2 — CRO events (Phase 2.5)

Fire when CRO machinery dispatches an action.

| Event | When |
| --- | --- |
| `idle-nudge-fired` | Idle re-engagement emitted an assistant turn |
| `idle-nudge-recovered` | User replied within `recoveryWindow` after a nudge |
| `abandonment-banner-shown` | Returning-visitor banner displayed |
| `abandonment-resumed` | User clicked the resume CTA |
| `social-proof-shown` | "N users completed this" badge rendered |
| `variant-assigned` | Visitor assigned to arm A/B (once per visitor) |
| `unlock-granted` | Variable-reward unlock fired |
| `friction-prefill` | Prior-thread fields auto-injected |
| `personalisation-rule-applied` | A `when` rule matched and override applied |

### Tier 3 — A2A events (Phase 2.5 + Wave 7.5 A2A1)

Fire on peer-routed agent-to-agent calls.

| Event | When |
| --- | --- |
| `peer-discovery-query` | This agent queried `/api/agents/discover` |
| `peer-route-selected` | Pheromone routing picked a peer |
| `peer-call-issued` | This agent called another's skill |
| `peer-call-result` | Result returned (with `ok`, `latencyMs`, `bytes`) |
| `pheromone-mark` | Path strengthened (success) |
| `pheromone-warn` | Path weakened (failure) |
| `x402-receipt-verified` | Payment settled |
| `escrow-locked` | Sui escrow created |
| `escrow-released` | Sui escrow paid out |

### Tier 4 — custom events (Phase 3+)

Authors emit custom events via a chat tool `emit_event({ name, payload })`
and via the SDK `client.emitAgentEvent(...)`. Names are namespaced
`custom:<author-defined>` and pass a schema check.

---

## Data model

### `agent_events_warm` (D1, hot store, 14 days) — live

Migration: `migrations/0031_agent_events_warm.sql`. Full `AgentEvent` shape.

```sql
-- key columns (see migration for full DDL)
CREATE TABLE agent_events_warm (
  id               TEXT PRIMARY KEY,   -- ULID, idempotency key (INSERT OR IGNORE)
  ts               INTEGER NOT NULL,
  slug             TEXT NOT NULL,
  agent_id         TEXT,
  event            TEXT NOT NULL,
  variant          TEXT,
  visitor_hash     TEXT NOT NULL DEFAULT '',
  thread_id        TEXT,
  actor_id         TEXT,
  actor_type       TEXT,
  source           TEXT NOT NULL DEFAULT 'web',
  channel          TEXT,
  campaign         TEXT,
  link_id          TEXT,
  referrer         TEXT,
  user_agent_class TEXT,
  locale           TEXT,
  payload          TEXT NOT NULL DEFAULT '{}',
  consent_state    TEXT NOT NULL DEFAULT 'unknown',
  region           TEXT NOT NULL DEFAULT '',
  tags             TEXT,   -- JSON array
  created_at       INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
);
-- Indexes: ts, visitor_hash, (slug, event)
```

`visitor_hash` is populated by `climbLadder()` in `src/lib/identity.ts` —
called in both `POST /api/events` (reads `_one` cookie from request) and
`GET /go/:id` (sets cookie on first hit). Events written before the cookie
is set arrive with `visitor_hash = ''`; they are stitched retroactively
via the `same-as` relation when rung 4 resolves (deferred W7).

### `rollup_counters` (D1) — live

Migration: `migrations/0033_rollup_counters.sql`.
`(workspace, date, event, channel)` → `count`. Hourly cron upserts.

### `tracked_links` (D1) — live

Migration: `migrations/0032_tracked_links.sql`.
Stores `/go/:id` destinations, campaign, channel metadata.

### `agent_events` (D1, legacy) — still exists

Original narrow-schema table from pre-tracking-pipeline work. Still
written by `/api/agent-events` for backward compat. New work reads from
`agent_events_warm`. Migration plan: union both in queries; drop `agent_events`
after W7 wires all callers to `/api/events`.

### `funnel_hourly` (D1, derived, 14 days)

```sql
CREATE TABLE funnel_hourly (
  slug         TEXT NOT NULL,
  agent_id     TEXT NOT NULL,
  bucket       INTEGER NOT NULL,        -- epoch ms rounded down to hour
  event        TEXT NOT NULL,
  variant      TEXT,
  stage_id     TEXT,
  goal_id      TEXT,
  count        INTEGER NOT NULL,
  unique_count INTEGER NOT NULL,        -- distinct visitor_hash
  value_sum    REAL NOT NULL DEFAULT 0, -- Σ goal.value
  PRIMARY KEY (slug, agent_id, bucket, event, variant, stage_id, goal_id)
);
```

Populated by the cron job described below.

### `funnel_daily` (D1, derived, 90 days)

Same shape as `funnel_hourly` with `bucket` = epoch ms rounded down to
UTC day. Backfilled hourly from `funnel_hourly`.

### `agent_events_daily.parquet` (R2, archive, 2 years)

Daily Parquet exports of `agent_events` partitioned by `slug/agent_id/date`.
Lets partners run their own analysis via DuckDB or similar — paid feature
in Phase 3.

```
{slug}/analytics/exports/{agent_id}/2026/05/13.parquet
```

### `funnel_visitor_state` (KV, ephemeral, 30 days)

Per-visitor session state, keyed `funnel:<slug>:<agent_id>:<visitor_hash>`:

```json
{
  "variant": "B",
  "firstSeen": 1716200000000,
  "lastSeen":  1716203600000,
  "stagesStarted":   ["brief", "research"],
  "stagesComplete":  ["brief"],
  "goalsHit":        ["brief-locked"],
  "unlocks":         ["free-headline-skill"],
  "lastThreadId":    "01HZQ...",
  "nudgesFired":     1
}
```

Used by CRO dispatchers (progressive disclosure, abandonment recovery)
without hitting D1 every request.

---

## Ingestion pipeline

```
   Client (browser, SDK, MCP, CLI, pixel, /go/:id)
              │
              ├── trackEvent()  →  POST /api/events   (typed AgentEvent)
              └── /go/:id       →  reads tracked_links → sets _one cookie
                                    → writes click event → 302

   POST /api/events  (src/pages/api/events.ts)
              │  parse + validate required fields
              │  climbLadder() — read _one cookie → visitorHash() → enrich event
              ▼
   ctx.waitUntil(D1.insert + DO broadcast)
              │
              ├──► D1 agent_events_warm   INSERT OR IGNORE (idempotent)
              │
              └──► WorkspaceDO (AnalyticsRelay) /broadcast
                       │  accept([event])
                       │    ├── rollups.bump(slug:event:channel:date)    O(1)
                       │    ├── recent.push(event)                       O(1), cap 10k
                       │    ├── wal.push(event)                          O(1)
                       │    └── world.mark(tag[i]→tag[i+1])             O(1) per tag pair
                       │
                       ├── alarm (50ms) → coalesce buffer → WS fan-out by topic
                       │       topics: slug:agentId | actor:visitor_hash | channel:X | global
                       │       clients: useWatch() SSE hook via /api/analytics/watch
                       │
                       ├── alarm (5s)  → WAL → D1 agent_events_warm batch insert
                       └── alarm (60s) → world.serialize() → KV typedb_snap/{slug}/{ts}

   ──── async (cron) ────
   funnel-aggregate-cron (hourly)
              │  SELECT from agent_events_warm WHERE ts > last_processed
              │  UPSERT INTO funnel_hourly + rollup_counters
              ▼
   funnel-aggregate-cron (daily, 02:00 UTC)
              │  roll funnel_hourly → funnel_daily
              │  archive raw events older than 14 days → R2 Parquet (deferred)
              ▼
   Dashboard /u/<slug>/agents/<id>/funnel reads from funnel_daily.
```

**Two ingest paths coexist:**
- `POST /api/events` — new typed path (C1+); returns `{ ok, id }`
- `POST /api/agent-events` — legacy path; still works, writes to `agent_events`

All new instrumentation uses `/api/events`. Legacy path stays until W7.

---

## Query patterns

### 1. Funnel chart (the canonical view)

```sql
-- Conversion rate per stage for the last 7 days
WITH per_stage AS (
  SELECT stage_id,
         SUM(CASE WHEN event = 'stage-start'    THEN count END) AS starts,
         SUM(CASE WHEN event = 'stage-complete' THEN count END) AS completes
  FROM funnel_daily
  WHERE slug = ?1 AND agent_id = ?2
    AND bucket >= ?3   -- 7 days ago
  GROUP BY stage_id
)
SELECT stage_id, starts, completes,
       CAST(completes AS REAL) / NULLIF(starts, 0) AS scr
FROM per_stage;
```

### 2. Variant lift (A/B winner check)

```sql
-- Goal-rate per variant; report lift only if both arms ≥ minSampleSize
SELECT variant,
       SUM(CASE WHEN event = 'variant-assigned'   THEN unique_count END) AS exposed,
       SUM(CASE WHEN event = 'stage-complete' AND goal_id = ?3 THEN unique_count END) AS converted
FROM funnel_daily
WHERE slug = ?1 AND agent_id = ?2
  AND bucket >= ?4
  AND variant IS NOT NULL
GROUP BY variant;
```

Server then computes `lift = (B/exposedB) / (A/exposedA) - 1` and
applies a two-proportion z-test for significance (see § Statistical
rigour below).

### 3. Top chips by CTR

```sql
WITH chips AS (
  SELECT json_extract(payload, '$.chipId') AS chip_id,
         event,
         SUM(count) AS total
  FROM agent_events
  WHERE slug = ?1 AND agent_id = ?2
    AND event IN ('chip-impression', 'chip-click')
    AND ts >= ?3
  GROUP BY chip_id, event
)
SELECT chip_id,
       SUM(CASE WHEN event = 'chip-impression' THEN total END) AS impr,
       SUM(CASE WHEN event = 'chip-click'      THEN total END) AS clicks,
       CAST(SUM(CASE WHEN event = 'chip-click' THEN total END) AS REAL)
         / NULLIF(SUM(CASE WHEN event = 'chip-impression' THEN total END), 0) AS ctr
FROM chips
GROUP BY chip_id
ORDER BY clicks DESC
LIMIT 20;
```

### 4. Cohort retention (7-day return rate)

```sql
-- First-visit cohort per day; return-visit within 7d
WITH first_visit AS (
  SELECT visitor_hash, MIN(ts) AS first_ts
  FROM agent_events
  WHERE slug = ?1 AND agent_id = ?2 AND event = 'intro-shown'
  GROUP BY visitor_hash
),
returned AS (
  SELECT DISTINCT fv.visitor_hash, fv.first_ts
  FROM first_visit fv
  JOIN agent_events ae ON ae.visitor_hash = fv.visitor_hash
                       AND ae.event = 'intro-shown'
                       AND ae.ts > fv.first_ts
                       AND ae.ts <= fv.first_ts + 7 * 86400 * 1000
)
SELECT DATE(first_ts / 1000, 'unixepoch') AS cohort_day,
       COUNT(DISTINCT fv.visitor_hash)             AS new_visitors,
       COUNT(DISTINCT r.visitor_hash)              AS returned_7d,
       CAST(COUNT(DISTINCT r.visitor_hash) AS REAL)
         / COUNT(DISTINCT fv.visitor_hash)         AS rate
FROM first_visit fv
LEFT JOIN returned r USING (visitor_hash)
GROUP BY cohort_day
ORDER BY cohort_day DESC;
```

### 5. Top conversion paths (sequence analysis)

Finds the sequences of stages users actually walk through, ranked by sessions and CVR. The "humanised highway" — no pheromone vocabulary exposed.

```ts
// Executed in-process (JavaScript, not SQL) — D1 doesn't support window functions
// 1. Pull all stage-start events per visitor ordered by ts
// 2. GROUP_CONCAT(stageId) per visitor → sequence string
// 3. JOIN with journey-complete visitors → converted flag
// 4. Aggregate by sequence string → { sessions, conversions, cvr }
```

Returned by `GET /api/agents/:id/paths`. Displayed as animated chip chains with CVR bars — the most common path highlighted, rare paths dimmed.

**What it answers:** "Which route through my agent converts best?" Directly actionable for funnel reordering.

### 6. Acquisition (referrer domain breakdown)

```sql
-- First-touch referrer per visitor, with conversion flag
SELECT visitor_hash,
  COALESCE(referrer, '') as referrer,
  MAX(CASE WHEN event = 'journey-complete' THEN 1 ELSE 0 END) as converted
FROM agent_events
WHERE slug = ? AND agent_id = ?
GROUP BY visitor_hash
-- Then parsed in-process: URL → hostname → domain
```

Returns `{ source, sessions, conversions, cvr }[]` sorted by sessions. "direct" for no referrer, "unknown" for malformed URLs.

### 7. Weekly cohort retention

```ts
// Computed in-process from two queries:
// 1. MIN(ts) per visitor → cohort week (floor to 7-day epoch week)
// 2. DISTINCT (visitor_hash, activity_week) → which weeks each visitor was active
// Then: for each cohort, count distinct visitors in each relative week
```

Returns up to 8 cohort rows × 7 relative weeks. `pct = retained / cohortSize`. Dashboard renders as a heatmap using `color-mix(in oklab, primary X%, foreground)` — opacity scales with retention rate.

### 8. Stage timing (from durationMs payloads)

```sql
SELECT json_extract(payload, '$.stageId') as stage_id,
       CAST(json_extract(payload, '$.durationMs') AS REAL) as duration_ms
FROM agent_events
WHERE slug = ? AND agent_id = ? AND event = 'stage-complete'
  AND json_extract(payload, '$.durationMs') IS NOT NULL
ORDER BY stage_id, duration_ms
```

Sorted arrays per stageId → median (index n/2), p90 (index 0.9n) computed in-process. No SQL percentile function needed.

### 9. Tool call analytics

```sql
SELECT event,
       json_extract(payload, '$.tool') as tool,
       json_extract(payload, '$.ok') as ok
FROM agent_events
WHERE slug = ? AND agent_id = ?
  AND event IN ('chat-tool-call', 'chat-tool-result')
```

`chat-tool-call` increments `calls`. `chat-tool-result` increments `successes` or `failures` based on `ok`. Success rate = `successes / calls`. Uniquely AI-native — no traditional analytics platform has this.

### 10. A2A path strength

Joins the WorkspaceDO pheromone world with funnel `peer-call-result`
events to show which incoming agents and tag paths convert best.

```sql
-- D1: raw peer-call outcomes
SELECT json_extract(payload, '$.fromAgent') AS source_agent,
       COUNT(*)                              AS calls,
       SUM(CASE WHEN json_extract(payload, '$.ok') THEN 1 ELSE 0 END) AS successes,
       AVG(json_extract(payload, '$.latencyMs'))  AS avg_latency_ms
FROM agent_events_warm
WHERE slug = ?1 AND agent_id = ?2
  AND event = 'peer-call-result'
  AND ts >= ?3
GROUP BY source_agent
ORDER BY calls DESC;
```

```ts
// WorkspaceDO pheromone world — top tag paths for this workspace
const doId = env.ANALYTICS_HUB.idFromName(slug)
const stub = env.ANALYTICS_HUB.get(doId)
const highways = await stub.fetch(
  new Request(`https://do/highways?prefix=channel:&n=20`)
).then(r => r.json())
// → [{ from, to, strength, resistance, net }]
```

### 11. Actor snapshot (realtime)

Hydrates a chat agent or CRM page with the actor's current context in
one in-RAM read — no warehouse round-trip.

```ts
const snap = await stub.fetch(new Request('https://do/snapshot', {
  method: 'POST',
  body: JSON.stringify({ actorId: visitor_hash }),
})).then(r => r.json())
// → { recent: AgentEvent[], persona: string[], highways: Highway[] }
```

`persona` = union of all `tags` across the actor's recent events.
`highways` = top DO pheromone edges — used for next-best-action.

### 12. Live subscription (useWatch)

```tsx
import { useWatch } from '@/lib/use-watch'

function ContactPanel({ visitorHash, slug }) {
  const { events, summary, gap } = useWatch(`actor:${visitorHash}`, slug)
  // events: last 100 live events for this actor
  // summary.persona: current tag set
  // gap: true if SSE is reconnecting
}
```

`useWatch` opens `GET /api/analytics/watch?topic=actor:X&slug=Y` which
bridges to the WorkspaceDO WebSocket topic via TransformStream.

---

## Attribution model

Customer journeys cross multiple touch points. We support three
attribution modes; partner picks per-agent.

| Mode | What it credits | When to use |
| --- | --- | --- |
| **First-touch** | The first event in the visitor's first session | Top-of-funnel research |
| **Last-touch** | The final event before the goal | Bottom-of-funnel conversion |
| **Linear** | Equal share across all events in the journey | Multi-step funnels (default) |

Configured via `analytics.attribution: first | last | linear` in
frontmatter (Phase 3). Default is `linear`. Server materialises an
`attributed_value` column per (event, goal) pair using the chosen model.

External referrer attribution is captured via the `referrer` column
(canonicalised host, no PII). UTM parameters propagate from the URL
into a denormalised `utm_source`, `utm_medium`, `utm_campaign` column
during ingestion.

---

## Segmentation

Every KPI can be segmented on these dimensions without extra config:

| Segment | Source |
| --- | --- |
| **Variant** | `agent_events_warm.variant` |
| **Locale** | `agent_events_warm.locale` (BCP-47) |
| **Device** | `agent_events_warm.user_agent_class` |
| **Source** | `agent_events_warm.source` (web/sdk/mcp/cli/email/channel/webhook/pixel) |
| **Channel** | `agent_events_warm.channel` (telegram/discord/email/sms/web) |
| **Campaign** | `agent_events_warm.campaign` |
| **Referrer** | `agent_events_warm.referrer` |
| **Tracked link** | `agent_events_warm.link_id` → join `tracked_links` |
| **Consent state** | `agent_events_warm.consent_state` |
| **Region** | `agent_events_warm.region` (ISO-3166) |
| **Tags (pheromone)** | `agent_events_warm.tags` JSON array → DO `highways` |
| **Returning vs new** | `funnel_visitor_state.firstSeen` |
| **Logged-in vs anon** | `actor_type` column |

Dashboard surfaces a "Segment by…" dropdown that drives a parameterised
query. Multi-dim segmentation (variant × locale) is supported up to two
dimensions; beyond that the matrix is too sparse to be useful.

---

## Statistical rigour

When the dashboard claims "variant B converts 12% better", that claim
is gated on:

1. **Sample size** ≥ `minSampleSize` per arm (default 100 conversions, not impressions)
2. **Two-proportion z-test**, two-sided, α = 0.05
3. **Confidence interval** ± 95% shown alongside the point estimate

Implementation in `lib/funnel/stats.ts`:

```ts
export function variantLift(
  arms: { name: string; exposed: number; converted: number }[],
  minSample: number,
): { winner?: string; lift?: number; ci?: [number, number]; pValue?: number; note: string } {
  if (arms.some(a => a.converted < minSample))
    return { note: `Not enough data — minimum ${minSample} conversions per arm` }
  // Compute z-test + lift + CI; full implementation in the lib file.
  // ...
}
```

The dashboard renders "✗ Not enough data" rather than misleading deltas.

**Holdout policy:** when `variants.holdout` is set in the funnel block,
that fraction is excluded from variant assignment and serves the
control prompt regardless. Lift is also reported vs holdout. Default
holdout is 0% (off) — partners opt in.

---

## Retention policy

| Tier | Where | Duration | Why |
| --- | --- | --- | --- |
| Hot | D1 `agent_events` | 14 days | live debugging, ad-hoc queries |
| Warm | D1 `funnel_hourly` | 14 days | hour-resolution dashboards |
| Warm-2 | D1 `funnel_daily` | 90 days | day-resolution dashboards |
| Cold | R2 Parquet | 2 years | exports, audits |
| GDPR delete | All tiers | within 30 days of request | legal |

GDPR delete: a `DELETE /api/visitor/<visitor_hash>` admin endpoint
removes rows matching the hash across all tiers within 30 days. Hashes
are opaque so deletion-by-hash is purely operational.

---

## Privacy + ethics

- **Visitor identification:** `visitor_hash = sha256(cookie_id + workspace_salt)`. The salt is per-workspace so the same cookie produces different hashes across workspaces — no cross-workspace tracking.
- **No PII fields exist in the schema.** Email, IP, name, geolocation are explicitly excluded. IP is used only for rate-limiting in a 60-second KV window then discarded.
- **No fingerprinting.** Device class is bucketed (desktop/mobile/tablet/bot) — no UA strings retained.
- **Locale only from `Accept-Language` first 2 chars.** No geolocation databases.
- **Substrate signals carry the same payload as events.** Same privacy rules.
- **Dashboard read access** gated on workspace ownership via existing middleware (`Astro.locals.slug`).
- **Public exports** never include `visitor_hash` — Parquet shipped to partners only includes derived counts.

---

## Exports

Three export shapes for partners who want raw data:

### 1. CSV (free tier)

```
GET /api/agents/<id>/analytics/export.csv?from=&to=&grain=daily
→ slug,agent_id,date,event,variant,count,unique_count,value_sum
```

Capped at 100k rows. Throttled by per-key rate-limit.

### 2. JSON (free tier)

```
GET /api/agents/<id>/analytics/export.json?from=&to=
→ { events: [...], kpis: {...}, generatedAt }
```

### 3. Parquet (Pro tier)

```
GET /api/agents/<id>/analytics/export/parquet?from=&to=
→ 302 redirect to a 24h-signed R2 URL
```

Partners pull from R2 and run DuckDB locally:

```sql
SELECT event, COUNT(*) FROM read_parquet('events.parquet')
WHERE date BETWEEN '2026-05-01' AND '2026-05-13'
GROUP BY event;
```

---

## Dashboard architecture

Two pages: `/u/<slug>/agents/<id>/analytics` (overview) and `/u/<slug>/agents/<id>/funnel` (funnel detail). Both are Astro SSR with React islands for interactive charts.

```
<analytics.astro>                         10 parallel SSR fetches
  ├── KPI row (4 headline numbers)        static HTML
  ├── <EventTimelineChart>   client:v     recharts AreaChart — event trends over time
  ├── <FunnelChart>          client:v     lifecycle-aware stage bars (journey: block titles)
  ├── <VariantCard>          client:v     A/B arms, lift %, recharts BarChart
  ├── <AudienceCard>         client:v     human/agent/anonymous stacked bar + identified table
  ├── <PathsCard>            client:v     top converting sequences as animated chip chains
  ├── <AcquisitionCard>      client:v     referrer domain dual-layer bars
  ├── <RetentionGrid>        client:v     weekly cohort heatmap, color-mix on primary
  ├── <StageTimingCard>      client:v     median/p90 bars per stage (only if data)
  ├── <ToolCallsCard>        client:v     per-tool success rate (only if tool events)
  ├── <ChipCtrChart>         client:v     chip impressions vs clicks (only if chip data)
  ├── <OptimizationCard>     client:v     CRO technique impact (only if CRO events)
  ├── Metrics grid           static HTML  artifact rate, return rate, TTC, A2A, messages
  ├── Event counts table     static HTML  all events ranked by volume
  ├── <LiveEventStream>      client:v     WebSocket — events slide in live, green pulse dot
  └── Export panel           static HTML  CSV / JSON download links
```

**Lifecycle-aware funnel:** `FunnelChart` fetches `/api/agents/:id/lifecycle` which reads the agent's `journey:` block from R2 markdown. Stage titles from the markdown (e.g. "New or Existing?", "Project Brief") replace raw `stageId` slugs. All defined stages appear in definition order even with zero events — greyed out until data arrives.

**Real-time (two surfaces):**

| Surface | API | When to use |
| --- | --- | --- |
| `LiveEventStream` (existing) | `GET /api/analytics/stream` → WS → DO | Dashboard live tail — all events for a workspace:agent |
| `useWatch()` hook (new) | `GET /api/analytics/watch?topic=actor:X` → SSE → DO | Per-actor CRM panel, contact page, chat agent hydration |

`LiveEventStream` auto-reconnects on WS close (3s backoff). `useWatch`
uses EventSource with exponential backoff (1s→30s). Both bridge to
the same `AnalyticsRelay` DO topic map — no duplication of state.

**Pheromone world (WorkspaceDO RPCs):**

| Endpoint | Returns | Use |
| --- | --- | --- |
| `GET /highways?prefix=channel:&n=20` | top-N tag edges | next-best-action, segment routing |
| `GET /follow?from=persona:founder` | `{ next }` | deterministic best-next step |
| `GET /sense?edge=A→B` | `{ strength }` | path health check |
| `POST /snapshot` body `{ actorId }` | `{ recent, persona, highways }` | agent hydration, CRM context |

---

## Frontmatter — the `analytics:` block

The funnel block (`agent-lifecycle.md`) is where authors declare goals
and CRO. The analytics block is where they tune measurement defaults.
**Most authors never touch it — defaults are good.**

```yaml
analytics:
  # Which raw events to ingest (default: all in taxonomy)
  events:
    include: [intro-shown, stage-start, stage-complete, chip-click, chat-message,
              artifact-saved, share-link-copied, journey-complete]
    exclude: [chat-tool-result]    # noisy

  # Attribution model — first | last | linear (default: linear)
  attribution: linear

  # Retention overrides — falls back to defaults if unset
  retention:
    hot:   14d                     # D1 raw
    warm:  90d                     # daily rollup
    cold:  2y                      # R2 parquet

  # Statistical guard rails
  significance:
    alpha: 0.05                    # two-sided z-test
    minSampleSize: 100             # per variant arm
    holdout: 0.10                  # reserve 10% for holdout

  # Export tier — what's exposed via /export endpoints
  exports:
    csv: true                      # free tier
    json: true                     # free tier
    parquet: pro                   # paywalled

  # Custom events (Phase 3)
  customEvents:
    - name: persona-locked
      schema:
        personaId: string
        confidence: number

  # Substrate coupling (default: all goals fire signals)
  substrate:
    emitOn: [goal, stage-complete, peer-call-result, x402-receipt-verified]
    sensitivity: 0.6               # high = signal louder
```

Author-side, this is rarely set. Platform-side, the defaults live in
`web/_platform/analytics-defaults.json` and are inherited by every agent.

---

## What `agent-lifecycle.md` references in here

Every KPI definition in `agent-lifecycle.md § KPI definitions` is
computed by a SQL pattern in `agent-analytics.md § Query patterns`.
Every CRO technique fires events listed in `agent-analytics.md § Event
taxonomy § Tier 2`. The two docs are **two ends of the same wire**.

If you change an event name in this doc, update `agent-lifecycle.md`'s
"Standard events" table in the same PR. The schema validator
(`agent-schema.ts`) cross-references both via a shared `event-vocabulary.ts`
constants file.

---

## Files this spec touches

```
SHIPPED — tracking pipeline baseline (C1–C6, 2026-05-14)
  migrations/0031_agent_events_warm.sql      — full AgentEvent schema + indexes
  migrations/0032_tracked_links.sql          — /go/:id link table + test fixture
  migrations/0033_rollup_counters.sql        — hourly rollup counters table
  web/src/lib/tracking-types.ts             — AgentEvent interface + union types (canonical)
  web/src/lib/identity.ts                   — cookieId(), visitorHash(), climbLadder()
  web/src/lib/pheromone.ts                  — vendored in-RAM world (mark/warn/sense/follow/select/highways)
  web/src/lib/use-watch.ts                  — useWatch() SSE hook with auto-reconnect
  web/src/lib/analytics-client.ts           — trackEvent() → POST /api/events (updated)
  web/src/pages/api/events.ts               — typed ingest endpoint; returns { ok, id }
  web/src/pages/api/analytics/watch.ts      — SSE endpoint (WS→SSE bridge via DO)
  web/src/pages/go/[id].ts                  — /go/:id tracked redirect Worker
  web/src/workers/analytics-relay.ts        — WorkspaceDO: rollups, WAL, pheromone world,
                                              50ms alarm coalesce, 5s D1 flush, 60s KV snap,
                                              cold-start restore from KV snapshot
  web/wrangler.toml                         — [[durable_objects.bindings]] ANALYTICS_HUB

SHIPPED — pre-tracking-pipeline
  migrations/0027_actor_identity.sql         — actor_id + actor_type columns + index
  web/src/lib/agent-events.ts                — emitEvent (legacy; still used by /api/agent-events)
  web/src/lib/event-vocabulary.ts            — shared event-name constants
  web/src/lib/funnel/queries.ts              — funnel aggregate query helpers
  web/src/pages/api/agent-events.ts          — legacy ingest (writes to agent_events)
  web/src/pages/api/analytics/stream.ts      — WebSocket upgrade → AnalyticsRelay DO
  web/src/pages/api/funnel/[id]/kpis.ts      — 9-dimension KPI endpoint
  web/src/pages/api/funnel/[id]/timeline.ts  — bucketed event counts for AreaChart
  web/src/pages/api/agents/[id]/analytics.ts — event counts + top chips summary
  web/src/pages/api/agents/[id]/lifecycle.ts — human-readable stages from journey: block
  web/src/pages/api/agents/[id]/audience.ts  — actor breakdown + identified table
  web/src/pages/api/agents/[id]/paths.ts     — top conversion path sequences
  web/src/pages/api/agents/[id]/acquisition.ts — referrer domain + CVR
  web/src/pages/api/agents/[id]/retention.ts — weekly cohort grid
  web/src/pages/api/agents/[id]/stage-timing.ts — median/p90 per stage
  web/src/pages/api/agents/[id]/tool-calls.ts  — per-tool success rates
  web/src/workers/funnel-aggregate-cron.ts   — hourly + daily roll-ups
  web/src/components/funnel/                 — dashboard components (FunnelChart, VariantCard, …)
  web/src/components/funnel/LiveEventStream.tsx — WS feed; see also useWatch() for per-actor
  web/src/pages/u/[slug]/agents/[id]/analytics.astro — main dashboard
  web/src/pages/u/[slug]/agents/[id]/funnel.astro    — funnel detail page

SHIPPED — analytics completions (2026-05-14)
  web/src/lib/funnel/stats.ts                — variant lift z-test + CI (131 LOC, real implementation)
  web/src/lib/funnel/attribution.ts          — first/last/linear attribution models (82 LOC)
  web/src/pages/api/visitor/[hash].ts        — GDPR delete by visitor_hash (79 LOC)
  web/_platform/analytics-defaults.json      — platform defaults JSON
  web/wrangler.toml                          — ANALYTICS_HUB DO binding + v1 migration + cron triggers
  web/astro.config.mjs                       — durableObjectExportsPlugin: AnalyticsRelay export + scheduled cron handler

DEFERRED
  Parquet writing in AGG2                    — Phase 3 / W16 (export endpoint exists; R2 write not yet wired)
  Identity rungs 2-5 (email/phone/account)   — W7
```

---

## Compatibility invariants (don't break)

1. **Event names are append-only.** Renaming breaks aggregations. Add a new event; deprecate the old one with a `until` date.
2. **Payload shape is forward-compatible.** Adding fields = OK; removing = breaks downstream consumers; renaming = breaks dashboards.
3. **Visitor hash is stable per cookie + workspace.** Don't change the salt without a migration plan (would split every cohort).
4. **Ingestion never blocks the request.** `waitUntil` only. A failed insert is logged but the chat reply still streams.
5. **Aggregations are rebuildable from raw events** for the hot-tier window. If `funnel_daily` is corrupted, drop it and re-roll. (Beyond 14d, R2 Parquet is the source of truth.)
6. **Sample-size guards apply to every comparison surface.** Dashboard never shows lifts below the threshold.
7. **No PII reaches storage.** Schema validates at ingestion; rows that fail PII checks are dropped with a warn.
8. **Substrate signals and analytics events are 1:1.** Same name, same payload, same time. Pheromone and dashboards never diverge.

---

## Quality bar

| Dimension | Target |
| --- | --- |
| **Ingestion latency** | < 5ms p95 (just enqueues via `waitUntil`) |
| **Dashboard cold load** | < 100ms p95 (reads pre-aggregated rows) |
| **Cron freshness** | hourly roll-up ≤ 5 min lag; daily ≤ 30 min after UTC day boundary |
| **Storage cost per agent** | < $0.01/month at 10k events/day |
| **Export generation** | CSV/JSON < 2s; Parquet < 30s for 30 days |
| **Statistical power** | always reports CI + p-value, never bare deltas |

Regression on any of these fails the rubric.

---

*Append-only events. Privacy-by-default. Pre-aggregated reads. Substrate
and analytics share one source. Funnel definitions in one doc, plumbing
in another. Two ends of the same wire.*
