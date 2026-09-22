#!/usr/bin/env bash
# Internal: emit world:do-event signals at /do phase boundaries, and drive the
# tasks:create/claim/link verbs so a /do plan's own lifecycle IS a substrate
# task's lifecycle (text/tasks-do-plan.md C1 — the shared-atom wire).
# Called by do-auto.sh at plan arm, cycle open, cycle close, and halt. Not a
# user command.
#
# Usage:
#   do-signal.sh [--print] <type> <slug> <tier> <cycle> [key=value ...]
#   do-signal.sh [--print] --task-create <slug> <title> [tags=a,b,c] [notes=...]
#   do-signal.sh [--print] --task-claim  <slug>
#   do-signal.sh [--print] --task-plan   <slug>   # one task per cycle
#   do-signal.sh [--print] --task-reap
#   do-signal.sh [--print] --task-link   <slug> [docs=a,b,c]
#   do-signal.sh [--print] --task-heartbeat <slug> <body>
#   do-signal.sh [--print] --outcome <slug> tags=a,b actor=<aid> success=<bool> [weight=<n>]
#
# --print: write JSON to stdout without POSTing (tests + dry runs).
# Extra key=value pairs are merged into the world:do-event payload.
#   axis=security,structure  → adds s:security + s:structure tags + "axis" field
#   composite=0.82           → numeric field (no quotes)
#   wave=W3                  → string field
#   deliverable=...          → string field
#
# Env overrides:
#   DO_SIGNAL_URL  default: https://one.ie
#   ONE_ENV_FILE   default: one.ie/web/.env  (read SERVER_SECRET for auth)
#   DO_ENV_FILE    accepted as an alias for ONE_ENV_FILE (kept for callers)
#
# world:do-event failure never blocks the build loop — callers wrap with `|| true`.
# tasks:* (create/claim/link/heartbeat) propagate failure so callers can log it;
# they must still not abort the build (capture the exit, continue).
set -euo pipefail

PRINT=false
# Credentials come from ONE_ENV_FILE, so the harness runs with no one.ie/web/
# on disk. DO_ENV_FILE stays an accepted alias — it predates the generalisation.
ONE_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
DO_ENV_FILE="$ONE_ENV_FILE"
DO_SIGNAL_URL="${DO_SIGNAL_URL:-https://one.ie}"

_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Monorepo fallbacks. Unquoted on purpose: they expand to nothing outside the
# monorepo, so the loop degrades to ONE_ENV_FILE alone rather than erroring.
_MONOREPO_ENV_CANDIDATES="$_ROOT/one.ie/web/.env $_ROOT/one.ie/web/.secrets.generated.local $_ROOT/one.ie/web/.dev.vars"

# Shared SERVER_SECRET lookup — /api/signal/world:do-event checks this (see
# world:do-event POST at the bottom of this file).
_server_secret() {
  local _f _v
  for _f in "$ONE_ENV_FILE" "$_ROOT/.env" $_MONOREPO_ENV_CANDIDATES; do
    [ -f "$_f" ] || continue
    # DO_SIGNAL_SKIP_FALLBACKS=1 → ONE_ENV_FILE is the WHOLE ladder. Without it the
    # no-secret state is unreachable from inside the monorepo (_ROOT resolves to a
    # tree that carries a real .env), so the dark-cycle guard could not be proven.
    if [ "${DO_SIGNAL_SKIP_FALLBACKS:-0}" = "1" ] && [ "$_f" != "$ONE_ENV_FILE" ]; then continue; fi
    _v=$(grep -E '^SERVER_SECRET=' "$_f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//' || true)
    [ -n "$_v" ] && { printf '%s' "$_v"; return 0; }
  done
  printf ''
}

# GATEWAY_API_KEY lookup — /api/ask/<receiver> (the tasks:* verbs) checks THIS,
# not SERVER_SECRET (one.ie/web/src/pages/api/ask/[...receiver].ts isServiceCaller).
# Presenting SERVER_SECRET there resolves to no service caller, no ctx.ownerSlug,
# and every tasks:* resolver returns {error:"workspace required"} — verified
# 2026-07-17, zero do-signal task-create/claim/link calls had ever landed in prod.
_gateway_key() {
  local _f _v
  for _f in "$ONE_ENV_FILE" "$_ROOT/.env" $_MONOREPO_ENV_CANDIDATES; do
    [ -f "$_f" ] || continue
    _v=$(grep -E '^GATEWAY_API_KEY=' "$_f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//' || true)
    [ -n "$_v" ] && { printf '%s' "$_v"; return 0; }
  done
  printf ''
}

# POST a JSON payload to /api/ask/<receiver> with bearer auth. Board writes
# (tasks:*) must not disguise failure as ok: curl errors and a body without
# `"ok":true` (HTTP 200 wrapping {error:...} is the TypeDB-down case) exit
# non-zero. Prints the response body. Callers log and continue.
_post_ask() {
  local _receiver="$1" _payload="$2" _secret _authcfg _url _resp _rc=0
  _secret="$(_gateway_key)"
  _url="${DO_SIGNAL_URL}/api/ask/${_receiver}"
  if [ -n "$_secret" ]; then
    _authcfg="$(mktemp)"; chmod 600 "$_authcfg"
    printf 'header = "Authorization: Bearer %s"\n' "$_secret" > "$_authcfg"
    _resp=$(curl -sf -X POST "$_url" -H "Content-Type: application/json" --config "$_authcfg" -d "$_payload" 2>/dev/null) || _rc=$?
    rm -f "$_authcfg"
  else
    _resp=$(curl -sf -X POST "$_url" -H "Content-Type: application/json" -d "$_payload" 2>/dev/null) || _rc=$?
  fi
  printf '%s' "$_resp"
  if [ "$_rc" -eq 0 ]; then
    case "$_resp" in
      *'"ok":true'*) ;;
      *) _rc=1 ;;
    esac
  fi
  return "$_rc"
}

