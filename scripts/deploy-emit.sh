#!/usr/bin/env bash
# deploy-emit.sh — ONE deploy gate, onto the run/event stream every viewer reads.
#
# manifest: monorepo-only
#   Same classification as deploy-record.sh, and for the same reason: deploy.sh
#   is its only caller and deploy.sh does not ship. It DOES read a credential —
#   GATEWAY_API_KEY through ONE_ENV_FILE (default one.ie/web/.dev.vars, plus the
#   monorepo fallbacks do-signal.sh walks), honoured so that a future ship needs
#   no change — and no credential is exit 3 BY NAME, never a quiet success and
#   never a skipped gate that reads as a gate that ran.
#
# WHY IT EXISTS. `deploy.sh` emitted NOTHING — `grep -n signal deploy.sh` returns
# two comment lines and no call. A deploy's only trace was a committed JSON file,
# and `/deploy` says on its face what that costs: "nothing here animates a run
# that is happening now, because nothing here can know about one". The file stays
# (a page must render with no network); this makes the RUN a row as well.
#
# THE CALLER MUST NEVER LET THIS FAIL A DEPLOY. Every call site in deploy.sh ends
# in `|| true`, exactly as `deploy-record.sh` is called. This script is a
# reporter: a gate that passed while the network was down is still a gate that
# passed, and a deploy that goes red because its telemetry could not phone home
# is a worse failure than the one it was reporting. The other half of that rule
# lives in the mapper: a stage that never arrives is ABSENT, never a default
# frame, so a dropped emit degrades to a gap in the trace and never to a lie.
#
# USAGE
#   deploy-emit.sh --run <id> --target <worker> [--stage <gate> --status <s>]
#                  [--verdict green|red] [--sha <sha>] [--door <text>]
#                  [--slug <ws>] [--env dev] [--reason <text>] [--wall-ms <n>]
#                  [--detail k=v]... [--dry-run]
#   deploy-emit.sh --self-test          # local red proofs, no network
#
#   stage  : tree credentials typecheck tests build smoke approval migrations
#            ship health                                  (DEPLOY_SPINE_STEPS)
#   status : start | ok | fail                            (DeployStageStatus)
#   verdict: green | red   — the FINAL call, and the only thing that closes the
#            run. Separate from the stages because `--gates-only` is a complete,
#            successful run that never reaches ship or health; closing on the
#            last stage would leave every one of those runs open forever.
#
# --run IS HALF THE RUN KEY, and the sha cannot serve. On 2026-09-06 the same sha
# (af3ba5919) ran gates-only, went red, went green, then shipped — four runs.
# Keyed on sha they would have interleaved into one. deploy.sh already mints a
# usable id for its own log name: deploy-20260906-225246.log.
#
# NEVER CALL THIS ON --dry-run. A run row for a deploy that did not happen is the
# same theater the page refuses to render. Enforced at the call site, because a
# script cannot know its caller's flags.
#
# EXITS  0 emitted (or --dry-run printed) · 2 bad arguments · 3 no credential
#        4 the receiver refused — its own words on stderr · 5 jq missing
#
# THE REFUSAL IS THE WHOLE POINT — measured against prod 2026-09-06:
#   unknown receiver → HTTP 200 {"outcome":"dissolved","reason":"unknown_receiver"}
#   forbidden call   → HTTP 200 {"outcome":"result","result":{"ok":false,...}}
# A caller reading curl's exit code, the HTTP status, or `outcome` alone records
# a gate that never landed. Success is ONE shape: .outcome == "result" AND
# .result.ok == true.
#
# ENV  DEPLOY_EMIT_URL       default $ONE_API_URL, else https://one.ie
#      DEPLOY_EVENT_RECEIVER default deploy:event
#      ONE_ENV_FILE / DO_ENV_FILE   the credential file. Defaults to .dev.vars
#          and the ladder tries it FIRST, mirroring do-board.sh:54-60: BOTH
#          files carry a GATEWAY_API_KEY and PROD REFUSES the one in .env. A
#          refused key is exit 4 — but deploy.sh backgrounds every _emit with
#          both streams discarded and `|| true`, so the whole run would have
#          reported nothing while recording nothing. Reordering the ladder
#          alone would not have fixed it: the default above lands on a file
#          before the ladder is ever consulted.
#      DEPLOY_EMIT_SKIP_FALLBACKS=1 ONE_ENV_FILE is the WHOLE ladder. Without it
#          the no-credential state is unreachable from inside the monorepo, so
#          exit 3 could not be driven red. Same reason and shape as
#          FACTORY_EMIT_SKIP_FALLBACKS / DO_SIGNAL_SKIP_FALLBACKS.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# .dev.vars, NOT .env — prod refuses the .env key (recorded trap; do-board.sh:56
# pins the same file for the same reason). Relative, as it has always been: from
# a subdirectory this misses and the ladder below — which now also leads with
# .dev.vars — picks it up by absolute path.
ONE_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.dev.vars}}"
URL="${DEPLOY_EMIT_URL:-${ONE_API_URL:-https://one.ie}}"
RECEIVER="${DEPLOY_EVENT_RECEIVER:-deploy:event}"
TIMEOUT="${DEPLOY_EMIT_TIMEOUT:-8}"

