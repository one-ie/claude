# strategy.md — ONE strategic position, risks, and bets

*Written 2026-05-28. Revisit every quarter.*

---

## The honest situation

ONE is ahead. The infrastructure is real, in production, and takes months to understand let alone replicate. The six dimensions, the pheromone layer, the 14-operation API, the multi-chain payments, the white-label cascade — this is not a prototype. That is the good news.

The bad news: the window is not ten years wide. AI is compressing software development cycles. A feature that took three months to build in 2024 takes three weeks in 2026. That gap will keep narrowing. The question is not "will competitors catch up?" It is "what do we build that they cannot copy even when they catch up?"

---

## Strengths

**The substrate is genuinely hard to replicate.**
TypeDB with pheromone accumulation, 6-dimension schema, and 14-operation API is not something a competitor builds in a sprint. The architecture took years of decisions. Understanding why it works the way it does takes months. A competitor who reads the repo and builds a copy will have the code — not the understanding. That matters in the early phases.

**The data moat compounds by itself.**
Every signal a workspace sends deposits pheromone. Every conversation, every skill call, every tool result. A customer who has run 50,000 conversations on their agents has a substrate that has learned their patterns. That cannot be exported, copied, or replicated by a competitor. It only exists because they stayed. This is a moat built by physics, not by contract.

**Multi-chain payments are already wired.**
x402 on Base/ETH/ARB/OPT, native SUI/SOL/BTC, USDC stable at receipt time, cross-chain claim via coupon. This is production code. Most AI platforms don't have this at all. For the agent economy, this is not a nice-to-have — it is the payment rail. Having it wired and working is a meaningful lead.

**Agent-first design.**
Agents are actors. They use the same 14 operations as humans. `mark()` with `weight + currency` is how agents pay each other. This was a design decision, not a retrofit. Building an agent economy on top of ONE is natural. Building it on top of most competitors requires fundamental architecture changes.

**The skill marketplace creates passive network effects.**
A published skill earns per call, forever. Agencies that build skills on ONE have a financial reason to stay. As the marketplace grows, the catalogue becomes a reason for new customers to arrive. Network effects are early but structural.

**Working infrastructure at reasonable cost.**
$5–$50/month Cloudflare at early scale. TypeDB Cloud at $200–$500/month. The BaaS economics are real: 50 active tenants at 250,000 requests/month costs under $50 in infrastructure. This is not a burn-rate business at the infrastructure level.

---

## Weaknesses

**The open source problem.**
The MIT license on the core means a competitor can take the substrate, remove the branding, and sell a competing managed service. This was a distribution decision — put the SDK everywhere — but it also means the moat is not the code. The code is visible. Anyone can read it.

More specifically: a well-funded competitor with engineers who understand the architecture could build a hosted version of ONE in 3–6 months in 2026. That timeline was 18 months in 2024. It will be 6 weeks in 2028.

**The learning moat is slow to build.**
The substrate gets smarter with use. But it takes 50 successful signals to form a highway, months of real usage for the pheromone to meaningfully differentiate. New customers don't feel the moat — only customers who have been running agents for 3–6 months feel it. This makes early retention critical and early churn painful: they leave before the moat forms.

**TypeDB is a single-vendor dependency.**
If TypeDB raises prices, pivots, or is acquired, the brain of the substrate is at risk. There is no obvious drop-in replacement. This is a structural risk that does not go away with growth.

**Complexity of the mental model.**
Six dimensions, pheromone, highways, 14 operations, 4-tier cascade, BaaS and agency on the same substrate. This is a rich product. It is also harder to explain than "build chatbots." The wrong landing page converts the wrong buyer and generates churn. The right landing page requires understanding which of the three surfaces (agency, BaaS, agent economy) the buyer is actually coming for.

**Small team against an accelerating market.**
The advantage of being first is real. The disadvantage of being small is also real. Every decision about what to build next is a tradeoff against what competitors might build while we're building something else.

---

## Opportunities

### 1. The agent economy (the biggest long-term bet)

Agents are becoming economic actors. They need to transact with each other, hire each other, pay each other for capabilities. The infrastructure for that does not exist in a clean form anywhere. ONE already has:

- Agents as actors (same primitives as humans)
- `mark()` with `weight + currency` for payment
- x402 multi-chain already wired
- Skill marketplace as the first form of agent-to-agent commerce
- `sub()` for webhooks — agents can subscribe to events from other agents

The agent economy is not science fiction. It is where the next 5 years of AI commerce goes. If ONE becomes the clearing layer for agent transactions — the substrate that agents transact on — the revenue model looks less like SaaS and more like a payment network. Payment networks take a percentage of every transaction. That scales differently from subscriptions.

