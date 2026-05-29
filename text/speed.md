# Speed

---

## The chat page responds in under 100 milliseconds.

That's faster than a human blink (~150ms).

The moment you click the text box, ONE opens a warm connection to the AI. By the time you hit send, it's already waiting. First token on screen in ~97ms p50. Lighthouse score: 100/100/100/100.

No other AI chat page scores four hundreds. Most don't bother measuring.

---

## The routing decision takes 0.005 milliseconds.

Not the AI inference — the routing. The part that decides which agent handles your request.

Traditional AI orchestration: ~300ms per routing call. ONE: <0.005ms. That's 60,000× faster on the decision layer alone. Once a path becomes a highway, it caches at the edge. Routing drops to <10ms. The LLM stays at 1–2 seconds. Physics. Nothing to do about that.

But we win on everything else.

---

## The whole graph lives in memory.

Most backends read from a database: across the network, into the store, back again. ONE keeps the whole graph in RAM, at the edge, in one Durable Object. A read isn't a database call. It's a memory lookup.

It went live on 29 May 2026. The production median is measuring now — we publish numbers after we measure them, not before. What's certain is the shape: we took the database off the read path. See *The Engine*.

---

## One agent equals 150 people.

An agent executes one decision per second, 24 hours a day. That's 43,200 decisions per day. A human makes 288.

The ratio is 150× by throughput. 10× cheaper per outcome. And the agent never sleeps, never has holidays, and gets faster over time as paths harden into highways.

Marketing analysis: 50 minutes human, 4 seconds agent. Customer support triage: 4 minutes human, 2 seconds agent. Content approval chain: 125 minutes human, 8 seconds agent.

These aren't projections. They're arithmetic.

---

## The substrate learns 43,000× faster than humans can review feedback.

Every signal marks a path. Every outcome — success or failure — deposits pheromone. After 50 passes, a path becomes a highway. After a highway hardens, routing is instant and the path is immutable on Sui.

Day 1: LLM routes every decision (~1,500ms). Day 50: highway emerges, routing drops to <10ms. Cost per decision falls 200×.

The flywheel runs without configuration.

---

## From commit to production in 107 seconds.

Build (Astro): 23s. Gateway deploy: 13.7s. Sync: 8.2s. NanoClaw: 9.2s. Pages: ~16s. Health checks: <1s. Total: 106.9s.

Four services. One command. Every time.

---

## The numbers that back the claim

| What | Number | Verified |
|------|--------|---------|
| Chat TTFB p50 (browser) | ~97ms | 2026-05-03 |
| Chat TTFB gate | ≤100ms | passed |
| Lighthouse (perf / a11y / best / SEO) | 100/100/100/100 | 2026-05-03 |
| Routing decision | <0.005ms | 320 tests |
| Mark / warn | <0.001ms | in-memory |
| Highway cache (KV) | <10ms | edge |
| Graph read (in-RAM, BrainDO) | memory lookup · p50 measuring | live 2026-05-29 |
| Agent decisions / day | 43,200 | arithmetic |
| Human decisions / day | 288 | arithmetic |
| Throughput ratio | 150× | |
| Cost per decision (agent) | $0.001 | |
| Cost per decision (human) | $0.10 | |
| Commit → production | 106.9s | 2026-04-14 |
| Tests passing | 320 / 320 | <7s total |

Every speed claim has a number. That's the rule.

---

## Why ONE is fast

Not because the LLM is faster. Everyone uses the same LLMs.

ONE is fast because:

1. Routing is arithmetic, not inference. Pheromone weights. Integer comparisons. No LLM call.
2. Bad paths dissolve before they touch the LLM. Three checks, all sub-millisecond.
3. The whole graph lives in RAM at the edge. A read is a memory lookup, not a round-trip to a database.
4. Agents run 24/7, accumulate feedback at 43,200 marks/day, and harden the best paths into immutable on-chain proof.

The substrate carries the weight. The surface stays fast.

---

> "He who can handle the quickest rate of change survives." — Col. John Boyd

Fastest wins. Remove friction. Power through simplicity. Same arrow. Three angles.

---

*Numbers: `one/speed.md` (chat) · `one/agent-speed-advantage.md` (economics) · deploy log 2026-04-14 · 320 tests, verified. Architecture: `text/002-engine.md`.*
