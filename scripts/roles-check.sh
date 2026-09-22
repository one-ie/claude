#!/usr/bin/env bash
# roles-check.sh — the nine behavioural checks for roles-vantage-collapse.
#
# Interface Contract row 1: `roles-check.sh --check-<name>` · exit 0 = pass ·
# every subcommand must demonstrate its own red path (never merely assert that
# a file or a line is present).
#
#   --check-gate        C1  IMPLEMENTED
#   --check-decide      C3  IMPLEMENTED
#   --check-503         C3  IMPLEMENTED
#   --check-floors      C4  IMPLEMENTED
#   --check-no-vantage  C5  IMPLEMENTED
#   --check-worldkey    C6  IMPLEMENTED
#   --check-staff       C7  stub
#   --check-suite       C8  stub
#   --check-docs        C9  stub
#
# --check-gate proves the gate that catches the bug this plan exists to kill: a
# vantage word compared against a rung word (`viewer === 'owner'`) — a ts(2367)
# only `astro check` can see, because `tsc --noEmit` never reads .astro
# frontmatter. It runs one.ie/web's astro-check ratchet twice: clean (green —
# the committed baseline is accurate) then with a planted comparison (red — and
# the diagnostic must name the planted file, ts(2367), and "have no overlap").
# Presence of the script line in package.json is NOT the check.
#
# Env:
#   ROLES_CHECK_SCRATCH  path of the planted file. Default
#                        one.ie/web/src/__roles_check_scratch.astro — outside
#                        src/pages (so it can never become a served route) and
#                        outside src/components (no directory contract). If
#                        astro check does not glob that path the check FAILS
#                        loudly and names the src/pages/ retry.
#
# Exit: 0 pass · 1 fail · 2 inconclusive (astro check OOMed or emitted no
#       parseable summary — an unrun check is never a green one).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB="$ROOT/one.ie/web"
SCRATCH="${ROLES_CHECK_SCRATCH:-$WEB/src/__roles_check_scratch.astro}"
RATCHET="$WEB/scripts/astro-check-ratchet.mjs"

_stub() { echo "ROLES-CHECK: $1 is not implemented yet — lands in $2" >&2; exit 1; }
_fail() { echo "ROLES-CHECK: FAIL — $*" >&2; exit 1; }

# astro check's output is read from a FILE, never a $( ) capture — see check_gate.
RATCHET_LOG=""
_run_ratchet() { ( cd "$WEB" && node scripts/astro-check-ratchet.mjs ) >"$RATCHET_LOG" 2>&1; }

check_gate() {
  [ -f "$RATCHET" ] || _fail "no ratchet at one.ie/web/scripts/astro-check-ratchet.mjs"
  [ -f "$WEB/.astro-check-baseline.json" ] \
    || _fail "no committed baseline at one.ie/web/.astro-check-baseline.json (generate: cd one.ie/web && node scripts/astro-check-ratchet.mjs --update)"
  grep -q '"verify":.*check:ratchet' "$WEB/package.json" \
    || _fail "bun run verify does not call the ratchet — the gate is not wired"

  # `bun run verify` builds the SDK before typechecking for a reason: an unbuilt
  # packages/sdk/dist emits a wall of phantom TS2307s, which would raise ts(2307)
  # above baseline and report a stale baseline that has nothing to do with the
  # plant. This check runs standalone (it is first in the plan's kill-switch, in a
  # bare shell), so it warms the same build itself rather than assuming one.
  ( cd "$ROOT/packages/sdk" && bun run build ) >/dev/null 2>&1 \
    || _fail "packages/sdk build failed — astro check cannot be measured honestly without it"

  rm -f "$SCRATCH"
  trap 'rm -f "$SCRATCH"' EXIT

  local out rc t0 green_secs red_secs base
  base="$(basename "$SCRATCH")"

  # astro check emits megabytes (2436 files, minified inline scripts among them),
  # and capturing that through $( ) drops lines: measured on the merged tree, the
  # substitution kept 65 KB and lost the very diagnostic this check asserts on,
  # while the same run redirected to a FILE kept it at line 967. That produced a
  # false RED — "the gate went red but no diagnostic names the plant" — on a run
  # where the ratchet had correctly reported ts(2367) 1 -> 2. Same family as the
  # pipefail/SIGPIPE trap in .claude/CLAUDE.md: never read a large producer
  # through a pipe or a substitution. Redirect, then read the file.
  RATCHET_LOG="$(mktemp -t roles-check-ratchet)"
  trap 'rm -f "$SCRATCH" "${RATCHET_LOG:-}"' EXIT

  # --- green half: no plant, the committed baseline is accurate ---
  t0=$(date +%s)
  set +e; _run_ratchet; rc=$?; out="$(cat "$RATCHET_LOG")"; set -e
  green_secs=$(( $(date +%s) - t0 ))
  case "$rc" in
    2) printf '%s\n' "$out" | tail -30
       echo "ROLES-CHECK: INCONCLUSIVE — astro check gave no parseable summary (heap OOM reports 134)" >&2
       exit 2 ;;
    0) echo "ROLES-CHECK: green half ok (${green_secs}s) — baseline accurate with no plant" ;;
    *) printf '%s\n' "$out" | tail -30
       _fail "the ratchet is red BEFORE the plant — the committed baseline is stale (${green_secs}s)" ;;
  esac

  # --- red half: plant the cross-vocabulary comparison ---
  cat > "$SCRATCH" <<'ASTRO'
---
// SCRATCH — planted by .claude/scripts/roles-check.sh --check-gate, removed on exit.
// The bug class this plan exists to kill: a vantage word compared to a rung word.
type Vantage = 'platform' | 'agency' | 'client' | 'end_user';
const viewer: Vantage = 'agency';
const planted = viewer === 'owner';
---
<p>{String(planted)}</p>
ASTRO

  t0=$(date +%s)
  set +e; _run_ratchet; rc=$?; out="$(cat "$RATCHET_LOG")"; set -e
  red_secs=$(( $(date +%s) - t0 ))
  rm -f "$SCRATCH"

  if [ "$rc" -eq 2 ]; then
    printf '%s\n' "$out" | tail -30
    echo "ROLES-CHECK: INCONCLUSIVE — astro check gave no parseable summary on the red half" >&2
    exit 2
  fi
  [ "$rc" -ne 0 ] \
    || _fail "the planted comparison did NOT turn the gate red (${red_secs}s) — if astro check never globbed $base, retry with ROLES_CHECK_SCRATCH=$WEB/src/pages/__roles_check_scratch.astro"
  grep -qF "$base" <<<"$out" \
    || _fail "the gate went red but no diagnostic names $base — that red is pre-existing, not the plant"
  grep -qF 'ts(2367)' <<<"$out" \
    || _fail "the diagnostic for $base is not a ts(2367) cross-vocabulary comparison"
  grep -qF 'have no overlap' <<<"$out" \
    || _fail "no \"have no overlap\" diagnostic — the planted comparison was not the cause"

  echo "ROLES-CHECK: red half ok (${red_secs}s) — ts(2367) \"have no overlap\" reported at $base"
  echo "ROLES-CHECK: --check-gate pass · $((green_secs + red_secs))s wall (green ${green_secs}s + red ${red_secs}s)"
}

