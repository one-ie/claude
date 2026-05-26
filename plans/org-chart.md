# Org Chart — Modeling the Human GTM Org We Replace

For every recognizable human role in a marketing, sales, customer service, and community department, we show the **agent + skills + tools** that replace or augment it. Built on `plans/agent-spec.md`, our SDK compile targets, the ELEVATE playbook (`apps/playbook/`), and the canonical marketing frameworks (Hormozi, Schwartz, Brunson, Dunford, Weinberg, Cialdini).

The frame: **clients buy roles, not technology.** A business owner recognizes "Senior Copywriter, £75k, writes 4 ads a month." She doesn't recognize a signal bus. The doc speaks in titles, comp, and outputs.

**Naming convention used throughout:**
- **Agents** are *roles* — Head of Marketing, Sales Closer, Offer Architect
- **Skills** are *activities* — Copywriting, Cohort Analysis, Dream Outcome Mapping
- **Tools** are *services* — Web Crawler, Image Generator, Search

---

## 1. Ground truth

Three primitives per `agent-spec.md`. Any natural-language string in YAML is an LLM call at runtime. Skill selection is automatic — each skill's `description` is auto-injected as a routing line. Same role-file deploys three ways via `packages/sdk/src/compile.ts`: our cloud, Fetch.ai network, MCP. Every skill is priced (`price: 0.02` USD, multi-chain via x402) — the department *is* a marketplace. Quality is enforced by evals, run by `skill-creator` with three reviewer sub-agents (Analyzer, Comparator, QA Reviewer).

---

## 2. Two modes — and where humans still belong

| Mode | Who buys | Effect on the human team |
|---|---|---|
| **Replace** | Startups, scale-ups, high-turnover junior roles | Specific roles eliminated; senior layer keeps the relationship work |
| **Augment** | Established teams, regulated industries, relationship-led businesses | All humans stay; each becomes 10× through their agent |

Most clients buy a mix: **replace tactical/junior, augment senior/strategic**. The boundary moves up as models improve.

**Where humans still belong:** relationship sales above £500k · brand-defining creative leaps · crisis comms decisions · executive presence in board pitches · contracts, refunds above threshold, hire/fire · deep technical sales engineering · compassion in the worst service moments. The agent below them clears the runway so the human spends their hours on what only they can do.

---

## 3. The org we model

A typical mid-market GTM department, ~£5M-£50M revenue band, ~80 humans, ~£8.8M/year loaded.

```
                                  CEO (human)
                                       │
        ┌──────────┬─────────────┬─────┴─────────┬─────────────┬──────────────┐
   Head of     Head of      Head of         Head of      Head of
   Marketing   Sales        Customer        Community    Operations (RevOps)
                            Service
    27 FTE      19 FTE       22 FTE           7 FTE         4 FTE
    £2.7M       £2.7M        £1.94M           £660k         £700k
```

Plus eliminated external consulting: Hormozi-style offer coaches (£30-50k/offer), Dunford positioning workshops (£40-80k each), Brunson funnel consultants (£20-40k retainer), McKinsey-tier strategy retainers (£100-300k/yr). All baked into the agent team.

---

## 4. MARKETING — 27 humans → 1 director + 13 specialists + ~115 skills

ELEVATE steps owned: **0 Foundation** (shared) · **1 Stop** · **2 Gift** · **3 Identify** · **6 Nurture** (shared)

### 4.1 Human roles → what we provide

| Human role | Comp / yr | Replaces with | Mode |
|---|---:|---|---|
| **Chief Marketing Officer** | £250k | Head of Marketing + Marketing Strategist | Augment |
| **Head of Demand Generation** | £180k | Email & Lifecycle Marketer + Media Buying skill | Augment |
| **Head of Brand** | £150k | Brand Guardian + Brand Voice Auditing | Augment |
| **Head of Product Marketing** | £140k | Marketing Strategist + Positioning Mapping + Launch Planning | Augment |
| **Creative Director** | £150k | **Creative Strategist** + Hook Lab + Swipe File Curation + Big Idea Generation | Augment |
| **PR & Communications Lead** | £90k | **Press Officer** + Press Release Writing + Crisis Comms Drafting + Media Pitching | Augment |
| **Offer / Pricing Consultant** *(external)* | £30-80k/engagement | **Offer Architect** + Dream Outcome Mapping + Problem Listing + Solution Inversion + Bonus Stack Design + Guarantee Design + Scarcity Validation + Urgency Construction + Offer Naming + Price Anchoring | Replace per-engagement |
| **Positioning Consultant** *(external)* | £40-80k/engagement | **Positioning Architect** + Competitive Alternative Mapping + Unique Attribute Extraction + Best-For-Whom Definition + Sales Narrative Building | Replace per-engagement |
| **Funnel Strategist / Growth Hacker** | £100k | **Funnel Architect** + Value Ladder Design + Perfect Webinar Design + Squeeze Page Design | Replace |
| **Demand Generation Director** *(B2B)* | £150k | **Demand Creator** + POV Essay Writing + LinkedIn Thought Leadership + Podcast Tour Pitching + Dark Funnel Analysis | Augment |
| **Marketing Operations Manager** | £90k | **Tracking Engineer** + Pixel Installation + UTM Tagging + GTM Configuration + GA4 Configuration + Server-Side Tracking + Consent Mode Management + Conversion Event Mapping + Attribution Modeling | Replace |
| **Senior Copywriter** | £80k | Copywriting + Headline Writing + Brand Voice Auditing (framework-aware) | Augment (10× output) |
| **Senior Designer** | £80k | Visual Design + Web Design + Image Generator (tool) | Augment (20× variants) |
| **SEO Manager** | £75k | SEO Auditing + Schema Building + Keyword Research + Internal Linking | Replace |
| **Paid Media Manager** | £75k | **Media Buyer** + Meta Ads + Google Ads + TikTok Ads + LinkedIn Ads + Custom Audience Sync + Lookalike Audience Building + Ad Account Setup + Bid Strategy Selection + Budget Allocation + Audience Exclusion + Frequency Capping + Daily Campaign Optimization + Winner Scaling + Underperformer Killing + Creative Rotation + Creative Refreshing + Budget Rebalancing | Replace |
| **Email / Lifecycle Manager** | £70k | Email & Lifecycle Marketer + Email Sequencing | Replace |
| **Social Media Manager** | £60k | **Social Media Manager** (agent) + Carousel Design + Caption Writing + Content Repurposing + Social Calendar + Cross-Posting Management + Platform Adaptation + Hashtag Research + Story/Reel Scheduling | Replace |
| **Content Marketer** | £65k | Copywriting + YouTube Scriptwriting + Podcast Production + Blog Outlining | Augment |
| **Marketing Analyst** | £70k | Marketing Analyst + Cohort Analysis | Replace |
| **Influencer / Partnership Manager** | £80k | Partnership Research + Influencer Outreach + Co-Marketing Briefing | Replace |
| **Affiliate Program Manager** | £70k | Affiliate Onboarding + Affiliate Payouts + Fraud Screening *(shared)* | Replace |
| **ABM Strategist** *(B2B)* | £100k | ABM Strategist + Account Planning + Multi-Thread Mapping | Augment |
| **Webinar Producer** | £60k | Webinar Production + Registration Page Design + Webinar Follow-up Writing | Replace |
| **Conversion Rate Optimizer** | £80k | A/B Test Design + Landing Page Design + Form Optimization + Pricing Page Optimization | Replace |
| **Localization Manager** | £70k | Translation + Regional Adaptation | Replace |
| **Accessibility / Compliance Lead** | £75k | Accessibility Auditing + GDPR Auditing | Augment |
| **Junior Copywriter / Designer** (× 2) | £87k | Copywriting + Visual Design (high-volume mode) | Replace |

