#!/usr/bin/env bash
# sweep.sh — every finished branch into `dev`, one gate, one sha to promote.
#
# manifest: monorepo-only
#
# THE RULES. Each is true at the line it guards; the story that earned it is one
# command away and is never summarised here.
#
#   ONE gate for N branches, never one gate per branch.        incident:sweep-n-trees
#   A batched red RESETS dev; re-land with land.sh, which      incident:sweep-batched-red-owner
#     still names the owner. land.sh's default is UNCHANGED.
#   gc measures against origin/main, after a fetch. Removal    incident:gc-stale-base
#     is do-auto.sh --gc's; this never re-implements it.
#   A dry run starts no gates, so it is never refused for      incident:sweep-dry-run-never-refused
#     the box. Reap only when orphans > 0.
#
#   Accounts:  bash .claude/scripts/incident.sh --for .claude/scripts/sweep.sh
#
# Usage:
#   sweep.sh                 # doctor · fetch · classify · land · ONE gate · gc · close
#   sweep.sh --dry-run       # the whole plan, nothing merged, removed or pushed
#   sweep.sh --inventory     # the classification table only (what --self-test drives)
#   sweep.sh --full          # force the FULL lane on the integrated tree
#   sweep.sh --pr            # also push dev and open/refresh the dev -> main PR
#   sweep.sh --no-doctor     # skip the box read (never skip it because it said no)
#   sweep.sh --self-test     # mint a sandbox estate and prove the classifier bites
#
# It does NOT ship. The last two doors are release-manager's
# (../CLAUDE.md § The dev -> prod loop); this one ends by naming the sha to promote.
#
# Exit codes, distinct and named — "it refused" is not a finding:
#   0 ok · 2 usage · 3 box refused (doctor) · 4 integrated gate RED (dev reset)
#   5 a merge conflicted (dev reset) · 6 nothing to sweep and nothing to promote
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SWEEP_ROOT lets --self-test point the whole classifier at a sandbox estate.
# HERE always stays the real script dir, so the lib it sources is never the
# sandbox's (there isn't one) — the sandbox supplies REFS, not code.
ROOT="${SWEEP_ROOT:-$(cd "$HERE/../.." && pwd)}"
cd "$ROOT" || exit 2

# SWEEP_GATE_CMD is honoured ONLY under SWEEP_ROOT — there is no way to spell
# "skip the gate" in a real run.                        incident:sweep-sandbox-seam
SANDBOX=0; [ -n "${SWEEP_ROOT:-}" ] && SANDBOX=1
TRUNK="${SWEEP_TRUNK:-dev}"
GC_BASE="${SWEEP_GC_BASE:-origin/main}"
KEEP="${SWEEP_KEEP:-main dev release}"
DRY=0; INVENTORY=0; FULL=0; PR=0; DOCTOR=1; SELF_TEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY=1 ;;
    --inventory) INVENTORY=1 ;;
    --full)      FULL=1 ;;
    --pr)        PR=1 ;;
    --no-doctor) DOCTOR=0 ;;
    --self-test) SELF_TEST=1 ;;
    -h|--help)   sed -n '1,60p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "sweep: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }
ok()  { printf '  ok   %s\n' "$*"; }
bad() { printf '  RED  %s\n' "$*" >&2; }

# ---------------------------------------------------------------- classify ---
# ONE definition of "finished", shared with the sweep that does the removing.
. "$HERE/lib/gc-finished.sh"

# _live <worktree-dir> — is anything running in this tree?
# The trailing slash is load-bearing; pgrep -f reads argv, not cwd.  incident:live-anchor
_live() {
  local wt="$1"
  [ -n "$(pgrep -f "${wt%/}/" 2>/dev/null | grep -v "^$$\$" || true)" ]
}

# _worktree_of <branch> — the checkout holding it, empty when there is none.
_worktree_of() {
  git -C "$ROOT" worktree list --porcelain 2>/dev/null \
    | awk -v b="refs/heads/$1" '
        /^worktree /{wt=substr($0,10)}
        /^branch /{if (substr($0,8)==b) {print wt; exit}}'
}

