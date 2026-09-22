#!/bin/bash
# TASK-COMPLETE VERIFY — a READER, not a runner. Fires on TaskCompleted.
#
# WHAT IT USED TO DO, measured 2026-09-04: `cd "$CLAUDE_PROJECT_DIR" && bun run
# verify`. The repo root has no package.json, so bun answered "Script not found",
# EXIT was 1, and this hook — wired `blocking: true` on matcher `*` — printed
# "W4 GATE BLOCKED: Verification failed" for EVERY task completion in every
# session, over a suite that never ran (plus an `integer expression expected`
# from parsing that output). A false red on every task is a gate nobody reads.
#
# And the version that "worked" would be worse. TaskCompleted fires per subagent
# task, in every session; twelve sessions completing tasks is twelve full suites
# — the N-agents-N-full-suites shape that thrashed this box on 2026-08-18
# (load 57, swap full, 18-minute gates). text/factory-do.md § Deploy is the ship
# gate names this hook as "one file away from running the full suite on every
# task completion", and the fix is not a governed run — it is that this hook
# does not run a suite at all. The suite has owners: W4 runs `verify:fast`
# through the governor and the memo; /close and ./deploy run the full lane.
#
# WHAT IT DOES NOW — two deterministic reads, milliseconds, no gate:
#   1. the deferred-pin ledger: an outstanding debt on `main` means a plan
#      landed without reaching its close gate. Named, never paid here.
#   2. the governor: a slot held by a DEAD pid is an orphaned gate. Named.
# Both are reports. Neither blocks — a task is not the place to pay a plan's
# debt, and a hook that blocks on a neighbour's orphan punishes the wrong
# session. Exit 0 always, with the facts in the signal.
#
# Emits hook:w4-verify:{ok,debt,orphan} per Rule 1 (see .claude/skills/signal.md).

# shellcheck source=lib/signal.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/signal.sh"

DEBT_FILE="${VERIFY_FAST_DEBT_FILE:-${TMPDIR:-/tmp}/one-verify-fast-debt}"
GOVERN_DIR="${GOVERN_DIR:-${TMPDIR:-/tmp}/one-govern}"

notes=""
if [ -s "$DEBT_FILE" ]; then
  n=$(wc -l < "$DEBT_FILE" | tr -d ' ')
  br=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "?")
  echo "verify: $n deferred pin run(s) owed (branch $br) — paid by a GREEN full lane at /close or ./deploy, never here" >&2
  emit_signal "hook:w4-verify:debt" 0 "deferred_pins=$n branch=$br"
  notes="debt=$n"
fi

orphans=0
for d in "$GOVERN_DIR"/lock-slot-*; do
  [ -d "$d" ] || continue
  pid=$(cat "$d/pid" 2>/dev/null)
  [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null && orphans=$((orphans + 1))
done
if [ "$orphans" -gt 0 ]; then
  echo "verify: $orphans governor slot(s) held by a dead pid — reaped on the next contender; \`bash .claude/scripts/gate-reaper.sh --dry-run\` to see them" >&2
  emit_signal "hook:w4-verify:orphan" 0 "stale_slots=$orphans"
  notes="${notes:+$notes }orphans=$orphans"
fi

[ -z "$notes" ] && emit_signal "hook:w4-verify:ok" 1 "reader: no debt, no orphaned slot"
exit 0
