---
title: Make /do the universal front door — backfill the artifact spine, then build
slug: do-loop
type: plan
tier: complex
mode: construction
tags: [do, lifecycle, artifact-backfill, agentic-patterns, tokens, state, substrate, orchestration]

# ─── GOAL CONTRACT ──────────────────────────────────────────────────
goal: "Typing `/do <anything>` runs the whole build lifecycle from wherever the idea is: /do restates it as a goal, then walks the full artifact spine — promise (`text/`), spec (`plans/<f>.md`), todo (`plans/<f>-todo.md`), code, tests, docs, proof, release — and backfills whatever is MISSING anywhere on it, skipping whatever already exists. Point it at a bare idea and it writes everything; point it at code with no tests or docs and it backfills just those. Two quality gates ride the spine (borrowed from Spec Kit): CLARIFY de-risks the spec for FEATURE/SCHEMA tiers, and ANALYZE verifies every deliverable maps to a cycle before any build spend. Autonomous, durable (survives compaction), tier-matched, every trunk commit a kept promise. One command. No /do-loop."
outcome: "bash .claude/scripts/do-smoke.sh"
outcome_asserts: "On fixtures, the deterministic substrate works end-to-end: tier-infer maps each trigger to the right phase set; reconcile rejects a dead name (exit 1) and passes a canonical one (exit 0); survey returns a non-build verdict on a duplicate; analyze blocks a coverage-broken plan (CRITICAL, exit 1) and passes a clean one (100% coverage, exit 0); a seed goes KV→promote-on-mark→TypeDB→fade-GC; cost:cycle emits valid receiver grammar; .w2-spec/.do-trust/.w3-receipts/.w2-doc-plan schemas validate. The LLM phase-sequencing (incl. CLARIFY's questions) is proven by one logged canary `/do <idea>` run (the loop can't be driven from bash) — verified by exit code on the deterministic half."

deliverables:   # stable IDs (D#) are the coverage keys ANALYZE (C14) checks against the cycle list
  # --- foundation: folder-aware engine (every W0/W4 depends on it — built FIRST) ---
  - D0  script:     .claude/scripts/do-folder.sh — resolve target repo folder from touched files → that folder's verify/build; doc-only → skip bun; fixes the no-root-package.json reality (C0)
  # --- state foundation (hardens the /do engine, used by every phase) ---
  - D1  state-file: .w2-spec.json — W2 plan + lean per-spec context pack (current_state·must_not_break·serves) W3 reads by path (C1; ex-BMAD story-file, stripped)
  - D2  state-file: .w2-doc-plan.json — W2 actually WRITES the doc-plan the W4 gate already reads (C1, dead-gate fix)
  - D3  state-file: .do-trust.json — machine-readable trust read at cycle start (C2)
  - D4  signal:     cost:cycle — token spend per cycle → substrate pheromone (C3)
  - D5  state-file: .w3-receipts.json — per-edit checkpoint → soft resume (C4)
  # --- front door + backlog (the merge) ---
  - D6  backlog:    plans/ideas.md + seed KV→TypeDB promote-on-mark (C5)
  - D7  engine:     INTAKE + full artifact-spine backfill (promise·spec·todo·code·tests·docs·proof·release) folded into do.md intent mode (C6)
  # --- control plane ---
  - D8  control:    tier auto-infer + tier→phase gating, reconciled with do.md's TRIVIAL/SIMPLE/COMPLEX classifier (C7)
  - D9  control:    worktree lifecycle — merge-on-PROVE, abandon-on-fail, --batch, split-test (C8)
  # --- phase gates (deterministic bash helpers) ---
  - D10 script:     SURVEY — feature recon + simplicity verdict + gap scan (C9)
  - D11 script:     substrate reconciliation — dim/verb/type/dead-name gate (C10)
  - D12 script:     PROVE — surface auto-detect + promise-check + /browser + type-lockstep (C11)
  - D13 script:     ANALYZE — read-only spec↔todo coverage + drift + locked-rule gate, BEFORE build (C14, ex-Spec-Kit /analyze)
  - D14 sub-step:   CLARIFY — tier-gated ambiguity scan at SPEC, ≤5 Qs, decisions written into plans/<f>.md (C12 authors, C6 invokes; ex-Spec-Kit /clarify)
  # --- the merge + outcome ---
  - D15 command:    merge do-loop.md → do-lifecycle.md (spec /do reads); make the ladder executable; delete the /do-loop command (C12)
  - D16 script:     .claude/scripts/do-smoke.sh — the deterministic outcome gate (C13)

ux_before: "Two commands exist by accident: /do (W0→W4 engine) and /do-loop (the lifecycle, never wired). Neither lets you just say what you want. The operator holds plan/trust/progress in the transcript (lost on compaction), can't see token spend, and ideas typed at the prompt vanish. The lifecycle phases are beautifully described in do-loop.md but not executable, and the only entry assumes a todo already exists."
ux_after:  "Operator types `/do <anything>`. /do agrees the goal at one gate, then walks the artifact ladder — writes the promise/spec/todo only if missing, skips forward past whatever already exists — and runs build→prove→ship autonomously in worktrees, writing durable artifacts and reporting cost. One command, one mental model."
ux_delta:  "A described lifecycle becomes an executable one, behind a single command — idea in, shipped-and-proven feature out, with the human owning only the goal sentence and /do owning everything below it."
# ────────────────────────────────────────────────────────────────────

parallel_budget:
  haiku:   16
  sonnet:  10
  opus:    2

batches:
  - [C0, C1, C2, C3, C4]    # C0 FIRST (folder-aware verify — every W0/W4 needs it); then state foundation. do.md edits sequence as W3b, C0 before C1-C4
  - [C5, C7, C9, C10]       # seed · tier · survey · reconcile — fully disjoint (product code + scripts)
  - [C6, C8, C11, C14]      # INTAKE→do.md (←C5,C7) · worktree→do-lifecycle.md (←C7) · PROVE + ANALYZE scripts (indep)
  - [C12]                   # the merge — composes every piece, rewires do.md↔do-lifecycle.md, authors CLARIFY, kills /do-loop
  - [C13]                   # deterministic smoke = the plan outcome

shared_recon:
  - .claude/commands/do.md
  - .claude/commands/do-loop.md
  - .claude/commands/do-intent.md
  - .claude/agents/w2-decide.md
  - .claude/agents/w3-edit.md
  - .claude/agents/w4-verify.md
  - plans/agentic-patterns.md
  - .claude/commands/create.md

source_of_truth:
  - .claude/commands/do.md            # the single command — lifecycle merges in here
  - .claude/commands/do-loop.md       # the design to preserve → becomes do-lifecycle.md
  - plans/agentic-patterns.md
  - plans/template-todo.md

