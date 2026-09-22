#!/usr/bin/env bash
# do-ui-gate.sh — IC9: executable proof rows for a promise's screens/states.
#
# Reads the ```ui fenced blocks out of text/<slug>-ui.md — same fenced-block
# convention as do-walk.sh's ```walk blocks — and executes them:
#
#   ```ui
#   row: 1
#   component: LoginButton
#   state: default
#   route: /login
#   expect_text: "Sign in"            # optional — substring in the served HTML
#   expect_cmd: test -f x.tsx         # optional bash, exit 0 = pass
#   check: renders a blue primary button
#   ```
#
# Rows may be moved under a `## Deferred` heading, but that ONLY skips them
# if the Deferred section's body contains a line `promise: <slug>` (ties the
# deferral to a tracked promise — otherwise the gate FAILs; UI work can't be
# silently waived).
#
# Usage:
#   do-ui-gate.sh <slug> [--list]     # print parsed rows (active vs deferred), run nothing
#   do-ui-gate.sh <slug>              # run active rows against a live/self-started dev server
#   do-ui-gate.sh --self-test
#
# Env:
#   UI_GATE_BASE_URL   force the base URL (skips sentinel detection + self-start)
#
# Base URL resolution (when UI_GATE_BASE_URL unset):
#   1. derive port = 4400 + (cksum of slug) % 100 (same derivation as do-auto.sh's
#      _sentinel_port, IC1) and check .do-worktrees/<slug>/.do-loop-running for a
#      live pid on that port
#   2. else self-start `astro dev --port <port>` from one.ie/web, poll for 200
#      up to 60s, run rows, then kill the server it started
#
# Exit codes: 0 = every active row passed (or --list) · 1 = a row failed, or an
# undeferred waive (rows after ## Deferred with no `promise: <slug>` line).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------- parse helpers (copied from do-walk.sh, fence tag `ui`) ----------

# extract_stops <file> → lines "N<TAB>key: value" for every ```ui block
extract_stops() {
  awk '
    /^```ui[[:space:]]*$/ { inb=1; n++; next }
    /^```[[:space:]]*$/   { inb=0; next }
    inb                   { print n "\t" $0 }
  ' "$1"
}

# field <stops> <n> <key> → value, empty if absent (fence-agnostic)
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

# _sentinel_port <slug> — must match do-auto.sh's derivation exactly
_sentinel_port() {
  echo $(( 4400 + $(cksum <<<"$1" | cut -d' ' -f1) % 100 ))
}

# split_rows <file> <stops> <ids> → prints two files: $1.active $1.deferred
# (as global vars ACTIVE_IDS / DEFERRED_IDS, newline-separated row numbers)
split_deferred() { # $1 = ui.md file, $2 = stops
  local file="$1"
  awk '/^##[[:space:]]*Deferred/{print NR; exit}' "$file"
}

deferred_section_names_promise() { # $1 = file, $2 = slug
  local file="$1" slug="$2" ln
  ln="$(awk '/^##[[:space:]]*Deferred/{print NR; exit}' "$file")"
  [ -z "$ln" ] && return 1
  tail -n "+$ln" "$file" | grep -qE "^promise:[[:space:]]*${slug}[[:space:]]*$"
}

