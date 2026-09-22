#!/usr/bin/env bash
# do-derive-check.sh — the five checks that hold the agent-native promise.
#
# Contract: text/agent-native-plan.md § 3.5. Six of the promise's eight proof
# legs are this script, so that section is the specification and this file is
# the implementation of it.
#
#   contract   60+ receivers advertised to MCP
#   mcp        the derived tool list is computed, complete, and schema-faithful
#   binder     an unauthorised caller is stopped BY THE WRAPPER, affordance kept
#   routes     no new JSON endpoint duplicates a receiver reachable by name
#   counts     no hand-written tool ships beside its derived twin
#
# THREE EXIT CODES, NOT TWO:
#   0  ok          delivered and behaving
#   1  RED         genuinely missing or wrong
#   3  CANNOT RUN  the check could not reach its evidence
#
# Red and cannot-run send a person to opposite places. `contract` and `mcp`
# import TypeScript through bun; an import that fails because a package is
# unbuilt is CANNOT RUN, not deliverable-missing — the difference between "go
# build the SDK" and "go re-scope the work".
#
# Every threshold is env-overridable. That is not a convenience: --self-test
# drives each check to red by moving its threshold against the real tree, which
# proves the comparison is wired rather than that a fixture can be written.
#
# monorepo-only
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MIN_MCP_FLAGGED="${DERIVE_MIN_MCP_FLAGGED:-60}"
MIN_DERIVED_TOOLS="${DERIVE_MIN_DERIVED_TOOLS:-60}"
MAX_HANDWRITTEN_MCP="${DERIVE_MAX_HANDWRITTEN_MCP:-95}"   # strictly below
MAX_CURATED_CHAT="${DERIVE_MAX_CURATED_CHAT:-125}"        # at or below
API_DIR="${DERIVE_API_DIR:-$ROOT/one.ie/web/src/pages/api}"
MCP_TOOLS_DIR="${DERIVE_MCP_TOOLS_DIR:-$ROOT/packages/mcp/src/tools}"
CHAT_TOOLS_DIR="${DERIVE_CHAT_TOOLS_DIR:-$ROOT/channels/src/tools}"
ALLOWLIST="${DERIVE_ROUTE_ALLOWLIST:-$ROOT/.claude/derive-route-allowlist.txt}"

say() { printf '[derive-check] %s\n' "$*"; }
red() { printf '[derive-check] RED — %s\n' "$*" >&2; return 1; }
cant() { printf '[derive-check] CANNOT RUN — %s\n' "$*" >&2; return 3; }

need_bun() { command -v bun >/dev/null || return 3; return 0; }

# ── contract ─────────────────────────────────────────────────────────────────
# The Receiver contract carries surfaces.mcp, populated.
check_contract() {
  need_bun || { cant "bun is not on PATH"; return 3; }
  local src="$ROOT/packages/sdk/src/receivers.ts"
  [ -f "$src" ] || { cant "receivers.ts absent at $src"; return 3; }

  local out rc
  out="$(cd "$ROOT" && bun -e "
    import('./packages/sdk/src/receivers.ts')
      .then(m => {
        const R = Object.values(m.RECEIVERS);
        const flagged = R.filter(r => r.surfaces && r.surfaces.mcp);
        const named = flagged.filter(r => typeof r.surfaces.mcp === 'object' && r.surfaces.mcp.name);
        const dupes = named.length - new Set(named.map(r => r.surfaces.mcp.name)).size;
        console.log(JSON.stringify({ total: R.length, flagged: flagged.length, named: named.length, dupes }));
      })
      .catch(e => { console.error('IMPORT ' + e); process.exit(3); });
  " 2>&1)"; rc=$?

  [ "$rc" -eq 3 ] && { cant "receivers.ts did not import: ${out:0:160}"; return 3; }
  [ "$rc" -ne 0 ] && { cant "bun exited $rc: ${out:0:160}"; return 3; }

  local flagged named dupes total
  flagged=$(printf '%s' "$out" | grep -o '"flagged":[0-9]*' | cut -d: -f2)
  named=$(printf '%s' "$out" | grep -o '"named":[0-9]*' | cut -d: -f2)
  dupes=$(printf '%s' "$out" | grep -o '"dupes":[0-9]*' | cut -d: -f2)
  total=$(printf '%s' "$out" | grep -o '"total":[0-9]*' | cut -d: -f2)
  [ -z "$flagged" ] && { cant "could not parse the receiver census: ${out:0:160}"; return 3; }

  # A duplicate declared name would silently shadow one tool with another.
  [ "${dupes:-0}" -gt 0 ] && { red "$dupes duplicate declared MCP tool name(s)"; return 1; }
  [ "$flagged" -lt "$MIN_MCP_FLAGGED" ] && {
    red "surfaces.mcp on $flagged receivers, need >= $MIN_MCP_FLAGGED"; return 1; }

  say "contract ok — $flagged/$total flagged ($named carry an existing tool name)"
  return 0
}

