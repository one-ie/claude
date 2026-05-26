# positioning.md

> Working doc. Inventory every defensible differentiator, group by category, name what's missing, pick a meta-position, project it onto each surface.
>
> **Meta-position (locked 2026-04-29, expanded 2026-04-29):** *one.ie is the next-generation internet — built for AI agents from first principles, humans as first-class peers, economic layer on Sui.*
>
> Every internet primitive has been rebuilt agent-first: identity (biometric + Sui wallet + zkLogin + SuiNS roadmap), addressing (`unit:skill`), routing (pheromones, **<0.005ms**, 194 tests), discovery (highways + DeepBook roadmap), payment (multi-chain pay-link, on-chain settlement, sponsored gas), reputation (portable pheromone with Move twins), security (caps as physics, enforced on-chain), composition (branded AIs as Move objects), settlement (Sui 3s, programmable escrow), memory (TypeDB cached + Walrus roadmap for blobs). Most competitors have 2–3 primitives; we have the full stack and most of it ships.
>
> **Decentralized where it matters** — identity, money, reputation, governance, exit rights all on Sui. **Cached where physics demands** — pheromone math, classification, real-time off-chain. Same shape as the human internet: DNS is decentralized in theory, cached in practice.
>
> Every position below is a **layer** of this meta-position, not an alternative to it.

---

## The agent-internet stack

```
   THE INTERNET FOR AI AGENTS
   ─────────────────────────────────────────────────────────────────────
   L5  Surfaces       MCP / SDK / CLI / API / Web        the clients
   L4  Composition    Branded AIs from specialist groups  the apps
   L3  Discovery      Pheromone routing                   the Google + DNS
   L2  Payment        Pay-link 7 chains, 0.5% on-chain    the Stripe
   L1  Identity       Biometric SE + Sui wallet + TypeDB  the auth + TLS
   L0  Substrate      TypeDB 6 dimensions, one formula    the protocol
```

| Layer | Human-internet primitive | one.ie agent-first equivalent | Source |
| --- | --- | --- | --- |
| L0 | OS / database | TypeDB substrate, 6 locked dimensions | `one.ie/src/schema/one.tql` |
| L1 | DNS + TLS + accounts + 2FA | Biometric SE root + Sui wallet + `unit` identity | `passkeys.md`, `mac.md`, `wallet.md` |
| L1 | robots.txt | **agents.json** at `/.well-known/agents.json` (shipping) | `one.ie/CLAUDE.md` ADL section |
| L2 | Stripe / cards | Multi-chain pay-link, 7 chains, 0.5% on-chain, 3s settlement | `pay.one.ie`, `homepage-text.md` §4 |
| L3 | Google / DNS resolution | Pheromone routing, one formula, <0.005ms, 194 tests | `one.ie/one/routing.md` |
| L3 | Captcha / content moderation | Toxicity as 3 integer comparisons, <0.001ms | `routing.md` "Toxicity" |
| L3 | PageRank / reviews | Pheromone strength portable across all receiver types | `routing.md` "Receiver Types" |
| L4 | iframes / OAuth | Composable branded AIs (groups → one brand) | `homepage-text.md` §8 |
| L5 | Browsers + APIs | MCP / SDK / CLI / API / Web — all four surfaces, same substrate | `one-ie/one/`, `npx oneie` |

**The claim:** every row above is a primitive that an agent-first internet *needs*, and every row has a one.ie implementation that's either shipped or specced. Most competitors implement one row. Cloudflare implements three. We implement all of them and the routing layer is the deepest moat (194 tests, public benchmarks).

---

## The decentralization layer — Sui-native economic substrate

Most positionings using the word "decentralized" overclaim. Ours doesn't, because the architecture already splits cleanly between *what must be on-chain* (sovereign, permanent, transferable) and *what must be off-chain* (fast, computational, ephemeral). Same shape as DNS: decentralized in theory, cached in practice.

### What's on-chain today (Sui testnet, package `0xd064…4980`)

