#!/usr/bin/env bash
# factory-turn.sh — drive ONE turn of the factory, locally, from the DOCUMENT.
#
# manifest: needs-env
#   Reads GATEWAY_API_KEY through the ONE_ENV_FILE ladder (DO_ENV_FILE alias) and
#   talks to the receivers over HTTPS. With --replay it needs neither and runs
#   from a fixture, which is how tests/unit/factory/factory-turn.test.ts proves it.
#
# WHAT IT IS. R8 of text/factory-do.md: `one.ie/ai/workflows/factory-turn.tql`
# is the turn — the six funs asked, one handler each, and a close that refuses
# an empty board dressed as a finished one. This script is that document's LOCAL
# DRIVER and NOT a second definition of it: it parses the .tql, walks the steps
# in edge order with the executor's own semantics (condition grammar, `each` +
# `limit` + `concurrency`, pruned branches, a human step that parks), and
# dispatches every `receiver` over the one door — POST /api/ask/<receiver>, the
# payload wrapped in "data", `workspace` on every call because a rung elaborated
# with slug X lives in workspace X (measured 2026-09-04). Change the turn by
# editing the document; this file has nothing to say about WHICH funs or WHICH
# handlers.
#
# The one thing it adds is a verdict the document's grammar cannot express: a
# turn that reached `ran` with N ready rows and launched NONE of them is RED here
# (a condition step cannot count ok:true receipts inside an each result).
#
#   bash .claude/scripts/factory-turn.sh --plan objective:<slug>:1 [--workspace <slug>]
#   bash .claude/scripts/factory-turn.sh --plan ... --dry-run     reads live, writes nothing
#   bash .claude/scripts/factory-turn.sh --plan ... --replay f.json [--log calls.jsonl]
#   bash .claude/scripts/factory-turn.sh --self-test
#
# Exit codes — the verdict, and nothing else on stdout's last line:
#   0  the close was a MARK      (ran · settled)
#   1  the close was a WARN      (blind · stalled · halted), or ran-but-launched-nothing
#   2  PARKED at a human step    (deadlocked — a person, now)
#   3  CANNOT RUN                (no key, no plan, unreadable document, a step failed)
# 1 vs 3 is load-bearing (same as factory-check.sh): red sends someone to the
# board, cannot-run sends them to the environment. Never widen a 3 into a 1.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/one.ie/ai/workflows/factory-turn.tql"

