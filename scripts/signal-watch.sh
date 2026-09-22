#!/usr/bin/env bash
# signal-watch.sh — watch signals travel through the factory's gates, live,
# with a budget per door and a ledger that tracks speed over time.
#
# manifest: needs-env   (reads GATEWAY_API_KEY from the shell or one.ie/web/.env;
#                        the local lane reads one.ie/web/.dev.vars)
#
# USAGE
#   bash .claude/scripts/signal-watch.sh                 both lanes, once
#   bash .claude/scripts/signal-watch.sh --prod|--local  one lane
#   bash .claude/scripts/signal-watch.sh --watch 30      redraw every 30s
#   bash .claude/scripts/signal-watch.sh --json          one JSON line per door
#   bash .claude/scripts/signal-watch.sh --self-test     the red proofs
#
# THE DOORS are the five HTTP hops the factory's own path makes (text/factory-do.md
# § THE ONE PATH: classify · size · board · claim · close) plus the world door the
# hooks and do-signal.sh post to, plus the stream the listeners sit on:
#
#   health            GET  /api/health                       the worker answers
#   world:announce    POST a canary tagged [signal-watch-wire] on the
#                     MARKETPLACE board — intake's door.
#                     The wire, and only the wire: zero subscribers matched, so
#                     the number is the door's own cost with no fan-out in it.
#                     It used to be sent on the caller's own board and the header
#                     claimed it "matches nobody by design" — it matched `ceo`,
#                     which subscribes to EVERY tag by canon (root CLAUDE.md: the
#                     CEO is the default receiver, always listening). Measured
#                     2026-09-08 on prod server-timing, same door, one variable:
#                     matched=0 -> data 259/332/401 ms; matched=1 -> data
#                     1535..2066 ms. So ~1.3s per matched subscriber was being
#                     read as "the wire". The probe now ASSERTS matched=0 and
#                     goes UNRUN if it ever matches — a wire probe that fanned
#                     out did not measure the wire, and an unrun door is not a
#                     pass. The fan-out's own cost is a separate finding
#                     (text/announce-fanout-plan.md), not a budget to widen.
#                     BOTH halves are load-bearing and both were measured
#                     wrong before: the BOARD (own board -> `ceo`, who
#                     follows every tag) and the TAG (`cc` on the marketplace
#                     board -> the live `cc-proof-listener`, found 2026-09-08
#                     by this very assertion on its first run). Hence a
#                     RESERVED tag nobody stakes, on the shared board. If
#                     someone ever stakes `signal-watch-wire`, the row goes
#                     unrun and says so, rather than quietly reporting a
#                     fan-out as the wire.
#   tasks:everywhere  POST {workspace:factory-do}             the board read
#   factory:size      POST {paths:[this file]}                the size hop
#   stream            GET  channels.one.ie/stream/space:vespio  time to first byte
#
# EVERY ROW CARRIES the server-timing phases the worker itself reports
# (auth · data · det) and cf-placement, so "slow" is never a single number:
# you can read WHICH leg paid. Measured 2026-09-05: D1 `one-owners` runs in
# APAC, TypeDB Cloud in Virginia, and Smart Placement runs one-prod at ORD about
# one call in three — so every substrate call pays one Pacific leg somewhere.
#
# VERDICTS, four states, the same vocabulary as do-w4-gates.sh:
#   pass   200, the receiver answered `outcome:result`, wall <= budget
#   fail   dropped (no response inside 15s) · non-200 · a refusal · over budget
#   n/a    the door is not on this box (no local server, no listener config)
#   unrun  the door could not be TRIED (no key) — never read as a pass
# Exit 0 = every door pass or n/a · 1 = any fail · 3 = any unrun and no fail.
#
# LEDGER: one JSON line per door per run appended to .claude/.signal-watch.jsonl
# (gitignored). `--no-ledger` skips it. Speed is tracked, never remembered.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROD_URL="${SIGNAL_WATCH_PROD:-https://one.ie}"
LOCAL_URL="${SIGNAL_WATCH_LOCAL:-http://localhost:4321}"
STREAM_URL="${SIGNAL_WATCH_STREAM:-https://channels.one.ie/stream/space:vespio}"
LEDGER="${SIGNAL_WATCH_LEDGER:-$ROOT/.claude/.signal-watch.jsonl}"
CURL_MAX="${SIGNAL_WATCH_MAX:-15}"
BUDGET_SCALE="${SIGNAL_WATCH_BUDGET_SCALE:-1}"   # self-test shrinks budgets with this

