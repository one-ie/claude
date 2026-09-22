#!/usr/bin/env bash
# test-lanes.sh — the full suite as TWO concurrent lanes, because it has two
# different binding constraints and one pool cannot serve both.
#
# manifest: needs-env
#
# THE MEASUREMENT THAT FORCED THIS (2026-09-03). Four full-suite runs on an
# UNCHANGED tree produced four DIFFERENT failure sets — 8, 12, 13, 8 failures.
# Every failing file in all four runs was one of the 19 suites marked
# `real TypeDB`; not one of the other ~1126 files ever failed. Per run the log
# carried 41-72 `typedbQuery upstream 503` and 25-38 `upstream 500` warnings,
# and those are emitted only AFTER the retry budget is spent (substrate.ts:208).
#
# The cause is capacity, not code: `substrate.ts:56-60` records that the shared
# TypeDB Cloud gateway 503s in bursts lasting SECONDS, while the retry cover is
# 500ms + 1000ms. Eight vitest forks hammering one external singleton turn that
# into a coin flip, and a coin-flip gate costs far more than it saves — the
# 2026-09-03 deploy spent hours on re-runs and root-cause agents for failures
# that were never in the diff.
#
# WHY TWO LANES BEAT ONE. The lanes have opposite constraints, so they overlap
# almost for free:
#   pool  — ~1126 files, CPU-bound, 8 forks, touches no gateway
#   typedb — 19 files, NETWORK-bound, serial, one gateway conversation at a time
# Lane `typedb` spends its life waiting on a socket, so it costs little CPU while
# `pool` saturates the cores. Wall clock is max(pool, typedb), not pool+typedb.
#
# WHAT THIS IS NOT. It is not `--no-file-parallelism` over the whole suite (that
# serialises 1126 innocent files to fix 19), and it is not a retry that swallows
# a 503. Serialising ONLY the suites that share the external singleton removes
# the contention at its source while leaving the real gate intact: every test
# still runs, no assertion is weakened, nothing is skipped.
#
# The selector is the `real TypeDB` marker the suites already carry — read from
# the tree at run time, never a hardcoded list that would rot silently.
#
# ONE LANE AT A TIME — `TEST_LANES_ONLY=pool|typedb`. Unset is unchanged and must
# stay that way: both lanes, concurrent, the same two `───── <lane> lane` headers
# in the same order (release.sh:96-101 PARSES those headers for its per-lane
# receipt keys, and deploy.sh's memo probe reads the keys under them).
#
# WHY IT EXISTS (measured 2026-09-21). The two lanes were ONE gate for deploy, and
# a gate costs its SLOWER lane: pool 1420 files / 8 forks / 29.6s, typedb 25 files
# / serial / 118.8s. deploy.sh set TYPEDB_LANE_NONBLOCKING=1 — declaring the typedb
# rc could not change the outcome — and then blocked ~89s at `wait "$PID_B"` for
# exactly that rc. Split into two gates, the network-bound lane can overlap the
# CPU-bound astro build instead of delaying the deploy.
#
# The selection each lane hands vitest is IDENTICAL in single-lane mode: the
# memo key is the argv (test-cached.sh:141-181), so a lane that dropped its
# `--exclude` list or reordered a flag would mint a key no other caller can hit,
# and a warm tree would pay the suite twice. Both lane command arrays are built
# the same way whatever is selected; TEST_LANES_ONLY chooses only which to LAUNCH.
#
#   bash .claude/scripts/test-lanes.sh            # both lanes, concurrent
#   bash .claude/scripts/test-lanes.sh --list     # show the split, run nothing
#   bash .claude/scripts/test-lanes.sh --self-test
#   TEST_LANES_ONLY=pool bash .claude/scripts/test-lanes.sh    # one lane
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FOLDER="${TEST_FULL_FOLDER:-one.ie/web}"
DIR="$ROOT/$FOLDER"

# Timeouts match test-full.sh's single definition — see that file's comment on
# why every caller must present identical argv to test-cached.sh.
# test-full.sh owns the ONE definition of these flags and hands them over in
# TEST_FULL_ARGS. The literal here is only the standalone-invocation fallback —
# if the two ever drift, the memo key splits and a warm tree silently pays the
# suite twice, which is the exact bug test-full.sh was created to kill.
if [ -n "${TEST_FULL_ARGS:-}" ]; then
  COMMON=(); for _a in $TEST_FULL_ARGS; do COMMON+=("$_a"); done
