#!/usr/bin/env bash
# one-sync.sh — one-way, ADDITIVE sync: one-ie -> apps/one (github.com/one-ie/one).
# CLASS: monorepo-only (factory-repo.sh manifest) — maintainer tooling. It reads
# public_manifest() and writes a sibling clone; neither exists downstream.
#
# THIS IS NOT A MIRROR, AND THE DIFFERENCE IS THE WHOLE POINT.
# vespio-sync.sh mirrors: `rm -rf dst; cp -RL src dst`. Vespio is our private
# agency tree and the monorepo is its upstream, so overwriting is correct there.
# apps/one is PUBLIC and its .claude/ is a HAND-AUTHORED DERIVATIVE. Measured
# 2026-09-22: seven items exist in both trees and differ, and in every case the
# PUBLIC one is the correct one for its tree —
#
#   skills/astro      ours 374 lines, Astro 6, one.ie/web | theirs 44 lines, Astro 7
#   skills/react19    ours 391 lines, one.ie/web islands  | theirs 41, @oneie/react
#   skills/shadcn     ours 516 lines, one.ie/web ui/      | theirs 27, 6-token only
#   skills/sdk        ours: authoring receivers           | theirs: oneClient()
#   commands/create.md · commands/deploy.md · rules/design.md — re-authored
#
# A mirror would replace right docs with wrong docs in a repo with 125 stars.
# text/opensource-release-plan.md records the same class of near-miss ("a
# template->apps/one push would have silently destroyed apps/one-only work"),
# which is why the template->apps/one push path was deleted from release.sh.
# So: this script ADDS what is absent, REFUSES what diverged (and names it for
# a human), and can never DELETE. It never commits and never pushes.
#
#   bash .claude/scripts/one-sync.sh --check    # read-only: ADD / DIVERGED / SAME
#   bash .claude/scripts/one-sync.sh --report   # what is held back, and why
#   bash .claude/scripts/one-sync.sh            # stage, gate, install, show the diff
#   bash .claude/scripts/one-sync.sh --self-test # prove the gates can go RED
#
# THE AUTHORITY IS public_manifest() IN factory-repo.sh — a second, independent
# axis from the manifest() vespio-sync.sh reads. Silence there means EXCLUDED,
# the safe default for a public destination. Read that function's header before
# adding a row; it records what doctrine refuses and why.
#
# THREE GATES run on the STAGED copy, before anything lands. A row cannot rot
# into a lie between the day it was classified and the day it ships:
#   leak      — a secret-shaped string
#   cites     — a monorepo path (one.ie/web, packages/*/src, schema/*.tql,
#               resolvers/, channels/src, pay/backend, .claude/scripts/) that
#               survives the transform. This is the same grep that decided the
#               rows; running it again is what makes the classification checkable.
#   owner     — an operator or agency NAME (Donal, Tony, OO, vespio) or a
#               `source: oo-internal` stamp. The citation grep cannot see this
#               and it shipped six rag-*.md skills that were pure operator
#               working practice. A document says whose it is with names as
#               readily as with paths.
#   integrity — a relative .md cite that does not resolve INSIDE the destination
#               tree. `ai/agents/templates/ceo.md` ends with `../founder.md`,
#               which does not exist even upstream; five more like it. The
#               transform repairs those six by name and this gate proves it.
# Any gate biting REFUSES that item, names file and line, and the run exits 1.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# apps/one is a sibling of the MONOREPO, not of whatever tree this copy sits in.
# Run from .claude/worktrees/dev — which is where development happens, per
# ../CLAUDE.md § The dev -> prod loop — `$ROOT/../apps/one` resolves inside
# .claude/worktrees/ and the script refuses a repo that is right there. The
# common git dir is the same for every worktree, so it names the main tree.
MAIN="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
MAIN="${MAIN:+$(dirname "$MAIN")}"
PUB="${ONE_PUBLIC_ROOT:-${MAIN:-$ROOT}/../apps/one}"
MODE="${1:-}"

# ROOT comes from BASH_SOURCE, so a relative invocation from inside apps/one
# would resolve ROOT to apps/one and sync the tree onto itself. Assert the
# source really is the monorepo before touching anything. (Same trap as
# land.sh/release.sh; see ../CLAUDE.md § The dev -> prod loop.)
[ -f "$ROOT/schema/one.tql" ] || {
  echo "refusing: \$ROOT ($ROOT) is not the one-ie monorepo (no schema/one.tql)."
  echo "run it from the monorepo, or by absolute path."; exit 1; }
