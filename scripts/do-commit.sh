#!/usr/bin/env bash
# do-commit.sh <worktree> <slug> <cid> <path>... — stage EXACTLY these paths and
# commit them as one cycle, holding a per-worktree lock so two parallel cycles
# cannot interleave their staging.
#
# manifest: needs-env
#
# WHY (measured 2026-08-31, lifecycle-money). A batch's cycles run in PARALLEL in
# ONE worktree. W4 was told to `git -C $WT add -A && git commit`, so whichever
# cycle committed first swept every sibling's in-progress edits into its own
# commit. Commit c5eeeb9ec is labelled "C4" and carries C3's escrow + market work
# and C5's money/sui-network work; its own verifier called it "commit
# contamination". The repo already forbids blanket staging on the shared tree
# (hook:git-add-guard) for precisely this reason — the worktree exemption assumed
# one worker per worktree, which stopped being true when batches went parallel.
#
# Two independent problems, two mechanisms:
#   1. WHAT gets staged — explicit paths only. Never add -A / add . / commit -a.
#   2. WHEN — `git add` and `git commit` are two calls against one index. Between
#      them a sibling's `git add` can land, and its files join this commit even
#      though this one named only its own. The lock closes that window.
#
# It is deliberately NOT an error for a named path to be missing or unchanged: a
# cycle whose W3 dissolved one spec still commits the rest.
set -uo pipefail

WT="${1:-}"; SLUG="${2:-}"; CID="${3:-}"
shift 3 2>/dev/null || { echo "usage: do-commit.sh <worktree> <slug> <cid> <path>..." >&2; exit 2; }
[ -n "$WT" ] && [ -n "$SLUG" ] && [ -n "$CID" ] && [ "$#" -gt 0 ] || {
  echo "usage: do-commit.sh <worktree> <slug> <cid> <path>..." >&2; exit 2; }
[ -d "$WT/.git" ] || [ -f "$WT/.git" ] || { echo "do-commit: not a worktree: $WT" >&2; exit 3; }

for p in "$@"; do
  case "$p" in
    -A|.|--all|-a) echo "do-commit: REFUSING blanket stage '$p' — name the cycle's own paths" >&2; exit 4 ;;
  esac
done

# shellcheck source=lib/govern.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/govern.sh"
LOCK="commit-$(printf '%s' "$WT" | tr '/' '_')"

if ! gate_lock "$LOCK" "${DO_COMMIT_WAIT:-300}"; then
  echo "do-commit: could not take the commit lock for $WT within ${DO_COMMIT_WAIT:-300}s" >&2
  exit 5
fi
trap 'gate_release_all' EXIT INT TERM

# Only stage paths that exist or are tracked-and-deleted; a dissolved spec is normal.
staged=0
for p in "$@"; do
  if [ -e "$WT/$p" ] || git -C "$WT" ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    git -C "$WT" add -- "$p" 2>/dev/null && staged=$((staged + 1))
  else
    echo "do-commit: skip (absent, never tracked): $p" >&2
  fi
done

if [ "$staged" -eq 0 ] || git -C "$WT" diff --cached --quiet 2>/dev/null; then
  echo "do-commit: ${SLUG} ${CID} — nothing staged to commit"
  gate_release_all; trap - EXIT INT TERM
  exit 0
fi

# Report exactly what this commit carries, so contamination is visible in the log
# rather than discovered by a later verifier.
echo "do-commit: ${SLUG} ${CID} staging $(git -C "$WT" diff --cached --name-only | wc -l | tr -d ' ') file(s):"
git -C "$WT" diff --cached --name-only | sed 's/^/    /'

git -C "$WT" commit -m "do(${SLUG}): ${CID}" >/dev/null 2>&1 \
  && echo "do-commit: ${SLUG} ${CID} -> $(git -C "$WT" rev-parse --short HEAD)" \
  || { echo "do-commit: commit FAILED for ${SLUG} ${CID}" >&2; gate_release_all; trap - EXIT INT TERM; exit 6; }

gate_release_all; trap - EXIT INT TERM
exit 0
