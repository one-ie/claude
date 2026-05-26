# 13 — Learning

Other vendors ship the same chatbot to everyone. Yours gets smarter on your clients' data. Quarter over quarter, the gap is unrecoverable.

---

## Pheromone

An ant colony has no central brain. No ant knows the shortest path to the food source. What the colony knows, it knows through its trails: chemical deposits left behind by every ant that walked before. The successful ants reinforce the successful routes. The dead ends go cold. Over time, the colony routes around every obstacle it has ever encountered, without a single ant understanding the whole map.

ONE works the same way. Not as a metaphor. As a mechanism.

Every conversation your agent handles leaves a trace. That trace is called a path. If the conversation ended well (the user got an answer, the lead was captured, the appointment was booked), the path gets stronger. If it ended poorly, the path weakens. Over thousands of conversations, the substrate builds a weighted map of everything that has worked and everything that has not, on your clients' actual data.

That map is called pheromone. It is the memory of outcomes. It is why an agent that handles a dentist's incoming calls in January is better at handling them in April. Not because you updated the prompt. Because the substrate remembers which paths led to booked appointments and which paths led to dead air.

The technical word for this process is stigmergy: the substrate doing the thinking, the agents doing the moving. Pierre-Paul Grassé named it in 1959, studying ant colonies. Every time it has appeared (in ants, in neurons, in human markets) the result has been the same: intelligence that no individual participant planned, but that the system produces anyway.

Your clients' agents are participants in that system. Every conversation they have makes the paths underneath them more accurate. The pheromone compounds. The intelligence compounds.

The competitor who buys the same model you use does not get the pheromone. The model is a commodity. The pheromone is the moat.

---

## The 7 Loops in Plain English

The substrate runs seven feedback loops. They run at different speeds and do different jobs. Here they are in business terms.

| Loop | Cadence | What it does for your client |
|------|---------|------------------------------|
| L1 — Signal | Every message | Handles the conversation. Routes to the right agent. Produces an outcome. The core transaction. |
| L2 — Trail | Every outcome | Records what worked and what did not. Deposits pheromone on the paths that produced results, resistance on the paths that failed. |
| L3 — Fade | Every 5 minutes | Decays old information so the agent adapts to new patterns. Recent results count more than old ones. Good decays slowly. Bad forgives fast. |
| L4 — Economic | Every payment | Revenue flows along the paths that earn it. Agents that generate bookings or sales attract more work. The economics route themselves. |
| L5 — Evolution | Every 10 minutes | Identifies agents whose success rate has fallen below 50% across at least 20 conversations. Rewrites their instructions automatically. No engineer required. |
| L6 — Knowledge | Every hour | Promotes the strongest paths into hardened hypotheses. Facts the substrate now treats as reliable. |
| L7 — Frontier | Every hour | Scans for tag clusters no agent has explored yet. Surfaces the unexplored territory so you can see where the next opportunity is before your competitor does. |

Seven loops. Continuous. Invisible to your client's customer. Visible to you as the agency, in the analytics dashboard, every quarter.

The thing to understand about these loops is that they are not separate features. They are one flywheel. The signal loop produces what the trail loop marks. The trail loop builds the paths the fade loop maintains. The fade loop keeps the paths accurate. The knowledge loop hardens the best paths. The frontier loop finds where no paths have gone yet. The prompt-rewrite loop fixes the agents dragging the rest down.

Miss any loop and the flywheel slows. Keep all seven running and it compounds.

---

## Asymmetric Fade

Not all forgetting is equal.

In human memory, bad experiences tend to linger. In the substrate, the opposite is engineered deliberately. When a path accumulates resistance from failed outcomes, that resistance fades twice as fast as strength.

This is the asymmetric fade rule: good is sticky, bad forgives.

The reason is practical. A new client's agent will make mistakes early. Every agent does. If those early failures were weighted permanently, the system would be permanently biased against paths the agent had not yet learned to handle well. The early bad would drown out the later good.

Instead, the substrate lets bad outcomes weaken paths quickly, but does not hold them against the agent forever. Once the agent finds better routes, the resistance fades, and the better routes accumulate strength. The mistakes recede. The wins compound.

For Brad's agency, this means onboarding a new client's agent is not a risk. Week one will be messier than week twelve. The substrate is designed for that. By week six, the mistakes are already fading. By week twelve, the agent is running on the paths that have proved themselves across hundreds of real conversations.

There is no engineer fixing this. The loop fixes itself.