# classify <branch> -> "<class> <detail>"
#   infra    one of the branches the loop itself stands on — never touched
#   landed   its content is already in the trunk (content identity, not counting)
#   busy     ahead, but its worktree is dirty or something is running in it
#   ready    ahead, clean, idle — this is the only class that gets merged
classify() {
  local b="$1" wt ahead dirt
  case " $KEEP " in *" $b "*) echo "infra -"; return ;; esac
  wt="$(_worktree_of "$b")"
  if gc_finished "$TRUNK" "$b"; then echo "landed ${wt:--}"; return; fi
  ahead="$(gc_carries "$TRUNK" "$b")"
  if [ -n "$wt" ]; then
    dirt="$(gc_real_dirt "$wt")"
    [ -n "$dirt" ] && { echo "busy uncommitted-work-in-$wt"; return; }
    _live "$wt" && { echo "busy something-running-in-$wt"; return; }
  fi
  echo "ready carries-${ahead}-path(s)"
}

inventory() {
  local b cls
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    cls="$(classify "$b")"
    printf '%s\t%s\n' "$b" "$cls"
  done < <(git -C "$ROOT" for-each-ref --format='%(refname:short)' refs/heads/)
}

# --------------------------------------------------------------- self-test ---
# A green run on the live estate proves only that a no-op is a no-op.
self_test() {
  local rc=0

  # _mint <dir> [extra-shell] — a throwaway estate with one branch of every
  # class. `extra` runs last, inside the repo, so a case can add its own shape.
  _mint() {
    local d="$1" extra="${2:-}"
    ( set -e
      mkdir -p "$d"; cd "$d"
      git init -q -b dev .
      git config user.email s@s; git config user.name s
      echo base > a.txt
      # one.ie/web must be TRACKED or .astro never surfaces as its own path.
      #                                incident:porcelain-collapses-untracked-dir
      mkdir -p one.ie/web; echo keep > one.ie/web/keep.txt
      git add a.txt one.ie/web/keep.txt; git commit -qm base

      # landed: its patch is in dev under a DIFFERENT sha — the rebase/squash
      # case `rev-list --count` gets wrong, which is why the predicate is content.
      git checkout -qb feat/landed; echo one > b.txt; git add b.txt; git commit -qm one
      git checkout -q dev; echo one > b.txt; git add b.txt; git commit -qm "one, landed differently"

      # ready: ahead, clean, no worktree.
      git checkout -qb feat/ready dev; echo two > c.txt; git add c.txt; git commit -qm two

      # busy-dirty: ahead, with uncommitted WORK in its checkout.
      git checkout -qb feat/dirty dev; echo three > d.txt; git add d.txt; git commit -qm three
      git checkout -q dev
      git worktree add -q "$d/wt-dirty" feat/dirty
      echo scribble >> "$d/wt-dirty/d.txt"

      # ephemeral-only dirt must NOT read as busy — build output is not work.
      git checkout -qb feat/ephemeral dev; echo four > e.txt; git add e.txt; git commit -qm four
      git checkout -q dev
      git worktree add -q "$d/wt-eph" feat/ephemeral
      mkdir -p "$d/wt-eph/one.ie/web/.astro"; echo x > "$d/wt-eph/one.ie/web/.astro/x"

      git checkout -q dev
      [ -n "$extra" ] && eval "$extra"
      true
    ) >/dev/null 2>&1
  }

  _run() { # <dir> <gate-cmd> [flags...] -> prints output, returns sweep's exit
    local d="$1" gate="$2"; shift 2
    ( cd "$d" && SWEEP_ROOT="$d" SWEEP_GATE_CMD="$gate" SWEEP_TRUNK=dev \
        SWEEP_KEEP="main dev release" bash "$HERE/sweep.sh" --no-doctor "$@" 2>&1 )
  }
  _assert() { # <label> <condition-result 0/1>
    if [ "$2" = 0 ]; then ok "$1"; else bad "$1"; rc=1; fi
  }

  say "── sweep --self-test ──"

  # ---- 1. the classifier, one branch of every class ------------------------
  local t1 out
  t1="$(mktemp -d)"; _mint "$t1" || { bad "sandbox 1 would not build"; return 1; }
  out="$( cd "$t1" && SWEEP_ROOT="$t1" SWEEP_TRUNK=dev SWEEP_KEEP="main dev release" \
          bash "$HERE/sweep.sh" --inventory 2>/dev/null )"
  printf '%s\n' "$out" | sed 's/^/  /'
  _expect() { # <branch> <class>
    local got; got="$(printf '%s\n' "$out" | awk -v b="$1" '$1==b{print $2}')"
    if [ "$got" = "$2" ]; then ok "classify $1 -> $2"
    else bad "classify $1 -> ${got:-<absent>} (expected $2)"; rc=1; fi
  }
  _expect dev            infra
  _expect feat/landed    landed
  _expect feat/ready     ready
  _expect feat/dirty     busy
  _expect feat/ephemeral ready

  # ---- 2. liveness, both directions ---------------------------------------
  # `exec -a` puts the path in argv, which is what pgrep -f reads. incident:live-anchor
  if _live "$t1/definitely-not-a-tree"; then bad "_live said yes for an empty path"; rc=1
  else ok "_live is false for an empty path"; fi
  local holder
  ( exec -a "node $t1/one.ie/web/dev-server" sleep 20 ) >/dev/null 2>&1 &
  holder=$!; sleep 0.3
  _live "$t1" && ok "_live sees a live process under the tree" || { bad "_live missed it"; rc=1; }
  # The anchor: `pgrep -f worktrees/media` also matches `worktrees/mediawire`.
  if _live "${t1}-neighbour"; then bad "_live matched a PREFIX neighbour"; rc=1
  else ok "_live does not match a prefix neighbour"; fi
  kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null

  # ---- 3. the MERGE path: ready branches land, busy ones do not ------------
  # Everything below MOVES REFS, which is why it is tested.  incident:sweep-sandbox-seam
  local t2 pre post
  t2="$(mktemp -d)"; _mint "$t2"
  pre="$(git -C "$t2" rev-parse HEAD)"
  out="$(_run "$t2" true)"; local st2=$?
  post="$(git -C "$t2" rev-parse HEAD)"
  _assert "merge: exits 0 with a green gate" $([ $st2 -eq 0 ] && echo 0 || echo 1)
  _assert "merge: dev moved" $([ "$pre" != "$post" ] && echo 0 || echo 1)
  _assert "merge: feat/ready landed (c.txt)"     $(git -C "$t2" cat-file -e dev:c.txt 2>/dev/null && echo 0 || echo 1)
  _assert "merge: feat/ephemeral landed (e.txt)" $(git -C "$t2" cat-file -e dev:e.txt 2>/dev/null && echo 0 || echo 1)
  _assert "merge: feat/dirty did NOT land (d.txt absent)" $(git -C "$t2" cat-file -e dev:d.txt 2>/dev/null && echo 1 || echo 0)
  _assert "merge: reports gates=1" $(printf '%s' "$out" | grep -q "gates=1" && echo 0 || echo 1)
  _assert "merge: reports lane=fast" $(printf '%s' "$out" | grep -q "lane=fast" && echo 0 || echo 1)

  # ---- 4. the lane escalates on schema/, by itself -------------------------
  local t3
  t3="$(mktemp -d)"
  _mint "$t3" 'git checkout -qb feat/schema dev; mkdir -p schema; echo "define x" > schema/one.tql; git add schema; git commit -qm schema; git checkout -q dev'
  out="$(_run "$t3" true)"
  _assert "lane: a schema/ touch selects FULL without being asked" \
    $(printf '%s' "$out" | grep -q "lane=full" && echo 0 || echo 1)

  # ---- 5. a RED gate resets dev and names the re-land -----------------------
  local t4 pre4 post4
  t4="$(mktemp -d)"; _mint "$t4"
  pre4="$(git -C "$t4" rev-parse HEAD)"
  out="$(_run "$t4" false)"; local st4=$?
  post4="$(git -C "$t4" rev-parse HEAD)"
  _assert "red gate: exit 4" $([ $st4 -eq 4 ] && echo 0 || echo 1)
  _assert "red gate: dev reset to the pre-sweep sha" $([ "$pre4" = "$post4" ] && echo 0 || echo 1)
  _assert "red gate: names land.sh per branch" \
    $(printf '%s' "$out" | grep -q "land.sh feat/ready" && echo 0 || echo 1)

  # ---- 6. a CONFLICT resets dev too — its own exit code (5, not 4) ---------
  local t5 pre5 post5
  t5="$(mktemp -d)"
  _mint "$t5" 'git checkout -qb feat/clash dev; echo mine > a.txt; git commit -qam mine; git checkout -q dev; echo theirs > a.txt; git commit -qam theirs'
  pre5="$(git -C "$t5" rev-parse HEAD)"
  out="$(_run "$t5" true)"; local st5=$?
  post5="$(git -C "$t5" rev-parse HEAD)"
  _assert "conflict: exit 5" $([ $st5 -eq 5 ] && echo 0 || echo 1)
  _assert "conflict: dev reset to the pre-sweep sha" $([ "$pre5" = "$post5" ] && echo 0 || echo 1)

  # ---- 7. the stub is unreachable without a sandbox ------------------------
  _assert "SWEEP_GATE_CMD is honoured only under SWEEP_ROOT" \
    $(grep -q 'if (( SANDBOX )) && \[ -n "\${SWEEP_GATE_CMD:-}" \]' "$HERE/sweep.sh" && echo 0 || echo 1)

  rm -rf "$t1" "$t2" "$t3" "$t4" "$t5"
  say ""
  [ $rc -eq 0 ] && say "  self-test PASS" || say "  self-test RED"
  return $rc
}

