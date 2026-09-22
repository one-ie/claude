#!/usr/bin/env bash
# do-close.sh — the universal end-of-workflow closer. Fast, bounded, honest.
#
# manifest: needs-env
#   Reads GATEWAY_API_KEY / SERVER_SECRET through ONE_ENV_FILE (default
#   one.ie/web/.env plus the monorepo fallbacks), exactly as do-signal.sh does.
#
# WHY IT EXISTS. `/close` was nine markdown steps a model walked by hand: read the
# rubric weights, POST four doors, settle the promise, propagate docs, write a
# report. Every step was deterministic and every step could hang — none of the
# curls it prescribed carried a timeout, so ONE dead door made the whole close
# read as a stall, and the usual repair was to skip the close entirely. A close
# that is skipped is Rule 1 broken: the signal never closes and the paths never
# learn. So the close is now a script, it is BOUNDED, and what it cannot do it
# FILES rather than drops.
#
# THE CONTRACT, in one line: close everything closable in one bounded pass; for
# everything else, leave a row that names the exact command that finishes it.
#
# THE HONESTY LAW (inherited verbatim from do-w4-gates.sh — same four states):
#     pass  : ran, exit 0
#     fail  : ran, non-zero — the close is real and the verdict is bad
#     unrun : could not run inside its budget, or its precondition was not met
#     n/a   : does not apply to this close (by rule, not by accident)
# An unrun leg is NOT a closed leg. `closed` is true only when there are ZERO
# fails and ZERO unruns. Every non-pass leg gets a ledger row and, where the
# board is reachable, a substrate task whose notes ARE the command to finish it.
#
# THE ONE DEPENDENCY EDGE. `task` (the board write that says done) depends on
# `gate`. Decoupling them rebuilds this repo's most expensive scar — cycles
# closed green at 0.92 with "tsc not measured, box saturated". A close with no
# receipt does not write `done`; it writes a row saying which command mints one.
#
# WHY IT NEVER RUNS THE SUITE. `/close` is a FULL-lane trigger and
# "a fast pass is never reported as a full pass" is locked. This script does not
# resolve that by swapping in the fast lane — it asks test-cached.sh whether THIS
# EXACT TREE already carries a full-suite receipt (TEST_CACHE_KEY_ONLY=1 prints
# the key, the stamp's presence is the answer, and the key is content-addressed
# so a neighbour's suite counts as yours). A memo HIT is free and it counts. No
# receipt is `unrun`, filed, and named — never a fast pass wearing a full badge.
#
# USAGE
#   do-close.sh [<slug>] [options]        close a slug / a workflow's tail
#   do-close.sh --pending                 the legs nothing has closed (exit 6 if any)
#   do-close.sh --self-test               fixtures + RED PROOFS
#
# OPTIONS
#   --tid <tid>            substrate task id to set status on
#   --workspace <slug>     board workspace                 (default: one)
#   --status <s>           done|failed|dissolved|timeout   (default: done)
#   --composite <0.NN>     cycle rubric composite          (default: unset)
#   --edge <from→to>       path the marks land on          (default: close:<slug>→result)
#   --dims k=v,...         security,stability,simplicity,speed[,integration]
#   --tags a,b             tags on the feedback signal
#   --only <leg,leg>       run only these legs — the retry door
#   --budget <secs>        whole-run wall clock            (default: 45)
#   --leg-budget <secs>    per-leg wall clock              (default: 12)
#   --notify               always ping the human, not only on an unfiled leg
#   --no-file              do not file board tasks (ledger only)
#   --strict               exit 1 when not fully closed (default: always exit 0)
#   --json                 machine-readable receipt on stdout
#   --no-metrics           legs + verdict only, no measured block
#   --reply                ALSO fold the enriched envelope back to the previous
#                          sender (CLOSE_SIGNAL_SENDER, else the origin)
#   --no-decide            file every open leg, decide nothing (the pre-2026-09-09
#                          behaviour — every blocker waits for a person)
#   --dry-run              plan the legs, touch nothing
#
# EXIT
#   0  ran and reported — the DEFAULT even when legs are open, because a closer
#      that fails its caller is a closer callers stop calling. `--strict` opts in.
#   1  --strict and not fully closed
#   6  --pending and rows are open
#   2  usage
#
# END OF EVERY WORKFLOW. Call it last, wrapped: `bash .claude/scripts/do-close.sh
# <slug> || true`. It is idempotent — the board writes dedupe, the ledger is
# keyed by <slug>:<leg>, and a leg that already passed is skipped on a re-run.
set -uo pipefail   # deliberately NOT -e: a closer must finish its report

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# CLOSE_LEDGER overrides the path — the self-test drives a sandbox ledger with it,
# and it MUST be resolved here, above --pending: an override applied later meant
# --pending read the real ledger while the run wrote the sandbox one, and the
# ledger red-proof passed on rows a previous check had left behind.
# THE LEDGER LIVES IN THE PRIMARY WORKTREE, never in $ROOT. `release.sh ship`
# runs deploy.sh from `.release/`, so $ROOT there is `.release` — a tree the next
# promote re-materialises away. Rows written there are invisible to `--pending`
# from main, on exactly the path where "files what it cannot close" matters most.
# `--git-common-dir` resolves to the primary tree's .git from any linked worktree;
# it is the same pin deploy-record.sh makes for the deploy record.
_primary_root() {
  local gcd
  gcd="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || { printf '%s' "$ROOT"; return; }
  [ -n "$gcd" ] && printf '%s' "$(dirname "$gcd")" || printf '%s' "$ROOT"
}
LEDGER="${CLOSE_LEDGER:-$(_primary_root)/.claude/.close-pending.jsonl}"
# MUST match the WRITER's default byte for byte. test-cached.sh:32 writes to
# ${TMPDIR:-/tmp}/one-test-cache and release.sh:56 reads the same; this file
# defaulted to $ROOT/.claude/.test-cache — a directory nothing creates and
# nothing writes. So `gate` answered "0/2 lane(s) stamped" on a tree whose
# receipts were sitting on disk, and because `task` is vetoed behind `gate`
# (the board write must never be decided around its gate), the board could
# never be told `done` by this closer at all.
#
# --self-test did not catch it and structurally could not: both gate probes set
# TEST_CACHE_DIR="$(mktemp -d)" explicitly, so the broken DEFAULT is the one
# path the red proof never exercises. A check that stubs the seam it is meant
# to guard proves the stub works.
CACHE_DIR="${TEST_CACHE_DIR:-${TMPDIR:-/tmp}/one-test-cache}"

# THE CLOSED LOOP ON THE DECISIONS THEMSELVES (Rule 1, applied one level up).
# A decision taken is not a decision proven. What licenses the NEXT auto-decision
# is what happened to the leg AFTER this one acted — so the previous run's
# `decided` rows are read here, before this run rewrites them, and settled below
# against this run's leg states. mark on pass, warn on still-open. Reading the
# command's exit code instead would measure the command, not the choice.
PRIOR_DECIDED=""
if [ -f "$LEDGER" ]; then
  PRIOR_DECIDED=$(grep -o '"k":"[^"]*","at[^}]*"decide":"taken:[a-z-]*"' "$LEDGER" 2>/dev/null \
    | sed -n 's/"k":"[^:]*:\([a-z]*\)".*"decide":"taken:\([a-z-]*\)"/\1 \2/p' || true)
fi

ONE_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
_MONOREPO_ENV_CANDIDATES="$ROOT/one.ie/web/.env $ROOT/one.ie/web/.dev.vars"

SLUG=""; TID=""; WORKSPACE="${CC_TASKS_WORKSPACE:-one}"; STATUS="done"
COMPOSITE=""; EDGE=""; DIMS=""; TAGS=""; ONLY=""
BUDGET="${CLOSE_BUDGET:-45}"; LEG_BUDGET="${CLOSE_LEG_BUDGET:-12}"
NOTIFY=0; NOFILE=0; STRICT=0; JSON=0; DRY=0; PENDING=0; SELFTEST=0; METRICS=1
# The decide layer is ON by default and that is the point: a blocker whose answer
# the substrate has already watched come good five times is not a question. It
# still cannot act under --dry-run (structural, do-decide.sh check 9) and it can
# never touch a vetoed fork.
DECIDE=1
# DECIDE_BIN exists for ONE reason: --self-test drives a gutted COPY of the real
# do-decide.sh (its `_verdict` short-circuited to `highway`) so the taken path is
# proven without writing five fake marks onto a live decision path. Seeding the
# oracle to test the reader would make the test the evidence.
DECIDE_BIN="${DECIDE_BIN:-$ROOT/.claude/scripts/do-decide.sh}"
# The return leg is OPT-IN. A close with no caller has nobody to reply to, and a
# reply nobody asked for is one more signal in a world that already routes.
REPLY="${CLOSE_REPLY:-0}"

while [ $# -gt 0 ]; do
  case "$1" in
    --tid) TID="${2:-}"; shift 2 ;;
    --workspace) WORKSPACE="${2:-one}"; shift 2 ;;
    --status) STATUS="${2:-done}"; shift 2 ;;
    --composite) COMPOSITE="${2:-}"; shift 2 ;;
    --edge) EDGE="${2:-}"; shift 2 ;;
    --dims) DIMS="${2:-}"; shift 2 ;;
    --tags) TAGS="${2:-}"; shift 2 ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --budget) BUDGET="${2:-45}"; shift 2 ;;
    --leg-budget) LEG_BUDGET="${2:-12}"; shift 2 ;;
    --notify) NOTIFY=1; shift ;;
    --no-file) NOFILE=1; shift ;;
    --strict) STRICT=1; shift ;;
    --json) JSON=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --pending) PENDING=1; shift ;;
    --self-test) SELFTEST=1; shift ;;
    -h|--help) sed -n '/^# USAGE/,/^# END OF EVERY/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --metrics) METRICS=1; shift ;;
    --reply) REPLY=1; shift ;;
    --no-reply) REPLY=0; shift ;;
    --decide) DECIDE=1; shift ;;
    --no-decide) DECIDE=0; shift ;;
    --no-metrics) METRICS=0; shift ;;
    --*) echo "do-close: unknown flag $1" >&2; exit 2 ;;
    *) [ -z "$SLUG" ] && SLUG="$1" || { echo "do-close: unexpected arg $1" >&2; exit 2; }; shift ;;
  esac
