# billing-plans.md — Premium pricing strategy

---

## The honest caveat

Pricing is a hypothesis until customers pay or don't. What follows is a structured argument for a price range, built from what ONE actually replaces and what comparable tools charge. The recommendation is to test higher than feels comfortable, and lower only when data says to.

---

## What ONE actually is

Two distinct products running on the same substrate. This matters for pricing because they have completely different buyers, different replacement values, and different ceilings.

### Surface 1 — AI agency platform

For agencies and business operators. ONE replaces their entire operational stack:

| Category | What ONE replaces | Comparable tool | Monthly cost |
|----------|-----------------|----------------|:------------:|
| Multi-channel agents (web, WhatsApp, Telegram, Discord) | Intercom / Drift | Intercom Scale | $499 |
| CRM (built-in from conversation data) | HubSpot | HubSpot Professional | $800 |
| Social media creation + posting (all accounts, AI-generated) | Hootsuite + copywriter | Hootsuite Advanced | $399 |
| 1,000+ integrations (Shopify, Gmail, Slack, Stripe, Salesforce…) | Zapier / Workato | Zapier Team | $103 |
| AI agents + skills + marketplace | Relevance AI / Lindy | Relevance AI Team | $349 |
| White-label resell platform | GoHighLevel / custom build | GoHighLevel Agency | $497 |
| Analytics + automated client reporting | Databox / Looker | Databox Professional | $169 |
| Memory + learning substrate (TypeDB) | Nothing comparable | — | — |
| **Total stack replaced** | | | **$2,816+/month** |

Before accounting for labor replaced: a social media manager ($3,000–$8,000/month), a junior CRM admin ($2,500/month), an integration developer ($150–$300/hour).

**At any price under $1,500/month, ONE is saving the agency buyer money on tools alone.**

---

### Surface 2 — Backend as a Service (BaaS)

For developers building SaaS products. ONE replaces the entire infrastructure layer they would otherwise buy and wire together:

| Usually bought separately | ONE equivalent | Comparable cost |
|--------------------------|----------------|:---------------:|
| Database + ORM (Supabase / PlanetScale) | TypeDB — six dimensions, typed schema | $25–$699/month |
| Auth + roles (Auth0 / Clerk) | Actors with scoped keys; revoking is a `warn` | $23–$240/month |
| Recommendation engine (build it yourself) | `select()` — pheromone routing, automatic | $10,000–$50,000 to build |
| Message queue (SQS / Upstash) | `signal()` — async, tagged, delivered | $5–$100/month |
| Webhooks (Svix / build it yourself) | `sub()` — any HTTPS URL becomes a receiver | $50–$500/month |
| Payments (Stripe) | `mark()` with `weight` + `currency` | 2.9% + $0.30/transaction |
| Analytics (Amplitude / Mixpanel) | `events` dimension — every signal is an event | $0–$1,500/month |
| A/B routing (Optimizely / LaunchDarkly) | `follow()` + `select()` with `exploration` | $50,000+/year |
| **Total stack replaced** | | **$10,000–$100,000+/year** |

The comparison that matters: a developer building a commerce platform, a marketplace, or an LMS on ONE gets a recommendation engine, payments, analytics, auth, and a self-improving routing layer as a consequence of using the substrate correctly — not as separate services to buy and maintain.

**Five SDK calls to a live, isolated tenant workspace.** That is the entire multi-tenancy story.

The BaaS buyer is different from the agency buyer in every way: they are developers, they self-serve, they measure in API calls and tenant counts, and their willingness-to-pay scales directly with their own product's growth. A BaaS customer who builds a successful SaaS on ONE will pay more as their tenants grow — without any sales call, any renewal conversation, or any upsell.

---

## The four delivery models

Two surfaces, four buyer types. The axis is both *what* you're building and *how much* of the work ONE does.

```
BaaS surface                     Agency surface
────────────────                 ─────────────────────────────────────
  Platform                 Done By You → Done With You → Done For You
(developer builds           Builder        Operator         Partner
  on the substrate)
```

