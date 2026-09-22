#!/usr/bin/env bash
# typedb-flake-check.sh — decide whether a RED vitest log is ONLY the shared
# TypeDB Cloud cluster being unavailable, and therefore safe to ship past.
#
# manifest: portable
#
# WHY THIS EXISTS. `one.ie/web`'s suite talks to a REAL shared TypeDB Cloud
# cluster (CLAUDE.md: "Don't mock TypeDB in integration tests"). When that
# cluster blips or a query exceeds its timeout, a handful of task/substrate
# suites go red without anything in the diff being wrong. Before this script the
# operator read the log by eye and decided — which is exactly the judgement call
# that gets rubber-stamped at 2am on the fifth deploy attempt.
#
# WHAT IT IS NOT. It is not a failure allowlist by FILE. A file-based allowlist
# waves through every future failure in that file, including real ones. This
# keys on the failure SIGNATURE — the substrate was unreachable — so a genuine
# assertion break in the very same test still blocks.
#
# THE HARD LINE. `not_found` from `tasks:claim` is the privilege boundary. Four
# separate defects presented as exactly that string and were fixed 2026-08-02
# (see deploy.md's Known-Flaky section). It is NEVER a flake, it is never
# waived, and it is checked BEFORE the flake signatures so no combination of
# other output can pass it.
#
# CONTRACT
#   exit 0 — every failure carries a substrate-unavailable signature. Waivable.
#   exit 1 — at least one failure is real, or the log could not be classified.
# Silence is never a pass: a log with no parseable "Tests N failed" line exits 1.
#
#   bash .claude/scripts/typedb-flake-check.sh <vitest-log>
#   bash .claude/scripts/typedb-flake-check.sh --self-test
set -uo pipefail

# ── signatures ───────────────────────────────────────────────────────────────
# The substrate refused to answer. Nothing downstream of these proved anything.
FLAKE_RE='upstream_50[234]|status=50[234]|fixture write failed|Test timed out in [0-9]+ ?ms|ETIMEDOUT|ECONNRESET|ECONNREFUSED|EAI_AGAIN|socket hang up|fetch failed|TypeDB.*(unavailable|timed out|connection)|Failed to connect'

# Never waivable, whatever else the log says: the privilege boundary. Matched
# against failure BODIES only, in the awk below -- see the comment there.
NEVER_RE='not_found'

classify() {
  local log="$1" fails blocks matched
  [ -f "$log" ] || { echo "typedb-flake: no such log: $log"; return 1; }

  # A COLLECT CRASH — vitest's bracketed form, `FAIL  path/x.test.ts [ path/x.test.ts ]`
  # followed by a parse/import error — ran ZERO tests. It is never a cluster blip
  # and never waivable: on 2026-09-05 a truncated gitignored JSON crashed the
  # collect of deploy-board.test.tsx and the waiver called it a TypeDB outage
  # (vitest-collect-crash-reads-as-pass, through the waiver door).
  if grep -qE '^ *FAIL +[^ ]+\.test\.[a-z]+ +\[ +[^ ]+\.test\.[a-z]+ +\]' "$log"; then
    echo "typedb-flake: BLOCKED -- a test file failed to COLLECT ($(grep -oE '^ *FAIL +[^ ]+\.test\.[a-z]+ +\[' "$log" | head -1 | awk '{print $2}')). Zero tests ran there. Not a flake."
    return 1
  fi
  # Unhandled errors ("Errors  45 errors") fail the run with ZERO failed tests.
  # They are never a cluster blip and never waivable — refuse before anything
  # else, or a red run reads GREEN here (measured 2026-09-05).
  if grep -qE 'Errors +[1-9][0-9]* errors?' "$log"; then
    echo "typedb-flake: BLOCKED -- the log carries unhandled errors ($(grep -Eo 'Errors +[0-9]+ errors?' "$log" | tail -1)). Not a flake."
    return 1
  fi
  # How many tests vitest itself says failed. No line ⇒ we cannot classify ⇒ RED.
  # Strip ANSI escape codes first — vitest 4.x wraps its summary in colour codes
  # that break the regex ("Tests  \x1b[1m\x1b[31m12 failed\x1b[39m" → no match).
  fails=$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -Eo 'Tests +[0-9]+ failed' | tail -1 | grep -Eo '[0-9]+' || true)
  if [ -z "$fails" ]; then
    # A green log has "Tests N passed" and no "failed" — that is not our business.
    if grep -qE 'Tests +[0-9]+ passed' "$log" && ! grep -qE '[0-9]+ failed' "$log"; then
      echo "typedb-flake: log is GREEN — nothing to classify"; return 1
    fi
    echo "typedb-flake: cannot find a 'Tests N failed' line — refusing to classify"; return 1
  fi

  # The hard line, checked first and independently of everything else.
  #
  # Scoped to failure BODIES, with the FAIL header line dropped. Two reasons,
  # both real: (a) a whole-log grep sees `not_found` in the NAME of a perfectly
  # healthy test -- tasks-do-roundtrip.test.ts really does contain
  # `claim by an unknown slug is not_found, never a silent success`, so a
  # log-wide grep let one passing test veto every deploy; (b) `not_found` is
  # legitimate ASSERTED output in the tests that check the boundary holds. What
  # is never acceptable is `not_found` as the RECEIVED value of a failure.
  # `seen` bounds the FIRST block: before any FAIL header the accumulator holds
  # the log PREAMBLE — gate banners plus the stderr of every PASSING test that
  # ran first — and a passing test's NAME ("…is not_found") or asserted output
  # ("workspace_not_found") tripped this on two deploys (2026-09-05), once with a
  # confident wrong diagnosis pointing at tasks:claim for an un-regenerated
  # roster. A body is only a failure body once a header has opened it.
  if awk -v re="$NEVER_RE" '
      /^ *(FAIL|Unhandled)/ { if (seen && body ~ re) { print "HIT"; exit } ; seen = 1; body = ""; next }
      { body = body "\n" $0 }
      END { if (seen && body ~ re) print "HIT" }
    ' "$log" | grep -q HIT; then
    echo "typedb-flake: BLOCKED -- a failure BODY contains 'not_found'."
    echo "  That is the tasks:claim privilege boundary, not a cluster blip."
    echo "  It is never waived. See deploy.md section Known-Flaky Test Allowlist."
    return 1
  fi

  # Split the log into vitest's per-failure blocks (the ⎯[n/m]⎯ separators) and
  # require EVERY one of them to carry a substrate signature. Counting matched
  # blocks rather than grepping the whole file is the point: one flake signature
  # anywhere must not vouch for an unrelated assertion failure beside it.
  blocks=$(awk '/^ *(FAIL|Unhandled)/{n++} END{print n+0}' "$log")
  matched=$(awk -v re="$FLAKE_RE" '
    /^ *(FAIL|Unhandled)/ { if (cur != "" && cur ~ re) m++; cur = $0; next }
    { cur = cur "\n" $0 }
    END { if (cur != "" && cur ~ re) m++; print m+0 }
  ' "$log")

  if [ "$blocks" -eq 0 ]; then
    echo "typedb-flake: $fails failed test(s) but no FAIL blocks parsed — refusing to classify"; return 1
  fi
  if [ "$matched" -lt "$blocks" ]; then
    echo "typedb-flake: BLOCKED — $matched/$blocks failure blocks look like substrate outage."
    echo "  $(( blocks - matched )) failure(s) are REAL. Diagnose them."
    return 1
  fi
  echo "typedb-flake: WAIVABLE — all $blocks failure block(s) ($fails test(s)) are substrate-unavailable."
  echo "  Signature matched: shared TypeDB Cloud did not answer. Nothing was disproven."
  return 0
}

