#!/usr/bin/env bash
# do-w4-gates.sh — run W4's DETERMINISTIC gate battery, emit one JSON evidence pack.
#
# manifest: needs-env
#
# needs-env: it runs do-reconcile.sh, do-folder.sh and the folder verify lane,
# all of which are needs-env.
#
# WHY. Every gate in `.claude/commands/do.md` § W4 is already bash. The `w4-verify`
# agent was being spawned (28.9KB of prose + 5.4KB of w4-tools.md) mostly to READ
# those gate lines out of the markdown and then type them into Bash. That is a
# model call to operate a shell. This script IS the gate list, executed, with a
# machine-readable receipt — so the only thing left that needs judgment is the
# rubric VERDICT (goal-fit especially, which no script can score).
#
# GATE PARITY IS THE WHOLE POINT. This script must run exactly the gates do.md
# lists, no more and no fewer. It adds nothing and removes nothing; it only
# stops a model from re-typing them.
#
# THE HONESTY LAW (this repo has shipped green gates over red trees three times
# on record): a gate has FOUR states, never two —
#     pass  : ran, exit 0
#     fail  : ran, non-zero
#     unrun : could not run (tool absent, verify skipped)
#     n/a   : does not apply to this diff (by rule, not by accident)
# `deterministic_pass` is true only when there are ZERO fails and ZERO unruns.
# An unrun gate is NOT a passed gate. An absent tool is an unrun check, never a
# green one.
#
# TWO GATES THIS SCRIPT CANNOT INVENT. do.md's W4 block also runs the cycle's
# `$(cycle.demo.command)` — the goal gate — and `do-prove.sh <slug>` when the
# promise exists. Neither is derivable from a diff: one lives in the cycle, the
# other needs the plan slug. So the CALLER supplies them (`--demo`, `--slug`)
# and, when it does not, they are reported `unrun` — which under the law above
# makes `deterministic_pass` false. Running this script bare therefore CANNOT
# produce a green over an unrun goal gate. That is deliberate, not an oversight.
#
# Usage:
#   do-w4-gates.sh [--files <changed-path>...]     # default: git diff HEAD --name-only
#                  [--demo '<command>']            # the cycle's goal gate
#                  [--slug <slug>]                 # enables do-prove.sh <slug>
#   do-w4-gates.sh --self-test                     # fixtures + RED PROOF
# Env:
#   W4_SKIP_VERIFY=1     skip the folder verify lane -> reported `unrun` (never pass)
#   W4_SKIP_RECONCILE=1  SELF-TEST ONLY — skip the 7 canons + consumer sweep, all
#                        reported `unrun`. Exists because `do-reconcile.sh types`
#                        is a tsc that can queue for minutes behind the governor
#                        and the self-test calls this script six times. Safe only
#                        because a skip is unrun, not pass; never set it for real.
set -euo pipefail


ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/.claude/scripts"
RESULTS_FILE=""
DEMO_CMD=""
SLUG=""

_add() { # name status detail
  jq -n --arg n "$1" --arg s "$2" --arg d "$3" '{gate:$n,status:$s,detail:$d}' >> "$RESULTS_FILE"
}

# Run a command; classify by exit code. Never let a missing tool invert the exit.
_run() { # name cmd...
  local name="$1"; shift
  local out rc
  set +e
  out="$( "$@" </dev/null 2>&1 )"; rc=$?
  set -e
  if [ $rc -eq 0 ]; then _add "$name" pass "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')"
  else _add "$name" fail "exit=$rc $(printf '%s' "$out" | tail -5 | tr '\n' ' ')"; fi
}

