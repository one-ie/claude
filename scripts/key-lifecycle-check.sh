#!/usr/bin/env bash
# key-lifecycle-check.sh — the deterministic verifier for text/key.md § Two lifecycles, one table.
#
# manifest: needs-env   (GATEWAY_API_KEY from the shell or one.ie/web/.dev.vars; ONE_ENV_FILE /
#                        DO_ENV_FILE override the file)
#
# One line per lifecycle step: <step> <name> <verdict> — <door> → <reading>. Four verdicts, never
# fewer:  pass · fail · unknown (the door errored — NOT a fail, NOT a pass) · n/a (no door exists,
# or the step is device-side by design). Same inputs → same output; no model anywhere in it.
#
#   key-lifecycle-check.sh --actor <uid|slug> [--workspace one] [--vault <file>] [--api https://one.ie]
#   key-lifecycle-check.sh --self-test        # proves the checker can go RED: a fixture actor with
#                                             # no wallet MUST read fail at step 4, or this exits 1
#
# Exit: 0 = no step failed · 1 = at least one fail · 2 = usage / env.  `unknown` never changes the
# exit code — say it, don't launder it.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENVF="${ONE_ENV_FILE:-${DO_ENV_FILE:-$ROOT/one.ie/web/.dev.vars}}"
API="https://one.ie"; WS="one"; ACTOR=""; VAULT=""; SELF=0
while [ $# -gt 0 ]; do case "$1" in
  --actor) ACTOR="$2"; shift 2;; --workspace) WS="$2"; shift 2;; --vault) VAULT="$2"; shift 2;;
  --api) API="$2"; shift 2;; --self-test) SELF=1; shift;; *) echo "unknown arg $1" >&2; exit 2;; esac; done
case "$API" in
  https://one.ie|http://localhost:*|http://127.0.0.1:*) ;;
  *) echo "--api must be https://one.ie or a localhost dev server — the gateway key is sent there" >&2; exit 2;;
esac
KEY="${GATEWAY_API_KEY:-$(grep -E '^GATEWAY_API_KEY=' "$ENVF" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"')}"
[ -n "$KEY" ] || { echo "no GATEWAY_API_KEY (env or $ENVF)" >&2; exit 2; }

