#!/usr/bin/env bash
# factory-rate.sh — THE NUMBER: closes per hour off the board, and whether each
# close carries a receipt.
#
# manifest: needs-env   (GATEWAY_API_KEY from one.ie/web/.dev.vars or the shell;
#                        ONE_ENV_FILE / DO_ENV_FILE override the file)
#
# WHY THIS IS A SCRIPT AND NOT A jq IN A PLAN (text/do-factory-plan.md § 7 C1).
# This rung is the do-factory plan's KILL SWITCH. If the rate is at or below the
# before-number, the plan is falsified and Phase D does not run: the second engine
# was not the cost. A kill switch that lives as a shell one-liner in a document is
# one nobody runs and nobody can drive red.
#
#   factory-rate.sh --workspace one --since <iso> [--width N] [--floor F] [--json]
#   factory-rate.sh --self-test
#
# THE WINDOW IS `--since` -> THE LAST `closedAt`, NOT first-close -> last-close.
# That definition is what makes a ONE-RUNG round evaluable: with one close, first
# equals last and a first-to-last window is zero, so the only honest denominator
# is the time from when the round STARTED. A round start is a fact the caller
# knows and the board does not, which is why --since is required and never guessed.
#
# THE FOUR-STATE HONESTY LAW (inherited from do-w4-gates.sh / factory-walk.sh).
# A number that could not be computed is UNRUN, never zero. An empty board does
# not report "0.00 closes/hour" and exit 0 — that is the fail-open shape this whole
# plan exists to remove. Exit codes:
#
#   0  pass    — rate STRICTLY above the floor, and every close carries a receipt
#   1  fail    — rate at or below the floor (`>` not `>=`: landing exactly on the
#                before-number is not an improvement)
#   3  unrun   — the board could not be read, or the window is not positive.
#                Distinct from 1 on purpose: "we did not measure" must never be
#                filed as "we measured and it was bad", or vice versa.
#   4  norcpt  — the rate cleared the floor but closes are missing Lane:/Verdict:/
#                Commit: in their notes. A caller-reported total is not a receipt.
#   2  usage
#
# SELF-TEST INJECTION. --self-test never touches the network: FACTORY_RATE_ROWS
# names a JSON file in the receiver's response shape, and the fixtures drive every
# verdict INCLUDING the reds. A checker that has only ever been seen green has not
# been shown to work.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

WORKSPACE=""; SINCE=""; WIDTH=""; FLOOR=""; JSON=false; SELFTEST=false; TAG=""
API="${ONE_API_URL:-https://one.ie}"

usage() { sed -n '2,45p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --workspace) WORKSPACE="${2:-}"; shift 2 ;;
    --since)     SINCE="${2:-}"; shift 2 ;;
    --width)     WIDTH="${2:-}"; shift 2 ;;
    --floor)     FLOOR="${2:-}"; shift 2 ;;
    --tag)       TAG="${2:-}"; shift 2 ;;
    --api)       API="${2:-}"; shift 2 ;;
    --json)      JSON=true; shift ;;
    --self-test) SELFTEST=true; shift ;;
    -h|--help)   usage ;;
    *) echo "factory-rate: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ── the board read ──────────────────────────────────────────────────────────
# One tasks:everywhere {closed:true} call. Read-only by its own docblock
# (subscriptions.ts:1049) and it returns closedAt per row (:1632). limit 200
# matches the plan; the response carries `truncated`, which we REPORT rather
# than swallow — a floor computed over a truncated page is a floor, not a rate.
fetch_rows() {
  if [ -n "${FACTORY_RATE_ROWS:-}" ]; then cat "$FACTORY_RATE_ROWS"; return $?; fi
  local envf key authcfg rc=0 resp
  envf="${ONE_ENV_FILE:-${DO_ENV_FILE:-$ROOT/one.ie/web/.dev.vars}}"
  key="${GATEWAY_API_KEY:-$(grep -E '^GATEWAY_API_KEY=' "$envf" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"')}"
  authcfg="$(mktemp)"; chmod 600 "$authcfg"
  [ -n "$key" ] && printf 'header = "Authorization: Bearer %s"\n' "$key" > "$authcfg"
  resp=$(curl -sS --max-time 25 -X POST "$API/api/ask/tasks:everywhere" \
    -H 'Content-Type: application/json' --config "$authcfg" \
    -d "{\"data\":{\"workspace\":\"$WORKSPACE\",\"closed\":true,\"limit\":200}}" 2>/dev/null) || rc=$?
  rm -f "$authcfg"
  [ "$rc" -eq 0 ] || return 1
  printf '%s' "$resp"
}

