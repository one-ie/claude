#!/usr/bin/env bash
# do-board.sh <slug> [--dry-run | --status | --self-test] — the ▸board stop's executor,
# and the ONE minter of a plan's cycle rows.
#
# manifest: needs-env  (reads GATEWAY_API_KEY; writes rows through one.ie)
#
# Mirrors a plan's batch DAG onto the board as CHAINED rows and writes the tids
# back into the todo's frontmatter (`anchor:` + `cycle_rows:`), so the plan and
# the board are one graph rendered twice.
#
# WHY THE JOIN MATTERS. `tasks:claim` and `tasks:status picked` are BLOCKER-GATED:
# they read the very `blocks` edge this script writes. A mirrored plan cannot be
# claimed out of order; an unmirrored one hands every head every cycle at once.
#
# ONE MINTER. do-signal.sh's `--task-plan` used to file the same rows flat
# (tasks:create, no edges, tagged `slug:<slug>-C1` in UPPER case) while
# `--task-cycle` closed rows named `slug:<slug>-c1` in lower case — SLUG_RE is
# lowercase-only, so the armed rows never deduped and never closed. Both now meet
# here: `--task-plan` delegates to this script, and the rows it mints carry the
# exact lower-case slug tag `--task-cycle` resolves, so the engine's existing
# close (do-tick.sh, do-engine.js, do-close.sh) moves THESE rows to done and the
# gate unblocks the next batch by itself. No new return leg was written.
#
# IDEMPOTENT AND RESUMABLE. tasks:subtask does not dedupe, so before minting a
# cycle the walk looks the row up by its slug tag (tasks:list) and, if it exists,
# only re-asserts the edges with tasks:depend (a negated-pattern insert — safe to
# repeat). Frontmatter is written after EVERY batch, so a walk that dies at C7
# resumes at C7 instead of twinning C1..C6.
#
# SEQUENTIAL BY CONTRACT. blockedBy takes tids, so batch N+1 needs batch N's rows
# to exist. Within a batch nothing depends on anything, but 14 rows cost ~20s in
# series and the order is the proof — not worth a parallel shape.
#
# THE LEASE MOVES TO THE CYCLE. Containment children gate their parent's claim
# (blockersResolved reads `containment` too), so once cycles hang off the anchor
# the plan-level lease (`tasks:claim` on the anchor) is refused as `blocked`.
# do-signal.sh --task-claim and do-fleet.sh claim_task therefore claim the FIRST
# OPEN CYCLE's row when the plan has cycle_rows — the row actually in flight.
#
# The deterministic-fact rule (.claude/CLAUDE.md): a fact the spine needs gets a
# script; the model executes it, never substitutes for it.
#
# DO_BOARD_FAKE=1 swaps the door for an in-process stub that mints deterministic
# tids — the dry run and the self-test walk the REAL loop, not a summary of it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="${ONE_API_URL:-https://one.ie}"
FAKE="${DO_BOARD_FAKE:-0}"

die() { echo "do-board: $*" >&2; exit 1; }

# ---------------------------------------------------------------- the door
_key() {
  [ -n "${GATEWAY_API_KEY:-}" ] && { printf '%s' "$GATEWAY_API_KEY"; return; }
  # .dev.vars, NOT .env — prod refuses the .env key (recorded trap).
  local f="${ONE_ENV_FILE:-${DO_ENV_FILE:-$ROOT/one.ie/web/.dev.vars}}"
  [ -f "$f" ] || die "no GATEWAY_API_KEY and no $f"
  grep -o 'GATEWAY_API_KEY=.*' "$f" | head -1 | cut -d= -f2-
}

