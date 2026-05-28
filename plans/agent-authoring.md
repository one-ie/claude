# Authoring agents in markdown

One `.md` file describes a complete agent on ONE: the system prompt, the
skills it composes with, the journey it walks users through, the page
sections it renders, the chat UI, and the colors and layout. The same file
also compiles to Fetch.ai uAgents Python via `oneie agent compile --target
uagents` — one source, two runtimes.

This document is the contract. If a field isn't here, it isn't supported yet.

**Sibling docs:**
- [`agent-template.md`](agent-template.md) — copy-paste starter showing every supported field
- [`agent-features.md`](agent-features.md) — what's shipped vs planned, by phase (128 planned gaps)
- [`agent-lifecycle.md`](agent-lifecycle.md) — the visitor funnel: goals, stages, CRO techniques, A2A funnels
- [`agent-analytics.md`](agent-analytics.md) — measurement, attribution, segmentation, retention, exports
- [`agent-api.md`](agent-api.md) — public REST surface: auth, resources, webhooks, OpenAPI, errors

Two distinct lifecycles also exist in this repo — don't confuse them:
- `agents-lifecycle.md` — the **agent's own state machine** (draft → live → paused → evolving → archived)
- `agent-lifecycle.md`  — the **visitor's funnel through the agent** (Discovery → Conversion → Advocacy)

---

## The shape

