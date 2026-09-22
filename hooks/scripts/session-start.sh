#!/bin/bash
# SESSION-START — reclaim what a dead session left behind — and, since
# 2026-09-13, break the one jam whose owners are both ALIVE — then NAME the
# channel this hook's payload arrived on, then tell the world a session began.
#
# `_gv_reap` only fires when someone CONTENDS for a lock, so a session that died
# holding a governor slot would shrink GOVERN_MAX_GATES until the next contender
# happened along; region claims evaporate the same way. Sweep both here. The
# sweeps are silent unless something was actually reclaimed; the payload line
# below prints EVERY time, because a channel nobody names is a channel that goes
# dark unnoticed — which is the whole reason it is there.
#
# What this hook no longer does (removed 2026-09-05, each measured): a find+stat
# over eight modules for a "hot module" hint (5.8s of the session's first
# prompt, decorative), and a count of .claude/improvements.queue.md proposals
# (a queue nothing consumed — 445 unaddressed, zero git history of a drain).
#
# Emits hook:session-start:ok and world session:start (Rule 1).

# shellcheck source=lib/signal.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/signal.sh"
cd "$CLAUDE_PROJECT_DIR" || exit 0

# ── Name the payload channel — live or dark ─────────────────────────────────
# Four Bash guards (git-add-guard, branch-pin, load-guard, governor-escape) read
# their JSON payload from stdin, and every one of them falls through to ALLOW
# when it is empty. That fall-through is the RIGHT failure mode — a guard that
# refused on an absent payload would wedge the session — but it also means a
# channel that has gone dark is indistinguishable from a session with nothing to
# refuse. That is not hypothetical: on 2026-08-21 all five blocking PreToolUse
# hooks read the payload from $1 while the runtime was writing stdin, so they
# had been dark since the day they were written, and every presence check said
# "wired" — declared in settings.json, forwarded, executed. Only behaviour could
# see it.
#
# So the channel gets NAMED here, out loud, once per session: argv, stdin, or
# DARK when neither delivered. This REPORTS. It gates nothing, and it changes no
# guard's refusal behaviour — an unproven guard reported as live is the house
# bug, but a guard that refuses on absence wedges the session, which is worse.
#
# It runs before the reaper and the watchdog on purpose: those are children and
# inherit fd 0, so a payload left unread here is a payload one of them can eat.
# Resolved off BASH_SOURCE, not CLAUDE_PROJECT_DIR: that variable is set by the
# runtime and is UNSET in a plain shell, so a `bash .claude/hooks/session-start.sh`
# (which is exactly how this rung's proof invokes it) would source "/.claude/..."
# and the probe would print an empty channel — a hook reporting nothing about
# whether it can see anything.
source "${BASH_SOURCE[0]%/*}/lib/hook.sh"
echo "hook payload: $(hook_payload_channel "${1:-}")"

# ── the secret scan, installed as a git hook ────────────────────────────────
# `.git/hooks/` is UNTRACKED, so the tracked pre-commit body
# (.claude/hooks/git/pre-commit) cannot install itself — a clone, a fresh
# worktree and this session all start without it. This is the install, and it
# lives here because this hook already runs once per session and nothing else
# does. Idempotent: the installer compares the shim it would write against the
# one already there and returns without touching the file when they match, so
# the steady-state cost is one `git rev-parse` and one `cat` (measured ~15ms).
# It is DELIBERATELY not fatal and deliberately quiet — a session that cannot
# install the hook is still a usable session, and the gate that matters is the
# one git runs at commit time. Contract: text/do-factory-plan.md § A3.
if [ -x "$CLAUDE_PROJECT_DIR/.claude/scripts/factory-secret-gate.sh" ]; then
  bash "$CLAUDE_PROJECT_DIR/.claude/scripts/factory-secret-gate.sh" --install --quiet >/dev/null 2>&1 </dev/null || true
fi

SWEPT=0; CLAIMS_SWEPT=0
if [ -f "$CLAUDE_PROJECT_DIR/.claude/scripts/lib/govern.sh" ]; then
  . "$CLAUDE_PROJECT_DIR/.claude/scripts/lib/govern.sh" 2>/dev/null || true
  SWEPT=$(gate_sweep_stale 2>/dev/null || echo 0)
  CLAIMS_SWEPT=$(claim_sweep 2>/dev/null || echo 0)
fi

# An `astro dev` / `wrangler dev` that dies leaves its workerd child reparented
# to launchd, holding ~40MB until the box reboots. gate-reaper.sh has known that
# shape since 2026-09-05 but nothing ever RAN it: on 2026-09-05 nineteen of them
# had accumulated over 13 hours and the box sat at 20.5G of 21.5G swap with
# 997MB free. Reaping them returned swap to 7.8G used / 8.6G free in three
# seconds. The reaper is 60ms, silent when there is nothing to do, and gated on
# ppid==1 + a gate shape + a 15-minute age floor, so it can never touch live work.
REAPED=0
if [ -x "$CLAUDE_PROJECT_DIR/.claude/scripts/gate-reaper.sh" ]; then
  REAPED=$(bash "$CLAUDE_PROJECT_DIR/.claude/scripts/gate-reaper.sh" --once 2>/dev/null </dev/null | grep -c '^\[gate-reaper\] reaped' || true)
fi

# The reaper reaps a DEAD owner. The 2026-09-13 deadlock has two LIVE owners —
# a lock holder with no slot, and a slot holder waiting on that lock — so no
# reaper could ever see it, and it stalled every session on the box for 8-28
# minutes at 0% CPU, three times in 35 minutes. gate-watchdog is the one thing
# that cuts it. A healthy box costs 0.12s and prints nothing; it only spends the
# confirm delay when it has already found a jam. Its predicate is positive
# evidence of a closed cycle (--self-test drives all 14 checks, both halves), so
# a slow-but-working gate is never the victim and a slot owner never is either.
JAMMED=0
if [ -x "$CLAUDE_PROJECT_DIR/.claude/scripts/gate-watchdog.sh" ]; then
  JAMMED=$(bash "$CLAUDE_PROJECT_DIR/.claude/scripts/gate-watchdog.sh" --once 2>/dev/null </dev/null | grep -c '^\[gate-watchdog\] BREAK' || true)
fi

OUT=""
[ "${JAMMED:-0}" -gt 0 ] 2>/dev/null && OUT+="🧹 broke ${JAMMED} governor deadlock(s) — a lock was held with no slot while every slot sat idle\n"
[ "${REAPED:-0}" -gt 0 ] 2>/dev/null && OUT+="🧹 reaped ${REAPED} abandoned gate(s)/workerd orphan(s) burning the box\n"
[ "${SWEPT:-0}" -gt 0 ] 2>/dev/null && OUT+="🧹 reclaimed ${SWEPT} stale build slot(s) from a dead session\n"
[ "${CLAIMS_SWEPT:-0}" -gt 0 ] 2>/dev/null && OUT+="🧹 reclaimed ${CLAIMS_SWEPT} region claim(s) from a dead worker\n"
[ -n "$OUT" ] && { echo ""; printf "%b" "$OUT"; echo ""; }

emit_signal "hook:session-start:ok" 1 "swept=${SWEPT:-0} claims=${CLAIMS_SWEPT:-0} reaped=${REAPED:-0} jams=${JAMMED:-0}"
emit_world "session:start" "fyi" "session,start" "session started" "swept=${SWEPT:-0}" "claims=${CLAIMS_SWEPT:-0}" "reaped=${REAPED:-0}" "jams=${JAMMED:-0}"
exit 0
