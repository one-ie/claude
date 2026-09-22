#!/usr/bin/env bash
# do-smoke.sh — deterministic outcome gate for the /do refinement.
# Drives fixtures through every helper + state-file schemas +
# the seven-canon predicate (do-reconcile.sh) + navigation reachable/orphan fixtures.
# Exits 0 only if ALL pass.
set -uo pipefail

# _GATE — route a heavy compute through the machine governor. A gate_lock only
# dedupes IDENTICAL work; a SLOT is what bounds N worktrees each running one of
# these at once (measured 2026-09-07: three concurrent 2.5GB typecheckers, every
# lock uncontended, load 171). Empty when already inside a gate, so a nested call
# inherits the outer slot rather than taking a second one.
#
# Resolves gate-run.sh from its OWN directory, deliberately: an earlier version
# keyed off $ROOT and got inserted above the line that sets it, so _GATE was
# silently empty and every call ran ungoverned -- a fail-OPEN, which is the exact
# defect this preamble exists to close.
_GATE=()
if [ "${GOVERN_IN_GATE:-0}" != "1" ]; then
  _GR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-run.sh"
  [ -f "$_GR" ] && _GATE=( bash "$_GR" "compute:$(basename "${BASH_SOURCE[0]}")" -- )
fi

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
S=.claude/scripts
fail=0
ok(){ printf '  \xe2\x9c\x93 %s\n' "$1"; }
no(){ printf '  \xe2\x9c\x97 %s\n' "$1"; fail=1; }

echo "== C0 do-folder =="
"$S/do-folder.sh" one.ie/web/src/x.ts | grep -q '"folder":"one.ie/web"' && ok "web file → folder" || no "web file"
"$S/do-folder.sh" .claude/commands/do.md text/x-plan.md | grep -q '"doc_only":true' && ok "doc-only → skip" || no "doc-only"

echo "== C7 do-tier =="
"$S/do-tier.sh" text/x.md | grep -q '"tier":"PATCH"' && ok "typo → PATCH" || no "PATCH"
"$S/do-tier.sh" schema/one.tql | grep -q '"tier":"SCHEMA"' && ok ".tql → SCHEMA" || no "SCHEMA"
"$S/do-tier.sh" channels/migrations/0001_init.sql | grep -q '"tier":"SCHEMA"' && ok "D1 migration → SCHEMA" || no "D1 migration"
"$S/do-tier.sh" pay/contracts/sui/sources/one_token.move | grep -q '"tier":"SCHEMA"' && ok "contract source → SCHEMA" || no "contract source"
"$S/do-tier.sh" pay/contracts/sui/tests/gateway_tests.move | grep -q '"tier":"FIX"' && ok "contract test → FIX (not SCHEMA)" || no "contract test"
"$S/do-tier.sh" --intent "add billing" one.ie/web/src/api/b.ts | grep -q '"tier":"FEATURE"' && ok "intent → FEATURE" || no "FEATURE"
# Absence of recon must not read as simplicity: no paths → UNSIZED, never PATCH.
# Intent is deliberately ignored here — "add a null check" and "add a settings page"
# share a verb, so a sentence alone can't size anything. Exit 3 is the contract.
# Capture before grepping: UNSIZED exits 3, and under `pipefail` that propagates
# through the pipe even when grep matches — the same trap any caller piping do-tier
# into grep/jq will hit now that it can exit non-zero.
UNS=$(echo "" | "$S/do-tier.sh" --intent "add a settings page" 2>/dev/null); UNS_RC=$?
case "$UNS" in *'"tier":"UNSIZED"'*) ok "no paths → UNSIZED (not PATCH)" ;; *) no "UNSIZED" ;; esac
[ "$UNS_RC" -eq 3 ] && ok "UNSIZED → exit 3" || no "UNSIZED exit code (got $UNS_RC)"

echo "== C2 do-reconcile — substrate canon =="
echo "uses a node in the colony" | "$S/do-reconcile.sh" substrate >/dev/null 2>&1 && no "dead name should fail substrate" || ok "dead name → substrate exit 1"
echo "signal a mark on a path" | "$S/do-reconcile.sh" substrate >/dev/null 2>&1 && ok "canonical → substrate exit 0" || no "canonical should pass substrate"

