#!/usr/bin/env bash
# do-prove.sh — PROVE (pure). Promise-check moved to do-reconcile.sh (design canon).
# Auto-detects surface from changed files, then RUNS the proof for frontend surfaces
# (chrome-headless-shell page check via chrome.mjs, curl fallback against prod).
#
# Usage:
#   do-prove.sh [--route <path>]... [--base <url>] [<changed-path>|<cycle-slug>]...
#   do-prove.sh --self-test
#   git diff --name-only | do-prove.sh
#
# Arg contract:
#   - Positional args that exist as files/dirs are treated as changed paths.
#   - Positional args that do NOT exist on disk (e.g. a cycle slug) are ignored
#     for surface detection; changed paths then come from `git diff --name-only HEAD`.
#   - --route <path> (repeatable) forces frontend surface + names the route(s) to prove.
#   - --base <url> proves against <url> instead of the default localhost base.
#   - stdin (non-tty) supplies changed paths when no positional paths are given.
#   - AN UNRECOGNISED FLAG IS A HARD ERROR (exit 2). It was not, until 2026-09-07,
#     and that is how the launch promise came to prove a laptop. `text/bring-one-to-life.md`
#     deliverable 6 read `--route /keys --base https://one.ie`; `--base` did not
#     exist, so BOTH tokens fell through the lenient `*)` branch as "not a path
#     (cycle slug?)" and the run silently used the localhost default. Measured that
#     morning with a dev server up on :4321:
#       PROVE: note — '--base' is not a path (cycle slug?); …
#       PROVE: ok / — http=200, 0 console/js errors (dev http://localhost:4321)
#       PROVE: pass (1 route(s) proven)          ← exit 0, prod never contacted
#     The leniency is deliberate for BARE tokens (a cycle slug is passed
#     legitimately — do-w4-gates.sh:210, do-smoke.sh:85-88). It is never correct
#     for a token starting with `-`: nobody passes a flag they do not mean.
#
# --base semantics (matches land.sh:344-345, which pins both bases by hand and
# says why): --base PINS THE FALLBACK TOO, unless PROVE_PROD_URL is explicitly
# exported. Setting only the dev base would rebuild the same defect one layer
# down — an unreachable `--base https://staging.x` would fall through to
# PROD_URL and prove PRODUCTION while reporting it as staging.
# And an explicit --base that ANSWERS NOTHING exits non-zero rather than
# `PROVE: skipped` (exit 0): do-promise-settle.sh runs a promise's proof: string
# verbatim and reads the exit code, so a skipped prod probe would settle the
# promise KEPT with the site down. An unrun gate is not a pass. Bare invocations
# keep the old skip-is-0 semantics — land.sh:346-350 reads the ROUTE COUNT and
# factory-walk.sh:294 matches `PROVE: skipped` → unrun, and both rely on it.
#
# Env:
#   PROVE_BASE_URL   dev base for browser check (default http://localhost:4321).
#                    `--base <url>` is the flag form of exactly this, and wins.
#   PROVE_PROD_URL   prod fallback base       (default https://one.ie)
#   PROVE_CHECK_CMD  optional check command for non-frontend surfaces; if set and
#                    it fails, do-prove.sh exits nonzero.
#   PROVE_SESSION_COOKIE
#                    `name=value` session cookie, sent on BOTH legs — chrome.mjs
#                    already reads this env var itself; the curl leg now sends it
#                    as a Cookie header. Needed to prove any authed route
#                    (anything under /u/<slug>/…). Against a LOCAL dev base it is
#                    acquired automatically via one.ie/web/scripts/dev-sign-in.ts
#                    so a promise's proof: still runs in a bare shell; set it by
#                    hand for a remote base. Sent to a localhost base only — the
#                    prod fallback leg never carries it.
#   PROVE_NO_SESSION=1
#                    skip session acquisition — the documented way to drive the
#                    landing rule red on demand (`--route /u/one/tasks` then fails
#                    with "landed on /signin"). Without it the red state is only
#                    reachable when sign-in itself fails.
#
# LANDING RULE (2026-08-04): a route is proven only if the browser/curl ENDED UP
# on the path that was asked for. Measured: `--route /u/one/tasks` signed-out
# 302s to /signin, which renders 200 with zero console errors — so do-prove
# reported "ok" and a promise's proof clause went green on the sign-in page. The
# tasks page was never loaded. Every authed `/u/one/*` clause in the corpus had
# the same hole. Path is compared without query or trailing slash, so
# `/u/one/in?dest=tasks` still proves itself.
#
# Exit codes: 0 = pass or skipped (no reachable environment) · 1 = a reachable
# page failed (HTTP >= 500 / 404 / status 0 / console+JS errors / landed on a
# different path than requested), a declared check failed, or an explicit --base
# answered nothing · 2 = usage error (unknown flag, or a flag missing its value).
#
# --self-test drives both halves red and green with no live server required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_URL="${PROVE_BASE_URL:-http://localhost:4321}"
PROD_URL="${PROVE_PROD_URL:-https://one.ie}"
BROWSER_CHECK="$ROOT/.claude/scripts/chrome.mjs"

