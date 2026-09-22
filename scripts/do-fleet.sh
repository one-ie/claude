#!/usr/bin/env bash
# do-fleet.sh — run several /do plans in parallel, each in its own worktree.
#
# The layer above do-auto.sh: do-auto runs ONE plan's cycles in a worktree;
# do-fleet picks the top-ranked, file-disjoint plans and launches a do-auto per
# plan, concurrently. Ranking comes from do-rank.py. Merges are NOT automated —
# each plan's do-auto writes its own .do-digest.md; a human lands them.
#
# v2: slot-pool queue. Starts up to --slots live plans; as each exits a new one
# pops from the ranked queue (file-disjoint against the CURRENTLY live set).
# Supports --slots 10 safely — the queue feeds slots as they free up.
#
# SAFETY (non-negotiable):
#   - DRY-RUN by default. Real launch needs --go.
#   - Hard --slots cap (default 3). Override with --slots N.
#   - Conflict filter: greedy by score, skips any plan whose deliverable dirs
#     overlap a currently-live plan. Re-checks on every pop (dynamic).
#   - _link_deps symlinks node_modules + built sdk dist into each worktree.
#   - One slug ⇒ one worktree. Refuses to schedule a slug already running.
#   - Stall watchdog: kills any slot alive > STALL_TIMEOUT seconds, marks stalled.
#
# Usage:
#   do-fleet.sh                      # dry-run, top 3 slots
#   do-fleet.sh --slots 2 --go       # launch 2 at a time from queue
#   do-fleet.sh --slots 10 --go      # 10-slot queue mode
#   do-fleet.sh --top 40 --slots 10 --go
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RANK="$ROOT/.claude/scripts/do-rank.py"
AUTO="$ROOT/.claude/scripts/do-auto.sh"
WT_BASE="$ROOT/.do-worktrees"

# Worktree branches cut from trunk, never HEAD — a shared tree parked on a
# feature branch must not seed fleet plans with its commits. DO_BASE_REF overrides.
BASE_REF="${DO_BASE_REF:-dev}"
git -C "$ROOT" show-ref --verify --quiet "refs/heads/$BASE_REF" || BASE_REF=HEAD

GO=false
SLOTS=3
TOP=40
STALL_TIMEOUT=1800   # 30 min — kill a stuck do-auto
POLL=10              # seconds between slot checks

while [ $# -gt 0 ]; do
  case "$1" in
    --go)    GO=true; shift ;;
    --slots|--max) SLOTS="$2"; shift 2 ;;
    --top)   TOP="$2"; shift 2 ;;
    --stall) STALL_TIMEOUT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -f "$RANK" ] || { echo "do-fleet: missing $RANK" >&2; exit 1; }

# Cap slots by (cores - 2), never exceed --slots.
CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
CORE_CAP=$(( CORES - 2 )); [ "$CORE_CAP" -lt 1 ] && CORE_CAP=1
BIND="--slots"
[ "$SLOTS" -gt "$CORE_CAP" ] && { SLOTS="$CORE_CAP"; BIND="cores"; }

# …and by MEMORY, which is the constraint that actually bites.
#
# Cores were never the limit. On a 10-core/24GB box `cores - 2` authorised 8
# concurrent worktrees; 8 cycles is ~16GB of gates before the editors, the
# sessions and the OS get a byte. The box reached load 57 and filled 16GB of
# swap with fewer than that. gate_headroom prices a cycle in GB and divides
# what is actually free, so the fleet shrinks on a loaded box and opens back
# up on an idle one. It only ever LOWERS the count — --slots and the core cap
# still hold.
# shellcheck source=lib/govern.sh
. "$ROOT/.claude/scripts/lib/govern.sh"
MEM_CAP=$(gate_headroom)
[ "$SLOTS" -gt "$MEM_CAP" ] && { SLOTS="$MEM_CAP"; BIND="memory"; }