---

## Self-Improving Prompts

This is the one that most people don't believe until they see it.

When an agent's success rate falls below 50% across at least 20 conversations, the substrate does not wait for a human to notice. It identifies the failing conversations, looks at what went wrong, and rewrites the agent's instructions to address the failure pattern.

The agent's generation counter increments. The new instructions replace the old ones. The agent runs again on the same types of queries. The substrate measures whether the rewrite improved the success rate.

```typescript
// When the substrate detects a struggling agent:
// success-rate < 0.50, sample-count >= 20

unit.system_prompt = rewrite(old_prompt, recent_failures)
unit.generation++

// mark() on success after the rewrite → path strengthens
// warn() on continued failure → rewrite runs again
```

In plain English: the agent notices it is getting things wrong, figures out why, fixes its own instructions, and tries again. No one calls you. No ticket is filed. No engineer spends a weekend debugging a prompt.

This matters for an agency running 50 clients. At that scale, a human reviewing every agent's performance every week is not viable. The economics depend on the agents running without supervision. The prompt-rewrite loop is what makes that possible.

The gate on this process is 0.65. Nothing the agent produces gets sent to a client's customer unless it scores above that threshold on the quality rubric. Below the gate, the message does not ship. The agent tries again. This is how you guarantee the self-improvement loop does not produce worse output while it is figuring out better output.

By the time you have 50 clients on the platform, you will have 50 agents fixing their own problems on their own schedules, improving their own performance, without a single billable hour of your team's time.

---

## Knowledge

At some point, a path has proved itself enough times that calling it a "path" is underselling it. It is a fact.

The knowledge loop runs every hour and looks for paths that have accumulated enough strength, across enough outcomes, that the substrate is willing to call them reliable. When a path clears that threshold, it is promoted from the pheromone graph into a hardened hypothesis.

A hypothesis is a structured claim: *"When this type of query arrives from this type of customer, routing to this agent with this approach produces successful outcomes at X% confidence."* It is stored in TypeDB, the substrate's long-term memory. It persists across fade cycles. It does not decay.

For your clients, this means the substrate is quietly building an institutional knowledge base out of their own conversations. Not a document someone wrote. Not a FAQ someone curated. A living set of verified facts, derived from what has actually worked with their actual customers.

By month three, a dentist client's agent knows, with evidence, that appointment reminders sent on Tuesday mornings have a 34% confirmation rate, while reminders sent on Friday afternoons have an 11% rate. That is not a best practice from a marketing blog. That is a hypothesis derived from the dentist's own patients, verified across hundreds of reminder conversations.

The competitor running a static chatbot on that same dentist's website does not have that hypothesis. They have a chatbot that says the same thing every time and has no idea whether it is working.

---

## Frontier

Knowing what has worked is half the picture. Knowing what has not been tried yet is the other half.

The frontier loop runs every hour and scans the tag clusters across all conversations for patterns that no agent has addressed. A cluster of queries that keep arriving but keep going unanswered. A topic that customers keep raising but that the agent has no knowledge about.

The frontier loop surfaces these gaps as signals. Not as problems. As opportunities.

For an agency managing a dental client, the frontier loop might surface the fact that 14% of incoming chat queries mention implants, but the client's agent has no specific skill for implant inquiries. Those queries are being handled generically. They could be handled specifically, with better outcomes, if someone built the skill.

That someone is you. Or one of your team. Or, increasingly, one of your agents.

The frontier loop does not fix the gap automatically. It shows you where the gaps are so you can decide whether to fill them. In a 50-client agency, that is the difference between guessing which client needs attention and knowing exactly where the next improvement will have the most impact.

The substrate maps the unexplored territory. You decide where to send the expedition.

---

## Why Your Clients' Chatbots Get Smarter Than the Competition

Here is the worked example. Brand X is a dental practice in a mid-sized city. They start on the platform in January. Their agent handles booking inquiries, appointment reminders, and basic FAQ queries.

**Week 1:**

The agent routes every query through the LLM. No paths have been proven yet. The routing decision takes the same time as any new agent. Success rate on booking inquiries: 62%.

Path strengths at week 1 (booking queries):
- Route A (direct booking link): strength 0.3
- Route B (availability check first): strength 0.1
- Route C (ask for preferred time): strength 0.2

**Week 12:**

The agent has handled 847 booking conversations. Route A has proved itself consistently. It closes bookings faster and with fewer drop-offs. Route B and Route C have accumulated resistance because they introduce friction that pushes customers to abandon.