ask() { # ask <receiver> <k=v>...  → body on stdout; "__ERR__ <detail>" on transport/HTTP failure.
  # The body is built by json.dumps from argv — an actor named `"},"x":` is a string, never structure.
  local recv="$1"; shift; local out code body
  body=$(python3 -c 'import json,sys; print(json.dumps({"data": dict(a.split("=",1) for a in sys.argv[1:])}))' "$@") || { echo "__ERR__ body"; return; }
  case "$recv" in *[!a-z:-]*) echo "__ERR__ bad receiver name"; return;; esac
  out=$(curl -s -m 25 -w '\n%{http_code}' -X POST "$API/api/ask/$recv" -H "Authorization: Bearer $KEY" -H "content-type: application/json" -d "$body") || { echo "__ERR__ transport"; return; }
  code="${out##*$'\n'}"; out="${out%$'\n'*}"
  [ "$code" = "200" ] || { echo "__ERR__ http $code $(printf '%s' "$out" | head -c 120)"; return; }
  printf '%s' "$out"
}
jq_() { # jq_ <python-expr-over-r>; the actor is available as ACTOR (env), never interpolated into code
  ACTOR="$ACTOR_FOR_JQ" python3 -c "import json,sys,os
actor=os.environ.get('ACTOR','')
try: d=json.load(sys.stdin)
except Exception: print(''); sys.exit()
r=d.get('result',d)
$1"; }

FAILS=0
line() { # line <step> <name> <verdict> <door> <reading>
  printf '%-4s %-16s %-8s — %s → %s\n' "$1" "$2" "$3" "$4" "$5"; [ "$3" = fail ] && FAILS=$((FAILS+1)); return 0; }

run() {
  local actor="$1"; ACTOR_FOR_JQ="$actor"
  line S1  mint     n/a  "(device-side)"  "by design: only step 4's address proves it"
  line S2  derive   n/a  "(device-side)"  "frozen-address test pins account 0"

  # S3 keep — agent: a vault file we can read; human: needs a session (the manager shows it)
  if [ -n "$VAULT" ]; then
    if [ -s "$VAULT" ] && python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d.get('v')==1 and d.get('kdf') and d.get('iv') and d.get('ct')" "$VAULT" 2>/dev/null; then
      line S3 keep pass "vault file $VAULT" "header v=1 kdf/iv/ct present (sealed; not opened)"
    else line S3 keep fail "vault file $VAULT" "missing or not a v1 vault header"; fi
  else line S3 keep n/a "/api/vault/devices (session) · --vault <file>" "no vault given; a human's seal is not readable through the gateway"; fi

  # S4 register — identity:address {uid}
  local r addr
  r=$(ask identity:address "uid=$actor")
  case "$r" in __ERR__*) line S4 register unknown "identity:address{uid}" "$r";; *)
    addr=$(printf '%s' "$r" | jq_ "print(r.get('address') or '')")
    if [ -n "$addr" ]; then line S4 register pass "identity:address{uid}" "$addr"; else line S4 register fail "identity:address{uid}" "no address for $actor"; fi;; esac
  line S4b authorise n/a "walk ⟷ ceiling owner (C10)" "not wired"
  line S4c verify    n/a "identity:proofs (C11)"       "not wired"
  line S5  show      "$( [ -n "${addr:-}" ] && echo pass || echo fail )" "same row as S4" "warning text is a unit test, not a probe"

  # S6/S8/S9 — wallet:get {workspace, actor}
  r=$(ask wallet:get "workspace=$WS" "actor=$actor")
  case "$r" in __ERR__*)
    line S6 money unknown "wallet:get" "$r"; line S8 credits unknown "wallet:get" "$r";; *)
    local bal cred
    bal=$(printf '%s' "$r" | jq_ "
bs=[b for b in (r.get('balances') or []) if b.get('actor')==actor]
v=[b for b in bs if b.get('balance') not in (None,'0','0.0','')]
print('nonzero=%d of %d chains' % (len(v),len(bs)) if bs else 'no balance rows for actor')")
    case "$bal" in nonzero=0*) line S6 money fail "wallet:get.balances[actor]" "$bal";; "no balance rows for actor") line S6 money fail "wallet:get.balances[actor]" "$bal";; *) line S6 money pass "wallet:get.balances" "$bal";; esac
    cred=$(printf '%s' "$r" | jq_ "print(r.get('credits') if r.get('credits') is not None else 'absent')")
    case "$cred" in absent) line S8 credits unknown "wallet:get.credits (WORKSPACE-level, not per actor)" "field absent";; 0|0.0) line S8 credits fail "wallet:get.credits (workspace)" "0";; *) line S8 credits pass "wallet:get.credits (WORKSPACE-level, not per actor)" "$cred";; esac;; esac
  line S7  funded?  n/a "inline condition (C9)" "derived from S6"
  line S9  use      n/a "credit_burns (no gateway read)" "not wired as a read door"
  line S10 stake    n/a "tasks:stake events (no read door)" "not wired"
  line S11 sweep    n/a "payout:set + settlement (Build the sweep)" "not wired"
  line S12 recover  n/a "(device-side)" "--vault re-open is the CLI's job (wallet open)"
}

if [ "$SELF" = 1 ]; then
  fx="no-such-actor-$RANDOM$RANDOM"
  echo "self-test: fixture actor $fx must read FAIL at S4"
  out=$(run "$fx"); echo "$out"
  if echo "$out" | grep -q '^S4  *register  *fail'; then echo "self-test: RED reachable — ok"; exit 0
  else echo "self-test: the checker did NOT go red on a missing actor — it is theatre"; exit 1; fi
fi
[ -n "$ACTOR" ] || { echo "usage: --actor <uid|slug> [--workspace one] [--vault <file>] | --self-test" >&2; exit 2; }
echo "key lifecycle · actor=$ACTOR · workspace=$WS · api=$API · $(date -u +%FT%TZ)"
run "$ACTOR"
echo "fails=$FAILS  (unknown never changes the exit code)"
[ "$FAILS" = 0 ]
