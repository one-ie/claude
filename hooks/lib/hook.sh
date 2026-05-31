#!/usr/bin/env bash
# Shared hook utilities. Source from any hook:
#   source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/hook.sh"
#
# is_hook_disabled <id>  — returns 0 (skip) or 1 (run)
# hook_session_key <json-arg>  — stable per-session key for temp files

# ── Runtime toggles ──────────────────────────────────────────────────────────
#
# ECC_DISABLED_HOOKS=hook:gate-guard,hook:stop-reflect
#   Comma-separated hook IDs to skip. Useful in CI or setup scripts.
#
# ECC_HOOK_PROFILE=minimal|standard (default: standard)
#   minimal  — skips signal emissions, reflect, session-end, post-edit lint
#   standard — all hooks active
#
# Per-hook disable: ECC_GATEGUARD=off  (alias for hook:gate-guard)

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
        hook:tool-signal|hook:stop-reflect|hook:session-end|hook:post-edit) return 0 ;;
      esac
      ;;
  esac

  # Per-hook env aliases
  case "$id" in
    hook:gate-guard)
      local v="${ECC_GATEGUARD:-}"
      [[ "$v" =~ ^(0|off|false|disabled|disable)$ ]] && return 0
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
