# home.md — ONE Home Page v4

**Classifier:** mode=lean · lifecycle=construction
**Exit scalar:** 24 sections render in `chatMode="wide"`, every "Show me" seeds a live chat, motion fires on scroll, page passes the 5-second test, `bun run verify` green, Lighthouse mobile ≥ 95.

> Median SaaS landing page converts at 3.8%. Top quartile clears 11.6%. Best-in-class crosses 18%. The gap is a stack of decisions documented here — each measurable, each cheap to verify.

---

## The thesis lock

**Headline:** *Your AI Workforce Awaits.*
**Spine:** Marketing · Sales · Service — three full teams, twenty-seven named roles, live the hour you sign.
**Hook:** Under your brand. On your invoice. The corpus stays with you.

The earlier "resell an AI brand" framing read as agency-only. Workforce reads as universal: every business needs marketing, sales, and service. Agencies sell it forward. Consultants deploy it for clients. Operators run it for themselves. One thesis, three audiences, one page.

---

## Goal

Replace the sparse 4-section home with a single conversion-grade page that:

1. **Promises an outcome the visitor can picture.** A workforce. Three departments. Twenty-seven roles. Live on day one.
2. **Walks the visitor through the teams, then the platform that powers them.** Every feature doc is integrated — not as a feature catalogue but as evidence the workforce is real.
3. **Closes on a named stake with one button.** Two exits, one chosen path: **Continue** → `/get-yours`, or **Chat** → the right-rail demo.

No nav. No links to sub-pages. The content is the prompt library; the chat is the live demo. Every section's *"Show me"* seeds a real conversation in the right rail.

---

## The journey — six acts, twenty-four sections

Each act has one job. Acts are emotional, not visual.

### Act 1 — The promise  (§1 · §2 · §3)
*Your workforce is already there. Here are the numbers. Here's why now.*

The visitor lands. In eight seconds they know what this is (an AI workforce), who it's for (anyone with clients to serve), and why it matters (cost-to-serve drops to software cost). The proof bar borrows authority through measurement. Then §3 names the structural shift — *"AI is changing both sides of the equation at once"* — and offers a persona picker so the chat opens in the visitor's own voice.

### Act 2 — Meet the three teams  (§4 · §5 · §6)
*Marketing. Sales. Service. Twenty-seven roles. Live the hour you sign.*

The showcase. Three full-bleed sections, one per team, each with the real org chart (Director + specialists, all named, all costed against a UK median salary band). This is the visual centerpiece of the page — visitors should be able to point and say *"that one, that's mine."*

### Act 3 — The platform that powers them  (§7–§12)
*Brand. Agents. Skills. Models. Tools. Memory. The substrate beneath the workforce.*

Six tight sections, alternating split-left and split-right, each answering one question: *what makes the workforce work?* Pulled verbatim from the locked feature docs (`01-brand.md` … `08-memory.md`).

### Act 4 — The single customer view  (§13 · §14 · §15 · §16)
*Tracking. CRM. Analytics. Learning. The records and reports that compound.*

The unified record story: every conversation joined, every record built itself, every report ships in 90 seconds, every quarter the agents get measurably better. The compounding moat (`10-tracking.md` … `13-learning.md`).

### Act 5 — The technical foundation  (§17 · §18 · §19)
*Development. Speed. Security. The bones the rest stands on.*

How the platform is built (markdown agents, CLI publish), measured (eight surfaces, every number dated, this page measuring itself live), and protected (open-source substrate, escrowed product layer, corpus stays with the customer).

### Act 6 — Make it yours  (§20–§24)
*The math. The founder. The objections. The stake. The action.*

The credit math becomes concrete. Anthony, named, signs the work. Five objections answered without hedging. The stake — *be the one they copy.* One button. **Hire my workforce.**

The chat is the always-present sixth surface. At any point in the journey, "Show me" seeds a real conversation in the right rail.

---

## Architecture

### Layout mode
- `chatMode="wide"` — 55/45 content/chat split on desktop (CSS grid: `minmax(0,55fr) clamp(480px,45vw,720px)`).
- `chatLock={false}` — user can minimize; default is open.
- Mobile: grid collapses to 1fr; chat falls back to widget (FAB + sheet).

The current home uses `chat-full`. The new home uses `wide`: content scrolls left, chat stays sticky right.

### The bridge (already wired — no new protocol)

```ts
function dispatchSeed(text: string, persona?: string) {
  window.__chatSeedPending = { text, persona }
  window.dispatchEvent(new CustomEvent('one:chat-seed', { detail: { text, persona } }))
  if (window.matchMedia('(min-width: 768px)').matches) {
    document.documentElement.dataset.chatMode = 'wide'
    localStorage.setItem('one:chat-mode', JSON.stringify('wide'))
    window.dispatchEvent(new CustomEvent('one:chat-mode', { detail: 'wide' }))
  }
}
```

`Chat.tsx:344-367` already consumes `one:chat-seed` and drains `__chatSeedPending`. Copy the function from `Personas.tsx`; do not re-derive.

### Motion primitives (all already built)

| Primitive | Path | Use |
|---|---|---|
| `Reveal.astro` | `components/motion/Reveal.astro` | Every section heading — scroll-triggered fade-up |
| `Stagger.astro` | `components/motion/Stagger.astro` | Team org-chart roles; bento-style platform sections |
| `ScrollCounter` | `components/motion/demo/ScrollCounter.tsx` | Proof bar; math section; speed receipt |

No new motion primitives. Cadence — dense ↔ quiet — does the elegance work.

### Beauty rules (the cadence)

Twenty-four sections is long. Elegance comes from rhythm. Every dense section is followed by a quiet one; every showcase is followed by a single thought.

| § | Section | Density |
|---|---|---|
| 1 | Hero | dense (headline, sub, 2 CTAs, micro) |
| 2 | Proof bar | quiet (4 animated numbers) |
| 3 | Why now | quiet (60ch paragraph + 3 persona buttons) |
| 4 | Marketing team | **showcase** (org chart, full-bleed) |
| 5 | Sales team | **showcase** (org chart, full-bleed) |
| 6 | Service team | **showcase** (org chart, full-bleed) |
| 7 | Brand | medium split |
| 8 | Agents | medium split |
| 9 | Skills | medium split |
| 10 | Models | medium split |
| 11 | Tools | medium split (logo grid right) |
| 12 | Memory | medium split |
| 13 | Tracking | medium split |
| 14 | CRM | medium split |
| 15 | Analytics | medium split (sample report visual) |
| 16 | Learning | medium split (loop diagram) |
| 17 | Development | quiet (code-focused) |
| 18 | Speed | **showcase** (comparison table + live receipt) |
| 19 | Security | medium (4-pillar grid) |
| 20 | The math | **showcase** (oversized number, one sentence) |
| 21 | Founder | quiet (portrait + 2 paragraphs) |
| 22 | FAQ | dense (5 accordion rows + ask-anything) |
| 23 | The stake | quiet (single sentence, large type) |
| 24 | Final CTA | quiet (one button, one promise) |

