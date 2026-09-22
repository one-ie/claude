#!/usr/bin/env bash
# do-auto.sh — INTERNAL context-isolated loop for multi-cycle /do plans.
#
# Not a user command. `/do <slug>` invokes this itself when the resolved todo has
# >=2 incomplete cycles. Each cycle runs in a FRESH `claude -p "/do <slug> --next-cycle"`
# subprocess, resetting the context window to near-zero. State passes entirely through
# disk: the todo file (checked boxes), .do-trust.json (trust), .w4-improvements.json.
#
# Why it exists: run inline, each closed cycle leaves ~15-25k tokens of recon/edit/verify
# chatter in context that the next cycle has no use for — ~90-150k tokens of noise by
# cycle 6. Fresh-per-cycle eliminates it. The todo checkboxes are the only carried state.
#
# Internal usage (driven by do.md, not a human):
#   bash .claude/scripts/do-auto.sh <slug> [--max-cycles N] [--dry-run]
#   (it's a bash script — invoking with `bun` parses it as JS and dies on `case ... )`)
set -euo pipefail

SLUG=""
MAX_CYCLES=30
DRY_RUN=false
GC_ONLY=false
SETUP_ONLY=false
SELF_TEST_LIFECYCLE=false
SELF_TEST_KANBAN=false
SELF_TEST_DAEMON=false
STATUS_ONLY=false
DAEMON=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --setup-only)          SETUP_ONLY=true; shift ;;
    --status)              STATUS_ONLY=true; shift ;;
    --daemon)              DAEMON=true; shift ;;
    --max-cycles)          MAX_CYCLES="$2"; shift 2 ;;
    --dry-run)             DRY_RUN=true; shift ;;
    --gc)                  GC_ONLY=true; shift ;;
    --self-test-lifecycle) SELF_TEST_LIFECYCLE=true; shift ;;
    --self-test-kanban)    SELF_TEST_KANBAN=true; shift ;;
    --self-test-daemon)    SELF_TEST_DAEMON=true; shift ;;
    -*)                    echo "unknown flag: $1" >&2; exit 1 ;;
    *)                     SLUG="$1"; shift ;;
  esac
done

# Standalone GC: sweep every worktree whose branch is fully merged into the
# RELEASE trunk. Safe-only: `worktree remove` refuses a dirty tree and
# `branch -d` refuses an unmerged branch, so live work is listed, never touched.
#
# TWO DIRECTORIES, not one. `.do-worktrees/<slug>` carries branch `do/<slug>`;
# `.claude/worktrees/<name>` carries whatever branch is checked out there, which
# is the door root CLAUDE.md sends every session through. Only the first was ever
# swept, and the canon said so out loud — "swept by nothing" — for as long as the
# second existed. Measured 2026-09-06: 36 worktrees, 24 of them fully landed,
# 6.4G, and the box at load 16 funding ONE concurrent gate because each one costs
# a tsserver. Sweeping 17 took load to 3.5.
#
# THE BASE IS `main`, DELIBERATELY, AND NOT `dev`. Branches are cut from dev and
# land into dev (§ the loop), so measuring against dev would delete a worktree
# the moment its work integrated — which is BEFORE the dev→main PR is reviewed.
# A reviewer asking for changes would find the branch already gone. A branch is
# finished when it is released, not when it is integrated. DO_BASE_REF overrides.
if $GC_ONLY; then
  BASE="${DO_GC_BASE:-${DO_BASE_REF_GC:-main}}"
  # RESOLVE ANY COMMIT-ISH, AND NEVER SUBSTITUTE ONE SILENTLY. This used to be
  # `show-ref --verify refs/heads/$BASE`, which accepts only a LOCAL branch — so
  # `DO_GC_BASE=origin/main`, the obvious way to sweep against the real trunk,
  # failed the check and fell back to the invoking branch. That is the branch the
  # override exists to escape, and the run reported `base=main` as if it had
  # worked. Measured 2026-09-07: local main sat 131 commits behind origin/main,
  # so every landed branch read as "142 unmerged commit(s)" and the sweep hoarded
  # 1.0 GB of finished worktrees. A base that cannot be resolved is now a REFUSAL,
  # not a fallback — the whole point of --gc is that it never deletes live work,
  # and measuring against the wrong ref is how it would.
  if ! git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null 2>&1; then
    echo "[do-auto] gc: base '$BASE' does not resolve to a commit — refusing to sweep" >&2
    echo "[do-auto]     (a wrong base makes landed work look unmerged, and unlanded work look landed)" >&2
    exit 2
  fi
  # Say what was measured against, so a STALE base is visible in the output
  # rather than inferred from a surprising verdict. `main` 131 commits behind its
  # upstream is not a wrong ref — it is a right ref pointing at the wrong commit,
  # and nothing in the old output could tell those apart.
  BASE_SHA="$(git rev-parse --short "${BASE}^{commit}")"
  BASE_NOTE=""
  if _gc_up="$(git rev-parse --abbrev-ref --symbolic-full-name "${BASE}@{upstream}" 2>/dev/null)"; then
    _gc_behind="$(git rev-list --count "${BASE}..${_gc_up}" 2>/dev/null || echo 0)"
    [ "${_gc_behind:-0}" -gt 0 ] && BASE_NOTE=" — STALE: ${_gc_behind} commit(s) behind ${_gc_up}"
  fi
  echo "[do-auto] gc: measuring against ${BASE} (${BASE_SHA})${BASE_NOTE}"
  # Never sweep the branches the loop itself stands on, whatever their state.
  GC_KEEP="${GC_KEEP:-main dev release}"
  removed=0; kept=0

  # The predicate lives in lib/gc-finished.sh — shared, so its red proof
  # (gc-content-check.sh) drives the same code the sweep runs.
  . "$(dirname "${BASH_SOURCE[0]}")/lib/gc-finished.sh"

  _gc_one() { # <worktree-dir> <branch>
    local wt="$1" b="$2"
    case " $GC_KEEP " in *" $b "*) echo "[do-auto] gc: $wt is $b — infrastructure, kept"; kept=$((kept+1)); return ;; esac

    if ! gc_finished "$BASE" "$b"; then
      echo "[do-auto] gc: $b carries $(gc_carries "$BASE" "$b") path(s) $BASE does not have — kept"; kept=$((kept+1)); return
    fi

    # Finished. The only thing that still earns a keep is UNCOMMITTED work — that
    # is content no merge has seen and no ref points at, so losing it loses it.
    local real; real="$(gc_real_dirt "$wt")"
    if [ -n "$real" ]; then
      echo "[do-auto] gc: $b is in $BASE but its worktree has uncommitted work — kept:"
      echo "$real" | sed "s/^/[do-auto] gc:     /"
      kept=$((kept+1)); return
    fi

    # A DRY RUN THAT DELETES IS NOT A DRY RUN. `--dry-run` is parsed by the same
    # flag loop that serves the cycle path, where it is honoured in four places —
    # but nothing here read it, so `--gc --dry-run` removed the worktree AND
    # `branch -D`'d the ref while printing a line that reads like a preview.
    # Measured 2026-09-10: it reported `removed=1 kept=2` and `feat/panel-resize`
    # and its worktree were actually gone. The content was safely in the trunk
    # that time; the flag composes in the usage string, so next time it need not
    # be. Report exactly what it WOULD do, then return without touching the disk.
    if $DRY_RUN; then
      echo "[do-auto] gc: WOULD remove $wt + branch $b (content already in $BASE) — dry run, nothing deleted"
      removed=$((removed+1)); return
    fi

    # --force gets past ephemeral dirt only: the check above already refused
    # anything that was work. `branch -d` asks "is it merged into HEAD", which is
    # the wrong question here (HEAD is usually main and $BASE is usually dev), so
    # -D is correct once content identity is proven — and it is proven, above.
    if git worktree remove --force "$wt" 2>/dev/null; then
      git branch -D "$b" >/dev/null 2>&1 \
        && echo "[do-auto] gc: removed $wt + branch $b (content already in $BASE)" \
        || echo "[do-auto] gc: removed $wt (branch $b kept — could not delete ref)"
      removed=$((removed+1))
    else
      echo "[do-auto] gc: $b is in $BASE but its worktree would not remove — inspect $wt"; kept=$((kept+1))
    fi
  }

  # ENUMERATE FROM GIT, NOT FROM A GLOB. `for wt in .claude/worktrees/*/` is
  # relative to the INVOKING tree, and a worktree contains no worktrees — so run
  # from anywhere but main and the sweep matches nothing and reports success.
  # Measured 2026-09-06 on the first run of this code: `removed=0 kept=0` with 19
  # worktrees live. It is the same trap the canon already records for land.sh and
  # release.sh ("Run MAIN's copy"), and a glob cannot be told apart from a clean
  # sweep by its output. `git worktree list` answers with absolute paths from any
  # tree, so there is no copy to run.
  SELF="$(git rev-parse --show-toplevel 2>/dev/null)"
  while IFS= read -r wt; do
    [ -d "$wt" ] || continue
    case "$wt" in *"/.do-worktrees/"*|*"/.claude/worktrees/"*) ;; *) continue ;; esac
    # Never saw off the branch you are sitting on.
    [ "$wt" = "$SELF" ] && { echo "[do-auto] gc: $wt is the invoking tree — kept"; kept=$((kept+1)); continue; }
    b="$(git -C "$wt" branch --show-current 2>/dev/null)"
    [ -n "$b" ] || { echo "[do-auto] gc: $wt is detached — kept"; kept=$((kept+1)); continue; }
    _gc_one "$wt" "$b"
  done < <(git worktree list --porcelain | sed -n 's/^worktree //p')

  echo "[do-auto] gc done: removed=$removed kept=$kept (base=$BASE ${BASE_SHA}${BASE_NOTE})"
  exit 0
fi

# _remaining/_reap_check/_reap_watcher are defined here (ahead of the SLUG
# requirement) so --self-test-lifecycle can exercise them without a plan.
_remaining() {
  # Count cycles in the Status section that are open ([ ]) or in-flight ([~]) — i.e. not [x].
  # Pattern starts with '\[' (not '-') so grep never mistakes it for an option flag.
  # grep -c already prints a count (0 on no match) but exits 1 then — capture it so
  # the `|| true` swallows the exit without appending a second "0" to the output.
  # IC3 hardened: requires the em-dash after `C<n> ` so a prose bullet like
  # "C2's collapsed into C1" is never mistaken for a real Status-block line.
  # `^[[:space:]]*` (zero-or-more, not one-or-more) so the --self-test-lifecycle
  # fixture (no leading indentation) still matches.
  local n; n=$(grep -cE '^[[:space:]]*- \[[ ~]\] \*{0,2}C[0-9]+\*{0,2} —' "$TODO" 2>/dev/null) || true
  echo "${n:-0}"
}

