#!/usr/bin/env bash
# key-cycle.sh — one subtask of `key`, three commands and one builder spawn per pass.
#
# manifest: needs-env   (GATEWAY_API_KEY + OPENROUTER_API_KEY from one.ie/web/.dev.vars or the shell;
#                        ONE_ENV_FILE / DO_ENV_FILE override the file)
#
#   key-cycle.sh prep  <tid>              row → context → Kimi spec → Astra review → <tid>.brief.md
#   key-cycle.sh judge <tid> <base-sha> [head]  git diff <base>..<head|HEAD> in the key worktree → Astra refute → Kimi second → verdict
#   key-cycle.sh close <tid>              runs the row's `ACCEPT ·` line in the worktree; exit 0 → row done + chain comment
#   key-cycle.sh --self-test              a fixture whose accept is `false` must NOT close (exit 1)
#
# The conductor's whole job per pass: `prep`, ONE Agent(implementer, opus) call with the brief pasted in,
# `judge`, then `close` or another builder pass. Every model verdict lands on the ROW via key-seat.sh,
# opening with the model id; nothing is posted without content; no model grades its own work.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# The key worktree is wherever git says branch feat/key is checked out — never a path relative to
# whichever worktree's copy of this script ran (measured: run from the dev worktree it looked for
# dev/.claude/worktrees/key, which does not exist).
WT="${KEY_WORKTREE:-$(git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree /{w=$2} /^branch refs\/heads\/feat\/key$/{print w; exit}')}"
[ -n "$WT" ] && [ -d "$WT" ] || WT="$ROOT/.claude/worktrees/key"
CACHE="${KEY_CYCLE_CACHE:-${TMPDIR:-/tmp}/key-cycle}"; mkdir -p "$CACHE"
ENVF="${ONE_ENV_FILE:-${DO_ENV_FILE:-$ROOT/one.ie/web/.dev.vars}}"
GW="${GATEWAY_API_KEY:-$(grep -E '^GATEWAY_API_KEY=' "$ENVF" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"')}"
# KEY_CLI overrides the board CLI: the key worktree carries no packages/cli/dist build, so its copy
# of this script reads the board through another tree's build (dev's) rather than failing on 127.
CLI="${KEY_CLI:-node $ROOT/packages/cli/dist/src/index.js}"
SEAT="$ROOT/.claude/scripts/key-seat.sh"
die() { echo "key-cycle: $*" >&2; exit 2; }

row() { # row <tid> → $CACHE/<tid>.row.md (name + notes), from the board CLI (whole board, one read, cached 10 min)
  local tid="$1" board="$CACHE/board.json"
  if [ ! -s "$board" ] || [ "$(find "$board" -mmin +10 2>/dev/null)" ]; then
    (unset ONE_API_KEY ONEIE_API_KEY; $CLI tasks board --workspace one --all --limit 2000 --include notes --json > "$board") || die "board read failed"
  fi
  python3 - "$board" "$tid" > "$CACHE/$tid.row.md" <<'PY'
import json,sys; d=json.load(open(sys.argv[1])); tid=sys.argv[2]
r=next((r for r in d.get('tasks',[]) if r.get('tid')==tid),None)
if not r: sys.exit("row not found on the board: "+tid)
print("ROW",tid,"·",r.get('status'),"· blockedBy",r.get('blockedBy') or [])
print("TITLE ·",r.get('name'))
print(); print(r.get('notes') or "(no notes)")
PY
  [ -s "$CACHE/$tid.row.md" ] || die "no row for $tid"
}

# The ACCEPT field may start a line ('ACCEPT · cmd') or sit inside a one-line notes block
# ('… ACCEPT: cmd. LANE: fast.'); it ends at a newline, at ' LANE', or at a parenthesised note.
# The delimiter (· or :) is REQUIRED: the runner row's own notes say "runs the row's ACCEPT line"
# in prose, and without it the parser took that sentence as the command and close refused on
# exit 127 — "command not found" is a parse failure, never an accept verdict (measured 2026-09-21).
accept_line() { python3 - "$CACHE/$1.row.md" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
m=re.search(r'ACCEPT\s*[·:]\s*(.+?)(?=\n|\s+\(| LANE[ ·:]|$)', s, re.S)
print(m.group(1).strip().rstrip('.') if m else '')
PY
}

