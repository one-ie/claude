---
title: Agency-CEO PDF — 17 pages (written for Brad)
slug: text
type: plan
tier: simple
mode: construction
tags: [writing, marketing, pdf, agency, writer-skill, persona-bound, prompt-caching]
source_of_truth:
  - text/persona-agency-owner.md     # WHO we write to — Brad. Load FIRST every cycle.
  - text/text-plan.md                # WHAT we say to him — page map, CTAs, rubric.
  - text/quotes.md                   # WHICH quotes go where — the ONLY quote source.
  - .claude/skills/writer/SKILL.md   # HOW we write — 7-step craft loop.
  - .claude/product-marketing.md     # VOICE — banned words, data rule.
  - text/speed.md                    # Calibration target — match this density and rhythm.
show: false
escape:
  condition: "any cycle's W4 rubric < 0.90 after the Opus polish pass on two consecutive cycles OR persona check fails (no push/pull/anxiety/job named on the page)"
  action: "halt that cycle; reread persona doc §3 (forces of progress) + §10 (objection ladder); rewrite from the strongest sentence down"
context_triggers:
  - pattern: "headline|hero|H1|tagline|subhead"
    inject: ".claude/skills/writer/references/copy-frameworks.md § The ten frameworks"
  - pattern: "cliche|adjective|seamless|leverage|robust|cutting-edge|game-changer|delve|unlock|elevate"
    inject: ".claude/skills/writer/references/anti-patterns.md"
  - pattern: "voice|tone|rhythm|ghostwrite"
    inject: ".claude/skills/writer/references/voice-matching.md"
  - pattern: "objection|fear|anxiety|risk|what if"
    inject: "text/persona-agency-owner.md § 10. The objection ladder"
  - pattern: "hope|dream|outcome|ARR|exit|multiple"
    inject: "text/persona-agency-owner.md § 8. Hopes / fears / dreams / problems"
  - pattern: "quote|citation|attribute|said|McKinsey|Bain|BCG|Gartner|Forrester|WPP|Publicis|Omnicom|Klarna|Bain"
    inject: "text/quotes.md § Practical / operator-grade bank"
---

# Agency-CEO PDF — 17 pages

**Goal:** ship `text/00-cover.md` through `text/16-speed.md` — one printable page each, two-pass written (Sonnet draft → Opus polish), every page passing the per-page rubric (`text-plan.md § Per-page rubric`) at composite ≥ 0.90 after the Opus pass.
**Exit:** `ls text/[0-9]*.md | wc -l` returns `17` AND every file ends with a rubric receipt line `<!-- rubric: … → 0.NN ✓ --> (opus)` with composite ≥ 0.90 AND `bash text/verify.sh` exits 0 (banned-word grep + em-dash count + word-count band + CTA-table match + Opus tag present).

---

## Why /do works for writing

The W1→W4 sandwich is structure-agnostic. Only W4's deterministic check is code-shaped by default; for this plan it's prose-shaped:

| Wave | Code default | This plan's substitution |
|---|---|---|
| W1 recon | read source files | identical — read primary sources per `text-plan.md § page map`, optionally spawn Haiku to index secondaries |
| W2 decide | architecture tradeoffs | pick **one** headline framework from `copy-frameworks.md`; lock the strongest sentence; outline the h2s; resolve the page's required numbers |
| W3a draft | Sonnet writes code | Sonnet writes prose — writer-skill 7-step loop (`SKILL.md:14-26`), draft → cut → show → structure → polish → read-aloud. All 17 pages spawned in **one message**, fully parallel. |
| W3b polish | (n/a) | **Opus** refinement pass, one per page, fully parallel — re-runs steps 4–6 (structure / sentence polish / read-aloud), enforces CFO-number rule, kills any survivors of the banned-word grep, raises rubric from ~0.80 → ~0.95 |
| W4 verify | biome + tsc + vitest + code-rubric ≥ 0.65 | `text/verify.sh` (grep-based hard gates) + writer-skill rubric (5 dims, gate ≥ 0.90 after Opus pass) + CTA-table match |

The escape, source_of_truth, context_triggers, and dependency-graph machinery all map cleanly. No code change to `/do` needed.

---

## Prompt caching strategy — why this batches the way it does

We write 17 pages × 2 passes = **34 model calls**. Each call ships a heavy shared prefix: the persona doc (~5k words), the plan map (~25k words), the writer skill (~3k words), `product-marketing.md` (~1k words), `speed.md` calibration (~1k words), and the anti-patterns list (~2k words). That's **roughly 80–90k input tokens of stable context per call** before the page-specific spec.

Anthropic prompt caching gives ~90% discount on cached input tokens, with a **5-minute TTL** on each cache breakpoint. The batching shape below is designed around that TTL — not just for ergonomics, but to make caching mechanical.

### The cacheable bundle (load once, hit 33 times)

