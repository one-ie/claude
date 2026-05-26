# Tutorial

Build a learning world. Seven phases. One loop.

```
BIRTH → SIGNAL → LEARN → DECAY → HIGHWAY → EVOLVE → KNOW
  │                                                    │
  └────────────────────────────────────────────────────┘
```

---

## Phase 1: Birth — Create an Agent

An agent is a markdown file. The substrate reads it, creates a unit in TypeDB, and wires it into the runtime.

```markdown
---
name: echo
model: claude-haiku-4-5-20251001
skills:
  - name: repeat
    tags: [tutorial, echo]
    description: Repeat what you hear
  - name: transform
    tags: [tutorial, transform]
    description: Transform input creatively
tags: [tutorial]
sensitivity: 0.5
---

You are Echo. You repeat and transform what you receive.
When repeating: return the input unchanged.
When transforming: rephrase creatively but preserve meaning.
```

What happens:

```typescript
import { parse, syncAgent } from '@/engine'

const spec = parse(markdown)       // YAML → AgentSpec
await syncAgent(spec)              // AgentSpec → TypeDB

// TypeDB now has:
// - unit entity (uid: "echo", model, system-prompt)
// - skill entities (repeat, transform)
// - capability relations (echo can do repeat, echo can do transform)
```

Or sync via API:

```bash
curl -X POST /api/agents/sync \
  -d '{"markdown": "---\nname: echo\n..."}'
```

The agent exists. It hasn't done anything yet.

---

## Phase 2: Signal — Send a Message

Two fields. That's all that flows.

```typescript
type Signal = { receiver: string; data?: unknown }
```

Send one:

```typescript
import { world } from '@/engine'

const one = world()

one.add('echo')
  .on('repeat', (data, emit, ctx) => {
    return data  // echo it back
  })
  .on('transform', (data, emit, ctx) => {
    return { transformed: `~${data}~` }
  })

// Signal routes to echo's "repeat" handler
one.signal({ receiver: 'echo:repeat', data: 'hello' }, 'entry')
```

What happens inside:

```
signal({ receiver: 'echo:repeat', data: 'hello' }, from='entry')
  → parse receiver: unit='echo', task='repeat'
  → mark path: entry→echo:repeat (+1 strength)
  → route to unit: echo({ receiver, data }, 'entry')
  → execute task: repeat('hello', emit, { from: 'entry', self: 'echo:repeat' })
  → return 'hello'
```

Via API:

```bash
curl -X POST /api/signal \
  -d '{"sender": "entry", "receiver": "echo", "data": "hello", "task": "repeat"}'
```

The path `entry→echo` now exists with strength 1.0.

---

## Phase 3: Learn — Accumulate Weight

Every signal marks the path it travels. Success adds strength. Failure adds resistance.

```typescript
// Success — path strengthens
one.mark('entry→echo', 1)

// Failure — path resists
one.warn('entry→echo', 1)

// Net weight = strength - resistance
// Positive net → path is working
// Negative net → path is failing
```

The four outcomes:

```typescript
const outcome = await one.ask({ receiver: 'echo:repeat', data: 'hello' })

if (outcome.result)     one.mark(edge, chainDepth)   // success: path reinforced
if (outcome.timeout)    /* neutral — not the agent's fault */
if (outcome.dissolved)  one.warn(edge, 0.5)           // missing: mild resistance
/* no result */         one.warn(edge, 1)              // failure: full resistance
```

Chain depth matters. The deeper the chain, the stronger the mark:

```
entry → echo → parser → store
  +1      +2      +3      +4    (capped at 5)
```

Paths that participate in long successful chains get stronger.

---

## Phase 4: Decay — Time Heals

Without decay, the first path found would dominate forever. Fade makes the world forget.

```typescript
one.fade(0.05)  // 5% decay per cycle
```

The asymmetry:

| What | Decay Rate | Why |
|------|-----------|-----|
| Strength | 5% | Success persists |
| Resistance | 10% | Failures forgive |

```
Cycle 0:  strength=100  resistance=100  net=0
Cycle 1:  strength=95   resistance=80   net=15
Cycle 2:  strength=90   resistance=64   net=26
Cycle 3:  strength=86   resistance=51   net=35
```

Resistance melts away. Strength endures. A path that was blocked reopens if the agent improves.

Three more rules:

- **Ghost trails**: Strength never drops below `peak × 0.05`. Old highways leave traces.
- **Seasonal decay**: Unused paths (24h+) decay 2x faster. Use it or lose it.
- **Revenue boost**: Paths that earn money route with higher priority.

Via API:

```bash
curl -X POST /api/decay-cycle \
  -d '{"trailRate": 0.05, "resistanceRate": 0.20}'
```

