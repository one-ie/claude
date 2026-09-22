#!/usr/bin/env bash
# AUTO-CONTINUE — Stop hook: keep the session moving without the operator
# typing "continue" / "do it" / "yes" / "merge and deploy" over and over.
#
# OPT-IN. Armed only while the flag file exists:
#   .claude/auto-continue.local        (toggle with /go on · /go off)
#
# Flag file format (all lines optional):
#   max=12                — continuation budget per session (default 12)
#   mission=<free text>   — shown in every continuation directive
#
# When armed and the budget isn't spent, this hook BLOCKS the stop and hands
# Claude the standing instruction: finish in-flight work → merge and deploy
# when green → pick the next slug from todo.md → fan out when file-disjoint.
# Claude escapes the loop by finishing everything or removing the flag file
# (which it is told to do when genuinely blocked on a human-only decision).
#
# Safety:
#   - per-session counter in /tmp caps continuations (no infinite loop)
#   - absent flag file = hook is a no-op (default state)
#   - ECC_DISABLED_HOOKS=hook:auto-continue disables it entirely
#
# Per Rule 1 (closed loop) — emits hook:auto-continue:{block,done}.

# shellcheck source=lib/hook.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh"
# shellcheck source=lib/signal.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/signal.sh"
is_hook_disabled "hook:auto-continue" && exit 0

FLAG="$CLAUDE_PROJECT_DIR/.claude/auto-continue.local"
[[ -f "$FLAG" ]] || exit 0

PAYLOAD="${1:-}"

MAX=$(grep -E '^max=' "$FLAG" 2>/dev/null | head -1 | cut -d= -f2 | tr -dc '0-9')
[[ -z "$MAX" ]] && MAX=12
MISSION=$(grep -E '^mission=' "$FLAG" 2>/dev/null | head -1 | cut -d= -f2-)

SESSION_KEY=$(hook_session_key "$PAYLOAD")
COUNT_FILE="/tmp/oneie-auto-continue-${SESSION_KEY}.count"
COUNT=$(cat "$COUNT_FILE" 2>/dev/null | tr -dc '0-9')
[[ -z "$COUNT" ]] && COUNT=0
COUNT=$((COUNT + 1))

if (( COUNT > MAX )); then
  # Budget spent — let the stop through, but say so out loud.
  echo "[auto-continue] budget spent (${MAX} continuations this session) — letting the stop through. /go on resets next session; rm $COUNT_FILE resets now."
  emit_signal "hook:auto-continue:done" 1 "count=$COUNT max=$MAX"
  exit 0
fi
printf '%s' "$COUNT" > "$COUNT_FILE"

REASON="AUTO-CONTINUE is ON (/go). Standing instruction from the operator: fill the gaps · do it · continue · merge and deploy · fan out.

Do not stop yet — take the next action, in this order:
1. Work in flight → finish it. A failed command is not a stopping point: diagnose, fix, retry.
2. Work done and green (tsc + tests + kill-switch) → close the loop: commit by explicit path (check the current branch first), merge, deploy, verify live.
3. Idle → read todo.md, take the top unblocked slug, run /do <slug>. Independent file-disjoint work → fan out parallel agents in one message.
4. ONLY stop if genuinely blocked on a human-only decision (destructive action, spend, scope change) or everything is shipped and verified. In that case run: rm .claude/auto-continue.local — then report state honestly and stop.

Never fabricate green: if something fails, say so and keep working on it.${MISSION:+

Mission: $MISSION}

[continuation $COUNT of $MAX this session]"

emit_signal "hook:auto-continue:block" 1 "count=$COUNT max=$MAX"
jq -nc --arg r "$REASON" '{"decision":"block","reason":$r}'
exit 0
