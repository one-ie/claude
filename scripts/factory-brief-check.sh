#!/usr/bin/env bash
# factory-brief-check.sh — pre-flight a factory brief for DEFERRED DECISIONS.
#
# manifest: portable
#   Reads no credential and names no monorepo path — every rule is a literal
#   in this file and the brief arrives as an argument or on stdin. The red
#   half of --self-test reads fixtures/factory-brief-real.md, which ships
#   beside it; absent, the self-test goes RED rather than skipping.
#
# WHY THIS EXISTS. A brief that hands the doer a decision instead of a decision
# already made costs a whole run. The first factory run spent ~46 minutes and
# ended in a refutation because one parenthesis said "verify which is right" —
# the launching session had two candidate reads of the workspace and shipped
# both. The doer is the wrong place to settle that: it has no board, no
# neighbours, and no cheap way to be wrong. This gate reads the brief BEFORE a
# worktree, a port, or a model call is spent, and refuses.
#
# Usage:
#   factory-brief-check.sh <brief-file>     check a brief file
#   factory-brief-check.sh -                check a brief on stdin
#   cat brief.md | factory-brief-check.sh   same
#   factory-brief-check.sh --self-test      prove the gate goes RED and GREEN
#
# Exit: 0 = brief is launchable · 1 = RED (or self-test failed) · 2 = usage.
#
# Env:
#   FACTORY_BRIEF_FIXTURE  override the --self-test red fixture (default:
#                          fixtures/factory-brief-real.md beside this script)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# The rules. Each is a NAMED pattern, matched case-insensitively, one per line
# of the brief. A rule fires when the brief leaves a decision for the doer.
#
# Third field is the input the pattern is matched against: `line` is the raw
# line, `stripped` is the line with every file-path token removed first.
#
# Deliberate deviation, documented: `tbd` and `todo` match against `stripped`,
# so `text/template-todo.md` and `<slug>-todo.md` — which nearly every real
# brief in this repo cites — are NOT hits, while a bare `TBD.` at the end of a
# sentence still is. A gate that goes red on the name of a file it expects you
# to name is decoration, and gets disabled; a gate that misses `TBD.` because
# of the full stop is worse.
# ---------------------------------------------------------------------------
RULES=(
  'verify-which|verify[[:space:]]+which|line'
  'check-whether|check[[:space:]]+whether|line'
  'tbd|(^|[^-_/[:alnum:]])tbd([^-_[:alnum:]]|$)|stripped'
  'todo|(^|[^-_/[:alnum:]])todo([^-_[:alnum:]]|$)|stripped'
  'decide-later|decide[[:space:]]+later|line'
  'or-alternatively|or[[:space:]]+alternatively|line'
  'either-or|(^|[^[:alnum:]])either[^[:alnum:]].*[[:space:]]or[[:space:]]|line'
  'trailing-question|\?[[:space:]]*$|line'
  'if-possible|if[[:space:]]+possible|line'
  'ideally|(^|[^[:alnum:]])ideally([^[:alnum:]]|$)|line'
)

# Rule 'code-span-options': two options joined by ` ?? ` or ` or ` INSIDE a code
# span. `a ?? b` in prose is a decision the doer has to make; the same string in
# shipped code is not, so only backtick spans count. Returns 0 when the line has
# one.
code_span_options() {
  awk '
    {
      n = split($0, part, "`")
      # odd-indexed parts (2,4,…) are inside a span
      for (i = 2; i <= n; i += 2) {
        s = part[i]
        if (s ~ /[^[:space:]][[:space:]]+\?\?[[:space:]]+[^[:space:]]/) { found = 1 }
        if (s ~ /[^[:space:]][[:space:]]+or[[:space:]]+[^[:space:]]/)   { found = 1 }
      }
    }
    END { exit !found }
  ' <<< "$1"
}

# A file path token. The spec class is lowercase; this adds A-Z so the count and
# any listing read correctly (`ComponentBrowser.tsx`, not `omponentBrowser.tsx`).
# Presence is identical either way.
PATH_RE='[A-Za-z0-9_./-]+\.(tsx|astro|ts|sh|md|mjs|js)([^A-Za-z0-9]|$)'

