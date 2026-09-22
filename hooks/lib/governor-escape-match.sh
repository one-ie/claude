#!/usr/bin/env bash
# governor-escape-match.sh — ONE definition of "this command escapes the governor".
#
# Sourced by BOTH .claude/hooks/governor-escape.sh (the enforcement) and
# .claude/scripts/governor-escape-check.sh (the proof). load-guard.sh and
# load-guard-check.sh keep two copies of their regex; that is a drift bug
# waiting to happen and this file exists so this guard never has one.
#
# SCOPE — deliberately the four ESCAPE HATCHES, not every heavy command.
#
#   1. `bun run verify:raw`   web/package.json — the ungoverned verify
#   2. `bun run test:raw`     web/package.json — a bare `vitest run`
#   3. a directly-typed `vitest` / `npx vitest` / `bunx vitest`
#   4. `GOVERN_DISABLE=1` or `CI=1` in front of a gate
#      (gate-run.sh:26 execs straight through on either)
#
# A bare `tsc --noEmit` or `astro check` is NOT here on purpose. Those are
# ordinary heavy commands with legitimate uses; hook:load-guard already denies
# them once the box is saturated. Denying them unconditionally would be the
# false positive that gets this hook switched off, which is worse than not
# having it. Do not "fix" that.
#
# Contract:
#   gov_escape_kind "<command string>"
#     prints  env|raw|vitest  and returns 0  -> this command escapes the governor
#     prints  nothing         and returns 1  -> it does not

# Command POSITION: start of a line, or just after a shell operator, allowing a
# run of leading VAR=value assignments. Anchoring here is what stops the guard
# firing on a command that merely NAMES an escape -- a `git commit -m` whose
# message quotes it, a `grep` looking for it, a `sed` reading package.json.
GOV_POS='(^|[;&|(]|&&|\|\|)[[:space:]]*'
GOV_ENV='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'

# 4. an env bypass sitting at command position...
GOV_RE_ENVPOS="${GOV_POS}${GOV_ENV}(GOVERN_DISABLE|CI)="
# ...in front of something that is actually a gate. Both halves must hold, so
# `GOVERN_DISABLE=1 ls` and `CI=1 bun run build` are left alone.
GOV_RE_GATETOKEN='(vitest|gate-run\.sh|tsc[[:space:]]+--noEmit|astro[[:space:]]+check|playwright[[:space:]]+test|(bun|npm|pnpm|yarn)[[:space:]]+run[[:space:]]+(verify|test|typecheck|check))'

# 1+2. any `:raw` package script -- their entire purpose is bypassing the cap.
GOV_RE_RAW="${GOV_POS}${GOV_ENV}(bun|npm|pnpm|yarn)[[:space:]]+run[[:space:]]+[A-Za-z0-9:_.-]*:raw([[:space:]]|\$)"

# 3. vitest invoked directly, however it is reached.
GOV_RE_VITEST="${GOV_POS}${GOV_ENV}((bunx|npx|pnpm[[:space:]]+dlx|bun[[:space:]]+x|yarn[[:space:]]+dlx)[[:space:]]+)?([A-Za-z0-9_./-]*/)?vitest([[:space:]]|\$)"

# A heredoc BODY is data, not commands, and `grep -E '^...'` anchors per LINE --
# so `cat > f <<'EOF'` whose body has a line starting with an escape would match
# on `^`. Writing a doc or a script that quotes an escape is exactly the innocent
# act this guard must not refuse. Drop heredoc bodies before matching.
_gov_strip_heredocs() {
  awk '
    term != "" { if ($0 == term) term = ""; next }
    {
      if (match($0, /<<-?[[:space:]]*("[^"]+"|\047[^\047]+\047|[A-Za-z_][A-Za-z0-9_]*)/)) {
        t = substr($0, RSTART, RLENGTH)
        sub(/^<<-?[[:space:]]*/, "", t)
        gsub(/["\047]/, "", t)
        term = t
      }
      print
    }
  '
}

gov_escape_kind() {
  local cmd
  cmd="$(printf '%s' "${1:-}" | _gov_strip_heredocs)"
  [ -n "$cmd" ] || return 1

  # ORDER MATTERS. The env bypass is checked FIRST, because
  # `GOVERN_DISABLE=1 bash gate-run.sh verify -- …` turns the governor itself
  # into a plain exec -- it is an escape even though it names gate-run.sh.
  if printf '%s' "$cmd" | grep -qE "$GOV_RE_ENVPOS" \
     && printf '%s' "$cmd" | grep -qE "$GOV_RE_GATETOKEN"; then
    printf 'env'; return 0
  fi

  # Governed -- gate-run.sh takes the slot, bounds the wall clock and reaps the
  # process group, so whatever it wraps is not an escape.
  # Known limit: this is a whole-command carve-out (the same one load-guard.sh:39
  # makes), so `vitest run x && bash gate-run.sh …` reads as governed.
  printf '%s' "$cmd" | grep -q 'gate-run\.sh' && return 1

  printf '%s' "$cmd" | grep -qE "$GOV_RE_RAW"    && { printf 'raw';    return 0; }
  printf '%s' "$cmd" | grep -qE "$GOV_RE_VITEST" && { printf 'vitest'; return 0; }
  return 1
}
