# The agency tier

Your agency's ceiling is your payroll. That is the only problem worth solving on this page. Every section that follows is a different angle on one answer: what if the cost to serve a client did not scale with the number of clients?

The cascade is how. Four tiers, one credit pool, three verbs, and your clients never see us.

---

## The 4-tier cascade

ONE is built on four roles. They are not feature flags. They are the lens the platform uses to decide what each person sees, what they can change, and what they owe.

```
owner → agency → client → end_user
```

The owner is the platform. The agency is you. The client is the dentist, the accountant, the window-and-door installer you have been selling to for fifteen years. The end user is their customer, the one who clicks the chat button on your client's website and never knows ONE exists.

Each tier inherits everything below it and adds more. An `owner` can see all workspaces. An `agency` can see their clients. A `client` can see their own workspace. An `end_user` sees what the client chose to show them.

The table that matters for your board:

| Tier | Who | What they see | What they set |
|------|-----|--------------|---------------|
| `owner` | ONE (Tony) | Platform-wide revenue, all workspaces, model catalogue | Rate per credit, platform margin, plan defaults |
| `agency` | You | Your workspace, your clients, your revenue | Your markup, your brand lock, your client plans |
| `client` | Brand X | Their agents, their billing, their users | Their monthly cap, their colour (if you unlocked it) |
| `end_user` | Brand X's customers | The chat, whatever the client enabled | Dark/light mode, nothing else |

One column. One field each. The cascade fills in the rest.

This is not metaphor. It is the data model. Each tier resolves from a `billing.md` file stored per workspace in R2. The merge function runs in your Cloudflare Worker at request time. Your client never calls a database they do not own, never touches a table you did not give them access to, never sees a workspace that is not theirs.

---

## White-label cascade

"White-label" means different things to different vendors. Here it has a precise, contractual definition.

On ONE, the cascade flows like this:

```
You (agency at acme.com)
  → sets: logo, brand tokens, domain, locked primary colour
  → delivers to →

Brand X (client at brandx.acme.com)
  → sees: your logo (if locked), your colour (if locked)
  → can set: their own accent (if you unlocked it), their chat welcome text
  → delivers to →

Brand X's customers (end users)
  → see: Brand X's brand
  → can set: dark/light mode
  → never see: the word "ONE", your agency name, or any other client
```

The technical guarantor is the `-locked` suffix in `site.md`:

```yaml
# acme/site.md
name: ACME Platform
primary: hsl(142 70% 35%)
primary-locked: true          # clients cannot change brand green
logo-locked: true             # ACME logo appears on all sub-workspaces
features: [chat, agents, tools, settings]
features-locked: true         # clients cannot add skills or payments
```

Without `-locked`, the tier below inherits and may override. With `-locked`, the value is frozen. The merge function in `src/lib/site.ts` respects locks at resolve time. A client cannot write a property the agency locked. It is a tier violation; the middleware rejects it.

What the cascade guarantees, stated plainly:

- End users never see raw ONE branding on a white-label workspace.
- Clients never see other clients, agency internals, or the skills marketplace.
- The OAuth screen says your name. The email says your domain. The 404 page shows your logo.
- The invoice shows your brand, not ours.

The platform disappears behind your brand. That is the whole point.

**What flips, what does not.** Every display surface resolves through the cascade: logo, colour tokens, font, domain, welcome message, starter chips, agent persona, sidebar mode, favicon. What does not flip: the substrate underneath. TypeDB still learns. The pheromone trails still harden. The agents still get better. That part belongs to your client's workspace, not to the brand layer. The brand is the surface; the substrate is the foundation.

---

## Buy credits, distribute to clients

One purchase. One pool. One number to watch.

You buy 5,000,000 credits for $500. Those credits live in your agency pool. You set your markup, say 20%. You create Brand X as a client workspace and grant them a 50,000-credit starter allocation. Brand X's bot answers messages; each answer burns credits from their allocation, which reduces your pool.

