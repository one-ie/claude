---
title: ONE Home Page v4 — Your AI Workforce Awaits
slug: home
type: plan
tier: simple
mode: construction
tags: [home, landing-page, chat-integration, motion, workforce]

parallel_budget:
  haiku:   20
  sonnet:  10
  opus:    1

batches:
  - [C1]                     # foundation: ChatSeedButton + home-sections (data + types)
  - [C2, C3, C4, C5]        # SectionBlock + HomeHero/ProofBar + TeamOrgChart + SpeedReceipt — all parallel
  - [C6]                     # wire index.astro — composes everything

shared_recon:
  - plans/home.md
  - one.ie/web/src/pages/index.astro
  - one.ie/web/src/components/Chat.tsx
  - one.ie/web/src/components/Personas.tsx
  - one.ie/web/src/layouts/Layout.astro
  - one.ie/web/src/lib/personalize-map.ts
  - text/00-cover.md
  - text/09-teams.md
  - text/16-speed.md

source_of_truth:
  - plans/home.md
  - one.ie/web/src/components/Chat.tsx
  - one.ie/web/src/pages/index.astro
  - text/09-teams.md
  - text/16-speed.md

existing_primitives:
  - one.ie/web/src/components/Chat.tsx: consumes `one:chat-seed` CustomEvent at lines 344-367 — C1 bridge, no new protocol needed; verify it also emits `one:chat-first-token` for SpeedReceipt (else add a 4-line emitter)
  - one.ie/web/src/components/Personas.tsx: `dispatchSeed(text, persona)` pattern — C1 copies this function verbatim
  - one.ie/web/src/components/motion/Reveal.astro: scroll-triggered fade-up — C6 wraps every section
  - one.ie/web/src/components/motion/Stagger.astro: staggered child entrance (--i CSS var) — used in ProofBar and TeamOrgChart
  - one.ie/web/src/components/motion/demo/ScrollCounter.tsx: animated count-up on scroll — used in ProofBar and §20 math
  - one.ie/web/src/components/Hero.tsx: headline/subhead/CTA shell — C3 HomeHero composes it
  - one.ie/web/src/components/ui/Icon.tsx: Lucide icon wrapper — used in TeamOrgChart role cards
  - one.ie/web/src/components/ui/IconBadge.tsx: toned icon badge — used in TeamOrgChart role cards (lg/md sizes)
  - one.ie/web/src/lib/personalize-map.ts: `pickHeroVariant` + `HERO_VARIANTS` — C3 HomeHero

show: false
escape:
  condition: "any cycle's W4 bun run build fails AND delta_tsc > 0 twice"
  action: "halt; isolate failing component; re-scope the cycle to fix the single broken import before retrying"

context_triggers:
  - pattern: "chatMode|chat-mode|one:chat-seed|dispatchSeed|one:chat-first-token"
    inject: "one.ie/web/src/components/Chat.tsx § External seed"
  - pattern: "Reveal|Stagger|ScrollCounter|stagger-child"
    inject: "one.ie/web/src/pages/motion.astro § Stats bar"
  - pattern: "TeamOrgChart|org chart|director|specialists"
    inject: "plans/home.md § 4. TeamOrgChart"
  - pattern: "SpeedReceipt|performance.timing|first-token"
    inject: "plans/home.md § 5. SpeedReceipt"
---

# ONE Home Page v4 — Your AI Workforce Awaits

**Thesis:** *Your AI Workforce Awaits.* Marketing · Sales · Service — three full teams, twenty-seven named roles, live the hour you sign. Under your brand. On your invoice. The corpus stays with you.

**Goal:** Replace the sparse 4-section home with a 24-section split landing page where the right rail is always-live chat, the visual centerpiece is a beautiful 27-role org chart (rendered three times — one per department), and the speed claim is proven on the page measuring itself.

**Exit:** `bun run build` green + `bun run verify` green + manual smoke: scroll the page, click 5 different chat seeds across acts (hero, one team, one platform feature, one foundation feature, FAQ), each produces a streaming response in the right rail. Plus: 27 roles render across §4–§6, and `SpeedReceipt` shows a real non-zero page-load number on the production build.

---

## Reuse contract (read before drafting any cycle)

**Power through simplicity.** The smallest amount of new code that closes the loop wins. Every cycle must answer the **compose-or-construct** question before W3 spawns any agent.

### The compose-or-construct test

For every new file a cycle proposes, W2 must record one line:

> **`{file}`** — no existing primitive covers `{specific behaviour}`. Closest match: `{path}` does `{what}` but lacks `{gap}`. Composition would require `{≥N hacks}` and lose `{what}`.

If you can't fill that in, **delete the new file from the W3 list** and slot the behaviour into the closest existing primitive instead.

### Compose-first taxonomy

