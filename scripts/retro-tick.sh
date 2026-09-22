#!/usr/bin/env bash
# retro-tick.sh — the LOCAL half of the standing retro. No model call, no judgment.
#
# WHY THIS HALF CANNOT GO TO THE CLOUD: the corpus is ~/.claude/projects/*.jsonl on
# this Mac. A cloud agent has its own checkout and no access to this disk, so the
# MEASUREMENT is local by construction. This script does only the measuring and then
# commits the brief, which is what makes the cloud half possible: once the brief is in
# the repo, the judgment — deciding what to land, and where — runs anywhere.
#
# Deterministic end to end: retro.sh reads transcripts and prints counts. Nothing here
# decides anything, so it is safe to run unattended from cron or launchd.
#
#   bash .claude/scripts/retro-tick.sh              # measure, commit, push
#   bash .claude/scripts/retro-tick.sh --no-push    # commit only
#   bash .claude/scripts/retro-tick.sh --days 14
#
# Cron it (weekly, Monday 09:07 local — an off-minute on purpose):
#   7 9 * * 1 cd /Users/toc/Server/one-ie/.claude/worktrees/dev && \
#     bash .claude/scripts/retro-tick.sh >> /tmp/retro-tick.log 2>&1
set -uo pipefail

DAYS=7
PUSH=1
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="${2:-7}"; shift 2 ;;
    --no-push) PUSH=0; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

# The dev worktree, never the shared main tree — hook:dev-only refuses a write there,
# and a commit on main is not how this repo receives work (root CLAUDE.md § the loop).
GITDIR="$(git rev-parse --absolute-git-dir 2>/dev/null)"
case "$GITDIR" in
  */worktrees/*) : ;;
  *) echo "[retro-tick] REFUSING: $ROOT is the primary tree. Run from .claude/worktrees/dev." >&2
     exit 3 ;;
esac

BRANCH="$(git branch --show-current 2>/dev/null)"
STAMP="$(date -u +%Y-%m-%d)"
OUTDIR="text/retro"
OUT="$OUTDIR/$STAMP.md"
mkdir -p "$OUTDIR"

echo "[retro-tick] $(date -u +%Y-%m-%dT%H:%M:%SZ) · branch=$BRANCH · window=${DAYS}d"

bash .claude/scripts/retro.sh --days "$DAYS" --out "$OUT" >/dev/null
rc=$?
if [ $rc -ne 0 ] || [ ! -s "$OUT" ]; then
  echo "[retro-tick] RED: retro.sh exited $rc / brief empty — nothing committed." >&2
  exit 4
fi
LINES="$(wc -l < "$OUT" | tr -d ' ')"
# A brief that is all headings and no measurement is the failure mode retro.sh itself
# once had (--out lost every generated section and read as an empty retro). Refuse it
# here too: a short answer must say it is short, and this one would not.
if [ "$LINES" -lt 60 ]; then
  echo "[retro-tick] RED: brief is only $LINES lines — the sections did not render. Not committing." >&2
  exit 5
fi
echo "[retro-tick] brief: $OUT ($LINES lines)"

if git diff --quiet -- "$OUT" && ! git ls-files --others --exclude-standard --error-unmatch "$OUT" >/dev/null 2>&1; then
  echo "[retro-tick] brief unchanged since last tick — nothing to commit."
  exit 0
fi

# Stage by explicit path. A blanket add would sweep a neighbour session's work
# (.claude/CLAUDE.md § Don't, and hook:git-add-guard refuses it on main).
git add "$OUT" || exit 6
git -c user.name="Tony O'Connell" commit -q -m "retro($STAMP): the ${DAYS}-day brief

Measured by .claude/scripts/retro.sh — counts only, no judgment. What to land, and
in which auto-loading door, is the next session's call (§4 and §5 of the brief).

Nothing in this commit changes behaviour." -- "$OUT" || exit 7
echo "[retro-tick] committed $(git rev-parse --short HEAD)"

if [ "$PUSH" -eq 1 ]; then
  if git push origin "$BRANCH" 2>&1 | tail -2; then
    echo "[retro-tick] pushed $BRANCH — the cloud half can read the brief now"
  else
    echo "[retro-tick] push FAILED — brief is committed locally only" >&2
    exit 8
  fi
fi
exit 0
