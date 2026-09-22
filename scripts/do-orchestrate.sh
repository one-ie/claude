#!/usr/bin/env bash
# do-orchestrate.sh — the OUTER loop. rank → pick → build → REFLECT → fold → repeat.
#
# do-auto.sh loops cycles WITHIN one plan. do-fleet.sh runs several plans ONCE.
# This drains the ready-queue ACROSS plans, one verified plan per iteration, each
# in its own worktree — the "always building, always better" engine.
#
# (Not /do-loop — that was a deprecated per-plan accident. This is the ranked
#  cross-plan orchestrator: do-rank chooses, do-auto builds, _reflect verifies.)
#
# THE ANTI-FABRICATION LAW (why this exists): the loop trusts DETERMINISTIC
# checks, never the model's self-report. A plan counts as progress ONLY if its
# kill-switch flips red→green, its diff is real, and nothing regressed. This is
# the architectural fix for confident-but-wrong output: claims must pass a gate.
#
# SAFETY (v1, non-negotiable):
#   - DRY-RUN by default. Prints the loop's plan over N iterations. --go to run.
#   - NEVER auto-merges to main. Verified plans become merge-ready branches.
#   - Stops at: queue drained · trust < floor · iter cap · a plan fails twice.
#   - One plan per worktree; never touches the shared main tree.
#
# Usage:
#   do-orchestrate.sh                  # dry-run: show the next 3 iterations' plan
#   do-orchestrate.sh --iters 5        # dry-run, 5 iterations deep
#   do-orchestrate.sh --iters 3 --go   # LIVE: build top-3 ready plans to branches
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RANK="$ROOT/.claude/scripts/do-rank.py"
AUTO="$ROOT/.claude/scripts/do-auto.sh"
TRUST="$ROOT/.do-trust.json"
WT_BASE="$ROOT/.do-worktrees"
RUNLOG="$ROOT/.do-orchestrate.log"

# Fail-fast executor timeout. do-auto's watchdog defaults to 2400s (40min); for
# the loop's unproven runs that's too long to discover a wedged cycle. /do is
# interactive-by-design (AIM / CLARIFY / W3 anchor-miss all halt-and-ask), so a
# headless cycle that hits a gate WEDGES until the watchdog kills it (found live
# 2026-06-21: 8min, 0 model calls). Cap tighter so a stall is caught fast, not
# after 40 wasted minutes. Override with DO_CONDUCTOR_TIMEOUT.
export DO_CONDUCTOR_TIMEOUT="${DO_CONDUCTOR_TIMEOUT:-900}"

