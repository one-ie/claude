#!/usr/bin/env bash
# resume-lost-sessions.sh — reopen the Claude Code sessions killed by the
# 2026-09-16 12:14 reboot, one Ghostty tab each.
#
# manifest: monorepo-only
#
# WHY THIS EXISTS. The box rebooted at 12:14 and took 8 live sessions with it.
# Every session's COMMITTED work survived — all of it is in production at
# c716295ac (verified by probe: /buttons 200, /ambient 404). What died was the
# conversation: the half-finished next step each one was holding in context.
# `--resume <id>` restores that context; the transcripts are on disk under
# ~/.claude/projects/-Users-toc-Server-one-ie/.
#
# Usage:
#   bash .claude/scripts/resume-lost-sessions.sh --list     # names + status, no side effects
#   bash .claude/scripts/resume-lost-sessions.sh <key>...   # open those tabs
#   bash .claude/scripts/resume-lost-sessions.sh --unfinished
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# key|session-id|status|what it was doing
ROWS=(
"media|baa8d065-7e0a-44a5-be4a-0b65ea39252f|MID-CYCLE|@chairman team: pages/media — view, upload, generate media and insert into pages. Was at /close when it died."
"blocks|3aa1bc43-0029-4ddd-bd4e-bc76695dd74c|LANDED|One block-insert component shared by page editor and documents. Shipped ca89b9c58 + 5b74e7f4d. Was at /close."
"components|a82ef0c3-3863-40ed-84b8-49502e42a42e|MID-CYCLE|Parallel agents enhancing the hundreds of page-editor components. 9 turns in, feat/components merged — more was planned."
"pages-links|bd004874-cd1e-4298-bd8d-a733721c8af0|OPEN Q|Feature pages (pages/analytics etc.) — wanted links to them, 'on prod'. A question, no commit."
"models|95bead26-d470-4c4a-84d7-41dabbf54144|LANDED|Rank models by intelligence and speed in the + picker. Shipped: src/lib/chat/model-rank.ts."
"ticker|d8b1424b-3bfe-4fa5-92bc-fa4fc197ed4e|LANDED|Real streamed 'thinking' text instead of pretend. Shipped a99651b48. Last words: 'ship it all'."
"chat-url|79bc3b97-dab2-4f3d-a4c1-81b163917e4f|LANDED|Can chat change the page URL the user is on. Shipped d6a41f2f5 + text/chat-navigation-docs.md."
"health|4c2ff180-a2d9-4b37-9cef-9ce9740c5fc9|ONE-SHOT|'health' — the doctor pass. Nothing to resume unless you want another."
)

_row() { local k=$1; for r in "${ROWS[@]}"; do [ "${r%%|*}" = "$k" ] && { echo "$r"; return 0; }; done; return 1; }

if [ $# -eq 0 ] || [ "${1:-}" = "--list" ]; then
  printf '\n  %-13s %-10s %s\n' KEY STATUS "WHAT IT WAS DOING"
  for r in "${ROWS[@]}"; do
    IFS='|' read -r k id st what <<<"$r"
    printf '  %-13s %-10s %s\n' "$k" "$st" "${what:0:88}"
  done
  printf '\n  open one:  bash %s <key>\n' "${BASH_SOURCE[0]#"$ROOT/"}"
  printf '  unfinished only:  bash %s --unfinished\n\n' "${BASH_SOURCE[0]#"$ROOT/"}"
  exit 0
fi

KEYS=("$@")
if [ "${1:-}" = "--unfinished" ]; then
  KEYS=()
  for r in "${ROWS[@]}"; do
    IFS='|' read -r k id st what <<<"$r"
    case "$st" in MID-CYCLE|"OPEN Q") KEYS+=("$k");; esac
  done
  echo "  unfinished: ${KEYS[*]}"
fi

for k in "${KEYS[@]}"; do
  r="$(_row "$k")" || { echo "  ✗ unknown key: $k (try --list)" >&2; continue; }
  IFS='|' read -r _ id st what <<<"$r"
  echo "  → $k  ($st)  $id"
  osascript <<OSA >/dev/null 2>&1 || echo "     (could not open a tab — run by hand: cd $ROOT && claude --resume $id)"
tell application "Ghostty" to activate
tell application "System Events" to keystroke "t" using command down
delay 0.7
tell application "System Events" to keystroke "cd $ROOT && claude --resume $id"
tell application "System Events" to key code 36
OSA
  sleep 1
done
