#!/bin/bash
# gc-finished.sh — "is this branch's work already on the platform?"
#
# ONE definition, sourced by both the sweep (do-auto.sh --gc) and its red proof
# (gc-content-check.sh). The matcher for hook:governor-escape lives in a shared
# lib for the same reason: a checker that re-implements what it checks proves
# only that two copies agree.
#
# NOT `rev-list --count BASE..branch`. That counts COMMITS, and a branch whose
# patch reached BASE under a different sha — cherry-picked, rebased, landed by a
# squash — keeps commits of its own for ever. Measured 2026-09-07 on this repo:
# fix/webhook-500's single patch was already in dev under another sha, so the
# count read "1 unmerged" and the sweep had been keeping a ~120MB checkout of
# work the platform already had. A sweep that cannot recognise its own work is
# not a sweep, it is a hoard.
#
# `git cherry` is the obvious fix and is NOT sufficient alone. A MERGE commit
# carries no patch of its own, so cherry reports 0-new for a branch that holds
# content nothing else has — merge/trunk-reconcile, the same day, 24 files and
# 3416 lines dev had never seen. Sweeping on cherry would have deleted the only
# checkout of a hand-made merge resolution.
#
# The predicate true in BOTH cases is content identity: every path the branch
# touched since the merge base is now byte-identical in BASE. A rebased duplicate
# passes; a merge carrying unique files fails; an ordinary unlanded branch fails.

# gc_finished <base> <branch> -> 0 = finished (its content is in base), 1 = not
gc_finished() {
  local base="$1" b="$2"
  local -a paths=()
  # Paths the branch changed since the merge base. `...` (three dots) is the
  # load-bearing part: `..` would also list what BASE changed underneath it, and
  # a busy trunk would then make every branch look like it carries everything.
  while IFS= read -r f; do [ -n "$f" ] && paths+=("$f"); done < <(git diff --name-only "${base}...${b}" 2>/dev/null)
  # A branch that changed nothing since the merge base is finished by definition.
  [ ${#paths[@]} -eq 0 ] && return 0
  # Compare those paths as they stand NOW in each tip. --quiet exits 1 on any
  # difference, which is the answer, not an error — never let `set -e` see it.
  git diff --quiet "$base" "$b" -- "${paths[@]}" 2>/dev/null
}

# gc_carries <base> <branch> — how many paths the BRANCH still carries that base
# does not have. This is the number the sweep prints, so it has to mean what it
# says: `git diff --name-only base branch | wc -l` (two dots) counts everything
# that differs in EITHER direction, so a branch adding one file to a trunk that
# has moved on by 500 commits reports "carries 508 paths". Measured on this repo
# 2026-09-07: fix/webhook-500-again touches ONE file and read 508. The paths that
# belong to the branch are the ones it changed since the merge base AND that
# still differ from base now — the same set gc_finished tests.
gc_carries() {
  local base="$1" b="$2" n=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    git diff --quiet "$base" "$b" -- "$f" 2>/dev/null || n=$((n+1))
  done < <(git diff --name-only "${base}...${b}" 2>/dev/null)
  echo "$n"
}

# Dirt that is not work: build output, worktree bookkeeping, a regenerated data
# file. None of it is recoverable from a checkout and all of it regenerates, so
# it must not stand between a finished branch and its removal.
GC_EPHEMERAL="${GC_EPHEMERAL:-one\.ie/web/\.astro|one\.ie/web/\.wrangler|one\.ie/web/\.preview|\.dev\.pid|\.worktree-port|deploy-runs\.json|node_modules}"

# gc_real_dirt <worktree> — the uncommitted lines that are actually WORK, empty
# when the tree is clean or carries only ephemera.
#
# The `|| true` is load-bearing and is why this is a function rather than an
# inline pipeline. `grep -v` exits 1 when it filters EVERYTHING out — which is
# exactly the clean-worktree case — and the caller runs under `set -euo
# pipefail`, so `real="$(... | grep -v ...)"` killed the sweep the first time it
# met a worktree it was supposed to remove. Measured 2026-09-07: the sweep
# printed four keep lines, exited 1, and never reached its own summary; piped
# through `cat` or `tail` the failure was invisible, which is how it nearly got
# reported as a clean run.
gc_real_dirt() {
  git -C "$1" status --porcelain 2>/dev/null | grep -vE "$GC_EPHEMERAL" || true
}
