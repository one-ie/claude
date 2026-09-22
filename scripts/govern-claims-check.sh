#!/usr/bin/env bash
# govern-claims-check.sh — the two properties the claim registry exists for.
#
#   C1  MUTUAL EXCLUSION   two workers cannot hold the same claim
#   C2  EVAPORATION        a dead owner's claim expires with no human in the loop
#
# Plus the checks that stop C1/C2 from passing against a gutted implementation:
#   C3  the TTL branch also evaporates (the pid branch is not the only one)
#   C4  a partial claim rolls back (a loser holds no ground)
#   C5  do-fleet's has_conflict seam inherits the reap — the caller, not just
#       the primitive
#   R1/R2  RED-PROOF: with the reaper disabled, C2 and C5 must FAIL. A checker
#       that stays green against a broken implementation is not a check.
#
# No coordinator anywhere in here — every worker is an independent process and
# mkdir(2) is the only arbiter.
#
#   bash .claude/scripts/govern-claims-check.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Point the whole library at a throwaway dir — this test must never touch the
# real machine registry other sessions are coordinating through.
export GOVERN_DIR="$SANDBOX/govern"
export GOVERN_CLAIMS_DIR="$GOVERN_DIR/claims"
# shellcheck source=lib/govern.sh
. "$HERE/lib/govern.sh"

PASS=0; FAIL=0
ok()   { echo "  ok   $*"; PASS=$(( PASS + 1 )); }
bad()  { echo "  FAIL $*"; FAIL=$(( FAIL + 1 )); }
head_() { echo ""; echo "$*"; }

reset_registry() { rm -rf "$GOVERN_CLAIMS_DIR"; mkdir -p "$GOVERN_CLAIMS_DIR"; }

# A worker is a separate bash process that sources the library and tries to
# claim. It records WON or LOST and then HOLDS — a worker that exits the instant
# it wins is a DEAD owner, and the next contender would rightly reap it, so the
# exclusion test would end up measuring evaporation instead of exclusion (it did,
# first run: 12 winners). Nothing coordinates these processes; mkdir(2) is the
# only arbiter between them.
worker() { # worker <region> <slug> <outfile>
  bash -c '
    . "$1/lib/govern.sh"
    if claim_take "$2" "$3"; then echo WON > "$4"; else echo LOST > "$4"; fi
    sleep 20
  ' _ "$HERE" "$1" "$2" "$3" >/dev/null 2>&1
}

# ─── C1 · two workers cannot hold the same claim ──────────────────────────────
head_ "C1  mutual exclusion — N concurrent workers, one region"
reset_registry
N=12
WPIDS=""
for i in $(seq 1 $N); do
  worker "one.ie/web/src/lib/resolvers" "fleet-$i" "$SANDBOX/w$i" &
  WPIDS="$WPIDS $!"
  disown %% 2>/dev/null || true   # keep the reap quiet; we kill by pid below
done
# Wait until every worker has decided — all of them are still holding.
for _ in $(seq 1 100); do
  [ "$(cat "$SANDBOX"/w* 2>/dev/null | grep -c . || true)" = "$N" ] && break
  sleep 0.1
done
WON=$(cat "$SANDBOX"/w* 2>/dev/null | grep -c WON || true)
LOST=$(cat "$SANDBOX"/w* 2>/dev/null | grep -c LOST || true)
HOLDERS=$(claim_list | grep -c . || true)
[ "$WON" = "1" ] && ok "exactly 1 of $N concurrent workers won the region (won=$WON lost=$LOST)" \
                 || bad "expected exactly 1 winner, got $WON (lost=$LOST)"
[ "$HOLDERS" = "1" ] && ok "registry holds exactly 1 claim on the region" \
                     || bad "registry holds $HOLDERS claims on one region"
# shellcheck disable=SC2086
kill -9 $WPIDS 2>/dev/null || true
rm -f "$SANDBOX"/w*

