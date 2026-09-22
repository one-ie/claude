#!/usr/bin/env bash
# land.sh — a finished branch into `dev` in one command. `--to main` overrides.
#
#   bash .claude/scripts/land.sh feat/campaign-one
#   bash .claude/scripts/land.sh feat/campaign-one --deploy   # also ship dev
#   bash .claude/scripts/land.sh feat/x --quick               # tsc only, for a saturated box
#   bash .claude/scripts/land.sh feat/x feat/y --deploy        # several, in order
#
# WHY THIS EXISTS: a fleet finishing is not the same as work landing. The branch
# still has to survive the trunk — a branch that was 12/12 green on its own can
# go red the moment it meets main, because main moved. That merge-then-gate step
# was being done by hand, once per fleet, and it is the slow part.
#
# THE ORDER IS THE POINT:
#   1  merge $TRUNK (dev) INTO the branch, in its own worktree     (cheap, isolated)
#   2  run the FAST gate there                                      (the dev-tier gate)
#   3  only then fast-forward $TRUNK                                (dev never breaks)
#   4  optionally ./deploy dev                                      (fast lane again)
# Merging main into the branch first means a conflict or a red gate is discovered
# on the BRANCH, where it costs nothing, instead of on main, where every other
# fleet inherits it.
#
# What it will NOT do: touch production. Promotion to one.ie is `./deploy`, a
# full gate and a human decision. A fast pass is never reported as a full pass.
#
# --- A RED ON THE INTEGRATED TREE HAS THREE OWNERS ---------------------------
# Step 2 gates the branch WITH dev merged in, so a red there can belong to:
#
#   the branch     — red on its own, dev innocent
#   dev            — dev was already red; every branch landing now inherits it
#   the seam       — green alone, green on dev, red TOGETHER (a signature dev
#                    changed, a call the branch added; each side typechecks)
#   (and a fourth that is nobody's: the ENVIRONMENT — the substrate door the
#    real-TypeDB suites need was down at gate time, and eight of those suites
#    refuse to skip by design)
#
# Until 2026-09-12 every one of these printed the same line — "fast gate RED on
# <branch> — not landing it" — which is the wrong owner three ways out of four,
# and a wrong diagnosis is worse than none because it sends the executor to fix
# the wrong tree. Measured that day on feat/agent-page: the first red WAS the
# seam (TS2559 — dev changed authorizeWorkspace's env shape, the branch's
# overview.ts passed the old one; both green alone), the executor fixed it, and
# the NEXT red — same line, same blame — was `fixture write failed (transport:
# fetch failed)` against a local gateway that was not answering; the same suite
# passed 4/4 five minutes later. Two reds, two owners, one message.
#
# So a red is DIAGNOSED, deterministically, from three cheap facts:
#   1. the branch's own typecheck BEFORE the merge — a memo lookup
#      (`tsc-cached.sh --probe`; verify:fast stamps it on every edit), never a
#      compute: `green` or `unknown`
#   2. dev's own typecheck at the sha merged in — the same lookup on dev's tree
#   3. the gate's own output: `error TS` lines, transport failures, assertion
#      failures, and WHICH SIDE of the merge touched each failing file
# and the record (`deploy-runs.json`) carries the verdict as its note, so the
# /deploy page shows why, not just that.
#
# --- THE OTHER DOOR: --pr ----------------------------------------------------
#   bash .claude/scripts/land.sh feat/x --pr        # open/update a PR, do not touch main
#
# `--pr` swaps step 3 for a pull request, and it also SKIPS STEP 1 — deliberately,
# because the two orders answer different questions. Landing merges main into the
# branch first so a conflict is discovered where it costs nothing; a PR wants the
# branch as the author wrote it, so GitHub computes the merge and the diff a
# reviewer reads is what this branch added and nothing else. Merging main in
# first would put trunk's own commits in the PR and make the branch
# non-fast-forwardable at the same time.
#
# So the gate under `--pr` proves LESS than the gate under a land: it says the
# branch is green on its own, not that it survives the trunk. The body says so,
# and reports how far trunk has moved plus whether the merge is clean
# (`git merge-tree`, which computes without mutating anything).
#
# --- --pr --deploy: run it before you propose it ------------------------------
#   bash .claude/scripts/land.sh feat/x --pr --deploy --probe /pricing
#
# The full workflow, in one command and in this order:
#
#   gate (fast lane, in the branch's worktree)
#     → ship THAT WORKTREE to dev.one.ie
#     → prove the routes against dev, with the landing rule
#     → open/update the PR, carrying the dev URL and the probe verdict
#
# The pair used to be refused, and the refusal was right while `--deploy` meant
# "ship main after the fast-forward" — a PR lands nothing, so there was nothing
# to ship. What makes it work now is a property of `deploy-dev.sh`, not a flag:
# it derives its own ROOT from `${BASH_SOURCE[0]}/../..`, so invoking THE
# WORKTREE'S COPY ships the worktree's tree. `$wt/.claude/scripts/deploy-dev.sh`
# puts the BRANCH on dev.one.ie; `$ROOT`'s copy would have put main there and
# called it the branch.
#
# The probe is `do-prove.sh` with both its bases pinned to dev, never curl.
# do-prove carries the LANDING RULE — a route counts only if the run ENDED on
# the path asked for — and deploy-dev.sh's own check is `curl / -> 200`, which
# a redirect to /signin satisfies. Both bases are pinned because do-prove falls
# back to PROVE_PROD_URL (https://one.ie by default) when its dev base does not
# answer: an unreachable dev would otherwise quietly prove PRODUCTION and report
# it as the branch passing. And `PROVE: skipped` exits 0, so the route COUNT is
# read, not the exit code — an unrun probe is not a pass.
#
# dev.one.ie IS ONE SLOT, and it reads and writes production's rows. So this door
# takes exactly one branch: two branches would mean the second overwrites the
# first while the first is still being "tested". It is also why nothing here
# touches production — promotion to one.ie is `./deploy`, a full gate, a human.
#
# The body is `pr-body.sh` — every number derived from git at PR time. Re-running
# is the normal case, not the edge case: an existing open PR is UPDATED, never
# duplicated.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

# TRUNK is what a branch LANDS INTO; PR_BASE is what `dev` is RELEASED into.
# They are deliberately different: branches integrate on dev and main receives a
# pull request (root CLAUDE.md § the loop). Before 2026-09-06 both were `main`,
# so nothing ever advanced dev and it fell behind by construction — 5 commits one
# way, 8 the other, undetected until someone asked.
TRUNK="${LAND_TRUNK:-dev}"
DEPLOY=0 DRY=0 QUICK=0 PR=0 SELF_TEST=0 PR_BASE="main" BRANCHES=() PROBES=()
INTEGRATE=0 INTEGRATE_FULL=0
for a in "$@"; do
  case "$a" in
    --self-test) SELF_TEST=1 ;;
    --deploy) DEPLOY=1 ;;
    --integrate) INTEGRATE=1 ;;
    --full) INTEGRATE_FULL=1 ;;
    --quick) QUICK=1 ;;
    --pr) PR=1 ;;
    --to) LAND_TRUNK_ARG=1 ;;
    --probe) WANT_PROBE=1 ;;
    -n|--dry-run) DRY=1 ;;
    -h|--help) sed -n '2,80p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*) echo "land.sh: unknown flag '$a'" >&2; exit 2 ;;
    *) if [[ "${WANT_PROBE:-0}" == 1 ]]; then PROBES+=("$a"); WANT_PROBE=0;
       elif [[ "${LAND_TRUNK_ARG:-0}" == 1 ]]; then TRUNK="$a"; LAND_TRUNK_ARG=0;
       else BRANCHES+=("$a"); fi ;;
  esac
