#!/usr/bin/env bash
# do-prove.sh — PROVE (P5). Auto-detect the surface from the changed files and emit the proof
# action; optional promise-check vs the P0 copy. The shipped thing must let the user do what the
# promise said. Exit 1 only on a clear over-promise (artifact mentions none of the promise terms).
# Usage:  do-prove.sh [--promise text/<f>.md] <changed-path>...
set -euo pipefail

promise=""
if [ "${1:-}" = "--promise" ]; then promise="$2"; shift 2; fi

paths=()
if [ "$#" -gt 0 ]; then paths=("$@"); else while IFS= read -r l; do [ -n "$l" ] && paths+=("$l"); done; fi
[ "${#paths[@]}" -eq 0 ] && { echo "PROVE: no changes"; exit 0; }

# surface detect — substrate wins (upstream), then api, then frontend, else backend
surface=backend
for p in "${paths[@]}"; do
  case "$p" in
    *.tql|schema/*) surface=substrate; break ;;
    */pages/api/*|*/api/*) surface=api ;;
    *.astro|*.tsx) [ "$surface" != "api" ] && surface=frontend ;;
  esac
done

case "$surface" in
  frontend)  proof="/browser (real Chrome: HTTP + JS/console errors + rail before/after + screenshot) + Lighthouse" ;;
  api)       proof="contract test (vitest+msw) + curl per surface — route + SDK + MCP + CLI (four-surface rule)" ;;
  backend)   proof="curl against the DEPLOYED runtime (local verify is necessary, not sufficient)" ;;
  substrate) proof="/sync reconcile (TypeDB↔KV↔D1↔SUI) + TypeQL returns the new shape + types compile downhill" ;;
esac
echo "surface: $surface"
echo "proof:   $proof"

# promise-check: at least one substantive term from the P0 copy must appear in the shipped files
if [ -n "$promise" ] && [ -f "$promise" ]; then
  # drop code keywords + generic verbs so the check keys on domain terms, not coincidences
  stop='export|function|return|const|class|import|async|await|value|string|number|default|users|allow|enable|create|update|delete|where|which|their'
  terms=$(grep -oiE '[a-z]{5,}' "$promise" | tr 'A-Z' 'a-z' | sort -u | grep -vwE "$stop" | head -40)
  hit=0
  for t in $terms; do
    for p in "${paths[@]}"; do
      if [ -f "$p" ] && grep -qi "$t" "$p" 2>/dev/null; then hit=1; break 2; fi
    done
  done
  if [ "$hit" -eq 0 ]; then
    echo "PROMISE-CHECK: FAIL — shipped artifact mentions none of the promise's terms (over-promise → back to P4 or re-FRAME)"
    exit 1
  fi
  echo "PROMISE-CHECK: ok"
fi
echo "PROVE: pass"; exit 0