```
┌─────────────────────────────────────────────────────────────┐
│  STABLE PREFIX  (cache breakpoint 1 — ~80k tokens, hot)     │
│                                                              │
│  1. text/persona-agency-owner.md       (~5k words)           │
│  2. text/text-plan.md                  (~25k words)          │
│  3. .claude/skills/writer/SKILL.md     (~3k words)           │
│  4. .claude/skills/writer/references/  (~5k words)           │
│       copy-frameworks.md + anti-patterns.md + voice-matching │
│  5. .claude/product-marketing.md       (~1k words)           │
│  6. text/speed.md (calibration target) (~1k words)           │
│                                                              │
│  Wave-stable. Same for every page, every pass. Cache it.     │
├─────────────────────────────────────────────────────────────┤
│  PAGE-SPECIFIC PREFIX  (cache breakpoint 2 — ~5k tokens)    │
│                                                              │
│  The single page-map entry for page NN (sections, sources,   │
│  required artefacts, locked CTA, persona elements to land).  │
│  Also wave-stable per page, but only useful to one agent.    │
├─────────────────────────────────────────────────────────────┤
│  PER-CYCLE SOURCES  (cache breakpoint 3 — ~10–30k tokens)   │
│                                                              │
│  The primary + secondary source files that the page draws    │
│  from (W1 recon output). Same for W3a and W3b within a       │
│  cycle. Cache it across the two passes.                      │
├─────────────────────────────────────────────────────────────┤
│  PER-CALL TASK  (NOT cached — small, varies per call)        │
│                                                              │
│  "Draft NN" (W3a Sonnet) or "Polish NN to 0.90+" (W3b Opus). │
│  The Sonnet draft is also injected at this layer for W3b.    │
└─────────────────────────────────────────────────────────────┘
```

### How this maps to the existing W1→W4 sandwich

- **W1 recon** runs once per page (Haiku, cheap, parallel across all 17). Output is the *PER-CYCLE SOURCES* layer above — keep it in memory; pass it verbatim to both W3a and W3b for that page.
- **W2 decide** updates the *PAGE-SPECIFIC PREFIX* (locks the strongest sentence, the framework choice, the artefacts). Update once; W3a and W3b both read it.
- **W3a Sonnet draft** — spawn **all 17 in one message** (one Agent-tool call with 17 parallel invocations) so they land inside the same 5-minute cache window. First call writes the cache for the *STABLE PREFIX*; calls 2–17 hit it. Time the batch so all 17 fire within 60 seconds; W3a typically returns within 3 minutes. The whole W3a wave finishes inside one cache TTL.
- **W3b Opus polish** — same shape. Spawn all 17 Opus calls in one message immediately after W3a returns. Each W3b call also gets its Sonnet draft inline (per-call task layer). If W3a→W3b handoff is fast (< 4 minutes), the *STABLE PREFIX* cache is still warm for the first W3b call too; otherwise the first Opus call re-warms it and calls 2–17 hit.

### Wall-clock targets for cache to land

| Wave | Targeted wall clock | Cache state |
|------|---------------------|-------------|
| W3a spawn → W3a return | < 4 min | First Sonnet writes cache (~80k tokens, full price). 16 subsequent hits at ~10%. |
| W3a return → W3b spawn | < 30 s | Stable prefix still hot — no re-warm needed. |
| W3b spawn → W3b return | < 4 min | First Opus may re-warm if Sonnet's cache rolled. 16 subsequent hits at ~10%. |

If a wave runs over 5 minutes (a slow source-read, a queue stall), the second pass pays full price on the prefix. That's an acceptable degraded mode — the writing is still correct — but it's worth budgeting one re-warm in cost estimates.

### Rough cost math (Opus 4.7 input pricing as the worst case)

- Uncached: 34 × 80k = **2.72M input tokens** at full rate
- Cached (best case, both waves inside TTL): 1 × 80k full + 33 × 80k × 0.10 = **0.34M effective input tokens** — an **~87% reduction on prefix tokens**, before counting per-call task tokens
- Cached (degraded case, one re-warm): 2 × 80k full + 32 × 80k × 0.10 = **0.42M effective** — still **~85% reduction**

Net: prompt caching across the batched waves cuts the dominant cost line by roughly 6×. **Worth designing for.**

### Implementation notes for `/do` agent prompts

- The **stable prefix** is everything that doesn't change across pages. Load it as the *first* block of the system prompt so the cache breakpoint sits before any per-page variation.
- The **page-specific prefix** is the next block. Cache it too — W3a and W3b for the same page hit it twice.
- The **per-cycle sources** (W1 output) follow. Cache them across W3a and W3b for the same page; do not cache them across pages.
- The **per-call task** is the only variable layer: "write a fresh draft" vs. "polish this draft to 0.90+, here's the Sonnet output to start from."
- Set `cache_control: {"type": "ephemeral"}` on the last message of each cacheable block in the Anthropic API call.
- Use **the same Agent-tool invocation** for all 17 parallel agents in a wave. Multiple separate invocations land in different cache windows and don't share.

### Why this matters now, not later

Page 09 (Teams) alone will go to the top of the word budget (~7k words drafted + Opus polish). Each page now reads ~80k tokens of prefix on every call. Without caching, generating the PDF is a $30+ Opus run; with it, a $5 run. Sub-$10 runs make iteration cheap — we can regenerate the PDF after any persona update, any voice-contract change, any speed-table refresh. **Cheap iteration is what keeps the PDF current.**

---

## Dependency graph

**Default is parallel.** No cycle reads a file another cycle writes — every page is its own file, every page draws from the same primary sources. Spawn all 17 in one message.

```
C0 C1 C2 C3 C4 C5 C6 C7 C8 C9 C10 C11 C12 C13 C14 C15 C16   (all parallel)
```

