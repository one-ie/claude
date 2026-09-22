#!/usr/bin/env bash
# deploy-gap.sh — which service's LIVE deployment is behind its committed source?
#
# manifest: needs-env  (reads a Cloudflare credential; no monorepo path — it DISCOVERS
#                       services by finding wrangler configs rather than naming them)
#
# PULLED FROM apps/vespio/scripts/client-gap.sh 2026-09-22, where it was written for the
# agency's client nodes. It needed one change to work here and that change is the point:
# vespio has one wrangler config per node; ONE has ~200, because every .claude/worktrees/*
# and .release carries a full copy of all five services. Without the exclusion below this
# reports the same service a dozen times, once per worktree, each with a different verdict.
#
# LIVES IN scripts/, NOT .claude/scripts/. `.claude/` is GENERATED output synced
# from one-ie (doctrine §11); anything put there dies at the next sync.
#
# The agency's core question wearing a deploy-gap costume. For every deployable
# node found ON DISK (never a hardcoded list — that is the /status defect,
# doctrine §1) it compares the newest deployment on Cloudflare against the newest
# commit that touched something that MATTERS in that node's source.
#
# VERDICTS — five, not three. Collapsing them loses the useful one.
#   ok                every content commit predates the newest deployment
#   behind            an undeployed commit touches src/public/config/data
#   never-provisioned the config still ships change-me binding IDs; this node has
#                     never been pointed at real infra
#   absent            the worker/project does not exist on the account (measured
#                     upstream: three workers had perfect config parity and were
#                     simply not there)
#   unknown           no wrangler / no credential. NEVER "ok" — an unrun check is
#                     not a green one (an unrun check is never a green one).
#
# CONTENT-AWARE, NOT HOURS-AWARE (an hours threshold trips on docs commits and gets muted inside a week): an hours threshold trips on docs commits
# and gets muted inside a week. `dist/` is TRACKED in this repo, so it is
# excluded or every build would make every node permanently red.
#
# EXIT  0 = every node ok   1 = at least one behind   2 = unknown/absent/error
#
#   bash .claude/scripts/deploy-gap.sh
#   bash .claude/scripts/deploy-gap.sh --json
#   bash .claude/scripts/deploy-gap.sh --check-red     # prove the checker can fail
set -uo pipefail   # no -e: a failed probe must render a row, not kill the run

# TWO levels up, not one: vespio's copy lives at scripts/, this one at
# .claude/scripts/. With /.. it resolved ROOT to .claude/ — a directory with no
# wrangler config in it — so `find .` returned nothing and the run went GREEN on
# zero nodes. Caught 2026-09-22 on the port, by the empty-set guard below.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_BAD=$'\033[31m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'; C_B=$'\033[1m'
MODE="${1:-}"

