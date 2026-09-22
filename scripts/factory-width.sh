#!/usr/bin/env bash
# factory-width.sh — how many factory tasks this box may build AT ONCE, measured.
#
# manifest: portable
#
# The Workflow runtime caps a script's concurrency at min(16, cpus-2) — CORES,
# which were never the binding constraint here (10 cores authorised 8 worktrees
# on a 24 GB box; 8 cycles is ~16 GB of gates). Two things bind first, and this
# prints the smaller so the launcher passes it as args.width:
#
#   memory   gate_headroom — MB actually free (vm_stat: free + purgeable + cold
#            cache, never memory_pressure's inflated figure) ÷ the measured price
#            of one cycle. 99 means "the sensor is unreadable — do not constrain".
#   ports    the preview range minus what a neighbour already holds. One
#            server per UI task; 4321 is the human's and is never counted.
#
# Prints ONE JSON line: {"width":N,"memory":N,"ports":N,"price_mb":N}. Never 0 —
# work slows, it never stops (the governor's own floor). Exit 0 always; a reader
# that cannot get a number gets 1, printed, not a crash.
#
#   bash .claude/scripts/factory-width.sh            # {"width":1,...}
#   bash .claude/scripts/factory-width.sh --explain  # the same, with the why
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/.claude/scripts/lib/govern.sh"
PORT_MIN="${PREVIEW_PORT_MIN:-4322}"; PORT_MAX="${PREVIEW_PORT_MAX:-4329}"

mem=99; price=0
if [ -f "$LIB" ]; then
  # shellcheck source=lib/govern.sh
  . "$LIB"
  mem="$(gate_headroom 2>/dev/null || echo 99)"
  price="$(gate_price_mb 2>/dev/null || echo 0)"
fi
case "$mem" in ''|*[!0-9]*) mem=99 ;; esac

ports=0
if command -v lsof >/dev/null 2>&1; then
  for ((p = PORT_MIN; p <= PORT_MAX; p++)); do
    lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 || ports=$((ports + 1))
  done
else
  ports=$((PORT_MAX - PORT_MIN + 1))   # no lsof: cannot see neighbours; the range is the cap
fi
[ "$ports" -lt 1 ] && ports=1

width="$mem"; [ "$ports" -lt "$width" ] && width="$ports"
[ "$width" -lt 1 ] && width=1
# 99 is "unconstrained by memory"; the ports then bind, and they always exist.
[ "$width" -gt 16 ] && width=16

printf '{"width":%s,"memory":%s,"ports":%s,"price_mb":%s}\n' "$width" "$mem" "$ports" "$price"
if [ "${1:-}" = "--explain" ]; then
  echo "width $width = min(memory funds $mem cycle(s) at ${price} MB, $ports free preview port(s) in $PORT_MIN-$PORT_MAX)" >&2
  [ "$mem" = 99 ] && echo "memory sensor unreadable (99) — not constraining; ports bind" >&2
fi
exit 0