# _jsonesc — JSON-escape a value before it is interpolated into a payload
# string. EVERY free-text field must go through this. Measured 2026-08-26: a
# task filed with `notes=accept: ! grep -q "x" f.ts` produced
#   "notes":"accept: ! grep -q "x" f.ts"
# — malformed JSON, and the create failed. Titles carry quotes just as often.
_jsonesc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' | tr -d '\n\r'; }

# Every task this harness files lands in one workspace — /u/one/tasks — so a
# human never has to hunt across slugs for Claude Code's own work. Overridable
# for a differently-branded harness fork; unset means "one" (same convention
# as CC_WORLD_SLUG in hooks/lib/signal.sh). ctx.ownerSlug resolves straight to
# this value (nominated via GATEWAY_API_KEY auth above), so every tasks:*
# resolver's actor/owner/workspace tag is this slug, not whatever ambient
# session happened to be attested.
CC_TASKS_WORKSPACE="${CC_TASKS_WORKSPACE:-one}"

# CC_TASKS_AUTHOR — WHO the comment is from, when it is not simply "the
# workspace". tasks:comment records an author on the message and the inbox draws
# it (three directors on one task read as three speakers, not one anonymous
# run), but a field no caller supplies is a field production never sets: this
# script and the MCP door are the two writers, and both built their payload with
# tid/workspace/body only, so every /do close and every wave heartbeat landed
# `authorKind:"staff"`. The receiver honours the field only for an ATTESTED
# staff caller — which is exactly what GATEWAY_API_KEY auth above makes this
# script — and validates the slug shape; a caller that cannot be attested names
# nobody. UNSET is the default and emits the byte-identical payload this script
# has always sent, so nothing changes for a harness that does not set it.
CC_TASKS_AUTHOR="${CC_TASKS_AUTHOR:-}"
_author_json() {  # emits `,"author":"<slug>"` or nothing
  [ -n "$CC_TASKS_AUTHOR" ] || return 0
  printf ',"author":"%s"' "$CC_TASKS_AUTHOR"
}

# signal_tasks_create — plan arm: files an open task tagged slug:<slug>, so the
# plan appears in tasks:everywhere the moment it's armed (C1/C2 interface contract).
signal_tasks_create() {  # signal_tasks_create <slug> <title> [tags=a,b,c] [notes=...]
  local slug="$1" title="$2" tags="slug:${1}" notes=""
  shift 2
  for kv in "$@"; do
    case "${kv%%=*}" in
      tags)  tags="${tags},${kv#*=}" ;;
      notes) notes="${kv#*=}" ;;
    esac
  done
  local tags_json; tags_json=$(printf '%s' "$tags" | awk -F',' '{for(i=1;i<=NF;i++){printf "%s\"%s\"", (i>1?",":""), $i}}')
  local title_esc notes_esc
  title_esc="$(_jsonesc "$title")"; notes_esc="$(_jsonesc "$notes")"
  local payload="{\"data\":{\"title\":\"${title_esc}\",\"workspace\":\"${CC_TASKS_WORKSPACE}\",\"tags\":[${tags_json}]${notes:+,\"notes\":\"${notes_esc}\"}}}"
  if $PRINT; then printf '%s\n' "$payload"; return 0; fi
  _post_ask "tasks:create" "$payload"
}

