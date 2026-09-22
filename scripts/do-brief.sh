#!/usr/bin/env bash
# do-brief.sh <slug> [--files <path>...] — the CYCLE COMPILER.
#
# manifest: needs-env
#
# needs-env, not portable: this is a JOIN over do-tier.sh and do-folder.sh, both
# of which are needs-env, so it cannot be cleaner than its inputs. Classified
# portable on the first pass and the factory build caught it.
#
# WHY. Every wave of a /do cycle used to spend model tokens NARRATING facts that a
# script in this directory already emits. W1 read the plan an LLM could have been
# handed; W2 re-derived the tier; W4 re-derived the folder and the verify command.
# Five model calls, each carrying ~130KB of markdown, to reach a decision whose
# inputs were all deterministic. Measured 2026-09-01: the deterministic half of a
# cycle is ~30s of compute; the prose around it was the bill.
#
# This is a JOIN, not new logic. It composes the existing single-purpose scripts
# into ONE json object — the brief — so the loop makes at most two model calls per
# cycle (decide, then edit) and the gates stay exactly what they were.
#
#   do-plan-json.sh  -> worktree, outcome, batches, open cycles
#   do-next.sh       -> which cycles are READY right now (DAG, not batch barrier)
#   do-tier.sh       -> tier, pruned spine, classifier, ceiling, w2 model
#   do-folder.sh     -> target folder(s) + verify/build commands
#
# Output: one JSON object on stdout. Non-zero exit + no stdout when the plan
# cannot be parsed — a brief that half-resolved is worse than no brief, because
# the caller cannot tell which half is missing.
#
# --self-test  runs the fixtures; exits non-zero on failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/.claude/scripts"

_self_test() {
  local fails=0 t
  t="$(mktemp -d)"; trap 'rm -rf "$t"' RETURN

  # 1. a missing slug must FAIL, not emit a half-brief.
  if out=$(bash "$S/do-brief.sh" __nosuchplan__ 2>/dev/null); then
    echo "FAIL: missing plan produced a brief"; fails=$((fails+1))
  else
    [ -z "${out:-}" ] || { echo "FAIL: missing plan wrote to stdout"; fails=$((fails+1)); }
    echo "ok: missing plan refuses (exit non-zero, empty stdout)"
  fi

  # 2. the join must be valid JSON carrying every required key.
  #    Use --files so the test needs no plan file at all.
  local req='.tier and .spine and .folders and .files and .ceiling_tokens'
  if out=$(bash "$S/do-brief.sh" --files one.ie/web/src/lib/authority.ts 2>/dev/null); then
    if printf '%s' "$out" | jq -e "$req" >/dev/null 2>&1; then
      echo "ok: --files brief is valid JSON with all required keys"
    else
      echo "FAIL: brief missing required keys: $out"; fails=$((fails+1))
    fi
  else
    echo "FAIL: --files brief did not run"; fails=$((fails+1))
  fi

  # 3. RED PROOF — a checker that cannot go red proves nothing. Feed a file list
  #    that must classify above PATCH and assert the tier actually MOVES.
  local patch_tier deep_tier
  patch_tier=$(bash "$S/do-brief.sh" --files text/readme.md 2>/dev/null | jq -r .tier)
  deep_tier=$(bash "$S/do-brief.sh" --files schema/one.tql 2>/dev/null | jq -r .tier)
  if [ "$patch_tier" = "$deep_tier" ]; then
    echo "FAIL: tier does not discriminate (doc=$patch_tier schema=$deep_tier)"; fails=$((fails+1))
  else
    echo "ok: tier discriminates (doc=$patch_tier schema=$deep_tier)"
  fi

  [ "$fails" -eq 0 ] && { echo "do-brief: self-test PASS"; return 0; }
  echo "do-brief: self-test FAILED ($fails)"; return 1
}

[ "${1:-}" = "--self-test" ] && { _self_test; exit $?; }

SLUG=""; FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --files) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do FILES+=("$1"); shift; done ;;
    --*) shift ;;
    *) SLUG="$1"; shift ;;
  esac
done

plan='null'; nextc='null'
if [ -n "$SLUG" ]; then
  # A plan that cannot be parsed is a HARD stop: the whole point of the compiler
  # is that the caller never has to guess which half resolved.
  plan="$(bash "$S/do-plan-json.sh" "$SLUG" 2>/dev/null)" || {
    echo "do-brief: cannot parse plan '$SLUG' (do-plan-json refused)" >&2; exit 1; }
  nextc="$(bash "$S/do-next.sh" "$SLUG" --all 2>/dev/null | jq -Rs 'split("\n")|map(select(length>0))' 2>/dev/null || echo 'null')"
fi

# File list: explicit --files, else the cycle's own working diff.
if [ "${#FILES[@]}" -eq 0 ]; then
  mapfile -t FILES < <(git -C "$ROOT" diff --name-only HEAD 2>/dev/null; git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null) || true
fi
[ "${#FILES[@]}" -eq 0 ] && FILES=("text/${SLUG:-none}-todo.md")

tier="$(printf '%s\n' "${FILES[@]}" | bash "$S/do-tier.sh" 2>/dev/null || echo '{}')"
folders="$(printf '%s\n' "${FILES[@]}" | bash "$S/do-folder.sh" 2>/dev/null | jq -s '.' 2>/dev/null || echo '[]')"
files_json="$(printf '%s\n' "${FILES[@]}" | jq -Rs 'split("\n")|map(select(length>0))')"

jq -n --argjson plan "${plan:-null}" \
      --argjson tier "${tier:-{\}}" \
      --argjson folders "${folders:-[]}" \
      --argjson files "$files_json" \
      --argjson next "${nextc:-null}" \
      --arg slug "$SLUG" '
  {slug: $slug, plan: $plan, ready: $next, files: $files, folders: $folders}
  + ($tier | {tier, spine, classifier, ceiling_tokens, w2_model})'
