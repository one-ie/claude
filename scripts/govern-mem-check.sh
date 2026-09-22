#!/usr/bin/env bash
# govern-mem-check.sh — prove the machine governor's memory probe can say NO.
#
#   bash .claude/scripts/govern-mem-check.sh            # all checks
#   bash .claude/scripts/govern-mem-check.sh --self-test # same, explicit
#   bash .claude/scripts/govern-mem-check.sh --live      # just read this box
#
# WHY THIS EXISTS
# gate_headroom used to compute availability as
#     hw.memsize * (memory_pressure "free percentage") / 100
# and that percentage counts reclaimable memory — file cache, purgeable, and
# already-compressed pages — as free. It is a PRESSURE signal, not a quantity.
# Measured three times on one 24GB box, all while ~1% of RAM was actually free
# and 9-12 GB sat in swap, the old probe answered "room for 2 / 7 / 7 more
# 2GB cycles". A governor that cannot say no is not a governor.
#
# Every check below drives a SYNTHETIC machine state — a fake vm_stat, a fake
# memory_pressure block and a fake vm.swapusage line, together, so the old
# formula and the new one see the SAME input and the comparison is honest.
# Stubbing is done by overriding _gv_vm_stat / _gv_swapusage / _gv_memsize,
# the same idiom govern-claims-check.sh uses to stub _gv_alive.
#
# Nothing here touches the real machine, the real $GOVERN_DIR, or any gate.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

# Sandbox: never touch the machine-wide governor dir.
export GOVERN_DIR="${TMPDIR:-/tmp}/one-govern-memcheck.$$"
mkdir -p "$GOVERN_DIR"
trap 'rm -rf "$GOVERN_DIR"' EXIT

# shellcheck source=lib/govern.sh
. "$ROOT/.claude/scripts/lib/govern.sh"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ── the pre-fix arithmetic, VERBATIM ────────────────────────────────────────
# Copied unchanged from lib/govern.sh before 2026-09-03 (the `deploy-gate-check.sh`
# idiom: carry the old code so the red proof is a real comparison, not a story).
_old_gate_headroom() {
  local total_gb free_pct avail_gb usable_gb per_cycle reserve slots
  total_gb=$(( $(_gv_memsize 2>/dev/null || echo 0) / 1073741824 ))
  [ "$total_gb" -lt 1 ] && { echo 99; return 0; }
  free_pct=$(_gv_memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{gsub(/%/,"",$2); print int($2)}')
  [ -z "$free_pct" ] && { echo 99; return 0; }
  per_cycle="${GOVERN_GB_PER_CYCLE:-2}"
  reserve="${GOVERN_RESERVE_GB:-2}"
  avail_gb=$(( total_gb * free_pct / 100 ))
  usable_gb=$(( avail_gb - reserve ))
  [ "$usable_gb" -lt 0 ] && usable_gb=0
  slots=$(( usable_gb / per_cycle ))
  [ "$slots" -lt 1 ] && slots=1
  echo "$slots"
}
_old_gate_pressure() {
  local free_pct
  free_pct=$(_gv_memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{gsub(/%/,"",$2); print $2}')
  [ -z "$free_pct" ] && return 0
  [ "$free_pct" -lt "${GOVERN_MIN_FREE_PCT:-12}" ] && return 1
  return 0
}

# ── synthetic machine states ────────────────────────────────────────────────
# All on a 24 GB / 16384-byte-page box, so hw.memsize is constant and only the
# page counts move. FIX_* are set by fixture(); the stubs read them.
FIX_FREE=0; FIX_PURGE=0; FIX_INACT=0; FIX_FILEBK=0; FIX_ACTIVE=0; FIX_WIRED=0
FIX_COMPRESSOR=0; FIX_PCT=0; FIX_SWAP_USED="0.00"; FIX_SWAP_TOTAL="0.00"
FIX_MODE=normal   # normal | empty | garbage | nopagesize

_gv_memsize()   { [ "$FIX_MODE" = "nomemsize" ] && return 1; echo 25769803776; }
_gv_swapusage() { echo "total = ${FIX_SWAP_TOTAL}M  used = ${FIX_SWAP_USED}M  free = 0.00M  (encrypted)"; }
_gv_memory_pressure() {
  cat <<PRESSURE
Swapins: 1614739
Swapouts: 2928367

Page Q counts:
Pages active: $FIX_ACTIVE
Pages inactive: $FIX_INACT
Pages speculative: 6772
Pages throttled: 0
Pages wired down: $FIX_WIRED

Compressor Stats:
Pages used by compressor: $FIX_COMPRESSOR

System-wide memory free percentage: ${FIX_PCT}%
PRESSURE
}
_gv_vm_stat() {
  case "$FIX_MODE" in
    empty)      return 0 ;;
    garbage)    echo "vm_stat: command not found"; return 0 ;;
    nopagesize) echo "Mach Virtual Memory Statistics:" ;;
    *)          echo "Mach Virtual Memory Statistics: (page size of 16384 bytes)" ;;
  esac
  cat <<VMSTAT
