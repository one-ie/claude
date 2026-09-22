#!/usr/bin/env bash
# subdomains-proof.sh — the subdomains promise's proof: — text/subdomains.md
#
# Seeds a disposable fixture agency (plan=agency, a verified parent domain, and a
# world-key to authenticate as it), provisions a disposable client subdomain via
# POST /api/domain?action=provision-subdomain, curls the resulting host with a
# Host-header override and confirms the response is the CLIENT's own workspace
# (page <title> carries the client's identity, not the agency's), then tears
# down every fixture row it created — success or failure (trap).
#
# Exit 0 — provisioned, live-routed to the client's own workspace.
# Exit 1 — an assertion failed.
# Exit 2 — environment not ready (wrangler/curl/jq missing, D1 seed failed).
#
# Env: ONE_API_URL (default http://localhost:4321), ONE_D1_DB (default one-owners).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WEB_DIR="$ROOT/one.ie/web"
API_URL="${ONE_API_URL:-http://localhost:4321}"
DB_NAME="${ONE_D1_DB:-one-owners}"

for bin in curl jq openssl bunx; do
  command -v "$bin" >/dev/null 2>&1 || { echo "[subdomains-proof] $bin required"; exit 2; }
done

# Sanity gate: $API_URL must be the one.ie/web dev server, not a neighbouring
# app squatting the default port (an unauthenticated POST to /api/domain must
# return JSON — the route answers {"error":"unauthorized"}; a squatter serves
# its HTML 404 page).
probe="$(curl -sS --max-time 5 -X POST "$API_URL/api/domain" -H 'Content-Type: application/json' -d '{}' || true)"
if ! printf '%s' "$probe" | jq -e . >/dev/null 2>&1; then
  echo "[subdomains-proof] environment not ready: $API_URL is not the one.ie/web dev server (set ONE_API_URL)"
  exit 2
fi

SUFFIX="$$"
AGENCY="do-proof-agency-$SUFFIX"
CLIENT="do-proof-client-$SUFFIX"
AGENCY_DOMAIN="proof-agency-$SUFFIX.test"
RAW_KEY="one-$(openssl rand -hex 24)"
KEY_HASH="$(printf '%s' "$RAW_KEY" | openssl dgst -sha256 -hex | awk '{print $NF}')"
KEY_ID="$(openssl rand -hex 16)"
CLIENT_HOST="$CLIENT.$AGENCY_DOMAIN"

d1() { (cd "$WEB_DIR" && bunx wrangler d1 execute "$DB_NAME" --local --command "$1"); }

SEEDED=0
AUTHCFG=""
teardown() {
  [ -n "$AUTHCFG" ] && rm -f "$AUTHCFG"
  [ "$SEEDED" -eq 1 ] || return 0
  d1 "DELETE FROM domains WHERE host IN ('$AGENCY_DOMAIN','$CLIENT_HOST');
      DELETE FROM owners WHERE slug IN ('$AGENCY','$CLIENT');
      DELETE FROM world_keys WHERE actor_id = '$AGENCY';
      DELETE FROM world_actors WHERE aid = '$AGENCY';" >/dev/null 2>&1
}
trap teardown EXIT
# Token off argv (ps aux would leak a bare -H value) — one private 0600 curl
# --config file for the process lifetime.
AUTHCFG="$(mktemp)"; chmod 600 "$AUTHCFG"
printf 'header = "Authorization: Bearer %s"\n' "$RAW_KEY" >"$AUTHCFG"

d1 "INSERT INTO owners (slug, pubkey, credential_id, plan) VALUES ('$AGENCY','group','group','agency');
    INSERT INTO world_actors (aid, name, type) VALUES ('$AGENCY','$AGENCY','agent');
    INSERT INTO world_keys (key_id, key_hash, actor_id, label) VALUES ('$KEY_ID','$KEY_HASH','$AGENCY','subdomains-proof');
    INSERT INTO domains (host, gid, verified_at) VALUES ('$AGENCY_DOMAIN','group:$AGENCY', unixepoch());" >/dev/null 2>&1
if [ $? -ne 0 ]; then echo "[subdomains-proof] seed failed"; exit 2; fi
SEEDED=1

resp="$(curl -sS --max-time 10 -X POST "$API_URL/api/domain?action=provision-subdomain" \
  -H 'Content-Type: application/json' --config "$AUTHCFG" \
  -d "$(jq -nc --arg s "$AGENCY" --arg c "$CLIENT" '{slug:$s,parentSlug:$s,clientSlug:$c}')")"
host="$(printf '%s' "$resp" | jq -r '.host // empty')"
has_edge="$(printf '%s' "$resp" | jq 'has("edgeRouted")')"
echo "[subdomains-proof] provision host=$host edgeRouted-present=$has_edge resp=$resp"
if [ "$host" != "$CLIENT_HOST" ] || [ "$has_edge" != "true" ]; then
  echo "[subdomains-proof] FAIL — unexpected provision response"
  exit 1
fi

page="$(curl -sS --max-time 10 -H "Host: $CLIENT_HOST" "$API_URL/")"
case "$page" in
  *"@$CLIENT"*) : ;;
  *) echo "[subdomains-proof] FAIL — live host did not serve the client's own workspace"; exit 1 ;;
esac
case "$page" in
  *"@$AGENCY"*) echo "[subdomains-proof] FAIL — live host served the agency's workspace instead"; exit 1 ;;
esac

echo "[subdomains-proof] PASS — $CLIENT_HOST provisioned live and routed to $CLIENT's own workspace"
exit 0
