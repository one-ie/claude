#!/usr/bin/env bash
# tsc-cached.sh <folder> — run `tsc --noEmit` for <folder>, or reuse the answer
# tsc-cached.sh --probe <folder> — answer from the memo ONLY: prints `green` (exit 0)
#   when this exact tree already passed, `unknown` (exit 1) otherwise. Never
#   computes, never locks, never takes a slot. This is how land.sh learns what a
#   branch knew about itself BEFORE the trunk was merged in, and whether dev's own
#   tree is on record as green — the two facts that turn "fast gate RED" into an
#   attribution (root CLAUDE.md § The dev → prod loop › three owners).
# TSC_CACHE_ROOT=<dir> fingerprints THAT checkout instead of the one this script
#   lives in. Every door script runs MAIN's copy (a worktree's copy resolves ROOT
#   to the worktree and lands nothing), so main's copy needs a way to ask about a
#   worktree. The key is content, so the memo is shared across checkouts anyway.
# someone else already computed for this exact tree. Prints the error COUNT.
#
# manifest: needs-env
#
# WHY. do-reconcile.sh solved this in 2026-08: one tsc per (folder,
# tree-fingerprint), everyone else reuses it, so six identical runs collapse to
# one compute and five cache hits. verify-fast.sh never used that cache, so every
# /do cycle paid full price for a typecheck of a tree that had not changed since
# the last cycle typechecked it. The cache KEY FORMAT here is byte-identical to
# do-reconcile's on purpose: they share entries, so a reconcile and N cycle gates
# on one tree cost exactly one tsc between them.
#
# CRITICAL, inherited from do-reconcile: the fingerprint must cover everything
# tsc READS, not just the folder being checked. one.ie/web resolves @oneie/sdk
# types out of packages/sdk/dist, and its tests cross into channels/. A
# fingerprint scoped to the folder alone would miss an SDK edit and hand back a
# cached PASS for a tree that no longer type-checks -- a green gate over a red
# tree, which is the one thing this harness exists to prevent.
#
# TSC_CACHE_DISABLE=1 forces a real run (and still records the result).
#
# ── SLOT BEFORE LOCK — the 2026-09-13 deadlock ──────────────────────────────
# This script used to take the per-folder dedupe LOCK and then, still holding
# it, queue for a governor SLOT. Any caller already inside a gate arrives in the
# opposite order: `bun run verify:fast` IS `gate-run.sh verify-fast -- …`, so it
# holds a SLOT and its child here waits for the LOCK. Two orders, one cycle:
#
#   A: gate-run(verify-fast) holds slot-1   ->  its tsc-cached waits for lock-tsc-one.ie_web
#   B: tsc-cached holds lock-tsc-one.ie_web ->  its inner gate-run waits for a slot
#
# Measured three times in ~35 minutes on 2026-09-13, each stalling EVERY session
# on the box for 8-28 minutes at 0% CPU — one of them a production release gate.
# Owner pairs: 22173/68920, 15762/97557, 87579. Nothing reaps it: both owners are
# alive, and `reapLock`/gate-reaper only reap a DEAD owner.
#
# KILLING THE LOCK HOLDER DOES NOT FIX IT (observed twice): the lock passes
# straight to the next waiter, which is itself inside a gate holding a slot, and
# the cycle re-forms within seconds. Killing the SLOT holder is what breaks it.
#
# So the order is now global: SLOT, then LOCK, never the reverse. A cache HIT
# and `--probe` still take NEITHER — a memo lookup must never join a queue.
# Proof, both halves: `bash .claude/scripts/govern-order-check.sh`.
# do-reconcile.sh takes the SAME lock name and carries the same fix; one
# inverted participant is enough to re-form the cycle.
set -uo pipefail

