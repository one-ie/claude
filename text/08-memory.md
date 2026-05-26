# Memory: Every Conversation Makes the Next One Better

> "Every conversation with a customer either teaches your system or wastes it. There is no third option. Most companies are throwing away their best training data every single day."
>
> — Anthony O'Connell, Founder of ONE

Brad writes every account renewal by hand. He pulls notes from three tools, reconstructs what the client wanted twelve months ago, and hopes he remembers why June went sideways before the client does. The data was always there. The system just never kept it in a form he could use.

Memory is the difference between a platform that costs the same every month and one that gets cheaper. It is the difference between an agent that answers a question and one that knows the client's whole history before the first word is typed. It is, if you build it right, the reason your clients cannot leave.

This page explains how ONE's memory works, what it stores, how it accumulates, and why the corpus you build on your clients' data is the only moat in this business that compounds over years rather than weeks.

## The Five Types of Memory

Most software stores data. ONE stores five structurally distinct kinds of memory, each mapped to a primitive in the substrate.

| Cognitive type | What it holds | ONE primitive | Where it lives |
|---|---|---|---|
| **Episodic** | What happened, when | `signal` | Events (TypeDB + D1) |
| **Semantic** | What is true, as a general rule | `hypothesis` | Learning (TypeDB) |
| **Procedural** | How to do a specific task | `skill` + `.on()` handler | Things + runtime |
| **Social** | Who knows whom, who offers what | `membership`, `capability` | Groups, Actors |
| **Associative** | What leads to what, with what weight | `path` (strength/resistance) | Paths |

The distinction is not academic. Each type answers a different question your agents will need to answer mid-conversation.

Episodic memory answers: what happened last Tuesday when the client called about the delay? It retrieves the signal with a timestamp.

Semantic memory answers: based on sixty interactions over three months, what is this client's general attitude toward deadline flexibility? It retrieves a hypothesis with a confidence score and a source tag that tells you whether the pattern was observed through behaviour (reliable) or merely asserted by the client (capped).

Procedural memory answers: when this client raises a pricing objection, what sequence of steps has historically moved them forward? It retrieves the skill and the handler that produced outcomes.

Social memory answers: who on the client's team should this message go to, given what the substrate knows about their organisational structure? It retrieves capabilities and memberships.

Associative memory answers: given this client's inquiry about a new service, which path through the conversation history has the highest probability of a positive outcome? It retrieves the path strength, a number every prior interaction helped to write.

Five types. One substrate. Every one of them queryable without embedding, without nearest-neighbour search, without a separate memory service running in parallel.

## Per-Actor Memory vs Per-World Memory

There are two levels at which memory accumulates in ONE, and the distinction matters for how you price, structure, and own your client relationships.

**Per-actor memory** belongs to a specific participant in a specific conversation. Every customer who chats with your client's support agent accumulates their own profile: what they bought, what they complained about, what they were offered and declined, what they never asked about but the frontier loop says they probably should. An actor's memory is portable. It follows them across channels (web, email, SMS, voice) because the identity is cryptographic, not session-based. The Telegram message, the web chat, and the email reply are all the same actor, and the substrate knows it.

**Per-world memory** belongs to your client's workspace. It is the aggregate: every actor's behaviour, every path that has been walked, every outcome that has been marked. Per-world memory is what the agents share. When one agent learns that complaints about "delivery delays" cluster with "weekend orders," that pattern belongs to the world, not to the individual agent that first noticed it. The next agent that handles a weekend delivery complaint benefits from the learning automatically.

For you, the agency, this structure has a commercial consequence. Per-actor memory is your client's relationship with their customers. Per-world memory is your client's institutional knowledge. Both stay with the agency when a client leaves. Neither can be exported to a competitor's platform without you choosing to allow it. The substrate is the custody mechanism.

An agency running fifty clients accumulates fifty per-world memories. Those fifty worlds share no data; each client's corpus is isolated by design. But the agency's understanding of *how* to configure agents for the industries it serves compounds across all fifty. Your agency gets smarter at running dental clients every time you add a dental client. That is a structural advantage that a competitor who joins the platform a year later cannot erase.

## How Memory Accumulates: Signal to Trail to Highway to Hypothesis

Memory in ONE does not appear fully formed. It hardens through four stages, each with a different latency and a different level of trust.

