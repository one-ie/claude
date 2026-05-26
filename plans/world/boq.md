# ONE Infrastructure for BOQ 

> **As of:** 2026-05-12 · **Author:** Tony O'Connell · **Audience:** Donal (partner) — not for forwarding to Brad without calibration pass.
> **Status keys used below:** *landed* = shipped, runnable today · *scaffolded* = code exists, not production-hardened · *designed* = spec exists, no code · *not built* = neither.

**Donal — this doc is written for you, not Brad. It's the honest state of the substrate as I see it from inside the code, so you can calibrate what to claim in the deck before Brad gets in deeper. The big numbers in the [forecast](https://boq-forecast.pages.dev/) are achievable; what they need is the Pilot 1 work, and we both need to be straight with Brad about where we are.**

The 15 questions are answered below.

## How onboarding works

### 1. Sparse-site onboarding minimum viable input

The chat is designed to ask conversationally for what's missing — business name, hours, services, phone — when scraping fails. Pattern is implemented; robustness at real-world edge cases is a Pilot 1 discovery. Logos auto-generate (`web/src/pages/api/logo/[slug].ts`); brand palettes auto-derive from the site. **Pilot 1 builds:** 7 niche default packs + the workspace dashboard from your wireframe.

### 2. URL-paste auto-gather scope and wall-time

60-second bot-live is the dev happy-path number on a normally-responsive site, measured manually. Real-world variance has not been measured. Page HTML and visible copy pull and index in real time. Review aggregation (Google Maps / Facebook / Yelp) is **not built** — it ships in Pilot 1 (Apify-fronted, cached per domain). The 48-hour fully-tuned envelope from your deck covers niche prompt tuning + QA pass + custom upsell wiring — those steps are manual today; the 48h target is design, not measured throughput.

### 3. DNS — is the A-record the only step?

CNAME flow is implemented (`web/src/pages/api/domain.ts`). One DNS edit; subdomain fallback exists. Long tail of registrar quirks, dangling TTLs, SSL propagation under simultaneous onboards — not yet seen. Pilot 1's first 50 domains surface those.

### 4. Stripe sufficiency for $1k / $1.5k / $2.5k recurring + one-time upsells

Stripe is **scaffolded, not production-hardened.** Tier pricing matches the forecast exactly:

- Tier 1 — $1,000/mo · Tier 2 — +$500 (30% target penetration) · Tier 3 — +$1,500 (10%)
- Marketing upsells — $700/mo average (25% penetration)
- Brad retainer — $4k flat
- One-time audits — $200–$3,000

All of these tier shapes are supported by the scaffold (`web/src/pages/api/pay/`, `workers/billing-cron.ts`). What hasn't happened: real-card volume at 50+ concurrent recurring renewals, refund storms, card-decline cascades, dispute handling, idempotent webhook delivery under retries. Stripe Connect and ad-spend % billing are not built. Pilot 1 is the volume + failure-mode test.

**Real Stripe arithmetic on a $1,000 Tier 1 renewal** (Stripe Canada pricing, as of 2026-05-12):

| Line | Cost on $1k |
|---|---|
| Base domestic card (2.9% + $0.30) | $29.30 |
| + Stripe Billing (0.7% — needed for the embedded customer portal in your wireframe) | +$7.00 |
| + Stripe Tax API ($0.50 / transaction — sales tax for Canadian provinces) | +$0.50 |
| **Fully loaded Stripe cost** | **$36.80** |
| Optional add-ons (international card +0.8%, currency conversion +2%, dispute $15) | as incurred |

So the real Stripe cost depends on whether we run with the embedded portal + tax automation (yes, for the dashboard wireframe) or strip back to checkout-only ($29.30). I'd budget **$36.80 per Tier 1 renewal** for the BOQ deployment.

### 5. Other onboarding gotchas

Three categories anticipated in code with partial mitigation; none seen at customer scale:

- **Email deliverability** — Resend integration exists; DKIM/SPF + warm-up sequence documented; never run at customer volume
- **Passkey UX in webviews** — FB/LinkedIn detection routes to `MobileHandoff`; works in dev; not tested across the full browser matrix
- **Custom-domain SSL** — Cloudflare cert provisioning shows "provisioning…" state; not stress-tested under simultaneous onboards