Dense → showcase → quiet → medium → showcase → quiet. The eye gets to rest. The mind gets to weigh.

---

## The 24 sections

Every section ships with: optional eyebrow, a headline (with one `text-tertiary` highlight word), a body of 1–3 sentences, an optional visual, and exactly one `<ChatSeedButton>` at bottom-right of the copy block (with §4–§6 special-cased to two — *"Hire this team"* + *"Show me their work"*).

### Act 1 — The promise

| § | Section | Layout | Headline · *highlight* · body | Chat seed |
|---|---|---|---|---|
| 1 | **Hero** | centered, full-bleed | **"Your AI Workforce Awaits."** · *Awaits* · "Marketing, sales, and service — three full teams, twenty-seven roles, live the hour you sign. Under your brand. On your invoice. The corpus stays with you." | "Walk me through how I get a full marketing, sales, and service team live this week." |
| 2 | **Proof bar** | 4-metric strip | *(no headline)* — `5s wallet · 60s bot live · 48h deployment · 90s report` | *(no button — `ScrollCounter` auto-fires)* |
| 3 | **Why now** | centered, 60ch + 3-button persona picker | **"Every win used to be a hire. Not any more."** · *hire* · "Forrester forecasts a 15% reduction in agency roles in 2026. The cost-to-serve a client is collapsing from headcount to software. The platforms built on this shift will be uncatchable in three years." | *(see persona picker detail below)* |

### Act 2 — Meet the three teams  (the showcase)

| § | Section | Layout | Headline · *highlight* · body | Chat seed |
|---|---|---|---|---|
| 4 | **Marketing** | team-org (split-right, copy left, org chart right) | **"A full marketing department. Day one."** · *day one* · "Director + eleven specialists. Brand, copy, SEO, paid, social, design, PR, lifecycle, events, analytics. UK median salary for this team: £800k–£1.2M per year. The substrate cost runs to hundreds of pounds per client per month." | "Show me the marketing team in action for a new retail client." |
| 5 | **Sales** | team-org (split-left, org chart left, copy right) | **"A full sales department. Pipeline filled the day they go live."** · *filled* · "Director + seven specialists. SDR, outbound, AE, SE, deal desk, CS, analyst. Median first-response on a tier-1 inbound: 47 seconds. UK median payroll for this team: £600k–£900k." | "Walk me through a sales agent qualifying an inbound lead in real time." |
| 6 | **Service** | team-org (split-right, copy left, org chart right) | **"A full service department. No ticket waits."** · *waits* · "Director + six specialists. Tier-1, tier-2, onboarding, complaints, knowledge curator, analyst. After eight weeks live, repeat queries drop 40–60%. UK median payroll for this team: £400k–£600k." | "Demo the service team for a returning customer who asks a complaint question." |

### Act 3 — The platform that powers them

| § | Section | Layout | Headline · *highlight* · body | Chat seed |
|---|---|---|---|---|
| 7 | **Brand** | split-right | **"Your name on everything."** · *everything* · "OAuth screen, invoice, 404 page, every system email — all carry your wordmark and tokens. Six CSS variables. The platform disappears behind your brand." | "Show me white-labeling. I want my clients on my domain, not yours." |
| 8 | **Agents** | split-left | **"An agent is a markdown file you own."** · *own* · "Edit in minutes. Redeploy in seconds. No release cycle. The IP is yours, not ours — 150× the throughput of a human at a fraction of the cost." | "Show me what an agent file looks like and how I'd change the tone for a specific client." |
| 9 | **Skills** | split-right | **"Build once, deploy everywhere."** · *everywhere* · "A skill is reusable capability — publishable from the CLI, revenue-tracked per use, reusable across every client and every team in the workforce." | "Give me an example skill that a marketing agent would reuse across all my clients." |
| 10 | **Models** | split-left (cost/quality/speed feature tabs) | **"300+ models. You pick per agent."** · *you pick* · "Per skill. Per cost target. Bring your own keys. When prices drop next quarter, you keep the margin." | "I want cheap for support tickets and smart for sales. How do I bind models per agent?" |
| 11 | **Tools** | split-right (8-tool logo grid) | **"Your agents work as the customer."** · *as the customer* · "250+ integrations. Read their Gmail, post their Slack, update their HubSpot — all through a white-label OAuth screen carrying your name." | "Can my agent post to a customer's Slack as them? Walk me through the OAuth flow." |
| 12 | **Memory** | split-left (5-type diagram) | **"The corpus is yours."** · *yours* · "Every conversation makes the next one better. Five memory types — short-term, long-term, semantic, episodic, procedural. Legally and physically yours, even if a client leaves." | "If a client leaves me, what do I keep? Walk me through the data and the contract." |

### Act 4 — The single customer view

| § | Section | Layout | Headline · *highlight* · body | Chat seed |
|---|---|---|---|---|
| 13 | **Tracking** | split-right | **"One inbox. Every channel."** · *Every channel* · "Web, WhatsApp, Discord, iMessage, email, voice. 95% identity resolution. The customer who DM'd this morning is the same one who visited the site last week. Joined on one record." | "A customer messaged on WhatsApp this morning and visited the site last week. Is that one record?" |
| 14 | **CRM** | split-left | **"The record builds itself."** · *itself* · "No import. No sync. No separate seat. Actors in the conversation are the CRM — the record assembles from the work as it happens." | "Where does the contact data come from? Do I need to import a CSV?" |
| 15 | **Analytics** | split-right (sample report visual) | **"The monthly report that wins renewals."** · *wins renewals* · "90 seconds to generate. Every number drillable to the conversation that earned it. Six-block structure. The artefact every client sees and renews on." | "Generate a sample monthly report for a client with 200 conversations and 12 leads last month." |
| 16 | **Learning** | split-left (loop diagram) | **"Every quarter, the gap widens."** · *widens* · "Seven feedback loops. The successful paths harden into highways. The competitor who buys the same model doesn't get the corpus. The model is a commodity. The corpus is the moat." | "Show me a real before/after — how does the workforce get measurably smarter on my data?" |

### Act 5 — The technical foundation