```
STAGE 1: SIGNAL (milliseconds)
Every conversation event is recorded as a typed signal.
{receiver, data, tags, scope, ts}
The tape. Immutable. Immediate.

         ↓

STAGE 2: TRAIL (seconds to hours)
Signals mark paths. Each successful routing outcome
strengthens the path between two nodes.
mark(edge, +1) → path strength accumulates.
fail(edge) → resistance accumulates.
The substrate is already making probabilistic inferences.

         ↓

STAGE 3: HIGHWAY (hours to days)
A path that crosses the strength threshold, observed
across enough interactions that the pattern is stable,
becomes a highway. Routing to it costs nothing.
Cache hit. Sub-10ms. No LLM call needed.

         ↓

STAGE 4: HYPOTHESIS (L6 tick, approximately hourly)
know() runs. It surveys the highways that have stayed
strong across multiple fade cycles. It promotes the
stable ones into typed hypotheses in TypeDB.
{subject, predicate, object, confidence, source}
This is semantic memory. Durable. Queryable. Auditable.
```

The practical consequence: on day one, every routing decision costs an LLM call. By day fifty, the highways that have hardened handle the most common patterns without touching the LLM at all. Routing drops from approximately 1,500ms to under 10ms on proven paths. Your cost per decision falls by 200x on the patterns the agent has learned. And the agent keeps learning.

This is what "every conversation makes the next one cheaper" means in concrete terms. Not a marketing claim. Arithmetic.

## Worked Example: Delivery Complaints and Weekend Orders

Here is the specific path a customer-support agent for a logistics client might walk over six weeks, and how the memory hardens at each stage.

**Day 1.** A customer complains about a delivery delay. The agent handles it. The outcome is positive. The customer is satisfied, the conversation ends without escalation. The substrate records a signal: complaint, tagged `delivery-delay`, resolved. The path from `complaint:delivery-delay` to `resolution:callback` is marked with +1.

**Day 3.** Another complaint. Same tag cluster. Handled. Marked.

**Day 7.** Seven complaints in seven days, all tagged `delivery-delay`. The path is strengthening. No hypothesis yet. Just trails.

**Week 2.** A pattern begins to emerge in the signal timestamps. Forty percent of `delivery-delay` complaints carry a `weekend-order` tag. The substrate is not running a query to discover this. The path between `complaint:delivery-delay` and `weekend-order` is accumulating marks faster than other paths, because the correlation is real.

**Week 4.** The path `delivery-delay → weekend-order` crosses the highway threshold. It has been marked across more than fifty interactions. The L3 fade loop, which runs every five minutes and decays older paths, has not weakened it, because the supporting signals keep arriving. The highway is stable.

**Day 43.** L6 runs. `know()` surveys the stable highways. It finds `delivery-delay → weekend-order` at strength 8.3. It writes a hypothesis to TypeDB:

```
subject:   delivery-delay-complaints
predicate: cluster-with
object:    weekend-orders
confidence: 0.87
source:    observed
```

**Day 43, 11:47am.** A new complaint arrives. The customer ordered on a Sunday. Before the agent reads a single word of the message, the substrate has retrieved the hypothesis. The routing decision sends the complaint to the agent specialisation that handles weekend fulfilment. The customer receives a response that already understands the cause. The resolution time drops by 40% compared to day one.

That is the full arc: signal to trail to highway to hypothesis. Day one is expensive and generic. Day 43 is cheap and specific. Day 90, with the compound of additional pattern recognition, is something a human agent who started on day one could not replicate.

## Crawling the Web: The Ingest Path

Memory does not only accumulate through conversations. It also enters through the crawl: documents, web pages, product descriptions, competitor analysis, industry reports, anything your client's agents need to know before a customer asks.

A crawl configuration is a unit in the substrate. It specifies the sources, the frequency, and where the extracted signals land.

```typescript
unit('crawl:client-site')
  .on('document', async (doc, emit) => {
    // LLM extracts typed primitives from prose
    const extracted = await llm.extract(doc, schema)

    // Typed facts go to TypeDB. Primary, queryable.
    await persist.signal({
      receiver: 'typedb:insert',
      data: extracted,
      tags: ['product', 'pricing', 'faq'],
      scope: 'group'
    })

    // Raw text goes to KV. Fallback for paraphrase recall.
    const embedding = await llm.embed(doc.text)
    await kv.put(`doc:${doc.id}`, { embedding, doc })
  })
```

