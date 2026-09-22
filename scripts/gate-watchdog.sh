#!/usr/bin/env bash
# gate-watchdog.sh — break the one governor jam whose owners are both ALIVE.
#
# manifest: portable
#
# WHY (measured 2026-09-13: three times in ~35 minutes, 8-28 minutes each at 0%
# CPU, one of them a production release gate). The governor has two resources and
# two callers took them in opposite orders:
#
#   A: gate-run.sh(verify-fast) holds slot-1        ->  its child tsc-cached.sh
#                                                       waits for lock-tsc-one.ie_web
#   B: tsc-cached.sh holds lock-tsc-one.ie_web      ->  its inner gate-run.sh
#                                                       waits for a slot
#
# Two orders, one cycle. `gate-reaper.sh` and govern.ts's own `reapLock` reap a
# DEAD owner; both of these are alive, so nothing in the harness could see it.
# Every other session queues behind them and reads the wait as a hang.
#
# The code fix is SLOT-before-LOCK everywhere (tsc-cached.sh + do-reconcile.sh,
# proved by `govern-order-check.sh`). This script is the operational half: a
# worktree only carries that fix once it rebases, and until every tree on the box
# has it, one inverted participant re-forms the cycle.
#
# ── WHICH PROCESS IT CUTS, AND WHY THAT ONE ─────────────────────────────────
# The cycle always has exactly ONE process on the wrong side: a lock holder that
# holds NO slot. Cut it and the lock lands on a waiter that already holds a slot,
# which can then finish and release everything. Measured the same day: three
# standalone holders killed in sequence (the lock passing to the next standalone
# each time), then it landed on an in-gate owner and tsc ran at 121% CPU.
#
# It NEVER cuts a slot owner. The scratchpad draft did, as a fallback when no
# standalone holder was found; that throws away a whole verify run on the exact
# evidence that says the cycle is NOT the one described above. No proven cycle,
# no cut — the jam is reported and a human decides.
#
# ── THE PREDICATE IS POSITIVE EVIDENCE, NOT ABSENCE ─────────────────────────
# "Idle" is not "deadlocked". On a swapping box a real tsc blocked on page-ins
# sits at 0% CPU for minutes, and a watchdog that kills a slow-but-working gate
# is worse than no watchdog. So a victim must satisfy ALL of:
#
#   1. it owns a non-slot lock in GOVERN_DIR and is alive
#   2. it holds NO slot — no gate-run.sh in its ancestry, and its pid is in no
#      lock-slot-*/pid
#   3. it HAS a gate-run.sh descendant that holds no slot — so it is provably
#      inside the slot queue while holding the lock. This is the clause that
#      separates a deadlock from a process that is merely quiet
#   4. at least one slot is held by a live owner, and NO slot owner's subtree has
#      anything over CPU_FLOOR% — nobody with a slot is computing, so the queue
#      cannot drain on its own
#   5. a SLOT has been held for >= STALL_MIN minutes — read from the slot
#      DIRECTORY's mtime, which mkdir(2) stamps at acquisition and nothing writes
#      into afterwards. No in-process timer, so --once and the loop share one
#      clock and there is no state file
#   5b. and the victim's own lock is older than LOCK_MIN seconds, so a handoff is
#      never mistaken for a jam
#
# THE CLOCK IS THE SLOT, NOT THE LOCK, and that was measured the hard way. In the
# live jam of 2026-09-13 16:00Z the LOCK changed hands every ~9 minutes — each
# standalone holder was killed by its session's 600s Bash ceiling, released, and
# the next queued standalone took it, resetting the directory mtime. The jam
# itself ran >20 minutes; no single lock holding ever reached 10. A watchdog
# clocking the lock would have watched that jam forever and never fired.
# The slot is the thing that does not rotate: slot-1 was held by one pid,
# subtree idle, for the whole episode.
#
# Then it re-checks the whole predicate after CONFIRM_SECS and requires the SAME
# victim pid and the SAME lock mtime before cutting. A healthy box costs one ps.
#
# The floor's ceiling is set by the thing it prevents: gate-run.sh queues for
# GOVERN_QUEUE_WAIT (default 1800s) and then prints "no slot after 1800s —
# machine saturated" and exits 1, which tsc-cached reports as a FAILED typecheck
# that never ran. Acting at 10 minutes is acting before the false RED.
#
# Usage:  gate-watchdog.sh [--once] [--interval N] [--dry-run] [--self-test]
#   (no flags)  loop every --interval seconds (default 60) until interrupted
#   --once      one sweep, then exit — this is the session-start form
#   --dry-run   name the victim, cut nothing
#   --self-test drive both halves in a sandboxed GOVERN_DIR (see --self-test)
#
# Prints one line per finding; SILENT when there is nothing to do, so it is safe
# to run from a hook. Every environment knob: GATE_WATCHDOG_STALL_MIN,
# GATE_WATCHDOG_CPU_FLOOR, GATE_WATCHDOG_CONFIRM.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
G="${GOVERN_DIR:-${TMPDIR:-/tmp}/one-govern}"
STALL_MIN="${GATE_WATCHDOG_STALL_MIN:-10}"
LOCK_MIN="${GATE_WATCHDOG_LOCK_MIN:-60}"
CPU_FLOOR="${GATE_WATCHDOG_CPU_FLOOR:-20}"
CONFIRM_SECS="${GATE_WATCHDOG_CONFIRM:-3}"
ANCESTRY_MAX="${GATE_WATCHDOG_ANCESTRY_MAX:-16}"

