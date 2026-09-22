#!/usr/bin/env bash
# corpus-check.sh — measure book-register prose against the corpus that defines it.
#
#   bash .claude/skills/voice/corpus-check.sh --corpus        re-derive the SKILL.md table
#   bash .claude/skills/voice/corpus-check.sh <draft.md> ...  check a draft
#   bash .claude/skills/voice/corpus-check.sh --self-test     prove the checker goes RED
#
# It counts the MECHANICAL half of the voice only: the things a machine can see.
# It cannot tell whether a sentence observes or asserts, and it never claims to.
# A green run is a draft that has not broken a countable rule. It is not a good draft.
#
# manifest: monorepo-only   (the corpus lives in the sibling repo apps/ants)
set -o pipefail

CORPUS="${VOICE_CORPUS:-/Users/toc/Server/apps/ants/docs/book/manuscript}"

measure() {  # measure <label> <file...>
  python3 - "$@" <<'PY'
import re,sys,statistics
label=sys.argv[1]; files=sys.argv[2:]
txt=[]
for f in files:
    try: t=open(f, encoding="utf-8").read()
    except OSError as e: print(f"  cannot read {f}: {e}"); continue
    txt.append(t)
raw="\n".join(txt)
raw=re.sub(r'\A---\n.*?\n---\n','',raw,flags=re.S)      # YAML frontmatter is metadata, not prose
body="\n".join(l for l in raw.split("\n") if not l.startswith("#"))
words=len(body.split())
if not words: print("  EMPTY — nothing to measure"); sys.exit(2)
sents=[s.strip() for s in re.split(r'(?<=[.!?])\s+',body) if len(s.strip())>1]
wl=[len(s.split()) for s in sents]
paras=[p.strip() for p in body.split("\n\n") if p.strip() and p.strip()!="---"]
psent=[len(re.split(r'(?<=[.!?])\s+',p)) for p in paras]
per10k=lambda n: 10000*n/words
CONTRACTION=r"n[\u2019']t\b"
c=lambda pat: len(re.findall(pat,body))
craw=lambda pat: len(re.findall(pat,raw))   # headings live only in raw
one=sum(1 for x in psent if x==1)
short=sum(1 for x in wl if x<=6)
last=re.split(r'(?<=[.!?])\s+',paras[-1].replace("\n"," "))[-1] if paras else ""
print(f"  {label}: {words} words · {len(sents)} sentences · {len(paras)} paragraphs")
print(f"    I                    {c(r'(?<![A-Za-z])I[ ,.]'):6d}        target 0")
print(f"    contractions n\'t     {c(CONTRACTION):6d}        target ~0 (corpus 0.5/10k)")
print(f"    ### headings         {craw(r'(?m)^#{3,}'):6d}        target 0")
sb=[len(re.findall(r'(?m)^---\s*$',t)) for t in txt]
print(f"    --- scene breaks     {sum(sb):6d}  median {statistics.median(sb) if sb else 0:.0f}/file   corpus median 5")
print(f"    1-sentence paras     {one:6d}  {100*one/len(paras):5.1f}%   corpus 25.7%")
print(f"    sentences <=6 words  {short:6d}  {100*short/len(sents):5.1f}%   corpus 22.4%")
print(f"    sentence median      {statistics.median(wl):6.0f} words    corpus 12 (mean {statistics.mean(wl):.1f}, corpus 15.1)")
print(f"    'the reader'         {c(r'(?i)\bthe reader\b'):6d}")
print(f"    'you'                {c(r'(?i)\byou\b'):6d}        corpus favours 'the reader'")
print(f"    digits    per10k     {per10k(c(r'\b\d')):6.1f}        corpus 5.8")
print(f"    em dash   per10k     {per10k(c(chr(8212))):6.1f}        corpus 89.8")
print(f"    final sentence       {len(last.split()):6d} words    corpus median 10")
if last: print(f"      > {last[:100]}")
PY
}

case "${1:-}" in
  --corpus)
    if [ ! -d "$CORPUS" ]; then
      echo "corpus not found: $CORPUS"
      echo "It lives in the sibling repo apps/ants and does not ship. Set VOICE_CORPUS to point at it."
      exit 4          # unavailable — NOT a pass
    fi
    measure "corpus" "$CORPUS"/[0-9][0-9]-*.md ;;

  --self-test)
    d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
    printf '### A heading\n\nI think this is fine. It doesn'"'"'t matter.\n\nYou will see that you agree, you really will.\n' > "$d/bad.md"
    out=$(measure "red-proof" "$d/bad.md")
    echo "$out"
    fail=0
    echo "$out" | grep -qE '^ +I +[1-9]'            || { echo "RED PROOF FAILED: 'I' not counted"; fail=1; }
    echo "$out" | grep -qE "contractions n't +[1-9]" || { echo "RED PROOF FAILED: contraction not counted"; fail=1; }
    echo "$out" | grep -qE '### headings +[1-9]'     || { echo "RED PROOF FAILED: heading not counted"; fail=1; }
    [ $fail -eq 0 ] && echo "SELF-TEST ok — the checker sees all three violations" || exit 1 ;;

  ""|-h|--help)
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//' ;;

  *)
    measure "draft" "$@"
    echo
    echo "  Counted, not judged. The uncountable half is the checklist in SKILL.md." ;;
esac
