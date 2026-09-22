#!/usr/bin/env bash
# Deterministic /deploy — the whole pipeline with no LLM in the loop.
#
# Ships the five services to Cloudflare: gateway (api) · sync · channels ·
# pay/backend · astro (one-prod). Every step reports a number; the final
# report is the same shape /deploy prints by hand.
#
# Usage:
#   bash .claude/scripts/deploy.sh dev             # one.ie/web → one-dev (dev.one.ie)
#   bash .claude/scripts/deploy.sh                 # full pipeline (PRODUCTION)
#   bash .claude/scripts/deploy.sh astro           # one.ie/web → one-prod only
#   bash .claude/scripts/deploy.sh workers         # api + sync + channels
#   bash .claude/scripts/deploy.sh gateway|sync|agents|pay
#
# Flags:
#   --skip-tests      skip vitest (typecheck still runs)
#   --no-typedb-flake-waiver
#                     hard-stop on a red suite even when every failure is the
#                     shared TypeDB Cloud cluster being unreachable. The waiver
#                     is ON by default (DEPLOY_ALLOW_TYPEDB_FLAKE=0 also disables)
#                     and is classified by signature — a real assertion break, or
#                     a tasks:claim `not_found`, still blocks.
#   --skip-typecheck  skip per-service tsc
#   --skip-build      reuse an existing one.ie/web/dist
#   --skip-migrations skip `d1 migrations apply DB --remote`
#   --skip-health     deploy without the post-deploy probes
#   --changed         skip services with no commits since their last deploy
#   --gates-only      run the gates, ship nothing (a local pre-flight)
#   --check-creds     self-test the credential ladder, ship nothing
#   --yes / -y        no approval prompt (also: DEPLOY_YES=1)
#   --dry-run         print every command, deploy nothing
#
# NOT done here (it needs judgment): commit / PR / merge. Commit before you
# run this. The script refuses a dirty tree unless --allow-dirty.
#
# HARD RULES baked in (see .claude/commands/deploy.md):
#   · never `--env production` — it ships to the `one-prod-production` decoy
#   · CLOUDFLARE_API_TOKEN is unset; auth is GLOBAL_API_KEY + EMAIL
#   · health-check custom domains only (*.workers.dev is blocked on this net)
#   · sync is cron-only: a clean `wrangler deploy` IS its health signal
#   · a fast pass is NEVER reported as a full pass, and `dev` never touches prod
#   · dev.one.ie shares PRODUCTION's D1 and KV — ship dev freely, treat its DATA
#     as production                                    incident:deploy-two-tiers
#
# ACCOUNTS — why each gate is shaped the way it is (dates, shas, what it cost):
#   bash .claude/scripts/incident.sh --for .claude/scripts/deploy.sh
# What a gate MEANS: .claude/commands/deploy.md · its traps:
#   .claude/skills/deploy/REFERENCE.md

set -uo pipefail

# The deploy gate is the FULL gate, always. Build cycles run the dev lane
# (verify:fast — tsc + related tests + pinned suites); this is the one place
# every test must run, so any script that honours FULL_VERIFY runs everything.
export FULL_VERIFY=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

[[ -d one.ie/web && -d api && -d sync && -d channels && -d pay/backend ]] || {
  echo "deploy.sh: not the one-ie monorepo (missing a service dir): $ROOT" >&2
  exit 2
}

MODE="full"
SKIP_TESTS=0 SKIP_TYPECHECK=0 SKIP_BUILD=0 SKIP_MIGRATIONS=0 SKIP_HEALTH=0
ASSUME_YES="${DEPLOY_YES:-0}" DRY=0 ALLOW_DIRTY=0 ONLY_CHANGED=0 GATES_ONLY=0 CHECK_CREDS=0
# A red suite that is only the shared TypeDB cluster refusing to answer is
# waivable — classified by SIGNATURE, never by filename.  incident:waived-pass-is-a-fact
TYPEDB_FLAKE_WAIVER="${DEPLOY_ALLOW_TYPEDB_FLAKE:-1}" TESTS_WAIVED=0

for a in "$@"; do
  case "$a" in
    dev|full|astro|workers|gateway|sync|agents|channels|pay) MODE="$a" ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --skip-typecheck) SKIP_TYPECHECK=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --skip-migrations) SKIP_MIGRATIONS=1 ;;
    --skip-health) SKIP_HEALTH=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --no-typedb-flake-waiver) TYPEDB_FLAKE_WAIVER=0 ;;
    --changed) ONLY_CHANGED=1 ;;
    --gates-only) GATES_ONLY=1 ;;
    --check-creds) CHECK_CREDS=1 ;;
    --all) ONLY_CHANGED=0 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -n|--dry-run) DRY=1 ;;
    -h|--help) sed -n '2,46p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "deploy.sh: unknown argument '$a' (try --help)" >&2; exit 2 ;;
  esac
done
[[ "$MODE" == channels ]] && MODE=agents

# ── dev tier ─────────────────────────────────────────────────────────────────
# A different destination with a different gate is a different procedure.
# deploy-dev.sh owns it; this is only the door.          incident:deploy-two-tiers
if [[ "$MODE" == dev ]]; then
  # `(( SKIP_TESTS ))`, never `${SKIP_TESTS:+...}` — the latter expands on the
  # literal "0" and skips the gate every time.          incident:deploy-two-tiers
  dev_gate=0; (( SKIP_TESTS )) && dev_gate=1
  if (( DRY )); then
    echo "[dry] DEV_SKIP_GATE=$dev_gate bash .claude/scripts/deploy-dev.sh"
    exit 0
  fi
  exec env "DEV_SKIP_GATE=$dev_gate" bash "$ROOT/.claude/scripts/deploy-dev.sh"
fi

LOG_DIR="$ROOT/.deploy-logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/deploy-$STAMP.log"

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
[[ -t 1 ]] || { RED=""; GRN=""; YEL=""; DIM=""; OFF=""; }

say()  { printf '%s\n' "$*" | tee -a "$LOG"; }
step() { printf '\n%s══ %s%s\n' "$DIM" "$*" "$OFF" | tee -a "$LOG"; }
ok()   { printf '%s  ✓%s %s\n' "$GRN" "$OFF" "$*" | tee -a "$LOG"; }
bad()  { printf '%s  ✗%s %s\n' "$RED" "$OFF" "$*" | tee -a "$LOG"; }
warn() { printf '%s  !%s %s\n' "$YEL" "$OFF" "$*" | tee -a "$LOG"; }
die()  { bad "$*"; say ""; say "log: $LOG"; exit 1; }

# run <label> <dir> <cmd...> — logs, honours --dry-run, returns the exit code
run() {
  local label="$1" dir="$2"; shift 2
  if (( DRY )); then say "  [dry] (cd $dir && $*)"; return 0; fi
  say "  → $label"
  ( cd "$ROOT/$dir" && unset CLOUDFLARE_API_TOKEN && "$@" ) >>"$LOG" 2>&1
}

want_astro=0 want_gateway=0 want_sync=0 want_agents=0 want_pay=0
case "$MODE" in
  full)    want_astro=1 want_gateway=1 want_sync=1 want_agents=1 want_pay=1 ;;
  astro)   want_astro=1 ;;
  workers) want_gateway=1 want_sync=1 want_agents=1 ;;
  gateway) want_gateway=1 ;;
  sync)    want_sync=1 ;;
  agents)  want_agents=1 ;;
  pay)     want_pay=1 ;;
esac

# --changed skips a service with no new commits since its last CLEAN deploy.
# Secrets and bindings change outside git — use --all.        incident:changed-marker
svc_paths() { case "$1" in
  astro)    echo "one.ie/web packages" ;;
  gateway)  echo "api" ;;
  sync)     echo "sync" ;;
  channels) echo "channels packages" ;;
  pay)      echo "pay/backend" ;;
esac }
mark_file() { echo "$LOG_DIR/last-$1.sha"; }
svc_changed() { # 0 = has new commits (or no marker yet)
  local last; last="$(cat "$(mark_file "$1")" 2>/dev/null)"
  [[ -n "$last" ]] || return 0
  git merge-base --is-ancestor "$last" HEAD 2>/dev/null || return 0
  [[ -n "$(git log --oneline "$last..HEAD" -- $(svc_paths "$1") 2>/dev/null)" ]]
}
SKIPPED_UNCHANGED=()
if (( ONLY_CHANGED )); then
  for svc in astro gateway sync channels pay; do
    case "$svc" in
      astro)    (( want_astro ))   || continue ;;
      gateway)  (( want_gateway )) || continue ;;
      sync)     (( want_sync ))    || continue ;;
      channels) (( want_agents ))  || continue ;;
      pay)      (( want_pay ))     || continue ;;
    esac
    svc_changed "$svc" && continue
    SKIPPED_UNCHANGED+=("$svc")
    case "$svc" in
      astro) want_astro=0 ;; gateway) want_gateway=0 ;; sync) want_sync=0 ;;
      channels) want_agents=0 ;; pay) want_pay=0 ;;
    esac
  done
fi

# Typecheck only what is being shipped — `./deploy gateway` has no business
# spending 30s on one.ie/web. Full mode still covers all five.
SERVICES_TYPECHECK=()
(( want_astro ))   && SERVICES_TYPECHECK+=(one.ie/web)
(( want_gateway )) && SERVICES_TYPECHECK+=(api)
(( want_sync ))    && SERVICES_TYPECHECK+=(sync)
(( want_agents ))  && SERVICES_TYPECHECK+=(channels)
(( want_pay ))     && SERVICES_TYPECHECK+=(pay/backend)

if (( ONLY_CHANGED )) && ! (( want_astro + want_gateway + want_sync + want_agents + want_pay )); then
  echo "deploy: nothing changed since the last deploy of ${SKIPPED_UNCHANGED[*]} — use --all to ship anyway"
  exit 0
fi

say "deploy · mode=$MODE · $(date '+%Y-%m-%d %H:%M:%S')"
say "log: $LOG"

# ── Cloudflare credential resolution ────────────────────────────────────────
# A LADDER, not a lookup. Resolve ONE credential from an ordered list, prove it
# with curl against the API (never `wrangler whoami`, which answers about one
# directory), EXPORT the winner so all five subshells share it, name the source
# as sha8+length (never bytes), and prove all five agree on the account id —
# all of it BEFORE the 20-minute gates.          incident:cf-credential-ladder
CF_AUTH="" CF_AUTH_SOURCE="" CF_ACCOUNT=""