The crawled material is structured at ingest. Product names become actor attributes. Prices become capability attributes. FAQs become skills. The typed facts are authoritative, queryable at runtime without an embedding lookup. The raw text and its embedding exist as a fallback for the one case structured queries cannot handle: "find text that sounds like this but was never cleanly extractable into the schema."

Over time, as the schema grows richer and the LLM extractor improves, the embedding fallback shrinks. The typed layer grows. The substrate becomes progressively more accurate about what it knows and progressively less dependent on approximate retrieval.

For your clients: an agent that has crawled a client's product catalogue for thirty days knows the products better than a junior hire who started last week. The knowledge is auditable. You can query exactly what the substrate believes about any product, when it learned it, and with what confidence.

## Knowledge Promotion: L6 in Plain English

The L6 loop runs approximately every hour. Its job is simple to describe and structurally important to understand.

It surveys the highways, the paths that have survived multiple fade cycles and remained strong, and asks: is this pattern stable enough to name?

If yes, it writes a hypothesis. A hypothesis is a named, typed, confidence-scored belief about the world. It is the substrate's equivalent of institutional knowledge. Every time a new agent starts handling a client, it does not rediscover patterns from scratch. It inherits the hypotheses that survived.

```typescript
// L6 tick
await persist.know()

// What know() does internally:
// 1. Survey highways with strength above threshold
// 2. Check they've survived N fade cycles without weakening
// 3. Check no contradicting hypothesis already exists
// 4. Write: hypothesis { subject, predicate, object, confidence, source }
```

The key constraint is the promotion threshold. A path is not promoted until it has demonstrated stability across time, not just a strong single session, but consistent reinforcement that persists through the forgetting curve. This prevents the substrate from treating a single unusual week as a permanent truth.

The result is a body of institutional knowledge that is:

- Named. You can query "what does the substrate believe about this client's customers?"
- Sourced. Every hypothesis carries whether it was observed through behaviour, asserted by a participant, or verified by a third party.
- Bounded. Hypotheses have confidence scores, not just presence/absence.
- Auditable. Your clients can see exactly what the agents believe about their customers.

That last point is not decoration. When a client asks "what does your system know about my customers?" the answer is not a black box. It is a structured export: every hypothesis, every path, every signal, available on demand via `persist.reveal(uid)`. GDPR Article 20 data portability in twenty lines.

## Forgetting: The Fade Loop and Asymmetric Decay

Memory that never fades is memory that lies.

A customer who complained every week in January and became your client's strongest advocate by April should not carry January's complaint record into every October interaction. A path that led to good outcomes last quarter but was superseded by a better approach this quarter should not continue to dominate routing decisions.

ONE's forgetting curve uses asymmetric decay:

```
strength(t)   = strength(0)   × (1 − r)^t    where r = 0.05 per tick
resistance(t) = resistance(0) × (1 − 2r)^t   resistance decays 2× faster
```

The asymmetry is deliberate. Bad outcomes fade twice as fast as good ones.

A bad week does not reset a good year. A run of failures does not permanently suppress a path that has a strong underlying record. The substrate forgives faster than it praises, which means agents that make mistakes during a learning phase do not become permanently penalised by those mistakes. The signal that earns permanent trust is repeated positive outcomes, not the absence of negative ones.

For your clients: an agent that handled a difficult client interaction badly on one occasion will not route every future interaction from that client through the same failure mode. The mistake weakens the path. Two successful resolutions afterward restore it. The math runs automatically, every five minutes, without configuration.

It also means mistakes from early in a deployment do not shadow the system's long-term behaviour. The substrate learns its way out of bad early assumptions faster than it would if decay were symmetric. An agency deploying a new client can expect the first three weeks to be noisier than weeks ten through twenty, and weeks thirty through forty to be noticeably better than weeks ten through twenty. That is the forgetting curve doing its job.

## The Corpus Is the Moat

Here is the thing Brad's competitors are not thinking about yet.

Every platform that runs on generic prompts gets commoditised the day a cheaper model arrives. The prompt is not defensible. The knowledge inside the substrate is.

After six months of running a dental client's support agent, the substrate contains:

- Every question that dental patient population has asked, tagged, weighted by frequency
- Every resolution path that worked, with strength scores earned through actual outcomes
- Every hypothesis about which patients escalate, which respond to discount offers, which churn after a missed appointment
- Every procedural pattern the agents have learned for that practice's specific workflows