[ "$MODE" = "--report" ] || [ "$MODE" = "--self-test" ] || {
  [ -d "$PUB/.git" ] && [ -d "$PUB/site" ] || {
    echo "refusing: no public repo at $PUB (want .git + site/)."
    echo "  git clone git@github.com:one-ie/one.git $PUB"; exit 1; }
  [ "$(cd "$ROOT" && pwd -P)" != "$(cd "$PUB" && pwd -P)" ] || {
    echo "refusing: source and destination are the same tree"; exit 1; }
}

# A SECOND SOURCE. Measured 2026-09-22: nine .claude/skills and all seven
# ai/workflows in apps/vespio exist NOWHERE in this monorepo — they were
# authored there. vespio is a SOURCE, not only a sink, so a sync that assumes
# one upstream encodes the wrong path for half of what should ship. A row names
# its source with a `vespio:` prefix; bare means this monorepo.
VESPIO="${VESPIO_ROOT:-${MAIN:-$ROOT}/../apps/vespio}"
src_root() { case "$1" in vespio:*) echo "$VESPIO" ;; *) echo "$ROOT" ;; esac; }
src_path() { echo "${1#vespio:}"; }

MANIFEST_SH="$ROOT/.claude/scripts/factory-repo.sh"
rows() {
  sed -n '/^public_manifest() {/,/^PUBLIC$/p' "$MANIFEST_SH" | grep -E '^public[[:space:]]'
}

# --- the three gates --------------------------------------------------------
# A monorepo path in a public doc. `.claude/scripts/` is here because we ship no
# scripts: a command that names one is a command that cannot run in the clone.
BAD_CITE='one\.ie/web|one\.ie/ai|packages/(sdk|cli|mcp|evals|claude)/|schema/[a-z-]*\.tql|\.claude/scripts/|channels/src|pay/backend|resolvers/|text/[a-z0-9-]+\.md|\.claude/worktrees|\.release/'
LEAK='sk-[A-Za-z0-9]{16}|sk-or-v1-|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|ONE_API_KEY[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9]|CALLBACK_SECRET[[:space:]]*=|IDENTITY_SECRET[[:space:]]*=|SERVER_SECRET[[:space:]]*='

gate_leak() { # gate_leak <dir-or-file>
  grep -rnE "$LEAK" "$1" 2>/dev/null | sed 's/^/    leak      /'
}
gate_cites() { # gate_cites <dir-or-file>
  grep -rnE "$BAD_CITE" "$1" 2>/dev/null | sed 's/^/    cites     /'
}
# THE FOURTH GATE, and the one that cost the most to learn. On 2026-09-22 the
# first pass shipped six rag-*.md skills because the CITATION grep scored them
# zero — and it scored them zero because it looks for PATHS. Every one of them
# carries `source: oo-internal`, triggers on "when Donal says", and uses "OO
# should take on the tax-prep niche" as its worked example. A skill can name no
# file at all and still be entirely somebody's private working practice. Paths
# are not the only way a document says whose it is; a NAME is the other way.
OWNED='(^|[^A-Za-z])(Donal|Tony|Vespio|vespio)([^A-Za-z]|$)|source:[[:space:]]*oo-internal|(^|[^A-Za-z])OO(&#39;|'"'"')?s?([^A-Za-z]|$)|elitemovers|maestro-sales|oo-brain|agency-operator'
gate_owned() { # gate_owned <dir-or-file>
  grep -rnE "$OWNED" "$1" 2>/dev/null | sed 's/^/    owner     /'
}

gate_integrity() { # gate_integrity <staged-root> <dst-rel-root>
  # Every relative *.md cite inside the staged copy must resolve within the
  # staged copy. Resolving against the CONTAINING FILE is the only correct
  # walk — a first pass that resolved everything against the subtree root
  # reported 19 dangling cites where there were 6, because `../ceo.md` inside
  # marketing/director.md is correct and inside ceo.md is not.
  local stage="$1"
  python3 - "$stage" <<'PY'
import os, re, sys
root = os.path.abspath(sys.argv[1])
pat = re.compile(r'(?<![\w/.-])((?:\.\./)*[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*\.md)(?![\w/-])')
bad = []
for d, _, fs in os.walk(root):
    for f in fs:
        if not f.endswith('.md'):
            continue
        p = os.path.join(d, f)
        for i, line in enumerate(open(p, encoding='utf-8', errors='replace'), 1):
            for m in pat.findall(line):
                if m.startswith(('http', 'https')):
                    continue
                t = os.path.normpath(os.path.join(d, m))
                if not os.path.exists(t) or not (t == root or t.startswith(root + os.sep)):
                    bad.append(f"    integrity {os.path.relpath(p, root)}:{i}  {m}")
for b in sorted(set(bad)):
    print(b)
PY
}

