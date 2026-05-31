#!/usr/bin/env bash
# cc-connect — Claude Code ↔ Claude Code messaging over the substrate.
# SSE push (no client poll). Background listener writes to .cc-connect/<group>.jsonl.
#
# Multi-group: one local config holds your sender name + the groups you're
# subscribed to. `listen` starts one SSE listener per group. `send`/`read`
# default to your "default" group; pass --to / <group> to address another.
#
# Subcommands:
#   init <sender> [group]              first-time setup
#   join <group>                       subscribe + start its listener
#   leave <group>                      stop listener + unsubscribe
#   listen                             start a listener for every subscribed group
#   stop [group]                       kill one listener (or all if no arg)
#   status                             show config + listener state per group
#   listeners                          list all running listener PIDs
#   groups                             ask channels what groups exist (discovery)
#   send [--to <group>] <text>         send to default (or specific) group
#   read [<group>]                     show new messages since last read (one group)
#   read --all                         merge new across every subscribed group
#   (no args)                          = read default group
#
# Requires: bash, curl, jq.

set -e

CHANNELS_URL="${CHANNELS_URL:-https://channels.oneie.workers.dev}"
if ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$ROOT" ] && [ -d "$ROOT/.cc-connect" ]; then
  DIR="$ROOT/.cc-connect"
else
  DIR="$HOME/.cc-connect"
fi
CFG="$DIR/config.json"

mkdir -p "$DIR"

# ─── config helpers ─────────────────────────────────────────────────────────

cfg_read() {
  [ -f "$CFG" ] && /bin/cat "$CFG" || /bin/echo '{}'
}

# Read sender; default $USER
cfg_sender() {
  cfg_read | jq -r '.sender // empty' 2>/dev/null | { read v; /bin/echo "${v:-$USER}"; }
}

# Read subscribed groups as a newline-separated list.
# Back-compat: old config used `group: "x"`; new uses `groups: ["x", ...]`.
cfg_groups() {
  cfg_read | jq -r '
    if .groups and (.groups | length > 0) then .groups[]
    elif .group then .group
    else "newco" end
  ' 2>/dev/null
}

# Read default group (first in list if not set explicitly)
cfg_default() {
  cfg_read | jq -r '.default // .group // (.groups[0] // "newco")' 2>/dev/null
}

cfg_save() {
  local sender="$1" default="$2"
  shift 2
  /bin/echo "$@" \
    | jq -R 'split(" ") | map(select(length > 0))' \
    | jq --arg s "$sender" --arg d "$default" \
        '{sender: $s, default: $d, groups: .}' \
    > "$CFG"
}

# ─── listener primitives (one per group) ───────────────────────────────────

listener_pid_file() { /bin/echo "$DIR/$1.pid"; }
listener_jsonl()    { /bin/echo "$DIR/$1.jsonl"; }
listener_offset()   { /bin/echo "$DIR/$1.offset"; }

listener_running() {
  local pidf
  pidf=$(listener_pid_file "$1")
  [ -f "$pidf" ] && kill -0 "$(/bin/cat "$pidf" 2>/dev/null)" 2>/dev/null
}

listener_start() {
  local group="$1"
  local pidf jsonl last_ts_file
  pidf=$(listener_pid_file "$group")
  jsonl=$(listener_jsonl "$group")
  last_ts_file="$DIR/$group.last_ts"
  if listener_running "$group"; then
    /bin/echo "  - $group already listening (pid=$(/bin/cat "$pidf"))"
    return 0
  fi
  /usr/bin/touch "$jsonl"
  [ -f "$(listener_offset "$group")" ] || /bin/echo 0 > "$(listener_offset "$group")"
  # Seed last_ts file from the tail of the existing jsonl (or 0 for fresh).
  # The outer loop re-reads this file each iteration so curl reconnects
  # honour the latest ts — without this, the inner `| while` subshell drops
  # the variable update and every reconnect replays the full backlog.
  if [ ! -f "$last_ts_file" ]; then
    /usr/bin/tail -n 1 "$jsonl" 2>/dev/null | jq -r '.ts // 0' 2>/dev/null > "$last_ts_file" \
      || /bin/echo 0 > "$last_ts_file"
  fi
  (
    while true; do
      last_ts=$(/bin/cat "$last_ts_file" 2>/dev/null || /bin/echo 0)
      [ -z "$last_ts" ] && last_ts=0
      curl -N -sS --max-time 90 \
        --header "Last-Event-ID: $last_ts" \
        "$CHANNELS_URL/stream/$group?since=$last_ts" 2>/dev/null \
      | while IFS= read -r line; do
          case "$line" in
            "data: "*)
              payload="${line#data: }"
              /bin/echo "$payload" >> "$jsonl"
              new_ts=$(/bin/echo "$payload" | jq -r '.ts // empty' 2>/dev/null)
              [ -n "$new_ts" ] && /bin/echo "$new_ts" > "$last_ts_file"
              sender=$(/bin/echo "$payload" | jq -r '.sender // empty' 2>/dev/null | tr -cd 'A-Za-z0-9 _.:@-')
              snippet=$(/bin/echo "$payload" | jq -r '.content // empty' 2>/dev/null | /usr/bin/cut -c1-80 | tr -cd 'A-Za-z0-9 _.:@-,!?')
              [ -n "$sender" ] && osascript -e "display notification \"$snippet\" with title \"cc-connect · $group\" subtitle \"$sender\"" 2>/dev/null || true
              ;;
          esac
        done
      sleep 1
    done
  ) > /dev/null 2>&1 &
  /bin/echo $! > "$pidf"
  /bin/echo "  + $group listening (pid=$(/bin/cat "$pidf"))"
}

