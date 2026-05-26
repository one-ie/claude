# /do-loop

**The outer build lifecycle.** `/do` (W0→W4) is the *execution engine* — it consumes a `-todo.md` and ships verified code. `/do-loop` is the *product loop* that wraps it: idea → goal → promise → survey → design → plan → equip → build → prove → teach → ship → learn.

> `/do` answers *"is the code correct?"* — bash gates, rubric ≥ 0.65.
> `/do-loop` answers *"did we ship what we promised, to whom, and can they use it?"*

**This file orchestrates; it does not reimplement.** Every phase composes a primitive that already exists. If a phase tempts you to write new machinery, you've misread the phase — find the command/skill it wraps.

```
/do-loop <feature-intent>            full lifecycle P0→P8 (tier auto-inferred)
/do-loop <feature> --tier fix        force a loop tier (patch|fix|feature|schema)
/do-loop <feature> --from P3         resume at a phase (skip done phases)
/do-loop <feature> --surface api     force a surface (skip auto-detect)
/do-loop --batch f1,f2,f3            independent features, parallel — one worktree each
```

---

## The front door — INTAKE (idea → goal)

Every loop starts as a raw idea, in any form — a line, a paragraph, a Slack paste. INTAKE's only job is to turn it into an agreed **goal** before any phase spends a token. It is the **one human gate** in the loop; everything downstream runs autonomously (trust-gated).

1. **Restate as a goal** — reflect the idea back as one sentence in the contract shape: *"a {persona} can {outcome} they couldn't before."* This is the spine: FRAME renders it as the promise (P0), PLAN formalizes it into `goal:`/`outcome:` frontmatter (P2), PROVE verifies it (P5). **Goal and promise are one thing, two faces** — the goal is machine-checkable (the outcome command), the promise is persona-readable (the copy).
2. **Locate + fit (cheap)** — `do-intent` search (does a todo / spec / feature already exist?) + the P0.5 substrate pre-scan (does it fit a dim + verb?). Haiku · bash greps.
3. **Propose tier + entry** — *"Looks like a FEATURE — full pipeline"* or *"mostly built — `expose` tier, I'll just wire the route."*

**The gate:** the human confirms or edits the one-sentence goal + tier. That confirmation is a `mark` — and the mark **promotes the seed** to durable backlog (see the lifecycle below). Pulling from a pre-agreed backlog auto-skips the gate (the goal was marked at capture).

**Propose-and-confirm in one shot** — never interrogate. Present your read of the goal + tier as a single correctable proposal; ask a real question only when *who* or *what-outcome* is genuinely ambiguous, and never more than one.

---

## The pipeline (INTAKE → P8)

Each phase closes with **one durable artifact** on disk. No phase advances until its artifact exists. This is the closed-loop rule applied to the build itself.

| # | Phase | Closes with (artifact) | Composes | Model · effort |
|---|-------|------------------------|----------|----------------|
| **INTAKE** | **GATE** | agreed **goal** sentence + tier (the one human gate) | `do-intent` search + `AskUserQuestion` | Sonnet · low |
| **P0** | **FRAME** | feature blurb in `text/` — the promise in persona language | `writer` skill + `product-marketing.md` | Sonnet · medium |
| **P0.5** | **SURVEY** | feature inventory + simplicity verdict + gap list (≤400 words) | grep the 4 surfaces + `plans/*.md` | Haiku · low |
| **P1** | **SPEC** | `plans/<f>.md` — **substrate-reconciled** architecture + frozen contract | `/typedb` + `one-ontology.md`/`dsl.md`/`dictionary.md` + `agent-api.md` §14-ops | Opus · high *(xhigh if `.tql`/new-primitive; max if dim/verb)* |
| **P2** | **PLAN** | `plans/<f>-todo.md` — goal contract + DAG + parallel budget | `/create todo` + `template-todo.md` | Opus · high |
| **P3** | **EQUIP** | `.claude/skills/<name>/SKILL.md` *(only if a capability is missing)* | skill-check ladder | Sonnet · medium |
| **P4** | **BUILD** | shipped + verified code (tests written here) | **`/do --auto`** (inner W0→W4) | *inner matrix* |
| **P5** | **PROVE** | surface proof + **promise-check** vs P0 copy | Chrome / curl / contract test | Haiku/bash · low |
| **P6** | **TEACH** | human how-to + agent runbook | `tutorial` skill pattern | Sonnet · medium |
| **P7** | **SHIP** | release note + changelog + README/feature doc + **adoption signal** | `/release` + `/close` propagate matrix | Haiku/bash · low |
| **P8** | **LEARN** | meta-edits to loop / skills / templates | **`/do --improve`** | Opus · high *(max if locked-rule-adjacent)* |

