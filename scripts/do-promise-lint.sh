#!/usr/bin/env bash
# do-promise-lint.sh — verify a promise's contract form: the schedule ⇄ proof law.
#
# The promise is the statement of work an agency signs with a client
# (text/template-feature.md). This lint enforces,
# with zero LLM calls, that the contract has no gaps by construction:
#   1. proof: is non-empty (the acceptance test exists)
#   2. the schedule has ≥ 1 deliverable, and every `- item:` carries its own `accept:`
#   3. every accept: appears VERBATIM inside proof: — schedule ⊆ acceptance test,
#      so a deliverable that isn't proven cannot exist on the schedule
#   4. every assumes: check exits 0 — client-side dependencies green at the making
#      (skipped with --no-run)
#   5. with --red: proof exits NON-ZERO — red before green at PROMISE
#
# A promise with NO deliverables: block FAILS CLOSED (exit 1). It used to be
# reported and passed; a lint that certifies an unscheduled promise cannot hold
# the armed-red contract. cp text/template-feature.md and write the schedule.
#
# Usage:
#   do-promise-lint.sh <slug> [--no-run] [--red]     (file: text/<slug>.md, or $PROMISE_FILE)
#   do-promise-lint.sh --self-test
#
# Exit: 0 = well-formed · 1 = contract violation (a missing schedule is one) · 3 = missing
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

unquote() { # strip one layer of yaml quoting + trailing comment
  local line="$1"
  case "$line" in
    \"*) printf '%s' "$line" | sed -E 's/^"(.*)"[[:space:]]*(#.*)?$/\1/' | sed 's/\\"/"/g' ;;
    \'*) printf '%s' "$line" | sed -E "s/^'(.*)'[[:space:]]*(#.*)?\$/\1/" | sed "s/''/'/g" ;;
    *)   printf '%s' "$line" | sed -E 's/[[:space:]]+#.*$//' ;;
  esac
}

fm() { # $1 = file — print the first frontmatter block only
  awk '/^---[[:space:]]*$/{c++;next} c==1{print} c>=2{exit}' "$1"
}

extract_proof() { # $1 = file
  local line
  line="$(fm "$1" | awk '/^proof:/{print;exit}')"
  [ -z "$line" ] && return 1
  line="${line#proof:}"
  unquote "$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//')"
}

# print the deliverables: sub-block (from the key to the next top-level key)
deliverables_block() { # $1 = file
  fm "$1" | awk '/^deliverables:/{on=1;next} on && /^[a-zA-Z_-]+:/{exit} on{print}'
}

# print the assumes: list entries, one per line, unquoted
assumes_entries() { # $1 = file
  fm "$1" | awk '/^assumes:[[:space:]]*\[\]/{exit} /^assumes:/{on=1;next} on && /^[a-zA-Z_-]+:/{exit} on && /^[[:space:]]*-[[:space:]]/{sub(/^[[:space:]]*-[[:space:]]*/,"");print}' \
    | while IFS= read -r l; do unquote "$l"; echo; done
}

# exec_dry — IC6: catch a path-shape-fragile proof at PROMISE, before it dies
# at settle. Runs proof: for real (env -i, from $base) and inspects stderr for
# the classic bug: two deliverables' accept: joined by `&&`, each independently
# written assuming CWD=repo-root, e.g. "cd A && test 1 && cd A && test 2" — the
# second bare `cd A` runs from inside A (after the first leg), tries A/A, dies.
# Subshell-wrapped legs ("(cd A && test 1) && (cd A && test 2)") reset CWD
# between legs and never hit this. A non-zero exit alone is NOT a failure here —
# red-before-green proofs are legitimately red; only the path-shape death is.
exec_dry() { # $1 = file, $2 = base dir (default $ROOT)
  local file="$1" base="${2:-$ROOT}" proof err
  proof="$(extract_proof "$file")"
  if [ -z "$proof" ]; then
    echo "[promise-lint:exec-dry] FAIL — no proof: to test"
    return 1
  fi
  err="$(cd "$base" && env -i HOME="$HOME" PATH="$PATH" bash -c "$proof" 2>&1 1>/dev/null)"
  if printf '%s' "$err" | grep -qE 'cd: .*No such file or directory'; then
    echo "[promise-lint:exec-dry] FAIL — path-shape death (a repeated bare 'cd X &&' leg dies once a prior leg already moved CWD into X):"
    printf '%s\n' "$err" | grep -E 'cd: .*No such file or directory' | sed 's/^/  /'
    return 1
  fi
  echo "[promise-lint:exec-dry] OK — proof is path-shape safe (a non-zero exit here is fine; red-before-green is legitimate)"
  return 0
}

