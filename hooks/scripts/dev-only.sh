#!/usr/bin/env bash
# DEV-ONLY — PreToolUse(Edit|Write|MultiEdit, Bash): development happens on
# `dev`, or in a worktree cut from `dev`. Never on the shared main tree.
#
# THE RULE, in one line: main RECEIVES, it does not get EDITED.
#
# WHY THIS EXISTS — three measured failures, none of them theoretical:
#
#   1. WORK VANISHES. 2026-09-16: a session deleted eight root .astro pages in
#      the shared main tree and never committed. The 12:14 reboot killed it,
#      `git pull --ff-only` fast-forwarded main, and every deleted file came
#      back. `git status` was CLEAN afterwards, so nothing recorded that the
#      work had existed at all. The operator reported it as "I deleted them but
#      they don't seem to be deleted" — which is exactly what it looks like.
#
#   2. THE RECEIPT CAN NEVER BIND. `test-cached.sh` keys on tree CONTENT
#      (`git diff HEAD` + untracked + .env). A gate run on a main tree that any
#      neighbour is editing measures a MOVING tree, so it mints a receipt for a
#      state that never ships. 2026-09-05: four full suites, ~25 minutes, zero
#      receipts. `./deploy` from main was simply never runnable that day.
#
#   3. A DEV SERVER ON MAIN SERVES THE STALE TRUNK. Every page it renders is a
#      false reading — the same false-RED class as running a gate there.
#      2026-09-16: localhost:4321 answered /media with 200 for hours after the
#      page was deleted on dev, because it was booted from the main tree.
#
# WHAT IS ALLOWED. Any linked worktree — its git-dir sits under
# `.git/worktrees/…`, which is the test this hook uses. That covers
# `.claude/worktrees/dev` (the workbench), every `feat/*` tree cut from dev,
# and `.release` (which must stay writable: it is how prod ships). Anything
# outside the repo entirely is none of this hook's business — and since
# 2026-09-22 that sentence is IMPLEMENTED, not merely intended.
#
# WHY THE REPO-IDENTITY GATE EXISTS (2026-09-22). The main/worktree test above
# is a fact about THIS monorepo and nowhere else. Until this gate landed the
# hook asked only "is the target's git-dir free of /worktrees/?", which is TRUE
# of every ordinary git repo on earth — so a freshly `git init`'d scratch
# directory answered `permissionDecision: deny`. That was harmless while the
# hook only ran here, and became shipped-severity when `hooks/hooks.json` wired
# it into the @oneie/claude plugin (0a6021a5f): every plugin installer editing a
# file in their own unrelated repo would have had EVERY Edit and Write refused,
# with a message telling them to `cd .claude/worktrees/dev`. Measured before the
# fix: `git init` in /tmp, point the hook at a file in it -> deny.
#
# The identity test is the canon marker `schema/one.tql` at the target repo's
# toplevel, NOT the origin remote. Two measured reasons the remote is wrong:
# this repo's origin is `github.com/one-ie/repo.git`, so a check for
# `one-ie/one` would match nothing and silently turn all three hooks into
# permanent no-ops HERE (the opposite failure, and invisible); and a
# `github.com/one-ie/` prefix would match the mirror repos — `.claude/` itself
# ships to github.com/one-ie/claude — so a contributor in a plugin-repo clone
# would still be denied. The marker is offline, needs no remote configured, and
# is present in the primary tree, every linked worktree and `.release` alike.
#
# It is INLINE in each of the three scripts (dev-only, git-add-guard,
# branch-pin) and deliberately not in hooks/lib/hook.sh: a plugin install
# sources that lib by `${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh`, which
# does not exist there, and without `set -e` the script CONTINUES past the
# failed source into the deny logic. A helper in lib/ would be undefined in the
# only environment this fix exists for. `_target()` is already duplicated
# between git-add-guard.sh and branch-pin.sh for the same self-containment.
#
# WHERE TO GO INSTEAD:
#   small, hours   ->  .claude/worktrees/dev          (already minted and warm)
#   large or long  ->  bash .claude/scripts/worktree-up.sh <name> --no-dev
#                      (cuts from dev by default — worktree-up.sh:63 BASE="dev")
#
# Disable: ECC_DISABLED_HOOKS=hook:dev-only

# shellcheck source=lib/hook.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh"
is_hook_disabled "hook:dev-only" && exit 0

PAYLOAD="${1:-}"
# Claude Code delivers the payload on STDIN; argv stays first so a positional
# caller still works. Bounded read — a bare $(cat) hangs forever on a tty and
# would freeze every Edit and every Bash call in the session.
if [[ -z "$PAYLOAD" && ! -t 0 ]]; then
  IFS= read -r -d '' -t 2 PAYLOAD <&0 || true
