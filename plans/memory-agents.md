# Agent Memory

How individual agents remember, recall, and forget.

---

## The Process Layer — Three Tiers

Anthropic's new Memory API (2026) formalises what we've been building toward: a three-layer process model. Their implementation uses files + dreaming (LLM reads transcripts, rewrites files). ONE's implementation uses TypeDB + inference + signals + dreaming. The tiers are the same; the substrate is better.

```
HOT PATH     CF edge            sub-50ms     deterministic, zero LLM
WARM PATH    cron loops L1-L7   5m → 1h      statistical, LLM gated by threshold
COLD PATH    out-of-band        daily         synthetic, LLM across sessions
```

### Hot Path (CF edge — deterministic, zero LLM)

Every signal, every turn. No model call to resolve memory state.

| Step | Mechanism | Cost |
|------|-----------|------|
| Toxicity gate | `isToxic(edge)` — in-memory resistance check | O(1) |
| Actor/path status | TypeDB rule inference — `proven-actor`, `highway-flow`, `toxic-flow` | query-time derived |
| Skill prompt read | KV cache `skill:{name}:prompt` | <5ms |
| Context pack | D1 messages + KV hypothesis snapshot | <50ms |

TypeDB rules fire at query time. No LLM token determines whether a path is toxic or an actor is at-risk — the graph structure implies it.

### Warm Path (cron loops — periodic, outcome-gated)

| Loop | Schedule | What it does |
|------|----------|--------------|
| L1 mark/warn | per signal | Pheromone deposit on outcome |
| L3 fade | every 5m | Asymmetric decay; strength -5%, resistance -10% |
| L5 evolution | every 10m | Actors with success-rate < 0.50 over ≥20 samples rewrite their system prompt |
| **L5b skill-evolution** | every 10m | **Skills with resistance > strength rewrite their instruction prompt** |
| L6 harden | hourly | Highways → confirmed hypotheses; skill path strength → skill quality hypotheses |
| L7 frontier | hourly | Unexplored tag clusters detected, surfaced to agents |

### Cold Path (dreaming — out-of-band, synthetic)

Dreaming is a batch process. It runs outside any live agent session. It reads recent transcripts across all groups, calls the LLM once, and produces a diff applied to the memory store.

What dreaming produces that no single-session agent can:

- Cross-session pattern detection (five agents saw the same failure, worded differently)
- Hypothesis deduplication (same belief stated six ways → one high-confidence hypothesis)
- Stale hypothesis flagging (contradicted by last 30 days of transcripts)
- **Skill quality synthesis (skill X fails on topic Y consistently → update skill prompt)**
- Verification notes (confirmed still accurate as of today's sessions)

The diff format:

```ts
type DreamDiff = {
  hypotheses: {
    add:    { statement: string; confidence: number; source_sessions: string[] }[]
    update: { hid: string; statement?: string; confidence?: number }[]
    remove: { hid: string; reason: string }[]
    verify: { hid: string; sessions: string[] }[]
  }
  skills: {
    update: { tid: string; prompt: string; generation: number; reason: string }[]
    retire: { tid: string; reason: string }[]
  }
}
```

The diff is applied to TypeDB. Each change carries the session IDs that produced it. No dreaming job touches TypeDB directly — it produces a diff, the diff is reviewed (or auto-applied above a trust threshold), then applied.

---

## Three Layers of Memory (Runtime View)

```
Layer 1: Pheromone (milliseconds)
  In-memory strength/resistance on paths.
  Updated on every signal. Fades every 5m.
  "What worked recently."

Layer 2: Hypotheses (persistent, TypeDB)
  Typed entities with confidence, p-value, source, scope.
  Created by L6 harden, operator assertion, or dreaming.
  "What we've learned is true."

Layer 3: Context Pack (per-conversation)
  Assembled just-in-time before each LLM call.
  Combines hypotheses + highways + recent D1 messages.
  "What the agent knows right now."
```

---

## Skills as Procedural Memory

Skills are not static files. They are TypeDB `thing` entities (thing-type='skill') with a prompt that can evolve.

### Schema (on `thing`)

```tql
# thing already has:
owns name
owns tag @card(0..)
owns thing-type      # "skill" for skills

# add for skill evolution (same as actor has):
owns prompt          # instruction content — mutable, evolves
owns generation      # iteration count
owns task-status     # active | at-risk | retired
```

### Signal path for skills

When an agent uses a skill, it signals the path:

```ts
// After skill use — outcome determines weight
mark('skill:ai-seo', depth)     // success
warn('skill:ai-seo', 0.5)       // failure
```

These signals flow into L6 harden exactly like any other path. After enough observations:

```
L6: skill:ai-seo path strength >= 50
  → insert hypothesis: "skill ai-seo is a highway for landing page work"
  → skill path-status: "highway" (derived by TypeDB rule)
```

A skill with resistance > strength × 3 triggers:

```
L5b: skill:ai-seo resistance > strength × 3
  → rewrite skill prompt using recent failure transcripts
  → increment skill.generation
  → update KV cache: skill:ai-seo:prompt
```

This is the same machinery as L5 actor evolution. Skills and actors evolve through identical loops.

### Dreaming for skills

Dreaming synthesises what L5b can't see — patterns across multiple agents using the same skill in different groups.

```
Dreaming sees:
  - 8 sessions used skill:content-strategy
  - 6 of 8 failed on "enterprise SaaS" context
  - All 6 used the same section of the prompt
  → diff: update skill:content-strategy prompt, add "For enterprise SaaS, lead with..."
  → generation: 3 → 4
  → sessions: [session-ids that produced the pattern]
```

### Hot path: reading skills

The CF edge reads skill prompts from KV, not TypeDB:

```ts
// builder.ts — skill load
const prompt = await env.KV.get(`skill:${name}:prompt`) ?? await loadSkillFromTypeDB(env, name)
```

TypeDB is the source of truth. KV is the hot-path cache. `L5b` and dreaming write to TypeDB; a post-write hook invalidates the KV key.

---

## Memory Trust Gate

The substrate does not inject everything it knows into every prompt. Confidence tiers and the operator-configured trust gate govern injection.

```ts
// substrate.ts — readMemoryGate
{ floor: 0.65, requireVerify: false }  // operator default
```

| Confidence | Treatment |
|---|---|
| ≥ 0.85 | Stated as fact |
| 0.50 – 0.84 | Stated as likely |
| < floor (default 0.65) | Omitted |

`requireVerify: true` (enterprise setting) — only `source: "verified"` hypotheses are injected. Observations and assertions are excluded until corroborated.

Agent-asserted hypotheses are capped at 0.30. A user can tell the agent something; the substrate won't trust it until independent signals corroborate it. This is the prompt injection guard.

---

## Pheromone: Fast Memory

```typescript
mark(edge, amount)    // Success. Strength increases.
warn(edge, amount)    // Failure. Resistance increases. 2× faster decay.
sense(edge)           // Read strength.
danger(edge)          // Read resistance.
```

Asymmetric decay:

```
Strength:   strength *= (1 - 0.05)     5% decay per cycle
Resistance: resistance *= (1 - 0.10)   10% decay (2x faster)
```

Strength never drops below `peak × 0.05`. Ghost trails survive — a path that was once strong can reactivate faster than a new connection.

---

## Hypotheses: Permanent Memory

### Schema

```tql
entity hypothesis,
    owns hid @key,
    owns statement,
    owns confidence,
    owns observations,
    owns scope;          # private | group | public
```

### Sources

| Source | Created by | Confidence cap |
|--------|-----------|----------------|
| `observed` | L6 harden (pheromone → knowledge) | none |
| `asserted` | operator seed or agent remember() | 0.30 |
| `verified` | dreaming corroboration across sessions | none |

### Lifecycle

```
pending → testing → confirmed
                  → rejected
```

Dreaming can promote `testing` → `confirmed` when cross-session evidence arrives. Dreaming can also move `confirmed` → `rejected` when transcripts contradict it.

---

## Context Pack: Assembled Memory

Before every LLM call:

```ts
interface ContextPack {
  profile:    { uid: string; handle: string; messageCount: number }
  hypotheses: { statement: string; status: string; confidence: number }[]
  highways:   { to: string; strength: number }[]
  recent:     { role: string; content: string }[]
  tools:      string[]
}
```

Injected into system prompt via `systemPromptWithPack()`. Facts ≥ 0.85 stated directly; hints 0.50–0.84 stated as likely; below floor omitted.

---

## Dreaming: Implementation

### Cron entry

```ts
// cron.ts
{ cron: '0 2 * * *', handler: 'dreaming-tick' }
```

### dreaming.ts

```ts
export async function dreamingTick(env: Env): Promise<void> {
  // 1. Pull last 7 days of messages from D1 across all groups
  const transcripts = await env.DB.prepare(
    `SELECT group_id, role, content, ts FROM messages
     WHERE ts > ? ORDER BY group_id, ts`
  ).bind(Date.now() - 7 * 86400000).all()

  // 2. Pull current hypotheses (to diff against)
  const current = await recallAllHypotheses(env)

  // 3. Pull current skill prompts
  const skills = await getSkillEntities(env)

  // 4. Call LLM (Opus) with full context
  const diff = await synthesize(env, transcripts.results, current, skills)

  // 5. Apply diff above trust threshold; queue rest for review
  await applyDreamDiff(env, diff)
}
```

### Trust threshold for auto-apply

```ts
const AUTO_APPLY_CONFIDENCE = 0.75  // sessions that agree on a pattern

// diff.hypotheses.add: auto-apply if source_sessions.length >= 3 AND confidence >= 0.75
// diff.skills.update:  queue for operator review (never auto-apply prompt changes)
// diff.hypotheses.remove: queue for review (destructive)
```

Skill prompt updates never auto-apply. They produce a pending `thing` update that an operator reviews via the memory UI before commit.

---

## How Memory Flows (Full Picture)

```
Signal arrives
    │
    ▼
[Toxicity gate]      isToxic() — in-memory, O(1)
    │  toxic → dissolve (no LLM)
    ▼
[TypeDB inference]   proven-actor? highway-flow? (derived facts, no LLM)
    │
    ▼
[Context pack]       D1 messages + KV hypothesis snapshot + skill prompt
    │
    ▼
[LLM call]           System prompt + context pack + user message
    │
    ▼
[Outcome]            result / timeout / dissolved / failure
    │
    ▼
[Pheromone]          mark() or warn() on path + skill path (<1ms)
    │
    ▼
[L3 — 5m]            Asymmetric fade
    │
    ▼
[L5 — 10m]           Actor evolution (success-rate < 0.50 → rewrite prompt)
[L5b — 10m]          Skill evolution (resistance > strength × 3 → rewrite skill)
    │
    ▼
[L6 — 1h]            Highways → hypotheses; skill highways → skill quality hypotheses
    │
    ▼
[L7 — 1h]            Frontier detection
    │
    ▼
[Dreaming — 2am]     Cross-session synthesis → hypothesis diff + skill update queue
    │
    ▼
[Next session]       Context pack contains promoted hypotheses + evolved skill prompts
                     TypeDB rules fire on updated graph
```

---

## Memory Operations Reference

| Operation | What it does | Hot path? |
|---|---|---|
| `mark(edge, amount)` | Strengthen path | yes |
| `warn(edge, amount)` | Add resistance | yes |
| `recall(query)` | TypeDB hypothesis search | warm (KV snapshot) |
| `remember(key, value)` | Asserted hypothesis; confidence capped at 0.30 | TypeDB write |
| `frontier(uid)` | Unexplored skill tags for this actor | TypeDB read |
| `reveal(uid)` | Full 6-dimension memory export | TypeDB read |
| `forget(uid)` | GDPR erasure — signals, paths, hypotheses, actor | TypeDB + D1 + KV |

---

## Comparison: ONE vs Anthropic Memory API

| Feature | Anthropic (2026) | ONE |
|---|---|---|
| Storage | File system (files + hierarchy) | TypeDB (typed graph) |
| Path status | LLM reads file, decides | TypeDB rule inference (deterministic) |
| Actor status | LLM reads file, decides | TypeDB `proven-actor` / `at-risk-actor` rules |
| Skill updates | Dreaming rewrites skill files | L5b + dreaming queue (operator review) |
| Concurrency | Content hash (optimistic) | KV CAS + TypeDB transaction |
| Version history | File audit log | KV versioned snapshots + TypeDB ts |
| Out-of-band synthesis | Dreaming (LLM reads transcripts) | Dreaming tick (same) |
| Process trigger | API call or cron | Cron (L1-L7 + dreaming-tick) |
| Confidence model | Not exposed | p-value gate + trust floor + requireVerify |
| Permission scope | read-only / read-write per store | `scope` on hypothesis (private/group/public) |

The structural difference: Anthropic uses the LLM to interpret the memory state. ONE uses TypeDB rules to derive it. The LLM in ONE is only invoked when the question is genuinely probabilistic — which cross-session pattern is worth hardening, which skill prompt should change. Everything else is deterministic.

---

## See Also

- [world-memory.md](world-memory.md) — L1-L7 loops in detail; world-level learning
- [memory.md](memory.md) — The "no RAG" claim; 6 dimensions as memory
- [routing.md](routing.md) — How TypeDB inference feeds the routing formula
- [dictionary.md](dictionary.md) — Canonical names: hypothesis, strength, resistance, highway, frontier
- [patterns.md](patterns.md) — Closed loop, zero returns, deterministic sandwich
