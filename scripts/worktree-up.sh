#!/bin/bash
# worktree-up.sh — a worktree with a WORKING dev environment, in one command.
#
# manifest: monorepo-only
#
# The locked loop (one-ie/CLAUDE.md § The dev → prod loop) says every session
# edits in `.claude/worktrees/<name>` and main only receives merges. A bare
# `git worktree add` gives you a tree that cannot run: git omits gitignored
# dirs, so there is no node_modules, no .env, no miniflare state.
#
# THE FIX, in three parts, the first two of which are both required:
#   1. symlink every gitignored path from main, EXCEPT node_modules/.vite
#   2. give the worktree its OWN .vite, SEEDED WARM by cloning main's
#   3. GENERATE the gitignored JSON that src IMPORTS (`_link_deps` tail) — a
#      linked tree still fails `bunx tsc --noEmit` without it, on two files
#      nobody edited. Git omits generated output the same way it omits deps.
#
# Neither half works alone, and that is why this took six attempts to pin down:
#   * share main's .vite (what a wholesale `ln -s node_modules` does) and two
#     dev servers write one esbuild optimiser cache. The bundles corrupt and
#     every SSR route 500s with "module is not defined" at
#     workers/runner-worker/index.js. It reads like module resolution. It is not.
#   * give it its own EMPTY .vite and you trade corruption for a cold start:
#     vite discovers deps incrementally and reloads the workerd runner after each
#     batch ("✨ optimized dependencies changed. reloading"), and every request
#     landing mid-teardown 500s with the SAME message. It does not settle.
# Own + warm is the only combination that serves.
#
# MEASURED 2026-09-05, main's dev server deliberately RUNNING so the contention
# was present: worktree :4322 /u/one = 200 and main :4321 /u/one = 200, both, 24s.
#
# ── DO NOT `bun install` HERE ──────────────────────────────────────────────
# It re-points MAIN's one.ie/web/node_modules/@oneie/sdk at this worktree's
# dist-less copy and breaks the main checkout. That is why deps are linked.
#
# ── WHY .env AND .dev.vars ARE LINKS, NOT COPIES ──────────────────────────
# A rotated key then reaches every live worktree at once instead of going stale
# in N copies. (They disagree today and the WORKER reads .dev.vars, not .env —
# see project_local_gateway_8787_is_the_substrate_door.)
#
# ── FOUR THINGS THAT ARE NOT THE PROBLEM, EACH MEASURED ───────────────────
# Do not re-run these:
#   * vite.resolve.preserveSymlinks (deps resolving outside the root as CJS)
#   * bypassing `bun run dev`s codegen — real, fixed below, but not this bug
#   * an empty .wrangler/.astro (no miniflare D1 state)
#   * "something was editing the worktree" — a CLEAN worktree failed identically
#
# ── THE METHOD LESSON, which is the reusable part ─────────────────────────
# Five of those six wrong answers came from changing one thing and reading the
# result while OTHER variables moved underneath. Main's dev server going up and
# down between runs is what made a passing control look like proof: it passed
# because main was DOWN and the worktree had the shared cache to itself. Hold
# the rest still, and say which state you held it in.
#
# Usage:
#   bash .claude/scripts/worktree-up.sh <name> [--port N] [--no-dev] [--base REF]
#   bash .claude/scripts/worktree-up.sh <name> --check   # is it really serving?
#   bash .claude/scripts/worktree-up.sh <name> --down
#   bash .claude/scripts/worktree-up.sh --self-test      # prove READY can go red
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Branches are cut from `dev`, not main: dev is the integration branch every
# branch lands into, so a branch cut from main starts life missing whatever
# dev has already integrated. `--base main` still does the old thing.
NAME=""; PORT=""; BASE="dev"; MODE="up"

while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="${2:-}"; shift 2 ;;
    --base) BASE="${2:-dev}"; shift 2 ;;
    --no-dev) MODE="setup"; shift ;;
    --check) MODE="check"; shift ;;
    --down) MODE="down"; shift ;;
    --self-test) MODE="selftest"; shift ;;
    -*) echo "worktree-up: unknown flag $1" >&2; exit 2 ;;
    *) NAME="$1"; shift ;;
  esac
