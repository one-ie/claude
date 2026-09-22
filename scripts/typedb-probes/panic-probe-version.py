#!/usr/bin/env python3
"""Run both confirmed server-killing query shapes against an arbitrary TypeDB.

Usage: panic-probe-version.py <url> <container-name>
Oracle is the container restart count, same as the 3.8.3 probes.
"""
import json, subprocess, sys, time, urllib.request, urllib.error

URL, CONTAINER = sys.argv[1], sys.argv[2]
DB = "panicver"


def restarts():
    return subprocess.run(["docker", "inspect", CONTAINER, "--format", "{{.RestartCount}}"],
                          capture_output=True, text=True).stdout.strip()


def alive():
    try:
        urllib.request.urlopen(urllib.request.Request(
            URL + "/v1/signin", method="POST", headers={"Content-Type": "application/json"}),
            json.dumps({"username": "admin", "password": "password"}).encode(), timeout=3)
        return True
    except urllib.error.HTTPError:
        return True          # answered => process alive
    except Exception:
        return False


def signin(tries=30):
    for _ in range(tries):
        try:
            req = urllib.request.Request(URL + "/v1/signin", method="POST",
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, json.dumps(
                    {"username": "admin", "password": "password"}).encode(), timeout=5) as r:
                return json.load(r)["token"]
        except Exception:
            time.sleep(1)
    return None


def send(tok, q, kind="write"):
    req = urllib.request.Request(URL + "/v1/query", method="POST", headers={
        "Content-Type": "application/json", "Authorization": "Bearer " + tok})
    body = json.dumps({"databaseName": DB, "transactionType": kind, "query": q},
                      ensure_ascii=False).encode("utf-8")
    try:
        with urllib.request.urlopen(req, body, timeout=30) as r:
            d = json.load(r)
            return f"200 ({len(d.get('answers') or [])} answers)"
    except urllib.error.HTTPError as e:
        return f"{e.code} {json.loads(e.read()).get('code','')}"
    except Exception as e:
        return f"DROPPED({type(e).__name__})"


tok = signin()
try:
    urllib.request.urlopen(urllib.request.Request(
        URL + f"/v1/databases/{DB}", method="POST",
        headers={"Authorization": "Bearer " + tok}), b"", timeout=15).read()
except Exception:
    pass
send(tok, """define
  attribute note, value string; attribute nid, value string;
  entity node, owns nid @key, owns note,
    plays containment:container, plays containment:contained;
  relation containment, relates container, relates contained;""", "schema")
send(tok, 'insert $a isa node, has nid "a"; $b isa node, has nid "b";', "write")
send(tok, 'match $a isa node, has nid "a"; $b isa node, has nid "b"; '
          'insert $r links (container: $a, contained: $b), isa containment;', "write")

PROBES = [
    ("control: ASCII insert",             'insert $x isa node, has nid "ctl1", has note "plain";', "write"),
    ("control: raw UTF-8 insert",         'insert $x isa node, has nid "ctl2", has note "café — ok";', "write"),
    ("KILLER 1: \\uXXXX in literal",      'insert $x isa node, has nid "u1", has note "caf\\u00e9";', "write"),
    ("KILLER 2: same var, two roles",     'match $r links (container: $x, contained: $x), isa containment; select $x;', "read"),
    ("recovery: ASCII read",              'match $x isa node, has nid $n; select $n;', "read"),
]

print(f"  {'probe':36} {'result':30} restarts  alive")
prev = restarts()
print(f"  {'(baseline)':36} {'-':30} {prev:8}  {alive()}")
for name, q, kind in PROBES:
    res = send(tok, q, kind)
    time.sleep(4)
    r, a = restarts(), alive()
    flag = "  <-- KILLED" if r != prev else ""
    print(f"  {name:36} {res:30} {r:8}  {a}{flag}")
    prev = r
    tok = signin() or tok
