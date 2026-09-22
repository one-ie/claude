#!/usr/bin/env bash
# manifest: monorepo-only
#
# chat-context-check.sh — the deep chat context reaches the prompt, and the
# checker that says so can go RED.
#
# WHAT IT GUARDS. Two fields carry the operator's ask: `contextPack.page.body`
# (the page read in full, not just its headings) and `contextPack.panel` (the
# tab open in the rail beside the chat, and its rows). Both cross four files —
# the sender (Chat.tsx), web's edge sanitizer (/api/chat), channels'
# sanitizer, and channels' renderer — and a field that any one of them does not
# name is DEAD while every other test stays green. That has happened four times
# on this exact path (`workflowId` twice, `focusBlockId`, `page`).
#
# WHY A SCRIPT AND NOT JUST THE SUITE. The suite proves the field arrives. This
# proves the SUITE would notice if it stopped: it cuts the copy line out of
# `sanitizeContextPack`, re-runs, and requires a failure. A green run against a
# gutted sanitizer would mean the assertions were reading something else.
#
#   bash .claude/scripts/chat-context-check.sh              # green half
#   bash .claude/scripts/chat-context-check.sh --self-test  # both halves
#
# Exit codes: 0 ok · 1 the suite is red on an untouched tree · 2 the RED PROOF
# failed (the suite stayed green with the wire cut) · 3 setup (dirty target).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CTX="$ROOT/channels/src/context.ts"
SUITES=(test/context-pack-deep.test.ts test/context-pack-parity.test.ts)

run_suite() {
  ( cd "$ROOT/channels" && bash "$ROOT/.claude/scripts/gate-run.sh" chat-ctx-check -- bunx vitest run "${SUITES[@]}" ) >"$1" 2>&1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[chat-context] green half — the suite on an untouched tree"
if ! run_suite "$TMP/green.log"; then
  echo "[chat-context] RED on an untouched tree — this is a real failure, not a proof:"
  tail -30 "$TMP/green.log"
  exit 1
fi
grep -E 'Tests +[0-9]+ passed' "$TMP/green.log" || true

if [ "${1:-}" != "--self-test" ]; then
  echo "[chat-context] ok — pass --self-test for the red proof"
  exit 0
fi

# ── RED PROOF ───────────────────────────────────────────────────────────────
# Cut the two copy lines out of channels' sanitizer, one at a time, and require
# the suite to notice. The file is restored on every exit path, including a
# SIGINT — a checker that can leave the tree mutated is worse than no checker.
if ! git -C "$ROOT" diff --quiet -- channels/src/context.ts; then
  echo "[chat-context] refusing: channels/src/context.ts already has uncommitted edits."
  echo "               The red proof rewrites it and restores from THIS copy; it will not"
  echo "               step on work in progress."
  exit 3
fi
cp "$CTX" "$TMP/context.ts.orig"
restore() { cp "$TMP/context.ts.orig" "$CTX"; }
trap 'restore; rm -rf "$TMP"' EXIT INT TERM

fail=0
cut_and_check() {
  local label="$1" pattern="$2"
  restore
  if ! grep -q "$pattern" "$CTX"; then
    echo "[chat-context] RED PROOF SETUP FAILED — no line matching: $pattern"
    echo "               The wire moved. Update this checker or it is guarding nothing."
    fail=1
    return
  fi
  grep -v "$pattern" "$TMP/context.ts.orig" > "$CTX"
  if run_suite "$TMP/red-$label.log"; then
    echo "[chat-context] RED PROOF FAILED ($label) — the suite stayed GREEN with the wire cut."
    fail=1
  else
    echo "[chat-context] red proof ok: cutting $label turns the suite red"
  fi
}

cut_and_check "page.body"  "page.body = rawBody.slice"
cut_and_check "panel.tab"  "pack.panel = panel"
restore

[ "$fail" -eq 0 ] || exit 2
echo "[chat-context] ok — the field arrives, and the checker can go red"
