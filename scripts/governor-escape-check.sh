#!/usr/bin/env bash
# governor-escape-check.sh — proof for hook:governor-escape, both directions.
#
#   bash .claude/scripts/governor-escape-check.sh
#
# Three parts, and the third is the one that makes the first two mean anything:
#
#   A  the matcher's case table — every escape BLOCKS, and every innocent
#      command that merely NAMES an escape is ALLOWED. A guard with false
#      positives gets switched off, which is worse than no guard at all.
#   B  the REAL hook, driven end to end with a real payload on stdin. A
#      matcher-only table stays green while the hook is broken (a wrong jq
#      path, a missing tool_name guard, malformed deny JSON), so at least one
#      BLOCK and one allow go through the actual file.
#   C  the RED PROOF. Gut the matcher and assert A goes red; neuter the hook
#      (ECC_DISABLED_HOOKS) and assert B goes red. A checker that stays green
#      against a gutted subject proves nothing — the same argument
#      govern-claims-check.sh makes when it stubs _gv_alive.
#
# Exits non-zero on any failure. Touches nothing outside a temp dir.
# Test-case strings deliberately avoid absolute monorepo paths: this script is
# classified `portable` in factory-repo.sh's manifest, and --check-portability
# greps the file CONTENTS for them.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MATCH="${GOV_MATCH_FILE:-$ROOT/.claude/hooks/lib/governor-escape-match.sh}"
HOOK="$ROOT/.claude/hooks/governor-escape.sh"
# shellcheck source=/dev/null
. "$MATCH"

# A stray ECC_DISABLED_HOOKS in the operator's environment would neuter part B
# and read as a red. Clear it for the real run; part C sets it explicitly on the
# child it wants neutered.
[ -z "${GOV_CHECK_INNER:-}" ] && unset ECC_DISABLED_HOOKS

bad=0
ok()   { printf '  ok    %s\n' "$*"; }
nope() { printf '  FAIL  %s\n' "$*"; bad=$((bad + 1)); }

# ---------------------------------------------------------------------------
# A — the matcher
# ---------------------------------------------------------------------------
m_check() { # m_check <BLOCK|allow> <label> <command>
  local want="$1" label="$2" cmd="$3" kind
  kind="$(gov_escape_kind "$cmd")"
  local got="allow"; [ -n "$kind" ] && got="BLOCK"
  if [ "$got" = "$want" ]; then ok "$want  $label${kind:+  [$kind]}"
  else nope "$want expected, got $got  —  $label"; fi
}

part_a() {
  echo "== A. matcher — escapes must BLOCK"
  m_check BLOCK 'bun run test:raw'            'cd web && bun run test:raw'
  m_check BLOCK 'bun run verify:raw'          'bun run verify:raw'
  m_check BLOCK 'bunx vitest run <file>'      'bunx vitest run tests/unit/foo.test.ts'
  m_check BLOCK 'npx vitest'                  'npx vitest'
  m_check BLOCK 'bare vitest run'             'vitest run'
  m_check BLOCK 'path-invoked vitest'         'node_modules/.bin/vitest run'
  m_check BLOCK 'vitest after an operator'    'echo starting; bunx vitest run'
  m_check BLOCK 'GOVERN_DISABLE in front'     'GOVERN_DISABLE=1 bun run verify'
  m_check BLOCK 'CI=1 in front'               'CI=1 bunx vitest run'
  m_check BLOCK 'env bypass beats gate-run'   'GOVERN_DISABLE=1 bash .claude/scripts/gate-run.sh verify -- bun run verify'

  echo "== A. matcher — merely NAMING an escape must be allowed"
  m_check allow 'the governed form'           'bash .claude/scripts/gate-run.sh test -- bunx vitest run tests/unit/foo.test.ts'
  m_check allow 'governed package script'     'cd web && bun run verify'
  m_check allow 'the dev lane'                'cd web && bun run verify:fast'
  m_check allow 'a commit message'            "git commit -m 'fix: bun run test:raw is the escape hatch'"
  m_check allow 'grepping for it'             'grep -rn "verify:raw" web/package.json'
  m_check allow 'reading package.json'        "sed -n '47,48p' web/package.json"
  m_check allow 'reading the vitest config'   'cat web/vitest.config.ts'
  m_check allow 'echoing the override'        'echo "GOVERN_DISABLE=1 bun run verify is the override"'
  m_check allow 'env bypass, but no gate'     'GOVERN_DISABLE=1 ls -la'
  m_check allow 'CI=1 on a non-gate'          'CI=1 bun run build'
  m_check allow 'reading the hook itself'     'cat .claude/hooks/governor-escape.sh'
  m_check allow 'tsc is out of scope'         'bunx tsc --noEmit'
  # THE FALSE POSITIVE THAT ALREADY BIT SOMEONE. hook:load-guard REFUSES this
  # command: the `|` INSIDE the quoted regex is a shell-operator position as
  # far as a position-anchored pattern is concerned, and what follows it is
  # `tsc --noEmit'` -- which load-guard.sh:57 matches as a bare alternative.
  # Reading `ps` is not running a gate. This guard cannot reproduce it: the
  # vitest rule needs the literal word `vitest` at that position, and tsc is
  # deliberately out of scope -- so the scope decision is load-bearing, not
  # incidental.
  m_check allow 'ps piped into grep'          "ps -Ao rss,command | grep -E 'vitest|tsc --noEmit'"
  m_check allow 'ps grep, vitest first'       "ps -Ao command | grep -E 'vitest|astro check'"
  m_check allow 'pgrep for a runner'          'pgrep -fl vitest'
  # The heredoc case. `grep -E` anchors ^ per LINE, so a doc BODY quoting an
  # escape would match without _gov_strip_heredocs. Writing about the escape is
  # the most innocent act there is.
  m_check allow 'heredoc body quoting it'     "$(printf '%s\n' \
    "cat > notes.md <<'EOF'" \
    'bun run test:raw is the ungoverned lane' \
    'GOVERN_DISABLE=1 bun run verify bypasses the cap' \
    'EOF')"
}

