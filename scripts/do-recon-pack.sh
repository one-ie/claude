#!/usr/bin/env bash
# do-recon-pack.sh <slug> [--files <path>...] — the DETERMINISTIC W1.
#
# manifest: needs-env
#
# needs-env, not portable: it JOINs do-brief.sh (needs-env) and do-recon-cache.sh,
# so it can be no cleaner than its inputs.
#
# WHY. `.claude/commands/do.md` Step 0.5 already states the contract: "with the
# brief compiled, a cycle needs at most TWO model calls — W2 (decide) and W3
# (make it). W1 collapses into the brief plus do-recon-cache.sh check." Step 3
# still spawned a `w1-recon` agent every cycle anyway. Measured 2026-09-01, that
# spawn re-loads 6.4KB of agent prose to narrate, in <400 words, facts that are
# on disk: which files exist, how big they are, what they export, who imports
# them, which docs carry the slug, and what the previous cycle left in
# `.w4-improvements.json` / `.claude/improvements.queue.md`. None of that is
# judgment. All of it is grep.
#
# This is a JOIN plus a symbol inventory, not new logic:
#   do-brief.sh        -> slug, plan, ready, files, folders, tier, spine, ceiling
#   do-recon-cache.sh  -> a warm prior recon for the same file shas (0 tokens)
#   git grep / wc      -> exports, imports, consumers, doc family
#
# It does NOT replace the `w1-recon` AGENT for SURVEY or INVESTIGATE (the spine
# stops in do.md Step 2). Those are once-per-PLAN judgment calls — reuse verdicts
# and root-cause forensics — and are not the per-cycle bill. This replaces the
# per-cycle RECON spawn only.
#
# Output: ONE json object on stdout. Non-zero exit + EMPTY stdout when the brief
# cannot be compiled — a half-pack is worse than no pack, because the caller
# cannot tell which half is missing (same law as do-brief.sh).
#
# --self-test  runs the fixtures INCLUDING a red proof; exits non-zero on failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/.claude/scripts"
MAX_FILES="${RECON_PACK_MAX_FILES:-40}"

_exports() {   # exported symbol names, capped
  grep -hoE '^[[:space:]]*export[[:space:]]+(default[[:space:]]+)?(async[[:space:]]+)?(function|const|let|class|type|interface|enum)[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*' "$1" 2>/dev/null \
    | awk '{print $NF}' | sort -u | head -30
}
_imports() {   # module specifiers this file pulls in, capped
  [ "$WIDE" = true ] || return 0
  grep -hoE "from[[:space:]]+['\"][^'\"]+['\"]" "$1" 2>/dev/null \
    | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/" | sort -u | head -30
}
_consumers() { # files that import this one, by basename stem, capped
  local stem; stem="$(basename "$1")"; stem="${stem%.*}"
  [ -n "$stem" ] || return 0
  git -C "$ROOT" grep -l -F -- "/$stem'" -- '*.ts' '*.tsx' '*.astro' 2>/dev/null \
    | grep -vxF "$1" | head -"$CO_CAP" || true
}

# WIDTH CAP. This pack replaces a receipt do.md caps at 400 words (~2.5KB), and
# a recon input bigger than the agent prompt it removed is not a saving.
# Measured 2026-09-01: 5 files -> 6.4KB, 15 files -> 12.1KB uncapped. Past 10
# files the per-file detail narrows — `imports` goes first, because W2 needs the
# exported surface and who depends on it, almost never the module specifiers.
CO_CAP=12
WIDE=true
_set_caps() { # <file-count>
  if [ "$1" -gt "${RECON_PACK_WIDE_MAX:-10}" ]; then CO_CAP=5; WIDE=false
  else CO_CAP=12; WIDE=true; fi
}

_json_arr() { # stdin lines -> json array (empty stdin -> [])
  jq -R -s 'split("\n") | map(select(length > 0))'
}

