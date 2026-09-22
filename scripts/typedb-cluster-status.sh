#!/usr/bin/env bash
# typedb-cluster-status.sh — read the TypeDB Cloud CONTROL plane and answer the
# one question the data plane cannot: is the instance running and the process
# dying, or is the instance never coming up at all?
#
# This is step 1 of text/typedb-production-problem-solutions.md § Solutions.
# Everything else about the cluster (resize vs rebuild vs escalate) is guessing
# until this is read.
#
#   servers present but unhealthy  -> instance runs, TypeDB process fails
#                                     => resource limits, resize (solution 2)
#   servers empty / missing        -> instance is not being provisioned
#                                     => platform issue, TypeDB support (solution 4)
#   servers appear/disappear       -> crash loop, which is what the external
#     between polls                  behaviour has looked like all along
#
# Usage:
#   bash .claude/scripts/typedb-cluster-status.sh          # one read
#   bash .claude/scripts/typedb-cluster-status.sh --watch  # poll 10x/5s — catches a crash loop
#
# Needs ONE secret this machine does not have. Mint it in the TypeDB Cloud
# console (Settings -> API keys) and put it in .claude/typedb/prod.env
# (gitignored, mode 600):
#
#   TYPEDB_CLOUD_TOKEN=<the key>
#
# The team / space / cluster IDs are DISCOVERED from the token — don't hunt for
# them. Override only if discovery picks the wrong one:
#   TYPEDB_CLOUD_TEAM_ID= / TYPEDB_CLOUD_SPACE_ID= / TYPEDB_CLOUD_CLUSTER_ID=
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROD_ENV="$ROOT/.claude/typedb/prod.env"
API="${TYPEDB_CLOUD_API:-https://cloud.typedb.com}"
WATCH=0; [ "${1:-}" = "--watch" ] && WATCH=1

[ -f "$PROD_ENV" ] && eval "$(python3 - "$PROD_ENV" <<'PY'
import re,sys,shlex
for line in open(sys.argv[1], errors="replace"):
    m = re.match(r'^\s*(?:export\s+)?(TYPEDB_CLOUD_\w+)\s*=\s*(.*?)\s*$', line)
    if m: print(f"{m.group(1)}={shlex.quote(m.group(2).strip(chr(34)+chr(39)))}")
PY
)"
: "${TYPEDB_CLOUD_TOKEN:=}" "${TYPEDB_CLOUD_TEAM_ID:=}" "${TYPEDB_CLOUD_SPACE_ID:=}" "${TYPEDB_CLOUD_CLUSTER_ID:=}"

if [ -z "$TYPEDB_CLOUD_TOKEN" ]; then
  cat >&2 <<EOF
CANNOT RUN: no TYPEDB_CLOUD_TOKEN.

This is the control-plane credential, and it is NOT the same as the four
TYPEDB_* keys already in prod.env — those log in to the cluster to run queries
and carry no authority over the instance.

  1. TypeDB Cloud console -> Settings -> API keys -> create
  2. printf 'TYPEDB_CLOUD_TOKEN=%s\n' '<key>' >> $PROD_ENV
     chmod 600 $PROD_ENV
  3. re-run this script

Verified reachable 2026-07-29: ${API}/api/v1/{team,teams,clusters,user} all
answer 401 UNAUTHENTICATED_REQUEST, so the API is live and only wants the key.
EOF
  exit 3
fi

# The console has used more than one header scheme over time; try each and keep
# whichever authenticates, rather than guessing one and reporting a false 401.
AUTH=""
for scheme in "Authorization: Bearer $TYPEDB_CLOUD_TOKEN" "X-API-Key: $TYPEDB_CLOUD_TOKEN" "Authorization: $TYPEDB_CLOUD_TOKEN"; do
  code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' -H "$scheme" "$API/api/v1/teams")
  [ "$code" = "200" ] && { AUTH="$scheme"; break; }
done
if [ -z "$AUTH" ]; then
  echo "CANNOT RUN: token rejected by every auth scheme tried (Bearer / X-API-Key / raw)." >&2
  echo "  The key may be expired, scoped to another team, or the API may have moved." >&2
  exit 3
fi

get() { curl -s -m 30 -H "$AUTH" "$API$1"; }

# ── discover the IDs so nobody has to hunt for them ───────────────────────
[ -z "$TYPEDB_CLOUD_TEAM_ID" ] && TYPEDB_CLOUD_TEAM_ID=$(get /api/v1/teams | python3 -c '
import sys,json
try:
    d=json.load(sys.stdin)
    ts=d.get("teams") or d.get("data") or (d if isinstance(d,list) else [])
    print((ts[0].get("id") or ts[0].get("uuid") or ts[0].get("slug") or "") if ts else "")
except Exception: print("")')
[ -z "$TYPEDB_CLOUD_TEAM_ID" ] && { echo "CANNOT RUN: authenticated, but no team returned." >&2; exit 3; }

[ -z "$TYPEDB_CLOUD_SPACE_ID" ] && TYPEDB_CLOUD_SPACE_ID=$(get "/api/v1/team/$TYPEDB_CLOUD_TEAM_ID/spaces" | python3 -c '
import sys,json
try:
    d=json.load(sys.stdin)
    ss=d.get("spaces") or d.get("data") or (d if isinstance(d,list) else [])
    print((ss[0].get("id") or ss[0].get("uuid") or ss[0].get("slug") or "") if ss else "")
except Exception: print("")')

BASE="/api/v1/team/$TYPEDB_CLOUD_TEAM_ID/spaces/$TYPEDB_CLOUD_SPACE_ID/clusters"
echo "team=$TYPEDB_CLOUD_TEAM_ID space=$TYPEDB_CLOUD_SPACE_ID"

report() {
  get "$BASE${TYPEDB_CLOUD_CLUSTER_ID:+/$TYPEDB_CLOUD_CLUSTER_ID}" | python3 - "$@" <<'PY'
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("  (unparseable response)"); sys.exit(0)
cs = d.get("clusters") or d.get("data") or (d if isinstance(d, list) else [d])
for c in cs:
    if not isinstance(c, dict): continue
    name = c.get("id") or c.get("name") or c.get("slug") or "?"
    servers = c.get("servers") or []
    line = f"  cluster {name}  status={c.get('status','?')}  tier={c.get('machineType') or c.get('tier') or c.get('size','?')}  servers={len(servers)}"
    for s in servers:
        line += f"\n      server {s.get('id') or s.get('name','?')}  status={s.get('status','?')}"
    print(line)
    if not servers:
        print("      NO SERVERS -> the instance is not being provisioned. Platform issue: raise with TypeDB support.")
    elif any(str(s.get("status","")).lower() not in ("running","ready","healthy") for s in servers):
        print("      UNHEALTHY SERVER -> the instance runs and the TypeDB process fails. Resource limits: resize.")
PY
}

if [ $WATCH -eq 1 ]; then
  echo "polling 10x every 5s — servers appearing and disappearing between polls IS the crash loop"
  for i in $(seq 1 10); do printf '[%02d] ' "$i"; report; sleep 5; done
else
  report
fi
