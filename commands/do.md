# /do — idea to reality, fast

**The goal, stated once, so every rule below has to earn its place against
it: move quickly and efficiently from idea to reality.** Every step in this
doc exists because it makes that faster or safer — never as ceremony. Where
a step doesn't, cut it (as Step 3 already was, 2026-09-22 — 200 lines of
W0–W4 wave machinery replaced by five lines pointing at the factory).

**ONE builds itself through this loop.** Type `/do "<an idea>"` and it walks the whole build lifecycle — agreeing a goal, walking the artifact spine, **making each artifact true**. Every cycle writes `mark`/`warn`/`signal("cost:cycle")` back into the substrate. The world grows smarter with each run; the loop and the substrate are the same system.

For each artifact on the spine: `true(artifact) ≡ exists(artifact) ∧ reconciles(artifact, canon)`. Missing → write. Stale → rewrite. True → skip.

The human owns one thing: the goal sentence. `/do` owns everything below it.

> Narrative for humans: `text/do.md`. Per-stage template/skill/agent routing: `text/templates-plan.md`. Surface layers detail: `text/surfaces-layers.md`. Skill invocation contract: `text/skill-invocation.md`. Full-stack composition example: `text/sdk-mcp-cli-schema-design-integration.md`. This file is what `/do` executes.

---

## Principles · parallelism · substrate signals

Moved to `text/do-reference.md` — read it ONLY on a miss (a decision
the core below does not settle). The four rules it carries, in one line each:

- **Docs-first** — the doc is the spec AND the acceptance oracle; written before
  BUILD, made true by PROVE.
- **Progressive disclosure** — each phase loads only what it needs; widen on a miss.
- **Tool ladder** — bash → Haiku → Sonnet → Opus → Fable; stop at the first that
  decides. Fable is apex judgment ×1, never sweeps, never edits.
- **Parallel by default** — `C_n → C_m` exists ONLY when C_m reads a file C_n
  writes. Every other arrow is an imaginary blocker; reject on sight.

Every phase emits `signal("world:do-event", payload)`; the router fans to
followers and `mark()` closes the loop. Payloads + tag list: the reference.

---

### The coherence ratchet

`reconciles` is not pass/fail in isolation — it is **monotonic**. A write may leave the system *more* coherent or equally coherent. Never less.

```
types     — zero new tsc errors          (the original ratchet)
names     — converge to the dictionary   (no new synonym, no dead name)
primitives— net new ≤ 0                   (compose 3 existing before adding 1)
schema    — extend, never fork            (one model, not two)
surfaces  — reachable, never orphaned     (registered + linked, never dangling)
docs      — synced, never stale           (no broken link, no lie)
```

This is what *"every line makes the system stronger"* means mechanically: coherence is a gate the loop runs, not a hope. The ratchet can tighten the system; it can never loosen it.

### Fast & lean — the token economy (automatic, never a flag)

Comprehensive and fast are not in tension: the **tier decides which gates run**, so a typo never pays for a feature's pipeline.

| Lever | Fires at | Saves by |
|---|---|---|
| Tier prune | Step 1 | PATCH walks `BUILD → VERIFY` only; a gate never runs above the phases it guards |
| Tool ladder | every decision | bash → Haiku → Sonnet → Opus → Fable; stop at the first that decides |
| **Context reset** | cycle boundary | multi-cycle plans run each cycle in a fresh subprocess (`do-auto.sh`) — prior-cycle chatter (~15–25k/cycle) never accumulates; ~90–150k saved on a 6-cycle plan |
| **TRIVIAL fast-path** | BUILD | **0 agent spawns** — read ≤3 files inline, edit, bash verify, inline rubric, 1 learnings line |
| **Deterministic W1** | W1 | `do-recon-pack.sh` — brief + per-file exports/imports/consumers + the prior cycle's improvements, **0 model tokens in 0.28s**. Removes the ~6.4KB `w1-recon` prompt from the default path entirely |
| **Deterministic W4 gates** | W4 | `do-w4-gates.sh` — the whole gate battery in ONE call (~1.3s), four-state receipt. Removes the ~34.3KB `w4-verify` + `w4-tools` spawn; only the rubric verdict stays a model judgment, scored by the in-context conductor |
| Recon cache | W1 | `do-recon-cache.sh check` — sha-keyed local store, <14d → **0 tokens**; folded into the recon pack, still runnable standalone (saves ~12k/recon) |
| ~~W1 prefix cache~~ | — | **Does not exist.** `w1-recon.ts` is a 6-line stub that writes `[w1-recon] using agent spawn` and exits 2 *unconditionally* — the API key is irrelevant. Kept as the escalation door, not as a saving. Do not quote its numbers |
| W4 rubric judge | W4 | `w4-rubric.ts` — **one** OpenRouter Haiku call scoring the 5 *task* axes (not 6 parallel Haiku, and no prefix cache: it has neither). Needs `OPENROUTER_API_KEY`; absent → exit 2, and the conductor scores from `do-w4-gates.sh` instead |
| Verify-only-changed | W3→W4 | dependency cone from `git diff`; full verify only at cycle close |
| Cross-cycle pre-warm | W4 close | one fire-and-forget Haiku pre-reads the next cycle's W1 targets |
| Recon cap | W1 | 400-word receipt; high-signal slices → `.w2-spec.json`, not the raw dump |
| Write-once state | per cycle | `.w2-spec`/`.w3-receipts` read by path, never re-derived after compaction |
| `cost:cycle` gradient | close | spend → pheromone; future SELECT routes toward cheap-and-effective paths |

A cycle that runs **zero LLM calls** is a *good* cycle. The comprehensiveness lives in the gates (DoD, rubric, RECONCILES, ANALYZE, PROVE); the tier decides how many of them you pay for.

## Step 0 — Classify the input

| Input | Treat as | Entry |
|---|---|---|
| bare text (`"add usage billing"`) | **IDEA** (default) | walk the spine from the top |
| `<slug>` or a `text/*.md` path | existing work | resolve its slug; **always builds in a worktree** — ≥2 incomplete cycles → auto context-isolated loop, else walk the spine in-session inside a `--setup-only` worktree |
| `--here` | run inline on the **current tree** — skip the worktree, for a trivial in-session edit you'll commit yourself | BUILD engine |
| `--wave N` | force one wave of a todo | BUILD engine |
| `--next-cycle` | *(internal)* run one batch then exit — the loop's recursion guard, set by `do-auto.sh`; never typed by a human | BUILD engine |
| `--auto` | *(legacy alias)* same as a bare multi-cycle `/do <slug>` — the loop is automatic now | BUILD engine, trust-aware |
| `--autonomous` | *(set by the orchestrator)* resolve gates without a human — see **Autonomous gate resolution** below | BUILD engine, headless |

