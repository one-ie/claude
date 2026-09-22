#!/usr/bin/env bash
# lighthouse-run.sh — capture-and-print ONE Lighthouse run. No thresholds.
#
# WHY IT EXISTS: the two pre-existing runners (one.ie/web/scripts/
# lighthouse-{dashboard,in}.sh) each hardcode their own pass/fail numbers.
# That made the thresholds live in two places and neither could be ratcheted.
# This script does capture only; `speed-check.mjs` owns every comparison.
# One source of truth for "what is the number", one for "is it good enough".
#
# USAGE
#   lighthouse-run.sh <url> [desktop|mobile]
#
# PRINTS (one line, stdout, parseable):
#   perf=<0-100> a11y=<0-100> bp=<0-100> seo=<0-100>
#   fcp=<ms> lcp=<ms> tbt=<ms> cls=<0.000> si=<ms> tti=<ms> bytes=<n>
#
# EXIT  0 captured · 2 INCONCLUSIVE (no lighthouse, no chrome, url dead,
#       unparseable report). NEVER 1 — this script has no opinion on the
#       numbers, so it can never "fail". An unrun check is not a green check.
set -uo pipefail

URL="${1:?usage: lighthouse-run.sh <url> [desktop|mobile]}"
MODE="${2:-desktop}"
OUT="${LIGHTHOUSE_OUT:-$(mktemp -t lhrun)}"
LH_ERR="$(mktemp -t lherr)"
# Clean up BOTH temp files on every exit path. ~40 runs a session otherwise
# leaves ~80 stray files in $TMPDIR.
trap 'rm -f "$OUT" "$LH_ERR"' EXIT
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

inconclusive() { echo "INCONCLUSIVE: $*" >&2; exit 2; }

# --- locate lighthouse ------------------------------------------------------
LH=""
for cand in \
  "$REPO/one.ie/web/node_modules/.bin/lighthouse" \
  "$REPO/node_modules/.bin/lighthouse" \
  "$(command -v lighthouse 2>/dev/null || true)"; do
  [ -n "$cand" ] && [ -x "$cand" ] && { LH="$cand"; break; }
done
[ -n "$LH" ] || inconclusive "lighthouse not installed (bun add -D lighthouse in one.ie/web)"

# --- locate chrome ----------------------------------------------------------
# Lighthouse needs full Chrome, not chrome-headless-shell: several audits
# (and the whole a11y category) depend on APIs the shell build omits.
if [ -z "${CHROME_PATH:-}" ]; then
  for cand in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "$(command -v google-chrome 2>/dev/null || true)" \
    "$(command -v chromium 2>/dev/null || true)"; do
    [ -n "$cand" ] && [ -x "$cand" ] && { export CHROME_PATH="$cand"; break; }
  done
fi
[ -n "${CHROME_PATH:-}" ] || inconclusive "no Chrome found (set CHROME_PATH)"

# --- url must actually answer before we spend 30s on Chrome -----------------
# NOTE: curl's -w prints "000" on connection failure AND exits non-zero, so a
# `|| echo 000` fallback concatenates to "000000" and silently misses the
# guard. Test curl's exit status separately instead.
# Fetch the body ONCE here and reuse it for the asset guard below — a second
# full download per sample would add latency to every measurement.
BODY_FILE="$(mktemp -t lhbody)"; trap 'rm -f "$OUT" "$LH_ERR" "$BODY_FILE"' EXIT
if code="$(curl -s -o "$BODY_FILE" -w '%{http_code}' --max-time 10 -L "$URL" 2>/dev/null)"; then
  case "$code" in
    000|"") inconclusive "$URL unreachable (no server listening?)" ;;
    5*)     inconclusive "$URL returned $code — measuring an error page is not a measurement" ;;
  esac
else
  inconclusive "$URL unreachable (curl failed; no server listening?)"
fi

# --- assets must resolve, or we measure a blank page ----------------------
# A served-200 document whose stylesheets 404 paints NOTHING: Lighthouse
# returns runtimeError NO_FCP, or (worse) a partial load that scores 100.
# Measured 2026-08-18: a concurrent `bun run build` replaced dist/ under a
# running `wrangler dev`, so the HTML referenced new content hashes the
# server could no longer serve — every /_astro/*.css returned 404 while `/`
# still returned 200 in 19ms. Checking the document alone cannot see this.
if [ "${SPEED_SKIP_ASSET_CHECK:-0}" != "1" ]; then
  first_asset="$(grep -oE '/_astro/[^"]+\.(css|js)' "$BODY_FILE" 2>/dev/null | head -1 || true)"
  if [ -n "$first_asset" ]; then
    base="$(printf '%s' "$URL" | sed -E 's#^(https?://[^/]+).*#\1#')"
    acode="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${base}${first_asset}" 2>/dev/null || echo 000)"
    case "$acode" in
      2*) : ;;
      *)  inconclusive "assets 404 (${first_asset} -> ${acode}) — the page cannot paint. Stale build? Rebuild and restart the server." ;;
    esac
  fi
fi