done

# ── credentials ─────────────────────────────────────────────────────────────
# Same ladder as do-signal.sh, same rule: the VALUE is never printed, only which
# file it came from (factory-repo.sh --check-env-indirection enforces this).
_env_key() { # <KEY>
  local _f _v
  for _f in "$ONE_ENV_FILE" "$ROOT/.env" $_MONOREPO_ENV_CANDIDATES; do
    [ -f "$_f" ] || continue
    _v=$(grep -E "^$1=" "$_f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//' || true)
    [ -n "$_v" ] && { printf '%s' "$_v"; return 0; }
  done
  printf ''
}

# ── the base URL, decided in <=1.5s and never guessed ───────────────────────
# Three doors disagreed on this for months: close.md said localhost:4321,
# do-signal.sh defaults to https://one.ie, do-promise-settle.sh to localhost.
# The ladder is now explicit and it is BOUNDED: an unset ONE_API_URL probes the
# local dev server for 1.5s and falls to prod. A dead local server costs 1.5s of
# a 45s budget, not a hang.
_resolve_base() {
  if [ -n "${ONE_API_URL:-}" ]; then printf '%s' "$ONE_API_URL"; return; fi
  if curl -s -o /dev/null --max-time 1.5 --connect-timeout 1 \
       "http://localhost:4321/api/health" 2>/dev/null; then
    printf 'http://localhost:4321'
  else
    printf 'https://one.ie'
  fi
}

# ── bounded POST ────────────────────────────────────────────────────────────
# EVERY curl here carries --max-time AND --connect-timeout. do-signal.sh's
# _post_ask carries neither (do-signal.sh:89) — that is the hang this script
# exists to not inherit. Prints the body; exit 0 only on a 2xx that does not
# carry an `"error"`, because this estate answers HTTP 200 {error:...} when
# TypeDB is down and a closer must not read that as closed.
#
# THE THREE DOORS TAKE THREE DIFFERENT CREDENTIALS, and nothing said so until a
# close measured it (2026-09-09, all three on localhost:4321):
#   /api/mark-dims      Bearer GATEWAY_API_KEY   — isVerifiedServiceCaller
#   /api/ask/<receiver> Bearer GATEWAY_API_KEY   — do-signal.sh's door
#   /api/signal/<recv>  Bearer SERVER_SECRET     — signal-dispatch.ts:78-85
# Sending GATEWAY_API_KEY at the signal door returns `{"error":"unauthorized"}`
# with HTTP 401 — which is why /close's feedback pheromone, the step every
# future agent's routing reads, had never landed from this script's ancestor.
# The credential is chosen from the PATH, so a new door cannot inherit the wrong
# one by being added to the wrong helper.
_post() { # <url> <json> [max-time]
  local _url="$1" _body="$2" _mt="${3:-$LEG_BUDGET}" _key _cfg _resp _code
  case "$_url" in
    */api/signal/*) _key="$(_env_key SERVER_SECRET)" ;;
    *)              _key="$(_env_key GATEWAY_API_KEY)" ;;
  esac
  _cfg="$(mktemp)"; chmod 600 "$_cfg"
  [ -n "$_key" ] && printf 'header = "Authorization: Bearer %s"\n' "$_key" > "$_cfg"
  _resp=$(curl -s -w '\n%{http_code}' --max-time "$_mt" --connect-timeout 2 \
            -X POST "$_url" -H 'Content-Type: application/json' \
            --config "$_cfg" -d "$_body" 2>/dev/null)
  rm -f "$_cfg"
  _code="${_resp##*$'\n'}"; _resp="${_resp%$'\n'*}"
  printf '%s' "$_resp"
  case "$_code" in
    2*) case "$_resp" in *'"error"'*) return 1 ;; *) return 0 ;; esac ;;
    # A TIMEOUT PRINTS "000", NOT "". curl still writes the -w format string when
    # it gives up, so `%{http_code}` is the literal 000 and this branch — the one
    # that means "nobody answered" — was unreachable for the commonest way nobody
    # answers. Every timeout fell through to the catch-all below and was reported
    # as `fail: <door> refused:` with an EMPTY reason, because there was no body
    # to quote. Measured 2026-09-22: the dims leg timed out at its 12s budget and
    # the close printed a refusal the door never made. In a script whose whole
    # contract is that an unrun leg is not a failed one, this door misclassified
    # its own silence.
    ""|000) return 7 ;;   # no answer at all — timed out or never connected
    *)  return 1 ;;
  esac
}

# Escapes for a JSON string body. Newlines become a literal \n, not a space:
# `notes=` is multi-line on purpose (the detail, then the FIX command on its own
# line), and flattening it is what turns a paste-able command into prose.
_jsonesc() {
  printf '%s' "${1:-}" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
    | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}'
}

# ── bounded subprocesses ────────────────────────────────────────────────────
# Every network leg is bounded by curl's own --max-time. Two legs are not: they
# shell out to scripts this one does not control, and do-promise-settle.sh runs
# an arbitrary `proof:` command that can be anything at all. Those go through
# govern.sh's run_bounded — the repo's timeout(1) replacement, which kills the
# whole PROCESS GROUP (a plain `kill` reparents the children to launchd, which is
# how this repo leaked orphaned verify trees).
#
# THE TIMEOUT IS 143, NOT 124 — measured 2026-09-09:
#     ( . lib/govern.sh; run_bounded 1 bash -c 'sleep 5' ); echo $?   ->  143
# because run_bounded SIGTERMs the process group and bash reports 128+15. The
# first draft of this file branched on 124 (the GNU timeout(1) convention it
# assumed run_bounded kept) and those branches were dead: a `proof:` that ran out
# of clock fell through to the catch-all and was recorded **BROKEN** — a promise
# marked broken because the box was slow, which is the exact class the exit-3
# handling one branch over exists to prevent.
#
# 143 alone is not safe to key on either: a child can legitimately exit 143. So
# the timeout is read from run_bounded's OWN announcement on stderr, and only
# then normalised to 124 for the callers. A leg reads 124 as `unrun`, never as a
# verdict — a check that ran out of clock has told us nothing.
_bounded() { # <secs> <cmd...> — echoes stdout, returns the exit code (124 = timed out)
  local _err _rc=0
  _err="$(mktemp)"
  if [ -r "$ROOT/.claude/scripts/lib/govern.sh" ] \
     && ( . "$ROOT/.claude/scripts/lib/govern.sh" >/dev/null 2>&1; command -v run_bounded >/dev/null 2>&1 ); then
    # shellcheck disable=SC1090
    ( . "$ROOT/.claude/scripts/lib/govern.sh" >/dev/null 2>&1
      run_bounded "$@" ) 2>"$_err" || _rc=$?
    if grep -q '\[govern\] TIMEOUT' "$_err" 2>/dev/null; then _rc=124; fi
    cat "$_err" >&2
  else
    shift
    "$@" 2>"$_err" || _rc=$?
    cat "$_err" >&2
  fi
  rm -f "$_err"
  return "$_rc"
}

# ── the leg table ───────────────────────────────────────────────────────────
LEGS_ALL="gate derives task dims feedback promise"
_wanted() { # <leg> — honours --only
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

RUNDIR="$(mktemp -d)"; trap 'rm -rf "$RUNDIR"' EXIT
_emit() { printf '%s\t%s\t%s\n' "$2" "$3" "${4:-}" > "$RUNDIR/$1"; }   # <leg> <leg> <status> <detail>
_status_of() { cut -f2 "$RUNDIR/$1" 2>/dev/null; }
_detail_of() { cut -f3 "$RUNDIR/$1" 2>/dev/null; }

# The remediation table. `notes=` on a filed task is a PASTE-ABLE COMMAND, never
# prose — that is the whole difference between a task and a nag.
_fix_for() { # <leg>
  local s="${SLUG:-<slug>}"
  case "$1" in
    gate)     printf 'cd %s/one.ie/web && FULL_VERIFY=1 bun run verify   # then: bash .claude/scripts/do-close.sh %s --only gate,task' "$ROOT" "$s" ;;
    # gate,task — never `--only task` alone: the task leg needs the gate's verdict,
    # and a fix command that skips the gate it is blocked on is not a fix.
    task)     printf 'bash .claude/scripts/do-close.sh %s --only gate,task%s' "$s" "${TID:+ --tid $TID}" ;;
    dims)     printf 'bash .claude/scripts/do-close.sh %s --only dims%s' "$s" "${DIMS:+ --dims $DIMS}" ;;
    feedback) printf 'bash .claude/scripts/do-close.sh %s --only feedback' "$s" ;;
    derives)  printf 'bash .claude/scripts/do-derives-check.sh %s   # write the artifact it names, then: bash .claude/scripts/do-close.sh %s --only derives,promise' "$s" "$s" ;;
    promise)  printf 'bash .claude/scripts/do-promise-settle.sh %s%s   # then: bash .claude/scripts/do-close.sh %s --only promise' "$s" "${COMPOSITE:+ --composite $COMPOSITE}" "$s" ;;
    *)        printf 'bash .claude/scripts/do-close.sh %s --only %s' "$s" "$1" ;;
  esac
}

# ═══ LEGS ═══════════════════════════════════════════════════════════════════

# gate — is there a FULL-suite receipt for this exact tree? Never runs a suite.
#
# test-full.sh is THE one definition of the full suite and /close is named in its
# header as one of its two callers — so the key this reads is byte-identical to
# the one deploy.sh mints, by construction. TEST_CACHE_KEY_ONLY=1 makes every
# test-cached.sh in its fan-out print its key and exit 0 without starting vitest:
# ~1s, and it CANNOT accidentally launch a suite. Reading the stamp back is
# release.sh's `_stamp_for`, same match-on-the-key rule (test-cached mangles the
# whole path into the filename, so matching the sha256 is the stable form).
leg_gate() {
  if [ "$STATUS" != "done" ]; then _emit gate gate n/a "status=$STATUS — a non-done close asserts no green"; return; fi
  if [ ! -f "$ROOT/.claude/scripts/test-full.sh" ]; then _emit gate gate n/a "no test-full.sh in this tree"; return; fi
  local keys k n=0 hit=0 stamp="" rc=0
  keys=$(cd "$ROOT" && TEST_CACHE_KEY_ONLY=1 _bounded "$LEG_BUDGET" bash .claude/scripts/test-full.sh 2>/dev/null | grep -Eo '^[0-9a-f]{64}$') || rc=$?
  if [ -z "$keys" ]; then _emit gate gate unrun "test-full.sh printed no receipt key (rc=$rc)"; return; fi
  for k in $keys; do
    n=$((n+1))
    for f in "$CACHE_DIR"/*"$k".pass; do
      [ -f "$f" ] && { hit=$((hit+1)); [ -z "$stamp" ] && stamp="$(cat "$f" 2>/dev/null)"; break; }
    done
  done
  if [ "$hit" -eq "$n" ]; then
    _emit gate gate pass "full-suite receipt on this exact tree — $hit/$n lane(s), minted $stamp"
  else
    # NOT a fast pass wearing a full badge. The close does not mint a receipt and
    # does not pretend one exists; it names the command that mints one.
    _emit gate gate unrun "no full-suite receipt — $hit/$n lane(s) stamped for this tree; the close does not mint one"
  fi
}

# derives — every `derives: <key>: true` file-shaped artifact present on disk.
leg_derives() {
  if [ -z "$SLUG" ] || [ ! -f "$ROOT/text/$SLUG.md" ]; then _emit derives derives n/a "no text/$SLUG.md promise"; return; fi
  local out rc=0
  out=$(cd "$ROOT" && _bounded "$LEG_BUDGET" bash .claude/scripts/do-derives-check.sh "$SLUG" 2>&1) || rc=$?
  case "$rc" in
    0)   _emit derives derives pass "all declared artifacts on disk" ;;
    124) _emit derives derives unrun "do-derives-check.sh exceeded ${LEG_BUDGET}s" ;;
    *)   _emit derives derives fail "exit=$rc $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
}

# task — the board write. GATED on `gate` for status=done (see the header).
leg_task() {
  if [ -z "$TID" ] && [ -z "$SLUG" ]; then _emit task task n/a "no --tid and no slug — nothing addressable"; return; fi
  if [ "$STATUS" = "timeout" ]; then _emit task task n/a "timeout leaves the lease held — status untouched, by rule"; return; fi
  # ONLY pass (a receipt exists) or n/a (no receipt is claimed — a non-done close,
  # or a tree with no suite) may license the board write. `skipped` may not: an
  # operator narrowing --only is not evidence about the tree.
  local g; g="$(_status_of gate)"
  if [ "$STATUS" = "done" ] && [ "$g" != "pass" ] && [ "$g" != "n/a" ]; then
    _emit task task unrun "gate=$g — refusing to write done over an unproven tree"
    return
  fi
  if [ -z "$TID" ]; then
    # The slug door: resolves by the `slug:` tag and stamps provenance as it closes.
    local out rc=0
    out=$(cd "$ROOT" && bash .claude/scripts/do-signal.sh --task-link "$SLUG" "docs=$SLUG" 2>&1) || rc=$?
    if [ "$rc" -eq 0 ]; then _emit task task pass "closed via slug door ($SLUG)"
    else _emit task task unrun "slug door exit=$rc $(printf '%s' "$out" | tail -1)"; fi
    return
  fi
  local body resp rc=0
  body="{\"data\":{\"tid\":\"$(_jsonesc "$TID")\",\"status\":\"$STATUS\",\"workspace\":\"$(_jsonesc "$WORKSPACE")\"}}"
  resp=$(_post "$BASE/api/ask/tasks:status" "$body") || rc=$?
  case "$rc" in
    0) _emit task task pass "tid=$TID status=$STATUS" ;;
    7) _emit task task unrun "tasks:status door did not answer inside ${LEG_BUDGET}s" ;;
    *) _emit task task fail "tasks:status refused: $(printf '%s' "$resp" | head -c 160)" ;;
  esac
}

# dims — the five rubric axes onto the path. Bare {edge,dims}: mark-dims.ts:11
# Zod-parses exactly that; a `{data:{...}}` wrapper is a 400.
leg_dims() {
  if [ -z "$DIMS" ]; then _emit dims dims "n/a" "no --dims supplied"; return; fi
  if [ "$STATUS" = "timeout" ]; then _emit dims dims n/a "timeout is neutral — no mark, no warn"; return; fi
  local d body resp rc=0
  d=$(printf '%s' "$DIMS" | awk -F',' '{for(i=1;i<=NF;i++){split($i,a,"=");printf "%s\"%s\":%s",(i>1?",":""),a[1],a[2]}}')
  body="{\"edge\":\"$(_jsonesc "$CLOSE_EDGE")\",\"dims\":{$d}}"
  resp=$(_post "$BASE/api/mark-dims" "$body") || rc=$?
  case "$rc" in
    0) _emit dims dims pass "edge=$CLOSE_EDGE dims=$DIMS" ;;
    7) _emit dims dims unrun "mark-dims door did not answer inside ${LEG_BUDGET}s" ;;
    *) _emit dims dims fail "mark-dims refused: $(printf '%s' "$resp" | head -c 160)" ;;
  esac
}

# feedback — the return-path pheromone. The receiver is a PATH SEGMENT, never a
# body field: /api/signal with no segment is 400 `receiver required`.
leg_feedback() {
  local tags outcome body resp rc=0
  case "$STATUS" in
    done) outcome=result ;; failed) outcome=failure ;;
    dissolved) outcome=dissolved ;; timeout) outcome=timeout ;;
    *) outcome="$STATUS" ;;
  esac
  # THE TAGS ARE DERIVED, NOT DECLARED — see § the tags this close earned. They
  # are what the world routes on, so a close that measured `degraded` and `slow`
  # reaches whoever staked on those words, not just whoever watches `close`.
  tags=$(printf '%s' "${CLOSE_TAGS:-close ${SLUG:-session}}" | awk '{for(i=1;i<=NF;i++){printf "%s\"%s\"",(i>1?",":""),$i}}')
  # AS MUCH DATA AS THE CLOSE HAS. The return path is the one channel the next
  # agent's routing actually reads; it used to carry four fields and so said only
  # that a close happened. It now carries every leg's state AND its seconds, the
  # decisions taken and recommended with their confidence, the verdict, the wall
  # clock, and the whole measured block — one instant, measured once, above.
  local metrics='null'
  [ -f "$METRICS_JSON" ] && [ -s "$METRICS_JSON" ] && metrics="$(cat "$METRICS_JSON")"
  body="{\"data\":{\"tags\":[$tags],\"strength\":\"${COMPOSITE:-0}\",\"content\":{\"slug\":\"$(_jsonesc "${SLUG:-}")\",\"task_id\":\"$(_jsonesc "$TID")\",\"composite\":${COMPOSITE:-0},\"outcome\":\"$outcome\",\"closed\":${CLOSED:-false},\"pass\":${PASS:-0},\"fail\":${FAIL:-0},\"unrun\":${UNRUN:-0},\"na\":${NA:-0},\"elapsed_s\":$(( $(date +%s) - T0 )),\"door\":\"$BASE\",\"branch\":\"$(git -C "$ROOT" branch --show-current 2>/dev/null || echo '')\",\"legs\":[${CLOSE_LEGS_JSON:-}],\"decisions\":[${CLOSE_DECIDE_JSON:-}],\"metrics\":$metrics,\"hop\":${ACCRETE_HOP:-1},\"accretion\":{\"budget_bytes\":${ACCRETE_BUDGET:-4096},\"rule\":\"base<<hop, capped ${ACCRETE_MAX:-262144}; bulk by reference\"},\"artifacts\":[${ARTIFACTS:-}],\"diffstat\":\"$(_jsonesc "${DIFFSTAT:-}")\",\"origin\":\"$(_jsonesc "$ACCRETE_ORIGIN")\",\"sender\":\"$(_jsonesc "$ACCRETE_SENDER")\",\"reply_to\":\"$(_jsonesc "$ACCRETE_REPLY")\",\"trail\":[${TRAIL:-}]}}}"
  FEEDBACK_BODY="$body"   # kept for the return leg below — the same envelope, verbatim
  resp=$(_post "$BASE/api/signal/loop:feedback" "$body") || rc=$?
  case "$rc" in
    0) _emit feedback feedback pass "outcome=$outcome tags=$CLOSE_TAGS hop=$ACCRETE_HOP" ;;
    7) _emit feedback feedback unrun "signal door did not answer inside ${LEG_BUDGET}s" ;;
    *) _emit feedback feedback fail "signal refused: $(printf '%s' "$resp" | head -c 160)" ;;
  esac
}

# promise — settle off-chain. EXIT 3 IS NOT A CLOSE. A `proof:` is an &&-join, so
# a leg that cannot reach its substrate returns 3 = UNVERIFIABLE. Folding that
# into `warn` deposits resistance on a proven path for a cluster blip — a promise
# recorded BROKEN for a reason its maker cannot fix (text/factory.md § "red" vs
# "cannot run"). Here it is `unrun`: the promise stays open and gets a row.
leg_promise() {
  # A halt is not a settlement. --status timeout means the work is UNFINISHED and
  # the lease is still held; running the proof there records BROKEN on a promise
  # nobody has finished making. Same rule as task and dims: timeout writes nothing.
  if [ "$STATUS" = "timeout" ]; then _emit promise promise n/a "timeout — the work is unfinished; a proof run now measures nothing"; return; fi
  if [ -z "$SLUG" ] || [ ! -f "$ROOT/text/$SLUG.md" ]; then _emit promise promise n/a "no text/$SLUG.md"; return; fi
  if ! grep -qE '^\s*proof:' "$ROOT/text/$SLUG.md" 2>/dev/null; then
    _emit promise promise n/a "promise carries no proof: — nothing observable to settle"; return; fi
  local dv; dv="$(_status_of derives)"
  if [ "$dv" = "fail" ]; then _emit promise promise unrun "derives=fail — a missing artifact forces BROKEN; fix the artifact first"; return; fi
  local out rc=0
  out=$(cd "$ROOT" && _bounded "$LEG_BUDGET" bash .claude/scripts/do-promise-settle.sh "$SLUG" ${COMPOSITE:+--composite "$COMPOSITE"} 2>&1) || rc=$?
  case "$rc" in
    0)   _emit promise promise pass "KEPT — mark on promise:${SLUG}→proof" ;;
    3)   _emit promise promise unrun "UNVERIFIABLE (exit 3) — proof could not reach its substrate; neither verb written, promise stays open" ;;
    124) _emit promise promise unrun "proof exceeded ${LEG_BUDGET}s — a proof out of clock is not a broken promise" ;;
    *)   _emit promise promise fail "BROKEN (exit $rc) — warn on promise:${SLUG}→proof" ;;
  esac
}

# ═══ escalation ═════════════════════════════════════════════════════════════
# Every non-pass leg lands in the LOCAL ledger first — that write cannot fail and
# it is what `--pending` reads back. Then, best-effort and bounded, a board task
# whose notes are the fix command. Only when the board write ALSO fails does a
# human get pinged: a ledger nothing reads and a board nobody reached means the
# only remaining channel is the person.
_ledger_row() { # <leg> <status> <detail> <filed> [decide]
  local k row
  k="${SLUG:-session}:$1"
  row=$(printf '{"k":"%s","at":"%s","slug":"%s","leg":"%s","status":"%s","detail":"%s","fix":"%s","tid":"%s","workspace":"%s","filed":"%s","decide":"%s"}' \
    "$(_jsonesc "$k")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_jsonesc "${SLUG:-}")" "$1" "$2" \
    "$(_jsonesc "$3")" "$(_jsonesc "$(_fix_for "$1")")" "$(_jsonesc "$TID")" "$(_jsonesc "$WORKSPACE")" "$4" "${5:-}")
  mkdir -p "$(dirname "$LEDGER")" 2>/dev/null
  # Keyed union: a re-run REPLACES its own row rather than stacking duplicates,
  # so the ledger measures open work, not close attempts (deploy-record.sh's
  # _union, one file shape simpler).
  if [ -f "$LEDGER" ]; then
    grep -v "\"k\":\"$(_jsonesc "$k")\"" "$LEDGER" 2>/dev/null > "$LEDGER.tmp" || true
    mv "$LEDGER.tmp" "$LEDGER"
  fi
  printf '%s\n' "$row" >> "$LEDGER"
}
_ledger_clear() { # <leg> — a leg that passed owes nothing
  local k="${SLUG:-session}:$1"
  [ -f "$LEDGER" ] || return 0
  grep -v "\"k\":\"$(_jsonesc "$k")\"" "$LEDGER" 2>/dev/null > "$LEDGER.tmp" || true
  mv "$LEDGER.tmp" "$LEDGER"
}

_file_task() { # <leg> <status> <detail> → 0 filed, 1 not
  [ "$NOFILE" -eq 1 ] && return 1
  local title fix out rc=0
  title="close ${SLUG:-session}: $1 is $2"
  fix="$(_fix_for "$1")"
  out=$(cd "$ROOT" && bash .claude/scripts/do-signal.sh --task-create \
        "close-${SLUG:-session}-$1" "$title" \
        "tags=close,unclosed,leg:$1" \
        "notes=$3

FIX (paste this):
  $fix" 2>&1) || rc=$?
  [ "$rc" -eq 0 ]
}

_notify_human() { # <summary>
  [ -x "$ROOT/.claude/scripts/notify.sh" ] || return 1
  bash "$ROOT/.claude/scripts/notify.sh" "$1" >/dev/null 2>&1
}

# ═══ --pending ══════════════════════════════════════════════════════════════
# Two states, and it says WHICH — printing the wrong instruction on every run is
# how a nudge stops being read. Silent and 0 when clean.
if [ "$PENDING" -eq 1 ]; then
  [ -f "$LEDGER" ] || exit 0
  n=$(grep -c . "$LEDGER" 2>/dev/null || echo 0)
  [ "$n" -eq 0 ] && exit 0
  echo "do-close: $n leg(s) never closed —"
  if command -v jq >/dev/null 2>&1; then
    jq -r '"  \(.k)\n      \(.status)  \(.detail)\n      fix: \(.fix)"' < "$LEDGER"
  else
    # sed on a JSON string truncates at the first escaped quote — a detail like
    # {\"error\":\"unauthorized\"} printed as `{\`. Without jq, print the raw row
    # rather than a mangled one: a half-shown fix command is worse than none.
    cat "$LEDGER"
  fi
  exit 6
fi

# ═══ --self-test ════════════════════════════════════════════════════════════
if [ "$SELFTEST" -eq 1 ]; then
  fails=0
  echo "── do-close.sh --self-test ──"
  # Every sub-run gets a SANDBOX ledger and a SANDBOX receipt cache. A self-test
  # that files rows into the operator's real close ledger is a self-test that
  # makes `--pending` lie on the next real run.
  _sbl="$(mktemp -d)/ledger.jsonl"
  export CLOSE_LEDGER="$_sbl"

  # 1. GREEN: a dry run reports every leg and never touches a door.
  out=$(bash "$0" __probe__ --dry-run 2>&1)
  if printf '%s' "$out" | grep -q 'DRY-RUN'; then echo "ok: --dry-run plans without POSTing"
  else echo "FAIL: --dry-run did not announce itself"; fails=$((fails+1)); fi

  # 2. RED PROOF — an unrun leg must never read as closed. Force the gate unrun
  #    by pointing the receipt cache at an empty dir, and assert closed=false.
  out=$(TEST_CACHE_DIR="$(mktemp -d)" CLOSE_NO_ESCALATE=1 bash "$0" __probe__ --only gate --no-file 2>&1)
  if printf '%s' "$out" | grep -q 'gate .*unrun'; then
    if printf '%s' "$out" | grep -q 'closed=false'; then
      echo "ok: RED PROOF — a missing full-suite receipt is unrun and the close is NOT closed"
    else echo "FAIL: RED PROOF — unrun gate still reported closed=true"; fails=$((fails+1)); fi
  else echo "FAIL: RED PROOF — an empty receipt cache did not surface as an unrun gate"; fails=$((fails+1)); fi

  # 3. RED PROOF — the dependency edge. An unrun gate must BLOCK the done write.
  out=$(TEST_CACHE_DIR="$(mktemp -d)" CLOSE_NO_ESCALATE=1 bash "$0" __probe__ --tid t_probe --only gate,task --no-file 2>&1)
  if printf '%s' "$out" | grep -q 'task .*unrun.*refusing to write done'; then
    echo "ok: RED PROOF — no receipt ⇒ the board is NOT told done"
  else echo "FAIL: RED PROOF — the task leg wrote done over an unproven tree"; fails=$((fails+1)); fi

  # 4. GREEN PROOF — the edge is not stuck red: a gate that is n/a lets task run.
  out=$(CLOSE_NO_ESCALATE=1 bash "$0" __probe__ --tid t_probe --status failed --only gate,task --no-file --dry-run 2>&1)
  if printf '%s' "$out" | grep -q 'gate .*n/a'; then
    echo "ok: GREEN PROOF — a non-done close does not demand a green receipt"
  else echo "FAIL: GREEN PROOF — status=failed still demanded a receipt"; fails=$((fails+1)); fi

  # 5. The ledger round-trips: a filed leg comes back out of --pending with its fix.
  tmpl="$(mktemp)"; rm -f "$tmpl"
  out=$(LEDGER_OVERRIDE=1 CLOSE_LEDGER="$tmpl" TEST_CACHE_DIR="$(mktemp -d)" CLOSE_NO_ESCALATE=1 \
        bash "$0" __probe__ --only gate --no-file 2>&1)
  out2=$(CLOSE_LEDGER="$tmpl" bash "$0" --pending 2>&1); rc=$?
  if [ "$rc" -eq 6 ] && printf '%s' "$out2" | grep -q 'fix: '; then
    echo "ok: an unclosed leg round-trips through --pending WITH its fix command (exit 6)"
  else echo "FAIL: --pending did not return the unclosed leg (rc=$rc)"; fails=$((fails+1)); fi

  # 6. RED PROOF for the ledger itself — gut the writer and assert check 5 breaks.
  gut="$(mktemp)"; awk '/^_ledger_row\(\) \{/{print "_ledger_row() { :; }"; sk=1; next} sk&&/^\}$/{sk=0;next} !sk' "$0" > "$gut"
  tmpl2="$(mktemp)"; rm -f "$tmpl2"
  CLOSE_LEDGER="$tmpl2" TEST_CACHE_DIR="$(mktemp -d)" CLOSE_NO_ESCALATE=1 bash "$gut" __probe__ --only gate --no-file >/dev/null 2>&1
  CLOSE_LEDGER="$tmpl2" bash "$0" --pending >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ]; then echo "ok: RED PROOF — a gutted ledger writer makes --pending go blind (check 5 measures something)"
  else echo "FAIL: RED PROOF — --pending still found a row after the writer was gutted"; fails=$((fails+1)); fi
  rm -f "$gut" "$tmpl" "$tmpl2"

  # 7. RED PROOF — `--only task` must NOT become a door around the receipt gate.
  #    This is the defect the first draft shipped: a skipped gate reported n/a,
  #    leg_task read n/a as licence, and the fix string it advertised for
  #    "refusing to write done over an unproven tree" was `--only task` — the
  #    command that wrote done over an unproven tree.
  out=$(TEST_CACHE_DIR="$(mktemp -d)" CLOSE_NO_ESCALATE=1 bash "$0" __probe__ --tid t_probe --only task --no-file 2>&1)
  if printf '%s' "$out" | grep -q 'task .*unrun'; then
    echo "ok: RED PROOF — --only task cannot bypass the receipt gate"
  else echo "FAIL: RED PROOF — --only task wrote the board with no gate verdict"; fails=$((fails+1)); fi

  # 8. And the fix it advertises must be the one that works: gate,task.
  tf=$(bash -c "ROOT='$ROOT'; SLUG=x; TID=''; DIMS=''; COMPOSITE=''; $(declare -f _fix_for); _fix_for task" 2>/dev/null)
  case "$tf" in
    *"--only gate,task"*) echo "ok: the task leg's fix command runs the gate it is blocked on" ;;
    *) echo "FAIL: the task fix skips its own gate: $tf"; fails=$((fails+1)) ;;
  esac

  # 9. RED PROOF — the bound reports a TIMEOUT as unrun, never as a verdict.
  #    run_bounded exits 143 (SIGTERM), not 124; branching on 124 alone made
  #    every timed-out proof record BROKEN.
  tb=$(bash -c "ROOT='$ROOT'; $(declare -f _bounded); _bounded 1 bash -c 'sleep 4'; echo rc=\$?" 2>/dev/null | tail -1)
  if [ "$tb" = "rc=124" ]; then echo "ok: RED PROOF — a bounded call that times out returns 124, so a slow proof is unrun, not BROKEN"
  else echo "FAIL: a timed-out bounded call returned '$tb', not rc=124 — a slow proof would record BROKEN"; fails=$((fails+1)); fi

  # 10. Every leg's remediation command NAMES that leg (a fix that merely
  #     contains the word do-close.sh is a tautology, not a check).
  miss=0
  for l in $LEGS_ALL; do
    f=$(bash -c "ROOT='$ROOT'; SLUG=x; TID=''; DIMS=''; COMPOSITE=''; $(declare -f _fix_for); _fix_for $l" 2>/dev/null)
    case "$f" in *"$l"*) ;; *) echo "FAIL: leg $l fix does not name the leg: $f"; miss=1 ;; esac
  done
  [ "$miss" -eq 0 ] && echo "ok: every leg carries a paste-able fix command that names it"

  # 11. The decide wiring: a `highway` verdict is TAKEN, reported with its undo,
  #     and leaves a `taken:` ledger row so the NEXT close can settle it. Driven
  #     through a gutted copy of the real do-decide.sh, never through seeded
  #     evidence — five fake marks would make the test its own oracle.
  _dg="$(mktemp)"
  awk '/^_verdict\(\) \{/{print; print "  printf \"highway mint\"; return 0;"; next} {print}' \
    "$ROOT/.claude/scripts/do-decide.sh" > "$_dg"; chmod +x "$_dg"
  tmpd="$(mktemp)"
  out=$(CLOSE_LEDGER="$tmpd" TEST_CACHE_DIR="$(mktemp -d)" DECIDE_BIN="$_dg" DECIDE_DRYCMD=1 \
        CLOSE_NO_ESCALATE=1 bash "$0" __probe__ --only gate --no-file --no-metrics 2>&1)
  if printf '%s' "$out" | grep -q 'TAKEN mint' && printf '%s' "$out" | grep -q 'undo:' \
     && grep -q '"decide":"taken:mint"' "$tmpd" 2>/dev/null; then
    echo "ok: a highway verdict is TAKEN, carries its undo, and leaves a settle-able row"
  else echo "FAIL: the decide wiring did not take a highway verdict: $out"; fails=$((fails+1)); fi

  # 12. RED PROOF for 11 — --no-decide must leave the same fork entirely alone.
  tmpd2="$(mktemp)"
  out=$(CLOSE_LEDGER="$tmpd2" TEST_CACHE_DIR="$(mktemp -d)" DECIDE_BIN="$_dg" DECIDE_DRYCMD=1 \
        CLOSE_NO_ESCALATE=1 bash "$0" __probe__ --only gate --no-file --no-metrics --no-decide 2>&1)
  if ! printf '%s' "$out" | grep -q 'TAKEN'; then
    echo "ok: RED PROOF — --no-decide decides nothing on the same forced highway (check 11 measures something)"
  else echo "FAIL: RED PROOF — --no-decide still took a decision"; fails=$((fails+1)); fi
  rm -f "$_dg" "$tmpd" "$tmpd2"

  # 13. A tag can never carry a `/`. land.sh and deploy.sh pass a BRANCH NAME as
  #     the slug, and the mark edge is a URL path segment — `feat/x` split the
  #     route and the verb vanished with no error. Measured: 6 tags, 5 verbs.
  _tt=$( CLOSE_TAGS=""
         eval "$(sed -n '/^_tag_add() {/,/^}/p' "$0")"
         _tag_add "feat/test-branch"; _tag_add "a b"; _tag_add "ok-1"
         printf '%s' "$CLOSE_TAGS" )
  case "$_tt" in
    */*|*" a b "*) echo "FAIL: _tag_add let an unroutable tag through: $_tt"; fails=$((fails+1)) ;;
    *) echo "ok: a branch-shaped slug is sanitised to a routable tag ($_tt)" ;;
  esac
  # 14. The promise leg's TERMINAL branches must survive `set -u`.
  #
  #     Both were dead from this file's first commit (b6641e812, 2026-09-09):
  #     `"KEPT — mark on promise:$SLUG→proof"` runs the U+2192 bytes straight
  #     into the variable, bash does not end the name there, and under `set -u`
  #     the whole function aborts. 459 was the `pass` case and 462 the `fail`
  #     case, so exit 3 and 124 — the two UNRUN branches — were the only
  #     outcomes that ever reached a reader. The leg is usually unrun, and an
  #     unrun leg prints a reason and moves on, which is why four days of
  #     closes went by without anyone seeing it.
  #
  #     Checks 1-13 could not catch this: not one of them drives the promise
  #     leg to a verdict. That hole is the reason the defect existed, so this
  #     check evaluates the real emit strings from the real file rather than a
  #     copy of them — a hand-written fixture would pass while the script
  #     stayed broken.
  _pe=$(
    set -u
    SLUG="probe"; rc=7
    for _ln in 459 462; do
      _src=$(sed -n "${_ln}p" "$0" | sed 's/^ *[0-9*)]*) *_emit promise promise [a-z]* //; s/ *;;$//')
      eval "printf '%s\n' $_src" 2>&1 || printf 'DIED\n'
    done
  )
  case "$_pe" in
    *"unbound variable"*|*DIED*)
      echo "FAIL: a promise leg terminal branch dies under set -u — it can never report a verdict"; fails=$((fails+1)) ;;
    *KEPT*probe*|*BROKEN*probe*)
      echo "ok: the promise leg's pass and fail branches both survive set -u and name the slug" ;;
    *)
      echo "FAIL: could not drive the promise leg's terminal branches (got: ${_pe:-empty})"; fails=$((fails+1)) ;;
  esac

  # 14b. RED PROOF for 14 — the unbraced form must STILL die, or 14 proves nothing.
  #
  #      First attempt failed honestly and is worth recording: it passed the
  #      escape "\u2192" through eval, where bash printf leaves it literal, so
  #      the arrow bytes never sat against the variable and the form could not
  #      fail. The check correctly reported "the unbraced form no longer fails".
  #      A red proof that cannot go red is the thing this check exists to catch,
  #      and it caught itself. The character is written literally now.
  _rp=$(bash -uc 'SLUG=probe; printf "%s\n" "KEPT on promise:$SLUG→proof"' 2>&1 || printf 'DIED\n')
  case "$_rp" in
    *"unbound variable"*|*DIED*) echo "ok: RED PROOF — the unbraced form still dies, so check 14 measures something" ;;
    *) echo "FAIL: RED PROOF — the unbraced form no longer fails; check 14 proves nothing"; fails=$((fails+1)) ;;
  esac

  fails=$((fails+miss))

  echo "──"
  [ "$fails" -eq 0 ] && { echo "do-close self-test: PASS"; exit 0; }
  echo "do-close self-test: $fails FAILURE(S)"; exit 1
