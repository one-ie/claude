---
paths:
  - "packages/sdk/src/**/*.ts"
  - "channels/src/**/*.ts"
  - "one.ie/web/src/lib/pheromone.ts"
  - "one.ie/web/src/workers/**/*.ts"
---

# Engine Rules

Apply to substrate code — the SDK verbs, the pheromone world, and every worker that consumes them.

---

## The Three Locked Rules (non-negotiable)

These three rules compound. Breaking any one breaks the flywheel.

### Rule 1 — Closed Loop

**Every signal closes its loop.** `mark()` on result, `warn()` on failure,
`dissolve` on missing receiver. No silent returns. No orphan signals.

```typescript
// ask() resolves to one of 4 outcomes (packages/sdk/src/types.ts — Outcome<T>)
const outcome = await one.ask(receiver, data)
switch (outcome.kind) {
  case "result":    await one.mark(edge); break        // success → path strengthens
  case "timeout":   /* neutral — not the agent's fault */ break
  case "dissolved": await one.warn(edge, 0.5); break   // mild — receiver doesn't exist
  case "failure":   await one.warn(edge, 1); break     // failure — produced nothing
}
```

Why: path strength is the only thing that compounds. A handler that returns
silently leaks learning. Width (parallelism) only compounds if every
parallel branch deposits a mark or warn on the path it used.

### Rule 2 — Structural Time Only

**Plan in tasks → waves → cycles.** Never days, hours, weeks, sprints,
or any wall-clock unit.

```
task    = atomic unit of work (one receiver handler, one file edit)
wave    = phase within a cycle (W1 recon → W2 decide → W3 edit → W4 verify)
cycle   = full W0-W4 sandwich, exits at rubric >= 0.65
path    = what remembers across cycles (strength / resistance)
```

Why: the substrate measures **width** by tasks-per-wave, **depth** by
waves-per-cycle, **learning** by cycles-per-path. Calendar time can't be
`mark()`d, so it doesn't compound. Genuine external deadlines (merge
freezes, release cuts) are the only wall-clock exception — they come
from outside the substrate.

### Rule 3 — Deterministic Results in Every Loop

**Every loop reports verified numbers, not vibes.** Tests passed/total.
Build time in ms. Deploy time per service. Health check latency. Rubric
dimension scores. These are the deterministic signals that calibrate path strength.

```typescript
// Every loop ends like this — not "done", but "done with receipts"
{
  passed: 320,
  failed: 0,
  buildMs: 22995,
  deployMs: { web: 13705, sync: 8249, channels: 9163, api: 17391 },
  health: { web: 292, sync: 270, channels: 270 },
  // /do code rubric — security/stability/simplicity/integration/speed, gate ≥ 0.65
  rubric: { security: 0.92, stability: 0.85, simplicity: 0.90, integration: 0.88, speed: 0.80 }
}
```

Why: path strength without verification is superstition; with verification
it's learning. A loop that can't report deterministic results can't
`mark()` — it's just noise. This is the POST check of the deterministic
sandwich applied to every automation skill.

**Where it shows up:**
- `/do` — W4 reports tests passed/total, reconcile canons, rubric scores
- `/close` — reports rubric score (security + stability + simplicity + integration + speed, composite ≥ 0.65) + learnings entry + promise settle (kept/broken/dissolved/none)
- `/sync` — reports tasks synced, hash-delta, KV writes
- `/deploy` — reports W0 results, build ms, per-service deploy ms, health

If you can't measure it, you can't route around it.

---

## Signal

```typescript
type Signal = {
  receiver: string      // "family" or "family:action"
  data?: unknown        // typed per receiver via RECEIVERS catalog
}
```

The universal primitive — `{ receiver, data }` is frozen. Capability contracts
live in the receiver registry (`@oneie/sdk/receivers`); the schema is truth for data.

---

## World (the pheromone primitives)

Shipped surface — `createWorld()` in `one.ie/web/src/lib/pheromone.ts`
(vendored in-RAM for DO bundles; mirrors the SDK verb semantics):

