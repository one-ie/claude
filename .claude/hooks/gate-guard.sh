#!/usr/bin/env bash
# GATE-GUARD — PreToolUse(Edit|Write|MultiEdit): require Read before edit.
#
# Blocks the first attempt to Edit/Write an existing file that hasn't been
# Read in this session. Forces "understand before you change."
#
# Rules:
#   - New files (Write creating a file that doesn't exist yet) → always allowed
#   - Settings files (.claude/settings*.json) → always allowed
#   - Subagent calls → allowed (parent session's reads cover the session)
#   - File already in this session's read registry → allowed
#   - Existing file NOT yet read → BLOCK with instructions
#
# Disable for the session: ECC_GATEGUARD=off
# Disable one-off:         ECC_DISABLED_HOOKS=hook:gate-guard
# Skip globally in CI:     add hook:gate-guard to ECC_DISABLED_HOOKS in env

# shellcheck source=lib/hook.sh
source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/hook.sh"
is_hook_disabled "hook:gate-guard" && exit 0

PAYLOAD="${1:-}"
[[ -z "$PAYLOAD" ]] && exit 0

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
case "$TOOL" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

# Subagents: parent session already passed the gate for these files
SUBAGENT=$(printf '%s' "$PAYLOAD" | jq -r '.parent_tool_use_id // .parentToolUseId // empty' 2>/dev/null)
[[ -n "$SUBAGENT" ]] && exit 0

SESSION_KEY=$(hook_session_key "$PAYLOAD")
READS_FILE="/tmp/oneie-gate-reads-${SESSION_KEY}"

_deny() {
  # Claude Code PreToolUse block format
  printf '%s' "$(jq -nc --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}')"
  exit 0
}

_is_settings() {
  [[ "$1" =~ \.claude/settings[^/]*\.json$ ]]
}

_was_read() {
  local fp="$1"
  [[ -f "$READS_FILE" ]] && grep -qF "$fp" "$READS_FILE" 2>/dev/null
}

_block_msg() {
  local fp="$1" verb="$2"
  printf '[Gate-Guard] Read %s before you %s it.\n\nUse the Read tool on this file first to prove you understand it, then retry.\n\nTo disable for this session: set ECC_GATEGUARD=off\nTo disable permanently:   add hook:gate-guard to ECC_DISABLED_HOOKS in your environment.' \
    "$fp" "$verb"
}

check() {
  local fp="$1" tool="$2"
  [[ -z "$fp" ]] && return 0
  _is_settings "$fp" && return 0
  # New file being created — no prior read needed
  [[ "$tool" == "Write" && ! -f "$fp" ]] && return 0
  # Previously read this session — allowed
  _was_read "$fp" && return 0
  # Existing file not read → block
  [[ -f "$fp" ]] && { _deny "$(_block_msg "$fp" "$(printf '%s' "$tool" | tr '[:upper:]' '[:lower:]')")"; }
  return 0
}

case "$TOOL" in
  Edit|Write)
    FILE=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    check "$FILE" "$TOOL"
    ;;
  MultiEdit)
    while IFS= read -r fp; do
      [[ -z "$fp" ]] && continue
      check "$fp" "Edit"
    done < <(printf '%s' "$PAYLOAD" | jq -r '.tool_input.edits[].file_path // empty' 2>/dev/null)
    ;;
esac

exit 0