| § | Section | Layout | Headline · *highlight* · body | Chat seed |
|---|---|---|---|---|
| 17 | **Development** | code-focused, centered narrow | **"A markdown file and a CLI command."** · *markdown* · "Agents are markdown. Skills publish from the CLI. Your engineers extend the workforce without touching the substrate. Your IP, your artefacts." | "How does my developer extend an agent? Show me the editing flow." |
| 18 | **Speed** | split-left (table) + live receipt panel right | **"Speed is a measurement. Not a claim."** · *measurement* · "Eight surfaces measured. Lighthouse 100/91/100/100 on /chat. TTFT 97ms versus 1,400ms on ChatGPT. 107-second deploy. Five-second wallet. Every number dated, every test reproducible." | "Show me the Lighthouse score on /chat right now, compared to ChatGPT and Claude." |
| 19 | **Security** | 4-pillar grid | **"Open source. In escrow. Yours."** · *Yours* · "Substrate is open source. Product layer in escrow. Corpus is legally yours. GDPR deletion in one command. Threat model is a table, not a promise." | "What happens if you go out of business? Can I take my data and run? Walk me through the escrow." |

### Act 6 — Make it yours

| § | Section | Layout | Headline · *highlight* · body | Chat seed |
|---|---|---|---|---|
| 20 | **The math** | centered, oversized number with `ScrollCounter` | **"$5.4M ARR. 90%+ gross margin. The corpus is yours."** · *yours* · "Buy 5,000,000 credits at $500. Set your markup. Distribute to clients — or use directly for your business. The math works at five clients or five hundred." | "Walk me through the credit math for my situation. What's the margin in year one?" |
| 21 | **Founder** | split-right (portrait left, two paragraphs right) | **"Built by an engineer who reads the codebase and writes the landing page."** · *(no highlight)* · *"I'm Anthony. Thirty years building websites. Eight years building AI. I built ONE because the agencies that already have distribution should own the AI layer their clients run on. The substrate is open source. The corpus is yours. If we disappear, you walk away with everything."* — Anthony O'Connell, Founder | "I want to understand the philosophy. Why did you build this, and why now?" |
| 22 | **FAQ** | 5-row accordion + 6th-row "ask anything" `<ChatSeedButton>` | **"The five questions every serious buyer asks."** · *(no highlight)* · *(rows below — see FAQ detail)* | "I have a different question — let me ask it directly." |
| 23 | **The stake** | centered, large type, generous whitespace | **"Two years from now, the platforms your peers are copying will be the ones that own a corpus."** · *copying* · "Be the one they copy." | "What changes between moving now and waiting six months? Show me both timelines." |
| 24 | **Final CTA** | centered, full-bleed | **"Hire your workforce."** · *(highlight on CTA)* · "One client. Forty-eight hours from sign to live. The corpus is yours either way." | "I'm ready. What happens in the first 48 hours after I start?" |

---

## Section details that need more than a table row

### §3 persona picker

Beneath the §3 paragraph, three ghost `<ChatSeedButton>`s side-by-side, each labelled with a visitor type and an icon. Clicking any one opens the chat with a tailored seed. The three buttons replace the generic single seed for §3 only.

| Button label | Icon | Seed dispatched |
|---|---|---|
| **"I run an agency"** | `Building2` | "I run an agency with around 200 clients. How does ONE become the platform I resell, with my brand on every screen?" |
| **"I run a business"** | `Briefcase` | "I run a business and want a full marketing, sales, and service workforce of my own. Where do I start?" |
| **"I'm a consultant"** | `UserCircle` | "I'm a consultant who deploys AI for clients. How does ONE become the infrastructure underneath my consulting work?" |

The rest of the page continues regardless of which path is picked — the visitor stays on the page; only the chat thread diverges.

### §4 · §5 · §6 — Team sections

Each team section is a split layout: copy on one side, the **TeamOrgChart** component (see full spec below) on the other.

- **Copy column (50%)** — eyebrow ("Marketing" / "Sales" / "Service"), headline, body, payroll math callout, two CTAs:
  - **Primary** — *"Hire this team"* → `/get-yours?team=marketing` (etc.)
  - **Secondary** — `<ChatSeedButton variant="secondary" label="Show me their work">`
- **Org-chart column (50%)** — `<TeamOrgChart>` component, fed a single `team` data object from `home-sections.ts`.

The split alternates direction: §4 chart-right, §5 chart-left, §6 chart-right. The eye scans differently on each, so the three teams never read as repetition.

Marketing team roles (12 total): Marketing Director, Brand Manager, Copywriter, SEO Lead, Advertising Manager, Media Buyer, Social Media Manager, Designer, PR / Comms, Email / Lifecycle, Events, Marketing Analyst.

Sales team roles (8 total): Sales Director, SDR / Qualifier, Outbound Rep, Account Executive, Solutions Engineer, Deal Desk, Customer Success Lead, Sales Analyst.

Service team roles (7 total): Service Director, Tier-1 Support, Tier-2 Specialist, Onboarding Agent, Complaint Handler, Knowledge Curator, Service Analyst.

**Sum: 27 named roles.** That number is the load-bearing claim of the entire page — it gets surfaced in §4's payroll callout, in the math (§20), and in the founder voice (§21). Asserted in tests.

### §18 — Speed live receipt

The section that proves the speed thesis must prove it on the surface making the claim.

- **Left column (table)** — the 3-row comparison from `text/16-speed.md`:

  | Platform | TTFT p50 | Lighthouse Perf | JS payload |
  |---|---|---|---|
  | ONE /chat | **97ms** | **100** | **248 KB** |
  | Claude.ai | ~1,200ms | 66 | 4.9 MB |
  | ChatGPT | ~1,400ms | 51 | 4.4 MB |

- **Right column (live receipt panel)** — a three-line block filled at runtime:

  ```
  this page loaded in 0.42s
  first token of this chat: 84ms
  /chat Lighthouse today: 100 / 91 / 100 / 100   measured 2026-05-15
  ```

  Line 1: `(performance.timing.loadEventEnd - performance.timing.navigationStart) / 1000` to two decimals.
  Line 2: wired from the chat island's first-token timestamp.
  Line 3: hardcoded from the most recent measurement with a `data-measured-at` ISO date in HTML.

The receipt makes the page its own demo. A speed claim that times itself is hard to disbelieve.

### §22 — FAQ (the five questions, answered without hedging)

Pulled from the objection ladder in `text/persona-agency-owner.md` §10 — the same fears surface regardless of visitor type. Each answer ≤ 40 words. No marketing softeners.

1. **"What if you pivot or get acquired?"** — Substrate is open source. Product layer in escrow. Walk away with every conversation and every trained agent in one export command.
2. **"What if my clients realise it's AI and demand a discount?"** — Tier 1 ships in your brand only. Tier 3 lets them name the model and pay more. Most don't ask; the ones who do, you charge.
3. **"What about GDPR and state AI law?"** — Per-client data space. Deletion in one command. Named retention windows. The threat model is a table, not a promise.
4. **"What if the AI says something stupid in front of a client?"** — Voice contract enforced before every outbound message. Quality gate at 0.65. Below the gate, nothing ships.
5. **"Why now?"** — Six platforms now. Three in eighteen months. Three years from now the corpus winners are uncatchable. The platforms that move now build the corpus. The corpus is the moat.

