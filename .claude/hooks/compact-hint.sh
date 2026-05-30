#!/usr/bin/env bash
# COMPACT-HINT — PreToolUse: suggest /compact when context is large.
#
# Non-blocking — writes one line to stderr, fires at most once per session.
# Threshold: 400KB transcript (~80-120k tokens depending on content density).
#
# Disable: ECC_DISABLED_HOOKS=hook:compact-hint

# shellcheck source=lib/hook.sh
source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/hook.sh"
is_hook_disabled "hook:compact-hint" && exit 0

PAYLOAD="${1:-}"
[[ -z "$PAYLOAD" ]] && exit 0

# Locate the transcript — from hook JSON or env var (Claude Code sets both)
TRANSCRIPT=$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // .transcriptPath // empty' 2>/dev/null)
[[ -z "$TRANSCRIPT" ]] && TRANSCRIPT="${CLAUDE_TRANSCRIPT_PATH:-}"
[[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]] && exit 0

SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')
[[ -z "$SIZE" || "$SIZE" -lt 400000 ]] && exit 0

# Fire at most once per session
SESSION_KEY=$(hook_session_key "$PAYLOAD")
FLAG="/tmp/oneie-compact-hint-${SESSION_KEY}"
[[ -f "$FLAG" ]] && exit 0
touch "$FLAG"

SIZE_KB=$(( SIZE / 1024 ))
echo "" >&2
echo "⚡ Context is ~${SIZE_KB}KB — run /compact before the next big edit to keep responses fast and cheap." >&2
echo "" >&2

exit 0
