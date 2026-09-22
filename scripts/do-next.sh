#!/usr/bin/env bash
# do-next.sh <slug> [--claim] [--all] — stream the next READY cycle(s) of a plan.
#
# manifest: portable
#
# WHY. do-engine runs a plan as BATCHES: every cycle in a batch must finish before
# any cycle of the next one starts, so the batch costs its SLOWEST member and a
# cycle whose own dependencies closed an hour ago still waits at the barrier. The
# batch is not a real constraint — the DAG is. This emits the cycles whose
# dependencies are ACTUALLY closed, right now, so a worker can take one, do it,
# verify it, close it, and immediately ask for the next.
#
# Readiness is DERIVED, never read. The todo's `state: ready` / `state: blocked-on-C1,C2`
# words are written once when the plan is authored and nothing updates them as
# cycles close — the same second-source-of-truth seam that let a verified cycle
# stay `- [ ]` forever. The `blocked-on-` list is the edge set (authored, static,
# correct); whether those edges are SATISFIED is computed from the checkboxes,
# which are the live record do-tick.sh writes.
#
# --claim makes the emission ATOMIC across every session and worktree on this box:
# claim_take is mkdir(2)-arbitrated, so N workers racing the same plan each get a
# DIFFERENT cycle and never the same one. A claim evaporates when its owner dies
# or its lease expires, so a killed worker's cycle returns to the stream by itself
# — no coordinator, no queue, nothing to deadlock.
set -euo pipefail

SLUG=""; DO_CLAIM=0; ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --claim) DO_CLAIM=1 ;;
    --all) ALL=1 ;;
    -*) echo "do-next: unknown flag $1" >&2; exit 2 ;;
    *) [ -n "$SLUG" ] && { echo "do-next: one slug only" >&2; exit 2; }; SLUG="$1" ;;
  esac
  shift
done
[ -n "$SLUG" ] || { echo "usage: do-next.sh <slug> [--claim] [--all]" >&2; exit 2; }

ROOT="${DO_NEXT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TODO="$ROOT/text/${SLUG}-todo.md"
[ -f "$TODO" ] || { echo "do-next: no such plan: $TODO" >&2; exit 3; }

# The cycle-line shape. Identical to do-tick.sh's reader and do-auto.sh's
# _remaining(); parity across all four implementations is proven behaviourally by
# do-cycle-shape-check.sh, which reads this file rather than a copy of it.
OPEN_RE='^[[:space:]]*- \[[ ~]\] \*{0,2}C[0-9]+\*{0,2} —'
CLOSED_RE='^[[:space:]]*- \[x\] \*{0,2}C[0-9]+\*{0,2} —'

closed_raw=$(grep -oE "$CLOSED_RE" "$TODO" 2>/dev/null || true)
closed=" $(printf '%s' "$closed_raw" | grep -oE 'C[0-9]+' 2>/dev/null | tr '\n' ' ' || true)"
open_lines=$(grep -E "$OPEN_RE" "$TODO" 2>/dev/null || true)
[ -n "$open_lines" ] || { echo "do-next: ${SLUG} — no open cycles; plan complete" >&2; exit 0; }

ready=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  cid=$(printf '%s' "$line" | grep -oE 'C[0-9]+' | head -1)
  [ -n "$cid" ] || continue
  # Edge set: `state: blocked-on-C1,C2`. No blocked-on clause ⇒ no edges ⇒ ready.
  deps=$(printf '%s' "$line" | sed -nE 's/.*blocked-on-([C0-9,]+).*/\1/p' | tr ',' ' ')
  blocked=0
  for d in $deps; do
    case "$closed" in *" $d "*) ;; *) blocked=1; break ;; esac
  done
  [ "$blocked" -eq 0 ] && ready="$ready $cid"
done <<EOF
$open_lines
EOF

ready=$(printf '%s' "$ready" | tr ' ' '\n' | grep -v '^$' || true)
[ -n "$ready" ] || { echo "do-next: ${SLUG} — cycles remain OPEN but every one is blocked on an unclosed dependency. Nothing to stream." >&2; exit 1; }

if [ "$DO_CLAIM" -eq 0 ]; then
  [ "$ALL" -eq 1 ] && printf '%s\n' "$ready" || printf '%s\n' "$ready" | head -1
  exit 0
fi

# shellcheck source=lib/govern.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/govern.sh"
# Claim on behalf of the WORKER, not of this script. do-next.sh exits in
# milliseconds; if the claim tracked its lifetime it would evaporate immediately
# and the next racer would be handed the very cycle we just emitted. Default to
# the caller (PPID) — the shell, agent, or fleet loop that will actually do the
# work and whose death SHOULD return the cycle to the stream.
export GOVERN_CLAIM_PID="${DO_NEXT_OWNER_PID:-$PPID}"
# PPID is only the real worker when do-next is called directly. Called the
# natural way — `cid=$(do-next.sh <slug> --claim)` — the parent IS the command
# substitution's subshell, which dies the instant the value is assigned, so the
# claim would evaporate before the worker ever saw the cycle it was handed.
# minhold keeps the ground held for a grace window regardless of owner liveness;
# the worker adopts it by re-claiming under its own pid (claim_take is idempotent
# for the same owner), and the lease TTL still bounds the whole thing.
export GOVERN_CLAIM_MIN_HOLD_SECS="${DO_NEXT_MIN_HOLD_SECS:-300}"
took=""
for cid in $ready; do
  if claim_take "do-${SLUG}-${cid}" "${SLUG}/${cid}" >/dev/null 2>&1; then
    took="$took $cid"
    [ "$ALL" -eq 1 ] || break
  fi
done
took=$(printf '%s' "$took" | tr ' ' '\n' | grep -v '^$' || true)
if [ -z "$took" ]; then
  echo "do-next: ${SLUG} — every ready cycle is already claimed by a live worker. Nothing to take." >&2
  exit 1
fi
printf '%s\n' "$took"
