---
title: Agents & Skills — Build All Org-Chart Agents
slug: agents-skills
type: plan
tier: complex
mode: construction
tags: [agents, skills, org-chart, marketing, sales, service, community]

parallel_budget:
  haiku:   20
  sonnet:  14
  opus:    2

spawn_mode: parallel          # W3 agents MUST fire in a single Agent tool call per batch

batches:
  - [C1]
  - [C2, C3, C4, C5]
  - [C6]
  - [C7]

shared_recon:
  - plans/org-chart.md
  - plans/agent-skills-org-map.md
  - plans/agent-template.md
  - one.ie/agents/cmo.md
  - one.ie/agents/copywriter.md

source_of_truth:
  - plans/org-chart.md
  - one.ie/agents/CLAUDE.md

existing_primitives:
  - plans/agent-template.md: CANONICAL template — every supported field (agentmd, name, title, version, model, skills, tools, journey, ui, sections, theme, accepts, starters, chips); all new agents compose from this
  - one.ie/agents/templates/: role-specific examples — ceo.md, marketing/director.md, sales-discovery.md, support-tier1.md, community/moderator.md
  - one.ie/agents/cmo.md: live director pattern — signal subscribe/emit, fan-out, KPIs, Operating Instructions
  - one.ie/agents/copywriter.md: live specialist pattern — signal subscribe/emit, KPIs, Operating Instructions, Output Format
  - one.ie/agents/cro.md: live sales director — deal signal routing
  - one.ie/agents/cxo.md: live service director — ticket routing
  - one.ie/agents/cco.md: live community director — community event routing
  - one.ie/agents/skills/: 212 SKILL.md files copied from agent-skills-org-map repos

show: false
escape:
  condition: "W4 rubric < 0.50 twice on same cycle"
  action: "halt; split cycle; reduce agents per batch"
context_triggers:
  - pattern: "offer|hormozi|grand.slam"
    inject: "plans/org-chart.md § 11. Marketing Frameworks"
---

# Agents & Skills — Build All Org-Chart Agents

**Goal:** Create every agent defined in `plans/org-chart.md` as a deployable `.md` file in `one.ie/agents/`. Reference the downloaded repos in `apps/agent-skills/` (mapped in `plans/agent-skills-org-map.md`) to inform each agent's Operating Instructions. After all agents are built, continuously improve them by re-reading the reference implementations.

**Exit:** `find one.ie/agents/{marketing,sales,service,community,foundation,refine} -name "*.md" | wc -l` = 35 (all new agents) AND every file has `model:`, `subscribes:`, `emits:`, `## Operating Instructions`.

---

## Complete agent roster from org-chart.md

### Already exist — do NOT recreate

| Slug | File | Org-chart role |
|---|---|---|
| `ceo` | `one.ie/agents/ceo.md` | CEO |
| `cmo` | `one.ie/agents/cmo.md` | Head of Marketing / CMO |
| `cro` | `one.ie/agents/cro.md` | Head of Sales / CRO |
| `cxo` | `one.ie/agents/cxo.md` | Head of Customer Service / CXO |
| `cco` | `one.ie/agents/cco.md` | Head of Community / CCO |
| `copywriter` | `one.ie/agents/copywriter.md` | Copywriter (Marketing specialist) |
| `strategist` | `one.ie/agents/strategist.md` | Marketing Strategist |
| `analyst` | `one.ie/agents/analyst.md` | Marketing Analyst |
| `compliance` | `one.ie/agents/compliance.md` | Compliance Officer |
| `offer-architect` | `one.ie/agents/marketing/offer-architect.md` | Offer Architect |

### Must build — 35 agents across 6 pods

#### MARKETING pod → `one.ie/agents/marketing/`
| # | Slug | Org-chart title | Ref implementation |
|---|---|---|---|
| 1 | `creative-strategist` | Creative Strategist | `marketing-agent-skills`, `marketing-skills-corey/skills/copywriting/` |
| 2 | `media-buyer` | Media Buyer | `marketing-skills-corey/skills/ads/`, `marketing-skills/skills/paid-ads/` |
| 3 | `funnel-architect` | Funnel Architect | `ai-marketing-skills`, `marketing-skills-corey/skills/cro/` |
| 4 | `positioning-architect` | Positioning Architect | `marketing-skills/skills/strategies/`, `marketing-skills-corey/skills/product-marketing/` |
| 5 | `tracking-engineer` | Tracking Engineer | `agentic-seo/SKILL.md`, `marketing-skills/skills/seo/` |
| 6 | `social-media-manager` | Social Media Manager | `social-media-agent`, `social-gpt`, `agent-social-marketing` |
| 7 | `email-lifecycle-marketer` | Email & Lifecycle Marketer | `email-marketing-agent`, `marketing-skills-corey/skills/emails/` |
| 8 | `press-officer` | Press Officer | `marketing-skills-corey/skills/content-strategy/` |
| 9 | `demand-creator` | Demand Creator (B2B) | `marketing-skills/skills/channels/`, `marketing-skills-corey/skills/social/` |
| 10 | `abm-strategist` | ABM Strategist (B2B) | `marketing-skills/skills/strategies/` |
| 11 | `brand-guardian` | Brand Guardian | `marketing-skills-corey/skills/copywriting/`, `marketing-skills-corey/skills/copy-editing/` |