# ask <receiver> <json-data> -> stdout is the raw envelope. No `-f`: a refusal's
# body is the diagnosis, and a silent empty string is how a mint reads as a hang.
ask() {
  if [ "$FAKE" = 1 ]; then
    case "$1" in
      # deterministic per payload (ask runs in a $(...) subshell, so a counter cannot climb)
      tasks:create|tasks:subtask) printf '{"ok":true,"tid":"task:%024x"}' "$(printf '%s' "$2" | cksum | cut -d' ' -f1)" ;;
      tasks:list)                 printf '{"ok":true,"tasks":[]}' ;;
      # The bulk door answers a ref→tid map, one entry per `creates` row, so the
      # self-test walks the REAL bulk loop (chunking, cross-chunk ref resolution,
      # the frontmatter write) instead of a summary of it. A stub that only knew
      # the one-at-a-time receivers would have left the whole bulk path unproven
      # while printing PASS.
      tasks:bulk)
        local _r _t _out=""
        for _r in $(jq -r '.creates[]?.ref // empty' <<<"$2"); do
          _t=$(printf '%s%s' "$_r" "$2" | cksum | cut -d' ' -f1)
          _out="$_out,\"$_r\":\"$(printf 'task:%024x' "$_t")\""
        done
        printf '{"ok":true,"attempted":%s,"applied":%s,"failed":0,"created":{%s}}' \
          "$(jq -r '.creates|length' <<<"$2")" "$(jq -r '.creates|length' <<<"$2")" "${_out#,}"
        ;;
      *)                          printf '{"ok":true}' ;;
    esac
    return
  fi
  curl -sS -m 30 -X POST "$API/api/ask/$1" \
    -H "Authorization: Bearer $(_key)" -H 'Content-Type: application/json' \
    -d "{\"data\":$2}"
}

# tid_of <envelope> — the id a task receiver returns, whatever it calls it.
tid_of() { jq -r '.result.tid // .result.id // .result.taskId // .tid // empty' <<<"$1"; }

# row_by_slug <cslug> <ws> — an existing row's tid by its exact `slug:` tag, or empty.
# Same rule as resolveTaskBySlug: exact tag, and the sort-last tid wins if there are twins.
row_by_slug() {
  local env; env=$(ask tasks:list "{\"workspace\":\"$2\",\"tag\":\"slug:$1\"}")
  jq -r '[(.result.tasks // .tasks // [])[].tid] | sort | last // empty' <<<"$env"
}

# cycle_notes <todo> <cid> <slug> — what a head reads when it opens the row: the
# cycle's goal delta + deliverable, and where the whole frame lives. Capped so a
# silent 4000-byte truncation (tasks:comment's, and notes' by the same discipline)
# can never eat the pointer at the end.
cycle_notes() {
  local body
  body=$(awk -v c="$2" '
    $0 ~ "^## "c" — " {on=1; next}
    on && /^## / {exit}
    on && /^\*\*(Goal delta|Deliverable|Files|Accept)/ {print}
  ' "$1" | sed 's/\*\*//g' | head -c 1200)
  printf '%s\n\nPlan: text/%s-todo.md § %s\nClose: bash .claude/scripts/do-signal.sh --task-cycle %s %s done' "$body" "$3" "$2" "$3" "$2"
}

# write_front <todo> <anchor> <ws> <rows-block> — replace-or-insert the BOARD
# CONTRACT block. ONE definition, used by the walk AND the self-test, so the red
# proof exercises the writer that ships and not a copy of it.
write_front() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import re,sys
p,anchor,ws,rows = sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
s=open(p).read()
# strip any previous block first — running ▸board twice must not leave two answers
# `[ \t]*(?:#.*)?` on the cycle_rows line is load-bearing: template-todo.md ships
# `cycle_rows: []             # WRITTEN BY do-board.sh, never by hand`, and without
# the comment clause that group does not match. The group is OPTIONAL, so the strip
# then silently removed only anchor+board_workspace and LEFT the empty list — and a
# second `cycle_rows:` is last-wins in YAML, so every YAML consumer read ZERO tids
# while the file visibly held six. --status never saw it (it parses by line, not by
# YAML), so writer and checker agreed and only the consumers were wrong. Measured on
# workflow-genesis, 2026-09-12.
s=re.sub(r'\n(anchor:.*\n)(board_workspace:.*\n)?(cycle_rows:[ \t]*(?:\[\])?[ \t]*(?:#.*)?\n(?:[ \t]+-.*\n)*)?','\n',s,count=1)
blk=f'anchor: "{anchor}"\nboard_workspace: {ws}\ncycle_rows:\n{rows}'
if not blk.endswith('\n'): blk += '\n'
if re.search(r'^depends_on:.*\n',s,flags=re.M):
    s=re.sub(r'^(depends_on:.*\n)',lambda m:m.group(1)+blk,s,count=1,flags=re.M)
else:
    s=re.sub(r'^(slug:.*\n)',lambda m:m.group(1)+blk,s,count=1,flags=re.M)
open(p,'w').write(s)
PY
}