existing_primitives:
  - .claude/commands/do.md: the W0→W4 engine + mode dispatch ("Read do-intent.md/do-autonomous.md first") — the lifecycle becomes a new dispatch on this, never a fork
  - .claude/commands/do-loop.md: the lifecycle DESIGN (INTAKE, seed→highway, surface matrix, P0–P8) — preserved verbatim, renamed do-lifecycle.md, made the spec /do reads
  - .claude/commands/{create,do-intent,close,release,sync,browser,do-improve}.md: the phase commands /do composes — never reimplemented
  - .claude/skills/{writer,tutorial,typedb}/ + .claude/product-marketing.md: P0 FRAME / P6 TEACH / substrate — invoked as skills
  - packages/sdk/src/client.ts: signal()/mark()/warn()/fade() — every lifecycle transition; cost:cycle reuses signal() verbatim
  - plans/template-todo.md: PLAN base — /create todo fills it; never hand-written
  - Agent tool isolation:"worktree": C8 worktree lifecycle rides this, no new git machinery
  - root repo folders (one.ie/, packages/, agents/, api/, schema/, sync/): each is its OWN buildable repo — **there is no root package.json by design**; /do MUST resolve the target folder from the touched files and run W0/W4 verify+build IN that folder (C0), never a root `bun run verify`. Doc-only cycles (.md/.claude edits) skip bun-verify entirely. Tests run with that folder's runner (e.g. one.ie/web → `typecheck && test`).

show: false
escape:
  condition: "C12 merge leaves /do with two live entries (a canary `/do <idea>` and the old /do-loop path both resolve) OR a phase handoff artifact goes missing twice"
  action: "halt; confirm /do-loop is fully removed and the artifact ladder is the only lifecycle entry — likely a state-file contract mismatch from batch 1 or a stale do-loop ref"
---

# Make /do the universal front door

## Goal, outcome, deliverables, UX

### Goal
Typing **`/do <anything>`** runs the whole build lifecycle from wherever the idea is. `/do` restates it as a goal, then walks the **artifact spine** — backfilling whatever is missing *anywhere* on it, skipping whatever exists. One command; the human owns only the goal sentence.

```
/do <anything>
  promise   text/<f>.md exists?          no → write   (FRAME)    yes → skip
  spec      plans/<f>.md exists?          no → write   (SPEC)     yes → skip
   └─ CLARIFY gate (FEATURE/SCHEMA only): scan spec for ambiguity, ≤5 Qs, write answers back into spec
  todo      plans/<f>-todo.md exists?     no → write   (PLAN)     yes → skip
   └─ ANALYZE gate (read-only): every deliverable maps to a cycle? no drift? no locked-rule break? CRITICAL → fix before build
  code      capability exists (survey)?   no → build   (BUILD)    yes → skip
  tests     tests cover it?               no → write   (BUILD)    yes → skip
  docs      feature doc + runbook exist?  no → write   (TEACH)    yes → skip
  proof     proof artifact captured?      no → run     (PROVE)    yes → skip
  release   changelog/README updated?     no → cut     (SHIP)     yes → skip
```

The two `└─` gates are **checkpoints, not artifacts** — CLARIFY edits the spec in place; ANALYZE is read-only and only blocks on CRITICAL findings. Both are borrowed from GitHub's Spec Kit (`apps/spec-kit`), which our spine otherwise already covers. CLARIFY runs at SPEC (not the front door — INTAKE stays a one-shot proposal, never an interrogation); ANALYZE runs at the todo→code boundary where misalignment is cheapest to catch and most expensive to skip.

**Every artifact on the spine is a backfill target — not just the upstream planning trio.** Point `/do` at a bare idea → it writes all of them, top to bottom. Point it at shipped code that's missing tests and docs → it backfills *just those two* and stops. The spine **is** the loop: every phase closes with one durable artifact on disk; a phase whose artifact already exists is skipped (resume is free, no `--from` flag). This is the closed-loop rule applied to the build itself, and it's how `/do` "checks if the text, the plan, the todo, the tests, the docs are written — and if not, writes them."

| Artifact / gate | Presence check | Phase · backfills |
|---|---|---|
| **promise** | `test -f text/<f>.md` | FRAME — `writer` skill + `product-marketing.md` |
| **spec** | `test -f plans/<f>.md` | SPEC — Opus + substrate reconcile (C10) |
| ↳ *CLARIFY* (gate) | spec ambiguity scan, tier ∈ {FEATURE,SCHEMA} | C12/C6 — ≤5 Qs → decisions written into the spec |
| **todo** | `test -f plans/<f>-todo.md` | PLAN — `/create todo` + `template-todo.md` |
| ↳ *ANALYZE* (gate) | every D# → ≥1 cycle, no drift, no locked-rule break | C14 — read-only; CRITICAL blocks BUILD |
| **code** | SURVEY (C9) grep ≥70% match | BUILD — `/do` W0→W4 |
| **tests** | test file / coverage in the repo folder | BUILD — written in W2 plan + W3 (per-repo runner) |
| **docs** | feature doc + `dictionary.md`/runbook entry | TEACH — `tutorial` skill + `/close` propagate matrix |
| **proof** | proof artifact for the surface | PROVE (C11) — `/browser` · curl · contract test · `/sync` |
| **release** | changelog / README / feature-doc row | SHIP — `/release` + adoption signal |

### Outcome (the kill-switch)
```bash
bash .claude/scripts/do-smoke.sh
```
**What passing proves (deterministic half):** tier-infer maps each trigger to the right phase set · reconcile rejects a dead name / passes a canonical one · survey returns non-build on a duplicate · a seed goes KV→promote-on-mark→TypeDB→fade · `cost:cycle` emits valid grammar · the four state-file schemas validate.

**What bash cannot prove:** the LLM phase-sequencing itself. `/do` is Claude following markdown — a bash script can't drive it. So the smoke gate covers the *plumbing*; the *loop* is proven by **one logged canary `/do <idea>` run** appended to `docs/learnings.md`. Honesty here is the point — a green bash exit that claimed to have run the whole LLM loop would be theater.

**Contract:** runs after every batch's W4. The plan does not close until `do-smoke.sh` exits 0 **and** the canary run is logged.

### Deliverables → the designed system
| The design (in `do-lifecycle.md`, preserved from `do-loop.md`) | Cycle | Kind |
|---|---|---|
| INTAKE front door + full-spine backfill (text·spec·todo·code·tests·docs·proof·release) | C6 | engine (do.md intent mode) |
| Seed lifecycle (KV→TypeDB promote-on-mark, `fade` GC) | C5 | backlog |
| FRAME · TEACH · SHIP (marketing, tutorials, release) | C12 | merge wires writer/tutorial/release |
| SURVEY (feature recon + simplicity + gaps) | C9 | script |
| Substrate reconciliation (dim/verb/type/name) | C10 | script |
| BUILD = `/do` W0→W4 + tests; state durability | C1–C4 | state-files + signal |
| PROVE (surface-detect, promise-check, `/browser`) | C11 | script |
| CLARIFY (tier-gated spec ambiguity scan, ≤5 Qs → spec) | C12, C6 | sub-step (ex-Spec-Kit) |
| ANALYZE (spec↔todo coverage + AC→test + drift + locked-rule, read-only) | C14 | script (ex-Spec-Kit) |
| Definition of Done (one named gate, AC→test, tier-scaled) | C14 + W4 + close | gate (ex-BMAD) |
| Token economy (size-probe → spine-prune + per-tier budget) | C7 | control |
| Loop tiers + model×effort routing + parallelism | C7, C12 | control + merge |
| Worktree lifecycle (merge-on-PROVE, `--batch`, split-test) | C8 | control |
| Token & state discipline (GAP 1,2,3,4,7) | C1–C4 | state-files |
| LEARN (self-improve) | C12 | merge wires `/do --improve` |