The only soft coupling is **tone calibration**: every cycle re-reads `text/speed.md` in W1 as a reference. That's a read dependency on an existing file, not on another cycle's output, so it does not gate parallelism.

---

## W3 agent parallelism map

```
W3a — parallel (all 17 pages, different files, one message):
  agent-00  →  text/00-cover.md
  agent-01  →  text/01-brand.md
  agent-02  →  text/02-agency.md
  agent-03  →  text/03-chatbots.md
  agent-04  →  text/04-models.md
  agent-05  →  text/05-agents.md
  agent-06  →  text/06-skills.md
  agent-07  →  text/07-tools.md
  agent-08  →  text/08-memory.md
  agent-09  →  text/09-teams.md
  agent-10  →  text/10-tracking.md
  agent-11  →  text/11-analytics.md
  agent-12  →  text/12-crm.md
  agent-13  →  text/13-learning.md
  agent-14  →  text/14-development.md
  agent-15  →  text/15-security.md
  agent-16  →  text/16-speed.md   (mv text/speed.md → rubric pass only)

W3b — Opus polish (all 17, parallel, one message, fires after W3a returns):
  opus-00  →  text/00-cover.md
  opus-01  →  text/01-brand.md
  ... (one Opus per page, same fan-out as W3a)
  opus-16  →  text/16-speed.md
```

**Why two passes, not one.** Sonnet is fast and obedient — great for drafting against a tight spec. Opus is slower but catches what Sonnet can't: prose rhythm, structural emphasis mismatches, the third pass of cutting, and the "would the CEO repeat this to her CFO?" judgment call on every number. The two-pass shape mirrors the writer skill's own draft→edit separation (`SKILL.md:43-75`): draft fast without judgement (Sonnet), then cut and polish with judgement (Opus). Doing both in one agent collapses the loop and produces neither a good draft nor a good edit.

Cost: 17 Opus calls is the price of the PDF being worth printing. Worth it.

Every Sonnet agent (W3a) gets this prompt skeleton. The blocks are ordered for **prompt-cache fit** — stable prefix first, then page spec, then per-cycle sources, then the per-call task. Mark a `cache_control: ephemeral` breakpoint at the end of each cacheable block.

```
═════════════════════ STABLE PREFIX (cache breakpoint 1) ═════════════════════
PERSONA (the only person you are writing to):
  Brad — agency owner profiled in text/persona-agency-owner.md. Read the full
  doc. He is mid-fifties, runs a 30-staff agency, has 7 ICPs and 12k contacts,
  has bet a few hundred thousand on us, and sits at Schwartz awareness level 4
  (product-aware, moving to most-aware). The job stack — functional, emotional,
  social, identity — and the forces of progress (push / pull / anxiety /
  attachment) are non-negotiable inputs.

ROLE: You are the `writer` skill (.claude/skills/writer/SKILL.md). Voice
  contract: .claude/product-marketing.md. Calibration target: text/speed.md.

═════════════════════ PAGE PREFIX (cache breakpoint 2) ═════════════════════
PAGE: NN — {name}. Read text/text-plan.md § page map entry for page NN, end
  to end, including the persona binding table at the top of text-plan.md.

═════════════════════ SOURCES (cache breakpoint 3) ═════════════════════
{W1 recon output for page NN — verbatim file contents, no summarization}

═════════════════════ PER-CALL TASK (not cached) ═════════════════════
Write text/NN-name.md. Run the 7-step core loop (SKILL.md:14-26). Lock the
strongest sentence first (SKILL.md:122-126). Apply the data rule on every
claim. Headings: one h1, h2 sections only. End with the locked CTA from
text-plan.md § CTA table. End the file with the rubric receipt comment.

PERSONA REQUIREMENTS (binding — checked at W4):
1. Land at least one PUSH from persona doc §3 (what Brad hates today).
2. Defuse at least one ANXIETY from persona doc §3 / §10 (the objection ladder).
3. Land at least one PULL from persona doc §3 / §6 (the dream outcome).
4. Name at least one JOB from persona doc §2 (functional, emotional, social,
   or identity). The per-page job table in text-plan.md says which.
5. Pull objections (if your page lists them) from persona doc §10 — do not
   invent new ones; the ladder is research output, not improvisation.
6. Use sentences from the shape in persona doc §14 where they fit. Never use
   sentences from persona doc §13 (Brad-banned).
7. The whole page should be readable as written *to* Brad, not *about*
   agencies in the abstract. If you can substitute "agencies" for "Brad" and
   the sentence still works, rewrite it tighter — he is the named reader.

CONSTRAINTS:
- 4500–7000 words (cover: 1000–1800; 09-teams: 6000–8000)
- Hit EVERY artefact in text-plan.md § Universal depth checklist:
  * 8–12 CFO-grade numbers
  * 3–5 worked examples (different industry/size/horizon, each costed)
  * 5–8 objections answered (drawn from persona doc §10 ladder)
  * 2–3 side-by-side comparisons (vs hiring, vs DIY, vs incumbent)
  * 1 pricing-math walkthrough (inputs → assumptions → £ and % answer)
  * 2–3 failure modes (when NOT to use this)
  * 1 "day in the life" paragraph (named, scened, time-stamped — Brad or
    Brad-equivalent at the centre)
  * 2–3 code/config excerpts (≤25 lines each, captioned)
  * 2 diagrams or tables
  * 1 FAQ block (5–10 Q&A pairs — Brad's actual questions)
  * 1 glossary block (3–5 terms)
  * 3 cross-references (2 forward, 1 back)
  * 1 named integration / file path / route
- Plus the page's own required-artefacts list in text-plan.md § page map
- **Quote rule: text/quotes.md is the ONLY quote source.** If the page calls
  for a quote, take it from `quotes.md`. Never invent, paraphrase, or pull
  from training data. If `quotes.md` has no fitting quote for the page's
  argument, skip the quote slot — do not improvise. Per-page assignments
  live in `text-plan.md § page map > NN > Quote slot`; the "Strongest
  combinations" footer in `quotes.md` pre-builds threat / FOMO / TAM /
  incumbent-bet clusters. Reproduce quotes verbatim with attribution and
  year. Any quote marked `[verify exact wording]` must either be sourced
  to its exact original or omitted.
- CFO test on every number: money / time / conversion / risk / scale / comparison.
  Engineering trivia (LoC, loop cadences, internal thresholds) only when it
  directly anchors a money or time claim Brad would repeat to his CFO.
- Zero items from anti-patterns.md AND zero items from persona doc §13.
- ≤1 em-dash per paragraph, ≤6 in the page
- Every adjective survives the "drop-all-adjectives" drill or gets cut
- Every claim has a number, citation, or [stat: …] placeholder

EXIT: file ends with
  `<!-- rubric: fit=X strongest=X show=X cut=X craft=X → 0.NN ✓ --> (sonnet)`
  and
  `<!-- persona: push=Y anxiety=Y pull=Y job={fn|em|so|id} -->`
```

