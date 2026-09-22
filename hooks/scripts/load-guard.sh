#!/usr/bin/env bash
# LOAD-GUARD — PreToolUse(Bash): refuse to pile a heavy gate onto a thrashing box.
#
# WHY (measured 2026-08-18): several sessions each ran `bun run verify`
# (tsc --noEmit + vitest over 875 files) at the same time on a 10-core/24GB Mac.
# Six tsc and three vitest pools ran concurrently -> load 57, swap 15.7/16 GB,
# ~26 MB/s of swapins. Starved by paging, each gate took 18 min instead of ~2,
# so sessions hit their Bash timeout and launched MORE. The box got slower the
# harder it was pushed.
#
# package.json's verify/test/check now route through gate-run.sh, but a session
# can still type `bunx tsc --noEmit` or `vitest run` straight into Bash and
# bypass the governor entirely (observed: pid 88114). This hook is the backstop
# for that path — it is the difference between a convention and a guarantee.
#
# Rule: a heavy, UNGOVERNED command is denied while the machine is already
# saturated. It is never denied on a healthy box, and never for the governed
# form (which queues by design rather than piling on).
#
# Disable: ECC_DISABLED_HOOKS=hook:load-guard

source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/hook.sh"
is_hook_disabled "hook:load-guard" && exit 0

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

# Already governed (gate-run.sh queues rather than piling) — always allow.
printf '%s' "$CMD" | grep -q 'gate-run\.sh' && exit 0
# Explicit opt-out for a deliberate full-throughput run.
[[ "${GOVERN_DISABLE:-0}" == "1" ]] && exit 0

# Heavy = spawns a long multi-core, multi-hundred-MB job.
# Heavy only when INVOKED, never when merely NAMED. The previous pattern
# matched the bare word anywhere in the command string, so `sed -n 1,60p
# vitest.config.ts` and a `git commit -m` whose message quoted `bun run
# verify` were both refused as though they were gates. Reading a config is
# not running a suite; both cost a retry through a temp file while fixing the
# engine on 2026-08-31.
#
# Anchor to command POSITION: start of the command or just after a shell
# operator, allowing leading env assignments and a bunx/npx/bun/npm runner.
# This decides only WHETHER the command is a heavy gate -- it still falls
# through to the saturation check below, which is what actually denies.
HEAVY_POS='(^|[;&|(]|&&|\|\|)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
_is_heavy=0
printf '%s' "$CMD" | grep -qE "${HEAVY_POS}((bunx|npx|bun|npm)[[:space:]]+)?(tsc[[:space:]]+--noEmit|vitest([[:space:]]+run)?|astro[[:space:]]+check|playwright[[:space:]]+test)" && _is_heavy=1
printf '%s' "$CMD" | grep -qE "${HEAVY_POS}(bun|npm)[[:space:]]+run[[:space:]]+(verify|test|typecheck|check)(:[a-z]+)?([[:space:]]|$)" && _is_heavy=1
[ "$_is_heavy" = "1" ] || exit 0
# `bun run test:raw` etc. are the deliberate escape hatches — still guarded, since
# their whole point is bypassing the cap.

CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 8)
LOAD1=$(uptime | sed -E 's/.*load averages?: //' | awk '{print int($1)}')
# FREE is the share of RAM genuinely available. It used to read memory_pressure's
# "free percentage", which counts file cache, purgeable and already-compressed
# pages as free: measured 2026-09-03, that said 74% while vm_stat said 1.3% and
# 9.4 GB sat in swap — so this guard's MEMORY arm could not fire on a thrashing
# box; only its load arm ever did. gate_mem_avail_mb is the honest quantity —
# two vm_stat/sysctl reads, no ps, no sleep, nothing on stdin (see the bounded
# -read scar above). Unreadable probe -> 100, i.e. this arm stays silent.
#
# The probe runs in a SUBSHELL with `set +eu`, and its failure is swallowed. A
# PreToolUse hook that dies mid-stream emits no deny decision, so the heavy gate
# proceeds — a guard that crashes fails OPEN. lib/hook.sh sets no -e/-u today,
# but nothing stops it from doing so tomorrow, and this arm must not be the
# reason a block silently stops happening. Anything other than a plain integer
# leaves FREE at 100, i.e. this arm stays silent.
FREE=100
_gv_lib="$CLAUDE_PROJECT_DIR/.claude/scripts/lib/govern.sh"
if [[ -r "$_gv_lib" ]]; then
  _pct=$( set +eu
          # shellcheck source=../scripts/lib/govern.sh
          source "$_gv_lib" 2>/dev/null || exit 0
          _a=$(gate_mem_avail_mb 2>/dev/null) || exit 0
          _t=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1048576 ))
          [ -n "$_a" ] && [ "$_t" -gt 0 ] && echo $(( _a * 100 / _t ))
          exit 0 ) 2>/dev/null
  [[ "$_pct" =~ ^[0-9]+$ ]] && FREE="$_pct"
fi

# How many heavy gates are already burning cores right now?
RUNNING=$(ps -Ao command= 2>/dev/null | grep -cE '(\.bin/tsc --noEmit|\.bin/vitest run|astro check)' || echo 0)

# Thresholds are env-tunable so they can be exercised in both directions —
# a guard that has only ever been seen to fire is an unproven guard.
LOAD_FACTOR="${GUARD_LOAD_FACTOR:-2}"
MIN_FREE="${GUARD_MIN_FREE_PCT:-10}"
MAX_RUNNING="${GUARD_MAX_RUNNING:-3}"

SAT=""
[[ "$LOAD1" -gt $(( CORES * LOAD_FACTOR )) ]] && SAT="load ${LOAD1} on ${CORES} cores"
[[ "$FREE" -lt "$MIN_FREE" ]]                 && SAT="${SAT:+$SAT; }free memory ${FREE}%"
[[ "$RUNNING" -ge "$MAX_RUNNING" ]]           && SAT="${SAT:+$SAT; }${RUNNING} heavy gates already running"
[[ -z "$SAT" ]] && exit 0           # healthy box — proceed

MSG="[load-guard] This machine is saturated ($SAT).

Starting another ungoverned build gate makes it slower, not faster: the box is
already paging, so every running gate takes ~10x longer and yours would too.

Run it through the governor instead — it queues for a free slot rather than
piling on, and kills its whole process group if it overruns:

  bash .claude/scripts/gate-run.sh verify -- <your command>

Or use the governed package script, which already does this:
  bun run verify     (in one.ie/web)

See what is holding the box:
  bash .claude/scripts/machine-check.sh --watch

Deliberate override:  GOVERN_DISABLE=1 <command>
Disable this hook:    ECC_DISABLED_HOOKS=hook:load-guard"

jq -nc --arg r "$MSG" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
exit 0
