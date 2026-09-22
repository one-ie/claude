#!/usr/bin/env bash
# speed-parity-check.sh — C10's checker. Three flags:
#
#   --parity      static, exit 0/1 — P1-P6, the six structural facts the
#                 Interface Contract (text/speed-todo.md, C10) pins: the
#                 altitude of the read probe (P1), the sequence order of the
#                 store middleware (P2), the frozen export surface of
#                 lib/page-cache.ts (P3), pageCacheVerdict as the single
#                 decision point in both tenant routes (P4), hasLiveBindings
#                 staying uncapped (P5), and no per-visitor value reaching
#                 LeadCaptureScript un-gated (P6).
#   --freshness   static, exit 0/1 — F1/F2. touchPage is the ONE choke point
#                 for "this page changed" (IC row 8): every UPDATE pages SET /
#                 INSERT INTO pages write site across the four writer files
#                 must be followed by a touchPage( call within 6 lines (F1),
#                 and the old name (broadcastPageUpdated) must have zero
#                 occurrences repo-wide once the rename lands (F2) — a
#                 survivor is a second, silent choke point.
#   --check-gate  exit 0 iff EVERY one of six planted violations goes RED
#                 against the real checks above. G1/G2/G4/G5 exercise the pure
#                 pageCacheVerdict() function directly with a bad input — no
#                 file mutation needed. G3 and G6 mutate a COPY of the source
#                 under $TMP (never a tracked file) and re-run the matching
#                 structural check against that copy.
#
# Exit codes: 0 pass · 1 fail · 2 missing prerequisite (a source file or `bun`
# is absent — never reported as pass).
#
# THE TWO TRAPS THIS SCRIPT IS WRITTEN AROUND (both already paid for in this
# repo — see .claude/CLAUDE.md and text/learnings.md):
#   1. Plant against a FIXTURE COPY in $TMP, never a tracked file. An
#      interrupted run must never leave middleware.ts / inject-rows.ts /
#      page-cache.ts corrupted, and mutate-then-restore is unsafe under a live
#      parallel batch (roles-check.sh --check-decide is the shape copied here).
#   2. NO `producer | grep -q` under `set -o pipefail` anywhere — a MATCH
#      SIGPIPEs the producer and the pipeline reports 141 (false RED, or false
#      GREEN under a `!`). Every check below captures a command's full output
#      to a variable or a scratch file FIRST (`out=$(...)`), then matches it
#      with `grep -c` (which reads to EOF, never exits early) or an `awk`
#      pass with no `head`/`grep -q` downstream of a live process.
#
# Usage:
#   speed-parity-check.sh --parity
#   speed-parity-check.sh --freshness
#   speed-parity-check.sh --check-gate

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PAGE_CACHE_TS="one.ie/web/src/lib/page-cache.ts"
PAGE_CACHE_MW="one.ie/web/src/lib/page-cache-middleware.ts"
MIDDLEWARE_TS="one.ie/web/src/middleware.ts"
INJECT_ROWS="one.ie/web/src/lib/puck/inject-rows.ts"
PAGESLUG_ASTRO="one.ie/web/src/pages/u/[slug]/p/[pageSlug].astro"
INDEX_ASTRO="one.ie/web/src/pages/u/[slug]/index.astro"
PAGES_TS="one.ie/web/src/lib/resolvers/pages.ts"
PAGES_CHAT_TS="one.ie/web/src/lib/resolvers/pages-chat.ts"
API_SLUG_TS="one.ie/web/src/pages/api/pages/[slug].ts"
API_INDEX_TS="one.ie/web/src/pages/api/pages/index.ts"

WRITER_FILES=("$PAGES_TS" "$PAGES_CHAT_TS" "$API_SLUG_TS" "$API_INDEX_TS")
ROUTE_FILES=("$PAGESLUG_ASTRO" "$INDEX_ASTRO")

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

need_file() {
	if [ ! -f "$1" ]; then
		echo "[speed-parity-check] missing $1" >&2
		return 2
	fi
	return 0
}

