#!/usr/bin/env bash
# do-world-check.sh — assert every CODE surface a promise's `world.code:` block
# declares actually EXISTS on disk. Zero LLM; the path's presence is the verdict.
#
# WHY: a tag is an address, and the family named after it is what `world:`
# manifests. `/do` already presence-checks the block's agents, skills, workflow
# steps and views — but nothing checked for a `.ts`, `.astro` or `.tql` at the
# tag's name, so a promise could name a code surface it never built and settle
# green. `world.code:` declares those paths; this gate answers missing/present
# with the same rule already applied to agents: missing → a cycle · present → skip.
#
# SCOPE — `world.code.*` ONLY, and the line is deliberate. The other four kinds
# (agents · skills · workflow/lifecycle · views) stay the PROSE walk an agent runs
# at DESIGN/PLAN (.claude/commands/do.md § world, .claude/agents/w1-recon.md);
# they are named entities, not one deterministic path each. Every key under
# `code:` is a repo-root-relative path, so every key under `code:` is checkable.
# Not wired into do-w4-gates.sh or do-promise-settle.sh yet — that is the follow-on.
#
# The --self-test fixtures name paths under fixtures/ rather than schema/ only
# because factory-repo.sh:44 (MONOREPO_PATH_RE) refuses a `portable` script that
# names a monorepo path. The RED shape is identical either way; the demo C6 asks
# for — `code.tql` naming an absent schema/<tag>.tql — is recorded verbatim in
# text/deploy-todo.md § C6.
#
# Usage:
#   do-world-check.sh <slug>          # text/<slug>.md, or $PROMISE_FILE
#   do-world-check.sh --self-test     # temp fixtures, zero network
#   exit: 0 all present (or no code: block) · 1 a surface missing · 2 no promise file · 4 bad usage
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# print "<key>\t<path>" for every path declared under world: → code:.
# Two levels of nesting, so the col-0 terminator alone is not enough: the walk
# tracks indentation. Both YAML list forms are read — flow (`tql: [a, b]`) and
# block (`tql:` then `- a`) — and a trailing ` # comment` is stripped.
code_entries() { # $1 = promise file
  awk '
    function indent(s,   n) { n = match(s, /[^ ]/); return n ? n - 1 : -1 }
    function clean(v) {
      sub(/[ \t]+#.*$/, "", v)                 # trailing comment
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      gsub(/^["'"'"']|["'"'"']$/, "", v)       # one layer of quoting
      return v
    }
    function emit(k, v) { v = clean(v); if (v != "") printf "%s\t%s\n", k, v }
    function emit_flow(k, v,   n, i, parts) {
      sub(/^\[/, "", v); sub(/\].*$/, "", v)
      n = split(v, parts, ",")
      for (i = 1; i <= n; i++) emit(k, parts[i])
    }
    /^---[ \t]*$/ { fm++; if (fm >= 2) exit; next }
    fm != 1 { next }
    /^world:[ \t]*(#.*)?$/ { inw = 1; next }   # a trailing comment must not hide the block — `code:` below already tolerates one, and the asymmetry made a full world: block read as "nothing to check" at exit 0 (2026-09-22)
    inw && /^[^ \t#]/ { inw = 0; inc = 0; key = "" }     # a col-0 key ends world:
    !inw { next }
    /^[ \t]*$/ { next }
    /^[ \t]*#/ { next }
    {
      i = indent($0)
      if (inc && i <= 2) { inc = 0; key = "" }            # a sibling of code: ends it
      if (!inc) { if ($0 ~ /^[ \t]*code:[ \t]*(#.*)?$/ && i == 2) { inc = 1; key = "" } ; next }
      if (i < 4) next
      if ($0 ~ /^[ \t]*-[ \t]/) {                         # block list item
        if (key == "") next
        line = $0; sub(/^[ \t]*-[ \t]*/, "", line); emit(key, line); next
      }
      if (match($0, /^[ \t]*[A-Za-z][A-Za-z0-9_-]*:/)) {  # a code: sub-key
        key = $0; sub(/^[ \t]*/, "", key); sub(/:.*$/, "", key)
        rest = $0; sub(/^[ \t]*[A-Za-z][A-Za-z0-9_-]*:[ \t]*/, "", rest)
        if (rest ~ /^\[/) { emit_flow(key, rest); key = "" }
        else emit(key, rest)
      }
    }
  ' "$1"
}

check() { # $1 = slug
  local slug="$1"
  local file="${PROMISE_FILE:-$ROOT/text/$slug.md}" missing=0 checked=0 line key path
  if [ ! -f "$file" ]; then
    echo "[world-check] $slug — no promise file at text/$slug.md"; return 2
  fi
  while IFS="$(printf '\t')" read -r key path; do
    [ -z "${path:-}" ] && continue
    checked=$((checked+1))
    if [ -e "$ROOT/$path" ]; then
      echo "[world-check] ok: world.code.$key → $path"
    else
      echo "[world-check] MISSING: world.code.$key declares $path — no such path"
      missing=$((missing+1))
    fi
  done <<EOF
$(code_entries "$file")
EOF
  if [ "$checked" -eq 0 ]; then
    echo "[world-check] $slug — no world.code: surfaces declared (nothing to check)"; return 0
  fi
  if [ "$missing" -gt 0 ]; then
    echo "[world-check] $slug — $missing/$checked declared code surface(s) missing"; return 1
  fi
  echo "[world-check] $slug — ok ($checked declared code surface(s) present)"; return 0
}

if [ "${1:-}" = "--self-test" ]; then
  dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
  mkdir -p "$dir/text" "$dir/fixtures"
  fails=0
  : >"$dir/fixtures/green.tql"; : >"$dir/fixtures/green.astro"
  # green: flow list + block list, every declared path on disk
  cat >"$dir/text/green.md" <<'YAML'
---
slug: green
world:
  agents:
    - { name: doctor, subscribes: [health] }
  code:                    # a trailing comment on the key must not hide the block
    tql: [fixtures/green.tql]
    astro:
      - fixtures/green.astro   # a trailing comment must not break the path
  tracking:
    marks: ["a nested sibling at indent 4 must not read as a code surface"]
  views: []
---
YAML
  # red: a declared .tql that was never written
  cat >"$dir/text/red.md" <<'YAML'
---
slug: red
world:
  code:
    tql: [fixtures/nonexistent-zzz.tql]
---
YAML
  # bare: a world: block with no code: — passes, checks nothing
  printf -- '---\nslug: bare\nworld:\n  agents: []\n---\n' >"$dir/text/bare.md"
  # commented: a trailing comment on `world:` ITSELF must not hide the block. Until
  # 2026-09-22 it did — /^world:[ \t]*$/ required the key to be alone on its line while
  # the sibling `code:` already tolerated a comment, so a promise with a full world: block
  # answered exit 0 "nothing to check". A false green on the one gate whose whole job is
  # to refuse a declared-but-unbuilt path. This fixture is RED against the old regex.
  cat >"$dir/text/commented.md" <<'YAML'
---
slug: commented
world:                     # the runtime this promise puts into the world
  code:
    tql: [fixtures/nonexistent-zzz.tql]
---
YAML
  out="$(ROOT="$dir" PROMISE_FILE= check green 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL green should pass: $out"; fails=$((fails+1)); }
  case "$out" in *"ok (2 declared"*) ;; *) echo "FAIL green must count 2 surfaces: $out"; fails=$((fails+1)) ;; esac
  out="$(ROOT="$dir" PROMISE_FILE= check red 2>&1)"; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL red should fail: $out"; fails=$((fails+1)); }
  case "$out" in *"MISSING: world.code.tql"*) ;; *) echo "FAIL red must name the path: $out"; fails=$((fails+1)) ;; esac
  out="$(ROOT="$dir" PROMISE_FILE= check bare 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL bare should pass: $out"; fails=$((fails+1)); }
  case "$out" in *"nothing to check"*) ;; *) echo "FAIL bare must say nothing to check: $out"; fails=$((fails+1)) ;; esac
  out="$(ROOT="$dir" PROMISE_FILE= check commented 2>&1)"; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL commented world: should fail, not read as empty: $out"; fails=$((fails+1)); }
  case "$out" in *"MISSING: world.code.tql"*) ;; *) echo "FAIL commented must name the path: $out"; fails=$((fails+1)) ;; esac
  case "$out" in *"nothing to check"*) echo "FAIL commented read as an EMPTY world: block - the 2026-09-22 false green"; fails=$((fails+1)) ;; esac
  echo "[world-check] self-test: 4 fixtures, $fails failed"
  exit "$fails"
fi

SLUG="${1:-}"
[ -z "$SLUG" ] && { echo "usage: do-world-check.sh <slug> | --self-test" >&2; exit 4; }
PROMISE_FILE="${PROMISE_FILE:-}"
check "$SLUG"