# =============================================================================
# C3 — the authority matrix (--check-decide) and the 503 state (--check-503).
#
# Both run one.ie/web/tests/authority/decide.test.ts, which drives the REAL
# decide() over the fixture tree in tests/authority/fixture-tree.ts. Neither
# check trusts vitest's exit code alone: vitest exits 0 when its include
# allowlist matches nothing, so the suite must also EMIT its receipt line
# ("AUTHORITY-MATRIX: N cells, D deny, U undetermined") and clear the floors.
#
# Each check then demonstrates its own red path by MUTATING THE FIXTURE
# (ROLES_FIXTURE_MUTATE) — never by a hook inside decide.ts, which would be a
# test backdoor shipping in the authority path.
#
#   --check-decide  controls-all-true / rung-owner-always must each break the
#                   suite, proving the deny cells are actually asserted.
#   --check-503     swallow-membership-throw / swallow-controls-throw reproduce
#                   the historical `.catch(() => [])` and must each break the
#                   suite, proving a lookup failure cannot silently become 403.
#
# Floors (a matrix may grow, never shrink):
MATRIX_MIN_CELLS=24
MATRIX_MIN_DENY=12
MATRIX_MIN_UNDETERMINED=3

VITEST="$WEB/node_modules/.bin/vitest"
SUITE="tests/authority/decide.test.ts"
FIXTURE="$WEB/tests/authority/fixture-tree.ts"
RUN_OUT=""
RUN_RC=0

_matrix_preflight() {
  [ -f "$FIXTURE" ] || _fail "no fixture tree at one.ie/web/tests/authority/fixture-tree.ts"
  [ -f "$WEB/$SUITE" ] || _fail "no matrix suite at one.ie/web/$SUITE"
  [ -x "$VITEST" ] || _fail "vitest is not installed in one.ie/web/node_modules (cd one.ie/web && bun install)"
  # The include array is an allowlist; without an entry the suite is never
  # collected AND vitest still exits 0. That would be a fail-open check.
  grep -q "tests/authority/" "$WEB/vitest.config.ts" \
    || _fail "vitest.config.ts include allowlist has no tests/authority entry — the suite would never be collected"
}

# run_matrix <mutation>  -> sets RUN_OUT / RUN_RC
run_matrix() {
  set +e
    # `--reporter=basic` was removed in vitest 3 and is a hard STARTUP error on
  # the installed 4.1.7 ("Failed to load custom Reporter from basic") —
  # measured, so never pass that. `--reporter=default` is required explicitly
  # instead: vitest's implicit reporter (no flag at all) swallows per-test
  # stdout/console.log even with --silent=false, but naming "default" prints
  # it — also measured, on 4.1.7.
  RUN_OUT="$(cd "$WEB" && ROLES_FIXTURE_MUTATE="$1" "$VITEST" run "$SUITE" --silent=false --reporter=default 2>&1)"
  RUN_RC=$?
  set -e
}

# _receipt -> echoes "<cells> <deny> <undetermined>", or nothing when absent.
# Here-string, never a pipe: under pipefail `<producer> | grep -q` returns 141
# on a MATCH when the producer is still writing (recorded 2026-08-04).
_receipt() {
  local line
  line="$(grep -F 'AUTHORITY-MATRIX:' <<<"$RUN_OUT" | tail -1)"
  [ -n "$line" ] || return 0
  sed -E 's/.*AUTHORITY-MATRIX: ([0-9]+) cells, ([0-9]+) deny, ([0-9]+) undetermined.*/\1 \2 \3/' <<<"$line"
}

# _green_half <label> — run unmutated, assert exit 0, receipt present, floors met.
_green_half() {
  local cells deny undet receipt
  run_matrix ""
  if [ "$RUN_RC" -ne 0 ]; then
    printf '%s\n' "$RUN_OUT" | tail -40
    _fail "the authority matrix is RED with no mutation — fix decide.ts or the fixture before trusting $1"
  fi
  receipt="$(_receipt)"
  [ -n "$receipt" ] \
    || _fail "no AUTHORITY-MATRIX receipt in the output — the suite did not execute (vitest exits 0 when the include allowlist matches nothing)"
  read -r cells deny undet <<<"$receipt"
  # sed echoes its input unchanged when the pattern does not match, so a drifted
  # receipt format would sail past the -n test and die on `integer expression
  # expected` instead of naming the cause.
  [[ "$cells" =~ ^[0-9]+$ && "$deny" =~ ^[0-9]+$ && "$undet" =~ ^[0-9]+$ ]] \
    || _fail "malformed AUTHORITY-MATRIX receipt: $receipt"
  [ "$cells" -ge "$MATRIX_MIN_CELLS" ] \
    || _fail "the matrix has $cells cells, floor is $MATRIX_MIN_CELLS"
  [ "$deny" -ge "$MATRIX_MIN_DENY" ] \
    || _fail "the matrix asserts $deny deny cells, floor is $MATRIX_MIN_DENY — an allow-only matrix proves nothing"
  [ "$undet" -ge "$MATRIX_MIN_UNDETERMINED" ] \
    || _fail "the matrix asserts $undet undetermined cells, floor is $MATRIX_MIN_UNDETERMINED"
  echo "ROLES-CHECK: green half ok — $cells cells, $deny deny, $undet undetermined"
}

check_decide() {
  _matrix_preflight
  _green_half --check-decide

  # Red half: if the tree said yes to everything, or every membership came back
  # owner, the deny cells MUST notice. If they don't, they aren't assertions.
  local mut
  for mut in controls-all-true rung-owner-always; do
    run_matrix "$mut"
    if [ "$RUN_RC" -eq 0 ]; then
      printf '%s\n' "$RUN_OUT" | tail -20
      _fail "mutation '$mut' did NOT turn the matrix red — the deny cells are not actually asserted"
    fi
    echo "ROLES-CHECK: red half ok — '$mut' breaks the matrix"
  done
  echo "ROLES-CHECK: --check-decide pass"
}

check_503() {
  _matrix_preflight
  _green_half --check-503

  # Red half: restore the historical `.catch(() => [])` — a failed lookup
  # answering "not a member" instead of "couldn't determine". The 503 cells must
  # go red, and the failure must name 503 (otherwise the red is unrelated).
  local mut
  for mut in swallow-membership-throw swallow-controls-throw; do
    run_matrix "$mut"
    if [ "$RUN_RC" -eq 0 ]; then
      printf '%s\n' "$RUN_OUT" | tail -20
      _fail "mutation '$mut' did NOT turn the matrix red — a swallowed lookup error still reads as a denial and this check cannot see it"
    fi
    # Must match the ASSERTION, not a test NAME: three fixture cells are literally
    # titled "503 ...", so a bare grep for 503 would pass on the labels alone —
    # a presence grep in the one check whose whole identity is 403-vs-503.
    # vitest prints `expected 403 to be 503` for the collapsed status.
    grep -qF 'to be 503' <<<"$RUN_OUT" \
      || _fail "mutation '$mut' went red but no assertion collapsed a 503 into a 403 — that red is unrelated to this check"
    echo "ROLES-CHECK: red half ok — '$mut' collapses 503 into 403 and the matrix catches it"
  done
  echo "ROLES-CHECK: --check-503 pass"
}

