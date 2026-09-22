#!/usr/bin/env bash
# pr-body.sh — the pull request a finished branch deserves, derived, never written.
#
#   bash .claude/scripts/pr-body.sh feat/editor-panel-tabs
#   bash .claude/scripts/pr-body.sh do/my-plan --base main --gate "fast lane (green)"
#   bash .claude/scripts/pr-body.sh feat/x --dev "https://dev.one.ie — 2 routes proven"
#   bash .claude/scripts/pr-body.sh feat/x --title      # just the title line
#   bash .claude/scripts/pr-body.sh --self-test         # the red proofs
#
# WHY THIS EXISTS: a /do branch arrives at the merge door carrying no explanation.
# Context isolation throws away each cycle's reasoning to save 90-150k tokens, so
# the prose that would have justified the diff is gone by the time a human reads
# it. `do-auto.sh`'s `_merge_digest` solved that for the LOCAL reader by writing
# `.do-digest.md` at trunk root. A pull request is the same document with an
# audience: same facts, same sources, addressed to a reviewer instead of to the
# operator standing in the tree.
#
# EVERY FIELD IS DERIVED FROM GIT AT CALL TIME. It deliberately does NOT read
# `.do-digest.md`, even when one is sitting there: that file lives at trunk root,
# is uncommitted, is written per-slug and is overwritten by the next cycle, so a
# body that were "the digest when present, git otherwise" would be right
# sometimes and stale sometimes with nothing on its face to say which. Deriving
# every time is slower by milliseconds and always true.
#
# THE DIFF IS `merge-base..BR`, NEVER `BASE..BR`. Two-dot from the base conflates
# what this branch added with what trunk advanced while it was building — the
# latter reads as spurious reversions and inflates every count in the body. Same
# rule `_merge_digest` follows, and the same reason.
#
# A MEASUREMENT THAT IS NOT THERE IS NOT RENDERED. The trust score, the open
# improvements and the cycle count come from gitignored artifacts that exist only
# beside a live worktree; the plan title comes from a file that only a /do branch
# has. When one is absent its line is omitted — never printed as 0, "?" or
# "unknown", which read as measured facts.
#
# Exit codes: 0 emitted · 2 bad usage · 3 no such branch · 4 self-test failed.
set -uo pipefail
# The repo this reads. Overridable ONLY through a dedicated name so the
# self-test can point it at a scratch repo; a generic `ROOT` would inherit
# whatever a calling script happened to export and read the wrong tree.
ROOT="${PR_BODY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

BR="" BASE="main" GATE="" DEV="" TITLE_ONLY=0 SELF_TEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-main}"; shift 2 ;;
    --gate) GATE="${2:-}"; shift 2 ;;
    --dev) DEV="${2:-}"; shift 2 ;;
    --title) TITLE_ONLY=1; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*) echo "pr-body.sh: unknown flag '$1'" >&2; exit 2 ;;
    *) BR="$1"; shift ;;
  esac
done

# --- the plan behind a branch ------------------------------------------------
# `feat/editor-panel-tabs` and `do/editor-panel-tabs` are both the slug
# `editor-panel-tabs`; a bare branch name is its own slug.
slug_of() { printf '%s' "${1#*/}"; }

# The worktree holding a branch, if any. The gitignored build artifacts
# (.do-trust.json, .w4-improvements.json) live there and nowhere else, so a
# branch with no worktree simply reports fewer facts.
worktree_of() {
  git worktree list --porcelain \
    | awk -v b="refs/heads/$1" '/^worktree /{w=$2} /^branch /{if ($2==b) print w}' \
    | head -1
}

# THE PLAN IS READ FROM THE BRANCH, NOT FROM THE TREE THIS RUNS IN.
#
# A /do branch commits its own `text/<slug>-todo.md`, and that copy is the one
# whose cycles this branch actually closed. The checked-out tree may not have the
# file at all (a plan authored entirely on the branch) or may have a STALE copy —
# `do-auto.sh` blind-syncs `<slug>-plan.md` from main every iteration, so a tree
# copy is not evidence about a branch. Caught by the throwaway proof: reading
# $ROOT silently dropped the title, the cycle counts and the kill-switch, and the
# body still looked complete because every one of those lines is optional.
#
# Falls back to the working tree so a branch with no committed plan (a hand-made
# `feat/*`) can still pick up a plan that exists only locally.
todo_for() {
  local br="$1" slug="$2" out
  out="$(mktemp)"
  if git -C "$ROOT" show "${br}:text/${slug}-todo.md" > "$out" 2>/dev/null && [ -s "$out" ]; then
    printf '%s' "$out"; return 0
  fi
  rm -f "$out"
  [ -f "$ROOT/text/${slug}-todo.md" ] && { printf '%s' "$ROOT/text/${slug}-todo.md"; return 0; }
  return 1
}