# The PLAN cycle this iteration is about to build — the first open C<n> in the Status
# block, same lines _remaining counts. Every emission keys on this, never on the loop
# ordinal `$i`: `i` restarts at 0 on a resume, so a resumed run building C3 would emit
# cycle:1, and the projection's run key `do:<slug>:c1` would silently append C3's trace
# to C1's closed run (text/do-as-workflow.md). Falls back to the caller's ordinal when
# the todo carries no Status block.
_plan_cycle() {
  local n; n=$(grep -oE '^[[:space:]]*- \[[ ~]\] \*{0,2}C[0-9]+\*{0,2} —' "$TODO" 2>/dev/null | grep -oE 'C[0-9]+' | head -1 | tr -d 'C') || true
  echo "${n:-${1:-0}}"
}

# IC3: keep the Status-block checkbox in sync with each cycle's own wave checkboxes —
# a cycle is done iff its `## C<n>` section has zero remaining `- [ ] W` lines.
# POSIX-portable (no gawk-only 3-arg match()) — works with BSD awk/sed (macOS) and GNU.
_sync_status() {
  local todo="$1"
  [ -f "$todo" ] || return 0
  local total_lines
  total_lines=$(wc -l < "$todo" 2>/dev/null | tr -d ' ') || return 0
  # Line numbers of every `## C<n>` header (cycle-section starts) and every
  # `## ` header (section starts in general, used to find where a cycle ends).
  local cid_lines
  cid_lines=$(grep -nE '^## C[0-9]+' "$todo" 2>/dev/null) || true
  [ -z "$cid_lines" ] && return 0
  local all_hdr_lines
  all_hdr_lines=$(grep -nE '^## ' "$todo" 2>/dev/null) || true
  local entry cid start_line end_line section
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    start_line="${entry%%:*}"
    cid=$(sed -E 's/^[0-9]+:## (C[0-9]+).*/\1/' <<<"$entry")
    # End line = line number of the next header strictly after start_line, minus 1;
    # if none, end of file.
    end_line=$(awk -F: -v s="$start_line" '$1 > s {print $1; exit}' <<<"$all_hdr_lines")
    if [ -z "$end_line" ]; then
      end_line="$total_lines"
    else
      end_line=$((end_line - 1))
    fi
    section=$(sed -n "$((start_line + 1)),${end_line}p" "$todo" 2>/dev/null)
    if ! printf '%s\n' "$section" | grep -qE '^[[:space:]]*- \[ \] W'; then
      # No open wave line left in this cycle's section — flip the Status-block
      # line for this cid from [ ]/[~] to [x] if not already ticked.
      sed -i.bak -E "s/^([[:space:]]*- \\[)[ ~](\\] \\*{0,2}${cid}\\*{0,2} —)/\\1x\\2/" "$todo" 2>/dev/null || true
      rm -f "${todo}.bak"
    fi
  done <<<"$cid_lines"
}

# IC2: reap a lingering conductor whose close-commit already landed. Split into
# a pure decision (_reap_check, unit-testable) and the polling loop (_reap_watcher).
_reap_check() {
  local cur_sha="$1" iter_sha="$2" cur_remaining="$3" iter_remaining="$4"
  [ -n "$cur_sha" ] && [ "$cur_sha" != "$iter_sha" ] && [ "$cur_remaining" -lt "$iter_remaining" ]
}

# interval/grace default to 60s/120s in production; --self-test-lifecycle passes
# 1s/1s so the fixture doesn't block on real wall-clock time.
_reap_watcher() {
  local wt="$1" cond_pid="$2" iter_sha="$3" iter_remaining="$4"
  local interval="${5:-60}" grace="${6:-120}"
  # Iteration cap (backstop): the CONDUCTOR_TIMEOUT watchdog is what actually
  # bounds this loop in production (it kills cond_pid, so `kill -0` fails and
  # the while exits) — this cap only guards against a logic regression turning
  # the loop infinite, at production defaults that's ~24h, harmless.
  local max_iters=1440 n=0
  while kill -0 "$cond_pid" 2>/dev/null; do
    n=$((n + 1)); [ "$n" -gt "$max_iters" ] && return 1
    sleep "$interval"
    kill -0 "$cond_pid" 2>/dev/null || break
    local cur_sha cur_remaining
    cur_sha=$(git -C "$wt" rev-parse HEAD 2>/dev/null || echo "")
    cur_remaining=$(_remaining)
    if _reap_check "$cur_sha" "$iter_sha" "$cur_remaining" "$iter_remaining"; then
      echo "[do-auto] reap watcher: close-commit detected (HEAD moved, remaining ${iter_remaining}→${cur_remaining}) — grace ${grace}s" >&2
      sleep "$grace"
      if kill -0 "$cond_pid" 2>/dev/null; then
        kill -TERM "$cond_pid" 2>/dev/null || true
        echo "[do-auto] reaped conductor — close-commit detected" >&2
      fi
      return 0
    fi
  done
}

# IC1: JSON sentinel — {"pid":N,"port":N,"iteration":N,"started_at":"<iso>"}.
# Port is derived deterministically from the slug so a self-started dev server
# (do-ui-gate.sh, C5) and the sentinel agree without a coordination file.
_sentinel_port() {
  echo $(( 4400 + $(cksum <<<"$1" | cut -d' ' -f1) % 100 ))
}
_write_sentinel() {
  local path="$1" pid="$2" iteration="$3" slug="$4"
  printf '{"pid":%d,"port":%d,"iteration":%d,"started_at":"%s"}\n' \
    "$pid" "$(_sentinel_port "$slug")" "$iteration" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$path"
}

# --self-test-daemon: prove the liveness guard can go RED. A guard that only ever
# reports success is the bug it is meant to prevent (this one shipped as
# `ps aux | grep -c do-auto.sh`, which reported a loop that had already died).
# True when this conductor run looks like "the API was unreachable": it died fast
# AND its output carries a transport error. Pure so --self-test-daemon can prove
# both verdicts — the guard that burned 30 iterations shipped untested.
_netfail_run() {
  local cond_secs="$1" logfile="$2"
  [ "${cond_secs:-999}" -lt 90 ] || return 1
  [ -f "$logfile" ] || return 1
  tail -c 2000 "$logfile" 2>/dev/null \
    | grep -qE 'Unable to connect to API|ENOTFOUND|ECONNREFUSED|getaddrinfo' || return 1
  return 0
}

# The HEAD of the last commit that touched something OTHER than loop bookkeeping.
# Plain HEAD is not a progress signal: a conductor that dies instantly still gets a
# commit, because .do-conductor.out (the heartbeat log) and todo.md's timestamp are
# inside the worktree. On 2026-08-07 that turned a 2-iteration stall halt into a
# 30-iteration burn — 28 subprocesses, each dying on ENOTFOUND, each committing one
# line of error text that the stall guard scored as work.
_substantive_head() {
  local wt="$1" sha
  for sha in $(git -C "$wt" log --format=%H -200 2>/dev/null); do
    if git -C "$wt" show --name-only --format= "$sha" 2>/dev/null \
       | grep -qvE '^(\.do-|\.w[0-9]|todo\.md$|$)'; then
      echo "$sha"; return 0
    fi
  done
  echo ""
}

# Stalled ONLY if nothing moved on ANY axis we can observe. Cycle checkboxes are
# too coarse to be the sole signal: a wide cycle (blocks C4) commits real work for
# an hour — 97 registrations archived, three commits — while its cycle box stays
# open until W4 closes it, so a box-only guard halts a run that is plainly working.
# Returns 0 (true, stalled) only when the box count AND the branch head are both
# unchanged from the previous iteration.
_stall_check() {
  local remaining="$1" prev_remaining="$2" head="$3" prev_head="$4"
  [ "$remaining" -eq "$prev_remaining" ] || return 1
  [ -n "$prev_head" ] && [ "$head" != "$prev_head" ] && return 1
  return 0
}

if ${SELF_TEST_DAEMON:-false}; then
  rc=0
  _t=$(mktemp -d); _self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  cd "$_t" || exit 1
  mkdir -p text .do-worktrees

  # 1. --status on a slug with no loop and open cycles must say NOT RUNNING (exit 3).
  printf -- '- [ ] C1 — nothing\n' > text/ghost-todo.md
  st=0; out=$(bash "$_self" ghost --status 2>&1) || st=$?
  if [ "$st" -eq 3 ] && grep -q "NOT RUNNING" <<<"$out"; then
    echo "[self-test-daemon] PASS: absent loop reports NOT RUNNING (exit 3)"
  else
    echo "[self-test-daemon] FAIL: absent loop reported '$out' (exit $st, wanted 3)" >&2; rc=1
  fi

  # 2. A loop that dies on startup must make --daemon exit NON-ZERO. This is the
  #    regression: `nohup setsid ...` died instantly and the launch read as success.
  #    No text/<slug>-todo.md → the child exits 1 → the owner file never appears.
  st=0; out=$(DO_DAEMON_LOG="$_t/d.log" bash "$_self" nosuchplan --daemon 2>&1) || st=$?
  if [ "$st" -ne 0 ] && grep -q "is NOT running" <<<"$out"; then
    echo "[self-test-daemon] PASS: a dead launch fails loud (exit $st)"
  else
    echo "[self-test-daemon] FAIL: dead launch reported '$out' (exit $st, wanted non-zero)" >&2; rc=1
  fi

  # 3. A live owner file must read RUNNING — the guard is not merely always-red.
  mkdir -p .do-worktrees/alive
  printf '{"pid":%d,"slug":"alive","started_at":"now"}\n' $$ > .do-worktrees/alive/.do-loop-owner
  printf -- '- [ ] C1 — nothing\n' > text/alive-todo.md
  st=0; out=$(bash "$_self" alive --status 2>&1) || st=$?
  if [ "$st" -eq 0 ] && grep -q "RUNNING" <<<"$out"; then
    echo "[self-test-daemon] PASS: a live loop reports RUNNING (exit 0)"
  else
    echo "[self-test-daemon] FAIL: live loop reported '$out' (exit $st, wanted 0)" >&2; rc=1
  fi

  # 4. the stall decision itself: a committing cycle is NOT stalled.
  if _stall_check 6 6 "sha1" "sha1"; then
    echo "[self-test-daemon] PASS: no boxes + no commits = stalled"
  else
    echo "[self-test-daemon] FAIL: flat state should count as stalled" >&2; rc=1
  fi
  if _stall_check 6 6 "sha2" "sha1"; then
    echo "[self-test-daemon] FAIL: a new commit must clear the stall" >&2; rc=1
  else
    echo "[self-test-daemon] PASS: same boxes but a new commit = progress"
  fi
  if _stall_check 5 6 "sha1" "sha1"; then
    echo "[self-test-daemon] FAIL: a ticked cycle must clear the stall" >&2; rc=1
  else
    echo "[self-test-daemon] PASS: a closed cycle = progress"
  fi

  # 5. the connectivity verdict: fast death + transport error = unreachable API.
  printf 'API Error: Unable to connect to API (ENOTFOUND)\n' > "$_t/net.log"
  if _netfail_run 3 "$_t/net.log"; then
    echo "[self-test-daemon] PASS: fast death + ENOTFOUND = unreachable"
  else
    echo "[self-test-daemon] FAIL: should have flagged an unreachable API" >&2; rc=1
  fi
  if _netfail_run 4000 "$_t/net.log"; then
    echo "[self-test-daemon] FAIL: a long run is not a connectivity failure" >&2; rc=1
  else
    echo "[self-test-daemon] PASS: a long run is never scored unreachable"
  fi
  printf 'W4 verify failed: 3 tests red\n' > "$_t/work.log"
  if _netfail_run 3 "$_t/work.log"; then
    echo "[self-test-daemon] FAIL: a real build failure must not read as network" >&2; rc=1
  else
    echo "[self-test-daemon] PASS: a fast REAL failure is not a network failure"
  fi

  cd /; rm -rf "$_t"
  [ "$rc" -eq 0 ] && echo "[self-test-daemon] all checks passed"
  exit "$rc"