# --- transforms: applied to the STAGED copy, never to the source ------------
# A transform exists only where the gate would otherwise bite for a reason that
# is mechanical rather than substantive. It is NOT a way to launder a doc that
# should not ship — every one below is named, and the gate re-runs after it.
transform() { # transform <dst-rel> <staged-path>
  case "$1" in
    .claude/rules/ui.md)
      # The only monorepo path is the `paths:` frontmatter glob that decides
      # when the rule auto-loads. Repointing a glob is not a claim about the
      # world; the rule's body says nothing about one.ie/web.
      sed -i '' 's|one\.ie/web/src/components/|site/src/components/|g' "$2" ;;
    ai/workflows/ticket-triage.md)
      # Two operator hits, both PLACEHOLDERS in example fields — an assignee and
      # an email signature. Substituting them is the same class of change as
      # ui.md's `paths:` glob: mechanical, and it does not alter a single claim
      # the workflow makes. The ownership gate re-runs after this, so a NEW
      # operator name added upstream later still refuses the row.
      sed -i '' 's|^  assignee: Donal$|  assignee: "{{ owner }}"|' "$2"
      sed -i '' 's|^    — OO Service$|    — {{ business_name }} Service|' "$2"
      ;;
    ai/agents/templates/)
      # Six cites dangle upstream too — they name files that do not exist in
      # this monorepo either (`../founder.md`, `one/rubrics.md`,
      # `one/governance-todo.md`, `agents/README.md`,
      # `one/agents-how-they-work.md`, `.claude/commands/claw.md`). Repair by
      # name, so a NEW dangle added later still fails the gate.
      sed -i '' '/^- `\.\.\/founder\.md`/d' "$2/ceo.md"
      sed -i '' 's| (in$|, in|; s|^   cycles not days; see `one/rubrics\.md`)$|   cycles, not days.|' "$2/marketing/director.md"
      sed -i '' 's|`ceo`, `director`, `agent`). Permission = Role × Pheromone — see|`ceo`, `director`, `agent`). Permission = Role × Pheromone.|' "$2/README.md"
      sed -i '' '/^`one\/governance-todo\.md`\.$/d' "$2/README.md"
      sed -i '' '/^- `agents\/README\.md`/d;/^- `one\/agents-how-they-work\.md`/d;/^- `\.claude\/commands\/claw\.md`/d' "$2/README.md"
      # Those three were the WHOLE of README's "See also". Dropping the items
      # and keeping the heading leaves an EMPTY SECTION — which the integrity
      # gate cannot catch (a heading cites nothing) and a reader can. Strip a
      # trailing heading whose body the repair just emptied.
      python3 -c 'import re,sys;p=sys.argv[1];s=open(p,encoding="utf-8").read();s=re.sub(r"\n#+ See also\s*\n\s*$","\n",s);open(p,"w",encoding="utf-8").write(s if s.endswith("\n") else s+"\n")' "$2/README.md"
      ;;
  esac
}

