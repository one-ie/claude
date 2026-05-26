# text/plan.md — pages for the agency-CEO PDF

**Source outline:** `text/contents.md`
**Persona (the only person we are writing to):** `text/persona-agency-owner.md` — Brad, named anchor. Read first; re-read between every page. **If a paragraph doesn't move Brad one notch closer to "I'll resell this," it's cut.** The persona doc carries Jobs-to-be-Done, Forces of Progress, StoryBrand, Dunford positioning, Hormozi value equation, the awareness ladder, the hopes/fears/dreams inventory, and the problem→ONE-feature grid. Treat it as binding.
**Reader path:** scan-first on screen, then printed to PDF and read end-to-end.
**Voice:** `.claude/product-marketing.md` (Anthony, fast/easy/simple, data rule).
**Craft:** `.claude/skills/writer/SKILL.md` — invoke on every page. The 7-step loop, the cut/show/structure passes, and the banned-words list are the procedure; this plan only adds the structural and source decisions on top.
**Worked example:** `text/speed.md` — already drafted to the bar this plan targets. Use it as the calibration reference for tone, paragraph density, headline rhythm, and the show-don't-tell rule. When in doubt about how a page should *feel*, re-read `speed.md`.
**Output:** one file per page, detailed but tight (see decision 6).

---

## Writing for Brad — the persona binding

Every page is written for one named person: **Brad** (the agency owner profiled in `text/persona-agency-owner.md`). The persona doc is the source of truth for *who reads this*; this plan is the source of truth for *what we say to him*. The mapping below is binding — when you draft a page, you also pick which persona elements it lands.

**On every page, name (at least) one of each:**
- One **push** (something Brad hates about the status quo — drawn from §3 of the persona doc)
- One **anxiety**, defused (drawn from the persona doc's anxiety list — usually via the page's "objections answered" block)
- One **pull** (the dream the page makes more believable — drawn from §3 pull / §6 dream outcome)
- One **job**, named (functional, emotional, social, or identity — see persona doc §2)

**On the PDF as a whole, all four job tiers must be covered:**
- *Functional jobs* (replace headcount, 90% margin, ship 50 clients) → §02 Agency, §09 Teams, §16 Speed
- *Emotional jobs* (stop being the bottleneck, stop apologising) → §05 Agents, §11 Analytics, §13 Learning
- *Social jobs* (be the agency peers copy) → §00 Cover, §02 Agency, §09 Teams
- *Identity jobs* (platform founder, not agency owner) → woven through every page; explicit in §02 and §13

**Per-page job table (binding spec — pulled from persona doc §12):**

| Page | The job Brad hires this page to do |
|------|------|
| 00 Cover | Land the dream outcome + the proof stack on page one. He should want to read on. |
| 01 Brand | Reassure: the platform disappears behind his brand. Cascade visible; we are not. |
| 02 Agency | Show the unit economics he was promised — credits, markup, distribute. £/$ math walked through. |
| 03 Chatbots | Prove surface area: every channel his clients' customers use. |
| 04 Models | Reassure: he isn't locked into one LLM vendor. Cost falls; he keeps margin. |
| 05 Agents | Hit the identity job: an agent is a markdown file; you own the IP. |
| 06 Skills | The dream of reusable IP that compounds. Show the marketplace shape. |
| 07 Tools | Defuse integration-sprawl anxiety; one server-side key. |
| 08 Memory | Hit the philosophical job: corpus = moat. The data is *his*. |
| 09 Teams | The closer. A £2M payroll, shipped the day the contract signs. |
| 10 Tracking | Justify the self-improvement claim. One inbox, every channel. |
| 11 Analytics | The monthly report. The artefact that wins every renewal call. |
| 12 CRM | One fewer seat to buy. Actors already are the CRM. |
| 13 Learning | The unrecoverable gap. Every quarter the moat deepens. |
| 14 Development | Reassure the technical partner (Donal): your engineers can extend this. |
| 15 Security | Defuse every compliance / lock-in fear in one page. |
| 16 Speed | Speed is the product. Match the value equation's time-delay lever. |

**Banned at Brad's awareness level** (Schwartz level 4 — product-aware, moving to most-aware). Allow no page to use these:
*AI-powered · cutting-edge · game-changer · transform your agency · empower your team · future-proof · seamless integration · in today's fast-paced world · reach out to learn more · trusted by leading brands · built by AI experts.*
Persona doc §13 is the canonical list; persona doc §14 has the sentences he *should* read.

**The objection ladder.** Every page that lists "objections answered" pulls from persona doc §10 (12 ranked objections). Don't invent new ones; the ladder is research output, not improvisation.

---

## Decisions made up front

1. **Headings normalized.** Every page is `h1` (page title) with `h2` sections. The outline in `contents.md` mixed `h1`/`h2`/`h3`; this plan flattens it so the PDF compiler doesn't choke on orphan levels.
2. **One cover page + 16 feature pages = 17 files.**
3. **Agency-first throughout.** Every page opens with what the agency operator gets — revenue, retention, defensibility, or margin — before the technical detail. Thesis line, same on every page: *fastest wins, through simplicity, which is why your clients stay.*
4. **Numbers or nothing — but the right kind of numbers.** Voice contract is non-negotiable: any claim without a number gets a `[stat: needs citation]` placeholder. But the *kind* of number matters more than the count.

   **Numbers a CEO cares about (use these):**
   - Money — revenue, margin, cost per conversation, credit cost per outcome, upside per client
   - Time — minutes to ship, days to first sale, weeks to break-even, seconds at the surface
   - Conversion — % lift, retention curve, churn, attach rate, response rate
   - Risk — uptime, incidents, who's accountable, what we accept
   - Scale — clients per agency, conversations per month, integrations
   - Comparison — 10× faster than X, half the cost of Y, beats Z on this benchmark

   **Numbers a CEO does NOT care about (avoid unless they directly anchor a money/time claim):**
   - Lines of code, runtime size in KB, internal architecture counts (loops, dimensions, verbs)
   - Cadence of internal background jobs ("L3 fade every 5 min")
   - Threshold values for internal triggers ("success-rate < 0.50 over ≥20 samples")
   - Token counts, model parameter sizes, embedding dimensions

   An engineer's trophy ("~670 LoC runtime") becomes a CEO line only when it ties to something they care about: *"The whole engine is small enough to read in an afternoon — which is why we ship features in days, not quarters, and why our prices keep falling."* The number serves the outcome; it isn't the outcome.

   When in doubt, ask: *would the CEO repeat this number to her CFO tomorrow?* If yes, keep it. If no, replace it with one she would.
5. **One quote max per page, sometimes two.** Set in a blockquote, attributed. Some pages skip the quote — that's fine. Primary source: `text/quotes.md` (8 parts, ~605 lines). Anthony's originals (Part VII) are first-class — use them first before reaching for external citations. The §Quote & stat bank below is a curated subset; always check `quotes.md` for a better fit. Two quotes per page is fine when one is a data citation and one is a philosophical closer; three is showing off.
6. **Length: exhaustive. This is a book, not a brochure.** Target ~**4500–7000 words per content page**. Cover page is the only exception (1000–1800 words — it sets the table for the rest). The PDF totals ~80,000–110,000 words: a full evening read, or a deliberate week of one-page-per-night for the CEO who wants to absorb it slowly. Every page is *standalone*: a CEO who reads only §07 Tools or only §09 Teams gets the full picture of that part of the business. That means each page repeats just enough context to stand alone, without becoming a summary of the whole PDF.

   **Density is the bar, not adjective count.** A page that finishes at 6000 words with every paragraph carrying its own number, scene, or objection beats a page at 1500 words with thin coverage. Depth comes from:

   - **Multiple worked examples** (3–5 per page) — different industry, different client size, different time horizon (week 1 vs month 3 vs year 1)
   - **Multiple objections answered** (5–8 per page) — every realistic CEO pushback, named in her words, answered in two-to-three sentences
   - **Side-by-side comparisons** — vs the status-quo (hiring), vs DIY (build your own stack), vs the obvious competitor (incumbent SaaS, OpenAI direct, etc.)
   - **Pricing math walked through** — show the calculation, not just the result; show the inputs, show the assumption, show the answer in £ and in % margin
   - **Failure modes** — what this *doesn't* solve, what it would be wrong to use it for, when to keep the human in the loop
   - **A "day in the life"** — narrative paragraph of the client CEO using or seeing this page's surface across a normal Tuesday
   - **Multiple code/config excerpts** (2–3 per page) — different angles on the same system (markdown spec, API call, dashboard view)
   - **FAQ block** at the end (5–10 Q&A pairs covering the questions a CEO will email back)
   - **Glossary / "what we mean when we say"** for any term that could mean different things to different readers
   - **Cross-references that go both ways** — every page links forward to 2 pages and back to 1, so the PDF reads as a network not a list

   The cut rule still applies: anything that doesn't carry weight goes. But "carries weight" now includes everything in the list above. **Padding is still death.** The test for every paragraph is: *does this carry a number, a scene, an objection, a comparison, a calculation, a failure mode, or a cross-reference the reader can't get elsewhere in the PDF?* If no, cut. If yes, keep — even at 6500 words.
7. **Billing is credits, resold.** The agency model is one line: *buy credits from us, distribute them to clients.* 1 credit = $0.0001 (owner-set, immutable per grant). Agency picks a markup % above the platform floor (5%), sets a default plan for new clients, and pours from their pool into client sub-pools. Source: `web/billing.md` (cascade + grants/pools/burn + gates). The Agency page (§02) explains the *flow* with this concrete model; specific markup numbers stay agency-discretion, but the credit unit, the floor, the cascade and the gate verbs (`on | metered | off`) are named.
8. **Composio is named once.** Page 07 (Tools) calls the underlying provider *"the connector layer"* in body copy, and adds one honest line: *"OAuth is relayed through a partner; the consent screen shows your brand."* No hiding, no marketing.

---

## File layout