else
  COMMON=(--testTimeout=15000 --hookTimeout=15000 --teardownTimeout=15000 --reporter=dot)
fi

# The 19. Read from the tree so adding a real-TypeDB suite puts it in the serial
# lane automatically; a hardcoded list is how this rots back into flakiness.
typedb_files() { (cd "$DIR" && grep -rl 'real TypeDB' tests --include='*.test.ts' 2>/dev/null | sort); }

# A TYPO MUST REFUSE, not pick a lane. `TEST_LANES_ONLY=tyepdb` silently running
# both lanes would hide the split; silently running neither would be a gate that
# can only answer green. Exit 2 is distinct from a lane failure (1).
ONLY="${TEST_LANES_ONLY:-}"
case "$ONLY" in
  ""|pool|typedb) ;;
  *) echo "test-lanes: TEST_LANES_ONLY='$ONLY' is not pool|typedb — refusing to guess which lane you meant" >&2
     exit 2 ;;
esac

if [ "${1:-}" = "--list" ]; then
  n=$(typedb_files | wc -l | tr -d ' ')
  total=$(cd "$DIR" && find tests -name '*.test.ts*' | wc -l | tr -d ' ')
  if [ "$ONLY" != "pool" ]; then
    echo "typedb lane (serial, network-bound): $n files"
    typedb_files | sed 's/^/  /'
  fi
  if [ "$ONLY" != "typedb" ]; then
    echo "pool lane (8 forks, CPU-bound): $(( total - n )) files"
  fi
  exit 0
fi

# --self-test: the selector must actually select, and must not select everything.
if [ "${1:-}" = "--self-test" ]; then
  fails=0
  n=$(typedb_files | wc -l | tr -d ' ')
  total=$(cd "$DIR" && find tests -name '*.test.ts*' | wc -l | tr -d ' ')
  if [ "$n" -gt 0 ]; then echo "  ok   selector found $n real-TypeDB suites"
  else echo "  FAIL selector found ZERO files — the marker moved, lane is empty"; fails=$((fails+1)); fi
  if [ "$n" -lt "$total" ]; then echo "  ok   selector is a strict subset ($n of $total)"
  else echo "  FAIL selector matched everything — no split happened"; fails=$((fails+1)); fi
  # Every selected file must exist (guards a stale/quoted path)
  miss=0; while read -r f; do [ -n "$f" ] && [ -f "$DIR/$f" ] || miss=$((miss+1)); done < <(typedb_files)
  if [ "$miss" -eq 0 ]; then echo "  ok   every selected path exists"
  else echo "  FAIL $miss selected path(s) do not exist"; fails=$((fails+1)); fi

  # TEST_LANES_ONLY must answer BOTH ways, and must not move the memo key.
  # The key IS the argv (test-cached.sh:141-181), so a single-lane run whose key
  # differs from the same lane inside a both-lane run means every deploy pays for
  # a suite the tree has already passed — invisible, and only a comparison finds
  # it. TEST_CACHE_KEY_ONLY prints keys and runs no vitest (~1s for all three).
  _self_keys() { TEST_CACHE_KEY_ONLY=1 TEST_LANES_ONLY="$1" \
                   bash "$ROOT/.claude/scripts/test-full.sh" 2>/dev/null \
                 | grep -E '^[0-9a-f]{64}$'; }
  kb="$(_self_keys "")"; kp="$(_self_keys pool)"; kt="$(_self_keys typedb)"
  kb_pool="$(printf '%s\n' "$kb" | sed -n 1p)"; kb_tdb="$(printf '%s\n' "$kb" | sed -n 2p)"
  nb=$(printf '%s\n' "$kb" | grep -c .); np=$(printf '%s\n' "$kp" | grep -c .); nt=$(printf '%s\n' "$kt" | grep -c .)
  if [ "$nb" -eq 2 ]; then echo "  ok   unset runs BOTH lanes (2 keys)"
  else echo "  FAIL unset printed $nb lane key(s), expected 2 — release.sh's receipt reads these"; fails=$((fails+1)); fi
  if [ "$np" -eq 1 ] && [ "$kp" = "$kb_pool" ]; then echo "  ok   TEST_LANES_ONLY=pool runs the pool lane ALONE, same key"
  else echo "  FAIL pool-only printed $np key(s) and/or a DIFFERENT key than the pool lane of a both-lane run"; fails=$((fails+1)); fi
  if [ "$nt" -eq 1 ] && [ "$kt" = "$kb_tdb" ]; then echo "  ok   TEST_LANES_ONLY=typedb runs the typedb lane ALONE, same key"
  else echo "  FAIL typedb-only printed $nt key(s) and/or a DIFFERENT key than the typedb lane of a both-lane run"; fails=$((fails+1)); fi
  # …and the two lanes must not be the same selection wearing two names.
  if [ -n "$kp" ] && [ "$kp" != "$kt" ]; then echo "  ok   the two lanes select different sets (keys differ)"
  else echo "  FAIL both lanes produced the same key — the split is not happening"; fails=$((fails+1)); fi
  # A flag that cannot refuse is not a flag: a typo must not pick a lane.
  TEST_LANES_ONLY=tyepdb bash "$ROOT/.claude/scripts/test-lanes.sh" --list >/dev/null 2>&1
  if [ "$?" -eq 2 ]; then echo "  ok   an unknown TEST_LANES_ONLY value REFUSES (exit 2)"
  else echo "  FAIL an unknown TEST_LANES_ONLY value did not refuse"; fails=$((fails+1)); fi

  [ "$fails" -eq 0 ] && { echo "test-lanes: self-test PASS"; exit 0; }
  echo "test-lanes: self-test FAILED ($fails)"; exit 1