routes=()
paths=()
base_explicit=0
self_test=0

prove_usage() {
  echo "PROVE: usage: do-prove.sh [--route <path>]... [--base <url>] [--self-test] [<changed-path>|<cycle-slug>]..."
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --route)
      [ "$#" -ge 2 ] || { echo "PROVE: --route requires a value"; exit 2; }
      routes+=("$2"); shift 2 ;;
    --base)
      # The flag form of PROVE_BASE_URL. Trailing slash stripped so
      # "$BASE_URL$route" never produces a double slash.
      [ "$#" -ge 2 ] || { echo "PROVE: --base requires a value"; exit 2; }
      BASE_URL="${2%/}"; base_explicit=1; shift 2 ;;
    --self-test)
      self_test=1; shift ;;
    -h|--help)
      prove_usage; exit 0 ;;
    -*)
      # THE ROOT CAUSE, closed. A token that looks like a flag and is not one is
      # a caller asking for something this script cannot do — never a cycle slug.
      # Silently continuing is how `--base https://one.ie` became a no-op.
      echo "PROVE: unknown flag '$1'" >&2
      prove_usage >&2
      exit 2 ;;
    *)
      # A real path (exists on disk relative to root or cwd) counts as a changed
      # path; anything else (a cycle slug) is noted and ignored for detection.
      if [ -e "$1" ] || [ -e "$ROOT/$1" ]; then
        paths+=("$1")
      else
        echo "PROVE: note — '$1' is not a path (cycle slug?); using git diff for surface detection"
      fi
      shift ;;
  esac
done

# An explicit --base means "prove HERE, nowhere else". Only an explicitly
# exported PROVE_PROD_URL may name a different fallback (land.sh does exactly
# that, pinning both to the dev URL).
if [ "$base_explicit" -eq 1 ] && [ -z "${PROVE_PROD_URL:-}" ]; then
  PROD_URL="$BASE_URL"
fi

if [ "$self_test" -eq 1 ]; then
  exec bash "$ROOT/.claude/scripts/do-prove-selftest.sh" "$ROOT/.claude/scripts/do-prove.sh"
fi

# stdin (piped) paths
if [ "${#paths[@]}" -eq 0 ] && [ ! -t 0 ]; then
  while IFS= read -r l; do [ -n "$l" ] && paths+=("$l"); done || true
fi

# git fallback
if [ "${#paths[@]}" -eq 0 ]; then
  while IFS= read -r l; do [ -n "$l" ] && paths+=("$l"); done \
    < <(git -C "$ROOT" diff --name-only HEAD 2>/dev/null || true)
fi

if [ "${#paths[@]}" -eq 0 ] && [ "${#routes[@]}" -eq 0 ]; then
  echo "PROVE: no changes"; exit 0
fi

