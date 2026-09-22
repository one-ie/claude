#!/usr/bin/env bash
# gate-run.sh — run a heavy build gate under the machine-wide governor.
#
#   gate-run.sh <label> -- <command...>
#
# Three things it guarantees that a bare `bun run verify` does not:
#   1. SLOT   — at most GOVERN_MAX_GATES heavy gates run machine-wide, across
#               every Claude Code session and every worktree. Session 3+ queues.
#   2. BOUND  — a hard wall-clock cap; macOS ships no timeout(1), so an
#               unbounded gate ran 18 min under load and outlived its session.
#   3. REAP   — kills the whole PROCESS GROUP on timeout/exit. Killing only the
#               shell reparents bun/node/vitest-forks to launchd, which is how
#               orphaned verify trees leaked here.
#
# Degrades to a plain exec if the governor lib is missing (CI, fresh clone).
set -uo pipefail

LABEL="${1:-gate}"; shift || true
[ "${1:-}" = "--" ] && shift

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/govern.sh"
if [ ! -f "$LIB" ]; then exec "$@"; fi
. "$LIB"

# CI and explicit opt-out run at full throughput.
if [ -n "${CI:-}" ] || [ "${GOVERN_DISABLE:-0}" = "1" ]; then exec "$@"; fi

# Re-entrancy: `verify` calls `test`, and both are wrapped. A nested gate must
# INHERIT the outer slot, never take a second one — two slots held by one
# logical gate would deadlock the queue at cap 2.
if [ "${GOVERN_IN_GATE:-0}" = "1" ]; then exec "$@"; fi
export GOVERN_IN_GATE=1

trap 'gate_release_all' EXIT INT TERM

# SAY THAT YOU ARE QUEUEING.
#
# gate_slot blocks for up to 1800s and this script printed nothing until it had a
# slot, so a queued gate and a hung gate looked identical to whoever was waiting.
# Measured 2026-09-01: lifecycle C8's demo gate was reported by its verifier as
# "timed out (>120s) and did not complete", and the cycle failed. Run directly it
# passes 6/6 in 1.19 SECONDS. Nothing was broken — the gate was waiting behind
# other gates in silence, and the verifier gave up and called it a hang.
#
# A wait that is announced is a wait. A wait that is silent is read as a failure.
_held=$(ls -d "$GOVERN_DIR"/lock-slot-* 2>/dev/null | wc -l | tr -d ' ')
# The EFFECTIVE cap is min(config, what memory can fund) — gate_slot takes that
# min every retry. Announcing the config alone misreported the wait on exactly
# the boxes where the memory probe is doing its job.
_head=$(gate_headroom 2>/dev/null || echo 99)
_cap="${GOVERN_MAX_GATES:-2}"
[ "$_head" -lt "$_cap" ] 2>/dev/null && _cap="$_head"
[ "${_cap:-0}" -lt 1 ] 2>/dev/null && _cap=1
if [ "${_held:-0}" -ge "$_cap" ]; then
  echo "[gate-run] $LABEL: QUEUEING for a slot (${_held}/${_cap} held; config ${GOVERN_MAX_GATES:-2}, memory funds ${_head} at $(gate_price_mb)MB each). This is a WAIT, not a hang — do not report it as a timeout. Set GOVERN_QUEUE_WAIT to bound it, or GOVERN_DISABLE=1 to bypass." >&2
fi
_q0=$(date +%s)

if ! gate_slot "${GOVERN_QUEUE_WAIT:-1800}"; then
  echo "[gate-run] $LABEL: no slot after ${GOVERN_QUEUE_WAIT:-1800}s — machine saturated." >&2
  exit 1
fi

if ! gate_pressure; then
  echo "[gate-run] $LABEL: WARNING — low free memory; running anyway in slot $GOVERN_SLOT." >&2
fi

_qw=$(( $(date +%s) - _q0 ))
echo "[gate-run] $LABEL: running in $GOVERN_SLOT (cap ${GOVERN_MAX_GATES} machine-wide$([ "$_qw" -gt 2 ] && echo ", queued ${_qw}s"))" >&2
run_bounded "${GOVERN_GATE_TIMEOUT:-1800}" "$@"
rc=$?
gate_release_all; trap - EXIT INT TERM
exit $rc
