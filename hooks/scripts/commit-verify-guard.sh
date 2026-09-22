#!/usr/bin/env bash
# COMMIT-VERIFY-GUARD — PreToolUse(Bash): refuse an agent's attempt to commit
# with the hooks turned off. A3 of text/do-factory-plan.md.
#
# The secret scan is a git `pre-commit` hook so that a doer cannot skip it. Git
# leaves exactly one door open — `--no-verify` (and its short form `-n`, and a
# `-c core.hooksPath=…` override) — and this closes that door for the agent that
# would take it under pressure. A HUMAN overriding a false positive at their own
# terminal is untouched; this hook only sees the Bash tool.
#
# hook:git-add-guard cannot carry this rule: that hook deliberately allows
# everything inside a linked worktree (git-add-guard.sh:90), and a linked
# worktree is exactly where the factory commits.
#
# THE CHANNEL IS NAMED, NOT ASSUMED. On 2026-08-21 all five blocking PreToolUse
# hooks opened with PAYLOAD="${1:-}" then exited 0 when it was empty — while the
# runtime was writing STDIN. Every one had been dark from the day it was
# written, and every presence check said "wired". So the payload comes from
# hook_payload_channel(), which reports argv / stdin / DARK, and the self-test
# (factory-secret-gate.sh --self-test, case 4) drives THIS FILE with a real
# payload on stdin and asserts the deny JSON.
#
# ON DARK IT ALLOWS, deliberately. hook.sh:84-86 is explicit: a guard that
# refuses on an absent payload wedges the session. That is not a hole in the
# rung — the git hook carries fail-closed and cannot be dark, because git runs
# it whether or not anything is listening. This guard is the --no-verify door
# only.
#
# Quote-stripped and POSITION-ANCHORED, like git-add-guard.sh:62-66: a command
# that merely NAMES the escape — a grep, a commit message quoting it, a doc
# being written — is never refused. The unanchored form denied
# `grep -rn "git commit" text/` on 2026-09-07.
#
# Disable: ECC_DISABLED_HOOKS=hook:commit-verify-guard

# shellcheck source=lib/hook.sh
# BASH_SOURCE FIRST, CLAUDE_PROJECT_DIR last: that variable is set by the runtime
# and is UNSET in a plain shell, which is exactly how the self-test invokes this
# file (session-start.sh records the same trap). The `../lib` rung is for the
# packages/claude mirror, where this file sits in hooks/scripts/ and the library
# one directory up in hooks/lib/ — a verbatim copy that cannot find its library
# is the kind of mirror rot .claude/rules/scripts.md is about.
for _hooklib in \
  "${BASH_SOURCE[0]%/*}/lib/hook.sh" \
  "${BASH_SOURCE[0]%/*}/../lib/hook.sh" \
  "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh"
do
  [ -r "$_hooklib" ] && { source "$_hooklib"; break; }
done
# No library ⇒ no payload reader ⇒ ALLOW. Same rule as DARK: this guard is the
# --no-verify door, and the git pre-commit hook is what fails closed.
command -v hook_payload_channel >/dev/null 2>&1 || exit 0
is_hook_disabled "hook:commit-verify-guard" && exit 0

# CALLED IN THIS SHELL, never as $(...). A command substitution runs the helper
# in a SUBSHELL, so HOOK_PAYLOAD is set there and dies there: the channel word
# comes back correctly reading "stdin" while the payload is EMPTY — and the
# guard then exits 0 on the tool_name check and allows --no-verify. That is the
# 2026-08-21 shape wearing the helper as a disguise, and it is measured, not
# theoretical: it is what the first draft of this file did on 2026-09-21, and
# case 4 of factory-secret-gate.sh --self-test is what caught it.
# HOOK_CHANNEL_OUT lets a caller (the self-test) read the channel word back.
hook_payload_channel "${1:-}" > "${HOOK_CHANNEL_OUT:-/dev/null}"
PAYLOAD="$HOOK_PAYLOAD"
[[ -z "$PAYLOAD" ]] && exit 0    # DARK — allow. hook.sh:84-86: refusing here wedges the session.

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL" == "Bash" ]] || exit 0

CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# Strip quoted strings first — a commit MESSAGE naming the flag is not a use of
# it — then require a `git … commit` at a command position.
BARE=$(printf '%s' "$CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
printf '%s' "$BARE" | grep -qE '(^|[;&|][[:space:]]*)git([[:space:]]|$)' || exit 0
printf '%s' "$BARE" | grep -qE '(^|[;&|][[:space:]]*)git[^;&|]*[[:space:]]commit([[:space:]]|$)' || exit 0

# Three ways to turn the hooks off on a commit:
#   --no-verify          the documented escape
#   -n / a short cluster containing n   the same thing, two characters
#   -c core.hooksPath=…  points git at a hooks dir that has no pre-commit
WHICH=""
printf '%s' "$BARE" | grep -qE '[[:space:]]--no-verify([[:space:]]|$)' && WHICH="--no-verify"
[[ -z "$WHICH" ]] && printf '%s' "$BARE" | grep -qE '[[:space:]]commit[^;&|]*[[:space:]]-[a-mo-zA-Z]*n[a-zA-Z]*([[:space:]]|$)' && WHICH="-n"
[[ -z "$WHICH" ]] && printf '%s' "$BARE" | grep -qE 'core\.hooksPath[[:space:]]*=' && WHICH="core.hooksPath override"
[[ -z "$WHICH" ]] && exit 0

MSG="[commit-verify-guard] Committing with the git hooks turned off ($WHICH) is refused.

The pre-commit hook is the secret scan (.claude/hooks/git/pre-commit). It exists
precisely because a scan a doer is ASKED to run is a scan a doer under pressure
skips — so skipping it is the one thing it may not allow.

If the gate refused you, it printed the path, the pattern label and the line
numbers (never the matched text). Do one of:
  - remove the secret and commit again
  - if it is a false positive, say so and let a HUMAN decide — a person at their
    own terminal is not blocked by this hook
  - see exactly what it saw:  git diff --cached -- <path>

Override once, deliberately:  ECC_DISABLED_HOOKS=hook:commit-verify-guard"

jq -nc --arg r "$MSG" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
exit 0
