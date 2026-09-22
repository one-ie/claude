#!/bin/bash
# gc-content-check.sh — the red proof for lib/gc-finished.sh.
#
# manifest: needs-env
#   (portable by behaviour — its own sandbox — but it must spell one.ie/web/.astro
#    to exercise GC_EPHEMERAL. See factory-repo.sh's manifest block comment.)
#
# Builds a sandbox repo carrying the branch shapes the sweep meets, drives the
# REAL predicate (sourced, never re-implemented), and then proves the OLD
# commit-count predicate gets the important one wrong. A checker that only shows
# the new code passing would not tell you the change was worth making.
#
# NOT reproduced here: `git cherry`'s blind spot on a merge commit. That was
# measured on this repo (merge/trunk-reconcile, 2026-09-07: cherry reported
# 0-new for a branch holding 24 files and 3416 lines dev had never seen) and the
# reasoning lives in lib/gc-finished.sh. Faking a multi-merge-base history to
# re-stage it would be asserting a claim this sandbox does not actually show —
# the fourth case below covers the same risk directly: a merge carrying unique
# content must read NOT finished.
#
#   bash .claude/scripts/gc-content-check.sh    # exits non-zero on failure
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/gc-finished.sh"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
fails=0
EXPECT_RED=0   # set while driving the neutered predicate, so an INTENDED failure
               # does not print the word FAIL and read as a broken checker.
ok()  { printf '  ok    %s\n' "$1"; }
bad() {
  if [ "$EXPECT_RED" = 1 ]; then printf '  red   %s — as intended\n' "$1"
  else printf '  FAIL  %s\n' "$1"; fi
  fails=$((fails+1))
}
want() { # <expected 0|1> <branch> <what>
  gc_finished trunk "$2"; local got=$?
  [ "$got" -eq "$1" ] && ok "$3" || bad "$3 (wanted finished=$1, got $got)"
}

cd "$SANDBOX"
git init -q -b trunk .
git config user.email t@e.st; git config user.name t
git config commit.gpgsign false
echo base > a.txt; git add a.txt; git commit -qm base
echo one  > c.txt; git add c.txt; git commit -qm second
B1="$(git rev-parse HEAD)"

# 1 — REBASED DUPLICATE: the branch's patch reaches trunk under a DIFFERENT sha.
#     This is the case the commit count gets wrong, and the reason for this file.
git checkout -q -b dup "$B1"
echo fixed > a.txt; git commit -qam "fix a"
git checkout -q trunk
git cherry-pick dup >/dev/null 2>&1 || { bad "sandbox: cherry-pick failed"; exit 1; }
# Re-message it. A cherry-pick onto the same parent, in the same second, with the
# same author and message, produces a byte-identical commit OBJECT — trunk then
# fast-forwards onto the branch and there is no divergence left to detect. That
# is a sandbox artifact, not the real world, where a re-landed patch always
# arrives with a different sha. The amend forces the sha apart while leaving the
# patch identical, which is precisely the case under test.
git commit -q --amend -m "fix a (relanded under a different sha)"

# 2 — ORDINARY UNLANDED BRANCH.
git checkout -q -b ahead trunk
echo new > b.txt; git add b.txt; git commit -qm "adds b"

# 3 — FULLY CONTAINED: tip is an ancestor of trunk.
git checkout -q -b behind "$B1"

# 4 — MERGE COMMIT CARRYING UNIQUE CONTENT. The shape that makes a
#     patch-counting test (git cherry) unsafe on its own.
git checkout -q -b side "$B1"
echo unique > only-here.txt; git add only-here.txt; git commit -qm "unique file"
git checkout -q -b mergey trunk
git merge --no-edit side >/dev/null 2>&1 || { bad "sandbox: merge failed"; exit 1; }

