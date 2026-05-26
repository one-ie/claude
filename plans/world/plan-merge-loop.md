---
title: Build the merge-loop (the machine that imports the world into one.ie)
slug: merge-loop
goal: Stand up the deterministic-first merge loop so any old repo can be safely mined into one.ie with measurable trunk improvement on every cycle.
group: ONE
cycles: 7
route_hints:
  primary: [merge-loop, infrastructure, deterministic, ratchet]
  secondary: [donal, translate, gem, compress, secrets]
rubric: code
rubric_weights:
  security: 0.30
  stability: 0.25
  ratchet: 0.20
  simplicity: 0.15
  speed: 0.10
split_tests:
  - cycle: 3
    wave: W2
    variants: 2
    dimension: "translate.md authoring strategy: Haiku-scaffold from imports vs Opus-author from a one-screen design brief"
  - cycle: 4
    wave: W3
    variants: 2
    dimension: "AST rewrite engine: ts-morph vs jscodeshift"
escape:
  condition: "C2 PORT fails to round-trip a single Donal agent within rubric ≥ 0.65"
  action: "emit merge-loop:halt:port-failed; stop building; re-scope features.md generation before retrying"
downstream:
  capability: merge-loop:run
  price: null
  scope: private
source_of_truth:
  - merge-loop.md
  - merge.md
  - one.ie/one/100-lines.md
  - one.ie/one/dictionary.md
  - one.ie/src/schema/one.tql
  - one.ie/.claude/commands/do.md
  - one.ie/one/template-plan.md
context_triggers:
  - pattern: "translate\\.md|host_primitives|ui_primitives"
    inject: merge-loop.md § Stage 0
  - pattern: "ratchet|delta_loc|cloc"
    inject: merge-loop.md § Stage 5
  - pattern: "gem|extract"
    inject: merge-loop.md § Stage 1
  - pattern: "compress|orphan|ts-prune"
    inject: merge-loop.md § Stage 6
mode: full
lifecycle: construction
show: true
lifecycle_show:
  C1:
    customer: "Anyone can point the loop at a repo and see what it claims to contain, without spending tokens on slop."
    agent: "An agent generates features.md for an unknown source and blocks anything that smells like a secret."
    unlocks_stage: "scope"
  C2:
    customer: "Donal's agents and skills land in one.ie with zero hand-editing and full provenance."
    agent: "Agents can be ported in bulk from any source repo via a per-source schema map."
    unlocks_stage: "port"
  C3:
    customer: "Every recurring source has a one-page translation contract that humans review once, not per file."
    agent: "Agents reuse translate.md across cycles, so cycle 50 spends ~0 tokens on translation deciding."
    unlocks_stage: "translate-contract"
  C4:
    customer: "A beautiful component built on the wrong theme becomes a trunk-native component in minutes, behavior intact."
    agent: "AST rewrite + translate.md substitutes 90%+ of TRANSLATE work mechanically; Sonnet handles only stitches."
    unlocks_stage: "translate-engine"
  C5:
    customer: "Every cycle reports trunk_delta: LOC, tests, build_ms, bundle, tsc_errors — green or red, no vibes."
    agent: "Agents fail a cycle that bloats trunk, even if the landed code looks clean in isolation."
    unlocks_stage: "ratchet"
  C6:
    customer: "Merges leave trunk smaller than they started, because the cycle prunes what the new code makes obsolete."
    agent: "Compress sweep flags orphaned exports + new duplicates + dead branches and removes them in the same cycle."
    unlocks_stage: "compress"
  C7:
    customer: "Type /merge donal and watch trunk absorb the gems — alias resolution, auto-clone, interactive intent scaffold, the whole thing."
    agent: "The orchestrator owns G0/G1, trust budget, dry-run, --explain, SYNTHESIZE guardrail, source registry, and the one-screen UX. The loop is real and feels like one command."
    unlocks_stage: "orchestrator"
classifier:
  spec_locked: yes — merge-loop.md v0.2 + merge.md + 100-lines.md cited per cycle
  variance_known: no — translate.md authoring strategy + AST engine choice are split-tested (see split_tests)
  exit_scalar: yes — per cycle: rubric ≥ 0.65 + behavior_preserves green + ratchet pass; full plan: orchestrator runs end-to-end on Donal repo
  files_known: yes — every cycle below names its file targets
