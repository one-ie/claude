#!/usr/bin/env bash
# do-reconcile.sh — substrate reconciliation gate (P1.0). Reads a proposal (files or stdin
# text) and FAILS (exit 1) on a dead name or a proposed new dimension/verb. The schema is
# truth: a feature that needs a new dim/verb is rejected before any design spend.
# Usage:  do-reconcile.sh <file|text>...   |   echo "proposal" | do-reconcile.sh
set -euo pipefail

# Locked vocabulary (root CLAUDE.md). Dead names auto-fail.
DEAD="knowledge connections node scent alarm trail colony"
DIMS="groups actors things paths events learning"
VERBS="signal mark warn fade follow harden"

text=""
if [ "$#" -gt 0 ]; then
  for a in "$@"; do if [ -f "$a" ]; then text="$text $(cat "$a")"; else text="$text $a"; fi; done
else
  text="$(cat)"
fi

fail=0
for d in $DEAD; do
  if printf '%s' "$text" | grep -qiw "$d"; then
    echo "DEAD-NAME: '$d' — use the canonical term (dims: $DIMS)"; fail=1
  fi
done

if [ "$fail" -ne 0 ]; then echo "RECONCILE: FAIL (dead name)"; exit 1; fi
echo "RECONCILE: clean — names canonical, no new dim/verb"; exit 0
