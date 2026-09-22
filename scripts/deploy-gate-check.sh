#!/usr/bin/env bash
# deploy-gate-check.sh — red proofs for the deploy gate wrappers. Ships nothing,
# deploys nothing, touches no service. Exits non-zero on failure.
#
# manifest: monorepo-only
#
# WHY. deploy.sh grew a memoised test gate, a cached build gate, and a rule that
# an unpaid deferred-pin debt refuses a deploy. Each is a place a gate could
# quietly stop biting, and a wiring check that only greps for a string proves
# nothing about behaviour. So the deferred-pin block is EXTRACTED VERBATIM from
# deploy.sh and executed against stubs -- a copy of it here would prove only that
# the copy works.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/.claude/scripts/deploy.sh"
fails=0

# --- deploy must NOT have re-wired tsc through the shared-lock cache --------
# It was wired that way for one commit and reverted on measurement: the five
# typechecks are 8s serial on a warm box and finish inside vitest's shadow, while
# tsc-cached.sh takes the same gate_lock do-reconcile.sh takes -- so a concurrent
# /do cycle could make the ship gate queue 900s and then go RED over nothing.
if grep -qE 'gate_start(_governed)? "tsc-\$\(echo "\$svc" \| tr / -\)" "\$svc" bunx tsc --noEmit' "$DEPLOY"; then
  echo "ok: typechecks run bare (no shared lock on the ship path)"
else
  echo "FAIL: the typecheck gate no longer runs bare — check the lock-contention note in deploy.sh"; fails=$((fails+1))
fi

# --- deploy must still call the cached build, not a bare `bun run build` -----
if grep -q 'gate_start_heavy build one.ie/web bash "\$ROOT/.claude/scripts/astro-build-cached.sh"' "$DEPLOY"; then
  echo "ok: the build gate routes through astro-build-cached.sh"
else
  echo "FAIL: the build gate no longer routes through astro-build-cached.sh"; fails=$((fails+1))
fi
# --- and the vitest gate must keep its pty, or it hangs on a log file --------
# The assertion names test-full.sh, NOT test-cached.sh, and that is the whole
# point of the edit that put it here. deploy.sh used to spell the vitest argv out
# itself and call test-cached.sh directly; test-full.sh was then created as the
# ONE definition of the full suite so deploy and /close could not present
# different argv to the memo and miss each other's stamps. This grep kept naming
# the old call, so it emitted "the vitest gate lost TEST_CACHE_PTY" over wiring
# that was correct -- a FALSE RED on a ship gate, which is the failure mode that
# gets a gate ignored. The pty is still set, twice: here, and per-lane at
# test-lanes.sh:102/107.
if grep -q 'TEST_CACHE_PTY=1 bash "\$ROOT/.claude/scripts/test-full.sh"' "$DEPLOY"; then
  echo "ok: the vitest gate runs through test-full.sh with a pty"
else
  echo "FAIL: the vitest gate lost TEST_CACHE_PTY — it will hang on a non-TTY stdout"; fails=$((fails+1))
fi

# --- and the memo behind that gate must actually MISS when the tree moves ----
# The line above is a wiring grep. This drives the real thing on one small
# selection: a cold MISS, then a HIT on identical inputs, then a MISS again after
# a source file the selection reads is edited. Without the third step a memo that
# always hit would look perfect -- and would hand deploy a green suite over a
# changed tree, which is the only way this optimisation can ship bad code.
_SEL="tests/unit/agents/subscribe-tags-parity.test.ts"
_SRC="one.ie/web/src/lib/in/spaces.ts"
if [ ! -d "$ROOT/one.ie/web/node_modules" ] || [ ! -f "$ROOT/$_SRC" ]; then
  # An unrunnable check is n/a. Never ok: a worktree without node_modules cannot
  # start vitest, and a startup crash exits non-zero for reasons that have
  # nothing to do with the property under test.
  echo "n/a: no one.ie/web/node_modules here — the memo drive cannot run (NOT a pass)"
