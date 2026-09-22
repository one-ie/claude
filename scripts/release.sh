#!/usr/bin/env bash
# release.sh — a deploy worktree of beautifully tested code, shipped without
# re-running the suite.
#
# manifest: monorepo-only
#
# THE ASK. "We should have a deploy worktree with beautifully tested code that we
# can deploy without testing." The second half is the part that needs care: not
# *without testing* — without RE-RUNNING the tests, because the tree already
# carries a green full-suite receipt and the receipt is bound to the tree.
#
# WHAT THE RECEIPT IS. test-cached.sh memoises a full-suite PASS under a key over
# the exact inputs: the vitest argv + the content of every selected test file +
# `git diff HEAD` BY CONTENT + untracked contents + HEAD + the gitignored .env
# files + the test-file set. Only passes are ever recorded. So a stamp existing
# for a tree is a proof that this exact tree ran the whole suite green, and it is
# the same object deploy.sh's own vitest gate looks for. release.sh does not
# invent a second notion of "tested" — it reads deploy's.
#
#   promote [<sha>]  refuse unless <sha>'s tree carries that receipt; then
#                    fast-forward `release` to it and materialise .release/
#   ship             run ./deploy FROM .release/, where the suite gate is a
#                    memo HIT rather than a 400-second re-run
#   --self-test      the red proof (three refusals, sandboxed)
#
# WHY .release/ AND NOT .do-worktrees/. do-auto.sh's exit-time --gc sweep deletes
# worktrees under .do-worktrees/ (project_do_auto_gc_collateral_bug). A release
# tree that a neighbouring /do cycle can garbage-collect mid-deploy is not a
# release tree. .release/ is gitignored and swept by nothing.
#
# WHY THE KEY IS COMPUTED BY RUNNING THE REAL MACHINERY. The full suite runs as
# TWO lanes (test-lanes.sh) with different argv, so it has TWO keys — and a third
# shape if the `real TypeDB` marker ever matches nothing (test-lanes falls back to
# a single run). Spelling those lanes out here would be a second definition that
# drifts silently, which is the exact bug test-full.sh was created to kill. So
# promote runs test-full.sh with TEST_CACHE_KEY_ONLY=1: every lane's test-cached.sh
# prints its key and exits without running anything. Whatever the lanes are, the
# keys are theirs.
#
# THE DIRTY-MAIN COROLLARY, measured 2026-09-05. The key hashes `git diff HEAD`
# by content, and main carried 9 uncommitted paths. A receipt minted on main is
# therefore a receipt for a tree that will never ship. The mint has to happen on
# a CLEAN tree at the sha — which is what .release/ is. This is also the honest
# security property: `./deploy --allow-dirty` from main ships uncommitted code;
# `ship` structurally cannot.
#
# Exit codes are distinct and named, because "it refused" is not a finding:
#   0 ok · 2 usage · 3 no receipt · 4 tsc red · 5 not a fast-forward
#   6 dirty release tree · 7 tsc could not run (lock/timeout) · 8 deploy failed
#   9 no receipt key could be computed
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WT="${RELEASE_WORKTREE:-$ROOT/.release}"
BRANCH="${RELEASE_BRANCH:-release}"
CACHE_DIR="${TEST_CACHE_DIR:-${TMPDIR:-/tmp}/one-test-cache}"
# Bounded, unlike tsc-cached's 900s default. deploy.sh deliberately does NOT route
# its typechecks through tsc-cached because a /do cycle holding the per-folder
# gate_lock would turn a ship gate red for lock contention rather than for code.
# promote reads the cache but must never inherit that stall: 120s, then refuse
# with its own exit code (7), which says "unrun", never "green".
TSC_WAIT="${RELEASE_TSC_WAIT:-120}"
TSC_SERVICES=(one.ie/web api sync channels pay/backend)

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ok   %s\n' "$*"; }
bad()  { printf '  RED  %s\n' "$*" >&2; }

