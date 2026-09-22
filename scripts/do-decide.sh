#!/usr/bin/env bash
# do-decide.sh — the layer between "a leg is open" and "a human is asked".
#
# manifest: needs-env
#   Reads GATEWAY_API_KEY through ONE_ENV_FILE, exactly as do-close.sh does.
#   Its one network call is a PURE READ (world:route decide:true — zero side
#   effects, zero tokens, no delivery, no mark). The writer half (mark/warn) is
#   the settle path, and it writes strength 1 only.
#
# WHY IT EXISTS. /close closed what it could and filed a row for the rest. Every
# row named a command and waited for a person — including the rows whose answer
# was never in doubt. A blocker that resolves the same way every time is not a
# decision; it is a chore with a human bolted to it. And a blocker that IS a
# decision was filed as bare prose: "gate unrun", no options, no recommendation,
# no cost. So the person had to re-derive the fork every time.
#
# THE CONTRACT, in one line: for every open leg, name the fork, rank the options,
# recommend one, and TAKE it when — and only when — the substrate has already
# watched that choice come good five times.
#
# CONFIDENCE IS MEASURED, NOT ASSERTED, AND IT IS NOT MINE.
# The oracle is the substrate's own routing verdict — `world:route decide:true`
# (subscriptions.ts:672), the deterministic TS twin of 0043_route_verdict.tql:
#
#     highway     best >= 5 (HARDEN_STRENGTH) AND best >= 2 x second   -> ACT
#     classified  a candidate, but not a proven one                    -> RECOMMEND
#     ceo         no candidate at all                                  -> RECOMMEND
#
# where `best` is SUM(strength) - SUM(resistance) over `claw_paths` rows from
# `tag:one:decide:close:<id>` to each option, and a path stops being a candidate
# at all once resistance >= 0.2 x strength. Measured against production
# 2026-09-09, the whole loop in three calls:
#
#     0 marks              -> {"reason":"ceo","receiver":null,"rung":3}
#     5 marks of strength 1-> {"reason":"highway","receiver":"optionA","rung":1}
#     + 1 warn             -> {"reason":"ceo","receiver":null,"rung":3}
#
# So the first five times a fork appears, a person answers it. After that the
# substrate has the base rate and /close acts. One bad outcome takes the
# authority away again on the very next run. That is the root CLAUDE.md's "human
# gates that auto-skip when trust earns it", applied to close blockers, using the
# mechanism G4 already uses for the auto-ship gate (text/factory-do.md).
#
# WHY strength 1, ALWAYS. rankCandidates sums strength; it cannot tell 5 marks of
# 1 from 1 mark of 5. HARDEN_STRENGTH = 5 is therefore a de-facto n>=5 SAMPLE
# floor only while every writer on `tag:one:decide:close:*` writes 1. This script
# is that sole writer and `--self-test` pins it. A future writer that marks these
# sources with strength > 1 turns a single event into a highway — don't.
#
# WHY AN UNREACHABLE SUBSTRATE ASKS. The decide lane's own D1 catch falls to
# "no candidates -> ceo", and a bounded curl that never answers is read here the
# same way. Every failure direction in this file points at the human. A layer
# that acts when it cannot measure is worse than the ask it replaced.
#
# THE VETO IS NOT A CONFIDENCE NUMBER, AND CONFIDENCE CANNOT OUTRANK IT.
# Blast radius is a second axis. A vetoed fork never reaches the oracle at all —
# structurally unreachable, not reachable-and-outranked — so no amount of
# accumulated strength can ever license it. See _veto_for.
#
# USAGE
#   do-decide.sh --leg <leg> --status <s> --detail <d> [--slug <s>] [--apply]
#                                        one open leg -> a verdict line (+ act)
#   do-decide.sh --settle --leg <leg> --outcome pass|open [--slug <s>]
#                                        the closed loop: mark/warn the option
#   do-decide.sh --table                 the decision table, as it is
#   do-decide.sh --self-test             fixtures + RED PROOFS
#
# OPTIONS
#   --apply          take the decision when the verdict is `highway`. Without it
#                    this script is a pure reporter — do-close.sh --dry-run and
#                    the self-test rely on that.
#   --budget <secs>  oracle + action wall clock            (default: 12)
#   --json           one JSON object on stdout
#
# EXIT
#   0  a verdict was produced (taken OR recommended — both are success)
#   4  the fork is vetoed: it will never be automatic, and the row says why
#   5  no decision table entry for this leg+detail — the caller files as before
#   2  usage
#
# It never returns non-zero for "the substrate was down" or "confidence was low".
# Those are ordinary answers, and a closer that fails on them is a closer callers
# route around — do-close.sh's founding lesson, inherited whole.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ONE_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
_MONOREPO_ENV_CANDIDATES="$ROOT/one.ie/web/.env $ROOT/one.ie/web/.dev.vars"
WORKSPACE="${CC_TASKS_WORKSPACE:-one}"