# signal_tasks_plan — file EVERY cycle of a plan as its own task, once.
#
# WHY. The loop filed exactly ONE task per plan (do-auto.sh's `.task-created`
# sentinel) and nothing else. Measured 2026-09-01: text/lifecycle-todo.md carries
# 10 cycles and its promise 13 deliverables -- 1 task reached the substrate.
# `signal_tasks_cycle` (the per-cycle status writer, and its --task-cycle flag)
# was already written and had ZERO callers, because the tasks it sets status on
# were never created: _tid_for_slug found nothing and it returned 1 every time.
#
# So the substrate could not answer "which cycles are ready" -- and that is
# exactly why do-next.sh re-derives readiness by PARSING MARKDOWN CHECKBOXES, a
# second source of truth whose divergences are most of this repo's scars.
#
# The cycle list is read from do-plan-json.sh, which is a parser, not a model.
# tasks:create dedupes on the slug tag, so re-running a plan is idempotent.
signal_tasks_plan() {  # signal_tasks_plan <slug>
  # ONE MINTER (2026-09-12). This used to file the cycles itself — flat, unchained,
  # tagged `slug:<slug>-C1` in UPPER case. SLUG_RE is lowercase-only, so those rows
  # never deduped on re-arm and `--task-cycle` (which lowercases) closed a DIFFERENT
  # row: the armed rows sat open forever. do-board.sh mints the same rows chained
  # (`tasks:subtask` + blockedBy from the batch DAG), tagged `slug:<slug>-c<n>` —
  # the exact tag _tid_for_slug resolves — so the existing --task-cycle close moves
  # THESE rows and the gate unblocks the next batch by itself.
  local slug="$1"
  if $PRINT; then bash "$_ROOT/.claude/scripts/do-board.sh" "$slug" --dry-run; return $?; fi
  bash "$_ROOT/.claude/scripts/do-board.sh" "$slug"
}

# signal_tasks_claim — cycle open: leases the plan's substrate task so a fleet
# run (or a human) never double-builds the same slug (do-fleet.sh mirrors this).
# _tid_for_slug <slug> [title] — resolve a plan slug to its task tid, and cache it.
#
# The SERVER's slug→tid resolver is broken in prod: measured 2026-08-31, every
# tasks:claim/link/heartbeat addressed by `slug` returns not_found, while the
# same task claimed by `tid` succeeds. That cost a whole campaign's board
# visibility — the /do engine's claim, six heartbeats and link all failed exit 1
# on every run, silently, because nothing treats a board write as load-bearing.
#
# `tasks:create` is idempotent — it dedupes on the `slug:` tag and returns the
# EXISTING tid — so create IS a working slug→tid resolver. One call adds the task
# if missing and resolves it if present, which is also the simplest thing for a
# human: there is no separate "add" step to forget.
#
# Cached under .claude/.task-tids/<slug> so the steady state is zero round-trips.
_tid_for_slug() {
  local slug="$1" title="${2:-}" dir="$_ROOT/.claude/.task-tids" f tid resp
  f="$dir/$slug"
  if [ -f "$f" ]; then tid=$(cat "$f" 2>/dev/null); [ -n "$tid" ] && { printf '%s' "$tid"; return 0; }; fi
  [ -n "$title" ] || title="$slug — /do plan"
  resp=$(signal_tasks_create "$slug" "$title" 2>/dev/null) || true
  tid=$(printf '%s' "$resp" | sed -n 's/.*"tid":"\([^"]*\)".*/\1/p')
  [ -n "$tid" ] || { printf ''; return 1; }
  mkdir -p "$dir" && printf '%s' "$tid" > "$f"
  printf '%s' "$tid"
}

