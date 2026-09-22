#!/usr/bin/env bash
# govern-order-check.sh — the governor's LOCK ORDER, proved by deadlocking it.
#
# manifest: needs-env
#
# THE DEFECT (measured 2026-09-13, three occurrences in ~35 minutes, each
# stalling every session on the box for 8-28 minutes at 0% CPU — one of them a
# production release gate):
#
#   tsc-cached.sh took the per-folder dedupe LOCK and then, still holding it,
#   queued for a governor SLOT.                             LOCK -> SLOT
#   Any caller already inside a gate has the opposite order: `bun run verify:fast`
#   IS `gate-run.sh verify-fast -- verify-fast.sh`, so it holds a SLOT, and its
#   child tsc-cached.sh then waits for the LOCK.            SLOT -> LOCK
#
#   A: gate-run(verify-fast) holds slot-1  ->  child tsc-cached waits for lock-tsc-one.ie_web
#   B: tsc-cached holds lock-tsc-one.ie_web ->  its inner gate-run waits for a slot
#
# Two orders, one cycle. Neither owner is DEAD, so nothing reaps it:
# `gate_lock`/`gate_slot` only reap an owner whose pid is gone (govern.ts
# `reapLock`), and gate-reaper.sh is the same predicate. Measured owner pairs:
# 22173/68920, then 15762/97557, then 87579.
#
# KILLING THE LOCK HOLDER DOES NOT FIX IT — observed twice. The lock is released
# and immediately taken by the next waiter, which is itself inside a gate holding
# a slot, and the cycle re-forms within seconds. Killing the SLOT holder is what
# breaks it, because that is the resource nobody else can produce.
#
# THE FIX this proves: SLOT before LOCK, everywhere. A cache HIT still takes
# neither.
#
# WHAT EACH HALF PROVES. The green half proves tsc-cached.sh is no longer an
# inverted participant. It does NOT prove the cycle is impossible — a synthetic
# LOCK -> SLOT holder still deadlocks a fixed tsc-cached, and that is exactly
# what the red half plants, so this checker is never green for lack of power.
# Both halves run in their own GOVERN_DIR: nothing here touches the machine's
# real governor, so a real gate in another session is never delayed or killed.
set -uo pipefail

_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$_HERE/../.." && pwd)"
GR="$_HERE/gate-run.sh"
TSC="$_HERE/tsc-cached.sh"

# A folder inside ROOT, because tsc_tree_fingerprint cd's to ROOT and resolves
# the folder relatively. Never one.ie/web: that is a real 2.5GB typecheck.
REL=".govern-order-probe"
P="$ROOT/$REL"
LOCKNAME="tsc-$(printf '%s' "$REL" | tr '/' '_')"

# Waits are SHORT and bounded on purpose: a deadlocked pair must expire by
# itself in under a minute, on a box where other sessions are running real
# gates. OBSERVE is when the verdict is read — long enough for both roles to
# have taken their ground, short enough to finish inside a Bash tool call.
WAIT="${GOVERN_ORDER_WAIT:-20}"
OBSERVE="${GOVERN_ORDER_OBSERVE:-10}"

bad=0
ok()   { echo "  ok: $*"; }
nope() { echo "  FAIL: $*"; bad=$((bad + 1)); }

probe_up() {
  rm -rf "$P"; mkdir -p "$P/src"
  printf '{ "compilerOptions": { "strict": true, "noEmit": true }, "include": ["src"] }\n' > "$P/tsconfig.json"
  printf 'export const x: number = 1;\n' > "$P/src/a.ts"
}
probe_down() { rm -rf "$P"; }

# _race <sandbox> <role-b-command...> — start the two roles in the two orders and
# read the state at OBSERVE seconds.
#
# Role A is always the REAL shape a session runs: gate-run holds a slot, and its
# child tsc-cached asks for the lock. The `sleep 3` is the whole determinism of
# this repro — it lets role B take its ground first, so the interleaving is
# fixed rather than raced.
#
# Echoes "done" (both roles exited) or "stalled <lock-owner> <slot-owner>".
_race() {
  local sb="$1"; shift
  local aout="$sb/a.log" bout="$sb/b.log" pa pb t

  ( GOVERN_DIR="$sb" GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT="$WAIT" \
    GOVERN_GATE_TIMEOUT=$((WAIT * 4)) TSC_CACHE_WAIT="$WAIT" TSC_CACHE_TIMEOUT="$WAIT" \
    TSC_CACHE_CMD='echo no-errors-here' \
    bash "$GR" role-a -- bash -c "sleep 3; bash '$TSC' '$REL'" ) >"$aout" 2>&1 &
  pa=$!
  sleep 2
  ( GOVERN_DIR="$sb" GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT="$WAIT" \
    GOVERN_GATE_TIMEOUT=$((WAIT * 4)) TSC_CACHE_WAIT="$WAIT" TSC_CACHE_TIMEOUT="$WAIT" \
    TSC_CACHE_CMD='echo no-errors-here' \
    "$@" ) >"$bout" 2>&1 &
  pb=$!

  t=0
  while [ "$t" -lt "$OBSERVE" ]; do
    kill -0 "$pa" 2>/dev/null || kill -0 "$pb" 2>/dev/null || break
    sleep 1; t=$((t + 1))
  done

  # The exit codes go to DISK, not to variables: _race is read through a command
  # substitution, so anything it assigns dies with the subshell.
  if ! kill -0 "$pa" 2>/dev/null && ! kill -0 "$pb" 2>/dev/null; then
    wait "$pa"; echo $? > "$sb/rc.a"; wait "$pb"; echo $? > "$sb/rc.b"
    echo "done"; return 0
  fi
  # Still alive at OBSERVE: name the two owners, then stop them. These are our
  # own children in our own sandbox — never another session's gate.
  local lo so
  lo=$(cat "$sb/lock-$LOCKNAME/pid" 2>/dev/null | tr -d '[:space:]')
  so=$(cat "$sb/lock-slot-1/pid" 2>/dev/null | tr -d '[:space:]')
  kill -TERM "$pa" "$pb" 2>/dev/null
  sleep 1
  kill -KILL "$pa" "$pb" 2>/dev/null
  wait "$pa" 2>/dev/null; wait "$pb" 2>/dev/null
  echo 99 > "$sb/rc.a"; echo 99 > "$sb/rc.b"
  echo "stalled lock=${lo:-none} slot=${so:-none}"
}

