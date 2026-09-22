#!/usr/bin/env bash
# agent-actor-parity.sh — the Proof line for text/agent-actor-plan.md.
#
# THREE GUARDS over the three stores that claim to know which agents are live.
# All reads are read-only (D1 SELECT, R2 ListObjectsV2, one HTTP GET). Nothing
# is written, nothing is published.
#
#   G1 IDENTITY   every distinct follows.actor_id is a mintable actor id
#                 ^[a-z0-9][a-z0-9-]{0,62}$ — no trailing dot, no domain
#   G2 GROUNDING  every distinct follows.actor_id has a live persona in R2
#                 at <ws>/agents/<id>.md
#   G3 SUBSTRATE  count(R2 live personas) == count(actor with actor-status "live")
#
# EXIT CODES ARE THE VERDICT
#   0  all three pass
#   1  a guard FAILED (real mismatch)
#   3  no guard failed but one is UNRUN — an unrun gate is not a pass
#   4  could not read a store (credentials / network) — UNRUN, never green
#
# Usage:  bash .claude/scripts/agent-actor-parity.sh [workspace]      (default: one)
#         bash .claude/scripts/agent-actor-parity.sh --self-test      (red + green proof)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WS="${1:-one}"

# ── the guard logic, isolated so --self-test can drive it with fixtures ──────
guards() { # $1=actor_ids file  $2=r2 live names file  $3=substrate live count ("" = unrun)
  python3 - "$1" "$2" "${3:-}" <<'PY'
import re,sys
ids=[l.strip() for l in open(sys.argv[1]) if l.strip()]
r2=set(l.strip() for l in open(sys.argv[2]) if l.strip())
sub=sys.argv[3]
ID=re.compile(r'^[a-z0-9][a-z0-9-]{0,62}$')
bad=[i for i in ids if not ID.match(i)]
ung=[i for i in ids if i not in r2]
rc=0
print(f"G1 IDENTITY   {'pass' if not bad else 'FAIL'}  {len(ids)-len(bad)}/{len(ids)} mintable" + (f"  -> {' '.join(sorted(bad))}" if bad else ""))
print(f"G2 GROUNDING  {'pass' if not ung else 'FAIL'}  {len(ids)-len(ung)}/{len(ids)} have an R2 persona" + (f"  -> {len(ung)} ungrounded" if ung else ""))
if bad or ung: rc=1
if sub=="":
    print(f"G3 SUBSTRATE  unrun  R2 live={len(r2)}  actor-status live=UNREADABLE (no door)")
    rc = rc if rc else 3
else:
    ok = int(sub)==len(r2) and len(r2)>0
    print(f"G3 SUBSTRATE  {'pass' if ok else 'FAIL'}  R2 live={len(r2)}  actor-status live={sub}")
    if not ok: rc=1
sys.exit(rc)
PY
}

# ── --self-test: prove the checker can go BOTH ways ─────────────────────────
if [ "${1:-}" = "--self-test" ]; then
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
  printf 'ceo\ncmo.\n'      > "$T/red_ids";   printf 'ceo\n'        > "$T/red_r2"
  printf 'ceo\ncto\n'       > "$T/green_ids"; printf 'ceo\ncto\n'   > "$T/green_r2"
  guards "$T/red_ids" "$T/red_r2" 0 >/dev/null 2>&1; r=$?
  guards "$T/green_ids" "$T/green_r2" 2 >/dev/null 2>&1; g=$?
  guards "$T/green_ids" "$T/green_r2" "" >/dev/null 2>&1; u=$?
  echo "self-test: red=$r (want 1)  green=$g (want 0)  unrun=$u (want 3)"
  [ "$r" = 1 ] && [ "$g" = 0 ] && [ "$u" = 3 ] && { echo "SELF-TEST PASS"; exit 0; }
  echo "SELF-TEST FAIL"; exit 1
fi

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# ── store 1: D1 follows ─────────────────────────────────────────────────────
( cd "$ROOT/one.ie/web" && npx wrangler d1 execute one-owners --remote --json \
    --command "SELECT DISTINCT actor_id FROM follows WHERE workspace='$WS' ORDER BY actor_id" 2>/dev/null ) \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print('\n'.join(r['actor_id'] for r in d[0]['results']))" \
  > "$WORK/ids" || { echo "UNRUN: D1 follows unreadable"; exit 4; }