If a designed capability isn't in this table, it isn't in scope — and if it's in `do-loop.md` and missing here, that's a gap to add, not skip.

### UX: before → after
| | Today | After |
|---|---|---|
| **Who** | operator / Claude | same |
| **Friction** | two accidental commands; neither takes a bare idea; lifecycle described but not executable; state in transcript; spend invisible; ideas vanish | `/do <anything>` agrees the goal, backfills missing artifacts, runs every phase autonomously in worktrees; durable artifacts; cost reported; only kept promises hit trunk |
| **Delta** | a *described* lifecycle becomes an *executable* one behind *one* command — idea in, shipped-and-proven feature out |

**The proof a future-you points at:**
```
$ /do "operators can see token spend per cycle"
INTAKE  goal agreed ✓  tier=FEATURE
SPINE   promise? no→wrote · spec? no→wrote · todo? no→wrote · code? no→build
        tests? no→wrote · docs? no→wrote · proof? no→ran · release? no→cut
BUILD   worktree wt-cost/  W0→W4 run
PROVE   promise-check ✓  outcome exit 0  → merged to trunk
SHIP    cost:cycle live · adoption signal live

$ /do "the cost feature has no tests or runbook"
INTAKE  goal agreed ✓  tier=FIX
SPINE   promise ✓skip · spec ✓skip · todo ✓skip · code ✓skip
        tests? no→wrote · docs? no→wrote · proof? no→ran      (backfilled only the 2 gaps)
$ bash .claude/scripts/do-smoke.sh   → exit 0
```

---

## Reuse contract
This plan **edits the `/do` engine + agents, writes thin bash helpers, and merges the `do-loop.md` lifecycle design into `/do` as the spec it reads.** It builds almost no new product code — it's orchestration + durable state. The single product-code cycle is **C5** (seed persistence). Everything else is markdown (do.md, do-lifecycle.md, agent prompts) + bash scripts.

**Net new code budget** (counting bash + TS, not markdown): the 6 helper scripts (C7,C9,C10,C11,C14) + smoke (C13) ≈ **< 620 LOC bash**; C5 product code **< 150 LOC TS**. CLARIFY adds no script (it's prose in `do-lifecycle.md`). Markdown edits are not LOC-budgeted but follow the W4 doc rubric (simplicity = fewer words). The earlier "<400 net LOC" claim was wrong — the per-cycle caps below are the real budget.

The phases (FRAME/PLAN/TEACH/SHIP/LEARN) are **invocations of `writer`/`/create todo`/`tutorial`/`/release`/`/do --improve`** — never reimplemented.

**The merge architecture.** `do-loop.md`'s body is excellent and stays intact — it just moves to `do-lifecycle.md` and becomes the spec `/do` reads (exactly how `do.md` already dispatches to `do-intent.md`, `do-autonomous.md`). `do.md` itself gains only a small lifecycle dispatch in intent mode + the state-file wiring + the tier reconciliation note. This keeps `do.md` lean and avoids serializing every cycle on one fat file.

**Borrowed methods — take the idea, refuse the token bill.** Two external repos informed this plan; both are awesome and both teach by contrast as much as by example.

| Source | Take (folded in, token-lean) | Refuse (the bloat) |
|---|---|---|
| **Spec Kit** (`apps/spec-kit`) | CLARIFY gate (C12/C6), ANALYZE coverage gate (C14) | a separate `/memory/constitution.md` (we have substrate truth); the `extensions.yml` hook protocol (Claude Code hooks cover it) |
| **BMAD** (`apps/BMAD-METHOD`) | self-contained per-unit context pack → lean `.w2-spec.json` (C1); "read current state + don't break adjacent behavior" guardrail (C1→`w3-edit.md`); learnings carryover (already: `learnings.md` + W4 pre-warm) | per-story **global re-analysis** of PRD+arch+UX+git+web every story; persona prompts; web-research-per-story; 12-section story templates; document-sharding ceremony — **this is why BMAD burns tokens** |

The principle: BMAD proves the value of a self-contained context pack *and* proves that re-deriving it from scratch per unit is the token sink. Our architecture already solves the same problem for ~an order of magnitude fewer tokens — capped 400-word recon, the Haiku-first tool ladder, tier-gating (a PATCH spawns 0 agents), and state files written **once** per cycle. We take BMAD's *insight* (the executing agent needs current-state + guardrails up front) and pay for it out of context W2 already holds, not a fresh global scan. Any future `/do` change that reintroduces per-unit global re-analysis is a regression against this rule.

---

## Token economy — automatic, not optional

**The human never picks how much to spend.** One cheap probe at intake (`intent` + a one-line `git diff --stat`) infers a single size signal; that signal prunes the **outer spine** (which stops/gates run) *and* sets the **inner cycle** (how many agents spawn, which model), in lockstep. **Default is always down** — an under-built FIX re-opens cheaply at PROVE; an over-built PATCH is tokens you can't refund. Every step is **opt-out for small work, not opt-in.**

**Defensive note (why this section exists now):** the 8-stop spine + CLARIFY + ANALYZE are *FEATURE/SCHEMA richness*. They must never tax a typo. The **spine is tier-pruned before the walk** — a PATCH presence-checks `code`+`verify`, not all 8 stops and 2 gates. A gate never runs above the phases it guards.

The automatic savings ladder (each fires without a flag):

| Mechanism | Fires at | Saves by |
|---|---|---|
| **Size probe** (C7) | intake | inferring the smallest tier that fits; default-down when unsure |
| **Spine prune** (C7→C6) | before the spine walk | a PATCH walks `code`+`verify` only — never 8 stops + 2 gates |
| **Gate-skip** | per phase | no gate runs above the phases it guards (SURVEY/SPEC/CLARIFY/ANALYZE all skip for PATCH; FIX adds only SURVEY→PROVE) |
| **Complexity classifier** (do.md) | W0 | TRIVIAL = 0 agent spawns · SIMPLE = 2–3 · COMPLEX = full W1→W4 |
| **Tool ladder** (do.md) | every decision point | bash → Haiku → Sonnet → Opus; stop at the first that decides |
| **Recon cap + cache** | W1 | 400-word cap; KV `recon:{sha}:{sha}` hit (<14d) skips the re-read |
| **Context budget by tier** | recon spawn | Haiku gets last 10 turns + top 5 paths; Opus last 40 — never the full history |
| **Write-once state** (C1/C4) | per cycle | `.w2-spec`/`.w3-receipts` read by path, never re-derived after compaction |
| **Per-tier token budget** (C7, new) | cycle close | an *expected* ceiling per tier; overspend → `warn` + justify-or-drop, catching a runaway in-flight instead of after |
| **cost:cycle → SELECT** (C3) | autonomous | the pheromone routes future work toward cheap-and-effective paths — thrift becomes a gradient, not a rule |

**Worked example — same command, two costs, zero human choice:**
```
/do "fix the typo in the pricing CTA"
  probe → PATCH (1 file, copy-only)   spine pruned to: code✓skip → edit → verify
  inner → TRIVIAL → 0 agent spawns    ~1 LLM call (the edit), bash verify, 1 learnings line
  no FRAME · no SURVEY · no SPEC · no CLARIFY · no PLAN · no ANALYZE · no worktree · no TEACH/SHIP

/do "add usage-based billing"
  probe → FEATURE                     full spine: all 8 stops + CLARIFY + ANALYZE
  inner → COMPLEX → full W1→W4 fan-out, worktree, merge-on-PROVE
```
Same front door. The cost matches the change because the probe — not the operator — sized it.

The **forward budget** is the one genuinely new lever: `cost:cycle` (C3) measures spend *after* a cycle; pairing each tier with an *expected* ceiling lets `/do` flag a cycle that's blowing past its tier mid-flight (a SIMPLE cycle spending COMPLEX tokens is a mis-tiered task — drop or justify, don't silently burn).

