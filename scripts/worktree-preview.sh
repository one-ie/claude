#!/usr/bin/env bash
# worktree-preview.sh — a task's PRIVATE dev server, so the work closes with a link.
#
# manifest: needs-env
#   It names `one.ie/web` (the app whose dev server is previewed) and reads that
#   app's gitignored `.env`. Both degrade: PREVIEW_APP_DIR retargets the app and
#   a missing app dir is a clean refusal, not a crash. Same bucket, same reason,
#   as do-prove.sh — which also names one.ie/web and reads credentials.
#
#   USAGE
#     worktree-preview.sh up   <slug> [--route /path] [--base main] [--port N]
#     worktree-preview.sh down <slug>
#     worktree-preview.sh check <slug|--dir PATH>     the isolation gate
#     worktree-preview.sh list
#     worktree-preview.sh --self-test                 two servers, concurrent
#
#   WHY EVERY LINE OF THIS EXISTS — all measured 2026-09-03 on a 10-core/24GB Mac.
#
#   1. `astro dev` DOES boot in a git worktree. The recorded "astro fails in a
#      worktree" finding is about `astro build` (missing prerender entry), not
#      `dev`:  astro v6.3.7 ready in 7345 ms · GET /factory -> 200 on :4325.
#
#   2. SYMLINKING `node_modules` ITSELF IS FATAL AT TWO SERVERS. Vite WRITES to
#      node_modules/.vite. Two worktree servers sharing one cache killed each
#      other: 4325 -> 000 (process dead), 4326 -> 500, both reporting
#        "The file does not exist at .../node_modules/.vite/deps_ssr/….js?v=<hash>"
#      with TWO DIFFERENT ?v= hashes. That is the desync /kill documents.
#      `.dev-stable` gets away with a whole-dir symlink because it is ONE tree.
#      A factory fans out N. So: symlink the CONTENTS, keep the caches local.
#
#   3. A COLD .vite FLAPS. Three consecutive requests to a fresh worktree gave
#      500, 000, 200 while the dep optimiser churned, then settled and stayed.
#      A preview handed over during the flap shows a human a 500 for work that
#      is fine — hence warm-to-N-CONSECUTIVE-200s, never a single probe.
#
#   4. `.env` must be COPIED IN. `git worktree add` does not carry a gitignored
#      file, and the boot log's "Using secrets defined in .env" is load-bearing.
#
#   5. ALLOCATE PORTS, NEVER SWEEP. /kill's sweep of 4321-4329 also kills
#      neighbour projects (it names apps/one/site on 4322). 4321 is the human's.
#      Teardown kills THIS port only, by recorded pid and by that one port.
#
#   6. NEVER `bun install` INSIDE A WORKTREE — it re-points MAIN's
#      node_modules/@oneie/sdk at the worktree's dist-less SDK and breaks the
#      tree you did not touch. This script never installs. Not once.
#
#   Cost note the governor does not know about: ~128M of .vite PER worktree.
#   gate_headroom prices a cycle at 2GB of MEMORY; preview disk is on top.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/govern.sh"
# shellcheck source=/dev/null
[ -f "$LIB" ] && . "$LIB"

# The source tree is the one that HAS node_modules and .env: the main checkout.
# From any linked worktree, that is the parent of the common git dir.
_common_git="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
DEFAULT_SOURCE="${_common_git:+$(dirname "$_common_git")}"
SOURCE_ROOT="${PREVIEW_SOURCE:-${DEFAULT_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd)}}"
APP_DIR="${PREVIEW_APP_DIR:-one.ie/web}"
WT_DIR="${PREVIEW_WT_DIR:-$SOURCE_ROOT/.do-worktrees}"
BASE_REF="${DO_BASE_REF:-main}"

PORT_MIN="${PREVIEW_PORT_MIN:-4322}"      # 4321 belongs to the human
PORT_MAX="${PREVIEW_PORT_MAX:-4329}"      # /restart reserves 4321-4329 for astro
WARM_TIMEOUT="${PREVIEW_WARM_TIMEOUT:-180}"
WARM_STREAK="${PREVIEW_WARM_STREAK:-3}"   # 3 CONSECUTIVE 200s — see note 3
BOOT_TIMEOUT="${PREVIEW_BOOT_TIMEOUT:-60}"

# node_modules entries that MUST be real local dirs, because something writes
# to them. Sharing any one of these across two servers is defect #2.
LOCAL_CACHE_DIRS=(.vite .vite-temp .astro .cache .mf)

say()  { printf '%s\n' "$*" >&2; }
die()  { printf 'worktree-preview: %s\n' "$*" >&2; exit 2; }

# ---------------------------------------------------------------------------
# node_modules — symlink the CONTENTS, keep the writable caches local.
# ---------------------------------------------------------------------------
link_node_modules() {
  local src="$1" dst="$2" e n=0
  [ -d "$src" ] || die "no node_modules at $src — run bun install in the SOURCE tree, never in a worktree"
  if [ -L "$dst" ]; then
    say "worktree-preview: replacing whole-dir node_modules symlink (defect #2) with per-entry links"
    rm -f "$dst"
  fi
  mkdir -p "$dst"
  while IFS= read -r e; do
    case " ${LOCAL_CACHE_DIRS[*]} " in
      *" $e "*) [ -L "$dst/$e" ] && rm -f "$dst/$e"; mkdir -p "$dst/$e"; continue ;;
    esac
    [ -e "$dst/$e" ] || [ -L "$dst/$e" ] || { ln -s "$src/$e" "$dst/$e" && n=$((n + 1)); }
  done < <(ls -A "$src")
  # The caches must exist even if the source tree never made them.
  for e in "${LOCAL_CACHE_DIRS[@]}"; do mkdir -p "$dst/$e"; done
  echo "$n"
}