ONCE=0; INTERVAL=60; DRY=0; SELFTEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --once)      ONCE=1 ;;
    --dry-run)   DRY=1 ;;
    --interval)  INTERVAL="${2:-60}"; shift ;;
    --self-test) SELFTEST=1 ;;
    # The whole header, not a line range: a range drifts silently every time the
    # measured account above grows, and --help then prints the middle of an
    # argument instead of the usage.
    -h|--help)   sed -n '2,/^set -uo pipefail$/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 0 ;;
    *) echo "gate-watchdog: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '[gate-watchdog] %s\n' "$*"; }

# ── the process table, read ONCE per sweep ──────────────────────────────────
# One snapshot answers every ancestry, descendant, liveness and CPU question, so
# the whole script is driven by a stubbed `ps` in --self-test, and a sweep cannot
# see two different machines halfway through. Liveness IS presence in this
# snapshot — `kill -0` would answer about a different instant.
PS_SNAP=""
_snap() { PS_SNAP="$(ps -Ao pid=,ppid=,pcpu=,command= 2>/dev/null)"; }

_ppid()  { awk -v p="$1" '$1==p {print $2; exit}' <<<"$PS_SNAP"; }
_pcpu()  { awk -v p="$1" '$1==p {print $3; exit}' <<<"$PS_SNAP"; }
_cmd()   { awk -v p="$1" '$1==p {for(i=4;i<=NF;i++) printf "%s ", $i; exit}' <<<"$PS_SNAP"; }
_alive() { [ -n "${1:-}" ] && [ -n "$(_ppid "$1")" ]; }
_kids()  { awk -v p="$1" '$2==p {print $1}' <<<"$PS_SNAP"; }

# Every descendant of $1, deepest first, so children die before their parent.
# DOWNWARD ONLY, never a process group: the victim's PARENT is a live Claude
# session's shell (measured — pid 13011's parent chain was zsh -> claude), and
# gate-reaper's `kill -TERM -pgid` would take the session with it.
_descendants() {
  local k
  for k in $(_kids "$1"); do _descendants "$k"; done
  printf '%s\n' "$1"
}

_ancestry_has_gate_run() {   # 0 = this pid sits under a gate-run.sh (holds a slot)
  local q="$1" i
  for i in $(seq 1 "$ANCESTRY_MAX"); do
    [ -n "$q" ] && [ "$q" != "1" ] && [ "$q" != "0" ] || return 1
    case "$(_cmd "$q")" in *gate-run.sh*) return 0 ;; esac
    q="$(_ppid "$q")"
  done
  return 1
}

_max_cpu_in_subtree() {      # highest %CPU anywhere under (and including) $1
  local p m=0 c
  for p in $(_descendants "$1"); do
    c="$(_pcpu "$p")"; [ -n "$c" ] || continue
    awk -v a="$c" -v b="$m" 'BEGIN { exit !(a > b) }' && m="$c"
  done
  printf '%s' "$m"
}

# ── the governor's two resources, as read off disk ──────────────────────────
_slot_pids() {               # pid of every slot dir that has one (alive or not)
  local d p
  for d in "$G"/lock-slot-*; do
    [ -f "$d/pid" ] || continue
    p="$(tr -d '[:space:]' < "$d/pid" 2>/dev/null)"
    [ -n "$p" ] && printf '%s\n' "$p"
  done
}

_holds_a_slot() { local p; for p in $(_slot_pids); do [ "$p" = "$1" ] && return 0; done; return 1; }

