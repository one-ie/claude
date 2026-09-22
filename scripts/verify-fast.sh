#!/usr/bin/env bash
# verify-fast.sh — the DEV lane. Run from a package folder (one.ie/web, channels).
#
# Full `bun run verify` is the REVIEW/DEPLOY gate (deploy.sh, /close, --full).
# During a /do cycle we only need: does the code still typecheck, and do the
# tests that actually cover what I touched still pass?
#
#   fast = sdk build + tsc --noEmit + vitest related(<changed>) + PINNED always-run
#
# Three rules learned the hard way:
#   1. EMPTY DIFF ⇒ RUN THE FULL SUITE. Never ⇒ pass. A fast lane that goes
#      green because it selected zero tests is worse than the slow one.
#   2. PINS. `vitest related` follows imports; config/parity/boundary suites
#      import nothing from what they guard (cron-wrangler-parity reads a .toml).
#      Those are always run — ~seconds, and they are the class of gate that
#      historically went dark.
#   3. Everything heavy goes through gate-run.sh (machine governor + load-guard).
#      This was ASSERTED here and false until 2026-09-07: tsc-cached.sh was called
#      outside the governor on purpose (see below), so a typecheck escaped the
#      slot cap entirely. It now takes its own slot internally.
#
# FULL_VERIFY=1 makes this an alias for `bun run verify`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$ROOT/.claude/scripts/gate-run.sh"
FOLDER="$(pwd)"
BASE_REF="${DO_BASE_REF:-main}"

# The deferred-pin ledger. It must NOT live under $ROOT: inside a /do cycle $ROOT
# is .do-worktrees/<slug>, and do-auto.sh --gc deletes that checkout -- so the
# debt would evaporate with the worktree it was owed from, and the
# outstanding-debt-on-main backstop would never see it. A deferral that can
# vanish is a deleted gate wearing a different word, which is the exact thing the
# ledger exists to prevent. Machine-keyed, like the gate locks, the recon cache
# and the test memo, so every worktree and session reads ONE ledger.
DEBT_FILE="${VERIFY_FAST_DEBT_FILE:-${TMPDIR:-/tmp}/one-verify-fast-debt}"

# Pinned suites: run on every fast pass regardless of the diff.
#
# `portable` and `design-dock` were added 2026-09-05, after both went red at the
# ship gate on a change whose fast pass was green. They belong here for the
# reason the whole list exists — they import NOTHING from what they guard:
#
#   astro-portable  reads the pages DIRECTORY. Adding a root `*.astro` puts it in
#                   neither ASTRO_PORTABLE nor ASTRO_NON_PORTABLE, and the new
#                   page then 404s on every tenant host. No import graph reaches
#                   a file that was just created, so `vitest related` cannot ever
#                   select this — the one edit that trips it is invisible to it.
#   design-dock     reads `Layout.astro` and every page as STRINGS, to hold "one
#                   BrandingSection per document". An edit to Layout.astro selects
#                   nothing that imports Layout.astro.
#   render-sites    reads MessageList/ShowcaseMessageList as STRINGS to hold that
#                   both approval states route to the approval card. Added
#                   2026-09-06, after both sites gated on `approval-requested`
#                   alone: the answered card — the whole celebration — was
#                   unreachable through the wire, and the component suite covering
#                   that state was green the entire time, because it handed the
#                   card a state no render site ever passes it.
#   panel-tabs      reads `PanelPanes.tsx` as a STRING to hold that every tab a
#   person-panel    strip can emit resolves to a rendered pane. Both import only
#                   `panels/tabs`, so editing ONLY PanelPanes -- which is where a
#                   pane is DELETED -- selects neither. Measured 2026-09-09:
#                   with `pane('task', …)` removed, all 79 tests passed.
#   ad-flow-panel   reads `pages/ad/index.astro` and `AdFunnel.tsx` as STRINGS.
#                   Same class as design-dock: nothing imports an .astro page.
#
# Deliberately NOT pinned: `page-chat-meta`, which imports everything it guards,
# so `vitest related` already reaches it. A pin for a suite the import graph
# covers is cost with no coverage.
#
# These three cost SECONDS, not the milliseconds the two above cost: measured
# 2026-09-09, 2.34s for 49 tests, most of it `ad-flow-panel.test.tsx` building a
# jsdom to render AdFlowPanel. That is the price of the only check that can see
# a deleted pane, and it is paid on every fast lane.
#
# Cost measured on the run that motivated this: 7ms and 46ms. The failure they
# catch costs an 18-minute deploy gate and a red ship.
#
#   sweep-self-test  shells out to `sweep.sh --self-test`. A .sh file is in no
#                    import graph at all, so `vitest related` can never select
#                    it — not "usually misses", CANNOT. It is the most expensive
#                    pin here (2.4s, minting throwaway git estates) and it buys
#                    the only check on a script that runs `git reset --hard` on
#                    `dev`: a red gate and a conflict must each put the trunk
#                    back where they found it. Deleting the reset line takes it
#                    RED on exactly that assertion — verified, not asserted.
#
#   selftest-        ONE PIN, N WRAPPERS — a PREFIX, not a file. Every
#                    `one.ie/web/tests/unit/scripts/selftest-*.test.ts` shells
#                    out to a shell or node proof and fails when it fails. The
#                    prefix is the mechanism: the next shell proof someone
#                    writes is pinned by DROPPING A FILE HERE, with nothing to
#                    remember and no second edit to this line. Seven today —
#                    factory-rate (13 checks, 7 of them reds) · factory-secret-
#                    gate (29, the commit-time secret door) · do-test-gate (16
#                    injected; see below) · do-promise-lint (11 fixtures) ·
#                    factory-walk (50) · verify-fast --self-test-pins (10) ·
#                    factory-executor-check.mjs (59).
#
#                    Added 2026-09-21. All seven passed the day they were
#                    written and NONE had a wrapper or a pin, so all seven would
#                    have stopped running the moment their authors' sessions
#                    ended — the exact failure `.claude/rules/scripts.md`
#                    § Proofs names. Three separate agents flagged it and none
#                    could fix it, because each was scoped to its own files.
#
#                    ~10s serial, less across forks, and it is the most
#                    expensive entry in this list. It buys the only checks on
#                    the commit-time secret gate, the factory's verdict walk and
#                    the vacuous-vitest gate. `selftest-verify-fast-pins`
#                    asserts BACK: every selftest-* wrapper in that directory
#                    must be matched by some entry of this very line, so a
#                    wrapper written without its pin — or this pin deleted out
#                    from under seven wrappers — goes RED in the full suite
#                    instead of going quiet.
#
#                    NOT `do-test-gate-live.test.ts`, which sits in the same
#                    directory WITHOUT the prefix on purpose. Its half drives
#                    real `bunx vitest` processes, and the cost is NOT the
#                    seconds — measured 2026-09-21 it is 2s with a slot already
#                    held. It is the SLOT: a run that does not inherit one
#                    queues up to GOVERN_QUEUE_WAIT (600s) inside the gate that
#                    runs on every edit — the shape that queued 696s for one
#                    agent that day and expired another at 1500s — and then
#                    exits 3, which a wrapper asserting 0 reads as RED for an
#                    environment reason. So the edit gate takes the half that
#                    can neither queue nor false-red, and the FULL suite — which
#                    already holds a slot — takes the other. Still automatic,
#                    just not on every edit. do-test-gate.sh
#                    § DO_TEST_GATE_NO_LIVE carries the whole account, including
#                    why the skipped half exits 3 and never 0.
PINS_DEFAULT='parity|wrangler|boundary|authority|roles|signals-parity|receivers|portable|design-dock|render-sites|panel-tabs|person-panel|ad-flow-panel|ehc-tone|vantage-a-first|sweep-self-test|incident-ledger|selftest-'
PINS="${VERIFY_FAST_PINS:-$PINS_DEFAULT}"

