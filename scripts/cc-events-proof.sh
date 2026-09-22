#!/usr/bin/env bash
# cc-events-proof.sh — the code-signals promise's proof: — text/code-signals.md
#
# Proves both wires deliver, not just accept: registers a throwaway listener distinct
# from the CC engine's own identity (fanOut never delivers to its own sender — see
# tag-match.ts), fires one authenticated session signal (wire 1) and one bridged
# tasks:announce batch (wire 3), and asserts each response is ok:true with matched>=1.
#
# Exit 0  — session wire matched, AND task wire matched (or explicitly skipped: empty
#           local queue is not a failure, see text/code-signals-plan.md pre-mortem).
# Exit 1  — a wire ran and did not match.
# Exit 2  — GATEWAY_API_KEY unresolved (named reason, not a generic non-zero).
#
# Env: ONE_API_URL (default http://localhost:4321), DO_ENV_FILE (override secret file),
#      CC_PROOF_SLUG (default cc-proof-listener — the throwaway subscriber identity).
#
# Port-collision self-heal: :4321 is Astro's own default, so an unrelated sibling app
# (e.g. apps/one/site) can already be squatting on it in a shared dev machine — its 404
# HTML then breaks every jq parse below with a blank ok=, not a wrong-answer. If
# ONE_API_URL is unset and nothing at :4321 answers /api/health as one.ie/web, this
# script starts its own one.ie/web on an ephemeral port for the proof's lifetime and
# tears it down on exit. An explicit ONE_API_URL is trusted as-is (fails loudly instead,
# see below) — the auto-start only ever fills in the unset default.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/.claude/hooks/lib/signal.sh"

command -v jq >/dev/null 2>&1 || { echo "[cc-events-proof] jq required"; exit 2; }

PROOF_SLUG="${CC_PROOF_SLUG:-cc-proof-listener}"
API_URL="${ONE_API_URL:-http://localhost:4321}"

_is_one_web() {
  jq -e '.status == "ok"' >/dev/null 2>&1 <<<"$(curl -sS --max-time 3 "$1/api/health" 2>/dev/null)"
}

SELF_STARTED_PID=""
if ! _is_one_web "$API_URL"; then
  if [ -n "${ONE_API_URL:-}" ]; then
    echo "[cc-events-proof] FAIL — ONE_API_URL=$API_URL did not answer /api/health as one.ie/web"
    exit 2
  fi
  echo "[cc-events-proof] :4321 isn't one.ie/web (port occupied by another app, or nothing's listening) — starting one.ie/web on an ephemeral port for this proof"
  DEV_PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')"
  ( cd "$ROOT/one.ie/web" && exec ./node_modules/.bin/astro dev --port "$DEV_PORT" ) >/tmp/cc-events-proof-web.log 2>&1 &
  SELF_STARTED_PID=$!
  API_URL="http://localhost:$DEV_PORT"
  for _ in $(seq 1 30); do
    _is_one_web "$API_URL" && break
    sleep 1
  done
  if ! _is_one_web "$API_URL"; then
    echo "[cc-events-proof] FAIL — could not start one.ie/web for the proof (see /tmp/cc-events-proof-web.log)"
    kill "$SELF_STARTED_PID" 2>/dev/null
    exit 2
  fi
  export ONE_API_URL="$API_URL"
fi

API_KEY="$(_one_secret GATEWAY_API_KEY)"
if [ -z "$API_KEY" ]; then
  echo "[cc-events-proof] GATEWAY_API_KEY not found — checked shell env and $(_one_env_file)"
  [ -n "$SELF_STARTED_PID" ] && kill "$SELF_STARTED_PID" 2>/dev/null
  exit 2
fi

# Token off argv (ps aux would leak a bare -H value) — one private 0600 curl
# --config file for the process lifetime.
AUTHCFG="$(mktemp)"; chmod 600 "$AUTHCFG"
printf 'header = "Authorization: Bearer %s"\n' "$API_KEY" >"$AUTHCFG"
cleanup() {
  rm -f "$AUTHCFG"
  [ -n "$SELF_STARTED_PID" ] && kill "$SELF_STARTED_PID" 2>/dev/null
}
trap cleanup EXIT

# ── wire 2 setup — register the throwaway listener ──────────────────────────
# Cookie: signed_out=1 opts out of local dev's DEV_SLUG bypass (middleware.ts), which
# would otherwise resolve EVERY caller to the same identity and make the subscriber
# self-exclude (fanOut never delivers to its own sender). No effect in prod, where
# DEV_SLUG doesn't exist.
register_resp="$(curl -sS --max-time 5 -X POST "$API_URL/api/ask/subscriptions:register" \
  -H 'Content-Type: application/json' --config "$AUTHCFG" \
  -H 'Cookie: signed_out=1' \
  -d "$(jq -nc --arg slug "$PROOF_SLUG" '{data:{receiver:"world:announce",tags:["cc","session"],board:"marketplace",slug:$slug}}')")"
