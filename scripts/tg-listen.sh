#!/usr/bin/env bash
# tg-listen — listen for Telegram messages and auto-reply via Claude Code
# Usage:
#   tg-listen.sh start [group]   # start background listener (default: donal)
#   tg-listen.sh stop  [group]
#   tg-listen.sh status
#   tg-listen.sh log   [group]

set -uo pipefail

REPO="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SCRIPTS="$REPO/.claude/scripts"
CHANNELS_URL="${CHANNELS_URL:-https://channels.one.ie}"
DIR="$REPO/.claude/.tg-listen"
mkdir -p "$DIR"

DEFAULT_GROUP="tg-1328669602-714125982"

# Map group id → notify.sh recipient name
recipient_for() {
  case "$1" in
    tg-1328669602-714125982) echo "donal" ;;
    *) echo "" ;;
  esac
}

all_groups() {
  echo "tg-1328669602-714125982"
}

pid_file() { echo "$DIR/$1.pid"; }
log_file() { echo "$DIR/$1.log"; }
ts_file()  { echo "$DIR/$1.last_ts"; }

is_running() {
  local pidf; pidf=$(pid_file "$1")
  [[ -f "$pidf" ]] && kill -0 "$(<"$pidf")" 2>/dev/null
}

start_listener() {
  local group="${1:-$DEFAULT_GROUP}"
  local foreground="${2:-}"
  local recipient; recipient=$(recipient_for "$group")

  if [[ -z "$recipient" ]]; then
    echo "unknown group: $group" >&2; exit 1
  fi

  if [[ -z "$foreground" ]] && is_running "$group"; then
    echo "already listening on $group (pid=$(cat "$(pid_file "$group")"))"
    return 0
  fi

  [[ -f "$(ts_file "$group")" ]] || echo "0" > "$(ts_file "$group")"

  run_loop() {
    while true; do
      last_ts=$(cat "$(ts_file "$group")" 2>/dev/null || echo 0)
      curl -N -sS --max-time 90 \
        --header "Last-Event-ID: $last_ts" \
        "$CHANNELS_URL/stream/$group?since=$last_ts" 2>/dev/null \
      | while IFS= read -r line; do
          [[ "$line" != "data: "* ]] && continue
          payload="${line#data: }"

          sender=$(echo "$payload" | jq -r '.sender // empty' 2>/dev/null)
          content=$(echo "$payload" | jq -r '.content // empty' 2>/dev/null)
          ts=$(echo "$payload" | jq -r '.ts // empty' 2>/dev/null)
          [[ -z "$sender" || -z "$content" ]] && continue
          [[ -n "$ts" ]] && echo "$ts" > "$(ts_file "$group")"

          # skip our own replies and system messages
          [[ "$sender" == "claude-code" || "$sender" == "onedotbot" || "$sender" == "assistant" || "$sender" == "workflow" ]] && continue

          echo "[$(date '+%H:%M:%S')] $sender: $content" >> "$(log_file "$group")"

          CONTEXT_FILE="$DIR/context.md"
          if [[ -f "$CONTEXT_FILE" ]]; then
            reply=$(echo "$content" | claude -p --system "$(cat "$CONTEXT_FILE")" 2>/dev/null)
          else
            reply=$(echo "$content" | claude -p --system "You are onedotbot, replying via Telegram on behalf of Tony O'Connell (one.ie). Donal is Tony's co-founder. Be concise and direct." 2>/dev/null)
          fi
          [[ -z "$reply" ]] && continue

          echo "[$(date '+%H:%M:%S')] reply: $reply" >> "$(log_file "$group")"
          "$SCRIPTS/notify.sh" --to "$recipient" "$reply"
        done
      sleep 1
    done
  }

  if [[ "$foreground" == "--foreground" ]]; then
    echo "listening on $group → $recipient (foreground)"
    run_loop >> "$(log_file "$group")" 2>&1
  else
    run_loop >> "$(log_file "$group")" 2>&1 &
    echo $! > "$(pid_file "$group")"
    echo "listening on $group → $recipient (pid=$!)"
  fi
}

stop_listener() {
  local group="${1:-$DEFAULT_GROUP}"
  local pidf; pidf=$(pid_file "$group")
  if [[ -f "$pidf" ]]; then
    kill "$(<"$pidf")" 2>/dev/null && echo "stopped $group" || echo "already stopped"
    rm -f "$pidf"
  else
    echo "not running"
  fi
}

status() {
  for group in $(all_groups); do
    recipient=$(recipient_for "$group")
    if is_running "$group"; then
      echo "✓ $group → $recipient (pid=$(cat "$(pid_file "$group")"))"
    else
      echo "✗ $group → $recipient (stopped)"
    fi
  done
}

cmd="${1:-status}"
group="${2:-}"
foreground="${3:-}"

case "$cmd" in
  start)  start_listener "${group:-$DEFAULT_GROUP}" "$foreground" ;;
  stop)   stop_listener  "${group:-$DEFAULT_GROUP}" ;;
  status) status ;;
  log)    tail -f "$(log_file "${group:-$DEFAULT_GROUP}")" ;;
  *)      echo "usage: tg-listen.sh <start|stop|status|log> [group] [--foreground]" >&2; exit 1 ;;
esac
