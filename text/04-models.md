# Pick the Model. Swap It in One Line.

You are not locked into any AI vendor. Not today, not when a better model ships next quarter, not when your favourite provider triples its prices. You pick the model per agent, per skill, per cost target. When the landscape shifts, you change one field in a markdown file and the platform catches up.

That is not a feature. It is a business decision you get to keep making.

---

## Any Model

The catalogue today stands at over 300 models. Claude Haiku, Claude Opus, GPT-5, Gemini 2.5 Flash, Grok 4, Llama 3, Mistral, Qwen, Command R+, and a hundred others you have not heard of yet but will when they beat the current leader on a specific task. Every one of them is reachable through a single line in your agent definition.

The platform routes through OpenRouter as its default provider. OpenRouter maintains the catalogue. You benefit from every model they add without touching your code.

```yaml
# agents/sales-qualifier.md
name: sales-qualifier
model: anthropic/claude-haiku-4-5
```

Change that one field. That is the entire migration.

Groq is available as a direct opt-in when you need sub-200ms first tokens and the task does not demand reasoning depth. The AI SDK Gateway sits underneath both as a fallback chain. If a provider goes down or rate-limits you, the next one in the chain picks up the request. Your agents keep running.

The routing fallback looks like this:

```
Default (OpenRouter gateway)
  └── model available? → serve
  └── model unavailable or rate-limited?
        └── Groq direct (if groq model specified)
              └── Groq available? → serve
              └── Groq unavailable?
                    └── AI SDK Gateway fallback
                          └── degraded mode (cached last response or graceful error)
```

Your agents do not go silent when a provider has a bad hour.

---

## Why Model Choice Is a Product Choice

Every model sits somewhere on a triangle. Cost. Latency. Quality. Moving along any edge trades against the others.

Claude Haiku processes 1,000 input tokens at 25 credits. Claude Opus processes the same 1,000 tokens at 1,500 credits, 60 times more expensive. GPT-5 lands at 1,250 credits per 1,000 input tokens. The gap in reasoning quality between Haiku and Opus is real. So is the gap in your operating cost.

The decision is not "which model is best." It is "which model is right for this task at this cost target."

A sales qualification agent that triages 500 inbound leads a day does not need Opus. It needs to read a contact record, ask two clarifying questions, and route the lead to the right bucket. Haiku does this accurately at a fraction of the cost. You save the Opus-grade reasoning for the moment in that sales flow where it matters: the contract review, the proposal draft, the one-shot analysis where getting it wrong costs a client relationship.

That distinction is a product decision. It determines your margin. An agency that runs every agent on Opus because it feels safer is an agency that cannot compete on price when the client eventually notices the bill. An agency that routes intelligently (triage on Haiku, depth on Sonnet, one-shot review on Opus) can charge the same rate, deliver the same quality, and keep 20 extra points of margin per client.

The platform makes the routing decision explicit. You set it. You own it.

---

## Per-Agent vs Per-Skill Model Binding

The model field in an agent definition sets the default for everything that agent does. Individual skills within that agent can override the default for specific tasks.

A content agent might default to Claude Sonnet for its general work: drafting blog posts, rewriting copy, answering brand questions. When a client asks it to review a 40-page strategy document and extract the three most important commercial risks, you can bind that specific skill to Opus. One conversation. Two models. The cost tuning happens at the level of the work, not the level of the agent.

This is how you build a practice that scales. Define the skill, bind the right model to it, let the platform route accordingly. The client sees one agent. You see one cost-tuned workflow.

The agent markdown contract makes this explicit and auditable. Every agent file is plain text. Every model assignment is visible. Nothing is hidden in vendor configuration panels you cannot read.

```yaml
# agents/content-team.md
name: content-team
model: anthropic/claude-sonnet-4-7    # default for all skills

skills:
  - name: draft-post
    model: anthropic/claude-haiku-4-5  # override for high-volume task
  - name: strategy-review
    model: anthropic/claude-opus-4-7   # override for high-stakes task
  - name: brand-check
    # no override — inherits sonnet from agent default
```