echo "== C2 do-reconcile — dictionary canon =="
echo "this uses knowledge not groups" | "$S/do-reconcile.sh" dictionary >/dev/null 2>&1 && no "dead name should fail dictionary" || ok "dead name → dictionary exit 1"
echo "signal mark warn fade follow harden" | "$S/do-reconcile.sh" dictionary >/dev/null 2>&1 && ok "verbs only → dictionary exit 0" || no "verbs should pass dictionary"

echo "== C2 do-reconcile — authority canon =="
echo 'if (role === "admin") return true' | "$S/do-reconcile.sh" authority >/dev/null 2>&1 && no "ad-hoc role check should fail" || ok "ad-hoc role → authority exit 1"
echo 'const ok = await can(actor, group, "manage_clients")' | "$S/do-reconcile.sh" authority >/dev/null 2>&1 && ok "walk-up → authority exit 0" || no "walk-up should pass"

echo "== C2 do-reconcile — sdk canon =="
echo 'SubstrateClient.signal = () => {}' | "$S/do-reconcile.sh" sdk >/dev/null 2>&1 && no "verb redef should fail sdk" || ok "verb redef → sdk exit 1"
echo 'await client.signal("chat:message", data)' | "$S/do-reconcile.sh" sdk >/dev/null 2>&1 && ok "receiver call → sdk exit 0" || no "receiver call should pass sdk"

echo "== C2 do-reconcile — design canon (promise-check) =="
pm=$(mktemp); art=$(mktemp)
echo "users export revenue analytics dashboard" > "$pm"
echo "function foo(){ return 42; }" > "$art"
"$S/do-reconcile.sh" design --promise "$pm" "$art" >/dev/null 2>&1 && no "over-promise should fail design" || ok "over-promise → design exit 1"
echo "revenue analytics export dashboard" >> "$art"
"$S/do-reconcile.sh" design --promise "$pm" "$art" >/dev/null 2>&1 && ok "promise hit → design exit 0" || no "promise hit should pass design"
rm -f "$pm" "$art"

echo "== C2 do-reconcile — types canon =="
# State the baseline = current real error count so delta = 0 (smoke tests the logic,
# not the errors). Per-call env, never a file on disk — see do-reconcile.sh canon 7.
# Use a temp file to capture grep output — avoids pipefail swallowing the value when tsc
# exits non-zero (which it does whenever there are any type errors).
_tsc_tmp=$(mktemp)
( cd one.ie/web 2>/dev/null && "${_GATE[@]}" bunx tsc --noEmit 2>&1 | grep -c 'error TS' > "$_tsc_tmp" ) 2>/dev/null || true
_tsc_now=$(cat "$_tsc_tmp" 2>/dev/null | tr -d '[:space:]'); rm -f "$_tsc_tmp"
RECONCILE_TSC_BASELINE="${_tsc_now:-0}" "$S/do-reconcile.sh" types >/dev/null 2>&1 && ok "types delta=0 → exit 0" || no "types should pass when no delta"

echo "== C2 do-reconcile — navigation --self-test =="
"$S/do-reconcile.sh" navigation --self-test && ok "navigation self-test → exit 0" || no "navigation self-test failed"

echo "== C2 do-reconcile — unknown canon =="
"$S/do-reconcile.sh" invalid_canon >/dev/null 2>&1 && no "unknown canon should exit 2" || ok "unknown canon → non-zero exit"

echo "== C9 do-survey =="
"$S/do-survey.sh" zxqwfoobar 2>/dev/null | grep -q 'VERDICT: build' && ok "novel → build" || no "novel"
"$S/do-survey.sh" signal 2>/dev/null | grep -qE 'VERDICT: (extend|expose)' && ok "existing → extend/expose" || no "existing"

echo "== C14 do-analyze =="
"$S/do-analyze.sh" text/tools-router-todo.md >/dev/null 2>&1 && ok "real plan → every cycle ships + testable" || no "real plan coverage"
tmp=$(mktemp); printf 'deliverables:\n  - api: foo.ts — does X (C1)\nsource_of_truth:\n## C1 — y\n(no deliverable line)\n' > "$tmp"
"$S/do-analyze.sh" "$tmp" >/dev/null 2>&1 && no "cycle w/o deliverable should fail" || ok "cycle ships nothing → CRITICAL exit 1"; rm -f "$tmp"

