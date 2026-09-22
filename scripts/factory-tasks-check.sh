#!/usr/bin/env bash
# factory-tasks-check.sh — the LIVE half of text/factory-tasks.md.
#
# Every other check in that promise asserts an EMITTED TQL STRING. That is the right
# instrument for a query-builder change, and it is not enough on its own: all of them
# can be green while nothing ever came back from a substrate, because the production
# graph holds 6 `deliverable` rows against 783 written in promise markdown. So this
# check seeds a real objective -> deliverable -> task, reads it back through the
# widened path, and asserts the nesting survives AND that a deliverable with no task
# under it is visible as a gap.
#
# Modes:
#   ladder-live   seed a ladder in a SCRATCH db, read it back nested
#
# Exit: 0 = ok · 1 = RED (the wire is broken) · 3 = CANNOT RUN (no scratch db / no creds)
#
# 1 vs 3 is load-bearing, same as factory-check.sh: red sends someone to fix the build,
# cannot-run sends them to fix the environment. Never widen a cannot-run into a red.
#
# NEVER runs against `one`. The scratch db is named explicitly by TYPEDB_TEST_DB and
# the guard below refuses if it resolves to the production database — a seeding check
# pointed at production writes fabricated rungs into the graph the board reads.
set -uo pipefail

# _GATE — route a heavy compute through the machine governor. A gate_lock only
# dedupes IDENTICAL work; a SLOT is what bounds N worktrees each running one of
# these at once (measured 2026-09-07: three concurrent 2.5GB typecheckers, every
# lock uncontended, load 171). Empty when already inside a gate, so a nested call
# inherits the outer slot rather than taking a second one.
#
# Resolves gate-run.sh from its OWN directory, deliberately: an earlier version
# keyed off $ROOT and got inserted above the line that sets it, so _GATE was
# silently empty and every call ran ungoverned -- a fail-OPEN, which is the exact
# defect this preamble exists to close.
_GATE=()
if [ "${GOVERN_IN_GATE:-0}" != "1" ]; then
  _GR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-run.sh"
  [ -f "$_GR" ] && _GATE=( bash "$_GR" "compute:$(basename "${BASH_SOURCE[0]}")" -- )
fi


ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:-ladder-live}"

red()    { echo "RED  $1" >&2; return 1; }
cannot() { echo "CANNOT RUN: $1" >&2; return 3; }

# Same parser as factory-check.sh — `set -a && . .env` aborts on that file's
# hyphenated key + unquoted value.
eval "$(python3 - "$ROOT/one.ie/web/.env" <<'PY'
import re,sys,shlex
for line in open(sys.argv[1], errors="replace"):
    m = re.match(r'^\s*(TYPEDB_(?:URL|DATABASE|USERNAME|PASSWORD))\s*=\s*(.*?)\s*$', line)
    if m: print(f"{m.group(1)}={shlex.quote(m.group(2).strip(chr(34)+chr(39)))}")
PY
)"
: "${TYPEDB_URL:=}" "${TYPEDB_DATABASE:=}" "${TYPEDB_USERNAME:=}" "${TYPEDB_PASSWORD:=}" "${TYPEDB_TEST_DB:=}"

check_ladder_live() {
  local t="$ROOT/one.ie/web/src/lib/resolvers/factory-ladder-live.test.ts"
  [ -f "$t" ] || return $(red "no factory-ladder-live.test.ts — the ladder read is unproven against any substrate")
  [ -n "$TYPEDB_URL" ] || return $(cannot "no TYPEDB_URL in one.ie/web/.env")
  [ -n "$TYPEDB_TEST_DB" ] \
    || return $(cannot "no TYPEDB_TEST_DB scratch database — this check SEEDS rungs, so it must never point at the production graph the board reads")

  # The production guard. TYPEDB_DATABASE is what the app talks to; if the scratch name
  # equals it (or is the well-known prod name), refuse — seeding there would write
  # fabricated rungs into the graph /factory and /u/<slug>/tasks both read.
  if [ "$TYPEDB_TEST_DB" = "${TYPEDB_DATABASE:-}" ] || [ "$TYPEDB_TEST_DB" = "one" ]; then
    return $(red "TYPEDB_TEST_DB is the PRODUCTION database — refusing to seed rungs into it")
  fi

  local out
  out=$(cd "$ROOT/one.ie/web" && \
        TYPEDB_URL="$TYPEDB_URL" \
        TYPEDB_USERNAME="$TYPEDB_USERNAME" \
        TYPEDB_PASSWORD="$TYPEDB_PASSWORD" \
        TYPEDB_TEST_DB="$TYPEDB_TEST_DB" \
        "${_GATE[@]}" bunx vitest run src/lib/resolvers/factory-ladder-live.test.ts 2>&1)

  # An empty scratch db answers "Type label 'thing' not found" — the schema was never
  # loaded there. That is an environment gap, not a broken ladder.
  printf '%s' "$out" | grep -qE "Type label '(thing|containment|blocks)' not found" \
    && return $(cannot "scratch db $TYPEDB_TEST_DB has no schema loaded — load schema/one.tql into it first")
  printf '%s' "$out" | grep -qE 'Failed to parse URL|ERR_INVALID_URL|signin failed' \
    && return $(cannot "scratch db named but the credentials did not reach vitest")

  # A SKIPPED test is not a proof. The test is `describe.skipIf(!TYPEDB_TEST_DB)`, so
  # without this guard vitest exits 0 having run nothing — the exact fail-open this
  # check exists to forbid.
  printf '%s' "$out" | grep -qE 'Tests[[:space:]]+.*skipped' \
    && return $(red "ladder-live tests SKIPPED — a skipped test is not a proof (fail-open)")
  printf '%s' "$out" | grep -qE 'Tests[[:space:]]+[1-9][0-9]*[[:space:]]+passed' \
    || return $(red "ladder-live tests did not pass — a seeded objective->deliverable->task did not come back nested")

  echo "ok   ladder-live (scratch db $TYPEDB_TEST_DB)"
}

case "$MODE" in
  ladder-live) check_ladder_live ;;
  *) echo "usage: factory-tasks-check.sh ladder-live" >&2; exit 2 ;;
esac