# THE THREE PINS NO NARROWING MAY DROP. Read the paragraph above: `portable`,
# `design-dock` and `render-sites` are here because each has a DATED CATCH — a
# change whose fast pass was green and whose ship gate was red (2026-09-05,
# 2026-09-05, 2026-09-06) — and because the edit that trips each one (a new root
# `*.astro`, an edit to `Layout.astro`, an edit to a render site) is invisible to
# `vitest related` by construction. They also cost milliseconds: 7ms and 46ms
# measured, against the 2.34s and 2.4s the panel/sweep pins cost. So the tier
# narrowing below still buys back the SECONDS it was written for; it just stops
# selling the three cheapest catches to do it.
#
# It was selling them. Until 2026-09-21 `tier=PATCH` set the pin list to exactly
# `(parity boundary)`. On a `do/<slug>` branch that is harmless because the pins
# are DEFERRED whole and the close gate pays them. Every other branch reaches the
# narrowing — including `feat/task-*`, which is EVERY factory branch
# (`.claude/workflows/factory-executor.js`: `branch feat/${slugFor(t.tid)}`) —
# and on those nothing ever pays: the three were dropped silently, forever, on
# precisely the tier (a doc line, a copy edit, a new page) whose most likely
# breakage is a root `*.astro` that `astro-portable` is the only check for.
#
# `selftest-` joined them on 2026-09-22, for the same reason measured a fourth
# time. Every `selftest-*.test.ts` wraps a SHELL proof, and a `.sh` is in no
# import graph — `vitest related` can never select one, by construction. So on a
# PATCH-tier non-`do/` branch the narrowing was the whole difference between
# those proofs running and not running at all, with nothing later to pay them.
# What that bought, concretely: `selftest-do-test-gate.test.ts` carries
# `expectMirrored("do-test-gate.sh")`, the only lane-level check that
# packages/claude ships what .claude says. Drift the mirror and touch nothing
# under .claude/scripts and a PATCH branch went green on a plugin that no longer
# matches canon — and packages/claude has no build step, so nothing else notices.
PINS_UNNARROWABLE=(portable design-dock render-sites selftest-)

# _pins_all_forced <branch> — true when this run must take the WHOLE pin set.
# Two ways in: the operator asked (VERIFY_FAST_PINS_ALL=1), or an outstanding
# debt is sitting on a non-do branch, which means a plan landed without ever
# reaching its close gate. A deferral that can be forgotten is a deleted gate
# wearing a different word, so the debt is paid the moment it is seen.
_pins_all_forced() {
  local _b="${1:-}"
  if [ "${VERIFY_FAST_PINS_ALL:-0}" = "1" ]; then return 0; fi
  if [ -f "$DEBT_FILE" ] && { [ -z "$_b" ] || [ "${_b#do/}" = "$_b" ]; }; then return 0; fi
  return 1
}

