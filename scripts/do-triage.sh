#!/usr/bin/env bash
# do-triage.sh — zero-LLM pre-pass over a captured task.
# Emits {verdict, paths, route, dupe}. Verdicts: sizeable | idea | dupe | split.
# Discriminator for idea: can you state in one line the check that proves this done?
# Usage:  do-triage.sh "captured text"   |   do-triage.sh --self-test
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEXT_DIR="${TRIAGE_TEXT_DIR:-$ROOT/text}"
PAGES="$ROOT/one.ie/web/src/pages"

# --self-test — one fixture per verdict (same idiom as do-tier.sh).
if [ "${1:-}" = "--self-test" ]; then
  S="$(cd "$(dirname "$0")" && pwd)"; f=0
  export TRIAGE_TEXT_DIR="$S/fixtures"
  chk() {
    want="$1"; shift
    got="$("$S/do-triage.sh" "$@" 2>/dev/null)" || true
    case "$got" in *"\"verdict\":\"$want\""*) printf '  ok   %s → %s\n' "$*" "$want" ;;
                   *) printf '  FAIL %s → expected %s, got %s\n' "$*" "$want" "$got"; f=1 ;; esac
  }
  chk sizeable "fix UNSIZED exit in .claude/scripts/do-tier.sh"
  chk idea     "make the board nicer"
  chk split    "fix .claude/scripts/do-tier.sh and .claude/scripts/do-survey.sh"
  chk dupe     "xyzzy-triage-dupe unique deliverable phrase"
  # sizeable names a real file — paths must include it (feeds do-tier, never a sentence)
  got="$("$S/do-triage.sh" "fix UNSIZED exit in .claude/scripts/do-tier.sh" 2>/dev/null)" || true
  case "$got" in *".claude/scripts/do-tier.sh"*) printf '  ok   sizeable paths include the named file\n' ;;
                 *) printf '  FAIL sizeable paths missing named file: %s\n' "$got"; f=1 ;; esac
  got="$("$S/do-triage.sh" "the banner on /chat shows twice" 2>/dev/null)" || true
  case "$got" in *"\"verdict\":\"sizeable\""*"\"route\":\"/chat\""*|*"\"route\":\"/chat\""*"\"verdict\":\"sizeable\""*) printf '  ok   named route /chat → sizeable\n' ;;
                 *) printf '  FAIL named route /chat: %s\n' "$got"; f=1 ;; esac
  [ "$f" -eq 0 ] && echo "do-triage: self-test green" || echo "do-triage: self-test FAILED"
  exit "$f"
fi

text="${*:-}"
if [ -z "$text" ]; then
  if [ -t 0 ]; then echo "usage: do-triage.sh <captured text> | --self-test" >&2; exit 4; fi
  text="$(cat)"
fi
[ -z "$text" ] && { echo "usage: do-triage.sh <captured text> | --self-test" >&2; exit 4; }

# Existing repo-relative paths the title names.
paths=""
while IFS= read -r p; do
  [ -z "$p" ] && continue
  case "$p" in http*|*:*) continue ;; esac
  if [ -e "$ROOT/$p" ]; then
    case "
$paths
" in *"
$p
"*) ;; *) paths="${paths}${p}
" ;; esac
  fi
done <<EOF
$(printf '%s' "$text" | grep -oE '[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+' || true)
EOF

# A whitespace-bounded /route that maps onto an existing page.
route=""
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  r="$(printf '%s' "$tok" | sed 's/^[[:space:]]*//')"
  rel="${r#/}"
  page=""
  if [ -f "$PAGES/${rel}.astro" ]; then page="one.ie/web/src/pages/${rel}.astro"
  elif [ -f "$PAGES/${rel}/index.astro" ]; then page="one.ie/web/src/pages/${rel}/index.astro"
  else
    slugrel="$(printf '%s' "$rel" | sed -E 's|^u/[^/]+/|u/[slug]/|')"
    if [ "$slugrel" != "$rel" ]; then
      [ -f "$PAGES/${slugrel}.astro" ] && page="one.ie/web/src/pages/${slugrel}.astro"
      [ -z "$page" ] && [ -f "$PAGES/${slugrel}/index.astro" ] && page="one.ie/web/src/pages/${slugrel}/index.astro"
    fi
  fi
  if [ -n "$page" ]; then
    route="$r"
    case "