need_bun() {
	if ! command -v bun >/dev/null 2>&1; then
		echo "[speed-parity-check] bun not on PATH — cannot run pure-function checks" >&2
		return 2
	fi
	return 0
}

# first_field_of_first_line PATTERN VAR_CONTAINING_GREP_N_OUTPUT
# Never `grep -n ... | head -1` — that pipes a live grep into an early-exiting
# consumer. Every caller here first captures grep's FULL output to a shell
# variable (`matches=$(grep -n ... file || true)`), which is a command
# substitution (reads to EOF, no early-exit risk), then this just does string
# processing on the already-captured text.
first_line_number() {
	awk -F: 'NR==1 && $1 != "" {n=$1} END{print n+0}' <<<"$1"
}

# ---------------------------------------------------------------------------
# --parity : P1-P6
# ---------------------------------------------------------------------------

p1_altitude() {
	local file="${1:-$MIDDLEWARE_TS}"
	need_file "$file" || return 2
	local isprimary_return domainmemo_matches pagecache_matches
	isprimary_return=$(awk '/const isPrimary =/{f=1} f && /return next\(\);/{print NR; exit}' "$file")
	domainmemo_matches=$(grep -n 'readDomainRowMemo(' "$file" || true)
	pagecache_matches=$(grep -n 'readPageCache(' "$file" || true)
	local domainmemo_line pagecache_line
	domainmemo_line=$(first_line_number "$domainmemo_matches")
	pagecache_line=$(first_line_number "$pagecache_matches")
	if [ -z "${isprimary_return:-}" ] || [ "$domainmemo_line" -eq 0 ] || [ "$pagecache_line" -eq 0 ]; then
		echo "  P1 FAIL — could not locate anchors (isPrimary-return='${isprimary_return:-}' readDomainRowMemo=$domainmemo_line readPageCache=$pagecache_line) in $file" >&2
		return 1
	fi
	if [ "$pagecache_line" -gt "$isprimary_return" ] && [ "$pagecache_line" -lt "$domainmemo_line" ]; then
		return 0
	fi
	echo "  P1 FAIL — altitude violated in $file: isPrimary-return=$isprimary_return readPageCache=$pagecache_line readDomainRowMemo=$domainmemo_line (want isPrimary-return < readPageCache < readDomainRowMemo)" >&2
	return 1
}

p2_sequence() {
	local file="${1:-$MIDDLEWARE_TS}"
	need_file "$file" || return 2
	local block
	block=$(sed -n '/^export const onRequest = sequence(/,/^);/p' "$file")
	if [ -z "$block" ]; then
		echo "  P2 FAIL — sequence(...) block not found in $file" >&2
		return 1
	fi
	local perfstart_matches store_matches mainmw_matches
	perfstart_matches=$(grep -n 'perfStart' <<<"$block" || true)
	store_matches=$(grep -n 'pageCacheStore' <<<"$block" || true)
	mainmw_matches=$(grep -nE '^\s*mainMiddleware,\s*$' <<<"$block" || true)
	local perfstart_line store_line mainmw_line
	perfstart_line=$(first_line_number "$perfstart_matches")
	store_line=$(first_line_number "$store_matches")
	mainmw_line=$(first_line_number "$mainmw_matches")
	if [ "$perfstart_line" -eq 0 ] || [ "$store_line" -eq 0 ] || [ "$mainmw_line" -eq 0 ]; then
		echo "  P2 FAIL — sequence missing an anchor (perfStart=$perfstart_line pageCacheStore=$store_line mainMiddleware=$mainmw_line)" >&2
		return 1
	fi
	if [ "$store_line" -gt "$perfstart_line" ] && [ "$store_line" -lt "$mainmw_line" ]; then
		return 0
	fi
	echo "  P2 FAIL — sequence order wrong: perfStart=$perfstart_line pageCacheStore=$store_line mainMiddleware=$mainmw_line (want perfStart < pageCacheStore < mainMiddleware)" >&2
	return 1
}

