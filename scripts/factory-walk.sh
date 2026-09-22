#!/usr/bin/env bash
# factory-walk.sh — the factory's deterministic check of ONE piece of work.
#
# manifest: needs-env
#   Names one.ie/web (the previewed app) and reads that app's gitignored .env
#   through the scripts it composes. Every stage degrades to `unrun`, never to a
#   pass, when the environment cannot answer.
#
# WHAT IT IS. One command whose exit code is the verdict on a task: it walks the
# work across the lifecycle stages text/factory-do.md § THE WHOLE PATH names —
# size · isolate · gate · prove · human · substrate — and writes one receipt. It
# builds NO new gate. Every stage is an existing script, chosen by the tier and
# the surface, run through the governor and the memo:
#
#   size       do-tier.sh            how big is the change; UNSIZED is a FAIL,
#                                    because absence of recon must never read
#                                    as simplicity
#   isolate    worktree-preview.sh   a UI task's tree is a real worktree with
#                                    local .vite/.astro caches (n/a on main)
#   gate       verify-fast.sh        the tier's lane, per folder do-folder.sh
#                                    maps — fast for PATCH/FIX/FEATURE, FULL
#                                    for SCHEMA or schema/sdk/auth paths; via
#                                    gate-run.sh (slot), tsc-cached.sh and
#                                    test-cached.sh (memo). Exit 144 = UNRUN.
#              do-test-gate.sh       …and, on the SAME row, every vitest file the
#                                    rung's `Proof:`/`accept:` names, so a suite
#                                    that collects nothing, skips everything or
#                                    crashes at collect cannot read as green.
#   prove      do-prove.sh           UI: every route, landing rule, against the
#              do-walk.sh --agents   task's preview URL. Otherwise the slug's
#                                    agents walk (text/<slug>-agents.md).
#   human      the link block        UI only: the preview URL, one stop per
#                                    route or per text/<slug>-humans.md stop,
#                                    and the instruction that records the
#                                    verdict. `--humans` on a tty asks y/n.
#                                    Until a person answers, PENDING — which
#                                    is unrun, which is not a pass.
#   substrate  factory-check.sh      SCHEMA tier only: the ladder is live.
#
# THE HONESTY LAW, inherited from do-w4-gates.sh: every stage has FOUR states
#     pass  : ran, green          fail  : ran, red
#     unrun : could not run       n/a   : does not apply, by rule
# and the verdict is `pass` only with ZERO fails AND ZERO unruns. A missing row
# is treated as unrun and named — an absent row is the fail-open trap in data
# form. Exit 0 = pass · 1 = a stage failed · 3 = nothing failed but something
# was not proven (unrun / pending human).
#
# THE LANE IS PART OF THE RECEIPT. A fast pass is never reported as a full pass:
# the receipt and the last line carry `lane:<fast|full|test|none>` beside
# `verdict:<ok|red|unrun>`, which is exactly the pair the executor writes onto
# the task with tasks:tag (§ Tests, T4).
#
# Usage:
#   factory-walk.sh <slug> [--files <path>...] [--route </path>]...
#                   [--preview <url>] [--no-gate] [--humans] [--json <file>]
#   factory-walk.sh --self-test
#
#   <slug>      names text/<slug>-agents.md / -humans.md when they exist, and
#               the receipt. Any word; a task id is fine.
#   --files     the changed paths (default: git diff HEAD + untracked, from
#               the repo this script lives in — a worktree checks itself)
#   --route     a route to prove; repeatable. Derived from changed
#               src/pages/**.astro when omitted (dynamic [param] routes are
#               skipped and named — pass them explicitly)
#   --preview   the task's private server, from worktree-preview.sh up
#               (default http://localhost:4321 — the human's server)
#   --no-gate   record the gate as UNRUN instead of running it (a read of the
#               other stages; never a pass)
#   --humans    on a tty, ask y/n per stop and record the human verdict
#   --json      where the receipt goes (default $TMPDIR/one-factory-walk/<slug>.json)
#
# Env, self-test only (the TSC_CACHE_CMD idiom): FACTORY_WALK_TIER_CMD,
# FACTORY_WALK_GATE_CMD, FACTORY_WALK_PROVE_CMD, FACTORY_WALK_SUBSTRATE_CMD,
# FACTORY_WALK_TESTGATE_CMD substitute the stage's command so every state can be
# driven deterministically; FACTORY_WALK_TESTGATE_DOC substitutes the rung doc
# the gate stage scans for `Proof:` lines; FACTORY_WALK_CHECKLIST substitutes the
# surface checklist stage 3c reads (and, in --self-test, is the ONLY file it will
# read — the repo-root one is ignored, so a neighbouring /do cycle writing its own
# checklist can never flip these checks); and FACTORY_WALK_DROP_ROW=<stage> drops a
# row to prove the missing-row trap bites. None is read outside --self-test.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/.claude/scripts"
cd "$ROOT" || exit 2