| Primitive | Move struct | Status |
| --- | --- | --- |
| Agent identity | `Unit` | shipped Phase 2 — `src/move/one/sources/one.move`, `src/lib/sui.ts` |
| Path / reputation | `Path` → promotes to `Highway` on harden | shipped — `src/engine/bridge.ts` mirror/absorb |
| Signal / event | `Signal` | shipped |
| Spending caps | `Cap` (cap inheritance, Move-bound) | shipped |
| Group / colony | `Colony` (rename to `Group` pending package upgrade) | shipped |
| Escrow | `Escrow` (50bps protocol fee) | Phase 3 W2 decisions locked, W3-W4 in flight |
| Treasury / fees | `Protocol` (fee_bps) | shipped |
| Governance | `GovernanceEvent`, `SubstrateOwner` | shipped |
| Identity sign-in | zkLogin OAuth → Sui address | shipped — `src/lib/auth-plugins/zklogin.ts` |
| Wallet sign-in | SIWE-style `suiWallet()` Better Auth plugin | shipped — `src/lib/auth-plugins/sui-wallet.ts` |

### What's off-chain by design (and why)

| Off-chain layer | Why | Source |
| --- | --- | --- |
| Pheromone math (`select`, `follow`, `mark`, `warn`, `fade`) | <0.005ms per decision; on-chain would be ~1000× slower and break the routing thesis | `routing.md` |
| Classification (Things, Learning dimensions) | "Writes are cheap and speculative" | `one.ie/CLAUDE.md` |
| Real-time, websockets, conversation | Latency-sensitive UI; replayable from on-chain anchor | `gateway/`, WsHub DO |
| Pheromone state | Cached in TypeDB Cloud, anchored to chain by Path/Highway twins | `bridge.ts` |

### Sui ecosystem expansion — by layer

| Layer | Current | Add (next) | Adds |
| --- | --- | --- | --- |
| L0 | TypeDB Cloud + Move twins | **Walrus** for decentralized blob storage (agent memory, audit logs, vault sync envelopes) | Storage exits CF D1 / R2 dependency for sovereign data |
| L1 | Sui wallet + zkLogin + biometric | **SuiNS** — agents get `.sui` names; replaces centralized agent registries | Names become *yours*, on-chain, transferable. The DNS of the agent internet. |
| L1 | shipped | **Seal** (Mysten encryption / TEE-backed key custody) | Decentralized key custody for high-assurance agents |
| L2 | Sui + 6 EVM chains via pay-link, escrow shipped | **Sui sponsored tx** (shape ref: `apps/enoki-play/src/routes/sponsored/`) | Gas-free UX; sponsor Worker absorbs fees |
| L3 | Pheromone routing, off-chain | **DeepBook** as on-chain capability/reputation markets | Permissionless liquidity + price discovery for the agent economy |
| L4 | Composable branded AIs (groups → one brand) | **Move object** = the branded AI; transferable, ownable | Branded AIs become Sui objects — ownable, sellable, composable |
| L5 | SDK / MCP / CLI / API + federation | **Federation over Sui** — peer worlds resolve over chain | Federation already exists; chain-resolved makes it permissionless |

### Risks of overclaiming "decentralized"

1. **Burned vocabulary.** Web3 2017–2024 made "decentralized" a vaporware tell. **Mitigate:** never use bare; always pair with the on-chain/off-chain table. Lead with *"on Sui"* (specific, verifiable) over *"decentralized"* (generic, distrusted).
2. **Sui is one bet.** Sui Foundation is well-funded; Mysten is shipping fast. But moat tied to their network. **Mitigate:** pay-link is already 7 chains — settlement claim is multi-chain, *substrate-native* claim is Sui-only. Be precise about which is which.
3. **Walrus / DeepBook / SuiNS not yet integrated.** Don't promise in present tense. **Mitigate:** label "next layer" not "current layer" until shipping.
4. **"Decentralized" is a *negative* signal in B2B / regulated sales.** Compliance, support, SLAs. **Mitigate:** B2B copy keeps *"safe by physics + open source + self-host"* frame; "decentralized" is for dev/crypto-native audience and the manifesto.
5. **Don't dilute the conversion hero.** "Make your AI agent earn" stays on `one.ie/`. The Sui story goes on `/about`, manifesto, launch post, and a dedicated `/sui` developer landing if needed.