```yaml
---
# ── Identity ─────────────────────────────────────────────────────────────────
agentmd: "0.1"                # spec version (recommended but optional)
name: my-agent                # kebab-case id — must match file basename + URL
title: My Agent               # display name
description: One-line tagline.
model: meta-llama/llama-4-scout-17b-16e-instruct
group: marketing              # optional — used for filtering on /agents
tags: [marketing, demo]
sensitivity: 0                # 0..1 — content sensitivity level
lifecycle: active             # active | beta | deprecated

# ── Org hierarchy ─────────────────────────────────────────────────────────────
reports_to: ceo               # parent agent slug — persisted as TypeDB membership relation
tier: specialist              # director | specialist — controls routing weight + pheromone
domain: marketing             # marketing | sales | service | community | foundation | refine

# ── Signal routing ────────────────────────────────────────────────────────────
# Director agents fan-out; specialists receive and return. Convention:
#   inbound:  <entity>:<id>:<action>-needed
#   outbound: <entity>:<id>:<action>-ready
subscribes:
  - signal: campaign:brief
emits:
  - signal: campaign:<id>:copy-needed

# ── Shared context reads ──────────────────────────────────────────────────────
# Files in one.ie/agents/foundation/ loaded at runtime. Marketing + sales agents
# declare both. Foundation agents write them; all others read.
reads:
  - frameworks-library         # 15 canonical frameworks — Hormozi, Schwartz, Brunson, Dunford…
  - blueprint                  # ICP, positioning, offer — written by Brand Strategist

# ── Persona (web chat) ───────────────────────────────────────────────────────
starters:                     # 3–4 conversation seeds shown if no ui.starters
  - What can you help me with?
  - Walk me through a quick win

# ── Capabilities ─────────────────────────────────────────────────────────────
skills: [draft-email, headline-variants]   # refs to skills/*.md
tools: [crawl, search]                     # platform tools whitelist; [] = none
features: [field-service]                  # opt-in platform features; see field-service.md

# ── uAgents / Fetch.ai (compile target) ──────────────────────────────────────
seed: deterministic-seed-here              # uAgents identity seed
port: 8001                                 # local agent HTTP port (default 8000)
mailbox: true                              # receive via Agentverse mailbox
agentverse: https://agentverse.ai
intervals:                                 # autonomous ticks
  - period: 300
    task: Check for signals and coordinate with peers
endpoints:                                 # HTTP endpoints to expose
  - method: POST
    path: /webhook
    response: Process webhook and acknowledge
bureau: [partner-agent-a, partner-agent-b] # sibling agents in a bureau

# ── Payments / commerce (x402) ───────────────────────────────────────────────
wallet: 0x…                                # wallet to receive payments
accepts:                                   # accepted payment schemes
  - scheme: exact
    network: eip155:8453
    asset: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
    max: "0.05"

# ── Theme (web only — color overrides for this agent's /studio page) ────────
theme:
  primary: "#6366f1"
  secondary: "#ec4899"
  tertiary: "#10b981"
  background: "#0a0a0f"
  foreground: "#1a1a20"
  font: "#fafafa"

# ── Chat UI (web only — every chat surface customisation) ────────────────────
ui:
  hero:
    image: https://…/banner.jpg
    eyebrow: "BRAND · 2026"
    typewriter:
      - First animated line
      - Second animated line
  covers:                                  # photo strip
    - { url: https://…/a.jpg, label: A }
    - { url: https://…/b.jpg, label: B }
  starters:                                # intro card grid
    - id: kickoff
      icon: rocket                         # Lucide name (kebab-case)
      tone: primary                        # primary | secondary | tertiary
      title: Get Started
      subtitle: One line of context
      seed: "Help me get started with…"
  quickReplies:                            # always-on pills above input
    - { label: New brief, prompt: "Walk me through a fresh brief…" }
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
    default: nova                          # alloy | echo | fable | onyx | nova | shimmer
  layout:
    chat: wide                             # wide | rail | icon | none
    chatLock: true                         # forces the chat width on this page
    sidebar: mini                          # none | mini | full
  avatar:
    image: https://…/agent-avatar.png      # shown next to streaming state
    name: My Agent
  animation:
    typewriterSpeedMs: 26                  # per-character typing delay
    typewriterPauseMs: 360                 # between-line pause
    stageStaggerMs: 40                     # stage-card reveal stagger
  send:
    icon: rocket                           # Lucide icon name shown on the send button
    label: Ship it                         # aria-label when ready; ui.labels.stop overrides while streaming

# ── Journey (web only — the guided-work funnel) ──────────────────────────────
journey:
  intro: marketing                         # window.__oneChatIntro key
  stages:                                  # the 4–6 phases of work
    - id: brief                            # kebab-case, used as chip id
      num: 1
      phase: Brief
      title: Lock the Brief
      subtitle: One page. Clear ask.
      tone: primary
      time: Start here · 5 min
      bullets:
        - Audience in one sentence
        - Outcome metric — what number moves
      longPrompt: >-
        Help me write a one-page campaign brief…
      seed: >-
        Help me write a brief — audience, outcome, anti-goal.
      sections: ['#brand', '#personas']    # section ids to scroll to
      continuations:                       # follow-up chips after assistant reply
        - id: persona-pick
          label: Pick a persona
          prompt: "Pick one persona and write the brief for them…"
  pills:                                   # quick-access journey prompts
    - id: draft-email
      label: Draft launch email
      prompt: "Draft the launch email — 3 subjects, body…"

# ── Sections (web only — page content surfaces) ──────────────────────────────
sections:
  - kind: stat                             # 4-up grid of key numbers
    id: quick-stats
    title: Brand Voice Quick Stats
    items:
      - { label: Tone, value: Confident, sub: Specific, no jargon }
      - { label: CTAs, value: 5 verbs, sub: start · try · see · get · claim }

  - kind: card                             # single card with key/value rows
    id: brief
    title: Your Brand Brief
    subtitle: The one-page foundation
    ask: "Critique this brief…"             # data-ask on the footer button
    fields:
      - { label: Audience, value: "Solo founder…" }
      - { label: Outcome,  value: "<strong>150 signups</strong>" }   # HTML allowed

  - kind: grid                             # 2-col tile grid (personas, products…)
    id: personas
    title: Your Personas
    subtitle: 4 starting templates
    ask: "Help me pick a persona…"
    items:
      - name: Solo Founder
        tag: SaaS · pre-revenue
        img: https://…/founder.jpg
        description: "JTBD: …  Blocker: …"
        ask: "Write the brief for this persona…"

  - kind: list                             # vertical list with leading value chip
    id: channels
    title: Channel Mix
    subtitle: Default $5k/month launch
    ask: "Stress-test this mix…"
    items:
      - name: Paid search
        value: 40                          # rendered as the big number on the left
        description: Intent already there
        meta: CAC < $80                    # right-side pill
        ask: "Build the paid-search plan…"

  - kind: compare                          # A/B side-by-side (rules, options)
    id: rules
    title: Brand-Voice Rules
    a:
      label: ✅ Always
      tone: tertiary                       # tints the bullet markers
      bullets:
        - "<strong>Specific:</strong> doubles signups in 30 days"
        - "<strong>Verb-first CTAs:</strong> start · try · see"
    b:
      label: ❌ Never
      tone: primary
      bullets:
        - "<strong>Adverbs:</strong> very, really, incredibly"
        - "<strong>Hedges:</strong> might, could potentially"
---

You are [agent persona]. Your system prompt body goes here as markdown.

## Style
- Use markdown — `##` headers, **bold**, bulleted lists, tables for comparisons.
- One inline image at the top when there's a strong visual anchor.