# ── --self-test: prove the checker can go RED ────────────────────────────────
# A classifier that only ever says "waivable" is worse than no classifier. This
# drives both halves, including the two ways it must refuse.
if [ "${1:-}" = "--self-test" ]; then
  d=$(mktemp -d); fails=0
  t() { # name expected_rc file
    local name="$1" want="$2" f="$3" got
    classify "$f" >/dev/null 2>&1; got=$?
    if [ "$got" -eq "$want" ]; then echo "  ok   $name (rc=$got)"
    else echo "  FAIL $name — wanted rc=$want got rc=$got"; fails=$((fails+1)); fi
  }

  cat >"$d/flake.log" <<'EOF'
 FAIL  tests/unit/tasks-humans.test.ts > seeds a task
Error: fixture write failed (status=503 error=upstream_503)
⎯⎯⎯[1/1]⎯
 Test Files  1 failed | 900 passed (901)
      Tests  1 failed | 9000 passed (9001)
EOF
  t "pure 503 outage is waivable" 0 "$d/flake.log"

  cat >"$d/real.log" <<'EOF'
 FAIL  tests/unit/billing.test.ts > charges the card once
AssertionError: expected 2 to be 1
⎯⎯⎯[1/1]⎯
 Test Files  1 failed | 900 passed (901)
      Tests  1 failed | 9000 passed (9001)
EOF
  t "a real assertion failure BLOCKS" 1 "$d/real.log"

  cat >"$d/mixed.log" <<'EOF'
 FAIL  tests/unit/tasks-humans.test.ts > seeds a task
Error: fixture write failed (status=503 error=upstream_503)
 FAIL  tests/unit/billing.test.ts > charges the card once
AssertionError: expected 2 to be 1
⎯⎯⎯[2/2]⎯
 Test Files  2 failed | 900 passed (902)
      Tests  2 failed | 9000 passed (9002)
EOF
  t "one flake must not vouch for its neighbour" 1 "$d/mixed.log"

  cat >"$d/notfound.log" <<'EOF'
 FAIL  tests/unit/tasks-containment.test.ts > a task is claimable
AssertionError: expected 'not_found' to be undefined
Error: fixture write failed (status=503 error=upstream_503)
⎯⎯⎯[1/1]⎯
 Test Files  1 failed | 900 passed (901)
      Tests  1 failed | 9000 passed (9001)
EOF
  t "not_found BLOCKS even wrapped in a 503" 1 "$d/notfound.log"

  cat >"$d/nameonly.log" <<'EOF'
 FAIL  tests/tasks-do-roundtrip.test.ts > claim by an unknown slug is not_found, never a silent success
Error: fixture write failed (status=503 error=upstream_503)
 Test Files  1 failed | 900 passed (901)
      Tests  1 failed | 9000 passed (9001)
EOF
  t "not_found in a test NAME does not block a real 503" 0 "$d/nameonly.log"

  cat >"$d/green.log" <<'EOF'
 Test Files  901 passed (901)
      Tests  9001 passed (9001)
EOF
  t "a green log is not classifiable" 1 "$d/green.log"

  : >"$d/empty.log"
  t "an empty log is not a pass" 1 "$d/empty.log"

  rm -rf "$d"
  [ "$fails" -eq 0 ] && { echo "typedb-flake: self-test PASS"; exit 0; }
  echo "typedb-flake: self-test FAILED ($fails)"; exit 1
fi

classify "${1:?usage: typedb-flake-check.sh <vitest-log> | --self-test}"
