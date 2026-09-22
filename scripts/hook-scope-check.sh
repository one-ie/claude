#!/usr/bin/env bash
# hook-scope-check.sh — prove the three "shared main tree" hooks only ever
# refuse INSIDE the one-ie/one monorepo.
#
# THE BUG THIS PINS (measured 2026-09-22). dev-only.sh, git-add-guard.sh and
# branch-pin.sh each decided "is this the shared main tree?" with ONE test: does
# the target's absolute git-dir contain `/worktrees/`? A linked worktree's does;
# the primary tree's does not. True — and true of EVERY ordinary git repo on
# earth, none of which is this monorepo. Pointed at a freshly `git init`'d
# scratch directory, dev-only.sh answered `permissionDecision: deny`.
#
# That was harmless while the hooks only ran here. It became shipped-severity
# when packages/claude/hooks/hooks.json wired dev-only into the @oneie/claude
# plugin (0a6021a5f): every plugin installer editing a file in their own,
# unrelated repository would have had EVERY Edit and Write refused, with a
# message telling them to cd into a worktree they do not have. git-add-guard and
# branch-pin carried the identical defect with a narrower blast radius — they
# refuse specific git subcommands rather than all editing.
#
# The fix is a repo-identity gate in front of the existing logic: the canon
# marker `schema/one.tql` at the TARGET repo's toplevel. Not the origin remote —
# this repo's origin is `github.com/one-ie/repo.git`, so a check for `one-ie/one`
# would match nothing and turn all three hooks into permanent no-ops HERE, and a
# `github.com/one-ie/` prefix would match the mirror repos (`.claude/` ships to
# github.com/one-ie/claude), denying a contributor in a plugin-repo clone.
#
# FIVE CASES, and the last two are the ones that make the first three mean
# something:
#
#   a  unrelated scratch repo            -> ALLOW  (the shipped bug)
#   b  the real SHARED MAIN tree         -> DENY   (protection intact)
#   c  a real linked worktree            -> ALLOW  (unchanged)
#   d  .release                          -> ALLOW  (prod ships from there)
#   e  scratch repo + a schema/one.tql   -> DENY   (the RED proof: the gate is
#                                           reading the MARKER, and this checker
#                                           can reach a DENY verdict at all)
#
# Case (b) asserts the REASON STRING, not merely "something was refused" — a
# gate that silently stopped matching would otherwise read green here, which is
# exactly the failure mode a remote-URL identity test would have introduced.
#
# Usage: bash .claude/scripts/hook-scope-check.sh
# Exit:  0 all cases correct · 1 one or more wrong · 2 cannot reach the tree
#
# manifest: monorepo-only   (the convenience copy; the AUTHORITY is the heredoc
# in factory-repo.sh, which the portability check actually reads.) monorepo-only
# because cases (b)(c)(d) need the real tree. sync-claude-mirror.sh copies all
# of .claude/scripts/ into the plugin regardless; there it simply exits 2 on the
# "not the one-ie monorepo" guard rather than reporting a false pass.

set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
# The SHARED MAIN tree, resolved from wherever this runs: every linked worktree
# shares one common git dir, and the primary tree is its parent.
COMMON=$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 2
MAIN=$(dirname "$COMMON")
[ -f "$MAIN/schema/one.tql" ] || { echo "hook-scope-check: $MAIN is not the one-ie monorepo" >&2; exit 2; }

HOOKS="$HERE/.claude/hooks"
for h in dev-only git-add-guard branch-pin; do
  [ -f "$HOOKS/$h.sh" ] || { echo "hook-scope-check: missing $HOOKS/$h.sh" >&2; exit 2; }
done

TMP=$(mktemp -d) || exit 2
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# ── the two scratch repos ────────────────────────────────────────────────────
# (a) plain: what a plugin user's own project looks like.
# (e) same, plus the canon marker: the red proof.
mk_repo() { # mk_repo <dir> [marker]
  mkdir -p "$1" && git -C "$1" init -q .
  printf 'x\n' > "$1/a.txt"
  if [ "${2:-}" = marker ]; then mkdir -p "$1/schema" && printf '# stand-in\n' > "$1/schema/one.tql"; fi
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" -c user.email=t@example.invalid -c user.name=t commit -qm init >/dev/null 2>&1
}
PLAIN="$TMP/plain"; mk_repo "$PLAIN"
MARKED="$TMP/marked"; mk_repo "$MARKED" marker

# ── a real linked worktree of THIS repo, with a checkout ─────────────────────
# Must be a real one: a `git worktree add --no-checkout` tree has no
# schema/one.tql, so it would be allowed for the WRONG reason and the case would
# prove nothing. Never minted here — discovered, or the case is reported UNRUN.
WT=""
RELEASE=""
while IFS= read -r line; do
  case "$line" in worktree\ *) p="${line#worktree }" ;; *) continue ;; esac
  [ "$p" = "$MAIN" ] && continue
  [ -f "$p/schema/one.tql" ] || continue
  case "$p" in */.release) RELEASE="$p" ;; esac
  [ -z "$WT" ] && WT="$p"