fi

# bash 3.2 (what macOS ships) has no `mapfile` — read the list the portable way.
TDB=()
while IFS= read -r _f; do [ -n "$_f" ] && TDB+=("$_f"); done < <(typedb_files)
if [ "${#TDB[@]}" -eq 0 ]; then
  # The whole-suite fallback is correct for "everything except the marked files"
  # when nothing is marked — it is NOT correct for the typedb lane, which would
  # then run the entire suite under one worker, or (worse) report green having
  # selected nothing. A lane that selects no file is not a green lane.
  if [ "$ONLY" = "typedb" ]; then
    echo "test-lanes: TEST_LANES_ONLY=typedb but the 'real TypeDB' marker matched NOTHING — refusing to report an empty lane as green" >&2
    exit 1
  fi
  echo "test-lanes: no 'real TypeDB' suites found — falling back to the single full run"
  exec bash "$ROOT/.claude/scripts/test-cached.sh" "$FOLDER" -- "${COMMON[@]}"
fi

EXCL=(); for f in "${TDB[@]}"; do EXCL+=(--exclude "$f"); done

LOG_A="$(mktemp)"; LOG_B="$(mktemp)"
RUN_POOL=1; RUN_TDB=1
case "$ONLY" in pool) RUN_TDB=0 ;; typedb) RUN_POOL=0 ;; esac
if [ -n "$ONLY" ]; then
  echo "test-lanes: $ONLY lane ONLY (TEST_LANES_ONLY=$ONLY) — the other lane is somebody else's gate"
else
  echo "test-lanes: pool lane (8 forks) + typedb lane (${#TDB[@]} files, serial) — concurrent"
fi

# Lane A: everything except the gateway suites. Full fan-out, no external dep.
#
# ...unless something else CPU-heavy is running beside us. Measured on the
# 2026-09-03 production deploy: the astro build (8 GiB heap) and this lane ran
# concurrently on a 10-core box and BOTH took 256s — the lane alone is 104s and
# the build alone is 133s, so the overlap bought nothing and cost 2x each. Eight
# forks plus a build is oversubscription, not parallelism.
#
# BUT CAPPING THE POOL DOES NOT FIX IT — measured, same box, same tree:
#   8 forks (baseline)   gates wall-clock 256s   build 133s
#   5 forks (VERIFY_POOL_FORKS=5)          272s   build 209s
# Starving the pool did not feed the build; both got worse. Parallel, serial and
# capped all land at 250-270s, so that is simply the floor for build+suite on a
# 10-core box as currently shaped. The knob is left here, UNSET by default and
# wired to nothing, purely so the next person can re-measure cheaply instead of
# re-deriving the idea. Nothing in deploy.sh sets it.
POOL_FORKS="${VERIFY_POOL_FORKS:-}"
POOL_ARGS=(); [ -n "$POOL_FORKS" ] && POOL_ARGS=(--maxWorkers="$POOL_FORKS")
# ${A[@]+"${A[@]}"} is not defensive noise -- it is REQUIRED here. macOS ships
# bash 3.2.57, where expanding an EMPTY array under `set -u` (line 40) is an
# "unbound variable" error, not an empty expansion. POOL_ARGS is empty by
# default because VERIFY_POOL_FORKS is deliberately unset, so the bare
# "${POOL_ARGS[@]}" killed the pool lane before vitest was ever invoked:
#
#   test-lanes.sh: line 119: POOL_ARGS[@]: unbound variable
#   ----- pool lane (rc=1) -----      0 of ~1126 files run
#
# The gate reported FAILED, which is correct and is the only reason this was
# caught rather than shipped as a pass -- but the FULL SUITE COULD NOT RUN on
# main from the commit that added the knob until this one. EXCL and TDB get the
# same guard: both are empty if the `real TypeDB` marker ever matches nothing,
# which would break BOTH lanes the same way, silently, on a rename.
RC_A=0; RC_B=0
if (( RUN_POOL )); then
( TEST_CACHE_PTY=1 bash "$ROOT/.claude/scripts/test-cached.sh" "$FOLDER" -- \
    "${COMMON[@]}" ${POOL_ARGS[@]+"${POOL_ARGS[@]}"} ${EXCL[@]+"${EXCL[@]}"} >"$LOG_A" 2>&1 ) & PID_A=$!
