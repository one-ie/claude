#!/usr/bin/env bash
# SESSION-START — surface unaddressed proposals + module-specific context.
#
# Closes the loop with stop-reflect.sh: stop emits proposals into
# .claude/improvements.queue.md; this surfaces them at next session start so
# they don't rot. Article calls this the self-improving harness pattern.
#
# Also prints the relevant skill list for the most recently touched module,
# so dev context loads dynamically rather than every-session.
#
# Output is brief — every line costs context.

# shellcheck source=lib/signal.sh
source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/signal.sh"

cd "$CLAUDE_PROJECT_DIR" || exit 0

QUEUE="$CLAUDE_PROJECT_DIR/.claude/improvements.queue.md"
PROPOSAL_COUNT=0

# Count unaddressed proposals (every "-" bullet under a session header)
if [ -f "$QUEUE" ]; then
  PROPOSAL_COUNT=$(grep -c '^- \*\*' "$QUEUE" 2>/dev/null || echo 0)
fi

# Detect most-recently touched module — use mtime on a stable per-module marker.
# Falls back silently if nothing identifiable.
HOT_MODULE=""
HOT_HINT=""

# Parallel arrays — bash 3.2 compatible (macOS default).
MODULES=(
  "one.ie/web"
  "agents"
  "api"
  "packages/sdk"
  "packages/mcp"
  "packages/cli"
  "sync"
  "backup"
)
HINTS=(
  "/astro · /react19 · /shadcn · /dev · /build"
  "/cloudflare · /ai-sdk · /signal"
  "/cloudflare · /typedb · /signal"
  "/typecheck · /signal (substrate verbs)"
  "/typecheck · MCP server"
  "/typecheck · CLI bins"
  "/cloudflare (Scheduled Worker)"
  "/cloudflare (Scheduled Worker)"
)

NEWEST_TS=0
i=0
while [ $i -lt ${#MODULES[@]} ]; do
  module="${MODULES[$i]}"
  if [ -d "$module" ]; then
    TS=$(find "$module" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.astro' -o -name '*.md' \) \
      -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/.wrangler/*' \
      2>/dev/null | head -200 | xargs -I{} stat -f '%m' {} 2>/dev/null | sort -rn | head -1)
    if [ -n "$TS" ] && [ "$TS" -gt "$NEWEST_TS" ]; then
      NEWEST_TS=$TS
      HOT_MODULE=$module
      HOT_HINT="${HINTS[$i]}"
    fi
  fi
  i=$((i + 1))
done

# Render — keep it short. Only print if there's something to say.
OUT=""

if [ "$PROPOSAL_COUNT" -gt 0 ]; then
  OUT+="📋 ${PROPOSAL_COUNT} unaddressed proposal(s) in .claude/improvements.queue.md\n"
fi

if [ -n "$HOT_MODULE" ]; then
  OUT+="🔥 hot module: \`${HOT_MODULE}\` — relevant skills: ${HOT_HINT}\n"
fi

if [ -n "$OUT" ]; then
  echo ""
  printf "%b" "$OUT"
  echo ""
fi

emit_signal "hook:session-start:ok" 1 "proposals=$PROPOSAL_COUNT hot=$HOT_MODULE"
exit 0