# Surface detection — substrate wins (upstream), then api, then frontend, else backend
surface=backend
for p in "${paths[@]+"${paths[@]}"}"; do
  case "$p" in
    *.tql|schema/*) surface=substrate; break ;;
    */pages/api/*|*/api/*) surface=api ;;
    *.astro|*.tsx) [ "$surface" != "api" ] && surface=frontend ;;
  esac
done
# Explicit --route forces a frontend proof
[ "${#routes[@]}" -gt 0 ] && surface=frontend
echo "surface: $surface"

# ---------- non-frontend surfaces ----------
if [ "$surface" != "frontend" ]; then
  case "$surface" in
    api)       proof="contract test (vitest+msw) + curl per surface — route + SDK + MCP + CLI (four-surface rule)" ;;
    backend)   proof="curl against the DEPLOYED runtime (local verify is necessary, not sufficient)" ;;
    substrate) proof="/sync reconcile (TypeDB↔KV↔D1↔SUI) + TypeQL returns the new shape + types compile downhill" ;;
  esac
  echo "proof:   $proof"
  if [ -n "${PROVE_CHECK_CMD:-}" ]; then
    echo "PROVE: running declared check: $PROVE_CHECK_CMD"
    if bash -c "$PROVE_CHECK_CMD"; then
      echo "PROVE: pass"; exit 0
    else
      echo "PROVE: fail (declared check command failed)"; exit 1
    fi
  fi
  echo "PROVE: pass (no declared check command — proof action stated above)"
  exit 0
fi

# ---------- frontend surface: actually prove the page loads ----------

# Route discovery: --route args > .w2-surface-checklist.json > derive from changed pages
if [ "${#routes[@]}" -eq 0 ] && [ -f "$ROOT/.w2-surface-checklist.json" ] && command -v jq >/dev/null 2>&1; then
  while IFS= read -r r; do [ -n "$r" ] && routes+=("$r"); done < <(
    jq -r '((.surfaces // []) | map(.routes // [])[] | .[]?), ((.routes // [])[]?)' \
      "$ROOT/.w2-surface-checklist.json" 2>/dev/null | sort -u
  ) || true
fi
if [ "${#routes[@]}" -eq 0 ]; then
  for p in "${paths[@]+"${paths[@]}"}"; do
    case "$p" in
      one.ie/web/src/pages/api/*) ;; # api routes, not pages
      one.ie/web/src/pages/*)
        r="${p#one.ie/web/src/pages}"
        r="${r%.astro}"; r="${r%.md}"; r="${r%.mdx}"; r="${r%.ts}"; r="${r%.tsx}"
        [ "${r##*/}" = "index" ] && r="${r%index}"
        r="${r%/}"; [ -z "$r" ] && r="/"
        # skip dynamic routes — no concrete param to check
        case "$r" in *\[*\]*) continue ;; esac
        routes+=("$r") ;;
    esac
  done
fi
[ "${#routes[@]}" -eq 0 ] && routes=("/")

# De-dupe (portable — macOS bash 3.2 has no mapfile)
deduped=()
while IFS= read -r r; do deduped+=("$r"); done < <(printf '%s\n' "${routes[@]}" | awk '!seen[$0]++')
routes=("${deduped[@]}")

dev_up=0
if curl -sf -o /dev/null --max-time 4 "$BASE_URL/" 2>/dev/null; then dev_up=1; fi