_lock_age_secs() {
  local m; m="$(stat -f '%m' "$1" 2>/dev/null)" || return 1
  [ -n "$m" ] || return 1
  printf '%s' "$(( $(date +%s) - m ))"
}

# ── find_victim — echoes "<pid> <lockdir> <mtime>", or nothing ──────────────
# Prints its reasoning to stderr under GATE_WATCHDOG_DEBUG=1; silent otherwise.
find_victim() {
  # NO ARRAYS. bash 3.2 is what macOS ships, and `${#arr[@]}` on an EMPTY array
  # under `set -u` is an unbound-variable error there — on the healthy-box path,
  # which is the one path that must never fail.
  local d p slot_owners="" so busy_slot=0 kids_gr n oldest=0 a
  _snap

  # (4a) at least one LIVE slot owner. No slot held => no queue => nothing to break.
  for so in $(_slot_pids); do _alive "$so" && slot_owners="$slot_owners $so"; done
  [ -n "${slot_owners// /}" ] || { _dbg "no live slot owner — not a jam"; return 1; }

  # (4b) nobody holding a slot is computing. A gate over the floor means the
  # queue IS draining, however slowly, and a cut would throw away live work.
  for so in $slot_owners; do
    n="$(_max_cpu_in_subtree "$so")"
    if awk -v a="$n" -v f="$CPU_FLOOR" 'BEGIN { exit !(a >= f) }'; then
      _dbg "slot owner $so busy at ${n}% — box is working, not jammed"; busy_slot=1; break
    fi
  done
  [ "$busy_slot" = "0" ] || return 1

  # (5) THE JAM'S OWN CLOCK. How long has a slot been held while nothing under it
  # computes? A legitimate gate is not idle for ten minutes — the full suite is
  # 87s and a 2.5GB tsc burns CPU throughout. See the header for why this is not
  # measured on the lock.
  for d in "$G"/lock-slot-*; do
    [ -f "$d/pid" ] || continue
    p="$(tr -d '[:space:]' < "$d/pid" 2>/dev/null)"
    _alive "$p" || continue
    a="$(_lock_age_secs "$d")" || continue
    [ "$a" -gt "$oldest" ] && oldest="$a"
  done
  if [ "$oldest" -lt $(( STALL_MIN * 60 )) ]; then
    _dbg "oldest held slot is ${oldest}s, under the ${STALL_MIN}m floor"; return 1
  fi

  for d in "$G"/lock-*; do
    case "$d" in *lock-slot-*) continue ;; esac
    [ -f "$d/pid" ] || continue
    p="$(tr -d '[:space:]' < "$d/pid" 2>/dev/null)"
    # (1) a live owner. A DEAD owner's lock is gate_sweep_stale's job, not ours.
    _alive "$p" || { _dbg "$(basename "$d"): owner ${p:-?} is dead — reaper's job"; continue; }
    # (2) it must hold NO slot. An in-gate holder is the INNOCENT side of the
    # cycle (SLOT then LOCK, the correct order) and cutting it costs a verify run.
    if _holds_a_slot "$p" || _ancestry_has_gate_run "$p"; then
      _dbg "$(basename "$d"): owner $p is inside a gate — innocent side"; continue
    fi
    # (3) POSITIVE EVIDENCE the cycle is closed: it has a gate-run.sh descendant
    # that holds no slot, i.e. it is queueing for a slot while holding the lock.
    kids_gr=""
    for n in $(_descendants "$p"); do
      [ "$n" = "$p" ] && continue
      case "$(_cmd "$n")" in *gate-run.sh*) _holds_a_slot "$n" || kids_gr="$n" ;; esac
    done
    [ -n "$kids_gr" ] || { _dbg "$(basename "$d"): owner $p is not in the slot queue — quiet, not deadlocked"; continue; }
    # (5b) don't race a handoff. The lock passes between standalone holders every
    # few minutes during a jam; a directory created two seconds ago names a
    # process that has not had time to be stuck.
    local age; age="$(_lock_age_secs "$d")" || continue
    if [ "$age" -lt "$LOCK_MIN" ]; then
      _dbg "$(basename "$d"): taken ${age}s ago — a handoff, not yet a jam"; continue
    fi
    printf '%s %s %s\n' "$p" "$d" "$(stat -f '%m' "$d" 2>/dev/null)"
    return 0
  done
  return 1
}

_dbg() { [ -n "${GATE_WATCHDOG_DEBUG:-}" ] && printf '[gate-watchdog] .. %s\n' "$*" >&2; return 0; }