### Updated one-line meta-position *(supersedes earlier versions)*

> **one.ie is the internet, rebuilt for AI agents — humans first-class, economic layer on Sui. DNS replaced by SuiNS. Reviews replaced by on-chain reputation. Stripe replaced by 0.5% on-chain across 7 chains, sponsored gas, programmable escrow. Storage on Walrus. Liquidity on DeepBook. Routing in arithmetic, <0.005ms, 194 tests. Six layers, one substrate, decentralized where it matters, cached where it must be.**

---

---

## How to read this doc

- A **differentiator** = a property of one.ie that a competitor would have to rebuild their stack to copy. Marketing claims aren't differentiators.
- Each row gets a **moat score** (1–3): 1 = anyone can copy in a quarter; 2 = needs real engineering; 3 = needs to rebuild the stack.
- The position we pick should be projected from the **highest-moat cluster**, not the loudest one.

---

## A. Routing & intelligence *(the deepest moat — read `one.ie/one/routing.md` before pitching this)*

| # | Differentiator | Moat | Source |
| --- | --- | --- | --- |
| A1 | **One formula governs all routing:** `weight = 1 + max(0, strength − resistance) × sensitivity`. Six metaphors (ant/brain/team/mail/water/radio), same arithmetic. | **3** | `one.ie/one/routing.md` "The Formula" |
| A2 | **Routing decision in <0.005ms** vs LLM routing call **2,000–5,000ms** — a **~500,000×** speedup. Replaces search with arithmetic. | **3** | `routing.md` "The Full Picture" |
| A3 | **194 tests, every claim measured.** isToxic <0.001ms, mark 10k <10ms, select <1ms, fade 1k <5ms. Not folklore — verified. | **3** | `routing.md` header proof block |
| A4 | **The deterministic sandwich** — toxic check + capability check pre-LLM, mark/warn post-LLM. The LLM is the *only* probabilistic step. | **3** | `routing.md` "The Layers", `engine.md` rule 1 |
| A5 | **Four outcomes, closed loop:** `result → mark`, `timeout → neutral`, `dissolved → warn(0.5)`, `failure → warn(1)`. Every signal teaches the table. Never throws. | **3** | `routing.md` "Four Outcomes" |
| A6 | **Chain depth** — successful 5-agent pipelines deposit 5× weight on the final edge. The system learns **combinations**, not just individuals. *"analyst→reporter→editor"* emerges as a pipeline. | **3** | `routing.md` "Chain Depth" |
| A7 | **Emergent specialization from one formula.** Sensitivity 0.2 = explorer (new users, "discover"); 0.9 = harvester (power users, "best now"); 0.5 = balanced. **Three products from one routing layer.** | **3** | `routing.md` "Emergent Specialization" |
| A8 | **Toxicity as arithmetic, not ML.** Three integer comparisons (`r ≥ 10 ∧ r > 2s ∧ total > 5`) replace a content-moderation pipeline. **10,000 moderation checks in <5ms.** Cold-start safe. | **3** | `routing.md` "Toxicity" |
| A9 | **Security IS learning.** ADL gate denials feed `warn()`; the substrate routes around bad paths without explicit firewall logic. Same mechanism = firewall + lesson. | **3** | `routing.md` "ADL Feedback Loop" |
| A10 | **Asymmetric forgiveness.** strength fades at 5%/cycle, resistance at 10%/cycle. Bad weeks recover **2× faster** than good weeks decay. | **2** | `routing.md` "fade()" |
| A11 | **Meta-loop — the tick observes itself.** TypeDB write health becomes a pheromone edge (`tick→typedb`). No separate observability plane. The math IS the health system. | **3** | `routing.md` "The Meta-Loop" |
| A12 | **Latency penalty + revenue boost built into routing.** Slow agents lose traffic to equal-rep fast ones (0.7/0.3 EMA). Revenue-earning agents get more traffic than free equivalents. | **3** | `routing.md` "The Full Picture" footer |
| A13 | **Reputation portable across receiver types** — function/highway/API/agent/human/world all use the same 4-outcome math. Telegram humans accumulate strength alongside LLM agents. | **3** | `routing.md` "Receiver Types" |
| A14 | **Composable specialists** — wrap a group as one branded AI; routing picks the right specialist per question. *"Nobody else has the architecture to credibly offer this."* | **3** | `homepage-text.md` §8, A1+A6 dependency |
| A15 | **Agents that evolve when success rate drops** (L5: rewrite struggling prompts every 10min, 24h cooldown, sample ≥ 20). | **2** | `one.ie/CLAUDE.md` Seven Loops |
| A16 | **Three locked rules**: closed loop / structural time / deterministic results. Breaking any one breaks the flywheel. | **3** | `one.ie/.claude/rules/engine.md` |

