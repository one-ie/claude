#!/usr/bin/env bash
# do-folder.sh — resolve target repo folder(s) from a changed-file list and emit each
# folder's verify/build commands. There is NO root package.json by design: every top
# folder under one-ie/ is its own buildable repo. /do W0/W4 use this instead of a root
# `bun run verify`. Doc-only cycles (.md / .claude / plans / text / docs) skip bun entirely.
#
# Usage:  do-folder.sh <path>...        |   git diff --name-only | do-folder.sh
# Output: one JSON object per resolved folder (or a single doc_only line):
#   {"folder":"one.ie/web","verify":"bun run verify","build":"bun run build","doc_only":false}
#   {"folder":null,"verify":null,"build":null,"doc_only":true}
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # .claude/scripts -> one-ie root

# 1. gather paths from args or stdin
paths=()
if [ "$#" -gt 0 ]; then
  paths=("$@")
else
  while IFS= read -r line; do [ -n "$line" ] && paths+=("$line"); done
fi
[ "${#paths[@]}" -eq 0 ] && { echo '{"folder":null,"verify":null,"build":null,"doc_only":true}'; exit 0; }

# 2. doc-only = every path is markdown or lives in a non-built dir
doc_only=true
for p in "${paths[@]}"; do
  case "$p" in
    *.md|.claude/*|plans/*|text/*|docs/*) ;;
    *) doc_only=false ;;
  esac
done
if $doc_only; then
  echo '{"folder":null,"verify":null,"build":null,"doc_only":true}'
  exit 0
fi

# 3. longest-prefix match against known buildable folders (one.ie/web BEFORE one.ie).
#    bash 3.2-safe (macOS): no associative arrays — dedup a newline list with sort -u.
folders="one.ie/web one.ie packages agents api schema sync backup"
matched=""
for p in "${paths[@]}"; do
  for f in $folders; do
    case "$p" in "$f"/*) matched="${matched}${f}
"; break;; esac
  done
done
matched=$(printf '%s' "$matched" | sed '/^$/d' | sort -u)

if [ -z "$matched" ]; then
  echo '{"folder":null,"verify":null,"build":null,"doc_only":false,"reason":"unmapped"}'
  exit 0
fi

# 4. emit per folder, reading its own package.json for the script names
printf '%s\n' "$matched" | while IFS= read -r f; do
  pj="$ROOT/$f/package.json"
  verify="null"; build="null"
  if [ -f "$pj" ]; then
    jq -e '.scripts.verify' "$pj" >/dev/null 2>&1 && verify='"bun run verify"'
    jq -e '.scripts.build'  "$pj" >/dev/null 2>&1 && build='"bun run build"'
  fi
  printf '{"folder":"%s","verify":%s,"build":%s,"doc_only":false}\n' "$f" "$verify" "$build"
done
