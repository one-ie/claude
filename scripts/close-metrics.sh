#!/usr/bin/env bash
# close-metrics.sh — mine every DETERMINISTIC number a close can report, in one
# bounded read-only pass.
#
# manifest: needs-env
#   Only for the substrate reachability probe, which reads the same
#   ONE_ENV_FILE ladder do-signal.sh and do-close.sh read. Every other row is
#   local git / filesystem and needs nothing.
#
# WHY. `/close` reported six leg states and almost no numbers about the WORK.
# "closed=true pass=6" says the doors were knocked on; it does not say what
# changed, whether the tree is proven, whether the branch reached trunk, or why
# a gate could not run. Those numbers all exist — scattered across nine scripts,
# each of which a model was expected to remember to call. This is the one call.
#
# IT COMPOSES, IT DOES NOT RE-DERIVE. Every row below names an owner that
# already computes it (test-cached.sh for the receipt, machine-check.sh for
# pressure, deploy-record.sh for unlanded rows, rubric-weights.json for the
# weights). A number this script computed itself, that one of those also
# computes, is a second opinion — and a second opinion is drift with a delay on
# it. Where there is no owner, the row is git or the filesystem, directly.
#
# THE HONESTY LAW (verbatim from do-w4-gates.sh, and the reason this file is not
# a pile of `echo $(git ...)`): every row has FOUR states, never two —
#     ok    : measured, the number is real
#     bad   : measured, and the number is a problem
#     unrun : COULD NOT BE MEASURED — the source was absent, empty, or too slow
#     n/a   : does not apply to this close, by rule
# A number with no state beside it is the failure this law exists to stop. In
# THIS session, `grep -c "error TS" <file>` returned `0` against an output file
# a queued gate had not written yet — "zero errors" and "never ran" are the same
# three characters. Every numeric row here carries its state, and `unrun` never
# prints a zero.
#
# IT NEVER RUNS A GATE. `/close` is a FULL-lane trigger and a fast pass is never
# reported as a full pass — so this asks `test-cached.sh` (TEST_CACHE_KEY_ONLY=1,
# ~1s, structurally cannot start vitest) whether the tree ALREADY carries a
# receipt, and reads `.w4-gates.json` if a cycle left one. It must never invoke
# `do-w4-gates.sh` bare: that runs `do-reconcile.sh types`, a tsc that queues
# minutes behind the governor, and a metrics row is not worth a gate slot.
#
# IT CANNOT FAIL A CLOSE. It has its own budget, every external call is bounded,
# and it exits 0 unless its own arguments are wrong. A miner that made the
# closer slower or redder would be removed within a week, and then the numbers
# would be gone along with it.
#
# USAGE
#   close-metrics.sh [<slug>]                 every section, human-readable
#   close-metrics.sh --json                   one object, for a caller
#   close-metrics.sh --section work,tree      only these
#   close-metrics.sh --self-test              fixtures + the unrun proofs
#
# OPTIONS
#   --slug <slug>        the plan/promise this close is for (enables promise rows)
#   --composite <0.NN>   the cycle composite, so the rubric section can gate it
#   --dims k=v,...       per-axis scores (security,stability,simplicity,speed,integration)
#   --base <ref>         trunk to measure against          (default: origin/main)
#   --section <a,b>      work,tree,gates,rubric,close,machine,substrate  (default: all)
#   --budget <secs>      whole-run wall clock              (default: 20)
#   --json               machine-readable
#   --json-out <file>    ALSO write the JSON here — one measurement, two readers
#
# EXIT  0 always (2 on a usage error). A metric is never a verdict.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/.claude/scripts"
SLUG=""; COMPOSITE=""; DIMS=""; BASE_REF="${CLOSE_BASE_REF:-origin/main}"
SECTIONS="work,tree,gates,rubric,close,machine,substrate"
BUDGET="${CLOSE_METRICS_BUDGET:-20}"; JSON=0; SELFTEST=0
# ONE RUN, TWO CONSUMERS. The measured block costs ~17s of real work — git
# plumbing, a cache-key hash, a governor read. Running it once for the human and
# again for the machine would double that on the closer's critical path, and the
# two runs would measure different instants of a tree seven sessions are editing.
# --json-out writes the machine copy to a file while stdout stays the table, so
# the signal and the report are the SAME measurement, not two of them.
JSON_OUT=""
STARTED=$(date +%s)

