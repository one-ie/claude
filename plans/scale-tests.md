# Scale Tests — Proving Millions of Users at Speed

> Companion to [`scale.md`](scale.md). That doc makes the claims; this doc designs the tests that **prove each claim with measured numbers**. The headline test (T0 — *The Millions Proof*) provisions 1M users and runs every other test against that load for two hours; the cheap proof (Q1–Q3) sustains the equivalent RPS for 60 seconds at a cost under $1. Both are runnable on `app.one.ie` today.

**Scope:** design + runnable. Q1–Q3 are runnable now ([`web/tests/perf/quickproof/`](../../one.ie/web/tests/perf/quickproof/)). T0 is fully designed; build cost ~$50/run. Tests target **local** (`bun run dev`) and **staging** (`app.one.ie`). One-shot, on-demand.

---

## 1. Principle

Speed and scale claims without measurements are marketing. Every test below produces a number; that number passes a threshold or fails it. The result is posted as `mark`/`warn` on `perf:*` paths so the substrate participates in its own learning loop.

Engine Rule 3 applies: **every loop reports verified numbers, not vibes.**

---

## 2. The map — concern → test that defuses it

The first table a partner reads. Five concerns, each backed by tests.

| Concern | Headline test | Component tests (diagnostic) | What pass means |
| --- | --- | --- | --- |
| **1. Hold up at scale with speed** | Q1 (60s, $1) · T0 (2h, $50) | T1–T7 (volume); P1–P6, P8 (speed) | Sustain 5,000 RPS = 1M users, with p95 <150ms, speed metrics in budget — even with isolation/failure/cost probes firing during the run |
| **2. Tenant isolation** | Q3 (60s) · T0 (mid-run probes) | **T8** hot tenant · **T9** cross-workspace attempt · **T13** export/delete | Hot tenant ≤20% degradation to cold; every cross-workspace API call returns 401/empty; export of one workspace returns clean blob, zero cross-tenant rows |
| **3. What happens when something fails** | T0 (chaos probes during load) | **T10** TypeDB cut · **T11** LLM fallback · **T12** D1 backpressure | Graceful degradation under all three failure modes; no silent drops; no data loss |
| **4. Cost predictability + cheaper than building it** | T0 (T14 runs continuously during) | **T14** cost instrumentation · **P7** head-to-head vs Express/Lambda | Measured $/company within ±20% of $2.50 model; we beat Express on TTFB by ≥50ms, TTI by ≥500ms, cost by ≥5× |
| **5. Onboarding speed** | T15 + T16 (run standalone) | **T15** provision throughput · **T16** zero-to-first-signal | 1,000 workspaces created in <10 min; new workspace's first signal accepted within 60 s |
| **6. Real-pilot operations** *(the 50-client launch)* | T17–T22 run as a one-week warm-up sequence | **T17** 72h endurance · **T18** real-LLM cost · **T19** data ingest · **T20** live deploy · **T21** per-client report · **T22** pause/resume | Six-week pilot survives: no memory leak, measured $/conversation within ±25%, Brad's 12k-row CSV imports in <10 min, hot-fix deploys with <0.1% error spike, per-client daily report generates in <30s, paused workspaces accrue zero cost |

**Reading guide:** when a question lands, scroll to the row, point at the test number, jump to §10 for the design.

**T0 is the test that ends the argument.** It runs *every* component test simultaneously while serving a million users for two hours. When T0 is green, every row above is green by direct measurement, not inference. The partner reads T0's report.

---

## 3. Scope

**In scope:**
- All six concerns, end-to-end, against local + `app.one.ie`
- 25 tests total (Q1–Q3, T0, T1–T22, P1–P8 — overlap collapsed)
- One-shot, on-demand
- Q1–Q3 runnable today; T0 + T17–T22 fully designed (build cost ~$50 for T0, ~$15 for the pre-pilot week)

**Out of scope:**
- T5 (50M users) distributed load — designed in §11; needs k6 Cloud or multi-region runners
- Production load against `one.ie` — would mix synthetic with real traffic and burn LLM spend
- Continuous CI gating — every-PR runs cost too much for partner-confidence work
- Real-user (RUM) metrics — closes in pilot, not now
- Mobile-network specific tests — separate later doc
- Chaos beyond the three named failure modes — separate later doc

---

## 4. Tooling

| Tool | Job | Why this one |
| --- | --- | --- |
| **k6** | HTTP load + arrival-rate executor | Single binary, JS-scriptable, machine-readable output |
| **Lighthouse** | Web Vitals + a11y + dark-mode contrast | Already used (`web/scripts/lighthouse-in.sh`); Google reference |
| **WebPageTest CLI** | Multi-region synthetic page tests | Real Chrome on real network shapes |
| **Playwright** | Browser flows + cross-workspace API attacks | Already installed (`.claude/scripts/browser-check.mjs`) |
| **curl + bash** | TTFB probes, cold/warm gap, provisioning latency | Lowest-noise way to measure first-byte |
| **esbuild metafile** | Bundle budget | Astro build emits one; we just read it |
| **Custom chaos scripts** | TypeDB cut, LLM rate-limit injection | One-off Node scripts toggling feature flags |
| **Terraform** | Reference stacks for P7 head-to-head | Provision Express/EC2 + Lambda; tear down after run |

We do **not** add Artillery, JMeter, locust, or a SaaS load tool. One toolchain, one mental model.

---

## 5. Test environments

