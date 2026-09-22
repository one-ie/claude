#!/usr/bin/env bash
# do-recon-cache.sh — sha-keyed W1 recon cache, 14-day TTL
#
# Primary: local file store (.w1-cache/)
# Secondary: KV-backed via /api/export/wave-cache when ONEIE_API_KEY + ONEIE_BASE_URL are set
#            (cross-worktree sharing — a warmed local miss falls through to KV)
#
# check <file>...   → if ALL files are cached and fresh, print findings to stdout, exit 0
#                     else exit 1 (caller proceeds to agent spawn)
# write <sha> <file> → store findings file under CACHE_DIR/<sha>.json + KV (best-effort)
# prune              → delete entries older than MAX_AGE_DAYS
set -euo pipefail

# CACHE_DIR must NOT be CWD-relative. Every /do cycle runs in a fresh
# .do-worktrees/<slug> checkout, so a relative `.w1-cache` was born empty on every
# single cycle -- the "0 tokens on hit, ~12k saved/recon" lever this script exists
# to provide had never once fired in a worktree run (measured 2026-09-01: no
# .w1-cache directory existed anywhere in the tree). Key it to the MACHINE, the
# same way the gate governor keys its locks, so worktrees share one warm store.
CACHE_DIR="${CACHE_DIR:-${TMPDIR:-/tmp}/one-w1-cache}"
MAX_AGE_DAYS=14
BASE_URL="${ONEIE_BASE_URL:-${ONE_BASE_URL:-}}"
API_KEY="${WAVE_CACHE_SECRET:-${ONEIE_API_KEY:-${ONE_API_KEY:-}}}"
cmd="${1:-}"; shift || true

_sha() { git hash-object "$1" 2>/dev/null || sha256sum "$1" | cut -c1-40; }

# Secret off argv (ps aux would leak a bare -H value) — one private 0600 curl
# --config file for the process lifetime, cleaned up on exit.
_AUTHCFG=""
_authcfg() {
  [ -n "$API_KEY" ] || return 1
  if [ -z "$_AUTHCFG" ]; then
    _AUTHCFG="$(mktemp)"; chmod 600 "$_AUTHCFG"
    printf 'header = "Authorization: Bearer %s"\n' "$API_KEY" >"$_AUTHCFG"
    trap '[ -n "$_AUTHCFG" ] && rm -f "$_AUTHCFG"' EXIT
  fi
  printf '%s' "$_AUTHCFG"
}

_kv_get() {
  local sha="$1" cfg
  [ -n "$BASE_URL" ] && [ -n "$API_KEY" ] || return 1
  cfg="$(_authcfg)" || return 1
  curl -sf -m 5 \
    --config "$cfg" \
    "${BASE_URL%/}/api/export/wave-cache?sha=${sha}" 2>/dev/null
}

_kv_put() {
  local sha="$1" src="$2" cfg
  [ -n "$BASE_URL" ] && [ -n "$API_KEY" ] || return 0
  cfg="$(_authcfg)" || return 0
  curl -sf -m 10 -X POST \
    --config "$cfg" \
    -H "Content-Type: text/plain" \
    --data-binary "@${src}" \
    "${BASE_URL%/}/api/export/wave-cache?sha=${sha}" >/dev/null 2>&1 || true
}

case "$cmd" in
  check)
    [ "$#" -eq 0 ] && exit 1
    mkdir -p "$CACHE_DIR"
    all_findings=""
    for path in "$@"; do
      [ -f "$path" ] || continue
      sha=$(_sha "$path")
      cache_file="$CACHE_DIR/${sha}.json"
      # local hit?
      if [ -f "$cache_file" ]; then
        if find "$cache_file" -mtime "+${MAX_AGE_DAYS}" -print 2>/dev/null | grep -q .; then
          rm -f "$cache_file"
        else
          all_findings="${all_findings}$(cat "$cache_file")"$'\n\n'
          continue
        fi
      fi
      # KV fallback
      kv_hit=$(_kv_get "$sha") || kv_hit=""
      if [ -n "$kv_hit" ]; then
        echo "$kv_hit" > "$cache_file"
        all_findings="${all_findings}${kv_hit}"$'\n\n'
        continue
      fi
      exit 1
    done
    printf '%s' "$all_findings"
    exit 0
    ;;
  write)
    sha="$1"; src="$2"
    mkdir -p "$CACHE_DIR"
    cp "$src" "$CACHE_DIR/${sha}.json"
    _kv_put "$sha" "$src"
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
