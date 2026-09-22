#!/usr/bin/env bash
# typedb-flap-recorder.sh — record the NEXT production flap in full, so it does
# not have to be reconstructed by hand the way 2026-07-28/29 was.
#
# The cluster is healthy between failures, which is exactly why this is hard:
# by the time anyone looks, the transition is gone. This samples the three
# layers that fail INDEPENDENTLY and timestamps every change of state:
#
#   /v1/health   204  — readiness. Cheapest, and the first to go.
#   /v1/signin   200  — auth path. Can pass while queries fail.
#   /v1/query    200  — the data plane actually doing work, with latency.
#
# The doc's open question is whether the backend dies under no load. This answers
# it with a timeline instead of an inference: if health flips to 5xx while this
# is the only client, that is measured, not argued.
#
# Usage:
#   bash .claude/scripts/typedb-flap-recorder.sh              # foreground
#   nohup bash .claude/scripts/typedb-flap-recorder.sh &      # leave it running
#   INTERVAL=5 bash .claude/scripts/typedb-flap-recorder.sh   # tighter sampling
#
# Log: text/typedb-flap-log.tsv (append-only, gitignored-safe to commit if short)
#   ts  health  signin  query  query_ms  note
#
# Writes a line on EVERY sample to the log, but prints to the terminal only when
# the state CHANGES — so a week of green is quiet and the flap is loud.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG="${FLAP_LOG:-$ROOT/text/typedb-flap-log.tsv}"
INTERVAL="${INTERVAL:-15}"

eval "$(python3 - "$ROOT/.claude/typedb/prod.env" <<'PY'
import re,sys,shlex
try: f = open(sys.argv[1], errors="replace")
except OSError: sys.exit(0)
for line in f:
    m = re.match(r'^\s*(?:export\s+)?(TYPEDB_(?:URL|DATABASE|USERNAME|PASSWORD))\s*=\s*(.*?)\s*$', line)
    if m: print(f"{m.group(1)}={shlex.quote(m.group(2).strip(chr(34)+chr(39)))}")
PY
)"
: "${TYPEDB_URL:=}" "${TYPEDB_DATABASE:=one}" "${TYPEDB_USERNAME:=admin}" "${TYPEDB_PASSWORD:=}"
[ -z "$TYPEDB_URL" ] && { echo "CANNOT RUN: no TYPEDB_URL in .claude/typedb/prod.env" >&2; exit 3; }
case "$TYPEDB_URL" in
  *127.0.0.1*|*localhost*) echo "refusing: prod.env points at a LOCAL substrate — nothing to record" >&2; exit 2 ;;
esac

[ -f "$LOG" ] || printf 'ts\thealth\tsignin\tquery\tquery_ms\tnote\n' > "$LOG"
echo "recording $TYPEDB_URL every ${INTERVAL}s -> $LOG   (ctrl-c to stop)"

last=""
while true; do
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  health=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$TYPEDB_URL/v1/health")
  tok=$(curl -s -m 10 -X POST "$TYPEDB_URL/v1/signin" -H 'Content-Type: application/json' \
        -d "{\"username\":\"$TYPEDB_USERNAME\",\"password\":\"$TYPEDB_PASSWORD\"}" \
        | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("token",""))
except Exception: print("")' 2>/dev/null)
  if [ -n "$tok" ]; then
    signin=200
    t0=$(python3 -c 'import time;print(int(time.time()*1000))')
    query=$(curl -s -o /dev/null -m 30 -w '%{http_code}' -X POST "$TYPEDB_URL/v1/query" \
      -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
      -d "{\"databaseName\":\"$TYPEDB_DATABASE\",\"transactionType\":\"read\",\"query\":\"match \$x isa thing; reduce \$c = count;\"}")
    t1=$(python3 -c 'import time;print(int(time.time()*1000))')
    qms=$((t1 - t0))
  else
    # A signin that returns no token is NOT necessarily auth failure — on this
    # cluster it is usually the backend being gone. Record the transport code.
    signin=$(curl -s -o /dev/null -m 10 -w '%{http_code}' -X POST "$TYPEDB_URL/v1/signin" \
             -H 'Content-Type: application/json' \
             -d "{\"username\":\"$TYPEDB_USERNAME\",\"password\":\"$TYPEDB_PASSWORD\"}")
    query="-"; qms="-"
  fi

  state="$health/$signin/$query"
  note=""
  [ "$state" != "$last" ] && [ -n "$last" ] && note="STATE CHANGE from $last"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$ts" "$health" "$signin" "$query" "$qms" "$note" >> "$LOG"
  if [ "$state" != "$last" ]; then
    printf '%s  health=%-4s signin=%-4s query=%-4s %sms  %s\n' "$ts" "$health" "$signin" "$query" "$qms" "$note"
    last="$state"
  fi
  sleep "$INTERVAL"
done