LEG=""; DSTATUS=""; DETAIL=""; SLUG=""; APPLY=0; BUDGET="${DECIDE_BUDGET:-12}"
JSON=0; SETTLE=0; OUTCOME=""; TABLE=0; SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --leg) LEG="${2:-}"; shift 2 ;;
    --status) DSTATUS="${2:-}"; shift 2 ;;
    --detail) DETAIL="${2:-}"; shift 2 ;;
    --slug) SLUG="${2:-}"; shift 2 ;;
    --outcome) OUTCOME="${2:-}"; shift 2 ;;
    --budget) BUDGET="${2:-12}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --settle) SETTLE=1; shift ;;
    --table) TABLE=1; shift ;;
    --json) JSON=1; shift ;;
    --self-test) SELFTEST=1; shift ;;
    -h|--help) sed -n '/^# USAGE/,/^# EXIT/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "do-decide: unknown arg $1" >&2; exit 2 ;;
  esac
done

_env_key() {
  local _f _v
  for _f in "$ONE_ENV_FILE" "$ROOT/.env" $_MONOREPO_ENV_CANDIDATES; do
    [ -f "$_f" ] || continue
    _v=$(grep -E "^$1=" "$_f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//' || true)
    [ -n "$_v" ] && { printf '%s' "$_v"; return 0; }
  done
  printf ''
}
_base() {
  if [ -n "${ONE_API_URL:-}" ]; then printf '%s' "$ONE_API_URL"; return; fi
  curl -s -o /dev/null --max-time 1.5 --connect-timeout 1 "http://localhost:4321/api/health" 2>/dev/null \
    && printf 'http://localhost:4321' || printf 'https://one.ie'
}
_jsonesc() { printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n' ' '; }

# ═══ THE DECISION TABLE ═════════════════════════════════════════════════════
# Four entries, and the fourth is a veto. This is deliberately a TABLE and not an
# engine: it was enumerated from do-close.sh's actual `_emit` call sites, not
# imagined. A fork that is not in this table is not a decision — exit 5, and the
# caller files the row exactly as it did before. Adding a row is how this grows;
# generalising it is how it starts guessing.
#
#   id | fires on                       | options (first = the declared prior)
#   ---+--------------------------------+------------------------------------
#   gate-mint      gate unrun, no receipt   mint · file
#   derives-retry  derives unrun (out of clock) retry · file
#   promise-retry  promise unrun (exit 3 / clock) retry · file
#   writeback      dims|feedback|task unrun at a door  file            [VETO]
#   task-gate      task unrun, gate not pass           file            [VETO]
_decision_for() { # <leg> <status> <detail> -> "<id> <opt1> <opt2>" or ""
  local leg="$1" st="$2" d="$3"
  [ "$st" = "unrun" ] || { printf ''; return; }   # a `fail` is a verdict, not a fork
  case "$leg" in
    gate)     case "$d" in *"no full-suite receipt"*) printf 'gate-mint mint file' ;; *) printf '' ;; esac ;;
    derives)  case "$d" in *"exceeded"*) printf 'derives-retry retry file' ;; *) printf '' ;; esac ;;
    promise)  case "$d" in
                *"UNVERIFIABLE"*|*"exceeded"*) printf 'promise-retry retry file' ;;
                *) printf '' ;; esac ;;
    dims|feedback) printf 'writeback file' ;;
    task)     printf 'task-gate file' ;;
    *)        printf '' ;;
  esac
}