| Layer | Where to look | Default verdict |
|---|---|---|
| 1. **Domain composition** | `web/src/components/` existing files | extend the file that already renders this surface |
| 2. **Cross-surface composition** | `chat/`, `motion/`, `cards/`, `ui/` | import + slot — do not copy |
| 3. **Design primitives** | `web/src/components/ui/` | compose; never reimplement |
| 4. **Library primitives** | `@/lib/`, existing hooks | reuse the helper |
| 5. **New file** | only if 1–4 all fail | requires the W2 justification line above |

**Anti-patterns rejected on sight:**
- ❌ New `<Modal>` / `<Drawer>` when `ui/` already has them
- ❌ Inline `<svg>` when `<Icon>` / `<IconBadge>` exist
- ❌ New `dispatchSeed` implementation when `Personas.tsx` already has it (copy verbatim)
- ❌ Bespoke animated counter when `ScrollCounter.tsx` exists
- ❌ Reading `performance.timing` outside `SpeedReceipt.tsx`
- ❌ Re-implementing the role-card visual outside `TeamOrgChart.tsx`

---

## Parallel execution plan

### Cycle-level DAG

```
                C1
       ╱  │  │  │  ╲
     C2  C3  C4  C5         ← all four read SectionData / OrgRole types + ChatSeedButton from C1
       ╲  │  │  │  ╱
                C6           ← wires index.astro, imports everything
```

Arrow test:
- C1 → C2: C2 imports `SectionData` from `@/lib/home-sections` and `ChatSeedButton` from C1.
- C1 → C3: C3 imports `ChatSeedButton` from C1.
- C1 → C4: C4 imports `ChatSeedButton` and `OrgRole` from C1 (OrgRole lives in TeamOrgChart but C1 must re-export it via SectionTeam type).
- C1 → C5: C5 imports `ChatSeedButton` from C1.
- C2,C3,C4,C5 → C6: C6 (`index.astro`) imports `SectionBlock`, `HomeHero`, `ProofBar`, `TeamOrgChart`, `SpeedReceipt`, `FinalCTA-dissolved` from each. Also `HOME_SECTIONS` from C1.

**Note on the type cycle:** `OrgRole` lives in `TeamOrgChart.tsx` (it's the chart's domain type). `SectionTeam` in `home-sections.ts` imports it. To break the apparent cycle, C1 defines `OrgRole` first as a small standalone type file (`web/src/lib/home-org-types.ts`, ≤ 30 LOC) which both C1 (home-sections.ts) and C4 (TeamOrgChart.tsx) import.

### Batches

| Batch | Cycles | What runs in parallel |
|-------|--------|----------------------|
| 0 | shared W0 + W1 | baseline + shared_recon reads |
| 1 | C1 | full W1→W4 (sequential — others depend on types) |
| 2 | C2, C3, C4, C5 | four cycles W1→W4 in lockstep; W3a merges into one Sonnet message |
| 3 | C6 | full W1→W4 (wires everything) |

---

## Status

```
Batch 0 (shared)
  - [x] W0 baseline
  - [x] W1 shared recon (9 files)

Batch 1
  - [x] C1 — Foundation: ChatSeedButton + home-sections + OrgRole types     state: closed · rubric ≈ 0.92
    - [x] W1 recon · W2 decide · W3 edit · W4 verify

Batch 2
  - [x] C2 — SectionBlock (10 layout variants, thin slot delegation)          state: closed · 217 LOC ≤ 220
    - [x] W1 · W2 · W3 · W4
  - [x] C3 — HomeHero + ProofBar                                              state: closed · 47 + 41 LOC
    - [x] W1 · W2 · W3 · W4
  - [x] C4 — TeamOrgChart (the beautiful 27-role centerpiece)                state: closed · 73 LOC, 27 roles asserted
    - [x] W1 · W2 · W3 · W4
  - [x] C5 — SpeedReceipt (live performance receipt)                          state: closed · 69 LOC + Chat.tsx 1-line emitter
    - [x] W1 · W2 · W3 · W4
  - [x] demo batch (bun run verify after all four land)

Batch 3
  - [x] C6 — Wire index.astro                                                 state: closed
    - [x] W1 · W2 · W3 · W4

Plan close
  - [x] bun run build green (12.39s)
  - [ ] Manual smoke: 5 ChatSeedButton clicks → 5 chat responses   (requires dev server)
  - [x] 27 roles render (12 + 8 + 7 across §4–§6)                  (asserted via TOTAL_ROLE_COUNT)
  - [ ] SpeedReceipt shows real page-load number on production build (requires deployed page)
  - [ ] 5-second test passes on a fresh reader                      (requires human reader)
  - [x] Plan rubric ≥ 0.65 (composite 0.91)
```