# ---------------------------------------------------------------- self-test
if [ "${1:-}" = "--self-test" ]; then
  fail=0
  ok() { if [ "$2" = 1 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

  ok "tid_of reads .result.tid"    "$([ "$(tid_of '{"result":{"tid":"task:a"}}')"    = "task:a" ] && echo 1 || echo 0)"
  ok "tid_of reads .result.id"     "$([ "$(tid_of '{"result":{"id":"task:b"}}')"     = "task:b" ] && echo 1 || echo 0)"
  ok "tid_of reads bare .tid"      "$([ "$(tid_of '{"ok":true,"tid":"task:c"}')"      = "task:c" ] && echo 1 || echo 0)"
  ok "tid_of empty on an error"    "$([ -z "$(tid_of '{"error":"forbidden"}')" ] && echo 1 || echo 0)"

  tmp="$(mktemp -d)"; f="$tmp/x-todo.md"
  # A fixture do-plan-json accepts: frontmatter, three cycles in two batches, a kanban.
  cat > "$f" <<'FIX'
---
title: fixture plan
slug: x
outcome: "three rows chained"
depends_on: []
batches:
  - [C1]
  - [C2, C3]
---
## Status
- [ ] C1 — first
- [ ] C2 — second
- [ ] C3 — third

## C1 — first  [tier: trivial]
**Goal delta:** one is true.
**Deliverable:** row one.

## C2 — second  [tier: trivial]
**Goal delta:** two is true.

## C3 — third  [tier: trivial]
**Goal delta:** three is true.
FIX
  # A pristine copy: the walk below rewrites $f, and the bulk cases need a plan
  # that is still UNMIRRORED (bulk is gated on drift == the cycle count).
  cp "$f" "$tmp/orig-todo.md"
  # THE WALK, under /bin/bash 3.2 — the shell this box actually runs. The first
  # cut used `mapfile` (bash 4), died on the first batch, and was never caught
  # because --dry-run exited before the loop. The fake door makes the loop the thing
  # under test.
  out=$(cd "$ROOT" && DO_PLAN_TODO="$f" DO_BOARD_FAKE=1 /bin/bash "$ROOT/.claude/scripts/do-board.sh" x 2>&1) || true
  ok "walk runs under /bin/bash 3.2"        "$(grep -q 'drift is now 0' <<<"$out" && echo 1 || echo 0)"
  ok "C1 minted with no blockers"           "$(grep -q '^  C1 .*blockedBy=0' <<<"$out" && echo 1 || echo 0)"
  ok "C2 and C3 both blocked by batch 1"    "$([ "$(grep -c '^  C[23] .*blockedBy=1' <<<"$out")" = 2 ] && echo 1 || echo 0)"
  ok "anchor + 3 rows written to frontmatter" "$([ "$(grep -c 'cycle: C[123], tid: "task:' "$f")" = 3 ] && grep -q '^anchor: "task:' "$f" && echo 1 || echo 0)"
  # Second run: every cycle has a row → nothing minted, drift 0, ONE block.
  out2=$(cd "$ROOT" && DO_PLAN_TODO="$f" DO_BOARD_FAKE=1 /bin/bash "$ROOT/.claude/scripts/do-board.sh" x 2>&1) || true
  ok "second run mints nothing (idempotent)" "$(grep -q 'already mirrored' <<<"$out2" && echo 1 || echo 0)"
  ok "second run leaves ONE anchor:"         "$([ "$(grep -c '^anchor:' "$f")" = 1 ] && echo 1 || echo 0)"
  ok "second run leaves ONE cycle_rows:"     "$([ "$(grep -c '^cycle_rows:' "$f")" = 1 ] && echo 1 || echo 0)"
  # Resume: drop C3's row from the frontmatter → only C3 is re-minted, chained to batch 1.
  sed -i '' '/cycle: C3,/d' "$f"
  out3=$(cd "$ROOT" && DO_PLAN_TODO="$f" DO_BOARD_FAKE=1 /bin/bash "$ROOT/.claude/scripts/do-board.sh" x 2>&1) || true
  ok "resume re-mints ONLY the missing cycle" "$([ "$(grep '^  C[0-9]* ' <<<"$out3" | grep -vc existing)" = 1 ] && grep -q '^  C3 .*blockedBy=1' <<<"$out3" && echo 1 || echo 0)"
  ok "fake tids are distinct per row"         "$([ "$(grep -o 'task:[0-9a-f]\{24\}' "$f" | sort -u | wc -l | tr -d ' ')" = 4 ] && echo 1 || echo 0)"
  # Notes carry the pointer a head needs.
  ok "cycle_notes ends with the close command" "$(cycle_notes "$f" C1 x | grep -q -- '--task-cycle x C1 done' && echo 1 || echo 0)"

  # ── the BULK path, walked end to end against the fake bulk door ────────────
  # A fresh fixture, because bulk is gated on drift == the cycle count. This
  # drives the real loop: the creates array, the ref chain, the receipt's
  # ref→tid map, and the SAME write_front the per-row walk uses.
  g="$tmp/bz-todo.md"; sed 's/^slug: x$/slug: bz/' "$tmp/orig-todo.md" > "$g"
  outb=$(cd "$ROOT" && DO_PLAN_TODO="$g" DO_BOARD_FAKE=1 DO_BOARD_BULK=1 /bin/bash "$ROOT/.claude/scripts/do-board.sh" bz 2>&1) || true
  ok "bulk mints the tree in ONE tasks:bulk call" "$(grep -q 'in 1 tasks:bulk call' <<<"$outb" && echo 1 || echo 0)"
  ok "bulk chains batch 2 behind batch 1"         "$([ "$(grep -c '^  C[23] .*blockedBy=1' <<<"$outb")" = 2 ] && grep -q '^  C1 .*blockedBy=0' <<<"$outb" && echo 1 || echo 0)"
  ok "bulk writes all 3 tids to frontmatter"      "$([ "$(grep -c 'cycle: C[123], tid: \"task:' "$g")" = 3 ] && echo 1 || echo 0)"
  ok "bulk tids are distinct per row"             "$([ "$(grep -o 'task:[0-9a-f]\{24\}' "$g" | sort -u | wc -l | tr -d ' ')" = 4 ] && echo 1 || echo 0)"
  # drift=0 is not the proof, and the script must say so rather than imply it.
  ok "bulk points at the claim REFUSAL as proof"  "$(grep -q -- '--task-claim bz' <<<"$outb" && echo 1 || echo 0)"
  # RED HALF: a half-mirrored plan must DECLINE bulk — `creates` does not dedupe,
  # so a second bulk run over these rows would twin every one of them.
  outb2=$(cd "$ROOT" && DO_PLAN_TODO="$g" DO_BOARD_FAKE=1 DO_BOARD_BULK=1 /bin/bash "$ROOT/.claude/scripts/do-board.sh" bz 2>&1) || true
  ok "fully mirrored plan mints nothing under --bulk" "$(grep -q 'already mirrored' <<<"$outb2" && echo 1 || echo 0)"
  sed -i '' '/cycle: C3,/d' "$g"
  outb3=$(cd "$ROOT" && DO_PLAN_TODO="$g" DO_BOARD_FAKE=1 DO_BOARD_BULK=1 /bin/bash "$ROOT/.claude/scripts/do-board.sh" bz 2>&1) || true
  ok "half-mirrored plan DECLINES bulk (no twins)" "$(grep -q 'bulk    declined' <<<"$outb3" && [ "$(grep -c '^  C[0-9]* ' <<<"$outb3" | tr -d ' ')" = 3 ] && echo 1 || echo 0)"
  # Empty block form (`cycle_rows: []`, the template's default) is replaced, not doubled.
  printf -- '---\ntitle: t\nslug: y\ndepends_on: []\nanchor: ""\nboard_workspace: one\ncycle_rows: []\n---\nbody\n' > "$f"
  write_front "$f" "task:aaa" "one" '  - {cycle: C1, tid: "task:111"}'
  ok "template default block is replaced"   "$([ "$(grep -c '^cycle_rows' "$f")" = 1 ] && grep -q 'tid: "task:111"' "$f" && echo 1 || echo 0)"

  # THE TEMPLATE'S ACTUAL SHAPE — every one of the three keys carries a trailing
  # `# comment`, which is what text/template-todo.md ships and therefore what every
  # real plan looks like. The comment-free fixture above passed while this one wrote
  # a DUPLICATE cycle_rows (last-wins in YAML ⇒ consumers read zero tids). A fixture
  # tidier than the artefact it stands for is not a fixture. Parsed with a real YAML
  # reader, not grep, because grep is the parser that missed it.
  printf -- '---\ntitle: t\nslug: y\ndepends_on: []\nanchor: ""                 # filled by do-board.sh\nboard_workspace: one       # where the rows live\ncycle_rows: []             # WRITTEN BY do-board.sh, never by hand\n---\nbody\n' > "$f"
  write_front "$f" "task:bbb" "one" '  - {cycle: C1, tid: "task:222"}'
  ok "commented template form leaves ONE cycle_rows" "$([ "$(grep -c '^cycle_rows' "$f")" = 1 ] && echo 1 || echo 0)"
  ok "and a YAML reader sees the tid, not []" "$(python3 -c "
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]).read().split('---')[1])
r=d.get('cycle_rows') or []
print(1 if len(r)==1 and r[0]['tid']=='task:222' else 0)" "$f")"
  # RED PROOF: a naive appender fails the idempotence check the way the real writer must not.
  printf -- '---\ntitle: t\nslug: y\ndepends_on: []\n---\nbody\n' > "$f"
  printf 'anchor: "task:aaa"\n' >> "$f"; printf 'anchor: "task:aaa"\n' >> "$f"
  ok "gutted writer is caught (2 anchors reads red)" "$([ "$(grep -c '^anchor:' "$f")" = 2 ] && echo 1 || echo 0)"

  rm -rf "$tmp"
  [ "$fail" = 0 ] && echo "PASS" || echo "FAIL"
  exit "$fail"