# ═══ THE VETO ═══════════════════════════════════════════════════════════════
# Checked BEFORE the oracle is called, so a vetoed fork is structurally
# unreachable rather than reachable-but-outranked. Two standing vetoes, each with
# its measured reason, plus the blanket class.
_veto_for() { # <id> -> reason, or empty
  case "$1" in
    writeback)
      # THE SELF-POISONING VETO, and it is the sharpest rule in this file.
      # dims, feedback and task write THROUGH doors (mark-dims, loop:feedback,
      # tasks:status). Their `unrun` is curl exit 7: the request timed out with
      # the answer UNKNOWN — the write may well have landed. A retry that
      # double-writes deposits strength twice on exactly the `claw_paths` rows
      # this script reads back as confidence. An auto-retry here would inflate
      # its own evidence, and the more it fired the more certain it would look.
      # No confidence number may buy that. Ever.
      printf 'an ambiguous WRITE cannot be retried — a double mark inflates the very weights this layer reads as confidence' ;;
    task-gate)
      # The repo's most expensive scar, named twice in do-close.sh's own header:
      # cycles closed green at 0.92 with "tsc not measured, box saturated".
      # The task<-gate edge is the thing that stopped it happening again.
      printf 'the board write must never be decided around its gate — cycles once closed green at 0.92 with the suite unmeasured' ;;
    *) printf '' ;;
  esac
}

# The blanket class, independent of the table: an action string that ships,
# deploys, pushes, deletes, force-writes, spends, or touches the shared main tree
# is never taken by this script, whatever the table or the oracle says. Applied
# to the COMMAND about to run, so a table row edited to smuggle one in still
# cannot fire.
_action_forbidden() { # <command> -> reason, or empty
  case "$1" in
    *"release.sh"*|*"deploy.sh"*|*"./deploy"*|*"wrangler deploy"*|*" ship"*)
      printf 'ships or deploys' ;;
    *"git push"*|*"--force"*|*"-f "*|*"git reset --hard"*|*"git clean"*)
      printf 'rewrites or discards history' ;;
    *"rm -rf"*|*"DROP "*|*"undefine"*|*"secret put"*)
      printf 'deletes or rotates' ;;
    *) printf '' ;;
  esac
}

# ═══ THE ACTIONS ════════════════════════════════════════════════════════════
# Every option is one line, and `file` is always the null action: it is what
# /close already did, so choosing it changes nothing and can break nothing.
_command_for() { # <id> <option> -> the command, or empty for the null action
  local s="${SLUG:-<slug>}"
  case "$1:$2" in
    gate-mint:mint)      printf 'cd %s/one.ie/web && FULL_VERIFY=1 bun run verify' "$ROOT" ;;
    derives-retry:retry) printf 'bash %s/.claude/scripts/do-derives-check.sh %s' "$ROOT" "$s" ;;
    promise-retry:retry) printf 'bash %s/.claude/scripts/do-promise-settle.sh %s' "$ROOT" "$s" ;;
    *:file)              printf '' ;;
    *)                   printf '' ;;
  esac
}

# What taking the option costs, so a recommendation carries its price and a
# reader can disagree with it on the evidence rather than on faith.
_cost_for() { # <id> <option>
  case "$1:$2" in
    gate-mint:mint)      printf '~87s + one governor gate slot' ;;
    derives-retry:retry) printf 'a bounded re-read, no gate slot' ;;
    promise-retry:retry) printf 'the promise proof, re-run bounded' ;;
    *:file)              printf 'nothing — this is what /close already does' ;;
    *)                   printf 'unknown' ;;
  esac
}