register_ok="$(printf '%s' "$register_resp" | jq -r '.result.ok // false' 2>/dev/null)"
echo "[cc-events-proof] register listener=$PROOF_SLUG ok=$register_ok"
if [ "$register_ok" != "true" ]; then
  echo "[cc-events-proof] FAIL — could not register the standing listener: $register_resp"
  exit 1
fi

# ── wire 1 — one authenticated session signal, through the SAME nomination path ──
# emit_world itself is fire-and-forget and (locally) never needs to nominate — local
# dev's DEV_SLUG=one bypass resolves ctx.ownerSlug to "one" for ANY request regardless
# of auth headers, so routing this through emit_world unmodified would pass even with a
# missing/wrong key and prove nothing about authentication. Cookie: signed_out=1 (same
# trick as the register step above) opts OUT of that bypass, forcing ctx.ownerSlug to
# come from the service-caller nomination this feature actually wires — the real path
# prod always takes (no DEV_SLUG there). This is what "session signals authenticate"
# in the promise means, and the only way to prove it locally.
session_payload="$(jq -nc '{tags:["cc","session"],slug:"one",board:"marketplace"}')"
session_resp="$(curl -sS --max-time 5 -X POST "$API_URL/api/ask/world:announce" \
  -H 'Content-Type: application/json' --config "$AUTHCFG" \
  -H 'Cookie: signed_out=1' -d "{\"data\":$session_payload}")"
session_ok="$(printf '%s' "$session_resp" | jq -r '.result.ok // false' 2>/dev/null)"
session_matched="$(printf '%s' "$session_resp" | jq -r '.result.matched // 0' 2>/dev/null)"
echo "[cc-events-proof] wire1 session ok=$session_ok matched=$session_matched"

# Negative control — if auth isn't load-bearing, a wrong key would ALSO succeed here.
# Same nomination attempt, deliberately wrong Bearer: must be rejected (ownerSlug never
# resolves), proving the gateway/nomination gate is actually doing something.
neg_resp="$(curl -sS --max-time 5 -X POST "$API_URL/api/ask/world:announce" \
  -H 'Content-Type: application/json' -H 'Authorization: Bearer wrong-key-0000000000000000' \
  -H 'Cookie: signed_out=1' -d "{\"data\":$session_payload}")"
neg_ok="$(printf '%s' "$neg_resp" | jq -r '.result.ok // false' 2>/dev/null)"
if [ "$neg_ok" = "true" ]; then
  echo "[cc-events-proof] FAIL — a wrong Bearer key still resolved ok:true; auth is not load-bearing: $neg_resp"
  exit 1
fi
echo "[cc-events-proof] wire1 negative control ok — wrong key correctly rejected ($neg_resp)"

# ── wire 3 — tasks:announce direct (shared-atom wire, text/tasks-do-plan.md C1/C8:
# tasks:create already fires tasks:announce in-process, so this proof calls the same
# receiver the create path calls instead of going through the deleted reconciler
# script) ───────────────────────────────────────────────────────────────────
tasks_payload="$(jq -nc --arg tid "task:${PROOF_SLUG}-$$" '{taskId:$tid,tags:["cc","session"],board:"marketplace"}')"
tasks_resp="$(curl -sS --max-time 5 -X POST "$API_URL/api/ask/tasks:announce" \
  -H 'Content-Type: application/json' --config "$AUTHCFG" \
  -H 'Cookie: signed_out=1' -d "{\"data\":$tasks_payload}")"
tasks_ok="$(printf '%s' "$tasks_resp" | jq -r '.result.ok // false' 2>/dev/null)"
tasks_matched="$(printf '%s' "$tasks_resp" | jq -r '.result.matched // 0' 2>/dev/null)"
echo "[cc-events-proof] wire3 tasks:announce ok=$tasks_ok matched=$tasks_matched"
if [ "$tasks_ok" = "true" ] && [ "${tasks_matched:-0}" -ge 1 ]; then
  wire3_ok=true
else
  echo "[cc-events-proof] wire3 tasks FAIL — $tasks_resp"
  wire3_ok=false
fi

# ── verdict ───────────────────────────────────────────────────────────────────
if [ "$session_ok" = "true" ] && [ "${session_matched:-0}" -ge 1 ] && [ "$wire3_ok" != "false" ]; then
  echo "[cc-events-proof] PASS"
  exit 0
fi
echo "[cc-events-proof] FAIL — session_ok=$session_ok session_matched=$session_matched wire3_ok=$wire3_ok"
exit 1
