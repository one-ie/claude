#!/usr/bin/env bash
# govern-bound-check.sh — prove run_bounded neither hangs its caller nor leaks
# its watchdog. Three checks, each one a measured outage.
#
# manifest: portable
#
#   1. A CAPTURED call returns when the command returns. `$(run_bounded 60 true
#      2>&1)` must come back in ~0s, not 60s. The watchdog used to inherit the
#      caller's stdout (fixed 2026-09-01, `>&2`) and then its stderr (measured
#      2026-09-03 as 1800s of nothing inside `$(… 2>&1)`, and again inside
#      `… 2>&1 | tail`). A wait that reads as a hang gets killed at 144 = UNRUN.
#   2. NO ORPHAN SLEEP survives a bounded call. `kill "$watch_pid"` reaped the
#      watchdog subshell but not the `sleep` it forked — 21 `sleep 1800` with
#      ppid 1 were on the box on 2026-09-04, each holding a dead caller's pipe.
#   3. The bound still BITES: a command that outlives its cap is killed, the
#      whole process group with it, and the parent says so on stderr.
#
# Exit 0 = all three hold · 1 = one did not. Touches nothing machine-wide:
# GOVERN_DIR is a sandbox.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export GOVERN_DIR="${TMPDIR:-/tmp}/one-govern-boundcheck.$$"
mkdir -p "$GOVERN_DIR"; trap 'rm -rf "$GOVERN_DIR"' EXIT
# shellcheck source=lib/govern.sh
. "$ROOT/.claude/scripts/lib/govern.sh"
fails=0
ok()  { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; fails=$((fails+1)); }
now() { date +%s; }
tag="bound-check-$$"

echo "== 1. a captured call returns with the command, not with the watchdog"
t0=$(now)
out="$(run_bounded 61 bash -c "echo answer-$tag" 2>&1)"; rc=$?
dt=$(( $(now) - t0 ))
if [ "$rc" -eq 0 ] && [ "$dt" -le 3 ] && [ "$out" = "answer-$tag" ]; then ok "\$(run_bounded 60 …) returned in ${dt}s with the output intact"
else bad "captured call took ${dt}s rc=$rc out='$out' (a 60s wait here is the watchdog holding the pipe)"; fi
t0=$(now)
out="$(run_bounded 61 bash -c "echo answer2-$tag" 2>&1 | cat)"
dt=$(( $(now) - t0 ))
[ "$dt" -le 3 ] && ok "… and through a pipe (${dt}s)" || bad "piped call took ${dt}s"

echo "== 2. no orphaned watchdog sleep survives"
sleep 1
n=$(ps -Ao command= | grep -c "^sleep 61$")
[ "$n" -eq 0 ] && ok "no 'sleep 61' left behind" || bad "$n orphaned 'sleep 61' still running (the watchdog's child outlived it)"

echo "== 3. the bound still bites, and the group goes with it"
t0=$(now)
err="$(run_bounded 1 bash -c "sleep 31 & sleep 31; echo lived-$tag" 2>&1 >/dev/null)"; rc=$?
dt=$(( $(now) - t0 ))
if [ "$rc" -ne 0 ] && [ "$dt" -le 12 ]; then ok "a 31s command under a 1s cap died in ${dt}s (rc=$rc)"
else bad "cap did not bite: rc=$rc after ${dt}s"; fi
case "$err" in *TIMEOUT*) ok "the parent printed the TIMEOUT line" ;; *) bad "no TIMEOUT line on stderr: '$err'" ;; esac
sleep 1
n=$(ps -Ao command= | grep -c "^sleep 31$")
[ "$n" -eq 0 ] && ok "the process group was reaped (no 'sleep 31' survivors)" || bad "$n 'sleep 31' survived the group kill"

[ "$fails" -eq 0 ] && { echo "govern-bound-check: PASS"; exit 0; }
echo "govern-bound-check: FAILED ($fails)"; exit 1