listener_stop() {
  local group="$1"
  local pidf
  pidf=$(listener_pid_file "$group")
  if [ -f "$pidf" ]; then
    local pid
    pid=$(/bin/cat "$pidf")
    if [ -n "$pid" ]; then
      pkill -P "$pid" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
    fi
    /bin/rm -f "$pidf"
    /bin/echo "  - $group stopped (pid=$pid)"
  else
    /bin/echo "  - $group not running"
  fi
}

# ─── pretty print messages ─────────────────────────────────────────────────

print_messages() {
  local me="$1"
  jq -r --arg me "$me" '
    def t: (.ts / 1000 | strftime("%H:%M:%S"));
    if (.group | length > 0) then
      "[\(t)] \(.group) · \(.sender) → \(if .sender == $me then "(you)" else $me end): \(.content)"
    else
      "[\(t)] \(.sender) → \(if .sender == $me then "(you)" else $me end): \(.content)"
    end
  '
}

# ─── dispatch ──────────────────────────────────────────────────────────────

SENDER="$(cfg_sender)"
DEFAULT="$(cfg_default)"

cmd="${1:-read}"
shift 2>/dev/null || true

case "$cmd" in
  init)
    s="${1:-$USER}"
    g="${2:-newco}"
    cfg_save "$s" "$g" "$g"
    /bin/echo "ok  sender=$s  default=$g  groups=[$g]  config=$CFG"
    ;;

  join)
    g="${1:?usage: cc-connect join <group>}"
    cur=$(cfg_groups | /usr/bin/tr '\n' ' ')
    if /bin/echo " $cur " | /usr/bin/grep -q " $g "; then
      /bin/echo "ok  already subscribed to $g"
    else
      cfg_save "$SENDER" "$DEFAULT" "$cur $g"
      /bin/echo "ok  joined $g  (groups now: $(cfg_groups | /usr/bin/tr '\n' ' '))"
    fi
    listener_start "$g"
    ;;

  leave)
    g="${1:?usage: cc-connect leave <group>}"
    new=$(cfg_groups | /usr/bin/grep -v "^$g$" | /usr/bin/tr '\n' ' ')
    new_default="$DEFAULT"
    [ "$DEFAULT" = "$g" ] && new_default=$(/bin/echo "$new" | /usr/bin/awk '{print $1}')
    [ -z "$new_default" ] && new_default="$g"
    cfg_save "$SENDER" "$new_default" "$new"
    listener_stop "$g"
    /bin/echo "ok  left $g  (default=$new_default)"
    ;;

  listen)
    while IFS= read -r g; do
      [ -n "$g" ] && listener_start "$g"
    done < <(cfg_groups)
    ;;

  stop)
    g="${1:-}"
    if [ -n "$g" ]; then
      listener_stop "$g"
    else
      while IFS= read -r grp; do
        [ -n "$grp" ] && listener_stop "$grp"
      done < <(cfg_groups)
    fi
    ;;

  status)
    /bin/echo "sender=$SENDER  default=$DEFAULT"
    /bin/echo "subscribed groups:"
    while IFS= read -r g; do
      [ -z "$g" ] && continue
      jsonl=$(listener_jsonl "$g")
      total=0
      [ -f "$jsonl" ] && total=$(/usr/bin/wc -l < "$jsonl" | /usr/bin/tr -d ' ')
      off=0
      [ -f "$(listener_offset "$g")" ] && off=$(/bin/cat "$(listener_offset "$g")" 2>/dev/null | /usr/bin/tr -d ' ')
      [ -z "$off" ] && off=0
      unread=$((total - off))
      if listener_running "$g"; then
        live="pid=$(/bin/cat "$(listener_pid_file "$g")")"
      else
        live="not running"
      fi
      /bin/echo "  $g  total=$total  unread=$unread  listener=$live"
    done < <(cfg_groups)
    ;;

  listeners)
    while IFS= read -r g; do
      [ -z "$g" ] && continue
      if listener_running "$g"; then
        /bin/echo "  $g  pid=$(/bin/cat "$(listener_pid_file "$g")")"
      fi
    done < <(cfg_groups)
    ;;

  groups)
    /bin/echo "channels says:"
    curl -s "$CHANNELS_URL/groups" -m 5 \
      | jq -r '.groups[] | "  \(.id)  msgs=\(.message_count)  last=\(.last_sender // "—"): \((.last_content // "")[0:60])"' \
      || /bin/echo "  (could not reach channels)"
    /bin/echo "you are subscribed to:"
    cfg_groups | /usr/bin/sed 's/^/  /'
    ;;

  send)
    # send [--to <group>] <text...>  (--group is an alias for --to; flag can appear anywhere)
    target="$DEFAULT"
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --to|--group)
          target="${2:?usage: cc-connect send --to <group> <text>}"
          shift 2
          ;;
        *)
          args+=("$1")
          shift
          ;;
      esac
    done
    text="${args[*]}"
    [ -z "$text" ] && { /bin/echo "error  usage: cc-connect send [--to <group>] <text>"; exit 1; }
    body=$(jq -n --arg s "$SENDER" --arg c "$text" '{sender: $s, content: $c}')
    resp=$(curl -s -X POST "$CHANNELS_URL/signal/$target" \
      -H 'Content-Type: application/json' \
      -d "$body")
    /bin/echo "ok  →$target  $resp"
    ;;

  read)
    target="$DEFAULT"
    all=false
    if [ "$1" = "--all" ]; then
      all=true
    elif [ -n "$1" ]; then
      target="$1"
    fi
    # auto-start listeners if not running
    if $all; then
      while IFS= read -r g; do
        [ -n "$g" ] && ! listener_running "$g" && listener_start "$g" >/dev/null 2>&1
      done < <(cfg_groups)
    else
      ! listener_running "$target" && listener_start "$target" >/dev/null 2>&1
    fi
    if $all; then
      # Merge new across all subscribed groups, sort by ts
      tmp=$(/usr/bin/mktemp)
      while IFS= read -r g; do
        [ -z "$g" ] && continue
        jsonl=$(listener_jsonl "$g")
        [ -f "$jsonl" ] || continue
        total=$(/usr/bin/wc -l < "$jsonl" | /usr/bin/tr -d ' ')
        off=$(/bin/cat "$(listener_offset "$g")" 2>/dev/null | /usr/bin/tr -d ' ')
        [ -z "$off" ] && off=0
        if [ "$total" -gt "$off" ]; then
          new=$((total - off))
          /usr/bin/tail -n "$new" "$jsonl" | jq -c --arg g "$g" '. + {group: $g}' >> "$tmp"
          /bin/echo "$total" > "$(listener_offset "$g")"
        fi
      done < <(cfg_groups)
      if [ -s "$tmp" ]; then
        /usr/bin/sort -t '"' -k '6' "$tmp" 2>/dev/null | print_messages "$SENDER"
      else
        /bin/echo "ok  no new messages across $(cfg_groups | /usr/bin/wc -l | /usr/bin/tr -d ' ') groups (you=$SENDER)"
      fi
      /bin/rm -f "$tmp"
    else
      jsonl=$(listener_jsonl "$target")
      offset=$(listener_offset "$target")
      /usr/bin/touch "$jsonl"
      [ -f "$offset" ] || /bin/echo 0 > "$offset"
      total=$(/usr/bin/wc -l < "$jsonl" | /usr/bin/tr -d ' ')
      off=$(/bin/cat "$offset" 2>/dev/null | /usr/bin/tr -d ' ')
      [ -z "$off" ] && off=0
      [ -z "$total" ] && total=0
      if [ "$total" -le "$off" ]; then
        /bin/echo "ok  no new messages in $target  (you=$SENDER  total=$total)"
        exit 0
      fi
      new=$((total - off))
      /usr/bin/tail -n "$new" "$jsonl" | jq -c --arg g "$target" '. + {group: $g}' | print_messages "$SENDER"
      /bin/echo "$total" > "$offset"
    fi
    ;;

  *)
    /bin/echo "usage: cc-connect {init|join|leave|listen|stop|status|listeners|groups|send|read}"
    exit 1
    ;;
esac
