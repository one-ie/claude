#!/usr/bin/env bash
# Shared signal emitter — every Claude Code session broadcasts RICH signals to the world.
# Source from any hook:
#   source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/signal.sh"
#   emit_world  <type> <priority> <tags_csv> <text> [key=value ...]   # rich session/world signal
#   emit_signal <receiver> <weight> [data...]                         # back-compat, routed as a world tag
#
# Every signal is a fire-and-forget POST to /api/ask/world:announce — the PUBLIC front
# door, now sent with the service credential (GATEWAY_API_KEY / GATEWAY_SERVICE_SECRET)
# so the gateway accepts it (armed in prod — see text/code-signals-plan.md) and
# world:announce can attest a sender identity for it (slug:"one"). world:announce reads
# data.tags and fans the payload to every subscriber whose follow-tags intersect,
# marking each delivery (closed loop). A hook must broadcast to the world, never write raw
# substrate — direct /api/signal is gateway-guarded by design.
# Contract: one.ie/web/src/lib/resolvers/subscriptions.ts (world:announce · subscriptions:register)
# Point ONE_API_URL at https://one.ie to broadcast into the live world instead of local dev.

# The world is https://one.ie — the same door the factory executor and
# do-signal.sh post to. Until 2026-09-05 this defaulted to localhost:4321, so
# every session:start / session:intent signal landed in the operator's local
# dev D1 (matched 0) or nowhere when no dev server was up. ONE_API_URL still
# overrides for local work. Measured the same day: the prod door answers in
# 1.3-2.0s (D1 in APAC, TypeDB in Virginia — text/factory-do.md § GATES ›
# Signals), so the cap below is 8s, not the 2s that dropped every post.
_one_world_url() { printf '%s' "${ONE_API_URL:-https://one.ie}/api/ask/world:announce"; }

# Where the service credential lives — hooks don't reliably inherit a login shell's
# exports, so read straight out of the web env file (same pattern do-signal.sh
# established). The LOCAL astro/wrangler dev server reads secrets from .dev.vars, not
# .env — they hold DIFFERENT values, so which file we read must match ONE_API_URL's
# target: localhost → .dev.vars, anything else (prod) → .env. Override with DO_ENV_FILE.
# An explicitly-exported shell var always wins over either file.
_one_env_file() {
  [ -n "${DO_ENV_FILE:-}" ] && { printf '%s' "$DO_ENV_FILE"; return 0; }
  local root="${CLAUDE_PROJECT_DIR:-$PWD}" url="${ONE_API_URL:-http://localhost:4321}"
  case "$url" in
    *localhost*|*127.0.0.1*) printf '%s' "$root/one.ie/web/.dev.vars" ;;
    *) printf '%s' "$root/one.ie/web/.env" ;;
  esac
}
_one_secret() { # $1 = VAR name → value or empty, never printed by any caller
  local val="${!1:-}"
  if [ -n "$val" ]; then printf '%s' "$val"; return 0; fi
  local f; f="$(_one_env_file)"
  [ -f "$f" ] || return 0
  grep -E "^$1=" "$f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//'
}

# Rich broadcast — the structured envelope the routing + marketplace can stake on.
emit_world() {
  local type="${1:-event}" priority="${2:-fyi}" tags_csv="${3:-}" text="${4:-}"
  shift 4 2>/dev/null || true
  command -v jq >/dev/null 2>&1 || return 0   # rich payload needs jq; degrade silently, never block

  local session="${CLAUDE_SESSION_ID:-${CC_SESSION_ID:-unknown}}"
  local root="${CLAUDE_PROJECT_DIR:-$PWD}"
  local proj branch; proj="$(basename "$root")"
  branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '')"

  # extra key=value pairs → JSON object
  local extras='{}' kv k v
  for kv in "$@"; do
    [ -z "$kv" ] && continue
    k="${kv%%=*}"; v="${kv#*=}"
    extras="$(jq -c --arg k "$k" --arg v "$v" '. + {($k):$v}' <<<"$extras" 2>/dev/null || printf '%s' "$extras")"
  done

  # tags: caller csv + always-on cc/session/<proj>/<type> so any subscriber can route it
  local tags_json
  tags_json="$(jq -Rc --arg proj "$proj" --arg type "$type" \
    'split(",")|map(select(length>0)) + ["cc","session",$proj,$type]|unique' <<<"$tags_csv" 2>/dev/null || printf '%s' '["cc","session"]')"

  # slug/board are the service-caller nomination pair (text/code-signals-plan.md § The
  # pairing constraint): "one" is the platform's own workspace (PLATFORM_SLUG default,
  # world-receivers.ts), "marketplace" is the one board a sender and a differently-
  # identified subscriber can both land in — world:announce never delivers to its own
  # sender. Only honored server-side when the request also authenticates below.
  local payload
  payload="$(jq -nc \
    --argjson tags "$tags_json" --argjson extras "$extras" \
    --arg type "$type" --arg text "$text" --arg pri "$priority" \
    --arg sender "cc:$proj" --arg session "$session" --arg proj "$proj" --arg branch "$branch" \
    --arg slug "${CC_WORLD_SLUG:-one}" \
    '{sender:$sender, data: ({tags:$tags, type:$type, text:$text, priority:$pri, session:$session, cwd:$proj, branch:$branch, source:"claude-code", slug:$slug, board:"marketplace"} + $extras)}' 2>/dev/null)"
  [ -z "$payload" ] && return 0

  local -a hdr=(-H 'Content-Type: application/json')
  local api_key gw_secret authcfg=""
  api_key="$(_one_secret GATEWAY_API_KEY)"
  gw_secret="$(_one_secret GATEWAY_SERVICE_SECRET)"
  if [ -n "$api_key" ] || [ -n "$gw_secret" ]; then
    # Secrets off argv (ps aux would leak a bare -H value) — fold both into a
    # private 0600 curl --config file instead.
    authcfg="$(mktemp)"; chmod 600 "$authcfg"
    [ -n "$api_key" ] && printf 'header = "Authorization: Bearer %s"\n' "$api_key" >>"$authcfg"
    [ -n "$gw_secret" ] && printf 'header = "X-Gateway-Key: %s"\n' "$gw_secret" >>"$authcfg"
    hdr+=(--config "$authcfg")
  fi

  ( curl -sS -o /dev/null --max-time "${ONE_WORLD_TIMEOUT:-8}" -X POST "$(_one_world_url)" \
      "${hdr[@]}" -d "$payload" >/dev/null 2>&1
    [ -n "$authcfg" ] && rm -f "$authcfg" ) &
  return 0
}

# Back-compat low-level emitter — LOCAL crumb only, never the world.
# tool-signal.sh fires this on EVERY tool (PostToolUse *); broadcasting each one to
# world:announce would be a firehose that floods the live world. Tool-level telemetry
# stays a local per-session crumb (greppable, zero network); the world only hears the
# session-level rich signals (emit_world: session:intent/start/stop) + /do's own
# world:do-event milestones. Roll tool activity up into session:stop, don't stream it.
emit_signal() {
  local receiver="${1:-hook}" weight="${2:-1}"
  shift 2 2>/dev/null || true
  local log="${TMPDIR:-/tmp}/cc-signals-${CLAUDE_SESSION_ID:-session}.log"
  printf '%s\t%s\t%s\n' "$receiver" "$weight" "$*" >>"$log" 2>/dev/null || true
  return 0
}
