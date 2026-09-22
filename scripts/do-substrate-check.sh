#!/usr/bin/env bash
# do-substrate-check.sh — can this machine reach TypeDB DIRECTLY, right now?
#
# Distinct from `do-rank.py --board-check`, which asks whether the *gateway*
# accepts us as a service caller. The two fail independently and the difference
# decides what is provable:
#   board-check RED + substrate GREEN → board logic is testable against the real
#     cluster by calling resolvers directly; anything routed through api.one.ie
#     or one.ie is not.
#   substrate RED → no test that touches the graph can prove anything, and a
#     `describe.skipIf(...)` suite will PASS while proving nothing (a skipped
#     test is a green test — never let an accept: rest on one).
#
# Reads TYPEDB_URL / TYPEDB_USERNAME / TYPEDB_PASSWORD from one.ie/web/.env.
# Never echoes the password or the returned token.
#
# Usage: do-substrate-check.sh [--quiet]
# Exit: 0 = reachable and authenticating · 1 = unreachable/refused · 2 = no creds
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true
say() { $QUIET || echo "$@"; }

ENVF=one.ie/web/.env
val() { grep -h "^$1=" "$ENVF" 2>/dev/null | head -1 | sed 's/^[^=]*=//; s/^"//; s/"$//'; }

URL=$(val TYPEDB_URL); USER=$(val TYPEDB_USERNAME); PASS=$(val TYPEDB_PASSWORD)
if [ -z "$URL" ] || [ -z "$USER" ] || [ -z "$PASS" ]; then
  say "[substrate] NO CREDS — TYPEDB_URL/USERNAME/PASSWORD missing from $ENVF"
  exit 2
fi

# Credentials ride a temp file, never argv: a bare --data on the command line is
# visible to any local user via `ps` for the life of the process.
BODY=$(mktemp); chmod 600 "$BODY"
printf '{"username":"%s","password":"%s"}' "$USER" "$PASS" > "$BODY"
CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 \
  -X POST "$URL/v1/signin" -H 'Content-Type: application/json' \
  --data-binary @"$BODY" 2>/dev/null)
rm -f "$BODY"

if [ "$CODE" = "200" ]; then
  say "[substrate] GREEN — ${URL} authenticates"
  exit 0
fi
say "[substrate] RED — ${URL}/v1/signin → HTTP ${CODE:-no-response}"
exit 1