# Credentials: the same ladder do-signal.sh walks. ONE_ENV_FILE is the whole
# story in a generated factory clone; the monorepo fallbacks are extras.
ONE_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-$ROOT/one.ie/web/.env}}"
if [ -z "${GATEWAY_API_KEY:-}" ]; then
  for _f in "$ONE_ENV_FILE" "$ROOT/.env" "$ROOT/one.ie/.env"; do
    [ -f "$_f" ] || continue
    _v=$(grep -E '^GATEWAY_API_KEY=' "$_f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//' || true)
    if [ -n "$_v" ]; then GATEWAY_API_KEY="$_v"; break; fi
  done
fi
export GATEWAY_API_KEY="${GATEWAY_API_KEY:-}"
export ONE_API_URL="${ONE_API_URL:-https://one.ie}"
export FACTORY_TURN_DOC="$DOC"

if [ "${1:-}" = "--self-test" ]; then
  # The replay fixtures the unit test drives, run here so a bare shell can see
  # the four verdicts without vitest. Each line is <expected exit> <fixture>.
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  fails=0
  mk() { printf '%s' "$2" >"$tmp/$1.json"; }
  fun() { printf '{"ok":true,"fn":"%s","rows":%s}' "$1" "$2"; }
  ROWS1='[{"r0":"0x1"}]'; ROWS0='[]'
  mk ran      "{\"fn:run\":{\"incomplete\":$(fun incomplete '[{"r0":"0x1"},{"r0":"0x2"}]'),\"ready-tasks\":$(fun ready-tasks "$ROWS1"),\"unrealised\":$(fun unrealised "$ROWS0"),\"uncovered\":$(fun uncovered "$ROWS0"),\"covered-unproven\":$(fun covered-unproven "$ROWS1"),\"deadlocked\":$(fun deadlocked "$ROWS0")},\"tasks:list\":{\"ok\":true,\"tasks\":[{\"tid\":\"task:t1\",\"status\":\"open\"}]},\"tasks:launch\":{\"ok\":true,\"results\":[{\"tid\":\"task:t1\",\"ok\":true}]},\"world:outcome\":{\"ok\":true}}"
  mk stalled  "{\"fn:run\":{\"incomplete\":$(fun incomplete '[{"r0":"0x9"}]'),\"ready-tasks\":$(fun ready-tasks "$ROWS0"),\"unrealised\":$(fun unrealised "$ROWS1"),\"uncovered\":$(fun uncovered "$ROWS0"),\"covered-unproven\":$(fun covered-unproven "$ROWS0"),\"deadlocked\":$(fun deadlocked "$ROWS0")},\"tasks:list\":{\"ok\":true,\"tasks\":[]},\"world:outcome\":{\"ok\":true}}"
  mk settled  "{\"fn:run\":{\"incomplete\":$(fun incomplete "$ROWS0"),\"ready-tasks\":$(fun ready-tasks "$ROWS0"),\"unrealised\":$(fun unrealised "$ROWS0"),\"uncovered\":$(fun uncovered "$ROWS0"),\"covered-unproven\":$(fun covered-unproven "$ROWS0"),\"deadlocked\":$(fun deadlocked "$ROWS0")},\"tasks:list\":{\"ok\":true,\"tasks\":[]},\"world:outcome\":{\"ok\":true}}"
  mk blind    "{\"fn:run\":{\"incomplete\":{\"ok\":false,\"fn\":\"incomplete\",\"rows\":[],\"error\":\"substrate_unavailable (status 503)\"},\"ready-tasks\":$(fun ready-tasks "$ROWS0"),\"unrealised\":$(fun unrealised "$ROWS0"),\"uncovered\":$(fun uncovered "$ROWS0"),\"covered-unproven\":$(fun covered-unproven "$ROWS0"),\"deadlocked\":$(fun deadlocked "$ROWS0")},\"tasks:list\":{\"ok\":true,\"tasks\":[]},\"world:outcome\":{\"ok\":true}}"
  mk parked   "{\"fn:run\":{\"incomplete\":$(fun incomplete "$ROWS1"),\"ready-tasks\":$(fun ready-tasks "$ROWS0"),\"unrealised\":$(fun unrealised "$ROWS0"),\"uncovered\":$(fun uncovered "$ROWS0"),\"covered-unproven\":$(fun covered-unproven "$ROWS0"),\"deadlocked\":$(fun deadlocked "$ROWS1")},\"tasks:list\":{\"ok\":true,\"tasks\":[]},\"world:outcome\":{\"ok\":true}}"
  for case in "0 ran" "1 stalled" "0 settled" "1 blind" "2 parked"; do
    want="${case%% *}"; name="${case##* }"
    out=$(bash "$0" --plan objective:self-test:1 --workspace self-test --replay "$tmp/$name.json" 2>&1); rc=$?
    last=$(printf '%s\n' "$out" | tail -1)
    if [ "$rc" -eq "$want" ] && [[ "$last" == *"$name"* ]]; then
      echo "ok   $name → exit $rc · $last"
    else
      echo "FAIL $name → wanted exit $want with '$name' on the last line, got exit $rc · $last"; fails=$((fails+1))
    fi
  done
  [ "$fails" -eq 0 ] && { echo "factory-turn --self-test: 5/5"; exit 0; }
  echo "factory-turn --self-test: $fails FAIL"; exit 1
fi

exec python3 - "$@" <<'PY'
import json, os, re, sys, urllib.request, urllib.error

DOC = os.environ["FACTORY_TURN_DOC"]
API = os.environ.get("ONE_API_URL", "https://one.ie").rstrip("/")
KEY = os.environ.get("GATEWAY_API_KEY", "")

# ── args ─────────────────────────────────────────────────────────────────────
opts = {"plan": "", "workspace": "", "replay": "", "log": "", "dry": False}
a = sys.argv[1:]
i = 0
while i < len(a):
    k = a[i]
    if k == "--plan": opts["plan"] = a[i + 1]; i += 2
    elif k == "--workspace": opts["workspace"] = a[i + 1]; i += 2
    elif k == "--replay": opts["replay"] = a[i + 1]; i += 2
    elif k == "--log": opts["log"] = a[i + 1]; i += 2
    elif k == "--dry-run": opts["dry"] = True; i += 1
    else: print(f"CANNOT RUN: unknown arg {k}", file=sys.stderr); sys.exit(3)

def cannot(msg):
    print(f"factory-turn: CANNOT RUN — {msg}")
    sys.exit(3)

m = re.match(r"^objective:([a-z0-9-]+):\d+$", opts["plan"])
if not m: cannot("--plan must be an objective tid (objective:<slug>:<n>)")
slug = m.group(1)
ws = opts["workspace"] or slug
if not opts["replay"] and not KEY: cannot("no GATEWAY_API_KEY resolved (ONE_ENV_FILE ladder) — use --replay for an offline run")

# ── the document, parsed the way the executor reads it ───────────────────────
try:
    src = open(DOC, encoding="utf-8").read()
except OSError as e:
    cannot(f"document unreadable: {e}")

def unq(s):  # a TQL double-quoted literal → its text (same escapes as workflow-tql.ts)
    return s.replace('\\"', '"').replace("\\\\", "\\")

steps, order, var2tid = {}, [], {}
# A statement ends at the first `;` OUTSIDE a quoted literal — an intent string
# may carry one (step:promise does), and a non-greedy `.*?;` stopped inside it.
STMT = r'((?:[^;"]|"(?:[^"\\]|\\.)*")*);'
for mm in re.finditer(r'(\$s\d+) isa thing,' + STMT, src, re.S):
    var, body = mm.group(1), mm.group(2)
    tid = re.search(r'has tid "step:([^"]+)"', body)
    kind = re.search(r'has step-kind "([^"]+)"', body)
    cfg = re.search(r'has step-config "((?:[^"\\]|\\.)*)"', body)
    if not (tid and kind and cfg): cannot(f"step {var} is missing tid/kind/config")
    try:
        config = json.loads(unq(cfg.group(1)))
    except json.JSONDecodeError as e:
        cannot(f"step:{tid.group(1)} step-config is not JSON: {e}")
    steps[tid.group(1)] = {"id": tid.group(1), "kind": kind.group(1), "config": config}
    order.append(tid.group(1)); var2tid[var] = tid.group(1)

edges = []
for mm in re.finditer(r'\$e\d+ isa path, links \(source: (\$s\d+), target: (\$s\d+)\)' + STMT, src, re.S):
    cond = re.search(r'has edge-condition "([^"]*)"', mm.group(3))
    edges.append({"source": var2tid[mm.group(1)], "target": var2tid[mm.group(2)], "condition": cond.group(1) if cond else ""})
if not steps or not edges: cannot("document has no steps or no edges")

# ── dispatch: replay · dry · live ─────────────────────────────────────────────
replay = json.load(open(opts["replay"])) if opts["replay"] else None
calls = []
READS = {"fn:run", "tasks:list"}

def dispatch(receiver, data):
    payload = dict(data); payload["workspace"] = ws
    calls.append({"receiver": receiver, "data": payload})
    if replay is not None:
        canned = replay.get(receiver)
        if receiver == "fn:run" and isinstance(canned, dict): canned = canned.get(payload.get("fn"))
        if isinstance(canned, list): canned = canned.pop(0) if canned else None
        if canned is None: return {"ok": False, "error": f"replay has no answer for {receiver}"}
        return canned
    if opts["dry"] and receiver not in READS:
        print(f"dry    {receiver} {json.dumps(payload)[:160]}")
        return {"ok": True, "dry": True}
    # A named User-Agent: the edge refuses urllib's default with a 403 while the same
    # key by curl gets 200 (measured 2026-09-04) — that 403 was the door, not the key.
    req = urllib.request.Request(f"{API}/api/ask/{receiver}", data=json.dumps({"data": payload}).encode(),
                                 headers={"Authorization": f"Bearer {KEY}", "content-type": "application/json", "User-Agent": "factory-turn.sh (curl-shaped; ONE factory R8)"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            body = json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        try: body = json.loads(e.read().decode() or "{}")
        except Exception: return {"ok": False, "error": f"http {e.code}"}
    except Exception as e:
        return {"ok": False, "error": f"unreachable: {e}"}
    # The door answers an ENVELOPE — {"outcome":"result","result":{...},"signalId",...}
    # — exactly what a workflow step's dispatch sees. Unwrap it the same way:
    # `result` is the receiver's answer; any other outcome (dissolved, failure) is
    # a refusal the receiver never saw, reported as such rather than as its answer.
    if isinstance(body, dict) and "outcome" in body:
        if body.get("outcome") in ("result", "success"): return body.get("result") if isinstance(body.get("result"), dict) else {"ok": True, "result": body.get("result")}
        return {"ok": False, "error": f"outcome {body.get('outcome')}: {body.get('error') or body.get('reason') or ''}".strip()}
    return body

# ── substitution + guard grammar, mirroring workflow-executor.ts ─────────────
# `tag` is carried WHOLE: a string arg substitutes only in whole, so the document
# reads $trigger.tag rather than composing "slug:$trigger.slug" (which ships the
# literal — the first live dry-run proved it with an honest zero from tasks:list).
trigger = {"plan": opts["plan"], "slug": slug, "tag": f"slug:{slug}", "workspace": ws}
results = {}

def sub(v, item=None):
    if isinstance(v, dict): return {k: sub(x, item) for k, x in v.items()}
    if isinstance(v, list): return [sub(x, item) for x in v]
    if not isinstance(v, str) or not v.startswith("$"): return v
    if v.startswith("$trigger."): return trigger.get(v[9:], v)
    if v.startswith("$step."):
        rest = v[6:]; sid, _, field = rest.partition(".")
        if sid not in results: return v
        r = results[sid]
        if not field: return r
        return r.get(field, v) if isinstance(r, dict) else v
    if v == "$item": return item if item is not None else v
    if v.startswith("$item."): return item.get(v[6:], v) if isinstance(item, dict) else v
    return v

def getpath(obj, path):
    for p in path.split("."):
        if isinstance(obj, dict): obj = obj.get(p)
        elif isinstance(obj, list) and p == "length": obj = len(obj)
        else: return None
    return obj

def resolve_ref(ref):
    if ref.startswith("$trigger."): return getpath(trigger, ref[9:])
    if ref.startswith("$step."):
        sid, _, field = ref[6:].partition(".")
        return getpath(results.get(sid), field) if field else results.get(sid)
    return getpath(trigger, ref)

def evaluate(expr):
    mm = re.match(r"^(\S+)\s*(===|!==|>=|<=|>|<|includes)\s*(.+)$", expr.strip())
    if not mm: return None
    lhs = resolve_ref(mm.group(1)); raw = mm.group(3).strip().strip("'\"")
    rhs = True if raw == "true" else False if raw == "false" else None if raw == "null" else float(raw) if re.match(r"^-?\d+(\.\d+)?$", raw) else raw
    op = mm.group(2)
    try:
        if op == "===": return lhs == rhs and type(lhs) == type(rhs) if isinstance(rhs, bool) or isinstance(lhs, bool) else lhs == rhs
        if op == "!==": return lhs != rhs
        if op == ">": return float(lhs) > float(rhs)
        if op == "<": return float(lhs) < float(rhs)
        if op == ">=": return float(lhs) >= float(rhs)
        if op == "<=": return float(lhs) <= float(rhs)
        if op == "includes": return rhs in lhs
    except (TypeError, ValueError):
        return False
    return None

# ── the walk ─────────────────────────────────────────────────────────────────
done, failed, pruned, decision = set(), set(), set(), {}
incoming = {sid: [e for e in edges if e["target"] == sid] for sid in steps}
closes, dark, parked = [], [], None

def active(e):
    return e["source"] in done and (e["condition"] == "" or decision.get(e["source"]) == e["condition"])

progress = True
while progress:
    progress = False
    for sid in order:
        if sid in done or sid in failed or sid in pruned: continue
        ins = incoming[sid]
        if any(e["source"] in failed for e in ins): failed.add(sid); progress = True; continue
        if any(e["source"] not in done and e["source"] not in pruned for e in ins): continue
        if ins and not any(active(e) for e in ins): pruned.add(sid); progress = True; continue
        st = steps[sid]; cfg = st["config"]; kind = st["kind"]
        if kind == "trigger":
            results[sid] = trigger
        elif kind == "condition":
            v = evaluate(cfg.get("expr", ""))
            if v is None: failed.add(sid); print(f"failed step:{sid} — unparseable guard {cfg.get('expr')!r}"); progress = True; continue
            decision[sid] = "true" if v else "false"
            print(f"guard  step:{sid} {cfg.get('expr')} → {decision[sid]}")
        elif kind == "human":
            parked = sid
            print(f"park   step:{sid} — {cfg.get('question', 'a person, now')}")
            break
        elif kind == "tool":
            receiver = cfg.get("receiver"); args = cfg.get("args", {})
            if not receiver:
                dark.append(sid)
                print(f"dark   step:{sid} — {cfg.get('blocked', 'no receiver')}")
                results[sid] = None
            elif isinstance(cfg.get("each"), str):
                items = sub(cfg["each"]); limit = cfg.get("limit")
                if not isinstance(items, list) or not isinstance(limit, int) or len(items) > limit:
                    failed.add(sid); print(f"failed step:{sid} — each_limit (items={type(items).__name__}, limit={limit})"); progress = True; continue
                out = [dispatch(receiver, sub(args, it)) for it in items]
                results[sid] = out
                for it, r in zip(items, out):
                    rec = (r.get("results") or [{}])[0] if isinstance(r, dict) and isinstance(r.get("results"), list) else (r if isinstance(r, dict) else {})
                    print(f"action {receiver} {it.get('tid') if isinstance(it, dict) else it} → {'ok' if rec.get('ok') else rec.get('reason') or rec.get('error') or r.get('error') if isinstance(r, dict) else '?'}")
                if not items: print(f"action {receiver} — 0 items")
            else:
                r = dispatch(receiver, sub(args))
                results[sid] = r
                if receiver == "world:outcome": closes.append((sid, bool(args.get("success"))))
                elif receiver == "fn:run": print(f"fun    {args.get('fn')}: {'ok' if r.get('ok') else 'FAILED ' + str(r.get('error'))} · {len(r.get('rows') or [])} row(s)")
                else: print(f"call   {receiver} → {'ok' if r.get('ok') else r.get('error')}")
        else:
            failed.add(sid); print(f"failed step:{sid} — kind {kind} is not driven locally"); progress = True; continue
        done.add(sid); progress = True
    if parked: break

if opts["log"]:
    with open(opts["log"], "w") as f:
        for c in calls: f.write(json.dumps(c) + "\n")

# ── the verdict ──────────────────────────────────────────────────────────────
counts = {k: len((results.get(k) or {}).get("rows") or []) if isinstance(results.get(k), dict) else "?" for k in ("ready", "unrealised", "uncovered", "unproven", "deadlocked", "incomplete")}
print("turn:  plan=%s ws=%s ready=%s unrealised=%s uncovered=%s unproven=%s deadlocked=%s incomplete=%s · dark=%s" % (
    opts["plan"], ws, counts["ready"], counts["unrealised"], counts["uncovered"], counts["unproven"], counts["deadlocked"], counts["incomplete"], ",".join(dark) or "-"))

if parked:
    print(f"factory-turn: ESCALATE parked at step:{parked} — deadlocked={counts['deadlocked']}, a person, now")
    sys.exit(2)
if failed:
    print(f"factory-turn: CANNOT RUN — step(s) failed: {', '.join(sorted(failed))}")
    sys.exit(3)
if not closes:
    print("factory-turn: CANNOT RUN — the walk reached no close (document shape)")
    sys.exit(3)
close, marked = closes[-1]
if close == "ran":
    launched = sum(1 for r in (results.get("execute") or []) if isinstance(r, dict) for rec in (r.get("results") or []) if rec.get("ok"))
    ready = counts["ready"]
    if launched == 0 and not opts["dry"]:
        print(f"factory-turn: RED ran but launched 0 of {ready} ready — every launch was refused; read the receipts above")
        sys.exit(1)
    print(f"factory-turn: OK ran — launched {launched} of {ready} ready{' (dry-run: nothing written)' if opts['dry'] else ''}")
    sys.exit(0)
if marked:
    print(f"factory-turn: OK {close} — ready and incomplete both empty; the plan is established")
    sys.exit(0)
why = {"blind": "the substrate did not answer", "stalled": f"empty stream with incomplete={counts['incomplete']} — nothing to run, work remains", "halted": "a person halted the plan"}.get(close, close)
print(f"factory-turn: RED {close} — {why}")
sys.exit(1)
PY