cut_victim() {
  local vpid="$1" vlock="$2" p
  _snap
  for p in $(_descendants "$vpid"); do kill -TERM "$p" 2>/dev/null; done
  sleep 4
  _snap
  for p in $(_descendants "$vpid"); do kill -KILL "$p" 2>/dev/null; done
  # tsc-cached traps EXIT/TERM and releases its own lock; belt and braces for the
  # KILL path, where no trap runs. gate_sweep_stale reclaims a dead owner's lock.
  if [ -f "$ROOT/.claude/scripts/lib/govern.sh" ]; then
    bash -c ". '$ROOT/.claude/scripts/lib/govern.sh' >/dev/null 2>&1; gate_sweep_stale" >/dev/null 2>&1 || true
  fi
  [ -n "$vlock" ] && [ -d "$vlock" ] && rm -rf "$vlock" 2>/dev/null
  # The orphans a broken cycle leaves behind are gate-reaper's shape, not ours.
  # GATE_WATCHDOG_NO_REAP=1 holds it back, so --self-test never touches the real
  # process table while proving the cut.
  [ "${GATE_WATCHDOG_NO_REAP:-0}" = "1" ] \
    || bash "$ROOT/.claude/scripts/gate-reaper.sh" --once 2>/dev/null || true
  return 0
}

sweep() {
  local v vpid vlock vmt v2
  v="$(find_victim)" || return 0
  # find_victim ran in a command substitution, so ITS snapshot died with the
  # subshell. Take one here for the reporting and the kill walk.
  _snap
  vpid="$(awk '{print $1}' <<<"$v")"
  vlock="$(awk '{print $2}' <<<"$v")"
  vmt="$(awk '{print $3}' <<<"$v")"

  if [ "$DRY" = "1" ]; then
    say "WOULD cut pid=$vpid — holds $(basename "$vlock") ($(_lock_age_secs "$vlock")s) with NO slot while every slot has sat idle >= ${STALL_MIN}m: $(_cmd "$vpid" | cut -c1-70)"
    return 0
  fi

  # CONFIRM. A jam that resolves in three seconds was a queue, not a cycle.
  sleep "$CONFIRM_SECS"
  v2="$(find_victim)" || { say "jam cleared while confirming — cut nothing"; return 0; }
  if [ "$(awk '{print $1}' <<<"$v2")" != "$vpid" ] || [ "$(awk '{print $3}' <<<"$v2")" != "$vmt" ]; then
    say "jam moved while confirming (was pid=$vpid) — cut nothing"
    return 0
  fi

  say "BREAK — $(basename "$vlock") held by $vpid with NO slot ($(_lock_age_secs "$vlock")s) while every slot has been held and idle for >= ${STALL_MIN}m: $(_cmd "$vpid" | cut -c1-70)"
  cut_victim "$vpid" "$vlock"
  say "cut pid=$vpid, released $(basename "$vlock") — the lock now falls to a waiter that already holds a slot"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# --self-test — both halves, in a sandbox GOVERN_DIR that is never the machine's.
#
#   C1  a REAL planted deadlock is named, then cut, and the lock is released
#   C2  the victim's own parent shell SURVIVES the cut (downward-only walk)
#   C3  the sandbox's slot owner survives — a slot owner is never the victim
#   C4  healthy box (no slot held) — nothing named
#   C5  merely BUSY (a slot owner computing) — nothing named, even with a
#       textbook deadlock shape sitting next to it
#   C6  young jam (a slot held under the floor) — nothing named
#   C6b a fresh HANDOFF of the lock inside an old jam — nothing named
#   C7  the lock holder is itself in a gate — the innocent side, nothing named
#   C8  a quiet lock holder with NO queueing gate-run — nothing named
#   R1  RED PROOF: drop clause (3) and C8 must start naming the innocent
#   R2  RED PROOF: drop clause (4b) and C5 must start naming a working box
#   R3  RED PROOF: drop clause (5) and C6 must start naming a young queue
#   R4  RED PROOF: drop clause (2) and C7 must start naming the in-gate holder
#   H1  hooks/session-start.sh SAYS it broke a real planted jam — the silent
#       path is not the only one that can rot
# ─────────────────────────────────────────────────────────────────────────────
self_test() {
  local fails=0
  # SB is deliberately GLOBAL: the EXIT trap that removes it fires after this
  # function has returned, and a `local` SB is unbound by then — which under
  # `set -u` made a fully green run end on "SB: unbound variable".
  SB="$(mktemp -d "${TMPDIR:-/tmp}/gate-watchdog-check.XXXXXX")"
  trap 'rm -rf "$SB"' EXIT
  ok()  { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
  bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails + 1)); }

  local SELF="${BASH_SOURCE[0]}"
  # Declared up here, not inside C1's else-branch: a fixture that fails to plant
  # would otherwise leave it unset and `set -u` would take H1 down with it.
  local back; back="$(date -v-30M +%Y%m%d%H%M.%S 2>/dev/null || date -d '-30 min' +%Y%m%d%H%M.%S)"

  # ── the REAL half ──────────────────────────────────────────────────────────
  # A sandbox governor with one slot, held by a live dummy, and a planted
  # standalone holder of `lock-tsc-probe` whose inner gate-run.sh queues for that
  # slot forever. This is govern-order-check.sh's red-proof shape, stripped of
  # tsc: the deadlock, with no typecheck to pay for.
  echo "── C1-C3: a real planted deadlock ──"
  local gsb="$SB/govern"; mkdir -p "$gsb"
  ( sleep 120 ) & local slot_pid=$!
  mkdir -p "$gsb/lock-slot-1"; echo "$slot_pid" > "$gsb/lock-slot-1/pid"

  # The victim's PARENT — a stand-in for the Claude session's shell. It must
  # still be alive afterwards.
  local plant="$SB/plant.sh"
  cat > "$plant" <<PLANT