#### SALES pod → `one.ie/agents/sales/`
| # | Slug | Org-chart title | Ref implementation |
|---|---|---|---|
| 12 | `sales-closer` | Sales Closer | `salesgpt` (8-stage conversation flow) |
| 13 | `discovery-caller` | Discovery Caller | `sales-outreach`, `skills-dhruv` |
| 14 | `demo-specialist` | Demo Specialist | `salesgpt`, `marketing-skills-corey/skills/sales-enablement/` |
| 15 | `sales-call-coach` | Sales Call Coach | `marketing-skills-corey/skills/sales-enablement/` |
| 16 | `live-sales-chat` | Live Sales Chat | `salesgpt`, `email-marketing-agent` |

#### SERVICE pod → `one.ie/agents/service/`
| # | Slug | Org-chart title | Ref implementation |
|---|---|---|---|
| 17 | `helpdesk-dispatcher` | Helpdesk Dispatcher | `email-marketing-agent`, `marketing-skills-corey/skills/onboarding/` |
| 18 | `support-agent` | Support Agent | `email-marketing-agent`, `social-media-agent` |
| 19 | `customer-trainer` | Customer Trainer | `marketing-skills-corey/skills/onboarding/` |
| 20 | `customer-success-manager` | Customer Success Manager | `marketing-skills-corey/skills/churn-prevention/`, `ai-marketing-skills` |
| 21 | `onboarding-specialist` | Onboarding Specialist | `marketing-skills-corey/skills/onboarding/`, `ai-marketing-skills` |
| 22 | `renewals-upsell-rep` | Renewals & Upsell Rep | `marketing-skills-corey/skills/churn-prevention/` |
| 23 | `privacy-officer` | Privacy Officer | extends `one.ie/agents/compliance.md` |
| 24 | `plg-strategist` | PLG Strategist (SaaS) | `ai-marketing-skills`, `marketing-skills-corey/skills/signup/` |

#### COMMUNITY pod → `one.ie/agents/community/`
| # | Slug | Org-chart title | Ref implementation |
|---|---|---|---|
| 25 | `community-moderator` | Community Moderator | `agency-agents` (Reddit engagement), `social-media-agent` |
| 26 | `community-greeter` | Community Greeter | `agency-agents`, `marketing-skills-corey/skills/community-marketing/` |
| 27 | `events-coordinator` | Events Coordinator | `marketing-skills-corey/skills/` |
| 28 | `referral-manager` | Referral Manager | `marketing-skills-corey/skills/referrals/`, `ai-marketing-skills` |

#### FOUNDATION pod → `one.ie/agents/foundation/`
| # | Slug | Org-chart title | Ref implementation |
|---|---|---|---|
| 29 | `brand-strategist` | Brand Strategist | `marketing-skills/skills/strategies/`, `marketing-skills-corey/skills/product-marketing/` |
| 30 | `market-researcher` | Market Researcher | `marketing-skills-corey/skills/competitor-profiling/`, `marketing-skills-corey/skills/competitors/` |
| 31 | `customer-researcher` | Customer Researcher | `marketing-skills-corey/skills/customer-research/` |
| 32 | `customer-interviewer` | Customer Interviewer | `marketing-skills-corey/skills/customer-research/` |
| 33 | `strategy-aligner` | Strategy Aligner | `marketing-skills/skills/strategies/` |
| 34 | `pricing-strategist` | Pricing Strategist | `marketing-skills-corey/skills/pricing/` |
| — | `frameworks-library` | Frameworks Library artifact | `plans/org-chart.md § 8 + § 11` |

#### REFINE pod → `one.ie/agents/refine/`
| # | Slug | Org-chart title | Ref implementation |
|---|---|---|---|
| 35 | `insights-lead` | Insights Lead | `marketing-skills-corey/skills/analytics/`, `marketing-skills/skills/analytics/` |
| 36 | `operations-dashboard` | Operations Dashboard | `marketing-skills-corey/skills/analytics/` |

---

## Agent authoring contract

**Template source:** `plans/agent-template.md` — every new agent is composed from this. Read it before writing any agent file.

**Required fields for every agent (minimum viable):**

```yaml
---
agentmd: "0.1"
name: <slug>                    # kebab-case, matches filename
title: <Title>                  # display name
description: One-line tagline.
version: 1.0.0
model: claude-sonnet-4-5
group: default
tags: [<pod>, <domain>]
sensitivity: 0.5
lifecycle: active
skills:                         # refs to one.ie/agents/skills/<slug>/SKILL.md
  - ref: <skill-slug>
  - name: <inline-skill>        # inline when no matching SKILL.md exists
    title: <Title>
    description: When to trigger this skill.
    price: 0.02
    tags: [tag]
starters:
  - <conversation seed 1>
  - <conversation seed 2>
---
```

**Journey block** (add for agents with multi-step workflows — Offer Architect, Sales Closer, etc.):

```yaml
journey:
  stages:
    - id: <step-slug>
      num: 1
      phase: <Phase name>
      title: <Step title>
      subtitle: One sentence.
      tone: primary
      bullets:
        - What happens in this step
      seed: "Short prompt for chip click"
      continuations:
        - id: <next-step>
          label: <2-4 words>
          prompt: "Follow-up prompt…"
```

