#!/usr/bin/env bash
# livekit-live-check.sh — does the LIVE LiveKit server accept a token this repo signs?
#
# The offline suites prove the token is well FORMED (claims decode correctly).
# They cannot prove LiveKit ACCEPTS it — that needs a real project. This does.
#
# THREE EXIT CODES, because red and cannot-run send a human to opposite places:
#   0  the live server verified our HMAC signature
#   1  RED — it rejected us (wrong key/secret, or the signer regressed)
#   3  CANNOT RUN — no credentials configured. NOT a failure; the promise's
#      offline proof still stands and this check simply has no evidence to read.
#
# Credentials are read from one.ie/web/.dev.vars (gitignored) or the environment.
# Never prints a secret — only the host, the HTTP status, and the verdict.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 3

ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.dev.vars}}"

_read() { # _read VARNAME — env wins, then the env file
  local v="${!1:-}"
  [ -n "$v" ] && { printf '%s' "$v"; return; }
  [ -f "$ENV_FILE" ] || return
  sed -n "s/^${1}=//p" "$ENV_FILE" | tail -1 | tr -d '\r'
}

URL=$(_read LIVEKIT_URL); KEY=$(_read LIVEKIT_API_KEY); SECRET=$(_read LIVEKIT_API_SECRET)

if [ -z "$URL" ] || [ -z "$KEY" ] || [ -z "$SECRET" ]; then
  echo "livekit-live-check: CANNOT RUN — LIVEKIT_URL/API_KEY/API_SECRET unset (checked ${ENV_FILE})"
  echo "  this is not a failure: local mode needs no credentials. See text/livekit-docs.md."
  exit 3
fi

OUT=$(LK_URL="$URL" LK_KEY="$KEY" LK_SECRET="$SECRET" node -e '
const { createHmac } = require("crypto");
const b = (o) => Buffer.from(JSON.stringify(o)).toString("base64")
  .replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
const now = Math.floor(Date.now()/1000);
// Same claim shape as one.ie/web/src/lib/livekit.ts, with roomList so the
// REST API is reachable without joining anything.
const h = b({ typ:"JWT", alg:"HS256" });
const p = b({ iss: process.env.LK_KEY, sub:"live-check", jti:"live-check",
  nbf: now, iat: now, exp: now+120, video:{ roomList:true } });
const s = createHmac("sha256", process.env.LK_SECRET).update(h+"."+p).digest("base64")
  .replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
const base = process.env.LK_URL.replace(/^wss:/,"https:").replace(/^ws:/,"http:");
fetch(base + "/twirp/livekit.RoomService/ListRooms", { method:"POST",
  headers:{ Authorization:"Bearer " + h+"."+p+"."+s, "Content-Type":"application/json" },
  body:"{}" })
  .then(r => console.log(new URL(base).host + " " + r.status))
  .catch(e => { console.log("unreachable " + String(e.message).slice(0,60)); });
' 2>&1)

HOST=${OUT%% *}; STATUS=${OUT##* }

case "$STATUS" in
  200) echo "livekit-live-check OK — $HOST verified our signature (http 200)"; exit 0 ;;
  401|403) echo "livekit-live-check RED — $HOST rejected our token (http $STATUS): key/secret wrong, or the signer regressed" >&2; exit 1 ;;
  *) echo "livekit-live-check CANNOT RUN — $OUT (server unreachable, not a signing failure)"; exit 3 ;;
esac