# A session turns "the sign-in page rendered" into "the page under test rendered".
# chrome.mjs reads PROVE_SESSION_COOKIE from the environment on its own (it is
# inherited by the `node` call below); the curl leg needs it passed explicitly.
#
# Auto-acquire against a LOCAL dev server only. A promise's proof: has to run in
# a bare shell — that is the whole point of the kill-switch — so requiring a
# human to export a cookie first would just move the fail-open one level up.
# Strictly gated: localhost/127.0.0.1 base, dev-sign-in.ts present, no cookie
# already set. Never against a remote host, and the value is never echoed.
_prove_local_base() {
  case "$BASE_URL" in
    http://localhost:*|http://localhost|http://127.0.0.1:*|http://127.0.0.1) return 0 ;;
    *) return 1 ;;
  esac
}
# LAZY, and only on a /signin bounce. Signing in up front changes the answer for
# routes that were already fine: locally, DEV_SLUG lets a signed-out request
# render /u/one/* as workspace `one`, while a real session is tony@one.ie — so
# an eager session turned `--route /u/one/workflows` from a genuine pass into
# "landed on /u/tony/workflows". Measured 2026-08-04. Try signed-out first; only
# a bounce to the login wall is worth a second attempt.
#
# PROVE_NO_SESSION=1 disables the retry entirely. Without it the landing rule's
# red half is only reachable when sign-in itself fails, i.e. by accident — and a
# gate nobody can drive red on demand is what this whole change exists to
# prevent. The documented two-line matrix:
#   PROVE_NO_SESSION=1 do-prove.sh --route /u/one/tasks   → FAIL, landed on /signin
#                      do-prove.sh --route /u/one/tasks   → ok (retried with a session)
_session_tried=0
prove_acquire_session() { # → 0 if a cookie is now available, 1 otherwise
  [ -n "${PROVE_SESSION_COOKIE:-}" ] && return 0
  [ -n "${PROVE_NO_SESSION:-}" ] && return 1
  [ "$_session_tried" -eq 1 ] && return 1
  _session_tried=1
  _prove_local_base || return 1
  local c=""
  # Preferred: the repo's own script. It seeds the credential in local D1 first,
  # so it only works from a tree that has .wrangler/state — i.e. the main tree,
  # which is where promise proofs actually run.
  if [ -f "$ROOT/one.ie/web/scripts/dev-sign-in.ts" ] && command -v bun >/dev/null 2>&1; then
    c="$( (cd "$ROOT/one.ie/web" && bun scripts/dev-sign-in.ts 2>/dev/null) \
          | sed -n 's/^Set-Cookie: //p' | head -1 || true)"
  fi
  # Fallback for a worktree (no local D1 state): plain HTTP sign-in, but only
  # with credentials the caller supplied. No password is hardcoded here —
  # one.ie/web/scripts/dev-sign-in.ts stays the single source of the dev creds.
  if [ -z "$c" ] && [ -n "${OWNER_EMAIL:-}" ] && [ -n "${DEV_PASSWORD:-}" ]; then
    c="$(curl -s -D - -o /dev/null --max-time 20 -X POST \
           -H 'Content-Type: application/json' -H "Origin: $BASE_URL" \
           --data "{\"email\":\"${OWNER_EMAIL}\",\"password\":\"${DEV_PASSWORD}\"}" \
           "$BASE_URL/api/auth/sign-in/email" 2>/dev/null \
         | sed -n 's/^[Ss]et-[Cc]ookie: \(better-auth\.session_token=[^;]*\).*/\1/p' | head -1 || true)"
  fi
  [ -z "$c" ] && return 1
  export PROVE_SESSION_COOKIE="$c"
  curl_auth=(-H "Cookie: $c")
  echo "PROVE: signed-out run hit the login wall — retrying with a dev session"
  return 0
}

# A login wall is the one landing worth a retry; anything else is a real answer.
is_signin_path() {
  case "$1" in /signin|/login|/sign-in) return 0 ;; *) return 1 ;; esac
}

curl_auth=()
[ -n "${PROVE_SESSION_COOKIE:-}" ] && curl_auth=(-H "Cookie: ${PROVE_SESSION_COOKIE}")