Pages free:                                   $FIX_FREE.
Pages active:                                 $FIX_ACTIVE.
Pages inactive:                               $FIX_INACT.
Pages speculative:                              6772.
Pages throttled:                                   0.
Pages wired down:                             $FIX_WIRED.
Pages purgeable:                              $FIX_PURGE.
File-backed pages:                            $FIX_FILEBK.
Anonymous pages:                              893951.
Pages occupied by compressor:                 $FIX_COMPRESSOR.
Swapins:                                     1614739.
Swapouts:                                    2928367.
VMSTAT
}

fixture() {
  FIX_MODE=normal
  case "$1" in
    # ── The live reading taken 2026-09-03 at load 8, verbatim from vm_stat and
    #    memory_pressure on the box the operator was complaining about. It
    #    reproduces Receipt B: 1.3% of RAM free, 9.4 GB in swap, probe says 7.
    thrash-now)
      FIX_FREE=21032; FIX_PURGE=646; FIX_INACT=547837; FIX_FILEBK=216477
      FIX_ACTIVE=555819; FIX_WIRED=250202; FIX_COMPRESSOR=135982
      FIX_PCT=74; FIX_SWAP_USED="9400.56"; FIX_SWAP_TOTAL="10240.00" ;;
    # ── Receipt A: the verifier's sample at load 27, with hook:load-guard itself
    #    reporting the machine saturated. free 15798 pages, compressor 8.7 GB,
    #    swap 11997/13312 M, memory_pressure 32%. Old probe answered 2.
    thrash-A)
      FIX_FREE=15798; FIX_PURGE=500; FIX_INACT=137812; FIX_FILEBK=100000
      FIX_ACTIVE=600000; FIX_WIRED=250000; FIX_COMPRESSOR=569254
      FIX_PCT=32; FIX_SWAP_USED="11997.44"; FIX_SWAP_TOTAL="13312.00" ;;
    # ── The row that kills a swap-subtraction design: genuinely idle NOW
    #    (8 GB free, 6 GB cache) but macOS has not released the 9.4 GB swapfile
    #    it grew an hour ago. A probe that charges for history serialises this.
    recovered-idle)
      FIX_FREE=524288; FIX_PURGE=1000; FIX_INACT=655360; FIX_FILEBK=393216
      FIX_ACTIVE=200000; FIX_WIRED=200000; FIX_COMPRESSOR=50000
      FIX_PCT=85; FIX_SWAP_USED="9400.56"; FIX_SWAP_TOTAL="10240.00" ;;
    # ── Fresh idle: 12 GB free, swap never grown.
    fresh-idle)
      FIX_FREE=786432; FIX_PURGE=500; FIX_INACT=65536; FIX_FILEBK=131072
      FIX_ACTIVE=100000; FIX_WIRED=150000; FIX_COMPRESSOR=20000
      FIX_PCT=90; FIX_SWAP_USED="0.00"; FIX_SWAP_TOTAL="0.00" ;;
    # ── Absurd: nothing available at all. Must floor to 1, never 0 —
    #    do-fleet.sh clamps its slot count to this with no floor of its own.
    starved)
      FIX_FREE=0; FIX_PURGE=0; FIX_INACT=0; FIX_FILEBK=0
      FIX_ACTIVE=1000000; FIX_WIRED=500000; FIX_COMPRESSOR=72864
      FIX_PCT=1; FIX_SWAP_USED="16000.00"; FIX_SWAP_TOTAL="16384.00" ;;
    *) echo "unknown fixture $1" >&2; exit 2 ;;
  esac
}

# The environment the checks are scored in: the box's real settings.json values
# minus the stale GOVERN_GB_PER_CYCLE pin, so the derived price is live.
unset GOVERN_GB_PER_CYCLE
export GOVERN_RESERVE_GB=3
export VITEST_MAX_FORKS=4          # what a Claude Code session actually sets

