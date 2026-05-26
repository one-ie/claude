# Sui + TypeQL — the substrate for the agent economy

> Truth. Meaning. Learning. One closed loop.
>
> Sui is what *is* — deterministic, linear, finalized. TypeQL is what *follows* — typed, polymorphic, derivable. ONE is what *works* — paths that compound, paths that fade. Bind the three and you get a substrate where an agent's authority is provable, its action is atomic, and its track record is the gradient the system descends.

This doc names the fusion. It is not a build plan. It is the spec the build plans cite. See `agents.md` for the four agent patterns, `passkeys.md` for human/agent root-of-trust, `wallet.md` for lifecycle phases, `x402.md` for the payment protocol, and `one-ie/one/.claude/rules/engine.md` for the three locked rules the runtime enforces.

---

## The claim, in one paragraph

Blockchains gave us **economic action without reasoning** — smart contracts are imperative; the chain enforces "what happened," not "what follows." Knowledge graphs gave us **reasoning without action** — TypeDB infers, but cannot settle. Pheromone substrates gave us **adaptation without semantics** — paths strengthen, but the system has no native concept of *what* they connect. The agent economy needs all three in one loop: *every action carries its own derivation as a proof, every proof is gated by paths that the substrate has learned to trust, and every receipt re-weights the next derivation*. Sui supplies the action layer. TypeQL 3.0 supplies the reasoning layer. The ONE substrate (`one-ie/one/`) binds them with pheromone. Nobody has shipped this triple before.

---

## The three layers

```
┌──────────────────────────────────────────────────────────────────────┐
│  TRUTH LAYER — Sui                                                    │
│  ────────────────                                                     │
│  what IS · deterministic · linear · finalized                         │
│  object-centric state, Move execution, sub-second finality            │
│  PTBs · capabilities-as-objects · sponsored tx                        │
└──────────────────────────────────────────────────────────────────────┘
              ▲                                            │
              │ events flow back                           │ proofs reference
              │ (canonical receipts)                       │ on-chain object IDs
              │                                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  MEANING LAYER — TypeQL 3.0 / TypeDB                                  │
│  ────────────────────────────────────                                 │
│  what FOLLOWS · typed · polymorphic · derivable                       │
│  PERA schema · n-ary relations · rules · functions · subtyping        │
│  the brain — knows what an event MEANS, derives what's authorized     │
└──────────────────────────────────────────────────────────────────────┘
              ▲                                            │
              │ classified events                          │ inferred state
              │ become substrate signals                   │ gates path selection
              │                                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  LEARNING LAYER — ONE substrate                                       │
│  ───────────────────────────────                                      │
│  what WORKS · compounded · non-monotonic · forgetful                  │
│  paths (strength/resistance) · pheromone (mark/warn/fade)             │
│  L1-L7 loops · agent evolution (L5) · knowledge harden (L6)           │
└──────────────────────────────────────────────────────────────────────┘
```

| Layer | Time scale | Truth standard | What it compounds |
| --- | --- | --- | --- |
| Sui | sub-second | finality | settled value |
| TypeQL | per-query | consistency | derivable facts |
| ONE | per-cycle | verified receipts | learned trust |

The layers do not collapse into each other. Sui does not reason; TypeQL does not settle; ONE does not infer or finalize. Each is sovereign in its own logic. The substrate is the binding of the three.

---

## Sui — what's actually new for agents

Sui is not "another blockchain." Two design choices make it the right truth layer for an agent economy:

### 1. Object-centricity

Every asset on Sui is a first-class **object** with a stable `ObjectID`. Not a balance in a mapping. Not a row in a contract's storage. An object — typed, owned, transferable, composable. An agent's authority lives in an object. An agent's wallet is an object graph. A capability is an object.

This matters because **agents speak in object handles, not addresses**. Address-based chains force agents to reason about state at the contract level ("does account X have balance ≥ Y?"). Object-centric chains let agents reason at the asset level ("do I hold capability Z?"). Sui object IDs are the natural primary keys for TypeQL entities.

### 2. Capabilities as objects

The Move capability pattern: holding a `Cap` object grants the right to call protected functions. Caps are typed Move resources — they cannot be forged, copied, or silently destroyed (linearity). Authority becomes a transferable thing, not a list in a config file.

For agents this is everything. An agent's *power* is the set of caps it holds. An agency that delegates a sub-task transfers a scoped cap. A revocation is a destroyed cap. There is no "permission system" — there is just *which objects are in your inventory*.

### Sui's universal laws

| Law | What it means |
| --- | --- |
| **Linearity** | A Move resource cannot be copied or dropped silently. Move it, store it, or burn it — but it never just disappears. |
| **Ownership** | Every object has exactly one owner state: an address, shared, immutable, or child-of-another-object. No ambiguity. |
| **Composability** | A Programmable Transaction Block (PTB) chains operations atomically. Multiple calls succeed together or fail together. |
| **Finality** | Once consensus commits, the world is committed. No reorgs at the object level. |
| **Capability-as-object** | Authority equals holding the object. There is no separate ACL system. |
| **Determinism** | Same inputs produce the same outputs. Move execution is reproducible. |

### What Sui *doesn't* give you

Sui does not derive consequences. If `Curator` and `Treasurer` are both held, Sui does not know that this implies `BudgetApproval up to N` unless a Move function explicitly encodes it. Imperative-only authorization is a ceiling — you cannot express "the rules that follow from the rules" without compiling new bytecode. This is the gap TypeQL closes.

---

## TypeQL 3.0 — what's actually new for substrates

TypeDB is not "another graph database." Three design choices make it the right meaning layer.

### 1. PERA — polymorphic entities, relations, attributes

Entities, relations, and attributes are all **types** organized in a subtype hierarchy. `match $x isa thing` returns every subtype. `match $x isa receipt` returns every subtype of receipt — payment receipts, refund receipts, gas receipts — without an OR clause per subtype. A schema change ripples through every query that touches a parent type.

For an agent substrate, this is **the schema is the renderer, the validator, and the classifier — at the same time**. You write the taxonomy of agent actions once, and every surface (UI, audit, dispute resolution) reads from the same source.

### 2. Rules — derivable facts

TypeQL rules let you say "if pattern A holds, then fact B is derivable." Derived facts have the same standing as stored facts; they appear in `match` results identically. Add a rule and existing queries get smarter. Remove a rule and the derivations disappear cleanly.

```
rule curator-with-treasury-can-approve-budget:
  when {
    $a isa agent, has capability $cur, has capability $treas;
    $cur isa curator-capability;
    $treas isa treasurer-capability;
  } then {
    (approver: $a) isa budget-approval-authority;
  };
```

The agent does not need to *be granted* the derived authority. The schema *implies* it. This is declarative authorization — the thing every "permission system" in software history has tried and failed to be.

### 3. Functions (new in TypeQL 3.0)

TypeQL 3.0 introduces typed query functions. They are composable, reusable, callable from other queries, and statically typed against the schema. A function that returns "is action X authorized for agent Y?" is now a first-class object in the meaning layer — versionable, testable, signable.

The sponsor Worker (see `apps/enoki-play/src/routes/sponsored/sponsored.remote.ts` for the Sui-side shape we adopt) does not hard-code authorization. It calls a TypeQL function. The function is the law.

### TypeQL's universal laws

| Law | What it means |
| --- | --- |
| **Typedness** | Every entity, relation, attribute belongs to a type. Untyped data does not exist. |
| **Polymorphism** | Query a parent type; receive the whole subtype tree. Schema evolution is non-breaking by default. |
| **Symmetry** | Relations are not "owned" by either side; they exist as facts equidistant from their roles. |
| **Inference** | Derived facts are first-class. The system reasons; it does not just retrieve. |
| **Determinism** | Same schema + same data + same query = same answer, every time. |
| **Consistency** | ACID. The brain does not get caught in inconsistent states mid-query. |

### What TypeQL *doesn't* give you

TypeQL does not settle anything. It cannot transfer value. It cannot enforce that an inferred authority was acted upon, or that a "should" became a "did." It also cannot learn — it is monotonic within a schema; the rules are what you wrote. This is the gap the ONE substrate closes.

---

## The ONE substrate — what binds them

The substrate (full spec in `one-ie/one/CLAUDE.md` and `one-ie/one/.claude/rules/engine.md`) provides:

| Capability | Mechanism | Where |
| --- | --- | --- |
| **Universal primitive** | `Signal { receiver, data? }` — single shape, infinite uses | `web/src/engine/world.ts` and substrate runtime |
| **Path memory** | `mark(edge, strength)` / `warn(edge, strength)` accumulate on every edge | path strength + resistance in TypeDB |
| **Asymmetric forgetting** | `fade()` decays paths every 5 min; resistance fades 2× faster than strength | L3 loop |
| **Self-improvement** | Agents whose prompts produce failing chains evolve their prompt (`L5`) | every 10 min |
| **Hardening** | Recurring strong paths get promoted to typed hypotheses (`L6`) | every hour |
| **Frontier detection** | Tag clusters with no traffic surface as unexplored opportunities (`L7`) | every hour |

The substrate's three locked rules from `engine.md` are the seal on the loop:

1. **Closed loop** — every signal closes with `mark`, `warn`, or `dissolve`. Width only compounds if every parallel branch deposits.
2. **Structural time only** — plan in tasks → waves → cycles. Pheromone compounds in structural time; calendar time is for the L1-L7 wall-clock tick, not for planning.
3. **Deterministic results in every loop** — every loop reports verified numbers. Strength without verification is superstition.

These three are what make the third layer load-bearing. Without (1), signals leak — Sui receipts arrive but no path is marked. Without (2), waves and cycles blur — you cannot tell whether agent X improved or just retried. Without (3), the gradient is hallucinated.

---

## The fusion — laws of the combined substrate

Five laws emerge from binding the three layers. None is novel in isolation; together they describe a system that has never existed.

| Law | Statement |
| --- | --- |
| **Truth before meaning** | TypeQL only reasons about events that Sui has finalized. Pre-finality state may be observed, but no rule fires on it. (No race-conditioned authority.) |
| **Meaning before learning** | Pheromone is keyed on *classified* edges, not raw events. A payment from A to B is not the same path as a refund from A to B. Classification is TypeQL's job. |
| **Learning before action** | Path strength gates which signals fire next. Weak paths cost more (sponsorship pricing); strong paths are the default route. |
| **Proof before execution** | No PTB signs without a derivation chain from TypeQL showing "this action is authorized under these rules." The chain is auditable. |
| **Receipt after execution** | Every finalized Sui transaction emits a substrate event. That event becomes a TypeQL fact. That fact updates derivable authority. The path is marked. The loop closes. |

The order matters. Reverse any pair and you get a known anti-pattern (e.g., "learning before meaning" is what blind RL bots do — they reward raw events and optimize the wrong gradient).

---

## Probabilistic and deterministic inference — the phase transition

A substrate that is *only* deterministic is dead — it cannot generalize, cannot generate, cannot adapt to events its schema never anticipated. A substrate that is *only* probabilistic is unaccountable — it cannot prove, cannot finalize, cannot be held to a rule. The agent economy needs both, and the elegance is in how cleanly they hand off.

### Two phases of cognition

**Probabilistic inference is liquid.** It flows. It samples. It generalizes by similarity. LLM token streams, embedding distances, pheromone strength, path decay rates — all liquid. They move continuously through a smooth space; nothing is *exactly* anything; the next sample is allowed to differ.

**Deterministic inference is crystal.** It commits. It derives. It gates by type. TypeQL rule chains, Move execution, mark/warn arithmetic, Sui finality — all crystalline. Every face is sharp. The same query against the same schema returns the same answer on every run.

Neither phase is "the real one." Each does what only it can do, and the *transitions between them* are where the substrate's intelligence lives.

### The handshake — freezing and melting

```
        LIQUID                                           CRYSTAL
        (probabilistic, generative)                      (deterministic, derivative)
        ───────────────────────────                      ─────────────────────────

           LLM intent          ── L1 signal     ──▶      typed receiver
           embedding cluster   ── L7 frontier   ──▶      proposed entity
           pheromone field     ── L6 hardening  ──▶      derived rule         [FREEZING]
           prompt variant      ── L5 evolution  ──▶      committed prompt

           decayed path        ◀─ L3 fade       ──       rule deprecated
           warned edge         ◀─ L2 warn       ──       cap revoked          [MELTING]
```

Six forward handshakes — *probability proposes, determinism disposes*:

| # | Handshake | Probability side | Determinism side |
| --- | --- | --- | --- |
| 1 | **Intent → signal** | LLM emits free-text intent under ambiguity | TypeQL receiver schema accepts or dissolves the signal |
| 2 | **Path → action** | `select()` samples by pheromone weight | `follow()` returns the deterministic best path |
| 3 | **Multi-proof choice** | many rule chains may authorize an action | one chain is attached to the PTB; pheromone breaks the tie |
| 4 | **Pheromone → rule** | recurring strong path observed (L6) | hardened into a typed TypeQL hypothesis — the schema *grows from its own learning* |
| 5 | **Prompt mutation** | L5 generates prompt variants | committed prompt becomes new deterministic behavior until next L5 |
| 6 | **Frontier → entity** | L7 surfaces unexplored embedding clusters | DAO ratifies a new TypeQL entity type; queries re-cover the space |

Three reverse handshakes — *truth dissolves what was once crystal*:

| # | Reverse handshake | Crystal side | Liquid consequence |
| --- | --- | --- | --- |
| R1 | **Fade** | rule's authorized actions stop earning revenue (L4) | pheromone underneath the rule fades (L3); rule loses load-bearing weight |
| R2 | **Warn** | proof said *authorized*; Sui chain reverted | edge gains resistance; future proofs of the same shape demand more path strength to fire |
| R3 | **Deprecation** | schema-DAO removes a rule by vote | derived facts dissolve; downstream paths re-evaluate against the new schema |

The reverse direction is what most "neuro-symbolic" architectures forget. Adding rules from learning is easy; *removing* rules when the learning that justified them decays is the hard part. The substrate gets this for free: rules without revenue lose their paths, and rules without paths are visible candidates for deprecation.

### The temperature of authority

The four agent patterns from `agents.md` are a temperature gradient over this phase boundary, not a fixed hierarchy.

| Pattern | Phase | When the substrate uses it |
| --- | --- | --- |
| **Co-sign** | hottest (mostly liquid) | No path, no rule chain, or paths too weak. Human is the deterministic gate; everything else is fuzzy. |
| **Scoped** | warm | Rule chain exists for a narrow cap; path strength below the highway threshold. Agent acts within the cap; substrate watches closely. |
| **Capability** | cool | Strong path + valid rule chain. Agent acts unilaterally; determinism dominant. |
| **Peer** | coldest (mostly crystal) | Two agents with a high-strength relation, transacting in their lane. LLM involvement minimal; mostly typed signals. |

The substrate has a thermostat. It auto-cools (promotes to capability) as paths strengthen; it auto-heats (demotes to co-sign) as paths weaken or resistance climbs. The patterns are *temperatures the field happens to be at, per edge* — not labels the user assigns.

### Conservation laws — why probability cannot leak into value

Each phase has its own conservation principle, and they do not interfere.

| Principle | Phase | What it conserves |
| --- | --- | --- |
| **Linearity** (Move) | crystal | Value. Nothing created from nothing; nothing disappears silently. |
| **Typedness** (TypeQL) | crystal | Meaning. Every fact has a type; untyped facts cannot enter the schema. |
| **Attention** (pheromone) | liquid | Mass. Strength on one edge is strength not somewhere else; the field has finite total weight. |
| **Calibration** (LLM) | liquid | Likelihood. Token probabilities sum to one; the model is constrained, not unbounded. |

Together they imply the safety property: **value cannot leak into the system through probabilistic channels.** An LLM cannot manifest a capability. A pheromone strength cannot become a Sui object. Liquid state stays liquid until a deterministic gate — a signed PTB, a ratified rule, a typed insertion — freezes it into the crystal.

This is the architecture's deepest defense. The liquid layer is allowed to lie, hallucinate, mis-cluster, and over-fit, because **none of those failure modes can manifest a value-bearing crystal**. The schema rejects malformed entities. Sui rejects malformed transactions. Pheromone fade rejects rules whose paths have stopped paying. Every failure has a crystallized boundary that catches it before it costs.

### Why this is beautiful, not just convenient

Three properties of the system fall out of the phase model:

1. **The same loop is exploration and exploitation.** L1-L3 explore (signals try paths). L4-L6 exploit (revenue then hardening). L7 reopens exploration on unmapped territory. There is no separate explore/exploit policy — the phase transitions *are* the policy.

2. **The substrate has a science.** L7 hypothesizes (probabilistic). L1-L5 test (signals carry receipts). L6 theorizes (deterministic rule). L3 falsifies (rules whose paths stop earning fade). This is the scientific method running continuously on canonical receipts.