# The analyser is written to a file, NOT piped as a heredoc: `python3 - <<PY` makes
# the HEREDOC the process's stdin, so a `sys.stdin.read()` inside it returns "" and
# every fixture reads as an empty board. That bug shipped in the first draft of this
# file and --self-test caught it, 5 of 8 red -- which is the whole argument for the
# fixtures existing.
PYSRC="$(mktemp -t factory-rate-XXXXXX.py)"
trap 'rm -f "$PYSRC"' EXIT
cat > "$PYSRC" <<'PY'
import json, sys, datetime as dt

rows_path, since_s, width_s, floor_s, as_json = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] == 'true')
# tasks:everywhere's response declares no `workspace` (receivers.ts:1235-1262),
# so the receipt names the one that was ASKED for rather than printing blank.
ws_asked = sys.argv[6] if len(sys.argv) > 6 else ''
# --tag NARROWS THE POPULATION, and it is not optional decoration. tasks:everywhere
# {closed:true} returns every closed row in the workspace -- 1826 rows spanning clean,
# pages, marketing, security. A rate over all of them is not the rate of a build loop,
# and comparing it to a before-number measured on ONE plan's burst is a category error.
# Unset means all-workspace, and the receipt SAYS so rather than implying a round.
tag = sys.argv[7] if len(sys.argv) > 7 else ''

def iso(s):
    if not s: return None
    s = s.strip().replace('Z', '+00:00')
    # The board hands back both "2026-09-21T08:56:19.412Z" and a bare
    # "2026-09-19T15:32:45.000000000" (nanoseconds, no zone) -- seen on real rows.
    # Trim sub-microsecond digits fromisoformat cannot take, and treat a missing
    # zone as UTC rather than as local, so the window never moves with $TZ.
    if '.' in s:
        head, _, tail = s.partition('.')
        digits = ''.join(c for c in tail if c.isdigit())[:6]
        rest = tail[len(''.join(c for c in tail if c.isdigit())):]
        s = f"{head}.{digits}{rest}" if digits else head + rest
    try: d = dt.datetime.fromisoformat(s)
    except ValueError: return None
    return d.replace(tzinfo=dt.timezone.utc) if d.tzinfo is None else d

def out(code, verdict, **kw):
    body = dict(verdict=verdict, **kw)
    if as_json:
        print(json.dumps(body, indent=2, default=str))
    else:
        print(f"factory-rate: {verdict.upper()}")
        for k, v in body.items():
            if k != 'verdict':
                print(f"  {k:<16} {v}")
    sys.exit(code)

raw = (sys.stdin.read() if rows_path == '-' else open(rows_path).read()).strip()
if not raw:
    out(3, 'unrun', reason='the board returned nothing -- not measured, NOT zero')
try: env = json.loads(raw)
except Exception as e:
    out(3, 'unrun', reason=f'board response is not JSON: {e}')

# the ask envelope nests under `result`; a non-`result` outcome is UNRUN, not 0
if isinstance(env, dict) and 'outcome' in env and env.get('outcome') != 'result':
    out(3, 'unrun', reason=f"ask outcome {env.get('outcome')!r} -- the door did not answer")
res = env.get('result', env) if isinstance(env, dict) else {}