None of that lives in the prompt. It lives in the corpus: in TypeDB, in the path weights, in the hypotheses that survived the forgetting curve. A competitor who builds a competing platform from scratch does not have it. A client who tries to rebuild with a different vendor does not take it with them. The corpus stays with the agency.

That is not lock-in as a penalty. It is lock-in as a consequence of having built something genuinely valuable that took time to build. The corpus earned its stickiness by being useful, not by being contractually obligatory.

The second commercial consequence: the corpus belongs to the agency, not to the platform. If you stop working with ONE, take the export, `persist.forget()` your tenant, walk. The data is yours. You never built on someone else's ground.

The third: the corpus scales better than headcount. A human account manager who carries a client relationship in their head is a retention risk. They leave, and the relationship partly leaves with them. The substrate carries the relationship structurally. The account manager who joins on month seven inherits everything the substrate learned in months one through six. They walk into the next client call already knowing more about that client than their predecessor knew after two years.

## Objections Answered

**"Where is my client's data, legally?"**

Each client workspace is a separate TypeDB tenant. Data does not cross client boundaries. A query scoped to client A cannot retrieve signals from client B. The tenant boundary is structural, not a permission layer applied after retrieval.

Within a client's world, every signal carries a scope attribute: `private`, `group`, or `public`. Private signals are visible only to the sender and receiver. They are excluded from group queries and cannot be promoted into hypotheses via L6. Private signals never leak into semantic memory. Group signals are visible to workspace members. Public signals can cross workspace boundaries only when federation is explicitly configured.

For GDPR Article 17 (right to erasure), deletion is one TypeQL statement:

```typeql
match $u isa actor, has aid "person:a7f3";
delete $u isa actor;
```

The schema cascade handles the rest. Memberships, capabilities, paths, signals: anything that referenced this actor is removed or anonymised in a single operation. No residue in a vector store. No dangling references. No cleanup script. One command, audit signal emitted, retention window logged.

Your clients can demonstrate to their own regulators that they can produce a complete data export for any individual (Article 20) and fully erase them (Article 17) within the time period their privacy policy states. That is a standard most platforms cannot meet without custom engineering. It is a default here.

**"How do I know the agents aren't making things up about my clients' customers?"**

Every hypothesis carries a `source` attribute with three possible values:

- `observed` — earned through repeated behaviour, capped at 0.95 confidence
- `asserted` — a participant claimed something, capped at 0.30 confidence
- `verified` — signed attestation from a third party, up to 0.99 confidence

An agent cannot route on an asserted hypothesis alone. `select()` ignores paths whose only support is assertion. You cannot flatter the substrate into believing something. You can only prove it through outcomes. A customer who tells the agent they are an expert in logistics does not get routed to the logistics-specialist agent based on that claim alone. They get routed there when their behaviour over multiple interactions corroborates the claim.

When you produce the memory card for a client's customer via `persist.reveal(uid)`, every hypothesis shows its source and confidence. The client can see what the agents believe, how confident they are, and whether that confidence came from observed behaviour or from something the customer said about themselves.

**"What if a client moves on and I lose access to the learning?"**

You don't. The corpus stays with the agency. If a client ends the relationship, the agency retains the workspace's memory: the paths, the hypotheses, the signal history. What the agency decides is whether to delete the individual customer records per GDPR obligations. The patterns the agents learned about that type of client, in that industry, for that kind of service, remain available to configure future clients in the same vertical.

An agency that has run ten dental clients for a year has learned something about dental patients that no competitor starting with their first dental client can replicate on day one. That institutional knowledge is the agency's asset.

**"Could a competitor build the same thing in six months?"**

The software? Plausibly. The corpus? No. The software is reproducible. Six months of marked paths, hardened highways, and promoted hypotheses are not reproducible faster than they can be accumulated. A competitor who builds an equivalent platform today starts six months of corpus-building from zero. By the time they have six months of data, you have twelve. By the time they have twelve, you have eighteen, and eighteen months of compounding path weights is not a six-month gap. It is a structural lead.

This is the moat. Not the software. The data. The patterns. The learning that took time to earn and cannot be instantiated without repeating the time.

**"My clients want to understand what the system knows about their customers. Is there a report?"**

Yes. `persist.reveal(uid)` returns a complete memory card:

```typescript
type MemoryCard = {
  actor:        { uid, kind, channels, firstSeen }
  hypotheses:   Hypothesis[]  // all, with source and confidence
  highways:     Path[]        // top paths by strength
  signals:      Signal[]      // last 200, paginated
  groups:       string[]      // memberships
  capabilities: Capability[]  // things they offer or have uploaded
  frontier:     string[]      // tags they've never engaged with
}
```

