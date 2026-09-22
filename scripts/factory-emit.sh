#!/usr/bin/env bash
# factory-emit.sh — ONE factory stage, onto the run/event stream every viewer reads.
#
# manifest: needs-env
#   Reads GATEWAY_API_KEY through ONE_ENV_FILE (default one.ie/web/.env, plus the
#   monorepo fallbacks do-signal.sh walks). No credential is exit 3 by name —
#   never a quiet success, never a skipped stage that reads as a stage that ran.
#
# WHY IT EXISTS. .claude/workflows/factory-executor.js writes to the substrate
# exactly TWICE per job: tasks:claim at Claim and tasks:notes+tasks:status at
# Close. Ready · Build · Review · Prove emit nothing, so no surface can draw a
# job DURING. This is the call that closes that gap: one FactoryEventPayload
# (one.ie/web/src/lib/factory/event.ts) per stage boundary, posted to the
# factory:event receiver, which maps it onto the same run/event stream RunTrack
# already reads.
#
# USAGE
#   factory-emit.sh --job <tid> --stage <stage> --status <start|ok|fail>
#                   [--slug <workspace>] [--model <rung>] [--reason <text>]
#                   [--detail k=v]... [--env dev] [--dry-run]
#   factory-emit.sh --self-test        # local red proofs, no network
#
#   stage : ready | claim | build | review | prove | close   (FACTORY_SPINE_STEPS)
#   status: start | ok | fail                                (FactoryStageStatus)
#
# EXITS  0 emitted (or --dry-run printed) · 2 bad arguments · 3 no credential
#        4 the receiver refused — its own words on stderr · 5 jq missing
#
# THE REFUSAL IS THE WHOLE POINT — both measured against prod 2026-09-06:
#   unknown receiver → HTTP 200 {"outcome":"dissolved","reason":"unknown_receiver",...}
#   forbidden call   → HTTP 200 {"outcome":"result","result":{"ok":false,"error":"forbidden: ..."}}
# A caller that reads curl's exit code, the HTTP status, or `outcome` alone
# records a stage that never landed. Success is ONE shape and nothing else:
#   .outcome == "result"  AND  .result.ok == true
#
# ENV  FACTORY_EMIT_URL   default $ONE_API_URL, else https://one.ie
#      FACTORY_EVENT_RECEIVER   default factory:event
#      ONE_ENV_FILE / DO_ENV_FILE   the credential file
#      FACTORY_EMIT_SKIP_FALLBACKS=1  ONE_ENV_FILE is the WHOLE ladder. Without
#          it the no-credential state is unreachable from inside the monorepo
#          (the fallbacks resolve to a tree that carries a real .env), so exit 3
#          could not be driven red. Same reason, same shape, as
#          DO_SIGNAL_SKIP_FALLBACKS in do-signal.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ONE_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
URL="${FACTORY_EMIT_URL:-${ONE_API_URL:-https://one.ie}}"
RECEIVER="${FACTORY_EVENT_RECEIVER:-factory:event}"
TIMEOUT="${FACTORY_EMIT_TIMEOUT:-8}"

die() { printf 'factory-emit: %s\n' "$1" >&2; exit "$2"; }