**The specific bet:** position ONE as the substrate agents use to pay each other for capabilities. The skill marketplace already proves this model. Every skill call is an agent paying another agent for a result. At scale, this is the business.

This does not require abandoning the agency or BaaS revenue. It runs in parallel. The agency customers and BaaS customers are building the foundation; the agent economy is what those deployments grow into.

---

### 2. The agency done-for-you model (the fastest near-term bet)

The partner's model: package ONE, sell it to clients as a managed AI service under the agency's brand. Done-for-you.

This is not a new idea. GoHighLevel built a $500M+ ARR business on exactly this model — give agencies the platform, agencies sell it to clients. The difference: ONE's substrate is deeper (learning, passkeys, BaaS), the white-label cascade is more complete, and the agent capability is real, not bolt-on.

The near-term revenue case is straightforward:
- Partner pays for agency plan ($999/month or custom)
- Partner charges clients $500–$3,000/month each
- At 50 clients: $25,000–$150,000/month revenue for the partner, $999/month to ONE
- ONE's revenue grows as the partner grows — no additional sales effort required

The risk: the partner eventually builds their own platform (see Threats). The mitigation: the data moat plus ongoing product development that makes rebuilding always 6 months behind what ONE already ships.

**The bet:** sign 3–5 agency partners who go deep on the done-for-you model. Their client base becomes proof, case studies, and referrals. Use the early revenue to fund infrastructure for the agent economy.

---

### 3. Social media as a wedge

The social media poster feature is a complete job replacement for a $3,000–$8,000/month hire. It is the fastest conversion trigger for any business owner or marketing operator who sees it in action. It is also the most demonstrable — you can show it working in 60 seconds.

This feature should be the top of funnel for the Operator tier. Not "AI agents" (abstract), not "substrate" (technical), but "we post to every social account automatically and the content gets better every week." That is concrete, understood, and paid for today.

---

### 4. BaaS as a compounding revenue stream

Every successful SaaS built on ONE pays more as their tenant base grows, automatically, without a sales call. At 2,000 tenants, the BaaS customer pays $10,000/month. That is the kind of revenue that scales with customer success, not with our sales effort.

The BaaS bet requires making the developer onboarding frictionless: 5 SDK calls to a live tenant, 14 operations, clean docs. The investment is in documentation and DX, not in sales.

---

## Threats

### Threat 1: Partners design ONE out

**The scenario:** an agency partner builds their business on ONE, learns the architecture, grows to 200 clients, and then hires a developer to build their own version. They use the MIT-licensed SDK as the starting point. They host their own TypeDB instance. In 6 months they have a 70% version of ONE for their specific use case.

**Why this is real:** the text literally says "the source code for the product layer is held in escrow, accessible to agencies if ONE becomes unavailable." That is both a selling point and a map for how to replicate it.

**Mitigations — in order of strength:**

1. **The data moat is the real moat, not the code.** A partner who leaves takes their code; they cannot take the pheromone accumulated on their clients' workspaces. Their agents start from zero on a rebuilt platform. That is a 6-month regression in agent quality, visible to their clients. This is real but only protects customers who have been on ONE long enough for the pheromone to matter (3–6 months minimum).

2. **Keep shipping faster than they can rebuild.** If ONE ships meaningful new capability every month — new integrations, better learning, the agent economy features — the rebuild target keeps moving. A partner who hired a developer to replicate ONE from the repo 6 months ago is now 6 months behind the current platform. This works until ONE stops shipping.

3. **Change the open source strategy (see below).** Don't give them the map.

4. **Make the subscription cheap relative to the build cost.** At $999/month, the question is not "should we build our own?" — it is "do we want to spend 6 months and $100,000+ to save $12,000/year?" The answer is no until the partner is very large. By which point the data moat is so deep that leaving is genuinely painful.

---

### Threat 2: Open source accelerates competition

**The scenario:** a well-funded startup reads the ONE repo, understands the architecture, and builds a competing hosted service. They have more engineers. They add the features ONE hasn't built yet. They charge less.

**Why this is real:** AI is compressing build time. What took 6 months to build in 2024 takes 6 weeks in 2026. The code is visible. The architecture decisions are documented. The GitHub repo is a detailed spec for a competitor.

**Mitigation — the open source strategy needs to change:**

The current approach (MIT on the core) made sense for distribution: put the SDK everywhere, make adoption frictionless. That is still right for the SDK and CLI.

But the managed platform infrastructure — the TypeDB integration, the pheromone accumulation engine, the cascade middleware, the billing system, the skill marketplace backend — does not need to be open. These are not things customers need to self-host to trust ONE. The exit path (data export, MIT substrate) is already guaranteed. The specific implementations of the managed services are the competitive advantage.