[ $SELF_TEST -eq 1 ] && { self_test; exit $?; }
[ $INVENTORY -eq 1 ] && { inventory; exit 0; }

# ------------------------------------------------------------ phase 0 doctor --
# The box read comes FIRST because a sweep starts gates, and a saturated box
# turns a fine tree red for queueing. health.sh --fix never kills a claude
# session, a governor-slot holder, or anything in the main tree.
VERDICT="skipped"; ORPHANS="?"; FUNDED="?"; WHY=""

# _box — re-read the doctor's instrument. health.sh owns every number; this only
# reads them. HEALTHY | DEGRADED | UNHEALTHY (health.sh:307-319).
_box() {
  local j
  j="$( bash "$HERE/health.sh" --box --json 2>/dev/null )"
  VERDICT="$(printf '%s' "$j" | sed -n 's/.*"verdict":"\([A-Z]*\)".*/\1/p')"
  WHY="$(printf '%s' "$j" | sed -n 's/.*"why":"\([^"]*\)".*/\1/p')"
  ORPHANS="$(printf '%s' "$j" | sed -n 's/.*"orphans":\([0-9]*\).*/\1/p')"
  FUNDED="$(printf '%s' "$j" | sed -n 's/.*"gates_funded":\([0-9]*\).*/\1/p')"
  VERDICT="${VERDICT:-unknown}"
}

if [ $DOCTOR -eq 1 ]; then
  say "── doctor ──"
  _box
  say "  box: $VERDICT — ${WHY:-no reason given}"
  say "  orphans=$ORPHANS gates_funded=$FUNDED"

  # Reap only when there is something to reap.  incident:sweep-dry-run-never-refused
  if [ "${ORPHANS:-0}" != "0" ]; then
    bash "$HERE/gate-reaper.sh" --once 2>/dev/null | sed 's/^/  /'
    _box
    say "  box after reap: $VERDICT (orphans=$ORPHANS)"
  fi

  case "$VERDICT" in
    UNHEALTHY)
      # A dry run starts no gates, so it is never refused.
      if (( DRY )); then say "  (dry run — reporting the box, refusing nothing)"; else
      bad "box is UNHEALTHY — $WHY"
      say "      A sweep STARTS gates. On a paging box the gate runs long and a slow"
      say "      gate is not a red one, but it is indistinguishable from one at the"
      say "      wall clock. Hand the box to the doctor first:"
      say "        Agent({ subagent_type: \"doctor\", model: \"opus\","
      say "                prompt: \"health.sh says: $WHY. Reclaim what nothing is coming back for, then report.\" })"
      say "      Or override, knowing the gate will be slow:  sweep.sh --no-doctor"
      exit 3
      fi ;;
    DEGRADED)
      # Headroom of 1: a reason to run ONE gate, not a reason to refuse.
      say "  proceeding: DEGRADED funds $FUNDED concurrent gate(s), and a sweep needs exactly one" ;;
    *)
      ok "box is $VERDICT" ;;
  esac
