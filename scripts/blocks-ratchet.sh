#!/usr/bin/env bash
# blocks-ratchet — the block-registry CENSUS REPORTER.
#
# NO CEILING IS ENFORCED. Owner directive, 2026-08-20: "you can add as many
# blocks as necessary. remove the 130 cap. remove any ceiling." Both gates this
# script used to hold — (1) count <= --max, (2) count <= the integer in
# one.ie/web/src/lib/puck/.blocks-baseline — are GONE. It counts, it prints,
# and it ALWAYS EXITS 0, including when it cannot count at all.
#
# The name is kept because callers grep for it; it is no longer a ratchet.
# `--max` and `--update` are still accepted so no caller breaks:
#   --max N    reported for context, NEVER enforced
#   --update   writes the current count to .blocks-baseline as a plain census
#              record. It moves in EITHER direction now — the old "only ever
#              lower" rule is part of the removed ratchet.
# The superseding contract for growing the registry is text/blocks-restore.md.
# text/blocks.md's registry-ceiling deliverable is superseded (see its dated
# 2026-08-20 note); nothing else in that promise changed.
#
# Count source: the same tsx-import trick as blocks-usage.mjs's
# readRegisteredNames() (.claude/scripts/blocks-usage.mjs:40-53) — a temp
# .mjs that imports puckConfig from config.tsx by absolute path and prints
# Object.keys(puckConfig.components), run with `bunx tsx` from one.ie/web.
# NEVER a grep over config.tsx — a grep counts source lines, not what Puck
# actually registers after collapseFamilies.
#
# TRAP (.claude/CLAUDE.md): under `set -o pipefail`, `<producer> | grep -q`
# can SIGPIPE the producer (exit 141) when grep matches early. Never pipe
# the count command into grep — capture its stdout to a variable first,
# then match with a here-string.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_DIR="$REPO_ROOT/one.ie/web"
CONFIG_PATH="$WEB_DIR/src/lib/puck/config.tsx"
BASELINE_PATH="$WEB_DIR/src/lib/puck/.blocks-baseline"

MAX=160
UPDATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --max)
      MAX="$2"
      shift 2
      ;;
    --max=*)
      MAX="${1#--max=}"
      shift
      ;;
    --update)
      UPDATE=1
      shift
      ;;
    *)
      # A census reporter never fails a caller. Say it loudly, carry on.
      echo "blocks-ratchet: ignoring unknown argument: $1" >&2
      shift
      ;;
  esac
done

if [ -f "$BASELINE_PATH" ]; then
  BASELINE="$(tr -d '[:space:]' < "$BASELINE_PATH")"
else
  BASELINE=""
fi

# A census that cannot count says so — loudly, on stderr, and still exits 0.
# The likely cause is a config.tsx mid-edit in another window, which is not a
# verdict about the registry.
if [ ! -f "$CONFIG_PATH" ]; then
  echo "blocks-ratchet census: UNAVAILABLE — config.tsx not found at $CONFIG_PATH"
  echo "blocks-ratchet ok: no ceiling — census only (owner directive 2026-08-20)"
  exit 0
fi

TMPDIR_RUN="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RUN"' EXIT

RUNNER="$TMPDIR_RUN/names.mjs"
cat > "$RUNNER" <<EOF
import { puckConfig } from $(node -e "console.log(JSON.stringify(process.argv[1]))" "$CONFIG_PATH")
console.log(JSON.stringify(Object.keys(puckConfig.components)))
EOF

# Capture producer output to a variable BEFORE any matching — never pipe
# this command directly into grep under set -o pipefail (SIGPIPE trap).
# stderr goes to a file, never merged into stdout: bun writes "Resolving
# dependencies" there, and merging it corrupts the JSON this parses.
ERRLOG="$TMPDIR_RUN/err.log"
if ! NAMES_JSON="$(cd "$WEB_DIR" && bunx tsx "$RUNNER" 2>"$ERRLOG")"; then
  echo "blocks-ratchet census: UNAVAILABLE — config.tsx did not import"
  cat "$ERRLOG" >&2
  echo "blocks-ratchet ok: no ceiling — census only (owner directive 2026-08-20)"
  exit 0
fi

# The name list is the LAST line — a cold bun can print install chatter first.
NAMES_LINE="$(printf '%s\n' "$NAMES_JSON" | tail -n 1)"

if ! COUNT="$(node -e "console.log(JSON.parse(process.argv[1]).length)" "$NAMES_LINE" 2>"$ERRLOG")"; then
  echo "blocks-ratchet census: UNAVAILABLE — the registry did not print a name list"
  cat "$ERRLOG" >&2
  echo "blocks-ratchet ok: no ceiling — census only (owner directive 2026-08-20)"
  exit 0
fi

# The census record. Moves in either direction; it gates nothing.
if [ "$UPDATE" -eq 1 ]; then
  printf '%s' "$COUNT" > "$BASELINE_PATH"
  BASELINE="$COUNT"
fi

echo "blocks-ratchet census: count=$COUNT max=$MAX (not enforced) baseline=${BASELINE:-none} (record, not a gate)"
echo "blocks-ratchet ok: no ceiling — census only (owner directive 2026-08-20)"