| Model | Buyer | Their real problem | Willing to pay for |
|-------|-------|-------------------|-------------------|
| Platform | Developer building SaaS | I need a substrate to build my product on — DB, auth, payments, recommendations, all of it | Primitives, tenant scale, no lock-in |
| Builder | Developer / technical founder | I need the full AI stack — agents, tools, learning — I'll build the product myself | Capability, no limits |
| Operator | Agency owner / business operator | I know what I want, I need to get there this week | Speed, white-label, resell margin |
| Partner | Executive / enterprise buyer | I want the outcome, not the project | Accountability, managed delivery |

---

## Price point scenarios

Four scenarios modelled against the same customer mix. The features are the same throughout — only price changes.

### Scenario A — Underpriced ($149 / $499 / $2,500)

The first draft. Problem: $149 is *less* than Relevance AI charges for an AI agent platform alone ($349). $499 is *less* than Hootsuite charges for social media management alone ($399). These prices say you don't believe in the product.

**Revenue at 500 customers (300 Builder / 150 Operator / 50 Partner):**
(300 × $149) + (150 × $499) + (50 × $2,500) = **$244,550/month**

---

### Scenario B — Market-justified ($299 / $999 / $5,000)

Prices defensible in a single sentence against comparables.

- $299 Builder: below Zapier Team ($103) + Relevance AI Pro ($29) + any CRM ($50) = $182 for worse, disconnected tools
- $999 Operator: below Hootsuite Advanced ($399) + HubSpot Professional ($800) + Relevance AI Team ($349) alone = $1,548
- $5,000 Partner: below what a social media manager costs before they've touched a keyboard

**Revenue at same mix:**
(300 × $299) + (150 × $999) + (50 × $5,000) = **$489,350/month** — 2× Scenario A, same customers.

---

### Scenario C — Premium anchor ($499 / $1,499 / $10,000)

Prices that position ONE as a category of its own.

- $499 Builder: same as GoHighLevel Agency, but ONE includes TypeDB learning, MCP, multi-model, a skill marketplace, and passkey auth that GoHighLevel doesn't have
- $1,499 Operator: the buyer is comparing against hiring. A junior marketing hire costs $4,000/month. ONE at $1,499 replaces that hire and runs 24/7
- $10,000 Partner: Workato enterprise for integrations alone costs $7,000–$15,000/year. ONE at $10,000/month delivers integrations + agents + social + CRM + analytics + managed operations

**Revenue at same mix (assume 20% fewer customers at higher price):**
(240 × $499) + (120 × $1,499) + (40 × $10,000) = **$699,640/month** — still 43% more than Scenario B with fewer customers.

---

### Scenario D — Tiered with no ceiling (custom Operator + Partner pricing)

Remove published pricing from Operator and Partner. Builder is self-serve at $299. Everything above requires a conversation. In that conversation you price to the customer's specific stack and replacement value.

A legal firm replacing a $6,000/month social media team pays $4,500. An e-commerce agency replacing HubSpot + Shopify integrations + a junior ops hire pays $2,500. A global enterprise with 200 client deployments pays $25,000/month.

Custom pricing captures willingness-to-pay that flat rates leave on the table. Trade-off: kills self-serve growth above Builder.

---

## Recommendation

**Launch at Scenario B. Test Scenario C within 90 days.**

| Plan | Launch price | Test at 90 days | Notes |
|------|:-----------:|:---------------:|-------|
| Platform | $199 + $5/tenant | $299 + $7/tenant | BaaS — volume grows with customer's product |
| Builder | $299 | $499 | Developers who know what this replaces won't baulk |
| Operator | $999 | $1,499 | Drops < 20%? Raise permanently |
| Partner | from $5,000 | from $10,000 | Sold, not self-served |

The BaaS angle (Platform tier) opens a second revenue stream that scales on its own: every successful SaaS built on ONE pays more as their tenant base grows. That revenue compounds without any sales or marketing effort.

The biggest risk is not charging too much. It is charging too little and training the market to undervalue the product.

---