fi
[[ -z "$PAYLOAD" ]] && exit 0

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)

# ── is <dir> inside the one-ie/one monorepo? ─────────────────────────────────
# The canon marker `schema/one.tql` at the repo toplevel. See the header block
# for why this is a marker and not the origin remote, and why it is inline.
# Returns 1 for a non-repo, an unrelated repo, or any repo lacking the marker —
# and 1 means "not ours", which means the caller must ALLOW.
_is_one_monorepo() {
  local d="$1" top
  [[ -d "$d" ]] || return 1
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || return 1
  [[ -n "$top" && -f "$top/schema/one.tql" ]]
}

# ── is this path inside the SHARED MAIN tree? ────────────────────────────────
# A linked worktree's absolute git-dir contains /worktrees/. The primary tree's
# does not. That single fact is the whole test, and it needs no path list that
# could drift as worktrees come and go — but it is only MEANINGFUL inside this
# monorepo, so the identity gate runs first.
_is_shared_main() {
  local p="$1" d gitdir
  [[ -z "$p" ]] && return 1
  # A Write to a file that does not exist yet still has an existing parent.
  d="$p"; while [[ -n "$d" && "$d" != "/" && ! -d "$d" ]]; do d=$(dirname "$d"); done
  [[ -d "$d" ]] || return 1
  _is_one_monorepo "$d" || return 1                  # not one-ie/one — not ours
  gitdir=$(git -C "$d" rev-parse --absolute-git-dir 2>/dev/null) || return 1
  [[ -z "$gitdir" ]] && return 1
  case "$gitdir" in */worktrees/*) return 1 ;; esac   # linked worktree — fine
  return 0
}

_deny() {
  jq -nc --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
  exit 0
}

WHERE="Work in the dev worktree, or a worktree cut from it:

  small, hours   cd .claude/worktrees/dev
  large or long  bash .claude/scripts/worktree-up.sh <name> --no-dev

Both are cut from \`dev\`, which is the branch every feature integrates into.
main receives \`--ff-only\` merges and a release PR; it is not an edit surface.

Override, for a deliberate one-off:  ECC_DISABLED_HOOKS=hook:dev-only"

case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit)
    FP=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
    [[ -z "$FP" ]] && exit 0
    _is_shared_main "$FP" || exit 0
    _deny "[dev-only] This file is in the SHARED MAIN tree. Development happens on dev.

  $FP

An edit here is not saved work. Main gets fast-forwarded by whichever session
pulls next, and an uncommitted change is silently reverted — on 2026-09-16 that
resurrected eight deleted pages and left \`git status\` clean, so nothing
recorded that the work had ever existed.

$WHERE"
    ;;

  Bash)
    CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
    [[ -z "$CMD" ]] && exit 0
    # Strip heredoc bodies so a command that merely NAMES a dev server in a
    # commit message or a doc is never refused — same discipline as
    # hook:governor-escape.
    STRIPPED=$(printf '%s' "$CMD" | sed -E '/<<-?[A-Za-z_'"'"'"]/,/^[[:space:]]*[A-Za-z_]+[[:space:]]*$/d')
    printf '%s' "$STRIPPED" | grep -qE '(^|[|&;[:space:]])(astro[[:space:]]+dev|(bun|npm|pnpm|yarn)[[:space:]]+run[[:space:]]+dev)([[:space:]]|$)' || exit 0

    # Where would it run? An explicit `cd` wins, else the tool's cwd.
    TARGET=$(printf '%s' "$CMD" | grep -oE "(^|&&|;|\|)[[:space:]]*cd[[:space:]]+(\"[^\"]+\"|'[^']+'|[^[:space:]]+)" | head -1 \
             | sed -E "s/.*cd[[:space:]]+//; s/^[\"']//; s/[\"']\$//")
    [[ -z "$TARGET" ]] && TARGET=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
    case "$TARGET" in *'$'*) TARGET=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // "."' 2>/dev/null) ;; esac
    [[ -z "$TARGET" ]] && TARGET="."
    _is_shared_main "$TARGET" || exit 0
    _deny "[dev-only] A dev server started here serves the STALE TRUNK.

  $TARGET

Every page it renders is a false reading: main does not carry what dev has
integrated. Measured 2026-09-16 — localhost:4321 answered /media with 200 for
hours after that page was deleted on dev, because the server was booted from
the main tree. One dev server, and it runs on dev.

  cd .claude/worktrees/dev/one.ie/web && bun run dev

$WHERE"
    ;;
esac

exit 0
