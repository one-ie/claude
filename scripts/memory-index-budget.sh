#!/usr/bin/env bash
# memory-index-budget.sh — is the auto-memory index still inside the loader's budget?
#
# WHY THIS EXISTS. Measured 2026-09-12: MEMORY.md was 89,954 bytes / 479 lines,
# and a session loaded 128 lines = 25,162 bytes. The cut is a ~25KB BYTE budget.
# 73% of the index never reached context, and the only warning was a line at the
# BOTTOM of the file — inside the 73% nobody reads. The corpus passed the budget
# around June and nothing noticed for three months.
#
# The loader's own advice ("one line under ~200 chars") does not fix it: 245 of
# 479 lines violated it, and trimming every one yields 77,943 bytes — still 3.1x
# over. The constraint is total bytes, so that is what this measures.
#
# Growth is 7.3 files/day (Sep 2026), so an index cut by hand re-grows within
# weeks. This is the thing that says so.
#
#   bash memory-index-budget.sh              # check, exit 3 if over
#   bash memory-index-budget.sh --self-test  # prove it can go RED
set -uo pipefail

BUDGET_BYTES="${MEMORY_INDEX_BUDGET:-25162}"   # measured cut, not a guess
WARN_AT_PCT="${MEMORY_INDEX_WARN_PCT:-80}"

_check() {
  local idx="$1"
  [ -f "$idx" ] || { echo "[memory-budget] no index at $idx"; return 2; }

  local bytes lines pct
  bytes=$(wc -c < "$idx" | tr -d ' ')
  lines=$(wc -l < "$idx" | tr -d ' ')
  pct=$(( bytes * 100 / BUDGET_BYTES ))

  # How much actually loads: bytes are the cap, so count lines until the budget.
  local fit
  fit=$(awk -v b="$BUDGET_BYTES" '{s+=length($0)+1; if(s<=b) n++} END{print n+0}' "$idx")
  local dark=$(( lines - fit ))
  local darkpct=0
  [ "$lines" -gt 0 ] && darkpct=$(( dark * 100 / lines ))

  echo "[memory-budget] $idx"
  echo "  bytes   $bytes / $BUDGET_BYTES budget  (${pct}%)"
  echo "  lines   $lines total, ~$fit reach context, $dark dark (${darkpct}%)"

  if [ "$bytes" -gt "$BUDGET_BYTES" ]; then
    echo "  RED — over budget. ~${darkpct}% of the index never reaches context."
    echo "        Trimming long lines does not fix this; the cap is total bytes."
    echo "        Shrink to a hot set and move the tail to its files — they stay"
    echo "        reachable by their description:, which is the real recall key."
    return 3
  fi
  if [ "$pct" -ge "$WARN_AT_PCT" ]; then
    echo "  WARN — ${pct}% of budget. At ~7 new memories/day this goes red soon."
    return 0
  fi
  echo "  ok — inside budget, whole index reaches context."
  return 0
}

_self_test() {
  local t; t=$(mktemp -d); local rc=0
  # GREEN: a small index must pass.
  printf 'a%.0s' $(seq 1 100) > "$t/small.md"
  if _check "$t/small.md" >/dev/null 2>&1; then echo "  ok   green half: small index passes"
  else echo "  FAIL green half: small index did not pass"; rc=1; fi
  # RED: an oversized index must fail, or this checker is theatre.
  awk -v n=$((BUDGET_BYTES * 2)) 'BEGIN{for(i=0;i<n/50;i++) print "x-------------------------------------------------"}' > "$t/big.md"
  if _check "$t/big.md" >/dev/null 2>&1; then echo "  FAIL red half: oversized index PASSED — checker is broken"; rc=1
  else echo "  ok   red half: oversized index correctly goes red"; fi
  rm -rf "$t"
  [ $rc -eq 0 ] && echo "[memory-budget] self-test PASS" || echo "[memory-budget] self-test FAIL"
  return $rc
}

INDEX="${MEMORY_INDEX:-$HOME/.claude/projects/-Users-toc-Server-one-ie/memory/MEMORY.md}"
case "${1:-}" in
  --self-test) _self_test ;;
  --index)     _check "${2:?--index needs a path}" ;;
  *)           _check "$INDEX" ;;
esac