fi

# ═══ RUN ════════════════════════════════════════════════════════════════════
CLOSE_EDGE="${EDGE:-close:${SLUG:-session}→result}"
T0=$(date +%s)
BASE="$( [ "$DRY" -eq 1 ] && printf 'http://dry.invalid' || _resolve_base )"

_run_leg() { # <leg> — one leg, bounded, always emits
  local leg="$1"
  # `skipped`, never `n/a`. n/a means "this leg does not apply, by rule" and it is
  # what licenses the dependent legs to proceed. A leg the operator merely left
  # out of --only has proved nothing, and must license nothing.
  if ! _wanted "$leg"; then _emit "$leg" "$leg" skipped "not in --only"; return; fi
  if [ "$DRY" -eq 1 ]; then
    # A dry run still evaluates the CHEAP local preconditions, so the plan it
    # prints is the plan that would run — not a list of leg names.
    case "$leg" in
      gate|derives|promise) "leg_$leg" ;;
      *) _emit "$leg" "$leg" unrun "DRY-RUN — would POST $BASE" ;;
    esac
    return
  fi
  # THE BUDGET DOES NOT STARVE THE CLOSING SIGNAL. Every other leg is skipped
  # once the wall clock is spent — that is what bounds this script. `feedback` is
  # exempt because it is wave 3: it runs after the ~17s measured block, so on any
  # slow box the budget check would fire on the one leg that CARRIES the whole
  # close, and Rule 1 (every signal closes) would be broken by its own guard. It
  # is still bounded — by its own --leg-budget, like every curl here.
  local elapsed=$(( $(date +%s) - T0 ))
  if [ "$elapsed" -ge "$BUDGET" ] && [ "$leg" != "feedback" ]; then
    _emit "$leg" "$leg" unrun "budget ${BUDGET}s spent before this leg started"; return; fi
  # SPEED IS A MEASURED ROW, NOT A FEELING. Each leg's own wall clock is written
  # beside its verdict, because "the close was slow" and "the promise proof was
  # slow" are different facts with different fixes — and because the signal below
  # carries these numbers, so the next close can see which door is drifting.
  local _t0; _t0=$(date +%s)
  "leg_$leg"
  printf '%s' "$(( $(date +%s) - _t0 ))" > "$RUNDIR/$leg.s" 2>/dev/null
  [ -f "$RUNDIR/$leg" ] || _emit "$leg" "$leg" unrun "leg produced no verdict"
}
_secs_of() { cat "$RUNDIR/$1.s" 2>/dev/null || printf '0'; }