# Two DIFFERENT regions must never collide into one claim. Sanitising a path
# into a filename is lossy (a/b and a_b sanitise alike); the key must not be.
reset_registry
claim_take "a/b" "p1" >/dev/null 2>&1
claim_take "a_b" "p2" >/dev/null 2>&1
KEYS=$(claim_list | grep -c . || true)
[ "$KEYS" = "2" ] && ok "distinct regions a/b and a_b get distinct claims (key is injective)" \
                  || bad "a/b and a_b produced $KEYS claim(s) — the claim key collides"

# ─── C2 · a dead owner's claim evaporates ─────────────────────────────────────
head_ "C2  evaporation — kill the owner, prove the claim clears"
reset_registry
REGION="auth-seam"
# Spawn a real process, let IT take the claim, then kill it. The claim outlives
# the process on disk — that is the whole hazard.
bash -c '. "$1/lib/govern.sh"; claim_take "$2" "dead-fleet" >/dev/null; sleep 300' \
  _ "$HERE" "$REGION" &
DEAD_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -n "$(claim_owner "$REGION")" ] && break
  sleep 0.2
done
OWNER_BEFORE="$(claim_owner "$REGION")"
[ -n "$OWNER_BEFORE" ] && ok "claim is held while the owner lives ($OWNER_BEFORE)" \
                       || bad "owner never took the claim — test is not exercising anything"

kill -9 "$DEAD_PID" 2>/dev/null || true
wait "$DEAD_PID" 2>/dev/null || true

# No sweeper ran. No human intervened. The next contender's own read reaps it.
OWNER_AFTER="$(claim_owner "$REGION")"
[ -z "$OWNER_AFTER" ] && ok "after the owner dies, claim_owner reports nobody" \
                      || bad "dead owner still reads as holding the claim ($OWNER_AFTER)"

if claim_take "$REGION" "next-fleet"; then
  NEW_OWNER="$(claim_owner "$REGION" | awk '{print $1}')"
  [ "$NEW_OWNER" = "next-fleet" ] \
    && ok "the ground is reclaimable — new owner is next-fleet" \
    || bad "claim taken but metadata still names '$NEW_OWNER'"
else
  bad "a dead owner's region could not be reclaimed — evaporation failed"
fi
claim_release "$REGION"

# ─── C3 · the TTL branch evaporates too ───────────────────────────────────────
head_ "C3  evaporation — an expired lease clears even while the owner lives"
reset_registry
GOVERN_CLAIM_TTL_SECS=5400 claim_take "stale-region" "silent-fleet" >/dev/null
KEY="$GOVERN_CLAIMS_DIR/$(_gv_claim_key "stale-region")"
# Backdate the deposit past its lease. Owner (this shell) is very much alive,
# so ONLY the timestamp branch can clear this.
sed -i.bak "s/^started=.*/started=$(( $(date +%s) - 6000 ))/" "$KEY/meta" && rm -f "$KEY/meta.bak"
[ -z "$(claim_owner "stale-region")" ] \
  && ok "a lease older than ttl reads as free although the owner is alive" \
  || bad "expired lease still reads as held — the TTL branch never fires"

# …and an in-lease claim from a live owner is NOT reaped (the check can say no).
reset_registry
claim_take "fresh-region" "live-fleet" >/dev/null
[ -n "$(claim_owner "fresh-region")" ] \
  && ok "a fresh claim from a live owner is still held (reaper is not indiscriminate)" \
  || bad "reaper cleared a live, in-lease claim"
claim_release "fresh-region"

# ─── C4 · partial claim rolls back ────────────────────────────────────────────
head_ "C4  rollback — a worker that loses one region holds none"
reset_registry
# Another live worker owns region B.
bash -c '. "$1/lib/govern.sh"; claim_take "regionB" "other" >/dev/null; sleep 60' _ "$HERE" &
OTHER=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -n "$(claim_owner regionB)" ] && break; sleep 0.2; done
# Our worker wants A and B; it must end up holding neither.
bash -c '
  . "$1/lib/govern.sh"
  taken=()
  for r in regionA regionB; do
    if claim_take "$r" "mine"; then taken+=("$r"); else
      for t in "${taken[@]}"; do claim_release "$t"; done
      exit 1
    fi
  done
  exit 0' _ "$HERE" 2>/dev/null