while [ $# -gt 0 ]; do
  case "$1" in
    --slug) SLUG="${2:-}"; shift 2 ;;
    --composite) COMPOSITE="${2:-}"; shift 2 ;;
    --dims) DIMS="${2:-}"; shift 2 ;;
    --base) BASE_REF="${2:-}"; shift 2 ;;
    --section) SECTIONS="${2:-}"; shift 2 ;;
    --budget) BUDGET="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --json-out) JSON_OUT="${2:-}"; shift 2 ;;
    --self-test) SELFTEST=1; shift ;;
    -h|--help) sed -n '/^# USAGE/,/^# EXIT/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*) echo "close-metrics: unknown flag $1" >&2; exit 2 ;;
    *) [ -z "$SLUG" ] && SLUG="$1" || { echo "close-metrics: unexpected arg $1" >&2; exit 2; }; shift ;;
  esac
done

ROWS="$(mktemp)"; trap 'rm -f "$ROWS"' EXIT

# _row <section> <name> <value> <state> [note]
# The state is NOT optional and there is no default. A caller that forgets it
# gets `unrun`, because an unstated state is exactly the ambiguity this file
# exists to remove.
# US (0x1f) as the field separator, NOT a tab. Tab is IFS *whitespace*, and bash
# collapses runs of IFS whitespace — so a row with an empty value (`composite`
# before a score is passed) lost the field and every column after it shifted
# left, printing the STATE where the value belongs. A metrics file whose own
# report can mislabel a state is worse than no metrics file, and 0x1f is
# non-whitespace so `read` keeps every empty field exactly where it was written.
_ROW_FS=$'\037'
_row() {
  # Every field is flattened: a value containing a newline would split one row
  # into two and shift every column after it. That is not hypothetical — see the
  # `grep -c || echo 0` note in the machine section.
  local _1 _2 _3 _4 _5
  _1=$(printf '%s' "$1" | tr -d '\n\037'); _2=$(printf '%s' "$2" | tr -d '\n\037')
  _3=$(printf '%s' "${3:-}" | tr '\n' ' ' | tr -d '\037')
  _4=$(printf '%s' "${4:-unrun}" | tr -d '\n\037')
  _5=$(printf '%s' "${5:-}" | tr '\n' ' ' | tr -d '\037')
  printf '%s%s%s%s%s%s%s%s%s\n' "$_1" "$_ROW_FS" "$_2" "$_ROW_FS" "$_3" "$_ROW_FS" "$_4" "$_ROW_FS" "$_5" >> "$ROWS"
}
_want() { case ",$SECTIONS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
_has()  { command -v "$1" >/dev/null 2>&1; }
_left() { echo $(( BUDGET - ( $(date +%s) - STARTED ) )); }

# Every external call goes through here. A source that hangs costs its own
# budget and reports `unrun`; it never costs the run.
_try() { # _try <secs> <cmd...>  → stdout, rc
  local secs="$1"; shift
  local left; left=$(_left); [ "$left" -lt 1 ] && return 124
  [ "$secs" -gt "$left" ] && secs="$left"
  if [ -f "$S/lib/govern.sh" ]; then
    # shellcheck disable=SC1090
    ( . "$S/lib/govern.sh" >/dev/null 2>&1; run_bounded "$secs" "$@" ) 2>/dev/null
  else
    "$@" 2>/dev/null
  fi
}

# ── work — what actually changed ────────────────────────────────────────────
# Against the INDEX AND the worktree (`git diff HEAD`), because a close happens
# before a commit as often as after one, and a metric that only sees committed
# work reports an empty session for the most common case.
if _want work; then
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    numstat="$(git -C "$ROOT" diff HEAD --numstat 2>/dev/null)"
    namest="$(git -C "$ROOT" diff HEAD --name-status 2>/dev/null)"
    untracked="$(git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null | grep -c . || true)"; untracked="${untracked:-0}"
    files=$(printf '%s' "$numstat" | grep -c . || true)
    ins=$(printf '%s\n' "$numstat" | awk -F'\t' '$1!="-"{s+=$1}END{print s+0}')
    del=$(printf '%s\n' "$numstat" | awk -F'\t' '$2!="-"{s+=$2}END{print s+0}')
    added=$(printf '%s\n' "$namest"  | awk '$1=="A"' | grep -c . || true)
    removed=$(printf '%s\n' "$namest"| awk '$1=="D"' | grep -c . || true)
    renamed=$(printf '%s\n' "$namest"| awk '$1 ~ /^R/' | grep -c . || true)
    paths=$(printf '%s\n' "$numstat" | awk -F'\t' '{print $3}')
    tests=$(printf '%s\n' "$paths" | grep -cE '(^|/)(tests?|__tests__)/|\.(test|spec)\.[tj]sx?$' || true)
    docs=$(printf '%s\n' "$paths"  | grep -cE '\.mdx?$' || true)
    code=$(( files - tests - docs )); [ "$code" -lt 0 ] && code=0

    # `files` is the only row here that can be legitimately 0 (a close with
    # nothing uncommitted), so it is `ok` at zero. The derived rows follow it.
    _row work files_changed    "$files"     ok  "vs HEAD, index + worktree"
    _row work lines_added      "$ins"       ok
    _row work lines_removed    "$del"       ok
    _row work files_new        "$added"     ok
    _row work files_deleted    "$removed"   "$( [ "$removed" -gt 0 ] && echo bad || echo ok )" \
      "$( [ "$removed" -gt 0 ] && echo 'a delete takes the FULL lane — vitest related cannot see a file that is gone' )"
    _row work files_renamed    "$renamed"   "$( [ "$renamed" -gt 0 ] && echo bad || echo ok )" \
      "$( [ "$renamed" -gt 0 ] && echo 'a rename takes the FULL lane' )"
    _row work files_untracked  "$untracked" ok  "new files git has never seen"
    _row work test_files       "$tests"     ok
    _row work doc_files        "$docs"      ok
    _row work code_files       "$code"      ok
    # Not a quality score — a RATIO, reported without a threshold on purpose.
    # `test-coverage` is an axis rubric-weights.json says is "scored by NOTHING
    # today"; inventing a number for it would put a fake input into a real gate.
    if [ "$code" -gt 0 ]; then
      _row work tests_per_code_file "$(awk -v t="$tests" -v c="$code" 'BEGIN{printf "%.2f", t/c}')" ok "ratio only — NOT a coverage figure"
    else
      _row work tests_per_code_file "" n/a "no code files changed"
    fi
    biggest=$(printf '%s\n' "$numstat" | awk -F'\t' '$1!="-"{print $1+$2"\t"$3}' | sort -rn | head -1)
    [ -n "$biggest" ] && _row work largest_file "$(printf '%s' "$biggest" | cut -f2) ($(printf '%s' "$biggest" | cut -f1) lines)" ok
  else
    _row work files_changed "" unrun "not a git repository"
  fi
fi

# ── tree — where this work is, and whether it reached trunk ─────────────────
if _want tree; then
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    br="$(git -C "$ROOT" branch --show-current 2>/dev/null)"
    _row tree branch "${br:-<detached>}" "$( [ -n "$br" ] && echo ok || echo bad )"
    _row tree worktree "$ROOT" ok "$( [ -f "$ROOT/.git" ] && echo 'linked worktree' || echo 'primary tree' )"
    dirty=$(git -C "$ROOT" status --porcelain 2>/dev/null | grep -c . || true)
    # A dirty tree is not a fault — but it is the reason a receipt cannot bind,
    # since the memo key hashes `git diff HEAD` by content.
    _row tree dirty_paths "$dirty" "$( [ "$dirty" -gt 0 ] && echo bad || echo ok )" \
      "$( [ "$dirty" -gt 0 ] && echo 'a receipt minted on a dirty tree describes a tree that never ships' )"

    if git -C "$ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
      ahead=$(git -C "$ROOT" rev-list --count "$BASE_REF..HEAD" 2>/dev/null || echo)
      behind=$(git -C "$ROOT" rev-list --count "HEAD..$BASE_REF" 2>/dev/null || echo)
      _row tree commits_ahead  "${ahead:-}"  "$( [ -n "$ahead" ] && echo ok || echo unrun )" "vs $BASE_REF"
      _row tree commits_behind "${behind:-}" "$( [ -n "$behind" ] && { [ "${behind:-0}" -gt 30 ] && echo bad || echo ok; } || echo unrun )" \
        "$( [ "${behind:-0}" -gt 30 ] && echo 'trunk has moved far — a gate here measures a stale tree' )"
      # LANDED IS AN ANCESTRY FACT, NOT A MERGE RESULT. `git merge` succeeding is
      # a claim about an instant; being an ancestor of trunk is a fact about now.
      # Three lands on 2026-09-05 printed "main fast-forwarded" while main never
      # moved — this is the check that would have caught them.
      if git -C "$ROOT" merge-base --is-ancestor HEAD "$BASE_REF" 2>/dev/null; then
        _row tree landed yes ok "HEAD is an ancestor of $BASE_REF"
      else
        _row tree landed no ok "${ahead:-?} commit(s) not yet in $BASE_REF"
      fi
    else
      _row tree commits_ahead "" unrun "$BASE_REF does not resolve — fetch, or pass --base"
      _row tree landed "" unrun "no $BASE_REF to measure ancestry against"
    fi
    wt=$(git -C "$ROOT" worktree list 2>/dev/null | grep -c . || true)
    _row tree worktrees "$wt" "$( [ "$wt" -gt 12 ] && echo bad || echo ok )" \
      "$( [ "$wt" -gt 12 ] && echo 'each is ~120MB and one tsserver — bash .claude/scripts/do-auto.sh --gc' )"
  else
    _row tree branch "" unrun "not a git repository"
  fi
fi

# ── gates — what is PROVEN about this exact tree, never what could be run ────
if _want gates; then
  # THE RECEIPT — is this exact tree already proven by a FULL suite?
  #
  # `test-full.sh` is THE one definition of the full suite, and it fans out to a
  # `test-cached.sh` per lane. TEST_CACHE_KEY_ONLY=1 makes every one of them
  # print its key and exit 0 WITHOUT starting vitest — ~1s, and it structurally
  # cannot launch a suite. That last property is why this row is allowed to
  # exist at all: `/close` is a FULL-lane trigger and a fast pass is never
  # reported as a full pass, so the only honest question is "does a receipt
  # already exist", never "let me go and make one".
  #
  # Calling `test-cached.sh` directly here was WRONG and read as `unrun` on a
  # tree that may well have been proven: that script takes a `<folder>` and
  # prints a usage line without one. do-close.sh's own gate leg already knew
  # this. Composing the owner beats re-deriving it — the same rule as everywhere
  # else in this file.
  #
  # The key is content-addressed, so a NEIGHBOUR'S suite on this same tree counts
  # as yours. A memo HIT is free and it counts.
  if [ -f "$S/test-full.sh" ]; then
    keys="$(cd "$ROOT" && TEST_CACHE_KEY_ONLY=1 _try 12 bash .claude/scripts/test-full.sh | grep -Eo '^[0-9a-f]{64}$')"
    # ${TMPDIR:-/tmp}/one-test-cache — the SAME default test-cached.sh:32 mints into
    # and do-close.sh:110 reads. It used to be "$ROOT/.claude/.test-cache", a path no
    # minter has ever written to, so `ls` found nothing and this row could only ever
    # answer MISS. Measured 2026-09-15 on a tree whose two lanes were both stamped:
    # the gate LEG read "pass — 2/2 lane(s), minted 09:16:44Z" and this row read
    # "MISS 0/2", same tree, same second. A permanent false RED on the one row that
    # gates the board write.
    #
    # This is the file's own Rule 1 broken — "it composes, it never re-derives". The
    # row re-derived the cache PATH instead of taking the owner's, which is the same
    # drift-with-a-delay that made it call test-cached.sh without a <folder>. Both
    # halves of that lesson are now spent; the path is not to be re-derived either.
    cache="${TEST_CACHE_DIR:-${TMPDIR:-/tmp}/one-test-cache}"
    if [ -z "$keys" ]; then
      _row gates full_suite_receipt "" unrun "test-full.sh printed no receipt key inside its budget"
    else
      n=0; hit=0
      for k in $keys; do
        n=$((n+1))
        ls "$cache" 2>/dev/null | grep -q "$k" && hit=$((hit+1))
      done
      if [ "$hit" -eq "$n" ]; then
        _row gates full_suite_receipt "HIT $hit/$n" ok "every lane of the FULL suite is stamped for THIS tree"
      else
        _row gates full_suite_receipt "MISS $hit/$n" bad "cd one.ie/web && FULL_VERIFY=1 bun run verify — an unstamped lane is an UNRUN lane, never a passed one"
      fi
    fi
  else
    _row gates full_suite_receipt "" unrun "test-full.sh not in this tree"
  fi

  # A cycle's own gate pack, if one was left. NEVER regenerated here: running
  # do-w4-gates.sh bare runs do-reconcile.sh types, a tsc that queues behind the
  # governor, and no metrics row is worth a gate slot.
  pack=""
  for c in "$ROOT/.w4-gates.json" "$ROOT/.claude/.w4-gates.json"; do [ -f "$c" ] && pack="$c" && break; done
  if [ -n "$pack" ] && _has jq; then
    for st in pass fail unrun; do
      _row gates "w4_$st" "$(jq -r "[.gates[]?|select(.status==\"$st\")]|length" "$pack" 2>/dev/null || echo)" \
        "$( [ "$st" = "fail" ] && echo bad || echo ok )" "$(basename "$pack")"
    done
    _row gates w4_deterministic_pass "$(jq -r '.deterministic_pass//empty' "$pack" 2>/dev/null)" ok
  else
    _row gates w4_pack "" unrun "no .w4-gates.json — this close did not come from a /do cycle, or W4 never wrote one"
  fi

  # delta_tsc is a HARD CONJUNCT of the cycle gate and it is a DELTA: it needs a
  # baseline to subtract from. There is no baseline file in this repo today, so
  # this row is honestly unrun rather than quietly 0. A 0 here would satisfy
  # `delta_tsc <= 0` on evidence that does not exist.
  base_tsc=""
  # One candidate, not two: the W0 baseline file this also used to accept was
  # gitignored state holding 999999, deleted 2026-09-21 with its readers (rung
  # A5, text/do-factory-plan.md § 7 Phase A).
  [ -f "$ROOT/.claude/.tsc-baseline" ] && base_tsc="$ROOT/.claude/.tsc-baseline"
  if [ -n "$base_tsc" ]; then
    _row gates delta_tsc "" unrun "baseline at $base_tsc — compare after a measured tsc; this script never runs one"
  else
    _row gates delta_tsc "" unrun "no W0 baseline on disk — delta_tsc is unmeasurable, so the cycle gate cannot be scored green"
  fi
fi

# ── rubric — the verdict, gated against weights this file never restates ────
if _want rubric; then
  W="$ROOT/.claude/scripts/rubric-weights.json"
  if [ -f "$W" ] && _has jq; then
    gate=$(jq -r '.gate' "$W"); gfgate=$(jq -r '.goalFitGate' "$W")
    _row rubric gate_threshold    "$gate"   ok "composite must be >= this (rubric-weights.json)"
    _row rubric goalfit_threshold "$gfgate" ok "goal-fit must be >= this — independent HARD gate"
  else
    _row rubric gate_threshold "" unrun "rubric-weights.json unreadable — the thresholds are NOT restated anywhere else"
  fi
  if [ -n "$COMPOSITE" ]; then
    _row rubric composite "$COMPOSITE" \
      "$(awk -v c="$COMPOSITE" -v g="${gate:-0.65}" 'BEGIN{print (c+0>=g+0)?"ok":"bad"}')" "cycle rubric"
  else
    _row rubric composite "" unrun "no --composite passed — a close with no score is not a scored close"
  fi
  if [ -n "$DIMS" ]; then
    # `printf '%s'` with no trailing newline loses the LAST field: `read` returns
    # non-zero on a final unterminated line and the loop body never runs for it.
    # Measured — `--dims security=0.9,stability=0.8` reported security and
    # silently dropped stability, which is a missing axis in a weighted gate.
    printf '%s\n' "$DIMS" | tr ',' '\n' | while IFS='=' read -r k v; do
      [ -z "$k" ] && continue
      printf 'rubric%saxis_%s%s%s%s%s%s\n' "$_ROW_FS" "$k" "$_ROW_FS" "$v" "$_ROW_FS" \
        "$(awk -v x="$v" 'BEGIN{print (x+0>=0.5)?"ok":"bad"}')" "$_ROW_FS" >> "$ROWS"
    done
  else
    _row rubric axes "" unrun "no --dims passed"
  fi
  # VELOCITY — against the previous composite in text/learnings.md. Both
  # separators are matched because the file genuinely carries both
  # (`composite 0.88` and `composite=0.89`); a regex that matched one would
  # report `+0.00`, which is indistinguishable from "no change" and is the worst
  # failure mode a metric has.
  L="$ROOT/text/learnings.md"
  if [ -f "$L" ]; then
    prev="$(grep -oE 'composite[ =:]+[0-9]*\.?[0-9]+' "$L" 2>/dev/null | tail -1 | grep -oE '[0-9]*\.?[0-9]+$')"
    n="$(grep -cE 'composite[ =:]+[0-9]' "$L" 2>/dev/null || true)"; n="${n:-0}"
    if [ -n "$prev" ] && [ -n "$COMPOSITE" ]; then
      _row rubric velocity "$(awk -v a="$COMPOSITE" -v b="$prev" 'BEGIN{printf "%+.2f", a-b}')" ok "vs $prev, the last of $n recorded"
    elif [ -n "$prev" ]; then
      _row rubric velocity "" unrun "last recorded is $prev ($n rows) — pass --composite to get a delta"
    else
      _row rubric velocity "" unrun "no composite found in text/learnings.md"
    fi
  else
    _row rubric velocity "" unrun "text/learnings.md absent"
  fi
fi

# ── close — what this repo already knows is unclosed ────────────────────────
if _want close; then
  LED="${CLOSE_LEDGER:-$ROOT/.claude/.close-pending.jsonl}"
  if [ -f "$LED" ]; then
    open=$(grep -c . "$LED" 2>/dev/null || true); open="${open:-0}"
    _row close ledger_open "$open" "$( [ "$open" -gt 0 ] && echo bad || echo ok )" \
      "$( [ "$open" -gt 0 ] && echo 'bash .claude/scripts/do-close.sh --pending' )"
  else
    _row close ledger_open 0 ok "no ledger yet — nothing has ever failed to close"
  fi
  if [ -f "$S/deploy-record.sh" ]; then
    out="$(_try 8 bash "$S/deploy-record.sh" --pending)"; rc=$?
    case "$rc" in
      0)   _row close deploy_rows_pending 0 ok "trunk carries every recorded run" ;;
      6)   _row close deploy_rows_pending "$(printf '%s' "$out" | grep -cE '^\s*\{|run' || echo '?')" bad \
             "bash .claude/scripts/deploy-record.sh --land — from a worktree cut from trunk" ;;
      124) _row close deploy_rows_pending "" unrun "deploy-record.sh --pending exceeded its budget" ;;
      *)   _row close deploy_rows_pending "" unrun "deploy-record.sh --pending exit=$rc" ;;
    esac
  else
    _row close deploy_rows_pending "" unrun "deploy-record.sh not found"
  fi
  # The mirror. `packages/claude` is GENERATED from `.claude` by
  # sync-claude-mirror.sh, and when it drifts the STALE copy is what a plugin
  # user's `/close` loads — so the authority is edited and nothing changes.
  if [ -f "$S/sync-claude-mirror.sh" ]; then
    _try 10 bash "$S/sync-claude-mirror.sh" --check >/dev/null 2>&1; rc=$?
    case "$rc" in
      0)   _row close claude_mirror in-sync ok ;;
      124) _row close claude_mirror "" unrun "mirror check exceeded its budget" ;;
      *)   _row close claude_mirror DRIFT bad "packages/claude is behind .claude — the STALE copy is what a plugin's /close loads. bash .claude/scripts/sync-claude-mirror.sh" ;;
    esac
  else
    _row close claude_mirror "" unrun "sync-claude-mirror.sh not found"
  fi
  if [ -n "$SLUG" ] && [ -f "$S/do-derives-check.sh" ]; then
    _try 8 bash "$S/do-derives-check.sh" "$SLUG" >/dev/null 2>&1; rc=$?
    case "$rc" in
      0)   _row close derives complete ok "every 'derives: true' artifact is on disk" ;;
      124) _row close derives "" unrun "derives check exceeded its budget" ;;
      *)   _row close derives missing bad "bash .claude/scripts/do-derives-check.sh $SLUG" ;;
    esac
  else
    _row close derives "" n/a "$( [ -z "$SLUG" ] && echo 'no slug — nothing to derive from' || echo 'do-derives-check.sh not found' )"
  fi
