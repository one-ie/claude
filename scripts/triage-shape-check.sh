#!/usr/bin/env bash
# triage-shape-check.sh — prove the `shape` half of .claude/workflows/triage.js
# writes a sane, non-destructive plan. Same idiom as do-tier.sh --self-test and
# do-triage.sh --self-test: one command, exits non-zero on failure, and carries
# a RED PROOF so a checker that stays green against gutted code is caught.
#
# manifest: monorepo-only
#
# WHY THIS EXISTS. The shape phase emits a LIST of board writes, and the list is
# where the damage lives, not the words. Two of these invariants were broken in
# the first version and neither would have failed a syntax check:
#   · TWO tasks:notes writes. tasks:notes SETS the body, it does not append, so
#     the second silently destroyed the first — and the survivor said
#     "accept: see above" pointing at the line it had just deleted. Exactly the
#     defect the board already carries one layer down (an absent notes key is a
#     silent DELETE returning ok:true).
#   · tasks:assign, which is not in the receiver registry and would dissolve as
#     unknown_receiver.
# Both are invisible to the eye and obvious to this file.
#
# Usage:  bash .claude/scripts/triage-shape-check.sh [--red]
#         --red   gut the guard and assert this checker goes RED

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WF="$ROOT/.claude/workflows/triage.js"
SDK="$ROOT/packages/sdk/src/receivers.ts"
RED=0
[ "${1:-}" = "--red" ] && RED=1

[ -f "$WF" ] || { echo "FAIL: no $WF"; exit 2; }

run_cases() { # <workflow file>
  node - "$1" "$SDK" <<'NODE'
// eval() IS DELIBERATE AND BOUNDED HERE, and JSON.parse cannot replace it: the
// tables it lifts contain REGEX LITERALS (ROUTES) and unquoted keys (SPLIT),
// neither of which is JSON. The input is not untrusted — it is a tracked file
// in this repo, read by path, and the whole point of the checker is to test the
// SHIPPING definitions rather than a copy that can drift. A copy is the failure
// mode this file exists to prevent: two definitions of one rule is how the
// routing table and its fixtures disagree silently. Never point this at a path
// a caller supplies.
const fs = require('fs')
const src = fs.readFileSync(process.argv[2], 'utf8')
const sdk = fs.existsSync(process.argv[3]) ? fs.readFileSync(process.argv[3], 'utf8') : ''
const grab = (re) => { const m = src.match(re); if (!m) { console.log('FAIL: could not find ' + re); process.exit(3) } return m[0] }
const ROUTES = eval('(' + grab(/const ROUTES = \[[\s\S]*?\n\]/).replace('const ROUTES = ', '') + ')')
const SPLIT  = eval('(' + grab(/const SPLIT = \{[\s\S]*?\n\}/).replace('const SPLIT = ', '') + ')')
eval(grab(/function routeFor[\s\S]*?\n\}/))
eval(grab(/function plannedWrites[\s\S]*?\n  return writes\n\}/))

let bad = 0
const fail = (m) => { console.log('  FAIL  ' + m); bad++ }
const ok   = (m) => console.log('  ok    ' + m)

// ── 1. routing: what a file IS beats what it is ABOUT ───────────────────────
// The first draft put the money nouns first and sent a wallet COMPONENT and a
// wallet TEST to security-auditor. These fixtures are that bug, frozen.
for (const [p, want] of [
  ['one.ie/web/src/components/wallet/AllWallets.tsx', 'implementer'],
  ['one.ie/web/tests/unit/wallet/x.test.ts', 'test-engineer'],
  ['one.ie/web/src/lib/auth/passkey-webauthn.ts', 'security-auditor'],
  ['pay/backend/src/signing-key.ts', 'security-auditor'],
  ['schema/one.tql', 'architect'],
  ['one.ie/web/src/lib/resolvers/tasks.ts', 'architect'],
  ['text/story.md', 'tech-writer'],
  ['one.ie/web/wrangler.toml', 'release-manager'],
  ['one.ie/web/src/pages/about.astro', 'implementer'],
  ['somewhere/random.go', 'cto'],
]) {
  const got = routeFor([p])
  got === want ? ok(`route ${want.padEnd(17)}${p}`) : fail(`route ${p} → ${got}, want ${want}`)
}

// ── 2. the write plan ───────────────────────────────────────────────────────
const C = {
  FIX: { title: 'send button does nothing', triage: { verdict: 'sizeable', paths: ['one.ie/web/src/components/wallet/AllWallets.tsx'] }, size: { tier: 'FIX' },
    shape: { want: 'Stop the Send button pretending it moved money', why: 'It emits telemetry and signs nothing.', subtasks: ['a', 'b', 'c'], chain: true, assignee: 'implementer' } },
  UNSIZED: { title: 'make chat nicer', triage: { verdict: 'idea', paths: [] }, size: { tier: 'UNSIZED' }, shape: null },
  PATCH: { title: 'typo', triage: { verdict: 'sizeable', paths: ['text/readme.md'] }, size: { tier: 'PATCH' },
    shape: { want: 'Fix the misspelled word', why: '', subtasks: [], chain: false, assignee: 'tech-writer' } },
}
const plans = Object.fromEntries(Object.entries(C).map(([k, t]) => [k, plannedWrites(t)]))