## The plans

### Platform — $199/month base + $5/tenant workspace/month · $1,990/year base

**"Build any SaaS on the substrate. Ship in a weekend."**

*Replaces: Supabase ($25) + Auth0 ($23) + message queue ($30) + webhooks ($50) + Amplitude ($0–$1,500) + a recommendation engine you'd spend 3 months building = $128–$1,628/month of separate services, before you've written a line of product code.*

This is the BaaS tier. The buyer is a developer building a product — a commerce platform, a marketplace, a learning management system, a project tool, anything — and they want the substrate to handle database, auth, routing, recommendations, payments, analytics, and learning so they can focus entirely on the product.

| What's included | Detail |
|----------------|--------|
| Base credits | 1,000,000/month (covers ~50 active tenants at typical volume) |
| Tenant workspaces | 10 included · $5/workspace/month above that |
| All 14 operations | signal · ask · mark · warn · fade · sub · follow · select · groups · actors · things · paths · events · learning |
| TypeDB substrate | Six dimensions — groups, actors, things, paths, events, learning — handles any domain |
| Auth | Actor-scoped keys, passkey + SE for human actors, no ACL table to maintain |
| Recommendation engine | `select()` with pheromone routing — improves automatically on your tenants' data |
| Payments | `mark()` with `weight` + `currency` — USDC and fiat, no separate Stripe integration required |
| Message queue | `signal()` — async, tagged, persistent |
| Webhooks | `sub()` — any HTTPS URL becomes a receiver |
| Analytics | `events` dimension — every signal is a queryable event |
| A/B routing | `follow()` + `select()` with configurable `exploration` parameter |
| SDK | `@oneie/sdk` MIT — Node, Bun, Cloudflare Workers. 14 methods. |
| CLI | `npx oneie` — all 14 verbs, JSON output, shell completion |
| MCP tools | `@oneie/mcp` — substrate tools in Claude, Cursor, any MCP client |
| REST API | 14 endpoints, Bearer auth, versioned, stable |
| API rate limit | 6,000 req/hour base |
| Support | Docs + community |

**The tenant economics:**

```
You build a SaaS on ONE.
You have 100 tenants paying you $29/month = $2,900/month revenue.
You pay ONE: $199 base + (90 extra tenants × $5) = $649/month.
Your infrastructure margin: $2,251/month — before any product differentiation.
```

At 1,000 tenants (the scale where this plan gets interesting): you pay ONE $5,149/month, earn $29,000/month from tenants, keep $23,851/month infrastructure margin. The recommendation engine, the learning loop, the payments layer, the auth — all included in $5.15/tenant/month.

**The pheromone multiplier:** every signal your tenants send deposits pheromone on their paths. A commerce platform built on ONE has a recommendation engine that gets better with every purchase, for every tenant, automatically — without a data science team or a weekly retraining job. This is not a feature you buy. It is a consequence of using the substrate correctly.

**Who uses this:** a developer who wants to build the next Shopify, Udemy, Upwork, or any multi-sided platform. They provision a workspace per tenant in five SDK calls, issue scoped API keys, and ship. The substrate handles the hard parts.

---

### Builder — $299/month · $2,990/year

**"The full substrate. You build the product."**

*Replaces: Zapier Team ($103) + any AI agent tool ($299) + CRM starter ($50) = $452/month for disconnected tools with no learning layer*