# Two waves, because there are exactly two dependency edges and no more:
#   task ← gate      (never write done over an unproven tree)
#   promise ← derives (a missing artifact forces BROKEN — fix it, don't record it)
# Everything else is independent and goes in parallel.
for l in gate derives dims; do _run_leg "$l" & done
wait
for l in task promise; do _run_leg "$l" & done
wait
# `feedback` is the THIRD wave and it is the only leg that runs after the
# verdict — a third dependency edge the two-wave design did not have:
#   feedback ← everything else
# It used to fire in wave 1 carrying four fields (slug, tid, composite, outcome),
# which is a pheromone that says a close happened and nothing about what it found.
# The return path is the one channel the next agent's routing actually reads, so
# it now carries the whole close: every leg's state AND its seconds, the decisions
# taken and recommended with their confidence, the derived tags, and the measured
# block. The cost of moving it is one ordering constraint; the cost of not moving
# it was a signal nobody could learn from.

# ── verdict ─────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; UNRUN=0; NA=0; OPEN_LEGS=""
# The five that have run. `feedback` is folded in below, after it fires with the
# verdict in its payload — it reports ON this verdict, so it cannot be inside it.
_fold_leg() { # <leg>
  local l="$1" s
  s="$(_status_of "$l")"; [ -n "$s" ] || s=unrun
  case "$s" in
    pass) PASS=$((PASS+1)); [ "$DRY" -eq 1 ] || _ledger_clear "$l" ;;
    fail) FAIL=$((FAIL+1)); OPEN_LEGS="$OPEN_LEGS $l" ;;
    unrun) UNRUN=$((UNRUN+1)); OPEN_LEGS="$OPEN_LEGS $l" ;;
    n/a) NA=$((NA+1)) ;;
    # skipped: the operator narrowed --only. Not a pass, not a debt — this run
    # made no claim about it, so it neither blocks `closed` nor files a row.
    skipped) ;;
  esac
}
for l in gate derives task dims promise; do _fold_leg "$l"; done
# A PROVISIONAL verdict — feedback has not fired yet, and it carries this in its
# payload. Recomputed once more below, after the fold, and THAT is the one the
# report and `--strict` read.
CLOSED=true
if [ "$FAIL" -gt 0 ] || [ "$UNRUN" -gt 0 ]; then CLOSED=false; fi