fi

# ---------------------------------------------------------------- read the plan
SLUG="${1:-}"; [ -n "$SLUG" ] || die "usage: do-board.sh <slug> [--dry-run|--status|--bulk]"
MODE="${2:-}"

PLAN="$(bash "$ROOT/.claude/scripts/do-plan-json.sh" "$SLUG")" || die "plan will not parse — fix it before mirroring it"
TODO="${DO_PLAN_TODO:-$ROOT/$(jq -r '.todo' <<<"$PLAN")}"
WS="$(jq -r '.boardWorkspace' <<<"$PLAN")"
ANCHOR="$(jq -r '.boardAnchor' <<<"$PLAN")"
DRIFT="$(jq -r '.boardDrift | length' <<<"$PLAN")"
TITLE="$(sed -n 's/^title:[ \t]*//p' "$TODO" | head -1 | tr -d '"')"

# ---------------------------------------------------------------- --status: the instrument
if [ "$MODE" = "--status" ]; then
  # ONE read for every cycle row (they all carry plan:<slug>), one for the anchor.
  rows=$(ask tasks:list "{\"workspace\":\"$WS\",\"tag\":\"plan:$SLUG\"}")
  arow=$(ask tasks:list "{\"workspace\":\"$WS\",\"tag\":\"slug:$SLUG\"}")
  echo "do-board: $SLUG — workspace=$WS  anchor=${ANCHOR:-none} $(jq -r --arg a "$ANCHOR" '(.result.tasks//.tasks//[])[] | select(.tid==$a) | "(\(.status))"' <<<"$arow")"
  printf '  %-4s %-30s %-9s %s\n' cycle tid status title
  jq -r '.batches | to_entries[] | .value[] as $c | "\(.key+1)\t\($c)"' <<<"$PLAN" | while IFS=$'\t' read -r b c; do
    tid=$(jq -r --arg c "$c" '.cycleRows[$c] // "-"' <<<"$PLAN")
    st=$(jq -r --arg t "$tid" '(.result.tasks//.tasks//[])[] | select(.tid==$t) | .status' <<<"$rows" | head -1)
    nm=$(jq -r --arg t "$tid" '(.result.tasks//.tasks//[])[] | select(.tid==$t) | .name // ""' <<<"$rows" | head -1)
    [ "$tid" = "-" ] && st="NO ROW"
    [ -n "$st" ] || st="not-on-board"
    printf '  %-4s %-30s %-9s %s\n' "$c" "$tid" "$st" "${nm:-$(sed -n "s/^## $c — //p" "$TODO" | head -1 | sed 's/ *\[.*//')}"
  done
  n_open=$(jq -r '[(.result.tasks//.tasks//[])[] | select(.status=="open")] | length' <<<"$rows")
  n_done=$(jq -r '[(.result.tasks//.tasks//[])[] | select(.status=="done" or .status=="verified")] | length' <<<"$rows")
  n_pick=$(jq -r '[(.result.tasks//.tasks//[])[] | select(.status=="picked")] | length' <<<"$rows")
  echo "  rows: open=$n_open picked=$n_pick done=$n_done  drift=$DRIFT  (door: tasks:list tag=plan:$SLUG — exact, uncapped)"
  exit 0
