#!/usr/bin/env bash
# govern.sh — machine-wide concurrency governor for heavy build gates.
#
# WHY: N concurrent Claude Code sessions each run `bun run verify`
# (tsc --noEmit + vitest over 875 files). Nothing bounded them, so 6 tsc and
# 3 vitest pools ran at once on a 10-core/24GB box -> load 57, swap full,
# ~26 MB/s of swapins. Each gate then took 18 min instead of 2, so sessions
# timed out and spawned MORE. This library breaks that cycle.
#
# macOS has NO flock(1) and NO timeout(1) — both are GNU coreutils. Every
# primitive is built from mkdir(2) atomicity instead.
#
# ─────────────────────────────────────────────────────────────────────────────
# THIS FILE IS NOW A SHIM. The mechanics live in lib/govern.ts (Bun).
#
# § GATES item 5 of text/factory-do.md: the DESIGN was proven — slots, bound,
# claims, the two memo keys, four-state gates. The RUNTIME was the recurring
# defect. bash 3.2 on macOS has no flock, no timeout, no BASHPID; `set -m`
# needs job control; a watchdog subshell cannot own the `sleep` it forks (21
# orphaned `sleep 1800` on the box at once, 2026-09-04); and the
# `find | sort -z | xargs` pipeline plus zsh-vs-bash word splitting produced
# four separate measured bugs in one day. Every one of those lives in a
# MECHANISM, not in a decision. The mechanisms moved to govern.ts; the
# decisions did not change.
#
# The FUNCTION NAMES, ARGUMENTS and EXIT CODES below are unchanged, because
# ~65 callers source this file (gate-run.sh, do-fleet.sh, tsc-cached.sh,
# do-reconcile.sh, machine-check.sh, fleet-status.sh, do-commit.sh,
# factory-width.sh, gate-reaper.sh, do-preflight.sh, hooks/load-guard.sh,
# hooks/session-start.sh, and the six governor proofs). None of them changed.
#
# WHAT DELIBERATELY STAYS IN BASH — the stub seams:
#   _gv_alive                                 (kill -0)
#   _gv_vm_stat / _gv_swapusage / _gv_memsize (vm_stat, sysctl)
# Three of the six governor proofs override these AS BASH FUNCTIONS to drive a
# synthetic machine or a gutted reaper (govern-mem-check.sh's whole fixture
# table; govern-claims-check.sh's R1/R2 red proof). They are one syscall and one
# exec each — none of the runtime defects above touches them — so leaving them
# here costs nothing and is what keeps those red proofs honest. The shim feeds
# their output to govern.ts: vm_stat text on stdin, and, for the claim reads, an
# explicit alive-set computed through _gv_alive.
#
# THE OWNER PID is the CALLING SHELL ($$), never the short-lived bun process: a
# lock whose owner exits the instant it is taken is reaped by the next
# contender, which would silently invert governor-doors-check.sh's re-entrancy
# RED half.
#
# Source it, don't exec it:  . "$(dirname "$0")/lib/govern.sh"

GOVERN_DIR="${GOVERN_DIR:-${TMPDIR:-/tmp}/one-govern}"
export GOVERN_DIR
mkdir -p "$GOVERN_DIR" 2>/dev/null || true

# Heavy gates allowed to run at once, machine-wide, across all sessions and
# worktrees. 10 cores: 2 gates leaves headroom for editors + dev servers.
GOVERN_MAX_GATES="${GOVERN_MAX_GATES:-2}"
export GOVERN_MAX_GATES

# ── locating the port ────────────────────────────────────────────────────────
# BASH_SOURCE is unset under zsh, which this lib is sourced into. $0 is the
# fallback there. GOVERN_TS overrides both.
if [ -n "${BASH_SOURCE:-}" ]; then
  _GOVERN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
else
  _GOVERN_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
fi
GOVERN_TS="${GOVERN_TS:-$_GOVERN_LIB_DIR/govern.ts}"

# Resolve bun ONCE. A hook fired by Claude Code does not necessarily inherit a
# login PATH, and the one memory arm that actually BLOCKS (hooks/load-guard.sh)
# fails OPEN when the probe cannot answer — so an unresolvable bun would
# silently stop a guard from guarding. No absolute user path is hardcoded: this
# file is classified `portable` and factory-repo.sh --check-portability greps it
# for monorepo paths.
if [ -z "${GOVERN_BUN:-}" ]; then
  GOVERN_BUN="$(command -v bun 2>/dev/null || true)"
  if [ -z "$GOVERN_BUN" ]; then
    for _c in "${BUN_INSTALL:-$HOME/.bun}/bin/bun" \
              "$HOME/.bun/bin/bun" \
              "$HOME/.local/share/mise/shims/bun" \
              "$HOME/.local/share/mise/installs/bun/latest/bin/bun" \
              /opt/homebrew/bin/bun /usr/local/bin/bun; do
      [ -x "$_c" ] && { GOVERN_BUN="$_c"; break; }
    done
  fi
  [ -n "$GOVERN_BUN" ] || echo "[govern] WARNING: bun not found — the governor cannot run (set GOVERN_BUN)" >&2
