#!/bin/bash
# DO-DOC-CHECK — When a new text/*-todo.md is Written, check the feature's doc spine.
#
# Promise-aware: when text/<slug>.md (the genesis promise) exists and declares a
# derives: manifest, every key set true maps to one artifact file that must exist
# (plan → text/<slug>-plan.md … agents → text/<slug>-agents-docs.md; tests is
# skipped — its path varies by repo folder). Warns listing ONLY the missing ones.
# No promise file → the legacy <slug>-docs.md check runs unchanged, plus a warn
# that the genesis itself is missing.
#
# Fires: PostToolUse/Write (new file creation only — not Edit, so it doesn't
# fire on every checkbox tick during a loop run).
# Non-blocking (exit 0) — reminds Claude to seed the missing artifacts before BUILD starts.
# Emits hook:do-doc-check:{ok,warn} per Rule 1.

# shellcheck source=lib/signal.sh
source "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR:-.}/.claude}/hooks/lib/signal.sh"

TOOL=$(echo "$1" | jq -r '.tool // empty' 2>/dev/null)
FILE=$(echo "$1" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only fire when a file is Written (not Edited — avoids noise on checkbox ticks)
[ "$TOOL" = "Write" ] || exit 0

# Only fire for text/*-todo.md
case "$FILE" in
  */text/*-todo.md) ;;
  *) exit 0 ;;
esac

BASENAME=$(basename "$FILE")
SLUG="${BASENAME%-todo.md}"
DIR=$(dirname "$FILE")
PROMISE_FILE="$DIR/${SLUG}.md"

# ── Promise-aware path: text/<slug>.md exists and declares derives: ─────────
if [ -f "$PROMISE_FILE" ]; then
  # derives: block inside YAML frontmatter only (body prose may mention "derives:")
  HAS_DERIVES=$(awk '
    BEGIN { fm=0 }
    /^---[[:space:]]*$/ { fm++; if (fm==2) exit; next }
    fm==1 && /^derives:/ { print "yes"; exit }
  ' "$PROMISE_FILE")

  if [ "$HAS_DERIVES" = "yes" ]; then
    # Keys set true inside the derives: block. The block ends at the next
    # column-0 line (comment, next key, or frontmatter close).
    TRUE_KEYS=$(awk '
      BEGIN { fm=0; in_d=0 }
      /^---[[:space:]]*$/ { fm++; if (fm==2) exit; next }
      fm != 1 { next }
      /^derives:/ { in_d=1; next }
      in_d && /^[^[:space:]]/ { in_d=0 }
      in_d && /^[[:space:]]+[a-z-]+:[[:space:]]*true([[:space:]]|$)/ {
        key=$1; sub(/:$/, "", key); print key
      }
    ' "$PROMISE_FILE")

    MISSING=""
    for KEY in $TRUE_KEYS; do
      case "$KEY" in
        plan)      TARGET="${SLUG}-plan.md" ;;
        todo)      TARGET="${SLUG}-todo.md" ;;
        docs)      TARGET="${SLUG}-docs.md" ;;
        tutorial)  TARGET="${SLUG}-tutorial.md" ;;
        how-to)    TARGET="${SLUG}-how-to.md" ;;
        reference) TARGET="${SLUG}-reference.md" ;;
        features)  TARGET="${SLUG}-features.md" ;;
        ui)        TARGET="${SLUG}-ui.md" ;;
        agents)    TARGET="${SLUG}-agents-docs.md" ;;
        tests)     continue ;;  # test path varies by repo folder — not checked here
        *)         continue ;;  # unknown key — ignore, never guess a path
      esac
      [ -f "$DIR/$TARGET" ] || MISSING="${MISSING} text/${TARGET}"
    done

    if [ -n "$MISSING" ]; then
      MISSING_N=$(printf '%s' "$MISSING" | wc -w | awk '{print $1}')
      echo "do-doc-check: text/${SLUG}.md derives: marks artifacts true that are missing:${MISSING} — seed them before BUILD starts" >&2
      emit_signal "hook:do-doc-check:warn" -0.5 "slug=$SLUG missing=$MISSING_N"
    else
      emit_signal "hook:do-doc-check:ok" 1 "slug=$SLUG derives=complete"
    fi
    exit 0
  fi
fi

# ── Fallback: no promise (or promise without derives:) — legacy behavior ────
GENESIS_NOTE=""
if [ ! -f "$PROMISE_FILE" ]; then
  echo "do-doc-check: text/${SLUG}.md (the genesis promise) is missing — every feature starts as a promise (proof: + derives:); cp text/template-feature.md text/${SLUG}.md" >&2
  GENESIS_NOTE=" promise=missing"
fi

DOC_FILE="$DIR/${SLUG}-docs.md"
if [ ! -f "$DOC_FILE" ]; then
  echo "do-doc-check: text/${SLUG}-docs.md is missing — seed it now (writer skill, initial draft: for whom · what ships · usage sketch)" >&2
  emit_signal "hook:do-doc-check:warn" -0.5 "slug=$SLUG$GENESIS_NOTE"
elif [ -n "$GENESIS_NOTE" ]; then
  emit_signal "hook:do-doc-check:warn" -0.5 "slug=$SLUG$GENESIS_NOTE"
else
  emit_signal "hook:do-doc-check:ok" 1 "slug=$SLUG"
fi

exit 0