# _cf_probe <email> <key> — 200 from /user means these exact bytes authenticate.
# Ground truth, and direction-agnostic: it is equally able to prove a key ALIVE
# (2026-08-19) as dead (2026-08-18). Never conclude either from wrangler alone.
_cf_probe() {
  local e="$1" k="$2" code
  [[ -n "$e" && -n "$k" ]] || return 1
  code="$(curl -s -m 15 -o /dev/null -w '%{http_code}' \
            -H "X-Auth-Email: $e" -H "X-Auth-Key: $k" \
            https://api.cloudflare.com/client/v4/user 2>/dev/null)"
  [[ "$code" == "200" ]]
}

# _cf_fingerprint <secret> — length + sha8. The whole point of logging the
# credential's identity is to make "which key was that?" answerable next time,
# so it must be logged in a form that can never leak the key itself.
_cf_fingerprint() { printf 'len=%s sha=%s' "${#1}" "$(printf %s "$1" | shasum | cut -c1-8)"; }

# _cf_read <file> <var> — one value out of a .env-style file, quotes stripped.
_cf_read() {
  [[ -f "$1" ]] || return 1
  local v; v="$(grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2- | tr -d '"'"'"'\r' | xargs)"
  [[ -n "$v" ]] && printf '%s' "$v"
}

_cf_resolve() {
  local e k src
  # Rung 1-3: a global key from ambient env, then repo root, then one.ie/web.
  # Ordered so an operator's explicit export still wins, but a STALE export
  # cannot block a good key on disk — it just fails its probe and falls through.
  for src in "ambient env" "$ROOT/.env.local" "$ROOT/one.ie/web/.env"; do
    case "$src" in
      "ambient env")
        e="${CLOUDFLARE_EMAIL:-}"
        k="${CLOUDFLARE_API_KEY:-${CLOUDFLARE_GLOBAL_API_KEY:-}}" ;;
      *)
        e="$(_cf_read "$src" CLOUDFLARE_EMAIL || true)"
        k="$(_cf_read "$src" CLOUDFLARE_API_KEY || _cf_read "$src" CLOUDFLARE_GLOBAL_API_KEY || true)"
        [[ -n "${e:-}" ]] || e="${CLOUDFLARE_EMAIL:-}" ;;
    esac
    if _cf_probe "${e:-}" "${k:-}"; then
      # wrangler reads CLOUDFLARE_API_KEY; older copies of this script exported
      # only CLOUDFLARE_GLOBAL_API_KEY, a name wrangler ignores (the 2026-08-18
      # bug). Export BOTH so neither spelling can diverge again.
      export CLOUDFLARE_EMAIL="$e" CLOUDFLARE_API_KEY="$k" CLOUDFLARE_GLOBAL_API_KEY="$k"
      CF_AUTH="global-api-key"
      CF_AUTH_SOURCE="$src ($(_cf_fingerprint "$k"))"
      return 0
    fi
    [[ -n "${k:-}" ]] && say "    ${DIM}rejected: $src ($(_cf_fingerprint "$k")) — /user did not answer 200${OFF}"
  done
  # Rung 4: OAuth. Last, because it expires (~1h) and because a shadowing key
  # must never let the deploy land here by accident. A DEAD ambient key would
  # otherwise sit in the env poisoning every service, so strip all three now.
  unset CLOUDFLARE_EMAIL CLOUDFLARE_API_KEY CLOUDFLARE_GLOBAL_API_KEY
  if ( cd "$ROOT/one.ie/web" && ./node_modules/.bin/wrangler whoami >/dev/null 2>&1 ); then
    CF_AUTH="oauth"; CF_AUTH_SOURCE="wrangler login session (expires ~1h — re-run 'wrangler login' if a step 403s)"
    return 0
  fi
  return 1
}

# _cf_agree — every service must deploy to the SAME account, and that is only
# visible by asking each directory separately.   incident:cf-credential-ladder
_cf_agree() {
  (( DRY )) && return 0
  local d id first="" bad=0
  for d in one.ie/web api sync channels pay/backend; do
    id="$( cd "$ROOT/$d" 2>/dev/null && bunx wrangler whoami 2>/dev/null \
           | grep -oE '[0-9a-f]{32}' | head -1 )"
    if [[ -z "$id" ]]; then warn "$d — no account id from wrangler whoami"; bad=1; continue; fi
    if [[ -z "$first" ]]; then first="$id"; CF_ACCOUNT="$id"
    elif [[ "$id" != "$first" ]]; then
      bad "$d resolves account $id, but one.ie/web resolves $first"
      say "    a per-directory .env is overriding the resolved credential in $d"
      bad=1
    fi
  done
  (( bad )) && return 1
  ok "5/5 services agree on account ${first:0:8}…"
  return 0
}

# --check-creds — the RED half: a gate never seen to fail is not known to work.
# Plants a key that cannot authenticate.           incident:check-creds-red-half
if (( CHECK_CREDS )); then
  step "credential ladder — self-test"
  fails=0
  unset CLOUDFLARE_API_TOKEN
  # Resolve for real first — tests 3 and 4 assert properties OF a resolution,
  # so running them against an unresolved shell tests nothing.
  _cf_resolve || die "self-test cannot run: no working credential on any rung"
  ok "resolved: $CF_AUTH"

  say "  1/4 · a dead key must be rejected, not exported"
  if _cf_probe "nobody@example.invalid" "0000000000000000000000000000000000000"; then
    bad "_cf_probe returned 0 for a key that cannot authenticate — the probe is fail-open"; fails=1
  else ok "dead key rejected by /user probe"; fi

  say "  2/4 · a live credential must still resolve with a dead key shadowing it"
  ( export CLOUDFLARE_API_KEY="0000000000000000000000000000000000000" \
           CLOUDFLARE_GLOBAL_API_KEY="0000000000000000000000000000000000000" \
           CLOUDFLARE_EMAIL="nobody@example.invalid"
    _cf_resolve >/dev/null 2>&1 && [[ -n "$CF_AUTH" ]] ) \
    && ok "ladder fell through the shadowing key to a working rung" \
    || { bad "a dead ambient key BLOCKS resolution — this is the 2026-08-19 bug"; fails=1; }

  say "  3/4 · the resolved source must be named, and must not be the key itself"
  if [[ "$CF_AUTH_SOURCE" == *"sha="* || "$CF_AUTH" == "oauth" ]]; then
    ok "source reported: $CF_AUTH_SOURCE"
  else bad "credential source is unnamed — the next confusion is unavoidable"; fails=1; fi
  if [[ -n "${CLOUDFLARE_API_KEY:-}" && "$CF_AUTH_SOURCE" == *"${CLOUDFLARE_API_KEY}"* ]]; then
    bad "the log line contains the key BYTES"; fails=1
  else ok "no key bytes in the log line"; fi

  say "  4/4 · all five services must agree on the account"
  _cf_agree || fails=1

  say ""
  (( fails )) && die "credential self-test FAILED"
  ok "credential self-test passed"
  say "log: $LOG"; exit 0
fi

# ── Step 0.1 — the box (BEFORE everything, because everything below is a gate) ──
# Same reasoning as Step 0.4 one step further back: the cheapest check runs
# first. health.sh --box costs ~0.2s and owns every number in it (this reads,
# never restates). The verdict vocabulary is HEALTHY | DEGRADED | UNHEALTHY, and
# its own --self-test proves each threshold bites.
#
# WHY A PAGING BOX IS A DEPLOY CONCERN. A deploy runs five heavy gates. On a box
# under swap pressure each one runs long, and a slow gate is indistinguishable
# from a red one at the wall clock — measured 2026-09-05, an 8-fork vitest run
# showed a >20-minute wall clock that was governor QUEUEING, not runtime. A good
# tree then gets diagnosed as broken code, which is the most expensive wrong
# answer this script can give.
#
# DEGRADED never refuses: it means headroom of one gate, or orphans that survived
# a reap, and one gate is what a deploy needs. Only UNHEALTHY stops, and it names
# the agent that can fix it rather than telling you to wait.
step "Step 0.1 — box"
if [ "${DEPLOY_SKIP_DOCTOR:-0}" = "1" ]; then
  say "  skipped (DEPLOY_SKIP_DOCTOR=1)"
elif [ ! -x "$ROOT/.claude/scripts/health.sh" ] && [ ! -f "$ROOT/.claude/scripts/health.sh" ]; then
  say "  health.sh absent — box unmeasured (never read this as healthy)"
