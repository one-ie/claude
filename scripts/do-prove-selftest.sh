#!/usr/bin/env bash
# do-prove-selftest.sh — the red proof for do-prove.sh's argument contract.
# Invoked as `do-prove.sh --self-test`; $1 is the do-prove.sh under test.
#
# Asked for by .claude/improvements.queue.md:307 ("it has no --self-test, unlike
# its sibling gates ... or this regresses silently the way it arrived").
#
# Every GREEN check here is paired with a RED one that GUTS the guard it depends
# on and asserts the check then fails. A checker that stays green against gutted
# code proves nothing.
#
# Needs no live server: the parser half is pure argument handling, and the base
# half points at a closed port on purpose.
set -uo pipefail

TARGET="${1:-}"
[ -n "$TARGET" ] && [ -f "$TARGET" ] || { echo "selftest: need the path to do-prove.sh"; exit 2; }

pass=0; fail=0
ok()  { echo "  ok   — $1"; pass=$((pass+1)); }
no()  { echo "  FAIL — $1"; fail=$((fail+1)); }

# A port nothing is listening on. Verified closed, not assumed.
DEAD=""
for p in 45871 45872 45873 45874; do
  if ! curl -sf -o /dev/null --max-time 1 "http://127.0.0.1:$p/" 2>/dev/null; then DEAD="$p"; break; fi
done
[ -n "$DEAD" ] || { echo "selftest: could not find a closed port"; exit 2; }
DEADBASE="http://127.0.0.1:$DEAD"

# A gutted copy of do-prove.sh with one guard removed, laid out so its own
# ROOT-from-BASH_SOURCE derivation still works.
# A mutant must still PARSE. Deleting the body of an `if` leaves an orphaned
# `fi`, and bash exits 2 on a syntax error — which is indistinguishable from a
# usage error and would have let a broken mutant masquerade as a red proof.
# Measured while writing this file: both base-half mutants "failed" that way.
# So mutate by SUBSTITUTION (guard → `:`), and refuse a mutant that does not
# parse rather than scoring it.
gut() { # $1 = sed program → echoes the path of the mutant, or empty on failure
  local d; d="$(mktemp -d)"
  mkdir -p "$d/.claude/scripts"
  sed "$1" "$TARGET" > "$d/.claude/scripts/do-prove.sh"
  if ! cmp -s "$TARGET" "$d/.claude/scripts/do-prove.sh"; then :; else
    echo "" ; return 0   # sed matched nothing — the guard moved
  fi
  bash -n "$d/.claude/scripts/do-prove.sh" 2>/dev/null || { echo ""; return 0; }
  echo "$d/.claude/scripts/do-prove.sh"
}

echo "do-prove --self-test"
echo "[1/2] parser — an unrecognised FLAG is a hard error"

out="$(bash "$TARGET" --route / --bogus </dev/null 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ok "unknown flag --bogus exits 2 (got $rc)" \
                || no "unknown flag --bogus should exit 2, got $rc"
case "$out" in *"unknown flag '--bogus'"*) ok "…and names the flag" ;;
               *) no "output did not name the flag: $out" ;; esac

out="$(bash "$TARGET" --base </dev/null 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ok "--base with no value exits 2" || no "--base with no value: rc=$rc"
out="$(bash "$TARGET" --route </dev/null 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ok "--route with no value exits 2" || no "--route with no value: rc=$rc"

# The leniency that must SURVIVE: a bare token (cycle slug) is still ignored,
# not refused. do-w4-gates.sh:210 and do-smoke.sh:85-88 depend on this.
out="$(bash "$TARGET" some-cycle-slug --route / --base "$DEADBASE" </dev/null 2>&1)"; rc=$?
[ "$rc" -ne 2 ] && ok "a bare cycle slug is still tolerated (rc=$rc, not a usage error)" \
                || no "a bare cycle slug was refused as a usage error — this breaks existing callers"
case "$out" in *"is not a path (cycle slug?)"*) ok "…and still says so" ;;
               *) no "the lenient note is gone" ;; esac

# RED: remove the -*) branch and the flag guard must stop biting.
m="$(gut 's|^      exit 2 ;;$|      shift ;;|')"
if [ -z "$m" ]; then no "RED PROOF FAILED: could not build the flag-guard mutant"; else
out="$(bash "$m" --route / --bogus --base "$DEADBASE" </dev/null 2>&1)"; rc=$?
[ "$rc" -ne 2 ] && ok "RED PROOF: gutted flag guard no longer exits 2 (got $rc) — check 1 is live" \
                || no "RED PROOF FAILED: mutant still exits 2; check 1 proves nothing"
fi

echo "[2/2] base — --base pins the leg, and an unrun proof is not a pass"

out="$(bash "$TARGET" --route / --base "$DEADBASE" </dev/null 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "explicit --base that answers nothing exits non-zero (got $rc)" \
                || no "explicit --base answered nothing and still exited 0 — the fail-open is back"
case "$out" in *"an unrun proof is not a pass"*) ok "…and says why" ;;
               *) no "no unrun message: $out" ;; esac
case "$out" in *"https://one.ie"*) no "--base did not pin the fallback — it reached for https://one.ie" ;;
               *) ok "--base pinned the fallback (production never named)" ;; esac

# RED: remove the fallback pin → the mutant must reach for https://one.ie.
m="$(gut 's|^  PROD_URL="\$BASE_URL"$|  :|')"
if [ -z "$m" ]; then no "RED PROOF FAILED: could not build the pin mutant"; else
out="$(bash "$m" --route / --base "$DEADBASE" </dev/null 2>&1)"
case "$out" in *"https://one.ie"*) ok "RED PROOF: unpinned mutant reaches production — the pin is load-bearing" ;;
               *) no "RED PROOF FAILED: mutant did not reach production; the pin check proves nothing" ;; esac
fi

# RED: remove the unrun-is-not-a-pass block → the mutant must go back to exit 0.
m="$(gut 's|^    exit 1$|    :|')"
if [ -z "$m" ]; then no "RED PROOF FAILED: could not build the fail-open mutant"; else
out="$(bash "$m" --route / --base "$DEADBASE" </dev/null 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "RED PROOF: gutted mutant exits 0 on an unreachable base — the guard is live"
else no "RED PROOF FAILED: mutant still exits $rc; the fail-open check proves nothing"; fi
fi

echo
echo "do-prove --self-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