LANES="prod local"; WATCH=0; JSON=0; LEDGER_ON=1
while [ $# -gt 0 ]; do
  case "$1" in
    --prod) LANES="prod" ;; --local) LANES="local" ;;
    --watch) WATCH="${2:-30}"; shift ;;
    --json) JSON=1 ;; --no-ledger) LEDGER_ON=0 ;;
    --self-test) SELF_TEST=1 ;;
    -h|--help) sed -n 2,45p "$0"; exit 0 ;;
    *) echo "signal-watch: unknown arg $1" >&2; exit 2 ;;
  esac; shift
done

PASS=0; FAIL=0; NA=0; UNRUN=0
_key() { # $1 = env file; the shell wins; the value is never printed
  local f="$1" v="${GATEWAY_API_KEY:-}"
  [ -n "$v" ] && { printf '%s' "$v"; return; }
  [ -f "$f" ] && grep -E '^GATEWAY_API_KEY=' "$f" | head -1 | cut -d= -f2- | tr -d '"'
}
_budget() { awk -v b="$1" -v s="$BUDGET_SCALE" 'BEGIN{printf "%d", b*s}'; }
_row() { # lane door verdict wall budget placement phases note
  if [ "$JSON" = 1 ]; then
    printf '{"ts":"%s","lane":"%s","door":"%s","verdict":"%s","wall_ms":%s,"budget_ms":%s,"placement":"%s","phases":"%s","note":"%s"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" "${4:-null}" "$5" "$6" "$7" "$8"
  else
    printf '  %-6s %-18s %-5s %7s ms  budget %5s  %-11s %-34s %s\n' "$1" "$2" "$3" "${4:--}" "$5" "${6:--}" "${7:--}" "$8"
  fi
  if [ "$LEDGER_ON" = 1 ]; then
    printf '{"ts":"%s","lane":"%s","door":"%s","verdict":"%s","wall_ms":%s,"budget_ms":%s,"placement":"%s","phases":"%s"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" "${4:-null}" "$5" "$6" "$7" >> "$LEDGER" 2>/dev/null || true
  fi
  case "$3" in pass) PASS=$((PASS+1));; fail) FAIL=$((FAIL+1));; n/a) NA=$((NA+1));; unrun) UNRUN=$((UNRUN+1));; esac
}