# A 'Done' section: a line that STARTS with the word done, optionally behind a
# markdown heading or bold marker. "DONE LOOKS LIKE", "## Done", "**Done**".
DONE_RE='^[[:space:]]*(#+[[:space:]]*)?(\*\*)?[[:space:]]*done([^[:alnum:]]|$)'

check_brief() {
  local text="$1" label="${2:-brief}"
  local hits=0 line rule name pat

  if [ -z "${text//[[:space:]]/}" ]; then
    printf 'BRIEF RED: empty-brief — "<%s is empty — a brief that says nothing defers everything>"\n' "$label"
    return 1
  fi

  local rest src stripped
  while IFS= read -r line; do
    [ -z "${line//[[:space:]]/}" ] && continue
    stripped="$(sed -E "s#$PATH_RE# #g" <<< "$line")"
    for rule in ${RULES[@]+"${RULES[@]}"}; do
      name="${rule%%|*}"; rest="${rule#*|}"
      pat="${rest%|*}"; src="${rest##*|}"
      if grep -qiE "$pat" <<< "$([ "$src" = stripped ] && printf '%s' "$stripped" || printf '%s' "$line")"; then
        printf 'BRIEF RED: %s — "%s"\n' "$name" "$line"
        hits=$((hits + 1))
      fi
    done
    if code_span_options "$line"; then
      printf 'BRIEF RED: code-span-options — "%s"\n' "$line"
      hits=$((hits + 1))
    fi
  done <<< "$text"

  local files
  files="$(grep -oE "$PATH_RE" <<< "$text" | sed -E 's/[^A-Za-z0-9]$//' | sort -u)"
  local nfiles=0
  [ -n "$files" ] && nfiles="$(wc -l <<< "$files" | tr -d ' ')"

  if [ "$nfiles" -eq 0 ]; then
    printf 'BRIEF RED: no-file-path — "<%s names no file the doer can open>"\n' "$label"
    hits=$((hits + 1))
  fi

  if ! grep -qiE "$DONE_RE" <<< "$text"; then
    printf 'BRIEF RED: no-done-section — "<%s has no Done section — nothing says when to stop>"\n' "$label"
    hits=$((hits + 1))
  fi

  if [ "$hits" -gt 0 ]; then
    return 1
  fi
  printf 'BRIEF OK: %s files named, 0 deferred decisions\n' "$nfiles"
  return 0
}