---

## Definition of Done — one named gate, mostly bash

We already *enforce* a DoD (W4 rubric + PROVE promise-check + ANALYZE coverage + doc-sync gate + cycle close) but never *named* it — so it's scattered and a reader can't see the whole bar. BMAD's contribution (`bmad-dev-story/checklist.md`) is the single explicit checklist. We adopt the **shape**, mapped to what we already check (so it adds almost no tokens — each row has a deterministic enforcer), and **tier-scale** it so a PATCH isn't taxed.

A cycle is **DONE** only when every enabled row passes:

| # | Done means | Enforcer | Min tier |
|---|---|---|---|
| 1 | Every `D#` this cycle owns is satisfied (W2 goal-delta holds vs the shipped diff; CLARIFY decisions honored) | W4 goal-fit ≥ 0.50 | all |
| 2 | **Every shippable `D#` has a test asserting it** (goal-based: one `expect()` per deliverable, not per code path) | C14 ANALYZE (planned) + W4 demo gate (green) | all |
| 3 | No regression — all existing tests green, `delta_tsc ≤ 0`, `must_not_break` preserved | `bun run verify` + ratchet | all |
| 4 | PROVE promise-check true vs the P0 copy; deliverable proof captured (curl/screenshot/log line) | C11 PROVE | FIX+ |
| 5 | Docs in sync — stale-name 0, links ok, `CLAUDE.md` mtime ≥ touched code | W4 doc-sync gate | FIX+ (when docs touched) |
| 6 | Coverage 100% — every `D#`→cycle, no orphan cycle, no terminology drift | C14 ANALYZE | FEATURE/SCHEMA |
| 7 | Composite ≥ 0.65, goal-fit ≥ 0.50, no adversarial finding > 0.5 | W4 rubric | SIMPLE+ |
| 8 | Closed loop — cycle ends in `mark`/`warn` (no silent return); SHIP emits the adoption signal; one learnings entry written | `/close` | all |

A **PATCH's DoD is rows {1,2,3,8}** — test green, no regression, closed loop. The full eight are FEATURE/SCHEMA. The point: same named bar, scaled by tier, and every row is a check we *already run* — naming it just makes the gate legible and closes the one real gap (row 2's AC→test link).

**ex-BMAD, refused:** BMAD's separate QA/Test-Architect *persona agents* and per-story `qa-generate-e2e-tests` pass. We don't need them — tests are written **inline in BUILD** from each deliverable's acceptance assertion (cheaper than a hand-off to a QA agent), and the adversarial/edge-case pass is W4's existing `agent-adversarial` haiku, tier-gated to COMPLEX. Take the DoD and the AC→test discipline; skip the agent ceremony.

---

## Parallel execution plan

### Shared-edit map (which file each cycle touches)
```
do.md            ← C1 C2 C3 C4 (state wiring) · C6 (ladder dispatch) · C7 (tier note)   → W3b serialize
do-lifecycle.md  ← C8 C12 (lifecycle body + CLARIFY at SPEC, renamed from do-loop.md)     → W3b serialize
agent prompts    ← C1 (w2/w3/w4) · C3 (w4) · C4 (w3)                                       → per-file disjoint
bash scripts     ← C7 (do-tier) · C9 (do-survey) · C10 (do-reconcile) · C11 (do-prove) · C14 (do-analyze)  → disjoint, parallel
product code     ← C5 (one.ie/web task API + KV + schema/one.tql + plans/ideas.md)         → disjoint
```
**Rule:** within a batch, cycles editing the *same* markdown file run W1/W2 parallel but W3 edits sequence as **W3b**. Everything else is fully parallel.

### Cycle DAG
```
   C0                 (folder-aware verify/build — MUST land first; every later W0/W4 uses it)
   C1 C2 C3 C4        (state foundation — share do.md → W3b, after C0)
   C5 C7 C9 C10       (seed · tier · survey · reconcile — disjoint)
       │  │
   C6 ─┘  ├─ C8       (C6←C5 seed + C7 tier ; C8←C7 tier)   C11 C14 (indep scripts)
       \  │  /
         C12          (the merge — composes all + rewires do.md↔do-lifecycle.md + authors CLARIFY + kills /do-loop)
          │
         C13          (deterministic smoke = outcome)
```
**Valid arrows only:** C6 reads C5's promote API + C7's tier; C8 reads C7's tier; C12 reads every piece; C13 runs the helpers C7–C11+C14 produce. C14 (ANALYZE) is an independent script like C11. Everything else is parallel.

### Batches (model × effort)
| Batch | Cycles | Parallel work · routing |
|---|---|---|
| 0 | shared | W0 baseline (per touched repo folder) + one Haiku·low recon over `shared_recon` |
| 1 | C0·C1·C2·C3·C4 | **C0 first** (Sonnet·medium — folder-aware verify, unblocks all W0/W4); then W2 Opus·high (state contracts); W3a agent edits Sonnet·low parallel; `do.md` W3b in order C0→C1→C2→C3→C4 |
| 2 | C5·C7·C9·C10 | C5 Opus·xhigh (substrate); C7/C9/C10 Sonnet·medium; all W3a parallel |
| 3 | C6·C8·C11·C14 | C6 Opus·high (the ladder + human gate); C8/C11/C14 Sonnet·medium (C14 = ANALYZE coverage gate) |
| 4 | C12 | Opus·high — the merge (+ authors CLARIFY into do-lifecycle.md); the worktree's final commit — **merging it is the cutover** that activates the new engine + removes /do-loop |
| 5 | C13 | bash·none — writes + runs the deterministic smoke gate |