# ── the verdict is a PURE FUNCTION of (deployed_epoch, changed_paths) ─────────
# Factored out so --check-red can drive it with synthetic inputs. A checker you
# have only ever watched pass is not evidence (doctrine §3).
CONTENT_RE='(^|/)(src|public|data)/|(^|/)(astro|one)\.config\.|(^|/)(package|wrangler)\.(json|jsonc|toml)$'
verdict() {  # verdict <deployed_epoch|unknown> <newline-separated changed paths>
  local dep="$1" paths="$2" p hit=0
  [ "$dep" = "unknown" ] && { echo "unknown"; return; }
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in */dist/*|dist/*) continue ;; esac      # tracked build output
    if [[ "$p" =~ $CONTENT_RE ]]; then hit=1; echo "  changed: $p" >&2; fi
  done <<< "$paths"                                      # here-string, never a
                                                         # pipe: `producer|grep -q`
                                                         # returns 141 on MATCH
                                                         # under pipefail (§3)
  [ "$hit" -eq 1 ] && echo "behind" || echo "ok"
}

# ── discover every deployable node from disk ─────────────────────────────────
# name|kind|dir|config   — kind is read from the config SHAPE, because
# `wrangler deployments list --name` cannot answer for a Pages project and would
# report a deployed node as "absent". That would read as a finding and be a bug.
discover() {
  local f name kind
  while IFS= read -r f; do
    case "$f" in */dist/*) continue ;; esac
    if grep -q 'pages_build_output_dir' "$f" 2>/dev/null; then kind=pages; else kind=worker; fi
    name=$(sed -n 's/^[[:space:]]*"\{0,1\}name"\{0,1\}[[:space:]]*[:=][[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1)
    [ -z "$name" ] && name="(no name in config)"
    printf '%s|%s|%s|%s\n' "$name" "$kind" "$(dirname "$f")" "$f"
  done < <(find . -name 'wrangler.toml' -o -name 'wrangler.jsonc' -o -name 'wrangler.json' \
             | grep -v node_modules | grep -v '/dist/' \
             | grep -v '/.claude/worktrees/' | grep -v '/.release/' | sort)
}

have_cred() {
  command -v npx >/dev/null 2>&1 || return 1
  [ -n "${CLOUDFLARE_API_TOKEN:-}" ] && return 0
  [ -f "$HOME/.wrangler/config/default.toml" ] && return 0
  [ -d "$HOME/Library/Preferences/.wrangler" ] && return 0
  return 1
}

deployed_epoch() {  # deployed_epoch <name> <kind>  -> epoch | "unknown" | "absent"
  local name="$1" kind="$2" out
  have_cred || { echo unknown; return; }
  if [ "$kind" = pages ]; then
    out=$(npx --yes wrangler@latest pages deployment list --project-name "$name" 2>&1)
  else
    out=$(npx --yes wrangler@latest deployments list --name "$name" 2>&1)
  fi
  # capture-then-match; never `| grep -q` (§3)
  if grep -qiE 'does not exist|could not be found|not found|no project' <<< "$out"; then echo absent; return; fi
  if grep -qiE 'not logged in|authentication|API token|credentials' <<< "$out"; then echo unknown; return; fi
  local ts
  ts=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' <<< "$out" | sort | tail -1)
  [ -z "$ts" ] && { echo unknown; return; }
  date -j -f '%Y-%m-%dT%H:%M:%S' "$ts" +%s 2>/dev/null || echo unknown
}

# ── --check-red: prove all four arms, with pinned inputs ─────────────────────
if [ "$MODE" = "--check-red" ]; then
  fail=0
  a=$(verdict 1000000000 $'site/src/pages/index.astro\nREADME.md' 2>/dev/null)
  printf 'arm 1  content commit undeployed  -> %s  (want behind)\n' "$a"; [ "$a" = behind ] || fail=1
  b=$(verdict 1000000000 $'DEPLOY.md\ntext/doctrine.md\nsite/dist/client/500.html' 2>/dev/null)
  printf 'arm 2  docs+dist only             -> %s  (want ok)\n' "$b"; [ "$b" = ok ] || fail=1
  c=$(verdict unknown $'site/src/x.astro' 2>/dev/null)
  printf 'arm 3  no credential              -> %s  (want unknown, never ok)\n' "$c"
  [ "$c" = unknown ] || fail=1
  d=$(verdict 1000000000 $'clients/elitemoversca/site/data/x.json' 2>/dev/null)
  printf 'arm 4  client data changed        -> %s  (want behind)\n' "$d"; [ "$d" = behind ] || fail=1
  # arm 5 — the exit-code map. "absent" and "unknown" must never exit 0.
  # Measured upstream: three workers had perfect config parity and simply did
  # not exist on the account. That must not read as ok.
  for v in unknown absent; do
    case "$v" in ok) e=0 ;; behind) e=1 ;; *) e=2 ;; esac
    printf 'arm 5  verdict %-8s              -> exit %s  (want non-zero)\n' "$v" "$e"
    [ "$e" -ne 0 ] || fail=1
  done
  if [ "$fail" -eq 0 ]; then echo "check-red: all five arms behaved — the checker CAN go red"; exit 0
  else echo "check-red: FAILED — the verdict function is broken"; exit 1; fi
fi

# ── the run ──────────────────────────────────────────────────────────────────
# worst starts at -1, NOT 0. At 0 an empty node set falls straight through to
# "every deployable node is up to date" and exits 0 — a checker that measured
# nothing reporting green, which is the exact failure this script exists to
# catch. Zero nodes is now its own refusal below.
worst=-1; rows=()
have_cred || { printf '  %bno Cloudflare credential (no CLOUDFLARE_API_TOKEN, no wrangler login)%b\n' "$C_WARN" "$C_0"
               printf '  %bevery deployment column below is UNKNOWN, not ok%b\n\n' "$C_DIM" "$C_0"; }

while IFS='|' read -r name kind dir cfg; do
  [ -z "$name" ] && continue
  # never-provisioned beats every other verdict: change-me bindings mean this
  # config has never been pointed at real infra.
  prov=ok
  grep -q 'change-me' "$cfg" 2>/dev/null && prov=never-provisioned

  dep=$(deployed_epoch "$name" "$kind")
  if [ "$dep" = unknown ] || [ "$dep" = absent ]; then
    v="$dep"; changed=""
  else
    changed=$(git log --since="@$dep" --name-only --pretty=format: -- "$dir" 2>/dev/null | sort -u)
    v=$(verdict "$dep" "$changed" 2>/dev/null)
  fi
  [ "$prov" = never-provisioned ] && [ "$v" != behind ] && v=never-provisioned

  last=$(git log -1 --format='%h %ad' --date=short -- "$dir" 2>/dev/null)
  case "$v" in
    ok)    col=$C_OK;   [ "$worst" -lt 0 ] && worst=0 ;;
    behind) col=$C_BAD; worst=1 ;;
    # -lt 1, not -eq 0: with worst starting at -1 an `-eq 0` test never fires, so a
    # run of twelve UNKNOWN nodes kept the -1 sentinel and printed "no node found".
    *)     col=$C_WARN; [ "$worst" -lt 1 ] && worst=2 ;;
  esac
  printf '  %b%-11s%b %-20s %-7s %-32s %s\n' "$col" "$v" "$C_0" "$name" "$kind" "$dir" "${last:-no commits}"
  rows+=("{\"name\":\"$name\",\"kind\":\"$kind\",\"dir\":\"$dir\",\"verdict\":\"$v\"}")
done < <(discover)

if [ "$MODE" = "--json" ]; then
  printf '{"nodes":[%s]}\n' "$(IFS=,; echo "${rows[*]}")"
fi
echo
case "$worst" in
  -1) echo "  NO deployable node found — this measured nothing and is not a pass"; exit 2 ;;
  0) echo "  every deployable node is up to date"; exit 0 ;;
  1) echo "  at least one node is BEHIND its committed source"; exit 1 ;;
  2) echo "  could not measure at least one node — unknown is not ok (an unrun check is never a green one)"; exit 2 ;;
esac
