# 100 + 100

200 lines. The complete substrate. Schema + engine. Read top to bottom — it's a journey.

---

## Part 1: The Schema (TypeQL)

```typeql
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  THE SCHEMA — 100 lines. Six dimensions. One world.                     ║
# ║  The engine ACTS in memory. The schema REMEMBERS in TypeDB.              ║
# ║  Inference rules fire automatically. Functions query intelligence.       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

define

# ── DIMENSION 1: GROUPS ─────────────────────────────────────────────────────
# Containers. A colony of ants. A team of engineers. A DAO of agents.

entity group,
    owns sid @key,                  # unique identifier
    owns name,                     # human-readable label
    owns group-type,               # "persona" | "team" | "colony" | "dao"
    owns status,                   # "active" | "dormant"
    plays hierarchy:parent,        # swarms nest inside swarms
    plays hierarchy:child,
    plays membership:group;        # units belong to swarms

relation hierarchy, relates parent, relates child;

# ── DIMENSION 2: ACTORS ─────────────────────────────────────────────────────
# Who acts. Human, agent, LLM, robot, insects — all are units.
# Status is INFERRED from success-rate + activity + sample-count.

entity unit,
    owns uid @key,
    owns name,
    owns unit-kind,                # "human" | "agent" | "llm" | "system"
    owns wallet,                   # Sui address for x402 payments
    owns status,                   # INFERRED: "active" | "proven" | "at-risk"
    owns success-rate,             # 0.0–1.0 — classification input
    owns activity-score,           # 0.0–100.0 — classification input
    owns sample-count,             # interaction count — classification input
    plays path:source, plays path:target,
    plays capability:provider,
    plays membership:member,
    plays signal:sender, plays signal:receiver;

# ── DIMENSION 3: THINGS ─────────────────────────────────────────────────────
# Tasks. A task with a price IS a service. price:0 = free, price:>0 = paid.

entity task,
    owns tid @key,
    owns name,                     # "translate", "analyze", "deploy"
    owns task-type,                # "work" | "inference" | "data" | "compute"
    owns status,                   # "todo" | "in_progress" | "complete" | "blocked"
    owns price,                    # x402 price (0 = free work)
    owns currency,                 # "SUI" | "USDC" | "FET"
    owns attractive,               # INFERRED: strong trail + no blockers
    plays dependency:dependent, plays dependency:blocker,
    plays capability:skill,
    plays trail:source-task, plays trail:destination-task;

relation dependency, relates dependent, relates blocker;

# ── DIMENSION 4: PATHS ──────────────────────────────────────────────────────
# Weighted connections. mark() adds strength. warn() adds resistance.
# fade() decays both. This IS the pheromone trail. The learned knowledge.

relation path,                     # unit ←→ unit
    relates source, relates target,
    owns strength,                 # mark() increments — success
    owns resistance,                    # warn() increments — failure
    owns traversals,               # signal count
    owns revenue,                  # sum of x402 payments
    owns path-status;              # INFERRED: "highway" | "fading" | "toxic"

relation trail,                    # task → task (what sequence works)
    relates source-task, relates destination-task,
    owns trail-pheromone,          # success weight (0–100)
    owns resistance-pheromone,          # failure weight (0–100)
    owns completions, owns failures,
    owns trail-status;             # INFERRED: "proven" | "fading" | "dead"

relation capability, relates provider, relates skill, owns price;
relation membership, relates group, relates member;

# ── DIMENSION 5: EVENTS ─────────────────────────────────────────────────────
# Every signal recorded. Who sent what, when, for how much.
# Raw data that dimensions 4 and 6 learn from.

relation signal,
    relates sender, relates receiver,
    owns data,                     # JSON payload
    owns amount,                   # x402 payment (0 = free)
    owns success,                  # did the task succeed?
    owns latency, owns ts;         # how long, when

# ── DIMENSION 6: KNOWLEDGE ──────────────────────────────────────────────────
# What emerged. Not programmed — inferred from dimensions 1–5.

entity hypothesis,
    owns hid @key,
    owns statement,                # "translator-1 is best for Spanish"
    owns hypothesis-status,        # "pending" | "testing" | "confirmed" | "rejected"
    owns p-value, owns action-ready;  # INFERRED when confirmed + p<=0.05

entity frontier,
    owns fid @key,
    owns frontier-description,     # "unexplored task combination"
    owns expected-value,           # potential × probability / cost
    owns frontier-status;          # "unexplored" | "exploring" | "exhausted"

# ── FUNCTIONS ────────────────────────────────────────────────────────────────
# TypeDB 3.x uses fun (NOT rule). Functions are the classifier layer.
# Call them in queries. They classify, route, and aggregate on demand.

# Classify path: highway (strong), fading (weak), toxic (resistance > strength)
fun path_status($e: path) -> string:
    match $e has strength $s, has resistance $a, has traversals $t;
    return first
        if ($a > $s and $a >= 10.0) then "toxic"
        else if ($s >= 50.0) then "highway"
        else if ($s >= 10.0 and $t < 10) then "fresh"
        else if ($s > 0.0 and $s < 5.0) then "fading"
        else "active";

# Classify unit: proven (reliable), at-risk (failing)
fun unit_classification($u: unit) -> string:
    match $u has success-rate $sr, has activity-score $as, has sample-count $sc;
    return first
        if ($sr >= 0.75 and $as >= 70.0 and $sc >= 50) then "proven"
        else if ($sr < 0.40 and $as >= 25.0 and $sc >= 30) then "at-risk"
        else "active";

# Who should handle this task? Follow the strongest path.
fun optimal_route($from: unit, $task: task) -> actor:
    match (source: $from, target: $to) isa path, has strength $s;
          (provider: $to, skill: $task) isa capability;
    sort $s desc; limit 1; return $to;

# What are the proven paths? The colony's highways.
fun highways($threshold: double, $limit: long) -> { path }:
    match $e isa path, has strength $s; $s >= $threshold;
    sort $s desc; limit $limit; return { $e };

# What tasks can start now? No blockers, all clear.
fun ready_tasks() -> { task }:
    match $t isa task, has status "todo";
          not { (dependent: $t, blocker: $b) isa dependency;
                $b has status $bs; not { $bs == "complete"; }; };
    return { $t };

# Which units have earned trust through repeated success?
fun proven_actors() -> { actor }:
    match $u isa unit, has status "proven";
    return { $u };

# How much has the colony earned? Sum of all path payments.
fun total_revenue() -> double:
    match $e isa path, has revenue $r; return sum($r);

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  6 dimensions  — groups, actors, things, paths, events, knowledge       ║
# ║  2 classifiers — path_status, unit_classification                       ║
# ║  5 queries     — route, highways, ready, proven, revenue                ║
# ║  The engine ACTS. The schema REMEMBERS. Functions REASON.               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
```