GO=false; ITERS=3; FLOOR=0.65; PROVE=false; AUTONOMOUS=false
while [ $# -gt 0 ]; do
  case "$1" in
    --go) GO=true; shift ;;
    --iters) ITERS="$2"; shift 2 ;;
    --floor) FLOOR="$2"; shift 2 ;;
    --prove-gate) PROVE=true; shift ;;
    --autonomous) AUTONOMOUS=true; shift ;;   # only feed eligible plans (text/do-autonomous-plan.md)
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Propagate autonomous mode to the conductor (do-auto reads DO_AUTONOMOUS=1 and
# appends --autonomous to the /do prompt → gates resolve by rule, not AskUser).
$AUTONOMOUS && export DO_AUTONOMOUS=1

trust_now() {
  [ -f "$TRUST" ] && python3 -c 'import json;print(json.load(open("'"$TRUST"'")).get("composite",0))' 2>/dev/null || echo 0
}

# The kill-switch outcome command for a plan (frontmatter `outcome:`), run from
# the worktree so its relative paths resolve against the isolated build.
plan_outcome() {
  # Strip the surrounding YAML quotes off an inline outcome — else `eval` runs
  # `"bash x.sh"` as one quoted command → "command not found" → every quoted
  # gate looks broken. Block form (outcome: |) has no wrapping quotes (untouched).
  awk '/^outcome:[[:space:]]*\|/{m=1;next} /^outcome:[[:space:]]*/{sub(/^outcome:[[:space:]]*/,"");print;exit} m&&/^[a-z_]+:/{exit} m{print}' \
    "$ROOT/text/$1-todo.md" 2>/dev/null | sed '1s/^"//; 1s/^'"'"'//; $s/"$//; $s/'"'"'$//'
}

# HERMETIC GUARD — the autonomous loop only builds plans it can verify LOCALLY.
# A kill-switch that curls prod (one.ie), deploys, or hits the network mutates
# the live world on every verify — that needs a human watching, not a loop. Such
# plans are skipped as "needs-human", never built unattended. (Caught live:
# agent-accounts bootstraps a real prod account in its outcome.)
_hermetic() {
  local oc; oc="$(plan_outcome "$1")"
  [ -z "$oc" ] && return 1   # no kill-switch ⇒ can't prove ⇒ not loop-safe
  # network/prod markers — NOT bare one.ie (that's the one.ie/web LOCAL dir);
  # match curl/wget, URLs, SUBDOMAIN.one.ie (api./pay./channels.), deploy tooling.
  echo "$oc" | grep -qiE 'curl|wget|https?://|[a-z0-9-]+\.one\.ie|wrangler|deploy|--remote' && return 1
  return 0
}

# CLASSIFY the kill-switch by RUNNING it once and reading the result — mirrors
# do-validate-armed.py. Echoes: green (passes → already met) · broken (runner
# couldn't start: no vitest / missing module / no test files → would churn) ·
# armed (runner ran, tests failed → real fuel) · unclear. Only `armed` is built.
_classify_armed() {
  local oc out rc; oc="$(plan_outcome "$1")"
  [ -z "$oc" ] && { echo unclear; return; }
  out="$( cd "$ROOT" && eval "$oc" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] && { echo green; return; }
  if echo "$out" | grep -qiE 'not found|no such file|cannot find module|no test files|command not found|script not found|cannot find package'; then
    echo broken; return
  fi
  if echo "$out" | grep -qiE '[0-9]+ (pass|fail)|Tests?[[:space:]]|expect\(|FAIL|assert|[0-9]+ (passing|failing)'; then
    echo armed; return
  fi
  echo unclear
}

# AUTONOMOUS ELIGIBILITY — the cheap pre-filter, NOT the safety net.
# The real guards are downstream and already hold: the KILL-SWITCH catches a wrong
# build (wrong thing → gate stays red → rejected), the ANTI-FAB gate catches
# fiction/gaming, the in-cycle CLARIFY/PROMISE gates PARK genuine judgment during
# the build, and MERGE STAYS HUMAN. So we no longer exclude by tier — the only
# thing worth pre-skipping is a plan with UNRESOLVED clarifications (it would just
# park immediately, wasting a spawn). Everything else genuine-armed is eligible;
# if it truly needs judgment mid-build, --autonomous parks it then.
_autonomous_eligible() {
  local slug="$1"
  if grep -q '^## Clarifications' "$ROOT/text/$slug-plan.md" 2>/dev/null; then
    if grep -A40 '^## Clarifications' "$ROOT/text/$slug-plan.md" | grep -qE '^\s*- \[ \]|\?\s*$'; then
      return 1   # would park on CLARIFY anyway — skip the spawn
    fi
  fi
  return 0
}

# _link_deps — symlink the heavy gitignored dirs from main so the worktree can
# actually run tsc/vitest (else the kill-switch faceplants on missing modules).
_link_deps() {
  local wt="$1" nm
  for nm in node_modules one.ie/web/node_modules packages/node_modules \
            packages/sdk/dist channels/node_modules packages/evals/node_modules; do
    if [ -e "$ROOT/$nm" ] && [ ! -e "$wt/$nm" ]; then
      mkdir -p "$wt/$(dirname "$nm")"
      ln -s "$ROOT/$nm" "$wt/$nm" 2>/dev/null || true
    fi
  done
}

# reflect_check <worktree> <outcome-cmd> — THE GATE, factored to take its inputs
# explicitly so it's testable (prove_gate below) and the loop and the test
# exercise the SAME code. Deterministic "is this real?" — believes bash, not the
# model. Returns 0 (real progress) / 1 (fiction or regression → park it).
reflect_check() {
  local wt="$1" outcome="$2"
  # 1. the diff is real (branch has commits + non-empty change vs main)
  local n; n=$(git -C "$wt" rev-list --count main..HEAD 2>/dev/null || echo 0)
  if [ "${n:-0}" -lt 1 ]; then echo "    ✗ no commits on branch — nothing built"; return 1; fi
  if git -C "$wt" diff --quiet main...HEAD 2>/dev/null; then echo "    ✗ empty diff vs main — fiction"; return 1; fi
  echo "    ✓ real diff: $n commit(s)"
  # 2. GATE-GAMING GUARD — the cycle must NOT have edited the kill-switch it is
  # judged by. A green outcome means nothing if the cycle changed the outcome.
  # (Found live 2026-06-21: a system-audit cycle edited scripts/system-audit-
  # gate.sh to add exclusions, making the gate pass without doing the work.)
  local changed gate
  changed="$(git -C "$wt" diff --name-only main...HEAD 2>/dev/null)"
  for gate in $(echo "$outcome" | grep -oE '[A-Za-z0-9_./-]+\.sh'); do
    if printf '%s\n' "$changed" | grep -qxF "$gate"; then
      echo "    ✗ GATE GAMED — cycle modified its own kill-switch ($gate); green is meaningless"; return 1
    fi
  done
  # 3. the kill-switch is GREEN now (the plan's own outcome, run in the worktree)
  if [ -z "$outcome" ]; then
    echo "    ✗ no kill-switch — goal cannot be proven; claim rejected"; return 1
  fi
  if ( cd "$wt" && eval "$outcome" ) >/dev/null 2>&1; then
    echo "    ✓ kill-switch GREEN (outcome exits 0)"; return 0
  fi
  echo "    ✗ kill-switch RED — the goal is NOT met; claim rejected"; return 1
}

_reflect() {
  echo "  [reflect] $1 — verifying claims against reality"
  reflect_check "$WT_BASE/$1" "$(plan_outcome "$1")"
}

# prove_gate — fire the gate at REAL worktrees and assert it rejects fiction and
# accepts real work. The anti-fabrication proof: this is the machinery that makes
# my own confident-but-wrong output impossible inside the loop. Run: --prove-gate
prove_gate() {
  local base="$WT_BASE/_gateproof" fails=0
  rm -rf "$base" 2>/dev/null; git -C "$ROOT" worktree prune 2>/dev/null || true
  git -C "$ROOT" branch -D _gateproof 2>/dev/null || true
  git -C "$ROOT" worktree add -b _gateproof "$base" HEAD >/dev/null 2>&1

  echo "  CASE A — fiction (empty branch, claims work, built nothing):"
  if reflect_check "$base" "echo PASS"; then echo "    RESULT: accepted ✗ BAD"; fails=1
  else echo "    RESULT: REJECTED ✓ (gate caught the fiction)"; fi

  echo "  CASE B — real change that passes its kill-switch:"
  echo "real work $(git -C "$ROOT" rev-parse --short HEAD)" > "$base/.gateproof.txt"
  git -C "$base" add .gateproof.txt >/dev/null 2>&1
  git -C "$base" commit -q -m "gateproof: real change" >/dev/null 2>&1
  if reflect_check "$base" "test -f .gateproof.txt"; then echo "    RESULT: ACCEPTED ✓ (real work passes)"
  else echo "    RESULT: rejected ✗ BAD"; fails=1; fi

  echo "  CASE C — real change but kill-switch RED (work that doesn't meet the goal):"
  if reflect_check "$base" "test -f .this-file-does-not-exist"; then echo "    RESULT: accepted ✗ BAD"; fails=1
  else echo "    RESULT: REJECTED ✓ (built something, but goal unmet)"; fi

  echo "  CASE D — GATE GAMED (cycle edits the .sh kill-switch to pass) [found live]:"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$base/fakegate.sh"
  git -C "$base" add fakegate.sh >/dev/null 2>&1
  git -C "$base" commit -q -m "gateproof: edit the gate" >/dev/null 2>&1
  if reflect_check "$base" "bash fakegate.sh"; then echo "    RESULT: accepted ✗ BAD (gate-gaming slipped through)"; fails=1
  else echo "    RESULT: REJECTED ✓ (caught the cycle editing its own gate)"; fi

  rm -rf "$base" 2>/dev/null
  git -C "$ROOT" worktree prune 2>/dev/null || true
  git -C "$ROOT" branch -D _gateproof 2>/dev/null || true
  if [ "$fails" -eq 0 ]; then echo "  GATE PROOF: 4/4 — rejects fiction, accepts real, rejects red-killswitch, rejects gate-gaming"; return 0; fi
  echo "  GATE PROOF: FAILED"; return 1
}

if $PROVE; then
  echo "[orchestrate] proving the anti-fabrication gate against real worktrees…"
  prove_gate; exit $?
fi

echo "[orchestrate] $( $GO && echo LIVE || echo DRY-RUN ) · up to $ITERS iteration(s) · trust floor $FLOOR" | tee "$RUNLOG"
echo "[orchestrate] current trust: $(trust_now)" | tee -a "$RUNLOG"

BUILT=(); PARKED=(); SKIPPED=()
SEEN=" "   # space-delimited set of slugs handled this run (in-memory, bash 3.2)
declare i=0
while [ "$i" -lt "$ITERS" ]; do
  i=$((i+1))

  # stop: trust floor
  t="$(trust_now)"
  if awk "BEGIN{exit !($t < $FLOOR)}"; then
    echo "[orchestrate] STOP — trust $t < floor $FLOOR (the ratchet refuses to proceed)" | tee -a "$RUNLOG"
    break
  fi

  # pick the highest-ranked READY plan not already in flight (on disk) or
  # already handled this run (in memory).
  pick=""
  while IFS= read -r cand; do
    [ -z "$cand" ] && continue
    case "$SEEN" in *" $cand "*) continue ;; esac
    if [ -d "$WT_BASE/$cand" ]; then SKIPPED+=("$cand:flight"); SEEN="$SEEN$cand "; continue; fi
    if ! _hermetic "$cand"; then
      echo "  ⤫ $cand — kill-switch hits prod/network → needs-human, not loop-safe" | tee -a "$RUNLOG"
      SKIPPED+=("$cand:needs-human"); SEEN="$SEEN$cand "; continue
    fi
    # classify only in live mode (it runs real test suites — too slow for dry).
    # Build ONLY genuine-armed; skip green (done), broken (would churn), unclear.
    if $GO; then
      case "$(_classify_armed "$cand")" in
        green)   echo "  ⟳ $cand — kill-switch already GREEN → goal met, skip" | tee -a "$RUNLOG"
                 SKIPPED+=("$cand:already-met"); SEEN="$SEEN$cand "; continue ;;
        broken)  echo "  ✗ $cand — BROKEN gate (runner can't start) → would churn, skip" | tee -a "$RUNLOG"
                 SKIPPED+=("$cand:broken-gate"); SEEN="$SEEN$cand "; continue ;;
        unclear) echo "  ? $cand — kill-switch unclear → needs-human, skip" | tee -a "$RUNLOG"
                 SKIPPED+=("$cand:unclear"); SEEN="$SEEN$cand "; continue ;;
        armed)   : ;;  # genuine fuel — proceed
      esac
    fi
    # autonomous mode: only build plans safe to run unattended (no open judgment)
    if $AUTONOMOUS && ! _autonomous_eligible "$cand"; then
      echo "  ⊘ $cand — open judgment (FEATURE/SCHEMA unclarified or no promise) → needs-human" | tee -a "$RUNLOG"
      SKIPPED+=("$cand:open-judgment"); SEEN="$SEEN$cand "; continue
    fi
    pick="$cand"; break
  done < <("$RANK" --top 20)

  if [ -z "$pick" ]; then
    echo "[orchestrate] STOP — ready-queue drained (no buildable plan left)" | tee -a "$RUNLOG"
    break
  fi

  SEEN="$SEEN$pick "   # committed to this pick — don't re-pick it this run
  echo "" | tee -a "$RUNLOG"
  echo "── iteration $i/$ITERS · plan: $pick · trust $t ──" | tee -a "$RUNLOG"

  if ! $GO; then
    echo "  DRY-RUN — would: worktree do/$pick → do-auto.sh (cycles+W4) → _reflect gate" | tee -a "$RUNLOG"
    echo "    gate: real-diff ∧ kill-switch[$(plan_outcome "$pick" | head -c 50)…] GREEN ∧ no regression" | tee -a "$RUNLOG"
    BUILT+=("$pick(dry)")
    continue
  fi

  # LIVE: build the plan (do-auto worktrees + cycles + W4 + digest)
  #
  # The log lives BESIDE the worktrees, never inside one. It used to be
  # "$WT_BASE/$pick/.orchestrate.log", which forced a `mkdir -p` of the worktree
  # path before do-auto ran — and that plain directory made do-auto's old
  # `rev-parse --git-dir` probe report "resuming worktree". `git worktree add`
  # then never ran, and every cycle commit targeted the MAIN tree's HEAD, where
  # _safe_stage refuses to stage: orchestrated cycles committed NOTHING, with no
  # error. do-auto now discriminates properly (see _is_worktree there); this side
  # removes the trigger, so neither half depends on the other being correct.
  #
  # Keeping it outside also means the log survives `git worktree remove`, which
  # is when you most want to read it.
  log="$WT_BASE/.logs/$pick.log"   # not `local` — this loop is top-level, not a function
  mkdir -p "$WT_BASE/.logs"
  echo "  ▶ building (log: $log)" | tee -a "$RUNLOG"
  if "$AUTO" "$pick" >"$log" 2>&1; then
    _link_deps "$WT_BASE/$pick"   # do-auto cut the worktree; ensure deps are linked
    if _reflect "$pick" | tee -a "$RUNLOG"; then
      echo "  ✅ $pick — VERIFIED, merge-ready on branch do/$pick" | tee -a "$RUNLOG"
      BUILT+=("$pick")
    else
      echo "  ⛔ $pick — reflect gate FAILED, branch parked for human review" | tee -a "$RUNLOG"
      PARKED+=("$pick")
    fi
  else
    echo "  ⛔ $pick — do-auto exited non-zero, parked" | tee -a "$RUNLOG"
    PARKED+=("$pick")
  fi
done

echo "" | tee -a "$RUNLOG"
echo "════ run summary ════" | tee -a "$RUNLOG"
echo "  built/verified : ${BUILT[*]:-none}" | tee -a "$RUNLOG"
echo "  parked (review): ${PARKED[*]:-none}" | tee -a "$RUNLOG"
echo "  skipped (flight): ${SKIPPED[*]:-none}" | tee -a "$RUNLOG"
$GO && echo "  → merge-ready branches await your review. NOTHING merged to main." | tee -a "$RUNLOG"
$GO || echo "  → DRY-RUN. Re-run with --go to build. Merge stays human until trust earns it." | tee -a "$RUNLOG"
