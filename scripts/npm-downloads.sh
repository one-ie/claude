#!/usr/bin/env bash
# npm-downloads.sh — all-time download counts for every @oneie package.
#
#   bash .claude/scripts/npm-downloads.sh            # table, all time
#   bash .claude/scripts/npm-downloads.sh --json     # machine-readable
#   bash .claude/scripts/npm-downloads.sh --since 2026-01-01
#   bash .claude/scripts/npm-downloads.sh --scope @other
#
# manifest: needs-env  (network + jq; no repo state, no credentials)
#                      Keyword normalised from `portability:` 2026-09-21 — seven
#                      sibling scripts say `manifest:`; one spelling, one habit.
#
# WHY THIS IS NOT ONE CURL: npm's downloads API answers `last-day`, `last-week`
# and `last-month`, and for anything else a date range — but it REFUSES a range
# longer than 18 months (`{"error":"...exceeds maximum of 18 months"}`), and it
# answers that with HTTP 200. So "all time" is a WALK: start at the package's
# first publish (registry `time.created`), step in 17-month windows, and sum.
# A single wide range does not error loudly, it just returns nothing useful.
#
# THE SCOPED-NAME TRAP: `@oneie/sdk` must be percent-encoded as `@oneie%2Fsdk`
# in the downloads API path. Unencoded, the `/` reads as a path separator and
# the API returns a 404 that looks exactly like "this package has no downloads"
# — a zero you would believe. Encoded here, once.
#
# A package published days ago legitimately reads 0. That is not a failure, and
# it is reported as 0 with its first-publish date beside it so the number can be
# read in context rather than mistaken for a broken query.
set -uo pipefail

SCOPE="@oneie"; JSON=0; SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)  JSON=1 ;;
    --scope) SCOPE="$2"; shift ;;
    --since) SINCE="$2"; shift ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "npm-downloads.sh: unknown flag '$1'" >&2; exit 2 ;;
  esac
  shift
done

command -v jq >/dev/null || { echo "npm-downloads.sh: needs jq" >&2; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The package list comes from the workspace, not from `npm access list packages`
# — that command returns nothing for a granular token whose scope is per-package
# (measured 2026-09-14: "packages in scope: 0" while all nine were readable).
# The manifests on disk are the honest list.
pkgs=()
while IFS= read -r pj; do
  n="$(jq -r '.name // empty' "$pj" 2>/dev/null)"
  [[ "$n" == "$SCOPE/"* ]] || continue
  [[ "$(jq -r '.private // false' "$pj")" == "true" ]] && continue
  pkgs+=("$n")
done < <(find "$ROOT/packages" -maxdepth 2 -name package.json -not -path '*/node_modules/*' 2>/dev/null | sort)

(( ${#pkgs[@]} )) || { echo "npm-downloads.sh: no public $SCOPE packages found under packages/" >&2; exit 1; }

# add_months <YYYY-MM-DD> <n> — date(1) differs between BSD and GNU; try both.
add_months() {
  date -j -v+"$2"m -f '%Y-%m-%d' "$1" '+%Y-%m-%d' 2>/dev/null \
    || date -d "$1 + $2 months" '+%Y-%m-%d' 2>/dev/null
}
today() { date -u '+%Y-%m-%d'; }

rows="[]"
for p in "${pkgs[@]}"; do
  enc="${p/\//%2F}"                                   # @oneie/sdk -> @oneie%2Fsdk
  created="$(npm view "$p" time.created 2>/dev/null | head -1 | cut -c1-10)"
  [[ -n "$created" ]] || { created="2024-01-01"; }
  start="${SINCE:-$created}"
  end="$(today)"

  total=0; cursor="$start"
  while [[ "$cursor" < "$end" ]]; do
    stop="$(add_months "$cursor" 17)"
    [[ -z "$stop" || "$stop" > "$end" ]] && stop="$end"
    body="$(curl -sS --max-time 25 "https://api.npmjs.org/downloads/point/${cursor}:${stop}/${enc}" 2>/dev/null)"
    # the API reports its refusals in a 200 body — read the field, not the status
    err="$(printf '%s' "$body" | jq -r '.error // empty' 2>/dev/null)"
    if [[ -n "$err" ]]; then
      printf '  ! %s: %s\n' "$p" "$err" >&2
    else
      n="$(printf '%s' "$body" | jq -r '.downloads // 0' 2>/dev/null)"
      [[ "$n" =~ ^[0-9]+$ ]] && total=$(( total + n ))
    fi
    [[ "$stop" == "$end" ]] && break
    cursor="$(add_months "$stop" 0)"
  done

  wk="$(curl -sS --max-time 15 "https://api.npmjs.org/downloads/point/last-week/${enc}" 2>/dev/null | jq -r '.downloads // 0')"
  ver="$(npm view "$p" version 2>/dev/null | tail -1)"
  rows="$(printf '%s' "$rows" | jq --arg p "$p" --arg v "$ver" --arg c "$created" \
            --argjson t "${total:-0}" --argjson w "${wk:-0}" \
            '. + [{package:$p, version:$v, since:$c, all_time:$t, last_week:$w}]')"
done

if (( JSON )); then
  printf '%s\n' "$rows" | jq .
  exit 0
fi

printf '\n  %-24s %-9s %12s %10s   %s\n' "PACKAGE" "VERSION" "ALL TIME" "LAST WK" "SINCE"
printf '  %s\n' "$(printf '─%.0s' {1..74})"
printf '%s' "$rows" | jq -r '.[] | [.package,.version,(.all_time|tostring),(.last_week|tostring),.since] | @tsv' \
  | while IFS=$'\t' read -r p v a w s; do printf '  %-24s %-9s %12s %10s   %s\n' "$p" "$v" "$a" "$w" "$s"; done
printf '  %s\n' "$(printf '─%.0s' {1..74})"
printf '  %-24s %-9s %12s %10s\n\n' "TOTAL" "" \
  "$(printf '%s' "$rows" | jq '[.[].all_time]|add')" \
  "$(printf '%s' "$rows" | jq '[.[].last_week]|add')"
