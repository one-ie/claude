#!/bin/bash
# machine-watch.sh — periodic memory check + conservative reclaim.
#
# Reports the same picture as machine-check.sh, then reclaims ONLY what is
# provably safe: leaked children whose parent is gone, and stale governor locks.
# It never touches a gate owned by a live session and never touches a deploy —
# those are a human's call. Appends one line per run to the log so trend is
# readable without watching.
#
# Usage: machine-watch.sh [--reclaim] [--quiet]
#   --reclaim  actually kill orphans (default: report only)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="${MACHINE_WATCH_LOG:-$ROOT/.machine-watch.log}"
RECLAIM=0; QUIET=0
for a in "$@"; do
  [ "$a" = "--reclaim" ] && RECLAIM=1
  [ "$a" = "--quiet" ]   && QUIET=1
done

CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 8)
LOAD=$(uptime | sed -E 's/.*load averages?: //' | awk '{print $1}')
LOADI=${LOAD%%.*}
FREE=$(memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{gsub(/%/,"",$2); print int($2)}')
FREE=${FREE:-100}
SWAP_USED=$(sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9.]+)M.*/\1/')
SWAP_FREE=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/')
GATE_PAT='(\.bin/tsc --noEmit|\.bin/vitest run|astro check)'

# Snapshot ps ONCE, then count from the frozen text. Critical: a `ps | grep PAT`
# pipeline matches grep's OWN command line (the pattern is an argv element), and
# the awk variant self-matches the same way — both silently inflate every count
# by one. Freezing the snapshot before any matcher process exists removes the
# whole class. (Found 2026-08-21: a phantom ungoverned=2 with nothing running.)
PS_SNAP=$(ps -Ao pid=,ppid=,command= 2>/dev/null)

# Real gate drivers: matches the pattern, and is not a shell wrapper / gate-run
# whose command TEXT merely mentions it.
GATES=$(printf '%s\n' "$PS_SNAP" \
  | grep -E "$GATE_PAT" \
  | grep -vE '^ *[0-9]+ +[0-9]+ +([^ ]*/)?(zsh|bash|sh|grep|awk|ps)( |$)|gate-run\.sh' \
  | grep -c . || true)

