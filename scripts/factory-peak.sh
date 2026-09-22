#!/usr/bin/env bash
# factory-peak.sh — the resident price of a running tree, measured.
#
# manifest: portable
#
# WHAT IT IS. Width is an assumption until something reads the bill.
# factory-width.sh DIVIDES the free memory by an assumed price per cycle; this
# script MEASURES that price. Point it at the root pid of anything that forks —
# a parked preview server, a gate, a fleet worktree — and it samples the
# resident set of the whole process TREE until the job ends or the clock runs
# out, then prints the peak.
#
#   bash .claude/scripts/factory-peak.sh --pid 12163 --seconds 30
#   bash .claude/scripts/factory-peak.sh --pid "$!" --until /tmp/run.done --interval 5
#   bash .claude/scripts/factory-peak.sh --self-test
#
# Output — one line per sample, then the verdict:
#
#   t=0 procs=4 rss_mb=91
#   t=2 procs=4 rss_mb=104
#   PEAK rss_mb=104 at t=2 procs=4
#
# WHAT THE NUMBER IS. The SUM of every process's RSS in the tree. RSS
# double-counts pages that processes share — a node parent and its workerd child
# share libraries and mapped files — so the figure is an UPPER BOUND on what the
# tree costs the box. That is the conservative direction for a budget, and it is
# the same rough arithmetic gate_headroom already prices a cycle with.
#
# RSS IS A LIVE QUANTITY, NOT A CONSTANT. The OS reclaims and compresses idle
# anonymous pages, so an idle tree's resident set DECAYS while you watch it: the
# same parked preview server, untouched, read PEAK 138 MB in one 30s window and
# 87 MB in another. Neither is wrong — a peak is what the tree held while it was
# watched. Price a cycle from a window in which the tree is DOING the work being
# priced, and read an idle tree's number as its floor, not its cost under load.
#
# THE TREE. Descendants via `pgrep -P`, walked breadth-first with a seen-set and
# a depth cap (a live tree reshapes between levels; a pid must be counted once).
# If the root pid is its own process-group leader, the group's other members are
# added too (mode=children+pgid). When it is NOT — a server forked by a wrapper
# shell inherits the WRAPPER's group — that group belongs to somebody else and is
# left alone (mode=children). The mode is printed, so the number is interpretable.
#
# FAILS CLOSED. A tree that is not there is never a cheap tree:
#
#   exit 2   the root pid is not alive at start      nothing was measured
#   exit 3   the root exited mid-run                 TRUNCATED, peak still printed
#   exit 4   every sample read 0 MB                  the sampler is broken, not the tree free
#   exit 5   --self-test failed
#
# `PEAK rss_mb=0` is never printed as a pass — that is the benign default this
# instrument exists to refuse.
set -uo pipefail

PID=""
INTERVAL=2
UNTIL_FILE=""
SECONDS_CAP=""
DO_SELFTEST=0
MAX_DEPTH=6
HARD_CAP="${FACTORY_PEAK_HARD_CAP:-3600}"

die() { printf '%s\n' "$*" >&2; }

usage() {
  die "usage: factory-peak.sh --pid <root pid> [--interval 2] [--until <file>|--seconds N]"
  die "       factory-peak.sh --self-test"
}

# RED-PROOF SEAM — --self-test's red half neuters exactly this line and asserts
# the green half then fails. Keep it a one-liner.
_children() { pgrep -P "$1" 2>/dev/null; }

_alive() { kill -0 "$1" 2>/dev/null; }

# Every descendant of $1, breadth-first, each pid once, depth-capped.
_tree_pids() {
  local root="$1" seen=" $1 " d=0 p c
  local -a frontier=("$root") next=()
  printf '%s\n' "$root"
  while [ "${#frontier[@]}" -gt 0 ] && [ "$d" -lt "$MAX_DEPTH" ]; do
    next=()
    for p in "${frontier[@]}"; do
      while read -r c; do
        [ -n "$c" ] || continue
        case "$seen" in *" $c "*) continue ;; esac
        seen="$seen$c "
        printf '%s\n' "$c"
        next+=("$c")
      done < <(_children "$p")
    done
    frontier=(${next[@]+"${next[@]}"})
    d=$((d + 1))
  done
}

# echoes "<rss_mb> <procs>"; 0 0 when nothing in the tree answered.
_sample() {
  local pids list
  pids="$(_tree_pids "$PID" | sort -un)"
  if [ "$MODE" = "children+pgid" ]; then
    pids="$(printf '%s\n%s\n' "$pids" \
      "$(ps -axo pid=,pgid= | awk -v g="$PID" '$2 == g { print $1 }')" | sort -un)"
  fi
  list="$(printf '%s' "$pids" | tr '\n' ',' | sed 's/,$//')"
  [ -n "$list" ] && [ "$list" != "," ] || { printf '0 0\n'; return; }
  ps -o rss= -p "$list" 2>/dev/null \
    | awk '{ s += $1; n++ } END { printf "%d %d\n", s / 1024, n }'
}

