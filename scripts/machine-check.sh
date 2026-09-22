#!/usr/bin/env bash
# machine-check.sh — is this box healthy, and if not, what is holding it?
# Answers the question "why is my Mac slow" with numbers, not vibes.
#   bash .claude/scripts/machine-check.sh          # snapshot
#   bash .claude/scripts/machine-check.sh --watch  # live swap-rate probe
set -uo pipefail

cores=$(sysctl -n hw.ncpu); ram=$(( $(sysctl -n hw.memsize) / 1073741824 ))
load=$(uptime | sed -E 's/.*load averages?: //')
l1=$(echo "$load" | awk '{print $1}')
echo "host      : ${cores} cores · ${ram} GB RAM"
echo "load      : $load   (healthy < ${cores})"
sysctl -n vm.swapusage | sed 's/^/swap      : /'
# Both numbers, deliberately. memory_pressure's "free percentage" is what every
# probe in this harness used to believe; it counts file cache, purgeable and
# already-compressed pages as free, and read 74% on 2026-09-03 while 1.3% of RAM
# was actually free and 9.4 GB sat in swap. Printing them side by side is how
# the next person sees the gap instead of rediscovering it.
# shellcheck source=lib/govern.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/govern.sh"
free_pct=$(memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{print $2}')
avail_mb=$(gate_mem_avail_mb 2>/dev/null || echo "")
tot_mb=$(( ram * 1024 ))
if [ -n "$avail_mb" ] && [ "$tot_mb" -gt 0 ]; then
  echo "free mem  : $(( avail_mb / 1024 )) GB available ($(( avail_mb * 100 / tot_mb ))% — free + purgeable + cold cache)"
  echo "            memory_pressure claims ${free_pct:-?} free; that figure counts reclaimable memory — never price gates with it"
else
  echo "free mem  : ? (vm_stat unreadable) · memory_pressure claims ${free_pct:-?}"
fi
echo "gates     : memory funds $(gate_headroom) concurrent cycle(s) at $(gate_price_mb) MB each"

if [ "${1:-}" = "--watch" ]; then
  echo -n "swap rate : sampling 10s ... "
  _sw() { vm_stat | awk '/Swapins/{gsub(/\./,"",$2); i=$2} /Swapouts/{gsub(/\./,"",$2); o=$2} END{print i, o}'; }
  _used() { sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9.]+)M.*/\1/' | cut -d. -f1; }
  a=$(_sw); ua=$(_used); sleep 10; b=$(_sw); ub=$(_used)
  din=$(( $(echo "$b"|awk '{print $1}') - $(echo "$a"|awk '{print $1}') ))
  dout=$(( $(echo "$b"|awk '{print $2}') - $(echo "$a"|awk '{print $2}') ))
  echo "in ${din} / out ${dout} pages per 10s · swap used ${ua}M -> ${ub}M"
  # Swapins alone are ambiguous: they spike during RECOVERY too, as freed
  # memory lets pages fault back in. The thrash signal is pages going OUT
  # while swap usage GROWS and free memory is scarce — that is the box
  # evicting live working sets to make room, which is what makes it crawl.
  fp=$(memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{gsub(/%/,"",$2); print int($2)}')
  if [ "$dout" -gt 2000 ] && [ "$ub" -ge "$ua" ] && [ "${fp:-100}" -lt 20 ]; then
    echo "            ^^ THRASHING — evicting live memory; reduce concurrent gates"
  elif [ "$din" -gt 1000 ] && [ "$ub" -lt "$ua" ]; then
    echo "            (recovering — swap draining, pages faulting back in; this is fine)"
  else
    echo "            (paging normal)"
  fi
fi

echo
echo "── heavy gates running now ──"
ps -Ao pid=,etime=,rss=,command= \
  | grep -E '[t]sc --noEmit|[v]itest run|[a]stro check|[e]sbuild --service' \
  | awk '{printf "  %-7s %-9s %6.0fMB  %s\n",$1,$2,$3/1024,substr($0,index($0,$4),60)}' \
  || echo "  none"

echo
echo "── language servers (OUTSIDE the governor) ──"
# Every Claude Code session spawns typescript-language-server, and its tsserver
# child grows with the project it indexes. Measured 2026-09-04: one tsserver at
# 1.99 GB after 1h39m, 2.46 GB across the fleet — the single largest ungoverned
# consumer on the box, and it never shows up in a "heavy gates" grep because it
# is not a gate. It is priced only indirectly, through what gate_mem_avail_mb
# sees left over. Listed so the number is legible, not to be killed here.
ps -Ao pid=,etime=,rss=,command= \
  | grep -E '[t]sserver\.js|[t]ypescript-language-server' \
  | awk '{n++; s+=$3; if ($3/1024 >= 100) printf "  %-7s %-9s %6.0fMB  tsserver\n",$1,$2,$3/1024}
         END {printf "  %d process(es), %.0f MB total\n", n, s/1024}'

echo
echo "── governor ──"
GOVERN_DIR="${GOVERN_DIR:-${TMPDIR:-/tmp}/one-govern}"
if [ -d "$GOVERN_DIR" ]; then
  held=0
  for d in "$GOVERN_DIR"/lock-*; do
    [ -d "$d" ] || continue
    pid=$(cat "$d/pid" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
      echo "  HELD  $(basename "$d")  by pid $pid"; held=$((held+1))
    else
      echo "  stale $(basename "$d")  (dead pid $pid — will be reaped)"
    fi
  done
  [ "$held" = 0 ] && echo "  no slots held (idle)"
else
  echo "  never used yet"
fi

echo
echo "── orphans (parent died, work still burning CPU) ──"
ps -Ao pid=,ppid=,etime=,rss=,command= | awk '$2==1' \
  | grep -E 'tsc --noEmit|vitest|bun run (verify|test)|node .*(one-ie|\.do-worktrees)|node_modules.*workerd serve|sleep [0-9]+$' \
  | awk '{printf "  %-7s %-9s %6.0fMB  %s\n",$1,$3,$4/1024,substr($0,index($0,$5),55)}' \
  || echo "  none"

echo
echo "── claude sessions ──"
echo "  $(pgrep -f '^claude' 2>/dev/null | wc -l | tr -d ' ') running · each /do cycle can launch a gate"
