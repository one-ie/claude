#!/usr/bin/env bash
# incident.sh — the accounts, fetched when they are relevant, not carried always.
#
# manifest: monorepo-only
#
# THE PROBLEM IT SOLVES. 35,752 lines of shell under .claude/scripts/, of which
# 10,961 — THIRTY PERCENT — are comments, and most of that is incident history:
# the day a thing was measured, the sha, the count, what was diagnosed wrong
# first. Every one of those lines is load-bearing (it is why the code has the
# shape it has) and every one of them is paid for on every read, by every human
# and every agent, whether or not it is relevant to the edit in hand.
#
# THE SPLIT. A comment block is two different things wearing one coat:
#
#   the RULE     imperative, 1-2 lines, true at the line it guards.
#                "Never pipe a gate." "gc measures against origin/main."
#                STAYS INLINE. Moving it is how a trap stops biting.
#
#   the ACCOUNT  the story that earned the rule — dates, shas, counts, the
#                wrong diagnosis that came first. Read ONCE, when you are about
#                to change that code or doubt that rule. MOVES HERE, VERBATIM.
#
# Nothing is paraphrased and nothing is deleted: a trap loses its authority the
# moment it is summarised, so the account moves whole and the rule stays put.
# The script keeps a `# incident:<id>` pointer, which is the guarantee — an
# agent with no inherited context still sees it in the file it is editing and
# needs one command.
#
# Usage:
#   incident.sh                      # every family, with counts
#   incident.sh <family>             # the whole family (e.g. sweep, deploy)
#   incident.sh <id>                 # one account
#   incident.sh --for <script>       # every account that script points at
#   incident.sh --check              # parity, both directions, both copies
#   incident.sh --self-test          # prove --check can go red
#
# WHY --check IS NOT OPTIONAL. A pointer to a moved section is worse than no
# pointer: it reads as authority and resolves to nothing. So the check runs both
# ways — every `# incident:<id>` in a script resolves to a `## <id>` here, and
# every `## <id>` here is pointed at by at least one script. An orphaned account
# is an account nobody will ever be shown.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${INCIDENT_ROOT:-$(cd "$HERE/../.." && pwd)}"
DIR="$ROOT/.claude/incidents"
# Both copies, or the check lies: packages/claude/ is a hand-maintained verbatim
# mirror with no build step, so it rots silently.
SCRIPT_DIRS=("$ROOT/.claude/scripts" "$ROOT/packages/claude/scripts")

say() { printf '%s\n' "$*"; }
ok()  { printf '  ok   %s\n' "$*"; }
bad() { printf '  RED  %s\n' "$*" >&2; }