Sixth row, always visible, is the "different question" row: a single `<ChatSeedButton>` labelled *"My question's different — ask it"* that opens the chat with focus on the input.

### §24 — Final CTA

- **Headline:** "Hire your workforce."
- **Subhead:** "One client, or your whole business. Forty-eight hours from sign to live. The corpus is yours either way."
- **Primary button:** "Hire my workforce" → `/get-yours`
- **Microcopy under button:** "5,000,000 credits for $500. No annual contract. Mark up and distribute on your schedule."
- **Secondary:** *"Talk to the founder first"* → `<ChatSeedButton text="I want to talk to the founder before I start. What changes for me in the first 30 days?">`

No third CTA. The eye picks one.

---

## New components

Six components + one data file. Two of them — `TeamOrgChart` and `SpeedReceipt` — are specialized renderers fed by data; `SectionBlock` composes them through layout slots, never re-implementing their internals.

### 1. `HomeHero.tsx`  · **≤ 90 LOC**
**Path:** `web/src/components/HomeHero.tsx`

Composes `Hero.tsx` for the headline shell; reads `visitorHash` + `slug` for personalization via `pickHeroVariant`; renders two CTAs:

- **Primary** — `<a href="/get-yours">Hire my workforce</a>` with microcopy beneath: *"5,000,000 credits for $500. Pilot one client. No annual contract."*
- **Secondary** — `<ChatSeedButton variant="secondary" text="..." label="Show me my team">`

No third CTA. Personas picker moves to §3.

```tsx
interface HomeHeroProps {
  visitorHash?: string
  slug?: string
  linkGreeting?: string
  linkActor?: string
}
```

### 2. `ProofBar.tsx`  · **≤ 70 LOC**
**Path:** `web/src/components/ProofBar.tsx`

Replaces `Buyers.tsx`. Four metrics:

| Metric | Value | Label |
|---|---|---|
| 1 | **5s** | first wallet, p50 |
| 2 | **60s** | live client chatbot |
| 3 | **48h** | fully-tuned deployment |
| 4 | **90s** | monthly client report |

Each wraps `<ScrollCounter>` so the number animates up on viewport entry; staggered via `style={{ '--i': i }}`.

Caption beneath, in `text-font/50 text-sm`: *"Eight surfaces measured. Every number dated and reproducible — see §18."*

### 3. `ChatSeedButton.tsx`  · **≤ 50 LOC**
**Path:** `web/src/components/ChatSeedButton.tsx`

The conversion primitive used by every section.

```tsx
interface ChatSeedButtonProps {
  text: string                              // prompt sent to chat
  persona?: string                          // optional persona tag
  label: string                             // button label (e.g. "Show me my team")
  variant?: 'primary' | 'secondary' | 'ghost' | 'tile'
  icon?: LucideIcon
  emit?: string                             // override emitClick suffix (default: section.id)
}
```

Each click fires `emitClick('ui:home:chat-seed', { section, text })` then dispatches `one:chat-seed`. Copies `dispatchSeed` from `Personas.tsx` verbatim. **First-person labels** outperform second-person by 15–20% (CXL).

### 4. `TeamOrgChart.tsx`  · **≤ 180 LOC** — the visual centerpiece
**Path:** `web/src/components/TeamOrgChart.tsx`

The component that makes the 27-role claim *visible*. Renders one full department per render — Marketing (12 roles), Sales (8), or Service (7) — as a beautiful, restrained hierarchy. Used three times on the page (§4, §5, §6) and nowhere else.

```tsx
interface OrgRole {
  title: string                              // "Marketing Director" · "SDR / Qualifier" · "Tier-1 Support"
  icon: LucideIcon                           // lucide-react icon
  blurb: string                              // one-line role description, ≤ 60 chars
  chatSeed?: string                          // optional click → seed chat with role-specific prompt
  tone?: 'primary' | 'secondary' | 'tertiary' | 'neutral'   // default 'neutral' for specialists
}

interface TeamOrgChartProps {
  department: 'marketing' | 'sales' | 'service'   // used for data-attribute + aria-label
  director: OrgRole                                // tone defaults to 'primary' regardless of input
  specialists: OrgRole[]                           // 6, 7, or 11 — never 0
  ceoLabel?: string                                // default: "the client's CEO — the only human at the top"
}
```

#### Visual structure (the design)

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   CEO · the only human at the top              ← caption,    │
│                  │                               text-xs,    │
│                  │                               40% opacity │
│        ┌─────────┴─────────┐                                 │
│        │   ▣  Marketing    │   ← Director card:              │
│        │      Director     │     larger (col-span-2),        │
│        │  strategy · OKRs  │     primary-toned IconBadge,    │
│        │   · weekly digest │     border-primary/20,          │
│        └───────────────────┘     bg-primary/[0.03]           │
│                                                              │
│   ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                       │
│   │ ◇ R1 │ │ ◇ R2 │ │ ◇ R3 │ │ ◇ R4 │   ← Specialists grid: │
│   └──────┘ └──────┘ └──────┘ └──────┘     4 cols desktop,    │
│   ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐     2 cols tablet,    │
│   │ ◇ R5 │ │ ◇ R6 │ │ ◇ R7 │ │ ◇ R8 │     1 col mobile     │
│   └──────┘ └──────┘ └──────┘ └──────┘                       │
│   ┌──────┐ ┌──────┐ ┌──────┐                                │
│   │ ◇ R9 │ │ R10  │ │ R11  │   ← each card:                 │
│   └──────┘ └──────┘ └──────┘     IconBadge (md, neutral)    │
│                                  + title (font-semibold)     │
│                                  + blurb (text-sm/60)        │
│                                  + hover -translate-y-0.5    │
└──────────────────────────────────────────────────────────────┘
```

**Hierarchy is communicated by three signals, not by literal lines:**
1. **Position** — CEO label is small text at top; Director card sits centered above the grid; specialists sit in a regular grid below.
2. **Size** — Director card spans 2 grid columns (`col-span-2`); specialist cards each span 1.
3. **Tone** — Director uses `text-primary` accent, `border-primary/20`, and a `bg-primary/[0.03]` wash; specialists are neutral cards.

A single optional **thin vertical line** (1px, `bg-foreground/8`, 24px tall) descends from the CEO label to the Director card to suggest the reporting line. No lines from Director to specialists — visual hierarchy carries the relationship, and lines from one box to many quickly read as corporate. Restraint is the brief.

#### Layout

- Outer container: `flex flex-col gap-8 items-center text-center`.
- CEO caption: `text-xs uppercase tracking-[0.18em] text-font/40` — sits above everything, no card.
- Director: `<article>` card, `p-6 lg:p-7`, `rounded-2xl`, accent classes above. Centered, max-width `420px`.
- Specialists grid: `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 w-full`. Mobile collapses to a single column for readability — the 11 marketing roles would be illegible squeezed into a tablet grid.

#### The role card

A single role card (used for both Director and specialists; tone is the only difference):

```tsx
<article
  className="group rounded-2xl border bg-background p-5 lg:p-6
             transition will-change-transform
             hover:-translate-y-0.5 hover:shadow-lg
             focus-within:-translate-y-0.5 focus-within:shadow-lg
             stagger-child"
  style={{
    borderColor: 'var(--color-border)',
    boxShadow: 'var(--shadow-card)',
    '--i': index,
  }}