# ---------------------------------------------------------------------------
# --self-test — every LOCAL refusal, driven for real. No network, no credential.
# A stage this script would have posted anyway is the frame nobody meant, so
# each refusal is asserted by its EXIT CODE, never by its message.
# ---------------------------------------------------------------------------
self_test() {
  local me="${BASH_SOURCE[0]}" fails=0 rc out
  _case() {  # $1 label, $2 expected rc, rest: argv (run with no credential ladder)
    local label="$1" want="$2"; shift 2
    out="$(ONE_ENV_FILE=/dev/null FACTORY_EMIT_SKIP_FALLBACKS=1 bash "$me" "$@" 2>&1)"; rc=$?
    if [ "$rc" = "$want" ]; then
      printf '  ok   %-46s exit %s\n' "$label" "$rc"
    else
      printf '  FAIL %-46s exit %s, wanted %s\n     %s\n' "$label" "$rc" "$want" "$(printf '%s' "$out" | head -1)" >&2
      fails=$((fails + 1))
    fi
  }
  printf '== factory-emit --self-test\n'
  # THE broken shape this test exists for: factoryEventToRunEvent returns null
  # for a stage outside the six, and a null posted anyway is a lie on the stream.
  _case 'unknown stage is REFUSED before the wire' 2 --job task:selftest --stage warm --status ok
  _case 'unknown status is REFUSED'                2 --job task:selftest --stage build --status green
  _case 'missing --job is REFUSED'                 2 --stage build --status ok
  _case 'missing --stage is REFUSED'               2 --job task:selftest --status ok
  _case 'malformed --detail is REFUSED'            2 --job t --stage build --status ok --detail nokv
  _case 'unknown argument is REFUSED'              2 --job t --stage build --status ok --wat
  # No credential must be a NAMED exit 3, never a quiet skip that reads as a
  # stage that ran. Reachable only because SKIP_FALLBACKS exists.
  _case 'no credential is exit 3, not a quiet pass' 3 --job task:selftest --stage build --status start
  # --dry-run precedes the credential read, so it stays 0 with no key at all.
  _case '--dry-run needs no credential'             0 --job task:selftest --stage prove --status ok --dry-run

  # And the dry-run payload must actually carry the three required fields plus
  # an optional one, or a green emit could be an empty frame.
  local pl
  pl="$(ONE_ENV_FILE=/dev/null FACTORY_EMIT_SKIP_FALLBACKS=1 bash "$me" \
        --job task:selftest --stage review --status fail --slug one --model opus \
        --reason 'refuted' --detail lens=urls --dry-run 2>/dev/null)"
  if printf '%s' "$pl" | jq -e '.data.job == "task:selftest" and .data.stage == "review"
        and .data.status == "fail" and .data.slug == "one" and .data.model == "opus"
        and .data.reason == "refuted" and .data.detail.lens == "urls"' >/dev/null 2>&1; then
    printf '  ok   %-46s\n' 'dry-run payload carries every named field'
  else
    printf '  FAIL %-46s\n     %s\n' 'dry-run payload is incomplete' "$pl" >&2
    fails=$((fails + 1))
  fi

  # The optional fields must be ABSENT rather than empty strings — zod strips
  # undeclared keys silently, and an empty `slug` is not the same as no slug.
  pl="$(ONE_ENV_FILE=/dev/null FACTORY_EMIT_SKIP_FALLBACKS=1 bash "$me" \
        --job t --stage ready --status start --dry-run 2>/dev/null)"
  if printf '%s' "$pl" | jq -e '(.data | has("slug") | not) and (.data | has("detail") | not)' >/dev/null 2>&1; then
    printf '  ok   %-46s\n' 'unset optional fields are absent, not empty'
  else
    printf '  FAIL %-46s\n     %s\n' 'unset optional fields leaked into the payload' "$pl" >&2
    fails=$((fails + 1))
  fi

  if [ "$fails" -eq 0 ]; then
    printf 'factory-emit --self-test: PASS (10 checks)\n'; return 0
  fi
  printf 'factory-emit --self-test: RED — %s check(s) failed\n' "$fails" >&2; return 1
}

JOB=""; STAGE=""; STATUS=""; SLUG=""; MODEL=""; REASON=""; ENVW=""; DETAILS=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --job)     JOB="${2:-}";    shift 2 ;;
    --stage)   STAGE="${2:-}";  shift 2 ;;
    --status)  STATUS="${2:-}"; shift 2 ;;
    --slug)    SLUG="${2:-}";   shift 2 ;;
    --model)   MODEL="${2:-}";  shift 2 ;;
    --reason)  REASON="${2:-}"; shift 2 ;;
    --env)     ENVW="${2:-}";   shift 2 ;;
    --detail)  DETAILS="${DETAILS}${DETAILS:+$'\n'}${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --self-test) command -v jq >/dev/null 2>&1 || die "jq not found" 5; self_test; exit $? ;;
    -h|--help) sed -n '2,42p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $1" 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq not found — this script builds and reads JSON with it, and a hand-rolled parser is how a refusal becomes a pass" 5