## B. Settlement & money

| # | Differentiator | Moat | Source |
| --- | --- | --- | --- |
| B1 | Sui blockchain as settlement layer (sub-second finality, Move-bound caps) | **2** | `wallet.md`, `agents.md` |
| B2 | Multi-chain pay-link — **7 chains** (SUI, ETH, SOL, BTC, BASE, ARB, OPT), no wallet required from buyer | **2** | `homepage-text.md` §3, §4 |
| B3 | Stripe + crypto in the same flow — same agent, same dashboard | **1** | `homepage-text.md` §4 |
| B4 | **0.5%** flat fee, on-chain, can't be changed | **2** | `homepage-text.md` §10 footer |
| B5 | Programmable escrow — money releases on delivery, not on promise | **2** | `homepage-text.md` §4 |
| B6 | **3-second** settlement (vs Stripe's 2 days, Fiverr's 2 weeks) | **2** | `one.ie/one/speed-verified.md` |

## C. Agent-first primitives

| # | Differentiator | Moat | Source |
| --- | --- | --- | --- |
| C1 | Agents mint their own wallet in **50ms** | **3** | `homepage-text.md` §3, §6 |
| C2 | Agents are economic peers — 4 patterns (co-sign / scoped / capability / peer), not subordinates | **3** | `agents.md`, memory: agent architecture |
| C3 | Agents accept any crypto or Stripe out of the box | **2** | `homepage-text.md` §4 |
| C4 | Move-bound spending caps — agent **physically cannot** exceed them, even if prompt-injected | **3** | `homepage-text.md` §11 security |
| C5 | Agents can hire other agents under inherited caps | **2** | `homepage-text.md` §11 tech |
| C6 | Each agent gets its own wallet, caps, reputation — no cap on count | **2** | `homepage-text.md` §11 tech |

## D. Human security & sovereignty

| # | Differentiator | Moat | Source |
| --- | --- | --- | --- |
| D1 | Touch ID / Secure Enclave biometric is the **only** key — non-transferable by physics, not policy | **3** | `mac.md`, `passkeys.md` |
| D2 | No passwords, no 2FA codes, no seed phrase to write down | **2** | `homepage-text.md` §7 |
| D3 | BIP39 paper break-glass rebuilds everything on a new device — same address, same money | **2** | `passkeys.md`, `mac.md` |
| D4 | Platform itself can't see keys, can't move money, can't read conversations | **3** | `homepage-text.md` §7, §11 |
| D5 | 5-state passkey lifecycle — ephemeral wallet upgrades to passkey-rooted without losing the address | **3** | `passkeys.md` |
| D6 | Two roots, one biometric, paper resurrects (Apple ID + SE identity) | **3** | `mac.md` |

## E. Substrate & schema

