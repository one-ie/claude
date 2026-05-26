# Inventory — Agents · Skills · Commands across `Server/*`

Scan date: 2026-05-21 · Source: every `.claude/` under `/Users/toc/Server` (depth ≤ 4, excluding `node_modules` and `worktrees`).

## Totals

| Repo | Agents | Skills | Commands | Rules | Hooks |
|---|---:|---:|---:|---:|---:|
| `apps/agency-operator/` (Donal) | 8 | **133** (122 flat + 11 folders + 1 empty) | — | 15 | 1 |
| `apps/playbook/` | **91** | — | — | — | — |
| `apps/old.one.ie/` | 20 | 50 (5 flat + 45 in 11 agent-named folders) | 20 | — | 19 |
| `apps/one.ie.old/` | 20 | 50 | 20 | — | 19 |
| `apps/antsatwork/` | 11 | 16 (folders) | 38 | 4 | 4 |
| `apps/ants/` | 11 | 16 | 38 | 4 | 4 |
| `one-ie/` (this repo) | 4 | 23 (9 flat + 14 folders) | 15 | 7 | 9 |
| `apps/dev.one.ie/` | 4 | 24 | 10 | 5 | 6 |
| `apps/dave/` | 4 | 20 | 8 | 6 | 7 |
| `apps/agitrader/` | 5 | 14 | 8 | — | — |
| `apps/agent-launch-toolkit/` | — | 11 (1 flat + 10 folders) | — | 12 | — |
| `apps/text2typeql/` | 2 | 1 | — | — | — |
| `apps/pay/` | — | — | 2 | — | — |
| `apps/enoki-play/` | — | — | — | — | — |

> `one.ie.old/` and `apps/ants/` are exact mirrors of `old.one.ie/` and `antsatwork/`. Treat as duplicates.

---

## 1. `apps/agency-operator/` — Donal (Online Optimisers)

Marketing-agency operating brain. Heavy specialization in local-SEO, AEO/GEO, prospect audits, client onboarding.

### Agents (8)

| Name | Purpose |
|---|---|
| engineering-code-reviewer | Constructive code review — correctness, maintainability, security |
| engineering-codebase-onboarding-engineer | Traces source to onboard engineers; facts grounded in code |
| engineering-security-engineer | Threat model, vuln assessment, secure review, IR |
| marketing-agentic-search-optimizer | WebMCP readiness — can agents actually book/buy on the site |
| marketing-ai-citation-strategist | AEO/GEO across ChatGPT/Claude/Gemini/Perplexity |
| sales-discovery-coach | Discovery methodology, gap quantification |
| sales-proposal-strategist | RFP → win narrative, exec summary, positioning |
| _oo-shim-header | Shared OO-tuning header (not an agent) |

### Folder skills (11)

| Skill | Purpose |
|---|---|
| ai-audit-deep | Definitive AI-ranking audit (ChatGPT/Perplexity/Google AI) |
| client-strategy | 360° master strategy (SEO + AI + content + dev + ads + automation) |
| full-audit | Local-biz AI-visibility + technical SEO diagnostic |
| lead-brief | Warm-lead closing package (pre + post discovery) |
| lead-orb | Constellation-hub orb deployed to CF Pages |
| monthly-report | Styled retainer monthly SEO report |
| pbp | Mid-session play-by-play orientation |
| pre-call-brief | 1-2 page tactical brief before any call |
| presentation | Post-discovery HTML sales deck |
| vsl | Personalized prospect video + landing + email |
| claude-ads | (empty) |

### Flat skills (122) — grouped