# ---------------------------------------------------------------------------
# self-test — every state driven, and the two red proofs that matter
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  fails=0; T="$(mktemp -d)"
  ok()  { printf '  ok   %s\n' "$*"; }
  bad() { printf '  FAIL %s\n' "$*"; fails=$((fails+1)); }
  # stubs: a tier, a gate, a prove, a substrate check — each a tiny script
  printf '#!/bin/bash\necho "{\\"tier\\":\\"%s\\"}"; exit %s\n' FIX 0 > "$T/tier-fix"; chmod +x "$T/tier-fix"
  printf '#!/bin/bash\necho "{\\"tier\\":\\"%s\\"}"; exit %s\n' SCHEMA 0 > "$T/tier-schema"; chmod +x "$T/tier-schema"
  printf '#!/bin/bash\necho "{\\"tier\\":\\"%s\\"}"; exit %s\n' UNSIZED 3 > "$T/tier-unsized"; chmod +x "$T/tier-unsized"
  for rc in 0 1 3 144; do printf '#!/bin/bash\nexit %s\n' "$rc" > "$T/rc$rc"; chmod +x "$T/rc$rc"; done
  printf '#!/bin/bash\necho "PROVE: skipped (no reachable environment)"; exit 0\n' > "$T/prove-skipped"; chmod +x "$T/prove-skipped"
  printf '#!/bin/bash\necho "PROVE: pass (1 route(s) proven)"; exit 0\n' > "$T/prove-pass"; chmod +x "$T/prove-pass"
  run() { # run <expected-exit> <label> <env...> -- <args...>
    local want="$1" label="$2"; shift 2
    local envs=(); while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
    local out rc
    out="$(env "${envs[@]+"${envs[@]}"}" FACTORY_WALK_SELFTEST=1 bash "$0" "$@" --json "$T/r.json" 2>&1)"; rc=$?
    if [ "$rc" = "$want" ]; then ok "$label (exit $rc)"; else bad "$label — expected exit $want, got $rc"; printf '%s\n' "$out" | tail -8 | sed 's/^/       /'; fi
    LAST_OUT="$out"
  }
  COMMON=(FACTORY_WALK_SUBSTRATE_CMD="$T/rc0" FACTORY_WALK_PROVE_CMD="$T/rc0")

  echo "== green: a FIX with every stage answering"
  run 0 "non-UI FIX, gate green, walk green" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  jq -e '.verdict=="ok" and .lane=="fast" and .tier=="FIX"' "$T/r.json" >/dev/null && ok "receipt carries verdict:ok lane:fast tier:FIX" || bad "receipt wrong: $(cat "$T/r.json")"

  echo "== RED PROOFS: the walk must be able to lose"
  run 1 "gate exits 1 → verdict red, exit 1" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc1" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  jq -e '.verdict=="red"' "$T/r.json" >/dev/null && ok "receipt says red" || bad "receipt did not say red"
  run 3 "gate exits 144 (unrun) → NOT a pass, exit 3" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc144" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  jq -e '.stages[]|select(.stage=="gate")|.status=="unrun"' "$T/r.json" >/dev/null && ok "144 is recorded as unrun" || bad "144 not recorded as unrun"
  run 1 "no paths → UNSIZED → FAIL (absence of recon is not simplicity)" FACTORY_WALK_TIER_CMD="$T/tier-unsized" FACTORY_WALK_GATE_CMD="$T/rc0" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  run 3 "--no-gate → gate unrun → exit 3, never 0" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts --no-gate
  run 3 "a dropped stage row reads as unrun, never as pass" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_DROP_ROW=gate "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  case "$LAST_OUT" in *"no row for gate"*) ok "the missing row is NAMED" ;; *) bad "missing row not named" ;; esac

  echo "== UI: the human gets a link and the walk is PENDING until they answer"
  run 3 "UI change, prove skipped, no human yet → exit 3" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_PROVE_CMD="$T/prove-skipped" FACTORY_WALK_SUBSTRATE_CMD="$T/rc0" -- selftest --files one.ie/web/src/pages/factory.astro --preview http://localhost:4399
  case "$LAST_OUT" in *"HUMAN WALK"*"http://localhost:4399/factory"*"factory-walk.sh selftest --humans"*) ok "link block: URL, route, and the record-the-verdict instruction" ;; *) bad "link block missing pieces"; printf '%s\n' "$LAST_OUT" | grep -n 'HUMAN\|http' | head -5 ;; esac
  jq -e '.stages[]|select(.stage=="prove")|.status=="unrun"' "$T/r.json" >/dev/null && ok "a skipped prove is unrun (do-prove exits 0 on skip — the walk reads the line, not the code)" || bad "skipped prove misread"
  run 3 "UI, prove PASS, human pending → still exit 3 (a person has not looked)" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_PROVE_CMD="$T/prove-pass" FACTORY_WALK_SUBSTRATE_CMD="$T/rc0" -- selftest --files one.ie/web/src/pages/factory.astro --preview http://localhost:4399
  jq -e '.stages[]|select(.stage=="human")|.status=="unrun" and (.detail|test("PENDING"))' "$T/r.json" >/dev/null && ok "human stage is PENDING, counted as unrun" || bad "human stage not pending"
  run 3 "a dynamic [param] page with no --route is unrun and named" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_PROVE_CMD="$T/prove-pass" FACTORY_WALK_SUBSTRATE_CMD="$T/rc0" -- selftest --files 'one.ie/web/src/pages/u/[slug]/tasks.astro'
  case "$LAST_OUT" in *"pass --route"*) ok "the fix is named in the output" ;; *) bad "dynamic route not named" ;; esac

  echo "== SCHEMA: the substrate check joins, and a 3 is cannot-run"
  run 3 "schema tier, substrate exits 3 → unrun" FACTORY_WALK_TIER_CMD="$T/tier-schema" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_PROVE_CMD="$T/rc0" FACTORY_WALK_SUBSTRATE_CMD="$T/rc3" -- selftest --files schema/one.tql
  jq -e '.lane=="full"' "$T/r.json" >/dev/null && ok "SCHEMA takes the FULL lane" || bad "SCHEMA did not take the full lane: $(jq -r .lane "$T/r.json")"
  run 1 "schema tier, substrate exits 1 → red" FACTORY_WALK_TIER_CMD="$T/tier-schema" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_PROVE_CMD="$T/rc0" FACTORY_WALK_SUBSTRATE_CMD="$T/rc1" -- selftest --files schema/one.tql

  echo "== test-gate: a rung whose Proof names a vitest file is gated by do-test-gate.sh"
  printf 'Proof: bash .claude/scripts/do-test-gate.sh one.ie/web 4 tests/unit/made-up.test.ts\n' > "$T/rung-todo.md"
  printf '#!/bin/bash\necho "$@" >> "%s/tg.args"; exit 0\n' "$T" > "$T/tg-ok"; chmod +x "$T/tg-ok"
  printf '#!/bin/bash\nexit 1\n' > "$T/tg-red"; chmod +x "$T/tg-red"
  printf '#!/bin/bash\nexit 2\n' > "$T/tg-usage"; chmod +x "$T/tg-usage"
  : > "$T/tg.args"
  run 0 "Proof names a vitest file, test-gate green → walk green" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_TESTGATE_CMD="$T/tg-ok" FACTORY_WALK_TESTGATE_DOC="$T/rung-todo.md" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  case "$(cat "$T/tg.args")" in "one.ie/web 4 tests/unit/made-up.test.ts") ok "the rung's OWN workdir and floor are used, not a re-guessed 1" ;; *) bad "wrong test-gate args: $(cat "$T/tg.args")" ;; esac
  jq -e '[.stages[]|select(.stage=="gate" and (.detail|test("test-gate")))]|length==1' "$T/r.json" >/dev/null && ok "the test-gate row lands on the EXISTING gate stage (six rows, not seven)" || bad "test-gate row missing or duplicated: $(jq -c '[.stages[]|select(.stage=="gate")]' "$T/r.json")"
  echo "   RED PROOF: the same walk, with do-test-gate.sh red"
  run 1 "test-gate exits 1 (vacuous/red vitest) → verdict red, exit 1" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_TESTGATE_CMD="$T/tg-red" FACTORY_WALK_TESTGATE_DOC="$T/rung-todo.md" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  jq -e '.stages[]|select(.stage=="gate" and (.detail|test("test-gate")))|.status=="fail"' "$T/r.json" >/dev/null && ok "receipt records the test-gate row as fail" || bad "test-gate red not recorded as fail"
  run 3 "test-gate refuses as unusable (exit 2) → unrun, exit 3, never 0" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_TESTGATE_CMD="$T/tg-usage" FACTORY_WALK_TESTGATE_DOC="$T/rung-todo.md" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  printf 'Proof: bunx vitest run tests/unit/no-such-file-anywhere.test.ts\n' > "$T/rung-ghost.md"
  run 3 "a Proof naming a vitest file that exists NOWHERE is unrun, never a pass" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_TESTGATE_CMD="$T/tg-ok" FACTORY_WALK_TESTGATE_DOC="$T/rung-ghost.md" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  case "$LAST_OUT" in *"exists nowhere in this tree"*) ok "the unresolvable proof is NAMED" ;; *) bad "unresolvable proof not named" ;; esac
  run 3 "--no-gate skips the test-gate too (a read, never a pass)" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_TESTGATE_CMD="$T/tg-red" FACTORY_WALK_TESTGATE_DOC="$T/rung-todo.md" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts --no-gate
  run 0 "no rung, no changed test file → no test-gate row at all (the walk is unchanged)" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" FACTORY_WALK_TESTGATE_CMD="$T/tg-red" "${COMMON[@]}" -- selftest --files one.ie/web/src/lib/x.ts

  echo "== surface wiring: surface-checklist + the four rows merged from do-w4-gates.sh (A6)"
  SW=(FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc0" "${COMMON[@]}")
  # never-n/a: the whole point of the merge. A DECLARED surface that is not
  # wired must read `fail`; an `n/a` there is the fail-open that lets these four
  # rows be deleted with the proof still green.
  _sw_never_na() { jq -e --arg k "$1" '[.stages[]|select(.stage=="gate" and (.detail|test("surface-wiring "+$k)))]|length==1 and (.[0]|.status=="fail")' "$T/r.json" >/dev/null 2>&1; }

  run 0 "no checklist at all → 3c adds NO row and the walk is unchanged" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  jq -e '[.stages[]|select(.stage=="gate" and (.detail|test("surface-")))]|length==0' "$T/r.json" >/dev/null \
    && ok "an absent checklist makes no claim, so surface-checklist emits no row (a /do artifact the factory never writes)" \
    || bad "3c emitted a row with no checklist: $(jq -c '[.stages[]|select(.stage=="gate")]' "$T/r.json")"

  printf '{"surface":"none"}\n' > "$T/cl.json"
  run 1 "surface-checklist: surface:none WITHOUT a reason → gate fail, exit 1" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  printf '{"surface":"none","reason":"self-test fixture"}\n' > "$T/cl.json"
  run 0 "surface-checklist: surface:none WITH a reason → pass (the gate is not stuck red)" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  printf 'not json at all\n' > "$T/cl.json"
  run 1 "surface-checklist: a checklist that will not parse is a fail, never a skip" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts

  echo "   RED FIRST: each merged row driven red by a declaration the tree cannot confirm"
  printf '{"surfaces":[{"sdk_export":"zzz-not-a-real-export"}]}\n' > "$T/cl.json"
  run 1 "sdk_export declared for an export that does not exist → gate fail, exit 1" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  _sw_never_na sdk_export && ok "the sdk_export row reads fail, NEVER n/a (the standard text/factory-do.md sets)" || bad "sdk_export row was not a single fail: $(jq -c '[.stages[]|select(.stage=="gate")]' "$T/r.json")"
  printf '{"surfaces":[{"mcp_tool":"zzz-not-a-real-tool"}]}\n' > "$T/cl.json"
  run 1 "mcp_tool declared for a tool absent from packages/mcp/src/index.ts → gate fail" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  _sw_never_na mcp_tool && ok "the mcp_tool row reads fail, NEVER n/a" || bad "mcp_tool row was not a single fail"
  printf '{"surfaces":[{"cli_verb":"zzzNotARealVerbCmd"}]}\n' > "$T/cl.json"
  run 1 "cli_verb declared for a verb absent from packages/cli/src/index.ts → gate fail" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  _sw_never_na cli_verb && ok "the cli_verb row reads fail, NEVER n/a" || bad "cli_verb row was not a single fail"
  printf '{"surfaces":[{"inbound_links":["index:zzz-not-on-this-page"]}]}\n' > "$T/cl.json"
  run 1 "inbound_links declared for text that is not on the named page → gate fail" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  _sw_never_na inbound_links && ok "the inbound_links row reads fail, NEVER n/a" || bad "inbound_links row was not a single fail"

  echo "   GREEN: the same four rows against real sites — none of them is stuck red"
  # The four green tokens are chosen for STABILITY, not for realism — a fixture
  # that churns turns this gate false-RED for a reason that is not the walk.
  # `types` is an SDK barrel export, `signal` a LOCKED verb, `walletCmd` an
  # import line in the CLI entry, and `prerender` the Astro SSR idiom on 383 of
  # 394 pages (measured 2026-09-21). one.ie/web/src/pages/index.astro is on the
  # active `clean` board, so a COMPONENT name there (InviteGate, Layout) would
  # have been the brittle choice. If this row ever goes red, check that page
  # first — the walk is probably fine.
  printf '{"surfaces":[{"sdk_export":"types","mcp_tool":"signal","cli_verb":"walletCmd","inbound_links":["index:prerender"]}]}\n' > "$T/cl.json"
  run 0 "all four wired for real (sdk_export · mcp_tool · cli_verb · inbound_links) → gate pass, exit 0" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts
  jq -e '[.stages[]|select(.stage=="gate" and (.detail|test("surface-wiring")))]|length==4 and all(.status=="pass")' "$T/r.json" >/dev/null \
    && ok "four surface-wiring rows, one per declared kind, all pass" || bad "expected 4 passing wiring rows: $(jq -c '[.stages[]|select(.stage=="gate")|.detail]' "$T/r.json")"
  jq -e '[.stages[]|select(.stage=="gate" and (.detail|test("surface-wiring")))]|length==4' "$T/r.json" >/dev/null \
    && ok "an UNDECLARED kind emits no row at all (four declared, four rows — not five, not six)" || bad "row count is not 4"

  run 3 "--no-gate skips 3c too — surface-checklist is a read, never a pass" FACTORY_WALK_CHECKLIST="$T/cl.json" "${SW[@]}" -- selftest --files one.ie/web/src/lib/x.ts --no-gate
  jq -e '[.stages[]|select(.stage=="gate" and (.detail|test("surface-")))]|length==0' "$T/r.json" >/dev/null \
    && ok "--no-gate emits no surface-wiring row" || bad "--no-gate still ran 3c"
  rm -f "$T/cl.json"

  echo "== doc-only: no gate by rule (n/a), and n/a is not unrun"
  run 0 "a text/ change: gate n/a, prove via walk stub, pass" FACTORY_WALK_TIER_CMD="$T/tier-fix" FACTORY_WALK_GATE_CMD="$T/rc1" "${COMMON[@]}" -- selftest --files text/factory-do.md
  jq -e '.stages[]|select(.stage=="gate")|.status=="n/a"' "$T/r.json" >/dev/null && ok "doc-only gate is n/a (the red stub was never run)" || bad "doc-only gate not n/a"

  rm -rf "$T"
  [ "$fails" -eq 0 ] && { echo "factory-walk: self-test PASS"; exit 0; }
  echo "factory-walk: self-test FAILED ($fails)"; exit 1
fi

# ---------------------------------------------------------------------------
# args
# ---------------------------------------------------------------------------
slug=""; files=(); routes=(); preview="${FACTORY_WALK_PREVIEW:-http://localhost:4321}"
no_gate=0; humans=0; json_out=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --files)   shift; while [ "$#" -gt 0 ] && [ "${1#--}" = "$1" ]; do files+=("$1"); shift; done ;;
    --route)   routes+=("$2"); shift 2 ;;
    --preview) preview="${2%/}"; shift 2 ;;
    --no-gate) no_gate=1; shift ;;
    --humans)  humans=1; shift ;;
    --json)    json_out="$2"; shift 2 ;;
    --*)       echo "factory-walk: unknown flag $1" >&2; exit 2 ;;
    *)         [ -z "$slug" ] && slug="$1" || { echo "factory-walk: one slug only" >&2; exit 2; }; shift ;;
  esac
