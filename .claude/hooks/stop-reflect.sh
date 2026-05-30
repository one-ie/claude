#!/usr/bin/env bash
# STOP-REFLECT — capture session learnings while context is fresh.
#
# Runs on Stop alongside session-end-verify. Non-blocking.
# Scans the session's git delta for signals of new conventions and appends
# proposals to .claude/improvements.queue.md for batch review.
#
# Heuristics (intentionally conservative — false positives = noise):
#   1. CLAUDE.md / rules / skills changed → record the change as a candidate
#      convention for upstream propagation.
#   2. Code touched but no doc touched in same family → flag for doc-drift.
#   3. New file created under .claude/skills/ or .claude/rules/ → flag as new
#      primitive (likely deserves a one-line README mention).
#
# Per Rule 1 (closed loop) — emits hook:stop-reflect:{ok,warn} with counts.
# shellcheck source=lib/signal.sh
source "$CLAUDE_PROJECT_DIR/.claude/hooks/lib/signal.sh"

cd "$CLAUDE_PROJECT_DIR" || exit 0

QUEUE="$CLAUDE_PROJECT_DIR/.claude/improvements.queue.md"
mkdir -p "$(dirname "$QUEUE")"

# What changed this session? Use unstaged + staged + untracked.
CHANGED=$(git status --porcelain 2>/dev/null | awk '{print $2}')
[ -z "$CHANGED" ] && { emit_signal "hook:stop-reflect:ok" 1 "changed=0"; exit 0; }

# Header for this session's block (idempotent — appends if file exists)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PROPOSALS=0

# Buffer proposals; only write if non-empty
BUF=""

# (1) Convention-bearing files
CONVENTION_HITS=$(echo "$CHANGED" | grep -E '(CLAUDE\.md$|\.claude/rules/|\.claude/skills/|\.claude/agents/)' || true)
if [ -n "$CONVENTION_HITS" ]; then
  while IFS= read -r f; do
    BUF+="- **convention** \`$f\` — review: did this change introduce a rule the broader team should know? If yes, surface it in root \`CLAUDE.md\` or the relevant skill.\n"
    PROPOSALS=$((PROPOSALS + 1))
  done <<< "$CONVENTION_HITS"
fi

# (2) New primitives (untracked files in .claude/)
NEW_PRIMITIVES=$(echo "$CHANGED" | grep -E '^\.claude/(skills|rules|agents|hooks)/[^/]+\.(md|sh)$' | while read -r f; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || echo "$f"
done)
if [ -n "$NEW_PRIMITIVES" ]; then
  while IFS= read -r f; do
    BUF+="- **new primitive** \`$f\` — add a one-line entry to the index (\`.claude/CLAUDE.md\` or root README skills table).\n"
    PROPOSALS=$((PROPOSALS + 1))
  done <<< "$NEW_PRIMITIVES"
fi

# (3) Doc drift — code touched in a family but no doc touched
#    Family map: agents/src ↔ agents/CLAUDE.md, packages/sdk/src ↔ packages/sdk/CLAUDE.md,
#                one.ie/web/src ↔ one.ie/web/CLAUDE.md
check_drift() {
  local code_glob="$1"; local doc_file="$2"
  local code_changed
  code_changed=$(echo "$CHANGED" | grep -E "$code_glob" || true)
  if [ -n "$code_changed" ] && ! echo "$CHANGED" | grep -qF "$doc_file"; then
    local count
    count=$(echo "$code_changed" | wc -l | awk '{print $1}')
    if [ "$count" -ge 3 ]; then
      BUF+="- **doc-drift** \`$doc_file\` not updated despite $count file changes under \`$code_glob\`. Review.\n"
      PROPOSALS=$((PROPOSALS + 1))
    fi
  fi
}
check_drift '^agents/src/'         'agents/CLAUDE.md'
check_drift '^packages/sdk/src/'   'packages/sdk/CLAUDE.md'
check_drift '^one\.ie/web/src/'    'one.ie/web/CLAUDE.md'
check_drift '^api/src/'            'api/CLAUDE.md'

# (4) Completed /do cycle → suggest /skill-create to crystallise the pattern.
# Heuristic: learnings.md was touched AND W3 edited >=3 non-plan/non-text files.
if echo "$CHANGED" | grep -qF 'plans/learnings.md'; then
  CYCLE_FILES=$(echo "$CHANGED" | grep -vE '^plans/|^text/|^\.claude/' | wc -l | awk '{print $1}')
  if [ "$CYCLE_FILES" -ge 3 ]; then
    # Extract the cycle slug from the last learnings entry
    CYCLE_SLUG=$(grep -oE 'cycle [0-9]+|· [a-z][a-z0-9-]+' plans/learnings.md 2>/dev/null | tail -1 | sed 's/^· //')
    BUF+="- **skill-create** cycle closed with ${CYCLE_FILES} file(s) changed — run \`/skill-create ${CYCLE_SLUG}\` to crystallise the pattern as a reusable skill.\n"
    PROPOSALS=$((PROPOSALS + 1))
  fi
fi

# Only write the file if we found something worth reviewing
if [ "$PROPOSALS" -gt 0 ]; then
  {
    echo ""
    echo "## $TS"
    printf "%b" "$BUF"
  } >> "$QUEUE"

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│ STOP-REFLECT: $PROPOSALS proposal(s) queued                          │"
  echo "│ Review: .claude/improvements.queue.md                       │"
  echo "└─────────────────────────────────────────────────────────────┘"

  emit_signal "hook:stop-reflect:warn" 0.5 "proposals=$PROPOSALS"
else
  emit_signal "hook:stop-reflect:ok" 1 "changed=$(echo "$CHANGED" | wc -l | awk '{print $1}') proposals=0"
fi

exit 0
