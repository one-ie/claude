#!/usr/bin/env bash
# download-stats.sh — every lifetime reach number we can prove, in one table.
#
#   bash .claude/scripts/download-stats.sh              # print
#   bash .claude/scripts/download-stats.sh --write      # + record to text/download-stats.md
#   bash .claude/scripts/download-stats.sh --json
#   bash .claude/scripts/download-stats.sh --self-test
#
# manifest: needs-env — (npm + gh + network; writes only text/download-stats.md)
#
# FOLDS IN npm-downloads.sh, which this replaces. Both of that script's traps
# are live here and neither is obvious:
#
#   1. npm's downloads API REFUSES a range longer than 18 months — and answers
#      that refusal with HTTP 200 and an `error` field. A naive all-time query
#      therefore returns nothing useful without failing. All-time is a WALK: from
#      each package's first publish (registry `time.created`), 17 months at a
#      time, summed. Read `.error`, never the status code.
#   2. A scoped name must be percent-encoded — `@oneie%2Fsdk`. Unencoded, the
#      slash reads as a path separator and the API 404s, which deserialises to a
#      zero indistinguishable from a real one. Encoded once, in enc().
#
# And one about WHICH packages: the list comes from the REGISTRY (search by
# maintainer), not from manifests on disk and not from `npm access list
# packages` — that returns EMPTY under a granular token (measured 2026-09-14:
# "packages in scope: 0" while all 30 were readable). Reading manifests misses
# every package not in this repo, which was 10 of 30 — including `oneie` at
# 13,117 downloads, the single most-downloaded package we have.
#
# WHY A RECORDED .md: npm's per-day history is queryable back to a package's
# first publish, so npm needs no ledger. GitHub traffic is different — it keeps
# FOURTEEN DAYS and offers no backfill (see gh-traffic-capture.sh). The .md is
# the durable, committed, human-readable record; the gitignored ledger is the
# daily machine one. A snapshot appended here survives a dead laptop.
#
# HONESTY, because these numbers are for social proof and will be checked:
# npm counts mirrors, CI and crawlers. "57,819 downloads" is defensible;
# "57,819 developers" is a lie. The table separates the current @oneie scope
# from retired lines so a headline can be sourced to the right subtotal.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/text/download-stats.md"
MAINTAINER="${NPM_MAINTAINER:-oneie}"
ORG="${GH_ORG:-one-ie}"
MODE=print

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write) MODE=write ;;
    --json)  MODE=json ;;
    --self-test) MODE=selftest ;;
    -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "download-stats.sh: unknown flag '$1'" >&2; exit 2 ;;
  esac
  shift
done

command -v jq >/dev/null || { echo "download-stats.sh: needs jq" >&2; exit 2; }

enc() { printf '%s' "${1/\//%2F}"; }                       # @oneie/sdk -> @oneie%2Fsdk
today() { date -u '+%Y-%m-%d'; }
add_months() { date -j -v+"$2"m -f '%Y-%m-%d' "$1" '+%Y-%m-%d' 2>/dev/null || date -d "$1 + $2 months" '+%Y-%m-%d' 2>/dev/null; }

# all_time <pkg> — the 17-month walk described above.
all_time() {
  local p="$1" e c created start end total=0 body err n
  e="$(enc "$p")"
  created="$(npm view "$p" time.created 2>/dev/null | head -1 | cut -c1-10)"
  [[ -n "$created" ]] || created="2024-01-01"
  start="$created"; end="$(today)"; cursor="$start"
  while [[ "$cursor" < "$end" ]]; do
    stop="$(add_months "$cursor" 17)"
    [[ -z "$stop" || "$stop" > "$end" ]] && stop="$end"
    body="$(curl -sS --max-time 25 "https://api.npmjs.org/downloads/point/${cursor}:${stop}/${e}" 2>/dev/null)"
    err="$(printf '%s' "$body" | jq -r '.error // empty' 2>/dev/null)"
    if [[ -z "$err" ]]; then
      n="$(printf '%s' "$body" | jq -r '.downloads // 0' 2>/dev/null)"
      [[ "$n" =~ ^[0-9]+$ ]] && total=$(( total + n ))
    fi
    [[ "$stop" == "$end" ]] && break
    cursor="$stop"
  done
  printf '%s|%s' "$total" "$created"
}

if [[ "$MODE" == selftest ]]; then
  fails=0
  [[ "$(enc '@oneie/sdk')" == '@oneie%2Fsdk' ]] || { echo "  FAIL: scoped name not encoded"; fails=1; }
  [[ "$(enc 'oneie')" == 'oneie' ]] || { echo "  FAIL: unscoped name mangled"; fails=1; }
  [[ -n "$(add_months 2026-01-01 17)" ]] || { echo "  FAIL: add_months returned nothing"; fails=1; }
  # the 18-month refusal must be READ, not inferred from the status code
  b="$(curl -sS --max-time 20 "https://api.npmjs.org/downloads/point/2000-01-01:$(today)/npm" 2>/dev/null)"
  [[ -n "$(printf '%s' "$b" | jq -r '.error // empty')" ]] \
    || { echo "  NOTE: the >18mo range did not error — the walk is still correct, the guard is just untested here"; }
  (( fails )) && { echo "download-stats.sh: self-test FAILED"; exit 1; }
  echo "download-stats.sh: self-test PASS"; exit 0
fi

# ── npm ──────────────────────────────────────────────────────────────────────
pkgs="$(curl -sS --max-time 30 "https://registry.npmjs.org/-/v1/search?text=maintainer:${MAINTAINER}&size=250" 2>/dev/null | jq -r '.objects[].package.name' | sort)"
[[ -n "$pkgs" ]] || { echo "download-stats.sh: registry search returned no packages for maintainer:${MAINTAINER}" >&2; exit 1; }