fi

if $SELF_TEST_LIFECYCLE; then
  rc=0
  tmp=$(mktemp -d)
  echo "[self-test-lifecycle] stale sentinel sweep..."
  mkdir -p "$tmp/.do-worktrees/fake-slug"
  sfile="$tmp/.do-worktrees/fake-slug/.do-loop-running"
  _write_sentinel "$sfile" 99999999 1 "fake-slug"
  spid=$(jq -r '.pid // empty' "$sfile" 2>/dev/null || true)
  if [ -n "$spid" ] && kill -0 "$spid" 2>/dev/null; then
    echo "[self-test-lifecycle] FAIL: expected dead pid $spid to fail kill -0" >&2; rc=1
  else
    rm -f "$sfile"
    if [ -f "$sfile" ]; then echo "[self-test-lifecycle] FAIL: sentinel not swept" >&2; rc=1
    else echo "[self-test-lifecycle] PASS: stale sentinel swept"; fi
  fi

  echo "[self-test-lifecycle] reap watcher..."
  grepo=$(mktemp -d)
  ( cd "$grepo" && git init -q && git commit --allow-empty -q -m init )
  iter_sha=$(git -C "$grepo" rev-parse HEAD)
  TODO="$tmp/fake-todo.md"
  printf -- '- [x] C1 — reap + sentinel\n- [ ] C2 — kanban sync\n' > "$TODO"
  iter_remaining=$(_remaining)
  sleep 300 & fake_cond=$!
  ( cd "$grepo" && git commit --allow-empty -q -m close )
  printf -- '- [x] C1 — reap + sentinel\n- [x] C2 — kanban sync\n' > "$TODO"
  cur_sha=$(git -C "$grepo" rev-parse HEAD); cur_remaining=$(_remaining)
  if _reap_check "$cur_sha" "$iter_sha" "$cur_remaining" "$iter_remaining"; then
    echo "[self-test-lifecycle] PASS: reap check fires on close-commit"
  else
    echo "[self-test-lifecycle] FAIL: reap check should fire" >&2; rc=1
  fi
  _reap_watcher "$grepo" "$fake_cond" "$iter_sha" "$iter_remaining" 1 1
  sleep 1
  if kill -0 "$fake_cond" 2>/dev/null; then
    echo "[self-test-lifecycle] FAIL: fake conductor not reaped" >&2; rc=1; kill -KILL "$fake_cond" 2>/dev/null || true
  else
    echo "[self-test-lifecycle] PASS: fake conductor reaped"
  fi

  rm -rf "$tmp" "$grepo"
  [ "$rc" -eq 0 ] && echo "[self-test-lifecycle] all checks passed"
  exit "$rc"
fi

if $SELF_TEST_KANBAN; then
  rc=0
  tmp=$(mktemp -d)
  TODO="$tmp/fake-todo.md"
  cat > "$TODO" <<'EOF'
## Status

Batch 1
  - [x] C1 — reap + sentinel (do-auto lifecycle)     state: done
    - [x] W1 · W2 · W3 · W4

Batch 2
  - [ ] C2 — kanban sync + do-engine pick            state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4

Prose note: C2's collapsed into C1 because both touch the same file — not a real Status line.

## C1 — reap + sentinel
some text, no open wave boxes here

## C2 — kanban sync + do-engine pick
- [ ] W1 · W2 · W3 · W4
EOF
  before=$(_remaining)
  # Now tick C2's wave line to simulate it finishing, then sync should flip Status too
  sed -i.bak 's/^- \[ \] W1/- [x] W1/' "$TODO" && rm -f "$TODO.bak"
  _sync_status "$TODO"
  after=$(_remaining)
  if grep -qE '^\s*- \[x\] C2 —' "$TODO"; then
    echo "[self-test-kanban] PASS: Status line auto-ticked for C2"
  else
    echo "[self-test-kanban] FAIL: C2 Status line not ticked" >&2; rc=1
  fi
  if [ "$before" -eq 1 ] && [ "$after" -eq 0 ]; then
    echo "[self-test-kanban] PASS: count correct before=$before after=$after"
  else
    echo "[self-test-kanban] FAIL: count wrong before=$before after=$after (expected 1,0)" >&2; rc=1
  fi
  # _plan_cycle: the run key must name the PLAN cycle, not the loop ordinal. C1 is
  # already ticked here, so a resumed run (loop ordinal 1) building C2 must emit 2 —
  # emitting 1 would append C2's trace to C1's closed run (text/do-as-workflow.md).
  cat > "$TODO" <<'EOF'
## Status

Batch 1
  - [x] C1 — done                                    state: done
    - [x] W1 · W2 · W3 · W4
  - [ ] C2 — next                                    state: ready
    - [ ] W1 · W2 · W3 · W4
EOF
  pc=$(_plan_cycle 1)
  if [ "$pc" = "2" ]; then
    echo "[self-test-kanban] PASS: _plan_cycle resolves the open cycle (2), not the loop ordinal (1)"
  else
    echo "[self-test-kanban] FAIL: _plan_cycle=$pc (expected 2)" >&2; rc=1
  fi
  : > "$TODO"   # no Status block at all → fall back to the caller's ordinal
  pc=$(_plan_cycle 7)
  if [ "$pc" = "7" ]; then
    echo "[self-test-kanban] PASS: _plan_cycle falls back to the ordinal with no Status block"
  else
    echo "[self-test-kanban] FAIL: _plan_cycle fallback=$pc (expected 7)" >&2; rc=1
  fi
  rm -rf "$tmp"
  [ "$rc" -eq 0 ] && echo "[self-test-kanban] all checks passed"
  exit "$rc"
fi

[ -z "$SLUG" ] && { echo "usage: do-auto.sh <slug> [--max-cycles N] [--dry-run] | do-auto.sh --gc" >&2; exit 1; }

# Validate slug is safe (kebab-case only) before it touches any shell string.
# Prevents command injection if the slug ever contains metacharacters.
if ! printf '%s' "$SLUG" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'; then
  echo "[do-auto] unsafe slug (must be alphanumeric + hyphens/underscores): $SLUG" >&2; exit 1
fi

# ── Liveness is READ, never inferred ──────────────────────────────────────────
# The loop owns `.do-loop-owner` for its whole life (pid = this script's own $$,
# removed by an EXIT trap). The older `.do-loop-running` sentinel tracks the
# CONDUCTOR of the current iteration, so it is legitimately absent between
# iterations — reading it to answer "is the loop up?" reports a false DEAD.
#
# WHY THIS EXISTS: a launch was reported as running when it had died instantly
# (`nohup setsid ...` — setsid does not exist on macOS). The check used was
# `ps aux | grep -c do-auto.sh`, which cannot go red: it counts its own shell,
# a stale match, or nothing, and every outcome reads as plausible. A check that
# cannot fail is not a check. Liveness now has exactly one answer, and the only
# supported way to start a detached loop (--daemon) refuses to return success
# until it has SEEN that answer say RUNNING.
_owner_file() { echo ".do-worktrees/${1}/.do-loop-owner"; }

_loop_pid() {
  local f; f=$(_owner_file "$1")
  [ -f "$f" ] || return 1
  local pid; pid=$(jq -r '.pid // empty' "$f" 2>/dev/null || true)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
  echo "$pid"
}

if $STATUS_ONLY; then
  [ -n "$SLUG" ] || { echo "usage: do-auto.sh <slug> --status" >&2; exit 1; }
  TODO="text/${SLUG}-todo.md"
  wt=".do-worktrees/${SLUG}"
  [ -f "$wt/text/${SLUG}-todo.md" ] && TODO="$wt/text/${SLUG}-todo.md"
  rem=$(_remaining)
  if pid=$(_loop_pid "$SLUG"); then
    f=$(_owner_file "$SLUG")
    echo "[do-auto] RUNNING — slug=$SLUG pid=$pid started=$(jq -r '.started_at // "?"' "$f" 2>/dev/null) cycles-remaining=$rem"
    exit 0
  fi
  if [ "$rem" -eq 0 ] && [ -f "$TODO" ]; then
    echo "[do-auto] COMPLETE — slug=$SLUG no open cycles"
    exit 4
  fi
  echo "[do-auto] NOT RUNNING — slug=$SLUG cycles-remaining=$rem"
  exit 3
fi

if $DAEMON; then
  [ -n "$SLUG" ] || { echo "usage: do-auto.sh <slug> --daemon" >&2; exit 1; }
  if pid=$(_loop_pid "$SLUG"); then
    echo "[do-auto] already running for $SLUG (pid $pid) — not starting a second loop" >&2
    exit 0
  fi
  log="${DO_DAEMON_LOG:-.do-worktrees/${SLUG}.loop.log}"
  mkdir -p "$(dirname "$log")" 2>/dev/null || true
  # Portable detach: nohup + background + disown. NO setsid — it is Linux-only and
  # its absence is precisely the silent death this guard exists to catch.
  nohup "$0" "$SLUG" ${MAX_CYCLES:+--max-cycles "$MAX_CYCLES"} > "$log" 2>&1 < /dev/null &
  child=$!
  disown "$child" 2>/dev/null || true
  # Do not trust the fork. Wait until the loop PUBLISHES liveness, or fail loud.
  for _ in $(seq 1 60); do
    if _loop_pid "$SLUG" >/dev/null; then
      echo "[do-auto] daemon up — slug=$SLUG pid=$(_loop_pid "$SLUG") log=$log"
      echo "[do-auto]   check: bash .claude/scripts/do-auto.sh $SLUG --status"
      exit 0
    fi
    kill -0 "$child" 2>/dev/null || break
    sleep 1
  done
  echo "[do-auto] FATAL: daemon did not come up for $SLUG — the loop is NOT running." >&2
  echo "[do-auto]   log tail: $(tail -c 600 "$log" 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi

# Recursion guard: the conductor subprocess runs `/do <slug> --next-cycle` inside
# the worktree. A buggy conductor may call do-auto.sh again despite the --next-cycle
# flag. If our JSON sentinel exists AND its pid is alive, we're already inside a
# parent loop — exit cleanly. A dead pid means a prior run crashed without
# cleanup (kill -9, machine sleep) — self-heal by sweeping it instead of wedging
# every future invocation forever.
_sentinel=".do-worktrees/${SLUG}/.do-loop-running"
if [ -f "$_sentinel" ]; then
  _sentinel_pid=$(jq -r '.pid // empty' "$_sentinel" 2>/dev/null || true)
  if [ -n "$_sentinel_pid" ] && kill -0 "$_sentinel_pid" 2>/dev/null; then
    echo "[do-auto] recursion guard: parent loop already running for $SLUG (pid $_sentinel_pid) — exiting" >&2
    exit 0
  else
    echo "[do-auto] swept stale sentinel (pid ${_sentinel_pid:-unknown} dead)" >&2
    rm -f "$_sentinel"
  fi
