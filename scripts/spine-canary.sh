#!/bin/bash
# spine-canary.sh — C7 nightly home. Walks a client spine in canary mode.
# The spine's data/actors/<kind>.toml lives in a SEPARATE git repo
# (apps/vespio/clients/<slug>/) that is never bundled into the one-prod
# Cloudflare Worker, so this cannot run as a CF cron — it runs here, on the
# machine that has both checkouts, same pattern as backup/scripts/pull-backup.ts.
set -euo pipefail

REPO_ROOT="/Users/toc/Server/one-ie"
CLIENT_SLUG="${SPINE_CANARY_SLUG:-elitemoversca}"
ACTOR_KIND="${SPINE_CANARY_KIND:-customer}"

export SPINE_CLIENT_DIR="/Users/toc/Server/apps/vespio/clients/${CLIENT_SLUG}"
export ONE_API_URL="${ONE_API_URL:-https://one.ie}"
if [ -f "$REPO_ROOT/one.ie/web/.env" ]; then
  export GATEWAY_SERVICE_SECRET="$(grep -m1 '^GATEWAY_SERVICE_SECRET=' "$REPO_ROOT/one.ie/web/.env" | cut -d= -f2-)"
fi

cd "$REPO_ROOT/one.ie/web"
exec bun scripts/spine-walk.ts "$ACTOR_KIND" --mode=canary