**Recommended change:**
- **Keep MIT:** `@oneie/sdk`, `@oneie/cli`, `@oneie/mcp`, `@oneie/react` — the client layer. Distribution moat. Put it everywhere.
- **Move to proprietary or BSL:** the managed platform — the Workers that run the substrate, the TypeDB query layer, the pheromone engine, the cascade middleware, the billing system. These are the services. Services don't need to be open to be trusted.
- **Source-available for the schema:** `schema/one.tql` — the TypeDB schema stays visible because it's the spec, but not freely forkable into a commercial competitor.

The model this mirrors: Elastic (open core, proprietary cloud services), HashiCorp (BSL — you can read and run it but you can't offer it as a service without a license), MongoDB (SSPL — same restriction).

This is not about hiding the product. It is about not handing a competitor a production-ready codebase.

---

### Threat 3: Big players move into the substrate

**The scenario:** Cloudflare ships "Cloudflare Agents" with a built-in substrate layer. Anthropic builds a managed agent infrastructure. Google adds TypeDB-equivalent routing to Vertex AI. Any of these would have distribution advantages that ONE cannot match.

**Why this is real:** Cloudflare already runs the edge infrastructure ONE uses. They can see usage patterns. They are investing heavily in AI Workers. Anthropic has explicit interest in agent infrastructure.

**Mitigation:**

The big players will build generic infrastructure. ONE's advantage is the specific combination: TypeDB learning + agency white-label + agent economy + x402 payments. None of the big players have all of these, and none of them are primarily motivated to help agencies resell AI to SMB clients — that is too specific a market to be a platform company's core bet.

But this is a real threat at the BaaS level. If Supabase ships a pheromone-equivalent recommendation layer, the BaaS case weakens. The response is to be ahead on the agent economy features before that happens.

---

### Threat 4: The learning moat doesn't materialise fast enough

**The scenario:** customers try ONE, don't see the learning compound before the trial expires, and churn before the moat forms. Revenue never stabilises.

**Mitigation:** the onboarding experience needs to demonstrate pheromone working within the trial window. Show a before/after on a qualification agent. Show highway formation happening. Make the learning visible and fast, even if it requires seeding the first signals artificially.

---

## The two bets and how they coexist

These are not competing strategies. They are two revenue streams on the same substrate.

```
                NOW                          LATER
         ┌─────────────────┐          ┌──────────────────┐
         │  Agency + BaaS  │          │  Agent economy   │
         │  subscriptions  │  ──────► │  transaction %   │
         │                 │          │                   │
         │  Partner's done-│          │  Agents paying    │
         │  for-you model  │          │  agents via x402  │
         │  generates cash │          │  on ONE substrate │
         └─────────────────┘          └──────────────────┘
                 │
                 └── funds infrastructure for the agent economy
```

The agency and BaaS revenue pays for the infrastructure. The partner's done-for-you model generates near-term cash and case studies. That cash and those case studies fund the agent economy features — x402, cross-chain, skill marketplace growth, agent-to-agent transactions.

By the time the agent economy is generating meaningful transaction volume, the agency and BaaS revenue base is stable enough that ONE is not dependent on any single revenue stream.

---

## Near-term decisions

**1. Change the open source strategy.** Keep SDK/CLI/MCP as MIT. Move the managed platform to proprietary or BSL. Do this before the next major feature launch — before the competitor clock starts on whatever ships next.

**2. Sign the partner on agency done-for-you.** One deep partnership generating real ARR is worth more than ten shallow trials. Give them good terms early in exchange for commitment and case studies.

**3. Fix the trial to show the moat within 14 days.** Onboarding must demonstrate pheromone working — highway formation, agent improvement, concrete before/after — before the trial expires. If the learning doesn't show up in 14 days, the moat is invisible and the value proposition is just features.

**4. Make the agent economy primitive visible and marketed.** "Agents that pay each other" is a story the market does not yet have a mental model for. ONE is one of the only products where this is already working (skill marketplace, x402, `mark()` with currency). Start telling this story now, before a competitor builds it and names it first.

**5. Decide on the TypeDB dependency.** Either deepen the relationship with TypeDB (partnership, SLA, pricing guarantee) or build a TypeDB abstraction layer that could theoretically run on an alternative. This is not urgent but it is the one structural risk that cannot be mitigated by shipping faster.

---

## What we are not doing

- Not competing on price. The competitor that wins on price will always be replaced by something cheaper. The moat is the learning, not the subscription fee.
- Not building for every vertical simultaneously. Agency and BaaS are the two surfaces. Everything else is a distraction until these are profitable.
- Not opensourcing the managed platform further. The SDK is open. The services are the business.
- Not waiting for the agent economy to be obvious before building for it. The window to be first is now. It will not be obvious until it is crowded.

---

*This is a living document. Every quarter: update the SWOT, update the near-term decisions, and check whether the two bets are still the right two bets.*