fi

# Trust boundary: this script runs in the developer's own workspace, invoked by /do
# which resolves the slug from a text/ file the developer controls. The spawned
# claude subprocess uses --dangerously-skip-permissions because it is non-interactive
# — it cannot prompt the human for tool approvals. The workspace is the isolation
# boundary. Do not expose this script to untrusted input or run it in shared environments.
[ -f "text/${SLUG}-todo.md" ] || { echo "[do-auto] text/${SLUG}-todo.md not found — run /do $SLUG first" >&2; exit 1; }

# Conductor model is ALWAYS sonnet — the conductor reads boxes, spawns agents, ticks
# state; it needs no apex judgment. Without this pin the subprocess inherits the
# session's saved default model (the /model trap), silently running Opus/Fable
# conductors at 10-50x the cost. W2 escalation to Opus/Fable happens INSIDE the
# cycle via the Agent tool, exactly where judgment is needed.
CONDUCTOR_MODEL="sonnet"

# Conductor effort is session-level (the `claude --effort` flag). The conductor
# orchestrates — reads boxes, routes, spawns agents, ticks — so `medium` holds
# without burning the cap; raise to `high` for a flaky plan via DO_CONDUCTOR_EFFORT.
# NOTE: this sets the CONDUCTOR's effort only. Per-WAVE effort (W1 low, W2 high,
# W4 medium) is NOT controllable here — the Agent tool has no effort param. For
# true per-wave effort use the Workflow engine (.claude/workflows/do-engine.js,
# see text/do-engine-plan.md), which the interactive session drives instead of
# this shell loop.
CONDUCTOR_EFFORT="${DO_CONDUCTOR_EFFORT:-medium}"

# Per-iteration hang guard: `claude -p` has no built-in wall-clock limit, and the
# stall guard only fires BETWEEN iterations — a conductor that truly hangs would
# block the loop forever.
#
# F11 (2026-07-23): the guard is PROGRESS-BASED, not wall-clock. The old fixed
# `sleep CONDUCTOR_TIMEOUT` killed live-but-slow COMPLEX/UI cycles mid-edit (done-ui:
# a healthy cycle was murdered at 900s while actively editing). Now the watchdog
# polls the worktree for SILENCE — it resets whenever the conductor writes anything
# (new/edited files, growing diffs, a commit) and kills only after DO_IDLE_SECS of
# NO change, with an absolute DO_HARD_CAP backstop against a pathological write-loop.
# DO_CONDUCTOR_TIMEOUT is retained as the default hard-cap for back-compat.
CONDUCTOR_TIMEOUT="${DO_CONDUCTOR_TIMEOUT:-2400}"
# 60 min of TOTAL silence = hung. Not 10, and not 30 — both were measured too
# tight on blocks C4 (killed at 603s, then at 1922s, both times mid-real-work): an apex W2 (Opus/Fable deciding a wide
# cut — blocks C4 reasons over 376 registrations) legitimately spends 10-25 min
# inside a single Agent spawn, writing nothing and printing nothing. At 600s the
# guard killed a working conductor every iteration and the run could never finish
# that cycle. HARD_CAP (3x CONDUCTOR_TIMEOUT, default 7200s) remains the backstop
# against a genuinely wedged conductor, so raising this loses no real protection.
IDLE_SECS="${DO_IDLE_SECS:-3600}"
HARD_CAP="${DO_HARD_CAP:-$(( CONDUCTOR_TIMEOUT > 0 ? CONDUCTOR_TIMEOUT * 3 : 7200 ))}"  # absolute backstop
POLL_SECS="${DO_POLL_SECS:-30}"

# W1/W4 scripts (w1-recon.ts, w4-rubric.ts) exit 2 and defer to agent spawns
# through the Claude Code session (Claude Max subscription path) ONLY when no
# OPENROUTER_API_KEY resolves. With a key present — and one is present in
# one.ie/web/.env, which both scripts fall back to — they call OpenRouter and
# exit 0/1 with a REAL verdict. "Always defers" was wrong and hid that
# w4-rubric.ts gates for real: its exit 1 fails a wave without any agent
# adjudicating. Note its number is the TASK rubric (no goal-fit); the cycle gate
# is W4's own, per .claude/scripts/rubric-weights.json.

# ── Worktree isolation (one per plan) ────────────────────────────────────────
# The loop's existence IS the trigger: do-auto only runs for multi-cycle plans
# (>=2 incomplete cycles) = exactly the FEATURE/SCHEMA work that must not land
# half-built on trunk. So every loop builds in its own worktree on branch
# do/<slug>, leaving trunk green until a human merges. No tier plumbing, no flag.
#
# Why a worktree and not just a branch: the main session keeps observing trunk
# while the loop's subprocesses build in a separate checkout — they never fight
# over HEAD or the working tree. A halt leaves a clean, inspectable WIP branch.
#
#   trunk (BASE) ── never moves during the loop
#        └─ do/<slug>  (worktree .do-worktrees/<slug>) ── every cycle commits here
#   plan complete → report `git merge do/<slug>`  (human lands it — never auto)
#   halt          → worktree persists → re-run /do <slug> resumes in place
#
# BASE is pinned to main, not HEAD: a shared tree parked on someone's feature
# branch would otherwise seed every new do/<slug> with that branch's commits
# (plans cross-contaminating across concurrent sessions, 2026-07-21).
# DO_BASE_REF overrides for a deliberate stack on another branch.
# `dev` since 2026-09-06: it is the integration branch branches land into, so
# cutting from main would start every cycle missing what dev already holds.
BASE="${DO_BASE_REF:-dev}"
git show-ref --verify --quiet "refs/heads/$BASE" \
  || BASE="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
BR="do/${SLUG}"
WT=".do-worktrees/${SLUG}"

# Publish liveness the moment the worktree path is known, and retract it on ANY
# exit (clean, halt, kill, crash). This file — not `ps | grep` — is the single
# answer to "is the loop running?", and --daemon blocks until it appears.
_OWNER="$WT/.do-loop-owner"
_publish_owner() {
  mkdir -p "$WT" 2>/dev/null || true
  printf '{"pid":%d,"slug":"%s","started_at":"%s"}\n' \
    "$$" "$SLUG" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$_OWNER" 2>/dev/null || true
}
_retract_owner() {
  [ -f "$_OWNER" ] || return 0
  local own; own=$(jq -r '.pid // empty' "$_OWNER" 2>/dev/null || true)
  [ "$own" = "$$" ] && rm -f "$_OWNER"
}
if ! $SETUP_ONLY && ! $DRY_RUN; then
  _publish_owner
  trap _retract_owner EXIT INT TERM
fi