Derive the **slug** from the idea: kebab-case, 2–4 words (`"add usage billing"` → `usage-billing`). Every artifact on the spine is keyed by this slug.

### Orchestrator verbs — `/do` across MANY plans

If the **first word** after `/do` is one of these reserved verbs, it routes to the cross-plan orchestrator: run the mapped script via Bash, show its output verbatim, don't editorialize. Anything else is an idea/slug (above). None of these merge to `main` — they stop at the merge gate.

| Type | Does | Runs |
|---|---|---|
| `/do next` | show the ranked priority queue (what to build next) | `.claude/scripts/do-rank.py` |
| `/do audit` | classify every plan's kill-switch — armed/green/broken/prod | `.claude/scripts/do-killswitch-audit.py --run` |
| `/do loop [N]` | **preview** — what the loop WOULD build (dry-run, N iters, default 3) | `.claude/scripts/do-orchestrate.sh --iters ${N:-3}` |
| `/do auto [N]` | **build hands-off** — top N eligible+armed plans → branches, stop at merge | `DO_CONDUCTOR_TIMEOUT=900 .claude/scripts/do-orchestrate.sh --autonomous --go --iters ${N:-1}` |
| `/do fleet [N]` | build N file-disjoint plans in parallel worktrees (default 2) | `.claude/scripts/do-fleet.sh --max ${N:-2} --go` |
| `/do accept <slug>` | record a merge you landed (earns trust toward auto-merge) | `.claude/scripts/do-accept.sh <slug> accept` |
| `/do reject <slug>` | record a branch you abandoned | `.claude/scripts/do-accept.sh <slug> reject` |
| `/do prove` | prove the anti-fabrication gate (4/4) | `.claude/scripts/do-orchestrate.sh --prove-gate` |
| `/do rubric [pkg]` | score security · stability · simplicity · integration · speed; writes W0 baseline the loop reads | `python3 .claude/scripts/do-rubric.py ${pkg:-"--all"}` |
| `/do turn` | **one wavefront turn of ONE LOOP** — 4 haiku senses ∥ → opus pick (fable on anomaly) → 1–4 disjoint moves ∥ (worktree-isolated, model per move) → haiku skeptics re-run every receipt → one sonnet close (marks, log, state, rotation) | `Workflow({scriptPath: ".claude/workflows/one-loop.js"})` — contract: `text/one-loop.md` |

`/do turn` is the company loop, not a plan loop: it picks across ALL lanes (SETTLE·BUILD·SHIP·DISTRIBUTE·SELL·MINE·LEARN), and its **verify-before-mark law** is absolute — an executor's claimed success is worthless until an independent skeptic reproduces the receipt; unverified success closes as `warn`. Self-grading corrupts weights at scale. Code moves land on `loop/<slug>` branches; merge stays human.

`/do auto` builds **nothing** when no plan is hermetic ∧ genuine-armed ∧ no-open-judgment — that's correct (it refuses unsafe work with a receipt). Give it fuel: a `tier: fix` plan with a LOCAL `outcome:` (see `text/orchestrator-how-to.md` §8). Full runbook: `text/orchestrator-how-to.md`.

### Autonomous gate resolution (`--autonomous` / `DO_AUTONOMOUS=1`)

Headless, the four asking-gates **must not call `AskUserQuestion`** — there is no human to answer, so it wedges. Resolve each by rule (the orchestrator only feeds *eligible* plans, so these rarely fire). Logic + tests: `one.ie/web/src/lib/do-autonomous.ts`; design: `text/do-autonomous-plan.md`.

| Gate | Autonomous action |
|---|---|
| **AIM** (goal+tier) | **Resolve** from frontmatter `goal:`/`tier:` — the plan is authored, the human already answered. No question. |
| **W3 anchor-miss** | **Re-plan once** — re-run W2 recon against current code to regenerate anchors, then retry. Miss again → **park**. |
| **CLARIFY** | **Park** — emit `signal("world:do-event",{type:"park",reason:"needs-clarification"})`, tag `do:parked`, stop the cycle. Never guess. |
| **PROMISE** (missing) | **Park** the same way — a missing promise is a missing spec. |

**The rule:** auto-resolution ≠ auto-approval. Resolve what's encoded or safely derivable; **park** genuine judgment (a parked plan lands in the inbox for a human). The anti-fabrication gate (real ∧ ungamed ∧ kill-switch green) still runs on every autonomous cycle, and **merge stays human** until merge-trust is earned (L4, `autonomyLevel`). Never auto-merge from `--autonomous` alone.

---

## Step 0.5 — COMPILE the brief (do this FIRST; it answers most of what follows)

```bash
.claude/scripts/do-brief.sh <slug>            # a plan cycle
.claude/scripts/do-brief.sh --files <path>... # a loose change
```

One JSON object, zero model tokens: `{slug, plan, ready, files, folders, tier,
spine, classifier, ceiling_tokens, w2_model}`. It is a JOIN over `do-plan-json`,
`do-next`, `do-tier` and `do-folder` — the four scripts the waves used to make a
model re-derive in prose.

**Read the brief; never re-derive a field it already answers.** `tier` and `spine`
settle Step 1. `folders` settles the verify command in W0/W4. `ready` settles
which cycles may run now (the DAG, not the batch barrier). `plan.worktree`
settles where. A wave that re-asks one of these is spending tokens on a fact that
is already on disk.

Consequence for the wave count: with the brief compiled, a cycle needs at most
**two** model calls — W2 (decide what the edit is; not delegable) and W3 (make
it). W1 collapses into the brief plus `do-recon-cache.sh check`; W4's gates are
already bash and only the rubric verdict is a model call. A TRIVIAL/PATCH cycle
needs **one**.

`do-brief.sh --self-test` proves it: it refuses a missing plan with empty stdout,
emits every required key, and — the red proof — asserts the tier actually
discriminates (a doc edit and a `schema/*.tql` edit must not size the same).

---

## Step 1 — Goal + tier (the one human gate)