# ---------------------------------------------------------------------------
# --self-test — the red proof. Four cases; the red half runs against the ACTUAL
# brief that produced the first run's refutation, copied verbatim, not retyped.
# ---------------------------------------------------------------------------
self_test() {
  local fixture="${FACTORY_BRIEF_FIXTURE:-$HERE/fixtures/factory-brief-real.md}"
  local tmp out rc bad=0 cases=0

  if [ ! -f "$fixture" ]; then
    printf 'SELF-TEST RED: the red fixture is missing at %s — the red half cannot be run, so nothing here is proven. Refusing to pass.\n' "$fixture" >&2
    printf 'SELF-TEST RED: 0 cases — fixture absent\n'
    return 1
  fi

  # (a) the real brief MUST go red, and MUST name verify-which on the real line.
  cases=$((cases + 1))
  out="$(check_brief "$(cat "$fixture")" "$fixture")"; rc=$?
  if [ $rc -eq 0 ]; then
    printf '  FAIL (a) the real brief passed — the gate is blind\n' >&2; bad=1
  elif ! grep -q '^BRIEF RED: verify-which — ' <<< "$out"; then
    printf '  FAIL (a) the real brief went red, but not on verify-which:\n%s\n' "$out" >&2; bad=1
  elif ! grep -qi 'verify which is right' <<< "$(grep '^BRIEF RED: verify-which — ' <<< "$out")"; then
    printf '  FAIL (a) verify-which fired on the wrong line:\n%s\n' "$(grep '^BRIEF RED: verify-which' <<< "$out")" >&2; bad=1
  else
    printf '  ok   (a) the real brief is RED on verify-which, quoting "verify which is right"\n'
  fi

  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN

  # (b) a clean brief MUST pass.
  cat > "$tmp/clean.md" <<'CLEAN'
BUILD: the picker gate on the component gallery.

WHAT TO BUILD
Add an "Add to page" control to the preview footer in
src/components/puck/ComponentBrowser.tsx. It lists the workspace pages, takes
one, appends the block, then offers two exits.

THE DECISION, ALREADY MADE
Read the workspace slug server-side from Astro.locals.slug in
src/pages/components.astro and pass it down as an optional prop. There is no
session, so there is no slug, so the control does not render.

TEST
Extend tests/unit/puck/add-to-page.test.tsx with one case that names the wrong
result: a missing slug renders the control anyway.

DONE LOOKS LIKE
1. The control renders signed in and is absent signed out.
2. The block lands at the end of the picked page.
3. bash .claude/scripts/gate-run.sh doer -- bunx vitest related --run is green.
4. node .claude/scripts/wf-check.mjs is green.
CLEAN
  cases=$((cases + 1))
  out="$(check_brief "$(cat "$tmp/clean.md")" "$tmp/clean.md")"; rc=$?
  if [ $rc -ne 0 ]; then
    printf '  FAIL (b) the clean brief went red — the gate cries wolf:\n%s\n' "$out" >&2; bad=1
  elif ! grep -q '^BRIEF OK: ' <<< "$out"; then
    printf '  FAIL (b) the clean brief exited 0 without printing BRIEF OK\n' >&2; bad=1
  else
    printf '  ok   (b) the clean brief is GREEN — %s\n' "$out"
  fi

  # (c) a brief with no file path MUST go red, even with nothing deferred.
  cat > "$tmp/nopath.md" <<'NOPATH'
BUILD: make the gallery let you put a block on a page.

DONE LOOKS LIKE
1. It works signed in and is absent signed out.
NOPATH
  cases=$((cases + 1))
  out="$(check_brief "$(cat "$tmp/nopath.md")" "$tmp/nopath.md")"; rc=$?
  if [ $rc -eq 0 ] || ! grep -q '^BRIEF RED: no-file-path' <<< "$out"; then
    printf '  FAIL (c) a brief naming no file passed:\n%s\n' "$out" >&2; bad=1
  else
    printf '  ok   (c) a brief naming no file is RED on no-file-path\n'
  fi

  # (d) a brief with no Done section MUST go red.
  cat > "$tmp/nodone.md" <<'NODONE'
BUILD: the picker gate.
Edit src/components/puck/ComponentBrowser.tsx and read the slug server-side in
src/pages/components.astro. Extend tests/unit/puck/add-to-page.test.tsx.
NODONE
  cases=$((cases + 1))
  out="$(check_brief "$(cat "$tmp/nodone.md")" "$tmp/nodone.md")"; rc=$?
  if [ $rc -eq 0 ] || ! grep -q '^BRIEF RED: no-done-section' <<< "$out"; then
    printf '  FAIL (d) a brief with no Done section passed:\n%s\n' "$out" >&2; bad=1
  else
    printf '  ok   (d) a brief with no Done section is RED on no-done-section\n'
  fi

  # (e) EVERY named rule must fire. A declared rule that no case exercises is a
  # rule that can ship broken and pass a brief it exists to refuse — one line
  # per rule, all eleven, and the count asserted so a line tripping two rules
  # (or none) is caught rather than averaged away.
  cat > "$tmp/allrules.md" <<'ALLRULES'
BUILD: one line per deferred decision, in src/lib/one.ts.
Verify which read is right.
Check whether the snapshot is warm.
The signal name is TBD.
Leave a TODO where the gate goes.
Name the signal now and decide later on the payload.
Append the block, or alternatively insert it at the top.
Use either the snapshot or a live read.
Should the picker show archived pages?
Reuse the existing helper if possible.
Ideally the control renders in the footer.
Set the base to `4321 or 4325` first.
DONE LOOKS LIKE
1. It renders.
ALLRULES
  cases=$((cases + 1))
  out="$(check_brief "$(cat "$tmp/allrules.md")" "$tmp/allrules.md")"; rc=$?
  local missing="" r n
  for r in verify-which check-whether tbd todo decide-later or-alternatively \
           either-or trailing-question if-possible ideally code-span-options; do
    grep -q "^BRIEF RED: $r — " <<< "$out" || missing="$missing $r"
  done
  n="$(grep -c '^BRIEF RED: ' <<< "$out" | tr -d ' ')"
  if [ -n "$missing" ]; then
    printf '  FAIL (e) rules declared but never fired:%s\n%s\n' "$missing" "$out" >&2; bad=1
  elif [ "$n" != 11 ]; then
    printf '  FAIL (e) expected 11 hits, one per rule, got %s:\n%s\n' "$n" "$out" >&2; bad=1
  else
    printf '  ok   (e) all 11 named rules fire — 11 hits, one per rule, no structural hit\n'
  fi

  # (f) THE RED PROOF ITSELF. Gut this script — empty the RULES array, keep
  # everything else — and case (a) MUST flip: the real brief that cost ~46
  # minutes now passes. A checker that stays green against its own gutted copy
  # proves nothing, which is the failure this whole script exists to refuse.
  #
  # Gut by STRUCTURE, never by line number, so an edit above cannot quietly turn
  # this into a no-op. Two things were measured before this assertion was
  # written, and both are why it reads the way it does:
  #   - `"${RULES[@]}"` on an EMPTY array is an unbound variable under `set -u`
  #     in bash 3.2, so the gutted copy used to die with a bash error and exit 1.
  #     "exit non-zero" would have looked like proof and measured the crash. The
  #     expansion in check_brief is empty-safe for exactly this reason.
  #   - code_span_options lives OUTSIDE Rules and still runs in the gutted copy;
  #     the real fixture happens to trip none of its spans, so the gutted copy
  #     reaches BRIEF OK. Both halves are asserted separately so a future change
  #     to either one names itself instead of averaging away.
  cases=$((cases + 1))
  awk '/^RULES=\(/{print "RULES=()"; s=1; next} s&&/^\)/{s=0; next} !s' \
    "${BASH_SOURCE[0]}" > "$tmp/gutted.sh"
  if ! grep -q '^RULES=()$' "$tmp/gutted.sh"; then
    printf '  FAIL (f) the gutting did not take — no empty RULES in the copy\n' >&2; bad=1
  elif ! bash -n "$tmp/gutted.sh" 2>/dev/null; then
    printf '  FAIL (f) the gutted copy does not parse — the proof measures a syntax error, not the rules\n' >&2; bad=1
  else
    out="$(bash "$tmp/gutted.sh" "$fixture" 2>&1)"; rc=$?
    if grep -q '^BRIEF RED: verify-which' <<< "$out"; then
      printf '  FAIL (f) the gutted copy STILL refused the brief on verify-which — the RULES array is not load-bearing:\n%s\n' "$out" >&2; bad=1
    elif [ $rc -ne 0 ]; then
      printf '  FAIL (f) the gutted copy stopped the brief for some OTHER reason (rc=%s) — the red half of (a) is not attributable to the rules:\n%s\n' "$rc" "$out" >&2; bad=1
    else
      printf '  ok   (f) rules emptied ⇒ the real brief PASSES (%s) — case (a) is attributable to the rules, not to the structural checks\n' "$out"
    fi
  fi

  if [ $bad -ne 0 ]; then
    printf 'SELF-TEST RED: %s cases — the gate does not hold\n' "$cases"
    return 1
  fi
  printf 'SELF-TEST OK: %s cases — red half red, green half green\n' "$cases"
  return 0
}

main() {
  case "${1:-}" in
    --self-test) self_test; exit $? ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
      exit 0 ;;
    "")
      if [ -t 0 ]; then
        printf 'usage: factory-brief-check.sh <brief-file> | - | --self-test\n' >&2
        exit 2
      fi
      check_brief "$(cat)" "stdin"; exit $? ;;
    -)  check_brief "$(cat)" "stdin"; exit $? ;;
    *)
      if [ ! -f "$1" ]; then
        printf 'factory-brief-check.sh: no such brief file: %s\n' "$1" >&2
        exit 2
      fi
      check_brief "$(cat "$1")" "$1"; exit $? ;;
  esac
}

main "$@"