measure() {
  local start now t mb n samples=0 truncated=0
  local peak=0 peak_t=0 peak_n=0

  _alive "$PID" || { die "root pid $PID is not alive — nothing to measure"; return 2; }

  MODE=children
  local rpgid
  rpgid="$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ')"
  [ -n "$rpgid" ] && [ "$rpgid" = "$PID" ] && MODE="children+pgid"
  printf '# pid=%s mode=%s interval=%s%s%s\n' "$PID" "$MODE" "$INTERVAL" \
    "${SECONDS_CAP:+ seconds=$SECONDS_CAP}" "${UNTIL_FILE:+ until=$UNTIL_FILE}"

  start="$(date +%s)"
  while :; do
    now="$(date +%s)"; t=$((now - start))
    if ! _alive "$PID"; then
      truncated=1
      die "# root pid $PID exited at t=${t}s — the tree is gone"
      break
    fi
    read -r mb n <<EOS
$(_sample)
EOS
    printf 't=%s procs=%s rss_mb=%s\n' "$t" "$n" "$mb"
    samples=$((samples + 1))
    if [ "$mb" -gt "$peak" ]; then peak="$mb"; peak_t="$t"; peak_n="$n"; fi

    if [ -n "$UNTIL_FILE" ] && [ -e "$UNTIL_FILE" ]; then break; fi
    if [ -n "$SECONDS_CAP" ] && [ "$t" -ge "$SECONDS_CAP" ]; then break; fi
    if [ "$t" -ge "$HARD_CAP" ]; then break; fi
    sleep "$INTERVAL"
  done

  if [ "$samples" -eq 0 ]; then
    die "no sample was taken — root pid $PID died before the first read"
    return 3
  fi
  if [ "$peak" -le 0 ]; then
    die "every one of $samples sample(s) read 0 MB — the sampler could not see the tree,"
    die "which is not the same as the tree being free. Refusing to print a peak."
    return 4
  fi
  printf 'PEAK rss_mb=%s at t=%s procs=%s\n' "$peak" "$peak_t" "$peak_n"
  if [ "$truncated" -eq 1 ]; then
    printf 'TRUNCATED — the root exited before the window closed; the peak is a lower bound\n'
    return 3
  fi
  return 0
}

