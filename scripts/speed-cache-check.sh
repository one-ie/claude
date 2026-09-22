#!/usr/bin/env bash
# speed-cache-check.sh — proves domain-memo.ts's cross-isolate (L2) cache is a
# real behaviour, not a presence grep.
#
# WHY THIS EXISTS: an earlier draft of "prove the cache works" matched the
# word "CACHED" inside a docblock and passed on nothing — a presence grep
# proves a SHAPE, never a BEHAVIOUR (text/learnings.md, project_fail_open_aggregate_runners).
# This check instead runs the real vitest suite twice against two different
# trees of the SAME file (working tree vs `git show HEAD:<path>`, the shape
# before this cycle's L2 fix landed) and asserts the exit code differs in the
# expected direction:
#
#   RED  (pre-fix domain-memo.ts): "a cold isolate ... still skips D1 via L2"
#        fails — a per-isolate Map has no cross-isolate reach, so a fresh
#        `vi.resetModules()` import always re-pays D1.
#   GREEN (this cycle's domain-memo.ts): the same test passes — a fresh
#        module import still finds the row in the shared `caches.default`
#        store the "warm" isolate wrote, and never touches D1.
#
# The GREEN half is what a normal CI run enforces (`bun run verify` already
# runs tests/unit/domain-memo.test.ts). This script exists for the RED half —
# proving the test can fail, and fails for the SPECIFIC reason claimed (a cold
# isolate re-pays D1), not some unrelated breakage.
#
# Usage: bash .claude/scripts/speed-cache-check.sh
#   Exits 0 only if: RED run fails on the cold-isolate test AND GREEN run
#   (the current working tree) passes the whole file.

set -euo pipefail

# _GATE — see governor-doors-check.sh "compute sites". A gate_lock dedupes
# identical work; only a SLOT bounds N worktrees running N computes at once.
# Empty inside an existing gate so the outer slot is inherited, never doubled.
_GATE=()
if [ "${GOVERN_IN_GATE:-0}" != "1" ]; then
  _GR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-run.sh"
  [ -f "$_GR" ] && _GATE=( bash "$_GR" "compute:$(basename "${BASH_SOURCE[0]}")" -- )
fi


ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB="$ROOT/one.ie/web"
REL_MEMO="one.ie/web/src/lib/domain-memo.ts"
REL_TEST="one.ie/web/tests/unit/domain-memo.test.ts"
TEST_FILE="tests/unit/domain-memo.test.ts"
COLD_TEST_NAME="a cold isolate"

cd "$ROOT"

if [ ! -f "$REL_MEMO" ]; then
	echo "[speed-cache-check] missing $REL_MEMO — nothing to check" >&2
	exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "[speed-cache-check] not a git repo — cannot diff RED vs GREEN" >&2
	exit 2
fi

# The RED half needs a tree where domain-memo.ts has NO L2 (Cache API) layer.
# If HEAD already has the fix (this cycle already committed), fall back to a
# hand-written broken copy so the check still proves something rather than
# silently degrading to "n/a".
HEAD_HAS_L2=0
if git show HEAD:"$REL_MEMO" 2>/dev/null | grep -q "caches\.default"; then
	HEAD_HAS_L2=1
fi

TMP_BROKEN=""
cleanup() {
	if [ -n "$TMP_BROKEN" ] && [ -f "$TMP_BROKEN" ]; then
		rm -f "$TMP_BROKEN"
	fi
	if [ "${STASHED:-0}" = "1" ]; then
		git stash pop --quiet
	fi
}
trap cleanup EXIT

STASHED=0
RED_SOURCE_DESC=""

if [ "$HEAD_HAS_L2" = "0" ]; then
	RED_SOURCE_DESC="git HEAD:$REL_MEMO (pre-fix shape)"
	# Stash ONLY this file's working-tree changes (never a blanket stash —
	# .claude/CLAUDE.md's git-add-guard rule, and just good hygiene: this repo
	# has other unrelated modified files in play from sibling /do cycles).
	if ! git diff --quiet -- "$REL_MEMO"; then
		git stash push --quiet -- "$REL_MEMO"
		STASHED=1
	fi
else
	# HEAD already carries the L2 fix (e.g. re-run after commit) — synthesize
	# the pre-fix shape by stripping the L2 read/write calls out of a scratch
	# copy, then swap it in the same way (stash, write broken, test, restore).
	RED_SOURCE_DESC="synthesized pre-L2 copy (HEAD already has the fix)"
	TMP_BROKEN="$(mktemp)"
	python3 - "$REL_MEMO" "$TMP_BROKEN" <<'PY'
import re, sys
src_path, out_path = sys.argv[1], sys.argv[2]
with open(src_path) as f:
    src = f.read()
# Remove the L2 read/write calls from readDomainRowMemo so it behaves exactly
# like the original per-isolate-only implementation.
src = src.replace(
    """\tconst edgeRow = await readEdgeCache(host);
\tif (edgeRow !== undefined) {
\t\tif (_cache.size >= MAX_ENTRIES) _cache.clear();
\t\t_cache.set(host, { row: edgeRow, at: Date.now() });
\t\treturn edgeRow;
\t}

""",
    "",
)
src = src.replace("\twriteEdgeCache(host, row);\n", "")
with open(out_path, "w") as f:
    f.write(src)
PY
	cp "$REL_MEMO" "${REL_MEMO}.speed-cache-check.bak"
	cp "$TMP_BROKEN" "$REL_MEMO"
	STASHED=2
	cleanup() {
		mv "${REL_MEMO}.speed-cache-check.bak" "$REL_MEMO"
		rm -f "$TMP_BROKEN"
	}
	trap cleanup EXIT
fi

echo "[speed-cache-check] RED run — $RED_SOURCE_DESC"
cd "$WEB"
set +e
RED_OUT="$("${_GATE[@]}" bunx vitest run "$TEST_FILE" -t "$COLD_TEST_NAME" 2>&1)"
RED_STATUS=$?
set -e
cd "$ROOT"

if [ $RED_STATUS -eq 0 ]; then
	echo "[speed-cache-check] FAIL: the cold-isolate test PASSED against the pre-fix shape." >&2
	echo "  That means the test isn't proving cross-isolate behaviour — it would pass on nothing." >&2
	echo "$RED_OUT" | tail -40 >&2
	exit 1
fi
if ! printf '%s' "$RED_OUT" | grep -q "$COLD_TEST_NAME"; then
	echo "[speed-cache-check] FAIL: RED run failed but not on the named test — some other breakage." >&2
	echo "$RED_OUT" | tail -60 >&2
	exit 1
fi
echo "[speed-cache-check] RED confirmed — cold-isolate test fails without L2 (as expected)."

# Restore the fixed file before the GREEN run.
trap - EXIT
cleanup
STASHED=0
TMP_BROKEN=""

echo "[speed-cache-check] GREEN run — working tree $REL_MEMO"
cd "$WEB"
set +e
GREEN_OUT="$("${_GATE[@]}" bunx vitest run "$TEST_FILE" 2>&1)"
GREEN_STATUS=$?
set -e
cd "$ROOT"

if [ $GREEN_STATUS -ne 0 ]; then
	echo "[speed-cache-check] FAIL: the full domain-memo suite does not pass on the fixed file." >&2
	echo "$GREEN_OUT" | tail -60 >&2
	exit 1
fi

echo "[speed-cache-check] GREEN confirmed — full domain-memo.test.ts passes with L2 wired."
echo "[speed-cache-check] OK — the cross-isolate cache is proven by behaviour, not by grep."
exit 0