[ -s "$WORK/ids" ] || { echo "UNRUN: D1 follows returned no rows for workspace=$WS"; exit 4; }

# ── store 2: R2 one-content, ListObjectsV2 (SigV4, stdlib only) ─────────────
python3 - "$ROOT/one.ie/web/.dev.vars" "one-content" "$WS/agents/" > "$WORK/r2" <<'PY' || { echo "UNRUN: R2 unreadable"; exit 4; }
import sys,hmac,hashlib,datetime,urllib.request,urllib.parse
import xml.etree.ElementTree as ET
env={}
for line in open(sys.argv[1],encoding='utf-8',errors='ignore'):
    line=line.strip()
    if line and not line.startswith('#') and '=' in line:
        k,v=line.split('=',1); env[k.strip()]=v.strip().strip('"').strip("'")
AK=env['CLOUDFLARE_R2_S3_ACCESS_KEY_ID']; SK=env['CLOUDFLARE_R2_S3_SECRET_KEY']
host=f"{env['CLOUDFLARE_ACCOUNT_ID']}.r2.cloudflarestorage.com"
bucket,prefix=sys.argv[2],sys.argv[3]
sign=lambda k,m: hmac.new(k,m.encode(),hashlib.sha256).digest()
def page(tok):
    q={'list-type':'2','prefix':prefix,'max-keys':'1000'}
    if tok: q['continuation-token']=tok
    qs='&'.join(f"{urllib.parse.quote(k,safe='')}={urllib.parse.quote(v,safe='')}" for k,v in sorted(q.items()))
    t=datetime.datetime.now(datetime.timezone.utc)
    ad,ds=t.strftime('%Y%m%dT%H%M%SZ'),t.strftime('%Y%m%d')
    ph=hashlib.sha256(b'').hexdigest()
    cr=f"GET\n/{bucket}\n{qs}\nhost:{host}\nx-amz-content-sha256:{ph}\nx-amz-date:{ad}\n\nhost;x-amz-content-sha256;x-amz-date\n{ph}"
    sc=f"{ds}/auto/s3/aws4_request"
    sts=f"AWS4-HMAC-SHA256\n{ad}\n{sc}\n{hashlib.sha256(cr.encode()).hexdigest()}"
    k=sign(('AWS4'+SK).encode(),ds);k=sign(k,'auto');k=sign(k,'s3');k=sign(k,'aws4_request')
    sig=hmac.new(k,sts.encode(),hashlib.sha256).hexdigest()
    r=urllib.request.Request(f"https://{host}/{bucket}?{qs}",headers={'Host':host,'x-amz-date':ad,
        'x-amz-content-sha256':ph,'Authorization':f"AWS4-HMAC-SHA256 Credential={AK}/{sc}, "
        f"SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature={sig}"})
    return urllib.request.urlopen(r,timeout=60).read()
ns='{http://s3.amazonaws.com/doc/2006-03-01/}';keys=[];tok=None
while True:
    root=ET.fromstring(page(tok))
    keys += [c.find(ns+'Key').text for c in root.findall(ns+'Contents')]
    tr=root.find(ns+'IsTruncated')
    if tr is not None and tr.text=='true': tok=root.find(ns+'NextContinuationToken').text
    else: break
for k in sorted(keys):
    rel=k[len(prefix):]
    if rel.endswith('.md') and '/' not in rel: print(rel[:-3])
PY

# ── store 3: the substrate. actor-status "live" has no read door today. ─────
SUB=""
CODE=$(curl -s -o "$WORK/sub" -w '%{http_code}' --max-time 25 \
        "https://one.ie/api/export/actors?workspace=$WS&status=live" 2>/dev/null || echo 000)
if [ "$CODE" = "200" ]; then
  SUB=$(python3 -c "
import json,sys
try:
  d=json.load(open('$WORK/sub'))
  rows=d if isinstance(d,list) else d.get('actors',d.get('results',[]))
  print(sum(1 for r in rows if str(r.get('actorStatus',r.get('actor-status',''))) == 'live'))
except Exception: print('')" 2>/dev/null)
fi

echo "workspace=$WS  follows_actors=$(wc -l < "$WORK/ids" | tr -d ' ')  r2_live_personas=$(wc -l < "$WORK/r2" | tr -d ' ')  export_actors_http=$CODE"
guards "$WORK/ids" "$WORK/r2" "$SUB"