p3_exports() {
	local file="${1:-$PAGE_CACHE_TS}"
	need_file "$file" || return 2
	local pinned=(PAGE_CACHE_TTL_SECONDS PAGE_CACHE_HEADER PAGE_CACHE_STATUS_HEADER pageCacheKey PageCacheInput pageCacheVerdict readPageCache storePageCache purgePageCache)
	# PageCacheVerdict is the return-type companion to PageCacheInput and is
	# the one allowed export beyond the nine pinned names.
	local allowed_extra="PageCacheVerdict"
	local exports
	exports=$(grep -nE '^export ' "$file" || true)
	printf '%s\n' "$exports" >"$TMP/p3-exports.txt"
	local missing=0 name
	for name in "${pinned[@]}"; do
		local hit
		hit=$(grep -c "[[:space:]]$name\b" "$TMP/p3-exports.txt" || true)
		if [ "$hit" -eq 0 ]; then
			echo "  P3 FAIL — $file does not export $name" >&2
			missing=1
		fi
	done
	# Any export line not naming a pinned or allowed-extra identifier is drift.
	local extra=0
	while IFS= read -r line; do
		[ -z "$line" ] && continue
		local ok=0 n hit
		for n in "${pinned[@]}" "$allowed_extra"; do
			hit=$(grep -cE "[[:space:]]$n\b" <<<"$line" || true)
			if [ "$hit" -ge 1 ]; then
				ok=1
			fi
		done
		if [ "$ok" -eq 0 ]; then
			echo "  P3 FAIL — unexpected export: $line" >&2
			extra=1
		fi
	done <"$TMP/p3-exports.txt"
	if [ "$missing" -eq 0 ] && [ "$extra" -eq 0 ]; then
		return 0
	fi
	return 1
}

p4_decision_point() {
	local files=("${@:-${ROUTE_FILES[@]}}")
	local bad=0
	local f
	for f in "${files[@]}"; do
		need_file "$f" || return 2
	done
	# Exactly the two tenant routes call pageCacheVerdict( in the astro tree.
	local call_files
	call_files=$(grep -rl 'pageCacheVerdict(' --include='*.astro' one.ie/web/src/pages 2>/dev/null || true)
	local n
	n=$(grep -c '.' <<<"$call_files" || true)
	if [ "$n" -ne "${#files[@]}" ]; then
		echo "  P4 FAIL — pageCacheVerdict( is called in $n .astro file(s), want ${#files[@]}: $call_files" >&2
		bad=1
	fi
	for f in "${files[@]}"; do
		local vmatches hmatches vline hline gated
		vmatches=$(grep -n 'pageCacheVerdict(' "$f" || true)
		hmatches=$(grep -n 'Astro.response.headers.set(PAGE_CACHE_HEADER' "$f" || true)
		gated=$(grep -c 'if (cacheVerdict.cacheable) Astro.response.headers.set(PAGE_CACHE_HEADER' "$f" || true)
		vline=$(first_line_number "$vmatches")
		hline=$(first_line_number "$hmatches")
		if [ "$vline" -eq 0 ] || [ "$hline" -eq 0 ] || [ "$gated" -lt 1 ]; then
			echo "  P4 FAIL — $f: verdict-call=$vline header-set=$hline gated-form=$gated (want both present and the header set inside \`if (cacheVerdict.cacheable)\`)" >&2
			bad=1
			continue
		fi
		if [ "$hline" -le "$vline" ]; then
			echo "  P4 FAIL — $f: PAGE_CACHE_HEADER set at line $hline is not after the verdict call at line $vline" >&2
			bad=1
		fi
	done
	[ "$bad" -eq 0 ]
}