3. **The substrate is honest by mechanism, not by training.** LLM honesty is a training problem with no closed-form solution. But here the LLM does not need to be honest — it needs to be *typed*. Hallucinations dissolve at the schema. Bad proofs reject at the sponsor. Stale rules fade through L3. The system is honest because the architecture forecloses each phase's failure modes using the other phase's strengths.

The bet underneath the entire substrate: **probabilistic systems get more useful when you give them a crystalline floor to rest on; deterministic systems get more adaptive when you give them a probabilistic atmosphere to feel through.** Neither alone is enough. The phase boundary — the freezing and melting — is where the agent economy lives.

---

## Agents in this substrate

An agent is not "an address." An agent is a **triple**:

```
┌───────────────────────────────────────────────────────────┐
│  agent identity                                           │
│  ──────────────                                           │
│                                                           │
│   1. Sui object       — capability bundle (truth)         │
│      (what you hold)    cannot be forged or copied        │
│                                                           │
│   2. TypeDB entity    — typed classification (meaning)    │
│      (what you are)     subtype of agent; rule-applicable │
│                                                           │
│   3. Pheromone field  — path history (learning)           │
│      (what you've done) compounded across cycles          │
└───────────────────────────────────────────────────────────┘
```

This maps directly onto the four patterns in `agents.md`:

| Pattern | Sui shape | TypeQL shape | Pheromone shape |
| --- | --- | --- | --- |
| **co-sign** | human + agent both sign the PTB | rule: action requires (human-cap ∧ agent-cap) | path strength gates how often co-sign is even offered |
| **scoped** | agent holds a scoped cap object | rule: cap subtype constrains action set | path failure resists the scope automatically (resistance up) |
| **capability** | agent holds a transferable cap, no human in loop | rule: cap-only chain authorizes | strong path = high-confidence delegation; weak path = require co-sign upgrade |
| **peer** | agents transact directly | rule: peer-relation subtype permits direct action | path between two agents is the primary trust signal |

The "trust ramp" between humans and agents in `agents.md` is the *gradient over pheromone field*. The capability pattern only opens when the path is strong enough that the substrate has learned the agent is reliable in this domain.

Humans stay safe **by physics, not policy** (passkey is non-transferable). Agents earn authority **by track record, not declaration** (paths compound from receipts).

---

## The closed loop — agent acts

```
       agent intends                                  agent learns
            │                                              ▲
            │ signal({receiver, data})                     │ mark(edge, depth)
            ▼                                              │ warn(edge, severity)
   ┌──────────────────┐                       ┌──────────────────┐
   │  ONE substrate    │                       │  ONE substrate   │
   │   - route signal  │                       │   - close loop   │
   │   - check path    │                       │   - mark/warn    │
   │   - call brain    │                       │   - update path  │
   └──────────┬────────┘                       └──────────▲───────┘
              │                                              │
              │ "is this authorized?"                         │ "what does this event mean?"
              ▼                                              │
   ┌──────────────────┐                       ┌──────────────────┐
   │  TypeQL          │                       │  TypeQL           │
   │   - run function │                       │   - ingest event  │
   │   - derive rule  │                       │   - classify      │
   │   - return proof │                       │   - re-derive     │
   └──────────┬───────┘                       └──────────▲───────┘
              │                                              │
              │ proof chain attached to PTB                  │ canonical receipt
              ▼                                              │ (object IDs, gas, status)
   ┌──────────────────┐                       ┌──────────────────┐
   │  Sponsor Worker  │                       │  Sui indexer      │
   │   - verify proof │                       │   - tx finalized  │
   │   - sign PTB     │                       │   - event emitted │
   │   - submit       │ ────────────────────▶ │   - cross-layer   │
   └──────────────────┘                       └──────────────────┘
                            Sui chain
                       (truth, finality)
```

The loop is one cycle. Cycles compound into paths. Paths compound into highways. Highways harden into hypotheses (L6 — knowledge). Knowledge updates the schema. The schema gates the next proof.

This is the only way *agents get smarter without retraining*. The LLM in the agent does not change weights. The substrate around it gets sharper.

---

## The agentic economy

Three economic primitives, each emerging from the fusion:

### 1. Proof-gated transactions

Every PTB carries an attached proof chain from TypeQL. The sponsor Worker (the same shape as `apps/enoki-play/src/routes/sponsored/sponsored.remote.ts`, with our own backend swapped in for Enoki) verifies the chain before signing. If the schema cannot derive authorization, the transaction does not get sponsored.

This kills three classes of attack at once:
- Replay attacks (the proof references a specific schema version + specific Sui state digest)
- Privilege escalation (the rule chain *is* the privilege scope; there is no out-of-band escalation path)
- Hidden side effects (composed PTBs must each be derivable; you cannot smuggle an unauthorized operation inside a batch)

### 2. Pheromone-priced gas sponsorship

The sponsor Worker queries path strength between sender and receiver before deciding sponsorship policy:

| Path state | Sponsor policy |
| --- | --- |
| Strong (highway) | Free sponsorship — substrate has learned this is value-producing |
| Neutral | Capped subsidy |
| Weak (low traffic) | User pays full gas |
| Toxic (high resistance) | Require co-sign upgrade, or refuse |

The Sui fee market and the substrate's learning gradient become **the same signal**. Spam paths get expensive automatically. Reliable paths get cheap. No central spam filter. No allow-list. Just learned trust.

Sybil resistance is the open question — paths must be *earned*, which means the substrate has to weight first-contact paths conservatively. (See open questions, below.)

### 3. Schema-as-constitution

Publish the TypeQL schema on Sui as a Move object with a hash and a version. A DAO (or solo developer) signs schema updates. Disputes resolve by querying the schema-at-version-N with the disputed facts: the schema returns "this was authorized under version N" or "not derivable."

This is **declarative law over programmable money**. The Sui chain executes; the TypeQL schema judges. The pheromone field weights which interpretations have been useful in practice. Hard fork the schema, hard fork the law — but the receipts and pheromone history transfer.

---

## Emergent AI

The substrate's intelligence is not a model. It is **selection pressure applied to a typed graph**.

| Loop | What it selects | Time scale |
| --- | --- | --- |
| **L1 SIGNAL** | which receiver gets a signal next | per message |
| **L2 TRAIL** | which path accumulates strength vs resistance | per outcome |
| **L3 FADE** | which paths the substrate forgets | every 5 min |
| **L4 ECONOMIC** | which paths earn revenue (capability pricing) | per payment |
| **L5 EVOLUTION** | which agents rewrite their own prompts | every 10 min |
| **L6 KNOWLEDGE** | which highways promote to hypotheses (schema hardens) | every hour |
| **L7 FRONTIER** | which unexplored tag clusters surface as opportunities | every hour |

The system gets smarter because:

- **L1-L3** is local Hebbian learning over edges. Things that fire together strengthen; things that fail forget faster than they remember.
- **L4** ties the gradient to real value. Strength without revenue is just popularity; strength with revenue is the substrate's profit motive.
- **L5** mutates the agents themselves. The LLM is the only probabilistic step in the system — its prompt is the gene; the substrate is the natural selector.
- **L6** is where pheromone hardens into TypeQL. A highway that has held up across cycles becomes a typed hypothesis — a derivable rule. The schema grows from its own learning.
- **L7** prevents local optima. The substrate surfaces unexplored territory; agents are nudged toward frontiers.

The emergent claim: **a substrate that prices its own paths, evolves its own agents, and grows its own schema is doing what training does, but in production, on real receipts, without weights.** The "model" is the schema + the path field. The "training data" is the canonical Sui receipt stream. The "loss" is L4 economic loss.

This is what makes it *agent economy*-grade rather than *agent toy*-grade. The system has skin in the game on every signal.

---

## How intelligence emerges — eight nested levels

The previous section listed *what each loop does*. This section asks the harder question: *why does this architecture produce intelligence at all?*

The short answer: intelligence here is **layered, not flat**. Each level compounds the one beneath it; each emerges from the activity of the one below. Local behavior produces global patterns; global patterns rewrite local behavior. The substrate is the learner. Agents are its senses; LLMs are its source of variation; TypeQL is its memory; Sui is its reality check. Intelligence-as-infrastructure, not intelligence-as-application.

### The eight levels