>
  <IconBadge icon={role.icon} tone={role.tone ?? 'neutral'} size="lg" />
  <h3 className="mt-3 font-semibold text-base lg:text-lg">{role.title}</h3>
  <p className="mt-1 text-sm text-font/60 leading-snug">{role.blurb}</p>
  {role.chatSeed && (
    <ChatSeedButton
      variant="ghost"
      text={role.chatSeed}
      label="Show me this role"
      className="mt-3 -ml-2"
    />
  )}
</article>
```

#### Motion choreography

The whole component is wrapped in `<Reveal dist="md">` at the page level (via `SectionBlock`). Inside the component:

1. **CEO caption** — fades in immediately on viewport entry (no stagger).
2. **Director card** — `stagger-child` with `--i: 0`, ~120ms in.
3. **Specialists** — `stagger-child` with `--i: 1..N`, ~60ms per item, cascading left-to-right, top-to-bottom.
4. **Total animation budget** — ≤ 1.2s for the 12-role marketing chart; shorter for sales/service.
5. **`prefers-reduced-motion`** — disables `stagger-child` keyframes via the existing global rule; component renders in final state immediately.

The stagger keyframes are the same `stagger-child` injected in `index.astro`'s global CSS — no new CSS introduced.

#### Click behaviour

- **CEO caption** — not clickable (it's a label, not an actor).
- **Director card** — clickable if `director.chatSeed` is set. Click fires `emitClick('ui:home:team:<dept>:director')` then dispatches `one:chat-seed` with the director's seed. Default seed if not specified: *"Show me how the {dept} director runs the department day-to-day."*
- **Specialist card** — clickable if `role.chatSeed` is set; same dispatch pattern. Default seed: *"Show me what the {role.title} actually does."*

Each card uses a `<button>` wrapping the inner content for proper focus and keyboard support, **OR** the entire `<article>` carries a `<ChatSeedButton variant="ghost" className="absolute inset-0">` overlay so the whole card is the hit target. Pick one — the overlay pattern is cleaner because the card content stays semantic. **Go with the overlay.**

#### Accessibility

- Outer container is a `<section aria-label="{department} department org chart">`.
- Specialists grid is `<ul role="list">` containing `<li>` per role.
- Director is `<header>` semantic inside the section, above the ul.
- Each role card is keyboard-focusable; focus ring is visible.
- Icon-only badges have `aria-hidden="true"`; the role title is the accessible name.
- Hover and focus produce the same visual lift (already in the snippet above).

#### Sample data flow

In `home-sections.ts`:

```ts
import { Crown, Megaphone, Pen, Search, Target, /* ... */ } from 'lucide-react'

export const MARKETING_TEAM: SectionTeam = {
  department: 'marketing',
  director: {
    title: 'Marketing Director',
    icon: Crown,
    blurb: 'strategy · budgets · OKRs · weekly digest to CEO',
    chatSeed: 'Show me how the Marketing Director runs the department.',
    tone: 'primary',
  },
  specialists: [
    { title: 'Brand Manager',        icon: Sparkles,    blurb: 'voice, positioning, guideline enforcement' },
    { title: 'Copywriter',           icon: Pen,         blurb: 'long-form, landing pages, emails' },
    { title: 'SEO Lead',             icon: Search,      blurb: 'keywords, audits, programmatic pages' },
    { title: 'Advertising Manager',  icon: Target,      blurb: 'paid acquisition strategy, briefs' },
    { title: 'Media Buyer',          icon: Wallet,      blurb: 'placements, budgets, rate negotiation' },
    { title: 'Social Media Manager', icon: Hash,        blurb: 'calendar, engagement, DMs' },
    { title: 'Designer',             icon: Palette,     blurb: 'assets, layouts, video cuts' },
    { title: 'PR / Comms',           icon: Newspaper,   blurb: 'journalist outreach, press releases' },
    { title: 'Email / Lifecycle',    icon: Mail,        blurb: 'drip campaigns, retention, win-back' },
    { title: 'Events',               icon: Calendar,    blurb: 'webinars, conference logistics' },
    { title: 'Marketing Analyst',    icon: BarChart3,   blurb: 'attribution, dashboards, weekly report' },
  ],
  payroll: '£800k–£1.2M / year',
  substrateCost: 'Hundreds of pounds per client per month',
}
```

Sales and Service teams follow the same shape with their respective roles. All role blurbs sourced verbatim from `text/09-teams.md`.

---

### 5. `SpeedReceipt.tsx`  · **≤ 80 LOC** — the page measures itself
**Path:** `web/src/components/SpeedReceipt.tsx`

A small live-data panel used once on the page (§18). The job: prove the speed claim *on the surface making the claim*. A speed receipt that times itself is hard to disbelieve.

```tsx
interface SpeedReceiptProps {
  lighthouseDate: string                     // ISO date of the latest /chat Lighthouse measurement
  lighthouseScores?: [number, number, number, number]   // perf · a11y · best · seo (default: [100, 91, 100, 100])
}
```

#### Visual structure

A single card (`bg-background border rounded-2xl p-6 lg:p-8`) with three lines stacked vertically, each in a monospace receipt style:

```
┌─────────────────────────────────────────────┐
│                                             │
│   this page loaded in   0.42s               │
│   first token of this chat  84ms            │
│   /chat Lighthouse today  100 / 91 /        │
│   100 / 100   measured 2026-05-15           │
│                                             │
└─────────────────────────────────────────────┘
```

Layout:
- Labels in `text-font/50 text-sm`.
- Numbers in `text-primary font-mono text-2xl lg:text-3xl tabular-nums font-semibold`.
- Lines separated by `border-t border-foreground/5` so they read as a receipt.
- The whole card has a subtle `bg-primary/[0.02]` wash to feel like a register strip.

#### Runtime behaviour

The three numbers are populated on mount:

1. **Page load** — `(performance.timing.loadEventEnd - performance.timing.navigationStart) / 1000`, fixed to 2 decimals. If `loadEventEnd === 0` (still loading), uses `performance.now() / 1000` and re-renders on `window.load`. Falls back to `"—"` if `performance` is unavailable.
2. **First token** — subscribes to a `window.dispatchEvent(new CustomEvent('one:chat-first-token', { detail: { ms: 84 } }))` event that `Chat.tsx` already fires (verify in W1 recon; if missing, add a 4-line emitter in `Chat.tsx:sendMessage` before this component lands). Default *"—"* until first token arrives in the right rail.
3. **Lighthouse** — hardcoded from props with a `time` element carrying `dateTime={lighthouseDate}` so the date is machine-readable.

#### Motion

Three lines appear in sequence:
- Line 1: 0ms — fade-up 8px over 240ms.
- Line 2: 200ms after — same.
- Line 3: 400ms after — same.

Once the page-load number lands, it animates from a previous value to the real value using a 600ms ease-out (`useReducedMotion()` skip — show final value immediately).

#### Why a separate component (not inline in SectionBlock)

Three reasons that make this worth its own file:
1. **Runtime side-effects** — `performance.timing` reads, event subscriptions, cleanup on unmount. SectionBlock should stay pure-data-in.
2. **Test isolation** — the page-load value needs a unit test with mocked `performance`; isolating the component makes that one file.
3. **Reusability** — `pay.one.ie`, `api.one.ie`, and `/chat` all want a speed receipt. Build once, use four times.

---

### 6. `SectionBlock.tsx`  · **≤ 220 LOC**
**Path:** `web/src/components/SectionBlock.tsx`

The workhorse — renders 23 of the 24 sections from data. (`HomeHero` is the only bespoke section.)

```tsx
// Re-exported from TeamOrgChart so SectionData can carry it
import type { OrgRole } from '@/components/TeamOrgChart'

