#!/usr/bin/env bash
# do-recon-cache.sh — sha-keyed W1 recon cache, 14-day TTL, local file store
#
# check <file>...   → if ALL files are cached and fresh, print findings to stdout, exit 0
#                     else exit 1 (caller proceeds to agent spawn)
# write <sha> <file> → store findings file under CACHE_DIR/<sha>.json
# prune              → delete entries older than MAX_AGE_DAYS
set -euo pipefail

CACHE_DIR="${CACHE_DIR:-.w1-cache}"
MAX_AGE_DAYS=14
cmd="${1:-}"; shift || true

_sha() { git hash-object "$1" 2>/dev/null || sha256sum "$1" | cut -c1-40; }

case "$cmd" in
  check)
    [ "$#" -eq 0 ] && exit 1
    mkdir -p "$CACHE_DIR"
    all_findings=""
    for path in "$@"; do
      [ -f "$path" ] || continue
      sha=$(_sha "$path")
      cache_file="$CACHE_DIR/${sha}.json"
      [ -f "$cache_file" ] || exit 1
      # stale?
      if find "$cache_file" -mtime "+${MAX_AGE_DAYS}" -print 2>/dev/null | grep -q .; then
        rm -f "$cache_file"
        exit 1
      fi
      all_findings="${all_findings}$(cat "$cache_file")"$'\n\n'
    done
    printf '%s' "$all_findings"
    exit 0
    ;;
  write)
    sha="$1"; src="$2"
    mkdir -p "$CACHE_DIR"
    cp "$src" "$CACHE_DIR/${sha}.json"
    ;;
  prune)
    [ -d "$CACHE_DIR" ] || exit 0
    count=$(find "$CACHE_DIR" -name '*.json' -mtime "+${MAX_AGE_DAYS}" -print -delete | wc -l)
    echo "pruned ${count} stale entries from $CACHE_DIR"
    ;;
  *)
    echo "usage: do-recon-cache.sh check <file>... | write <sha> <file> | prune" >&2
    exit 1
    ;;
esac