The output cost is the sum of actual work done at the appropriate tier. Not a flat rate on the most expensive model in the fleet.

---

## The Routing Fallback Chain

Under normal conditions, the platform routes to your chosen model through the OpenRouter gateway. Over 300 models. One API key. The gateway handles authentication, rate pooling, and load balancing across providers.

When you need speed over depth (and for many agency tasks you do) Groq is available as a direct provider. Groq runs inference on custom silicon. The result is a median time to first token that competes with nothing else on the market for models at the Llama 3 / Mixtral tier. First-token latency in interactive contexts determines whether the conversation feels live or laggy. For your clients' end customers, that difference is felt within the first three seconds of every interaction.

The AI SDK Gateway is the fallback layer. When the primary provider returns an error or a timeout, the Gateway routes to the next available option. When no live model is reachable, the platform degrades gracefully, serving a cached response where one exists or returning a structured error your agent can surface cleanly.

None of this requires configuration. The chain is built in. You choose your primary model. The rest is handled.

---

## BYOK and Provider Keys

You can run entirely on the platform's credit pool. That is the default. You buy credits, the platform routes them to the appropriate provider, and you pay one consolidated bill.

If you have existing agreements with Anthropic, OpenAI, or Google (enterprise pricing, volume commitments, data residency requirements) you can bring your own keys. Set your provider API key in the workspace settings. Agents that target that provider route through your key, not the platform's pool.

The operational model stays the same. You still define models in agent markdown. The platform still handles the routing logic. The bill goes to your provider account instead of your credit balance.

For most agencies starting out, this distinction does not matter. You run on credits, you mark them up, and you watch the unit economics work. For agencies with existing enterprise contracts or data residency obligations, BYOK is the path that keeps those agreements intact.

---

## How Credits Map to Upstream Cost

Credits are the platform's unit of account. Every token consumed by an agent costs a defined number of credits, whether it is generating a response, processing a tool call, or classifying an incoming message. The exchange rate between credits and real cost is public and fixed.

| Model | Input per 1k tokens | Output multiplier | Notes |
|---|---|---|---|
| Claude Haiku 4.5 | 25 credits | 5× input rate | Best for high-volume triage |
| Claude Sonnet 4.7 | 300 credits | 5× input rate | Default for most client work |
| Claude Opus 4.7 | 1,500 credits | 5× input rate | Reserve for one-shot deep analysis |
| GPT-5 | 1,250 credits | 8× input rate | Strong on code and structured reasoning |

The markup layer sits between your cost and what you charge clients. You set it. If you buy credits at the platform rate and distribute to client workspaces at 2× markup, every credit your clients consume generates a margin before you have touched the work. If upstream model prices fall (and they will, because they always do) your cost drops and your margin expands unless you choose to pass the reduction to clients.

That is the economics of a reseller on a substrate. Your pricing decision is decoupled from the vendor's pricing decision. You move when you want to, on your timeline, not the provider's.

---

## The 18-Month Price Collapse

This is the number that matters for how you price your services in 2026 and 2027.

Claude 3 Opus launched in March 2024 at \$15 per million input tokens. Sixteen months later, Claude Haiku 4.5, a model that outperforms Claude 3 Sonnet on most agency tasks, costs \$0.80 per million input tokens. The cost of a comparable quality tier dropped roughly 95% in under two years.

GPT-4 launched in 2023 at pricing that made large-scale deployment prohibitive for most agencies. Today, models at GPT-4 quality or better are available at prices that make per-client deployment an afterthought in the unit economics.

The direction is not ambiguous. The cost of intelligence is collapsing. It has been collapsing every quarter for four years. There is no structural reason for it to stop.

For you, this means two things. First, your cost to deliver AI services will continue to fall even if you do nothing. Second, competitors who built their service pricing on today's model costs will be undercut by the market itself within 18 months.

