#!/usr/bin/env bash
# vespio-sync.sh — one-way harness sync, one-ie -> apps/vespio.
#
# Vespio is an AGENCY repo (clients/, site/, web/, ai/, packages/). It is not
# the monorepo: no schema/, no pay/, no channels/, no text/ promise layer. So
# "sync everything" is the wrong instinct — most of one-ie's harness hard-asserts
# against a tree vespio does not have.
#
# THE AUTHORITY IS THE MANIFEST IN factory-repo.sh. It classifies every script
# AND every skill directory portable | needs-env | monorepo-only. This script
# reads that one manifest rather than keeping a second list that could drift
# from it. An UNCLASSIFIED script or skill does not ship — silence is never a
# licence.
#
# Skills were added to the manifest on 2026-09-21. Until then it classified
# scripts only and this script carried a hand-written SKILLS= list of six, so
# vespio had 7 skill directories out of 25 — and the skill list is the discovery
# surface a session reads before it builds. That list is gone; the manifest
# answers for skills exactly as it does for scripts.
#
#   bash .claude/scripts/vespio-sync.sh --check   # what's missing/drifted (read-only)
#   bash .claude/scripts/vespio-sync.sh           # copy, then show the diff
#   bash .claude/scripts/vespio-sync.sh --commit  # copy + commit (never pushes)
#
# Never pushes. Never stages by wildcard — every path is named. The 6 modified
# clients/*/data/lifecycles/*.toml in vespio belong to someone else's work and
# must never ride along in a sync commit.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# apps/vespio is a sibling of the MONOREPO, not of whatever tree this copy sits
# in. Run from .claude/worktrees/dev — which is where development happens, per
# ../CLAUDE.md § The dev -> prod loop — and `$ROOT/../apps/vespio` resolves to
# `.claude/worktrees/apps/vespio`, so this refused a repo that was right there
# with "no vespio repo at ...". The common git dir is shared by every worktree,
# so it names the primary tree no matter which one invoked this.
MAIN="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
MAIN="${MAIN:+$(dirname "$MAIN")}"
VESPIO="${VESPIO_ROOT:-${MAIN:-$ROOT}/../apps/vespio}"
MODE="${1:-}"

[ -d "$VESPIO/.git" ] || { echo "no vespio repo at $VESPIO"; exit 1; }

# ROOT is derived from BASH_SOURCE, so invoking this by a RELATIVE path from
# inside vespio resolves ROOT to vespio and syncs the tree onto itself. Assert
# the source is really one-ie before touching anything.
[ -f "$ROOT/schema/one.tql" ] || {
  echo "refusing: \$ROOT ($ROOT) is not the one-ie monorepo (no schema/one.tql)."
  echo "run this from /Users/toc/Server/one-ie, or by absolute path."
  exit 1
}
[ "$(cd "$ROOT" && pwd -P)" != "$(cd "$VESPIO" && pwd -P)" ] || {
  echo "refusing: source and destination are the same tree"; exit 1
}

# --- the shippable set, read from the single manifest ------------------------
# One list, two kinds of row: a name starting `skills/` is a directory under
# .claude/skills/, anything else is a path under .claude/scripts/.
_manifest_rows() {
  sed -n '/^manifest() {/,/^MANIFEST/p' "$ROOT/.claude/scripts/factory-repo.sh" \
    | grep -E '^(portable|needs-env) '
}
shippable() {
  _manifest_rows | awk '$2 !~ /^skills\// {print $2}' | sort
}
shippable_skills() {
  _manifest_rows | awk '$2 ~ /^skills\// {sub(/^skills\//, "", $2); print $2}' | sort
}
unclassified() {
  bash "$ROOT/.claude/scripts/factory-repo.sh" --check-portability 2>/dev/null \
    | sed -n 's/.*FAIL unclassified: //p' | sort
}

# Commands that make sense in an agency tree. Deliberately excluded and why:
#   deploy.md db-sync.md release.md  -> 5-service monorepo pipeline
#   one.md                           -> nine fleets over text/ docs vespio lacks
#   oo-push.md rag.md                -> monorepo-specific surfaces
COMMANDS="browser.md cc-connect.md chat.md close.md create.md do.md do-autonomous.md
          do-improve.md do-show.md go.md improve.md kill.md notify.md restart.md
          see.md skill-create.md sync.md"

copied=0; missing=0
say() { printf '  %-14s %s\n' "$1" "$2"; }