p5_uncapped() {
	local file="${1:-$INJECT_ROWS}"
	need_file "$file" || return 2
	local body
	body=$(awk '/^export function hasLiveBindings/{f=1} f{print} f && /^}/{exit}' "$file")
	if [ -z "$body" ]; then
		echo "  P5 FAIL — hasLiveBindings not found in $file" >&2
		return 1
	fi
	printf '%s\n' "$body" >"$TMP/p5-body.txt"
	local hits
	hits=$(grep -cE '\bcap\b' "$TMP/p5-body.txt" || true)
	if [ "$hits" -eq 0 ]; then
		return 0
	fi
	echo "  P5 FAIL — hasLiveBindings in $file references \`cap\` — it must stay uncapped (existence, not job-limited collection)" >&2
	return 1
}

p6_visitor_value() {
	local files=("${@:-${ROUTE_FILES[@]}}")
	local bad=0 f
	for f in "${files[@]}"; do
		need_file "$f" || return 2
		local raw leadv
		raw=$(grep -c 'visitorHash={Astro.locals.visitorHash' "$f" || true)
		leadv=$(grep -c 'visitorHash={leadVisitorHash}' "$f" || true)
		# A route with no LeadCaptureScript at all (leadv==0 AND no
		# LeadCaptureScript tag) is not a violation — only a route that both
		# renders the script AND still passes the raw session value is.
		local has_script
		has_script=$(grep -c '<LeadCaptureScript' "$f" || true)
		if [ "$raw" -gt 0 ]; then
			echo "  P6 FAIL — $f passes Astro.locals.visitorHash directly into a component; must go through the verdict-gated variable" >&2
			bad=1
		elif [ "$has_script" -gt 0 ] && [ "$leadv" -eq 0 ]; then
			echo "  P6 FAIL — $f renders LeadCaptureScript without the gated leadVisitorHash variable" >&2
			bad=1
		fi
	done
	[ "$bad" -eq 0 ]
}

run_parity() {
	local bad=0
	echo "speed-parity-check --parity"
	if p1_altitude; then echo "  ok   P1 altitude — readPageCache sits strictly between the isPrimary exit and readDomainRowMemo"; else bad=1; fi
	if p2_sequence; then echo "  ok   P2 sequence — pageCacheStore wired after perfStart, before mainMiddleware"; else bad=1; fi
	if p3_exports; then echo "  ok   P3 exports — lib/page-cache.ts exports exactly the frozen surface"; else bad=1; fi
	if p4_decision_point; then echo "  ok   P4 single decision point — pageCacheVerdict is the one gate on both tenant routes"; else bad=1; fi
	if p5_uncapped; then echo "  ok   P5 uncapped — hasLiveBindings carries no job cap"; else bad=1; fi
	if p6_visitor_value; then echo "  ok   P6 visitor value — no route hands a raw per-visitor hash to a cacheable component"; else bad=1; fi
	if [ "$bad" -eq 0 ]; then
		echo "[speed-parity-check --parity] ok — all six structural facts hold"
		return 0
	fi
	echo "[speed-parity-check --parity] FAIL" >&2
	return 1
}

# ---------------------------------------------------------------------------
# --freshness : F1/F2
# ---------------------------------------------------------------------------

