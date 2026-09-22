#!/usr/bin/env python3
"""do-killswitch-audit.py — sweep every plan's kill-switch, sort it, give the
loop real fuel. A kill-switch is only useful if it is hermetic, runnable, and
honestly red-or-done. This finds the ones that aren't.

Buckets:
  PROD     — outcome hits prod/network (curl one.ie, wrangler, deploy) → needs-human
  NONE     — no outcome: command → can't gate at all
  BROKEN   — command can't run: stale `cd` path, missing script, ENOENT → fix the gate
  GREEN    — passes NOW → work shipped; reconcile to DONE (tick boxes / log close)
  ARMED    — red because the feature is unbuilt → THE LOOP'S FUEL
  SLOW     — exceeded the run timeout → audit separately

Static pass (instant, no execution): PROD / NONE / BROKEN(stale-cd) / HERMETIC.
Dynamic pass (--run, bounded by --timeout): runs HERMETIC outcomes → GREEN/ARMED/BROKEN/SLOW.

Usage:
  do-killswitch-audit.py                 static only — instant, sorts every plan
  do-killswitch-audit.py --run           also run hermetic outcomes (slow, real)
  do-killswitch-audit.py --run --ready   only audit do-rank's READY set (the loop's candidates)
  do-killswitch-audit.py --json [...]    machine output
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXT = ROOT / "text"
RANK = ROOT / ".claude" / "scripts" / "do-rank.py"

# Network/prod markers. NOT bare `one.ie` — that's the `one.ie/web` LOCAL DIR, not
# the host. Match real network refs: curl/wget, any URL, a SUBDOMAIN.one.ie
# (api./pay./channels.one.ie), or deploy tooling.
PROD = re.compile(r"\bcurl\b|\bwget\b|https?://|[a-z0-9-]+\.one\.ie|wrangler|deploy|--remote", re.I)
BROKEN_OUT = re.compile(
    r"not found|no such file|cannot find|command not found|ENOENT|"
    r"cannot find module|is not a function|unknown command",
    re.I,
)
EXCLUDE = {"template", "todo"}


def parse_outcome(text):
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    body = m.group(1) if m else text
    # block form: outcome: |  (indented lines follow). Strip a TRAILING backslash
    # per line (shell line-continuation) before joining — else `test -f x \` +
    # join makes `test -f x \ && …` which the shell mis-parses. Internal `\|`
    # (grep alternation) is preserved (rstrip only the line end).
    bm = re.search(r"^outcome:\s*\|\s*\n((?:[ \t]+.*\n?)+)", body, re.MULTILINE)
    if bm:
        lines = [re.sub(r"\\$", "", l.strip()) for l in bm.group(1).splitlines() if l.strip()]
        return " ".join(lines).strip()
    # inline form: outcome: "..."  or  outcome: ...
    # A double-quoted YAML scalar must be unescaped (\" → ", \\ → \) and may
    # carry a trailing comment after the closing quote — match the quoted
    # string properly first, else the escapes leak into the shell verbatim
    # and grep hunts for quote characters that were never in the file.
    qm = re.search(r'^outcome:\s*"((?:[^"\\]|\\.)*)"', body, re.MULTILINE)
    if qm:
        return re.sub(r'\\(.)', r'\1', qm.group(1)).strip()
    # single-quoted YAML scalar: '' is the only escape (a literal ')
    sm = re.search(r"^outcome:\s*'((?:[^']|'')*)'", body, re.MULTILINE)
    if sm:
        return sm.group(1).replace("''", "'").strip()
    im = re.search(r'^outcome:\s*(.+?)\s*$', body, re.MULTILINE)
    return im.group(1).strip() if im else ""


def stale_cd(cmd):
    """Walk the &&/; chain tracking cwd — `cd a && cd ../b` makes ../b relative
    to a, not to root. A `(cd x && …)` subshell inherits the outer cwd but its
    cd does NOT leak past the closing paren (outcomes are commonly chains of
    subshells: `(cd web && test) && (cd channels && test)`). Parens inside
    quotes (grep patterns) can unbalance the stack; that degrades to the outer
    cwd, never a crash. Return the first cd target that doesn't exist, else None."""
    cwd = ROOT
    stack = []
    for seg in re.split(r"&&|;|\|", cmd):
        for _ in range(seg.count("(")):
            stack.append(cwd)
        m = re.search(r"\bcd\s+([^\s&|;)]+)", seg)
        if m:
            t = m.group(1)
            nxt = Path(t) if t.startswith("/") else (cwd / t)
            try:
                nxt = nxt.resolve()
            except Exception:
                return t
            if not nxt.exists():
                return t
            cwd = nxt
        for _ in range(seg.count(")")):
            cwd = stack.pop() if stack else ROOT
    return None


