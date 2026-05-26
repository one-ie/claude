# /do

**Skills:** `/signal` · `/typedb` · `/todo`

> **Before anything:** read `docs/TODO.md` AND load the `/todo` skill's *"The world this skill builds for"* block (7 properties). Every cycle inherits those constraints.

---

## Tool ladder (try in order — stop at first that decides)

```
bash (grep/hash/diff/find)   — bit-equal, name match, path check   ~0 tokens
Haiku × N parallel           — ambiguous binary judgment            ~70 tok/file
Sonnet                       — restructure, genuine edit            ~1k tok/file
Opus, main context           — semantic fork, schema reconciliation ~10k+
```

Cheapest tool that answers wins. A cycle that runs zero LLM calls is a *good* cycle. Apply at every decision point — W1 recon, W3 anchor validation, W4 compress sweep.

---

## Complexity classifier

Runs before W0. Classify from the current cycle's task scope:

| Tier | Criteria | Execution path |
|------|----------|----------------|
| **TRIVIAL** | ≤3 files, ≤20 LOC delta, no new types/API routes/schema | 0 agent spawns |
| **SIMPLE** | ≤6 files, clear scope, no new primitives | 2–3 spawns |
| **COMPLEX** | Multi-file architecture, new primitives, schema/API changes | Full W1→W4 |

**TRIVIAL fast path (0 agent spawns):**
1. Read ≤3 files directly in main context
2. Decide diff specs inline — no W2 spawn
3. Pre-validate anchors: `grep -qF "$anchor" "$target"`
4. Apply edits with Edit tool directly
5. `bun run verify` — biome + tsc + vitest
6. Inline rubric: score goal-fit/security/stability/simplicity/speed, composite = `0.35g+0.20s+0.20t+0.15i+0.10p`; goal-fit ≥ 0.50 hard gate
7. Gate ≥ 0.65 → write one learnings.md entry → done

Log: `tier=trivial  files=N  edits=N  composite=N.NN`

**SIMPLE fast path:**
- W1: read files directly in main context (≤6 files = below spawn threshold)
- W2: spawn as **Sonnet** (Opus reserved for COMPLEX)
- W3: parallel agents, skill routing per spec (not blanket)
- W4: `bun run verify` + inline composite; spawn 5 agents only if deterministic checks fail

Log: `tier=simple  spawns=2-3`

**COMPLEX → full W1→W4** (see wave specs below)

**One gradient, two scopes.** The classifier above (TRIVIAL/SIMPLE/COMPLEX) sizes the *build* — agent spawns, model routing. The *product* tier from `.claude/scripts/do-tier.sh` (PATCH/FIX/FEATURE/SCHEMA) sizes the *lifecycle* — which spine stops + gates run — and emits a per-tier token ceiling. They compose, never compete: `do-tier.sh` maps each product tier to its classifier (PATCH→TRIVIAL, FIX→SIMPLE, FEATURE/SCHEMA→COMPLEX) and pruned spine. Token economy is automatic — a typo gets the 2-stop spine + 0 spawns; only a FEATURE earns the full pipeline. Cycle close compares `cost:cycle` to the tier ceiling; over → `warn` + justify-or-drop.

---

## Loop optimizations

