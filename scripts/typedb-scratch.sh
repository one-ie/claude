#!/usr/bin/env bash
# typedb-scratch.sh — create (or refresh) a LOCAL scratch database carrying the
# live `one` schema, for integration tests that must never touch `one`.
#
# Why this exists: `factory-check.sh belief-guard` runs a real-substrate test
# (repo rule: never mock TypeDB) and needs TYPEDB_TEST_DB pointing at a database
# that already has the schema — the test defines none of its own. Hand-building
# that db is a step nobody remembers, and an empty db reports as `cannot run`, so
# the check silently never proves anything.
#
# Usage:
#   bash .claude/scripts/typedb-scratch.sh [name]     # default: belieftest
#   export TYPEDB_TEST_DB=belieftest                  # then run the checks
#
# Refuses anything but a local substrate: this DROPS and recreates the database.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="${1:-belieftest}"

if [ "$NAME" = "one" ]; then
  echo "refusing: 'one' is the working database, not a scratch db" >&2; exit 2
fi

# An explicitly-exported TYPEDB_URL wins over .env. Without this the eval below
# silently overwrites it, which makes the local-only guard untestable and means a
# caller who thinks they are pointing somewhere else is not.
_ENV_URL="${TYPEDB_URL:-}"
eval "$(python3 - "$ROOT/one.ie/web/.env" <<'PY'
import re,sys,shlex
for line in open(sys.argv[1], errors="replace"):
    m = re.match(r'^\s*(TYPEDB_(?:URL|DATABASE|USERNAME|PASSWORD))\s*=\s*(.*?)\s*$', line)
    if m: print(f"{m.group(1)}={shlex.quote(m.group(2).strip(chr(34)+chr(39)))}")
PY
)"
: "${TYPEDB_URL:=}" "${TYPEDB_DATABASE:=one}" "${TYPEDB_USERNAME:=admin}" "${TYPEDB_PASSWORD:=}"
[ -n "$_ENV_URL" ] && TYPEDB_URL="$_ENV_URL"

case "$TYPEDB_URL" in
  *127.0.0.1*|*localhost*) ;;
  *) echo "refusing: TYPEDB_URL is not local ($TYPEDB_URL). Run typedb-env.sh dev first." >&2; exit 2 ;;
esac

TOK=$(curl -s -m 15 -X POST "$TYPEDB_URL/v1/signin" -H 'Content-Type: application/json' \
  -d "{\"username\":\"$TYPEDB_USERNAME\",\"password\":\"$TYPEDB_PASSWORD\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))' 2>/dev/null)
[ -z "$TOK" ] && { echo "cannot run: local TypeDB signin failed at $TYPEDB_URL" >&2; exit 3; }

SCHEMA=$(mktemp); trap 'rm -f "$SCHEMA" "$REQ"' EXIT
curl -s -m 30 -H "Authorization: Bearer $TOK" "$TYPEDB_URL/v1/databases/$TYPEDB_DATABASE/schema" > "$SCHEMA"
[ -s "$SCHEMA" ] || { echo "cannot run: could not read the $TYPEDB_DATABASE schema" >&2; exit 3; }

curl -s -o /dev/null -X DELETE "$TYPEDB_URL/v1/databases/$NAME" -H "Authorization: Bearer $TOK"
curl -s -o /dev/null -X POST   "$TYPEDB_URL/v1/databases/$NAME" -H "Authorization: Bearer $TOK"

# ensure_ascii=False is load-bearing: json.dumps' default escapes non-ASCII to
# \uXXXX, and a \uXXXX inside TypeQL PANICS TypeDB 3.8.3 — it kills the server
# process rather than returning an error. See
# text/typedb-production-problem-solutions.md § Two queries that kill a 3.8.3 server.
REQ=$(mktemp)
python3 - "$SCHEMA" "$NAME" > "$REQ" <<'PY'
import json,sys
print(json.dumps({"databaseName": sys.argv[2], "transactionType": "schema",
                  "query": open(sys.argv[1]).read()}, ensure_ascii=False))
PY
RES=$(curl -s -m 60 -X POST "$TYPEDB_URL/v1/query" -H "Authorization: Bearer $TOK" \
      -H 'Content-Type: application/json' --data-binary @"$REQ")

case "$RES" in
  *'"answerType":"ok"'*)
    echo "scratch db '$NAME' ready — $(wc -c < "$SCHEMA" | tr -d ' ') chars of schema"
    echo "  export TYPEDB_TEST_DB=$NAME" ;;
  *) echo "failed to define schema in '$NAME': ${RES:0:300}" >&2; exit 1 ;;
esac