# =============================================================================
# C4 — page action floors (--check-floors).
#
# Three legs, each with its own red path:
#
#   1. BEHAVIOUR  tests/authority/page-floors.test.ts drives the REAL guardPage()
#                 over the fixture tree: anonymous / stranger / below-floor
#                 member / at-floor member / ancestor owner, plus a 503 cell per
#                 page. Red path: ROLES_FIXTURE_MUTATE=controls-all-true and
#                 =rung-owner-always must each break it.
#   2. SOURCE     the same suite reads each .astro and asserts it passes that
#                 exact RoleAction to guardPage. Red path:
#                 ROLES_FLOORS_MUTATE=floor-drift, which must break with a
#                 `page-floor:` message — otherwise this leg is a presence grep
#                 and this script's header forbids those.
#   3. LANDING    do-prove's landing rule, red half only: a TRULY anonymous
#                 request to a private page must fail to land on it. The GREEN
#                 half is the demo command's own do-prove call — running it twice
#                 would double a 120s budget.
#
# Leg 3 needs `signed_out=1`, not merely PROVE_NO_SESSION=1. Measured in
# middleware.ts: DEV_SLUG (line 258) assigns locals.slug on any signed-out
# localhost request, and principalFromLocals accepts locals.slug — so a
# session-less run of /u/one/billing RENDERS, and asserting it fails would fail
# for the opposite reason. The `signed_out` cookie (line 234) is the one lever
# that skips every auto-auth path including DEV_SLUG, which makes the caller
# genuinely anonymous and forces the /signin bounce this leg is about.
#
# Same reason `one` is not a negative fixture and `jcoffey`/`vxbmxdeg` are not
# used: those are PRODUCTION accounts (one.ie/web/scripts/fix-jcoffey.ts posts to
# api.one.ie). The rung deny cells live in the fixture tree, where fx-stranger /
# fx-teammate / fx-writer have exactly the null-parent shape the plan wanted.
FLOORS_SUITE="tests/authority/page-floors.test.ts"
FLOOR_MIN_CELLS=72
FLOOR_MIN_DENY=34
FLOOR_MIN_UNDETERMINED=12
FLOOR_MIN_PAGES=14
PROVE_BASE="${PROVE_BASE:-http://localhost:4321}"
FLOOR_PROVE_ROUTE="${FLOOR_PROVE_ROUTE:-/u/one/billing}"

# run_floors <fixture-mutation> <floor-mutation> -> sets RUN_OUT / RUN_RC
run_floors() {
  set +e
  RUN_OUT="$(cd "$WEB" && ROLES_FIXTURE_MUTATE="$1" ROLES_FLOORS_MUTATE="$2" \
    "$VITEST" run "$FLOORS_SUITE" --silent=false --reporter=default 2>&1)"
  RUN_RC=$?
  set -e
}

check_floors() {
  [ -f "$FIXTURE" ] || _fail "no fixture tree at one.ie/web/tests/authority/fixture-tree.ts"
  [ -f "$WEB/$FLOORS_SUITE" ] || _fail "no page-floor matrix at one.ie/web/$FLOORS_SUITE"
  [ -x "$VITEST" ] || _fail "vitest is not installed in one.ie/web/node_modules (cd one.ie/web && bun install)"
  grep -q "tests/authority/" "$WEB/vitest.config.ts" \
    || _fail "vitest.config.ts include allowlist has no tests/authority entry — the suite would never be collected"

  # --- green: unmutated, receipt present, floors met ---
  local line cells deny undet pages
  run_floors "" ""
  if [ "$RUN_RC" -ne 0 ]; then
    printf '%s\n' "$RUN_OUT" | tail -40
    _fail "the page-floor matrix is RED with no mutation — fix the page gates before trusting --check-floors"
  fi
  line="$(grep -F 'PAGE-FLOORS:' <<<"$RUN_OUT" | tail -1)"
  [ -n "$line" ] \
    || _fail "no PAGE-FLOORS receipt in the output — the suite did not execute (vitest exits 0 when the include allowlist matches nothing)"
  read -r cells deny undet pages <<<"$(sed -E 's/.*PAGE-FLOORS: ([0-9]+) cells, ([0-9]+) deny, ([0-9]+) undetermined, ([0-9]+) pages.*/\1 \2 \3 \4/' <<<"$line")"
  [[ "$cells" =~ ^[0-9]+$ && "$deny" =~ ^[0-9]+$ && "$undet" =~ ^[0-9]+$ && "$pages" =~ ^[0-9]+$ ]] \
    || _fail "malformed PAGE-FLOORS receipt: $line"
  [ "$pages" -ge "$FLOOR_MIN_PAGES" ] || _fail "$pages pages carry a floor, floor is $FLOOR_MIN_PAGES"
  [ "$cells" -ge "$FLOOR_MIN_CELLS" ] || _fail "the matrix has $cells cells, floor is $FLOOR_MIN_CELLS"
  [ "$deny" -ge "$FLOOR_MIN_DENY" ] || _fail "the matrix asserts $deny deny cells, floor is $FLOOR_MIN_DENY — an allow-only matrix proves nothing"
  [ "$undet" -ge "$FLOOR_MIN_UNDETERMINED" ] \
    || _fail "the matrix asserts $undet undetermined cells, floor is $FLOOR_MIN_UNDETERMINED — without them 503-not-403 ships unproven at the page"
  echo "ROLES-CHECK: green half ok — $cells cells over $pages pages, $deny deny, $undet undetermined"

  # --- red 1: the tree said yes to everything / every membership came back owner ---
  local mut
  for mut in controls-all-true rung-owner-always; do
    run_floors "$mut" ""
    if [ "$RUN_RC" -eq 0 ]; then
      printf '%s\n' "$RUN_OUT" | tail -20
      _fail "mutation '$mut' did NOT turn the page-floor matrix red — the bounce cells are not actually asserted"
    fi
    echo "ROLES-CHECK: red half ok — '$mut' breaks the page-floor matrix"
  done

  # --- red 2: the table drifts from what the page names ---
  run_floors "" "floor-drift"
  if [ "$RUN_RC" -eq 0 ]; then
    printf '%s\n' "$RUN_OUT" | tail -20
    _fail "'floor-drift' did NOT turn the matrix red — the source check does not read the page, so the floors are unwired"
  fi
  grep -qF 'page-floor:' <<<"$RUN_OUT" \
    || _fail "'floor-drift' went red but no 'page-floor:' assertion fired — that red is unrelated to the source check"
  echo "ROLES-CHECK: red half ok — 'floor-drift' is caught by the source check"

  # --- red 3: a genuinely anonymous caller cannot land on a private page ---
  local out rc
  set +e
  curl -fsS -o /dev/null --max-time 5 "$PROVE_BASE/" 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "ROLES-CHECK: INCONCLUSIVE — no dev server at $PROVE_BASE, so the landing leg could not run (cd one.ie/web && bun run dev)" >&2
    exit 2
  fi
  set +e
  out="$(PROVE_NO_SESSION=1 PROVE_SESSION_COOKIE='signed_out=1' PROVE_BASE_URL="$PROVE_BASE" \
        bash "$ROOT/.claude/scripts/do-prove.sh" --route "$FLOOR_PROVE_ROUTE" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    printf '%s\n' "$out" | tail -20
    _fail "an ANONYMOUS $FLOOR_PROVE_ROUTE scored green — either the gate is not wired or the landing rule is not applying, and every authed page proof is then worthless"
  fi
  grep -qF '/signin' <<<"$out" \
    || _fail "the anonymous run failed but never mentions /signin — that red is not the login-wall landing this leg is about"
  echo "ROLES-CHECK: red half ok — anonymous $FLOOR_PROVE_ROUTE lands on /signin and fails the landing rule"

  echo "ROLES-CHECK: --check-floors pass"
}

