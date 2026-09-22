#!/usr/bin/env bash
# speed-waterfall-check.sh — proves a serial-hop waterfall was actually
# collapsed into a fan-out, structurally, on both surfaces this checker will
# eventually cover:
#
#   --chat    (C9, THIS cycle) api/chat.ts's pre-flight ladder: three
#             independent D1/crypto reads (loadPublishedPage, getThread,
#             visitorHash) that used to run one `await` at a time before the
#             `...P` parallel block even opened. Ships in THIS cycle.
#   --tenant  (C8) the tenant page round trip. Checks THREE files together —
#             u/[slug]/index.astro, u/[slug]/p/[pageSlug].astro and the loader
#             module lib/tenant/page-data.ts they both delegate their data wave
#             to. Checking the frontmatters ALONE would be fooled by a
#             "collapse" that merely relocated the round trips one level down
#             into a helper, so each of the three carries its own await-line
#             ceiling (5 / 5 / 4) as well as a required fan-out shape. That
#             pair — required join + per-file ceiling — is what makes the
#             ceiling TRANSITIVE: 3 dependency levels per route, counted across
#             frontmatter + loader, leaf helpers one node each.
#
#             The two declared exceptions are visible in the numbers: the
#             [pageSlug] draft-preview authz gate (a security gate; asserted to
#             be EXACTLY ONE authorizeWorkspace call, never zero, never two) and
#             index.astro's invite-token early-return branch.
#   --check-gate  SELF-TEST: plant the pre-fix serial shape in a scratch file,
#             prove --chat's structural check flags it RED, then prove the
#             real working tree is GREEN. Same discipline as
#             speed-cache-check.sh and speed-check.mjs --check-gate: a checker
#             that has never been observed failing is not evidence of anything.
#
# WHY STRUCTURAL, NOT A LIVE TIMING DIFF: chat.ts's pre-flight reads D1 and
# crypto.subtle inside a live Worker request — there is no cheap way to
# dependency-inject fake latency into 1,200+ lines of route handler from a
# shell script, and a live prod A/B (the C6 method) needs a funded turn +
# billing side-effects, which this checker must not trigner on every run.
# So this proves the SHAPE that makes concurrency possible (three `P` promises
# created before any of them is awaited, joined with Promise.all/await),
# and the real timing readback lives in text/speed-results.md (W4, manual).
#
# Usage:
#   speed-waterfall-check.sh --chat          structural pass/fail, exit 0/1
#   speed-waterfall-check.sh --tenant         NOT YET SHIPPED — exits 2
#   speed-waterfall-check.sh --check-gate    self-test, exits 0/1

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHAT_TS="one.ie/web/src/pages/api/chat.ts"

cd "$ROOT"

check_chat() {
	local file="$1"
	if [ ! -f "$file" ]; then
		echo "[speed-waterfall-check] missing $file" >&2
		return 2
	fi
	# GREEN shape: the three independent reads are captured as promises
	# (never `await`-ed at their own call site) and joined explicitly.
	local has_published_p has_thread_p has_visitor_p has_join
	has_published_p=$(grep -c 'const publishedPageP: Promise<PublishedPage | null> =' "$file" || true)
	has_thread_p=$(grep -c 'const claimedThreadP: Promise<ClaimedThread | null> =' "$file" || true)
	has_visitor_p=$(grep -c 'const visitorHashP: Promise<string | null> =' "$file" || true)
	has_join=$(grep -c 'Promise.all(\[claimedThreadP, visitorHashP\])' "$file" || true)
	# RED shape: any of the three still awaited serially, inline, at its own
	# call site — the pattern this cycle removed.
	local red_published red_thread red_visitor
	red_published=$(grep -cE '\?\s*await loadPublishedPage\(' "$file" || true)
	red_thread=$(grep -cE 'const t = await getThread\(' "$file" || true)
	red_visitor=$(grep -cE 'attestedVisitorHash \?\? \(convoCookieId \? await visitorHash\(' "$file" || true)

	if [ "$has_published_p" -ge 1 ] && [ "$has_thread_p" -ge 1 ] && [ "$has_visitor_p" -ge 1 ] \
		&& [ "$has_join" -ge 1 ] \
		&& [ "$red_published" -eq 0 ] && [ "$red_thread" -eq 0 ] && [ "$red_visitor" -eq 0 ]; then
		return 0
	fi
	return 1
}