1. **Restate as a goal**, one sentence: *"a {persona} can {outcome} they couldn't before."* Not "ship X" — "user can do Y" / "system enforces Z".
2. **Size the tier** (the token economy — automatic, never a human choice):
   ```bash
   .claude/scripts/do-tier.sh --intent "<idea>" $(git diff --name-only 2>/dev/null)
   ```
   Emits **tier** (PATCH | FIX | FEATURE | SCHEMA), the **pruned spine** (which stops run), the **inner classifier** (TRIVIAL | SIMPLE | COMPLEX for BUILD), and a **token ceiling**. Default down when unsure — an under-built FIX reopens cheaply at PROVE; an over-built PATCH is tokens you can't refund.

   **`UNSIZED` (exit 3) is the expected answer at AIM on a clean tree.** `git diff` is
   empty before any edit exists, and `do-tier` sizes a *diff*, never a sentence — so it
   refuses rather than guessing. It used to fall through to PATCH/TRIVIAL/5k here, which
   silently mis-sized real work twice on record (`text/learnings.md:485`,
   `text/remote-suspend-todo.md:5`). On `UNSIZED`: name the files the idea would touch
   (a grep or a `w1-recon` spawn — this is what SURVEY does anyway), then re-run
   `do-tier` with those paths. Never treat `UNSIZED` as PATCH. Note it exits non-zero,
   so under `pipefail` a `do-tier … | grep` returns 3 even when the grep matches —
   capture the output first.
3. **Confirm once** — goal sentence + tier, in a single `AskUserQuestion`. Never interrogate. A pre-agreed backlog item auto-skips this gate.

The pruned spine by tier:

```
PATCH     AIM → BUILD → VERIFY                                                                          (edit + W4 verify gate; 0 spawns)
FIX       AIM → SURVEY → [INVESTIGATE] → DOCS → BUILD → TEST → PROVE → LEARN
FEATURE   AIM → PROMISE → SURVEY → DESIGN ▸clarify → DOCS → PLAN ▸analyze ▸board ▸meet → TEST → BUILD → VERIFY → PROVE → TEACH → SHIP → LEARN
SCHEMA    = FEATURE + Substrate reconcile at max

  ▸ Docs-first order: DOCS (the full doc set = the spec) is written right after DESIGN; TEST (from those docs)
    is written before BUILD; BUILD makes docs+tests true; PROVE validates the shipped thing against the docs;
    TEACH is now reconcile-not-author (correct any doc↔reality drift so every doc ends true).

  ▸ Board-then-meet: ▸board mirrors the plan's batch DAG onto the board as chained rows; ▸meet convenes
    the heads who will claim them. BOTH run before BUILD, and in that order — a meeting called before the
    rows are chained hands every head every cycle at once, and the fan-out is a race.
```

`INVESTIGATE` rides any tier when the work touches code we didn't just write — it's the "understand before you change" step, not a separate tier.

---

## Step 2 — Walk the artifact spine (presence-check · backfill · skip)

For each **enabled** stop (per the pruned spine), in order: check if its artifact exists and reconciles with its canon. **True → skip. Missing or stale → write/rewrite with the owner below.**

| Stop | Presence check | Missing → write with | Owner · model · effort |
|---|---|---|---|
| **AIM** | goal + tier confirmed | `AskUserQuestion` (one) | — |
| **PROMISE** | `test -f text/<slug>.md && .claude/scripts/do-promise-lint.sh <slug> --red` | `writer` skill + `text/template-feature.md` | sonnet · medium |
| **SURVEY** | `do-survey.sh` (4 surfaces) | reuse verdict (expose / extend / build / drop) → the gap list, not the whole idea, feeds the design | `w1-recon`, `Explore` · haiku · low |
| **INVESTIGATE** *(fix / legacy only)* | code we didn't just write | forensic recon → root cause (not symptom) + blast radius + the `must_not_break` line | `w1-recon` · haiku→sonnet · medium |
| **DESIGN** | `test -f text/<slug>-plan.md` | Opus + `text/template-plan.md` (designs the gap list; pre-mortem + decisions live in the template), then `do-reconcile.sh substrate` + `do-reconcile.sh dictionary` | opus · high |
| ↳ *CLARIFY* | plan has `## Clarifications` (FEATURE/SCHEMA) | ≤5 `AskUserQuestion`, written back into the plan | opus · high |
| ↳ *SPEC docs* | `-features.md` if scope is multi-capability; `-ui.md` if the feature ships a user-visible surface | `docs` skill picks the types → `text/template-features.md` / `text/template-ui.md` (conditional — see Doc artifacts below) | sonnet · medium |
| **DOCS** | doc set exists ∧ reconciles | the **full** doc set, written as the spec — `docs` skill picks the types, `writer` drafts: always `-docs.md`; + `-tutorial`/`-how-to`/`-reference`/`-agents-docs` per condition. Written in the reader's language *before* code — this is the acceptance spec PROVE validates against. Not a draft: the real thing | sonnet · medium |
| **PLAN** | `test -f text/<slug>-todo.md` | `/create todo` + `text/template-todo.md` — cycles + deliverables derived from the docs (each cycle ships a documented observable) | sonnet · medium |
| ↳ *ANALYZE* | — | `do-analyze.sh text/<slug>-todo.md [--strict-promise]` — CRITICAL exit 1 blocks BUILD. Also reads `text/<slug>.md` and HIGH-warns any promise `accept:` no `C<n>` cycle carries (the todo's `outcome:` and `Correct-course` blocks are not corpus — that's where the gap hides); `--strict-promise` makes an uncovered deliverable CRITICAL | bash · none |
| ↳ *BOARD* | `bash .claude/scripts/do-board.sh <slug> --status` shows a tid and a live status on every cycle (drift 0) | **`bash .claude/scripts/do-board.sh <slug>`** — the ONE minter of cycle rows (`do-signal.sh --task-plan` delegates to it). Reuses the plan row do-auto already filed as `anchor:`, walks the batches **in order**, one `tasks:subtask` per cycle (`parent` = anchor, `blockedBy` = the previous batch's tids, tags `slug:<slug>-c<n>` + `plan:<slug>`, notes = the cycle's goal delta + the close command), and writes `anchor:` + `cycle_rows:` back after **every batch**. Idempotent (an existing row only gets its edges re-asserted with `tasks:depend`) and resumable. `--dry-run` walks the same loop against a fake door. **The return leg already exists:** the engine's `--task-cycle <slug> C<n> done` resolves the same `slug:` tag, so closing a cycle unblocks the next batch on the board with no new wire | bash · none |
| ↳ *MEET* *(fan-out plans only — any batch with ≥2 cycles)* | a thread id in `/u/<slug>/in` and every claimable cycle row carries a **named** assignee (`do-board.sh <slug> --status`) | the `meeting` skill — chairman convenes, heads **claim · delegate · chat · chain**, ledger read back from D1. Under the shared gateway key every head claims as the workspace (`@one`), so a head **names itself with `tasks:reassign` after `tasks:claim`** — the two calls are one act. Skipped when the plan is one head wide | opus · high |
| **TEST** | test file in the repo folder | test-first **from the docs** — one assertion per documented observable; the docs' claims become the executable acceptance tests *before* code exists | sonnet · low |
| **BUILD** | survey verdict = `build` (≥70% match → `expose`/`extend` instead) | the BUILD engine (Step 3) — make the docs + tests true | sonnet · low–medium |
| **VERIFY** | rubric + ratchet pass | `do-reconcile.sh <canon>` per category + rubric composite ≥ 0.65 | haiku · medium |
| **PROVE** | proof artifact captured | `do-prove.sh` (browser / curl / contract / sync) + `accessibility`; the shipped thing checked against **the docs** — `text/<slug>-docs.md` (every documented observable) + `text/<slug>.md` (the promise). The docs are the oracle. A multi-cycle plan already built on its own `do/<slug>` branch (worktree isolation — see context isolation below); PROVE is the gate that branch must clear before a human merges it to trunk | sonnet · low |
| **TEACH** | docs reconcile with shipped reality | **reconcile, not author** — the docs were written first at DOCS; now correct any doc↔reality drift so every doc ends *true* (fix the doc where reality justifiably diverged, or loop BUILD where the code missed the spec). `docs` skill + `writer` | sonnet · medium |
| **SHIP** | changelog / README row | `/release` + adoption signal | sonnet · low |
| **LEARN** | learnings entry written | close: learnings + cost signal + trust write | — |