The agencies that survive this are the ones whose pricing is not pinned to model costs. You are not selling tokens. You are selling outcomes: qualified leads, answered questions, written copy, managed relationships. The token cost is an input you manage down. The outcome is what the client pays for.

The platform lets you swap models without rebuilding your service. When a better model ships at lower cost, you update one field in an agent definition and the improvement lands across every client workspace automatically.

---

## When to Use Haiku vs Sonnet vs Opus vs Open Weights

The choice is not about which model is smartest. It is about matching cost and latency to the task.

**Haiku** for any task where volume is high and the decision is bounded. Lead triage. Message classification. FAQ responses. Sentiment tagging. Content moderation. These tasks run hundreds or thousands of times per client per day. Running them on Haiku at 25 input credits per 1,000 tokens keeps the unit economics intact. Haiku's speed advantage also matters here. Faster first tokens mean more responsive conversations.

**Sonnet** for the daily work of an agency. Drafting copy. Rewriting briefs. Answering complex client questions. Generating social content with brand context. Sonnet sits at the right point on the cost-quality triangle for tasks that require genuine intelligence but do not demand Opus-level depth. Most of what a marketing agent does day to day runs well on Sonnet.

**Opus** for moments that justify the cost. A 40-page strategy document that needs genuine analysis. A contract that requires close reading. A one-shot proposal where the quality of the output directly affects whether a client renews. Opus at 1,500 input credits per 1,000 tokens is expensive. It is also the right tool for the work that earns client trust. The skill binding described above lets you reserve it for exactly those moments without applying it to everything.

**Open-weight models** via Groq for latency-sensitive interactive tasks where Llama 3 70B quality is sufficient. Customer support triage. First-response handling. Any task where the user is waiting and the decision is not complex. Groq's custom inference hardware delivers first tokens that feel immediate in a chat interface. For your clients' end customers, that matters.

The platform does not dictate a choice. It makes all of them available, lets you bind the right model to the right task, and gets out of the way.

---

## A Day in the Life: A Sales Agent That Routes by Task

A dental practice client. Seven ICPs, one of which is multi-location dental operators. The sales agent handles inbound enquiries, qualifies leads, drafts proposals, and flags contracts for human review.

The agent runs on Claude Sonnet by default. Haiku handles the initial classification: is this a qualified lead or a spam submission? The classification call costs under five credits. It runs in under 150 milliseconds. Every inbound enquiry goes through it.

Qualified leads move to the main agent. Sonnet handles the conversation, asking qualifying questions, pulling context from the CRM, drafting a summary of what the prospect needs. A conversation that takes 20 exchanges at an average of 200 tokens per turn costs roughly 1,200 credits in total. At the agency's 2× markup, the client pays 2,400 credits. The platform's cost was 600.

When the conversation reaches proposal stage, a skill binding kicks in. The proposal-draft skill runs on Sonnet with extended context. The output is a formatted proposal document with the client's brand, the prospect's specific situation, and a pricing recommendation based on the prospect's stated volume. Total cost for the proposal generation: around 800 credits of Sonnet output. The proposal closes deals at a rate the practice owner's previous manual process could not match.

Contracts that come back for review go through a single Opus call. The contract-review skill reads the document, flags non-standard clauses, and returns a structured summary with three bullet points the account manager needs to know before signing. One Opus call at maybe 3,000 input tokens costs 4,500 credits. That call replaces an hour of a human's time on a task where a mistake costs far more than the model.

Total credit cost for a complete sales cycle: roughly 7,000 credits. At a 2× markup, the client pays 14,000. The agency's gross margin on the AI layer: 50%. The relationship and the strategy are still the agency's product. The execution is running on the platform.

---

## Worked Example: Credit Cost per Conversation

Three agents. One sales cycle. Real credit arithmetic.

The triage agent (Haiku, 25 credits/1k input) handles 500 inbound enquiries per month for one client. Average enquiry is 150 tokens. Average classification response is 50 tokens.

