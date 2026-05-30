#!/usr/bin/env bash
# do-auto.sh — INTERNAL context-isolated loop for multi-cycle /do plans.
#
# Not a user command. `/do <slug>` invokes this itself when the resolved todo has
# >=2 incomplete cycles. Each cycle runs in a FRESH `claude -p "/do <slug> --next-cycle"`
# subprocess, resetting the context window to near-zero. State passes entirely through
# disk: the todo file (checked boxes), .do-trust.json (trust), .w4-improvements.json.
#
# Why it exists: run inline, each closed cycle leaves ~15-25k tokens of recon/edit/verify
# chatter in context that the next cycle has no use for — ~90-150k tokens of noise by
# cycle 6. Fresh-per-cycle eliminates it. The todo checkboxes are the only carried state.
#
# Internal usage (driven by do.md, not a human):
#   bun .claude/scripts/do-auto.sh <slug> [--max-cycles N] [--dry-run]
set -euo pipefail

SLUG=""
MAX_CYCLES=30
DRY_RUN=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --max-cycles) MAX_CYCLES="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -*)           echo "unknown flag: $1" >&2; exit 1 ;;
    *)            SLUG="$1"; shift ;;
  esac
done

[ -z "$SLUG" ] && { echo "usage: do-auto.sh <slug> [--max-cycles N] [--dry-run]" >&2; exit 1; }

TODO="plans/${SLUG}-todo.md"
TRUST=".do-trust.json"

[ -f "$TODO" ] || { echo "[do-auto] $TODO not found — run /do $SLUG first" >&2; exit 1; }

_remaining() {
  # Count cycles in the Status section that are open ([ ]) or in-flight ([~]) — i.e. not [x].
  # Pattern starts with '\[' (not '-') so grep never mistakes it for an option flag.
  grep -cE '\[[ ~]\] C[0-9]+' "$TODO" 2>/dev/null || echo 0
}

_trust() {
  jq -r '.level // "standard"' "$TRUST" 2>/dev/null || echo "standard"
}

_plan_done() {
  # Plan close item is ticked. -e marks the pattern explicitly (dash-safe).
  grep -qe '\[x\].*Plan outcome command exits 0' "$TODO" 2>/dev/null
}

i=0
prev_remaining=-1
stall=0
while [ "$i" -lt "$MAX_CYCLES" ]; do
  if _plan_done; then
    echo "[do-auto] plan complete — outcome line ticked"
    break
  fi

  remaining=$(_remaining)
  if [ "$remaining" -eq 0 ]; then
    echo "[do-auto] no open cycles — plan complete"
    break
  fi

  # Stall guard: a cycle that ticks no box means the subprocess halted/errored.
  # Retrying the identical state forever just burns subprocesses — halt after 2 stalls.
  if [ "$remaining" -eq "$prev_remaining" ]; then
    stall=$((stall + 1))
    if [ "$stall" -ge 2 ]; then
      echo "[do-auto] no progress for 2 iterations (${remaining} cycle(s) stuck) — halting." >&2
      echo "[do-auto] The last cycle ticked no checkbox. Inspect $TODO, fix the blocker, then re-run /do $SLUG." >&2
      exit 1
    fi
  else
    stall=0
  fi
  prev_remaining=$remaining

  trust=$(_trust)
  if [ "$trust" = "cautious" ]; then
    echo "[do-auto] trust=cautious — halting. Fix the issue, then re-run /do $SLUG."
    exit 1
  fi

  i=$((i + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "[do-auto] iteration ${i} — ${remaining} cycle(s) remaining — trust=${trust}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if $DRY_RUN; then
    echo "[do-auto] DRY RUN: would invoke — claude --dangerously-skip-permissions -p \"/do $SLUG --next-cycle\""
    break
  fi

  # Fresh context: no --resume, no --continue. Each cycle is a clean slate.
  claude --dangerously-skip-permissions -p "/do $SLUG --next-cycle"
done

if [ "$i" -ge "$MAX_CYCLES" ]; then
  echo "[do-auto] hit --max-cycles $MAX_CYCLES — halting"
  exit 1
fi