**Why this order.** Marketing first is not vanity — **the promise IS the goal contract**. P0's blurb becomes `goal:` / `ux_after:` in P2's todo frontmatter, and P5 re-reads it to verify we shipped what we said. Spec before plan because design-before-code is a repo rule. Equip before build so `/do` never stalls on a missing skill. Teach + ship after proof because you document what's real, not what's planned. Learn last because drift only exists after a cycle closes.

---

## Loop tiers — run only the phases the change earns

Phases are **opt-out for small work, not opt-in.** A typo does not get marketing copy, a tutorial, and a release note. Matching spend to the change is the loop's primary token control.

| Tier | Trigger | Phases | Isolation | Token shape |
|------|---------|--------|-----------|-------------|
| **PATCH** | copy tweak · typo · ≤2 files · no behaviour change | P4 only (`/do` trivial — 0 agent spawns) | trunk (direct) | ~bash, near-zero LLM |
| **FIX** | bug · behaviour change · no new surface or primitive | P0.5 → P1.0 check → P4 → P5 | trunk (direct) | one Sonnet edit pass + bash/`/browser` proof |
| **FEATURE** | new user-visible capability | P0 → P8 (full) | worktree → merge on P5 | full fan-out, budgeted |
| **SCHEMA** | touches `.tql` / dimension / verb / dictionary name | P1.0 at **max** effort, then full | worktree → merge on P5 | substrate is never a patch |

`/do-loop` infers the tier from intent + a one-line `git diff --stat` probe; `--tier` overrides. **When unsure, drop a tier, not up** — an under-built FIX surfaces in P5 and re-opens; an over-built PATCH is burnt tokens you can't refund.

**One gradient, two scopes.** These *product* tiers gate **which phases run**. Inside P4, `/do`'s own *code* classifier (TRIVIAL · SIMPLE · COMPLEX) gates **how the build executes** — agent spawns, model routing. They compose, they don't compete: the outer tier asks *how much product does this change earn?*, the inner asks *how much machinery does the build need?* A FEATURE can still be a SIMPLE build; a FIX can still be COMPLEX.

---

## P0.5 — Survey (the cheapest feature is the one you already ship)

Runs after FRAME, before SPEC. **Power through simplicity** (root motif) applied at *feature* scope — before the *file*-scope reuse-audit in `template-todo.md`. Three standing questions; their answers decide whether P1 even opens.

1. **Feature recon** — grep the four surfaces (`web/src/pages/api/` · `web/src/components/` · `packages/sdk/` · `agents/`) and `plans/*.md` for anything already doing ≥70% of the promise. Haiku · low · receipt capped at 400 words.
2. **Simplicity verdict** — for the closest match: *can the promise be kept with existing code, or less code?* Verdict ∈ `expose` (exists, just unreachable) · `extend` (add a field/slot) · `build` (genuinely new) · `drop` (the promise is goldplating). Default is **not** build.
3. **Gap scan** — does keeping this promise reveal an adjacent missing piece (an unwired signal, a half-shipped surface, a dead route)? Record gaps as follow-up task IDs; systemic ones feed **P8 LEARN**, not this loop.

Only a `build` verdict — no ≥70% match, no named gap that closes it cheaper — opens the full P1. `expose`/`extend` collapse the loop to **FIX** tier. Survey is the gate that stops the loop re-building what already exists, and its cheap substrate pre-scan answers *"does this even fit the ontology?"* before the expensive P1.0 reconciliation runs.

---

## P1.0 — Substrate reconciliation (the schema is truth)

The first move of P1, before any architecture. Root principle: **the schema is truth; the meta-layer expresses what the substrate already knows.** Most features touch zero schema — they compose the 6 dimensions and 6 verbs that already exist. The rare feature that needs a *type* change is the expensive case, and this gate is where it's caught — cheaply, before P0's promise hardens into code.

Four questions, in order — first hard-no wins:

| Q | Check | Verdict |
|---|-------|---------|
| **Dimension** | which of the 6 dims does this live in? (Groups · Actors · Things · Paths · Events · Learning) | fits one → proceed · needs a new/renamed dim → **reject** (locked) |
| **Verb** | does it close with one of the 6 verbs? (signal · mark · warn · fade · follow · harden) | yes → proceed · needs a new verb → **reject** (locked) |
| **Type** | does it need a new TypeQL entity/attribute or D1 column? | no → compose existing types · yes → justify against `schema/one.tql`, edit `.tql` + migration **in the same plan** |
| **Name** | is every name canonical — no invented synonym, no dead name? | check `dictionary.md`; dead names (*knowledge, node, scent, trail, colony*…) **auto-reject** |

A locked-rule violation kicks back **past P0** — you cannot promise a user something the substrate refuses to express. Fix the promise, not the schema. Effort: **xhigh** for a type/`.tql` decision, **max** when it's dimension/verb-adjacent (locked-rule territory).

**Types are the contract that flows downhill.** A schema change is never local — it propagates:

```
schema/one.tql → @oneie/sdk types → /api/* route → MCP tool → CLI verb → dictionary.md
```

P5 PROVE verifies every consumer moved in lockstep (`/sync` reconciles TypeDB↔KV↔D1↔SUI; TypeDB is the truth layer, *not* the hot path). A type changed in `.tql` but not in the SDK is a broken contract, not a shipped feature — which is why `.tql`/migration is a **fifth surface** in the matrix below.

---

## Cross-cutting: the effort × model dial

Effort is orthogonal to model — it's *how much reasoning before output*, not *which brain*. Pick the cheapest tool that decides (the tool ladder), then pick effort by **kind of cognition**, not by phase importance.

| Effort | Cognition | Where |
|--------|-----------|-------|
| *(none)* | bit-equal, name match, exit code | every bash gate — the ideal cycle spawns zero LLM |
| **low** | pattern-match, extract, mechanical anchored edit | W1 recon · W3 edit · W4 verify · P5 proof · P7 ship |
| **medium** | craft prose, restructure one file, compose known primitives | P0 copy · P3 skill · P6 tutorial · W2 (simple) |
| **high** | architecture in a known domain, todo DAG, contract design | P1 spec · P2 plan · W2 (complex) · P8 improve |
| **xhigh** | schema reconciliation, new-primitive justification, cross-surface design | P1 when `.tql`/new-primitive · W2 schema fork |
| **max** | semantic fork — *is the whole model wrong?*, locked-rule-adjacent | P8 when editing gates/invariants · plan-outcome drift ×3 |

**The rule:** escalate effort only when the cheaper tier *can't decide*, never by default. A `max` call you can't justify in one sentence is a `high` call wearing a costume.

---

## Cross-cutting: maximise parallelism (two layers)

**Inner (within one feature):** owned by `/do` — `parallel_budget`, single-message W1/W3 fan-out, cross-cycle W3 merge. Don't touch it; it's tuned.

**Outer (the new win):** phases of *different features* overlap, and within one feature some phases overlap:

```
Feature A:  P0 ─ P1 ─┬─ P2 ─ P3 ─ P4 ─ P5 ─┬─ P7
                     └──────── P6 ──────────┘   (TEACH starts when SPEC freezes — docs-first)
Feature B:  P0 ─ P1 ─ P2 ─ P3 ─ P4 ...        (runs concurrently — no shared file = no arrow)
```

- **P0+P1+P3 can draft concurrently** for one feature: the promise, the architecture, and a missing skill share no files. One message, three agents (Sonnet copy · Opus spec · Sonnet skill).
- **P6 TEACH begins the moment P1's contract freezes** — tutorials are written against the frozen interface, not the finished code (docs-first rule). It lands in parallel with P4 BUILD.
- **`--batch`:** independent features are an outer DAG. Same arrow test as cycles — *an arrow exists only when feature B reads a file feature A writes*. "Same area" is not an arrow.

**Worktrees isolate the trunk from in-flight builds.** FEATURE and SCHEMA tiers build inside a git worktree (`Agent isolation: "worktree"`); the worktree merges to the trunk the moment its **P5 promise-check** passes — so every commit on the trunk is, by construction, a kept promise. A feature that fails PROVE is abandoned with its worktree and the trunk stays clean. Under `--batch`, that's one worktree per feature, each merging independently on its own P5. The same mechanism runs P4 split-test variants: N worktrees, the winner merges, the losers `warn(0.5)` and are discarded. PATCH/FIX skip this — they're too small to isolate and edit the trunk directly.

The executable lifecycle (one repo folder = one git root — there is no monorepo-spanning git, so the worktree is created in the **target folder** `do-folder.sh` resolves):

