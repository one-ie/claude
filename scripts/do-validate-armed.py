#!/usr/bin/env python3
"""do-validate-armed.py — the deeper pass. For each ARMED∩ready plan, run its
kill-switch and READ the failure to tell real fuel from a broken gate:

  GENUINE-ARMED — the test runner RAN and tests failed (or the deliverable file
                  is plainly absent) → the loop can build this.
  BROKEN-GATE   — the runner couldn't start (no vitest, missing module, no test
                  files, stale import) → fix the gate, don't build.
  NOW-GREEN     — exits 0 on re-run (flaky/state) → reconcile to done.
  UNCLEAR       — needs a human eye; evidence printed.

Reads ARMED from /tmp/ksaudit.json, READY from do-rank. Bounded per-plan timeout.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXT = ROOT / "text"
RANK = ROOT / ".claude" / "scripts" / "do-rank.py"
AUDIT = Path("/tmp/ksaudit.json")
TIMEOUT = 50

# the runner actually executed tests (⇒ failures are real ⇒ armed)
RAN = re.compile(r"\d+\s+(pass|fail)|Tests?\s+\d|expect\(|✓|✗|FAIL |PASS |"
                 r"\bAssertionError\b|toBe|toEqual|\d+\s+passing|\d+\s+failing", re.I)
# the gate couldn't even start (⇒ broken)
BROKE = re.compile(r"not found|no such file|cannot find module|script not found|"
                   r"no test (files? )?found|cannot find package|error: cannot find|"
                   r"unknown command|is not a function|command not found|"
                   r"failed to (load|resolve)|ERR_MODULE", re.I)


def parse_outcome(text):
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    body = m.group(1) if m else text
    bm = re.search(r"^outcome:\s*\|\s*\n((?:[ \t]+.*\n?)+)", body, re.MULTILINE)
    if bm:
        # strip trailing line-continuation backslash before joining (keep \| escapes)
        lines = [re.sub(r"\\$", "", l.strip()) for l in bm.group(1).splitlines() if l.strip()]
        return " ".join(lines).strip()
    im = re.search(r'^outcome:\s*"?(.+?)"?\s*$', body, re.MULTILINE)
    return im.group(1).strip() if im else ""


def main():
    armed = set(json.load(open(AUDIT))["buckets"].get("ARMED", []))
    rank = json.loads(subprocess.run([sys.executable, str(RANK), "--json"],
                                     capture_output=True, text=True, cwd=str(ROOT)).stdout)
    ready = {p["slug"]: p for p in rank["ready"]}
    cands = sorted([s for s in armed if s in ready], key=lambda s: -ready[s]["score"])

    results = []
    for slug in cands:
        outcome = parse_outcome((TEXT / f"{slug}-todo.md").read_text(errors="ignore"))
        try:
            # shell=True contained: ARMED is hermetic-by-construction (the audit
            # only reaches ARMED by running a hermetic outcome; prod/network is
            # filtered upstream), source is trusted in-repo, timeout-bounded.
            r = subprocess.run(outcome, shell=True, cwd=str(ROOT),  # noqa: S602
                               capture_output=True, text=True, timeout=TIMEOUT)
            blob = (r.stdout or "") + (r.stderr or "")
            if r.returncode == 0:
                verdict, ev = "NOW-GREEN", "exits 0 on re-run"
            elif RAN.search(blob) and not BROKE.search(blob.split("\n")[0]):
                verdict = "GENUINE-ARMED"
                m = re.search(r"(\d+\s+fail\w*|\d+\s+failing|FAIL[^\n]{0,50})", blob, re.I)
                ev = (m.group(1) if m else "tests ran and failed").strip()
            elif BROKE.search(blob):
                verdict = "BROKEN-GATE"
                m = BROKE.search(blob)
                line = next((l for l in blob.splitlines() if BROKE.search(l)), "")
                ev = line.strip()[:70]
            else:
                verdict, ev = "UNCLEAR", (blob.strip().splitlines()[-1][:70] if blob.strip() else "no output")
        except subprocess.TimeoutExpired:
            verdict, ev = "SLOW", f">{TIMEOUT}s"
        except Exception as e:
            verdict, ev = "ERROR", str(e)[:60]
        results.append({"slug": slug, "score": ready[slug]["score"],
                        "priority": ready[slug]["priority"], "verdict": verdict, "evidence": ev})
        print(f"  {verdict:14} {slug:24} score={results[-1]['score']:>3}  {ev}", flush=True)

    json.dump(results, open("/tmp/armed_validated.json", "w"), indent=2)
    fuel = [r["slug"] for r in results if r["verdict"] == "GENUINE-ARMED"]
    print(f"\n  REAL FUEL ({len(fuel)}): {', '.join(fuel) or 'none'}")
    print(f"  broken gates: {', '.join(r['slug'] for r in results if r['verdict']=='BROKEN-GATE') or 'none'}")


if __name__ == "__main__":
    main()