# _pins_deferred <branch> — true when this branch's pins are OWED to a later gate
# rather than run now. Only a `do/<slug>` branch has a later gate to owe them to.
_pins_deferred() {
  local _b="${1:-}"
  if _pins_all_forced "$_b"; then return 1; fi
  if [ -n "$_b" ] && [ "${_b#do/}" != "$_b" ]; then return 0; fi
  return 1
}

# _pin_set <branch> <tier> — the pins that will actually run, space-separated on
# one line. The ONE definition of the narrowing: the live lane below and
# --self-test-pins both read it, so the assertion cannot drift from the code.
_pin_set() {
  local _b="${1:-}" _t="${2:-UNKNOWN}"
  local _p=()
  IFS='|' read -r -a _p <<< "$PINS"
  if ! _pins_all_forced "$_b" && [ "$_t" = "PATCH" ]; then
    _p=(parity boundary "${PINS_UNNARROWABLE[@]}")
  fi
  printf '%s\n' "${_p[*]}"
}

# --- --self-test-pins ---------------------------------------------------------
# Asserts the resulting pin set for BOTH branch shapes, because the bug was not
# in either one alone — it was in the pair. Dispatched HERE, above the manifest
# step and the FULL_VERIFY branch, so the proof is a pure decision and can never
# go red for a reason that is not the decision.
#
# It carries its own negative control. An assertion that passes before and after
# the fix is not an assertion, so the pre-fix narrowing — literally `(parity
# boundary)` — is run through the same containment check and MUST fail it.
_self_test_pins() {
  local _fail=0 _got
  # never the machine-wide ledger: this test decides what the debt file says.
  DEBT_FILE="${TMPDIR:-/tmp}/one-verify-fast-selftest-debt.$$"
  rm -f "$DEBT_FILE"
  PINS="$PINS_DEFAULT"
  VERIFY_FAST_PINS_ALL=0

  _st() { # _st <label> <expected> <actual>
    if [ "$2" = "$3" ]; then
      echo "  ok   $1"
    else
      echo "  FAIL $1" >&2
      echo "         expected: $2" >&2
      echo "         actual:   $3" >&2
      _fail=1
    fi
  }
  _plan() { # _plan <branch> <tier> -> DEFERRED | the pin set
    if _pins_deferred "$1"; then echo "DEFERRED"; else _pin_set "$1" "$2"; fi
  }
  _missing() { # _missing "<set>" -> the unnarrowable pins absent from it
    local _k _m=""
    for _k in "${PINS_UNNARROWABLE[@]}"; do
      case " $1 " in *" $_k "*) ;; *) _m="${_m:+$_m }$_k" ;; esac
    done
    echo "$_m"
  }

  echo "[verify-fast] --self-test-pins"

  # 1. the do/<slug> shape: pins deferred WHOLE, and the close gate pays them.
  _st "do/<slug> PATCH defers the pins" \
      "DEFERRED" "$(_plan do/some-plan PATCH)"
  _st "do/<slug> FIX defers the pins" \
      "DEFERRED" "$(_plan do/some-plan FIX)"

  # 2. the feat/task-* shape — EVERY factory branch. Nothing pays later, so the
  #    four with dated catches must still be in the set. This is the rung.
  _got="$(_plan feat/task-01a07591 PATCH)"
  _st "feat/task-* PATCH keeps the four pins with dated catches" \
      "" "$(_missing "$_got")"
  _st "feat/task-* PATCH narrows to the core plus those four" \
      "parity boundary portable design-dock render-sites selftest-" "$_got"

  # 3. NEGATIVE CONTROL. The pre-fix narrowing must FAIL check 2 — otherwise
  #    check 2 is decoration that passes whatever the code does.
  _st "the pre-fix narrowing (parity boundary) FAILS that same check" \
      "portable design-dock render-sites selftest-" "$(_missing "parity boundary")"

  # 4. non-PATCH tiers are untouched. The dev lane every cycle runs is this one;
  #    narrowing more than PATCH would be a silent cut nobody asked for.
  _st "feat/task-* FIX runs the whole pin set" \
      "${PINS_DEFAULT//|/ }" "$(_plan feat/task-01a07591 FIX)"
  _st "an UNKNOWN tier runs the whole pin set (default UP)" \
      "${PINS_DEFAULT//|/ }" "$(_plan feat/task-01a07591 UNKNOWN)"

  # 5. an outstanding debt on a non-do branch is paid in full, PATCH or not.
  : > "$DEBT_FILE"
  _st "outstanding debt on dev pays the whole set even at PATCH" \
      "${PINS_DEFAULT//|/ }" "$(_plan dev PATCH)"
  _st "outstanding debt does NOT un-defer a do/<slug> branch" \
      "DEFERRED" "$(_plan do/some-plan PATCH)"
  rm -f "$DEBT_FILE"

  # 6. VERIFY_FAST_PINS_ALL=1 still forces everything, on every shape.
  VERIFY_FAST_PINS_ALL=1
  _st "VERIFY_FAST_PINS_ALL=1 forces the whole set on do/<slug>" \
      "${PINS_DEFAULT//|/ }" "$(_plan do/some-plan PATCH)"
  VERIFY_FAST_PINS_ALL=0

  if [ "$_fail" -eq 0 ]; then
    echo "[verify-fast] --self-test-pins PASS"
    return 0
  fi
  echo "[verify-fast] --self-test-pins FAILED" >&2
  return 1
}
if [ "${1:-}" = "--self-test-pins" ]; then
  _self_test_pins
  exit $?
fi