# _ids_declared — every `## <id>` across the ledger.
_ids_declared() { grep -h '^## ' "$DIR"/*.md 2>/dev/null | sed 's/^## //' | sort -u; }

# _ids_in — ONE matcher for every `incident:<id>` token, used by --check AND by
# --for. They had two, and the two drifted within the hour: --for still carried
# the older `#[[:space:]]*incident:` form, which requires the token to follow the
# `#` directly — so every pointer written at the END of a rule line was invisible
# to it. `--check` reported 32 reachable while `--for deploy.sh` found 9, and only
# one of them was right. A checker that re-implements what it checks proves only
# that two copies agree.
#
# The token is `incident:` immediately followed by the id, with NO space. That is
# what keeps a sentence out of the count: `incident: demo` (spaced) is prose and
# never matches, so a script that merely talks about an incident does not claim
# to point at one. Presence greps are not proof; this one has a shape.
#
# AND IT SKIPS ITSELF, which is not fastidiousness. This file's --self-test
# writes fixture scripts containing `# incident:demo-one` and friends; scanned,
# the checker reported its own test data as three DANGLING production pointers
# (measured 2026-09-17, first run). A checker that reads its own fixtures is
# measuring the test, not the tree. The cost is that a real pointer inside
# incident.sh would be invisible — there are none, by construction.
_ids_in() { # <file-or-dir>...
  grep -rhoE 'incident:[A-Za-z0-9_-]+' "$@" 2>/dev/null \
    --exclude=incident.sh | sed 's/.*incident://' | sort -u
}
_ids_referenced() { _ids_in "${SCRIPT_DIRS[@]}"; }

_section() { # <id> — print that one account
  local id="$1" f
  for f in "$DIR"/*.md; do
    awk -v id="$id" '
      $0 == "## " id {inside=1; print; next}
      inside && /^## / {exit}
      inside {print}
    ' "$f"
  done
}

cmd_check() {
  local rc=0 id decl ref miss=0 orph=0
  [ -d "$DIR" ] || { bad "no ledger at $DIR"; return 1; }
  decl="$(_ids_declared)"; ref="$(_ids_referenced)"
  say "── incident ledger ──"
  say "  declared=$(printf '%s\n' "$decl" | grep -c . ) referenced=$(printf '%s\n' "$ref" | grep -c . )"
  # A pointer that resolves to nothing.
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    printf '%s\n' "$decl" | grep -qx "$id" || { bad "DANGLING pointer: # incident:$id — no '## $id' in .claude/incidents/"; miss=$((miss+1)); rc=1; }
  done <<< "$ref"
  # An account nobody is ever shown.
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    printf '%s\n' "$ref" | grep -qx "$id" || { bad "ORPHAN account: ## $id — no script points at it"; orph=$((orph+1)); rc=1; }
  done <<< "$decl"
  [ $rc -eq 0 ] && ok "every pointer resolves, every account is reachable"
  say "  dangling=$miss orphans=$orph"
  return $rc
}

cmd_self_test() {
  local tmp rc=0 out
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/.claude/incidents" "$tmp/.claude/scripts" "$tmp/packages/claude/scripts"
  say "── incident.sh --self-test ──"

  # 1. a matched pair is green
  printf '## demo-one\n\nthe account.\n' > "$tmp/.claude/incidents/demo.md"
  printf '#!/usr/bin/env bash\n# incident:demo-one\n' > "$tmp/.claude/scripts/x.sh"
  out="$( INCIDENT_ROOT="$tmp" bash "$HERE/incident.sh" --check 2>&1 )" \
    && ok "matched pair passes" || { bad "matched pair failed: $out"; rc=1; }

  # 2. a DANGLING pointer must fail — this is the failure the whole ledger
  #    exists to prevent: a pointer that reads as authority and resolves to
  #    nothing.
  printf '#!/usr/bin/env bash\n# incident:demo-gone\n' > "$tmp/.claude/scripts/y.sh"
  if INCIDENT_ROOT="$tmp" bash "$HERE/incident.sh" --check >/dev/null 2>&1; then
    bad "a dangling pointer passed the check"; rc=1
  else ok "a dangling pointer goes RED"; fi
  rm -f "$tmp/.claude/scripts/y.sh"

  # 3. an ORPHANED account must fail — an account nobody is shown is an account
  #    that rots without anyone noticing.
  printf '## demo-one\n\nthe account.\n\n## demo-orphan\n\nnobody points here.\n' > "$tmp/.claude/incidents/demo.md"
  if INCIDENT_ROOT="$tmp" bash "$HERE/incident.sh" --check >/dev/null 2>&1; then
    bad "an orphaned account passed the check"; rc=1
  else ok "an orphaned account goes RED"; fi

  # 4. the MIRROR counts as a referencing copy — canon green while the mirror
  #    rots is the trap do-plan-json-batches was written for.
  printf '## demo-one\n\nthe account.\n\n## demo-mirror\n\nonly the mirror points here.\n' > "$tmp/.claude/incidents/demo.md"
  printf '#!/usr/bin/env bash\n# incident:demo-mirror\n' > "$tmp/packages/claude/scripts/z.sh"
  INCIDENT_ROOT="$tmp" bash "$HERE/incident.sh" --check >/dev/null 2>&1 \
    && ok "the mirror copy is scanned too" || { bad "the mirror copy was not scanned"; rc=1; }

  # 5. a mention in PROSE is not a reference. (Clearing z.sh first is not
  #    housekeeping — leaving it made this case go red on a DANGLING pointer
  #    from case 4, which is the check working and the fixture lying. A fixture
  #    looser than the case it claims to test certifies nothing.)
  rm -f "$tmp/packages/claude/scripts/z.sh"
  printf '## demo-one\n\nthe account.\n' > "$tmp/.claude/incidents/demo.md"
  printf '#!/usr/bin/env bash\n# incident:demo-one\n# talk about incident: demo-prose here\n' > "$tmp/.claude/scripts/x.sh"
  INCIDENT_ROOT="$tmp" bash "$HERE/incident.sh" --check >/dev/null 2>&1 \
    && ok "a spaced-out mention is not counted as a pointer" || { bad "prose counted as a pointer"; rc=1; }

  # 6. --for and --check read the SAME tokens. They did not: --for missed every
  #    pointer written at the end of a line, and reported 9 of 24.
  printf '## demo-tail\n\nthe account.\n' >> "$tmp/.claude/incidents/demo.md"
  printf '#!/usr/bin/env bash\n# a rule, stated first.        incident:demo-tail\n' \
    > "$tmp/.claude/scripts/tail.sh"
  # NOT `... | grep -q`. Under `set -o pipefail` grep -q exits on the FIRST match
  # and closes the pipe, the upstream bash takes SIGPIPE and exits 141, and the
  # pipeline status is 141 — so a case that PASSED reads as RED. It did, here,
  # for ten minutes, while the --for output being tested was visibly correct.
  _for_out="$( INCIDENT_ROOT="$tmp" bash "$HERE/incident.sh" --for "$tmp/.claude/scripts/tail.sh" 2>/dev/null )"
  case "$_for_out" in
    "## demo-tail"*) ok "--for finds a pointer at the END of a line" ;;
    *) bad "--for missed an end-of-line pointer"; rc=1 ;;
  esac
  rm -f "$tmp/.claude/scripts/tail.sh"
  printf '## demo-one\n\nthe account.\n' > "$tmp/.claude/incidents/demo.md"

  # 7. the checker does not scan itself — its own fixtures are not pointers.
  cp "$HERE/incident.sh" "$tmp/.claude/scripts/incident.sh"
  INCIDENT_ROOT="$tmp" bash "$HERE/incident.sh" --check >/dev/null 2>&1 \
    && ok "incident.sh's own fixtures are not counted as pointers" \
    || { bad "the checker scanned itself"; rc=1; }

  rm -rf "$tmp"
  say ""
  [ $rc -eq 0 ] && say "  self-test PASS" || say "  self-test RED"
  return $rc
}

case "${1:-}" in
  --check)     cmd_check; exit $? ;;
  --self-test) cmd_self_test; exit $? ;;
  --for)
    [ -n "${2:-}" ] || { say "usage: incident.sh --for <script>"; exit 2; }
    ids="$(_ids_in "$2")"
    [ -n "$ids" ] || { say "no incident pointers in $2"; exit 0; }
    while IFS= read -r id; do [ -n "$id" ] && _section "$id" && say ""; done <<< "$ids"
    exit 0 ;;
  "")
    say "incident ledger — .claude/incidents/"
    for f in "$DIR"/*.md; do
      [ -e "$f" ] || { say "  (empty)"; break; }
      say "  $(basename "${f%.md}")  ($(grep -c '^## ' "$f") account(s))"
    done
    say ""
    say "  incident.sh <family> | <id> | --for <script> | --check"
    exit 0 ;;
  *)
    if [ -f "$DIR/$1.md" ]; then cat "$DIR/$1.md"; exit 0; fi
    out="$(_section "$1")"
    [ -n "$out" ] && { printf '%s\n' "$out"; exit 0; }
    say "no family or account named '$1' — try: incident.sh"; exit 2 ;;
esac