## Knowledge anchors
- Use verbatim facts the agent should never paraphrase.

## Trailing chips — required
Every reply ends with one line:

<chips>[{"id":"<kebab-id>","label":"<2-5 words>"}]</chips>

Use stable chip ids that match `journey.continuations[].id` and `journey.pills[].id`
so clicks fire the rich pre-baked prompt registered on the page.
```

---

## Required fields

| Field | Why |
|---|---|
| `name`   | Kebab-case id. Must match the filename (`web/agents/<name>.md`) and the `?agent=` URL param. |
| `title`  | Display name on `/agents`, `/studio/<name>`, and chat hero. |
| Body     | The system prompt the LLM receives. Everything below the closing `---`. |

Everything else is optional. Sensible defaults derive from `title` and `description`.

---

## The ten section primitives

Sections render via `SectionRenderer.astro`. Each `kind` has a fixed shape — partners can't extend the renderer without TypeScript today (a custom-kind template system is on the roadmap).

| Kind | Shape | Use for |
|---|---|---|
| `stat`    | 4-up grid of `{ label, value, sub }` | Quick numbers (weather, prices, conversion targets) |
| `card`    | One card with `{ label, value }` rows (HTML allowed in `value`) | Brand briefs, configuration summaries |
| `grid`    | 2-col image tiles with `{ name, img, tag, description, meta, ask }` | Personas, places, products, templates |
| `list`    | Vertical rows with optional leading `value` chip | Channels, ranked picks, tip lists |
| `compare`  | A/B side-by-side with bulleted `{ label, tone, bullets }` columns (HTML allowed) | Rules (always vs never), option comparisons |
| `cta`      | `{ primary: { label, ask?, href? }, secondary?: {...}, icon? }` | Call-to-action cards, landing CPAs, campaign CTAs |
| `embed`    | `{ provider: 'youtube'\|'vimeo'\|'iframe', src, aspect? }` | Video walkthroughs, Loom demos, iframe embeds |
| `code`     | `{ lang, content, copyable? }` | Code snippets, config examples, CLI recipes |
| `timeline` | `{ items: [{ time?, label, description?, tone? }] }` | Step-by-step flows, roadmaps, onboarding sequences |
| `hotel`    | `{ items: [{ name, img?, location?, rating?, reviewCount?, starRating?, price?, currency?, href }] }` | Property cards, product listings with price + rating |

Items with an `ask` field render as clickable buttons that seed the chat with the prompt.

---

## The journey contract

A journey has **stages** (the funnel) and **pills** (the top-strip shortcuts).

Each stage carries two prompts:
- `seed` — short version sent when the user clicks a stage card in the in-chat intro
- `longPrompt` — verbose version sent when the user clicks a data-flow button on the page (no continuation pills are visible there, so the prompt must self-contain)

Each stage has 1–4 `continuations` — follow-up chips that appear after the assistant's reply. Their `id` becomes the chip's stable identifier. When the assistant emits `<chips>[{"id":"persona-pick", "label":"..."}]</chips>`, clicking it fires the matching `continuations[i].prompt` from the registered registry.

**The chip-id contract is the magic.** Author once, route everywhere.

---

## Compatibility — what travels to other runtimes

| Field | Web `/studio` | Web chat (api/chat.ts) | uAgents (Python via SDK compile) |
|---|---|---|---|
| `name`, `title`, `description` | ✓ | ✓ | ✓ |
| `model`, `skills` | display only | system prompt | ✓ uAgents protocols generated |
| `tools` | display only | tool whitelist | — |
| `features` | — | enables platform tools (e.g. `field-service`) | — |
| `seed`, `port`, `mailbox`, `intervals`, `endpoints`, `bureau` | — | — | ✓ uAgents config |
| `wallet`, `accepts` (x402) | — | ✓ stored, paid-skill gate | ✓ |
| `journey`, `sections`, `theme`, `ui` | ✓ | — | silently ignored |
| Prompt body | — | ✓ system prompt | ✓ `SYSTEM_PROMPT` constant |

The SDK's `compileAgent(md, target: 'uagents')` reads only the fields it cares about. New web fields don't break uAgents compilation.

---

## Workflow

```bash
# 1. Auth (stores ~/.config/oneie/key with mode 0600)
oneie auth login --key sk_xxx

