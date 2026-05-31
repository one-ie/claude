#!/usr/bin/env bash
# do-smoke.sh — deterministic outcome gate for the /do upgrade. Drives fixtures through every
# helper + the state-file schemas + the seed lifecycle. Exits 0 only if ALL pass. The LLM
# phase-sequencing itself is proven by a logged canary `/do <idea>` run, NOT by this script
# (a bash script cannot drive Claude — see plans/do-loop-todo.md outcome contract).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
S=.claude/scripts
fail=0
ok(){ printf '  \xe2\x9c\x93 %s\n' "$1"; }
no(){ printf '  \xe2\x9c\x97 %s\n' "$1"; fail=1; }

echo "== C0 do-folder =="
"$S/do-folder.sh" one.ie/web/src/x.ts | grep -q '"folder":"one.ie/web"' && ok "web file → folder" || no "web file"
"$S/do-folder.sh" .claude/commands/do.md plans/x.md | grep -q '"doc_only":true' && ok "doc-only → skip" || no "doc-only"

echo "== C7 do-tier =="
"$S/do-tier.sh" text/x.md | grep -q '"tier":"PATCH"' && ok "typo → PATCH" || no "PATCH"
"$S/do-tier.sh" schema/one.tql | grep -q '"tier":"SCHEMA"' && ok ".tql → SCHEMA" || no "SCHEMA"
"$S/do-tier.sh" --intent "add billing" one.ie/web/src/api/b.ts | grep -q '"tier":"FEATURE"' && ok "intent → FEATURE" || no "FEATURE"

echo "== C10 do-reconcile =="
echo "uses a node in the colony" | "$S/do-reconcile.sh" >/dev/null 2>&1 && no "dead name should fail" || ok "dead name → exit 1"
echo "signal a mark on a path" | "$S/do-reconcile.sh" >/dev/null 2>&1 && ok "canonical → exit 0" || no "canonical should pass"

echo "== C9 do-survey =="
"$S/do-survey.sh" zxqwfoobar 2>/dev/null | grep -q 'VERDICT: build' && ok "novel → build" || no "novel"
"$S/do-survey.sh" signal 2>/dev/null | grep -qE 'VERDICT: (extend|expose)' && ok "existing → extend/expose" || no "existing"

echo "== C14 do-analyze (current template format: deliverables: + **Deliverable:** + demo/Cycle outcome) =="
"$S/do-analyze.sh" plans/tools-router-todo.md >/dev/null 2>&1 && ok "real plan → every cycle ships + testable" || no "real plan coverage"
tmp=$(mktemp); printf 'deliverables:\n  - api: foo.ts — does X (C1)\nsource_of_truth:\n## C1 — y\n(no deliverable line)\n' > "$tmp"
"$S/do-analyze.sh" "$tmp" >/dev/null 2>&1 && no "cycle w/o deliverable should fail" || ok "cycle ships nothing → CRITICAL exit 1"; rm -f "$tmp"
tmp=$(mktemp); printf 'deliverables:\n  - api: foo.ts — does X (C1)\nsource_of_truth:\n## C1 — y\n**Deliverable:** `foo.ts`\n**Cycle outcome:** vitest passes\n' > "$tmp"
"$S/do-analyze.sh" "$tmp" >/dev/null 2>&1 && ok "well-formed mini-plan → pass" || no "well-formed should pass"; rm -f "$tmp"

echo "== C11 do-prove =="
pv=$("$S/do-prove.sh" one.ie/web/src/components/X.tsx 2>/dev/null); echo "$pv" | grep -q 'surface: frontend' && ok "frontend → /browser" || no "frontend"
pm=$(mktemp); art=$(mktemp); echo "users export revenue analytics" > "$pm"; echo "function foo(){}" > "$art"
"$S/do-prove.sh" --promise "$pm" "$art" >/dev/null 2>&1 && no "over-promise should fail" || ok "over-promise → exit 1"; rm -f "$pm" "$art"

echo "== state-file schemas =="
echo '{"diff_specs":[{"current_state":"x","must_not_break":"y","serves":"D1"}]}' | jq -e '.diff_specs[0]|.current_state and .must_not_break and .serves' >/dev/null && ok ".w2-spec context pack" || no ".w2-spec"
echo '{"renames":[],"touched_docs":[],"contract_dirs":[]}' | jq -e 'has("renames") and has("touched_docs") and has("contract_dirs")' >/dev/null && ok ".w2-doc-plan" || no ".w2-doc-plan"
echo '{"level":"standard","consecutive":1,"composite":0.78,"updated":"t"}' | jq -e '.level and (.composite|type=="number")' >/dev/null && ok ".do-trust" || no ".do-trust"
echo '{"receiver":"cost:cycle","data":{"tokens":{"input":1},"model":"sonnet","composite":0.7}}' | jq -e '.receiver=="cost:cycle" and .data.model' >/dev/null && ok "cost:cycle grammar" || no "cost:cycle"

echo "== /do-loop removed (single front door) =="
# scan commands+agents only (the engine surface); the 'no separate' note is the lone allowed mention
if grep -rn '/do-loop' .claude/commands .claude/agents 2>/dev/null | grep -vq 'no separate'; then no "/do-loop still referenced"; else ok "/do-loop gone (only the 'no separate' note)"; fi
[ -f .claude/commands/do.md ] && ok "do.md is the spec (single front door)" || no "do.md missing"

echo "== C5 seed lifecycle (one.ie/web vitest) =="
if command -v bunx >/dev/null 2>&1; then
  ( cd one.ie/web && bunx vitest run tests/unit/substrate-seed-c5.test.ts >/dev/null 2>&1 ) && ok "seed→promote→fade (4/4)" || no "seed lifecycle test"
else
  echo "  ~ bunx not found — seed test skipped (run in one.ie/web)"
fi

echo "----"
if [ "$fail" -ne 0 ]; then echo "do-smoke: FAIL"; exit 1; fi
echo "do-smoke: PASS — deterministic substrate green. (LLM loop: run a canary /do <idea> and log it.)"; exit 0
