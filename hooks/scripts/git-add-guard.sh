#!/usr/bin/env bash
# GIT-ADD-GUARD — PreToolUse(Bash): block blanket staging on the SHARED MAIN tree.
#
# Multiple windows share ONE working tree on `main`. A blanket `git add -A` /
# `git add .` / `git commit -a` stages EVERY uncommitted file — sweeping a
# neighbouring window's in-progress work into THIS commit (wrong attribution,
# tangled history that can't be undone without rewriting shared main).
# Happened 2026-06-20: types/viewer work landed inside do(funnels) commits.
#
# Rule: blanket staging is allowed ONLY inside an isolated linked worktree
# (git-dir under .git/worktrees/…). On the main tree it is denied — stage by
# explicit path, or work in a worktree.
#
# Carve-out: an operator deploy/release (command contains `git push`) is an
# intentional whole-tree publish and is allowed — only the silent per-cycle
# sweep (add -A + commit, no push) is blocked.
#
# SCOPE (2026-09-22): everything above is a fact about the one-ie/one monorepo
# and about no other repo. This hook ships in @oneie/claude, so it runs in
# strangers' trees, where there is no shared main tree and no worktree
# discipline to enforce — and the `/worktrees/` test alone is satisfied by every
# ordinary repo on earth. `_is_one_monorepo` gates the whole refusal on the
# canon marker `schema/one.tql` at the target repo's toplevel; outside this
# monorepo the hook is a silent no-op. The marker, not the origin remote:
# origin here is `github.com/one-ie/repo.git`, and a `github.com/one-ie/` prefix
# would also match the mirror repos (`.claude/` ships to one-ie/claude). Inline
# rather than in hooks/lib/hook.sh because a plugin install cannot source that
# lib at all — full account in dev-only.sh's header.
#
# Disable: ECC_DISABLED_HOOKS=hook:git-add-guard

# shellcheck source=lib/hook.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh"
is_hook_disabled "hook:git-add-guard" && exit 0

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
printf '%s' "$CMD" | grep -qE '\bgit\b' || exit 0

# Blanket stage = `add -A`, `add --all`, `add .` (bare dot), or `commit` with a
# short-flag cluster containing `a` (-a/-am/…) or `--all`. (`--amend`/`--author`
# are `--` long flags, so the `-[a-z]*a` short-cluster test never matches them.)
# Also blanket: any MUTATING `git stash` (bare/push/-u/pop/apply/drop) — a stash
# on the shared main tree sweeps every neighbour's uncommitted work into one
# stash entry, and pop/apply dumps foreign state back mixed with yours
# (near-miss 2026-07-06: a loop conductor ran `git stash -u` on main and picked
# up a neighbour's edits). `stash list` / `stash show` are read-only — allowed.
_is_blanket() {
  printf '%s' "$1" | grep -qE '\bgit\b[^|&;]*\badd\b[^|&;]*(-A\b|--all\b|[[:space:]]\.([[:space:]]|$))' && return 0
  printf '%s' "$1" | grep -qE '\bgit\b[^|&;]*\bcommit\b[^|&;]*([[:space:]]-[a-zA-Z]*a[a-zA-Z]*\b|--all\b)' && return 0
  if printf '%s' "$1" | grep -qE '\bgit\b[^|&;]*\bstash\b' \
     && ! printf '%s' "$1" | grep -qE '\bgit\b[^|&;]*\bstash\b[[:space:]]+(list|show)\b'; then
    return 0
  fi
  return 1
}
# Any commit on the shared main tree — main receives PRs, never development.
# QUOTE-STRIPPED and POSITION-ANCHORED, so a command that merely NAMES a commit
# — a grep for "git commit", a commit message quoting it, a doc being written —
# is never refused. Measured 2026-09-07: the unanchored form denied
# `grep -rn "git commit" text/`.
_is_commit() {
  local bare
  bare=$(printf '%s' "$1" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
  printf '%s' "$bare" | grep -qE '(^|[;&|][[:space:]]*)git[^;&|]*[[:space:]]commit([[:space:]]|$)'
}

_is_blanket "$CMD" || _is_commit "$CMD" || exit 0

# Carve-out: deploy/release publishes the whole tree on purpose.
printf '%s' "$CMD" | grep -qE '\bgit\b[^|&;]*\bpush\b' && exit 0

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
# Unresolvable shell-var path (e.g. "$WT") — fall back to the tool cwd.
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
[[ -z "$GITDIR" ]] && exit 0                       # not a git repo — let git handle it
case "$GITDIR" in */worktrees/*) exit 0 ;; esac    # isolated linked worktree — blanket is safe

# Main tree → deny. A plain commit gets the dev-only rule; a blanket action gets
# the sweep warning. Both refuse; the reason must name the right one.
if ! _is_blanket "$CMD"; then
  CMSG="[git-add-guard] Development on the shared main tree is blocked — we develop on dev.

main receives a PULL REQUEST from dev and nothing else. It is never edited,
never committed to directly, and production only ever ships from a sha that
arrived on main that way.

Do this instead:
  bash .claude/scripts/worktree-up.sh <name> --no-dev   # cut from dev
  ...edit, then...
  bash .claude/scripts/land.sh feat/<name>              # lands on DEV
  gh pr create --base main --head dev                   # the only door to main

Why: on 2026-09-07 four commits went straight onto main while seven sessions
shared this tree, and an hour-cold ad conversion map plus its test sat
uncommitted in it — invisible to every branch, and one blanket stage away from
landing in a stranger's commit.

Override once, for a deliberate rescue:  ECC_DISABLED_HOOKS=hook:git-add-guard"
  jq -nc --arg r "$CMSG" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
  exit 0
fi

MSG="[git-add-guard] Blanket staging/stashing on the shared main tree is blocked.

Multiple windows share this working tree. A blanket add (-A, bare dot, commit -a)
or a mutating stash (bare/push/-u/pop/apply) sweeps a neighbouring window's
uncommitted work into your commit or stash
(the do(funnels) tangle 2026-06-20; the stash -u near-miss 2026-07-06).

Do one of:
  - stage by explicit path:    git add path/to/file ...
  - isolate the work:          git worktree add -b feat/<slug> ../wt-<slug> main
  - read-only stash views (git stash list / show) are always allowed

Deploy/release (a command containing git push) is exempt.
Override once for a deliberate scoped action:  ECC_DISABLED_HOOKS=hook:git-add-guard"
jq -nc --arg r "$MSG" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
exit 0