# --self-test — the RED half. A cache that has never been seen to refuse is not
# known to refuse. Builds a throwaway package with a real type error and proves:
# a red count is never memoised, a red tree never replays as a HIT, and a tsc that
# could not finish exits non-zero instead of reporting "0 errors".
if [ "${1:-}" = "--self-test" ]; then
  _ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  _P="$_ROOT/.tsc-cache-probe"
  fails=0
  export GOVERN_DIR="$(mktemp -d)"
  rm -rf "$_P"; mkdir -p "$_P/src"
  cat > "$_P/tsconfig.json" <<'EOF'
{ "compilerOptions": { "strict": true, "noEmit": true, "skipLibCheck": true }, "include": ["src"] }
EOF
  echo 'export const x: number = "not a number";' > "$_P/src/a.ts"
  n1=$(bash "$0" .tsc-cache-probe 2>/dev/null)
  if [ "${n1:-0}" -gt 0 ] 2>/dev/null; then echo "ok: a type error is reported ($n1)"
  else echo "FAIL: type error not reported (got '$n1')"; fails=$((fails+1)); fi
  out2=$(bash "$0" .tsc-cache-probe 2>&1 >/dev/null)
  case "$out2" in *"cache HIT"*) echo "FAIL: a RED count replayed as a cache HIT"; fails=$((fails+1));;
    *) echo "ok: a red tree is re-run, never replayed";; esac
  if ls "$GOVERN_DIR"/tsc-_tsc-cache-probe.* >/dev/null 2>&1; then
    echo "FAIL: a red count was written to the cache"; fails=$((fails+1))
  else echo "ok: no cache entry written for a red tree"; fi
  # green half — a pass IS memoised
  echo 'export const x: number = 1;' > "$_P/src/a.ts"
  n3=$(bash "$0" .tsc-cache-probe 2>/dev/null)
  [ "$n3" = "0" ] && echo "ok: clean tree reports 0" || { echo "FAIL: clean tree reported '$n3'"; fails=$((fails+1)); }
  out4=$(bash "$0" .tsc-cache-probe 2>&1 >/dev/null)
  case "$out4" in *"cache HIT"*) echo "ok: a PASS is memoised";;
    *) echo "FAIL: identical clean tree did not HIT"; fails=$((fails+1));; esac
  # THE KEY IS CONTENT, NOT MTIME — both halves, because a constant key would
  # pass every check above (red is never cached, so red-then-green-then-HIT
  # proves nothing about the key moving). Measured 2026-09-04: the first cut of
  # the content key hashed EMPTY input under zsh word-splitting and every check
  # above stayed green. A checker that cannot go red has no demonstrated power.
  touch "$_P/src/a.ts"                                   # mtime moves, bytes do not
  out5=$(bash "$0" .tsc-cache-probe 2>&1 >/dev/null)
  case "$out5" in *"cache HIT"*) echo "ok: an mtime-only change still HITs (key is content)";;
    *) echo "FAIL: a touch invalidated the memo — the key is reading mtime"; fails=$((fails+1));; esac
  echo '{"wave":"W2"}' > "$_P/.w2-spec.json"             # a cycle receipt, not a tsc input
  out5b=$(bash "$0" .tsc-cache-probe 2>&1 >/dev/null)
  case "$out5b" in *"cache HIT"*) echo "ok: a dot-file receipt does not move the key";;
    *) echo "FAIL: .w2-spec.json invalidated the memo — the key reads cycle receipts"; fails=$((fails+1));; esac
  echo 'export const x: number = 2;' > "$_P/src/a.ts"   # bytes move, still green
  out6=$(bash "$0" .tsc-cache-probe 2>&1 >/dev/null)
  case "$out6" in *"cache HIT"*) echo "FAIL: a content change replayed as a HIT — the key does not read the bytes"; fails=$((fails+1));;
    *) echo "ok: a content change MISSes (key covers the bytes)";; esac
  # --probe answers from the memo and NEVER computes. The tree is green and
  # memoised here (out6 computed it); a probe must say so. Then break it: a
  # never-checked tree must read `unknown`, exit 1, and leave no stamp behind —
  # a probe that computed would stamp the green half and hide the cost it exists
  # to avoid; a probe that said `green` for an unchecked tree would let land.sh
  # call a branch "green alone" on no evidence.
  if pr=$(bash "$0" --probe .tsc-cache-probe 2>/dev/null) && [ "$pr" = "green" ]; then echo "ok: --probe reads the memoised PASS as green"
  else echo "FAIL: --probe missed a memoised PASS (got '${pr:-}')"; fails=$((fails+1)); fi
  echo 'export const y: string = 1;' > "$_P/src/b.ts"     # red, and never checked
  _stamps_before=$(ls "$GOVERN_DIR" | wc -l | tr -d ' ')
  if pr=$(bash "$0" --probe .tsc-cache-probe 2>/dev/null); then echo "FAIL: --probe reported '$pr' for a tree never checked"; fails=$((fails+1))
  elif [ "$pr" != "unknown" ]; then echo "FAIL: --probe exit 1 but said '$pr', not 'unknown'"; fails=$((fails+1))
  else echo "ok: --probe says unknown for an unchecked tree"; fi
  _stamps_after=$(ls "$GOVERN_DIR" | wc -l | tr -d ' ')
  [ "$_stamps_before" = "$_stamps_after" ] && echo "ok: --probe wrote nothing" \
    || { echo "FAIL: --probe left a stamp ($_stamps_before -> $_stamps_after) — it computed"; fails=$((fails+1)); }
  rm -f "$_P/src/b.ts"
  # TSC_CACHE_ROOT: the same bytes in ANOTHER checkout share the memo. This is
  # the property land.sh leans on — main's copy asking about a worktree's tree.
  _C="$(mktemp -d)"; cp -R "$_P" "$_C/.tsc-cache-probe"
  if pr=$(TSC_CACHE_ROOT="$_C" bash "$0" --probe .tsc-cache-probe 2>/dev/null) && [ "$pr" = "green" ]; then
    echo "ok: TSC_CACHE_ROOT reads the same memo for identical bytes in another checkout"
  else echo "FAIL: TSC_CACHE_ROOT did not share the memo (got '${pr:-}')"; fails=$((fails+1)); fi
  rm -rf "$_C"
  # RED PROOF — an unrun tsc must NOT read as 0 errors. A child that cannot
  # finish inside the bound is killed by run_bounded, leaving the count file
  # EMPTY -- exactly the shape a real 600s timeout produces. The old
  # `n=${n:-0}` turned that empty file into "0 errors" AND cached it, so a
  # typecheck that never ran was replayed forever as a PASS.
  rm -rf "$GOVERN_DIR"; export GOVERN_DIR="$(mktemp -d)"
  if out7=$(TSC_CACHE_TIMEOUT=1 TSC_CACHE_CMD='sleep 30' bash "$0" .tsc-cache-probe 2>&1 >/dev/null); then
    echo "FAIL: a timed-out tsc exited 0 — an unrun gate read as a pass"; fails=$((fails+1))
  else echo "ok: a tsc that could not finish exits non-zero"; fi
  # AND it must be the EMPTY-COUNT branch that refused, not merely some non-zero
  # exit. Since 2026-09-13 the compute runs inside a slot this script bought
  # itself, so there are now TWO bounds — the inner run_bounded and gate-run's
  # outer one — and if the outer ever fires first, the count file is never even
  # read and this red proof silently degrades into "the outer bound works".
  # Pinned by the message the inner branch prints.
  case "$out7" in *"no error count"*) echo "ok: the refusal came from the empty-count branch" ;;
    *) echo "FAIL: a timed-out tsc did not reach the empty-count branch — got: ${out7:-<nothing>}"; fails=$((fails+1)) ;; esac
  rm -rf "$_P" "$GOVERN_DIR"
  [ "$fails" -eq 0 ] && { echo "tsc-cached: self-test PASS"; exit 0; }
  echo "tsc-cached: self-test FAILED ($fails)"; exit 1
