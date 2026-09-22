#!/usr/bin/env bash
# GOVERNOR-ESCAPE — PreToolUse(Bash): an executor cannot escape the governor.
#
# WHY (measured 2026-08-18): several sessions each ran the full verify on one
# 10-core/24GB Mac. Six tsc and three vitest pools ran at once -> load 57, swap
# 15.7/16 GB. Starved by paging, each gate took 18 MINUTES instead of ~2, so
# sessions hit their Bash timeout and launched MORE. The box got slower the
# harder it was pushed. gate-run.sh (slot + wall-bound + group-reap) is the fix.
#
# Four doors bypass all of it, and an agent taking one is invisible to every
# arbiter in factory-do.md's § Concurrency:
#   verify:raw · test:raw · a directly-typed vitest · GOVERN_DISABLE=1 / CI=1
#
# They exist for a HUMAN who means it. This hook is about an EXECUTOR reaching
# for one. hook:load-guard already refuses an ungoverned heavy command -- but
# only once load > 2x cores, free mem < 10%, or 3 gates are already burning.
# That is a check that fires AFTER the damage. This one fires INSTEAD of it.
#
# WHY A HOOK AND NOT A POST-HOC CHECK: the Bash tool does not carry shell state
# between calls, so an `export GOVERN_DISABLE=1` in one call is gone by the
# next. An env bypass therefore has to appear INLINE in the command string --
# which is precisely the surface a PreToolUse hook reads. For that class of
# escape prevention is not merely stronger than detection, it is complete.
# (Honest limit: this reads the command string, not an inherited environment.
# A GOVERN_DISABLE exported into the whole session's env is out of its view.)
#
# What counts as an escape lives in ONE place, shared with the checker:
#   .claude/hooks/lib/governor-escape-match.sh
# Proof, both directions (it bites / it does not false-positive):
#   bash .claude/scripts/governor-escape-check.sh
#
# Disable (the deliberate human override): ECC_DISABLED_HOOKS=hook:governor-escape

# shellcheck source=lib/hook.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh"
is_hook_disabled "hook:governor-escape" && exit 0
# shellcheck source=lib/governor-escape-match.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/governor-escape-match.sh"

PAYLOAD="${1:-}"

# ── REPO IDENTITY: this hook encodes ONE-monorepo machine policy ─────────────
# The governor, its slots and `gate-run.sh` exist only in one-ie/one. Outside it
# this hook would refuse a stranger's own `vitest`/`bun run verify` and point
# them at `.claude/scripts/gate-run.sh`, which they do not have — the shipped
# form of the defect hook-scope-check.sh pins for dev-only/branch-pin/
# git-add-guard. Same marker, same reason: `schema/one.tql` at the target repo's
# toplevel, offline, no remote needed, true in the primary tree, every linked
# worktree and `.release` alike. Not ours ⇒ ALLOW, silently.
_is_one_monorepo() {
  local d="$1" top
  [[ -d "$d" ]] || return 1
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || return 1
  [[ -n "$top" && -f "$top/schema/one.tql" ]]
}
_gate_cwd=$(printf '%s' "${PAYLOAD:-}" | jq -r '.cwd // empty' 2>/dev/null)
_is_one_monorepo "${_gate_cwd:-$PWD}" || exit 0

# Claude Code delivers the hook payload on STDIN; argv stays first so any
# caller that passes it positionally still works. Bounded read: a bare $(cat)
# would hang forever on a tty or an idle pipe, freezing every Bash call.
if [[ -z "$PAYLOAD" && ! -t 0 ]]; then
  IFS= read -r -d '' -t 2 PAYLOAD <&0 || true
fi
[[ -z "$PAYLOAD" ]] && exit 0

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL" == "Bash" ]] || exit 0

CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

KIND=$(gov_escape_kind "$CMD") || exit 0

case "$KIND" in
  env)    WHAT="an inline GOVERN_DISABLE= / CI= in front of a gate. gate-run.sh:26
execs straight through on either, so the slot, the wall-clock bound and the
process-group reap are all skipped." ;;
  raw)    WHAT="a \`:raw\` package script (verify:raw / test:raw). Those exist to
bypass the cap -- that is their whole definition." ;;
  vitest) WHAT="vitest invoked directly. It takes no slot, has no wall-clock
bound, and its forks reparent to launchd if the session dies." ;;
esac

MSG="[governor-escape] That command bypasses the machine governor.

Detected: $WHAT

Measured 2026-08-18, before the governor existed: concurrent ungoverned gates
took this box to load 57 and swap 15.7/16 GB, and each gate ran 18 minutes
instead of ~2. The box gets SLOWER the harder it is pushed, so one agent's
shortcut is every other agent's stall.

Run the same thing governed -- it queues for a free slot instead of piling on:

  bash .claude/scripts/gate-run.sh test -- bunx vitest run <path>
  bash .claude/scripts/gate-run.sh verify -- bun run verify

The cheap rungs of the gate ladder are still cheap: gate-run.sh is re-entrant
and returns immediately when a slot is free, so a targeted 0.4s test stays a
targeted 0.4s test.

Or use the governed package scripts, which already do this:
  bun run verify:fast     (the dev lane)
  bun run verify          (the review gate)

See what is holding the box:
  bash .claude/scripts/machine-check.sh --watch

Deliberate human override (session-level, on purpose, and visible):
  ECC_DISABLED_HOOKS=hook:governor-escape"

jq -nc --arg r "$MSG" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
exit 0