# =============================================================================
# C5 — the vantage vocabulary is gone (--check-no-vantage).
#
# Presence greps are not proof (header law), so this check demonstrates its own
# red path the simplest way available for a pure grep with no environment
# dependency: it plants the exact token it's hunting for, asserts the grep
# actually notices, then removes the plant and asserts clean again. No process
# to start, no fixture to mutate — the grep IS the check, so the grep is what
# gets proven.
#
# Tokens: deriveViewer|end_user|workspaceContext\.viewer|lib/viewer. 'agency',
# 'client', 'platform' are excluded — they collide with the billing tier and
# MCP vocabulary; end_user is unique to the vantage enum and unambiguous.
# src/data/promises.json is excluded by extension (generated history —
# legitimately contains the old strings; not a source-code carrier).
VANTAGE_PATTERN='deriveViewer|end_user|workspaceContext\.viewer|lib/viewer'
VANTAGE_PROBE="$WEB/src/lib/.vantage-probe.ts"

_vantage_grep() {
  # tests/authority/ is the C3/C4/C6 regression net: it must document the deleted
  # vantage words (e.g. worldkey.test.ts asserts deny messages never contain them)
  # in order to test their absence elsewhere — self-reference, not resurrection.
  grep -rnE "$VANTAGE_PATTERN" "$WEB/src" "$WEB/tests" \
    --include='*.ts' --include='*.tsx' --include='*.astro' 2>/dev/null \
    | grep -v "$WEB/tests/authority/" || true
}

check_no_vantage() {
  # --- leg 1: the vantage module itself is gone ---
  [ ! -f "$WEB/src/lib/viewer.ts" ] \
    || _fail "one.ie/web/src/lib/viewer.ts still exists — the vantage module was not deleted"
  echo "ROLES-CHECK: leg 1 ok — one.ie/web/src/lib/viewer.ts does not exist"

  rm -f "$VANTAGE_PROBE"
  trap 'rm -f "$VANTAGE_PROBE"' EXIT

  # --- leg 2 (green): no vantage vocabulary left under src or tests ---
  local hits
  hits="$(_vantage_grep)"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits"
    _fail "vantage vocabulary still present — see hits above"
  fi
  echo "ROLES-CHECK: leg 2 ok — no deriveViewer/end_user/workspaceContext.viewer/lib/viewer hits under src or tests"

  # --- red path self-test: plant the token, prove the grep can go red ---
  printf "export const v = 'end_user'\n" > "$VANTAGE_PROBE"
  hits="$(_vantage_grep)"
  rm -f "$VANTAGE_PROBE"
  grep -qF '.vantage-probe.ts' <<<"$hits" \
    || _fail "the red-path self-test did NOT detect a planted end_user token — this check cannot go red, it is a presence claim"
  echo "ROLES-CHECK: red half ok — planted end_user token in .vantage-probe.ts was detected"

  # --- cleanup verification: probe removed, grep clean again ---
  hits="$(_vantage_grep)"
  [ -z "$hits" ] \
    || _fail "the probe was removed but the grep is still non-empty — cleanup failed or a real hit remains"
  echo "ROLES-CHECK: cleanup ok — probe removed, grep clean again"

  echo "ROLES-CHECK: --check-no-vantage pass"
}

# =============================================================================
# C6 — the world key is a principal, the tree is the judge (--check-worldkey).
#
# Replays the original bug report: an agent world-key acting in a workspace it
# legitimately reached was refused with a VANTAGE word compared to a RUNG word.
# The suite drives the REAL decide() with a world-key Principal over the same
# fixture tree C3 built, and asserts the three clauses of the accept:
#
#   1. a key whose actor controls the node succeeds (via controls, or via rung
#      for the membership-only key)
#   2. the same key elsewhere is 403 whose reason NAMES THE NODE and speaks
#      neither vocabulary
#   3. a lookup that could not be read is 503, never 403
#
# It deliberately does NOT build packages/sdk — that build is what makes
# --check-gate cost minutes, and this check has a 60s budget. Nothing on the
# suite's import path reaches the receiver registry: decide.ts -> role-check.ts
# imports the action union TYPE-ONLY, and a type import is erased.
#
# Floors (a matrix may grow, never shrink):
WORLDKEY_MIN_CELLS=10
WORLDKEY_MIN_DENY=5
WORLDKEY_MIN_UNDETERMINED=2

WORLDKEY_SUITE="tests/authority/worldkey.test.ts"

# run_worldkey <mutation>  -> sets RUN_OUT / RUN_RC. Same reporter reasoning as
# run_matrix: --reporter=basic is a hard startup error on vitest 4.1.7, and the
# implicit reporter swallows console.log even with --silent=false.
run_worldkey() {
  set +e
  RUN_OUT="$(cd "$WEB" && ROLES_FIXTURE_MUTATE="$1" "$VITEST" run "$WORLDKEY_SUITE" --silent=false --reporter=default 2>&1)"
  RUN_RC=$?
  set -e
}

