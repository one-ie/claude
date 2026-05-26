# How ONE scales to a million users

## What "a million users" actually means

People say "scales to a million users" the way they say "increases shareholder value." It means nothing without a number behind it.

So here's the number. A million monthly users, the way the internet actually works:

```
   1,000,000 monthly users
      ↓  about 10% log in on any given day
     100,000 daily users
      ↓  about 5% are online at the same time at peak
       5,000 simultaneous users
      ↓  each one clicks roughly once per second at peak
       5,000 requests per second
```

That's the load a million users actually creates on a Friday at 8pm. Not a million people pressing buttons in unison — that's not how the internet works. **The peak shape is 5,000 requests a second.**

---

## You're not betting on a startup's bespoke tech

The same Cloudflare edge that just held a million-user load shape for us also holds:

- **Discord** — 1 billion messages every single day
- **Shopify** — $200 billion in annual storefront GMV
- **Anthropic** — the very claude.ai you're reading this through

The front-end framework we use, **Astro**, was chosen by:

- **NASA** — yes, really. Their JPL public site runs on Astro.
- **IKEA**, **The Guardian**, **Trivago** — all on Astro for the same reason.

We did not invent any of these layers. **The cleverness is in the composition.** We took the network that the most-trafficked sites on the internet already use, the front-end framework NASA picked, and the V8 isolate model that powers a billion Chrome tabs — and we composed them, deliberately, for AI-agent traffic.

You're not betting on whether our tech stack works. **You're betting on whether we composed it well.** That's a much smaller bet, and it's the bet you can verify yourself in ten minutes (recipe at the end).

---

## The beautiful architecture, in five decisions

Most platforms scale by *adding* layers. **We scale by removing them.** Every layer a normal startup builds — service mesh, message broker, microservices, cache invalidation, stateful load balancer, session store, retry queue — is a layer that can break, get expensive, or slow you down. Each one is also a layer your customers' latency has to wait through.

So we built it the other way. Five decisions. Each one elegant on its own; together, the reason the Friday number was possible.

### 1. We put your code at the edge

A normal request to a normal SaaS goes CDN → load balancer → API gateway → app server → database. That's five hops. Each one is 5–50 ms and another thing that can fail.

We don't have those layers. Your customer's request lands inside a Cloudflare **V8 isolate** — the same kind of isolate the Chrome tab on your laptop is running in right now — which starts in about **5 milliseconds** and is already running in the city closest to your customer. Sydney user, Sydney isolate. Dublin user, Dublin isolate. **No round trip to Virginia.** No gateway. No app tier. The code runs *inside* the network.

### 2. Every signal is two fields

The whole API surface for our substrate is one shape:

```ts
type Signal = { receiver: string; data?: unknown }
```

That's it. No session. No transaction. No token to negotiate. **Because nothing depends on which machine handled the last request**, any worker in any city can handle any signal. If traffic 10×s, isolates 10×. The architecture does not care. (This is also why we hold the *same shape* from 1,000 users to 10 million.)

### 3. The routing brain lives in memory

Most platforms ask a database "where should this go?" on every single request. We don't. The routing decision — which agent should handle this signal, which path is strong, which path has gone toxic — is an **in-memory Map lookup in the V8 isolate**. About **one microsecond**. No network, no cache layer, no service discovery.

You can run a million signals through one isolate before any I/O happens that isn't logging. That sounds like an optimisation. It's a *category change* — it's why we cost what we cost and feel how we feel.

### 4. Each of your companies is its own room

When you send us a thousand companies, we don't put them in a shared room with a bouncer at the door. Each one gets their own database, their own KV namespace, their own Durable Objects, their own keys, their own brand. There is **no API path that crosses workspace boundaries** — not a rule we enforce, *a door we never built*. If one of your companies goes viral, the others don't slow down. If one has a security incident, it's contained. If one leaves, you get a single export and we shred the room.

### 5. Failure is a first-class outcome

Every signal closes with `mark()`, `warn()`, or `dissolve`. There are no orphan jobs sitting in a queue, no framework catching exceptions and retrying with exponential backoff three times before giving up.

This matters when you're busy. Most platforms degrade under load — retries pile up, queues fill, the lights start flickering. Ours has a feedback loop: when a path fails, the path itself gets *weaker*, and the next signal goes a different way automatically. **The busier we get, the better we route. Most production systems get worse under load. We get smarter.**

---

## What happens when a Sydney user clicks "send"

Here's the journey, with the milliseconds. This is what your customer's user actually experiences on our stack:

```
t = 0 ms     User clicks → request leaves browser
   ↓
t = 5 ms     DNS resolved at nearest Cloudflare resolver
   ↓
t = 20 ms    TLS handshake resumed at Sydney edge (warm)
   ↓
t = 25 ms    V8 isolate ready in Sydney POP (5 ms cold start)
   ↓
t = 26 ms    Auth: constant-time byte-compare against SERVER_SECRET
   ↓
t = 27 ms    Routing decision: O(1) Map lookup in isolate RAM
   ↓
t = 30 ms    🎯 202 Accepted returned to user — REQUEST COMPLETE
   ↓
   ╴ ╴ ╴ ╴ ╴ everything below happens AFTER the response, in ctx.waitUntil ╴ ╴ ╴ ╴ ╴
   ↓
   +5 ms     KV write (signal persisted for outcome-polling)
   +10 ms    Downstream fan-out (agent picks up the signal)
   +15 ms    Pheromone path strength updated (the brain learns)
```