done

WT="$ROOT/.claude/worktrees/$NAME"
_say() { echo "[worktree-up] $*"; }
_port_file() { echo "$WT/.worktree-port"; }

# Every gitignored path the dev env needs. Wholesale symlinks — a per-package
# farm was tried and bought nothing.
# one.ie/web/node_modules is deliberately ABSENT here — it is built below as a
# farm of per-package links so that .vite can be worktree-local. A wholesale
# symlink would drag main's .vite in with it, which is the corruption above.
# api/.dev.vars was MISSING from this list until 2026-09-15, and its absence does
# not read as an absence: the gateway starts, answers 401, and the seven
# real-TypeDB suites die in mustWrite at fixture setup — so the typedb lane reads
# as a broken key or a flaky substrate rather than as an unlinked file. It holds
# GATEWAY_API_KEY and the four TYPEDB_* vars; without it that lane cannot run at all.
# api/ and sync/ were MISSING until 2026-09-17, and their absence does not read as
# an absence either: `deploy.sh` typechecks all five services (:181-182), so both
# died on `TS2688: Cannot find type definition file for '@cloudflare/workers-types'`
# — a TypeScript error naming TypeScript, caused by an unlinked directory. Measured
# that day at the ship gate: two of five typechecks red at t≈290s, in a tree whose
# code was fine, in all four existing worktrees at once.
LINKS="node_modules
packages/node_modules
api/node_modules
sync/node_modules
packages/sdk/dist
packages/sdk/node_modules
pay/backend/node_modules
channels/node_modules
one.ie/web/.env
one.ie/web/.dev.vars
one.ie/web/.wrangler
one.ie/web/.astro
one.ie/web/src/data/fleets.json
pay/backend/.env
channels/.env
api/.dev.vars"

# Ports are ALLOCATED, never assumed: several worktrees run at once, and a
# hardcoded port is how two of them come to think they serve each other's code.
# 4322+ keeps main's 4321 uncontended.
_free_port() {
  local p=4322
  while lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; do p=$((p+1)); done
  echo "$p"
}