RULES=$(cat <<'R'
RULES (fixed, every builder, every pass):
- Work ONLY in the worktree named below, on its branch. Never touch the shared main tree or another worktree.
- RED FIRST: the accept test exists and fails before component code; paste both exit codes.
- vitest only as: cd one.ie/web && bash ../../.claude/scripts/gate-run.sh <name> -- bunx vitest run <files>  (a bare vitest is refused).
- Then: bunx tsc --noEmit · bun run verify:fast (say FAST). No full suite, no browser, no new dependencies.
- Commit by explicit path (git add <file> <file>; never -A). Do not push. Do not close the row.
- Never print, log, fetch or clipboard a master, a phrase or a key.
- ONE row comment at the end, opening "[claude-opus · implementer]": files · red exit · green exit · tsc · verify:fast lane+exit · sha · DID NOT RUN.
  K=$(grep -E "^GATEWAY_API_KEY=" one.ie/web/.dev.vars | cut -d= -f2- | tr -d '"'); curl -s -X POST https://one.ie/api/ask/tasks:comment -H "Authorization: Bearer $K" -H "content-type: application/json" -d '{"data":{"tid":"<TID>","workspace":"one","body":"..."}}'
- FINAL REPORT ≤ 15 lines: tid · files · RED cmd+exit · GREEN cmd+exit · tsc · verify:fast · sha · amendments NOT satisfied and why · DID NOT RUN · the one thing that would make you refuse to call this done.
R
)