**Subtotal: ~£2.1M of £2.7M FTE eliminated**, plus per-engagement consulting (Offer, Positioning, Funnel) — typically £100-300k/yr.

### 4.2 What we deploy

**Specialist agents (13):** Head of Marketing · Marketing Strategist · Brand Guardian · Email & Lifecycle Marketer · Press Officer · **Creative Strategist** · **Offer Architect** · **Funnel Architect** · **Positioning Architect** · **Demand Creator** *(B2B)* · **Media Buyer** · **Tracking Engineer** · **Social Media Manager** · ABM Strategist *(B2B)* · Marketing Analyst *(shared)*

**Skills (~115):**

*Foundational copy + design:* Copywriting · Headline Writing · Brand Voice Auditing · Visual Design · Web Design · Storyboard Writing · UGC Script Writing · Thumbnail Generation

*SEO + paid:* SEO Auditing · Schema Building · Keyword Research · Internal Linking · Meta Ads · Google Ads · TikTok Ads · LinkedIn Ads

*Ad ops (Media Buyer):* Custom Audience Sync · Lookalike Audience Building · Ad Account Setup · Bid Strategy Selection · Budget Allocation · Audience Exclusion · Frequency Capping · Day-Parting · Geo-Targeting Optimization · Daily Campaign Optimization · Winner Scaling · Underperformer Killing · Creative Rotation Management · Creative Refreshing · Budget Rebalancing · Audience Building

*Tracking (Tracking Engineer):* Pixel Installation · UTM Tagging · GTM Configuration · GA4 Configuration · Server-Side Tracking Setup *(Meta CAPI, Google Enhanced)* · Conversion Event Mapping · Consent Mode Management · Attribution Modeling

*Lifecycle + email:* Email Sequencing · Send Time Optimization · Deliverability Checking · List Hygiene

*Social (Social Media Manager):* Social Calendar · Cross-Posting Management · Platform Adaptation · Hashtag Research · Story/Reel Scheduling · Carousel Design · Caption Writing · Content Repurposing · YouTube Scriptwriting · Podcast Production · Blog Outlining

*PR + partnerships:* Press Release Writing · Crisis Comms Drafting · Media Pitching · Partnership Research · Influencer Outreach · Co-Marketing Briefing · Affiliate Onboarding · Affiliate Payouts

*ABM + B2B:* Account Planning · Multi-Thread Mapping

*Webinar + CRO:* Webinar Production · Registration Page Design · Webinar Follow-up Writing · A/B Test Design · Landing Page Design · Thank You Page Design · Order Bump Design · Exit Intent Modal Design · Form Optimization · Page Speed Optimization · Pricing Page Optimization

*Campaign ops:* Campaign Briefing · KPI Setting · Funnel Analysis · Pacing Tracking · Attribution Reporting

*Localization + compliance:* Translation · Regional Adaptation · Accessibility Auditing · GDPR Auditing

*Offer construction (Hormozi):* Dream Outcome Mapping · Problem Listing · Solution Inversion · Bonus Stack Design · Guarantee Design · Scarcity Validation · Urgency Construction · Offer Naming · Price Anchoring

*Creative & big-idea:* Hook Lab · Swipe File Curation · Big Idea Generation · Brand Storytelling *(StoryBrand)*

*Funnel topology (Brunson):* Value Ladder Design · Perfect Webinar Design · Squeeze Page Design · Application Funnel Design

*Positioning (Dunford):* Competitive Alternative Mapping · Unique Attribute Extraction · Best-For-Whom Definition · Sales Narrative Building

*Demand creation (B2B):* POV Essay Writing · LinkedIn Thought Leadership · Podcast Tour Pitching · Dark Funnel Analysis · Channel Bullseye · Channel Experiment Design

*Cross-pod:* Cohort Analysis · Launch Planning · **MQL-to-SQL Translation** · **Lead Scoring Calibration** *(both live between Marketing and Sales)*

**Two skills no agency has:**
- **AI Visibility Tracking** 🔮 — brand citation rate across ChatGPT/Claude/Gemini/Perplexity. AEO/GEO.
- **AI-Agent Readiness Audit** 🤖 — can AI agents complete tasks on your site. The next 5 years of SEO.

---

## 5. SALES — 19 humans → 1 director + 5 specialists + 22 skills

ELEVATE steps owned: **4 Engage** · **5 Sell** · **6 Nurture** (shared)

### 5.1 Human roles → what we provide

| Human role | Comp / yr | Replaces with | Mode |
|---|---:|---|---|
| **Chief Revenue Officer** | £300k | Head of Sales | Augment |
| **VP Sales** | £180k | — (stays; manages 4× reports) | Augment |
| **VP RevOps** | £160k | Sales Forecasting + Pipeline Tracking + Pipeline Hygiene | Augment |
| **Sales Enablement Manager** | £100k | Battlecard Writing + Sales Coaching Notes + Onboarding Plan Writing | Augment |
| **Senior Account Executive** (× 3) | £600k | Discovery Caller + Demo Specialist + Proposal Writing + Sales Closer | Augment (4× pipeline) |
| **Junior Account Executive** (× 4) | £400k | Sales Closer (full close path) | Replace |
| **SDR / BDR** (× 6) | £360k | Prospect Research + Lead Scoring + Cold Email Writing + Meeting Booking | Replace |
| **Sales Engineer** (× 2) | £240k | Demo Specialist + RFP Writing | Augment |
| **Sales Operations Analyst** | £80k | Marketing Analyst + connectors | Replace |
| **Win-Loss Analyst** | £80k | Win-Loss Analysis + Voice-of-Customer Analysis | Replace |
| **Sales Call Coach** | £90k | Sales Call Coach | Replace (every call coached, not 1 in 20) |
| **Customer Reference Coordinator** | £65k | Reference Coordination + Customer Health Check *(shared)* | Replace |

**Subtotal: ~£1.35M of £2.7M eliminated**; remaining humans handle 3-4× pipeline.

### 5.2 What we deploy

**Specialist agents (6):** Head of Sales · Discovery Caller · Demo Specialist · Sales Closer · Live Sales Chat · Sales Call Coach

**Skills (22):** Prospect Research · Lead Scoring · Cold Email Writing · Meeting Booking · Call Note-Taking · Demo Planning · Proposal Writing · RFP Writing · Contract Drafting · Sales Forecasting · Pipeline Tracking · Pipeline Hygiene · Objection Handling · Quoting · Negotiation Briefing · Account Expansion · Battlecard Writing · Sales Coaching Notes · Onboarding Plan Writing · Win-Loss Analysis · Reference Coordination · Deal Health Scoring