fi

# ── machine — the context that turns "unrun" from a mystery into a reason ───
# This section exists because "tsc not measured, box saturated" once closed three
# cycles green. The pressure is not a metric about the work; it is the EVIDENCE
# for every unrun row above it.
if _want machine; then
  cores="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null)"
  load="$(uptime 2>/dev/null | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')"
  if [ -n "$load" ] && [ -n "$cores" ]; then
    _row machine load "$load / ${cores} cores" \
      "$(awk -v l="$load" -v c="$cores" 'BEGIN{print (l+0 > 2*c)?"bad":"ok"}')" \
      "$(awk -v l="$load" -v c="$cores" 'BEGIN{if(l+0>2*c) print "saturated — a queued gate is a WAIT, not a hang"}')"
  else
    _row machine load "" unrun "could not read load or core count"
  fi
  if _has vm_stat; then
    free_mb=$(vm_stat 2>/dev/null | awk '/Pages free/{gsub(/\./,"",$3); print int($3*4096/1048576)}')
    [ -n "$free_mb" ] && _row machine free_mb "$free_mb" "$( [ "${free_mb:-0}" -lt 512 ] && echo bad || echo ok )" \
      "$( [ "${free_mb:-0}" -lt 512 ] && echo 'memory is the binding constraint on gate concurrency, not cores' )" \
      || _row machine free_mb "" unrun "vm_stat gave no page count"
  else
    _row machine free_mb "" unrun "vm_stat absent (not a mac)"
  fi
  gd="${GOVERN_DIR:-${TMPDIR:-/tmp}/one-govern}"
  if [ -d "$gd" ]; then
    # `grep -c` already prints 0 when it matches nothing — it just EXITS 1. So
    # `grep -c … || echo 0` emits TWO lines ("0\n0"), and a multi-line value tore
    # the row apart: the report printed the note where the state belongs.
    # Measured by --self-test's stateless-row check, which is why that check
    # asserts structure rather than trusting the writer.
    slots=$(ls "$gd" 2>/dev/null | grep -c '^slot-' || true)
    locks=$(ls "$gd" 2>/dev/null | grep -c '^lock-' || true)
    _row machine gate_slots_held "$slots" ok "machine-wide; this is what a queueing gate is waiting for"
    _row machine gate_locks "$locks" ok
  else
    _row machine gate_slots_held "" unrun "no governor dir at $gd — nothing has taken a slot yet"
  fi
