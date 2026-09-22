#!/usr/bin/env bash
# cc-connect — Claude Code ↔ Claude Code messaging over the substrate.
# SSE push (no client poll). Background listener writes to .cc-connect/<group>.jsonl.
#
# Multi-group: one local config holds your sender name + the groups you're
# subscribed to. `listen` starts one SSE listener per group. `send`/`read`
# default to your "default" group; pass --to / <group> to address another.
#
# Subcommands:
#   auth <key>                         save ONE_API_KEY to ~/.cc-connect/.auth.conf
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

CHANNELS_URL="${CHANNELS_URL:-https://channels.one.ie}"
ONE_API_URL="${ONE_API_URL:-https://one.ie}"
ONE_API_KEY="${ONE_API_KEY:-}"
if ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$ROOT" ] && [ -d "$ROOT/.cc-connect" ]; then
  DIR="$ROOT/.cc-connect"
else
  DIR="$HOME/.cc-connect"
fi
CFG="$DIR/config.json"

mkdir -p "$DIR"

# notify.sh lives beside this script — used for the optional Telegram push from the
# always-on daemon listener (listen-fg, gated by CC_TG_NOTIFY).
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTIFY_SH="$SELF_DIR/notify.sh"

# Auth: prefer --config <file> (token stays off ps aux) over bare --header CLI arg.
# If .auth.conf exists use it directly; else fall back to ONE_API_KEY from env.
if [ -f "$DIR/.auth.conf" ]; then
  CURL_AUTH="--config $DIR/.auth.conf"
  # Also populate ONE_API_KEY so the space:post JSON path still works
  if [ -z "$ONE_API_KEY" ]; then
    ONE_API_KEY=$(grep '^header = "Authorization: Bearer ' "$DIR/.auth.conf" 2>/dev/null \
      | sed 's/header = "Authorization: Bearer \(.*\)"/\1/' | head -1)
  fi
elif [ -n "$ONE_API_KEY" ]; then
  # Token off argv (ps aux would leak a bare --header value) — write a private,
  # session-scoped curl config instead. Not persisted to .auth.conf: that file is
  # only ever written by the explicit `auth` subcommand.
  AUTH_TMP="$(mktemp "${TMPDIR:-/tmp}/cc-connect-auth.XXXXXX")"
  chmod 600 "$AUTH_TMP"
  printf 'header = "Authorization: Bearer %s"\n' "$ONE_API_KEY" > "$AUTH_TMP"
  trap 'rm -f "$AUTH_TMP"' EXIT
  CURL_AUTH="--config $AUTH_TMP"
else
  CURL_AUTH=""
fi

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

# Shared dedup store — last 2000 signal IDs across all groups (gap 4).
_SEEN="$DIR/.seen"
_seen_check() {
  local id="$1"
  [ -z "$id" ] && return 1  # no id → can't dedup, allow through
  [ -f "$_SEEN" ] && /usr/bin/grep -qF "$id" "$_SEEN" && return 0  # already seen
  /bin/echo "$id" >> "$_SEEN"
  # Keep the file bounded — trim to last 2000 lines in-place
  if [ "$(/usr/bin/wc -l < "$_SEEN" 2>/dev/null | /usr/bin/tr -d ' ')" -gt 2000 ]; then
    /usr/bin/tail -n 2000 "$_SEEN" > "$_SEEN.tmp" && /bin/mv "$_SEEN.tmp" "$_SEEN"
  fi
  return 1  # not seen before
}

listener_running() {
  local pidf
  pidf=$(listener_pid_file "$1")
  [ -f "$pidf" ] && kill -0 "$(/bin/cat "$pidf" 2>/dev/null)" 2>/dev/null
}