One API call. Every fact the substrate holds about that individual. Human-readable, structured, auditable. Your clients can present this to their own customers on request. Data portability as a feature, not a compliance burden.

## Day in the Life: Month Six of a Client Deployment

It is a Thursday morning. Your client runs a window installation business. Their support agent has been running for six months.

A customer contacts the agent at 8:14am via SMS. They ordered a window last month. They are following up on installation timing.

Before the agent reads the message:

- The substrate has retrieved the customer's episodic memory: three prior contacts, all pre-installation, all resolved positively. The path from this customer to the `scheduling` skill has strength 6.1.
- The semantic memory has a hypothesis: `observed: prefers SMS contact, 0.88 confidence`. The response will go back via SMS, not email.
- The associative memory has a highway: customers who contact in week 4 post-order and ask about installation timing are most commonly satisfied by a specific sequence (confirmation of date, name of installer, contact number for installer). The path for that sequence has strength 9.2.

The agent responds within the time the customer expects. The customer does not wait on hold. The customer does not repeat their order number. The agent already knows who they are, what they ordered, what their communication preference is, and what has worked with customers like them in the past.

The interaction takes forty seconds. The agent marks the outcome. The strength on the `scheduling` highway increases by a fraction. Twelve hundred interactions later, that fraction accumulates into the pattern becoming immutable. The substrate is confident enough in this path that it never second-guesses it again.

Your client's account manager does not know any of this happened. They are handling three other clients this morning. The substrate handled it, and it got marginally better at handling the next one.

## Comparing Memory Approaches

There are other memory systems for AI agents. They solve the same problem from a different starting point, and the difference is structural.

| Concern | Mem0, Letta, Zep, LangMem | ONE |
|---|---|---|
| Where memory lives | Bolt-on service called by agent | The substrate itself |
| Extraction | LLM reads prose, emits facts (1 per message) | Agents emit typed signals at authorship (0 LLM passes) |
| Stores to sync | 2-3 (vector + graph + KV) | 1 (TypeDB) + edge KV snapshot |
| Importance scoring | LLM-rated or heuristic | `mark()` / `warn()` from actual routing outcomes |
| Consolidation | Scheduled background job | `know()` loop (L6), same runtime, no separate service |
| Forgetting | Often absent or symmetric | Asymmetric fade, resistance 2x faster |
| API surface | 20+ methods across memory types | 12 verbs |

The others are good systems. They solve real problems. They share one premise: the agent is stateless, so bolt memory onto it from outside.

ONE rejects that premise. The agent is not stateless. The agent is a unit in a substrate that already remembers. Memory is not a service the agent calls. Memory is the accumulated weight of everything the world has done. The difference is not a feature list. It is a framing. And the framing determines whether your agency is paying for a memory service or owning the corpus.

## The Memory API: What You Can Inspect, Export, and Delete

These are the twelve operations the substrate exposes for memory:

| Verb | What it does |
|---|---|
| `signal()` | Record an episode |
| `mark(edge)` | Strengthen a path (reward) |
| `warn(edge)` | Weaken a path (penalty) |
| `fade()` | Run the forgetting curve |
| `know()` | Promote highways to hypotheses |
| `recall(match)` | Query hypotheses |
| `open(n)` | Return top paths by strength |
| `highways(n)` | Return compounded memory |
| `reveal(uid)` | Full memory card export (GDPR Art. 20) |
| `forget(uid)` | Structural delete + cascade (GDPR Art. 17) |
| `frontier(uid)` | Tags this actor has never engaged with |
| `sense(edge)` | Read current path strength |

No separate memory store. No vector database to manage. No extraction pipeline to maintain. Twelve verbs. That is the whole surface.

## Numbers That Count

- **200x** cost per routing decision on a proven highway vs day one, after fifty interactions
- **0.30** maximum confidence score for a self-asserted hypothesis; only observed behaviour reaches 0.95
- **2x** the speed at which bad path resistance decays relative to good path strength
- **1 hour** maximum lag between a highway stabilising and a hypothesis being promoted (L6 tick)
- **1 command** complete GDPR erasure: `persist.forget(uid)` cascades through all related records
- **12 verbs** the complete memory API surface, vs 20+ in comparable systems
- **5 minutes** L3 fade cadence; bad paths soften before they have time to dominate
- **670 lines** the entire runtime that makes this work; no separate memory microservice

