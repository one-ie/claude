#!/usr/bin/env bash
# do-promise-settle.sh — settle a promise off-chain: run its proof:, the exit code moves the path.
#
# The armed wire behind text/marketplace.md and the off-chain half of
# text/promise-plan.md ("runs off-chain, settles on-chain"): a kept promise mark()s the
# weighted path the routing already reads; a broken one warn()s it. Zero LLM — the proof
# exit code is the verdict. Rule 1 (closed loop): every settlement ends in mark or warn.
#
# Usage:
#   do-promise-settle.sh <slug> [--composite 0.NN] [--dry-run]
#   do-promise-settle.sh --self-test
#
#   kept   (proof exits 0) → POST /api/mark/promise:<slug>→proof   strength = composite×5 (default 1)
#   broken (proof non-0)   → POST /api/warn/promise:<slug>→proof   strength = 1
#   no proof: in frontmatter → dissolved, exit 3 (a promise with no observable can't close its loop)
#
# Either verdict also broadcasts world:announce (the PUBLIC front door — no secret) so every
# subscriber staked on [promise, <slug>] hears the settlement; the CEO routing is one of them.
# Substrate write targets ONE_API_URL (default http://localhost:4321). If GATEWAY_SERVICE_SECRET
# is set it is sent as X-Gateway-Key; it is never printed. Unreachable wire degrades to
# broadcast-only and says so — no silent success.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="${ONE_API_URL:-http://localhost:4321}"

# Credentials come from ONE_ENV_FILE (DO_ENV_FILE is the accepted alias), the same
# indirection do-signal.sh and do-fleet.sh honour and that factory-repo.sh's
# --check-env-indirection enforces for every shipped credential-reading script.
#
# This script read $GATEWAY_API_KEY from the PROCESS environment only, and nothing
# exports it — so it never sent an Authorization header and every mark/warn 401'd.
# The failure was invisible because a 401 printed "wire unreachable, broadcast-only":
# the settle blaming the network for its own missing credential. Measured 2026-08-02
# settling pages-fill-pack and tauri — both proofs exit 0, both marks 401, against a
# localhost:4321 answering 200. tauri had already settled KEPT this way once before.
ONE_ENV_FILE="${ONE_ENV_FILE:-${DO_ENV_FILE:-one.ie/web/.env}}"
DO_ENV_FILE="$ONE_ENV_FILE"

# Unquoted on purpose: expands to nothing outside the monorepo, so the loop
# degrades to ONE_ENV_FILE alone rather than erroring.
_MONOREPO_ENV_CANDIDATES="$ROOT/one.ie/web/.env $ROOT/one.ie/web/.dev.vars"

# Reads a key out of the first env file that carries it. Never echoes the value
# anywhere but its own stdout, which the caller assigns straight to a local.
_env_key() { # $1 = key name
  local _f _v
  for _f in "$ONE_ENV_FILE" "$ROOT/.env" $_MONOREPO_ENV_CANDIDATES; do
    [ -f "$_f" ] || continue
    _v=$(grep -E "^$1=" "$_f" 2>/dev/null | head -1 | sed 's/^[^=]*=//;s/^"//;s/"$//' || true)
    [ -n "$_v" ] && { printf '%s' "$_v"; return 0; }
  done
  printf ''
}

usage() { grep '^# ' "$0" | sed 's/^# //' | sed -n '3,14p'; exit 4; }

# ── frontmatter proof: extractor (first frontmatter block only) ──────────────
extract_proof() { # $1 = promise file
  local line
  line="$(awk '/^---[[:space:]]*$/{c++;next} c==1 && /^proof:/{print;exit} c>=2{exit}' "$1")"
  [ -z "$line" ] && return 1
  line="${line#proof:}"
  line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//')"
  case "$line" in
    \"*) printf '%s' "$line" | sed -E 's/^"(.*)"[[:space:]]*(#.*)?$/\1/' | sed 's/\\"/"/g' | sed 's/\\\\/\\/g' ;;
    \'*) printf '%s' "$line" | sed -E "s/^'(.*)'[[:space:]]*(#.*)?\$/\1/" | sed "s/''/'/g" ;;
    *)   printf '%s' "$line" | sed -E 's/[[:space:]]+#.*$//' ;;
  esac
}