fi

echo "do-board: $SLUG — workspace=$WS  drift=$DRIFT cycle(s) with no row"
[ "$DRIFT" = 0 ] && { echo "do-board: already mirrored — nothing to mint"; exit 0; }

if [ "$MODE" = "--dry-run" ]; then
  # The dry run walks the SAME loop against the fake door, in a scratch copy of the
  # todo, so what it prints is what the live run does — not a summary of it.
  tmp="$(mktemp -d)"; cp "$TODO" "$tmp/$SLUG-todo.md"
  echo "do-board: DRY RUN (fake door, scratch copy) —"
  DO_PLAN_TODO="$tmp/$SLUG-todo.md" DO_BOARD_FAKE=1 bash "$ROOT/.claude/scripts/do-board.sh" "$SLUG" | sed 's/^/  /'
  rm -rf "$tmp"; exit 0
fi
[ -z "$MODE" ] || [ "$MODE" = "--bulk" ] || die "unknown mode $MODE"

# ---------------------------------------------------------------- the walk
# The anchor IS the plan row do-auto.sh already files (tasks:create dedupes on the
# `slug:` tag and returns the existing tid) — never a second parent.
if [ -z "$ANCHOR" ]; then
  env=$(ask tasks:create "{\"title\":$(jq -Rn --arg t "$TITLE" '$t'),\"workspace\":\"$WS\",\"tags\":[\"slug:$SLUG\",\"do:cycle\"]}")
  ANCHOR="$(tid_of "$env")"
  [ -n "$ANCHOR" ] || die "anchor mint failed: $env"
  echo "  anchor  $ANCHOR"