# Everything gitignored that a checkout does not get but the gates read. The
# node_modules half is do-auto.sh's _link_deps set; the .env half is WIDER than
# _link_deps on purpose. test-cached.sh's key hashes one.ie/web/.env, .env.local
# AND .env.test, printing "ABSENT" for a missing one — so a worktree that links
# .env but not .env.local computes a DIFFERENT key from the main tree for the same
# commit, and every receipt misses for a reason nothing prints. Measured
# 2026-09-05: one.ie/web/.env.local exists on this box and _link_deps does not
# link it.
_link_deps() {
  local wt="$1" nm
  for nm in node_modules one.ie/web/node_modules packages/node_modules \
            packages/sdk/dist packages/sdk/node_modules \
            pay/backend/node_modules channels/node_modules \
            api/node_modules sync/node_modules \
            one.ie/web/.env one.ie/web/.env.local one.ie/web/.env.test \
            .env.local pay/backend/.env channels/.env; do
    if [ -e "$ROOT/$nm" ] && [ ! -e "$wt/$nm" ]; then
      mkdir -p "$wt/$(dirname "$nm")"
      ln -s "$ROOT/$nm" "$wt/$nm" 2>/dev/null && say "  linked $nm"
    fi
  done
}

# The receipt keys for the tree standing in $1. Prints one 64-hex key per lane.
# TEST_CACHE_KEY_ONLY=1 makes every test-cached.sh in the fan-out print its key
# and exit 0 without running vitest, so this costs ~1s and cannot start a suite.
#
# Each line is "<lane> <key>". The lane is read off test-lanes.sh's own
# `───── <lane> lane (rc=N) ─────` header that precedes the key, so a new lane
# names itself; a key with no header (the single-run fallback) is lane `suite`.
_receipt_keys() {
  ( cd "$1" && TEST_CACHE_KEY_ONLY=1 bash .claude/scripts/test-full.sh 2>/dev/null ) \
    | awk '/ lane \(rc=/ { for (i = 1; i <= NF; i++) if ($i == "lane") lane = $(i-1); next }
           /^[0-9a-f]{64}$/ { print (lane == "" ? "suite" : lane), $0 }'
}