| # | Name | Wave | Mechanism |
|---|------|------|-----------|
| 1 | Recon cache | W1 | KV `recon:{sha}:{sha}` hit (<14d) → skip re-read, `mark(recon:hit)` |
| 2 | W2 context auto-load | W2 | Last 20 learnings + `dictionary.md` + `rubrics.md` pre-loaded |
| 3 | W3 prompts auto-gen | W2→W3 | TARGET/ANCHOR/ACTION blocks → mechanical spawn |
| 4 | Verify-only-what-changed | W3→W4 | Dependency cone from `git diff`; full verify at cycle close only |
| 5 | Pheromone-routed SELECT | autonomous | `priority + strength − resistance + tag-warmth` |
| 6 | Split-test | W3 | N variants → winner `mark()`, losers `warn(0.5)` |
| 7 | Cycle-size cap | cycle start | >5 tasks refused unless `mode: lean` |
| 8 | Trust budget | cycle close | ≥0.85 × 3 consecutive = `trusted` (skip show-pause) |
| 9 | Compress-before-construct | W2 | PRIMITIVE/COMPOSE/VERDICT before any new primitive |
| 10 | Test = bash, not LLM | W4 | Cycle's `demo.command` exit code is the gate; 0 tokens |
| 11 | Vitest-first | W2 plan + W4 verify | Default test = Vitest + msw + @testing-library; Playwright only if `requires_playwright: true` |
| 12 | Goal-based assertion | W2 plan | One `expect()` per cycle goal — not implementation paths |
| 13 | Plan-outcome re-check | W4 cycle close | `$(plan.outcome)` re-runs every cycle close; exit 0 → kill-switch on remaining cycles (justify-or-drop) |
| 14 | Goal-fit rubric dim | W4 | `0.35·goal-fit + 0.20·security + 0.20·stability + 0.15·simplicity + 0.10·speed`; hard gate goal-fit ≥ 0.50 |
| 15 | Deliverable proof | W4 | Every cycle records observable proof (curl / screenshot / log) that the `deliverables:` row is live |

**Trust levels:**

| Level | Condition | `--auto` behavior |
|-------|-----------|-------------------|
| `trusted` | composite ≥ 0.85 × 3+ consecutive | skip show-pause; start next cycle immediately |
| `standard` | composite 0.65–0.85 (default) | show-frame render; auto-continue |
| `cautious` | composite < 0.65 × 2 consecutive | show-frame + halt; run `/do next` to continue |

Counter resets to 0 on streak break. **Source of truth is `.do-trust.json` `{level, consecutive, composite, updated}`** — machine-readable, written at cycle close, read FIRST at startup (absent → default `standard`). `learnings.md` stays human history only (deriving trust from prose fails silently). Emit `loop:trust:{level}`.

*Constraint set: Minimize context. Maximize accuracy. Succinct. Progressive. Self-learning. Secure. Compress before construct.*

---

## Modes

| Mode | What | Notes |
|------|------|-------|
| `<intent>` | Natural language → find context → fastest path | Read `do-intent.md` first |
| `<todo-file>` | Advance next wave of the TODO | wave-at-a-time |
| `<TODO> --auto` | Run W1→W4 continuously until all cycles done | trust-aware |
| `<TODO> --wave N` | Run specific wave (override auto-detect) | |
| *(empty)* / `--once` | Autonomous loop | Read `do-autonomous.md` |
| `--show` | Cycle frame rendering (when plan `show: true`) | Read `do-show.md` |
| `--improve` | Meta-improvement from drift signals | Read `do-improve.md` |

**Intent mode:** when args are not a TODO filename/`--flag`, read `.claude/commands/do-intent.md` before proceeding.

**Skill check:** infer from task tags → `ls .claude/skills/{name}/` → ready (proceed) / stale (warn) / missing (offer options). Block only if missing+required.

---

## Wave-aware model routing

| Wave | Tier | Model |
|------|------|-------|
| W1 | COMPLEX (≥6 files) | Haiku — parallel spawns |
| W2 | COMPLEX | Opus |
| W2 | SIMPLE | Sonnet |
| W2 | TRIVIAL | inline (main context) |
| W3 | any | Sonnet — parallel |
| W4 | COMPLEX | Haiku × 5 |
| W4 | SIMPLE/TRIVIAL | inline (main context) |

---

## `<todo-file>` — Wave execution

Read `docs/<todo-file>`. Find first unchecked `- [ ]` wave entry. Execute that wave:

---

**W0 — Baseline**