| Step | Trigger | Action |
|------|---------|--------|
| **create** | tier ∈ {FEATURE, SCHEMA} | `Agent isolation:"worktree"` in the resolved repo folder; build happens there, trunk untouched |
| **merge** | P5 promise-check passes (`do-prove.sh` ok ∧ outcome exit 0) | merge the worktree to that folder's trunk — the cutover; `mark` promise-kept |
| **abandon** | P5 fails or outcome ≠ 0 | drop the worktree, `warn`; trunk stays clean; back to P4 or re-FRAME |
| **batch** | `--batch f1,f2,…` | one worktree per feature, each merging on its own P5 (no shared file = parallel) |
| **split-test** | P4 N-variants | N worktrees; winner merges, losers `warn(0.5)` and discard |

A self-modifying plan (one that edits `.claude/` itself) is the special case: build in a worktree of the **engine repo**, and the merge is the engine cutover — never hot-swap agent files mid-run.

---

## Cross-cutting: token & state discipline (from `agentic-patterns.md`)

The loop's memory lives in **files, not the transcript** — so a compaction mid-build never corrupts a plan, and resume is free. Five rules `/do` and `/do-loop` share:

| Rule | Artifact | Why (GAP) |
|------|----------|-----------|
| **Cap recon receipts** | W1/Survey ≤ 400 words, enforced before the next phase spawns | GAP 1 — verbatim recon blows W2/W4 context |
| **Plan in a file** | `.w2-spec.json` — W3/W4 read the path, never a transcript excerpt | GAP 2 — partial compaction → anchor mismatch |
| **Machine-readable trust** | `.do-trust.json` `{level, consecutive, composite}` read first; prose `learnings.md` is history only | GAP 3 — trust derived from prose fails silently |
| **Token receipt + cost signal** | W4 records `tokens` per wave; cycle close emits `signal("cost:cycle", {tokens, model, composite})` | GAP 4 — spend is never measured or routed |
| **Checkpoint + soft resume** | `.w3-receipts.json` appended per edit; resume skips W0–W2 if W3 was mid-flight | GAP 7 — interrupted W3 restarts from scratch |

**Context budget by tier** (recon agents): Haiku gets last 10 turns + top 5 highways; Opus gets last 40 + top 20 + confirmed hypotheses only. Never hand a Haiku the full history.

The cost signal closes the loop on tokens: `cost:cycle` pheromone lets the autonomous SELECT route toward cheap-and-effective cycles over time — token thrift becomes a routing gradient, not a manual rule.

---

## Cross-cutting: surface-aware branching (substrate · frontend · backend · api)

P5 auto-detects surface from P4's diff (`--surface` overrides). The surface changes **P1 contract**, **P5 proof**, and **P6 runbook** — nothing else. **Substrate** (`.tql`/migration) is the upstream surface: if a feature touches it, it touches it *first* (P1.0), and the type change cascades into whichever of the other three it surfaces through.

| | **Substrate** (`.tql`, D1 migration) | **Frontend** (`.tsx`/`.astro`) | **Backend/Worker** (`api/`, workers) | **API** (`pages/api/`, SDK, MCP, CLI) |
|---|---|---|---|---|
| **P1 contract** | the P1.0 reconciliation **is** the contract — entity/attribute named per `dictionary.md`, fits a locked dim + verb | component tree + **slot map** (which `ai-elements`/`ui` primitives compose) | data flow across 3 layers (TypeDB→KV→`globalThis`) | freeze request/response **against the 14 operations**; new op needs the compress justification |
| **P4 build** | edit `schema/one.tql` + migration; propagate types downhill (SDK→API→MCP→CLI) | compose primitives, never reimplement (`PromptInput*`, `Conversation`, `Drawer`…) | handler + signal close (no silent return) | route **+ SDK method + MCP tool + CLI verb** — one op, four surfaces, or justify the gap |
| **P5 proof** | `/sync` reconciles TypeDB↔KV↔D1↔SUI + a TypeQL query returns the new shape + types compile across every consumer | **`/browser`** (HTTP + JS/console errors + rail before/after + screenshot) + Lighthouse 100 + `@testing-library` render + a11y roles | `curl` against **deployed** runtime (local verify is necessary, not sufficient) | contract test (Vitest + msw) + `curl` example for each surface |
| **P6 runbook** | the schema diff **is** the agent doc — update `dictionary.md` + `one-ontology.md` | "what the user sees + does" + component props/slots for agents | signal sequence (the runbook IS a signal trace) | API reference: `curl` for humans, MCP call for agents |