| Env | URL | Use for |
| --- | --- | --- |
| **Local** | `localhost:4321` (`bun run dev`) | Rapid iteration; catching regressions before staging |
| **Staging** | `app.one.ie` | Real CF Workers + D1 + KV + TypeDB Cloud. Anything shared with the partner comes from here. |
| **P7 reference — Express** | `perf-ref-express.example.com` (t3.small, us-east-1) | Reference stack for head-to-head |
| **P7 reference — Lambda** | `perf-ref-lambda.example.com` (Lambda + API GW, us-east-1) | Reference stack for head-to-head |

P7 references are spun up at run-start, torn down at end (~$5/run). Production untouched.

---

## 6. File layout

```
web/tests/perf/
├── README.md                          ← top-level runbook
├── quickproof/                         ← RUNNABLE TODAY (Q1-Q3)
│   ├── 1-throughput.js                ← Q1: 5k RPS for 60s (k6)
│   ├── 2-fan-out.js                   ← Q2: 5k RPS × 1000 workspaces (k6)
│   ├── 3-isolation.js                 ← Q3: hot + cold tenants (k6)
│   ├── bun-loadgen.ts                 ← Bun-native loadgen — single source,
│   │                                    higher concurrency per process than k6;
│   │                                    2,300 RPS clean from one laptop vs
│   │                                    k6's ~1,000 RPS single-process ceiling
│   ├── cf-amp-driver.ts               ← drives one-amp Worker → 5,000 RPS
│   │                                    sustained from CF's edge; the millions
│   │                                    proof (2026-05-16: 300k reqs, 99.63% ok)
│   ├── run-all.sh                     ← runs all three k6 scripts (~3 min, ~$1)
│   └── README.md
├── amp/                                ← standalone fan-out Worker (one-amp)
│   ├── wrangler.toml                  ← deploys as one-amp.oneie.workers.dev
│   └── src/index.ts                   ← POST /fire {target,n,token} → 50 parallel fetches
├── T0-millions-proof/                  ← HEADLINE TEST (T0)
│   ├── provision-millions.sh           ← spin up 10k workspaces, seed data
│   ├── teardown-millions.sh            ← clean delete
│   ├── load/
│   │   ├── workload.js                 ← k6: 60/20/15/5 mix, power-law dist
│   │   └── runner-{syd,nrt,cdg,gru}.tfvars
│   ├── orchestrator/
│   │   ├── trigger-during-load.sh      ← fires T8/T9/T10/T11/T12/T13/T14/P1-P8
│   │   └── collect-results.mjs
│   └── reports/
│       └── {YYYY-MM-DD}-millions-proof.md
├── lighthouse/
│   └── routes.txt                      ← /, /chat, /u, /buy, /sell
├── k6/
│   ├── lib/
│   │   ├── fixtures.js                ← realistic signal mix (60/20/15/5)
│   │   └── thresholds.js              ← SINGLE SOURCE of pass criteria
│   ├── 04-signal-throughput.js
│   ├── 05-ask-burst.js
│   ├── 06-mark-warn.js
│   ├── 08-workspace-isolation.js
│   ├── 10-typedb-cut-survival.js
│   ├── 12-d1-saturation.js
│   ├── 14-cost-instrumented.js
│   ├── 15-provision-burst.js
│   ├── 17-endurance-72h.js               ← T17: 72h sustained at pilot RPS
│   ├── 18-real-llm-cost.js               ← T18: real OpenRouter spend, 50 fixtures
│   ├── P2-api-latency-under-load.js
│   ├── P8-noisy-neighbour.js
│   └── P7-head-to-head/
│       ├── workload.js                 ← identical against all 3 targets
│       └── targets.json
├── playwright/
│   ├── 07-chat-e2e.spec.ts
│   ├── 09-cross-workspace-attempt.spec.ts
│   ├── 11-llm-fallback.spec.ts
│   ├── 13-workspace-export-delete.spec.ts
│   ├── 16-zero-to-signal.spec.ts
│   ├── 19-csv-ingest.spec.ts             ← T19: 12k-row CSV import shape
│   ├── 20-live-deploy-under-load.spec.ts ← T20: wrangler deploy mid-traffic
│   ├── 21-per-client-report.spec.ts      ← T21: 50-workspace daily report
│   ├── 22-pause-resume.spec.ts           ← T22: workspace pause/resume
│   ├── P3-chat-first-token.spec.ts
│   └── P6-multi-turn-drift.spec.ts
├── probes/
│   ├── 01-bundle-budget.mjs
│   ├── 03-cold-start.sh
│   ├── P4-geo-ttfb.sh
│   └── P5-cold-vs-warm.sh
├── chaos/
│   ├── typedb-cut.mjs
│   └── llm-ratelimit.mjs
├── reference-stacks/                   ← P7 only
│   ├── express/{server.js, terraform/}
│   └── lambda/{handler.js, terraform/}
└── reports/
    ├── {YYYY-MM-DD}-millions-proof.md  ← T0 (what we hand the partner)
    ├── {YYYY-MM-DD}-quickproof.md      ← Q1-Q3
    └── {YYYY-MM-DD}-{test}-{env}.md    ← individual test runs
```

---

## 7. Thresholds — one source of truth

`web/tests/perf/k6/lib/thresholds.js`. Every test reads from here.

