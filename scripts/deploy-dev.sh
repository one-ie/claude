#!/usr/bin/env bash
# deploy-dev.sh - ship one.ie/web to https://dev.one.ie (worker `one-dev`).
#
# THE TWO-TIER RULE:
#   dev.one.ie  - agents finish loops here. MINIMUM gate: the fast lane only.
#   one.ie      - humans promote here. FULL gate: ./deploy (FULL_VERIFY=1).
# A fast pass is never reported as a full pass.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB="$ROOT/one.ie/web"
cd "$WEB"

echo "[deploy-dev] target: https://dev.one.ie  worker: one-dev"

# 2. the MINIMUM gate - fast lane, through the governor. Never the full suite.
if [ "${DEV_SKIP_GATE:-0}" = "1" ]; then
  echo "[deploy-dev] gate SKIPPED (DEV_SKIP_GATE=1) - you asked for it"
else
  echo "[deploy-dev] gate: FAST LANE (not a full pass)"
  bash "$ROOT/.claude/scripts/gate-run.sh" devgate -- bun run verify:fast
fi

# 3. build + ship against the dev config
bash "$ROOT/.claude/scripts/gate-run.sh" devbuild -- bun run build

# derive the dev config FROM the astro build output, so it can never drift from
# what production actually ships (and so `main` + the assets binding come along)
python3 "$ROOT/.claude/scripts/gen-dev-config.py" || exit 1
npx wrangler deploy --config dist/server/wrangler.dev.json

# 4. prove it answers
code=$(curl -s -o /dev/null -w '%{http_code}' https://dev.one.ie/ --max-time 20 || echo 000)
echo "[deploy-dev] https://dev.one.ie -> HTTP $code"
[ "$code" = "200" ] || { echo "[deploy-dev] FAILED - dev.one.ie did not answer 200"; exit 1; }
echo "[deploy-dev] done. Promote to production with: ./deploy   (full gate, human decision)"
