#!/usr/bin/env bash
# Test the load-guard's heavy-command matcher. Lives in a file because the cases
# manifest: portable
# ARE command strings -- putting them in the command would make the hook match on
# the test itself, which is what happened twice while writing this.
POS='(^|[;&|(]|&&|\|\|)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
A="${POS}((bunx|npx|bun|npm)[[:space:]]+)?(tsc[[:space:]]+--noEmit|vitest([[:space:]]+run)?|astro[[:space:]]+check|playwright[[:space:]]+test)"
B="${POS}(bun|npm)[[:space:]]+run[[:space:]]+(verify|test|typecheck|check)(:[a-z]+)?([[:space:]]|\$)"

heavy() {
  local c="$1" h=0 out
  out=$(printf '%s' "$c" | grep -cE "$A" || true); [ "${out:-0}" -gt 0 ] && h=1
  out=$(printf '%s' "$c" | grep -cE "$B" || true); [ "${out:-0}" -gt 0 ] && h=1
  echo "$h"
}

bad=0
check() { # check <expected 1|0> <command>
  local want="$1" cmd="$2" got
  got=$(heavy "$cmd")
  if [ "$got" = "$want" ]; then
    printf '  ok    %-6s %s\n' "$([ "$want" = 1 ] && echo BLOCK || echo allow)" "$cmd"
  else
    printf '  FAIL  %-6s %s\n' "$([ "$want" = 1 ] && echo BLOCK || echo allow)" "$cmd"
    bad=$((bad + 1))
  fi
}

echo "--- must be treated as a heavy gate ---"
V=verify; T=test
check 1 "bun run $V"
check 1 "cd one.ie/web && bun run $T"
check 1 "bunx vitest run"
check 1 "bunx tsc --noEmit"
check 1 "VITEST_MAX_FORKS=2 bunx vitest run"
check 1 "cd x; npx playwright test"
check 1 "bun run $V:fast"
check 1 "bun run check:ratchet"

echo "--- must NOT be (merely names a gate) ---"
check 0 "sed -n '1,60p' vitest.config.ts"
check 0 "git commit -m 'perf: bun run $V is the review gate'"
check 0 "cat one.ie/web/vitest.config.ts"
check 0 "grep -rn 'bun run $V' .claude/"
check 0 "echo the astro check ratchet is a doc phrase"
check 0 "ps -Ao pcpu=,command= | sort -rn"

echo
[ "$bad" -eq 0 ] && echo "RESULT: all correct" || { echo "RESULT: $bad wrong"; exit 1; }