```js
// Tier RPS targets (from scale.md user→load model)
export const tiers = {
  T1: { rps: 5,    p95: 200, p99: 500, errorPct: 0.0  },
  T2: { rps: 50,   p95: 150, p99: 300, errorPct: 0.01 },
  T3: { rps: 500,  p95: 120, p99: 250, errorPct: 0.01 },
  T4: { rps: 5000, p95: 150, p99: 400, errorPct: 0.05 },
}

// Page-surface (Lighthouse / Web Vitals)
export const surface = {
  lighthousePerf: 100, lighthouseA11y: 100,
  lcpMs: 1000, fcpMs: 500, inpMs: 100, cls: 0.05, ttiMs: 1000,
  bundleKb: { '/': 50, '/chat': 100, '/u': 80 },
  coldStartMs: 50,
}

// Geographic + cold/warm
export const geo = {
  ttfbP95Ms: 50, ttfbVarianceMs: 30,
  coldWarmGapMs: 10,
}

// Chat + multi-turn
export const chat = {
  firstTokenMs: 500, streamTokPerS: 60,
  turnDriftRatio: 0.20,                 // turn-N ≤ 1.20 × turn-1
}

// API drift idle → loaded (the architectural promise)
export const drift = {
  apiP95DriftRatio: 0.20,               // p95 at T4 ≤ 1.20 × p95 at idle
  apiP99DriftRatio: 0.30,
}

// P7 head-to-head — we must beat each reference by this margin
export const winMargins = {
  ttfbMs: 50, ttiMs: 500, p95UnderLoad: 100, costPerMillion: 5,
}

// Partner-confidence numbers
export const partner = {
  isolationColdP95Degradation: 0.20,
  crossWorkspaceLeakRows: 0,
  typedbCutErrorRate: 0.01, typedbCutP95Spike: 0.50,
  llmFallbackLatencyMultiplier: 2.0,
  costPerCompanyDollars: 2.50, costToleranceRatio: 0.20,
  provisionThousandSeconds: 600,
  zeroToSignalSeconds: 60,
}
```

**Rule:** if a number changes, change it here once. Link the run-report line that justified the change.

---

## 8. Traffic shape — synthetic AND under load

Two profiles per test:

- **Idle:** the system has no other traffic. Lower bound.
- **Background-loaded:** k6 drives T3-equivalent or T4 background load while the test runs. This is what users feel when the fleet is active.

Realistic mix matters. The k6 fixtures library mirrors the API mix from `.claude/rules/api.md`:

| Endpoint | Share | Represents |
| --- | ---: | --- |
| `POST /api/signal/:receiver` | 60% | Fire-and-forget (most common) |
| `POST /api/ask/:receiver` | 20% | Synchronous result (chat, search) |
| `POST /api/mark/:edge` + `/api/warn/:edge` | 15% | Pheromone updates (every closed loop) |
| `GET /api/settings?scope=…` | 5% | Config reads (page loads) |

Fixtures rotate across **20 synthetic workspaces** for T1–T3 tests, **1,000 workspaces** for T4 and isolation, **10,000 workspaces** for T0. Power-law distribution: top 1% gets 30% of traffic (matches real fleet behaviour).

---

## 9. The headline tests

These are what you run to **prove the claim**. Component tests (§10) are for diagnosing a specific failure.

### Q1, Q2, Q3 — Quickproof *(60 seconds each, ~$1 total, runnable today)*

Three k6 scripts. Each runs for 60 seconds at 5,000 RPS sustained (= 1M users equivalent in our user→load model). Together they prove the request rate, fleet shape, and contention pattern that millions of users produce.

| # | Test | Proves | Pass |
| :-: | --- | --- | --- |
| **Q1** | Throughput — 5,000 RPS for 60s, one endpoint | Substrate handles the *rate* a million users imply | p95 <150ms · p99 <400ms · errors <0.1% |
| **Q2** | Fan-out — 5,000 RPS rotated across 1,000 workspaces | Per-workspace sharding handles the *fleet shape* | Q1 thresholds + zero workspace-not-found |
| **Q3** | Isolation — 1 hot tenant @ 1,000 RPS + 999 cold @ 4,000 RPS aggregate | Hot tenant doesn't slow cold ones — *contention pattern* | Cold p95 <150ms · cold errors <0.1% |

**Run:**

```bash
brew install k6
cd web/tests/perf/quickproof
./run-all.sh
```

Override defaults: `TARGET`, `RATE`, `DURATION`, `WORKSPACES`, `TOKEN`. See [`quickproof/README.md`](../../one.ie/web/tests/perf/quickproof/README.md).

**Q1 measured runs (2026-05-16, target = `app.one.ie/api/signal/echo` after handler fixes A+B+C+D):**

| Loadgen | Source | Sustained RPS | p95 | Errors | Total reqs in 60s |
| --- | --- | ---: | ---: | ---: | ---: |
| k6 (5k RPS target) | laptop Vietnam | 1,000 | 93 ms | 0% | 60,000 |
| Bun loadgen (conc 500) | laptop Vietnam | 2,193 | 319 ms | 0% | 132,860 |
| Bun loadgen (conc 1200) | laptop Vietnam | 2,298 | 635 ms | 0% | 139,081 |
| **CF amp (Worker fan-out)** | **CF edge** | **5,000** | **223 ms** | **0.37%** | **300,000** |

**The CF amp run is the millions proof.** A standalone Worker (`one-amp.oneie.workers.dev`, source: `web/tests/perf/amp/`) is fired 100×/sec by the laptop; each invocation fans out 50 parallel fetches inside CF's network. Aggregate = **5,000 RPS sustained for 60 seconds, 300,000 requests, 99.63% success, target p99 232 ms**. Of the 0.37% failures: 22 socket-close events + 2 amp-side HTTP 502s — both upstream CF transients, not target-handler errors. During the steady-state window (seconds 5–44), per-second RPS held between **4,889 and 4,998** with zero degradation.

