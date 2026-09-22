#!/usr/bin/env bash
# do-walk.sh — the deterministic verification walk for a shipped /do loop.
#
# Reads the walk stops out of text/<slug>-humans.md (guided browser walk for a
# person) or text/<slug>-agents.md (machine asserts, zero LLM) and executes
# them in order. Both files carry the same fenced-block format:
#
#   ```walk
#   stop: 1
#   title: Ads board loads
#   route: /u/one/ads
#   expect_status: ok            # ok (default, <500) | exact code e.g. 200
#   expect_text: "New campaign"  # optional — substring in the served HTML
#   expect_cmd: test -f one.ie/web/src/pages/api/ads/push.ts   # optional bash, exit 0 = pass
#   max_ms: 3000                 # optional speed budget for THIS stop's asserts
#   check: The board renders with the New campaign button top-right.
#   ```
#
# Usage:
#   do-walk.sh <slug> --agents [--base <url>]   # run every stop's asserts; exit 0 iff none failed
#   do-walk.sh <slug> --humans [--base <url>]   # open each page in the browser, ask y/n per stop
#   do-walk.sh <slug> --list  [--humans|--agents]  # print the stops, run nothing
#   do-walk.sh <slug> --agents --strict         # also exit 3 if any stop could not be run
#   do-walk.sh --self-test
#
# Env:
#   WALK_BASE_URL         force the base (else dev http://localhost:4321 if up, else prod)
#   PROVE_PROD_URL        prod fallback base (default https://one.ie)
#   PROVE_SESSION_COOKIE  optional "name=value" — sent on every request so
#                         auth-gated routes (/u/[slug]/*) can be walked signed-in.
#   WALK_STRICT=1         same as --strict
#   WALK_DEPTH            set by the script itself; a nested run refuses (see below)
#
# ── max_ms — a stop that passes slowly is not a stop that passes ──────────
# `max_ms: N` budgets THIS stop's own asserts (the curl(s) plus expect_cmd),
# not the whole walk. Over budget with everything else green fails the stop on
# SPEED, and says so in the FAIL line so nobody goes hunting for a correctness
# bug that isn't there.
#
# **A stop with no `max_ms` has NO budget.** Absent must never read as zero —
# every walk doc written before this field existed would fail instantly. Same
# for an unmeasurable clock: if neither bash 5 nor python3 can stamp the time,
# budgets are skipped rather than assumed blown. A non-numeric `max_ms` is a
# doc bug and fails the stop loudly instead of being silently ignored.
#
# Put budgets on the deterministic stops (file greps, local commands). A stop
# whose assert crosses the network is measuring someone else's latency, so
# either leave it unbudgeted or make the budget wide enough to mean something.
#
# ── red vs cannot run ────────────────────────────────────────────────────
# An `expect_cmd` that exits **3** did not fail — it could not be run, and
# nothing was proven either way (the convention `.claude/scripts/factory-check.sh`
# already uses, and text/factory.md § "A note on red vs cannot run"). Exit 1
# sends someone to fix the build; exit 3 says the environment could not answer.
#
# So: the walk's EXIT CODE answers "did anything fail?", and its OUTPUT answers
# "was everything proven?". Cannot-run stops are printed as CANNOT-RUN, counted
# separately, and named in the summary — they are never folded into the pass
# count. `--strict` is for a caller that needs full proof: it exits 3 when
# nothing failed but something could not be run.
#
# The 3 must always ORIGINATE IN THE CHECK. Never wrap a command so that its
# red becomes a cannot-run; that is how a walk starts lying.
#
# ── no nesting ───────────────────────────────────────────────────────────
# A stop must not re-run do-walk.sh. The obvious way to write the stop for a
# "the walk passes" deliverable is to paste in an accept: that calls this
# script, which loops forever. WALK_DEPTH makes a nested run refuse loudly
# instead. Assert the observable directly (--self-test, a grep) instead.
#
# Exit codes: 0 = nothing failed · 1 = a stop failed · 3 = --strict and a stop
# could not be run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROD_URL="${PROVE_PROD_URL:-https://one.ie}"
DEV_URL="${PROVE_DEV_URL:-http://localhost:4321}"

# ---------- parse helpers ----------