---

## Part 2: The Engine (TypeScript)

```typescript
// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  THE ENGINE.                                                            ║
// ║                                                                         ║
// ║  100 lines. Two fields. Zero returns.                                   ║
// ║                                                                         ║
// ║  Ants discovered this 100 million years ago.                            ║
// ║  Drop a signal. Follow the weight. Highways emerge.                     ║
// ║  No ant decides. The colony learns.                                     ║
// ╚═══════════════════════════════════════════════════════════════════════════╝


// ── THE SIGNAL ──────────────────────────────────────────────────────────────
//
//  The universal primitive. Everything that moves through the substrate
//  is a signal. Two fields. That's it.
//
//    receiver: where it's going    "scout" or "scout:observe"
//    data:     what it carries     anything — or nothing
//
//  Ants carry chemical signals. Neurons fire electrical signals.
//  Agents carry digital signals. Same pattern. Same substrate.

export type Signal = { receiver: string; data?: unknown }

// Emit: how a task sends signals out into the world
export type Emit = (s: Signal) => void

// Task: the work a unit does when a signal arrives
//   data  — what the signal carried
//   emit  — function to send more signals (fan out)
//   ctx   — who sent this (from) and who I am (self)
type Task = (data: unknown, emit: Emit, ctx: { from: string; self: string }) => Promise<unknown>

// Template: after a task completes, this shapes the next signal
type Template = (result: unknown) => Signal

// Route: how a unit sends signals back into the colony
type Route = (s: Signal, from: string) => void


// ── THE UNIT ────────────────────────────────────────────────────────────────
//
//  A unit is anything that receives signals and does work.
//  An agent? A unit. A payment processor? A unit. An LLM? A unit.
//  They differ in what tasks they handle, not in what they are.
//
//  .on(name, fn)        — "when signal arrives, do this"
//  .then(name, tmpl)    — "after task completes, send this next"
//  .role(name, task, c) — "a preset variant with extra context"

export const unit = (id: string, route?: Route) => {
  const tasks: Record<string, Task> = {}    // task registry: name → handler
  const next: Record<string, Template> = {} // continuations: name → next signal

  // When a signal arrives: parse the task name, find the handler, run it
  const u = ({ receiver, data }: Signal, from = 'entry') => {
    const name = receiver.includes(':') ? receiver.split(':')[1] : 'default'
    const task = tasks[name] || tasks.default  // fall back to default

    const emit: Emit = s => route?.(s, receiver)       // emit sends through colony
    const ctx = { from, self: receiver }                // who called me, who am I

    // Execute task. If it has a continuation (.then), fire the next signal.
    // Missing task? Nothing happens. Signal dissolves. Group continues.
    task?.(data, emit, ctx).then(result =>
      next[name] && route?.(next[name](result), receiver)
    )
  }

  // .on() — register a task. Wraps sync functions in Promise.resolve.
  u.on = (n, f) => (tasks[n] = (d, e, c) => Promise.resolve(f(d, e, c)), u)

  // .then() — define what happens after task completes
  u.then = (n, t) => (next[n] = t, u)

  // .role() — preset: merges extra context into data before calling the real task
  u.role = (n, t, ctx) => (tasks[n] = (d, e, c) =>
    tasks[t]?.({ ...ctx, ...(d as object) }, e, c) ?? Promise.resolve(null), u)

  // Introspection: does this task exist? what tasks do I have? who am I?
  u.has = n => n in tasks
  u.list = () => Object.keys(tasks)
  u.id = id
  return u
}


// ── THE COLONY ──────────────────────────────────────────────────────────────
//
//  The colony is the world. Units live here. Signals flow here.
//  Paths form here. Highways emerge here.
//
//  units:  who lives in the colony          { id → unit }
//  strength:  the memory of what worked        { "a→b" → weight }
//
//  No central controller. No message queue. No router table.
//  Just signals, weight, and time.

export const colony = () => {
  const units: Record<string, Unit> = {}   // the population
  const strength: Record<string, number> = {} // the shared memory (pheromone trails)

  // MARK — mark weight on a path. This is how the colony remembers.
  // Every successful signal strengthens the path it traveled.
  const mark = (path: string, strength = 1) => {
    strength[path] = (strength[path] || 0) + strength
  }

  // SENSE — read the weight on a path. How strong is this trail?
  const sense = (path: string) => strength[path] || 0

  // SIGNAL — the heartbeat. Move a signal through the world.
  //   1. Parse receiver to find the target unit
  //   2. If target exists: mark the path (it was used), then deliver
  //   3. If target missing: nothing. Signal dissolves. No error. No return.
  const signal = ({ receiver, data }: Signal, from = 'entry') => {
    const id = receiver.includes(':') ? receiver.split(':')[0] : receiver
    const target = units[id]
    target && (mark(`${from}→${receiver}`), target({ receiver, data }, from))
  }

  // SPAWN — birth a new unit into the world.
  // Wires the unit's emit back into world.signal, closing the loop.
  const spawn = (id: string) => {
    const u = unit(id, (s, from) => signal(s, from))
    units[id] = u
    return u
  }

  // FOLLOW — find the strongest trail matching a type.
  // This is how the colony routes: not by rules, but by what worked before.
  const follow = (type?: string) =>
    Object.entries(strength)
      .filter(([e]) => !type || e.includes(type))
      .sort(([, a], [, b]) => b - a)[0]
      ?.[0].split('→').pop()?.split(':')[0] || null

  // FADE — time passes. All paths decay. Forgetting is intelligence.
  // Unused paths weaken. Used paths survive. Highways persist.
  // rate=0.1 means every path loses 10% per tick.
  const fade = (r = 0.1) => Object.keys(strength).forEach(e => {
    strength[e] *= (1 - r)
    strength[e] < 0.01 && delete strength[e]  // below threshold? forgotten.
  })

  // HIGHWAYS — query what emerged. The top paths by weight.
  // These are the colony's accumulated intelligence.
  const highways = (limit = 10) =>
    Object.entries(strength)
      .sort(([, a], [, b]) => b - a)
      .slice(0, limit)
      .map(([path, strength]) => ({ path, strength }))

  // Introspection
  const has = (id: string) => id in units
  const list = () => Object.keys(units)
  const get = (id: string) => units[id]

  return { units, strength, spawn, signal, mark, sense, follow, fade, highways, has, list, get }
}


// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  100 lines.                                                             ║
// ║                                                                         ║
// ║  signal  — move through world                                           ║
// ║  mark    — leave weight on path                                         ║
// ║  follow  — traverse strongest trail                                     ║
// ║  fade    — paths decay with time                                        ║
// ║  highway — what survived is knowledge                                   ║
// ║                                                                         ║
// ║  No ant decides. The colony learns.                                     ║
// ╚═══════════════════════════════════════════════════════════════════════════╝
```