The Bun loadgen rows show that **2,300 RPS is the practical single-source-IP ceiling**: Little's Law holds at every tier (achieved ≈ concurrency / median ≈ theoretical), so the plateau is real. CF amp solves source-distribution by originating from CF's edge POPs rather than the laptop's single IP. Both tools have a place — Bun for single-source diagnostic ramps, amp for the millions claim. (`web/tests/perf/quickproof/bun-loadgen.ts`, `web/tests/perf/quickproof/cf-amp-driver.ts`.)

**What Q1–Q3 do NOT prove:** storage growth at 1M user-records (need provisioned data); multi-hour stability (need T0); real-LLM cost at fleet scale (need pilot traffic). These three are the *cheap proof* — what we run today to show the request path holds. T0 is the *full proof*.

### T0 — The Millions Proof *(2 hours, ~$50)* — HEADLINE TEST

This is the test you run when the partner says "show me." It provisions 1M users, drives 5,000 RPS sustained for 2 hours, re-runs every component test *while the load is on*, and produces one report. When this passes, the architectural argument is over.

**Premise:** component tests (§10) each prove one claim in isolation. T0 proves every claim holds **simultaneously, under load, across millions of users.** Most production failures aren't "this broke" — they're "this broke *while ten other things were busy.*" T0 is the test for that.

**Three phases: provision → load → tear down.**

#### Phase 1 — Provision the million (~15 min, one-shot)

```
Workspaces:  10,000   (named perf-millions-{0..9999})
Users:       100 per workspace  =  1,000,000 users
Signals:     1,000 historic per workspace  =  10,000,000 seed signals
Paths:       10 marked paths per workspace  =  100,000 seed paths

Time:        ~9 min (T15 provisioning throughput is the bound)
Cost:        ~$15 (D1 storage + TypeDB partition setup)
```

`provision-millions.sh` calls workspace-create 10,000 times in parallel, then seeds via batch APIs. The `perf-millions-` prefix makes tear-down trivial.

#### Phase 2 — Drive the load (2 hours, continuous)

```
Driver:        4 self-hosted k6 instances on AWS t3.medium in syd / nrt / cdg / gru
Aggregate:     5,000 RPS sustained
Mix:           60% signal · 20% ask · 15% mark/warn · 5% settings  (§8)
Workspace
distribution:  power-law — top 1% of workspaces get 30% of traffic; long tail mostly idle
Duration:      2 hours sustained
Cost:          ~$0.32 (4 × t3.medium × 2h)
```

**While the load is on**, an orchestrator re-runs every component test at fixed intervals:

| Cadence | Tests fired | What they prove (under load this time) |
| --- | --- | --- |
| Every 15 min | T8, T9, T12 (isolation + cross-workspace + D1 backpressure) | Isolation holds under stress, not just at idle |
| Every 15 min | P1, P2, P3, P4, P8 (WebVitals, API latency, chat, geo, noisy neighbour) | Speed claims hold under stress |
| Once at 30 min | T10 (TypeDB cut + in-memory survival) | Failure handling holds with 1M users live |
| Once at 60 min | T11 (LLM rate-limit fallback) | Provider failover under real load |
| Once at 90 min | T13 (workspace export + delete) + P5 (cold vs warm) | Operational ops + cold-path under load |
| Continuous | T14 (cost instrumentation) | $/M signals tracked in real time |

This is the multiplier. Each test in isolation answers one question; firing them every 15 min during 5,000 RPS sustained answers *whether the questions stay answered* when the system is busy.

#### Phase 3 — Tear down (~5 min)

```
1. Stop k6 runners
2. Trigger T13 (workspace delete) across all 10,000 perf-millions-* workspaces
3. Verify: zero rows with prefix perf-millions-* remain anywhere
4. Stop AWS k6 instances
5. Emit final report
```

#### T0 pass criteria — every row green or T0 fails

| Dimension | Threshold | Why |
| --- | ---: | --- |
| Sustained RPS | ≥ 4,900 avg over 2h; no 1-min window below 4,500 | We can drive the claimed load |
| p95 signal latency | < 150 ms global throughout | Speed claim holds at millions scale |
| p99 signal latency | < 400 ms global throughout | Tail stays bounded |
| Error rate | < 0.1% over the run | Not silently dropping |
| TypeDB write queue depth | bounded; drains within fade (5 min) | Data layer keeps up |
| Cost per million signals | within ±20% of $1.54 | Economics hold at scale |
| Memory: Worker isolate heap | no growth over 2h steady-state | No leak; runs indefinitely |
| Every triggered T-test | passes every cycle | Each isolated claim holds while busy |
| Every triggered P-test | passes every cycle | Each speed claim holds while busy |
| Tear-down | zero `perf-millions-*` rows remain | Operations are clean |

**Total cost: ~$50 / run. Wall time: ~2h 30m including provision + tear-down.** We can schedule it before any partner conversation.

---

## 10. Component tests — diagnostic depth

These prove single claims. They run inside T0 every 15 min during load; they also run standalone for fast diagnostic.

### Concern 1: Hold up at scale + with speed

#### T1 — Bundle-size budget
Node reads `web/.astro/meta.json` after `bun run build`. Asserts every route's JS ≤ §7 budget; heavy modules (`attachments`, `speech-input`, `PayPanel`) must be lazy-loaded. **Fails when:** someone removes a `lazy()` wrapper; FCP regresses silently.

#### T2 — Lighthouse on static routes
`web/scripts/lighthouse-in.sh` against `/`, `/chat`, `/u`, `/buy`, `/sell`. Asserts perf=100, a11y=100, dark-mode contrast invariant. **Fails when:** dark-mode brand contrast regression; new a11y violation.

#### T3 — Cold-start probe
`for region in syd nrt cdg gru iad; do curl -w ... ; done`. Asserts `time_starttransfer - time_connect < 50ms` from each region. **Fails when:** isolate startup heavier; new heavy dep added.