# extract_stops <file> → lines "N<TAB>key: value" for every ```walk block
extract_stops() {
  awk '
    /^```walk[[:space:]]*$/ { inb=1; n++; next }
    /^```[[:space:]]*$/     { inb=0; next }
    inb                     { print n "\t" $0 }
  ' "$1"
}

# field <stops> <n> <key> → value, empty if absent. Strips ONE matching pair
# of wrapping quotes (title: "x") but leaves an unquoted value — e.g. any
# expect_cmd containing its own internal 'quoted' args — completely untouched.
field() {
  printf '%s\n' "$1" | awk -F'\t' -v n="$2" -v k="$3" '
    $1 == n {
      line = $2
      prefix = k ": "
      if (index(line, prefix) == 1) {
        v = substr(line, length(prefix) + 1)
        sub(/[ \t]+$/, "", v)
        len = length(v)
        if (len >= 2) {
          first = substr(v, 1, 1); last = substr(v, len, 1)
          if ((first == "\"" && last == "\"") || (first == "'"'"'" && last == "'"'"'")) {
            v = substr(v, 2, len - 2)
          }
        }
        print v
        exit
      }
    }'
}

# now_ms → epoch milliseconds, or EMPTY if this box cannot stamp one.
# Portability is the whole point: `date +%s%N` is a GNU-ism, and BSD date (what
# macOS ships) prints a literal N — which then arithmetics into garbage that
# compares as 0 and fails every budget. bash 5 has EPOCHREALTIME with no
# subprocess; macOS's stock bash is 3.2, so python3 is the fallback; if neither
# answers, the caller SKIPS the budget rather than inventing a duration.
now_ms() {
  local e s f
  if [ "${BASH_VERSINFO[0]:-0}" -ge 5 ]; then
    e="${EPOCHREALTIME:-}"
    case "$e" in
      *[.,]*)
        s="${e%%[.,]*}"; f="${e##*[.,]}"; f="${f}000"; f="${f:0:3}"
        printf '%s' "$(( 10#$s * 1000 + 10#$f ))"; return 0 ;;
    esac
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time;print(int(time.time()*1000))'; return 0
  fi
  printf ''
}

# ---------- self-test ----------

if [ "${1:-}" = "--self-test" ]; then
  tmp="$(mktemp)"
  cat > "$tmp" <<'EOF'
## Stop 1
```walk
stop: 1
title: First
route: /a
expect_text: "hello"
check: first check
```
## Stop 2
```walk
stop: 2
title: Second
route: /b
expect_cmd: true
max_ms: 1500
check: second check
```
EOF
  stops="$(extract_stops "$tmp")"
  count="$(printf '%s\n' "$stops" | awk -F'\t' '{print $1}' | sort -u | grep -c . || true)"
  t1="$(field "$stops" 1 title)"; r2="$(field "$stops" 2 route)"
  # The budget arms: stop 2 carries one, stop 1 does not — and "does not" MUST
  # read as empty, never as 0, or every pre-max_ms walk doc fails on speed.
  b2="$(field "$stops" 2 max_ms)"; b1="$(field "$stops" 1 max_ms)"
  # And the clock must actually tick — a stuck clock makes every budget pass.
  c0="$(now_ms)"; sleep 0.05; c1="$(now_ms)"
  clock_ok=0
  if [ -n "$c0" ] && [ -n "$c1" ] && [ "$c1" -ge "$c0" ] && [ "$c0" -gt 1600000000000 ]; then clock_ok=1; fi
  rm -f "$tmp"
  if [ "$count" = "2" ] && [ "$t1" = "First" ] && [ "$r2" = "/b" ] \
     && [ "$b2" = "1500" ] && [ -z "$b1" ] && [ "$clock_ok" = "1" ]; then
    echo "WALK: self-test pass (parse + max_ms + clock)"; exit 0
  fi
  echo "WALK: self-test FAIL (count=$count t1=$t1 r2=$r2 b2=$b2 b1='$b1' clock_ok=$clock_ok)"; exit 1
fi

# ---------- args ----------

slug="" mode="" base="" list=0
strict=0; [ "${WALK_STRICT:-0}" = "1" ] && strict=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --agents) mode=agents; shift ;;
    --humans) mode=humans; shift ;;
    --strict) strict=1; shift ;;
    --list)   list=1; shift ;;
    --base)   [ "$#" -ge 2 ] || { echo "WALK: --base requires a value"; exit 1; }
              base="$2"; shift 2 ;;
    -*)       echo "WALK: unknown flag $1"; exit 1 ;;
    *)        slug="$1"; shift ;;
  esac
