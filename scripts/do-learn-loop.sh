#!/usr/bin/env bash
# do-learn-loop.sh — self-improving loop
# Runs rubric across all packages, reads learnings, synthesises gap todos, fleets.
# Called by the scheduled trigger every 2 hours.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "[learn-loop] $(date -u +%Y-%m-%dT%H:%M:%SZ) — starting self-improve pass"

# 1. Baseline rubric
echo "[learn-loop] running rubric across all packages..."
python3 .claude/scripts/do-rubric.py --all 2>&1 | tee /tmp/rubric-snapshot.txt

# 2. Extract failing axes (score < 0.80)
echo "[learn-loop] extracting gaps..."
python3 - <<'EOF'
import re, sys

with open('/tmp/rubric-snapshot.txt') as f:
    text = f.read()

# find lines like:  security        ████░░ 0.35  ×0.20
gaps = []
pkg = None
for line in text.splitlines():
    if 'CODE RUBRIC —' in line:
        pkg = line.split('—')[1].strip().split()[0]
    m = re.match(r'\s+(security|stability|simplicity|speed)\s+.*?(\d+\.\d+)\s+×', line)
    if m and pkg:
        axis, score = m.group(1), float(m.group(2))
        if score < 0.80:
            gaps.append((pkg, axis, score))

if gaps:
    print(f"[learn-loop] gaps found: {len(gaps)}")
    for pkg, axis, score in sorted(gaps, key=lambda x: x[2]):
        print(f"  {pkg} / {axis}: {score:.2f}")
else:
    print("[learn-loop] all axes ≥ 0.80 — no new gap todos needed")
EOF

# 3. Fleet any armed todos not yet in the queue
echo "[learn-loop] running fleet..."
bash .claude/scripts/do-fleet.sh --max 8 --go 2>&1 | tail -20

# 4. Append to learnings
echo "- $(date -u +%Y-%m-%d) · learn-loop · auto-pass · rubric swept + fleet run · source=loop" >> text/learnings.md

echo "[learn-loop] done."