### The board is the plan's other rendering — and the gate that enforces it

A plan's cycles and the board's rows are **the same work, twice**. Until ▸board existed they were
two graphs that drifted: `batches:` held the ordering in markdown, D1 held it in `blocks` edges,
and nothing joined them.

**The join is not bookkeeping. `tasks:claim` is BLOCKER-GATED and reads the very `blocks` edge
`tasks:depend` writes.** So a plan mirrored onto the board **cannot be claimed out of order** —
the substrate enforces the batch DAG that used to be a comment. A plan that is *not* mirrored
hands every agent every cycle at once.

```
batches: [[C1],[C2,C3],[C4]]   ≡   C2.blockedBy=[C1] · C3.blockedBy=[C1] · C4.blockedBy=[C2,C3]
```

**If the two disagree, the BOARD is truth** — it is what the gate reads. `do-plan-json.sh` emits
both so the drift is visible rather than silent.

**Mint with `tasks:subtask`, never `tasks:create`.** Subtask writes the row, its notes, its tags,
its `containment` edge to the anchor **and** every `blockedBy` in ONE pipeline — precisely so a
child never appears claimable with an empty body or missing ordering. A cycle row made with
`tasks:create` is an orphan that some head claims before it is ready.

**A cycle with no row is invisible to every agent but the one running `/do`.** Measured
2026-09-12: fifteen filed rungs returned in **zero** of `tasks:everywhere`'s reads at any limit
(hard cap 200, weight DESC, `tag` ignored) — which, not neglect, was why every one had sat open.
Read rungs with `tasks:list` by tag, and treat a count from a capped door as not a count.

### ▸meet — the four verbs, and when the chairman convenes

A meeting is **not** where heads report. It is where they take a row, hand a row, argue on the
row, and put the rows in order:

| verb | door |
|---|---|
| **claim** | `tasks:claim` — blocker-gated; the claimant is the **attested caller**, never a body field. Under the gateway key that caller is the *workspace* (`@one`) for every head, so a spawned head follows the claim with `tasks:reassign {assignee: <its own slug>}` or the ledger cannot say who took what |
| **delegate** | `tasks:reassign` (moves the row in place) · `tasks:announce` (to the world by tags — returns `matched`, and **matched is not delivered**) |
| **chat** | `tasks:comment` (same D1 store as the inbox thread) · `thread:append` for the room |
| **chain** | `tasks:subtask` (split) · `tasks:depend` (order) |

Protocol: the **`meeting` skill** (`.claude/skills/meeting/SKILL.md`); form:
`text/template-meeting.md`. Two rules the skill enforces that `/do` depends on — **no head leaves
without a tid**, and **size the spawn to the budget** (five heads spawned into a budget that
carried two report nothing at all).

**The lease moves to the cycle.** `blockersResolved` reads `containment` too, so once cycle rows hang off the anchor a `tasks:claim` on the plan row is refused as `blocked` for the whole run. `do-signal.sh --task-claim` and `do-fleet.sh` therefore lease the **first open cycle's row** when `cycle_rows:` is filled — the row actually in flight, gated by its own batch.

**▸meet is skipped when the plan is one head wide.** A meeting with one attendee is a status
update, and the checklist refuses it.

**Docs are written first, validated last.** `text/<slug>-docs.md` (and the conditional doc set) is the **spec** — authored at DOCS, *before* BUILD, in the reader's language, so the plan and tests are drawn from a sharp description of intended behavior. It is not a draft: it is what the build must make true. At TEACH / plan close the same doc is **validated, not re-authored** — PROVE checks the shipped thing against it, and any drift is reconciled (fix the doc where reality justifiably diverged, or loop BUILD where the code fell short). Every doc ends true. *(This supersedes the old seed-at-PLAN / refine-at-TEACH pattern: the first write is the real spec, the last touch is validation.)*