### 5.3 The killer story

Human SDR team of 6 (£360k loaded): 14,400 emails/month, 3% reply, ~50 booked meetings. **£7.2k cost-per-meeting.**

Our **Prospect Research + Lead Scoring + Cold Email Writing + Meeting Booking** stack: 50,000 personalized emails/month, drafts queued for human review, 4-6% reply rate, ~400 booked meetings. **£0.5k cost-per-meeting.**

**14× CAC efficiency. 8× pipeline coverage.**

---

## 6. CUSTOMER SERVICE — 22 humans → 1 director + 8 specialists + 19 skills

ELEVATE steps owned: **7 Upsell** · **8 Educate**

### 6.1 Human roles → what we provide

| Human role | Comp / yr | Replaces with | Mode |
|---|---:|---|---|
| **VP Customer Success** | £180k | Head of Customer Service | Augment |
| **Customer Success Manager** (× 4) | £400k | Customer Success Manager + Customer Health Check + Renewals & Upsell Rep | Augment (4× book) |
| **PLG Strategist** *(SaaS)* | £140k | **PLG Strategist** + Activation Optimization + In-Product CTA Design + Free-to-Paid Trigger Design | Augment |
| **Onboarding Specialist** (× 2) | £150k | Onboarding Specialist + Customer Trainer | Replace |
| **Support Engineer T1** (× 6) | £300k | Helpdesk Dispatcher + First-Line Support + Support Agent | Replace (24/7, 70%+ deflection) |
| **Support Engineer T2** (× 3) | £225k | Log Investigation + human pair | Augment |
| **Support Engineer T3** (× 1) | £110k | — (stays; agent prepares dossier) | Augment |
| **Support Operations Manager** | £85k | Helpdesk Dispatcher + Marketing Analyst | Replace |
| **Trust & Safety Analyst** | £80k | Fraud Screening + ID Verification | Augment |
| **Renewals Specialist** (× 2) | £150k | Renewals & Upsell Rep + Win-Back Offer Writing | Replace |
| **Privacy Officer / DPO** | £100k | Privacy Officer + GDPR Request Handling + DPA Drafting + Security Questionnaire Response | Augment |

**Subtotal: ~£1.28M of £1.94M eliminated.**

### 6.2 What we deploy

**Specialist agents (9):** Head of Customer Service · Helpdesk Dispatcher · Support Agent · Onboarding Specialist · Customer Trainer · Customer Success Manager · Renewals & Upsell Rep · Privacy Officer · **PLG Strategist** *(SaaS)*

**Skills (19):** Ticket Classification · First-Line Support · Log Investigation · Customer Health Check · NPS Surveying · Churn Detection · Win-Back Offer Writing · Renewal Quoting · Upsell Briefing · Voice-of-Customer Analysis · Fraud Screening · ID Verification · Refund Review · GDPR Request Handling · DPA Drafting · Security Questionnaire Response · **Activation Optimization** · **In-Product CTA Design** · **Free-to-Paid Trigger Design**

---

## 7. COMMUNITY — 7 humans → 1 director + 4 specialists + 10 skills

ELEVATE step owned: **9 Share** (closes the spiral)

### 7.1 Human roles → what we provide

| Human role | Comp / yr | Replaces with | Mode |
|---|---:|---|---|
| **Head of Community** | £130k | Head of Community | Augment |
| **Community Manager** (× 2) | £140k | Community Moderator + Community Greeter + Expert Matching | Replace (24/7) |
| **Developer Advocate / DevRel** | £110k | — (stays; agent preps content + monitors) | Augment |
| **Events Coordinator** | £55k | Events Coordinator + Calendar tools | Replace |
| **UGC Curator** | £50k | Content Curation + Content Repurposing | Replace |
| **Brand Monitoring Analyst** | £55k | Sentiment Tracking + Crisis Detection | Replace |
| **Referral Program Manager** | £60k | Referral Manager + Referral Offer Writing + Rewards Calculation | Replace |

**Subtotal: ~£500k of £660k eliminated.**

### 7.2 What we deploy

**Specialist agents (5):** Head of Community · Community Moderator · Community Greeter · Events Coordinator · Referral Manager

**Skills (10):** Post Moderation · Welcome DM Writing · Contribution Ranking · Expert Matching · Event Page Building · Rewards Calculation · Referral Offer Writing · Content Repurposing *(shared)* · Sentiment Tracking · Crisis Detection

**Step 9 Share** — Referral Manager detects peak-NPS moment, picks the right share mechanism per persona, Content Curation ranks contributions, work loops back into Marketing's Step 1 Stop hooks and Step 5 Sell pages. **The Advocacy Loop closes here.**

---

## 8. FOUNDATION (Step 0) — replaces strategy days, ICP workshops, external consultants

**What humans do today:** two-day offsite once a year · customer avatar slide that ages · competitor matrix nobody updates · brand voice doc nobody reads · pricing from a £30k consulting engagement · positioning from a £60k Dunford workshop. Most companies skip this entirely.

### What we deploy

**Specialist agents (7):** Brand Strategist · Market Researcher · Customer Researcher · **Customer Interviewer** · Strategy Aligner · Brand Guardian · Pricing Strategist

**Skills (14):** Company Profiling · Market Watching · Customer Profiling · Competitor Tracking · Alignment Checking · Brand Voice Auditing · Positioning Mapping · Pricing Page Optimization · Persona Building · **Awareness Mapping** · **Sophistication Audit** · **Review Mining** · **Pain Indexing** · **Jobs-to-be-Done Interview**

### The Frameworks Library (Foundation artifact)

Canonical reference loaded into every specialist's system prompt. Every Marketing/Sales agent declares `reads: [frameworks-library, blueprint]` — the frameworks are the operating prior.

| Framework | Source | Where it applies |
|---|---|---|
| **Value Equation** — `(Dream × Likelihood) / (Time × Effort)` | Hormozi · $100M Offers | Offer Architect, Copywriting, Sales Closer |
| **Awareness Levels** — Unaware → Most Aware | Schwartz · Breakthrough Advertising | Copywriting, Visual Design, Email Sequencing (variant prompts per level) |
| **Sophistication Levels** — 1 to 5 | Schwartz | Hook Lab, Headline Writing |
| **Hook · Story · Offer** | Brunson | Creative Strategist, Copywriting |
| **Value Ladder** — magnet → tripwire → core → continuity → high-ticket | Brunson | Funnel Architect |
| **Perfect Webinar (Stack Slide)** | Brunson | Webinar Production |
| **StoryBrand 7-Element** | Donald Miller | Brand Storytelling, Copywriting |
| **Positioning Canvas** — alternatives → attributes → value → best-for-whom | April Dunford | Positioning Architect |
| **Bullseye (19 channels)** | Gabriel Weinberg · Traction | Channel Bullseye |
| **7 Principles of Influence** | Cialdini | Copywriting, Email Sequencing, Offer Architect |
| **Jobs To Be Done** | Christensen | Customer Interviewer, Customer Researcher |
| **1-Page Marketing Plan** — before / during / after | Allan Dib | Marketing Strategist |
| **AARRR Pirate Metrics** | Dave McClure | Marketing Analyst, PLG Strategist |
| **Three Ways to Grow** — more customers, higher ticket, more frequent | Jay Abraham | Marketing Strategist, CRO |
| **USP** | Reeves / Kennedy | Positioning Architect |