# ── settle the LAST run's decisions ─────────────────────────────────────────
# Before anything is filed. A leg this run reports `pass` vindicates whatever was
# auto-taken for it last time (mark, strength 1 — five of those make a highway);
# a leg still open refutes it (warn — one of those takes the authority straight
# back on the very next close). This is the only writer of the evidence the
# decide layer reads, and it writes from OUTCOMES, never from exit codes.
if [ "$DRY" -eq 0 ] && [ "$DECIDE" -eq 1 ] && [ -n "$PRIOR_DECIDED" ] && [ -z "${CLOSE_NO_DECIDE:-}" ]; then
  while read -r _pl _po; do
    [ -n "$_pl" ] || continue
    _ps="$(_status_of "$_pl")"
    case "$_ps" in pass) _out=pass ;; ""|skipped) continue ;; *) _out=open ;; esac
    bash "$DECIDE_BIN" --settle --leg "$_pl" --status "$_po" \
      --outcome "$_out" ${SLUG:+--slug "$SLUG"} >/dev/null 2>&1 || true
  done <<PRIOR
$PRIOR_DECIDED
PRIOR
fi

DECIDED=0; RECOMMENDED=0; DECIDE_LINES=""; DECIDE_JSON_ROWS=""; DECIDE_ROWED=""
MARKED=0; WARNED=0; CLOSE_LEGS_JSON=""; CLOSE_DECIDE_JSON=""; CLOSE_TAGS=""
METRICS_TXT=""; METRICS_JSON=""; METRICS_S=0
# ── decide what a person does not need to be asked ──────────────────────────
# Runs AFTER the verdict and it is NOT a seventh leg: it cannot change `CLOSED`,
# it cannot turn anything red, and its exit code is discarded — the same law the
# metrics block obeys, for the same reason (a closer that can fail on its extras
# is a closer callers route around). What it changes is what gets FILED: a fork
# the substrate has proven is taken and the human is TOLD; a fork it has not is
# ranked, priced and RECOMMENDED, and the human still decides.
#
# It deliberately does not retro-flip a leg to `pass` when a decision closes it.
# The verdict above was computed at a real instant and reporting it otherwise
# would be the "unrun read as a pass" failure wearing a new hat. A taken decision
# says so in its own line and the next close measures the tree again.
if [ "$DECIDE" -eq 1 ] && [ -n "$OPEN_LEGS" ] && [ -z "${CLOSE_NO_DECIDE:-}" ] \
   && [ -x "$DECIDE_BIN" ]; then
  for l in $OPEN_LEGS; do
    _wanted "$l" || continue
    _dj=$(bash "$DECIDE_BIN" --leg "$l" --status "$(_status_of "$l")" \
            --detail "$(_detail_of "$l")" ${SLUG:+--slug "$SLUG"} \
            $([ "$DRY" -eq 0 ] && echo --apply) --json 2>/dev/null) || _drc=$?
    case "${_drc:-0}" in
      5) _drc=0; continue ;;                       # no table row — file it as before
    esac
    _drc=0
    [ -n "$_dj" ] || continue
    _dres=$(printf '%s' "$_dj" | sed -n 's/.*"verdict":"\([a-z]*\)".*/\1/p')
    _dch=$(printf '%s' "$_dj"  | sed -n 's/.*"choice":"\([^"]*\)".*/\1/p')
    _dcf=$(printf '%s' "$_dj"  | sed -n 's/.*"confidence":"\([a-z]*\)".*/\1/p')
    _dun=$(printf '%s' "$_dj"  | sed -n 's/.*"undo":"\([^"]*\)".*/\1/p')
    _drn=$(printf '%s' "$_dj"  | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')
    case "$_dres" in
      taken)
        DECIDED=$((DECIDED+1))
        DECIDE_LINES="$DECIDE_LINES
    $l → TAKEN $_dch (confidence: $_dcf)   undo: $_dun"
        DECIDE_JSON_ROWS="${DECIDE_JSON_ROWS:+$DECIDE_JSON_ROWS,}{\"leg\":\"$l\",\"id\":\"$(printf '%s' "$_dj" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')\",\"result\":\"taken\",\"choice\":\"$_dch\",\"confidence\":\"$_dcf\"}"
        # The row records WHAT was taken, so the next close can settle it.
        [ "$DRY" -eq 0 ] && { _ledger_row "$l" "$(_status_of "$l")" \
          "$(_detail_of "$l") | decided: $_dch ($_dcf)" ledger "taken:$_dch"
          DECIDE_ROWED="${DECIDE_ROWED:-} $l"; } ;;
      veto)
        DECIDE_LINES="$DECIDE_LINES
    $l → HUMAN by rule: $_drn"
        DECIDE_JSON_ROWS="${DECIDE_JSON_ROWS:+$DECIDE_JSON_ROWS,}{\"leg\":\"$l\",\"result\":\"veto\",\"reason\":\"$(_jsonesc "$_drn")\"}" ;;
      *)
        RECOMMENDED=$((RECOMMENDED+1))
        DECIDE_LINES="$DECIDE_LINES
    $l → RECOMMEND $_dch (confidence: $_dcf — unproven, ${DECIDE_N:-5} good outcomes make it automatic)"
        DECIDE_JSON_ROWS="${DECIDE_JSON_ROWS:+$DECIDE_JSON_ROWS,}{\"leg\":\"$l\",\"result\":\"recommend\",\"choice\":\"$_dch\",\"confidence\":\"$_dcf\"}" ;;
    esac
  done