# gate-mint is the one option with a machine precondition: minting takes a gate
# slot, and taking the last slot on a saturated box is how this repo once ran six
# concurrent tsc at load 57. Confidence says the choice is right; headroom says
# whether NOW is the moment. Both must hold.
_precondition_for() { # <id> <option> -> reason it cannot run now, or empty
  [ "$1:$2" = "gate-mint:mint" ] || { printf ''; return; }
  local hr=99
  if [ -r "$ROOT/.claude/scripts/lib/govern.sh" ]; then
    hr=$( . "$ROOT/.claude/scripts/lib/govern.sh" >/dev/null 2>&1
          command -v gate_headroom >/dev/null 2>&1 && gate_headroom 2>/dev/null || echo 99 )
  fi
  case "$hr" in ''|*[!0-9]*) hr=99 ;; esac
  # A broken sensor reads 99 and must never silently block — govern.sh's own rule.
  [ "$hr" -lt 1 ] && printf 'no gate headroom (%s) — minting now would take the last slot on a saturated box' "$hr" || printf ''
}

# ═══ THE ORACLE ═════════════════════════════════════════════════════════════
# One bounded POST, a pure read. `workspace` must be nominated in the payload:
# world:route refuses with `forbidden: authentication required` when ctx.ownerSlug
# is unset, and a service key alone sets no slug (ask/[...receiver].ts:238 —
# a VERIFIED service caller may nominate one, nobody else may). Measured: without
# it, every verdict was `forbidden` and this layer would have asked forever.
_verdict() { # <id> -> "<reason> <receiver>"
  local key resp cfg reason recv
  key="$(_env_key GATEWAY_API_KEY)"
  [ -n "$key" ] || { printf 'ceo -'; return; }
  cfg="$(mktemp)"; chmod 600 "$cfg"
  printf 'header = "Authorization: Bearer %s"\n' "$key" > "$cfg"
  resp=$(curl -s --max-time "$BUDGET" --connect-timeout 2 -X POST \
          "$(_base)/api/ask/world:route" -H 'Content-Type: application/json' --config "$cfg" \
          -d "{\"data\":{\"workspace\":\"$WORKSPACE\",\"tags\":[\"decide:close:$1\"],\"decide\":true}}" 2>/dev/null)
  rm -f "$cfg"
  reason=$(printf '%s' "$resp" | sed -n 's/.*"reason":"\([a-z]*\)".*/\1/p')
  recv=$(printf '%s' "$resp"  | sed -n 's/.*"receiver":"\([^"]*\)".*/\1/p')
  # No answer, a malformed answer, or an error body all land on `ceo`. Every
  # failure direction in this file points at the human.
  case "$reason" in highway|classified|ceo) ;; *) reason=ceo; recv="" ;; esac
  printf '%s %s' "$reason" "${recv:--}"
}

# ═══ THE SETTLE — Rule 1, closed ════════════════════════════════════════════
# A decision taken is not a decision proven. The evidence this layer reads is
# written HERE, on the next close, from what actually happened to the leg:
#   pass -> mark  (the option came good; strength 1, five of them make a highway)
#   open -> warn  (it did not; one warn takes the authority straight back)
# Never from "the command exited 0" — that measures the command, not the choice.
_settle() { # <id> <option> <outcome>
  local verb key edge cfg
  case "$3" in pass) verb=mark ;; *) verb=warn ;; esac
  key="$(_env_key GATEWAY_API_KEY)"; [ -n "$key" ] || return 1
  edge=$(printf 'tag:one:decide:close:%s→%s' "$1" "$2" \
         | sed 's/:/%3A/g; s/→/%E2%86%92/g')
  cfg="$(mktemp)"; chmod 600 "$cfg"
  printf 'header = "Authorization: Bearer %s"\n' "$key" > "$cfg"
  # strength 1, ALWAYS — the sample floor depends on it (see the header).
  curl -s -o /dev/null --max-time "$BUDGET" --connect-timeout 2 -X POST \
    "$(_base)/api/$verb/$edge" -H 'Content-Type: application/json' \
    --config "$cfg" -d '{"strength":1}' 2>/dev/null
  local rc=$?; rm -f "$cfg"; return $rc
}