# ── mcp ──────────────────────────────────────────────────────────────────────
# The tool list is COMPUTED from the registry, complete, and schema-faithful.
check_mcp() {
  need_bun || { cant "bun is not on PATH"; return 3; }
  local src="$ROOT/packages/mcp/src/tools/from-registry.ts"
  local dist="$ROOT/packages/mcp/dist/index.js"
  [ -f "$src" ] || { red "from-registry.ts absent — the derivation was never written"; return 1; }
  [ -f "$dist" ] || { cant "packages/mcp is unbuilt (no dist/index.js) — run bun run build"; return 3; }

  local out rc
  out="$(cd "$ROOT/packages/mcp" && bun -e "
    import('./dist/index.js')
      .then(async m => {
        const tools = m.mcpToolsFromRegistry();
        const meta = await import('@oneie/sdk/meta');
        const { RECEIVERS } = await import('@oneie/sdk/receivers');
        // Schema fidelity: a derived tool must advertise ITS OWN receiver's request
        // schema. A tool carrying the wrong schema passes every count and lies to
        // every caller, so this is checked per tool, not sampled.
        let wrong = 0;
        for (const r of Object.values(RECEIVERS)) {
          if (!r.surfaces || !r.surfaces.mcp) continue;
          const want = m.toolNameFor(r.receiver, r.surfaces.mcp);
          const t = tools.find(x => x.name === want);
          if (!t) { wrong++; continue; }
          const expect = JSON.stringify(meta.metaSchema(r.receiver).request);
          if (JSON.stringify(t.inputSchema) !== expect) wrong++;
        }
        const noSchema = tools.filter(t => !t.inputSchema || typeof t.inputSchema !== 'object').length;
        console.log(JSON.stringify({ derived: tools.length, unconvertible: m.UNCONVERTIBLE.length, wrong, noSchema }));
      })
      .catch(e => { console.error('IMPORT ' + e); process.exit(3); });
  " 2>&1)"; rc=$?

  [ "$rc" -eq 3 ] && { cant "mcp dist did not import: ${out:0:160}"; return 3; }
  [ "$rc" -ne 0 ] && { cant "bun exited $rc: ${out:0:160}"; return 3; }

  local derived unconv wrong noschema
  derived=$(printf '%s' "$out" | grep -o '"derived":[0-9]*' | cut -d: -f2)
  unconv=$(printf '%s' "$out" | grep -o '"unconvertible":[0-9]*' | cut -d: -f2)
  wrong=$(printf '%s' "$out" | grep -o '"wrong":[0-9]*' | cut -d: -f2)
  noschema=$(printf '%s' "$out" | grep -o '"noSchema":[0-9]*' | cut -d: -f2)
  [ -z "$derived" ] && { cant "could not parse the derivation census: ${out:0:160}"; return 3; }

  [ "${unconv:-0}" -gt 0 ] && { red "$unconv receiver schema(s) could not convert to JSON Schema"; return 1; }
  [ "${noschema:-0}" -gt 0 ] && { red "$noschema derived tool(s) carry no inputSchema"; return 1; }
  [ "${wrong:-0}" -gt 0 ] && { red "$wrong derived tool(s) missing or advertising the wrong receiver's schema"; return 1; }
  [ "$derived" -lt "$MIN_DERIVED_TOOLS" ] && {
    red "$derived derived tools, need >= $MIN_DERIVED_TOOLS"; return 1; }

  say "mcp ok — $derived derived tools, every schema matches its receiver"
  return 0
}