# A RESOLVER ERROR ARRIVES UNDER outcome:"result". Measured 2026-09-21:
#   {"outcome":"result","result":{"error":"D1_ERROR: Currently processing a
#    long-running export.","forbidden":false}}
# -- HTTP 200, envelope says `result`, and there is no `tasks` key at all. Read
# only `tasks` and that is an EMPTY BOARD: the script then blamed --since ("no
# closes at or after ...") for an outage it never detected. An error and an empty
# round are both unrun, but they are not the same unrun, and a number is worth
# nothing if the instrument cannot say which one it hit. Absent is not false;
# read every key of `result` before claiming the door said nothing.
if isinstance(res, dict) and res.get('error'):
    out(3, 'unrun', reason=f"the door answered an error under outcome:result -- {res['error']}",
        forbidden=res.get('forbidden'), hint='transient D1/gateway state: retry before reading anything into this')
if isinstance(res, dict) and 'tasks' not in res:
    out(3, 'unrun', reason="the response carries no `tasks` key at all -- that is a door fault, not an empty board",
        result_keys=sorted(res.keys()))

rows = res.get('tasks') or []
truncated = bool(res.get('truncated'))

since = iso(since_s)
if since is None:
    out(2, 'usage', reason='--since <iso> is required; the round start is a fact the board does not hold')

# Rows whose closedAt is inside the window. A row with no parseable closedAt is
# COUNTED AS UNPARSEABLE and named -- never silently dropped, which would deflate
# the denominator's numerator and read as a worse rate than reality.
inwin, unparseable = [], 0
for r in rows:
    c = iso(r.get('closedAt') or '')
    if c is None:
        if r.get('closedAt'): unparseable += 1
        continue
    if c < since: continue
    if tag and tag not in (r.get('tags') or []): continue
    inwin.append((c, r))

if not inwin:
    out(3, 'unrun', reason=('no closes at or after --since'
                            + (f' carrying tag {tag!r}' if tag else '')
                            + ' -- an empty round is not a rate of zero'),
        rows_read=len(rows), since=since_s, unparseable=unparseable, truncated=truncated)

inwin.sort(key=lambda t: t[0])
last = inwin[-1][0]
hours = (last - since).total_seconds() / 3600.0
if hours <= 0:
    out(3, 'unrun', reason=f'window is not positive ({hours:.4f}h) -- --since is at or after the last close',
        since=since_s, last_close=last.isoformat(), closes=len(inwin))

closes = len(inwin)
rate = closes / hours

# The second clause of C1's acceptance: a close is a RECEIPT only if its notes
# carry Lane:, Verdict: ok and Commit:. A caller-reported total is not a receipt.
missing = []
for c, r in inwin:
    n = r.get('notes') or ''
    lacks = [k for k, ok in (('Lane:', 'Lane:' in n),
                             ('Verdict: ok', 'Verdict: ok' in n),
                             ('Commit:', 'Commit:' in n)) if not ok]
    if lacks: missing.append({'id': r.get('id'), 'lacks': lacks})

common = dict(workspace=res.get('workspace') or ws_asked,
              population=(f'tag:{tag}' if tag else 'ALL closed rows in the workspace '
                          '-- NOT a build loop; a before-number measured on one plan is not comparable'),
              since=since_s,
              last_close=last.isoformat(), window_hours=round(hours, 4),
              closes=closes, rate_per_hour=round(rate, 4),
              width=width_s or 'unset',
              rate_per_hour_per_width=(round(rate / float(width_s), 4)
                                       if width_s and float(width_s) > 0 else 'n/a'),
              receipts_complete=closes - len(missing), receipts_missing=len(missing),
              unparseable_closed_at=unparseable,
              truncated=truncated)
if truncated:
    common['truncated_note'] = 'more closed rows exist than were read: this rate is a FLOOR, not a count'

if floor_s:
    floor = float(floor_s)
    common['floor'] = floor
    # `>` not `>=`: landing EXACTLY on the before-number is not an improvement.
    if rate <= floor:
        out(1, 'fail', reason=f'{rate:.4f} closes/hour is at or below the floor {floor}', **common)

