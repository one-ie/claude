# merge-loop.md — one trunk, thousands of merges, zero duplicates *(v0.2)*

**Status: IMPLEMENTED** — `plan-merge-loop.md` C1–C7 shipped 2026-05-13. All pipeline scripts live in `one.ie/scripts/merge-loop/`. Invoke via `/merge <alias|path|url>` or `bun run one.ie/scripts/merge-loop/index.ts <source>`. Source registry at `~/.merge-loop/sources/<alias>.yml`.

**Principle:** every external file is a *signal* against the existing world. The trunk (`one.ie/`) is the only ground truth. Nothing lands without being weighed against the schema, the dictionary, and the code that's already shipped. `mark()` on land, `warn()` on reject, `dissolved` on missing context. The loop compounds — after 100 merges it knows more than it did at merge 1.

**Token discipline (the meta-rule):** at every stage, the cheapest tool that can answer wins. `sha256sum` beats Haiku. `grep` beats Haiku. `cp` beats Sonnet. Haiku beats Opus. Opus is the last resort, only at genuine semantic forks. A merge cycle that ran zero LLM calls is the *best* cycle, not a degenerate one — it means the deterministic layers caught everything.

```
Tool ladder (try in order, stop at first that decides):
  sha256sum / git hash-object   (bit-equal)
  grep -F / comm                (name/string match against dictionary + trunk)
  diff -q / git diff            (line-equal modulo whitespace)
  tree-sitter normalize | sha   (AST-equal)
  Haiku × N parallel             (ambiguous file judgment)
  Opus, main context             (semantic fork, schema reconciliation)
```

This is the meta-loop. [`merge.md`](merge.md) is instance #1 (one-ie → one.ie). Every future merge — a scratch repo, a fork, a generated app, an agent's output — runs through this same machine.

---

## 1. The problem in one paragraph

Code is scattered across dozens of repos: experiments, forks, scratch trees, AI-generated apps, old branches, opensource SDKs we maintain elsewhere. Each has *some* signal — a clean component, a better hook, a sharper schema — buried under noise: dead code, stale deps, renamed concepts, half-finished refactors, things we already have under a different name. Manually merging is slow and produces duplicates. Auto-merging produces sludge. This loop is the third option: deterministic dedupe layers + a rubric gate + pheromone, so every cycle is cheaper and more accurate than the last.

---

## 2. Invariants (every cycle inherits these — non-negotiable)

| # | Invariant | Why |
|---|---|---|
| 1 | **`one.ie/` is the trunk.** Wallets, workers, schema, engine, auth, deploy pipeline never move. External code lands *into* the trunk, never the reverse. | One ground truth. No "which version is canonical" debates. |
| 2 | **`one.tql` + `dictionary.md` are the vocabulary.** Any name not in `dictionary.md` is either added explicitly (with rationale) or renamed at the border. No silent aliases. | Dead names ("knowledge", "scent", "colony-as-dimension") never come back through the side door. |
| 3 | **Schema first, code second.** If the merge would add a 7th dimension or a parallel actor-like entity, it halts for spec reconciliation. The 6 dimensions are locked. | The substrate's stability is its value. |
| 4 | **One file, one home.** Every landed file has exactly one path in `one.ie/`. No `foo.ts` and `foo.v2.ts`. No backup copies. No "old" suffixes. | Duplicates are the failure mode this loop exists to prevent. |
| 5 | **Closed loop — every candidate file resolves.** `landed` / `rejected:reason` / `dissolved:reason` / `out-of-scope`. No "TODO: decide later". The bag is empty at cycle close. | Same rule as `/do`: pheromone only compounds if every branch reports. |
| 5b | **Closed loop — every source feature resolves.** Every id in `features.md` appears in exactly one of `want` / `skip` / `undecided`; every `undecided` is closed by DEDUPE before LAND. | The bag is empty at the *feature* layer too, not just file layer. Intent is auditable end-to-end. |
| 6 | **Rubric ≥ 0.65 to land, exit code green.** The W4 gate from `/do` applies verbatim — security / stability / simplicity / speed. A merge that passes 3 of 4 doesn't land. | Less is more; an "almost clean" merge IS the duplicate problem. |
| 7 | **Reversible at every step.** Each landing is one atomic git commit on a merge branch. Bad call → `git revert` or branch drop. Never amend, never force-push trunk. | Thousands of runs means thousands of chances to be wrong cheaply. |
| 8 | **Every cycle ratchets trunk.** Deterministic deltas (LOC, tests, build_ms, bundle, tsc_errors) are measured before and after LAND. A cycle that grows trunk LOC without compensating gains in tests/features/compression fails the gate. | "Every new line increases speed/stability/succinct" becomes a number, not a vibe. The loop refuses to bloat. |
| 9 | **The 200-line bar.** `one.ie/one/100-lines.md` is loaded as W2 base context in every cycle. Any fit plan with `loc > 50` must include a one-line justification — what does this earn that less couldn't? Empty justification → halt. | The substrate's whole engine + schema is 200 lines. Merged code is held to the same standard or it doesn't land. |
| 10 | **Secrets never land.** Path-pattern + content-regex sweep at CLASSIFY-A'; any hit halts the cycle before tokens spend. Re-run W4 sweep on the diff before G1. | A single leaked key in a "thousands of times" loop is unacceptable. Deterministic, fail-closed. |
| 11 | **First cycle on any source forces human G0 + G1.** Trust budget bypass is disabled until at least one cycle from that source has closed cleanly. | The first run is when authorial intent is least audited. Bootstrap from a human check, then let trust accumulate normally. |