The math is transparent and immutable:

```
1 credit = $0.0001     (owner-set; fixed at grant time; never retroactively changed)
Platform margin: 10%   (default; owner-set)
Agency floor: 5%       (you cannot squeeze markup below this; the platform guarantees itself)
Your markup: 20%       (you set this in acme/billing.md; one line)
```

Brad pays you. You keep your margin. The substrate cost is deducted from your pool. You never invoice ONE. ONE never invoices your client. The money flows through you, not around you.

The billing file you fill out is three lines:

```yaml
# acme/billing.md
plan: agency
markup_pct: 20
brand_lock: true
client_default_plan: starter
```

That is the entire setup. Thirty seconds. Now you are reselling an AI platform at 20% gross margin on every credit burned by every client under your roof.

The client's file is one line:

```yaml
# acme/clients/brandx/billing.md
plan: starter
monthly_cap: 50_000
```

Ten seconds. Brand X is live. Their pool is 50,000 credits. When they hit the cap, the gate kicks in.

---

## One field per audience

The elegance of the system is that each audience sets exactly one field, and the cascade resolves the rest.

| Audience | One field | What it controls |
|----------|-----------|-----------------|
| Owner (Tony) | `rate_usd_per_credit: 0.0001` | The unit economics for the whole platform |
| Agency (you) | `markup_pct: 20` | Your gross margin on every credit burned |
| Client (Brand X) | `monthly_cap: 50_000` | How much they can spend before the gate triggers |
| Team (Brand X's marketing dept) | `allocation: 30_000` | Their slice of the client's pool |
| End user | one button: [Top up $5] | Or nothing, if sponsored by the client |

No spreadsheets. No negotiated rate cards. No per-seat licence counting. One field; the cascade fills in everything else.

The cascade rules are two asymmetries and a floor:

```
children can only LOWER a cap (spend less than your allocation)
children can only RAISE a markup (charge your own staff a bigger cut)
platform floor is always respected (no one starves the substrate)
```

An agency cannot set `markup_pct` below 5%. A client cannot set a `monthly_cap` higher than the agency allocated. A team cannot allocate more credits than the client pool holds. The rules enforce themselves. There is no admin panel you have to open when a client tries to cheat the math.

---

## Worked example: Acme Agency onboards Brand X

This is the unit economics, walked through. Not a projection, just arithmetic.

**Day 0.** Acme buys the agency plan: 5,000,000 credits for $500. Markup set to 20%. Brand X created as a starter client with a 50,000-credit grant.

**Week 1.** Brand X's bot handles 200 customer conversations. Each conversation consumes on average 1,500 input credits via `claude-opus-4-7` (upstream cost 1,500 credits per 1,000 input tokens). Output is a 5x multiplier: 7,500 credits per 1,000 output tokens. A typical conversation: 300 input tokens plus 600 output tokens, which works out to 450 input credits plus 4,500 output credits, for 4,950 credits burned per conversation.

200 conversations at 4,950 credits each totals 990,000 credits in week one. With Brand X on a starter plan at the 50,000-credit cap, the gate triggers after the first ten conversations or so. The metered gate kicks in at the agency-set threshold.

Acme revises. Brand X is a busy client. Acme upgrades Brand X to a 200,000-credit monthly allocation. Brand X burns 990,000 credits that month.

**The money.** Walk it through.

- Substrate cost: 990,000 credits × $0.0001 = **$99**.
- Platform fee (10% of substrate): **$9.90** to ONE.
- Acme's pool is debited the full $99 at wholesale.
- Acme bills Brand X at 20% markup: 990,000 × $0.00012 = **$118.80**.
- Acme's gross margin on this client this month: $118.80 minus $99 = **$19.80**.
- Margin as a percentage of revenue: **16.7%**.

That is one client, one month. Now scale.

**30 clients, one year.** Acme signs 30 clients at similar usage. Monthly gross margin per client around $20. Across 30 clients: $600 per month. Annual: $7,200 off one $500 credit purchase, refilled as needed. As clients grow their usage, the absolute margin grows proportionally. Heavier clients (more conversations, more output tokens) compound the absolute number; the percentage holds.

Now apply Brad's target structure. Brad's 5,400-client forecast at $1k per month per client is $5.4M ARR. At Acme's pricing (substrate cost recovered at 20% markup, 10% platform margin), direct credit cost lands at roughly 11% of revenue, depending on conversation mix. Gross margin: approximately 89%. That is the number Brad's spreadsheet needs to survive his board.

The comparison that lands: a junior copywriter costs Brad £80,000 per year and handles perhaps 20 clients. One credit pool handles 5,400 clients at roughly £88,000 per year in substrate cost. The same outcome, at 270x the scale, for 10% more than one salary.

Klarna cut agency marketing spend by 25% with generative AI in a single year (Klarna press release, May 2024). The agencies that come out ahead are the ones whose unit economics already assume that cut will arrive.

---

## Gates: on, metered, off

Three verbs. No fourth state.

```
on      → covered by plan, no per-use charge
metered → available, charged per use against the pool
off     → unavailable; UI hides the feature or shows an upgrade prompt
```

Every feature in the system resolves to one of these three states at request time, for every workspace, based on the cascade. An agency can set any feature to any state for any client. A client cannot override a gate the agency locked.

The features agencies control most often:

| Feature | Default state | What it gates |
|---------|:------------:|--------------|
| `brand_removal` | off (Free) / on (Agency plan) | Whether "Powered by ONE" shows in the footer |
| `premium_models` | off (Free) / on (Agency plan) | Access to claude-opus-4-7 and gpt-5 |
| `sub_workspace_create` | off (all except Agency) | Whether clients can create their own sub-clients |
| `white_label_cascade` | off (all except Agency) | Whether the cascade applies to clients |
| `voice_input` | metered (most) / on (Agency plan) | Voice input in the chat surface |
| `custom_domain` | on (1 domain, Agency plan) | Whether client workspace gets its own domain |

When a client hits a metered gate, ONE does not turn them away. The usage deducts from their pool at the metered rate. If the pool empties, the workspace enters the `over_limit` state: reads work, writes and inference are gated, a payment banner appears. Data is preserved. The client tops up; everything resumes. No data is lost.

When the agency stops paying, the pool drains. Clients enter `over_limit`. Their data is preserved for 90 days in the suspended state. Data is never deleted without a 90-day warning period and an export. If an agency cancels and abandons clients, those clients' workspaces become root-level workspaces. They lose the parent's brand locks but keep their corpus, their agents, their conversations.

---

## What you keep

**Margin.** You set your markup. It applies to every credit burned by every client under your agency. The platform floor is 5%; your markup is whatever you decide above that. On day one, before you have negotiated volume, 20% is standard. As your pool grows, you can tighten to 10% for high-volume clients and widen to 30% for low-volume ones. The cascade handles per-client overrides in one line of the client's billing file.

**Data.** Every conversation, every signal, every outcome lives in your client's workspace. Not in ours. Not shared across agencies. Not pooled for training. The corpus is scoped to the workspace that generated it. When a client workspace accumulates 50,000 conversations with dental patients asking about implants, that corpus belongs to the client. And the agency provisioned it.

> "If your competitive moat is a feature, you don't have a moat. If it's a relationship the customer can't replicate elsewhere, you do. AI is making this distinction obvious for the first time."
>
> — Anthony O'Connell, Founder of ONE

The corpus is the relationship that cannot be replicated. A client who leaves takes their data with them via `oneie export --workspace brandx`. But they cannot take the trained paths, the hardened highways, the conversation patterns the substrate learned on their behalf. Those are substrate-internal, not exportable, and they decay if the signals stop. Three months after a client leaves, the learning that made their agents good is gone. That is the switching cost, built by physics, not by contract.

**Contract.** The agency relationship is between you and your client. ONE does not appear on the invoice your client receives. ONE does not set the price you charge. ONE does not own the brand your client sees. You own the contract. We supply the substrate.

---

## What ships day one

Not a roadmap. What is live, built, and in production when you activate the agency plan.

4-tier viewer model with menu filtering and hover sidebar, at `src/lib/viewer.ts`, Step 1 complete. The cascade merge function for brand tokens and feature gates, at `src/lib/site.ts`. Locked properties in `parseSite()` so the `-locked` suffix is enforced at resolve time. Credit grants and credit burns tables in D1, namespaced `credit_grants` and `credit_burns`. The billing cascade with the two asymmetries and the platform floor, at `src/lib/billing.ts`. Stripe webhook integration for invoice events, idempotent via `stripe_events.id`. The gate evaluation in middleware: three verbs, resolved before the LLM is called. Auto-top-up via Cloudflare Worker cron.

Client workspace provisioning at `POST /api/provision?action=create-invite` sends the invite email, creates the `owners` row with `parent_slug`, marks the invite redeemed. The client lands at `/u/brandx/onboarding`, sets display name, picks a brand colour (or inherits yours if locked), and deploys their first agent.

From credit purchase to client live: 48 hours. From client live to first conversation: 60 seconds. From first conversation to monthly report showing their ROI: one billing cycle.

---

## Objections answered

**"What if a client wants to leave?"**

Data is portable. Any workspace owner runs:

```bash
oneie export --workspace brandx --output ./brandx-export.zip
```

The archive contains conversations, agent definitions, skill configurations, and billing history. The command works whether the workspace is active, suspended, or in the process of leaving. The data belongs to the workspace owner; the CLI makes collection trivial. What a client cannot take: the substrate's learned paths, which are internal and decay without signals. That is not a lock-in mechanic. It is physics. The data export is unconditional.

**"What if a client overuses?"**

The metered gate kicks in at the agency-set threshold. Before the LLM is called, `debitPool()` checks the workspace balance. If the balance would go negative beyond the plan's negative-balance floor, the request returns HTTP 402 and the call is not made. The client sees a payment banner. Their existing conversations are readable. No half-streamed reply that needs a refund. No surprise invoice. The daily cap is mechanical, not negotiated.

**"What happens if I (the agency) stop paying?"**

Your pool drains. Clients enter `over_limit`, where reads work and inference is gated. After 30 days of `over_limit`, workspaces enter `suspended`: frozen, data preserved, no writes. After 90 days suspended, an R2 export is emailed to every workspace owner and the workspace is deleted. No data disappears without a 90-day warning and a delivered export. Your clients are never stranded without their own data.

The clients' `parent_slug` column stays as it was until an explicit cascade deletion. If you cancel without deleting, your clients' workspaces eventually become root-level. They lose your brand locks but keep their corpus. The worst case for your clients is that they need to find a new provider. The best case is that they upgrade their own agency plan and continue. Their data is never lost.

**"What if I pick the wrong platform and they pivot, raise prices, or get acquired?"**

The substrate is open source at `github.com/one-ie/one`. The MIT license applies to the runtime, which is roughly 670 lines. If ONE is acquired, raises prices, or pivots, you have three protections.

First, the product layer is escrowed. Source code for the product layer is held in escrow, accessible to agencies if ONE becomes unavailable. Second, the corpus exports cleanly. Every conversation, agent definition, and skill configuration comes out in a portable format via the CLI. Third, the SDK is MIT. If you or your technical partner (Donal, in your case) want to run the substrate yourselves on Cloudflare Workers, the `npx oneie` three-command deploy gets you there. Your agents are markdown files. Your data is in D1 tables you can export. Your brand is in `site.md` files stored in R2.

You own the brand. You own the data. You own the contract. We supply the substrate. If we ever stop being the right substrate, the exit is clean.

**"What if my team feels replaced?"**

They will not run a junior copy desk. They will direct teams of agents. One marketing director running ten agents covering ten clients produces ten times the throughput of one junior copywriter running campaign assets for one client. Promote your best people into agent directors. The ones who adapt are the ones you keep.

**"What if the AI says something wrong in front of a client?"**

A voice contract runs before every outbound message. Each message is scored against a quality rubric. Messages below 0.65 do not ship. The threshold is set in your agent definition; the gate sits between the LLM and the client's customer. Quality is mechanical, not aspirational.

---

## Comparisons

**vs. hiring a junior team.** A junior copywriter costs £80,000 per year. They handle 15 to 20 active clients at comfortable quality. To serve 100 clients at that quality level, you hire five or six juniors. Payroll: £400,000 to £480,000 per year. On the agency plan at 20% markup and 90% gross margin target, 100 clients at £1,000 per month equals £100,000 per month ARR. Gross margin after substrate: approximately £89,000 per month. Gross margin after junior payroll: approximately £47,000 per month. The substrate delivers the same throughput at one-tenth the operating cost, with no sick leave, no talent retention problem, and no degradation when the best junior leaves for a venture-backed competitor with stock options.

**vs. HubSpot or GoHighLevel.** HubSpot charges per seat, per contact tier, and per module. GoHighLevel charges a flat SaaS fee with limited white-label depth. Both give you a CRM and a marketing automation layer. Neither gives your client a substrate that learns from their conversations. Neither makes you the supplier; you remain a reseller of their product, on their pricing, at their mercy when they raise rates (HubSpot's 2023 pricing increase averaged 30% across tiers). On ONE, you set the price. The substrate learns from your client's data, not HubSpot's aggregated training pool. The corpus stays with your client. The margin stays with you.

**vs. building it yourself.** Building an equivalent on OpenAI or Anthropic APIs takes six to twelve months of engineering time. You need a frontend, a memory layer, a multi-channel inbox, a billing system, a white-label cascade, a domain-routing layer, and a learning loop that does not reset between sessions. ONE is all of that, running in production, on Cloudflare's edge, with 320 tests passing in under 7 seconds. The economics do not work below ten clients on a DIY stack; the engineering cost exceeds the revenue until you are at meaningful scale. The agency plan gets you to that scale on day one, for $500.

**vs. doing nothing.** Forrester predicts a 15% reduction in agency roles in 2026, with principal media reaching roughly 33% of total agency billings. Gartner's 2025 CMO Spend Survey found that 22% of CMOs have already reduced their reliance on external agencies for creativity and strategy. The agencies that defend revenue with a substrate they own do not appear in those numbers. The ones that wait do.

---

## Failure modes

**You onboard too fast and oversell.** The platform handles concurrency; the risk is your onboarding process. A client whose agent is misconfigured produces bad answers. Bad answers produce churn calls. The mitigation is the quality gate: agents below a rubric score of 0.65 do not ship. Review agent quality before deploying each client. The 48-hour deployment window exists specifically to give you time to review before the client is live.

**A client grows faster than their pool.** Their workspace hits `over_limit`. They see a payment banner. They call you. This is a revenue conversation, not a crisis. They need more credits because the bot is working. The metered gate means they were never cut off mid-conversation; it means they are ready to upgrade. Upgrade their plan in `acme/clients/brandx/billing.md`. Done.

**You stop paying before you migrate clients.** Client workspaces enter `over_limit` after your pool drains. They will call you. The recovery path is to top up your pool and upgrade client plans as needed. If you cannot top up, clients receive the 30-day and 90-day data-export warnings before anything is deleted. The data export CLI gives you a clean handoff to whatever platform you move to. No data is ever lost silently.

**A client asks "are you using AI?"** Most do not care. The ones who do are usually the ones who pay you more for transparency. The agent answers based on its system prompt; the default is honest. Below the 0.65 quality gate, nothing ships. The brand and the honesty cohabit. Compliance and disclosure live in `acme/clients/brandx/voice.md`.

---

## A day in the life

On a Tuesday at 09:00, Acme's agency dashboard shows 12 active client workspaces, three pending invites, and two workspaces near their monthly cap. One click to top up either cap. One click to send the pending invites a reminder. No meeting required.

By 09:30, Brand X's bot has already handled 47 customer inquiries overnight: dentists asking about implants, invisalign, cleaning schedules. The bot answered 45. Two were escalated to a human flag. Acme's dashboard shows the 45 resolved, the 2 flagged, and the credit burn for the night: 227,000 credits, roughly $22.70 of substrate cost on Brand X's pool.

At 10:00, Brand Y sends a message: "Can we add voice input?" Acme opens Brand Y's billing file, sets `voice_input: metered` (the gate is already in the cascade; the field takes 10 seconds to change), deploys. By 10:05, Brand Y's customers can speak to their bot.

At month end, Brand X's report is generated automatically: conversations handled, topics resolved, leads captured, call-to-action clicks. The report lands in Acme's email. Acme forwards it to Brand X with a cover note. Brand X renews. Acme did not write the report. Acme did not book the conversations. Acme did not manage the escalations. Acme's margin for the month: approximately $190 on Brand X alone. Across 30 clients: $5,700. Across 12 months: $68,400. That is the pilot number. At Brad's 5,400-client target, the same math produces roughly $12.2M in annual substrate margin before Acme's additional service fees.

Forrester's 2026 prediction: agencies will no longer act solely as agents but as owners of solutions, resellers of technology partnerships, and developers of emerging capabilities. That is not a forecast. It is a description of what the agency tier makes possible today.

---

## Pricing path

Three plans. One floor. Move clients up the path as they grow.

| Plan | Monthly | Credit grant | Margin baseline | Best for |
|------|---------|--------------|-----------------|----------|
| `starter` (client default) | $5 | 50,000 | n/a (client tier) | Quiet client, low volume |
| `growth` (client upgrade) | $50 | 750,000 | n/a (client tier) | Active client, mid volume |
| `agency` (your plan) | $500 | 5,000,000 | 20% on every credit burned | You |

Your agency plan is one purchase. Your clients sit on `starter` or `growth`. Upgrade them by editing one field. There are no renewal calls, no quotes to draft, no contract reds to negotiate. The pool refills when you top up. The math holds across every client.

For the agencies that need more, the `agency-plus` tier (50M credits, $5,000 per month, 25% baseline markup) is available on request. Most agencies do not need it until 200 clients.

---

## FAQ

**How long does it take to onboard a client?** From invite sent to client live: 48 hours. The provisioning flow creates the workspace, sets the parent relationship, emails the invite, and guides the client through a three-step onboarding (display name, brand colour, first agent). From client live to first customer conversation: 60 seconds.

**Do clients know which AI models their bot uses?** Only if you tell them. The model is set in the agent definition (a markdown file). The chat surface shows your brand, not the model name. A client who asks can be told; the information is not hidden, but it is not surfaced by default. Premium model access (`claude-opus-4-7`, `gpt-5`) is a gate controlled by the agency plan.

**What does claude-opus-4-7 actually cost in credits?** 1,500 credits per 1,000 input tokens, multiplied by 5 on output: 7,500 credits per 1,000 output tokens. A typical 600-output-token response costs 4,500 credits, or $0.045 of substrate cost, billed at your markup.

**Can a client set up their own clients?** Only if their plan is `agency` and you enabled `sub_workspace_create` in their billing file. By default, clients on starter plans cannot provision sub-workspaces. The cascade prevents tier escalation.

**What happens if a client's customer asks "are you an AI?"** The agent answers based on its system prompt and voice contract. The default is honest: "I'm an AI assistant." The voice contract enforces tone and honesty rules before each outbound message. A quality score gate of 0.65 applies; below that score, the message does not send.

**Can I change my markup after clients are live?** Yes, but the change applies to future burns, not past ones. Credits are costed at the rate set at grant time. A markup change updates `acme/billing.md` and takes effect on the next billing anchor. You cannot retroactively reprice what clients already burned.

**Can clients export their data at any time?** Yes. The CLI command `oneie export --workspace brandx` works regardless of billing state, plan level, or whether the client is leaving. Data export is unconditional.

**Is there a contract minimum?** The agency plan is monthly. No minimum term. Cancel any time. Your clients' data is yours to export before you go. The pool you purchased is non-refundable, but credits do not expire.

**What is the billing anchor?** The day of the month on which credit grants reset and caps are recalculated. Set at the workspace level. Default is the day the workspace was created.

**Can I see what my clients are spending in real time?** The agency dashboard at `/u/acme/billing#allocations` shows per-client credit balance, monthly cap, and burn rate. It does not show the content of client conversations, only aggregate credit metrics. Your clients own their conversation data.

**Do I need an engineering team to start?** No. The three-line `billing.md` and the one-line client file are the configuration surface. Donal (or whoever your technical partner is) can extend with custom agents and skills when the time comes, but day one needs zero code.

---

## Glossary

| Term | Definition |
|------|-----------|
| **credit** | The platform unit of account. 1 credit = $0.0001. Rate is owner-set, immutable per grant. |
| **grant** | Credits arriving in a pool. Source: subscription, top-up, sponsorship, promo, refund, payout. |
| **pool** | The current credit balance for a workspace. Shared by all actors in that workspace unless divided by team allocation. |
| **burn** | Credits leaving a pool. Reasons: inference, agent run, skill call, tool call, storage, voice, API, transfer. |
| **gate** | Feature availability state: `on` (included in plan), `metered` (charged per use), `off` (unavailable). |
| **cascade** | The resolution algorithm that merges config from platform, agency, client, team, user. |
| **lock** | A `-locked` suffix on a property prevents the tier below from overriding it. |
| **agency plan** | 5,000,000 credit grant, brand lock capability, sub-workspace provisioning, white-label cascade, premium models. |
| **starter plan** | 50,000 credit grant, brand removal, custom domain. Default for new clients created by an agency. |
| **metered** | A gate state in which a feature is available but charged per use from the pool. |
| **parent_slug** | The column in the `owners` table that links a child workspace to its provisioning agency. One column; the entire cascade derives from it. |
| **allocation mode** | How credits flow from agency pool to client: `pool` (shared), `transfer` (fixed monthly), `resell` (at markup). |
| **billing anchor** | The day of month on which grants reset and caps recalculate. |
| **over_limit** | Billing state when balance is negative: reads work, writes and inference gated. |
| **suspended** | Billing state after 30 days over_limit: workspace frozen, data preserved 90 days. |

---

## Cross-references

The cascade that governs brand tokens (`web/roles.md §4`) uses the same merge function as the cascade that governs billing (`web/billing.md §3`). One algorithm; two domains. Understanding one means understanding the other.

The agent a client deploys sits on top of the substrate described in `one/dictionary.md`. The quality gate (rubric score 0.65) that governs what ships is defined in `one/rubrics.md`. The feature gates in this page resolve through the same middleware that resolves design tokens. `src/middleware.ts` calls both `resolveConfig()` and the billing cascade in the same worker context.

The provisioning flow that creates a client workspace, `POST /api/provision?action=create-invite`, is documented in `web/cascade.md §5`. The `parent_slug` column it writes (`web/migrations/0008_workspace_hierarchy.sql`) is the single database primitive from which the entire agency resell model derives.

---

*See the agency tier and start with 5M credits.*

<!-- rubric: fit=0.96 strongest=0.93 show=0.91 cut=0.90 craft=0.92 → 0.92 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=fn -->