# Symlink node_modules + built SDK dist into the worktree. A git worktree omits
# gitignored dirs (node_modules), so without this a worktree can't typecheck, run
# vitest, or build — the kill-switch would fail for lack of deps, not lack of code.
# Same set do-fleet's _link_deps uses; folding it here means EVERY worktree do-auto
# cuts (inline /do, not just the fleet) is build-ready. Symlinks, so no copy cost.
_link_deps() {
  local wt="$1" root nm
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  # pay/backend + channels are here because one.ie/web's OWN vitest suite reaches
  # across into them (tests/e2e/wallets-refined.test.ts imports
  # pay/backend/src/protocol, tests/unit/chat-block-tool-filter.test.ts imports
  # channels/src/agents/builder). Without their node_modules those two suites fail
  # to COLLECT — zero tests run, vitest exits 1 — so `bun run verify` in a worktree
  # went red for a missing dep rather than a real fault (measured 2026-08-04).
  # .env belongs in this list for exactly the reason node_modules does: it is
  # gitignored, so a worktree never gets one, and the suites that need credentials
  # then fail for lack of a KEY rather than lack of correct code. Measured
  # 2026-08-31: two independent W4 verifiers both reported
  # `fixture write failed (status=0 error=no_gateway_key)` across 4-7 real-TypeDB
  # test files and had to hand-classify them as environmental — noise that makes a
  # verifier argue with its own gate. Symlinked, never copied: one file of truth,
  # and a rotated key is picked up by every live worktree at once.
  #
  # The credential file honours ONE_ENV_FILE (DO_ENV_FILE is the accepted
  # alias), like every other credential-reading script in the harness —
  # factory-repo.sh --check-env-indirection is the gate. A RELATIVE
  # ONE_ENV_FILE is linked at the same relative path inside the worktree; an
  # ABSOLUTE one is reachable from anywhere already and needs no link.
  local env_file="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
  local env_links="pay/backend/.env channels/.env"
  case "$env_file" in /*) ;; *) env_links="$env_file $env_links" ;; esac
  for nm in node_modules one.ie/web/node_modules packages/node_modules \
            packages/sdk/dist packages/sdk/node_modules \
            pay/backend/node_modules channels/node_modules \
            $env_links; do
    if [ -e "$root/$nm" ] && [ ! -e "$wt/$nm" ]; then
      mkdir -p "$wt/$(dirname "$nm")"
      ln -s "$root/$nm" "$wt/$nm" 2>/dev/null && echo "[do-auto] linked $nm" || true
    fi
  done
}

# Is $WT a REAL linked worktree, or just a directory that happens to sit inside
# the repo? `rev-parse --git-dir` cannot tell you: run from any plain directory
# under the repo root it walks UP, finds the main tree's .git, and exits 0 —
# verified 2026-08-02, `mkdir .do-worktrees/x && git -C .do-worktrees/x
# rev-parse --git-dir` prints the MAIN /Users/toc/Server/one-ie/.git.
#
# That is not academic. do-orchestrate.sh used to `mkdir -p` the worktree path so
# it could redirect a log into it BEFORE calling do-auto; this probe then said
# "resuming worktree", `git worktree add` never ran, and every later
# `git -C "$WT" commit` targeted the MAIN TREE'S HEAD — where _safe_stage
# correctly refuses to stage. Orchestrated cycles committed nothing, silently.
#
# --show-toplevel is the discriminator: from a real worktree it returns that
# worktree's own root; from a plain subdirectory it returns the main tree's root.
# Compare it against the resolved path and the two cases separate cleanly.
_is_worktree() {
  local wt="$1" abs top
  abs="$(cd "$wt" 2>/dev/null && pwd -P)" || return 1
  [ -n "$abs" ] || return 1
  top="$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ "$top" = "$abs" ]
}

_setup_worktree() {
  # Idempotent: reuse an existing worktree (resume), else attach one to an
  # existing branch (prior halt), else create branch+worktree fresh from HEAD.
  #
  # A pre-existing PLAIN directory at $WT is fatal, not recoverable: `git
  # worktree add` refuses a non-empty path, and silently proceeding is the bug
  # documented above. Empty is fine — git accepts an existing empty dir — so
  # clear that case and fail loudly on anything else.
  if [ -d "$WT" ] && ! _is_worktree "$WT"; then
    # OUR OWN liveness file is not foreign content. _publish_owner() runs long
    # before this (it fires the moment $WT is known, so --daemon can block on
    # it) and it `mkdir -p "$WT"` + writes .do-loop-owner. On a slug whose
    # worktree does not exist yet, that left a plain directory holding exactly
    # one file — ours — so the rmdir below failed and every NEW slug FATALed
    # here. The file is deleted again on exit, so the directory read as empty
    # to anyone who looked afterwards, which is what made this hard to see.
    # Drop it, then re-publish after `git worktree add` succeeds.
    rm -f "$WT/.do-loop-owner"
    rmdir "$WT" 2>/dev/null || {
      echo "[do-auto] FATAL: $WT exists but is not a git worktree, and is not empty." >&2
      echo "[do-auto]   Commits there would land on the MAIN tree's HEAD. Refusing." >&2
      echo "[do-auto]   Inspect it, then: rm -rf '$WT' && git worktree prune" >&2
      return 1
    }
    echo "[do-auto] cleared empty non-worktree dir at $WT"
  fi

  if _is_worktree "$WT"; then
    echo "[do-auto] resuming worktree $WT on $BR"
  else
    # Both add-paths below fail with "already registered" if a previous run left
    # a stale entry in .git/worktrees/<slug> — the directory deleted by hand but
    # never deregistered. prune drops ONLY registrations whose working dir is
    # gone, so it can never touch a live worktree; do-orchestrate.sh:178 already
    # relies on that. Needed here because the clear-empty-dir branch above now
    # routes more cases into `git worktree add` than the old probe ever did.
    git worktree prune 2>/dev/null || true

    if git show-ref --verify --quiet "refs/heads/$BR"; then
      echo "[do-auto] re-attaching worktree $WT to existing branch $BR"
      git worktree add "$WT" "$BR" >/dev/null
    else
      echo "[do-auto] creating worktree $WT on new branch $BR (from $BASE)"
      git worktree add -b "$BR" "$WT" "$BASE" >/dev/null
    fi
  fi

  # Re-publish liveness: the clear-empty-dir branch above deletes our owner file
  # so `git worktree add` sees an empty path. Without this, a fresh slug runs
  # with no liveness file and `--status` reports it dead while it is building.
  _publish_owner
  _link_deps "$WT"

  # Carry the plan's own artifacts into the worktree. The spine walk may have
  # just written promise/spec/todo uncommitted in the main tree; a worktree cut
  # from HEAD wouldn't have them. Copy only this slug's files — never unrelated
  # working-tree changes — then commit them as the branch baseline.
  #
  # The todo is special: the subprocess ticks checkboxes in the *worktree* copy,
  # so a blind root→worktree copy on resume would clobber committed progress
  # (reset [x]→[ ] and re-run finished cycles). Only the non-todo spine docs
  # blind-sync. For the todo, copy in only when root is strictly AHEAD — i.e.
  # has more ticked boxes than the worktree (fresh setup, or new cycles the
  # spine walk just added). If the worktree is ahead-or-equal, keep it.
  local f changed=0
  # grep -c already prints a count (0 on no match) but then exits 1; `|| true`
  # swallows the exit without appending a second line. Default to 0 if empty.
  _ticked() { local n; n=$(grep -cE '\[[xX]\]' "$1" 2>/dev/null || true); echo "${n:-0}"; }
  for f in "text/${SLUG}.md" "text/${SLUG}-plan.md" "text/${SLUG}-docs.md" \
           "text/${SLUG}-features.md" "text/${SLUG}-ui.md" "text/${SLUG}-tutorial.md" \
           "text/${SLUG}-how-to.md" "text/${SLUG}-reference.md" "text/${SLUG}-agents-docs.md" \
           ".w4-improvements.json"; do
    if [ -f "$f" ]; then
      mkdir -p "$WT/$(dirname "$f")"
      if ! cmp -s "$f" "$WT/$f" 2>/dev/null; then cp "$f" "$WT/$f"; changed=1; fi
    fi
  done
  f="text/${SLUG}-todo.md"
  if [ -f "$f" ]; then
    mkdir -p "$WT/$(dirname "$f")"
    if ! cmp -s "$f" "$WT/$f" 2>/dev/null; then
      if [ ! -f "$WT/$f" ] || [ "$(_ticked "$f")" -gt "$(_ticked "$WT/$f")" ]; then
        cp "$f" "$WT/$f"; changed=1
      else
        echo "[do-auto] worktree todo ahead-or-equal — keeping worktree progress, not clobbering"
      fi
    fi
  fi
  # Worktree-relative outcome (kill-switch hardening). The conductor runs the plan
  # `outcome:` command from the worktree root, so an ABSOLUTE repo path (e.g.
  # /Users/.../one-ie/channels) points at TRUNK and gates nothing during the
  # isolated build. Strip the repo-root prefix on the outcome line so its paths
  # resolve inside the worktree. Idempotent — a relative outcome has no prefix.
  local repo_root; repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$repo_root" ] && [ -f "$WT/$f" ] && grep -q "^outcome:.*${repo_root}/" "$WT/$f" 2>/dev/null; then
    sed -i '' "/^outcome:/ s#${repo_root}/##g" "$WT/$f" 2>/dev/null \
      && { echo "[do-auto] relativized absolute repo paths in outcome: — worktree-safe kill-switch"; changed=1; }
  fi
  # W0 rubric baseline — copy into worktree so W4 can measure delta per axis.
  # Auto-generate if missing AND a package dir named $SLUG exists (e.g. sync/, channels/).
  local rubric_src="text/${SLUG}-w0-rubric.json"
  local proj_root; proj_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ ! -f "$rubric_src" ] && [ -n "$proj_root" ] && [ -d "${proj_root}/${SLUG}" ]; then
    echo "[do-auto] W0 rubric: no baseline found — running do-rubric.py on ${SLUG}/ ..."
    python3 "${proj_root}/.claude/scripts/do-rubric.py" "$SLUG" --json > "$rubric_src" 2>/dev/null \
      || { echo "[do-auto] W0 rubric: do-rubric.py failed — skipping baseline"; rm -f "$rubric_src"; }
  fi
  if [ -f "$rubric_src" ]; then
    if ! cmp -s "$rubric_src" "$WT/.w0-rubric.json" 2>/dev/null; then
      cp "$rubric_src" "$WT/.w0-rubric.json"; changed=1
      local w0c; w0c=$(python3 -c "import json,sys; d=json.load(open('$rubric_src')); print(d.get('composite','?'))" 2>/dev/null)
      echo "[do-auto] W0 rubric baseline: composite=${w0c} (security/stability/simplicity/speed stored in .w0-rubric.json)"
    fi
  fi

  if [ "$changed" -eq 1 ]; then
    _safe_stage "$WT" "$f" ".do-trust.json" ".w4-improvements.json" ".w0-rubric.json"
    git -C "$WT" commit -q -m "do(${SLUG}): sync spine artifacts" 2>/dev/null || true
  fi
}

# _safe_stage <dir> [explicit paths…] — NEVER blanket-add on the shared main tree.
# In an isolated linked worktree (git-dir under .git/worktrees/…) a full `add -A`
# is safe — only this cycle's changes live there. On the main tree it would sweep
# concurrent windows' uncommitted work into this commit (the do(funnels) tangle,
# 2026-06-20), so we stage only the explicit paths given — or nothing, loudly.
_safe_stage() {
  local d="$1"; shift
  local gd; gd=$(git -C "$d" rev-parse --absolute-git-dir 2>/dev/null)
  case "$gd" in
    # In a worktree `add -A` is safe (only this cycle's changes live there) — BUT
    # the fleet's `_link_deps` creates node_modules/dist SYMLINKS, and the
    # `node_modules/` gitignore (trailing slash = dirs only) does NOT match a
    # symlink, so a blind add -A commits them as junk that fights every later
    # merge. Exclude them explicitly here (belt; the gitignore is the suspenders).
    */worktrees/*) git -C "$d" add -A -- . ':(exclude)**/node_modules' ':(exclude)**/dist' ':(exclude).do-digest.md' ;;
    *) if [ "$#" -gt 0 ]; then
         echo "[do-auto] main tree ($d): staging explicit paths only, never -A (avoids sweeping concurrent work)" >&2
         git -C "$d" add -- "$@" 2>/dev/null || true
       else
         echo "[do-auto] REFUSING 'git add -A' on the main tree ($d) — run cycles in a worktree. Nothing staged." >&2
       fi ;;
  esac
}

# --setup-only: the inline /do path (single-cycle · PATCH · FIX) wants the worktree
# without the subprocess loop — it runs the spine in-session, cd'd into the tree.
# Setup progress goes to stderr; stdout carries ONLY the absolute worktree path so
# the caller can `WT=$(do-auto.sh <slug> --setup-only)` cleanly.
if $SETUP_ONLY; then
  _setup_worktree 1>&2
  ( cd "$WT" && pwd )
  exit 0
fi

if ! $DRY_RUN; then
  _setup_worktree
  # All loop state now lives in the worktree — read the boxes the subprocess ticks.
  TODO="$WT/text/${SLUG}-todo.md"
  TRUST="$WT/.do-trust.json"
  # Plan arm (tasks-do C1): file the origin substrate task once per plan — a
  # worktree-local sentinel (persists across a resumed loop on the same branch)
  # keeps a re-run from re-creating it.
  if [ ! -f "$WT/.task-created" ]; then
    _title=$(grep -m1 '^title:' "$TODO" 2>/dev/null | sed 's/^title:[[:space:]]*//' | tr -d '"' || true)
    bash "$(dirname "$0")/do-signal.sh" --task-create "$SLUG" "${_title:-$SLUG}" "tags=do:cycle" >/dev/null 2>&1 || true
    # ...and one task PER CYCLE, so the substrate holds the whole plan rather than
    # a single row standing in for it. Measured 2026-09-01: lifecycle carries 10
    # cycles and 13 deliverables; exactly ONE task reached the substrate, which is
    # why `signal_tasks_cycle` had zero callers (the tasks it sets status on did
    # not exist) and why do-next.sh re-derives readiness from markdown checkboxes.
    bash "$(dirname "$0")/do-signal.sh" --task-plan "$SLUG" >/dev/null 2>&1 || true
    touch "$WT/.task-created"
  fi
else
  TODO="text/${SLUG}-todo.md"
  TRUST=".do-trust.json"
fi

# _remaining() is defined earlier (ahead of the SLUG check, for --self-test-lifecycle).

_trust() {
  jq -r '.level // "standard"' "$TRUST" 2>/dev/null || echo "standard"
}

_tier() {
  grep -m1 '^tier:' "$TODO" 2>/dev/null | sed 's/^tier:[[:space:]]*//' | tr -d '"' || echo "feature"
}

# Emit a world:do-event signal at a cycle boundary. Fire-and-forget — never blocks the loop.
# stderr is NOT swallowed: do-signal's dark-cycle guard writes there, and a worktree
# that emits nothing must say so rather than looking like a cycle that never ran.
_signal() {
  bash "$(dirname "$0")/do-signal.sh" "$@" || true
}