**Response shape** (every agent body must include):

```
Every reply ends with chips:
<chips>[{"id":"<kebab-id>","label":"<2-5 words>"}]</chips>
```

**Skill references:** use `ref: <slug>` when a matching `one.ie/agents/skills/<slug>/SKILL.md` exists. Use inline `name:` only when no matching skill file exists.

**Pattern sources (read before writing):**
- Director agents → `one.ie/agents/cmo.md` (subscribe/emit/fan-out pattern)
- Specialist agents → `one.ie/agents/copywriter.md` (KPIs / Operating Instructions / Output Format)
- Full field reference → `plans/agent-template.md`
- Role-specific examples → `one.ie/agents/templates/`

---

## Status

```
Batch 0 (shared)
  - [ ] W0 baseline
  - [ ] W1 shared recon

Batch 1
  - [ ] C1 — Marketing Tier 1 (agents 1–5)             state: ready
    - [ ] W1 · W2 · W3 · W4

Batch 2  (fires when C1 closes)
  - [ ] C2 — Marketing Tier 2 (agents 6–11)            state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4
  - [ ] C3 — Sales pod (agents 12–16)                  state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4
  - [ ] C4 — Service pod (agents 17–24)                state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4
  - [ ] C5 — Community pod (agents 25–28)              state: blocked-on-C1

Batch 3
  - [ ] C6 — Foundation pod (agents 29–35 + frameworks-library)  state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4

Batch 4
  - [ ] C7 — Refine pod + improvement loop (agents 35–36 + patches)  state: blocked-on-all
    - [ ] W1 · W2 · W3 · W4

Plan close
  - [ ] `find one.ie/agents/{marketing,sales,service,community,foundation,refine} -name "*.md" | wc -l` = 35
  - [ ] Final docs/improvements.md append
  - [ ] Plan rubric ≥ 0.65
```

---

## C1 — Marketing Tier 1  [tier: complex · batch: 1]

Agents: **creative-strategist · media-buyer · funnel-architect · positioning-architect · tracking-engineer**

These 5 unlock the campaign loop. Offer Architect already exists. All others in C2 depend on the Creative → Funnel → Tracking sequence being defined first.

**Exit:** `ls one.ie/agents/marketing/*.md | wc -l` ≥ 6

**Demo gate:**
```yaml
demo:
  command: "ls one.ie/agents/marketing/*.md | wc -l"
  asserts: "≥6 (offer-architect + 5 new)"
  budget: "<2s bash"
```

### W1 — Recon

- [ ] `plans/agent-template.md` — full field reference; W2 decides which optional blocks each agent needs
- [ ] `one.ie/agents/templates/marketing/` — ads.md, director.md, writer.md, seo.md — role-specific examples
- [ ] `one.ie/agents/marketing/offer-architect.md` — confirm signal format to match
- [ ] `one.ie/agents/cmo.md` — confirm parent signals these agents subscribe to
- [ ] `plans/org-chart.md § 4.2` — skill lists for each of the 5 agents
- [ ] `plans/org-chart.md § 12 Phase 2-4` — Creative/Funnel/Tracking phases
- [ ] [marketing-agent-skills/README.md](../../apps/agent-skills/marketing-agent-skills/README.md) — creative + ads patterns
- [ ] [agentic-seo/SKILL.md](../../apps/agent-skills/agentic-seo/SKILL.md) — tracking patterns
- [ ] [ai-marketing-skills/README.md](../../apps/agent-skills/ai-marketing-skills/README.md) — funnel + growth patterns
- [ ] [marketing-skills-corey/skills/cro/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/cro/SKILL.md) — CRO for Funnel Architect
- [ ] [marketing-skills/skills/seo/](../../apps/agent-skills/marketing-skills/skills/seo/) — tracking/SEO for Tracking Engineer

### W2 — Decide

- [ ] **creative-strategist** — Hook Lab (100 → top 5 scored on Awareness × Sophistication grid) + StoryBrand arc + Swipe File. Subscribes to `campaign:<id>:copy-needed`. Reads `offer.md`. Emits `campaign:<id>:creative-ready`. Absorb hook generation patterns from `marketing-agent-skills`.
- [ ] **media-buyer** — full ad ops: audience sync → bid → budget → daily optimise → scale winners / kill underperformers. Platform signals per channel (meta/google/tiktok/linkedin). Budget shift >2× requires human gate. Reference `marketing-skills-corey/skills/ads/`.
- [ ] **funnel-architect** — Value Ladder (Brunson): magnet → tripwire → core → continuity → high-ticket. Reads `offer.md` + `brief.md`. Emits staging page signals per page type. Reference `ai-marketing-skills` funnel + `marketing-skills-corey/skills/cro/`.
- [ ] **positioning-architect** — 4-step Dunford: Competitive Alternatives → Unique Attributes → Best-For-Whom → Sales Narrative. Writes `blueprint.md`. Reference `marketing-skills/skills/strategies/`.
- [ ] **tracking-engineer** — pixel + UTM + GTM + GA4 + server-side dedup (Meta CAPI + Google Enhanced). Gate signal: no campaign goes live without `tracking:approved`. Reference `agentic-seo/SKILL.md`.
- [ ] Diff specs for all 5