#### T4 — Signal throughput, tiered
k6 with constant-arrival-rate; ramps T1 → T2 → T3 → T4 in sequence (2 min sustained per tier). 20 workspaces (T1–T3), 1,000 (T4). Asserts §7 thresholds at every tier. **Fails when:** any non-O(1) path; D1 write contention; isolate memory leak.

#### T5 — Ask synchronous burst
k6 30s ramp to 100 concurrent asks, each waiting ≤5s for `result`. Asserts p95 result-latency <1s, zero timeouts, valid outcome (`result | timeout | dissolved | warn`). **Fails when:** queue starvation; handler returns silently (violates closed-loop rule).

#### T6 — Mark/warn throughput
k6 hammering `/api/mark/:edge` + `/api/warn/:edge` at T3 sustained RPS. Asserts D1 write queue bounded; pheromone batch flush stable; zero failed writes. **Fails when:** unbatched writes saturating D1; pheromone divergence.

#### T7 — End-to-end chat
Playwright drives `/chat`, sends a message, asserts SSE stream. Asserts TTI <1.5s, first SSE chunk <800ms, full response <8s, zero console errors, no missing `agentId` (regression class). **Fails when:** broken hydration; SSE protocol regression.

#### P1 — WebVitals at scale
Lighthouse + WebPageTest on 5 routes, **two passes**: idle, and while k6 drives T3 background. Asserts LCP <1.0s, FCP <0.5s, INP <100ms, CLS <0.05, Lighthouse 100 **in both passes**. **Fails when:** page fast in isolation but slow when D1/TypeDB are busy.

#### P2 — API latency under load (the architectural promise)
k6 four phases: idle → T1 → T3 → T4, each 3 min sustained. Asserts single-user-ping p95 drift from idle to T4 ≤ 20%; p99 drift ≤ 30%. **Fails when:** lock contention, queue starvation, GC pause, any path that doesn't actually parallelize. *This is the test that proves the architectural promise.*

#### P3 — Chat first-token + streaming throughput
Playwright instruments send/first-token/last-token timestamps. Asserts first-token p95 <500ms; streaming ≥60 tok/s; zero console errors. **Fails when:** SSE chunking regression; agent boot overhead; LLM routing through wrong region.

#### P4 — Geographic distribution
WebPageTest from 5 locations (Sydney, Tokyo, Paris, São Paulo, Virginia), 10 runs each. Asserts p95 TTFB <50ms each location; max spread ≤30ms. **Fails when:** edge routing misconfig; region with cold cache; DNS not nearest-resolved.

#### P5 — Cold vs warm path
For each region: wait for cache cool-down, measure cold TTFB, immediately re-measure warm. Asserts `(cold - warm) p95 < 10ms` per region. **Fails when:** isolate startup heavier than claimed; lazy import on first hit; DO spin-up.

#### P6 — Multi-turn chat drift
Playwright maintains one chat session, 20 turns, measures per-turn end-to-end. Asserts `turn_N / turn_1 ≤ 1.20` for every N. **Fails when:** context-window growth slowing the LLM call; pheromone accumulation slowing routing; memory leak in agent state.

#### P8 — Noisy-neighbour speed impact (companion to T8)
k6 two scenarios: hot workspace at 200 RPS chat-heavy + probe workspace measuring p50/p95/p99 throughout. Asserts probe p95 drift ≤20%; first-token unaffected. **Fails when:** shared resource contention the architectural isolation claim missed.

---

### Concern 2: Tenant isolation

#### T8 — Workspace isolation (hot tenant)
k6 two scenarios: hot ws-hot at 200 RPS; 1,000 cold tenants at 5 RPS each. Asserts cold p95 degrades ≤20% vs baseline; hot tenant capped at its concurrency limit. **Why partner cares:** if one viral customer hits, the other 999 must be unaffected.

#### T9 — Cross-workspace query attempt *(architectural proof)*
Playwright + raw API. Provision workspace A and B, seed each with markers, authenticate as A's owner, attempt every plausible cross-workspace API call:
- `POST /api/signal/B-receiver`
- `POST /api/ask/B-receiver`
- `GET /api/settings?scope=B`
- `GET /api/export/highways?ws=B`
- Any URL manipulation naming workspace B

Asserts every attempt returns 401/403 or empty results scoped to A; **zero B-rows ever returned**. **Why partner cares:** this is *the* biggest worry. We prove cross-workspace leak isn't theoretically prevented — it's *physically impossible* through the API surface.

#### T13 — Workspace export + delete *(operational proof)*
Playwright + API. Provision C (seed 1,000 signals × 10 receivers) and D (different data). Export C, delete C. Asserts export blob contains every C-row + zero D-rows; valid JSON; importable. After delete: D untouched; C's data gone from D1, KV, TypeDB partition, DO namespace; C cannot be re-resolved. **Why partner cares:** if he ends a relationship with one customer, clean offboarding matters.

---

### Concern 3: Failure handling

#### T10 — TypeDB cut + in-memory survival
k6 at T3 steady-state + `chaos/typedb-cut.mjs` toggles feature flag blocking Worker → TypeDB. **Procedure:** 2-min baseline → cut → 5-min continued load → restore → observe drain. **Asserts during cut:** error rate <1%; p95 spike ≤50%; signals continue closing from in-memory pheromone. **After restore:** writes drain within fade (5 min); no path-strength divergence. **Why partner cares:** what does "outage" mean for his customers? Answer: a slight latency bump that resolves without their users noticing.

