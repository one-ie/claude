#!/usr/bin/env bash
# do-tick.sh <slug> <C1> [C2 ...] — tick a cycle's Status-kanban line after a
# green W4. Run from the plan worktree (or pass DO_TICK_ROOT).
#
# manifest: portable
#
# WHY (2026-08-31). do-engine had no writer for the tick, so a cycle that PASSED
# stayed `- [ ]` forever. openCyclesFromTodo/_remaining then reported it open on
# the next launch, the batch rebuilt work that was already verified green, and
# because a rebuilt batch never got further the run reported stoppedAt:1 every
# time. Measured: lifecycle-money C2 was verified green at 15:43 and was being
# rebuilt from scratch at 16:02. Two W2 agents diagnosed it independently and
# named it ROOT CAUSE in the census.
#
# Deterministic on purpose: ticking is a two-character edit on a line whose exact
# shape is already the contract. Nothing about it needs a model.
set -euo pipefail
SLUG="${1:-}"; shift || true
[ -n "$SLUG" ] && [ "$#" -gt 0 ] || { echo "usage: do-tick.sh <slug> <C1> [C2 ...]" >&2; exit 2; }
ROOT="${DO_TICK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TODO="$ROOT/text/${SLUG}-todo.md"
[ -f "$TODO" ] || { echo "do-tick: no such plan: $TODO" >&2; exit 3; }

# _is_open <cid> — the ONE reader in this script. Same shape do-auto.sh's
# _remaining() and do-engine's openCyclesFromTodo use; parity across all four
# is proven behaviourally by do-cycle-shape-check.sh, not by eyeballing them.
_is_open() { grep -qE "^[[:space:]]*- \[[ ~]\] \*{0,2}${1}\*{0,2} —" "$TODO"; }

# ── the OTHER half of closing a cycle ────────────────────────────────────────
# This script was the single writer of the markdown tick and touched the
# substrate ZERO times, so a cycle went `[x]` in a file while the platform task
# stayed open forever. Two records of the same fact, one of them always stale --
# and the stale one is what a human or an agent reads on the board.
#
# So the tick writes BOTH, here, in the one place a cycle is declared complete.
#
# It must not fail the tick. The markdown tick is the ratchet the engine reads to
# avoid rebuilding proven work; losing it because a gateway was unreachable would
# trade a stale board for a rebuilt cycle, which is far worse. Instead an
# unreachable substrate PARKS the update in a machine-keyed pending file and every
# later tick flushes it first -- so "as soon as complete" degrades to "at the next
# tick", never to "never". Same debt-ledger shape as the deferred test pins.
PENDING="${DO_TICK_PENDING:-${TMPDIR:-/tmp}/one-do-tick-pending}"
_sig() { bash "$(dirname "${BASH_SOURCE[0]}")/do-signal.sh" --task-cycle "$1" "$2" done >/dev/null 2>&1; }

_flush_pending() {
  [ -f "$PENDING" ] || return 0
  local left; left="$(mktemp)"
  while IFS=$'\t' read -r pslug pcid; do
    [ -n "$pcid" ] || continue
    _sig "$pslug" "$pcid" || printf '%s\t%s\n' "$pslug" "$pcid" >> "$left"
  done < "$PENDING"
  if [ -s "$left" ]; then mv "$left" "$PENDING"
    echo "do-tick: $(wc -l < "$PENDING" | tr -d ' ') substrate update(s) still pending"
  else rm -f "$left" "$PENDING"; fi
}

_mark_done_in_substrate() {
  local cid="$1"
  if _sig "$SLUG" "$cid"; then
    echo "do-tick: ${SLUG} ${cid} -> task done (substrate)"
  else
    printf '%s\t%s\n' "$SLUG" "$cid" >> "$PENDING"
    echo "do-tick: substrate unreachable — ${SLUG} ${cid} PARKED in $PENDING (flushed on the next tick)" >&2
  fi
}

_flush_pending

ticked=0; failed=0
for cid in "$@"; do
  case "$cid" in C[0-9]|C[0-9][0-9]) ;; *) echo "do-tick: skip bad cycle id '$cid'" >&2; continue ;; esac
  # Only ever [ ] or [~] -> [x]. Never the reverse: the ratchet cannot regress.
  if _is_open "$cid"; then
    # SUBSTRATE FIRST, checkbox second. The task is the record; the checkbox is a
    # projection of it. Writing the file first made these two peers that could
    # disagree -- a dual write, which is the same two-sources-of-truth shape that
    # produced every engine scar here. Written in this order the box can only
    # reach [x] downstream of a task that is already `done`.
    _mark_done_in_substrate "$cid"
    perl -i -pe "s/^(\s*- )\[[ ~]\](\s\*{0,2}${cid}\*{0,2}\s—)/\${1}[x]\${2}/" "$TODO"
    # POST-CONDITION. A fire-and-forget write is how the original bug survived:
    # the engine called a ticker, nobody checked the box actually moved, and the
    # next launch rebuilt proven work. Asserting the write LANDED — with this
    # script's own reader — is the guard that works even when do-engine runs from
    # a cached snapshot, because it runs inside whatever code actually executed.
    if _is_open "$cid"; then
      echo "do-tick: FAILED — ${SLUG} ${cid} is STILL open after the write. The plan will rebuild proven work. Line shape in $TODO does not match the writer." >&2
      failed=$((failed+1))
    else
      echo "do-tick: ${SLUG} ${cid} -> [x]"; ticked=$((ticked+1))
    fi
  else
    echo "do-tick: ${SLUG} ${cid} already closed or absent — no change"
  fi
done

# Report what the ENGINE's next launch will see. A silent success that leaves the
# same count open is the failure mode this whole file exists to end.
open_now=$(grep -cE '^[[:space:]]*- \[[ ~]\] \*{0,2}C[0-9]+\*{0,2} —' "$TODO" 2>/dev/null || true)
echo "do-tick: ${SLUG} ticked=${ticked} open=${open_now:-0}"
[ "$failed" -eq 0 ] || exit 4
