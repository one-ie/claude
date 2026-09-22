#!/usr/bin/env bash
# do-preflight.sh <slug> [--fix] — refuse to launch a plan into a broken environment.
#
# manifest: needs-env
#
# WHY. Every expensive failure on 2026-08-31 was an ENVIRONMENT fault discovered
# only AFTER the run had spent itself:
#
#   - an unreachable model made W2 return nothing; W3 edited nothing, W4 verified
#     an empty diff, and the plan reported "batch total loss". 41 agents and 3.7M
#     tokens to learn that a model name was wrong.
#   - `.env` was not linked into the worktree, so real-TypeDB tests failed with
#     no_gateway_key and two verifiers hand-classified 4-7 red files as
#     "environmental" before they could score their gate.
#   - four abandoned gates held the box at load 138 and one held a governor slot,
#     so live cycles starved and verifiers began SKIPPING their gates and passing
#     cycles anyway.
#   - a cycle line the writers could tick was invisible to the engine's reader.
#
# Not one of those is a code defect, and every one is checkable in seconds. This
# is the cheap deterministic gate that runs first, so a run is never spent
# discovering something a grep could have said.
#
# Exit 0 = safe to launch. Exit 1 = a blocker (do not launch). Exit 2 = usage.
set -uo pipefail

SLUG="${1:-}"; shift 2>/dev/null || true
FIX=0
for f in "$@"; do case "$f" in --fix) FIX=1 ;; esac; done
[ -n "$SLUG" ] || { echo "usage: do-preflight.sh <slug> [--fix]" >&2; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WT="$ROOT/.do-worktrees/$SLUG"
bad=0; warn=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; bad=$((bad+1)); }
note() { printf '  warn  %s\n' "$1"; warn=$((warn+1)); }

echo "do-preflight: $SLUG"

# 1. The plan must PARSE. do-plan-json refuses (non-zero, no stdout) on a plan
#    missing worktree/outcome/batches/cycles, which is the failure that used to
#    surface as an LLM summarising a 30KB file down to 6.8KB.
if plan=$(node "$ROOT/.claude/scripts/do-plan-json.mjs" "$SLUG" 2>&1); then
  ok "plan parses ($(printf '%s' "$plan" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["cycles"]), "cycles,", len(d["batches"]), "batches")' 2>/dev/null || echo 'ok'))"
else
  fail "plan does not parse: $(printf '%s' "$plan" | head -1)"
fi

# 2. Worktree + the gitignored deps a worktree cannot inherit. A missing .env is
#    not a slow test -- it makes a verifier argue with its own gate and teaches
#    whoever reads the report that red is normal.
if [ -d "$WT" ]; then
  ok "worktree present"
  for dep in .env node_modules; do
    for where in "one.ie/web/$dep" "$dep"; do
      [ -e "$ROOT/$where" ] || continue
      if [ -e "$WT/$where" ]; then ok "linked: $where"; else
        if [ "$FIX" = "1" ]; then
          mkdir -p "$(dirname "$WT/$where")" && ln -s "$ROOT/$where" "$WT/$where" 2>/dev/null \
            && ok "linked: $where (repaired)" || fail "could not link $where"
        else
          fail "MISSING in worktree: $where — real-infra tests will fail as 'environmental'. Re-run with --fix"
        fi
      fi
      break
    done
  done
else
  note "no worktree yet at .do-worktrees/$SLUG (do-auto --setup-only will cut one)"
fi

# 3. The cycle-line shape must agree across its four implementations, or the
#    engine reads a different set of open cycles than the writers can tick.
if bash "$ROOT/.claude/scripts/do-cycle-shape-check.sh" >/dev/null 2>&1; then
  ok "cycle-line shape parity (reader == writer)"
else
  fail "cycle-shape parity RED — run .claude/scripts/do-cycle-shape-check.sh"
fi

# 4. A workflow with a syntax error does not fail loudly; it never launches.
if node "$ROOT/.claude/scripts/wf-check.mjs" >/dev/null 2>&1; then
  ok "workflow scripts parse + seam checks"
else
  fail "wf-check RED — run node .claude/scripts/wf-check.mjs"
fi

# 5. The box. A saturated box is why verifiers started skipping gates and
#    reporting passes anyway, so this is an ACCURACY check, not only a speed one.
orph=$(bash "$ROOT/.claude/scripts/gate-reaper.sh" --once --dry-run 2>/dev/null | grep -c 'WOULD reap' || true)
if [ "${orph:-0}" -gt 0 ]; then
  if [ "$FIX" = "1" ]; then
    bash "$ROOT/.claude/scripts/gate-reaper.sh" --once >/dev/null 2>&1
    ok "reaped ${orph} abandoned gate(s)"
  else
    fail "${orph} abandoned gate(s) burning the box — re-run with --fix, or gate-reaper.sh --once"
  fi
else
  ok "no abandoned gates"
fi

head=$(bash -c ". '$ROOT/.claude/scripts/lib/govern.sh'; gate_headroom" 2>/dev/null || echo 99)
loadi=$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/' | cut -d. -f1)
cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 8)
if [ "${loadi:-0}" -gt $(( cores * 3 )) ]; then
  note "load ${loadi} on ${cores} cores — gates will run slow; the governor will queue them"
else
  ok "load ${loadi} on ${cores} cores, memory funds ${head} concurrent cycle(s)"
fi

echo
if [ "$bad" -gt 0 ]; then
  echo "do-preflight: $bad blocker(s) — DO NOT LAUNCH. Every one of these is cheaper to fix now than to discover mid-run."
  exit 1
fi
echo "do-preflight: clear${warn:+ ($warn warning(s))} — safe to launch $SLUG"
exit 0