# --print-pins <branch> <tier> — the pin set, space-separated, for a reader that
# is not this script. It exists because one already drifted: the vitest guard
# `tests/unit/factory/tier-parity.test.ts` REGEXED this file for `_pins=(`, the
# variable was renamed to `_p`, the match returned nothing, and its `?? []` read
# that as "no pins" instead of "I could not find the pins". The guard went blind
# and stopped catching the very drift it exists to catch. A reader that shells
# out to the definition cannot drift from it; a reader that greps the source can.
if [ "${1:-}" = "--print-pins" ]; then
  _pin_set "${2:-}" "${3:-UNKNOWN}"
  exit 0
fi

# --- 0. generated-artifact drift ---------------------------------------------
# `blocks-manifest.mjs` builds THREE COMMITTED artifacts from one registry:
#   one.ie/web/src/lib/puck/block-manifest.json        what tooling reads
#   channels/src/generated/block-enum.ts               what the model is told
#   one.ie/web/src/lib/puck/block-schema.generated.ts  what the browser
#                                                      normalises against
# Until 2026-09-09 NOTHING ran it: `grep -c blocks-manifest verify-fast.sh
# deploy.sh` was 0 and 0, and no test shells out to it. Three committed files
# behind an ungated generator are three files that rot silently -- the registry
# moves, the artifacts do not, and the first symptom is a model being told about
# a block the browser cannot render.
#
# IT IS A STEP, NOT A PIN, and that distinction is the entire gate. `PINS` below
# are vitest POSITIONAL SUBSTRING filters. Adding `blocks-manifest` there would
# select zero test files, the other pins would still match, the pinned gate would
# exit 0 -- and `grep -q blocks-manifest .claude/scripts/verify-fast.sh` would be
# TRUE. A green grep over a check that never ran is worse than no gate at all.
#
# It runs BEFORE the FULL_VERIFY branch on purpose: every lane below has an exit
# of its own (FULL_VERIFY exits at the top; an empty selection `exec`s the full
# suite; a do/* branch exits 0 after deferring the pins), so anywhere lower is a
# lane that can skip it. Repo-scoped, not folder-scoped -- one of the three
# artifacts lives in channels/ and one in one.ie/web/, so both folders check both.
#
# NOT wrapped in gate-run.sh: one node process, ~2.5s of CPU. Most of its ~16s
# wall is `bunx tsx` resolving a dependency this repo does not vendor
# (`one.ie/web/node_modules/.bin/tsx` does not exist -- measured 2026-09-09), and
# holding a machine-wide slot through a network round-trip is the anti-pattern
# the tsc-cached note further down records.
#
# Capture-then-branch, per rule 3 at the top of this file: `set -e` would kill the
# script with no message, and `node ... | grep` is the PIPESTATUS scar recorded at
# the vitest call below. `--check` writes `ok (no drift)` to stdout and `drift
# detected` to stderr; both are shown. A rc it cannot explain is still RED --
# an unrun check is not a passing check.
# MEMOISED since 2026-09-09. The raw --check is ~7s WARM (measured 8.19s then
# 6.98s back-to-back on this box), and this lane runs on every edit, so a
# doc-only or test-only cycle was paying 7s for a registry nobody touched.
# blocks-manifest-cached.sh keys on the whole of one.ie/web/src -- a superset
# of the check's declared inputs AND of the three artifacts it compares --
# so any src edit still runs it. Only a PASS is stamped; drift is never
# memoised. deploy.sh Step 0.5 deliberately keeps calling the RAW check: the
# ship gate runs once and should not depend on a stamp. BLOCKS_MANIFEST_FORCE=1
# bypasses the memo; --self-test proves the miss.
_bm_out="$(mktemp)"
set +e
bash "$ROOT/.claude/scripts/blocks-manifest-cached.sh" > "$_bm_out" 2>&1
_bm_rc=$?
set -e
cat "$_bm_out"; rm -f "$_bm_out"
if [ "$_bm_rc" -ne 0 ]; then
  echo "[verify-fast] block manifest DRIFT (or --check could not run) - rc=$_bm_rc" >&2
  echo "[verify-fast] regenerate and commit all three artifacts:" >&2
  echo "[verify-fast]   node .claude/scripts/blocks-manifest.mjs" >&2
  exit 1
fi

if [ "${FULL_VERIFY:-0}" = "1" ]; then
  echo "[verify-fast] FULL_VERIFY=1 — running the full gate"
  # The close gate is where deferred pins come due. The full suite is a superset
  # of every pin, so reaching here GREEN is the payment.
  #
  # Order is load-bearing, and the first version got it wrong: it cleared the
  # ledger and THEN ran the suite, so a RED close wiped the debt on its way to
  # failing and the deferred pins would never run again. Proven wrong by probe,
  # not by reading: a scripted `verify` of `exit 1` cleared the ledger.
  # The debt is settled by a PASS, never by an attempt. `exec` is gone for the
  # same reason -- it replaces the process, leaving no line after the run to
  # settle from. `set -e` is suspended around the run so a red suite reaches the
  # settle logic instead of killing the script first.
  _full_st=0
  set +e
  if jq -e '.scripts.verify' package.json >/dev/null 2>&1; then
    bun run verify; _full_st=$?
  else
    # channels has no `verify` script; its full gate is typecheck + the whole suite.
    bash "$ROOT/.claude/scripts/sdk-build-cached.sh" >/dev/null
    bun run typecheck && bun run test; _full_st=$?
  fi
  set -e
  if [ -f "$DEBT_FILE" ]; then
    if [ "$_full_st" -eq 0 ]; then
      echo "[verify-fast] full gate GREEN — clearing $(wc -l < "$DEBT_FILE" | tr -d ' ') deferred pin run(s)"
      rm -f "$DEBT_FILE"
    else
      echo "[verify-fast] full gate RED — deferred pins stay owed" >&2
    fi
  fi
  exit "$_full_st"