check_route_curl() { # $1 = base, $2 = route → echoes "<http_code> <final_url>"
  # -L on purpose: a redirect is followed so the LANDING RULE can see where it
  # ended up. Without it every 302 read as a bare 3xx and the old code scored
  # that as "ok — not >=500, not 404", which is how a signed-out authed route
  # proved itself green.
  # The session cookie goes to a LOCAL base only. Auto-acquire is already
  # localhost-gated, but a hand-exported PROVE_SESSION_COOKIE is not — and this
  # same function serves the prod fallback below, so without this check a dev
  # server being down would send a live session cookie to $PROD_URL.
  local auth=()
  case "$1" in
    http://localhost|http://localhost:*|http://127.0.0.1|http://127.0.0.1:*)
      auth=("${curl_auth[@]+"${curl_auth[@]}"}") ;;
  esac
  curl -sL -o /dev/null --max-time 20 "${auth[@]+"${auth[@]}"}" \
    -w '%{http_code} %{url_effective}' "$1$2" 2>/dev/null || echo "000 "
}

# Pathname only — no scheme/host, no query, no fragment, no trailing slash.
# The landing rule compares these, so `/u/one/in?dest=tasks` matches its own
# redirect-free landing and a bounce to /signin does not.
path_of() {
  local u="$1" rest
  case "$u" in
    *://*) rest="${u#*://}"
           case "$rest" in
             */*) u="/${rest#*/}" ;;
             *)   u="/" ;;
           esac ;;
  esac
  u="${u%%\?*}"; u="${u%%#*}"
  case "$u" in ""|"/") printf '/' ;; *) printf '%s' "${u%/}" ;; esac
}

# One place decides what a wrong landing means, so both legs say the same thing.
report_redirect() { # $1 = route, $2 = landed path, $3 = leg label
  echo "PROVE: FAIL $1 — landed on $2, not $(path_of "$1") ($3) — the page under test never rendered"
  case "$2" in
    /signin|/login|/sign-in)
      echo "PROVE:   hint: authed route — export PROVE_SESSION_COOKIE='better-auth.session_token=…'"
      echo "PROVE:         (cd one.ie/web && bun scripts/dev-sign-in.ts prints one)" ;;
  esac
}

# The result line used to hardcode the word "dev" — so a production run
# printed "(dev https://one.ie)" on the very receipt someone reads to decide
# whether the site is live. Name the leg for what it is.
if _prove_local_base; then LEG="dev $BASE_URL"; else LEG="base $BASE_URL"; fi