Pilot 1 surfaces the unknown unknowns.

---

## How the economics could hold at scale

### 6. Per-client all-in cost (margin floor)

**Real today's prices, bottom-up. Not measured against customers yet (none exist). Real curve comes from Pilot 1.**

**Inference model menu (verified live pricing 2026-05-12, USD per 1M tokens):**

| Model | Input (cache miss) | Input (cache hit) | Output | Notes |
|---|---|---|---|---|
| DeepSeek-V4-Flash | $0.14 | $0.0028 | $0.28 | Cheapest capable model. Thinking + non-thinking modes. |
| GPT-4.1-mini | $0.40 | $0.04 | $1.60 | OpenRouter default. 90% cache discount. |
| Groq Llama 3.3 70B | $0.59 | — | $0.79 | No prompt cache on Groq. Fastest tokens/sec. |
| Kimi K2.6 | $0.95 | $0.16 | $4.00 | 256k context. Native multimodal. Good for harder turns. |
| Claude Haiku 4.5 | $1.00 | $0.10 | $5.00 | Anthropic baseline. 10× cache discount. |
| Claude Sonnet 4.6 | $3.00 | $0.30 | $15.00 | Hard reasoning only — use sparingly. |

**Routing strategy** (designed; the router exists in code, the per-niche routing rules don't):

- **Cheap turns** (greeting, simple lookup, niche-pack response) → DeepSeek-V4-Flash
- **Tool-call turns** (CMS edit, calendar booking, lead capture) → Kimi K2.6 or Haiku 4.5
- **Hard reasoning** (project-takeoff cost estimate, multi-step planning) → Sonnet 4.6 sparingly
- **Fallback when cap nearly hit** → Groq Llama 3.3 70B (fast, predictable, cheap)

**Modelled volume:** 500 conversations/mo × ~8k tokens each = 4M tokens, of which ~70% input / 30% output, with ~80% prompt-cache hit rate on system prompt + niche context.

| Profile | Convos/mo | Inference (mixed routing) | Stripe (Billing + Tax) | Edge + misc | **All-in** |
|---|---|---|---|---|---|
| **Lean** | ~200 | $1–2 (DeepSeek-heavy) | $36.80 | $1 | **~$39–40** |
| **Modal** | ~500 | $3–6 (mixed routing) | $36.80 | $1 | **~$41–44** |
| **Heavy** | ~1500 (capped) | $10–25 (capped) | $36.80 | $1 | **~$48–63** |

**With Stripe stripped back to checkout-only** (no embedded portal, no tax automation): subtract $7.50 → lean ~$32, modal ~$34, heavy ~$56.

**Gross margin on Tier 1 ($1k):** 95–96% modal, 94% heavy.

Donal — your $30/client number is achievable on the lean config (DeepSeek-heavy routing + stripped-back Stripe). The fully-loaded BOQ config (mixed model routing + Stripe Billing + Tax for the dashboard wireframe) lands closer to **$40–45 modal**. Same envelope, more defensible to Brad. **The cost cap in Q10 (not built yet) is what keeps the upper tail bounded.**

Sources: [Stripe Canada](https://stripe.com/en-ca/pricing), [OpenAI](https://pricepertoken.com/pricing-page/provider/openai), [DeepSeek](https://api-docs.deepseek.com/quick_start/pricing), [Kimi K2.6](https://platform.kimi.ai/docs/pricing/chat-k26), [Groq](https://groq.com/pricing).

### 7. Pre-niche-training mechanics

Skill system framework exists (`web/src/pages/api/skill/`, `claw/src/skill-tools.ts`). Per-pack shape: markdown system prompt + opening flow + Zod schema. The dental demo shows the pattern; the PMS write-back hook is the kind of vertical integration each niche can have.

**Zero of the 7 BOQ ICP packs is authored as a production-grade pack today.** Pilot 1 builds 7 packs + a niche-pack authoring kit so you can extend without engineering touch. ~1 day per pack once the kit is in place.

### 8. Rate limit / SLA at 5,000+ concurrent

**The substrate has measured performance benchmarks** (`one.ie/SPEED.md`, vitest-runnable): signal routing <0.005ms ✓, fade 1k paths <5ms ✓, ask round-trip 3-unit chain <100ms ✓, TypeDB query top-50 paths 300ms p50 ✓, select from 1k paths <1ms ✓. **The substrate operations themselves are characterised** — not a "we hope it's fast" claim.

What hasn't been done: end-to-end load test against a BOQ-shaped workload (chat + niche pack + tool call + cascade write + Stripe webhook) at 5k concurrent. D1 has a ~1k writes/sec ceiling per database; the sharding plan (one DB per Level-1 agency, hash-shard within) is designed, not implemented — single-DB carries the early cohort.

**Path to a written SLA:**
- Pilot 1 (50 clients) — first BOQ-shaped production telemetry; calibrate
- Pilot 2 (200–500 clients) — sustained-load telemetry; written SLA lands

**Target:** 99.9% uptime / p95 < 800ms (matches your Orb). **Defensible pre-telemetry floor:** 99.5%. The 99.9% is reachable given the substrate's measured performance and Cloudflare's edge characteristics — assuming Pilot 1+2 don't surface BOQ-specific stability issues we haven't anticipated.

### 9. White-label rights

Cascade schema is in (`migration 0008_workspace_hierarchy.sql`). Cascade reads exist in code; full middleware + UI coverage is mid-flight. The 6-token design system + dark/light theming is implemented and works.

**The workspace dashboard from your wireframe is not built as UI.** Pilot 1 builds it to spec:

- Three-column: left nav (Workspace / Conversations / Services / Account) · centre KPIs · right-side chat widget
- Top strip: brand identity + multi-property selector
- Sessions chart with geographic filters · "What people are asking" · "Active upsells" · "Recent edits"
- Edit-mode toggle (mustard pill) → split-pane preview
- Role-based permissions (Owner / Editor / Viewer)

### 10. OOM cost ceiling on a viral burst

Cloudflare auto-scales for uptime. **Per-workspace daily token budget is not built.** Design:

- Tier 1 → $40/day soft → Groq fallback
- Tier 2 → $80/day → same
- Tier 3 → $150/day → same
- Hard breaker at 2× cap → "I'll be back online tomorrow"

1 cycle to build. **Required before client #100.** Designed, not yet code.

---

## What makes BOQ different (what's actually built behind it)

### 11. Self-service CMS connectors

**Composio OAuth integration is landed** (`composio-todo.md` shipped 2026-05-12 · rubric 0.79). `/u/{slug}/tools` renders the catalogue; the connect flow (`composio/connect.ts`, `callback.ts`) is wired with skill-first routing — nanoclaw.dev skills take precedence; Composio is the fallback for anything not covered by an imported skill. `userId = walletAddress`, COMPOSIO_API_KEY Worker-side only.

Per-CMS work for Composio-supported targets is now OAuth-app registration + auth-config — ~2h each, not "shipped":

| Connector | Composio | Tools | Work to enable |
|---|---|---|---|
| Shopify | yes | 361 | Shopify Partner app + auth-config |
| Webflow | yes | 51 | Webflow Dev app + auth-config |
| Wix | yes | 138 | Wix Dev app + auth-config |
| GoHighLevel | yes | 94 | GHL Marketplace app + auth-config |
| Static HTML | n/a | — | `commit.ts` exists (121-line scaffold; production hardening needed) |
| WordPress | no | — | Native REST connector — not started, ~1 wave |
| WooCommerce | no | — | Native REST connector — not started, ~1 wave |
| Squarespace | no | — | Thin API; static-HTML fallback — not started |

**Ship plan:**
- Pilot 1: Static-HTML hardening + Shopify + Webflow + WordPress (native)
- Pilot 2: Wix + GHL + WooCommerce
- Squarespace: long tail

### 12. Audit trail

Logging passes through `substrateMiddleware` (`claw/src/substrate.ts`, `claw/src/middleware.ts`); some events land in D1. **Retention is not yet configured for the 90-day spec.** Site edits are git-style snapshots in R2 + KV; rollback API exists. **Customer-facing audit timeline UI is not built** — Pilot 1 work, per your wireframe.

### 13. Source-code escrow / continuity

**Two-layer continuity, by design.**

**Substrate layer — open:** `github.com/one-ie/one` is live, MIT-licensed. SDK, MCP server, CLI, Python package, channel adapters, niche-pack format all public. **Forkable by construction.** Plus the production substrate runs real traffic today across `dev.one.ie` (Astro Worker), `api.one.ie` (TypeDB gateway + WsHub DO), `nanoclaw.oneie.workers.dev` (channel bots), `one-substrate.pages.dev` (substrate exports). There's a live production config to fork from, not just source code.

**Product layer — private to `one.ie/`:** the agency cascade UI, billing system, workspace dashboard, Composio toolkits surface, element-edit pipeline, audit timeline. This is the exclusive IP that justifies BOQ's tier pricing. Continuity here works through a **source-code escrow clause in the NewCo agreement** — NCC Group or equivalent at ~$3–5k/yr, releasable to OO under defined trigger conditions (Tony unavailability, ONE entity dissolution, etc.). Cleaner than escrow-everything because the value to protect is concentrated and well-bounded.

Net result: Brad has bus-factor protection (open substrate is permanent + product layer is escrow-protected) AND a real competitive moat (no other agency can lift the productized layer). Better than either pure-OSS or pure-closed alone.

### 14. Niche-detection LLM confidence threshold

Classifier in `claw/src/classify.ts` emits confidence scores. Default: < 0.7 → ask user to pick from shortlist. **Accuracy never measured against BOQ ICPs because no BOQ data exists.** Pilot 1: 7-ICP-only classifier (smaller label space → better accuracy), threshold raised to 0.85, sub-threshold sign-ups route to the Philippines support inbox via Telegram (channel wiring exists in `claw/src/channels.ts`).

### 15. Element-highlight-and-talk

[Your demo](https://boq-edit-demo.pages.dev/) proves the UX visually on a mock. **None of the production wiring exists today.** What's built: chat widget (`ChatWidget.tsx`, currently modified-uncommitted), commit pipeline (`commit.ts` 121-line scaffold). What's not built: edit-mode toggle injection, iframe DOM event capture, XPath extraction, chat context handshake, real CMS connector call, audit entry.

**Effort:** Composio cycle landed 2026-05-12, so the OAuth substrate is in. Remaining: 1 cycle to wire Static-HTML + Shopify + Webflow into the edit pipeline; +1 cycle for the other 4 connectors; +1 cycle for polish. The differentiator is buildable on a now-real foundation.

---

## Pilot 1, in one paragraph

**Pilot 1 = first 50 paying clients · 6-week duration · week-6 decision gate.** The gate has three pass conditions, all measured at week 6: (1) **conversion ≥ 1%** of bot conversations into a closed action (booking, lead capture, payment, qualified handoff — niche-specific definition agreed before Pilot 1 kickoff); (2) **churn ≤ 8%** across the cohort over the 6 weeks; (3) **COGS in envelope** per §6 — modal all-in ≤ $45/client/mo, heavy ≤ $63/client/mo, no client exceeding the §10 daily cap. Pass all three → we ramp to Pilot 2 (200-500 clients). Miss any one → we don't ramp; the cohort keeps earning revenue while Tony + Donal course-correct. This gate is the load-bearing checkpoint for both Brad's contract and the NewCo/JV memo — both reference these exact criteria.

---

## Where the deck and reality currently diverge

Things in the BOQ materials that go beyond what the code supports today — worth softening or talk-track-adjusting before Brad probes them:

| Deck claim | Reality | Suggested talk-track |
|---|---|---|
| "Stripe-in-chat, drops Stripe card mid-conversation" (Orb, dental demo description) | Stripe scaffold supports it; the dental demo itself does **not** show Stripe-in-chat (it shows PMS booking) | Either update the dental demo to include a payment moment, or steer the live demo to a different niche pack where in-chat payment is the actual flow |
| "15-niche FAQ in Tier 1" (Orb) | Question pack says 7 ICPs; forecast assumes 7 | Pick one number for the deck. 7 is what we're committing to author in Pilot 1 |
| "~$30/month per client" (Empire Architecture) | Achievable on lean config (DeepSeek-heavy + stripped Stripe) ~$32; fully-loaded BOQ config (mixed routing + Stripe Billing + Tax) ~$40–45 modal | Position as "~$30–45 per client depending on config, 94–96% gross margin on Tier 1" — both numbers defensible, no surprise later |
| "99.9% uptime at any scale" (Orb) | 99.5% is the defensible pre-telemetry floor; 99.9% is the post-Pilot-2 target | Frame as "target 99.9%, written SLA after Pilot 2 telemetry" |
| "48-hour deployment" (Orb Tier 1) | 60-second bot-live in dev; 48h fully-tuned is target, not measured | Pair them: "bot live in 60 seconds, fully tuned in 48 hours" — both honest |
| "Tony's stack — 99.9% uptime, no servers to maintain, no scaling surprises" (Empire Architecture) | True architecturally; not yet load-tested at our specific code path | Soften "no scaling surprises" — there will be some in Pilot 1, that's what Pilot 1 is for |
| Element-edit positioned as live differentiator | Visual demo only; no production wiring yet | "Working visually today, wired to real CMSes in Pilot 1" — accurate and still impressive |
| "100% bot onboarding for months 1–6" (Orb) | Realistic with the niche packs + classifier; will need human review fallback for the long tail | Keep "100% automated happy path" but acknowledge the Philippines fallback queue exists from day 1 |
| "Already shipped" benchmark site (Orb references) | The benchmark page exists; the substrate behind a paying-customer chatbot does not exist deployed today | Differentiate "benchmark + demos shipped" from "production substrate at customer scale — Pilot 1" |

None of these kill the deal. All of them protect us from a "wait, this isn't what you showed me" moment 6 weeks in.

---

## What else is in the substrate — revenue and defensibility you haven't pitched yet

There's a lot in the codebase that doesn't show up in the Orb or the deck. 

Some of these slot straight into the existing tiers as upsells; some are Tier 3+ / Developer SKU material; some are just defensibility worth naming in the pitch out loud.

### Revenue levers — extra ways to monetize without rebuilding anything

**1. Credit-based metered billing layered onto flat tiers.** This is the big one Donal hasn't fully exploited. The billing layer (`web/billing.md`, migrations `0016_credit_grants` + `0017_credit_burns` + `0018_billing_state` + **six dedicated billing crons**) is built on a credit ledger: `1 credit = $0.0001`, `GRANT → POOL → BURN`. Plans are just YAML bundles in `_platform/billing.md`:

```yaml
starter:  { grant: 50_000 }      # ~$5 worth of conversation
pro:      { grant: 500_000 }     # ~$50 worth
agency:   { grant: 5_000_000 }   # ~$500 worth, with sub_workspace_create + white_label_cascade
```

**What this unlocks for BOQ:** Tier 1 ships with X credits included (covers modal usage); heavy users buy auto-topup packs (existing `billing-autotopup-cron.ts`). Agency margin is codified directly in the burn ledger (`agency_margin`, `platform_margin`, `recipient_share` columns in migration 0017) — Brad's cut, Donal's cut, and ONE's platform floor are tracked per burn, no manual reconciliation. **Donal captures usage spikes from ad-driven traffic without re-architecting tiers.**

**2. Premium model gates as paid features.** Workspaces have `premium_models: on|off` as a billing gate. Concrete tier story: Tier 1 chats run on DeepSeek + GPT-4.1-mini; Tier 3 unlocks Sonnet 4.6 for hard reasoning. Tier escalation becomes a *model quality* story, not just feature count.

**3. Brand-removal as a paid gate.** `brand_removal: off|on` is in the billing config. Free/Starter sees "Powered by BOQ" (or whatever you brand it); paid tiers strip that. Marginal revenue lever, but it's already wired.

**4. Per-conversation revenue capture.** The burn ledger has a `recipient_share` field (migration 0017). When the dental bot books a $200 cleaning, BOQ can take a clean cut (e.g., 2% of booking value) without inventing new infra. Tier 3+ "performance pricing" upsell.

**5. x402 crypto rail with USD bookkeeping.** Migration 0020 adds `agency_usd` + `agency_slug` to x402 payments — meaning Brad can accept crypto for clients who want it, settled and reported in USD. Niche but real.

### Channels — a bot is not just a web widget

`claw/src/channels.ts` handles **multi-bot Telegram** out of the box (per-name token routing: `TELEGRAM_TOKEN_<NAME>`, group prefix `tg-<name>-`). Same pattern extends to Discord and HTTP. **What this unlocks for BOQ:**

- A dental practice runs their bot on **web + Telegram + Discord** from one workspace → Tier 2 upsell ("multi-channel: +$500/mo")
- WhatsApp Business is one adapter away — Brad's window-and-door installers want WhatsApp on jobsites
- Voice via the existing `tts.ts` endpoint — Donal's Tier 2 "AI voice agent" claim has an actual surface behind it

### Defensibility — why clients don't churn

These are the moat lines worth pitching explicitly to Brad:

- **Pheromone substrate** (`claw/src/substrate.ts`) — paths get marked when conversations succeed, weighted over time. **The agent gets measurably better at the client's business the longer it runs.** A generic vendor's bot resets every conversation; ONE's bot at month 6 is provably smarter than at month 1. This is the anti-churn weapon — Donal should pitch this explicitly.
- **Eval system** (`web/src/pages/api/eval.ts`) — A/B test prompts, measure conversion lift per niche pack. Brad's clients see their bot improving with data, not vibes. Reduces "why am I paying $1k for this" risk at renewal.
- **Cascade-based agency-pooled billing** (`billing-allocation-cron.ts`) — Brad pays one invoice for all 5,400 workspaces; per-workspace burns get allocated automatically. **Critical at scale** — no agency wants 5,000 separate Stripe invoices.
- **Recovery codes / break-glass auth** (`web/src/pages/api/recover.ts`) — table-stakes for the multi-location commercial niche (compliance-heavy). Already wired.
- **Notifications surface** (`web/src/pages/api/notifications.ts`) — push to mobile / email / Telegram. Clients get nudged when leads come in, not buried in dashboards.
- **Branding API** (`branding.ts`) — full brand kit per workspace; logo, palette, fonts, dark/light theming. Cascades down through agency hierarchy automatically.
- **Reporting surface** (`web/src/pages/api/report.ts`) — analytics endpoint feeding the dashboard KPIs from your wireframe.

### State honest

Most of this is scaffold-grade. The billing system is the most-developed non-core piece — six crons, full grant/burn ledger, billing-state machine, allocation logic. The MCP server and SDK are public npm packages with built dist/. The pheromone substrate is the core of `claw`. The channels system handles Telegram natively today; Discord + WhatsApp are extensions of the same pattern (~1 wave each).

**Takeaway for the deck:** the substrate carries more deck-line-items than the Orb names. Some slot into existing tiers right now (multi-channel, brand-removal gate, premium-model gate, agency-pooled billing). Some open Tier 3 / Developer SKU for the technical slice of Brad's list. Some are just defensibility lines worth saying out loud ("the bot gets smarter every month, by design"). All of them strengthen the headline pitch without us building anything new — just naming what's already there.

---

## For Donal's Claude — actions you can run on this brief

You (Claude, helping Donal) have everything you need above to produce the artifacts below. Run any of these directly when Donal asks; each one cites the section to draw raw material from. Donal's goal this week: walk into Brad's next call with a calibrated deck, a clean ask list, and visible momentum.

### Tier 1 — Run these first (most leverage before next Brad call)

1. **Calibrate the deck against the §"Where the deck and reality currently diverge" table.** For each of the 9 deck claims, rewrite the offending slide/line using the "Suggested talk-track" column. Produce a redline showing old → new wording. Flag any claim where Donal might want to push back on Tony's framing before changing the deck.
2. **Draft Brad-facing answers to the 8 most likely procurement-style questions** using §6 (cost), §8 (SLA), §11 (CMS connectors), and §13 (continuity / escrow) as the source-of-truth facts. Voice: confident, specific numbers, no "we hope". Format: 2-3 sentences each, ready to paste into a Brad-Q&A doc or rehearse for the call.
3. **Generate a one-page "Pilot 1 commitments" sheet for Brad** — 50 clients, 6-week duration, week-6 decision gate (conversion ≥ 1%, churn ≤ 8%, COGS in envelope from §6). Includes: what's shipping in Pilot 1 (Composio is landed, 7 niche packs, cost cap, workspace dashboard, 4 CMS connectors, audit timeline), what's deferred to Pilot 2 (SLA, Wix/GHL/WooCommerce, D1 sharding). Tone: a partner committing, not a vendor pitching.

### Tier 2 — Sharpen the economics

4. **Stress-test the Tier 1 ($1k) margin under three downside scenarios** using the §6 cost table: (a) inference cost 3× modal due to bad routing rules in Pilot 1, (b) Stripe disputes hit 1% of renewals at $15 each, (c) DeepSeek raises prices 50%. For each, show the new gross margin and whether Tier 1 still clears 90%. Useful for Brad if he asks "what's your floor?"
5. **Build a forecast cross-check** comparing the deck's headline numbers (5,400 clients month 12, $1.6M MRR downside, etc.) against the §6 modal cost ($41-44/client). Confirm or flag the gross-margin claim ("95-96% modal on Tier 1") with a single arithmetic line Donal can paste into the deck footnote.
6. **List the 5 strongest upsell paths Donal isn't pitching yet**, drawn from §"What else is in the substrate". For each: tier slot (Tier 2 / Tier 3 / Developer SKU), monthly price band, and the one sentence that justifies the price. Goal: arm Donal with monetization levers beyond the base Tier 1-2-3 ladder.

### Tier 3 — Outreach & content

7. **Draft a 5-minute Loom walkthrough script** you will record: provision a workspace → niche-pack chat → Stripe checkout moment → element-edit → revert. Sequence beats, on-screen text, words to say. Tight script, 600 words max. Source: §15 + §11 + §"Pilot 1" delivery list.
8. **Draft Brad's first-10-clients outreach email** — what BOQ sends to the first sample names Brad surfaces. Frame as "first cohort, founding-customer pricing locked, higher-touch support, your needs shape what gets built next." Specifies Pilot 1 cadence (60-second bot-live, 48h fully-tuned). Source: §1, §2, §"Pilot 1" delivery list.
9. **Write 7 niche-pack opening prompts** for the BOQ ICPs (dental, accountant, restaurant, window-and-door installer, bookstore, MDU developer, multi-location commercial). For each: greeting line, 3 qualifying questions, the upsell moment. Tony authors the production packs; these are starter shapes Donal can review and pre-edit before they hit code. Source: §7 + §1.

### Tier 4 — Risk and decisions surfacing

10. **Identify the 3 highest-risk items in this brief** that could blow up the BOQ relationship if not addressed before Pilot 1 kickoff. For each: what could go wrong, what the warning sign would be, what Donal should ask Tony for in writing this week. Likely candidates: cost cap (Q10, "required before client #100", not built), classifier accuracy on BOQ ICPs (Q14, "never measured"), Stripe production-hardening (Q4, "scaffolded, not production-hardened"). Confirm or override based on the doc.
11. **Surface Tony's open asks of Donal** by re-reading the doc end-to-end. List each as a one-line decision Donal needs to make this week (e.g., "confirm dental demo path: add Stripe-in-chat OR steer to different niche", "pick Pilot 1 kickoff date", "decide on Tony joining Brad call vs 5-min Loom"). Format: bullet list with one-sentence context per item.
12. **Draft the NewCo / JV memo opener** — a partner-to-partner sketch Donal sends Tony to start formalizing the shape. **Framing — this matters:** Donal and Tony are friends building a great, profitable company together. The memo is generous, symmetric, and high-trust by default. Not vendor/buyer. Not arms-length. Read like two people who already trust each other and are choosing structure that lets both win bigger together than apart.

### Use-this-doc rules for Donal's Claude

- **Cite section numbers when claiming facts.** Tony has receipts (file paths, migration numbers, pricing dates) — don't paraphrase past them.
- **Don't soften the honest-state markers.** "Landed", "scaffolded", "designed", "not built" are status keys (see top of doc). Preserve them in any artifact that might reach Brad.
- **Default to Tony's voice for Tony-attributable claims** (technical commitments, what ships in Pilot 1) and Donal's voice for Donal-attributable claims (deck framing, sales motion, Brad relationship).
- **When in doubt, ask Donal which artifact to produce first** rather than batching all twelve. The Tier-1 three are the highest-leverage this week.

—Tony