lint() { # $1 = slug, $2 = file, $3 = no_run (true/false), $4 = red (true/false)
  local slug="$1" file="$2" no_run="$3" red="$4" fails=0
  echo "[promise-lint] slug=$slug file=${file#"$ROOT"/}"
  [ -f "$file" ] || { echo "[promise-lint] FAIL — no promise file"; return 3; }

  if ! fm "$file" | grep -q '^deliverables:'; then
    echo "[promise-lint] FAIL — no deliverables: schedule (pre-schedule form, no longer certifiable)"
    echo "[promise-lint] every promise carries the schedule: cp text/template-feature.md"
    return 1
  fi

  local proof; proof="$(extract_proof "$file")"
  if [ -z "$proof" ]; then
    echo "[promise-lint] FAIL — schedule present but proof: empty (no acceptance test)"
    return 1
  fi

  local block items accepts
  block="$(deliverables_block "$file")"
  items="$(printf '%s\n' "$block" | grep -c '^[[:space:]]*-[[:space:]]*item:' || true)"
  accepts="$(printf '%s\n' "$block" | grep -c '^[[:space:]]*accept:' || true)"

  if [ "$items" -lt 1 ]; then
    echo "[promise-lint] FAIL — deliverables: has no '- item:' lines (empty schedule)"
    fails=$((fails+1))
  fi
  if [ "$items" -ne "$accepts" ]; then
    echo "[promise-lint] FAIL — $items item(s) but $accepts accept(s): every deliverable needs its own acceptance check"
    fails=$((fails+1))
  fi

  # every accept: must appear verbatim inside proof: (fixed-string match)
  local n=0
  while IFS= read -r raw; do
    [ -z "$raw" ] && continue
    n=$((n+1))
    local val
    val="$(unquote "$(printf '%s' "$raw" | sed -E 's/^[[:space:]]*accept:[[:space:]]*//')")"
    if [ -z "$val" ]; then
      echo "[promise-lint] FAIL — accept #$n is empty"
      fails=$((fails+1))
    elif ! printf '%s' "$proof" | grep -qF -- "$val"; then
      echo "[promise-lint] FAIL — accept #$n not inside proof: — deliverable unproven: $val"
      fails=$((fails+1))
    fi
  done <<EOF
$(printf '%s\n' "$block" | grep '^[[:space:]]*accept:')
EOF

  # story: the root document IS the story (text/docs.md, text/templates.md §
  # "The story fans out the templates"). The seven beats come first and the
  # schedule answers them. Same conservative shape as the page check below:
  # ABSENT is a WARN, because 210 promises predate the ruling and a hard fail
  # would retro-break every one of them; MALFORMED is a FAIL, because a story:
  # block that is present and missing beats was written to the new canon and
  # got it wrong, which is worse than not having written one.
  # Drive it red: strip a beat from any promise and re-run.
  local story_beats='world cast knock want way turn lesson'
  if ! grep -qE '^story:[[:space:]]*$' "$file"; then
    echo "[promise-lint] WARN — no story: block. The root document is the story (text/docs.md); the schedule should answer its beats."
  else
    local sblock missing=""
    sblock="$(awk '/^story:[[:space:]]*$/{f=1;next} f&&/^[a-zA-Z_-]+:[[:space:]]*$/{exit} f{print}' "$file")"
    local b
    for b in $story_beats; do
      printf '%s\n' "$sblock" | grep -qE "^[[:space:]]+$b:" || missing="$missing $b"
    done
    if [ -n "$missing" ]; then
      echo "[promise-lint] FAIL — story: present but missing beat(s):$missing — the seven beats are locked (world cast knock want way turn lesson)"
      fails=$((fails+1))
    fi
  fi

  # goal: the standing objective this promise serves (text/template-feature.md).
  # Same conservative shape as story: ABSENT is a WARN (every promise predates
  # the field), PRESENT-BUT-EMPTY is a FAIL, because a goal: block written and
  # left blank is worse than one not written. Drive it red: blank the objective.
  if ! grep -qE '^goal:[[:space:]]*$' "$file"; then
    echo "[promise-lint] WARN — no goal: block. Name the standing objective this promise serves (not story.want)."
  elif ! awk '/^goal:[[:space:]]*$/{f=1;next} f&&/^[a-zA-Z_-]+:[[:space:]]*$/{exit} f' "$file" \
       | grep -qE '^[[:space:]]+objective:[[:space:]]*["'"'"']?[^"'"'"'[:space:]]'; then
    echo "[promise-lint] FAIL — goal: present but objective: is empty — a blank goal is worse than none"
    fails=$((fails+1))
  fi

  # loop: what re-runs while the goal is unmet, and WHAT STOPS IT. The `until:`
  # list is the gate — a loop with no escape is not a loop, it is a bill. Same
  # conservative shape: ABSENT -> WARN, PRESENT WITHOUT `until:` -> FAIL.
  # Drive it red: delete the until: list from any promise carrying a loop.
  if ! grep -qE '^loop:[[:space:]]*$' "$file"; then
    echo "[promise-lint] WARN — no loop: block. Name what re-runs while the goal is unmet, and what stops it."
  elif ! awk '/^loop:[[:space:]]*$/{f=1;next} f&&/^[a-zA-Z_-]+:[[:space:]]*$/{exit} f' "$file" \
       | grep -qE '^[[:space:]]+until:'; then
    echo "[promise-lint] FAIL — loop: present with no until: — a loop with no escape is not a loop, it is a bill"
    fails=$((fails+1))
  fi

  # user-visible ⇒ page: a deliverable that explicitly names a page/route/view
  # (kind prefix `route:`/`page:`/`view:`/`component:`, an .astro / src/pages/
  # path, or the phrase "a page") must be proven by at least one accept: that
  # actually checks the page — curl / browser-check / do-prove / an http(s) URL /
  # a `--route /x` flag / a src/pages/ or .astro file check.
  # Heuristic is deliberately conservative (deliverables text only, NOT the
  # world: block) so settled promises whose UI is proven via vitest/grep
  # (brain, chat) don't retro-fail; it catches new promises that schedule a
  # page but never load it.
  local vis_re='(route|page|view|component):|src/pages/|\.astro| a page '
  local page_proof_re='curl|browser-check|do-prove|https?://|--route[[:space:]]+/|src/pages/|\.astro'
  local vis_item
  vis_item="$(printf '%s\n' "$block" | grep -E '^[[:space:]]*-[[:space:]]*item:' | grep -iE "$vis_re" | head -1)"
  if [ -n "$vis_item" ]; then
    if ! printf '%s\n' "$block" | grep '^[[:space:]]*accept:' | grep -qiE "$page_proof_re"; then
      echo "[promise-lint] FAIL — user-visible deliverable but no page-load proof:"
      echo "[promise-lint]   $(printf '%s' "$vis_item" | sed -E 's/^[[:space:]]*//')"
      echo "[promise-lint]   add a route/component deliverable whose accept: loads the page (curl / browser-check / do-prove.sh --route /x / src/pages file check)"
      fails=$((fails+1))
    fi
  fi

  # assumes: — client-side dependencies must be green at the making
  if [ "$no_run" != true ]; then
    local a_n=0
    while IFS= read -r a; do
      [ -z "$a" ] && continue
      a_n=$((a_n+1))
      if ! ( cd "$ROOT" && bash -c "$a" ) >/dev/null 2>&1; then
        echo "[promise-lint] FAIL — assumption #$a_n not true (contract can't be signed): $a"
        fails=$((fails+1))
      fi
    done <<EOF
$(assumes_entries "$file")
EOF
  fi

  # --red: red before green at PROMISE
  if [ "$red" = true ]; then
    if ( cd "$ROOT" && bash -c "$proof" ) >/dev/null 2>&1; then
      echo "[promise-lint] FAIL — proof already GREEN at PROMISE: already shipped (skip) or too weak to gate (rewrite)"
      fails=$((fails+1))
    else
      echo "[promise-lint] proof RED at PROMISE — correct (green is earned at PROVE)"
    fi
  fi

  if [ "$fails" -eq 0 ]; then
    echo "[promise-lint] OK — $items deliverable(s), schedule ⊆ proof, contract well-formed"
    return 0
  fi
  echo "[promise-lint] $fails violation(s) — the contract has gaps; fix the schedule before PROMISE closes"
  return 1
}