```typescript
world.mark(edge, w?)        // strengthen path
world.warn(edge, w?)        // weaken path (resistance)
world.sense(edge)           // read strength
world.follow(from)          // best path (deterministic)
world.select(from)          // best path (probabilistic, ant-like)
world.highways(prefix?, n?) // top weighted paths
world.fade(rate?)           // decay all paths (resistance 2x faster)
world.serialize()           // snapshot for KV
world.restore(snapshot)     // rehydrate
```

Over HTTP the same verbs are `SubstrateClient` methods (`packages/sdk/src/client.ts`).

`harden` is the one verb with **no general wire**. `learning:know` is in no
registry (`grep -c "learning:" packages/sdk/src/receivers.ts` → 0) and has no
resolver; `client.know()` is `@deprecated` and returns `{}`. The only shipped
harden receiver is **`chat:harden`** (`one.ie/web/src/lib/resolvers/entity.ts:566`),
which crystallises a resolved chat thread into a dim-6 learning and requires an
`entityId` — so it does not cover free-standing claims. Do not write
`signal("learning:know")` into new code or docs; it fails silently.

**Promise paths.** `promise:<slug>→proof` is a first-class weighted path
family. At close, `.claude/scripts/do-promise-settle.sh` re-runs the
promise's `proof:` and `mark`s the path with the W4 composite (kept) or
`warn`s it (broken). Build-time and run-time reputation are one ledger —
cycle composites land on the same weighted paths run-time routing reads.

---

## Zero Returns

Positive flow only. Silence is valid.

```typescript
// GOOD — missing handler? Signal dissolves. World continues.
handler?.(data, send, ctx)

// BAD
if (!handler) return reject(...)
if (!target) throw new Error(...)
```

A dissolved signal still closes its loop — the *caller* sees `kind: "dissolved"`
and warns the edge (Rule 1). Dissolve is an outcome, not an exception.

---

*The 6 verbs: signal · mark · warn · fade · follow · harden.*

---

## Rules 4–6 (from The Shape of the System)

### Rule 4 — Deadlines + Ceilings

**Every external call has a deadline. Every caller-controlled loop has a ceiling.**

```typescript
// GOOD — AbortController on every fetch to an uncontrolled boundary
const controller = new AbortController()
const id = setTimeout(() => controller.abort(), TIMEOUT_MS)
try {
  const res = await fetch(url, { signal: controller.signal })
} finally {
  clearTimeout(id)
}

// BAD — no deadline = the caller's failure becomes your hang
const res = await fetch(url)
```

Ungated retries and uncapped allocations (sockets, threads, recursion) are DoS bugs — fixed on sight, no profiling required. Applies to: TypeDB calls, KV reads, chain RPCs, price oracles, any `fetch` to an external host.

### Rule 5 — Drain Before Exit

**CF Workers drain before returning.** Stop accepting → drain in-flight within deadline → flush durable writes → return.

```typescript
// pattern for Durable Objects and long-running handlers
ctx.waitUntil(drainAndFlush())
return new Response('accepted', { status: 202 })
```

Half-finished work silently corrupts downstream. The OS reclaims memory; it never reclaims meaning. Signal loss between "credits granted" and "signal emitted" is this failure mode.

### Rule 6 — Monotonic Durations

**Durations use a monotonic source. Wall clock is for display and TTL anchoring at write time only.**

```typescript
// GOOD — duration from performance.now() (monotonic)
const start = performance.now()
// ... work ...
const elapsedMs = performance.now() - start

// GOOD — TTL anchored once at write time (wall clock OK here)
await KV.put(key, value, { expirationTtl: TTL_SECONDS })

// BAD — wall clock for ordering or mid-flight deadline check
if (Date.now() > deadline) throw new Error('expired') // skews under NTP
```

Wall clock can jump or skew under NTP corrections. Never use it to compare event ordering across Workers or to check a deadline computed from a prior `Date.now()` call.

---

## Verb Contracts

Each of the 6 verbs has a **pre / post / invariant** contract. Spec lives in `text/contracts.md` — loaded only when editing a verb implementation, not every session.

New verb? You need: contract block in `text/contracts.md`, row in `one-ie/CLAUDE.md` § The 6 verbs, contract gate in `.claude/agents/w4-verify.md` step 2.5. If you can't write the contract, you can't ship the verb.