Break any one of these → the loop is producing the slop it was built to prevent. Halt, fix the invariant, resume.

---

## 3. The loop — seven stages, two human gates, one cycle per source repo

```
              ┌─ features.md ─┐    ┌─ intent.md ─┐
DECLARE  →   │  source HAS    │ ⨉ │  we WANT     │  →  G0
   W0        └────────────────┘    └──────────────┘     ↓
                                                       want ∩ has
                                                          ↓
CLASSIFY  →  DEDUPE  →  FIT  →  LAND  →  LEARN  →  COMPRESS  →  G1  →  fast-forward
   W1         W2       W2/3    W3       W4         W5

  base context auto-loaded into W2 (every cycle):
    dictionary.md  ·  one.tql  ·  rubrics.md  ·  100-lines.md  ·  merge.lessons.md
```

Maps onto `/do`'s wave grammar so the same telemetry, the same pheromone, the same rubric apply. One source repo = one `/do` plan (`mode: lean` if small, `mode: full` if it touches schema or > 5 cycles).

**Two human gates, nothing more.** G0 confirms intent before any tokens are spent. G1 confirms landing before trunk moves. Internal cycle gates stay deterministic (rubric ≥ 0.65, the three shell gates in W4). `trust: trusted` (per `/do` opt #8) auto-passes both.

### Stage 0.5 — Three modes, three lanes *(the load-bearing insight)*

A source's distance from trunk decides which lane it runs in. The mode is declared per feature in `intent.md` and dictates tools + token budget.

| Mode | When | What changes | What stays | Tools | Token budget/file |
|---|---|---|---|---|---|
| **PORT** | source already speaks our idioms (e.g. ONE-format agents) — only schema/vocabulary differs | field names, tag vocabulary | structure, semantics, content | `cp` + schema map (deterministic) | ~0 |
| **TRANSLATE** | source has the right shape but wrong host primitives (Donal's website editor; your wrong-theme components) | imports, host calls, theme tokens, prop conventions | structure, behavior, types, state logic | AST rewrite via `translate.md` + Sonnet for boundary stitching | ~2–5k |
| **SYNTHESIZE** | source has the right *idea* but wrong architecture (a monolith we'd build as 3 substrate units) | architecture, decomposition, primitives | concept, behavior, acceptance criteria | Opus reads source as inspiration, writes new trunk-shape impl | ~10k |

**Mode auto-proposed in `features.md`** by counting cross-host imports + theme refs + LOC density. **Mode confirmed in `intent.md`** by author. Disagreement is intentional — author overrides classifier.

**SYNTHESIZE guardrail (hard).** Bypasses the ratchet's LOC bias (we're genuinely re-implementing), so it needs stronger justification. Cap: **max 1 SYNTHESIZE feature per cycle.** Requires a one-page design doc as part of intent and **separate human G0 approval** beyond the standard intent gate. Pheromone: `merge:synthesize:<id>` cumulative — three failed SYNTHESIZE attempts on the same source → halt all SYNTHESIZE from that source until human reset.

**Ratchet credit for TRANSLATE/SYNTHESIZE.** These legitimately add LOC; their baseline isn't zero. Each declares `from_scratch_loc_estimate` in `intent.md`. Ratchet measures `delta_loc - from_scratch_estimate` for translated/synthesized features — credits the source for being inspiration, prevents the rubric from punishing legitimate mining. PORT features still measured against zero baseline (they should net-deduct after compress).

---

### Stage 0 — DECLARE *(three manifests, then G0)*

Top-down scope before bottom-up scan. The manifests are the spec for this cycle; everything downstream is execution against them.

**`<source>/features.md`** — generated once per source, cached, invalidated only on source HEAD change. One Haiku pass reads the source's README, top-level dir tree, and `package.json`/equivalent → emits a structured catalog:

```yaml
---
source: one-ie/one
generated: 2026-05-12
source_sha: abc1234
---

features:
  - id: ai-elements
    files: web/src/components/ai-elements/**
    exports: [Reasoning, Citations, ToolCall, CodeBlock, ...]
    deps: [ai, @ai-sdk/react]
    loc: 4200
    claims: "50+ composable AI UI elements"
  - id: design-tokens
    files: [web/src/styles/tokens.css, web/src/components/design/**]
    exports: []
    deps: []
    loc: 800
    claims: "radix-nova design system"
  # ...
```

Token cost: ~2k per source, **once.** Re-runs are zero unless source HEAD moves.

**`merge.intent.md`** — authored per cycle. Three lists, nothing else:

```yaml
---
source: one-ie/one
cycle: C1
trunk_sha: def5678
---

want:                                  # explicit yes — land these features
  - ai-elements
  - design-tokens

skip:                                  # explicit no — out of scope this cycle
  - sdk-compile                        # we have our own
  - python-sdk                         # wrong language target

undecided:                             # let DEDUPE decide per file
  - chat-orchestrator                  # may overlap with src/components/Chat.tsx
```

Each entry in `want` carries its mode + (if TRANSLATE/SYNTHESIZE) a baseline:

```yaml
want:
  - id: ai-elements
    mode: TRANSLATE                  # uses theme transplant via translate.md § ui_primitives
    from_scratch_loc_estimate: 3500  # ratchet credits this against landed LOC
  - id: agent-skills
    mode: PORT                       # schema-map only; ~0 tokens
  - id: campaign-orchestrator
    mode: SYNTHESIZE                 # 1/cycle cap; separate G0; needs design block below
    from_scratch_loc_estimate: 1200
    design: |
      Decompose the monolith into 3 substrate units:
        - campaign-director (unit)  owns the schedule, fans tasks out
        - asset-resolver (unit)     turns briefs into asset signals
        - publish-gate (unit)       gates final publish via human signal
      Behavior preserved: kickoff → brief → assets → publish chain.
```

Three rules — non-negotiable:
1. **Every feature id in the source's `features.md` MUST appear in exactly one of `want` / `skip` / `undecided`.** No silent omissions. Missing id at G0 → halt.
2. **`skip` is auditable** — every entry has a one-line comment explaining why. Future cycles inherit these reasons via pheromone (`merge:skip:<id>` strength).
3. **`undecided` is bounded** — at most 20% of feature ids. More than that → the intent isn't formed; halt and refine before spending tokens.

**`<source>/translate.md`** — the boundary translation contract. Authored once per source repo, reused across every cycle from that source. Lives at `~/.merge-loop/translations/<source>.md` (synced via the same envelope mechanism as wallets — it's a personal corpus). The centerpiece that makes TRANSLATE actually work:

```yaml
---
source: donal-marketing
trunk: one.ie
last_validated: 2026-05-12
schema_version: 1
---

## vocabulary                                          # term-level renames
campaign      → group(group-type: "campaign")
brief         → task
deliverable   → task(status: complete)
seo-audit     → skill(skill-id: marketing:seo-audit)

## schema                                              # data-shape → 6 dimensions
his.Campaign{name, brand, channels[]}    → group + memberships
his.Brief{title, requirements, due}      → task(name, attrs..., due_at)
his.Asset{url, type, owner}              → signal(data.content) + path(actor→thing)

## host_primitives                                     # the rewires (TRANSLATE engine consumes this)
donalDB.query(sql)              → typedb().query(tql)
donalAuth.user()                → ensureHumanUnit(req)
donalRouter.route(path, fn)     → Astro route file at src/pages/{path}.astro
campaignBus.emit(evt)           → world.signal({receiver, data})

## ui_primitives                                       # theme transplant
@mui/material:Button            → @/components/ui/button (variant ← color prop)
@mui/material:Card              → @/components/ui/card
@chakra-ui/react:Modal          → @/components/ui/dialog
sx={{p: 2, bg: "primary.main"}} → className="p-2 bg-primary"
useTheme().palette.primary      → var(--primary) / Tailwind primary token

## behavior_preserves                                  # acceptance criteria — W4 gates on these
- "autosave fires within 3s of last keystroke"
- "publishing creates a versioned snapshot in trunk's signal log"
- "media picker accepts drag-drop with same MIME filtering"
- "rich-text supports h1-h3, lists, links, code, images"
```

**Why `translate.md` is the leverage point:**
- Authored once per source, *amortized* across every cycle from that source. Cycle 50 needs ~0 new translation work.
- Determinism: AST rewrite engine reads it and applies substitutions mechanically. Sonnet only stitches boundaries the contract didn't cover.
- Diffable: each section is a flat map. Reviewers can audit a single substitution rule without reading code.
- Compounding: missing entries surface as `dissolved:no-translation` rejects, which become PRs against `translate.md` for the next cycle. Each cycle sharpens the contract.

**Rules:**
1. Every TRANSLATE feature requires the source's `translate.md` to cover its primitives. Missing mapping → `dissolved`, no token spend on that file.
2. `behavior_preserves` items become first-class W4 gates: a Playwright/unit test must demonstrate each. No green tests → cycle fails.
3. `translate.md` is versioned (`schema_version`); breaking changes require a cycle to revalidate prior landings (rare, but supported).

**G0 — Intent gate.** Render a one-screen summary: source, cycle, sha, want/skip/undecided counts, est. file count after scope resolution, est. token budget. Human OK (or auto-OK if `trust: trusted`). G0 failure → halt, no tokens spent past the manifest generation.

**Scope resolution (deterministic, zero tokens):** `want` + `undecided` → resolves to file globs via `features.md` → SOURCE_FILES set. CLASSIFY only sees this set. Everything else gets `verdict: out-of-scope` for free. On `one-ie/one` this is ~95% file reduction before Stage 1.

**Lean bypass:** for cycles with ≤ 5 candidate files (e.g. a scratch tree, a single agent's output), `mode: lean` skips manifest generation entirely — falls back to pure bottom-up classify. The classifier in `template-plan.md §0` decides which mode at cycle start.

---

### Stage 1 — CLASSIFY *(shell first, Haiku only for residue)*

**Input:** a path to an external repo (or subtree).
**Output:** every file tagged with one of six verdicts. Most files never touch an LLM.

Run the funnel in this order. Each pass shrinks the input for the next:

```bash
# A. NOISE — pure path/extension match, zero reads
find $SRC -type f \( \
   -name node_modules -prune -o -name .git -prune -o \
   -name '*.lock' -o -name '*.log' -o -name 'dist/*' -o \
   -name '.DS_Store' -o -name '*.map' \) > noise.txt

# A'. SECRETS — hard gate, never lands regardless of mode
# Match: API keys, tokens, JWTs, private keys, .env files, common secret prefixes
find $SRC -type f \( -name '.env*' -o -name '*.pem' -o -name '*.key' \
   -o -name 'id_rsa*' -o -name '*credentials*' \) > secret-paths.txt
grep -rlE \
  '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|AKIA[0-9A-Z]{16}|xox[abp]-|BEGIN [A-Z ]*PRIVATE KEY)' \
  $SRC > secret-contents.txt
cat secret-paths.txt secret-contents.txt | sort -u > secrets.txt
# Any non-empty secrets.txt → halt cycle, no tokens spent, alert author

# B. DUPLICATE — bit-equal hash sweep against trunk
git -C one.ie ls-files | xargs -I{} git hash-object {} > trunk.hashes
find $SRC -type f -exec git hash-object {} \; > src.hashes
comm -12 <(sort trunk.hashes) <(sort src.hashes) > duplicate.txt

# C. REFERENCE — declared in merge-loop.config (e.g. apps/enoki-play/)
grep -lFf reference-globs.txt <(find $SRC -type f) > reference.txt

# D. SCHEMA — extension or path match
find $SRC \( -name '*.tql' -o -name '*.move' -o -name 'dictionary.md' \) > schema.txt
```

After A–D, the remainder is **either `novel`, `overlap`, or `gem`**. One Haiku pass per *remaining* file (parallel, single message) classifies between those three:

```json
{ "path": "...", "verdict": "novel|overlap|gem",
  "anchor": "one.ie/src/...|null",
  "extract": { "start": 42, "end": 89, "symbol": "useFoo" } | null }
```

`gem` is the sub-file extraction path. Use when a beautiful function / hook / type / snippet is buried in a file that's otherwise noise or duplicate. The classifier returns the exact line range to lift. Without this, old slop-repos lose their gems.

| Verdict | Caught by | Cost | Next stage |
|---|---|---|---|
| `secret` | shell glob + regex | 0 tokens | **halt cycle**, no tokens spent |
| `noise` | shell glob | 0 tokens | reject `noise` |
| `duplicate` | hash comm | 0 tokens | reject `duplicate` |
| `reference` | shell grep | 0 tokens | reject `reference-only` |
| `schema` | shell find | 0 tokens | halt, escalate to spec author |
| `novel` | Haiku ternary | ~80 tok | → FIT |
| `overlap` | Haiku ternary | ~80 tok | → DEDUPE |
| `gem` | Haiku ternary | ~120 tok | → FIT with `action: extract` |

**Recon cache (`/do` opt #1) applies on top.** Once a source file's `sha256` is logged as `noise`/`duplicate`/`reference` in `merge-log.jsonl`, future cycles short-circuit to `reject:cached` with one `grep` — zero tokens.

### Stage 2 — DEDUPE *(shell-only; LLM never adjudicates alone)*

For every `overlap` file, walk four layers in order. **All four are deterministic.** First hit decides.

| Layer | Command | If matches |
|---|---|---|
| **L1 — dead name** | `grep -wFf dictionary.dead-names.txt <file>` | → reject `dead-name` |
| **L2 — schema** | `grep -wFf one-tql.idents.txt <file>` then verify intent maps to existing dimension | found + maps → continue; new dimension → halt (invariant #3) |
| **L3 — AST hash** | `tree-sitter parse + normalize + sha256` vs precomputed trunk AST hashes | collision → reject `ast-duplicate` |
| **L4 — exports** | `grep -E '^export' <file>` → signature set → `comm` against trunk signatures index | full subset → reject `behavior-duplicate`; partial → FIT with `extends:` rationale |

Indexes (`dictionary.dead-names.txt`, `one-tql.idents.txt`, `trunk.ast-hashes`, `trunk.exports`) are **built once per cycle by a 10-line make target**, cached by trunk commit sha. Across cycles on the same trunk sha → zero rebuild. All four layers run in well under 100ms per file.

**LLM use in DEDUPE: zero by default.** An LLM is invoked only when L4 produces a *partial* signature match — i.e. the candidate genuinely extends a trunk module and the loop needs a one-sentence "should this extension land?" call. That's one Haiku question per ambiguous file, not per file. The "less is more" gate is *physical* — the dedupe budget literally has no LLM line items unless ambiguity forces one.

### Stage 3 — FIT *(W2 → W3)*

For files surviving DEDUPE, produce a *fit plan* — one block per file, mechanically convertible to a Sonnet edit prompt (`/do` optimization #3):

```
TARGET:    one.ie/src/<canonical-path>     # path chosen to match trunk geography
ANCHOR:    <existing trunk file or "new">  # what this lands next to
ACTION:    create | extend | replace
RENAMES:   { external_name → canonical_name, ... }   # from dictionary.md
IMPORTS:   rewrite @one-ie/* → @/... etc.            # path-alias normalization
DROPS:     [<symbol>, ...]                            # things in candidate that don't belong
RATIONALE: <one sentence — why this earns its place>
```

**Fit rules (enforced before W3 spawn):**
- TARGET path is unique across the merge plan (invariant #4). Conflict → DEDUPE returns to L4.
- RENAMES is exhaustive — any external term not in `dictionary.md` and not renamed → halt for vocabulary decision.
- DROPS is non-empty for any file > 100 lines. If you can't name what to drop, you haven't read it.
- No file lands with > 200 LOC unless `mode: full` and an explicit rationale > 1 sentence. Less is more.

### Stage 4 — LAND *(shell mechanics, LLM only for true edits)*

Most landings are `cp` + `sed`, not an LLM edit. The fit plan tells you which:

| Fit plan signature | Mechanism | Tools |
|---|---|---|
| ACTION=`create`, RENAMES=∅, IMPORTS only need path-alias rewrite | **pure shell** | `cp $src $target && sed -i '' -E -f rename.sed $target` |
| ACTION=`create`, RENAMES present, all 1:1 word-boundary | **pure shell** | `cp` + generated `sed` rules from RENAMES (one `\b<from>\b/<to>/g` per pair) |
| ACTION=`extend`, anchor in existing trunk file, additive only | **pure shell** | `cat $src >> $target` or `awk` block-insert at anchor |
| ACTION=`create|extend` with non-trivial restructure (interleaving, conditional logic) | **one Sonnet Edit** | only this row spawns an agent |
| ACTION=`replace` | **`git mv` + sed**, never Sonnet | path move is deterministic; see "replace-and-remove gate" below |
| ACTION=`extract` (gem path) | **tree-sitter + `sed`** | lift named symbol + its referenced imports + types into a new trunk file |

**Extract mechanism (gem path, deterministic):**

```bash
# 1. Slice the named symbol with its leading comment
tree-sitter parse $src --capture function.definition[name=$symbol] --range > extract.ts

# 2. Resolve its imports — only the ones actually referenced inside the slice
imports=$(tree-sitter parse $src --capture import.statement | filter-by-usage extract.ts)

# 3. Resolve referenced types in the same file → inline or follow
types=$(tree-sitter parse $src --capture type.definition --referenced-by extract.ts)

# 4. Write the new trunk file
{ echo "$imports"; echo "$types"; cat extract.ts; } > $target
```

Sonnet is invoked only if the extracted slice references *non-type* local symbols that don't follow it — i.e. genuine restructure. The common case (a self-contained hook, util, or component) is pure shell. Token cost: ~0 for clean gems, ~1k tok for messy ones.

**Replace-and-remove gate (post-LAND, hard):**

```bash
# Every ACTION=replace must orphan its old path:
for old in $(jq -r '.[] | select(.action=="replace") | .replaced_path' fit-plan.json); do
  grep -rl "from.*${old%.ts}" one.ie/src/ && exit 1   # still has importers → fail
  [[ -f "$old" ]] && exit 1                            # old file still on disk → fail
done
```

A "replacement" that didn't remove is a `created-duplicate` finding with severity 0.9 and rolls back the cycle.

`rename.sed` is auto-generated from the fit plan's RENAMES + a fixed prelude that rewrites `@one-ie/* → @/*`, `@oneie/* → @/*`, and any other canonical aliases. Built once per cycle.

**Commit per file (atomic).** `git add $target && git commit -m "merge(<src>): <path> — <rationale>"`. Rejected files never commit. Bad cycle → `git checkout main && git branch -D merge/...` and the trunk is untouched.

**Token math.** A 50-file cycle where 40 land via shell, 8 via one Sonnet Edit each, 2 via Opus = ~8× Sonnet + ~2× Opus tokens. The other 40 cost zero LLM tokens. Compared to "Sonnet edits everything" baseline: ~80% token reduction, ~5× wall-clock speedup (shell is parallel + cached, LLMs are serialized by rate limits).

### Stage 5 — LEARN *(deterministic ratchet + adversarial Haiku)*

**Ratchet — snapshot trunk before W3, snapshot after, diff:**

```bash
# Snapshot (run before W3 and after W3, diff the two)
{ cloc one.ie/src --json | jq .SUM.code
  bun test --reporter=json 2>/dev/null | jq .numTotalTests
  /usr/bin/time -p bun run build 2>&1 | awk '/real/{print $2*1000}'
  stat -f%z one.ie/dist/_worker.js
  bun run tsc --noEmit 2>&1 | grep -c "error TS"
} > ratchet.{before,after}.json

# Compute deltas
delta_loc        = after.loc - before.loc           # ≤ 0 is GOOD (net deletion)
delta_tests      = after.tests - before.tests       # ≥ 0 is GOOD (more coverage)
delta_build_ms   = after.build - before.build       # ≤ 0 is GOOD (faster)
delta_bundle     = after.bundle - before.bundle     # ≤ 0 is GOOD (smaller)
delta_tsc_errors = after.tsc - before.tsc           # HARD GATE: must be ≤ 0
```

**The new 5-dim rubric** (replaces the old 4-dim):

```
security   0.30   # zero vulns, boundaries validated, no secrets
stability  0.25   # tests pass, zero new type errors, handlers close
ratchet    0.20   # trunk got smaller / faster / more tested — deterministic
simplicity 0.15   # every line earns its place — held against 100-lines.md
speed      0.10   # cycle wall-clock + token spend vs budget

composite ≥ 0.65 AND delta_tsc_errors ≤ 0 AND zero adversarial findings > 0.5
```

`ratchet` dim is computed deterministically from the deltas (no LLM):

```
loc_score    = clip(-delta_loc / max(landed_loc, 1) + 0.5, 0, 1)  # net deletion → 1.0
tests_score  = clip(delta_tests / 10 + 0.5, 0, 1)
build_score  = clip(-delta_build_ms / 1000 + 0.5, 0, 1)
bundle_score = clip(-delta_bundle / 1024 + 0.5, 0, 1)
ratchet      = 0.4·loc + 0.2·tests + 0.2·build + 0.2·bundle
```

A cycle that landed 200 clean lines but grew trunk LOC by 195 (i.e. only deleted 5) scores `loc_score ≈ 0.5 + (-195/200)·... → low`, drags ratchet down, fails the gate even with otherwise-perfect code. **This is the answer to "every new line increases X" — it's a measurable number, not a vibe.**

The three merge-specific adversarial gates are **pure shell** — caught regardless of LLM judgment:

```bash
# G1 — created-duplicate sweep (post-land AST hash collision)
build-ast-hashes one.ie/ | sort | uniq -d   # must be empty

# G2 — dead-name resurrection
grep -wFf dictionary.dead-names.txt $(git diff --name-only main..HEAD)   # must be empty

# G3 — cross-tree import
grep -EHn '^import.*from .(?!@/|@oneie/|node:|[a-z@])' $(git diff --name-only main..HEAD)   # must be empty
```

Plus deterministic `bun run verify` (biome + tsc + vitest) on the cone — same as `/do` W4 opt #4.

**One Haiku adversarial pass** scores `simplicity` against `100-lines.md` (does every landed line earn its place at the 200-line bar?) and surfaces things the deterministic gates can't see — naming inconsistencies, comments that lie, dead branches, justifications that don't justify. Same rubric format as `/do`.

Score budget per cycle: ratchet measurement (0 tokens) + 3 shell gates (0 tokens) + verify (0 tokens) + 1 Haiku (~500 tok). That's the whole W4.

On clean pass: emit `merge:landed` signal with `{source, cycle, want, skip, files_landed, files_rejected, rubric, deltas, dedupe_hits_by_layer, llm_calls, llm_tokens}`. The deltas + token counts feed the next cycle's rubric — drift toward bloat *or* more LLM use loses score and gets routed around.

---

### Stage 6 — COMPRESS *(the prune that closes the loop)*

Landing a feature often *enables* trunk deletions that weren't possible before — a new abstraction makes 3 helpers obsolete; a new component makes 5 wrapper files unnecessary. The current cycle is the only moment we know exactly what changed, so it's the cheapest moment to prune.

**Three deterministic sweeps, in order:**

```bash
# S1 — newly-orphaned exports (nothing in trunk imports them anymore)
git diff --name-only main..HEAD | xargs -I{} dirname {} | sort -u | \
  xargs ts-prune --project one.ie/tsconfig.json | grep "used in module" -v \
  > orphans.txt

# S2 — newly-created AST duplicates (two files now hash-equal)
build-ast-hashes one.ie/src/ | sort | uniq -d -f1 > new-dupes.txt

# S3 — newly-dead branches (unreachable per tsc / zero coverage in cone)
bun run tsc --noEmit --noUnusedLocals 2>&1 | grep "is declared but" > dead-locals.txt
```

**Prune actions:**

| Sweep finding | Action | Tool |
|---|---|---|
| File in `orphans.txt` with zero importers | `git rm` + commit `compress(<src>): remove orphan <path>` | shell |
| Pair in `new-dupes.txt` | keep canonical-path twin, `git rm` the other, rewrite imports via `sed` | shell |
| Dead local in `dead-locals.txt` | one Sonnet Edit per file to delete the dead branch | LLM |

After prune commits, **re-run the ratchet snapshot.** The compression deltas roll into the same `ratchet` rubric — meaning a cycle that lands 200 lines and prunes 350 reports `delta_loc = -150`, ratchet ≈ 1.0, gate sails through. A cycle that lands 200 with zero prune ops likely scores ratchet ≈ 0.4 and has to justify against the 100-lines bar or fail.

**Token budget:** S1+S2 are 0 tokens. S3 spawns at most one Sonnet per dirty file, only when dead branches exist. Most cycles: 0–1k tokens for compression.

Pheromone tag: `merge:compress:<source>` strength accumulates with prune count. Sources that consistently enable trunk deletion become highways; sources that only ever add code get deprioritized over time.

---

**G1 — Land gate.** After COMPRESS passes, the cycle is on a merge branch (`merge/<source>-<short-sha>`), trunk is untouched. G1 renders a one-screen summary: features landed (cross-referenced to `merge.intent.md`), file count, rubric, **deltas** (LOC ±, tests ±, build ±, bundle ±, tsc errors ±), token spend. Human OK (or auto-OK if `trust: trusted`) → fast-forward to trunk. Reject → drop the branch (`git branch -D`); pheromone records `warn(1)` on `merge:source:<repo>` and `warn(0.5)` on the specific feature tags that landed. Manifests survive — refining `intent.md` and retrying is the next cycle.

---

## 4. Decision matrix — what happens to every candidate file

```
              ┌─ name match (L1)     → reject:dead-name | continue
              ├─ schema match (L2)   → reject:exists | halt:new-dimension
overlap   →   ├─ AST match (L3)      → reject:ast-duplicate
              └─ behavior match (L4) → reject:behavior-duplicate | extend

novel     →   FIT → LAND (full file)
gem       →   FIT → LAND (extract symbol range only)
duplicate →   reject:duplicate
reference →   reject:reference-only
noise     →   reject:noise
schema    →   halt:spec-reconciliation
```

Every leaf is a closed loop. Every reject produces one line in `merge-log.jsonl`:

```json
{"cycle": 17, "source": "scratch/foo", "path": "src/bar.ts",
 "verdict": "ast-duplicate", "trunk_anchor": "one.ie/src/baz.ts",
 "confidence": 0.94, "ts": "2026-05-12T..."}
```

That log IS the dedupe memory. Cycle N+1 reads it before classifying — anything previously rejected from the same source path with the same hash short-circuits to `reject:cached`.

---

## 5. Speed + token budget (every cycle reports — invariant #6)

| Stage | Wall-clock | LLM tokens | How |
|---|---|---|---|
| DECLARE — `features.md` generation (first run per source) | < 10s | ~2k tok Haiku | once, cached on source sha |
| DECLARE — `features.md` (cached subsequent runs) | < 100ms | 0 | sha match → reuse |
| DECLARE — `intent.md` resolution → file globs | < 200ms | 0 | yaml parse + glob expand |
| G0 — intent gate render | < 1s | 0 | one-screen summary |
| CLASSIFY shell funnel (A–D) | < 5s for 10k files | 0 | `find` + `comm` + `grep` |
| CLASSIFY Haiku residue (per file) | < 1s | ~70 tok | binary novel/overlap, parallel |
| DEDUPE L1–L4 (per overlap) | < 200ms | 0 | indexed `grep` + AST hash |
| DEDUPE ambiguous extension | < 2s | ~200 tok Haiku | only when L4 is partial |
| FIT plan (per file) | < 3s | ~150 tok Haiku, or 0 if mechanical | Opus only when DROPS is non-trivial |
| LAND — `cp` / `sed` / `git mv` path | < 100ms | 0 | most files take this path |
| LAND — Sonnet Edit path | < 30s | ~1k tok | only for genuine restructure |
| W4 — ratchet snapshots (before + after) | < 30s × 2 | 0 | `cloc` + `bun test --json` + build + `stat` + `tsc` |
| W4 — 3 shell gates + verify | < 90s | 0 | `bun run verify` on cone |
| W4 — Haiku adversarial | < 5s | ~500 tok | one call per cycle |
| W5 — COMPRESS sweeps S1+S2 | < 10s | 0 | `ts-prune` + AST hash uniq |
| W5 — COMPRESS S3 prune edits | < 30s | ~0–1k tok | Sonnet only when dead locals exist |
| G1 — land gate render | < 1s | 0 | one-screen summary + deltas |
| **Full cycle target** | **< 5 min for ≤ 5 files** | **< 5k tokens for clean cycles** | exceeded → `warn(0.5)` on source tag |

**The shape this enforces.** A 20-file cycle where 80% are deterministic landings should cost roughly: 20 × 70 (classify) + 4 × 200 (extension calls) + 4 × 1k (Sonnet edits) + 500 (W4) = ~6.7k tokens total. Compare to "Sonnet does everything": 20 × ~3k = 60k. **~9× reduction baked into the topology**, not a tuning knob.

Cycles whose token count drifts upward without a matching rubric improvement → speed dim drops → pheromone deprioritizes that source pattern. The loop self-corrects toward cheaper.

---

## 6. What pheromone learns (the compounding part)

Every cycle close emits tagged signals. After N cycles, the loop knows:

| Tag pattern | What it means | How the loop uses it |
|---|---|---|
| `merge:source:<repo>` strength | this repo has produced clean landings | `select()` prefers it as a candidate-source for routine work |
| `merge:source:<repo>` resistance | this repo produces noise / duplicates / fails the rubric | `select()` deprioritizes; > 2× strength → toxic, skip without classifying |
| `merge:feature:<id>` strength | this feature landed cleanly | future cycles fast-path it (skip manifest re-review for unchanged features) |
| `merge:skip:<id>` strength | this feature was explicitly skipped in prior cycles | pre-fills `skip` in new `intent.md`; auditor sees the reason chain |
| `merge:dedupe:<layer>` strength | this layer catches the most rejects | tunes layer ordering: rotate the cheapest high-hit layer to position 1 |
| `merge:verdict:<v>` strength | this verdict trends true after W4 | classifier prior shifts: e.g. files matching pattern X are usually `noise`, fast-path |
| `merge:dim:<security|...>` resistance | this dim is the rubric blocker | future FIT plans pre-flight that dim before spawning W3 |

This is `/do` optimization #5 (pheromone-routed SELECT) applied to merging. The substrate that powers ONE powers its own intake.

---

## 7. Failure modes and the safety net

| Failure | Detection | Response |
|---|---|---|
| A landed file later turns out to duplicate a trunk file | post-merge nightly AST-hash sweep | open issue → revert commit → `warn(1)` on `merge:source:<repo>` |
| Classifier marks `novel` but DEDUPE finds match (W2 catches W1) | rate tracked per source | > 10% disagreement on a source → halt that source, recalibrate prompt |
| Rubric drops below 0.65 for 3 consecutive cycles on same source | drift detection (same as `/do --improve`) | freeze source; emit `merge:drift:<source>`; require human review |
| Dictionary gap (an external term has no canonical name) | FIT halts | one-line PR to `dictionary.md` resolves it before merge resumes |
| Schema candidate (verdict = `schema`) | Stage 1 halts | spec-author handshake: edit `one.tql` + `dictionary.md` in a separate cycle, *then* re-classify |
| Source repo deleted/moved mid-cycle | Stage 1 `dissolved` | `warn(0.5)` on `merge:source:<repo>`; cycle ends clean |
| `intent.md` names a feature id no longer in `features.md` (source restructured) | G0 halts | regenerate `features.md`, refine `intent.md`, retry — no tokens leaked past G0 |
| `features.md` lists ids that `intent.md` omits entirely | G0 halts (invariant 5b) | author must classify every id as want/skip/undecided — no silent omissions |
| > 20% of feature ids in `undecided` | G0 halts | intent isn't formed; refine before spending DEDUPE budget |

**The safety net is git.** Every cycle is one branch (`merge/<source>-<short-sha>`). Trunk is only updated by a fast-forward merge after the full cycle's rubric passes + a human OK (or `trust: trusted` per `/do` optimization #8). Bad cycle → drop the branch. Cost of being wrong: ~zero.

---

## 8. Why this is the right shape

- **Deterministic-first everything.** Not just dedupe — classify, fit, and land all lead with shell. `cp`, `sed`, `git hash-object`, `grep`, `comm` do the work; Haiku binary-classifies the residue; Sonnet edits only when restructure is real; Opus only at semantic forks. The "less is more" gate is *physical* — most cycles spend zero LLM tokens on most files.
- **Intent-first, scan-second.** Two short manifests (`features.md` + `intent.md`) collapse the search space by ~95% before tokens are spent. Features are first-class — they accumulate pheromone, they're diffable across cycles, they make "why did this land?" a `grep`, not an archaeology dig.
- **Sub-file extraction (`gem` verdict).** Old repos hide beauty in slop. The loop can lift a single hook, util, or component from a 5000-line tangled file via tree-sitter + line-range, leaving the rest unmerged. Without this, mining old work is all-or-nothing.
- **Ratchet, not vibes.** Trunk LOC, test count, build ms, bundle bytes, tsc errors — measured before and after every cycle, rolled into a `ratchet` rubric dim with deterministic weights. "Every new line increases speed/stability/succinct" is a number that must score ≥ threshold or the cycle fails. The loop physically refuses to bloat.
- **Compress on land.** Stage 6 sweeps for orphaned exports, newly-created AST duplicates, and dead branches enabled by the merge — then prunes them in the same cycle. A merge that lands 200 lines and deletes 350 is the *normal* outcome, not the exception.
- **The 200-line bar.** `100-lines.md` loads as W2 base context. Every fit plan > 50 LOC must justify against the substrate's whole engine fitting in 200 lines. Empty justification → halt. The bar isn't taste; it's measurement.
- **The trunk is the spec.** No "merge into a staging tree first." Either it earns a canonical path in `one.ie/`, or it doesn't land. Half-merged code is the failure case.
- **One commit per file.** Atomic landings = atomic reverts. A bad cycle is a single `git branch -D`, not a 4-hour bisect.
- **Same loop as `/do`.** Operators, telemetry, pheromone, rubric, optimizations — all inherited. No new vocabulary to learn; merge-loop *is* `/do` with a different W1 brief.
- **Compounds.** Cycle 1 is slow because everything is novel. Cycle 100 is fast because the recon cache is warm, the source-repo pheromone is sharp, the classifier prior is tuned, and most candidate files short-circuit at L1.

---

## 9. First two instances (where the rubber meets the road)

| Cycle | Source | Status | Spec |
|---|---|---|---|
| C1 | `one-ie/one/web/` → `one.ie/src/` | designed | [`merge.md`](merge.md) — already plans the file-by-file moves; this loop is the machine that executes it |
| C2 | TBD scratch tree | next | run `/do merge-loop --source <path>` once C1 closes |

`merge.md` is the *territory* for C1: which files, which paths, which renames. `merge-loop.md` (this doc) is the *map* — the loop that makes C1 reproducible for C2..Cn.

---

## 10. Surface cheatsheet

```
# 1. Generate the feature manifest (once per source, cached)
/do merge-loop --source <path> --declare

# 2. Author intent.md (or copy from prior cycle and edit)
$EDITOR merge.intent.md

# 3. Run the cycle (G0 → CLASSIFY → ... → LEARN → G1)
/do merge-loop --source <path>            # one source, one cycle
/do merge-loop --source <path> --auto     # autonomous if trust: trusted
/do merge-loop --source <path> --dry-run  # runs through G1 but never fast-forwards; renders the diff + ratchet only
/do merge-loop --source <path> --explain  # G0 only — prints scope + budget without classifying

# Query the merge memory
cat merge-log.jsonl | jq 'select(.verdict | startswith("reject"))'  # what was rejected
cat merge-log.jsonl | jq -s 'group_by(.source) | map({src: .[0].source, n: length})'

# Pheromone view (after merge:landed signals accumulate)
curl /api/highways?tag=merge | jq                # which sources are highways
curl /api/state | jq '.toxic[] | select(.tag | startswith("merge:"))'   # toxic sources
```

---

## See also

- [`merge.md`](merge.md) — first concrete instance (one-ie → one.ie); the territory for cycle C1
- [`one.ie/.claude/commands/do.md`](one.ie/.claude/commands/do.md) — wave + rubric grammar this loop inherits
- [`one.ie/docs/dictionary.md`](one.ie/docs/dictionary.md) — canonical names, dead names; the L1 dedupe oracle
- [`one.ie/src/schema/one.tql`](one.ie/src/schema/one.tql) — 6 dimensions; the L2 dedupe oracle and the only place that can grow with explicit reconciliation
- [`one.ie/one/template-plan.md`](one.ie/one/template-plan.md) — `mode: lean | full | mixed` classifier; merge cycles classify the same way
- `CLAUDE.md` (this directory) — root-cluster rules; merge-loop is one of the *.md spec docs

---

*One trunk. One vocabulary. One loop, ten thousand cycles. Every candidate file closes — landed, rejected, or dissolved. Less is more, and the substrate remembers which less.*
