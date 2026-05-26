---
title: Agent analytics — wire cron, DO export, platform defaults, e2e tests
slug: agent-analytics
type: plan
tier: simple
mode: construction
tags: [analytics, durable-object, cron, funnel, wrangler]
source_of_truth:
  - web/agent-analytics.md
  - web/src/workers/analytics-relay.ts
  - web/src/workers/funnel-aggregate-cron.ts
  - web/wrangler.toml
show: false
escape:
  condition: "C1 W4 delta_tsc > 0 twice"
  action: "halt; check astro cloudflare adapter DO export docs before retrying"
context_triggers:
  - pattern: "AnalyticsRelay|DurableObject|durable.object"
    inject: "web/agent-analytics.md § Dashboard architecture"
  - pattern: "funnel_hourly|funnel_daily|funnel_agg_cursor"
    inject: "web/agent-analytics.md § Data model"
  - pattern: "scheduled|cron|triggers"
    inject: "web/agent-analytics.md § Ingestion pipeline"
---

# Agent analytics — wire cron, DO export, platform defaults, e2e tests

**Goal:** The analytics backend code exists; wire it so it actually runs — cron trigger in wrangler, DO re-export for CF adapter, platform defaults JSON, and a smoke test confirming events flow end-to-end.

**Exit:** `POST /api/events` → row in D1 `agent_events_warm`; `GET /api/analytics/watch?topic=global&slug=test` delivers that event over SSE within 200ms; `bun run verify` passes.

---

## Context

All backend code is shipped (`web/src/workers/analytics-relay.ts`, `web/src/workers/funnel-aggregate-cron.ts`, all API routes, all migrations). Three things keep it from running:

1. **No cron trigger** — `funnel-aggregate-cron.ts` exports a `scheduled` handler but wrangler.toml has no `[triggers]` entry pointing at it. Aggregations never fire.
2. **DO class not re-exported** — Astro's Cloudflare adapter needs `AnalyticsRelay` re-exported from the worker entry. Currently it's only exported from its own file; the DO binding in wrangler works in wrangler dev but fails silently in `astro build` output because the class isn't in the emitted `_worker.js`.
3. **`_platform/analytics-defaults.json` missing** — the spec references it; without it the analytics frontmatter fallback path throws at runtime (or fails silently to load defaults).

---

## Dependency graph

```
C1:do-export ──→ C2:cron-wire
```

`C1 → C2` because the cron worker imports `AnalyticsRelay` types; if C1 changes the export shape, C2's wrangler entry must reference the correct export.

---

### W3 agent parallelism map

```
C1 W3a — parallel:
  agent-1  →  web/src/env.d.ts                   # declare AnalyticsRelay export in ambient types
  agent-2  →  web/src/workers/analytics-relay.ts  # add explicit re-export shim comment (already exported; verify)
  agent-3  →  web/_platform/analytics-defaults.json  # create file

C1 W3b — sequential (after W3a):
  agent-4  →  web/astro.config.mjs               # wire DO re-export via cloudflare adapter config

C2 W3a — parallel:
  agent-5  →  web/wrangler.toml                  # add [triggers] crons block
  agent-6  →  web/agent-analytics.md             # update SHIPPED section: remove _platform stale DEFERRED
```

---

## Status

- [x] C1 — DO re-export + platform defaults
  - [x] W0 baseline
  - [x] W1 recon
  - [x] W2 decide
  - [x] W3 edit
  - [x] W4 verify

- [x] C2 — Cron trigger wiring
  - [x] W0 baseline
  - [x] W1 recon
  - [x] W2 decide
  - [x] W3 edit
  - [x] W4 verify

---

## C1 — DO re-export + platform defaults  [tier: simple]

**Exit:** `bun run build` succeeds without "AnalyticsRelay is not exported" error AND `web/_platform/analytics-defaults.json` exists with the shape from `agent-analytics.md § Frontmatter`.

### W1 — Recon  [direct — ≤5 files]

