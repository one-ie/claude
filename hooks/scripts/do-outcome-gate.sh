#!/bin/bash
# DO-OUTCOME-GATE — When the Plan close "outcome" box is ticked in a *-todo.md,
# run the plan's outcome: command and block if it fails.
# When text/<slug>.md exists, the todo's outcome: is the promise's proof: verbatim —
# this gate re-runs the contract's oracle (the same exit code do-promise-settle.sh
# settles at close).
#
# Fires: PostToolUse/Write|Edit on text/*-todo.md.
# Blocking (exit 1) — prevents a plan from closing while the kill-switch is red.
# Emits hook:do-outcome-gate:{ok,fail,dissolved} per Rule 1.

# shellcheck source=lib/signal.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/signal.sh"

# ── self-test: match / mismatch / no-promise fixtures ────────────────────────
# Fixtures live as disposable files under the real text/ dir (the hook resolves
# text/<slug>.md relative to $CLAUDE_PROJECT_DIR by design) — a prefixed slug and
# a trap-guaranteed cleanup keep this from touching anything real.
if [ "${1:-}" = "--self-test" ]; then
  PREFIX="__selftest-do-outcome-gate"
  cleanup() { rm -f "$CLAUDE_PROJECT_DIR/text/${PREFIX}"*.md; }
  trap cleanup EXIT
  fails=0

  # match — todo outcome: is the promise proof: verbatim → passes through (exit 0)
  printf -- '---\nproof: "true"\n---\n' >"$CLAUDE_PROJECT_DIR/text/${PREFIX}-match.md"
  printf -- '---\noutcome: "true"\n---\n\n- [x] **Plan outcome command exits 0**\n' >"$CLAUDE_PROJECT_DIR/text/${PREFIX}-match-todo.md"
  out=$(bash "$0" "$(jq -n --arg p "$CLAUDE_PROJECT_DIR/text/${PREFIX}-match-todo.md" '{tool_input:{file_path:$p}}')" 2>&1)
  rc=$?
  [ $rc -eq 0 ] || { echo "FAIL match → expected exit 0, got $rc"; echo "$out"; fails=$((fails+1)); }

  # mismatch — todo outcome: drifted from promise proof: → blocks (exit 1), shows both
  printf -- '---\nproof: "true"\n---\n' >"$CLAUDE_PROJECT_DIR/text/${PREFIX}-mismatch.md"
  printf -- '---\noutcome: "false"\n---\n\n- [x] **Plan outcome command exits 0**\n' >"$CLAUDE_PROJECT_DIR/text/${PREFIX}-mismatch-todo.md"
  out=$(bash "$0" "$(jq -n --arg p "$CLAUDE_PROJECT_DIR/text/${PREFIX}-mismatch-todo.md" '{tool_input:{file_path:$p}}')" 2>&1)
  rc=$?
  [ $rc -eq 1 ] || { echo "FAIL mismatch → expected exit 1, got $rc"; fails=$((fails+1)); }
  echo "$out" | grep -q 'outcome: false' || { echo "FAIL mismatch → outcome: not shown"; fails=$((fails+1)); }
  echo "$out" | grep -q 'proof:   true' || { echo "FAIL mismatch → proof: not shown"; fails=$((fails+1)); }

  # no-promise — no text/<slug>.md at all → existing behavior unchanged (runs outcome: as-is)
  printf -- '---\noutcome: "true"\n---\n\n- [x] **Plan outcome command exits 0**\n' >"$CLAUDE_PROJECT_DIR/text/${PREFIX}-nopromise-todo.md"
  out=$(bash "$0" "$(jq -n --arg p "$CLAUDE_PROJECT_DIR/text/${PREFIX}-nopromise-todo.md" '{tool_input:{file_path:$p}}')" 2>&1)
  rc=$?
  [ $rc -eq 0 ] || { echo "FAIL no-promise → expected exit 0 (unchanged), got $rc"; echo "$out"; fails=$((fails+1)); }

  echo "[do-outcome-gate] self-test: 3 fixtures, $fails failed"
  exit "$fails"
fi

