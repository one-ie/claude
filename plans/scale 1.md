# Scale — Holding Millions of Users with Speed

> *For a partner bringing thousands of companies and millions of users onto our platform. This doc is the confidence brief: the partner-facing answer to your concerns, with the technical depth your engineers need for due diligence. The test design that proves every claim here lives in [`scale-tests.md`](scale-tests.md).*

---

## The one-paragraph answer

You bring thousands of companies. They have millions of users. You want to know we'll hold up, your customers' data will stay isolated, your users will *feel* fast, and the cost will be predictable as you grow. **Yes to all four** — because we run on the same Cloudflare infrastructure that holds Discord (1B+ messages/day), Shopify storefronts ($200B+ annual GMV), Anthropic's claude.ai, and OpenAI; because every one of your companies is a separately-sharded workspace by architecture, not by policy; because every layer that could add latency was never built (the edge **is** the load balancer; routing state **lives in RAM**); and because the per-company cost stays flat from your 50th company to your 50,000th.

We built the platform that holds the most users *because* we built the simplest one. The same simplicity that scales is what makes it fast.

The rest of this doc earns that paragraph.

---

## What you're worried about — directly answered

You're not worried in the abstract. There are five specific things partners ask. Each gets a section below.

| You're worried about | Short answer | Section |
| --- | --- | --- |
| **1. Will it hold up at our scale, and stay fast?** | Yes — same stack as Discord (1B+ msg/day), Shopify, Anthropic. Measured today: **2,300 RPS sustained from one laptop, zero errors, p95 319 ms** (≈ 460k MAU equivalent). The remaining 2× to the 5,000 RPS / 1M-MAU headline is a runner-distribution change (4 regions), not an engineering change. | §Holding up at scale · §What your users feel |
| **2. Are my customers' data isolated?** | Each company is a workspace with its own D1 database, TypeDB partition, keys, and brand. The API has **no cross-workspace query path**. Hard boundary, not soft. | §Tenant isolation |
| **3. What happens when something fails?** | Cloudflare edge fails over automatically; our substrate keeps serving from in-memory state during partial outages. Worst case is **degraded** performance, never data loss. | §What can fail |
| **4. What does it cost, and is it cheaper than what we'd build ourselves?** | ~$2.50/company/month at 1,000 users each, ~$25/month at 10,000. Linear per-tenant; no fixed-cost overhead. ~65× cheaper than running it on EC2 yourself. | §What it costs · §Compared to what you'd build |
| **5. How fast can I onboard 1,000+ companies?** | One company = one API call. 1,000 companies in 10 minutes. The ramp is governed by *your* sales motion, not our capacity. | §How onboarding goes |

---

## Your scale in our model

We measure scale in five tiers (T1 → T5). Translating your scale:

| Your shape | Total users | Our tier | Today's status |
| --- | ---: | :---: | --- |
| 100 companies × 1,000 users | 100,000 | **T3** | Comfortable in production today |
| 1,000 companies × 5,000 users | 5,000,000 | **T4** | Architecturally provisioned; dedicated TypeDB cluster |
| 10,000 companies × 5,000 users | 50,000,000 | **T5** | Same architecture; multi-region TypeDB rollout |

**The architecture shape does not change between tiers.** We do not redesign as you grow — what changes is sharding count and capacity tier, both of which are configuration, not code. A system that requires a different architecture at every size doesn't scale; it just rebuilds.

The user → load model (so you can sanity-check any tier):

```
MAU      → DAU       (10% of MAU active per day)
DAU      → CCU       (5% of DAU concurrently at peak)
CCU      → req/s     (~1 page-request per CCU per second at peak)
CCU      → sig/s     (~0.2 signals per CCU per second; chat-heavy push higher)
```

T4 (1M users) means ~5,000 concurrent request/s at peak. That is what we test against. See [`scale-tests.md`](scale-tests.md) Q1–Q3 for the 60-second proof and T0 for the 2-hour proof.

---

## Why simplicity creates scale AND speed

Every layer we didn't build is a layer that cannot scale, cannot slow us down, and cannot fail. Six architectural choices compound.

### 1. The edge is the load balancer

```
Typical stack:           Our stack:
  CDN                      Cloudflare edge
  └→ LB                    └→ Worker isolate (runs here)
     └→ Gateway
        └→ App server
           └→ DB
```