check_worldkey() {
  [ -f "$FIXTURE" ] || _fail "no fixture tree at one.ie/web/tests/authority/fixture-tree.ts"
  [ -f "$WEB/$WORLDKEY_SUITE" ] || _fail "no world-key suite at one.ie/web/$WORLDKEY_SUITE"
  [ -x "$VITEST" ] || _fail "vitest is not installed in one.ie/web/node_modules (cd one.ie/web && bun install)"
  grep -q "tests/authority/" "$WEB/vitest.config.ts" \
    || _fail "vitest.config.ts include allowlist has no tests/authority entry — the suite would never be collected"

  local cells deny undet line t0 green_secs

  # --- green half ---
  t0=$(date +%s)
  run_worldkey ""
  green_secs=$(( $(date +%s) - t0 ))
  if [ "$RUN_RC" -ne 0 ]; then
    printf '%s\n' "$RUN_OUT" | tail -40
    _fail "the world-key matrix is RED with no mutation (${green_secs}s) — fix api-auth.ts, decide.ts or the fixture first"
  fi
  # Here-string, never a pipe: under pipefail `<producer> | grep -q` returns 141
  # on a MATCH when the producer is still writing (recorded 2026-08-04).
  line="$(grep -F 'WORLDKEY-MATRIX:' <<<"$RUN_OUT" | tail -1)"
  [ -n "$line" ] \
    || _fail "no WORLDKEY-MATRIX receipt in the output — the suite did not execute (vitest exits 0 when the include allowlist matches nothing)"
  read -r cells deny undet <<<"$(sed -E 's/.*WORLDKEY-MATRIX: ([0-9]+) cells, ([0-9]+) deny, ([0-9]+) undetermined.*/\1 \2 \3/' <<<"$line")"
  [[ "$cells" =~ ^[0-9]+$ && "$deny" =~ ^[0-9]+$ && "$undet" =~ ^[0-9]+$ ]] \
    || _fail "malformed WORLDKEY-MATRIX receipt: $line"
  [ "$cells" -ge "$WORLDKEY_MIN_CELLS" ] || _fail "the world-key matrix has $cells cells, floor is $WORLDKEY_MIN_CELLS"
  [ "$deny" -ge "$WORLDKEY_MIN_DENY" ] \
    || _fail "the world-key matrix asserts $deny deny cells, floor is $WORLDKEY_MIN_DENY — an allow-only matrix proves nothing"
  [ "$undet" -ge "$WORLDKEY_MIN_UNDETERMINED" ] \
    || _fail "the world-key matrix asserts $undet undetermined cells, floor is $WORLDKEY_MIN_UNDETERMINED"
  echo "ROLES-CHECK: green half ok (${green_secs}s) — $cells cells, $deny deny, $undet undetermined"

  # --- red half: mutate the FIXTURE, never the authority path ---
  # controls-all-true: if the tree said yes to every key, the "same key
  # elsewhere" cells MUST notice, or they are not assertions.
  run_worldkey "controls-all-true"
  if [ "$RUN_RC" -eq 0 ]; then
    printf '%s\n' "$RUN_OUT" | tail -20
    _fail "mutation 'controls-all-true' did NOT turn the world-key matrix red — the 'same key elsewhere' cells are not actually asserted"
  fi
  echo "ROLES-CHECK: red half ok — 'controls-all-true' breaks the world-key matrix"

  # swallow-controls-throw: the historical `.catch(() => [])` — an unreadable
  # tree answering "no" instead of "couldn't determine". Match the ASSERTION,
  # not a test NAME: cells are titled "503 ...", so a bare grep for 503 would
  # pass on the labels alone.
  run_worldkey "swallow-controls-throw"
  if [ "$RUN_RC" -eq 0 ]; then
    printf '%s\n' "$RUN_OUT" | tail -20
    _fail "mutation 'swallow-controls-throw' did NOT turn the world-key matrix red — a swallowed lookup error still reads as a denial"
  fi
  grep -qF 'to be 503' <<<"$RUN_OUT" \
    || _fail "mutation 'swallow-controls-throw' went red but no assertion collapsed a 503 into a 403 — that red is unrelated to this check"
  echo "ROLES-CHECK: red half ok — 'swallow-controls-throw' collapses 503 into 403 and the matrix catches it"

  echo "ROLES-CHECK: --check-worldkey pass"
}

# ── C7 · staff = owner of the root ────────────────────────────────────────────
# Four legs. The point is that "platform staff" stops being a bypass consulted
# BEFORE the tree is walked and becomes an ownership row the walk reads — so the
# check must prove (a) the row is what grants, (b) removing it takes the grant
# away, and (c) the flag and the row have not drifted apart.
STAFF_SUITE="tests/authority/staff-root.test.ts"
STAFF_MIGRATION="migrations/0220_staff_root_membership.sql"

run_staff() {
  set +e
  RUN_OUT="$(cd "$WEB" && ROLES_STAFF_MUTATE="$1" \
    "$VITEST" run "$STAFF_SUITE" --silent=false --reporter=default 2>&1)"
  RUN_RC=$?
  set -e
}

check_staff() {
  [ -f "$WEB/$STAFF_MIGRATION" ] || _fail "no root-owners migration at one.ie/web/$STAFF_MIGRATION"
  [ -f "$WEB/$STAFF_SUITE" ]     || _fail "no staff-root suite at one.ie/web/$STAFF_SUITE"
  [ -x "$VITEST" ]               || _fail "vitest is not installed in one.ie/web/node_modules"

  # Leg 1 (source): root ownership is READ BY THE WALK, not by a branch beside it.
  grep -q 'export async function isRootOwner' "$WEB/src/lib/analytics/authz.ts" \
    || _fail "no isRootOwner in analytics/authz.ts — staff authority is not expressed as ownership"
  grep -q 'isRootOwner(callerSlug, db)' "$WEB/src/lib/analytics/authz.ts" \
    || _fail "callerControlsSlug does not consult isRootOwner — the walk cannot answer for staff"
  grep -q 'root_owners' "$WEB/$STAFF_MIGRATION" \
    || _fail "the migration does not create root_owners"

  # Leg 2 (green): the suite passes unmutated.
  run_staff ""
  [ "$RUN_RC" -eq 0 ] || { printf '%s\n' "$RUN_OUT" | tail -20 >&2
    _fail "the staff-root suite is RED with no mutation — fix authz.ts or the suite"; }
  local receipt
  receipt="$(printf '%s\n' "$RUN_OUT" | grep -oE 'STAFF-ROOT cells=[0-9]+ grant-via-root=[0-9]+ deny=[0-9]+' | head -1)"
  [ -n "$receipt" ] || _fail "no STAFF-ROOT receipt — the suite did not execute (vitest exits 0 when the include allowlist matches nothing)"
  local deny; deny="$(printf '%s' "$receipt" | sed -E 's/.*deny=([0-9]+).*/\1/')"
  [ "${deny:-0}" -ge 3 ] || _fail "the staff matrix has only ${deny} deny cells — a staff check that can only say yes is not a check"
  echo "ROLES-CHECK: green half ok — $receipt"

  # Leg 3 (red): take the root row out of the walk and the grant must vanish.
  run_staff "ignore-root"
  [ "$RUN_RC" -ne 0 ] \
    || _fail "'ignore-root' did NOT break the staff matrix — root ownership is not what grants, so this check proves nothing"
  echo "ROLES-CHECK: red half ok — 'ignore-root' removes the grant and the matrix catches it"

  # Leg 4 (drift): the flag is a CACHE now. Report divergence rather than trust it.
  local d1 drift
  d1="$(find "$WEB/.wrangler/state" -name '*.sqlite' 2>/dev/null | head -1)"
  if [ -z "$d1" ] || ! command -v sqlite3 >/dev/null 2>&1; then
    echo "ROLES-CHECK: drift leg INCONCLUSIVE — no local D1 (or no sqlite3); run 'bun run db:migrate:local' to enable it"
  else
    drift="$(sqlite3 "$d1" "SELECT COUNT(*) FROM user WHERE staff_role = 1 AND slug IS NOT NULL AND slug NOT IN (SELECT slug FROM root_owners);" 2>/dev/null || echo unknown)"
    case "$drift" in
      0)       echo "ROLES-CHECK: drift leg ok — every staff_role=1 slug has a root_owners row" ;;
      unknown) echo "ROLES-CHECK: drift leg INCONCLUSIVE — root_owners not migrated locally (bun run db:migrate:local)" ;;
      *)       _fail "cache drift: ${drift} staff_role=1 slug(s) have no root_owners row — the flag and the tree disagree" ;;
    esac
  fi

  echo "ROLES-CHECK: --check-staff pass"
}

