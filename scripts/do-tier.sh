#!/usr/bin/env bash
# do-tier.sh — the token-economy spine-pruner. Infer the loop tier from the changed files
# (+ optional --intent) and emit the pruned spine, the inner classifier, and a per-tier
# token ceiling. The human never picks: this one signal sizes both outer and inner work.
# DEFAULT DOWN when unsure — an under-built FIX re-opens cheaply; an over-built PATCH is burnt.
# Usage:  do-tier.sh [--intent "text"] <path>...   |   git diff --name-only | do-tier.sh [--intent ...]
set -euo pipefail

# --self-test — the tier fixtures, runnable as one command (same idiom as
# do-reconcile.sh / do-promise-settle.sh / do-promise-lint.sh). Exists so an
# acceptance check can be `do-tier.sh --self-test` instead of a fragile inline
# pipeline: do-tier now exits 3 on UNSIZED, and under `pipefail` that propagates
# through `… | grep` even when the grep matches.
if [ "${1:-}" = "--self-test" ]; then
  S="$(cd "$(dirname "$0")" && pwd)"; f=0
  chk() { # chk <expected-tier> <args...>
    want="$1"; shift
    got="$("$S/do-tier.sh" "$@" 2>/dev/null)" || true
    case "$got" in *"\"tier\":\"$want\""*) printf '  ok   %s → %s\n' "$*" "$want" ;;
                   *) printf '  FAIL %s → expected %s, got %s\n' "$*" "$want" "$got"; f=1 ;; esac
  }
  chk PATCH   text/x.md
  chk SCHEMA  schema/one.tql
  chk SCHEMA  channels/migrations/0001_init.sql
  chk SCHEMA  pay/contracts/sui/sources/one_token.move
  chk FIX     pay/contracts/sui/tests/gateway_tests.move
  chk FIX     .claude/scripts/x.sh
  chk FIX     .claude/workflows/x.js
  chk FEATURE --intent "add billing" one.ie/web/src/api/b.ts
  # Absence of recon must not read as simplicity — no paths → UNSIZED, never PATCH.
  # Intent is ignored by design: "add a null check" and "add a settings page" share a verb.
  # set +e around this: UNSIZED exits 3 BY CONTRACT, and this script runs under
  # `set -e`, so the assignment below would abort the self-test before it asserted
  # anything — silently "passing" a build with the guard removed (caught doing
  # exactly that during authoring).
  set +e
  out="$(printf '' | "$S/do-tier.sh" --intent "add a settings page" 2>/dev/null)"; rc=$?
  set -e
  case "$out" in *'"tier":"UNSIZED"'*) printf '  ok   no paths → UNSIZED (not PATCH)\n' ;;
                 *) printf '  FAIL no paths → expected UNSIZED, got %s\n' "$out"; f=1 ;; esac
  [ "$rc" -eq 3 ] && printf '  ok   UNSIZED → exit 3\n' || { printf '  FAIL UNSIZED exit: expected 3, got %s\n' "$rc"; f=1; }
  [ "$f" -eq 0 ] && echo "do-tier: self-test green" || echo "do-tier: self-test FAILED"
  exit "$f"
fi

intent=""
if [ "${1:-}" = "--intent" ]; then intent="$2"; shift 2; fi

paths=()
if [ "$#" -gt 0 ]; then paths=("$@"); else while IFS= read -r l; do [ -n "$l" ] && paths+=("$l"); done; fi

# UNSIZED — zero real paths. do-tier sizes a DIFF, never a sentence.
#
# The downward bias below ("an over-built PATCH is burnt") is right when the paths are
# known and dangerous when there are none: with no paths every input fell through to
# PATCH/TRIVIAL/5k, so an unrecon'd idea read as a typo. That silently mis-sized real
# work twice on record — text/learnings.md:485 ("correctly returned PATCH on a bare slug
# with no changes yet") and text/remote-suspend-todo.md:5 ("do-tier mis-sized as FIX").
# The caller at .claude/commands/do.md Step 1 passes $(git diff --name-only), which is
# empty on a clean tree — i.e. at AIM, every single time, before any edit exists.
#
# Absence of recon must not read as simplicity. Intent text alone can't decide either
# ("add a null check" and "add a settings page" share a verb), so UNSIZED ignores
# --intent by design: run recon, then size the paths it found.
# NB: guard the expansion — `"${paths[@]}"` on an empty array is an unbound-variable
# error under `set -u` on macOS's bash 3.2, not an empty list.
real=0
if [ "${#paths[@]}" -gt 0 ]; then
  for p in "${paths[@]}"; do [ -n "$p" ] && real=$((real + 1)); done
fi
if [ "$real" -eq 0 ]; then
  printf '{"tier":"UNSIZED","spine":"recon","classifier":"UNKNOWN","ceiling_tokens":0,"w2_model":"none"}\n'
  exit 3
fi