**Doc artifacts — all twelve templates, each gated.** Every doc type in `text/docs.md` has a template (`text/templates.md` is the map). The **promise's `derives:` manifest** (`text/<slug>.md` frontmatter) declares which of these the feature spawns; the `docs` skill (`.claude/skills/docs/SKILL.md`) confirms the choice at DESIGN/DOCS — neither forces all twelve. **Four are spine (automatic); eight are conditional (write only if the promise's `derives:` set them true, else skip).** All are written *before* BUILD. Copy the template, never write from scratch. (Corrected 2026-09-22 — this table previously undercounted itself: it said "ten … three spine … seven conditional" while its own rows already totalled four spine, and it never listed `lifecycle`/`walk` at all, despite both being real `derives:` keys `template-feature.md` has always declared.)

| Doc | Template | Stop | Write when (else skip) |
|---|---|---|---|
| `<slug>.md` | `template-feature.md` | PROMISE | **spine** — FEATURE/SCHEMA (PATCH/FIX skip) |
| `<slug>-plan.md` | `template-plan.md` | DESIGN | **spine** — FEATURE/SCHEMA |
| `<slug>-features.md` | `template-features.md` | DESIGN | scope spans ≥3 capabilities, or a non-goal boundary must be pinned |
| `<slug>-ui.md` | `template-ui.md` | DESIGN | the feature ships ≥1 user-visible surface (component/page) |
| `<slug>-docs.md` | `template-teach.md` | **DOCS** (spec) → TEACH (validate) | **spine** — FEATURE/SCHEMA |
| `<slug>-tutorial.md` | `template-tutorial.md` | **DOCS** | there's a first-success worth its own page |
| `<slug>-how-to.md` | `template-how-to.md` | **DOCS** | ≥2 distinct recurring tasks users will repeat |
| `<slug>-reference.md` | `template-reference.md` | **DOCS** | the spec (signals/fields/limits) is too detailed for `-docs.md` |
| `<slug>-agents-docs.md` | `template-agents-docs.md` | **DOCS** | agents call this feature's receivers/signals |
| `<slug>-lifecycle.md` | `template-lifecycle.md` | **DOCS** | `world:` names lifecycle stages, workflow steps, or ≥2 surfaces (default `true`) |
| `<slug>-humans.md` + `<slug>-agents.md` | `template-humans.md` + `template-agents.md` | **DOCS** → run by `do-walk.sh` at PROVE | `ui:` is true or any route ships (default `true`) |
| *(build)* `tests/<slug>.test.ts` | `template-tests.md` | **TEST** (pre-BUILD) | **spine** — one assertion per documented observable |