# The SSE read loop for one group. Blocking — callers either background it
# (listener_start) or run it in the foreground under launchd (listen-fg).
# Writes each signal to the group jsonl, fires a macOS notification, and — when
# CC_TG_NOTIFY is set (the always-on daemon) — pushes a Telegram alert via
# notify.sh, skipping our own and bot/system senders so Tony isn't pinged by his
# own posts or automated replies.
_listener_loop() {
  local group="$1" jsonl="$2" last_ts_file="$3"
  while true; do
    last_ts=$(/bin/cat "$last_ts_file" 2>/dev/null || /bin/echo 0)
    [ -z "$last_ts" ] && last_ts=0
    curl -N -sS --max-time 90 \
      --header "Last-Event-ID: $last_ts" \
      ${CURL_AUTH:+$CURL_AUTH} \
      "$CHANNELS_URL/stream/$group?since=$last_ts" 2>/dev/null \
    | while IFS= read -r line; do
        case "$line" in
          "data: "*)
            payload="${line#data: }"
            # Gap 4: dedup by signalId — skip if we've seen this signal before
            sig_id=$(/bin/echo "$payload" | jq -r '.id // .signalId // empty' 2>/dev/null)
            if _seen_check "$sig_id"; then continue; fi
            /bin/echo "$payload" >> "$jsonl"
            # Gap 6: heartbeat — record last activity time for watchdog
            /bin/date +%s > "$DIR/$group.heartbeat" 2>/dev/null || true
            new_ts=$(/bin/echo "$payload" | jq -r '.ts // empty' 2>/dev/null)
            [ -n "$new_ts" ] && /bin/echo "$new_ts" > "$last_ts_file"
            sender=$(/bin/echo "$payload" | jq -r '.sender // empty' 2>/dev/null | tr -cd 'A-Za-z0-9 _.:@-')
            # Strip ALL shell-/AppleScript-special chars; no quotes, backslashes, dollars, or backticks.
            snippet=$(/bin/echo "$payload" | jq -r '.content // empty' 2>/dev/null | /usr/bin/cut -c1-220 | tr -cd 'A-Za-z0-9 _.:@/=,.!? ')
            # Smart priority from the content — louder for things that need Tony now.
            prio="🔵"
            case " $(/bin/echo "$snippet" | tr 'A-Z' 'a-z') " in
              *urgent*|*asap*|*emergency*|*blocker*|*" p1"*|*" down"*|*"right now"*|*"need you"*|*approve*|*broken*) prio="🔴" ;;
              *"?"*) prio="🟡" ;;
            esac
            # Reply surface per channel: vespio/oo land in the workspace inbox; all are cc-connect-replyable.
            case "$group" in
              space:*) inbox="one.ie/u/${group#space:}/in" ;;
              *) inbox="" ;;
            esac
            # Pass notification content via env vars — never via osascript -e string interpolation.
            # terminal-notifier (brew install terminal-notifier) opens the inbox on click.
            # Falls back to display notification (opens Script Editor — less useful).
            if [ -n "$sender" ]; then
              _inbox_url="${inbox:+https://$inbox}"
              if command -v terminal-notifier &>/dev/null; then
                terminal-notifier \
                  -title "$prio $group · $sender" \
                  -message "$snippet" \
                  ${_inbox_url:+-open "$_inbox_url"} \
                  -sound default 2>/dev/null || true
              else
                CC_SNIPPET="$snippet" CC_TITLE="$prio $group · $sender" CC_SUBTITLE="${_inbox_url:-reply: cc-connect send --to $group}" \
                osascript <<'APPLESCRIPT' 2>/dev/null || true
on run
  set t to system attribute "CC_TITLE"
  set s to system attribute "CC_SNIPPET"
  set u to system attribute "CC_SUBTITLE"
  display notification s with title t subtitle u
end run
APPLESCRIPT
              fi
            fi
            # Telegram push (always-on daemon only). Skip our own + bot/system senders. Smart + actionable.
            if [ -n "${CC_TG_NOTIFY:-}" ] && [ -n "$sender" ]; then
              case "$sender" in
                tony|Tony|claude-code|onedotbot|assistant|workflow|system) : ;;
                *) "$NOTIFY_SH" --to tony "$prio $group · $sender
$snippet
↳ reply: cc-connect send --to $group \"…\"${inbox:+  ·  $inbox}" >/dev/null 2>&1 || true ;;
              esac
            fi
            ;;
        esac
      done
    sleep 1
  done
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
    _listener_loop "$group" "$jsonl" "$last_ts_file"
  ) > /dev/null 2>&1 &
  listener_pid=$!
  /bin/echo $listener_pid > "$pidf"
  # Gap 6: watchdog — restarts the listener if no SSE data received for 120s
  (
    while kill -0 $listener_pid 2>/dev/null; do
      sleep 30
      hb_file="$DIR/$group.heartbeat"
      if [ -f "$hb_file" ]; then
        last=$(/bin/cat "$hb_file" 2>/dev/null)
        now=$(/bin/date +%s)
        age=$(( now - last ))
        if [ "$age" -gt 120 ]; then
          # Stale — kill so the outer while-true in _listener_loop reconnects
          pkill -P $listener_pid 2>/dev/null || true
          /bin/date +%s > "$hb_file"
        fi
      fi
    done
  ) > /dev/null 2>&1 &
  /bin/echo "  + $group listening (pid=$listener_pid)"
}

