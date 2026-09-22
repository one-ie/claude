#!/usr/bin/env bash
# do-survey.sh — P0.5 SURVEY. Grep the 4 surfaces + text/ for an existing ≥70% match so
# /do stops rebuilding what already ships. Emits a simplicity verdict. (The cheapest feature
# is the one you already have.) Always exits 0 — it informs, it doesn't gate.
# Usage:  do-survey.sh <keyword>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
q="${1:?usage: do-survey.sh <keyword>}"

surfaces="one.ie/web/src/pages/api one.ie/web/src/components packages/sdk agents plans"
total=0
for d in $surfaces; do
  if [ -d "$ROOT/$d" ]; then
    n=$( { grep -rilw "$q" "$ROOT/$d" 2>/dev/null || true; } | wc -l | tr -d ' ')
  else
    n=0
  fi
  printf '  %-28s %s match(es)\n' "$d" "$n"
  total=$((total + n))
done

echo "----"
if [ "$total" -ge 3 ]; then
  echo "VERDICT: expose/extend — $total existing matches; reuse, do not rebuild (collapse to FIX tier)"
elif [ "$total" -ge 1 ]; then
  echo "VERDICT: extend — $total match; add a field/slot to what exists"
else
  echo "VERDICT: build — no existing match for '$q'"
fi
exit 0
