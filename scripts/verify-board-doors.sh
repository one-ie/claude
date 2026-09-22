#!/usr/bin/env bash
# verify-board-doors.sh — did the tasks:board / tasks:bulk ship actually land in prod?
#
# Run BEFORE the ship to capture RED, and AFTER to confirm GREEN. A checker never shown
# to fail proves nothing — running it twice IS the instrument proof.
#
#   bash .claude/scripts/verify-board-doors.sh
#
# Gate row: task:01a09b3e3c8564b1eabb984a (p0.97, blocker)
# Honest sibling: task:01a09b7497bdd80ac761b825 — tasks:board has NEVER been called
# against a real substrate. These probes are the first time it ever will be.
set -uo pipefail
BASE="${ONE_API_URL:-https://one.ie}"
ENVF="${ONE_ENV_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/one.ie/web/.dev.vars}"
KEY="${GATEWAY_API_KEY:-$(grep -m1 '^GATEWAY_API_KEY' "$ENVF" 2>/dev/null | cut -d= -f2- | tr -d '"')}"
red=0; green=0

# WITHOUT a key every door answers 403 "direct substrate access not permitted" and every
# line below reads RED for the wrong reason. The first version of this script did exactly
# that; the CONTROL is what caught it.
[ -n "$KEY" ] || { echo "NO KEY — set GATEWAY_API_KEY or ONE_ENV_FILE. Refusing to report."; exit 2; }

probe() { # name · expect-regex · receiver · payload
  local name="$1" expect="$2" rcv="$3" payload="$4" body
  body=$(curl -s -m 25 -X POST "$BASE/api/ask/$rcv" -H "Authorization: Bearer $KEY" \
    -H 'content-type: application/json' -d "$payload" 2>&1 | head -c 400)
  if printf '%s' "$body" | grep -qE "$expect"; then
    printf '  GREEN  %-36s\n' "$name"; green=$((green+1))
  else
    printf '  RED    %-36s %s\n' "$name" "$(printf '%s' "$body" | tr -d '\n' | head -c 130)"; red=$((red+1))
  fi
}

echo "== board doors, against $BASE =="

# CONTROL FIRST. If this is RED the key or the host is wrong and every other line is
# meaningless rather than informative. Never read the results above a red control.
probe "CONTROL tasks:everywhere" '"ok":true' 'tasks:everywhere' '{"data":{"workspace":"one","limit":1}}'

# 1. tasks:board — answers `unknown_receiver` until this ships.
probe "tasks:board summary" '"total"' 'tasks:board' '{"data":{"workspace":"one","view":"summary"}}'

# 2. tasks:bulk where+set — prod takes `edits` only until this ships.
probe "tasks:bulk where+set dryRun" '"ok":true|matched|dryRun' 'tasks:bulk' \
  '{"data":{"workspace":"one","where":{"status":"open"},"set":{"addTags":["_probe"]},"dryRun":true}}'

# 3. tasks:bulk `creates` with a priority — the ONLY door that can file a row the
#    priority-sorted board can see. tasks:create still has no priority parameter, which
#    is why 407 of 730 open rows carry none and the count grows with every filing.
#    IT CLEANS UP AFTER ITSELF. The first version of this script left a _probe row on
#    every run — which made the checker a source of exactly the orphan exhaust it was
#    written to measure. A probe that litters the thing it measures is not a probe.
body=$(curl -s -m 25 -X POST "$BASE/api/ask/tasks:bulk" -H "Authorization: Bearer $KEY" \
  -H 'content-type: application/json' \
  -d '{"data":{"workspace":"one","creates":[{"ref":"p","title":"_probe verify-board-doors — auto-dissolved","priority":0.01}]}}' 2>&1 | head -c 400)
ptid=$(printf '%s' "$body" | grep -oE 'task:[0-9a-f]{24}' | head -1)
if printf '%s' "$body" | grep -q '"ok":true'; then
  printf '  GREEN  %-36s\n' "tasks:bulk creates takes priority"; green=$((green+1))
else
  printf '  RED    %-36s %s\n' "tasks:bulk creates takes priority" "$(printf '%s' "$body" | tr -d '\n' | head -c 130)"; red=$((red+1))
fi
if [ -n "$ptid" ]; then
  swept=$(curl -s -m 20 -X POST "$BASE/api/ask/tasks:bulk" -H "Authorization: Bearer $KEY" \
    -H 'content-type: application/json' \
    -d "{\"data\":{\"workspace\":\"one\",\"edits\":[{\"tid\":\"$ptid\",\"status\":\"dissolved\"}]}}" | grep -c '"ok":true')
  [ "$swept" -ge 1 ] && printf '         swept %s\n' "$ptid" || printf '         WARN could not sweep %s — dissolve it by hand\n' "$ptid"
fi

# 4. Single-row read door. Expected RED even AFTER this ship — "tasks:get" is 0 hits in
#    dev's receivers.ts. Listed so its absence stays visible instead of being forgotten.
code=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$BASE/api/things/task:01a09b3e3c8564b1eabb984a")
if [ "$code" = "200" ]; then printf '  GREEN  %-36s\n' "GET /api/things/<tid>"; green=$((green+1))
else printf '  RED    %-36s HTTP %s — no single-row read door (EXPECTED, not a ship failure)\n' "GET /api/things/<tid>" "$code"; red=$((red+1)); fi

echo
echo "  green=$green red=$red"
echo "  BEFORE the ship: CONTROL green · doors 1-3 RED · door 4 RED"
echo "  AFTER  the ship: CONTROL green · doors 1-3 GREEN · door 4 still RED"
echo "  CONTROL red => the probe is broken, not the ship. Ignore every other line."
[ "$red" -gt 0 ] && exit 1 || exit 0
