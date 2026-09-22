#!/usr/bin/env bash
# factory-close-check.sh — did the Close actually land on the board?
#
# manifest: needs-env
#   Reads GATEWAY_API_KEY through ONE_ENV_FILE (default one.ie/web/.env, plus the
#   monorepo fallbacks). A read it cannot make is exit 3 by name; it never
#   answers MISSING on evidence it did not get.
#
# WHY IT EXISTS. On the first factory run the Close agent RETURNED
# {"status":"done"} while the board row stayed `picked`
# (task:01a07591e5c350a306c93933, workspace one, measured 2026-09-06). The
# executor's result JSON is a claim about an agent, not evidence about the
# substrate. This reads the row back and prints what the BOARD says, one line.
#
# WHY NOT /api/factory/board. Its `?slug=` is a PLAN selector from a closed list
# (board.ts PLAN_SLUGS = ['factory-do','factory']; planSlug coerces everything
# else to the default), so `?slug=one` answers for factory-do — measured. And the
# executor's rows are on neither plan board. readWork is
# `tasks:everywhere {workspace, limit:200}` anyway, and it deliberately never
# reads the CLOSED queue, which is the half a close-check needs. So: the same
# source, one hop earlier, both queues.
#
# USAGE  factory-close-check.sh <tid> <workspace>
#        factory-close-check.sh --self-test [workspace]
# PRINTS CLOSE tid=<tid> lane=<lane> verdict=<verdict> status=<status>
# EXITS  0 the row was read
#        2 both queues answered cleanly and completely, and no such row: MISSING
#        3 UNREADABLE — a refusal, a truncated answer, an unparseable count, or
#          zero rows in both queues (subscriptions.ts answers `{ok:true,tasks:[]}`
#          when env.DB is absent, so an outage and an empty workspace are the same
#          bytes; that must never become "your task is not there")
#        4 bad arguments / jq missing
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ONE_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
URL="${FACTORY_EMIT_URL:-${ONE_API_URL:-https://one.ie}}"
TIMEOUT="${FACTORY_CLOSE_TIMEOUT:-15}"
# The server's own ceiling: subscriptions.ts is Math.min(data.limit ?? 50, 200),
# so 200 is the most any caller can ask for. `returned == 200` is therefore the
# only honest truncation signal — measured 2026-09-06, workspace one answered
# 100 open rows to a limit of 200 and 100 again to a limit of 500, which is the
# whole visible set, not a cap.
LIMIT=200

