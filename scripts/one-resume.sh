#!/usr/bin/env bash
# one-resume.sh — the board, for a harness picking up someone else's fleets.
#
#   bash .claude/scripts/one-resume.sh            # print the board
#   bash .claude/scripts/one-resume.sh --deploy   # board, then land+ship what is ready
#
# Zero model tokens. It reads the workflow journals and git, and tells you which
# fleets finished, which are mid-flight, which branches are ready to land, and
# the exact Workflow({scriptPath, resumeFromRunId}) call to continue each one.
#
# WHY: a session that runs out of credits must not lose its fleets. Every run
# persists a script and a journal; a resume replays unchanged agents from CACHE
# for free and only re-runs what changed. The expensive mistake is re-launching a
# fleet whose work already landed — so this prints the branch state next to it.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1
DEPLOY=0
for a in "$@"; do case "$a" in --deploy) DEPLOY=1 ;; -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}"; exit 0 ;; esac; done

GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
[[ -t 1 ]] || { GRN=""; YEL=""; DIM=""; OFF=""; }

PROJ="$HOME/.claude/projects"
echo "${DIM}══ fleets ══${OFF}"

# One journal per run: {"type":"started"} / {"type":"result"} lines.
found=0
while IFS= read -r j; do
  [[ -f "$j" ]] || continue
  run="$(basename "$(dirname "$j")")"
  read -r done total < <(python3 - "$j" <<'PY'
import json,sys
s=e=0
for line in open(sys.argv[1]):
    try: t=json.loads(line).get("type")
    except Exception: continue
    s += t=="started"; e += t=="result"
print(e, s)
PY
)
  [[ "${total:-0}" == "0" ]] && continue
  found=1
  state="in flight"; mark="$YEL"
  [[ "$done" == "$total" ]] && { state="DONE"; mark="$GRN"; }
  script="$(ls -t "$PROJ"/*/*/workflows/scripts/*"${run#wf_}"* 2>/dev/null | head -1)"
  printf '%s  %-22s %s%s%s  %s/%s agents\n' "$mark" "$run" "$mark" "$state" "$OFF" "$done" "$total"
  [[ -n "$script" ]] && printf '     resume: Workflow({scriptPath: "%s", resumeFromRunId: "%s"})\n' "$script" "$run"
done < <(find "$PROJ" -path '*/subagents/workflows/wf_*/journal.jsonl' -mtime -3 2>/dev/null)
(( found )) || echo "  (no workflow journals in the last 3 days)"

echo
echo "${DIM}══ branches ══${OFF}"
# WHY the yardstick is `dev` and not `main`:
#   land.sh merges a branch into TRUNK, and TRUNK is `dev` (land.sh:117 —
#   "TRUNK is what a branch LANDS INTO; PR_BASE is what dev is RELEASED into").
#   Measuring "ready to land" against main therefore counts every commit that
#   is ALREADY INTEGRATED on dev and merely waiting on the dev->main PR, and
#   reports it as unlanded work. Measured 2026-09-15: feat/dashboard,
#   feat/fix-og-screenshot-fullpage and feat/tasks-bulk each read
#   "38 / 20 / 11 commit(s) ready to land" while all three were 0 ahead of
#   origin/dev and already merged — and `--deploy` would have re-run land.sh
#   on all three. This is the same stale-yardstick class as do-auto.sh --gc,
#   but the opposite direction: --gc measures against main and KEEPS too much
#   (safe); this INVENTED work (unsafe), and re-launching landed work is the
#   most expensive mistake the board offers.
# Remote refs first: a local `main`/`dev` can sit hundreds of commits behind
#   origin while `git status` reports the tree clean.
_ref() { git rev-parse --verify -q "origin/$1" >/dev/null 2>&1 && echo "origin/$1" || echo "$1"; }
TRUNK_REF="$(_ref "${LAND_TRUNK:-dev}")"   # what a branch lands INTO
BASE_REF="$(_ref main)"                    # what dev is RELEASED into
READY=()
while IFS= read -r br; do
  [[ -z "$br" ]] && continue
  ahead="$(git rev-list --count "$TRUNK_REF..$br" 2>/dev/null || echo 0)"
  if [[ "$ahead" == "0" ]]; then
    printf '  %-34s %sno commits beyond %s%s\n' "$br" "$DIM" "$TRUNK_REF" "$OFF"
  else
    printf '  %-34s %s%s commit(s) ready to land%s %s(-> %s)%s\n' \
      "$br" "$GRN" "$ahead" "$OFF" "$DIM" "$TRUNK_REF" "$OFF"
    READY+=("$br")
  fi
done < <(git for-each-ref --format='%(refname:short)' --sort=-committerdate refs/heads/feat 2>/dev/null | head -20)

# The other half of the loop: what is integrated but not yet released.
rel="$(git rev-list --count "$BASE_REF..$TRUNK_REF" 2>/dev/null || echo 0)"
if [[ "$rel" != "0" ]]; then
  printf '\n  %-34s %s%s commit(s) ready to release%s %s(%s -> %s, by PR)%s\n' \
    "${LAND_TRUNK:-dev}" "$YEL" "$rel" "$OFF" "$DIM" "$TRUNK_REF" "$BASE_REF" "$OFF"
fi

echo
echo "${DIM}══ next ══${OFF}"
if (( ${#READY[@]} )); then
  echo "  bash .claude/scripts/land.sh ${READY[*]} --deploy"
elif [[ "$rel" != "0" ]]; then
  echo "  gh pr create --base main --head ${LAND_TRUNK:-dev}   # $rel commit(s) integrated, not released"
else
  echo "  nothing to land yet — resume a fleet above, or ./deploy dev"
fi
echo "  read text/HANDOFF.md BEFORE spawning anything new"

if (( DEPLOY )) && (( ${#READY[@]} )); then
  echo
  bash "$ROOT/.claude/scripts/land.sh" "${READY[@]}" --deploy
fi
