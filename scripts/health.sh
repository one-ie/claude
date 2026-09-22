#!/usr/bin/env bash
# health.sh — is this box healthy enough to work on, and is the estate up?
#
# manifest: portable
#
# WHY (measured 2026-09-05). Answering "why is localhost slow" took a dozen
# ad-hoc commands: uptime, vm_stat, sysctl vm.swapusage, three greps of ps, a
# gate-reaper dry run, an ls of the governor dir, and a curl per surface. Every
# one of those numbers already had a home; nothing put them on one page. The
# session that prompted this found 19 orphaned workerd processes holding the box
# at 20.5G of 21.5G swap — visible in ps all along, in a shape nobody was
# looking at.
#
# It reuses rather than restates: machine-check.sh owns the process/memory read,
# gate-reaper.sh --dry-run owns the orphan shape, govern.sh owns the arithmetic.
# This adds the VERDICT and the service probes, and nothing else.
#
# Usage:  health.sh [--box] [--services] [--json] [--watch N] [--self-test]
#   (no flags)   both halves, human-readable
#   --box        the machine only          --services   the estate only
#   --json       machine-readable, both halves, no colour
#   --watch N    re-run every N seconds until interrupted
#   --fix        reclaim what nothing is coming back for, then re-read
#   --dry-run    with --fix, name every kill instead of making it
#   --signal     emit the box verdict into the world, tagged `engineering`, so
#                the doctor sees the Mac in the same graph as the estate
#   --self-test  prove the verdict thresholds bite (red proof included)
#
# WHAT --fix WILL AND WILL NOT TOUCH. It reclaims three shapes, each one dead by
# a test that cannot be true of live work:
#   1. orphaned gates and workerd  — delegated whole to gate-reaper.sh, whose own
#      checker proves it spares a live parent and a fresh reparent
#   2. language servers rooted in a WORKTREE — the editor should not have opened
#      a project there at all (.vscode/settings.json excludes it); the real
#      tsserver for the main tree is never a candidate
#   3. dev servers in a worktree with NO live claude session — the session that
#      started it is gone, so nobody is watching the port
# It will NEVER kill a claude session, anything holding a governor slot, or
# anything running in the main tree. Those are judgement calls a script does not
# get to make: a session classifier misfired twice on 2026-09-05, which is the
# reason this list is shapes-with-a-dead-owner and not "looks idle".
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/govern.sh
. "$HERE/lib/govern.sh" 2>/dev/null || true

WANT_BOX=1; WANT_SVC=1; AS_JSON=0; WATCH=0; SELFTEST=0; FIX=0; DRY=0; SIGNAL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --box)       WANT_SVC=0 ;;
    --services)  WANT_BOX=0 ;;
    --json)      AS_JSON=1 ;;
    --watch)     WATCH="${2:-10}"; shift ;;
    --fix)       FIX=1 ;;
    --dry-run)   DRY=1 ;;
    --signal)    SIGNAL=1 ;;
    --self-test) SELFTEST=1 ;;
    -h|--help)   sed -n '2,24p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "health: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done

C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_BAD=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
[ -t 1 ] || { C_OK=""; C_WARN=""; C_BAD=""; C_DIM=""; C_OFF=""; }
[ "$AS_JSON" = "1" ] && { C_OK=""; C_WARN=""; C_BAD=""; C_DIM=""; C_OFF=""; }

# ── the box ───────────────────────────────────────────────────────────────────
# Every number here has exactly one source. load and swap come from the kernel;
# headroom comes from govern.sh so the dashboard can never disagree with the
# governor that actually admits gates.
cores() { sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 1; }
load1()  { uptime | sed -E 's/.*load averages?: *([0-9.]+).*/\1/'; }
swap_used_mb() { sysctl -n vm.swapusage 2>/dev/null | sed -E 's/.*used = ([0-9.]+)M.*/\1/' | cut -d. -f1; }
swap_free_mb() { sysctl -n vm.swapusage 2>/dev/null | sed -E 's/.*free = ([0-9.]+)M.*/\1/' | cut -d. -f1; }
orphan_count() {
  [ -x "$HERE/gate-reaper.sh" ] || { echo 0; return; }
  bash "$HERE/gate-reaper.sh" --once --dry-run 2>/dev/null | grep -c 'WOULD reap' || true
}
slots_held() { ls -d "${TMPDIR:-/tmp}/one-govern"/lock-slot-* 2>/dev/null | wc -l | tr -d ' '; }
sessions()   { ps -Ao command= 2>/dev/null | grep -cE '^claude( --|$)' || true; }