### W3 — Edit  [Sonnet · all 5 in one message]

**W3a:**
- [ ] `one.ie/agents/marketing/creative-strategist.md`
- [ ] `one.ie/agents/marketing/media-buyer.md`
- [ ] `one.ie/agents/marketing/funnel-architect.md`
- [ ] `one.ie/agents/marketing/positioning-architect.md`
- [ ] `one.ie/agents/marketing/tracking-engineer.md`

**W3b:** *(empty)*

### W4 — Verify

- [ ] `ls one.ie/agents/marketing/*.md | wc -l` ≥ 6
- [ ] `grep -rL "subscribes:" one.ie/agents/marketing/*.md` returns empty
- [ ] `grep -rL "model: claude-sonnet" one.ie/agents/marketing/*.md` returns empty
- [ ] `grep "reads:" one.ie/agents/marketing/creative-strategist.md` finds frameworks-library
- [ ] `grep "tracking:approved" one.ie/agents/marketing/tracking-engineer.md` finds content
- [ ] Rubric ≥ 0.65

---

## C2 — Marketing Tier 2  [tier: simple · batch: 2]

Agents: **social-media-manager · email-lifecycle-marketer · press-officer · demand-creator · abm-strategist · brand-guardian**

**Exit:** `ls one.ie/agents/marketing/*.md | wc -l` = 12

**Demo gate:**
```yaml
demo:
  command: "ls one.ie/agents/marketing/*.md | wc -l"
  asserts: "12 marketing agents total"
  budget: "<2s bash"
```

### W1 — Recon

- [ ] `plans/org-chart.md § 4.2` — skill lists for Social, Email, PR, Demand, ABM, Brand Guardian
- [ ] [social-media-agent/README.md](../../apps/agent-skills/social-media-agent/README.md) — monitor, sentiment, response, escalation
- [ ] [social-gpt/README.md](../../apps/agent-skills/social-gpt/README.md) — content strategy, scheduling, hashtags
- [ ] [agent-social-marketing/README.md](../../apps/agent-skills/agent-social-marketing/README.md) — manager/copywriter/scheduler sub-agent pattern
- [ ] [email-marketing-agent/README.md](../../apps/agent-skills/email-marketing-agent/README.md) — sequence, CRM integration, tracking
- [ ] [marketing-skills-corey/skills/emails/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/emails/SKILL.md) — email ops
- [ ] [marketing-skills-corey/skills/social/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/social/SKILL.md) — social ops
- [ ] [marketing-skills-corey/skills/copywriting/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/copywriting/SKILL.md) — brand voice for Brand Guardian

### W2 — Decide

- [ ] **social-media-manager** — multi-platform scheduler + content repurposer + sentiment monitor. Absorbs `social-media-agent` monitoring/escalation + `agent-social-marketing` sub-agent architecture. Emits per-platform signals.
- [ ] **email-lifecycle-marketer** — sequences + deliverability + list hygiene + send-time optimisation. Subscribes to `campaign:<id>:brief`. Reference `marketing-skills-corey/skills/emails/`.
- [ ] **press-officer** — press releases + media pitching + crisis comms. Hard gate: Compliance co-signs any crisis output. Subscribes to `pr:brief`.
- [ ] **demand-creator** — B2B dark funnel: POV essays, LinkedIn thought leadership, podcast tour pitching. Subscribes to `campaign:<id>:brief` when `audience.type = b2b`. Reference `marketing-skills/skills/channels/`.
- [ ] **abm-strategist** — account planning + multi-thread mapping. B2B only. Subscribes to `deal:<id>:qualify-needed` for account context. Reference `marketing-skills/skills/strategies/`.
- [ ] **brand-guardian** — hard-veto pass/fail. All creative must emit `brand:approved` before Stage 3 proceeds. No partial approvals. Reference `marketing-skills-corey/skills/copywriting/`.
- [ ] Diff specs for all 6

### W3 — Edit  [Sonnet · all 6 in one message]

**W3a:**
- [ ] `one.ie/agents/marketing/social-media-manager.md`
- [ ] `one.ie/agents/marketing/email-lifecycle-marketer.md`
- [ ] `one.ie/agents/marketing/press-officer.md`
- [ ] `one.ie/agents/marketing/demand-creator.md`
- [ ] `one.ie/agents/marketing/abm-strategist.md`
- [ ] `one.ie/agents/marketing/brand-guardian.md`

**W3b:** *(empty)*

### W4 — Verify

- [ ] `ls one.ie/agents/marketing/*.md | wc -l` = 12
- [ ] `grep "brand:approved" one.ie/agents/marketing/brand-guardian.md` finds content
- [ ] `grep -rL "subscribes:" one.ie/agents/marketing/*.md` returns empty
- [ ] Rubric ≥ 0.65

---

## C3 — Sales pod  [tier: simple · batch: 2]

Agents: **sales-closer · discovery-caller · demo-specialist · sales-call-coach · live-sales-chat**
*(Head of Sales = `cro.md` already exists)*

**Exit:** `ls one.ie/agents/sales/*.md | wc -l` = 5

