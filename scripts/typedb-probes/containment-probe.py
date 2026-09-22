#!/usr/bin/env python3
"""Settles the doc's UNCONFIRMED claim:

    "Do NOT run `match (container: $x, contained: $x) isa containment;` — the
     same variable in two roles. It appeared to kill the cluster outright
     rather than return empty."

Same oracle as the unicode panic probe: docker restart count before/after.
Runs against a scratch db with a containment relation defined and a couple of
real (non-self) edges, so an empty result is a meaningful empty.
"""
import json, subprocess, sys, time, urllib.request, urllib.error

URL = "http://127.0.0.1:8000"
DB = "selfrole"


def restarts():
    return subprocess.run(["docker", "inspect", "typedb", "--format", "{{.RestartCount}}"],
                          capture_output=True, text=True).stdout.strip()


def signin(tries=25):
    for _ in range(tries):
        try:
            req = urllib.request.Request(URL + "/v1/signin", method="POST",
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, json.dumps(
                    {"username": "admin", "password": "password"}).encode(), timeout=5) as r:
                return json.load(r)["token"]
        except Exception:
            time.sleep(1)
    sys.exit("could not sign in")


def send(tok, q, kind="read"):
    req = urllib.request.Request(URL + "/v1/query", method="POST", headers={
        "Content-Type": "application/json", "Authorization": "Bearer " + tok})
    body = json.dumps({"databaseName": DB, "transactionType": kind, "query": q},
                      ensure_ascii=False).encode("utf-8")
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, body, timeout=60) as r:
            d = json.load(r)
            n = len(d.get("answers") or [])
            return f"200 ({n} answers)", time.time() - t0
    except urllib.error.HTTPError as e:
        return f"{e.code} {e.read()[:60].decode('utf-8','replace')}", time.time() - t0
    except Exception as e:
        return f"DROPPED({type(e).__name__})", time.time() - t0


tok = signin()
try:
    urllib.request.urlopen(urllib.request.Request(
        URL + f"/v1/databases/{DB}", method="POST",
        headers={"Authorization": "Bearer " + tok}), b"", timeout=15).read()
except Exception:
    pass

send(tok, """define
  attribute nid, value string;
  entity node, owns nid @key, plays containment:container, plays containment:contained;
  relation containment, relates container, relates contained;""", "schema")
send(tok, 'insert $a isa node, has nid "a"; $b isa node, has nid "b"; $c isa node, has nid "c";', "write")
send(tok, 'match $a isa node, has nid "a"; $b isa node, has nid "b"; '
          'insert $r links (container: $a, contained: $b), isa containment;', "write")
send(tok, 'match $b isa node, has nid "b"; $c isa node, has nid "c"; '
          'insert $r links (container: $b, contained: $c), isa containment;', "write")

PROBES = [
    ("sanity: normal containment read", 'match $r links (container: $x, contained: $y), isa containment; select $x, $y;'),
    ("THE SUSPECT: same var in two roles", 'match $r links (container: $x, contained: $x), isa containment; select $x;'),
    ("legacy paren syntax, same var",      'match ($x, $x) isa containment; select $x;'),
    ("recovery: normal read again",        'match $r links (container: $x, contained: $y), isa containment; select $x, $y;'),
]

print(f"  {'probe':40} {'result':30} {'secs':>6}  restarts")
prev = restarts()
print(f"  {'(baseline)':40} {'-':30} {'-':>6}  {prev}")
for name, q in PROBES:
    res, secs = send(tok, q)
    time.sleep(4)
    r = restarts()
    flag = "  <-- SERVER KILLED" if r != prev else ""
    print(f"  {name:40} {res:30} {secs:6.2f}  {r}{flag}")
    prev = r
    tok = signin()