# ═══ --table ════════════════════════════════════════════════════════════════
if [ "$TABLE" -eq 1 ]; then
  printf '%-14s %-26s %-18s %s\n' ID FIRES-ON OPTIONS VETO
  for row in "gate-mint|gate unrun, no receipt|mint · file" \
             "derives-retry|derives unrun (clock)|retry · file" \
             "promise-retry|promise unrun (3/clock)|retry · file" \
             "writeback|dims/feedback/task door|file" \
             "task-gate|task unrun, gate not pass|file"; do
    id="${row%%|*}"; rest="${row#*|}"; fires="${rest%%|*}"; opts="${rest#*|}"
    printf '%-14s %-26s %-18s %s\n' "$id" "$fires" "$opts" "$(_veto_for "$id" | cut -c1-60)"
  done
  exit 0
fi

# ═══ --settle ═══════════════════════════════════════════════════════════════
if [ "$SETTLE" -eq 1 ]; then
  [ -n "$LEG" ] && [ -n "$OUTCOME" ] || { echo "do-decide: --settle needs --leg and --outcome" >&2; exit 2; }
  spec="$(_decision_for "$LEG" unrun "${DETAIL:-}")"
  [ -n "$spec" ] || exit 5
  id="${spec%% *}"; opt="${DSTATUS:-$(printf '%s' "$spec" | awk '{print $2}')}"
  if _settle "$id" "$opt" "$OUTCOME"; then
    echo "decide: settled $id→$opt as $OUTCOME ($([ "$OUTCOME" = pass ] && echo mark || echo warn))"
  else
    echo "decide: settle unreachable for $id→$opt — the path keeps its old weight"
  fi
  exit 0
fi