. "$ROOT/.claude/scripts/lib/govern.sh"
gate_lock tsc-probe 5 || exit 9
trap 'gate_release_all' EXIT INT TERM
bash "$ROOT/.claude/scripts/gate-run.sh" planted -- sleep 90
PLANT
  # The `sleep 300` is what makes C2 meaningful: this shell stands in for the
  # Claude session's zsh, and it must still be here after its child is cut. A
  # bare `( plant ) &` would exit WITH the plant and C2 would pass vacuously.
  GOVERN_DIR="$gsb" GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT=120 \
    bash -c "bash '$plant' & sleep 300" >"$SB/plant.log" 2>&1 &
  local parent_pid=$!

  # Wait for the plant to take the lock and for its gate-run to be queueing.
  local i victim=""
  for i in $(seq 1 40); do
    [ -f "$gsb/lock-tsc-probe/pid" ] && victim="$(tr -d '[:space:]' < "$gsb/lock-tsc-probe/pid")"
    [ -n "$victim" ] && pgrep -P "$victim" >/dev/null 2>&1 && break
    sleep 0.5
  done
  if [ -z "$victim" ]; then
    bad "C1 the plant never took the sandbox lock — fixture broken: $(cat "$SB/plant.log")"
  else
    # Backdate BOTH directories to clear the two floors — mkdir(2) stamped each
    # of them a moment ago. The slot carries the jam's clock; the lock only has
    # to be older than the handoff floor.
    touch -t "$back" "$gsb/lock-tsc-probe" "$gsb/lock-slot-1"
    local out
    out="$(GOVERN_DIR="$gsb" bash "$SELF" --once --dry-run 2>&1)"
    if grep -q "WOULD cut pid=$victim " <<<"$out"; then
      ok "C1a the planted standalone lock holder is NAMED ($victim)"
    else
      bad "C1a the deadlock was NOT seen. got: ${out:-<silence>}"
    fi
    out="$(GOVERN_DIR="$gsb" GATE_WATCHDOG_CONFIRM=1 GATE_WATCHDOG_NO_REAP=1 \
           bash "$SELF" --once 2>&1)"
    sleep 1
    if kill -0 "$victim" 2>/dev/null; then
      bad "C1b the victim survived the cut — the jam is still there. got: $out"
    else
      ok "C1b the victim is cut"
    fi
    if [ -d "$gsb/lock-tsc-probe" ]; then
      bad "C1c the lock was NOT released — cutting the holder bought nothing"
    else
      ok "C1c the lock is released — it can now fall to a waiter that holds a slot"
    fi
    if kill -0 "$parent_pid" 2>/dev/null; then
      ok "C2 the victim's PARENT shell survived (no process-group kill)"
    else
      bad "C2 the parent shell died — this would kill a Claude session"
    fi
    if kill -0 "$slot_pid" 2>/dev/null; then
      ok "C3 the slot owner survived — a slot owner is never the victim"
    else
      bad "C3 the SLOT OWNER was killed — that throws away a whole verify run"
    fi
  fi
  # The shell announces a terminated background job on ITS stderr, at `wait`.
  # Redirect the whole block, not each kill, or a green run ends in two lines of
  # "Terminated: 15" that read like a failure.
  { pkill -P "$parent_pid" 2>/dev/null
    kill -TERM "$parent_pid" "$slot_pid" 2>/dev/null
    wait "$parent_pid"; wait "$slot_pid"; } >/dev/null 2>&1

  # ── H1: the hook's jam path ────────────────────────────────────────────────
  # The SILENT path is easy to prove and easy to get wrong in the other
  # direction: a typo in session-start's grep anchor means the watchdog breaks
  # jams forever and nobody ever sees a line — the class of defect § 5 of
  # text/health-docs.md is entirely about. So plant a SECOND deadlock and drive
  # the real hook against it.
  #
  # The hook also runs gate-reaper.sh --once against the real process table.
  # That is exactly what every session start already does, it is ppid==1 + gate
  # shape + a 15-minute floor, and gate-reaper-check.sh proves it spares live
  # work — so it is left alone rather than stubbed.
  echo "── H1: hooks/session-start.sh reports a break ──"
  local hook="$ROOT/.claude/hooks/session-start.sh"
  if [ ! -f "$hook" ]; then
    bad "H1 session-start.sh is missing — the watchdog is wired to nothing"
  else
    local hsb="$SB/hookgov" hv="" h_parent h_slot hout
    mkdir -p "$hsb"
    ( sleep 120 ) & h_slot=$!
    mkdir -p "$hsb/lock-slot-1"; echo "$h_slot" > "$hsb/lock-slot-1/pid"
    GOVERN_DIR="$hsb" GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT=120 \
      bash -c "bash '$plant' & sleep 300" >"$SB/plant2.log" 2>&1 &
    h_parent=$!
    for i in $(seq 1 40); do
      [ -f "$hsb/lock-tsc-probe/pid" ] && hv="$(tr -d '[:space:]' < "$hsb/lock-tsc-probe/pid")"
      [ -n "$hv" ] && pgrep -P "$hv" >/dev/null 2>&1 && break
      sleep 0.5
    done
    if [ -z "$hv" ]; then
      bad "H1 the second plant never took the lock — fixture broken: $(cat "$SB/plant2.log")"
    else
      touch -t "$back" "$hsb/lock-tsc-probe" "$hsb/lock-slot-1"
      hout="$(CLAUDE_PROJECT_DIR="$ROOT" GOVERN_DIR="$hsb" GATE_WATCHDOG_CONFIRM=1 \
              GATE_WATCHDOG_NO_REAP=1 ONE_API_URL="http://127.0.0.1:1" \
              bash "$hook" 2>/dev/null)"
      grep -q "broke 1 governor deadlock" <<<"$hout" \
        && ok "H1 the hook SAYS it broke the jam — its grep anchor matches say()" \
        || bad "H1 the hook was SILENT about a real break — anchor drift. got: ${hout:-<silence>}"
    fi
    { pkill -P "$h_parent" 2>/dev/null
      kill -TERM "$h_parent" "$h_slot" 2>/dev/null
      wait "$h_parent"; wait "$h_slot"; } >/dev/null 2>&1
  fi

  # ── the MUST-NOT-CUT half, on fixtures ─────────────────────────────────────
  # A stubbed `ps` on PATH is the whole machine here, exactly as
  # gate-reaper-check.sh does it: no load is spawned and no real pid is read.
  echo "── C4-C8: shapes that must NEVER be cut ──"
  mkdir -p "$SB/bin"
  cat > "$SB/bin/ps" <<'PSSTUB'