fi

# _gov <subcommand> … — the one door to the port.
_gov() { "$GOVERN_BUN" "$GOVERN_TS" "$@"; }

_gv_log() { [ -n "${GOVERN_DEBUG:-}" ] && echo "[govern] $*" >&2; return 0; }

# _gv_alive <pid> — is that pid still running?
# STUB SEAM: govern-claims-check.sh R1/R2 overrides this to prove the claim
# reaper is what the evaporation checks are testing.
_gv_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }
_GV_ALIVE_CANON="$(declare -f _gv_alive 2>/dev/null || true)"

# ── locks · slots ────────────────────────────────────────────────────────────
# mkdir(2) is the arbiter; the owner recorded is THIS shell.

# gate_lock <name> [wait_secs] — take a named singleton lock.
#   exit 0 = acquired (caller MUST call gate_unlock)
#   exit 1 = someone else holds it and still does after wait_secs
gate_lock() {
  local name="$1"; local wait_s="${2:-0}"
  if GOVERN_OWNER_PID=$$ _gov lock "$name" "$wait_s"; then
    GOVERN_HELD="${GOVERN_HELD:-} $name"
    return 0
  fi
  return 1
}

gate_unlock() {
  GOVERN_OWNER_PID=$$ _gov unlock "$1" >/dev/null 2>&1
  return 0
}

# gate_slot [wait_secs] — take one of the effective slots. This is the cap that
# makes "many Claude sessions" safe: session 3+ queues instead of piling more
# tsc onto a thrashing box. The effective cap is min(GOVERN_MAX_GATES,
# gate_headroom) — a static config must never authorise more than memory can
# fund (measured 2026-08-31: settings said 4, headroom said 2, and 4 won —
# load 82, gates taking 19:34 instead of ~2 min).
gate_slot() {
  local wait_s="${1:-900}" _s
  _s="$(GOVERN_OWNER_PID=$$ _gov slot "$wait_s")" || return 1
  [ -n "$_s" ] || return 1
  GOVERN_SLOT="$_s"
  GOVERN_HELD="${GOVERN_HELD:-} $_s"
  return 0
}

gate_slot_release() { [ -n "${GOVERN_SLOT:-}" ] && gate_unlock "$GOVERN_SLOT"; GOVERN_SLOT=""; return 0; }

# gate_release_all — drop every lock this shell holds. Wire to a trap so a
# killed/timed-out gate never leaves a lock behind.
gate_release_all() {
  local n
  for n in ${GOVERN_HELD:-}; do gate_unlock "$n"; done
  gate_slot_release
  return 0
}

# run_bounded <secs> <cmd...> — run cmd with a hard wall-clock cap, killing the
# whole PROCESS GROUP on timeout. Replaces the missing timeout(1).
#
# The process group is the point: `bun run verify` spawns bash -> bun -> node
# -> N vitest forks. Killing the shell alone reparents all of them to launchd,
# which is exactly how this repo leaked orphaned verify trees.
#
# The bash watchdog this replaces failed twice, both measured: it inherited the
# caller's stdout (then stderr), so `$(run_bounded …)` and `… 2>&1 | tail` hung
# for the FULL timeout after the command had answered; and `kill $watch_pid`
# reaped the subshell but not the `sleep` it forked (21 orphaned `sleep 1800`,
# ppid 1, on the box at once). govern.ts uses an in-process timer — it forks
# nothing and holds no fd — so neither can recur.
run_bounded() { _gov run-bounded "$@"; }

# ─────────────────────────────────────────────────────────────────────────────
# MEMORY PROBE — what is actually available, not what feels available.
#
# THE DEFECT THIS REPLACES (measured 2026-09-03, three independent samples):
# every memory decision in this harness read `memory_pressure`'s "System-wide
# memory free percentage" and multiplied it by hw.memsize. That figure is a
# PRESSURE signal: macOS counts reclaimable memory — file cache, purgeable, and
# pages it has already compressed — as "free". Same box, same second:
#
#     memory_pressure "free percentage"    74%      -> 24 * 74/100 = 17 GB
#     vm_stat Pages free                   21032    -> 0.32 GB (1.3% of 24)
#     vm.swapusage                         9400 M of 10240 M in use
#     old gate_headroom                    7        ("room for 7 more cycles")
#
# The honest quantities are in vm_stat: free + purgeable + min(file-backed,
# inactive). NO SWAP TERM, deliberately — swap in use is a scar, not a signal:
# macOS does not release swap files promptly, so a box that thrashed an hour ago
# still reads ~9 GB used, and charging for that would serialise an idle machine.
#
# The arithmetic is in govern.ts; the three wrappers below stay here because
# govern-mem-check.sh overrides them to feed the probe a synthetic machine.
_gv_vm_stat()   { vm_stat 2>/dev/null; }
_gv_swapusage() { sysctl -n vm.swapusage 2>/dev/null; }
_gv_memsize()   { sysctl -n hw.memsize 2>/dev/null; }