# door <lane> <name> <method> <url> <payload|-> <budget_ms> <key|-> [expect|-]
# `expect` is a fixed string the RESPONSE BODY must contain for the number to
# mean what the door claims to measure. Absent it, a door can keep answering 200
# fast while measuring something else entirely — which is exactly how the
# announce canary reported "the wire" while paying a full fan-out. A miss is
# UNRUN, never fail and never pass: the door ran, but not the door we named.
door() {
  local lane="$1" name="$2" method="$3" url="$4" payload="$5" budget key="$7" expect="${8:--}" hdr body out code wall placement phases verdict note=""
  budget=$(_budget "$6")
  hdr=$(mktemp); body=$(mktemp)
  if [ "$method" = POST ] && [ "$key" = "-" ]; then
    _row "$lane" "$name" unrun "" "$budget" "" "" "no GATEWAY_API_KEY — not tried"; rm -f "$hdr" "$body"; return
  fi
  # bash 3.2 + set -u: an EMPTY array expands as unbound. The ${a[@]+"${a[@]}"} idiom is the only portable form.
  local cfg=""; [ "$key" != "-" ] && { cfg=$(mktemp); chmod 600 "$cfg"; printf 'header = "Authorization: Bearer %s"\n' "$key" > "$cfg"; }
  local -a auth=(); [ -n "$cfg" ] && auth=(--config "$cfg")
  if [ "$method" = POST ]; then
    out=$(curl -s -D "$hdr" -o "$body" --max-time "$CURL_MAX" -X POST "$url" -H 'content-type: application/json' ${auth[@]+"${auth[@]}"} -d "$payload" -w '%{http_code} %{time_total}' 2>/dev/null)
  else
    out=$(curl -s -D "$hdr" -o "$body" --max-time "$CURL_MAX" "$url" ${auth[@]+"${auth[@]}"} -w '%{http_code} %{time_total}' 2>/dev/null)
  fi
  [ -n "$cfg" ] && rm -f "$cfg"
  code="${out%% *}"; wall=$(awk -v t="${out##* }" 'BEGIN{printf "%d", t*1000}')
  placement=$(grep -i '^cf-placement:' "$hdr" | head -1 | cut -d' ' -f2- | tr -d '\r')
  phases=$(grep -i '^server-timing:' "$hdr" | head -1 | grep -oE '(auth|data|det);dur=[0-9]+' | sed -E 's/;dur=/=/' | paste -sd' ' -)
  if [ "$code" = "000" ] || [ -z "$code" ]; then verdict=fail; note="DROPPED — no response inside ${CURL_MAX}s"
  elif [ "$code" != "200" ]; then verdict=fail; note="http $code $(head -c 80 "$body" | tr -d '\n')"
  elif [ "$method" = POST ] && ! grep -q '"outcome":"result"' "$body"; then verdict=fail; note="refused: $(head -c 100 "$body" | tr -d '\n')"
  elif [ "$method" = POST ] && grep -q '"ok":false' "$body"; then verdict=unrun; note="refused before the work: $(grep -oE '"error":"[^"]{0,80}' "$body" | head -1 | cut -d'"' -f4)"
  elif [ "$expect" != "-" ] && ! grep -qF "$expect" "$body"; then verdict=unrun; note="not the door we named: body lacks $expect — $(head -c 60 "$body" | tr -d '\n')"
  elif [ "$wall" -gt "$budget" ]; then verdict=fail; note="over budget by $((wall-budget)) ms"
  else verdict=pass; fi
  _row "$lane" "$name" "$verdict" "$wall" "$budget" "${placement:-}" "${phases:-}" "$note"
  rm -f "$hdr" "$body"
}

stream_door() {
  local budget cfg="$HOME/.cc-connect/.auth.conf" out code ttfb wall verdict note=""
  budget=$(_budget 600)
  [ -f "$cfg" ] || { _row prod stream n/a "" "$budget" "" "" "no ~/.cc-connect/.auth.conf on this box"; return; }
  out=$(curl -s -N -o /dev/null --max-time 4 --config "$cfg" "$STREAM_URL?since=$(date +%s)000" -w '%{http_code} %{time_starttransfer}' 2>/dev/null)
  code="${out%% *}"; ttfb=$(awk -v t="${out##* }" 'BEGIN{printf "%d", t*1000}')
  if [ "$code" != "200" ]; then verdict=fail; note="http ${code:-000}"
  elif [ "$ttfb" -gt "$budget" ]; then verdict=fail; note="first byte over budget"
  else verdict=pass; note="first byte"; fi
  _row prod stream "$verdict" "$ttfb" "$budget" "" "" "$note"
}

listeners() {
  command -v launchctl >/dev/null 2>&1 || { _row prod listeners n/a "" 0 "" "" "no launchctl"; return; }
  local alive; alive=$(launchctl list 2>/dev/null | awk '/ie\.one\.(cc-vespio|cc-oo|tg-listen)$/ && $1 ~ /^[0-9]+$/ {n++} END{print n+0}')
  if [ "$alive" -gt 0 ]; then _row prod listeners pass "" 0 "" "" "$alive listener(s) alive (cc-vespio · cc-oo · tg-listen)"
  else _row prod listeners fail "" 0 "" "" "no ie.one.* listener has a pid"; fi
}

lane() { # prod|local
  local l="$1" base key
  # The prod credential file honours ONE_ENV_FILE / DO_ENV_FILE, like every other
  # credential read in the harness (factory-repo.sh --check-env-indirection).
  # A relative path is taken from $ROOT; the shell's GATEWAY_API_KEY still wins.
  local env_file="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
  case "$env_file" in /*) ;; *) env_file="$ROOT/$env_file" ;; esac
  if [ "$l" = prod ]; then base="$PROD_URL"; key=$(_key "$env_file")
  else
    base="$LOCAL_URL"; key=$(_key "$ROOT/one.ie/web/.dev.vars")
    if ! curl -s -o /dev/null --max-time 3 "$base/api/health"; then
      _row local health n/a "" 0 "" "" "no dev server at $base"; return
    fi
  fi
  [ -z "$key" ] && key="-"
  # Budgets are a RATCHET: set at the measured p90 the day the door was first
  # watched (2026-09-05 — announce 1.3-1.8s, board/size 0.8-1.5s), lowered only
  # after a measured improvement ships. Never raised to make a red row green.
  # announce: 2000 → 800 after the parallel-read ship (2026-09-05, measured 149-379 ms).
  # UNCHANGED 2026-09-08 on purpose. The door it describes is now the WIRE door
  # (board=marketplace, matched=0), whose data phase measures 259-401 ms — the
  # same range 800 was set against. The wall it is compared to also carries the
  # CLIENT's egress, which is not the worker's: `health` does det=0 ms of server
  # work and has walked 134 → 72 → 437 → 463 ms across the ledger purely on where
  # the laptop was sitting. So a marginal announce/health miss can be this box's
  # network, not the door. Whether these budgets should be worker-phase budgets
  # rather than wall budgets is a RECALIBRATION — a human decision, deliberately
  # not taken here. A budget moved to fit an observation stops meaning anything.
  local b1 b2 b3; if [ "$l" = prod ]; then b1=400; b2=1500; b3=800; else b1=150; b2=300; b3=300; fi
  door "$l" health GET "$base/api/health" - "$b1" -
  # SIGNAL_WATCH_WIRE_OWN_BOARD=1 exists for --self-test case 4 ONLY: DROPPING
  # the board key sends the canary to the caller's own board, where `ceo` matches
  # every tag by canon — the durable red half of the assertion below. (Setting
  # `board` to an arbitrary slug does NOT work: the receiver's Zod schema rejects
  # it with a 400, which is a different failure and proves nothing.) Never set
  # this in a real run.
  local wire_board='"board":"marketplace",'
  if [ "${SIGNAL_WATCH_WIRE_OWN_BOARD:-0}" = 1 ]; then wire_board=''; fi
  door "$l" world:announce POST "$base/api/ask/world:announce" \
    "{\"data\":{\"tags\":[\"signal-watch-wire\"],${wire_board}\"type\":\"signal:canary\",\"text\":\"signal-watch $(date -u +%H:%M:%SZ)\",\"priority\":\"fyi\",\"slug\":\"one\"}}" "$b3" "$key" '"matched":0'
  door "$l" tasks:everywhere POST "$base/api/ask/tasks:everywhere" '{"data":{"workspace":"factory-do","limit":200}}' "$b2" "$key"
  door "$l" factory:size POST "$base/api/ask/factory:size" '{"data":{"paths":[".claude/scripts/signal-watch.sh"]}}' "$b2" "$key"
}

run_once() {
  PASS=0; FAIL=0; NA=0; UNRUN=0
  [ "$JSON" = 1 ] || { echo "signal-watch · $(date '+%Y-%m-%d %H:%M:%S') · prod=$PROD_URL local=$LOCAL_URL"; echo; }
  for l in $LANES; do lane "$l"; done
  case " $LANES " in *" prod "*) stream_door; listeners ;; esac
  [ "$JSON" = 1 ] || { echo; echo "SIGNAL-WATCH: pass=$PASS fail=$FAIL n/a=$NA unrun=$UNRUN$([ "$LEDGER_ON" = 1 ] && printf ' · ledger %s' "$LEDGER")"; }
  [ "$FAIL" -gt 0 ] && return 1; [ "$UNRUN" -gt 0 ] && return 3; return 0
}

if [ "${SELF_TEST:-0}" = 1 ]; then
  fails=0
  echo "== 1. a dropped door is a fail, and the exit says so"
  out=$(SIGNAL_WATCH_PROD=http://127.0.0.1:1 SIGNAL_WATCH_MAX=2 bash "$0" --prod --no-ledger 2>&1); rc=$?
  [ "$rc" -eq 1 ] && grep -q "DROPPED" <<<"$out" && echo "  ok   exit 1, DROPPED named" || { echo "  FAIL rc=$rc"; echo "$out" | tail -4; fails=$((fails+1)); }
  echo "== 2. a door over budget is a fail, never a slow pass"
  out=$(SIGNAL_WATCH_BUDGET_SCALE=0.0001 bash "$0" --prod --no-ledger 2>&1); rc=$?
  [ "$rc" -eq 1 ] && grep -q "over budget" <<<"$out" && echo "  ok   exit 1, over budget named" || { echo "  FAIL rc=$rc"; echo "$out" | tail -4; fails=$((fails+1)); }
  echo "== 3. no key is UNRUN (exit 3), not a pass — the door was never tried"
  # the .env key resolves on a configured box, so prove the branch from a stub root with no .env
  tmp=$(mktemp -d); mkdir -p "$tmp/.claude/scripts" "$tmp/one.ie/web"; cp "$0" "$tmp/.claude/scripts/"
  out=$(GATEWAY_API_KEY= SIGNAL_WATCH_BUDGET_SCALE=100 bash "$tmp/.claude/scripts/signal-watch.sh" --prod --no-ledger 2>&1); rc=$?
  [ "$rc" -eq 3 ] && grep -q "unrun" <<<"$out" && echo "  ok   exit 3, unrun rows" || { echo "  FAIL rc=$rc"; echo "$out" | tail -4; fails=$((fails+1)); }
  rm -rf "$tmp"
  echo "== 4. a wire probe that MATCHED somebody is unrun (exit 3), not a fast pass"
  # Red half: point the canary back at the caller's own board, where `ceo`
  # subscribes to every tag. The door still answers 200 with outcome=result —
  # only the assertion catches it.
  out=$(SIGNAL_WATCH_WIRE_OWN_BOARD=1 SIGNAL_WATCH_BUDGET_SCALE=100 bash "$0" --prod --no-ledger 2>&1); rc=$?
  [ "$rc" -eq 3 ] && grep -q 'not the door we named' <<<"$out" && echo "  ok   exit 3, fan-out named as not-the-wire" || { echo "  FAIL rc=$rc"; echo "$out" | tail -4; fails=$((fails+1)); }
  echo "signal-watch --self-test: $fails failed"
  exit "$fails"
fi

if [ "$WATCH" -gt 0 ] 2>/dev/null; then
  while :; do clear; run_once; sleep "$WATCH"; done
fi
run_once