- **Audits & QA (15):** ads-audit, audit-batch, audit-qa, brand-mcro-check, cro-check, eldar-seo-audit-pass, eldar-seo-tech-checklist, full-audit-deck, full-saas-audit, gbp-audit, prospect-screen, quick-audit, re-audit, report-qa, skill-audit
- **AI ranking / schema (9):** ai-backlink-plan, ai-content-gap, ai-evidence-pages, ai-keyword-gen, ai-prompt-bank, ai-ranking-implementation *(parked)*, ai-schema-build, schema-rollout, schema-validator
- **OpenAI Ads suite (8):** openai-ads-{brand-watch, competitor-watch, creative-brief, landing-audit, prompt-cluster, readiness, sdk-check, vs-organic-decision}
- **Citations / GBP / local (7):** citation-tracker, eldar-citation-build, eldar-local-dominator-roadmap, gmb-heatmap, internal-links, monthly-report-heatmap, niche-intel-refresh
- **Client lifecycle (10):** onboard, client-brief, client-content-pipeline, client-health, client-quarterly-review, client-update, daily-task-engine, niche-learnings, upsell-brief, voice-dump
- **Sales / proposals (9):** bland-cold-call, faq-deck, outreach-personalizer, portfolio-pitch, proposal-gen, sales-room, strat-hub, wedge-vault, thonty-brief-v2
- **Site build & deploy (11):** build-client-site, cloudflare, deploy-preview, hosting-cutover, qa-site, responsive-check, site-build, site-build-qa, site-project-pages, site-qa-loop, web-to-mobile
- **Content / social (12):** content-brief, content-update, keyword-cluster, social-caption, social-mega, social-metrics, social-post, social-repurpose, style-cloner, write-site-copy, yt-script, logo-gen
- **Intel system (7):** intel-brief, intel-extract, intel-monitor, intel-sample, intel-score, intel-sync, yt-learn
- **Council / thinking (5):** council, council-matrix, deep-thinking, persona-ingest, tool-bias-eval
- **Session ops (9):** start-here, sesh, pbp, park, reflect, wrap-up, sprint-dispatch, research-wave, token-tag
- **Scrapers (7):** amazon-chat-commerce-widget, amazon-fba-strategy, amazon-listing-scrape, meta-ad-library-scrape, tiktok-ad-scrape, google-ads-transparency-scrape, scrape-book
- **Backlink / off-site bursts (14):** article-promotion-burst, article-syndication-burst, blog-submission-burst, classified-ad-burst, directory-citation-build, infographic-syndication, micro-blog-promotion, micro-blog-syndication, pbn-build-plan, pbn-domain-vet, pbn-footprint-audit, reddit-soft-mention, social-bookmark-burst, visual-citation-build, web2-blog-promotion, backlink-disavow, domain-blacklist-check
- **Meta:** skill-author (reverse-engineer chats → skills), skill-audit (validate against rule 00)
- **Misc:** ad-factory, agent-mission-control, biz-evaluation, case-study-builder, chatbot-pilot-1-spec, course-distill, deck-diff, distill-status, format-sheet, ghl-workflows, n8n-workflow-builder, obsidian-export, pdf-resource-pitch, press-release-pitch, report-deliver, seo-roadmap, slideshare-repurpose, tomas-tracker-sync, video-distribution, local-services-3-month-roadmap, local-services-audit-pass

### Rules (15)
`00-meta-skill-authoring`, `01-orchestrator`, `02-client-data`, `03-security`, `04-seo-delivery`, `05-ai-ranking`, `06-output-style`, `07-cold-email`, `08-model-routing`, `09-competitor-filtering`, `10-build-locations`, `10-hosting-standard`, `11-domain-policy`, `12-no-auto-email`, `13-design-quality`

### Hooks
`check-em-dashes.sh`

---

## 2. `apps/playbook/` — ELEVATE Framework

E-commerce playbook authoring system. **91 agents**, no skills/commands.

Grouped:
- **Strategy & ops:** advertiser, marketing-director, creative-director, content-director, content-strategist, content-performance-analyst, marketing-technologist, marketing-automation, performance-marketer, conversion-optimizer, customer-journey-optimizer, lifecycle-marketer, retention-specialist, research-intelligence, analytics-expert, data-analyst, quality-auditor, builder, prompt-creator
- **Channel specialists:** affiliate-manager, amazon-specialist, b2b-specialist, bigcommerce-specialist, etsy-specialist, shopify-specialist, woocommerce-specialist, subscription-specialist, blockchain-specialist, voice-commerce-specialist, ar-vr-specialist, ai-specialist
- **Industry specialists:** beauty-, fashion-, food-beverage-, health-wellness-, home-goods-, sustainability-, tech-specialist, europe-market-, latam-market-
- **Content roles:** chapter, editor, elevate-chapter-generator, writer, copywriter, storyteller, blog-content-creator, newsletter-writer, podcast-producer, whitepaper-author, topical-authority-builder, keyword-research-specialist, seo-specialist, content-repurposing-specialist, content-asset-builder, case-study-specialist, documentation-specialist, interactive-content-creator, personalization-expert, social-media-creator, community-manager, user-generated-content-curator, video-content-creator, motion-graphics-designer
- **Design:** brand-designer, graphic-designer, illustration-artist, infographic-designer, web-designer, ui-ux-designer, print-designer, email-designer, product-photographer, social-media-designer, web-performance-expert
- **CRO/funnel:** advocacy-builder, customer-success-manager, customer-support-specialist, engage-specialist, foundation-builder, gift-creator, identify-optimizer, nurture-architect, optimization-specialist, sales-converter, stop-specialist, success-engineer, upsell-strategist, media-buyer, email-marketer

---

## 3. `apps/old.one.ie/` and `apps/one.ie.old/` — pre-substrate ONE platform

(Duplicates of each other.) Convex-era. Useful patterns to study, do not invoke directly.

### Agents (20)
agent-{backend, builder, claude, clean, clone, designer, director, documenter, frontend, integrator, lawyer, news, onboard, ontology, ops, problem-solver, quality, sales, writer} + TROUBLESHOOTING.