cmd="${1:-}"; shift || true
case "$cmd" in
  prep)
    tid="${1:?tid}"; row "$tid"
    ctx="$CACHE/$tid.ctx.md"; { cat "$CACHE/$tid.row.md"; echo; echo "=== WORKTREE ==="; echo "$WT · branch $(git -C "$WT" branch --show-current 2>/dev/null) · HEAD $(git -C "$WT" rev-parse --short HEAD 2>/dev/null)"; } > "$ctx"
    if [ -s "$CACHE/$tid.spec.md" ] && [ "${REPREP:-0}" != 1 ]; then echo "prep: reusing cached spec (REPREP=1 to re-buy)"; else
    spec=$("$SEAT" cto "$tid" "$ctx") || die "cto seat failed"; echo "$spec" | tail -n +2 > "$CACHE/$tid.spec.md"; fi
    { cat "$ctx"; echo; echo "=== LAST COMMENT ON THE ROW (the CTO spec) ==="; cat "$CACHE/$tid.spec.md"; } > "$CACHE/$tid.rctx.md"
    if [ -s "$CACHE/$tid.review.md" ] && [ "${REPREP:-0}" != 1 ]; then echo "prep: reusing cached review"; else
    rev=$("$SEAT" review "$tid" "$CACHE/$tid.rctx.md") || die "review seat failed"; echo "$rev" | tail -n +2 > "$CACHE/$tid.review.md"; fi
    brief="$CACHE/$tid.brief.md"
    { echo "You are the BUILDER (the only seat that edits files) for row $tid, workspace one. You inherit no project instructions; everything is here. The spec (CTO, Kimi K3) and its review (security, GPT-6 Astra) both bind you."; echo
      echo "WORKTREE: $WT (branch $(git -C "$WT" branch --show-current))"; echo
      echo "${RULES//<TID>/$tid}"; echo; echo "=== THE ROW ==="; cat "$CACHE/$tid.row.md"; echo; echo "=== CTO SPEC (moonshotai/kimi-k3) ==="; cat "$CACHE/$tid.spec.md"; echo; echo "=== SECURITY REVIEW (openai/gpt-6-astra) — each AMEND line is a requirement ==="; cat "$CACHE/$tid.review.md"; } > "$brief"
    echo "prep $tid: spec $(wc -l < "$CACHE/$tid.spec.md") lines · review: $(head -c 6 "$CACHE/$tid.review.md") · brief → $brief ($(wc -c < "$brief") bytes)"
    echo "next: Agent({subagent_type:'implementer', model:'opus', prompt: <contents of $brief>}) then: key-cycle.sh judge $tid $(git -C "$WT" rev-parse --short HEAD)";;
  judge)
    tid="${1:?tid}"; base="${2:?base-sha}"; head="${3:-HEAD}"; [ -s "$CACHE/$tid.row.md" ] || row "$tid"
    # <head> is optional: with several builders on one branch, judge THIS row's commits only.
    diff="$CACHE/$tid.$base.diff"; git -C "$WT" diff "$base..$head" > "$diff" || die "diff failed"; [ -s "$diff" ] || die "empty diff $base..$head in $WT"
    # The builder's report is EVIDENCE the diff cannot carry (exit codes, byte hashes, test counts). Without it
    # Astra refutes on "no results supplied" — three such objections on one row (2026-09-21). The conductor
    # saves the builder's final report to $CACHE/<tid>.evidence.md before judge; judge appends it when present.
    { cat "$CACHE/$tid.row.md"; echo; [ -s "$CACHE/$tid.spec.md" ] && { echo "=== CTO SPEC ==="; cat "$CACHE/$tid.spec.md"; }; [ -s "$CACHE/$tid.review.md" ] && { echo; echo "=== SECURITY AMENDMENTS ==="; cat "$CACHE/$tid.review.md"; }; [ -s "$CACHE/$tid.evidence.md" ] && { echo; echo "=== BUILDER REPORT (measured exits and hashes — weigh it as evidence, not as a claim to trust) ==="; cat "$CACHE/$tid.evidence.md"; }; echo; echo "Judge the diff ($base..$head)."; } > "$CACHE/$tid.jctx.md"
    ref=$("$SEAT" refute "$tid" "$CACHE/$tid.jctx.md" "$diff") || die "refute seat failed"; echo "$ref" | tail -n +2 > "$CACHE/$tid.refute.md"
    { cat "$CACHE/$tid.jctx.md"; echo; echo "=== LAST COMMENT ON THE ROW (the security refutation) ==="; cat "$CACHE/$tid.refute.md"; } > "$CACHE/$tid.sctx.md"
    sec=$("$SEAT" second "$tid" "$CACHE/$tid.sctx.md") || echo "second seat failed (non-blocking)"; echo "$sec" | tail -n +2 > "$CACHE/$tid.second.md"
    v=$(grep -m1 -oE '^(PASS|REFUTED)' "$CACHE/$tid.refute.md" || echo UNPARSED); k=$(grep -m1 -oE '^(AGREE|DISAGREE)' "$CACHE/$tid.second.md" || echo UNPARSED); echo "judge $tid: astra=$v · kimi=$k"
    [ "$v" = "PASS" ] && echo "next: key-cycle.sh close $tid" || { echo "objections:"; tail -n +2 "$CACHE/$tid.refute.md" | head -12; echo "next: resume the builder with the objections, then judge again from $(git -C "$WT" rev-parse --short HEAD)"; };;
  close)
    tid="${1:?tid}"; [ -s "$CACHE/$tid.row.md" ] || row "$tid"
    acc=$(accept_line "$tid"); [ -n "$acc" ] || die "row has no 'ACCEPT ·' line"
    echo "accept: $acc"; ( cd "$WT" && bash -c "$acc" ) > "$CACHE/$tid.accept.log" 2>&1; rc=$?
    if [ $rc -ne 0 ]; then echo "close REFUSED: accept exit $rc (log $CACHE/$tid.accept.log)"; exit 1; fi
    sha=$(git -C "$WT" rev-parse --short HEAD)
    body="[claude-opus · ceo] CLOSED. Accept run by the convener → exit 0 at $sha. Chain on this row: Kimi spec → Astra review → Opus build → Astra refute → Kimi second-read. Landing $(git -C "$WT" branch --show-current) → dev next."
    python3 -c 'import json,sys; print(json.dumps({"data":{"tid":sys.argv[1],"status":"done","workspace":"one"}}))' "$tid" | curl -s -m 30 -X POST https://one.ie/api/ask/tasks:status -H "Authorization: Bearer $GW" -H "content-type: application/json" -d @- | grep -q '"ok":true' || die "tasks:status failed"
    python3 -c 'import json,sys; print(json.dumps({"data":{"tid":sys.argv[1],"workspace":"one","body":sys.argv[2]}}))' "$tid" "$body" | curl -s -m 30 -X POST https://one.ie/api/ask/tasks:comment -H "Authorization: Bearer $GW" -H "content-type: application/json" -d @- | grep -q '"ok":true' || die "tasks:comment failed"
    echo "close $tid: done at $sha · ledger: CLOSED $tid $sha"; echo "CLOSED $tid $sha $(date -u +%FT%TZ)" >> "$CACHE/ledger.log";;
  --self-test)
    fx="task:selftest000000000000000"; printf 'ROW %s\nTITLE · fixture\n\nACCEPT · false\n' "$fx" > "$CACHE/$fx.row.md"
    acc=$(accept_line "$fx"); ( cd "$WT" 2>/dev/null || cd /; bash -c "$acc" ) >/dev/null 2>&1; rc=$?
    [ $rc -ne 0 ] && { echo "self-test: a failing accept ($acc → exit $rc) is REFUSED before any write — ok"; rm -f "$CACHE/$fx.row.md"; exit 0; }
    echo "self-test: the failing accept read as pass — theatre"; exit 1;;
  *) die "usage: prep <tid> | judge <tid> <base-sha> | close <tid> | --self-test";;
esac
