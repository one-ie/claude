#!/usr/bin/env bash
# CONFIG-PROTECT — PreToolUse(Edit|Write): block lint/type config weakening.
#
# Prevents introducing "off"/"warn" rules or disabling strict flags in
# biome.json, tsconfig*.json, or .eslintrc* files.
#
# Why: W4 verify uses biome + tsc as hard gates. Weakening the config
# is equivalent to deleting the gate. Fix the code — not the rules.
# If a rule genuinely needs changing, explain it in the PR description.
#
# Disable: ECC_DISABLED_HOOKS=hook:config-protect

# shellcheck source=lib/hook.sh
source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/hook.sh"
is_hook_disabled "hook:config-protect" && exit 0

PAYLOAD="${1:-}"
[[ -z "$PAYLOAD" ]] && exit 0

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
case "$TOOL" in Edit|Write) ;; *) exit 0 ;; esac

FILE=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE" ]] && exit 0

# Only gate known config files
case "$(basename "$FILE")" in
  biome.json|biome.*.json|\
  tsconfig.json|tsconfig.*.json|\
  .eslintrc|.eslintrc.json|.eslintrc.js|.eslintrc.cjs|.eslintrc.mjs) ;;
  *) exit 0 ;;
esac

# For Edit: compare old_string vs new_string — block only if weakening is NEW.
# For Write: check the whole content.
if [[ "$TOOL" == "Edit" ]]; then
  OLD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
  NEW=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
  [[ -z "$NEW" ]] && exit 0
  # Only block if the weakening pattern appears in NEW but not in OLD
  _has_weakening() { printf '%s' "$1" | grep -qE '"(off|warn)"|"noErrors":\s*true|"strict":\s*false|"skipLibCheck":\s*true|"noUnusedLocals":\s*false|"noImplicitAny":\s*false|"allowJs":\s*true'; }
  _has_weakening "$OLD" && exit 0   # already present — not introducing it
  _has_weakening "$NEW" || exit 0   # not in new content — safe
else
  # Write: check full content
  CONTENT=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.content // empty' 2>/dev/null)
  [[ -z "$CONTENT" ]] && exit 0
  printf '%s' "$CONTENT" | grep -qE '"(off|warn)"|"noErrors":\s*true|"strict":\s*false|"skipLibCheck":\s*true|"noUnusedLocals":\s*false|"noImplicitAny":\s*false|"allowJs":\s*true' || exit 0
fi

FNAME=$(basename "$FILE")
printf '%s' "$(jq -nc --arg f "$FNAME" --arg path "$FILE" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":
    ("[Config-Guard] Weakening \($f) is not allowed.\n\nW4 verify uses biome + tsc as hard gates — disabling rules deletes the gate.\nFix the code, not the config.\n\nIf this change is genuinely intentional, explain it in the PR description, then\ndisable for this session:  ECC_DISABLED_HOOKS=hook:config-protect")}}')"
exit 0
