#!/usr/bin/env bash
# preview-fd-check.sh — is the preview tax a PIPE that outlives the script?
#
# manifest: needs-env
#   Mode A (default) is self-contained: a scratch sandbox, one node mimic, no
#   ports, no worktree, no astro, no credential. Mode B (--real) drives
#   worktree-preview.sh against one.ie/web and costs a worktree and a port.
#
# NOT A FIX. A MEASUREMENT THAT IS ALLOWED TO COME BACK NEGATIVE.
#
# THE OBSERVATION. The chairman measured ~7 min of Opus per UI task blocked in
#   worktree-preview.sh up <slug> --route / | tail -30
# with the server green in under a minute and the shell parked in __wait4 at
# 8m42s. Two mechanisms fit that sample and only one of them is fixable at the
# launch line:
#
#   H1  THE PIPE OUTLIVES THE SCRIPT. cmd_up prints GREEN and returns, but the
#       reader never sees EOF because a descendant of the launch still holds the
#       script's stdout. The tool call is waiting on `tail`, not on the server.
#   H2  THE SCRIPT REALLY IS STILL RUNNING. BOOT_LOCK_WAIT 240 + BOOT_TIMEOUT 60
#       + WARM_TIMEOUT 180 = 480s against an observed 522s. A `sleep 1` poll loop
#       samples as __wait4 exactly like waiting on a pipe.
#
# Mode A can only support or refute H1. It CANNOT exclude H2 — only --real can,
# by asking whether the driver process is already gone at the moment the server
# answers 200. So a green Mode A is not licence to touch worktree-preview.sh.
#
# THE LAUNCH THIS REPRODUCES, quoted from worktree-preview.sh (the perl branch;
# the nohup branch is its twin):
#   ( cd "$app" && perl -e 'setsid; exec @ARGV' -- sh -c "exec $astro dev ..." >>"$log" 2>&1 & echo $! > "$state/pid" )
#
# VARIANTS, each timed from the DRIVER'S OWN EXIT to the reader's EOF:
#   V1 driver | cat                      the shape the operator runs
#   V2 driver > file                     no pipe at all
#   V3 driver | cat, launch gets </dev/null    is stdin the holder?
#   V4 driver | cat, subshell does `exec >>log 2>&1 </dev/null` BEFORE the fork
#
# VERDICT DISCIPLINE. REPRODUCED requires ALL THREE:
#   V1 hold >= 60% of the mimic's lifetime  AND  V2 hold <= 2s  AND  a NAMED
#   process holding the same pipe as the reader's fd 0.
# A timing alone is a correlation. Anything short of all three prints
# NOT REPRODUCED with every number and exits 3, and no line of
# worktree-preview.sh is touched.
#
# WHAT MODE A FOUND, 2026-09-06 (hold 12s):
#   V1(pipe)=12.2s  V2(file)=0.0s  V3(stdin</dev/null)=12.2s  V4(exec-before-fork)=0.0s
#   holder = <pid> bash / fd 1 / the exact peer of the reader's fd 0.
# The holder is a BASH SUBSHELL, not node. `cmd >>log 2>&1 &` backgrounds the
# whole `cd "$app" && perl …` AND-LIST: bash forks a subshell to run it, and the
# `>>"$log" 2>&1` binds to the `perl` simple command INSIDE it. So the subshell
# keeps the caller's stdout on its own fd 1 for as long as the server lives, and
# `$!` — the pid worktree-preview.sh stores and polls — IS that subshell.
# V3 shows stdin is not the holder; V4 shows giving the subshell its own stdio
# before the fork closes it. That is H1, named.
#
# H2 IS STILL LIVE for the 522s the chairman observed (BOOT_LOCK_WAIT 240 +
# BOOT_TIMEOUT 60 + WARM_TIMEOUT 180 = 480s), and Mode A cannot separate them.
# NOTHING IN worktree-preview.sh HAS BEEN CHANGED on the strength of this run.
#
# USAGE  preview-fd-check.sh [--sandbox] [--hold N]     Mode A, default
#        preview-fd-check.sh --real <slug>              Mode B, opt-in
#        preview-fd-check.sh --self-test                the harness's own guards
# EXITS  0 REPRODUCED · 3 NOT REPRODUCED · 4 bad arguments / missing tool /
#        UNMEASURED (a variant produced no timing — never reported as a verdict)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOLD="${PREVIEW_FD_HOLD:-12}"
MODE=sandbox
SLUG=""

now() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time'; }
el()  { perl -e 'printf "%.1f\n", $ARGV[1] - $ARGV[0]' "$1" "$2"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --sandbox) MODE=sandbox; shift ;;
    --real)    MODE=real; SLUG="${2:-}"; shift 2 ;;
    --hold)    HOLD="${2:-12}"; shift 2 ;;
    --self-test) MODE=selftest; shift ;;
    -h|--help) sed -n '2,50p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "preview-fd-check: unknown argument: $1" >&2; exit 4 ;;
  esac