interface SectionTeam {
  department: 'marketing' | 'sales' | 'service'
  director: OrgRole
  specialists: OrgRole[]                     // 6, 7, or 11 roles
  payroll: string                            // "£800k–£1.2M / year"
  substrateCost?: string                     // "Hundreds of pounds / client / month"
}

interface SectionItem {
  icon?: LucideIcon
  tone?: 'primary' | 'secondary' | 'tertiary' | 'neutral'
  title: string
  body: string
  chatSeed?: string
}

interface SectionMetric {
  value: string
  label: string
  prefix?: string
  suffix?: string
}

interface SectionData {
  id: string
  eyebrow?: string
  headline: string
  highlight?: string                         // colored span via text-tertiary
  body?: string
  layout: 'centered' | 'split-left' | 'split-right'
        | 'team-org' | 'speed-receipt'
        | 'metrics-grid' | 'pillar-grid'
        | 'faq' | 'cta' | 'persona-picker'
  team?: SectionTeam                         // §4–§6 — fed straight to <TeamOrgChart>
  chartSide?: 'left' | 'right'               // §4–§6 — alternates direction
  items?: SectionItem[]                      // pillars / tiles / model tabs
  metrics?: SectionMetric[]                  // proof bar / math
  faq?: { q: string; a: string }[]           // §22
  comparison?: { headers: string[]; rows: string[][] }     // §18 left column
  speedReceipt?: { lighthouseDate: string;                  // §18 right column
                   lighthouseScores?: [number, number, number, number] }
  personaChoices?: { label: string; icon: LucideIcon; seed: string }[] // §3
  visual?: React.ReactNode                   // generic diagram slot for split layouts
  chatSeed?: string
  chatLabel?: string
  chatPersona?: string
  primaryHref?: string                       // for sections with a buy CTA
  primaryLabel?: string
  microCopy?: string
}
```

Layout variants:

- **centered** — headline + body in `max-w-prose mx-auto`; bottom-right `<ChatSeedButton>`.
- **split-left / split-right** — 50/50 copy + visual; `<ChatSeedButton>` aligned to copy column.
- **centered** — headline + body in `max-w-prose mx-auto`; bottom-right `<ChatSeedButton>`.
- **split-left / split-right** — 50/50 copy + visual; `<ChatSeedButton>` aligned to copy column.
- **team-org** — thin slot wrapper: renders the copy column + a `<TeamOrgChart>` in the visual column. SectionBlock contains *no* org-chart rendering logic; that lives in `TeamOrgChart.tsx`. Side (chart-left/chart-right) is controlled by a `chartSide` field on the SectionData.
- **speed-receipt** — thin slot wrapper: renders the comparison table left + `<SpeedReceipt>` right. SectionBlock does not read `performance.*`; that lives in `SpeedReceipt.tsx`.
- **metrics-grid** — `grid grid-cols-2 lg:grid-cols-4`; large numbers in `text-7xl lg:text-8xl tabular-nums text-primary`.
- **pillar-grid** — `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4` of icon + title + body cards (§19 Security).
- **faq** — accordion using native `<details>`/`<summary>` (zero-JS); row 6 is the `<ChatSeedButton>` ask-anything row.
- **cta** — full-bleed `py-32`, headline `text-5xl lg:text-6xl font-bold`, single primary `<a>` + secondary `<ChatSeedButton>` + microcopy beneath.
- **persona-picker** — paragraph + 3 ghost buttons row (§3).

Every variant respects the 6 tokens, the icon system, and `emitClick('ui:home:<section-id>:<action>')` on every onClick.

### 7. `home-sections.ts`  · **≤ 360 LOC** (data-heavy, no logic)
**Path:** `web/src/lib/home-sections.ts`

Exports `HOME_SECTIONS: SectionData[]` with 23 entries (§1 hero is its own component) populated from the tables above. Lucide icons. The team data (`Marketing`, `Sales`, `Service`) lifted from `text/09-teams.md`. The platform feature copy lifted verbatim — never paraphrased — from `text/01-brand.md` through `text/16-speed.md`. Whenever a number changes in a text file, this data file must change in the same commit.

Also exports `SectionData` and `SectionTeam` types so `SectionBlock` and `index.astro` can share them.

---

## Modifications to existing files

### `web/src/pages/index.astro`

1. `chatMode="chat-full"` → `chatMode="wide"`.
2. Drop imports: `PersonalizedHero`, `Buyers`, `Strategy`, `Personas`.
3. Add imports: `HomeHero`, `ProofBar`, `SectionBlock`, `Reveal`, `Stagger`, `HOME_SECTIONS` from `@/lib/home-sections`.
4. New `<main>`:

   ```astro
   <main>
     <HomeHero client:load visitorHash={vHash} slug={slug} />
     <ProofBar client:visible />
     {HOME_SECTIONS.map(s => (
       <Reveal dist="md">
         <SectionBlock client:visible data={s} />
       </Reveal>
     ))}
   </main>
   ```

5. Inject the `stagger-child` global CSS once (keyframes fade-up 12px, respects `prefers-reduced-motion`).

### `web/src/components/Personas.tsx`

**No longer imported on `/`.** The persona-picker role is now embodied inside §3 as three ghost `<ChatSeedButton>`s. `Personas.tsx` stays in the codebase for `/u` and `/chat`.

### `web/src/components/Hero.tsx`, `PersonalizedHero.tsx`

Unchanged. `HomeHero` composes `Hero` internally. `PersonalizedHero` stays available for other surfaces.

### `web/src/components/Strategy.tsx`, `Buyers.tsx`

Removed from home. Queue deletion in a follow-up if grep confirms unused elsewhere.

---

## Motion plan

Every `SectionBlock` is wrapped in `<Reveal dist="md">` at the page level — its heading fades up on scroll.

**Proof bar (§2)** — `<Stagger stagger={0.12}>` wraps the four `<ScrollCounter>` cards.

**Team org charts (§4–§6)** — each role card uses `style={{ '--i': i }}` + `className="stagger-child"`. The Director appears first, then specialists cascade in over ~800ms total.

**The math (§20)** — `<ScrollCounter value={5.4} prefix="$" suffix="M" duration={1600} />` for the dollar number. The build-up is the drama.

**Speed live receipt (§18)** — typewriter-style append: each of the three lines fades in 200ms after the previous, then the LCP number updates to the real `performance` value.

**Quiet sections** (hero, why-now, memory, learning, founder, stake, final CTA) — `<Reveal dist="lg" speed="slow">`. Slower reveals for the quiet sections; faster for the dense ones. Cadence is partly motion-driven.

---

## Chat seed library (the 24 prompts, verbatim)

Seeds stored in `home-sections.ts` and dispatched verbatim. First-person, persona-suggestive, never named. Every seed names a number, a system, or a specific scenario.

```ts
{
  // §1 hero
  hero:            "Walk me through how I get a full marketing, sales, and service team live this week.",
  // §3 persona picker — three variants
  whyAgency:       "I run an agency with around 200 clients. How does ONE become the platform I resell, with my brand on every screen?",
  whyBusiness:     "I run a business and want a full marketing, sales, and service workforce of my own. Where do I start?",
  whyConsultant:   "I'm a consultant who deploys AI for clients. How does ONE become the infrastructure underneath my consulting work?",
  // §4–§6 teams
  marketing:       "Show me the marketing team in action for a new retail client.",
  sales:           "Walk me through a sales agent qualifying an inbound lead in real time.",
  service:         "Demo the service team for a returning customer who asks a complaint question.",
  // §7–§12 platform
  brand:           "Show me white-labeling. I want my clients on my domain, not yours.",
  agents:          "Show me what an agent file looks like and how I'd change the tone for a specific client.",
  skills:          "Give me an example skill that a marketing agent would reuse across all my clients.",
  models:          "I want cheap for support tickets and smart for sales. How do I bind models per agent?",
  tools:           "Can my agent post to a customer's Slack as them? Walk me through the OAuth flow.",
  memory:          "If a client leaves me, what do I keep? Walk me through the data and the contract.",
  // §13–§16 unified view
  tracking:        "A customer messaged on WhatsApp this morning and visited the site last week. Is that one record?",
  crm:             "Where does the contact data come from? Do I need to import a CSV?",
  analytics:       "Generate a sample monthly report for a client with 200 conversations and 12 leads last month.",
  learning:        "Show me a real before/after — how does the workforce get measurably smarter on my data?",
  // §17–§19 foundation
  development:     "How does my developer extend an agent? Show me the editing flow.",
  speed:           "Show me the Lighthouse score on /chat right now, compared to ChatGPT and Claude.",
  security:        "What happens if you go out of business? Can I take my data and run? Walk me through the escrow.",
  // §20–§24 close
  math:            "Walk me through the credit math for my situation. What's the margin in year one?",
  founder:         "I want to understand the philosophy. Why did you build this, and why now?",
  faqOpen:         "I have a different question — let me ask it directly.",
  stake:           "What changes between moving now and waiting six months? Show me both timelines.",
  finalCta:        "I'm ready. What happens in the first 48 hours after I start?",
}
```

Three rules:
1. Every seed names a number, a system, or a specific scenario. No vague *"tell me more."*
2. Every seed is first-person and role-suggestive without assuming a name or city. The agent infers visitor type from context (and from the §3 persona choice if made).
3. Every seed leaves a hook the agent must respond to — never just a topic.

---

## Design rules for every new component

1. **6 tokens only** — `bg-background`, `bg-foreground`, `text-font`, `text-primary`, `text-secondary`, `text-tertiary`. No hex, no `zinc-*`.
2. **`emitClick('ui:home:<section>:<action>')`** before every onClick handler.
3. **The only `<a href>`** on the page are `/get-yours` (the buy) and `/sign-in` (returning visitor). No nav. No sub-pages.
4. **Icon size ramp** — `sm` (14) inline, `md` (16) buttons, `lg` (20) tiles/roles, `xl` (24) hero. Lucide only via `<Icon>` / `<IconBadge>`.
5. **Card pattern** — `bg-background border rounded-2xl` with `borderColor: 'var(--color-border)'`, `boxShadow: 'var(--shadow-card)'`. Role cards hover: `-translate-y-0.5 transition`.
6. **Text hierarchy** — eyebrow (`text-sm uppercase tracking-wider text-secondary`) → headline (`text-4xl lg:text-5xl font-semibold` + one `text-tertiary` highlight word) → body (`text-lg lg:text-xl text-font/70 leading-relaxed`) → CTA.
7. **Section padding** — `py-24 lg:py-32` quiet, `py-20 lg:py-28` dense, `py-32 lg:py-40` showcase (§4–§6, §18, §20).
8. **Type ramp** — hero `text-6xl lg:text-7xl`, section headlines `text-4xl lg:text-5xl`, oversized numbers `text-7xl lg:text-8xl tabular-nums`, the stake (§23) `text-5xl lg:text-6xl`.
9. **First-person CTA copy** — *"Hire my workforce"*, *"Show me my team"*. Never *"your"*, never *"Learn more"*.
10. **Voice contract** — every line passes `.claude/product-marketing.md`. No banned vocabulary (*seamless*, *cutting-edge*, *empower*, *transform*, *AI-powered*, *future-proof*, *in today's fast-paced world*, *game-changer*). No exclamation points anywhere except the §1 headline (the awaits frame *is* an emphasis — but no `!` punctuation).
11. **Specificity rule** — if a competitor could put their logo on the headline and have it still be true, rewrite. Every adjective takes a number.
12. **Mobile-first** — primary CTA above the fold on 375×667. Single-column. Buttons ≥ 44px.

---

## Verify

**Conversion stack**
- [ ] 5-second test: a fresh reader names *what · who · why* from the hero alone — "AI workforce," "anyone with clients," "ready on day one."
- [ ] One primary CTA, one secondary, on every section with CTAs. Never three.
- [ ] First-person CTA copy on every `<ChatSeedButton>` label.
- [ ] Friction-reducer microcopy under both `/get-yours` buttons (hero §1 + final §24).
- [ ] FAQ covers all five rows from the objection ladder, ≤ 40 words each.
- [ ] Named founder voice section (§21) with portrait + attribution.
- [ ] Speed receipt panel renders real `performance.loadEventEnd` measurement.
- [ ] All 27 roles appear by name across §4 + §5 + §6 (12 + 8 + 7 = 27 — assert count in tests).
- [ ] Every chat seed names a number, a system, or a specific scenario.

**Voice & content**
- [ ] No "Brad" anywhere in `home-sections.ts` or any rendered string.
- [ ] No banned vocabulary anywhere — grep against `.claude/product-marketing.md` banned list.
- [ ] Zero exclamation points in any rendered string.
- [ ] Every speed claim cites a number that matches `text/16-speed.md`.
- [ ] Every team payroll number matches `text/09-teams.md`.
- [ ] All copy passes the read-aloud test: would Anthony say this at the pub?

**Implementation**
- [ ] `bun run verify` green (tsc + vitest).
- [ ] `bun run build` green (no import errors, wrangler bundle produced).
- [ ] Desktop ≥ 1024px: 55/45 content/chat split visible on load.
- [ ] Mobile ≤ 768px: chat collapses to widget FAB; all sections full-width.
- [ ] Clicking any `<ChatSeedButton>` sends its prompt to the chat and a response begins streaming.
- [ ] Proof bar numbers count up when section enters viewport.
- [ ] `TeamOrgChart` cascades (CEO label → Director → specialists) on scroll; tested with throttled CPU.
- [ ] `TeamOrgChart` clickable cards open chat with role-specific seed; default seed used when none specified.
- [ ] `TeamOrgChart` passes a11y: `<section aria-label>` outer, `<ul role="list">` specialists, focus ring visible, icons `aria-hidden`.
- [ ] `SpeedReceipt` page-load number > 0 on production build; falls back to *"—"* gracefully if `performance` is unavailable.
- [ ] `SpeedReceipt` `<time dateTime>` element on the Lighthouse line is machine-readable.
- [ ] FAQ rows expand/collapse via native `<details>`; no JS required.
- [ ] No `bg-zinc-*`, no `text-indigo-*`, no hex literals in any new file.
- [ ] Every `onClick` in new components calls `emitClick('ui:home:...')`.
- [ ] The only `<a href>` values are `/get-yours` and `/sign-in`.

**Performance & accessibility**
- [ ] Lighthouse mobile: Performance ≥ 95, Accessibility ≥ 95, Best Practices ≥ 95, SEO 100.
- [ ] LCP < 2.5s, CLS < 0.1, INP < 200ms.
- [ ] `@media (prefers-reduced-motion: reduce)` disables all animations.
- [ ] All `<ChatSeedButton>` reachable by keyboard; focus visible.
- [ ] Team org charts pass screen-reader pass-through (use `<ul>` semantics, not divs).

---

## Close criteria

- [ ] All 7 new files exist: `HomeHero.tsx`, `ProofBar.tsx`, `ChatSeedButton.tsx`, `TeamOrgChart.tsx`, `SpeedReceipt.tsx`, `SectionBlock.tsx`, `home-sections.ts`.
- [ ] `TeamOrgChart` renders three times (one per department), with the correct role counts: 12 marketing, 8 sales, 7 service.
- [ ] `SpeedReceipt` shows a real, non-placeholder page-load number on render in a production build.
- [ ] `index.astro` updated to v4 structure (24 sections, `chatMode="wide"`).
- [ ] Manual smoke: scroll full page, click 5 different chat seeds (hero, one team, one platform, one foundation, FAQ), verify each produces a streaming chat response.
- [ ] Manual 5-second test on a fresh reader: they correctly name *what · who · why* from the hero alone.
- [ ] Pheromone tag: `surface:home-v4 mode:lean lifecycle:construction`.

---

## Migration note (v3 → v4)

The in-flight `home-todo.md` was scoped to v3 (12 sections, 4 components + data). v4 keeps the same skeleton but splits two heavy concerns (the org chart and the live receipt) into their own files:

| Cycle | v3 deliverable | v4 status |
|---|---|---|
| C1 | `ChatSeedButton.tsx` + `home-sections.ts` | **extended** — 12 → 23 section entries; new `SectionTeam` type re-exports `OrgRole` from TeamOrgChart; data LOC 260 → 360 |
| C2 | `SectionBlock.tsx` (5 layouts) | **refactored thinner** — drop `bento`; add `team-org` / `speed-receipt` / `pillar-grid` / `persona-picker` slots; both `team-org` and `speed-receipt` are slot wrappers that delegate to the dedicated component (so SectionBlock LOC stays at ≤ 220, not ballooning) |
| C3 | `HomeHero.tsx` + `ProofBar.tsx` | **mostly unchanged** — `HomeHero` headline + microcopy update only |
| C4 | `FinalCTA.tsx` | **dissolved** — collapsed into `SectionBlock` `layout="cta"` |
| **C4-new** | **`TeamOrgChart.tsx`** | **NEW cycle** — visual centerpiece of §4·§5·§6; ≤ 180 LOC; runs parallel to C2/C3 |
| **C5-new** | **`SpeedReceipt.tsx`** | **NEW cycle** — live performance receipt for §18; ≤ 80 LOC; runs parallel to C2/C3/C4-new |
| C5 (was) | wire `index.astro` | **renumbered C6** — same `chatMode="wide"`, same map; 23 `SectionBlock` calls instead of 11 |

**Reconciliation:** when v4 lands, `home-todo.md` becomes a 6-cycle plan (C1 sequential, then C2 + C3 + C4 + C5 in parallel, then C6 wire). DAG, batches, and reuse contract carry over.

---

*Twenty-four sections. Six acts. Two exits. One thesis: your AI workforce awaits — twenty-seven roles, three full teams, live the hour you sign. Every word on the page earns its place by closing a loop the chat opens — or opening a loop the chat closes.*