---

## The Schema Journey

```
Lines 1–8      GROUPS (Dimension 1)
               Containers. Colonies, teams, DAOs.
               Swarms nest inside swarms. Units belong to swarms.

Lines 9–20     ACTORS (Dimension 2)
               Who acts. Humans, agents, LLMs, systems.
               All are units. Status is INFERRED from performance.

Lines 21–32    THINGS (Dimension 3)
               Tasks with optional price. Task + price = service.
               Blockers form dependency chains.

Lines 33–48    PATHS (Dimension 4)
               Weighted connections. The pheromone trails.
               mark() → strength. warn() → resistance. fade() → decay.
               Unit↔unit paths. Task→task trails. Capability links.

Lines 49–55    EVENTS (Dimension 5)
               Every signal recorded. Who, what, when, how much.
               Raw data that dimensions 4 and 6 learn from.

Lines 56–64    KNOWLEDGE (Dimension 6)
               Hypotheses, frontiers. Not programmed — inferred.
               The colony's intelligence, known.

Lines 65–100   FUNCTIONS
               TypeDB 3.x uses fun, not rule. Functions are the classifier layer.
               path_status() classifies: highway, fading, toxic.
               unit_status() classifies: proven, at-risk.
               optimal_route() follows the strongest path.
               highways() discovers proven paths. ready_tasks() finds work.
               The engine ACTS. The schema REMEMBERS. Functions REASON.
```