fi

# The human is the LAST channel, not the first. Ping when a leg reached neither
# the board nor anything anyone watches — or when --notify asks for it outright.
#
# ── measure ONCE, for both readers ──────────────────────────────────────────
# ~17s of real work (git plumbing, a cache-key hash, a governor read). It used to
# run at the very end, for the human only. Now it runs here, `--json-out` writes
# the machine copy, and stdout is held for the report — so the table a person
# reads and the numbers the signal carries are the SAME measurement of the same
# instant. On a tree seven sessions are editing, two runs are two different trees.
METRICS_TXT="$RUNDIR/metrics.txt"; METRICS_JSON="$RUNDIR/metrics.json"
if [ "$METRICS" -eq 1 ] && [ "$DRY" -eq 0 ] && [ -f "$ROOT/.claude/scripts/close-metrics.sh" ]; then
  _MT0=$(date +%s)
  _bounded 40 bash "$ROOT/.claude/scripts/close-metrics.sh" \
    ${SLUG:+--slug "$SLUG"} ${COMPOSITE:+--composite "$COMPOSITE"} ${DIMS:+--dims "$DIMS"} \
    --json-out "$METRICS_JSON" > "$METRICS_TXT" 2>/dev/null || true
  METRICS_S=$(( $(date +%s) - _MT0 ))
fi

# ── the tags this close earned ──────────────────────────────────────────────
# Tags are how the world routes (root CLAUDE.md § the universal router): a signal
# carries tags and flows down the weighted Paths from those tags to whoever
# staked on them. A close that tags itself only `close,<slug>` is a close nobody
# can route on. These are DERIVED FROM WHAT WAS MEASURED, never declared — bare
# words, because a namespaced subscribe tag matches zero subscribers
# (subscribe-tags-parity.test.ts) and `lifecycle:<x>` is a different lane.
# TAGS ARE SANITISED AT THE DOOR, and it is not cosmetic. `land.sh` and
# `deploy.sh` pass a BRANCH NAME as the slug, so `feat/test-branch` became a tag,
# and the mark edge below is a URL PATH SEGMENT: the `/` split
# `/api/mark/tag%3Aone%3Afeat/test-branch…` into a route that does not exist.
# Measured 2026-09-09: 6 tags derived, 5 verbs landed, and the sixth failed
# silently — the close reported a number that looked fine. Bare word chars only,
# which is also the subscribe-tag rule (`subscribe-tags-parity.test.ts`).
_tag_add() {
  local t; t=$(printf '%s' "$1" | tr '/' '-' | tr -cd 'a-zA-Z0-9_.:-')
  [ -n "$t" ] || return 0
  case " $CLOSE_TAGS " in *" $t "*) ;; *) CLOSE_TAGS="${CLOSE_TAGS:+$CLOSE_TAGS }$t" ;; esac
}
CLOSE_TAGS=""
for t in $(printf '%s' "${TAGS:-close,${SLUG:-session}}" | tr ',' ' '); do _tag_add "$t"; done
_tag_add close
[ "$CLOSED" = "true" ] && _tag_add closed || _tag_add unclosed
[ "$FAIL"  -gt 0 ] && _tag_add failing
[ "$UNRUN" -gt 0 ] && _tag_add unrun
[ "$DECIDED" -gt 0 ] && _tag_add decided
[ "$RECOMMENDED" -gt 0 ] && _tag_add recommended
for l in gate derives task dims promise; do
  case "$(_status_of "$l")" in fail|unrun) _tag_add "$l" ;; esac
