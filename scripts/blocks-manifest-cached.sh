#!/usr/bin/env bash
# blocks-manifest-cached.sh — run `blocks-manifest.mjs --check`, or skip it when
# nothing that feeds the manifest has moved.
#
# manifest: needs-env
#
# WHY. C2 wired `--check` into verify-fast.sh as Step 0 on 2026-09-09, which was
# right -- three committed artifacts were generated from one registry and gated by
# nothing. But it runs on EVERY fast-lane pass, and measured on this box, warm,
# twice in a row: 8.19s and 6.98s. The fast lane exists to be run on every edit;
# a fixed ~7s toll on a doc edit, a script edit or a test-only cycle is most of
# what the lane was built to avoid. Only ~1.0-1.3s of that is the `bunx tsx`
# resolution leg (measured: `bunx tsx --version` 1.33s then 1.03s) -- the rest is
# the real work, importing a 7,800-line config through tsx and walking 243 blocks.
# So vendoring tsx does not fix this. A memo does.
#
# WHY NARROWING IS SOUND HERE, AND IS NOT THE test-cached.sh MISTAKE. CLAUDE.md
# warns: do not narrow test-cached.sh's key, because those tests readFileSync
# across pay/, channels/, schema/, .claude/ and text/ at runtime, so an import
# graph is NOT a superset of what a test reads. blocks-manifest.mjs is the
# opposite shape. Its inputs are DECLARED at :33-38 -- config.tsx, families.ts,
# block-usage.json -- and the runner it generates does nothing but import
# config.tsx and walk puckConfig.components. Its inputs ARE its import graph, by
# construction. Read that precedent before reaching for it here; it is about a
# different failure.
#
# THE KEY IS A SUPERSET ON PURPOSE. Everything the check reads AND all three
# artifacts it compares against live under one.ie/web/src, so the fingerprint
# covers that whole tree rather than a hand-listed set of paths. A block
# component living somewhere the list did not anticipate is exactly how a memo
# goes unsound, and a drifted manifest reading as cached is far worse than 7s.
# The cost of the superset is that any src edit misses -- which is correct, and
# still skips every doc-only, script-only and test-only cycle.
#
# SAFETY, the direction that matters: a LOST stamp costs a run, never a skip.
# The stamp lives in GOVERN_DIR (machine-wide tmp, evaporates), so a fresh box, a
# cleared tmp or a new worktree all MISS. There is no path where a missing stamp
# reads as cached. Staged-but-uncommitted edits move the key too, because
# `ls-files -s` shows the INDEX while `diff` shows the working tree -- one leg
# alone would miss half of them (the scar sdk-build-cached.sh records).
#
# BLOCKS_MANIFEST_FORCE=1 always runs. --self-test drives the red half.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GOVERN_DIR="${GOVERN_DIR:-${TMPDIR:-/tmp}/one-govern}"
mkdir -p "$GOVERN_DIR"

_fp() {
  { git -C "$ROOT" ls-files -s one.ie/web/src 2>/dev/null
    git -C "$ROOT" diff -- one.ie/web/src 2>/dev/null
    git -C "$ROOT" ls-files --others --exclude-standard one.ie/web/src 2>/dev/null \
      | while IFS= read -r u; do shasum -a 256 "$ROOT/$u" 2>/dev/null; done
  } | shasum -a 256 | cut -d' ' -f1
}

_run_check() {
  local out rc
  out="$(mktemp)"
  set +e
  node "$ROOT/.claude/scripts/blocks-manifest.mjs" --check > "$out" 2>&1
  rc=$?
  set -e
  cat "$out"; rm -f "$out"
  return $rc
}

if [ "${1:-}" = "--self-test" ]; then
  fails=0
  probe="$ROOT/one.ie/web/src/lib/puck/.memo-probe.ts"
  BLOCKS_MANIFEST_FORCE=1 bash "$0" >/dev/null 2>&1 || true
  a="$(bash "$0" 2>&1)"
  case "$a" in *cached*) echo "ok: second run on an unchanged tree is CACHED";;
    *) echo "FAIL: unchanged tree re-ran: $a"; fails=$((fails+1));; esac
  # RED HALF: a memo that cannot be shown to MISS is an unrun gate in a
  # performance costume -- the exact class Step 0 was added to close.
  printf 'export const __memoProbe = 1\n' > "$probe"
  b="$(bash "$0" 2>&1)"
  rm -f "$probe"
  case "$b" in *cached*) echo "FAIL: a new file under src did NOT invalidate the memo"; fails=$((fails+1));;
    *) echo "ok: a new file under src MISSES (red half proven)";; esac
  c="$(bash "$0" 2>&1)"
  case "$c" in *cached*) echo "ok: removing the probe returns to the earlier key";;
    *) echo "note: post-probe run re-ran (fine — a miss is never wrong)";; esac
  [ "$fails" -eq 0 ] && echo "blocks-manifest-cached --self-test: PASS" || { echo "blocks-manifest-cached --self-test: $fails FAIL"; exit 1; }
  exit 0
fi

want="$(_fp)"
STAMP="$GOVERN_DIR/blocks-manifest.$want"

if [ "${BLOCKS_MANIFEST_FORCE:-0}" != "1" ] && [ -f "$STAMP" ]; then
  echo "blocks-manifest --check: cached (one.ie/web/src unchanged since the last pass)"
  exit 0
fi

_run_check || exit $?
# Only a PASS is memoised. A drift result is never stamped: the next run must
# see it again, and `test-cached.sh` records the same rule for the same reason.
rm -f "$GOVERN_DIR"/blocks-manifest.* 2>/dev/null || true
printf '%s' "$want" > "$STAMP"