**The four-surface rule (API):** a capability that ships as a route but *not* as SDK + MCP + CLI is half-shipped. P5 fails the promise-check unless all four are reachable or the gap is justified in P1.
**The type-lockstep rule (Substrate):** a `.tql` change that hasn't propagated to every downhill consumer (SDK types → API → MCP → CLI → `dictionary.md`) is a broken contract — P5 fails until they compile together.

---

## The closed loop (the invariant that makes this a loop, not a list)

```
P0 promise  ──────────────────────────────────►  P5 promise-check
  │  "user can X"                                   re-read P0 copy:
  │                                                 does the shipped thing let them X?
  ▼                                                   │
P2 goal contract  ──►  P4 outcome cmd (exit 0)  ──────┘
                                                      │
                          P7 adoption signal  ◄───────┘
                          every feature emits one signal so
                          adoption is measurable — a feature
                          with no signal is invisible to the substrate
```

Three gates, each a hard stop:
1. **P4 outcome** — `$(plan.outcome)` exits 0 (bash, owned by `/do`).
2. **P5 promise-check** — the P0 marketing copy is *true* of the shipped artifact. If the copy over-promised, either the build is incomplete (→ P4) or the copy lied (→ P0 rewrite). Never ship a promise you didn't keep.
3. **P7 signal** — the feature emits an adoption signal (`ui:*`, `cli:*`, or domain event). No signal → not shipped.

---

## The idea lifecycle & outputs (seed → highway)

One idea = one **path**. The loop is that path strengthening from a weak seed to a shipped highway. Each state emits **two** outputs — a *file* (for humans/git) and a *signal* (for the substrate). The file is what you read; the signal is how the system ranks the *next* idea.

| State | Set at | File output | Signal | Advances when |
|-------|--------|-------------|--------|---------------|
| **seed** | capture | `plans/ideas.md` row / task | `signal` idea:seed (weak, KV) | someone files it |
| **goal** | INTAKE | goal contract (rough) | `mark` idea:agreed → **promote to TypeDB** | human agrees sentence + tier |
| **promised** | P0 | `text/<f>.md` blurb | — | passes voice contract |
| **scoped** | P0.5 | survey receipt | `mark` exists / `warn` gap | verdict ∈ build · extend · expose |
| **designed** | P1 | `plans/<f>.md` | — | contract frozen + substrate-reconciled |
| **planned** | P2 | `plans/<f>-todo.md` | — | DAG + outcome command written |
| **built** | P4 | code + tests (worktree) | `mark` per cycle close | `/do` gates pass |
| **proven** | P5 | proof artifact | `mark` promise-kept → worktree merges | promise-check true ∧ outcome exit 0 |
| **taught** | P6 | tutorial + runbook | — | both audiences covered |
| **shipped** | P7 | release / changelog | `signal` adoption event **live** → highway | reachable ∧ signal emitted |
| **known** | P8 | `learnings.md` entry | `harden` → hypothesis | drift checked, loop improved |

**Failure is part of the lifecycle, not an exception.** SURVEY `drop` (or post-outcome `justify-or-drop`) → `fade` the path, archive. P5 promise-check false → `warn`, abandon the worktree, back to P4 or re-FRAME.

