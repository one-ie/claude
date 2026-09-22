---
name: perf
description: Iterative perf tuning — instrument, measure quantiles, attack the biggest bin, re-measure. Use when latency or throughput targets are missed and the bottleneck is unknown.
---

# /perf — Performance Optimization Loop

Enforces Rule 3 on perf work: quantiles, not averages; bottleneck rank, not slowest call.

## The loop (one iteration)

1. **Instrument** — bracket every async boundary; extend `packages/sdk/src/telemetry.ts` before inventing a new surface. No target → no work.
2. **Run** — production-shaped load (real signal sizes, real receiver distribution). Capture every trace row.
3. **Analyse** — script reports per-op `count / p50 / p95 / p99 / total = count × p50`. Sort by total; the top 1–2 lines are the next cycle. Optimize the *biggest* op, not the *slowest*.
4. **Propose → measure** — one change per iteration. Re-run 2–3. Compare quantiles, not averages.

**Symptom → likely cause:**

| Symptom | Cause |
|---|---|
| High p99, low p50 | tail latency — locks, GC, retries |
| High flat distribution | algorithmic — wrong data structure |
| Many short calls dominate | call overhead — fan-out, async hop, JSON parse |
| Memory-bound | redundant copies, missing buffer reuse |
| Network-bound | round-trips — coalesce, cache |

**Stop:** target hit, or 3 iterations with <10% delta on the top bin.

## Receipt (Rule 3)

```json
{ "receiver": "perf:session:ok", "data": { "weight": 1, "content": {
  "path": "<surface>", "target_us": N,
  "before": { "p50_us": N, "p95_us": N, "p99_us": N },
  "after":  { "p50_us": N, "p95_us": N, "p99_us": N },
  "delta_pct": { "p50": -N, "p95": -N, "p99": -N },
  "wins": [ { "iter": N, "change": "...", "p50_delta_pct": -N } ]
}}}
```

Negative `delta_pct` = faster. Pheromone marks the path; substrate learns which optimization shapes pay off where.

## Targets

`50ms` agent wallet · `<10ms` gateway · `3s` buy · `30s` list. From root `CLAUDE.md`.