# ── frontmatter oracle: extractor (contract: sub-block, indented) ────────────
extract_oracle() { # $1 = promise file
  awk '/^---[[:space:]]*$/{c++;next} c==1 && /^[[:space:]]*oracle:/{print;exit} c>=2{exit}' "$1" \
    | sed -E 's/^[[:space:]]*oracle:[[:space:]]*"?([^"#]*)"?.*/\1/' | sed -E 's/[[:space:]]+$//'
}

# ── resolve which keystore index (if any) signs AS the promise's oracle: ─────
# Prints "index:N" (keystore position N matches oracle:) or "skip:<reason>".
# Never aborts, never guesses — a promise settling under the wrong key is worse
# than one that skips its on-chain twin and stands on the off-chain settle alone.
resolve_oracle_signer() { # $1 = promise file
  local file="$1" oracle
  oracle="$(extract_oracle "$file")"
  if [ -z "$oracle" ]; then echo "skip:no-oracle-field"; return; fi
  if ! command -v sui >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "skip:no-sui-or-jq-cli"; return
  fi
  local oracle_lc idx
  oracle_lc="$(printf '%s' "$oracle" | tr 'A-Z' 'a-z')"
  idx="$(sui keytool list --json 2>/dev/null | jq -r --arg o "$oracle_lc" \
    'to_entries[] | select((.value.suiAddress // "" | ascii_downcase) == $o) | .key' | head -1)"
  if [ -z "$idx" ]; then echo "skip:unmatchable oracle=$oracle not in local keystore"; return; fi
  echo "index:$idx"
}

