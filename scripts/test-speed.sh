#!/usr/bin/env bash
# test-speed.sh — the ms ledger for the test suite.
#
# WHY: "the suite is slow" is not actionable; "two files are 93% of the slice"
# is. This runs vitest with the JSON reporter, aggregates per-FILE milliseconds,
# and writes a ranked ledger so the next cycle has a target instead of a mood.
#
# It measures, it never gates. Exit status mirrors vitest's so a red suite still
# reads as red, but nothing here fails a build for being slow.
#
#   bash .claude/scripts/test-speed.sh                  # whole suite
#   bash .claude/scripts/test-speed.sh tests/unit        # a subtree
#   bash .claude/scripts/test-speed.sh --report-only     # re-rank the last run
#
# Output: one.ie/web/tests/.speed-ledger.json  (committed — a prerendered page
# can read it at build time; it cannot query live timings).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB="$ROOT/one.ie/web"
LEDGER="$WEB/tests/.speed-ledger.json"
RAW="${TEST_SPEED_RAW:-$WEB/tests/.speed-raw.json}"

report_only=0
args=()
for a in "$@"; do
  case "$a" in
    --report-only) report_only=1 ;;
    *) args+=("$a") ;;
  esac
done

st=0
if [ "$report_only" -eq 0 ]; then
  cd "$WEB" || exit 1
  # The governor owns concurrency; a raw vitest here would bypass it and trip
  # hook:load-guard. Same gate label the other lanes use.
  bash "$ROOT/.claude/scripts/gate-run.sh" test-speed -- \
    npx vitest run --reporter=json --outputFile="$RAW" "${args[@]+"${args[@]}"}"
  st=$?
fi

[ -f "$RAW" ] || { echo "[test-speed] no run data at $RAW" >&2; exit 1; }

LEDGER="$LEDGER" RAW="$RAW" python3 <<'PY'
import json, os, collections, datetime

raw, ledger = os.environ['RAW'], os.environ['LEDGER']
d = json.load(open(raw))

files = collections.Counter()
counts = collections.Counter()
for t in d.get('testResults', []):
    name = t['name'].split('one.ie/web/')[-1]
    # assertionResults carry per-TEST ms. A file's wall time also includes
    # import+transform, which the JSON reporter does not attribute per file --
    # so this is the FLOOR of a file's cost, never an overstatement.
    files[name] += sum(a.get('duration') or 0 for a in t.get('assertionResults', []))
    counts[name] += len(t.get('assertionResults', []))

total = sum(files.values())
rows = [
    {'file': f, 'ms': round(ms), 'tests': counts[f],
     'share': round(ms / total, 4) if total else 0.0}
    for f, ms in files.most_common()
]

# The headline: how few files hold the suite hostage.
cum, p80 = 0.0, 0
for r in rows:
    cum += r['ms']
    p80 += 1
    if total and cum >= 0.8 * total:
        break

out = {
    'generated': datetime.datetime.now(datetime.timezone.utc)
                 .strftime('%Y-%m-%dT%H:%M:%SZ'),
    'files': len(rows),
    'tests': sum(counts.values()),
    'total_ms': round(total),
    'files_for_80pct': p80,
    'slowest': rows[:50],
}
json.dump(out, open(ledger, 'w'), indent=2)

print(f"\n[test-speed] {out['files']} files · {out['tests']} tests · {out['total_ms']}ms in test bodies")
print(f"[test-speed] {p80} file(s) carry 80% of it\n")
for r in rows[:15]:
    print(f"  {r['ms']:>8}ms  {r['share']*100:5.1f}%  {r['tests']:>4}t  {r['file']}")
print(f"\n[test-speed] ledger -> {ledger}")
PY

exit $st