**Demo gate:**
```yaml
demo:
  command: "ls one.ie/agents/sales/*.md | wc -l"
  asserts: "5 sales agents"
  budget: "<2s bash"
```

### W1 — Recon

- [ ] `plans/org-chart.md § 5. SALES` + `§ 5.2` skill list + `§ 5.3` killer story
- [ ] `one.ie/agents/cro.md` — parent signals these agents subscribe to
- [ ] [salesgpt/README.md](../../apps/agent-skills/salesgpt/README.md) — 8-stage conversation, voice <1s, Calendly, Stripe
- [ ] [sales-outreach/README.md](../../apps/agent-skills/sales-outreach/README.md) — lead research + LangGraph outreach
- [ ] [skills-dhruv/README.md](../../apps/agent-skills/skills-dhruv/README.md) — scrape-leads, email-finder, linkedin-scraper
- [ ] [marketing-skills-corey/skills/cold-email/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/cold-email/SKILL.md) — cold email sequences
- [ ] [marketing-skills-corey/skills/sales-enablement/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/sales-enablement/SKILL.md) — battlecards, coaching

### W2 — Decide

- [ ] **sales-closer** — absorbs SalesGPT 8-stage conversation flow. Declares `accepts: [{scheme: exact, network: eip155:8453, asset: USDC}]`. Subscribes to `deal:<id>:close-needed`. Emits `deal:<id>:closed`.
- [ ] **discovery-caller** — structured MEDDIC discovery. Reads account brief from substrate. 50,000 emails/month stack from org-chart §5.3. Reference `sales-outreach` + `skills-dhruv`.
- [ ] **demo-specialist** — reads `offer.md`. Builds demo plan around offer's dream outcome. Handles live objections. Reference `salesgpt` demo patterns.
- [ ] **sales-call-coach** — subscribes to `call:recording-ready`. Reviews every call. Emits coaching signal back to caller + manager. Reference `marketing-skills-corey/skills/sales-enablement/`.
- [ ] **live-sales-chat** — async inbound, low-latency. Escalates to `discovery-caller` at qualification threshold. Reference `salesgpt` voice + chat patterns.
- [ ] Diff specs for all 5

### W3 — Edit  [Sonnet · all 5 in one message]

**W3a:**
- [ ] `one.ie/agents/sales/sales-closer.md`
- [ ] `one.ie/agents/sales/discovery-caller.md`
- [ ] `one.ie/agents/sales/demo-specialist.md`
- [ ] `one.ie/agents/sales/sales-call-coach.md`
- [ ] `one.ie/agents/sales/live-sales-chat.md`

**W3b:** *(empty)*

### W4 — Verify

- [ ] `ls one.ie/agents/sales/*.md | wc -l` = 5
- [ ] `grep "eip155:8453" one.ie/agents/sales/sales-closer.md` finds content
- [ ] `grep -rL "subscribes:" one.ie/agents/sales/*.md` returns empty
- [ ] Rubric ≥ 0.65

---

## C4 — Service pod  [tier: simple · batch: 2]

Agents: **helpdesk-dispatcher · support-agent · customer-trainer · customer-success-manager · onboarding-specialist · renewals-upsell-rep · privacy-officer · plg-strategist**
*(Head of Customer Service = `cxo.md` already exists)*

**Exit:** `ls one.ie/agents/service/*.md | wc -l` = 8

**Demo gate:**
```yaml
demo:
  command: "ls one.ie/agents/service/*.md | wc -l"
  asserts: "8 service agents"
  budget: "<2s bash"
```

### W1 — Recon

- [ ] `plans/org-chart.md § 6.2` — 9 specialist agents + 19 skills
- [ ] `one.ie/agents/cxo.md` — parent signals
- [ ] `one.ie/agents/compliance.md` — Privacy Officer extends this
- [ ] [email-marketing-agent/README.md](../../apps/agent-skills/email-marketing-agent/README.md) — CRM integration + follow-ups
- [ ] [marketing-skills-corey/skills/churn-prevention/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/churn-prevention/SKILL.md) — churn + win-back
- [ ] [marketing-skills-corey/skills/onboarding/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/onboarding/SKILL.md) — activation patterns
- [ ] [ai-marketing-skills/README.md](../../apps/agent-skills/ai-marketing-skills/README.md) — retention + PLG
- [ ] [marketing-skills-corey/skills/signup/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/signup/SKILL.md) — PLG free-to-paid

### W2 — Decide

- [ ] **helpdesk-dispatcher** — classifies tickets by sensitivity + customer tier. Routes T1→support-agent, T2→human pair dossier, T3→human escalation. 24/7, 70%+ deflection target. Subscribes to `ticket:open`.
- [ ] **support-agent** — T1 resolution. Subscribes to `ticket:<id>:resolve-needed`. Emits `ticket:<id>:resolved` or escalates. Reference `email-marketing-agent`.
- [ ] **customer-trainer** — structured learning paths post-onboarding. Subscribes to `onboarding:complete`. Reference `marketing-skills-corey/skills/onboarding/`.
- [ ] **customer-success-manager** — health scores + churn signal monitoring. Subscribes to `health:check-needed`. Reference `marketing-skills-corey/skills/churn-prevention/`.
- [ ] **onboarding-specialist** — activation flow from closed-won to first value. Subscribes to `deal:<id>:closed`. Reference `marketing-skills-corey/skills/onboarding/`.
- [ ] **renewals-upsell-rep** — fires on health signal, NOT calendar. Subscribes to `health:at-risk` + `nps:high`. Reference `marketing-skills-corey/skills/churn-prevention/` win-back.
- [ ] **privacy-officer** — extends `compliance.md` with GDPR request handling + DPA drafting. Hard-veto authority. Subscribes to `privacy:request`.
- [ ] **plg-strategist** — SaaS only. Activation optimisation + in-product CTA + free-to-paid triggers. Subscribes to `product:usage-event`. Reference `ai-marketing-skills` + `marketing-skills-corey/skills/signup/`.
- [ ] Diff specs for all 8