fi

# ---------------------------------------------------------------- the bulk mint
# ONE call files a whole plan tree. tasks:bulk's `creates` resolves `ref` handles
# INSIDE the call, so C2's blockedBy names C1's ref and the receiver wires the
# edge itself — the batch DAG arrives as one request instead of one per row plus
# one per edge (14 rows cost ~20s in series; this costs one round trip per 25).
#
# GATED ON AN UNMIRRORED PLAN, and that is correctness, not caution: `creates`
# does NOT dedupe — which is the same reason `row_by_slug` exists at all, since
# tasks:subtask never deduped either. Run over a half-mirrored plan it would TWIN
# every row that already exists. So bulk fires only when drift == the cycle count
# (nothing on the board yet); every other state — including the resume after a
# bulk run that died mid-way — takes the per-row walk below, which looks each row
# up by its slug tag first. The fast path never becomes the only path.
#
# Opt in with `--bulk` or DO_BOARD_BULK=1. The default is unchanged.
BULK="${DO_BOARD_BULK:-0}"
[ "$MODE" = "--bulk" ] && BULK=1
NCYC=$(jq -r '[.batches[][]] | length' <<<"$PLAN")
if [ "$BULK" = 1 ] && [ "$DRIFT" = "$NCYC" ]; then
  echo "  bulk    $NCYC row(s) with no board row — minting the tree with tasks:bulk creates"
  rowsf="$(mktemp)"; ordf="$(mktemp)"
  prevrefs='[]'
  nb=$(jq -r '.batches | length' <<<"$PLAN"); b=0
  while [ "$b" -lt "$nb" ]; do
    currefs='[]'
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      n="${c#C}"; cslug="$(printf '%s-c%s' "$SLUG" "$n" | tr '[:upper:]' '[:lower:]')"
      ctitle="$(sed -n "s/^## $c — //p" "$TODO" | head -1 | sed 's/ *\[.*//' | tr -d '"')"
      notes="$(cycle_notes "$TODO" "$c" "$SLUG")"
      jq -cn --arg ref "c$n" --arg p "$ANCHOR" --arg t "$c — $ctitle" --argjson bb "$prevrefs" \
             --arg ws "$WS" --arg s "slug:$cslug" --arg pl "plan:$SLUG" --arg cy "cycle:$n" --arg notes "$notes" \
             '{ref:$ref,parent:$p,title:$t,blockedBy:$bb,tags:[$s,$pl,"do:cycle",$cy],notes:$notes,workspace:$ws}' >> "$rowsf"
      currefs=$(jq -c --arg r "c$n" '. + [$r]' <<<"$currefs")
      printf '%s\tc%s\n' "$c" "$n" >> "$ordf"
    done < <(jq -r ".batches[$b][]" <<<"$PLAN")
    prevrefs="$currefs"; b=$((b+1))
  done

  ALL=$(jq -cs '.' "$rowsf"); MAP='{}'; off=0; ncall=0
  # 25 rows per call is the receiver's declared ceiling. A ref can only be named
  # by a row LATER IN THE SAME array, so a blockedBy pointing at an earlier CHUNK
  # is rewritten to the real tid that chunk returned — otherwise the edge would
  # silently not form and the plan would hand every head every cycle at once,
  # which is the exact failure this whole script exists to prevent.
  while [ "$off" -lt "$NCYC" ]; do
    chunk=$(jq -c --argjson o "$off" '.[$o:$o+25]' <<<"$ALL")
    chunk=$(jq -c --argjson here "$(jq -c '[.[].ref]' <<<"$chunk")" --argjson map "$MAP" \
      'map(.blockedBy = [ .blockedBy[]? | if (. as $r | $here | index($r)) then . else ($map[.] // .) end ])' <<<"$chunk")
    env=$(ask tasks:bulk "$(jq -cn --argjson c "$chunk" --arg ws "$WS" '{creates:$c,workspace:$ws}')")
    # ok is the CALL's outcome, never the rows' — read applied/failed (receivers.ts).
    fail=$(jq -r '(.result//.).failed // 0' <<<"$env")
    [ "$fail" = 0 ] || die "tasks:bulk: $fail row(s) failed — $(jq -c '(.result//.).results // .' <<<"$env")"
    created=$(jq -c '(.result//.).created // {}' <<<"$env")
    [ "$(jq -r 'length' <<<"$created")" -gt 0 ] || die "tasks:bulk returned no created map: $env"
    MAP=$(jq -cn --argjson a "$MAP" --argjson b "$created" '$a * $b')
    off=$((off+25)); ncall=$((ncall+1))
  done

  ROWS=""
  while IFS=$'\t' read -r c ref; do
    tid=$(jq -r --arg r "$ref" '.[$r] // empty' <<<"$MAP")
    [ -n "$tid" ] || die "$c: tasks:bulk never returned a tid for ref $ref"
    nb_=$(jq -r --arg r "$ref" '.[] | select(.ref==$r) | .blockedBy | length' <<<"$ALL")
    echo "  $c  $tid  blockedBy=$nb_"
    ROWS="$ROWS  - {cycle: $c, tid: \"$tid\"}