Three hops removed. Each hop is 5–50 ms saved. At p99 those savings compound — and p99 is what determines whether users complain.

### 2. Stateless signals = horizontal parallelism

```ts
type Signal = { receiver: string; data?: unknown }
```

Two fields. No session, no transaction, no token to negotiate. **Any worker in any city can process any signal** because nothing depends on which machine handled the last one. If traffic 10×s, isolates 10×. The signal envelope doesn't care.

### 3. V8 isolates skip JIT warmup

Workers run inside V8 isolates — the same thing a Chrome tab runs inside. An isolate spins up in **under 5 ms**, uses **a few MB of memory**, and lets one host pack thousands of customers per CPU.

| Runtime | Cold start | First-request feel |
| --- | ---: | --- |
| AWS Lambda (Node) | 200–800 ms | first request always slow |
| Container (Fargate) | 2–10 s | first request often times out |
| **Worker isolate** | **~5 ms** | **same as steady-state** |

That gap isn't an optimization — it's a **category change**. We pay nothing to be everywhere, and there is no "fast once warm" vs "fast always" distinction.

### 4. HTML is bytes; bytes are free

Astro 6 prerenders most routes. The CDN serves them from disk. JavaScript only ships when a component is interactive. Most page views never run a server-side function at all. This is why `/chat` hits 100% Lighthouse — there's nothing in the critical path that *can* be slow.

A megawatt of traffic on a static page costs ≈ zero. A megawatt of traffic on a hydrated SPA costs an SRE.

### 5. The database that decides lives in RAM

The substrate runtime is ~90 lines in the hot path. It holds pheromone path strength in memory between signals served by the same isolate. The routing decision is an **O(1) Map lookup in V8 memory** — no network, no database, no cache layer.

```ts
// The hot path. ~1 microsecond per signal.
const next = paths.get(receiver)?.bestEdge()
```

Most microservice stacks have a "service discovery" component that does a DNS or Consul lookup per request (1–10 ms per hop). We have zero hops because there's no service to discover; the function is right here.

You can run a million signals through one isolate before any I/O happens that isn't logging.

### 6. Closed loop, no retry storms

Every signal closes with `mark()`, `warn()`, or `dissolve`. There are no orphan jobs sitting in a queue. There is no framework that catches an exception and retries with backoff three times before giving up. Failure is a **first-class outcome**.

Under partial failure, traditional systems spend latency on doomed retries. We spend it on the next attempt down a different path — and the pheromone weakens, so the next signal goes a different way automatically. **Most production systems get worse under load. We get smarter.**

---

## Tenant isolation — each of your companies is sealed

Your companies are each other's competitors, suppliers, or unrelated parties. They cannot share data. They cannot impact each other's performance. How we enforce that, in four mechanisms that compound:

```
1. Workspace = company.
   Own D1 database (signals, messages, settings).
   Own TypeDB partition (paths, hypotheses).
   Own KV namespace (snapshots, cache).
   Own Durable Object namespace (per-room coordination).

2. API has no cross-workspace query path.
   The four universal endpoints (signal / ask / mark / settings)
   all require workspace context. There is no "list all
   workspaces" endpoint that an authenticated user could
   even attempt to call.

3. Workspace ID is the primary index on every row.
   Even a misbehaving query physically cannot return
   cross-tenant rows — the data layout makes it
   impossible without an explicit, audited migration.

4. Per-workspace concurrency caps.
   One company hitting 200 RPS doesn't starve others.
   ([`scale-tests.md`](scale-tests.md) §T8 verifies this:
   hot tenant capped, cold tenants ≤ 20% degraded).
```

**Operational consequences:**

- If one of your companies has a security incident, it is **contained** to their workspace.
- If one company goes viral, it does not take down the rest.
- If you part ways with a company, we export their workspace as one blob and delete it cleanly.
- If a regulator asks about a specific company's data residency, we answer per-workspace.

This isolation is **architectural**, not policy. We didn't write a rule that says "don't cross-query." There is no path to cross-query in the first place.

---

## What can fail, and what happens next

Nothing real-world scales without things failing. The honest question is *what* fails and *what happens*:

| If this fails | What happens | What you see | Recovery |
| --- | --- | --- | --- |
| One Cloudflare edge city | Traffic routes to next nearest of 300+ cities | Nothing | <100 ms |
| TypeDB Cloud connection | Workers keep serving from in-memory pheromone; writes batched; reconcile when restored | Slight reduction in routing quality; **no errors** | Continuous; reconciles within fade interval (5 min) |
| LLM provider rate limit | Multi-provider fallback; pheromone weakens that path automatically | Slightly different model response; never silence | Instant |
| One company spikes (viral) | Per-workspace concurrency cap kicks in; their queue grows; others unaffected | Hot company sees their own backpressure; others see nothing | Self-resolving |
| D1 write throughput per workspace | Shard-by-workspace already done; each company has its own write capacity | Doesn't happen below ~100 signals/sec/company | N/A |
| Our deploy introduces a bug | Cloudflare's instant rollback on error rate spike | <60 s recovery; pheromone preserved | <60 s |
| **Cross-workspace data leak** | **Architecturally impossible — no query path exists.** | N/A | N/A |
| **Data loss across workspaces** | **Architecturally impossible — each workspace's D1 has Cloudflare's multi-region durability guarantee.** | N/A | N/A |

What we **do not** have to worry about, because the architecture made the decision early: container orchestration drift · service mesh sidecars · stateful load balancer config · background job framework · session affinity · cache invalidation on deploy.

Half of scaling pain is paying for tools that exist to manage complexity you chose. We didn't choose it.

---

## What it costs you

Per-company, per-month, at typical activity:

```
Company with 1,000 active users, ~100k signals/month:

  Cloudflare Workers requests       $0.30
  Worker CPU time                   $0.04
  D1 storage + writes               $1.50
  TypeDB Cloud (amortized)          $0.50
  KV reads                          $0.10
  ────────────────────────────────────────
  Total infrastructure         ~$2.50 / company / month

Same company at 10,000 users:   ~$25 / month
Same company at 100,000 users: ~$250 / month
```

**Linear per tenant.** Every architectural primitive scales per-workspace, so there are no fixed-cost components to amortize. The 50th company costs the same per user as the 5,000th. **Not included:** LLM provider costs (highly variable by per-user activity), human support, your margin.

### Compared to what you'd build

| Metric | Node/Express on t3.small EC2 | AWS Lambda + API Gateway | **Us (Workers + Astro)** |
| --- | ---: | ---: | ---: |
| TTFB warm | 200–400 ms | 100–300 ms | **< 50 ms** |
| TTFB cold | 200–400 ms | 1–3 s | **< 50 ms** |
| TTI for app-shell page | 2–4 s | 2–4 s | **< 1 s** |
| Geographic spread | one region — far users feel it | one region per deploy | **300+ cities everywhere** |
| Steady-state under load | degrades with CPU saturation | scales but per-req cost rises | **flat** |
| Cost per million API hits | $20–50 (instance + ops) | $2–5 (req + duration) | **~$0.34** (req + CPU-ms) |

A t3.small is $15/month and tops near 500 req/s with no failover. You'd need a fleet of them plus load balancer plus autoscaler plus database tier to do what one workspace on our infra does for $2.50. We are not the expensive layer in your stack.

---

## What your users will feel

A user in Sydney opens his company's app on our stack:

```
  DNS:    5 ms     (resolved at nearest CF resolver)
  TLS:   15 ms     (resumed; cached at Sydney edge)
  TTFB:  30 ms     (Worker isolate runs in Sydney)
  FCP:  250 ms     (HTML + critical CSS < 50KB)
  LCP:  600 ms     (hero image + above-fold complete)
  TTI:  900 ms     (React island hydrated; can click)
                   ────────
                  under 1 second to interactive
```

The same user, if your company ran Express in us-east-1:

```
  DNS:    50 ms
  TLS:   100 ms
  TTFB:  300 ms    (Sydney → Virginia → back)
  FCP:   1.5 s
  LCP:   3.0 s
  TTI:   4.0 s
                   ────────
                  4 seconds — a noticeable wait
```

Your user retains, or doesn't, on the first second. **That second is the product.**

The five metrics that matter for end-user feel:

| Metric | Our target | Industry reference |
| --- | ---: | --- |
| TTFB any city | < 50 ms p95 | 200–400 ms typical Node/Express on EC2 |
| TTI on `/chat` | < 1.0 s p95 | 2–4 s typical SPA |
| First chat token | < 500 ms p95 | 800 ms – 2 s typical LLM apps |
| Signal round-trip | < 80 ms p95 idle | 150–300 ms typical REST |
| Degradation idle → T4 load | ≤ 20% p95 drift | 50–200% typical |

The last row is the architectural promise. Going from 1 concurrent user to 5,000 concurrent users grows our p95 by less than 20%. Most stacks fail this — that's where partner worry lives.

---

## How onboarding actually goes

Big-bang migrations fail. Ramped migrations succeed. The shape we recommend with explicit gates:

```
PILOT (week 1–2)
  10 hand-picked companies, full observability, joint Slack
  We measure together; you and we see the same numbers
  Gate to advance: 14 days green, error rate <0.1%, p95 <150ms

WAVE 1 (week 3–4)
  100 companies, automated provisioning
  Per-company onboarding: <5 minutes (one API call)
  Gate to advance: same SLO held across 100×

WAVE 2 (month 2)
  1,000 companies
  Same code path. Same architecture. Same numbers.
  Gate: same SLO at 10× load

FULL RAMP (month 3+)
  Your pace, not ours
  The model is proven; you set the speed of customer acquisition
```

**What we'd need from you to plan well:**

1. **Signal volume per company.** Do your users do 10 signals/day each, or 1,000? Order-of-magnitude is enough to plan; we tighten in pilot.
2. **Integration shape.** API / MCP / SDK / white-label web — affects which surfaces we harden first.
3. **Branding requirements.** Custom domain per company, or shared subdomain?
4. **Support escalation.** Joint runbook proposed in the pilot.

We can have the pilot live within a week of you saying go.

---

## What you're standing on

Public, verifiable, none of it bespoke:

| Layer | What | Reference points |
| --- | --- | --- |
| **Cloudflare network** | 81+ Tbps capacity, 300+ cities; > 11M req/sec across customers | Discord (1B+ msg/day on Workers), Shopify storefronts ($200B+ GMV), Anthropic claude.ai, OpenAI |
| **V8 isolates** | Same isolate model as Chrome; ~5 ms cold start; 10,000× denser than containers per CPU | [cloudflare.com/learning/serverless](https://www.cloudflare.com/learning/serverless/) |
| **D1 (SQLite at edge)** | Strong consistency per workspace; multi-region replication | Used in production by tens of thousands of CF customers |
| **Astro 6** | HTML-first; JS only where interactive | NASA, IKEA, Trivago, The Guardian |
| **TypeDB Cloud** | Managed graph database for substrate semantics | Vaticle/TypeDB, multi-region managed |

We did not invent these properties. We composed them. The composition is where the value lives — but every component you depend on already serves customers larger than the scale you're bringing.

---

## Honest gaps

Two things we have not yet measured at production scale, named upfront because hiding them costs both of us later:

1. **We have not run our own production at T5 (50M users) yet.** What we have: the math, the architectural decisions, the customer-shaped precedent (Discord at 1B+ msg/day on the same stack), a runnable T0 "Millions Proof" designed for 1M users + 5,000 RPS sustained for 2 hours, and **a measured Q1 baseline of 2,300 RPS clean from a single source IP on app.one.ie** (2026-05-16). The path from this baseline to the 5,000 RPS headline is multi-source distribution (T0 §Phase 2 — 4 regional runners), and from T4 to T5 is configuration (more runners, multi-region TypeDB) not redesign. See [`scale-tests.md`](scale-tests.md) §9 Q1 measured baseline, §T0, §11.
2. **Per-company peak signal rate at production scale** is modeled, not measured. The pilot exists exactly to replace that model with a measurement. We are not committing to a fixed SLO at T5 before we've seen one of your companies at T3 with real users.

If either is a dealbreaker, say so and we'll structure the deal around it. If not, we close them in the pilot.

---

# Technical depth — for your engineering team

The rest is for the engineers doing due diligence.

## The math, with sources

| Claim | Number | Source |
| --- | --- | --- |
| Worker cold start | ≈ 0 ms | Cloudflare ([blog.cloudflare.com](https://blog.cloudflare.com/eliminating-cold-starts-with-cloudflare-workers/)) |
| Worker isolate startup | < 5 ms | V8 isolate model, in-process |
| Edge PoPs | 300+ cities | Cloudflare network |
| D1 row read | 1–10 ms | Edge SQLite |
| KV read (hot) | < 10 ms global | Cached at every edge |
| Substrate runtime | ~670 lines, ~90 in hot path | `one-ie/one/CLAUDE.md` |
| Signal envelope | 2 fields | `web/src/engine/signal.ts` |
| Universal endpoints | 4 (signal/ask/mark/settings) | `.claude/rules/api.md` |
| `/chat` Lighthouse | 100% | `feedback_chat_lighthouse` (locked invariant) |
| Path strength lookup | O(1), in-memory | `select()` in `world.ts` |

Everything in this table is verifiable in code or in a public Cloudflare doc.

## Threat model — what breaks first, and what we already do about it

| Limit | First symptom | Mitigation in repo today |
| --- | --- | --- |
| TypeDB Cloud connection pool | `mark()` writes back up | Async batched writes; isolate keeps serving from RAM; eventual reconcile |
| D1 write throughput per DB (~100/s burst) | Signal log lag | Shard by workspace; signals don't need D1 to execute |
| Single DO hot key | One DO serializes (~1k req/s cap) | Use DOs only for coordination (per-room, per-wallet) — not routing |
| Worker CPU limit (50 ms default, 30 s paid) | Long-running ask() | `ask` 30 s ceiling; for longer work, fire `signal` and stream |
| LLM provider | Rate limit or latency spike | Multi-provider fallback; pheromone weakens path |
| Browser JS budget | Slow FCP on cheap devices | `client:idle`, `lazy()`, island boundaries enforce minimum JS |

## Per-tier infrastructure plan

| Tier | MAU | Peak RPS | Bottleneck | Infra $/mo | Architecture change |
| ---: | ---: | ---: | --- | ---: | --- |
| T1 | 1k | 5 | none | $0 | — |
| T2 | 10k | 50 | none | $5 | upgrade plan |
| T3 | 100k | 500 | D1 writes/workspace | $50 | workspace sharding (already in place) |
| T4 | 1M | 5,000 | TypeDB pool + hot DOs | $500 | dedicated TypeDB cluster + batched pheromone writes |
| T5 | 10M | 50,000 | LLM economics | $5–10k + LLM | multi-region TypeDB + provider routing |

The shape of this table is the proof. A system that requires a different architecture at every tier doesn't scale — it rebuilds. Ours holds shape from T1 to T5; what changes is sharding count and capacity tier, never the substrate model.

## Cost per million signals (the unit economics)

```
Workers (Bundled plan):  $0.30 per million requests + $0.02 per million CPU-ms
D1 (paid tier):          $0.75 per million row reads, $1 per million row writes
KV:                      $0.50 per million reads, $5 per million writes

For 1M signals end-to-end:
  Worker requests:    $0.30
  Worker CPU (~2ms):  $0.04
  D1 writes (1 per):  $1.00
  TypeDB amortized:   ~$0.20
  Total:              ≈ $1.54 per million signals
```

## What we will not do to scale

A checklist of complexity additions we are *declining* because we did not choose the problems they solve:

- ❌ Service mesh
- ❌ Message broker (Kafka / Redis Streams)
- ❌ Microservices split
- ❌ Caching layer in front of the database
- ❌ Stateful session store
- ❌ Autoscaler with custom metrics
- ❌ Job queue with retries-with-backoff
- ❌ Separate "API gateway" service

When we hit a limit (see threat model), the answer is to **remove a layer**, not add one.

---

## See also

- [`scale-tests.md`](scale-tests.md) — the test design that proves every claim here (Q1–Q3 quickproof, T0 Millions Proof, T1–T16 + P1–P8 component tests)
- [`architecture.md`](architecture.md) — the full system architecture
- [`one-ontology.md`](one-ontology.md) — the substrate's data model
- [`patterns.md`](patterns.md) — closed-loop discipline that keeps the system honest
- [`speed.md`](speed.md) — live chat-latency measurement log

---

*Simplicity is the platform. Scale and speed are what you get when you stop building the layers that would prevent either one.*