done
# Speed is a tag too, so a drifting door is routable and not just readable.
_CLOSE_S=$(( $(date +%s) - T0 ))
# `slow` is judged on the LEGS, not on the measured block: the block is a fixed
# ~17s cost this script chose to pay, and tagging every close `slow` because of a
# constant is a tag that stops carrying information.
[ $(( _CLOSE_S - ${METRICS_S:-0} )) -gt 20 ] && _tag_add slow || _tag_add fast
[ -f "$METRICS_JSON" ] && grep -q '"state":"bad"' "$METRICS_JSON" 2>/dev/null && _tag_add degraded

# ── accretion: a signal gets RICHER at every node it crosses ────────────────
# The rule (the operator, 2026-09-09): "every time a signal hits a node we should
# add exponentially more metadata and data and images etc. to it." A signal that
# carries the same four fields at hop 5 as at hop 1 has learned nothing from the
# journey — and the journey is the only thing that knows what mattered.
#
# So the payload budget DOUBLES per hop: BASE << hop, and this close is one hop.
# `CLOSE_SIGNAL_HOP` is read from the caller (do-auto, land, deploy, the factory
# executor) and re-emitted incremented, so a signal crossing four nodes arrives
# with 16x the room it started with.
#
# TWO BOUNDS, because "exponentially more" without them is a signal nobody can
# store and every door refuses:
#   1. A HARD CEILING (ACCRETE_MAX, 256KB). The doubling is how fast the room
#      grows, not a promise it grows forever.
#   2. BULK TRAVELS BY REFERENCE. Images, JSON dumps, diffs and gate packs go as
#      {path, bytes, sha256} — verified to EXIST at emit time, never as bytes.
#      That is what makes "and images etc." affordable: a screenshot costs ~120
#      bytes of envelope, and the node that wants the pixels reads the path.
# Numbers are packed first, then details, then references — so a budget that runs
# out drops the biggest thing, never the verdict.
# THE TRAIL, AND THE WAY BACK. Accretion only pays if the enriched signal can be
# FOLDED BACK — otherwise every node is richer and the one who asked learns
# nothing. So the envelope carries three addresses and a trail:
#
#   origin   who started the work (survives every hop unchanged)
#   sender   the PREVIOUS node — one hop back
#   reply_to where a return leg goes (defaults to sender, then origin)
#   trail[]  one entry per node crossed: hop, node, what it added, its tags
#
# Outbound the signal gains data; the return leg carries the accumulated whole
# back down the same path. That is the closed loop at the level of the JOURNEY
# rather than the single call — and `loop:feedback` was always the return leg;
# it just had nothing to return. `--reply` emits it.
ACCRETE_ORIGIN="${CLOSE_SIGNAL_ORIGIN:-${SLUG:-session}}"
ACCRETE_SENDER="${CLOSE_SIGNAL_SENDER:-}"
ACCRETE_REPLY="${CLOSE_REPLY_TO:-${ACCRETE_SENDER:-$ACCRETE_ORIGIN}}"
ACCRETE_HOP=$(( ${CLOSE_SIGNAL_HOP:-0} + 1 ))
ACCRETE_BASE="${ACCRETE_BASE:-4096}"
ACCRETE_MAX="${ACCRETE_MAX:-262144}"
ACCRETE_BUDGET=$(( ACCRETE_BASE << (ACCRETE_HOP > 6 ? 6 : ACCRETE_HOP) ))
[ "$ACCRETE_BUDGET" -gt "$ACCRETE_MAX" ] && ACCRETE_BUDGET="$ACCRETE_MAX"