die() { printf 'deploy-emit: %s\n' "$1" >&2; exit "$2"; }

STAGES='tree credentials typecheck tests build smoke approval migrations ship health'

# ---------------------------------------------------------------------------
# --self-test — every LOCAL refusal, driven for real. No network, no credential.
# Each refusal is asserted by its EXIT CODE, never by its message: a gate this
# script would have posted anyway is the frame nobody meant.
# ---------------------------------------------------------------------------
self_test() {
  local me="${BASH_SOURCE[0]}" fails=0 rc out pl
  _case() {
    local label="$1" want="$2"; shift 2
    out="$(ONE_ENV_FILE=/dev/null DEPLOY_EMIT_SKIP_FALLBACKS=1 bash "$me" "$@" 2>&1)"; rc=$?
    if [ "$rc" = "$want" ]; then printf '  ok   %-52s exit %s\n' "$label" "$rc"
    else printf '  FAIL %-52s exit %s, wanted %s\n     %s\n' "$label" "$rc" "$want" "$(printf '%s' "$out" | head -1)" >&2
      fails=$((fails + 1)); fi
  }
  printf '== deploy-emit --self-test\n'
  # THE broken shape this exists for: deployEventToRunEvents returns [] for a
  # gate outside the ten, and an empty mapping posted anyway is a lie on the stream.
  _case 'unknown stage is REFUSED before the wire'   2 --run r1 --target one-prod --stage lint --status ok
  _case 'unknown status is REFUSED'                  2 --run r1 --target one-prod --stage tests --status green
  _case 'unknown verdict is REFUSED'                 2 --run r1 --target one-prod --verdict amber
  _case 'missing --run is REFUSED'                   2 --target one-prod --stage tests --status ok
  _case 'missing --target is REFUSED'                2 --run r1 --stage tests --status ok
  # Half a stage frame is not a stage frame — the mapper returns [] for either half.
  _case 'stage without status is REFUSED'            2 --run r1 --target one-prod --stage tests
  _case 'status without stage is REFUSED'            2 --run r1 --target one-prod --status ok
  # A payload that names no stage AND no verdict would upsert a run and say nothing.
  _case 'neither stage nor verdict is REFUSED'       2 --run r1 --target one-prod
  _case 'non-numeric --wall-ms is REFUSED'           2 --run r1 --target one-prod --stage tests --status ok --wall-ms fast
  _case 'malformed --detail is REFUSED'              2 --run r1 --target one-prod --stage tests --status ok --detail nokv
  _case 'unknown argument is REFUSED'                2 --run r1 --target one-prod --stage tests --status ok --wat
  _case 'no credential is exit 3, not a quiet pass'  3 --run r1 --target one-prod --stage tests --status ok
  _case '--dry-run needs no credential'              0 --run r1 --target one-prod --stage build --status ok --dry-run
  _case 'verdict alone is a valid final call'        0 --run r1 --target one-prod --verdict green --dry-run

  pl="$(ONE_ENV_FILE=/dev/null DEPLOY_EMIT_SKIP_FALLBACKS=1 bash "$me" \
        --run 20260906-225246 --target one-prod --stage tests --status ok --sha af3ba5919 \
        --door './deploy' --slug one --reason none --wall-ms 168000 \
        --detail reused=true --detail waived=false --dry-run 2>/dev/null)"
  if printf '%s' "$pl" | jq -e '.data.run == "20260906-225246" and .data.target == "one-prod"
        and .data.stage == "tests" and .data.status == "ok" and .data.sha == "af3ba5919"
        and .data.slug == "one" and .data.wallMs == 168000
        and .data.detail.reused == true and .data.detail.waived == false' >/dev/null 2>&1; then
    printf '  ok   %-52s\n' 'dry-run payload carries every named field'
  else
    printf '  FAIL %-52s\n     %s\n' 'dry-run payload is incomplete' "$pl" >&2; fails=$((fails + 1))
  fi

  # wallMs must be a NUMBER and booleans must be BOOLEANS — zod rejects a string
  # for z.number(), so a quoted 168000 is a receiver refusal at deploy time
  # rather than a test failure here.
  if printf '%s' "$pl" | jq -e '(.data.wallMs | type) == "number"
        and (.data.detail.reused | type) == "boolean"' >/dev/null 2>&1; then
    printf '  ok   %-52s\n' 'wallMs is a number, booleans are booleans'
  else
    printf '  FAIL %-52s\n     %s\n' 'metric types would be refused by zod' "$pl" >&2; fails=$((fails + 1))
  fi

  # Optional fields ABSENT rather than empty — zod strips undeclared keys
  # silently, and an empty `slug` is not the same as no slug.
  pl="$(ONE_ENV_FILE=/dev/null DEPLOY_EMIT_SKIP_FALLBACKS=1 bash "$me" \
        --run r --target one-prod --stage tree --status start --dry-run 2>/dev/null)"
  if printf '%s' "$pl" | jq -e '(.data | has("slug") | not) and (.data | has("detail") | not)
        and (.data | has("wallMs") | not) and (.data | has("verdict") | not)' >/dev/null 2>&1; then
    printf '  ok   %-52s\n' 'unset optional fields are absent, not empty'
  else
    printf '  FAIL %-52s\n     %s\n' 'unset optional fields leaked into the payload' "$pl" >&2; fails=$((fails + 1))
  fi

  # Every stage in STAGES must be accepted — a typo here silently narrows the
  # pipeline to the gates somebody remembered.
  local st
  for st in $STAGES; do
    ONE_ENV_FILE=/dev/null DEPLOY_EMIT_SKIP_FALLBACKS=1 bash "$me" \
      --run r --target t --stage "$st" --status ok --dry-run >/dev/null 2>&1 \
      || { printf '  FAIL %-52s\n' "stage '$st' rejected by its own script" >&2; fails=$((fails + 1)); }
  done
  printf '  ok   %-52s\n' "all 10 DEPLOY_SPINE_STEPS accepted"

  if [ "$fails" -eq 0 ]; then printf 'deploy-emit --self-test: PASS (17 checks)\n'; return 0; fi
  printf 'deploy-emit --self-test: RED — %s check(s) failed\n' "$fails" >&2; return 1
}

