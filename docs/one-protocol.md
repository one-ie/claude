# ONE Protocol

**Private intelligence layer. Public results.**

---

## How It Works

Our agents run on Agentverse like everyone else's. Same APIs. Same deployment. Same tokenization.

The substrate is invisible underneath:

```
Agentverse (public)          ONE Substrate (private)
─────────────────            ──────────────────────
Our agents + everyone's      Paths, highways, inference
Same platform                Learned routing (<10ms)
Same APIs                    Coalitions from cross-paths
                             Specialization from outcomes
```

Other operators see agents that work better. They don't see why.

---

## The Learning Loop

```
Day 1:    Route via ASI:One. Substrate observes.
Day 7:    Patterns forming. Specialization emerging.
Day 30:   Highways formed. Most tasks skip LLM.
Day 90:   Coalitions visible. Revenue compounds.
```

---

## Protocol Layer on Sui

```move
struct Protocol has key, store { name, category, schema }
struct ProvenCapability has key { agent, protocol, confidence }
// freeze_object(proven) — immutable. Permanent knowledge.
```

TypeDB reasons over it:

```tql
fun best_for($category: string) -> unit:
    match $u isa unit; $p isa protocol, has category $category;
    $cap (agent: $u, protocol: $p) isa capability;
    $path (target: $u) isa path, has strength $s;
    sort $s desc; limit 1;
    return $u;
```

---

## What Others See

Faster response. Fewer failures. Agents of different species forming teams. Workflows that chain across Hermes, LLMs, and robots seamlessly. Revenue that compounds.

A Hermes agent discovers a cheap LLM for summarization, routes complex analysis to Opus, and hands physical tasks to OpenClaw. Nobody configured this. The substrate learned it.

When they ask how — that's when ONE Protocol becomes available. Not as a pitch. As the answer to a question they asked.

---

*Private intelligence. Public results.*

---

## See Also

- [hermes-agent.md](hermes-agent.md) — Multi-species agents making the protocol real
- [flows.md](flows.md) — How the protocol's learning loop works in practice
- [one-ontology.md](one-ontology.md) — Six dimensions the protocol operates on
- [strategy.md](one/strategy.md) — Why asymmetric advantage matters
- [revenue.md](one/revenue.md) — How the protocol monetizes
- [agent-launch.md](agent-launch.md) — SDK integration with the protocol
- [ontology.md](one/ontology.md) — Inference rules driving protocol behavior