Every Opus agent (W3b polish) gets this prompt skeleton. Cache-fit ordering matches W3a — the stable prefix and page prefix are byte-identical so the W3a → W3b handoff inherits hot cache (assuming sub-5-minute wave timing).

```
═════════════════ STABLE PREFIX (cache breakpoint 1 — SAME bytes as W3a) ═════════════════
PERSONA: text/persona-agency-owner.md (full). You are editing for Brad.
ROLE: Senior editor. Writer skill: .claude/skills/writer/SKILL.md.
  Voice: .claude/product-marketing.md. Calibration target: text/speed.md.
  Quote bank: text/quotes.md.

═════════════════ PAGE PREFIX (cache breakpoint 2 — SAME bytes as W3a) ═════════════════
PAGE: NN — {name}. Read text/text-plan.md § page map entry for NN, plus the
  persona-binding table and per-page job table at the top of text-plan.md.

═════════════════ SOURCES (cache breakpoint 3 — SAME bytes as W3a) ═════════════════
{W1 recon output for page NN — verbatim, same content W3a received}

═════════════════ PER-CALL TASK (not cached — varies per call) ═════════════════
The Sonnet draft of text/NN-name.md is on disk, scored ~0.80 on the per-page
rubric. Your job: take it to ≥ 0.90 without lengthening it. Voice intact.
Craft per SKILL.md, with emphasis on steps 4 (structure), 5 (five sentence
questions), 6 (read aloud).

THE SONNET DRAFT (read once, end-to-end, before changing anything):
{contents of text/NN-name.md as written by W3a}

EDIT PASS:
1. Identify the one sentence Brad would underline. If it isn't in the first
   paragraph, move it there. Delete what made it the third paragraph instead.
2. PERSONA AUDIT. Confirm the Sonnet draft lands all four binding elements:
   - One push      (persona doc §3 — what Brad hates today)
   - One anxiety   defused (§3 / §10 objection ladder)
   - One pull      (§3 / §6 — the dream outcome)
   - One named job (§2 — match the per-page job table)
   If any is missing or weak, rewrite that paragraph to land it. Update the
   `<!-- persona: ... -->` footer accordingly.
3. Read on for the CFO test, adjective audit, and cut pass below — but the
   persona audit gates everything else. A page that scores 0.95 on craft and
   misses a job is still a fail.

ORIGINAL EDIT PASS (steps continue):
1. Read the file once end-to-end without changing anything. Identify the one
   sentence the agency CEO would underline. If it isn't in the first paragraph,
   move it there. Delete whatever made it the third paragraph instead.
2. Run the CFO test on every number: money / time / conversion / risk / scale /
   comparison. Replace or delete engineering trivia (lines of code, loop
   cadences, internal thresholds) unless it directly anchors a money or time
   claim the CEO would repeat to her CFO.
3. Adjective audit. For every adjective, find the number or scene that earned
   it; if it isn't there, either supply the number or cut the adjective.
4. Cut 10–20% of the words. The page should feel denser, not shorter.
5. Sentence-level pass — meaning, clarity, tone, novelty, beauty
   (SKILL.md:130-140). Stop at clarity if rushed; reach beauty when you can.
6. Read aloud. Rewrite any sentence that stumbles.
7. Confirm: one h1, h2 sections only, no h3, no emoji, no exclamation marks,
   CTA matches text-plan.md § CTA table verbatim, all required artefacts present.
8. Replace the sonnet rubric receipt with your own scored line, ≥ 0.90 composite.

CONSTRAINTS:
- Do not lengthen beyond the band. Final word count must stay 4500–7000
  (cover 1000–1800; 09-teams 6000–8000). If Sonnet underran, Opus may
  add depth — more worked examples, more objections, more pricing math —
  to reach the band; never pad.
- Preserve every required artefact (worked example, code excerpt, table/diagram,
  objection answered, cross-reference, named integration/path). Rewrite them
  if weak; do not delete them.
- Preserve the locked CTA verbatim.
- **Quote rule (binding):** `text/quotes.md` is the only quote source.
  If the Sonnet draft used a quote that isn't in `quotes.md`, replace it
  with the fitting one from `quotes.md § Practical / operator-grade bank`
  per the page's `Quote slot` line in `text-plan.md § page map`. If
  Sonnet skipped the slot but the page would close stronger with a quote
  from the Strongest-combinations clusters (threat / FOMO / TAM /
  incumbent-bet), add it. Never invent, paraphrase, or import quotes
  from outside this file. Drop any quote marked `[verify exact wording]`
  unless its exact source has been confirmed.
- Zero items from anti-patterns.md after your pass.
- ≤6 em-dashes total. ≤1 per paragraph.

EXIT: file ends with
  `<!-- rubric: fit=X strongest=X show=X cut=X craft=X → 0.NN ✓ --> (opus)`
   with 0.NN ≥ 0.90, AND
  `<!-- persona: push=Y anxiety=Y pull=Y job={fn|em|so|id} -->`
   with all four Y.
```