fi

# --- changed files: committed-since-base UNION uncommitted -------------------
# The BASE the committed half of the diff is measured from.
#
# Default `main` is right for a one-off check and wrong for a /do plan. On branch
# do/<slug> the committed term is "everything this PLAN has landed", so cycle 5
# re-selects cycles 1-4's files, cycle 6 re-selects five cycles' worth, and the
# fast lane converges on the full suite exactly as the plan gets long. Measured:
# 23 changed files after 3 commits, growing monotonically.
#
# Those earlier cycles were each verified green when they landed, and the plan's
# LAST cycle takes the full lane anyway (do-engine escalates on final-batch
# membership), so integration is still gated -- once, at the end, instead of once
# per cycle.
#
# The cycle's own edits are UNCOMMITTED at W4 time (W4 verifies, then commits),
# so the uncommitted term below already captures them exactly. Moving the base to
# the previous cycle's commit just stops the committed term re-adding work that
# is already proven. Derived from the commit message do-engine writes -- no
# plumbing, no ref passed through an LLM. Override with VERIFY_FAST_SINCE.
cycle_base=""
if [ -n "${VERIFY_FAST_SINCE:-}" ]; then
  cycle_base="$VERIFY_FAST_SINCE"
elif git rev-parse --git-dir >/dev/null 2>&1; then
  _br="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
  case "$_br" in
    do/*)
      _slug="${_br#do/}"
      # do-engine's W4 prompt asks for `do(<slug>): C<n>`, but the agent writing
      # the commit does not always obey it -- the two live plans wrote
      # `do(lifecycle): C1` and `lifecycle-money C2: ...` respectively. Match
      # either shape, and NEVER fall back to main: falling back is what re-selects
      # the whole plan, which is the thing being fixed. With no boundary commit
      # found, HEAD is the correct base -- every commit on this branch is already
      # verified work, and this cycle's own edits are uncommitted at W4 time.
      cycle_base="$(git -C "$ROOT" log -1 --format=%H \
        --grep="^do(${_slug}): C[0-9]" --grep="^${_slug} C[0-9]" 2>/dev/null || true)"
      [ -n "$cycle_base" ] || cycle_base="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
      ;;
  esac
fi
if [ -n "$cycle_base" ]; then
  BASE_REF="$cycle_base"
  echo "[verify-fast] cycle base ${cycle_base:0:9} (previous cycle) - earlier cycles were verified when they landed; the plan's last cycle takes the full lane"
fi

changed=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  # -C "$ROOT" is load-bearing: run from a subdir, git prints paths relative to
  # CWD, and the repo-relative prefix strip below then matches nothing — which
  # silently drops every fast run into the full-suite fallback.
  mb="$(git -C "$ROOT" merge-base HEAD "$BASE_REF" 2>/dev/null || true)"
  { [ -n "$mb" ] && git -C "$ROOT" diff --name-only "$mb"...HEAD 2>/dev/null || true
    git -C "$ROOT" diff --name-only HEAD 2>/dev/null || true
    git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null || true
  } > /tmp/.vf-changed.$$ || true
  changed="$(sort -u /tmp/.vf-changed.$$ | grep -E '\.(ts|tsx|astro|js|mjs)$' || true)"
  rm -f /tmp/.vf-changed.$$
fi

# Paths are repo-relative; vitest wants them relative to the package folder.
rel="${FOLDER#"$ROOT"/}"
scoped="$(printf '%s\n' "$changed" | sed -n "s#^${rel}/##p" || true)"

echo "[verify-fast] $rel — $(printf '%s\n' "$scoped" | grep -c . || true) changed file(s)"

# --- 1. SDK build (types for tsc) + typecheck --------------------------------
# Generated-but-gitignored inputs tsc resolves as modules. Missing => a wall of
# phantom TS2307s on any tree that has not run dev/build yet.
if [ -f package.json ] && grep -q '"gen:page-modified"' package.json; then
  bun run gen:page-modified >/dev/null || true
fi
# Through the fingerprint cache. The raw build is 2.0s of the 2.6s total
# deterministic cost of a cycle -- 78% -- and on an unchanged src it reproduces
# byte-identical dist (measured: same digest before and after). Skip it.
bash "$ROOT/.claude/scripts/sdk-build-cached.sh" || { echo "[verify-fast] sdk build FAILED" >&2; exit 1; }
# Typecheck through the SHARED fingerprint cache, not a fresh tsc every time.
#
# tsc-cached.sh keys on (folder, tree-fingerprint) using do-reconcile's exact key
# format, so a reconcile and N cycle gates on one unchanged tree cost ONE tsc
# between them instead of N. Measured on a warm tree: 21.6s -> 0.1s.
#
# It was written and proven in isolation and then not wired here, so every /do
# cycle kept paying full price for a typecheck of a tree that had not changed
# since the last cycle typechecked it. Proving an artifact is not the same as
# proving it in place.
#
# It is NOT wrapped in gate-run here, and that is now safe rather than a hole:
# tsc-cached.sh takes its own SLOT internally on a MISS, and takes the folder
# lock only once that slot is held, so a HIT costs nothing and a MISS queues like
# every other gate.
#
# THE ORDER IS THE POINT, and this comment used to argue the other way: it said
# wrapping the call out here "would hold a slot through the up-to-900s lock
# wait". That reasoning is what left tsc-cached taking the LOCK first and the
# SLOT second -- while THIS script always runs inside `gate-run.sh verify-fast`,
# i.e. holding a slot already. Two orders, one cycle, and on 2026-09-13 it
# deadlocked every session on the box three times in ~35 minutes, one of them a
# production release gate (tsc-cached.sh § SLOT BEFORE LOCK).
#
# The trade is real and it is the right way round: a waiter can now burn a slot
# while the lock holder computes. But the holder is ALWAYS computing and ALWAYS
# holds a slot itself, so that wait is bounded by one tsc and ends in a cache HIT
# for the waiter. The old order was bounded by nothing -- it stalled the machine
# until a human found the right process to kill, and killing the LOCK holder did
# not even work.
#
# The comment this replaces said it "must NOT be nested inside another gate-run
# slot -- that is a second lock on the same logical gate". That conflated the
# per-folder dedupe LOCK with the machine-wide SLOT, and it is the instruction
# that kept the typecheck outside the governor. It prints the error
# COUNT on stdout and exits non-zero only when the check could not RUN; an unrun
# check is not a passing check, so both a non-zero exit and a non-zero count fail.
if [ -x "$ROOT/.claude/scripts/tsc-cached.sh" ] && [ "${VERIFY_FAST_TSC_CACHE:-1}" = "1" ]; then
  _tsc_n=$(bash "$ROOT/.claude/scripts/tsc-cached.sh" "$rel") || {
    echo "[verify-fast] typecheck could NOT RUN (tsc-cached) — treating as RED" >&2; exit 1; }
  _tsc_n=$(printf '%s' "$_tsc_n" | tr -d '[:space:]')
  if [ "${_tsc_n:-1}" != "0" ]; then
    echo "[verify-fast] typecheck FAILED — ${_tsc_n} error(s) in $rel" >&2
    exit 1
  fi
  echo "[verify-fast] typecheck: 0 errors (shared fingerprint cache)"
else
  bash "$GATE" typecheck -- bun run typecheck || exit 1
fi

# --- 2. tests ----------------------------------------------------------------
# Tightening the base (above) introduces one way to select nothing that is NOT
# the dangerous one rule 1 guards. On a do/* branch the cycle's edits are normally
# uncommitted at W4 time -- but a W3 that commits its own work leaves both terms
# empty, and rule 1 would then send every cycle to the FULL suite: slower than the
# lane we replaced. The last commit IS that cycle's work, so retry with it before
# concluding nothing changed. Rule 1 still has the final word: if even that is
# empty, nothing was selected and the full suite runs.
if [ -z "$scoped" ] && [ -n "$cycle_base" ]; then
  last="$(git -C "$ROOT" diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E '\.(ts|tsx|astro|js|mjs)$' || true)"
  scoped="$(printf '%s\n' "$last" | sed -n "s#^${rel}/##p" || true)"
  [ -n "$scoped" ] && echo "[verify-fast] cycle edits were already committed - selecting the last commit's $(printf '%s\n' "$scoped" | grep -c . || true) file(s)"
fi

if [ -z "$scoped" ]; then
  echo "[verify-fast] no changed source files in $rel — falling back to the FULL suite"
  exec bash "$GATE" test -- bun run test
fi

# vitest `related` resolves the importers of the changed files.
# Through test-cached.sh: identical inputs (same selection, same file contents,
# same working delta) reuse the recorded PASS instead of re-running. Only passes
# are remembered -- a red gate re-runs every time until it is green.
# shellcheck disable=SC2086
# THE THIRD CASE. Rule 1 covers an empty DIFF. This is an empty SELECTION: the
# diff is non-empty, but `vitest related` resolves no importers, and vitest then
# prints "No test files found" and exits 1. That is a FALSE RED -- it fails the
# cycle for a property of the import graph, not of the code. Measured on
# src/lib/authority.ts, a real file a real cycle edits.
#
# It must not become a pass either; selecting zero tests is exactly the shape
# rule 1 exists to refuse. So an empty selection falls back to the FULL suite,
# the same answer an empty diff gets. Conservative in the safe direction.
# `if cmd | tee` would test TEE's status, not the gate's -- the PIPESTATUS trap
# this repo has a scar for. Capture first, then branch on the real exit code.
# `set -e` is ON: a bare failing command exits the script BEFORE the next line,
# so `cmd; rc=$?` never assigns and the fallback below never runs -- the test gate
# then vanishes silently, which is strictly worse than the false RED being fixed.
# Measured: the run stopped after "typecheck: 0 errors" and printed no test line
# at all. Suspend it around the call, exactly as the FULL_VERIFY branch does.

# --- memo probe: never queue for a slot you do not need ----------------------
# Both test legs below go through test-cached.sh, which reuses a recorded PASS.
# But the SLOT was taken first and the memo consulted second, so a hit still
# waited in the governor queue. Measured 2026-09-09 on a saturated box: a single
# acquisition queued 855s and 1324s -- for work that, on a hit, is a stat() of a
# stamp file. A hit needs no memory, no forks and no slot.
#
# _memo_hit asks test-cached.sh itself (TEST_CACHE_PROBE=1, runs nothing, exits 0
# on a hit) so there is exactly ONE definition of what a hit is. On a MISS we
# fall through and take the slot exactly as before -- the gate is never skipped,
# only the WAIT for a gate that had nothing to do.
_memo_hit() {
  TEST_CACHE_PROBE=1 bash "$ROOT/.claude/scripts/test-cached.sh" "$@" >/dev/null 2>&1
}

# --- the gateway suites do not belong in an 8-fork parallel leg -------------
#
# MEASURED 2026-09-21, and it is the reason the fast lane is not fast:
#
#   edit src/lib/world-receivers.ts -> `vitest related` selects 364 test files,
#                                      18 of them `real TypeDB` gateway suites
#   edit src/lib/substrate.ts       -> 596 test files, ALL 25 gateway suites
#
# Two separate defects in one number. 596 of 1447 files is 41% of the suite, so
# on a hub file this leg is not a narrowed selection at all. And `related` runs
# at 8 forks with NO lane split, so every one of those gateway suites bursts a
# single shared TypeDB gateway concurrently — the exact contention test-lanes.sh
# was written to remove, whose signature is recorded there: four runs on an
# UNCHANGED tree giving 8, 12, 13 and 8 DIFFERENT failures. A fast lane that is
# a coin flip on every substrate edit teaches an executor to read red as noise,
# which is how a real red eventually lands.
#
# So the split that the full gate already makes is made here too. The selector is
# the `real TypeDB` marker read from the tree at run time, never a hardcoded list.
#
# IT IS NOT THE SAME SET AS test-lanes.sh, and the first version of this comment
# said it was. Corrected 2026-09-21, measured:
#
#   test-lanes.sh:typedb_files   grep -rl 'real TypeDB' tests --include='*.test.ts'
#                                -> 25 files (the serial lane)
#   here                         grep -rl 'real TypeDB' tests src
#                                     --include='*.test.ts' --include='*.test.tsx'
#                                -> 28 files
#
# The three it adds are `src/lib/resolvers/factory-ladder-live.test.ts`,
# `src/lib/resolvers/learning-evidence.test.ts` and `tests/create-pages.test.tsx`
# — a colocated pair under src/ and one .tsx, all three carrying the marker and
# none of them reachable by a selector that greps only `tests` for `*.test.ts`.
#
# The WIDER set is deliberate here: this leg is the one that bursts, so a marked
# suite the narrow selector misses is exactly the file we least want inside an
# 8-fork run. Deferring three extra files costs a fast pass nothing.
#
# But the divergence itself is a defect and it lives in test-lanes.sh, not here:
# those same three files are marked `real TypeDB` and the full gate runs them in
# the POOL lane at 8 forks — the contention the serial lane exists to remove.
# Widening test-lanes.sh's glob moves BOTH lane memo keys and changes what the
# pool lane runs, so it is its own change with its own receipt, not a drive-by.
# Filed on the testing board.
#
# THIS IS A DEFERRAL, NOT A DELETION, and it uses the ledger this file already
# has. A skipped gate that nothing records is a deleted gate wearing a different
# word — which is precisely why $DEBT_FILE exists here for the do/* pin case. The
# debt is settled the same way: only a GREEN full gate clears it, and the full
# gate runs these suites properly, serialized, in the typedb lane.
_rel_excl=()
_rel_deferred=0
if [ -d "$ROOT/$rel" ]; then
  while IFS= read -r _f; do
    [ -n "$_f" ] && { _rel_excl+=(--exclude "$_f"); _rel_deferred=$((_rel_deferred+1)); }
  done < <(cd "$ROOT/$rel" && grep -rl 'real TypeDB' tests src --include='*.test.ts' --include='*.test.tsx' 2>/dev/null | sort)
fi
if [ "$_rel_deferred" -gt 0 ]; then
  echo "[verify-fast] related: deferring $_rel_deferred real-TypeDB suite(s) to the full gate's serial lane"
  echo "verify-fast deferred $_rel_deferred typedb suite(s) from the related leg at $(date -u +%FT%TZ)" >> "$DEBT_FILE"
fi

_rel_out="$(mktemp)"
set +e
# The exclusions ride BOTH calls. test-cached.sh keys a PASS on the exact argv,
# so a probe whose args differ from the run's can never hit its own stamp —
# the split-key bug test-full.sh was created to kill, one script over.
if _memo_hit "$rel" -- related --run ${_rel_excl[@]+"${_rel_excl[@]}"} $(printf '%s ' $scoped); then
  echo "[verify-fast] related: cache HIT — no slot taken"
  _rel_rc=0
else
  bash "$GATE" test -- bash "$ROOT/.claude/scripts/test-cached.sh" "$rel" -- related --run ${_rel_excl[@]+"${_rel_excl[@]}"} $(printf '%s ' $scoped) > "$_rel_out" 2>&1
  _rel_rc=$?
fi
set -e
cat "$_rel_out"
if [ "$_rel_rc" -eq 0 ]; then
  :
else
  if grep -q 'No test files found' "$_rel_out"; then
    # An empty SELECTION must never read as a pass, and must not silently exit 1
    # either -- vitest prints "No test files found" and exits 1, which fails the
    # cycle for a property of the import graph rather than of the code.
    #
    # HOW I MISREAD THIS, recorded so the next reader does not repeat it: I first
    # hit the empty selection on src/lib/authority.ts and concluded the file was
    # untested. It is not -- `vitest related` finds 338 test files for it. The
    # empty selection was an ARGUMENT-PASSING bug in the test-cached wrapper,
    # fixed separately (c983c45e2). So this branch is a genuine guard against a
    # state that must not be a pass, NOT evidence that any particular file lacks
    # coverage. Do not infer a coverage gap from reaching here without checking
    # `bunx vitest related --run <file>` directly first.
    #
    # The pins still run, so the gate is not skipped, and the files are named so
    # the condition is visible instead of silent.
    echo "[verify-fast] vitest selected NO test files for these changed files:" >&2
    printf '%s\n' $scoped | sed 's/^/  - /' >&2
    echo "[verify-fast] running the pinned gates only. VERIFY the selection by hand before trusting this:" >&2
    echo "[verify-fast]   bunx vitest related --run <file>   (an empty result here is usually a WRAPPER bug, not a coverage gap)" >&2
    echo "[verify-fast] VERIFY_FAST_UNCOVERED_FULL=1 forces the whole suite instead." >&2
    if [ "${VERIFY_FAST_UNCOVERED_FULL:-0}" = "1" ]; then
      rm -f "$_rel_out"; exec bash "$GATE" test -- bun run test
    fi
    _rel_rc=0
  fi
  if [ "$_rel_rc" -ne 0 ]; then rm -f "$_rel_out"; exit 1; fi
fi
rm -f "$_rel_out"

# Pinned gates that no import graph reaches. vitest positional filters are
# SUBSTRINGS, not a regex — one alternation string matches nothing and exits 1
# ("No test files found"), which reads as a failed gate. Pass one arg per pin.
#
# TIER-GATED, and MEMOISED. The pinned block is 44 files / 420 tests / ~20s and it
# ran on every cycle regardless of the diff -- a six-cycle plan paid it six times
# for a surface that never moved. Two independent cuts, neither of which checks
# less:
#
#   1. tier. do-tier.sh already sizes the change. A PATCH (a doc line, a comment)
#      cannot reach the authority/receivers/parity surface these pins guard, so it
#      does not pay for them. FIX and above run the full pin set, unchanged.
#      DEFAULT UP here, the opposite of do-tier's own default-down: an unknown
#      tier runs ALL the pins. Skipping a gate on a guess is the failure this
#      harness has the most scars from.
#   2. memo. Identical pins over an identical tree reuse the recorded PASS.
#
# VERIFY_FAST_PINS_ALL=1 forces the whole set.
#
# THE TIMING CUT. The pins guard integration surfaces -- parity, boundary,
# authority, receivers. Integration is a property of the FINISHED plan, not of
# cycle 3 of 6. Running them per-cycle was testing at the wrong time: six
# identical answers to a question only the last one can actually decide.
#
# So mid-plan they are DEFERRED, not deleted. The debt is written to
# .verify-fast-debt in the repo root, and the close gate (FULL_VERIFY=1, which
# /close and ./deploy both export) runs the whole suite and clears it. Accuracy
# is MOVED to the moment it matters, never dropped: a plan cannot reach a ship
# gate with the debt outstanding, because the ship gate is the full suite.
#
# The deferral applies ONLY on a do/<slug> branch -- a one-off check on main has
# no later gate to defer to, so it pays now. And an outstanding debt on main means
# a plan landed without ever reaching its close gate: pay it here, immediately.
# A deferral that can be forgotten is a deleted gate wearing a different word.
# The three predicates below are `_pins_all_forced`, `_pins_deferred` and
# `_pin_set`, defined at the top beside PINS_DEFAULT. They are the ONE definition
# of this decision, and `--self-test-pins` asserts THEM — so the proof cannot
# drift from the lane. Read them for the narrowing floor and why it exists.
if [ -f "$DEBT_FILE" ] && { [ -z "${_br:-}" ] || [ "${_br#do/}" = "${_br:-}" ]; }; then
  echo "[verify-fast] outstanding deferred pins from a merged plan — paying now (branch ${_br:-detached})"
fi
if _pins_deferred "${_br:-}"; then
  printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_br" "$rel" >> "$DEBT_FILE"
  echo "[verify-fast] pins DEFERRED to the close gate (branch $_br) — debt recorded in .verify-fast-debt; FULL_VERIFY=1 clears it"
  echo "[verify-fast] PASS (fast lane, pins deferred — full gate runs at /close and ./deploy)"
  exit 0
fi

_tier="$(printf '%s\n' $scoped | sed "s#^#${rel}/#" | bash "$ROOT/.claude/scripts/do-tier.sh" 2>/dev/null | jq -r '.tier // "UNKNOWN"' 2>/dev/null || echo UNKNOWN)"
IFS=' ' read -r -a _pins <<< "$(_pin_set "${_br:-}" "$_tier")"
if ! _pins_all_forced "${_br:-}" && [ "$_tier" = "PATCH" ]; then
  echo "[verify-fast] tier=PATCH — pins narrowed to the core plus the three no import graph reaches: ${_pins[*]} (FIX+ runs all $PINS)"
else
  echo "[verify-fast] tier=$_tier — running the full pin set"
fi
if _memo_hit "$rel" -- run "${_pins[@]}"; then
  echo "[verify-fast] pins: cache HIT — no slot taken"
elif ! bash "$GATE" test -- bash "$ROOT/.claude/scripts/test-cached.sh" "$rel" -- run "${_pins[@]}"; then
  echo "[verify-fast] pinned gate FAILED (pins: ${_pins[*]})" >&2
  exit 1
fi

echo "[verify-fast] PASS (fast lane — full gate still runs at /close and ./deploy)"