"
  done < "$ordf"
  write_front "$TODO" "$ANCHOR" "$WS" "$ROWS"
  rm -f "$rowsf" "$ordf"
  echo "do-board: wrote anchor + $NCYC cycle row(s) into $(basename "$TODO") in $ncall tasks:bulk call(s)"
  DO_PLAN_TODO="$TODO" bash "$ROOT/.claude/scripts/do-plan-json.sh" "$SLUG" | jq -r '"do-board: drift is now \(.boardDrift|length)"'
  # drift=0 is NOT proof the chain formed — it only says every cycle has a tid.
  # The edge is proven by a REFUSAL: tasks:claim on a blocked cycle answers
  # `blocked`, and that is the check to run (recorded trap, 2026-09-12).
  echo "do-board: prove the chain with a refusal, not a count —"
  echo "  bash .claude/scripts/do-signal.sh --task-claim $SLUG   # a later cycle must answer 'blocked'"
  exit 0
fi
[ "$BULK" != 1 ] || echo "  bulk    declined — $DRIFT of $NCYC cycle(s) missing; creates does not dedupe, taking the per-row walk"

PREV=""; ROWS=""
nb=$(jq -r '.batches | length' <<<"$PLAN")
b=0
while [ "$b" -lt "$nb" ]; do
  CUR=""
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    n="${c#C}"; cslug="$(printf '%s-c%s' "$SLUG" "$n" | tr '[:upper:]' '[:lower:]')"
    tid=$(jq -r --arg c "$c" '.cycleRows[$c] // empty' <<<"$PLAN")
    blocked=$(printf '%s' "$PREV" | tr ' ' '\n' | jq -Rsc 'split("\n")|map(select(length>0))')
    if [ -z "$tid" ]; then tid="$(row_by_slug "$cslug" "$WS")"; fi
    if [ -n "$tid" ]; then
      # existing row: only the edges are (re)asserted — depend is idempotent
      k=0
      for p in $PREV; do ask tasks:depend "{\"tid\":\"$tid\",\"blockedBy\":\"$p\",\"workspace\":\"$WS\"}" >/dev/null; k=$((k+1)); done
      echo "  $c  $tid  (existing) blockedBy=$k"
    else
      ctitle="$(sed -n "s/^## $c — //p" "$TODO" | head -1 | sed 's/ *\[.*//' | tr -d '"')"
      notes="$(cycle_notes "$TODO" "$c" "$SLUG")"
      body=$(jq -cn --arg p "$ANCHOR" --arg t "$c — $ctitle" --argjson b "$blocked" --arg ws "$WS" \
               --arg s "slug:$cslug" --arg pl "plan:$SLUG" --arg cy "cycle:$n" --arg notes "$notes" \
               '{parent:$p,title:$t,blockedBy:$b,tags:[$s,$pl,"do:cycle",$cy],notes:$notes,workspace:$ws}')
      env=$(ask tasks:subtask "$body")
      tid="$(tid_of "$env")"
      [ -n "$tid" ] || die "$c mint failed: $env"
      echo "  $c  $tid  blockedBy=$(jq -r 'length' <<<"$blocked")"
    fi
    CUR="$CUR $tid"
    ROWS="$ROWS  - {cycle: $c, tid: \"$tid\"}
"
  done < <(jq -r ".batches[$b][]" <<<"$PLAN")
  # write after EVERY batch — a walk that dies at batch 3 resumes at batch 3
  write_front "$TODO" "$ANCHOR" "$WS" "$ROWS"
  PREV="$CUR"; b=$((b+1))
done

echo "do-board: wrote anchor + $(printf '%s' "$ROWS" | grep -c 'cycle:') cycle row(s) into $(basename "$TODO")"
DO_PLAN_TODO="$TODO" bash "$ROOT/.claude/scripts/do-plan-json.sh" "$SLUG" | jq -r '"do-board: drift is now \(.boardDrift|length)"'