fi

# Lane B: the gateway suites, ONE at a time. --no-file-parallelism is the whole
# point — it is what stops 8 forks bursting a singleton that 503s under load.
if (( RUN_TDB )); then
( TEST_CACHE_PTY=1 bash "$ROOT/.claude/scripts/test-cached.sh" "$FOLDER" -- \
    "${COMMON[@]}" --no-file-parallelism --maxWorkers=1 ${TDB[@]+"${TDB[@]}"} >"$LOG_B" 2>&1 ) & PID_B=$!
fi

# Same order as ever, so a both-lane run is byte-identical to what it was.
(( RUN_POOL )) && { wait "$PID_A"; RC_A=$?; }
(( RUN_TDB ))  && { wait "$PID_B"; RC_B=$?; }

# The `───── <lane> lane (rc=N) ─────` headers are PARSED — release.sh:96-101
# reads the lane name off them to label each receipt key. A lane that did not run
# prints no header, so its key can never be mistaken for the other lane's.
(( RUN_POOL )) && { echo "───── pool lane (rc=$RC_A) ─────";   cat "$LOG_A"; }
(( RUN_TDB ))  && { echo "───── typedb lane (rc=$RC_B) ─────"; cat "$LOG_B"; }
rm -f "$LOG_A" "$LOG_B"

# ONE LANE: its own rc is the verdict, full stop.
#
# TYPEDB_LANE_NONBLOCKING is deliberately NOT honoured here, and this is the
# sharp edge of the whole flag. That branch exits 0 whenever the POOL lane is
# green — in typedb-only mode there IS no pool lane, so honouring it would make
# this a gate that can only ever answer green. Non-blocking is the CALLER's
# policy (deploy.sh keeps the typedb gate out of its verdict); it is not this
# script's licence to hide a red.
if [ -n "$ONLY" ]; then
  if [ "$ONLY" = "pool" ]; then _rc=$RC_A; else _rc=$RC_B; fi
  if [ "$_rc" -eq 0 ]; then echo "test-lanes: $ONLY lane green"; exit 0; fi
  echo "test-lanes: FAILED ($ONLY lane rc=$_rc)"; exit "$_rc"
fi

# TYPEDB_LANE_NONBLOCKING: the typedb lane still runs (signal is preserved) but
# its exit code is never a gate. Set in deploy.sh because the deploy must not
# block on the shared TypeDB Cloud cluster — the request path goes through
# Cloudflare (BrainDO / KV), TypeDB is writes + sync only (§ The brain and the edge).
if [[ "${TYPEDB_LANE_NONBLOCKING:-0}" == "1" ]]; then
  if [ "$RC_B" -ne 0 ]; then
    echo "test-lanes: typedb lane FAILED (rc=$RC_B) — non-blocking, gate is pool lane only"
  fi
  if [ "$RC_A" -eq 0 ]; then
    echo "test-lanes: pool lane green — PASS (typedb lane non-blocking)"; exit 0
  fi
  echo "test-lanes: FAILED (pool=$RC_A typedb=$RC_B, typedb non-blocking)"; exit 1
fi

# Both must pass. A lane that could not run is a failure, never a pass.
if [ "$RC_A" -eq 0 ] && [ "$RC_B" -eq 0 ]; then
  echo "test-lanes: BOTH lanes green"; exit 0
fi
echo "test-lanes: FAILED (pool=$RC_A typedb=$RC_B)"; exit 1