- Input: 500 × 150 tokens = 75,000 tokens × 25 credits/1k = 1,875 credits
- Output: 500 × 50 tokens × 5 (Haiku output multiplier) = 62 credits
- Triage monthly cost: ~1,937 credits

The qualification agent (Sonnet, 300 credits/1k input) handles the 60 leads that pass triage. Average qualification conversation: 2,000 input tokens, 800 output tokens.

- Input: 60 × 2,000 tokens × 300 credits/1k = 36,000 credits
- Output: 60 × 800 tokens × 5 = 240,000 token-weighted credits / 1k = 1,500 output cost
- Qualification monthly cost: ~37,500 credits

The proposal agent (Opus, 1,500 credits/1k input) handles the 12 qualified leads that reach proposal stage. Average proposal: 5,000 input tokens, 2,000 output tokens.

- Input: 12 × 5,000 × 1,500/1k = 90,000 credits
- Output is priced at 5× input rate for Opus: 5 × 1,500/1k = 7.5 credits per output token per 1k
- Output: 12 × 2,000 tokens × 7.5 credits/1k = 180 credits
- Proposal monthly cost: ~90,180 credits

Total platform cost for all three agents, one client, one month: approximately 129,617 credits.

At a 2× markup, the client pays 259,234 credits worth of billing. Agency gross margin on the AI layer: roughly 50%. That is before the agency's own service fee on top. The credit layer alone runs at margin. The service sits above it.

---

## Pricing Math: What "Model Choice" Does to Your P&L

Scenario: 50 clients. Each client runs the three-agent sales stack above.

At 2× markup across the board, monthly AI revenue: 50 × 259,234 = ~12.96M credits billed. Monthly AI cost: 50 × 129,617 = ~6.48M credits consumed.

Now consider the 18-month price trajectory. If input costs fall 50% across the board, consistent with the historical rate, and the agency holds its billing rate:

Monthly AI cost drops to ~3.24M credits consumed. Revenue stays at ~12.96M credits billed. Margin on the AI layer expands from 50% to ~75%.

The agency did not renegotiate with a client. The agency did not change its service. The upstream cost fell and the margin improved automatically.

This is why model flexibility is not a technical preference. It is a financial position. An agency locked to a single vendor at a fixed pricing tier loses this option. An agency on a substrate that routes across 300+ models retains it.

---

## Objections Answered

**"What if the model I've built around gets deprecated?"**

Every provider deprecates models. GPT-3.5, Claude 2, PaLM, all retired on timelines the vendors chose. The question is whether your agents break when that happens.

On this platform, the model field in an agent definition is a string. Change the string, the agent switches. No rebuilding, no re-prompting exercise, no call to a developer. The platform maintains an alias map. `haiku-latest` always resolves to the current Haiku generation. If you want to pin to a specific version, you can. If you want to follow the latest, you can. The choice is yours at the agent level.

Deprecation policy: the platform gives 90 days' notice on any model removal from the gateway. During that window, the alias continues to resolve and your agents continue to work. At the end of the window, the alias either redirects to the successor model or requires a one-field update if no clear successor exists.

**"What if I build my service around one model's specific behaviour and a swap breaks it?"**

This is a real risk. Different models handle edge cases differently. A prompt written for Sonnet may produce different output when run on GPT-5 for the same input.

The answer is that the platform does not force model swaps. You choose when to change. You test in a staging workspace before rolling to clients. The eval loop that ships with every agent gives you a deterministic quality gate. The agent runs against a set of reference inputs and the outputs are scored before you change anything in production.

Model swaps that pass the eval gate ship. Swaps that fail tell you what to fix. The gate is a number, not a judgment call.

**"What if I trust OpenAI more than Anthropic for my clients' data?"**

BYOK. Point your OpenAI key at the workspace. Every agent in that workspace routes to OpenAI. The platform does not touch the data in transit; it passes the request through to the provider you have a data processing agreement with.

