#!/usr/bin/env bash
# hourly-brief — compile a context digest of our systems / agents / workflows /
# tracking / analytics and signal it to Donal every hour.
#
# Per the ONE convention (one-ie/CLAUDE.md § "Chat / send a message = a signal to
# the CEO who routes"): sending Donal a brief is signal(receiver, data) — receiver
# defaults to the `donal` channel; he reads/routes it.
#
# Scheduled by launchd ie.one.hourly-brief (StartInterval=3600). Run by hand:
#   bash .claude/scripts/hourly-brief.sh            # compile + send
#   BRIEF_DRY=1 bash .claude/scripts/hourly-brief.sh # compile + print, no send
#   BRIEF_TO=space:vespio bash .claude/scripts/hourly-brief.sh
set -uo pipefail

REPO="/Users/toc/Server/one-ie"
VESPIO="/Users/toc/Server/apps/vespio"
CC="$REPO/.claude/scripts/cc-connect.sh"
RECIPIENT="${BRIEF_TO:-donal}"
NOW="$(date '+%Y-%m-%d %H:%M %Z')"

# 1) SYSTEMS — realtime listener health (the always-on signal spine)
alive=$(launchctl list 2>/dev/null | awk '/ie\.one\.(cc-|tg-listen)/{printf "%s ",$3}')
[ -z "$alive" ] && alive="none ⚠️"

# 2) AGENTS & WORKFLOWS — per vespio client node
clients_block=""
for d in "$VESPIO"/clients/*/; do
  c=$(basename "$d")
  case "$c" in _example) continue;; esac
  a=$(find "$d/ai/agents" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  w=$(find "$d/ai/workflows" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "${a:-0}" = "0" ] && [ "${w:-0}" = "0" ] && continue
  flags=""
  [ -f "$d/data/analytics/kpis.toml" ] && flags="${flags} +kpis"
  [ -d "$d/data/campaigns" ] && flags="${flags} +campaign"
  clients_block="${clients_block}  ${c}: ${a} agents · ${w} workflows${flags}
"
done
[ -z "$clients_block" ] && clients_block="  (no client nodes)
"

# 3) TRACKING — unread per channel (cc-connect status)
tracking=$(bash "$CC" status 2>/dev/null | awk '/total=/{gsub(/^  /,"");printf "  %s\n",$0}')
[ -z "$tracking" ] && tracking="  (cc-connect not configured)
"

# 4) ANALYTICS — which clients have KPI/funnel wired
analytics=""
for d in "$VESPIO"/clients/*/; do
  c=$(basename "$d")
  [ -f "$d/data/analytics/kpis.toml" ] && analytics="${analytics}${c} "
done
[ -z "$analytics" ] && analytics="none yet"

# 5) SUBSCRIPTIONS — which agents have subscribes: tags declared
subs_block=""
for d in "$VESPIO"/clients/*/; do
  c=$(basename "$d")
  case "$c" in _example) continue;; esac
  sub_agents=$(grep -rl "^subscribes:" "$d/ai/agents/" 2>/dev/null | wc -l | tr -d ' ')
  [ "${sub_agents:-0}" = "0" ] && continue
  subs_block="${subs_block}  ${c}: ${sub_agents} agents subscribed
"
done
[ -z "$subs_block" ] && subs_block="  (no subscribe: tags declared)
"

MSG="🧠 ONE/Vespio hourly brief · $NOW

SYSTEMS — realtime listeners
  alive: ${alive}

AGENTS & WORKFLOWS (vespio client nodes)
${clients_block}
SUBSCRIPTIONS — world:announce routing
${subs_block}
TRACKING — channels (unread per group)
${tracking}
ANALYTICS — KPI/funnel wired: ${analytics}

— auto-brief, hourly. Reply on this channel to steer."

if [ -n "${BRIEF_DRY:-}" ]; then
  printf '%s\n' "$MSG"
  exit 0
fi

if bash "$CC" send --to "$RECIPIENT" "$MSG" >/dev/null 2>&1; then
  echo "[$NOW] brief sent → $RECIPIENT"
else
  echo "[$NOW] brief send FAILED → $RECIPIENT"
  exit 1
fi