n=${#paths[@]}
schema=false; code=false; doconly=true
for p in "${paths[@]}"; do
  case "$p" in
    *.tql|schema/*) schema=true; code=true; doconly=false ;;
    # Persistent-shape + irreversible surfaces escalate like schema: an applied
    # D1 migration is append-only and a deployed contract can't be patched, so
    # a wrong shape here taxes every future cycle the same way a .tql one does.
    */migrations/*.sql|migrations/*.sql) schema=true; code=true; doconly=false ;;
    */tests/*.move) code=true; doconly=false ;;  # contract tests are code, not shape
    *.move|*.sol) schema=true; code=true; doconly=false ;;
    # .claude/scripts/*.sh and .claude/workflows/*.js are code that runs gates and
    # fleets, not .claude/'s usual prose arm — must precede the .claude/* PATCH
    # fallback below or they fall through as doc-only.
    .claude/scripts/*.sh|.claude/workflows/*.js) code=true; doconly=false ;;
    *.md|.claude/*|text/*|docs/*) ;;
    "") ;;
    *) code=true; doconly=false ;;
  esac
done

# tier inference — first match wins, biased downward
if $schema; then tier=SCHEMA
elif printf '%s' "$intent" | grep -qiE '\b(add|new|introduce|build a|feature|capability)\b'; then tier=FEATURE
elif $doconly && [ "$n" -le 2 ]; then tier=PATCH
elif ! $code && [ "$n" -le 2 ]; then tier=PATCH
elif ! $code; then tier=FIX
else tier=FIX
fi

# w2_model — who decides. SCHEMA verdicts compound across the whole substrate
# (one wrong entity shape taxes every future cycle), so W2 escalates to Fable
# whenever FABLE_AVAILABLE=on (restored 2026-07-04; set in settings.json's env
# block) — falls back to Opus if that var is ever unset again. The plan can
# still override per-cycle.
W2_SCHEMA=opus
[ "${FABLE_AVAILABLE:-off}" = "on" ] && W2_SCHEMA=fable
# spine — the pruned stop list, in the tokens do.md Step 1 has always used. These are
# the SAME stops as do.md's uppercase spine block (§ "The pruned spine by tier"), in
# their original lowercase names: spec=DESIGN · todo=PLAN · code=BUILD · tests=TEST ·
# proof=PROVE · teach=TEACH · release=SHIP. At genesis (ff72af398, 2026-06-04) do.md
# printed this exact lowercase list; 6b5b89f04 renamed the doc's tokens and 98c20f586
# (2026-06-18) reordered them docs-first, and neither change reached here — so the
# strings below sat two commits behind canon from 2026-06-18. Realigned 2026-08-02.
#
# What the drift actually was (the trailing `docs` was NOT the bug):
#   - `proof docs release` was already canon — that `docs` is TEACH (reconcile the docs
#     against shipped reality), which correctly follows PROVE. It is renamed to `teach`
#     below only so the one pre-BUILD `docs` stop can own the word `docs` unambiguously.
#   - The real defect was an OMISSION: there was no pre-BUILD `docs` stop on any tier,
#     so the deterministic spine never scheduled the doc set that .claude/rules/
#     documentation.md makes the spec ("docs are the spec, written FIRST"). A conductor
#     reading this spine walked straight to `code`.
#   - FEATURE/SCHEMA also still emitted `code tests` where canon is TEST → BUILD: the
#     tests are drawn FROM the docs, before the code exists.
#   - FIX had neither a `docs` stop nor a `learn` stop that do.md:222 gives it.
# The `docs` insert + `teach` rename are prescribed verbatim by text/do-evolve.md § 8.
# `verify` and `learn` go beyond that string — they come straight from do.md:222-223,
# which lists VERIFY (FEATURE/SCHEMA, between BUILD and PROVE) and LEARN (all but PATCH).
# Noted because do-evolve § 8 is a live design doc: the delta from its string is deliberate.
#
# Deliberately absent: `aim` (AIM is the stop that RUNS do-tier — emitting it here would
# be the output naming its own caller) and `investigate` (do.md:231 — it rides any tier
# on a condition, so it is not tier-pruned). `reconcile` stays SCHEMA-only per do.md:224.
case "$tier" in
  PATCH)   spine="code verify";                                                                          cls=TRIVIAL; ceil=5000;   w2=opus ;;
  FIX)     spine="survey docs code tests proof learn";                                                   cls=SIMPLE;  ceil=30000;  w2=opus ;;
  FEATURE) spine="promise survey spec clarify docs todo analyze tests code verify proof teach release learn"; cls=COMPLEX; ceil=150000; w2=opus ;;
  SCHEMA)  spine="promise survey spec reconcile clarify docs todo analyze tests code verify proof teach release learn"; cls=COMPLEX; ceil=200000; w2="$W2_SCHEMA" ;;
esac

printf '{"tier":"%s","spine":"%s","classifier":"%s","ceiling_tokens":%s,"w2_model":"%s"}\n' "$tier" "$spine" "$cls" "$ceil" "$w2"