done
[ -n "$slug" ] || { sed -n '2,3p;42,60p' "$0" >&2; exit 2; }
[ -n "$json_out" ] || { mkdir -p "${TMPDIR:-/tmp}/one-factory-walk"; json_out="${TMPDIR:-/tmp}/one-factory-walk/$slug.json"; }
selftest="${FACTORY_WALK_SELFTEST:-0}"

if [ "${#files[@]}" -eq 0 ]; then
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(
    { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | sort -u)
fi

# ---------------------------------------------------------------------------
# receipt rows — jq lines, exactly the do-w4-gates.sh shape
# ---------------------------------------------------------------------------
ROWS="$(mktemp)"; trap 'rm -f "$ROWS"' EXIT
_add() { # stage status detail
  [ "$selftest" = "1" ] && [ "${FACTORY_WALK_DROP_ROW:-}" = "$1" ] && return 0
  jq -n --arg s "$1" --arg st "$2" --arg d "$3" '{stage:$s,status:$st,detail:$d}' >> "$ROWS"
  printf '  %-9s %-6s %s\n' "$1" "$2" "$3"
}
_cmd() { # _cmd <ENV_NAME> <default...> — self-test substitution only
  local v="$1"; shift
  if [ "$selftest" = "1" ] && [ -n "${!v:-}" ]; then printf '%s' "${!v}"; else printf '%s' "$*"; fi
}

echo "FACTORY-WALK: $slug · ${#files[@]} file(s) · preview $preview"

# ---------------------------------------------------------------------------
# 1. size — the fork everything else hangs off
# ---------------------------------------------------------------------------
tier="UNKNOWN"
_tier_cmd="$(_cmd FACTORY_WALK_TIER_CMD bash "$S/do-tier.sh")"
_tier_out="$(printf '%s\n' "${files[@]}" | $_tier_cmd 2>/dev/null)"; _tier_rc=$?
tier="$(printf '%s' "$_tier_out" | jq -r '.tier // "UNKNOWN"' 2>/dev/null || echo UNKNOWN)"
if [ "$_tier_rc" -eq 3 ] || [ "$tier" = "UNSIZED" ]; then
  _add size fail "UNSIZED — no paths to size; absence of recon must never read as simplicity (do-tier.sh exit 3)"
elif [ "$_tier_rc" -ne 0 ] || [ "$tier" = "UNKNOWN" ]; then
  _add size unrun "do-tier.sh could not answer (exit $_tier_rc)"
else
  _add size pass "tier=$tier"
fi

# surface — from the paths, by rule
ui=0; substrate=0; full=0; doc_only=1; pages=()
for f in "${files[@]}"; do
  case "$f" in
    one.ie/web/src/pages/*|one.ie/web/src/components/*|one.ie/web/src/layouts/*|*.astro) ui=1 ;;
  esac
  case "$f" in schema/*|*.tql) substrate=1 ;; esac
  case "$f" in schema/*|packages/sdk/*|*auth*|*authority*|*roles*) full=1 ;; esac
  case "$f" in *.md|.claude/*|text/*|docs/*) ;; *) doc_only=0 ;; esac
  case "$f" in one.ie/web/src/pages/*.astro) pages+=("$f") ;; esac
done
[ "$tier" = "SCHEMA" ] && full=1
# derive routes from the changed pages
for pg in "${pages[@]+"${pages[@]}"}"; do
  r="${pg#one.ie/web/src/pages}"; r="${r%.astro}"; r="${r%/index}"; [ -z "$r" ] && r="/"
  case "$r" in *\[*) echo "  route     note   $pg is dynamic — pass --route <concrete path> to prove it"; dyn=1; continue ;; esac
  routes+=("$r")
done
dyn="${dyn:-0}"

# ---------------------------------------------------------------------------
# 2. isolate — a UI task lives in a worktree with local caches
# ---------------------------------------------------------------------------
if [ "$ui" -eq 1 ] && [ "$selftest" != "1" ]; then
  _common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$_common" ] && [ "$(dirname "$_common")" != "$ROOT" ]; then
    if bash "$S/worktree-preview.sh" check --dir "$ROOT/one.ie/web" >/dev/null 2>&1; then
      _add isolate pass "linked worktree, per-entry node_modules, local .vite/.astro"
    else
      _add isolate fail "worktree-preview.sh check RED — see \`worktree-preview.sh check --dir $ROOT/one.ie/web\`"
    fi
  else
    _add isolate n/a "main checkout — the human's tree; a task's build goes in a worktree (§ Concurrency)"
  fi
elif [ "$ui" -eq 1 ]; then
  _add isolate n/a "self-test"
else
  _add isolate n/a "not a UI change"
fi

# ---------------------------------------------------------------------------
# 3. gate — the tier's lane, per folder, through the governor and the memo
# ---------------------------------------------------------------------------
lane="none"
if [ "$doc_only" -eq 1 ]; then
  _add gate n/a "doc-only change — no gate by rule (do-folder.sh)"
elif [ "$no_gate" -eq 1 ]; then
  _add gate unrun "--no-gate: the lane was not run (a read, never a pass)"
  lane="$([ "$full" -eq 1 ] && echo full || echo fast)"
else
  lane="$([ "$full" -eq 1 ] && echo full || echo fast)"
  _gate_cmd="$(_cmd FACTORY_WALK_GATE_CMD "")"
  if [ -n "$_gate_cmd" ]; then
    $_gate_cmd "$lane" >/dev/null 2>&1; _g=$?
    case "$_g" in
      0)   _add gate pass "lane=$lane (stub)" ;;
      144) _add gate unrun "lane=$lane exit 144 — the gate could not run (queued out / killed); not red, not green" ;;
      *)   _add gate fail "lane=$lane exit $_g" ;;
    esac
  else
    _gfail=0; _gunrun=0; _gran=0
    while IFS= read -r row; do
      folder="$(printf '%s' "$row" | jq -r '.folder // empty')"; [ -n "$folder" ] || continue
      [ -d "$ROOT/$folder" ] || { _add gate unrun "$folder: not on disk"; _gunrun=1; continue; }
      _log="$(mktemp)"
      if jq -e '.scripts["verify:fast"]' "$ROOT/$folder/package.json" >/dev/null 2>&1; then
        ( cd "$ROOT/$folder" && FULL_VERIFY="$( [ "$lane" = full ] && echo 1 || echo 0 )" bun run verify:fast ) > "$_log" 2>&1; _g=$?
        _lane_ran="$lane"
      elif jq -e '.scripts.test' "$ROOT/$folder/package.json" >/dev/null 2>&1; then
        ( cd "$ROOT/$folder" && bun run test ) > "$_log" 2>&1; _g=$?
        _lane_ran="test"; lane="test"
      else
        _add gate unrun "$folder: no verify:fast or test script"; _gunrun=1; rm -f "$_log"; continue
      fi
      _gran=1
      case "$_g" in
        0)   _add gate pass "$folder lane=$_lane_ran — $(grep -o 'PASS ([^)]*)\|cache HIT[^—]*\|typecheck: 0 errors' "$_log" | tail -1)" ;;
        144) _add gate unrun "$folder lane=$_lane_ran exit 144 — could not run (queued out or killed); log $_log"; _gunrun=1 ;;
        *)   _add gate fail "$folder lane=$_lane_ran exit $_g — $(grep -m1 'FAILED\|FAIL\|error' "$_log" | cut -c1-120); log $_log" ; _gfail=1 ;;
      esac
      [ "$_g" -eq 0 ] && rm -f "$_log"
    done < <(printf '%s\n' "${files[@]}" | bash "$S/do-folder.sh" 2>/dev/null | jq -c 'select(.folder != null)')
    [ "$_gran" -eq 0 ] && [ "$_gfail" -eq 0 ] && [ "$_gunrun" -eq 0 ] && _add gate unrun "no folder mapped — do-folder.sh answered nothing for these paths"
  fi
fi

# ---------------------------------------------------------------------------
# 3b. gate — the vitest accept clauses this task's rung actually names
#
# WHY THIS IS HERE. The lane above answers "does the suite pass". It cannot
# answer "did the suite RUN anything": vitest exits 0 on an all-`it.skip` file,
# on a file that collects zero tests, and on a collect-time crash (the repo's
# `vitest-collect-crash-reads-as-pass`). do-test-gate.sh is the check that
# refuses all three — and until this block, NOTHING on the build path called it.
# Twelve `accept:`/`proof:`/`outcome:` lines in text/*.md invoke it (receipt:
# grep -rnE '^ *(accept|proof|outcome):.*do-test-gate' text/*.md | wc -l), all of
# them prose a human runs by hand. A checker whose only callers are prose is not
# orphaned, which is worse: it rots with nothing going red.
#
# The rows land on the EXISTING `gate` stage on purpose. The verdict loop below
# iterates exactly six stage names; a seventh would never be checked for absence,
# and the missing-row trap is the whole reason that loop exists. When no rung
# names a vitest file, this block adds no row at all and the walk is unchanged.
#
# The floor comes from the rung when the rung states one — a `Proof:` line that
# already reads `do-test-gate.sh one.ie/web 4 tests/unit/x.test.ts` is run with
# ITS workdir and ITS 4, not a re-guessed 1. A bare filename gets floor 1, which
# is the weakest honest claim (it proves the file exercised SOMETHING); the
# strength of the number is the rung author's job, not this script's.
# ---------------------------------------------------------------------------
if [ "$no_gate" -eq 1 ]; then
  : # --no-gate means no gate, including this one; the unrun row above covers it
else
  _tg_docs=()
  if [ "$selftest" = "1" ] && [ -n "${FACTORY_WALK_TESTGATE_DOC:-}" ]; then
    _tg_docs=("$FACTORY_WALK_TESTGATE_DOC")
  else
    for _d in "$ROOT/text/$slug-todo.md" "$ROOT/text/$slug-plan.md" "$ROOT/text/$slug.md"; do
      [ -f "$_d" ] && _tg_docs+=("$_d")
    done
  fi
  _tg_specs="$(
    printf '%s\n' "${files[@]}" | python3 - "$ROOT" "${_tg_docs[@]+"${_tg_docs[@]}"}" <<'PY'
import os, re, sys
root = sys.argv[1]; docs = sys.argv[2:]
TEST = r'[\w./@\[\]-]+\.test\.tsx?'
rows = []   # (workdir, min, path-as-written)
# (a) every changed test file is its own proof — floor 1, the weakest honest claim
for line in sys.stdin.read().splitlines():
    f = line.strip()
    if f and re.fullmatch(TEST, f):
        rows.append(("", "1", f))
# (b) every vitest file named on a Proof:/accept:/proof:/outcome: line of the rung
for doc in docs:
    try:
        text = open(doc, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for line in text.splitlines():
        if not re.search(r'\b(Proof|proof|accept|outcome|demo)\b\s*[:=]', line):
            continue
        if ".test.ts" not in line:
            continue
        claimed = set()
        for m in re.finditer(r'do-test-gate\.sh\s+(\S+)\s+(\d+)((?:\s+' + TEST + r')+)', line):
            for f in m.group(3).split():
                rows.append((m.group(1), m.group(2), f)); claimed.add(f)
        for m in re.finditer(TEST, line):
            if m.group(0) not in claimed:
                rows.append(("", "1", m.group(0)))
if not rows:
    raise SystemExit(0)
# resolve: a fragment like tests/unit/x.test.ts is relative to ITS package, not the repo
_pkgs = None
def packages():
    global _pkgs
    if _pkgs is None:
        _pkgs = []
        for base, dirs, fnames in os.walk(root):
            depth = base[len(root):].count(os.sep)
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in
                       ("node_modules", "dist", "build", ".release", "media")] if depth < 3 else []
            if "package.json" in fnames:
                _pkgs.append(os.path.relpath(base, root))
        _pkgs.sort(key=len)
    return _pkgs
seen = set()
for wd, mn, f in rows:
    if wd:
        # the rung stated its own workdir — take it verbatim. do-test-gate.sh
        # already owns the missing-file verdict ("FAIL missing test file"), and
        # two scripts answering the same question is how they drift apart.
        hit = (wd, mn, f)
    elif os.path.isfile(os.path.join(root, f)):
        d = os.path.dirname(f)
        while d and not os.path.isfile(os.path.join(root, d, "package.json")):
            d = os.path.dirname(d)
        hit = (d or ".", mn, os.path.relpath(f, d) if d else f)
    else:
        cand = [p for p in packages() if os.path.isfile(os.path.join(root, p, f))]
        hit = (cand[0], mn, f) if cand else ("?", mn, f)
    if hit not in seen:
        seen.add(hit); print("\t".join(hit))
PY
  )"
  if [ -n "$_tg_specs" ]; then
    _tg_cmd="$(_cmd FACTORY_WALK_TESTGATE_CMD bash "$S/do-test-gate.sh")"
    while IFS=$'\t' read -r _wd _min _rel; do
      [ -n "$_rel" ] || continue
      if [ "$_wd" = "?" ]; then
        _add gate unrun "test-gate: $_rel is named as a proof but exists nowhere in this tree — a proof pointing at nothing is not a pass"
        continue
      fi
      $_tg_cmd "$_wd" "$_min" "$_rel" >/dev/null 2>&1; _t=$?
      case "$_t" in
        0) _add gate pass  "test-gate $_wd/$_rel floor $_min — the suite exercised something" ;;
        2) _add gate unrun "test-gate $_wd/$_rel: refused as unusable (exit 2) — not run, and not a pass" ;;
        *) _add gate fail  "test-gate $_wd/$_rel floor $_min exit $_t — red, skipped, or vacuous; \`bash $S/do-test-gate.sh $_wd $_min $_rel\`" ;;
      esac
    done <<< "$_tg_specs"
  fi
fi

# ---------------------------------------------------------------------------
# 3c. gate — the per-surface WIRING greps the cycle's checklist DECLARES
#
# WHY THIS IS HERE. do-w4-gates.sh grades a /do cycle against
# .w2-surface-checklist.json: `surface-checklist` (is there a declaration at
# all) and `surface-wiring` (is each declared surface found at its named site).
# Four of that second gate's five branches — inbound_links, sdk_export,
# mcp_tool, cli_verb — are MERGED here (plan rung A6) so they survive D4's
# deletion of that file. They are copied, not moved: do-w4-gates.sh keeps its
# own copies until D4. The fifth branch, the nav-entry one, was DELETED there
# and is deliberately NOT ported — it greped a route table that
# src/lib/navigation.ts does not contain, so it could only ever go red.
#
# THE ONE DELIBERATE DIFFERENCE from do-w4-gates.sh, written down so it is not
# read as drift: an ABSENT checklist is a FAIL there and NO ROW here.
# .w2-surface-checklist.json is a /do W2 artifact (w2-decide.md:95 writes it at
# repo root, .gitignore:78 ignores it) and NOTHING on the factory path writes
# one — factory-executor.js never does. Porting `absent = fail` verbatim would
# turn every factory walk red on an artifact the factory never produces. No
# checklist is no claim, so it gets no row, exactly as 3b adds no row when no
# rung names a vitest file.
#
# WHAT IS NEVER n/a: a checklist that DOES declare a surface which is not wired
# at its named site. That is a `fail` — a declaration the tree cannot confirm is
# the fail-open this whole stage exists to remove, and an `n/a` there would let
# the rows be deleted with the proof still green. `n/a` survives for exactly one
# case: surface:"none" WITH a reason, which is a declaration that there is
# nothing to wire.
#
# The rows land on the EXISTING `gate` stage, for 3b's reason: the verdict loop
# iterates exactly six stage names, and a seventh would never be checked for
# absence — which is the missing-row trap the loop exists to catch.
# ---------------------------------------------------------------------------
if [ "$no_gate" -eq 1 ]; then
  : # --no-gate means no gate, including this one; the unrun row above covers it
else
  if [ "$selftest" = "1" ]; then _sw_cl="${FACTORY_WALK_CHECKLIST:-}"
  else _sw_cl="$ROOT/.w2-surface-checklist.json"; fi

  if [ -n "$_sw_cl" ] && [ -f "$_sw_cl" ]; then
    if ! jq -e . "$_sw_cl" >/dev/null 2>&1; then
      _add gate fail "surface-checklist: $_sw_cl is not readable JSON — a checklist that cannot be parsed is not a checklist"
    elif [ "$(jq -r '.surface // empty' "$_sw_cl")" = "none" ]; then
      if [ -n "$(jq -r '.reason // empty' "$_sw_cl")" ]; then
        _add gate pass "surface-checklist: surface:none with a reason — nothing to wire, and the escape hatch is auditable"
      else
        _add gate fail "surface-checklist: surface:none WITHOUT a reason — an implicit escape hatch is not auditable"
      fi
    else
      _add gate pass "surface-checklist: surfaces declared"
      # the folder that resolves src/ for inbound_links. sdk_export, mcp_tool
      # and cli_verb name fixed repo paths and need no folder.
      _sw_root="$(printf '%s\n' "${files[@]}" | bash "$S/do-folder.sh" 2>/dev/null \
                  | jq -r 'select(.verify) | .folder' | head -1)"
      # _sw_row <kind> <jq-selector> — one row per DECLARED kind. A kind the
      # checklist does not declare gets no row; a kind it declares gets pass or
      # fail, and `unrun` only when the site itself could not be located.
      _sw_row() {
        local kind="$1" sel="$2" n=0 bad=0 miss="" it site
        while IFS= read -r it; do
          [ -n "$it" ] || continue; n=$((n+1))
          case "$kind" in
            inbound_links)
              site="$ROOT/$_sw_root/src/pages/${it%%:*}.astro"
              grep -q "${it#*:}" "$site" 2>/dev/null || { bad=$((bad+1)); miss="$miss $it"; } ;;
            sdk_export)
              grep -q "export.*from.*$it" "$ROOT/packages/sdk/src/index.ts" 2>/dev/null \
                || { bad=$((bad+1)); miss="$miss $it"; } ;;
            mcp_tool)
              grep -q "$it" "$ROOT/packages/mcp/src/index.ts" 2>/dev/null \
                || { bad=$((bad+1)); miss="$miss $it"; } ;;
            cli_verb)
              grep -q "$it" "$ROOT/packages/cli/src/index.ts" 2>/dev/null \
                || { bad=$((bad+1)); miss="$miss $it"; } ;;
          esac
        done < <(jq -r "$sel" "$_sw_cl" 2>/dev/null)
        [ "$n" -eq 0 ] && return 0          # not declared — no claim, no row
        if [ "$kind" = inbound_links ] && [ -z "$_sw_root" ]; then
          _add gate unrun "surface-wiring $kind: $n declared, but no code folder resolved — cannot locate src/pages to grep (not run, and not a pass)"
          return 0
        fi
        if [ "$bad" -gt 0 ]; then
          _add gate fail "surface-wiring $kind: $bad of $n declared NOT wired at its named site —$miss"
        else
          _add gate pass "surface-wiring $kind: $n declared, all wired at their named site"
        fi
      }
      _sw_row inbound_links '.surfaces[]? | select(.inbound_links) | .inbound_links[]'
      _sw_row sdk_export    '.surfaces[]? | select(.sdk_export)    | .sdk_export'
      _sw_row mcp_tool      '.surfaces[]? | select(.mcp_tool)      | .mcp_tool'
      _sw_row cli_verb      '.surfaces[]? | select(.cli_verb)      | .cli_verb'
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 4. prove — routes with the landing rule, or the slug's agents walk
# ---------------------------------------------------------------------------
if [ "$ui" -eq 1 ]; then
  if [ "${#routes[@]}" -eq 0 ]; then
    _add prove unrun "UI change with no provable route$([ "$dyn" = 1 ] && echo ' (dynamic page)') — pass --route </path>"
  else
    _prove_cmd="$(_cmd FACTORY_WALK_PROVE_CMD bash "$S/do-prove.sh")"
    _rargs=(); for r in "${routes[@]}"; do _rargs+=(--route "$r"); done
    _pout="$(PROVE_BASE_URL="$preview" $_prove_cmd "${_rargs[@]}" 2>&1)"; _p=$?
    case "$_pout" in
      *"PROVE: skipped"*|*"PROVE: no changes"*) _add prove unrun "do-prove.sh skipped — no reachable environment at $preview (exit 0 there is NOT a pass)" ;;
      *) if [ "$_p" -eq 0 ]; then _add prove pass "${#routes[@]} route(s) at $preview, landing rule held"
         else _add prove fail "$(printf '%s\n' "$_pout" | grep -m1 'PROVE: FAIL' | cut -c1-140)"; fi ;;
    esac
  fi
else
  _prove_cmd="$(_cmd FACTORY_WALK_PROVE_CMD "")"
  if [ -n "$_prove_cmd" ]; then
    $_prove_cmd >/dev/null 2>&1; _p=$?
    case "$_p" in 0) _add prove pass "agents walk (stub)";; 3) _add prove unrun "walk could not run (stub 3)";; *) _add prove fail "walk failed (stub $_p)";; esac
  elif [ -f "$ROOT/text/$slug-agents.md" ]; then
    _wout="$(WALK_BASE_URL="$preview" bash "$S/do-walk.sh" "$slug" --agents --strict 2>&1)"; _p=$?
    case "$_p" in
      0) _add prove pass "$(printf '%s\n' "$_wout" | grep -m1 '^WALK: pass')" ;;
      3) _add prove unrun "$(printf '%s\n' "$_wout" | grep -m1 'could not be run' | cut -c1-140)" ;;
      *) _add prove fail "$(printf '%s\n' "$_wout" | grep -m1 '^WALK: FAIL' | cut -c1-140)" ;;
    esac
  else
    _add prove unrun "no text/$slug-agents.md — write the walk (one stop per deliverable, expect_cmd = the accept:)"
  fi
fi

# ---------------------------------------------------------------------------
# 5. human — UI only: the link, the stops, and how the verdict lands
# ---------------------------------------------------------------------------
if [ "$ui" -eq 1 ]; then
  hdoc="$ROOT/text/$slug-humans.md"
  echo
  echo "── HUMAN WALK — $slug ──────────────────────────────────────────────"
  echo "   open:  $preview${routes[0]:-/}"
  if [ -f "$hdoc" ]; then
    WALK_BASE_URL="$preview" bash "$S/do-walk.sh" "$slug" --humans --list 2>/dev/null | sed -n '2,$p' | sed 's/^/   /'
  else
    i=0
    for r in "${routes[@]+"${routes[@]}"}"; do
      i=$((i+1)); echo "   $i. $preview$r"
      echo "      · the page you land on IS $r (a bounce to /signin proves nothing — sign in first)"
      echo "      · the change this task describes is visible and behaves; no console errors (⌥⌘I)"
    done
    [ "$i" -eq 0 ] && echo "   (no route derived — open the preview and the page this task changed)"
    echo "   No text/$slug-humans.md yet — one \`\`\`walk block per stop makes this list yours."
  fi
  echo "   record: bash .claude/scripts/factory-walk.sh $slug --humans        # asks y/n per stop on a tty"
  echo "       or: signal(\"tasks:tag\", { tid, tags: [\"verdict:ok\"] })       # or verdict:red — lands on the task"
  echo "────────────────────────────────────────────────────────────────────"
  echo
  if [ "$humans" -eq 1 ] && [ -t 0 ] && [ -f "$hdoc" ]; then
    if WALK_BASE_URL="$preview" bash "$S/do-walk.sh" "$slug" --humans; then _add human pass "a person walked every stop and said ok"
    else _add human fail "a person rejected a stop"; fi
  elif [ "$humans" -eq 1 ] && [ -t 0 ]; then
    printf '   verified in the browser? [y/n] '; read -r v || v=n
    case "$v" in y|Y|yes) _add human pass "a person looked and said ok" ;; *) _add human fail "a person looked and said red" ;; esac
  else
    _add human unrun "PENDING — a person has not looked; the link block above is the instruction"
  fi
else
  _add human n/a "not a UI change"
fi

# ---------------------------------------------------------------------------
# 6. substrate — SCHEMA tier: the ladder is live, and a 3 is cannot-run
# ---------------------------------------------------------------------------
if [ "$substrate" -eq 1 ] || [ "$tier" = "SCHEMA" ]; then
  _sub_cmd="$(_cmd FACTORY_WALK_SUBSTRATE_CMD bash "$S/factory-check.sh" schema-live)"
  $_sub_cmd >/dev/null 2>&1; _s=$?
  case "$_s" in
    0) _add substrate pass "factory-check.sh schema-live" ;;
    3) _add substrate unrun "factory-check.sh could not reach the substrate (3) — nothing proven either way" ;;
    *) _add substrate fail "factory-check.sh schema-live RED (exit $_s)" ;;
  esac
else
  _add substrate n/a "not a schema change"
fi

# ---------------------------------------------------------------------------
# verdict — zero fails AND zero unruns, over exactly the six rows
# ---------------------------------------------------------------------------
fails=$(jq -s '[.[]|select(.status=="fail")]|length' "$ROWS")
unruns=$(jq -s '[.[]|select(.status=="unrun")]|length' "$ROWS")
missing=0
for st in size isolate gate prove human substrate; do
  if [ "$(jq -r --arg s "$st" 'select(.stage==$s)|.stage' "$ROWS" 2>/dev/null | head -1)" != "$st" ]; then
    echo "  $st       unrun  no row for $st — an absent row is the fail-open trap in data form"
    missing=$((missing+1))
  fi
done
unruns=$((unruns + missing))
if [ "$fails" -gt 0 ]; then verdict=red; rc=1
elif [ "$unruns" -gt 0 ]; then verdict=unrun; rc=3
else verdict=ok; rc=0; fi

jq -n --arg slug "$slug" --arg tier "$tier" --arg lane "$lane" --arg verdict "$verdict" \
      --arg preview "$preview" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson ui "$ui" --argjson fails "$fails" --argjson unruns "$unruns" \
      --slurpfile rows "$ROWS" \
      '{slug:$slug, ts:$ts, tier:$tier, lane:$lane, verdict:$verdict, ui:($ui==1), preview:$preview,
        fails:$fails, unruns:$unruns, stages:$rows}' > "$json_out" 2>/dev/null \
  || jq -n --arg slug "$slug" --arg verdict "$verdict" --arg lane "$lane" --arg tier "$tier" '{slug:$slug,verdict:$verdict,lane:$lane,tier:$tier,stages:[]}' > "$json_out"

echo
echo "FACTORY-WALK: $verdict — $fails failed · $unruns not proven · tier $tier · receipt $json_out"
echo "tasks:tag  lane:$lane verdict:$verdict          # what the executor writes on the task (T4)"
exit "$rc"