# ── settle one promise file ──────────────────────────────────────────────────
settle() { # $1 = slug, $2 = promise file, $3 = composite ("" = none), $4 = dry-run (true/false)
  local slug="$1" file="$2" composite="$3" dry="$4"
  echo "[promise-settle] slug=$slug file=${file#"$ROOT"/}"

  if [ ! -f "$file" ]; then
    echo "[promise-settle] dissolved — no promise file"; return 3
  fi
  local proof; proof="$(extract_proof "$file")"
  if [ -z "$proof" ]; then
    echo "[promise-settle] dissolved — promise has no proof: observable"; return 3
  fi
  echo "[promise-settle] proof: $proof"

  local rc=0
  ( cd "$ROOT" && bash -c "$proof" ) >/dev/null 2>&1 || rc=$?

  # EXIT 3 IS "COULD NOT RUN", NOT "BROKEN". A proof: is an `&&`-join, so a leg
  # that cannot reach its substrate stops the chain and the join returns 3 — and
  # this script used to fold that into `else → warn`. A TypeDB blip would then
  # deposit resistance on a proven path, permanently, for infrastructure noise:
  # the settle would record a promise as BROKEN for a reason the maker cannot
  # fix and did not cause. text/factory.md § "A note on red vs cannot run" states
  # the rule — "exit 3 anywhere in the chain means re-run later, never warn" —
  # and until now the tool that enforces promises did not implement the sharpest
  # idea in them.
  #
  # An unverifiable promise closes NOTHING: no mark, no warn, no on-chain settle,
  # and the loop stays open by design. It is not `dissolved` either — dissolved
  # means there is no observable to run (rule 1's third exit); here the observable
  # exists and was simply unreachable. The caller re-runs later. /close must treat
  # exit 3 as "not settled yet", never as a close.
  if [ "$rc" -eq 3 ]; then
    echo "[promise-settle] proof exit=3 → UNVERIFIABLE (substrate unreachable) — no mark, no warn, promise stays open"
    echo "[promise-settle] re-run when the substrate answers: $0 $slug"
    if [ "$dry" = true ]; then
      echo "[promise-settle] DRY would write no path and broadcast unverifiable"
      return 3
    fi
    # Announce it anyway: an unverifiable settle is news the world can act on
    # (someone can fix the cluster), and the broadcast writes no path.
    # shellcheck source=/dev/null
    source "$ROOT/.claude/hooks/lib/signal.sh" 2>/dev/null && \
      emit_world "promise" "fyi" "promise,do,unverifiable,$slug" \
        "promise $slug UNVERIFIABLE — proof could not run; no path written" "proof_exit=3"
    echo "[promise-settle] broadcast world:announce queued (fire-and-forget, unconfirmed) tags=[promise,do,unverifiable,$slug]"
    return 3
  fi

  # derives gate — a promise cannot settle KEPT while an artifact its derives: block
  # declares true is missing on disk (the class that let security-gates ship a missing
  # -docs.md). Zero LLM; folds into the verdict so the close still ends in mark/warn.
  # Only exit 1 ("artifact missing") overrides kept→broken — exit 2 ("no promise file
  # at the conventional text/<slug>.md path") is a different failure class (e.g. a
  # settle() call against a custom PROMISE_FILE, or a self-test fixture slug with no
  # real promise on disk) and must not be conflated with a genuinely broken promise.
  if [ "$rc" -eq 0 ]; then
    local derives_out derives_rc=0
    derives_out="$(bash "$ROOT/.claude/scripts/do-derives-check.sh" "$slug" 2>&1)" || derives_rc=$?
    if [ "$derives_rc" -eq 1 ]; then
      echo "[promise-settle] derives-check FAILED — declared artifact missing; overriding kept→broken:"
      echo "$derives_out" | sed 's/^/[promise-settle]   /'
      rc=1
    fi
  fi

  local verb strength verdict
  if [ "$rc" -eq 0 ]; then
    verdict=kept; verb=mark
    strength="$(awk -v c="${composite:-0.2}" 'BEGIN{printf "%g", c*5}')"
  else
    verdict=broken; verb=warn; strength=1
  fi
  echo "[promise-settle] proof exit=$rc → $verdict"

  local edge="promise:${slug}→proof"
  if [ "$dry" = true ]; then
    echo "[promise-settle] DRY $verb $edge strength=$strength"
    echo "[promise-settle] DRY broadcast world:announce queued (fire-and-forget, unconfirmed) tags=[promise,do,$verdict,$slug]"
    if [ -n "${SUI_PRIVATE_KEY:-}" ]; then
      echo "[promise-settle] DRY on-chain settle_promise kept=$([ "$verdict" = kept ] && echo true || echo false) signer=env-override"
    else
      local dry_signer; dry_signer="$(resolve_oracle_signer "$file")"
      case "$dry_signer" in
        index:*) echo "[promise-settle] DRY on-chain settle_promise kept=$([ "$verdict" = kept ] && echo true || echo false) signer=keystore#${dry_signer#index:}" ;;
        skip:*)  echo "[promise-settle] DRY on-chain: ${dry_signer#skip:} — would skip (off-chain settle stands)" ;;
      esac
    fi
    return 0
  fi

  local enc http
  enc="$(jq -rn --arg e "$edge" '$e|@uri')"
  local -a hdr=(-H 'Content-Type: application/json')
  # Secrets off argv (ps aux would leak a bare -H value) — fold both into a
  # private 0600 curl --config file instead.
  # Environment wins over the env file, so an explicit export still overrides.
  local gsecret gkey
  gsecret="${GATEWAY_SERVICE_SECRET:-$(_env_key GATEWAY_SERVICE_SECRET)}"
  gkey="${GATEWAY_API_KEY:-$(_env_key GATEWAY_API_KEY)}"
  local authcfg=""
  if [ -n "$gsecret" ] || [ -n "$gkey" ]; then
    authcfg="$(mktemp)"; chmod 600 "$authcfg"
    [ -n "$gsecret" ] && printf 'header = "X-Gateway-Key: %s"\n' "$gsecret" >>"$authcfg"
    [ -n "$gkey" ] && printf 'header = "Authorization: Bearer %s"\n' "$gkey" >>"$authcfg"
    hdr+=(--config "$authcfg")
  fi
  # --max-time 20, not 5. This POST is a SUBSTRATE WRITE: the route authenticates,
  # then opens a TypeDB transaction against the cloud cluster, where a cold sign-in
  # alone measured 4.1s (factory-check.sh header, 2026-07-29). A 5s ceiling made a
  # healthy system report "wire unreachable" — the settle blaming the network for
  # its own stopwatch, which is exactly what /factory's gaps board did before it
  # was fixed. Measured after the change: the same call answers well inside 20s.
  #
  # curl's own failure is captured separately. `|| echo 000` appended a second
  # "000" to the -w output, printing http=000000 — a status code that does not
  # exist, in the line an operator reads to decide whether the path moved.
  local curl_rc=0
  http="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 -X POST "$BASE/api/$verb/$enc" \
    "${hdr[@]}" -d "{\"strength\":$strength,\"tags\":[\"promise\",\"do\",\"$slug\"]}" 2>/dev/null)" || curl_rc=$?
  [ "$curl_rc" -ne 0 ] && http="000 (curl rc=$curl_rc)"
  [ -n "$authcfg" ] && rm -f "$authcfg"
  # Name the failure accurately. Calling a 401 "wire unreachable" is what hid the
  # missing-credential bug above: an operator reading that line goes looking at the
  # network for a fault that is entirely local.
  if [ "$http" = 200 ]; then
    echo "[promise-settle] $verb $edge strength=$strength http=$http"
  else
    local why
    case "$http" in
      401|403) why="AUTH REJECTED — no/!bad GATEWAY_API_KEY; checked ONE_ENV_FILE=$ONE_ENV_FILE. Substrate NOT written" ;;
      000*)    why="wire unreachable ($BASE)" ;;
      404)     why="no such route at $BASE/api/$verb — substrate NOT written" ;;
      *)       why="substrate NOT written" ;;
    esac
    echo "[promise-settle] $verb $edge strength=$strength http=$http — $why, broadcast-only"
  fi

  # public broadcast — the world hears the settlement regardless of the substrate wire
  # shellcheck source=/dev/null
  source "$ROOT/.claude/hooks/lib/signal.sh" 2>/dev/null && \
    emit_world "promise" "fyi" "promise,do,$verdict,$slug" \
      "promise $slug $verdict — $verb $edge strength=$strength" "proof_exit=$rc"
  # NOT a confirmation. emit_world curls in a background subshell, discards the
  # response and returns 0 unconditionally — by design, since it also runs from
  # hooks that must never block. So this line reports what was QUEUED, not what
  # the world heard. Printing it as a delivery would be a settle announcing its
  # own success on no evidence, which is the failure class this whole promise
  # family exists to name. Confirming it needs a synchronous emitter; until then
  # the wording carries the uncertainty.
  echo "[promise-settle] broadcast world:announce queued (fire-and-forget, unconfirmed) tags=[promise,do,$verdict,$slug]"

  # on-chain twin — settle_promise on the generated Move object (schema/sui.tql →
  # substrate.move). Fires only when armed (signer present + object minted); the
  # amount is the off-chain strength in bps. Failure never blocks the close —
  # the off-chain settle above is the settle of record until the chain confirms.
  if grep -qE '^\s*object_id:\s*"0x' "$file"; then
    local flag amount_bps chain_rc=0 signer
    flag=$([ "$verdict" = kept ] && echo --kept || echo --broken)
    amount_bps="$(awk -v s="$strength" 'BEGIN{printf "%d", s*1000}')"
    if [ -n "${SUI_PRIVATE_KEY:-}" ]; then
      signer="env-override"
    else
      signer="$(resolve_oracle_signer "$file")"
    fi
    case "$signer" in
      skip:*)
        echo "[promise-settle] on-chain: ${signer#skip:} — skipping on-chain settle (off-chain settle stands)"
        ;;
      index:*)
        SUI_KEY_INDEX="${signer#index:}" PROMISE_FILE="$file" bun "$ROOT/pay/tools/promise-chain.ts" settle "$slug" "$flag" --amount "$amount_bps" || chain_rc=$?
        case "$chain_rc" in
          0) echo "[promise-settle] on-chain settle_promise $verdict amount=${amount_bps}bps signer=keystore#${signer#index:}" ;;
          2) echo "[promise-settle] on-chain: unarmed (no signer) — off-chain settle stands" ;;
          *) echo "[promise-settle] on-chain settle failed rc=$chain_rc (off-chain settle stands) — retry: bun pay/tools/promise-chain.ts settle $slug $flag --amount $amount_bps" ;;
        esac
        ;;
      env-override)
        PROMISE_FILE="$file" bun "$ROOT/pay/tools/promise-chain.ts" settle "$slug" "$flag" --amount "$amount_bps" || chain_rc=$?
        case "$chain_rc" in
          0) echo "[promise-settle] on-chain settle_promise $verdict amount=${amount_bps}bps signer=env-override" ;;
          2) echo "[promise-settle] on-chain: unarmed (no signer) — off-chain settle stands" ;;
          *) echo "[promise-settle] on-chain settle failed rc=$chain_rc (off-chain settle stands) — retry: bun pay/tools/promise-chain.ts settle $slug $flag --amount $amount_bps" ;;
        esac
        ;;
    esac
  else
    echo "[promise-settle] on-chain: skipped (promise not minted — bun pay/tools/promise-chain.ts mint $slug)"
  fi
  return 0
}