| What's included | Detail |
|----------------|--------|
| Credits | 2,000,000/month |
| Seats | 10 |
| Agents | 100 (markdown-defined, self-learning) |
| All AI models | Haiku → Opus, GPT-4.1, Gemini 2.5, DeepSeek R1 — swap in one line |
| All six verbs | signal · mark · warn · fade · follow · harden |
| Multi-channel | Web chat, WhatsApp, Telegram, Discord, email — one agent, all surfaces |
| 1,000+ integrations | Shopify, Gmail, Slack, HubSpot, Stripe, Salesforce, Notion, Linear… |
| Social media tools | Connect accounts, post via agents (tool access — you build the posting logic) |
| Memory | 6-layer TypeDB memory: episodic, associative, semantic, inferred, procedural, social |
| CRM | Built-in from conversation data — no HubSpot import needed |
| Skills marketplace | Publish and import reusable priced skills — earn passive revenue |
| MCP server | Expose substrate to Claude, Cursor, any MCP client |
| CLI | Full `oneie` CLI — pull, validate, publish, compile agents to Python / MCP / skill |
| API access | 6,000 req/hour |
| Custom domain | 1 |
| Brand removal | on |
| Webhooks | 10 |
| File storage | 50 GB |
| Voice | on (STT + TTS) |
| Security | Passkey + Secure Enclave + Touch ID — no passwords, nothing to breach |
| Support | Docs + community |

**Who buys this:** a developer or technical founder who wants to build an AI-powered product on a substrate that already has TypeDB, billing, auth, multi-channel, 1,000 integrations, and a learning loop. The alternative is 6–12 months of engineering time to build an inferior version.

---

### Operator — $999/month · $9,990/year

**"We help you build it, run it, and grow with it."**

*Replaces: Intercom ($499) + Hootsuite Advanced ($399) + HubSpot Professional ($800) + Relevance AI Team ($349) + GoHighLevel Agency ($497) = $2,544/month of inferior, fragmented tools with no shared substrate*

| What's included | Detail |
|----------------|--------|
| Credits | 10,000,000/month |
| Seats | 50 |
| Everything in Builder | yes |
| Social media poster | AI creates and posts content across all platforms, multiple client accounts — included |
| Pre-built agent teams | Marketing team · Sales team · Service team — ready to deploy, tune to your ICP |
| Client workspaces | Create and manage sub-workspaces for clients |
| White-label cascade | Your brand, your domain, your OAuth consent screen — clients never see ONE |
| Agency markup controls | Set your own per-client pricing; ONE takes the floor, you keep the spread |
| Plan templates | Create named plans, stamp them on clients in one click |
| Allocations manager | Per-client credit caps, team budget splits, auto-alerts |
| CRM per client | Each client workspace has its own TypeDB-backed CRM from day one |
| Automated reporting | Monthly client reports generated and delivered automatically — 90 seconds |
| Custom domains | 5 |
| Teams | unlimited |
| Webhooks | unlimited |
| File storage | 250 GB |
| Guided onboarding | 2 × 1hr setup calls included |
| Monthly strategy review | 1 × 30min call/month |
| Priority support | 24h response SLA |

**Who buys this:** an agency owner who currently has 10–200 clients and pays $2,500+/month across disconnected tools, plus staff time to run them. The pitch in one sentence: "Build an AI agency at 20% of the tool cost, with white-label delivery, and earn recurring markup on every credit your clients burn."

**The reseller math:** an Operator charging 10 clients $500/month earns $5,000/month in client revenue, pays $999 to ONE, keeps $4,001/month. At 50 clients charging $300/month each: $15,000 client revenue – $999 ONE cost = $14,001 net. At that point, the Operator is not evaluating ONE's price — they're growing their client base.

---

### Partner — from $5,000/month · custom annual contracts

**"We build it. We run it. You get the results."**

*Replaces: a social media manager ($3,000–$8,000/month) + HubSpot Enterprise ($5,000+/month) + Workato enterprise integrations ($7,000–$15,000/year) + a managed AI implementation agency ($50,000–$150,000 one-time). Starting at $5,000/month is a fraction of any of those.*

| What's included | Detail |
|----------------|--------|
| Credits | custom prepaid pool |
| Seats | unlimited |
| Everything in Operator | yes |
| Social media managed service | ONE creates content strategy, writes, schedules, posts across all accounts |
| Custom agent development | ONE scopes, builds, deploys agents against your workflows and data |
| Integration setup | Any of the 1,000+ tools wired and tested for your specific stack |
| Managed operations | ONE monitors, maintains, evolves live agents — you see dashboards, not tickets |
| Dedicated infrastructure | Isolated Cloudflare Workers + TypeDB instance — your data, your region |
| 99.9% uptime SLA | Contractual |
| SSO / SAML | on |
| Audit logs | 12-month retention, exportable |
| Data residency | EU / US / negotiated |
| Quarterly business review | Outcomes vs. targets, with attribution receipts |
| Dedicated account manager | Named contact, shared Slack channel |
| Custom contract | MSA, DPA, BAA on request |
| White-glove onboarding | Full implementation project, not a setup call |

