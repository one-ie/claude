#!/usr/bin/env bash
# redirect-lint.sh — `Response.redirect()` is banned under one.ie/web/src/pages/api/.
#
# WHY. `Response.redirect()` returns a Response whose headers are IMMUTABLE.
# The Astro Cloudflare adapter / middleware then writes `Server-Timing` (or the
# queued `vid` cookie) onto it and the worker throws "Can't modify immutable
# headers" — a 500 with Cloudflare error code 1101, on the success path only.
# Measured on production 2026-09-11: /api/composio/redirect and
# /api/composio/callback both 500.
#
# This repo has diagnosed and fixed the same mechanism three separate times
# before this lint existed:
#   one.ie/web/src/pages/api/og/screenshot.png.ts:33  (the comment + the fix)
#   one.ie/web/src/middleware.ts:746                  (the comment + the fix)
#   one.ie/web/src/lib/page-cache-middleware.ts:45    (swallows the throw)
# The lint is what stops a fourth time.
#
# THE FIX, every time:
#   return new Response(null, { status: 302, headers: { Location: <absolute url> } })
#
# SCOPE. API routes only — those are the handlers whose response the adapter
# decorates. Comment lines are exempt: the three files above NAME the pattern in
# prose, and a lint that is red on a clean tree gets deleted within a week.
#
# USAGE
#   bash .claude/scripts/redirect-lint.sh              # lint the repo, exit 1 on any hit
#   bash .claude/scripts/redirect-lint.sh --self-test  # drive it RED, then GREEN, then
#                                                      # prove a comment stays GREEN
# EXITS
#   0  clean          1  violations found          2  usage / self-test failed
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_DIR="one.ie/web/src/pages/api"
PATTERN='Response\.redirect('

# scan <dir> — every CODE occurrence as `file:line:content`, comments dropped.
# Empty output means clean. The grep output is CAPTURED first and matched from a
# here-string: under `set -o pipefail`, `<producer> | grep -q` returns 141 when
# it matches while the producer is still writing.
scan() {
  local dir="$1" raw line content trimmed
  raw="$(grep -rn "$PATTERN" "$dir" 2>/dev/null || true)"
  [ -z "$raw" ] && return 0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    content="${line#*:}"          # strip `file:`
    content="${content#*:}"       # strip `line:`
    trimmed="$(printf '%s' "$content" | sed 's/^[[:space:]]*//')"
    case "$trimmed" in
      '//'*|'*'*|'/*'*) continue ;;   # a comment naming the pattern is not a call
    esac
    printf '%s\n' "$line"
  done <<< "$raw"
}

# lint <dir> [label] — report and set the exit code. The whole main path, so the
# self-test drives the real thing rather than a re-implementation of it.
lint() {
  local dir="$1" label="${2:-$dir}" hits count
  if [ ! -d "$dir" ]; then
    echo "[redirect-lint] RED — directory not found: $dir" >&2
    return 2
  fi
  hits="$(scan "$dir")"
  if [ -z "$hits" ]; then
    echo "[redirect-lint] ok — no Response.redirect() under $label"
    return 0
  fi
  count="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  echo "[redirect-lint] RED — $count call site(s) of Response.redirect() under $label:" >&2
  printf '%s\n' "$hits" | sed "s#^$ROOT/##" >&2
  cat >&2 <<'HINT'

  Response.redirect() headers are immutable; the adapter's Server-Timing write
  then throws "Can't modify immutable headers" (500, cf error 1101). Use:

    return new Response(null, { status: 302, headers: { Location: <absolute url> } })
HINT
  return 1
}

# Global on purpose: the EXIT trap body is evaluated after self_test has
# returned, so a `local` sandbox is already out of scope by then — under
# `set -u` that made a fully passing self-test exit 1 on its own cleanup.
sandbox=""

self_test() {
  local rc out fails=0
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/redirect-lint-selftest.XXXXXX")"
  trap 'rm -rf "${sandbox:-}"' EXIT
  mkdir -p "$sandbox/api"

  # A file that is already correct — present in all three phases, so a green
  # phase proves the scan ran over real content rather than over nothing.
  cat > "$sandbox/api/ok.ts" <<'TS'
export const GET = ({ url }) =>
  new Response(null, { status: 302, headers: { Location: `${url.origin}/next` } })
TS

  # 1 — a real call site must go RED.
  cat > "$sandbox/api/bad.ts" <<'TS'
export const GET = ({ url }) => Response.redirect(`${url.origin}/next`, 302)
TS
  set +e
  out="$(lint "$sandbox" "sandbox" 2>&1)"; rc=$?
  set -e
  if [ "$rc" -eq 1 ]; then
    echo "  [1/3] planted call site → RED (exit 1) ✓"
  else
    echo "  [1/3] planted call site → expected exit 1, got $rc" >&2
    printf '%s\n' "$out" >&2
    fails=$((fails + 1))
  fi

  # 2 — removing it must go GREEN.
  rm -f "$sandbox/api/bad.ts"
  set +e
  out="$(lint "$sandbox" "sandbox" 2>&1)"; rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "  [2/3] violation removed → GREEN (exit 0) ✓"
  else
    echo "  [2/3] violation removed → expected exit 0, got $rc" >&2
    printf '%s\n' "$out" >&2
    fails=$((fails + 1))
  fi

  # 3 — a COMMENT naming the pattern must stay GREEN. This is the exclusion the
  # three prior fixes depend on; untested, someone "simplifies" it back into a
  # false positive and the lint starts firing on its own documentation.
  cat > "$sandbox/api/documented.ts" <<'TS'
export const GET = ({ url }) => {
  // Response.redirect() returns an immutable Response — the adapter's
  // Server-Timing header write then throws "Can't modify immutable headers".
  /* Response.redirect( in a block comment too */
  return new Response(null, { status: 302, headers: { Location: `${url.origin}/next` } })
}
TS
  set +e
  out="$(lint "$sandbox" "sandbox" 2>&1)"; rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "  [3/3] comment naming the pattern → GREEN (exit 0) ✓"
  else
    echo "  [3/3] comment naming the pattern → expected exit 0, got $rc" >&2
    printf '%s\n' "$out" >&2
    fails=$((fails + 1))
  fi

  if [ "$fails" -ne 0 ]; then
    echo "[redirect-lint] --self-test FAILED ($fails/3)" >&2
    return 2
  fi
  echo "[redirect-lint] --self-test ok (3/3)"
  return 0
}

case "${1:-}" in
  --self-test) self_test ;;
  --scan-dir)  lint "${2:?--scan-dir needs a directory}" ;;
  -h|--help)
    sed -n '1,32p' "${BASH_SOURCE[0]}"
    exit 2 ;;
  '')          lint "$ROOT/$API_DIR" "$API_DIR" ;;
  *)
    echo "usage: redirect-lint.sh [--self-test|--scan-dir <dir>]" >&2
    exit 2 ;;
esac