# `title: Some Words` out of a todo's frontmatter. Frontmatter only — a `title:`
# in the body of a 900-line plan is somebody's YAML example, not the plan's name.
plan_title() {
  local f="$1"
  [ -f "$f" ] || return 1
  awk '
    NR==1 && $0=="---" { inside=1; next }
    inside && $0=="---" { exit }
    inside && /^title:[[:space:]]/ { sub(/^title:[[:space:]]*/, ""); print; exit }
  ' "$f"
}

emit() {
  local br="$1" base="$2"
  local mb behind shortstat slug todo wt title
  slug="$(slug_of "$br")"
  todo="$(todo_for "$br" "$slug" || true)"
  wt="$(worktree_of "$br")"

  mb="$(git -C "$ROOT" merge-base "$base" "$br" 2>/dev/null || printf '%s' "$base")"
  behind="$(git -C "$ROOT" rev-list --count "$mb..$base" 2>/dev/null || echo 0)"
  shortstat="$(git -C "$ROOT" diff --shortstat "$mb..$br" 2>/dev/null || true)"

  title="$(plan_title "$todo" 2>/dev/null || true)"
  # No plan, or a plan with no title: the branch's own first commit says what it
  # set out to do, which is the next most honest sentence available.
  [ -n "$title" ] || title="$(git -C "$ROOT" log --format=%s "$mb..$br" 2>/dev/null | tail -1)"
  [ -n "$title" ] || title="$br"

  if [ "$TITLE_ONLY" = "1" ]; then printf '%s\n' "$title"; return 0; fi

  echo "## What this is"
  echo
  echo "Branch \`${br}\` → \`${base}\`. Generated by \`.claude/scripts/pr-body.sh\` from git —"
  echo "every number below is derived at PR time, not written by hand or by a model."
  echo
  [ -n "$todo" ] && [ -f "$todo" ] && echo "Plan: \`text/${slug}-todo.md\`"
  [ -n "$todo" ] && [ -f "$todo" ] && echo

  # --- the counts ------------------------------------------------------------
  echo "## Receipts"
  echo
  if [ -n "$todo" ] && [ -f "$todo" ]; then
    local closed total
    closed="$(grep -cE '\[[xX]\] \*{0,2}C[0-9]+' "$todo" 2>/dev/null || true)"
    total="$(grep -cE '\[[ xX]\] \*{0,2}C[0-9]+' "$todo" 2>/dev/null || true)"
    [ "${closed:-0}" != "0" ] || [ "${total:-0}" != "0" ] \
      && echo "- **Cycles closed:** ${closed:-0} of ${total:-0}"
  fi
  echo "- **This branch's changes (merge-base..${br}):** ${shortstat:-none}"
  [ "${behind:-0}" -gt 0 ] \
    && echo "- **Trunk advanced during build:** ${behind} commit(s) — the diff above excludes them"

  # Mergeability WITHOUT mutating anything. `--write-tree` computes the merge in
  # the object store and says whether it conflicts; it does not touch a worktree,
  # an index or a ref, which is why this is safe to run against a shared trunk.
  if git -C "$ROOT" merge-tree --write-tree "$base" "$br" >/dev/null 2>&1; then
    echo "- **Merges cleanly into \`${base}\`:** yes"
  else
    echo "- **Merges cleanly into \`${base}\`:** NO — conflicts, resolve before merging"
  fi

  # Gate result is PASSED IN by the caller that actually ran one. This script
  # runs no gate, so it must never imply it did: no --gate, no line.
  [ -n "$GATE" ] && echo "- **Gate:** ${GATE}"

  # Same rule, one door further along: whether this branch was ever RUN, and
  # where. `--dev` is passed only by a caller that actually shipped the branch
  # to dev.one.ie and probed it. No flag, no line — a PR that says nothing
  # about dev is a PR whose branch was never run, and that is the honest read.
  [ -n "$DEV" ] && echo "- **Ran on dev:** ${DEV}"

  if [ -n "$wt" ] && [ -f "$wt/.do-trust.json" ]; then
    local trust composite
    trust="$(jq -r '.level // empty' "$wt/.do-trust.json" 2>/dev/null || true)"
    composite="$(jq -r '.composite // empty' "$wt/.do-trust.json" 2>/dev/null || true)"
    [ -n "$trust$composite" ] \
      && echo "- **Rubric:** trust=${trust:-—} · composite=${composite:-—}"
  fi
  if [ -n "$wt" ] && [ -f "$wt/.w4-improvements.json" ]; then
    local open
    open="$(jq -r 'if type=="array" then length elif type=="object" then ([.[]?]|length) else 0 end' \
      "$wt/.w4-improvements.json" 2>/dev/null || true)"
    [ -n "$open" ] && echo "- **Open improvements carried:** ${open}"
  fi

  # The kill-switch, quoted so a reviewer can run the same command the plan
  # gates on rather than taking "it works" on trust.
  if [ -n "$todo" ] && [ -f "$todo" ]; then
    local outcome
    outcome="$(awk '
      NR==1 && $0=="---" { inside=1; next }
      inside && $0=="---" { exit }
      inside && /^outcome:[[:space:]]/ { sub(/^outcome:[[:space:]]*/, ""); print; exit }
    ' "$todo" 2>/dev/null | sed 's/^"//; s/"$//')"
    if [ -n "$outcome" ]; then
      echo
      echo "**Outcome check** — the plan's own kill-switch, exits 0 when the goal is met:"
      echo
      echo '```bash'
      echo "$outcome"
      echo '```'
    fi
  fi

  echo
  echo "## Files changed (this branch only)"
  echo
  echo '```'
  git -C "$ROOT" diff --stat "$mb..$br" 2>/dev/null || true
  echo '```'
  echo
  echo "## Commits"
  echo
  echo '```'
  git -C "$ROOT" log --oneline "$mb..$br" 2>/dev/null || true
  echo '```'
}

