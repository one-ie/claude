#!/usr/bin/env bash
# do-untracked-gate.sh — a deliverable that exists on disk but is NOT in git has
# not shipped. This gate is the only check in the harness that can say so.
#
# WHY (the real failure, 2026-07-28, plan `factory`): two shipped deliverables —
#   packages/sdk/src/fn-allowlist.ts            (C8's single source of truth)
#   one.ie/web/tests/unit/fn-entity-args.test.ts (C7's proof)
# sat UNTRACKED for hours while every acceptance check stayed GREEN, because
# every check reads the WORKING TREE. Built, tested, passing, and on a path to
# never reach main. A human running `git status` caught it; no gate did.
#
# That is the promise's own failure class — "built but not wired" — one level
# lower than it was being looked for. factory-check.sh asks "is it live in the
# substrate?"; this asks the question underneath it: "is it even in the repo?"
#
# Usage:
#   do-untracked-gate.sh <slug> [--verbose]   # e.g. do-untracked-gate.sh factory
#   do-untracked-gate.sh --self-test          # temp git fixtures, zero network
#
# Exit: 0 = green (every existing deliverable file is tracked)
#       1 = red   (a deliverable exists on disk and is untracked or gitignored)
#       3 = cannot run (not a git repo, or neither text/<slug>.md nor -todo.md)
#       4 = bad usage
#
# 1 vs 3 is the same distinction factory-check.sh draws: red sends someone to
# `git add`; cannot-run sends them to fix the environment, and proves nothing
# either way. Never widen a cannot-run into a red to make a chain simpler.
#
# WHAT IT READS — the `deliverables:` frontmatter block of BOTH text/<slug>.md
# (the promise: `- item:` / `accept:` prose) and text/<slug>-todo.md (the plan:
# `- <kind>: "path — description"`). Paths live in prose, so every path-shaped
# token in the block is a candidate. Comments inside the block are scanned too:
# a path worth naming in the schedule is a path worth having in git.
#
# WHAT IT DOES NOT DO — it never reports a MISSING file. A deliverable path that
# does not exist is simply not built yet; that is factory-check.sh's / the
# promise proof's job. This gate has exactly one question: of the files that
# DO exist, is any of them invisible to git?
set -uo pipefail

ROOT="${DO_UNTRACKED_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
VERBOSE=0
say()    { [ "$VERBOSE" -eq 1 ] && echo "      $*" >&2; return 0; }
red()    { echo "RED  $1" >&2; return 1; }
cannot() { echo "CANNOT RUN: $1" >&2; return 3; }

# Paths that are legitimately absent from git and are never a deliverable.
# A `#` comment inside a deliverables block may name one (e.g. an assumes-style
# credential file); reporting those as red would be noise, not a finding.
# `.env` / `.dev.vars` are named inside real `accept:` command lines (sui-upgrade's
# accept sources a key from pay/backend/.dev.vars) — a local secrets file is never
# a deliverable, and flagging it as "can never ship" is noise that trains the
# reader to ignore the gate.
SKIP_RE='(^|/)(node_modules|dist|build|\.wrangler|\.astro)/|(^|/)\.env|(^|/)\.dev\.vars|\.local\.md$|\.keys\.local'

