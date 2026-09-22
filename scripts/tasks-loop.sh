#!/usr/bin/env bash
# tasks-loop.sh — the task board as a continuously-running loop.
#
# Each pass does three things, in this order:
#   0. REAP     sweep stranded `picked` leases back to `open`. This is the half
#               atomicity does NOT fix: a lease whose owner died is invisible to
#               the claimable view and blocks every dependent via ready-tasks.
#               It runs FIRST so this pass can claim what it just freed.
#   1. ACCEPTS  re-run every seed row's `accept:` check. Green ⇒ the task is
#               done in the tree; it is not filed (and is reported as settled).
#   2. SEED     file every still-RED seed row that is not on the board yet,
#               tagged with its BARE-WORD stake.
#   3. CLAIM    lease up to --claims tasks this pass.
#
# SAFE-BY-DEFAULT: it prints what it would do and writes NOTHING unless --live.
# The board lives in PRODUCTION TypeDB (there is no separate task store — dev
# and prod share it), so a dry run is the honest default.
#
#   bash .claude/scripts/tasks-loop.sh --accepts   # just score the checks
#   bash .claude/scripts/tasks-loop.sh --once      # one pass, DRY
#   bash .claude/scripts/tasks-loop.sh --once --live
#   bash .claude/scripts/tasks-loop.sh --live      # continuous
#   bash .claude/scripts/tasks-loop.sh --status    # read liveness, don't guess
#   bash .claude/scripts/tasks-loop.sh --stop
#
# Liveness is a PUBLISHED FILE, never `ps | grep`. --status reads it.
#
# ── why this loop is safe to run beside other fleets ────────────────────────
# `tasks:claim` is ATOMIC as of 2026-08-26: one guarded TypeDB pipeline, one
# commit, and the loser of a race is refused at commit time with
#   "[STC2] Commit ... failed with isolation conflict: Transaction uses a lock
#    held by a concurrent commit."
# Proven both ways by `node .claude/scripts/tasks-claim-race.mjs` (which also
# demonstrates its own red half). So a second claimer here cannot double-lease.
# This loop is therefore NOT single-claimer-by-construction; it is safe because
# the seam underneath it was fixed. If that harness ever stops passing, drop
# CLAIMS_PER_PASS to 0 until it does again.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEED="${TASKS_SEED:-$ROOT/.claude/tasks/seed.tsv}"
STATE_DIR="${TMPDIR:-/tmp}/one-tasks-loop"
LIVE="$STATE_DIR/live.json"
LOG="$STATE_DIR/loop.log"
LOCK="$STATE_DIR/lock"
STOP="$STATE_DIR/stop"
FILED="$STATE_DIR/filed"        # slugs already filed by this loop
INTERVAL="${TASKS_LOOP_INTERVAL:-300}"
CLAIMS_PER_PASS="${TASKS_LOOP_CLAIMS:-1}"
WS="${CC_TASKS_WORKSPACE:-one}"
DRY=true
mkdir -p "$STATE_DIR"; touch "$FILED"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[%s] %s\n' "$(now)" "$*" | tee -a "$LOG"; }

publish() {  # publish(state, detail, red, green, filed, claimed)
  cat > "$LIVE" <<JSON
{"state":"$1","pid":$$,"detail":"$2","red":$3,"green":$4,"filed":$5,"claimed":$6,"dry":$DRY,"workspace":"$WS","at":"$(now)","interval":$INTERVAL,"log":"$LOG"}
JSON
}

# rows() — the seed, comments and blanks stripped.
rows() { grep -v '^#' "$SEED" | grep -v '^[[:space:]]*$'; }

# score_accepts — run every accept check. Prints "RED <slug>" / "GREEN <slug>".
# An accept that exits 0 means the work is already in the tree.
score_accepts() {
  local red=0 green=0
  while IFS=$'\t' read -r slug title tags accept; do
    [ -z "${slug:-}" ] && continue
    if ( cd "$ROOT" && eval "$accept" ) >/dev/null 2>&1; then
      echo "GREEN $slug"; green=$((green+1))
    else
      echo "RED   $slug"; red=$((red+1))
    fi
  done < <(rows)
  echo "# red=$red green=$green"
}

case "${1:-}" in
  --status)
    if [ ! -f "$LIVE" ]; then echo "no loop has ever published liveness here ($LIVE)"; exit 1; fi
    cat "$LIVE"
    pid=$(sed -n 's/.*"pid":\([0-9]*\).*/\1/p' "$LIVE")
    if kill -0 "$pid" 2>/dev/null; then echo "owner pid $pid is ALIVE"
    else echo "owner pid $pid is GONE — this file is a record, not a running loop"; fi
    exit 0 ;;
  --stop) touch "$STOP"; echo "stop requested — the loop exits after its current pass"; exit 0 ;;
  --accepts) score_accepts; exit 0 ;;