done < <(git -C "$MAIN" worktree list --porcelain 2>/dev/null)

bad=0
LAST_OUT=""   # the last refusal body, for check_reason. Assigned in check() and
              # never inside a command substitution: a subshell's assignment is
              # invisible to the parent, and the first draft of this file lost
              # every LAST_OUT that way.

check() { # check <want DENY|ALLOW> <hook> <label> <payload>
  local want="$1" hook="$2" label="$3" got
  LAST_OUT=$(printf '%s' "$4" | CLAUDE_PROJECT_DIR="$HERE" bash "$HOOKS/$hook.sh" 2>/dev/null)
  case "$LAST_OUT" in *'"permissionDecision":"deny"'*) got=DENY ;; *) got=ALLOW ;; esac
  if [ "$got" = "$want" ]; then
    printf '  ok    %-5s %-14s %s\n' "$want" "$hook" "$label"
  else
    printf '  FAIL  %-5s %-14s %s  (got %s)\n' "$want" "$hook" "$label" "$got"
    bad=$((bad + 1))
  fi
}

# Assert the refusal still SAYS what it refused. A hook that stopped matching
# altogether would pass a bare DENY/ALLOW test on every other case and fail only
# here — which is the whole point of asserting the string.
check_reason() { # check_reason <hook> <needle> <label>
  case "$LAST_OUT" in
    *"$2"*) printf '  ok    REASON %-14s %s\n' "$1" "$3" ;;
    *)      printf '  FAIL  REASON %-14s %s  (no %s in refusal)\n' "$1" "$3" "$2"; bad=$((bad + 1)) ;;
  esac
}

edit_payload()   { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/a.txt"},"cwd":"%s"}' "$1" "$1"; }
# Built here rather than typed at a shell: a blanket-stage string in a Bash tool
# command would trip hook:git-add-guard on the test itself.
stage_payload()  { printf '{"tool_name":"Bash","tool_input":{"command":"git -C %s add %s"},"cwd":"%s"}' "$1" "-A" "$1"; }
switch_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"git -C %s checkout -b scope-probe"},"cwd":"%s"}' "$1" "$1"; }

echo "main tree:  $MAIN"
echo "worktree:   ${WT:-<none found>}"
echo ".release:   ${RELEASE:-<none found>}"
echo

echo "--- (a) an UNRELATED repo: every hook must be a silent no-op ---"
check ALLOW dev-only       "scratch repo"        "$(edit_payload "$PLAIN")"
check ALLOW git-add-guard  "scratch repo"        "$(stage_payload "$PLAIN")"
check ALLOW branch-pin     "scratch repo"        "$(switch_payload "$PLAIN")"

echo "--- (b) the SHARED MAIN tree: protection intact, and it says so ---"
check DENY  dev-only       "shared main"         "$(edit_payload "$MAIN")"
check_reason dev-only      "[dev-only]"          "shared main"
check DENY  git-add-guard  "shared main"         "$(stage_payload "$MAIN")"
check_reason git-add-guard "[git-add-guard]"     "shared main"
check DENY  branch-pin     "shared main"         "$(switch_payload "$MAIN")"
check_reason branch-pin    "[branch-pin]"        "shared main"

echo "--- (c) a real linked worktree: allowed, as before ---"
if [ -n "$WT" ]; then
  check ALLOW dev-only      "linked worktree"    "$(edit_payload "$WT")"
  check ALLOW git-add-guard "linked worktree"    "$(stage_payload "$WT")"
  check ALLOW branch-pin    "linked worktree"    "$(switch_payload "$WT")"
else
  echo "  UNRUN  no linked worktree with a checkout — case (c) did not run"
  bad=$((bad + 1))
fi

echo "--- (d) .release: must stay writable, prod ships from it ---"
if [ -n "$RELEASE" ]; then
  check ALLOW dev-only      ".release"           "$(edit_payload "$RELEASE")"
else
  echo "  n/a    no .release worktree on this box"
fi

echo "--- (e) RED proof: scratch repo carrying schema/one.tql must be REFUSED ---"
check DENY  dev-only       "marked scratch"      "$(edit_payload "$MARKED")"
check DENY  git-add-guard  "marked scratch"      "$(stage_payload "$MARKED")"
check DENY  branch-pin     "marked scratch"      "$(switch_payload "$MARKED")"

echo
if [ "$bad" -eq 0 ]; then
  echo "RESULT: all correct — the three hooks refuse only inside one-ie/one"
else
  echo "RESULT: $bad wrong"
  exit 1
fi