---

## Bootstrap protocol — building `/do` with `/do` (self-modification safety)

This plan rewrites the very engine that runs it (`do.md` + the four W1–W4 agents + the lifecycle spec). Three rules keep that from corrupting the in-flight build:

1. **Build the whole plan in a worktree** (`Agent isolation: "worktree"`). The live `.claude/` stays frozen for the duration; every spawned W1/W3/W4 agent keeps reading the **stable live definitions** (the Agent tool loads agent `.md` fresh at spawn — a worktree is the only thing that prevents mid-batch drift). The new engine activates **atomically at merge**, only after the smoke gate is green. *(This overrides the old "C12 edits the harness, no worktree" note — editing the harness is exactly when isolation matters most.)*
2. **C0 lands before anything else runs against the engine.** Without folder-aware verify, cycle 1's W0 (`bun run verify` from a folder with no `package.json`) errors. C0 is the first `do.md` edit; verify it on its own doc-only demo before continuing.
3. **Don't `--auto` batch 1.** Run the engine cycles (C0–C4) wave-at-a-time; after batch 1, confirm `do.md` + the four agent files are a **consistent set** before relying on the new behavior. The contracts are already **absent-tolerant by design** (`.do-trust.json` absent → `standard`; `.w2-doc-plan.json` absent → doc-gate bypassed; context-pack fields optional) — so a half-upgraded engine *degrades*, it never crashes. Batches 2–5 are mostly disjoint scripts + product code (C5, C7, C9, C10, C11, C14) that never touch the running engine and are safe under any `/do`.

**The merge is the cutover.** Until C12 merges the worktree, `/do` behaves exactly as it does today; after merge, the single front-door `/do` is live and `/do-loop` is gone. No half-state ships.

---

## Status
```
Batch 0   - [ ] W0 baseline   - [ ] W1 shared recon
Batch 1   - [x] C0 folder-aware verify  - [x] C1 .w2-spec+doc-plan (cf681b3)  - [x] C2 .do-trust (6704cfe)  - [x] C3 cost:cycle (754dd1e)  - [x] C4 .w3-receipts (43ba67b)  ✓ engine consistency verified
Batch 2   - [x] C5 seed (one.ie b8b8b4c2 + ideas.md c444b37; 4/4 tests, tsc clean)  - [x] C7 tiers (858b50f)  - [x] C9 survey (858b50f)  - [x] C10 reconcile (858b50f)
Batch 3   - [x] C6 INTAKE+spine (38b2397)   - [x] C8 worktree (026e81d)   - [x] C11 PROVE (9a417d4)   - [x] C14 ANALYZE (858b50f)
Batch 4   - [x] C12 merge + CLARIFY, /do-loop killed (ea2527f)
Batch 5   - [x] C13 smoke (a6b4cd5) — exits 0
Plan close
  - [x] do-smoke.sh exits 0   - [ ] canary `/do <idea>` run logged (the LLM loop — bash can't drive it)   - [x] /do-loop command gone, single entry
  - [x] every D# reachable (ANALYZE coverage = 100% on this very plan)   - [x] do-lifecycle.md no longer describes fiction
  - [ ] final compress sweep + learnings append
```

---