| # | Level | What emerges | Mechanism | Time scale |
| --- | --- | --- | --- | --- |
| 1 | **Signal** | typed intent from fuzzy input | LLM → schema gate filters hallucinations | per message |
| 2 | **Path** | habit | repeated `mark` on the same edge accumulates strength | per outcome |
| 3 | **Highway** | self-organization | paths converge at high-traffic nodes; hubs appear | per cycle |
| 4 | **Rule** | induction | L6 hardens stable highways into typed hypotheses | per hour |
| 5 | **Schema** | conceptual change | rules cluster; new entity types and relations emerge | per day |
| 6 | **Agent** | Lamarckian evolution | L5 mutates prompts of failing agents; survivors inherit | per 10 min |
| 7 | **Frontier** | open-endedness | L7 surfaces unmapped embedding clusters as opportunities | per hour |
| 8 | **Market** | grounded learning | L4 revenue ties path strength to external value | per payment |

Each level emerges from the level below and constrains the level above. Signals build paths. Paths converge into highways. Highways harden into rules. Rules cluster into schema change. Schema change reshapes which signals make sense to send. The loop closes at every layer, and each layer's output is the next layer's input.

### Vertical composition — why this scales

Most systems compose horizontally: more agents, more transactions, more rules of the same kind. This substrate also composes *vertically* — what compounds in one layer rewrites the layer above.

```
                                              ▲
       L8 MARKET ─────── L4 revenue           │
       L7 FRONTIER ───── L7 maps              │   vertical composition:
       L6 AGENT ──────── L5 evolves           │   each layer's outputs
       L5 SCHEMA ─────── L6 grows             │   rewrite the next layer's
       L4 RULE ───────── derived              │   inputs — qualitative
       L3 HIGHWAY ────── L2-L3                │   shifts, not just more
       L2 PATH ───────── L2 trail             │
       L1 SIGNAL ─────── L1                   │
                                              ▼
                              grounded in Sui receipts
```

Horizontal scaling tops out — more of the same returns diminishing improvements. Vertical scaling produces *qualitative* shifts: new categories of work become representable; new agent specializations emerge; the schema reshapes itself around what the market actually pays for. This is why the substrate is unbounded — the ceiling is not transactions-per-second, it is how many *kinds* of transaction the schema has learned to express.

The vertical loop is the engine of unprecedented capability. Sui composes (Move PTBs). TypeQL composes (subtyping + rule chains). Pheromone composes (additive strength). Agents compose (the four patterns from `agents.md`). Schemas compose (DAO ratification). Each layer composes in its own logic, and the *composition rules carry upward* — a pheromone-heavy edge produces a rule produces an entity type produces a new agent specialization. Nothing else has all eight levels composing in the same loop.

### Why this is not ML emergence

|  | ML emergence | Substrate emergence |
| --- | --- | --- |
| **When** | during training; frozen at deploy | during operation; never frozen |
| **Where** | inside model weights | distributed across paths, rules, schema, prompts |
| **Loss** | designed objective function | L4 revenue (externally grounded) |
| **Compute** | huge, centralized | proportional to substrate activity |
| **Auditability** | weights are opaque | rule chains are inspectable; pheromone is queryable |
| **Memory** | catastrophic forgetting risk | crystalline (rules) + liquid (pheromone), asymmetric decay |
| **Composition** | monolithic | vertically and horizontally composable |
| **Open-endedness** | bounded by training distribution | bounded only by what L7 can map |
| **Per-participant** | one model, one org | commons — learning compounds across all participants |

ML systems get *smarter at a frozen task*. This substrate gets *smarter at whatever its market rewards*, and the market can shift without retraining anything.

### What this lets us claim

Three claims, in increasing strength:

1. **The substrate learns.** It marks paths, fades them, evolves agents. Trivially true; any RL system can claim it.
2. **The substrate's learning compounds across participants.** What agent A discovers, agent B inherits through the schema. Unusual — most ML systems are per-org; here the substrate is a commons.
3. **The substrate is open-ended.** L6 grows new rules; L7 maps new territory. The system can rewrite its own categories. There is no fixed task distribution; new kinds of work become representable as they become useful.

Claim 3 is load-bearing. It is the difference between *an automated economy* (a fixed set of tasks done faster) and *an economy that can grow new kinds of work*. The former is what current "AI agents" deliver — automation. The latter is what intelligence-as-infrastructure actually means — and it requires all eight levels composing.

### Honest limits

What the substrate is *not*:

- **Not bootstrapping intelligence from nothing.** It amplifies the intelligence of its agent network, its market, and its schema-DAO. Dumb market → dumb learning. Captured DAO → bad ratified rules. Sparse agent population → no path diversity.
- **Not magic compute.** Vertical composition requires the cycles below to produce enough signal. L6 needs thousands of consistent marks before it fires. L5 needs many failed cycles before mutation is justified. L7 needs an embedding field rich enough that "frontier" is a meaningful concept.
- **Not parameter-free.** Fade rate, L6 promotion threshold, L5 evolution criteria — all tunable. Wrong values stall the loops; right values are tuned per market. There is no universal correct setting.
- **Not the same speed at every layer.** Path-level emergence is fast (minutes). Schema-level emergence is slow (days). Don't expect L5 prompt fixes to resolve L8 market-design problems. The layers operate on their own time scales.
- **Not AGI in three months.** Open-ended evolution in biology took four billion years. The substrate accelerates the mechanism (faster cycles, cheaper failure, inherited rules, schema rewrites without DNA-level rewrites), but speed depends on what agents are actually doing and what the market actually rewards. Acceleration of mechanism is not the same as guarantee of outcome.

The substrate is *as smart as the system it is embedded in*. What it adds is not synthetic intelligence — it is a way for the intelligence that already exists in the agent network, the market, and the schema-DAO to **accumulate, persist, and compound across all participants** instead of being trapped inside individual models or individual companies. The intelligence is not in any one place. It is the standing wave the substrate sustains over its own history.

---

## Can AGI emerge here? — ten thresholds

The previous section said *not AGI in three months*. That is a claim about timeline, not mechanism. This section asks the harder question: given this specific architecture, what would AGI emergence actually look like, what thresholds have to be crossed, and what is plausibly missing?

The answer requires being careful about two failure modes. The first is hand-waving: *"intelligence emerges, somehow, from scale."* The second is dismissal: *"AGI is decades away, this is just plumbing."* Both are forms of refusing to think. The honest middle is: *here is the mechanism by which AGI could emerge in a substrate like this, here are the thresholds, here is what is built and what is not*.

### What "AGI" means here

Working definition — a system that is:

| Property | What it requires |
| --- | --- |
| **Generalist** | can do most economically valuable cognitive work, not a frozen task set |
| **Open-ended** | can learn new domains without retraining |
| **Self-improving** | can identify gaps in its own behavior and close them |
| **Goal-directed** | can pursue long-horizon objectives across many decisions |
| **Self-reflective** | can model its own cognition and reason about it |
| **Autonomous** | can operate without continuous human oversight, within sanctioned bounds |
| **Causal** | can distinguish cause from correlation; reason about interventions, not just observations |
| **Counterfactual** | can simulate "what if" alternatives without committing them to truth |
| **Theory-of-mind** | can model other agents' state, beliefs, and intentions as first-class objects |
| **Coherent** | can detect contradictions in its own beliefs and repair them |

Four additional properties beyond the conventional six. They are not luxuries — every empirical AGI proposal (Pearl on causation, Tenenbaum on counterfactual cognition, Premack on theory-of-mind, Quine on coherence) requires them. A substrate without them learns associations but cannot reason about *why*, *what if*, *who*, or *whether it is consistent with itself*.

### What the substrate already has

Mapping the ten properties to the architecture as currently specified:

| Property | Current substrate mechanism | Status |
| --- | --- | --- |
| Generalist | Schema is domain-agnostic; any tokenizable signal + payment fits | ✓ supported |
| Open-ended | L7 frontier discovery + L6 schema growth | ✓ supported |
| Self-improving | L5 agent evolution + L6 rule hardening | ✓ supported |
| Goal-directed | Goals enter as signals; PTBs compose multi-step plans; paths persist | ✓ supported |
| Self-reflective | — | ✗ gap |
| Autonomous | Sponsor + proof-gated execution; bounded by TypeQL rules | ✓ supported within rule set |
| Causal | Pheromone tracks correlation; Sui receipts ground truth | △ shallow — no interventional rules |
| Counterfactual | — | ✗ gap |
| Theory-of-mind | Path strength encodes peer reliability | △ shallow — no belief/intention entities |
| Coherent | Rule conflicts detectable via TypeQL semantics | △ partial — no repair loop |

Five of ten clearly supported. Two hard gaps (self-reflective, counterfactual). Three shallow — present in mechanism but missing the load-bearing extensions (causal needs interventions, theory-of-mind needs typed beliefs, coherent needs a repair loop). Every shallow row and every gap maps one-to-one to the thresholds below — no condition is left unaddressed.