The platform's own credential handling is covered in section 15. The short version: provider keys are stored in encrypted environment variables, never logged, never exposed to the client-facing surface.

**"What about open-source models? I don't want to depend on commercial providers."**

Open-weight models run through the same gateway. Llama 3, Mistral, Qwen, Falcon. If OpenRouter carries them, you can route to them by name. Some clients in regulated sectors prefer to know their data goes through an open-weight model where the weights are auditable. That is a valid requirement. It is a one-field change in the agent definition.

**"Our team built workflows around a specific model's tool-calling format."**

The AI SDK Gateway handles format translation at the protocol level. You write one tool definition. The platform serialises it appropriately for whichever provider you target. Switching from Anthropic's tool format to OpenAI's function-calling format is not something you manage. The SDK layer handles it.

**"What if the model prices go up?"**

They have been going down for four years. If a specific model's price increases, you swap to a comparable model at a lower cost tier. The catalogue is large enough that there is always an alternative within the quality range you need.

**"Can I mix commercial and open-weight models in the same agent team?"**

Yes. Each agent has its own model binding. A team of five agents can run across five different models simultaneously. The signals flow between agents through the substrate; the model each agent uses is local to that agent. There is no constraint that forces uniformity across a team.

**"What if Groq's infrastructure is unreliable?"**

The fallback chain handles it. Groq is an opt-in speed layer, not a dependency. If Groq is unavailable, the routing falls back to the gateway default. The agent keeps working. You may notice slightly higher latency in the fallback path. The conversation does not fail.

---

## Comparisons

**This platform vs a single-model SaaS tool**

A single-model SaaS tool gives you one model, one price tier, and one set of capabilities. When a better model ships, the vendor decides whether and when to adopt it. You wait. When prices change, you pay the new price or find a different tool. When the model produces the wrong output for your use case, you work around it with prompt engineering because you have no alternative.

This platform gives you the catalogue. You pick. You swap. You match the model to the task. The vendor relationship is with the platform, which sources from the model providers. Your relationship with the model market is mediated by one key and one API.

**This platform vs building your own routing layer**

Building your own model router is a real option. It takes a senior engineer, four to six weeks minimum, ongoing maintenance as provider APIs change, and a test suite that covers the edge cases every routing decision creates.

The platform ships that router already built, tested, and maintained. The engineer's time goes toward the service you are selling, not the infrastructure underneath it.

**Groq direct vs Groq through the platform**

If you have a Groq API key, you can call Groq directly. The advantage of routing through the platform is the fallback chain. A direct Groq call that fails is a failed call. A Groq call through the platform that fails falls back to the gateway default. For production workloads with clients watching, the fallback matters.

---

## Failure Modes

**Calling Opus on every task**

The most common way agencies burn through credits is defaulting to the highest-capability model for work that does not need it. Opus on triage is waste. Define the skill, bind the appropriate model, and run the eval to confirm the cheaper model performs adequately on that task before committing.

**Ignoring the output multiplier**

Input costs get the attention. Output costs compound quietly. A model priced at 1,500 credits per 1,000 input tokens charges 5× that rate for output. A task that generates long responses, a detailed proposal or a comprehensive analysis, costs significantly more per call than the input figure suggests. Run the arithmetic before setting the pricing for a client workspace.

**Not testing after a model swap**

The model field is easy to change. The consequences of changing it without testing are not. Different models handle ambiguous instructions differently. A swap that passes basic testing may fail on edge cases that appear in production. Run the eval gate before rolling changes to client workspaces.

---

## Frequently Asked Questions

**How do I add a new model that just shipped?**

If it is in the OpenRouter catalogue, it is available immediately. Change the model field in your agent definition to the new model's identifier. No package update, no platform change required.

**What is the model field format?**

It follows OpenRouter's naming convention: `{provider}/{model-id}`. For example: `anthropic/claude-haiku-4-5`, `openai/gpt-4o`, `google/gemini-2.5-flash`, `groq/llama-3-70b`. The platform validates the identifier against the catalogue at agent load time and surfaces an error if the model is unavailable.