fi

PROBE=0 LOCKED=0 folder=""
for _a in "$@"; do
  case "$_a" in
    --probe) PROBE=1 ;;
    # INTERNAL. Set only by this script's own re-invocation through gate-run.sh
    # (see § SLOT BEFORE LOCK): "a slot is held — take the lock and compute".
    # It is also what stops the re-invocation recursing: under CI=1 or
    # GOVERN_DISABLE=1, gate-run.sh execs straight through BEFORE it exports
    # GOVERN_IN_GATE, so the child would otherwise see no gate and re-invoke
    # itself forever. The mode flag is checked first, and never GOVERN_IN_GATE
    # alone.
    --locked-compute) LOCKED=1 ;;
    -*) echo "tsc-cached: unknown flag '$_a'" >&2; exit 2 ;;
    *) folder="$_a" ;;
  esac
done
[ -n "$folder" ] || { echo "usage: tsc-cached.sh [--probe] <folder>" >&2; exit 2; }

# _HERE is where the SCRIPTS live (main's copy); ROOT is the tree being checked.
# They differ exactly when TSC_CACHE_ROOT names a worktree.
_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolved BEFORE the cd below, and by basename rather than a literal name, so
# the re-invocation survives both a relative $0 and a rename of this file.
_SELF="$_HERE/$(basename "${BASH_SOURCE[0]}")"
ROOT="${TSC_CACHE_ROOT:-$(cd "$_HERE/../.." && pwd)}"
cd "$ROOT" || exit 2
[ -d "$folder" ] || { echo "tsc-cached: no such folder: $folder" >&2; exit 2; }

