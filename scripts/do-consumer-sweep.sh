#!/usr/bin/env bash
# do-consumer-sweep.sh — path-prefix table mapping a changed public surface to
# the commands that prove its consumers still build. W4's RECONCILES gate can
# see that A changed; it can't see that B silently broke because it imports A.
# This does — by rule, not by LLM judgment.
#
# Usage: do-consumer-sweep.sh [--exec] <changed-file>...
#        do-consumer-sweep.sh --self-test
#   default: prints one command per matched rule (no execution)
#   --exec:  also runs each printed command; any non-zero exit fails the sweep
set -euo pipefail

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

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

EXEC=false
FILES=()
for a in "$@"; do
  case "$a" in
    --exec)       EXEC=true ;;
    --self-test)  SELF_TEST=true ;;
    *)            FILES+=("$a") ;;
  esac
done
SELF_TEST="${SELF_TEST:-false}"

# rule: <path-prefix or exact path>|<command>  (one rule may repeat a prefix for multiple commands)
RULES='
packages/sdk/src/|(cd packages/cli && bun run test)
packages/sdk/src/|(cd packages/mcp && bunx tsc --noEmit)
schema/one.tql|(cd packages/sdk && bun run generate:base && git diff --exit-code src/generated/)
packages/sdk/src/receivers.ts|(cd one.ie/web && bunx vitest run tests/unit/done/surfaces.test.ts)
'

_match() {
  local f="$1" prefix cmd matched=false
  while IFS='|' read -r prefix cmd; do
    [ -z "$prefix" ] && continue
    case "$f" in
      "$prefix"*) matched=true; echo "$cmd" ;;
    esac
  done <<< "$RULES"
  $matched
}

if $SELF_TEST; then
  echo "[consumer-sweep] self-test: packages/sdk/src/client.ts"
  out=$(_match "packages/sdk/src/client.ts" || true)
  ok=true
  echo "$out" | grep -q "cd packages/cli && bun run test" || { echo "[consumer-sweep] FAIL: cli rule missing" >&2; ok=false; }
  echo "$out" | grep -q "cd packages/mcp && bunx tsc --noEmit" || { echo "[consumer-sweep] FAIL: mcp rule missing" >&2; ok=false; }
  $ok && echo "[consumer-sweep] self-test OK" || exit 1
  exit 0
fi

[ "${#FILES[@]}" -eq 0 ] && { echo "[consumer-sweep] no changed files given — nothing to sweep"; exit 0; }

any=false
rc=0
for f in "${FILES[@]}"; do
  cmds=$(_match "$f" || true)
  [ -z "$cmds" ] && continue
  any=true
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    echo "[consumer-sweep] $f → $cmd"
    if $EXEC; then
      "${_GATE[@]}" bash -c "$cmd" || { echo "[consumer-sweep] FAIL: consumer command failed for $f: $cmd" >&2; rc=1; }
    fi
  done <<< "$cmds"
done

$any || echo "[consumer-sweep] no rule matched any changed file — nothing to sweep"
exit "$rc"