```
text/
├── contents.md          ← original outline (source of truth for structure)
├── plan.md              ← this file
├── 00-cover.md          ← Build your AI Brand. Attract, convert, grow.
├── 01-brand.md          ← Build Your Brand
├── 02-agency.md         ← Build Your Agency
├── 03-chatbots.md       ← Chatbots
├── 04-models.md         ← Models
├── 05-agents.md         ← Agents
├── 06-skills.md         ← Skills
├── 07-tools.md          ← Tools
├── 08-memory.md         ← Memory
├── 09-teams.md          ← Teams (Marketing / Sales / Service)
├── 10-tracking.md       ← Tracking
├── 11-analytics.md      ← Analytics
├── 12-crm.md            ← CRM
├── 13-learning.md       ← Learning
├── 14-development.md    ← Development
├── 15-security.md       ← Security
└── 16-speed.md          ← Speed
```

Numbered prefixes lock PDF concatenation order (`cat text/[0-9]*.md > build/pages.md`).

---

## The page map

For each page: sections (h2s), source docs to crawl for substance, agency-CEO hook, required numbers, required artefacts (worked examples, tables, diagrams, code excerpts, objections answered), and suggested quote slot. The **required artefacts** are what create depth — without them a page collapses to under 2500 words and reads thin. Treat them as non-negotiable.

### Universal depth checklist (every content page)

Each non-cover page MUST include all of the following. None are optional. A page missing any of them fails W4.

- **8–12 concrete numbers** — every one passes the **CFO test** (Decision 4): money / time / conversion / risk / scale / comparison. Engineering trivia (lines of code, loop cadences, internal thresholds) doesn't count unless it directly anchors a money or time claim the CEO would repeat to her CFO.
- **3–5 worked examples** — different industry, different client size, different time horizon. Each named, dated, costed. *"Acme Agency × Brand X (DTC skincare, 12 staff): Mon — sign; Tue — launch; Fri — first sale; Month 3 — payback. Revenue: £42k. Substrate cost: £600. Margin: 98.6%."*
- **5–8 objections answered** — every realistic CEO pushback, named in her words, answered in 2–3 sentences. Cover at least: lock-in, data ownership, what-if-you-go-bust, why-not-DIY, why-not-OpenAI-direct, my-existing-vendor-already-does-this, what-about-compliance, what-about-my-team.
- **2–3 side-by-side comparisons** — vs the status quo (e.g. hiring humans), vs the obvious DIY path (e.g. wiring up the OpenAI API yourself), vs the incumbent competitor on this specific surface. Table or two-column block, named axes.
- **1 pricing-math walkthrough** — at least one calculation shown end-to-end with inputs, assumptions, and the £-and-%-margin answer. *"5M credits × $0.0001 = $500 wholesale. 20% markup. 50k credits per client × 10 clients = 500k credits sold at $0.00012 = $60. Substrate cost $50. Margin per client: $10/mo. At 30 clients, £3.6k/yr per client × 30 = £108k/yr ARR off a $500 spend."*
- **2–3 failure modes** — what this *doesn't* solve, what it would be wrong to use it for, when to keep the human in the loop. *"Don't use this for legal contract review without a human signoff. Don't use it for crisis comms in the first 24 hours of an incident."*
- **1 "day in the life"** — a narrative paragraph (4–8 sentences) of the client CEO encountering this page's surface across a normal Tuesday. Concrete, scened, time-stamped.
- **2–3 code or config excerpts** — different angles on the same system (markdown frontmatter / API call / config YAML / dashboard query / CLI invocation). Each ≤ 25 lines. Each captioned with one sentence on what it shows.
- **2 ASCII diagrams or tables** — at least one flow/architecture diagram and one comparison/decision table.
- **1 FAQ block** at the end — 5–10 Q&A pairs covering the questions a CEO will email back after reading. The Q is in her words, the A is two sentences.
- **1 glossary block** — *"What we mean when we say [term]"* for the 3–5 terms in this page that could mean different things to different readers. Each gloss is one sentence.
- **3 cross-references** — link forward to 2 pages and back to 1 page in this PDF. Use the page number and the one-sentence reason. *"See §13 Learning (p. 14) for how this compounds across a quarter."*
- **1 named integration / file path / route** — proof it's shipped, not slideware.

Pages that hit every item land at 4500–7000 words without padding. Pages that strain to hit them earn the longer word count by being denser. Pages that *can't* hit them probably shouldn't be in the PDF.

### 00 — Cover
- **Sections:** title block · one-paragraph thesis · the four-line proof (numbers) · master CTA · table of contents (one line per page, page number + the one sentence the CEO will remember from that page)
- **Sources:** `.claude/product-marketing.md` (thesis), root `ai-brand.md`, `one/one/goal.md`
- **Hook:** Resell an AI brand to every client. They never leave.
- **Numbers (CEO-grade):** 60s to your first chatbot · 5s checkout · $0.0001 per credit · one platform, every channel your client uses · 17 pages, every claim numbered
- **Required artefacts:** the four-line proof table (claim → number → page reference); the one-sentence-per-page TOC
- **Word budget:** 1000–1800 (exception to the universal 4500–7000 — cover sets the table, the rest of the PDF does the work)
- **Quote slot:** Naval — *"In a world of infinite supply, distribution is the only moat."*

### 01 — Build Your Brand
- **Sections:** Create in 60 seconds (the actual flow) · The 6-token design system (and why only 6) · Your domain (CNAME → verify → routed) · Embed anywhere (script tag, iframe, MCP, A2A) · What "your brand" actually means (UI + OAuth screen + invoice + emails) · The white-label cascade in practice
- **Sources:** root `ai-brand.md`, `web/agent-authoring.md`, `.claude/rules/design.md` (6 tokens), `one/one/theme-editor.md`, `web/src/middleware.ts`, `web/cascade.md`
- **Hook:** Your agency's brand on a substrate you don't have to operate. One brain, many faces.
- **Numbers:** 6 design tokens (background, foreground, font, primary, secondary, tertiary); 3 depth levels (page, card, content); WCAG AA contrast auto-enforced; custom apex via CNAME + verify; `acme.com/sales/quote` routes to your TypeDB Group in <10ms gateway; 5 invariant tokens (white, black, transparent, destructive, success); brand-fill auto-contrast labels (`on-primary`, `on-secondary`, `on-tertiary`)
- **Required artefacts:**
  - Code excerpt: the 6 CSS custom properties from `Layout.astro` (token source) — show the actual shape
  - Walkthrough: 60-second flow (open editor → pick colors → upload logo → enter domain → embed) with the click count at each step
  - Table: where your brand shows up (chat UI · invoice · OAuth consent · transactional email · status page · 404 page · favicon)
  - Diagram: CNAME → domain-verify → middleware match → TypeDB Group resolution
  - Objection: *"Can I match my client's existing brand pixel-perfectly?"* — answer with the 6-token boundary
- **Code refs:** `web/src/middleware.ts:55-72` (domain routing); `web/src/pages/api/themes/`; `.claude/rules/design.md` (design system enforcement at build time)
- **Quote slot:** Scott Cook — *"A brand is no longer what we tell the consumer it is — it is what consumers tell each other it is."*