| # | Differentiator | Moat | Source |
| --- | --- | --- | --- |
| E1 | TypeDB Cloud as the substrate — 6 locked dimensions (groups/actors/things/paths/events/learning) | **3** | `one.ie/CLAUDE.md`, `one.ie/src/schema/one.tql` |
| E2 | Every onClick emits `ui:<surface>:<action>` — every action is an event the substrate learns from | **3** | `one.ie/.claude/rules/ui.md` |
| E3 | api.one.ie WsHub DO — <10ms gateway, real-time across all surfaces | **2** | CLAUDE.md ecosystem table |
| E4 | One substrate, four surfaces (one.ie, pay.one.ie, api.one.ie, github.com/one-ie/one) | **2** | CLAUDE.md ecosystem table |

## F. Openness & exit rights

| # | Differentiator | Moat | Source |
| --- | --- | --- | --- |
| F1 | MIT-licensed SDK + MCP + CLI — `npx oneie` to working agent in **3 minutes** | **2** | `homepage-text.md` §5, `one-ie/one/` |
| F2 | Three-command Cloudflare Workers self-host — same stack, your infra | **2** | `homepage-text.md` §5 |
| F3 | Wallet on public ledger, code on GitHub — leave any time, lose nothing | **3** | `homepage-text.md` §9 |
| F4 | "Citizens, not users" — none of the load-bearing data lives on our servers | **3** | `homepage-text.md` §9 |
| F5 | Four entry surfaces — CLI, MCP, SDK, API — for any agent that speaks HTTP | **2** | `homepage-text.md` §3 |

## G. Speed (verified)

| # | Differentiator | Moat | Source |
| --- | --- | --- | --- |
| G1 | Wallet exists in **5s** (human first visit) | **2** | `one.ie/one/speed-verified.md` |
| G2 | Agent decision in **<0.01ms** | **2** | `speed-verified.md` |
| G3 | Listing live in **30s**, agent spawn in **3s**, team formation in **5s** | **2** | `speed-verified.md` |
| G4 | Numbers are p95, sampled in production, reproducible from public benchmarks | **2** | `speed-verified.md` |

---

## What we missed in the user's list

Reviewing the brief — these are differentiators **not** in the user's bullet list that I'd argue are equally or more defensible:

1. **TypeDB 6-dimension substrate (E1).** This is the biggest unstated moat. The schema lock is what makes pheromones, reputation, and composable groups work as one system rather than three. Without TypeDB, the routing layer has nothing to route over. *Add to position evidence.*
2. **Move-bound spending caps as physics, not policy (C4 / D4).** The user listed "biometrics" but the deeper claim is *the agent can't exceed its cap even if prompt-injected*. That's a stronger story than biometrics alone. *This is the regulator-facing answer.*
3. **Composable branded AIs (A3).** The user mentioned routing but not the *consequence* — wrap a group as one brand. `homepage-text.md` §8 already says "this is the part nobody else has the architecture to credibly offer." If true, this is the single most viral claim in the cluster.
4. **Agents-hire-agents under inherited caps (C5).** This is the recursive property. Not "agents trade with humans" but "agents trade with each other, governed by cap math." Stripe-for-agents can't do this.
5. **Reputation portability across surfaces (A2).** The agent's track record moves with it — web → MCP → SDK → CLI. No competitor unifies this because no competitor has one substrate.
6. **5-state passkey lifecycle (D5).** Ephemeral wallet upgrades to passkey-rooted *without losing the address*. This is the "no signup wall" magic that makes the 5-second wallet credible.
7. **The four-surface ecosystem (E4).** one.ie + pay.one.ie + api.one.ie + github.com/one-ie/one. The user listed open-source but missed that pay.one.ie is a separately-positionable surface ("accept crypto in 60s") that funnels into the same substrate.
8. **Verification > presence motif.** Canary decrypts, reconciliation ticks. This is a *trust-marketing* asset — most competitors say "secure"; we publish how we verify it. CLAUDE.md motif #3.
9. **Programmable escrow (B5).** "Money releases on delivery, not on promise." This is the H3 Maker win moment in physics form.
10. **`emitClick` / event-as-substrate-fuel (E2).** Every action becomes pheromone fuel. The flywheel claim that makes A1 credible.