# ---------------------------------------------------------------------------
# --self-test: a tree whose allocation is KNOWN, then the red half.
# ---------------------------------------------------------------------------
self_test() {
  local rt alloc_mb=50 base_mb expected measured delta rc
  local tmpdir child root out

  command -v python3 >/dev/null 2>&1 || {
    die "SELF-TEST unrun — no python3 on this box to build a known tree"
    return 5
  }
  rt=python3

  tmpdir="$(mktemp -d -t factory-peak)" || { die "SELF-TEST unrun — mktemp failed"; return 5; }
  child="$tmpdir/hold.py"
  # The child must KEEP its pages hot, not merely allocate them. macOS compresses
  # idle anonymous pages: a bytearray touched once and then slept on falls out of
  # the resident set within seconds (measured — a 133MB tree read 20MB at t=3s),
  # so a self-test that allocates and sleeps asserts against a number the OS has
  # already taken back. Re-touching every page is what makes the allocation a
  # thing the sampler can be held to.
  cat > "$child" <<PY
import time
b = bytearray(${alloc_mb} * 1024 * 1024)
end = time.time() + 25
while time.time() < end:
    for i in range(0, len(b), 4096):
        b[i] = 1                  # keep every page RESIDENT, not just allocated
    time.sleep(0.05)
PY

  # Baseline: what one interpreter costs holding nothing. Measured, never guessed —
  # it is what makes the 30% tolerance mean something.
  "$rt" -c 'import time; time.sleep(6)' &
  local bpid=$!
  sleep 2
  base_mb="$(ps -o rss= -p "$bpid" 2>/dev/null | awk '{ printf "%d", $1 / 1024 }')"
  kill "$bpid" 2>/dev/null; wait "$bpid" 2>/dev/null
  case "${base_mb:-}" in ''|*[!0-9]*) base_mb=0 ;; esac
  if [ "$base_mb" -le 0 ]; then
    die "SELF-TEST unrun — could not read the baseline interpreter's RSS"
    rm -rf "$tmpdir"; return 5
  fi

  # The known tree: one sh, two children each holding alloc_mb resident.
  sh -c "\"$rt\" \"$child\" & \"$rt\" \"$child\" & wait" &
  root=$!
  sleep 2   # let both children reach the plateau

  out="$(PID="$root" INTERVAL=1 SECONDS_CAP=8 UNTIL_FILE="" measure 2>&1)"
  rc=$?
  kill -- -"$root" 2>/dev/null
  pkill -P "$root" 2>/dev/null
  kill "$root" 2>/dev/null
  wait "$root" 2>/dev/null
  rm -rf "$tmpdir"

  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out"
    die "SELF-TEST FAIL — the sampler exited $rc against a known-live tree"
    return 5
  fi
  measured="$(printf '%s\n' "$out" | awk -F'rss_mb=' '/^PEAK /{ split($2, a, " "); print a[1] }')"
  case "${measured:-}" in ''|*[!0-9]*)
    printf '%s\n' "$out"
    die "SELF-TEST FAIL — no PEAK line to read"
    return 5 ;;
  esac

  # The KNOWN quantity is the allocation: 2 x alloc_mb, page-touched, resident.
  # The interpreter baseline is measured, but it is the unstable term (it swings
  # with how far the interpreter has loaded when it is sampled), so it is never
  # allowed into the FLOOR — only into the ceiling, as headroom. Asserting the
  # symmetric "expected = 2*alloc + 2*baseline" would put a term that moves 36%
  # between runs inside a 30% budget.
  local known floor ceiling
  known=$(( 2 * alloc_mb ))
  floor=$(( known * 70 / 100 ))
  ceiling=$(( known * 130 / 100 + 2 * base_mb ))
  delta="$(awk -v m="$measured" -v k="$known" 'BEGIN { printf "%+.1f", (m - k) * 100 / k }')"
  printf 'SELF-TEST known=%sMB (2x%s alloc) measured=%sMB delta=%s%% window=[%s,%s] (ceiling carries 2x%s baseline)\n' \
    "$known" "$alloc_mb" "$measured" "$delta" "$floor" "$ceiling" "$base_mb"
  if [ "$measured" -lt "$floor" ] || [ "$measured" -gt "$ceiling" ]; then
    die "SELF-TEST FAIL — measured peak ${measured}MB is outside [${floor},${ceiling}] for a known ${known}MB allocation"
    return 5
  fi
  printf 'SELF-TEST green half ok — tree measured within 30%% of a known allocation\n'

  # --- red half: gut the recursion, assert the green half then goes RED --------
  if [ "${FACTORY_PEAK_NO_RED:-0}" = "1" ]; then return 0; fi
  local gutted
  gutted="$(mktemp -t factory-peak-red)" || { die "SELF-TEST unrun — mktemp failed"; return 5; }
  sed 's/^_children() { pgrep -P "\$1" 2>\/dev\/null; }$/_children() { :; }/' "$0" > "$gutted"
  if ! grep -q '^_children() { :; }$' "$gutted"; then
    rm -f "$gutted"
    die "SELF-TEST unrun — could not neuter the recursion seam; the red proof did not run"
    return 5
  fi
  FACTORY_PEAK_NO_RED=1 bash "$gutted" --self-test >/dev/null 2>&1
  rc=$?
  rm -f "$gutted"
  if [ "$rc" -eq 0 ]; then
    die "SELF-TEST FAIL — a copy with the child recursion REMOVED still passed."
    die "The green half proves nothing; it is not reading the tree."
    return 5
  fi
  printf 'SELF-TEST red-proof ok — recursion removed => exit %s (root only, tree unseen)\n' "$rc"
  printf 'SELF-TEST PASS\n'
  return 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pid)       PID="${2:-}"; shift 2 ;;
    --interval)  INTERVAL="${2:-}"; shift 2 ;;
    --until)     UNTIL_FILE="${2:-}"; shift 2 ;;
    --seconds)   SECONDS_CAP="${2:-}"; shift 2 ;;
    --self-test) DO_SELFTEST=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           die "unknown argument: $1"; usage; exit 64 ;;
  esac
done

if [ "$DO_SELFTEST" -eq 1 ]; then
  self_test
  exit $?
fi

case "${PID:-}" in
  ''|*[!0-9]*) usage; exit 64 ;;
esac
case "$INTERVAL" in ''|*[!0-9]*) die "--interval must be whole seconds"; exit 64 ;; esac
[ "$INTERVAL" -lt 1 ] && INTERVAL=1
if [ -n "$SECONDS_CAP" ]; then
  case "$SECONDS_CAP" in *[!0-9]*) die "--seconds must be a whole number"; exit 64 ;; esac
fi
# Neither stop condition given: bound the run rather than sample forever.
[ -z "$SECONDS_CAP" ] && [ -z "$UNTIL_FILE" ] && SECONDS_CAP=30

measure
exit $?