[ "${1:-}" = "--live" ] && { echo "live: $(gate_mem_report)"; exit 0; }

# ═══════════════════════════════════════════════════════════════════════════
hdr "1. THRASH — the new probe says no, and the OLD one says yes (red proof)"
for st in thrash-now thrash-A; do
  fixture "$st"
  new=$(gate_headroom); old=$(_old_gate_headroom)
  avail=$(gate_mem_avail_mb)
  oldpct=$FIX_PCT
  if _old_gate_pressure; then oldp="0 (has headroom)"; else oldp="1 (thrashing)"; fi
  if gate_pressure;      then newp="0 (has headroom)"; else newp="1 (thrashing)"; fi
  echo "  [$st] memory_pressure says ${oldpct}% free · vm_stat says $((FIX_FREE*16384/1048576))MB free · swap ${FIX_SWAP_USED}M used"
  echo "        OLD: headroom=$old  pressure=$oldp        NEW: avail=${avail}MB headroom=$new  pressure=$newp"
  [ "$new" -eq 1 ] && ok "$st: new cap FELL to 1" || bad "$st: new cap is $new, expected 1"
  [ "$old" -gt 1 ] && ok "$st: OLD arithmetic authorised $old cycles on this same state (red proof)" \
                   || bad "$st: OLD arithmetic did not over-authorise — red proof is inert"
  _old_gate_pressure && ok "$st: OLD gate_pressure called it healthy (red proof)" \
                     || bad "$st: OLD gate_pressure already fired — red proof is inert"
  gate_pressure && bad "$st: NEW gate_pressure still calls it healthy" \
                || ok "$st: NEW gate_pressure fires"
done

hdr "2. HEALTHY — not replaced by a serialising bug"
for st in recovered-idle fresh-idle; do
  fixture "$st"
  new=$(gate_headroom); avail=$(gate_mem_avail_mb)
  echo "  [$st] avail=${avail}MB  swap ${FIX_SWAP_USED}M used  ->  headroom=$new"
  [ "$new" -ge 2 ] && ok "$st: healthy box still funds $new cycles (>=2)" \
                   || bad "$st: healthy box collapsed to $new — this is the serialising bug"
  gate_pressure && ok "$st: gate_pressure stays quiet" || bad "$st: gate_pressure fired on a healthy box"
done
echo "  (recovered-idle is the row that refutes any design subtracting vm.swapusage:"
echo "   9.4GB of stale swap would drive it to 1 while 8GB of RAM sits free.)"

hdr "3. BROKEN SENSOR — 99, never 0, never 1"
for mode in empty garbage nopagesize; do
  fixture thrash-now; FIX_MODE="$mode"
  h=$(gate_headroom)
  [ "$h" = "99" ] && ok "vm_stat '$mode' -> headroom=99 (do not constrain)" \
                  || bad "vm_stat '$mode' -> headroom=$h, expected 99"
  gate_pressure && ok "vm_stat '$mode' -> gate_pressure does not block" \
                || bad "vm_stat '$mode' -> gate_pressure blocked on a broken probe"
done

hdr "4. FLOOR — a starved box slows down, it never stops"
fixture starved
h=$(gate_headroom); a=$(gate_mem_avail_mb)
echo "  avail=${a}MB, reserve=$((GOVERN_RESERVE_GB*1024))MB, price=$(gate_price_mb)MB -> headroom=$h"
[ "$h" = "1" ] && ok "starved box -> 1 (do-fleet.sh clamps to this with no floor of its own; 0 would launch nothing)" \
               || bad "starved box -> $h, expected 1"

hdr "5. PRICE — derived from the live fork count, not a stale constant"
p4=$(VITEST_MAX_FORKS=4 gate_price_mb)
p8=$(VITEST_MAX_FORKS=8 gate_price_mb)
pdef=$(unset VITEST_MAX_FORKS; gate_price_mb)
povr=$(GOVERN_GB_PER_CYCLE=2 gate_price_mb)
echo "  forks=4 -> ${p4}MB · forks=8 -> ${p8}MB · unset -> ${pdef}MB · GOVERN_GB_PER_CYCLE=2 -> ${povr}MB"
[ "$p8" -gt "$p4" ]  && ok "price tracks fork count (8 forks cost more than 4)" || bad "price ignores fork count"
[ "$p4" -gt 2048 ]   && ok "a 4-fork slot is priced above the old flat 2048MB" || bad "4-fork slot still priced at or below the stale constant ($p4)"
[ "$pdef" = "$p8" ]  && ok "unset VITEST_MAX_FORKS prices the config default of 8" || bad "unset != 8-fork price"
[ "$povr" = "2048" ] && ok "explicit GOVERN_GB_PER_CYCLE still wins (operator override)" || bad "override ignored"
if grep -q '"GOVERN_GB_PER_CYCLE"' "$ROOT/.claude/settings.json" 2>/dev/null; then
  bad "settings.json still pins GOVERN_GB_PER_CYCLE — the derivation is dead code in every Claude Code session"