# ── self-test: kept / broken / dissolved fixtures, dry-run, zero network ─────
if [ "${1:-}" = "--self-test" ]; then
  dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
  printf -- '---\nproof: "true"\n---\n' >"$dir/kept.md"
  printf -- '---\nproof: "false"\n---\n' >"$dir/broken.md"
  printf -- '---\ntitle: no proof here\n---\n' >"$dir/noproof.md"
  printf -- '---\nproof: "[ \\"a\\" = \\"a\\" ]"\n---\n' >"$dir/escaped-quotes.md"
  printf -- '---\nproof: "true"\ncontract:\n  oracle: "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"\n---\n' >"$dir/unmatchable-oracle.md"
  # cannot-run: the `&&`-join stops at a leg that exits 3, so the join returns 3.
  # The second leg must NEVER run — if it did, this fixture would return 0 and the
  # test would pass for the wrong reason.
  printf -- '---\nproof: "exit 3 && true"\n---\n' >"$dir/cannotrun.md"
  fails=0
  out="$(settle kept-fixture "$dir/kept.md" 0.8 true)"
  echo "$out" | grep -q 'DRY mark .*strength=4' || { echo "FAIL kept → mark strength=4"; fails=$((fails+1)); }
  out="$(settle broken-fixture "$dir/broken.md" "" true)"
  echo "$out" | grep -q 'DRY warn .*strength=1' || { echo "FAIL broken → warn strength=1"; fails=$((fails+1)); }
  settle noproof-fixture "$dir/noproof.md" "" true >/dev/null; [ $? -eq 3 ] || { echo "FAIL noproof → dissolved(3)"; fails=$((fails+1)); }
  out="$(settle escaped-quotes-fixture "$dir/escaped-quotes.md" "" true)"
  echo "$out" | grep -q 'DRY mark .*strength=1' || { echo "FAIL escaped-quotes → mark (proof: with embedded \\\" must extract+run intact)"; fails=$((fails+1)); }
  out="$(SUI_PRIVATE_KEY= settle unmatchable-oracle-fixture "$dir/unmatchable-oracle.md" "" true)"
  rc=$?
  echo "$out" | grep -q 'DRY on-chain: unmatchable oracle=0xffff.*would skip' || { echo "FAIL unmatchable-oracle → clean skip, no wrong-key attempt"; fails=$((fails+1)); }
  [ "$rc" -eq 0 ] || { echo "FAIL unmatchable-oracle → exit 0"; fails=$((fails+1)); }
  # cannot-run must be its OWN verdict: exit 3, and NEITHER verb written. The bug
  # this fixture pins is a cluster blip settling a promise BROKEN and warning its
  # path — so asserting "not mark" is not enough; assert "not warn" explicitly.
  out="$(settle cannotrun-fixture "$dir/cannotrun.md" "" true)"; rc=$?
  [ "$rc" -eq 3 ] || { echo "FAIL cannot-run → exit 3 (got $rc)"; fails=$((fails+1)); }
  echo "$out" | grep -q 'UNVERIFIABLE' || { echo "FAIL cannot-run → says UNVERIFIABLE"; fails=$((fails+1)); }
  echo "$out" | grep -qE 'DRY (warn|mark) ' && { echo "FAIL cannot-run → wrote a path verb (must write neither)"; fails=$((fails+1)); }
  echo "[promise-settle] self-test: 6 fixtures, $fails failed"
  exit "$fails"
fi

# ── main ─────────────────────────────────────────────────────────────────────
SLUG="${1:-}"; [ -z "$SLUG" ] && usage
shift
COMPOSITE=""; DRY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --composite) COMPOSITE="${2:-}"; shift 2 ;;
    --dry-run)   DRY=true; shift ;;
    *) usage ;;
  esac
done
settle "$SLUG" "${PROMISE_FILE:-$ROOT/text/$SLUG.md}" "$COMPOSITE" "$DRY"
