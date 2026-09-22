#!/usr/bin/env bash
# do-test-gate.sh — a vitest accept clause that cannot pass vacuously.
#
# manifest: portable
#
# WHY THIS EXISTS. A promise `accept:` of the form
#     ( cd <workdir> && bunx vitest run tests/unit/<slug>.test.ts )
# is not proof. Measured on vitest 4.1.7 in this repo (2026-08-18):
#   · a test file full of `it.skip(...)`          → exit 0
#   · `-t "name-that-does-not-exist"`             → exit 0, "10 skipped"
#   · a file containing only `it('x', () => {})`  → exit 0
# The only shape that DOES go red is a missing file ("No test files found",
# exit 1). So the clause proves the file exists — the same class of claim as a
# presence grep, and the same trap: the cycle that must pass the check is the
# cycle that authors the file.
#
# This gate asserts the run actually EXERCISED something: at least <min> tests
# passed, zero failed, and zero were pending/skipped. A skipped test is a hole,
# not a pass — `it.skip` in a security accept is the failure mode this closes.
#
# WHAT IT CANNOT SEE, named so nobody mistakes the floor for more than it is:
# vitest's json report carries no assertion count, so `it('x', () => {})`
# reports `numPassedTests: 1` and counts toward <min> like any other row. The
# gate's defence against a body that asserts nothing is the FLOOR and nothing
# else — pick a <min> equal to the number of behaviours the rung actually
# claims, never 1 "to be safe". `min` below 1 is refused (exit 2) precisely
# because a floor of zero is the vacuous pass this script exists to stop.
#
# Usage:  do-test-gate.sh <workdir> <min-passed> <test-file> [<test-file>...]
#         do-test-gate.sh --self-test
# Example (inside a promise accept:):
#   bash .claude/scripts/do-test-gate.sh <workdir> 4 tests/unit/<slug>-persona.test.ts
#
# <workdir> is repo-relative, or absolute (the self-test's sandbox is a temp dir
# outside the tree, and one.ie/web's `include:` is an ALLOWLIST, so a fixture
# planted under it would collect zero files and go red for the wrong reason).
#
# Exit codes — distinct and named:
#   0  the run exercised >= min tests, none failed, none skipped
#   1  FAIL — a test failed, a test was skipped, the floor was not met, a named
#      file is missing, or no json report was produced (the run did not start)
#   2  usage — no test files, <min> not an integer, or <min> < 1
#   3  --self-test only: every deterministic check passed but the LIVE vitest
#      fixtures could not run (no vitest in this checkout). Not proven, so not 0.
set -uo pipefail

S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$S/../.." && pwd)"
GATE_RUN="$S/gate-run.sh"