fi

# ── substrate — is there a door to close through at all ─────────────────────
if _want substrate; then
  base="${ONE_API_URL:-}"
  if [ -z "$base" ]; then
    if _try 2 curl -fsS -m 1 -o /dev/null "http://localhost:4321/api/health"; then base="http://localhost:4321"; else base="https://one.ie"; fi
  fi
  code="$(_try 6 curl -s -o /dev/null -w '%{http_code}' -m 5 "$base/api/health")"
  case "$code" in
    200) _row substrate door "$base" ok "reachable — the close can write" ;;
    "")  _row substrate door "$base" unrun "no answer inside the budget — the close will FILE its legs, not drop them" ;;
    *)   _row substrate door "$base" bad "health returned $code — board writes will be filed to the ledger instead" ;;
  esac
  if [ -n "$SLUG" ]; then
    P="$ROOT/text/$SLUG.md"
    if [ -f "$P" ]; then
      if grep -qE '^\s*proof:' "$P" 2>/dev/null; then
        _row substrate promise "$SLUG" ok "text/$SLUG.md carries a proof: — settleable"
      else
        _row substrate promise "$SLUG" bad "text/$SLUG.md has no proof: — a promise with no observable settles DISSOLVED"
      fi
    else
      _row substrate promise "" n/a "no text/$SLUG.md — this close has no promise"
    fi
  else
    _row substrate promise "" n/a "no slug given"
  fi
