#!/bin/bash
# POST-EDIT-CHECK — PostToolUse(Write|Edit): two cheap reads, never a block.
#
#   1. .claude/workflows/*.js  → wf-check.mjs. A syntax error here does not fail
#      loudly — it stops the workflow launching at all — and `node --check`
#      exits 0 on any file that starts with `export`.
#   2. *.ts/*.tsx/*.js/*.jsx    → biome, ONLY when the repo carries a biome
#      config. Measured 2026-09-05: biome was not installed, so every edit
#      printed a false "biome: ? issues" line into the model's context and
#      emitted a warn signal for a tool that never ran. An absent tool is
#      silent; it is never a verdict.
#
# Emits hook:post-edit:{ok,warn} (Rule 1). Exit 0 always — inform, don't gate.

# shellcheck source=lib/signal.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/signal.sh"

FILE=$(echo "$1" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[[ -z "$FILE" ]] && exit 0
[[ "$FILE" =~ \.(ts|tsx|js|jsx)$ ]] || exit 0
BASE=$(basename "$FILE")

# 1 — workflow scripts
if [[ "$FILE" == *".claude/workflows/"*.js ]]; then
  if ! WF=$(cd "$CLAUDE_PROJECT_DIR" && node .claude/scripts/wf-check.mjs "$FILE" 2>&1); then
    echo "wf-check: $(echo "$WF" | grep FAIL || echo "$WF")" >&2
    echo "wf-check: this workflow will NOT launch until fixed" >&2
    emit_signal "hook:post-edit:warn" -1 "file=$BASE wf-check=fail"
    exit 0
  fi
  emit_signal "hook:post-edit:ok" 1 "file=$BASE wf-check=ok"
  exit 0
fi

# 2 — biome, only if the tree actually configures it
_biome_root() {
  local d; d=$(dirname "$FILE")
  while [[ "$d" != "/" && "$d" != "." ]]; do
    [[ -f "$d/biome.json" || -f "$d/biome.jsonc" ]] && { printf '%s' "$d"; return 0; }
    d=$(dirname "$d")
  done
  return 1
}
ROOT=$(_biome_root) || exit 0
BIOME="$ROOT/node_modules/.bin/biome"
[[ -x "$BIOME" ]] || exit 0

if RESULT=$("$BIOME" check "$FILE" 2>&1); then
  emit_signal "hook:post-edit:ok" 1 "file=$BASE"
else
  ISSUES=$(echo "$RESULT" | grep -c "━━━" 2>/dev/null || echo 0)
  echo "biome: ${ISSUES} issue(s) in $BASE" >&2
  emit_signal "hook:post-edit:warn" -0.5 "file=$BASE issues=$ISSUES"
fi
exit 0