### 02 — Build Your Agency
- **Sections:** The 4-tier cascade (owner → agency → client → end-user) · White-label cascade (what flips, what doesn't) · Buy credits, distribute to clients (the resell loop) · One field per audience (cascade as design tokens for billing) · Worked example: Acme Agency onboards Brand X · Gates: `on | metered | off` · What you keep (margin, data, contract) · What ships day one
- **Sources:** `web/roles.md`, `web/cascade.md`, `web/billing.md`, `web/billing-todo.md`, `web/_platform/billing.md`, root `ai-brand.md`
- **Hook:** Four roles (owner / agency / client / end-user). White-label cascade. Buy credits in bulk, distribute to clients, set your markup. Your clients never see us.
- **Numbers:** 4-tier roles; 1 credit = $0.0001 (owner-set, immutable per grant); platform margin 10% default, agency floor 5%; agency plan grant 5,000,000 credits; starter client default 50,000-credit grant; gates are three verbs (`on | metered | off`); per-model cost = `upstream_per_1k_in` × `output_mult` (opus-4-7: 1500 in × 5 output = 7500 credits per 1k output); billing anchor monthly per workspace; display currency UI-only (credits stay USD-anchored)
- **Required artefacts:**
  - Diagram: `owner → agency → client → end-user` with the one field each audience sets
  - Diagram: GRANT → POOL → BURN with GATE branch from `billing.md:12-18`
  - YAML excerpt: agency `billing.md` (plan, markup_pct, brand_lock, client_default_plan)
  - Worked example (numbers, not hand-wave): *Acme buys 5M credits at $500. Marks them up 20%. Day one signs Brand X at 50k starter grant. Brand X's bot answers 200 customer messages × 1500 credits = 300k burned. Acme's pool drops to 4.7M. Acme bills Brand X $60. Acme's margin: $54 on $6 of substrate.*
  - Table: what the agency sees vs. what the client sees vs. what the end-user sees on every surface (UI / invoice / OAuth / email / 404)
  - Objections answered: *"What if a client wants to leave?"* (data export, CLI command) · *"What if a client overuses?"* (metered gate kicks in at agency-set threshold) · *"What happens if I (the agency) stop paying?"* (pool drains; clients get a grace window; data stays)
- **CTA:** *See the agency tier and start with 5M credits.*
- **Quote slot:** Anthony O'Connell — *"If your competitive moat is a feature, you don't have a moat. If it's a relationship the customer can't replicate elsewhere, you do. AI is making this distinction obvious for the first time."* Alt: Jason Lemkin — *"Own the customer, rent the technology."* The page's argument is that ONE gives agencies the technology so they can focus entirely on owning the relationship. Both quotes serve that; Anthony's version names *why* the relationship is the moat.

### 03 — Chatbots
- **Sections:** Web (generative UI, what renders inline) · Messaging (Telegram · Discord · iMessage · WhatsApp roadmap) · Groups (multi-actor rooms) · Rich messages (payment card, map, form, code, image, file, claim button) · Streaming (token-by-token, first-token target) · The same brain across surfaces (one TypeDB Group, N channels)
- **Sources:** `web/chat-integrated.md`, `one/one/discord.md`, `one/one/telegram.md`, `web/groups.md`, `one/one/groups.md`, `one/one/ai-elements.md`, `one/one/rich-messages-todo.md`, `web/chat-lighthouse.md` (if exists)
- **Hook:** One agent. Every surface a client uses. Same brain, same memory.
- **Numbers:** /chat scores 100/100/100/100 Lighthouse (memory `project_chat_lighthouse.md`); streaming first token <300ms; supported channels (count from sources); rich-message types (count from `rich-messages-todo.md`); message dedup across channels via signal `id`
- **Required artefacts:**
  - Matrix: rows = channels (web / Telegram / Discord / iMessage / API / MCP), cols = features (streaming, rich messages, attachments, payments, voice, group, presence). Mark ✓ / metered / roadmap.
  - Code excerpt: a RichMessage payment card payload (`{type:'payment', payment:{receiver, amount, action:'claim'}}`)
  - Worked example: one customer sends "send me an invoice" in WhatsApp; agent recognises intent in TypeDB, emits a `payment` RichMessage, client clicks claim, Sui tx in 5s, agent confirms back in the same WhatsApp thread
  - Diagram: ingress channels → claw worker → ToolLoopAgent → TypeDB brain → response stream back
  - Objection: *"What about voice?"* — note the speech-input island, the latency budget, what's shipped vs roadmap
- **Quote slot:** Karpathy — *"The hottest new programming language is English."*

### 04 — Models
- **Sections:** Any model (the 300+ catalogue) · Why model choice is a product choice (cost / latency / quality triangle) · Per-agent vs per-skill model binding · The routing fallback chain (default → Groq → AI SDK Gateway) · BYOK and provider keys · How credits map to upstream cost · The 18-month price collapse (anchor data) · When to use Haiku vs Sonnet vs Opus vs open-weights
- **Sources:** `one/one/aisdk.md`, `web/agent-template.md`, repo `CLAUDE.md` (OpenRouter default, Groq opt-in, AI SDK Gateway fallback), `web/_platform/billing.md` (per-model credit cost)
- **Hook:** Pick the model per agent, per skill, per cost target. The platform doesn't lock you in — that's how you stay cheap as prices drop.
- **Numbers:** 300+ models via OpenRouter; per-model credit cost (haiku-4-5: 25 in × 5 out; opus-4-7: 1500 in × 5 out; gpt-5: 1250 in × 8 out); provider swap = one line in the agent markdown; Groq median time-to-first-token (cite from speed.md if measured)
- **Required artefacts:**
  - Code excerpt: the model line in an agent markdown header (`model: claude-haiku-4-5`)
  - 4-line ASCII routing diagram (default → Groq → fallback → degraded)
  - Table: 4 models × 4 axes (input cost per 1k credits, output multiplier, p50 TTFT, best-for use case)
  - Worked example: a sales agent that uses Haiku for triage, escalates to Sonnet for proposals, and Opus for one-shot contract review — show the credit cost per conversation
  - Objection: *"What if my favourite model gets deprecated?"* — model resolver, alias map, deprecation policy
- **Quote slot:** Anthony O'Connell — *"The companies that win this decade won't be the ones with the smartest models. They'll be the ones with the shortest distance between a customer's question and a useful answer."* Alt: Anthony — *"The cost of intelligence is collapsing. The cost of waiting is not."* Both are ONE's own lines — pick the one that fits the page's final beat.

### 05 — Agents
- **Sections:** What an agent is (a markdown file) · Anatomy of an agent.md (frontmatter, system prompt, skills, journey, sections, theme, ui) · How an agent learns (pheromone + prompt evolution) · The studio page (`/studio/[agent]`) · Editing an agent without redeploying · Versioning, signing, publishing · Markdown is the spec (IP-portable)
- **Sources:** `one/one/agents-how-they-work.md`, `one/one/agent-spec.md`, `web/agent-features.md`, `web/agent-authoring.md`, `web/agent-template.md`
- **Hook:** An agent is a markdown file. Edit the file, redeploy in seconds, the agency owns the IP.
- **Numbers (CEO-grade):** edit an agent in minutes (not a release cycle); agency owns the agent IP outright; one agent answers 24/7 (the equivalent of 150 human shifts); failing agents rewrite their own prompts after 20 bad outcomes — so quality compounds without engineering time
- **Required artefacts:**
  - Code excerpt: ~25 lines of a real agent markdown (sales.md or qualify-lead) with frontmatter + system prompt + one skill binding
  - Diagram: agent.md → CLI compile → published artifact (signed) → loaded by claw → registered in TypeDB
  - Table: the 4 outcomes and what each one does to pheromone (mark = strengthen, timeout = neutral, dissolved = warn 0.5, warn = weaken 1)
  - Worked example: an agent that fails 12 out of 20 lead-qualification calls; L5 evolution rewrites its system prompt; success rate climbs to 0.75 over the next 20
  - Objection: *"Why markdown — won't engineers want code?"* — the markdown→code path (CLI compile, IDE plugin, MCP-callable)
- **Quote slot:** Sam Altman — *"...a super-competent colleague that knows absolutely everything about my whole life, every email, every conversation I've ever had."*

### 06 — Skills
- **Sections:** What a skill does (a reusable capability) · The library (what ships) · Custom skills (author and publish) · Skill marketplace (sell to other agencies) · How skills earn pheromone (L4 economic loop) · Skill versioning and the dependency boundary · The eval loop (skill must pass to publish)
- **Sources:** `one/one/skills-implementation.md`, `one/one/skills-implementation-todo.md`, `web/skills/` (real examples), `cli/` (skill verbs: new/emit/publish/refresh/import/eval)
- **Hook:** Skills are reusable IP. Build once, sell to every client. The substrate tracks which skill earned which path the most revenue (loop L4).
- **Numbers:** real skills in repo — `qualify-lead`, `close-deal`, `draft-email`, `handle-complaint`, `escalate`, `headline-variants`, `brand-voice-check`; 6 CLI skill verbs; eval gate (cite threshold from skills-implementation.md)
- **Required artefacts:**
  - Table: 5 named skills × outcome × who earns the credit when they fire
  - Code excerpt: a skill frontmatter (`name`, `description`, `price`, `inputs`, trigger keywords)
  - Diagram: client triggers skill → agent calls it → outcome marked → L4 attributes revenue back to skill author
  - Worked example: an agency publishes a `brand-voice-check` skill; 12 client agents adopt it; the skill earns credits each time it fires; agency tracks per-skill revenue in the analytics dashboard
  - Objection: *"How do I stop a competitor copying my skill?"* — signing, publish + verify, attribution in the path metadata
- **Quote slot:** *(skip — let the skill list carry the page)*

### 07 — Tools
- **Sections:** Connect anything (the connector layer) · How your client's accounts stay theirs (per-user OAuth) · The 250+ surface (named: Gmail · Slack · GitHub · HubSpot · Linear · Notion · Calendar · Drive) · The white-label consent screen · Tool authorisation and approval gates · MCP as a second tool surface · What we add on top (substrate-aware tool wrapping)
- **Sources:** root `composio.md`, root `composio-todo.md`, `one/one/ai-tools.md`, `one/one/mcp.md`
- **Hook:** Your agents work *as the client*, with the client's own Gmail / Slack / GitHub / HubSpot / Linear. White-label OAuth screen says **your brand**.
- **Numbers:** 250+ integrations [verify against composio.md before draft]; one server-side API key, N user-scoped accounts; approval-gated substrate tools (count from claw/)
- **Required artefacts:**
  - Table: 10 named integrations × (read / write / streaming / webhook) coverage
  - Worked example: agent reads from client's Gmail, drafts a reply, posts to client's Slack with a `claim` button, client clicks once, reply sends
  - Code excerpt: the OAuth consent-screen template wording — *"Acme wants to access your Gmail"* — verbatim
  - Diagram: one server key → connector layer → N user-scoped accounts (one per client end-user)
  - Objection: *"What if a tool's API changes?"* — connector versioning, fallback behaviour, who maintains the adapter
- **Voice rule:** body copy calls it *"the connector layer."* One sentence acknowledges the OAuth relay (decision 8). Composio is not a brand we sell.
- **Quote slot:** Bill Gates — *"Agents are not only going to change how everyone interacts with computers. They're also going to upend the software industry."*

### 08 — Memory
- **Sections:** Types of memory (the actual taxonomy from `memory.md`) · Per-actor memory vs per-world memory · How memory accumulates (signal → trail → highway → hypothesis) · Crawling the web (ingest path) · Knowledge promotion (L6) · Forgetting (the fade loop, asymmetric decay) · The corpus is the moat
- **Sources:** `one/one/memory.md`, `one/one/agents-memory.md`, `one/one/world-memory.md`, `one/one/crawl.md`, `one/one/knowledge.md`
- **Hook:** Every conversation makes the next one better. The agency owns the corpus. Switching costs are real — your clients' data is the moat.
- **Numbers (CEO-grade):** every conversation makes the next one cheaper (fewer tokens, faster routing); the corpus is the agency's asset and stays with the agency if the client leaves; named memory types your client can audit; mistakes get forgotten 2× faster than wins — so a bad week doesn't reset a good year
- **Required artefacts:**
  - Table: memory types × where stored (TypeDB entity / D1 / KV) × who can read
  - Diagram: signal → trail → highway → hypothesis (the 4 stages of memory hardening)
  - Worked example: a customer-support agent learns over 6 weeks that complaints about "delivery delays" cluster with "weekend orders"; that pattern hardens into a hypothesis; on day 43 a new complaint triggers proactive routing — show the path strengths
  - Code excerpt: a crawl config (URL pattern, frequency, where ingested signals land)
  - Objection: *"Where is my client's data, legally?"* — TypeDB tenant boundary, export, deletion policy
- **Quote slot:** Anthony O'Connell — *"Every conversation with a customer either teaches your system or wastes it. There is no third option. Most companies are throwing away their best training data every single day."* Alt: Arie de Geus — *"The only sustainable competitive advantage is the ability to learn faster than your competition."* (Anthony's version is more specific to the memory product; de Geus works if the page leans corporate-strategy)

### 09 — Teams *(the page that closes the deal)*

This page reframes the pitch from "we ship chatbots" to "we ship **departments**." Every role on a real org chart becomes a markdown agent. The agency licence delivers three full-stack C-suite teams to every client on day one. The CEO doesn't buy software — she replaces a £1M payroll.