TENANT_LOADER="one.ie/web/src/lib/tenant/page-data.ts"
TENANT_INDEX="one.ie/web/src/pages/u/[slug]/index.astro"
TENANT_PAGE="one.ie/web/src/pages/u/[slug]/p/[pageSlug].astro"

# THE CEILING, as three numbers. C8 pinned 3 dependency levels per tenant route,
# counted TRANSITIVELY across the frontmatter and the loader module it delegates
# to (leaf helpers count as one node each). await-bearing LINES are the
# enforceable proxy: they cannot be relocated, because moving a hop out of a page
# and into the loader raises the loader's count. Raising any of these three
# numbers is a decision, not a fix.
MAX_AWAIT_LINES_INDEX=5   # env import + invite early-return + the wave + bindings + rows (was 11)
MAX_AWAIT_LINES_PAGE=5    # env import + the wave + the draft gate + bindings + rows (was 7)
MAX_AWAIT_LINES_LOADER=4  # two Promise.all joins + the rare non-default home read

# NOTE ON GREP, the trap this checker was written around: never
# `<producer> | grep -q PAT` under `set -o pipefail` — a MATCH kills the producer
# with SIGPIPE and the pipeline reports 141, which reads as a false RED (or, under
# a `!`, a false GREEN). Every check below is `grep -c ... FILE || true` captured
# into a variable and compared numerically. No pipes anywhere.

check_tenant_loader() {
	local file="$1"
	if [ ! -f "$file" ]; then
		echo "[speed-waterfall-check] missing $file" >&2
		return 2
	fi
	local home_join page_join awaits
	home_join=$(grep -c 'await Promise.all(\[ctxP, settingsP, brainAgentP, authzP, homeRowDefaultP\])' "$file" || true)
	page_join=$(grep -c 'await Promise.all(\[rowP, expRowP, canEditP\])' "$file" || true)
	awaits=$(grep -c 'await ' "$file" || true)
	if [ "$home_join" -ge 1 ] && [ "$page_join" -ge 1 ] && [ "$awaits" -le "$MAX_AWAIT_LINES_LOADER" ]; then
		return 0
	fi
	return 1
}

check_tenant_index() {
	local file="$1"
	if [ ! -f "$file" ]; then
		echo "[speed-waterfall-check] missing $file" >&2
		return 2
	fi
	local green red_ctx red_setting red_agent red_authz awaits
	green=$(grep -c 'await loadWorkspaceHomeData(' "$file" || true)
	# RED shapes: the four helpers this page used to await one hop at a time.
	red_ctx=$(grep -c 'await getSlugContext(' "$file" || true)
	red_setting=$(grep -c 'await readWorkspaceSetting' "$file" || true)
	red_agent=$(grep -c 'await loadAgent(' "$file" || true)
	red_authz=$(grep -c 'await authorizeWorkspace(' "$file" || true)
	awaits=$(grep -c 'await ' "$file" || true)
	if [ "$green" -ge 1 ] && [ "$red_ctx" -eq 0 ] && [ "$red_setting" -eq 0 ] \
		&& [ "$red_agent" -eq 0 ] && [ "$red_authz" -eq 0 ] \
		&& [ "$awaits" -le "$MAX_AWAIT_LINES_INDEX" ]; then
		return 0
	fi
	return 1
}

check_tenant_page() {
	local file="$1"
	if [ ! -f "$file" ]; then
		echo "[speed-waterfall-check] missing $file" >&2
		return 2
	fi
	local green red_exp authz awaits
	green=$(grep -c 'await loadTenantPageData(' "$file" || true)
	red_exp=$(grep -c 'const expRow = await env.DB' "$file" || true)
	# EXACTLY ONE: the draft-preview gate is the declared security exception.
	# Zero means the gate was deleted; two means the owner-edit walk crept back.
	authz=$(grep -c 'await authorizeWorkspace(' "$file" || true)
	awaits=$(grep -c 'await ' "$file" || true)
	if [ "$green" -ge 1 ] && [ "$red_exp" -eq 0 ] && [ "$authz" -eq 1 ] \
		&& [ "$awaits" -le "$MAX_AWAIT_LINES_PAGE" ]; then
		return 0
	fi
	return 1
}

CHECK_GATE=0
MODE=""
for arg in "$@"; do
	case "$arg" in
	--chat) MODE="chat" ;;
	--tenant) MODE="tenant" ;;
	--check-gate) CHECK_GATE=1 ;;
	*)
		echo "[speed-waterfall-check] unknown flag: $arg" >&2
		exit 2
		;;
	esac
