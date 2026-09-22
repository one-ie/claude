#!/usr/bin/env bash
# test-cached.sh <folder> -- <vitest args...> — run a vitest selection, or reuse
# the PASS someone already computed for this exact input. Exits 0 on pass/hit,
# non-zero on fail or on could-not-run.
#
# manifest: needs-env
#
# WHY. The dev lane re-ran identical work on every cycle. The pinned block alone
# is 44 files / 420 tests / ~20s, and it runs on EVERY cycle regardless of the
# diff -- so a plan of six cycles paid it six times for a tree whose pinned
# surface never moved. Same for `vitest related` when two cycles touch the same
# file. Measured 2026-09-01: fast lane ~30s/cycle, two thirds of it the pins.
#
# The key is the exact INPUT to the run, so a hit is sound by construction:
#   sha( vitest args + content of every selected test file
#      + content of every tracked source file that differs from the base )
# Nothing else can change the answer. Change a test, change a source file it
# reads, or change the selection, and the key moves. This is the tsc-cached.sh
# idiom (one compute per tree-fingerprint, everyone else reuses) narrowed from
# the whole tree to the actual inputs of one selection.
#
# ONLY PASSES ARE CACHED. A red result is never memoised: a failing gate must be
# re-run every single time until it is green, because the value of a gate is that
# it keeps saying no. This is the `unrun-gate-is-not-a-pass` rule applied to its
# mirror image -- a *remembered* pass is only a pass while its inputs are identical.
#
# TEST_CACHE_DISABLE=1 forces a real run (and still records the result).
# --self-test runs the fixtures.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE_DIR="${TEST_CACHE_DIR:-${TMPDIR:-/tmp}/one-test-cache}"
MAX_AGE_DAYS="${TEST_CACHE_MAX_AGE_DAYS:-7}"

_self_test() {
  local t fails=0
  t="$(mktemp -d)"; export TEST_CACHE_DIR="$t"
  # 1. a PASS is remembered
  bash "$ROOT/.claude/scripts/test-cached.sh" __probe__ -- --probe-pass >/dev/null 2>&1
  local r1=$?
  local out2; out2=$(bash "$ROOT/.claude/scripts/test-cached.sh" __probe__ -- --probe-pass 2>&1)
  if printf '%s' "$out2" | grep -q 'cache HIT'; then echo "ok: pass is remembered"
  else echo "FAIL: identical pass did not hit (r1=$r1): $out2"; fails=$((fails+1)); fi
  # 2. RED PROOF — a FAIL must never be remembered
  bash "$ROOT/.claude/scripts/test-cached.sh" __probe__ -- --probe-fail >/dev/null 2>&1
  local out3; out3=$(bash "$ROOT/.claude/scripts/test-cached.sh" __probe__ -- --probe-fail 2>&1)
  if printf '%s' "$out3" | grep -q 'cache HIT'; then
    echo "FAIL: a RED result was cached — the gate would stop biting"; fails=$((fails+1))
  else echo "ok: a fail is never cached (re-runs every time)"; fi
  # 3. a different selection must not collide with a remembered pass
  local out4; out4=$(bash "$ROOT/.claude/scripts/test-cached.sh" __probe__ -- --probe-pass --extra 2>&1)
  if printf '%s' "$out4" | grep -q 'cache HIT'; then
    echo "FAIL: different args collided with a cached key"; fails=$((fails+1))
  else echo "ok: key discriminates on args"; fi
  # 4. RED PROOF against a REAL vitest -- a genuinely failing run must exit
  # non-zero AND leave no stamp. Checks 1-3 use the __probe__ folder, which never
  # touches the runner; this one drives the actual code path the gate uses.
  local pt; pt="$(mktemp -d)"
  cat > "$pt/red.test.ts" <<'REDEOF'
import { it, expect } from "vitest";
it("is deliberately red", () => { expect(1).toBe(2); });
REDEOF
  local before after
  before=$(ls "$t" 2>/dev/null | wc -l | tr -d ' ')
  if TEST_CACHE_DIR="$t" bash "$ROOT/.claude/scripts/test-cached.sh" \
       one.ie/web -- --reporter=dot --root "$pt" >/dev/null 2>&1; then
    echo "FAIL: a red vitest exited 0"; fails=$((fails+1))
  else echo "ok: a real failing vitest exits non-zero"; fi
  after=$(ls "$t" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$before" = "$after" ]; then echo "ok: a red run recorded no stamp"
  else echo "FAIL: a red run wrote a cache stamp"; fails=$((fails+1)); fi

  # 5. the pty path, only where it can actually be exercised. `script -qeF` needs
  # a controlling tty on stdin; without one it dies with
  # "tcgetattr/ioctl: Operation not supported on socket" -- which is a NON-ZERO
  # exit, so a naive red proof here passes for the wrong reason and proves
  # nothing about status propagation. Measured 2026-09-01. An unrunnable check
  # reports n/a; it is never reported as ok.
  if [ -t 0 ]; then
    before=$(ls "$t" 2>/dev/null | wc -l | tr -d ' ')
    if TEST_CACHE_PTY=1 TEST_CACHE_DIR="$t" bash "$ROOT/.claude/scripts/test-cached.sh" \
         one.ie/web -- --reporter=dot --root "$pt" >/dev/null 2>&1; then
      echo "FAIL: a red vitest under the pty wrapper exited 0"; fails=$((fails+1))
    else echo "ok: pty wrapper propagates a red exit status"; fi
    after=$(ls "$t" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$before" = "$after" ]; then echo "ok: a red pty run recorded no stamp"
    else echo "FAIL: a red pty run wrote a cache stamp"; fails=$((fails+1)); fi
  else
    echo "n/a: no controlling tty — the pty wrapper cannot be exercised here (NOT a pass)"
  fi
  rm -rf "$pt"
  rm -rf "$t"
  [ "$fails" -eq 0 ] && { echo "test-cached: self-test PASS"; return 0; }
  echo "test-cached: self-test FAILED ($fails)"; return 1
}
[ "${1:-}" = "--self-test" ] && { _self_test; exit $?; }

folder="${1:-}"; shift || true
[ "${1:-}" = "--" ] && shift
[ -n "$folder" ] || { echo "usage: test-cached.sh <folder> -- <vitest args>" >&2; exit 2; }
ARGS=("$@")

# --- key -------------------------------------------------------------------
# Selected test files: whichever of the args name a real file, plus (for a
# substring selection like the pins) the files those substrings resolve to.
_sel=""
for a in "${ARGS[@]}"; do
  case "$a" in
    --*) continue ;;
    *) _sel="$_sel$a"$'\n' ;;
  esac