fi

# ── self-test ───────────────────────────────────────────────────────────────
if [ "$SELFTEST" -eq 1 ]; then
  echo "── close-metrics.sh --self-test ──"; fails=0
  ck() { if [ "$1" = 0 ]; then echo "ok: $2"; else echo "FAIL: $2"; fails=$((fails+1)); fi; }

  out="$(bash "${BASH_SOURCE[0]}" --section work,tree 2>&1)"
  printf '%s' "$out" | grep -q 'files_changed'; ck $? "work section reports files_changed"
  printf '%s' "$out" | grep -q 'landed'; ck $? "tree section reports landed as an ANCESTRY fact"

  # THE UNRUN PROOF, and it is the whole point of the file. Point a section at a
  # source that does not exist and require the row to read `unrun` — never `0`.
  # A miner that prints 0 for an absent source is the `grep -c` trap with a
  # nicer font, and this repo has shipped that failure.
  out="$(CLOSE_BASE_REF=refs/heads/definitely-not-a-branch bash "${BASH_SOURCE[0]}" --section tree 2>&1)"
  printf '%s' "$out" | grep -E 'landed .*unrun' >/dev/null; ck $? "RED PROOF — an unresolvable base makes landed UNRUN, not 'no'"
  # Anchored on the VALUE COLUMN, not the line: the unrun row's own note reads
  # "no origin/main to measure ancestry against", and a bare /(yes|no)/ matched
  # that word in the prose and reported a verdict the code never emitted. A
  # checker that fails on its own note is noise, and noise is how a red proof
  # stops being read.
  CLOSE_BASE_REF=refs/heads/definitely-not-a-branch bash "${BASH_SOURCE[0]}" --section tree --json 2>/dev/null \
    | tr ',' '\n' | grep -A1 '"name":"landed"' | grep -qE '"value":"(yes|no)"' \
    && { echo "FAIL: unresolvable base still asserted a landed verdict"; fails=$((fails+1)); }

  out="$(TEST_CACHE_DIR=/definitely/not/here bash "${BASH_SOURCE[0]}" --section gates 2>&1)"
  printf '%s' "$out" | grep -E 'full_suite_receipt .*(MISS|unrun)' >/dev/null
  ck $? "RED PROOF — an absent receipt cache is MISS or unrun, never a green receipt"

  # GREEN PROOF — and it is the half that was missing, which is how the row stayed
  # broken. The red proof above passes just as happily when the row can ONLY answer
  # red: for months `cache` defaulted to "$ROOT/.claude/.test-cache", a path no
  # minter has ever written to, so MISS was the only reachable verdict and the one
  # check guarding it was satisfied by the defect. Measured 2026-09-15: the gate LEG
  # read "pass — 2/2 lane(s)" on a tree this row called "MISS 0/2", same second.
  #
  # A check that cannot go both ways is not a check. But note WHERE the fault was:
  # in the DEFAULT. A proof that exports TEST_CACHE_DIR overrides that default and
  # passes against the broken version too — verified, and it is why the first attempt
  # at this check was worthless. So the proof reads the default EXPRESSION and
  # requires it to be the same one the minter uses.
  minter="$(grep -m1 '^CACHE_DIR=' "$ROOT/.claude/scripts/test-cached.sh" | sed 's/^CACHE_DIR=//')"
  mine="$(grep -m1 '^[[:space:]]*cache=' "${BASH_SOURCE[0]}" | sed 's/^[[:space:]]*cache=//')"
  [ -n "$minter" ] && [ "$minter" = "$mine" ]
  ck $? "PARITY — the receipt cache default matches test-cached.sh's (minter: ${minter:-?} / reader: ${mine:-?})"

  out="$(bash "${BASH_SOURCE[0]}" --section rubric 2>&1)"
  printf '%s' "$out" | grep -q 'no --composite passed'
  ck $? "RED PROOF — no --composite is UNRUN, never a zero score"
  # delta_tsc lives in `gates`, not `rubric`. Asking the wrong section for it
  # returned nothing and read as a failure — the check was wrong, not the code.
  out="$(bash "${BASH_SOURCE[0]}" --section gates 2>&1)"
  printf '%s' "$out" | grep 'delta_tsc' | grep -q unrun
  ck $? "RED PROOF — delta_tsc with no baseline is UNRUN (a 0 would satisfy the gate on no evidence)"

  # The budget is real: a run must not outlive it by more than a slack second.
  t0=$(date +%s); bash "${BASH_SOURCE[0]}" --budget 3 >/dev/null 2>&1; t1=$(date +%s)
  [ $(( t1 - t0 )) -le 12 ]; ck $? "the whole run respects its budget (took $(( t1 - t0 ))s)"

  # Every row carries a state, always. This is the law the file is built on, so
  # it is asserted structurally rather than trusted.
  bad=$(bash "${BASH_SOURCE[0]}" --json 2>/dev/null | tr ',' '\n' | grep -c '"state":""' || true)
  [ "${bad:-0}" -eq 0 ]; ck $? "every row carries one of the four states (stateless rows: ${bad:-?})"

  echo "──"
  [ "$fails" -eq 0 ] && { echo "close-metrics self-test: PASS"; exit 0; }
  echo "close-metrics self-test: $fails FAILURE(S)"; exit 1