Stored at `one.ie/agents/foundation/frameworks-library.md`. Rarely changes — these are canon.

### Foundation output

**Strategic Blueprint + Frameworks Library** = the universal context every specialist grounds in. Refresh cadence: weekly micro-refresh from Voice-of-Customer signals; quarterly full pass triggered by the Insight Loop.

### Human roles displaced

| Role | Comp | Mode |
|---|---:|---|
| External strategy consultancy retainer | £100-300k/yr | Replace |
| External Dunford positioning workshop | £40-80k/engagement | Replace |
| External Hormozi-style offer coach | £30-50k/engagement | Replace |
| External Brunson funnel consultant | £20-40k retainer | Replace |
| Customer Research Specialist | £80k | Replace |
| Internal Head of Strategy | £140k | Augment |

---

## 9. REFINE (Step 10) — replaces RevOps + Analytics + QA

The learning layer.

### Already shipped as platform primitives

- **Memory writer** (`SubstrateClient.signal/mark/warn/fade/follow`) — outcomes become path weights in TypeDB. Every skill emits a memory write on completion.
- **Multi-target compiler** (`compileAgent`) — same role-file deploys to our cloud, Fetch.ai, MCP.
- **QA Reviewer + Analyzer + Comparator** sub-agents in `skill-creator` — rubric scoring, failure diagnosis, A/B variant comparison.

### Specialist agents to add (4)

| Agent | Replaces | What it does |
|---|---|---|
| **Marketing Analyst** *(in repo)* | Marketing / RevOps Analyst | Live cohort + attribution measurement |
| **Insights Lead** 🆕 | Senior strategist connecting dots across departments | Cross-domain pattern matcher |
| **Operations Dashboard** 🆕 | Chief of Staff / exec dashboard analyst | Real-time C-suite view, root-cause traces |
| **Compliance Officer** *(in repo)* | Legal / brand compliance reviewer | Hard veto for legal, brand, regulatory risk |

**Skills (5):** Cohort Analysis · Pattern Finding · Dashboard Building · Anomaly Detection · Compliance Review

### Human roles displaced

Marketing Analyst (£70k) · RevOps Analyst (£85k) · Marketing Ops Manager (£90k) · External BI consultancy (£80k/yr) — all replace. Data Engineer light (£100k) — augment.

**~£425k saved** with continuous measurement.

---

## 10. Architectural foundations

Twelve questions a sophisticated buyer asks. Each answered by what's already in the stack.

| Question | Answer |
|---|---|
| How does my CMO approve 50 drafts/day? | Web approval queue. Per-skill confidence scores: high auto-ships, medium queues for batch review, low queues with explanation. Slack/email digest with one-click approvals. Owner overrides any threshold. |
| Show me what the agents did this week. | Weekly digest: every action, who/what triggered it, cost, outcome, top wins/misses, items awaiting approval. Every signal is a TypeDB row. |
| What if a skill update degrades performance? | Skills are semver-versioned. Skill Creator runs evals before publish. If evals regress, publish blocked, prior version stays live. One-click rollback. |
| What stops inference costs spiralling? | Per-tenant monthly budget with soft cap (80% warning) and hard cap (pause non-essential skills). Per-skill ceiling on `accepts.max`. Pre-paid credit buckets. |
| How is Client A isolated from Client B? | The `group` field scopes the substrate. Every TypeDB query filters on `group`. Multi-tenancy enforced at the row, not the table. |
| EU data residency? | Per-tenant region pin. Cloudflare Workers + D1 + R2 + TypeDB Cloud all region-locked per group. |
| BYOK? | Each agent's `model:` field accepts `byok:<provider>:<key-ref>` and routes through the buyer's keys. |
| TypeDB pruning? | Every group has a `fade-rate` (default ~1%/week). Paths below threshold weight (default 0.05) GC'd. |
| Skill failure? | Auto-retry once with backoff. Sustained failure → human approval queue with error context. OpenRouter fallback chains cover provider outages. |
| Cross-skill state? | The `memory` platform tool is per-agent KV scoped to the customer thread. |
| Sync or async? | <5s synchronous. >5s returns a job handle; client polls or receives webhook. UI shows progress. |
| Who sees what? | Better Auth + group-scoped roles: owner / admin / operator / viewer. Per-pod scoping available. |

Every answer maps to a field, table, or function already in the codebase.

---

## 11. Marketing Frameworks Operating Layer

What separates top marketers from average ones isn't talent — it's that they apply **engineered frameworks** instead of guessing. Hormozi has the Grand Slam Offer. Schwartz has Awareness Levels. Brunson has Hook-Story-Offer. Dunford has the positioning canvas. Donal applies these in his head; most agencies apply them ad hoc; we apply them by default, every time, via callable workflows.

### The Hormozi Grand Slam Offer (worked example)

Most consultancies charge £30-50k to build one Grand Slam Offer. We make it a callable workflow run by the **Offer Architect** agent.

```
campaign:brief OR product:launch
    │
    ▼  Offer Architect runs in sequence (evals at each step):

      1. Dream Outcome Mapping     — what the customer truly wants (not the product)
      2. Problem Listing           — every obstacle blocking the dream
      3. Solution Inversion        — convert each problem into a deliverable
      4. Bonus Stack Design        — add bonuses with named, anchored value (£X-value, free)
      5. Guarantee Design          — propose risk reversal (unconditional / conditional / anti)
      6. Scarcity Validation       — real or fake? (Compliance Review auto-checks)
      7. Urgency Construction      — real deadline only; no fake countdowns
      8. Offer Naming              — "X-Result-In-Y-Time" formula; A/B tested
      9. Price Anchoring           — price at 10× perceived value; sell at value
    │
    ▼  Output: offer.md — single canonical source of truth
    │
    ▼  Downstream specialists read offer.md:
         Copywriting drafts hooks against it
         Visual Design designs the offer page
         Email & Lifecycle Marketer builds the sequence that sells it
         Sales Closer carries the offer through close
         Demo Specialist orients demos around it
```

| Dimension | Human consultant | Our Offer Architect |
|---|---|---|
| Time to first offer | 4-6 weeks | 30 minutes |
| Cost | £40,000 | £200 |
| Iteration cost | £10k per revision | £20 |
| Compliance check on claims | Manual | Auto via Compliance Review |
| Persisted | PDF in shared drive | TypeDB entity, queryable by every specialist |
| A/B test naming | "Pick the best one" | Run 10 names against 1,000 synthetic personas, pick winner |

### Schwartz Awareness in practice

Every copy task starts with an **Awareness Mapping** call returning one of: `unaware · problem-aware · solution-aware · product-aware · most-aware`. Copywriting has variant system prompts per level:

| Level | Audience state | Copy style |
|---|---|---|
| Unaware | Doesn't know they have the problem | Story-led, pattern-interrupt, no product mention |
| Problem-aware | Knows the problem, not the solution | Pain agitation + new solution category |
| Solution-aware | Knows solutions exist | Why ours not theirs — mechanism reveal |
| Product-aware | Knows our product | Offer-led, social proof, guarantees |
| Most-aware | Existing customers / hot leads | Price, urgency, scarcity, win-back |