# Foreground listener for launchd supervision (always-on daemon). Takes ownership
# of the group (kills any stale/session listener), writes its own pidfile so
# interactive sessions see it as live and don't double-listen, then blocks.
listen_fg() {
  local group="$1"
  local pidf jsonl last_ts_file oldpid
  pidf=$(listener_pid_file "$group")
  jsonl=$(listener_jsonl "$group")
  last_ts_file="$DIR/$group.last_ts"
  oldpid=$(/bin/cat "$pidf" 2>/dev/null || true)
  if [ -n "$oldpid" ] && [ "$oldpid" != "$$" ] && kill -0 "$oldpid" 2>/dev/null; then
    pkill -P "$oldpid" 2>/dev/null || true
    kill "$oldpid" 2>/dev/null || true
  fi
  /usr/bin/touch "$jsonl"
  [ -f "$(listener_offset "$group")" ] || /bin/echo 0 > "$(listener_offset "$group")"
  if [ ! -f "$last_ts_file" ]; then
    /usr/bin/tail -n 1 "$jsonl" 2>/dev/null | jq -r '.ts // 0' 2>/dev/null > "$last_ts_file" \
      || /bin/echo 0 > "$last_ts_file"
  fi
  /bin/echo $$ > "$pidf"
  trap '/bin/rm -f "'"$pidf"'"' EXIT
  /bin/echo "listen-fg $group (pid=$$, tg_notify=${CC_TG_NOTIFY:-0})"
  _listener_loop "$group" "$jsonl" "$last_ts_file"
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

  listen-fg)
    g="${1:?usage: cc-connect listen-fg <group>}"
    listen_fg "$g"
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
      ${CURL_AUTH:+$CURL_AUTH} \
      | jq -r '.groups[] | "  \(.id)  msgs=\(.message_count)  last=\(.last_sender // "—"): \((.last_content // "")[0:60])"' \
      || /bin/echo "  (could not reach channels)"
    /bin/echo "you are subscribed to:"
    cfg_groups | /usr/bin/sed 's/^/  /'
    ;;

  send)
    # send [--to <space>] <text...>  (--group is an alias for --to; flag can appear anywhere)
    # C6: routes through space:post so messages are mirrored to the workspace inbox.
    # Set ONE_API_URL + ONE_API_KEY to authenticate; falls back to direct channels signal.
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
    if [ -n "$ONE_API_KEY" ]; then
      # space:post adds "space:" prefix — strip it from the target if already present
      space_name="${target#space:}"
      body=$(jq -n --arg sp "$space_name" --arg c "$text" '{data: {space: $sp, content: $c}}')
      resp=$(curl -s -X POST "${ONE_API_URL}/api/ask/space:post" \
        -H 'Content-Type: application/json' \
        ${CURL_AUTH:+$CURL_AUTH} \
        -d "$body")
    else
      body=$(jq -n --arg s "$SENDER" --arg c "$text" '{sender: $s, content: $c}')
      resp=$(curl -s -X POST "$CHANNELS_URL/signal/$target" \
        -H 'Content-Type: application/json' \
        ${CURL_AUTH:+$CURL_AUTH} \
        -d "$body")
    fi
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

  auth)
    # Save ONE_API_KEY to .auth.conf so the script auto-authenticates without env vars.
    key="${1:?usage: cc-connect auth <one-... key>}"
    # Write with tight permissions from the start (no TOCTOU window)
    old_umask=$(umask)
    umask 177
    /bin/echo "header = \"Authorization: Bearer $key\"" > "$DIR/.auth.conf"
    umask "$old_umask"
    ONE_API_KEY="$key"
    /bin/echo "ok  key saved to $DIR/.auth.conf"
    ;;

  broadcast)
    # broadcast [--to g1,g2,...] <text>  — fan-out to all subscribed space:* groups (or listed ones).
    # Uses space:post (same auth path as send) for space:* targets when ONE_API_KEY is set.
    targets=""
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --to)
          targets="${2:?usage: cc-connect broadcast --to g1,g2 <text>}"
          shift 2
          ;;
        *)
          args+=("$1")
          shift
          ;;
      esac
    done
    text="${args[*]}"
    [ -z "$text" ] && { /bin/echo "error  usage: cc-connect broadcast [--to g1,g2] <text>"; exit 1; }
    if [ -z "$targets" ]; then
      # Default: all space:* groups only (skip raw peer groups like "newco" or "donal")
      targets=$(cfg_groups | /usr/bin/grep '^space:' | /usr/bin/tr '\n' ',')
    fi
    IFS=',' read -ra gs <<< "$targets"
    ok_count=0
    for g in "${gs[@]}"; do
      g="${g// /}"
      [ -z "$g" ] && continue
      if [ -n "$ONE_API_KEY" ] && [[ "$g" == space:* ]]; then
        space_name="${g#space:}"
        body=$(jq -n --arg sp "$space_name" --arg c "$text" '{data: {space: $sp, content: $c}}')
        resp=$(curl -s -X POST "${ONE_API_URL}/api/ask/space:post" \
          -H 'Content-Type: application/json' \
          ${CURL_AUTH:+$CURL_AUTH} \
          -d "$body" 2>/dev/null)
      else
        body=$(jq -n --arg s "$SENDER" --arg c "$text" '{sender: $s, content: $c}')
        resp=$(curl -s -X POST "$CHANNELS_URL/signal/$g" \
          -H 'Content-Type: application/json' \
          ${CURL_AUTH:+$CURL_AUTH} \
          -d "$body" 2>/dev/null)
      fi
      sig=$(/bin/echo "$resp" | jq -r '.result.id // .id // "err"' 2>/dev/null)
      /bin/echo "  → $g  $sig"
      ok_count=$((ok_count + 1))
    done
    /bin/echo "ok  broadcast to $ok_count space(s)"
    ;;

  *)
    /bin/echo "usage: cc-connect {init|join|leave|listen|listen-fg|stop|status|listeners|groups|send|broadcast|read|auth}"
    exit 1
    ;;
esac
