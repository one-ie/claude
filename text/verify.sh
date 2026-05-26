#!/usr/bin/env bash
# text/verify.sh — prose W4 gate. Usage: bash text/verify.sh [NN | --all]
# Body-only checks: excludes fenced code blocks, table rows (|...), HTML comments.
set -uo pipefail

cd "$(dirname "$0")"
TARGET="${1:---all}"
FAIL=0

BANNED='\b(seamless|leverage|robust|cutting-edge|game-changer|game-changing|delve|unlock|elevate|empower|transform|supercharge|revolutionise|revolutionize|world-class|best-in-class|next-generation|actionable insights?|move the needle|low-hanging fruit|at the end of the day|in conclusion|in summary|in the realm of|tapestry|landscape \(as a metaphor\)|it.?s important to note)\b'

# body_of: strip fenced code blocks, table rows, and HTML comments
body_of() {
  awk '
    /^```/ { c=!c; next }
    c { next }
    /^\|/ { next }
    /<!--/ { next }
    { print }
  ' "$1"
}

# count_re_in <pattern> <file>  — returns integer (0 on no match)
count_re() {
  local n
  n=$(grep -cE "$1" 2>/dev/null || true)
  echo "${n:-0}"
}

check_file() {
  local f="$1"
  local file_fail=0

  # 1. banned vocab
  local banned_count
  banned_count=$(grep -ciE "$BANNED" "$f" 2>/dev/null || true)
  banned_count=${banned_count:-0}
  if [ "$banned_count" -gt 0 ]; then
    echo "✗ $f: $banned_count banned word(s)"
    grep -niE "$BANNED" "$f" | head -5
    file_fail=1
  fi

  # 2. em-dash budget: ≤ 6 in BODY
  local em
  em=$(body_of "$f" | grep -o '—' | wc -l | tr -d ' ')
  em=${em:-0}
  if [ "$em" -gt 6 ]; then
    echo "✗ $f: $em em-dashes in body (limit 6)"
    file_fail=1
  fi

  # 3. word count
  local words
  words=$(wc -w < "$f" | tr -d ' ')
  local fname; fname=$(basename "$f")
  local lo=4500 hi=7000
  if [[ "$fname" == "00-cover.md" ]]; then
    lo=1000; hi=1800
  elif [[ "$fname" == "09-teams.md" ]]; then
    lo=6000; hi=8000
  fi
  if [ "$words" -lt "$lo" ] || [ "$words" -gt "$hi" ]; then
    echo "✗ $f: $words words (target $lo–$hi)"
    file_fail=1
  fi

  # 4. heading rule — body only
  local h1 h3
  h1=$(body_of "$f" | grep -c '^# ' 2>/dev/null || true); h1=${h1:-0}
  h3=$(body_of "$f" | grep -c '^### ' 2>/dev/null || true); h3=${h3:-0}
  if [ "$h1" -ne 1 ]; then echo "✗ $f: $h1 h1 headings (need 1)"; file_fail=1; fi
  if [ "$h3" -ne 0 ]; then echo "✗ $f: $h3 h3 heading(s)"; file_fail=1; fi

  # 5. rubric receipt — (opus) tag + composite ≥ 0.90
  local receipt
  receipt=$(tail -3 "$f" | grep -oE '<!-- rubric:.*-->.*' | tail -1 || true)
  local score="0"
  if [ -z "$receipt" ]; then
    echo "✗ $f: missing rubric receipt"; file_fail=1
  else
    if ! echo "$receipt" | grep -q '(opus)'; then
      echo "✗ $f: rubric receipt not marked (opus)"; file_fail=1
    fi
    score=$(echo "$receipt" | grep -oE '→ [0-9]\.[0-9]+' | grep -oE '[0-9]\.[0-9]+' || true)
    score=${score:-0}
    if awk "BEGIN{exit !($score < 0.90)}"; then
      echo "✗ $f: rubric composite $score < 0.90"; file_fail=1
    fi
  fi

  # 6. no exclamation marks in body
  local bang
  bang=$(body_of "$f" | grep -c '!' 2>/dev/null || true); bang=${bang:-0}
  if [ "$bang" -gt 0 ]; then
    echo "✗ $f: $bang exclamation mark(s) in body"
    body_of "$f" | grep -n '!' | head -3
    file_fail=1
  fi

  # 6b. persona footer
  local persona
  persona=$(tail -5 "$f" | grep -oE '<!-- persona:[^>]*-->' | tail -1 || true)
  if [ -z "$persona" ]; then
    echo "✗ $f: missing persona footer"; file_fail=1
  else
    local push_v anxiety_v pull_v job_v
    push_v=$(echo "$persona" | grep -oE 'push=[YN]' | cut -d= -f2)
    anxiety_v=$(echo "$persona" | grep -oE 'anxiety=[YN]' | cut -d= -f2)
    pull_v=$(echo "$persona" | grep -oE 'pull=[YN]' | cut -d= -f2)
    job_v=$(echo "$persona" | grep -oE 'job=(fn|em|so|id)')
    if [ "$push_v" != "Y" ] || [ "$anxiety_v" != "Y" ] || [ "$pull_v" != "Y" ] || [ -z "$job_v" ]; then
      echo "✗ $f: persona footer incomplete (push=$push_v anxiety=$anxiety_v pull=$pull_v job=$job_v)"
      file_fail=1
    fi
  fi

  # 6c. Brad-banned vocab in body
  local bradban='\b(AI-powered|future-proof|reach out to learn more|trusted by leading brands|built by AI experts|transform your agency)\b'
  local bradban_count
  bradban_count=$(body_of "$f" | grep -ciE "$bradban" 2>/dev/null || true); bradban_count=${bradban_count:-0}
  if [ "$bradban_count" -gt 0 ]; then
    echo "✗ $f: $bradban_count Brad-banned phrase(s)"
    body_of "$f" | grep -niE "$bradban" | head -3
    file_fail=1
  fi

  if [ "$file_fail" -eq 0 ]; then
    echo "✓ $f: words=$words em=$em rubric=$score"
  fi
  FAIL=$((FAIL + file_fail))
}

if [ "$TARGET" = "--all" ]; then
  for f in [0-9][0-9]-*.md; do
    [ -f "$f" ] && check_file "$f"
  done
else
  for f in ${TARGET}-*.md; do
    [ -f "$f" ] && check_file "$f"
  done
fi

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "FAIL: $FAIL file(s) did not pass"
  exit 1
fi
echo ""
echo "PASS: all checked files green"