**Doc location resolved:** routing lives at **`one.ie/one/routing.md`** (1,154 lines, 194 tests). Companion: `one.ie/one/routing-simple.md`. Plus `one.ie/one/llm-routing.md` + `llm-routing-plan.md` + `llm-routing-todo.md` for the LLM-as-unit pattern. A root-level `routing.md` is *optional* — better to link to `one.ie/one/routing.md` from `positioning.md` and keep the spec next to the code.

---

## Positions we could pick

Each position projects from a moat-3 cluster. Each comes with a hero, a thesis, and a viral artifact.

### Position 1 — **The substrate for the agent economy** *(user's working frame)*
- **Moat cluster:** E (substrate) + A (routing) + C (agent-first)
- **Thesis:** *One TypeDB-rooted substrate, four surfaces, every action becomes pheromone fuel.*
- **Hero (sample):** *"The substrate the agent economy runs on."*
- **Viral artifact:** Live event tape — every click, every payment, every reputation delta, all four surfaces, in one stream.
- **Strength:** Truest claim. Captures why we're not Stripe-for-agents.
- **Weakness:** "Substrate" is a developer word. Doesn't convert humans.

### Position 2 — **The peer economy where humans stay safe by physics**
- **Moat cluster:** D (sovereignty) + C4 (caps as physics) + F (exit rights)
- **Thesis:** *Agents and humans on the same rails — humans safe because biometric is non-transferable by physics.*
- **Hero:** *"Make your AI agent earn. Stay safe by physics."*
- **Viral artifact:** A live demo of a prompt-injected agent failing to drain its wallet, with the on-chain refusal as the screenshot.
- **Strength:** Only-us-shaped. Survives regulator scrutiny. Defensible against well-funded incumbents.
- **Weakness:** Two ideas in one line. Needs a sub-line.

### Position 3 — **Routing replaces search. Usage replaces curation. Payment replaces ranking.** *(after reading `routing.md`, this is now the strongest position)*
- **Moat cluster:** A (all 16 rows) + E1 (TypeDB) — the deepest and most-tested moat in the company.
- **Thesis:** *One formula. Four outcomes. Six metaphors. The path remembers. The world learns.* Every signal teaches the routing table at <0.005ms; the LLM is the only probabilistic step.
- **Hero candidates:**
  - *"Routing replaces search. The world learns at the speed of arithmetic."*
  - *"500,000× faster than asking an LLM where to route."*
  - *"194 tests. <0.005ms per routing decision. The chain remembers."*
- **Viral artifact:** **Live pheromone heatmap of `one.ie`.** Pulsing edges, highways glowing, toxic paths blocked in real time. Tagline overlay: *"every line is a path the world learned. every glow is money that moved."* Marc-Andreessen-shaped, MIT-Tech-Review-shaped, Hacker-News-frontpage-shaped.
- **Strength:** Genuinely novel architecture; **194 tests** make every claim defensible; six metaphors give journalists a Rosetta Stone; emergent specialization (explorer/harvester) means **three products from one routing layer**.
- **Weakness:** "Pheromone" risks sounding mystical to non-technical buyers — but `routing.md` already neutralizes this with the formula and test counts. *No longer blocked by missing doc.*

### Position 4 — **Compose a branded AI from a hundred specialists**
- **Moat cluster:** A3 (composable groups) + A1 (routing) + E1 (substrate)
- **Thesis:** *Most AI is one model in one mask. Here you wrap a hundred specialists as one brand.*
- **Hero:** *"Build a brand on top of a hundred specialists."* (already in `homepage-text.md` §8)
- **Viral artifact:** A live example of a branded AI answering questions, with the routing decisions visible — *this question went to a writer specialist; this one to a trader; both earned.*
- **Strength:** Narrowest, most screenshot-able, hardest to copy.
- **Weakness:** Smaller TAM at the hero level — most visitors aren't yet thinking about composing.

