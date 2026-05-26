---
# ═══════════════════════════════════════════════════════════════════════════
# Agent.md — template showing every supported field
# ═══════════════════════════════════════════════════════════════════════════
#
# Copy this file to web/agents/<your-name>.md (or anywhere) and edit. Every
# block is optional except `name` — even that defaults to the filename stem.
#
# Read first:    web/agent-authoring.md     full contract + every field
# See planned:   web/agent-features.md      shipped vs planned, by phase
#
# Author loop:
#   oneie agent validate <path>             schema check (kebab-case, anchors)
#   oneie agent lint <path>                 style nits (chip-label length, etc.)
#   oneie agent diff <a> <b>                semantic diff
#   oneie agent publish <path> --slug acme  upload to R2
#   oneie agent pull <name> --slug acme     download live version
#   oneie agent unpublish <name> --slug acme remove (idempotent)
#
# Same flow on SDK: client.{publish, pull, unpublish}Agent
# Same flow on MCP: publish_agent, pull_agent, unpublish_agent
# ═══════════════════════════════════════════════════════════════════════════

# ── Identity ─────────────────────────────────────────────────────────────────
agentmd: "0.1"                       # spec version
name: my-agent                       # kebab-case id — matches filename + ?agent=<name> URL
title: My Agent                      # display name shown on /agents + /studio hero
description: One-line tagline shown on the agent card and chat hero.
version: 1.0.0                       # semver — bump when prompt intent changes
model: meta-llama/llama-4-scout-17b-16e-instruct
group: marketing                     # optional — filtered on /agents
tags: [marketing, demo]
sensitivity: 0                       # 0..1 — content sensitivity
lifecycle: active                    # active | beta | deprecated

# ── Org hierarchy ─────────────────────────────────────────────────────────────
reports_to: ceo                      # parent agent slug — drives TypeDB membership relation
tier: specialist                     # director | specialist — controls routing weight
domain: marketing                    # marketing | sales | service | community | foundation | refine

# ── Signal routing (internal orchestration) ──────────────────────────────────
# Director agents fan-out work; specialist agents receive and return.
# Signal names use the convention: <entity>:<id>:<action>-needed / <action>-ready
subscribes:
  - signal: campaign:brief           # inbound — what triggers this agent
emits:
  - signal: campaign:<id>:copy-needed  # outbound — what this agent fires

# ── Shared context reads ──────────────────────────────────────────────────────
# Loaded from one.ie/agents/foundation/ at runtime. All marketing + sales agents
# should declare both. Foundation agents write these files; all others read them.
reads:
  - frameworks-library               # 15 canonical frameworks (Hormozi, Schwartz, Brunson…)
  - blueprint                        # company ICP, positioning, offer — written by Brand Strategist

# ── Persona ──────────────────────────────────────────────────────────────────
starters:                            # 3-4 conversation seeds if ui.starters is unset
  - What can you help me with?
  - Walk me through a quick win

# ── Capabilities ─────────────────────────────────────────────────────────────
skills: [draft-email, headline-variants]   # refs to web/skills/*.md (string shorthand)
# Inline skills (alternative shape — no separate file needed):
# skills:
#   - { ref: draft-email }                 # ref-by-id, full form
#   - name: voice-rewrite                  # inline, defined in-place
#     title: Voice Rewrite
#     description: Rewrite copy in the brand voice — concise, specific, no hedging.
#     price: 0
#     tags: [marketing]
tools: [crawl, search]               # platform tool whitelist — [] = none, omit = all
                                     # available: write, eval, skill, payment, import_skill,
                                     # compile, patch_agent, patch_theme, emit_card, emit_chips
                                     # (allowlist enforcement ships in Phase 1.5 W4.5)

# ── uAgents / Fetch.ai (only set if compiling to Python via SDK) ─────────────
# seed: deterministic-seed
# port: 8001
# mailbox: true
# agentverse: https://agentverse.ai
# intervals:
#   - { period: 300, task: "Check signals and coordinate with peers" }
# endpoints:
#   - { method: POST, path: /webhook, response: "Process webhook" }
# bureau: [partner-a, partner-b]

# ── Payments / x402 (only set if you charge) ────────────────────────────────
# wallet: "0x…"
# accepts:
#   - scheme: exact
#     network: eip155:8453
#     asset: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
#     max: "0.05"

# ── Theme — color tokens scoped to this agent's /studio page ────────────────
theme:
  primary: "#6366f1"
  secondary: "#ec4899"
  tertiary: "#10b981"
  # background: "#0a0a0f"     # optional
  # foreground: "#1a1a20"     # optional
  # font: "#fafafa"           # optional