**Not in this table, and not a fan-out artifact:** `template-feature.md`'s optional `story: seven_beats:` frontmatter block. It's written *inside* the promise at PROMISE, not spawned as a separate file — the condensed, commercial-register telling, distinct from `template-story.md`'s standalone book-register form (`text/templates.md § A promise's story: field vs a standalone story`). When present, `cast`/`turn` should seed `-lifecycle.md`'s audience list and stage-transition rows directly — the two should read as the same journey, elaborated, not two accounts.

The split rule: `-docs.md` stays the single complete guide until it would balloon; when it does, the `docs` skill pulls the first-run into `-tutorial.md`, recurring tasks into `-how-to.md`, and the exhaustive spec into `-reference.md`, leaving `-docs.md` as explanation that links out. W4 doc-sync verifies whichever files the `docs` skill chose to write — a chosen doc that's missing or stale (or untrue against the shipped behavior) fails the gate.

The two `↳` rows are **gates, not artifacts**: CLARIFY edits the plan in place (FEATURE/SCHEMA only); ANALYZE is read-only and blocks only on CRITICAL. Each real stop closes by leaving **one durable artifact on disk** — that artifact is the skip-check next time.

**PROMISE first — the genesis contract (for FEATURE/SCHEMA).** The promise (`text/<slug>.md`) is the **first file and the genesis of the feature**: a contract of what will be made — read like the statement of work an engineering agency signs with a client. Everything below it on the spine — `-plan`, `-todo`, `-docs`, tests, code — is **derived from it and reconciles upward to it**. Four frontmatter fields make this mechanical (`text/template-feature.md`):
- **`deliverables:`** — the **schedule of work**, enumerated and exhaustive: every item the client receives, each with its own `accept:` check. Not on the schedule = not promised (it goes in the promise's "Out of scope" section, in writing); on the schedule = ships or the whole promise settles broken. Acceptance is indivisible — no partial credit. `assumes:` alongside it lists client-side dependencies, each green at the making (a failing assumption means the contract can't be signed yet).
- **`proof:`** — the acceptance test that settles the contract: **derived, not authored** — the `&&`-join of every deliverable's `accept:`, verbatim, so the one observable is exhaustive *by construction*. It *becomes* the todo's `outcome:`, the TEST assertion, and the PROVE oracle — named once here, never restated loosely. The schedule ⇄ proof law is enforced by `.claude/scripts/do-promise-lint.sh <slug> --red` (zero LLM — the PROMISE gate, and `/do` always passes `--red`): every `accept:` must appear inside `proof:`, every item must carry an `accept:`, every assumption must hold, and `proof:` must exit NON-ZERO right now — a proof already green at PROMISE has either already shipped (skip) or is too weak to gate (rewrite). A promise with no `deliverables:` block **fails closed** (exit 1); it is no longer grandfathered.
- **`derives:`** — the manifest of which artifacts this promise spawns. `/do` reads it to know which conditional stops to backfill (instead of re-deciding at DESIGN); the tier prune still applies on top.
- **`world:`** — the manifest of runtime the kept promise puts into the substrate: lifecycle moves (+ the signal that records each), workflow steps (the locked kinds), agents (+ their `subscribes:` tags), skills, the tag's own **code** surfaces, task tags, tracking marks/warns, routing paths. At DESIGN/PLAN, `/do` presence-checks every entry the same way it checks an artifact — **missing agent → a `template-agent.md` cycle (+ `subscriptions:register` for its tags) · missing skill → `/skill-creator` · missing workflow/lifecycle stage → a cycle in the todo · present → skip**. The `code:` sub-block is the one kind checked MECHANICALLY rather than by reading — it names `ts`/`astro`/`tql`/`panel`/`command` paths relative to the repo root, and `bash .claude/scripts/do-world-check.sh <slug>` answers missing/present for each under the same rule (exit 1 on a declared path that does not exist). PROVE reads `tracking.marks` as production observables alongside the docs; the `routing:` paths are where cycle composites and run-time outcomes land, so the ranker routes the next wave toward what worked. The fan-out builds exactly what the promise names — nothing more.

**Contract-backed promises mint on-chain.** When the promise carries an uncommented `contract:` block (`text/template-feature.md`'s optional on-chain block), PROMISE also runs `bun pay/tools/promise-chain.ts mint <slug>` — it submits the generated `create_promise` with `terms_hash = sha256(text/<slug>.md)` and writes `object_id` + `maker` back into the frontmatter. Unarmed (no signer) → clean exit 2, the promise stays off-chain-only until minted. At close, `do-promise-settle.sh` settles **both halves** from the one proof exit code.

The promise is the **genesis + root oracle**; it **composes with** docs-first, it does not replace it — `text/<slug>-docs.md` (authored at DOCS) is the derived, detailed oracle that *elaborates* the promise, and PROVE checks the shipped thing against **both**. Everything reconciles upward: a doc claim that contradicts the promise is a bug in the doc. If you can't state what the user gets, halt — the idea isn't ready to build. PATCH/FIX have no promise to keep, so they skip it. Design + Sui sketch: `text/promise-plan.md`.

**Before BUILD — EQUIP (skill-check).** Infer skills from the task tags → `ls .claude/skills/{name}/` → **ready** (proceed) / **stale** (warn, proceed) / **missing** (offer to add). Block only if a required skill is missing.

**Checkboxes — the file is the progress bar.** Every actionable item is a `[ ]`, and `/do` flips it to `[x]` the **moment** that action finishes — never batched at the end, never "I'll tick them next time." A user reading the todo mid-run sees exactly where the fan-out is.

| When | Ticked by |
|---|---|
| a W1 recon agent returns findings for a file | `/do` after the agent settles |
| a W2 verdict / diff spec / doc-plan resolves | `/do` after the spawned W2 agent settles |
| a W3 edit agent reports success on a file | `/do` after the agent settles |
| a W4 check passes (verify · demo · RECONCILES · rubric · ratchet) | `/do` after the bash exits 0 |
| all of a wave's items are `[x]` | the wave header (derived) |
| all 4 waves `[x]` | the cycle header (derived) |
| all cycles in a batch `[x]` | the batch header (derived) |

Forward-only — a `[x]` is never un-ticked except by `/do --wave N --redo`. If an action has no checkbox, it isn't tracked, and untracked work is the loudest smell. Full granularity table in `text/template-todo.md`.

After the spine: **LEARN / close** — validate `text/<slug>-docs.md` against the shipped behavior (the doc was authored at DOCS as the spec; close is where every documented observable is confirmed true and any drift reconciled — no plan closes with a doc that lies about what shipped); write one `learnings.md` entry (slug, tier, composite, deliverable, proof line), emit `signal("cost:cycle", {tokens, model, composite})` and `signal("world:do-event", { type:"learn", slug, tier, cycle, composite, deliverable, tags:["do:learn","do:cycle","tier:"+tier,"slug:"+slug] })`, delete `.w3-receipts.json`, write `.do-trust.json {level, consecutive, composite}` (in a worktree loop, `do-auto.sh` syncs trust + improvements back to the main tree every iteration — state never strands), and append `.w4-improvements.json` (an open item recurring in 3+ consecutive cycles = systemic gap → emit `substrate:systemic-gap`; next W1 reads it as a mandatory recon target).

**Plan-outcome kill-switch (zero LLM).** The switch must be **armed before it can fire**: at PLAN close (before the first BUILD cycle), run the `outcome:` command once and require a **non-zero exit**. Exit 0 at plan start means either the goal is already met (close the plan, build nothing) or the outcome is too weak to gate anything (rewrite it before any cycle runs) — red before green, at plan level. Then re-run the command every cycle close. Exit 0 → the goal is met: remaining cycles enter justify-or-drop (default drop), `--auto` halts. Over the tier ceiling → `warn` + justify. Weak rubric 3× → halt, the *plan* is wrong, not the code.

**Correct-course — mid-plan triage, tier-sized.** When reality diverges from the plan mid-loop — goal-drift (outcome fails 3× with green rubrics), a W3 anchor-miss that survives the autonomous re-plan-once, or INVESTIGATE surfacing a wider blast radius than the plan assumed — size the *correction*, not the feature, with the same tier lens Step 1 already uses:
- **PATCH-sized** (a wrong assumption in one cycle, no scope change) → fix inline in the current cycle; append one line to the todo's `## Correct-course` log; continue the loop.
- **FIX-sized** (a cycle's tasks/deliverables need adding, splitting, or dropping, but the promise still holds) → reopen PLAN: edit `text/<slug>-todo.md` cycles in place, append a `## Correct-course: <date>` block (old → new, one-line rationale, which cycle triggered it), re-run `do-analyze.sh` (the ANALYZE gate), resume the loop.
- **FEATURE-sized** (a `deliverables:`/`assumes:` entry in the promise no longer holds, or the goal itself must change) → reopen DESIGN (and PROMISE, if the schedule of work changed): append the same `## Correct-course` block, re-derive PLAN from it, `do-promise-lint.sh` re-checks the schedule⇄proof law before the loop resumes.

The block is the only new artifact — appended to the todo/plan already on disk, never a separate document. `--autonomous` treats a FEATURE-sized correction the same as CLARIFY: park, don't guess.

**One command, complexity-sized.** `/do <anything>` is the only thing a human types — an idea, a slug, or a `text/<slug>-todo.md` path. The tier sizes the work and the spine prunes itself: a typo is edited and verified inline (one cycle, no loop); a feature writes its promise, plan, todo, tests, and docs and then runs every cycle. The human never picks the mode, never types a flag, never runs a second command.

**Multi-cycle plans no longer need a subprocess loop — the factory already
loops.** (Corrected 2026-09-22, same change as Step 3.) `do-auto.sh`'s whole
reason to exist was spawning a fresh `/do <slug> --next-cycle` per cycle so
W1→W4 context never accumulated. `factory-executor`'s own round loop
(`for (let round = 0; round * width < tasks.length; round++)`,
`.claude/workflows/factory-executor.js`) already does this natively — each
round is a fresh Build spawn, per cycle, at the measured width — so once a
plan's cycles are mirrored onto the board (Step 3), there is nothing left
for `do-auto.sh`'s loop to do that the factory doesn't already do. Land the
worktree question the same way: the factory builds each cycle in its own
worktree with a preview URL already; no second worktree convention needed.

`do-auto.sh` and its `.do-trust.json`/`.w4-improvements.json`/`--gc` state
are **historical** — describe the retired loop, not removed from disk this
turn (`we can delete anything do` is the standing authorization; the actual
deletion is a separate, smaller cleanup, not done blind inside this edit).

This compounds with the deterministic W1 and W4 above: a 6-cycle run with context isolation, `do-recon-pack.sh` and `do-w4-gates.sh` pays two agent prompts per cycle instead of five.

---

## Step 3 — BUILD (the factory)

Runs only when the spine reaches `BUILD`. **BUILD is the factory. There is no
second engine.** (Corrected 2026-09-22 — this step used to run its own W0→W4
wave loop; superseded, not merely paralleled, by `factory-executor`, proven
twice — `course-pack`, `learning`.)

1. **Mirror the plan's cycles onto the board** — one anchor task
   (`tasks:create`), one child per cycle (`tasks_bulk` with `ref`/`blockedBy`,
   matching `batches:`'s DAG). `text/template-todo.md`'s rule: a cycle's
   `Deliverable:`/`Cycle outcome:` are the promise's `item:`/`accept:`,
   quoted verbatim, not paraphrased.
2. **Verify the edges landed** — read `tasks:everywhere`'s `claimable`/
   `blockedBy` fields back directly (curl the receiver with the board's
   gateway key, not the MCP tool — see `channels/src/tools/…` for why). A
   write receipt alone (`write_failed`/`may-have-landed`) is not proof.
3. **Measure width, never guess it** — `bash .claude/scripts/factory-width.sh`.
4. **Launch**: `Workflow({name:"factory-executor", args:{tag:"<cycle tag>",
   width:<measured>, base:"dev"}})`. Ready → Claim → Build (Opus, its own
   worktree, a preview URL) → Review (refutation) → Prove
   (`factory-walk.sh`) → Close (lane/verdict appended to the task) — per
   cycle, in rounds of the measured width.
5. **A single invocation only claims what's ready at launch.** Cycles that
   were blocked at launch time need a fresh invocation once their blocker
   closes — not a resume of the first one.

Coordinate the humans directing this the way `text/learning-lifecycle.md`'s
Operator journey does: a `meeting` (chairman-hosted) for a big, cross-cutting
batch; a small-team meeting for a mid-sized one; a plain task chain
(`tasks:depend`, no meeting) when it's just a few rows in sequence. Scale the
coordination to the batch, not the other way round.

## Definition of done (tier-scaled — `/do` ticks these automatically)

| # | Done means | Gate |
|---|---|---|
| 1 | The agreed goal is met | RUBRIC goal-fit |
| 2 | Docs written first (the spec) + a test per documented observable | DOCS + TEST (both pre-BUILD) |
| 3 | No regression — ratchet held, `must_not_break` preserved | RECONCILES |
| 4 | Proven live, reachable, **every documented observable is true** + matches the promise | PROVE (docs as oracle + `.w2-surface-checklist.json`) |
| 5 | **Routes registered in navigation + nav links wired** | W3 (navigation layer) + W4 (checklist verify) |
| 6 | **Inbound links added from related pages** | W3 (inbound links layer) + W4 (checklist verify) |
| 7 | **SDK/MCP/CLI exports completed** | W3 (SDK layer) + W4 (checklist verify) |
| 8 | **All UI states rendered** (empty, loading, error, edit) | W3 (states layer) + W4 (checklist verify) |
| 9 | Docs true — no stale name, no dead link, no claim the shipped thing doesn't honor | DOCS (authored) + W4 (docs reconcile vs shipped) |
| 10 | Surfaces wired into navigation, not orphaned | W4 (RECONCILES Navigation) |
| 11 | Rubric clears the bar | RUBRIC |
| 12 | Loop closed — result + learning recorded | LEARN |

PATCH clears {1, 3, 11, 12}. FIX clears {1, 2, 3, 4, 11, 12}. FEATURE clears all twelve. Same bar, scaled to the work.

---

## Non-negotiable rules

- **Never skip W2.** Understanding is not delegable — spawn the single Opus `w2-decide` agent; never inline it, never fan it.
- **Default to parallel.** Spawn W1, **W2**, W3, and W4-rubric agents — across cycles in a batch, not just within one. W2 is in the spawn list; the conductor runs Sonnet. An arrow exists only when you can name the file one cycle writes and the next reads; reject every imaginary blocker.
- **Tick the moment it lands.** Flip `[ ]`→`[x]` as each agent/check settles — never batch at the end. The file is the progress bar.
- **PROMISE before code (FEATURE/SCHEMA)** — no feature ships without a stated promise. PATCH/FIX skip PROMISE by design.
- **Docs-first, validated last.** The doc set (`text/<slug>-docs.md` + conditional types) is authored at **DOCS, before BUILD**, as the real spec — never as a sketch. Tests are written from those docs at **TEST, before BUILD**. PROVE validates the shipped thing against the docs; close reconciles any drift so every doc ends true. No plan closes with a doc that lies about what shipped.
- **W2 outputs surface checklist.** Every new route/page/component must have nav_entry, inbound_links, and ui_states declared before W3 runs. Missing any = W4 fails. This is what `.w2-surface-checklist.json` is for — no surprises in W3.
- **W3 builds surfaces in order.** Code → docs → navigation → inbound links → UI states. All in W3a (parallel), not W3b. Docs are parallel to code, navigation is mandatory (not optional). If checklist says nav_entry, W3 wires it.
- **W4 verifies surface layers.** No declared surface is unconfirmed: every inbound link created, every UI state rendered, every SDK/MCP/CLI export done, every doc updated — `do-w4-gates.sh`'s `surface-wiring` gate (:161-191) is what says no. **`nav_entry` is NOT among them**: its wiring grep read a route table `src/lib/navigation.ts` does not contain, so it could only go red, and rung A6 deleted it rather than port it. nav_entry is still DECLARED and still gated by `surface-checklist`; it is no longer claimed to be grepped. Every inbound link created. Every UI state rendered. Every SDK/MCP/CLI export done. Every doc updated. These are hard gates, not aspirational.
- **Security findings sweep the whole cycle, not one file.** When a security gap (IDOR, SSRF, auth bypass, injection) is found or fixed, extract the pattern and grep it across the entire cycle diff — every sibling instance is fixed in the same wave, or the cycle does not close. `do-reconcile.sh authority` enforces the IDOR case deterministically per GATEWAY file (slug/workspace-from-request must use `authorizeWorkspace()`). A finding patched in one file but shipped in a sibling created the same cycle is an open vulnerability.
- **Closed loop** — every cycle ends in `mark`/`warn`, never a silent return.
- **Cheapest tool that decides wins** — a phase that needs no LLM call is the best kind.
- **Arm the kill-switch.** The plan `outcome:` command must exit non-zero at PLAN close, before the first cycle. An outcome that passes before the work starts gates nothing.
- **Correct-course, don't silently absorb.** A discovery that widens blast radius, breaks a promise assumption, or drifts the goal gets sized (PATCH/FIX/FEATURE) and logged in a `## Correct-course` block on the todo/plan — never quietly folded into the current cycle's diff unremarked.
- **W4 max 3 loops**, then halt and report.
- **One command.** A human types `/do <anything>` and nothing else. Complexity sizing, spine pruning, and (for multi-cycle plans) the context-isolated loop are all automatic — never a flag, never a second command.
- **Every cycle gets a fresh context.** A multi-cycle `/do` runs each cycle in a clean subprocess via the internal loop. Prior-cycle conversation is noise; the todo checkboxes are the only state that carries forward.
- **Coherence ratchet is a hard gate.** Every write must leave types / names / primitives / schema / surfaces / docs equal or more coherent than before. The ratchet can tighten; it can never loosen.

---

## Available to /do — the toolbox

**Scripts** (`.claude/scripts/`): `do-auto.sh` (*internal* — the context-isolated, worktree-isolated loop `/do` drives for multi-cycle plans; builds on branch `do/<slug>`, merges to trunk only on a human's say-so; writes a zero-LLM merge digest (`.do-digest.md`) at plan-complete so the human merges informed, not blind; conductor pinned `--model sonnet`; syncs trust/improvements back to main tree every iteration; `--gc` sweeps merged worktrees; **`--setup-only` cuts+links the worktree and prints its path then exits — the seam the inline single-cycle/PATCH/FIX path uses to build in a worktree without the subprocess loop**) · `do-tier.sh` (tier + pruned spine + classifier + ceiling) · `do-folder.sh` (folder-aware verify/build) · `do-survey.sh` (reuse verdict) · `do-reconcile.sh <canon>` (**one predicate over 7 canons** — `substrate|dictionary|authority|sdk|design|navigation|types` — subsumes the old RECONCILE, COMPRESS, PROMISE-CHECK, DOC-SYNC gates; `navigation` branch enforces surface reachability; `--self-test` drives fixtures) · `do-analyze.sh` (deliverable↔cycle coverage gate) · `do-prove.sh` (surface-detect proof — pure PROVE, promise-check moved into `do-reconcile.sh design`; **landing rule** — a `--route` counts as proven only if the run ended on the path requested, so a signed-out `/u/<slug>/*` bouncing to `/signin` fails instead of scoring the sign-in page green; acquires a dev session itself against a localhost base, `PROVE_SESSION_COOKIE` overrides) · `do-promise-settle.sh <slug> [--composite 0.NN]` (zero-LLM promise settle at close — re-runs the promise's `proof:`; kept → `mark` on `promise:<slug>→proof` + `world:announce`, broken → `warn`, no observable → dissolved; `--self-test` drives kept/broken/dissolved fixtures; thesis `text/marketplace.md`) · `do-smoke.sh` (deterministic outcome — drives ≥1 fixture per canon branch + orphan/reachable nav fixtures) · `w1-recon.ts` (prompt-cached recon) · `w4-rubric.ts` (cached parallel rubric).

**Workflows** (`.claude/workflows/`): `one-loop.js` (`/do turn` — one wavefront company turn; phase-pinned model ladder Sense=haiku · Pick=opus/fable-on-anomaly · Execute=pick-assigned per move · Verify=haiku skeptics · Close=sonnet; contract `text/one-loop.md`, log `text/loop-log.md`, state `text/loop-state.json`) · `do-engine` (per-wave model+effort plan runner, `text/do-engine-plan.md`).

**Templates**: `text/template-feature.md` (promise/PROMISE — uncomment its `contract:` block for a contract-backed promise that mints on-chain, worked example `text/playbook.md`) · `text/template-plan.md` (design + pre-mortem + decisions/DESIGN) · `text/template-todo.md` (plan + parallel budget + testing policy/PLAN) · `text/template-agent.md` (agent definition/BUILD).

**Agents**: `w1-recon` · `w2-decide` (spawned single Opus; carries the full W2 contract — compress check, Interface Contract pin, maximal batch DAG) · `w3-edit` · `w4-verify` · `Explore` · `Plan` · `pr-review-toolkit:*` (code-reviewer, silent-failure-hunter, type-design-analyzer, pr-test-analyzer, code-simplifier) · `find-bugs`.

**Skills** (per-stage routing in `text/templates-plan.md`): PROMISE → `docs`, `writer`, `copywriting` · DESIGN → `docs`, `typedb`, `signal`, `frontend-design` (if UI) · BUILD → `astro`, `react19`, `shadcn`, `ai-ui`, `reactflow`, `puck` (page-shaped deliverables route through the Puck page editor / views registry — `one.ie/web/src/lib/views/registry.ts` — not hand-rolled pages), `ai-sdk`, `sdk`, `mcp`, `cli`, `hono`, `cloudflare`, `wrangler`, `durable-objects` · TEST → `vitest`, `playwright-best-practices`, `webapp-testing` · VERIFY → `accessibility`, `find-bugs`, `perf`, `typecheck` · TEACH → `docs`, `writer`.

**Skill-per-layer routing (W3 surface build order):** schema → `typedb` · types → `sdk` · API route → `ai-sdk` · receiver/SDK → `sdk` · MCP tool → `mcp` · CLI verb → `cli` · component/page → `react19` + `shadcn` · docs → `writer`. W3 loads the layer's skill before editing; missing/stale (>30d) → `/skill-creator` first (contract: `text/skill-invocation.md`).

**State files** (write-once, read-by-path — compaction-proof): `.w2-spec.json` · `.w2-doc-plan.json` · `.w3-receipts.json` · `.do-trust.json` · `.w4-improvements.json`.

---

*`/do` is `select()` made executable: idea in, proven feature out — each completed cycle marks what worked, warns what didn't, and writes the result back into the substrate. The world builds itself.*