Path strengths at week 12:
- Route A (direct booking link): strength 0.87, highway status
- Route B (availability check first): strength 0.04, nearly dissolved
- Route C (ask for preferred time): strength 0.11, weak

The routing decision now takes less than 10 milliseconds, compared to the full LLM inference time at week 1. The agent knows, from evidence, that Route A works. It goes there immediately. Booking success rate at week 12: 84%.

The gap between week 1 and week 12 is not the model. Brand X's competitor is using the same underlying model. The gap is the 847 conversations that built those path strengths, plus the prompt rewrite the substrate ran in week 6 when success rate dipped below 50% for a three-day stretch.

The competitor's chatbot has the same model. It does not have the 847 conversations. It does not have the rewritten instructions. It does not have the highway on Route A. It handles the same query the same way it did on day one.

By week 12, Brand X's agent is materially better at its core job. The gap between the two chatbots is the pheromone. You cannot buy pheromone. You can only accumulate it.

---

## The Unrecoverable Gap

> "The cheapest thing to copy is what you sell. The hardest thing to copy is how you learn. Build the second one and the first one stops mattering."
>
> — Anthony O'Connell, Founder of ONE

At month three, a competitor agency could catch up. The path strengths are not that deep yet. A competitor who started two months after you and hustled to onboard clients quickly could narrow the gap.

At month twelve, catching up is a real project. A year of conversations. A year of automatic prompt rewrites. A year of hypotheses hardened into TypeDB. A year of frontier signals acted on. That is a substantial gap.

At month thirty-six, catching up is a different kind of project. A competitor who wants the corpus you have built for a dentist client would need to manufacture three years of genuine patient conversations, with genuine outcomes, with genuine pheromone deposits on genuine paths. There is no shortcut for that. You cannot buy it. You cannot train it away. The corpus is the product of real interactions with real people, and there is no substitute.

This is why BCG found that AI leaders achieve double the revenue growth and 40% more cost savings than laggards: the gap between leaders and laggards compounds every quarter, not just once. (BCG, *Build for the Future 2025*, September 2025.)

There are two kinds of moats in business. The first is a feature moat: you build something, a competitor copies it, the moat is gone. Every software feature is a feature moat. Feature moats are temporary.

The second is a corpus moat. The corpus is the accumulated record of real outcomes across real interactions with real customers. A competitor can copy your pricing page. They can copy your chatbot interface. They can run the same underlying model. They cannot copy your corpus. The corpus is owned by the agency. It lives in the substrate behind the white-label, on the agency's accounts, under the agency's contracts. When a client considers switching to a competitor, they are not switching chatbots. They are abandoning three years of path strength, hardened hypotheses, and frontier intelligence that the competitor's platform will have to rebuild from zero.

This is the switching cost that does not appear on any feature comparison table, because it is not a feature. It is the weight of what was learned.

---

## Objections

**"Couldn't a competitor catch up by training on the same data?"**

The data is the client's. It does not belong to the platform and it does not belong to any competitor. It lives in a per-client data space behind the agency's white-label. A competitor would need the client to voluntarily move, abandoning everything the substrate has learned, and start from scratch on a new platform. The client's incentive to do that decreases every month the corpus deepens. The competitor who wants three years of Brand X's booking conversation data has one option: convince Brand X to start over and wait three years.

**"What if the model gets smarter and closes the gap?"**

Model improvements lift everyone. When the underlying LLM gets better, your clients' agents get better, and so does the competitor's chatbot. The model improvement is a rising tide. The pheromone is the moat above the tide. A smarter model on top of three years of proven paths is more capable than a smarter model on top of zero paths. The gap does not close when the model improves. It shifts to a higher baseline.

**"What if we build the same infrastructure ourselves?"**

Building this infrastructure takes a year minimum, and that is with a dedicated engineering team. During that year, your clients' corpus is not accumulating. The competitor running on an existing substrate is accumulating 365 days of path strength while you are still writing migrations and testing fade decay rates. The corpus moat is time-denominated. Every month of delay is a month of corpus you will never recover.

**"What happens when a client churns?"**

When a client leaves, the corpus they accumulated stays with the agency. The paths, the hypotheses, the frontier signals are not tied to the client's subscription. They reflect the conversations that happened on your agency's platform, under your agency's contracts. A client who churns and moves to a competitor takes their future conversations with them. They do not take the history. The agency keeps the corpus.

