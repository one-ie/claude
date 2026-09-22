#!/usr/bin/env bash
# astro-build-cached.sh — build one.ie/web, or skip when nothing it reads has moved.
#
# manifest: needs-env
#
# WHY. The production astro build is one of the two heavy deploy gates: ~174s with
# --max-old-space-size=8192. It is a pure function of its sources, so re-running it
# over a tree that has not moved since the last successful build reproduces bytes
# that are already on disk. Same idiom as sdk-build-cached.sh, widened to cover
# everything the site build actually reads.
#
# SCOPE IS THE WHOLE SAFETY ARGUMENT. Under-scope the fingerprint and this ships a
# STALE dist -- unproven code in production, the one failure the deploy gate exists
# to prevent. So the key covers one.ie/web in full (src, public, every config) AND
# packages/, because the site imports @oneie/sdk, @oneie/design, @oneie/frontend and
# ten plugins by path. It is deliberately over-broad: an unnecessary rebuild costs
# three minutes, a missed one costs a bad deploy.
#
# The key is CONTENT, never mtimes and never `git status --porcelain` (which names
# files, so an edit that keeps a file "modified" does not move it -- the trap that
# was caught red-handed in test-cached.sh).
#
# SAFETY. The stamp lives INSIDE dist/. Delete, clean, or never build dist and the
# stamp goes with it, so a missing dist can never read as cached. The stamp is
# written only AFTER the build exits 0 and dist/server/ exists -- a failed or
# half-written build leaves no stamp and the next run rebuilds.
#
# ASTRO_BUILD_FORCE=1 rebuilds unconditionally. --self-test runs the fixtures.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB="$ROOT/one.ie/web"
STAMP="$WEB/dist/.astro-build-fingerprint"

# Files the build reads that git CANNOT see. `.env`/`.env.local` are gitignored,
# so neither ls-files nor diff nor even ls-files --others (which honours
# .gitignore) covers them -- and astro inlines PUBLIC_* values from them into the
# output. A key blind to them would hand back a cache hit for a build that would
# now produce different bytes. Lockfiles are listed explicitly for the same
# reason: a dependency bump can move only a lockfile.
# The credential file is part of the key (BETTER_AUTH_SECRET et al. are read at
# build time), and it honours ONE_ENV_FILE / DO_ENV_FILE like every credential
# read in the harness — factory-repo.sh --check-env-indirection is the gate.
_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
_UNTRACKED_INPUTS="$_ENV_FILE one.ie/web/.env.local one.ie/web/bun.lock one.ie/web/package-lock.json packages/bun.lock bun.lock"

_fp() {
  { git -C "$ROOT" ls-files -s one.ie/web packages 2>/dev/null
    git -C "$ROOT" diff -- one.ie/web packages 2>/dev/null
    git -C "$ROOT" ls-files --others --exclude-standard one.ie/web packages 2>/dev/null \
      | grep -v '^one.ie/web/dist/' \
      | while IFS= read -r u; do shasum -a 256 "$ROOT/$u" 2>/dev/null; done
    for f in $_UNTRACKED_INPUTS; do
      # An input that is absent must hash as "absent", not as nothing -- otherwise
      # deleting .env would leave the key unmoved.
      if [ -f "$ROOT/$f" ]; then shasum -a 256 "$ROOT/$f" 2>/dev/null
      else echo "ABSENT $f"; fi
    done
  } | shasum -a 256 | cut -d' ' -f1
}