_gv_num() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) printf '%s' "$1" ;; esac; }

# gate_mem_avail_mb — available RAM in MB on stdout. Returns non-zero and prints
# NOTHING when any field is unreadable: a broken sensor must never silently
# serialise the fleet.
gate_mem_avail_mb() { _gv_vm_stat | _gov mem-avail-mb; }

# gate_price_mb — what ONE gate slot actually costs in RAM, derived from the
# LIVE fork count rather than a stale constant (vitest maxWorkers went 4 -> 8 and
# test-lanes.sh runs TWO drivers in one slot, so the same gate had two different
# prices depending on who launched it — that drift IS the defect). Constants
# measured 2026-09-03 over 125 fork / 65 driver samples. All overridable; an
# explicit GOVERN_GB_PER_CYCLE is still the operator's override and wins.
gate_price_mb() { _gov price-mb; }

# gate_pressure — 0 if the machine has headroom, 1 if it is already thrashing.
# Unreadable sensor -> 0: never block on a broken probe.
gate_pressure() {
  local _ms
  _ms="$(_gv_memsize)" || _ms=""
  _gv_vm_stat | GOVERN_MEMSIZE="$_ms" _gov pressure
}

# gate_headroom — how many concurrent heavy CYCLES this box can afford right
# now. >= 1 always (do-fleet.sh clamps to this with no floor of its own, so a 0
# would launch nothing at all); 99 when memory cannot be read.
gate_headroom() { _gv_vm_stat | _gov headroom; }

# gate_mem_report — one legible line of the honest numbers, for the sites a
# HUMAN reads (machine-check, fleet-status, do-preflight). Never on a hot path.
# Emits: avail_mb=<n> total_mb=<n> avail_pct=<n> swap_used_mb=<n> price_mb=<n> slots=<n>
gate_mem_report() {
  local _ms _sw
  _ms="$(_gv_memsize 2>/dev/null)" || _ms=""
  _sw="$(_gv_swapusage 2>/dev/null)" || _sw=""
  _gv_vm_stat | GOVERN_MEMSIZE="$_ms" GOVERN_SWAPUSAGE="$_sw" _gov mem-report
}

# tsc_tree_fingerprint <folder> [<extra-dir>...] — ONE hash of everything tsc
# READS for <folder>, keyed BY CONTENT, never by mtime. Run from the repo root.
#
# Two checkouts of one commit have identical bytes and different mtimes, so the
# old `stat -f '%m %N'` key made N worktrees each pay a full tsc and write their
# own stamp (28 unshared stamps, measured 2026-09-03). Same bytes ⇒ same key, in
# any checkout; a doc edit moves nothing.
#
# The two callers — tsc-cached.sh and do-reconcile.sh `types` — MUST both use
# this function: they share the `tsc-<folder>.<fp>` namespace on purpose, and a
# second key derivation is a second definition that silently splits the memo.
# The CALLER names the extra dirs (the folders that resolve a workspace
# package's types out of its dist) — this library is `portable` and names no
# monorepo path.
tsc_tree_fingerprint() {
  [ -n "${1:-}" ] || return 1
  _gov fingerprint "$@"
}

# gate_sweep_stale — drop locks whose owner is gone. The lock reaper only fires
# when someone CONTENDS, so a session that died holding a slot would shrink the
# effective cap until the next contender happened along. Run at session start.
# Echoes the number swept.
gate_sweep_stale() { _gov sweep-stale; }

# ─────────────────────────────────────────────────────────────────────────────
# CLAIMS — a machine-wide registry of who is working on WHICH REGION right now.
#
# WHY: do-fleet's conflict registry was `LOCK_FILE="$(mktemp)"` — process-local.
# Nine concurrent fleet invocations held nine private maps and could not see
# each other, so two fleets picked the same region and did the work twice.
#
# It is NOT a queue and there is NO coordinator. A worker that finds its region
# claimed takes the next candidate instead of waiting — contention costs a
# re-rank, never a wait, so there is nothing to deadlock.
#
# EVAPORATION — a claim expires with no human in the loop, two ways: the owner
# pid is dead, or the lease expired (GOVERN_CLAIM_TTL_SECS, default 90 min;
# p100 observed fleet duration is 79 min). Both fire on the READ path, so the
# next contender reclaims dead ground without anyone sweeping first.
# gate_sweep_stale only matches `lock-*` and will never see these; claim_sweep
# is the equivalent for claims.