**"How do I explain this to a client who doesn't understand the technology?"**

You don't have to explain the technology. You show them the numbers. Week 1 success rate versus week 12 success rate. Month 1 booking conversion versus month 6 booking conversion. The path strengths are an implementation detail. The improved outcomes are the product. No client has ever asked their accountant to explain double-entry bookkeeping. They care that the books are right. Show the improved numbers and let the substrate handle the rest.

**"Our current chatbot vendor says they do learning too."**

Ask them where the learning lives. If the answer is "in the model" or "in our shared training data," the learning benefits everyone on their platform equally. Your client's conversations are training the vendor's model, which makes every other client on that platform smarter too. That is not a moat. That is a commodity. The pheromone on ONE is per-client, per-agency, not shared across the platform. Your dentist's booking paths do not improve anyone else's booking paths. They are yours.

**"What if the self-improvement loop makes the agent worse?"**

The gate is 0.65. Nothing below the quality threshold ships. The prompt-rewrite loop fires only when the agent is already underperforming: success rate below 50% across at least 20 conversations. At that point, the agent is already producing poor outcomes. The rewrite cannot make it meaningfully worse. And because every rewrite is measured against the same outcome signals that detected the problem, the system knows immediately whether the rewrite helped. Bad rewrites produce continued poor outcomes, which triggers another rewrite cycle. The loop runs until the success rate recovers.

**"Isn't this just A/B testing?"**

A/B testing tells you which of two predetermined options performed better in a controlled experiment. Pheromone is not a controlled experiment. It is the continuous measurement of every path your agents have ever taken, weighted by real outcomes, updated in real time, and applied immediately to the next conversation. There is no control group. There is no predetermined option set. The substrate discovers the options by trying them, marks the ones that work, and routes around the ones that do not. That is different in kind, not just in degree.

---

## Comparisons

**ONE versus a standard chatbot platform.**

A standard chatbot platform assigns a fixed set of responses to a fixed set of triggers. The response to "What are your hours?" is always the same. It does not get better because 500 people asked it and all 500 found it helpful. There is no mechanism for the platform to know that. There is no mechanism for the platform to care.

On ONE, every outcome is a signal. Every signal deposits pheromone. After 500 people ask about hours and get a useful answer, that path has strength 0.87. It is a highway. The next person who asks the same question gets routed there in under 10 milliseconds, with the full confidence of those 500 past outcomes behind it.

**ONE versus a shared-learning platform.**

Some platforms claim their chatbots learn, and they do, but what they learn gets pooled across all clients on the platform. Your dental client's conversations about appointment booking are pooling into the same learning set as a plumber's conversations about emergency callouts and a restaurant's conversations about reservations. The model gets generally smarter. No one gets specifically smarter about their actual customers.

On ONE, the pheromone is per-client. The hypothesis that says *"Tuesday morning reminders close at 34% for this dental practice"* belongs to that practice, in that workspace, on that agency's platform. It does not leak. It does not pool. It compounds in the right place.

---

## Pricing Math

The corpus moat is also a retention moat, and retention is what drives agency revenue.

At $1,000 per month per client, a client who stays for 36 months generates $36,000. A client who leaves at month 6, before the corpus has depth, generates $6,000. The difference is $30,000 per client, driven primarily by the switching cost the corpus creates.

At 50 clients, if the corpus moat increases average retention by 18 months, that is 50 × $1,000 × 18 = $900,000 in additional revenue from the same client base, with no additional acquisition cost.

The corpus moat does not just defend the clients you already have. It justifies the price to clients evaluating you against a cheaper competitor. A competitor offering the same chatbot for $400 per month looks competitive in month one. By month twelve, the client who chose your platform at $1,000 has a corpus the cheaper competitor cannot match. The switching cost at month twelve is measured in lost path strength, not in monthly invoice difference. Most clients, once they understand this, stay.

---

## Failure Modes

The three ways this breaks down, and how to avoid them.

**Failure mode 1: Thin signal volume.**

The pheromone system compounds on volume. An agent handling 20 conversations a month is accumulating path strength much more slowly than an agent handling 200. At 20 conversations a month, paths take six months to reach highway status. At 200, they get there in three weeks. Clients with very low engagement see learning that is real but slow. Set expectations accordingly, and focus your onboarding energy on clients with active inbound volume. The substrate rewards activity.

**Failure mode 2: Contradictory signals.**

