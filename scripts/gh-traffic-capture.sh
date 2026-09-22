#!/usr/bin/env bash
# gh-traffic-capture.sh — keep GitHub traffic before GitHub throws it away.
#
#   bash .claude/scripts/gh-traffic-capture.sh                 # capture, default repos
#   bash .claude/scripts/gh-traffic-capture.sh --repo o/r       # one repo
#   bash .claude/scripts/gh-traffic-capture.sh --report         # read the ledger
#   bash .claude/scripts/gh-traffic-capture.sh --install-cron   # daily at 07:15
#   bash .claude/scripts/gh-traffic-capture.sh --self-test
#
# manifest: needs-env — (gh CLI + network; no repo state beyond its own ledger)
#
# WHY: /traffic/clones and /traffic/views return THE LAST 14 DAYS AND NOTHING
# ELSE. There is no backfill, no paging, no "all time" — a day that scrolls out
# of that window is gone from the API permanently. Measured 2026-09-14 on
# one-ie/one: the repo has existed since 2024-11-12 and the API could account
# for 14 days of it. Every day this does not run, a day is lost for good.
#
# THE MERGE IS THE WHOLE JOB, and it has one rule that is easy to get wrong:
# TODAY'S ROW IS PARTIAL. Capture at 07:15 and the day is a few hours old; the
# same date re-fetched tomorrow is larger and correct. So a merge must take the
# GREATER of stored and incoming per date — never "skip if the date exists"
# (freezes every day at its morning value) and never "last write wins" (a later
# call that drops a day to 0 would erase a real number). max() is the only
# rule that is right on the first write, the same-day rewrite, and the replay.
#
# Idempotent by construction: re-running an hour later, or ten times, converges.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA="${GH_TRAFFIC_DIR:-$ROOT/.claude/data/gh-traffic}"
REPOS=(); MODE=capture

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPOS+=("$2"); shift ;;
    --report) MODE=report ;;
    --install-cron) MODE=cron ;;
    --self-test) MODE=selftest ;;
    -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "gh-traffic-capture.sh: unknown flag '$1'" >&2; exit 2 ;;
  esac
  shift