else
  ok "settings.json no longer pins GOVERN_GB_PER_CYCLE"
fi

hdr "6. SELF-RED — gut the probe and the checks above MUST go red"
# A checker that stays green against a gutted probe proves nothing
# (govern-claims-check.sh stubs _gv_alive for exactly this reason). Here we
# put the OLD arithmetic back behind the new name and re-run section 1's
# assertions: they have to fail.
_saved_headroom=$(declare -f gate_headroom)
_saved_pressure=$(declare -f gate_pressure)
gate_headroom() { _old_gate_headroom; }
gate_pressure() { _old_gate_pressure; }
red=0
for st in thrash-now thrash-A; do
  fixture "$st"
  h=$(gate_headroom)
  [ "$h" -eq 1 ] || red=$((red+1))
  gate_pressure && red=$((red+1))
done
if [ "$red" -ge 4 ]; then
  ok "with the old arithmetic restored, all 4 thrash assertions fail ($red/4) — the checks have power"
else
  bad "gutted probe still satisfied $(( 4 - red ))/4 thrash assertions — this checker proves nothing"
fi
eval "$_saved_headroom"; eval "$_saved_pressure"

hdr "7. LOAD-GUARD's MEMORY ARM — the one site that actually BLOCKS"
# load-guard-check.sh exercises the regex classifier (which commands count as
# heavy), never the memory state. This drives the real hook against the REAL
# box with only the memory threshold moving, so the arm is seen firing AND
# staying silent — a guard only ever seen to fire is an unproven guard. The load
# and running-gate arms are pinned out of the way so nothing else can explain
# the verdict.
_lg_run() {  # _lg_run <GUARD_MIN_FREE_PCT> -> prints "deny" or "allow"
  local out
  out=$(CLAUDE_PROJECT_DIR="$ROOT" GUARD_MIN_FREE_PCT="$1" \
        GUARD_LOAD_FACTOR=100000 GUARD_MAX_RUNNING=100000 \
        bash "$ROOT/.claude/hooks/load-guard.sh" \
        '{"tool_name":"Bash","tool_input":{"command":"bunx vitest run"}}' 2>/dev/null)
  case "$out" in *'"deny"'*) echo deny ;; *) echo allow ;; esac
}
_lg_hi=$(_lg_run 101)   # threshold above any possible reading -> must deny
_lg_lo=$(_lg_run 0)     # threshold below any possible reading -> must allow
echo "  GUARD_MIN_FREE_PCT=101 -> $_lg_hi   ·   GUARD_MIN_FREE_PCT=0 -> $_lg_lo"
[ "$_lg_hi" = "deny" ]  && ok "memory arm FIRES (hook emits a deny decision, does not crash open)" \
                        || bad "memory arm did not fire — the blocking hook failed OPEN"
[ "$_lg_lo" = "allow" ] && ok "memory arm stays silent on a satisfied threshold" \
                        || bad "memory arm fires unconditionally — it is not reading memory"
# And it must survive a probe that cannot be read at all: point the hook at a
# project dir with no govern.sh. FREE falls back to 100, so the arm goes quiet
# rather than taking the hook down with it.
_lg_nolib=$(CLAUDE_PROJECT_DIR="$GOVERN_DIR" GUARD_MIN_FREE_PCT=101 \
            GUARD_LOAD_FACTOR=100000 GUARD_MAX_RUNNING=100000 \
            bash "$ROOT/.claude/hooks/load-guard.sh" \
            '{"tool_name":"Bash","tool_input":{"command":"bunx vitest run"}}' 2>/dev/null; echo "rc=$?")
case "$_lg_nolib" in
  *rc=0*) ok "missing govern.sh -> hook still exits 0 (FREE=100, arm silent, nothing crashes)" ;;
  *)      bad "missing govern.sh -> hook exited non-zero: $_lg_nolib" ;;
esac

hdr "RESULT"
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || { echo "  GOVERN-MEM-CHECK: RED"; exit 1; }
echo "  GOVERN-MEM-CHECK: GREEN"