# ---------------------------------------------------------------------------
# self-test — a vacuous vitest must not pass, and the checker must go RED
#
# Two halves, because they answer different questions:
#   LIVE        real vitest over real temp fixtures. This is the only thing that
#               can prove the PREMISE in the header — that vitest itself exits 0
#               on an all-`it.skip` file while this gate exits 1. A claim about
#               another tool's exit code is worth nothing unasked.
#   INJECTED    a canned json report (DO_TEST_GATE_FAKE_REPORT, honoured only
#               under DO_TEST_GATE_SELFTEST=1 — the TSC_CACHE_CMD idiom) drives
#               the verdict branches that do not need a process: failed, skipped,
#               below the floor, zero collected, no report at all.
# The split is not tidiness. Six separate gate-run.sh calls queue six times on a
# busy box — measured 2026-09-21 with five sibling gates in this worktree: the
# FIRST of six never got a slot in three minutes and the run was reaped at 144.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  fails=0; checks=0
  T="$(mktemp -d -t do-test-gate-selftest.XXXXXX)"
  trap 'rm -rf "$T"' EXIT
  ok()  { checks=$((checks+1)); printf '  ok   %s\n' "$*"; }
  bad() { checks=$((checks+1)); fails=$((fails+1)); printf '  FAIL %s\n' "$*"; }

  # run <expected-exit> <label> -- <args to the gate>
  run() {
    local want="$1" label="$2"; shift 2; [ "${1:-}" = "--" ] && shift
    local out rc
    out="$(bash "$0" "$@" 2>&1)"; rc=$?
    if [ "$rc" = "$want" ]; then ok "$label (exit $rc)"
    else bad "$label — expected exit $want, got $rc"; printf '%s\n' "$out" | tail -4 | sed 's/^/       /'; fi
    LAST_OUT="$out"
  }
  # inject <json> <expected-exit> <label> -- <args>
  inject() {
    local json="$1"; shift
    printf '%s' "$json" > "$T/report.json"
    DO_TEST_GATE_SELFTEST=1 DO_TEST_GATE_FAKE_REPORT="$T/report.json" run "$@"
  }

  mkdir -p "$T/box"
  : > "$T/box/stub.test.ts"        # exists, so the missing-file guard passes

  echo "== usage: every refusal has its own code"
  run 2 "no test files given"                  -- "$T/box" 2
  run 2 "min-passed not an integer"            -- "$T/box" abc stub.test.ts
  run 2 "min-passed 0 is refused (a floor of zero IS the vacuous pass)" -- "$T/box" 0 stub.test.ts
  run 2 "min-passed negative is refused"       -- "$T/box" -1 stub.test.ts
  run 1 "a named file that does not exist is FAIL, not 'no test files found'" -- "$T/box" 1 nope.test.ts
  case "$LAST_OUT" in *"missing test file"*) ok "the missing file is NAMED" ;; *) bad "missing file not named: $LAST_OUT" ;; esac

  echo "== INJECTED: the verdict branches, driven from a canned report"
  inject '{"numPassedTests":4,"numFailedTests":0,"numPendingTests":0}' 0 \
    "4 passed, floor 4 → pass" -- "$T/box" 4 stub.test.ts
  inject '{"numPassedTests":0,"numFailedTests":0,"numPendingTests":0}' 1 \
    "ZERO collected, zero failed → FAIL (vitest's own verdict here is success)" -- "$T/box" 1 stub.test.ts
  inject '{"numPassedTests":0,"numFailedTests":0,"numPendingTests":7}' 1 \
    "7 skipped, 0 failed → FAIL (a skipped assertion is a hole)" -- "$T/box" 1 stub.test.ts
  case "$LAST_OUT" in *"skipped"*) ok "the skip is NAMED as the reason" ;; *) bad "skip not named: $LAST_OUT" ;; esac
  inject '{"numPassedTests":9,"numFailedTests":0,"numPendingTests":1}' 1 \
    "9 passed but 1 skipped → FAIL (one hole is enough)" -- "$T/box" 1 stub.test.ts
  inject '{"numPassedTests":3,"numFailedTests":1,"numPendingTests":0}' 1 \
    "1 failed → FAIL" -- "$T/box" 1 stub.test.ts
  inject '{"numPassedTests":2,"numFailedTests":0,"numPendingTests":0}' 1 \
    "2 passed under a floor of 5 → FAIL" -- "$T/box" 5 stub.test.ts
  case "$LAST_OUT" in *"expected >= 5"*) ok "the floor that bit is NAMED" ;; *) bad "floor not named: $LAST_OUT" ;; esac
  inject 'not json at all' 1 \
    "an unparseable report → FAIL (the run did not start)" -- "$T/box" 1 stub.test.ts
  DO_TEST_GATE_SELFTEST=1 DO_TEST_GATE_FAKE_REPORT="$T/absent.json" \
    run 1 "no report file at all → FAIL, never green" -- "$T/box" 1 stub.test.ts

  echo "== LIVE: real vitest, real fixtures — the premise this gate is built on"
  vhome=""
  # Each candidate is tested with -x and "$ROOT" is last, so a downstream clone
  # that has none of them still resolves — these are probes, not dependencies.
  for c in "$ROOT/one.ie/web" "$ROOT/channels" "$ROOT/packages/sdk" "$ROOT/packages/cli" "$ROOT"; do  # portability-ok: probe candidates, each -x tested, "$ROOT" last
    [ -x "$c/node_modules/.bin/vitest" ] && { vhome="$c"; break; }
  done
  # DO_TEST_GATE_NO_LIVE=1 — run the INJECTED half only.
  #
  # WHY THIS EXISTS, and it is NOT "the live half is slow". Measured 2026-09-21
  # on this box: with a slot already held (GOVERN_IN_GATE=1) the live half costs
  # **2s** and the whole self-test is 22/22. The 28s a bare shell shows is ~26s
  # of governor QUEUEING plus 2s of work — the same misreading the root manual
  # warns about ("Measure with vitest's own Duration, never the elapsed time of
  # a gate-run.sh call").
  #
  # The reason is the SLOT, not the seconds. The vitest wrapper that keeps this
  # self-test running (one.ie/web/tests/unit/scripts/selftest-do-test-gate.test.ts
  # — a .sh is in no import graph, so a pin is the only thing that runs it) is
  # itself a vitest process, and the live half then does one of two things:
  #   · it INHERITS the caller's slot (GOVERN_IN_GATE=1, the normal case) and
  #     costs 2s; or
  #   · it does not, and QUEUES for one — up to GOVERN_QUEUE_WAIT, default 600s,
  #     inside the gate that runs on every edit. That is the shape that queued
  #     696s for one agent on 2026-09-21 and expired another at 1500s. And when
  #     the wait runs out the script exits 3 honestly, which a wrapper asserting
  #     0 reads as RED for an ENVIRONMENT reason on a gate whose job is to judge
  #     the CODE.
  # So the half that can neither queue nor false-red — 16 checks, no process, no
  # slot, ~0.2s — is what the edit gate takes. The half that needs a process runs
  # in the FULL suite, which already holds a slot and is the lane where "the box
  # could not run this" is the right answer rather than an interruption.
  #
  # It does NOT invent a pass. This lands on the existing live_unrun path, so the
  # run exits 3 — "every deterministic check passed but the LIVE fixtures could
  # not run. Not proven, so not 0." An opt-out that answered 0 would be the
  # vacuous pass this whole script exists to refuse. The live half keeps a home
  # that actually runs it: tests/unit/scripts/do-test-gate-live.test.ts, which
  # carries no `selftest-` prefix and is therefore NOT pinned — it runs in the
  # FULL suite (`/close`, `./deploy`), never in the fast lane.
  if [ "${DO_TEST_GATE_NO_LIVE:-0}" = "1" ]; then
    vhome=""
    no_live_reason=" (DO_TEST_GATE_NO_LIVE=1 — the injected half only)"
  else
    no_live_reason=""
  fi
  live_unrun=0
  # ONE slot for the WHOLE live half, taken here and not at the top of the
  # self-test: the injected checks above need no process and must stay instant,
  # while six separate gate-run.sh calls would queue six times. Measured
  # 2026-09-21 with five sibling gates in this worktree: the machine funded ONE
  # slot, and wrapping the whole self-test left the proof queueing with nothing
  # to show. Holding the slot ourselves and exporting GOVERN_IN_GATE makes every
  # nested gate-run.sh below inherit it — gate-run.sh's own re-entrancy rule.
  if [ -n "$vhome" ] && [ "${GOVERN_IN_GATE:-0}" != "1" ] && [ -f "$S/lib/govern.sh" ]; then
    # shellcheck disable=SC1091
    . "$S/lib/govern.sh"
    trap 'gate_release_all 2>/dev/null; rm -rf "$T"' EXIT
    if gate_slot "${GOVERN_QUEUE_WAIT:-600}"; then
      export GOVERN_IN_GATE=1
    else
      vhome=""
      echo "  UNRUN no governor slot in ${GOVERN_QUEUE_WAIT:-600}s — the box is saturated, not the code."
    fi
  fi
  if [ -z "$vhome" ]; then
    live_unrun=1
    echo "  UNRUN the live vitest fixtures could not run (no vitest in this checkout, or no slot)${no_live_reason}."
  else
    L="$T/live"; mkdir -p "$L"
    ln -s "$vhome/node_modules" "$L/node_modules"
    printf '{"name":"do-test-gate-selftest","private":true,"type":"module"}\n' > "$L/package.json"
    cat > "$L/pass.test.ts"  <<'FIX'