fi

# ── report ──────────────────────────────────────────────────────────────────
OK=$(awk -F'\037' '$4=="ok"' "$ROWS" | grep -c . || true)
BAD=$(awk -F'\037' '$4=="bad"' "$ROWS" | grep -c . || true)
UNRUN=$(awk -F'\037' '$4=="unrun"' "$ROWS" | grep -c . || true)
NA=$(awk -F'\037' '$4=="n/a"' "$ROWS" | grep -c . || true)
ELAPSED=$(( $(date +%s) - STARTED ))

_emit_json() {
  printf '{"slug":"%s","elapsed_s":%d,"ok":%d,"bad":%d,"unrun":%d,"na":%d,"rows":[' \
    "$SLUG" "$ELAPSED" "$OK" "$BAD" "$UNRUN" "$NA"
  local first=1 sec name val state note
  while IFS="$_ROW_FS" read -r sec name val state note; do
    [ -n "$sec" ] || continue
    [ "$first" -eq 1 ] || printf ','; first=0
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\000-\037'; }
    printf '{"section":"%s","name":"%s","value":"%s","state":"%s","note":"%s"}' \
      "$(esc "$sec")" "$(esc "$name")" "$(esc "$val")" "$(esc "$state")" "$(esc "$note")"
  done < "$ROWS"
  printf ']}\n'
}
[ -n "$JSON_OUT" ] && _emit_json > "$JSON_OUT" 2>/dev/null

