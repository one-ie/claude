#!/usr/bin/env bash
# BRANCH-PIN — PreToolUse(Bash): the SHARED MAIN tree's HEAD is pinned.
#
# Multiple windows share ONE working tree. When any session switches HEAD
# (`git checkout <branch>`, `git switch`, `checkout -b`), every neighbouring
# session is silently pulled onto that branch — their reads see its files and
# their commits land on it (3 collisions 2026-07-08; do loops confused across
# sessions 2026-07-21). Branch work belongs in a linked worktree:
#   bash .claude/scripts/do-auto.sh <slug> --setup-only     # /do plans
#   git worktree add -b feat/<slug> .do-worktrees/<slug> main   # anything else
#
# Rule: on the shared main tree, any command that moves HEAD is denied —
# EXCEPT converging back to `main` (re-parking is the one allowed direction).
# Inside a linked worktree (git-dir under .git/worktrees/…) everything is
# allowed. Pathspec restores (`checkout [<ref>] -- <paths>`) don't move HEAD
# and pass through here (git-add-guard territory).
#
# SCOPE (2026-09-22): "the shared main tree" names a fact about the one-ie/one
# monorepo and about no other repo. This hook ships in @oneie/claude, so it runs
# in strangers' trees — and the `/worktrees/` test alone is satisfied by every
# ordinary repo, which would have made `git checkout -b` refusable in a plugin
# user's own project. `_is_one_monorepo` gates the refusal on the canon marker
# `schema/one.tql` at the target repo's toplevel; outside this monorepo the hook
# is a silent no-op. Marker not remote, inline not lib/ — dev-only.sh's header
# carries the full account of both.
#
# Disable: ECC_DISABLED_HOOKS=hook:branch-pin

# shellcheck source=lib/hook.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh"
is_hook_disabled "hook:branch-pin" && exit 0

PAYLOAD="${1:-}"
# Claude Code delivers the hook payload on STDIN; argv stays first so any
# caller that passes it positionally still works. Bounded read: a bare $(cat)
# would hang forever on a tty or an idle pipe, freezing every Bash call.
if [[ -z "$PAYLOAD" && ! -t 0 ]]; then
  IFS= read -r -d '' -t 2 PAYLOAD <&0 || true
fi
[[ -z "$PAYLOAD" ]] && exit 0

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL" == "Bash" ]] || exit 0

CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# The checkout/switch segment (up to a pipe/;/&&). `git worktree add` contains
# neither verb and never matches.
SEG=$(printf '%s' "$CMD" | grep -oE '\bgit\b[^|&;]*\b(checkout|switch)\b[^|&;]*' | head -1)
[[ -z "$SEG" ]] && exit 0

# A `--` pathspec means file restore, not a HEAD move.
printf '%s' "$SEG" | grep -qE '[[:space:]]--([[:space:]]|$)' && exit 0

# BSD sed has no \b — use an explicit space boundary.
ARGS=$(printf '%s' "$SEG" | sed -E 's/.*[[:space:]](checkout|switch)([[:space:]]+|$)/ /')

# Branch creation / detach / previous-branch shorthand always move HEAD.
if printf '%s' "$ARGS" | grep -qE '(^|[[:space:]])(-b|-B|-c|-C|--orphan|--detach|-)([[:space:]]|$)'; then
  :
else
  # First non-flag arg is the target ref; bare `git checkout` errors on its own.
  REF=""
  for a in $ARGS; do case "$a" in -*) ;; *) REF="$a"; break ;; esac; done
  [[ -z "$REF" ]] && exit 0
  [[ "$REF" == "main" ]] && exit 0   # converging home is allowed
fi

# Resolve the target dir: `git -C <path>`, else a leading `cd <path>`, else cwd.
_target() {
  local c="$1" t=""
  t=$(printf '%s' "$c" | grep -oE "git[[:space:]]+-C[[:space:]]+(\"[^\"]+\"|'[^']+'|[^[:space:]]+)" | head -1 | sed -E "s/^git[[:space:]]+-C[[:space:]]+//; s/^[\"']//; s/[\"']$//")
  if [[ -z "$t" ]]; then
    t=$(printf '%s' "$c" | grep -oE "(^|&&|;|\|)[[:space:]]*cd[[:space:]]+(\"[^\"]+\"|'[^']+'|[^[:space:]]+)" | head -1 | sed -E "s/.*cd[[:space:]]+//; s/^[\"']//; s/[\"']$//")
  fi
  [[ -z "$t" ]] && t=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
  [[ -z "$t" ]] && t="."
  printf '%s' "$t"
}
TARGET="$(_target "$CMD")"
case "$TARGET" in *'$'*) TARGET=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // "."' 2>/dev/null) ;; esac

# Is the target inside the one-ie/one monorepo? Canon marker at the toplevel —
# see the SCOPE note in the header. 1 = not ours = allow, silently.
_is_one_monorepo() {
  local d="$1" top
  [[ -d "$d" ]] || return 1
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || return 1
  [[ -n "$top" && -f "$top/schema/one.tql" ]]
}
_is_one_monorepo "$TARGET" || exit 0               # unrelated repo — not ours

GITDIR=$(git -C "$TARGET" rev-parse --absolute-git-dir 2>/dev/null)
[[ -z "$GITDIR" ]] && exit 0                       # not a git repo
case "$GITDIR" in */worktrees/*) exit 0 ;; esac    # linked worktree — switch freely

MSG="[branch-pin] HEAD switches on the shared main tree are blocked.

Multiple sessions share this working tree; moving HEAD pulls every one of
them onto your branch — their reads and commits land there silently.

Do the work in a linked worktree instead:
  - /do plan:        bash .claude/scripts/do-auto.sh <slug> --setup-only
  - anything else:   git worktree add -b feat/<slug> .do-worktrees/<slug> main
  - returning home:  git switch main   (always allowed)

Override for a deliberate switch:  ECC_DISABLED_HOOKS=hook:branch-pin"
jq -nc --arg r "$MSG" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
exit 0