# ---------------------------------------------------------------------------
# check — THE GATE. It must be able to go RED, and --self-test proves it does.
# Last line is the verdict; an exit code is not the gate result.
# ---------------------------------------------------------------------------
check_isolation() {
  # NOT `local app="$1" nm="$app/node_modules"` — bash expands every word of a
  # `local` line BEFORE it runs, so `$app` is unbound there and `set -u` kills
  # the whole function. Caught by --self-test: BOTH the green and the red case
  # then "passed", one of them for entirely the wrong reason.
  local app="$1"
  local nm="$app/node_modules" bad=0 e linked

  if [ ! -e "$nm" ]; then
    echo "RED  node_modules missing at $nm"
    echo "worktree-preview check: RED (1 fault)"; return 1
  fi
  if [ -L "$nm" ]; then
    echo "RED  node_modules is a SYMLINK -> $(readlink "$nm")"
    echo "     Vite WRITES to node_modules/.vite. Two worktree servers sharing"
    echo "     one cache desync on the ?v= hash and kill each other (000/500)."
    echo "     Fix: symlink the CONTENTS; keep ${LOCAL_CACHE_DIRS[*]} local."
    bad=$((bad + 1))
  else
    for e in "${LOCAL_CACHE_DIRS[@]}"; do
      if [ -L "$nm/$e" ]; then
        echo "RED  node_modules/$e is a SYMLINK -> $(readlink "$nm/$e") (shared write cache)"
        bad=$((bad + 1))
      elif [ ! -d "$nm/$e" ]; then
        echo "RED  node_modules/$e is not a local directory"
        bad=$((bad + 1))
      fi
    done
    [ -e "$nm/.bin" ] || { echo "RED  node_modules/.bin missing — astro is unreachable"; bad=$((bad + 1)); }
    linked=$(find "$nm" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')
    [ "${linked:-0}" -ge 100 ] || { echo "RED  only ${linked:-0} linked entries — node_modules looks unpopulated"; bad=$((bad + 1)); }
  fi

  [ -f "$app/.env" ] || { echo "RED  .env not copied in (git worktree add does not carry a gitignored file)"; bad=$((bad + 1)); }

  if [ "$bad" -eq 0 ]; then
    echo "worktree-preview check: GREEN ($(find "$nm" -maxdepth 1 -type l | wc -l | tr -d ' ') linked, ${#LOCAL_CACHE_DIRS[@]} local caches, .env present)"
    return 0
  fi
  echo "worktree-preview check: RED ($bad fault$([ "$bad" -gt 1 ] && echo s))"
  return 1
}

# ---------------------------------------------------------------------------
# Ports — ALLOCATE by probing, never sweep. Two independent guards:
#   1. nothing is LISTENing there right now
#   2. an atomic mkdir(2) reservation wins the race against every other caller
#   3. after boot, the SERVER's own log must name the port we asked for
#
# DO NOT use govern.sh's claim_take here, and this is measured, not stylistic.
# claim_take records the owner as `${GOVERN_CLAIM_PID:-$$}` and treats a
# re-claim by the same pid as idempotent success. macOS ships **bash 3.2.57**,
# which has NO `BASHPID` — inside `( … ) &` the variable `$$` is still the
# PARENT's pid. So two concurrent previews forked from one shell present the
# SAME owner, both take the "you already hold it" branch, and both are handed
# the same port. Measured 2026-09-03 by --self-test C:
#
#   worktree-preview up: GREEN  slug=preview-selftest-a port=4322 …
#   worktree-preview up: GREEN  slug=preview-selftest-b port=4322 …
#
# Both then probed 4322 and both saw 200 — from ONE server. A green that
# means nothing. mkdir(2) does not consult $$, so it arbitrates correctly.
# (The same trap applies to any caller that forks claim_take into subshells.)
# ---------------------------------------------------------------------------
# `${PORT_LOCK_DIR:-…}`, not a bare assignment. An unconditional assignment here
# SILENTLY IGNORED an inherited PORT_LOCK_DIR, so --self-test D's "isolated" lock
# dir was never isolated: its racers used the real machine-wide one and inherited
# a reservation left by the previous run, inside the boot grace. 12 racers, 0
# winners — a RED that looked like the arbiter failing when the arbiter was fine.
PORT_LOCK_DIR="${PORT_LOCK_DIR:-${GOVERN_DIR:-${TMPDIR:-/tmp}/one-govern}/preview-ports}"
PORT_BOOT_GRACE="${PREVIEW_PORT_GRACE:-300}"   # a reservation with no pid yet

port_is_free() { ! lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

_port_stamp() { printf 'slug=%s\nstarted=%s\n' "$1" "$(date +%s)" > "$2/meta"; }

# reserve_port <port> <slug> — 0 if it is ours, 1 if someone live holds it.
reserve_port() {
  # Same trap as check_isolation: a `local` line is fully word-expanded BEFORE
  # it runs, so `d="$PORT_LOCK_DIR/$p"` on the same line sees an unbound $p and
  # `set -u` kills the function. Caught by --self-test D: "12 racers produced 0
  # winners". Split every self-referencing local.
  local p="$1" slug="$2"
  local d="$PORT_LOCK_DIR/$p" owner started age dead=1
  mkdir -p "$PORT_LOCK_DIR" 2>/dev/null
  if mkdir "$d" 2>/dev/null; then _port_stamp "$slug" "$d"; return 0; fi

  # Held. Evaporate it only if its server is gone AND the port is really free.
  owner="$(sed -n 's/^pid=//p' "$d/meta" 2>/dev/null | head -1)"
  started="$(sed -n 's/^started=//p' "$d/meta" 2>/dev/null | head -1)"
  if [ -n "$owner" ]; then
    kill -0 "$owner" 2>/dev/null && dead=0
    [ "$dead" = 0 ] && return 1
  else
    # No pid yet: the holder is mid-boot. Give it a grace window, then reap.
    age=$(( $(date +%s) - ${started:-0} ))
    [ "$age" -lt "$PORT_BOOT_GRACE" ] && return 1
  fi
  port_is_free "$p" || return 1
  rm -rf "$d" 2>/dev/null
  mkdir "$d" 2>/dev/null || return 1
  _port_stamp "$slug" "$d"; return 0
}

port_release() { rm -rf "${PORT_LOCK_DIR:?}/${1:?}" 2>/dev/null; return 0; }

# boot_lock — machine-wide, held only while ONE astro dev is coming up. See the
# EADDRINUSE note in cmd_up. mkdir(2) again, and again NOT claim_take: this is
# taken from inside `( … ) &` subshells, where $$ collides. Stale locks reap by
# pid death or age; a lock nobody can acquire must never be able to wedge the
# factory, so the wait is bounded and expiry just takes the ground.
BOOT_LOCK_WAIT="${PREVIEW_BOOT_LOCK_WAIT:-240}"
BOOT_TOKEN=""
boot_lock_take() {
  local d="$PORT_LOCK_DIR/.boot"
  local waited=0 owner started
  # $$ is NOT unique across subshells on bash 3.2, so ownership is a random
  # token; the pid is recorded only so a dead holder can be reaped.
  BOOT_TOKEN="$$-$RANDOM-$RANDOM"
  mkdir -p "$PORT_LOCK_DIR" 2>/dev/null
  while [ "$waited" -lt "$BOOT_LOCK_WAIT" ]; do
    if mkdir "$d" 2>/dev/null; then
      printf 'token=%s\npid=%s\nstarted=%s\n' "$BOOT_TOKEN" "$$" "$(date +%s)" > "$d/meta"
      return 0
    fi
    owner="$(sed -n 's/^pid=//p' "$d/meta" 2>/dev/null | head -1)"
    started="$(sed -n 's/^started=//p' "$d/meta" 2>/dev/null | head -1)"
    if { [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; } \
       || [ $(( $(date +%s) - ${started:-0} )) -gt "$BOOT_LOCK_WAIT" ]; then
      rm -rf "$d" 2>/dev/null; continue
    fi
    [ "$waited" = 0 ] && say "worktree-preview: another preview is booting — queueing (this is a WAIT, not a hang)"
    sleep 1; waited=$((waited + 1))
  done
  BOOT_TOKEN=""
  say "worktree-preview: boot lock not acquired in ${BOOT_LOCK_WAIT}s — booting anyway (inspector port may race)"
  return 0
}
boot_lock_release() {
  local d="$PORT_LOCK_DIR/.boot"
  [ -n "$BOOT_TOKEN" ] || return 0
  [ "$(sed -n 's/^token=//p' "$d/meta" 2>/dev/null | head -1)" = "$BOOT_TOKEN" ] \
    && rm -rf "$d" 2>/dev/null
  BOOT_TOKEN=""
  return 0
}
port_adopt()   { [ -d "$PORT_LOCK_DIR/$1" ] && echo "pid=$2" >> "$PORT_LOCK_DIR/$1/meta"; return 0; }

alloc_port() {
  local slug="$1" p
  for ((p = PORT_MIN; p <= PORT_MAX; p++)); do
    port_is_free "$p" || continue
    reserve_port "$p" "$slug" || continue
    echo "$p"; return 0
  done
  return 1
}

# log_banner_port <astro.log> — the port astro ACTUALLY bound, or empty.
#
# It must match every host form astro prints, and this is measured, not guessed:
# with `--host 127.0.0.1` the banner reads
#
#   ┃ Local    http://127.0.0.1:4323/
#
# NOT `localhost:`. The first version of this grep only matched `localhost:[0-9]+`,
# so it never matched anything — the port-contention check silently never fired
# AND every healthy boot burned the full BOOT_TIMEOUT waiting for a line that
# could not appear. A dead assertion that also costs 60s a boot.
log_banner_port() {
  grep -oE '(localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0):[0-9]+' "$1" 2>/dev/null \
    | head -1 | sed 's/.*://'
}

# ---------------------------------------------------------------------------
# warm — the whole point of this function is that it WAITS.
# A cold .vite gave 500, 000, 200 on three consecutive requests. One 200 proves
# nothing; N CONSECUTIVE 200s proves the optimiser settled. No -L: a 302 to
# /signin is NOT a 200 on the route asked for (the do-prove landing rule).
# Prints "probes=<n> streak_broken=<n> elapsed=<s>" so a caller can see it waited.
# ---------------------------------------------------------------------------
warm_route() {
  local url="$1" timeout="${2:-$WARM_TIMEOUT}" want="${3:-$WARM_STREAK}"
  local t0 deadline streak=0 probes=0 broken=0 code first=""
  t0=$(date +%s); deadline=$((t0 + timeout))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    # `curl … || echo 000` CONCATENATES: on a refused connection curl already
    # printed 000 and then failed, so the variable held "000000" and no branch
    # matched. Normalise instead of appending.
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null)"
    case "$code" in ''|*[!0-9]*) code=000 ;; esac
    [ ${#code} -ne 3 ] && code=000
    probes=$((probes + 1)); [ -z "$first" ] && first="$code"
    if [ "$code" = "200" ]; then
      streak=$((streak + 1))
      if [ "$streak" -ge "$want" ]; then
        echo "probes=$probes first=$first streak_broken=$broken elapsed=$(( $(date +%s) - t0 ))s verdict=GREEN"
        return 0
      fi
    else
      [ "$streak" -gt 0 ] && broken=$((broken + 1))
      streak=0
    fi
    sleep 1
  done
  echo "probes=$probes first=$first streak_broken=$broken elapsed=$(( $(date +%s) - t0 ))s last=$code verdict=RED"
  return 1
}

# ---------------------------------------------------------------------------
# up
# ---------------------------------------------------------------------------
cmd_up() {
  local slug="" route="/factory" port="" base="$BASE_REF"
  slug="${1:-}"; shift || true
  [ -n "$slug" ] || die "up needs a slug"
  while [ $# -gt 0 ]; do
    case "$1" in
      --route) route="$2"; shift 2 ;;
      --port)  port="$2";  shift 2 ;;
      --base)  base="$2";  shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done

  local src_app="$SOURCE_ROOT/$APP_DIR"
  [ -d "$src_app" ] || die "no app at $src_app (set PREVIEW_APP_DIR)"
  local wt="$WT_DIR/$slug" app="$WT_DIR/$slug/$APP_DIR"

  # 1. worktree — attach if it is already there, never clobber
  if [ -d "$wt" ]; then
    say "worktree-preview: reusing worktree $wt"
  else
    mkdir -p "$WT_DIR"
    if git -C "$SOURCE_ROOT" show-ref --verify --quiet "refs/heads/feat/$slug"; then
      git -C "$SOURCE_ROOT" worktree add "$wt" "feat/$slug" >&2 || die "worktree add failed"
    else
      git -C "$SOURCE_ROOT" worktree add -b "feat/$slug" "$wt" "$base" >&2 || die "worktree add failed"
    fi
    # OWNERSHIP. `down` may only remove a worktree THIS script created. Two agents
    # on 2026-09-05 pointed PREVIEW_WT_DIR at their own checkout so `up` would
    # serve it, and `down` then removed the checkout with every uncommitted file
    # in it. The marker is written only on the create path, so an attached
    # (pre-existing) tree is never ours to delete.
    mkdir -p "$wt/$APP_DIR/.preview" && : > "$wt/$APP_DIR/.preview/owned"
  fi
  [ -d "$app" ] || die "worktree has no $APP_DIR"

  # 2. node_modules by CONTENTS + local caches. NEVER an install.
  local n; n="$(link_node_modules "$src_app/node_modules" "$app/node_modules")"
  say "worktree-preview: linked $n entries, ${#LOCAL_CACHE_DIRS[@]} local caches (no install)"

  # 3. .env — git worktree add does not carry a gitignored file, and the boot
  #    log's "Using secrets defined in .env" is load-bearing. Indirected through
  #    ONE_ENV_FILE (DO_ENV_FILE alias) like every other credential-reading
  #    script here, so a collaborator tree can point it elsewhere. We never read
  #    a VALUE out of it — we copy the file — but the path is still theirs.
  local env_src="${ONE_ENV_FILE:-${DO_ENV_FILE:-$src_app/.env}}"
  [ -f "$env_src" ] || die "no .env at $env_src (set ONE_ENV_FILE)"
  cp "$env_src" "$app/.env"
  [ -f "$src_app/.dev.vars" ] && cp "$src_app/.dev.vars" "$app/.dev.vars"

  # 4. the gate, BEFORE we boot anything
  if ! check_isolation "$app"; then
    die "isolation check RED — refusing to boot (see above)"
  fi

  # 5. port
  if [ -n "$port" ]; then
    port_is_free "$port" && reserve_port "$port" "$slug" || die "port $port is already taken"
  else
    port="$(alloc_port "$slug")" || die "no free port in $PORT_MIN-$PORT_MAX (cap is 8 minus whatever a neighbour holds)"
  fi

  # 6. boot, detached into its own process group so a gate-run group-kill or a
  #    dying parent shell does not take the preview with it.
  #
  # SERIALISE THE BOOT — the servers stay concurrent, only their STARTS queue.
  # Measured 2026-09-03 by --self-test C, second defect it caught: `astro dev`
  # here also opens an INSPECTOR socket (miniflare/workerd, default 9229). Two
  # previews launched at the same instant both read 9229 as busy, both fell back
  # to 9231, and one DIED:
  #
  #   [WARN] [vite] Default inspector port 9229 not available, using 9231 instead
  #   Error: listen EADDRINUSE: address already in use 127.0.0.1:9231
  #
  # That port is not settable from the CLI, and its own fallback scan is only
  # unsafe when raced. Holding a machine-wide boot lock until the banner appears
  # lets the second launch see 9231 taken and step to 9233. It costs one boot of
  # latency and removes a crash that reads as "the preview just never came up".
  local state="$app/.preview"; mkdir -p "$state"
  local log="$state/astro.log"; : > "$log"
  local astro="$app/node_modules/.bin/astro"
  [ -x "$astro" ] || astro="npx astro"
  local pid
  boot_lock_take
  if command -v perl >/dev/null 2>&1; then
    ( cd "$app" && perl -e 'setsid; exec @ARGV' -- sh -c "exec $astro dev --port $port --host 127.0.0.1" >>"$log" 2>&1 & echo $! > "$state/pid" )
  else
    ( cd "$app" && nohup sh -c "exec $astro dev --port $port --host 127.0.0.1" >>"$log" 2>&1 & echo $! > "$state/pid" )
  fi
  pid="$(cat "$state/pid" 2>/dev/null)"
  echo "$port" > "$state/port"
  # The reservation now tracks the SERVER's lifetime, so a dead server frees its
  # port with no human in the loop — the leaked `preview:` tag the spec worries
  # about. This is where a real pid finally exists, hence adopt-after-boot.
  port_adopt "$port" "$pid"

  local url="http://localhost:$port$route"
  echo "$url" > "$state/url"

  # 6b. THE SERVER MUST HAVE THE PORT WE ASKED FOR, AND MUST STILL BE ALIVE.
  # `astro dev --port N` is NOT strict: on a busy port Vite increments and boots
  # somewhere else, printing the port it actually took. Two previews handed the
  # same number would then both probe N, both get 200 from ONE server, and the
  # two-server test would go green while proving nothing. Read the boot banner —
  # and watch for the process dying, so an EADDRINUSE is a 10s honest RED rather
  # than a 300s warm timeout that looks like slowness.
  local waited=0 banner="" dead=0
  while [ "$waited" -lt "$BOOT_TIMEOUT" ]; do
    banner="$(log_banner_port "$log")"
    [ -n "$banner" ] && break
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then dead=1; break; fi
    sleep 1; waited=$((waited + 1))
  done
  boot_lock_release
  if [ "$dead" = 1 ]; then
    say "--- last 25 lines of $log ---"; tail -25 "$log" >&2
    cmd_down "$slug" --keep-worktree >&2 || true
    echo "worktree-preview up: RED  slug=$slug port=$port — the server DIED during boot (see log above); port freed, worktree kept at $wt/$APP_DIR/.preview/astro.log.failed"
    return 1
  fi
  if [ -n "$banner" ] && [ "$banner" != "$port" ]; then
    say "worktree-preview: astro bound port $banner, not $port — the port was contended"
    cmd_down "$slug" --keep-worktree >&2 || true
    echo "worktree-preview up: RED  slug=$slug — asked for $port, astro bound $banner (port contention; reservation released)"
    return 1
  fi

  # 7. WARM — do not hand over a URL during the flap.
  say "worktree-preview: warming $url (need $WARM_STREAK consecutive 200s)…"
  local w rc
  w="$(warm_route "$url" "$WARM_TIMEOUT" "$WARM_STREAK")"; rc=$?
  say "worktree-preview: warm $w"
  if [ $rc -ne 0 ]; then
    say "--- last 25 lines of $log ---"; tail -25 "$log" >&2
    # Free the port and kill the server we booted. A RED that leaves a server
    # running and a port claimed makes the next attempt allocate a SECOND port
    # and leaves 128M of .vite behind; the tree is kept for forensics.
    cmd_down "$slug" --keep-worktree >&2 || true
    echo "worktree-preview up: RED  slug=$slug port=$port url=$url ($w) — server killed, port freed, worktree kept at $wt"
    return 1
  fi

  # Record it the way the spec asks the task to carry it.
  echo "tag   preview:$port"
  echo "note  $url"
  echo "worktree-preview up: GREEN  slug=$slug port=$port pid=$pid url=$url ($w)"
  return 0
}

# ---------------------------------------------------------------------------
# down — frees THIS port. Never sweeps the range: /kill's sweep also kills a
# neighbour project's dev server (it names apps/one/site on 4322).
# ---------------------------------------------------------------------------
cmd_down() {
  local slug="${1:-}" keep=0
  [ -n "$slug" ] || die "down needs a slug"
  shift || true
  [ "${1:-}" = "--keep-worktree" ] && keep=1
  local wt="$WT_DIR/$slug" app="$WT_DIR/$slug/$APP_DIR" state="$WT_DIR/$slug/$APP_DIR/.preview"
  local port="" pid=""
  [ -f "$state/port" ] && port="$(cat "$state/port")"
  [ -f "$state/pid" ]  && pid="$(cat "$state/pid")"

  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    sleep 1
    kill -0 "$pid" 2>/dev/null && { kill -9 -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true; }
  fi
  if [ -n "$port" ]; then
    local victim
    while IFS= read -r victim; do
      [ -n "$victim" ] && kill -9 "$victim" 2>/dev/null
    done < <(lsof -ti:"$port" 2>/dev/null)
    port_release "$port"
  fi
  # Keeping the worktree "for forensics" while deleting the ONLY artifact that
  # says why it failed is not forensics. On the --keep-worktree path preserve
  # astro.log; drop only the live-state files. (Measured: when a preview died on
  # EADDRINUSE the log was gone and the failure had to be reconstructed from the
  # caller's captured stderr.)
  # Read the ownership marker BEFORE the state dir is cleared — it lives there.
  local owned=0; [ -f "$state/owned" ] && owned=1
  if [ "$keep" -eq 1 ] && [ -f "$state/astro.log" ]; then
    mv "$state/astro.log" "$state/astro.log.failed" 2>/dev/null || true
    rm -f "$state/pid" "$state/port" "$state/url" 2>/dev/null || true
  else
    rm -rf "$state" 2>/dev/null || true
  fi

  if [ "$keep" -eq 0 ] && [ -d "$wt" ]; then
    if [ "$owned" -eq 1 ]; then
      git -C "$SOURCE_ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
      git -C "$SOURCE_ROOT" worktree prune >/dev/null 2>&1 || true
    else
      say "worktree-preview down: worktree KEPT at $wt — not created by this script (no .preview/owned marker), so it is not ours to remove"
    fi
  fi
  local still="bound"; [ -z "$port" ] && still="n/a"
  [ -n "$port" ] && { port_is_free "$port" && still="free"; }
  echo "worktree-preview down: GREEN  slug=$slug port=${port:-none} port_now=$still worktree=$([ -d "$wt" ] && echo kept || echo removed)"
}

cmd_list() {
  local wt slug d port url alive
  printf '%-28s %-6s %-6s %s\n' SLUG PORT STATE URL
  for wt in "$WT_DIR"/*; do
    [ -d "$wt" ] || continue
    d="$wt/$APP_DIR/.preview"; [ -d "$d" ] || continue
    slug="$(basename "$wt")"
    port="$(cat "$d/port" 2>/dev/null)"; url="$(cat "$d/url" 2>/dev/null)"
    alive=down; [ -n "$port" ] && { port_is_free "$port" || alive=up; }
    printf '%-28s %-6s %-6s %s\n' "$slug" "${port:-?}" "$alive" "${url:-?}"
  done
}

# ---------------------------------------------------------------------------
# --self-test
#
#   A. the warm loop actually WAITS            (stub servers, no astro)
#   B. the isolation gate goes RED on the shared-cache arrangement
#   C. TWO previews, concurrent, both 200      (the whole point)
#
# A one-server test is exactly what missed the defect the first time.
# ---------------------------------------------------------------------------
ST_FAIL=0
st_ok()   { printf '  ok   %s\n' "$*"; }
st_fail() { printf '  FAIL %s\n' "$*" >&2; ST_FAIL=$((ST_FAIL + 1)); }
st_head() { printf '\n== %s\n' "$*"; }

# A stub HTTP server whose status codes are scripted: "<prefix>|<cycle>".
#   "500,500|200"   -> 500, 500, then 200 forever          (a cold cache settling)
#   "|200,500"      -> 200,500,200,500 forever             (a flap that never settles)
# Kill a stub without bash's "Terminated: 15" job notification landing on stdout.
st_stub_kill() {
  [ -n "${1:-}" ] || return 0
  kill "$1" 2>/dev/null
  wait "$1" 2>/dev/null
  return 0
}

st_stub() {
  local port="$1" pattern="$2" pidfile="$3"
  node -e '
    const http = require("http");
    const [pre, cyc] = process.argv[2].split("|");
    const prefix = pre ? pre.split(",").map(Number) : [];
    const cycle  = cyc ? cyc.split(",").map(Number) : [200];
    let i = 0;
    http.createServer((req, res) => {
      const c = i < prefix.length ? prefix[i] : cycle[(i - prefix.length) % cycle.length];
      i++;
      res.writeHead(c, { "content-type": "text/plain" });
      res.end(String(c));
    }).listen(parseInt(process.argv[1]), "127.0.0.1");
  ' "$port" "$pattern" &
  echo $! > "$pidfile"
  local t=0
  while [ $t -lt 60 ]; do port_is_free "$port" || return 0; sleep 0.1; t=$((t + 1)); done
  return 1
}

self_test() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/wtpreview-selftest.XXXXXX")"
  trap 'rm -rf "$tmp"' RETURN

  # ---------------------------------------------------------------- A. warm
  st_head "A — the warm loop WAITS (a cold .vite gave 500, 000, 200)"
  local sp=4399 out rc naive
  st_stub "$sp" "500,500|200" "$tmp/stub1.pid" || { st_fail "stub server did not bind"; return 1; }
  naive="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$sp/")"
  [ "$naive" = "500" ] && st_ok "a naive SINGLE probe sees $naive — this is what a human would have been handed" \
                       || st_fail "expected the first probe to be 500, got $naive"
  out="$(warm_route "http://127.0.0.1:$sp/" 30 3)"; rc=$?
  if [ $rc -eq 0 ] && grep -q 'verdict=GREEN' <<<"$out"; then
    st_ok "warm_route waited through the flap and returned GREEN: $out"
    # It CANNOT have returned on the first probe: the stub served 500 first.
    # >= streak+1 probes is the arithmetic proof that it waited.
    grep -qE 'probes=([4-9]|[1-9][0-9])' <<<"$out" && grep -q 'first=500' <<<"$out" \
      && st_ok "it needed >=4 probes and its FIRST was 500 — it waited, it did not get lucky" \
      || st_fail "warm returned too early: $out"
  else
    st_fail "warm_route should have settled: $out"
  fi
  st_stub_kill "$(cat "$tmp/stub1.pid")"

  st_head "A(red) — a route that NEVER settles must NOT pass"
  sp=4398
  st_stub "$sp" "|200,500" "$tmp/stub2.pid" || { st_fail "stub server did not bind"; return 1; }
  out="$(warm_route "http://127.0.0.1:$sp/" 8 3)"; rc=$?
  if [ $rc -ne 0 ] && grep -q 'verdict=RED' <<<"$out"; then
    st_ok "RED as required — a lucky 200 in an alternating flap does not pass: $out"
    grep -q 'streak_broken=[1-9]' <<<"$out" && st_ok "and it SAW the streak break (streak_broken>0)" \
      || st_fail "expected streak_broken>0: $out"
  else
    st_fail "flapping route passed the warm gate — the streak rule is not enforced: $out"
  fi
  st_stub_kill "$(cat "$tmp/stub2.pid")"

  # ------------------------------------------------------- B. isolation gate
  st_head "B — the isolation gate goes RED on the shared-cache arrangement"
  local shared="$tmp/shared_nm"; mkdir -p "$shared/.bin" "$shared/.vite"
  local i; for i in $(seq 1 120); do mkdir -p "$shared/pkg$i"; done

  local good="$tmp/good"; mkdir -p "$good"; : > "$good/.env"
  link_node_modules "$shared" "$good/node_modules" >/dev/null
  if out="$(check_isolation "$good")"; then
    st_ok "contents-linked tree is GREEN: $(tail -1 <<<"$out")"
  else
    st_fail "the GOOD arrangement went red:"; sed 's/^/       /' <<<"$out" >&2
  fi

  local bad="$tmp/bad"; mkdir -p "$bad"; : > "$bad/.env"
  ln -s "$shared" "$bad/node_modules"       # the FATAL arrangement, forced
  if out="$(check_isolation "$bad")"; then
    st_fail "shared-cache arrangement passed the gate — the checker cannot go red"
  else
    st_ok "RED as required. Verbatim:"; sed 's/^/       | /' <<<"$out"
  fi

  local half="$tmp/half"; mkdir -p "$half"; : > "$half/.env"
  link_node_modules "$shared" "$half/node_modules" >/dev/null
  rm -rf "$half/node_modules/.vite"; ln -s "$shared/.vite" "$half/node_modules/.vite"
  if check_isolation "$half" >/dev/null; then
    st_fail "a shared .vite INSIDE a real node_modules passed — the subtler half is unguarded"
  else
    st_ok "RED on a shared .vite inside an otherwise-local node_modules"
  fi

  # ------------------------------------------------- C. TWO REAL PREVIEWS
  if [ "${PREVIEW_SELFTEST_SERVERS:-1}" != "1" ]; then
    st_head "C — SKIPPED (PREVIEW_SELFTEST_SERVERS=0). This is the whole point; do not skip it in CI."
  else
    st_head "C — two previews, concurrent, both 200 (a one-server test missed this defect)"
    local A=preview-selftest-a B=preview-selftest-b
    # WT_DIR is computed ONCE at load; a `PREVIEW_WT_DIR=… cmd_up` prefix sets
    # the env var but not the already-assigned shell variable, so the first run
    # of this test silently built its worktrees in the SHARED .do-worktrees.
    # Assign the real variable.
    local saved_wt="$WT_DIR"; WT_DIR="$tmp/wt"
    cmd_down "$A" >/dev/null 2>&1 || true
    cmd_down "$B" >/dev/null 2>&1 || true
    git -C "$SOURCE_ROOT" branch -D "feat/$A" >/dev/null 2>&1 || true
    git -C "$SOURCE_ROOT" branch -D "feat/$B" >/dev/null 2>&1 || true
    git -C "$SOURCE_ROOT" worktree prune >/dev/null 2>&1 || true

    local base="${PREVIEW_SELFTEST_BASE:-$(git rev-parse HEAD)}"
    local ra rb
    ( cmd_up "$A" --route "${PREVIEW_SELFTEST_ROUTE:-/factory}" --base "$base" > "$tmp/a.out" 2>"$tmp/a.err" ) &
    local pa=$!
    ( cmd_up "$B" --route "${PREVIEW_SELFTEST_ROUTE:-/factory}" --base "$base" > "$tmp/b.out" 2>"$tmp/b.err" ) &
    local pb=$!
    wait $pa; ra=$?
    wait $pb; rb=$?

    printf '  --- A ---\n'; sed 's/^/  | /' "$tmp/a.out"
    printf '  --- B ---\n'; sed 's/^/  | /' "$tmp/b.out"
    [ $ra -eq 0 ] && st_ok "preview A: $(tail -1 "$tmp/a.out")" || { st_fail "preview A did not come up"; tail -20 "$tmp/a.err" | sed 's/^/       /' >&2; }
    [ $rb -eq 0 ] && st_ok "preview B: $(tail -1 "$tmp/b.out")" || { st_fail "preview B did not come up"; tail -20 "$tmp/b.err" | sed 's/^/       /' >&2; }

    local pA pB
    pA="$(cat "$tmp/wt/$A/$APP_DIR/.preview/port" 2>/dev/null)"
    pB="$(cat "$tmp/wt/$B/$APP_DIR/.preview/port" 2>/dev/null)"
    [ -n "$pA" ] && [ -n "$pB" ] && [ "$pA" != "$pB" ] && st_ok "distinct ports: A=$pA B=$pB (allocated, not swept)" \
      || st_fail "ports collided or were not recorded: A=${pA:-none} B=${pB:-none}"

    # The real defect was a SHARED .vite. Prove each server wrote its OWN.
    # `find` FOLLOWS a symlinked .vite into main's populated cache, so a
    # non-zero count alone is satisfied by the very arrangement under test —
    # assert the dirs are real AND that the two caches are not the same inode.
    local nmA="$tmp/wt/$A/$APP_DIR/node_modules" nmB="$tmp/wt/$B/$APP_DIR/node_modules"
    local vA vB iA iB
    vA="$(find "$nmA/.vite" -type f 2>/dev/null | wc -l | tr -d ' ')"
    vB="$(find "$nmB/.vite" -type f 2>/dev/null | wc -l | tr -d ' ')"
    iA="$(stat -f '%d:%i' "$nmA/.vite" 2>/dev/null)"
    iB="$(stat -f '%d:%i' "$nmB/.vite" 2>/dev/null)"
    if [ ! -L "$nmA/.vite" ] && [ ! -L "$nmB/.vite" ] && [ -n "$iA" ] && [ "$iA" != "$iB" ] \
       && [ "${vA:-0}" -gt 0 ] && [ "${vB:-0}" -gt 0 ]; then
      st_ok "each server wrote its OWN .vite — distinct inodes ($iA vs $iB), A=$vA files, B=$vB files"
    else
      st_fail "the two .vite caches are not independent: symlinkA=$([ -L "$nmA/.vite" ] && echo yes || echo no) symlinkB=$([ -L "$nmB/.vite" ] && echo yes || echo no) inodes=$iA/$iB files=${vA:-0}/${vB:-0}"
    fi

    # The worktree keeps its own .wrangler — local D1/KV/R2 per tree, so a
    # preview cannot corrupt the human's database. Observed, then asserted.
    local wA="$tmp/wt/$A/$APP_DIR/.wrangler" wB="$tmp/wt/$B/$APP_DIR/.wrangler"
    if [ -d "$wA" ] && [ ! -L "$wA" ] && [ -d "$wB" ] && [ ! -L "$wB" ]; then
      st_ok "each worktree has its OWN real .wrangler (local D1/KV/R2 is per-tree)"
    elif [ ! -e "$wA" ] && [ ! -e "$wB" ]; then
      st_ok "no .wrangler in either worktree — astro dev never created one, so there is nothing shared to corrupt"
    else
      st_fail ".wrangler is not per-tree: A=$([ -L "$wA" ] && echo symlink || ([ -d "$wA" ] && echo dir || echo absent)) B=$([ -L "$wB" ] && echo symlink || ([ -d "$wB" ] && echo dir || echo absent))"
    fi

    # Both still serving AFTER the other has been up. The measured desync
    # appeared on the SECOND and THIRD request while both were serving
    # (4325 -> 000, 4326 -> 500), so probe INTERLEAVED, three times each —
    # one probe apiece only proves each answered once after boot.
    local uA uB k cA cB okA=1 okB=1 seqA="" seqB=""
    uA="$(cat "$tmp/wt/$A/$APP_DIR/.preview/url" 2>/dev/null)"
    uB="$(cat "$tmp/wt/$B/$APP_DIR/.preview/url" 2>/dev/null)"
    for k in 1 2 3; do
      cA="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$uA" 2>/dev/null)"; [ ${#cA} -ne 3 ] && cA=000
      cB="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$uB" 2>/dev/null)"; [ ${#cB} -ne 3 ] && cB=000
      seqA="$seqA $cA"; seqB="$seqB $cB"
      [ "$cA" = "200" ] || okA=0
      [ "$cB" = "200" ] || okB=0
    done
    [ "$okA" = 1 ] && [ "$okB" = 1 ] \
      && st_ok "both STILL 200 under interleaved traffic — A:$seqA  B:$seqB" \
      || st_fail "concurrent servers interfered — A:$seqA  B:$seqB (the shared-cache signature is 000 and 500)"

    cmd_down "$A" | sed 's/^/  /'
    cmd_down "$B" | sed 's/^/  /'
    [ -n "$pA" ] && { port_is_free "$pA" && st_ok "teardown freed port $pA" || st_fail "port $pA still bound after down"; }
    [ -n "$pB" ] && { port_is_free "$pB" && st_ok "teardown freed port $pB" || st_fail "port $pB still bound after down"; }
    git -C "$SOURCE_ROOT" branch -D "feat/$A" >/dev/null 2>&1 || true
    git -C "$SOURCE_ROOT" branch -D "feat/$B" >/dev/null 2>&1 || true
    git -C "$SOURCE_ROOT" worktree prune >/dev/null 2>&1 || true
    port_release "${pA:-0}"; port_release "${pB:-0}"
    WT_DIR="$saved_wt"
  fi

  # ----------------------------------------------- D. the port arbiter
  # This section exists because C caught the real thing: both previews were
  # handed 4322. Guard the fix, and keep the reason for it honest.
  st_head "D — the port arbiter gives exactly one winner"
  local saved_lock="$PORT_LOCK_DIR"
  PORT_LOCK_DIR="$tmp/ports"; export PORT_LOCK_DIR
  local i wins
  : > "$tmp/race.out"
  for i in $(seq 1 12); do
    ( PORT_LOCK_DIR="$tmp/ports" bash "$0" __reserve 65000 "racer$i" >/dev/null 2>&1 \
        && echo win >> "$tmp/race.out" ) &
  done
  wait
  wins="$(grep -c win "$tmp/race.out" 2>/dev/null | tr -d ' ')"
  # Assert the ISOLATION before the count. A racer that wrote to the real
  # machine-wide dir would be racing whatever the last run left there, and a
  # 0-winner result would look like a broken arbiter instead of a leaky test.
  [ -d "$tmp/ports/65000" ] \
    && st_ok "the racers used the ISOLATED lock dir (PORT_LOCK_DIR was honoured, not overwritten)" \
    || st_fail "no reservation under $tmp/ports — PORT_LOCK_DIR was ignored, so this race was run against shared state"
  [ "${wins:-0}" = "1" ] && st_ok "12 independent racers, exactly $wins winner (mkdir(2) is the arbiter)" \
    || st_fail "12 racers produced ${wins:-0} winners — the port arbiter does not exclude"

  st_head "D(red) — WHY claim_take is not used here: it double-grants across subshells"
  if declare -F claim_take >/dev/null 2>&1; then
    local before after
    GOVERN_CLAIMS_DIR="$tmp/claims"; export GOVERN_CLAIMS_DIR
    mkdir -p "$GOVERN_CLAIMS_DIR"
    : > "$tmp/claim.out"
    ( claim_take "wtpreview-selftest-region" one >/dev/null 2>&1 && echo win >> "$tmp/claim.out" ) &
    ( claim_take "wtpreview-selftest-region" two >/dev/null 2>&1 && echo win >> "$tmp/claim.out" ) &
    wait
    after="$(grep -c win "$tmp/claim.out" 2>/dev/null | tr -d ' ')"
    if [ "${after:-0}" -ge 2 ]; then
      st_ok "confirmed: claim_take granted the SAME region to $after subshells of one shell."
      st_ok "  bash $BASH_VERSION has no BASHPID, so \$\$ is identical in both — this is the"
      st_ok "  measured cause of 'A port=4322 / B port=4322'. Hence reserve_port."
    else
      st_fail "claim_take no longer double-grants ($after winner) — the note above reserve_port is STALE, re-check whether govern.sh can arbitrate here"
    fi
    unset GOVERN_CLAIMS_DIR
  else
    st_fail "govern.sh not loaded — cannot demonstrate the claim_take trap"
  fi
  PORT_LOCK_DIR="$saved_lock"

  # ------------------------------------- E. the boot banner is READ, not assumed
  # A check that cannot match anything is decoration. This one shipped dead: the
  # grep looked for `localhost:` and astro prints `127.0.0.1:` under --host.
  st_head "E — log_banner_port reads the port astro ACTUALLY bound"
  local L="$tmp/banner.log" got
  printf '%s\n' '18:03:40 [WARN] [vite] Default inspector port 9229 not available, using 9231 instead' \
                '┃ Local    http://127.0.0.1:4323/' > "$L"
  got="$(log_banner_port "$L")"
  [ "$got" = "4323" ] && st_ok "the REAL banner form (--host 127.0.0.1) parses to $got" \
    || st_fail "the real banner form parsed to '${got:-empty}', expected 4323 — the check is dead again"

  printf '%s\n' '┃ Local    http://localhost:4327/' > "$L"
  got="$(log_banner_port "$L")"
  [ "$got" = "4327" ] && st_ok "the localhost form parses to $got" \
    || st_fail "localhost form parsed to '${got:-empty}'"

  st_head "E(red) — a server that took a DIFFERENT port must be caught"
  printf '%s\n' '┃ Local    http://127.0.0.1:4399/' > "$L"
  got="$(log_banner_port "$L")"
  if [ -n "$got" ] && [ "$got" != "4322" ]; then
    st_ok "RED as required: asked for 4322, the log says the server bound $got — cmd_up refuses and tears down"
  else
    st_fail "a mismatched banner was not detected (parsed '${got:-empty}') — a second preview could silently probe the first server's port"
  fi
  printf '%s\n' 'no banner here at all' > "$L"
  [ -z "$(log_banner_port "$L")" ] && st_ok "a log with no banner yields empty, so the boot loop keeps waiting rather than passing" \
    || st_fail "a bannerless log produced a port"

  # ------------------------------- F. the RED path's side effects are REAL
  # cmd_up's failure line promises three things: the server is killed, the port
  # is freed, and the worktree is kept WITH its log. Those were only ever
  # verified by reading the code — and one of them was false: `rm -rf "$state"`
  # deleted the very astro.log the message called forensics. Drive it.
  st_head "F — a RED teardown frees the port and KEEPS the log"
  local fslug=preview-selftest-red fwt="$tmp/redwt" fapp
  fapp="$fwt/$fslug/$APP_DIR"
  mkdir -p "$fapp/.preview"
  printf 'Error: listen EADDRINUSE: address already in use 127.0.0.1:9231\n' > "$fapp/.preview/astro.log"
  echo 999999 > "$fapp/.preview/pid"      # a pid that is not alive
  echo 65001  > "$fapp/.preview/port"
  echo "http://localhost:65001/x" > "$fapp/.preview/url"
  PORT_LOCK_DIR="$tmp/ports"; export PORT_LOCK_DIR
  reserve_port 65001 "$fslug" >/dev/null 2>&1
  [ -d "$tmp/ports/65001" ] && st_ok "reservation for 65001 exists before teardown" \
    || st_fail "could not set up the reservation fixture"

  local saved2="$WT_DIR"; WT_DIR="$fwt"
  cmd_down "$fslug" --keep-worktree > "$tmp/red-down.out" 2>&1
  WT_DIR="$saved2"

  [ -f "$fapp/.preview/astro.log.failed" ] \
    && st_ok "the log SURVIVED as astro.log.failed — the RED is actually diagnosable" \
    || st_fail "astro.log.failed is missing: a RED that keeps the worktree but deletes the log is not forensics"
  grep -q EADDRINUSE "$fapp/.preview/astro.log.failed" 2>/dev/null \
    && st_ok "and it still carries the failure reason verbatim" \
    || st_fail "the kept log lost its content"
  { [ ! -f "$fapp/.preview/pid" ] && [ ! -f "$fapp/.preview/port" ] && [ ! -f "$fapp/.preview/url" ]; } \
    && st_ok "the live-state files (pid/port/url) are gone, so nothing reads a dead preview as up" \
    || st_fail "stale live-state survived the teardown"
  [ ! -d "$tmp/ports/65001" ] \
    && st_ok "the port reservation was released — the next allocator can take 65001" \
    || st_fail "the port reservation LEAKED; the range would shrink by one every failure"
  [ -d "$fwt/$fslug" ] && st_ok "the worktree itself was kept, as the message claims" \
    || st_fail "--keep-worktree removed the tree"
  PORT_LOCK_DIR="$saved_lock"

  printf '\n'
  if [ "$ST_FAIL" -eq 0 ]; then
    echo "worktree-preview --self-test: GREEN (0 failures)"; return 0
  fi
  echo "worktree-preview --self-test: RED ($ST_FAIL failures)"; return 1
}

# ---------------------------------------------------------------------------
case "${1:---help}" in
  up)     shift; cmd_up "$@" ;;
  down)   shift; cmd_down "$@" ;;
  list)   shift; cmd_list "$@" ;;
  check)
    shift
    if [ "${1:-}" = "--dir" ]; then check_isolation "$2";
    else check_isolation "$WT_DIR/${1:?check needs a slug}/$APP_DIR"; fi ;;
  --self-test)
    # A heavy gate goes through the governor. gate-run.sh exports
    # GOVERN_IN_GATE=1, so this re-exec cannot recurse.
    if [ "${GOVERN_IN_GATE:-0}" != "1" ] && [ -x "$SCRIPT_DIR/gate-run.sh" ]; then
      exec "$SCRIPT_DIR/gate-run.sh" worktree-preview-selftest -- "$0" --self-test
    fi
    self_test ;;
  __reserve)  # internal — one fresh process taking one port, for --self-test D
    shift; reserve_port "${1:?port}" "${2:-racer}" ;;
  -h|--help|help)
    sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command: $1" ;;
esac
