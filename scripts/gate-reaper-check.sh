#!/usr/bin/env bash
# gate-reaper-check.sh — what gate-reaper.sh reaps, and what it must never touch.
#
# manifest: portable
#
# WHY THIS EXISTS (measured 2026-09-05). Five `workerd` processes left behind by
# dead `astro dev` sessions sat at ppid=1 for 33-63 minutes holding ~196MB, while
# BOTH gate-reaper and machine-check printed "orphans: none". The reaper keys on
# a gate SHAPE, and `workerd serve` was not one of the shapes, so nothing in the
# harness could see them. They had to be found and killed by hand.
#
# The reaper's danger is symmetric, and this checker holds both ends:
#   C1  an abandoned workerd under node_modules IS reaped
#   C2  a LIVE workerd (parent alive) is NEVER reaped
#   C3  a freshly reparented workerd is spared — the age floor still applies
#   C4  a long-lived ppid=1 daemon that merely NAMES a gate word is spared
#   C5  the pre-existing gate shapes still reap — no regression
#   C6  a workerd outside node_modules is spared — not ours to kill
#   R1  RED-PROOF: drop the workerd arm and C1 must FAIL
#
# Drives the REAL script with --once --dry-run against a STUBBED `ps`, so it
# never reads the live process table and never signals anything.
#
#   bash .claude/scripts/gate-reaper-check.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAPER="$ROOT/.claude/scripts/gate-reaper.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/gate-reaper-check.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

fails=0
ok()  { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails + 1)); }

WD='node_modules/@cloudflare/workerd-darwin-arm64/bin/workerd serve --binary --experimental'

# The fixture process table. Columns match `ps -Ao pid=,ppid=,etime=,command=`.
cat > "$SANDBOX/table" <<EOF
1001 1 45:00 /repo/someapp/web/$WD
1002 29457 45:00 /repo/someapp/web/$WD
1003 1 01:00 /repo/someapp/web/$WD
1004 1 45:00 /repo/bin/cc-connect.sh daemon run verify
1005 1 45:00 /usr/local/bin/workerd serve --binary --experimental
1006 1 45:00 bash /repo/.claude/scripts/gate-run.sh verify -- bun run verify
EOF

# Stub `ps`: serve the fixture for the sweep's -Ao read, and a pgid for lookups.
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/ps" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do case "\$a" in pgid=) echo "  9999"; exit 0 ;; esac; done
cat "$SANDBOX/table"
EOF
chmod +x "$SANDBOX/bin/ps"

run_reaper() { PATH="$SANDBOX/bin:$PATH" bash "$1" --once --dry-run 2>&1; }

echo "── gate-reaper: reaps the abandoned, spares the live ──"
out="$(run_reaper "$REAPER")"

reaped() { grep -q "WOULD reap pid=$1 " <<<"$out"; }

if reaped 1001; then ok "C1 abandoned workerd under node_modules is reaped"
else bad "C1 abandoned workerd NOT reaped — the orphan shape is still invisible: $out"; fi

if ! reaped 1002; then ok "C2 live workerd (parent alive) spared"
else bad "C2 LIVE workerd would be reaped — this kills a running dev server"; fi

if ! reaped 1003; then ok "C3 freshly reparented workerd spared by the age floor"
else bad "C3 age floor not applied to workerd"; fi

if ! reaped 1004; then ok "C4 ppid=1 daemon naming a gate word is spared"
else bad "C4 cc-connect daemon would be reaped — exclusions broken"; fi

if reaped 1006; then ok "C5 pre-existing gate-run.sh shape still reaps"
else bad "C5 REGRESSION — gate-run.sh shape no longer reaped: $out"; fi

if ! reaped 1005; then ok "C6 workerd outside node_modules spared"
else bad "C6 would reap a workerd this tree did not spawn"; fi

# ── R1  RED-PROOF: without the workerd arm, C1 must fail ─────────────────────
GUTTED="$SANDBOX/gutted.sh"
grep -v 'node_modules\*workerd" serve"\*) ;;' "$REAPER" > "$GUTTED"
if [ "$(wc -l < "$GUTTED")" -eq "$(wc -l < "$REAPER")" ]; then
  bad "R1 could not remove the workerd arm — anchor moved, this checker is blind"
else
  gout="$(run_reaper "$GUTTED")"
  if grep -q "WOULD reap pid=1001 " <<<"$gout"; then
    bad "R1 gutted reaper STILL reaped 1001 — C1 is not testing the new arm"
  else
    ok "R1 red-proof: without the arm 1001 is missed, so C1 has teeth"
  fi
fi

echo
if [ $fails -eq 0 ]; then echo "ALL GREEN — the reaper sees orphaned workerd and still spares live work"; exit 0; fi
echo "RED — $fails check(s) failed"; exit 1
