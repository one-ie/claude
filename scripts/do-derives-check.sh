#!/usr/bin/env bash
# do-derives-check.sh — assert every artifact a promise's derives: block declares
# `true` actually EXISTS on disk. Zero LLM; the file's presence is the verdict.
#
# WHY: text/security-gates.md declared `docs: true` but text/security-gates-docs.md
# was never written — the promise settled green on a lie. This gate closes that
# class: a declared derives: artifact that is missing fails the check, so /close
# (via do-promise-settle.sh) cannot mark the promise KEPT until the file exists.
#
# Usage:
#   do-derives-check.sh <slug>        # exit 0 if every true file-key exists, else 1
#   do-derives-check.sh --self-test   # temp fixtures, zero network
#   exit: 0 all present · 1 an artifact missing · 2 no promise file · 4 bad usage
#
# SCOPE — file-shaped keys ONLY. The derives: block mixes two kinds of key:
#   (a) 1:1 DOC keys → a single deterministic text/<slug>-<key>.md path:
#       plan · todo · docs · tutorial · how-to · reference · features · ui — CHECKED.
#   (b) named-entity / multi-file keys with NO single deterministic path — SKIPPED:
#       tests    (per-surface files, not one text/<slug>.test.ts),
#       agents   (a named actor at one.ie/ai/agents/*, or the -agents-docs.md
#                 briefing — ambiguous; security-gates' agents:true is a compliance
#                 actor, NOT text/security-gates-agents.md — checking it false-fails),
#       skills · tasks · tracking · routing · views (world: entries — presence-checked
#                 by the world: traversal + the proof's own test run, not a filename).
# v1: simple + deterministic, matched to the concrete bug (a missing DOC).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# derives keys that map 1:1 to text/<slug>-<key>.md (padded for whole-word match)
FILE_KEYS=" plan todo docs tutorial how-to reference features ui "

# print each derives sub-key whose value is exactly `true` (first frontmatter block).
# Ends the block on the first column-0 non-space, non-comment line (e.g. `rubric:` /
# `world:`); blank + col-0 comment lines inside the block are tolerated. world.agents
# is never counted — only `^derives:` opens the block.
true_derives_keys() { # $1 = promise file
  awk '
    /^---[[:space:]]*$/ { fm++; if (fm>=2) exit; next }
    fm!=1 { next }
    /^derives:[[:space:]]*$/ { ind=1; next }
    ind==1 && /^[^[:space:]#]/ { ind=0 }
    ind==1 && /^[[:space:]]+[A-Za-z][A-Za-z-]*:[[:space:]]+true([[:space:]]|#|$)/ {
      k=$0; sub(/^[[:space:]]+/,"",k); sub(/:.*/,"",k); print k
    }
  ' "$1"
}

check() { # $1 = slug
  local slug="$1"
  local file="$ROOT/text/$slug.md" missing=0 checked=0 key
  if [ ! -f "$file" ]; then
    echo "[derives-check] $slug — no promise file at text/$slug.md"; return 2
  fi
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    case "$FILE_KEYS" in *" $key "*) ;; *) continue ;; esac   # skip named-entity keys
    checked=$((checked+1))
    if [ ! -f "$ROOT/text/$slug-$key.md" ]; then
      echo "[derives-check] MISSING: derives.$key=true but text/$slug-$key.md does not exist"
      missing=$((missing+1))
    fi
  done < <(true_derives_keys "$file")
  if [ "$missing" -gt 0 ]; then
    echo "[derives-check] $slug — $missing/$checked declared artifact(s) missing"; return 1
  fi
  echo "[derives-check] $slug — ok ($checked file-shaped derives artifact(s) present)"; return 0
}

if [ "${1:-}" = "--self-test" ]; then
  dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
  mkdir -p "$dir/text"
  fails=0
  # green: docs:true + doc present; agents:true present but MUST be skipped (no -agents.md)
  printf -- '---\nslug: green\nderives:\n  plan: true\n  docs: true\n  agents: true\n---\n' >"$dir/text/green.md"
  : >"$dir/text/green-plan.md"; : >"$dir/text/green-docs.md"
  # red: docs:true but the doc is missing
  printf -- '---\nslug: red\nderives:\n  plan: true\n  docs: true\n---\n' >"$dir/text/red.md"
  : >"$dir/text/red-plan.md"
  ROOT="$dir" check green >/dev/null 2>&1 || { echo "FAIL green should pass (agents skipped)"; fails=$((fails+1)); }
  ROOT="$dir" check red  >/dev/null 2>&1 && { echo "FAIL red should fail (missing docs)"; fails=$((fails+1)); }
  echo "[derives-check] self-test: 2 fixtures, $fails failed"
  exit "$fails"
fi

SLUG="${1:-}"
[ -z "$SLUG" ] && { echo "usage: do-derives-check.sh <slug> | --self-test" >&2; exit 4; }
check "$SLUG"
