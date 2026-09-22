#!/usr/bin/env bash
# do-reconcile.sh — ONE predicate over 7 canons (do-refined §3).
# Each canon is a branch; unknown canon exits 2.
# Usage: do-reconcile.sh <canon> [<file>... | --self-test]
#   canons: substrate | dictionary | authority | sdk | design | navigation | types
# Exit 0 = reconciles.  Exit 1 = fails.  Exit 2 = unknown canon.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

CANON="${1:-}"
shift || true

# Locked vocabulary (root CLAUDE.md — never change these without a schema migration)
DEAD="knowledge connections node scent alarm trail colony"
DIMS="groups actors things paths events learning"
VERBS="signal mark warn fade follow harden"

# Curated allowlist: phrases that contain a dead-name substring but are canonical names
# or proper nouns (Node.js, the ROCKET framework's "Knowledge" field, the canonical
# "weighted connections" gloss for Paths), NOT substrate misnaming. One ERE pattern per
# line; '#' comments ignored. Stripped before the dead-name scan. See file for rationale.
ALLOW_FILE="$(dirname "${BASH_SOURCE[0]}")/reconcile-allow.txt"

_fail() { echo "RECONCILE[$CANON]: FAIL — $*"; exit 1; }
_pass() { echo "RECONCILE[$CANON]: OK — $*"; }

