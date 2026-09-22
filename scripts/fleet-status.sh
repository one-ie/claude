#!/usr/bin/env bash
# fleet-status.sh — what the board looks like right now.
# Reads the machine, the worktrees and the fleet docs. No agents, no cost.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

C_DIM=$'\033[2m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_BAD=$'\033[31m'; C_0=$'\033[0m'; C_B=$'\033[1m'

printf '%s\n' "${C_B}   ██████╗ ███╗   ██╗███████╗${C_0}"
printf '%s\n' "${C_B}  ██╔═══██╗████╗  ██║██╔════╝${C_0}"
printf '%s\n' "${C_B}  ██║   ██║██╔██╗ ██║█████╗  ${C_0}  ${C_DIM}probe · fan out · join${C_0}"
printf '%s\n' "${C_B}  ██║   ██║██║╚██╗██║██╔══╝  ${C_0}  ${C_DIM}no conductor · no collisions${C_0}"
printf '%s\n' "${C_B}  ╚██████╔╝██║ ╚████║███████╗${C_0}"
printf '%s\n' "${C_B}   ╚═════╝ ╚═╝  ╚═══╝╚══════╝${C_0}"
echo

# ── the box ────────────────────────────────────────────────────────────────
cores=$(sysctl -n hw.ncpu 2>/dev/null || echo '?')
memgb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))
load=$(uptime | sed 's/.*load averages*: *//' | awk '{print $1}')
# This board had a THIRD memory arithmetic of its own: (free+inactive) over
# (free+inactive+active+wired). It counted every inactive page as free, dirty
# anonymous ones included, and ignored the compressor entirely — on 2026-09-03
# it printed 41% while vm_stat said 1.3% free and 9.4 GB sat in swap. One honest
# probe now answers for the whole harness.
# shellcheck source=lib/govern.sh
. "$ROOT/.claude/scripts/lib/govern.sh"
availmb=$(gate_mem_avail_mb 2>/dev/null || echo "")
freepct='?'; [ -n "$availmb" ] && [ "$memgb" -gt 0 ] && freepct=$(( availmb * 100 / (memgb * 1024) ))
swapused=$(sysctl -n vm.swapusage 2>/dev/null | sed 's/.*used = \([0-9.]*\)M.*/\1/')

lc=$(printf '%.0f' "${load:-0}" 2>/dev/null || echo 0)
if   [ "$lc" -lt "$((cores))" ]; then lcol=$C_OK
elif [ "$lc" -lt "$((cores*2))" ]; then lcol=$C_WARN
else lcol=$C_BAD; fi

printf '  %-14s %s cores · %s GB\n' 'box' "$cores" "$memgb"
printf '  %-14s %b%s%b   %s free mem   swap %s M\n' 'load' "$lcol" "${load:-?}" "$C_0" "${freepct:-?}%" "${swapused:-?}"

# how many cycles can this box actually afford? Ask the governor rather than
# keeping a second copy of its arithmetic — that copy is how this line drifted.
res=${GOVERN_RESERVE_GB:-2}
permb=$(gate_price_mb)
slots=$(gate_headroom)
capc=$(( cores - 2 )); [ "$slots" -gt "$capc" ] && slots=$capc
bind='memory'; [ "$slots" -eq "$capc" ] && bind='cores'
printf '  %-14s %s  %b(bound by %s · %sMB/cycle · %sGB reserved)%b\n' 'affordable' "$slots" "$C_DIM" "$bind" "$permb" "$res" "$C_0"

gates=$(ls -d "${TMPDIR:-/tmp}"/one-govern/lock-slot-* 2>/dev/null | wc -l | tr -d ' ')
printf '  %-14s %s held / %s max\n' 'gate slots' "$gates" "${GOVERN_MAX_GATES:-2}"

orph=$(pgrep -f 'esbuild|vite/node_modules' 2>/dev/null | wc -l | tr -d ' ')
if [ "$orph" -gt 0 ]; then
  printf '  %-14s %b%s%b  %bpkill -f "esbuild|vite/node_modules"%b\n' 'orphans' "$C_WARN" "$orph" "$C_0" "$C_DIM" "$C_0"
fi
echo

# ── worktrees ──────────────────────────────────────────────────────────────
wt=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
wtsz=$(du -sh .claude/worktrees 2>/dev/null | cut -f1)
printf '  %-14s %s  %s  %b(~120MB + one tsserver each)%b\n' 'worktrees' "$wt" "${wtsz:-0}" "$C_DIM" "$C_0"
echo

# ── the board ──────────────────────────────────────────────────────────────
printf '  %bFLEET%b\n' "$C_B" "$C_0"
while IFS='|' read -r name doc; do
  [ -z "$name" ] && continue
  if [ -f "$doc" ]; then
    lines=$(wc -l < "$doc" | tr -d ' ')
    open=$(grep -ci 'NOT WIRED\|NOT MEASURED\|DARK —' "$doc" 2>/dev/null | head -1 | tr -dc '0-9')
    open=${open:-0}
    if [ "$open" -gt 0 ]; then
      printf '   %b●%b %-13s %-38s %4s lines  %b%s open%b\n' "$C_WARN" "$C_0" "$name" "$doc" "$lines" "$C_WARN" "$open" "$C_0"
    else
      printf '   %b●%b %-13s %-38s %4s lines\n' "$C_OK" "$C_0" "$name" "$doc" "$lines"
    fi
  else
    printf '   %b○%b %-13s %-38s %bnot written%b\n' "$C_DIM" "$C_0" "$name" "$doc" "$C_DIM" "$C_0"
  fi
done < <(
  # Single source of the fleet -> doc map: .claude/scripts/fleet-manifest.mjs,
  # which also feeds /u/one/engineering/fleets. Regenerated here so the CLI and
  # the page can never disagree about which fleets exist. Emits nothing if the
  # manifest is missing — a visibly empty board beats a stale second copy.
  node .claude/scripts/fleet-manifest.mjs >/dev/null 2>&1
  node -e '
    const fs=require("fs");
    const p="one.ie/web/src/data/fleets.json";
    if(!fs.existsSync(p)) process.exit(0);
    for(const f of JSON.parse(fs.readFileSync(p,"utf8")).board)
      console.log(f.name+"|"+(f.doc||"(no doc written)"));
  ' 2>/dev/null
)
echo

# ── the wall ───────────────────────────────────────────────────────────────
DB=$(ls one.ie/web/.wrangler/state/v3/d1/miniflare-D1DatabaseObject/*.sqlite 2>/dev/null | head -1)
if [ -n "$DB" ] && command -v sqlite3 >/dev/null 2>&1; then
  owners=$(sqlite3 "$DB" "SELECT COUNT(*) FROM owners;" 2>/dev/null)
  charge=$(sqlite3 "$DB" "SELECT COUNT(*) FROM owners WHERE charges_enabled=1;" 2>/dev/null)
  addrs=$(sqlite3 "$DB" "SELECT COUNT(*) FROM wallets WHERE sui_address IS NOT NULL AND sui_address!='';" 2>/dev/null)
  sales=$(sqlite3 "$DB" "SELECT COUNT(*) FROM credit_grants WHERE source='credits_product_sale';" 2>/dev/null)
  printf '  %bTHE FUNNEL%b  %b(local mirror of prod)%b\n' "$C_B" "$C_0" "$C_DIM" "$C_0"
  printf '   owners %-6s  can charge %b%-4s%b  wallets w/ address %b%-4s%b  sales %b%s%b\n' \
    "${owners:-?}" "$C_BAD" "${charge:-?}" "$C_0" "$C_BAD" "${addrs:-?}" "$C_0" "$C_WARN" "${sales:-?}" "$C_0"
  echo
fi

printf '  %bnext%b  re-measure (/one §1) · sweep worktrees · then fan out\n' "$C_DIM" "$C_0"