# check_ui_coupling — IC9 lint coupling: when a promise's derives: block has
# `ui: true`, its proof: must invoke `do-ui-gate.sh <slug>` (that promise's own
# filename stem) — a UI-bearing promise can't settle without its screens
# actually being gate-checked.
check_ui_coupling() { # $1 = file
  local file="$1" slug ui_val proof
  slug="$(basename "$file" .md)"
  ui_val="$(fm "$file" | awk '/^derives:/{on=1;next} on && /^[a-zA-Z_-]+:/{exit} on && /^[[:space:]]*ui:/{sub(/^[[:space:]]*ui:[[:space:]]*/,"");print;exit}')"
  ui_val="$(unquote "$ui_val" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  if [ "$ui_val" != "true" ]; then
    echo "[promise-lint:ui-coupling] skip — derives.ui != true (slug=$slug)"
    return 0
  fi
  proof="$(extract_proof "$file")"
  if printf '%s' "$proof" | grep -qF "do-ui-gate.sh $slug"; then
    echo "[promise-lint:ui-coupling] OK — proof invokes do-ui-gate.sh $slug"
    return 0
  fi
  echo "[promise-lint:ui-coupling] FAIL — derives.ui: true but proof: does not invoke 'do-ui-gate.sh $slug'"
  return 1
}