# shellcheck source=lib/govern.sh
. "$_HERE/lib/govern.sh"

# The key is tsc_tree_fingerprint (lib/govern.sh) — CONTENT, never mtime, over
# everything tsc reads. It used to live here as an mtime stat over src/tests +
# packages/sdk/src, and that key could not share across worktrees: two checkouts
# of one commit have identical bytes and different mtimes, so the 28 stamps on
# disk on 2026-09-03 were N worktrees each paying full price. do-reconcile.sh
# `types` calls the SAME function, so a reconcile and N cycle gates on one tree
# still cost exactly one tsc between them.
# one.ie/web and channels resolve @oneie/sdk types out of packages/sdk/dist.
_fp_extra=""
case "$folder" in one.ie/web|channels) _fp_extra="packages/sdk/src" ;; esac
_fp=$(tsc_tree_fingerprint "$folder" $_fp_extra)
[ -n "$_fp" ] || { echo "tsc-cached: could not fingerprint $folder" >&2; exit 1; }
_key="tsc-$(printf '%s' "$folder" | tr '/' '_')"
_cache="$GOVERN_DIR/${_key}.${_fp}"

# ONLY A ZERO IS REUSABLE. do-reconcile.sh writes its own counts into this same
# key namespace on purpose (shared entries, one tsc per tree), and it records
# NON-zero counts too because it wants a delta, not a verdict. This script is a
# GATE, so it obeys the gate rule: only a pass may be memoised. A cached "17" is
# re-run from scratch rather than replayed -- a red gate keeps biting until the
# tree is actually green.
_cache_ok() { # <file> — 0 when it holds a reusable PASS
  [ -s "$1" ] || return 1
  [ "$(tr -d '[:space:]' < "$1")" = "0" ]
}
if [ "$PROBE" = "1" ]; then
  # A memo lookup and nothing else. `unknown` is not `red`: it means this exact
  # tree has no recorded PASS — never checked, or checked and found red (a red
  # is never written). The caller decides what an unknown is worth.
  if _cache_ok "$_cache"; then echo green; exit 0; fi
  echo unknown; exit 1
fi
if [ "${TSC_CACHE_DISABLE:-0}" != "1" ] && _cache_ok "$_cache"; then
  echo "[tsc-cached] $folder — cache HIT (tree unchanged since it was checked)" >&2
  echo 0
  exit 0
fi

# The two bounds, read once and validated: a non-numeric override would make the
# arithmetic below a hard error rather than a slow gate.
_num() { case "${1:-}" in ''|*[!0-9]*) printf '%s' "$2" ;; *) printf '%s' "$1" ;; esac; }
_timeout=$(_num "${TSC_CACHE_TIMEOUT:-}" 600)
_lockwait=$(_num "${TSC_CACHE_WAIT:-}" 900)
# ZERO IS NOT A BOUND, it is a kill: run_bounded's timer is `setTimeout(secs *
# 1000)` (govern.ts:256), so 0 fires on the next tick and SIGTERMs the compute
# before tsc can start — every run would read RED through the empty-count
# branch. Treat it the way `${x:-600}` treats an empty string.
[ "$_timeout" -lt 1 ] && _timeout=600