# A write SITE is one DB.prepare(...).bind(...).run() call (or an if/else
# group of them, per spec 12's "ONE call after the if/else, never one per
# branch") — never a raw string-literal count. A ternary of two SQL literals
# for the same statement, or a 3-way if/elseif/else each with its own
# UPDATE/.run(), is ONE site: matches within 5 lines of each other cluster
# together, anchored at the cluster's LAST `.run()`. From there the rule is
# 6 SIGNIFICANT lines (non-blank, non-comment) — not 6 raw file lines, or a
# W2-authored explanatory comment between the `.run()` and the `touchPage(`
# call (exactly the shape at api/pages/[slug].ts:130-138) would itself burn
# the budget and make the pinned rule self-defeating. Comment-only lines
# (`//`, `*`, `/*`) never count as a write-site match either — pages.ts:32's
# own docblock quotes `UPDATE pages SET` / `INSERT INTO pages` in backticks
# and must not be read as a 19th writer.
f1_scan_file() {
	local f="$1"
	awk '
	function is_comment(s,   t) {
		t = s
		sub(/^[ \t]*/, "", t)
		return (t ~ /^\/\// || t ~ /^\*/ || t ~ /^\/\*/)
	}
	{
		lines[NR] = $0
		if (!is_comment($0) && ($0 ~ /UPDATE pages SET/ || $0 ~ /INSERT INTO pages/)) {
			if (NR - last_match > 10) {
				nclusters++
				cstart[nclusters] = NR
			}
			cend[nclusters] = NR
			last_match = NR
		}
	}
	END {
		total_lines = NR
		for (c = 1; c <= nclusters; c++) {
			anchor = 0
			for (i = cend[c]; i <= cend[c] + 10 && i <= total_lines; i++) {
				if (lines[i] ~ /\.run\(\)/) { anchor = i; break }
			}
			if (anchor == 0) anchor = cend[c]
			found = 0
			sig = 0
			for (i = anchor + 1; i <= total_lines && sig < 6; i++) {
				t2 = lines[i]
				trimmed = t2
				sub(/^[ \t]*/, "", trimmed)
				if (trimmed == "") continue
				if (is_comment(t2)) continue
				sig++
				if (t2 ~ /touchPage\(/) { found = 1; break }
			}
			total_sites++
			if (!found) {
				print "ORPHAN\t" anchor
				orphan_count++
			}
		}
		print "TOTAL\t" total_sites + 0
		print "ORPHANS\t" orphan_count + 0
	}
	' "$f"
}

f1_write_sites() {
	local files=("${@:-${WRITER_FILES[@]}}")
	local total=0 orphans=0 f
	for f in "${files[@]}"; do
		need_file "$f" || return 2
	done
	for f in "${files[@]}"; do
		local out
		out=$(f1_scan_file "$f")
		printf '%s\n' "$out" >"$TMP/f1-scan.txt"
		local file_total file_orphans
		file_total=$(awk -F'\t' '$1=="TOTAL"{print $2}' "$TMP/f1-scan.txt")
		file_orphans=$(awk -F'\t' '$1=="ORPHANS"{print $2}' "$TMP/f1-scan.txt")
		file_total=${file_total:-0}
		file_orphans=${file_orphans:-0}
		total=$((total + file_total))
		orphans=$((orphans + file_orphans))
		while IFS=$'\t' read -r tag lineno; do
			[ "$tag" = "ORPHAN" ] || continue
			echo "  F1 orphan — $f: no touchPage( within 6 significant lines after the .run() at line $lineno" >&2
		done <"$TMP/f1-scan.txt"
	done
	echo "  F1 write-sites=$total touchPage-covered=$((total - orphans)) orphans=$orphans"
	[ "$orphans" -eq 0 ]
}

f2_no_broadcast() {
	local hits
	hits=$(grep -rn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=.astro --exclude-dir=.wrangler --include='*.ts' --include='*.astro' 'broadcastPageUpdated' one.ie 2>/dev/null || true)
	printf '%s\n' "$hits" >"$TMP/f2-hits.txt"
	local n
	n=$(grep -c '.' "$TMP/f2-hits.txt" || true)
	if [ "$n" -eq 0 ]; then
		return 0
	fi
	echo "  F2 FAIL — broadcastPageUpdated survives at $n site(s):" >&2
	cat "$TMP/f2-hits.txt" >&2
	return 1
}

run_freshness() {
	local bad=0
	echo "speed-parity-check --freshness"
	if f1_write_sites; then echo "  ok   F1 — every UPDATE pages SET / INSERT INTO pages site is followed by touchPage( within 6 lines"; else bad=1; fi
	if f2_no_broadcast; then echo "  ok   F2 — broadcastPageUpdated has zero occurrences repo-wide (touchPage is the one choke point)"; else bad=1; fi
	if [ "$bad" -eq 0 ]; then
		echo "[speed-parity-check --freshness] ok"
		return 0
	fi
	echo "[speed-parity-check --freshness] FAIL" >&2
	return 1
}

# ---------------------------------------------------------------------------
# --check-gate : G1-G6
# ---------------------------------------------------------------------------

PAGE_CACHE_ABS="$ROOT/$PAGE_CACHE_TS"

write_probe() {
	cat >"$TMP/probe.mjs" <<PROBEEOF
import { pageCacheVerdict } from '${PAGE_CACHE_ABS}'
const input = JSON.parse(process.argv[2])
process.stdout.write(JSON.stringify(pageCacheVerdict(input)))
PROBEEOF
}

assert_reason() {
	local name="$1" json="$2" want="$3"
	local out
	if ! out=$(bun "$TMP/probe.mjs" "$json" 2>&1); then
		echo "  FAIL $name — probe threw: $out" >&2
		return 1
	fi
	printf '%s' "$out" >"$TMP/last-probe.json"
	local got
	got=$(grep -c "\"reason\":\"$want\"" "$TMP/last-probe.json" || true)
	if [ "$got" -ge 1 ]; then
		echo "  ok   $name -> reason=$want"
		return 0
	fi
	echo "  FAIL $name — want reason=$want, got: $out" >&2
	return 1
}

write_key_probe() {
	local module="$1" out="$2"
	cat >"$out" <<KEYEOF
import { pageCacheKey } from '${module}'
console.log(pageCacheKey(process.argv[2], process.argv[3]))
KEYEOF
}

plant_key_confusion() {
	# G3 — a $TMP key builder that drops the host. Never touches the tracked
	# file; writes only into $TMP.
	cat >"$TMP/plant-key.mjs" <<'JSEOF'
import { readFileSync, writeFileSync } from 'node:fs'
const src = readFileSync(process.argv[2], 'utf8')
const needle = 'return `${PAGE_CACHE_ORIGIN}/${encodeURIComponent(host)}${pathname}`;'
const replacement = 'return `${PAGE_CACHE_ORIGIN}${pathname}`;'
if (!src.includes(needle)) {
	console.error('PLANT_FAILED_NO_MATCH')
	process.exit(1)
}
writeFileSync(process.argv[3], src.replace(needle, replacement))
JSEOF
	bun "$TMP/plant-key.mjs" "$PAGE_CACHE_ABS" "$TMP/page-cache-red.ts"
}

plant_capped_bindings() {
	# G4b — a $TMP copy of inject-rows.ts whose hasLiveBindings caps at 5.
	cat >"$TMP/plant-cap.mjs" <<'JSEOF'
import { readFileSync, writeFileSync } from 'node:fs'
const src = readFileSync(process.argv[2], 'utf8')
const needle = 'export function hasLiveBindings(data: Data): boolean {'
if (!src.includes(needle)) {
	console.error('PLANT_FAILED_NO_MATCH')
	process.exit(1)
}
const replacement = needle + '\n\tconst cap = 5 // PLANTED — proves P5 catches a job cap creeping in\n'
writeFileSync(process.argv[3], src.replace(needle, replacement))
JSEOF
	bun "$TMP/plant-cap.mjs" "$ROOT/$INJECT_ROWS" "$TMP/inject-rows-red.ts"
}

plant_altitude() {
	# G6 — a $TMP copy of middleware.ts with the read probe moved BELOW
	# readDomainRowMemo. Text-only mutation; the plant never needs to compile,
	# it only needs to reproduce the byte order p1_altitude scans for.
	cat >"$TMP/plant-altitude.mjs" <<'JSEOF'
import { readFileSync, writeFileSync } from 'node:fs'
const src = readFileSync(process.argv[2], 'utf8')
const lines = src.split('\n')
const startIdx = lines.findIndex((l) => l.includes('C10 PARITY PROBE'))
if (startIdx === -1) {
	console.error('PLANT_FAILED_NO_START')
	process.exit(1)
}
const anchorIdx = lines.findIndex((l) => l.includes('An explicit verified'))
if (anchorIdx === -1) {
	console.error('PLANT_FAILED_NO_ANCHOR')
	process.exit(1)
}
let cut = anchorIdx - 1
while (cut > startIdx && lines[cut].trim() === '') cut--
const endIdx = cut
const block = lines.slice(startIdx, endIdx + 1)
const rest = lines.slice(0, startIdx).concat(lines.slice(endIdx + 1))
const domainIdx = rest.findIndex((l) => l.includes('readDomainRowMemo('))
if (domainIdx === -1) {
	console.error('PLANT_FAILED_NO_DOMAIN')
	process.exit(1)
}
const out = rest.slice(0, domainIdx + 1).concat(['']).concat(block).concat(rest.slice(domainIdx + 1))
writeFileSync(process.argv[3], out.join('\n'))
JSEOF
	bun "$TMP/plant-altitude.mjs" "$ROOT/$MIDDLEWARE_TS" "$TMP/middleware-red.ts"
}

run_check_gate() {
	need_bun || return 2
	need_file "$PAGE_CACHE_TS" || return 2
	need_file "$INJECT_ROWS" || return 2
	need_file "$MIDDLEWARE_TS" || return 2

	echo "speed-parity-check --check-gate — proving each of the six safety-rule plants goes RED"
	echo
	local bad=0

	write_probe

	# G1 draft
	if assert_reason "G1 draft" '{"status":"draft","hasSession":false,"hasLiveBindings":false,"hasExperiment":false,"canEdit":false,"visitorHash":""}' "draft"; then :; else bad=1; fi

	# G2 session
	if assert_reason "G2 session" '{"status":"published","hasSession":true,"hasLiveBindings":false,"hasExperiment":false,"canEdit":false,"visitorHash":""}' "session"; then :; else bad=1; fi

	# G4a live bindings
	if assert_reason "G4a bindings" '{"status":"published","hasSession":false,"hasLiveBindings":true,"hasExperiment":false,"canEdit":false,"visitorHash":""}' "bindings"; then :; else bad=1; fi

	# G5 visitor value
	if assert_reason "G5 visitor-value" '{"status":"published","hasSession":false,"hasLiveBindings":false,"hasExperiment":false,"canEdit":false,"visitorHash":"abc123"}' "visitor-value"; then :; else bad=1; fi

	# G — experiment (sixth named reason; IC row 3 lists all six in order)
	if assert_reason "G experiment" '{"status":"published","hasSession":false,"hasLiveBindings":false,"hasExperiment":true,"canEdit":false,"visitorHash":""}' "experiment"; then :; else bad=1; fi

	# G — can-edit
	if assert_reason "G can-edit" '{"status":"published","hasSession":false,"hasLiveBindings":false,"hasExperiment":false,"canEdit":true,"visitorHash":""}' "can-edit"; then :; else bad=1; fi

	# Sanity: the all-clear input is cacheable — proves the five guards above
	# are not vacuously true (e.g. always returning cacheable:false).
	if assert_reason "sanity all-clear" '{"status":"published","hasSession":false,"hasLiveBindings":false,"hasExperiment":false,"canEdit":false,"visitorHash":""}' "ok"; then :; else bad=1; fi

	# G3 — host confusion. Real module: two hosts, same pathname, different keys.
	write_key_probe "$PAGE_CACHE_ABS" "$TMP/key-real.mjs"
	local ka kb
	ka=$(bun "$TMP/key-real.mjs" 'a.com' '/p/x' 2>&1) || { echo "  FAIL G3 real probe threw: $ka" >&2; bad=1; }
	kb=$(bun "$TMP/key-real.mjs" 'b.com' '/p/x' 2>&1) || { echo "  FAIL G3 real probe threw: $kb" >&2; bad=1; }
	if [ -n "$ka" ] && [ -n "$kb" ] && [ "$ka" != "$kb" ]; then
		echo "  ok   G3a real pageCacheKey — a.com and b.com produce different keys"
	else
		echo "  FAIL G3a real pageCacheKey did not distinguish hosts: '$ka' vs '$kb'" >&2
		bad=1
	fi
	# ...then plant a key builder that drops the host and prove the SAME
	# assertion goes red against the plant.
	if plant_key_confusion; then
		write_key_probe "$TMP/page-cache-red.ts" "$TMP/key-red.mjs"
		local rka rkb
		rka=$(bun "$TMP/key-red.mjs" 'a.com' '/p/x' 2>&1) || rka=""
		rkb=$(bun "$TMP/key-red.mjs" 'b.com' '/p/x' 2>&1) || rkb=""
		if [ -n "$rka" ] && [ "$rka" = "$rkb" ]; then
			echo "  ok   G3b planted host-dropping key builder is flagged RED (a.com and b.com collide)"
		else
			echo "  FAIL G3b planted key builder was NOT flagged red — got '$rka' vs '$rkb' (want them equal, proving the bug is caught)" >&2
			bad=1
		fi
	else
		echo "  FAIL G3b could not plant the key-confusion fixture" >&2
		bad=1
	fi

	# G4b — capped hasLiveBindings must flag P5 red.
	if p5_uncapped "$INJECT_ROWS" >/dev/null 2>&1; then
		echo "  ok   G4b(real) working tree's hasLiveBindings is GREEN (uncapped)"
	else
		echo "  FAIL G4b(real) working tree's hasLiveBindings did NOT pass P5" >&2
		bad=1
	fi
	if plant_capped_bindings; then
		if p5_uncapped "$TMP/inject-rows-red.ts" >/dev/null 2>&1; then
			echo "  FAIL G4b planted capped hasLiveBindings was NOT flagged (got pass, want fail)" >&2
			bad=1
		else
			echo "  ok   G4b planted capped hasLiveBindings is flagged RED by P5"
		fi
	else
		echo "  FAIL G4b could not plant the capped-bindings fixture" >&2
		bad=1
	fi

	# G6 — altitude. Working tree must be GREEN; the plant (probe moved below
	# readDomainRowMemo) must be RED.
	if p1_altitude "$MIDDLEWARE_TS" >/dev/null 2>&1; then
		echo "  ok   G6(real) working tree's middleware.ts passes P1 altitude"
	else
		echo "  FAIL G6(real) working tree's middleware.ts did NOT pass P1 altitude" >&2
		bad=1
	fi
	if plant_altitude; then
		if p1_altitude "$TMP/middleware-red.ts" >/dev/null 2>&1; then
			echo "  FAIL G6 planted altitude violation was NOT flagged (got pass, want fail)" >&2
			bad=1
		else
			echo "  ok   G6 planted altitude violation (probe moved below readDomainRowMemo) is flagged RED by P1 — this is the plant that guards the deliverable itself"
		fi
	else
		echo "  FAIL G6 could not plant the altitude fixture" >&2
		bad=1
	fi

	echo
	if [ "$bad" -eq 0 ]; then
		echo "check-gate proven: all six planted violations are flagged RED, and the working tree stays GREEN where it should"
		return 0
	fi
	echo "$bad self-test group(s) FAILED — the parity gate is not trustworthy" >&2
	return 1
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------

MODE=""
for arg in "$@"; do
	case "$arg" in
	--parity) MODE="parity" ;;
	--freshness) MODE="freshness" ;;
	--check-gate) MODE="check-gate" ;;
	*)
		echo "[speed-parity-check] unknown flag: $arg" >&2
		exit 2
		;;
	esac
done

case "$MODE" in
parity) run_parity; exit $? ;;
freshness) run_freshness; exit $? ;;
check-gate) run_check_gate; exit $? ;;
*)
	echo "usage: speed-parity-check.sh --parity|--freshness|--check-gate" >&2
	exit 2
	;;
esac