# --- self-test ---------------------------------------------------------------
# The point is that each check can go RED. A body generator that emits a
# plausible paragraph no matter what it was handed proves nothing, and every
# claim below is one this script got wrong at least once while being written.
self_test() {
  local tmp fails=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  t_ok()  { printf '  ✓ %s\n' "$1"; }
  t_bad() { printf '  ✗ %s\n' "$1"; fails=$((fails+1)); }

  # A scratch repo, so the checks assert on a history they built themselves
  # rather than on whatever this repo happens to look like today.
  git init -q "$tmp/r" 2>/dev/null
  (
    cd "$tmp/r" || exit 1
    git config user.email t@t; git config user.name t; git config commit.gpgsign false
    echo base > a.txt; git add a.txt; git commit -qm "base commit"
    git checkout -q -b feat/scratch
    echo branch > b.txt; git add b.txt; git commit -qm "the branch's own first commit"
    git checkout -q master 2>/dev/null || git checkout -q main
    echo trunk >> a.txt; git add a.txt; git commit -qm "trunk moved on"
  )
  local basebr; basebr="$(cd "$tmp/r" && git rev-parse --abbrev-ref HEAD)"
  local out
  out="$(PR_BODY_ROOT="$tmp/r" bash "${BASH_SOURCE[0]}" feat/scratch --base "$basebr" 2>/dev/null)"

  # 1. The diff is merge-base scoped: the branch added b.txt and NOTHING else.
  #    A two-dot BASE..BR diff would also show a.txt as reverted.
  grep -q 'b.txt' <<<"$out" && ! grep -q 'a.txt' <<<"$out" \
    && t_ok "diff is merge-base scoped (trunk's own commit excluded)" \
    || t_bad "diff leaked trunk's changes — merge-base scoping is broken"

  # 2. Trunk drift is reported, not silently folded into the diff.
  grep -q 'Trunk advanced during build:\*\* 1 commit' <<<"$out" \
    && t_ok "trunk drift counted" || t_bad "trunk drift not reported"

  # 3. With no plan file and no worktree, the absent measurements are ABSENT —
  #    not rendered as 0 or "?". This is the claim that stops a body from
  #    reporting "Cycles closed: 0" about a branch that never had cycles.
  ! grep -qE 'Cycles closed|Rubric:|Open improvements' <<<"$out" \
    && t_ok "absent measurements are omitted, not zeroed" \
    || t_bad "rendered a measurement it never took"

  # 4. No --gate ⇒ no gate line. This script runs no gate and must not imply it.
  ! grep -q 'Gate:' <<<"$out" && t_ok "claims no gate it did not run" || t_bad "invented a gate result"

  # Same for --dev. A body that implies the branch was run on dev when nobody
  # shipped it is the same dishonesty as an invented gate, one door later.
  ! grep -q 'Ran on dev:' <<<"$out" \
    && t_ok "claims no dev run it did not do" || t_bad "invented a dev run"
  outd="$(PR_BODY_ROOT="$tmp/r" bash "${BASH_SOURCE[0]}" feat/scratch --base "$basebr" --dev "https://dev.one.ie — 1 route proven" 2>/dev/null)"
  grep -q 'Ran on dev:\*\* https://dev.one.ie' <<<"$outd" \
    && t_ok "reports the dev run it was handed" || t_bad "dropped the caller's dev result"
  local outg
  outg="$(PR_BODY_ROOT="$tmp/r" bash "${BASH_SOURCE[0]}" feat/scratch --base "$basebr" --gate "fast lane (green)" 2>/dev/null)"
  grep -q 'Gate:\*\* fast lane (green)' <<<"$outg" \
    && t_ok "reports the gate it was handed" || t_bad "dropped the caller's gate result"

  # 5. Title falls back to the branch's FIRST commit, not its last.
  local tl
  tl="$(PR_BODY_ROOT="$tmp/r" bash "${BASH_SOURCE[0]}" feat/scratch --base "$basebr" --title 2>/dev/null)"
  [ "$tl" = "the branch's own first commit" ] \
    && t_ok "title falls back to the branch's first commit" \
    || t_bad "title fallback wrong: got '$tl'"

  # 6. A conflicting branch is reported as conflicting. Without this the
  #    mergeability line is a constant that always says yes.
  (
    cd "$tmp/r" || exit 1
    git checkout -q -b feat/conflict "$basebr"
    printf 'totally different\n' > a.txt; git add a.txt; git commit -qm "rewrite a.txt"
    git checkout -q "$basebr"
    printf 'trunk rewrote it too\n' > a.txt; git add a.txt; git commit -qm "trunk rewrote a.txt"
  )
  local outc
  outc="$(PR_BODY_ROOT="$tmp/r" bash "${BASH_SOURCE[0]}" feat/conflict --base "$basebr" 2>/dev/null)"
  grep -q 'Merges cleanly into .*:\*\* NO' <<<"$outc" \
    && t_ok "a conflicting branch reads NO" || t_bad "conflict not detected — the line is a constant"
  grep -q 'Merges cleanly into .*:\*\* yes' <<<"$out" \
    && t_ok "a clean branch reads yes" || t_bad "clean branch misreported as conflicting"

  # 7. The plan is read from the BRANCH, not from the checked-out tree. This is
  #    the bug the throwaway PR proof caught: reading $ROOT silently dropped the
  #    title, the cycle counts and the kill-switch, and the body still looked
  #    complete, because every one of those lines is optional. Non-vacuous by
  #    construction — the plan exists ONLY on the branch, never in the tree.
  (
    cd "$tmp/r" || exit 1
    git switch -q -c do/planned "$basebr"
    mkdir -p text
    printf -- '---\ntitle: The Plan Name\nslug: planned\noutcome: "true"\n---\n\n- [x] C1 one\n- [ ] C2 two\n' > text/planned-todo.md
    git add text/planned-todo.md; git commit -qm "add the plan"
    git switch -q "$basebr"
  )
  local outp tlp
  [ ! -f "$tmp/r/text/planned-todo.md" ] \
    && t_ok "the plan is absent from the working tree (check is non-vacuous)" \
    || t_bad "self-test setup wrong — plan is in the tree, so this proves nothing"
  outp="$(PR_BODY_ROOT="$tmp/r" bash "${BASH_SOURCE[0]}" do/planned --base "$basebr" 2>/dev/null)"
  grep -q 'Cycles closed:\*\* 1 of 2' <<<"$outp" \
    && t_ok "cycle counts read from the branch's own plan" \
    || t_bad "cycle counts not read from the branch"
  grep -q 'kill-switch' <<<"$outp" \
    && t_ok "kill-switch read from the branch's own plan" \
    || t_bad "kill-switch not read from the branch"
  tlp="$(PR_BODY_ROOT="$tmp/r" bash "${BASH_SOURCE[0]}" do/planned --base "$basebr" --title 2>/dev/null)"
  [ "$tlp" = "The Plan Name" ] \
    && t_ok "title read from the branch's own plan" \
    || t_bad "title not read from the branch: got '$tlp'"

  printf '\n'
  [ "$fails" -eq 0 ] && { echo "pr-body.sh: all checks pass"; return 0; }
  echo "pr-body.sh: ${fails} check(s) FAILED"; return 1
}

if [ "$SELF_TEST" = "1" ]; then self_test || exit 4; exit 0; fi

[ -n "$BR" ] || { echo "pr-body.sh: name a branch" >&2; exit 2; }
git -C "$ROOT" show-ref --verify --quiet "refs/heads/$BR" \
  || { echo "pr-body.sh: no such branch '$BR'" >&2; exit 3; }

emit "$BR" "$BASE"