# 2. Scaffold
oneie agent new my-agent --profile core      # or commerce | asi
# → my-agent/agent.md

# 3. Author
$EDITOR my-agent/agent.md                    # follow this guide

# 4. Validate frontmatter + lint style
oneie agent validate my-agent/agent.md
oneie agent lint my-agent/agent.md

# 5a. Publish to your ONE workspace (R2 → {slug}/agents/<name>.md)
oneie agent publish my-agent/agent.md --slug acme

# 5b. Deploy to Agentverse (Fetch.ai) — compiles + deploys in one command
oneie agent publish my-agent/agent.md --target agentverse
# requires AGENTVERSE_API_KEY env var (or --agentverse-key flag)
# → returns agentAddress, walletAddress, agentverseUrl

# 6. Compile to Fetch.ai Python manually (if you need the .py file)
oneie agent compile my-agent/agent.md --target uagents
oneie agent compile my-agent/agent.md --target uagents --out agent.py
```

After step 5a: live at `https://acme.one.ie/chat?agent=my-agent` and at
`https://one.ie/studio/my-agent` (for the unified-studio rendering).

After step 5b: live on Agentverse and discoverable via ASI:One. The deployed agent
has `ONEIE_API_KEY` injected as a secret so it can call back to the ONE substrate
(`signal`, `mark`, `warn`, `fade`, `follow`) from inside its uAgents handlers.

---

## Examples

The two reference agents in this repo are the source-of-truth examples:

- [`web/agents/marketing-strategist.md`](agents/marketing-strategist.md) — full journey + 5 section kinds + rich `ui` block + 3 attached skills
- [`web/agents/hanoi-planner.md`](agents/hanoi-planner.md) — same shape applied to a travel domain

Both are < 700 lines including all journey content. Read them side-by-side to see how the same primitives express two completely different domains.

---

## Validation

Every `.md` parsed by `parseAgentMd` runs through a Zod schema
(`web/src/lib/agent-schema.ts`) and emits two tiers of issue:

| Level | What it means |
|-------|---------------|
| `error` | Required field missing or wrong shape (e.g. `name` not kebab-case, `kind` outside the five primitives). The agent still loads — the parser passes the raw frontmatter through so a single bad field doesn't blank out the whole agent — but you should fix the issue. |
| `warn`  | Soft semantic issues (stage anchor doesn't match a section id, chip id collides with a section id, continuation label longer than 28 chars, duplicate `ui.starters[].id`). |

How issues surface:

- **Dev server** — `[agent <id>] <level> at <path>: <message>` logged on parse;
  `/studio/<agent>` also shows a red banner at the top of the page (hidden in
  production builds).
- **CLI** — `oneie agent validate <path>` fails fast on `error`s;
  `oneie agent lint <path>` reports `warn`-tier issues. Both exit non-zero on
  failure so they wire into CI cleanly.
- **Publish** — `POST /api/agents/publish` runs the same schema and rejects
  the upload if frontmatter is unparseable or the `name` field doesn't match
  the publish target.

## Diff

`oneie agent diff <a.md> <b.md>` reports what *semantically* changed between
two versions — not a raw line diff. The output is a JSON shape with keys
like `promptChanged`, `skillsAdded`, `stagesAdded`, `stageContentChanged`,
`sectionsAdded`, `pillsAdded`, `uiChanged`, `themeChanged`. Great for PR
review comments and for spotting unintended drift between local + published.

## Round-tripping

- `oneie agent publish <path> --slug <workspace>` — upload to R2.
- `oneie agent pull <name> --slug <workspace>` — download the live version
  back into the current directory at `<name>/agent.md`.
- `oneie agent unpublish <name> --slug <workspace>` — remove from R2.
  Idempotent: deleting a non-existent agent returns ok with `removed: false`.

Same flow is exposed on the TS SDK via `client.publishAgent`,
`client.pullAgent`, `client.unpublishAgent`, and on the MCP side via the
`publish_agent`, `pull_agent`, and `unpublish_agent` tools.

### Version history and rollback

Every publish creates an archived version. The latest 20 versions are kept per agent:

```bash
# See all versions (newest first)
oneie agent history my-agent --slug my-workspace

# Roll back to a previous version (use the ts value from history)
oneie agent rollback my-agent --to 1715000000000 --slug my-workspace

# List all agents in a workspace
oneie agent list --slug my-workspace
```

Rollback re-validates the archived content before restoring. If the archived version has schema errors, the rollback is rejected with 422.

### Per-key API tokens

The shared `SERVER_SECRET` is for CI pipelines. Partners working on published agents should use per-key tokens scoped to their workspace:

```bash
# Create a token for your workspace
curl -X POST https://one.ie/api/keys \
  -H "Authorization: Bearer $SERVER_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"slug":"my-workspace","label":"ci-deploy"}'
# → { "ok": true, "token": "abc123...", "id": 5 }
# Store the token — it is shown once only.

# Use it for publish/pull/history/rollback
oneie auth login --key abc123...
oneie agent publish my-agent/agent.md --slug my-workspace
```

Revoke a token when it's no longer needed:
```bash
curl -X DELETE "https://one.ie/api/keys?slug=my-workspace&id=5" \
  -H "Authorization: Bearer $SERVER_SECRET"
```

## What's on the roadmap

- **Custom section kinds.** Partners declare new primitives via a small template + binding. Targets the cases where the ten built-in kinds don't fit.
- **Workspace-scoped skills registry.** Owner agents that ref skills published to the same workspace currently fall back to a bare-id placeholder on the studio page; full title/description hydration requires a registry round-trip we haven't built yet.
- **Per-agent message bubble shapes.** Right now everything inherits theme tokens — partners can already restyle via `theme`, but not change the bubble geometry.
- **`agent eval` real implementation.** The CLI command stubs to 0/0/0 today; needs the same eval harness `/api/chat` uses for skill grading.

---

*Markdown is the source. TypeScript is the compiled output. Author once, run on the web, in Fetch.ai uAgents, and on the agentverse — same file.*