done

command -v perl >/dev/null 2>&1 || { echo "preview-fd-check: perl not found — it is both the timer and the launch shape" >&2; exit 4; }
command -v node >/dev/null 2>&1 || { echo "preview-fd-check: node not found — the mimic is a node process on purpose" >&2; exit 4; }

SB="${TMPDIR:-/tmp}/preview-fd-$$"
mkdir -p "$SB"
cleanup() {
  local p
  for p in "$SB"/*/pid; do [ -f "$p" ] || continue; kill -- -"$(cat "$p")" 2>/dev/null || kill "$(cat "$p")" 2>/dev/null; done
  rm -rf "$SB"
}
trap cleanup EXIT INT TERM

# The astro-mimic: a node process that (a) runs a worker thread, (b) spawns a
# grandchild with inherited stdio, (c) holds the event loop. Those are the three
# things astro dev's process tree does that a bare `sleep` child does not — and
# a bare `sleep` child is exactly the harness that already failed to reproduce.
cat > "$SB/mimic.js" <<'MIMIC'
const { Worker } = require('worker_threads')
const { spawn } = require('child_process')
const secs = Number(process.argv[2] || 12)
const ms = secs * 1000
new Worker(`setTimeout(() => {}, ${ms})`, { eval: true })
spawn('sh', ['-c', `sleep ${secs}`], { stdio: 'inherit' })
console.log('mimic up')
setTimeout(() => process.exit(0), ms)
MIMIC

# The driver: worktree-preview.sh's cmd_up, reduced to its launch and its GREEN
# line. $1 = variant, $2 = state dir, $3 = hold seconds.
cat > "$SB/driver.sh" <<'DRIVER'
#!/usr/bin/env bash
set -uo pipefail
variant="$1"; state="$2"; hold="$3"
log="$state/mimic.log"; : > "$log"
mimic="$state/../mimic.js"
case "$variant" in
  plain)
    ( cd "$state" && perl -e 'setsid; exec @ARGV' -- sh -c "exec node $mimic $hold" >>"$log" 2>&1 & echo $! > "$state/pid" ) ;;
  stdin)
    ( cd "$state" && perl -e 'setsid; exec @ARGV' -- sh -c "exec node $mimic $hold" >>"$log" 2>&1 </dev/null & echo $! > "$state/pid" ) ;;
  execfd)
    ( cd "$state" && exec >>"$log" 2>&1 </dev/null; perl -e 'setsid; exec @ARGV' -- sh -c "exec node $mimic $hold" & echo $! > "$state/pid" ) ;;
  *) echo "driver: unknown variant $variant" >&2; exit 4 ;;
esac
perl -MTime::HiRes=time -e 'printf "%.3f\n", time' > "$state/driver_exit"
echo "GREEN mimic up (driver returning, exactly as cmd_up does)"
DRIVER
chmod +x "$SB/driver.sh"

# One variant, measured. $1 = name, $2 = driver variant, $3 = pipe|file
run_variant() {
  # NOT one `local` line: bash expands every word of the builtin BEFORE any of
  # the assignments take effect, so `st="$SB/$name"` reads an unset `name` and
  # dies under `set -u`. Measured here 2026-09-06 — it produced four empty
  # timings that the verdict then reported as a confident NOT REPRODUCED.
  local name="$1" variant="$2" sink="$3" t0 t_eof t_drv
  local st="$SB/$name"
  mkdir -p "$st"
  t0="$(now)"
  if [ "$sink" = pipe ]; then
    ( bash "$SB/driver.sh" "$variant" "$st" "$HOLD" | cat > "$st/out.txt"
      perl -MTime::HiRes=time -e 'printf "%.3f\n", time' > "$st/eof" ) &
  else
    ( bash "$SB/driver.sh" "$variant" "$st" "$HOLD" > "$st/out.txt"
      perl -MTime::HiRes=time -e 'printf "%.3f\n", time' > "$st/eof" ) &
  fi
  local job=$!
  # While the reader may still be blocked, name the holder. A timing without a
  # named process is a correlation, and the verdict refuses it.
  if [ "$sink" = pipe ] && [ "$name" = V1 ]; then sleep 3; name_holder "$st"; fi
  wait "$job" 2>/dev/null
  t_eof="$(cat "$st/eof" 2>/dev/null)"; t_drv="$(cat "$st/driver_exit" 2>/dev/null)"
  if [ -z "$t_eof" ] || [ -z "$t_drv" ]; then echo "unmeasured"; return; fi
  el "$t_drv" "$t_eof"
}

# Does any process in the launched tree hold the SAME pipe the reader is blocked
# on? macOS lsof prints a pipe as `PIPE 0x<dev> ... ->0x<peer>`; the reader's fd
# 0 and a writer's fd share those addresses.
HOLDER="none"
name_holder() {
  local st="$1" mpid rp toks t
  mpid="$(cat "$st/pid" 2>/dev/null)"
  command -v lsof >/dev/null 2>&1 || { HOLDER="lsof-missing"; return; }
  # The reader is the `cat` whose fd 1 is out.txt; find its pipe tokens on fd 0.
  rp="$(lsof -n -t -- "$st/out.txt" 2>/dev/null | head -1)"
  [ -n "$rp" ] || { HOLDER="reader-not-found"; return; }
  toks="$(lsof -n -p "$rp" 2>/dev/null | awk '$5 == "PIPE" {print $6; if ($NF ~ /^->0x/) print substr($NF,3)}' | sort -u)"
  [ -n "$toks" ] || { HOLDER="reader-holds-no-pipe"; return; }
  local cand="" line
  # Every descendant of the launched pid, plus the pid itself.
  local pids; pids="$(ps -A -o pid=,ppid=,comm= 2>/dev/null)"
  local tree; tree="$(printf '%s\n' "$mpid"; printf '%s\n' "$pids" | awk -v m="$mpid" '$2 == m {print $1}')"
  for t in $tree; do
    [ -n "$t" ] || continue
    line="$(lsof -n -p "$t" 2>/dev/null | awk '$5 == "PIPE" {print $6; if ($NF ~ /^->0x/) print substr($NF,3)}' | sort -u)"
    [ -n "$line" ] || continue
    local shared; shared="$(comm -12 <(printf '%s\n' "$toks") <(printf '%s\n' "$line") 2>/dev/null | head -1)"
    if [ -n "$shared" ]; then
      # Name the process AND the pipe, with the fd it holds it on. A pid alone
      # is a coincidence; a pid whose fd 1 is the peer of the reader's fd 0 is
      # the mechanism.
      local fd; fd="$(lsof -n -p "$t" 2>/dev/null | awk -v s="$shared" '$5 == "PIPE" && ($6 == s || substr($NF,3) == s) {print $4; exit}')"
      cand="$(ps -o pid=,comm= -p "$t" 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//')/fd${fd:-?}/pipe${shared}"
      break
    fi
  done
  HOLDER="${cand:-no-shared-pipe-in-launch-tree}"
  # run_variant is called in a command substitution, so this assignment lives in
  # a subshell and would evaporate. The answer travels by file, or the verdict
  # would silently read `none` and refuse a real reproduction.
  printf '%s' "$HOLDER" > "$SB/holder"
}

self_test() {
  local fails=0 rc
  printf '== preview-fd-check --self-test\n'
  # The harness must refuse to call a hang a reproduction without a named holder.
  if ( HOLDER="no-shared-pipe-in-launch-tree"; verdict 30 0 30 0 >/dev/null 2>&1 ); then
    printf '  FAIL %-52s\n' 'a hang with NO named holder read as REPRODUCED' >&2; fails=$((fails+1))
  else
    printf '  ok   %-52s\n' 'no named holder => NOT REPRODUCED, whatever the timings'
  fi
  if ( HOLDER="1234 node"; verdict 0 0 0 0 >/dev/null 2>&1 ); then
    printf '  FAIL %-52s\n' 'zero hold everywhere read as REPRODUCED' >&2; fails=$((fails+1))
  else
    printf '  ok   %-52s\n' 'no hold => NOT REPRODUCED even with a holder'
  fi
  if ( HOLDER="1234 node"; verdict "$HOLD" 0 "$HOLD" 0 >/dev/null 2>&1 ); then
    printf '  ok   %-52s\n' 'all three conditions => REPRODUCED'
  else
    printf '  FAIL %-52s\n' 'the green half is unreachable' >&2; fails=$((fails+1))
  fi
  if ( HOLDER="1234 node"; verdict "$HOLD" "$HOLD" "$HOLD" "$HOLD" >/dev/null 2>&1 ); then
    printf '  FAIL %-52s\n' 'V2 hanging too (so: not the pipe) read as REPRODUCED' >&2; fails=$((fails+1))
  else
    printf '  ok   %-52s\n' 'V2 hanging too => NOT REPRODUCED (not a pipe effect)'
  fi
  # THE HOUSE BUG, in this harness's own shape: an empty timing must not read as
  # a benign "not reproduced". Driven for real — this exact defect shipped in the
  # first draft and was caught by running it.
  ( HOLDER="1234 node"; verdict "" 0 0 0 >/dev/null 2>&1 ); rc=$?
  if [ "$rc" = 4 ]; then printf '  ok   %-52s exit 4\n' 'an unmeasured variant is UNMEASURED, not a verdict'
  else printf '  FAIL %-52s exit %s\n' 'an empty timing produced a verdict' "$rc" >&2; fails=$((fails+1)); fi
  ( HOLDER="1234 node"; verdict "$HOLD" unmeasured 0 0 >/dev/null 2>&1 ); rc=$?
  if [ "$rc" = 4 ]; then printf '  ok   %-52s exit 4\n' 'a word where a number belongs is UNMEASURED'
  else printf '  FAIL %-52s exit %s\n' 'a non-numeric timing produced a verdict' "$rc" >&2; fails=$((fails+1)); fi

  [ "$fails" -eq 0 ] && { printf 'preview-fd-check --self-test: PASS (6 checks)\n'; return 0; }
  printf 'preview-fd-check --self-test: RED — %s failed\n' "$fails" >&2; return 1
}

# verdict <v1> <v2> <v3> <v4> — the three conditions, judged together.
verdict() {
  local v1="$1" v2="$2" v3="$3" v4="$4" floor
  floor="$(perl -e 'printf "%.1f", $ARGV[0] * 0.6' "$HOLD")"
  printf 'PREVIEW-FD hold=%ss floor=%ss  V1(pipe)=%ss  V2(file)=%ss  V3(stdin</dev/null)=%ss  V4(exec-before-fork)=%ss  holder=%s\n' \
    "$HOLD" "$floor" "$v1" "$v2" "$v3" "$v4" "$HOLDER"
  local n
  for n in "$v1" "$v2" "$v3" "$v4"; do
    case "$n" in
      ''|*[!0-9.]*)
        printf 'PREVIEW-FD: UNMEASURED — a variant produced no timing (%s). This is NOT "not reproduced";\n' "$n"
        printf '  the harness failed to measure and says so. worktree-preview.sh unchanged.\n'
        return 4 ;;
    esac
  done
  local ok1 ok2 ok3
  ok1="$(perl -e 'print(($ARGV[0] =~ /^[0-9.]+$/ && $ARGV[0] >= $ARGV[1]) ? 1 : 0)' "$v1" "$floor")"
  ok2="$(perl -e 'print(($ARGV[0] =~ /^[0-9.]+$/ && $ARGV[0] <= 2.0) ? 1 : 0)' "$v2")"
  case "$HOLDER" in none|lsof-missing|reader-not-found|reader-holds-no-pipe|no-shared-pipe-in-launch-tree|'') ok3=0 ;; *) ok3=1 ;; esac
  if [ "$ok1" = 1 ] && [ "$ok2" = 1 ] && [ "$ok3" = 1 ]; then
    printf 'PREVIEW-FD: REPRODUCED (H1 candidate) — a named process in the launch tree holds the reader'"'"'s pipe.\n'
    printf 'PREVIEW-FD: H2 IS NOT EXCLUDED — Mode A cannot separate them. --real is unrun.\n'
    return 0
  fi
  printf 'PREVIEW-FD: NOT REPRODUCED — '
  [ "$ok1" = 1 ] || printf 'V1 did not hold past the floor. '
  [ "$ok2" = 1 ] || printf 'V2 held too (so the pipe is not the discriminator). '
  [ "$ok3" = 1 ] || printf 'no named fd holder (%s). ' "$HOLDER"
  printf 'worktree-preview.sh unchanged.\n'
  return 3
}

case "$MODE" in
  selftest) self_test; exit $? ;;
  real)
    [ -n "$SLUG" ] || { echo "preview-fd-check: --real needs a slug" >&2; exit 4; }
    echo "preview-fd-check: --real is opt-in and UNRUN here — it costs a worktree, a port and ~2.3GB," >&2
    echo "  it takes no boot lock, and this box is memory-bound. Run it alone, never in a fleet:" >&2
    echo "  PREVIEW_FD_REAL_YES=1 bash .claude/scripts/preview-fd-check.sh --real $SLUG" >&2
    [ "${PREVIEW_FD_REAL_YES:-0}" = 1 ] || exit 4
    echo "preview-fd-check: --real not implemented in this cycle; Mode A is the deliverable." >&2
    exit 4 ;;
esac

printf '== preview-fd-check --sandbox (mimic lifetime %ss)\n' "$HOLD"
V1="$(run_variant V1 plain  pipe)"
HOLDER="$(cat "$SB/holder" 2>/dev/null)"; HOLDER="${HOLDER:-none}"
V2="$(run_variant V2 plain  file)"
V3="$(run_variant V3 stdin  pipe)"
V4="$(run_variant V4 execfd pipe)"
verdict "$V1" "$V2" "$V3" "$V4"
exit $?