done

if [ "$CHECK_GATE" -eq 1 ]; then
	echo "speed-waterfall-check --check-gate — proving the --chat structural check bites"
	echo

	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT

	RED_FILE="$TMP/chat-red.ts"
	cat >"$RED_FILE" <<'EOF'
const publishedPage: PublishedPage | null =
  env.DB && pageUrl
    ? await loadPublishedPage(env as { DB?: D1Database }, pageUrl, locals.workspaceContext?.workspace as string | undefined).catch(() => null)
    : null
let claimedThread: ClaimedThread | null = null
if (env.DB && typeof body.thread === 'string' && body.thread) {
  const t = await getThread(env.DB, body.thread)
  if (t) claimedThread = { id: t.id, slug: t.slug, user_cookie: t.userCookie }
}
const convoIdentity: ConversationIdentity = {
  cookieId: convoCookieId,
  visitorHash: attestedVisitorHash ?? (convoCookieId ? await visitorHash(convoCookieId, env.WS_SALT ?? '') : null),
  signedInActorId: (locals.slug as string | undefined) ?? null,
}
EOF

	bad=0
	if check_chat "$RED_FILE"; then
		echo "  FAIL the pre-fix serial shape was NOT flagged (got pass, want fail)"
		bad=1
	else
		echo "  ok   the pre-fix serial shape is flagged RED (got fail, want fail)"
	fi

	if check_chat "$CHAT_TS"; then
		echo "  ok   the working tree's chat.ts is GREEN (got pass, want pass)"
	else
		echo "  FAIL the working tree's chat.ts did NOT pass (got fail, want pass)"
		bad=1
	fi

	echo
	echo "…and that the --tenant structural check bites"
	echo

	# PLANTED FIXTURES, never the live files. Mutating u/[slug]/index.astro and
	# restoring it would leave a corrupted page behind any interrupted run, and is
	# unsafe under a parallel batch. roles-check.sh --check-decide is the shape.
	RED_LOADER="$TMP/page-data-red.ts"
	cat >"$RED_LOADER" <<'EOF'
// The pre-C8 shape, relocated into a helper: each leg still gated on the one
// before it. A checker that only counted `Promise.all` in the pages would score
// this GREEN — which is the whole reason the loader carries its own ceiling.
export async function loadWorkspaceHomeData(args) {
  const ctx = await getSlugContext(args.slug, args.env.DB, args.env.CONTENT)
  const settings = await readWorkspaceSettings(args.env.DB, args.slug, ['home-page'])
  const brainAgent = await loadAgent(`${args.slug}--brain`, args.slug, args.env)
  const authorized = await authorize(args.locals, args.slug, args.env.DB, args.env)
  const homeRow = await args.env.DB.prepare(SQL).bind(args.slug).first()
  return { ctx, settings, brainAgent, authorized, homeRow }
}
export async function loadTenantPageData(args) {
  const row = await args.env.DB.prepare(SQL).bind(args.pageSlug, args.slug).first()
  const expRow = await args.env.DB.prepare(SQL2).bind(args.pageSlug, args.slug).first()
  const canEdit = await authorize(args.locals, args.slug, args.env.DB, args.env)
  return { row, expRow, canEdit }
}
EOF

	RED_INDEX="$TMP/index-red.astro"
	cat >"$RED_INDEX" <<'EOF'
const ctx = await getSlugContext(slug, env.DB, env.CONTENT).catch(() => null)
const homePageSetting = await readWorkspaceSetting(env.DB, slug, 'home-page')
const homeRow = await env.DB.prepare(SQL).bind(slug, homePageSlug, 'published').first()
const canEditHome = homeRow && Astro.locals.slug
  ? (await authorizeWorkspace(Astro.locals, homeRow.workspace, env.DB, env)).ok
  : false
const brainAgent = await loadAgent(`${slug}--brain`, slug, { CONTENT: env.CONTENT })
const widget = await readWorkspaceSetting(env.DB, slug, 'chat-widget')
EOF

	RED_PAGE="$TMP/pageslug-red.astro"
	cat >"$RED_PAGE" <<'EOF'