# Which wave checkboxes are ticked right now — the same `- [x] W` lines _sync_status
# reads. Used as the wave-trace fallback when the conductor appended no census lines.
_waves_ticked() {
  grep -oE '^[[:space:]]*- \[x\] W[0-9]' "$1" 2>/dev/null | grep -oE 'W[0-9]' | sort -u | tr '\n' ' ' || true
}

_plan_done() {
  # Plan close item is ticked. -e marks the pattern explicitly (dash-safe).
  grep -qe '\[x\].*Plan outcome command exits 0' "$TODO" 2>/dev/null
}

# Objective security gate — secret-scan + dependency audit (W4 bash-first,
# zero-LLM). Returns 0 = clean, 1 = finding. A scored security rubric can miss a
# leaked key or a known-vuln dep; this is the deterministic backstop. gitleaks or
# trufflehog when installed, else a builtin high-signal sweep of THIS cycle's diff
# (added lines only — fast, false-positive-lean). `bun audit` gates deps only when
# a lockfile/manifest moved. Every probe degrades to pass-if-tool-absent, so the
# gate blocks on a real hit, never on a missing scanner.
_secret_gate() {
  local wt="$1" rc=0
  if command -v gitleaks >/dev/null 2>&1; then
    gitleaks detect --no-git --source "$wt" --redact -q 2>/dev/null || rc=1
  elif command -v trufflehog >/dev/null 2>&1; then
    trufflehog filesystem "$wt" --no-update --fail >/dev/null 2>&1 || rc=1
  else
    local diff hits
    diff=$(git -C "$wt" diff HEAD 2>/dev/null | grep '^+' || true)
    hits=$(printf '%s\n' "$diff" | grep -nE 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}' || true)
    [ -n "$hits" ] && { echo "[do-auto] builtin secret-scan hit (cycle diff):" >&2; printf '%s\n' "$hits" | head -5 >&2; rc=1; }
  fi
  if command -v bun >/dev/null 2>&1; then
    local changed_manifests
    changed_manifests=$(git -C "$wt" diff HEAD --name-only 2>/dev/null | grep -E '(^|/)(bun\.lock|bun\.lockb|package\.json)$' || true)
    if [ -n "$changed_manifests" ]; then
      # No root package.json by design (do-folder.sh) — `bun audit` from $wt itself
      # always fails with "No package.json was found", which read as a false
      # "vulnerability" hit. Walk each changed manifest up to its nearest bun.lock
      # ancestor (every buildable folder owns one) and audit from there instead.
      local audit_roots dir found m
      audit_roots=""
      while IFS= read -r m; do
        [ -z "$m" ] && continue
        dir="$(dirname "$m")"
        found=""
        while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
          if [ -f "$wt/$dir/bun.lock" ] || [ -f "$wt/$dir/bun.lockb" ]; then found="$dir"; break; fi
          dir="$(dirname "$dir")"
        done
        [ -z "$found" ] && { [ -f "$wt/bun.lock" ] || [ -f "$wt/bun.lockb" ]; } && found="."
        [ -n "$found" ] && audit_roots="${audit_roots}${found}
"
      done <<EOF
$changed_manifests
EOF
      audit_roots=$(printf '%s' "$audit_roots" | sed '/^$/d' | sort -u)
      for f in $audit_roots; do
        ( cd "$wt/$f" && bun audit --audit-level moderate >/dev/null 2>&1 ) || { echo "[do-auto] bun audit: moderate+ vulnerability in updated deps ($f)" >&2; rc=1; }
      done
    fi
  fi
  return "$rc"
}

_merge_digest() {
  # Deterministic, zero-LLM record the human reads BEFORE landing do/<slug>.
  # Context isolation discards each cycle's reasoning to save ~90-150k tokens, so
  # without this the human merges blind — the comprehension debt a context-isolated
  # loop uniquely creates (the prose that explained the change was the scaffolding
  # we threw away). Pure git + jq: cycles closed, diffstat, gate verdict, open items,
  # cycle commits. Written to trunk's root (.do-digest.md) where the human stands.
  local digest=".do-digest.md"
  local cycles shortstat trust composite open mb behind agents
  cycles=$(grep -cE '\[[xX]\] \*{0,2}C[0-9]+' "$TODO" 2>/dev/null || true); cycles=${cycles:-0}
  # Diff from the MERGE-BASE, not BASE..BR. A two-dot BASE..BR diff conflates
  # "what this branch added" with "what trunk advanced while we built" (the
  # latter shows as spurious reversions), inflating the digest. merge-base..BR
  # is exactly the branch's own changes. `behind` reports how far trunk moved.
  mb=$(git -C "$WT" merge-base "$BASE" "$BR" 2>/dev/null || echo "$BASE")
  behind=$(git -C "$WT" rev-list --count "$mb..$BASE" 2>/dev/null || echo 0)
  shortstat=$(git -C "$WT" diff --shortstat "$mb..$BR" 2>/dev/null || true)
  trust=$(jq -r '.level // "?"' "$TRUST" 2>/dev/null || echo "?")
  composite=$(jq -r '.composite // "?"' "$TRUST" 2>/dev/null || echo "?")
  open=0
  [ -f "$WT/.w4-improvements.json" ] && open=$(jq -r 'if type=="array" then length elif type=="object" then ([.[]?]|length) else 0 end' "$WT/.w4-improvements.json" 2>/dev/null || echo 0)
  # IC7: exact agent count, not a guess — every wave agent appends a census
  # line to $WT/.do-census.jsonl as it settles (do.md wave instructions,
  # do-engine.js agent() wrapper); the digest just counts lines.
  agents=0
  [ -f "$WT/.do-census.jsonl" ] && agents=$(wc -l < "$WT/.do-census.jsonl" 2>/dev/null | tr -d ' ')
  {
    echo "# Merge digest — ${SLUG}"
    echo
    echo "Branch \`${BR}\` → \`${BASE}\`. Context isolation discarded the per-cycle reasoning to save tokens — this is the record. Read it before you land the merge."
    echo
    echo "- **Cycles closed:** ${cycles}"
    echo "- **This branch's changes (merge-base..${BR}):** ${shortstat:-none}"
    [ "${behind:-0}" -gt 0 ] && echo "- **Trunk advanced during build:** ${behind} commit(s) — run \`git merge-tree ${BASE} ${BR}\` to confirm a clean merge before landing"
    echo "- **Gate verdict:** trust=${trust} · composite=${composite}"
    echo "- **Open improvements carried:** ${open}"
    echo "- **Agents:** ${agents:-0}"
    echo
    echo "## Files changed (this branch only)"
    git -C "$WT" diff --stat "$mb..$BR" 2>/dev/null | sed 's/^/    /' || true
    echo
    echo "## Cycle commits"
    git -C "$WT" log --oneline "$mb..$BR" 2>/dev/null | sed 's/^/    /' || true
  } > "$digest" 2>/dev/null || true
}

# --- Nested-CLI probe (fail-fast) --------------------------------------------
# do-auto drives every cycle by spawning `claude -p` in a fresh session (line ~729).
# In environments without a headless claude CLI / auth, those spawns die instantly
# ("Execution error") and the loop grinds out ZERO work while LOOKING like a stall
# (verified done-ui 2026-07-23: 3 launches, 0 cycles built, ~45min wasted). Probe
# once, up front, and fail LOUDLY with the real cause + the Path-2 fallback instead
# of two silent no-progress iterations. Override with DO_SKIP_CLI_PROBE=1.
if [ "${DO_SKIP_CLI_PROBE:-0}" != "1" ] && ! $DRY_RUN; then
  ( cd "$WT" && unset CLAUDECODE CLAUDE_CODE_CHILD_SESSION CLAUDE_CODE_SESSION_ID AI_AGENT && \
    claude --model "$CONDUCTOR_MODEL" --dangerously-skip-permissions -p "Reply with exactly: PROBE_OK" ) >"$WT/.do-probe.out" 2>&1 &
  _probe_pid=$!
  ( sleep 45; kill -0 "$_probe_pid" 2>/dev/null && { pkill -f "PROBE_OK" 2>/dev/null || true; kill -TERM "$_probe_pid" 2>/dev/null || true; } ) &
  _probe_wd=$!
  wait "$_probe_pid" 2>/dev/null || true
  kill "$_probe_wd" 2>/dev/null || true
  if ! grep -q "PROBE_OK" "$WT/.do-probe.out" 2>/dev/null; then
    echo "[do-auto] FATAL: nested \`claude -p\` cannot run in this environment — the conductor would build zero work." >&2
    echo "[do-auto]   probe said: $(head -c 200 "$WT/.do-probe.out" 2>/dev/null | tr '\n' ' ')" >&2
    echo "[do-auto]   Run Path 2 instead (in-process agents, no nested CLI):" >&2
    echo "[do-auto]     Workflow({scriptPath: \".claude/workflows/do-engine.js\", args:{slug:\"$SLUG\"}})" >&2
    rm -f "$WT/.do-probe.out"
    _signal halt "$SLUG" "$(_tier)" 0 "reason=nested-cli-unavailable" 2>/dev/null || true
    exit 3
  fi
  rm -f "$WT/.do-probe.out"
  echo "[do-auto] nested-CLI probe: ok"
fi