---

## Status

- [x] C0 — 00-cover         (1181 w · 0.92 · opus)
- [x] C1 — 01-brand         (6275 w · 0.93 · opus)
- [x] C2 — 02-agency        (5066 w · 0.92 · opus)
- [x] C3 — 03-chatbots      (5665 w · 0.91 · opus)
- [x] C4 — 04-models        (4602 w · 0.92 · opus)
- [x] C5 — 05-agents        (5258 w · 0.92 · opus)
- [x] C6 — 06-skills        (4519 w · 0.91 · opus)
- [x] C7 — 07-tools         (5006 w · 0.92 · opus)
- [x] C8 — 08-memory        (4945 w · 0.93 · opus)
- [x] C9 — 09-teams         (6424 w · 0.92 · opus)   *(closer · top-of-band)*
- [x] C10 — 10-tracking     (5632 w · 0.91 · opus)   *(load-bearing)*
- [x] C11 — 11-analytics    (6124 w · 0.92 · opus)   *(load-bearing · renewal deliverable)*
- [x] C12 — 12-crm          (5835 w · 0.92 · opus)
- [x] C13 — 13-learning     (5277 w · 0.92 · opus)   *(load-bearing)*
- [x] C14 — 14-development  (4634 w · 0.91 · opus)
- [x] C15 — 15-security     (4662 w · 0.92 · opus)
- [x] C16 — 16-speed        (5417 w · 0.93 · opus)

**Cycle close** (2026-05-15): `bash text/verify.sh --all` exits 0. All 17 pages: word band ✓, rubric ≥0.90 (opus) ✓, persona footer all Y ✓, banned vocab zero ✓, em-dash budget ✓.

**Composite stats:** 17/17 pages above 0.90 rubric · mean composite 0.92 · max 0.93 · min 0.91 · total PDF body ~90k words.

Each cycle has the same W1→W4 shape (below). Per-page specifics live in `text-plan.md § page map`.

**Load-bearing trio (§10 → §11 → §13).** These three pages together justify every "self-improvement" claim elsewhere in the PDF. §10 captures the data, §11 ships the report, §13 names the loops. If any one of them under-delivers (thin worked example, weak monthly-report shape, vague loops), the dream-team page in §09 reads as marketing rather than evidence. W2 must read all three plan-map entries together before drafting any one of them, and W3 should spawn the trio in one batch so the cross-references stay in sync.