done
[[ "${WANT_PROBE:-0}" == 1 ]] && { echo "land.sh: --probe needs a route" >&2; exit 2; }
(( ${#BRANCHES[@]} || SELF_TEST )) || { echo "land.sh: name at least one branch" >&2; exit 2; }
# --integrate advances $TRUNK; --pr deliberately advances nothing. Asking for
# both is asking for two different answers to "where does this work go".
if (( INTEGRATE && PR )); then
  echo "land.sh: --integrate and --pr are opposite doors — --integrate advances $TRUNK, --pr advances nothing" >&2
  exit 2
fi
if (( INTEGRATE && QUICK )); then
  echo "land.sh: --quick is a per-branch concession; --integrate already costs ONE gate — run it properly" >&2
  exit 2
fi
# --pr --deploy is the full workflow (gate -> dev -> probe -> PR) and it ships
# the BRANCH's worktree, not main. dev.one.ie is one slot, so it takes one branch:
# with two, the second overwrites the first while the first is being probed.
if (( PR && DEPLOY )) && (( ${#BRANCHES[@]} > 1 )); then
  echo "land.sh: --pr --deploy ships one branch to dev.one.ie — name one, not ${#BRANCHES[@]}" >&2
  exit 2
fi
# --probe only means anything when something was shipped to probe.
if (( ${#PROBES[@]} )) && ! (( PR && DEPLOY )); then
  echo "land.sh: --probe needs --pr --deploy (there is nothing on dev to probe otherwise)" >&2
  exit 2
fi
(( PR )) && ! command -v gh >/dev/null 2>&1 && { echo "land.sh: --pr needs the gh CLI" >&2; exit 2; }

GRN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
[[ -t 1 ]] || { GRN=""; RED=""; YEL=""; DIM=""; OFF=""; }
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s══ %s%s\n' "$DIM" "$*" "$OFF"; }
ok()   { printf '%s  ✓%s %s\n' "$GRN" "$OFF" "$*"; }
bad()  { printf '%s  ✗%s %s\n' "$RED" "$OFF" "$*"; }
warn() { printf '%s  !%s %s\n' "$YEL" "$OFF" "$*"; }

# The worktree that holds a branch — a fleet branch lives in one, and gating
# there keeps the shared main tree free for the next fleet.
worktree_of() {
  git worktree list --porcelain \
    | awk -v b="refs/heads/$1" '/^worktree /{w=$2} /^branch /{if ($2==b) print w}' \
    | head -1
}

LANDED=() FAILED=() LANDED_QUICK=0 PRS=() DEV_NOTE="" DEV_URL="https://dev.one.ie"
BR_T0=0 GATE_T=0 DEV_T=0 PROBE_T=0 PR_T=0; PH=()
# Where $TRUNK is checked out, if anywhere (dev IS, on this box — see step 3).
TRUNK_WT="$(worktree_of "$TRUNK")"

# Per-branch facts the diagnosis reads. Reset at the top of every branch.
pre_sha="" dev_sha="" PRE_TSC="unknown" DEV_TSC="unknown" GW_URL="" GW_HTTP=""
DEV_FILES="" BR_FILES="" DIAG_NOTE=""

# The memo lookup — `green` when this exact tree has a recorded typecheck PASS,
# `unknown` otherwise (never checked, or checked and red: a red is never
# stamped). Never computes: TSC_CACHE_ROOT points MAIN's tsc-cached at another
# checkout, and the key is content, so a stamp made in the branch's worktree by
# its own verify:fast is found here.
_tsc_memo() { # <tree>
  TSC_CACHE_ROOT="$1" bash "$ROOT/.claude/scripts/tsc-cached.sh" --probe one.ie/web 2>/dev/null || echo unknown
}

# Which side of the merge touched a repo-relative path. DEV_FILES is what the
# merge brought in (pre-merge sha..HEAD); BR_FILES is what the branch added
# (dev sha..HEAD). Both computed by git after step 1, so this cannot drift.
_side() { # <repo-relative path>
  local d=0 b=0
  [[ -n "$DEV_FILES" ]] && grep -qxF "$1" <<<"$DEV_FILES" && d=1
  [[ -n "$BR_FILES" ]] && grep -qxF "$1" <<<"$BR_FILES" && b=1
  case "$d$b" in
    11) echo "both sides touched it" ;;
    10) echo "$TRUNK's change" ;;
    01) echo "the branch's file" ;;
    *)  echo "touched by neither side" ;;
  esac
}

# The diagnosis. Reads the gate's own output plus the two memo facts; prints the
# block and sets DIAG_NOTE (one line, for the record). It never changes the
# verdict — the gate is red and the branch is not landing; this says WHOSE red.
_land_diagnose() { # <branch> <gate-log>
  local br="$1" log="$2" ts_n env_n assert_n fails f
  ts_n=$(grep -c 'error TS' "$log" 2>/dev/null || true); ts_n=${ts_n:-0}
  env_n=$(grep -cE 'transport: fetch failed|fixture write failed|ECONNREFUSED|unreachable \(' "$log" 2>/dev/null || true); env_n=${env_n:-0}
  assert_n=$(grep -cE 'AssertionError|expected .* to (be|equal|have|contain|match|throw|deep)' "$log" 2>/dev/null || true); assert_n=${assert_n:-0}
  fails="$(grep -oE 'FAIL +[^ ]+\.test\.[a-z]+' "$log" 2>/dev/null | awk '{print $2}' | sort -u || true)"
  say ""
  say "  ── why the gate is red ──"
  if (( ts_n > 0 )); then
    say "  typecheck: $ts_n error(s) on the INTEGRATED tree"
    say "    branch alone @${pre_sha:-?}  : $PRE_TSC"
    say "    $TRUNK alone    @${dev_sha:-?}  : $DEV_TSC"
    say "    integrated            : $ts_n error(s)"
    grep 'error TS' "$log" | head -3 | sed 's/^/      /'
    for f in $(sed -nE 's/^([^(]+)\([0-9]+,[0-9]+\): error TS.*/\1/p' "$log" | sort -u | head -5); do
      say "      $f — $(_side "one.ie/web/$f")"
    done
    if [[ "$DEV_TSC" == unknown* ]]; then
      warn "$TRUNK's own typecheck is NOT on record at ${dev_sha:-?} — check $TRUNK before blaming $br:"
      say "      TSC_CACHE_ROOT=${TRUNK_WT:-<$TRUNK worktree>} bash .claude/scripts/tsc-cached.sh one.ie/web"
      DIAG_NOTE="typecheck red on the integrated tree; $TRUNK unverified at ${dev_sha:-?}"
    elif [[ "$PRE_TSC" == green ]]; then
      warn "INTEGRATION defect — green alone, green on $TRUNK, red together."
      warn "  $TRUNK brought $(git -C "$wt" rev-list --count "${pre_sha:-HEAD}..HEAD" 2>/dev/null || echo '?') commit(s) touching $(grep -c . <<<"$DEV_FILES" || true) file(s); the error lives in the seam."
      warn "  Fix on $br (in $wt), then re-run: bash .claude/scripts/land.sh $br"
      DIAG_NOTE="integration defect: $ts_n tsc error(s) only when $br and $TRUNK meet"
    else
      warn "$br was NOT typechecked as committed before this land — its own share is unknown."
      warn "  Run verify:fast in $wt first; a memo of that pass is what lets the next land attribute a red."
      DIAG_NOTE="typecheck red; $br unverified alone"
    fi
    return 0
  fi
  if (( env_n > 0 && assert_n == 0 )); then
    say "  ENVIRONMENT: $env_n transport failure(s), 0 assertion failures"
    [[ -n "$fails" ]] && printf '%s\n' "$fails" | sed 's/^/      /'
    if [[ "$GW_HTTP" == "000" ]]; then
      warn "the substrate door $GW_URL was DOWN at pre-flight and the gate could not reach it."
    else
      warn "the substrate door $GW_URL answered at pre-flight (HTTP $GW_HTTP) and dropped during the run — a wrangler reload, or a flip of .env under a running gate."
    fi
    warn "  These suites refuse to skip by design (real TypeDB or red). This is NOT evidence against $br."
    warn "  Bring the gateway back (or point GATEWAY_URL at a live one; \`typedb-env.sh\` flips .env) and re-run: bash .claude/scripts/land.sh $br"
    DIAG_NOTE="environment: substrate $GW_URL unreachable ($env_n transport failure(s), 0 assertions)"
    return 0
  fi
  say "  tests: $assert_n assertion failure(s)"
  for f in $fails; do say "      $f — $(_side "one.ie/web/$f")"; done
  [[ -z "$fails" ]] && say "      (no FAIL line found — read the gate output above)"
  DIAG_NOTE="test red: $(printf '%s' "$fails" | tr '\n' ' ')"
  return 0
}

# The record the /deploy page renders. A RED run is the one most worth a timing —
# a record holding only successes cannot be read for a trend, and the phase that
# refused is exactly what a reader wants to see. It can never change an exit
# status: the whole call is `|| true`.
_land_record() { # <branch> <verdict> [note]
  [[ -x "$ROOT/.claude/scripts/deploy-record.sh" ]] || return 0
  (( DRY )) && return 0
  local door="land"
  (( PR )) && door="$door --pr"
  (( DEPLOY )) && door="$door --deploy"
  local target="$TRUNK"
  (( PR && DEPLOY )) && target="$DEV_URL"
  local -a args=(--door "$door" --branch "$1" --verdict "$2" --target "$target"
                 --sha "$(git -C "$ROOT" rev-parse --short "$1" 2>/dev/null || echo '')"
                 --wall "$(( SECONDS - BR_T0 ))")
  [[ -n "${3:-}" ]] && args+=(--note "$3")
  local p; for p in ${PH[@]+"${PH[@]}"}; do args+=(--phase "$p"); done
  bash "$ROOT/.claude/scripts/deploy-record.sh" "${args[@]}" >/dev/null 2>&1 || true
  # The same nudge deploy.sh prints. This door is where it is cheapest to act
  # on: land runs many times a day, the operator already has the worktrees open,
  # and once the rows are committed on one the message degrades to the very
  # command being typed here — `land.sh <branch>`. Note ROOT is MAIN's tree (run
  # MAIN's copy), so --land itself is refused here; the message says where to go.
  # Never fatal — `|| true`, like the record call above it.
  local pend; pend="$(bash "$ROOT/.claude/scripts/deploy-record.sh" --pending 2>/dev/null)" || true
  [[ -n "$pend" ]] && say "$pend"
  return 0
}

# --self-test — the diagnosis driven with synthetic gate output, including the
# RED half: a log that carries BOTH a transport failure and an assertion must
# not be excused as environment. No gate runs, no branch is touched.
if (( SELF_TEST )); then
  fails=0; _log="$(mktemp)"; wt="$ROOT"
  _case() { # <name> <expected DIAG_NOTE prefix> <expected substring in output>
    # Not `out="$(…)"`: a command substitution is a subshell, and DIAG_NOTE set
    # inside it never reaches this shell — the first cut of this checker failed
    # all seven cases with an empty note for exactly that reason.
    local out; _land_diagnose feat/probe "$_log" > "$_log.out" 2>&1; out="$(cat "$_log.out")"; rm -f "$_log.out"
    if [[ "$DIAG_NOTE" == "$2"* ]] && [[ "$out" == *"$3"* ]]; then echo "ok: $1 → ${DIAG_NOTE%%:*}"
    else echo "FAIL: $1 — note '$DIAG_NOTE', wanted '$2*' and output containing '$3'"; fails=$((fails+1)); fi
  }
  pre_sha=aaaaaaa dev_sha=bbbbbbb
  DEV_FILES="one.ie/web/src/lib/authorize.ts"; BR_FILES="one.ie/web/src/pages/api/agents/[id]/overview.ts"
  printf '%s\n' 'src/pages/api/agents/[id]/overview.ts(59,44): error TS2559: Type X has no properties in common with type Y.' \
    '[verify-fast] typecheck FAILED — 1 error(s) in one.ie/web' > "$_log"
  PRE_TSC=green DEV_TSC=green;   _case "tsc red, both green alone" "integration defect" "the branch's file"
  PRE_TSC=green DEV_TSC=unknown; _case "tsc red, dev not on record" "typecheck red on the integrated tree; dev unverified" "check dev before blaming"
  PRE_TSC=unknown DEV_TSC=green; _case "tsc red, branch never checked" "typecheck red; feat/probe unverified" "NOT typechecked as committed"
  printf '%s\n' 'typedbQuery transport failure: fetch failed' \
    ' FAIL  tests/tasks-bulk.test.ts > tasks:bulk — N rows (real TypeDB)' \
    'Error: fixture write failed (status=0 error=transport: fetch failed) — nothing below proves anything.' > "$_log"
  GW_URL=http://127.0.0.1:8790 GW_HTTP=000; _case "transport red, door down" "environment:" "was DOWN at pre-flight"
  GW_HTTP=404;                              _case "transport red, door dropped" "environment:" "dropped during the run"
  printf '%s\n' ' FAIL  tests/unit/foo.test.ts > foo' 'AssertionError: expected 1 to be 2' > "$_log"
  _case "assertion red" "test red: tests/unit/foo.test.ts" "1 assertion failure"
  # RED PROOF: a transport line next to a real assertion is a test red, not an excuse.
  printf '%s\n' 'typedbQuery transport failure: fetch failed' ' FAIL  tests/unit/foo.test.ts > foo' 'AssertionError: expected 1 to be 2' > "$_log"
  _case "transport + assertion" "test red:" "assertion failure"
  rm -f "$_log"
  [[ "$fails" -eq 0 ]] && { echo "land.sh: self-test PASS"; exit 0; }
  echo "land.sh: self-test FAILED ($fails)"; exit 1
fi

# ── THE TRUNK LOCK ───────────────────────────────────────────────────────────
# Three land.sh runs raced on `dev` on 2026-09-13 and NOTHING landed: 0 of 14
# branches in 32 minutes with every gate GREEN. The shape is a livelock, not a
# slow path — each ~20-minute gate outlived the next session's fast-forward, so
# the ff was refused as "$TRUNK genuinely moved", and the retry inherits exactly
# the same race. More sessions made it strictly worse.
#
# The fix is not to forbid concurrency, it is to SERIALISE the trunk: one lander
# owns $TRUNK at a time and the others queue behind it, so a second session
# lands AFTER the first instead of invalidating it. The primitive already
# existed (gate_lock, lib/govern.sh) — land.sh simply never took it.
#
# Not held under --pr (a PR never advances $TRUNK, so there is nothing to race)
# and not under --dry-run. LAND_LOCK_WAIT bounds the queue; the default is
# generous because waiting is the CHEAP outcome here — the expensive one is a
# gate that runs for 20 minutes and then cannot land.
if (( ! PR && ! DRY )); then
  # shellcheck source=lib/govern.sh
  . "$ROOT/.claude/scripts/lib/govern.sh"
  if ! gate_lock "land-$TRUNK" "${LAND_LOCK_WAIT:-3600}"; then
    echo "land.sh: another land into $TRUNK still holds the lock after ${LAND_LOCK_WAIT:-3600}s." >&2
    echo "land.sh: NOT racing it — a concurrent land is how 0 of 14 branches landed on 2026-09-13." >&2
    exit 1
  fi
  trap 'gate_unlock "land-'"$TRUNK"'"' EXIT
fi

# ── --integrate: N branches, ONE gate ────────────────────────────────────────
# The default path gates each branch in its own worktree: N branches cost N
# gates. On a box whose governor funds ONE slot (the effective cap is
# min(GOVERN_MAX_GATES, what memory funds at ~2300MB each) — measured cap 1 on
# 2026-09-13 with 2GB free), those gates are strictly serial, so 14 branches is
# ~14 × 20min ≈ 5 hours of wall clock to prove a tree nobody will ever ship.
#
# What actually ships is the INTEGRATED tree, and root CLAUDE.md already says
# so: "one gate on the integrated tree also costs one gate, not N." This door
# implements that sentence — merge every named branch into $TRUNK's worktree,
# then gate ONCE. 14× less gate, and it is a STRICTLY STRONGER proof than the
# per-branch lane, which is green on each branch and blind to the defect that
# only exists once they are combined (measured twice on 2026-09-13: five inbox
# suites, then two stale stubs that reached main and blocked the release).
#
# The trade, stated plainly: a red here does not name its branch. That is what
# --no-ff buys back — every branch is one identifiable merge commit, so
# `git revert -m 1 <sha>` backs out a single suspect without disturbing the
# rest. A conflicting branch is SET ASIDE and named, never aborted wholesale:
# one conflict must not cost the other thirteen merges.
if (( INTEGRATE )); then
  step "integrate ${#BRANCHES[@]} branch(es) into $TRUNK — one gate, not ${#BRANCHES[@]}"

  TRUNK_WT="$(git worktree list --porcelain \
    | awk -v b="refs/heads/$TRUNK" '/^worktree /{w=$2} $0=="branch "b{print w; exit}')"
  [[ -n "$TRUNK_WT" ]] || { bad "$TRUNK is not checked out in any worktree — cannot integrate"; exit 2; }
  say "  worktree: $TRUNK_WT"

  # A dirty trunk is the same refusal the ff path makes, and for the same
  # reason: a gate on a tree carrying someone's half-typed file measures that
  # file, not these branches.
  if [[ -n "$(git -C "$TRUNK_WT" status --porcelain --untracked-files=no)" ]]; then
    bad "$TRUNK's worktree has uncommitted TRACKED changes — refusing to integrate onto it"
    git -C "$TRUNK_WT" status --short --untracked-files=no | sed 's/^/    /'
    exit 2
  fi

  MERGED=() CONFLICTED=() ALREADY=()
  for br in "${BRANCHES[@]}"; do
    git show-ref --verify --quiet "refs/heads/$br" || { warn "no such branch: $br"; FAILED+=("$br: missing"); continue; }
    if [[ -z "$(git -C "$TRUNK_WT" rev-list "$TRUNK..$br")" ]]; then
      ok "$br — already in $TRUNK, nothing to merge"; ALREADY+=("$br"); continue
    fi
    if (( DRY )); then say "  [dry] (cd $TRUNK_WT && git merge --no-ff $br)"; MERGED+=("$br"); continue; fi
    if git -C "$TRUNK_WT" merge --no-ff --no-edit "$br" >/dev/null 2>&1; then
      ok "merged $br"; MERGED+=("$br")
    else
      git -C "$TRUNK_WT" merge --abort 2>/dev/null || true
      warn "CONFLICT: $br — set aside, $TRUNK untouched by it"
      CONFLICTED+=("$br"); FAILED+=("$br: conflict")
    fi
  done

  say ""
  say "  merged=${#MERGED[@]}  already-in=${#ALREADY[@]}  conflicted=${#CONFLICTED[@]}"
  (( ${#CONFLICTED[@]} )) && { say "  resolve by hand, then land individually:"; printf '    %s\n' "${CONFLICTED[@]}"; }

  if (( ! ${#MERGED[@]} )); then
    say "  nothing new merged — no gate to run"
    exit $(( ${#CONFLICTED[@]} ? 1 : 0 ))
  fi

  # THE one gate. Run from the PACKAGE dir, never the worktree root: pointed at
  # the root, verify-fast resolves folder=<worktree>, finds 0 changed files,
  # falls back to the full suite, and that fallback dies on a missing "test"
  # script — measured 2026-09-13, and it exited 0 while running no tests at all.
  # And NEVER pipe it: `bun run verify | tail` reports tail's status, which
  # turned a RED lane (`test-lanes: FAILED`) into a reported pass twice in one
  # night. The subshell form below keeps $? honest.
  #
  # A BRANCH CAN MOVE UNDER YOU between the merge and the gate — measured the
  # same night: the fix that unblocked the release was pushed to a branch after
  # this door had already merged it, so $TRUNK carried the merge commit but not
  # the fix. `git merge-base --is-ancestor <br> $TRUNK` is the check; a merge
  # commit's presence proves nothing about a branch's current contents.
  if (( DRY )); then
    (( INTEGRATE_FULL )) && say "  [dry] (cd $TRUNK_WT/one.ie/web && FULL_VERIFY=1 bun run verify)" \
                         || say "  [dry] (cd $TRUNK_WT/one.ie/web && bun run verify:fast)"
  else
    if (( INTEGRATE_FULL )); then
      say "  gate: FULL lane on the integrated tree"
      _gate() ( cd "$TRUNK_WT/one.ie/web" && FULL_VERIFY=1 bash "$ROOT/.claude/scripts/gate-run.sh" verify -- bun run verify )
    else
      say "  gate: FAST lane on the integrated tree (not a full pass)"
      _gate() ( cd "$TRUNK_WT/one.ie/web" && bash "$ROOT/.claude/scripts/gate-run.sh" verify-fast -- bun run verify:fast )
    fi
    if _gate; then
      ok "$TRUNK is GREEN with ${#MERGED[@]} branch(es) integrated"
    else
      bad "$TRUNK is RED with ${#MERGED[@]} branch(es) integrated — the merges are LOCAL, nothing was pushed"
      say "  back one branch out with:  git -C $TRUNK_WT log --merges --oneline -${#MERGED[@]}"
      say "                             git -C $TRUNK_WT revert -m 1 <merge-sha>"
      exit 1
    fi
  fi
  exit $(( ${#CONFLICTED[@]} ? 1 : 0 ))
fi

for br in "${BRANCHES[@]}"; do
  step "land $br"
  BR_T0=$SECONDS; PH=(); GATE_T=0; DEV_T=0; PROBE_T=0; PR_T=0

  git show-ref --verify --quiet "refs/heads/$br" || { bad "no such branch"; FAILED+=("$br: missing"); continue; }

  wt="$(worktree_of "$br")"
  if [[ -z "$wt" ]]; then
    wt="$ROOT/.land-worktrees/${br//\//-}"
    if (( DRY )); then say "  [dry] git worktree add $wt $br"
    else
      git worktree add "$wt" "$br" >/dev/null 2>&1 || { bad "could not check out $br"; FAILED+=("$br: checkout"); continue; }
    fi
  fi
  say "  worktree: $wt"
  pre_sha="" dev_sha="" PRE_TSC="unknown" DEV_TSC="unknown" GW_URL="" GW_HTTP=""
  DEV_FILES="" BR_FILES="" DIAG_NOTE=""

  # 0.9 — what the branch knows about ITSELF before the trunk touches it. A
  # memo lookup, never a compute: every verify:fast in this worktree stamped
  # its typecheck, so a branch gated the way the canon says is `green` here for
  # free. Read again by _land_diagnose if step 2 goes red.
  pre_sha="$(git -C "$wt" rev-parse --short HEAD 2>/dev/null || echo '')"
  dev_sha="$(git rev-parse --short "$TRUNK" 2>/dev/null || echo '')"
  if ! (( DRY )); then
    PRE_TSC="$(_tsc_memo "$wt")"
    if [[ -n "$TRUNK_WT" ]]; then
      DEV_TSC="$(_tsc_memo "$TRUNK_WT")"
      # The memo reflects the worktree's BYTES; uncommitted edits there are in
      # the key. Say so rather than let a neighbour's half-typed file read as dev.
      if [[ -n "$(git -C "$TRUNK_WT" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
        DEV_TSC="$DEV_TSC (worktree has uncommitted edits)"
      fi
    fi
    say "  memo: branch alone @$pre_sha typecheck $PRE_TSC · $TRUNK @$dev_sha typecheck $DEV_TSC"
  fi

  # 1 — main INTO the branch. A conflict surfaces here, not on main.
  # Skipped under --pr: a reviewer must see what this branch added, not what
  # trunk did while it built, and a branch with main merged in is no longer
  # fast-forwardable. `pr-body.sh` reports mergeability without mutating.
  if (( PR )); then say "  ${DIM}step 1 skipped — a PR shows the branch as written${OFF}"
  elif (( DRY )); then say "  [dry] (cd $wt && git merge $TRUNK)"
  else
    if ! ( cd "$wt" && git merge --no-edit "$TRUNK" >/dev/null 2>&1 ); then
      bad "merge conflict with $TRUNK — resolve in $wt"
      ( cd "$wt" && git merge --abort >/dev/null 2>&1 )
      FAILED+=("$br: conflict")
      _land_record "$br" red; continue
    fi
    ok "merged $TRUNK into $br"
    # What each side contributed, by git — read by _side in the diagnosis.
    DEV_FILES="$(git -C "$wt" diff --name-only "$pre_sha" HEAD 2>/dev/null || true)"
    BR_FILES="$(git -C "$wt" diff --name-only "$dev_sha" HEAD 2>/dev/null || true)"
  fi
  if (( PR )) && ! (( DRY )); then
    BR_FILES="$(git -C "$wt" diff --name-only "$(git merge-base "$TRUNK" "$br" 2>/dev/null || echo "$TRUNK")" HEAD 2>/dev/null || true)"
  fi

  # 1.5 — the worktree node_modules trap. A fresh worktree has none, so every
  # gate that resolves through a service package dies on an import and reports a
  # RED gate when nothing is wrong with the code. `bun install` here is NOT the
  # fix: it re-points main's one.ie/web/node_modules/@oneie/sdk at this
  # worktree's dist-less SDK and breaks the shared tree. A symlink to main's
  # already-installed deps is read-only reuse and costs nothing.
  #
  # ENUMERATED FROM THE TREE, not from a list. This started as two hardcoded
  # directories — packages/sdk, then one.ie/web — each added after somebody's
  # branch went falsely red, and on 2026-09-05 it went red a third time for
  # `channels/` and `pay/backend/`: four suites under one.ie/web import
  # `channels/src/tools/pages.ts`, which imports `zod`, which a worktree without
  # channels/node_modules cannot resolve. The gate said `fast gate RED` and the
  # branch it was blaming contained nothing but shell scripts. Asking git for
  # every tracked package.json learns the next service without being told.
  while IFS= read -r pj; do
    d="$(dirname "$pj")"
    [[ "$d" == "." ]] && continue
    [[ -d "$ROOT/$d/node_modules" ]] || continue
    [[ -e "$wt/$d/node_modules" ]] && continue
    if (( DRY )); then say "  [dry] ln -s $ROOT/$d/node_modules $wt/$d/node_modules"
    else
      mkdir -p "$wt/$d"
      ln -s "$ROOT/$d/node_modules" "$wt/$d/node_modules" && ok "linked $d/node_modules (no bun install — that clobbers main)"
    fi
  done < <(git -C "$ROOT" ls-files -- '*package.json' ':!:**/node_modules/**' 2>/dev/null || true)

  # 1.55 — one.ie/web is the one that can be present but INCOMPLETE (a partial
  # install leaves the directory there, so the `-e` test above passes and tsc
  # still fails `File 'astro/tsconfigs/strict' not found`). Repair it by hand.
  if [[ -d "$ROOT/one.ie/web/node_modules/astro/tsconfigs" ]]; then
    webnm="$wt/one.ie/web/node_modules"
    if [[ -e "$webnm" && ! -e "$webnm/astro/tsconfigs/strict.json" ]]; then
      if (( DRY )); then say "  [dry] replace incomplete $webnm with main's"
      else
        rm -rf "$webnm"
        ln -s "$ROOT/one.ie/web/node_modules" "$webnm" && ok "replaced incomplete web node_modules with main's"
      fi
    fi
  fi

  # 1.56 — fleets.json is gitignored generated output. tsc imports it; a worktree
  # that never ran `gen:fleets` fails TS2307 and the land reads as a red gate.
  if [[ -f "$ROOT/one.ie/web/src/data/fleets.json" && ! -e "$wt/one.ie/web/src/data/fleets.json" ]]; then
    if (( DRY )); then say "  [dry] ln fleets.json"
    else ln -s "$ROOT/one.ie/web/src/data/fleets.json" "$wt/one.ie/web/src/data/fleets.json" && ok "linked fleets.json"
    fi
  fi

  # 1.57 — src/lib/generated/ is the same trap one directory over, and it bit a
  # fresh land worktree on 2026-09-05: `page-modified.json` is written by
  # `gen:page-modified` (a step of `verify`, never of a bare checkout), so tsc
  # stopped at TS2307 and the branch read RED with nothing wrong in it.
  #
  # Linking the DIRECTORY does not work and the first attempt at this proved it:
  # `src/lib/generated/` is tracked (it holds `substrate-client.ts`), so the
  # worktree already has the directory and only the gitignored files inside it
  # are missing. `! -e` on the directory is therefore always false, the link
  # never fires, and the gate stays red for a reason nothing in the output names.
  #
  # So ask git which files it IGNORES under that path and link those. That still
  # learns a new generator without this script being told about it — the failure
  # mode of the enumerated approach (1.55, 1.56, each added one file at a time
  # after somebody's branch went falsely red) is what this avoids.
  gendir="one.ie/web/src/lib/generated"
  if [[ -d "$ROOT/$gendir" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      [[ -e "$wt/$rel" ]] && continue
      if (( DRY )); then say "  [dry] ln -s $rel"
      else
        mkdir -p "$(dirname "$wt/$rel")"
        ln -s "$ROOT/$rel" "$wt/$rel" && ok "linked ${rel#one.ie/web/src/lib/} (gen:* output a checkout never has)"
      fi
    done < <(git -C "$ROOT" ls-files --others --ignored --exclude-standard -- "$gendir" 2>/dev/null || true)
  fi

  # 1.6 — the same gap, one layer up: a worktree has no one.ie/web/.env, so
  # GATEWAY_API_KEY is unset and every real-substrate suite SKIPS. A skipped suite
  # is NOT a passing suite — the gate would go green having never run the substrate
  # paths, which is worse than red. Link main's .env so the gate means what it says.
  for envf in one.ie/web/.env channels/.env; do
    if [[ -f "$ROOT/$envf" && ! -e "$wt/$envf" ]]; then
      if (( DRY )); then say "  [dry] ln -s $ROOT/$envf $wt/$envf"
      else ln -s "$ROOT/$envf" "$wt/$envf" && ok "linked $envf (else substrate suites silently skip)"
      fi
    fi
  done

  # 1.7 — the substrate door the real-TypeDB suites will use, resolved the way
  # tests/_env-file.ts resolves it: the shell wins, then one.ie/web/.env, then
  # api.one.ie. Eight suites (tasks-bulk, tasks-depend-cycle, …) refuse to skip
  # by design — real TypeDB or red — so a gateway that is down at gate time
  # reads as a red gate on an innocent branch. One curl, 4s cap; any HTTP
  # answer (401/404 included) proves the door is there — only a transport
  # failure means unreachable, the exact line substrate.ts draws at status 0.
  if ! (( DRY )); then
    GW_URL="${GATEWAY_URL:-$(sed -n 's/^GATEWAY_URL=//p' "$wt/one.ie/web/.env" 2>/dev/null | tail -1 | tr -d "\"'" | tr -d ' ')}"
    GW_URL="${GW_URL:-https://api.one.ie}"
    GW_HTTP="$(curl -s -m 4 -o /dev/null -w '%{http_code}' -X POST "$GW_URL/typedb/query" \
      -H 'content-type: application/json' -d '{}' 2>/dev/null || echo 000)"
    [[ -n "$GW_HTTP" ]] || GW_HTTP=000
    if [[ "$GW_HTTP" == "000" ]]; then
      warn "substrate door $GW_URL is UNREACHABLE — real-TypeDB suites will skip or go red; a red of that shape is named as ENVIRONMENT below, never as $br's"
    else
      ok "substrate door $GW_URL answers (HTTP $GW_HTTP)"
    fi
  fi

  # 2 — the fast gate, in the branch's worktree, through the governor. Output is
  # captured (tee) so a red can be diagnosed from what the gate actually said;
  # the exit code is read from PIPESTATUS, never from tee's.
  if (( DRY )); then
    (( QUICK )) && say "  [dry] (cd $wt/one.ie/web && npx tsc --noEmit)   # --quick" \
                || say "  [dry] (cd $wt/one.ie/web && bun run verify:fast)"
  else
    if (( QUICK )); then
      # --quick: tsc only. It catches type breaks, renames and dead imports —
      # which is most of what a fleet gets wrong — and nothing else. It does NOT
      # catch a logic regression, and it is NOT the fast lane: verify:fast also
      # runs the tests related to the diff plus the pinned config/parity gates
      # that import nothing from what they guard. Use it to move a queue when the
      # box is saturated; never as the last gate before production.
      warn "gate: TYPECHECK ONLY (--quick) — weaker than the fast lane, never a full pass"
      gate_log="$(mktemp)"
      ( cd "$wt/one.ie/web" && bash "$ROOT/.claude/scripts/gate-run.sh" quicktsc -- npx tsc --noEmit ) 2>&1 | tee "$gate_log"
      gate_rc=${PIPESTATUS[0]}
      if [[ "$gate_rc" -ne 0 ]]; then
        bad "typecheck RED on the integrated tree ($br + $TRUNK) — not landing it"
        _land_diagnose "$br" "$gate_log"; rm -f "$gate_log"
        FAILED+=("$br: tsc red")
        PH+=("tsc only:0:$(( SECONDS - BR_T0 )):gate:fail")
        _land_record "$br" red "$DIAG_NOTE"; continue
      fi
      rm -f "$gate_log"
      ok "typecheck green (tests NOT run)"
      LANDED_QUICK=1
    else
    say "  gate: FAST LANE (not a full pass)"
    gate_log="$(mktemp)"
    ( cd "$wt/one.ie/web" && bun run verify:fast ) 2>&1 | tee "$gate_log"
    gate_rc=${PIPESTATUS[0]}
    if [[ "$gate_rc" -ne 0 ]]; then
      bad "fast gate RED on the integrated tree ($br + $TRUNK) — not landing it"
      _land_diagnose "$br" "$gate_log"; rm -f "$gate_log"
      FAILED+=("$br: gate red")
      PH+=("fast gate:0:$(( SECONDS - BR_T0 )):gate:fail")
      _land_record "$br" red "$DIAG_NOTE"; continue
    fi
    rm -f "$gate_log"
    ok "fast gate green"
    fi
    GATE_T=$(( SECONDS - BR_T0 ))
    PH+=("$( (( QUICK )) && printf 'tsc only' || printf 'fast gate' ):0:$GATE_T:gate:pass")
  fi

  # 2.5 — run it before proposing it. Only under `--pr --deploy`: ship THIS
  # WORKTREE to dev.one.ie, then prove the routes there. A PR whose branch has
  # never been executed is a diff, not a proposal.
  if (( PR && DEPLOY )); then
    step "dev.one.ie ← $br"
    if (( DRY )); then
      say "  [dry] (cd $wt && DEV_SKIP_GATE=$(( QUICK ? 0 : 1 )) bash $wt/.claude/scripts/deploy-dev.sh)"
      dry_probe=""
      for r in ${PROBES[@]+"${PROBES[@]}"}; do dry_probe="$dry_probe --route $r"; done
      [[ -n "$dry_probe" ]] || dry_probe=" --route /"
      say "  [dry] PROVE_BASE_URL=$DEV_URL PROVE_PROD_URL=$DEV_URL do-prove.sh$dry_probe"
      DEV_NOTE="$DEV_URL — not run (dry run)"
    else
      # The worktree's OWN copy. $ROOT's would ship main and call it the branch.
      # The gate is skipped here because step 2 just ran it in this same tree —
      # except under --quick, where step 2 ran tsc only and is NOT the fast lane,
      # so deploy-dev.sh must run its own before anything reaches dev.
      if ! ( cd "$wt" && DEV_SKIP_GATE=$(( QUICK ? 0 : 1 )) bash "$wt/.claude/scripts/deploy-dev.sh" ); then
        bad "dev deploy failed for $br — not opening a PR for code that will not ship"
        FAILED+=("$br: dev deploy")
        _land_record "$br" red; continue
      fi
      ok "shipped $br to $DEV_URL"
      DEV_T=$(( SECONDS - BR_T0 - GATE_T ))
      PH+=("ship dev:$GATE_T:$DEV_T:ship:pass")

      # The probe. Both bases pinned to dev: do-prove falls back to
      # PROVE_PROD_URL when its dev base is silent, and an unreachable dev would
      # otherwise prove https://one.ie and report it as this branch passing.
      probe_args=()
      for r in ${PROBES[@]+"${PROBES[@]}"}; do probe_args+=(--route "$r"); done
      (( ${#probe_args[@]} )) || probe_args=(--route /)
      say "  probe: ${probe_args[*]} (landing rule, signed-out)"
      probe_out="$( cd "$wt" && PROVE_BASE_URL="$DEV_URL" PROVE_PROD_URL="$DEV_URL" \
        bash "$wt/.claude/scripts/do-prove.sh" "${probe_args[@]}" 2>&1 )"
      printf '%s\n' "$probe_out" | sed 's/^/    /'
      # Read the ROUTE COUNT, not the exit code: `PROVE: skipped (no reachable
      # environment)` exits 0, and an unrun probe is not a pass.
      proven="$(printf '%s' "$probe_out" | sed -n 's/^PROVE: pass (\([0-9][0-9]*\) route.*/\1/p' | tail -1)"
      if [[ -z "$proven" || "$proven" -lt 1 ]]; then
        bad "probe did not prove a single route on dev — not opening a PR"
        FAILED+=("$br: probe")
        _land_record "$br" red; continue
      fi
      ok "proved $proven route(s) on $DEV_URL"
      PROBE_T=$(( SECONDS - BR_T0 - GATE_T - DEV_T ))
      PH+=("probe dev:$(( GATE_T + DEV_T )):$PROBE_T:probe:pass")
      DEV_NOTE="$DEV_URL — $proven route(s) proven signed-out (landing rule); dev shares production's data"
    fi
  fi

  # 3 — the door. Either main fast-forwards to the branch, or the branch becomes
  # a pull request. Never both: a PR that has already been merged into main is a
  # PR with nothing to review.
  if (( PR )); then
    # The gate label is PASSED to pr-body.sh rather than inferred by it. That
    # script runs no gate and must never imply one; what actually ran is known
    # only here, and --quick has to say out loud that it is weaker.
    gate_label="fast lane (green) — branch only, trunk not merged in"
    (( QUICK )) && gate_label="typecheck only (--quick) — NOT the fast lane, never a full pass"
    (( DRY )) && gate_label="not run (dry run)"

    if (( DRY )); then
      say "  [dry] git push -u origin $br"
      say "  [dry] gh pr create --base $PR_BASE --head $br --title \"$(bash "$ROOT/.claude/scripts/pr-body.sh" "$br" --base "$PR_BASE" --title 2>/dev/null)\""
      say "  [dry] (body from pr-body.sh — $(bash "$ROOT/.claude/scripts/pr-body.sh" "$br" --base "$PR_BASE" 2>/dev/null | wc -l | tr -d ' ') lines${DEV_NOTE:+, + dev line})"
      PRS+=("$br: [dry]")
    else
      if ! git push -u origin "$br" >/dev/null 2>&1; then
        bad "could not push $br to origin"
        FAILED+=("$br: push"); continue
      fi
      ok "pushed $br"

      body_file="$(mktemp)"
      # --dev is passed only when something was actually shipped and probed.
      # pr-body.sh renders no line without it, which is the honest default: a PR
      # silent about dev is a PR whose branch was never run.
      dev_args=()
      [[ -n "$DEV_NOTE" ]] && dev_args=(--dev "$DEV_NOTE")
      bash "$ROOT/.claude/scripts/pr-body.sh" "$br" --base "$PR_BASE" --gate "$gate_label" \
        ${dev_args[@]+"${dev_args[@]}"} > "$body_file" 2>/dev/null
      title="$(bash "$ROOT/.claude/scripts/pr-body.sh" "$br" --base "$PR_BASE" --title 2>/dev/null)"
      [ -s "$body_file" ] || { bad "pr-body.sh produced nothing for $br"; rm -f "$body_file"; FAILED+=("$br: body"); continue; }

      # Idempotent by design. A re-run after "main moved", a second cycle on the
      # same branch, or simply landing twice must UPDATE the open PR — creating
      # is what fails when one already exists, so ask first.
      existing="$(gh pr list --head "$br" --base "$PR_BASE" --state open --json number \
        --jq '.[0].number' 2>/dev/null || true)"
      if [ -n "$existing" ]; then
        if gh pr edit "$existing" --title "$title" --body-file "$body_file" >/dev/null 2>&1; then
          url="$(gh pr view "$existing" --json url --jq .url 2>/dev/null || echo "#$existing")"
          ok "updated PR $url"
          PRS+=("$br: $url (updated)")
        else
          bad "could not update PR #$existing for $br"
          FAILED+=("$br: pr edit")
        fi
      else
        if url="$(gh pr create --base "$PR_BASE" --head "$br" --title "$title" --body-file "$body_file" 2>&1 | tail -1)"; then
          ok "opened PR $url"
          PRS+=("$br: $url")
        else
          bad "could not open a PR for $br: $url"
          FAILED+=("$br: pr create")
        fi
      fi
      rm -f "$body_file"
    fi
    # The PR path returns here, BEFORE the `LANDED+=` record below — so without
    # this line a green `--pr` run recorded nothing and the page showed only the
    # runs that failed. Measured on the first green run of this door: PR #35
    # opened, 768s of real work, and the record stayed empty.
    PR_T=$(( SECONDS - BR_T0 - GATE_T - DEV_T - PROBE_T ))
    PH+=("open PR:$(( GATE_T + DEV_T + PROBE_T )):$PR_T:pr:pass")
    _land_record "$br" green
    continue
  fi

  if (( DRY )); then say "  [dry] advance $TRUNK to $br (in its worktree if it has one, else git fetch .)"
  else
    # Advance $TRUNK WITHOUT MOVING HEAD in the shared tree. Switching HEAD here
    # is what `hook:branch-pin` refuses and the canon forbids: concurrent
    # sessions get pulled onto each other's branches. Two ways to avoid it, and
    # which applies is decided by git, not by taste:
    #   * $TRUNK is checked out in a worktree -> `fetch .` REFUSES it outright
    #     ("refusing to fetch into branch ... checked out at ..."), so
    #     fast-forward inside that worktree instead.
    #   * $TRUNK is checked out nowhere -> there is no worktree to run in, so
    #     move the ref with `fetch .`, which refuses a non-fast-forward exactly
    #     as `merge --ff-only` does.
    # Measured 2026-09-06: dev IS checked out at .claude/worktrees/dev on this
    # box, so the fetch-only version of this failed on its first real use.
    # TRUNK_WT was resolved once, before the loop (worktree_of "$TRUNK").
    # CAPTURE the error, never swallow it. Until 2026-09-09 both forms ended in
    # `>/dev/null 2>&1` and EVERY failure printed "$TRUNK moved", which is the
    # wrong diagnosis most of the time on this box: $TRUNK is checked out in a
    # worktree OTHER SESSIONS EDIT, so a fast-forward is refused whenever one of
    # them holds an uncommitted file this branch also touches. Measured that day
    # — three consecutive lands reported "dev moved" while `dev` was 0 commits
    # behind the branch; the real error was only visible by running the merge by
    # hand:
    #     error: Your local changes to the following files would be overwritten
    #     by merge:  one.ie/web/src/data/deploy-runs.json
    # "moved" sends you to re-run (which fails identically, forever); the truth
    # sends you to one named file. A wrong diagnosis costs more than no
    # diagnosis, because it is actionable in the wrong direction.
    if [[ -n "$TRUNK_WT" ]]; then
      _adv() { git -C "$TRUNK_WT" merge --ff-only "$br" 2>&1; }
    else
      _adv() { git fetch . "$br:$TRUNK" 2>&1; }
    fi
    if ! adv_err="$(_adv)"; then
      # Three causes, and they need three different next moves.
      if [[ "$adv_err" == *"would be overwritten by merge"* || "$adv_err" == *"local changes"* ]]; then
        # Name the files. `git` already listed them; pass them straight through
        # rather than re-deriving, so this cannot drift from what git checked.
        dirty="$(printf '%s\n' "$adv_err" | sed -n 's/^\t//p' | tr '\n' ' ')"
        warn "$TRUNK's worktree ($TRUNK_WT) has UNCOMMITTED changes to: ${dirty:-<see below>}"
        warn "  $TRUNK did NOT move — the fast-forward was refused by a dirty tree."
        warn "  Another session is likely mid-edit there. Do not blanket-restore:"
        warn "  check whether those files' contents are already in $br, and clear"
        warn "  only the paths that are (git checkout -- <path>), never -A."
        FAILED+=("$br: $TRUNK worktree dirty"); continue
      fi
      if [[ "$adv_err" == *"non-fast-forward"* || "$adv_err" == *"Not possible to fast-forward"* || "$adv_err" == *"diverge"* ]]; then
        warn "$TRUNK genuinely moved — merge it in and re-run land.sh for $br"
        FAILED+=("$br: $TRUNK moved"); continue
      fi
      warn "could not advance $TRUNK — git said:"
      printf '%s\n' "$adv_err" | sed 's/^/    /' >&2
      FAILED+=("$br: advance failed"); continue
    fi
    # READ THE REF BACK. A successful --ff-only is not proof the branch is IN
    # main a moment later: several sessions land into one shared tree, and on
    # 2026-09-05 two of these printed "main fast-forwarded to feat/deploy-page"
    # while main's reflog recorded a NEIGHBOUR's branch name at the very sha
    # this script had just reported. Twelve commits sat outside main for an hour
    # and were reported as landed, twice, because the script trusted its own
    # exit code over the ref. `git merge` succeeding is a claim; the branch
    # being an ancestor of main is the fact.
    if ! git merge-base --is-ancestor "$br" "$TRUNK"; then
      bad "$TRUNK does NOT contain $br after a clean fast-forward — a concurrent land overwrote it"
      say "  $TRUNK is now $(git rev-parse --short "$TRUNK"); $br is $(git rev-parse --short "$br")"
      FAILED+=("$br: ff did not hold"); _land_record "$br" red; continue
    fi
    ok "$TRUNK fast-forwarded to $br (verified: $TRUNK contains $(git rev-parse --short "$br"))"
  fi

  LANDED+=("$br")
  _land_record "$br" green
done

# 4 — one dev deploy for the whole batch, not one per branch. Not under --pr:
# that path already shipped the branch's own worktree in step 2.5, and this would
# overwrite it with main — the tree the PR is NOT proposing.
if (( DEPLOY )) && ! (( PR )) && (( ${#LANDED[@]} )); then
  step "deploy dev"
  if (( DRY )); then say "  [dry] bash .claude/scripts/deploy.sh dev"
  else
    bash "$ROOT/.claude/scripts/deploy.sh" dev || { bad "dev deploy failed"; FAILED+=("deploy"); }
  fi
fi

step "report"
(( ${#LANDED[@]} )) && ok "landed: ${LANDED[*]}"
if (( ${#PRS[@]} )); then
  for p in "${PRS[@]}"; do ok "pr: $p"; done
fi
(( LANDED_QUICK )) && warn "typecheck-only gate was used — run the full suite before ./deploy to production"
(( ${#FAILED[@]} )) && bad "failed: ${FAILED[*]}"
# --only dims,feedback is deliberate. A BRANCH NAME is not a plan slug: without
# --tid the task leg resolves by the `slug:` tag and would close whatever plan
# happens to share the name. And land runs the FAST lane, so the receipt gate is
# unrun on every land — filing that would fire a row on every land forever, with
# nothing anyone can do, which is the EXPIRED class deploy-record.sh names. The
# pheromone is the part that is true here.
# Close the loop on BOTH exits — a red land is an outcome, not an absence of one.
# `|| true` on purpose: a logging debt must never change what the merge door did.
(( ${#FAILED[@]} )) && { bash "$(dirname "${BASH_SOURCE[0]}")/do-close.sh" "${BRANCHES[0]##*/}" --status failed --only dims,feedback || true; exit 1; }
say ""
if (( PR )); then
  say "  Nothing landed — these are pull requests. main is untouched."
  say "  The gate that ran proves the branch is green ON ITS OWN, not that it survives the trunk."
  [[ -n "$DEV_NOTE" ]] && say "  Running on dev: $DEV_URL — dev shares production's DATA. Merge the PR, then ./deploy."
else
  say "  dev only. Promote to production with: ./deploy   (full gate, human decision)"
fi
bash "$(dirname "${BASH_SOURCE[0]}")/do-close.sh" "${BRANCHES[0]##*/}" --only dims,feedback || true
exit 0