$paths
" in *"
$page
"*) ;; *) paths="${paths}${page}
" ;; esac
    break
  fi
done <<EOF
$(printf '%s' "$text" | grep -oE '(^|[[:space:]])/[a-z][][a-z0-9_/-]*' || true)
EOF

# Near-dupe of an existing promise deliverable (or optional open-task list).
# One Python walk — a bash for-loop over text/*.md is ~8s (1470 files) and find hits ARG_MAX.
dupe_json="null"
if [ -d "$TEXT_DIR" ]; then
  dupe_json="$(python3 - "$TEXT_DIR" "$ROOT" "$text" "${TRIAGE_OPEN_TASKS:-}" <<'PY'
import json, os, re, sys
text_dir, root, needle, open_tasks = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
def norm(s):
    return re.sub(r"\s+", " ", s.lower()).strip()
def unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == '"':
        s = re.sub(r'^"(.*)"\s*(#.*)?$', r"\1", s).replace('\\"', '"')
    elif len(s) >= 2 and s[0] == "'":
        s = re.sub(r"^'(.*)'\s*(#.*)?$", r"\1", s)
    else:
        s = re.sub(r"\s+#.*$", "", s)
    return s
nt = norm(needle)
item_re = re.compile(r"^\s*-\s*item:\s*(.*)$")
def hit(item, rel):
    nitem = norm(item)
    if len(nitem) < 16:
        return False
    if nitem in nt or (len(nt) >= 16 and nt in nitem):
        print(json.dumps({"item": item, "file": rel}, separators=(",", ":")))
        return True
    return False
for dirpath, dirnames, files in os.walk(text_dir):
    dirnames[:] = [d for d in dirnames if not d.startswith(".")]
    rel_dir = os.path.relpath(dirpath, text_dir)
    depth = 0 if rel_dir == "." else rel_dir.count(os.sep) + 1
    if depth > 2:
        dirnames[:] = []
        continue
    for fn in files:
        if not fn.endswith(".md"):
            continue
        path = os.path.join(dirpath, fn)
        try:
            with open(path, encoding="utf-8", errors="ignore") as fh:
                in_fm = 0
                for line in fh:
                    if line.startswith("---"):
                        in_fm += 1
                        if in_fm >= 2:
                            break
                        continue
                    if in_fm != 1:
                        continue
                    m = item_re.match(line)
                    if not m:
                        continue
                    item = unquote(m.group(1))
                    rel = path[len(root)+1:] if path.startswith(root) else path
                    if hit(item, rel):
                        sys.exit(0)
        except OSError:
            continue
if open_tasks and os.path.isfile(open_tasks):
    for line in open(open_tasks, encoding="utf-8", errors="ignore"):
        ot = line.strip()
        if ot and hit(ot, "open-task"):
            sys.exit(0)
print("null")
PY
)"
fi

nfiles=0
if [ -n "$paths" ]; then nfiles="$(printf '%s' "$paths" | grep -c . || true)"; fi
nnum="$(printf '%s' "$text" | grep -oE '(^|[[:space:]])[0-9]+\.' | grep -c . || true)"
has_cmd=0
printf '%s' "$text" | grep -qE 'test -[efd]|grep -[qF]|bunx?[[:space:]]+vitest|bash[[:space:]]|\.sh[[:space:]]|accept:' && has_cmd=1 || true

verdict=idea
if [ "$dupe_json" != "null" ]; then
  verdict=dupe
elif [ "$nfiles" -ge 2 ] || [ "$nnum" -ge 2 ]; then
  verdict=split
elif [ "$nfiles" -ge 1 ] || [ -n "$route" ] || [ "$has_cmd" -eq 1 ]; then
  verdict=sizeable
fi

python3 -c '
import json,sys
verdict, route, dupe = sys.argv[1], sys.argv[2], sys.argv[3]
paths = [ln for ln in sys.stdin.read().splitlines() if ln]
print(json.dumps({"verdict":verdict,"paths":paths,"route":route or None,"dupe":None if dupe=="null" else json.loads(dupe)}, separators=(",",":")))
' "$verdict" "$route" "$dupe_json" <<EOF
$paths
EOF