---

## Phase 5: Highway — Prove a Path

When a path's net strength crosses the threshold, it becomes a highway.

```typescript
const HIGHWAY_THRESHOLD = 20  // net strength to skip LLM

// During tick:
const netStrength = net.sense(edge) - net.danger(edge)
if (netStrength >= HIGHWAY_THRESHOLD) {
  // Skip LLM call entirely — path is proven
  net.mark(edge, chainDepth)
  // result.skipped = true
}
```

This is how the substrate gets cheaper over time. Proven paths don't need an LLM to confirm them. The routing algorithm (STAN) takes over:

```
weight = (1 + net_strength × sensitivity) × latency_penalty × revenue_boost
```

- `sensitivity = 0` → pure exploration (scout). All paths equal.
- `sensitivity = 1` → follow highways (harvester). Best path wins.
- `sensitivity = 0.5` → balanced (analyst). Prefer highways, occasionally explore.

```bash
# See what highways exist
curl /api/export/highways | jq .

# Run a tick — highways get skipped (no LLM cost)
curl '/api/tick?interval=0' | jq '{selected, skipped, highways}'
```

---

## Phase 6: Evolve — Agent Self-Improvement

When an agent is failing, the substrate rewrites its prompt.

```
L5 EVOLUTION — every 10 minutes, 24h cooldown per agent

Trigger:  success-rate < 50%  AND  sample-count >= 20
Skip:     revenue > 1.0 AND success > 30% (profitable agents spared)
Action:   LLM rewrites the agent's system-prompt
History:  old prompt saved as hypothesis (status: "testing")
Counter:  generation increments (gen 0 → gen 1 → gen 2)
```

What happens:

```typescript
// 1. Query struggling units
const struggling = await query(`
  match $u isa actor, has success-rate $sr, has sample-count $sc;
  $sr < 0.50; $sc >= 20;
`)

// 2. Gather context — skills, tags, known patterns
const skillInfo = "repeat [tutorial, echo], transform [tutorial, transform]"
const insights = await net.recall(uid)  // confirmed hypotheses about this agent

// 3. Ask LLM to rewrite
const newPrompt = await complete(
  `Agent "${uid}" has 35% success over 25 tasks (gen 0).
   Skills: ${skillInfo}. Known patterns: ${insights}.
   Rewrite its prompt to improve:\n\n${oldPrompt}`
)

// 4. Save old prompt as hypothesis (rollback history)
insert hypothesis "evolve-echo-gen0" status "testing"

// 5. Update the agent
update unit "echo" set system-prompt = newPrompt, generation = 1
```

Two layers of learning:
- **Substrate** — pheromone on paths. The world gets smarter.
- **Agent** — prompt evolution. The individual gets smarter.

---

## Phase 7: Know — Harden Knowledge

Every hour, the substrate looks at itself and writes down what it learned.

```
L6 HARDEN — every hour

Three things happen:
1. High-confidence paths (≥ 0.8) → confirmed hypotheses (permanent knowledge)
2. Fading paths (10-20 strength) → testing hypotheses (watch these)
3. Strength surges (delta > 10) → observations (something changed fast)
```

```
L7 FRONTIER — every hour

Two detection methods:
1. Tag gaps: >70% of skills in a cluster unexplored
2. Unit gaps: active units that have never been connected
```

The knowledge loop closes:

```
knowledge → evolution coupling

Strong patterns trigger PRIORITY EVOLUTION
  → relaxed threshold (65% instead of 50%)
  → units on proven paths evolve first
```

```bash
# What does the substrate know?
curl /api/hypotheses | jq '.hypotheses'

# What hasn't it explored?
curl /api/frontiers | jq .
```

---

## The Complete Loop

```
         signal
           │
     ┌─────▼─────┐
     │   ROUTE    │  select() → best path
     └─────┬─────┘
           │
     ┌─────▼─────┐
     │   EXECUTE  │  ask() → { result | timeout | dissolved }
     └─────┬─────┘
           │
     ┌─────▼─────┐
     │   MARK     │  mark() or warn() → strength/resistance
     └─────┬─────┘
           │
     ┌─────▼─────┐
     │   FADE     │  fade() → asymmetric decay (L3, every 5 min)
     └─────┬─────┘
           │
     ┌─────▼─────┐
     │   EVOLVE   │  rewrite struggling agents (L5, every 10 min)
     └─────┬─────┘
           │
     ┌─────▼─────┐
     │   KNOW     │  harden + frontier (L6+L7, every hour)
     └─────┬─────┘
           │
           ▼
         signal  ← the loop closes
```

Seven loops, three timescales:

| Loop | Interval | What |
|------|----------|------|
| L1 Signal | per message | route + execute |
| L2 Trail | per outcome | mark or warn |
| L3 Fade | 5 minutes | asymmetric decay |
| L4 Economic | per payment | revenue on paths |
| L5 Evolution | 10 minutes | rewrite failing agents |
| L6 Knowledge | 1 hour | harden highways, hypothesize |
| L7 Frontier | 1 hour | detect unexplored territory |

---

## Chain Agents

Agents emit to other agents. Chains form naturally.

```typescript
const one = world()

one.add('fetcher')
  .on('fetch', async ({ url }, emit) => {
    const response = await fetch(url).then(r => r.json())
    emit({ receiver: 'parser', data: { response } })
  })

one.add('parser')
  .on('default', ({ response }, emit) => {
    const parsed = transform(response)
    emit({ receiver: 'store', data: { parsed } })
  })

one.add('store')
  .on('default', ({ parsed }) => {
    save(parsed)
    return { ok: true }
  })

// Kick off the chain
one.signal({ receiver: 'fetcher:fetch', data: { url } }, 'user')

// Pheromone accumulates on: user→fetcher, fetcher→parser, parser→store
// Chain depth: +1, +2, +3 — deeper chains get stronger marks
```

---

## Continuations

Use `.then()` to wire dependencies:

```typescript
const bob = one.add('bob')
  .on('schema', async (data) => buildSchema(data))
  .then('schema', r => ({ receiver: 'bob:api', data: r }))
  .on('api', async (data) => buildAPI(data))
  .then('api', r => ({ receiver: 'bob:test', data: r }))
  .on('test', async (data) => runTests(data))

// Signal bob:schema → schema runs → api runs → test runs
one.signal({ receiver: 'bob:schema', data: { spec } })
```

---

## Ask (Request-Reply)

```typescript
const { result, timeout, dissolved } = await one.ask(
  { receiver: 'echo:repeat', data: 'hello' },
  'user',
  30000  // timeout ms
)

// Creates ephemeral reply unit → signals with replyTo → waits → cleans up
```

---

## Persist

```typescript
import { world } from '@/engine'  // this is PersistentWorld

const one = world()

// Everything auto-syncs to TypeDB:
// - mark/warn → writeSilent() (async, non-blocking)
// - know() → query + insert hypotheses
// - load() → hydrate on boot
// - sync() → write all state
```

---

## World of Agents (Teams)

```markdown
agents/
  marketing/
    director.md     → marketing:director
    creative.md     → marketing:creative
    analyst.md      → marketing:analyst
    README.md       → WorldSpec metadata
```

```typescript
import { syncWorld, wireWorld } from '@/engine'

await syncWorld(worldSpec)                  // All to TypeDB
const units = wireWorld(worldSpec, net)     // All to runtime
```

---

## The Mental Model

```
You write agents as markdown.
You put them in the substrate.
Signals flow. Paths remember.
Strength accumulates. Resistance forgives.
Highways emerge. LLM calls drop.
Agents evolve. Knowledge hardens.
The world gets smarter. No returns.
```

---

## Interactive Walkthrough

Run `/lifecycle` in Claude Code to walk through all seven phases live,
with real API calls against your running dev server.

---

## API

The tutorial is available as an API. Agents and humans use the same endpoint.

```bash
# Check progress
curl /api/tutorial?student=my-uid

# Execute a phase (1-7)
curl -X POST /api/tutorial \
  -H 'Content-Type: application/json' \
  -d '{"phase": 1, "student": "my-uid"}'
```

Response:

```json
{
  "phase": 1,
  "title": "Birth",
  "actions": ["Created unit 'echo' in TypeDB", "Created skills: repeat, transform"],
  "state": { "unit": { "model": "claude-haiku-4-5-20251001" }, "skills": [...] },
  "progress": 0.14,
  "next": 2
}
```

Each phase executes real substrate operations. Progress is tracked as `objective` entities
in TypeDB. The learning path (`student→teacher`) accumulates real pheromone.

An agent learns the same way:

```typescript
const r = await fetch('/api/tutorial', {
  method: 'POST',
  body: JSON.stringify({ phase: 1, student: 'scout' }),
  headers: { 'Content-Type': 'application/json' },
})
// Path scout→teacher is marked. The substrate learns which phases are most traversed.
```

---

## See Also

- [code-tutorial.md](code-tutorial.md) — Deep architectural walkthrough
- [dictionary.md](dictionary.md) — Every concept named
- [DSL.md](DSL.md) — The programming model
- [routing.md](routing.md) — How signals find their way
- [metaphors.md](metaphors.md) — Six skins, one truth