i=0
prev_remaining=-1
stall=0
while [ "$i" -lt "$MAX_CYCLES" ]; do
  if _plan_done; then
    echo "[do-auto] plan complete — outcome line ticked"
    break
  fi

  _sync_status "$TODO"
  remaining=$(_remaining)
  if [ "$remaining" -eq 0 ]; then
    echo "[do-auto] no open cycles — plan complete"
    break
  fi

  # Stall guard: a cycle that ticks no box means the subprocess halted/errored.
  # Retrying the identical state forever just burns subprocesses — halt after 2 stalls.
  # Connectivity abort: a conductor that dies in seconds with a transport error
  # built nothing and will keep building nothing until the network returns. Burning
  # the whole --max-cycles budget on it (30 dead subprocesses, measured 2026-08-07)
  # teaches nothing and buries the real state. Three in a row = stop and say why.
  if _netfail_run "${_cond_secs:-999}" "$WT/.do-conductor.out"; then
    netfail=$((${netfail:-0} + 1))
    if [ "$netfail" -ge 3 ]; then
      echo "[do-auto] FATAL: the conductor failed to reach the API 3 times in a row (last run ${_cond_secs}s)." >&2
      echo "[do-auto]   This is a connectivity problem, not a plan problem — nothing was built." >&2
      echo "[do-auto]   Check the network, then re-run: bash .claude/scripts/do-auto.sh $SLUG --daemon" >&2
      echo "[do-auto]   WIP preserved on branch $BR (worktree $WT)." >&2
      _signal halt "$SLUG" "$(_tier)" "$(_plan_cycle "$i")" "reason=api-unreachable" 2>/dev/null || true
      exit 1
    fi
  else
    netfail=0
  fi

  _cur_head=$(_substantive_head "$WT")
  if _stall_check "$remaining" "$prev_remaining" "$_cur_head" "${prev_head:-}"; then
    stall=$((stall + 1))
    if [ "$stall" -ge 2 ]; then
      echo "[do-auto] no progress for 2 iterations (${remaining} cycle(s) stuck) — halting." >&2
      echo "[do-auto] The last cycle ticked no checkbox AND committed nothing. Inspect $TODO, fix the blocker, then re-run /do $SLUG." >&2
      echo "[do-auto] WIP preserved on branch $BR (worktree $WT)." >&2
      _signal halt "$SLUG" "$(_tier)" "$(_plan_cycle "$i")" "reason=stall"
      exit 1
    fi
  else
    stall=0
  fi
  prev_head="$_cur_head"
  prev_remaining=$remaining

  trust=$(_trust)
  if [ "$trust" = "cautious" ]; then
    echo "[do-auto] trust=cautious — halting. Fix the issue, then re-run /do $SLUG."
    echo "[do-auto] WIP preserved on branch $BR (worktree $WT)."
    _signal halt "$SLUG" "$(_tier)" "$(_plan_cycle "$i")" "reason=trust-cautious"
    exit 1
  fi

  i=$((i + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "[do-auto] iteration ${i} — ${remaining} cycle(s) remaining — trust=${trust}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Autonomous passthrough: when the orchestrator set DO_AUTONOMOUS=1, tell the
  # conductor to resolve gates by rule instead of asking (do.md "Autonomous gate
  # resolution"). Without this the headless cycle wedges on AIM/CLARIFY/anchor-miss.
  AUTO_FLAG=""
  [ "${DO_AUTONOMOUS:-}" = "1" ] && AUTO_FLAG=" --autonomous"

  # Ask world:pick-model which model has proven best for this task shape.
  # Fire-and-forget: on any error (no server, no auth, timeout) keeps the
  # CONDUCTOR_MODEL default (sonnet). The model id returned is the full
  # canonical id (e.g. claude-haiku-4-5-20251001); map to the short alias
  # claude uses (haiku/sonnet/opus) by stripping the prefix.
  { _pm=$(curl -sf --max-time 5 -X POST \
      -H 'Content-Type: application/json' \
      -d "{\"shape\":\"do:$(_tier)\"}" \
      "${DO_SIGNAL_URL:-https://one.ie}/api/ask/world:pick-model" 2>/dev/null) \
    && _pm_model=$(printf '%s' "$_pm" | grep -o '"model":"[^"]*"' | sed 's/"model":"//;s/"//g') \
    && [ -n "$_pm_model" ] && CONDUCTOR_MODEL="$_pm_model"; } 2>/dev/null || true

  if $DRY_RUN; then
    echo "[do-auto] DRY RUN: would invoke — claude --model $CONDUCTOR_MODEL --effort $CONDUCTOR_EFFORT --dangerously-skip-permissions -p \"/do $SLUG --next-cycle${AUTO_FLAG}\""
    break
  fi

  # Emit cycle-open signal (world:do-event type:aim) before the conductor starts.
  # One plan-cycle number for EVERY emission this iteration — resolved BEFORE the
  # conductor runs, since the conductor ticks the cycle closed and the post-wait
  # emissions would otherwise resolve to the NEXT cycle.
  _cyc=$(_plan_cycle "$i")
  _signal aim "$SLUG" "$(_tier)" "$_cyc"
  # Lease the plan's substrate task (tasks-do C1/C5 — claim = lease, same verb
  # do-fleet.sh checks before spawning a worktree). Asserted: a TypeDB-down or
  # gateway miss is logged (never disguised as ok) and never aborts the cycle.
  _claim_rc=0
  bash "$(dirname "$0")/do-signal.sh" --task-claim "$SLUG" >/dev/null || _claim_rc=$?
  if [ "$_claim_rc" -ne 0 ]; then
    echo "board-write: claim FAILED (exit ${_claim_rc})" >&2
  fi

  # C6: Trail confidence hint — query KV trail before spawning the conductor.
  # If confidence ≥ 0.8, write .do-trail-hint.json in the worktree so W1 can skip W2.
  _trail_base="${ONEIE_BASE_URL:-${ONE_BASE_URL:-https://one.ie}}"
  _trail_key="${ONEIE_API_KEY:-${ONE_API_KEY:-}}"
  _plan_tags=$(grep -m1 '^tags:' "$WT/text/${SLUG}-todo.md" 2>/dev/null \
    | sed 's/^tags:[[:space:]]*\[//;s/\]//;s/ //g;s/,/ /g' | tr ' ' '\n' \
    | grep -v '^$' | sort | tr '\n' ',' | sed 's/,$//' || true)
  if [ -n "$_plan_tags" ] && [ -n "$_trail_key" ]; then
    # Token off argv (ps aux would leak a bare -H value) — one-shot 0600 curl config.
    _trail_authcfg="$(mktemp)"; chmod 600 "$_trail_authcfg"
    printf 'header = "Authorization: Bearer %s"\n' "$_trail_key" >"$_trail_authcfg"
    _trail_resp=$(curl -sf --max-time 5 \
      --config "$_trail_authcfg" \
      "${_trail_base%/}/api/export/trail?tags=${_plan_tags}" 2>/dev/null) || _trail_resp=""
    rm -f "$_trail_authcfg"
    if [ -n "$_trail_resp" ]; then
      _trail_conf=$(printf '%s' "$_trail_resp" | grep -o '"confidence":[0-9.]*' | head -1 | cut -d: -f2 || echo "0")
      echo "[do-auto] trail confidence=${_trail_conf} for tags=${_plan_tags}"
      _threshold="0.8"
      if awk "BEGIN{exit !($_trail_conf >= $_threshold)}" 2>/dev/null; then
        printf '%s' "$_trail_resp" > "$WT/.do-trail-hint.json"
        echo "[do-auto] trail confidence ≥ ${_threshold} — hint written (.do-trail-hint.json); W2 may be skipped"
      fi
    fi
  fi

  # Fresh context, isolated tree: the subprocess runs INSIDE the worktree, so
  # every edit/box-tick/state-write lands on branch $BR — trunk is never touched.
  # Sentinel prevents the conductor from spawning a recursive do-auto.sh loop.
  # Pick the conductor model — fallback to sonnet (world:pick-model not yet wired).
  _shape_pick="do:$(_tier)"
  if [ -n "${_axis:-}" ]; then _shape_pick="${_shape_pick}·${_axis}"; fi

  # HEAD baseline + open-cycle baseline captured BEFORE the conductor runs — the
  # reap watcher (IC2) compares against these to detect a close-commit.
  _iter_sha=$(git -C "$WT" rev-parse HEAD 2>/dev/null || echo "")
  _iter_remaining="$remaining"

  # Wave-trace baselines, captured BEFORE the conductor runs (text/do-as-workflow.md).
  _census_base=0
  [ -f "$WT/.do-census.jsonl" ] && _census_base=$(wc -l < "$WT/.do-census.jsonl" 2>/dev/null | tr -d ' ')
  _waves_base=$(_waves_ticked "$TODO")

  # Run the conductor in the background with a bash-native, PROGRESS-BASED watchdog
  # (macOS has no `timeout`). It kills the conductor only after IDLE_SECS of worktree
  # SILENCE (or the HARD_CAP absolute backstop) — never mid-edit on a slow-but-live
  # cycle. Matches the claude process by its --next-cycle command line.
  # Unset Claude Code session vars so the subprocess starts a fresh session instead
  # of being blocked by the anti-nesting guard (CLAUDECODE/CLAUDE_CODE_CHILD_SESSION).
  # CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 — wait indefinitely for the conductor's
  # background tasks. The CLI default terminates a -p run whose background work is
  # still going after 600s, which kills a LIVE conductor mid-decision: a wide W2
  # (blocks C4 reasons over 376 registrations) always exceeds it, so that cycle can
  # never close and every iteration burns identically until the stall guard halts.
  # Bounding the conductor is already do-auto's own job, and its guards are the ones
  # that can tell alive-but-slow from hung: IDLE_SECS (no worktree write) and
  # HARD_CAP. Deferring to a print-wait ceiling that cannot see the worktree trades a
  # real halt for a fake one.
  # The conductor's own output is a heartbeat: tee it into the worktree so the
  # find -newer probe below counts "the conductor is still talking" as progress.
  # Without this, the only progress signal is a file write — and a wide W2 spends
  # its whole life inside one Agent spawn, writing nothing.
  ( cd "$WT" && unset CLAUDECODE CLAUDE_CODE_CHILD_SESSION CLAUDE_CODE_SESSION_ID AI_AGENT && CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS="${DO_BG_WAIT_CEILING_MS:-0}" claude --model "$CONDUCTOR_MODEL" --effort "$CONDUCTOR_EFFORT" --dangerously-skip-permissions -p "/do $SLUG --next-cycle${AUTO_FLAG}" ) > >(tee -a "$WT/.do-conductor.out") 2>&1 &
  cond_pid=$!
  _cond_t0=$(date +%s)
  _write_sentinel "$WT/.do-loop-running" "$cond_pid" "$i" "$SLUG"
  # Progress signal (F11): ANY file written under the worktree since the last poll —
  # code edits, new files, commits, AND gitignored state (.w2-spec.json, .w1-cache/,
  # .do-census.jsonl) that a git-only signal would miss during a long W1/W2 phase that
  # writes no tracked code. `find -newer <marker> | head -1` is POSIX-portable (BSD +
  # GNU). Marker lives OUTSIDE the worktree so it never lands in a commit; excludes
  # .git + node_modules (the linked heavy tree).
  _wd_marker="${TMPDIR:-/tmp}/.do-wd-${SLUG}-$$"; : > "$_wd_marker"
  ( _t0=$(date +%s); _last_change=$_t0
    while kill -0 "$cond_pid" 2>/dev/null; do
      sleep "$POLL_SECS"
      _now=$(date +%s)
      if [ -n "$(find "$WT" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -newer "$_wd_marker" 2>/dev/null | head -1)" ]; then
        : > "$_wd_marker"; _last_change=$_now
      fi
      _idle=$(( _now - _last_change )); _elapsed=$(( _now - _t0 ))
      if [ "$_idle" -ge "$IDLE_SECS" ]; then
        echo "[do-auto] conductor idle ${_idle}s (no worktree write ≥ ${IDLE_SECS}s) — terminating (progress guard); stall guard halts if no box ticked." >&2
        pkill -f "do ${SLUG} --next-cycle" 2>/dev/null || true
        kill -TERM "$cond_pid" 2>/dev/null || true; sleep 5; kill -KILL "$cond_pid" 2>/dev/null || true; break
      fi
      if [ "$_elapsed" -ge "$HARD_CAP" ]; then
        echo "[do-auto] conductor exceeded hard cap ${HARD_CAP}s (writing but never closing) — terminating (backstop)." >&2
        pkill -f "do ${SLUG} --next-cycle" 2>/dev/null || true
        kill -TERM "$cond_pid" 2>/dev/null || true; sleep 5; kill -KILL "$cond_pid" 2>/dev/null || true; break
      fi
    done
    rm -f "$_wd_marker" ) &
  wd_pid=$!
  # IC2: reap a conductor that's already committed its close but is still idling
  # (e.g. waiting on a tool call that never returns) — the 3600s+ hang guard above
  # stays as the backstop for a truly stuck conductor; this catches the faster,
  # more common case of "done but not exiting."
  TODO="$WT/text/${SLUG}-todo.md" _reap_watcher "$WT" "$cond_pid" "$_iter_sha" "$_iter_remaining" &
  reap_pid=$!
  # Board heartbeat (IC: the lease must outlive the cycle). `tasks:claim` stamps
  # `updated-at-ms`; a `picked` row older than CLAIM_LEASE_TTL_MS (45 min,
  # one.ie/web/src/lib/resolvers/tasks.ts:92) is STALE, and both `tasks:reap` (which
  # tasks-loop.sh runs FIRST on every pass) and `tasks:claim`'s own stale branch will
  # reopen it and hand the row to another worker. do-auto wrote exactly three board
  # events per plan — create/claim/link — with nothing between claim and link, while
  # p100 fleet duration is 79 min. So a live cycle crossed the TTL and its work could
  # be double-claimed, discovered only at merge. This ticker is what makes the lease
  # honest; the per-wave heartbeat below is the progress trace, not the keep-alive.
  # Default 900s = 3x margin inside the TTL. Fire-and-forget like every other signal.
  ( while kill -0 "$cond_pid" 2>/dev/null; do
      sleep "${DO_HEARTBEAT_SECS:-900}"
      kill -0 "$cond_pid" 2>/dev/null || break
      _hb_waves=$(_waves_ticked "$TODO" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
      bash "$(dirname "$0")/do-signal.sh" --task-heartbeat "$SLUG" \
        "cycle ${_cyc} in flight — waves: ${_hb_waves:-none yet}" >/dev/null 2>&1 || true
    done ) &
  hb_pid=$!
  wait "$cond_pid" 2>/dev/null || true
  _cond_secs=$(( $(date +%s) - ${_cond_t0:-$(date +%s)} ))
  kill "$wd_pid" 2>/dev/null || true   # conductor finished first — cancel the watchdog
  kill "$reap_pid" 2>/dev/null || true # conductor finished first — cancel the reap watcher
  kill "$hb_pid" 2>/dev/null || true   # conductor finished first — cancel the board heartbeat
  # Kill any child do-auto.sh the conductor may have spawned despite --next-cycle.
  pkill -f "do-auto.sh ${SLUG}" 2>/dev/null || true
  sleep 1
  rm -f "$WT/.do-loop-running" "${_wd_marker:-}"   # marker cleanup (subshell's rm is skipped when the conductor finishes first)

  # Wave trace (text/do-as-workflow.md deliverable 1) — one `wave` event per wave this
  # iteration ticked, in order, so the run record carries the wave-by-wave trace and a
  # W3.5 reloop shows as repeated w3/w4 entries. Drained in the FOREGROUND after the
  # wait: the watchdog subshell is killed the instant the conductor exits, which would
  # systematically drop the closing W4. The census is the primary source (it records
  # every agent settle, reloops included); it is an instruction to the conductor, not a
  # mechanical guarantee, so a cycle that appended none falls back to the wave
  # checkboxes it DID tick. Fire-and-forget, like every other _signal.
  _census_now=0
  [ -f "$WT/.do-census.jsonl" ] && _census_now=$(wc -l < "$WT/.do-census.jsonl" 2>/dev/null | tr -d ' ')
  _new_waves=""
  if [ "${_census_now:-0}" -gt "${_census_base:-0}" ]; then
    _new_waves=$(tail -n "+$((_census_base + 1))" "$WT/.do-census.jsonl" 2>/dev/null \
      | sed -n 's/.*"wave"[[:space:]]*:[[:space:]]*"\(W[0-9]\)".*/\1/p' || true)
  else
    for _w in $(_waves_ticked "$TODO"); do
      case " ${_waves_base} " in *" ${_w} "*) ;; *) _new_waves="${_new_waves} ${_w}" ;; esac
    done
  fi
  for _w in $_new_waves; do
    _signal wave "$SLUG" "$(_tier)" "$_cyc" "wave=${_w}"
    # Same wave close, second surface: a tasks:comment bumps `updated-at-ms`, so the
    # task sheet's timeline becomes the wave-by-wave trace a human watches at
    # /tasks/board — and each one re-arms the lease. Mirrors do-engine.js:427.
    bash "$(dirname "$0")/do-signal.sh" --task-heartbeat "$SLUG" \
      "cycle ${_cyc} · ${_w} close" >/dev/null 2>&1 || true
  done

  # Objective security gate (W4 bash-first, zero-LLM): before the cycle lands on
  # the branch, secret-scan the worktree + audit deps. A scored security score can
  # miss a leaked key or known-vuln dep; this is the deterministic backstop — a
  # finding halts the loop so the secret never gets committed. Runs independent of
  # the porcelain check so a self-committing conductor cannot bypass it.
  if ! _secret_gate "$WT"; then
    echo "[do-auto] secret-scan / bun audit found an issue — NOT committing cycle ${i}." >&2
    echo "[do-auto] Inspect $WT, remove the secret/vuln, then re-run /do $SLUG. WIP preserved on $BR." >&2
    _signal halt "$SLUG" "$(_tier)" "$_cyc" "reason=secret-gate"
    exit 1
  fi

  # Commit the cycle on its branch. A cycle closes with a passing rubric, so it
  # is the natural commit unit — and committed progress survives a later halt.
  if [ -n "$(git -C "$WT" status --porcelain)" ]; then
    _safe_stage "$WT"
    git -C "$WT" commit -q -m "do(${SLUG}): cycle ${i}" || true
  fi

  # Sync loop state back to the main tree EVERY iteration. Trust and improvements
  # gate the NEXT plan's behavior — stranded in the worktree they read days stale
  # on main (the bug this fixes: voice closed at trust=trusted while main still
  # said plan=connect from two days prior). Todo boxes stay worktree-only; they
  # arrive on main via the merge.
  for f in .do-trust.json .w4-improvements.json; do
    [ -f "$WT/$f" ] && cp "$WT/$f" "$f"
  done

  # Emit cycle-close signal (world:do-event type:learn) after state is synced.
  # shape = dominant axis (lowest-scoring advanced dim, remapped simplicity→structure).
  # model = conductor model (C1 deliverable — receiver prepends model: for the actor aid).
  _composite=$(jq -r '.composite // ""' "$TRUST" 2>/dev/null || true)
  _axis=$(jq -r 'if type=="array" then ([.[] | select(.score < 1.0)] | if length > 0 then (min_by(.score) | .dim // "") else "" end) else "" end' "$WT/.w4-improvements.json" 2>/dev/null || true)
  # remap simplicity → structure (UI label from the four-S spec; substrate attr stays rubric-simplicity)
  [ "$_axis" = "simplicity" ] && _axis="structure"
  _shape=""
  [ -n "$_axis" ] && _shape="shape=do:$(_tier)·${_axis}"
  _model="model=${CONDUCTOR_MODEL}"
  # worktags = the plan's dept+topic tags (the vocabulary real tasks carry) — the reputation
  # harvest credits these tag-nodes so tasks:mine ranks by proven work (text/reputation.md § A).
  _worktags=$(python3 "$(dirname "$0")/do-rank.py" --worktags "$SLUG" 2>/dev/null || true)
  if [ -n "$_composite" ]; then
    _signal learn "$SLUG" "$(_tier)" "$_cyc" "composite=${_composite}" ${_shape:+"$_shape"} "$_model" ${_worktags:+"worktags=$_worktags"}
  else
    _signal learn "$SLUG" "$(_tier)" "$_cyc" ${_shape:+"$_shape"} "$_model" ${_worktags:+"worktags=$_worktags"}
  fi
done

if $DRY_RUN; then exit 0; fi

if [ "$i" -ge "$MAX_CYCLES" ]; then
  echo "[do-auto] hit --max-cycles $MAX_CYCLES — halting"
  echo "[do-auto] WIP preserved on branch $BR (worktree $WT)."
  _signal halt "$SLUG" "$(_tier)" "$(_plan_cycle "$i")" "reason=max-cycles"
  # A halt still closes. --status timeout is the honest word: the lease stays
  # held and the task is NOT marked done, so the next run resumes rather than
  # re-opening finished work. Rule 1 has no exception for halts.
  bash "$(dirname "$0")/do-close.sh" "$SLUG" --status timeout || true
  exit 1
fi

# Plan complete. The branch holds every cycle, proven and committed; trunk is
# untouched. Landing it is a human decision (commit/push only when asked), so we
# report the merge instead of running it — the worktree stays for inspection.
# Write the digest FIRST so the report can point the human at it: the loop threw
# away the reasoning to stay cheap, so the digest is the only thing left to read
# before an irreversible merge.
_merge_digest
# Close the loop on the origin task (tasks-do C1): the handoff-completion
# record — provenance line + task-status:done — lands once, at PLAN close,
# not per cycle (a plan's cycles all serve the same origin task). Asserted:
# a failed link is logged with its exit, never disguised as ok; the plan
# still completed its code.
#
# do-close.sh is the whole close, not just the link: the board write (through
# this same slug door), the receipt check that gates it, the rubric dims, the
# feedback pheromone and the promise settle — bounded, in ~5s, and whatever it
# cannot close it FILES with the command that finishes it. It exits 0 by design
# even with open legs; a close that can fail a plan is a close plans skip.
bash "$(dirname "$0")/do-close.sh" "$SLUG" --composite "${_composite:-}" || true
echo ""
echo "[do-auto] ✓ plan complete on branch $BR — trunk ($BASE) untouched."
echo "[do-auto]   read:    .do-digest.md                 # what landed + gate verdict (reasoning was discarded)"
echo "[do-auto]   land:    git merge --no-ff $BR        # from $BASE"
echo "[do-auto]   inspect: git -C $WT log --oneline $BASE..$BR"
echo "[do-auto]   discard: git worktree remove $WT && git branch -D $BR"
echo "[do-auto]   gc:      after landing, run — .claude/scripts/do-auto.sh --gc"

# ── GC mode: sweep worktrees whose branches are fully merged ────────────────
# Invoked as `do-auto.sh --gc` (handled below via the flag parser) OR run here
# opportunistically for OTHER plans' leftovers: any .do-worktrees/<s> whose
# branch has 0 commits not in $BASE is finished work — remove it. Safe-only
# commands: `worktree remove` refuses a dirty tree, `branch -d` refuses
# unmerged. Active/unmerged worktrees are reported, never touched.
for wt in .do-worktrees/*/; do
  [ -d "$wt" ] || continue
  s=$(basename "$wt")
  [ "$s" = "$SLUG" ] && continue   # never GC the plan we just ran — human inspects first
  b="do/${s}"
  git show-ref --verify --quiet "refs/heads/$b" || continue
  if [ "$(git rev-list --count "${BASE}..${b}" 2>/dev/null || echo 1)" -eq 0 ]; then
    if git worktree remove "$wt" 2>/dev/null && git branch -d "$b" 2>/dev/null; then
      echo "[do-auto] gc: removed merged worktree $wt + branch $b"
    else
      echo "[do-auto] gc: $wt is merged but dirty — inspect manually" >&2
    fi
  fi
done