else
  _mc="$(mktemp -d)"; _memo() { TEST_CACHE_DIR="$_mc" bash "$ROOT/.claude/scripts/test-cached.sh" \
        one.ie/web -- --reporter=dot "$_SEL" 2>&1; }
  m1="$(_memo)"; r1=$?
  m2="$(_memo)"; r2=$?
  if [ "$r1" -ne 0 ] || [ "$r2" -ne 0 ]; then
    echo "n/a: the probe selection did not pass, cannot measure the memo (NOT a pass)"
  else
    case "$m1" in *"cache HIT"*) echo "FAIL: a cold cache reported a HIT"; fails=$((fails+1));;
      *) echo "ok: a cold memo MISSES and runs the tests";; esac
    case "$m2" in *"cache HIT"*) echo "ok: identical inputs HIT the memo";;
      *) echo "FAIL: identical inputs did not hit — the memo buys nothing"; fails=$((fails+1));; esac
    # RED PROOF — move a source file the selection reads; the memo MUST miss.
    cp "$ROOT/$_SRC" "$_mc/src.bak"
    echo "// __deploy_gate_check_probe" >> "$ROOT/$_SRC"
    m3="$(_memo)"
    cp -f "$_mc/src.bak" "$ROOT/$_SRC"
    case "$m3" in *"cache HIT"*) echo "FAIL: a CHANGED tree replayed a cached PASS"; fails=$((fails+1));;
      *) echo "ok: a source edit invalidates the memo";; esac
  fi
  rm -rf "$_mc"
fi
# --- the memo probe: a hit must never queue for a slot ----------------------
# deploy's vitest gate runs under gate-run.sh, so it TOOK A SLOT and only then
# asked the memo whether there was anything to run. Measured 2026-09-13: 300s
# queued, then both lanes reported cache HIT.
#
# The block is EXTRACTED VERBATIM from deploy.sh and driven against a fake root
# and a SANDBOX cache -- a copy here would prove only that the copy works. Every
# axis that could touch the real thing is sandboxed: TEST_CACHE_DIR (a planted
# stamp replayed by a real deploy is the worst thing this file could do) and
# GOVERN_DIR (the only direct evidence that no slot was taken). The last two
# assertions are that neither real directory gained a file.
_probe_block="$(awk '/^# >>> vitest-memo-probe/{f=1} f{print} f&&/^# <<< vitest-memo-probe/{exit}' "$DEPLOY")"
_report_block="$(awk '/elif grep -q .SKIPPED by the memo probe./{f=1} f{print} f&&/^ *ok "\$TESTS_REPORT"$/{exit}' "$DEPLOY")"
if [ -z "$_probe_block" ] || [ -z "$_report_block" ]; then
  echo "FAIL: could not extract the memo-probe block(s) from deploy.sh — this checker is blind"; fails=$((fails+1))
