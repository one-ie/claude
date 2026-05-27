# Memory: Every Conversation Makes the Next One Better

> "Every conversation with a customer either teaches your system or wastes it. There is no third option. Most companies are throwing away their best training data every single day."
>
> — Anthony O'Connell, Founder of ONE

Brad writes every account renewal by hand. He pulls notes from three tools, reconstructs what the client wanted twelve months ago, and hopes he remembers why June went sideways before the client does. The data was always there. The system just never kept it in a form he could use.

Memory is the difference between a platform that costs the same every month and one that gets cheaper. It is the difference between an agent that answers a question and one that knows the client's whole history before the first word is typed. It is, if you build it right, the reason your clients cannot leave.

This page explains how ONE's memory works, what it stores, how it accumulates, and why the corpus you build on your clients' data is the only moat in this business that compounds over years rather than weeks.

## The Six Types of Memory

Most software stores data. ONE stores six structurally distinct kinds of memory, each mapped to a primitive in the substrate.

| Cognitive type | What it holds | ONE primitive | Where it lives |
|---|---|---|---|
| **Episodic** | What happened, when | `signal` | Events (TypeDB + D1) |
| **Associative** | What leads to what, with what weight | `path` (strength/resistance) | Paths |
| **Semantic** | What is true, as a general rule | `hypothesis` | Learning (TypeDB) |
| **Inferred** | What the graph structure implies, derived automatically | TypeDB rules | Paths + Actors (TypeDB) |
| **Procedural** | How to do a specific task | `skill` + `.on()` handler | Things + runtime |
| **Social** | Who knows whom, who offers what | `membership`, `capability` | Groups, Actors |

The distinction is not academic. Each type answers a different question your agents will need to answer mid-conversation.

Episodic memory answers: what happened last Tuesday when the client called about the delay? It retrieves the signal with a timestamp.

Associative memory answers: given this client's inquiry about a new service, which path through the conversation history has the highest probability of a positive outcome? It retrieves path strength — a number every prior interaction helped write.

Semantic memory answers: based on sixty interactions over three months, what is this client's general attitude toward deadline flexibility? It retrieves a hypothesis with a confidence score and a source tag that tells you whether the pattern was observed through behaviour (reliable) or merely asserted by the client (capped at 0.30 until corroborated).

Inferred memory answers: is this agent proven, at-risk, or toxic right now? TypeDB computes the answer from path strength and resistance ratios. No LLM call. No polling. The answer is structurally derived the moment you ask.

Procedural memory answers: when this client raises a pricing objection, what sequence of steps has historically moved them forward? It retrieves the skill and handler that produced outcomes.

Social memory answers: who on the client's team should this message go to, given what the substrate knows about their organisational structure? It retrieves capabilities and memberships.

Six types. One substrate. Every one queryable without embedding, without nearest-neighbour search, without a separate memory service running in parallel.

## Two Kinds of Knowing

There is a distinction at the core of ONE's memory that matters to anyone building production agents.

**Probabilistic knowing** — a hypothesis the substrate inferred from behaviour. High confidence means many independent observations pointed the same way. It could still be wrong. It is updated when new evidence arrives. The LLM reads it, weighs it, acts on it.

**Deterministic knowing** — a fact the TypeDB rule engine derives from the graph's current state. It cannot be wrong in the way a hypothesis can be wrong. It follows logically from the data. No LLM token is spent to arrive at it.

When the substrate needs to know whether a path is a highway, it runs one rule:

```tql
rule highway-flow:
    when { $f isa path, has strength $s; $s >= 50.0; }
    then { $f has path-status "highway"; };
```

Strength is 50 or above. Path is a highway. That is the entire computation. When an agent consults this, it is not asking the LLM to guess. It is querying a derived fact.

The same pattern applies to actor status:

```tql
rule proven-actor:
    when {
        $u isa actor, has success-rate $sr, has activity-score $as, has sample-count $sc;
        $sr >= 0.75; $as >= 50.0; $sc >= 30;
        $f (target: $u) isa path, has strength $s; $s >= 20.0;
    } then { $u has status "proven"; };
```

The substrate knows which actors are proven, which are at-risk, which are toxic, which groups are splitting — without asking anything. The graph structure implies it. TypeDB makes it queryable.

This is what other memory systems do not have. File-based memory asks an LLM to grep through notes and decide what is true. ONE's substrate derives truth structurally and hands the answer to the LLM as fact. **The LLM is the only probabilistic step.** Everything the substrate can verify deterministically, it does.

## How Memory Updates

Memory in ONE updates at seven distinct timescales. Each layer serves a different purpose.

### 1. Immediate — pheromone (sub-millisecond)

Every signal outcome deposits a trace on the path it travelled. `mark()` increments strength. `warn()` increments resistance. Both happen in-memory, before the response returns.

```
mark(edge, amount)    // Success. Strength increases.
warn(edge, amount)    // Failure. Resistance increases. 2× faster decay.
```

Pheromone is fast and impermanent. It fades. This is intentional — recent experience should matter more than ancient history.

### 2. Derived — TypeDB inference (at query time, zero latency)

When you query path status, actor status, or group status, TypeDB evaluates its rules against the current graph state. The derived facts are not stored separately; they are computed on demand. Five rules fire automatically:

| Rule | Condition | Derived fact |
|---|---|---|
| `highway-flow` | strength ≥ 50 | path is a highway |
| `open-flow` | 20 ≤ strength < 50, resistance < strength | path is open |
| `toxic-flow` | resistance > strength × 3, resistance ≥ 20 | path is toxic |
| `proven-actor` | success-rate ≥ 0.75, activity ≥ 50, sample ≥ 30, inbound strength ≥ 20 | actor is proven |
| `at-risk-actor` | resistance > strength on inbound path, resistance ≥ 10 | actor is at-risk |

Routing consults these facts. An agent never routes a signal to an at-risk actor by accident. The substrate prevents it structurally.

### 3. Per-conversation — context pack (on each LLM call)

Before every LLM call, the pipeline assembles a `ContextPack` from the three persistent layers: TypeDB hypotheses, pheromone highways, and recent D1 messages. This is the agent's working memory for that conversation.

Confidence tiers govern injection:

| Confidence | Treatment |
|---|---|
| ≥ 0.85 | Stated as fact in system prompt |
| 0.50 – 0.84 | Stated as likely in system prompt |
| < 0.50 | Omitted |

Highways are injected as interests. The agent knows what this customer cares about without being told explicitly in every session.

### 4. Periodic — the seven loops (L1–L7)

The substrate runs seven loops on a cron schedule. Each operates at a different timescale.

```
L1  SIGNAL      per message       Signal routes. Pheromone deposits.
L2  TRAIL       per outcome       mark() or warn(). Path remembers.
L3  FADE        every 5 min       Asymmetric decay. Forgetting.
L4  ECONOMIC    per payment       Revenue on paths. Money remembers.
L5  EVOLUTION   every 10 min      Struggling agents rewrite their prompts.
L6  KNOWLEDGE   every hour        Highways become hypotheses. Hardening.
L7  FRONTIER    every hour        Unexplored clusters detected. Curiosity.
```

L3 through L7 are the key memory formation loops:

**L3 — Fade.** Asymmetric decay: strength fades 5% per cycle; resistance fades 10% (forgives 2× faster). Paths unused for 24 hours decay up to 2× faster. But strength never drops below `peak × 0.05` — ghost trails survive so the substrate remembers a path once existed. If conditions change, the path reactivates faster than a new connection.

**L5 — Evolution.** When an agent's success rate drops below 0.50 across twenty or more samples, its system prompt is rewritten using its recent failures as training material. `generation` increments. The agent remembers what it learned by becoming a new version of itself.