import { it, expect } from 'vitest'
it('a', () => { expect(1).toBe(1) })
it('b', () => { expect(2).toBe(2) })
FIX
    cat > "$L/skip.test.ts"  <<'FIX'
import { it, expect } from 'vitest'
it.skip('a', () => { expect(1).toBe(2) })
it.skip('b', () => { expect(1).toBe(2) })
FIX
    cat > "$L/crash.test.ts" <<'FIX'
import { it, expect } from 'vitest'
import { nope } from './this-module-does-not-exist'
it('a', () => { expect(nope).toBe(1) })
FIX
    cat > "$L/empty.test.ts" <<'FIX'
export const collectsNothing = 1
FIX

    # THE RED PROOF. Not "the gate said FAIL" — that alone would be a checker
    # asserting its own happy path. What is proven here is the PAIR: bare vitest
    # answers 0 on the all-skip file, and the gate answers non-zero on the same
    # file in the same directory. Remove the pending check in the python block
    # below and this check is the one that goes red.
    ( cd "$L" && bunx vitest run skip.test.ts --reporter=json --outputFile="$T/bare.json" ) >/dev/null 2>&1
    bare_rc=$?
    if [ "$bare_rc" -eq 0 ]; then
      ok "bare vitest exits 0 on an all-it.skip file (the trap, still true today)"
    else
      bad "bare vitest exited $bare_rc on the all-skip fixture — the premise in this header has changed; re-measure before trusting the rest"
    fi
    run 1 "the gate exits 1 on the SAME file vitest just passed" -- "$L" 1 skip.test.ts
    run 0 "a genuinely passing file (2 real assertions, floor 2) → exit 0" -- "$L" 2 pass.test.ts
    # …and SAY WHICH RULE CAUGHT THEM. A collect crash and a zero-collect file
    # both go red here, but not necessarily for the reason the label implies —
    # they can land on the floor (`0 passed, expected >= 1`) rather than on a
    # failure count. Printing the branch keeps the next reader from crediting
    # this gate with a suite-level check it does not make.
    run 1 "a COLLECT-TIME crash → FAIL (vitest-collect-crash-reads-as-pass)"  -- "$L" 1 crash.test.ts
    printf '       caught by: %s\n' "$(printf '%s' "$LAST_OUT" | tail -1)"
    run 1 "a file that collects ZERO tests → FAIL" -- "$L" 1 empty.test.ts
    printf '       caught by: %s\n' "$(printf '%s' "$LAST_OUT" | tail -1)"
    run 1 "the floor bites on a real run too (2 passed, floor 3)" -- "$L" 3 pass.test.ts
  fi

  echo
  if [ "$fails" -gt 0 ]; then
    echo "do-test-gate: self-test FAILED ($fails of $checks checks red)"; exit 1
  fi
  if [ "$live_unrun" -eq 1 ]; then
    echo "do-test-gate: self-test $checks/$checks deterministic checks OK — LIVE fixtures UNRUN (no vitest). Not proven; exit 3."
    exit 3
  fi
  echo "do-test-gate: self-test PASS ($checks/$checks)"
  exit 0