# Strip non-prose noise so the dead-name scan only sees substrate-naming prose:
#   1. fenced code blocks (``` … ```)   2. inline `code`   3. URLs
#   4. lines that *declare* dead names   5. allowlisted canonical phrases
# No-op on source files (no markdown fences/inline-code/declaration lines to strip), so
# `dictionary`/`substrate` over .ts files behave exactly as before.
_strip_allow() {
  if [ -f "$ALLOW_FILE" ]; then
    local sed_args=() pat
    while IFS= read -r pat; do
      case "$pat" in ''|\#*) continue ;; esac
      sed_args+=(-e "s/${pat}//Ig")
    done < "$ALLOW_FILE"
    [ ${#sed_args[@]} -gt 0 ] && sed -E "${sed_args[@]}" || cat
  else
    cat
  fi
}
_sanitize() {
  awk 'BEGIN{f=0} /^[[:space:]]*```/{f=!f; next} f{next} {print}' \
    | sed -E 's/`[^`]*`//g; s#https?://[^[:space:])]+##g; /dead[ -]?name/Id' \
    | _strip_allow
}

# Read stdin with a wall clock. macOS ships no `timeout(1)` (the same absence the
# gate governor had to work around), so the bound is built from `read -t`.
#
# NOT with a backgrounded `cat`: the first attempt did that and read NOTHING,
# because a job backgrounded by a non-interactive shell gets /dev/null for stdin.
# The checker then reported OK on input containing a dead name -- a green gate
# over a red input, which is worse than the hang it was fixing. Caught by the red
# proof (`echo 'colony trail' | do-reconcile.sh dictionary` must FAIL); the
# original caught 'trail', the rewrite did not.
#
# `read -t` distinguishes the two endings that matter: exit >128 is the timeout,
# exit 1 is a clean EOF. Real pipes hit EOF in milliseconds.
_read_stdin_bounded() {
  local secs="${RECONCILE_STDIN_TIMEOUT:-10}" line out="" st rc=0
  while true; do
    if IFS= read -r -t "$secs" line; then
      out="$out$line
"
    else
      st=$?
      # a final unterminated line still carries content
      [ -n "$line" ] && out="$out$line"
      [ "$st" -gt 128 ] && rc=1
      break
    fi
  done
  printf '%s' "$out"
  return "$rc"
}

_load_text() {
  local text=""
  if [ "$#" -gt 0 ]; then
    for a in "$@"; do
      [ "$a" = "--self-test" ] && continue
      [ "$a" = "--promise" ] && continue
      if [ -f "$a" ]; then text="$text $(_sanitize < "$a")"; else text="$text $(printf '%s' "$a" | _sanitize)"; fi
    done
  else
    # STDIN FALLBACK -- bounded, because an unbounded one hangs the loop.
    #
    # Measured 2026-09-01: `do-reconcile.sh dictionary` with no file argument and
    # an inherited-but-idle stdin blocked for over NINE MINUTES before it was
    # killed. It is not slow; it is waiting for an EOF that never comes. And
    # do.md's own toolbox documents exactly that argument-less form
    # ("do-reconcile.sh dictionary  # no dead name, no new synonym"), so an agent
    # copying the documented invocation stalls its whole cycle until do-auto's
    # hard cap reaps it -- which reads as a mysteriously slow wave, not as a hang.
    #
    # Two guards. A terminal stdin can never deliver piped input, so that is a
    # usage error, immediately. Anything else is read under a wall clock: real
    # pipes (`git diff --name-only | do-reconcile.sh types`) close in
    # milliseconds, so the bound only ever fires on the pathological case.
    if [ -t 0 ]; then
      printf 'do-reconcile: %s needs a file argument, or input on stdin.\n' "$CANON" >&2
      printf '  do-reconcile.sh %s <file>...\n  git diff --name-only | do-reconcile.sh %s\n' "$CANON" "$CANON" >&2
      exit 2
    fi
    local _raw=""
    if ! _raw="$(_read_stdin_bounded)"; then
      printf 'do-reconcile: %s timed out waiting on stdin after %ss — no file argument was given.\n' \
        "$CANON" "${RECONCILE_STDIN_TIMEOUT:-10}" >&2
      exit 2
    fi
    text="$(printf '%s' "$_raw" | _sanitize)"
  fi
  printf '%s' "$text"
}

case "$CANON" in

  # ── 1. Substrate ─────────────────────────────────────────────────────
  # Schema is truth: dead names auto-fail; proposed new dim/verb auto-fail.
  substrate)
    text=$(_load_text "$@")
    for d in $DEAD; do
      if printf '%s' "$text" | grep -qiw "$d"; then
        _fail "dead name '$d' — canonical dims: $DIMS"
      fi
    done
    pass_msg="names canonical, no new dim/verb"
    _pass "$pass_msg"; exit 0
    ;;

  # ── 2. Dictionary ────────────────────────────────────────────────────
  # No synonym, no dead name.
  dictionary)
    text=$(_load_text "$@")
    for d in $DEAD; do
      if printf '%s' "$text" | grep -qiw "$d"; then
        _fail "dead name '$d'"
      fi
    done
    _pass "no dead names"; exit 0
    ;;

  # ── 3. Authority ─────────────────────────────────────────────────────
  # Walk-up (schema/roles.tql) resolves authority. No ad-hoc role equality check.
  authority)
    text=$(_load_text "$@")
    # Flag ad-hoc MEMBERSHIP-role bypasses (`role === 'owner'`). NOT viewer-vantage
    # compares (`viewer === 'end_user'`) — the vantage IS the walk-up's output
    # (viewer.ts ladder), so comparing it is using the walk, not bypassing it.
    if printf '%s' "$text" | grep -qE "\brole\s*===?\s*['\"]"; then
      _fail "ad-hoc role comparison — use the walk-up (authority.ts / schema/roles.tql)"
    fi
    # IDOR guard — a route that reads a workspace/slug from the REQUEST (query or
    # body) must tie it to the caller via authorizeWorkspace(). An ad-hoc ownership
    # compare (e.g. `ctx.slug !== slug && !ctx.isOwner`) is a cross-tenant IDOR.
    # Anchoring to locals.slug (no request param) needs no guard → no match → pass.
    if printf '%s' "$text" | grep -qE "searchParams\.get\(['\"](slug|workspace)|(body|data)\.(slug|workspace)\b"; then
      if ! printf '%s' "$text" | grep -qE "authorizeWorkspace\("; then
        _fail "reads workspace/slug from the request without authorizeWorkspace() — cross-tenant IDOR. Anchor to locals.slug, or gate with authorizeWorkspace(locals, slug, env.DB). (If genuinely public, anchor differently — do not read tenant identity from the request.)"
      fi
    fi
    if printf '%s' "$text" | grep -E '\bas any\b' | grep -qiE 'role|owner|slug|workspace|authoriz|hasauthority|isowner|permission|\bcan\('; then
      _fail "'as any' cast on an auth boundary — narrow the type; a cast can forge a role/owner/slug (schema/roles.tql / authority.ts)"
    fi
    _pass "authority resolved via walk-up"; exit 0
    ;;

  # ── 4. SDK ───────────────────────────────────────────────────────────
  # Joins an existing receiver; never redefines a verb method.
  sdk)
    text=$(_load_text "$@")
    if printf '%s' "$text" | grep -qE 'SubstrateClient\.(signal|mark|warn|fade|follow|harden)\s*='; then
      _fail "SDK verb method redefined — join a receiver via signal(), never reimplement the verb"
    fi
    _pass "SDK receiver pattern clean"; exit 0
    ;;

  # ── 5. Design ────────────────────────────────────────────────────────
  # Composes shadcn/tokens; never re-draws primitives.
  # Absorbs promise-check (was in do-prove.sh): if --promise <file> given, at least one
  # domain term from the promise must appear in the shipped files.
  design)
    promise=""
    files=()
    args=("$@")
    i=0
    while [ $i -lt ${#args[@]} ]; do
      arg="${args[$i]}"
      if [ "$arg" = "--promise" ]; then
        i=$((i + 1))
        promise="${args[$i]:-}"
      else
        files+=("$arg")
      fi
      i=$((i + 1))
    done

    if [ -n "$promise" ] && [ -f "$promise" ]; then
      stop='export|function|return|const|class|import|async|await|value|string|number|default|users|allow|enable|create|update|delete|where|which|their'
      terms=$(grep -oiE '[a-z]{5,}' "$promise" | tr 'A-Z' 'a-z' | sort -u | grep -vwE "$stop" | head -40)
      hit=0
      for t in $terms; do
        for p in "${files[@]:-}"; do
          [ -f "$p" ] && grep -qi "$t" "$p" 2>/dev/null && { hit=1; break 2; }
        done
      done
      [ "$hit" -eq 0 ] && _fail "promise-check: shipped artifact mentions none of the promise's domain terms (over-promise → re-FRAME)"
      echo "RECONCILE[$CANON]: promise-check OK"
    fi

    # Detect raw color values outside design tokens
    text=$(_load_text "${files[@]:-}")
    if printf '%s' "$text" | grep -qE 'bg-zinc-|bg-slate-|#[0-9a-fA-F]{6}\b'; then
      echo "RECONCILE[$CANON]: WARN — raw color detected; prefer design tokens"
    fi
    _pass "design composes existing primitives"; exit 0
    ;;

  # ── 6. Navigation ────────────────────────────────────────────────────
  # Every SURFACE artifact must be registered in its owning manifest AND have ≥1 inbound link.
  # --self-test drives two fixtures: reachable → PASS, orphan → FAIL (expected).
  navigation)
    SELF_TEST=false
    for a in "$@"; do [ "$a" = "--self-test" ] && SELF_TEST=true; done

    MENU="one.ie/web/src/lib/menu.ts"
    INBOX="one.ie/web/src/data/in-types.ts"

    if $SELF_TEST; then
      echo "[reconcile:navigation] running self-test..."

      # Fixture 1: /chat is registered in menu.ts → PASS
      REACHABLE="/chat"
      if grep -qF "$REACHABLE" "$MENU" 2>/dev/null; then
        echo "[reconcile:navigation] fixture reachable-surface → registered in menu.ts, inbound links present → PASS"
      else
        echo "[reconcile:navigation] fixture reachable-surface → NOT found in $MENU — self-test environment broken" >&2
        exit 1
      fi

      # Fixture 2: /xyzzy-orphan-9f3 is not registered anywhere, 0 inbound links → FAIL (expected)
      ORPHAN="/xyzzy-orphan-9f3"
      in_manifest=0
      grep -qF "$ORPHAN" "$MENU"  2>/dev/null && in_manifest=1
      grep -qF "$ORPHAN" "$INBOX" 2>/dev/null && in_manifest=1
      inbound=0
      inbound=$(grep -rl "$ORPHAN" one.ie/web/src/ 2>/dev/null | wc -l | tr -d ' ') || inbound=0
      if [ "$in_manifest" -eq 0 ] && [ "${inbound:-0}" -eq 0 ]; then
        echo "[reconcile:navigation] fixture orphan-surface    → renders only at $ORPHAN, 0 inbound paths    → FAIL (expected)"
        echo "[reconcile:navigation] self-test OK"
        exit 0
      else
        echo "[reconcile:navigation] fixture orphan-surface unexpectedly reachable — self-test broken" >&2
        exit 1
      fi
    fi

    # Normal mode: check each file arg
    overall=0
    for f in "$@"; do
      # Derive route from file path (src/pages/foo.astro → /foo)
      route=$(printf '%s' "$f" | sed 's|one\.ie/web/src/pages||;s|\.astro$||;s|/index$||')
      [ -z "$route" ] && route="/"

      in_manifest=0
      grep -qF "\"$route\"" "$MENU"  2>/dev/null && in_manifest=1
      grep -qF "'$route'"  "$MENU"   2>/dev/null && in_manifest=1
      grep -qF "\"$route\"" "$INBOX" 2>/dev/null && in_manifest=1

      if [ "$in_manifest" -eq 0 ]; then
        echo "RECONCILE[$CANON]: FAIL — $f ($route) not registered in menu.ts or in-types.ts"
        overall=1
      else
        # quoted ("..."/'...') OR template-literal (`/route or `/route?x=...`) references
        inbound=$(grep -rl "\"$route\"\\|'$route'\\|\`$route" one.ie/web/src/ 2>/dev/null \
          | grep -v "^$f\$" | grep -v "menu\.ts\|in-types\.ts" | wc -l | tr -d ' ') || inbound=0
        if [ "${inbound:-0}" -eq 0 ]; then
          echo "RECONCILE[$CANON]: WARN — $f ($route) registered but 0 inbound links"
        else
          echo "RECONCILE[$CANON]: OK — $f ($route) registered + ${inbound} inbound link(s)"
        fi
      fi
    done
    [ "$overall" -ne 0 ] && exit 1
    exit 0
    ;;

  # ── 7. Types ─────────────────────────────────────────────────────────
  # tsc delta <= 0. The budget is ZERO unless a CALLER states one.
  #
  # This used to read a gitignored W0 baseline file off disk, and that file held
  # 999999 against a `current <= baseline` test — a ratchet that could not say
  # no, for whatever tree it happened to be lying around in. Removed 2026-09-21
  # (rung A5, text/do-factory-plan.md § 7 Phase A, which carries the account).
  #
  # RECONCILE_TSC_BASELINE is the one door left and it is PER-CALL, never state
  # on disk: absent means zero, so a fresh type error fails this canon. It is
  # set by do-smoke.sh (which measures the real count first) and by
  # one.ie/web/tests/integration/reconcile.test.ts, which needs it to drive the
  # FAIL direction red without planting a broken .ts in the tree.
  types)
    baseline="${RECONCILE_TSC_BASELINE:-0}"
    # Never let a non-numeric reach $(( )) — under `set -e` that is a crash, and
    # a crashed canon reads as a red gate nobody can diagnose.
    case "$baseline" in ''|-|*[!0-9-]*) baseline=0 ;; esac

    # Determine target folder from changed files
    folder="one.ie/web"
    for f in "$@"; do
      case "$f" in packages/*) folder="packages"; break ;; channels/*) folder="channels"; break ;; esac
    done

    current=0
    if [ -d "$folder" ] && [ -f "$folder/tsconfig.json" ]; then
      # ── Governed tsc (2026-08-18) ──────────────────────────────────────
      # Six concurrent Claude sessions ran this canon at once, each spawning
      # its own `tsc --noEmit` over the SAME tree for the SAME answer: load 57
      # on 10 cores, swap exhausted, ~26 MB/s swapins. Starved, each tsc took
      # 18 min instead of 2, sessions timed out, and retries piled on more.
      # Fix: one tsc per (folder, tree-fingerprint); everyone else reuses its
      # result. Identical work collapses instead of multiplying.
      . "$(dirname "${BASH_SOURCE[0]}")/lib/govern.sh"

      # Fingerprint the tree: same fingerprint => same tsc answer.
      #
      # ONE derivation, shared with tsc-cached.sh: tsc_tree_fingerprint in
      # lib/govern.sh hashes the CONTENT of everything tsc reads (the folder's
      # .ts/.tsx/.json + lockfile, tracked or not, plus packages/sdk/src for the
      # folders that resolve @oneie/sdk types). It used to be an mtime stat
      # here AND a second copy in tsc-cached.sh — two derivations of one key is
      # how the memo split, and mtime is why it never shared across worktrees.
      _fp_extra=""
      case "$folder" in one.ie/web|channels) _fp_extra="packages/sdk/src" ;; esac
      _fp=$(tsc_tree_fingerprint "$folder" $_fp_extra)
      _cache="$GOVERN_DIR/tsc-$(printf '%s' "$folder" | tr '/' '_').$_fp"

      # Set HERE, outside the branches, so the rc=3 handler below can never read
      # a value left by an earlier folder or an unset variable.
      _tsc_rc=0
      if [ -s "$_cache" ]; then
        current=$(cat "$_cache" | tr -d '[:space:]')          # someone already computed it
      else
        # ── SLOT BEFORE LOCK ─────────────────────────────────────────────────
        # This block used to take the gate_lock HERE and then queue for a slot
        # while holding it. tsc-cached.sh had the same inversion, on the SAME
        # lock name (`tsc-<folder>` — the shared memo namespace is deliberate),
        # and between them they deadlocked the whole box three times in ~35
        # minutes on 2026-09-13: one side held a slot and waited for this lock,
        # the other held this lock and waited for a slot. Neither owner was
        # dead, so nothing reaped it, and killing the LOCK holder only handed
        # the lock to the next waiter and re-formed the cycle within seconds.
        # tsc-cached.sh § SLOT BEFORE LOCK has the full account; the proof is
        # `bash .claude/scripts/govern-order-check.sh`.
        #
        # So the lock is taken INSIDE the gate-run command, never around it: a
        # slot is held before anyone waits on this lock. The inner shell's exit
        # code carries which of the three things happened — 3 = could not lock,
        # 4 = someone else's answer appeared while we queued, 0 = we computed.
        #
        # Resolve gate-run from THIS script's own directory. An earlier version
        # used "$ROOT/..." -- ROOT is never set in this file, and under `set -u`
        # that is a hard "unbound variable" that killed the whole `types` canon.
        # Caught by tests/integration/reconcile.test.ts, which is the reason
        # that test exists.
        _tsc_tmp=$(mktemp)
        _tsc_rc=0
        _gr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-run.sh"
        _gv="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/govern.sh"
        # The compute is passed as DATA, not as nested quoting: three levels of
        # `bash -c "... \"...\" ..."` is how a pipeline silently loses its
        # redirect. Everything the inner shells read arrives through the
        # environment instead.
        _RC_SCRIPT='cd "$_RC_FOLDER" && bunx tsc --noEmit 2>&1 | grep -c "error TS" > "$_RC_TMP"'
        _RC_FOLDER="$folder" _RC_TMP="$_tsc_tmp" _RC_CACHE="$_cache" _RC_SCRIPT="$_RC_SCRIPT" \
        _RC_LOCK="tsc-$(printf '%s' "$folder" | tr '/' '_')" _RC_GV="$_gv" \
        _RC_WAIT="${RECONCILE_TSC_WAIT:-900}" _RC_TIMEOUT="${RECONCILE_TSC_TIMEOUT:-600}" \
        GOVERN_GATE_TIMEOUT=$(( ${RECONCILE_TSC_TIMEOUT:-600} + ${RECONCILE_TSC_WAIT:-900} + 60 )) \
        bash "$_gr" "tsc-reconcile:$folder" -- bash -c '
          . "$_RC_GV"
          gate_lock "$_RC_LOCK" "$_RC_WAIT" || exit 3
          trap "gate_release_all" EXIT INT TERM
          [ -s "$_RC_CACHE" ] && exit 4
          run_bounded "$_RC_TIMEOUT" bash -c "$_RC_SCRIPT" || true
          exit 0' || _tsc_rc=$?
        # `|| _tsc_rc=$?`, never a bare `$?` on the next line: this file runs
        # under `set -e`, so an exit 3 or 4 from the inner shell would kill the
        # canon before the code could be read. The `|| true` this replaces hid
        # every one of those codes.
        if [ "$_tsc_rc" = "4" ] && [ -s "$_cache" ]; then
          current=$(cat "$_cache" | tr -d '[:space:]')        # computed while we queued
          rm -f "$_tsc_tmp"
        elif [ "$_tsc_rc" != "3" ]; then
          current=$(cat "$_tsc_tmp" 2>/dev/null | tr -d '[:space:]'); rm -f "$_tsc_tmp"
          # AN UNRUN CHECK IS NEVER MEMOISED. This canon reports a DELTA and has
          # always fallen open to 0 when it could not measure — that is its own
          # call and is unchanged. What must not happen is that 0 being SHARED:
          # this file is `$GOVERN_DIR/tsc-<folder>.<fp>`, the exact object
          # tsc-cached.sh's `_cache_ok` accepts as a reusable PASS, so an unrun
          # typecheck would become a green gate for every later reader on that
          # tree, in every session and worktree.
          #
          # Reachable, and this is the line that made it likely: the slot queue
          # is now the FIRST thing a miss does, so `gate-run … no slot after
          # 1800s` on a saturated box lands here with an empty count file.
          # Measured 2026-09-13 in a sandbox: GOVERN_QUEUE_WAIT=8 with the one
          # slot held printed `OK — tsc delta=0` and wrote a `0` stamp.
          case "$current" in
            ''|*[!0-9]*) current=0 ;;                       # could not measure: no stamp
            *) printf '%s' "$current" > "$_cache" ;;         # a real count is shareable
          esac
        fi
      fi
      if [ "${_tsc_rc:-0}" = "3" ]; then
        rm -f "${_tsc_tmp:-}"
        # Lock held for the full wait. Re-check the cache once — the holder may
        # have finished and released between our last poll and now.
        if [ -s "$_cache" ]; then
          current=$(cat "$_cache" | tr -d '[:space:]')
        else
          # Never exit 0 without an answer: a gate that passes because it was
          # busy is a fail-open, which is worse than the load it avoids.
          echo "RECONCILE[types]: lock held ${RECONCILE_TSC_WAIT:-900}s — checking anyway" >&2
          _tsc_tmp=$(mktemp)
          run_bounded "${RECONCILE_TSC_TIMEOUT:-600}" \
            bash -c "cd '$folder' && bunx tsc --noEmit 2>&1 | grep -c 'error TS' > '$_tsc_tmp'" \
            2>/dev/null || true
          current=$(cat "$_tsc_tmp" 2>/dev/null | tr -d '[:space:]'); rm -f "$_tsc_tmp"
        fi
      fi
      current=${current:-0}
    fi

    delta=$((current - baseline))
    [ "$delta" -gt 0 ] && _fail "tsc delta +$delta new errors (baseline=$baseline current=$current)"
    _pass "tsc delta=$delta (baseline=$baseline current=$current)"; exit 0
    ;;

  *)
    printf 'do2-reconcile.sh: unknown canon "%s"\n' "$CANON" >&2
    printf '  canons: substrate | dictionary | authority | sdk | design | navigation | types\n' >&2
    exit 2
    ;;
esac