_pack() {
  local brief slug files_json
  # The brief is the floor. If it refuses, we refuse — identically.
  brief="$(bash "$S/do-brief.sh" "$@" 2>/dev/null)" || return 1
  [ -n "$brief" ] || return 1
  printf '%s' "$brief" | jq -e . >/dev/null 2>&1 || return 1

  slug="$(printf '%s' "$brief" | jq -r '.slug // ""')"
  files_json="$(printf '%s' "$brief" | jq -r '.files[]?' | head -"$MAX_FILES" | _json_arr)"
  _set_caps "$(printf '%s' "$files_json" | jq 'length')"

  # ---- per-file inventory (the part W1 used to narrate) ----
  local inv='[]' f entry
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -f "$ROOT/$f" ]; then
      entry="$(jq -n \
        --arg path "$f" \
        --argjson loc "$(wc -l < "$ROOT/$f" | tr -d ' ')" \
        --arg sha "$(git -C "$ROOT" hash-object "$f" 2>/dev/null || echo '')" \
        --argjson exports "$(_exports "$ROOT/$f" | _json_arr)" \
        --argjson imports "$(_imports "$ROOT/$f" | _json_arr)" \
        --argjson consumers "$(_consumers "$f" | _json_arr)" \
        '{path:$path, exists:true, loc:$loc, sha:$sha, exports:$exports, imports:$imports, consumers:$consumers}')"
    else
      entry="$(jq -n --arg path "$f" '{path:$path, exists:false, loc:0, sha:"", exports:[], imports:[], consumers:[]}')"
    fi
    inv="$(printf '%s' "$inv" | jq --argjson e "$entry" '. + [$e]')"
  done < <(printf '%s' "$files_json" | jq -r '.[]?')

  # ---- prior-cycle carry-over (W1's non-recon side effects — must not be lost) ----
  local improvements='[]' queue='[]' docs='[]'
  if [ -f "$ROOT/.w4-improvements.json" ]; then
    improvements="$(jq -c '[.. | objects | select(has("item") or has("improve"))] | .[0:10]' \
      "$ROOT/.w4-improvements.json" 2>/dev/null || echo '[]')"
  fi
  if [ -n "$slug" ] && [ -f "$ROOT/.claude/improvements.queue.md" ]; then
    queue="$(grep -i -- "$slug" "$ROOT/.claude/improvements.queue.md" 2>/dev/null | head -5 | _json_arr)"
  fi
  if [ -n "$slug" ]; then
    docs="$(cd "$ROOT" && ls "text/$slug.md" "text/$slug-plan.md" "text/$slug-features.md" \
             "text/$slug-ui.md" "text/$slug-todo.md" "text/$slug-docs.md" 2>/dev/null | _json_arr)"
  fi

  # ---- warm recon cache (0-token prior findings for the same shas) ----
  local cache_hit=false cache_findings="" flist
  flist="$(printf '%s' "$files_json" | jq -r '.[]?')"
  if [ -n "$flist" ]; then
    if cache_findings="$(cd "$ROOT" && bash "$S/do-recon-cache.sh" check $flist 2>/dev/null)"; then
      cache_hit=true
    else
      cache_findings=""
    fi
  fi

  jq -n \
    --argjson brief "$brief" \
    --argjson inventory "$inv" \
    --argjson improvements "$improvements" \
    --argjson queue "$queue" \
    --argjson docs "$docs" \
    --argjson cache_hit "$cache_hit" \
    --arg cache_findings "$cache_findings" \
    '{brief:$brief, inventory:$inventory, doc_family:$docs,
      improvements_open:$improvements, improvements_queue:$queue,
      recon_cache:{hit:$cache_hit, findings:$cache_findings}}'
}

_self_test() {
  local fails=0 out

  # 1. refusal parity with do-brief: a missing plan must refuse with EMPTY stdout.
  if out=$(bash "$S/do-recon-pack.sh" __nosuchplan__ 2>/dev/null); then
    echo "FAIL: missing plan produced a pack"; fails=$((fails+1))
  else
    [ -z "${out:-}" ] || { echo "FAIL: missing plan wrote to stdout"; fails=$((fails+1)); }
    echo "ok: missing plan refuses (exit non-zero, empty stdout)"
  fi

  # 2. the pack is valid JSON and carries the brief + a real symbol inventory.
  if out=$(bash "$S/do-recon-pack.sh" --files one.ie/web/src/lib/authority.ts 2>/dev/null); then
    if printf '%s' "$out" | jq -e '.brief.tier and (.inventory | length > 0)' >/dev/null 2>&1; then
      echo "ok: pack is valid JSON with brief + inventory"
    else
      echo "FAIL: pack missing brief/inventory"; fails=$((fails+1))
    fi
    if printf '%s' "$out" | jq -e '.inventory[0].exports | length > 0' >/dev/null 2>&1; then
      echo "ok: exports extracted from a real source file"
    else
      echo "FAIL: no exports extracted from authority.ts"; fails=$((fails+1))
    fi
  else
    echo "FAIL: --files pack did not run"; fails=$((fails+1))
  fi

  # 3. RED PROOF — a checker that cannot go red proves nothing.
  #    Feed a file that does NOT exist. The pack must report exists:false and
  #    exports:[] rather than fabricate an inventory — AND the exact assertion
  #    that passed in (2) must now FAIL, proving it bites.
  if out=$(bash "$S/do-recon-pack.sh" --files no/such/file.ts 2>/dev/null); then
    if printf '%s' "$out" | jq -e '.inventory[0].exists == false and (.inventory[0].exports | length == 0)' >/dev/null 2>&1; then
      echo "ok: RED PROOF — a missing target is reported exists:false, not fabricated"
    else
      echo "FAIL: RED PROOF — missing target was not marked absent"; fails=$((fails+1))
    fi
    if printf '%s' "$out" | jq -e '.inventory[0].exports | length > 0' >/dev/null 2>&1; then
      echo "FAIL: RED PROOF — the exports assertion passed on a file with no exports"; fails=$((fails+1))
    else
      echo "ok: RED PROOF — the exports assertion goes RED on a file with none"
    fi
  else
    echo "FAIL: RED PROOF — pack refused a syntactically fine --files target"; fails=$((fails+1))
  fi

  if [ "$fails" -eq 0 ]; then echo "do-recon-pack: self-test PASS"; return 0; fi
  echo "do-recon-pack: self-test FAIL ($fails)"; return 1
}

case "${1:-}" in
  --self-test) _self_test; exit $? ;;
  ""|-h|--help) echo "usage: do-recon-pack.sh <slug> | --files <path>... | --self-test" >&2; exit 2 ;;
esac

out="$(_pack "$@")" || exit 1
printf '%s\n' "$out"
