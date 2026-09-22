#!/usr/bin/env bash
# deploy-ready.sh — say which branch the next deploy will take, BEFORE it takes it.
#
# manifest: monorepo-only
#
# WHY THIS EXISTS. deploy.sh prices its heavy gates in memory, not cores:
# vitest (~6GB) and the astro build (--max-old-space-size=8192) overlap only
# when `gate_mem_avail_mb` reports >= DEPLOY_HEAVY_NEED_GB (default 14) at the
# moment the gates start. deploy.sh's own comment carries the measurement:
#
#     overlapped  176s
#     serialised 1145s
#
# That is a 6.5x swing decided by ONE sample taken once, at gate-start, and
# nothing in the pipeline records which way it went. Two runs on a byte-identical
# tree can differ by 6.5x and the ledger cannot say why.
#
# So this is not a new gate and it changes no behaviour. It reads the same
# probe deploy.sh reads, through the same function, and prints the branch the
# deploy WOULD take. It turns a coin-flip into a decision.
#
# THE PROBE IS THE HONEST ONE. `memory_pressure`'s "free percentage" counts file
# cache, purgeable and compressed pages: measured 2026-09-03 it read 74% on a box
# with 1.3% actually free and 9.4GB in swap. gate_mem_avail_mb is what
# lib/govern.sh and deploy.sh both use; this reads it rather than inventing a
# second definition that drifts.
#
# Exit codes, so a caller can branch on it:
#   0  the fast branch — heavy gates will overlap
#   1  the slow branch — they will serialise (deploy still WORKS, just ~6.5x)
#   2  the probe could not read memory
#
# It never refuses and never kills anything: what to do about a short box is the
# operator's call, and a pre-flight that took that call would be a gate.
set -uo pipefail

ROOT="${DEPLOY_READY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "$ROOT/.claude/scripts/lib/govern.sh"

NEED_GB="${DEPLOY_HEAVY_NEED_GB:-14}"

avail_mb="$(gate_mem_avail_mb 2>/dev/null || echo "")"
if [ -z "$avail_mb" ]; then
  echo "  RED  memory probe unreadable — deploy.sh will assume 999GB and OVERLAP"
  echo "       (a broken sensor must never silently serialise the pipeline, so"
  echo "        the fallback is the fast branch. On a short box that pages.)"
  exit 2
fi
free_gb=$(( avail_mb / 1024 ))

swap="$(sysctl -n vm.swapusage 2>/dev/null || echo '')"
load="$(uptime | sed 's/.*load averages*: //')"
cores="$(sysctl -n hw.ncpu 2>/dev/null || echo '?')"

printf '\n  deploy-ready — will the heavy gates overlap?\n\n'
printf '    free memory   %sGB   (need >= %sGB)\n' "$free_gb" "$NEED_GB"
printf '    swap          %s\n' "$swap"
printf '    load          %s   on %s cores\n' "$load" "$cores"

# What is holding memory right now, so "unthrash" is actionable rather than advice.
printf '\n    top memory holders:\n'
ps -Ao rss=,comm=,args= | sort -rn | head -6 | while read -r rss comm rest; do
  printf '      %6s MB  %s\n' "$((rss/1024))" "$(printf '%.58s' "$comm $rest")"
done

printf '\n'
if (( free_gb >= NEED_GB )); then
  printf '    ok   OVERLAP — vitest and build run together (measured ~176s)\n\n'
  exit 0
fi
printf '    RED  SERIALISE — vitest then build, one after the other\n'
printf '         measured 1145s vs 176s: this is the 6.5x branch\n'
printf '         short by %sGB. Free memory before shipping — browsers and\n' "$(( NEED_GB - free_gb ))"
printf '         sessions cost RAM; worktrees cost only disk, so sweeping\n'
printf '         trees is hygiene, not the fix.\n\n'
printf '         Do NOT set DEPLOY_HEAVY_PARALLEL=1 to force the fast branch:\n'
printf '         overlapping ~7GB gates on a short box is what measured 1145s.\n\n'
exit 1