# Every artifact this close can point at, as a reference. `test -s` before each,
# because a reference to a file that is not there is the "file exists is theater"
# failure with an extra hop of delay on it.
_ref() { # <kind> <path>
  [ -s "$2" ] || return 0
  local sz sha
  sz=$(wc -c < "$2" 2>/dev/null | tr -d ' ')
  sha=$(shasum -a 256 "$2" 2>/dev/null | cut -c1-16)
  printf '%s{"kind":"%s","path":"%s","bytes":%s,"sha256":"%s"}' \
    "${_rc_:-}" "$1" "$(_jsonesc "${2#$ROOT/}")" "${sz:-0}" "${sha:-}"; _rc_=,
}
ARTIFACTS=$( _rc_=""
  _ref metrics      "$METRICS_JSON"
  _ref metrics_text "$METRICS_TXT"
  _ref ledger       "$LEDGER"
  _ref w4_gates     "$ROOT/.w4-gates.json"
  _ref w2_spec      "$ROOT/.w2-spec.json"
  _ref promise      "$ROOT/text/${SLUG:-__none__}.md"
  _ref todo         "$ROOT/text/${SLUG:-__none__}-todo.md"
  _ref plan         "$ROOT/text/${SLUG:-__none__}-plan.md"
  _ref deploy_runs  "$ROOT/one.ie/web/src/data/deploy-runs.json"
  # IMAGES. do-prove.sh / chrome.mjs leave screenshots behind; they are the only
  # evidence in this whole payload that a human can check at a glance.
  for _img in "$ROOT"/.claude/.artifacts/*.png "$ROOT"/.playwright-mcp/*.png "/tmp/one-prove"/*.png; do
    [ -s "$_img" ] || continue; _ref screenshot "$_img"
  done )

# The diff itself, by reference AND — if the budget stretches — by value. The
# close already knows what changed; a node downstream that must judge the change
# should not have to re-derive it from a sha.
DIFFSTAT=$(git -C "$ROOT" diff HEAD --stat 2>/dev/null | tail -40 || true)
[ "${#DIFFSTAT}" -gt "$(( ACCRETE_BUDGET / 4 ))" ] && DIFFSTAT="${DIFFSTAT:0:$(( ACCRETE_BUDGET / 4 ))}"

# This node's entry, appended to whatever the caller handed us. The inbound trail
# is passed through VERBATIM — a node that rewrites the history it was given is a
# node whose trail cannot be trusted; it may only append.
_ACC_ADDED=$(( ${#ARTIFACTS} + ${#DIFFSTAT} + ${#CLOSE_LEGS_JSON} ))
TRAIL_ENTRY=$(printf '{"hop":%d,"node":"close:%s","at":"%s","added_bytes":%d,"artifacts":%d,"tags":"%s","verdict":"%s"}' \
  "$ACCRETE_HOP" "${SLUG:-session}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_ACC_ADDED" \
  "$(printf '%s' "$ARTIFACTS" | grep -o '"kind"' | grep -c . || echo 0)" \
  "$(_jsonesc "$CLOSE_TAGS")" "$CLOSED")
TRAIL="${CLOSE_SIGNAL_TRAIL:+${CLOSE_SIGNAL_TRAIL},}$TRAIL_ENTRY"

# ── wave 3: the return path, carrying the whole close ───────────────────────
CLOSE_LEGS_JSON=$(for l in $LEGS_ALL; do
    printf '%s{"leg":"%s","status":"%s","secs":%s,"detail":"%s"}' \
      "${_c:-}" "$l" "$(_status_of "$l")" "$(_secs_of "$l")" "$(_jsonesc "$(_detail_of "$l")")"; _c=,
  done)
CLOSE_DECIDE_JSON=$(printf '%s' "${DECIDE_JSON_ROWS:-}")
_run_leg feedback
_fold_leg feedback

# ── the verdict, final ──────────────────────────────────────────────────────
# `closed` is true only with ZERO fails and ZERO unruns — do-w4-gates.sh's
# deterministic_pass, same law: an unrun leg is not a closed leg.
CLOSED=true
if [ "$FAIL" -gt 0 ] || [ "$UNRUN" -gt 0 ]; then CLOSED=false; fi

# ── escalate what did not close ─────────────────────────────────────────────
FILED=0; UNFILED=0; LEDGERED=0
if [ "$DRY" -eq 0 ] && [ -z "${CLOSE_NO_ESCALATE:-}" ]; then
  for l in $OPEN_LEGS; do
    # An --only run must not file rows for legs it deliberately did not run.
    _wanted "$l" || continue
    # A leg the decide layer already rowed carries its `taken:<option>`, and that
    # field is what the NEXT close settles against. A plain escalation row here
    # would silently erase it (the ledger is a keyed union — last writer wins),
    # and the decision would never be marked or warned. The board task still
    # gets filed below for those legs; only the ledger write is skipped.
    case " ${DECIDE_ROWED:-} " in *" $l "*) _file_task "$l" "$(_status_of "$l")" "$(_detail_of "$l")" && FILED=$((FILED+1)); continue ;; esac
    if _file_task "$l" "$(_status_of "$l")" "$(_detail_of "$l")"; then
      _ledger_row "$l" "$(_status_of "$l")" "$(_detail_of "$l")" task; FILED=$((FILED+1))
    else
      _ledger_row "$l" "$(_status_of "$l")" "$(_detail_of "$l")" ledger
      LEDGERED=$((LEDGERED+1))
      # --no-file is the operator choosing ledger-only. That is not an unreached
      # board, so it must not page anyone: a notifier that fires when it was told
      # not to file is a notifier the human mutes. UNFILED counts only the rows
      # that reached NOTHING — it is the trigger for the human, and conflating it
      # with "written to the ledger" reported `ledger=0` on a run that had just
      # written two rows.
      [ "$NOFILE" -eq 1 ] || UNFILED=$((UNFILED+1))
    fi
  done
elif [ "$DRY" -eq 0 ]; then
  # Same rule as the branch above: never overwrite a row the decide layer wrote,
  # or its `taken:<option>` is lost and the decision is never settled.
  for l in $OPEN_LEGS; do
    _wanted "$l" || continue
    case " ${DECIDE_ROWED:-} " in *" $l "*) continue ;; esac
    _ledger_row "$l" "$(_status_of "$l")" "$(_detail_of "$l")" ledger; LEDGERED=$((LEDGERED+1))
  done
fi

# ── the return leg: fold the enriched signal back to who asked ──────────────
# Accretion without a fold is a signal that gets richer while the one who asked
# learns nothing. `--reply` sends the SAME envelope back one hop — to `sender`,
# or to `origin` when this is hop 1 — tagged `reply` and `for:<node>` so the
# router delivers it to whoever staked on that node rather than broadcasting.
#
# It is the outbound payload verbatim, not a summary: the sender asked for work,
# and what comes back is everything the journey learned, including the artifact
# references it can now read for itself. A summary here would be this node
# deciding what the previous node is allowed to know.
#
# Bounded and fire-and-forget, like every write in this file — a return leg that
# can fail the close is a return leg callers switch off.
REPLIED=none
if [ "$DRY" -eq 0 ] && [ "$REPLY" -eq 1 ] && [ -n "$ACCRETE_REPLY" ] && [ -n "${FEEDBACK_BODY:-}" ]; then
  _rbody=$(printf '%s' "$FEEDBACK_BODY" \
    | sed "s/\"tags\":\[/\"tags\":[\"reply\",\"for:$(printf '%s' "$ACCRETE_REPLY" | tr -c 'a-zA-Z0-9-' '-')\",/")
  if _post "$BASE/api/signal/loop:feedback" "$_rbody" 6 >/dev/null 2>&1; then REPLIED="$ACCRETE_REPLY"
  else REPLIED=unreached; fi
fi

# ── mark · warn — the close closes its own loop ─────────────────────────────
# Rule 1: every signal closes with mark() or warn(). The close has been emitting
# a feedback signal for months and depositing NOTHING, so the tags it travels on
# never learned whether travelling on them went well. Now each derived tag gets
# one verb on the edge `tag:<workspace>:<tag> → close:<outcome>`, carrying the
# whole tag set — so `mark` on a closed run and `warn` on an open one moves the
# same weighted Paths the router reads, and a tag that keeps riding bad closes
# stops out-ranking one that does not.
#
#   closed  -> mark  strength 1
#   open    -> warn  strength 1   (a fail or an unrun; both are the loop not closed)
#   timeout -> NEITHER — a held lease is neutral by rule, the same rule that makes
#              the task and dims legs n/a on a timeout. A halt is not an outcome.
#
# Strength 1 and a `tag:` source, deliberately disjoint from the `decide:close:*`
# sources do-decide.sh reads: these marks must never become confidence for an
# auto-decision, or the close would be voting on its own authority.
MARKED=0; WARNED=0
if [ "$DRY" -eq 0 ] && [ "$STATUS" != "timeout" ] && [ -n "$CLOSE_TAGS" ]; then
  _verb=mark; [ "$CLOSED" = "true" ] || _verb=warn
  _tgt="close:$( [ "$CLOSED" = "true" ] && echo kept || echo open )"
  _tagj=$(printf '%s' "$CLOSE_TAGS" | awk '{for(i=1;i<=NF;i++){printf "%s\"%s\"",(i>1?",":""),$i}}')
  for t in $CLOSE_TAGS; do
    _edge=$(printf 'tag:%s:%s→%s' "$WORKSPACE" "$t" "$_tgt" | sed 's/:/%3A/g; s/→/%E2%86%92/g')
    if _post "$BASE/api/$_verb/$_edge" "{\"strength\":1,\"tags\":[$_tagj]}" 4 >/dev/null 2>&1; then
      [ "$_verb" = mark ] && MARKED=$((MARKED+1)) || WARNED=$((WARNED+1))
    fi
  done
fi

# A TAKEN DECISION IS ALWAYS ANNOUNCED, even when every row reached the board.
# That is the whole trade this layer makes: the human's veto moves from BEFORE
# the action to AFTER it, and that is only honest if they actually hear about it
# and hold the reversal. So `DECIDED > 0` pages on its own terms — not as a
# question, as a receipt with an undo line on it. A recommendation never pages;
# it is already on the board and in the report, and a notifier that fires for
# things nobody must act on is a notifier the human mutes.
NOTIFIED=none
if [ "$DRY" -eq 0 ] && { [ "$UNFILED" -gt 0 ] || [ "$NOTIFY" -eq 1 ] || [ "$DECIDED" -gt 0 ]; }; then
  if _notify_human "close ${SLUG:-session}: $UNRUN unrun, $FAIL fail, $UNFILED unfiled, $DECIDED decided —$OPEN_LEGS
$(for l in $OPEN_LEGS; do printf '  %s\n' "$(_fix_for "$l")"; done)${DECIDE_LINES}"; then NOTIFIED=sent; else NOTIFIED=failed; fi
fi

# ── report ──────────────────────────────────────────────────────────────────
ELAPSED=$(( $(date +%s) - T0 ))
if [ "$JSON" -eq 1 ]; then
  printf '{"slug":"%s","closed":%s,"elapsed_s":%d,"legs":{' "${SLUG:-}" "$CLOSED" "$ELAPSED"
  first=1
  for l in $LEGS_ALL; do
    [ "$first" -eq 1 ] || printf ','; first=0
    printf '"%s":{"status":"%s","secs":%s,"detail":"%s"}' "$l" "$(_status_of "$l")" "$(_secs_of "$l")" "$(_jsonesc "$(_detail_of "$l")")"
  done
  printf '},"pass":%d,"fail":%d,"unrun":%d,"na":%d,"filed":%d,"ledgered":%d,"unreached":%d,"notified":"%s","decided":%d,"recommended":%d,"marked":%d,"warned":%d,"tags":"%s"}\n' \
    "$PASS" "$FAIL" "$UNRUN" "$NA" "$FILED" "$LEDGERED" "$UNFILED" "$NOTIFIED" "$DECIDED" "$RECOMMENDED" \
    "${MARKED:-0}" "${WARNED:-0}" "$(_jsonesc "$CLOSE_TAGS")"
else
  _tag=""; [ "$DRY" -eq 1 ] && _tag="  (DRY-RUN)"
  echo "── close ${SLUG:-session}${_tag} ──"
  for l in $LEGS_ALL; do printf '  %-9s %-6s %3ss  %s\n' "$l" "$(_status_of "$l")" "$(_secs_of "$l")" "$(_detail_of "$l")"; done
  printf '  closed=%s  pass=%d fail=%d unrun=%d n/a=%d  %ds  door=%s\n' \
    "$CLOSED" "$PASS" "$FAIL" "$UNRUN" "$NA" "$ELAPSED" "$BASE"
  # The clock, split. "the close was slow" and "the promise proof was slow" are
  # different facts with different fixes, and the measured block is neither a leg
  # nor free — naming its seconds separately is what stops it being blamed on a door.
  printf '  speed:  %s| metrics=%ss  total=%ss\n' \
    "$(for l in $LEGS_ALL; do printf '%s=%ss ' "$l" "$(_secs_of "$l")"; done)" "${METRICS_S:-0}" "$ELAPSED"
  printf '  tags:   %s\n' "${CLOSE_TAGS:-none}"
  printf '  trail:  hop=%s origin=%s sender=%s reply=%s  budget=%sB  artifacts=%s\n' \
    "${ACCRETE_HOP:-1}" "${ACCRETE_ORIGIN:-}" "${ACCRETE_SENDER:--}" "${REPLIED:-none}" \
    "${ACCRETE_BUDGET:-0}" "$(printf '%s' "${ARTIFACTS:-}" | grep -o '"kind"' | grep -c . || echo 0)"
  printf '  verbs:  mark=%d warn=%d  on tag:%s:<tag>→close:%s\n' "${MARKED:-0}" "${WARNED:-0}" \
    "$WORKSPACE" "$( [ "$CLOSED" = "true" ] && echo kept || echo open )"
  if [ -n "$OPEN_LEGS" ] && [ "$DRY" -eq 0 ]; then
    printf '  open: filed=%d task(s)  ledger=%d row(s)  unreached=%d  human=%s\n' "$FILED" "$LEDGERED" "$UNFILED" "$NOTIFIED"
    for l in $OPEN_LEGS; do _wanted "$l" && printf '    %s → %s\n' "$l" "$(_fix_for "$l")"; done
    printf '  see them again: bash .claude/scripts/do-close.sh --pending\n'
  fi
  # The decisions, under the blockers they belong to. A TAKEN line always carries
  # its undo; a RECOMMEND line always carries the ranked options and their cost,
  # because a recommendation you cannot argue with is just a slower ask.
  if [ -n "$DECIDE_LINES" ]; then
    printf '  decide: taken=%d recommended=%d  (highway = 5 proven outcomes; one bad one revokes it)%s\n' \
      "$DECIDED" "$RECOMMENDED" "$DECIDE_LINES"
  fi

  # ── the numbers ───────────────────────────────────────────────────────────
  # ADDITIVE, NEVER A SEVENTH LEG, and that distinction is the whole design. The
  # six legs above decide `closed`; these rows decide nothing and can turn
  # nothing red. A metric that could fail a close would make this a closer people
  # route around — and the numbers would leave with it. So it runs AFTER the
  # verdict, inside its own budget, and its exit code is discarded on purpose.
  #
  # `/close` reported six leg states and almost no numbers about the WORK.
  # "closed=true pass=6" says the doors were knocked on. It does not say what
  # changed, whether this exact tree is proven, whether the branch reached trunk,
  # what is still open, or WHY something could not be measured. close-metrics.sh
  # composes those from the scripts that already own them.
  # Printed from the run captured above — NEVER re-run here. Two runs of a ~17s
  # measurement are two different trees on a box seven sessions are editing, and
  # the signal would then carry numbers the human never saw.
  if [ -s "$METRICS_TXT" ]; then sed '1d' "$METRICS_TXT"; fi
fi

[ "$STRICT" -eq 1 ] && [ "$CLOSED" = "false" ] && exit 1
exit 0
