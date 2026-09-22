#!/usr/bin/env python3
"""Minimal reproducer: a \\uXXXX escape inside a TypeQL string literal PANICS
TypeDB 3.8.3 and kills the server process.

Each probe sends one write query and then reads the container's restart count.
A rising restart count means that query killed the server, not that it errored.

Usage: panic-probe.py [url]
"""
import json, subprocess, sys, time, urllib.request, urllib.error

URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000"
DB = "paniclab"


def restarts():
    return subprocess.run(["docker", "inspect", "typedb", "--format", "{{.RestartCount}}"],
                          capture_output=True, text=True).stdout.strip()


def signin(tries=20):
    for _ in range(tries):
        try:
            req = urllib.request.Request(URL + "/v1/signin", method="POST")
            req.add_header("Content-Type", "application/json")
            body = json.dumps({"username": "admin", "password": "password"}).encode()
            with urllib.request.urlopen(req, body, timeout=5) as r:
                return json.load(r)["token"]
        except Exception:
            time.sleep(1)
    sys.exit("could not sign in")


def send(tok, q, kind="write"):
    req = urllib.request.Request(URL + "/v1/query", method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", "Bearer " + tok)
    # ensure_ascii=False: the ESCAPE UNDER TEST must reach TypeQL as written,
    # not be double-escaped by the JSON envelope.
    body = json.dumps({"databaseName": DB, "transactionType": kind, "query": q},
                      ensure_ascii=False).encode("utf-8")
    try:
        with urllib.request.urlopen(req, body, timeout=15) as r:
            return str(r.status)
    except urllib.error.HTTPError as e:
        return str(e.code)
    except Exception as e:
        return f"DROPPED({type(e).__name__})"


tok = signin()
# fresh scratch db
urllib.request.urlopen(urllib.request.Request(
    URL + f"/v1/databases/{DB}", method="POST",
    headers={"Authorization": "Bearer " + tok}), b"", timeout=15).read() if True else None
send(tok, "define attribute note, value string; entity probe, owns note;", "schema")

PROBES = [
    ("ASCII literal",                  'insert $x isa probe, has note "plain ascii";'),
    ("raw UTF-8 (e-acute, em-dash)",   'insert $x isa probe, has note "café — ok";'),
    ("escaped quote",                  'insert $x isa probe, has note "she said \\"hi\\"";'),
    ("\\uXXXX escape (e-acute)",       'insert $x isa probe, has note "caf\\u00e9";'),
    ("\\uXXXX escape (control char)",  'insert $x isa probe, has note "bell\\u0007here";'),
    ("ASCII again (did it recover?)",  'insert $x isa probe, has note "still alive";'),
]

print(f"  {'probe':38} {'http':16} restarts")
before = restarts()
print(f"  {'(baseline)':38} {'-':16} {before}")
for name, q in PROBES:
    code = send(tok, q)
    time.sleep(4)          # let docker restart-policy settle before reading the count
    r = restarts()
    killed = " <-- SERVER KILLED" if r != before else ""
    print(f"  {name:38} {code:16} {r}{killed}")
    before = r
    tok = signin()          # token dies with the process