[ -n "$JOB" ] || die "--job <tid> is required — it is the run key (factory:<tid>, event.ts factoryRunKey)" 2
case "$STAGE" in
  ready|claim|build|review|prove|close) ;;
  *) die "--stage must be one of ready claim build review prove close (got '$STAGE') — factoryEventToRunEvent returns NULL for anything else, and a null that is posted anyway is a frame nobody meant" 2 ;;
esac
case "$STATUS" in
  start|ok|fail) ;;
  *) die "--status must be start|ok|fail (got '$STATUS')" 2 ;;
esac

detail_json='{}'
if [ -n "$DETAILS" ]; then
  while IFS= read -r kv; do
    [ -n "$kv" ] || continue
    case "$kv" in *=*) ;; *) die "--detail wants k=v, got: $kv" 2 ;; esac
    detail_json="$(jq -n --argjson d "$detail_json" --arg k "${kv%%=*}" --arg v "${kv#*=}" '$d + {($k): $v}')" \
      || die "could not build --detail object" 2
  done <<EOF
$DETAILS
EOF
fi

payload="$(jq -n \
  --arg job "$JOB" --arg stage "$STAGE" --arg status "$STATUS" \
  --arg slug "$SLUG" --arg model "$MODEL" --arg reason "$REASON" --arg env "$ENVW" \
  --argjson detail "$detail_json" '
  {data: ({job: $job, stage: $stage, status: $status}
    + (if $slug   != "" then {slug:   $slug}   else {} end)
    + (if $model  != "" then {model:  $model}  else {} end)
    + (if $reason != "" then {reason: $reason} else {} end)
    + (if $env    != "" then {env:    $env}    else {} end)
    + (if ($detail | length) > 0 then {detail: $detail} else {} end))}')" \
  || die "could not build the payload" 2

if [ "$DRY" = 1 ]; then printf '%s\n' "$payload"; exit 0; fi

# The key never reaches argv (ps) and never reaches stdout. --config, chmod 600,
# removed on every path. Same shape as do-signal.sh.
_gateway_key() {
  local f v
  for f in "$ONE_ENV_FILE" "$ROOT/one.ie/web/.env" "$ROOT/one.ie/web/.dev.vars" "$ROOT/.env"; do
    [ -f "$f" ] || continue
    if [ "${FACTORY_EMIT_SKIP_FALLBACKS:-0}" = "1" ] && [ "$f" != "$ONE_ENV_FILE" ]; then continue; fi
    v="$(grep -E '^GATEWAY_API_KEY=' "$f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//')"
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
  printf ''
}

KEYVAL="$(_gateway_key)"
[ -n "$KEYVAL" ] || die "no GATEWAY_API_KEY in $ONE_ENV_FILE (or the monorepo fallbacks) — an unauthenticated emit is refused at the door and would look exactly like a stage that never happened" 3

cfg="$(mktemp)"; chmod 600 "$cfg"
trap 'rm -f "$cfg"' EXIT INT TERM
printf 'header = "Authorization: Bearer %s"\n' "$KEYVAL" > "$cfg"

resp="$(curl -sS -X POST "$URL/api/ask/$RECEIVER" \
  -H 'content-type: application/json' --config "$cfg" \
  --max-time "$TIMEOUT" -d "$payload" -w $'\n%{http_code}' 2>&1)"; rc=$?
rm -f "$cfg"; trap - EXIT INT TERM

code="$(printf '%s' "$resp" | tail -1)"
body="$(printf '%s' "$resp" | sed '$d')"
ok="$(printf '%s' "$body" | jq -r 'if (.outcome == "result" and (.result.ok == true)) then "yes" else "no" end' 2>/dev/null)"

if [ "$rc" -ne 0 ] || [ "$ok" != "yes" ]; then
  why="$(printf '%s' "$body" | jq -r '.reason // .result.error // .error // .hint // empty' 2>/dev/null)"
  [ -n "$why" ] || why="curl rc=$rc http=${code:-none} body=$(printf '%s' "$body" | head -c 200)"
  printf 'factory-emit: RED job=%s stage=%s status=%s http=%s — %s\n' \
    "$JOB" "$STAGE" "$STATUS" "${code:-none}" "$why" >&2
  exit 4
fi

printf 'factory-emit: ok job=%s stage=%s status=%s receiver=%s\n' "$JOB" "$STAGE" "$STATUS" "$RECEIVER"
exit 0
