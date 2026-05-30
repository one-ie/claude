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

# Validate slug is safe (kebab-case only) before it touches any shell string.
# Prevents command injection if the slug ever contains metacharacters.
if ! printf '%s' "$SLUG" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'; then
  echo "[do-auto] unsafe slug (must be alphanumeric + hyphens/underscores): $SLUG" >&2; exit 1
fi

# Trust boundary: this script runs in the developer's own workspace, invoked by /do
# which resolves the slug from a plans/ file the developer controls. The spawned
# claude subprocess uses --dangerously-skip-permissions because it is non-interactive
# — it cannot prompt the human for tool approvals. The workspace is the isolation
# boundary. Do not expose this script to untrusted input or run it in shared environments.
[ -f "plans/${SLUG}-todo.md" ] || { echo "[do-auto] plans/${SLUG}-todo.md not found — run /do $SLUG first" >&2; exit 1; }

# ── Worktree isolation (one per plan) ────────────────────────────────────────
# The loop's existence IS the trigger: do-auto only runs for multi-cycle plans
# (>=2 incomplete cycles) = exactly the FEATURE/SCHEMA work that must not land
# half-built on trunk. So every loop builds in its own worktree on branch
# do/<slug>, leaving trunk green until a human merges. No tier plumbing, no flag.
#
# Why a worktree and not just a branch: the main session keeps observing trunk
# while the loop's subprocesses build in a separate checkout — they never fight
# over HEAD or the working tree. A halt leaves a clean, inspectable WIP branch.
#
#   trunk (BASE) ── never moves during the loop
#        └─ do/<slug>  (worktree .do-worktrees/<slug>) ── every cycle commits here
#   plan complete → report `git merge do/<slug>`  (human lands it — never auto)
#   halt          → worktree persists → re-run /do <slug> resumes in place
BASE="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
BR="do/${SLUG}"
WT=".do-worktrees/${SLUG}"

_setup_worktree() {
  # Idempotent: reuse an existing worktree (resume), else attach one to an
  # existing branch (prior halt), else create branch+worktree fresh from HEAD.
  if git -C "$WT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "[do-auto] resuming worktree $WT on $BR"
  elif git show-ref --verify --quiet "refs/heads/$BR"; then
    echo "[do-auto] re-attaching worktree $WT to existing branch $BR"
    git worktree add "$WT" "$BR" >/dev/null
  else
    echo "[do-auto] creating worktree $WT on new branch $BR (from $BASE)"
    git worktree add -b "$BR" "$WT" HEAD >/dev/null
  fi

  # Carry the plan's own artifacts into the worktree. The spine walk may have
  # just written promise/spec/todo uncommitted in the main tree; a worktree cut
  # from HEAD wouldn't have them. Copy only this slug's files — never unrelated
  # working-tree changes — then commit them as the branch baseline.
  local f changed=0
  for f in "plans/${SLUG}.md" "plans/${SLUG}-todo.md" "text/${SLUG}.md" ".w4-improvements.json"; do
    if [ -f "$f" ]; then
      mkdir -p "$WT/$(dirname "$f")"
      if ! cmp -s "$f" "$WT/$f" 2>/dev/null; then cp "$f" "$WT/$f"; changed=1; fi
    fi
  done
  if [ "$changed" -eq 1 ]; then
    git -C "$WT" add -A
    git -C "$WT" commit -q -m "do(${SLUG}): sync spine artifacts" 2>/dev/null || true
  fi
}

if ! $DRY_RUN; then
  _setup_worktree
  # All loop state now lives in the worktree — read the boxes the subprocess ticks.
  TODO="$WT/plans/${SLUG}-todo.md"
  TRUST="$WT/.do-trust.json"
else
  TODO="plans/${SLUG}-todo.md"
  TRUST=".do-trust.json"
fi

_remaining() {
  # Count cycles in the Status section that are open ([ ]) or in-flight ([~]) — i.e. not [x].
  # Pattern starts with '\[' (not '-') so grep never mistakes it for an option flag.
  # grep -c already prints a count (0 on no match) but exits 1 then — capture it so
  # the `|| true` swallows the exit without appending a second "0" to the output.
  local n; n=$(grep -cE '\[[ ~]\] C[0-9]+' "$TODO" 2>/dev/null) || true
  echo "${n:-0}"
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
      echo "[do-auto] WIP preserved on branch $BR (worktree $WT)." >&2
      exit 1
    fi
  else
    stall=0
  fi
  prev_remaining=$remaining

  trust=$(_trust)
  if [ "$trust" = "cautious" ]; then
    echo "[do-auto] trust=cautious — halting. Fix the issue, then re-run /do $SLUG."
    echo "[do-auto] WIP preserved on branch $BR (worktree $WT)."
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

  # Fresh context, isolated tree: the subprocess runs INSIDE the worktree, so
  # every edit/box-tick/state-write lands on branch $BR — trunk is never touched.
  ( cd "$WT" && claude --dangerously-skip-permissions -p "/do $SLUG --next-cycle" )

  # Commit the cycle on its branch. A cycle closes with a passing rubric, so it
  # is the natural commit unit — and committed progress survives a later halt.
  if [ -n "$(git -C "$WT" status --porcelain)" ]; then
    git -C "$WT" add -A
    git -C "$WT" commit -q -m "do(${SLUG}): cycle ${i}" || true
  fi
done

if $DRY_RUN; then exit 0; fi

if [ "$i" -ge "$MAX_CYCLES" ]; then
  echo "[do-auto] hit --max-cycles $MAX_CYCLES — halting"
  echo "[do-auto] WIP preserved on branch $BR (worktree $WT)."
  exit 1
fi

# Plan complete. The branch holds every cycle, proven and committed; trunk is
# untouched. Landing it is a human decision (commit/push only when asked), so we
# report the merge instead of running it — the worktree stays for inspection.
echo ""
echo "[do-auto] ✓ plan complete on branch $BR — trunk ($BASE) untouched."
echo "[do-auto]   land:    git merge --no-ff $BR        # from $BASE"
echo "[do-auto]   inspect: git -C $WT log --oneline $BASE..$BR"
echo "[do-auto]   discard: git worktree remove $WT && git branch -D $BR"