**Spec drifts logged (2026-05-20):**
- `motion/demo/ScrollCounter.tsx` is a 4-step scroll-progress demo, not a count-up; substituted with static numbers in CSS `.stagger-child` cascade.
- `SectionBlock` takes `sectionId: string` (not `data: SectionData`) — Astro cannot serialize `LucideIcon` across the client-island JSON boundary; React-internal lookup keeps icons resolved in the bundle.
- `HomeHero.tsx` renders its own headline structure rather than composing `Hero.tsx` (whose hardcoded "you can sell." doesn't fit the workforce thesis).
- Side-fix: missing `SignInWithAnything` imports in `signin.astro` + `signup.astro` (pre-existing broken state; required to unblock `bun run build`).

---

## C1 — Foundation: ChatSeedButton + OrgRole types + home-sections  [tier: simple · batch: 1]

**Exit:** `bun run verify` green + `grep -c 'chatSeed' one.ie/web/src/lib/home-sections.ts` ≥ 23 (one per section) + `ChatSeedButton` named export present + `OrgRole` named export present in `one.ie/web/src/lib/home-org-types.ts` + 27 roles across the three SectionTeam entries.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bunx tsc --noEmit 2>&1 | grep -c error || true"
  asserts: "zero TypeScript errors after C1 files land"
  budget:  "<10s wall · <420 LOC new across 3 files"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `one.ie/web/src/components/Personas.tsx` — read full `dispatchSeed` function + call pattern
   - [ ] `one.ie/web/src/components/Chat.tsx:344-367` — confirm `one:chat-seed` handler + `__chatSeedPending` drain; check whether `one:chat-first-token` is emitted (if not, note for C5)
   - [ ] `one.ie/web/src/lib/ui-signal.ts` — confirm `emitClick` signature

2. **Primitive-inventory recon**
   - [ ] `one.ie/web/src/components/ui/Icon.tsx` — prop signature
   - [ ] `one.ie/web/src/components/ui/IconBadge.tsx` — prop signature (tone, size)
   - [ ] `one.ie/web/src/lib/personalize-map.ts` — confirm `HERO_VARIANTS` keys

3. **Content recon (for home-sections.ts data)**
   - [ ] `text/09-teams.md` — extract all 27 role names + blurbs (12 marketing, 8 sales, 7 service)
   - [ ] `text/16-speed.md` — extract 4 proof-bar numbers + the speed comparison table (TTFT, Lighthouse, JS payload for ONE/Claude/ChatGPT)
   - [ ] `text/00-cover.md` — hero thesis
   - [ ] `text/01-brand.md` through `text/08-memory.md` — one-sentence body per platform section
   - [ ] `text/10-tracking.md` through `text/14-development.md` + `text/15-security.md` — one-sentence body per unified-view + foundation section
   - [ ] `plans/home.md` — full §4–§6 detail + §22 FAQ rows + §23 stake + §24 final CTA

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `components/ChatSeedButton.tsx` | `Personas.tsx` has `dispatchSeed` inline | needs standalone reusable button called from 23+ sections | **new** |
| `lib/home-org-types.ts` | none — type-only file | n/a; breaks cycle between TeamOrgChart and home-sections | **new** (≤ 30 LOC) |
| `lib/home-sections.ts` | none — data file | n/a | **new** — 23 entries with all section copy + 3 team org definitions |

- [ ] **Slot map** — `ChatSeedButton` composes `<Icon>` (no new icon primitives). `home-sections.ts` imports `OrgRole` from `lib/home-org-types.ts`.
- [ ] **`dispatchSeed` decision:** copy the 10-line function from `Personas.tsx` verbatim into `ChatSeedButton.tsx` — no shared util.
- [ ] **`home-sections.ts` shape** — export `HOME_SECTIONS: SectionData[]` with 23 entries, plus three named team constants `MARKETING_TEAM`, `SALES_TEAM`, `SERVICE_TEAM` of type `SectionTeam` (which §4–§6 entries reference). All copy from `plans/home.md` and `text/` files; no paraphrasing.
- [ ] **LOC budget:** `ChatSeedButton.tsx` ≤ 50 · `home-org-types.ts` ≤ 30 · `home-sections.ts` ≤ 360
- [ ] **Diff specs output** for W3a

### W3 — Edit  [Sonnet · parallel]

**W3a — three new files spawned in one message:**

- [ ] `one.ie/web/src/lib/home-org-types.ts` — new file, type-only:
  ```ts
  import type { LucideIcon } from 'lucide-react'
  export interface OrgRole {
    title: string
    icon: LucideIcon
    blurb: string
    chatSeed?: string
    tone?: 'primary' | 'secondary' | 'tertiary' | 'neutral'
  }
  ```
- [ ] `one.ie/web/src/components/ChatSeedButton.tsx` — new file. Named export. Props per `plans/home.md § 3. ChatSeedButton`. Copies `dispatchSeed`, calls `emitClick('ui:home:chat-seed', { section, text })`, dispatches `one:chat-seed`. Variants: primary / secondary / ghost / tile. 6-token styling, `rounded-full`, `px-6 py-3` (primary); `text-sm underline-offset-4 hover:underline` (ghost).
- [ ] `one.ie/web/src/lib/home-sections.ts` — new file. `SectionData`, `SectionTeam`, `SectionItem`, `SectionMetric` types per `plans/home.md § 6. SectionBlock`. `OrgRole` imported from `home-org-types`. 23 `HOME_SECTIONS` entries + 3 team constants. Lucide icons imported per role (see `plans/home.md § 4` sample for marketing). All copy from `text/` and `plans/home.md`; never invented.

**W3b:** *(empty — three files are independent)*

### W4 — Verify  [inline]

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `grep -c 'chatSeed' one.ie/web/src/lib/home-sections.ts` ≥ 23
- [ ] `grep -c 'specialists' one.ie/web/src/lib/home-sections.ts` ≥ 3 (one per team)
- [ ] Programmatic role count: `MARKETING_TEAM.specialists.length === 11 && SALES_TEAM.specialists.length === 7 && SERVICE_TEAM.specialists.length === 6` (excluding the director) — assert in `home-sections.test.ts`
- [ ] Total roles (directors + specialists): `12 + 8 + 7 === 27` — asserted
- [ ] `grep 'export.*ChatSeedButton' one.ie/web/src/components/ChatSeedButton.tsx` → 1 match
- [ ] `grep 'export.*OrgRole' one.ie/web/src/lib/home-org-types.ts` → 1 match
- [ ] No banned vocabulary anywhere in `home-sections.ts` (grep against `.claude/product-marketing.md` banned list)
- [ ] No "Brad" or named-persona references anywhere in `home-sections.ts`
- [ ] Zero `!` punctuation in any rendered string
- [ ] **Reuse audit:**
  - [ ] `ChatSeedButton.tsx` imports `emitClick` from `@/lib/ui-signal` (not re-implemented)
  - [ ] `ChatSeedButton.tsx` imports `Icon` from `@/components/ui/Icon`
  - [ ] `wc -l` budgets respected
- [ ] Rubric composite ≥ 0.65

---

## C2 — SectionBlock (10 layout variants, slot-delegating)  [tier: simple · batch: 2]

**Exit:** `bun run verify` green + `SectionBlock` renders all 10 layout variants without TSC errors + `grep 'TeamOrgChart\|SpeedReceipt' one.ie/web/src/components/SectionBlock.tsx` ≥ 2 (proves slot delegation).

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bunx tsc --noEmit 2>&1 | grep -c error || true"
  asserts: "zero TypeScript errors; SectionBlock compiles with all 10 layouts"
  budget:  "<10s wall · ≤220 LOC"
```

### W1 — Recon  [Haiku · parallel]

- [ ] `one.ie/web/src/components/Strategy.tsx` — layout pattern for split sections
- [ ] `one.ie/web/src/components/ChatSeedButton.tsx` — prop signature (from C1)
- [ ] `one.ie/web/src/lib/home-sections.ts` — confirm `SectionData` interface (from C1)
- [ ] `one.ie/web/src/components/ui/IconBadge.tsx` + `Icon.tsx` — tone/size variants

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `components/SectionBlock.tsx` | `Strategy.tsx` covers 1 layout | needs 10 layouts including slot delegation to TeamOrgChart and SpeedReceipt | **new** |

- [ ] **Slot delegation:** `team-org` and `speed-receipt` layouts are **thin wrappers** that render the copy column inline and the visual column as `<TeamOrgChart>` or `<SpeedReceipt>` respectively. SectionBlock contains *no* org-chart rendering and *no* `performance.*` reads.
- [ ] **Stagger in React** — grid items use inline `style={{ '--i': i } as CSSProperties}` + `className="stagger-child"`. Animation keyframes injected globally by C6 in `index.astro`.
- [ ] **LOC budget:** `SectionBlock.tsx` ≤ 220
- [ ] **Diff specs output**

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `one.ie/web/src/components/SectionBlock.tsx` — new file. Props: `{ data: SectionData }`. Ten layout branches (`centered`, `split-left`, `split-right`, `team-org`, `speed-receipt`, `metrics-grid`, `pillar-grid`, `faq`, `cta`, `persona-picker`). Every layout that has CTAs ends with a `<ChatSeedButton>`. `team-org` renders `<TeamOrgChart team={data.team!} />` in the visual slot; `speed-receipt` renders `<SpeedReceipt {...data.speedReceipt!} />`. All classes use 6-token system only.

**W3b:** *(empty)*

### W4 — Verify  [inline]

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `grep 'export.*SectionBlock' one.ie/web/src/components/SectionBlock.tsx` → 1 match
- [ ] `wc -l one.ie/web/src/components/SectionBlock.tsx` ≤ 220
- [ ] **Reuse audit:**
  - [ ] Imports `ChatSeedButton`, `TeamOrgChart`, `SpeedReceipt` (composing, not re-implementing)
  - [ ] Imports `IconBadge` for pillar/tile rendering
  - [ ] Zero `performance.timing` or `performance.now()` references
  - [ ] Zero `<ul>` org-chart-like nested structures (delegation only)
  - [ ] Zero hex literals or `bg-zinc-` references
- [ ] Rubric composite ≥ 0.65

---

## C3 — HomeHero + ProofBar  [tier: simple · batch: 2]

**Exit:** `bun run verify` green + both named exports present + `ProofBar` references `ScrollCounter`.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bunx tsc --noEmit 2>&1 | grep -c error || true"
  asserts: "zero TypeScript errors; HomeHero and ProofBar compile"
  budget:  "<10s wall · ≤160 LOC combined"
```

### W1 — Recon  [Haiku · parallel]

- [ ] `one.ie/web/src/components/Hero.tsx` — confirm `variant` prop + composability
- [ ] `one.ie/web/src/components/PersonalizedHero.tsx` — confirm `visitorHash` + `slug` + `pickHeroVariant`
- [ ] `one.ie/web/src/components/motion/demo/ScrollCounter.tsx` — full props
- [ ] `one.ie/web/src/components/ChatSeedButton.tsx` — confirm C1 output

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `components/HomeHero.tsx` | `PersonalizedHero.tsx` wraps `Hero.tsx` | needs 2 CTAs (Hire + Show me), workforce thesis copy, no full-page chat assumption | **new** |
| `components/ProofBar.tsx` | `Buyers.tsx` is a trust bar | needs 4 animated metrics with `ScrollCounter` | **new** |

- [ ] **HomeHero copy:** headline *"Your AI Workforce Awaits."* · subhead per `plans/home.md § 1` · primary CTA *"Hire my workforce"* → `/get-yours` · secondary `<ChatSeedButton text="..." label="Show me my team">` · microcopy *"5,000,000 credits for $500. Pilot one client. No annual contract."*
- [ ] **ProofBar metrics:** 5s wallet · 60s bot live · 48h deployment · 90s report (from `text/16-speed.md` + `00-cover.md`)
- [ ] **LOC budget:** `HomeHero.tsx` ≤ 90 · `ProofBar.tsx` ≤ 70
- [ ] **Diff specs output**

### W3 — Edit  [Sonnet · parallel]

**W3a — two new files in one message:**
- [ ] `one.ie/web/src/components/HomeHero.tsx` — new file. Props per `plans/home.md § 1. HomeHero`. Uses `pickHeroVariant` + `useWatch` (same as `PersonalizedHero`). Renders `<Hero variant={variant}>` for headline shell. Two CTAs below subhead. `emitClick('ui:home:hero-primary')` on Hire click. No third CTA, no inline Personas.
- [ ] `one.ie/web/src/components/ProofBar.tsx` — new file. Four metric objects hardcoded. Each renders a `<ScrollCounter>` with staggered `--i` index. Caption beneath in `text-font/50 text-sm` referencing §18.

**W3b:** *(empty)*

### W4 — Verify  [inline]

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `grep 'ScrollCounter' one.ie/web/src/components/ProofBar.tsx` ≥ 1
- [ ] `grep 'Hero' one.ie/web/src/components/HomeHero.tsx` ≥ 1 (composing)
- [ ] `grep 'Hire my workforce' one.ie/web/src/components/HomeHero.tsx` → 1 match (CTA copy locked)
- [ ] **Reuse audit:** HomeHero composes `Hero`, ChatSeedButton; ProofBar composes ScrollCounter
- [ ] `wc -l` budgets respected
- [ ] Rubric composite ≥ 0.65

---

## C4 — TeamOrgChart (the beautiful 27-role centerpiece)  [tier: simple · batch: 2]

**Exit:** `bun run verify` green + `TeamOrgChart` renders correctly for all three departments (marketing 12 · sales 8 · service 7) + CEO label + Director card + specialists grid + payroll callout + click-to-seed behaviour.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bunx tsc --noEmit 2>&1 | grep -c error || true"
  asserts: "zero TypeScript errors; TeamOrgChart compiles; storybook-style snapshot test passes for 3 departments"
  budget:  "<15s wall · ≤180 LOC"
```

### W1 — Recon  [Haiku · parallel]

- [ ] `one.ie/web/src/components/ui/IconBadge.tsx` — full prop signature; tones (primary/neutral) and sizes (md/lg)
- [ ] `one.ie/web/src/components/ui/Icon.tsx` — confirm Lucide icon prop type
- [ ] `one.ie/web/src/components/ChatSeedButton.tsx` — confirm `variant="ghost"` + `className` prop (from C1)
- [ ] `one.ie/web/src/lib/home-org-types.ts` — confirm `OrgRole` shape (from C1)
- [ ] `one.ie/web/src/lib/home-sections.ts` — confirm `SectionTeam` shape + the three team constants
- [ ] `text/09-teams.md` — re-read for the canonical role list + Director responsibilities
- [ ] `plans/home.md § 4. TeamOrgChart` — read the full visual structure spec (ASCII diagram, role card snippet, motion choreography)

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `components/TeamOrgChart.tsx` | none — there is no org-chart primitive in the codebase | the load-bearing visual of the page; 27 named roles across 3 departments; bespoke director hierarchy + specialists grid | **new** — fully justified; this is the visual centerpiece, not a wrapper |

- [ ] **Slot map:**
  - Composes `IconBadge` (size lg for director, md for specialists), `Icon` (no — IconBadge wraps it), `ChatSeedButton` (variant="ghost" overlay for role clicks)
  - Uses `stagger-child` global CSS class (already injected by C6)
  - No new motion primitive — `style={{ '--i': i }}` is the existing pattern
- [ ] **Visual hierarchy via three signals (not lines):** position (CEO above Director above grid), size (Director col-span-2 / 420px max-width), tone (Director uses primary; specialists neutral). One optional thin 1px vertical line from CEO to Director, no lines from Director to specialists.
- [ ] **Card pattern:**
  ```tsx
  <article
    className="group rounded-2xl border bg-background p-5 lg:p-6
               transition will-change-transform
               hover:-translate-y-0.5 hover:shadow-lg
               focus-within:-translate-y-0.5 focus-within:shadow-lg
               stagger-child relative"
    style={{
      borderColor: 'var(--color-border)',
      boxShadow: 'var(--shadow-card)',
      ['--i' as string]: index,
    }}
  >
    <IconBadge icon={role.icon} tone={role.tone ?? 'neutral'} size="lg" />
    <h3 className="mt-3 font-semibold text-base lg:text-lg">{role.title}</h3>
    <p className="mt-1 text-sm text-font/60 leading-snug">{role.blurb}</p>
    {role.chatSeed && (
      <ChatSeedButton
        variant="ghost"
        text={role.chatSeed}
        label={`Show me the ${role.title}`}
        className="absolute inset-0 z-10 sr-only-focus"
      />
    )}
  </article>
  ```
  The `absolute inset-0` overlay makes the whole card the hit target while keeping inner content semantic.
- [ ] **Responsive layout:**
  - Outer: `flex flex-col gap-8 items-center text-center`
  - CEO label: `text-xs uppercase tracking-[0.18em] text-font/40` — text only, no card
  - Director: `<header>` card, centered, `max-w-[420px]`, `p-6 lg:p-7`
  - Specialists: `<ul role="list">` with `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 w-full`
- [ ] **Accessibility:**
  - Outer `<section aria-label="${department} department">`
  - `<ul role="list">` for specialists
  - `<header>` semantic for Director
  - IconBadge `aria-hidden="true"`
  - Whole-card clickable via overlay; focus ring on `<button>` inside ChatSeedButton — focus-within bubbles to card
- [ ] **Motion choreography:**
  - CEO label: fades in at 0ms, no stagger
  - Director: `--i: 0`, 120ms in
  - Specialists: `--i: 1..N`, 60ms each, cascading
  - Total: ≤ 1.2s for marketing (largest team)
  - `prefers-reduced-motion`: handled by existing global rule
- [ ] **Default seeds:** if a role has no `chatSeed`, generate one at render time: `Show me what the ${role.title} actually does day-to-day.` Director default: `Show me how the ${dept} director runs the department.`
- [ ] **LOC budget:** `TeamOrgChart.tsx` ≤ 180
- [ ] **Diff specs output**

### W3 — Edit  [Sonnet]

**W3a:**
- [ ] `one.ie/web/src/components/TeamOrgChart.tsx` — new file. Named export `TeamOrgChart`. Props per `plans/home.md § 4. TeamOrgChart`. Structure: section → CEO caption → 1px vertical line → Director card → specialists `<ul>`. Director uses `IconBadge size="lg"` with `tone="primary"`; specialists use `IconBadge size="lg"` with their own tone (defaults to `neutral`). Click overlay via `<ChatSeedButton variant="ghost" className="absolute inset-0">`. Payroll callout below the grid: `<p class="text-sm text-font/50 mt-6">UK median payroll: {payroll}</p>`. Uses `stagger-child` class with `--i` CSS variable for cascade. `emitClick('ui:home:team:<dept>:<role.title>')` on each card click.

**W3b:** *(empty)*

### W4 — Verify  [inline]

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `grep 'export.*TeamOrgChart' one.ie/web/src/components/TeamOrgChart.tsx` → 1 match
- [ ] `wc -l one.ie/web/src/components/TeamOrgChart.tsx` ≤ 180
- [ ] **Rendering test (vitest + @testing-library/react):**
  - Render `<TeamOrgChart {...MARKETING_TEAM} />` — assert 1 director + 11 specialists rendered (12 total roles)
  - Render `<TeamOrgChart {...SALES_TEAM} />` — assert 1 director + 7 specialists
  - Render `<TeamOrgChart {...SERVICE_TEAM} />` — assert 1 director + 6 specialists
  - Total across 3 renders: 27 roles
- [ ] **Accessibility test:**
  - `<section aria-label>` present
  - `<ul role="list">` present
  - Each role card has an accessible name via `<ChatSeedButton>` label
  - No `<div role="button">` antipatterns
- [ ] **Click test:**
  - Mock `window.dispatchEvent`; click a specialist card; assert `one:chat-seed` was dispatched with the role's seed
  - Click the director card; assert default-seed text dispatched if `chatSeed` undefined
- [ ] **Reuse audit:**
  - Imports `ChatSeedButton`, `IconBadge`, `OrgRole` type
  - Zero hex, zero `bg-zinc-*`
  - Zero `<svg>` inlined (uses IconBadge / Icon)
- [ ] Rubric composite ≥ 0.65 (lift target: 0.75 — this is the page's visual centerpiece)

---

## C5 — SpeedReceipt (live performance receipt)  [tier: simple · batch: 2]

**Exit:** `bun run verify` green + `SpeedReceipt` renders three lines + page-load number > 0 on production build + Lighthouse `<time dateTime>` element present.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bunx tsc --noEmit 2>&1 | grep -c error || true"
  asserts: "zero TypeScript errors; SpeedReceipt compiles; vitest tests for performance.timing pass"
  budget:  "<10s wall · ≤80 LOC"
```

### W1 — Recon  [Haiku · parallel]

- [ ] `one.ie/web/src/components/Chat.tsx` — confirm whether `one:chat-first-token` event is emitted in `sendMessage`. If yes, note the event detail shape. **If no, this cycle adds a 4-line emitter** (W3b below).
- [ ] `plans/home.md § 5. SpeedReceipt` — read the full structure + runtime behaviour spec

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `components/SpeedReceipt.tsx` | none — bespoke live-data panel | reads `performance.timing` and subscribes to chat first-token event; runtime side-effects justify isolation | **new** |

- [ ] **Slot map:** standalone component, no composition; uses 6-token system + IconBadge optional for the receipt watermark
- [ ] **Three lines, each its own row** with `border-t border-foreground/5` separator:
  1. `this page loaded in {N.NN}s`
  2. `first token of this chat: {N}ms`
  3. `/chat Lighthouse today: {P} / {A} / {B} / {S}` followed by `<time dateTime={lighthouseDate}>measured {date}</time>`
- [ ] **`performance.timing` read:**
  ```ts
  const loadMs = typeof performance !== 'undefined' && performance.timing
    ? performance.timing.loadEventEnd - performance.timing.navigationStart
    : 0
  ```
  If `loadMs === 0`: attach a `window.addEventListener('load', () => setLoadMs(performance.now()))` and clean up on unmount.
- [ ] **First-token subscription:**
  ```ts
  useEffect(() => {
    const handler = (e: CustomEvent<{ ms: number }>) => setFirstToken(e.detail.ms)
    window.addEventListener('one:chat-first-token', handler as EventListener)
    return () => window.removeEventListener('one:chat-first-token', handler as EventListener)
  }, [])
  ```
- [ ] **Default lighthouseScores:** `[100, 91, 100, 100]` per `text/16-speed.md` measurement of 2026-05-15
- [ ] **LOC budget:** `SpeedReceipt.tsx` ≤ 80

### W3 — Edit  [Sonnet]

**W3a:**
- [ ] `one.ie/web/src/components/SpeedReceipt.tsx` — new file. Named export. Props per `plans/home.md § 5. SpeedReceipt`. Three lines stacked vertically inside a `<div>` with receipt styling. State for `loadMs` and `firstTokenMs`. `useEffect` reads `performance.timing` on mount and subscribes to `one:chat-first-token` event. `<time dateTime>` element on the Lighthouse line. Reduced-motion: animations skip; final values shown immediately.

**W3b (conditional — only if W1 found `one:chat-first-token` is NOT emitted):**
- [ ] `one.ie/web/src/components/Chat.tsx` — add a 4-line emitter inside `sendMessage` (or wherever the first token arrives in the streaming handler):
  ```ts
  if (!firstTokenEmitted) {
    window.dispatchEvent(new CustomEvent('one:chat-first-token', { detail: { ms: Date.now() - sendTime } }))
    firstTokenEmitted = true
  }
  ```
  Strictly additive; does not change existing behaviour. Place inside the streaming start.

### W4 — Verify  [inline]

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `grep 'export.*SpeedReceipt' one.ie/web/src/components/SpeedReceipt.tsx` → 1 match
- [ ] `wc -l one.ie/web/src/components/SpeedReceipt.tsx` ≤ 80
- [ ] **Unit test (vitest):**
  - Mock `performance.timing` with known values; render `<SpeedReceipt>`; assert the page-load number renders to 2 decimals
  - Mock `performance` undefined; assert `"—"` placeholder renders gracefully
  - Dispatch `one:chat-first-token` with `{ ms: 84 }`; assert the second line updates
  - Assert `<time dateTime="2026-05-15">` element present
- [ ] **Reuse audit:**
  - Only `performance.*` access in the codebase outside of dev tooling is in this file (`grep -rn 'performance\.timing\|performance\.now' one.ie/web/src/components/ | grep -v SpeedReceipt | wc -l` → 0)
  - Zero hex, zero `bg-zinc-*`
- [ ] **W3b applied (if needed):** `Chat.tsx` now emits `one:chat-first-token`; no regression in chat send behaviour (smoke test: send a message, assert response streams)
- [ ] Rubric composite ≥ 0.65

---

## C6 — Wire index.astro  [tier: simple · batch: 3]

**Exit:** `bun run build` green + `bun run verify` green + `index.astro` uses `chatMode="wide"` + 23 `SectionBlock` renders + `HomeHero` + `ProofBar` + stagger-child global CSS injected.

**Demo gate:**
```yaml
demo:
  command: "cd one.ie/web && bun run build 2>&1 | tail -5"
  asserts: "build completes; wrangler worker bundle produced; no broken imports"
  budget:  "<120s wall"
```

### W1 — Recon  [Haiku · parallel]

- [ ] `one.ie/web/src/pages/index.astro` — full current source; note imports + `<main>` body + `chatMode`
- [ ] `one.ie/web/src/layouts/Layout.astro:326-390` — confirm `wide` mode CSS grid columns
- [ ] `one.ie/web/src/components/Strategy.tsx` + `Buyers.tsx` — confirm not imported elsewhere (safe to remove from home)
- [ ] All C1–C5 outputs: named exports verified

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct:** `index.astro` is an existing file — this is a pure edit.
- [ ] **`chatMode` change:** `"chat-full"` → `"wide"`.
- [ ] **Import changes:** Remove `PersonalizedHero`, `Buyers`, `Strategy`, `Personas`. Add `HomeHero`, `ProofBar`, `SectionBlock`, `TeamOrgChart` (imported only so chunking works — also imported by SectionBlock but Astro needs the direct import for `client:visible` islands), `SpeedReceipt` (same reason), `Reveal`, `Stagger`. Import `HOME_SECTIONS` from `@/lib/home-sections`.
- [ ] **`<main>` structure:**
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
- [ ] **Stagger global CSS:** inject `<style is:global>` block with `.stagger-child` keyframes (fade-up 12px from `--i * 60ms`, respects `prefers-reduced-motion`).
- [ ] **LOC budget for the edit:** net delta ≤ +70 LOC

### W3 — Edit  [Sonnet]

**W3a:**
- [ ] `one.ie/web/src/pages/index.astro` — modify existing file per W2.

**W3b:** *(empty)*

### W4 — Verify  [inline]

- [ ] `bun run build` green (production bundle, no import errors)
- [ ] `bun run verify` green
- [ ] `grep 'chatMode="wide"' one.ie/web/src/pages/index.astro` → 1 match
- [ ] `grep -c 'SectionBlock' one.ie/web/src/pages/index.astro` ≥ 1
- [ ] `grep 'chat-full' one.ie/web/src/pages/index.astro` → 0 (old mode gone)
- [ ] `grep 'Strategy\|Buyers\|PersonalizedHero' one.ie/web/src/pages/index.astro` → 0 (old components gone)
- [ ] **Manual smoke (record findings):**
  1. Open dev server. Hero loads with workforce headline.
  2. Scroll to §4 Marketing — TeamOrgChart cascades in; CEO label visible above Director.
  3. Click a specialist card — chat opens in right rail with role-specific seed; response streams.
  4. Scroll to §18 Speed — SpeedReceipt shows non-zero load number.
  5. Scroll to §22 FAQ — accordion expands.
  6. Click §24 Final CTA — navigates to `/get-yours`.
- [ ] **Reuse audit:**
  - `Reveal`, `Stagger` imported from `@/components/motion/` (not re-implemented)
  - No `bg-zinc-*` or hex in modified file
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=0  delta_loc=+N  new_files=6  primitives_composed=11`

---

## Plan close

- [ ] `bun run build` green (final)
- [ ] `bun run verify` green (final)
- [ ] 5 manual smoke clicks confirmed (hero, team org-chart card, platform feature, speed receipt section, final CTA)
- [ ] 27 roles render (asserted in tests across MARKETING_TEAM, SALES_TEAM, SERVICE_TEAM)
- [ ] SpeedReceipt page-load number > 0 on production build (manual check on deployed `/`)
- [ ] 5-second test passes on a fresh reader: they say "AI workforce / for anyone with clients / live on day one"
- [ ] Plan rubric ≥ 0.65 across all cycles (lift target 0.75 for C4 — visual centerpiece)
- [ ] Pheromone: `surface:home-v4 mode:lean lifecycle:construction`
- [ ] Append to `plans/improvements.md`: any anchor mismatches found during W3

---

## See also

- `plans/home.md` — spec (24 sections, 6 acts, TeamOrgChart spec, SpeedReceipt spec, chat seed library)
- `text/09-teams.md` — canonical 27-role list with blurbs
- `text/16-speed.md` — comparison numbers + Lighthouse measurement date
- `text/00-cover.md` — locked thesis + proof numbers
- `text/persona-agency-owner.md` — objection ladder for §22 FAQ
- `one.ie/web/src/components/Chat.tsx:344-367` — `one:chat-seed` consumer
- `one.ie/web/src/components/Personas.tsx` — `dispatchSeed` pattern to copy
- `one.ie/web/src/pages/motion.astro` — motion primitive usage examples
- `plans/rubrics.md` — scoring bands (gate: 0.65)
- `plans/dictionary.md` — canonical names