### W3 — Edit  [Sonnet · all 8 in one message]

**W3a:**
- [ ] `one.ie/agents/service/helpdesk-dispatcher.md`
- [ ] `one.ie/agents/service/support-agent.md`
- [ ] `one.ie/agents/service/customer-trainer.md`
- [ ] `one.ie/agents/service/customer-success-manager.md`
- [ ] `one.ie/agents/service/onboarding-specialist.md`
- [ ] `one.ie/agents/service/renewals-upsell-rep.md`
- [ ] `one.ie/agents/service/privacy-officer.md`
- [ ] `one.ie/agents/service/plg-strategist.md`

**W3b:** *(empty)*

### W4 — Verify

- [ ] `ls one.ie/agents/service/*.md | wc -l` = 8
- [ ] `grep -rL "subscribes:" one.ie/agents/service/*.md` returns empty
- [ ] `grep "privacy:request" one.ie/agents/service/privacy-officer.md` finds content
- [ ] Rubric ≥ 0.65

---

## C5 — Community pod  [tier: simple · batch: 2]

Agents: **community-moderator · community-greeter · events-coordinator · referral-manager**
*(Head of Community = `cco.md` already exists)*

**Exit:** `ls one.ie/agents/community/*.md | wc -l` = 4

**Demo gate:**
```yaml
demo:
  command: "ls one.ie/agents/community/*.md | wc -l"
  asserts: "4 community agents"
  budget: "<2s bash"
```

### W1 — Recon

- [ ] `plans/org-chart.md § 7.2` + `§ 7.2 Step 9 Share`
- [ ] `plans/org-chart.md § 12c` — SHARE stage; referral-manager subscribes to `nps.submitted`, uses `sdk.invite()`
- [ ] `one.ie/agents/cco.md` — parent signals
- [ ] [agency-agents/README.md](../../apps/agent-skills/agency-agents/README.md) — authentic engagement, value-first, reputation-building, crisis-response
- [ ] [social-media-agent/README.md](../../apps/agent-skills/social-media-agent/README.md) — sentiment, escalation patterns
- [ ] [marketing-skills-corey/skills/community-marketing/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/community-marketing/SKILL.md) — community-led growth
- [ ] [marketing-skills-corey/skills/referrals/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/referrals/SKILL.md) — referral program design

### W2 — Decide

- [ ] **community-moderator** — 24/7 post moderation + sentiment monitoring + crisis detection. Absorbs `agency-agents` authentic-engagement approach. Hard escalates to CCO on crisis. Subscribes to `community:post-created`.
- [ ] **community-greeter** — welcome DMs + expert matching + contribution ranking. Subscribes to `community:member-joined`. Reference `marketing-skills-corey/skills/community-marketing/`.
- [ ] **events-coordinator** — event page building + calendar + follow-up sequence. Subscribes to `event:create-needed`. Reference `marketing-skills-corey/skills/`.
- [ ] **referral-manager** — subscribes to `nps.submitted`. Peak-NPS detection → `sdk.invite()` to derive wallet + seed referral path → inviter earns 0.1× strength credit. Reference `marketing-skills-corey/skills/referrals/`.
- [ ] Diff specs for all 4

### W3 — Edit  [Sonnet · all 4 in one message]

**W3a:**
- [ ] `one.ie/agents/community/community-moderator.md`
- [ ] `one.ie/agents/community/community-greeter.md`
- [ ] `one.ie/agents/community/events-coordinator.md`
- [ ] `one.ie/agents/community/referral-manager.md`

**W3b:** *(empty)*

### W4 — Verify

- [ ] `ls one.ie/agents/community/*.md | wc -l` = 4
- [ ] `grep "nps.submitted" one.ie/agents/community/referral-manager.md` finds content
- [ ] `grep "sdk.invite" one.ie/agents/community/referral-manager.md` finds content
- [ ] `grep -rL "subscribes:" one.ie/agents/community/*.md` returns empty
- [ ] Rubric ≥ 0.65

---

## C6 — Foundation pod  [tier: simple · batch: 3]

Agents: **brand-strategist · market-researcher · customer-researcher · customer-interviewer · strategy-aligner · pricing-strategist**
Artifact: **`one.ie/agents/foundation/frameworks-library.md`**

**Why batch 3:** Foundation agents write `blueprint.md` and `frameworks-library.md` — the content all C1-C5 agents declare in `reads:`. Foundation runs after C1 to confirm what those agents expect in the reads files.