echo "== the predicate the sweep runs"
want 0 dup    "a rebased duplicate reads FINISHED — its content is already on the platform"
want 1 ahead  "an ordinary unlanded branch reads NOT finished"
want 0 behind "a branch fully contained in the base reads FINISHED"
want 1 mergey "a merge carrying a file the base lacks reads NOT finished"

echo "== what the OLD commit-count predicate would have said"
old_finished() { [ "$(git rev-list --count "trunk..$1" 2>/dev/null || echo 1)" -eq 0 ]; }
if old_finished dup
then bad "the count predicate should MISS the duplicate — this proof is broken"
else ok  "the count predicate hoards the duplicate for ever — the ~120MB this fixes"; fi
if old_finished ahead
then bad "the count predicate wrongly sweeps an unlanded branch"
else ok  "the count predicate keeps an unlanded branch (both agree here)"; fi

echo "== the clean-worktree path survives set -e"
# The sweep runs under `set -euo pipefail`, and `grep -v` exits 1 when it filters
# EVERYTHING out — the clean-worktree case. Inline, that killed the sweep at the
# first worktree it was meant to remove: four keep lines, exit 1, no summary, and
# invisible behind a `| cat`. Drive the real function in a real subshell under
# the real flags, because that is the only way this comes back red.
git checkout -q trunk
if out="$(bash -c '
      set -euo pipefail
      . "'"$HERE"'/lib/gc-finished.sh"
      d="$(gc_real_dirt "'"$SANDBOX"'")"
      [ -z "$d" ] && echo CLEAN-AND-ALIVE
    ' 2>&1)" && [ "$out" = "CLEAN-AND-ALIVE" ]; then
  ok "a clean worktree reports no dirt AND the shell survives it"
else
  bad "the clean-tree path died under set -e (got: ${out:-<nothing>})"
fi
# And it still SEES real work, or the fix would be a mute button.
echo scratch > "$SANDBOX/uncommitted.txt"
if [ -n "$(gc_real_dirt "$SANDBOX")" ]
then ok "uncommitted work is still reported — the guard did not silence it"
else bad "gc_real_dirt missed an uncommitted file"; fi
rm -f "$SANDBOX/uncommitted.txt"
# Ephemera alone must NOT read as work, or nothing is ever swept.
# The tracked file is required, not decoration: git COLLAPSES a wholly-untracked
# directory to its top level, so an unrepresentative sandbox reports `?? one.ie/`
# and no path pattern can match. A real worktree has one.ie/web/ tracked, so git
# descends and reports `?? one.ie/web/.astro` — which is what the filter is
# written against. Committing one file reproduces that.
mkdir -p "$SANDBOX/one.ie/web"; echo keep > "$SANDBOX/one.ie/web/keep.txt"
git add one.ie/web/keep.txt; git commit -qm "tracked file under one.ie/web"
mkdir -p "$SANDBOX/one.ie/web/.astro"; echo x > "$SANDBOX/one.ie/web/.astro/gen.d.ts"
if [ -z "$(gc_real_dirt "$SANDBOX")" ]
then ok "build output alone does not count as work"
else bad "ephemeral dirt was reported as work — nothing would ever be swept"; fi
rm -rf "$SANDBOX/one.ie/web/.astro"

echo "== red proof: neuter the predicate and the checks must fail"
gc_finished() { return 0; }   # claim every branch is finished
before=$fails; EXPECT_RED=1
want 1 ahead  "(neutered) an unlanded branch must NOT read finished"
want 1 mergey "(neutered) a unique-content merge must NOT read finished"
if [ "$fails" -eq $((before+2)) ]; then
  fails=$before; EXPECT_RED=0; ok "both checks bite when the predicate is gutted"
else
  fails=$((before+1)); EXPECT_RED=0; printf '  FAIL  a gutted predicate still passed — this checker proves nothing\n'
fi

echo
[ "$fails" -eq 0 ] && { echo "gc-content-check: PASS"; exit 0; }
echo "gc-content-check: FAIL ($fails)"; exit 1