esac

ONCE=false
for a in "$@"; do
  case "$a" in
    --live) DRY=false ;;
    --once) ONCE=true ;;
    --claims=*) CLAIMS_PER_PASS="${a#*=}" ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

# single instance — mkdir(2) is atomic; macOS ships no flock(1)
if ! mkdir "$LOCK" 2>/dev/null; then
  owner=$(cat "$LOCK/pid" 2>/dev/null || echo "?")
  if [ "$owner" != "?" ] && kill -0 "$owner" 2>/dev/null; then
    echo "[tasks-loop] already running as pid $owner — refusing to double-file"; exit 1
  fi
  echo "[tasks-loop] reaping dead lock (pid $owner)"; rm -rf "$LOCK"; mkdir "$LOCK" || exit 1
fi
echo $$ > "$LOCK/pid"
rm -f "$STOP"
cleanup() { rm -rf "$LOCK"; publish stopped "loop exited" 0 0 0 0; }
trap cleanup EXIT INT TERM

log "start — seed=$SEED ws=$WS interval=${INTERVAL}s claims/pass=$CLAIMS_PER_PASS dry=$DRY"

one_pass() {
  local red=0 green=0 filed=0 claimed=0 reaped=0
  # 0. REAP — before anything else, so a freed lease is claimable this pass.
  if $DRY; then
    log "DRY would reap stranded leases in workspace $WS"
  else
    rout=$(CC_TASKS_WORKSPACE="$WS" bash "$ROOT/.claude/scripts/do-signal.sh" --task-reap 2>&1)
    case "$rout" in
      *'"reaped":[]'*) log "reap: nothing stranded" ;;
      *'"ok":true'*)   log "reap: ${rout:0:220}"; reaped=1 ;;
      *)               log "reap inconclusive: ${rout:0:220}" ;;
    esac
  fi
  publish scoring "running accept checks" 0 0 0 0
  while IFS=$'\t' read -r slug title tags accept; do
    [ -z "${slug:-}" ] && continue
    if ( cd "$ROOT" && eval "$accept" ) >/dev/null 2>&1; then
      green=$((green+1))
      log "SETTLED $slug — accept is green, not filing"
      continue
    fi
    red=$((red+1))
    grep -qx "$slug" "$FILED" && continue
    if $DRY; then
      log "DRY would file: $slug [$tags] — $title"
    else
      if CC_TASKS_WORKSPACE="$WS" bash "$ROOT/.claude/scripts/do-signal.sh" \
           --task-create "$slug" "$title" "tags=$tags" "notes=accept: $accept" >>"$LOG" 2>&1; then
        echo "$slug" >> "$FILED"; log "FILED $slug [$tags]"
      else
        log "file FAILED $slug — see $LOG"
      fi
    fi
    filed=$((filed+1))
  done < <(rows)

  # CLAIM — bounded per pass. Atomic at the seam (see header), so a concurrent
  # fleet claiming the same slug is refused, not silently co-granted.
  local n=0
  while IFS=$'\t' read -r slug title tags accept; do
    [ -z "${slug:-}" ] && continue
    [ "$n" -ge "$CLAIMS_PER_PASS" ] && break
    grep -qx "$slug" "$FILED" || $DRY || continue
    if $DRY; then
      log "DRY would claim: $slug"
    else
      out=$(CC_TASKS_WORKSPACE="$WS" bash "$ROOT/.claude/scripts/do-signal.sh" --task-claim "$slug" 2>&1)
      case "$out" in
        *already-claimed*) log "SKIP $slug — already leased (that is the atomic guard working)" ;;
        *'"ok":true'*)     log "CLAIMED $slug"; claimed=$((claimed+1)) ;;
        *)                 log "claim inconclusive $slug: ${out:0:160}" ;;
      esac
    fi
    n=$((n+1))
  done < <(rows)

  publish idle "pass complete" "$red" "$green" "$filed" "$claimed"
  log "pass: red=$red green=$green filed=$filed claimed=$claimed reaped=$reaped"
}

if $ONCE; then one_pass; exit $?; fi
while true; do
  one_pass || true
  for _ in $(seq 1 "$INTERVAL"); do
    [ -f "$STOP" ] && { log "stop file seen — exiting"; exit 0; }
    sleep 1
  done
done
