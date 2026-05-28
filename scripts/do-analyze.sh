#!/usr/bin/env bash
# do-analyze.sh — ANALYZE coverage gate (ex-Spec-Kit /analyze), read-only. Run at the
# todo→code boundary, BEFORE build spends worktree tokens. Builds the D#↔C# coverage matrix
# and the AC→test check. CRITICAL (uncovered deliverable) → exit 1, blocks build. Never edits.
# Usage:  do-analyze.sh <todo.md>
set -euo pipefail
todo="${1:?usage: do-analyze.sh <todo.md>}"
[ -f "$todo" ] || { echo "CRITICAL: todo not found: $todo"; exit 1; }

crit=0; high=0

# 1. coverage: every deliverable line (- D#) must cite at least one cycle (C#)
uncovered=0
while IFS= read -r line; do
  did=$(printf '%s' "$line" | grep -oE 'D[0-9]+' | head -1)
  if ! printf '%s' "$line" | grep -qE 'C[0-9]+'; then
    echo "CRITICAL: $did maps to no cycle"; crit=1; uncovered=$((uncovered+1))
  fi
done < <(grep -E '^[[:space:]]*- D[0-9]+ ' "$todo")

ndel=$(grep -cE '^[[:space:]]*- D[0-9]+ ' "$todo" || true)
ncyc=$(grep -cE '^## C[0-9]+ ' "$todo" || true)

# 2. orphan cycles: every ## C# section should be cited by some deliverable
cited=$(grep -oE 'C[0-9]+' "$todo" | sort -u)
for c in $(grep -oE '^## C[0-9]+ ' "$todo" | grep -oE 'C[0-9]+'); do
  # a cycle is cited if it appears outside its own header (i.e. in a deliverable line)
  hits=$(grep -E "^[[:space:]]*- D[0-9]+ .*\b$c\b" "$todo" | wc -l | tr -d ' ')
  [ "$hits" -eq 0 ] && { echo "HIGH: cycle $c has no deliverable (orphan)"; high=$((high+1)); }
done

# 3. AC→test: every cycle section should carry a demo: line (DoD row 2, planned half)
nodemo=0
for c in $(grep -oE '^## C[0-9]+ ' "$todo" | grep -oE 'C[0-9]+'); do
  block=$(awk "/^## $c /{f=1} f&&/^## C[0-9]+ /&&!/^## $c /{if(seen)exit} {if(f)print; if(/^## $c /)seen=1}" "$todo")
  printf '%s' "$block" | grep -qiE 'demo:' || { echo "HIGH: $c has no planned test (demo: line)"; high=$((high+1)); nodemo=$((nodemo+1)); }
done

echo "----"
echo "coverage: $ndel deliverables / $ncyc cycles · uncovered=$uncovered · no-demo=$nodemo · high=$high"
if [ "$crit" -ne 0 ]; then echo "ANALYZE: CRITICAL — fix coverage before build"; exit 1; fi
echo "ANALYZE: pass (coverage 100%)"; exit 0