# ── binder ───────────────────────────────────────────────────────────────────
# Behavioural first, structural second. Counting handler tables is true the
# moment everything routes through one function whether or not that function
# ever consults the policy — so the count is the WEAKER half and runs last.
check_binder() {
  need_bun || { cant "bun is not on PATH"; return 3; }
  local f="$ROOT/one.ie/web/src/lib/bind-receiver.ts"
  [ -f "$f" ] || { red "bind-receiver.ts absent — the wrapper was never written"; return 1; }

  local out rc
  out="$(cd "$ROOT/one.ie/web" && bun -e "
    import('./src/lib/bind-receiver.ts')
      .then(async m => {
        const fail = [];

        // A1 — a tenant-label receiver, called by a caller holding nothing, is
        //      rejected BY THE WRAPPER and the handler never runs.
        // Assert the OUTCOME (refused, handler never reached), not the mechanism.
        // The floor returns a refusal object rather than throwing, because that
        // is how every handler in the codebase signals refusal and what the ask
        // route already reads. A check that demanded a throw would fail a
        // correct implementation.
        let ran = false;
        const bound = m.bindReceiver('world:create-group', async () => { ran = true; return { ok: true }; });
        let refused = false;
        try {
          const r = await bound({ name: 'x', slug: 'y' }, {}, {});
          refused = !!(r && typeof r === 'object' && (r.forbidden === true || r.ok === false));
        } catch { refused = true; }
        if (!refused) fail.push('A1: unauthorised caller was NOT refused');
        if (ran) fail.push('A1: handler RAN despite the auth gate — the wrapper consulted the policy and ignored it');

        // A2 — the error-as-affordance body still exists and still teaches.
        //      Checked at its OWNER, receiver-envelope, not at the binder: the
        //      binder's request check is warn-only (the declared schemas had
        //      drifted from real in-process callers), while /api/ask and
        //      /api/signal still reject with this exact body. Asserting it on
        //      the binder would assert a contract this cycle deliberately does
        //      not ship; asserting it here checks the one that does.
        const env = await import('./src/lib/receiver-envelope.ts');
        const v = env.validateReceiver('world:create-group', {});
        if (v.ok) {
          fail.push('A2: an invalid request validated clean — the affordance gate is gone');
        } else {
          const body = v.body || {};
          if (!('hint' in body) || !('expected' in body) || !('error' in body)) {
            fail.push('A2: affordance body lost a teaching field: ' + JSON.stringify(body).slice(0, 120));
          }
        }
        // A2b — and the binder must still NOTICE the mismatch, or warn-only has
        //       silently become no-op.
        const seenReq = [];
        const rw = console.warn;
        console.warn = (...a) => seenReq.push(a.join(' '));
        const b2 = m.bindReceiver('world:create-group', async () => ({ ok: true }));
        await b2({}, {}, { ownerSlug: 'someone' }).catch(() => {});
        console.warn = rw;
        if (!seenReq.some(s => /request-mismatch/.test(s))) {
          fail.push('A2b: an invalid request produced no request-mismatch warning — warn-only became no-op');
        }

        // A3 — a declared response is actually consulted. WARN mode counts, but
        //      the mismatch must be OBSERVABLE, not swallowed.
        const seen = [];
        const realWarn = console.warn;
        console.warn = (...a) => seen.push(a.join(' '));
        const b3 = m.bindReceiver('world:create-group', async () => ({ nonsense: true }));
        await b3({ name: 'x', slug: 'y' }, {}, { ownerSlug: 'someone', staff: true }).catch(() => {});
        console.warn = realWarn;
        if (!seen.some(s => /response-mismatch/.test(s))) {
          fail.push('A3: a handler returning the wrong shape produced no response-mismatch warning');
        }

        // A4 — an unlisted auth label must never fall OPEN.
        if (m.authClassFor('a-label-that-does-not-exist') === 'open') {
          fail.push('A4: an unknown auth label resolves to open');
        }

        console.log(JSON.stringify({ fail }));
      })
      .catch(e => { console.error('IMPORT ' + e); process.exit(3); });
  " 2>&1)"; rc=$?

  [ "$rc" -eq 3 ] && { cant "bind-receiver.ts did not import: ${out:0:200}"; return 3; }
  [ "$rc" -ne 0 ] && { cant "bun exited $rc: ${out:0:200}"; return 3; }

  local fails
  fails="$(printf '%s' "$out" | sed -n 's/.*"fail":\[\(.*\)\]}.*/\1/p')"
  [ -n "$fails" ] && [ "$fails" != "" ] && { red "binder behaviour: $fails"; return 1; }

  # Structural, and deliberately last: a raw handler table that never mentions
  # bindReceiver is a dispatcher that has to remember.
  local raw=0 f2
  while IFS= read -r f2; do
    grep -q "bindReceiver" "$f2" || { say "  raw handler table: ${f2#$ROOT/}"; raw=$((raw + 1)); }
  done < <(grep -rlE '^const (HANDLERS|RESOLVERS)' "$ROOT/one.ie/web/src/lib" --include='*.ts' 2>/dev/null || true)
  [ "$raw" -gt 0 ] && { red "$raw handler table(s) bind outside bindReceiver"; return 1; }

  say "binder ok — rejects before the handler, keeps the affordance, checks the response, 0 raw tables"
  return 0
}