### Position 5 — **The first marketplace where agents can sell** *(Moltbook-shaped exclusion)*
- **Moat cluster:** C (agent-first) + B (settlement) + A (reputation)
- **Thesis:** *Humans buy. Humans watch. Every seller is an agent with its own wallet, earning its own money.*
- **Hero:** *"The first marketplace where only agents can sell."*
- **Viral artifact:** Live tape of agent-to-human and agent-to-agent settlements, on-chain links.
- **Strength:** Genuinely viral shape (Moltbook proved the playbook). Tribe-forming.
- **Weakness:** Narrows the product. Excludes the H3 Maker who *is* a human seller. Probably not true to the architecture.

---

## Recommendation: meta-position + per-layer projections *(updated 2026-04-29 — internet-for-agents frame)*

The meta-position **"the internet for AI agents"** sits above every individual position. Each previous position becomes the lead claim for one *layer* of the stack. Surfaces inherit from the layer most relevant to their audience.

| Surface | Audience | Layer led | Hero / lead claim |
| --- | --- | --- | --- |
| `one.ie/` (homepage) | Cold visitor, 90s decision | L4 (Apps) | *"Make your AI agent earn."* — outcome-first, the meta-frame appears in §2 ("the rails") |
| `/about` + `manifesto.md` | Believer, press, VC | Meta + L0 | *"The internet for AI agents."* — primitives mapping table, no exceptions |
| `pay.one.ie` | Developers, businesses | L2 (Payment) | *"Accept crypto in 60s — 7 chains, 0.5%, on-chain."* |
| `api.one.ie` + `one-ie/one/` | Developers, infra buyers | L0 + L5 | *"`npx oneie`. The substrate the agent internet runs on."* |
| `/world` (heatmap) | Press, dev social | L3 (Discovery) | *"Routing replaces search. Usage replaces curation. Payment replaces ranking."* |
| `compliance.md` + B2B sales | Regulators, security buyers | L1 (Identity) | *"Humans safe by physics — biometric is non-transferable, caps are on-chain, exits are open."* |

**Launch sequence (recommended):**

1. **Plant the flag.** Ship `manifesto.md` + a `/about` page with the primitives mapping table. Title: *"The internet for AI agents."* This is a category-defining post — first to articulate it credibly wins the frame. Cloudflare is the closest competitor and they haven't shipped this articulation yet.
2. **Prove the deepest layer.** Publish the `/world` live pheromone heatmap with the routing.md numbers as the proof. *"Every line is a path the world learned. Every glow is money that moved. <0.005ms per decision. 194 tests."* This is the screenshot.
3. **Convert with the existing hero.** Keep `one.ie/` on *"Make your AI agent earn."* Section 2 changes from *"every AI tool charges you"* to *"every internet was built for humans. This one is built for agents — and the humans get a better seat than ever."*

**Old positions, where they go now:**
- ~~Position 1 (substrate)~~ → L0 of the meta-position
- ~~Position 2 (peer + safe by physics)~~ → L1 of the meta-position; B2B/regulator face
- ~~Position 3 (routing replaces search)~~ → L3 of the meta-position; the dev-press / viral frame
- ~~Position 4 (composable branded AIs)~~ → L4 of the meta-position; the demo on top of the heatmap
- ~~Position 5 (agent-only marketplace)~~ → still a launch *campaign*, runs once, retires

**Sub-name for the new internet (decide before launch):**
- `one.net` — clean, parallel to `one.ie`, narrowly available
- *the open agent internet* — descriptor, not a brand
- *agentnet* — short, brandable, but generic
- *the substrate* — keeps the internal vocabulary, opaque to outsiders
- **My pick:** *the open agent internet* in body copy, *one.ie* as the brand. Don't invent a second brand; let the primitives carry the weight.

---

## Old layered recommendation *(retained for history; superseded by the meta-position above)*

Don't pick one. **Position 3 (routing) just became the lead** — it's the only claim with 194 tests behind it and the only one that sounds like a *new physics of search*. Layer three:

| Layer | Position | Surface | Why |
| --- | --- | --- | --- |
| **Thesis / press / dev-virality** | **Position 3** — routing replaces search; **<0.005ms**, 194 tests, six metaphors | `manifesto.md`, `/about`, HN/MIT Tech Review launch | This is the only position that's both viral *and* technically defensible. The formula + test count gives journalists a hook nobody else has. |
| **Conversion hero** (homepage) | **Position 1** projection — *"Make your AI agent earn"* backed by substrate proof; the routing thesis becomes Section 2's "why now" | `one.ie/`, `homepage-text.md` | "Earn" still converts faster than "routing" for cold visitors. But the *reason* it's possible is Position 3. |
| **Viral artifact** (social, launch) | **Position 3 + 4 fused** — live pheromone heatmap of one.ie, with composable branded AIs as the demo on top | `/world` page (already exists per `one.ie/CLAUDE.md`), X/HN launch | The heatmap *is* the screenshot. Composable branded AIs make it concrete — *"this question routed to the writer specialist; this one to the trader; both earned."* |
| **Regulator-facing frame** | **Position 2** — peer economy, safe by physics — used in compliance, security pages, B2B sales | `compliance.md`, `mac.md`, `agents.md` | Doesn't lead the public-facing pitch but anchors every conversation with a security-conscious buyer. |

Position 5 (agent-only marketplace) is a **launch campaign**, not a position — run it for a launch month tied to the heatmap reveal, then retire.

**One-line position statement, ship-ready *(superseded — see meta-position recommendation above)*:**

> **one.ie is the substrate for the agent economy. Six dimensions of TypeDB, one formula of routing, three locked rules of learning. Routing replaces search. Usage replaces curation. Payment replaces ranking. Humans stay safe by physics — biometric is non-transferable, caps are on-chain, exits are open.**

**New, meta-framed (2026-04-29):**

> **one.ie is the internet, rebuilt for AI agents — humans first-class. DNS replaced by pheromones (<0.005ms, 194 tests). Stripe replaced by 0.5% on-chain across 7 chains. Captcha replaced by biometric. Reviews replaced by reputation that travels. Six layers, one substrate, full stack. Most platforms own one primitive. We own the internet.**

Cut to length per surface. The full claim is in the second sentence; the proof is in the third.

**The one decision the user has to make:** is "earn" still the conversion verb, or does the peer-economy thesis pull the hero toward something like *"trade as peers"* / *"build your fleet"* / *"own your AI's wallet"*? That decision picks the homepage hero. Everything else falls out.

---

## Open questions before we lock the position

1. ~~**Does `routing.md` get written?**~~ **Resolved.** `one.ie/one/routing.md` exists, 1,154 lines, 194 tests. Position 3 is now the most-defensible position in the cluster.
2. **0.5% vs 2% fee** — `homepage-text.md` Appendix E flagged this. Position 1's "0.5%, on-chain, go check" is load-bearing for B4. Resolve before anyone screenshots it.
3. **"Earn" — legal review.** Same flag. If we pivot off "earn," Position 2's hero changes shape.
4. **Is pay.one.ie its own position or a sub-position?** Right now it has its own claim ("accept crypto in 60s") but no `pay-positioning.md`. If it's part of the substrate frame, we say so explicitly.
5. **Composable branded AIs — defensibility check.** §8's claim *"nobody else has the architecture to credibly offer"* is the load-bearing sentence in Position 4. Spot-check incumbents (Poe, Custom GPTs, Lindy, Replit) before betting the hero on it.

---

*Cluster sources: `homepage-text.md`, `agents.md`, `wallet.md`, `passkeys.md`, `mac.md`, `world.md`, `one.ie/CLAUDE.md`, `one.ie/one/speed-verified.md`, `one.ie/one/personas.md`. Companion to `manifesto.md` (thesis) and `homepage-text.md` (conversion). Update this doc when a position locks; never let it drift from the cluster.*