# ---------------------------------------------------------------------------
# B — the real hook, end to end
# ---------------------------------------------------------------------------
h_deny() { # h_deny <command>  -> prints "deny" or "allow"
  local payload out
  payload="$(jq -nc --arg c "$1" --arg d "$ROOT" \
    '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}')"
  out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$ROOT" bash "$HOOK" 2>&1)"
  case "$out" in *'"permissionDecision":"deny"'*) printf 'deny' ;; *) printf 'allow' ;; esac
}

part_b() {
  echo "== B. the hook itself, driven with a real payload"
  local got
  got="$(h_deny 'cd web && bun run test:raw')"
  [ "$got" = "deny" ] && ok "hook DENIES  bun run test:raw" \
                      || nope "hook did not deny  bun run test:raw  (got $got)"
  got="$(h_deny 'GOVERN_DISABLE=1 bun run verify')"
  [ "$got" = "deny" ] && ok "hook DENIES  GOVERN_DISABLE=1 bun run verify" \
                      || nope "hook did not deny the env bypass  (got $got)"
  got="$(h_deny "git commit -m 'fix: bun run test:raw is the escape hatch'")"
  [ "$got" = "allow" ] && ok "hook ALLOWS a commit message that quotes it" \
                       || nope "hook denied an innocent commit message — FALSE POSITIVE"
  got="$(h_deny 'bash .claude/scripts/gate-run.sh test -- bunx vitest run tests/unit/foo.test.ts')"
  [ "$got" = "allow" ] && ok "hook ALLOWS the governed form" \
                       || nope "hook denied the governed form (got $got)"

  # The documented human override must actually work, or nobody can get past it.
  local payload out
  payload="$(jq -nc --arg c 'bun run test:raw' --arg d "$ROOT" \
    '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}')"
  out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$ROOT" \
        ECC_DISABLED_HOOKS=hook:governor-escape bash "$HOOK" 2>&1)"
  case "$out" in
    *'"permissionDecision":"deny"'*) nope "ECC_DISABLED_HOOKS=hook:governor-escape did NOT disable it" ;;
    *) ok "ECC_DISABLED_HOOKS=hook:governor-escape releases it (the human override)" ;;
  esac
}

# ---------------------------------------------------------------------------
# C — the red proof
# ---------------------------------------------------------------------------
part_c() {
  echo "== C. red proof — gut the subject, the checks must go RED"
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # C1 — a matcher that never matches. If part A still passes, part A is theatre.
  { cat "$MATCH"; printf '\ngov_escape_kind() { return 1; }\n'; } > "$tmp/stub.sh"
  if GOV_CHECK_INNER=matcher GOV_MATCH_FILE="$tmp/stub.sh" \
       bash "${BASH_SOURCE[0]}" >"$tmp/a.log" 2>&1; then
    nope "matcher gutted to always-allow and part A STILL PASSED"
  else
    ok "matcher gutted -> part A goes red ($(grep -c '^  FAIL' "$tmp/a.log") failures)"
  fi

  # C2 — a hook that cannot deny. If part B still passes, part B is theatre.
  if GOV_CHECK_INNER=hook ECC_DISABLED_HOOKS=hook:governor-escape \
       bash "${BASH_SOURCE[0]}" >"$tmp/b.log" 2>&1; then
    nope "hook disabled and part B STILL PASSED"
  else
    ok "hook disabled -> part B goes red ($(grep -c '^  FAIL' "$tmp/b.log") failures)"
  fi
}

case "${GOV_CHECK_INNER:-}" in
  matcher) part_a ;;
  hook)    part_b ;;
  *)       part_a; echo; part_b; echo; part_c ;;
esac

echo
if [ "$bad" -eq 0 ]; then echo "RESULT: PASS — the guard bites, and it does not bite the innocent"
else echo "RESULT: RED — $bad failure(s)"; exit 1; fi