# ── 1. THE REAL PAIR — both roles are the shipped tsc-cached.sh ──────────────
real_pair() {
  echo "== the real pair — gate-run(slot)->tsc-cached(lock) vs bare tsc-cached"
  local sb r ra rb
  sb="$(mktemp -d)"; probe_up
  r=$(_race "$sb" bash "$TSC" "$REL")
  ra=$(cat "$sb/rc.a" 2>/dev/null); rb=$(cat "$sb/rc.b" 2>/dev/null)
  case "$r" in
    done)
      if [ "${ra:-1}" = "0" ] && [ "${rb:-1}" = "0" ]; then
        ok "both roles completed (rc 0/0) — tsc-cached takes the SLOT before the LOCK"
      else
        nope "both roles exited but not cleanly (a=${ra:-?} b=${rb:-?})
$(sed 's/^/          A| /' "$sb/a.log"; sed 's/^/          B| /' "$sb/b.log")"
      fi ;;
    stalled*)
      nope "DEADLOCK reproduced against this code — $r
          neither owner is dead, so nothing reaps it. This is the 2026-09-13 stall.
$(sed 's/^/          A| /' "$sb/a.log"; sed 's/^/          B| /' "$sb/b.log")" ;;
  esac
  probe_down; rm -rf "$sb"
}

# ── 2. RED PROOF — plant the pre-fix order and the SAME harness must stall ───
# Without this, a green section 1 could mean "the harness cannot see a deadlock".
# The planted role is tsc-cached.sh's own pre-2026-09-13 body in miniature: take
# the folder lock, then queue for a slot while holding it.
red_proof() {
  echo "== red proof — a planted LOCK->SLOT holder must still deadlock the pair"
  local sb r
  sb="$(mktemp -d)"; probe_up
  r=$(_race "$sb" bash -c ". '$_HERE/lib/govern.sh'
      gate_lock '$LOCKNAME' $WAIT || exit 9
      trap 'gate_release_all' EXIT INT TERM
      bash '$GR' planted -- echo computed")
  case "$r" in
    stalled*)
      ok "the inverted order still deadlocks and the harness sees it — $r" ;;
    done)
      nope "a planted LOCK->SLOT holder did NOT stall — this checker has no power,
          so section 1 going green proves nothing.
$(sed 's/^/          A| /' "$sb/a.log"; sed 's/^/          B| /' "$sb/b.log")" ;;
  esac
  probe_down; rm -rf "$sb"
}

# ── 3. A CACHE HIT COSTS NOTHING — no lock, no slot ─────────────────────────
# The memo lookup is what makes this cache worth having. If a HIT queued for a
# slot, every cheap verify-fast would join the same queue as a real typecheck —
# and land.sh's `--probe` (a lookup, never a compute) would be able to hang.
hit_is_free() {
  echo "== a cache HIT takes neither the lock nor a slot"
  local sb out n
  sb="$(mktemp -d)"; probe_up
  # compute once (this one legitimately takes a slot)
  GOVERN_DIR="$sb" GOVERN_MAX_GATES=1 TSC_CACHE_CMD='echo no-errors-here' \
    bash "$TSC" "$REL" >/dev/null 2>&1
  n=$(ls "$sb" 2>/dev/null | grep -c "^${LOCKNAME}\." | tr -d ' ')
  [ "${n:-0}" -ge 1 ] || nope "nothing was memoised — the rest of this section cannot bind"
  # Now a HIT, with the slots ALL taken. If it needs one, it cannot finish.
  mkdir -p "$sb/lock-slot-1"; echo $$ > "$sb/lock-slot-1/pid"
  out=$(GOVERN_DIR="$sb" GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT=6 TSC_CACHE_WAIT=6 \
        TSC_CACHE_CMD='echo no-errors-here' bash "$TSC" "$REL" 2>/dev/null)
  if [ "$(printf '%s' "$out" | tr -d '[:space:]')" = "0" ]; then
    ok "a HIT answers 0 with every slot held (it never queued)"
  else
    nope "a HIT could not answer with the slots held (got '${out:-}') — it is taking a slot"
  fi
  [ -d "$sb/lock-$LOCKNAME" ] && nope "a HIT left the folder lock behind — it took the lock" \
    || ok "a HIT took no folder lock"
  # --probe, the pure lookup land.sh uses, under the same starvation
  out=$(GOVERN_DIR="$sb" GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT=6 \
        bash "$TSC" --probe "$REL" 2>/dev/null)
  [ "$out" = "green" ] && ok "--probe answers green with every slot held" \
    || nope "--probe could not answer with the slots held (got '${out:-}')"
  probe_down; rm -rf "$sb"
}

echo "govern-order-check — SLOT before LOCK, proved by deadlocking it"
real_pair
red_proof
hit_is_free
[ "$bad" -eq 0 ] && { echo "govern-order: PASS"; exit 0; }
echo "govern-order: FAILED ($bad)"; exit 1