```bash
# Folder-aware: there is NO root package.json — each top folder is its own repo.
# Resolve the cycle's target folder(s) from its planned deliverable/edit paths.
RESOLVED=$(printf '%s\n' $CYCLE_TARGET_PATHS | .claude/scripts/do-folder.sh)
if echo "$RESOLVED" | jq -se 'all(.doc_only)' >/dev/null; then
  echo "W0: doc-only cycle (.md/.claude/plans/text) — no bun verify"
else
  echo "$RESOLVED" | jq -r 'select(.verify).folder' | while read -r f; do
    ( cd "$f" && bun run verify ) || { echo "W0 verify FAILED in $f"; exit 1; }
  done
fi
```

Capture build baseline **only if** cycle touches bundle-affecting files (Astro pages, client islands, Worker entry, `src/lib/`, CSS). Skip for API-only, schema-only, or doc-only cycles.

```bash
# Bundle-affecting cycles only:
bun run build 2>&1 | tail -5
CLIENT_KB=$(du -sk dist/_astro/*.js 2>/dev/null | awk '{sum+=$1} END{print sum}')
WORKER_KB=$(du -sk .wrangler/output/*.js 2>/dev/null | awk '{sum+=$1} END{print sum}')
AGENT_LINES=$(find agents -name '*.md' 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
```

**Always capture (every cycle):**
```bash
TSC_ERRORS=$(bunx tsc --noEmit 2>&1 | grep -c "error TS" || echo 0)
LOC=$(cloc src/ --json 2>/dev/null | jq -r '.SUM.code // 0')
```

Write `.w0-baseline.json` with tests passed, buildMs (if run), bundleKB (if run), `tscErrors`, `loc`. W4 diffs against this.

---

**W1 — Recon**

**File threshold:** ≤5 files → read directly in main context (spawn overhead exceeds read cost). ≥6 files → spawn agents.

1. Read `.w4-improvements.json` (if exists) — open items become mandatory recon targets
   ```bash
   cat .w4-improvements.json 2>/dev/null | head -50
   ```
   Item appearing in 3+ consecutive cycles → flag as systemic gap.

2. **≥6 files (spawn path):** spawn ALL recon agents **in a single message** using `w1-recon` agent, `model: "haiku"`. Each returns structured JSON:
   ```json
   { "file": "<path>", "findings": [
       { "line": N, "type": "current-behavior|gap|pattern",
         "excerpt": "...", "relevance_score": 0.0-1.0 }
   ]}
   ```
   W2 auto-skips `relevance_score < 0.4`.

3. **≤5 files (direct path):** read files with Read tool, produce equivalent structured findings in-context.

**Recon cap (token discipline):** the W1 receipt is capped at **400 words** — enforce before W2 spawns. Verbatim recon blows W2/W4 context. Persist the high-signal slices into `.w2-spec.json`'s `current_state` fields (W2), don't carry the raw dump forward.

4. Mark Wave 1 `[x]`.

Log: `W1: mode=agents|direct  files=N  marked=N  warned=N  dissolved=N`

---

**W2 — Decide**

**Mandatory first — goal/deliverable/UX gate (zero LLM tokens, main context, written before step 1).**

Read plan frontmatter (`goal:`, `outcome:`, `deliverables:`, `ux_before:`, `ux_after:`, `ux_delta:`). Write three sentences in this exact shape:

```
GOAL DELTA:  After this cycle, $(plan.outcome) is closer because {observable} will be true.
DELIVERABLE: This cycle owns deliverables[{n}] = {kind}: {path}.
UX DELTA:    After this cycle, the user can {observable} that they couldn't before. (or: "internal-only — justified by {reason}")
```

Cannot write all three → halt; the cycle doesn't belong in this plan. Log: `W2 gate: goal-delta=✓ deliverable=✓ ux-delta=✓`.