# ── C8 · the authority suite is a real gate ───────────────────────────────────
# Two things must hold. (1) WIRING: the suite actually runs inside bun run verify
# — a suite nobody runs is documentation. (2) TEETH: mutating the authority code
# in named, plausible ways breaks it. A suite that survives every mutation is
# asserting nothing, which is the failure this whole plan exists to make
# impossible. Mutations are applied to SOURCE and always restored by a trap, so
# an interrupted run cannot leave the tree patched.
AUTH_SUITES="tests/authority"
DECIDE_SRC="src/lib/decide.ts"
AUTHZ_SRC="src/lib/analytics/authz.ts"

_restore_sources() {
  [ -f "$WEB/$DECIDE_SRC.rolesbak" ] && mv -f "$WEB/$DECIDE_SRC.rolesbak" "$WEB/$DECIDE_SRC"
  [ -f "$WEB/$AUTHZ_SRC.rolesbak" ]  && mv -f "$WEB/$AUTHZ_SRC.rolesbak"  "$WEB/$AUTHZ_SRC"
  return 0
}

run_auth_suites() {
  set +e
  RUN_OUT="$(cd "$WEB" && "$VITEST" run "$AUTH_SUITES" --silent=false --reporter=default 2>&1)"
  RUN_RC=$?
  set -e
}

# mutate <name> — patches source in place; returns 1 if the pattern is absent
# (an unapplied mutation must FAIL the check, never silently score as red).
_mutate() {
  case "$1" in
    swap-403-503)
      grep -q 'status: 403' "$WEB/$DECIDE_SRC" || return 1
      cp "$WEB/$DECIDE_SRC" "$WEB/$DECIDE_SRC.rolesbak"
      sed -i.tmp 's/status: 403,/status: 503,/; s/status: 503,$/status: 403,/' "$WEB/$DECIDE_SRC"
      rm -f "$WEB/$DECIDE_SRC.tmp" ;;
    invert-bind-order)
      grep -q '.bind(targetSlug, callerSlug)' "$WEB/$AUTHZ_SRC" || return 1
      cp "$WEB/$AUTHZ_SRC" "$WEB/$AUTHZ_SRC.rolesbak"
      sed -i.tmp 's/\.bind(targetSlug, callerSlug)/.bind(callerSlug, targetSlug)/' "$WEB/$AUTHZ_SRC"
      rm -f "$WEB/$AUTHZ_SRC.tmp" ;;
    drop-depth-cap)
      grep -q 'a.depth < 16' "$WEB/$AUTHZ_SRC" || return 1
      cp "$WEB/$AUTHZ_SRC" "$WEB/$AUTHZ_SRC.rolesbak"
      sed -i.tmp 's/a\.depth < 16/a.depth < 0/g' "$WEB/$AUTHZ_SRC"
      rm -f "$WEB/$AUTHZ_SRC.tmp" ;;
    *) return 1 ;;
  esac
  return 0
}

check_suite() {
  [ -d "$WEB/$AUTH_SUITES" ] || _fail "no authority suite directory at one.ie/web/$AUTH_SUITES"
  [ -x "$VITEST" ]           || _fail "vitest is not installed in one.ie/web/node_modules"

  # Leg 1 — WIRING: verify must reach the suite.
  grep -q '"verify"' "$WEB/package.json" || _fail "no verify script in one.ie/web/package.json"
  # Read the SCRIPT VALUE with a JSON parser, never a regex over the raw file.
  # `"verify": "[^"]*bun run test` cannot cross an escaped quote, so wrapping
  # verify in gate-run.sh (`-- bash -c \"…\"`, 2026-08-18) turned a live wiring
  # into a false red while `bun run test` sat intact inside the string. Assert
  # what verify DOES, not the shape it is written in.
  node -e '
    const s = require(process.argv[1]).scripts || {}
    const seen = new Set()
    const reaches = (name) => {
      if (seen.has(name)) return false
      seen.add(name)
      const body = s[name]
      if (!body) return false
      if (/\bvitest\b/.test(body)) return true
      // follow `bun run <script>` / `npm run <script>` one hop deeper
      return [...body.matchAll(/\b(?:bun|npm|pnpm|yarn) run ([\w:.-]+)/g)]
        .some((m) => reaches(m[1]))
    }
    process.exit(reaches("verify") ? 0 : 1)
  ' "$WEB/package.json" \
    || _fail "bun run verify does not reach vitest — the authority matrix would never gate anything"
  grep -q "tests/authority" "$WEB/vitest.config.ts" \
    || _fail "vitest.config.ts include allowlist has no tests/authority entry — verify would collect zero authority tests"

  # Leg 2 — GREEN: the suites pass unmutated, and there are enough of them.
  local n; n=$(find "$WEB/$AUTH_SUITES" -name '*.test.ts' | wc -l | tr -d ' ')
  [ "${n:-0}" -ge 3 ] || _fail "only ${n} authority suite(s) — decide, page-floors, world-key and staff-root are all expected"
  run_auth_suites
  [ "$RUN_RC" -eq 0 ] || { printf '%s\n' "$RUN_OUT" | tail -20 >&2
    _fail "the authority suites are RED unmutated — fix them before claiming a gate"; }
  echo "ROLES-CHECK: green half ok — ${n} authority suites pass unmutated"

  # Leg 3 — TEETH: each named mutation must break at least one assertion.
  trap _restore_sources EXIT INT TERM
  local m
  for m in swap-403-503 invert-bind-order drop-depth-cap; do
    _mutate "$m" || { _restore_sources; _fail "mutation '$m' could not be applied — its anchor moved, so this leg proves nothing"; }
    run_auth_suites
    if [ "$RUN_RC" -eq 0 ]; then
      _restore_sources
      _fail "mutation '$m' did NOT break the authority suites — they are not asserting what they claim"
    fi
    _restore_sources
    echo "ROLES-CHECK: red half ok — '$m' breaks the authority suites"
  done
  trap - EXIT INT TERM

  # Leg 4 — the tree is exactly as it was. A mutation check that leaves the
  # source patched would be worse than no check at all.
  run_auth_suites
  [ "$RUN_RC" -eq 0 ] || _fail "sources were not restored cleanly after mutation — the tree is dirty"
  echo "ROLES-CHECK: restore ok — suites green again, tree unpatched"

  echo "ROLES-CHECK: --check-suite pass"
}