GOVERN_CLAIMS_DIR="${GOVERN_CLAIMS_DIR:-$GOVERN_DIR/claims}"
GOVERN_CLAIM_TTL_SECS="${GOVERN_CLAIM_TTL_SECS:-5400}"   # 90 min
export GOVERN_CLAIMS_DIR GOVERN_CLAIM_TTL_SECS

# _gv_claim_key <region> — a readable, collision-free directory name.
# STAYS IN BASH: `cksum` is the POSIX CRC (length-appended, final complement),
# not zlib's crc32, and re-deriving it in TS would be a second definition of a
# mapping govern-claims-check.sh reads straight off disk. Readable matters —
# `ls $GOVERN_DIR/claims` is meant to be the map a human reads — and the cksum
# suffix restores the injectivity that sanitising destroys (a/b vs a_b).
_gv_claim_key() {
  local r="$1" safe sum
  safe=$(printf '%s' "$r" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64)
  sum=$(printf '%s' "$r" | cksum | awk '{print $1}')
  printf '%s.%s' "$safe" "$sum"
}

# _gv_claim_env — how the claim commands learn who is alive.
#
# NORMAL PATH: nothing. govern.ts asks the kernel itself, at the instant it
# contends. That is not an optimisation, it is a correctness requirement — a
# pre-computed alive-set is a SNAPSHOT, and 12 workers racing one region each
# snapshot an empty registry, each conclude the winner's pid is "not alive",
# each reap it and each take the region. Measured here on the first port:
# govern-claims-check C1 reported 12 winners of 12.
#
# STUBBED PATH: when the caller has overridden _gv_alive (govern-claims-check's
# R1/R2 red proof does exactly this, to prove the evaporation checks are testing
# the reaper), the shell's answer must win. Detected by comparing the function
# body against the one this file defined, so no caller has to opt in.
_gv_alive_stubbed() { [ "$(declare -f _gv_alive 2>/dev/null || true)" != "$_GV_ALIVE_CANON" ]; }

# Sets/exports the two vars govern.ts reads. Called before every claim command.
_gv_claim_prep() {
  GOVERN_ALIVE_SET=0; GOVERN_ALIVE_PIDS=""
  export GOVERN_ALIVE_SET GOVERN_ALIVE_PIDS
  _gv_alive_stubbed || return 0
  local p out=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    _gv_alive "$p" && out="$out,$p"
  done <<EOF
$(_gov claim-pids 2>/dev/null)
EOF
  GOVERN_ALIVE_SET=1; GOVERN_ALIVE_PIDS="${out#,}"
  return 0
}

# claim_take <region> [slug] — deposit a claim on a region.
#   0 = it is yours (freshly taken, or you already held it)
#   1 = a live, in-lease worker holds it — REROUTE, do not wait
# mkdir(2) is the arbiter: two workers racing one region, exactly one wins.
claim_take() {
  _gv_claim_prep
  GOVERN_OWNER_PID=$$ _gov claim-take "$(_gv_claim_key "$1")" "$1" "${2:-}"
}

# claim_owner <region> — echo "<slug> <pid>" of the LIVE owner, else nothing.
# Reaps before reading: a dead owner's claim must never read as held.
claim_owner() {
  _gv_claim_prep
  GOVERN_OWNER_PID=$$ _gov claim-owner "$(_gv_claim_key "$1")"
}

# claim_release <region> — drop a claim you own. Never touches another's.
claim_release() {
  GOVERN_OWNER_PID=$$ _gov claim-release "$(_gv_claim_key "$1")" >/dev/null 2>&1
  return 0
}

# claim_release_all — drop every claim this shell holds. Wire it to the EXIT
# trap: a clean exit must free its ground immediately, so the 90-min TTL stays
# the exception path (crash/kill) and never the normal one.
#
# NOTE it keys on the plain shell pid while claim_take/claim_release key on
# ${GOVERN_CLAIM_PID:-$$}. That asymmetry is in the bash original and is
# preserved verbatim — normalising it during a port would change behaviour no
# proof covers.
claim_release_all() {
  GOVERN_OWNER_PID=$$ _gov claim-release-all >/dev/null 2>&1
  return 0
}

# claim_list — every LIVE claim as "region<TAB>slug<TAB>pid". Reaps as it walks.
claim_list() {
  _gv_claim_prep
  GOVERN_OWNER_PID=$$ _gov claim-list
}

# claim_sweep — reap every dead/expired claim. Echoes the number swept.
# gate_sweep_stale's counterpart; safe to call at session start.
claim_sweep() {
  _gv_claim_prep
  GOVERN_OWNER_PID=$$ _gov claim-sweep
}