# ── SLOT BEFORE LOCK ────────────────────────────────────────────────────────
# A miss from here on. Buy the SLOT first, by re-entering this same script
# through gate-run.sh; the child then takes the lock and computes. Everything
# above this line — the memo lookup and --probe — still costs neither.
#
# WHY THE SELF-INVOCATION rather than a bare gate_slot: gate-run.sh is the one
# definition of what a slot is (the queue announcement, min(config, headroom),
# the pressure warning, and the re-entrancy rule that makes a nested gate
# INHERIT the outer slot instead of taking a second one). A second copy of that
# contract here is a second thing to drift. It also keeps the hard wall-clock
# BOUND on the compute: `run_bounded` is what turns a wedged tsc into an empty
# count, and an empty count is RED (see the case below).
#
# GOVERN_IN_GATE=1 means the CALLER already holds a slot — `bun run verify:fast`
# is exactly that. Then the order is already SLOT -> LOCK, so take the lock right
# here and compute inline. Re-invoking would only add a process; gate-run.sh
# would exec straight through anyway.
if [ "$LOCKED" != "1" ] && [ "${GOVERN_IN_GATE:-0}" != "1" ]; then
  # The outer bound must be LARGER than the inner one, or it fires first and the
  # empty-count RED below stops being reachable: lock wait + compute + slack.
  TSC_CACHE_ROOT="$ROOT" TSC_CACHE_TIMEOUT="$_timeout" TSC_CACHE_WAIT="$_lockwait" \
  GOVERN_GATE_TIMEOUT=$(( _timeout + _lockwait + 60 )) \
  exec bash "$_HERE/gate-run.sh" "tsc-cache:$folder" -- \
    bash "$_SELF" --locked-compute "$folder"
fi

if gate_lock "$_key" "$_lockwait"; then
  trap 'gate_release_all' EXIT INT TERM
  # Someone may have computed it while we queued for the lock.
  if [ "${TSC_CACHE_DISABLE:-0}" != "1" ] && _cache_ok "$_cache"; then
    echo "[tsc-cached] $folder — cache HIT (computed while queued)" >&2
    echo 0
    gate_release_all; trap - EXIT INT TERM; exit 0
  fi
  echo "[tsc-cached] $folder — cache MISS, running tsc" >&2
  _tmp=$(mktemp)
  # TSC_CACHE_CMD exists for --self-test only (the `__probe__` idiom from
  # test-cached.sh): it substitutes a child that cannot finish inside the bound,
  # so the timeout branch below can be driven deterministically instead of raced.
  #
  # THE SLOT IS ALREADY HELD when we get here — either the caller's (they were
  # inside a gate) or the one this script's own re-invocation bought above. The
  # gate_lock we hold dedupes by FOLDER: it stops two sessions computing the SAME
  # answer twice. It does not cap concurrency across DIFFERENT folders, and N
  # worktrees are N folders. Measured 2026-09-07: three worktrees each ran a
  # 2.5GB tsc at once, every lock uncontended and doing its job, load hit 171 and
  # localhost served a page in 8.4s. A lock DEDUPES; only a SLOT BOUNDS THE
  # MACHINE — which is why both exist and why the order between them is fixed.
  #
  # run_bounded, not a nested gate-run.sh: gate-run under GOVERN_IN_GATE=1 execs
  # straight through, which correctly declines a SECOND slot but also drops the
  # wall-clock BOUND. So every call from inside a gate — i.e. every
  # `bun run verify:fast` — ran an unbounded tsc until 2026-09-13. Calling
  # run_bounded directly keeps the slot contract (we hold one) and restores the
  # bound on the path that had none. It kills the whole process group.
  run_bounded "$_timeout" \
    bash -c "cd '$folder' && ${TSC_CACHE_CMD:-bunx tsc --noEmit} 2>&1 | grep -c 'error TS' > '$_tmp'" \
    || true
  n=$(cat "$_tmp" 2>/dev/null | tr -d '[:space:]'); rm -f "$_tmp"
  gate_release_all; trap - EXIT INT TERM
  # AN EMPTY COUNT IS NOT ZERO. run_bounded kills tsc at the bound and its `|| true`
  # swallows the status, so $_tmp is empty on a timeout. The old line was
  # `n=${n:-0}` -- an unrun typecheck was written to the cache as "0 errors" and
  # every later reader replayed that as a PASS. An uncomputable result is a
  # could-not-run, and a could-not-run is RED.
  case "$n" in
    ''|*[!0-9]*)
      echo "[tsc-cached] $folder — tsc produced no error count (timeout or crash); check did NOT run" >&2
      exit 1 ;;
  esac
  # Only a pass is recorded. See _cache_ok.
  [ "$n" = "0" ] && printf '%s' "$n" > "$_cache"
  echo "$n"
  exit 0
fi

# Could not get the lock within the wait. An UNRUN check is not a passing check:
# say so and fail, rather than emitting 0 and reading as green.
echo "[tsc-cached] $folder — could not acquire the tsc lock; check did NOT run" >&2
exit 1