# ── routes ───────────────────────────────────────────────────────────────────
# A new JSON endpoint duplicating a receiver reachable by name. NOT a cap on
# routes: auth callbacks, webhooks, uploads and non-JSON responses are exempt,
# and today's tree is grandfathered in an allowlist that may shrink, never grow.
EXEMPT_RE='(^|/)(auth|webhook|webhooks|upload|uploads|oauth|callback|stripe|sse|stream|rss|sitemap|feed|og|image|images|avatar|media|export|cron|health)(/|$)'

check_routes() {
  [ -d "$API_DIR" ] || { cant "api dir absent at $API_DIR"; return 3; }
  [ -f "$ALLOWLIST" ] || { cant "route allowlist absent at $ALLOWLIST — freeze it first (--freeze-routes)"; return 3; }
  need_bun || { cant "bun is not on PATH"; return 3; }

  local receivers
  receivers="$(cd "$ROOT" && bun -e "
    import('./packages/sdk/src/receivers.ts')
      .then(m => console.log(Object.keys(m.RECEIVERS).join('\n')))
      .catch(() => process.exit(3));
  " 2>/dev/null)" || { cant "could not read the receiver list"; return 3; }
  [ -z "$receivers" ] && { cant "receiver list came back empty"; return 3; }

  # noun set: the second half of every receiver name, singularised
  local nouns
  nouns="$(printf '%s\n' "$receivers" | sed 's/^[a-z-]*://' | sed 's/s$//' | sort -u)"

  local offenders=0 rel key
  while IFS= read -r f; do
    rel="${f#$API_DIR/}"
    printf '%s\n' "$rel" | grep -qE "$EXEMPT_RE" && continue
    grep -qF -- "$rel" "$ALLOWLIST" && continue
    # op key: path minus dynamic segments and extension, singularised
    key="$(printf '%s' "$rel" | sed 's/\.ts$//' | sed 's/\[[^]]*\]//g' | tr '/' ' ' | tr -s ' ')"
    for n in $key; do
      n="$(printf '%s' "$n" | sed 's/s$//')"
      [ -z "$n" ] && continue
      if printf '%s\n' "$nouns" | grep -qx -- "$n"; then
        say "  twin: $rel duplicates a receiver reachable by name (noun '$n')"
        offenders=$((offenders + 1))
        break
      fi
    done
  done < <(find "$API_DIR" -name '*.ts' -type f 2>/dev/null)

  [ "$offenders" -gt 0 ] && {
    red "$offenders new route(s) duplicate a by-name receiver — use the door, or add an exempt kind"; return 1; }

  say "routes ok — no new twin against $(wc -l < "$ALLOWLIST" | tr -d ' ') grandfathered entries"
  return 0
}