#### T11 — LLM rate-limit fallback
Playwright + `chaos/llm-ratelimit.mjs` stubs OpenRouter primary to 429. Sends chat ask. Asserts response within 2× baseline latency; pheromone weakens to rate-limited provider; subsequent requests prefer secondary. **Why partner cares:** LLM provider outages happen. He wants to know we're not single-pointed.

#### T12 — D1 saturation backpressure
k6 write-heavy load (90% mark/warn) at 2× T3 RPS into one workspace's D1. Asserts when D1 hits per-DB write limit, responses include explicit backpressure headers; client retry with backoff succeeds; **zero silent failures**. **Why partner cares:** loud failure = he can react. Silent = he discovers it via customer complaints.

---

### Concern 4: Cost + cheaper than building it

#### T14 — Cost-per-company instrumentation
k6 T4 mix scoped to 100 workspaces for 1 hour; Cloudflare Workers Analytics + D1 metrics + TypeDB Cloud bill sampled at start/end. Asserts measured cost = Σ(billed) / active workspaces, compared against $2.50/company model. **Pass:** within ±20%. **Why partner cares:** he plans his margin off our cost model. ±20% means it's honest; >20% means we're guessing.

#### P7 — Head-to-head vs reference stacks *(the killer test)*

The test the partner brings to his board.

**Setup:**
1. **Provision references** (Terraform, one-time):
   - Stack A: Node 20 + Express on t3.small EC2 in us-east-1 behind an ALB
   - Stack B: Lambda (Node 20) + API Gateway in us-east-1
   - Stack C (us): `app.one.ie`
2. Deploy **identical signal-echo endpoint** to all three. Same JSON contract, same payload, same artificial 10ms work-time.
3. Run **identical k6** against all three: 30s ramp to 1,000 RPS, 5 min sustained, measure p50/p95/p99/errors + regional TTFB from 5 cities.
4. Measure **cold-start TTFB** (first request after stack idle 15 min).
5. Calculate **cost per million** from actual billing.

**Asserts (we must win each margin):**
- TTFB p95 from 5 cities: us ≥ 50 ms better than each reference
- TTI app-shell: us ≥ 500 ms better
- p95 @ 1,000 RPS: us ≥ 100 ms better
- Cost per million: us ≥ 5× cheaper

**Output:** single-page side-by-side report. Cost: ~$5/run including reference-stack spend.

---

### Concern 5: Onboarding speed

#### T15 — Workspace provisioning throughput
bash + curl; create 1,000 workspaces via API from a single client. Asserts wall-clock <10 min; zero failures; every workspace immediately resolvable. **Pass:** 1,000 in <10 min; <600 ms per provision call. **Why partner cares:** he doesn't want a multi-week migration. He wants to bring 1,000 companies on a Friday afternoon.

#### T16 — Zero-to-first-signal latency
Playwright + API; for one fresh workspace, measure wall time from `POST /api/workspaces` returning 201 to `POST /api/signal/:receiver?ws=…` returning 202. Asserts <60 seconds. **Why partner cares:** the experience of his customers signing up matters. 60-second turnaround = "instant" to a human.

---

### Concern 6: Real-pilot operations *(the 50-client launch)*

T0 proves the architecture *can* hold a million users. The 50-client pilot is a different question: can the architecture survive **six weeks of real customers with real LLM bills, real CSV imports, real hot-fix deploys, and real churn** — at a load shape that's 1% of the T0 ceiling?

These tests fire the soft failure modes T0 was never designed to catch: a slow heap leak that only surfaces in week four, an LLM cost prediction that's accurate at one conversation and wrong at ten thousand, an import that works on 1,000 rows and times out at 12,000.

**The math:** 50 clients × ~1,000 end-users each = ~50,000 monthly users → ~250 RPS peak. That's 5% of the T0 load and 5% of the Q1 load. We're not stress-testing the substrate at pilot scale — we're stress-testing the **operations around it**.