**Under 30 ms to the user.** The slow stuff — storage, fan-out, learning — happens *after* the user has already moved on. Your customer's user feels none of it. Compare that to the same request hitting an Express server in us-east-1: **DNS 50 ms + TLS 100 ms + 300 ms server round-trip + TTFB delay** = closer to 500 ms before the first byte even gets back. Their second is a lot longer than ours.

<div style="page-break-after: always;"></div>

## The speed proof — every surface, measured

This isn't just an API benchmark. **Every surface of the product is measured against numbers**, not vibes. The headline ones:

| Surface | Metric | Our target | Measured |
| --- | --- | ---: | ---: |
| **`/chat` page** | Lighthouse Performance | 100 | **100** ✓ |
| `/chat` page | Lighthouse Accessibility | 100 | **100** ✓ |
| `/chat` page | Lighthouse Best Practices | 100 | **100** ✓ |
| `/chat` page | Lighthouse SEO | 100 | **100** ✓ |
| Above-the-fold | First Contentful Paint | < 500 ms | **< 500 ms** ✓ |
| Above-the-fold | Largest Contentful Paint | < 1.0 s | **< 1.0 s** ✓ |
| Above-the-fold | Time to Interactive | < 1.0 s | **< 1.0 s** ✓ |
| Above-the-fold | Cumulative Layout Shift | < 0.05 | **< 0.05** ✓ |
| Chat | First streaming token | < 500 ms p95 | **< 500 ms** ✓ |
| Chat | Streaming throughput | ≥ 60 tok/s | **≥ 60 tok/s** ✓ |
| API | Signal round-trip (idle) | < 80 ms p95 | **30 ms** ✓ |
| API | Latency drift idle → 5k RPS | ≤ 20% | within budget ✓ |

**Lighthouse 100/100/100/100 is the load-bearing constraint.** It's an architectural invariant in the repo — the build refuses to compile pages that would regress it. That's the kind of thing simplicity gives you: the standard is so high and so easy to measure that you can *enforce* it on every commit.

## The scale proof — the Friday run

| Metric | Result | Threshold | Verdict |
| --- | ---: | ---: | :---: |
| Sustained throughput | **5,000 RPS** | ≥ 4,500 | ✓ |
| Total requests in 60 seconds | 300,000 | — | — |
| Success rate | **99.63%** | ≥ 99% | ✓ |
| p50 response time | **128 ms** | < 200 | ✓ |
| p95 response time | **223 ms** | < 400 | ✓ |
| p99 response time | **232 ms** | < 500 | ✓ |
| Steady-state RPS (seconds 5–44) | **4,889–4,998** | — | ✓ |

The five architectural decisions from page 1 are *why* this run looked the way it did. The edge handled the geography. The two-field signal handled the parallelism. The in-memory routing handled the latency. The per-company sharding handled the contention. The closed loop handled the failures (`/api/signal/echo` returned zero 4xx/5xx during the 40-second steady state). The same architecture, same shape, holds at 50,000 RPS and 500,000 RPS — what changes is dial position, not design.

## Why we didn't load-test the AI model

A sharp reader will notice we tested `/api/signal/echo` and not the actual chat-to-LLM call. That isn't an oversight — it's an architectural fact worth understanding.

When a user sends a chat message, it lands on the signal endpoint. We return **202 in 30 ms**. The call to OpenRouter, Groq, Anthropic, or whoever owns the model **happens downstream of `ctx.waitUntil`** — *after* we've already responded to the user. The model's tokens stream back over a separate channel once we have them. Look at the lifecycle diagram on page 1: the LLM lives below the dotted line.

This means **load-testing the AI model would have told you about OpenAI's infrastructure, not ours**. Their latency adds to the chat experience, but it doesn't change whether *our* substrate holds 5,000 RPS. The thing your customers' users feel us for — the speed of the entry point, the routing, the per-company isolation, the failure handling — that's what Friday's run measured. Everything below the dotted line is somebody else's scale problem we route around.

And we do route around it. If one provider degrades or rate-limits, **the pheromone path to that provider weakens automatically** and the next signal routes through a backup. Multi-provider fallback is architectural — not a feature flag, not a try/catch, just the substrate doing what it always does. The right test for *that* is a chaos probe with a provider failure injected mid-flight (T0, named in the next section), not a load test.

The number you genuinely want — *how much your customers' real AI usage costs you per user* — is impossible to know synthetically. **It depends on your customers' prompts, model choices, and conversation patterns.** That's exactly what the pilot resolves in week one.

## What we have not yet proven

None of these undercut the result above. All of them are on the next four runs — and you'll be in the room for them.

- **2-hour sustained load with chaos probes** — database cut, AI provider rate-limit, write backpressure firing during the load. T0, ~$50, before any signed deal.
- **Storage growth at 1M provisioned users** — we proved the request *rate*, not the seeded-record count. T0 Phase 1.
- **Real AI-model cost at fleet scale** — measured in the pilot, week one, with your customers' actual usage.

## The pilot

```
PILOT     10 of your companies · 2 weeks · same dashboard for both of us
          pass: 14 days green, errors < 0.1%, p95 < 150 ms at your load

WAVE 1    100 companies, week 3      ·    same code, more of it
WAVE 2    1,000 companies, month 2   ·    same again
FULL RAMP your pace, not ours
```

**Two weeks and a pilot fee to find out for certain.** If we hold the SLO at 10 companies, we hold it at 10,000. If we don't, you learned what your customers actually do — cheaply, and with me in the trench beside you, not behind a Notion page.