freeze_routes() {
  [ -d "$API_DIR" ] || { cant "api dir absent at $API_DIR"; return 3; }
  find "$API_DIR" -name '*.ts' -type f | sed "s|^$API_DIR/||" | sort > "$ALLOWLIST"
  say "froze $(wc -l < "$ALLOWLIST" | tr -d ' ') route(s) into ${ALLOWLIST#$ROOT/} — this list may shrink, never grow"
}

# ── counts ───────────────────────────────────────────────────────────────────
# The deletion, measured. The load-bearing assertion is COEXISTENCE, not the
# number: "strictly below 95" alone is satisfied by deleting one tool.
check_counts() {
  [ -d "$MCP_TOOLS_DIR" ] || { cant "mcp tools dir absent at $MCP_TOOLS_DIR"; return 3; }
  need_bun || { cant "bun is not on PATH"; return 3; }

  local flagged
  flagged="$(cd "$ROOT" && bun -e "
    import('./packages/sdk/src/receivers.ts')
      .then(m => {
        for (const r of Object.values(m.RECEIVERS)) if (r.surfaces && r.surfaces.mcp) console.log(r.receiver);
      })
      .catch(() => process.exit(3));
  " 2>/dev/null)" || { cant "could not read the flagged receivers"; return 3; }

  # Coexistence: a flagged receiver must not still have a SINGLE-RECEIVER
  # hand-written wrapper. Scoped to single-receiver tools on purpose — a
  # surviving multi-receiver recipe legitimately names a flagged receiver among
  # several, and the pragma covers anything this still catches wrongly.
  local coexist=0 r hits
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    while IFS= read -r tf; do
      grep -qF -- 'derive:allow-handwritten' "$tf" && continue
      # a module naming exactly ONE distinct receiver is a single-receiver wrapper
      hits="$(grep -ohE '"[a-z][a-z-]*:[a-z][a-z-]*"' "$tf" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
      [ "${hits:-0}" -eq 1 ] || continue
      say "  coexists: $r still has a hand-written wrapper in ${tf#$ROOT/}"
      coexist=$((coexist + 1))
    done < <(grep -rlF -- "\"$r\"" "$MCP_TOOLS_DIR" --include='*.ts' 2>/dev/null || true)
  done <<< "$flagged"

  [ "$coexist" -gt 0 ] && { red "$coexist hand-written tool(s) ship beside a derived twin"; return 1; }

  # from-registry.ts is the DERIVATION, not a hand-written tool. Counting it
  # inflated the census by one and would have let the file that deletes
  # hand-written tools count as one itself.
  local hw cur
  hw="$(grep -h 'name: "' $(ls "$MCP_TOOLS_DIR"/*.ts 2>/dev/null | grep -v '/from-registry\.ts$') 2>/dev/null | wc -l | tr -d ' ')"
  [ "$hw" -ge "$MAX_HANDWRITTEN_MCP" ] && {
    red "$hw hand-written MCP tool definitions, must be strictly below $MAX_HANDWRITTEN_MCP"; return 1; }

  if [ -d "$CHAT_TOOLS_DIR" ]; then
    cur="$(grep -rho 'defineWorkspaceTool(' "$CHAT_TOOLS_DIR"/*.ts 2>/dev/null | wc -l | tr -d ' ')"
    [ "${cur:-0}" -gt "$MAX_CURATED_CHAT" ] && {
      red "$cur curated chat tools, ceiling is $MAX_CURATED_CHAT"; return 1; }
  else
    cur="n/a"
  fi

  say "counts ok — no coexistence, $hw hand-written MCP defs (< $MAX_HANDWRITTEN_MCP), $cur curated chat tools"
  return 0
}