# ── Chat surface customization ──────────────────────────────────────────────
ui:
  hero:
    image: https://loremflickr.com/900/270/my,brand,hero
    eyebrow: "MY BRAND · 2026"
    typewriter:
      - First animated line
      - Second animated line

  covers:                            # photo strip under the typewriter
    - { url: https://loremflickr.com/176/132/brand?random=1, label: A }
    - { url: https://loremflickr.com/176/132/brand?random=2, label: B }

  starters:                          # intro card grid — overrides journey.stages here
    - id: kickoff
      icon: rocket                   # any Lucide name (kebab-case)
      tone: primary                  # primary | secondary | tertiary
      title: Get Started
      subtitle: One line of context
      seed: "Help me get started with…"

  quickReplies:                      # always-on pills above the textarea
    - { label: New brief, prompt: "Walk me through a fresh brief…" }
    - { label: Critique,  prompt: "Critique this draft…" }

  footer: "Or type your own brief below."

  messages:
    placeholder: "Ask for a draft, a critique, or a plan…"
    streaming:   "Drafting…"
    empty:       "Pick a stage above or type your own brief."
    error:       "Something broke. Try again?"
    welcome:     "Welcome back. Where did we leave off?"

  labels:
    speak:   Play
    stop:    Stop
    approve: Ship it
    deny:    Hold
    send:    Send

  voice:
    default: nova                    # alloy | echo | fable | onyx | nova | shimmer

  layout:
    chat: wide                       # wide | rail | icon | none
    chatLock: true                   # locks this page's chat mode (user can't switch)
    sidebar: mini                    # none | mini | full

  avatar:
    image: https://loremflickr.com/64/64/avatar
    name: My Agent

  animation:
    typewriterSpeedMs: 26            # per-char delay (lower = faster)
    typewriterPauseMs: 360           # between-line pause
    stageStaggerMs: 40               # stage-card reveal stagger

  send:
    icon: rocket                     # any Lucide name — shown when ready
    label: Ship it                   # aria-label on Send; ui.labels.stop overrides while streaming

# ── Journey — the guided-work funnel + chip-id contract ─────────────────────
journey:
  intro: my-agent                    # window.__oneChatIntro key
  stages:
    - id: kickoff                    # kebab-case — used as chip id
      num: 1
      phase: Start
      title: Get Going
      subtitle: One sentence
      tone: primary
      time: First 5 min
      bullets:
        - First thing the user does
        - Second thing
      longPrompt: >-
        Verbose prompt for when the user clicks the stage card directly
        from the page (no continuation pills visible, so it must self-contain).
      seed: >-
        Short prompt for when the user clicks the stage card in the in-chat
        intro grid (continuation pills carry the rest of the journey).
      sections: ['#brand']           # section anchors to scroll to (must match sections[].id)
      continuations:                 # 1–4 follow-up chips after the assistant replies
        - id: persona-pick
          label: Pick a persona
          prompt: "Pick one persona and write the brief for them…"
        - id: refine
          label: Refine the metric
          prompt: "Help me convert the metric into a time-boxed number…"

    # Add more stages — typical journeys have 4–6 phases.

  pills:                             # top-strip shortcuts shown on the studio page
    - id: draft
      label: Draft a launch email
      prompt: "Draft the launch email — 3 subjects, body…"
    - id: critique
      label: Critique my page
      prompt: "Critique my landing page against the brand-voice rules…"

# ── Sections — page content surfaces ────────────────────────────────────────
sections:
  # stat — 4-up grid of key numbers
  - kind: stat
    id: quick-stats
    title: Brand Voice Quick Stats
    items:
      - { label: Tone,    value: Confident, sub: Specific, no jargon }
      - { label: CTAs,    value: 5 verbs,   sub: start · try · see · get · claim }

  # card — single card with key/value rows (HTML in value supported)
  - kind: card
    id: brand
    title: Your Brand Brief
    subtitle: The one-page foundation
    ask: "Critique this brief — score 1-5 on each section and rewrite the weakest line."
    fields:
      - { label: Audience, value: "Solo founder shipping their first SaaS." }
      - { label: Outcome,  value: "<strong>150 signups in 30 days.</strong>" }
      - { label: Anti-goal, value: "Tire-kicker signups that never activate." }

  # grid — 2-col tile grid. Items can be:
  #   (a) chat-seed buttons (set `ask`)
  #   (b) external affiliate links (set `href`)
  #   (c) plain display tiles (neither)
  - kind: grid
    id: personas
    title: Your Personas
    subtitle: 4 starting templates
    items:
      - name: Solo Founder
        tag: SaaS · pre-revenue
        img: https://loremflickr.com/600/400/founder,laptop
        description: "JTBD: Ship and find first 10 paying customers."
        ask: "Write the brief for this persona."

  # grid (affiliate variant) — when href is set, the tile is an external link.
  # Also supports rating, reviewCount, starRating, price for richer display.
  - kind: grid
    id: hotels
    title: Hotels (Agoda affiliate example)
    subtitle: External links — href turns the card into an <a>
    items:
      - name: La Siesta Premium Hang Be
        tag: Best boutique
        meta: Old Quarter
        img: https://picsum.photos/seed/lasiesta-hanoi/600/380
        description: Highest-rated mid-range in the Old Quarter — rooftop bar, walk to Hoan Kiem in 5 min.
        href: https://www.agoda.com/la-siesta-premium-hang-be/hotel/hanoi-vn.html
        price: 65                    # rendered as "$65"
        rating: 9.4                  # shown on photo overlay
        reviewCount: 2134
        starRating: 4                # whole-star count rendered as stars

  # list — vertical rows, optional leading value chip
  - kind: list
    id: channels
    title: Channel Mix
    subtitle: Default $5k/month launch
    ask: "Stress-test this mix — what if paid CAC doubles?"
    items:
      - { name: Paid search,   value: 40, description: Intent already there,        meta: CAC < $80,  ask: "Build the paid-search plan…" }
      - { name: Content / SEO, value: 30, description: Compounds. Cheapest at scale, meta: 20 sessions/post, ask: "Build a 4-week content plan…" }

  # compare — A/B columns with bulleted rules
  - kind: compare
    id: rules
    title: Brand-Voice Rules
    subtitle: Every artifact passes before ship
    ask: "Run this check on my copy."
    a:
      label: ✅ Always
      tone: tertiary
      bullets:
        - "<strong>Specific:</strong> doubles signups in 30 days"
        - "<strong>Verb-first CTAs:</strong> start · try · see"
    b:
      label: ❌ Never
      tone: primary
      bullets:
        - "<strong>Adverbs:</strong> very, really, incredibly"
        - "<strong>Hedges:</strong> might, could potentially"

  # cta — call-to-action with primary + optional secondary
  - kind: cta
    id: get-started
    title: Ready to launch your first campaign?
    subtitle: Pick the approach that fits your timeline.
    ask: Help me choose between these options
    primary:
      label: Start with AI-generated copy
      ask: Generate a campaign brief for me
    secondary:
      label: View a worked example
      ask: Show me a completed campaign example
    icon: rocket

  # embed — video or iframe content
  - kind: embed
    id: walkthrough
    title: 3-minute walkthrough
    subtitle: See the full campaign flow start to finish.
    provider: youtube
    src: https://www.youtube.com/watch?v=dQw4w9WgXcQ
    aspect: "16:9"

  # code — syntax-highlighted snippet with copy button
  - kind: code
    id: api-example
    title: Quick-start snippet
    lang: typescript
    copyable: true
    content: |
      import { OneClient } from '@oneie/sdk'
      const client = new OneClient({ apiKey: process.env.ONEIE_API_KEY })
      const result = await client.publishAgent({ slug: 'my-ws', name: 'my-agent', content })
      console.log(result.url)

  # timeline — step-by-step flow with optional tone markers
  - kind: timeline
    id: onboarding-steps
    title: Onboarding in four steps
    items:
      - time: Day 1
        label: Connect your data sources
        description: Link your CRM, analytics, and brand assets.
        tone: primary
      - time: Day 2
        label: Review generated briefs
        description: AI drafts three campaign directions for your approval.
        tone: secondary
      - time: Day 3-5
        label: Iterate and refine
        description: Feedback loop with the agent until the brief is locked.
        tone: tertiary
      - label: Launch
        description: One-click publish to your channels.
        tone: primary

  # hotel — property cards with price, rating, affiliate link (required href)
  - kind: hotel
    id: recommended-hotels
    title: Where to stay
    subtitle: Curated picks near the venue, affiliate rates via Agoda.
    ask: Help me choose a hotel for my budget
    items:
      - name: The Mira Hong Kong
        img: https://picsum.photos/seed/mira-hk/600/380
        location: Tsim Sha Tsui, Kowloon
        rating: 8.8
        reviewCount: 4201
        starRating: 5
        price: 210
        currency: USD
        href: https://www.agoda.com/the-mira-hong-kong/hotel/hong-kong-hk.html
      - name: Hotel Icon
        img: https://picsum.photos/seed/icon-hk/600/380
        location: Tsim Sha Tsui East
        rating: 9.1
        reviewCount: 2876
        starRating: 4
        price: 155
        currency: USD
        href: https://www.agoda.com/hotel-icon/hotel/hong-kong-hk.html
---

You are a [your persona] — sharp, opinionated, brand-aware.

Be direct. Pick a winner, justify it in one sentence, then deliver the artifact.

## Style

- Use markdown: `##` section headers, **bold** for names/prices, bulleted lists, tables for 2+ option comparisons.
- One inline image at the top when the topic has a strong visual anchor.

## Knowledge anchors (use verbatim)

- **Anchor fact 1** — verbatim, not paraphrased.
- **Anchor fact 2**
- **Anchor fact 3**

## Trailing chips — required

Every reply ends with one line, no code fence, no commentary after:

<chips>[{"id":"<kebab-id>","label":"<2-5 words>"}]</chips>

1–4 chips. Each chip is the **next move**, not a restart.

Chip vocabulary — the server auto-injects your journey's chip ids here at
chat time. Leave this heading in place; don't maintain the list manually.
Mint fresh kebab-case ids for new topics.

## Response shape

1. Open with one direct answer.
2. Show the work — table, timeline, or comparison.
3. Close with one specific next action.
4. Chips block.

Never close with "let me know if you'd like…" — close with the chips.

---

<!--
═══════════════════════════════════════════════════════════════════════════
 Planned fields — see agent-features.md (don't paste these yet; they parse
 as `error` until the matching wave ships, except where noted)
═══════════════════════════════════════════════════════════════════════════

# Phase 1.5 W4.5 — skills + tools integrity:
# (no new frontmatter — tools: allowlist becomes enforced; skills auto-listed in prompt)

# Phase 2 W5-W7 — persistence, analytics, mobile, templates, composition:
persistence:
  threadTtl: 30d                  # how long to keep conversation threads
  resumable: true                 # show "Resume your last conversation"
  shareable: true                 # allow /share/<tid> URLs

# Phase 2.5 W7.5 — lifecycle funnel + CRO (full spec: web/agent-lifecycle.md)
funnel:
  goals:
    - { id: brief-locked, name: Brief Locked, stage: brief,
        event: artifact-saved, value: 1.0, window: 600s }
    - { id: campaign-shipped, name: Campaign Shipped, stage: ship,
        event: chip-click, eventMatch: { id: ship-it }, value: 5.0, window: 1800s }
  stages:
    - id: brief
      window: 300s
      goal: brief-locked
      successSignal: { event: artifact-saved, within: 300s }
      partialSignal: { event: chip-click, chipId: refine }
      dropSignal:    { idleAfter: 60s }
  kpis: [stageCompletionRate, timeToConversion, dropOffByStage,
         chipCtr, artifactRate, returnRate7d, variantLift, pathStrength]
  optimization:
    idleReengagement:    { enabled: true, after: 30s, maxFires: 2,
                           prompt: "Still working on this? Want an example?" }
    abandonmentRecovery: { enabled: true, windowDays: 14,
                           banner: "Welcome back — pick up where you left off?" }
    socialProof:         { enabled: true, minCount: 50, windowDays: 7 }
    progressiveDisclosure: { enabled: false, stages: [draft, review, ship] }
    variableReward:      { enabled: true,
                           triggers: [{ after: brief-locked, unlock: free-headline-skill }] }
    frictionReduction:   { enabled: true, preFillFromThread: true,
                           preFillFields: [audience, outcome, channels] }
    variants:
      assignment: cookie
      arms:
        A: { weight: 0.5, prompt: "Help me lock the brief…" }
        B: { weight: 0.5, prompt: "I have a half-baked idea. Tell me where to start." }
      goalForWinner: brief-locked
      minSampleSize: 100
    personalisation:
      enabled: true
      rules:
        - when: returning
          seedPrompt: "Continue where you left off, or start fresh?"
        - when: variant=B
          quickReplies: ["Half-baked idea", "Show me an example"]
  visitorTypes: [human, agent]    # add `agent` to advertise to peers
  a2a:                            # only when visitorTypes includes agent
    discoverable: true
    capabilities: [draft-email, headline-variants]
    pricing: { currency: USDC, rate: 0.05 }
    pheromoneTags: [marketing, copy]
    sla: { p95LatencyMs: 4000, successRate: 0.90 }
ui:
  layout:
    mobile: { chat: sheet, sections: stack }   # responsive override
  shortcuts: { 1-6: stage, "/": chat, esc: close }
  print: { enable: true, header: "My Agent · {{date}}", footer: "{{title}}" }
subAgents:                        # delegation — chat routes through these
  - { name: copywriter, when: writing, agent: copywriter-v2 }

# Phase 3 W8-W10 — trust, business, scale, i18n:
i18n:
  locales: [en, vi, ja]
  translations:
    vi: { title: "Trợ lý của tôi", description: "...", starters: [...] }
branding:
  favicon: https://…/favicon.svg
  ogImage: https://…/og.png       # or omit — auto-rendered from theme + hero
  socialCard:
    title: My Agent — your AI partner
    description: Drafts, critiques, ships.
moderation:
  blockList: [hate, illegal]      # extra block categories beyond defaults
  sensitivityCap: 0.7             # refuse content above this score
marketplace: public               # listed at /marketplace cross-workspace
-->