done

# <hash>  <repo-relative path> — the shape `shasum <file>` prints, minus $ROOT.
#
# This is the SECOND memo key of the two the governor owns, and it is now
# computed by lib/govern.ts (cycle 16) — the same program that computes
# tsc_tree_fingerprint, so both keys have one implementation and one place to be
# wrong. The BYTES ARE IDENTICAL to the `shasum -a 256 < file | cut -d' ' -f1`
# form it replaces, including the empty hash a missing file produced, so every
# stamp already on disk still hits: verified 2026-09-04 by comparing
# TEST_CACHE_KEY_ONLY=1 across three selections before and after.
# GOVERN_BUN unresolvable -> the hash comes back empty for every file, which
# moves the key rather than freezing it, so a broken toolchain can only cost a
# re-run and can never replay a stale pass.
_GOV_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/govern.sh"
# shellcheck source=lib/govern.sh
[ -r "$_GOV_LIB" ] && . "$_GOV_LIB"
if command -v _gov >/dev/null 2>&1 && [ -n "${GOVERN_BUN:-}" ]; then
  _hash_rel() { _gov hash-rel "$ROOT" "$@"; }
else
  # No governor lib and no bun (a fresh clone, CI). Same bytes, one file per call.
  _hash_rel() {
    local f
    for f in "$@"; do
      printf '%s  %s\n' "$(shasum -a 256 < "$ROOT/$f" 2>/dev/null | cut -d' ' -f1)" "$f"
    done
  }
fi

_key_src=$(
  printf '%s\0' "${ARGS[@]}"
  # content of every file the selection names, when it exists
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # REPO-RELATIVE names, never "$ROOT/...": `shasum <path>` prints the path
    # beside the hash, and an absolute path puts the WORKTREE into the key. The
    # same bytes hashed from two checkouts then produced two keys, so the memo
    # was private per worktree for every selection that named a file — `related`
    # and BOTH full-suite lanes — and a plan that closed in a worktree and shipped
    # from main paid ~122s twice. Measured 2026-09-03 (three-cell probe: the
    # path-free pins shared, anything naming a file did not). Same bytes, same
    # key, any checkout. This is NOT a narrowing: nothing leaves the key.
    [ -f "$ROOT/$folder/$f" ] && _hash_rel "$folder/$f"
    [ -f "$ROOT/$f" ] && _hash_rel "$f"
  done <<< "$_sel"
  # The working delta, BY CONTENT. `git status --porcelain` was the first attempt
  # and it is a trap: it names files, so " M src/lib/authority.ts" is the same
  # string whether that file gained one comment or was rewritten. Caught in the
  # act 2026-09-01 -- appending a line to an already-modified file did not move
  # the key, and the run returned a cached PASS for a tree that had changed. A
  # green gate over a changed tree is the exact failure this cache must not have.
  # `git diff HEAD` hashes the CONTENT of every tracked change; untracked files
  # are hashed directly since no diff covers them.
  git -C "$ROOT" diff HEAD 2>/dev/null
  git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null \
    | while IFS= read -r u; do _hash_rel "$u"; done
  git -C "$ROOT" rev-parse HEAD 2>/dev/null
  # Inputs git CANNOT see. `.env`/`.env.local` are gitignored, so neither
  # `git diff HEAD` nor `ls-files --others` (which honours .gitignore) covers
  # them -- yet the suite reads them. Without these lines a pass could be
  # replayed across an environment change. Absent hashes as "ABSENT" so that
  # DELETING one still moves the key.
  for _e in "$folder/.env" "$folder/.env.local" "$folder/.env.test"; do
    if [ -f "$ROOT/$_e" ]; then _hash_rel "$_e"
    else echo "ABSENT $_e"; fi
  done
  # for a substring selection the matched SET can change without any arg changing
  ( cd "$ROOT/$folder" 2>/dev/null && git ls-files '*.test.*' 2>/dev/null | shasum -a 256 )
)
KEY=$(printf '%s' "$_key_src" | shasum -a 256 | cut -d' ' -f1)
# TEST_CACHE_KEY_ONLY=1 prints the key and runs nothing — how a caller (or a
# sharing proof) asks "would this selection hit?" without paying for the run.
if [ "${TEST_CACHE_KEY_ONLY:-0}" = "1" ]; then echo "$KEY"; exit 0; fi
STAMP="$CACHE_DIR/$folder-${KEY}.pass"
STAMP="${STAMP//\//_}"; STAMP="$CACHE_DIR/$(basename "$STAMP")"

