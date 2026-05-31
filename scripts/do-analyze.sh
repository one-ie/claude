#!/usr/bin/env bash
# do-analyze.sh — ANALYZE coverage gate (ex-Spec-Kit /analyze), read-only. Run at the
# todo→code boundary, BEFORE build spends worktree tokens. Verifies the plan against the
# current template-todo.md contract: a `deliverables:` frontmatter block, and per-cycle
# `**Deliverable:**` + (`demo:` | `**Cycle outcome:**`) lines.
#
# CRITICAL (exit 1, blocks build):
#   - deliverables: frontmatter is empty            → plan ships nothing
#   - a ## C# cycle has no **Deliverable:** line     → cycle ships nothing (coverage hole)
# HIGH (warn, does not block):
#   - a cycle has no demo:/Cycle outcome line        → AC→test gap (no planned verification)
# Never edits.
# Usage:  do-analyze.sh <todo.md>
set -euo pipefail
todo="${1:?usage: do-analyze.sh <todo.md>}"
[ -f "$todo" ] || { echo "CRITICAL: todo not found: $todo"; exit 1; }

crit=0; high=0

# 1. plan ships something: deliverables: frontmatter has >=1 real entry (- kind: ...)
ndel=$(awk '
  /^deliverables:/ {f=1; next}
  f && /^[a-z_]+:/ {f=0}
  f && /^[[:space:]]*-[[:space:]]/ {n++}
  END {print n+0}
' "$todo")
if [ "$ndel" -eq 0 ]; then
  echo "CRITICAL: deliverables: frontmatter is empty — plan ships nothing"; crit=1
fi

# 2. every cycle ships a deliverable AND has a planned test. Walk each ## C# section
#    (header to the next ## header — ### W-waves and **bold** lines stay inside).
ncyc=0; nodeliv=0; notest=0
for c in $(grep -oE '^## C[0-9]+' "$todo" | grep -oE 'C[0-9]+'); do
  ncyc=$((ncyc+1))
  block=$(awk -v c="$c" '
    $0 ~ "^## "c"( |$)" {f=1; print; next}
    f && /^## / {exit}
    f {print}
  ' "$todo")
  printf '%s' "$block" | grep -qE '^\*\*Deliverable' || {
    echo "CRITICAL: $c has no **Deliverable:** line (cycle ships nothing — coverage hole)"; crit=1; nodeliv=$((nodeliv+1))
  }
  printf '%s' "$block" | grep -qiE 'demo:|^\*\*Cycle outcome' || {
    echo "HIGH: $c has no planned test (demo: or **Cycle outcome:** line)"; high=$((high+1)); notest=$((notest+1))
  }
done

echo "----"
echo "coverage: $ndel deliverables / $ncyc cycles · cycles-without-deliverable=$nodeliv · cycles-without-test=$notest · high=$high"
if [ "$crit" -ne 0 ]; then echo "ANALYZE: CRITICAL — fix coverage before build"; exit 1; fi
echo "ANALYZE: pass (every cycle ships + is testable)"; exit 0
