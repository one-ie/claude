#!/usr/bin/env bash
# notify — send a Telegram message or file via onedotbot
# DEPRECATED (C6): prefer `cc-connect send` which routes through space:post and
# mirrors the message to the oo workspace inbox. Keep this for file sends and
# direct Telegram delivery where space:post is unavailable.
# Usage:
#   notify.sh <message>
#   notify.sh --to <username|chat_id> <message>
#   notify.sh --file <path> [caption]
#   notify.sh --to <username|chat_id> --file <path> [caption]
#
# Known recipients (add more as they connect to onedotbot):
#   me / tony   → 631201930
#   donal       → 714125982

set -euo pipefail

TOKEN="${TELEGRAM_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  DEV_VARS="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)/channels/.dev.vars"
  if [[ -f "$DEV_VARS" ]]; then
    TOKEN=$(grep '^TELEGRAM_TOKEN=' "$DEV_VARS" | cut -d'=' -f2-)
  fi
fi

if [[ -z "$TOKEN" ]]; then
  echo "TELEGRAM_TOKEN not set and channels/.dev.vars not found" >&2
  exit 1
fi

# Defaults
CHAT_ID="631201930"
FILE=""
ARGS=()

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to)
      RECIPIENT="$2"; shift 2
      case "$RECIPIENT" in
        me|tony)   CHAT_ID="631201930" ;;
        donal)     CHAT_ID="714125982" ;;
        *)         CHAT_ID="$RECIPIENT" ;;
      esac
      ;;
    --file)
      FILE="$2"; shift 2
      ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

MSG="${ARGS[*]:-}"

if [[ -n "$FILE" ]]; then
  if [[ ! -f "$FILE" ]]; then
    echo "file not found: $FILE" >&2; exit 1
  fi
  CAPTION="${MSG:-$(basename "$FILE")}"
  curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
    -F "chat_id=${CHAT_ID}" \
    -F "document=@${FILE}" \
    -F "caption=${CAPTION}" \
    -m 30 | python3 -c 'import json,sys; r=json.load(sys.stdin); print("sent ✓" if r.get("ok") else f"error: {r}")'
else
  if [[ -z "$MSG" ]]; then
    echo "usage: notify.sh [--to <recipient>] [--file <path>] <message>" >&2; exit 1
  fi
  curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":${CHAT_ID},\"text\":$(echo "$MSG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}" \
    -m 10 | python3 -c 'import json,sys; r=json.load(sys.stdin); print("sent ✓" if r.get("ok") else f"error: {r}")'
fi