if [ "${1:-}" = "--self-test" ]; then
  fails=0
  if [ ! -f "$STAMP" ]; then
    echo "n/a: no prior build stamp — run a real build first, then re-run --self-test" >&2
    echo "     (an absent stamp is 'not measured', never 'ok')" >&2
    exit 2
  fi
  # 1. an unchanged tree is cached
  o1=$(bash "$0" --check-only)
  case "$o1" in *cached*) echo "ok: unchanged tree reads as cached";;
    *) echo "FAIL: unchanged tree did not read as cached: $o1"; fails=$((fails+1));; esac
  # RED PROOF 1 — a source edit must invalidate
  probe="$WEB/src/.__build_cache_probe.ts"; echo 'export const __p = 1' > "$probe"
  o2=$(bash "$0" --check-only)
  case "$o2" in *cached*) echo "FAIL: an src edit did NOT invalidate the build cache"; fails=$((fails+1));;
    *) echo "ok: an src edit invalidates";; esac
  rm -f "$probe"
  # RED PROOF 2 — an edit in packages/ must invalidate (the cross-package trap)
  probe2="$ROOT/packages/design/.__build_cache_probe.ts"; echo 'export const __p = 1' > "$probe2"
  o3=$(bash "$0" --check-only)
  case "$o3" in *cached*) echo "FAIL: a packages/ edit did NOT invalidate"; fails=$((fails+1));;
    *) echo "ok: a packages/ edit invalidates";; esac
  rm -f "$probe2"
  # RED PROOF 3 — a gitignored .env edit must invalidate. git cannot see this file
  # at all, so a key built only from ls-files/diff stays put while the build's
  # inlined PUBLIC_* values change underneath it.
  envf="$WEB/.env"
  if [ -f "$envf" ]; then
    cp "$envf" "$envf.__probe.bak"
    echo '# __build_cache_probe' >> "$envf"
    o3b=$(bash "$0" --check-only)
    case "$o3b" in *cached*) echo "FAIL: a .env edit did NOT invalidate (git cannot see it)"; fails=$((fails+1));;
      *) echo "ok: a gitignored .env edit invalidates";; esac
    mv "$envf.__probe.bak" "$envf"
  else
    echo "n/a: no $_ENV_FILE present, cannot run the gitignored-input proof" >&2
  fi
  # RED PROOF 4 — a missing stamp must never read as cached
  mv "$STAMP" "$STAMP.bak"
  o4=$(bash "$0" --check-only)
  case "$o4" in *cached*) echo "FAIL: missing stamp read as cached"; fails=$((fails+1));;
    *) echo "ok: a missing stamp forces a rebuild";; esac
  mv "$STAMP.bak" "$STAMP"
  # RED PROOF 5 — a stamp whose dist/server is gone must never read as cached
  if [ -d "$WEB/dist/server" ]; then
    mv "$WEB/dist/server" "$WEB/dist/.server.bak"
    o5=$(bash "$0" --check-only)
    case "$o5" in *cached*) echo "FAIL: a stamp with no dist/server read as cached"; fails=$((fails+1));;
      *) echo "ok: a missing dist/server forces a rebuild";; esac
    mv "$WEB/dist/.server.bak" "$WEB/dist/server"
  else
    echo "n/a: dist/server absent, cannot run the missing-output proof" >&2
  fi
  [ "$fails" -eq 0 ] && { echo "astro-build-cached: self-test PASS"; exit 0; }
  echo "astro-build-cached: self-test FAILED ($fails)"; exit 1
fi

CHECK_ONLY=0
[ "${1:-}" = "--check-only" ] && CHECK_ONLY=1

want="$(_fp)"
# THREE conditions, all required. dist/server is checked as well as the stamp
# because the stamp records "these sources built cleanly", not "the output is
# still here" -- a `rm -rf dist/server` with the stamp left behind must rebuild.
if [ "${ASTRO_BUILD_FORCE:-0}" != "1" ] \
   && [ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$want" ] \
   && [ -d "$WEB/dist/server" ]; then
  echo "[astro] cached — one.ie/web + packages unchanged (${want:0:12})"
  exit 0
fi

if (( CHECK_ONLY )); then
  echo "[astro] would REBUILD (${want:0:12})"
  exit 0
fi

( cd "$WEB" && NODE_ENV=production bun run build ) || { echo "[astro] BUILD FAILED" >&2; exit 1; }
# Never stamp an output that is not there. A build that exits 0 without producing
# dist/server has not proven anything, and stamping it would hand the next deploy
# a cache hit over a missing artifact.
[ -d "$WEB/dist/server" ] || { echo "[astro] build exited 0 but dist/server is missing — NOT cached" >&2; exit 1; }
printf '%s' "$want" > "$STAMP"
echo "[astro] built (${want:0:12})"