**This is why generic AI copy underperforms — it doesn't know the level. Ours does, always.**

### Brunson Hook · Story · Offer

Every campaign brief decomposes into:
- **Hook** — Hook Lab generates 100 candidates, scored against the Awareness × Sophistication grid, top 5 ship
- **Story** — Brand Storytelling applies StoryBrand 7-element to position the customer as hero
- **Offer** — Offer Architect runs the Grand Slam workflow

These three artifacts feed Copywriting, Visual Design, Email & Lifecycle Marketer, Sales Closer. **No campaign exists without all three.**

### Dunford Positioning (when launching or repositioning)

**Positioning Architect** runs the canonical Dunford process:
1. **Competitive Alternative Mapping** — what customers consider instead (often "do nothing" or "Excel")
2. **Unique Attribute Extraction** — what we have that alternatives don't
3. **Best-For-Whom Definition** — narrow the ICP to the segment we genuinely beat alternatives for
4. **Sales Narrative Building** — the strategic narrative the whole company tells

Output feeds Foundation (`blueprint.md`) and is read by every Marketing and Sales agent.

### Bullseye Channels (for new traction)

**Channel Bullseye** evaluates all 19 Weinberg channels against the business stage + ICP + Offer. Returns inner-ring (test now), middle-ring (test soon), outer-ring (skip). **Channel Experiment Design** writes the 90-day test plan: hypothesis, MDE, budget, success criteria. Default: never spread across more than 3 inner-ring channels at once.

### Why frameworks × the rest of our stack is unfair

| | Human agency | Our team |
|---|---|---|
| Frameworks applied | One framework well, others ad hoc | Every framework, every time, via skill grounding |
| Memory of what worked | Tribal knowledge | Path weights queryable per persona/channel |
| Variants tested | 3-5/month | 50+/cohort |
| Personalization | One version for everyone | N=1, derived from substrate reads |
| Cost per variant | Senior copywriter time | Inference cost (~£0) |

**A human marketer applies one framework well. An agency applies five inconsistently. Our team applies every framework, every time, calibrated by memory, personalized to N=1, at zero marginal cost per variant.**

---

## 12. Running a Campaign End-to-End

A SaaS company launches a new feature. T-14 days to T+30 days. Every agent · skill · tool · connector that fires.

### Phase 1 — Brief (T-14d)
**Agents:** Head of Marketing → Marketing Strategist · Offer Architect · Customer Researcher
**Skills:** Campaign Briefing · the 9-step Hormozi workflow (Dream Outcome Mapping → Price Anchoring) · Audience Building · KPI Setting · Channel Bullseye · Awareness Mapping · Sophistication Audit
**Output:** `offer.md` + `brief.md` + `audience.md` committed to substrate

### Phase 2 — Creative (T-10d)
**Agents:** Creative Strategist · Brand Guardian
**Skills:** Hook Lab (100 candidates → top 5) · Copywriting · Headline Writing · Brand Storytelling · Visual Design · Storyboard Writing · UGC Script Writing · Thumbnail Generation · Carousel Design · Caption Writing
**Tools:** Image Generator · **Video Generator** *(new — Replicate/Runway/Pika)* · **Voiceover/TTS** *(new — ElevenLabs)*
**Output:** ~150 ad creative variants across platforms, persona-tagged

### Phase 3 — Funnel (T-7d)
**Agents:** Funnel Architect
**Skills:** Landing Page Design · Thank You Page Design · Order Bump Design · Exit Intent Modal Design · Form Optimization · Page Speed Optimization · Pricing Page Optimization · Accessibility Auditing · GDPR Auditing
**Tools:** Web Crawler · **Form Builder** *(new — Typeform/Tally style)*
**Output:** `/launch`, `/thank-you`, `/order-bump` pages live on staging

### Phase 4 — Tracking (T-5d)
**Agent:** **Tracking Engineer** (new)
**Skills:** Pixel Installation · UTM Tagging · GTM Configuration · GA4 Configuration · Server-Side Tracking Setup *(Meta CAPI, Google Enhanced Conversions)* · Conversion Event Mapping · Consent Mode Management · Attribution Modeling
**Connectors:** Google Tag Manager · Meta CAPI · Google Enhanced Conversions · GA4 · **Mixpanel** *(new)* · **PostHog** *(new)* · **Segment** *(new — CDP)* · **RudderStack** *(new — CDP)*
**Output:** every conversion event mapped, deduped server- + client-side, consent-aware. iOS 14+ attribution recovered.

### Phase 5 — Pre-launch QA (T-3d)
**Agents:** QA Reviewer *(in skill-creator)* · Compliance Officer
**Skills:** Customer Twin *(synthetic personas react to landing pages + ads)* · Brand Voice Auditing · Compliance Review · Accessibility Auditing · A/B Test Design
**Output:** ship/no-ship decision with eval scores; variants split for live A/B

### Phase 6 — Launch (T-0)
**Agents:** **Media Buyer** (new) · Email & Lifecycle Marketer · **Social Media Manager** (new) · Press Officer
**Skills:**
- *Media Buyer:* Custom Audience Sync · Lookalike Audience Building · Ad Account Setup · Bid Strategy Selection · Budget Allocation · Audience Exclusion · Frequency Capping · Day-Parting · Geo-Targeting Optimization · platform-specific Meta/Google/TikTok/LinkedIn Ads
- *Email & Lifecycle Marketer:* Email Sequencing · Send Time Optimization · Deliverability Checking · List Hygiene
- *Social Media Manager:* Social Calendar · Cross-Posting Management · Platform Adaptation · Hashtag Research · Story/Reel Scheduling
- *Press Officer:* Press Release Writing · Media Pitching
**Tools:** **URL Shortener** *(new — branded short links + click tracking)* · **Calendar API** *(new)* · Email Sender · **SMS Sender** *(new — Twilio)*
**Connectors:** Meta Ads · Google Ads · TikTok Ads · **LinkedIn Ads** *(new)* · **Reddit Ads** *(new)* · **YouTube Ads** *(new)* · **Microsoft Ads** *(new)* · **Twitter/X Ads** *(new)* · **Pinterest Ads** *(new)* · Klaviyo · **SendGrid** *(new)* · **Postmark** *(new)* · **Slack** *(new — internal alerts)*

### Phase 7 — Daily Ops (T+1 … T+30)
**Agent:** Media Buyer runs daily; Tracking Engineer monitors data integrity
**Skills:** Daily Campaign Optimization · Winner Scaling · Underperformer Killing · Creative Rotation Management · Creative Refreshing · Budget Rebalancing · Anomaly Detection
**Behavior:** every campaign rebalanced daily. CPA tracked per ad. Fatigued ads auto-paused (frequency cap breach OR CTR decay >30%). Budget shifted to winners up to 2× current — beyond 2× requires human approval.

### Phase 8 — Weekly Reporting
**Agents:** Marketing Analyst · Operations Dashboard · Insights Lead
**Skills:** Funnel Analysis · Pacing Tracking · Attribution Reporting · Cohort Analysis · Anomaly Detection
**Tools:** Memory *(queries TypeDB path weights)*
**Output:** weekly digest to CMO — what's working, what's not, root-cause traces through the path graph