# signal_tasks_cycle <slug> <cid> <status> — the per-CYCLE board row.
#
# The plan-level task says "lifecycle is being worked on". It cannot show the
# thing an operator actually wants to watch: which cycle is in flight and which
# ones are finished. This files one row per cycle (slug `<plan>-<cid>`, tagged
# with the plan) and moves it open -> picked -> done as the engine runs.
#
# create is idempotent (dedupes on the slug: tag), so calling this on every cycle
# open is safe and needs no separate "add" step. Status is addressed by tid,
# because prod's slug resolver returns not_found (see _tid_for_slug).
signal_tasks_cycle() {  # signal_tasks_cycle <slug> <cid> <status>
  local slug="$1" cid="$2" st="${3:-picked}" cslug tid
  cslug="$(printf '%s-%s' "$slug" "$cid" | tr '[:upper:]' '[:lower:]')"
  tid=$(_tid_for_slug "$cslug" "${slug} ${cid}") || true
  [ -n "$tid" ] || return 1
  _post_ask "tasks:status" "{\"data\":{\"tid\":\"${tid}\",\"workspace\":\"${CC_TASKS_WORKSPACE}\",\"status\":\"${st}\"}}"
}

signal_tasks_claim() {  # signal_tasks_claim <slug>
  # Address the lease by the plan SLUG, not a guessed tid: create returns a random
  # task:<traceId>, so "task:<slug>" never matched — claim silently 404'd for every /do
  # run until this. The server resolves slug → tid (resolvers/tasks.ts resolveTaskBySlug).
  local slug="$1" tid
  # THE LEASE MOVES TO THE CYCLE. Once do-board.sh hangs cycle rows off the plan
  # row (`containment`), blockersResolved refuses `picked` on the parent while any
  # child is open — so a claim on the plan row reads `blocked` for the whole run.
  # Claim the FIRST OPEN CYCLE's row instead: the thing actually in flight, gated by
  # its own batch predecessors, which is the DAG doing its job. Falls back to the
  # plan row for an unmirrored plan.
  tid=$(DO_PLAN_TODO="${DO_PLAN_TODO:-}" bash "$_ROOT/.claude/scripts/do-plan-json.sh" "$slug" 2>/dev/null \
        | jq -r '.cycleRows[.openCycles[0]] // empty' 2>/dev/null) || true
  [ -n "$tid" ] || tid=$(_tid_for_slug "$slug") || true
  local payload
  if [ -n "$tid" ]; then
    payload="{\"data\":{\"tid\":\"${tid}\",\"workspace\":\"${CC_TASKS_WORKSPACE}\"}}"
  else
    payload="{\"data\":{\"slug\":\"${slug}\",\"workspace\":\"${CC_TASKS_WORKSPACE}\"}}"
  fi
  if $PRINT; then printf '%s\n' "$payload"; return 0; fi
  _post_ask "tasks:claim" "$payload"
}

# signal_tasks_reap — the stranded-lease sweep. `tasks:claim` is atomic, so no
# two workers double-lease; this is the OTHER half — a lease whose owner died is
# `picked` forever, invisible to the claimable view and blocking every dependent
# via ready-tasks. Nothing else in the system goes looking for those rows.
signal_tasks_reap() {  # signal_tasks_reap
  local payload="{\"data\":{\"workspace\":\"${CC_TASKS_WORKSPACE}\"}}"
  if $PRINT; then printf '%s\n' "$payload"; return 0; fi
  _post_ask "tasks:reap" "$payload"
}