# ── self-test: ui-coupling fixtures, zero network ────────────────────────────
if [ "${1:-}" = "--self-test-ui-coupling" ]; then
  dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
  cat >"$dir/uinocheck.md" <<'F'
---
derives:
  ui:        true
proof: "true"
---
F
  cat >"$dir/uigood.md" <<'F'
---
derives:
  ui:        true
proof: "bash .claude/scripts/do-ui-gate.sh uigood"
---
F
  cat >"$dir/nouify.md" <<'F'
---
derives:
  ui:        false
proof: "true"
---
F
  fails=0
  check_ui_coupling "$dir/uinocheck.md" >/dev/null && { echo "FAIL: expected ui-coupling FAIL when ui:true but proof lacks do-ui-gate.sh"; fails=$((fails+1)); }
  check_ui_coupling "$dir/uigood.md" >/dev/null || { echo "FAIL: expected ui-coupling PASS when proof invokes do-ui-gate.sh <slug>"; fails=$((fails+1)); }
  check_ui_coupling "$dir/nouify.md" >/dev/null || { echo "FAIL: expected ui-coupling PASS (skip) when ui:false"; fails=$((fails+1)); }
  echo "[promise-lint] self-test-ui-coupling: 3 fixtures, $fails failed"
  exit "$fails"
fi

# ── self-test: fixtures, zero network ────────────────────────────────────────
if [ "${1:-}" = "--self-test" ]; then
  dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
  cat >"$dir/good.md" <<'F'
---
deliverables:
  - item: "route"
    accept: "test -f a"
  - item: "doc"
    accept: "grep -q x b.md"
assumes: []
proof: "test -f a && grep -q x b.md"
---
F
  cat >"$dir/gap.md" <<'F'
---
deliverables:
  - item: "route"
    accept: "test -f a"
  - item: "doc"
    accept: "grep -q x b.md"
proof: "test -f a"
---
F
  cat >"$dir/unchecked.md" <<'F'
---
deliverables:
  - item: "route"
    accept: "test -f a"
  - item: "doc"
proof: "test -f a"
---
F
  cat >"$dir/legacy.md" <<'F'
---
proof: "true"
---
F
  cat >"$dir/emptyproof.md" <<'F'
---
deliverables:
  - item: "route"
    accept: "test -f a"
proof: ""
---
F
  cat >"$dir/badassume.md" <<'F'
---
deliverables:
  - item: "route"
    accept: "test -f a"
assumes:
  - "false"
proof: "test -f a"
---
F
  cat >"$dir/pagegap.md" <<'F'
---
deliverables:
  - item: "route: /foo — user sees the page"
    accept: "grep -q foo a.ts"
proof: "grep -q foo a.ts"
---
F
  cat >"$dir/pagegood.md" <<'F'