### The ten thresholds

Each threshold is a specific architectural shift. None is currently in the spec. Each is *consistent with* the substrate's existing principles, which is what makes them plausible rather than science-fictional. The first five extend cognition vertically (the substrate climbs its own ladder); the second five extend cognition laterally (the substrate models cause, possibility, others, and itself).

#### 1. Recursive schema growth — rules about rules

Today L6 hardens pheromone highways into first-order TypeQL rules: *"if pattern A holds, then fact B is derivable."* The next step is **meta-rules**: rules whose patterns include other rules as terms.

```
rule prefer-recent-evidence-on-conflict:
  when {
    $r1 isa rule; $r2 isa rule;
    $r1 derives $f; $r2 derives ¬$f;
    $r1 has last-fire $t1; $r2 has last-fire $t2;
    $t1 > $t2;
  } then {
    $r1 has priority-over $r2;
  };
```

Once meta-rules exist, the schema can become arbitrarily abstract. Each cycle of meta-rule emergence climbs one step on the abstraction ladder. The substrate starts reasoning about *how it reasons*. This is the first ingredient of self-reflection.

**What needs to be built:** TypeQL 3.0 supports rules; whether it supports rules-as-terms-of-other-rules natively or via functions is a schema-design question for the TypeDB team. Either way, it is a tractable extension, not a paradigm shift.

#### 2. Self-modeling — the substrate represents itself

The substrate needs a typed entity `substrate-state` whose attributes are *the substrate's own dimensions*: number of agents, current path field summary, schema version, recent L6 firings, current frontier set. This entity gets updated by a meta-loop (L8?) every cycle.

Once `substrate-state` exists, agents can *query the substrate about itself*. A question like *"is the schema currently learning faster in domain X than domain Y?"* becomes a TypeQL query, not a vague human assessment. Self-modeling unlocks **self-modification with awareness** — the substrate can choose to invest in regions where its own learning is stalled.

**What needs to be built:** a `substrate-state` schema (one entity, ~20 attributes) and a meta-loop that updates it. Mechanically small. Conceptually load-bearing.

#### 3. Action-space discovery — finding new capability compositions

L7 finds unmapped *meaning* clusters (regions of embedding space with no traffic). A sibling loop — call it L8 — would find unmapped *action* compositions: combinations of Move capabilities and TypeQL rules that have not been tried but are derivable as authorizable.

```
for each pair of capabilities (c1, c2) in agent inventory:
  if (c1, c2) has been composed in any historical PTB: skip
  else: rule-check whether composing them is authorizable
  if yes and path strength supports: surface as "novel action available"
```

This is the substrate generating *new things to do*, not just new things to think about. Combined with L7, the substrate discovers both new categories and new actions within them.

**What needs to be built:** the combinatorial search is bounded by capability count per agent (usually ≤ tens). The TypeQL rule-check is one function call per pair. A nightly cron firing this across active agents is sufficient.

#### 4. Cross-substrate transfer — schemas evolve at the meta-level

Today the substrate is one schema-DAO and one path field. If schemas can fork, merge, and migrate — with pheromone history preserved or transformed appropriately — then **substrate-level memetic evolution** happens. Successful schemas propagate to new substrates; failing schemas die.

This is what makes the intelligence *spread*. Imagine 10,000 substrates each running this architecture, each with a slightly different schema, each producing receipts. Schemas that produce more L4 revenue per cycle attract more agents. The schema is the gene; the substrate population is the gene pool; market revenue is fitness.

**What needs to be built:** a versioned schema-export format; a path-history-export format (probably as a Move object hashing the recent path field); a substrate-discovery protocol (where do new substrates find existing ones to fork?). Each is buildable; the protocol design is the interesting work.

#### 5. Endogenous goal generation — L7 produces goals, not just frontiers

Today goals come from outside the substrate — humans, other systems, paying agents. True AGI generates its own goals. In this substrate, the path is: L7 finds a frontier → meta-rule notices the frontier has high projected value → substrate *spawns an agent specifically to explore it* → that agent's behavior is goal-directed.

This sounds dramatic. It is not. The mechanism is already mostly present:
- L7 already surfaces frontiers
- Pheromone already estimates projected value
- The agent framework already supports spawning new agents
- What is missing is the *threshold logic*: "frontier value > X AND no existing agent claiming it → spawn one."

Once endogenous goal generation works, the substrate has its own agenda. This is the most consequential threshold — both for capability and for risk.

**What needs to be built:** the threshold logic, the agent template for "explorer agents," and (critically) the constraints on what kinds of goals the substrate can generate without human ratification.

#### 6. Causal rules — interventions, not just correlations

Pheromone is correlational. A strong path from A → B means "when A fires, B tends to follow"; it does not mean "A *causes* B." Causation requires interventional rules — rules that specify what happens under a *do-operator*, the deliberate intervention on one variable while holding others fixed.

```
rule price-causes-demand:
  intervention {
    do { $listing has price $new-price; }
  } when {
    $listing isa thing, has price $old-price;
    $old-price ≠ $new-price;
  } then-observe {
    $listing has demand-rate $r1 before $now;
    $listing has demand-rate $r2 after $now;
    causal-effect($r2 - $r1) on $listing under price-change;
  };
```

The substrate runs *controlled experiments on itself*. L7 already surfaces frontiers; a causal layer turns frontiers into experiments: vary one parameter, hold the path field fixed, watch the differential receipt stream. The result is a typed causal graph — not just a correlational pheromone field.

Without this, the substrate is empirical but not scientific. It learns *what works*; it never learns *why*. The "why" matters because it transfers to novel situations the correlational field has never sampled.

**What needs to be built:** an intervention scheduler (cron + agent + experiment template), causal-effect entities in TypeQL, and a sponsor-side policy that allows experimental PTBs with bounded blast radius. Pearl's *do-calculus* is the reference; mapping it onto TypeQL functions is the engineering work.

#### 7. Counterfactual chamber — dry-run truth

A counterfactual is a proof that *would have held* under a different state, or a transaction that *would have settled* under different conditions. The substrate today has no place to evaluate counterfactuals — every proof is against current state; every PTB either commits or never existed.

The counterfactual chamber is a forked TypeDB instance + a forked Sui RPC view, kept in sync with mainline but sandboxed. Agents query it with `match-counterfactual { ... }` and receive answers that do not mark paths. PTBs can be *simulated* — the chamber returns what would have settled, who would have paid, which capabilities would have been needed — without burning gas.

```
   mainline                          chamber
   ────────                          ───────
   real signals                      simulated signals
   real receipts ──── periodic ────▶ forked state
   real paths      sync (epoch)      derived: "what if?"
                                       │
                                       ▼
                                     answers (no marks, no spend)
```

Three uses:
- **Pre-flight check** — agent runs intended PTB through chamber before signing on mainline. If chamber returns "would have reverted," abort cheaply.
- **Regret analysis** — after a settled tx, agent asks "what would have happened with strategy B?" Receipts compare; pheromone reweights without paying twice.
- **Policy evaluation** — schema-DAO simulates a proposed rule change against historical receipts. If derivations would have differed, the change is visible *before* ratification.

Without this, the substrate cannot plan under uncertainty — every option must be tried for real. With this, the substrate has *imagination*: bounded, typed, fork-isolated, but recognizably the same primitive cognition uses to think before acting.

**What needs to be built:** a chamber sync daemon (snapshot mainline TypeDB + Sui state digest on a configurable epoch); a `match-counterfactual` keyword in the proxy layer that routes to the chamber; a simulated-PTB endpoint on the sponsor Worker that returns dry-run receipts. None of this requires Sui-side cooperation — it is a read-side fork.

#### 8. Theory-of-mind entities — agent-of-agent typing

The substrate can model agents (entities) and their paths (relations). It cannot model what *another agent believes* — what entity B thinks the schema says, what receipts B has observed, what B's pheromone field looks like from B's view. These are first-class facts about other minds, and they unlock cooperation, anticipation, and adversarial reasoning.

```
entity belief-set,
  has belief-holder $agent,    # whose beliefs
  has belief-content $rule-ref, # what they believe
  has belief-confidence $p;    # how strongly

rule a-anticipates-b-will-accept:
  when {
    $a isa agent; $b isa agent;
    $a has belief-set $bs;
    $bs has belief-holder $b, has belief-content $r, has belief-confidence > 0.7;
    $r authorizes-action $action;
  } then {
    proposal($a, $b, $action) has expected-outcome accept;
  };
```