# The stamp for a key, if one exists. test-cached.sh mangles the whole stamp path
# into the filename, so match on the key rather than reproducing that mangling —
# the key is a sha256 and is unique on its own.
_stamp_for() {
  local k="$1" f
  for f in "$CACHE_DIR"/*"$k".pass; do [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }; done
  return 1
}

# ── promote ─────────────────────────────────────────────────────────────────
cmd_promote() {
  local sha="${1:-}"
  sha="$(git -C "$ROOT" rev-parse --verify "${sha:-HEAD}^{commit}" 2>/dev/null)" || {
    bad "not a commit: ${1:-HEAD}"; return 2; }

  say "release: promote ${sha:0:9}"

  # 1. fast-forward only. A release branch that can move backwards is not a record.
  local prev="" dist="(first release)"
  if prev="$(git -C "$ROOT" rev-parse --verify "$BRANCH" 2>/dev/null)"; then
    if [ "$prev" != "$sha" ] && ! git -C "$ROOT" merge-base --is-ancestor "$prev" "$sha"; then
      bad "$sha is not a fast-forward of $BRANCH (${prev:0:9}) — refusing to rewind the release record"
      return 5
    fi
    dist="$(git -C "$ROOT" rev-list --count "$prev..$sha") commit(s) since ${prev:0:9}"
  fi

  # 2. materialise the tree. Idempotent: create, or move an existing worktree.
  #
  # THE DIRTY CHECK COMES FIRST, and the ordering is the whole point. The obvious
  # shape — reset --hard, then check clean — can never report a dirty tree,
  # because the reset already destroyed the evidence, and the operator's work
  # with it. Silently discarding what is standing in the tree is not a refusal;
  # it is data loss that reads as success.
  if [ -d "$WT/.git" ] || [ -f "$WT/.git" ]; then
    local dirty; dirty="$(git -C "$WT" status --porcelain)"
    if [ -n "$dirty" ]; then
      bad "release tree is dirty — the receipt would not describe what ships:"
      printf '%s\n' "$dirty" | sed 's/^/       /' >&2
      return 6
    fi
    # -B moves the branch and HEAD together. A plain `git branch -f` is REFUSED
    # by git for a branch checked out in a worktree ("cannot force update the
    # branch ... checked out at"), so the move is made from inside the worktree.
    git -C "$WT" checkout -q -B "$BRANCH" "$sha" \
      || { bad "could not move $WT to $sha"; return 5; }
  else
    git -C "$ROOT" worktree add -B "$BRANCH" "$WT" "$sha" >/dev/null 2>&1 \
      || { bad "could not add worktree $WT on $BRANCH"; return 5; }
  fi
  _link_deps "$WT"

  # 3. after the move it must still be clean — a checkout that left something
  # behind is not a tree any receipt describes.
  local dirty2; dirty2="$(git -C "$WT" status --porcelain)"
  if [ -n "$dirty2" ]; then
    bad "release tree is dirty after checkout:"
    printf '%s\n' "$dirty2" | sed 's/^/       /' >&2
    return 6
  fi
  ok "release tree clean at $(git -C "$WT" rev-parse --short HEAD)"

  # 4. the receipt.
  local keys; keys="$(_receipt_keys "$WT")"
  if [ -z "$keys" ]; then
    bad "no receipt key could be computed — test-full.sh printed no lane key"
    return 9
  fi
  # THE TYPEDB LANE DOES NOT GATE PRODUCTION (operator ruling 2026-09-13). The
  # request path reads the edge snapshot, never TypeDB (CLAUDE.md § The brain and
  # the edge), and the lane's reds were the shared cluster timing out, not code:
  # three promotes in a row held a green pool lane behind `upstream 500: aborted
  # due to timeout`. deploy.sh already runs it non-blocking
  # (TYPEDB_LANE_NONBLOCKING=1); promote now weighs it the same way, so the two
  # doors can no longer disagree. The lane is still READ and printed — a missing
  # stamp is a named warning, never silence. RELEASE_TYPEDB_BLOCKING=1 restores
  # the hard gate.
  #
  # …AND THAT FLAG IS NOW A ONE-PASS REFUSAL. Say it here rather than leave it to
  # be discovered: promote's only mint is `deploy.sh --gates-only`, and since
  # 2026-09-21 that run does not WAIT for the typedb lane — when the heavy gates
  # can overlap, the lane is its own gate whose rc the deploy never collects (it
  # records `unrun`, never a pass). The deploy therefore exits BEFORE the lane can
  # stamp, so a first promote under RELEASE_TYPEDB_BLOCKING=1 finds no typedb
  # stamp and refuses — it can reach `refuse` and nothing else on that pass. The
  # orphaned lane does finish and DOES mint its stamp, so a SECOND promote on the
  # same tree finds it and passes. A guard that can reach one verdict is not a
  # guard: under that flag, either mint twice, or mint with
  # DEPLOY_HEAVY_PARALLEL unset on a serialised box, where the lane still runs
  # inside the vitest gate and stamps before the deploy exits. The DEFAULT path is
  # unaffected and is measured so (--self-test: "an unstamped typedb lane does not
  # gate production (exit 0)").
  local n_keys=0 missing=0 stamps=() lane k
  while read -r lane k; do
    [ -n "$k" ] || continue
    n_keys=$((n_keys+1))
    local s
    if s="$(_stamp_for "$k")"; then
      stamps+=("$s")
      ok "receipt ${k:0:12} ($lane lane) — full suite PASSED $(cat "$s" 2>/dev/null)"
    elif [ "$lane" = "typedb" ] && [ "${RELEASE_TYPEDB_BLOCKING:-0}" != "1" ]; then
      say "  warn receipt ${k:0:12} (typedb lane) — no green stamp; non-blocking for production"
    else
      bad "receipt ${k:0:12} ($lane lane) — NO green full-suite stamp for this tree"
      missing=$((missing+1))
    fi
  done <<< "$keys"
  if (( missing )); then
    say ""
    say "  $missing of $n_keys lane(s) have no receipt. Mint one on this exact tree:"
    say "    cd $WT && DEPLOY_YES=1 bash .claude/scripts/deploy.sh --gates-only"
    say "  (a receipt minted on a DIRTY main describes a tree that never ships —"
    say "   the mint has to happen here, on the clean tree at $(git -C "$WT" rev-parse --short HEAD))"
    return 3
  fi

  # 5. tsc, for the same tree. The suite does not typecheck; deploy does it as a
  # separate gate, and a promoted tree should already know the answer.
  if [ "${RELEASE_SKIP_TSC:-0}" != "1" ]; then
    local svc out rc
    for svc in "${TSC_SERVICES[@]}"; do
      out="$( cd "$WT" && TSC_CACHE_WAIT="$TSC_WAIT" bash .claude/scripts/tsc-cached.sh "$svc" 2>/dev/null )"
      rc=$?
      if (( rc != 0 )); then
        bad "tsc $svc — could NOT run (lock or timeout); an unrun check is not a pass"
        return 7
      fi
      if [ "$out" != "0" ]; then bad "tsc $svc — $out error(s)"; return 4; fi
      ok "tsc $svc — 0 errors"
    done
  fi

  say ""
  say "  promoted:  $sha"
  say "  branch:    $BRANCH -> $(git -C "$ROOT" rev-parse --short "$BRANCH")"
  say "  worktree:  $WT"
  say "  distance:  $dist"
  local s; for s in "${stamps[@]}"; do say "  receipt:   $s"; done
  say ""
  say "  ship it:   bash .claude/scripts/release.sh ship"
  return 0
}

# ── ship ────────────────────────────────────────────────────────────────────
cmd_ship() {
  [ -d "$WT" ] || { bad "no release worktree at $WT — run promote first"; return 2; }
  local dirty; dirty="$(git -C "$WT" status --porcelain)"
  [ -z "$dirty" ] || { bad "release tree is dirty — refusing to ship an unproven tree"; return 6; }
  local sha; sha="$(git -C "$WT" rev-parse HEAD)"
  say "release: ship ${sha:0:9} from $WT"

  # Seconds, ships nothing, and catches a credential ladder that cannot resolve
  # from a worktree BEFORE the seven-minute pipeline dies at the same place.
  say ""; say "── credential pre-flight ──"
  ( cd "$WT" && bash .claude/scripts/deploy.sh --check-creds ) || {
    bad "credential ladder did not verify from $WT"; return 8; }

  say ""; say "── deploy ──"
  local t0=$SECONDS
  # NO --skip-tests. The whole point is that the suite gate hits the memo and
  # reports "REUSED" — forcing the skip would throw away the proof and ship on a
  # promise instead of a receipt.
  #
  # --changed BY DEFAULT. A service with no commit under its svc_paths since its
  # last clean deploy has nothing to ship; deploy.sh's per-service markers live
  # under $WT/.deploy-logs, so they describe THIS tree's ships, never main's.
  # svc_paths already folds packages/ into astro and channels (an SDK-only
  # commit re-ships both), which is what makes the skip safe. First ship from a
  # fresh .release/ has no markers and ships all five. RELEASE_ALL=1 forces it.
  local changed=(--changed); [ "${RELEASE_ALL:-0}" = "1" ] && changed=(--all)
  ( cd "$WT" && DEPLOY_YES=1 bash .claude/scripts/deploy.sh "${changed[@]}" )
  local rc=$?
  say ""
  say "  ship wall-clock: $((SECONDS - t0))s"
  (( rc == 0 )) || { bad "deploy exited $rc"; return 8; }
  return 0
}

# ── --self-test — the red proof ─────────────────────────────────────────────
# Three refusals, each asserted on its OWN exit code: three refusals that all
# exit 1 would pass a checker that only asks "did it refuse?".
#
# Sandboxed on every axis that could touch the real thing: its own TEST_CACHE_DIR
# (so a planted stamp can never be replayed by a future deploy), its own worktree
# path, its own throwaway branch. The last assertion is that the REAL cache gained
# zero files — a fake receipt leaking into it is the single worst outcome this
# script could have.
_self_test() {
  local fails=0
  local sbcache sbwt sbbranch base
  sbcache="$(mktemp -d)"; sbwt="$(mktemp -d)/rel"; sbbranch="release-selftest-$$"
  base="$(git -C "$ROOT" rev-parse --verify HEAD)"
  local real_before real_after
  real_before=$(ls "${TMPDIR:-/tmp}/one-test-cache" 2>/dev/null | wc -l | tr -d ' ')

  _run() { TEST_CACHE_DIR="$sbcache" RELEASE_WORKTREE="$sbwt" RELEASE_BRANCH="$sbbranch" \
             RELEASE_SKIP_TSC=1 bash "${BASH_SOURCE[0]}" promote "$@" >/dev/null 2>&1; }
  _assert() { # <expected-rc> <actual-rc> <label>
    if [ "$1" = "$2" ]; then echo "  ok   $3 (exit $2)"
    else echo "  FAIL $3 — expected exit $1, got $2"; fails=$((fails+1)); fi
  }

  # 1. a tree with no receipt is REFUSED (3)
  _run "$base"; _assert 3 $? "no receipt refuses"

  # 2a. the typedb lane does not gate production: stamp every OTHER lane and the
  #     promote succeeds; RELEASE_TYPEDB_BLOCKING=1 restores the refusal. Red half
  #     first — a non-typedb lane left unstamped must still refuse.
  local lane k
  while read -r lane k; do
    [ -n "$k" ] && [ "$lane" = "typedb" ] && date -u +%Y-%m-%dT%H:%M:%SZ > "$sbcache/selftest-$k.pass"
  done < <(_receipt_keys "$sbwt")
  _run "$base"; _assert 3 $? "a green typedb lane cannot carry an unstamped pool lane"
  rm -f "$sbcache"/selftest-*.pass
  while read -r lane k; do
    [ -n "$k" ] && [ "$lane" != "typedb" ] && date -u +%Y-%m-%dT%H:%M:%SZ > "$sbcache/selftest-$k.pass"
  done < <(_receipt_keys "$sbwt")
  if _receipt_keys "$sbwt" | grep -q '^typedb '; then
    RELEASE_TYPEDB_BLOCKING=1 _run "$base"; _assert 3 $? "RELEASE_TYPEDB_BLOCKING=1 refuses an unstamped typedb lane"
    _run "$base"; _assert 0 $? "an unstamped typedb lane does not gate production"
  else
    echo "  FAIL no typedb lane key found — the non-blocking branch went unproven"; fails=$((fails+1))
  fi

  # 2. plant a PASS stamp for every lane key of that tree — promotion succeeds
  while IFS= read -r k; do
    [ -n "$k" ] && date -u +%Y-%m-%dT%H:%M:%SZ > "$sbcache/selftest-$k.pass"
  done < <(TEST_CACHE_KEY_ONLY=1 bash -c "cd '$sbwt' && bash .claude/scripts/test-full.sh" 2>/dev/null \
             | grep -Eo '^[0-9a-f]{64}$')
  _run "$base"; _assert 0 $? "a planted receipt promotes"

  # 3. the receipt is bound to the TREE. Append a byte (never `touch` — the key is
  #    content, never mtime, so a touch would move nothing and look like a bug),
  #    commit it so the tree is clean again, and the same stamps must no longer
  #    answer for the new tree.
  local probe="$sbwt/text/dictionary.md"
  [ -f "$probe" ] || probe="$(git -C "$sbwt" ls-files | head -1 | sed "s|^|$sbwt/|")"
  printf '\n<!-- release.sh self-test -->\n' >> "$probe"
  git -C "$sbwt" add -- "${probe#$sbwt/}" >/dev/null 2>&1
  git -C "$sbwt" -c user.email=selftest@one.ie -c user.name=selftest \
      commit -q -m "release.sh self-test: move the tree" >/dev/null 2>&1
  local moved; moved="$(git -C "$sbwt" rev-parse HEAD)"
  _run "$moved"; _assert 3 $? "a moved tree loses the receipt (key follows content)"

  # 4. and a DIRTY tree is refused before any key is computed
  printf 'dirty\n' >> "$probe"
  _run "$moved"; _assert 6 $? "a dirty release tree refuses"

  # 5. nothing leaked into the real cache
  real_after=$(ls "${TMPDIR:-/tmp}/one-test-cache" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$real_before" = "$real_after" ]; then ok "no stamp leaked into the real cache ($real_after files)"
  else echo "  FAIL self-test wrote to the REAL cache ($real_before -> $real_after)"; fails=$((fails+1)); fi

  git -C "$ROOT" worktree remove --force "$sbwt" >/dev/null 2>&1
  git -C "$ROOT" branch -D "$sbbranch" >/dev/null 2>&1
  rm -rf "$sbcache"
  [ "$fails" -eq 0 ] && { echo "release: self-test PASS"; return 0; }
  echo "release: self-test FAILED ($fails)"; return 1
}

case "${1:-}" in
  promote)     shift; cmd_promote "${1:-}"; exit $? ;;
  ship)        cmd_ship; exit $? ;;
  --self-test) _self_test; exit $? ;;
  -h|--help|"") sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
  *) echo "release.sh: unknown verb '${1}' (try --help)" >&2; exit 2 ;;
esac