**Voice guardrail for §10 / §11 (paired with the load-bearing flag).** These pages are the most likely to drift engineer-mode. Every paragraph must pass: *would the agency CEO repeat this to her CFO?* If not, rewrite. Allowed CEO terms: *inbox · channel · conversation · record · receipts · route · report · dashboard · quality score.* Banned in body copy (allowed only in §10's named-integration line at the bottom of the page): *signal · path · pheromone · actor · dimension · loop name (L1–L7) · mark/warn · TypeDB · D1 · KV · claw · receiver · ingress · upsert.* W4 grep checks for the banned set; any hit in body copy fails the cycle.

---

## Quote routing — `text/quotes.md` is the only source

Every quote that appears in any page comes from `text/quotes.md`. Nothing else. No training-data quotes, no paraphrases, no "as someone once said." If the page's argument doesn't find a fitting line in `quotes.md`, the quote slot stays empty.

`quotes.md` has two layers:
- **Aspirational bank** (the original — Naval, Hassabis, Saint-Exupéry, Karpathy, Linden, Boyd, etc.) — tone slots; use sparingly
- **Practical / operator-grade bank** (the appended section — Klarna, WPP, Publicis, Omnicom, McKinsey, Bain, BCG, Gartner, Forrester, CMO Barometer, Benioff, Huang, Nadella) — conversion slots; use these by default for an agency-CEO PDF

**Page-to-bucket map.** W2 picks the exact quote off `quotes.md`; this table tells it which bucket to look in first.

| Page | Primary bucket | Backup bucket | Pre-built cluster (from quotes.md footer) |
|------|----------------|---------------|--------------------------------------------|
| 00 Cover | Pressure (Bucket 3) | FOMO (Bucket 4) | Threat slide opener |
| 01 Brand | Aspirational (Naval distribution) | Operator (Klarna) | — |
| 02 Agency | Operator (Bucket 1) + Forrester | Analyst (Bucket 2) | **Threat slide** (Klarna 25% + Gartner 22% + Forrester 15%) |
| 03 Chatbots | Operator (Bucket 1) | Aspirational (Karpathy) | — |
| 04 Models | FOMO (Bucket 4 — Benioff / Huang) | Aspirational (ONE's own line) | — |
| 05 Agents | FOMO (Benioff "digital labor") | Aspirational (Altman) | Incumbent-bet cluster |
| 06 Skills | Operator (Bucket 1) | — | — |
| 07 Tools | FOMO (Nadella "AI chiefs of staff") | Aspirational (Gates) | — |
| 08 Memory | Aspirational (de Geus) | Operator | — |
| 09 Teams | Pressure (CMO Barometer 12%) + FOMO (Sadoun / Wren / Bolloré) | Versaunt (from aspirational bank) | **Incumbent-bet cluster** |
| 10 Tracking | Operator (Klarna / IDHL / Butler-Till) | Aspirational (Boyd) | — |
| 11 Analytics | Analyst (Bain 4× ROI / BCG 2× revenue) | Versaunt | **TAM slide** |
| 12 CRM | Pressure (ANA in-house 78%) | Operator | — |
| 13 Learning | Aspirational (Hassabis continual learning) | Analyst (BCG leaders 2× revenue) | — |
| 14 Development | FOMO (Benioff "no engineers in 2025") | Aspirational (Kay) | — |
| 15 Security | (skip — threat-model table is the proof) | — | — |
| 16 Speed | Operator (speed→revenue stats in aspirational bank — Amazon, Walmart, Akamai, Google) | Aspirational (Girouard) | — |

**Cluster usage.** The four pre-built clusters (Threat / FOMO / TAM / Incumbent-bet) at the bottom of `quotes.md` are *deck-ready combinations*, not single quotes. A page may use **a cluster as a callout box** (e.g. three short cited lines stacked) in place of, or alongside, the single-quote slot. Reserve clusters for pages 00, 02, 09, 11 — the conversion pages.

**Quote integrity rules (binding for W3a, W3b, and W4):**
1. Verbatim only. Attribution + year always included.
2. URL stays in the source map (`text-plan.md § page map > NN > Quote slot`); body copy carries name + publication + year, not the URL.
3. Skip beats invent. An empty quote slot is fine; a fabricated one fails the cycle.
4. Any quote marked `[verify exact wording]` in `quotes.md` (currently: Eric Siu's $1–2M/employee) must be confirmed against the original source before printing, or omitted.
5. One quote per page maximum, except for the four conversion pages above where a *cluster* (3 short cited lines) is allowed in addition.

**W4 quote check.** `text/verify.sh` greps each page for `"` and `>` quoted lines; any line that looks like a quote but isn't traceable to `quotes.md` fails the cycle. (Implementation: extract quoted strings ≥ 30 chars; check each appears in `quotes.md`.)

---

## C_n — per-page cycle template  [tier: simple]

**Exit:** `text/NN-name.md` exists; word count in band (4500–7000 content; 1000–1800 cover; 6000–8000 for 09-teams); two-pass written (Sonnet draft → Opus polish); ends with `(opus)` rubric receipt ≥ 0.90; every universal-depth-checklist artefact present; passes `text/verify.sh`; CTA matches `text-plan.md § CTA table` verbatim.

### W1 — Recon  [Haiku · parallel]

For page NN, read everything listed in `text-plan.md § page map > NN`. Then:
- re-read `text/speed.md` (calibration target)
- if the page's primary sources are thin, spawn Haiku to index `/Users/toc/Server/one.ie/` and `/Users/toc/Server/one-ie/dev.one.ie/` per `text-plan.md § Source hierarchy`

W1 reports back: every concrete number, named feature, file path, and code snippet that fits the page's h2s.

### W2 — Decide  [Sonnet]

W1 findings + `text-plan.md § page map > NN` resolve these questions:

1. Which **one** headline framework from `copy-frameworks.md` fits this page best? (JTBD / PAS / BAB / outcome+timeframe / hard-thing-without-pain / plain-truth / numbered-nouns / category-for-audience / Dunford / quote)
2. What is the **strongest sentence** — the one the agency CEO would underline? It goes first.
3. Which h2 sections survive the cut? `text-plan.md` lists them; W2 may drop any that lack a number.
4. Which numbers from W1 anchor which paragraph? (data rule — every adjective gets a number)
5. Any `[stat: …]` placeholders the writer can't resolve from sources? List them.
6. Quote slot — take from `text-plan.md § Quote & stat bank` or skip?

### W3 — Edit

**W3a — Sonnet draft [parallel with all other cycles, one message]:**
- [ ] `text/NN-name.md` — Sonnet writes per W2 decisions, ends with `(sonnet)` rubric receipt ≥ 0.80

**W3b — Opus polish [parallel with all other cycles, fires after W3a returns]:**
- [ ] `text/NN-name.md` — Opus refines per its prompt skeleton, ends with `(opus)` rubric receipt ≥ 0.90, does not lengthen, preserves every required artefact and the locked CTA

### W4 — Verify  [Haiku · inline]

- [ ] file exists, word count in target range (4500–7000 content; 1000–1800 cover; 6000–8000 09-teams): `wc -w text/NN-name.md`
- [ ] every universal-depth artefact present (worked example, code excerpt, table/diagram, objection answered, cross-ref, named integration/path)
- [ ] every number in the page passes the CFO test (money/time/conversion/risk/scale/comparison) — engineering trivia only when it directly anchors a money/time claim
- [ ] CTA matches table verbatim: `grep -F "$(cta_for NN)" text/NN-name.md`
- [ ] banned words zero: `bash text/verify.sh NN` exits 0
- [ ] em-dash count ≤ 6 per page, ≤ 1 per paragraph
- [ ] rubric receipt present, marked `(opus)`, composite ≥ 0.90: `tail -1 text/NN-name.md` matches `<!-- rubric: .* → 0\.9\d ✓ --> \(opus\)` or `→ 1\.00 ✓ \(opus\)`
- [ ] **persona footer present and all four flags = Y** — `<!-- persona: push=Y anxiety=Y pull=Y job={fn|em|so|id} -->`. Failure of any flag halts the cycle and re-enters W3b with explicit instruction to land the missing element (`verify.sh` step 6b).
- [ ] **Brad-banned vocabulary** (persona doc §13) — zero hits via `verify.sh` step 6c. Body copy clean; fenced code and HTML comments exempt.
- [ ] data rule: zero un-cited adjectival claims (read-aloud audit)

Targets per dimension: audience-fit ≥ 0.8 · strongest-first ≥ 0.8 · show-not-tell ≥ 0.8 · cut ≥ 0.8 · craft ≥ 0.8.

Report: `words=N  em_dashes=N  banned=N  rubric=0.NN`

---

## C16 — 16-speed   [tier: trivial]

**Exit:** `text/speed.md` renamed to `text/16-speed.md`, rubric receipt appended, passes `text/verify.sh`.

the speed doc just gives the raw numbers we want to make them feel very relevant to a ceo also compare to chatgpt openai etc. 

`/do` skips W1/W2/W3 for trivial cycles:
- [ ] `mv text/speed.md text/16-speed.md` (or `git mv`)
- [ ] read it once; score each rubric dimension; append the receipt
- [ ] confirm CTA matches `*Measure us. We'll measure back.*` — add if missing
- [ ] `bash text/verify.sh 16` exits 0

---

## text/verify.sh — the W4 deterministic check

`/do` reads this as the prose equivalent of `bun run verify`. Create at C0 W3a (one-shot, all cycles depend on it being present).

```bash
#!/usr/bin/env bash
# text/verify.sh — prose W4 gate. Usage: bash text/verify.sh [NN | --all]
set -euo pipefail

cd "$(dirname "$0")"
TARGET="${1:---all}"
FAIL=0

# Banned vocabulary from writer SKILL.md + product-marketing.md
BANNED='\b(seamless|leverage|robust|cutting-edge|game-changer|game-changing|delve|unlock|elevate|empower|transform|supercharge|revolutionise|revolutionize|world-class|best-in-class|next-generation|actionable insights?|move the needle|low-hanging fruit|at the end of the day|in conclusion|in summary|in the realm of|tapestry|landscape \(as a metaphor\)|it.?s important to note)\b'

check_file() {
  local f="$1"
  local file_fail=0

  # 1. banned words
  local banned_count
  banned_count=$(grep -ciE "$BANNED" "$f" || true)
  if [ "$banned_count" -gt 0 ]; then
    echo "✗ $f: $banned_count banned word(s)"
    grep -niE "$BANNED" "$f" | head -5
    file_fail=1
  fi

  # 2. em-dash budget: ≤ 6 per page
  local em
  em=$(grep -o '—' "$f" | wc -l | tr -d ' ')
  if [ "$em" -gt 6 ]; then
    echo "✗ $f: $em em-dashes (limit 6)"
    file_fail=1
  fi

  # 3. word count: cover 1000–1800, others 4500–7000 (09-teams may reach 7500 before split)
  local words
  words=$(wc -w < "$f" | tr -d ' ')
  local fname; fname=$(basename "$f")
  local lo=4500 hi=7000
  if [[ "$fname" == "00-cover.md" ]]; then
    lo=1000; hi=1800
  elif [[ "$fname" == "09-teams.md" ]]; then
    lo=6000; hi=8000
  fi
  if [ "$words" -lt "$lo" ] || [ "$words" -gt "$hi" ]; then
    echo "✗ $f: $words words (target $lo–$hi)"
    file_fail=1
  fi

  # 4. heading rule: exactly one h1, no h3
  local h1; h1=$(grep -c '^# ' "$f" || true)
  local h3; h3=$(grep -c '^### ' "$f" || true)
  [ "$h1" -ne 1 ] && { echo "✗ $f: $h1 h1 headings (need 1)"; file_fail=1; }
  [ "$h3" -ne 0 ] && { echo "✗ $f: $h3 h3 heading(s) — only h2 allowed"; file_fail=1; }

  # 5. rubric receipt present, marked (opus), composite ≥ 0.90
  local receipt
  receipt=$(tail -3 "$f" | grep -oE '<!-- rubric:.*-->.*' | tail -1 || true)
  if [ -z "$receipt" ]; then
    echo "✗ $f: missing rubric receipt"
    file_fail=1
  else
    if ! echo "$receipt" | grep -q '(opus)'; then
      echo "✗ $f: rubric receipt not marked (opus) — Opus polish pass missing"
      file_fail=1
    fi
    local score
    score=$(echo "$receipt" | grep -oE '→ [0-9]\.[0-9]+' | grep -oE '[0-9]\.[0-9]+' || echo "0")
    if awk "BEGIN{exit !($score < 0.90)}"; then
      echo "✗ $f: rubric composite $score < 0.90 (post-Opus target)"
      file_fail=1
    fi
  fi

  # 6. no exclamation marks, no emoji
  if grep -qE '!' "$f"; then
    echo "✗ $f: exclamation mark(s) found"
    file_fail=1
  fi

  # 6b. persona footer present and all four flags = Y
  local persona
  persona=$(tail -5 "$f" | grep -oE '<!-- persona:[^>]*-->' | tail -1 || true)
  if [ -z "$persona" ]; then
    echo "✗ $f: missing persona footer (push/anxiety/pull/job)"
    file_fail=1
  else
    local push_v anxiety_v pull_v job_v
    push_v=$(echo "$persona" | grep -oE 'push=[YN]' | cut -d= -f2)
    anxiety_v=$(echo "$persona" | grep -oE 'anxiety=[YN]' | cut -d= -f2)
    pull_v=$(echo "$persona" | grep -oE 'pull=[YN]' | cut -d= -f2)
    job_v=$(echo "$persona" | grep -oE 'job=(fn|em|so|id)')
    if [ "$push_v" != "Y" ] || [ "$anxiety_v" != "Y" ] || [ "$pull_v" != "Y" ] || [ -z "$job_v" ]; then
      echo "✗ $f: persona footer incomplete — push=$push_v anxiety=$anxiety_v pull=$pull_v job=$job_v"
      echo "      (all four must land — see persona doc §2/§3/§10)"
      file_fail=1
    fi
  fi

  # 6c. Brad-banned vocabulary (persona doc §13) — body copy must have none
  # Allowed only inside HTML comments (footers) or fenced code blocks
  local bradban='\b(AI-powered|cutting-edge|game-changer|empower your team|future-proof|seamless integration|reach out to learn more|trusted by leading brands|built by AI experts|in today.?s fast-paced world|transform your agency)\b'
  local bradban_count
  bradban_count=$(grep -ciE "$bradban" "$f" || true)
  if [ "$bradban_count" -gt 0 ]; then
    echo "✗ $f: $bradban_count Brad-banned phrase(s) (see persona doc §13)"
    grep -niE "$bradban" "$f" | head -5
    file_fail=1
  fi

  # 7. quote traceability — every quoted line ≥ 30 chars must appear in quotes.md
  # (extract quoted strings and the > blockquote bodies; check each is in quotes.md)
  local QUOTES_FILE="quotes.md"
  if [ -f "$QUOTES_FILE" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      # strip the markdown wrapping
      local body
      body=$(echo "$line" | sed -E 's/^> *//; s/^"//; s/"$//' | tr -s ' ')
      [ ${#body} -lt 30 ] && continue
      # take a 30-char fingerprint from the middle and search quotes.md
      local fp
      fp=$(echo "$body" | cut -c5-34)
      if ! grep -qF "$fp" "$QUOTES_FILE"; then
        echo "✗ $f: quote not traceable to quotes.md — ${body:0:60}…"
        file_fail=1
      fi
    done < <(grep -E '^> .{30,}|"[^"]{30,}"' "$f")
  fi

  if [ "$file_fail" -eq 0 ]; then
    echo "✓ $f: words=$words em=$em rubric=$score"
  fi
  FAIL=$((FAIL + file_fail))
}

if [ "$TARGET" = "--all" ]; then
  for f in [0-9][0-9]-*.md; do
    [ -f "$f" ] && check_file "$f"
  done
else
  for f in ${TARGET}-*.md; do
    [ -f "$f" ] && check_file "$f"
  done
fi

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "FAIL: $FAIL file(s) did not pass"
  exit 1
fi
echo ""
echo "PASS: all checked files green"
```

`/do` runs this at every W4. Any non-zero exit dissolves the cycle back to W3 with the diff.

---

## See also

- `text/text-plan.md` — page map, CTA table, per-page rubric, source hierarchy
- `text/quotes.md` — **the only quote source.** Two banks: aspirational (tone) and practical/operator-grade (conversion). Plus pre-built threat / FOMO / TAM / incumbent-bet clusters at the footer. Every quote in every page must be traceable here.
- `.claude/skills/writer/SKILL.md` — the 7-step core loop, the five sentence questions, banned vocabulary
- `.claude/skills/writer/references/copy-frameworks.md` — the ten headline frameworks (W2 picks one)
- `.claude/skills/writer/references/anti-patterns.md` — banned-word source for `verify.sh`
- `.claude/product-marketing.md` — voice contract layered on top of writer skill
- `text/speed.md` — calibration target for every cycle's W1
- `one/template-todo.md` — this file's structural source
- `one/rubrics.md` — scoring bands (writer-skill rubric extends these for prose)