- **Sections:**
  - The dream marketing department (org chart + named agents)
  - The dream sales department (org chart + named agents)
  - The dream service department (org chart + named agents)
  - How the three teams hand off (signal routing across teams)
  - One human per team (Director-equivalent — the only human seat needed)
  - What this team would cost in headcount (the resale economics)
  - Voice training (week one — how the team learns the client's tone)
  - Adding a 4th team (R&D / Finance / Ops) — the pattern repeats
- **Sources:** `web/agents/sales.md`, `web/agents/support.md`, `web/agents/marketing-strategist.md`, `web/agents/ptcorp-sales.md`, `web/agents/ptcorp-service.md`, `web/agents/ptcorp-qualifier.md`, `agents/templates/`, `web/groups.md`
- **Hook:** Ship a C-level marketing, sales, and service department to every client on day one. Each agent reports up. The CEO talks to three Directors. The Directors run the teams.
- **Numbers (CFO-grade):**
  - Marketing department: ~10 specialist roles, £800k–£1.2M/yr in UK headcount, replaced by one licence
  - Sales department: ~8 roles, £600k–£900k/yr, replaced
  - Service department: ~7 roles, £400k–£600k/yr, replaced
  - Time-to-launch a campaign: hours (vs weeks for a hired team)
  - First-response time on tier-1 tickets: seconds (vs minutes-to-hours)
  - One human Director per team — the only seat the client still hires for
  - Total: a £2M payroll, available the day the contract signs
- **Required artefacts:**

  **Marketing org chart (ASCII, baked into the page):**

  ```
  CEO (the client — the only human at the top)
   └─ Marketing Director (agent — strategy, budget, OKRs, brand calls)
       ├─ Brand Manager        — voice, positioning, guideline enforcement
       ├─ Copywriter           — long-form, landing pages, emails
       ├─ SEO Lead             — keywords, technical audits, programmatic pages
       ├─ Advertising Manager  — paid acquisition strategy, creative briefs
       ├─ Media Buyer          — placements, budgets, rate negotiation
       ├─ Social Media Manager — posting calendar, engagement, DMs
       ├─ Designer             — assets, layouts, video cuts
       ├─ PR / Comms           — journalist outreach, press releases
       ├─ Email / Lifecycle    — drip campaigns, retention, win-back
       ├─ Events               — webinars, conference logistics
       └─ Marketing Analyst    — attribution, dashboards, weekly report up
  ```

  **Sales org chart:**

  ```
  CEO
   └─ Sales Director (agent — pipeline, forecast, deal review)
       ├─ SDR / Qualifier       — inbound triage, BANT, booking
       ├─ Outbound Rep          — cold sequences, follow-up
       ├─ Account Executive     — discovery, demo, proposal
       ├─ Solutions Engineer    — technical questions, scoping
       ├─ Deal Desk             — pricing, contracts, approvals
       ├─ Customer Success Lead — onboarding, expansion, renewals
       └─ Sales Analyst         — pipeline health, conversion, weekly report up
  ```

  **Service org chart:**

  ```
  CEO
   └─ Service Director (agent — SLAs, escalation policy, CSAT)
       ├─ Tier-1 Support        — FAQs, password resets, refunds
       ├─ Tier-2 Specialist     — diagnosis, workarounds
       ├─ Onboarding Agent      — setup, training, first-value
       ├─ Complaint Handler     — de-escalation, root cause
       ├─ Knowledge Curator     — docs, FAQs, knowledge base hygiene
       └─ Service Analyst       — CSAT, ticket trends, weekly report up
  ```

  - **Code excerpt:** ~20 lines from `marketing-director.md` showing `reports_to: ceo`, `manages: [brand-manager, copywriter, seo-lead, …]`, one delegation skill, one approval-threshold gate
  - **Worked example (Acme Agency × Brand X, week one):**
    - *Mon 09:00* — Brand X signs. Marketing Director onboards: reads the brand guidelines, ingests the existing site, briefs the Copywriter and Designer.
    - *Tue 14:00* — Director briefs Advertising Manager on a launch campaign. Copywriter drafts five variants. Designer cuts three creatives. SEO Lead drafts the landing page.
    - *Wed 10:00* — Director approves the brief. Media Buyer places £2k of test spend across two channels. Social Media Manager schedules supporting posts.
    - *Thu* — campaign live. Marketing Analyst feeds CPL and CTR back to Director. Director shifts £500 from the worse channel to the better one.
    - *Fri 17:00* — Director's weekly summary lands in the human CMO's inbox: 12 minutes to read, 3 decisions to approve. The CMO never wrote a brief, never opened the ad platform, never wrote a line of copy.
  - **Cross-team handoff diagram:** lead arrives → Marketing's SEO/Ads capture → Marketing Director hands to Sales SDR → Account Executive closes → Service Director onboards → Customer Success owns the relationship. Signals on every arrow; pheromone strengthens the highest-conversion paths quarter over quarter.
  - **Headcount-cost table:** 3 columns (role · UK median salary · agent equivalent shipped). 27 rows across the three teams. Total at the bottom: ~£2M/yr in payroll, available immediately, scaling to N clients without rehiring.
  - **Objections answered:**
    - *"This replaces my marketing team — what's left for humans?"* Humans set strategy and approve spend over the agency-defined threshold (default £1k). Agents execute and report. One CMO now manages a team of 10 instead of running one.
    - *"My client wants a real human writing their tweets."* Configure: the Social Media Manager agent drafts; a human approves before post. One human approves ~150 posts/week in 30 minutes. The bottleneck stops being talent; it becomes attention.
    - *"What if I want to swap one specialist for a different one?"* Edit the markdown. Redeploy. Done.
    - *"Do agents really report up?"* Yes — `reports_to` is a frontmatter field. The Director receives the team's daily roll-up signal, makes calls, sends weekly summary up. See §05 Agents for the spec.
  - **Cross-references:** §05 Agents (markdown spec, `reports_to` field) · §06 Skills (the per-role skill packs) · §08 Memory (per-team shared memory) · §13 Learning (how the org chart's paths harden quarter over quarter)
- **Word count target:** top of the band (6500–7000) — this is the closer page, it earns every word. If Opus exceeds 8000 after polish, split into 09-marketing / 09-sales / 09-service (~5000 words each) and bump the PDF to 19 pages.
- **Quote slot:** Versaunt (Oct 2025) — *"Marketers will move from manually tweaking campaigns to overseeing intelligent systems that continuously learn, adapt, and optimize."* — earns its place here because it names the *exact* shift the dream-team page is selling. Skip only if the page already runs long.

### 10 — Tracking *(why the teams in §09 keep getting better)*

The teams keep getting better only because every conversation, on every channel, lands in one inbox. That's the whole page. Three lines for the CEO:

1. **One inbox, every channel.** WhatsApp, Discord, Telegram, iMessage, web chat, email — all into one place. No integration project.
2. **One customer across every channel.** The person who DM'd on WhatsApp this morning is the person who posted in your Discord last week. One record, every channel.
3. **Every outcome lands on the conversation that earned it.** Payments, refunds, replies, silences — all attached to the conversation that produced them. The team learns from receipts, not from opinions.

That third line is the point. Self-improvement isn't magic; it's bookkeeping. The substrate keeps the books so the teams in §09 can read them. Without §10, the rest of this PDF is marketing. With §10, the rest of this PDF is a query.

- **Sections:**
  - One inbox, every channel
  - The same customer everywhere
  - The unified inbox in practice (a Tuesday morning trace)
  - Every claim is drillable to the conversation that earned it
  - What gets tracked, what doesn't
  - Who sees what (the agency · the client · the customer)
  - Why your client can't get this from HubSpot, Segment, or GA4
- **Sources:** `web/tracking.md`, `web/tracking-realtime.md`, `web/tracking-todo.md`, `web/tracking-page-text.md`, `one/one/signals.md`, `one/one/events.md`
- **Hook:** Every conversation your client's customers have — on every channel — lands in one inbox. The agency reports to its clients with receipts, not screenshots. The teams in §09 keep getting better because every outcome lands on the conversation that earned it.
- **Numbers (CEO-grade):** every channel the client uses, in one feed; zero new integrations to add another channel; one record per customer no matter how they reached you; conversations kept for the life of the contract; every number in the monthly report is one click from the conversation that produced it
- **Required artefacts:**
  - **The unified-inbox story — Sara orders a kettle on Tuesday morning:**

    *Sara DMs the client's WhatsApp: "Is the silver kettle in stock?"*

    The substrate recognises Sara from her phone number. She's the same person who posted a question in the client's Discord community last week and looked at the product page on the site yesterday. No tickets so far — she's an active prospect.

    The conversation routes to the sales qualifier. Inventory: two in stock. The qualifier drafts a reply in the client's brand voice and sends it on WhatsApp. The same reply mirrors into the agency's Discord *#sales-live* room so the human team can see it.

    *Sara replies: "great, link me."* The qualifier sends a payment link. Sara pays in 47 seconds.

    Three things just happened. The agency wrote zero integration code. Marketing, Sales, and Service are looking at the same Sara — same record, same history. And the route from "WhatsApp question" to "paid in 47s" now has evidence attached to it; next time a customer like Sara messages, the substrate sends them down that same route first. That is the loop closing.
  - **Channel coverage table:** rows = channels (WhatsApp · Discord · Telegram · iMessage · web · email · API · MCP · CLI), cols = (inbound · outbound · group rooms · attachments · payments · presence · rich messages). Mark each cell shipped / metered / roadmap.
  - **Side-by-side comparison:** one inbox vs. the stitch-it-yourself stack (separate chat platform + separate analytics + separate CRM + a per-channel API connector). Axes: tools the client pays for · integrations the agency maintains · whether the same customer appears in every tool · who owns the data · time to add a new channel.
  - **Pricing math:** mid-size client, 50k inbound conversations a month across five channels. With ONE the conversation cost is folded into the credit price from §02. The stitched stack adds £X/month in licences plus engineering hours to keep it together. Show the cash delta over a year and the agency margin on it.
  - **Day-in-the-life:** *Tuesday, 10:14 — the agency's account lead opens Brand X's inbox. 142 conversations in the last hour: 38 WhatsApp, 22 Discord, 41 web, 12 email, the rest internal. The "first message to first payment" board shows three closes since coffee. She clicks one — sees the customer, the WhatsApp thread, the payment receipt — screenshots it for Friday's review and gets on with her morning. The CMO at Brand X doesn't open this view. She doesn't need to.*
  - **The receipts table — what makes §11's monthly report possible:**

    | Question the client asks | What the receipt looks like |
    |---|---|
    | "Where did this revenue come from?" | The list of conversations, ranked, with the channel and the team that closed each. |
    | "Why did we lose this one?" | The conversation thread, the point where it went sideways, the agent that handled it. |
    | "Which campaign drove this week's growth?" | Every closed deal traced back to the marketing touch that started it. |
    | "Did our brand voice survive?" | Every outbound message scored against the client's voice contract, with the misses listed. |
  - **Objections answered:**
    - *"Isn't this just analytics?"* No. Analytics tells you what happened last week. The substrate decides what to do next — which path to send the next customer down — based on what just worked. Reading the dashboard and improving the product are the same loop.
    - *"Can my client keep their existing tools?"* Yes. Send their data in, read ours out. Once the client sees the whole customer in one place, the older tools become reports rather than sources of truth.
    - *"What about GDPR?"* Per-client data stays in a per-client space. Personal details are kept only where they have to be. Customers can request deletion in one command. Full threat model in §15.
    - *"Won't 50,000 conversations a month overwhelm me?"* The inbox summarises by route; the live feed is for drilling, not staring. Anything not in active use fades from the surface within hours.
    - *"What if a customer messages on a channel you don't support?"* The agency adds a short markdown file for the channel and it's live the same day. Adding a channel is closer to filing paperwork than writing code.
  - **Failure modes:** the substrate can only see what reaches it. It does not attribute revenue to a billboard a customer saw before they messaged. It does not read private channels the client hasn't connected. It does not track customers who opt out — that flag is honoured at the door.
  - **Cross-references:** §03 Chatbots (the channels themselves) · §09 Teams (who handles the conversations) · §11 Analytics (the monthly report this makes possible) · §12 CRM (the customer record this populates) · §13 Learning (how the loop closes) · §15 Security (where the data lives and who can read it)
  - **Named integration / file path / route:** `web/tracking.md` · `web/tracking-realtime.md` (live feed) · `web/tracking-todo.md` (roadmap)
- **FAQ block:**
  - *Q: Do you track every click on my client's site?* A: Every click inside the chat and any embedded substrate widget. Tracking on the rest of the site is opt-in.
  - *Q: Where does the data live?* A: In a space dedicated to that client, on Cloudflare's edge, in the region you pick.
  - *Q: Can a client export everything?* A: Yes — one command. They get the whole inbox and customer history as portable files.
  - *Q: Can I switch tracking off for one customer?* A: Yes — per-customer flag, honoured at the door.
  - *Q: How is this different from Mixpanel?* A: Mixpanel reports on yesterday. The substrate decides about tomorrow.
- **Glossary block:**
  - *Conversation* — a thread between a customer and your client, on any channel.
  - *Record* — one row per customer, no matter how many channels they used.
  - *Receipts* — the trail from a number on the report to the actual conversation that produced it. Always one click away.
  - *Route* — the path a winning conversation took (channel, team, decisions). The substrate strengthens routes that worked and weakens routes that didn't.
- **Quote slot:** John Boyd — *"The way to win is to compress the loop."* Alt: *"The cost of intelligence is collapsing. The cost of latency is not."* (ONE's own line — fits because the page argues measurement is the latency that matters most.)

### 11 — Analytics *(the report the agency sends every month — and the dashboard the client opens any time)*

§10 captures everything. §11 turns it into one page the agency CEO sends her client every month, and one dashboard the client opens whenever she wants. Both white-labelled. Both built from the same record §09's teams already work in, so there is no second pipeline to maintain. Looking at the numbers and improving the work are the same act — because the dashboard reads the same evidence the teams use to decide what to do next.

- **Sections:**
  - The monthly client report — one page, every line drillable
  - The live dashboard — what your client opens any time
  - What you measure (revenue per team, revenue per campaign, retention, voice consistency, the four-axis rubric)
  - From a number to the conversation that earned it — one click
  - Cohort and channel views without a data team
  - Why the dashboard is also the improvement engine
  - Export to your client's BI tool
- **Sources:** `web/agent-analytics.md`, `web/agent-analytics-page-text.md`, `web/agent-analytics-todo.md`, `one/one/learnings.md`
- **Hook:** A one-page monthly report the agency CEO sends. A live dashboard her client opens any time. Every number on both is one click from the conversation that produced it — and every number is the same number the teams in §09 use to decide what to do next.
- **Numbers (CEO-grade):** the monthly report ships in under a minute from one click; live dashboard refreshes in seconds; every number drillable to the conversation behind it; revenue reported as cash by team, campaign, channel, and skill; the four-axis quality score (security · stability · simplicity · speed) shown to the client, not hidden from her
- **Required artefacts:**
  - **The monthly client report — exact shape (the artefact that wins the renewal):**

    | Block | What's in it |
    |---|---|
    | Revenue | Per campaign · per team · per channel · per skill — in cash. |
    | Pipeline | First message to first payment, with the drop-off points named. |
    | Retention | Customer satisfaction trend, ticket volume, time-to-resolution shortening over time. |
    | Learning | The agents that improved this month, the routes that hardened into reliable defaults, the new questions customers started asking. |
    | Quality | Four scores — security · stability · simplicity · speed — published to the client, not hidden. |
    | One CTA | The single change the agency recommends for next month, backed by the numbers above. |

    One page. Receipts on every line. The client can drill any number to the conversation that caused it.
  - **The renewal moment (worked example):** the agency runs the monthly report for Brand X. The "revenue per skill" view shows the brand-voice-check skill — built by the agency, sold to the client — earned £840 of margin in week three without a human touching it. The conversation with the client is no longer "what did you do for us this month?" It's "this skill we built for you earned £X. We're raising the price."
  - **The drill-down (worked example):** the client's CMO sees "WhatsApp closed 73% of presale questions" on the dashboard. She clicks the number. She sees the 47 conversations that produced it. She clicks one. She sees the customer, the conversation, the team that handled it, the payment receipt. Total clicks: three. No SQL, no data team, no support ticket.
  - **Day-in-the-life:** *Friday, 16:45 — Acme Agency's CEO clicks "Generate monthly report" for Brand X. PDF in four seconds, in Brand X's colours. She skims the one-line recommendation, reads the revenue-per-skill block twice (brand-voice-check earned £840 of margin without a human touching it), forwards it to her account lead with one line: "Raise the price on this in Q3." Whole cycle: 90 seconds.*
  - **Side-by-side comparison:** the substrate-native dashboard vs. the stitched stack (CRM pipeline + analytics tool + manual queries + monthly slide deck). Axes: time to produce the monthly report · drillable to the source · same numbers the optimisation engine reads · agency margin · white-labelling.
  - **Reports table:** 6 standard reports × what question each answers × where in the substrate the answer comes from.
  - **Objections answered:**
    - *"My client wants their own BI tool."* Send the data out on a schedule; the substrate is still the source of truth. The BI tool becomes a second view.
    - *"How do I know the numbers are right?"* Every metric is one click from the underlying conversation. If a number ever looks wrong, you can see exactly which conversation produced it. The audit is the product.
    - *"Doesn't every vendor say 'self-optimising'?"* They don't show you what's improving. This page does — the agents that evolved, the routes that hardened, the new questions customers started asking. The dashboard is the improvement engine's read-out.
    - *"Does my client see the same view as my account team?"* Yes by default. The cascade in §02 controls what each tier sees; the client gets the brand-side view, the agency gets the operations view, the platform stays invisible.
    - *"What about the quality scores — won't a client see a low number and panic?"* Anything below the quality gate doesn't ship in the first place. The published score is the score *of what's live*. If the client wants the gate raised, that's a conversation worth having.
  - **Failure modes:** the dashboard does not predict the future, does not replace a strategy conversation, does not tell the agency *why* a route worked. It shows *that* it did and supplies the audit trail. The "why" is a human conversation, supported by evidence.
  - **Cross-references:** §02 Agency (who sees what — the cascade) · §10 Tracking (the conversations underneath) · §13 Learning (where the improvement happens) · §06 Skills (revenue-per-skill credit).
  - **Named integration / file path / route:** `web/agent-analytics.md` (current dashboard) · `web/agent-analytics-todo.md` (roadmap shipped) · the quality score definition in `one/rubrics.md`.
- **FAQ block:**
  - *Q: Is the dashboard live?* A: Live for the moving parts (active conversations, today's closes); near-live for everything else (refresh in seconds); monthly for the report.
  - *Q: Can my client schedule the report?* A: Yes — monthly, weekly, on demand, or when a number crosses a threshold she sets.
  - *Q: Who owns the export?* A: The agency. Cascade applies — the client sees what you let her see; the platform stays out of view.
  - *Q: What about a board-deck format?* A: One PDF, one chart image, one CSV. Boards like all three.
- **Glossary block:**
  - *Receipts* — the trail from any number on the report to the conversation that produced it. One click.
  - *Quality score* — the four-axis number (security · stability · simplicity · speed) published with everything that ships.
  - *Self-optimising* — the numbers the dashboard shows are the same numbers the teams in §09 use to decide what to do next. Reading and improving are one act.
- **Quote slot:** Versaunt (Oct 2025) — *"Campaigns are not just optimized — they are self-optimizing, constantly seeking the event horizon of maximum performance."* Alt: Greg Linden (Amazon) — *"Every 100ms of latency cost us 1% in sales."* if the page leans more on speed-to-revenue than self-optimisation.

### 12 — CRM
- **Sections:** Actors as records (no separate CRM seat) · Conversations as history (auto-logged) · The pipeline writes itself · Stage transitions (signal-driven, not manual) · Enrichment (from public sources + tool integrations) · Handoff to human (when and how) · Importing an existing CRM
- **Sources:** `web/crm.md`, `web/crm-pages.md`, `web/crm-todo.md`
- **Hook:** No separate CRM seat per client. The substrate's *actors* dimension already is the CRM — and the agents already log every conversation.
- **Numbers:** actor type count from schema; shipped CRM endpoints (cite recent commits — `feat: CRM surface — actors pages, API endpoints, lib + components`); enrichment fields per actor
- **Required artefacts:**
  - Diagram: actor → conversation → deal → outcome (3-line flow with signals on each arrow)
  - Table: 6 standard CRM verbs (capture, qualify, contact, propose, close, retain) × which agent owns × which signal fires
  - Worked example: a lead opens the chat; agent captures email; TypeDB upserts the actor; conversation logs as signals; on "send me a proposal" the deal record auto-creates; on payment the outcome marks the path
  - Code excerpt: the actor query shape (REST or TQL) from `web/crm.md`
  - Objection: *"My agency already uses HubSpot — am I migrating?"* — bidirectional sync, write-through path, when to keep both
- **Quote slot:** Anthony O'Connell — *"Your CRM is a graveyard of intent. It tells you who showed up and what they bought. It doesn't tell you what they nearly bought, what made them hesitate, or what they wish you sold. AI changes that — if you let it listen."*

### 13 — Learning
- **Sections:** Pheromone (paths that strengthen with each successful outcome) · The 7 loops in plain English · Asymmetric fade (good is sticky, bad forgives) · Self-improving prompts (L5 evolution) · Knowledge (L6 — what hardened into a hypothesis) · Frontier (L7 — unexplored tag clusters) · Why your clients' chatbots get smarter than the competition · The unrecoverable gap
- **Sources:** `one/one/learnings.md`, `one/one/routing.md` (L1–L7 loops), `one/one/evaluate.md`, `one/one/knowledge.md`, `.claude/rules/engine.md`
- **Hook:** Other vendors ship the same chatbot to everyone. Yours gets smarter on your clients' data. Quarter over quarter, the gap is unrecoverable.
- **Numbers (CEO-grade):** week 1 vs week 12 — same client query, the agent routes differently because the path hardened; the gap between you and a competitor on the same client grows quarter over quarter; agents that fail too often rewrite themselves automatically (no engineer needed); your client's data is the moat — the competitor can copy the model, not the corpus
- **Required artefacts:**
  - Table: L1–L7 reproduced verbatim (cadence × what it does)
  - Diagram: signal → trail → fade → knowledge → frontier (full lifecycle, one signal's journey over a quarter)
  - Worked example: Brand X's agent at week 1 vs week 12 — same query, different routing — show the path strengths that diverged
  - Code excerpt: one `mark()` and one `warn()` call from `engine.md`
  - Objection: *"Couldn't a competitor catch up by training on the same data?"* — the data is the client's; the paths are agency-owned; switching cost is the corpus
- **Quote slot:** Anthony O'Connell — *"The cheapest thing to copy is what you sell. The hardest thing to copy is how you learn. Build the second one and the first one stops mattering."* Alt (if the page leans AGI-framing): Hassabis — *"Continual learning — the ability to learn in every new moment, as humans do — is one of the bottlenecks on the path to AGI."* Anthony's version is more agency-commercial; Hassabis gives it weight when the reader needs a scientist to confirm what ONE has already built.

### 14 — Development
- **Sections:** Build (chat / markdown / IDE) · Call (CLI · API · SDK · MCP) · Spec (ADL · Ontology · DSL · Dictionary) · Verb-surface parity (every action reachable from every surface) · The 15 CLI verbs · The MCP server surface · The SDK shape · Deploy in 3 commands · Local dev (`oneie dev`)
- **Sources:** `one/one/cli-reference.md`, `one/one/sdk.md`, `one/one/api.md`, `one/one/mcp.md`, `one/one/adl-integration.md`, `one/one/dsl.md`, `one/one/one-ontology.md`, `one/one/dictionary.md`, `one/one/create-websites-with-chat.md`
- **Hook:** Your engineers, your IDE. Or: your CEO and Claude. Same substrate. Verb-surface parity (memory: `feedback_verb_surface_parity.md`) — every action reachable from every surface.
- **Numbers (CEO-grade):** deploy a client in three commands; same action works from chat, CLI, IDE, or MCP — your team picks the surface; one Python team and one TypeScript team build on the same substrate; no platform lock-in (CLI export, SDK is MIT)
- **Required artefacts:**
  - 3-column matrix: build (chat / markdown / IDE) × call (CLI / API / SDK / MCP) × spec (ADL / Ontology / DSL / Dictionary), one example each
  - Code excerpt: the same operation 4 ways — CLI command, curl API call, SDK call, MCP tool call (one screen, side-by-side)
  - Diagram: developer surfaces → @oneie/sdk → api.one.ie → substrate
  - Worked example: a developer at the agency adds a new skill in their IDE, runs `oneie skill publish`, sees it appear in every client's chat within 30 seconds
  - Objection: *"My team uses Python."* — Python package, uAgents protocol, OpenRouter client
- **Quote slot:** Alan Kay — *"The best way to predict the future is to invent it."*

### 15 — Security
- **Sections:** You own your keys (passkey + Secure Enclave) · The 5 wallet states · Compliance (SOC2 / GDPR / EU AI Act — what we accept, what we delegate) · The threat model is a table · No passwords, no seed phrases · BIP39 paper break-glass · Per-tenant data isolation · Pen-test cadence · Incident response
- **Sources:** `one/one/SECURITY.md`, root `../passkeys.md`, root `../mac.md`, root `../agents.md`, root `../secrets.md`
- **Hook:** No password resets. No seed phrases. Secure Enclave + Touch ID. Compliance shrinks when there's nothing to leak.
- **Numbers:** 5 wallet states (name them); Apple Secure Enclave; every transaction signed; BIP39 break-glass; quarterly canary-tx verification cadence; 4 agent patterns (co-sign / scoped / capability / peer)
- **Required artefacts:**
  - Threat-model table: 6+ rows of (attack / defense / accepted risk) — format from `../mac.md`
  - Table: the 5 wallet states with the transition trigger between each
  - Diagram: Secure Enclave → passkey → biometric → signature → Sui tx
  - Worked example: an end-user clicks "claim payment", Touch ID prompts, transaction signs in <5s, no password ever entered
  - Objection: *"What about lost-device recovery?"* — BIP39 paper, recovery flow, two-root verification
- **Note:** the root *.md security docs live in `/Users/toc/Server/` — one level up from the repo. Cite paths as `../mac.md` etc.
- **Quote slot:** *(skip — the threat-model table is the proof)*

### 16 — Speed  *(DRAFT EXISTS — `text/speed.md`)*

> The current `text/speed.md` is the worked example for tone and density across the whole PDF. Treat it as the calibration target; on the writing pass it gets renamed/moved to `16-speed.md` and run through the rubric like every other page.

- **Sections:** Page · Inference · Build · Deploy · Wallet · Checkout
- **Sources:** `.claude/product-marketing.md` (the speed table), `one/one/speed.md`, `one/one/lighthouse.md`, `one/one/speed-chat.md`
- **Hook:** Speed is the product. Every 100ms costs 7% of conversions (Akamai, 2017). We measure six surfaces; the numbers below are live.
- **Numbers:** the full table from `product-marketing.md` — FCP/LCP/INP sub-1s, first token <300ms, hot reload <100ms, deploy seconds, 5s wallet, 60s checkout, 1min TTFAPIC, 3min time-to-value.
- **Quote slot (open):** Dave Girouard — *"Speed is the ultimate weapon in business. All else being equal, the fastest company in any market will win."*
- **Quote slot (close):** Anthony O'Connell — *"We were told AI would replace people. What it's really doing is replacing the parts of work that were never worth doing in the first place. The question isn't what AI takes from us. It's what we finally get to do with the time it gives back."* — the Speed page is the last page; this is the last thought the CEO carries out.
- **Closing line of the PDF:** *Whoever is fastest wins. The way to be fastest is to remove friction. The way to remove friction is power through simplicity.*

---

## Source hierarchy

Every page draws from three tiers. Use them in order — primary first, secondary only when the primary is thin.

| Tier | Path | Role |
|------|------|------|
| **Primary** | `one-ie/one/` (this repo) | Source of truth. Spec docs, canonical copy, verified numbers. Always read this first. |
| **Secondary A** | `/Users/toc/Server/one.ie/` | Live product codebase. Richer implementation detail, real route/component names, shipped feature descriptions. Use when primary is thin. |
| **Secondary B** | `/Users/toc/Server/one-ie/dev.one.ie/` | Dev branch. More exploratory docs, speed benchmarks, agent-economics breakdowns, alternative framings. Use for colour and numbers the primary hasn't locked. |

**When starting any page that needs secondary sources, spawn a Haiku agent** with a prompt like:

```
List all .md files under /Users/toc/Server/one.ie/
and /Users/toc/Server/one-ie/dev.one.ie/
(skip node_modules, .git, dist, .astro).
Group by subdirectory. Paths only, one per line.
Then read and return the contents of any files
relevant to: [page topic].
```

Haiku is fast and cheap for this indexing pass. Don't read secondary sources yourself until Haiku has returned the file list and surfaced what's relevant.

**Precedence rule:** if a number or claim exists in the primary and contradicts a secondary, the primary wins. If the secondary has a number the primary lacks, cite it with the path so it can be verified later.

---

## Per-page writing procedure

Each `text/NN-name.md` runs the **writer skill's 7-step core loop** (`SKILL.md:14-26`). This plan binds the variables; the skill carries the craft.

**Step 0 — Audience, medium, goal (writer SKILL.md:30-39).** Locked once for the whole PDF:
- *Audience:* agency CEO evaluating reselling ONE. Knows marketing economics. Skim-reads on screen, then prints the PDF and reads end-to-end. Speaks plain English; tolerates one technical term per page if it earns its place.
- *Medium:* one printable page in a 17-page PDF. ~800–1500 words. No interactivity.
- *Mode:* persuasive + technical-credible. Show, don't tell. Numbers do the persuading.
- *Goal:* move the CEO one notch closer to "I'll resell this." Not "I understand it" — *"I'll resell it."*

**Step 1 — Read sources (before drafting).** Open every primary source in the page's source list. If thin, spawn Haiku per the source hierarchy. Pull concrete numbers, named features, file paths, snippets. Then re-read `text/speed.md` to recalibrate the tone for this PDF.

**Step 2 — Draft fast (SKILL.md:43-50).** Lead with the strongest sentence for the agency CEO — almost always an economic outcome ("Your clients never leave", "Buy credits, set your markup", "Every conversation makes the next one better"). Use `[stat: …]` placeholders. Don't edit yet.

**Step 3 — Cut (SKILL.md:54-75).** Halve. Then prune. The page is done when removing one more sentence would weaken it. Run the writer skill's cut-list (adverbs, hedges, throat-clearing openers, empty intensifiers, restated questions, closing throat-clearing).

**Step 4 — Show, don't tell (SKILL.md:79-99).** Adjective audit: any adjective without a number behind it gets cut or replaced with the fact that earned it. Drill: read the page with all adjectives mentally removed. If it still moves the CEO, the content is good.

**Step 5 — Structure (SKILL.md:103-126).** Gopen/Swan: subject + verb close; old info first, new info last; the page's strongest claim moves to the top. Pyramid: conclusion → reasons → evidence, so the CEO can stop at any point and still take away the main thing.

**Step 6 — Sentence polish, the five questions (SKILL.md:130-140).** Meaning → clarity → tone → novelty → beauty. Stop one question short under time pressure; finish all five when the page warrants it.

**Step 7 — Read aloud (SKILL.md:144-152).** Lips move. If a sentence stumbles, rewrite. If a paragraph could be one sentence, make it one.

**Then apply this PDF's structural constraints (on top of the skill):**

- **Headings.** Page title is the only `h1`. Sections are `h2`. No `h3`. No emoji. No exclamation marks.
- **One CTA line per page.** Action verb + outcome. Listed in the CTA table below — lock once, don't drift.
- **Data rule.** Every claim has a number, a citation, or `[stat: …]`. Inherited from `product-marketing.md`.
- **Banned vocabulary.** `product-marketing.md` ban list + writer skill's anti-patterns (`SKILL.md:271-279` and `references/anti-patterns.md`). Grep at the end; rewrite any survivors.
- **One quote max.** From the bank below. Skipping is fine.

---

## CTA table (locked — write these, don't invent)

| Page | CTA |
|------|------|
| 00 Cover | *See the platform you'll resell.* |
| 01 Brand | *Build your brand in 60 seconds.* |
| 02 Agency | *See the agency tier and start with 5M credits.* |
| 03 Chatbots | *Try the chat that scores 100 on Lighthouse.* |
| 04 Models | *Pick a model. Swap it in one line.* |
| 05 Agents | *Read a real agent — it's one markdown file.* |
| 06 Skills | *Browse the skill library.* |
| 07 Tools | *Connect Gmail in two clicks.* |
| 08 Memory | *Watch an agent remember.* |
| 09 Teams | *Deploy a Marketing, Sales and Service team to one client.* |
| 10 Tracking | *See the signal feed in real time.* |
| 11 Analytics | *Open the dashboard your client will see.* |
| 12 CRM | *Open the actor view — it's already the CRM.* |
| 13 Learning | *Watch a path harden into a highway.* |
| 14 Development | *Pick your surface: chat, CLI, IDE, MCP.* |
| 15 Security | *Read the threat model.* |
| 16 Speed | *Measure us. We'll measure back.* |

---

## Per-page rubric (derived from the writer skill)

Every page passes or fails on five dimensions, each scored 0–1. Composite gate ≥ **0.80** (this is print copy; the bar is higher than the /do code-rubric 0.65). Apply at the end of step 6.

| Dimension | Pass means | Source in writer skill |
|---|---|---|
| **Audience fit** | A non-technical agency CEO can read it end-to-end without stalling. One technical term max per section, defined inline. | `SKILL.md:30-39` (audience), `SKILL.md:34` (parent / CTO / HN test) |
| **Strongest-point-first** | The first sentence of the page is the sentence the CEO would underline. The Pyramid resolves: conclusion → reasons → evidence. | `SKILL.md:122-126` |
| **Show, not tell** | Every adjective in the final draft has a number, name, or scene behind it. The "drop-all-adjectives" drill still leaves a page that persuades. | `SKILL.md:79-99` |
| **Cut to the bone** | Removing any one paragraph would weaken the page. No throat-clearing, no hedges, no restated points. | `SKILL.md:54-75` |
| **Sentence craft** | Subject + verb close. Active voice default. Reads aloud without stumbles. Zero items from the banned list (em-dash habit, "delve / unlock / elevate / leverage / seamless / robust / cutting-edge / actionable / game-changer"). | `SKILL.md:103-119`, `SKILL.md:130-152`, `SKILL.md:271-279` |

**Scoring rule.** Each dimension scores 0 (fails the rule somewhere), 0.5 (mostly passes; one fixable miss), or 1 (clean). Composite = mean. Page ships at ≥ 0.80, with no single dimension below 0.5.

**Plus two hard gates (binary, no partial credit):**
- ✅ CTA matches the locked CTA table above (verbatim).
- ✅ Data rule holds — every claim has a number, citation, or `[stat: …]`. Zero un-cited adjectival claims.

**Verification.** At the end of each page, write a one-line rubric receipt at the bottom of the file as an HTML comment, e.g.:
```
<!-- rubric: fit=1.0 strongest=1.0 show=0.5 cut=1.0 craft=1.0 → 0.90 ✓ -->
```
This is the "deterministic results" rule (`engine.md` Rule 3) applied to prose. No vibes; receipts.

---

---

## Quote & stat bank

**Primary source: `text/quotes.md`** — the complete collection (8 parts, ~605 lines). Everything below is a curated subset. When writing any page, read `quotes.md` in full and pick the quote that fits the argument best. Anthony's originals (Part VII) are first-class — use them without apology. They're sharper than most attributed quotes in the field.

**Rule:** one quote per page, set in a blockquote, attributed. Two is sometimes warranted (one data citation + one philosophical closer). Three is showing off. Anthony's quotes count toward the limit. For pages where the slot says "skip" — the evidence on the page is stronger than any available quote; don't force one.

### Anthony's originals — use these first

Pull from `quotes.md` Part VII. Best by theme:

**Learning / memory / CRM:**
> "Every conversation with a customer either teaches your system or wastes it. There is no third option. Most companies are throwing away their best training data every single day."

> "Your CRM is a graveyard of intent. It tells you who showed up and what they bought. It doesn't tell you what they nearly bought, what made them hesitate, or what they wish you sold. AI changes that — if you let it listen."

> "The cheapest thing to copy is what you sell. The hardest thing to copy is how you learn. Build the second one and the first one stops mattering."

**Speed / latency:**
> "The cost of intelligence is collapsing. The cost of waiting is not. Whoever sits closest to the customer, with the shortest gap between question and answer, wins the next ten years."

> "The companies that win this decade won't be the ones with the smartest models. They'll be the ones with the shortest distance between a customer's question and a useful answer."

**AI / foundation:**
> "AI isn't a feature you add to your product. It's the new ground floor. Everyone who treats it as a feature will be working for someone who treated it as the foundation."

> "Every company is about to find out which parts of their business were actually services and which parts were just friction the customer had to pay for."

**Agency / ownership / moat:**
> "If your competitive moat is a feature, you don't have a moat. If it's a relationship the customer can't replicate elsewhere, you do. AI is making this distinction obvious for the first time."

> "If your AI lives inside someone else's platform, you're a tenant. The customer relationship, the data, the brand — none of it is really yours. The only durable position is to own the ground your agents stand on."
> ⚠️ Use this on pages aimed at prospects who are *currently* on a walled-garden platform (vendor lock-in angle). Do NOT use on agency pages — our agencies are putting their AI into ONE's platform; this quote would undercut the pitch.

**Simplicity / engineering:**
> "Most AI platforms stitch together a hundred vendors and hand you the bill. Real engineering moves the complexity inside, where the customer never has to see it. Simple is expensive to build and cheap to run. Complicated is the opposite."

> "Add a thousand lines, and you've added a thousand places it can break. Remove a thousand, and you've removed a thousand. Most teams are working in the wrong direction."

**Marketing / signals:**
> "Most marketing automation is just sending the same wrong message faster. Real automation is sending fewer messages that actually land."

> "A brand isn't what you say about yourself. It's what your system does when you're not watching. AI made every brand answer that question in public."

**Emergence / substrate:**
> "No single ant knows the solution. The colony does. And the colony is just the ants leaving notes for each other in the dirt."

> "We are not building chatbots. We are building the layer underneath them — the thing that remembers which answers earned trust, and quietly forgets the ones that didn't. That layer is the product. Everything else is just a face."

**Closing / manifesto:**
> "We were told AI would replace people. What it's really doing is replacing the parts of work that were never worth doing in the first place. The question isn't what AI takes from us. It's what we finally get to do with the time it gives back."

---

### Speed → revenue (legacy web, still load-bearing)

- **Amazon — Greg Linden (2006):** *"Every 100ms of latency cost us 1% in sales."*
- **Walmart — Cliff Crocker (Velocity, 2012):** *"For every 1 second of page-load improvement, conversions increased by 2%. For every 100ms, revenue increased by 1%."*
- **Walmart (Velocity, 2012):** *"Buyers loaded our pages in 3.22 seconds on average. Non-buyers loaded them in 6.03 seconds."*
- **Akamai (Spring 2017):** *"A 100-millisecond delay in website load time can reduce conversion rates by 7%."*
- **Akamai (2017):** *"53% of mobile site visitors leave a page that takes longer than three seconds to load."*
- **Google (2017):** *"The probability of a mobile user bouncing increases 32% when page load goes from 1 to 3 seconds — and 123% at 10 seconds."*
- **Google × Deloitte × Fifty-five (2020):** *"A 0.1-second improvement in mobile site speed increased retail conversions by 8.4% and average order value by 9.2%."* (30M sessions, 37 brands)
- **Google × Deloitte (2020):** *"A 0.1-second improvement increased travel conversions by 10.1%."*
- **Google × Deloitte (2020):** *"A 0.1-second improvement drove a 40.1% increase in users moving from product detail to add-to-basket on luxury sites."*
- **Bing — Eric Schurman (Velocity, 2009):** *"A 2-second slowdown changed queries-per-user by -1.8% and revenue-per-user by -4.3%."*
- **Google Search — Jake Brutlag (Velocity, 2009):** *"A 400-millisecond delay resulted in a -0.59% change in searches per user. Even after the delay was removed, users still made -0.21% fewer searches — slower experiences change long-term behavior."*
- **Shopzilla — Phil Dixon (Velocity, 2009):** *"A 5-second speedup produced a 25% increase in page views, a 10% increase in revenue, a 50% reduction in hardware, and 120% more Google traffic."*
- **Pfizer (Google/Deloitte 2020):** *"After introducing a speed budget, Pfizer's sites loaded 38% faster and bounce rate dropped 20%."*
- **BMW (Google/Deloitte 2020):** *"After rebuilding its mobile site with PWA and AMP, BMW grew mobile traffic from 8% to 30%."*
- **Vodafone — Core Web Vitals case study (2021):** *"Vodafone improved sales 8% and lifted cart-to-visit rate 11% by improving Largest Contentful Paint."*
- **Financial trading (Tabb Group):** *"A broker can lose $4 million in revenue per millisecond if their trading platform is 5ms behind the competition."*
- **Jakob Nielsen, _Usability Engineering_:** *"Beyond 1 second, users lose focus on the task. Beyond 10 seconds, they abandon it."*
- **Deloitte consumer survey (2020):** *"45% of consumers said they are less likely to make a purchase when an ecommerce site loads slower than expected. 35% said they are less likely to return."*

### Speed → revenue (AI-native)

- **Alhena AI (2026):** *"Brands using AI report a 3× lift in conversion rates and 50%+ growth in average order value through faster, intent-aware responses. A leading DTC skincare brand saw a 14% increase in checkout completion after optimizing latency."*
- **Alhena AI (2026):** *"Sub-second latency keeps users in a flow state, preventing decision fatigue. Every instant answer sustains trust and momentum."*
- **BenchLM.ai (2026):** *"For chat applications, TTFT under 1 second feels instant. Reasoning models often have high TTFT (10–150s) because they 'think' before responding."*
- **BentoML (2025):** *"A chatbot might require a TTFT under 500 milliseconds to feel responsive, while a code completion tool may need TTFT below 100 milliseconds."*
- **IBM (2026):** *"In AI systems, users are more sensitive to the delay before the first token than to delays between subsequent tokens. The moment a user submits an input prompt, a silent countdown begins."*
- **BenchLM.ai (2026):** *"Models below 50 tokens/sec feel sluggish in interactive applications. 200 tok/s produces roughly 150 words per second."*
- **TokenFlow (2025):** *"Up to 82.5% higher effective throughput and up to 80.2% lower P99 TTFT, without lowering overall token throughput, by pairing buffer-aware scheduling..."*

### Continual learning & compounding *(the §13 Learning bank — primary slot for that page)*

- **Demis Hassabis, CEO Google DeepMind (CNBC, January 2026):** *"Continual learning — the ability to learn in every new moment, as humans do, rather than only learning every few months when a new training run happens — is one of the bottlenecks on the path to AGI."*
- **Global Advisors (2025), summarising Hassabis's research direction:** *"Biological intelligence fundamentally involves interaction with environments over time, generating diverse signals that guide learning."*
- **Naval Ravikant:** *"Information compounds. Relationships compound. Reputation compounds. The advantage compounds."*
- **Versaunt (October 2025):** *"Marketers will move from manually tweaking campaigns to overseeing intelligent systems that continuously learn, adapt, and optimize. Campaigns are not just optimized — they are self-optimizing, constantly seeking the event horizon of maximum performance."*
- **Arie de Geus, _The Living Company_ (former Shell strategy head):** *"The only sustainable competitive advantage is the ability to learn faster than your competition."* *(also indexed under Speed and competitive advantage)*

**How to use this slot:** §13 Learning's hook is *"your clients' chatbots get smarter than the competition; the gap is unrecoverable."* These five quotes are the external authority that turns that claim from marketing into established consensus. Hassabis names the bottleneck (continual learning); Naval names the compounding mechanism; Versaunt names the marketing-team consequence; de Geus names the strategic outcome. One quote per page max — §13 picks Hassabis or Naval depending on the page's lede.

The Versaunt line is also the natural quote slot for §09 Teams (the marketing-department reframe) and §11 Analytics (self-optimizing campaigns).

### AI-native economics

- **Bessemer, _State of AI 2025_:** *"AI-Native product gross margins benchmarks are 50–65%, while traditional SaaS benchmarks are 70–85%. The fastest growing AI-native companies — 'Super Novas' — typically have gross margins around 25%."*

### Brand, distribution, and aggregation

- **Naval Ravikant:** *"In a world of infinite supply, distribution is the only moat."*
- **Ben Thompson, Stratechery:** *"The biggest companies in the world will not own the customer relationship. The companies that own the customer relationship will own the biggest companies in the world."*
- **Marty Neumeier, _The Brand Gap_:** *"Build a brand, not a product. Products get commoditised. Brands compound."*
- **Scott Cook, Intuit:** *"A brand is no longer what we tell the consumer it is — it is what consumers tell each other it is."*
- **Tim O'Reilly:** *"The best products are platforms — they create more value than they capture."*
- **Jason Lemkin (SaaStr) — common reseller maxim:** *"Own the customer, rent the technology."*

### Simplicity (the 670-line argument)

- **Leonardo da Vinci:** *"Simplicity is the ultimate sophistication."*
- **Antoine de Saint-Exupéry:** *"Perfection is achieved, not when there is nothing more to add, but when there is nothing left to take away."*
- **Edsger Dijkstra:** *"Simplicity is a great virtue but it requires hard work to achieve it and education to appreciate it. And to make matters worse: complexity sells better."*
- **Gordon Bell:** *"The cheapest, fastest, and most reliable components are those that aren't there."*
- **Kent Beck:** *"Make it work, make it right, make it fast."*
- **Brian Kernighan:** *"Controlling complexity is the essence of computer programming."*

### Speed and competitive advantage

- **Dave Girouard, Upstart (ex-Google):** *"Speed is the ultimate weapon in business. All else being equal, the fastest company in any market will win."*
- **Klaus Schwab:** *"In the new world, it is not the big fish which eats the small fish, it's the fast fish which eats the slow fish."*
- **Arie de Geus:** *"The only sustainable competitive advantage is the ability to learn faster than your competition."*
- **Jeff Bezos:** *"If you double the number of experiments you do per year, you're going to double your inventiveness."*
- **John Boyd (OODA):** *"The way to win is to compress the loop."*
- **Navy SEAL maxim:** *"Slow is smooth, smooth is fast."*
- **Fred Wilson, USV:** *"Speed is a feature. In fact, for many products, speed is the most important feature."*
- **Patrick Collison, Stripe:** *"The faster you go, the more it feels like a different product."*

### AI agents and substrate

- **Bill Gates:** *"Agents are not only going to change how everyone interacts with computers. They're also going to upend the software industry, bringing about the biggest revolution in computing since we went from typing commands to tapping on icons."*
- **Sam Altman (Dec 2024):** *"In 2025, we may see the first AI agents join the workforce and materially change the output of companies."*
- **Sam Altman:** *"What you really want is just this thing that is off helping you... a super-competent colleague that knows absolutely everything about my whole life, every email, every conversation I've ever had, but doesn't feel like an extension."*
- **Andrej Karpathy:** *"The hottest new programming language is English."*
- **Jensen Huang, NVIDIA:** *"Software is eating the world, but AI is eating software."*
- **Sundar Pichai (Q3 2024 earnings):** *"More than a quarter of all new code at Google is now generated by AI."*
- **Jensen Huang:** *"20 years ago, all of this was science fiction. 10 years ago, it was a dream. Today, we are living it."*

### ONE's own lines (claim as our own)

- *"The cost of intelligence is collapsing. The cost of latency is not."* (Speed / Models pages)
- *"Platforms beat products. Networks beat platforms. Substrates beat networks."* (Agency thesis)

### Closing slot

- **William Gibson:** *"The future is already here — it's just not evenly distributed."*
- **Alan Kay:** *"The best way to predict the future is to invent it."*
- **Jeff Bezos:** *"Your margin is my opportunity."* (works as a jab at incumbent platforms passing the bill)

---

## Pick list (if you only want three for the PDF cover/intro/outro)

1. **Intro:** Naval — *"In a world of infinite supply, distribution is the only moat."* (sets up why a branded substrate matters)
2. **Why it stays cheap:** Saint-Exupéry — *"...nothing left to take away."* (the 670-line argument)
3. **The thesis:** Dave Girouard — *"Speed is the ultimate weapon in business. All else being equal, the fastest company in any market will win."*

---

## Open questions to resolve before drafting

These are the ones still open after the research pass:

1. **Real Lighthouse / TTFAPIC numbers as of 2026-05-15.** Use latest measured values, not stale ones from the docs. Run `/browser` against `/chat` and the cover routes before writing the Speed page.
2. **Closing page after 16.** Right now Speed closes with the thesis line. A 17th "Why now" page could carry the CTA to schedule a buy conversation — or it could feel like padding. Default: no 17th page; the Speed close is the close. Revisit after Pass 4.
3. **Memory-type taxonomy.** Page 08 needs the exact list from `one/one/memory.md` — confirm whether the source names them as *episodic / semantic / procedural* or uses ONE's own taxonomy before drafting.
4. **Composio integration count.** Page 07 says "250+ integrations" — verify against `composio.md` before commit.

Resolved (do not re-litigate):

- **Billing model** — credits, resold. 1 credit = $0.0001. Agency buys in bulk, marks up ≥ 5%, distributes to clients. Full cascade in `web/billing.md`. (Supersedes the old "no pricing yet" deferral.)
- **Composio naming** — handled per decision 8.
- **Quote inventory** — collected in the bank above. Drafting picks from it.
- **Tone calibration** — `text/speed.md` is the worked example. Match its density, sentence rhythm, and use of numbers per paragraph.
- **Per-page rubric** — derived from the writer skill, gate ≥ 0.80. See §Per-page rubric.
- **CTAs** — locked in the CTA table. Don't drift.

---

## What this plan does NOT do

- Does not write any page. That's the next pass.
- Does not design the PDF cover or layout. Assumes a downstream tool concatenates `text/[0-9]*.md` into one PDF.
- Does not write speaker notes or sales talking points — those belong in a separate deck.

---

## Next action

Run the writing pass page-by-page in order. Suggested batching:

- **Pass 1:** cover + 01 + 02 (brand/agency setup). Review tone & length.
- **Pass 2:** 03–08 (product layer). Same shape, fast.
- **Pass 3:** 09–13 (teams + data layer).
- **Pass 4:** 14–16 + final read-through.

Four passes, ~4 pages each, all inside the word budget. The writer skill carries the craft; this plan carries the structure.