FILE=$(echo "$1" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

# Only fire for text/*-todo.md
case "$FILE" in
  */text/*-todo.md) ;;
  *) exit 0 ;;
esac

# Only act when the plan outcome checkbox is now ticked [x]
grep -q '^\s*- \[x\] \*\*Plan outcome command exits 0\*\*' "$FILE" 2>/dev/null || exit 0

BASENAME=$(basename "$FILE")
SLUG="${BASENAME%-todo.md}"

# Extract outcome: value from YAML frontmatter (between first pair of ---)
OUTCOME=$(awk '
  BEGIN { in_front=0; done=0 }
  /^---/ { in_front++; next }
  in_front == 1 && /^outcome:/ { print; done=1 }
  in_front == 1 && done { exit }
  in_front == 2 { exit }
' "$FILE" | sed 's/^outcome:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")

if [ -z "$OUTCOME" ]; then
  echo "do-outcome-gate: no outcome: field in $BASENAME — cannot gate" >&2
  emit_signal "hook:do-outcome-gate:dissolved" -0.5 "slug=$SLUG reason=no-outcome-field"
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Cross-check: when text/<slug>.md (the promise) exists, its proof: is the single
# oracle — the todo's outcome: must be that proof verbatim (whitespace-normalized),
# never a drifted restatement. A drifted todo could gate green on the wrong
# condition while the promise itself proves nothing. Comparison only — the exec
# allowlist below is unchanged.
PROMISE_FILE="text/${SLUG}.md"
if [ -f "$PROMISE_FILE" ]; then
  PROOF=$(awk '
    BEGIN { in_front=0; done=0 }
    /^---/ { in_front++; next }
    in_front == 1 && /^proof:/ { print; done=1 }
    in_front == 1 && done { exit }
    in_front == 2 { exit }
  ' "$PROMISE_FILE" | sed 's/^proof:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")

  if [ -n "$PROOF" ]; then
    NORM_OUTCOME=$(printf '%s' "$OUTCOME" | tr -s '[:space:]' ' ' | sed -E 's/^ +| +$//g')
    NORM_PROOF=$(printf '%s' "$PROOF" | tr -s '[:space:]' ' ' | sed -E 's/^ +| +$//g')
    if [ "$NORM_OUTCOME" != "$NORM_PROOF" ]; then
      echo "" >&2
      echo "DO-OUTCOME-GATE BLOCKED: todo outcome: does not match promise proof: verbatim" >&2
      echo "  outcome: $OUTCOME" >&2
      echo "  proof:   $PROOF" >&2
      echo "text/${SLUG}.md and $BASENAME have drifted — reconcile before this box can be ticked." >&2
      emit_signal "hook:do-outcome-gate:fail" -1 "slug=$SLUG reason=proof-outcome-mismatch"
      exit 1
    fi
  fi
fi

# Safety: allowlist only the characters that appear in real outcome commands —
# cd/bun/vitest paths chained with &&. Everything else ($ backtick ; < > ( ) '
# " newlines) is an injection vector. Denylist approach has gaps; allowlist
# does not. Skip the gate (non-blocking) on any violation.
if ! printf '%s' "$OUTCOME" | grep -qE '^[-a-zA-Z0-9 /._&=|]+$'; then
  echo "do-outcome-gate: outcome command contains characters outside the safe allowlist — skipping gate (manual check required)" >&2
  emit_signal "hook:do-outcome-gate:dissolved" -0.3 "slug=$SLUG reason=unsafe-outcome-syntax"
  exit 0
fi

echo "do-outcome-gate: running plan kill-switch for $SLUG..." >&2
# THROUGH THE GOVERNOR. Fifteen text/*-todo.md carry `bun run verify` in
# outcome:, and one of them was already ticked — so an edit to that file fired a
# FULL suite plus an ungoverned bare vitest from a PostToolUse hook, with nothing
# asking for a slot (text/factory-do.md § Deploy is the ship gate, measured
# 2026-09-03). The hook is the N-agents-N-full-suites shape exactly when twelve
# sessions each tick a box. gate-run.sh queues it behind the machine-wide cap
# and prices it against real free memory; the wait is bounded so a hook never
# holds an editor for the governor's default 30 minutes. No slot inside the
# bound is NOT a pass — the box is the claim, and the box is not ticked: exit 1
# says so and names the fix. `bun run verify` inside the string is itself
# wrapped, and gate-run is re-entrant, so this is one slot, not two.
GATE="$CLAUDE_PROJECT_DIR/.claude/scripts/gate-run.sh"
if [ -f "$GATE" ]; then
  GOVERN_QUEUE_WAIT="${DO_OUTCOME_GATE_WAIT:-120}" bash "$GATE" outcome-gate -- bash -c "$OUTCOME" 2>&1
  EXIT=$?
else
  bash -c "$OUTCOME" 2>&1
  EXIT=$?
fi

if [ $EXIT -eq 0 ]; then
  emit_signal "hook:do-outcome-gate:ok" 1 "slug=$SLUG"
  exit 0
fi

echo "" >&2
echo "DO-OUTCOME-GATE BLOCKED: plan kill-switch failed (exit $EXIT)" >&2
echo "Command: $OUTCOME" >&2
echo "The plan outcome must exit 0 before this box can be ticked." >&2
emit_signal "hook:do-outcome-gate:fail" -1 "slug=$SLUG exit=$EXIT"
exit 1