# --- run --------------------------------------------------------------------
# THROTTLING: default is `simulate` (Lighthouse's own default), NOT `provided`.
# This matters more than anything else in this file. `provided` scores whatever
# the real network happened to do, so the same unchanged page measured minutes
# apart scored perf 95 then 63, LCP 1486ms then 4340ms (measured 2026-08-18) —
# noise that large makes a ratchet worthless and is why nobody trusted the old
# numbers. `simulate` loads once then applies a fixed synthetic connection, so
# scores are stable and comparable across machines and runs.
# Override with SPEED_THROTTLING=provided for a raw real-network reading.
# FORM FACTOR: use --preset=desktop, NOT --form-factor=desktop. Lighthouse's
# default screen emulation is mobile, and setting form-factor alone leaves the
# two inconsistent -> hard runtime error ("Screen emulation mobile setting
# (true) does not match formFactor setting (desktop)"). The preset sets
# form-factor, screen emulation and throttling together. Mobile needs no
# preset; it is already the default config.
# NOTE: macOS ships bash 3.2, where expanding an EMPTY array under `set -u`
# ("${PRESET[@]}") is an "unbound variable" error. Use a plain string + word
# splitting instead of an array — the value is a single fixed flag, so there is
# nothing to quote-protect.
PRESET=""
[ "$MODE" = "desktop" ] && PRESET="--preset=desktop"

"$LH" "$URL" \
  --output=json \
  --output-path="$OUT" \
  --chrome-flags="--headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage" \
  --quiet \
  --only-categories=performance,accessibility,best-practices,seo \
  ${PRESET} \
  --throttling-method="${SPEED_THROTTLING:-simulate}" >/dev/null 2>"$LH_ERR" || true

# Surface the real reason. Swallowing stderr here turned a config error into a
# bare "produced no report", which cost a debugging cycle.
if [ ! -s "$OUT" ]; then
  inconclusive "lighthouse produced no report for $URL: $(head -2 "$LH_ERR" | tr '\n' ' ')"
fi

node -e '
const fs = require("fs");
let j;
try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch { process.exit(3); }
if (j.runtimeError) { console.error("runtimeError: " + j.runtimeError.code); process.exit(3); }
const cat = (k) => {
  const c = j.categories && j.categories[k];
  return c && typeof c.score === "number" ? Math.round(c.score * 100) : -1;
};
const num = (k) => {
  const a = j.audits && j.audits[k];
  return a && typeof a.numericValue === "number" ? Math.round(a.numericValue) : -1;
};
const cls = (() => {
  const a = j.audits && j.audits["cumulative-layout-shift"];
  return a && typeof a.numericValue === "number" ? a.numericValue.toFixed(3) : "-1";
})();
const bytes = num("total-byte-weight");
const perf = cat("performance");
if (perf < 0) { console.error("no performance score in report"); process.exit(3); }

// PARTIAL-LOAD GUARD. A page that only half-loaded scores BRILLIANTLY: fewer
// bytes, earlier LCP, no long tasks. Measured 2026-08-18 under box contention:
// /chat reported perf=100 lcp=275ms bytes=13043 while the server was serving a
// healthy 49KB document with ~400KB of subresources. That reading would have
// been written into the baseline as a record to defend forever.
// Any real route here is >= 100KB, so a tiny total is a failed load, not a fast
// page. Tune with SPEED_MIN_BYTES for a genuinely minimal route.
const MIN_BYTES = Number(process.env.SPEED_MIN_BYTES || 100000);
if (bytes >= 0 && bytes < MIN_BYTES) {
  console.error(`partial load: total-byte-weight ${bytes} < ${MIN_BYTES} — not a measurement`);
  process.exit(3);
}
// Failed requests: judge the MAIN DOCUMENT strictly and the rest by
// proportion. Real pages routinely 404 a favicon or lose an analytics beacon;
// that is not a failed measurement. A dead document, or most of the page
// missing, is.
const reqs = (j.audits && j.audits["network-requests"] && j.audits["network-requests"].details
  && j.audits["network-requests"].details.items) || [];
if (reqs.length) {
  const doc = reqs.find((r) => r.resourceType === "Document");
  if (doc && doc.statusCode >= 400) {
    console.error(`main document returned ${doc.statusCode} — not a measurement`);
    process.exit(3);
  }
  const failed = reqs.filter((r) => r.statusCode >= 400).length;
  if (failed / reqs.length > 0.5) {
    console.error(`partial load: ${failed}/${reqs.length} requests failed`);
    process.exit(3);
  }
}
console.log(
  `perf=${perf} a11y=${cat("accessibility")} bp=${cat("best-practices")} seo=${cat("seo")} ` +
  `fcp=${num("first-contentful-paint")} lcp=${num("largest-contentful-paint")} ` +
  `tbt=${num("total-blocking-time")} cls=${cls} si=${num("speed-index")} ` +
  `tti=${num("interactive")} bytes=${bytes}`
);
' "$OUT" 2>"$LH_ERR" || inconclusive "$(head -2 "$LH_ERR" | tr '\n' ' ')" 
