#!/usr/bin/env bash
# test-full.sh — THE full vitest suite. One definition, every caller.
#
# manifest: needs-env
#
# WHY THIS FILE EXISTS. The full suite had two callers that ran it with
# DIFFERENT arguments:
#
#   ./deploy   → test-cached.sh one.ie/web -- --testTimeout=15000 … --reporter=dot
#   /close     → bun run test → gate-run test -- vitest run   (no memo at all)
#
# test-cached.sh keys a PASS on the exact input, and the argv is part of that
# key. So the two callers could not share a stamp even on a byte-identical
# tree — and the /close path was not memoised in the first place. A warm tree
# therefore paid the full suite TWICE: once to close the plan, once to ship it,
# for inputs that had not moved between them.
#
# The fix is not a smarter cache. It is removing the second definition: both
# callers now run THIS script, so the argv they present to test-cached.sh is
# identical by construction and the second run is a hit.
#
# WHAT THIS IS NOT. It is not the fast lane's stamps being reused to shrink the
# full run. That was the first idea and it is unsound, recorded here so nobody
# rebuilds it:
#   · `vitest related --run <files>` and `vitest run` are different runs — fork
#     assignment and module-graph order differ. A file that passes in a 2-file
#     selection is NOT thereby proven in the 875-file pool, and this repo has
#     order-dependent shared-TypeDB suites.
#   · On a do/* branch the fast lane DEFERS the pins (.verify-fast-debt), so its
#     stamps systematically exclude the gates the full run exists to pay.
#   · The window is empty anyway: a fast stamp is valid only at tree-state T, and
#     the full gate is only slow when the tree is not T.
# The inputs to a full-pool run include the pool. Only a whole-suite pass may
# stand in for a whole-suite run.
#
# TEST_CACHE_PTY=1 for a non-TTY stdout (the deploy gate logs to a file, and the
# runner hangs there — see deploy.md "The vitest gate hangs").
# --check asserts no caller has grown a second definition.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FOLDER="${TEST_FULL_FOLDER:-one.ie/web}"

# The one definition. Changing a flag here changes it for every caller at once,
# which is the whole point — a flag added on one side only would split the key
# again and silently cost a second full suite.
ARGS=(--testTimeout=15000 --hookTimeout=15000 --teardownTimeout=15000 --reporter=dot)

# --- --check: the second definition must not come back ----------------------
# A caller that runs the full suite by hand gets a different argv, so its PASS
# cannot be reused by the other caller. That is invisible — everything is green,
# it just costs an extra ~3 minutes — so it needs a checker, not a comment.
if [ "${1:-}" = "--check" ]; then
  fails=0
  # deploy.sh must reach the suite through this script
  if grep -qE 'test-cached\.sh[^|]*one\.ie/web[^|]*--[^|]*--reporter' "$ROOT/.claude/scripts/deploy.sh"; then
    echo "FAIL: deploy.sh still spells out its own vitest args — it must call test-full.sh"; fails=$((fails+1))
  else echo "ok: deploy.sh has no second definition"; fi
  # package.json's `test` must not be a bare vitest run (test:raw is the escape)
  _t=$(python3 -c "import json;print(json.load(open('$ROOT/$FOLDER/package.json'))['scripts'].get('test',''))" 2>/dev/null)
  case "$_t" in
    *test-full.sh*) echo "ok: package.json test routes through test-full.sh" ;;
    *) echo "FAIL: package.json test is '$_t' — not routed through test-full.sh"; fails=$((fails+1)) ;;
  esac
  # and the two must present the SAME argv, which is only true if neither adds any
  # A caller may prefix env (TEST_CACHE_PTY=1) but must pass NO vitest args --
  # an arg on one side only splits the key and quietly costs a second full suite.
  _extra=$(grep -n 'test-full\.sh' "$ROOT/.claude/scripts/deploy.sh" | grep -- '--' | grep -v -- '--check' || true)
  if [ -n "$_extra" ]; then
    echo "FAIL: deploy.sh passes args to test-full.sh -- that splits the key:"; echo "$_extra"; fails=$((fails+1))
  else echo "ok: no caller adds arguments"; fi
  [ "$fails" -eq 0 ] && { echo "test-full: check PASS"; exit 0; }
  echo "test-full: check FAILED ($fails)"; exit 1
fi

# TWO LANES, not one run. The suite has two binding constraints — CPU for ~1126
# files, and one shared external TypeDB gateway for 19 — and a single 8-fork pool
# serves the second one so badly the gate became a coin flip (four runs on an
# unchanged tree: 8, 12, 13, 8 different failures). test-lanes.sh splits them and
# runs them concurrently. Measured 2026-09-03, same tree:
#   before  238-282s, RED, rotating victims
#   after   121.9s wall, GREEN — pool 1125 passed / typedb 19 passed
# It still reaches test-cached.sh (once per lane), so passes are still memoised
# and a RED is still never cached. ARGS above stays the one definition of the
# vitest flags; test-lanes.sh consumes it via TEST_FULL_ARGS.
export TEST_FULL_ARGS="${ARGS[*]}"
exec bash "$ROOT/.claude/scripts/test-lanes.sh"