### Phase 9 — Postmortem (T+30)
**Skills:** Win-Loss Analysis · Voice-of-Customer Analysis · Pattern Finding · Cohort Analysis · Memory writes path weights — `audience × hook × channel × creative → outcome`
**Output:** `customer-profile.md` and `frameworks-library.md` updated; Insights Lead surfaces patterns for the next campaign brief. **The 2nd campaign starts from the 1st's verified outcomes.**

### Tools introduced by this workflow (additions to platform)

Video Generator · Voiceover/TTS · URL Shortener · Calendar API · Form Builder · SMS Sender · **Webhook Listener** · **Cron Scheduler** · **Heatmap / Session Recording** · **A/B Test Engine** *(server-side)* · **Chat Widget Embed** · **File Storage** *(R2)*

### Connectors introduced by this workflow

**Ad platforms (8 new):** LinkedIn Ads · Reddit Ads · YouTube Ads · Microsoft Ads · Twitter/X Ads · Pinterest Ads · Snapchat Ads · Quora Ads
**Tag + tracking (3 new):** Google Tag Manager · Meta CAPI · Google Enhanced Conversions
**Product analytics (4 new):** Mixpanel · Amplitude · PostHog · Heap
**CDP (2 new):** Segment · RudderStack
**Email infra (4 new):** SendGrid · Postmark · Iterable · Customer.io
**Comms (6 new):** Slack · Discord · Microsoft Teams · Loom · Zoom · WhatsApp Business
**Bookings (3 new):** Cal · Calendly · SavvyCal

### The "ships in 2 minutes" view

A new client launches their first campaign on Day 1:

1. **Spin up** — Marketing pod + Tracking Engineer + Media Buyer + Social Media Manager provisioned in one command
2. **Load context** — paste/crawl/connect their CRM (Phase 0)
3. **Run Phase 1-9** — Head of Marketing orchestrates the full sequence. Human approval gates fire at: ad budget >£X/day · final creative pre-launch · contract-equivalent commitments
4. **Output** — campaign live, daily optimization running, weekly reports flowing, Memory writing back

Total elapsed clock time from "spin up" to "first ad live" with all tracking + audiences + creative: **<48 hours.** Human GTM teams take 4-6 weeks for the same scope.

---

## 12b. Agent Handoff Sequence — How Work Flows

The campaign lifecycle is a relay, not a broadcast. Each agent reads from shared artifacts in the substrate (`offer.md`, `brief.md`, `audience.md`, `blueprint.md`) and writes outcomes back as path weights. No telephone game — every agent reads the same source of truth the previous agent wrote.

```
ATTRACT ──────────────────────────────────────────────────────────────────────►
                                                                               │
Stage 0 — Foundation (runs once, refreshes weekly)                            │
  Brand Strategist → Customer Researcher → Customer Interviewer                │
  → Positioning Architect → Offer Architect                                    │
  Writes: blueprint.md + frameworks-library.md (shared prior for all agents)  │
                                                                               │
Stage 1 — Brief (T-14d)                                                        │
  Head of Marketing → Marketing Strategist → Offer Architect                  │
  Channel Bullseye + KPI Setting + Awareness Mapping + Sophistication Audit    │
  + 9-step Hormozi workflow (Dream Outcome → Price Anchoring)                  │
  Writes: offer.md · brief.md · audience.md                                   │
                                                                               │
Stage 2 — Creative (T-10d)                                                     │
  Marketing Strategist brief → Creative Strategist → Brand Guardian            │
  Hook Lab (100 → top 5) + Copywriting (variant per awareness level)           │
  + Visual Design (~150 ad variants) + StoryBrand arc                         │
  Gate: Brand Guardian pass required before Stage 3                            │
                                                                               │
Stage 3 — Funnel (T-7d)                                                        │
  Creative outputs → Funnel Architect                                          │
  /launch → /thank-you → /order-bump (Brunson Value Ladder — no dead ends)    │
  + Page Speed + Accessibility Auditing → staging sign-off                    │
                                                                               │
Stage 4 — Tracking (T-5d)                                                      │
  Funnel on staging → Tracking Engineer                                        │
  Pixels + UTMs + GTM + GA4 + Meta CAPI + Google Enhanced Conversions          │
  Server-side + client-side deduped. iOS 14+ attribution recovered.            │
  Prerequisite for Media Buyer: no tracking = no optimizable campaign          │
                                                                               │
Stage 5 — Pre-launch QA (T-3d)                                                 │
  All artifacts → QA Reviewer + Compliance Officer                             │
  Customer Twin dry-run (synthetic personas react to funnel + ads)             │
  Compliance Officer hard-veto on legal/brand/regulatory risk                  │
  Gate: ship/no-ship eval score. Nothing goes live without pass.               │
                                                                               ▼
CONVERT ──────────────────────────────────────────────────────────────────────►
                                                                               │
Stage 6 — Launch (T-0) — four agents fire in parallel                         │
  Media Buyer        → audiences synced, bids set, budget allocated            │
  Email & Lifecycle  → sequence launched, deliverability-checked               │
  Social Media Mgr   → posts/stories/reels scheduled, platform-adapted        │
  Press Officer      → press release + media pitches fired                    │
  All four read from the same brief.md and offer.md                           │
                                                                               │
Stage 7 — Daily Ops (T+1 … T+30)                                              │
  Media Buyer runs autonomously every day                                      │
  CPA tracked per ad · fatigued creative auto-paused (frequency cap OR         │
  CTR decay >30%) · budget shifted to winners up to 2× (>2× = human gate)    │
  Creative Refreshing queues new variants from original creative pool          │
                                                                               │
Stage 8 — Qualify & Close                                                      │
  MQL-to-SQL Translation + Lead Scoring → Head of Sales                       │
  Discovery Caller → Demo Specialist → Sales Closer                            │
  Sales Call Coach reviews every call (not 1 in 20)                           │
  Live Sales Chat handles inbound async                                        │
                                                                               ▼
GROW ─────────────────────────────────────────────────────────────────────────►
                                                                               │
Stage 9 — Onboard & Expand                                                     │
  Closed deal → Onboarding Specialist → Customer Trainer                       │
  Customer Success Manager monitors health scores + churn signals              │
  PLG Strategist runs Activation Optimization + Free-to-Paid triggers (SaaS)  │
  Renewals & Upsell Rep fires on health signal, not calendar                  │
                                                                               │
Stage 10 — Advocate (closes the spiral)                                        │
  NPS peak signal → Referral Manager triggers referral offer                  │
  Community Greeter onboards new members                                       │
  Content Curation ranks UGC contributions                                     │
  UGC + social proof feeds back into Stage 2 Hook Lab and Copywriting          │
  ◄── The 2nd campaign brief starts from the 1st campaign's verified outcomes  │
                                                                               │
Stage 11 — Refine (continuous, weekly)                                         │
  Every signal from every stage writes path weights to TypeDB                  │
  Marketing Analyst + Insights Lead + Operations Dashboard                     │
  Cross-domain pattern matching: "3 sales objections this week match a         │
  community complaint last month" surfaces in weekly CMO digest                │
  Pattern Finding updates customer-profile.md + frameworks-library.md         │
  Next campaign brief inherits all verified outcomes                           │
```