## C0 — Folder-aware verify/build (no root package.json, by design)  [Sonnet·medium · batch 1, FIRST do.md edit]
**Goal delta:** `/do` resolves the target repo folder from the touched files and runs W0/W4 verify+build **in that folder** — never a root `bun run verify` (each root folder is its own buildable repo; there is no root package.json). Doc-only cycles (`.md`/`.claude/` edits, like most of this very plan) skip bun-verify entirely instead of erroring. **This unblocks every other cycle — W0 of cycle 1 dies on the root-verify assumption without it.**
**Deliverable:** `.claude/scripts/do-folder.sh` — given a changed-file list, emit `{folder, verify_cmd, build_cmd, doc_only}` (top path segment → repo folder → that folder's `package.json` scripts; multi-folder change → emit each; only `.md`/`.claude/` touched → `doc_only=true`). `do.md` W0 + W4 call it: `cd` into the folder and run its verify/build, or skip when `doc_only`.  **Outcome:** a cycle touching `one.ie/web` runs `one.ie/web` verify; a cycle editing only `.claude/*.md` → `doc_only`, verify skipped, **no error**.
**demo:** bash — (a) file list under `one.ie/web` → resolves web `typecheck && test`; (b) only `.claude/*.md` → `doc_only=true`, skip; (c) files in two folders → both verify cmds. `<90 LOC`
- W1: `do.md §W0 baseline + §W4 verify`, the root folders + each `package.json` `scripts` (one.ie/web, packages/*, agents, api, schema, sync)
- W2: resolver = path-segment → folder map; doc-only detection = no non-`.md`/non-`.claude` paths; W0/W4 wrap verify in `cd $(do-folder.sh)`; **this is a fix, not a new primitive** — compose existing folder scripts
- W3a: `.claude/scripts/do-folder.sh` · W3b: `do.md` (W0 + W4 sections — lands before C1-C4's do.md edits) · W4: green (self: doc-only, so bash-only) · both fixtures proven · composite ≥ 0.65

## C1 — `.w2-spec.json` cycle-context pack + `.w2-doc-plan.json` (GAP 1+2 + dead-gate fix; lean ex-BMAD story-file)  [Opus·high decide · batch 1]
**Goal delta:** W2's plan lives in a file W3/W4 read by path; W1 receipts capped 400 words → no compaction-driven anchor mismatch. **And** W2 actually writes `.w2-doc-plan.json` — which `do.md:310-321` and `close.md` already *read* but nothing currently *writes* (the doc-sync gate is dead code today). **And** each diff spec carries the high-signal context the edit agent needs so it reads the pack, not the repo (BMAD's self-contained "story file", stripped to essentials).
**Deliverable:** `.w2-spec.json` + `.w2-doc-plan.json` written at W2. Each entry in `.diff_specs[]` gains three lean fields W2 already has from recon: `current_state` (≤8-line excerpt of the region being changed), `must_not_break` (one line — adjacent behavior to preserve), `serves` (the `D#`/deliverable it advances). These are persisted, not re-derived — net token cost ≈ 0 (W2 saw the file in W1).  **Outcome:** `jq -e '.diff_specs[0] | .current_state and .must_not_break and .serves' .w2-spec.json` and `jq -e '.touched_docs' .w2-doc-plan.json` after a canary W2.
**demo:** bash schema-validate both files against a fixture W2 output (incl. the 3 new per-spec fields). `<140 LOC`
- W1: `w2-decide.md`, `w3-edit.md`, `w4-verify.md`, `do.md §W2 step 5a + W4 doc-gate`, `agentic-patterns.md §GAP1/2`, `apps/BMAD-METHOD/.../bmad-create-story/SKILL.md` (the context-pack idea — take the shape, refuse the exhaustive per-unit re-analysis)
- W2: confirm W2 already emits structured specs (do.md:260-268) → change is write-to-file + read-path + the 3 context fields; make step 5a WRITE `.w2-doc-plan.json {renames,touched_docs,contract_dirs}`; cap W1 at 400 words
- W3a: the 3 agent files — **add the regression guardrail to `w3-edit.md`**: the spec now carries `current_state` + `must_not_break`; the agent preserves that behavior and a cycle must leave the system working end-to-end, not merely match the anchor (BMAD's #1 documented failure cause, prevented for ~free since context is in the pack)
- W3b: `do.md`
- W4: verify green · delta_tsc ≤ 0 · canary writes both valid files (with context fields) · doc-gate now fires · composite ≥ 0.65

## C2 — `.do-trust.json` (GAP 3)  [Sonnet·medium · batch 1]
**Goal delta:** trust read from JSON, not parsed from prose — can't fail silently.
**Deliverable:** `.do-trust.json {level,consecutive,composite,updated}`.  **Outcome:** `jq -e '.level' .do-trust.json`.
**demo:** bash — close writes it; `--auto` reads it first; absent → default `standard`. `<60 LOC`
- W1: `do.md §Trust levels + cycle close`, `§GAP3`  · W2: close writes / read-first / default standard if absent
- W3b: `do.md`  · W4: green · valid after canary close · composite ≥ 0.65

## C3 — `cost:cycle` signal + token receipt (GAP 4)  [Sonnet·medium · batch 1]
**Goal delta:** token spend recorded per wave + emitted as a substrate signal — spend becomes a routing gradient.
**Deliverable:** W4 receipt `tokens` field; close emits `signal("cost:cycle",{tokens,model,composite})`.  **Outcome:** canary `cost:cycle` exists with numeric tokens + valid receiver grammar.
**demo:** test in `one.ie/web` (signal route lives there) — receiver grammar `(actor|world|all|sub)(:[a-z:+\w]+)?` validates. `<70 LOC`
- W1: `w4-verify.md`, `packages/sdk/src/client.ts signal()`, `§GAP4`
- W2: compress — `cost:cycle` is an event, not a verb → **extend**, reuse `signal()` verbatim
- W3a: `w4-verify.md` · W3b: `do.md` · W4: green · receiver grammar valid · composite ≥ 0.65

## C4 — `.w3-receipts.json` soft resume (GAP 7)  [Sonnet·medium · batch 1]
**Goal delta:** interrupted W3 resumes from last edit, not from W1.
**Deliverable:** `.w3-receipts.json` appended per edit; startup resumes W3; deleted on close.  **Outcome:** kill mid-W3, re-run → resumes W3.
**demo:** bash — simulate a partial receipt file → startup skips W0–W2. `<90 LOC`
- W1: `w3-edit.md`, `do.md §startup/W3`, `§GAP7` · W2: append per edit + resume branch + cleanup on close
- W3a: `w3-edit.md` · W3b: `do.md` · W4: green · resume proven · composite ≥ 0.65

## C5 — Seed persistence + `plans/ideas.md`  [Opus·xhigh · batch 2]
**Goal delta:** an idea persists weakly on entry, promotes to TypeDB only on first `mark`, and `fade`s if never marked — backlog self-ranks, no manual prune.
**Deliverable:** `/create task`→weak KV seed; `mark`→TypeDB `thing`; `plans/ideas.md` mirror.  **Outcome:** create→KV seed; mark→TypeDB thing; no-mark+window→gone.
**demo:** `one.ie/web` vitest — weak seed → promote-on-mark → fade GC. **No TypeDB mock** (repo rule + [[feedback-no-mocks]]): hit real TypeDB or skip with a VCR cassette. `<140 LOC`
- W1: `create.md`, `one.ie/web/src/pages/api/tasks/`, `schema/one.tql` (thing+path), `dictionary.md`, [[data-layers]] 3-layer memory
- **W2 substrate reconcile:** seed = `thing` (dim 3) + weak `path`; `mark` strengthens; no new dim/verb; name per `dictionary.md`; compose `signal()`/existing task API
- W3a: `create.md` · KV helper / task API (`one.ie/web`) · `schema/one.tql` · `plans/ideas.md` (all disjoint from `do.md`)
- W4: green (in `one.ie/web`) · KV→promote→TypeDB proven · fade GC proven · **reconcile passed** · composite ≥ 0.65

## C6 — INTAKE + artifact-spine backfill (the front door)  [Opus·high · batch 3 · ←C5,C7]
**Goal delta:** `/do <anything>` turns a raw idea into an agreed **goal** at one human gate, then walks the **full artifact spine** — writing the promise/spec/todo/code/tests/docs/proof/release only where missing, skipping past whatever exists — and runs the rest autonomously. Backfill targets the *whole* spine, not just the planning prefix: a feature with code but no tests/docs gets those backfilled and nothing else.
**Deliverable:** lifecycle dispatch in `do.md` intent mode: when args are a bare intent (not a todo/flag), restate as goal → `do-intent` locate → propose tier (C7) → human gate → `mark` promotes seed (C5) → **read `do-lifecycle.md` and walk the spine**, presence-checking each artifact in order and backfilling only the gaps, running the two checkpoint gates inline: after **spec** → invoke **CLARIFY** (C12-authored, only when tier ∈ {FEATURE,SCHEMA}); after **todo** → run **ANALYZE** (`do-analyze.sh`, C14) and halt on CRITICAL. Code-presence uses SURVEY (C9); tests/docs presence is a per-repo-folder file check. Pre-agreed backlog auto-skips the human gate.  **Outcome:** an idea string yields agreed goal + tier + promoted seed; the spine writes only the missing artifacts; CLARIFY fires for FEATURE/SCHEMA and ANALYZE blocks a coverage-broken plan before build.
**demo:** bash + fixture dirs — (a) bare idea → writes the whole spine; (b) fixture with code + spec + todo but **no tests and no docs** → backfills exactly tests + docs, skips the rest; (c) a todo with a deliverable that maps to no cycle → ANALYZE returns CRITICAL and BUILD does not start. `<150 LOC`
- W1: `do.md §Modes + intent mode (do.md:100-101)`, `do-intent.md` (locate half), `do-loop.md §front door + idea lifecycle + phases (artifact-per-phase)`, C5 promote API, C7 tier-infer, C9 survey (code-presence), C14 analyze, C12 clarify
- W2: extend existing intent-mode dispatch (don't fork); **the spine is tier-pruned BEFORE the walk** (C7 emits the stop set — a PATCH presence-checks `code`+`verify` only, never 8 stops + 2 gates); spine = ordered presence-check, backfill-or-skip each *enabled* stop, with CLARIFY after spec (tier-gated) and ANALYZE after todo (only when the tier has a todo); the human gate is the only interrogation point (INTAKE), CLARIFY is design-time decision capture not a front-door questionnaire; reuse `AskUserQuestion` for CLARIFY's ≤5 Qs
- W3b: `do.md` (intent-mode section) · W4: green · gate+promote proven · full-spine + mid-spine-only backfill proven · CLARIFY tier-gating + ANALYZE block proven · no-interrogation-at-INTAKE rule enforced · composite ≥ 0.65

## C7 — Tier control plane (the token-economy spine-pruner)  [Sonnet·medium · batch 2]
**Goal delta:** `/do` runs only the phases a change earns; the product tier composes with do.md's code classifier instead of competing; the tier is also the one signal that prunes the spine and budgets the cycle — so token savings are automatic, not a flag.
**Deliverable:** `.claude/scripts/do-tier.sh` — `git diff --stat`/intent tier inference (PATCH/FIX/FEATURE/SCHEMA, **default-down when unsure**) that emits: (a) the **pruned spine** (the exact stops+gates C6 will walk — PATCH = `code`+`verify`, FIX = `+SURVEY`+`PROVE`, FEATURE/SCHEMA = full); (b) the inner classifier mapping (TRIVIAL/SIMPLE/COMPLEX) for BUILD; (c) a **per-tier expected token ceiling** the cycle close checks (`cost:cycle` over ceiling → `warn` + justify-or-drop). `--tier` overrides. Plus a one-paragraph reconciliation note in `do.md`.  **Outcome:** typo→PATCH (2-stop spine, 0 spawns, lowest ceiling); new capability→FEATURE (full spine); `.tql` touch→SCHEMA (reconcile at max); a SIMPLE cycle that blows the ceiling → warn.
**demo:** bash — each trigger fixture → correct pruned spine + classifier + ceiling; an over-budget fixture → warn exit. `<120 LOC`
- W1: `do-loop.md §Loop tiers`, `do.md §Complexity classifier + Trust/cost`, the Token-economy table above
- W2: tier→{spine,classifier,ceiling} as one deterministic map; "one gradient, two scopes" reconciliation (no deletion of either classifier); ceilings calibrated from early `cost:cycle` data, not guessed precisely (start generous, tighten via SELECT)
- W3a: `.claude/scripts/do-tier.sh` · W3b: `do.md` (tier note) · W4: green · all 4 tiers → correct pruned spine · ceiling-warn proven · composite ≥ 0.65

## C8 — Worktree lifecycle  [Sonnet·medium · batch 3 · ←C7]
**Goal delta:** FEATURE/SCHEMA build in a worktree that merges to trunk only on PROVE pass — every trunk commit is a kept promise.
**Deliverable:** create-on-FEATURE/SCHEMA (`Agent isolation:"worktree"`), merge-on-PROVE-pass, abandon-on-fail, `--batch` one-per-feature, split-test N-variants (winner merges, losers `warn(0.5)`) — documented in `do-lifecycle.md §parallelism`.  **Outcome:** a failing PROVE leaves trunk untouched; a passing one merges.
**demo:** bash — pass→merge, fail→abandon, batch→N worktrees (git fixture). `<110 LOC`
- W1: `do-loop.md §parallelism+worktrees`, Agent isolation docs, C7 tier; note do.md opt-6 split-test (W3-level) — keep distinct from this feature-level one
- W2: PATCH/FIX skip (trunk direct); merge gate = PROVE pass; abandon = drop worktree
- W3b: `do-lifecycle.md` · maybe `.claude/scripts/do-merge.sh` (W3a) · W4: green · merge/abandon proven · composite ≥ 0.65

## C9 — SURVEY script  [Sonnet·medium · batch 2]
**Goal delta:** before SPEC opens, recon the 4 surfaces for ≥70% matches and emit a simplicity verdict — stop re-building what exists.
**Deliverable:** `.claude/scripts/do-survey.sh` — greps `one.ie/web/src/pages/api/`·`one.ie/web/src/components/`·`packages/sdk/`·`agents/`+`plans/`, ≤400-word receipt, verdict ∈ expose/extend/build/drop + gap list.  **Outcome:** a duplicate-of-existing idea → `expose`/`extend`, not `build`.
**demo:** bash — fixture with existing match → non-build verdict. `<90 LOC`
- W1: `do-loop.md §Survey`, the 4 surface dirs · W2: grep recipe + verdict rubric + 400-word cap
- W3a: the script · W4: green · verdict correct on fixture · composite ≥ 0.65

## C10 — Substrate reconciliation gate  [Sonnet·medium · batch 2]
**Goal delta:** a feature that needs a new dim/verb is rejected, dead names auto-fail, before any design spend.
**Deliverable:** `.claude/scripts/do-reconcile.sh` — dim/verb membership check + dead-name grep against `dictionary.md` + type/`.tql` flag.  **Outcome:** a dead-name proposal → non-zero exit; a clean one → 0.
**demo:** bash — dead name fails, canonical passes. `<80 LOC`
- W1: `do-loop.md §Substrate reconciliation`, `dictionary.md` dead-name list, `one-ontology.md` dims, `dsl.md` verbs
- W2: 4 ordered checks, first hard-no wins · W3a: the script · W4: green · both cases proven · composite ≥ 0.65

## C11 — PROVE script (surface-detect + promise-check + /browser)  [Sonnet·medium · batch 3]
**Goal delta:** PROVE auto-detects surface and verifies the shipped artifact matches the FRAME promise + types compile across consumers.
**Deliverable:** `.claude/scripts/do-prove.sh` — detect surface from diff; run `/browser` (frontend) / `curl` deployed (backend) / contract test (api) / `/sync`+TypeQL (substrate); promise-check vs `text/` copy; type-lockstep check.  **Outcome:** a frontend change runs `/browser`; an over-promised copy fails the check.
**demo:** bash — surface routing + failed promise-check on fixture. `<130 LOC`
- W1: `do-loop.md §closed loop + surface matrix`, `browser.md`, `sync.md`
- W2: surface detect map; promise-check = re-read copy vs artifact; four-surface + type-lockstep rules
- W3a: the script · W4: green · routing + promise-fail proven · composite ≥ 0.65

## C14 — ANALYZE coverage gate (ex-Spec-Kit `/analyze`)  [Sonnet·medium · batch 3]
**Goal delta:** before BUILD spends worktree tokens, a read-only gate proves the plan is internally consistent — every deliverable maps to a cycle, no cycle is orphaned, no terminology drift across `text↔spec↔todo`, no locked-rule violation. Misalignment is caught where it's cheapest, not after a build.
**Deliverable:** `.claude/scripts/do-analyze.sh` — given a `<f>-todo.md`, build the coverage matrix (every `D#` deliverable → ≥1 `C#` cycle, bidirectional; orphans flagged); **AC→test coverage** (every shippable `D#` has a planned test — a `demo:` line — else HIGH; this is DoD row 2's *planned* half, W4 verifies it green); grep for locked-rule breaks (calendar words → structural-time violation; a cycle with no numeric close → closed-loop violation); dead-name + terminology-drift grep across the trio against `dictionary.md`. Emits a severity-ranked report (CRITICAL/HIGH/MEDIUM/LOW); **CRITICAL exits non-zero** (blocks build), others warn. Read-only — never edits.  **Outcome:** a todo with an uncovered deliverable or a calendar-time cycle → CRITICAL, exit 1; a shippable deliverable with no planned test → HIGH; a clean plan → exit 0, coverage ≥ 100%.
**demo:** bash — (a) fixture todo missing a cycle for one deliverable → CRITICAL exit 1; (b) a deliverable with no `demo:` line → HIGH; (c) this very `do-loop-todo.md` → 100% coverage + every shippable D# has a demo, exit 0. `<130 LOC`
- W1: `apps/spec-kit/templates/commands/analyze.md` (detection passes + severity heuristic — adapt, don't copy), `template-todo.md` (the D#/C# contract), `dictionary.md` dead names, root `CLAUDE.md` (3 locked rules)
- W2: coverage matrix = bidirectional D#↔C# map from frontmatter; locked-rule checks are greps (calendar words, missing close); constitution = our locked rules + dictionary, NOT a new file (don't import Spec-Kit's `/memory/constitution.md` — we already have truth); severity heuristic trimmed to our 4 categories
- W3a: the script · W4: green · both fixtures proven · self-check on this plan = 100% · composite ≥ 0.65

## C12 — The merge: fold the lifecycle into `/do`, kill `/do-loop`  [Opus·high · batch 4]
**Goal delta:** `/do` becomes the single command. The lifecycle design is preserved as the spec `/do` reads; the accidental `/do-loop` command is removed; `do.md`'s intent mode dispatches the ladder, applying C7 tiers, C8 worktrees, C1–C5 state, the effort×model dial, and inner+outer parallelism.
**Deliverable:**
  1. `git mv .claude/commands/do-loop.md .claude/commands/do-lifecycle.md` — content preserved (it's the awesome part); retitle, fix self-references, mark it "spec, read by /do — not a command."
  2. Make the ladder in `do-lifecycle.md` executable: each phase names the command it composes (FRAME→`writer`, SPEC→Opus, PLAN→`/create todo`, EQUIP→skill-check, BUILD→`/do` W0→W4, PROVE→C11, TEACH→`tutorial`, SHIP→`/release`+adoption signal, LEARN→`/do --improve`); lifecycle signals (`mark`/`warn`/`fade`/`harden`) at each transition.
  3. **Author the CLARIFY sub-step** in `do-lifecycle.md`'s SPEC phase (ex-Spec-Kit `/clarify`, trimmed to our world): a compact ambiguity taxonomy (scope/data-model/edge-cases/non-functional/terminology vs `dictionary.md`/completion-signals), ≤5 high-impact Qs asked one at a time via `AskUserQuestion`, each answer written back into `plans/<f>.md` under a `## Clarifications` section. Tier-gated to FEATURE/SCHEMA; skipped for PATCH/FIX. Frame explicitly as design-time decision capture, NOT a second human gate — INTAKE stays the one front-door checkpoint.
  4. `do.md` intent mode reads `do-lifecycle.md` (C6 wired this); confirm no second entry survives.
  5. Remove the `/do-loop` command registration; grep `/do-loop` repo-wide → 0 hits outside history.
**Outcome:** a canary `/do <idea>` completes the whole loop unattended past the one gate; `grep -rl '/do-loop' .claude/ plans/` returns nothing.
**demo:** logged canary `/do <idea>` run (the LLM loop) + `bash` assertion that `/do-loop` is gone and `do-lifecycle.md` is reachable from `do.md`. `<80 LOC of edits`
- W1: all of `do-loop.md`; `do.md §Modes`; the phase commands; C1–C11+C14 outputs; `apps/spec-kit/templates/commands/clarify.md` (taxonomy reference — trim, don't copy)
- W2: the phase→command→model→effort table; tier-gated phase skipping; worktree merge-on-PROVE; CLARIFY taxonomy (≤5 Qs, write-back to spec, FEATURE/SCHEMA only); confirm single entry point
- W3b: `do-lifecycle.md` + `do.md` · W4: green · canary loop completes · every phase invoked · signals emitted · CLARIFY fires on a FEATURE fixture + skips a FIX · `/do-loop` absent · composite ≥ 0.65

## C13 — Deterministic smoke (the outcome gate)  [bash·none · batch 5]
**Goal delta:** one command proves the deterministic substrate works end-to-end — the loop's plumbing has a kill-switch (the LLM loop is proven by the logged canary, not bash).
**Deliverable:** `.claude/scripts/do-smoke.sh` — drives fixtures through the helpers C0+C7–C11+C14 + the state-file schemas + the seed lifecycle, asserts: **do-folder resolves the right folder + skips doc-only** · tier-infer correct · reconcile rejects/passes · survey non-build verdict · **analyze blocks an uncovered plan / passes a clean one** · seed KV→promote→fade · `cost:cycle` grammar valid · `.w2-spec`/`.w2-doc-plan`/`.do-trust`/`.w3-receipts` schemas validate · `/do-loop` absent.  **Outcome:** exits 0.
**demo:** `bash .claude/scripts/do-smoke.sh` (this IS the plan outcome). `<90 LOC bash`
- W1: every artifact C1–C12+C14 produce · W2: chain assertions, fail-fast, fixtures only (no live LLM) · W3a: the script · W4: exits 0 on fixtures · composite ≥ 0.65

---

## See also
- `.claude/commands/do.md` — the single command; the lifecycle merges into its intent mode
- `.claude/commands/do-loop.md` → becomes `do-lifecycle.md` (C12) — the design this plan preserves and makes executable
- `plans/agentic-patterns.md` — GAP 1,2,3,4,7 (C1–C4 source)
- `.claude/commands/{create,do-intent,close,release,sync,browser,do-improve}.md` — phase commands C12 wires
- `plans/dictionary.md` · `schema/one.tql` — C5/C10 substrate names; `dictionary.md` + root `CLAUDE.md` locked rules = the "constitution" C14 ANALYZE checks against (we do NOT adopt Spec-Kit's separate constitution file)
- `apps/spec-kit/templates/commands/{clarify,analyze}.md` — provenance for C12 CLARIFY + C14 ANALYZE; adapt to our world, never copy (no `extensions.yml` hook protocol, no `/memory/constitution.md`)
- `plans/template-todo.md` — the contract this plan follows; the D#/C# coverage keys C14 reads