# signal_tasks_link — cycle close: records the handoff-completion back on the
# origin task (provenance line + task-status:done), same shape lifecycle.ts's
# tasks_link MCP tool posts.
# signal_outcome — /close's loop-closer, and the reason it is world:outcome.
#
# THE NAMING GAP, measured. `/api/receivers/signals` ranks every emitted signal
# name as declared | candidate | unhomed against packages/sdk/src/receivers.ts,
# because 35 distinct event names were emitted in 90 days and exactly ONE
# (`world:in`) was a declared receiver. /close was a top contributor: measured
# 2026-09-09, `do:close` 0, `loop:feedback` 0, `world:do-event` 0 declarations —
# three of the four names it emitted could not be answered by anything, and it
# reported success anyway.
#
# `world:outcome` is not a new contract written for this. It already says exactly
# what /close does: "whoever consumed a route reports success/failure, moving the
# same tag->receiver paths the router reads - success marks, failure warns."
# So the fix converges four names to one and designs nothing.
#
# THE VERB IS READ BACK, NEVER ASSUMED. The receiver answers
# {ok, outcome:"marked"|"warned", ...}; a caller that prints "marked" because it
# sent success:true is reporting its own intent, which is the class of defect the
# whole four-outcome grammar exists to stop.
#
# TAGS ARE BARE WORDS. `marketing`, never `lifecycle:marketing` - a namespaced
# tag matches zero subscribers. `slug:`/`cycle:` are provenance, not stakes, and
# are appended separately so they can never be mistaken for a routable tag.
signal_outcome() {  # signal_outcome <slug> tags=a,b actor=<aid> success=<bool> weight=<n> [workspace=<ws>]
  local slug="$1"; shift
  local tags="" actor="" success="true" weight="" ws="${CC_TASKS_WORKSPACE}"
  local kv
  for kv in "$@"; do
    case "$kv" in
      tags=*)      tags="${kv#*=}" ;;
      actor=*)     actor="${kv#*=}" ;;
      success=*)   success="${kv#*=}" ;;
      weight=*)    weight="${kv#*=}" ;;
      workspace=*) ws="${kv#*=}" ;;
    esac
  done
  [ -n "$slug" ]  || { echo "signal_outcome: slug required" >&2; return 2; }
  [ -n "$actor" ] || { echo "signal_outcome: actor= required (world:outcome moves that actor's paths)" >&2; return 2; }
  case "$success" in true|false) ;; *) echo "signal_outcome: success must be true|false" >&2; return 2 ;; esac

  # A namespaced word here would route to nobody. Refuse it loudly rather than
  # emit a signal that matches zero subscribers and still exits 0.
  local t
  for t in ${tags//,/ }; do
    case "$t" in
      slug:*|cycle:*) ;;
      *:*) echo "signal_outcome: '$t' is namespaced - stake tags are BARE words (see subscribe-tags-parity.test.ts)" >&2; return 2 ;;
    esac
  done

  tags="${tags:+${tags},}slug:${slug}"
  local tags_json
  tags_json=$(printf '%s' "$tags" | awk -F',' '{for(i=1;i<=NF;i++){if($i!=""){printf "%s\"%s\"", (n++?",":""), $i}}}')

  local payload="{\"data\":{\"tags\":[${tags_json}],\"actor\":\"$(_jsonesc "$actor")\",\"success\":${success}${weight:+,\"weight\":${weight}},\"slug\":\"$(_jsonesc "$slug")\",\"workspace\":\"$(_jsonesc "$ws")\"}}"
  if $PRINT; then printf '%s\n' "$payload"; return 0; fi
  _post_ask "world:outcome" "$payload"
}

signal_tasks_link() {  # signal_tasks_link <slug> [docs=a,b,c]
  # Slug-addressed like claim — the server resolves slug → the origin tid create wrote.
  local slug="$1" docs=""
  shift 1
  for kv in "$@"; do
    case "${kv%%=*}" in
      docs) docs="${kv#*=}" ;;
    esac
  done
  local docs_json=""
  [ -n "$docs" ] && docs_json=$(printf '%s' "$docs" | awk -F',' '{for(i=1;i<=NF;i++){printf "%s\"%s\"", (i>1?",":""), $i}}')
  local tid; tid=$(_tid_for_slug "$slug") || true
  local payload="{\"data\":{\"slug\":\"${slug}\"${tid:+,\"tid\":\"${tid}\"},\"workspace\":\"${CC_TASKS_WORKSPACE}\"${docs_json:+,\"docs\":[${docs_json}]}}}"
  if $PRINT; then printf '%s\n' "$payload"; return 0; fi
  # Prod's tasks:link still resolves by slug and ignores an explicit tid, so it
  # returns not_found for every /do close (measured 2026-08-31). Fall back to the
  # two tid-addressed verbs that DO work, so a close is never silently lost:
  # status:done is the state the board renders, the comment is the provenance line.
  if _post_ask "tasks:link" "$payload"; then return 0; fi
  [ -n "$tid" ] || return 1
  _post_ask "tasks:status" "{\"data\":{\"tid\":\"${tid}\",\"workspace\":\"${CC_TASKS_WORKSPACE}\",\"status\":\"done\"}}" >/dev/null || return 1
  _post_ask "tasks:comment" "{\"data\":{\"tid\":\"${tid}\",\"workspace\":\"${CC_TASKS_WORKSPACE}\",\"body\":\"/do close — ${slug}${docs:+ (docs: ${docs})}\"$(_author_json)}}"
}