RUN=""; TARGET=""; STAGE=""; STATUS=""; VERDICT=""; SHA=""; DOOR=""
SLUG=""; ENVW=""; REASON=""; WALLMS=""; DETAILS=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --run)      RUN="${2:-}";     shift 2 ;;
    --target)   TARGET="${2:-}";  shift 2 ;;
    --stage)    STAGE="${2:-}";   shift 2 ;;
    --status)   STATUS="${2:-}";  shift 2 ;;
    --verdict)  VERDICT="${2:-}"; shift 2 ;;
    --sha)      SHA="${2:-}";     shift 2 ;;
    --door)     DOOR="${2:-}";    shift 2 ;;
    --slug)     SLUG="${2:-}";    shift 2 ;;
    --env)      ENVW="${2:-}";    shift 2 ;;
    --reason)   REASON="${2:-}";  shift 2 ;;
    --wall-ms)  WALLMS="${2:-}";  shift 2 ;;
    --detail)   DETAILS="${DETAILS}${DETAILS:+$'\n'}${2:-}"; shift 2 ;;
    --dry-run)  DRY=1; shift ;;
    --self-test) command -v jq >/dev/null 2>&1 || die "jq not found" 5; self_test; exit $? ;;
    -h|--help)  sed -n '2,48p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $1" 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq not found — this script builds and reads JSON with it, and a hand-rolled parser is how a refusal becomes a pass" 5
[ -n "$RUN" ]    || die "--run <id> is required — it is half the run key (deploy:<target>:<run>, event.ts deployRunKey). The sha cannot serve: one sha ships repeatedly and the attempts would interleave" 2
[ -n "$TARGET" ] || die "--target <worker> is required — the other half of the run key, so 'did pay go out' does not need disambiguating by timestamp" 2

# Half a stage frame is not a stage frame. The mapper returns [] for either half
# alone, so refusing here keeps the wire and the mapper saying the same thing.
if [ -n "$STAGE" ] || [ -n "$STATUS" ]; then
  [ -n "$STAGE" ]  || die "--status without --stage — deployEventToRunEvents returns [] for half a frame, and guessing the other half records a frame nobody meant" 2
  [ -n "$STATUS" ] || die "--stage without --status — same reason" 2
  case " $STAGES " in
    *" $STAGE "*) ;;
    *) die "--stage must be one of: $STAGES (got '$STAGE') — deployEventToRunEvents returns [] for anything else, and an empty mapping posted anyway is a frame nobody meant" 2 ;;
  esac
  case "$STATUS" in
    start|ok|fail) ;;
    *) die "--status must be start|ok|fail (got '$STATUS'). There is deliberately no 'skip': a gate that did not run must be ABSENT, and an unrun gate is never a pass" 2 ;;
  esac
fi