else
  _sbcache="$(mktemp -d)"; _sbgov="$(mktemp -d)"; _froot="$(mktemp -d)"
  _real_cache="${TMPDIR:-/tmp}/one-test-cache"
  K1="$(printf 'lane-pool'   | shasum -a 256 | cut -d' ' -f1)"
  K2="$(printf 'lane-typedb' | shasum -a 256 | cut -d' ' -f1)"
  mkdir -p "$_froot/.claude/scripts"
  # a stand-in for test-full.sh under TEST_CACHE_KEY_ONLY=1: two lanes, two keys,
  # and the chatter test-lanes.sh prints around them.
  { echo 'echo "test-lanes: pool lane (8 forks) + typedb lane (19 files, serial) — concurrent"'
    echo "echo $K1"; echo "echo $K2"; } > "$_froot/.claude/scripts/test-full.sh"

  _drive_probe() { # <SKIP_TESTS> <want_astro> <ROOT> — prints a transcript
    local logd; logd="$(mktemp -d)"
    SKIP_TESTS_IN="$1" WANT_IN="$2" ROOT_IN="$3" LOGD_IN="$logd" \
    TEST_CACHE_DIR="$_sbcache" GOVERN_DIR="$_sbgov" \
    bash -c '
      set -uo pipefail
      say(){ printf "SAY %s\n" "$*"; }
      ok(){  printf "OK %s\n"  "$*"; }
      _spine_stage(){ [ "$1" = vitest ] && echo tests; }
      _emit(){ printf "EMIT %s\n" "$*"; }
      # the stub records a heavy registration the way the real one does, so
      # HEAVY=0 on the skip path is a fact and not an artefact of the stub.
      gate_start_heavy(){ printf "GATE_STARTED %s\n" "$1"; HEAVY_IDX+=(1); }
      ROOT="$ROOT_IN"; LOG_DIR="$LOGD_IN"; STAMP="probe"; DRY=0
      SKIP_TESTS="$SKIP_TESTS_IN"; want_astro="$WANT_IN"
      GATE_NAMES=(); GATE_PIDS=(); GATE_LOGS=(); GATE_RC=(); GATE_T=(); GATE_DUR=(); HEAVY_IDX=()
      '"$_probe_block"'
      printf "GATES=%s RC=%s HEAVY=%s\n" "${#GATE_NAMES[@]}" "${GATE_RC[0]:-none}" "${#HEAVY_IDX[@]}"
      if [ "${#GATE_LOGS[@]}" -gt 0 ]; then sed "s/^/LOG /" "${GATE_LOGS[0]}"; fi
      exit 0'
    rm -rf "$logd"
  }

  # (a) every lane stamped ⇒ the gate is SKIPPED, counted, and passed
  date -u +%Y-%m-%dT%H:%M:%SZ > "$_sbcache/one.ie_web-$K1.pass"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$_sbcache/one.ie_web-$K2.pass"
  _p_hit="$(_drive_probe 0 1 "$_froot")"
  case "$_p_hit" in
    *GATE_STARTED*) echo "FAIL: every lane stamped and the gate still took a slot"; fails=$((fails+1)) ;;
    *) echo "ok: every lane stamped — the gate is skipped, no slot taken" ;;
  esac
  case "$_p_hit" in
    *"GATES=1 RC=0"*) echo "ok: the skipped gate is still COUNTED as a passed gate" ;;
    *) echo "FAIL: a memo-skipped gate was not recorded as a passed gate: $_p_hit"; fails=$((fails+1)) ;;
  esac
  # The hazard a stubbed gate_start_heavy would hide: a placeholder pid in
  # HEAVY_IDX makes the NEXT heavy gate `wait 0` (exit 127 — verified) and
  # overwrite this gate's rc with 1. A gate with no process is not a heavy gate.
  case "$_p_hit" in
    *HEAVY=0*) echo "ok: the skipped gate is not in HEAVY_IDX (no wait on a non-child)" ;;
    *) echo "FAIL: a process-less gate entered HEAVY_IDX — the next heavy gate will mark it FAILED"; fails=$((fails+1)) ;;
  esac
  # …and the report it produces must say REUSED, never "all pass", and carry the
  # stamp's timestamp. Driven through deploy.sh's OWN report branch, extracted.
  _skiplog="$(mktemp)"
  printf '%s\n' "$_p_hit" | sed -n 's/^LOG //p' > "$_skiplog"
  _rep="$( glog="$_skiplog" bash -c '
             ok(){ printf "OK %s\n" "$*"; }; TESTS_REPORT=""
             if false; then :
             '"$_report_block"'
             fi
             printf "REPORT=%s\n" "$TESTS_REPORT"' )"
  case "$_rep" in
    *"REUSED — identical inputs already passed"*"already PASSED 20"*)
      echo "ok: the skip reports REUSED with the stamp's timestamp" ;;
    *) echo "FAIL: the skip did not report REUSED with a timestamp: $_rep"; fails=$((fails+1)) ;;
  esac
  case "$_rep" in
    *"all pass"*) echo "FAIL: a memo hit was reported as 'all pass'"; fails=$((fails+1)) ;;
    *) echo "ok: a reused pass is never reported as 'all pass'" ;;
  esac
  # (b) RED HALF — ONE lane unstamped ⇒ the gate RUNS. This is the whole reason
  # the probe does not read test-lanes.sh's exit code: under
  # TYPEDB_LANE_NONBLOCKING=1 that code is the POOL lane's alone, so a pool-only
  # hit would skip a typedb lane that had never run.
  rm -f "$_sbcache/one.ie_web-$K2.pass"
  _p_miss="$(_drive_probe 0 1 "$_froot")"
  case "$_p_miss" in
    *GATE_STARTED*) echo "ok: one lane unstamped — the gate RUNS (pool-only hit cannot skip it)" ;;
    *) echo "FAIL: a pool-only hit skipped the gate — the typedb lane would never run"; fails=$((fails+1)) ;;
  esac
  case "$_p_miss" in *"memo probe: MISS"*) echo "ok: the miss is named in the report" ;;
    *) echo "FAIL: a miss ran the gate without saying why"; fails=$((fails+1)) ;; esac
  # (c) RED HALF — a probe that cannot answer runs the gate. An unrun check is
  # not a pass, and neither is an unanswerable one.
  echo 'exit 1' > "$_froot/.claude/scripts/test-full.sh"
  _p_unk="$(_drive_probe 0 1 "$_froot")"
  case "$_p_unk" in
    *GATE_STARTED*) echo "ok: a probe that cannot answer runs the gate" ;;
    *) echo "FAIL: an unanswerable probe skipped the gate"; fails=$((fails+1)) ;;
  esac
  # (d) --skip-tests keeps its own meaning: no gate at all, even with every lane
  # stamped. A skipped suite is not a reused one.
  { echo "echo $K1"; } > "$_froot/.claude/scripts/test-full.sh"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$_sbcache/one.ie_web-$K1.pass"
  _p_skip="$(_drive_probe 1 1 "$_froot")"
  case "$_p_skip" in
    *GATE_STARTED*|*GATES=1*) echo "FAIL: --skip-tests registered a gate"; fails=$((fails+1)) ;;
    *) echo "ok: --skip-tests still skips distinctly (no gate, no memo report)" ;;
  esac
  # the real test-full.sh must actually print a key per lane, or the probe above
  # answers `2` forever and the change buys nothing. KEY_ONLY runs no vitest.
  if [ -d "$ROOT/one.ie/web" ]; then
    _rkeys="$( cd "$ROOT" && TEST_CACHE_KEY_ONLY=1 TEST_CACHE_DIR="$_sbcache" \
                 bash "$ROOT/.claude/scripts/test-full.sh" 2>/dev/null | grep -Ec '^[0-9a-f]{64}$' )"
    if [ "${_rkeys:-0}" -ge 2 ]; then echo "ok: the real full suite prints $_rkeys lane keys (probe can answer)"
    else echo "FAIL: the real full suite printed ${_rkeys:-0} lane key(s) — the probe cannot answer"; fails=$((fails+1)); fi
  else
    echo "n/a: no one.ie/web here — the real lane-key probe cannot run (NOT a pass)"
  fi
  # NOTHING MAY LEAK — and the assertion is by CONTENT, not by count. release.sh's
  # self-test compares file counts either side (release.sh:304-307); here that is a
  # FALSE RED waiting to happen, because both directories are machine-wide and
  # every other session on the box writes to them. Measured while writing this:
  # the real governor dir went 161 -> 162 -> 163 inside one minute under two
  # neighbouring `gate-run.sh verify-fast` processes, with nothing here running.
  # So ask the precise question instead: did a PLANTED stamp reach the real cache?
  _leaked=0
  for _k in "$K1" "$K2"; do
    for _f in "$_real_cache"/*"$_k".pass; do [ -f "$_f" ] && _leaked=$((_leaked+1)); done
  done
  if [ "$_leaked" -eq 0 ]; then echo "ok: no planted stamp leaked into the real cache"
  else echo "FAIL: $_leaked planted stamp(s) reached the REAL cache — a future deploy could replay them"; fails=$((fails+1)); fi
  # …and the slot. GOVERN_DIR is exported into the driven block, so a gate-run
  # underneath it would leave its lock/slot HERE. An empty sandbox is the direct
  # evidence that the hit path took no slot — the whole point of the change.
  if [ -z "$(ls "$_sbgov" 2>/dev/null)" ]; then echo "ok: the probe took no governor slot at all (sandbox GOVERN_DIR empty)"
  else echo "FAIL: the probe touched its governor dir — it is taking a slot"; fails=$((fails+1)); fi
  rm -rf "$_sbcache" "$_sbgov" "$_froot" "$_skiplog"
fi

# --- the typedb lane: NOT waited on, and an unfinished lane is never green ---
# The lane runs as its OWN gate (deploy.sh `gate 1b`) and the collection loop
# refuses to `wait` on it -- waiting for it was the ~89s the split removed
# (pool 29.6s CPU-bound vs typedb 118.8s network-bound, measured 2026-09-21).
# That buys a third state, and the third state is the whole risk: a lane that has
# not finished must render `unrun`, never `pass`. All three blocks are EXTRACTED
# VERBATIM from deploy.sh and driven -- a copy here would prove only the copy.
# THE TERMINATOR MAY NOT BE THE THING UNDER TEST. The first cut of this ended
# the rc-read block on `else rc=-1; fi` and the receipt block on `_res=pass` --
# so breaking either literal (the exact defect being guarded) broke the
# EXTRACTION instead, and the checker went red with an empty reading and a
# confusing message rather than measuring the wrong answer. Both now end on a
# STRUCTURAL neighbour: the `elif wait` that follows the branch, and the printf
# that follows the receipt's result mapping.
_tdb_block="$(awk '/^  elif \[\[ "\$name" == typedb \]\]; then/{f=1} f&&/^  elif wait /{exit} f{print}' "$DEPLOY")"
_case_block="$(awk '/^    typedb\)/{f=1} f{print} f&&/^      fi ;;$/{exit}' "$DEPLOY")"
_res_block="$(awk '/^ *if   \(\( \$\{GATE_RC\[\$i\]\}/{f=1} f&&/^ *printf/{exit} f{print}' "$DEPLOY")"
if [ -z "$_tdb_block" ] || [ -z "$_case_block" ] || [ -z "$_res_block" ]; then
  echo "FAIL: could not extract the typedb-lane block(s) from deploy.sh — this checker is blind"; fails=$((fails+1))
else
  # (a) the rc read: marker present ⇒ that rc; marker ABSENT ⇒ -1, never 0.
  _drive_tdb() { # <marker contents|"">  — prints RC=<n>
    local f; f="$(mktemp)"
    if [ -n "$1" ]; then printf '%s\n' "$1" > "$f"; else rm -f "$f"; fi
    bash -c '
      set -uo pipefail
      name=typedb; TYPEDB_RC_FILE="'"$f"'"; GATE_RC=(-1); i=0
      if false; then :
      '"$_tdb_block"'
      fi
      printf "RC=%s\n" "$rc"'
    rm -f "$f"
  }
  case "$(_drive_tdb '')" in
    RC=-1) echo "ok: an unfinished typedb lane reads rc=-1 (unrun), not 0" ;;
    *) echo "FAIL: an unfinished typedb lane read $(_drive_tdb '') — a lane that did not run must never read as a pass"; fails=$((fails+1)) ;;
  esac
  case "$(_drive_tdb 0)" in RC=0) echo "ok: a finished green typedb lane reads rc=0" ;;
    *) echo "FAIL: a green typedb marker did not read 0"; fails=$((fails+1)) ;; esac
  case "$(_drive_tdb 1)" in RC=1) echo "ok: a finished red typedb lane reads rc=1" ;;
    *) echo "FAIL: a red typedb marker did not read 1"; fails=$((fails+1)) ;; esac

  # (b) the receipt rendering of those three states. -1 MUST be `unrun`.
  _drive_res() { # <rc> — prints the receipt's result word
    bash -c '
      set -uo pipefail
      GATE_RC=('"$1"'); i=0
      '"$_res_block"'
      printf "%s\n" "$_res"'
  }
  _r_unrun="$(_drive_res -1)"; _r_fail="$(_drive_res 1)"; _r_pass="$(_drive_res 0)"
  if [ "$_r_unrun" = unrun ] && [ "$_r_fail" = fail ] && [ "$_r_pass" = pass ]; then
    echo "ok: the receipt renders -1/1/0 as unrun/fail/pass"
  else
    echo "FAIL: the receipt rendered -1='$_r_unrun' 1='$_r_fail' 0='$_r_pass'"; fails=$((fails+1))
  fi

  # (c) and none of the three may append to gate_fail — the non-blocking rule.
  # An unrun or red lane must still be SAID: a red nobody prints is a lane that
  # has quietly stopped meaning anything.
  _drive_case() { # <rc> — prints the transcript plus GATEFAIL=<n>
    bash -c '
      set -uo pipefail
      warn(){ printf "WARN %s\n" "$*"; }; ok(){ printf "OK %s\n" "$*"; }
      rc='"$1"'; name=typedb; glog=/dev/null; gate_fail=(); TYPEDB_REPORT=""
      case "$name" in
      '"$_case_block"'
      esac
      printf "REPORT=%s GATEFAIL=%s\n" "$TYPEDB_REPORT" "${#gate_fail[@]}"'
  }
  _gf_fails0=$fails
  for _rc in -1 1 0; do
    _out="$(_drive_case "$_rc")"
    case "$_out" in
      *GATEFAIL=0*) : ;;
      *) echo "FAIL: a typedb lane rc=$_rc appended to gate_fail — it would refuse the deploy: $_out"; fails=$((fails+1)) ;;
    esac
    case "$_out" in
      *WARN*|*OK*) : ;;
      *) echo "FAIL: a typedb lane rc=$_rc printed nothing at all: $_out"; fails=$((fails+1)) ;;
    esac
  done
  # Only claim it when the loop above actually found nothing — an unconditional
  # summary line printed `ok` directly under its own FAIL.
  [ "$fails" -eq "$_gf_fails0" ] && echo "ok: no typedb rc (-1/1/0) reaches gate_fail, and each one is printed"
  case "$(_drive_case -1)" in
    *"never a pass"*) echo "ok: the unrun report says so in words, not only in a code" ;;
    *) echo "FAIL: the unrun report does not name itself unrun"; fails=$((fails+1)) ;;
  esac
  # RED PROOF — gut the rc read the way a future edit would ("just wait for it,
  # it is usually done") and assert this checker goes RED. A checker that stays
  # green against a broken block proves nothing.
  _broken_out="$( bash -c '
      set -uo pipefail
      name=typedb; TYPEDB_RC_FILE="/nonexistent-$$"
      if false; then :
      '"$(printf '%s\n' "$_tdb_block" | sed 's/else rc=-1; fi/else rc=0; fi/')"'
      fi
      printf "RC=%s\n" "$rc"' )"
  case "$_broken_out" in
    RC=0) echo "ok: red proof — an unfinished lane defaulting to 0 is exactly what assertion (a) catches" ;;
    *) echo "FAIL: the red proof did not reproduce the defect ($_broken_out) — assertion (a) may be vacuous"; fails=$((fails+1)) ;;
  esac
fi

# --- every `wait` in deploy.sh must name a pid -------------------------------
# This one is syntactic, so a grep is the right instrument -- but it is a grep
# with a red proof: reintroduce the bare form and the count goes to 1.
# `wait -n` was correct here only by ACCIDENT: /bin/bash and `env bash` are both
# 3.2.57, where -n is an invalid option that returns in 0s. On bash >= 4.3 it
# waits for the NEXT job to finish, and deploy.sh now backgrounds a test lane it
# deliberately never waits for -- so the verdict would block on that lane for up
# to GATE_BOUND (900s), on the --gates-only path release.sh promote takes.
# Comments are stripped first: this file and deploy.sh both DISCUSS `wait -n`.
# The rule stated positively: a `wait` is followed by a QUOTED pid expression.
# Anything else -- `wait`, `wait -n`, `wait $pid` -- is flagged. The first cut of
# this regex looked for `wait -n` at END OF STATEMENT and MISSED the real line
# (`wait -n 2>/dev/null || true`), staying GREEN against the reintroduced defect.
# Which is why it is red-driven, not merely written.
_bad_waits="$(sed 's/#.*//' "$DEPLOY" | grep -nE '(^|[^A-Za-z_])wait([[:space:]]+[^"[:space:]]|[[:space:]]*(;|[|]|$))' || true)"
if [ -z "$_bad_waits" ]; then
  echo "ok: every wait in deploy.sh names a pid (no bare/-n wait to swallow a test lane)"
else
  echo "FAIL: deploy.sh has a wait that names no pid — on bash >= 4.3 it waits for whatever finishes next, which is the typedb lane:"
  printf '%s\n' "$_bad_waits" | sed 's/^/    /'; fails=$((fails+1))
fi

# --- the split is CONDITIONAL, and both branches must be driven -------------
# The typedb lane only becomes its own gate when the heavy gates can overlap.
# Serialised (HEAVY_PARALLEL=0, the common case on a box with <14GB free), the
# typedb gate would start microseconds before the collection loop read its
# marker, so the receipt would say `unrun` on EVERY deploy -- a field that can
# only answer one way, which is a deleted gate wearing a different word. The
# serialised path therefore takes the OLD single gate with
# TYPEDB_LANE_NONBLOCKING=1, where the rc is visible in that gate's log as it
# always was. A branch nobody drives is `unrun`, so both are driven here, off
# the SAME verbatim block deploy.sh runs.
if [ -z "${_probe_block:-}" ]; then
  echo "FAIL: no probe block to drive the HEAVY_PARALLEL branches with"; fails=$((fails+1))
else
  _sb2="$(mktemp -d)"; _fr2="$(mktemp -d)"; mkdir -p "$_fr2/.claude/scripts"
  # a stand-in test-full.sh whose key has no stamp, so the probe MISSES and the
  # gate is actually launched -- the hit path launches nothing to inspect.
  echo "echo $(printf 'no-stamp-%s' $$ | shasum -a 256 | cut -d' ' -f1)" > "$_fr2/.claude/scripts/test-full.sh"
  _drive_hp() { # <HEAVY_PARALLEL> — prints the full command each gate was started with
    local logd; logd="$(mktemp -d)"
    HP_IN="$1" ROOT_IN="$_fr2" LOGD_IN="$logd" TEST_CACHE_DIR="$_sb2" GOVERN_DIR="$_sb2" \
    bash -c '
      set -uo pipefail
      say(){ :; }; ok(){ :; }; _spine_stage(){ [ "$1" = tests ] && echo tests; }; _emit(){ :; }
      gate_start_heavy(){ printf "GATE %s\n" "$*"; HEAVY_IDX+=(1); }
      ROOT="$ROOT_IN"; LOG_DIR="$LOGD_IN"; STAMP="probe"; DRY=0
      SKIP_TESTS=0; want_astro=1; HEAVY_PARALLEL="$HP_IN"
      GATE_NAMES=(); GATE_PIDS=(); GATE_LOGS=(); GATE_RC=(); GATE_T=(); GATE_DUR=(); HEAVY_IDX=()
      '"$_probe_block"'
      exit 0'
    rm -rf "$logd"
  }
  _hp1="$(_drive_hp 1)"; _hp0="$(_drive_hp 0)"
  case "$_hp1" in
    *TEST_LANES_ONLY=pool*) echo "ok: HEAVY_PARALLEL=1 runs the suite gate POOL-ONLY (the split)" ;;
    *) echo "FAIL: HEAVY_PARALLEL=1 did not take the split path: $_hp1"; fails=$((fails+1)) ;;
  esac
  case "$_hp1" in
    *TYPEDB_LANE_NONBLOCKING*) echo "FAIL: the split path still carries TYPEDB_LANE_NONBLOCKING — that flag exits 0 on a green pool lane, and there is no pool lane in the typedb gate"; fails=$((fails+1)) ;;
    *) echo "ok: the split path does not carry TYPEDB_LANE_NONBLOCKING" ;;
  esac
  case "$_hp0" in
    *TYPEDB_LANE_NONBLOCKING=1*) echo "ok: HEAVY_PARALLEL=0 keeps the OLD single gate, both lanes, rc still reported" ;;
    *) echo "FAIL: the serialised path no longer takes the old both-lanes gate: $_hp0"; fails=$((fails+1)) ;;
  esac
  case "$_hp0" in
    *TEST_LANES_ONLY*) echo "FAIL: the serialised path split the lanes — its typedb gate could only ever read \`unrun\`"; fails=$((fails+1)) ;;
    *) echo "ok: the serialised path does not split (no dead \`unrun\` field)" ;;
  esac
  # …and exactly ONE suite gate either way. Two would double the pool lane.
  _bad=0
  for _v in "$_hp1" "$_hp0"; do
    _n=$(printf '%s\n' "$_v" | grep -c '^GATE .*one\.ie/web ')
    [ "$_n" -eq 1 ] || { echo "FAIL: expected exactly 1 suite gate on a branch, got $_n"; fails=$((fails+1)); _bad=1; }
  done
  [ "$_bad" -eq 0 ] && echo "ok: exactly one suite gate on each branch"
  rm -rf "$_sb2" "$_fr2"
