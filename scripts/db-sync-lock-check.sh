#!/usr/bin/env bash
# db-sync-lock-check.sh — the property `sync-from-prod.ts` needs to be safe under
# N concurrent sessions.
#
# WHY THIS EXISTS. `hook:db-sync` (settings.json, SessionStart) fires
# `bun run db:sync` on EVERY session start, and the script writes a SHARED path
# (`/tmp/one-prod-sync/d1-export.sql`). On 2026-09-05, with 7 sessions open, two
# runs were caught mid-flight by lsof holding that one file open for write —
# two write fds, one inode, identical offset — and each would then have dropped
# and re-imported the local `one-owners` tables underneath the other. The bug is
# not the wasted export; it is the corrupted local mirror.
#
#   C1  a lone runner acquires, completes, and RELEASES
#   C2  a second runner SKIPS (exit 0) while a live owner holds the lock
#   C3  a dead owner's lock is reaped — the next runner proceeds
#   C4  the TTL branch reaps too, so the pid branch is not the only one
#   R1  RED-PROOF: with the guard removed, C2 must FAIL. A checker that stays
#       green against a gutted implementation is not a check.
#
# Sandboxed via ONE_SYNC_TMP_DIR — never touches a real /tmp/one-prod-sync.
# Runs with an empty --only scope, so no network call and no local mutation.
#
#   bash .claude/scripts/db-sync-lock-check.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/one.ie/web/scripts/sync-from-prod.ts"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/db-sync-lock-check.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

fails=0
ok()  { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails + 1)); }

# Dummy creds: the script only checks PRESENCE, and an empty --only scope makes
# no API call. Never put real credentials in a checker.
run_sync() { # run_sync <tmpdir> <script> -> stdout+stderr, exit code preserved
  CLOUDFLARE_EMAIL='check@example.invalid' \
  CLOUDFLARE_GLOBAL_API_KEY='not-a-real-key' \
  ONE_SYNC_TMP_DIR="$1" \
  bun "$2" --only= 2>&1
}

echo "── db-sync single-writer lock ──"

# ── C1  lone runner: acquires, completes, releases ───────────────────────────
d="$SANDBOX/c1"; mkdir -p "$d"
out="$(run_sync "$d" "$SCRIPT")"; rc=$?
if [ $rc -eq 0 ] && grep -q 'DONE' <<<"$out"; then
  ok "C1 lone runner completes"
else
  bad "C1 lone runner completes (rc=$rc): $out"
fi
if [ ! -d "$d/.lock" ]; then
  ok "C1 lock released on exit"
else
  bad "C1 lock LEAKED at $d/.lock"
fi

# ── C2  contention: a live owner makes the second runner skip ────────────────
# $$ is this shell — guaranteed alive, and never needs killing.
d="$SANDBOX/c2"; mkdir -p "$d/.lock"; printf '%s' "$$" > "$d/.lock/pid"
out="$(run_sync "$d" "$SCRIPT")"; rc=$?
if [ $rc -eq 0 ] && grep -q 'skipping this run' <<<"$out" && ! grep -q 'DONE' <<<"$out"; then
  ok "C2 second runner skips under a live owner"
else
  bad "C2 second runner did NOT skip (rc=$rc): $out"
fi
if [ -f "$d/.lock/pid" ] && [ "$(cat "$d/.lock/pid")" = "$$" ]; then
  ok "C2 skipping runner did not steal the owner's lock"
else
  bad "C2 owner's lock was clobbered by the skipper"
fi

# ── C3  a dead owner's lock is reaped ────────────────────────────────────────
bash -c 'exit 0' & deadpid=$!; wait $deadpid 2>/dev/null   # pid is now dead
d="$SANDBOX/c3"; mkdir -p "$d/.lock"; printf '%s' "$deadpid" > "$d/.lock/pid"
out="$(run_sync "$d" "$SCRIPT")"; rc=$?
if [ $rc -eq 0 ] && grep -q 'reaping stale lock' <<<"$out" && grep -q 'DONE' <<<"$out"; then
  ok "C3 dead owner's lock reaped, runner proceeds"
else
  bad "C3 dead owner's lock NOT reaped (rc=$rc): $out"
fi

# ── C4  the TTL branch reaps as well (owner alive, lease expired) ────────────
d="$SANDBOX/c4"; mkdir -p "$d/.lock"; printf '%s' "$$" > "$d/.lock/pid"
touch -A -013000 "$d/.lock" 2>/dev/null || touch -d '90 minutes ago' "$d/.lock" 2>/dev/null
out="$(run_sync "$d" "$SCRIPT")"; rc=$?
if grep -q 'reaping stale lock' <<<"$out" && grep -q 'DONE' <<<"$out"; then
  ok "C4 expired lease reaped even though the owner is alive"
else
  bad "C4 TTL branch did not fire — pid liveness is the only reaper: $out"
fi

# ── R1  RED-PROOF: gut the guard, C2 must fail ───────────────────────────────
GUTTED="$SANDBOX/gutted.ts"
sed 's/^if (!acquireLock()) {$/if (false) {/' "$SCRIPT" > "$GUTTED"
if ! grep -q 'if (false) {' "$GUTTED"; then
  bad "R1 could not gut the guard — the anchor moved, this checker is blind"
else
  d="$SANDBOX/r1"; mkdir -p "$d/.lock"; printf '%s' "$$" > "$d/.lock/pid"
  out="$(run_sync "$d" "$GUTTED")"
  if grep -q 'skipping this run' <<<"$out"; then
    bad "R1 gutted build STILL skipped — C2 is not testing the guard"
  else
    ok "R1 red-proof: gutted guard stops skipping, so C2 has teeth"
  fi
fi

echo
if [ $fails -eq 0 ]; then
  echo "ALL GREEN — the lock holds and the checks can go red"
  exit 0
fi
echo "RED — $fails check(s) failed"
exit 1