# A worktree cut before the governor landed runs the OLD unbounded gates, so
# the cap above is the only thing protecting the box from it. Say so — a silent
# stale worktree is how this problem returns.
for _wt in "$WT_BASE"/*/; do
  [ -f "$_wt/.claude/scripts/lib/govern.sh" ] && continue
  [ -d "$_wt/.claude/scripts" ] || continue
  echo "[do-fleet] ⚠ $(basename "$_wt") predates the governor — its gates are unbounded; rebase it onto $BASE_REF"
done

echo "[do-fleet] ranking… (top $TOP candidates, $SLOTS slots — bound by $BIND; cores≤$CORE_CAP mem≤$MEM_CAP, $( $GO && echo LIVE || echo DRY-RUN ))"

# Load ranked queue into an array (bash 3.2 compatible — no mapfile).
QUEUE=()
while IFS= read -r line; do [ -n "$line" ] && QUEUE+=("$line"); done \
  < <(python3 "$RANK" --top "$TOP" 2>/dev/null)

[ "${#QUEUE[@]}" -eq 0 ] && { echo "[do-fleet] no ready plans — nothing to do"; exit 0; }

# --- helpers -------------------------------------------------------------------

deliverable_dirs() {
  # SINGLE source of truth: do-rank.py owns deliverable-path parsing + the subtree
  # granularity. The fleet's live conflict check and the displayed waves now read the
  # SAME extractor, so they can never drift (the old bash re-parser at top/second dir
  # granularity disagreed with do-rank and serialized every one.ie/web plan).
  python3 "$RANK" --dirs "$1" 2>/dev/null
}

link_deps() {
  local wt="$1"
  for nm in node_modules one.ie/web/node_modules packages/node_modules \
            packages/sdk/dist packages/sdk/node_modules; do
    if [ -e "$ROOT/$nm" ] && [ ! -e "$wt/$nm" ]; then
      mkdir -p "$wt/$(dirname "$nm")"
      ln -s "$ROOT/$nm" "$wt/$nm" 2>/dev/null && echo "    linked $nm" || true
    fi
  done
}

# Region-claim registry — MACHINE-WIDE, in $GOVERN_DIR/claims (lib/govern.sh).
#
# This used to be `LOCK_FILE="$(mktemp)"`: a map private to one fleet process.
# Nine concurrent fleet invocations held nine private maps, so two fleets could
# each believe a region was free and both take it — the duplicate-selection
# collision this registry exists to remove. mkdir(2) is the arbiter; a claim
# evaporates on its own when the owner dies (kill -0) or its lease expires.
trap 'claim_release_all' EXIT

claim_dirs() {   # claim_dirs <slug> → 0 = all regions claimed, 1 = lost a race
  local slug="$1" n=0 d
  CLAIM_TAKEN=()
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    n=$(( n + 1 ))
    if claim_take "$d" "$slug"; then
      CLAIM_TAKEN+=("$d")
    else
      # Another fleet won this region between has_conflict and here. Give back
      # everything already taken for this slug — a half-claimed plan would hold
      # ground it never builds, and only the TTL would ever free it.
      if [ "${#CLAIM_TAKEN[@]}" -gt 0 ]; then
        for d in "${CLAIM_TAKEN[@]}"; do claim_release "$d"; done
      fi
      echo "  ✗ $slug — lost the race for a region to another fleet, deferring" >&2
      return 1
    fi
  done < <(deliverable_dirs "$slug")
  # An unscoped plan (no deliverables:) declares zero dirs — the conflict filter
  # would treat it as disjoint from EVERYTHING and parallelize it blindly, which
  # clobbers shared trees (one.ie/web). Claim the __ANY__ sentinel so it conflicts
  # with any other plan: it only ever runs as the sole slot. Declare deliverables
  # to make it fleet-safe (see do-rank.py UNSCOPED warning).
  if [ "$n" -eq 0 ]; then
    claim_take "__ANY__" "$slug" || { echo "  ✗ $slug — __ANY__ taken, deferring" >&2; return 1; }
  fi
  return 0
}

free_dirs() {    # free_dirs <slug>
  local d
  while IFS= read -r d; do
    [ -n "$d" ] && claim_release "$d"
  done < <(deliverable_dirs "$1")
  # Only the slug that took the sentinel may give it back. Every claim in this
  # process shares one pid, so an unguarded release here would let a finishing
  # SCOPED plan hand back a live UNSCOPED plan's sole-slot guarantee.
  [ "$(claim_owner "__ANY__" | awk '{print $1}')" = "$1" ] && claim_release "__ANY__"
  return 0
}

has_conflict() { # has_conflict <slug> → exit 0 if conflict
  # Every read below goes through claim_owner/claim_list, which reap a dead or
  # expired owner before answering — so a fleet that was killed mid-plan never
  # keeps a region shut.
  local live_owner
  # A live unscoped plan holds the __ANY__ sentinel → nothing may share with it.
  any_owner=$(claim_owner "__ANY__" | awk '{print $1}')
  if [ -n "$any_owner" ] && [ "$any_owner" != "$1" ]; then
    echo "  ✗ $1 — unscoped plan $any_owner holds the fleet (sole slot), deferring"
    return 0
  fi
  # This plan is itself unscoped (no deliverable dirs) → only runs alone.
  ndirs=$(deliverable_dirs "$1" | grep -c . || true)
  if [ "$ndirs" -eq 0 ]; then
    live_owner=$(claim_list | awk -F'\t' -v s="$1" '$2!=s{print $2; exit}')
    if [ -n "$live_owner" ]; then
      echo "  ✗ $1 — unscoped (no deliverables:), defers while $live_owner is live"
      return 0
    fi
  fi
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    owner=$(claim_owner "$d" | awk '{print $1}')
    if [ -n "$owner" ] && [ "$owner" != "$1" ]; then
      echo "  ✗ $1 — dir $d claimed by $owner, deferring"
      return 0
    fi
  done < <(deliverable_dirs "$1")
  return 1
}

# claim_task — fires tasks:claim before a worktree is cut (claim = lease, tasks-do C5).
# Best-effort like do-signal.sh's world:do-event stance: no configured secret or an
# unparseable response degrades to "ok to launch" rather than blocking the fleet. An
# explicit already-claimed/blocked response returns 1 so fill_slots skips this slug —
# two fleet runs (or a fleet run racing a human claim) never double-build the same task.
claim_task() {  # claim_task <slug> → 0 ok to launch, 1 already claimed elsewhere
  # GATEWAY_API_KEY, not SERVER_SECRET — /api/ask/<receiver>'s isServiceCaller checks
  # env.GATEWAY_API_KEY (one.ie/web/src/pages/api/ask/[...receiver].ts). SERVER_SECRET
  # is what /api/signal/ checks; the two routes don't share a secret. Also pin
  # workspace so the claim's ctx.ownerSlug lands in /u/one/tasks like every other
  # Claude Code task (do-signal.sh's CC_TASKS_WORKSPACE convention).
  # Address the lease by the plan SLUG, never a guessed tid: real tids are minted
  # task:<traceId> (resolvers/tasks.ts insertTaskRow), so "task:<slug>" resolved
  # not_found for every plan and the lease could never gate. tasks:claim resolves
  # data.slug via resolveTaskBySlug when present (resolvers/tasks.ts claim).
  local slug="$1" secret="" f resp
  # ONE_ENV_FILE first: the loop must be able to read credentials with no
  # one.ie/web/ on disk. The monorepo paths stay as fallbacks and expand to
  # nothing outside it.
  for f in "${ONE_ENV_FILE:-${DO_ENV_FILE:-}}" "$ROOT/.env" "$ROOT/one.ie/web/.env" "$ROOT/one.ie/web/.secrets.generated.local"; do
    [ -n "$f" ] || continue
    [ -f "$f" ] || continue
    secret=$(grep -E '^GATEWAY_API_KEY=' "$f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//' || true)
    [ -n "$secret" ] && break
  done
  [ -z "$secret" ] && return 0
  # A mirrored plan (do-board.sh) hangs its cycle rows off the plan row, and the
  # claim gate refuses a parent with open children — so lease the FIRST OPEN CYCLE's
  # row when there is one (its own batch predecessors gate it), the plan row otherwise.
  local addr tid
  tid=$(bash "$ROOT/.claude/scripts/do-plan-json.sh" "$slug" 2>/dev/null | jq -r '.cycleRows[.openCycles[0]] // empty' 2>/dev/null || true)
  if [ -n "$tid" ]; then addr="\"tid\":\"$tid\""; else addr="\"slug\":\"$slug\""; fi
  resp=$(curl -sf -X POST "${DO_SIGNAL_URL:-https://one.ie}/api/ask/tasks:claim" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $secret" \
    -d "{\"data\":{$addr,\"workspace\":\"${CC_TASKS_WORKSPACE:-one}\"}}" 2>/dev/null || true)
  case "$resp" in
    *'"ok":true'*)                 return 0 ;;   # lease held by us — launch
    *'"error":"already-claimed"'*) echo "  ~ $slug — claimed by another actor, skipping" >&2; return 1 ;;
    *'"error":"blocked"'*)         echo "  ~ $slug — blocked by an unresolved dependency, skipping" >&2; return 1 ;;
    *'"error":"not_found"'*)       return 0 ;;   # no substrate task yet (claim-before-create) — launch
    *'"error"'*)                   echo "  ! $slug — claim degraded: $resp" >&2; return 0 ;;
    *)                             return 0 ;;   # unparseable/empty — best-effort, launch
  esac
}

launch_plan() {  # launch_plan <slug> → echoes PID, or nothing if the claim was lost
  local slug="$1"
  local wt="$WT_BASE/$slug"
  # Claim the ground FIRST. has_conflict only read the registry; between that
  # read and now another fleet may have deposited. mkdir decides, and a loser
  # reroutes to the next candidate rather than waiting.
  claim_dirs "$slug" || return 1
  if [ ! -d "$wt" ]; then
    git -C "$ROOT" worktree add -b "do/$slug" "$wt" "$BASE_REF" >/dev/null 2>&1 \
      || git -C "$ROOT" worktree add "$wt" "do/$slug" >/dev/null 2>&1 || true
  fi
  # stdout of this function IS the pid — fill_slots captures it. Chatter must go
  # to stderr or the "pid" is a multi-line string and every kill -0 on it fails,
  # which reads as "slot finished" the instant it launches.
  link_deps "$wt" >&2
  echo "  ▶ launching $slug (log: $wt/.fleet.log)" >&2
  # Direct exec (no subshell wrapper) so $! is the do-auto.sh bash process itself.
  # A ( cmd ) & subshell forks cmd and exits immediately — the fleet would track the
  # subshell PID, which dies before cmd finishes, misreporting the slot as done.
  "$AUTO" "$slug" >"$wt/.fleet.log" 2>&1 &
  echo $!
}

# --- dry-run preview -----------------------------------------------------------
if ! $GO; then
  echo ""
  echo "  DRY-RUN — first $SLOTS disjoint plans from queue:"
  # Seed the preview from the LIVE machine-wide registry (read-only — a dry run
  # never deposits). Otherwise the preview says "✓ foo" for a region another
  # fleet is already inside, which is exactly the lie the registry removes.
  # claim_list emits region<TAB>slug<TAB>pid and reaps dead owners as it walks,
  # so the preview inherits evaporation for free.
  CLAIMED_DRY="$(claim_list)"
  # Keep "" meaning "nothing claimed" — the unscoped-plan check below tests -n.
  if [ -n "$CLAIMED_DRY" ]; then CLAIMED_DRY="$CLAIMED_DRY
"; fi
  COUNT=0
  for slug in "${QUEUE[@]}"; do
    [ "$COUNT" -ge "$SLOTS" ] && break
    if [ -d "$WT_BASE/$slug" ]; then
      if pgrep -f "do-auto.sh ${slug}" >/dev/null 2>&1; then
        echo "  ~ $slug — do-auto already running, skipping"
        continue
      fi
    fi
    conflict=""
    ndirs=$(deliverable_dirs "$slug" | grep -c . || true)
    any_owner=$(printf '%s\n' "$CLAIMED_DRY" | awk -F'\t' '$1=="__ANY__"{print $2; exit}')
    if [ -n "$any_owner" ]; then
      echo "  ✗ $slug — unscoped plan $any_owner holds the fleet, deferring"
      continue
    fi
    if [ "$ndirs" -eq 0 ] && [ -n "$CLAIMED_DRY" ]; then
      echo "  ✗ $slug — unscoped (no deliverables:), defers while a plan is claimed"
      continue
    fi
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      owner=$(printf '%s\n' "$CLAIMED_DRY" | awk -F'\t' -v k="$d" '$1==k{print $2; exit}')
      [ -n "$owner" ] && { conflict="$d ($owner)"; break; }
    done < <(deliverable_dirs "$slug")
    if [ -n "$conflict" ]; then
      echo "  ✗ $slug — $conflict, deferring"
      continue
    fi
    echo "  ✓ $slug"
    if [ "$ndirs" -eq 0 ]; then
      CLAIMED_DRY="$CLAIMED_DRY__ANY__	$slug
"
    else
      while IFS= read -r d; do
        [ -n "$d" ] && CLAIMED_DRY="$CLAIMED_DRY$d	$slug
"
      done < <(deliverable_dirs "$slug")
    fi
    COUNT=$(( COUNT + 1 ))
  done
  echo ""
  echo "  Re-run with --go to launch. Queue depth: ${#QUEUE[@]} plans."
  exit 0
fi

# --- LIVE: slot-pool queue loop ------------------------------------------------
echo ""
echo "[do-fleet] LIVE — $SLOTS slots, ${#QUEUE[@]} queued plans"
echo "[do-fleet] stall watchdog: ${STALL_TIMEOUT}s · poll: ${POLL}s"
echo ""

# Parallel arrays (bash 3.2: no associative arrays).
# SLOT_PIDS[i], SLOT_SLUGS[i], SLOT_START[i] track each live slot.
SLOT_PIDS=()
SLOT_SLUGS=()
SLOT_START=()
DONE_COUNT=0
STALLED=()
DONE_SLUGS=()   # slugs that finished or stalled — skip on every re-scan

# Pop next eligible plan from QUEUE.
# Scans from 0 on every call so deferred items (conflicts) are re-checked after each slot frees.
# Skips SLOT_SLUGS (live) and DONE_SLUGS (finished/stalled).
# Sets NEXT_SLUG or leaves it empty.
pop_next() {
  NEXT_SLUG=""
  local i=0
  while [ "$i" -lt "${#QUEUE[@]}" ]; do
    local s="${QUEUE[$i]}"
    i=$(( i + 1 ))
    # Skip currently-live slugs.
    local skip=false
    if [ "${#SLOT_SLUGS[@]}" -gt 0 ]; then
      for live in "${SLOT_SLUGS[@]}"; do
        [ "$live" = "$s" ] && { skip=true; break; }
      done
    fi
    $skip && continue
    # Skip already-finished slugs.
    if [ "${#DONE_SLUGS[@]}" -gt 0 ]; then
      for ds in "${DONE_SLUGS[@]}"; do
        [ "$ds" = "$s" ] && { skip=true; break; }
      done
    fi
    $skip && continue
    if [ -d "$WT_BASE/$s" ]; then
      # Worktree exists — only skip if a live do-auto process is already running for it.
      # (Worktrees from failed/stalled prior attempts are re-launchable — do-auto resumes them.)
      if pgrep -f "do-auto.sh ${s}" >/dev/null 2>&1; then
        echo "  ~ $s — do-auto already running, skipping"
        continue
      fi
    fi
    if has_conflict "$s" 2>/dev/null; then
      continue
    fi
    NEXT_SLUG="$s"
    return 0
  done
}

# Fill empty slots from the queue.
fill_slots() {
  while [ "${#SLOT_PIDS[@]}" -lt "$SLOTS" ]; do
    pop_next
    [ -z "$NEXT_SLUG" ] && break
    if ! claim_task "$NEXT_SLUG"; then
      echo "  ~ $NEXT_SLUG — already claimed elsewhere, skipping"
      DONE_SLUGS+=("$NEXT_SLUG")
      continue
    fi
    local pid=""
    # A lost region race is not an error — reroute to the next candidate.
    if ! pid=$(launch_plan "$NEXT_SLUG") || [ -z "$pid" ]; then
      DONE_SLUGS+=("$NEXT_SLUG")
      continue
    fi
    SLOT_PIDS+=("$pid")
    SLOT_SLUGS+=("$NEXT_SLUG")
    SLOT_START+=("$(date +%s)")
  done
}

# Initial fill.
fill_slots

[ "${#SLOT_PIDS[@]}" -eq 0 ] && {
  echo "[do-fleet] no disjoint plans to launch — all candidates conflicted or in-flight"
  exit 0
}

echo "[do-fleet] ${#SLOT_PIDS[@]} slot(s) live. PIDs: ${SLOT_PIDS[*]}"
echo "[do-fleet] tail a plan:  tail -f .do-worktrees/<slug>/.fleet.log"
echo ""

# Event loop: poll until all slots empty and queue exhausted.
while [ "${#SLOT_PIDS[@]}" -gt 0 ]; do
  sleep "$POLL"

  NEW_PIDS=()
  NEW_SLUGS=()
  NEW_START=()
  for idx in "${!SLOT_PIDS[@]}"; do
    pid="${SLOT_PIDS[$idx]}"
    slug="${SLOT_SLUGS[$idx]}"
    start="${SLOT_START[$idx]}"

    if kill -0 "$pid" 2>/dev/null; then
      # Still running — check stall.
      now=$(date +%s)
      age=$(( now - start ))
      if [ "$age" -gt "$STALL_TIMEOUT" ]; then
        echo "[do-fleet] ⚠ $slug stalled (${age}s > ${STALL_TIMEOUT}s) — killing PID $pid"
        kill "$pid" 2>/dev/null || true
        free_dirs "$slug"
        STALLED+=("$slug")
        DONE_SLUGS+=("$slug")
        DONE_COUNT=$(( DONE_COUNT + 1 ))
        echo "[do-fleet]   stalled: $slug"
      else
        NEW_PIDS+=("$pid")
        NEW_SLUGS+=("$slug")
        NEW_START+=("$start")
      fi
    else
      # Finished.
      DONE_COUNT=$(( DONE_COUNT + 1 ))
      DONE_SLUGS+=("$slug")
      free_dirs "$slug"
      echo "[do-fleet] ✓ $slug exited (slot freed, $DONE_COUNT done)"
    fi
  done

  SLOT_PIDS=(); [ "${#NEW_PIDS[@]}" -gt 0 ] && SLOT_PIDS=("${NEW_PIDS[@]}")
  SLOT_SLUGS=(); [ "${#NEW_SLUGS[@]}" -gt 0 ] && SLOT_SLUGS=("${NEW_SLUGS[@]}")
  SLOT_START=(); [ "${#NEW_START[@]}" -gt 0 ] && SLOT_START=("${NEW_START[@]}")

  # Refill freed slots.
  fill_slots

  # Progress line.
  live="${#SLOT_PIDS[@]}"
  remaining=$(( ${#QUEUE[@]} - ${#DONE_SLUGS[@]} - live ))
  echo "[do-fleet] live=$live · done=$DONE_COUNT · queued=$remaining"
done

echo ""
echo "[do-fleet] all plans exited. $DONE_COUNT completed, ${#STALLED[@]} stalled."
[ "${#STALLED[@]}" -gt 0 ] && echo "[do-fleet] stalled: ${STALLED[*]}"
echo "[do-fleet] merges are NOT automated — review each .do-worktrees/<slug>/.do-digest.md; land one at a time."
echo "[do-fleet] gc: after merging, run — .claude/scripts/do-auto.sh --gc"
