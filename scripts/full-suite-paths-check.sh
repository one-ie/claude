#!/bin/bash
# full-suite-paths-check.sh — sweep for unaccounted paths to the full test suite
#
# The full suite is run in three places: package.json callers (via test-full.sh),
# hooks, and outcome: strings in text/*-todo.md. This script sweeps all three
# surfaces and compares against a reviewed allowlist.
#
# manifest: portable
#
# Exit 0: all paths accounted for.
# Exit 1: a path found that is not in the allowlist (new caller, new hook, new outcome).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- The allowlist — paths we have reviewed and accept -----------------------
# Format:
#   caller:<file>:<pattern>  — a package.json script that runs the full suite
#   hook:<file>              — a hook that runs the full suite
#   outcome:<file>:<line>    — an outcome: string in a todo file
#
# This list is built by examining the sources and is NOT auto-generated.
ALLOWLIST=(
  # Package.json callers: test-full.sh --check verifies no duplicates here
  # (gates route through test-full.sh, not duplicated across callers)

  # Hooks: must not run the full suite (but may mention it in comments)
  # task-complete-verify.sh had bun run verify removed (documented in comments)

  # Outcome strings in text/*-todo.md (these are the 15 known paths that need
  # to be routed through gate-run.sh or otherwise accounted for)
  "outcome:text/best-practices-todo.md:12"
  "outcome:text/blocks-todo.md:17"
  "outcome:text/campaigns-reimagined-todo.md:12"
  "outcome:text/composio-todo.md:13"
  "outcome:text/dashboard-personas-todo.md:10"
  "outcome:text/dashboard-todo.md:10"
  "outcome:text/inbox-simplify-todo.md:10"
  "outcome:text/inbox-ui-simple-todo.md:10"
  "outcome:text/inbox-ui-todo.md:11"
  "outcome:text/lifecycle-loop-todo.md:21"
  "outcome:text/pack-starter-workflows-todo.md:12"
  "outcome:text/payments-integrated-todo.md:29"
  "outcome:text/roles-act-as-switcher-todo.md:11"
  "outcome:text/roles-final-todo.md:10"
  "outcome:text/voice-agents-todo.md:13"
)

# --- Check package.json callers -----------------------------------------------
# test-full.sh --check ensures no caller duplicates the vitest argv
if ! bash "$ROOT/.claude/scripts/test-full.sh" --check; then
  echo "FAIL: test-full.sh --check found a duplicate caller" >&2
  exit 1
fi
echo "✓ package.json callers: test-full.sh --check passed"

# --- Sweep hooks for full suite invocations ----------------------------------
# Read all hooks and look for patterns that EXECUTE the full suite.
# We exclude: comments (#), error message output (echo/cat), code examples in help text.
# We include: actual shell execution like $(bun run verify) or command substitution.
found_hooks=()
for hook in "$ROOT"/.claude/hooks/*.sh; do
  [ -f "$hook" ] || continue
  # Look for ACTUAL EXECUTION patterns:
  #  - $(bun run verify) — command substitution (not in echo/cat/string)
  # Ignore: comments (#), plain text mentions in error messages
  if grep -E '^\s*\$\(.*bun run verify' "$hook" >/dev/null 2>&1; then
    found_hooks+=("$(basename "$hook")")
  fi
done

if [ ${#found_hooks[@]} -gt 0 ]; then
  echo "FAIL: hooks running full suite (should be routed through gate-run.sh or removed):" >&2
  for h in "${found_hooks[@]}"; do
    echo "  hook:$h" >&2
  done
  exit 1
fi
echo "✓ hooks: none running full suite directly"

# --- Sweep outcome: strings in todo files ------------------------------------
# Count each `outcome:` field that contains `bun run verify` and check against allowlist
found_outcomes=()
for todofile in "$ROOT"/text/*-todo.md; do
  [ -f "$todofile" ] || continue
  # Use relative path from ROOT (e.g., text/best-practices-todo.md)
  relpath="${todofile#$ROOT/}"

  # Find all lines with outcome: (frontmatter field or inline)
  while IFS=: read -r linenum line; do
    # Check if this line contains bun run verify (unrouted)
    if echo "$line" | grep -q "bun run verify"; then
      found_outcomes+=("outcome:$relpath:$linenum")
    fi
  done < <(grep -n "^outcome:" "$todofile" 2>/dev/null || true)
done

# --- Compare against allowlist -----------------------------------------------
failed=0

# Check for new outcomes not in allowlist
if [ ${#found_outcomes[@]:-0} -gt 0 ]; then
  for found in "${found_outcomes[@]}"; do
    in_allowlist=0
    for allowed in "${ALLOWLIST[@]}"; do
      if [ "$found" = "$allowed" ]; then
        in_allowlist=1
        break
      fi
    done
    if [ $in_allowlist -eq 0 ]; then
      echo "FAIL: unaccounted path to full suite: $found" >&2
      failed=1
    fi
  done
fi

# Check for allowlist entries that no longer exist (removed paths)
for allowed in "${ALLOWLIST[@]}"; do
  found_match=0
  if [ ${#found_outcomes[@]:-0} -gt 0 ]; then
    for found in "${found_outcomes[@]}"; do
      if [ "$found" = "$allowed" ]; then
        found_match=1
        break
      fi
    done
  fi
  if [ $found_match -eq 0 ]; then
    # Extract the file:line from the allowlist entry
    if [[ $allowed == outcome:* ]]; then
      echo "INFO: allowlist entry no longer exists (may be fixed): $allowed" >&2
    fi
  fi
done

if [ $failed -eq 1 ]; then
  exit 1
fi

echo "✓ outcome strings: all ${#found_outcomes[@]} accounted for"
echo "✓ full-suite-paths-check.sh: all paths verified"
exit 0