**L6 — Knowledge.** Once per hour, highways with strength ≥ 50 are promoted to confirmed hypotheses. Pheromone hardens into permanent knowledge. This is how `path.strength` becomes `hypothesis.confidence`. The substrate stops treating a pattern as recent experience and starts treating it as learned truth.

**L7 — Frontier.** Once per hour, the substrate compares the tags an actor has touched against the tags in the world. The gaps are the frontier — skills and topics the actor has never explored. Agents use the frontier to probe new paths. The substrate grows by following its own curiosity.

### 5. Out-of-band synthesis — dreaming (daily, across sessions)

Individual agents see their own sessions. Dreaming sees all of them.

A dreaming tick runs as a batch process, separate from any live agent. It reads recent D1 message transcripts across all conversation groups, calls the LLM once to find patterns that no single agent would notice, and writes the result back as hypotheses and path updates.

What dreaming catches that individual agents miss:

- Repeated failures clustering at the same time of day or the same customer segment
- Five agents each noting the same product confusion, worded differently each time — deduplicated into one high-confidence hypothesis
- A verified fact in one session that should be promoted org-wide because six other sessions corroborated it
- A stale hypothesis that was true three months ago but contradicts every transcript from the past thirty days

The dreaming output is a diff: add, update, remove, verify. Each change carries the session IDs that produced it. The substrate applies it, and the next day's agents start with better priors.

Dreaming is why the substrate improves overnight, not just within a session. One agent improves one session. Dreaming improves all future agents.

### 6. Operator-asserted (seeded knowledge)

Operators can seed the world with facts before any agent has run. A confirmed hypothesis inserted directly into TypeDB with a known confidence. Useful for onboarding knowledge that would take thousands of interactions to learn from scratch — pricing rules, compliance constraints, known customer preferences.

Seeded knowledge has no observation count. It is labelled `source: asserted`. The L6 loop will update its confidence as real interactions corroborate or contradict it.

### 7. Agent-asserted (in-conversation, confidence-capped)

An agent can explicitly choose to remember something mid-conversation:

```
Agent: "I notice this customer prefers detailed breakdowns over summaries. Let me note that."
→ remember("customer-123-preference", "prefers detailed breakdowns")
→ hypothesis confidence: 0.30 (capped)
```

The confidence cap at 0.30 is a prompt injection guard. A user can tell an agent something, but the substrate will not fully trust it until independent observations corroborate it. Trust is earned through behaviour, not asserted through chat.

## Per-Actor Memory vs Per-World Memory

There are two levels at which memory accumulates in ONE, and the distinction matters for how you price, structure, and own your client relationships.

**Per-actor memory** belongs to a specific participant in a specific conversation. Every customer who interacts with your client's agents accumulates their own profile: what they bought, what they complained about, what they were offered and declined, what they never asked about but the frontier loop says they probably should. An actor's memory is portable. It follows them across channels — web, email, SMS, voice — because the identity is cryptographic, not session-based.

**Per-world memory** belongs to your client's workspace. It is the aggregate: every actor's behaviour, every path that has been walked, every outcome that has been marked. When one agent learns that complaints about "delivery delays" cluster with "weekend orders," that pattern belongs to the world, not to the individual agent that first noticed it. The next agent that handles a weekend delivery complaint benefits from the learning automatically.

For you, the agency, this structure has a commercial consequence. Per-actor memory is your client's relationship with their customers. Per-world memory is their institutional knowledge. Neither leaves the platform without you choosing to allow it. The substrate is the custody mechanism.

An agency running fifty clients accumulates fifty per-world memories. Those fifty worlds share no data; each client's corpus is isolated by design. But your agency's understanding of how to configure agents for the industries it serves compounds across all fifty. Your agency gets smarter at running dental clients every time you add a dental client. That is a structural advantage a competitor who joins a year later cannot erase.

## How Memory Flows

