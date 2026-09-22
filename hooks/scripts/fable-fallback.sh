#!/usr/bin/env bash
# FABLE-FALLBACK — PreToolUse(Agent): when Fable is unavailable, force Opus.
#
# Policy (set by Tony, 2026-06-18; Fable access restored 2026-07-04):
# FABLE_AVAILABLE=on is set in .claude/settings.json's "env" block, so fable
# spawns are allowed again — this hook is a no-op in that state. It stays
# wired as the BACKSTOP: if Fable access is ever revoked again, flip the env
# var off (or unset it) and every agent spawn requesting model "fable" falls
# back to "opus" automatically, with instructions for the conductor to
# re-spawn on opus. /do has no built-in auto-downgrade, so this guard is the
# enforcement mechanism for that case.
#
# Toggle:
#   FABLE_AVAILABLE=on    — allow fable spawns (current state; set in the
#                           "env" block of .claude/settings.json)
#   default / unset / any other value → fable blocked, opus enforced.
#
# Disable this hook entirely: ECC_DISABLED_HOOKS=hook:fable-fallback

# shellcheck source=lib/hook.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh"
is_hook_disabled "hook:fable-fallback" && exit 0

# Fable explicitly re-enabled → do nothing.
case "${FABLE_AVAILABLE:-off}" in
  on|ON|true|1|yes) exit 0 ;;
esac

PAYLOAD="${1:-}"
[[ -z "$PAYLOAD" ]] && exit 0

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
case "$TOOL" in Agent|Task) ;; *) exit 0 ;; esac

# The Agent tool carries the per-spawn model override in tool_input.model.
MODEL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.model // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
case "$MODEL" in
  *fable*) ;;          # a fable spawn — block it below
  *) exit 0 ;;         # any other model (or none) — allow
esac

MSG='[Fable-Fallback] Fable model access is revoked — policy is to always fall back to Opus.

Re-spawn this Agent with model: "opus" instead of "fable". Same prompt, same subagent_type — only the model changes.

(If a plan pins this cycle "[Fable — mandatory]", treat it as "[Opus · high]" while Fable is unavailable.)

To re-enable Fable when access returns: set FABLE_AVAILABLE=on (shell env, or the "env" block of .claude/settings.json).
To disable this guard: add hook:fable-fallback to ECC_DISABLED_HOOKS.'

printf '%s' "$(jq -nc --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}')"
exit 0
