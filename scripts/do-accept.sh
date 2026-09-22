#!/usr/bin/env bash
# do-accept.sh — record a human's merge/abandon decision on a do/<slug> branch.
#
# The cost-per-accepted-change signal (the one the improvements queue flagged and
# the trust ladder needs). Trust climbs on ACCEPTED change, not self-graded
# rubric. Run at the merge gate: `do-accept.sh <slug> accept` when you land a
# branch, `do-accept.sh <slug> reject` when you abandon it. Updates the rolling
# acceptCount/acceptTotal in .do-trust.json — autonomyLevel (do-autonomous.ts)
# reads them to decide L3 (auto-build) / L4 (auto-merge).
#
# Mirrors recordAccept() in one.ie/web/src/lib/do-autonomous.ts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRUST="$ROOT/.do-trust.json"
slug="${1:?usage: do-accept.sh <slug> accept|reject}"
decision="${2:?usage: do-accept.sh <slug> accept|reject}"
case "$decision" in accept|reject) ;; *) echo "decision must be accept|reject" >&2; exit 2 ;; esac

python3 - "$TRUST" "$slug" "$decision" << 'PY'
import json, sys, os
trust_path, slug, decision = sys.argv[1], sys.argv[2], sys.argv[3]
t = {}
if os.path.exists(trust_path):
    try: t = json.load(open(trust_path))
    except Exception: t = {}
t["acceptCount"] = int(t.get("acceptCount", 0)) + (1 if decision == "accept" else 0)
t["acceptTotal"] = int(t.get("acceptTotal", 0)) + 1
rate = t["acceptCount"] / t["acceptTotal"] if t["acceptTotal"] else 0.0
t["acceptRate"] = round(rate, 4)
json.dump(t, open(trust_path, "w"), indent=2)
print(f"[do-accept] {slug} {decision} → {t['acceptCount']}/{t['acceptTotal']} accepted (rate {t['acceptRate']})")
# echo the level gate the ladder would now allow (informational)
if t["acceptTotal"] >= 20 and rate >= 0.9: lvl = "L4 (auto-merge eligible)"
elif t["acceptTotal"] >= 10 and rate >= 0.7: lvl = "L3 (auto-build eligible)"
else: lvl = "L1-L2 (build stays supervised)"
print(f"[do-accept] trust ladder: {lvl}")
PY
