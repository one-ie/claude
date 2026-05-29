# The Engine

Most backends keep your data in a database and fetch it when asked. Every read is a round trip: across the network, into the store, back again. Twenty milliseconds on a good day. That round trip is what your users feel as waiting.

ONE does it the other way round. The whole graph — every actor, every connection, every weight — lives in memory, at the edge, next to the code that reads it. A read is not a database call. It is a lookup in RAM. We didn't make the round trip faster. We removed it.

That is the one idea behind the speed. The rest of this page is how we make it safe.

---

## Three layers, one truth

**TypeDB is the brain.** It holds the real graph: six dimensions, a typed schema, every path and weight and learned fact. It is the source of truth. When something must be remembered for good, it is written here.

**Cloudflare KV is the snapshot.** A copy of the graph, pushed to 330 cities. If a server restarts, it reloads from the nearest copy in about ten milliseconds, not from the brain across an ocean.

**The Durable Object is the memory.** One object holds the live graph in RAM and answers every read. A Durable Object has 128 MB of memory. The graph is about 1.3 MB at ten thousand connections, around 12 MB at a hundred thousand. It fits with room to spare, at any size an agency will reach.

Truth, snapshot, memory. The slow store is never on the path the user waits on.

---

## What each part does

No magic, no mystery box. Six named parts, each doing one job.

| Part | What it does |
|---|---|
| **Cloudflare Workers** | The code, running in 330 cities. A user in Brisbane hits a node 20ms away, not a data centre in Virginia. |
| **Durable Object** | One copy of the graph, single-threaded. No two writes race. The read after a write sees the write. |
| **TypeDB** | The brain. The typed graph everything else is a copy of. |
| **D1** | SQLite at the edge. The audit log: every signal, every change, in order, for when you need the receipts. |
| **KV** | The global cache. Sub-10ms reads from anywhere. Cold-start recovery and backup. |
| **R2** | Object storage. Daily backups and agent files. No charge to read your own data back out. |

You can point at every one of them. That is the test of a real system: a CTO can name the parts.

---

## Write once, answer from memory

When a connection strengthens, the memory updates in place and the answer comes straight back. The write to the brain happens just behind, batched in a 100-millisecond window so a hundred changes become one transaction.

The WebSocket clients hang off the same object that holds the graph. So a change pushes to every connected screen the instant it lands. No polling. No "refresh to see the latest." The screen already has it.

The clearest case is the safety check. "Is this path poisoned?" used to mean a cache read, or a query to the brain, with a verdict that could be five minutes old. Now it is a set lookup in memory, always current. The answer is there before the question finishes.

---

## What it accepts

Every fast system makes a trade. Here is ours, in a table, because a trade you can't name is a trade you don't understand.

| Behaviour | What we accept | Why it's safe |
|---|---|---|
| Writes batch for 100ms before reaching TypeDB | A crash in that window loses at most 100ms of writes | Changes are additive; the brain re-reads on restart. Nothing corrupts. |
| Memory refreshes from the brain every 60s | A change made directly in the brain takes up to a minute to show in memory | Almost everything flows through the engine, which updates memory at once. The 60s sweep is the backstop, not the path. |
| Cold start reloads from KV | The first request after a restart waits ~10ms longer | Ten milliseconds, once, from the nearest of 330 cities. |

The brain is always right. Memory is always fast. The gap between them is milliseconds, and it closes itself.

---

## What's measured, what's next

The deploy is 107 seconds, logged. KV reads are under 10ms, Cloudflare's own figure across 330 cities. The chat page loads in under a second (see *Speed*).

The in-memory graph went live on 29 May 2026. The before is known: a read crossed the network to the cache or the brain. The after is a lookup in RAM. We are measuring the production median now and will publish it on the *Speed* page with a date, like every other number we claim. `[prod p50: measuring]`

We don't ship the number before we've measured it. That rule is the reason you can trust the ones we do.

---

## Why it stays fast as you grow

Brad's worry is the right one: vendors promise speed, then add clients and slow down.

The defence is the shape, not the promise. The memory is one object per graph. Adding clients adds graphs, not contention. Each runs on the same Cloudflare runtime that serves the network at millions of requests a second. The brain scales sideways. The 107-second deploy does not grow with your client count. The architecture at fifty clients is the architecture at five thousand.

So when a plumbing client's customer asks a question from a car park on 4G, the answer is already in memory, 20 milliseconds away. They never learn the name of any of this. They just never wait.

> "Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away." — Antoine de Saint-Exupéry

We took the database off the read path. That is the whole trick. Everything fast about ONE follows from it.

<!-- rubric: fit=0.92 strongest=memory-not-network show=0.90 cut=0.90 craft=0.90 → 0.90 ✓ -->
<!-- persona: push=slow-fragile-backend anxiety=scale-degradation pull=customers-never-wait job=reassure-technical-partner -->
