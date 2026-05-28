#!/usr/bin/env bash
# do-tier.sh — the token-economy spine-pruner. Infer the loop tier from the changed files
# (+ optional --intent) and emit the pruned spine, the inner classifier, and a per-tier
# token ceiling. The human never picks: this one signal sizes both outer and inner work.
# DEFAULT DOWN when unsure — an under-built FIX re-opens cheaply; an over-built PATCH is burnt.
# Usage:  do-tier.sh [--intent "text"] <path>...   |   git diff --name-only | do-tier.sh [--intent ...]
set -euo pipefail

intent=""
if [ "${1:-}" = "--intent" ]; then intent="$2"; shift 2; fi

paths=()
if [ "$#" -gt 0 ]; then paths=("$@"); else while IFS= read -r l; do [ -n "$l" ] && paths+=("$l"); done; fi
[ "${#paths[@]}" -eq 0 ] && paths=("")

n=${#paths[@]}
schema=false; code=false; doconly=true
for p in "${paths[@]}"; do
  case "$p" in
    *.tql|schema/*) schema=true; code=true; doconly=false ;;
    *.md|.claude/*|plans/*|text/*|docs/*) ;;
    "") ;;
    *) code=true; doconly=false ;;
  esac
done

# tier inference — first match wins, biased downward
if $schema; then tier=SCHEMA
elif printf '%s' "$intent" | grep -qiE '\b(add|new|introduce|build a|feature|capability)\b'; then tier=FEATURE
elif $doconly && [ "$n" -le 2 ]; then tier=PATCH
elif ! $code && [ "$n" -le 2 ]; then tier=PATCH
elif ! $code; then tier=FIX
else tier=FIX
fi

case "$tier" in
  PATCH)   spine="code verify";                                            cls=TRIVIAL; ceil=5000 ;;
  FIX)     spine="survey code tests proof";                               cls=SIMPLE;  ceil=30000 ;;
  FEATURE) spine="promise survey spec clarify todo analyze code tests proof docs release"; cls=COMPLEX; ceil=150000 ;;
  SCHEMA)  spine="promise survey spec reconcile clarify todo analyze code tests proof docs release"; cls=COMPLEX; ceil=200000 ;;
esac

printf '{"tier":"%s","spine":"%s","classifier":"%s","ceiling_tokens":%s}\n' "$tier" "$spine" "$cls" "$ceil"