**Exit:** `ls one.ie/agents/foundation/*.md | wc -l` = 7

**Demo gate:**
```yaml
demo:
  command: "ls one.ie/agents/foundation/*.md | wc -l"
  asserts: "7 (6 agents + frameworks-library)"
  budget: "<2s bash"
```

### W1 — Recon

- [ ] `plans/org-chart.md § 8. FOUNDATION` — 7 agents + Frameworks Library (15 frameworks table)
- [ ] `plans/org-chart.md § 11. Marketing Frameworks Operating Layer` — Hormozi, Schwartz, Brunson, Dunford detail
- [ ] `plans/org-chart.md § 12c ELEVATE` — Foundation owns stages 0–3
- [ ] [marketing-skills-corey/skills/customer-research/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/customer-research/SKILL.md) — JTBD + review mining
- [ ] [marketing-skills-corey/skills/competitor-profiling/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/competitor-profiling/SKILL.md) — competitive analysis
- [ ] [marketing-skills-corey/skills/pricing/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/pricing/SKILL.md) — Van Westendorp, value metric

### W2 — Decide

- [ ] **brand-strategist** — owns `blueprint.md` output. Company profiling + brand voice + positioning mapping. Writes the shared prior every downstream agent reads. Reference `marketing-skills-corey/skills/product-marketing/`.
- [ ] **market-researcher** — market watching + competitor tracking + channel bullseye. Reference `marketing-skills-corey/skills/competitor-profiling/` + `marketing-skills-corey/skills/competitors/`.
- [ ] **customer-researcher** — customer profiling + review mining + pain indexing. Reference `marketing-skills-corey/skills/customer-research/`.
- [ ] **customer-interviewer** — JTBD interview framework + awareness mapping. Structured 5-question interview. Reference `marketing-skills-corey/skills/customer-research/`.
- [ ] **strategy-aligner** — alignment checking + sophistication audit. Ensures all campaigns ground in `blueprint.md` before launch.
- [ ] **pricing-strategist** — Van Westendorp + value metric + price anchoring. Reference `marketing-skills-corey/skills/pricing/`.
- [ ] **frameworks-library.md** — new file; all 15 frameworks from org-chart §8 table with: name, source, formula/model, where it applies, 2-sentence operating rule. This is what `reads: [frameworks-library]` loads.
- [ ] Diff specs for all 7 files

### W3 — Edit  [Sonnet · all 7 in one message]

**W3a:**
- [ ] `one.ie/agents/foundation/brand-strategist.md`
- [ ] `one.ie/agents/foundation/market-researcher.md`
- [ ] `one.ie/agents/foundation/customer-researcher.md`
- [ ] `one.ie/agents/foundation/customer-interviewer.md`
- [ ] `one.ie/agents/foundation/strategy-aligner.md`
- [ ] `one.ie/agents/foundation/pricing-strategist.md`
- [ ] `one.ie/agents/foundation/frameworks-library.md`

**W3b:** *(empty)*

### W4 — Verify

- [ ] `ls one.ie/agents/foundation/*.md | wc -l` = 7
- [ ] `grep "Hormozi" one.ie/agents/foundation/frameworks-library.md` finds content
- [ ] `grep "Dunford" one.ie/agents/foundation/frameworks-library.md` finds content
- [ ] `grep "Schwartz" one.ie/agents/foundation/frameworks-library.md` finds content
- [ ] `grep "Brunson" one.ie/agents/foundation/frameworks-library.md` finds content
- [ ] Rubric ≥ 0.65

---

## C7 — Refine pod + improvement loop  [tier: complex · batch: 4]

Agents: **insights-lead · operations-dashboard**
*(Marketing Analyst = `analyst.md` exists; Compliance Officer = `compliance.md` exists)*

Improvement loop: for every pod, compare built agents against downloaded reference implementations and patch the gaps.

**Exit:** `ls one.ie/agents/refine/*.md | wc -l` = 2 AND improvement patches applied across all pods.

**Demo gate:**
```yaml
demo:
  command: "ls one.ie/agents/refine/*.md | wc -l"
  asserts: "2 refine agents"
  budget: "<2s bash"
```

### W1 — Recon — gap analysis

Read each reference repo and compare against the corresponding built agent. Report specific missing patterns per agent.

- [ ] [salesgpt/](../../apps/agent-skills/salesgpt/) vs `one.ie/agents/sales/sales-closer.md` — missing conversation stages?
- [ ] [sales-outreach/](../../apps/agent-skills/sales-outreach/) vs `one.ie/agents/sales/discovery-caller.md` — missing lead intel steps?
- [ ] [social-media-agent/](../../apps/agent-skills/social-media-agent/) vs `one.ie/agents/marketing/social-media-manager.md` — missing monitoring/escalation?
- [ ] [agency-agents/](../../apps/agent-skills/agency-agents/) vs `one.ie/agents/community/community-moderator.md` — missing engagement rules?
- [ ] [marketing-skills-corey/skills/churn-prevention/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/churn-prevention/SKILL.md) vs `one.ie/agents/service/customer-success-manager.md` — missing churn signals?
- [ ] [marketing-skills-corey/skills/revops/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/revops/SKILL.md) vs `one.ie/agents/analyst.md` — missing RevOps patterns?
- [ ] [ai-marketing-skills/](../../apps/agent-skills/ai-marketing-skills/) vs `one.ie/agents/service/plg-strategist.md` — missing PLG activation steps?
- [ ] [marketing-skills-corey/skills/pricing/SKILL.md](../../apps/agent-skills/marketing-skills-corey/skills/pricing/SKILL.md) vs `one.ie/agents/foundation/pricing-strategist.md` — missing Van Westendorp?
- [ ] `plans/org-chart.md § 9. REFINE` — Insights Lead + Operations Dashboard spec