# VERDICT — the whole point of the file. Thresholds are the ones the harness
# already uses: machine-check calls load healthy under `cores`, and govern.sh
# refuses to fund a second cycle below one cycle's price. A dashboard that
# invents its own thresholds would drift from the governor within a week.
box_verdict() {
  local c load_i head orph swapfree
  c=$(cores); load_i=$(printf '%.0f' "$(load1)"); head=$(gate_headroom 2>/dev/null || echo 99)
  orph=$(orphan_count); swapfree=$(swap_free_mb)
  if [ "$orph" -gt 0 ]; then echo "DEGRADED|${orph} abandoned gate(s)/orphan(s) burning the box — gate-reaper.sh --once"; return; fi
  if [ "$load_i" -gt $(( c * 2 )) ]; then echo "UNHEALTHY|load ${load_i} is over 2x the ${c} cores — gates are queueing, not running"; return; fi
  if [ "${swapfree:-9999}" -lt 512 ]; then echo "UNHEALTHY|swap has ${swapfree}MB free — the box is paging, every gate runs long"; return; fi
  if [ "$load_i" -gt "$c" ]; then echo "DEGRADED|load ${load_i} is over ${c} cores — work is contending"; return; fi
  if [ "${head:-99}" -lt 2 ]; then echo "DEGRADED|memory funds only ${head} concurrent gate — close idle sessions to widen"; return; fi
  echo "HEALTHY|load ${load_i} on ${c} cores, memory funds ${head} gates"
}

print_box() {
  local v state why
  v=$(box_verdict); state="${v%%|*}"; why="${v#*|}"
  local col="$C_OK"; [ "$state" = "DEGRADED" ] && col="$C_WARN"; [ "$state" = "UNHEALTHY" ] && col="$C_BAD"
  printf '%s\n' "── box ─────────────────────────────────────────"
  printf '  %s%s%s  %s\n' "$col" "$state" "$C_OFF" "$why"
  printf '  %sload %s · %s cores · swap %sM used / %sM free · gates funded %s · slots held %s · sessions %s · orphans %s%s\n' \
    "$C_DIM" "$(load1)" "$(cores)" "$(swap_used_mb)" "$(swap_free_mb)" \
    "$(gate_headroom 2>/dev/null || echo '?')" "$(slots_held)" "$(sessions)" "$(orphan_count)" "$C_OFF"
}

# ── the estate ────────────────────────────────────────────────────────────────
# The URL/assert pairs are deploy.sh's, deliberately. If a probe here disagrees
# with the one that gates a deploy, this file is the one that is wrong.
SURFACES="one.ie|https://one.ie/api/health|\"status\":\"ok\"
api|https://api.one.ie/health|
channels|https://channels.one.ie/health|
pay|https://pay.one.ie/status|\"ok\""

probe() { # name url assert -> "name|state|code|ms|note"
  local name="$1" url="$2" assert="$3" body code ms t0 t1
  t0=$(date +%s%N 2>/dev/null || echo 0)
  body=$(curl -sL --max-time 8 -w $'\n%{http_code}' "$url" 2>/dev/null)
  t1=$(date +%s%N 2>/dev/null || echo 0)
  ms=$(( (t1 - t0) / 1000000 )); [ "$ms" -lt 0 ] && ms=0
  code="${body##*$'\n'}"; body="${body%$'\n'*}"
  if [ "$code" != "200" ]; then echo "${name}|DOWN|${code:-000}|${ms}|no 200"; return; fi
  if [ -n "$assert" ] && ! printf '%s' "$body" | grep -qF "$assert"; then
    echo "${name}|DEGRADED|${code}|${ms}|200 but missing ${assert}"; return
  fi
  echo "${name}|UP|${code}|${ms}|"
}