_link_deps() {
  local d n=0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ -e "$ROOT/$d" ] && [ ! -e "$WT/$d" ]; then
      mkdir -p "$WT/$(dirname "$d")"
      ln -s "$ROOT/$d" "$WT/$d" 2>/dev/null && n=$((n+1))
    fi
  done <<< "$LINKS"
  _say "linked $n gitignored path(s) from main"

  # The web package's node_modules is a REAL directory of per-package symlinks.
  # This is the only shape that shares every dependency with main while keeping
  # .vite local — see the header.
  local web="$WT/one.ie/web" mainweb="$ROOT/one.ie/web" e b p=0
  if [ ! -d "$web/node_modules" ] || [ -L "$web/node_modules" ]; then
    rm -f "$web/node_modules" 2>/dev/null
    mkdir -p "$web/node_modules"
    for e in "$mainweb"/node_modules/* "$mainweb"/node_modules/.[!.]*; do
      [ -e "$e" ] || continue
      b="$(basename "$e")"
      [ "$b" = ".vite" ] && continue
      ln -s "$e" "$web/node_modules/$b" 2>/dev/null && p=$((p+1))
    done
    _say "one.ie/web/node_modules: $p package links (.vite kept local)"
  fi

  # Seed the optimiser cache WARM. An empty one is not a neutral start — it is
  # the reload storm. `cp -c` is APFS clonefile: copy-on-write, near free.
  if [ -d "$mainweb/node_modules/.vite" ]; then
    rm -rf "$web/node_modules/.vite"
    cp -Rc "$mainweb/node_modules/.vite" "$web/node_modules/.vite" 2>/dev/null \
      || cp -R "$mainweb/node_modules/.vite" "$web/node_modules/.vite"
    _say "seeded .vite warm from main"
  else
    _say "WARNING: main has no .vite to clone. Run main's dev server once and"
    _say "  let it settle, or this worktree will 500 through the reload storm."
  fi

  # ── MINT THE GITIGNORED MODULES tsc RESOLVES AS MODULES ───────────────────
  # A fresh cut is missing two generated-but-gitignored JSON files that src
  # IMPORTS, so `bunx tsc --noEmit` reads RED on code in nobody's diff:
  #   src/data/promises.json            <- src/pages/api/goals/spine.ts:2
  #   src/lib/generated/page-modified.json <- src/lib/page-directory.ts:1
  # Measured 2026-09-21 on a fresh cut from dev: exactly those two TS2307s, rc=2.
  #
  # CUT TIME owns this, not verify:fast. A builder's first command is a bare
  # `bunx tsc --noEmit`, which never runs a gate -- so a generate living in
  # verify-fast.sh cannot make a fresh worktree typecheck clean, only its own
  # second run. This is a setup gap, the same family as an unlinked
  # node_modules, and it is paid once per cut instead of once per gate.
  # verify-fast.sh is deliberately left byte-untouched: ONE door, not two.
  #
  # ORDER: this must run AFTER the node_modules farm above.
  # promise-manifest.mjs:23 imports `yaml` by a hardcoded relative path into
  # one.ie/web/node_modules -- before the farm it would die MODULE_NOT_FOUND.
  # SCOPE, inspected not assumed (a comment cannot enforce it, so this records
  # what was read): promise-manifest.mjs imports node:fs/node:path/node:url plus
  # that one linked yaml parser, has no fetch and no process.env, and writes
  # only src/data/promises.json + promises-index.json. Local writes, no network,
  # no install -- 0.42s and 0.22s measured. If either ever grows a network call
  # or a dependency the farm does not carry, EVERY cut pays for it here.
  # An absent script is a SILENT skip (a checkout without it is unaffected, the
  # same contract verify-fast.sh's guard has). A script that was asked to run and
  # did not deliver FAILS THE DOOR -- it does not merely warn. A warning nobody
  # is forced to read is a report, not a guard: a cut whose generate broke would
  # exit 0, hand the builder a green door and a red `tsc`, and reproduce the very
  # bug this block closes, now with a reassuring line on top of it.
  #
  # BLAST RADIUS, chosen deliberately and bounded to the door's one job here:
  # ONLY the two artifacts tsc resolves as modules are REQUIRED, and only when
  # this checkout declares the script that makes them. Every other thing this
  # script does -- the links, the .vite seed, the dev server -- keeps the
  # behaviour it had. Failing a whole cut over an unrelated optional generate
  # would be worse than the warning it replaces.
  #
  # BOTH limbs fail: a generator that exits non-zero, and an artifact absent
  # afterwards. The ACT is not the OUTCOME -- a generator can exit 0 and write
  # nothing, so exit status alone can never be the proof; the file tsc resolves
  # has to be on disk. The summary is COUNTED from what happened, never asserted.
  local pair g art tried=0 made=0 broke=0 ok
  for pair in "gen:promises|one.ie/web/src/data/promises.json" \
              "gen:page-modified|one.ie/web/src/lib/generated/page-modified.json"; do
    g="${pair%%|*}"; art="${pair#*|}"
    [ -f "$web/package.json" ] && grep -q "\"$g\"" "$web/package.json" || continue
    tried=$((tried+1)); ok=1
    ( cd "$web" && bun run "$g" >/dev/null 2>&1 ) || { ok=0; _say "FAILED: $g exited non-zero"; }
    [ -f "$WT/$art" ] || { ok=0; _say "FAILED: $art STILL MISSING after $g"; }
    if [ "$ok" -eq 1 ]; then made=$((made+1)); else broke=$((broke+1)); fi
  done
  if [ "$tried" -gt 0 ]; then
    _say "generated $made/$tried gitignored module(s) tsc imports; $broke unusable"
  fi
  # The function's status IS the verdict -- read at the call site, which refuses.
  [ "$broke" -eq 0 ]
}

# READY means a real SSR route answered 200 — not that a port opened. /u/one is
# the probe because it exercises SSR + D1 + the substrate, so a 200 there says
# the whole chain works. "The process started" is not the same fact.
_wait_ready() {
  local port="$1" n=0 code=""
  while [ $n -lt 240 ]; do
    code="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://localhost:$port/u/one" 2>/dev/null)"
    [ "$code" = "200" ] && { _say "READY — http://localhost:$port serves /u/one 200 (${n}s)"; return 0; }
    sleep 3; n=$((n+3))
  done
  _say "NOT READY after ${n}s — last status ${code:-none}.  tail -40 $WT/.dev.log"
  if grep -q "module is not defined" "$WT/.dev.log" 2>/dev/null; then
    _say "  Saw 'module is not defined' — that is the .vite cache, every time."
    _say "  Either this worktree is SHARING main's cache (check that"
    _say "  one.ie/web/node_modules is a real dir, not a symlink), or its own"
    _say "  cache was cold. Re-run: this script reseeds it warm."
  fi
  return 1
}

case "$MODE" in
  check)
    [ -f "$(_port_file)" ] || { echo "no port recorded for $NAME"; exit 1; }
    p="$(cat "$(_port_file)")"
    c="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://localhost:$p/u/one")"
    echo "$NAME: port $p -> /u/one $c"; [ "$c" = "200" ] ;;
  down)
    [ -f "$WT/.dev.pid" ] && kill -9 "$(cat "$WT/.dev.pid")" 2>/dev/null
    [ -f "$(_port_file)" ] && lsof -ti:"$(cat "$(_port_file)")" | xargs kill -9 2>/dev/null
    _say "$NAME stopped" ;;
  selftest)
    # A checker that cannot go red proves nothing. Point the readiness probe at a
    # port with nothing behind it and assert it never reports 200.
    dead="$(_free_port)"
    code="$(curl -s -o /dev/null -w '%{http_code}' -m 2 "http://localhost:$dead/u/one" 2>/dev/null)"
    [ "$code" = "200" ] && { echo "SELF-TEST INCONCLUSIVE: dead port $dead answered 200"; exit 1; }
    echo "SELF-TEST ok: a dead port reports '${code:-none}' — _wait_ready would refuse, not pass." ;;
  *)
    [ -n "$NAME" ] || { echo "usage: worktree-up.sh <name> [--port N] [--no-dev|--check|--down]" >&2; exit 2; }
    if [ ! -d "$WT" ]; then
      git -C "$ROOT" worktree add -b "feat/$NAME" "$WT" "$BASE" >/dev/null 2>&1 \
        || git -C "$ROOT" worktree add "$WT" "$BASE" >/dev/null 2>&1 \
        || { echo "worktree-up: could not create $WT" >&2; exit 1; }
      _say "worktree $NAME cut from $BASE"
    else
      _say "worktree $NAME exists — reusing"
    fi
    # The setup verdict is READ, not assumed. _link_deps returns non-zero when a
    # module tsc imports is still missing after its generate ran, and this door
    # then REFUSES rather than handing back a tree whose bare `tsc` reads red on
    # code nobody edited -- the whole defect of task:01a0c2d3d637480040106f34.
    # The worktree is left in place on purpose: this door is idempotent, so the
    # re-run after the fix heals it.
    _link_deps || {
      _say "REFUSING: a generated module this tree imports is missing — a bare"
      _say "  \`bunx tsc --noEmit\` here would read red on a file nobody edited."
      _say "  Fix the generator above and re-run this door; it is idempotent."
      exit 1
    }
    [ "$MODE" = "setup" ] && { _say "setup only — no dev server"; exit 0; }
    [ -n "$PORT" ] || PORT="$(_free_port)"
    echo "$PORT" > "$(_port_file)"
    # `bun run dev`, not a bare `astro dev`: the package script runs four codegen
    # steps first (gen:playbook-meta/promises/fleets/page-modified) that write
    # modules the app imports, and they are gitignored build output a fresh
    # worktree does not have.
    ( cd "$WT/one.ie/web" && nohup bun run dev --port "$PORT" > "$WT/.dev.log" 2>&1 & echo $! > "$WT/.dev.pid" )
    _say "astro dev starting on $PORT (log: $WT/.dev.log)"
    _wait_ready "$PORT" ;;
esac