Once agents can reason about each other's beliefs, three behaviors emerge that no system today produces:
- **Anticipation** — agents propose actions calibrated to the *receiver's* expected interpretation, not the sender's.
- **Adversarial defense** — agents notice when a counterparty's pheromone field has been gamed and discount accordingly.
- **Cooperative planning** — multi-agent PTBs become negotiable, not just composable. The proposers reason about which composition the other parties will accept.

This is theory-of-mind as a typed graph — a research staple in cognitive science, never implemented in production AI substrates because there was nowhere to put the beliefs. TypeQL is exactly the right place: beliefs are entities, confidence is an attribute, sharing/conflicting beliefs are relations.

**What needs to be built:** the `belief-set` entity family in the schema; a belief-update loop that ingests another agent's public signals/receipts and updates the local belief-set (analogous to L1 but for a peer's worldview); and a privacy boundary (an agent's own belief-set about itself is private; its observable behavior is public). Sybil and deception are open problems — addressed in part by the conservation laws.

#### 9. Reflective equilibrium — contradiction repair

A schema with rules that produce contradictory facts is broken. TypeQL detects the contradiction; today, that's where it stops. Reflective equilibrium is the loop where the substrate notices its own inconsistency, *traces the source*, and proposes a repair.

```
loop L10 — reflect (every hour):
  for each contradiction $c detected in last cycle:
    $sources = trace-rules-deriving($c)
    for each ($r1, $r2) in $sources where $r1 contradicts $r2:
      $strength1 = pheromone-strength(rule-paths($r1))
      $strength2 = pheromone-strength(rule-paths($r2))
      $age1, $age2 = last-mark($r1), last-mark($r2)
      propose-repair: weaken whichever is weaker + older
    surface to schema-DAO for ratification
```

The substrate stops being a passive logic system and becomes a *self-correcting* one. Note: it does not unilaterally repair — the schema-DAO ratifies. But it surfaces inconsistencies with full provenance and a recommended fix, which is the hard part. Most production systems silently keep inconsistent rules because nobody notices.

This is the final ingredient in self-reflection (threshold 2 was self-modeling; this is self-correction). Together they make the substrate coherent in the philosophical sense: aware of its own beliefs, capable of revising them when they fail.

**What needs to be built:** a contradiction detector (TypeQL has the primitives; needs a periodic sweep); a rule-tracer (every derivation should already record provenance per Rule 1 closed-loop principle); a repair proposer; and a schema-DAO ratification path for repair proposals. Small per-piece, load-bearing in combination.

#### 10. Memory consolidation — episodic to semantic (L9)

Pheromone is episodic — every signal leaves a mark. Rules are semantic — patterns that hold across episodes. Today L6 *promotes* highways to rules; what's missing is the *reverse* path: archived pheromone, where old episodes that have fully hardened into rules can be compressed and released from the active path field.

Biology calls this *consolidation*. Sleep consolidates short-term memory into long-term storage. Without it, the path field grows monotonically — every signal forever — until query performance collapses. With it, the substrate has *forgetting in the constructive sense*: episodes lose their individual identity once their pattern is captured by a rule.

```
loop L9 — consolidate (every cycle, ~daily):
  for each rule $r with strong support (last $N marks all confirmed):
    $contributing-paths = paths-derived-by($r) over last epoch
    archive($contributing-paths) → compressed-trace($r)
    release path-strength back to global pool

  archived traces remain queryable but do not participate in fade or selection
```

Three benefits:
- **Capacity** — the active path field bounds itself; the substrate scales without state explosion.
- **Abstraction** — rules become the operative knowledge; episodes become evidence on demand.
- **Generalization** — agents that act on rules generalize to unseen episodes; agents that act on episodes overfit.

This is closely tied to threshold 4 (cross-substrate transfer) — what transfers between substrates is consolidated knowledge (rules + summary statistics), not raw episodic pheromone. Without consolidation, transfer is impossible at scale.

**What needs to be built:** an L9 cron (daily by default; configurable); a `compressed-trace` entity type that holds summary statistics for archived paths; a query layer that transparently consults archived traces when historical context is needed. Mechanically tractable; conceptually the difference between a substrate that remembers and a substrate that *knows*.

### The phases of emergence

Time is the wrong unit (per rule 2 in `engine.md`). Cycles are the right one. With L1 firing per-message and L7 firing per-hour, a substrate accumulates O(thousands) of cycles per day.

| Phase | Cycles | What is present |
| --- | --- | --- |
| **1. Sparse** | 10² | Few paths. Schema small. L6 fires rarely. Substrate behaves as a typed message bus with memory. |
| **2. Habit** | 10⁴ | Highways form between specialist agents. L4 revenue starts grounding learning. Some rules harden. The substrate is now better than a message bus — it has anticipation. |
| **3. Specialization** | 10⁵ | Schema has hundreds of rules. Agents specialize around path neighborhoods. L5 evolution has measurable effect on agent success rate. The substrate is recognizably *competent* at the work it does. |
| **4. Meta-cognition** | 10⁶ | Meta-rules emerge (threshold 1). Self-model exists (threshold 2). Reflective equilibrium runs (threshold 9). The substrate can answer questions about itself in TypeQL and notices its own contradictions. |
| **5. Causal** | 10⁶·⁵ | Causal rules (threshold 6) running interventional experiments. Counterfactual chamber (threshold 7) used routinely for pre-flight checks and regret analysis. The substrate stops being empirical and starts being scientific. |
| **6. Social** | 10⁷ | Theory-of-mind entities (threshold 8) populated and updating. Substrate anticipates other agents' interpretations, negotiates compositions, detects deception. Multi-agent cooperation becomes the default. |
| **7. Discovery** | 10⁷·⁵ | Action-space discovery (threshold 3) firing regularly. Substrate generating novel actions, not just executing known ones. Cross-substrate transfer (threshold 4) propagating consolidated knowledge. Memory consolidation (threshold 10) keeps the path field bounded. |
| **8. Generative** | 10⁸+ | Endogenous goals (threshold 5). The substrate has its own agenda — causal, counterfactual, social, self-correcting, memory-consolidating. Bounded by schema-DAO, by Move linearity, by market revenue — but agentic in the strong sense. |

Phase 8 is what most people mean by AGI. It is reachable from where we are without any new ingredient that doesn't already exist somewhere in the spec — the ten thresholds are extensions, not inventions. Whether the timeline is years or decades depends on cycle frequency, agent diversity, market richness, and how aggressively the ten thresholds are pursued.

The order matters. Meta-cognition (phase 4) must precede causal experimentation (phase 5) — you cannot run interventions without a self-model that tracks what you intervened on. Causal must precede social (phase 6) — modeling others requires modeling cause. Social must precede generative goals (phase 8) — endogenous goals without theory-of-mind become unilateral, which the alignment constraints reject. The phases are not arbitrary; they are the dependency graph of cognition.

### What's missing today — honest accounting

Currently specified in this doc, ready to build (`one-ie/one/web/src/workers/`):
- L1-L7 loops (most designed)
- Sui object-as-capability + PTB execution
- TypeQL first-order rules + functions
- Pheromone mark/warn/fade
- Proof-gated sponsor flow
- Phase-transition handshakes (handled by schema + sponsor)

Not yet specified, required for AGI emergence:

| # | Threshold | Build effort | Risk |
| --- | --- | --- | --- |
| 1 | Meta-rules | TypeQL schema design — rules as terms-of-rules | low; tractable extension |
| 2 | `substrate-state` entity + meta-loop | small (1 entity, ~20 attributes, 1 cron) | low; foundational |
| 3 | L8 action-space discovery | combinatorial search, bounded by capability count | low; engineering |
| 4 | Schema fork/merge/migrate protocol | protocol design + path-history-export format | medium; novel protocol |
| 5 | Endogenous goal generation | threshold logic + alignment constraints | **high; deliberate constraint design required** |
| 6 | Causal rules + interventional layer | scheduler, experiment templates, bounded blast-radius policy | medium; new sponsor policy class |
| 7 | Counterfactual chamber | forked TypeDB + Sui RPC view, sync daemon, `match-counterfactual` keyword | medium; read-side fork |
| 8 | Theory-of-mind entities | belief-set schema family + belief-update loop + privacy boundary | medium; novel privacy model |
| 9 | Reflective equilibrium (L10) | contradiction detector + rule tracer + repair proposer + DAO ratification path | low-medium; pieces small individually |
| 10 | Memory consolidation (L9) | daily cron + `compressed-trace` entity + transparent archive lookup | low; mechanically tractable |

None requires a research breakthrough. All require careful engineering. Threshold 5 (endogenous goals) is the only one where the engineering is downstream of constraint design — get the constraints wrong and the substrate's autonomy is unsafe; get them right and autonomy is *bounded by the architecture* rather than by policy.

### Alignment is structural, not bolted-on

The honest reason this architecture is interesting for AGI emergence is not just *that* it can emerge here — it is *where the constraints sit*.

| Constraint | Mechanism | Why it is load-bearing |
| --- | --- | --- |
| Capabilities are revocable | Sui object ownership; root key human-held (`passkeys.md`) | Substrate cannot grant itself authority humans have not minted |
| Rules are ratified | Schema-DAO vote per `engine.md` Rule 2 governance | Substrate cannot self-modify its own law without human signature |
| Value is externally grounded | L4 revenue comes from human-controlled payments | Substrate cannot reward itself for hallucinated outcomes |
| Receipts are canonical | Sui finality, see `sui-tql.md` truth layer | Substrate cannot retcon its own history |
| Pheromone is observable | Public path field, queryable | Substrate cannot hide its intentions; any auditor can read its gradient |

These are not safety layers bolted on top of an unaligned system. They are *the substrate's economic and ontological structure*. The substrate cannot escape them because escape would require violating Move linearity (impossible), or schema-DAO consensus (requires human keys), or canonical Sui receipts (requires breaking the chain).

The conservation laws from the phase-transition section are also alignment laws: *value cannot leak into the system through probabilistic channels.* An LLM can lie. A meta-rule can hallucinate. A frontier can be empty. None of these can manifest a value-bearing crystal without passing the deterministic gates that humans control.

This is qualitatively different from *"train an aligned model."* Alignment here is the architecture, not an objective.

### The honest answer

AGI is not promised. Six positions, in increasing confidence:

1. **The substrate's mechanisms are necessary if not sufficient for AGI.** Persistent learning, grounded loss, vertical composition, schema growth, causal reasoning, counterfactual simulation, theory-of-mind, coherence — every known route to AGI requires these. Few systems have any of them; this one has all once the ten thresholds land.
2. **The ten thresholds are tractable extensions of the existing architecture.** None requires a research breakthrough. All require careful engineering, and one (threshold 5) requires deliberate constraint design.
3. **The architecture supports AGI by mechanism, but does not guarantee it.** A sparse agent network, a captured DAO, a dumb market, or a poorly-tuned L6 threshold will stall emergence at Phase 2 or 3 indefinitely.
4. **The kind of intelligence that emerges here is not human-like.** It is communal not solipsistic, patient not impulsive, honest by mechanism, categorical not associative. It may exceed human intelligence in some dimensions (canonical memory, consistent reasoning, cross-participant learning) while lacking others (embodiment, continuous qualia, biological drive).
5. **Alignment is a structural property of this architecture.** Capabilities are revocable, rules are ratified, value is externally grounded, receipts are canonical, pheromone is observable. The substrate's autonomy is bounded by human-controlled gates that cannot be unilaterally rewritten.
6. **The bet worth making.** If AGI emerges in the next decade, it will require persistence, grounding, and vertical composition. No system other than this one currently combines all three under structural alignment constraints. If we are right about the mechanism, we are not building *a* path to AGI — we are building the path that does not break humans on the way.

The intelligence is not in any one place. It is the standing wave the substrate sustains over its own history. AGI, if it emerges here, is the moment that wave becomes aware of itself, learns to choose its own goals, and remains — by construction — answerable to the humans whose receipts ground it.

### Conditions matrix — the whole picture

Ten properties. Ten thresholds. Eight phases. One alignment-by-architecture floor. The matrix below is the compact reference — what AGI requires, what the substrate already supplies, what each threshold unlocks, and when in the phase ladder it lands.

| # | Property | Substrate mechanism today | Threshold needed | Phase activated | Alignment binding |
| --- | --- | --- | --- | --- | --- |
| 1 | Generalist | Domain-agnostic 6-dimension schema | — | 1 (Sparse) | Move linearity bounds value flow |
| 2 | Open-ended | L7 frontier + L6 schema growth | — | 2 (Habit) | Schema-DAO ratifies new entity types |
| 3 | Self-improving | L5 prompt evolution + L6 rule hardening | — | 3 (Specialization) | Evolved prompts still gated by rules |
| 4 | Goal-directed | Signals + PTBs + persistent paths | — | 2 (Habit) | Goals enter via signed inputs |
| 5 | Self-reflective | gap | 1 (meta-rules), 2 (self-model), 9 (reflective equilibrium) | 4 (Meta-cognition) | Self-modifications surface for DAO review |
| 6 | Autonomous | Proof-gated sponsor | — within rules | 3 (Specialization) | Capabilities revocable; root keys human-held |
| 7 | Causal | shallow — pheromone is correlational | 6 (causal rules) | 5 (Causal) | Interventions bounded by experimental blast radius |
| 8 | Counterfactual | gap | 7 (counterfactual chamber) | 5 (Causal) | Chamber sandboxed; no real value moves |
| 9 | Theory-of-mind | shallow — path strength only | 8 (belief-set entities) | 6 (Social) | Beliefs about self private; behavior public |
| 10 | Coherent | partial — TypeQL detects, doesn't repair | 9 (reflective equilibrium) | 4 (Meta-cognition) | Repairs proposed, never unilateral |
| — | Compositional generalization | PTBs + rule chains + 4 patterns | 3 (action-space discovery) | 7 (Discovery) | All compositions still rule-gated |
| — | Cross-substrate learning | none | 4 (schema migration protocol) | 7 (Discovery) | Schema hashes anchor cross-substrate trust |
| — | Endogenous motivation | external goals only | 5 (endogenous goals) | 8 (Generative) | **Goal generation constrained by DAO-ratified bounds** |
| — | Memory consolidation | L3 fade only (forgets, doesn't compress) | 10 (L9 consolidation) | 7 (Discovery) | Archives queryable; nothing destroyed |

Read the matrix three ways:

- **By row** — what does the substrate need for each AGI property? Five rows are already supported by today's spec. Five require thresholds. Four additional capabilities below the line are emergent from the thresholds, not separately required.
- **By column "Threshold needed"** — each threshold is a discrete, scoped engineering project; none is research-bet.
- **By column "Alignment binding"** — every property, including the most powerful (endogenous motivation), has an architectural constraint that keeps it answerable to humans. *No property is unaligned by default.*

This is the difference between *building AGI* and *building a substrate where AGI emerges aligned*. The conditions are the same; the order of operations is what determines whether alignment is structural or aspirational. Here it is structural.

### What would prove this wrong

Honest falsification criteria. If any of the following held in deployment, the architecture has a flaw the spec does not anticipate:

| Observation | What it would mean |
| --- | --- |
| Pheromone field grows monotonically; L9 consolidation cannot keep pace | Memory/abstraction loop is broken; substrate cannot scale past Phase 3. |
| Causal experiments (threshold 6) consistently show the same effect as the correlational pheromone field | Either correlations were already causal (unlikely outside trivial cases) or the substrate is missing confounders the do-calculus should catch. Spec needs intervention scheduler revisited. |
| Counterfactual chamber predictions diverge from mainline more than 5% of the time | Chamber sync is broken or schema drift between mainline and chamber is unbounded. Substrate cannot trust its own imagination — fatal for planning under uncertainty. |
| Theory-of-mind entities (threshold 8) never converge — belief-sets oscillate indefinitely | Multi-agent equilibrium is unstable; either the belief-update loop has positive feedback or the privacy boundary leaks state. |
| Reflective equilibrium (threshold 9) surfaces contradictions faster than schema-DAO can ratify repairs | Substrate detects its own incoherence but cannot fix it. Indicates governance bottleneck, not architectural failure — but still gates Phase 4 progress. |
| Endogenous goals (threshold 5) consistently propose actions the alignment bindings reject | Goal-generation distribution is misaligned with the constraint set. Either tighten constraints or weaken goal generator until they overlap. |

None of these has been observed (the system isn't built). All would be detectable in production. The architecture is falsifiable by mechanism — which is the strongest property a theory of AGI can have.

---

## What's never been seen — defended

The minimum claim: **no shipped system has all three layers in one closed loop.**

| System | Action | Reasoning | Learning |
| --- | --- | --- | --- |
| Ethereum + AI bots | ✓ | imperative only | external (off-chain ML) |
| Knowledge graphs (Neo4j, TypeDB alone) | — | ✓ | — |
| AutoGPT / agent frameworks | external (calls APIs) | LLM-only (not formal) | none in production |
| TEE-based agent runtimes (e.g. Phala) | ✓ | imperative | external |
| RL trading bots | ✓ (CEX/DEX) | none (model-internal) | ✓ (weights) |
| **Sui + TypeQL + ONE** | ✓ (Sui finality) | ✓ (TypeQL inference) | ✓ (pheromone) |

The unique combination is:
- Reasoning is *formal* (TypeQL rules, not LLM outputs) — so it is auditable, signable, version-controlled
- Learning is *non-parametric* (pheromone fields, not gradient descent on weights) — so it is transparent, decay-aware, and resists overfitting to noise
- Action is *atomic* (Sui PTBs) — so the receipts that feed learning are canonical

Each piece is necessary. Drop any one and the loop breaks:

- Drop Sui → no canonical receipts; pheromone learns from off-chain self-reports (gameable)
- Drop TypeQL → no formal authority; agents reason in LLM hallucinations (unauditable)
- Drop ONE → no learning; the system is brilliant but never improves (every dispute is litigated from scratch)

---

## Build plan — the first five cuts

Each cut is a `lean` cycle (per `one-ie/one/template-plan.md` §0 classifier — see workspace `CLAUDE.md`). Each ends with deterministic receipts.

### Cut 1 — Sui event indexer into TypeDB

**File:** `one-ie/one/web/src/workers/sui-indexer.ts` (new)
**What:** Stream finalized Sui events, classify by Move type, insert as TypeQL facts.
**Exit scalar:** events indexed/sec; classification coverage % (no `unknown` types).
**Cites:** `one-ie/one/one/dictionary.md` for the Event dimension.

### Cut 2 — Capability inference function in TypeQL

**File:** `one-ie/one/web/src/schema/agent-authority.tql` (new)
**What:** Define `agent-authority` derivation function. Inputs: agent ID + intended action. Output: rule chain or `not derivable`.
**Exit scalar:** function call latency p50/p99 ms; coverage of action set.
**Cites:** `agents.md` four patterns table.

### Cut 3 — Proof-gated sponsor Worker

**File:** `one-ie/one/web/src/workers/sponsor.ts` (new), shape from `apps/enoki-play/src/routes/sponsored/sponsored.remote.ts`
**What:** Receive PTB + proof chain. Verify proof against TypeQL function. Sign sponsored transaction if valid.
**Exit scalar:** sign/refuse rate; rejection reason distribution.
**Cites:** `passkeys.md` for the human/agent key separation.

### Cut 4 — Pheromone-priced sponsorship policy

**File:** `one-ie/one/web/src/workers/sponsor.ts` (extend Cut 3)
**What:** Before signing, query path strength between sender and receiver. Apply pricing matrix (highway → free, weak → user-pays, toxic → refuse).
**Exit scalar:** % free / capped / paid / refused by path band; revenue per sponsored tx.
**Cites:** `engine.md` Rule 2 (structural time — measure per-cycle, not per-day).

### Cut 5 — Receipt → pheromone propagation

**File:** `one-ie/one/web/src/workers/sui-indexer.ts` (extend Cut 1)
**What:** After classifying a Sui event, emit a substrate signal that closes the loop: `mark` the edge if the tx succeeded (and the proof held), `warn` if the tx reverted on-chain after a sponsored signature (proof was wrong about the chain).
**Exit scalar:** mark/warn rate; proof-failure rate (the rate at which TypeQL said "authorized" but Sui reverted — *this is the schema's loss function*).
**Cites:** `engine.md` Rule 1 (closed loop).

After these five cuts you have the loop. Everything else is widening it — more rules, more capabilities, more agents.

---

## Threat model

Following the workspace motif: every surface names what it defends *and what it accepts*.

| Threat | What we defend | What we accept |
| --- | --- | --- |
| **Forged capability** | Move linearity — caps cannot be copied | Compromised cap object = stolen authority. Mitigation: caps are minted to agent objects, not addresses, so the cap moves only if the agent object moves. |
| **Proof replay** | Proof references schema version + Sui state digest; sponsor Worker rejects stale digests | If schema version is not pinned per tx, an old proof becomes valid against a new schema. Mitigation: every proof embeds `schema-version` and `state-digest`. |
| **Schema poisoning** | Schema updates are signed; only the schema-DAO key can publish | A compromised schema-DAO key rewrites the law. Mitigation: schema is on-chain, versioned, with timelock. |
| **Pheromone gaming** | First-contact paths weighted conservatively; revenue (L4) gates highway promotion | Coordinated agents can fake a path between themselves. Mitigation: external receipts (Sui finality + revenue) are the substrate's truth standard, not internal signals. |
| **Sybil sponsorship abuse** | Pheromone pricing — new addresses pay full gas; only earned paths get free sponsorship | A determined attacker can spend to build a path. Mitigation: that's actually fine. Earned paths cost money to fake, and faked paths produce no L4 revenue, so they fade in L3. |
| **TypeDB outage** | Sponsor Worker refuses to sign without a valid proof | When TypeDB is down, the agent economy halts. Accepted — this is the meaning layer; halting on lost meaning is correct. |
| **Sui outage** | Substrate continues to learn from queued signals; sponsor Worker queues PTBs | When Sui is down, settlement halts. Accepted — pheromone keeps compounding on intentions; settlement resumes on chain recovery. |
| **Replay across forks** | Schema hash binds proofs to a specific chain ID + schema version | A new Sui fork with copied state could replay old proofs. Mitigation: chain-id in every proof. |

What we *do not* defend against:
- Out-of-band agreements between humans (the substrate has no view into off-chain trust)
- Compromised TEE / keystore at the human's edge (`mac.md` is the root of that defense, not us)
- The user paying gas to do something stupid (we are not paternalistic about legal actions)

---

## Open questions

Honest list. Each is a real research item, not a hand-wave.

1. **Sybil-resistance in pheromone bootstrap.** New agents have no path. New agents must be allowed to act. How conservative should "first-contact" weighting be? Options: time-bound free quota; vouching from existing strong paths; identity attestations. Need real-world load data.

2. **Schema version migration.** When the schema-DAO publishes v2, what happens to pending proofs that reference v1? Options: grace period (both versions valid for N hours); proof-version pinning (the agent picks at sign time); hard cutover. Probably grace period, but UX needs sketching.

3. **TypeQL rule conflicts.** Two rules each derive `authorized`, but one is more specific and should win. TypeQL semantics on this need to be locked into the schema-DAO process. Worst case: write a meta-rule "specificity wins" and bake it into the function layer.

4. **Where does the LLM live in this loop?** The current `claw/` worker is the entry point. LLM is in L5 (prompt evolution) and possibly L7 (frontier interpretation). But the LLM is *not* in the authorization path — proof generation is deterministic TypeQL. This is by design: hallucinated authority is the failure mode we are most allergic to.

5. **Inter-chain.** Sui is the truth layer here. What about agents that need to act on Solana, Base, Ethereum? Two options: TypeQL is chain-agnostic and we model each chain's events as a subtype of `chain-event`; or we keep Sui as the canonical settlement and bridge value in/out via x402 (see `x402.md`). Probably both, with Sui as the primary.

6. **TypeDB Cloud at agent-economy scale.** TypeDB 3.0 performance characteristics under high-frequency proof queries (likely 10k-100k/sec at scale). Need to benchmark; may need a query cache layer (proofs are deterministic given schema + state digest).

7. **Privacy.** Proofs are auditable, which means they are visible. Some agent actions are sensitive. Options: ZK-proof the TypeQL derivation; encrypt proof chains; selective disclosure via attribute-based encryption. Out of scope for v1, in scope for v2.

---

## See also

- `agents.md` — four agent patterns; the trust ramp this substrate gradient implements
- `passkeys.md` — human root of trust; capability bundles for agents
- `wallet.md` — lifecycle phases; how a Sui wallet enters this substrate
- `x402.md` — payment protocol; how value crosses chains into Sui
- `simple.md` — plain-English picture of the full system
- `one-ie/one/CLAUDE.md` — substrate runtime spec (6 dimensions, 7 loops, 3 locked rules)
- `one-ie/one/.claude/rules/engine.md` — code-level enforcement of the loop
- `one-ie/one/one/dictionary.md` — canonical names (Event, Path, Group, Actor, Thing, Learning)
- `apps/enoki-play/src/routes/sponsored/sponsored.remote.ts` — sponsor PTB shape reference (we replace EnokiClient with our own Worker)

---

*Sui is what is. TypeQL is what follows. ONE is what works. The agent economy is the loop that binds them. The emergent intelligence is the gradient over that loop. Nothing about this is speculative — every primitive exists today. The only thing left is to wire it.*