### Skills (50) — organised by agent
- `skills/{agent}/...` folders: `agents`, `astro` (5), `convex` (5), `deployment` (5), `design` (4), `documentation` (4), `integration` (4), `ontology` (5), `problem-solving` (4), `sales` (4), `testing` (4)
- Top-level: `agent-backend-create-mutation`, `agent-designer-create-wireframe`, `agent-frontend-create-page`, `INDEX`, `REGISTRY`

### Commands (20)
cascade, chat, commit, create, deploy, fast, mcp-on, media-upload, news, onboard, one, optimize, plan, push, release, review, server, start, test, validate

---

## 4. `apps/antsatwork/` and `apps/ants/` — Colony / stigmergic system

(Duplicates.)

### Agents (11)
agent-coordinator, colony-analyzer, colony-modeler, emergence-watcher, genome-evolver, pattern-crystallizer, performance-optimizer, schema-validator, security-auditor, test-generator, transfer-learning

### Skills (16, all folders)
caste-selector, cost-estimation, crystallization, dashboard, emergence-detection, genome-evolution, kangaroo-hunter, mission-manager, performance-profiling, pheromone-analyzer, security-analysis, slipstream-protection, transfer-learning, typedb, typeql-optimizer

### Commands (38)
actors, ants, audit, backup, colony-status, cost, crystallize, dao, dashboard, debug, delegate, deploy, emerge-loop, emerge-stop, emerge, emergence, evolve, gpu-loop, groups, grow, growth, health, hunt, learning, map, mission, model, pause, plan, queen, replay, security, spawn-ants, stan-cost, swarm, trails, transfer, world

---

## 5. `one-ie/` — current substrate (this repo)

### Agents (4)
`w1-recon`, `w2-decide`, `w3-edit`, `w4-verify` — the /do cycle.

### Skills (23)
- **Flat (9):** build, cloudflare, dev, oneie, perf, signal, sui, tutorial, typecheck
- **Folders (14):** ai-sdk, ai-ui, astro, react19, reactflow, shadcn, typedb, writer, youtube-subs (+ others)

### Commands (15)
browser, cc-connect, claw, close, create, deploy, do, do-autonomous, do-improve, do-intent, do-show, improve, release, see, sync

### Rules (7) · Hooks (9)
See `.claude/rules/` and `.claude/hooks/`.

---

## 6. `apps/dev.one.ie/` — Envelope System

### Agents (4) — same W1–W4 family as `one-ie/`
### Skills (24) — overlap with `one-ie/` + `better-auth`, `zklogin`
### Commands (10): claw, close, create, deploy, do, merge, release, see, sync, todo

---

## 7. `apps/dave/` — Envelope variant

Same W1–W4 agents · 20 skills (subset of `one-ie/`) · 8 commands (claw, close, create, deploy, do, release, see, sync).

---

## 8. `apps/agitrader/` — STAN trading system

### Agents (5)
data-analyst (Timescale + pandas), graph-builder (Memgraph/Cypher), indicator-builder, paper-trader (Hyperliquid), test-runner

### Skills (4 folders)
discretization, memgraph-operations, testing, timescale-query

### Commands (8)
check-graph, dashboard, run-tests, sequence, spec-check, status, task-status, trading-status

---

## 9. `apps/agent-launch-toolkit/` — Launch handoff

### Skills (11)
- Flat: `improve`
- Folders: alliance, build-agent, build-swarm, deploy, grow, market, status, todo, tokenize, welcome
### Rules (12)
Numbered governance for launch lifecycle.

---

## 10. `apps/text2typeql/`

### Agents (2): convert-query-runner, validate-syntax-findings
### Skills (1): convert-query

---

## 11. Empty / minimal

- `apps/pay/.claude/` — 2 commands only.
- `apps/enoki-play/.claude/` — empty.
- `Server/.claude/` — empty.

---

## Cross-repo themes

| Theme | Where it lives |
|---|---|
| W1–W4 /do cycle | `one-ie`, `dev.one.ie`, `dave` |
| Envelope System skills (astro, react19, shadcn, ai-ui, reactflow) | `one-ie`, `dev.one.ie`, `dave` |
| Stigmergic colony ops | `antsatwork` (= `ants`) |
| Convex-era platform | `old.one.ie` (= `one.ie.old`) |
| Agency operating brain | `agency-operator` |
| Trading systems | `agitrader` |
| TypeQL conversion | `text2typeql` |
| Launch handoff | `agent-launch-toolkit` |
| ELEVATE author swarm | `playbook` (91 agents) |

## Notable patterns to mine

- **Donal's `skill-author` + rule 00** — reverse-engineer chats into skills with validation.
- **Donal's progressive-disclosure folder skills** (`ai-audit-deep/SKILL.md` + `references/`) — pattern worth porting.
- **playbook's specialization tree** — 91 agents by industry/channel/role; opposite extreme from W1–W4's 4 agents.
- **antsatwork's command surface** (38) — heaviest CLI footprint; many are pure dashboards.
- **old.one.ie's agent-named skill folders** (`skills/{agent}/{task}.md`) — alternative to flat skills.