row_line_number() { # $1 = file, $2 = row n → line number of the ```ui fence that starts row n
  awk -v want="$2" '
    /^```ui[[:space:]]*$/ { n++; if (n == want) { print NR; exit } }
  ' "$1"
}

# ---------- self-test ----------

if [ "${1:-}" = "--self-test" ]; then
  tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  fails=0

  # fixture 1: one passing row, one failing row (both expect_cmd, no route) — expect exit 1
  f1="$tmpdir/f1-ui.md"
  cat > "$f1" <<'EOF'
## Row 1
```ui
row: 1
component: A
state: default
expect_cmd: true
check: always passes
```
## Row 2
```ui
row: 2
component: B
state: default
expect_cmd: false
check: always fails
```
EOF
  if UI_GATE_SELF_TEST=1 bash "${BASH_SOURCE[0]}" _fixture_f1 --file "$f1" >/dev/null 2>&1; then
    echo "FAIL: fixture1 expected exit 1 (one failing row), got 0"; fails=$((fails+1))
  fi

  # fixture 2: failing row moved under ## Deferred, no `promise: <slug>` line — expect exit 1 (undeferred waive)
  f2="$tmpdir/f2-ui.md"
  cat > "$f2" <<'EOF'
## Row 1
```ui
row: 1
component: A
state: default
expect_cmd: true
check: always passes
```
## Deferred
Some other note, no promise line here.
```ui
row: 2
component: B
state: default
expect_cmd: false
check: always fails
```
EOF
  if UI_GATE_SELF_TEST=1 bash "${BASH_SOURCE[0]}" _fixture_f2 --file "$f2" >/dev/null 2>&1; then
    echo "FAIL: fixture2 expected exit 1 (undeferred waive), got 0"; fails=$((fails+1))
  fi

  # fixture 3: same deferred row, but section names `promise: <slug>` — expect exit 0
  f3="$tmpdir/f3-ui.md"
  cat > "$f3" <<'EOF'
## Row 1
```ui
row: 1
component: A
state: default
expect_cmd: true
check: always passes
```
## Deferred
promise: _fixture_f3
```ui
row: 2
component: B
state: default
expect_cmd: false
check: always fails
```
EOF
  if ! UI_GATE_SELF_TEST=1 bash "${BASH_SOURCE[0]}" _fixture_f3 --file "$f3" >/dev/null 2>&1; then
    echo "FAIL: fixture3 expected exit 0 (properly deferred), got nonzero"; fails=$((fails+1))
  fi

  echo "[ui-gate] self-test: 3 fixtures, $fails failed"
  exit "$fails"
fi

# ---------- args ----------

slug="" list=0 file_override=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --list) list=1; shift ;;
    --file) [ "$#" -ge 2 ] || { echo "UI-GATE: --file requires a value"; exit 1; }
            file_override="$2"; shift 2 ;;   # internal: used by --self-test fixtures
    -*)     echo "UI-GATE: unknown flag $1"; exit 1 ;;
    *)      slug="$1"; shift ;;
  esac
done
[ -n "$slug" ] || { echo "UI-GATE: usage: do-ui-gate.sh <slug> [--list]"; exit 1; }

file="${file_override:-$ROOT/text/${slug}-ui.md}"
[ -f "$file" ] || { echo "UI-GATE: no ui doc at text/${slug}-ui.md"; exit 1; }

stops="$(extract_stops "$file")"
[ -n "$stops" ] || { echo "UI-GATE: text/${slug}-ui.md has no \`\`\`ui blocks"; exit 1; }
ids="$(printf '%s\n' "$stops" | awk -F'\t' '{print $1}' | sort -un)"

deferred_at_line="$(awk '/^##[[:space:]]*Deferred/{print NR; exit}' "$file")"

active_ids=""; deferred_ids=""
for n in $ids; do
  rln="$(row_line_number "$file" "$n")"
  if [ -n "$deferred_at_line" ] && [ "$rln" -gt "$deferred_at_line" ]; then
    deferred_ids="$deferred_ids $n"
  else
    active_ids="$active_ids $n"
  fi
done

if [ -n "$deferred_ids" ]; then
  if ! deferred_section_names_promise "$file" "$slug"; then
    echo "UI-GATE: FAIL — rows$deferred_ids are under ## Deferred but that section does not name \`promise: $slug\` — UI work cannot be silently waived"
    exit 1
  fi
  echo "UI-GATE: rows$deferred_ids deferred to promise: $slug (skipped)"
fi

echo "UI-GATE: $slug · $(printf '%s\n' "$active_ids" | wc -w | tr -d ' ') active row(s)"

# ---------- list mode ----------

if [ "$list" -eq 1 ]; then
  for n in $active_ids; do
    c="$(field "$stops" "$n" component)"; s="$(field "$stops" "$n" state)"
    r="$(field "$stops" "$n" route)"; ck="$(field "$stops" "$n" check)"
    echo "  active $n. $c/$s${r:+ → $r}"
    [ -n "$ck" ] && echo "     $ck"
  done
  for n in $deferred_ids; do
    c="$(field "$stops" "$n" component)"; s="$(field "$stops" "$n" state)"
    echo "  deferred $n. $c/$s"
  done
  exit 0
fi

# ---------- zero-network short-circuit (self-test fixtures) ----------
# If no active row needs a route/expect_text (only expect_cmd rows), skip the
# base-URL bootstrap entirely — keeps --self-test zero-network.
needs_network=0
for n in $active_ids; do
  r="$(field "$stops" "$n" route)"
  [ -n "$r" ] && needs_network=1
done

base=""
started_server=0
server_pid=""

if [ "$needs_network" -eq 1 ]; then
  base="${UI_GATE_BASE_URL:-}"
  port="$(_sentinel_port "$slug")"

  if [ -z "$base" ]; then
    sentinel="$ROOT/.do-worktrees/$slug/.do-loop-running"
    if [ -f "$sentinel" ]; then
      spid="$(grep -o '"pid":[0-9]*' "$sentinel" | head -1 | cut -d: -f2 || true)"
      sport="$(grep -o '"port":[0-9]*' "$sentinel" | head -1 | cut -d: -f2 || true)"
      if [ -n "$spid" ] && kill -0 "$spid" 2>/dev/null && [ -n "$sport" ]; then
        if curl -sf -o /dev/null --max-time 3 "http://localhost:$sport/" 2>/dev/null; then
          base="http://localhost:$sport"
        fi
      fi
    fi
  fi

  if [ -z "$base" ]; then
    echo "UI-GATE: self-starting dev server on port $port"
    ( cd "$ROOT/one.ie/web" && exec ./node_modules/.bin/astro dev --port "$port" ) >/tmp/ui-gate-$slug.log 2>&1 &
    server_pid=$!
    started_server=1
    base="http://localhost:$port"
    ok=0
    for _ in $(seq 1 30); do
      if curl -sf -o /dev/null --max-time 2 "$base/" 2>/dev/null; then ok=1; break; fi
      sleep 2
    done
    if [ "$ok" -ne 1 ]; then
      echo "UI-GATE: FAIL — dev server on $base did not come up within 60s"
      kill "$server_pid" 2>/dev/null || true
      exit 1
    fi
  fi
  echo "UI-GATE: base=$base"
fi

cleanup() {
  if [ "$started_server" -eq 1 ] && [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ---------- run ----------

fail=0
for n in $active_ids; do
  c="$(field "$stops" "$n" component)"; s="$(field "$stops" "$n" state)"
  r="$(field "$stops" "$n" route)"
  et="$(field "$stops" "$n" expect_text)"
  ec="$(field "$stops" "$n" expect_cmd)"

  ok=1; why=""
  if [ -n "$r" ] && [ -n "$base" ]; then
    body="$(curl -s --max-time 20 "$base$r" 2>/dev/null || true)"
    if [ -z "$body" ]; then ok=0; why="no response from $base$r"; fi
    if [ "$ok" -eq 1 ] && [ -n "$et" ] && ! grep -qiF "$et" <<<"$body"; then
      ok=0; why="text '$et' not in served HTML"
    fi
  fi
  if [ "$ok" -eq 1 ] && [ -n "$ec" ]; then
    if ! (cd "$ROOT" && bash -c "$ec" >/dev/null 2>&1); then ok=0; why="expect_cmd failed: $ec"; fi
  fi

  if [ "$ok" -eq 1 ]; then
    echo "UI-GATE: ok row $n — $c/$s"
  else
    echo "UI-GATE: FAIL row $n — $c/$s — $why"
    fail=1
  fi
done

echo ""
if [ "$fail" -eq 1 ]; then echo "UI-GATE: fail"; exit 1; fi
echo "UI-GATE: pass"; exit 0
