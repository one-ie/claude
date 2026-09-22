#!/usr/bin/env bash
# env-sync.sh — localhost bun dev from the dev worktree, on production data.
#
#   bash .claude/scripts/env-sync.sh              # D1 (if idle) + astro
#   bash .claude/scripts/env-sync.sh --astro-only # start :4321, leave D1 alone
#   bash .claude/scripts/env-sync.sh --d1-only    # prod → local mirror, no astro
#
# Geography:
#   Code  — env-sync-local worktree if it exists, else $ROOT/.dev-stable
#   Data  — $ROOT/one.ie/web/.wrangler  (prod D1/KV/R2 mirror; worktree links it)
#   Bind  — 0.0.0.0:4321 so both http://127.0.0.1:4321 and http://localhost:4321 work
#
# Does not kill 8787–8799. Does not start a second `wrangler d1 export`.
# Does not `git reset --hard` a fleet branch — only the detached .dev-stable tree.
set -euo pipefail

ASTRO=1 D1=1
for a in "$@"; do
  case "$a" in
    --astro-only) D1=0 ;;
    --d1-only) ASTRO=0 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    -*) echo "env-sync.sh: unknown flag $a" >&2; exit 2 ;;
  esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Shared checkout, even when this file is invoked from a linked worktree copy.
git_common="$(cd "$here/../.." && git rev-parse --git-common-dir)"
[[ "$git_common" == /* ]] || git_common="$(cd "$here/../.." && cd "$git_common" && pwd)"
ROOT="$(cd "$git_common/.." && pwd)"
# Prefer the env-sync-local worktree while that fleet is alive (has the `ai`
# pin Vite needs when node_modules is a symlink). Else the stable detached tree.
if [[ -z "${DEV_WT:-}" ]]; then
  if [[ -e "$ROOT/.claude/worktrees/env-sync-local/.git" ]]; then
    DEV_WT="$ROOT/.claude/worktrees/env-sync-local"
  else
    DEV_WT="$ROOT/.dev-stable"
  fi
fi
WEB_MAIN="$ROOT/one.ie/web"
WEB_DEV="$DEV_WT/one.ie/web"
HOST="${ASTRO_HOST:-0.0.0.0}"
PORT="${ASTRO_PORT:-4321}"

say() { printf '%s\n' "$*"; }
die() { printf 'env-sync.sh: %s\n' "$*" >&2; exit 1; }

link_file() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || return 0
  if [[ -L "$dest" ]]; then
    local now; now="$(readlink "$dest")"
    [[ "$now" == "$src" ]] && return 0
    rm -f "$dest"
  elif [[ -e "$dest" ]]; then
    return 0
  fi
  ln -s "$src" "$dest"
  say "  linked ${dest#"$DEV_WT/"} → main"
}

link_dir() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || return 0
  if [[ -L "$dest" ]]; then
    local now; now="$(readlink "$dest")"
    [[ "$now" == "$src" ]] && return 0
    rm -f "$dest"
  elif [[ -d "$dest" ]]; then
    mv "$dest" "${dest}.unlinked.$$"
    say "  moved ${dest#"$DEV_WT/"} aside (not production data)"
  fi
  ln -s "$src" "$dest"
  say "  linked ${dest#"$DEV_WT/"} → main"
}

# --- 0. worktree: production data via links ----------------------------------
ensure_dev_worktree() {
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null \
    || die "not a git repo: $ROOT"
  local head; head="$(git -C "$ROOT" rev-parse HEAD)"

  if [[ ! -d "$DEV_WT/.git" && ! -f "$DEV_WT/.git" ]]; then
    say "creating dev worktree $DEV_WT @ $head"
    git -C "$ROOT" worktree add --detach "$DEV_WT" "$head"
  fi

  local here_sha; here_sha="$(git -C "$DEV_WT" rev-parse HEAD)"
  if [[ "$DEV_WT" == "$ROOT/.dev-stable" && "$here_sha" != "$head" ]]; then
    say "fast-forward $DEV_WT $here_sha → $head"
    git -C "$DEV_WT" reset --hard "$head"
  else
    say "dev worktree $DEV_WT @ $here_sha"
  fi

  mkdir -p "$WEB_DEV"
  link_dir  "$WEB_MAIN/.wrangler"              "$WEB_DEV/.wrangler"
  link_dir  "$WEB_MAIN/node_modules"           "$WEB_DEV/node_modules"
  link_dir  "$ROOT/packages/sdk/node_modules"  "$DEV_WT/packages/sdk/node_modules"
  link_file "$WEB_MAIN/.env"                   "$WEB_DEV/.env"
  link_file "$WEB_MAIN/.dev.vars"              "$WEB_DEV/.dev.vars"
  if [[ -f "$WEB_MAIN/src/data/fleets.json" ]]; then
    link_file "$WEB_MAIN/src/data/fleets.json" "$WEB_DEV/src/data/fleets.json"
  fi
}

# --- 1. D1: one export at a time ---------------------------------------------
sync_d1() {
  local pids
  pids="$(pgrep -f 'wrangler d1 export one-owners --remote' || true)"
  if [[ -n "$pids" ]]; then
    say "D1 export already running pid=$pids — not starting a second"
    return 0
  fi
  say "syncing production D1 → $WEB_MAIN/.wrangler"
  ( cd "$WEB_MAIN" && bun run db:sync )
}

# --- 2. astro on 4321 from the worktree --------------------------------------
http_code() {
  curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "$1" 2>/dev/null || echo 000
}

kill_port() {
  local pids
  pids="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  [[ -n "$pids" ]] || return 0
  say "killing listeners on $PORT: $pids"
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true
  sleep 1
  pids="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  [[ -z "$pids" ]] || kill -9 $pids 2>/dev/null || true
}

start_astro() {
  local url_v4="http://127.0.0.1:$PORT"
  if [[ "$(http_code "$url_v4/")" == 200 ]]; then
    say "already 200 $url_v4/"
    return 0
  fi
  kill_port
  mkdir -p "$WEB_DEV/.dev"
  say "starting bun run dev in $WEB_DEV (--host $HOST --port $PORT)"
  (
    cd "$WEB_DEV"
    bun run dev -- --host "$HOST" --port "$PORT"
  ) >"$WEB_DEV/.dev/astro.log" 2>&1 &
  echo $! >"$WEB_DEV/.dev/astro.pid"
  say "  pid=$(cat "$WEB_DEV/.dev/astro.pid") log=$WEB_DEV/.dev/astro.log"

  local i code_root code_voice
  for i in $(seq 1 90); do
    code_root="$(http_code "$url_v4/")"
    code_voice="$(http_code "$url_v4/demo/voice")"
    if [[ "$code_root" == 200 && "$code_voice" == 200 ]]; then
      say "  ✓ $url_v4/          $code_root"
      say "  ✓ $url_v4/demo/voice $code_voice"
      say "  ✓ http://localhost:$PORT/  (same process; bound on $HOST)"
      return 0
    fi
    sleep 2
  done
  say "last 40 lines of $WEB_DEV/.dev/astro.log:"
  tail -n 40 "$WEB_DEV/.dev/astro.log" || true
  die "astro did not reach 200 on $url_v4/ and /demo/voice in 180s (got /=$code_root voice=$code_voice)"
}

ensure_dev_worktree
(( D1 )) && sync_d1
(( ASTRO )) && start_astro
say "done. code=$DEV_WT data=$WEB_MAIN/.wrangler"