fi

# --------------------------------------------------------------- phase 1 fetch --
say "── fetch ──"
git -C "$ROOT" fetch -q --prune origin 2>/dev/null || say "  (offline — measuring against local refs)"
TRUNK_WT="$(_worktree_of "$TRUNK")"
[ -n "$TRUNK_WT" ] || { bad "no worktree holds $TRUNK — cut one with worktree-up.sh $TRUNK"; exit 2; }
ok "$TRUNK is checked out at $TRUNK_WT"

# ------------------------------------------------------------ phase 2 classify --
say "── classify ──"
READY=(); LANDED=0; BUSY=0; INFRA=0
while IFS=$'\t' read -r b rest; do
  cls="${rest%% *}"; detail="${rest#* }"
  case "$cls" in
    infra)  INFRA=$((INFRA+1)) ;;
    landed) LANDED=$((LANDED+1)); say "  landed  $b" ;;
    busy)   BUSY=$((BUSY+1));     say "  busy    $b — $detail" ;;
    ready)  READY+=("$b");        say "  ready   $b — $detail" ;;
  esac
done < <(inventory)
say "  ready=${#READY[@]} landed=$LANDED busy=$BUSY infra=$INFRA"

PRE_SWEEP_SHA="$(git -C "$TRUNK_WT" rev-parse HEAD)"