status: COMPLETE
---

## 1 — Vision

Tony has thousands of files of beautiful work scattered across dozens of repos — Donal's marketing brain, old design systems, half-finished editors, agents written before the schema settled. This plan builds the machine that absorbs the best of it into `one.ie/` deterministically, with every cycle making trunk smaller, faster, more tested. After seven cycles the merge loop is real, validated on Donal's repo, and ready to run thousands of times.

---

## 2 — Closed loop

```
human ─/do merge-loop --source X──► classifier
                                        │
                                        ▼
                       ┌─── DECLARE (features.md, intent.md, translate.md) ───┐
                       │                                                       │
                       ▼                                                       │
                      G0  (auto if trusted, human first cycle on source)       │
                       │                                                       │
                       ▼                                                       │
                CLASSIFY ─►  DEDUPE  ─►  FIT  ─►  LAND  ─►  LEARN  ─►  COMPRESS
                       │       │           │       │         │            │
                    pheromone marks/warns on every transition;            │
                    `merge:source` / `merge:feature` / `merge:dedupe:L#`  │
                                                                          ▼
                                                                         G1
                                                                          │
                                                            fast-forward to trunk
                                                                          │
                                                          mark(merge:landed × ratchet)
                                                          warn on reject; feed next cycle
```

---

## 3 — Fronts

| Front | Tags | Rubric tilt | Director picks up (inferred) |
|---|---|---|---|
| **scope** | [classify, secrets, features-manifest, intent] | 0.30/0.30/0.20/0.15/0.05 (security-heavy) | recon specialist |
| **port** | [port, schema-map, agent-md, donal] | 0.25/0.25/0.30/0.15/0.05 (ratchet-heavy — should net-deduct) | substrate-schema specialist |
| **translate** | [translate-md, ast-rewrite, ui-primitives, host-primitives] | 0.25/0.30/0.20/0.20/0.05 (stability + simplicity) | code-translation specialist |
| **measure** | [ratchet, cloc, ts-prune, compress, behavior-tests] | 0.20/0.25/0.30/0.15/0.10 (ratchet primary) | observability specialist |
| **orchestrate** | [gates, trust, dry-run, do-command] | 0.30/0.25/0.15/0.15/0.15 (security + UX) | command specialist |

---

## 4 — Cycle map

| # | Front | Mode | Cycle name | Exit scalar | Speed budget |
|---|---|---|---|---|---|
| C1 | scope | full | declare-and-classify | features.md for `donal-marketing/` reviewed clean by Tony; secrets gate blocks an injected `.env` test fixture | < 8 min |
| C2 | port | lean | port-donal-agents | ≥ 10 of Donal's agents land in `one.ie/agents/donal/` via deterministic schema-map; ratchet ≤ 0 (net-deduction or wash) | < 12 min |
| C3 | translate | full | translate-md-scaffold | `~/.merge-loop/translations/donal-marketing.md` v0 authored and audited; covers ≥ 80% of host primitives observed in C1 features | < 15 min |
| C4 | translate | full | translate-engine-and-extract | one of Tony's wrong-theme components lands clean (MUI → shadcn) with behavior_preserves green; one `gem` extracted from a slop file | < 25 min |
| C5 | measure | full | ratchet-and-gates | every cycle from C1–C4 retro-reports `ratchet.json`; new cycle on a trivial source proves ratchet blocks a bloat injection | < 10 min |
| C6 | measure | full | compress-on-land | one TRANSLATE feature lands + COMPRESS prunes ≥ 1 orphan + 1 duplicate; final delta_loc ≤ 0 | < 20 min |
| C7 | orchestrate | full | orchestrator-and-ux | `/merge donal` resolves the alias, scaffolds intent if needed, runs the full loop, renders G0+G1 frames; `/merge` (no arg) lists candidate sources; `--dry-run` works | < 40 min |

Total wall-clock budget: < 2h cumulative across cycles. Total token budget: < 50k tokens cumulative (excluding the first features.md generation on Donal repo).

---

## 5 — Cycle 1: declare-and-classify

**Goal.** Stand up the front of the loop: scope manifests + secrets gate + binary CLASSIFY funnel. Validate on Donal's repo.

**Files (W1 recon targets):**
- read: `merge-loop.md § Stage 0`, `merge-loop.md § Stage 1`
- read: Donal's repo root (only top-level + README.md + package.json equivalents) for features.md generation
- write: `one.ie/scripts/merge-loop/declare.ts` (~80 LOC)
- write: `one.ie/scripts/merge-loop/classify.sh` (~50 LOC)
- write: `one.ie/scripts/merge-loop/secrets.regex` (~30 patterns)
- write: `~/.merge-loop/sources/donal-marketing/features.md` (generated artifact)

**W1 — Recon (Haiku × 4, parallel):**
- agent 1: list Donal repo top-level structure + README + package.json
- agent 2: enumerate trunk's existing `one.ie/agents/donal/` (if any) — what's already imported
- agent 3: scan merge-loop.md § Stage 0/1 — confirm the funnel A–D + secrets gate spec is current
- agent 4: list existing `one.ie/scripts/` patterns to match conventions

**W2 — Decide:** features.md generation prompt template (locked, reusable), schema for cached indexes (`.merge/indexes/<trunk_sha>/`), secrets.regex content (30 deterministic patterns covering env vars, key prefixes, PEM headers, JWT signatures), exact CLI surface for `declare.ts`. Document in 5 anchored decisions before W3.

**W3 — Edit (Sonnet × 3, parallel, W3a all independent):**
- agent 1: write `declare.ts` — reads source dir, generates `features.md` via one Haiku call, caches on source_sha
- agent 2: write `classify.sh` — funnel A (noise) + A' (secrets) + B (duplicate via `git hash-object`) + C (reference globs) + D (schema files); residue → list for Haiku
- agent 3: write `secrets.regex` + a test fixture under `one.ie/scripts/merge-loop/__fixtures__/leaked.env` that the gate must block

**W4 — Verify (Haiku × 5, parallel):**
- deterministic: `bun run verify` on touched files + `./classify.sh __fixtures__/donal-mini/` must produce expected verdicts + secrets gate blocks the fixture
- rubric scorers: security (does secrets.regex cover the OWASP cheat-sheet basics?), stability (script handles empty dirs, missing READMEs, BOM-encoded files), simplicity (every line < 100-lines.md justified?), speed (full classify on 10k files < 5s wall), adversarial (any false-positive on legitimate files?)
- behavior preserves: features.md for Donal repo reviewed by Tony as G0 sign-off → cycle closes only after human OK

**Exit:** features.md exists, secrets-gate test passes, classify runs in < 5s on `donal-marketing/`, Tony hits G0 OK.

**Close:** `/close --todo merge-loop --cycle 1` — `mark(merge:source:donal-marketing)` initial, no warns.

---

## 6 — Cycle 2: port-donal-agents

**Goal.** Prove PORT mode end-to-end on Donal's agents. Zero LLM tokens for the conversion itself.

**Files:**
- read: Donal's agent corpus (`donal-marketing/agents/*.md`), `one.ie/src/engine/agent-md.ts` (parse/sync target shape), `one.ie/agents/*.md` (canonical format examples)
- write: `one.ie/scripts/merge-loop/port-agents.ts` (~80 LOC)
- write: `~/.merge-loop/translations/donal-marketing.md` § vocabulary + § schema (partial — just enough for agents)
- write: `one.ie/agents/donal/*.md` (10+ landed agent files)

**W1:** sample 3 of Donal's agents — what fields do they have that we don't? What fields do we have that they don't? Where do tags differ from `dictionary.md`?

**W2:** author the agent-specific subset of `translate.md`. Decide: do unrecognized tags get dropped, mapped, or surface a `dissolved`? (Decision: dropped with a warn — agent author can re-tag if needed.) Lock the field map.

**W3:** write `port-agents.ts` — pure transform, reads source agent.md, applies vocabulary + schema map, writes canonical agent.md. Zero LLM calls per agent. Run it on the corpus; commit one file per agent.

**W4:** ratchet snapshot before/after. Expectation: trunk LOC increases by `landed_agent_loc`, but agents are net additive content (not bloat), so ratchet credits via `from_scratch_loc_estimate` matching landed loc → ratchet ≈ 0.5. Behavior preserves: each ported agent loads via `agent-md.ts` and produces a valid TypeDB sync without error. Adversarial: any agent that round-trips and produces *different* TypeDB output than its source claim → fail.

**Exit:** ≥ 10 agents in `one.ie/agents/donal/`, all round-trip clean via `bun run scripts/sync-agents.ts donal/`, no warns.

**Close:** `mark(merge:source:donal-marketing × depth=cycle2)`, `mark(merge:feature:agent-skills)`, `mark(merge:port:donal-marketing)`.

---

## 7 — Cycle 3: translate-md-scaffold

**Goal.** Produce the boundary translation contract for Donal's full repo — the document that makes every future TRANSLATE cycle from his repos cheap.

**Files:**
- read: every Donal repo file flagged in C1's features.md as TRANSLATE-mode (sample 20 representative files)
- read: `merge-loop.md § Stage 0 / translate.md schema`
- write: `~/.merge-loop/translations/donal-marketing.md` (full — covers vocabulary + schema + host_primitives + ui_primitives + behavior_preserves for the website-editing feature)
- write: `one.ie/scripts/merge-loop/translate-init.ts` (~60 LOC — scaffold a translate.md from a source's imports via one Haiku pass)

**Split test (W2, variants=2):** scaffolding strategy
- variant A: `translate-init.ts` reads all `import` statements + theme references via tree-sitter, groups them, outputs a draft translate.md. Author edits.
- variant B: `translate-init.ts` reads one feature's seed file + one Opus call ("here's the imports, here's our canonical primitives, draft the substitution map"). Author edits.
- both score on (1) author edit-distance to final, (2) coverage of host_primitives observed in W1, (3) token cost. Lower edit-distance + higher coverage + lower tokens wins.

**W3:** spawn winner's implementation; author Donal's actual translate.md using it; capture edits as deltas.

**W4:** verify coverage ≥ 80% of host primitives in the 20 sampled files. Adversarial: scan for substitutions that would silently lose behavior (e.g. a DB call mapped to a no-op). Behavior preserves: at least 3 named behaviors from the website editor are listed.

**Exit:** `donal-marketing.md` v0 exists, ≥ 80% primitive coverage, 0 silent-loss substitutions, Tony reviews and OKs.

**Close:** `mark(merge:translate-contract:donal-marketing)`, `mark(merge:feature:translate-init)`. Split-test winner gets `mark()` on its variant tag.

---

## 8 — Cycle 4: translate-engine-and-extract

**Goal.** Ship the AST rewrite engine that consumes `translate.md`, plus the gem extraction primitive. Validate on one of Tony's wrong-theme components.

**Files:**
- read: a wrong-theme component Tony nominates (e.g. a MUI Card he built years ago)
- read: shadcn equivalent in `one.ie/src/components/ui/`
- write: `one.ie/scripts/merge-loop/ast-rewrite.ts` (~120 LOC, consumes translate.md)
- write: `one.ie/scripts/merge-loop/extract.sh` (~60 LOC, tree-sitter slice for gems)
- write: 1–2 landed components in `one.ie/src/components/imported/` with behavior tests

**Split test (W3, variants=2):** AST engine choice
- variant A: `ts-morph`
- variant B: `jscodeshift`
- both implement the same surface: read `translate.md`, parse target file, apply substitutions, write result. Score on (1) lines of engine code, (2) substitution speed per file, (3) edge-case handling (JSX attrs, sx props, generic types).

**W3 (after split test):** apply winning engine to one of Tony's components. Use `extract.sh` to lift just the component if it's buried in a larger file. Sonnet stitches boundaries only if substitutions produce type errors. Write Playwright/unit tests covering the component's `behavior_preserves` items.

**W4:** rubric — security (no foreign theme leaks into trunk), stability (tests pass), ratchet (LOC vs `from_scratch_loc_estimate` for this component), simplicity (engine fits in budget). Adversarial: try a component with a substitution rule missing from translate.md — must produce `dissolved:no-translation` cleanly, not a silent half-rewrite.

**Exit:** Tony's component lives in `one.ie/src/components/imported/`, renders correctly, all behavior tests green, ratchet credit consumed against estimate (i.e. cycle's ratchet ≥ 0.5).

**Close:** `mark(merge:translate-engine)`, `mark(merge:feature:gem-extract)`. Split-test winner's tag gets `mark()`.

---

## 9 — Cycle 5: ratchet-and-gates

**Goal.** Make the ratchet rubric dim real and prove it blocks bloat.

**Files:**
- write: `one.ie/scripts/merge-loop/ratchet.sh` (~50 LOC — snapshot + diff)
- write: `one.ie/scripts/merge-loop/gates.sh` (~40 LOC — three deterministic gates from § Stage 5)
- write: `one.ie/scripts/merge-loop/__fixtures__/bloat-injection/` (a deliberately-bad source: legit-looking files that grow trunk by +500 LOC with no test/feature gain)

**W1:** confirm metrics shape (cloc JSON, bun test JSON, build ms parse, stat size, tsc error count) on current trunk.

**W2:** lock ratchet score formula (already in spec); decide threshold (composite dim ≥ 0.45 to pass — empirically tuned next cycle if too tight).

**W3:** implement `ratchet.sh` + `gates.sh`. Retrofit ratchet output into C2 and C4's cycle logs (verify the math against artifacts we already have).

**W4:** verify by running merge-loop end-to-end on the bloat-injection fixture — the cycle MUST fail at W4 with `ratchet < threshold`. If it lands the bloat, the gate is broken. Adversarial: try a fixture that adds LOC but also adds 20 tests covering it — should pass.

**Exit:** ratchet blocks the bloat fixture, passes the well-tested fixture, retrofits cleanly onto C2/C4 logs.

**Close:** `mark(merge:ratchet:enabled)`. From here, every subsequent merge-loop close emits trunk_delta in its signal payload.

---

## 10 — Cycle 6: compress-on-land

**Goal.** Make the prune real. Land a TRANSLATE feature *and* delete what it makes obsolete in the same cycle.

**Files:**
- read: trunk surface for orphan-prone areas (older util files, duplicate components)
- write: `one.ie/scripts/merge-loop/compress.sh` (~60 LOC — three sweeps + prune actions per § Stage 6)
- write: a real merge that triggers prune (TBD at W1; pick a feature from Donal's repo whose landing makes 2-3 existing trunk files obsolete — likely a date-helper, a logger wrapper, or an HTTP retry util)

**W1:** scan trunk for likely-obsolete utilities — those with ≤ 3 importers, written before a newer canonical equivalent. Pair candidates with Donal-side replacements.

**W2:** lock the prune decision: `git rm` automatic for zero-importer orphans; Sonnet edit for in-file dead branches; AST-dup pairs resolved by keeping the canonical-path twin (canonicality decided by import count + path-depth heuristic).

**W3:** spawn the cycle on the chosen feature. LAND completes; COMPRESS runs sweeps; produces prune list; applies prunes; re-snapshots ratchet.

**W4:** verify final `delta_loc ≤ 0` (LOC went down despite landing new feature) AND all `behavior_preserves` for both new feature + pruned-replaced code stay green. Adversarial: try a cycle where the prune sweep flags a file that's actually still in use (false orphan) — must catch via the `bun run verify` step that follows prune.

**Exit:** one real cycle ships with `delta_loc ≤ 0`, behavior preserves green, compress signal emitted with prune count.

**Close:** `mark(merge:compress × prune_count)`. Pheromone records the first net-deletion merge — establishes the highway.

---

## 11 — Cycle 7: orchestrator-and-ux

**Goal.** Wire everything into the real `/merge` command — alias resolution, interactive scaffolding, auto-clone, G0/G1 rendering, trust budget, dry-run, empty-arg discovery — so typing `/merge donal` Just Works end-to-end.

**Target experience (what we're building toward):**

```
$ /merge donal
┌─ resolving "donal" ─── matched ~/.merge-loop/sources/donal.yml ──────┐
│ path: ~/Server/donal-marketing   source_sha: bd14ef2 (47 new files)  │
└──────────────────────────────────────────────────────────────────────┘
[features cached · intent scaffold rendered · 1 keystroke confirms]
G0 — proceed? [Y/n]
[CLASSIFY → DEDUPE → FIT → LAND → LEARN → COMPRESS]
G1 — landed 10, pruned 3, delta_loc +280, rubric 0.78 ✓
Fast-forward to trunk? [Y/n]
```

```
$ /merge                                # no arg = "what would I merge right now?"
┌─ candidates with new work since last cycle ──────────────────────────┐
│ • donal-marketing    47 new files   last:  3 days ago    est: 12 min │
│ • design-experiments  8 new files   last: 10 days ago    est:  6 min │
│ • old-server-stack    2 new files   last:    none        est:  4 min │
└──────────────────────────────────────────────────────────────────────┘
Pick one to start. (Cheapest first; pheromone-weighted.)
```

**Files:**
- write: `one.ie/.claude/commands/merge.md` (the slash command — ~180 LOC, parallels do.md structure)
- write: `one.ie/scripts/merge-loop/index.ts` (~120 LOC — orchestrates the shell scripts + LLM calls, emits signals)
- write: `one.ie/scripts/merge-loop/resolve.ts` (~40 LOC — alias resolution: registry → local search → github URL → exact path)
- write: `one.ie/scripts/merge-loop/scaffold-intent.ts` (~50 LOC — TUI checklist over features.md, captures mode + estimates per feature)
- write: `one.ie/scripts/merge-loop/render-gate.ts` (~60 LOC — renders G0 + G1 frames using the same shape as `/do --show`)
- write: `one.ie/scripts/merge-loop/list-candidates.ts` (~30 LOC — `/merge` empty-arg behavior; reads source registry + pheromone)
- write: `~/.merge-loop/sources/donal.yml` (registry entry: path, alias, last_sync, source_sha)

**W1 — Recon (Haiku × 4, parallel):**
- agent 1: load `one.ie/.claude/commands/do.md` — orchestration patterns (modes, --auto, trust budget, show-frame), capture the conventions C7 must match
- agent 2: scan `merge-loop.md § cheatsheet` + § Stage 0/5/6 — confirm signal grammar, gate render shape, dry-run semantics still match what we're about to build
- agent 3: list any prior `/merge*` or `/import*` slash commands in trunk to avoid name collisions; check `.claude/settings.json` for permission patterns the orchestrator will need
- agent 4: list available TUI options (Ink, prompts, clack, plain stdin) — propose the lightest one that handles the intent-scaffold checklist

**W2 — Decide (locked anchors before W3 spawn):**
1. **Command name + invocation grammar:** `/merge <alias|path|url>` (positional), `/merge` (no arg = list candidates), `--dry-run`, `--explain`, `--auto` (trust required), `--force-human` (bypass trust budget once). Decision: positional arg, no `--source` flag — shorter beats explicit here.
2. **Alias resolution order** (resolve.ts):
   - exact match in `~/.merge-loop/sources/*.yml`
   - if starts with `/`, `./`, `~/` → treat as path
   - if matches `github.com/*/*` or `gh:*/*` → clone to `~/.merge-loop/clones/<repo>/`, register alias
   - otherwise glob: `~/Server/<name>*`, `~/code/<name>*`, `~/<name>*` — single hit wins, multi-hit asks
   - all-miss → ask one question: "where is <name>? (path or URL)"
3. **Intent scaffold UX:** numbered list of features with `[ ]` checkboxes; default state set by auto-proposed mode in features.md; keystrokes `w` (want) / `s` (skip + capture one-line reason) / `u` (undecided) / Enter (accept) / `q` (abort). Result written to `.merge-loop/intent.<cycle>.md`, audited by G0.
4. **Auto-clone safety:** clones go to `~/.merge-loop/clones/`, never adjacent to trunk; private repos require `gh auth status` ok or fail loud; never auto-update an existing clone — explicit `/merge <alias> --pull` does that.
5. **`/merge` empty-arg ranking:** new files since last cycle (cheap-first), tie-break by `merge:source:<name>` pheromone strength descending, cap at 5 candidates, render with est. cost from prior cycles.
6. **Signal grammar:** `merge:resolve:{ok|miss|cloned}`, `merge:cycle:{n}:{start|land|reject|halt}`, `merge:gate:{0|1}:{pass|abort}`, `merge:trust:bootstrap:{first-cycle-forced}`, `merge:source:<alias>:{landed|warned}`.
7. **Trust budget bootstrap:** first cycle on any new source → `force-human` regardless of `/do` trust. Tracked per source in `~/.merge-loop/sources/<alias>.yml::first_landed_at`. Subsequent cycles inherit `/do` trust normally.

**W3 — Edit (Sonnet × 6, parallel; W3a all independent):**
- agent 1: `merge.md` slash command — orchestrates the full pipeline, calls resolve→scaffold→declare→classify→…→G1
- agent 2: `resolve.ts` — alias resolution per W2 decision 2
- agent 3: `scaffold-intent.ts` — TUI checklist per W2 decision 3
- agent 4: `render-gate.ts` — G0 + G1 frames (parallel structure to `/do --show` frame)
- agent 5: `list-candidates.ts` — `/merge` empty-arg per W2 decision 5
- agent 6: `index.ts` — top-level entry point; glues the modules, owns the signal emission per W2 decision 6, enforces the trust bootstrap per W2 decision 7

W3b (sequential after W3a): integration touches — register `donal.yml` in the source registry; add `.claude/settings.json` permission entry for the merge-loop scripts.

**W4 — Verify:**

Deterministic gates:
- `bun run verify` on touched files — biome + tsc + vitest clean
- secrets gate sweeps the diff one more time (W4 invariant of merge-loop.md)
- `merge-loop.md § cheatsheet` examples all execute as specified

Behavior preserves (the load-bearing test list — every one must pass):
1. `/merge donal` (alias known, intent cached) → runs end-to-end without prompting except G0/G1
2. `/merge ~/Server/donal-marketing` (path) → same flow, registers alias on success
3. `/merge github.com/some-org/some-repo` → clones to `~/.merge-loop/clones/`, runs, registers
4. `/merge unknown-name` → asks "where is unknown-name?" exactly once
5. `/merge donal --explain` → prints scope summary + est. cost, exits, zero LLM calls
6. `/merge donal --dry-run` → full loop, no fast-forward; trunk git status unchanged after
7. `/merge` (no arg) → renders candidate list with new-file counts + est. costs
8. First-ever cycle on a new source → `--auto` is ignored and human G0 + G1 are forced regardless of trust level; emits `merge:trust:bootstrap:first-cycle-forced`
9. Intent scaffold: keystrokes w/s/u/Enter/q all produce the documented outcomes; result written to disk before G0
10. Auto-clone refuses if `gh auth` not configured for a private repo; never overwrites an existing clone without `--pull`
11. Signal grammar: every signal in W2 decision 6 fires at least once across the 10 tests above (verified by tailing `signals.jsonl`)

Rubric scorers (Haiku × 5):
- security: alias resolution can't be tricked into running outside `~/.merge-loop/clones/` or a path the user explicitly named; secrets gate still active; trust bootstrap unbypassable on first cycle
- stability: all 11 behavior tests pass on the first run, no flakes on second run
- ratchet: orchestrator code itself ≤ 500 LOC total across all 6 files; if higher, it failed the 100-lines bar
- simplicity: every flag and every keystroke has a one-line justification in `merge.md` (no orphan options)
- speed: `/merge donal --explain` returns in < 1s; `/merge` (list) returns in < 2s; full cycle on `donal-marketing` < 30 min wall
- adversarial: try `/merge ../../../etc/passwd`, `/merge $(rm -rf /)`, `/merge github.com/totally-real/malware` — all must fail safely

**Exit:** all 11 behavior tests pass; `/merge donal --dry-run` against the real Donal repo produces a clean G1 frame; trunk git status unchanged; `signals.jsonl` shows the full grammar exercised.

**Close:** `mark(merge:orchestrator:shipped)`, `mark(merge:ux:shipped)`, `mark(merge:source:donal-marketing × cycle7)`. Pheromone deposit on `merge:command:merge` opens the highway for the command itself.

After C7 closes: typing `/merge <name>` against any source is real. The plan is shipped — but the plan-level close (§ 13) requires one more thing: an actual non-dry-run cycle that fast-forwards a real merge to trunk.

---

## 12 — Per-cycle close protocol

Every cycle:
1. W4 verify gate passes (rubric ≥ 0.65, all 5 dims ≥ floor, ratchet specific to mode, behavior preserves green).
2. `/close --todo merge-loop --cycle N` emits `do:close` with `{cycle, wave:gate, rubric, deltas, llm_tokens}`.
3. Append to `docs/learnings.md`: one line, format per documentation rules.
4. Show frame renders (per `show: true`); auto-continue unless trust=cautious or W4 looped 3×.
5. Pheromone deposits update `merge:*` highways per § 6 of merge-loop.md.

## 13 — Plan-level close

Plan closes when C7 ships *and* `/merge donal` (without `--dry-run`) lands at least one real PORT cycle to trunk with a green ratchet and a clean fast-forward. That single end-to-end run proves the spec is real, not paper.

**Composite plan rubric** (averaged across all 7 cycles): ≥ 0.70. If avg < 0.70 at C7 close, plan transitions to `evolution` lifecycle and a follow-up plan addresses the weakest dim.

## 14 — Risks + escapes

| Risk | Trigger | Escape |
|---|---|---|
| `features.md` generation produces garbage for Donal repo | C1 W4 — Tony rejects features.md at G0 | re-scope: tighten the generation prompt; drop a cycle from the plan if needed |
| PORT round-trip fails on Donal agents | C2 W4 fails | escalate to user (matches plan-level `escape` condition); halt and re-scope translation contract |
| `translate.md` scaffolding produces low-coverage output (both variants) | C3 split-test winner < 80% coverage | manual authoring fallback; defer translate-init.ts to a follow-up |
| AST engine choice is ambiguous (both ts-morph and jscodeshift hit walls) | C4 split-test neither variant ships clean | pick whichever's closer; defer hard cases to Sonnet (worsens token budget but ships) |
| Ratchet too strict — legitimate merges fail | C5 retrofit shows historical cycles would have failed | tune threshold (lower from 0.45 to 0.40) once, then lock |
| Compress sweep deletes something live | C6 W4 verify fails after prune | rollback that commit; tune sweep rules; the gate is already there to catch this |
| Orchestrator dry-run hangs or doesn't render frames | C7 W4 | debug; this is mostly a tool-call shape issue, not a design one |
| TUI library choice fights the terminal (Claude Code CLI quirks) | C7 W3 — scaffold-intent UX breaks | fall back to plain numbered list + stdin; lose color/keys but keep functionality. Polish in a follow-up |
| Alias collides with an existing global command | C7 W1 finds collision | namespace under `/m` or `/m:merge`; never override a built-in |

## 15 — See also

- [`merge-loop.md`](merge-loop.md) — the spec this plan implements (v0.2)
- [`merge.md`](merge.md) — first concrete merge instance; informs the C1 features.md choices
- [`one.ie/.claude/commands/do.md`](one.ie/.claude/commands/do.md) — wave/rubric/trust grammar this plan inherits
- [`one.ie/one/100-lines.md`](one.ie/one/100-lines.md) — the 200-line bar every cycle's simplicity dim is judged against
- [`one.ie/one/template-plan.md`](one.ie/one/template-plan.md) — the v2.1.0 template this plan conforms to
- [`one.ie/docs/dictionary.md`](one.ie/docs/dictionary.md) — vocabulary the translate.md files map *into*
- [`one.ie/src/schema/one.tql`](one.ie/src/schema/one.tql) — the 6 dimensions the schema map maps *into*

---

*Build the machine. Type `/merge donal`. Watch trunk get smaller, faster, and more capable on every cycle.*
