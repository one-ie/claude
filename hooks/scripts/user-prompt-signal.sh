#!/usr/bin/env bash
# UserPromptSubmit → broadcast the inbound INTENT as a rich world signal.
# The query entering the world IS the demand side of the marketplace: a session's
# intent, tagged by its keywords, fans to whatever agent staked on those tags.
# Silent + non-blocking: prints NOTHING to stdout (stdout here would inject context).

source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/signal.sh"

PAYLOAD="$(cat 2>/dev/null)"
[ -z "$PAYLOAD" ] && PAYLOAD="$1"
[ -z "$PAYLOAD" ] && exit 0

PROMPT="$(printf '%s' "$PAYLOAD" | jq -r '.prompt // .user_prompt // empty' 2>/dev/null)"
# Fall back to treating the raw arg as the prompt if it wasn't JSON.
[ -z "$PROMPT" ] && case "$PAYLOAD" in '{'*) : ;; *) PROMPT="$PAYLOAD" ;; esac
[ -z "$PROMPT" ] && exit 0

TEXT="$(printf '%s' "$PROMPT" | tr '\n' ' ' | head -c 200)"
# Keyword tags the world can route on. Two tiers, six max: (1) words in the staked
# vocabulary (FN_TAGS in one.ie/web/src/lib/in/spaces.ts — the bare words agents
# subscribe to), so an intent about marketing/deploy/memory reaches its owner; then
# (2) remaining content words. Stopwords never tag — the first-six-words rule this
# replaced staked on "read", "this", "just", and matched nobody.
VOCAB=" lead mql sql marketing sales opportunity service education engineering memory recall intelligence finance staff health care deploy release security billing checkout signal routing workflow task tasks agent agents inbox schema typedb "
STOP=" this that with from have what when where which your about there their would could should into then them they will just like more some very also been were being make made want need show tell does done only than over such each much many really please still using used doing back look read write lets dont cant "
WORDS="$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]' | grep -oE '[a-z]{4,}' | awk '!seen[$0]++')"
HIT="$(printf '%s\n' $WORDS | awk -v v="$VOCAB" 'index(v," "$0" ")')"
REST="$(printf '%s\n' $WORDS | awk -v v="$VOCAB" -v s="$STOP" '!index(v," "$0" ") && !index(s," "$0" ")')"
TAGS="$(printf '%s\n%s\n' "$HIT" "$REST" | awk 'NF && !seen[$0]++' | head -6 | paste -sd, - 2>/dev/null)"

emit_world "session:intent" "question" "$TAGS" "$TEXT" "chars=${#PROMPT}"
exit 0