const row = await env.DB.prepare(SQL).bind(pageSlug, slug).first()
const canEdit = Astro.locals.slug
  ? (await authorizeWorkspace(Astro.locals, row.workspace, env.DB, env)).ok
  : false
const expRow = await env.DB
  .prepare(SQL2)
  .bind(pageSlug, slug)
  .first()
EOF

	if check_tenant_loader "$RED_LOADER"; then
		echo "  FAIL a serial LOADER was NOT flagged (got pass, want fail)"
		bad=1
	else
		echo "  ok   a serial loader is flagged RED — relocating hops into a helper does not pass"
	fi

	if check_tenant_index "$RED_INDEX"; then
		echo "  FAIL the pre-C8 index.astro shape was NOT flagged (got pass, want fail)"
		bad=1
	else
		echo "  ok   the pre-C8 index.astro serial ladder is flagged RED"
	fi

	if check_tenant_page "$RED_PAGE"; then
		echo "  FAIL the pre-C8 [pageSlug].astro shape was NOT flagged (got pass, want fail)"
		bad=1
	else
		echo "  ok   the pre-C8 [pageSlug].astro serial shape is flagged RED"
	fi

	if check_tenant_loader "$TENANT_LOADER"; then
		echo "  ok   the working tree's loader is GREEN (got pass, want pass)"
	else
		echo "  FAIL the working tree's loader did NOT pass (got fail, want pass)"
		bad=1
	fi

	if check_tenant_index "$TENANT_INDEX"; then
		echo "  ok   the working tree's index.astro is GREEN (got pass, want pass)"
	else
		echo "  FAIL the working tree's index.astro did NOT pass (got fail, want pass)"
		bad=1
	fi

	if check_tenant_page "$TENANT_PAGE"; then
		echo "  ok   the working tree's [pageSlug].astro is GREEN (got pass, want pass)"
	else
		echo "  FAIL the working tree's [pageSlug].astro did NOT pass (got fail, want pass)"
		bad=1
	fi

	if [ "$bad" -eq 0 ]; then
		echo
		echo "waterfall gate proven: it fails on the serial shape and passes on the fan-out"
		exit 0
	fi
	echo
	echo "$bad self-test(s) FAILED — the waterfall gate is not trustworthy"
	exit 1
fi

case "$MODE" in
chat)
	if check_chat "$CHAT_TS"; then
		echo "[speed-waterfall-check --chat] ok — loadPublishedPage/getThread/visitorHash fire concurrently, joined before deriveConversationKey"
		exit 0
	fi
	echo "[speed-waterfall-check --chat] FAIL — the pre-flight ladder in $CHAT_TS is serial again" >&2
	exit 1
	;;
tenant)
	tbad=0
	if check_tenant_loader "$TENANT_LOADER"; then
		echo "[speed-waterfall-check --tenant] ok — $TENANT_LOADER fans out both waves and stays within $MAX_AWAIT_LINES_LOADER await lines"
	else
		echo "[speed-waterfall-check --tenant] FAIL — $TENANT_LOADER is serial again, missing, or exceeds $MAX_AWAIT_LINES_LOADER await lines" >&2
		tbad=1
	fi
	if check_tenant_index "$TENANT_INDEX"; then
		echo "[speed-waterfall-check --tenant] ok — $TENANT_INDEX delegates its data wave and stays within $MAX_AWAIT_LINES_INDEX await lines"
	else
		echo "[speed-waterfall-check --tenant] FAIL — $TENANT_INDEX awaits a helper serially again, or exceeds $MAX_AWAIT_LINES_INDEX await lines" >&2
		tbad=1
	fi
	if check_tenant_page "$TENANT_PAGE"; then
		echo "[speed-waterfall-check --tenant] ok — $TENANT_PAGE delegates its data wave, keeps exactly one (draft-gate) authz call, and stays within $MAX_AWAIT_LINES_PAGE await lines"
	else
		echo "[speed-waterfall-check --tenant] FAIL — $TENANT_PAGE is serial again, lost or doubled its authz gate, or exceeds $MAX_AWAIT_LINES_PAGE await lines" >&2
		tbad=1
	fi
	if [ "$tbad" -eq 0 ]; then
		echo "[speed-waterfall-check --tenant] ok — 3 dependency levels per route, counted across frontmatter AND loader"
		exit 0
	fi
	exit 1
	;;
*)
	echo "usage: speed-waterfall-check.sh --chat|--tenant [--check-gate]" >&2
	exit 2
	;;
esac