## The Engine Journey

```
Lines 1–10     THE SIGNAL
               Two fields. receiver + data. That's all that flows.

Lines 11–20    THE UNIT
               Anything that receives a signal. Tasks + continuations.
               .on() to handle. .then() to chain. .role() to preset.

Lines 21–45    Unit internals
               Parse receiver → find task → execute → continue.
               Missing handler? Signal dissolves. Zero returns.

Lines 46–55    THE COLONY
               Units live here. Scent (weight) accumulates here.
               No router. No queue. Just weight and time.

Lines 56–60    MARK
               Drop weight on a path. +1 per signal. The memory.

Lines 61–70    SIGNAL
               Parse → find → mark → deliver. The heartbeat.

Lines 71–75    SPAWN
               Birth a unit. Wire its emit back into world.signal.
               The loop closes.

Lines 76–82    FOLLOW
               Find the strongest trail. Route by what worked.
               Not by rules — by accumulated evidence.

Lines 83–90    FADE
               All paths decay. 10% per tick. Below 0.01? Forgotten.
               This is how the colony forgets what stopped working.

Lines 91–98    HIGHWAYS
               Query the top paths. This is the colony's intelligence.
               What survived fade is proven. What's proven is knowledge.

Lines 99–100   RETURN
               Expose everything. The colony is transparent.
               Agents can read the strength graph. The world is open.
```

---

## How They Connect

```
         SCHEMA (TypeDB)                    ENGINE (TypeScript)
         remembers                          acts
         ────────────────                   ────────────────

         group, unit, task                  world.add(id)
              ↕                                  ↕
         path { strength, resistance }           world.mark(path)
              ↕                                  ↕
         signal { sender, receiver }        world.signal({ receiver, data })
              ↕                                  ↕
         fun path_status(): highway/fading   world.highways(10)
              ↕                                  ↕
         fun optimal_route()                world.follow(type)
              ↕                                  ↕
         hypothesis, frontier               what the colony explores next
```

```
signal → unit → task → emit → mark → persist → infer → route
  ↑                                                       │
  └───────────────────────────────────────────────────────┘
```

```
DROP                   FADE
  │                     │
  ▼                     ▼
weight++           weight × 0.9
  │                     │
  ▼                     ▼
more signals       reroute
  │                     │
  ▼                     ▼
HIGHWAY            dissolve
```

---

*100 + 100 lines. Schema remembers. Engine acts. World learns.*

---

## See Also

- [tutorial.md](tutorial.md) — Build a world in 5 minutes
- [code-tutorial.md](code-tutorial.md) — Deep architectural walkthrough
- [events.md](one/events.md) — The universal primitive
- [people.md](one/agents.md) — Agent patterns built on these 200 lines
- [knowledge.md](one/knowledge.md) — How complexity emerges from simple rules
- [one-ontology.md](one-ontology.md) — The 6 dimensions explained
- [substrate-learning.md](substrate-learning.md) — Learning without gradients