echo "== C3 do-prove — pure PROVE (no promise flag) =="
pv=$("$S/do-prove.sh" one.ie/web/src/components/X.tsx 2>/dev/null); echo "$pv" | grep -q 'surface: frontend' && ok "frontend → /browser" || no "frontend surface"
pv2=$("$S/do-prove.sh" one.ie/web/src/pages/api/foo.ts 2>/dev/null); echo "$pv2" | grep -q 'surface: api' && ok "api → contract test" || no "api surface"
# Confirm do-prove.sh is promise-free (no --promise flag logic)
"$S/do-prove.sh" one.ie/web/src/pages/index.astro 2>/dev/null | grep -q 'PROVE: pass' && ok "do-prove passes cleanly" || no "do-prove should pass cleanly"

echo "== state-file schemas =="
echo '{"diff_specs":[{"current_state":"x","must_not_break":"y","serves":"D1"}]}' | jq -e '.diff_specs[0]|.current_state and .must_not_break and .serves' >/dev/null && ok ".w2-spec context pack" || no ".w2-spec"
echo '{"renames":[],"touched_docs":[],"contract_dirs":[]}' | jq -e 'has("renames") and has("touched_docs") and has("contract_dirs")' >/dev/null && ok ".w2-doc-plan" || no ".w2-doc-plan"
echo '{"level":"standard","consecutive":1,"composite":0.78,"updated":"t"}' | jq -e '.level and (.composite|type=="number")' >/dev/null && ok ".do-trust" || no ".do-trust"
echo '{"receiver":"cost:cycle","data":{"tokens":{"input":1},"model":"sonnet","composite":0.7}}' | jq -e '.receiver=="cost:cycle" and .data.model' >/dev/null && ok "cost:cycle grammar" || no "cost:cycle"

echo "== TEACH + TEST stops =="
[ -f text/template-tests.md ] && ok "template-tests.md exists (TEST scaffold)" || no "template-tests.md missing"
[ -f text/template-teach.md ] && ok "template-teach.md exists (TEACH scaffold)" || no "template-teach.md missing"
[ -f text/do-refined-doc.md ] && ok "do-refined-doc.md exists (TEACH stop ran for do-refined)" || no "do-refined-doc.md missing (TEACH stop never ran)"
# Confirm template-spec-plan.md (stale alias) is gone
[ -f text/template-spec-plan.md ] && no "template-spec-plan.md still exists (should be deleted)" || ok "template-spec-plan.md removed (renamed → template-plan.md)"

echo "== 000-do.md + templates-plan.md =="
[ -f text/do.md ] && ok "text/do.md exists (narrative for humans)" || no "text/do.md missing"
grep -q 'template-teach.md\|TEACH' text/templates-plan.md 2>/dev/null && ok "templates-plan.md references TEACH" || no "templates-plan.md missing TEACH"
grep -q 'template-tests.md\|TEST' text/templates-plan.md 2>/dev/null && ok "templates-plan.md references TEST" || no "templates-plan.md missing TEST"

echo "== /do-loop removed (single front door) =="
if grep -rn '/do-loop' .claude/commands .claude/agents 2>/dev/null | grep -vq 'no separate'; then no "/do-loop still referenced"; else ok "/do-loop gone (only the 'no separate' note)"; fi
[ -f .claude/commands/do.md ] && ok "do.md is the spec (single front door)" || no "do.md missing"

echo "== do-auto merge digest wired =="
grep -q '^_merge_digest()' "$S/do-auto.sh" && ok "_merge_digest defined" || no "_merge_digest missing"
grep -qE '^_merge_digest$' "$S/do-auto.sh" && ok "_merge_digest called at plan-complete" || no "_merge_digest never called"
grep -q '\.do-digest\.md' .gitignore && ok ".do-digest.md gitignored (ephemeral)" || no ".do-digest.md not ignored"

echo "----"
if [ "$fail" -ne 0 ]; then echo "do-smoke: FAIL"; exit 1; fi
echo "do-smoke: PASS — all canon fixtures green, navigation self-test green, do-prove pure."; exit 0