**Can I set a daily cost cap per agent?**

Yes. The workspace settings include a daily credit cap per agent and per client workspace. When the cap is hit, the agent falls back to the lowest-cost model in the fallback chain or returns a graceful "I'll follow up" response depending on your configuration. Auto-topup is available if you want to remove the cap automatically when the workspace approaches the limit.

**What happens to my credit balance when a model's price changes?**

Credits are the unit of account. If a model's credit cost changes, future calls cost more or fewer credits. Your existing credit balance is unaffected. You do not retroactively pay more for credits you have already purchased.

**Can clients see which model is running their agent?**

By default, no. The model is an implementation detail you control. If you want to expose it (some enterprise clients in regulated sectors require model transparency) you can surface it through the agent's response metadata. The choice is yours.

**Do I need a separate account on each provider?**

No. The platform's credit pool abstracts the provider accounts. If you use BYOK for a specific provider, you need an account with that provider. For everything else, one platform account and one credit balance is sufficient.

---

## Glossary

**Gateway.** The AI SDK Gateway, a routing layer that translates your model request to the appropriate provider API. Handles authentication, format translation, and rate management. One key, 300+ models.

**BYOK.** Bring Your Own Key. Using your own provider API key instead of the platform's credit pool. Required for enterprise data agreements or existing volume commitments with specific providers.

**TTFT.** Time to First Token. The latency between submitting a request and receiving the first character of the response. The metric that determines whether an AI interaction feels live or laggy.

**Output multiplier.** The ratio of output token cost to input token cost for a given model. Typically 5× to 8× the input rate. Relevant for tasks that generate long responses.

**Model binding.** The assignment of a specific model to an agent or skill via the `model` field in the agent markdown definition. Overridable at the skill level.

**Alias.** A model identifier that resolves to the current version of a model family. For example, `haiku-latest` always resolves to the latest Haiku generation. Provides continuity across model versions without requiring manual updates.

**Fallback chain.** The ordered sequence of models the platform tries when the primary model is unavailable. Default → Groq → AI SDK Gateway → degraded mode.

**Credit.** The platform's unit of account. Fixed exchange rate to upstream model cost. The markup layer sits between your credit cost and your client billing.

---

## Cross-References

**Section 02, Agency.** The credit resale economics that this section's pricing math sits within. How credits flow from platform purchase to agency markup to client billing.

**Section 05, Agents.** How agent markdown definitions work, including the `model` field and skill bindings. The contract this section assumes.

**Section 15, Security.** Provider key handling, data residency, and the credential architecture behind BYOK.

---

## Named Integration: ToolLoopAgent and the Gateway Provider

The platform's agent runtime uses the AI SDK v6 `ToolLoopAgent` class. Each persona is one `ToolLoopAgent` instance. The model is set via the `gateway()` helper, which routes through the AI SDK Gateway to OpenRouter.

```typescript
import { ToolLoopAgent, gateway, stepCountIs } from 'ai'

const agent = new ToolLoopAgent({
  model: gateway('anthropic/claude-haiku-4-5'),  // change this one field
  instructions: persona.systemPrompt,
  tools: clawTools(env),
  stopWhen: stepCountIs(5),
})
```

Changing `'anthropic/claude-haiku-4-5'` to `'openai/gpt-5'` is the complete migration. The tool definitions, the instructions, the substrate wiring, all unchanged. The model is the only thing that moves.

---

> "The companies that win this decade won't be the ones with the smartest models. They'll be the ones with the shortest distance between a customer's question and a useful answer."
>
> — Anthony O'Connell, Founder of ONE

The shortest distance is not always the most powerful model. It is the right model, routed correctly, at a cost that lets you serve the client and keep the margin.

---

Pick a model. Swap it in one line.

<!-- rubric: fit=0.95 strongest=0.92 show=0.90 cut=0.90 craft=0.92 → 0.92 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=fn -->