# signal_tasks_heartbeat — batch/wave close: posts tasks:comment so the lease
# stays live (the comment resolver bumps updated-at-ms). Slug-addressed like
# claim/link; body is the wave-close note (e.g. "wave 2 close").
signal_tasks_heartbeat() {  # signal_tasks_heartbeat <slug> <body>
  local slug="$1"; shift
  local body="$*" body_esc
  body_esc="${body//\\/\\\\}"
  body_esc="${body_esc//\"/\\\"}"
  local tid; tid=$(_tid_for_slug "$slug") || true
  # tasks:comment lets `slug` OVERRIDE `tid`, so the slug must be omitted, not merely
  # accompanied, when the tid is known — otherwise the broken resolver runs anyway.
  local payload
  if [ -n "$tid" ]; then
    payload="{\"data\":{\"tid\":\"${tid}\",\"workspace\":\"${CC_TASKS_WORKSPACE}\",\"body\":\"${body_esc}\"$(_author_json)}}"
  else
    payload="{\"data\":{\"slug\":\"${slug}\",\"workspace\":\"${CC_TASKS_WORKSPACE}\",\"body\":\"${body_esc}\"$(_author_json)}}"
  fi
  if $PRINT; then printf '%s\n' "$payload"; return 0; fi
  _post_ask "tasks:comment" "$payload"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --print) PRINT=true; shift ;;
    # Report WHICH file credentials resolved from, never the value. This is how
    # factory-repo.sh --check-env-indirection proves the override is real
    # behaviour rather than a grep for a variable name.
    --print-env)
      _which=""
      for _f in "$ONE_ENV_FILE" "$_ROOT/.env" $_MONOREPO_ENV_CANDIDATES; do
        [ -f "$_f" ] || continue
        grep -qE '^(SERVER_SECRET|GATEWAY_API_KEY)=.' "$_f" 2>/dev/null || continue
        _which="$_f"; break
      done
      printf 'resolved-from: %s\n' "${_which:-<none>}"
      exit 0 ;;
    --task-create)     shift; signal_tasks_create "$@"; exit $? ;;
    --task-claim)      shift; signal_tasks_claim "$@"; exit $? ;;
    --task-cycle)      shift; signal_tasks_cycle "$@"; exit $? ;;
    --task-plan)       shift; signal_tasks_plan  "$@"; exit $? ;;
    --task-reap)       shift; signal_tasks_reap "$@"; exit $? ;;
    --task-link)       shift; signal_tasks_link "$@"; exit $? ;;
    --task-heartbeat)  shift; signal_tasks_heartbeat "$@"; exit $? ;;
    --outcome)         shift; signal_outcome "$@"; exit $? ;;
    *) break ;;
  esac
done

if [ "$#" -lt 4 ]; then
  echo "usage: do-signal.sh [--print] <type> <slug> <tier> <cycle> [key=value ...]" >&2
  echo "       do-signal.sh [--print] --task-create|--task-claim|--task-link|--task-heartbeat <slug> ..." >&2
  echo "       do-signal.sh [--print] --outcome <slug> tags=a,b actor=<aid> success=<bool> [weight=<n>]" >&2
  exit 1
fi

TYPE="$1"; SLUG="$2"; TIER="$3"; CYCLE="$4"; shift 4

# Core tags — all match ^(do|tier|slug|cycle|s):
TAGS="\"do:cycle\",\"slug:${SLUG}\",\"tier:${TIER}\",\"cycle:${CYCLE}\""
case "$TYPE" in
  aim)    TAGS="${TAGS},\"do:aim\""                 ;;
  wave)   TAGS="${TAGS},\"do:wave\",\"do:build\""   ;;
  verify) TAGS="${TAGS},\"do:verify\""              ;;
  learn)  TAGS="${TAGS},\"do:learn\""               ;;
  halt)   TAGS="${TAGS},\"do:halt\""                ;;
esac