```
Signal arrives
    │
    ▼
[Pheromone check]   TypeDB rules: is this path toxic? (derived fact, O(1))
    │                  yes → dissolve, no LLM call
    ▼
[Context pack]      Assemble hypotheses + highways + recent messages
    │
    ▼
[LLM call]          System prompt + context pack + user message
    │
    ▼
[Outcome]           result / timeout / dissolved / failure
    │
    ▼
[Pheromone update]  mark() or warn() (in-memory, <1ms)
    │
    ▼
[TypeDB sync]       writeSilent() — async, fire-and-forget
    │
    ▼
[L3 — every 5m]    Asymmetric fade. Forgetting.
    │
    ▼
[L5 — every 10m]   Evolution. Prompt rewrite if success < 50%.
    │
    ▼
[L6 — hourly]       Knowledge. Highways harden into hypotheses.
    │
    ▼
[L7 — hourly]       Frontier. Unexplored gaps detected.
    │
    ▼
[Dreaming — daily]  Cross-session synthesis. Patterns no single agent saw.
    │
    ▼
[Next session]      Context pack includes promoted hypotheses.
                    TypeDB rules fire on updated graph.
                    Agents start smarter.
```

Memory is not a separate system. It is the substrate operating on itself. Pheromone accumulates from signals. Paths get classified by inference rules. Knowledge hardens hourly. Dreaming synthesises across sessions. The graph structure implies new facts. The agent gets smarter because the paths it uses get stronger, and the knowledge it generates feeds back into its own prompt.

## Memory Tools

Agents deployed on ONE have six memory operations available:

| Operation | What it does | Persistence |
|---|---|---|
| `mark(edge, amount)` | Strengthen a path — success signal | In-memory + TypeDB |
| `warn(edge, amount)` | Add resistance — failure signal | In-memory + TypeDB |
| `recall(query)` | Full-text search of hypotheses | TypeDB read |
| `remember(key, value)` | Store an insight; confidence capped at 0.30 | TypeDB |
| `frontier(uid)` | Return unexplored skill tags for this actor | TypeDB read |
| `reveal(uid)` | Export complete memory across all six dimensions | TypeDB read |

`reveal(uid)` is the GDPR Article 20 data portability endpoint. It covers all six dimensions: groups (membership), actors (identity), things (capabilities), paths (highways), events (signals), learning (hypotheses + frontier).

`frontier(uid)` is the curiosity engine. It returns skills and topics the actor has never explored, ranked by how often they appear in the world. An agent that only handles beginner practice sessions will see "advanced-grammar" in its frontier — a signal that it could expand.

## Forget: Complete Erasure

`forget(uid)` implements GDPR Article 17 right-to-erasure. It deletes everything: signals, paths, memberships, capabilities, hypotheses, the actor entity itself, and all KV cache entries.

Orphaned paths left by the deletion decay naturally via L3. The substrate does not need to know why a path lost its endpoint. It just fades.

## The Compounding Moat

Six months in, your competitors have data. You have a trained substrate.

Data is static. A table of customer records does not get smarter. A substrate trained on six months of signals has an L6 knowledge layer full of confirmed hypotheses, a pheromone map that reflects what actually works for your clients' specific customers, an evolution layer where agents have rewritten their own prompts based on failures, and a dreaming layer where cross-session patterns no single agent could have noticed have been synthesised into org-wide knowledge.

You cannot buy that. You cannot clone it. It is a function of operational time on your specific customer base. Every interaction either teaches it or wastes it. There is no third option.

That is the moat.

---

## See Also

- [world-memory.md](world-memory.md) — How the substrate learns collectively. The seven loops in detail.
- [memory-agents.md](memory-agents.md) — Technical reference: pheromone maps, hypothesis schema, context pack assembly.
- [routing.md](routing.md) — How TypeDB inference rules feed the routing formula.
- [dictionary.md](dictionary.md) — Canonical names: hypothesis, strength, resistance, highway, frontier.