# ═══ --self-test ════════════════════════════════════════════════════════════
if [ "$SELFTEST" -eq 1 ]; then
  fails=0
  echo "── do-decide --self-test ──"

  # 1. A fork with no table row is not a decision.
  out=$(bash "$0" --leg dims --status fail --detail "refused" 2>&1); rc=$?
  [ "$rc" -eq 5 ] && echo "ok: a leg with no table row exits 5 — the caller files as before" \
    || { echo "FAIL: expected exit 5 for an untabled fork (rc=$rc)"; fails=$((fails+1)); }

  # 2. A vetoed fork exits 4 and NAMES why — before any oracle call.
  out=$(bash "$0" --leg task --status unrun --detail "gate=unrun" 2>&1); rc=$?
  if [ "$rc" -eq 4 ] && printf '%s' "$out" | grep -q '0.92'; then
    echo "ok: the task←gate fork is vetoed (exit 4) and the row names the scar"
  else echo "FAIL: task-gate veto did not fire (rc=$rc): $out"; fails=$((fails+1)); fi

  # 3. The write-door veto fires with its self-poisoning reason.
  out=$(bash "$0" --leg feedback --status unrun --detail "signal door did not answer" 2>&1); rc=$?
  if [ "$rc" -eq 4 ] && printf '%s' "$out" | grep -qi 'double mark'; then
    echo "ok: an ambiguous write door is vetoed, naming the self-poisoning reason"
  else echo "FAIL: writeback veto did not fire (rc=$rc): $out"; fails=$((fails+1)); fi

  # 4. RED PROOF for 2+3 — gut _veto_for and both must go green (i.e. stop vetoing).
  gut="$(mktemp)"; sed 's/^_veto_for() { # <id> -> reason, or empty/_veto_for() { printf ""; return; } _veto_dead() {/' "$0" > "$gut"
  rc=0; bash "$gut" --leg task --status unrun --detail "gate=unrun" >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 4 ] && echo "ok: RED PROOF — a gutted _veto_for stops vetoing (checks 2-3 measure something)" \
    || { echo "FAIL: RED PROOF — veto still fired with _veto_for gutted"; fails=$((fails+1)); }

  # 5. No oracle answer ⇒ ceo ⇒ RECOMMEND, never take. Point it at a dead door.
  out=$(ONE_API_URL="http://127.0.0.1:1" DECIDE_BUDGET=2 bash "$0" --leg gate --status unrun \
        --detail "no full-suite receipt — 0/2 lane(s)" --apply 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'RECOMMEND' && ! printf '%s' "$out" | grep -q 'TAKEN'; then
    echo "ok: an unreachable oracle reads ceo and RECOMMENDS — it never acts blind"
  else echo "FAIL: dead oracle did not fall to recommend (rc=$rc): $out"; fails=$((fails+1)); fi

  # 6. The blanket action veto outranks any verdict — a forbidden command cannot
  #    be taken even with `highway` forced. This is the check that proves
  #    confidence does not buy blast radius. The gut is an inserted early-return
  #    (a header rewrite mangles multi-line bodies — measured).
  _gut() { # <file> <fn> <body> -> a temp copy with that function short-circuited
    local f; f="$(mktemp)"
    awk -v fn="$2" -v body="$3" '$0 ~ "^"fn"\\(\\) \\{" {print; print "  "body; next} {print}' "$1" > "$f"
    printf '%s' "$f"
  }
  gut2="$(_gut "$0" _verdict 'printf "highway mint"; return 0;')"
  gut2b="$(_gut "$gut2" _command_for 'printf "bash .claude/scripts/release.sh ship"; return 0;')"
  out=$(bash "$gut2b" --leg gate --status unrun --detail "no full-suite receipt" --apply 2>&1); rc=$?
  if printf '%s' "$out" | grep -q 'ships or deploys' && ! printf '%s' "$out" | grep -q 'TAKEN'; then
    echo "ok: a forbidden action is refused even on a forced highway verdict"
  else echo "FAIL: forbidden action was not refused under highway (rc=$rc): $out"; fails=$((fails+1)); fi

  # 7. RED PROOF for 6 — gut _action_forbidden and the same forced highway takes it.
  gut3="$(_gut "$gut2b" _action_forbidden 'printf ""; return 0;')"
  out=$(DECIDE_DRYCMD=1 bash "$gut3" --leg gate --status unrun --detail "no full-suite receipt" --apply 2>&1)
  if printf '%s' "$out" | grep -q 'TAKEN'; then
    echo "ok: RED PROOF — a gutted _action_forbidden lets it through (check 6 measures something)"
  else echo "FAIL: RED PROOF — action still refused with the guard gutted: $out"; fails=$((fails+1)); fi

  # 8. strength 1, always — the n>=5 sample floor depends on this one literal.
  if grep -q "d '{\"strength\":1}'" "$0"; then
    echo "ok: the settle writes strength 1 — HARDEN_STRENGTH stays an n>=5 sample floor"
  else echo "FAIL: the settle no longer writes strength 1 — one event could become a highway"; fails=$((fails+1)); fi

  # 9. Without --apply this script cannot act at all, whatever the verdict says.
  gut4="$(_gut "$0" _verdict 'printf "highway mint"; return 0;')"
  out=$(bash "$gut4" --leg gate --status unrun --detail "no full-suite receipt" 2>&1)
  printf '%s' "$out" | grep -q 'TAKEN' \
    && { echo "FAIL: acted without --apply"; fails=$((fails+1)); } \
    || echo "ok: without --apply a highway verdict still only reports — dry-run is structural"

  rm -f "$gut" "$gut2" "$gut2b" "$gut3" "$gut4"
  echo "── $([ "$fails" -eq 0 ] && echo 'all checks pass' || echo "$fails FAILED") ──"
  [ "$fails" -eq 0 ]; exit $?
fi

# ═══ one fork ═══════════════════════════════════════════════════════════════
[ -n "$LEG" ] || { echo "do-decide: --leg required" >&2; exit 2; }
SPEC="$(_decision_for "$LEG" "$DSTATUS" "$DETAIL")"
[ -n "$SPEC" ] || exit 5
ID="${SPEC%% *}"; OPTS="${SPEC#* }"
PREFER="$(printf '%s' "$OPTS" | awk '{print $1}')"

# The veto, before the oracle. A vetoed fork is reported with its options and its
# reason — the person still gets the ranking, they just also get told this one is
# theirs by rule, not by a number that happened to be low today.
VETO="$(_veto_for "$ID")"
if [ -n "$VETO" ]; then
  if [ "$JSON" -eq 1 ]; then
    printf '{"id":"%s","leg":"%s","verdict":"veto","reason":"%s","options":"%s","action":"none"}\n' \
      "$ID" "$LEG" "$(_jsonesc "$VETO")" "$(_jsonesc "$OPTS")"
  else
    printf '  decide %-14s VETO      %s\n' "$ID" "$VETO"
    printf '  %-21s stays human by rule — no confidence buys it\n' ""
  fi
  exit 4
fi

REASON=""; RECV=""
read -r REASON RECV <<EOF
$(_verdict "$ID")
EOF
[ "$RECV" = "-" ] && RECV=""

# `highway` is the ONLY verdict that licenses acting, and the substrate must have
# picked an option this table actually knows. A highway pointing at an unknown
# target is stale evidence, not a mandate.
CHOICE="$PREFER"; TAKE=0
if [ "$REASON" = "highway" ] && [ -n "$RECV" ]; then
  case " $OPTS " in *" $RECV "*) CHOICE="$RECV"; TAKE=1 ;; esac