# Of those, how many have no gate-run.sh ancestor — the actionable number.
UNGOV=$(printf '%s\n' "$PS_SNAP" | awk '
  { cmd=""; for(i=3;i<=NF;i++) cmd=cmd" "$i; parent[$1]=$2; command[$1]=cmd }
  END {
    for (p in command) {
      if (command[p] !~ GP) continue
      if (command[p] ~ /^ *([^ ]*\/)?(zsh|bash|sh|grep|awk|ps) /) continue
      if (command[p] ~ /gate-run\.sh/) continue
      q=parent[p]; gov=0
      for (i=0; i<9 && q!="" && q!="1"; i++) {
        if (command[q] ~ /gate-run\.sh/) { gov=1; break }
        q=parent[q]
      }
      if (!gov) n++
    }
    print n+0
  }' GP="$GATE_PAT" || true)
UNGOV=${UNGOV:-0}

# macOS sizes the swap FILE to demand, so small swap_free is NOT thrash. Thrash
# is pages going OUT while free memory is scarce. Measure the pageout RATE across
# runs via a state file.
STATE="${MACHINE_WATCH_STATE:-$ROOT/.machine-watch.state}"
NOW=$(date +%s)
PGOUT=$(vm_stat | awk '/Pageouts/{gsub(/\./,"",$NF); print $NF}')
PGOUT=${PGOUT:-0}
PO_RATE=0
if [ -r "$STATE" ]; then
  read -r LAST_T LAST_PO < "$STATE" 2>/dev/null || true
  if [ -n "${LAST_T:-}" ] && [ -n "${LAST_PO:-}" ] && [ "$NOW" -gt "$LAST_T" ]; then
    PO_RATE=$(( (PGOUT - LAST_PO) / (NOW - LAST_T) ))
    [ "$PO_RATE" -lt 0 ] && PO_RATE=0
  fi
fi
echo "$NOW $PGOUT" > "$STATE"

# Claude sessions are the other half of the bill and they only ever grow: each
# session's cost is its whole descendant tree (gates, node, language servers),
# not the one `claude` process. Track count + rolled-up RSS + oldest age so the
# trend is visible before the box is in trouble.
SESSIONS=$(printf '%s\n' "$PS_SNAP" | grep -cE '(^| )[0-9]+ +[0-9]+ +([^ ]*/)?claude( |$)|claude --' || true)
SESS_MB=$(printf '%s\n' "$PS_SNAP" | awk '
  { cmd=""; for(i=3;i<=NF;i++) cmd=cmd" "$i; parent[$1]=$2; command[$1]=cmd }
  END { print 0 }')
SESS_MB=$(ps -Ao rss=,command= 2>/dev/null | awk '/[c]laude/{s+=$1} END{printf "%d", s/1024}')
SESSIONS=${SESSIONS:-0}; SESS_MB=${SESS_MB:-0}

# Thresholds are env-tunable so the alarm can be exercised in BOTH directions.
# An alarm only ever seen green is an unproven alarm.
W_LOAD_FACTOR="${WATCH_LOAD_FACTOR:-2}"
W_FREE_WARN="${WATCH_FREE_WARN:-20}"
W_FREE_CRIT="${WATCH_FREE_CRIT:-10}"
W_GATES="${WATCH_GATES_WARN:-4}"
W_PO="${WATCH_PAGEOUT_CRIT:-100}"
W_PO_FREE="${WATCH_PAGEOUT_FREE:-25}"

SEV=ok
[ "$LOADI" -gt $((CORES * W_LOAD_FACTOR)) ] && SEV=warn
[ "$FREE" -lt "$W_FREE_WARN" ]              && SEV=warn
[ "$GATES" -ge "$W_GATES" ]                 && SEV=warn
[ "$UNGOV" -ge "${WATCH_UNGOV_WARN:-2}" ]     && SEV=warn
# Sustained pageouts with little free memory = the box is actually paging.
[ "$PO_RATE" -gt "$W_PO" ] && [ "$FREE" -lt "$W_PO_FREE" ] && SEV=CRITICAL
[ "$FREE" -lt "$W_FREE_CRIT" ]                              && SEV=CRITICAL

# ── reclaim: leaked children of a dead parent, inside this repo, > 5 min old ──
# Shape filter is load-bearing: a backgrounded `astro dev` / `wrangler dev`
# reparents to launchd the moment its launching shell exits, and is then
# indistinguishable BY PATH from a leaked esbuild child. Reaping it is what made
# the dev server "keep stopping" every 10 minutes. Only leaked HELPERS qualify,
# and only past the 5-minute age the comment above always claimed (etime is $3).
ORPHANS=$(ps -Ao pid=,ppid=,etime=,command= 2>/dev/null \
  | awk -v root="$ROOT" '
      $2!=1 { next }
      index($0, root"/one.ie/web/node_modules")==0 { next }
      # long-lived servers a human deliberately started — never reap
      /astro dev|vite|wrangler|workerd serve|miniflare|tsserver/ { next }
      {
        # etime: [[dd-]hh:]mm:ss — require > 5 minutes
        e=$3; sub(/^.*-/,"",e); n=split(e,t,":")
        secs = (n==3 ? t[1]*3600+t[2]*60+t[3] : t[1]*60+t[2])
        if (secs > 300) print $1
      }')
KILLED=0
for p in $ORPHANS; do
  [ -z "$p" ] && continue
  if [ "$RECLAIM" = "1" ]; then
    kill -TERM "$p" 2>/dev/null; sleep 1; kill -KILL "$p" 2>/dev/null
    KILLED=$((KILLED+1))
  else
    KILLED=$((KILLED+1))
  fi
done

# stale governor locks (owner pid gone) — shrinks the slot cap silently otherwise
STALE=0
GDIR="${TMPDIR:-/tmp}one-govern"
for l in "$GDIR"/lock-slot-* "$GDIR"/lock-tsc-*; do
  [ -d "$l" ] || continue
  own=$(cat "$l/pid" 2>/dev/null)
  [ -z "$own" ] && continue
  if ! kill -0 "$own" 2>/dev/null; then
    [ "$RECLAIM" = "1" ] && rm -rf "$l"
    STALE=$((STALE+1))
  fi
done

# An ungoverned gate is usually short-lived — by the time a human investigates it
# has exited. Record WHICH command it was at detection time, or the warning is
# unactionable (observed 2026-08-21 15:21: ungoverned=2, both gone seconds later).
if [ "${UNGOV:-0}" -gt 0 ]; then
  ps -Ao pid=,etime=,command= 2>/dev/null \
    | grep -E "$GATE_PAT" \
    | grep -vE '^ *[0-9]+ *[0-9:-]+ *[^ ]*/(zsh|bash|sh) |gate-run\.sh' \
    | sed "s|^|$(date '+%Y-%m-%d %H:%M:%S') UNGOVERNED |" >> "${LOG%.log}.ungoverned.log"
fi

STAMP=$(date '+%Y-%m-%d %H:%M:%S')
VERB=$([ "$RECLAIM" = "1" ] && echo reaped || echo "would-reap")
LINE="$STAMP sev=$SEV load=$LOAD free=${FREE}% swap_used=${SWAP_USED}M swap_free=${SWAP_FREE}M pageout_rate=${PO_RATE}/s gates=$GATES ungoverned=$UNGOV sessions=$SESSIONS sess_mb=${SESS_MB}M ${VERB}_orphans=$KILLED stale_locks=$STALE"
echo "$LINE" >> "$LOG"

if [ "$QUIET" = "0" ] || [ "$SEV" != "ok" ]; then
  echo "$LINE"
  if [ "$SEV" != "ok" ]; then
    echo
    echo "  top consumers:"
    ps -Ao rss=,comm= | awk '{n=$2;for(i=3;i<=NF;i++)n=n" "$i;split(n,a,"/");k=a[length(a)];s[k]+=$1}END{for(i in s)printf "    %8.0f MB  %s\n",s[i]/1024,i}' | sort -rn | head -5
  fi
fi

[ "$SEV" = "CRITICAL" ] && exit 2
[ "$SEV" = "warn" ] && exit 1
exit 0