if missing:
    out(4, 'norcpt', reason='closes without a receipt (need Lane:, Verdict: ok, Commit: in notes)',
        missing_rows=missing[:10], **common)

out(0, 'pass', **common)
PY

compute() {  # compute <rows-file|-> <since> <width> <floor> <json>
  python3 "$PYSRC" "$@"
}

# ── self-test ───────────────────────────────────────────────────────────────
# Every fixture drives a verdict, and four of the six drive a RED. A checker that
# has only been seen green has not been shown to work.
if $SELFTEST; then
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
  fails=0
  ok()  { printf '  ok    %s\n' "$1"; }
  bad() { printf '  BAD   %s\n' "$1"; fails=$((fails+1)); }
  rcpt='Lane: fast\\nVerdict: ok\\nCommit: abc1234'

  mk() { # mk <file> <json>
    printf '%s' "$2" > "$T/$1"
  }
  run() { # run <expect-rc> <label> <fixture> [args...]
    local want="$1" label="$2" fix="$3"; shift 3
    local got=0 outp
    outp=$(compute "$T/$fix" "$@" 2>&1) || got=$?
    if [ "$got" -eq "$want" ]; then ok "$label (exit $got)"
    else bad "$label — wanted exit $want, got $got"; printf '%s\n' "$outp" | sed 's/^/        /' | head -6; fi
  }

  # 1 — a ONE-ROW round is evaluable. since 10:00, close 10:30 => 0.5h, 2.0/hr.
  mk one.json "{\"outcome\":\"result\",\"result\":{\"ok\":true,\"workspace\":\"one\",\"tasks\":[
    {\"id\":\"task:1\",\"closedAt\":\"2026-09-21T10:30:00Z\",\"notes\":\"$rcpt\"}]}}"
  run 0 "one-row round is evaluable (first-to-last would be a zero window)" one.json 2026-09-21T10:00:00Z 1 1.5 false

  # 2 — a multi-row round. since 10:00, last close 12:00 => 2h, 4 closes, 2.0/hr.
  mk many.json "{\"outcome\":\"result\",\"result\":{\"ok\":true,\"workspace\":\"one\",\"tasks\":[
    {\"id\":\"task:1\",\"tags\":[\"factory\"],\"closedAt\":\"2026-09-21T10:15:00Z\",\"notes\":\"$rcpt\"},
    {\"id\":\"task:2\",\"tags\":[\"factory\"],\"closedAt\":\"2026-09-21T11:00:00Z\",\"notes\":\"$rcpt\"},
    {\"id\":\"task:3\",\"tags\":[\"factory\"],\"closedAt\":\"2026-09-21T11:30:00Z\",\"notes\":\"$rcpt\"},
    {\"id\":\"task:4\",\"tags\":[\"factory\"],\"closedAt\":\"2026-09-21T12:00:00Z\",\"notes\":\"$rcpt\"}]}}"
  run 0 "multi-row round clears a floor it beats" many.json 2026-09-21T10:00:00Z 1 1.5 false

  # 3 — RED: the rate lands EXACTLY on the floor. 2.0 vs floor 2.0 must FAIL.
  run 1 "exactly on the floor is a FAIL (> not >=)" many.json 2026-09-21T10:00:00Z 1 2.0 false

  # 4 — RED: an empty board is UNRUN (3), never 0.00/hour reported as a pass.
  mk empty.json '{"outcome":"result","result":{"ok":true,"workspace":"one","tasks":[]}}'
  run 3 "empty board is UNRUN, never a rate of zero" empty.json 2026-09-21T10:00:00Z 1 2.44 false

  # 5 — RED: closes with no receipt do not pass, even when the rate clears.
  mk norcpt.json '{"outcome":"result","result":{"ok":true,"workspace":"one","tasks":[
    {"id":"task:9","closedAt":"2026-09-21T10:30:00Z","notes":"closed it"}]}}'
  run 4 "a close without Lane:/Verdict:/Commit: is not a receipt" norcpt.json 2026-09-21T10:00:00Z 1 1.5 false

  # 6 — RED: --since after the last close is UNRUN, not a divide-by-zero pass.
  run 3 "a non-positive window is UNRUN" one.json 2026-09-21T23:00:00Z 1 1.5 false

  # 7 — RED: a door that did not answer is UNRUN, distinct from a bad number.
  mk dissolved.json '{"outcome":"dissolved","receiver":"tasks:everywhere"}'
  run 3 "a dissolved ask is UNRUN, not zero" dissolved.json 2026-09-21T10:00:00Z 1 2.44 false

  # 8 — a truncated page still answers, and SAYS it is a floor.
  mk trunc.json "{\"outcome\":\"result\",\"result\":{\"ok\":true,\"workspace\":\"one\",\"truncated\":true,\"tasks\":[
    {\"id\":\"task:1\",\"closedAt\":\"2026-09-21T10:30:00Z\",\"notes\":\"$rcpt\"}]}}"
  o=$(compute "$T/trunc.json" 2026-09-21T10:00:00Z 1 1.5 true 2>&1) || true
  case "$o" in *'is a FLOOR, not a count'*) ok "a truncated page reports itself as a floor" ;;
    *) bad "truncated page did not say it was a floor"; printf '%s\n' "$o" | sed 's/^/        /' | head -4 ;; esac

  # 9 — RED: --tag narrows, and a tag nothing carries is UNRUN, not a rate over
  #     the rows it was supposed to exclude. Without this the filter could be a no-op.
  run 3 "a tag no row carries is UNRUN, never the unfiltered rate" many.json 2026-09-21T10:00:00Z 1 1.5 false one engineering
  run 0 "a tag every row carries leaves the rate intact" many.json 2026-09-21T10:00:00Z 1 1.5 false one factory

  # 11 — RED: a resolver error under outcome:"result" is UNRUN and names the ERROR,
  #      never "no closes in the window". This is the real shape, measured 2026-09-21.
  mk d1err.json '{"outcome":"result","result":{"error":"D1_ERROR: Currently processing a long-running export.","forbidden":false}}'
  run 3 "an error under outcome:result is UNRUN" d1err.json 2026-09-21T10:00:00Z 1 2.44 false
  o=$(compute "$T/d1err.json" 2026-09-21T10:00:00Z 1 2.44 true 2>&1) || true
  case "$o" in *D1_ERROR*) ok "and the receipt names the door's own error" ;;
    *) bad "the D1 error was swallowed"; printf '%s\n' "$o" | sed 's/^/        /' | head -4 ;; esac

  # 12 — RED: a result with no `tasks` key at all is a door fault, not a board of zero.
  mk nokey.json '{"outcome":"result","result":{"ok":true}}'
  run 3 "a result with no tasks key is a door fault" nokey.json 2026-09-21T10:00:00Z 1 2.44 false

  echo
  if [ "$fails" -eq 0 ]; then echo "factory-rate --self-test: 13/13 ok"; exit 0; fi
  echo "factory-rate --self-test: $fails failing"; exit 1
fi

# ── live ────────────────────────────────────────────────────────────────────
[ -n "$WORKSPACE" ] || { echo "factory-rate: --workspace is required" >&2; exit 2; }
[ -n "$SINCE" ]     || { echo "factory-rate: --since <round-start-iso> is required — see the header" >&2; exit 2; }

BOARDF="$(mktemp -t factory-rate-board-XXXXXX.json)"
fetch_rows > "$BOARDF" || { echo "factory-rate: UNRUN — the board read failed (not a rate of zero)" >&2; rm -f "$BOARDF"; exit 3; }
compute "$BOARDF" "$SINCE" "$WIDTH" "$FLOOR" "$JSON" "$WORKSPACE" "$TAG"; rc=$?
rm -f "$BOARDF"; exit $rc