# ── C9 · the docs no longer teach a vocabulary that does not exist ────────────
# A doc that describes a deleted type is worse than a missing doc: the next
# reader writes code against it. This check reads the DOCS for live claims, and
# proves itself by planting one.
DOCS_ORACLE="text/roles-vantage-collapse-docs.md"
# Files that legitimately keep the dead words as HISTORY (struck through, or in
# a "retired/was" sentence). Everything else must be clean.
# Two kinds of file legitimately keep the dead words:
#   (a) this plan's own family + the design doc that marks the model retired;
#   (b) APPEND-ONLY RECORDS of what was true at the time — a learnings line, an
#       improvements entry, a closed cycle's todo, a generated concatenation.
#       Rewriting those would be falsifying a log, not reconciling a doc.
# Everything else must be reconciled. Adding a row here is a deliberate act:
# it says "this file is a record", and a file that actually TEACHES belongs
# outside the list.
DOC_HISTORY="text/roles-vantage-collapse.md text/roles-vantage-collapse-plan.md text/roles-vantage-collapse-todo.md text/roles-vantage-collapse-docs.md text/roles-authority-plan.md text/learnings.md text/improvements.md text/roles-todo.md text/improve/02-agency.md text/all.md text/routing-plan.md text/security-surfaces.md"

# What counts as a LIVE CLAIM — deliberately narrow, and the narrowness is the
# point. Three earlier drafts of this scan were too blunt and would have forced
# 11 unrelated rewrites:
#   `viewer`   is an English word AND a rung — never searched.
#   `end_user` is ALSO a persona word (`creator | developer | end_user`,
#              text/ui.md · text/workspaces-plan.md) — searching it bare flags
#              docs that never described the vantage at all.
# So match only what genuinely no longer exists: the two identifiers, and the
# 4-value union written out as a type. A checker that cries wolf gets disabled,
# and a disabled checker is the failure this whole plan is about.
# Kept deliberately simple. An earlier draft alternated on quoted forms of the
# union ("platform" | "agency" and its single-quoted twin) and the shell quoting
# produced an INVALID ERE — grep then errored, `2>/dev/null` swallowed the
# error, and the scan reported zero hits. A silent-empty scan is a green light
# that means nothing, which is precisely the defect class this plan exists to
# remove. Three unambiguous needles beat one clever pattern.
DEAD_IDENTIFIERS='deriveViewer|workspaceContext\.viewer|platform/agency/client/end_user'

_docs_live_claims() {
  local f rel
  # Line-delimited, NOT `-Z`. Two traps here, both hit:
  #   1. `for f in $(grep -rl …)` word-splits `text/navigation-plan 1.md` into
  #      two nonexistent paths, so the check reports phantom files.
  #   2. The fix for (1) is normally `grep -Z` + `read -d ''` — but the grep on
  #      PATH here is **ugrep**, where `-Z` means FUZZY MATCH, not `--null`.
  #      Output stayed newline-separated, `read -d ''` hit EOF with no delimiter,
  #      the loop body never ran once, and the scan reported a clean tree.
  #      Another silently-empty green.
  # `IFS= read -r` per line handles the space correctly; no doc here has a
  # newline in its name.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$ROOT/"}"
    case " $DOC_HISTORY " in *" $rel "*) continue ;; esac
    # STRUCTURAL history — a class of file, not a name on a list, so the rule
    # cannot rot as files are added. A closed cycle's todo, an archived doc and
    # a generated concatenation are all append-only RECORDS of what was true at
    # the time; editing them would falsify a log rather than reconcile a doc.
    case "$rel" in
      *-todo.md|text/archive/*|text/improve/*|text/all.md) continue ;;
    esac
    # A doc that carries the retirement banner has been reconciled — it names
    # the deleted thing precisely so the next reader is not misled by it.
    # `grep … && continue` is NOT set -e safe here: when grep finds nothing the
    # && list evaluates non-zero and the shell exits mid-scan, silently
    # truncating the result to whatever it had. An if-block keeps the loop alive.
    if grep -qE 'RETIRED|DELETED 2026-08-04|STALE on the viewer model' "$f"; then
      continue
    fi
    echo "$rel"
  done < <(grep -rlE "$DEAD_IDENTIFIERS" "$ROOT/text" --include="*.md" 2>/dev/null)
}

check_docs() {
  [ -f "$ROOT/$DOCS_ORACLE" ] || _fail "no acceptance oracle at $DOCS_ORACLE"

  # Leg 1 — the oracle states the contract this plan is about.
  grep -qiE "couldn.t determine|503" "$ROOT/$DOCS_ORACLE" \
    || _fail "$DOCS_ORACLE does not state the three-state decision contract"
  grep -qE 'controls\(' "$ROOT/$DOCS_ORACLE" \
    || _fail "$DOCS_ORACLE does not name controls() — the question the whole model reduces to"

  # Leg 2 — the design doc marks the vantage RETIRED with a migration target,
  # rather than still presenting it as the current model.
  grep -qiE 'RETIRED|deleted' "$ROOT/text/roles-authority-plan.md" \
    || _fail "text/roles-authority-plan.md does not mark the vantage model retired"
  grep -qE 'decide\.ts|roles-vantage-collapse-docs' "$ROOT/text/roles-authority-plan.md" \
    || _fail "text/roles-authority-plan.md marks the model retired but names no migration target"

  # Leg 3 — green: no OTHER doc still teaches the deleted identifiers.
  local live; live="$(_docs_live_claims)"
  [ -z "$live" ] || { printf '%s\n' "$live" >&2
    _fail "doc(s) still teach the deleted vocabulary as current (above) — reconcile or add to DOC_HISTORY"; }
  echo "ROLES-CHECK: green half ok — no doc outside the history set teaches the deleted vocabulary"

  # Leg 4 — red: plant a live claim and prove the scan catches it.
  local plant="$ROOT/text/__roles_check_docs_probe.md"
  trap 'rm -f "$plant"' EXIT INT TERM
  printf '# probe\n\nCall `deriveViewer(session)` and compare `workspaceContext.viewer`.\n' > "$plant"
  live="$(_docs_live_claims)"
  rm -f "$plant"; trap - EXIT INT TERM
  grep -q '__roles_check_docs_probe' <<<"$live" \
    || _fail "the planted stale doc was NOT detected — this scan proves nothing"
  echo "ROLES-CHECK: red half ok — a planted stale doc claim was detected"

  # Leg 5 — the probe is gone and the tree is clean again.
  [ ! -f "$plant" ] || _fail "the doc probe was not removed"
  [ -z "$(_docs_live_claims)" ] || _fail "scan is not clean after the probe — the tree is dirty"
  echo "ROLES-CHECK: cleanup ok — probe removed, scan clean again"

  echo "ROLES-CHECK: --check-docs pass"
}


# =============================================================================
# ONE LADDER — every authority decision goes through the same walk
# (--check-one-ladder).
#
# The bug this exists to prevent, reported live 2026-08-05: an operator asked
# their own chat "what's open on my task board?" and got
#
#     "You're agency here, not an owner/admin — only those can read tasks."
#
# Two failures, both structural, both invisible to every existing check:
#
#   1. A SECOND LADDER. `defineWorkspaceTool` gated 137 tools on `canWalk()`
#      alone — the LAST rung. Where the TypeDB group tree is unseeded that is
#      false for the workspace's own owner, while D1 held the ownership all
#      along. The walk existed in three private copies at the time; an operator
#      was an owner to one surface and a stranger to another.
#   2. A SECOND VOCABULARY. `agency` is the deleted 4-word vantage ladder and
#      `owner/admin` are rungs. --check-no-vantage greps src+tests for vantage
#      TOKENS, but this sentence was assembled at runtime from `viewer.role`, so
#      it passed every check while shipping the exact comparison the
#      roles-vantage-collapse cycle existed to end.
#
# Both legs are red-proofed: a planted violation must be detected, or the check
# is a presence claim rather than a guard.
# =============================================================================

LADDER_PROBE="$ROOT/channels/src/tools/.ladder-probe.ts"

# Any authority gate in channels OUTSIDE the one ladder. substrate.ts DEFINES
# canWalk; authority.ts is the only legitimate caller (rung 4). A `walk(` default
# parameter is the injected-for-tests seam and is matched by name, not by call.
_second_ladder_grep() {
  grep -rn --include=*.ts 'canWalk(' "$ROOT/channels/src" 2>/dev/null \
    | grep -v '^[^:]*/src/authority\.ts:' \
    | grep -v '^[^:]*/src/substrate\.ts:' \
    | grep -v '= canWalk,$' \
    | grep -v '^\s*[^:]*:[0-9]*: *\*' \
    | grep -v '//' \
    || true
}