done
[ -n "$slug" ] || { echo "WALK: usage: do-walk.sh <slug> --agents|--humans [--base <url>] [--list]"; exit 1; }
[ -n "$mode" ] || mode=agents

file="$ROOT/text/${slug}-${mode}.md"
[ -f "$file" ] || { echo "WALK: no walk doc at text/${slug}-${mode}.md"; exit 1; }

stops="$(extract_stops "$file")"
[ -n "$stops" ] || { echo "WALK: text/${slug}-${mode}.md has no \`\`\`walk blocks"; exit 1; }
ids="$(printf '%s\n' "$stops" | awk -F'\t' '{print $1}' | sort -un)"

# ---------- base resolution ----------

if [ -z "$base" ]; then
  base="${WALK_BASE_URL:-}"
fi
if [ -z "$base" ]; then
  if curl -sf -o /dev/null --max-time 4 "$DEV_URL/" 2>/dev/null; then base="$DEV_URL"; else base="$PROD_URL"; fi
fi

cookie_args=()
[ -n "${PROVE_SESSION_COOKIE:-}" ] && cookie_args=(-H "Cookie: ${PROVE_SESSION_COOKIE}")

echo "WALK: $slug · $mode · base=$base · $(printf '%s\n' "$ids" | grep -c .) stop(s)"

# ---------- list mode ----------

if [ "$list" -eq 1 ]; then
  for n in $ids; do
    t="$(field "$stops" "$n" title)"; r="$(field "$stops" "$n" route)"
    c="$(field "$stops" "$n" check)"
    echo "  $n. ${t:-'(untitled)'}  ${r:+→ $base$r}"
    [ -n "$c" ] && echo "     $c"
  done
  exit 0
fi

# ---------- run ----------

# Nesting guard — see the header. A stop that shells back into do-walk.sh (the
# natural mistake when a deliverable IS "the walk passes") would recurse until
# the box gives up. Refuse loudly, at the stop, with the fix in the message.
# Placed after --list/--self-test so those stay usable from inside a walk.
if [ "${WALK_DEPTH:-0}" -ge 1 ]; then
  echo "WALK: refusing to nest (WALK_DEPTH=${WALK_DEPTH}) — a stop must not re-run do-walk.sh."
  echo "WALK: assert the observable directly (do-walk.sh --self-test, a grep), not by recursion."
  exit 1
fi
export WALK_DEPTH=$(( ${WALK_DEPTH:-0} + 1 ))