def classify_static(outcome):
    if not outcome:
        return "NONE", "no kill-switch — can't gate"
    if PROD.search(outcome):
        return "PROD", "hits prod/network → needs-human"
    bad = stale_cd(outcome)
    if bad:
        return "BROKEN", f"stale path: cd {bad}"
    return "HERMETIC", "local — runnable"


def run_outcome(outcome, timeout):
    # shell=True is REQUIRED and contained here: kill-switches are compound shell
    # commands (`cd x && bun test | jq …`) that cannot be arg-lists, and running
    # them is this tool's entire purpose. Containment: (1) source is the repo's
    # own trusted text/*-todo.md, not external input; (2) only outcomes already
    # classified HERMETIC reach this — PROD/network (curl/deploy/wrangler) are
    # filtered out by classify_static BEFORE any execution; (3) bounded timeout.
    try:
        r = subprocess.run(outcome, shell=True, cwd=str(ROOT),  # noqa: S602
                           capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "SLOW", f"exceeded {timeout}s"
    except Exception as e:
        return "BROKEN", f"spawn error: {e}"
    if r.returncode == 0:
        return "GREEN", "passes now → reconcile to DONE"
    blob = (r.stderr or "") + (r.stdout or "")
    if BROKEN_OUT.search(blob):
        first = next((l for l in blob.splitlines() if BROKEN_OUT.search(l)), "")
        return "BROKEN", f"errored: {first.strip()[:60]}"
    return "ARMED", "red — unbuilt → FUEL"


def main():
    args = sys.argv[1:]
    do_run = "--run" in args
    as_json = "--json" in args
    ready_only = "--ready" in args
    timeout = 90
    if "--timeout" in args:
        timeout = int(args[args.index("--timeout") + 1])

    slugs = None
    if ready_only:
        try:
            out = subprocess.run([sys.executable, str(RANK), "--top", "200"],
                                capture_output=True, text=True, cwd=str(ROOT))
            slugs = set(out.stdout.split())
        except Exception:
            slugs = None

    rows = []
    for f in sorted(TEXT.glob("*-todo.md")):
        slug = f.name[: -len("-todo.md")]
        if slug in EXCLUDE:
            continue
        if slugs is not None and slug not in slugs:
            continue
        outcome = parse_outcome(f.read_text(errors="ignore"))
        bucket, why = classify_static(outcome)
        if do_run and bucket == "HERMETIC":
            bucket, why = run_outcome(outcome, timeout)
        rows.append({"slug": slug, "bucket": bucket, "why": why,
                     "outcome": outcome[:70]})

    order = ["ARMED", "GREEN", "BROKEN", "PROD", "SLOW", "HERMETIC", "NONE"]
    rows.sort(key=lambda r: (order.index(r["bucket"]) if r["bucket"] in order else 9, r["slug"]))

    if as_json:
        buckets = {}
        for r in rows:
            buckets.setdefault(r["bucket"], []).append(r["slug"])
        print(json.dumps({"buckets": buckets, "rows": rows}, indent=2))
        return

    counts = {}
    for r in rows:
        counts[r["bucket"]] = counts.get(r["bucket"], 0) + 1
    mode = "DYNAMIC (ran outcomes)" if do_run else "STATIC (no execution)"
    scope = "READY set only" if ready_only else "all plans"
    print(f"\n  KILL-SWITCH AUDIT — {mode} · {scope}")
    print("  " + " · ".join(f"{k}:{counts.get(k,0)}" for k in order if counts.get(k)))
    print()
    for r in rows:
        tag = {"ARMED": "🔥", "GREEN": "✓", "BROKEN": "✗", "PROD": "⤫",
               "SLOW": "⏱", "HERMETIC": "·", "NONE": "∅"}.get(r["bucket"], " ")
        print(f"  {tag} {r['bucket']:9} {r['slug']:26} {r['why']}")
    if not do_run:
        print(f"\n  → re-run with --run to resolve HERMETIC into GREEN/ARMED/BROKEN")
    else:
        print(f"\n  🔥 ARMED = the loop's fuel. ✓ GREEN = reconcile to DONE. ✗ BROKEN = fix the gate.")
    print()


if __name__ == "__main__":
    main()