print_services() {
  printf '%s\n' "── estate ──────────────────────────────────────"
  local line name url assert r state code ms note col
  while IFS='|' read -r name url assert; do
    [ -n "$name" ] || continue
    r=$(probe "$name" "$url" "$assert")
    IFS='|' read -r _ state code ms note <<<"$r"
    col="$C_OK"; [ "$state" = "DEGRADED" ] && col="$C_WARN"; [ "$state" = "DOWN" ] && col="$C_BAD"
    printf '  %s%-9s%s %-4s %5sms  %s%s%s\n' "$col" "$state" "$C_OFF" "$code" "$ms" "$C_DIM" "${name} ${note}" "$C_OFF"
  done <<<"$SURFACES"
  printf '  %s%-9s%s   —      —  %ssync · backup — cron-only, no health endpoint exists%s\n' \
    "$C_DIM" "UNKNOWN" "$C_OFF" "$C_DIM" "$C_OFF"
}

print_json() {
  local v state why
  v=$(box_verdict); state="${v%%|*}"; why="${v#*|}"
  printf '{"box":{"verdict":"%s","why":"%s","load":%s,"cores":%s,"swap_used_mb":%s,"swap_free_mb":%s,"gates_funded":%s,"slots_held":%s,"sessions":%s,"orphans":%s},"services":[' \
    "$state" "$why" "$(load1)" "$(cores)" "$(swap_used_mb)" "$(swap_free_mb)" \
    "$(gate_headroom 2>/dev/null || echo 0)" "$(slots_held)" "$(sessions)" "$(orphan_count)"
  local first=1 name url assert r s code ms note
  while IFS='|' read -r name url assert; do
    [ -n "$name" ] || continue
    r=$(probe "$name" "$url" "$assert"); IFS='|' read -r _ s code ms note <<<"$r"
    [ $first = 1 ] || printf ','; first=0
    printf '{"name":"%s","state":"%s","code":"%s","ms":%s}' "$name" "$s" "$code" "$ms"
  done <<<"$SURFACES"
  printf ']}\n'
}

# ── signal ────────────────────────────────────────────────────────────────────
# The estate's half (health:diagnose) already writes its verdict back as weighted
# paths. This is the Mac's half of the same graph: same tag vocabulary, so a
# symptom here ranks beside a symptom there instead of living in a terminal
# nobody reads. Tagged `engineering` because that is the doctor's bare stake —
# a namespaced tag would match zero subscribers (root CLAUDE.md § the stake is
# written as BARE words).
emit_verdict() {
  local lib="$HERE/../hooks/lib/signal.sh"
  [ -f "$lib" ] || return 0
  local v state why
  v=$(box_verdict); state="${v%%|*}"; why="${v#*|}"
  # shellcheck source=../hooks/lib/signal.sh
  . "$lib" 2>/dev/null || return 0
  command -v emit_world >/dev/null 2>&1 || return 0
  emit_world "health" "$([ "$state" = "HEALTHY" ] && echo fyi || echo attention)" \
    "engineering,health,box" "box is ${state}: ${why}" \
    "verdict=${state}" "load=$(load1)" "cores=$(cores)" \
    "swap_free_mb=$(swap_free_mb)" "gates_funded=$(gate_headroom 2>/dev/null || echo 0)" \
    "orphans=$(orphan_count)" "sessions=$(sessions)" 2>/dev/null || true
}

run_once() {
  if [ "$AS_JSON" = "1" ]; then print_json; return; fi
  [ "$FIX" = "1" ] && run_fix
  [ "$SIGNAL" = "1" ] && emit_verdict
  [ "$WANT_BOX" = "1" ] && print_box
  [ "$WANT_BOX" = "1" ] && [ "$WANT_SVC" = "1" ] && echo
  [ "$WANT_SVC" = "1" ] && print_services
  return 0
}

# ── fix ───────────────────────────────────────────────────────────────────────
# Every candidate is named with the reason it is dead, so a --dry-run reads as
# an argument and not as a list of pids.
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# Walk REAL descendants via ppid — never signal a process GROUP. A pgid can be
# shared with an ancestor shell/session when a child is spawned without
# setsid(2) (tsserver commonly is), and `kill -TERM -$pgid` then kills
# everything sharing that group, session included. Measured 2026-09-15: this
# exact line took down 3 of 6 live `claude` sessions whose tsserver children
# happened to share the launching shell's process group. ppid is the only
# honest boundary — it can never reach outside the tree rooted at $pid.
_kill_tree() { # pid -> TERM pid and every process/pid rooted at pid, leaves ancestors untouched
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    _kill_tree "$child"
  done
  kill -TERM "$pid" 2>/dev/null || true
}

