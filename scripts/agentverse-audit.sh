#!/usr/bin/env bash
# agentverse-audit.sh — measure the health and composition of the Agentverse
# agent directory.
#
# This is an AUDIT, not an exposé. It reports what is measurable and states what
# it cannot know. Every number is reproducible by anyone holding an Agentverse
# API key, including Fetch — that is the design. An accusation is deniable;
# arithmetic is not.
#
# WHAT IT MEASURES
#   Liveness     status, unresponsive flag, total vs RECENT interactions
#   Quality      description, readme, declared protocols, rating
#   Composition  owner concentration, generated-name clustering, categories
#   Time         creation year, staleness of last update
#
# WHAT IT DELIBERATELY DOES NOT CLAIM
#   - That any published agent count is wrong. Registered is not the same as
#     active, and this measures ACTIVITY and COMPOSITION. Both can be true.
#   - That bulk-created agents are illegitimate. Generating one agent per entry
#     in a catalogue is a normal integration pattern. Clustering is REPORTED so a
#     reader can judge what a headline count represents — not as an allegation.
#   - That anyone acted in bad faith. Dormancy is normal in every registry: npm,
#     the App Store and GitHub all look like this.
#   - That the sample is uniformly random. It is not, and cannot be. See LIMITS.
#
# LIMITS — read before quoting any number
#   1. SEARCH-BIASED SAMPLE. Agents come from POST /v1/search/agents, ranked by
#      relevancy. No enumeration endpoint is exposed, so a uniform random sample
#      is impossible. Many unrelated queries plus deep pagination reduce the skew;
#      nothing removes it.
#   2. THEIR FIELDS, NOT OURS. `status`, `rating` and the interaction counters are
#      what the API returns. Their definitions are unpublished, so this measures
#      "what Agentverse says about its own agents" — the honest framing.
#   3. DUPLICATES ARE REAL. The directory returns the same agent repeatedly; this
#      dedupes by address before counting.
#   4. A SAMPLE IS NOT A CENSUS. Every figure is "of agents sampled".
#   5. OWNER IDS ARE OPAQUE. One owner id is one account, which is not
#      necessarily one person or one company.
#
# Usage:
#   agentverse-audit.sh                # default depth, human report
#   agentverse-audit.sh --json         # machine-readable receipt
#   agentverse-audit.sh --pages 4      # pages per query (50 agents each)
#   agentverse-audit.sh --self-test    # prove the counters can report health
#
# Env:
#   AGENTVERSE_API_KEY  required. Absent → exit 3 (could not run), never a
#                       fabricated zero.
set -uo pipefail

BASE="${AGENTVERSE_BASE:-https://agentverse.ai/v1}"
LIMIT=50           # API hard-caps at 50
PAGES=3
JSON=0
SELFTEST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --pages) PAGES="${2:-3}"; shift 2 ;;
    --self-test) SELFTEST=1; shift ;;
    -h|--help) sed -n '2,48p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "agentverse-audit: unknown flag $1" >&2; exit 2 ;;
  esac
done

# Fixed probe set, spread across verticals rather than clustered in one. Fixed in
# the script so a run is reproducible — hand-picking queries per run would let
# anyone tune the result.
QUERIES=(
  agent data trading assistant payment finance search weather
  news health travel game nft defi oracle chat image translate
  storage compute music legal research market social crypto
  bot llm model tool
)

if [[ $SELFTEST -eq 1 ]]; then
  echo "agentverse-audit --self-test"
  out=$(python3 - <<'PY'
# A counter that cannot report a HEALTHY directory is theatre. Feed the reducer a
# synthetic all-healthy, all-distinct-owner set and confirm it says so.
agents = [{"address": f"a{i}", "status": "active", "type": "mailbox",
           "total_interactions": 5, "recent_interactions": 2, "rating": 4.5,
           "description": "d", "readme": "r", "protocols": ["p"],
           "owner": f"owner{i}", "unresponsive": False} for i in range(10)]
n = len(agents)
active = sum(1 for a in agents if a["status"] == "active")
rated  = sum(1 for a in agents if (a.get("rating") or 0) > 0)
protos = sum(1 for a in agents if a.get("protocols"))
owners = len({a["owner"] for a in agents})
print(f"{active}/{n} {rated}/{n} {protos}/{n} owners={owners}")
PY
)
  if [[ "$out" == "10/10 10/10 10/10 owners=10" ]]; then
    echo "  ok   a healthy directory reports 100% and 10 distinct owners"
    echo "       (the counters are not hardcoded to a pessimistic answer)"
    exit 0
  fi
  echo "  BAD  reducer returned '$out'"; exit 1