_gates() {
  # macOS ships bash 3.2: no `mapfile`, and "${arr[@]}" on an EMPTY array is an
  # unbound-variable error under `set -u`. So the changed set is carried as a
  # newline-delimited STRING and re-split only where a command needs argv.
  local files_txt nfiles
  if [ "$#" -gt 0 ]; then files_txt="$(printf '%s\n' "$@")"
  else files_txt="$(git -C "$ROOT" diff HEAD --name-only 2>/dev/null || true)"; fi
  nfiles="$(printf '%s\n' "$files_txt" | grep -c . || true)"
  RESULTS_FILE="$(mktemp)"

  # ---- 1. folder verify lane (bun run verify / verify:fast; doc-only -> n/a) ----
  local folders
  folders="$(printf '%s\n' "$files_txt" | bash "$S/do-folder.sh" 2>/dev/null || echo '')"
  if [ -z "$folders" ]; then
    _add verify unrun "do-folder.sh resolved no folder for the changed set"
  elif printf '%s\n' "$folders" | jq -se 'all(.doc_only)' >/dev/null 2>&1; then
    _add verify n/a "doc-only diff — do.md W0/W4 skip bun verify by rule"
  elif [ "${W4_SKIP_VERIFY:-0}" = "1" ]; then
    _add verify unrun "W4_SKIP_VERIFY=1 — an unrun gate is not a pass"
  else
    local f v
    while IFS=$'\t' read -r f v; do
      [ -n "$f" ] || continue
      _run "verify:$f" bash -c "cd '$ROOT/$f' && $v"
    done < <(printf '%s\n' "$folders" | jq -r 'select(.verify) | "\(.folder)\t\(.verify)"')
    # A folder with NO verify script must say so. `select(.verify)` silently
    # drops it, so before 2026-09-03 a changed set that resolved only to
    # verify-less folders ran the loop zero times and added NO ROW AT ALL --
    # not pass, not unrun, not n/a. That is outside this script's own four-state
    # vocabulary, and an absent row is the fail-open trap in data form: every
    # reader that asks "did verify pass" gets nothing back and treats it as
    # nothing to worry about. Measured on channels/ and pay/, two of the five
    # deployed services, in BOTH lanes.
    local _unverified
    _unverified="$(printf '%s\n' "$folders" | jq -r 'select(.verify | not) | .folder // .reason // "unmapped"' | paste -sd, - 2>/dev/null || true)"
    if [ -n "$_unverified" ]; then
      _add verify unrun "no verify script for: $_unverified — an unrun gate is not a pass"
    fi
  fi

  # ---- 2. objective security gate (zero-LLM backstop) ----
  if command -v gitleaks >/dev/null 2>&1; then
    _run secrets gitleaks detect --no-git --source "$ROOT" --redact -q
  else
    _add secrets unrun "gitleaks not installed — absent tool is an unrun check, never green"
  fi
  if printf '%s\n' "$files_txt" | grep -qE '(bun\.lock|package\.json)$'; then
    _run dep-audit bash -c "cd '$ROOT' && bun audit --audit-level moderate"
  else
    _add dep-audit n/a "no dependency file in the diff"
  fi

  # security greps over the diff (w4-tools.md § Security grep) — hits are a FAIL
  local sec
  sec="$(git -C "$ROOT" diff HEAD 2>/dev/null | grep -E '^\+' \
        | grep -vE '^\+\+\+' \
        | grep -E "eval\(|dangerouslySetInnerHTML|Access-Control-Allow-Origin.*\*" \
        | grep -vE '// allow|sanitize|DOMPurify' | head -5 || true)"
  if [ -n "$sec" ]; then _add security-grep fail "$(printf '%s' "$sec" | tr '\n' ' ')"
  else _add security-grep pass "0 hits over the diff"; fi

  # ---- 3. surface checklist (missing file = W4 FAIL, by do.md rule) ----
  if [ ! -f "$ROOT/.w2-surface-checklist.json" ]; then
    _add surface-checklist fail ".w2-surface-checklist.json missing — W2 must declare surfaces or surface:none+reason"
  elif [ "$(jq -r '.surface // empty' "$ROOT/.w2-surface-checklist.json")" = "none" ]; then
    if [ -n "$(jq -r '.reason // empty' "$ROOT/.w2-surface-checklist.json")" ]; then
      _add surface-checklist pass "surface:none with a reason"
    else
      _add surface-checklist fail "surface:none without a reason"
    fi
  else
    _add surface-checklist pass "surfaces declared"
  fi

  # ---- 3b. per-surface WIRING greps (do.md W4: inbound_links / sdk_export /
  #      mcp_tool / cli_verb). These are NOT the same check as
  #      `do-reconcile.sh navigation|sdk`; each declared surface must be found
  #      wired at its named site. Needs a folder to resolve src/ paths against.
  #
  #      A FIFTH branch — the nav-entry one — was DELETED here (plan rung A6).
  #      It greped `path:.*<route>` in src/lib/navigation.ts, and, MEASURED
  #      2026-09-01, that file holds exactly two `path:` lines, both TypeScript
  #      parameter declarations and no route table: the branch could only ever
  #      go red, so it graded no cycle. The checklist FIELD survives — W2 still
  #      writes it and a human still reads it; nothing greps it any more.
  #      The four below are MERGED (copied, not moved) into factory-walk.sh's
  #      gate stage, which is where they survive D4's deletion of this file.
  local cl="$ROOT/.w2-surface-checklist.json" wroot wfails=0 wchecked=0 entry page txt ex tool verb
  if [ -f "$cl" ] && [ "$(jq -r '.surface // empty' "$cl")" != "none" ]; then
    wroot="$(printf '%s\n' "$folders" | jq -r 'select(.verify) | .folder' | head -1)"
    if [ -z "$wroot" ]; then
      _add surface-wiring unrun "no code folder resolved — cannot locate src/ to grep the declared surfaces"
    else
      while IFS= read -r entry; do
        [ -n "$entry" ] || continue; wchecked=$((wchecked+1))
        page="${entry%%:*}"; txt="${entry#*:}"
        grep -q "$txt" "$ROOT/$wroot/src/pages/$page.astro" 2>/dev/null || wfails=$((wfails+1))
      done < <(jq -r '.surfaces[]? | select(.inbound_links) | .inbound_links[]' "$cl" 2>/dev/null)
      while IFS= read -r ex; do
        [ -n "$ex" ] || continue; wchecked=$((wchecked+1))
        grep -q "export.*from.*$ex" "$ROOT/packages/sdk/src/index.ts" 2>/dev/null || wfails=$((wfails+1))
      done < <(jq -r '.surfaces[]? | select(.sdk_export) | .sdk_export' "$cl" 2>/dev/null)
      while IFS= read -r tool; do
        [ -n "$tool" ] || continue; wchecked=$((wchecked+1))
        grep -rq "$tool" "$ROOT/packages/mcp/src/index.ts" 2>/dev/null || wfails=$((wfails+1))
      done < <(jq -r '.surfaces[]? | select(.mcp_tool) | .mcp_tool' "$cl" 2>/dev/null)
      while IFS= read -r verb; do
        [ -n "$verb" ] || continue; wchecked=$((wchecked+1))
        grep -rq "$verb" "$ROOT/packages/cli/src/index.ts" 2>/dev/null || wfails=$((wfails+1))
      done < <(jq -r '.surfaces[]? | select(.cli_verb) | .cli_verb' "$cl" 2>/dev/null)
      if [ "$wfails" -gt 0 ]; then
        _add surface-wiring fail "$wfails of $wchecked declared surfaces are NOT wired at their named site"
      else
        _add surface-wiring pass "$wchecked declared surfaces wired"
      fi
    fi
  else
    _add surface-wiring n/a "no surfaces declared (surface:none, or no checklist — see surface-checklist)"
  fi

  # ---- 3c. the GOAL GATE and the PROMISE ORACLE.
  #      do.md's W4 block runs `$(cycle.demo.command)` and, when text/<slug>.md
  #      exists, `do-prove.sh <slug>`. This script cannot invent either: the demo
  #      command lives in the cycle, and the slug in the plan. They are therefore
  #      reported UNRUN unless supplied — which, by the four-state law, keeps
  #      deterministic_pass RED. A caller who runs the script bare CANNOT get a
  #      green without having run the goal gate. That is the point.
  if [ -n "$DEMO_CMD" ]; then
    _run demo-gate bash -c "cd '$ROOT' && $DEMO_CMD"
  else
    _add demo-gate unrun "no --demo <cmd> supplied — the cycle's goal gate has NOT run"
  fi
  if [ -n "$SLUG" ]; then
    if [ -f "$ROOT/text/$SLUG.md" ]; then
      _run promise-prove bash "$S/do-prove.sh" "$SLUG"
    else
      _add promise-prove n/a "no text/$SLUG.md — no promise to prove"
    fi
  else
    _add promise-prove unrun "no --slug supplied — do-prove.sh has NOT run"
  fi

  # ---- 4. the RECONCILES gate: the 7 canons ----
  # $files_txt is deliberately UNQUOTED here so newline-separated paths become
  # argv. Repo paths carry no spaces; a path that did would need bash 4 arrays.
  local canon
  if [ "${W4_SKIP_RECONCILE:-0}" = "1" ]; then
    # ESCAPE HATCH FOR THE SELF-TEST ONLY. `do-reconcile.sh types` is a tsc that
    # can queue for minutes behind the governor, and the self-test calls this
    # script six times to prove the cheap gates flip. Skipping is safe ONLY
    # because a skip is `unrun`, not `pass` — the verdict still goes red, and
    # test 6 below asserts exactly that. Never set this in a real cycle.
    for canon in types dictionary substrate sdk authority design navigation; do
      _add "reconcile:$canon" unrun "W4_SKIP_RECONCILE=1 — an unrun canon is not a passed canon"
    done
    _add consumer-sweep unrun "W4_SKIP_RECONCILE=1 — an unrun sweep is not a passed sweep"
  else
    _run reconcile:types      bash "$S/do-reconcile.sh" types
    _run reconcile:dictionary bash "$S/do-reconcile.sh" dictionary $files_txt
    # do.md scopes these: `do-reconcile.sh navigation <surface>` / `design <file>`
    # are SURFACE-task canons. A markdown doc is not a UI surface, so feeding
    # text/*.md to `navigation` produces a guaranteed false RED ("text/do.md not
    # registered in menu.ts" — measured 2026-09-01 on this very change). Excluded
    # here to restore do.md's own scoping; everything that IS a surface still runs.
    local surface_txt
    surface_txt="$(printf '%s\n' "$files_txt" | grep -vE '\.md$' || true)"
    for canon in substrate sdk authority; do
      _run "reconcile:$canon" bash "$S/do-reconcile.sh" "$canon" $files_txt
    done
    for canon in design navigation; do
      if [ -n "$surface_txt" ]; then
        _run "reconcile:$canon" bash "$S/do-reconcile.sh" "$canon" $surface_txt
      else
        _add "reconcile:$canon" n/a "no non-markdown surface in the diff"
      fi
    done

    # ---- 5. consumer sweep ----
    if [ "$nfiles" -gt 0 ]; then
      _run consumer-sweep bash "$S/do-consumer-sweep.sh" --exec $files_txt
    else
      _add consumer-sweep n/a "empty diff"
    fi
  fi

  # ---- 6. (deleted 2026-09-21 — rung A5, text/do-factory-plan.md § 7 Phase A) ----
  # A seventh gate compared a tsc count against a W0 baseline file and COULD NOT
  # SAY NO: the file it read was gitignored state holding 999999, and its own
  # compute ran `bunx tsc --noEmit` from a directory with no tsconfig.json —
  # 0.184s, exit 1, tsc's usage text, zero `error TS` lines matched. With the
  # file absent it reported `unrun`, and `deterministic_pass` requires ZERO
  # unruns, so every pack this script emitted was false. The plan rung carries
  # the full account verbatim. The typecheck that does run is `reconcile:types`
  # above — a real folder with a real tsconfig, governed and memoised.

  # ---- verdict ----
  local gates fails unruns
  gates="$(jq -s '.' "$RESULTS_FILE")"
  fails="$(printf '%s' "$gates" | jq '[.[] | select(.status=="fail")] | length')"
  unruns="$(printf '%s' "$gates" | jq '[.[] | select(.status=="unrun")] | length')"
  rm -f "$RESULTS_FILE"

  jq -n --argjson gates "$gates" --argjson fails "$fails" --argjson unruns "$unruns" \
    --argjson files "$(printf '%s\n' "$files_txt" | jq -R -s 'split("\n") | map(select(length>0))')" \
    '{files:$files, gates:$gates, fails:$fails, unrun:$unruns,
      deterministic_pass: ($fails == 0 and $unruns == 0),
      note: "deterministic_pass requires ZERO fails AND ZERO unruns. An unrun gate is not a passed gate. The rubric verdict (goal-fit, taste) is scored on top of this pack; it may only LOWER the outcome, never raise a fail to a pass."}'
}