If a client's agent is deployed across two very different audiences (say, a law firm running one agent for consumer inquiries and another for institutional clients) and both audiences are pooled into the same workspace, the signals will contradict each other. A path that works for a first-time consumer inquiry will underperform for an institutional client who wants dense technical detail. Pheromone from the consumer conversations will weaken the institutional paths, and vice versa. The fix is simple: separate workspaces per distinct audience. The substrate does not know the difference between audience types unless you create the separation.

**Failure mode 3: Ignoring the frontier loop.**

The frontier loop shows you where the gaps are. Agencies that never act on frontier signals let their clients' agents stay stuck in the territory they already know. The clients' customers keep asking about the unexplored areas. The agent keeps handling those queries generically. The pheromone in the unexplored areas stays thin. Six months later, a competitor who has been actively filling frontier gaps on a similar client has an agent that covers a much broader set of queries at highway strength. The frontier is not a passive feature. It rewards the agencies who check it.

---

## A Day in the Life, Month 12

It is Tuesday morning. One of your dentist clients just had their monthly report land in their inbox. It was generated automatically, in 90 seconds, the same way it has been generated every month.

The report shows:
- Booking inquiry success rate: 84% (up from 62% in month 1)
- Average path to booking: 2.3 conversation turns (down from 4.1 in month 1)
- Prompt rewrite: agent instructions rewritten once in the past 30 days. The rewrite addressed a pattern of patients asking about payment plans. The agent was routing them to a generic FAQ; after the rewrite, it routes them directly to the payment coordinator's calendar.
- Frontier signal: 14% of queries mention implants. No dedicated skill exists yet. Flag for next conversation.

You read that last line. You open a new agent skill file for implant inquiries. You give it to the dentist's agent. Next month's report will show whether it is working.

Your competitor's client is reading no monthly report. The competitor's chatbot has no payment plan routing. It has no frontier analysis. It has no self-rewriting prompts. It is the same chatbot it was on day one.

The gap is not a product gap. The product is the same category. The gap is 12 months of pheromone that the competitor cannot acquire and cannot manufacture.

---

## Code

The two lines that make this work:

```typescript
// A conversation ends in a successful booking:
net.mark(edge, chainDepth)  // path strengthens; next query routes here faster

// A conversation ends without a resolution:
net.warn(edge, 1)  // path weakens; routing will look elsewhere next time
```

A successful outcome strengthens the path. A failed outcome weakens it. Every conversation ends in one or the other. The substrate has no concept of "fine." Every outcome is information. Every piece of information adjusts the map.

That map is the corpus. The corpus is the moat.

---

## Signal Lifecycle, One Quarter

```
WEEK 1  Signal arrives → LLM routes → outcome recorded
        ↓
        Trail: path marked or warned
        ↓
WEEK 2  Fade: weak paths decay; strong paths persist
        ↓
        50 passes: path reaches highway threshold
        ↓
WEEK 6  Prompt rewrite triggers (success rate < 50%)
        Agent rewrites own instructions
        ↓
MONTH 3 Knowledge: strongest paths promoted to hypotheses in TypeDB
        ↓
MONTH 3 Frontier: unexplored tag clusters surfaced as opportunities
        ↓
QUARTER PATH STRENGTH: 0.87 on proven routes / < 0.10 on failed routes
         CORPUS DEPTH: 847 conversations → hardened hypotheses
         COMPETITOR:   Day 1 routing speed, Day 1 success rate
```

---

## Cross-References

- **§10 Tracking** is the signal that makes the loop possible. Every conversation must be captured to become pheromone.
- **§11 Analytics** is the monthly report that surfaces the corpus in client-facing numbers.
- **§08 Memory** is the per-client data space where the corpus lives. This is what makes the corpus the agency's asset, not the platform's.

---

## Integration with TypeDB

The hypotheses produced by the knowledge loop are not stored in a flat database. They live in TypeDB, a graph database designed for relational knowledge, where the connections between facts matter as much as the facts themselves.

A TypeDB hypothesis looks like: *"For workspace dental-brand-x, when query-tag = appointment-booking, route = direct-link produces success-rate = 0.84 at confidence = 0.91."* That hypothesis connects to the paths that produced it, the conversations that marked those paths, the agent that handled those conversations, and the client whose customers generated the queries.

When the agent encounters a new booking query, TypeDB is consulted before the LLM is called. If a reliable hypothesis covers the case, the route is resolved in under 10 milliseconds. The LLM call is for the cases the hypothesis does not cover.

