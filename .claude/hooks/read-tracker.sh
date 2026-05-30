#!/usr/bin/env bash
# READ-TRACKER — PostToolUse(Read): record file_path as read this session.
#
# Feeds gate-guard.sh: once a file appears in the reads registry,
# Edit/Write on that file is allowed. Disable both with ECC_GATEGUARD=off
# or ECC_DISABLED_HOOKS=hook:gate-guard.
#
# Non-blocking, always exits 0. Failure to write the registry is silent
# (gate-guard falls back to allow on missing registry).

# shellcheck source=lib/hook.sh
source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/hook.sh"
is_hook_disabled "hook:gate-guard" && exit 0

PAYLOAD="${1:-}"
[[ -z "$PAYLOAD" ]] && exit 0

FILE=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE" ]] && exit 0

SESSION_KEY=$(hook_session_key "$PAYLOAD")
READS_FILE="/tmp/oneie-gate-reads-${SESSION_KEY}"

# Append absolute path — idempotent (duplicates are fine, grep is fast)
echo "$FILE" >> "$READS_FILE" 2>/dev/null || true
exit 0