# ── the deliverables: frontmatter block ──────────────────────────────────
# First frontmatter block only. Opens on `^deliverables:` — WITH an optional
# trailing comment: text/marketplace-deal.md and text/template-feature.md both
# write `deliverables:              # THE SCHEDULE …`, and an anchored
# `[[:space:]]*$` never opened the block for them. That produced the worst
# possible verdict — `ok (0 files checked)`, a green earned by reading nothing.
#
# Closes on the first column-0 KEY (`assumes:`, `ux_before:`, `proof:`), not on
# any column-0 non-space char: the equally-valid YAML style puts `- item:` at
# column 0, and closing on `-` would end the block at its first entry — the same
# read-nothing green by a different door. Blank lines and comments inside the
# block are tolerated; the closing `---` ends it via the fm counter.
deliverables_block() { # $1 = file
  awk '
    /^---[[:space:]]*$/ { fm++; if (fm>=2) exit; next }
    fm!=1 { next }
    /^deliverables:[[:space:]]*(#.*)?$/ { ind=1; next }
    ind==1 && /^[A-Za-z_][A-Za-z0-9_.-]*:/ { ind=0 }
    ind==1 { print }
  ' "$1"
}

# ── candidate path extraction ────────────────────────────────────────────
# A candidate is a repo-relative-looking token with a file extension. It must
# contain a `/` — a bare `one.tql` or `do-walk.sh` names a file the writer did
# not locate, and resolving it by basename alone across 7k files invites a
# false positive worse than the miss.
#
# Globs (`text/template-*.md`), brace sets and URLs are dropped: a glob is not a
# path, and a URL is not in the repo.
candidates() { # stdin = block text
  grep -oE '[A-Za-z0-9_@.][A-Za-z0-9_@./+-]*\.[A-Za-z0-9]{1,6}' \
    | grep '/' \
    | grep -vE '://' \
    | grep -vE "$SKIP_RE" \
    | sort -u
}

# ── resolution ───────────────────────────────────────────────────────────
# Two shapes appear in real plans, and the gate is worthless unless it handles
# both — the 2026-07-28 failure had one of each:
#   (a) repo-relative   packages/sdk/src/fn-allowlist.ts        → direct hit
#   (b) package-relative tests/unit/fn-entity-args.test.ts      → suffix match
#                        (that file lives at one.ie/web/tests/unit/…)
# (b) is resolved against the repo's file universe (tracked + untracked-not-
# ignored, one `git ls-files` call). An AMBIGUOUS suffix — more than one hit —
# is NOT skipped: every hit is checked. "Ambiguous → skip" is exactly how this
# bug walks through the gate a second time.
resolve() { # $1 = candidate; prints 0+ repo-relative paths
  local cand="$1"
  if [ -e "$ROOT/$cand" ]; then printf '%s\n' "$cand"; return 0; fi
  printf '%s\n' "$INDEX" | awk -v c="$cand" '
    BEGIN { n=length(c) }
    $0==c { print; next }
    length($0) > n && substr($0, length($0)-n) == "/" c { print }
  '
}

check() { # $1 = slug
  local slug="$1"
  local promise="$ROOT/text/$slug.md" todo="$ROOT/text/$slug-todo.md"
  local block="" found=0 bad=0 checked=0 unresolved=0 cand path

  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
    || { cannot "$ROOT is not a git repo — trackedness is unanswerable here"; return 3; }

  if [ -f "$promise" ]; then block+=$(deliverables_block "$promise")$'\n'; found=1
    else say "no promise at text/$slug.md"; fi
  if [ -f "$todo" ];    then block+=$(deliverables_block "$todo")$'\n';    found=1
    else say "no todo at text/$slug-todo.md"; fi
  [ "$found" -eq 1 ] || { cannot "$slug — neither text/$slug.md nor text/$slug-todo.md exists"; return 3; }

  INDEX="$(git -C "$ROOT" ls-files --cached --others --exclude-standard)"

  while IFS= read -r cand; do
    [ -z "$cand" ] && continue
    local hits; hits="$(resolve "$cand")"
    if [ -z "$hits" ]; then
      unresolved=$((unresolved+1)); say "skip (not on disk): $cand"; continue
    fi
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      [ -d "$ROOT/$path" ] && { say "skip (directory): $path"; continue; }
      checked=$((checked+1))
      if git -C "$ROOT" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
        say "tracked: $path"; continue
      fi
      # tracked-first is deliberate: a file that is both tracked and matched by
      # .gitignore is tracked, and git ships it.
      if git -C "$ROOT" check-ignore -q -- "$path" 2>/dev/null; then
        red "GITIGNORED deliverable: $path — exists, matched by .gitignore, CAN NEVER SHIP (named by $slug)"
      else
        red "UNTRACKED deliverable: $path — exists on disk, absent from git; \`git add $path\` or it never reaches main"
      fi
      bad=$((bad+1))
    done <<<"$hits"
  done < <(printf '%s' "$block" | candidates)

  if [ "$bad" -gt 0 ]; then
    echo "[untracked-gate] $slug — $bad/$checked existing deliverable file(s) not in git" >&2
    return 1
  fi
  echo "[untracked-gate] $slug — ok ($checked existing deliverable file(s) tracked, $unresolved path(s) not on disk / not resolvable)"
  return 0
}

# ── self-test ────────────────────────────────────────────────────────────
# Drives a GREEN fixture and a RED fixture through a real temp git repo. No
# commit is needed: `git ls-files --error-unmatch` answers from the INDEX, so
# `git add` alone makes a file tracked and the test needs no user.name/email.
# The red fixture also exercises the package-relative suffix resolver — the
# shape that carried half the real 2026-07-28 failure.
self_test() {
  local fails=0 rc out
  dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
  git -C "$dir" init -q
  mkdir -p "$dir/text" "$dir/packages/sdk/src" "$dir/web/tests/unit"

  # A promise + todo naming two deliverables: one repo-relative, one package-relative.
  printf -- '---\nslug: green\ndeliverables:\n  - item: "the allowlist"\n    accept: "test -f packages/sdk/src/fn-allowlist.ts"\n---\n' \
    >"$dir/text/green.md"
  printf -- '---\nslug: green\ndeliverables:\n  - test: "tests/unit/fn-entity-args.test.ts — entity-param binding proven (C7)"\n\nux_before: "x"\n---\n' \
    >"$dir/text/green-todo.md"
  sed 's/green/red/' "$dir/text/green.md"      >"$dir/text/red.md"
  sed 's/green/red/' "$dir/text/green-todo.md" >"$dir/text/red-todo.md"

  : >"$dir/packages/sdk/src/fn-allowlist.ts"
  : >"$dir/web/tests/unit/fn-entity-args.test.ts"
  git -C "$dir" add text packages/sdk/src/fn-allowlist.ts >/dev/null 2>&1

  # RED: the package-relative test file exists but was never `git add`ed —
  # the exact 2026-07-28 shape.
  ROOT="$dir" VERBOSE=0 check red >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL red fixture: expected exit 1, got $rc"; fails=$((fails+1)); }
  # captured, never piped into `grep -q`: pipefail + grep's early exit SIGPIPEs
  # the producer and reports 141 for a pipeline that actually matched.
  out="$(ROOT="$dir" VERBOSE=0 check red 2>&1)"
  case "$out" in *fn-entity-args.test.ts*) ;; *)
    echo "FAIL red fixture: reason must name the untracked file"; fails=$((fails+1)) ;; esac

  # GREEN: same fixture once the file is tracked.
  git -C "$dir" add web/tests/unit/fn-entity-args.test.ts >/dev/null 2>&1
  ROOT="$dir" VERBOSE=0 check green >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL green fixture: expected exit 0, got $rc"; fails=$((fails+1)); }

  # GITIGNORED: a deliverable git can never ship must be loud, not silent.
  printf 'packages/sdk/src/fn-allowlist.ts\n' >"$dir/.gitignore"
  git -C "$dir" rm --cached -q packages/sdk/src/fn-allowlist.ts >/dev/null 2>&1
  out="$(ROOT="$dir" VERBOSE=0 check green 2>&1)"
  case "$out" in *GITIGNORED*) ;; *)
    echo "FAIL gitignored fixture: expected a GITIGNORED reason"; fails=$((fails+1)) ;; esac

  # BLOCK BOUNDARY: a `deliverables:   # trailing comment` header with its entries
  # at COLUMN 0. Both shapes exist in text/ and both used to yield an empty block
  # — i.e. exit 0 having checked nothing. The fixture must go RED.
  mkdir -p "$dir/text" "$dir/src"
  : >"$dir/src/lonely.ts"
  printf -- '---\nslug: shape\ndeliverables:   # THE SCHEDULE\n- item: "a thing"\n  accept: "test -f src/lonely.ts"\n\nproof: "x"\n---\n' \
    >"$dir/text/shape.md"
  ROOT="$dir" VERBOSE=0 check shape >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL block-boundary: comment header + column-0 entries must still parse (got $rc)"; fails=$((fails+1)); }

  # CANNOT RUN: no promise and no todo → 3, never 1.
  ROOT="$dir" check nosuchslug >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 3 ] || { echo "FAIL missing-slug: expected exit 3, got $rc"; fails=$((fails+1)); }

  echo "[untracked-gate] self-test: 6 assertions, $fails failed"
  return "$fails"
}

case "${1:-}" in
  --self-test) self_test; exit $? ;;
  ""|-*)       echo "usage: do-untracked-gate.sh <slug> [--verbose] | --self-test" >&2; exit 4 ;;
esac
[ "${2:-}" = "--verbose" ] && VERBOSE=1
check "$1"