# --- report: what is held back ---------------------------------------------
if [ "$MODE" = "--report" ]; then
  echo "== one-sync --report   what does NOT ship to $PUB"
  echo "-- the rule: public_manifest() in factory-repo.sh. Unlisted = excluded."
  shipped="$(rows | awk '{print $2}')"
  for k in commands rules agents skills; do
    held=""
    for f in "$ROOT"/.claude/$k/*; do
      [ -e "$f" ] || continue
      rel=".claude/$k/$(basename "$f")"
      grep -qxF "$rel" <<< "$shipped" || held="$held $(basename "$f")"
    done
    n=$(echo $held | wc -w | tr -d ' ')
    echo "-- .claude/$k — $n held back"
    echo "$held" | tr ' ' '\n' | grep -v '^$' | sed 's/^/     /' | head -200
  done
  echo "-- ai/ — the playbook. open-source.md caps this at one worked example"
  echo "   of each kind; ai/skills/elevate-* (the ELEVATE library) never ships."
  echo "     $(ls "$ROOT/one.ie/ai/agents" | wc -l | tr -d ' ') agent dirs, $(ls "$ROOT/one.ie/ai/skills" | wc -l | tr -d ' ') skills upstream; $(rows | grep -c 'ai/agents') row(s) here"
  exit 0
fi

# --- self-test: prove each gate can go RED ---------------------------------
if [ "$MODE" = "--self-test" ]; then
  t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT; fails=0
  printf 'see one.ie/web/src/pages for the shape\n' > "$t/a.md"
  [ -n "$(gate_cites "$t")" ] || { echo "SELF-TEST FAIL: cites gate did not bite"; fails=1; }
  printf 'ONE_API_KEY=abc123def456\n' > "$t/b.md"
  [ -n "$(gate_leak "$t")" ] || { echo "SELF-TEST FAIL: leak gate did not bite"; fails=1; }
  rm -f "$t/a.md" "$t/b.md"
  mkdir -p "$t/sub"; printf 'see `../nope.md`\n' > "$t/sub/c.md"
  [ -n "$(gate_integrity "$t")" ] || { echo "SELF-TEST FAIL: integrity gate did not bite"; fails=1; }
  printf 'see `c.md`\n' > "$t/sub/d.md"; rm -f "$t/sub/c.md"; printf 'x\n' > "$t/sub/c.md"
  [ -z "$(gate_integrity "$t")" ] || { echo "SELF-TEST FAIL: integrity gate bit a resolving cite"; fails=1; }
  printf 'Triggers when Donal says "do it".\nsource: oo-internal\n' > "$t/e.md"
  [ -n "$(gate_owned "$t")" ] || { echo "SELF-TEST FAIL: ownership gate did not bite"; fails=1; }
  rm -f "$t/e.md"
  printf 'A generic sentence about building websites.\n' > "$t/f.md"
  [ -z "$(gate_owned "$t/f.md")" ] || { echo "SELF-TEST FAIL: ownership gate bit clean prose"; fails=1; }
  [ "$fails" = 0 ] && echo "  ok   4 gates each go RED on a planted defect, and green on a clean tree"
  exit "$fails"
fi

# --- the run ----------------------------------------------------------------
echo "== one-sync   $ROOT -> $PUB"
echo "-- ADDITIVE ONLY. A divergent file is reported, never overwritten."
add=0; same=0; div=0; refused=0; absent=0
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT

while read -r _ src dst; do
  [ -n "${src:-}" ] || continue
  sr="$(src_root "$src")"; sp="$(src_path "$src")"
  dst="${dst:-$sp}"
  s="$sr/$sp"; d="$PUB/${dst%/}"
  [ -d "$sr" ] || { printf '  %-10s %s  (source tree %s absent)\n' "NOSRC" "$dst" "$sr"; absent=$((absent+1)); continue; }
  [ -e "${s%/}" ] || { printf '  %-10s %s\n' "ABSENT" "$src"; absent=$((absent+1)); continue; }

  # stage + transform + gate, before looking at the destination at all
  st="$STAGE/${dst%/}"; mkdir -p "$(dirname "$st")"
  cp -RL "${s%/}" "$st"
  transform "$dst" "$st"
  findings="$( { gate_leak "$st"; gate_cites "$st"; gate_owned "$st"; gate_integrity "$st"; } )"
  if [ -n "$findings" ]; then
    printf '  %-10s %s\n' "REFUSED" "$dst"
    echo "$findings" | sed "s|$STAGE/||" | head -12
    refused=$((refused+1)); continue
  fi

  if [ ! -e "$d" ]; then
    if [ "$MODE" = "--check" ]; then printf '  %-10s %s\n' "ADD" "$dst"
    else mkdir -p "$(dirname "$d")"; cp -RL "$st" "$d"; printf '  %-10s %s\n' "ADDED" "$dst"; fi
    add=$((add+1))
  elif diff -rq "$st" "$d" >/dev/null 2>&1; then
    printf '  %-10s %s\n' "same" "$dst"; same=$((same+1))
  else
    printf '  %-10s %s  (public re-authored it — reconcile by hand, never overwrite)\n' "DIVERGED" "$dst"
    div=$((div+1))
  fi
done <<< "$(rows)"

echo
echo "-- add:$add same:$same diverged:$div refused:$refused absent:$absent"
[ "$refused" = 0 ] || { echo "RED — a gate bit. Nothing was installed for the refused rows."; exit 1; }
if [ "$MODE" != "--check" ] && [ "$add" -gt 0 ]; then
  echo
  echo "-- $PUB is now dirty and UNCOMMITTED. This script never commits and never"
  echo "   pushes: apps/one is public. Review, then commit there yourself."
  ( cd "$PUB" && git status --short )
fi