fail=0
checked=0
for route in "${routes[@]}"; do
  proved=0
  # No node_modules precondition here on purpose. The old gate was
  # `[ -d /tmp/node_modules/playwright ]`; that directory had already evaporated,
  # so every browser PROVE silently degraded to the curl fallback while still
  # printing "ok". chrome.mjs resolves Playwright itself and exits 1 with
  # {"error":"playwright_not_found"} when it truly cannot run — which the
  # unparsable-output branch below already treats as environmental.
  if [ "$dev_up" -eq 1 ] && [ -f "$BROWSER_CHECK" ]; then
    out="$(node "$BROWSER_CHECK" "$BASE_URL$route" 2>/dev/null || true)"
    status="$(printf '%s' "$out" | jq -r '.httpStatus // 0' 2>/dev/null || echo 0)"
    # Same gated-is-not-broken policy the curl leg below already applies: a
    # subresource answering 401/403 means the page is signed-out, not broken, and
    # PROVE runs signed-out by default. Measured 2026-08-02 when the browser leg
    # came back to life: /pricing, /blog and /chat each failed on nothing but
    # "Failed to load resource: … 401", which curl had always passed. Everything
    # else still counts — uncaught JS, real console.error, and subresource
    # 404/5xx, which are genuine breakage.
    # 400 joins the same carve-out for the same reason: Layout.astro fires a
    # fire-and-forget tracking beacon (/api/follow) on every page, and it
    # answers 400 missing_slug on any page outside a tenant workspace — measured
    # on /, /components and prod one.ie/components identically (2026-08-07,
    # livekit C5). The beacon's failure has no bearing on the page; it is
    # gated-by-context the same way 401/403 is gated-by-session.
    counted='((.jsErrors // []) + ((.consoleErrors // []) | map(select(test("status of (400|401|403)") | not))))'
    # Against a LOCAL base only, a subresource 503 joins that list. Plain
    # `astro dev` binds no Durable Objects, so /api/analytics answers 503
    # intermittently — measured 2026-08-04 at roughly 1 load in 4, which made the
    # types-views proof flip GREEN/GREEN/RED across three identical sweeps. Same
    # reasoning as the 401/403 policy above: the environment is limited, the page
    # is not broken. Scoped to localhost so a 503 in prod still fails, and every
    # ignored one is PRINTED below rather than silently dropped. `dev:wrangler`
    # binds the DOs and makes this moot.
    if _prove_local_base; then
      counted='((.jsErrors // []) + ((.consoleErrors // []) | map(select(test("status of (400|401|403|503)") | not))))'
      ignored='((.consoleErrors // []) | map(select(test("status of 503"))) | length)'
    else
      ignored='0'
    fi
    errs="$(printf '%s' "$out" | jq -r "$counted | length" 2>/dev/null || echo "")"
    final="$(printf '%s' "$out" | jq -r '.finalUrl // ""' 2>/dev/null || echo "")"
    # Hit the login wall signed-out? That is the one case a session can change,
    # so retry once. Any other landing is the real answer and is left alone.
    if is_signin_path "$(path_of "${final:-$route}")" && prove_acquire_session; then
      out="$(node "$BROWSER_CHECK" "$BASE_URL$route" 2>/dev/null || true)"
      status="$(printf '%s' "$out" | jq -r '.httpStatus // 0' 2>/dev/null || echo 0)"
      errs="$(printf '%s' "$out" | jq -r "$counted | length" 2>/dev/null || echo "")"
      final="$(printf '%s' "$out" | jq -r '.finalUrl // ""' 2>/dev/null || echo "")"
    fi
    # One retry when the ONLY complaint is console errors on an otherwise correct
    # landing. Vite's first load after it pulls a new dep throws `useState of
    # null` / "more than one copy of React" and they vanish once the optimizer
    # settles (learnings 2026-08-02). Measured 2026-08-04: the same /u/one/tasks
    # proof came back exit=1 then exit=0 with no edit in between — a gate that
    # flips on a re-run cannot settle a promise. Status and landing failures are
    # NOT retried; a genuinely broken page fails both runs, so this kills the
    # flake without buying a flaky pass.
    landed="$(path_of "${final:-$route}")"
    if [ -n "$status" ] && [ "$status" != "0" ] && [ -n "$errs" ] && [ "$errs" -gt 0 ] \
       && [ "$status" -lt 500 ] && [ "$status" -ne 404 ] && [ "$landed" = "$(path_of "$route")" ]; then
      out="$(node "$BROWSER_CHECK" "$BASE_URL$route" 2>/dev/null || true)"
      status="$(printf '%s' "$out" | jq -r '.httpStatus // 0' 2>/dev/null || echo 0)"
      errs="$(printf '%s' "$out" | jq -r "$counted | length" 2>/dev/null || echo "")"
      final="$(printf '%s' "$out" | jq -r '.finalUrl // ""' 2>/dev/null || echo "")"
    fi
    if [ -n "$status" ] && [ "$status" != "0" ] && [ -n "$errs" ]; then
      proved=1; checked=$((checked+1))
      landed="$(path_of "${final:-$route}")"
      # LANDING RULE first — a bounce to /signin renders 200 with zero errors, so
      # every check below it would pass on a page that is not the one requested.
      # 404 IS A FAIL here too. The curl leg below learned this on 2026-07-29;
      # the browser leg never did, so a nonexistent route proved itself green
      # whenever the page also logged no errors. 401/403 stay ok — gated, not gone.
      if [ -n "$final" ] && [ "$landed" != "$(path_of "$route")" ]; then
        report_redirect "$route" "$landed" "$LEG"
        fail=1
      elif [ "$status" -ge 500 ] || [ "$status" -eq 404 ] || [ "$errs" -gt 0 ]; then
        echo "PROVE: FAIL $route — http=$status console/js errors=$errs ($LEG)"
        printf '%s' "$out" | jq -r "$counted[]" 2>/dev/null | head -5 | sed 's/^/PROVE:   error: /'
        fail=1
      else
        echo "PROVE: ok $route — http=$status, 0 console/js errors ($LEG)"
      fi
      # Never silent: an ignored error is still an error someone should see.
      ign="$(printf '%s' "$out" | jq -r "$ignored" 2>/dev/null || echo 0)"
      [ "${ign:-0}" -gt 0 ] 2>/dev/null && \
        echo "PROVE:   note — $ign subresource 503(s) ignored (no DO bindings in vite dev; dev:wrangler for DO parity)"
    fi
    # status 0 / unparsable = environmental (browser-check couldn't run) → fall through
  fi
  if [ "$proved" -eq 0 ] && [ "$dev_up" -eq 1 ]; then
    # dev reachable but playwright unavailable → curl the dev route
    read -r code effective <<< "$(check_route_curl "$BASE_URL" "$route")"
    if is_signin_path "$(path_of "${effective:-$route}")" && prove_acquire_session; then
      read -r code effective <<< "$(check_route_curl "$BASE_URL" "$route")"
    fi
    if [ "$code" != "000" ]; then
      proved=1; checked=$((checked+1))
      landed="$(path_of "${effective:-$route}")"
      # LANDING RULE, then 404. 404 IS A FAIL: it used to report `ok` — only >=500
      # failed — so a route that does not exist proved itself. Measured 2026-07-29:
      # `--route /factory` returned "ok /factory — http=404" against a dev server
      # running a tree without the page, and that line was the 17th leg of a
      # promise's proof. 401/403 stay ok: the route answered, it is merely gated.
      if [ -n "$effective" ] && [ "$landed" != "$(path_of "$route")" ]; then
        report_redirect "$route" "$landed" "$LEG, curl"; fail=1
      elif [ "$code" -ge 500 ] || [ "$code" -eq 404 ]; then
        echo "PROVE: FAIL $route — http=$code ($LEG, curl)"; fail=1
      else
        echo "PROVE: ok $route — http=$code ($LEG, curl)"
      fi
    fi
  fi
  if [ "$proved" -eq 0 ]; then
    read -r code effective <<< "$(check_route_curl "$PROD_URL" "$route")"
    if [ "$code" != "000" ]; then
      checked=$((checked+1))
      # Same rules as the dev branch above — a redirect off the requested path
      # proves the wrong page, and a 404 in production is the clearest possible
      # "not shipped". Neither may read as proven.
      landed="$(path_of "${effective:-$route}")"
      if [ -n "$effective" ] && [ "$landed" != "$(path_of "$route")" ]; then
        report_redirect "$route" "$landed" "prod $PROD_URL"; fail=1
      elif [ "$code" -ge 500 ] || [ "$code" -eq 404 ]; then
        echo "PROVE: FAIL $route — http=$code (prod $PROD_URL)"; fail=1
      else
        echo "PROVE: ok $route — http=$code (prod $PROD_URL)"
      fi
    else
      echo "PROVE: unreachable $route — neither $BASE_URL nor $PROD_URL responded"
    fi
  fi
done

if [ "$fail" -eq 1 ]; then
  echo "PROVE: fail"; exit 1
fi
if [ "$checked" -eq 0 ]; then
  # An explicitly named base that answered nothing is an UNRUN PROOF, and
  # do-promise-settle.sh reads this exit code verbatim. Exit 0 here would settle
  # a promise KEPT because the site was unreachable.
  if [ "$base_explicit" -eq 1 ]; then
    echo "PROVE: FAIL — --base $BASE_URL answered nothing; an unrun proof is not a pass"
    exit 1
  fi
  echo "PROVE: skipped (no reachable environment)"; exit 0
fi
echo "PROVE: pass ($checked route(s) proven)"; exit 0