# A refusal built out of viewer.role — the runtime path --check-no-vantage cannot
# see, because the dead word never appears as a literal.
_vantage_message_grep() {
  grep -rn --include=*.ts -E "viewer[?]?\.role|\\\$\{viewer\.role\}" "$ROOT/channels/src/tools/_contract.ts" "$ROOT/channels/src/authority.ts" 2>/dev/null \
    | grep -vE '^\s*[^:]*:[0-9]*: *(\*|//)' \
    || true
}

check_one_ladder() {
  rm -f "$LADDER_PROBE"
  trap 'rm -f "$LADDER_PROBE"' EXIT

  # --- leg 1: the ladder exists and carries all four rungs ---
  local ladder="$ROOT/channels/src/authority.ts"
  [ -f "$ladder" ] || _fail "channels/src/authority.ts is missing — there is no one ladder to enforce"
  local rung
  for rung in "via: 'self'" "via: 'owner-tree'" "via: 'membership'" "via: 'graph'"; do
    grep -qF "$rung" "$ladder" \
      || _fail "the ladder lost a rung ($rung) — a missing rung is how an owner becomes a stranger"
  done
  grep -q 'minTier' "$ladder" \
    || _fail "the ladder no longer compares against minTier — the policy table is not being consulted"
  echo "ROLES-CHECK: leg 1 ok — authority.ts carries self/owner-tree/membership/graph + the tier comparison"

  # --- leg 2 (green): no second ladder anywhere in channels ---
  local hits
  hits="$(_second_ladder_grep)"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits"
    _fail "canWalk() is gated outside src/authority.ts — that is a SECOND ladder, and it will deny someone the one ladder allows"
  fi
  echo "ROLES-CHECK: leg 2 ok — canWalk is called only by the ladder"

  # --- leg 3 (green): no refusal assembled from the vantage word ---
  hits="$(_vantage_message_grep)"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits"
    _fail "a deny path still reads viewer.role — that is how 'You're agency here, not an owner/admin' shipped"
  fi
  echo "ROLES-CHECK: leg 3 ok — refusals name the workspace and the rung, never the vantage"

  # --- red half A: plant a second ladder, prove leg 2 detects it ---
  printf "import { canWalk } from '../substrate'\nexport const g = (e: never) => canWalk(e, 'a', 'b', 'read_tasks')\n" > "$LADDER_PROBE"
  hits="$(_second_ladder_grep)"
  rm -f "$LADDER_PROBE"
  grep -qF '.ladder-probe.ts' <<<"$hits" \
    || _fail "the red-path self-test did NOT detect a planted second ladder — this check cannot go red"
  echo "ROLES-CHECK: red half A ok — a planted canWalk gate outside the ladder was detected"

  # --- red half B: plant the vantage-shaped refusal, prove leg 3 detects it ---
  local contract="$ROOT/channels/src/tools/_contract.ts"
  cp "$contract" "$contract.bak"
  printf "\nconst _probe = (viewer: { role: string }) => \`You're \${viewer.role} here\`\nvoid _probe\n" >> "$contract"
  hits="$(_vantage_message_grep)"
  mv "$contract.bak" "$contract"
  [ -n "$hits" ] \
    || _fail "the red-path self-test did NOT detect a planted viewer.role refusal — leg 3 is a presence claim"
  echo "ROLES-CHECK: red half B ok — a planted viewer.role refusal was detected"

  # --- cleanup verification ---
  [ -z "$(_second_ladder_grep)" ] && [ -z "$(_vantage_message_grep)" ] \
    || _fail "probes were removed but a grep is still non-empty — cleanup failed or a real hit remains"
  echo "ROLES-CHECK: cleanup ok — both probes removed, both greps clean again"

  echo "ROLES-CHECK: --check-one-ladder pass"
}

case "${1:-}" in
  --check-gate)       check_gate ;;
  --check-decide)     check_decide ;;
  --check-503)        check_503 ;;
  --check-floors)     check_floors ;;
  --check-no-vantage) check_no_vantage ;;
  --check-worldkey)   check_worldkey ;;
  --check-staff)      check_staff ;;
  --check-suite)      check_suite ;;
  --check-docs)       check_docs ;;
  --check-one-ladder) check_one_ladder ;;
  *) echo "usage: roles-check.sh --check-{gate,decide,503,floors,no-vantage,worldkey,staff,suite,docs,one-ladder}" >&2; exit 1 ;;
esac