fi

CMD="$(_command_for "$ID" "$CHOICE")"
FORBIDDEN="$(_action_forbidden "$CMD")"
PRECOND="$(_precondition_for "$ID" "$CHOICE")"
NOTE=""; RESULT=recommend

if [ "$TAKE" -eq 1 ] && [ -n "$FORBIDDEN" ]; then
  TAKE=0; NOTE="refused: the action $FORBIDDEN — blast radius is not a confidence number"
elif [ "$TAKE" -eq 1 ] && [ -n "$PRECOND" ]; then
  TAKE=0; NOTE="held: $PRECOND"
elif [ "$TAKE" -eq 1 ] && [ -z "$CMD" ]; then
  # The null action (`file`) won the highway. Taking it means doing what /close
  # already does — report it as chosen, run nothing.
  NOTE="the null action — /close files the row, which is the proven choice here"
  RESULT=taken
elif [ "$TAKE" -eq 1 ] && [ "$APPLY" -eq 0 ]; then
  TAKE=0; NOTE="would take it — re-run with --apply (or without --dry-run)"
fi

if [ "$TAKE" -eq 1 ] && [ -n "$CMD" ] && [ "$APPLY" -eq 1 ]; then
  if [ -n "${DECIDE_DRYCMD:-}" ]; then RESULT=taken; NOTE="(DECIDE_DRYCMD — command not run)"
  else
    rc=0; ( eval "$CMD" ) >/dev/null 2>&1 || rc=$?
    RESULT=taken
    NOTE="ran: exit $rc"
  fi
fi

# The undo line is not a nicety. Auto-taking moves the human's veto from BEFORE
# the action to AFTER it, and that trade is only honest while the reversal is
# actually in their hand — so it ships with every taken decision, always.
UNDO="bash .claude/scripts/do-decide.sh --settle --leg $LEG --status $CHOICE --outcome open${SLUG:+ --slug $SLUG}   # warn the path; the next close asks again"

if [ "$JSON" -eq 1 ]; then
  printf '{"id":"%s","leg":"%s","verdict":"%s","confidence":"%s","choice":"%s","options":"%s","result":"%s","note":"%s","command":"%s","undo":"%s"}\n' \
    "$ID" "$LEG" "$RESULT" "$REASON" "$CHOICE" "$(_jsonesc "$OPTS")" "$RESULT" \
    "$(_jsonesc "$NOTE")" "$(_jsonesc "$CMD")" "$(_jsonesc "$UNDO")"
  exit 0
fi

if [ "$RESULT" = "taken" ]; then
  printf '  decide %-14s TAKEN     %s  (confidence: %s — the substrate has watched this choice come good)\n' "$ID" "$CHOICE" "$REASON"
  [ -n "$NOTE" ] && printf '  %-21s %s\n' "" "$NOTE"
  printf '  %-21s undo: %s\n' "" "$UNDO"
else
  printf '  decide %-14s RECOMMEND %s  (confidence: %s — not yet proven; a person decides)\n' "$ID" "$CHOICE" "$REASON"
  for o in $OPTS; do
    _m=" "; [ "$o" = "$CHOICE" ] && _m="→"
    printf '  %-21s %s %-6s %s\n' "" "$_m" "$o" "$(_cost_for "$ID" "$o")"
  done
  [ -n "$NOTE" ] && printf '  %-21s %s\n' "" "$NOTE"
fi
exit 0