#!/usr/bin/env bash
cat "$WATCHDOG_FIXTURE"
PSSTUB
  chmod +x "$SB/bin/ps"

  # <case> <dir> — build a sandbox governor + process table for one shape.
  fixture() {   # $1 name; stdin = the ps table; $2.. = "lockname:pid" entries
    local name="$1"; shift
    local dir="$SB/$name"; mkdir -p "$dir"
    cat > "$SB/$name.ps"
    local e n p
    for e in "$@"; do
      n="${e%%:*}"; p="${e##*:}"
      mkdir -p "$dir/$n"; printf '%s' "$p" > "$dir/$n/pid"
      touch -t "$(date -v-30M +%Y%m%d%H%M.%S 2>/dev/null || date -d '-30 min' +%Y%m%d%H%M.%S)" "$dir/$n"
    done
    printf '%s' "$dir"
  }
  run_fixture() { # $1 dir, $2 ps table, rest = extra env
    WATCHDOG_FIXTURE="$2" PATH="$SB/bin:$PATH" GOVERN_DIR="$1" \
      bash "${3:-$SELF}" --once --dry-run 2>&1
  }

  # The canonical jam, as a process table:
  #   900  gate-run.sh verify-fast   — holds slot-1, idle
  #   901    its child, idle
  #   800  tsc-cached.sh app/site  — holds lock-tsc-x, NO slot, idle
  #   801    gate-run.sh tsc-cache   — its child, queueing for a slot
  #   700  the session shell (parent of 800)
  local d out

  d="$(fixture c4 "lock-tsc-x:800" <<'T'
  700     1   0.0 /bin/zsh -c claude-session
  800   700   0.0 bash .claude/scripts/tsc-cached.sh app/site
  801   800   0.0 bash .claude/scripts/gate-run.sh tsc-cache:app/site -- bash -c tsc