1. You ARE the decider. Do not delegate.
2. Read W1 findings. Skip `relevance_score < 0.4` (log `filtered:N`).
   Auto-load: last 20 `learnings.md` entries (overlapping tags) + `dictionary.md` + `rubrics.md`.
   **Context triggers** — scan W1 excerpts + paths. Check plan `context_triggers:` frontmatter first; fall back to built-in table:

   | Pattern | Inject |
   |---------|--------|
   | `signal\(`, `emit\(`, `receiver:` | `one/signals.md` |
   | `\.tql`, `@/engine`, `isa path` | `src/schema/one.tql` (first 80 lines) |
   | `subscribe\(`, `sub:` | `one/signals.md` |
   | `pheromone`, `edges\.json`, `mark\(` | `apps/generate/generate.md` §Pheromone rules |

   Pull only docs with matching W1 patterns (zero matches → don't pull).
   **Zero-findings guard:** all filtered → `W2: all_filtered` → halt → ask user to broaden W1 targets.

3. Tag TODO type: `refactor | fix | feature | doc` (controls W4 Simplicity benchmark).

4. **Focus check** — for every file in diff spec, note line count. "Is this file doing one thing?" Entire substrate is ~200 lines total — use as reference. Name splits here; W3 executes them.

5. **Compress check** — before any new primitive (HTTP endpoint, SDK method, MCP tool, CLI verb, schema field, event name, error type):
   ```
   PRIMITIVE: <what's being added>
   COMPOSE:   <3 existing primitives that cover this>
   VERDICT:   compose  (remove the addition)
              | extend  (add field/tag to existing primitive)
              | new     (justify vs dsl.md / one-ontology.md / dictionary.md — one sentence)
   ```
   `compose` → remove from diff spec (convenience wrappers → `sdk/src/sugar/` only).
   `new` → requires doc edit in same diff.

   | Tempted to add… | Check first |
   |---|---|
   | HTTP endpoint | `plans/agent-api.md` § The fourteen operations |
   | SDK method | `plans/agent-api.md` § The SDK |
   | MCP tool | `plans/agent-api.md` § The MCP |
   | CLI verb | `plans/agent-api.md` § The CLI |
   | Section kind | `plans/agent-authoring.md` § Sections |
   | Event name | `plans/agent-analytics.md` + `plans/dictionary.md` |
   | Substrate verb | `one/dsl.md` § Six Verbs |
   | Dimension | `one/one-ontology.md` § 6 Dimensions |

   Log: `W2 compress: compose=X extend=Y new=Z`

   **5a. Doc propagate plan** — list every doc this cycle must edit. Required when ANY of:
   - W2 marks `new` in the compress check (new primitive)
   - W3 will rename / move / delete an exported identifier
   - W3 touches `src/lib/`, `src/pages/api/` (public surface), new component directory, or new MCP/CLI/SDK export
   - W3 changes a 6-dimension boundary, a locked rule, or a directory contract

   Output (goes in same diff spec as code):

   | Trigger | Doc target | Action |
   |---|---|---|
   | new primitive | source-of-truth doc (from plan frontmatter) | always — even if only touch-verified |
   | rename / move | every `**/*.md` referencing the old name | rename inline (auto-grep in W3) |
   | 6-dim / locked rule / L1-L8 change | root `CLAUDE.md` | edit |
   | directory contract change (new component family, new pattern) | nearest `CLAUDE.md` (component dir or `one.ie/web/src/components/CLAUDE.md`) | edit |
   | public surface change (CLI verb, API route family, SDK export, MCP tool) | root `README.md` + relevant feature doc | edit |
   | feature doc exists (e.g., `plans/crm-buttons.md` for `/in` work) | feature doc | always — sync verbs/components/endpoints |

   Trivial cycles (≤3 files, no public surface, no rename) → skip step 5a entirely.

   **Write `.w2-doc-plan.json` `{renames, touched_docs, contract_dirs}`** — the W4 doc-sync gate reads it by path (without this write the gate is dead code). Trivial cycle → write `{"renames":[],"touched_docs":[],"contract_dirs":[]}` so the gate bypasses cleanly.

   Log: `W2 doc-plan: docs=N triggers=[<trigger-codes>]`

6. For each W1 finding: **Act** (diff spec) / **Keep** (intentional exception) / **Defer** (out of scope — write follow-up task ID).

7. Output diff specs:
   ```
   TARGET:    docs/foo.md
   ANCHOR:    "<exact old text>"
   ACTION:    replace | insert-after | delete
   NEW:       "<new text>"
   COMPRESS:  compose | extend | new
   RATIONALE: "<one sentence>"
   ```

   **Then write `.w2-spec.json`** — the canonical machine-readable handoff W3/W4 read by path (schema in `w2-decide.md`). Each spec carries the lean context pack: `current_state` (≤8-line excerpt you already hold from W1), `must_not_break` (one line), `serves` (the D#). W3 reads this file, not the transcript — compaction-proof.

8. Mark Wave 2 `[x]`.

Log: `W2: decisions=N  fan_out=N`

---

**W3 — Edits**

**Soft-resume check (before anything):** if `.w3-receipts.json` exists with specs still unapplied (fewer receipts than `.w2-spec.json` `diff_specs`), the previous W3 was interrupted → **skip W0/W1/W2 and resume W3** from the first spec not in the receipts file. Otherwise proceed normally.

**Pre-validation (parallel — before spawning any agent):**
Run all anchor checks simultaneously in parallel Bash calls:
```bash
grep -qF "$anchor" "$target" || echo "MISS: $target"
# Multi-line: perl -0777 -ne 'exit 0 if /\Q$anchor/; exit 1' "$target"
```
Any miss → return to W2 with current file excerpt. Same anchor misses twice → halt, ask user.

**Dependency detection:**
- No file overlap → **W3a**: spawn all agents in one message (fully parallel)
- Overlap → W3a first (independent edits), then **W3b** (same-file, sequential). W3b agents: "Read current file state — W3a edits already applied." W3b anchor miss after W3a → escalate to W2 for anchor refresh.

Spawn using `w3-edit` agent, `model: "sonnet"`. Each agent: file path, anchor, replacement, rationale.
Rule: "Edit tool, exact anchor as old_string. Dissolved on anchor mismatch or file-split needed."

Re-spawn dissolved agents once with corrected anchor. Mark Wave 3 `[x]`.

Log: `W3: w3a=N w3b=M  marked=N  warned=N  dissolved=N  reloops=N`

---

**W4 — Verify**

**Deterministic checks first (zero LLM tokens):**
```bash
# Folder-aware verify (no root package.json) — resolve from what actually changed this cycle.
RESOLVED=$(git diff --name-only HEAD 2>/dev/null | .claude/scripts/do-folder.sh)
if echo "$RESOLVED" | jq -se 'all(.doc_only)' >/dev/null; then
  echo "W4: doc-only cycle — skip bun verify (doc-sync gate below still runs)"
else
  echo "$RESOLVED" | jq -r 'select(.verify).folder' | while read -r f; do
    ( cd "$f" && bun run verify ) || { echo "W4 verify FAILED in $f"; exit 1; }
  done
fi
$(cycle.demo.command)             # the goal gate — exit 0 = pass

# Doc-sync hard gate — all three must pass, all bash, zero tokens.
# Reads W2's doc-plan output (step 5a) for the rename list + touched-doc list.

# (a) stale-name check — every old identifier renamed in W3 must not appear in any .md
for old_name in $(jq -r '.renames[]' .w2-doc-plan.json 2>/dev/null); do
  hits=$(grep -rn --include='*.md' "\b$old_name\b" . | grep -v '.git/' | wc -l)
  [ "$hits" -eq 0 ] || { echo "STALE: $old_name in $hits doc lines"; exit 1; }
done

# (b) link check — touched docs have zero broken local links
for doc in $(jq -r '.touched_docs[]' .w2-doc-plan.json 2>/dev/null); do
  bunx markdown-link-check --quiet "$doc" || exit 1
done

# (c) propagate-staleness check — if W3 touched a dir, its CLAUDE.md mtime must be newer
for dir in $(jq -r '.contract_dirs[]' .w2-doc-plan.json 2>/dev/null); do
  cmd_mtime=$(find "$dir" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.astro' \) -newer "$dir/CLAUDE.md" 2>/dev/null | wc -l)
  [ "$cmd_mtime" -eq 0 ] || { echo "STALE: $dir/CLAUDE.md older than touched code"; exit 1; }
done
```

If `.w2-doc-plan.json` is absent (trivial cycle skipped step 5a), the doc-sync gate is bypassed.

`cycle.demo.command` comes from the plan frontmatter (or cycle `Exit:` if inline). Default shape: `bun vitest run tests/e2e/{cycle-id}.test.ts`. **Playwright spawn ONLY when `requires_playwright: true` in cycle frontmatter** — otherwise Vitest + msw + @testing-library is the default. Lighthouse CLI runs via a Vitest wrapper (`LIGHTHOUSE=1`), not Playwright.

Verify or demo failure on W3-touched files → W3.5: one Sonnet agent per dirty file (same W3 rules). Max 3 total W4 loops before hard halt.

**Ratchet delta (always — compare against `.w0-baseline.json`):**
```bash
TSC_NOW=$(bunx tsc --noEmit 2>&1 | grep -c "error TS" || echo 0)
LOC_NOW=$(cloc src/ --json 2>/dev/null | jq -r '.SUM.code // 0')
DELTA_TSC=$((TSC_NOW - $(jq .tscErrors .w0-baseline.json 2>/dev/null || echo 0)))
DELTA_LOC=$((LOC_NOW - $(jq .loc .w0-baseline.json 2>/dev/null || echo 0)))
```

Hard gate: `delta_tsc_errors ≤ 0` — cycle cannot close if new type errors were introduced.
Report: `delta_tsc=N  delta_loc=±N` (negative LOC is good; positive requires TODO type=feature justification).

**Adaptive spawn (tier-gated — minimize tokens):**

*TRIVIAL:* inline rubric only. Score in main context. **No agent spawns** unless verify fails. If demo gate passes + delta_tsc ≤ 0 + W2 goal-delta sentence holds against the shipped diff + deliverable proof captured, composite ≥ 0.65 is the default — no rubric scoring needed.

*SIMPLE:* inline rubric only. Spawn 5 agents **only if** `bun run verify` fails OR cycle's `demo.command` fails OR composite < 0.65.

*COMPLEX (only when ≥6 files OR new primitives OR schema/API change):* spawn **6 agents in one message:**
```
agent-goal-fit    haiku — goal-fit 0–1    (W2 goal-delta sentence verified against shipped diff;
                                           deliverable proof present; ux_after journey reachable)
agent-security    haiku — security 0–1    (no vulns, validated boundaries, no secrets)
agent-stability   haiku — stability 0–1   (tests pass, zero type errors, handlers close)
agent-simplicity  haiku — simplicity 0–1  (min code, every line earns its place)
                          compress ceiling: new>0 without doc edit → cap 0.70
agent-speed       haiku — speed 0–1       (Lighthouse 100, bundle ≤ W0, tokens lean)
agent-adversarial haiku — failure modes, signal grammar, spec violations
                          receiver grammar: (actor|world|all|sub)(:[a-z:+\w]+)?
                          invalid receiver → severity 0.8
```
Composite: `0.35·goal-fit + 0.20·security + 0.20·stability + 0.15·simplicity + 0.10·speed`
Gate: composite ≥ 0.65 AND **goal-fit ≥ 0.50** AND no adversarial severity > 0.5 AND delta_tsc_errors ≤ 0.

**Compress sweep (after gate passes — zero LLM tokens):**
```bash
# S1 — orphaned exports (nothing imports them)
bunx ts-prune --project tsconfig.json 2>/dev/null | grep "used in module" -v > .compress-orphans.txt

# S2 — dead locals introduced by this cycle
bunx tsc --noEmit --noUnusedLocals 2>&1 | grep "is declared but" > .compress-dead.txt
```
Non-empty `.compress-orphans.txt` → `git rm` the orphaned file + commit `compress: remove orphan <path>`.
Non-empty `.compress-dead.txt` → one Sonnet Edit per file to delete the dead symbol.
Re-run ratchet snapshot after prune — final `delta_loc` should improve.

Log: `compress: orphans=N  dead_locals=N  pruned=N`

**Cross-cycle pre-warm (fire-and-forget — non-blocking):**
After gate passes, spawn one Haiku agent to pre-read next cycle's W1 targets. Store in `prewarm[path]` with mtime. Next W1: use if `file.mtime == prewarm[path].mtime_at_read`; else live read.

Mark Wave 4 `[x]` → mark cycle `[x]`.

**Write improvement artifacts:**
```bash
# .w4-improvements.json — machine-readable, feeds next W1
# docs/improvements.md  — human-readable; systemic gap = file:line in 3+ consecutive entries
```
Systemic gap → emit `substrate:systemic-gap` signal with file, dim, cycles_unresolved, action.

Log: `W4: security=N.NN  stability=N.NN  simplicity=N.NN  speed=N.NN  composite=N.NN  adversarial=pass|fail  delta_tsc=±N  delta_loc=±N  compress=N  verify=green|red`

---

**After each wave:**
- Update TODO Status `[x]`
- Report: `{ marked: N, warned: N, dissolved: N }`
- Wave-level signals tracked **in-memory** (not written to learnings.md until cycle close)

**Cycle close (hard gate):**
All 4 waves complete → `/close --todo <slug> --cycle N`
- Emit `do:close` [`cycle:N`, `wave:gate`]
- Emit `signal("cost:cycle", { tokens, model, composite })` — token spend (from the W4 `tokens` receipt) → substrate pheromone. `cost:cycle` is an event, not a new verb — reuse `signal()` verbatim. If the cycle's tier ceiling (C7) is exceeded → also `warn` and flag justify-or-drop.
- Write **one** learnings.md entry (cycle summary — do not write per-wave entries; include `goal-fit=N.NN`, `deliverable=<path>`, `ux-proof=<one-line>`)
- Verify entry written; block next cycle if skipped
- Delete `.w3-receipts.json` (cycle complete — soft-resume state no longer needed)
- **Deliverable proof captured** — curl output / screenshot path / log line that proves the cycle's `Deliverable:` row is live. Without it, cycle does not close.
- **Plan-outcome re-check (zero LLM tokens):** evaluate `$(yq '.outcome' plans/{todo-file}.md)`. Exit 0 → mark remaining cycles `state: justify-or-drop`, halt `--auto`, prompt user to drop or justify each. Plan does not close until this command exits 0.

**Write `.do-trust.json`** `{level, consecutive, composite, updated}` (the machine-readable trust record `--auto` reads at startup).
Format: `trust: {level} composite={X.XX} cycles_at_level={N}`

**Drift detection (at cycle close):**
Read last 3 learnings.md entries for this TODO. Any dim < 0.65 × 3 consecutive closes on same wave+tag → append `drift: {wave}:{dim} on [{tags}]` + emit `loop:drift:{wave}:{dim}`.

**Goal-drift (hardest signal):** plan-outcome command fails × 3 consecutive cycle-closes → append `drift: plan-outcome` + halt `--auto` + emit `loop:drift:goal`. Three green-rubric cycles with a red plan-outcome means the plan model is wrong, not the code. Force re-plan, do not continue.

**`--auto` continuation (after cycle close):**
- `trusted` → skip show-pause; log `[trust:trusted] continuing...`; start next cycle immediately
- `standard` → render show-frame; auto-continue
- `cautious` → render show-frame + `[trust:cautious] halting — run /do next to continue`; stop

Stop if: W4 loops > 3 (escalate to user), trust=cautious, or all cycles `[x]`.

**`--wave N`:** force specific wave (1–4) regardless of Status section.

---

**Rules (non-negotiable):**
- Never skip W2. Understanding is not delegable.
- Always spawn W1 and W3 agents in a **single message** (parallelism).
- W4 max 3 loops. After 3, halt and report to user.

---

*`/do` is `select()` made human-readable. The path remembers every execution.*