**Pricing tiers within Partner:**
- Single deployment: from $5,000/month
- Multi-deployment (3–10 systems): $10,000–$20,000/month
- Enterprise-wide (entire organisation): from $25,000/month, custom annual

**Who buys this:** a C-suite executive who measures success in outcomes, not tools. A legal firm that wants an AI intake agent running before Q3. A retailer who wants their Shopify store + customer support + social media run by agents. The conversation is never about features — it is about what they're currently spending and what they're currently missing.

---

## Add-ons (any paid plan)

Near-100% margin line items. Surfaced at natural usage moments.

| Add-on | Price | What it replaces / unlocks |
|--------|-------|---------------------------|
| Extra 5M credits | $35/month | Heavy model usage |
| Extra 20M credits | $120/month | Agency-scale volume |
| Extra social accounts (10 pack) | $49/month | Buffer: $10/channel = $100 for 10 |
| Extra seat block (10 seats) | $49/month | Team growth |
| Extra custom domain | $9/month | Client domains |
| Extra 50 GB storage | $9/month | File-heavy deployments |
| SSO / SAML | $99/month | Enterprise without full Partner jump |
| Audit logs 12-month | $29/month | Compliance buyers |
| 99.9% SLA | $149/month | — |
| White-label pack (Builder) | $149/month | Full white-label without Operator |
| Dedicated onboarding session | $499 one-time | — |
| Social media strategy session | $299 one-time | Content strategy setup |

---

## The free plan question

**No permanent free tier.** For a product that replaces $2,800+/month of tools and a social media manager, a free plan sends one message: we're not confident it's worth paying for.

**What to do instead:**

| Option | Form | Purpose |
|--------|------|---------|
| 14-day trial | Full Builder access, no card, auto-freezes | Maximum conversion — 14 days of real use creates emotional cost of losing it |
| Developer sandbox | API + SDK only, no hosted product | Technical evaluation without free operational use |
| Agency pilot | One client workspace, 30 days, card required | Let agencies test the resell model with one real client before committing |

The 14-day trial should feel generous — 200K credits is enough to deploy a real agent, connect integrations, and see the learning loop work. At day 10, a personal outreach from ONE ("how's it going — what are you building?") converts at 40%+. At day 14, workspace freezes with a clear prompt: choose a plan or export your data. The emotional cost of a 14-day build is high. That converts.

---

## Revenue per customer: the lifetime arcs

**Arc A — Agency (Operator path)**

| Stage | Monthly | Notes |
|-------|:-------:|-------|
| Trial (14 days) | $0 | — |
| Builder (months 1–4) | $299 | Learning the substrate |
| Operator (month 5, starts reselling) | $999 | Has 3 clients under their brand |
| Operator + extra credits + seats | $1,150 | 15 clients, growing |
| Annual Operator renewal (month 12) | $9,990/yr | Locked in, 2 months free |
| Partner (month 24, enterprise client signs) | $5,000+ | ONE builds and runs their stack |
| **3-year total** | | **$70,000+** |

**Arc B — BaaS (Platform path)**

| Stage | Monthly | Notes |
|-------|:-------:|-------|
| Trial (14 days) | $0 | — |
| Platform (months 1–3) | $199 + $0 | Building their product, 10 tenants included |
| Platform (month 4, product launches) | $249 | 10 extra tenants = $50 overage |
| Platform (month 8, 100 tenants) | $649 | 90 extra tenants × $5 = $450 overage |
| Platform (month 14, 500 tenants) | $2,649 | 490 × $5 = $2,450 overage |
| Platform (month 24, 2,000 tenants) | $10,149 | 1,990 × $5 = $9,950 overage |
| **3-year total** | | **$120,000+** |