T
)"
  out="$(run_fixture "$d" "$SB/c4.ps")"
  [ -z "$out" ] && ok "C4 healthy box (no slot held) — silent" \
                || bad "C4 named a victim with NO slot held: $out"

  d="$(fixture c5 "lock-slot-1:900" "lock-tsc-x:800" <<'T'
  700     1   0.0 /bin/zsh -c claude-session
  800   700   0.0 bash .claude/scripts/tsc-cached.sh app/site
  801   800   0.0 bash .claude/scripts/gate-run.sh tsc-cache:app/site -- bash -c tsc
  900     1   0.0 bash .claude/scripts/gate-run.sh verify-fast -- bash verify-fast.sh
  901   900  98.4 node vitest run
T
)"
  out="$(run_fixture "$d" "$SB/c5.ps")"
  [ -z "$out" ] && ok "C5 merely busy (a slot owner computing) — silent" \
                || bad "C5 would cut a gate while the box is WORKING: $out"

  d="$(fixture c6 "lock-slot-1:900" "lock-tsc-x:800" <<'T'
  700     1   0.0 /bin/zsh -c claude-session
  800   700   0.0 bash .claude/scripts/tsc-cached.sh app/site
  801   800   0.0 bash .claude/scripts/gate-run.sh tsc-cache:app/site -- bash -c tsc
  900     1   0.0 bash .claude/scripts/gate-run.sh verify-fast -- bash verify-fast.sh
T
)"
  touch "$d/lock-slot-1"    # the SLOT back to NOW — the jam is young
  out="$(run_fixture "$d" "$SB/c6.ps")"
  [ -z "$out" ] && ok "C6 young jam (slot held under the ${STALL_MIN}m floor) — silent" \
                || bad "C6 cut while the queue had barely started: $out"

  # C6b — the handoff. The jam is old, but THIS holder took the lock two seconds
  # ago. During the live 2026-09-13 jam the lock changed hands every ~9 minutes;
  # a holder that has not yet had time to be stuck is not the one to cut.
  d="$(fixture c6b "lock-slot-1:900" "lock-tsc-x:800" <<'T'
  700     1   0.0 /bin/zsh -c claude-session
  800   700   0.0 bash .claude/scripts/tsc-cached.sh app/site
  801   800   0.0 bash .claude/scripts/gate-run.sh tsc-cache:app/site -- bash -c tsc
  900     1   0.0 bash .claude/scripts/gate-run.sh verify-fast -- bash verify-fast.sh
T
)"
  touch "$d/lock-tsc-x"     # the LOCK back to NOW — a fresh handoff
  out="$(run_fixture "$d" "$SB/c6b.ps")"
  [ -z "$out" ] && ok "C6b a lock taken seconds ago (a handoff) — silent" \
                 || bad "C6b cut a holder that had just taken the lock: $out"

  d="$(fixture c7 "lock-slot-1:900" "lock-tsc-x:901" <<'T'
  900     1   0.0 bash .claude/scripts/gate-run.sh verify-fast -- bash verify-fast.sh
  901   900   0.0 bash .claude/scripts/tsc-cached.sh app/site
  902   901   0.0 bash .claude/scripts/gate-run.sh tsc-cache:app/site -- bash -c tsc
T
)"
  out="$(run_fixture "$d" "$SB/c7.ps")"
  [ -z "$out" ] && ok "C7 the in-gate lock holder (innocent side) — silent" \
                || bad "C7 would cut the SLOT-then-LOCK side, costing a verify run: $out"

  d="$(fixture c8 "lock-slot-1:900" "lock-tsc-x:800" <<'T'
  700     1   0.0 /bin/zsh -c claude-session
  800   700   0.0 bash .claude/scripts/tsc-cached.sh app/site
  900     1   0.0 bash .claude/scripts/gate-run.sh verify-fast -- bash verify-fast.sh