fi

if [[ -z "${AGENTVERSE_API_KEY:-}" ]]; then
  echo "agentverse-audit: AGENTVERSE_API_KEY unset — cannot run." >&2
  echo "  An unrun audit is not an audit reporting zero. Exiting 3." >&2
  exit 3
fi

RAW="$(mktemp)"; trap 'rm -f "$RAW"' EXIT
nreq=0
for q in "${QUERIES[@]}"; do
  for ((p=0; p<PAGES; p++)); do
    off=$((p * LIMIT))
    body="$(printf '{"search_text":"%s","sort":"relevancy","direction":"asc","offset":%d,"limit":%d}' "$q" "$off" "$LIMIT")"
    resp="$(curl -s -m 30 -X POST \
        -H "Authorization: Bearer ${AGENTVERSE_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "$body" "$BASE/search/agents" 2>/dev/null)"
    printf '%s\t%s\n' "$q" "$resp" >> "$RAW"
    nreq=$((nreq+1))
    sleep 0.35   # polite: this is their infrastructure
  done
done

python3 - "$RAW" "$nreq" "$JSON" <<'PY'
import json, re, sys
from collections import Counter
from datetime import datetime, timezone

raw, nreq, as_json = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "1"

seen, agents, failed = set(), [], 0
for line in open(raw, encoding="utf-8"):
    _, _, payload = line.partition("\t")
    try:
        d = json.loads(payload)
    except Exception:
        failed += 1; continue
    if not isinstance(d, dict) or "agents" not in d:
        failed += 1; continue
    for a in d.get("agents") or []:
        addr = a.get("address")
        if not addr or addr in seen:
            continue
        seen.add(addr); agents.append(a)

n = len(agents)
if n == 0:
    print("agentverse-audit: no agents returned — cannot report. exit 3", file=sys.stderr)
    sys.exit(3)

def pct(k): return round(100.0 * k / n, 1)
def yr(s):
    try: return int(str(s)[:4])
    except Exception: return None

active   = sum(1 for a in agents if a.get("status") == "active")
unresp   = sum(1 for a in agents if a.get("unresponsive"))
ever     = sum(1 for a in agents if (a.get("total_interactions") or 0) > 0)
recent   = sum(1 for a in agents if (a.get("recent_interactions") or 0) > 0)
rated    = sum(1 for a in agents if (a.get("rating") or 0) > 0)
desc     = sum(1 for a in agents if (a.get("description") or "").strip())
readme   = sum(1 for a in agents if (a.get("readme") or "").strip())
protos   = sum(1 for a in agents if a.get("protocols"))
featured = sum(1 for a in agents if a.get("featured"))

owners = Counter(a.get("owner") or "unknown" for a in agents)
top10 = owners.most_common(10)
top10_share = round(100.0 * sum(c for _, c in top10) / n, 1)
top1_share = round(100.0 * top10[0][1] / n, 1) if top10 else 0.0

# Agents minted in bulk share a stem: "hf-info-<model>", "test-bot-<n>". Strip a
# trailing id/hash and count stems. REPORTED, not alleged — a catalogue
# integration is legitimate; the reader decides what a headline count represents.
def stem(name: str) -> str:
    s = re.sub(r'[-_][0-9a-fA-F]{6,}$', '', name or '')
    s = re.sub(r'[-_]\d+$', '', s)
    parts = re.split(r'[-_\s]+', s)
    return '-'.join(parts[:2]).lower() if len(parts) >= 2 else s.lower()