fail=0; passed=0; unknown=0; failed=0
for n in $ids; do
  t="$(field "$stops" "$n" title)"
  r="$(field "$stops" "$n" route)"
  es="$(field "$stops" "$n" expect_status)"; es="${es:-ok}"
  et="$(field "$stops" "$n" expect_text)"
  ec="$(field "$stops" "$n" expect_cmd)"
  mm="$(field "$stops" "$n" max_ms)"
  ck="$(field "$stops" "$n" check)"
  url=""; [ -n "$r" ] && url="$base$r"

  if [ "$mode" = "humans" ]; then
    echo ""
    echo "── Stop $n — ${t:-'(untitled)'}"
    [ -n "$url" ] && echo "   page:  $url"
    [ -n "$ck" ]  && echo "   check: $ck"
    if [ ! -t 0 ]; then
      continue   # non-interactive: print the guide only
    fi
    if [ -n "$url" ] && command -v open >/dev/null 2>&1; then open "$url"; fi
    printf '   verified? [y/n] '
    read -r verdict || verdict=n
    case "$verdict" in
      y|Y|yes) echo "   WALK: ok stop $n" ;;
      *)       echo "   WALK: FAIL stop $n — human rejected"; fail=1 ;;
    esac
    continue
  fi

  # agents mode — deterministic asserts, zero LLM
  ok=1; why=""; cannot=0; elapsed=""; code=""
  # A malformed budget is a doc bug, and a doc bug that silently disables the
  # budget is worse than no budget at all. Fail the stop and name the value.
  if [ -n "$mm" ]; then
    case "$mm" in
      ''|*[!0-9]*) ok=0; why="invalid max_ms '$mm' — want whole milliseconds" ;;
    esac
  fi
  t0="$(now_ms)"
  if [ "$ok" -eq 1 ] && [ -n "$url" ]; then
    code="$(curl -s -o /dev/null --max-time 20 -w '%{http_code}' "${cookie_args[@]+"${cookie_args[@]}"}" "$url" 2>/dev/null || echo 000)"
    if [ "$es" = "ok" ]; then
      { [ "$code" = "000" ] || [ "$code" -ge 500 ]; } && { ok=0; why="http=$code"; }
    else
      [ "$code" != "$es" ] && { ok=0; why="http=$code (want $es)"; }
    fi
    if [ "$ok" -eq 1 ] && [ -n "$et" ]; then
      # Body FIRST, then grep it — never `curl | grep -q` here. `grep -q` exits
      # the moment it matches, curl is still writing, curl dies of SIGPIPE (141),
      # and `set -o pipefail` (line 73) hands that 141 to the `if`. The stop then
      # fails *because the text was found*, on any page big enough that curl has
      # not finished writing. Measured 2026-08-04: `/u/one/shop` serves "Shop"
      # twice and the stop still reported "text 'Shop' not in served HTML",
      # reproducibly. A false RED — the mirror of the false GREEN do-prove had.
      # A here-string, not a pipe: `printf … | grep -q` reintroduces the exact
      # same SIGPIPE race one process further left.
      body="$(curl -s --max-time 20 "${cookie_args[@]+"${cookie_args[@]}"}" "$url" 2>/dev/null || true)"
      if ! grep -qiF -- "$et" <<<"$body"; then
        ok=0; why="text '$et' not in served HTML"
      fi
      unset body
    fi
  fi
  if [ "$ok" -eq 1 ] && [ -n "$ec" ]; then
    # rc captured via `|| rc=$?` — NOT `cmd; rc=$?`, which set -e would kill
    # before the assignment ran. 3 = the check could not run; anything else
    # non-zero = it ran and failed.
    rc=0
    (cd "$ROOT" && bash -c "$ec" >/dev/null 2>&1) || rc=$?
    if [ "$rc" -eq 3 ]; then
      cannot=1; why="expect_cmd could not run (exit 3): $ec"
    elif [ "$rc" -ne 0 ]; then
      ok=0; why="expect_cmd failed (exit $rc): $ec"
    fi
  fi
  t1="$(now_ms)"
  if [ -n "$t0" ] && [ -n "$t1" ]; then elapsed=$(( t1 - t0 )); fi

  # Speed is judged LAST and only on a stop that actually decided itself.
  # A cannot-run stop proved nothing — including nothing about its duration —
  # so timing it would be measuring an outage.
  if [ "$cannot" -eq 0 ] && [ "$ok" -eq 1 ] && [ -n "$mm" ] && [ -n "$elapsed" ] \
     && [ "$elapsed" -gt "$mm" ]; then
    ok=0; why="SPEED: ${elapsed}ms over budget max_ms=${mm} (correctness passed)"
  fi

  timing=""; [ -n "$mm" ] && [ -n "$elapsed" ] && timing=" [${elapsed}ms/${mm}ms]"
  if [ "$cannot" -eq 1 ]; then
    echo "WALK: CANNOT-RUN stop $n — ${t:-'(untitled)'} — $why"
    unknown=$(( unknown + 1 ))
  elif [ "$ok" -eq 1 ]; then
    echo "WALK: ok stop $n — ${t:-'(untitled)'}${url:+ ($code)}${timing}"
    passed=$(( passed + 1 ))
  else
    echo "WALK: FAIL stop $n — ${t:-'(untitled)'} — $why"
    fail=1; failed=$(( failed + 1 ))
  fi
done

echo ""
if [ "$fail" -eq 1 ]; then
  echo "WALK: fail — $failed failed · $passed proven · $unknown could not be run"
  exit 1
fi
if [ "$unknown" -gt 0 ]; then
  echo "WALK: pass — $passed proven · $unknown could not be run · 0 failed"
  echo "WALK: nothing failed, but $unknown stop(s) proved nothing either way — re-run when the environment answers."
  if [ "$strict" -eq 1 ]; then
    echo "WALK: strict — a walk that could not run every stop is not a full proof."
    exit 3
  fi
  exit 0
fi
echo "WALK: pass — $passed proven"; exit 0