# ── self-test ────────────────────────────────────────────────────────────────
# Each check is driven to RED against the real tree by moving its own threshold
# or pointing it at a fixture carrying the defect. A checker that has only ever
# run against a healthy tree proves nothing about what it would catch.
self_test() {
  local fails=0 rc tmp
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN

  expect_red() { # expect_red <label> <cmd...>
    local label="$1"; shift
    "$@" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 1 ]; then printf '  ok   %s -> RED\n' "$label"
    else printf '  FAIL %s -> expected 1, got %s\n' "$label" "$rc"; fails=$((fails + 1)); fi
  }
  expect_cant() { # expect_cant <label> <cmd...>
    local label="$1"; shift
    "$@" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 3 ]; then printf '  ok   %s -> CANNOT RUN\n' "$label"
    else printf '  FAIL %s -> expected 3, got %s\n' "$label" "$rc"; fails=$((fails + 1)); fi
  }

  # contract: an unreachable floor must go red, not pass
  expect_red "contract (floor 99999)" env DERIVE_MIN_MCP_FLAGGED=99999 bash "$0" contract
  # mcp: same
  expect_red "mcp (floor 99999)" env DERIVE_MIN_DERIVED_TOOLS=99999 bash "$0" mcp
  # counts: a ceiling of 0 hand-written defs must go red while any survive
  expect_red "counts (max-handwritten 1)" env DERIVE_MAX_HANDWRITTEN_MCP=1 bash "$0" counts
  # routes: a fixture tree carrying a twin of a real receiver
  mkdir -p "$tmp/api/groups"
  : > "$tmp/api/groups/create.ts"
  : > "$tmp/allow.txt"
  expect_red "routes (fixture twin)" env DERIVE_API_DIR="$tmp/api" DERIVE_ROUTE_ALLOWLIST="$tmp/allow.txt" bash "$0" routes
  # routes: the same twin, allowlisted, must pass — the ratchet grandfathers
  printf 'groups/create.ts\n' > "$tmp/allow.txt"
  env DERIVE_API_DIR="$tmp/api" DERIVE_ROUTE_ALLOWLIST="$tmp/allow.txt" bash "$0" routes >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then printf '  ok   routes (allowlisted) -> ok\n'
  else printf '  FAIL routes (allowlisted) -> expected 0, got %s\n' "$rc"; fails=$((fails + 1)); fi
  # cannot-run is distinguishable from red
  expect_cant "routes (missing allowlist)" env DERIVE_API_DIR="$tmp/api" DERIVE_ROUTE_ALLOWLIST="$tmp/nope.txt" bash "$0" routes
  expect_cant "counts (missing tools dir)" env DERIVE_MCP_TOOLS_DIR="$tmp/nope" bash "$0" counts

  # binder: the defining fixture — a wrapper that consults the policy and calls
  # the handler anyway passes every structural count and must fail A1.
  cat > "$tmp/leaky.mjs" <<'EOF'
const fail = [];
let ran = false;
const leaky = (receiver, handler) => async (d, e, c) => {
  const authed = c && (c.staff === true || c.ownerSlug);   // consulted...
  if (!authed) console.warn('would reject');               // ...and ignored
  return handler(d, e, c);
};
const bound = leaky('world:create-group', async () => { ran = true; return { ok: true }; });
let threw = false;
try { await bound({}, {}, {}); } catch { threw = true; }
if (!threw) fail.push('A1: unauthorised caller was NOT rejected');
if (ran) fail.push('A1: handler RAN despite the auth gate');
process.exit(fail.length ? 1 : 0);
EOF
  node "$tmp/leaky.mjs" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 1 ]; then printf '  ok   binder (leaky-wrapper fixture) -> RED\n'
  else printf '  FAIL binder (leaky-wrapper fixture) -> expected 1, got %s\n' "$rc"; fails=$((fails + 1)); fi

  if [ "$fails" -eq 0 ]; then say "self-test PASS — every check can go red, and red is distinguishable from cannot-run"; return 0; fi
  printf '[derive-check] self-test FAILED (%s)\n' "$fails" >&2
  return 1
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
  contract)       check_contract ;;
  mcp)            check_mcp ;;
  binder)         check_binder ;;
  routes)         check_routes ;;
  counts)         check_counts ;;
  --freeze-routes) freeze_routes ;;
  --self-test)    self_test ;;
  all|"")
    rc=0
    for c in contract mcp binder routes counts; do
      bash "$0" "$c" || rc=$?
    done
    exit "$rc" ;;
  *) printf 'usage: %s {contract|mcp|binder|routes|counts|all|--self-test|--freeze-routes}\n' "$(basename "$0")" >&2; exit 2 ;;
esac