fi

# --- the deferred-pin ledger: driven, not grepped ---------------------------
# Extract deploy.sh's debt block verbatim and run it with stubbed reporters. The
# block is the last chance a deferred pin has to come due: verify-fast.sh settles
# the ledger only in its own FULL_VERIFY branch, and deploy sets FULL_VERIFY=1 but
# invokes the suite directly -- so before this block existed, a production deploy
# shipped straight over pins that no run had ever executed.
_debt_block="$(awk '/^DEBT_FILE=/{f=1} f{print} f&&/^fi$/{exit}' "$DEPLOY")"
if [ -z "$_debt_block" ]; then
  echo "FAIL: could not extract the debt block from deploy.sh — this checker is blind"; fails=$((fails+1))
else
  _drive_debt() { # <ledger-contents|""> <SKIP_TESTS> <TESTS_REPORT>
    local led; led="$(mktemp)"
    [ -n "$1" ] && printf '%s\n' "$1" > "$led" || : > "$led"
    VERIFY_FAST_DEBT_FILE="$led" SKIP_TESTS="$2" TESTS_REPORT="$3" LOG=/dev/null \
      bash -c '
        say(){ printf "%s\n" "$*"; }; step(){ :; }; ok(){ printf "ok %s\n" "$*"; }
        die(){ printf "DIE %s\n" "$*"; exit 1; }
        '"$_debt_block"'
        exit 0' >/dev/null 2>&1
    local rc=$?; rm -f "$led"; return $rc
  }
  # RED PROOF — an outstanding debt with a SKIPPED suite must refuse the deploy.
  if _drive_debt "pins deferred at cycle C3" 1 "skipped"; then
    echo "FAIL: an unpaid pin debt did NOT refuse a --skip-tests deploy"; fails=$((fails+1))
  else echo "ok: an unpaid pin debt refuses a test-skipping deploy"; fi
  # RED PROOF — the same debt with no suite REPORT must refuse too (an unrun gate
  # is not a passing gate, whatever the flags said).
  if _drive_debt "pins deferred at cycle C3" 0 "skipped"; then
    echo "FAIL: an unpaid debt passed with no suite result"; fails=$((fails+1))
  else echo "ok: an unpaid debt with no suite result refuses"; fi
  # GREEN half — a debt paid by a green full suite must let the deploy through,
  # or the two proofs above are just a gate that always says no.
  if _drive_debt "pins deferred at cycle C3" 0 "Tests 10780 passed"; then
    echo "ok: a green full suite settles the debt and the deploy continues"
  else echo "FAIL: a green full suite did not settle the debt"; fails=$((fails+1)); fi
  # …and a suite the MEMO PROBE reused pays the debt exactly as a cache HIT does.
  # The probe skips a gate whose lanes are all green stamps, so the pins ran when
  # those stamps were minted — but the debt block reads TESTS_REPORT, so the new
  # wording has to keep settling it or a memo hit would refuse every deploy.
  if _drive_debt "pins deferred at cycle C3" 0 \
       "full suite REUSED — identical inputs already passed (memo probe, no slot taken: already PASSED 2026-09-13T00:00:00Z)"; then
    echo "ok: a memo-probe REUSED suite settles the debt"
  else echo "FAIL: a memo-probe REUSED suite did not settle the debt"; fails=$((fails+1)); fi
  # and an EMPTY ledger must never block anything
  if _drive_debt "" 1 "skipped"; then echo "ok: no debt, no refusal"
  else echo "FAIL: an empty ledger blocked the deploy"; fails=$((fails+1)); fi
fi

echo ""
[ "$fails" -eq 0 ] && { echo "deploy-gate-check: PASS"; exit 0; }
echo "deploy-gate-check: FAILED ($fails)"; exit 1