else
  _box_json="$( bash "$ROOT/.claude/scripts/health.sh" --box --json 2>/dev/null )"
  _box_v="$(printf '%s' "$_box_json" | sed -n 's/.*"verdict":"\([A-Z]*\)".*/\1/p')"
  _box_why="$(printf '%s' "$_box_json" | sed -n 's/.*"why":"\([^"]*\)".*/\1/p')"
  _box_orph="$(printf '%s' "$_box_json" | sed -n 's/.*"orphans":\([0-9]*\).*/\1/p')"
  case "${_box_v:-unknown}" in
    HEALTHY)  ok "box HEALTHY" ;;
    DEGRADED) say "  box DEGRADED — ${_box_why:-?} (proceeding: a deploy needs one gate)" ;;
    UNHEALTHY)
      # Reap first, but only when there is something to reap: with orphans=0 the
      # verdict is about memory or headroom and no reaper can move it. Running one
      # anyway is the ritual that makes a refusal look like it tried something.
      if [ "${_box_orph:-0}" != "0" ]; then
        bash "$ROOT/.claude/scripts/gate-reaper.sh" --once 2>/dev/null | sed 's/^/  /'
        _box_json="$( bash "$ROOT/.claude/scripts/health.sh" --box --json 2>/dev/null )"
        _box_v="$(printf '%s' "$_box_json" | sed -n 's/.*"verdict":"\([A-Z]*\)".*/\1/p')"
        _box_why="$(printf '%s' "$_box_json" | sed -n 's/.*"why":"\([^"]*\)".*/\1/p')"
        say "  box after reap: ${_box_v:-unknown}"
      fi
      if [ "${_box_v:-unknown}" = "UNHEALTHY" ] && (( ! DRY )); then
        say "  ${_box_why:-the box is saturated}"
        say "  Hand the box to the doctor, then deploy:"
        say "    Agent({ subagent_type: \"doctor\", model: \"opus\","
        say "            prompt: \"health.sh says: ${_box_why:-saturated}. Reclaim what nothing is coming back for, then report.\" })"
        say "  Override (the gates will be slow, not wrong):  DEPLOY_SKIP_DOCTOR=1 ./deploy"
        die "box is UNHEALTHY — refusing to start five gates on it"
      fi
      say "  box UNHEALTHY — ${_box_why:-?} (dry run: reporting, refusing nothing)" ;;
    *) say "  box verdict unreadable — unmeasured, which is never a pass" ;;
  esac
fi

# ── Step 0.4 — credentials (BEFORE the slow gates) ──────────────────────────
# It was after them: on 2026-08-18 a bad credential was discovered only at Step
# 6.5, having already spent the full test suite and a 2m14s production build.
# One curl costs nothing. Fail here.
step "Step 0.4 — credentials"
unset CLOUDFLARE_API_TOKEN
_cf_resolve || die "no working Cloudflare credential — run 'wrangler login', or put a VALID CLOUDFLARE_API_KEY + CLOUDFLARE_EMAIL in .env.local"
ok "resolved: $CF_AUTH"
say "    source: $CF_AUTH_SOURCE"

# ── Step 0 — tree state (before the slow gates: a dirty tree should fail fast)
step "Step 0 — tree"
# stdin not a TTY means nobody can type "yes" at Step 6. Refuse here, where it
# is free, not after the whole gate battery.        incident:approval-needs-a-tty
if (( ! ASSUME_YES )) && (( ! DRY )) && [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] && [[ ! -t 0 ]]; then
  die "non-interactive (stdin is not a TTY) and the Step 6 approval prompt cannot be answered. Pass --yes / -y, or set DEPLOY_YES=1."
fi
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
HEAD_SHA="$(git rev-parse --short HEAD)"
say "  branch=$BRANCH head=$HEAD_SHA"
DIRTY="$(git status --porcelain | wc -l | tr -d ' ')"
if [[ "$DIRTY" != "0" ]]; then
  git status --porcelain | sed 's/^/    /' | tee -a "$LOG"
  if (( ALLOW_DIRTY )); then
    warn "$DIRTY uncommitted path(s) — shipping anyway (--allow-dirty)"
  else
    die "$DIRTY uncommitted path(s). Commit them (deploy.sh does not write git history), or pass --allow-dirty."
  fi
else
  ok "clean tree"
fi

# ── Step 0.5 — generated artifacts (cheap, before the slow gates) ─────────
# One cheap deterministic check, run where failing is free. It exits non-zero on
# drift AND on failing to run, and both stop the deploy.
#
# THE DRY BRANCH IS EXPLICIT: `run` returns 0 under --dry-run, so
# `if run ...; then ok` would print GREEN for a check that never executed — an
# unrun gate reported as a pass.                    incident:blocks-manifest-unrun
# ── Step 0.5a — deps present (0.05s, and it buys ~290s) ─────────────────────
# Every service this run will typecheck must have a node_modules. A missing one
# does not read as missing: tsc reports `TS2688: Cannot find type definition file
# for '@cloudflare/workers-types'` — a TypeScript error naming TypeScript — and
# it surfaces at the END of the gate fan-out, ~290s in, on code that is fine.
# Measured 2026-09-17 at the ship gate: api and sync red in all four worktrees at
# once, because worktree-up.sh's LINKS list carried neither. That list is fixed;
# this check is the half that cannot rot, because it holds for a tree materialised
# any other way.
step "Step 0.5a — deps"
_deps_missing=()
for _svc in "${SERVICES_TYPECHECK[@]}"; do
  [ -e "$ROOT/$_svc/node_modules" ] || _deps_missing+=("$_svc")
done
if (( ${#_deps_missing[@]} )); then
  for _svc in "${_deps_missing[@]}"; do say "  ✗ $_svc/node_modules missing"; done
  say "  A worktree is not \`git worktree add\` — that command omits every gitignored path."
  say "  Link them: bash .claude/scripts/worktree-up.sh <name> --no-dev"
  say "  Or by hand: ln -sfn <main-tree>/$'{'svc'}'/node_modules \$svc/node_modules"
  die "${#_deps_missing[@]} service(s) cannot typecheck — refusing at t≈7s rather than t≈290s"
fi
ok "${#SERVICES_TYPECHECK[@]}/${#SERVICES_TYPECHECK[@]} services have deps"

step "Step 0.5 — generated artifacts"
if (( DRY )); then
  say "  [dry] node .claude/scripts/blocks-manifest.mjs --check"
elif run "blocks-manifest --check" . node "$ROOT/.claude/scripts/blocks-manifest.mjs" --check; then
  ok "block manifest: no drift"
else
  tail -5 "$LOG" | sed 's/^/    /'
  die "block manifest DRIFT (or --check could not run) — regenerate with 'node .claude/scripts/blocks-manifest.mjs' and commit all three artifacts"
fi

# ── Steps 1+3 — the slow gates, all at once ─────────────────────────────────
# They share no STATE (only the SDK's dist/, built first), so concurrency makes
# W0+build cost max() instead of sum(). They are NOT independent in COST:
# TEST BUDGETS HERE MUST BE SIZED FOR A STARVED RUN, not a quiet one, and a gate
# that needs the box to itself leaves this block rather than widening every
# timeout downstream.                        incident:gates-not-independent-in-cost

# web + channels resolve @oneie/sdk types out of packages/sdk/dist — an unbuilt
# dist fakes a wall of TS2307, so this one is a real dependency, done serially.
if ! (( SKIP_TYPECHECK )) && [[ ! -d packages/sdk/dist ]]; then
  step "Step 1.0 — @oneie/sdk build (dist/ missing)"
  run "build @oneie/sdk" packages/sdk bun run build || die "SDK build failed — see $LOG"
  ok "sdk built"
fi

# ── heavy-gate concurrency, priced in MEMORY not cores ──────────────────────
# Cores were never the binding constraint. Serialising addresses a SLOW gate; it
# is NOT the fix for the vitest gate hanging — the bound below is. A probe that
# cannot read memory returns a large number: a broken sensor must never silently
# serialise the pipeline.                incident:heavy-gates-priced-in-memory
HEAVY_NEED_GB="${DEPLOY_HEAVY_NEED_GB:-14}"   # build 8 + vitest ~6
# shellcheck source=lib/govern.sh
. "$ROOT/.claude/scripts/lib/govern.sh"
# gate_mem_avail_mb, never memory_pressure's "free percentage" — that counts
# cache and compressed pages as free.     incident:heavy-gates-priced-in-memory
heavy_free_gb() {
  local avail_mb
  avail_mb="$(gate_mem_avail_mb 2>/dev/null || echo "")"
  [ -z "$avail_mb" ] && { echo 999; return 0; }
  echo $(( avail_mb / 1024 ))
}
HEAVY_FREE_GB="$(heavy_free_gb)"
if (( HEAVY_FREE_GB >= HEAVY_NEED_GB )); then HEAVY_PARALLEL=1; else HEAVY_PARALLEL=0; fi
[[ "${DEPLOY_HEAVY_PARALLEL:-}" == 1 ]] && HEAVY_PARALLEL=1   # escape hatch

if (( HEAVY_PARALLEL )); then
  step "Steps 1+3 — gates in parallel (typecheck ×5 · vitest · astro build)"
  say "  memory: ${HEAVY_FREE_GB}GB free >= ${HEAVY_NEED_GB}GB needed — heavy gates overlap"
else
  step "Steps 1+3 — gates (typecheck ×5 parallel · vitest + astro build serial)"
  say "  memory: ${HEAVY_FREE_GB}GB free < ${HEAVY_NEED_GB}GB needed — heavy gates serialised"
  say "          (overlapping them pages; measured 1145s vs 176s — see deploy.sh)"
fi

# ── the run, streamed into the world ────────────────────────────────────────
# THREE RULES, all about not making the telemetry load-bearing: it can never FAIL
# the deploy (backgrounded, `|| true`) · it can never SLOW the deploy (`&`) ·
# --dry-run emits NOTHING. A dropped emit degrades to a GAP in the trace, never
# to a lie.                              incident:deploy-emit-never-load-bearing
# An `if`, not `$( case ... esac )`: bash 3.2 closes `$(` at the FIRST `)`, and a
# case pattern ends in one — it wrote a literal into deploy-runs.json, which is
# the one degradation the rules above forbid.  incident:deploy-emit-never-load-bearing
if [ "$MODE" = dev ]; then EMIT_TARGET="dev.one.ie"; else EMIT_TARGET="one.ie"; fi
EMIT_ENV="$( [[ "$MODE" == dev ]] && echo dev || echo prod )"

# Anything unmapped emits NOTHING rather than inventing a stage — better absent
# than mislabelled.                      incident:deploy-emit-never-load-bearing
_spine_stage() {
  case "$1" in
    tsc-*)   echo typecheck ;;
    vitest)  echo tests ;;
    build)   echo build ;;
    *)       echo "" ;;
  esac
}

# The verdict CLOSES the run, and is a field of its own — --gates-only is a
# complete run that never reaches ship.  incident:deploy-verdict-closes-the-run
_emit_verdict() {
  local v="$1"
  _emit --verdict "$v" \
    --detail "shipped=${TARGETS[*]:-none}" \
    --detail "wallSec=$(( SECONDS ))" \
    --detail "mode=${MODE}" \
    --detail "heavyParallel=$( (( ${HEAVY_PARALLEL:-0} )) && echo true || echo false )" \
    --detail "memFreeGb=${HEAVY_FREE_GB:-0}"
  # Give the backgrounded emit a moment to land. Bounded and ignored: the run is
  # closing either way, and a deploy must not wait on its own telemetry.
  #
  # PID-QUALIFIED, and that is the whole point. This was a bare `wait -n`, which
  # on the local bash 3.2.57 is an INVALID OPTION that returns in 0s — so it was
  # correct here by accident, not by construction. On bash >= 4.3 `wait -n` waits
  # for the NEXT job to finish, whichever that is; and `_emit` returns at its
  # first two lines without backgrounding anything when deploy-emit.sh is absent
  # or not executable, or under --dry-run. The typedb lane gate is then the only
  # remaining child, so closing the run would block on it for up to GATE_BOUND
  # (900s) — on the --gates-only path `release.sh promote` takes. Every other
  # wait in this file is pid-qualified (:595, :761, :1053, :1100); this one now
  # is too. An empty/stale pid is swallowed, which is the old behaviour minus the
  # portability trap.
  #
  # NOTE THE COST, because it is newly real: on bash 3.2 the bare form returned
  # INSTANTLY (invalid option), so the "moment to land" this comment promised
  # never actually happened. It happens now, bounded by deploy-emit.sh's own
  # `--max-time` (DEPLOY_EMIT_TIMEOUT, default 8s; the door measures 1.3-2.0s),
  # and only when an emit was actually backgrounded — --dry-run and a missing
  # deploy-emit.sh return before that line and leave _EMIT_PID unset.
  #                                      incident:deploy-verdict-closes-the-run
  wait "${_EMIT_PID:-}" 2>/dev/null || true
}

