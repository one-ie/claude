#!/usr/bin/env bash
# flywheel-outcome.sh — the kill-switch for text/flywheel-todo.md.
#
# manifest: monorepo-only  (reads one.ie/web/.dev.vars with NO ONE_ENV_FILE indirection and
#                           exits 2 without it; also `cd one.ie/web && npx wrangler d1 execute`.
#                           Corrected from needs-env 2026-09-21: it DIES downstream, not degrades.)
#
# Exits 0 only when the flywheel plan's goal is TRUE in production:
#   1. a child's plan is not readable without auth        (rung 0)
#   2. the router warms on the one shape it has learned    (read edge)
#   3. the world routes tagged work to a head, not a model (namespace)
#   4. a fresh caller with only the workspace key can recall a memory (memory IN)
#   5. a second promise has settled-kept                   (the circuit)
# Every probe is one HTTP call. Each prints its own line; the first red stops nothing —
# all five run so the report shows which are still owed. Measured RED on 2026-09-15.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
K="$(grep -m1 '^GATEWAY_API_KEY' "$ROOT/one.ie/web/.dev.vars" | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d ' ')"
[ -n "$K" ] || { echo "flywheel-outcome: no GATEWAY_API_KEY in one.ie/web/.dev.vars"; exit 2; }
BASE="${ONE_API_URL:-https://one.ie}"
ask() { curl -s -m 40 -X POST "$BASE/api/ask/$1" -H "Authorization: Bearer $K" -H 'Content-Type: application/json' -H 'User-Agent: flywheel-outcome/1' -d "$2"; }
red=0
say() { printf '  %-4s %s\n' "$1" "$2"; [ "$1" = "RED" ] && red=$((red+1)); }

# 1 · rung 0
code="$(curl -s -o /dev/null -w '%{http_code}' -m 30 -H 'User-Agent: flywheel-outcome/1' "$BASE/ehc/cyp-005/plan?as=cyp-voice")"
if [ "$code" != "200" ]; then say OK "rung 0: /ehc/cyp-005/plan?as=cyp-voice → $code without auth"; else say RED "rung 0: /ehc/cyp-005/plan?as=cyp-voice → 200 without auth"; fi

# 2 · router read edge
r="$(ask world:pick-model '{"data":{"shape":"do:complex"}}')"
reason="$(printf '%s' "$r" | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin); r=d.get("result") or d; print(r.get("reason") or d.get("reason") or "?")
except Exception: print("?")')"
if [ "$reason" = "warmed" ]; then say OK "router: world:pick-model do:complex → warmed"; else say RED "router: world:pick-model do:complex → $reason"; fi

# 3 · namespace
a="$(ask world:route '{"data":{"tags":["engineering"],"workspace":"one"}}' | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin); r=d.get("result") or d; print(r.get("actor") or "?")
except Exception: print("?")')"
# world:route is not deterministic across calls (measured 2026-09-15: `chairman` once, `model:sonnet` three
# times in the same minute), so the actor read alone cannot be the gate. The deterministic half is the
# count of tag→model rows in the store the verbs write to: 50 rows / 207.5 strength today, must be 0.
tm="$(cd "$ROOT/one.ie/web" && npx wrangler d1 execute one-owners --remote --json --command "SELECT count(*) AS n FROM claw_paths WHERE source LIKE 'tag:%' AND target LIKE 'model:%'" 2>/dev/null | python3 -c 'import json,sys
try: print(json.load(sys.stdin)[0]["results"][0]["n"])
except Exception: print("?")')"
case "$a" in model:*|factory-turn|"?") say RED "namespace: world:route engineering → $a; tag→model rows = $tm" ;;
  *) if [ "$tm" = "0" ]; then say OK "namespace: world:route engineering → $a; tag→model rows = 0"; else say RED "namespace: world:route engineering → $a, but tag→model rows = $tm (need 0)"; fi ;; esac

# 4 · memory IN
n="$(ask meta:recall '{"data":{"match":"STRIPE_MODE"}}' | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin); r=d.get("result") or d; print(len(r.get("hypotheses") or []))
except Exception: print(0)')"
if [ "${n:-0}" -ge 1 ]; then say OK "memory: meta:recall STRIPE_MODE → $n"; else say RED "memory: meta:recall STRIPE_MODE → ${n:-0}"; fi

# 5 · the circuit — promises settled-kept (D1, read-only)
kept="$(cd "$ROOT/one.ie/web" && npx wrangler d1 execute one-owners --remote --json --command "SELECT count(*) AS n FROM promises WHERE state='settled-kept'" 2>/dev/null | python3 -c 'import json,sys
try: print(json.load(sys.stdin)[0]["results"][0]["n"])
except Exception: print("?")')"
if [ "$kept" != "?" ] && [ "$kept" -ge 2 ] 2>/dev/null; then say OK "circuit: promises settled-kept = $kept"; else say RED "circuit: promises settled-kept = $kept (need ≥ 2)"; fi

echo "flywheel-outcome: $red of 5 RED"
[ "$red" -eq 0 ]