# --------------------------------------------------------------- phase 3 land --
MERGED=0; TOUCHED=""
if [ ${#READY[@]} -gt 0 ]; then
  say "── land (batched into $TRUNK) ──"
  for b in "${READY[@]}"; do
    probe="$( TSC_CACHE_ROOT="$(_worktree_of "$b")" \
              bash "$ROOT/.claude/scripts/tsc-cached.sh" --probe one.ie/web 2>/dev/null || echo unknown )"
    if (( DRY )); then say "  [dry] merge $b into $TRUNK (own typecheck: $probe)"; MERGED=$((MERGED+1)); continue; fi
    say "  merging $b (own typecheck: $probe)"
    if ! git -C "$TRUNK_WT" merge --no-edit "$b" >/dev/null 2>&1; then
      git -C "$TRUNK_WT" merge --abort 2>/dev/null
      git -C "$TRUNK_WT" reset --hard "$PRE_SWEEP_SHA" >/dev/null 2>&1
      bad "$b conflicts with $TRUNK — $TRUNK reset to $PRE_SWEEP_SHA, land it alone: land.sh $b"
      exit 5
    fi
    TOUCHED="$TOUCHED$(git -C "$TRUNK_WT" diff --name-only "$PRE_SWEEP_SHA" HEAD)"$'\n'
    MERGED=$((MERGED+1))
  done
fi

# --------------------------------------------------------- phase 4 ONE gate ---
# schema, the SDK and auth take the FULL lane, whatever the default is.
GATES=0; LANE="none"
if [ $MERGED -gt 0 ] || [ $FULL -eq 1 ]; then
  if [ $FULL -eq 1 ] || printf '%s' "$TOUCHED" | grep -qE '^(schema/|packages/sdk/|one\.ie/web/src/lib/(authority|role-check))'; then
    LANE="full"
  else
    LANE="fast"
  fi
  say "── gate (ONE, on the integrated tree) ── lane=$LANE"
  if (( DRY )); then
    say "  [dry] (cd $TRUNK_WT/one.ie/web && gate-run.sh sweep -- $([ $LANE = full ] && echo 'FULL_VERIFY=1 bun run verify' || echo 'bun run verify:fast'))"
  else
    GATES=1
    # Status captured per branch of the if, never from `$?` after `fi`, and the
    # gate is never piped.                          incident:gate-status-never-piped
    st=0
    if (( SANDBOX )) && [ -n "${SWEEP_GATE_CMD:-}" ]; then
      eval "$SWEEP_GATE_CMD" || st=$?
    elif [ "$LANE" = "full" ]; then
      ( cd "$TRUNK_WT/one.ie/web" && FULL_VERIFY=1 bash "$ROOT/.claude/scripts/gate-run.sh" sweep -- bun run verify ) || st=$?
    else
      ( cd "$TRUNK_WT/one.ie/web" && bash "$ROOT/.claude/scripts/gate-run.sh" sweep -- bun run verify:fast ) || st=$?
    fi
    if [ $st -ne 0 ]; then
      git -C "$TRUNK_WT" reset --hard "$PRE_SWEEP_SHA" >/dev/null 2>&1
      bad "integrated gate RED (exit $st) — $TRUNK reset to $PRE_SWEEP_SHA, nothing landed"
      say "      the batch cannot name which of ${#READY[@]} owns it. Re-land one at a time,"
      say "      where land.sh diagnoses branch / dev / seam / environment:"
      for b in "${READY[@]}"; do say "        bash .claude/scripts/land.sh $b"; done
      exit 4
    fi
    ok "integrated $LANE gate green on $(git -C "$TRUNK_WT" rev-parse --short HEAD)"
  fi
fi

# ----------------------------------------------------------------- phase 5 gc --
say "── gc (base $GC_BASE — a branch is finished when RELEASED, not integrated) ──"
if (( SANDBOX )); then
  say "  (sandbox — the collector is do-auto.sh's and is not re-run here)"
elif (( DRY )); then
  DO_GC_BASE="$GC_BASE" bash "$ROOT/.claude/scripts/do-auto.sh" --gc --dry-run 2>&1 | sed 's/^/  /'
else
  DO_GC_BASE="$GC_BASE" bash "$ROOT/.claude/scripts/do-auto.sh" --gc 2>&1 | sed 's/^/  /'
fi

# ------------------------------------------------------------- phase 6 ready ---
say "── ready to deploy ──"
DEV_SHA="$(git -C "$TRUNK_WT" rev-parse HEAD)"
AHEAD_OF_MAIN="$(git -C "$ROOT" rev-list --count "origin/main..$DEV_SHA" 2>/dev/null || echo 0)"
if [ "$AHEAD_OF_MAIN" = "0" ] && [ $MERGED -eq 0 ]; then
  say "  $TRUNK carries nothing origin/main does not have — nothing to promote"
  say "ready=0 merged=0 landed=$LANDED busy=$BUSY infra=$INFRA gates=$GATES lane=$LANE box=$VERDICT dev=$(git -C "$TRUNK_WT" rev-parse --short HEAD) ahead_of_main=0"
  exit 6
fi
if (( DRY )); then
  say "  [dry] git push origin $TRUNK"
  (( PR )) && say "  [dry] gh pr create --base main --head $TRUNK"
else
  if (( SANDBOX )); then say "  (sandbox — not pushing)"
  else git -C "$TRUNK_WT" push -q origin "$TRUNK" 2>/dev/null && ok "pushed $TRUNK" || say "  (push skipped — offline or nothing new)"; fi
  if (( PR )); then
    gh pr create --base main --head "$TRUNK" --fill 2>/dev/null \
      || gh pr list --base main --head "$TRUNK" --json url --jq '.[0].url' 2>/dev/null | sed 's/^/  PR: /'
  fi
fi
say "  $TRUNK is $AHEAD_OF_MAIN commit(s) ahead of origin/main at $(git -C "$TRUNK_WT" rev-parse --short HEAD)"
say "  the ship door is release-manager's, never this script's:"
say "    Agent({ subagent_type: \"release-manager\", model: \"opus\", prompt: \"…promote $DEV_SHA, then ship\" })"

say ""
# THE NUMERIC CLOSE. Every number is counted, not narrated; `gates` is the point.
say "ready=${#READY[@]} merged=$MERGED landed=$LANDED busy=$BUSY infra=$INFRA gates=$GATES lane=$LANE box=$VERDICT dev=$(git -C "$TRUNK_WT" rev-parse --short HEAD) ahead_of_main=$AHEAD_OF_MAIN"