if [ -n "$VERDICT" ]; then
  case "$VERDICT" in
    green|red) ;;
    *) die "--verdict must be green|red (got '$VERDICT')" 2 ;;
  esac
fi

[ -n "$STAGE" ] || [ -n "$VERDICT" ] || \
  die "nothing to say: pass --stage/--status, or --verdict, or both. A payload naming neither would upsert a run and record no frame" 2

if [ -n "$WALLMS" ]; then
  case "$WALLMS" in
    ''|*[!0-9]*) die "--wall-ms wants an integer of milliseconds (got '$WALLMS') — the receiver types it z.number() and would refuse a string at deploy time" 2 ;;
  esac
fi

# k=v, with `true`/`false`/integers kept as JSON scalars. `reused` and `waived`
# are the two metrics this whole feature exists to carry, and both are booleans:
# quoting them would make `waived:"false"` truthy in every reader.
detail_json='{}'
if [ -n "$DETAILS" ]; then
  while IFS= read -r kv; do
    [ -n "$kv" ] || continue
    case "$kv" in *=*) ;; *) die "--detail wants k=v, got: $kv" 2 ;; esac
    k="${kv%%=*}"; v="${kv#*=}"
    case "$v" in
      true|false)  detail_json="$(jq -n --argjson d "$detail_json" --arg k "$k" --argjson v "$v" '$d + {($k): $v}')" ;;
      ''|*[!0-9]*) detail_json="$(jq -n --argjson d "$detail_json" --arg k "$k" --arg v "$v" '$d + {($k): $v}')" ;;
      *)           detail_json="$(jq -n --argjson d "$detail_json" --arg k "$k" --argjson v "$v" '$d + {($k): $v}')" ;;
    esac
    [ -n "$detail_json" ] || die "could not build --detail object" 2
  done <<EOF
$DETAILS
EOF
fi

payload="$(jq -n \
  --arg run "$RUN" --arg target "$TARGET" --arg stage "$STAGE" --arg status "$STATUS" \
  --arg verdict "$VERDICT" --arg sha "$SHA" --arg door "$DOOR" --arg slug "$SLUG" \
  --arg env "$ENVW" --arg reason "$REASON" --arg wallms "$WALLMS" \
  --argjson detail "$detail_json" '
  {data: ({run: $run, target: $target}
    + (if $stage   != "" then {stage:   $stage}   else {} end)
    + (if $status  != "" then {status:  $status}  else {} end)
    + (if $verdict != "" then {verdict: $verdict} else {} end)
    + (if $sha     != "" then {sha:     $sha}     else {} end)
    + (if $door    != "" then {door:    $door}    else {} end)
    + (if $slug    != "" then {slug:    $slug}    else {} end)
    + (if $env     != "" then {env:     $env}     else {} end)
    + (if $reason  != "" then {reason:  $reason}  else {} end)
    + (if $wallms  != "" then {wallMs: ($wallms | tonumber)} else {} end)
    + (if ($detail | length) > 0 then {detail: $detail} else {} end))}')" \
  || die "could not build the payload" 2

if [ "$DRY" = 1 ]; then printf '%s\n' "$payload"; exit 0; fi

# The key never reaches argv (ps) and never reaches stdout. --config, chmod 600,
# removed on every path. Same shape as factory-emit.sh and do-signal.sh.
_gateway_key() {
  local f v
  # .dev.vars BEFORE .env, both here and in the default above. Two changes, not
  # one: whichever is consulted first must be the file prod accepts.
  for f in "$ONE_ENV_FILE" "$ROOT/one.ie/web/.dev.vars" "$ROOT/one.ie/web/.env" "$ROOT/.env"; do
    [ -f "$f" ] || continue
    if [ "${DEPLOY_EMIT_SKIP_FALLBACKS:-0}" = "1" ] && [ "$f" != "$ONE_ENV_FILE" ]; then continue; fi
    v="$(grep -E '^GATEWAY_API_KEY=' "$f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//')"
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
  printf ''
}

KEYVAL="$(_gateway_key)"
[ -n "$KEYVAL" ] || die "no GATEWAY_API_KEY in $ONE_ENV_FILE (or the monorepo fallbacks) — an unauthenticated emit is refused at the door and would look exactly like a gate that never happened" 3

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
  printf 'deploy-emit: RED run=%s target=%s stage=%s%s http=%s — %s\n' \
    "$RUN" "$TARGET" "${STAGE:-none}" "${VERDICT:+ verdict=$VERDICT}" "${code:-none}" "$why" >&2
  exit 4
fi

printf 'deploy-emit: ok run=%s target=%s stage=%s%s receiver=%s\n' \
  "$RUN" "$TARGET" "${STAGE:-none}" "${VERDICT:+ verdict=$VERDICT}" "$RECEIVER"
exit 0