The BaaS arc is more valuable because the customer's success is directly wired to ONE's revenue. No churn risk from a product pivot — if they succeed, ONE succeeds. No upsell required — the bill grows automatically with their tenant base.

No outbound sales required for this arc. Every transition is triggered by the customer's own success.

---

## The social media feature: why it deserves its own section

Social media creation and posting is not just a feature in a feature list. It is a complete job replacement for many buyers.

A social media manager at an SMB costs $3,000–$8,000/month. Their job is:
- Create content ideas
- Write copy for each platform in the right format and tone
- Source or create visuals
- Schedule and post across all accounts
- Monitor and report

ONE with AI agents + 1,000+ integrations (including Instagram, LinkedIn, X, TikTok, Facebook, YouTube) + memory (knows the brand voice, past campaigns, what performed) does all of that. Not perfectly in month one. Measurably better by month six because the substrate learns what worked and what didn't on this client's actual audience.

**Pricing implication:** any buyer currently paying a social media manager $3,000/month will pay $999/month for ONE Operator without hesitation. The ROI calculation is:
- Save $2,000+/month on the manager
- Get better coverage (24/7, all platforms, consistent brand voice)
- Get improving performance (learning loop, not static templates)

The social media angle is the fastest path to Operator conversion for any buyer in marketing, retail, or professional services. Lead every sales conversation with it.

---

## The 1,000+ integrations: why it's the moat, not the headline

Customers don't switch platforms they're integrated with. Every Shopify order, Gmail thread, HubSpot contact, Linear ticket, Stripe transaction, and Slack message that flows through ONE agents becomes a reason not to leave.

The migration cost compounds with every integration. After 90 days of live agents connected to a client's Shopify + Gmail + Slack, the switching cost approaches infinity — not because of contracts, but because the substrate has learned the client's patterns and the agents are running in their actual systems.

**Pricing implication:** integrations justify higher prices at renewal, not at acquisition. Price for acquisition, justify with integrations over time.

---

## What to test first, in order

1. **Talk to 10 potential customers before setting a pricing page.** Ask: "What do you currently pay for social media, CRM, and integrations?" Their answer is your ceiling. Most will say $1,500–$4,000/month.
2. **Launch Builder at $299, Operator at $999.** These close in any conversation.
3. **At 30 paying customers**, A/B test Operator at $1,499 vs $999 for new signups. Run for 60 days.
4. **If $1,499 converts within 20% of $999**, raise permanently. Revenue uplift is immediate.
5. **Every Partner deal should be sold.** Quote $5,000 as the floor. Some will negotiate. The ones who negotiate hardest are highest churn risk — price them up, not down.
6. **Annual billing from day one.** Present it as "2 months free" not "17% discount." Saving months is emotionally salient; percentages aren't.

---

## What not to do

**Don't compete on price.** There will always be something cheaper. Buffer's AI features cost $5/channel/month. Zapier Starter is $20/month. The moment ONE is in a price comparison conversation, the wrong buyer is in the room. The right buyer is comparing against what they're currently *paying* ($2,800/month in tools + $3,000/month in staff) not what's cheapest on ProductHunt.

**Don't gate features that make customers successful.** Every gate should be on features that make ONE successful (brand removal, sub-workspace reselling), not features that make customers successful (models, agents, integrations, memory). Gating capability breeds resentment. Gate white-label, support levels, and services instead.

**Don't list 40 features per plan.** Premium buyers don't read feature tables. They read outcome statements. "Deploy a social media team that runs 24/7 and gets better every week" beats "AI content creation + scheduling + multi-platform posting + analytics + learning loop."

---

*Plans live in `billing.md`. Credit rates in `billing-config.ts`. Feature detail in `text/` (00-cover through 16-speed). Comparable pricing sourced May 2026 from Hootsuite, Intercom, HubSpot, Zapier, Workato, Relevance AI, GoHighLevel public pages.*