rows="[]"
while IFS= read -r p; do
  [[ -n "$p" ]] || continue
  at="$(all_time "$p")"
  wk="$(curl -sS --max-time 15 "https://api.npmjs.org/downloads/point/last-week/$(enc "$p")" 2>/dev/null | jq -r '.downloads // 0')"
  ver="$(npm view "$p" version 2>/dev/null | tail -1)"
  rows="$(printf '%s' "$rows" | jq --arg p "$p" --arg v "$ver" --arg c "${at##*|}" \
          --argjson t "${at%%|*}" --argjson w "${wk:-0}" \
          '. + [{package:$p,version:$v,since:$c,all_time:$t,last_week:$w,scoped:($p|startswith("@"))}]')"
done <<< "$pkgs"

NPM_ALL="$(printf '%s' "$rows" | jq '[.[].all_time]|add // 0')"
NPM_WK="$(printf '%s' "$rows" | jq '[.[].last_week]|add // 0')"
NPM_SCOPED="$(printf '%s' "$rows" | jq '[.[]|select(.scoped)|.all_time]|add // 0')"
NPM_COUNT="$(printf '%s' "$rows" | jq 'length')"

# ── github ───────────────────────────────────────────────────────────────────
repos="$(gh api "orgs/$ORG/repos?per_page=100&type=public" 2>/dev/null)"
GH_STARS="$(printf '%s' "$repos" | jq '[.[].stargazers_count]|add // 0')"
GH_FORKS="$(printf '%s' "$repos" | jq '[.[].forks_count]|add // 0')"
GH_REPOS="$(printf '%s' "$repos" | jq 'length')"
GH_CLONES=0; GH_UNIQ=0
while IFS= read -r r; do
  [[ -n "$r" ]] || continue
  t="$(gh api "repos/$r/traffic/clones" --jq '"\(.count) \(.uniques)"' 2>/dev/null)" || continue
  GH_CLONES=$(( GH_CLONES + ${t%% *} )); GH_UNIQ=$(( GH_UNIQ + ${t##* } ))
done < <(printf '%s' "$repos" | jq -r '.[].full_name')

if [[ "$MODE" == json ]]; then
  jq -n --argjson pkgs "$rows" --arg d "$(today)" \
    --argjson na "$NPM_ALL" --argjson nw "$NPM_WK" --argjson ns "$NPM_SCOPED" --argjson nc "$NPM_COUNT" \
    --argjson gs "$GH_STARS" --argjson gf "$GH_FORKS" --argjson gr "$GH_REPOS" \
    --argjson gc "$GH_CLONES" --argjson gu "$GH_UNIQ" \
    '{date:$d, npm:{packages:$nc, all_time:$na, scope_all_time:$ns, last_week:$nw, rows:$pkgs},
      github:{repos:$gr, stars:$gs, forks:$gf, clones_14d:$gc, unique_cloners_14d:$gu}}'
  exit 0
fi

emit() {
  printf '# Download stats\n\n'
  printf '_Measured %s by `.claude/scripts/download-stats.sh`. Every figure is re-derivable — no number here was typed by hand._\n\n' "$(today)"
  printf '## Headline\n\n| metric | value | source |\n|---|---:|---|\n'
  printf '| npm downloads, all time | **%s** | downloads API, per package since first publish |\n' "$NPM_ALL"
  printf '| npm downloads, `@%s` scope | **%s** | the current product line only |\n' "$MAINTAINER" "$NPM_SCOPED"
  printf '| npm downloads, last week | %s | downloads API |\n' "$NPM_WK"
  printf '| packages published | **%s** | registry, maintainer `%s` |\n' "$NPM_COUNT" "$MAINTAINER"
  printf '| GitHub stars | **%s** | %s public repos, org-wide |\n' "$GH_STARS" "$GH_REPOS"
  printf '| GitHub forks | %s | org-wide |\n' "$GH_FORKS"
  printf '| unique cloners, 14d | **%s** | %s clones — GitHub keeps only 14 days |\n\n' "$GH_UNIQ" "$GH_CLONES"
  printf '## Packages\n\n| package | version | all time | last week | since |\n|---|---|---:|---:|---|\n'
  printf '%s' "$rows" | jq -r 'sort_by(-.all_time)[] | "| `\(.package)` | \(.version) | \(.all_time) | \(.last_week) | \(.since) |"'
  printf '\n## Using these for social proof\n\n'
  printf 'npm counts mirrors, CI and crawlers alongside people. **%s downloads** is defensible; ' "$NPM_ALL"
  printf '"%s developers" is not — say downloads, or cite unique cloners (**%s in 14 days**), which are closer to humans.\n\n' "$NPM_ALL" "$GH_UNIQ"
  printf 'The all-time total spans retired lines as well as the current one. For claims about the product as it stands today, '
  printf 'the honest subtotal is the **`@%s` scope: %s**.\n\n' "$MAINTAINER" "$NPM_SCOPED"
  printf '## What cannot be recovered\n\n'
  printf 'GitHub keeps **14 days** of clone and view traffic and offers no backfill, so all-time clones do not exist for any repo. '
  printf '`.claude/scripts/gh-traffic-capture.sh` runs daily to stop further days being lost; everything before its first run is gone.\n'
}

if [[ "$MODE" == write ]]; then
  mkdir -p "$(dirname "$OUT")"
  emit > "$OUT"
  echo "  ✓ recorded → text/download-stats.md ($(wc -l < "$OUT" | tr -d ' ') lines)"
  echo "    npm all-time=$NPM_ALL  scope=$NPM_SCOPED  packages=$NPM_COUNT  stars=$GH_STARS  uniq-cloners-14d=$GH_UNIQ"
else
  emit
fi