ship_one() { # ship_one <relpath under .claude>
  local rel="${1:-}"; [ -n "$rel" ] || return 0
  local src="$ROOT/.claude/$rel" dst="$VESPIO/.claude/$rel"
  [ -e "$src" ] || { say "ABSENT" "$rel"; missing=$((missing+1)); return; }
  if [ "$MODE" = "--check" ]; then
    if [ ! -e "$dst" ]; then say "MISSING" "$rel"; missing=$((missing+1))
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then say "DRIFTED" "$rel"; missing=$((missing+1)); fi
    return
  fi
  mkdir -p "$(dirname "$dst")"
  # A second run must be identical to the first. `cp -R src dst` NESTS when dst
  # already exists (dst/src), so a re-sync silently built skills/writer/writer.
  # Remove the destination first — this is a mirror, not an accumulation.
  rm -rf "$dst"
  # -L dereferences symlinks: .claude/skills/livekit-agents points outside the
  # tree and would land in vespio as a dangling link.
  cp -RL "$src" "$dst" && copied=$((copied+1))
}

echo "== vespio-sync  $ROOT -> $VESPIO"
un="$(unclassified)"
if [ -n "$un" ]; then
  echo "-- NOT SHIPPING (unclassified in the manifest — classify them to ship):"
  echo "$un" | sed 's/^/     /'
fi

echo "-- scripts (manifest: portable + needs-env)"
while read -r f; do [ -n "$f" ] && ship_one "scripts/$f"; done <<< "$(shippable)"

echo "-- rules"
for f in api.md astro.md design.md documentation.md engine.md react.md ui.md; do ship_one "rules/$f"; done

echo "-- agents"
for f in w1-recon.md w2-decide.md w3-edit.md w4-verify.md; do ship_one "agents/$f"; done

echo "-- commands"
for f in $COMMANDS; do ship_one "commands/$f"; done

# /vespio has TWO bodies: the monorepo-side one (sync + push, lives in
# .claude/commands/vespio.md here) and the vespio-side one (start the fleet).
# Shipping the monorepo body would tell a vespio clone to run vespio-sync.sh,
# which is monorepo-only and not there — a command that lies from inside the
# repo it ships to. So the REMOTE body is authored separately and mapped on.
ship_mapped() { # ship_mapped <src rel> <dst rel>
  local src="$ROOT/.claude/$1" dst="$VESPIO/.claude/$2"
  [ -f "$src" ] || { say "ABSENT" "$1"; missing=$((missing+1)); return; }
  if [ "$MODE" = "--check" ]; then
    if [ ! -e "$dst" ]; then say "MISSING" "$2"; missing=$((missing+1))
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then say "DRIFTED" "$2"; missing=$((missing+1)); fi
    return
  fi
  mkdir -p "$(dirname "$dst")"; rm -rf "$dst"; cp -L "$src" "$dst" && copied=$((copied+1))
}
ship_mapped "commands/vespio.remote.md" "commands/vespio.md"

# Skills come from the manifest, not from a list here. `monorepo-only` is the
# bucket that keeps a skill home — typedb (edits schema/*.tql), deploy (the
# 5-service pipeline), sdk/mcp/cli (edit packages/*/src), meeting (its first
# instruction is `cp text/template-meeting.md`). Everything else travels.
echo "-- skills (manifest: portable + needs-env)"
while read -r s; do [ -n "$s" ] && ship_one "skills/$s"; done <<< "$(shippable_skills)"

if [ "$MODE" = "--check" ]; then
  echo "== $missing item(s) missing or drifted"
  [ "$missing" -eq 0 ] && echo "   vespio is current." 
  exit 0
fi

echo "== copied $copied item(s)"
cd "$VESPIO"
echo "-- vespio diff (.claude only):"
git status --porcelain .claude | sed 's/^/     /'

if [ "$MODE" = "--commit" ]; then
  # explicit paths only — never `git add -A`. A neighbour's uncommitted
  # clients/*/lifecycles edits must not be swept into a harness sync.
  git add .claude
  if git diff --cached --quiet; then echo "nothing to commit"; exit 0; fi
  git commit -q -F - <<'MSG'
chore(claude): sync harness from one-ie

Manifest-driven — the shippable set, scripts AND skills alike, is read from
factory-repo.sh's portability manifest, not a second list. Unclassified
scripts and skills do not ship. Excluded by design: the 5-service deploy
pipeline and the skills whose primary artifact is schema/*.tql or
packages/*/src, none of which exist in this tree.
MSG
  echo "committed. Review, then push by hand: git -C $VESPIO push origin main"
fi