### Why this handoff model doesn't break down

Three properties that keep the relay clean at scale:

| Property | Mechanism |
|---|---|
| **No telephone game** | Every agent reads the same `offer.md` / `brief.md` — Creative Strategist and Sales Closer work from identical truth |
| **Gates are structural** | Brand Guardian pass/fail is a signal write. Compliance Officer veto is a hard stop. Not advisory. |
| **Memory compounds** | Every outcome writes back as path weights. The 1000th campaign uses the 999th's verified outcomes as its starting prior. |

The agents don't coordinate by messaging each other. They coordinate by reading and writing to shared truth in the substrate. Drift is architecturally impossible.

---

## 12c. ELEVATE Playbook × Lifecycle-ONE × Substrate — One System

The ELEVATE framework (`apps/playbook/`) is the human-readable campaign strategy. `lifecycle-one.md` is the substrate's view of the same journey. They are the same shape at different zoom levels — the playbook describes what a business *does*; the lifecycle describes what the substrate *records* when they do it. Every agent in this org is built on `agent-template.md`, quality-gated through `skill-creator`, and deployed against a specific lifecycle stage it owns.

### The mapping

| ELEVATE Step | `lifecycle-one` Stage | What the substrate writes |
|---|---|---|
| **00 FOUNDATION** | 0–3 Wallet → Personal Group | `actor` + personal group + `chairman` role + `blueprint.md` as shared prior |
| **01 HOOK** | 4–5 Create → Deploy | agent specs → `unit` + `capability` relations; reverse tag edges for discovery |
| **02 GIFT** | 5–6 Deploy → Discover | capabilities with prices declared; landing pages live on staging |
| **03 IDENTIFY** | 6–7 Discover → Message | first signal; `visitor_hash` rung 0→1; `/go/:id` tracked redirect climbs to rung 2 (email_hash) |
| **04 ENGAGE** | 7–8 Message → Converse | sustained signals; chip-click → `pheromone-mark`; `path.strength` accumulates |
| **05 SELL** | 8–9 Converse → Sell | `POST /api/pay` → Sui escrow; `purchase` event writes `amount × 10` weight |
| **06 NURTURE** | 8+ (loop) | warm-path round-trips; email open/click events reinforce edges |
| **07 UPSELL** | 9–10 Sell → Buy | outbound payment; buyer→seller highway forms; revenue path hardens |
| **08 UNDERSTAND** | 10–11 Buy → Advocate | health signals; NPS event fires; hypothesis confirmation begins |
| **09 SHARE** | 11–13 Advocate → Invite | `sdk.invite()` → referral signal; inviter earns 0.1× on invitee's early paths |
| **10 REFINE** | continuous | L6 KNOWLEDGE loop promotes highways to hypotheses; `frameworks-library.md` updated |

### How each layer integrates

**Foundation → Personal group (stages 0–3)**
Foundation agents (Brand Strategist, Customer Researcher, Positioning Architect) live inside the personal group from the moment it is created. The group is `visibility: private` by default — the sovereign enclosure. `blueprint.md` and `frameworks-library.md` produced here are the context every downstream agent reads via `reads: [frameworks-library, blueprint]` in its frontmatter. No downstream agent writes its own ICP or positioning — it reads the Foundation's output.

**Tracking enters at IDENTIFY (stage 6–7)**
The first visitor who hits the landing page becomes rung 0 (cookie_id) → rung 1 (visitor_hash). The `/go/:id` tracked redirect used in every email send climbs the identity ladder to rung 2 (email_hash). A form submit fires `identify` → `same-as` relation links anonymous browsing to the known email. The campaign's first signal and the substrate's identity resolution are the same moment.

**Every chip click is a signal**
The `journey.continuations` in each agent's frontmatter (the chip chain from `agent-template.md`) are the substrate's `follow` paths. A chip click writes a `pheromone-mark` event to the tracking pipeline. `path.strength` on the `engage → sell` edge accumulates in real time from UI interactions, not from scheduled jobs.

**Payment is a pheromone event**
Sales Closer's `agent.md` declares `accepts: [{scheme: exact, network: eip155:8453, asset: USDC}]`. When a deal closes, `POST /api/pay` triggers Sui escrow settlement, the `purchase` event writes to `agent_events_warm` with `amount × 10` weight, and `mark()` deposits that weight onto the buyer→seller path. Revenue and routing share the same substrate write.

**SHARE closes the flywheel (stages 11–13)**
Referral Manager subscribes to `nps.submitted` via `sdk.subscribe({ tags: ['nps:high'], scope: 'private' })`. On NPS fire, `sdk.invite()` derives the new actor's wallet deterministically, seeds the referral path, and the inviter earns 0.1× strength credit on the new actor's early paths. The playbook's advocacy step is the substrate's advocate stage — both are the same `know()` call that promotes the highway to a permanent hypothesis and starts Layer-2 referral earnings.

### Skill Creator's role in the lifecycle

Every skill listed in every agent's frontmatter is built and quality-gated through the Skill Creator eval loop. The connection to lifecycle is structural:

- **Description optimization** ensures each skill triggers at the right lifecycle stage. `awareness-mapping` must trigger at Brief (stage 4–5), not at Close (stage 8–9). The 20 trigger eval queries include near-misses between adjacent lifecycle stages — that is the hard test.
- **Rubric scoring feeds path weights** — when a skill call completes with a rubric score, the weight deposit is `rubric_avg × 5` rather than `1`. High-performing skills on critical lifecycle paths earn disproportionate pheromone. Over time the substrate routes to better-performing skills automatically. The skill quality loop and the lifecycle learning loop are the same loop.
- **Eval prompts are lifecycle-grounded** — test prompts are drawn from real campaign moments: "We're at the Brief stage. Run awareness mapping." That is a Stage 4 prompt. The Skill Creator tests with and without the skill against it. A skill that passes at Stage 4 but would also trigger at Stage 8 fails the description optimizer.

### The full integration in one view

```
PLAYBOOK        LIFECYCLE-ONE    AGENT-TEMPLATE           SKILL-CREATOR        TRACKING + ANALYTICS
────────        ─────────────    ──────────────           ─────────────        ────────────────────
FOUNDATION  ──► stage 0-3    ──► blueprint.md             — (pre-loaded)   ──► rung 0 (cookie set)
HOOK        ──► stage 4-5    ──► journey.stages[0]        hook-lab evals   ──► stage-start event
GIFT        ──► stage 5-6    ──► capability declared      —                ──► pageview + scroll
IDENTIFY    ──► stage 6-7    ──► /go/:id in every send    —                ──► rung 1→2 (email_hash)
ENGAGE      ──► stage 7-8    ──► journey.continuations    —                ──► chip-click pheromone
SELL        ──► stage 8-9    ──► accepts[] in frontmatter sales-close eval ──► purchase × 10 weight
NURTURE     ──► stage 8 loop ──► email.stages             deliverability   ──► open/click events
UPSELL      ──► stage 9-10   ──► upsell capability        upsell evals     ──► revenue path hardens
UNDERSTAND  ──► stage 10-11  ──► health-check skill        —               ──► nps event fires
SHARE       ──► stage 11-13  ──► referral invite           —               ──► invite + 0.1× credit
REFINE      ──► continuous   ──► frameworks-library.md    description opt  ──► L6 promotes highway
```