done
# ENUMERATE THE ORG, never a hardcoded list. The first version of this script
# listed the seven subtree-mirror repos from the root CLAUDE.md table — and so
# it silently missed `ontology` (53 clones) and `astro-shadcn` (18 clones, 17
# uniques, 26 views), the org's second- and third-busiest repos. A capture that
# is blind to a repo loses that repo's history permanently, which is the one
# failure this script exists to prevent. A new repo joins the ledger by
# existing, not by someone remembering to add it here.
# GH_TRAFFIC_ORG overrides; --repo still pins an explicit set.
if (( ! ${#REPOS[@]} )); then
  while IFS= read -r r; do [[ -n "$r" ]] && REPOS+=("$r"); done < <(
    gh api "orgs/${GH_TRAFFIC_ORG:-one-ie}/repos?per_page=100&type=public" --jq '.[].full_name' 2>/dev/null
  )
  (( ${#REPOS[@]} )) || { echo "gh-traffic-capture.sh: could not enumerate org repos" >&2; exit 1; }
fi

command -v jq >/dev/null || { echo "gh-traffic-capture.sh: needs jq" >&2; exit 2; }
command -v gh >/dev/null || { echo "gh-traffic-capture.sh: needs the gh CLI" >&2; exit 2; }

mkdir -p "$DATA"

# merge_series <file> <key> <json-array of {timestamp,count,uniques}>
# max() per date, per the rule above.
merge_series() {
  local f="$1" key="$2" incoming="$3" tmp
  tmp="$(mktemp)"
  [[ -s "$f" ]] || printf '{"repo":"","clones":{},"views":{},"captured":[]}' > "$f"
  jq --arg k "$key" --argjson inc "$incoming" '
    .[$k] = ( (.[$k] // {}) as $have
      | reduce $inc[] as $d ($have;
          ($d.timestamp[0:10]) as $day
          | .[$day] = {
              count:   ([ (.[$day].count   // 0), ($d.count   // 0) ] | max),
              uniques: ([ (.[$day].uniques // 0), ($d.uniques // 0) ] | max)
            }
        ) )
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

capture_one() {
  # TWO statements, deliberately. `local repo="$1" f="$DATA/${repo//\//__}.json"`
  # expands EVERY word before it performs ANY assignment, so ${repo} there is
  # still unset: f became "$DATA/.json" and all seven repos shared one ledger.
  # The tell was subtle — the merge is max(), so the first repo's 163 clones
  # survived every later repo's zeros and each one reported 163.
  local repo="$1"
  local f="$DATA/${repo//\//__}.json"
  local c v
  c="$(gh api "repos/$repo/traffic/clones" --jq '.clones' 2>/dev/null)"
  v="$(gh api "repos/$repo/traffic/views"  --jq '.views'  2>/dev/null)"
  if [[ -z "$c" && -z "$v" ]]; then
    echo "  ! $repo — no traffic data (needs push access on that repo)" >&2
    return 1
  fi
  [[ -s "$f" ]] || printf '{"repo":"%s","clones":{},"views":{},"captured":[]}' "$repo" > "$f"
  [[ -n "$c" && "$c" != "null" ]] && merge_series "$f" clones "$c"
  [[ -n "$v" && "$v" != "null" ]] && merge_series "$f" views  "$v"
  local tmp; tmp="$(mktemp)"
  jq --arg r "$repo" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.repo=$r | .captured = ((.captured // []) + [$t] | .[-200:])' "$f" > "$tmp" && mv "$tmp" "$f"
  local days tot
  days="$(jq '(.clones|length)' "$f")"; tot="$(jq '[.clones[].count]|add // 0' "$f")"
  printf '  ✓ %-22s %s day(s) kept · %s clones total\n' "$repo" "$days" "$tot"
}

case "$MODE" in
  capture)
    echo "── capturing GitHub traffic → $DATA"
    rc=0; for r in "${REPOS[@]}"; do capture_one "$r" || rc=1; done
    exit $rc ;;

  report)
    printf '\n  %-24s %8s %9s %8s %9s   %s\n' "REPO" "CLONES" "UNIQ" "VIEWS" "UNIQ" "DAYS KEPT"
    printf '  %s\n' "$(printf '─%.0s' {1..76})"
    for f in "$DATA"/*.json; do
      [[ -e "$f" ]] || { echo "  (ledger empty — run a capture first)"; break; }
      jq -r '"  \(.repo[0:24] + "                        "|.[0:24]) \([.clones[].count]|add // 0|tostring|(("        "+.)|.[-8:])) \([.clones[].uniques]|add // 0|tostring|(("         "+.)|.[-9:])) \([.views[].count]|add // 0|tostring|(("        "+.)|.[-8:])) \([.views[].uniques]|add // 0|tostring|(("         "+.)|.[-9:]))   \(.clones|length)"' "$f"
    done
    printf '\n  NOTE: totals are what THIS LEDGER has kept, not GitHub all-time —\n'
    printf '  anything before the first capture was already unrecoverable.\n\n' ;;

  cron)
    line="15 7 * * * cd $ROOT && /bin/bash .claude/scripts/gh-traffic-capture.sh >> $DATA/cron.log 2>&1"
    if crontab -l 2>/dev/null | grep -qF 'gh-traffic-capture.sh'; then
      echo "  already installed:"; crontab -l 2>/dev/null | grep -F 'gh-traffic-capture.sh' | sed 's/^/    /'
    else
      ( crontab -l 2>/dev/null; echo "$line" ) | crontab - \
        && echo "  ✓ installed — daily 07:15" && crontab -l | grep -F 'gh-traffic' | sed 's/^/    /'
    fi
    echo "  NOTE: cron only fires while this Mac is awake. A missed day is still"
    echo "  recoverable for 14 days — that is the window, and the reason for daily." ;;

  selftest)
    # The merge is the only logic worth proving, and the property is max().
    d="$(mktemp -d)"; f="$d/t.json"; fails=0
    printf '{"repo":"x","clones":{},"views":{},"captured":[]}' > "$f"
    merge_series "$f" clones '[{"timestamp":"2026-09-01T00:00:00Z","count":5,"uniques":2}]'
    [[ "$(jq -r '.clones["2026-09-01"].count' "$f")" == "5" ]] || { echo "  FAIL: first write"; fails=1; }
    # same day, larger (the partial-today case) -> must grow
    merge_series "$f" clones '[{"timestamp":"2026-09-01T00:00:00Z","count":9,"uniques":4}]'
    [[ "$(jq -r '.clones["2026-09-01"].count' "$f")" == "9" ]] || { echo "  FAIL: partial day did not grow"; fails=1; }
    # same day, smaller (a late/rescoped answer) -> must NOT shrink
    merge_series "$f" clones '[{"timestamp":"2026-09-01T00:00:00Z","count":1,"uniques":1}]'
    [[ "$(jq -r '.clones["2026-09-01"].count' "$f")" == "9" ]] || { echo "  FAIL: a smaller number overwrote a larger one"; fails=1; }
    # a day older than the 14d window must survive a capture that omits it
    merge_series "$f" clones '[{"timestamp":"2026-09-02T00:00:00Z","count":3,"uniques":1}]'
    [[ "$(jq -r '.clones|length' "$f")" == "2" ]] || { echo "  FAIL: an out-of-window day was dropped"; fails=1; }
    rm -rf "$d"
    (( fails )) && { echo "gh-traffic-capture.sh: self-test FAILED"; exit 1; }
    echo "gh-traffic-capture.sh: self-test PASS (grows, never shrinks, never forgets)" ;;
esac