# ---------------------------------------------------------------------------
# The row reader. Mirrors toWorkRow (board.ts): the labelled NOTES lines ride
# first (WORK_LABELS), the `lane:`/`verdict:` TAGS are the fallback for rows a
# pre-fix close tagged. The label regex and the normalisation are copied from
# spec-gate.ts LABEL_RE / normaliseLabel — case- and space-insensitive, markdown
# furniture tolerated, smart quotes folded.
#
# ONE deviation, stated out loud: parseLabelledLines appends CONTINUATION lines
# to the open field; this takes the label line's own value only. For lane and
# verdict the executor writes single-line values (closePrompt), and a multi-line
# lane would print here as its first line rather than as a mangled one.
#
# `lane=unrecorded` / `verdict=unrun` are deliberate. board.ts says a NULL
# verdict "renders as unrun, which is not a pass"; an absent lane is not
# `lane=none`, which is a value the executor actually writes.
#
# It lives in a heredoc file, not inline, so the apostrophe inside the label
# character class never has to survive shell quoting.
# ---------------------------------------------------------------------------
_write_jq() {
  cat > "$1" <<'JQ'
def lbls:
  (.notes // "")
  | split("\n")
  | map(capture("^[ \t>*#-]*(?<k>[A-Za-z][A-Za-z'‘’ ]{2,24}?)[ \t]*:[ \t]*(?<v>.*)$")?)
  | map(select(. != null))
  | map({key: (.k | gsub("[‘’]"; "'") | ascii_downcase | gsub("\\s+"; " ") | gsub("^\\s+|\\s+$"; "")),
         value: (.v | gsub("^\\s+|\\s+$"; ""))})
  | from_entries;
def tagv($p): ([.tags[]? | select(startswith($p))] | .[0] // "") | if . == "" then "" else .[($p|length):] end;
def pick($a; $b; $d): if ($a // "") != "" then $a elif ($b // "") != "" then $b else $d end;
. as $t | (lbls) as $l
| "CLOSE tid=" + $t.id
  + " lane="    + ((pick($l["lane"];    ($t | tagv("lane:"));    "unrecorded")) | gsub("\\s+"; "_"))
  + " verdict=" + ((pick($l["verdict"]; ($t | tagv("verdict:")); "unrun"))      | gsub("\\s+"; "_"))
  + " status="  + (($t.status // "") | if . == "" then "unknown" else . end)
JQ
}

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

# ---------------------------------------------------------------------------
# --self-test — the local guards, the parser against the REAL close notes, and
# one network assertion: an impossible tid must be MISSING (exit 2), which is
# only reachable after a clean two-queue read.
#
# THE DISCIPLINE: an UNREADABLE (exit 3) here is a FAILED self-test, never a
# skip. A checker that goes green because it could not reach the substrate is
# the exact defect this script was written against.
# ---------------------------------------------------------------------------
self_test() {
  local me="${BASH_SOURCE[0]}" ws="${1:-${FACTORY_CLOSE_SELFTEST_WS:-one}}" fails=0 rc out
  printf '== factory-close-check --self-test (workspace %s)\n' "$ws"

  _case() {  # label, want-rc, argv...
    local label="$1" want="$2"; shift 2
    out="$(bash "$me" "$@" 2>&1)"; rc=$?
    if [ "$rc" = "$want" ]; then printf '  ok   %-52s exit %s\n' "$label" "$rc"
    else printf '  FAIL %-52s exit %s, wanted %s\n     %s\n' "$label" "$rc" "$want" "$(printf '%s' "$out" | head -1)" >&2; fails=$((fails+1)); fi
  }

  _case 'no arguments is REFUSED'                     4
  _case 'uppercase workspace is REFUSED, not read'    4 task:x One
  _case 'implausible tid is REFUSED'                  4 'task:$(rm -rf /)' one
  # Reachable only because SKIP_FALLBACKS exists; without it the monorepo's own
  # .env answers and the no-credential branch is unreachable.
  out="$(ONE_ENV_FILE=/dev/null FACTORY_EMIT_SKIP_FALLBACKS=1 bash "$me" task:x "$ws" 2>&1)"; rc=$?
  if [ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'reason=no-credential'; then
    printf '  ok   %-52s exit 3\n' 'no credential is UNREADABLE, not MISSING'
  else
    printf '  FAIL %-52s exit %s\n     %s\n' 'no credential must be UNREADABLE' "$rc" "$out" >&2; fails=$((fails+1))
  fi

  # The parser, against the FIRST REAL CLOSE, byte-identical to the fixture in
  # one.ie/web/src/lib/factory/close-parse.test.ts. Two parsers drift; this is
  # the line that would go red when WORK_LABELS or LABEL_RE moves.
  local jqf row got
  jqf="$(mktemp)"; _write_jq "$jqf"
  row='{"id":"task:01a07591e5c350a306c93933","status":"picked","tags":[],"notes":"Lane: none\nVerdict: red\nPreview: http://localhost:4325\nCommit: https://github.com/one-ie/one/commit/10a821f97\nHeld: red — see stage lines above\nwalk red (lane none, tier ?) · http://localhost:4325/components · commit 10a821f97 · 2026-09-06T07:18:36Z"}'
  got="$(printf '%s' "$row" | jq -r -f "$jqf" 2>&1)"
  rm -f "$jqf"
  if [ "$got" = "CLOSE tid=task:01a07591e5c350a306c93933 lane=none verdict=red status=picked" ]; then
    printf '  ok   %-52s\n' 'the real close notes parse as the TS reader does'
  else
    printf '  FAIL %-52s\n     got: %s\n' 'parser disagrees with close-parse.test.ts' "$got" >&2; fails=$((fails+1))
  fi

  # An absent verdict must read `unrun`, never a pass — board.ts's own rule.
  jqf="$(mktemp)"; _write_jq "$jqf"
  got="$(printf '%s' '{"id":"t","status":"picked","tags":[],"notes":"Preview: x"}' | jq -r -f "$jqf" 2>&1)"; rm -f "$jqf"
  if [ "$got" = "CLOSE tid=t lane=unrecorded verdict=unrun status=picked" ]; then
    printf '  ok   %-52s\n' 'an absent verdict reads unrun, never a pass'
  else
    printf '  FAIL %-52s\n     got: %s\n' 'absent verdict did not read unrun' "$got" >&2; fails=$((fails+1))
  fi

  # THE NETWORK HALF. exit 2 is only reachable through a clean read of BOTH
  # queues, so this asserts the read as much as the verdict.
  #
  # A LINKED WORKTREE HAS NO one.ie/web/.env — it is gitignored and never checked
  # out. Say that by name and STILL FAIL: an unreachable substrate is a failed
  # self-test, never a skip, exactly as the exit-3 branch above insists.
  if [ -z "$(_gateway_key)" ]; then
    printf '  FAIL %-52s\n' 'no credential — the read half could not be asserted' >&2
    printf '     SKIP-IMPOSSIBLE: no GATEWAY_API_KEY via %s. This is not a broken script;\n' "$ONE_ENV_FILE" >&2
    printf '     run --self-test from the MAIN tree, or export ONE_ENV_FILE=<main>/one.ie/web/.env\n' >&2
    fails=$((fails + 1))
    printf 'factory-close-check --self-test: RED — %s check(s) failed\n' "$fails" >&2; return 1
  fi
  out="$(bash "$me" 'task:0000000000000000000000000' "$ws" 2>&1)"; rc=$?
  if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'MISSING'; then
    printf '  ok   %-52s exit 2\n' 'an impossible tid is MISSING after a clean read'
  elif [ "$rc" = 3 ]; then
    printf '  FAIL %-52s exit 3 — the substrate was NOT read, so this test proved nothing\n     %s\n' \
      'impossible tid must be MISSING' "$out" >&2; fails=$((fails+1))
  else
    printf '  FAIL %-52s exit %s\n     %s\n' 'impossible tid must be MISSING' "$rc" "$out" >&2; fails=$((fails+1))
  fi

  if [ "$fails" -eq 0 ]; then printf 'factory-close-check --self-test: PASS (7 checks)\n'; return 0; fi
  printf 'factory-close-check --self-test: RED — %s check(s) failed\n' "$fails" >&2; return 1
}

case "${1:-}" in
  --self-test) command -v jq >/dev/null 2>&1 || { echo "factory-close-check: jq not found" >&2; exit 4; }
               self_test "${2:-}"; exit $? ;;
  -h|--help)   sed -n '2,32p' "${BASH_SOURCE[0]}"; exit 0 ;;
esac

TID="${1:-}"; WS="${2:-}"
[ -n "$TID" ] && [ -n "$WS" ] || { echo "usage: factory-close-check.sh <tid> <workspace>" >&2; exit 4; }
command -v jq >/dev/null 2>&1 || { echo "factory-close-check: jq not found" >&2; exit 4; }
# Validated, not escaped — the same shape readWork asserts. The workspace is
# interpolated into the JSON body below, so this is the injection guard too.
#
# ENUMERATED, never a RANGE. Measured on this box 2026-09-06 (bash 3.2,
# en_US.UTF-8): `case One in *[!a-z0-9-]*)` does NOT match — a glob range uses
# COLLATION order, which interleaves case, so `One` sailed past this very guard
# and reached the wire. Caught by --self-test's uppercase case. `-` is LAST in
# both sets on purpose; anywhere else it forms a range of its own.
WS_OK='abcdefghijklmnopqrstuvwxyz0123456789-'
TID_OK='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:_-'
case "$WS" in *[!$WS_OK]*|'') echo "factory-close-check: workspace must match ^[a-z0-9-]+$ (got '$WS')" >&2; exit 4 ;; esac
case "$TID" in *[!$TID_OK]*|'') echo "factory-close-check: implausible tid '$TID'" >&2; exit 4 ;; esac

KEYVAL="$(_gateway_key)"
[ -n "$KEYVAL" ] || { printf 'CLOSE tid=%s UNREADABLE reason=no-credential file=%s\n' "$TID" "$ONE_ENV_FILE"; exit 3; }

cfg="$(mktemp)"; chmod 600 "$cfg"
JQF="$(mktemp)"; _write_jq "$JQF"
trap 'rm -f "$cfg" "$JQF"' EXIT INT TERM
printf 'header = "Authorization: Bearer %s"\n' "$KEYVAL" > "$cfg"

read_queue() {  # $1 = false | true  (the CLOSED flag)
  curl -sS -X POST "$URL/api/ask/tasks:everywhere" \
    -H 'content-type: application/json' --config "$cfg" --max-time "$TIMEOUT" \
    -d "{\"data\":{\"workspace\":\"$WS\",\"limit\":$LIMIT,\"closed\":$1}}" 2>&1
}
open_body="$(read_queue false)"; rc_open=$?
done_body="$(read_queue true)";  rc_done=$?
rm -f "$cfg"

# One shape is a read; everything else is UNREADABLE. Measured: a forbidden call
# is HTTP 200 {"outcome":"result","result":{"ok":false,"error":"forbidden: ..."}}.
check_read() {  # $1 = body, $2 = rc, $3 = label
  local why
  if [ "$2" -ne 0 ]; then printf 'CLOSE tid=%s UNREADABLE reason=curl-rc-%s queue=%s\n' "$TID" "$2" "$3"; exit 3; fi
  if [ "$(printf '%s' "$1" | jq -r 'if (.outcome == "result" and (.result.ok == true)) then "yes" else "no" end' 2>/dev/null)" != "yes" ]; then
    why="$(printf '%s' "$1" | jq -r '.reason // .result.error // .result.reason // .error // .hint // empty' 2>/dev/null)"
    [ -n "$why" ] || why="unparseable body: $(printf '%s' "$1" | head -c 160)"
    printf 'CLOSE tid=%s UNREADABLE reason=%s queue=%s\n' "$TID" "$why" "$3"; exit 3
  fi
}
check_read "$open_body" "$rc_open" open
check_read "$done_body" "$rc_done" closed

n_open="$(printf '%s' "$open_body" | jq '.result.tasks | length' 2>/dev/null)"
n_done="$(printf '%s' "$done_body" | jq '.result.tasks | length' 2>/dev/null)"
# A count that is not a number would make BOTH arithmetic tests below evaluate
# false and drop this straight through to MISSING — the house bug in my own
# arithmetic. It is UNREADABLE by name instead.
case "${n_open}|${n_done}" in
  ''|*[!0-9\|]*|'|'*|*'|') printf 'CLOSE tid=%s UNREADABLE reason=unparseable-count open=%s closed=%s\n' "$TID" "${n_open:-none}" "${n_done:-none}"; exit 3 ;;
esac

row="$(jq -s -c --arg tid "$TID" '[.[] | .result.tasks[]?] | map(select(.id == $tid)) | .[0] // empty' <<EOF
$open_body
$done_body
EOF
)"

if [ -z "$row" ]; then
  if [ "$n_open" -ge "$LIMIT" ] || [ "$n_done" -ge "$LIMIT" ]; then
    printf 'CLOSE tid=%s UNREADABLE reason=answer-truncated open=%s closed=%s limit=%s\n' "$TID" "$n_open" "$n_done" "$LIMIT"; exit 3
  fi
  if [ "$n_open" -eq 0 ] && [ "$n_done" -eq 0 ]; then
    printf 'CLOSE tid=%s UNREADABLE reason=zero-rows-in-both-queues (subscriptions.ts answers ok:true with no rows when env.DB is absent — an outage wears this exact shape)\n' "$TID"; exit 3
  fi
  printf 'CLOSE tid=%s MISSING open=%s closed=%s\n' "$TID" "$n_open" "$n_done"; exit 2
fi

printf '%s' "$row" | jq -r -f "$JQF"
exit 0