---
deliverables:
  - item: "route: /foo — user sees the page"
    accept: "curl -sf https://one.ie/foo"
proof: "curl -sf https://one.ie/foo"
---
F
  # --red must DISCRIMINATE: a proof green at lint time is refused, a red one passes.
  cat >"$dir/redgreen.md" <<'F'
---
deliverables:
  - item: "a check that is already green at lint time"
    accept: "true"
proof: "true"
---
F
  cat >"$dir/redred.md" <<'F'
---
deliverables:
  - item: "a check that is still red at lint time"
    accept: "false"
proof: "false"
---
F
  fails=0
  lint good "$dir/good.md" true false >/dev/null        || { echo "FAIL good → 0"; fails=$((fails+1)); }
  lint gap "$dir/gap.md" true false >/dev/null          && { echo "FAIL gap → 1"; fails=$((fails+1)); }
  lint unchecked "$dir/unchecked.md" true false >/dev/null && { echo "FAIL unchecked → 1"; fails=$((fails+1)); }
  lint legacy "$dir/legacy.md" true false >/dev/null    && { echo "FAIL legacy → 1 (no deliverables: schedule — the lint fails closed)"; fails=$((fails+1)); }
  lint emptyproof "$dir/emptyproof.md" true false >/dev/null && { echo "FAIL emptyproof → 1"; fails=$((fails+1)); }
  lint badassume "$dir/badassume.md" false false >/dev/null && { echo "FAIL badassume → 1"; fails=$((fails+1)); }
  lint redcheck "$dir/gap.md" true true >/dev/null      && { echo "FAIL red-on-gap → 1"; fails=$((fails+1)); }
  lint pagegap "$dir/pagegap.md" true false >/dev/null  && { echo "FAIL pagegap → 1 (user-visible, no page proof)"; fails=$((fails+1)); }
  lint pagegood "$dir/pagegood.md" true false >/dev/null || { echo "FAIL pagegood → 0"; fails=$((fails+1)); }
  lint redgreen "$dir/redgreen.md" true true >/dev/null  && { echo "FAIL redgreen → 1 (--red must refuse a proof already GREEN at PROMISE)"; fails=$((fails+1)); }
  lint redred "$dir/redred.md" true true >/dev/null      || { echo "FAIL redred → 0 (--red must PASS a proof that is red at PROMISE)"; fails=$((fails+1)); }
  echo "[promise-lint] self-test: 11 fixtures, $fails failed"
  exit "$fails"
fi

# ── self-test: exec-dry fixtures, zero network ───────────────────────────────
if [ "${1:-}" = "--self-test-exec-dry" ]; then
  dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
  mkdir -p "$dir/leg"
  touch "$dir/leg/marker"
  cat >"$dir/failcase.md" <<'F'
---
proof: "cd leg && test -f marker && cd leg && test -f marker"
---
F
  cat >"$dir/passcase.md" <<'F'
---
proof: "(cd leg && test -f marker) && (cd leg && test -f marker)"
---
F
  fails=0
  exec_dry "$dir/failcase.md" "$dir" >/dev/null && { echo "FAIL: expected exec-dry FAIL on repeated bare 'cd leg &&' legs"; fails=$((fails+1)); }
  exec_dry "$dir/passcase.md" "$dir" >/dev/null || { echo "FAIL: expected exec-dry PASS on subshell-wrapped legs"; fails=$((fails+1)); }
  echo "[promise-lint] self-test-exec-dry: 2 fixtures, $fails failed"
  exit "$fails"
fi

# ── main ─────────────────────────────────────────────────────────────────────
SLUG="${1:-}"; [ -z "$SLUG" ] && { grep '^# ' "$0" | sed 's/^# //' | sed -n '3,24p'; exit 4; }
shift
NO_RUN=false; RED=false; EXEC_DRY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --no-run)   NO_RUN=true; shift ;;
    --red)      RED=true; shift ;;
    --exec-dry) EXEC_DRY=true; shift ;;
    *) echo "unknown flag $1"; exit 4 ;;
  esac
done
if $EXEC_DRY; then
  exec_dry "${PROMISE_FILE:-$ROOT/text/$SLUG.md}"
  exit $?
fi
lint "$SLUG" "${PROMISE_FILE:-$ROOT/text/$SLUG.md}" "$NO_RUN" "$RED"