T
)"
  out="$(run_fixture "$d" "$SB/c8.ps")"
  [ -z "$out" ] && ok "C8 a quiet lock holder NOT in the slot queue — silent" \
                || bad "C8 cut a process that was merely quiet: $out"

  # ── RED PROOFS ─────────────────────────────────────────────────────────────
  echo "── R1-R4: the checks have teeth ──"
  local GUT1="$SB/gutted-clause3.sh"
  sed 's/^    \[ -n "\$kids_gr" \] ||.*$/    kids_gr="${kids_gr:-1}"/' "$SELF" > "$GUT1"
  if ! grep -q 'kids_gr="${kids_gr:-1}"' "$GUT1"; then
    bad "R1 could not gut clause (3) — the anchor moved and C8 is blind"
  else
    out="$(run_fixture "$SB/c8" "$SB/c8.ps" "$GUT1")"
    grep -q "WOULD cut pid=800 " <<<"$out" \
      && ok "R1 red-proof: without clause (3) the quiet holder IS cut, so C8 bites" \
      || bad "R1 the gutted watchdog still spared 800 — C8 proves nothing: ${out:-<silence>}"
  fi

  local GUT2="$SB/gutted-clause4b.sh"
  sed 's/^  \[ "\$busy_slot" = "0" \] || return 1$/  busy_slot=0/' "$SELF" > "$GUT2"
  if ! grep -q '^  busy_slot=0$' "$GUT2"; then
    bad "R2 could not gut clause (4b) — the anchor moved and C5 is blind"
  else
    out="$(run_fixture "$SB/c5" "$SB/c5.ps" "$GUT2")"
    grep -q "WOULD cut pid=800 " <<<"$out" \
      && ok "R2 red-proof: without clause (4b) a WORKING box is cut, so C5 bites" \
      || bad "R2 the gutted watchdog still spared a busy box — C5 proves nothing: ${out:-<silence>}"
  fi

  local GUT3="$SB/gutted-clause5.sh"
  sed '/^  if \[ "\$oldest" -lt/ s/.*/  if false; then/' "$SELF" > "$GUT3"
  if ! grep -q '^  if false; then$' "$GUT3"; then
    bad "R3 could not gut clause (5) — the anchor moved and C6 is blind"
  else
    out="$(run_fixture "$SB/c6" "$SB/c6.ps" "$GUT3")"
    grep -q "WOULD cut pid=800 " <<<"$out" \
      && ok "R3 red-proof: without the slot clock a JUST-STARTED queue is cut, so C6 bites" \
      || bad "R3 the gutted watchdog still spared a young jam — C6 proves nothing: ${out:-<silence>}"
  fi

  # R4 is the one that nearly went missing. C7's fixture has ONE non-slot lock,
  # so after clause (2) skips the in-gate holder the loop simply runs out of
  # candidates — C7 would stay green with clause (2) deleted, and clause (2) is
  # the whole of what stands between this watchdog and cutting a process inside
  # somebody's running verify. Gut it and C7 must start naming 901.
  local GUT4="$SB/gutted-clause2.sh"
  sed '/^    if _holds_a_slot "\$p" || _ancestry_has_gate_run "\$p"; then$/ s/.*/    if false; then/' "$SELF" > "$GUT4"
  if ! grep -q '^    if false; then$' "$GUT4"; then
    bad "R4 could not gut clause (2) — the anchor moved and C7 is blind"
  else
    out="$(run_fixture "$SB/c7" "$SB/c7.ps" "$GUT4")"
    grep -q "WOULD cut pid=901 " <<<"$out" \
      && ok "R4 red-proof: without clause (2) the IN-GATE holder is cut, so C7 bites" \
      || bad "R4 the gutted watchdog still spared 901 — C7 is vacuous and clause (2) is untested: ${out:-<silence>}"
  fi

  echo
  if [ "$fails" -eq 0 ]; then
    echo "ALL GREEN — it breaks the planted cycle and cuts nothing on a healthy, busy, young or innocent box"
    return 0
  fi
  echo "RED — $fails check(s) failed"
  return 1
}

if [ "$SELFTEST" = "1" ]; then self_test; exit $?; fi
if [ "$ONCE" = "1" ]; then sweep; exit 0; fi
while :; do sweep; sleep "$INTERVAL"; done