fi

# ---------------------------------------------------------------------------
# the gate
# ---------------------------------------------------------------------------
workdir="${1:-}"
[ -n "$workdir" ] || { echo "usage: do-test-gate.sh <workdir> <min-passed> <test-file>... | --self-test" >&2; exit 2; }
min="${2:-}"
[ -n "$min" ] || { echo "usage: do-test-gate.sh <workdir> <min-passed> <test-file>... | --self-test" >&2; exit 2; }
shift 2
[ "$#" -gt 0 ] || { echo "[test-gate] no test files given" >&2; exit 2; }

case "$min" in ''|*[!0-9]*) echo "[test-gate] min-passed must be an integer, got '$min'" >&2; exit 2 ;; esac
# A floor of zero would let a suite that collected nothing pass the only numeric
# check this gate makes — the exact vacuous shape it exists to refuse.
[ "$min" -ge 1 ] || { echo "[test-gate] min-passed must be >= 1, got '$min' — a floor of zero passes a suite that ran nothing" >&2; exit 2; }

case "$workdir" in /*) WD="$workdir" ;; *) WD="$ROOT/$workdir" ;; esac

out="$(mktemp -t do-test-gate.XXXXXX)"
trap 'rm -f "$out"' EXIT

# Missing files must fail here rather than inside vitest's include-glob, whose
# "No test files found" message is easy to mistake for a red test.
for f in "$@"; do
  [ -f "$WD/$f" ] || { echo "[test-gate] FAIL missing test file: $workdir/$f" >&2; exit 1; }
done

# vitest's own exit code is deliberately IGNORED — it is 0 for the vacuous
# shapes above. The json report is the verdict.
#
# GOVERNED. This gate is written to be called from many parallel /do cycles at
# once, and a bare `bunx vitest` is exactly the ungoverned heavy gate that melted
# a 10-core box (see .claude/CLAUDE.md § Machine governor): no slot, no wall
# clock, no process-group reap. Routing through gate-run.sh means N parallel
# cycles QUEUE on GOVERN_MAX_GATES instead of thrashing, and it also satisfies
# hook:load-guard, which would otherwise refuse a direct `vitest run` on a
# saturated box and fail the accept for a reason that has nothing to do with the
# code. Degrades to a plain exec when the governor lib is absent (CI, fresh clone).
if [ "${DO_TEST_GATE_SELFTEST:-0}" = "1" ] && [ -n "${DO_TEST_GATE_FAKE_REPORT:-}" ]; then
  # self-test only: substitute the report so a verdict branch can be driven
  # without a process. Never read outside DO_TEST_GATE_SELFTEST=1.
  cp "$DO_TEST_GATE_FAKE_REPORT" "$out" 2>/dev/null || rm -f "$out"
else
  runner=( bash "$GATE_RUN" "test-gate:$workdir" -- )
  [ -x "$GATE_RUN" ] || runner=()
  ( cd "$WD" && "${runner[@]}" bunx vitest run "$@" --reporter=json --outputFile="$out" ) >/dev/null 2>&1 || true
fi

python3 - "$out" "$min" "$workdir" "$@" <<'PY'
import json, sys
out, min_passed, workdir = sys.argv[1], int(sys.argv[2]), sys.argv[3]
files = sys.argv[4:]
try:
    d = json.load(open(out))
except Exception as e:
    print(f"[test-gate] FAIL no json report ({e}) — the run did not start", file=sys.stderr)
    sys.exit(1)
passed  = int(d.get("numPassedTests", 0))
failed  = int(d.get("numFailedTests", 0))
pending = int(d.get("numPendingTests", 0))
label = " ".join(files)
if failed:
    print(f"[test-gate] FAIL {label}: {failed} failing", file=sys.stderr); sys.exit(1)
if pending:
    print(f"[test-gate] FAIL {label}: {pending} skipped — a skipped assertion is a hole, not a pass", file=sys.stderr); sys.exit(1)
if passed < min_passed:
    print(f"[test-gate] FAIL {label}: {passed} passed, expected >= {min_passed}", file=sys.stderr); sys.exit(1)
print(f"[test-gate] OK {workdir}/{label} — {passed} passed, 0 skipped, 0 failed (floor {min_passed})")
PY