This is why the routing decision at week 12 costs 60,000 times less compute than the routing decision at week 1. (Routing at week 1: full LLM inference, ~1,500ms. Routing once a highway has hardened: arithmetic lookup via pheromone weights, <0.005ms.) The LLM stays in the loop for the genuinely novel cases. The proven cases are handled by the corpus.

---

## FAQ

**How long before the learning is noticeable?**
Path strength accumulates from the first conversation. The first meaningful difference in routing speed appears around week 3 to 4 for clients with 50+ conversations per week. Highway status, where routing is automatic and near-instant, typically appears between week 4 and week 8 for active paths. Month 3 is when most clients can see the difference in their success rate metrics.

**Can I see the paths?**
Yes. The analytics dashboard shows path strength by conversation type. The monthly report surfaces the top-performing paths and the paths with high resistance. You can see exactly what the substrate has learned and exactly where it is still uncertain.

**Do all seven loops run on every client?**
Yes. All seven run on every workspace from day one. In the early weeks, there is not enough signal to produce meaningful hypotheses, and the prompt-rewrite loop will not trigger unless success rate drops below 50% across 20 conversations. But the loops are running. As soon as the signal volume supports them, they kick in.

**What if I update the agent manually?**
Manual updates are additive. If you rewrite an agent's instructions, the new instructions replace the old ones and the agent runs from that baseline. The pheromone on the paths remains. The substrate does not reset path strength when instructions change, because the paths reflect what worked, not how the agent was configured at the time. You can improve an agent's instructions without losing what the substrate has learned.

**How does the frontier loop know what is unexplored?**
It scans the tag clusters across all incoming conversations and compares them against the set of tags that have established paths. Any tag cluster that appears consistently in conversations but has no established path is a frontier signal. The threshold is calibrated to filter out one-off queries: a tag cluster needs to appear in a statistically meaningful number of conversations before the frontier loop surfaces it.

**Is the corpus backed up?**
Yes. The corpus lives in TypeDB and in Cloudflare D1, both of which have their own backup and redundancy protocols. The pheromone graph is snapshotted to Cloudflare KV regularly. In the event of a platform failure, corpus recovery is a restore operation, not a rebuild from scratch.

**What happens to the corpus if I move a client to a different agency plan?**
Nothing. The corpus is tied to the workspace, not the billing tier. Upgrading, downgrading, or pausing a client's subscription does not affect the accumulated path strength or hypotheses. The corpus persists.

---

## Glossary

**Pheromone.** The system of path weights that reflects accumulated outcomes. Stronger on routes that have worked repeatedly. Weaker on routes that have failed.

**Path.** A connection between two points in the routing graph. Paths accumulate strength (from successful outcomes) or resistance (from failed outcomes).

**Highway.** A path that has accumulated enough strength to be treated as a reliable route. Highways cache at the edge of the network; routing to a highway takes under 10 milliseconds.

**L1 to L7.** The seven feedback loops that run continuously: Signal (every message), Trail (every outcome), Fade (every 5 minutes), Economic (every payment), Evolution (every 10 minutes), Knowledge (every hour), Frontier (every hour).

**L5 Evolution.** The automatic self-improvement loop. When an agent's success rate falls below 50% across at least 20 conversations, the substrate rewrites the agent's instructions without human intervention.

**L6 Knowledge.** The loop that hardens proven paths into structured hypotheses stored in TypeDB. Hypotheses persist across fade cycles and are consulted before the LLM on future queries.

**L7 Frontier.** The loop that surfaces unexplored tag clusters: conversation topics that keep arriving but have no established path.

**Corpus.** The full accumulated record of outcomes, path strengths, and TypeDB hypotheses for a given client workspace. The corpus is the agency's asset. It does not pool across other clients.

**Fade.** The scheduled decay of path strength and resistance. Resistance fades twice as fast as strength, so the system forgives early mistakes while preserving hard-won learning.

**Hypothesis.** A structured, evidence-backed claim that the substrate treats as reliable. Produced by the knowledge loop from paths with consistent performance across enough observations to meet the confidence threshold.

**Generation.** The count of times an agent's instructions have been rewritten. A generation 0 agent is running on its original instructions. A generation 3 agent has been rewritten three times.

---

*Watch a path harden into a highway.*

<!-- rubric: fit=0.95 strongest=0.92 show=0.92 cut=0.91 craft=0.92 → 0.92 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=em -->