[ $? -ne 0 ] && ok "the multi-region worker correctly failed" || bad "worker claimed a region another holds"
[ -z "$(claim_owner regionA)" ] \
  && ok "regionA was released on rollback — no orphan ground" \
  || bad "regionA left claimed by a worker that never launched"
kill -9 "$OTHER" 2>/dev/null || true; wait "$OTHER" 2>/dev/null || true

# ─── C5 · the do-fleet seam inherits the reap ─────────────────────────────────
head_ "C5  seam — do-fleet's REAL has_conflict/free_dirs read through the reaper"
reset_registry
# Lift the ACTUAL function bodies out of do-fleet.sh — not a hand-written copy.
# A copy passes while the shipped function dies on an unquoted var or a stray
# awk field, which is precisely the drift this check exists to catch.
FLEET="$HERE/do-fleet.sh"
eval "$(awk '/^has_conflict\(\) \{/,/^\}/' "$FLEET")"
eval "$(awk '/^free_dirs\(\) \{/,/^\}/'   "$FLEET")"
# do-fleet gets its dir list from do-rank.py; stub that one seam so the test
# needs no plan files. Everything below is do-fleet's own code.
deliverable_dirs() { case "$1" in newplan|ghostplan) echo "one.ie/web/src/pages";; *) : ;; esac; }
declare -f has_conflict >/dev/null && ok "lifted the real has_conflict() out of do-fleet.sh" \
                                  || bad "could not lift has_conflict() — check the awk range"

bash -c '. "$1/lib/govern.sh"; claim_take "one.ie/web/src/pages" "ghostplan" >/dev/null; sleep 300' \
  _ "$HERE" &
GHOST=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -n "$(claim_owner "one.ie/web/src/pages")" ] && break; sleep 0.2; done
if has_conflict "newplan" >/dev/null 2>&1; then
  ok "a live ghost blocks the region (real has_conflict says conflict)"
else
  bad "real has_conflict failed to see another fleet's live claim"
fi
kill -9 "$GHOST" 2>/dev/null || true; wait "$GHOST" 2>/dev/null || true
if has_conflict "newplan" >/dev/null 2>&1; then
  bad "real has_conflict still blocks on a DEAD owner — the fleet would stay wedged"
else
  ok "after the owner dies the real has_conflict clears — the fleet reroutes in"
fi

# free_dirs must not hand back a sentinel this slug never took.
reset_registry
claim_take "__ANY__" "unscoped-plan" >/dev/null
free_dirs "newplan"          # a DIFFERENT, scoped plan finishing
[ "$(claim_owner "__ANY__" | awk '{print $1}')" = "unscoped-plan" ] \
  && ok "free_dirs leaves another slug's __ANY__ sentinel alone" \
  || bad "a scoped plan's free_dirs released the unscoped plan's sole-slot claim"
free_dirs "unscoped-plan"
[ -z "$(claim_owner "__ANY__")" ] \
  && ok "the sentinel's own slug can still release it" \
  || bad "__ANY__ could not be released by its owner"

# ─── R1/R2 · prove the checker can go RED ─────────────────────────────────────
head_ "R1/R2  red-proof — with the reaper gutted, C2 and C5 must FAIL"
reset_registry
(
  # A gutted implementation: the owner is always "alive", so nothing evaporates.
  _gv_alive() { return 0; }
  bash -c '. "$1/lib/govern.sh"; claim_take "red-region" "zombie" >/dev/null; sleep 300' \
    _ "$HERE" &
  Z=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -d "$GOVERN_CLAIMS_DIR/$(_gv_claim_key red-region)" ] && break; sleep 0.2; done
  kill -9 "$Z" 2>/dev/null || true; wait "$Z" 2>/dev/null || true
  if [ -n "$(claim_owner "red-region")" ]; then
    echo "  ok   with _gv_alive stubbed true, the dead owner's claim does NOT clear"
    echo "       -> C2/C5 are testing the reaper, not an empty directory"
    exit 0
  fi
  echo "  FAIL C2/C5 pass even with the reaper disabled — they prove nothing"
  exit 1
)
if [ $? -eq 0 ]; then PASS=$(( PASS + 1 )); else FAIL=$(( FAIL + 1 )); fi

echo ""
echo "govern-claims-check: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