Every column is a different file format. Every row is the same moment in the customer journey. The substrate doesn't care which surface wrote the event — pheromone accumulates on the same path whether it came from a chip click, a payment webhook, or a Skill Creator eval score. **The playbook is the human vocabulary for what the substrate measures natively.**

---

## 13. The team-level moats

| Capability | How it works |
|---|---|
| **Foundation + Frameworks = one source of truth** | Every specialist grounds in the same Blueprint + Frameworks Library. Drift impossible. |
| **Memory compounds** | Every job writes a weighted path; the 1000th decision uses the 999th's outcome |
| **Adversarial pre-launch** | QA Reviewer red-teams every customer-facing output before launch |
| **Customer simulation** | High-stakes campaigns dry-run against synthetic personas from Customer Profiling |
| **Parallel exploration** | Council pattern: spawn N Marketing Strategists, score, pick top idea |
| **Self-improving specialists** | Skill Creator eval-loops underperformers, drafts variants, A/B tests, picks winners |
| **N=1 personalization** | Per-recipient copy, page, cadence, tone — derived from substrate reads |
| **Cross-domain pattern matching** | Insights Lead queries paths across all 4 pods — "3 sales objections this week match a community complaint last month" |
| **Real-time exec dashboard** | Operations Dashboard with root-cause traces through the path graph |
| **Marketplace deployment** | Same specialist sold externally at £0.02/call via x402 |

---

## 14. Cost comparison

### Human GTM (typical mid-market)

| Pod | Headcount | Loaded comp |
|---|---:|---:|
| Marketing | 27 | £2,700,000 |
| Sales | 19 | £2,700,000 |
| Customer Service | 22 | £1,940,000 |
| Community | 7 | £660,000 |
| Operations / RevOps | 4 | £700,000 |
| **Total FTE** | **79** | **£8,700,000** |
| Plus external consultants (Hormozi/Dunford/Brunson/strategy) | — | £100-300k/yr |

### Agent GTM (same coverage, 24/7)

| Pod | Directors | Specialists | Skills | Annual run cost |
|---|---:|---:|---:|---:|
| Marketing | 1 | 13 | ~115 | ~£40,000 |
| Sales | 1 | 5 | 22 | ~£18,000 |
| Customer Service | 1 | 8 | 19 | ~£15,000 |
| Community | 1 | 4 | 10 | ~£6,000 |
| Foundation | — | 7 | 14 + Frameworks Library | ~£7,000 |
| Refine | — | 4 | 5 | ~£7,000 |
| **Total** | **4** | **41** | **~185** | **~£93,000** |

**~£8.6M saved · ~95× cost advantage · plus £100-300k/yr consulting eliminated.**

Quality lift: 24/7 vs 8/5 · N=1 personalization · continuous measurement · adversarial pre-launch · path memory · zero coordination tax · frameworks applied by default.

### Pricing tiers

| Tier | Includes | Replaces / augments | Annual |
|---|---|---|---:|
| **Starter** | Head of Marketing + 12 skills + Frameworks Library | Junior copy + design + content | £24k |
| **Growth** | + Head of Sales + 8 sales skills + Offer Architect | + SDRs + Junior AEs + Hormozi/funnel consulting | £60k |
| **Scale** | + Head of Customer Service + service stack | + T1/T2 support + onboarding | £120k |
| **Full GTM** | All 4 pods + Foundation + Refine + all framework workflows | 30+ FTE + all external consultants | £240k |
| **Enterprise** | Custom specialists + on-prem MCP + Agentverse + BYOK | — | £500k+ |

A client paying £240k replaces £3-4M of human comp **plus** £100-300k of consulting. **15-20× ROI on day one**, compounding via Memory and Insight loops.

---

## 15. Deployment

**Ships in 2 minutes.**

1. **Spin up the team** — one command provisions the 4 directors + chosen specialists + skills + connectors per tier.
2. **Load context** — pick any combination:
   - **Paste** company brief / product docs / customer notes
   - **Crawl** the website; the Web Crawler tool ingests pages, products, FAQs, blog
   - **Connect** existing CRM/email/analytics; importers backfill the substrate
3. **Done.** Strategic Blueprint builds itself from loaded context. Frameworks Library is preloaded. Every specialist reads from both. Output starts immediately.

No 30-day implementation projects. No consultants. The team deploys as fast as Slack and learns as it runs.

---

## 16. The pitch (one paragraph)

Your marketing team is 27 people costing £2.7M a year. They ship 3-5 A/B tests a month, refresh customer profiles annually (if at all), and pay £30-80k per engagement to external consultants for offer construction and positioning. Our Head of Marketing + Offer Architect + Positioning Architect + Creative Strategist + Funnel Architect + 75 framework-aware skills cost ~£32k a year (£60k at scale), ship 50 variants per cohort, refresh customer profiles weekly from real Voice-of-Customer signals, send per-recipient sequences to every lead, audit brand voice on every send, and run Hormozi's Grand Slam Offer workflow as a 30-minute callable process. Your senior copywriter writes 4 ads a month; with the Copywriting skill she ships 40. Your SDR team of 6 books 50 meetings at £7k each; Prospect Research + Lead Scoring + Cold Email Writing books 400 at £500 each. We don't replace your CMO, your strategists, or your customer relationships — we replace tactical headcount and external consulting, and we turn your senior team into the high-leverage layer they were always meant to be. We deliver the same playbook with the canonical frameworks of Hormozi, Schwartz, Brunson, Dunford, and Weinberg applied by default — plus continuous memory, adversarial review, parallel exploration, and N=1 personalization that compound over time. The 1000th campaign is materially better than the 1st because every result updates the playbook the next specialist reads. **That is the moat.**

---

## 17. Reference

- **Spec:** `plans/agent-spec.md` — agent / skill / tool contract
- **Template:** `plans/agent-template.md`
- **Authoring loop:** `one.ie/agents/skill-creator/SKILL.md`
- **SDK runtime:** `packages/sdk/src/{client,fetch,compile,skills}.ts`
- **Existing directors:** `one.ie/agents/{cmo,cro,cxo,cco,ceo}.md`
- **Existing specialists:** `one.ie/agents/{copywriter,analyst,strategist,compliance,journey-runner}.md`
- **Connectors:** `one.ie/agents/import-*.md`, `one.ie/agents/export-*.md`
- **ELEVATE source:** `apps/playbook/book/`
- **Reference agent library:** `apps/agency-operator/.claude/` (Donal's 8 agents + 122 skills)

Every new agent lands in `one.ie/agents/<slug>.md` with role title in `title:`. Every new skill lands in `one.ie/skills/<slug>.md` with `evals[]` and an activity-name title (e.g., `title: Copywriting`). The Frameworks Library lives at `one.ie/agents/foundation/frameworks-library.md`. Every Marketing/Sales agent's frontmatter declares `reads: [frameworks-library, blueprint]`. Both authored via Skill Creator.