# Parse extra key=value pairs into the payload.
EXTRA_JSON=""
for kv in "$@"; do
  k="${kv%%=*}"; v="${kv#*=}"
  case "$k" in
    axis)
      # comma-list → s:* tags + "axis" field
      _a="${v}"
      while [ -n "$_a" ]; do
        _item="${_a%%,*}"
        TAGS="${TAGS},\"s:${_item}\""
        [ "$_a" = "$_item" ] && break
        _a="${_a#*,}"
      done
      EXTRA_JSON="${EXTRA_JSON},\"axis\":\"${v}\""
      ;;
    composite)
      EXTRA_JSON="${EXTRA_JSON},\"${k}\":${v}"
      ;;
    worktags)
      # comma-list → JSON array field. The plan's task-vocabulary tags (dept + topics);
      # the reputation harvest credits these tag-nodes (text/reputation.md § Slice A).
      _wt=""; _w="${v}"
      while [ -n "$_w" ]; do
        _witem="${_w%%,*}"
        [ -n "$_witem" ] && _wt="${_wt:+${_wt},}\"${_witem}\""
        [ "$_w" = "$_witem" ] && break
        _w="${_w#*,}"
      done
      EXTRA_JSON="${EXTRA_JSON},\"worktags\":[${_wt}]"
      ;;
    *)
      EXTRA_JSON="${EXTRA_JSON},\"${k}\":\"${v}\""
      ;;
  esac
done

# is_test discriminator. An emission aimed anywhere but production is a test run by
# construction, so it defaults to dev; a real prod cycle is a real run and stays
# is_test=0. There is no automatic way to tell a developer's experimental prod cycle
# from a genuine one, so that case is the operator's explicit DO_SIGNAL_ENV=dev —
# which this respects rather than overrides.
case "$DO_SIGNAL_URL" in
  https://one.ie|https://one.ie/) : ;;
  *) DO_SIGNAL_ENV="${DO_SIGNAL_ENV:-dev}" ;;
esac
# DO_SIGNAL_ENV rides in the payload so the receiver can flag the projected run
# is_test — those cycles are then filterable instead of polluting the operator's list.
[ -n "${DO_SIGNAL_ENV:-}" ] && EXTRA_JSON="${EXTRA_JSON},\"env\":\"${DO_SIGNAL_ENV}\""

PAYLOAD="{\"type\":\"${TYPE}\",\"slug\":\"${SLUG}\",\"tier\":\"${TIER}\",\"cycle\":${CYCLE},\"tags\":[${TAGS}]${EXTRA_JSON}}"

# SERVER_SECRET for the Authorization header — _server_secret() (defined above) is the
# one lookup, shared with the tasks:* verbs. .env historically lacks it;
# .secrets.generated.local is what push-prod-secrets.sh pushed to the worker, so it
# matches prod. Without a matching secret the POST is silently 401/403-dropped at the
# gateway (verified 2026-07-04 — zero do-* threads had ever landed in prod D1).
SERVER_SECRET="$(_server_secret)"

# Dark-cycle guard — resolved BEFORE the --print exit so a dry run reports the same
# state a real emit would hit. A worktree with no secret emits nothing, and the
# resulting gap in the run trace reads as "no cycles ran" rather than "the wire was
# down". One loud stderr line; stdout is untouched, so every existing --print
# consumer is unaffected.
if [ -z "$SERVER_SECRET" ]; then
  echo "[do-signal] dark: no secret (SERVER_SECRET unresolved from ${ONE_ENV_FILE}) — this cycle emits nothing" >&2
fi

if $PRINT; then
  printf '%s\n' "$PAYLOAD"
  exit 0
fi

# POST — fire-and-forget; failures are silent so the build loop is never blocked.
_url="${DO_SIGNAL_URL}/api/signal/world:do-event"
if [ -n "$SERVER_SECRET" ]; then
  # Token off argv (a bare -H "Authorization: Bearer ..." leaks via `ps aux` to any
  # local user for the life of the process) — write a private, one-shot curl config.
  _authcfg="$(mktemp)"
  chmod 600 "$_authcfg"
  printf 'header = "Authorization: Bearer %s"\n' "$SERVER_SECRET" > "$_authcfg"
  curl -sf -X POST "$_url" \
    -H "Content-Type: application/json" \
    --config "$_authcfg" \
    -d "$PAYLOAD" >/dev/null 2>&1 || true
  rm -f "$_authcfg"
else
  curl -sf -X POST "$_url" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" >/dev/null 2>&1 || true
fi