**Seed persistence — promote-on-mark, fade-to-GC.** Don't choose between "keep every idea" and "keep none"; keep everything *weakly* and let the substrate's own decay clean up. A seed lands in the **hot/KV layer** (cheap, TTL'd, weak). The first `mark` — the INTAKE agreement, or an explicit `/create task` — **promotes** it to a TypeDB `thing` with a real path: durable, self-ranking backlog. A seed that never earns a mark `fade`s below threshold and is gone. No pruning job — `fade` *is* the cleanup, and TypeDB (the truth layer, never the hot path) only ever holds agreed goals. The autonomous SELECT reads the promoted backlog only — it never auto-builds a half-typed throwaway.

**The macro-loop is self-feeding.** P7's adoption signal is real usage → which surfaces as gaps and drift (P0.5 SURVEY + P8 LEARN) → which seed new ideas. **The output of one loop is the input signal to the next**; the backlog rises on shipped-feature telemetry, not just human whim. seed→…→known rhymes with the substrate's own Birth→…→Know arc — the loop doesn't invent a lifecycle, it rides the one the schema already runs.

---

## What each phase is *not* allowed to skip

- **INTAKE** — never spend a phase before the goal sentence is agreed (the one human gate). A loop that starts on a fuzzy idea builds the wrong thing fast and expensively.
- **P0** — never start a feature without articulating the promise. "Internal-only, no user-facing copy" is a valid promise (write it as such), but silence is not.
- **P1** — never design before the **P1.0 substrate reconciliation** (dimension · verb · type · name). Then never freeze a new primitive (endpoint, SDK method, MCP tool, CLI verb, schema field, event, section kind) without the compress check: `PRIMITIVE / COMPOSE / VERDICT`. Default verdict is compose; a new dim or verb is an automatic reject (locked).
- **P2** — never hand-write a todo. `cp template-todo.md` (the frontmatter contract is load-bearing) or `/create todo`.
- **P3** — skill-check is `infer tags → ls .claude/skills/{name}/ → ready|stale|missing`. Create **only** on missing+required. A skill that wraps knowledge already in a rule is bloat — extend the rule.
- **P4** — never bypass `/do`'s gates. If a cycle won't close, fix the cause; don't lower the gate.
- **P5** — bash/visual proof, not vibes. "Looks done" is not a proof artifact. Frontend promise-check is a `/browser` run (real Chrome: HTTP, JS errors, rail before/after) — a passing `@testing-library` test alone does not prove the user can use it.
- **P6** — two audiences, always: a human how-to *and* an agent runbook. One without the other is half-taught.
- **P7** — `/close` propagate matrix runs the doc sync; `/release` cuts the note. Don't hand-edit the changelog.
- **P8** — `--improve` may only edit agent-instruction text. **Never** gate thresholds, escape conditions, or the invariant list (that's `do-improve.md`'s hard rule).

---

## Don't

- Don't reimplement `/do`'s W0→W4 — P4 *is* `/do --auto`. This file never describes a wave.
- Don't add a phase without a durable artifact — a phase that produces nothing on disk isn't a phase.
- Don't run phases strictly serially when the outer DAG says they're independent — that's the most common waste here.
- Don't write a `-todo.md` from scratch, plan in calendar time, or rename a locked dimension/verb/outcome.
- Don't let P0 copy use mechanism words (pheromone/substrate/mark/warn) — persona outcomes only (`product-marketing.md`).
- Don't run the full pipeline on a PATCH/FIX — match the tier to the change; an over-built loop is the most expensive token mistake here.
- Don't open P1 before P0.5 SURVEY clears it — re-building a feature that already exists is the failure this loop most exists to prevent.
- Don't pass recon verbatim into the next phase or keep the plan in the transcript — cap at 400 words, write `.w2-spec.json` (token & state discipline).
- Don't merge a worktree before its P5 promise-check passes — the trunk's one invariant is that every commit kept its promise.
- Don't interrogate at INTAKE — propose the goal + tier as one correctable read; the goal is the human gate, not a questionnaire.
- Don't promote a seed to TypeDB before its first `mark` — unmarked ideas live in KV and fade; the truth layer holds only agreed goals.

## See also

- `.claude/commands/do.md` — the inner engine (W0→W4) this loop wraps at P4
- `.claude/commands/do-improve.md` — P8's machinery (and its hard scope limit)
- `.claude/commands/do-intent.md` — INTAKE's locate half (natural-language → existing context)
- `.claude/commands/create.md` — `/create task` captures a seed; `plans/lifecycle.md` — the substrate Birth→Know arc the idea lifecycle rides
- `plans/template-todo.md` — P2's base; the parallelism + goal contract
- `plans/agent-api.md` — the 14 operations; P1's API contract reference
- `.claude/product-marketing.md` + `.claude/skills/writer/` — P0's voice + craft
- `.claude/skills/tutorial.md` — P6's pattern (lifecycle walkthrough)
- `schema/one.tql` + `/typedb` skill — P1.0's substrate (the truth layer)
- `plans/one-ontology.md` · `plans/dsl.md` · `plans/dictionary.md` — the 6 dims, 6 verbs, canonical names P1.0 reconciles against
- `.claude/commands/sync.md` — P5's type-lockstep reconcile (TypeDB↔KV↔D1↔SUI)
- `.claude/commands/browser.md` — P5's frontend `/browser` proof (real-Chrome check)
- `plans/agentic-patterns.md` — the token/state GAPs (1,2,3,4,7) folded into the discipline section

---

*`/do` ships correct code. `/do-loop` ships a kept promise. The promise is the goal contract in the user's language — write it first, verify it last.*