if [ "$JSON" -eq 1 ]; then
  printf '{"slug":"%s","elapsed_s":%d,"ok":%d,"bad":%d,"unrun":%d,"na":%d,"rows":[' \
    "$SLUG" "$ELAPSED" "$OK" "$BAD" "$UNRUN" "$NA"
  first=1
  while IFS="$_ROW_FS" read -r sec name val state note; do
    [ -z "$sec" ] && continue
    [ "$first" -eq 1 ] || printf ','; first=0
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\000-\037'; }
    printf '{"section":"%s","name":"%s","value":"%s","state":"%s","note":"%s"}' \
      "$(esc "$sec")" "$(esc "$name")" "$(esc "$val")" "$(esc "$state")" "$(esc "$note")"
  done < "$ROWS"
  printf ']}\n'
else
  echo "── metrics ${SLUG:-session} ──"
  last=""
  while IFS="$_ROW_FS" read -r sec name val state note; do
    [ -z "$sec" ] && continue
    [ "$sec" != "$last" ] && { echo "  [$sec]"; last="$sec"; }
    # `-` not an em-dash: printf's %-28s pads by BYTES, and a 3-byte glyph in a
    # 1-column slot shifts every row that uses it. A report whose own columns
    # drift is a report people stop scanning.
    printf '    %-24s %-28s %-6s %s\n' "$name" "${val:--}" "$state" "$note"
  done < "$ROWS"
  printf '  ok=%d bad=%d unrun=%d n/a=%d  %ds\n' "$OK" "$BAD" "$UNRUN" "$NA" "$ELAPSED"
  [ "$UNRUN" -gt 0 ] && echo "  NOTE: an unrun row is NOT a good row. It is a number nobody has."
fi
exit 0