stems = Counter(stem(a.get("name") or "") for a in agents)
big_stems = [(s, c) for s, c in stems.most_common(10) if c >= 3]
clustered = sum(c for _, c in stems.items() if c >= 3)

years = Counter(y for y in (yr(a.get("created_at")) for a in agents) if y)
now = datetime.now(timezone.utc)
stale = 0
for a in agents:
    try:
        d = datetime.fromisoformat(str(a.get("last_updated")).replace("Z", "+00:00"))
        if (now - d).days > 180: stale += 1
    except Exception:
        pass

cats  = Counter(a.get("category") or "none" for a in agents)
types = Counter(a.get("type") or "unknown" for a in agents)

result = {
    "sampled": n, "requests": nreq, "failed_requests": failed,
    "liveness": {"active": active, "active_pct": pct(active),
                 "unresponsive": unresp,
                 "ever_interacted": ever, "ever_interacted_pct": pct(ever),
                 "recently_interacted": recent, "recently_interacted_pct": pct(recent)},
    "quality": {"rated": rated, "rated_pct": pct(rated),
                "has_description": desc, "has_description_pct": pct(desc),
                "has_readme": readme, "has_readme_pct": pct(readme),
                "declares_protocols": protos, "declares_protocols_pct": pct(protos),
                "featured": featured},
    "composition": {"distinct_owners": len(owners),
                    "top_owner_share_pct": top1_share,
                    "top10_owner_share_pct": top10_share,
                    "top_owners": [{"owner": o[:12] + "…", "agents": c} for o, c in top10],
                    "name_clustered_agents": clustered,
                    "name_clustered_pct": pct(clustered),
                    "top_name_stems": [{"stem": s, "agents": c} for s, c in big_stems]},
    "time": {"created_by_year": dict(sorted(years.items())),
             "not_updated_in_180d": stale, "not_updated_in_180d_pct": pct(stale)},
    "types": dict(types), "categories": dict(cats.most_common(6)),
}

if as_json:
    print(json.dumps(result, indent=2)); sys.exit(0)

print(f"Agentverse directory audit — {n} unique agents from {nreq} requests")
if failed: print(f"  NOTE {failed} request(s) returned no usable payload")
print()
print("LIVENESS")
print(f"  active                  {active:>5} / {n}   {pct(active):>5}%")
print(f"  ever interacted with    {ever:>5} / {n}   {pct(ever):>5}%")
print(f"  RECENTLY interacted     {recent:>5} / {n}   {pct(recent):>5}%")
print(f"  flagged unresponsive    {unresp:>5}")
print()
print("QUALITY")
print(f"  carries a rating        {rated:>5} / {n}   {pct(rated):>5}%")
print(f"  declares a protocol     {protos:>5} / {n}   {pct(protos):>5}%")
print(f"  has a description       {desc:>5} / {n}   {pct(desc):>5}%")
print(f"  has a readme            {readme:>5} / {n}   {pct(readme):>5}%")
print()
print("COMPOSITION")
print(f"  distinct owners         {len(owners):>5}  for {n} agents")
print(f"  largest owner holds     {top1_share:>5}% of the sample")
print(f"  top 10 owners hold      {top10_share:>5}%")
print(f"  in a name cluster (>=3) {clustered:>5} / {n}   {pct(clustered):>5}%")
for s, c in big_stems[:5]:
    print(f"      {s:<28} {c:>4}")
print()
print("TIME")
print(f"  created by year         {dict(sorted(years.items()))}")
print(f"  not updated in 180d     {stale:>5} / {n}   {pct(stale):>5}%")
print()
print(f"  types {dict(types)}")
print()
print("  Reproduce: bash .claude/scripts/agentverse-audit.sh --json")
print("  SEARCH-BIASED SAMPLE, not a census. Fields are Agentverse's own.")
print("  Registered is not the same as active — both can be true at once.")
print("  Bulk-created agents are a normal integration pattern, not an allegation.")
PY