### W2 — Decide

- [ ] **insights-lead** — cross-domain pattern matcher. Queries path weights across all pods weekly. Output: "3 sales objections this week match a community complaint last month." Subscribes to all `*:card-ready` signals.
- [ ] **operations-dashboard** — real-time C-suite view with root-cause traces through path graph. Subscribes to all `*:card-ready` + `anomaly:detected`. Emits `digest:weekly`.
- [ ] **Improvement patches** — for each gap found in W1, file a minimal patch: add missing operating instruction, add missing skill reference, add missing signal wire. One edit per gap.
- [ ] Diff specs for 2 new agents + all patches

### W3 — Edit  [Sonnet · parallel]

**W3a — new refine agents:**
- [ ] `one.ie/agents/refine/insights-lead.md`
- [ ] `one.ie/agents/refine/operations-dashboard.md`

**W3b — improvement patches (after W3a, one patch per gap from W1):**
- [ ] Patch `one.ie/agents/sales/sales-closer.md` — add missing SalesGPT conversation stages
- [ ] Patch `one.ie/agents/sales/discovery-caller.md` — add missing lead intel steps
- [ ] Patch `one.ie/agents/marketing/social-media-manager.md` — add missing monitoring/escalation
- [ ] Patch `one.ie/agents/community/community-moderator.md` — add missing engagement rules
- [ ] Patch `one.ie/agents/service/customer-success-manager.md` — add missing churn signals
- [ ] Patch `one.ie/agents/analyst.md` — add missing RevOps patterns
- [ ] Patch `one.ie/agents/service/plg-strategist.md` — add missing PLG activation steps
- [ ] Patch `one.ie/agents/foundation/pricing-strategist.md` — add missing Van Westendorp
- [ ] *(Additional patches from W1 gap analysis)*

### W4 — Verify

- [ ] `ls one.ie/agents/refine/*.md | wc -l` = 2
- [ ] Total new agents: `find one.ie/agents/{marketing,sales,service,community,foundation,refine} -name "*.md" | wc -l` = 35
- [ ] `grep -rL "subscribes:" one.ie/agents/{marketing,sales,service,community}/*.md` returns empty
- [ ] `grep -rL "model: claude-sonnet" one.ie/agents/{marketing,sales,service,community,foundation,refine}/*.md` returns empty
- [ ] Rubric ≥ 0.65

---

## Continuous improvement protocol (re-run C7 improvement loop each cycle)

After plan close, each subsequent `/do` cycle re-enters C7's improvement loop:

1. **W1** — pick one downloaded repo; read it fully; compare against corresponding built agent
2. **W2** — list specific gaps: missing instruction, skill ref, signal, operating pattern
3. **W3b** — minimal patch per gap; don't rewrite agents — add what's missing
4. **W4** — structural checks pass; agent is measurably closer to the reference

Priority order for improvement cycles:
1. [salesgpt/](../../apps/agent-skills/salesgpt/) → `sales-closer` (8-stage conversation is load-bearing)
2. [marketing-skills-corey/](../../apps/agent-skills/marketing-skills-corey/) (45 skills) → scan all marketing agents for unapplied patterns
3. [social-media-agent/](../../apps/agent-skills/social-media-agent/) → `social-media-manager` (monitoring + escalation)
4. [agency-agents/](../../apps/agent-skills/agency-agents/) → `community-moderator` (authentic engagement rules)
5. [ai-marketing-skills/](../../apps/agent-skills/ai-marketing-skills/) → `plg-strategist` + `funnel-architect`
6. [agentic-seo/SKILL.md](../../apps/agent-skills/agentic-seo/SKILL.md) → `tracking-engineer` (technical SEO depth)

The substrate measures which agents produce better outcomes — those paths harden; weaker agents get patched or dissolved. The improvement loop is what drives that ratchet.

---

## See also

- `plans/agent-template.md` — canonical template; every supported field with comments
- `plans/org-chart.md` — source spec for all agents (§4–§9), frameworks (§8, §11), handoff sequence (§12b)
- `plans/agent-skills-org-map.md` — downloaded repo map + install paths + key skills per repo
- `one.ie/agents/CLAUDE.md` — frontmatter contract + two consumers (sdk + AI SDK v6)
- `one.ie/agents/templates/` — role-specific starter examples (ceo, director, sales-discovery, support, moderator)
- `one.ie/agents/skills/` — 212 SKILL.md files (reference by `ref: <slug>` in agent `skills[]`)
- `one.ie/agents/cmo.md` + `one.ie/agents/copywriter.md` — live director + specialist patterns
- `plans/rubrics.md` — scoring bands (gate: ≥ 0.65)