- `web/astro.config.mjs` — how the Cloudflare adapter is configured; look for `cloudflare()` options and any existing DO/worker export hooks
- `web/wrangler.toml` — current `[[durable_objects.bindings]]` block; `script_name` is empty (correct for same-script DO) but check if the adapter needs `workerEntryPoint` config
- `web/src/workers/analytics-relay.ts` — confirm `export class AnalyticsRelay` is the top-level named export (not default)
- `web/src/env.d.ts` — check if `AnalyticsRelay` appears in ambient type declarations

### W2 — Decide  [Sonnet]

- Does `@astrojs/cloudflare` v12+ require an explicit `workerEntryPoint` in `astro.config.mjs` to include DO class exports in the final `_worker.js`?
- Is `analytics-defaults.json` consumed by any runtime code right now (grep `analytics-defaults`)? If not, create a stub shape; if yes, match the exact keys it expects.
- Compose / extend / new for the `analytics-defaults.json` path: it's a new static asset, so new.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/_platform/analytics-defaults.json` — create with the shape from `agent-analytics.md § Frontmatter analytics:` block as JSON (events.include, attribution, retention, significance, exports, substrate)
- [ ] `web/src/env.d.ts` — add `interface Env { ANALYTICS_HUB: DurableObjectNamespace }` if absent

**W3b — dependent (after W3a confirms adapter config pattern):**
- [ ] `web/astro.config.mjs` — add DO re-export config to cloudflare adapter if required by adapter version

### W4 — Verify  [inline]

- [ ] `bun run build` passes (no missing export errors for AnalyticsRelay)
- [ ] `bun run verify` green (biome + tsc + vitest)
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `cat web/_platform/analytics-defaults.json | jq .attribution` returns `"linear"`
- [ ] Rubric composite ≥ 0.65

Targets: security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.90 · speed ≥ 0.80

Report: `delta_tsc=±N  delta_loc=±N  compress_orphans=N`

---

## C2 — Cron trigger wiring  [tier: trivial]

**Exit:** `wrangler.toml` has a `[triggers]` block with `crons = ["0 * * * *", "0 2 * * *"]` pointing at the funnel-aggregate-cron scheduled handler; `bun run verify` passes.

### W1 — Recon  [direct]

- `web/wrangler.toml` — confirm no existing `[triggers]` block
- `web/src/workers/funnel-aggregate-cron.ts` — confirm `export default { async scheduled(...) }` shape and which cron expressions it dispatches on (`0 * * * *` = hourly AGG1, `0 2 * * *` = daily AGG2)

### W2 — Decide  [inline]

- Does `funnel-aggregate-cron.ts` export a `default` worker object (Cloudflare Workers scheduled format) or does it need to be merged into the Astro main worker's `scheduled` hook?
- If it's a separate Worker script: it needs its own `wrangler.toml` entry (or a multi-script build). If it merges into Astro's `_worker.js`: needs a `scheduled` export via adapter hooks.

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `web/wrangler.toml` — add `[triggers]\ncrons = ["0 * * * *", "0 2 * * *"]` if cron merges into main worker; OR document that it requires a separate wrangler deploy command in a comment
- [ ] `web/agent-analytics.md` — update DEFERRED section: move `_platform/analytics-defaults.json` from DEFERRED to SHIPPED (after C1), remove stale DEFERRED entries that now exist (`stats.ts`, `attribution.ts`, `visitor/[hash].ts`)

**W3b:**
*(empty — edits are independent)*

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `grep -c "0 \* \* \* \*" web/wrangler.toml` returns ≥ 1 OR comment explains separate deploy
- [ ] Rubric composite ≥ 0.65

---

## See also

- `web/agent-analytics.md` — full spec: event taxonomy, data model, ingestion pipeline, query patterns
- `web/src/workers/analytics-relay.ts` — WorkspaceDO: rollups, WAL, pheromone world, KV snap
- `web/src/workers/funnel-aggregate-cron.ts` — scheduled handler: AGG1 hourly, AGG2 daily
- `web/tracking-todo.md` — C1–C6 all `[x]`; this TODO continues where tracking left off
- `one/dictionary.md` — canonical names
- `one/rubrics.md` — scoring bands
