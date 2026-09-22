#!/usr/bin/env bash
# sdk-build-cached.sh — build @oneie/sdk, or skip when its sources have not moved.
#
# manifest: needs-env
#
# WHY. `cd packages/sdk && bun run build` ran on EVERY verify-fast pass, and it is
# 2.0s of the 2.6s total deterministic gate cost of a /do cycle -- 78%. Measured
# 2026-09-01: hashing dist before and after a rebuild on an unchanged tree gives
# the SAME digest. The build is deterministic, so on an unchanged src it is two
# seconds spent reproducing bytes that were already there.
#
# dist is a pure function of src (the same reasoning tsc-cached.sh uses to key on
# src rather than on dist mtimes, which every rebuild churns). So: fingerprint
# src, skip when it matches the fingerprint the current dist was built from.
#
# SAFETY. The stamp lives INSIDE dist. If dist is deleted, cleaned, or was never
# built, the stamp goes with it and the build runs -- there is no path where a
# missing dist reads as cached. A stale-but-present dist cannot survive an src
# edit either, because the fingerprint covers every tracked file under src.
#
# SDK_BUILD_FORCE=1 rebuilds unconditionally. --self-test runs the fixtures.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SDK="$ROOT/packages/sdk"

_fp() {
  { git -C "$ROOT" ls-files -s packages/sdk/src packages/sdk/package.json 2>/dev/null
    # uncommitted edits must move the key too -- ls-files -s shows the INDEX,
    # which does not change when a tracked file is edited in the working tree.
    git -C "$ROOT" diff -- packages/sdk/src packages/sdk/package.json 2>/dev/null
    git -C "$ROOT" ls-files --others --exclude-standard packages/sdk/src 2>/dev/null \
      | while IFS= read -r u; do shasum -a 256 "$ROOT/$u" 2>/dev/null; done
  } | shasum -a 256 | cut -d' ' -f1
}

if [ "${1:-}" = "--self-test" ]; then
  fails=0
  b1=$(bash "$0"); b2=$(bash "$0")
  case "$b2" in *"cached"*) echo "ok: second build on an unchanged tree is CACHED";;
    *) echo "FAIL: unchanged tree rebuilt: $b2"; fails=$((fails+1));; esac
  # RED PROOF 1 -- an src edit must force a rebuild
  probe="$SDK/src/.__cache_probe.ts"; echo 'export const __p = 1' > "$probe"
  b3=$(bash "$0")
  case "$b3" in *"cached"*) echo "FAIL: an src edit did NOT invalidate"; fails=$((fails+1));;
    *) echo "ok: an src edit forces a rebuild";; esac
  rm -f "$probe"
  # RED PROOF 2 -- a missing dist must force a rebuild, never read as cached
  rm -f "$SDK/dist/.build-fingerprint"
  b4=$(bash "$0")
  case "$b4" in *"cached"*) echo "FAIL: missing stamp read as cached"; fails=$((fails+1));;
    *) echo "ok: a missing stamp forces a rebuild";; esac
  [ "$fails" -eq 0 ] && { echo "sdk-build-cached: self-test PASS"; exit 0; }
  echo "sdk-build-cached: self-test FAILED ($fails)"; exit 1
fi

STAMP="$SDK/dist/.build-fingerprint"
want="$(_fp)"
if [ "${SDK_BUILD_FORCE:-0}" != "1" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$want" ]; then
  echo "[sdk] cached — src unchanged (${want:0:12})"
  exit 0
fi
( cd "$SDK" && bun run build >/dev/null ) || { echo "[sdk] BUILD FAILED" >&2; exit 1; }
printf '%s' "$want" > "$STAMP"
echo "[sdk] built (${want:0:12})"
