#!/usr/bin/env bash
# deploy-schema-check.sh — PARSE schema/deploy.tql with TypeDB. Not a grep.
#
# classification: needs-env
#
# WHY THIS EXISTS. The first version of this feature's acceptance check was
# `grep -q 'fun deploy_unrun' schema/deploy.tql`, and it passed on a file TypeDB
# REJECTED outright (TQL03: `return not { $t };` is not valid TypeQL). A grep
# proves a string is present; only the parser proves the schema is a schema.
#
# THREE EXIT CODES, because red and cannot-run send a human to opposite places:
#   0  the file loads into a scratch db carrying the live `one` schema
#   1  RED — TypeDB rejected it; the error is printed
#   3  CANNOT RUN — no local TypeDB (creds absent / cluster unreachable).
#      NOT a red: nothing was learned, and a board that paints this as failure
#      sends someone to rewrite a correct schema.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 3
ENVF="${ONE_ENV_FILE:-${DO_ENV_FILE:-.claude/typedb/dev.env}}"
[ -f "$ENVF" ] || { echo "CANNOT RUN: no $ENVF"; exit 3; }
set -a; . "$ENVF"; set +a
: "${TYPEDB_URL:?}" 2>/dev/null || { echo "CANNOT RUN: TYPEDB_URL unset"; exit 3; }
curl -sf -o /dev/null --max-time 5 "$TYPEDB_URL/v1/health" 2>/dev/null \
  || { echo "CANNOT RUN: TypeDB unreachable at $TYPEDB_URL"; exit 3; }

DB="${DEPLOY_SCHEMA_CHECK_DB:-deployschemacheck}"
bash "$ROOT/.claude/scripts/typedb-scratch.sh" "$DB" >/dev/null 2>&1 \
  || { echo "CANNOT RUN: could not build scratch db '$DB'"; exit 3; }

python3 - "$TYPEDB_URL" "$TYPEDB_USERNAME" "$TYPEDB_PASSWORD" "$DB" <<'PY'
import sys, json, urllib.request, urllib.error
url, user, pw, db = sys.argv[1:5]
def post(path, body, tok=None):
    h = {"Content-Type": "application/json"}
    if tok: h["Authorization"] = "Bearer " + tok
    return urllib.request.urlopen(
        urllib.request.Request(url + path, data=json.dumps(body).encode(), headers=h),
        timeout=90).read().decode()
try:
    tok = json.loads(post("/v1/signin", {"username": user, "password": pw}))["token"]
except Exception as e:
    print("CANNOT RUN: signin failed —", e); sys.exit(3)
q = open("schema/deploy.tql").read()
try:
    post("/v1/query", {"query": q, "transactionType": "schema", "databaseName": db}, tok)
    n = q.count("\nfun ")
    print(f"ok — TypeDB parsed and defined schema/deploy.tql ({n} functions)")
    sys.exit(0)
except urllib.error.HTTPError as e:
    try:  msg = json.loads(e.read().decode()).get("message", "")
    except Exception: msg = "<unreadable>"
    print("RED — TypeDB REJECTED schema/deploy.tql:")
    print(msg[:900])
    sys.exit(1)
except Exception as e:
    print("CANNOT RUN:", e); sys.exit(3)
PY