# --slug is load-bearing: without it prod answers `forbidden` to every frame.
#                                              incident:ask-slug-load-bearing
_emit() {  # ...deploy-emit.sh args
  [[ -x "$ROOT/.claude/scripts/deploy-emit.sh" ]] || return 0
  (( DRY )) && return 0
  ( bash "$ROOT/.claude/scripts/deploy-emit.sh" \
      --run "$STAMP" --target "$EMIT_TARGET" --env "$EMIT_ENV" \
      --slug "${DEPLOY_SLUG:-one}" \
      --door "deploy${MODE:+ $MODE}" \
      --sha "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '')" \
      "$@" >/dev/null 2>&1 || true ) &
  # The pid _emit_verdict waits on. Recorded HERE because this is the only line
  # in the file that backgrounds a telemetry job — a verdict that waits for
  # "whatever finishes next" waits for a test lane.
  _EMIT_PID=$!
  return 0
}

GATE_NAMES=() GATE_PIDS=() GATE_LOGS=() GATE_RC=() GATE_T=() GATE_DUR=()
GATE_BOUND="${DEPLOY_GATE_TIMEOUT:-900}"   # healthy vitest 176s, build 174s
# Typechecks are NOT "cached ~1s each" — no tsconfig sets `incremental`, so five
# full checks fan out to ~7.5GB that HEAVY_NEED_GB never priced. If the box
# cannot hold the fan-out, route them through the semaphore; a warm box runs them
# bare and parallel.                            incident:tsc-not-cached-on-ship
TSC_EACH_GB="${DEPLOY_TSC_EACH_GB:-2}"
TSC_NEED_GB=$(( TSC_EACH_GB * ${#SERVICES_TYPECHECK[@]} ))
if (( HEAVY_FREE_GB >= TSC_NEED_GB )); then TSC_GOVERNED=0; else TSC_GOVERNED=1; fi
[[ "${DEPLOY_TSC_GOVERNED:-}" == 1 ]] && TSC_GOVERNED=1   # escape hatch
[[ "${DEPLOY_TSC_GOVERNED:-}" == 0 ]] && TSC_GOVERNED=0
gate_start() { # <name> <dir> <cmd...>
  local name="$1" dir="$2"; shift 2
  if (( DRY )); then say "  [dry] (cd $dir && $*)"; return; fi
  local out="$LOG_DIR/$name-$STAMP.log"
  ( cd "$ROOT/$dir" && unset CLOUDFLARE_API_TOKEN && "$@" ) >"$out" 2>&1 &
  GATE_NAMES+=("$name"); GATE_PIDS+=("$!"); GATE_LOGS+=("$out"); GATE_RC+=(-1)
  GATE_T+=("$SECONDS"); GATE_DUR+=(-1)
  # The `start` frame is what makes a run render as IN PROGRESS rather than
  # appearing whole at the end. Emitted per LAUNCH, so a serialised gate's
  # start is the moment it really started, not the moment the batch did.
  { st="$(_spine_stage "$name")"; [[ -n "$st" ]] && _emit --stage "$st" --status start; } || true
  say "  → $name (pid $!)"
}
# Heavy gates run under gate-run.sh for its BOUND and its process-group REAP:
# macOS ships no timeout(1), and killing only the shell reparents the vitest
# forks to launchd. A hung gate must die on a clock, not outlive the deploy.
gate_start_governed() { # <name> <dir> <cmd...>
  local name="$1" dir="$2"; shift 2
  if (( DRY )); then say "  [dry] (cd $dir && gate-run.sh deploy-$name -- $*)"; return; fi
  local out="$LOG_DIR/$name-$STAMP.log"
  ( cd "$ROOT/$dir" && unset CLOUDFLARE_API_TOKEN \
      && GOVERN_GATE_TIMEOUT="$GATE_BOUND" \
         exec "$ROOT/.claude/scripts/gate-run.sh" "deploy-$name" -- "$@" ) >"$out" 2>&1 &
  GATE_NAMES+=("$name"); GATE_PIDS+=("$!"); GATE_LOGS+=("$out"); GATE_RC+=(-1)
  GATE_T+=("$SECONDS"); GATE_DUR+=(-1)
  # The `start` frame is what makes a run render as IN PROGRESS rather than
  # appearing whole at the end. Emitted per LAUNCH, so a serialised gate's
  # start is the moment it really started, not the moment the batch did.
  { st="$(_spine_stage "$name")"; [[ -n "$st" ]] && _emit --stage "$st" --status start; } || true
  say "  → $name (pid $!, bound ${GATE_BOUND}s)"
}
# gate_start_heavy — blocks until the previous heavy gate finished when memory
# says they cannot overlap, and records its status in GATE_RC so the collection
# loop never waits on a reaped pid.      incident:gate-start-heavy-wait-127
HEAVY_IDX=()
gate_start_heavy() {
  if (( ! DRY )) && (( ! HEAVY_PARALLEL )) && (( ${#HEAVY_IDX[@]} )); then
    local prev="${HEAVY_IDX[${#HEAVY_IDX[@]}-1]}"
    say "  … waiting for ${GATE_NAMES[$prev]} before starting $1 (serialised)"
    if wait "${GATE_PIDS[$prev]}"; then GATE_RC[$prev]=0; else GATE_RC[$prev]=1; fi
    GATE_DUR[$prev]=$(( SECONDS - GATE_T[$prev] ))
  fi
  gate_start_governed "$@"
  (( DRY )) || HEAVY_IDX+=( $(( ${#GATE_NAMES[@]} - 1 )) )
}

GATE_T0=$SECONDS
if ! (( SKIP_TYPECHECK )); then
  if (( TSC_GOVERNED )); then
    say "  memory: ${HEAVY_FREE_GB}GB free < ${TSC_NEED_GB}GB needed — typechecks governed (queued)"
  else
    say "  memory: ${HEAVY_FREE_GB}GB free >= ${TSC_NEED_GB}GB needed — typechecks bare (parallel)"
  fi
  # NOT routed through tsc-cached.sh, and that is a measurement: it would buy
  # zero seconds and could turn a ship gate red on LOCK CONTENTION rather than on
  # code.                                       incident:tsc-not-cached-on-ship
  # CONTENT TYPES FIRST, and worth its four seconds. Raw `tsc --noEmit` does not
  # sync, `DataEntryMap` is generated into the gitignored .astro/, and a TS2344
  # on a collection key is an ASTRO fault wearing a TypeScript error. Must run
  # BEFORE the fan-out, or a sync races the tscs already reading those types.
  #                                     incident:astro-content-sync-before-tsc
  if (( want_astro )) && [[ -d one.ie/web ]]; then
    ( cd one.ie/web && NODE_OPTIONS=--max-old-space-size=4096 \
        ./node_modules/.bin/astro sync >/dev/null 2>&1 ) \
      && ok "content types synced" \
      || warn "astro sync failed — a new content collection will read as a tsc error"
  fi
  for svc in "${SERVICES_TYPECHECK[@]}"; do
    if (( TSC_GOVERNED )); then
      gate_start_governed "tsc-$(echo "$svc" | tr / -)" "$svc" bunx tsc --noEmit
    else
      gate_start "tsc-$(echo "$svc" | tr / -)" "$svc" bunx tsc --noEmit
    fi
  done
fi
# the suite lives in one.ie/web and gates that worker
# The vitest gate hangs on a non-TTY stdout; `script -qeF` + `--reporter=dot` is
# the unstick.                              incident:vitest-pty-and-memo-probe
# TEST_CACHE_PTY=1 is not optional (this gate's stdout is a log file), the argv
# lives in test-full.sh so /close and deploy share one stamp, and the memo is
# PROBED BEFORE A SLOT IS TAKEN — a hit needs no memory, no forks and no slot.
#                                           incident:vitest-pty-and-memo-probe
#                                           incident:memo-hit-is-not-all-pass
#
# >>> vitest-memo-probe (extracted VERBATIM by deploy-gate-check.sh — keep self-contained)
# _memo_probe — "is EVERY lane already a green stamp for this exact tree?" Runs
# nothing, computes nothing, writes nothing.
#   0 = every lane HIT (stdout: one `already PASSED <ts>` line per lane)
#   1 = at least one lane MISSES  ·  2 = cannot answer
# Anything but 0 takes the slot and runs the gate: an unrun check is not a pass.
# It asks per LANE, never `TEST_CACHE_PROBE=1 test-full.sh` — that would skip the
# whole gate on a pool-only hit.            incident:vitest-pty-and-memo-probe
_memo_probe() {
  local cache="${TEST_CACHE_DIR:-${TMPDIR:-/tmp}/one-test-cache}"
  [[ "${TEST_CACHE_DISABLE:-0}" == "1" ]] && return 2
  local keys
  keys="$( TEST_CACHE_KEY_ONLY=1 bash "$ROOT/.claude/scripts/test-full.sh" 2>/dev/null \
           | grep -Eo '^[0-9a-f]{64}$' )"
  [[ -n "$keys" ]] || return 2          # no key ⇒ no answer ⇒ run the gate
  local k f hit n=0
  while IFS= read -r k; do
    [[ -n "$k" ]] || continue
    n=$((n+1)); hit=""
    for f in "$cache"/*"$k".pass; do
      if [[ -f "$f" ]]; then hit="$f"; break; fi
    done
    [[ -n "$hit" ]] || return 1         # one miss is a miss: the gate runs
    printf '    lane %s — identical inputs already PASSED %s\n' \
           "${k:0:12}" "$(cat "$hit" 2>/dev/null)"
  done <<< "$keys"
  (( n )) || return 2
  return 0
}
if (( SKIP_TESTS || ! want_astro )); then
  :                                      # --skip-tests keeps its own meaning
else
  _mp_t0=$SECONDS
  _mp_out="$(_memo_probe)"; _mp_rc=$?
  _mp_dur=$(( SECONDS - _mp_t0 ))
  if (( _mp_rc == 0 )) && (( DRY )); then
    say "  [dry] vitest gate would be REUSED from the memo (no slot taken)"
  elif (( _mp_rc == 0 )); then
    # NOT via gate_start_heavy and not in HEAVY_IDX: a gate with no process is
    # not a heavy gate, and `wait 0` on a non-child exits 127.
    #                                      incident:gate-start-heavy-wait-127
    _mp_log="$LOG_DIR/vitest-$STAMP.log"
    { echo "[deploy] vitest gate SKIPPED by the memo probe — every lane of the full suite"
      echo "[deploy] is already a green stamp for this exact tree. No governor slot taken."
      printf '%s\n' "$_mp_out"
      echo "[deploy] probe cost ${_mp_dur}s"
    } > "$_mp_log"
    GATE_NAMES+=(vitest); GATE_PIDS+=(0); GATE_LOGS+=("$_mp_log"); GATE_RC+=(0)
    GATE_T+=("$SECONDS"); GATE_DUR+=("$_mp_dur")
    { st="$(_spine_stage vitest)"; [[ -n "$st" ]] && _emit --stage "$st" --status start; } || true
    say "  → vitest (memo HIT in ${_mp_dur}s — no slot taken)"
  else
    case "$_mp_rc" in
      1) say "  memo probe: MISS — no green stamp for at least one lane of this tree" ;;
      *) say "  memo probe: could not answer — running the gate (an unrun check is not a pass)" ;;
    esac
    # THE SPLIT IS CONDITIONAL ON HEAVY_PARALLEL, and the condition is the whole
    # honesty of it. Split, this gate runs the POOL lane only and the typedb lane
    # is its own gate (`gate 1b` below) that nothing waits for — which is worth
    # ~204s of deploy latency ONLY while the two can genuinely overlap.
    #
    # When memory says they cannot (HEAVY_PARALLEL=0, the common case on this
    # box: 8258MB free against HEAVY_NEED_GB=14), gate_start_heavy serialises, so
    # the typedb gate — started LAST — would begin microseconds before the
    # collection loop reads its marker. The marker would therefore be absent on
    # EVERY serialised deploy and the receipt would read `Typedb: unrun` every
    # single time. A field that can only say one thing is a dead signal, and a
    # lane whose verdict never reaches a human is a deleted gate wearing a
    # different word — which is exactly what the split was supposed to prevent.
    #
    # So on the serialised path take the OLD path, unchanged: ONE gate running
    # BOTH lanes with TYPEDB_LANE_NONBLOCKING=1, the typedb rc printed in this
    # gate's own log as it always was. There is no overlap to win there, so the
    # split costs a dead field and buys nothing. `${HEAVY_PARALLEL:-0}` — an
    # unset value takes the OLD path, because the conservative branch is the one
    # that still reports.
    if (( ${HEAVY_PARALLEL:-0} )); then
      gate_start_heavy vitest one.ie/web \
        env TEST_LANES_ONLY=pool TEST_CACHE_PTY=1 bash "$ROOT/.claude/scripts/test-full.sh"
    else
      gate_start_heavy vitest one.ie/web \
        env TYPEDB_LANE_NONBLOCKING=1 TEST_CACHE_PTY=1 bash "$ROOT/.claude/scripts/test-full.sh"
    fi
  fi
fi
# <<< vitest-memo-probe
if (( want_astro )); then
  if (( SKIP_BUILD )); then
    [[ -d one.ie/web/dist/server ]] || die "--skip-build but one.ie/web/dist/server/ does not exist"
  else
    gate_start_heavy build one.ie/web bash "$ROOT/.claude/scripts/astro-build-cached.sh"
  fi
fi

# ── gate 1b — the typedb lane, on its own slot, NEVER waited on ─────────────
# Measured 2026-09-21. The two lanes were one gate, and a gate costs its slower
# lane:  pool 1420 files / 8 forks / CPU-bound / 29.6s  ·  typedb 25 files /
# serial / NETWORK-bound / 118.8s. 1.7% of the files set 100% of the wall clock —
# and this deploy passed TYPEDB_LANE_NONBLOCKING=1, i.e. it had already declared
# that rc could not change the outcome, then blocked ~89s at `wait` to collect it
# (test-lanes.sh, the second `wait` before the non-blocking branch discards it).
#
# Split, the typedb lane is the ONE lane that can overlap the astro build: it
# spends its life waiting on a socket, so it costs almost no CPU. The pool lane
# cannot — 8 forks beside an 8GiB-heap build made BOTH take 256s, and capping the
# pool to 5 forks made it WORSE (test-lanes.sh, the VERIFY_POOL_FORKS note).
#
# STARTED LAST on purpose: when memory serialises the heavy gates
# (HEAVY_PARALLEL=0 above) gate_start_heavy waits for the PREVIOUS heavy gate, so
# last position is the only one where this lane overlaps the ship rather than
# delaying the build behind it.
#
# Skipped entirely when the memo probe said EVERY lane is already a green stamp
# for this tree — that probe is all-or-nothing on purpose (a pool-only hit must
# never skip a typedb lane that never ran), so `_mp_rc == 0` covers both lanes.
TYPEDB_RC_FILE="$LOG_DIR/typedb-rc-$STAMP"
# A stale marker would be read as this run's verdict. $STAMP has one-second
# granularity, so a collision needs two deploys in the same second in the same
# tree — near-unreachable, and clearing costs nothing next to the question.
rm -f "$TYPEDB_RC_FILE"
if (( ${HEAVY_PARALLEL:-0} )) && (( ! SKIP_TESTS )) && (( want_astro )) && [[ "${_mp_rc:-9}" != "0" ]]; then
  # The lane writes its own rc to a file, because the collection loop must read
  # the verdict WITHOUT `wait`ing for it and bash 3.2 (macOS) has neither
  # `wait -n` nor timeout(1) to bound a wait with. No marker ⇒ the lane has not
  # finished ⇒ the receipt records `unrun`, which is the one thing it must be
  # able to say instead of `pass`.
  gate_start_heavy typedb one.ie/web \
    env TEST_LANES_ONLY=typedb TEST_CACHE_PTY=1 \
        TYPEDB_RC_FILE="$TYPEDB_RC_FILE" TYPEDB_LANE_SCRIPT="$ROOT/.claude/scripts/test-full.sh" \
        bash -c 'bash "$TYPEDB_LANE_SCRIPT"; rc=$?; printf "%s\n" "$rc" >"$TYPEDB_RC_FILE"; exit $rc'
fi

TYPECHECK_REPORT="skipped" TESTS_REPORT="skipped" BUILD_REPORT="skipped" TYPEDB_REPORT="skipped"
# On the serialised path there IS no typedb gate — the lane ran inside the vitest
# gate, as it always did. Say that, rather than leaving the field reading
# `skipped`, which would be false about a lane that ran.
if (( ! ${HEAVY_PARALLEL:-0} )) && (( ! SKIP_TESTS )) && (( want_astro )); then
  TYPEDB_REPORT="in the vitest gate — heavy gates serialised, lanes not split (rc non-blocking there too)"
elif (( ! SKIP_TESTS )) && (( want_astro )) && [[ "${_mp_rc:-9}" == "0" ]]; then
  # Split path, memo HIT: no typedb gate was started because EVERY lane was
  # already a green stamp for this tree. That is reuse, not a skip.
  TYPEDB_REPORT="REUSED with the pool lane — every lane already green for this tree (memo probe)"
fi
tc_pass=0 tc_total=0 gate_fail=()
for i in $(seq 0 $(( ${#GATE_NAMES[@]} - 1 )) ); do
  (( ${#GATE_NAMES[@]} )) || break
  name="${GATE_NAMES[$i]}" glog="${GATE_LOGS[$i]}"
  if (( ${GATE_RC[$i]} >= 0 )); then rc="${GATE_RC[$i]}"      # already reaped when serialised
  elif [[ "$name" == typedb ]]; then
    # NEVER `wait` on this one. Waiting for it IS the ~89s this split removes,
    # and its rc is not part of the verdict (see gate 1b above). Read the marker
    # the lane writes when it finishes; ABSENT means it has not finished, and
    # that is `unrun` (-1) — never a pass. `tr -dc` because a half-written marker
    # must not arithmetic-expand into something that reads as 0.
    if [[ -s "$TYPEDB_RC_FILE" ]]; then rc="$(tr -dc '0-9' <"$TYPEDB_RC_FILE")"; rc="${rc:-1}"
    else rc=-1; fi
  elif wait "${GATE_PIDS[$i]}"; then rc=0; else rc=1; fi
  GATE_RC[$i]=$rc   # record it: the deploy receipt below reads results, not just timings
  (( ${GATE_DUR[$i]} < 0 )) && GATE_DUR[$i]=$(( SECONDS - GATE_T[$i] ))
  # …and onto the stream. ONE hook for the three gates that are ~95% of the wall
  # clock. Deferred past the `case` for `tests`, whose reused/waived facts are not
  # known at this line.                   incident:deploy-emit-never-load-bearing
  _emit_stage="$(_spine_stage "$name")"
  _emit_dur=$(( GATE_DUR[i] < 0 ? 0 : GATE_DUR[i] ))
  cat "$glog" >>"$LOG"
  case "$name" in
    tsc-*)
      tc_total=$((tc_total+1))
      if (( rc )); then bad "${name#tsc-} typecheck FAILED"; gate_fail+=("$name")
      else tc_pass=$((tc_pass+1)); fi ;;
    vitest)
      # TWO lanes means TWO "Tests N passed" lines — SUM them; `tail -1` reported
      # 143 for a 10940-test run.        incident:two-lanes-tail-1-understates
      TESTS_REPORT="$(awk '
        /Tests +[0-9]+ (passed|failed)/ {
          for (i = 1; i <= NF; i++) {
            if ($i == "passed") p += $(i-1) + 0
            if ($i == "failed") f += $(i-1) + 0
          }
          n++
        }
        # Read the Errors line too: vitest exits non-zero on UNHANDLED errors
        # with ZERO failed tests.        incident:two-lanes-tail-1-understates
        /Errors +[0-9]+ errors?/ { for (i = 1; i <= NF; i++) if ($i ~ /^errors?$/) e += $(i-1) + 0 }
        END {
          if (n == 0) exit
          if (n > 1) printf "Tests %d passed", p; else printf "Tests %d passed", p
          if (f > 0) printf " | %d failed", f
          if (e > 0) printf " | %d unhandled errors", e
          if (n > 1) printf " (%d lanes)", n
          printf "\n"
        }' "$glog")"
      if (( rc )); then
        bad "${TESTS_REPORT:-vitest failed}"
        say "  Failing files (check the Known-Flaky allowlist in .claude/commands/deploy.md):"
        grep -E '^ *(FAIL|❯ .*\.test\.ts.*(failed|×))' "$glog" | sort -u | sed 's/^/    /' | tee -a "$LOG"
        # Is the whole red run just the shared substrate being down? The checker
        # answers by SIGNATURE, and blocks on the first failure it cannot account
        # for — so a real break standing beside a 503 still stops the deploy.
        _flake_out=""
        if (( TYPEDB_FLAKE_WAIVER )); then
          _flake_out="$(bash "$ROOT/.claude/scripts/typedb-flake-check.sh" "$glog" 2>&1)"; _flake_rc=$?
        else
          _flake_out="typedb-flake: waiver disabled (--no-typedb-flake-waiver)"; _flake_rc=1
        fi
        printf '%s\n' "$_flake_out" | sed 's/^/    /' | tee -a "$LOG"
        if (( _flake_rc == 0 )); then
          TESTS_WAIVED=1
          TESTS_REPORT="${TESTS_REPORT:-vitest failed} — WAIVED as TypeDB outage (suite NOT green)"
          ok "test failures waived: shared TypeDB Cloud unavailable"
        else
          gate_fail+=(vitest)
        fi
      elif grep -q 'SKIPPED by the memo probe' "$glog"; then
        # A reused pass is never reported as "all pass", and the stamp's own
        # timestamp rides along.           incident:memo-hit-is-not-all-pass
        TESTS_REPORT="full suite REUSED — identical inputs already passed (memo probe, no slot taken: $(grep -o 'already PASSED.*' "$glog" | tail -1))"
        ok "$TESTS_REPORT"
      elif grep -q 'cache HIT' "$glog"; then
        # Say WHICH it was — both are sound, only one took 20 minutes.
        #                                  incident:memo-hit-is-not-all-pass
        TESTS_REPORT="full suite REUSED — identical inputs already passed ($(grep -o 'already PASSED.*' "$glog" | tail -1))"
        ok "$TESTS_REPORT"
      else
        TESTS_REPORT="${TESTS_REPORT:-all pass}"; ok "$TESTS_REPORT"
      fi ;;
    build)
      if (( rc )); then bad "astro build FAILED"; gate_fail+=(build)
      else
        BUILD_REPORT="ok"; ok "astro build clean"
        # ── the two bundle ceilings — they need dist/server, so HERE is the only
        # place they can run. Both existed unwired before 2026-09-22, which by
        # our own doctrine is an unrun gate, not a pass. The 1102 incident shipped
        # through a fully green deploy because nothing measured what an isolate
        # instantiates:
        #   check:server-bundle  ONE global number for all of dist/server
        #   check:route-budget   a PER-ROUTE ceiling — /chat went 0.59MB (perf 97,
        #                        text/perf-baseline.json) to 4.53MB with every
        #                        existing gate green, because the speed gate
        #                        covers 2 routes out of 850.
        # NEITHER is a runtime memory gauge. They bound the margin; they do not
        # diagnose 1102, and a green here must never be reported as "memory is fine".
        # check:server-bundle BLOCKS. check:route-budget REPORTS ONLY — see below.
        if (cd one.ie/web && bun run check:server-bundle) >>"$LOG" 2>&1; then
          ok "check:server-bundle clean"
        else
          bad "check:server-bundle RED — dist/server grew past its ceiling (see $LOG)"
          gate_fail+=(check:server-bundle)
        fi
        # ── route-budget is ADVISORY until its baseline reproduces ────────────
        # Measured 2026-09-22 by two agents independently: a clean build of the
        # baseline's OWN commit, in a different worktree, reads 433 routes UP.
        # The mechanism found: promise-manifest.mjs readdirSync's all of text/,
        # INCLUDING the modified and untracked files of whatever tree you build
        # in, so src/data/promises.json differs per worktree (617,008 B vs
        # 622,896 B) and rolls into every route's closure. A ratchet whose
        # baseline is a function of the author's dirty tree cannot arbitrate,
        # and a gate that cannot arbitrate must never hold a deploy — a
        # permanently red gate teaches every executor to land anyway, which is
        # the failure tests/helpers/substrate-armed.ts exists to prevent.
        # It PRINTS so the numbers stay visible; it does not vote. Restore the
        # block by making the build reproducible, not by deleting this comment.
        if (cd one.ie/web && bun run check:route-budget) >>"$LOG" 2>&1; then
          ok "check:route-budget clean (advisory)"
        else
          warn "check:route-budget reports growth — ADVISORY ONLY, baseline is not reproducible across worktrees; not blocking"
        fi
      fi ;;
    typedb)
      # THIS LANE NEVER TOUCHES gate_fail — that is the whole non-blocking rule,
      # unchanged from the TYPEDB_LANE_NONBLOCKING=1 this gate used to pass: the
      # request path reads the edge snapshot, never TypeDB (CLAUDE.md § The brain
      # and the edge), and three promotes in a row were held by `upstream 500:
      # aborted due to timeout` on the shared cluster (release.sh's promote note,
      # operator ruling 2026-09-13). It is REPORTED loudly either way; a red that
      # nobody prints is how a lane stops meaning anything.
      # SAY THE LANE'S OWN TEST COUNT. The `Tests N passed` line above is now the
      # POOL LANE'S ALONE: splitting the gate took 25 suites out of that sum and
      # dropped the `(2 lanes)` suffix with them, so the headline number FELL on a
      # run where nothing was skipped. A count that moves for a structural reason
      # and says nothing reads as tests vanishing.
      _tdb_n="$(awk '/Tests +[0-9]+ (passed|failed)/ {
                       for (i = 1; i <= NF; i++) { if ($i == "passed") p += $(i-1) + 0
                                                   if ($i == "failed") f += $(i-1) + 0 }
                       n++ }
                     END { if (n) { printf "Tests %d passed", p; if (f > 0) printf " | %d failed", f } }' "$glog" 2>/dev/null)"
      if (( rc < 0 )); then
        TYPEDB_REPORT="unrun — still running when the gates closed; never waited on, never a pass ($glog)"
        warn "typedb lane: $TYPEDB_REPORT"
      elif (( rc )); then
        TYPEDB_REPORT="FAILED (rc=$rc)${_tdb_n:+ — $_tdb_n} — non-blocking, the deploy verdict does not read it ($glog)"
        warn "typedb lane: $TYPEDB_REPORT"
      else
        TYPEDB_REPORT="green${_tdb_n:+ — $_tdb_n}"; ok "typedb lane green (non-blocking)"
      fi ;;
  esac
  # AFTER the case: `tests` only learns reused/waived inside it, and those two
  # booleans are the whole reason this stream exists. A waived pass is a FACT on
  # the run.                                   incident:waived-pass-is-a-fact
  if [[ -n "$_emit_stage" ]]; then
    _emit_args=(--stage "$_emit_stage" --wall-ms "$(( _emit_dur * 1000 ))")
    if (( rc )) && ! { [[ "$_emit_stage" == tests ]] && (( TESTS_WAIVED )); }; then
      _emit_args+=(--status fail --reason "${name}")
    else
      _emit_args+=(--status ok)
    fi
    case "$_emit_stage" in
      tests)
        _emit_args+=(--detail "reused=$( [[ "$TESTS_REPORT" == *REUSED* ]] && echo true || echo false )")
        _emit_args+=(--detail "waived=$( (( TESTS_WAIVED )) && echo true || echo false )") ;;
      typecheck)
        # Which of the five, not just how many — a reader chasing a red gate
        # should not have to open the log to learn the service.
        _emit_args+=(--detail "service=${name#tsc-}") ;;
    esac
    _emit "${_emit_args[@]}"
  fi
done
(( tc_total )) && {
  TYPECHECK_REPORT="$tc_pass/$tc_total services clean"
  (( tc_pass == tc_total )) && ok "$TYPECHECK_REPORT"
}
if (( ${#GATE_NAMES[@]} )); then
  GATE_WALL="$((SECONDS - GATE_T0))s"
  # Per-gate, not just the aggregate — without the breakdown "make the deploy
  # faster" caches whatever finishes inside vitest's shadow for zero seconds.
  #                                    incident:deploy-verdict-closes-the-run
  for i in $(seq 0 $(( ${#GATE_NAMES[@]} - 1 )) ); do
    say "    ${GATE_NAMES[$i]}: ${GATE_DUR[$i]}s"
  done
  say "  gates wall-clock: $GATE_WALL"
  # Repeat the branch HERE, next to the durations it explains. Without it a
  # reader comparing two runs cannot tell a slow gate from a serialised one.
  if (( HEAVY_PARALLEL )); then
    say "  heavy gates: OVERLAPPED (${HEAVY_FREE_GB}GB free >= ${HEAVY_NEED_GB}GB)"
  else
    say "  heavy gates: SERIALISED (${HEAVY_FREE_GB}GB free < ${HEAVY_NEED_GB}GB) — the 6.5x branch"
  fi
  [[ "$BUILD_REPORT" == ok ]] && BUILD_REPORT="$GATE_WALL (overlapped)"
fi
(( ${#gate_fail[@]} )) && die "gates red: ${gate_fail[*]} — nothing deployed"

# ── deferred-pin debt ───────────────────────────────────────────────────────
# deploy is the LAST place verify-fast's deferred pins can come due. Two rules,
# both one-directional: a GREEN full suite PAYS the debt (the suite is a superset
# of every pin) · anything else REFUSES. An unpaid debt with no run to settle it
# is an unrun gate.                                  incident:deferred-pin-debt
DEBT_FILE="${VERIFY_FAST_DEBT_FILE:-${TMPDIR:-/tmp}/one-verify-fast-debt}"
if [[ -s "$DEBT_FILE" ]]; then
  step "Deferred-pin debt"
  say "  ledger: $DEBT_FILE"
  sed 's/^/    /' "$DEBT_FILE" | tee -a "$LOG"
  if (( SKIP_TESTS )) || [[ "$TESTS_REPORT" == "skipped" ]]; then
    die "deferred pins are outstanding and this run did not execute the suite — re-run without --skip-tests"
  fi
  # A waived run is not a green run. The debt exists precisely because the pinned
  # gates were deferred, and a waiver says only that the failures we DID see were
  # substrate — it says nothing about a pin that never got to report.
  if (( TESTS_WAIVED )); then
    die "deferred pins are outstanding and the suite was WAIVED, not green — re-run when TypeDB answers"
  fi
  rm -f "$DEBT_FILE"
  ok "debt settled by the green full suite"
fi
if (( GATES_ONLY )); then
  say ""; ok "gates green in ${GATE_WALL:-0s} — nothing shipped (--gates-only)"
  say "  Typecheck:  $TYPECHECK_REPORT"; say "  Tests:      $TESTS_REPORT"
  # Named even when it is `skipped`/`unrun`: a lane nobody mentions is a lane
  # nobody notices stopped running.
  say "  Typedb:     $TYPEDB_REPORT (non-blocking)"; say "  Log: $LOG"
  # CLOSE THE RUN — the --gates-only exit, which every release.sh promote takes.
  # Without this line the run sits `open` for ever.
  #                                    incident:deploy-verdict-closes-the-run
  _emit_verdict green
  exit 0
fi

# ── Step 4 — credentials (the real work happens in Step 0.4) ────────────────
step "Step 4 — credentials"
ok "auth verified ($CF_AUTH) · API_TOKEN unset"
say "    source: $CF_AUTH_SOURCE"
_cf_agree || die "services disagree about which Cloudflare account they are deploying to"

# ── Step 5 — smoke ──────────────────────────────────────────────────────────
step "Step 5 — smoke"
for cfg in api/wrangler.toml sync/wrangler.toml channels/wrangler.toml \
           one.ie/web/wrangler.toml pay/backend/wrangler.toml; do
  [[ -f "$cfg" ]] || die "missing wrangler config: $cfg"
done
ok "5/5 wrangler configs present"
if (( want_astro )); then
  [[ -d one.ie/web/dist/server ]] || die "one.ie/web/dist/server/ missing after build"
  GZIP_HINT="$(grep -Eo 'gzip: *[0-9.]+ *[KM]iB' "$LOG" | tail -1)"
  say "  dist/server: $(du -sh one.ie/web/dist/server | cut -f1)"
fi
# --env is the decoy trap; assert no config reintroduced an env-scoped target
if grep -q '^\[env\.production' one.ie/web/wrangler.toml 2>/dev/null; then
  warn "one.ie/web/wrangler.toml grew an [env.production] block — the deploy-target trap is reachable again"
fi

# ── Step 6 — approval ───────────────────────────────────────────────────────
step "Step 6 — approval"
TARGETS=()
(( want_gateway )) && TARGETS+=("api → one-gateway")
(( want_sync ))    && TARGETS+=("sync → one-sync (cron-only)")
(( want_agents ))  && TARGETS+=("channels → channels.one.ie")
(( want_pay ))     && TARGETS+=("pay/backend → one-core-worker")
(( want_astro ))   && TARGETS+=("one.ie/web → one-prod (one.ie)")
for t in "${TARGETS[@]}"; do say "    $t"; done
if (( ASSUME_YES || DRY )); then
  ok "auto-approved"
elif [[ "$BRANCH" != "main" ]]; then
  ok "auto-approved (branch $BRANCH ≠ main)"
else
  read -r -p "  deploy to production? [yes/N] " reply
  [[ "$reply" == "yes" ]] || die "aborted at approval"
fi

# ── Step 6.5 — D1 migrations ────────────────────────────────────────────────
MIG_REPORT="skipped"
if (( want_astro )) && ! (( SKIP_MIGRATIONS )); then
  step "Step 6.5 — D1 migrations (DB, remote)"
  if run "d1 migrations apply DB --remote" one.ie/web bunx wrangler d1 migrations apply DB --remote; then
    if (( DRY )); then
      MIG_REPORT="dry-run"
    elif tail -40 "$LOG" | grep -q "No migrations to apply"; then
      MIG_REPORT="none to apply"
    else
      MIG_REPORT="$(grep -Eo '[0-9]{4}_[a-z0-9_]+\.sql' "$LOG" | tail -5 | tr '\n' ' ')"
      MIG_REPORT="applied: ${MIG_REPORT:-see log}"
    fi
    ok "$MIG_REPORT"
  else
    die "D1 migrations failed — never ship worker code ahead of its schema"
  fi
fi

# ── Step 6.6 — D1 migrations (channels) ─────────────────────────────────────
# A SECOND database: channels binds `DB` to `claw` and keeps its own migrations,
# and nothing applied that directory. Same rule as 6.5: schema before code.
#                                                incident:channels-second-d1
MIG_CHAN_REPORT="skipped"
if (( want_agents )) && ! (( SKIP_MIGRATIONS )); then
  step "Step 6.6 — D1 migrations (channels DB, remote)"
  if run "d1 migrations apply DB --remote (channels)" channels bunx wrangler d1 migrations apply DB --remote; then
    if (( DRY )); then
      MIG_CHAN_REPORT="dry-run"
    elif tail -40 "$LOG" | grep -q "No migrations to apply"; then
      MIG_CHAN_REPORT="none to apply"
    else
      MIG_CHAN_REPORT="$(grep -Eo '[0-9]{4}_[a-z0-9_]+\.sql' "$LOG" | tail -5 | tr '\n' ' ')"
      MIG_CHAN_REPORT="applied: ${MIG_CHAN_REPORT:-see log}"
    fi
    ok "$MIG_CHAN_REPORT"
  else
    die "channels D1 migrations failed — never ship worker code ahead of its schema"
  fi
fi

# ── Step 7 — deploy ─────────────────────────────────────────────────────────
step "Step 7 — deploy"
# bash 3.2 on macOS has no associative arrays — two parallel indexed ones
BG_NAMES=() BG_PIDS=()
hfail=()
deploy_bg() { # <name> <dir> <cmd...>
  local name="$1" dir="$2"; shift 2
  if (( DRY )); then say "  [dry] (cd $dir && ${*})"; return; fi
  local out="$LOG_DIR/$name-$STAMP.log"
  ( cd "$ROOT/$dir" && unset CLOUDFLARE_API_TOKEN && "$@" ) >"$out" 2>&1 &
  BG_NAMES+=("$name"); BG_PIDS+=("$!")
  say "  → $name (pid $!, log $out)"
}

# All five upload independently — no shared state, no ordering constraint
# (verified 2026-07-08 for the three workers; astro's only dependency is its own
# build, already done). Astro is slowest (~30s), so it starts first.
# NEVER --env production on any of them — it ships to the one-prod-production decoy.
(( want_astro ))   && deploy_bg astro    one.ie/web   bunx wrangler deploy
(( want_gateway )) && deploy_bg gateway  api          bunx wrangler deploy
(( want_sync ))    && deploy_bg sync     sync         bunx wrangler deploy
(( want_agents ))  && deploy_bg channels channels     bunx wrangler deploy
(( want_pay ))     && deploy_bg pay      pay/backend  bun run deploy

DEPLOY_FAIL=()
for i in $(seq 0 $(( ${#BG_NAMES[@]} - 1 )) ); do
  (( ${#BG_NAMES[@]} )) || break
  name="${BG_NAMES[$i]}"
  if wait "${BG_PIDS[$i]}"; then
    ok "$name deployed"
    cat "$LOG_DIR/$name-$STAMP.log" >>"$LOG"
  else
    bad "$name FAILED"
    tail -30 "$LOG_DIR/$name-$STAMP.log" | sed 's/^/    /' | tee -a "$LOG"
    DEPLOY_FAIL+=("$name")
  fi
done
(( ${#DEPLOY_FAIL[@]} )) && die "parallel deploy failed: ${DEPLOY_FAIL[*]}"
if ! (( DRY )); then
  for i in $(seq 0 $(( ${#BG_NAMES[@]} - 1 )) ); do
    (( ${#BG_NAMES[@]} )) || break
    git rev-parse HEAD > "$(mark_file "${BG_NAMES[$i]}")"
  done
fi
(( want_astro && ! DRY )) && GZIP_HINT="$(grep -Eo 'gzip: *[0-9.]+ *[KM]iB' "$LOG_DIR/astro-$STAMP.log" | tail -1)"

# ── Step 8 — health ─────────────────────────────────────────────────────────
HEALTH_REPORT="skipped"
if (( SKIP_HEALTH || DRY )); then
  step "Step 8 — health (skipped)"
else
  step "Step 8 — health (custom domains only)"
  probe() { # <label> <url> <assert-substring|-> ; 3 tries, backoff
    local label="$1" url="$2" want="$3" i body code
    for i in 1 2 3; do
      body="$(curl -sL --max-time 20 -w $'\n%{http_code}' "${url}?_t=$(date +%s)" 2>/dev/null)"
      code="${body##*$'\n'}"; body="${body%$'\n'*}"
      if [[ "$code" == "200" ]] && { [[ "$want" == "-" ]] || [[ "$body" == *"$want"* ]]; }; then
        ok "$label 200"; return 0
      fi
      sleep $((i * 3))
    done
    bad "$label unhealthy (last code=${code:-none})"
    return 1
  }
  # probe all four at once — they are independent hosts; serial cost was the
  # sum of four round trips plus, on a bad deploy, three backoff sleeps each
  hp=0 ht=0 PNAMES=() PPIDS=()
  probe_bg() { probe "$2" "$3" "$4" >"$LOG_DIR/health-$1-$STAMP.log" 2>&1 & PNAMES+=("$1"); PPIDS+=("$!"); ht=$((ht+1)); }
  (( want_gateway )) && probe_bg gateway  "api.one.ie/health"  https://api.one.ie/health      -
  (( want_astro ))   && probe_bg astro    "one.ie/api/health"  https://one.ie/api/health      '"status":"ok"'
  (( want_agents ))  && probe_bg channels "channels.one.ie"    https://channels.one.ie/health -
  (( want_pay ))     && probe_bg pay      "pay.one.ie/status"  https://pay.one.ie/status      '"ok"'
  for i in $(seq 0 $(( ${#PNAMES[@]} - 1 )) ); do
    (( ${#PNAMES[@]} )) || break
    if wait "${PPIDS[$i]}"; then hp=$((hp+1)); else hfail+=("${PNAMES[$i]}"); fi
    cat "$LOG_DIR/health-${PNAMES[$i]}-$STAMP.log" | tee -a "$LOG"
  done
  (( want_sync )) && ok "sync — cron-only, deploy success IS the health signal"
  HEALTH_REPORT="$hp/$ht HTTP 200"
  (( want_sync )) && HEALTH_REPORT="$HEALTH_REPORT + sync deploy-confirmed"

  # ── deploy receipt ────────────────────────────────────────────────────────
  # Three honesty rules the data itself forces: gates here are only ever GREEN (a
  # red one died long before Step 8) · `healthy` is NULL for sync, which is never
  # probed · `deployed` is BG_NAMES (what uploaded), never TARGETS (the intent).
  # `|| true` so a failed write cannot fail a shipped deploy.
  #                                        incident:deploy-receipt-honesty
  _receipt="$ROOT/one.ie/web/src/lib/generated/deploy-receipt.json"
  {
    mkdir -p "$(dirname "$_receipt")"
    {
      printf '{\n  "stamp": "%s",\n  "headSha": "%s",\n  "mode": "%s",\n' \
        "$STAMP" "${HEAD_SHA:-unknown}" "$MODE"
      printf '  "gates": ['
      _sep=""
      for i in $(seq 0 $(( ${#GATE_NAMES[@]} - 1 )) ); do
        (( ${#GATE_NAMES[@]} )) || break
        if   (( ${GATE_RC[$i]} <  0 )); then _res=unrun
        elif (( ${GATE_RC[$i]} >  0 )); then _res=fail
        else                                 _res=pass; fi
        printf '%s\n    {"name": "%s", "seconds": %s, "result": "%s"}' \
          "$_sep" "${GATE_NAMES[$i]}" "${GATE_DUR[$i]}" "$_res"
        _sep=","
      done
      (( ${#GATE_NAMES[@]} )) && printf '\n  '
      printf '],\n  "workers": ['
      _sep=""
      for i in $(seq 0 $(( ${#BG_NAMES[@]} - 1 )) ); do
        (( ${#BG_NAMES[@]} )) || break
        _n="${BG_NAMES[$i]}"
        if   [[ "$_n" == sync ]];              then _h=null    # never probed
        # `${hfail[*]-}` not `${hfail[*]}` — bash 3.2 under `set -u` treats an
        # EMPTY array as unbound.      incident:empty-array-unbound-bash32
        elif [[ " ${hfail[*]-} " == *" $_n "* ]]; then _h=false
        else                                        _h=true; fi
        printf '%s\n    {"name": "%s", "deployed": true, "healthy": %s}' "$_sep" "$_n" "$_h"
        _sep=","
      done
      (( ${#BG_NAMES[@]} )) && printf '\n  '
      printf ']\n}\n'
    } >"$_receipt" && say "  receipt: $_receipt"
  } || true
fi

# ── Report ──────────────────────────────────────────────────────────────────
step "Step 9 — speed (advisory)"
# Post-deploy Lighthouse on the LIVE site. ADVISORY — the ENFORCED ratchet is
# `bun run speed` pre-deploy against the local build. Exit 2 = INCONCLUSIVE and
# is never a pass.                                incident:speed-step-detached
if (( DRY )); then
  echo "  (dry run — speed check skipped)" | tee -a "$LOG"
elif [[ "${SKIP_SPEED:-0}" == "1" ]]; then
  echo "  (SKIP_SPEED=1 — skipped)" | tee -a "$LOG"
else
  sp_out="$LOG_DIR/speed-$STAMP.log"
  sp_cmd=(node "$(dirname "${BASH_SOURCE[0]}")/speed-check.mjs" --prod --runs 3)
  # One verdict function for both the inline and the detached path. bad() only
  # PRINTS here: Step 9 runs after the ship, so it reports and does not block.
  #                                             incident:speed-step-detached
  speed_verdict() {
    grep -E 'perf=|faster|SLOWER|performance:|advisory only' "$sp_out" | sed 's/^/    /' | tee -a "$LOG" || true
    case "$1" in
      0) ok   "speed: nothing got slower (live site)" ;;
      1) warn "speed: REGRESSION on the live site — ADVISORY, deploy not blocked — $sp_out" ;;
      2) warn "speed: INCONCLUSIVE (not a pass) — ADVISORY — $sp_out" ;;
      # 3 = regressions found, deliberately not gating (--prod). Distinct from 0
      # so it can never render as "nothing got slower" — which it did, twice, in
      # the same log that printed the regression two lines above.
      3) warn "speed: REGRESSION on the live site — advisory, not gating — $sp_out" ;;
      # 124 is run_bounded's own code: Lighthouse hung past the cap and was
      # reaped. Reported as unrun, never as a pass.
      124) warn "speed: TIMED OUT (not a pass) — ADVISORY — $sp_out" ;;
      *) warn "speed: unexpected exit $1 — ADVISORY — $sp_out" ;;
    esac
  }
  if [[ "${SPEED_SYNC:-0}" == "1" ]]; then
    # Inline — the operator wants the number before leaving the terminal.
    run_bounded "${SPEED_TIMEOUT:-600}" "${sp_cmd[@]}" >"$sp_out" 2>&1
    speed_verdict $?
  else
    # DETACHED by default — it was 166s of a 227s pipeline, after the site had
    # already shipped and passed health. Bounded so a hung Chrome cannot outlive
    # the deploy.                                incident:speed-step-detached
    (
      run_bounded "${SPEED_TIMEOUT:-600}" "${sp_cmd[@]}" >"$sp_out" 2>&1
      rc=$?
      { echo ""; echo "══ Step 9 — speed (detached, landed $(date -u +%FT%TZ))"; } >>"$LOG"
      speed_verdict $rc >>"$LOG" 2>&1
    ) >/dev/null 2>&1 </dev/null &
    disown 2>/dev/null || true
    say "  speed: measuring the live site in the background (pid $!, ~3 min)"
    say "         verdict lands in $LOG · raw: $sp_out · inline: SPEED_SYNC=1"
  fi
fi

step "Report"
say "  Mode:       $MODE"
say "  Branch:     $BRANCH @ $HEAD_SHA"
say "  Typecheck:  $TYPECHECK_REPORT"
say "  Tests:      $TESTS_REPORT"
say "  Typedb:     $TYPEDB_REPORT (non-blocking)"
say "  Build:      $BUILD_REPORT"
say "  Migrations: $MIG_REPORT"
say "  Deployed:   ${TARGETS[*]:-none}"
say "  Health:     $HEALTH_REPORT"
[[ -n "${sp_out:-}" && "${SPEED_SYNC:-0}" != "1" ]] && say "  Speed:      detached — $sp_out"
(( ${#SKIPPED_UNCHANGED[@]} )) && say "  Unchanged:  ${SKIPPED_UNCHANGED[*]} (skipped, --changed)"
[[ -n "${GZIP_HINT:-}" ]] && say "  Bundle:     $GZIP_HINT"
say "  Log:        $LOG"

# The record the /deploy page renders, on BOTH exits — a record holding only
# green runs cannot be read for a trend. Guarded: a recorder fault must never
# turn a good deploy into a bad exit.       incident:deploy-record-trunk-leg
_record_run() {
  local verdict="$1"
  [[ -x "$ROOT/.claude/scripts/deploy-record.sh" ]] || return 0
  (( DRY )) && return 0
  local -a args=(--door "deploy${MODE:+ $MODE}" --target "${TARGETS[*]:-—}"
                 --branch "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
                 --sha "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '')"
                 --verdict "$verdict" --wall "$(( SECONDS ))"
                 --note "heavy=$( (( ${HEAVY_PARALLEL:-0} )) && echo parallel || echo serial ) memFreeGb=${HEAVY_FREE_GB:-?} needGb=${HEAVY_NEED_GB:-?}")
  local i st
  for i in "${!GATE_NAMES[@]}"; do
    # -1 means the gate never reported. It is recorded as `unrun`, never as a
    # pass and never as a zero — the page draws it as an outline for that reason.
    if   [[ "${GATE_RC[$i]}" == 0 ]];  then st=pass
    elif [[ "${GATE_RC[$i]}" == -1 ]]; then st=unrun
    else st=fail; fi
    args+=(--phase "${GATE_NAMES[$i]}:$(( GATE_T[i] - GATE_T0 )):$(( GATE_DUR[i] < 0 ? 0 : GATE_DUR[i] )):gate:$st")
  done
  bash "$ROOT/.claude/scripts/deploy-record.sh" "${args[@]}" >/dev/null 2>&1 || true
  # THE TRUNK LEG. The row lands in the PRIMARY worktree and NOTHING commits it,
  # so /deploy never renders it until someone does. Deliberately manual, and
  # printed at the moment it becomes true.  incident:deploy-record-trunk-leg
  local pend; pend="$(bash "$ROOT/.claude/scripts/deploy-record.sh" --pending 2>/dev/null)" || true
  [[ -n "$pend" ]] && say "$pend"
  return 0
}

if (( ${#hfail[@]} )); then
  _emit --stage health --status fail --reason "unhealthy: ${hfail[*]}"
  _emit_verdict red
  _record_run degraded
  # A degraded ship is an outcome. Close it as one.
  # --only dims,feedback: `deploy` is a LABEL, not a plan slug — the task leg
  # would close a plan named deploy.        incident:deploy-record-trunk-leg
  bash "$(dirname "${BASH_SOURCE[0]}")/do-close.sh" deploy --status failed --only dims,feedback || true
  say ""
  bad "degraded — unhealthy: ${hfail[*]}"
  say "  rollback: cd one.ie/web && bunx wrangler rollback --name one-prod"
  exit 1
fi
_emit --stage health --status ok --detail "probes=${#TARGETS[@]}"
_emit_verdict green
_record_run green
bash "$(dirname "${BASH_SOURCE[0]}")/do-close.sh" deploy --only dims,feedback || true
say ""
ok "deploy:success"
