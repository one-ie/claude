#!/usr/bin/env bash
# Publish the harness skills in .claude/skills/ into the substrate catalog, so the
# skills /do actually uses are reachable through `skill:run` and `skills:list`
# instead of only as local files an agent must already be on this disk to read.
#
# The two on-disk shapes map 1:1 onto the two shapes db/skills.ts already reads:
#   .claude/skills/<name>/SKILL.md  ->  R2  <slug>/skills/<name>/SKILL.md
#   .claude/skills/<name>.md        ->  R2  <slug>/skills/<name>.md
# So this is a copy, not a conversion — nothing here reformats a skill body.
#
# The SECOND source is the shared skill library in one.ie/ai/skills/, which is what
# an executor actually runs — `foundation:deep` loads each elevate-foundation-*
# SKILL.md through getSkillOrRef, so a skill that is on disk but not in R2 makes the
# run fail closed (`skill_not_found:<name>`). Same copy, same key shape:
#   one.ie/ai/skills/<name>/SKILL.md -> R2  <slug>/skills/<name>/SKILL.md
#
# That dir holds 140+ skills, so it is filtered by --ai-pattern rather than published
# wholesale: a routine run of this script must not silently push the whole library to
# prod R2. The default covers exactly the 10 skills in deep-sequence.ts SKILL_ORDER.
#
# Usage:
#   skills-publish.sh [--slug one] [--dry-run] [--bucket one-content]
#                     [--ai-pattern 'elevate-foundation-*'] [--no-ai]
#
# Re-running is safe: an R2 put is a full overwrite of one key, and the catalog is
# keyed by name, so a republished skill replaces itself rather than accumulating.
# Deletions are NOT mirrored — a skill removed from disk stays in the catalog until
# it is deleted deliberately, because unpublishing is a decision, not a side effect.
set -euo pipefail

SLUG="one"
BUCKET="one-content"
DRY=false
AI_PATTERN='elevate-foundation-*'
AI=true
while [ $# -gt 0 ]; do
  case "$1" in
    --slug)   SLUG="$2"; shift 2 ;;
    --bucket) BUCKET="$2"; shift 2 ;;
    --ai-pattern) AI_PATTERN="$2"; shift 2 ;;
    --no-ai)  AI=false; shift ;;
    --dry-run) DRY=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS="$_ROOT/.claude/skills"
AI_SKILLS="$_ROOT/one.ie/ai/skills"
[ -d "$SKILLS" ] || { echo "no skills dir at $SKILLS" >&2; exit 1; }

# wrangler resolves its account from one.ie/web's config; run from there.
cd "$_ROOT/one.ie/web"

ok=0; fail=0; failed=""

_put() { # <r2-key> <local-file>
  if [ "$DRY" = true ]; then echo "DRY  $1"; ok=$((ok + 1)); return 0; fi
  # Output captured, then matched — never `| grep -q`. In a pipefail script a
  # matching grep exits first and the producer takes SIGPIPE, which reads as a
  # failure on success (see .claude/CLAUDE.md § TRAP).
  local out
  if out=$(npx wrangler r2 object put "$BUCKET/$1" --file="$2" --remote 2>&1); then
    ok=$((ok + 1))
  else
    fail=$((fail + 1)); failed="$failed $1"
    printf '%s\n' "$out" | tail -2 >&2
  fi
}

for d in "$SKILLS"/*/; do
  [ -f "$d/SKILL.md" ] || continue
  _put "$SLUG/skills/$(basename "$d")/SKILL.md" "$d/SKILL.md"
done

for f in "$SKILLS"/*.md; do
  [ -f "$f" ] || continue
  _put "$SLUG/skills/$(basename "$f")" "$f"
done

ai=0
if [ "$AI" = true ] && [ -d "$AI_SKILLS" ]; then
  for d in "$AI_SKILLS"/$AI_PATTERN/; do
    [ -f "$d/SKILL.md" ] || continue
    _put "$SLUG/skills/$(basename "$d")/SKILL.md" "$d/SKILL.md"
    ai=$((ai + 1))
  done
  if [ "$ai" -eq 0 ]; then
    echo "skills-publish: WARNING no ai/skills matched --ai-pattern '$AI_PATTERN'" >&2
  fi
fi

echo "skills-publish: $ok published ($ai from ai/skills), $fail failed (slug=$SLUG bucket=$BUCKET)"
[ "$fail" -eq 0 ] || { echo "failed:$failed" >&2; exit 1; }