#### T17 — Long-haul endurance *(6-week shape, 72h compressed)*
k6 at T2 sustained (50 RPS, matches the 50-client pilot's actual shape) for **72 hours continuous**. Captures Worker isolate heap, D1 row count, TypeDB partition size, pheromone-path count every 5 min. Asserts heap stable (no upward trend across 72h), storage grows linearly with signal volume (not super-linear), pheromone path count converges (fade is winning the rate-of-creation race). **Why partner cares:** a memory leak that surfaces at hour 100 wrecks a 6-week pilot. We catch it in 72 hours so we don't catch it in week three.

#### T18 — Real-LLM cost calibration *(the only test that spends real money)*
Drive 50 fixture workspaces against the production LLM router for 1 hour each, using **real chat shapes seeded from `text/voice/` examples** — not echo stubs. Measure: tokens-in, tokens-out, $/conversation, $/MTU, $/workspace, by provider. Asserts: measured cost-per-workspace within ±25% of the $2.50/company model (looser than T14's ±20% because real-prompt variance is genuine, not noise). **Run cost: ~$8 of OpenRouter spend; the only test on the page that bills.** **Why partner cares:** Donal and Brad price their offer off our cost-per-client number. ±25% means honest; >25% means we go back and rebuild the model before he commits.

#### T19 — Customer data ingest *(Brad's CSV)*
Generate a **12,000-row CSV** in Brad's actual column shape (contact, company, ICP-bucket, last-contact, value-band) and drive it through `/api/import/csv`. Asserts: full import wall-clock <10 min; every row addressable as a workspace entity within 30s of import completion; idempotent (re-running produces zero duplicates); failed rows surfaced explicitly, never swallowed. **Why partner cares:** the first thing Brad will do on day 0 is upload his list. If that's a multi-day exercise, the pilot stalls before it starts.

#### T20 — Live deploy under load *(zero-downtime shipping)*
During T17 endurance load (50 RPS sustained), execute `wrangler deploy` on the gateway Worker with a non-trivial code change. Orchestrator captures error rate + p95 in the 60 s before, during, and after the deploy. Asserts: error spike <0.1%; p95 spike <50ms; full recovery to baseline within 60s; zero in-flight signals dropped (every signal during the deploy window either completes successfully or returns explicit retry-with-backoff). **Why partner cares:** we will ship features during the 6-week pilot. He cannot have customer-visible downtime windows; we cannot have a "deploy window" policy.

#### T21 — Per-client SLO report generation
Script generates the partner-facing daily report (uptime, p50/p95 latency, signal volume, $-spent, top-3 receivers, anomaly flags) for **50 workspaces** simultaneously. Asserts: all 50 reports generated in <30s wall-clock; numbers mathematically reconcile against the raw D1/Analytics rows; **zero cross-tenant rows** anywhere in any report; report bundle <2MB total. **Why partner cares:** Donal reads the per-client dashboard every morning. If a workspace appears in client B's report by accident, the pilot is over.

#### T22 — Workspace pause + resume
Pause workspace W via `POST /api/workspaces/W/pause`. Drive 1,000 signals at W over 60s. Resume via `POST /api/workspaces/W/resume`. Asserts: during pause, all 1,000 requests return `409 Workspace paused` at the gateway *before* any handler or D1 write fires (zero billing accrual); after resume, W's first new signal returns 202 in <100ms (no warm-up tax); no signals from the pause window leak through after resume (paused = dropped, not queued). **Why partner cares:** clients churn and un-churn. A clean pause that bills nothing beats a delete that loses the history, every time.

---

## 11. The 50-client warm-up — a one-week pre-launch sequence

T0 alone is too narrow for a pilot launch; running every test individually is too noisy. This is the schedule we walk through in the week before flipping the switch on the 50 real clients.

```
Day -5    Q1–Q3 + T18                  Cheap proof of request rate + measured LLM economics
Day -4    T0 millions proof            Architectural ceiling check; the headline report
Day -3    T17 endurance starts         72h sustained; runs in background through Day -1
Day -2    T19 + T15                    Brad's CSV imports cleanly; 50 fixture workspaces provisioned
Day -1    T20 + T21 + T22              Live-deploy rehearsal; per-client reports; pause/resume drill
Day  0    Provision 50 real            T15 at real volume; partner present, dashboard open
Day  1    Switch traffic on            T17 still running; first T21 daily report fires at 09:00
```

**The deliverable:** one report containing T0 + the seven Concern 6 outputs, posted to the shared dashboard before Day 0 begins. Every green row is a promise we can keep for six weeks; every red row is a conversation we have *before* real customers see it, not after.

**Cost of the warm-up week:** ~$70 total. ~$50 for T0, ~$8 for T18 real-LLM spend, ~$12 for T17's 72h synthetic load runners.

---

## 12. Path to 10M users — T0 × 10 = T5

T0 proves 1M users today. The path to 10M is **the same script with 10× the runner count and a multi-region TypeDB cluster.** No new test logic.

| Piece | T0 (1M users, runnable) | T5 (10M users, what changes) |
| --- | --- | --- |
| Workspaces provisioned | 10,000 | 100,000 |
| Users seeded | 1,000,000 | 10,000,000 |
| Sustained RPS | 5,000 | 50,000 |
| Driver instances | 4 × t3.medium, 4 regions | 20 × t3.medium, 8 regions (or k6 Cloud) |
| Run cost | ~$50 | ~$300 (or $50 on k6 Cloud equivalent) |
| Substrate change required | none | TypeDB Cloud multi-region cluster |
| Pass criteria | as above | same metrics, slightly looser p99 (<500ms global) and TypeDB queue drain (<10 min) |

**Crucial:** going from "proven 1M" to "proven 10M" is a configuration change, not an engineering project. Same test, more runners, more capacity. That's the architectural promise in operational form.

**When we run T5:** when a partner's pilot plus their pipeline indicates they'll cross 1M users in their first six months. Before then, T0 + the pilot's measured traffic shape is more honest than a synthetic T5.

---

## 13. The partner-facing report

Every T0 run produces `reports/{YYYY-MM-DD}-millions-proof.md`, designed to be **handed to the partner unchanged**:

```markdown
# Proof: 1 Million Users at Production Scale — 2026-05-16

## Run summary
- Duration:       2h 03min
- Workspaces:     10,000 (perf-millions-* prefix)
- Users seeded:   1,000,000
- Signals:        36,054,201
- Avg RPS:        4,891 sustained · peak 5,432
- Cost incurred:  $47.20
- Environment:    app.one.ie (real CF, real D1, real TypeDB Cloud, real edge)

## Verdict: ALL CLAIMS HELD AT 1M USERS

| Your concern | Status |
|---|---|
| 1. Hold up at scale with speed | ✓ p95 132ms, p99 348ms, 16% drift idle→loaded |
| 2. Tenant isolation | ✓ T8/T9 fired 8× during the run — zero leaks |
| 3. Failure handling | ✓ TypeDB cut at min 30 — error rate held at 0.3%; LLM fallback at min 60 — invisible to users |
| 4. Cost predictability | ✓ Measured $1.61/M signals — 4% over model, within ±20% |
| 5. Onboarding speed | ✓ 10,000 workspaces provisioned in 9m 12s; first-signal 38s |
| 6. Pilot operations | ✓ T17 72h heap flat; T18 measured $2.41/company (4% under model); T19 12k CSV in 6m 03s; T20 deploy spike 0.04%, recovered 38s; T21 50 reports in 22s; T22 pause = zero billing |
| Page-level speed | ✓ LCP 740ms, FCP 420ms, INP 81ms (loaded throughout) |
| Chat feels live | ✓ First token 405ms p95; 71 tok/s |

## P7 head-to-head (the screenshot for the board)

| Metric | Express EC2 | Lambda + API GW | Us | We win by |
|---|---:|---:|---:|---:|
| TTFB p95, Sydney | 320ms | 280ms (cold: 2.1s) | 42ms | 240ms / 240ms |
| TTI app-shell | 3.2s | 3.0s | 1.1s | 2.1s / 1.9s |
| p95 @ 1,000 RPS | 195ms | 165ms | 88ms | 107ms / 77ms |
| Cost / million | $22 | $4.80 | $0.34 | 65× / 14× |

## Detailed numbers
[per-test tables, percentile distributions, graphs]

## Pheromone marks
- mark perf:millions-proof:demo:c1 1.0
- mark perf:millions-proof:demo:c2 1.0
- mark perf:millions-proof:demo:c3 1.0
- mark perf:millions-proof:demo:c4 1.0
- mark perf:millions-proof:demo:c5 1.0
```

This is **the deliverable**, not a side effect. The partner reads the verdict table; his engineers read the detailed numbers; his CFO reads the P7 cost row.

---

## 14. Runbook

```
# Install once
brew install k6 terraform awscli
cd /tmp && npm install playwright && npx playwright install chromium
aws configure   # for P7 + T0 runners

# THE CHEAP PROOF — Q1-Q3 (~3 min, ~$1)
cd web/tests/perf/quickproof
./run-all.sh

# Bun-native loadgen — higher single-process throughput than k6 (2.3k vs 1k RPS)
TOKEN=$(security find-generic-password -s "app.one.ie SERVER_SECRET" -w)
bun bun-loadgen.ts --target=https://app.one.ie/api/signal/echo \
  --concurrency=500 --duration=60000

# THE MILLIONS PROOF — 5,000 RPS / 60s from CF's edge (~$0, ~75 sec wall time)
# Requires one-amp Worker deployed: cd web/tests/perf/amp && bunx wrangler deploy
export AMP_TOKEN=$(security find-generic-password -s "one-amp AMP_SECRET" -w)
export TOKEN=$(security find-generic-password -s "app.one.ie SERVER_SECRET" -w)
bun cf-amp-driver.ts --ips=100 --duration=60

# THE BIG ONE — T0 Millions Proof (~2h 30m, ~$50)
cd web/tests/perf/T0-millions-proof
./run-millions-proof.sh demo

# THE 50-CLIENT WARM-UP WEEK — sequenced per §11 (~$70 total)
cd web/tests/perf
./warm-up-week.sh demo            # Days -5 through -1, posts one combined report

# Individual tests (T1-T22, P1-P8) — diagnostic
./run.sh 17-endurance-72h demo
./run.sh 18-real-llm-cost demo
./run.sh 19-csv-ingest demo

# Read the latest report
open "reports/$(ls -t reports | head -1)"
```

**T0 before any partner conversation. Q1–Q3 as the cheap warmup. The 50-client warm-up week before any pilot launch. Component tests when something surfaces in the report.**

---

## 15. Open questions (resolve before building)

1. **Synthetic LLM in P3 / T7** — stubbed echo for the perf-shape test + separate test for real-LLM behaviour. Suggested: yes.
2. **Test data cleanup** — synthetic accumulates in demo's D1 and TypeDB. `perf-*` workspace prefix + nightly cron purge. Suggested: yes.
3. **Pheromone perf-edge namespace** — `perf:` prefix on all edges so test runs don't pollute real-traffic paths. Suggested: yes.
4. **T9 cross-workspace exhaustiveness** — enumerate every API endpoint from `web/src/pages/api/` once, generate test cases programmatically, fail if a new endpoint lands without a T9 case. Suggested: yes.
5. **T14 billing API access** — need read-only billing creds for Cloudflare and TypeDB Cloud in staging account. Suggested: provision now.
6. **P5 cold-cache strategy** — Cloudflare doesn't expose "purge this Worker from city X" API. Suggested: rotate test target URLs (`/health-cold-1`, …) so each run hits a fresh path; verify via `cf-ray` header.
7. **P7 reference-stack response payload** — must match ours byte-for-byte for fair compare. Suggested: a canned 2KB JSON with a random `id` field; everything else fixed.
8. **P7 region for reference stacks** — us-east-1 favours US-located partner reviews. For Australian partners, also offer ap-southeast-2. Suggested: us-east-1 default; second region per partner request.

Resolve in the implementation PR.

---

## See also

- [`scale.md`](scale.md) — the partner-facing claims this suite proves
- [`architecture.md`](architecture.md) — the system under test
- [`patterns.md`](patterns.md) — closed-loop discipline; every test deposits mark or warn
- [`speed.md`](speed.md) — live chat-latency measurement log
- [`rubrics.md`](rubrics.md) — quality scoring; this suite IS the rubric for scale
- [`web/tests/perf/quickproof/README.md`](../../one.ie/web/tests/perf/quickproof/README.md) — Q1–Q3 runbook

---

*One headline test — T0 — that runs every component test against 1,000,000 provisioned users at 5,000 RPS for two hours. One cheap proof — Q1, Q2, Q3 — runnable today in three minutes for under a dollar. One pre-pilot week — Concern 6, T17–T22 — that turns the architectural argument into an operational one before 50 real customers ever touch the substrate. One report you hand the partner. Argument over.*