for (const [k, w] of Object.entries(plans)) {
  const ops = w.map((x) => x.op)
  // EXACTLY ONE notes write. Two means the second clobbers the first.
  const notes = w.filter((x) => x.op === 'tasks:notes')
  notes.length <= 1 ? ok(`${k}: one notes write`) : fail(`${k}: ${notes.length} notes writes — the later SETS over the earlier`)
  if (notes[0] && /accept:\s*see above/i.test(notes[0].text)) fail(`${k}: notes back-reference a line this plan deletes`)
  // The capture lands FIRST, before anything can overwrite the title.
  ops[0] === 'tasks:comment' ? ok(`${k}: capture first`) : fail(`${k}: first write is ${ops[0]}, not tasks:comment`)
  // Every emitted receiver must exist.
  if (sdk) for (const op of new Set(ops)) {
    if (!sdk.includes('"' + op + '"')) fail(`${k}: ${op} is not in the receiver registry — would dissolve as unknown_receiver`)
  }
}
// UNSIZED is shaped by nobody.
{
  const ops = plans.UNSIZED.map((x) => x.op)
  ops.some((o) => ['tasks:rename', 'tasks:reassign', 'tasks:subtask'].includes(o))
    ? fail('UNSIZED row was renamed/assigned/split — absence of recon must not read as simplicity')
    : ok('UNSIZED: no title, no owner, no children')
}
// PATCH is one piece.
plans.PATCH.some((x) => x.op === 'tasks:subtask') ? fail('PATCH got children') : ok('PATCH: no children')
// The chain leaves exactly one sibling ready.
{
  const subs = plans.FIX.filter((x) => x.op === 'tasks:subtask')
  subs.length === 3 ? ok('FIX: 3 children') : fail(`FIX: ${subs.length} children, want 3`)
  subs[0] && subs[0].blockedBy ? fail('first sibling is blocked — nothing would be ready') : ok('FIX: first sibling ready')
  subs.slice(1).every((s) => s.blockedBy) ? ok('FIX: later siblings chained') : fail('FIX: a later sibling is unchained — siblings race')
}
process.exit(bad ? 1 : 0)
NODE
}

if [ "$RED" -eq 0 ]; then
  echo "triage-shape-check — invariants"
  run_cases "$WF"; rc=$?
  [ $rc -eq 0 ] && echo "triage-shape: self-test green" || echo "triage-shape: self-test FAILED"
  exit $rc
fi

# ── RED PROOF ────────────────────────────────────────────────────────────────
# A checker that stays green against gutted code proves nothing. Re-introduce
# the two defects that were actually shipped and assert this file catches both.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
gut="$tmp/triage.js"

echo "RED PROOF 1 — second notes write restored (the clobber)"
sed 's|if (body) writes.splice(1, 0, { op: .tasks:notes., text: body })|if (body) writes.splice(1, 0, { op: "tasks:notes", text: body }); if (task.shape \&\& task.shape.why) writes.push({ op: "tasks:notes", text: task.shape.why + "\\n\\naccept: see above" })|' "$WF" > "$gut"
if run_cases "$gut" >/dev/null 2>&1; then echo "  FAIL: checker stayed GREEN against a double notes write"; exit 1
else echo "  ok   checker went RED"; fi

echo "RED PROOF 2 — tasks:assign restored (the absent receiver)"
sed "s|op: 'tasks:reassign'|op: 'tasks:assign'|" "$WF" > "$gut"
if run_cases "$gut" >/dev/null 2>&1; then echo "  FAIL: checker stayed GREEN against an unwired receiver"; exit 1
else echo "  ok   checker went RED"; fi

echo "RED PROOF 3 — money rule moved back to the front (the mis-route)"
node -e '
const fs=require("fs");let s=fs.readFileSync(process.argv[1],"utf8");
s=s.replace(/const ROUTES = \[[\s\S]*?\n\]/,`const ROUTES = [\n  [/(^|\\\\/)(auth|passkey|vault|signer|wallet|escrow|payment|credits)/i, "security-auditor"],\n  [/\\\\.(astro|tsx|jsx|css)$|components?\\\\/|pages?\\\\//i, "implementer"],\n]`);
fs.writeFileSync(process.argv[2],s)' "$WF" "$gut"
if run_cases "$gut" >/dev/null 2>&1; then echo "  FAIL: checker stayed GREEN against a greedy money rule"; exit 1
else echo "  ok   checker went RED"; fi

echo "triage-shape: red proofs green (all three defects caught)"
