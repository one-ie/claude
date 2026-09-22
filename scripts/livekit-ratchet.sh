#!/usr/bin/env bash
# livekit-ratchet.sh — monorepo-only (hard-asserts against one.ie/web).
#
# Proves the LiveKit block family stayed collapsed: exactly ONE registration
# (`LiveRoom`), no second prefab smuggled either into livekit-blocks.tsx or
# straight into config.tsx's withChrome({...}) merge.
#
# Exit 0 = still one block. Exit 1 = the family re-split (or the test vanished).
# No pipes on purpose: `producer | grep -q` returns 141 on a match here.

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


ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

TEST_REL="tests/unit/puck/livekit-ratchet.test.ts"

# A vitest run whose path filter matches nothing exits 0. Assert the file first.
if [ ! -f "one.ie/web/$TEST_REL" ]; then
  echo "livekit-ratchet FAIL — missing one.ie/web/$TEST_REL" >&2
  exit 1
fi

(cd one.ie/web && "${_GATE[@]}" bunx vitest run "$TEST_REL") || {
  echo "livekit-ratchet FAIL — more than one LiveKit block is registered" >&2
  exit 1
}

echo "livekit-ratchet OK — exactly one LiveKit block (LiveRoom)"