# TEST_CACHE_PROBE=1 answers "would this HIT?" and runs nothing: exit 0 on a
# hit, 1 on a miss. It sits AFTER the STAMP lines above on purpose -- the
# probe and the real check must resolve the same path or the probe is a
# second, drifting definition of a hit. KEY_ONLY prints the key; PROBE
# answers the question the caller actually has.
#
# WHY IT EXISTS. verify-fast.sh took a GOVERNOR SLOT and then asked whether
# there was anything to run. Measured 2026-09-09 on a saturated box: 855s
# and 1324s queued for slots whose work was a memo hit costing ~0. A cache
# hit must never wait behind a real gate -- it needs no memory, no forks and
# no slot. Probe first, take the slot only on a MISS.
if [ "${TEST_CACHE_PROBE:-0}" = "1" ]; then
  if [ "${TEST_CACHE_DISABLE:-0}" != "1" ] && [ -f "$STAMP" ]; then
    echo "[test-cached] probe: HIT ${KEY:0:12}"; exit 0
  fi
  echo "[test-cached] probe: MISS ${KEY:0:12}"; exit 1
fi

mkdir -p "$CACHE_DIR" 2>/dev/null
find "$CACHE_DIR" -name '*.pass' -mtime "+${MAX_AGE_DAYS}" -delete 2>/dev/null

if [ "${TEST_CACHE_DISABLE:-0}" != "1" ] && [ -f "$STAMP" ]; then
  echo "[test-cached] cache HIT ${KEY:0:12} — identical inputs already PASSED $(cat "$STAMP" 2>/dev/null)"
  exit 0
fi

# --- run -------------------------------------------------------------------
# __probe__ is the self-test's fake folder: no vitest, deterministic outcome.
if [ "$folder" = "__probe__" ]; then
  case " ${ARGS[*]} " in *--probe-fail*) st=1 ;; *) st=0 ;; esac
else
  # THE SLOT. This script takes no lock, so unlike tsc-cached.sh there is no
  # ordering hazard -- adding a slot here is purely additive.
  #
  # verify-fast.sh already wraps ITS calls to this script in gate-run, and
  # gate-run exports GOVERN_IN_GATE=1, so _gate below collapses to a plain `env`
  # on that path: the outer slot is INHERITED, never doubled (a second slot held
  # by one logical gate is what deadlocks the queue at cap 2).
  #
  # What this closes is the other caller: `bun run test` -> test-lanes.sh -> here
  # reached vitest with no slot at all. Measured 2026-09-07 in one worktree at
  # 256% CPU and ~800MB, with the governor reporting "1 of 2 slots held".
  _gate=( env )
  if [ "${TEST_CACHE_GATE:-1}" = "1" ] && [ "${GOVERN_IN_GATE:-0}" != "1" ] \
     && [ -f "$ROOT/.claude/scripts/gate-run.sh" ]; then
    _gate=( env "GOVERN_GATE_TIMEOUT=${TEST_CACHE_TIMEOUT:-1800}"
            bash "$ROOT/.claude/scripts/gate-run.sh" "test-cache:$folder" -- )
  fi
  if [ "${TEST_CACHE_PTY:-0}" = "1" ]; then
    # The deploy gate's vitest HANGS when stdout is not a TTY -- a fork is spawned
    # and never given work (see .claude/commands/deploy.md "The vitest gate hangs").
    # `script -qeF /dev/null` allocates a pty and flushes. The -e is load-bearing:
    # it propagates the CHILD's exit status. Without it `script` exits 0 over a red
    # suite and this cache would record a PASS for a failing run.
    ( cd "$ROOT/$folder" && "${_gate[@]}" script -qeF /dev/null bunx vitest run "${ARGS[@]}" )
    st=$?
  else
    ( cd "$ROOT/$folder" && "${_gate[@]}" bunx vitest run "${ARGS[@]}" )
    st=$?
  fi
fi

# ONLY a pass is recorded. A red gate must re-run until it is green.
if [ "$st" -eq 0 ]; then
  date -u +%Y-%m-%dT%H:%M:%SZ > "$STAMP" 2>/dev/null
  echo "[test-cached] PASS recorded ${KEY:0:12}"
fi
exit "$st"