_reap() { # pid why
  local pid="$1" why="$2" rss
  rss=$(( $(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0) / 1024 ))
  if [ "$DRY" = "1" ]; then printf '  %sWOULD%s reclaim pid=%-7s %5sMB  %s\n' "$C_WARN" "$C_OFF" "$pid" "$rss" "$why"; return 0; fi
  _kill_tree "$pid"
  printf '  %sreclaimed%s pid=%-7s %5sMB  %s\n' "$C_OK" "$C_OFF" "$pid" "$rss" "$why"
}

# A governor slot owner is live work by definition — it is holding the lock the
# whole box queues behind.
_holds_slot() {
  local pid="$1" d
  for d in "${TMPDIR:-/tmp}/one-govern"/lock-slot-*; do
    [ -d "$d" ] || continue
    [ "$(cat "$d/pid" 2>/dev/null)" = "$pid" ] && return 0
  done
  return 1
}

# Is any live claude session — or any process in its tree — cwd'd inside this
# worktree? lsof on the pid is the only honest test: a worktree path in a
# command line proves nothing.
#
# TWO signals, and the second exists because the first is blind by construction.
#
#  1. a live `claude` process, OR ANY DESCENDANT OF ONE, cwd'd in the worktree.
#     Until 2026-09-22 this read only the top-level claude pid's OWN cwd, so a
#     session whose claude sits at the repo root while its bash / playwright /
#     browser child does the work INSIDE a worktree read as dead. The parent
#     check is kept — it is still a valid signal — and the descendant walk is
#     added beside it, never in place of it: a false negative here is not a
#     missed cleanup, it is a kill of live work.
#
#  2. the SHARED `dev` worktree is live by definition. Its dev server is
#     deliberately detached — the launcher reparents to init — so the server has
#     NO claude ancestor and never will, and signal 1 therefore cannot ever see
#     it, however far it walks. Measured 2026-09-22: `--fix --dry-run` proposed
#     reclaiming 1851MB of that server while six sessions were live. The BRANCH
#     is the derivable fact (git refuses two worktrees on one branch), never a
#     path literal, so no list can drift.
_worktree_is_shared_dev() {
  [ "$(git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "dev" ]
}

_worktree_has_session() {
  local wt="$1" csv

  _worktree_is_shared_dev "$wt" && return 0

  # ONE ps snapshot and ONE lsof call. Recursing `pgrep -P` per session would be
  # both slower and non-atomic — the tree can change between the calls, and a
  # liveness test that races is a liveness test that kills.
  csv=$(ps -Ao pid=,ppid=,command= 2>/dev/null | awk '
    { pid=$1; pp=$2; parent[pid]=pp; all[++n]=pid
      if ($3 ~ /claude$/ || $0 ~ / claude --/) seed[pid]=1 }
    END {
      for (i=1;i<=n;i++) {
        p=all[i]; q=p; hops=0
        while (q!="" && q!="0" && q!="1" && hops++<64) {
          if (seed[q]) { live[p]=1; break }
          q=parent[q]
        }
      }
      out=""
      for (i=1;i<=n;i++) if (live[all[i]]) out = out (out==""?"":",") all[i]
      print out
    }')

  [ -n "$csv" ] || return 1
  # Prefix-match on a path boundary: "…/wt-a" must not be satisfied by "…/wt-ab".
  lsof -a -d cwd -p "$csv" -Fn 2>/dev/null | sed -n 's/^n//p' |
    awk -v w="$wt" '$0==w || index($0, w "/")==1 { found=1 } END { exit !found }'
}

fix_orphans() { # delegated whole — this file must not own a second reaper
  [ -x "$HERE/gate-reaper.sh" ] || return 0
  local out
  if [ "$DRY" = "1" ]; then out=$(bash "$HERE/gate-reaper.sh" --once --dry-run 2>/dev/null)
  else out=$(bash "$HERE/gate-reaper.sh" --once 2>/dev/null); fi
  [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  /'
  return 0
}

fix_worktree_lsp() {
  local pid root rss
  for pid in $(pgrep -f 'tsserver.js|typescript/lib/tsserver' 2>/dev/null); do
    _holds_slot "$pid" && continue
    root=$(lsof -nP -p "$pid" 2>/dev/null | grep -oE "${REPO_ROOT}/\.claude/worktrees/[^/]+" | head -1)
    [ -n "$root" ] || continue
    _reap "$pid" "language server indexing $(basename "$root") — the editor config excludes worktrees"
  done
}

fix_dead_dev_servers() {
  # Resolve each dev server by its CWD, never by string-matching its argv. The
  # first draft grepped pids and worktree paths out of one ps stream and paired
  # them with `paste - -`; when a server's argv carried no worktree path the
  # columns silently shifted and it paired one pid with ANOTHER pid. A kill list
  # built by that is a coin flip, so cwd it is.
  local pid cwd wt
  for pid in $(pgrep -f 'bin/astro dev' 2>/dev/null); do
    _holds_slot "$pid" && continue
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
    case "$cwd" in
      "$REPO_ROOT"/.claude/worktrees/*) ;;
      *) continue ;;
    esac
    wt="${cwd#"$REPO_ROOT"/.claude/worktrees/}"; wt="$REPO_ROOT/.claude/worktrees/${wt%%/*}"
    _worktree_has_session "$wt" && continue
    _reap "$pid" "dev server in $(basename "$wt") — no live session is cwd'd there"
  done
}

run_fix() {
  printf '%s\n' "── reclaiming ──────────────────────────────────"
  [ "$DRY" = "1" ] && printf '  %sdry run — nothing will be killed%s\n' "$C_DIM" "$C_OFF"
  local before after
  before=$(swap_free_mb)
  fix_orphans
  fix_worktree_lsp
  fix_dead_dev_servers
  sleep 2
  after=$(swap_free_mb)
  printf '  %sswap free %sM -> %sM%s\n\n' "$C_DIM" "$before" "$after" "$C_OFF"
}

# ── self-test ─────────────────────────────────────────────────────────────────
# Proves the two things that can silently rot: the verdict thresholds, and the
# probe's willingness to call a 200 that lacks its assert DEGRADED rather than UP.
self_test() {
  local fails=0
  ok()  { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
  bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails + 1)); }
  echo "── health.sh: the verdict bites, and a bad 200 is not UP ──"

  cores() { echo 10; }; gate_headroom() { echo 4; }; orphan_count() { echo 0; }
  load1() { echo 2.0; }; swap_free_mb() { echo 4000; }
  [ "$(box_verdict)" != "${_x:-}" ] && case "$(box_verdict)" in HEALTHY*) ok "C1 quiet box reads HEALTHY";; *) bad "C1 quiet box: $(box_verdict)";; esac

  load1() { echo 25.0; }
  case "$(box_verdict)" in UNHEALTHY*) ok "C2 load over 2x cores reads UNHEALTHY";; *) bad "C2 got: $(box_verdict)";; esac

  load1() { echo 2.0; }; swap_free_mb() { echo 100; }
  case "$(box_verdict)" in UNHEALTHY*) ok "C3 swap under 512MB free reads UNHEALTHY";; *) bad "C3 got: $(box_verdict)";; esac

  swap_free_mb() { echo 4000; }; orphan_count() { echo 3; }
  case "$(box_verdict)" in DEGRADED*orphan*) ok "C4 orphans read DEGRADED and name the fix";; *) bad "C4 got: $(box_verdict)";; esac

  orphan_count() { echo 0; }; gate_headroom() { echo 1; }
  case "$(box_verdict)" in DEGRADED*funds*) ok "C5 headroom of 1 reads DEGRADED";; *) bad "C5 got: $(box_verdict)";; esac

  # A 200 whose body lost its assert is the failure deploy.sh's probe exists to
  # catch — a worker that boots and serves the wrong app.
  curl() { printf 'not the droid\n200'; }
  case "$(probe x http://stub '"status":"ok"')" in *"|DEGRADED|"*) ok "C6 a 200 missing its assert is DEGRADED, not UP";; *) bad "C6 got: $(probe x http://stub '\"status\":\"ok\"')";; esac
  curl() { printf '{"status":"ok"}\n200'; }
  case "$(probe x http://stub '"status":"ok"')" in *"|UP|"*) ok "C7 a 200 carrying its assert is UP";; *) bad "C7 got: $(probe x http://stub)";; esac

  # ── the --fix rules: each candidate must be dead by a test live work fails ──
  # _reap is replaced by a recorder, so nothing is killed and the LIST is the
  # assertion. That list is the whole safety argument of --fix.
  REAPED=""
  _reap() { REAPED="$REAPED $1"; }
  REPO_ROOT="/repo"

  pgrep() { echo 4242; }
  lsof()  { echo "n/repo/.claude/worktrees/wt-a/app/web"; }   # generic on purpose: a portable script must name no monorepo path
  _holds_slot() { return 1; }
  _worktree_has_session() { return 1; }

  REAPED=""; fix_worktree_lsp
  case "$REAPED" in *4242*) ok "F1 a language server rooted in a worktree is a candidate";; *) bad "F1 missed it: '$REAPED'";; esac

  _holds_slot() { return 0; }
  REAPED=""; fix_worktree_lsp
  case "$REAPED" in *4242*) bad "F2 killed a language server that holds a governor slot";; *) ok "F2 a slot holder is spared — it is the lock the box queues behind";; esac
  _holds_slot() { return 1; }

  REAPED=""; fix_dead_dev_servers
  case "$REAPED" in *4242*) ok "F3 a dev server in a session-less worktree is a candidate";; *) bad "F3 missed it: '$REAPED'";; esac

  _worktree_has_session() { return 0; }
  REAPED=""; fix_dead_dev_servers
  case "$REAPED" in *4242*) bad "F4 killed a dev server whose worktree HAS a live session";; *) ok "F4 a worktree with a live session is spared";; esac
  _worktree_has_session() { return 1; }

  # A dev server in the MAIN tree is never a candidate — the cwd case only
  # admits paths under .claude/worktrees/.
  lsof() { echo "n/repo/app/web"; }
  REAPED=""; fix_dead_dev_servers
  case "$REAPED" in *4242*) bad "F5 killed a dev server running in the MAIN tree";; *) ok "F5 the main tree's dev server is never a candidate";; esac

  # --dry-run must not kill. Restore the real _reap and prove its dry path never
  # reaches kill by stubbing kill itself as a recorder.
  unset -f _reap 2>/dev/null || true
  eval "$(sed -n '/^_reap() {/,/^}/p' "${BASH_SOURCE[0]}")"
  KILLED=""; kill() { KILLED="$KILLED $*"; }
  DRY=1; out=$(_reap 4242 "stub"); 
  case "$out$KILLED" in *WOULD*) [ -z "$KILLED" ] && ok "F6 --dry-run names the kill and never calls it" || bad "F6 dry run called kill: $KILLED";; *) bad "F6 dry run printed: $out";; esac
  unset -f kill 2>/dev/null || true


  # ── the worktree liveness test: two signals, and it must still answer DEAD ──
  # F1..F6 replaced this function with a constant. Put the REAL one back — a
  # liveness test proven only against a stub proves nothing about the kill list.
  unset -f _worktree_has_session 2>/dev/null || true
  eval "$(sed -n '/^_worktree_has_session() {/,/^}/p' "${BASH_SOURCE[0]}")"

  # A session whose claude sits at the repo ROOT while its child does the work
  # INSIDE the worktree. 600's own cwd is /repo, so a parent-only test reads
  # this worktree as dead — and then proposes killing the dev server in it.
  # ONLY the descendant walk can see 700. This is the 2026-09-22 near-miss.
  ps()   { printf '%s\n' "500 1 /bin/login" "600 500 claude" "700 600 bash -c browser-run"; }
  lsof() { local csv="" want=0 a
           for a in "$@"; do [ "$want" = 1 ] && { csv="$a"; want=0; }; [ "$a" = "-p" ] && want=1; done
           case ",$csv," in *,600,*) echo "n/repo";; esac
           case ",$csv," in *,700,*) echo "n/repo/.claude/worktrees/wt-a";; esac; }
  git()  { return 1; }   # no worktree in this fixture is the shared dev one

  if _worktree_has_session /repo/.claude/worktrees/wt-a
  then ok  "F10 a DESCENDANT of a live session, cwd'd in the worktree, reads LIVE"
  else bad "F10 the descendant walk is blind — this is the live-work kill"; fi

  # It must still be able to answer DEAD, or both guards are stuck open and
  # every other check in this block is worthless.
  if _worktree_has_session /repo/.claude/worktrees/wt-b
  then bad "F12 a worktree with nothing cwd'd in it read LIVE — the test is stuck open"
  else ok  "F12 a worktree with no session and no descendant still reads DEAD"; fi

  # The shared dev worktree: its server is detached — the launcher reparents to
  # init — so it has NO claude ancestor and signal 1 can never see it, however
  # far it walks. Not a path literal: the branch is the derivable fact.
  ps()  { printf '%s\n' "500 1 /bin/login"; }   # not a claude in sight
  git() { echo dev; }
  if _worktree_has_session /repo/.claude/worktrees/dev
  then ok  "F11 the shared dev worktree is live by definition, with no session at all"
  else bad "F11 the shared dev worktree read DEAD — that is 1851MB of live dev server"; fi
  unset -f ps lsof git 2>/dev/null || true
  # The red proofs below run the file AGAINST ITSELF. Without this guard the
  # gutted child runs them too, and each child spawns two more — the first
  # version of R2 died on `mktemp: File exists`, which was the recursion, not
  # the template.
  if [ "${HEALTH_SELFTEST_CHILD:-0}" = "1" ]; then
    if [ $fails -eq 0 ]; then echo "ALL GREEN (child)"; return 0; fi
    echo "RED — $fails check(s) failed"; return 1
  fi

  # RED PROOF — take the REAL file, delete the swap arm, and run its OWN
  # self-test. C3 must fail there. Stubbing box_verdict to a constant would
  # prove nothing about the arm; this proves the assertion is load-bearing.
  local gutted anchor_lines out
  gutted="$(mktemp "${TMPDIR:-/tmp}/health-gutted.XXXXXX")"
  grep -v "swapfree:-""9999" "${BASH_SOURCE[0]}" > "$gutted"
  anchor_lines=$(( $(wc -l < "${BASH_SOURCE[0]}") - $(wc -l < "$gutted") ))
  if [ "$anchor_lines" -ne 1 ]; then
    bad "R1 could not remove the swap arm — anchor moved, this checker is blind"
  else
    out=$(HEALTH_SELFTEST_CHILD=1 bash "$gutted" --self-test 2>&1)
    case "$out" in
      *"FAIL"*"C3"*) ok "R1 red-proof: with the swap arm deleted, C3 goes red" ;;
      *) bad "R1 red-proof did not bite — gutted script still passed C3" ;;
    esac
  fi
  rm -f "$gutted"

  # RED PROOF for the fix rules — delete the governor-slot guard from the real
  # file and require F2 to go red there. F1..F6 passing against a build that
  # cannot spare live work would be worthless.
  local gutted2 removed out2 guard
  gutted2="$(mktemp "${TMPDIR:-/tmp}/health-gutted2.XXXXXX")"
  # Assembled with printf so this line is not itself the anchor it deletes.
  guard=$(printf '_holds_slot "$%s" && continue' pid)
  grep -vF "$guard" "${BASH_SOURCE[0]}" > "$gutted2"
  removed=$(( $(wc -l < "${BASH_SOURCE[0]}") - $(wc -l < "$gutted2") ))
  if [ "$removed" -ne 2 ]; then
    bad "R2 could not remove the slot guard (removed ${removed} lines, expected 2) — anchor moved, this checker is blind"
  else
    out2=$(HEALTH_SELFTEST_CHILD=1 bash "$gutted2" --self-test 2>&1)
    case "$out2" in
      *"FAIL"*"F2"*) ok "R2 red-proof: with the slot guard deleted, F2 goes red" ;;
      *) bad "R2 red-proof did not bite — gutted --fix still spared a slot holder" ;;
    esac
  fi
  rm -f "$gutted2"

  # RED PROOF for the descendant walk — delete the one line that promotes a
  # descendant into the live set and require F10 to go red. F10 passing against
  # a build that cannot see a child is worthless. Assembled with printf so this
  # line is not itself the anchor it deletes.
  local gutted3 removed3 out3 guard3
  gutted3="$(mktemp "${TMPDIR:-/tmp}/health-gutted3.XXXXXX")"
  guard3=$(printf 'if (%s[q]) { live[p]=1; break }' seed)
  grep -vF "$guard3" "${BASH_SOURCE[0]}" > "$gutted3"
  removed3=$(( $(wc -l < "${BASH_SOURCE[0]}") - $(wc -l < "$gutted3") ))
  if [ "$removed3" -ne 1 ]; then
    bad "R4 could not remove the descendant walk (removed ${removed3}, expected 1) — anchor moved, this checker is blind"
  else
    out3=$(HEALTH_SELFTEST_CHILD=1 bash "$gutted3" --self-test 2>&1)
    case "$out3" in
      *"FAIL"*"F10"*) ok "R4 red-proof: with the descendant walk deleted, F10 goes red" ;;
      *) bad "R4 red-proof did not bite — a parent-only build still saw the child" ;;
    esac
  fi
  rm -f "$gutted3"

  # RED PROOF for the shared-dev exemption — delete it and require F11 to go
  # red. Signal 1 structurally cannot cover that worktree, so if this guard
  # ever stops being load-bearing the 1851MB dev server is a kill candidate again.
  local gutted4 removed4 out4 guard4
  gutted4="$(mktemp "${TMPDIR:-/tmp}/health-gutted4.XXXXXX")"
  guard4=$(printf '_worktree_is_shared_dev "$%s" && return 0' wt)
  grep -vF "$guard4" "${BASH_SOURCE[0]}" > "$gutted4"
  removed4=$(( $(wc -l < "${BASH_SOURCE[0]}") - $(wc -l < "$gutted4") ))
  if [ "$removed4" -ne 1 ]; then
    bad "R5 could not remove the shared-dev exemption (removed ${removed4}, expected 1) — anchor moved, this checker is blind"
  else
    out4=$(HEALTH_SELFTEST_CHILD=1 bash "$gutted4" --self-test 2>&1)
    case "$out4" in
      *"FAIL"*"F11"*) ok "R5 red-proof: with the exemption deleted, F11 goes red" ;;
      *) bad "R5 red-proof did not bite — the shared dev worktree still read live without it" ;;
    esac
  fi
  rm -f "$gutted4"

  # F8 / R3 — _reap must never signal a process GROUP. Measured 2026-09-15: a
  # negative-pid kill of a shared pgid killed 3 live claude sessions whose
  # tsserver children shared the launching shell's pgid. Static proof this
  # pattern can never silently return, since the runtime proof (spawn a real
  # shared-pgid tree, reap the child, assert the parent survives) needs a real
  # fork this harness cannot safely stage inside a self-test. Excludes THIS
  # comment block and itself from the scan.
  if grep -vE '^\s*#' "${BASH_SOURCE[0]}" | grep -qE 'kill[[:space:]]+-TERM[[:space:]]+-"'; then
    bad "F8 _reap (or something) still signals a process GROUP with -\"\$pgid\""
  else
    ok "F8 nothing in this file signals a process group — only _kill_tree's ppid walk"
  fi

  # _kill_tree must walk descendants (ppid) and never widen beyond them.
  REAPED=""
  pgrep() { case "$1" in -P) case "$2" in 4242) echo 4243 ;; 4243) : ;; esac ;; esac; }
  kill() { REAPED="$REAPED $2"; }
  _kill_tree 4242
  case "$REAPED" in *" 4242"*" 4243"*|*" 4243"*" 4242"*) ok "F9 _kill_tree reaches the target and its real child" ;; *) bad "F9 got: '$REAPED'";; esac
  unset -f pgrep kill 2>/dev/null || true

  if [ $fails -eq 0 ]; then echo "ALL GREEN — the verdict bites and a bad 200 is not UP"; return 0; fi
  echo "RED — $fails check(s) failed"; return 1
}

[ "$SELFTEST" = "1" ] && { self_test; exit $?; }

if [ "${WATCH:-0}" != "0" ]; then
  while :; do clear 2>/dev/null || true; date '+%H:%M:%S'; run_once; sleep "$WATCH"; done
fi
run_once
