#!/usr/bin/env bash
# Shared hook utilities. Source from any hook:
#   source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/hook.sh"
#
# is_hook_disabled <id>  — returns 0 (skip) or 1 (run)
# hook_session_key <json-arg>  — stable per-session key for temp files

# ── Runtime toggles ──────────────────────────────────────────────────────────
#
# ECC_DISABLED_HOOKS=hook:git-add-guard,hook:post-edit
#   Comma-separated hook IDs to skip. Useful in CI or setup scripts.
#
# ECC_HOOK_PROFILE=minimal|standard (default: standard)
#   minimal  — skips the post-edit lint
#   standard — all hooks active


is_hook_disabled() {
  local id="$1"
  local profile="${ECC_HOOK_PROFILE:-standard}"

  # Explicit disable list (comma-separated)
  if [[ -n "${ECC_DISABLED_HOOKS:-}" ]]; then
    local IFS=','
    for entry in $ECC_DISABLED_HOOKS; do
      # trim whitespace
      entry="${entry#"${entry%%[![:space:]]*}"}"
      entry="${entry%"${entry##*[![:space:]]}"}"
      [[ "$entry" == "$id" ]] && return 0
    done
  fi

  # Profile-based skips
  case "$profile" in
    minimal)
      case "$id" in
        hook:post-edit) return 0 ;;
      esac
      ;;
  esac

  return 1  # not disabled — run
}

# Derive a stable per-session key from the hook JSON payload ($1).
# Uses session_id from JSON if present; falls back to a cksum of the
# project dir so the key is consistent across hook invocations in one
# session even when CLAUDE_SESSION_ID isn't set.
hook_session_key() {
  local payload="${1:-}"
  local sid
  sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
  if [[ -n "$sid" ]]; then
    # Sanitise to filesystem-safe chars
    printf '%s' "$sid" | tr -dc 'a-zA-Z0-9_-' | cut -c1-48
    return
  fi
  # Fallback: hash of project dir
  printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}" | cksum | awk '{print $1}'
}

# ── Which channel actually delivered this hook's payload? ────────────────────
#
# hook_payload_channel "$@"  — echoes `argv`, `stdin` or `DARK`, and on a hit
# leaves the raw JSON in HOOK_PAYLOAD. Never non-zero; never blocks on a tty.
#
# WHY this exists. On 2026-08-21 all five blocking PreToolUse hooks were found
# to open with PAYLOAD="${1:-}" followed by [[ -z "$PAYLOAD" ]] && exit 0 —
# but Claude Code delivers on STDIN, so $1 was always empty and every one of
# them exited 0 before reading a field. They had been dark from the day they
# were written, and every presence check said "wired": declared in
# settings.json, forwarded by the runtime, executed. Only behaviour could see
# it. The channel is therefore not a thing to assume; it is a thing to NAME.
#
# The bound matters. A bare $(cat) hangs forever on a tty or an idle pipe and
# would freeze every session; the `! -t 0` guard plus an integer timeout is the
# shape the four live guards already use (bash 3.2 REJECTS a fractional -t —
# `read: 0.2: invalid timeout specification` — and its `-t 0` returns 1 even
# when data IS available, so neither a sub-second bound nor a true poll is
# reachable here). Note that `read -d ''` returns non-zero at EOF while still
# assigning what it read, which is why the read is `|| true` and the verdict is
# read off the VARIABLE, never off the exit code.
#
# What it deliberately does NOT do: make any caller refuse when the channel is
# DARK. An unproven guard reported as live is the house bug; a guard that
# refuses on an absent payload wedges the session. This reports. It never gates.
hook_payload_channel() {
  HOOK_PAYLOAD=""
  local a="${1:-}"
  if [[ -n "$a" && "$a" == *'{'* ]]; then
    HOOK_PAYLOAD="$a"
    printf 'argv'
    return 0
  fi
  if [[ ! -t 0 ]]; then
    local p=""
    IFS= read -r -d '' -t "${HOOK_PAYLOAD_TIMEOUT:-1}" p <&0 || true
    if [[ -n "$p" && "$p" == *'{'* ]]; then
      HOOK_PAYLOAD="$p"
      printf 'stdin'
      return 0
    fi
  fi
  printf 'DARK'
  return 0
}