_self_test() {
  local fails=0 out t
  t="$(mktemp -d)"; trap 'rm -rf "$t"' RETURN

  # 1. shape: a run emits valid JSON with a gate list and a verdict.
  #    Use a CODE file, not a doc: a doc-only diff makes the verify lane `n/a`
  #    by rule, which would hide the unrun branch test 2 exists to prove.
  out="$(W4_SKIP_VERIFY=1 W4_SKIP_RECONCILE=1 bash "$S/do-w4-gates.sh" --files one.ie/web/src/lib/authority.ts 2>/dev/null)" || true
  if printf '%s' "$out" | jq -e '(.gates|length) > 5 and has("deterministic_pass")' >/dev/null 2>&1; then
    echo "ok: evidence pack is valid JSON with a gate list and a verdict"
  else
    echo "FAIL: evidence pack malformed"; fails=$((fails+1))
  fi

  # 2. RED PROOF (a) — an UNRUN gate must not read as a pass.
  #    W4_SKIP_VERIFY=1 forces the verify lane unrun; deterministic_pass MUST be false.
  if printf '%s' "$out" | jq -e '[.gates[]|select(.gate=="verify" and .status=="unrun")]|length==1' >/dev/null 2>&1; then
    if printf '%s' "$out" | jq -e '.deterministic_pass == false' >/dev/null 2>&1; then
      echo "ok: RED PROOF — a skipped verify is reported unrun and the verdict goes RED"
    else
      echo "FAIL: RED PROOF — unrun verify still produced deterministic_pass:true"; fails=$((fails+1))
    fi
  else
    echo "FAIL: RED PROOF — W4_SKIP_VERIFY did not surface as an unrun verify gate"; fails=$((fails+1))
  fi

  # 3/4. RED PROOF (b) — the surface-checklist gate must move BOTH ways.
  #    A gate that is always red proves as little as one that is always green,
  #    so drive it green -> red -> green over a real file and assert each flip.
  local cl="$ROOT/.w2-surface-checklist.json" had_cl=false
  if [ -f "$cl" ]; then had_cl=true; cp "$cl" "$t/cl.bak"; fi
  _cl_status() {
    W4_SKIP_VERIFY=1 W4_SKIP_RECONCILE=1 bash "$S/do-w4-gates.sh" --files text/do.md 2>/dev/null \
      | jq -r '[.gates[]|select(.gate=="surface-checklist")][0].status'
  }

  rm -f "$cl"
  if [ "$(_cl_status)" = "fail" ]; then
    echo "ok: RED PROOF — an ABSENT .w2-surface-checklist.json fails the cycle"
  else
    echo "FAIL: RED PROOF — absent surface checklist did not fail"; fails=$((fails+1))
  fi

  printf '{"surface":"none"}\n' > "$cl"
  if [ "$(_cl_status)" = "fail" ]; then
    echo "ok: RED PROOF — surface:none WITHOUT a reason fails"
  else
    echo "FAIL: RED PROOF — surface:none without a reason passed"; fails=$((fails+1))
  fi

  # surface-WIRING, both directions. This is the gate that was MISSING from the
  # first cut, so it gets the same treatment as the rest: prove it red, prove it
  # green. `sdk_export` is used because its target (packages/sdk/src/index.ts) is
  # a fixed path, unlike nav/inbound which resolve against the cycle's folder.
  # A CODE file is passed so do-folder resolves $wroot (a doc-only diff cannot).
  _wire_status() {
    W4_SKIP_VERIFY=1 W4_SKIP_RECONCILE=1 bash "$S/do-w4-gates.sh" \
      --files one.ie/web/src/lib/authority.ts 2>/dev/null \
      | jq -r '[.gates[]|select(.gate=="surface-wiring")][0].status'
  }
  printf '{"surfaces":[{"sdk_export":"zzz-not-a-real-export"}]}\n' > "$cl"
  if [ "$(_wire_status)" = "fail" ]; then
    echo "ok: RED PROOF — a declared surface that is NOT wired fails surface-wiring"
  else
    echo "FAIL: RED PROOF — an unwired declared surface did not fail"; fails=$((fails+1))
  fi
  printf '{"surfaces":[{"sdk_export":"types"}]}\n' > "$cl"
  if [ "$(_wire_status)" = "pass" ]; then
    echo "ok: GREEN PROOF — a genuinely wired surface passes (surface-wiring is not stuck red)"
  else
    echo "FAIL: GREEN PROOF — a wired surface did not pass surface-wiring"; fails=$((fails+1))
  fi

  printf '{"surface":"none","reason":"self-test fixture"}\n' > "$cl"
  if [ "$(_cl_status)" = "pass" ]; then
    echo "ok: GREEN PROOF — surface:none WITH a reason passes (the gate is not stuck red)"
  else
    echo "FAIL: GREEN PROOF — a well-formed checklist did not pass"; fails=$((fails+1))
  fi

  rm -f "$cl"
  if [ "$had_cl" = true ]; then cp "$t/cl.bak" "$cl"; fi

  # 5. RED PROOF — the GOAL GATE. Bare, it must be `unrun`; supplied and passing,
  #    it must flip to `pass`. A caller can never get a green without running it.
  local dg
  dg="$(W4_SKIP_VERIFY=1 W4_SKIP_RECONCILE=1 bash "$S/do-w4-gates.sh" --files text/do.md 2>/dev/null \
        | jq -r '[.gates[]|select(.gate=="demo-gate")][0].status')"
  if [ "$dg" = "unrun" ]; then
    echo "ok: RED PROOF — no --demo means the goal gate is UNRUN (verdict cannot be green)"
  else
    echo "FAIL: RED PROOF — bare run reported demo-gate as '$dg', not unrun"; fails=$((fails+1))
  fi
  dg="$(W4_SKIP_VERIFY=1 W4_SKIP_RECONCILE=1 bash "$S/do-w4-gates.sh" --demo true --files text/do.md 2>/dev/null \
        | jq -r '[.gates[]|select(.gate=="demo-gate")][0].status')"
  if [ "$dg" = "pass" ]; then
    echo "ok: GREEN PROOF — a supplied, passing --demo flips the goal gate to pass"
  else
    echo "FAIL: GREEN PROOF — --demo true reported '$dg'"; fails=$((fails+1))
  fi
  dg="$(W4_SKIP_VERIFY=1 W4_SKIP_RECONCILE=1 bash "$S/do-w4-gates.sh" --demo false --files text/do.md 2>/dev/null \
        | jq -r '[.gates[]|select(.gate=="demo-gate")][0].status')"
  if [ "$dg" = "fail" ]; then
    echo "ok: RED PROOF — a FAILING --demo fails the goal gate"
  else
    echo "FAIL: RED PROOF — --demo false reported '$dg'"; fails=$((fails+1))
  fi

  # 6. The PROMISE ORACLE's branch selection — proven without running do-prove.sh
  #    (a real prove is a browser run; what needs proving here is the routing).
  local pp
  pp="$(W4_SKIP_VERIFY=1 W4_SKIP_RECONCILE=1 bash "$S/do-w4-gates.sh" --files text/do.md 2>/dev/null \
        | jq -r '[.gates[]|select(.gate=="promise-prove")][0].status')"
  [ "$pp" = "unrun" ] \
    && echo "ok: RED PROOF — no --slug means the promise oracle is UNRUN" \
    || { echo "FAIL: no --slug reported promise-prove as '$pp', not unrun"; fails=$((fails+1)); }
  pp="$(W4_SKIP_VERIFY=1 W4_SKIP_RECONCILE=1 bash "$S/do-w4-gates.sh" --slug __nosuchpromise__ --files text/do.md 2>/dev/null \
        | jq -r '[.gates[]|select(.gate=="promise-prove")][0].status')"
  [ "$pp" = "n/a" ] \
    && echo "ok: a slug with no text/<slug>.md is n/a — there is no promise to prove" \
    || { echo "FAIL: absent promise reported '$pp', not n/a"; fails=$((fails+1)); }

  # 7. RED PROOF — the self-test's OWN escape hatch must not read as a pass.
  #    Tests 1-5 run with W4_SKIP_RECONCILE=1. If that skip scored `pass`, every
  #    assertion above would be measured against a gutted battery.
  if printf '%s' "$out" | jq -e '[.gates[]|select(.gate|startswith("reconcile:"))|select(.status!="unrun")]|length==0' >/dev/null 2>&1; then
    echo "ok: RED PROOF — the self-test's own W4_SKIP_RECONCILE reads as unrun, not pass"
  else
    echo "FAIL: RED PROOF — a skipped canon scored something other than unrun"; fails=$((fails+1))
  fi

  if [ "$fails" -eq 0 ]; then echo "do-w4-gates: self-test PASS"; return 0; fi
  echo "do-w4-gates: self-test FAIL ($fails)"; return 1
}

[ "${1:-}" = "--self-test" ] && { _self_test; exit $?; }

PATHS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --demo)  DEMO_CMD="${2:-}"; shift 2 ;;
    --slug)  SLUG="${2:-}";     shift 2 ;;
    --files) shift ;;
    -h|--help)
      echo "usage: do-w4-gates.sh [--files <path>...] [--demo '<cmd>'] [--slug <slug>] | --self-test" >&2
      exit 2 ;;
    *) PATHS="$PATHS $1"; shift ;;
  esac
done

# unquoted on purpose — see the RECONCILES note in _gates
_gates $PATHS
