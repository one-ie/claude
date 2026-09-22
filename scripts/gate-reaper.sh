#!/usr/bin/env bash
# gate-reaper.sh — reap ABANDONED gates, so a stalled fleet cannot poison the box.
#
# manifest: portable
#
# WHY (measured 2026-08-31). Two fleets were running and the box sat at load 138
# on 10 cores with swap at 4.3G of 5.1G. The cause was not the live work: four
# processes had been reparented to launchd (ppid=1) when their parent shell died
# and were still burning CPU — a `bun run verify` abandoned for 21 minutes, and a
# gate-run.sh abandoned for 9 minutes that was STILL HOLDING governor slot-3. A
# dead process holding a slot shrinks the effective gate cap until someone
# notices by hand; nothing in the harness noticed.
#
# gate_sweep_stale reclaims the LOCK a dead owner left behind. Nothing reclaimed
# the PROCESS. This does.
#
# Deliberately narrow. It kills a process only when ALL of:
#   1. ppid == 1            — genuinely reparented; its parent is gone
#   2. the command names THIS repo, or is a gate-run.sh / bun-run-verify shape
#   3. it has burned real CPU time — not merely idle and forgotten
# so a system daemon (WindowServer and coreaudiod are both ppid=1 and busy) can
# never match, and neither can a live fleet's gate, whose parent is alive.
#
# Usage:  gate-reaper.sh [--once] [--interval N] [--dry-run]
# Prints one line per reap; silent when there is nothing to do, so it is safe to
# run as a Monitor for the length of a session.
set -uo pipefail

INTERVAL=60
ONCE=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --once) ONCE=1 ;;
    --dry-run) DRY=1 ;;
    --interval) INTERVAL="${2:-60}"; shift ;;
    *) echo "gate-reaper: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Gate on ELAPSED age, not CPU. An abandoned `bun run verify` parent sits at 0s
# CPU while the children it spawned burn the box -- gating on the parent's own
# CPU skipped exactly the processes worth reaping (measured: pids 79192 and
# 84649, both 0s CPU, both abandoned). ppid=1 plus a gate shape is already
# conclusive: a live gate always has a live parent. The age floor only avoids
# racing a process that was reparented moments ago.
# 90s was too eager. A gate is reparented the moment its launching shell exits,
# and that happens to LIVE work -- the harness killing a Bash call at its timeout,
# or a backgrounded launch -- not only to abandoned work. Reaping a 96s-old gate
# that a fleet is still waiting on slows the plan down, which is the opposite of
# the point. Every genuinely dead gate found by hand was 7-22 MINUTES old, and
# the harness Bash ceiling is 600s, so a gate still orphaned past that is one
# nobody is coming back for.
MIN_AGE_SECS="${GATE_REAPER_MIN_AGE:-900}"

# Elapsed seconds, from `ps -o etime=` (MM:SS | HH:MM:SS | D-HH:MM:SS)
_age_secs() {
  printf '%s' "$1" | awk -F: '
    { d=0; s=$0
      if (s ~ /-/) { split(s, a, "-"); d=a[1]; s=a[2]; n=split(s, b, ":") }
      else n=split(s, b, ":")
      if (n==3) print int(d*86400 + b[1]*3600 + b[2]*60 + b[3])
      else if (n==2) print int(d*86400 + b[1]*60 + b[2])
      else print int(0+s) }'
}

sweep() {
  local pid ppid age cmd secs pgid n=0
  while read -r pid ppid age cmd; do
    [ "$ppid" = "1" ] || continue
    # Match the GATE SHAPE, never "mentions the repo". The first draft keyed on
    # the repo path and its dry run would have killed cc-connect, the Telegram
    # listener, a `claude daemon run` and Cursor's extension host -- all of them
    # legitimate long-lived daemons that are ppid=1 by design, exactly like an
    # abandoned gate. A reaper that cannot tell those apart is worse than no
    # reaper. Only these shapes are gates, and a gate is always short-lived:
    case "$cmd" in
      *gate-run.sh*) ;;
      *"vitest"*) ;;
      *"tsc --noEmit"*) ;;
      *"astro check"*) ;;
      *"run verify"*|*"run test"*|*"run typecheck"*) ;;
      # An `astro dev` / `wrangler dev` that dies leaves its workerd child behind,
      # reparented and holding ~40MB for as long as the box is up. FIVE of them
      # accumulated in one hour on 2026-09-05 (ages 33-63min, ~196MB) while both
      # this reaper and machine-check reported "orphans: none" -- neither knew the
      # shape, so nothing in the harness could see them. A LIVE workerd always has
      # a live parent (astro dev, or wrangler), so the ppid==1 test above already
      # spares it; the node_modules anchor keeps this to runtimes THIS tree spawned
      # and away from any workerd a user runs by hand.
      *node_modules*workerd" serve"*) ;;
      *) continue ;;
    esac
    # Belt and braces: never a daemon, an editor, or anything system-owned, even
    # if one of the words above appears somewhere in its argv.
    case "$cmd" in
      */System/*|/usr/sbin/*|/usr/libexec/*|*Applications*) continue ;;
      *cc-connect*|*tg-listen*|*"daemon run"*|*Cursor*|*Code\ Helper*) continue ;;
      *--watch*|*watchexec*|*nodemon*) continue ;;
    esac
    secs=$(_age_secs "$age")
    [ "${secs:-0}" -ge "$MIN_AGE_SECS" ] || continue
    pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ "$DRY" = "1" ]; then
      echo "[gate-reaper] WOULD reap pid=$pid pgid=${pgid:-?} age=${secs}s ${cmd:0:60}"
    else
      echo "[gate-reaper] reaped abandoned gate pid=$pid pgid=${pgid:-?} age=${secs}s ${cmd:0:60}"
      kill -TERM -"${pgid:-$pid}" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    fi
    n=$((n + 1))
  done < <(ps -Ao pid=,ppid=,etime=,command= 2>/dev/null)

  # A dead owner's lock shrinks the gate cap until someone contends. Reclaim it.
  if [ "$DRY" != "1" ] && [ -f "$REPO/.claude/scripts/lib/govern.sh" ]; then
    local reclaimed
    reclaimed=$(bash -c ". '$REPO/.claude/scripts/lib/govern.sh'; gate_sweep_stale; claim_sweep" 2>/dev/null | tr '\n' ' ')
    case "$reclaimed" in *[1-9]*) echo "[gate-reaper] reclaimed stale governor locks/claims: $reclaimed" ;; esac
  fi
  return 0
}

if [ "$ONCE" = "1" ]; then sweep; exit 0; fi
while :; do sweep; sleep "$INTERVAL"; done