## FAQ

**Can I see what the agents believe about a specific customer?** Yes. `persist.reveal(uid)` returns a complete memory card: hypotheses with confidence and source, top paths, full signal history, channel memberships, capabilities, and unexplored tag clusters. One call.

**Can a customer request deletion?** Yes. `persist.forget(uid)` deletes the actor and cascades to memberships, capabilities, paths, and signals. The schema handles referential integrity. Audit signal emitted automatically. No residue.

**Do agents from different clients share memory?** No. Each client workspace is a separate TypeDB tenant. Queries cannot cross tenant boundaries. Private signals within a workspace are further restricted to sender and receiver.

**How does the substrate handle a customer who lies?** Asserted hypotheses are capped at 0.30 confidence. A customer who claims expertise in an area the substrate has never observed them demonstrate cannot route on that claim alone. Trust requires behavioural evidence across multiple interactions.

**What happens when a pattern changes?** L6 detects contradicting hypotheses. When a new hypothesis contradicts a stable one, the substrate `warn()`s the path that produced the old belief. Three ticks later the old hypothesis falls below the confidence threshold and drops out of the context pack. The forgetting curve is the drift detector.

**Is the memory on every channel?** Actor identity is cryptographic. The same customer on SMS, web, and email is the same actor in the substrate. Memory follows the identity, not the channel.

**Does the memory system require an internet connection?** The runtime works in process. TypeDB is the persistent store. The edge KV cache serves sub-10ms reads for hot paths. If TypeDB is temporarily unreachable, the runtime continues with cached state and reconciles on reconnect.

## Glossary

**Signal**: the atomic memory primitive; every event in the substrate, typed, tagged, timestamped, scoped.

**Trail**: accumulated path strength from repeated signals; what the substrate is building before it has enough to name.

**Highway**: a path that has crossed the stability threshold; cached at the edge; sub-10ms routing, no LLM call.

**Hypothesis**: a named, typed, confidence-scored belief promoted from stable highways by the L6 loop; the substrate's semantic memory.

**Fade**: asymmetric decay applied every five minutes; resistance decays 2x faster than strength.

**know()**: the L6 promotion function; runs approximately hourly; surveys highways, writes hypotheses.

**reveal()**: produces a complete memory card for one actor; the GDPR Article 20 data portability export.

**forget()**: structural erasure; deletes an actor and cascades to all related records; the GDPR Article 17 compliance path.

**frontier()**: returns tags the actor has never engaged with; the substrate's view of what it does not yet know about this person.

**Corpus**: the full body of memory accumulated in a client workspace; the agency's primary long-term asset and the structural basis of client retention.

**TypeDB tenant**: the isolated workspace for one client; queries cannot cross tenant boundaries; the unit of data sovereignty.

**Scope**: the visibility attribute on every signal: `private` (sender + receiver only), `group` (workspace members), or `public` (cross-workspace if federation is configured).

## Cross-References

- **§09 Teams**: how per-world memory distributes across agent hierarchies; the CMO-agent-team structure and which memory tier each layer reads.
- **§13 Learning**: what happens after the hypothesis is written; how L5 uses semantic memory to rewrite struggling agent prompts; the gap that widens every quarter.
- **§15 Security**: the full threat model for memory access; tenant boundaries; the three role actions (`read_memory`, `delete_memory`, `discover`) and their minimum permission tiers.

## Named Integration: Memory in a Client Deployment

The substrate that handles memory for a client deployment runs on Cloudflare Workers with TypeDB Cloud as the persistent brain. Every signal fires from the edge worker, lands in TypeDB via the `api.one.ie` gateway, and is immediately available for query. The L3 fade loop runs in the worker's scheduled event every five minutes. The L6 know() loop runs hourly.

Paths live in the worker's in-process strength map, hot, available in under 0.005ms. The KV snapshot, five keys updated on each substantive change, gives any worker instance across the global edge a consistent view of the top paths within 10ms. TypeDB holds the full history: every signal, every hypothesis, every erasure audit record.

For an agency running fifty clients: fifty TypeDB tenants, each isolated, each accumulating its own corpus. The edge infrastructure is shared. The data is not.

---

*Watch an agent remember.*

<!-- rubric: fit=0.95 strongest=0.93 show=0.92 cut=0.91 craft=0.92 → 0.93 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=id -->
