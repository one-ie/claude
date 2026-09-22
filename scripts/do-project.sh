#!/usr/bin/env bash
# do-project.sh — project a promise's deliverables: into an idempotent subtask spec.
# Parent = the promise (born with tags slug:<slug> — resolveTaskBySlug cannot retrofit).
# One child per deliverable; notes first line is accept: <that accept:> verbatim.
# Emits JSON. Does not POST. Re-projecting with --existing <prior.json> yields new_rows=0.
# Usage:  do-project.sh <slug> [--existing prior.json]   |   do-project.sh --self-test
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Lifted from do-promise-lint.sh — do not fork a second YAML parser.
unquote() {
  local line="$1"
  case "$line" in
    \"*) printf '%s' "$line" | sed -E 's/^"(.*)"[[:space:]]*(#.*)?$/\1/' | sed 's/\\"/"/g' ;;
    \'*) printf '%s' "$line" | sed -E "s/^'(.*)'[[:space:]]*(#.*)?\$/\1/" | sed "s/''/'/g" ;;
    *)   printf '%s' "$line" | sed -E 's/[[:space:]]+#.*$//' ;;
  esac
}
fm() { awk '/^---[[:space:]]*$/{c++;next} c==1{print} c>=2{exit}' "$1"; }
extract_proof() {
  local line
  line="$(fm "$1" | awk '/^proof:/{print;exit}')"
  [ -z "$line" ] && return 1
  line="${line#proof:}"
  unquote "$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//')"
}
deliverables_block() {
  fm "$1" | awk '/^deliverables:/{on=1;next} on && /^[a-zA-Z_-]+:/{exit} on{print}'
}

if [ "${1:-}" = "--self-test" ]; then
  S="$(cd "$(dirname "$0")" && pwd)"; f=0
  dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
  cat >"$dir/proj.md" <<'F'
---
title: Project fixture
slug: proj
deliverables:
  - item: "alpha row"
    accept: "test -f a"
  - item: "beta row"
    accept: "test -f b"
proof: "test -f a && test -f b"
---
F
  cat >"$dir/gap.md" <<'F'
---
title: Gap
slug: gap
deliverables:
  - item: "alpha row"
proof: "true"
---
F
  out1="$(PROMISE_FILE="$dir/proj.md" "$S/do-project.sh" proj)" || { echo "  FAIL first project exited $?"; exit 1; }
  echo "$out1" >"$dir/once.json"
  case "$out1" in *"\"slug:proj\""*) printf '  ok   parent carries slug:proj\n' ;;
                 *) printf '  FAIL parent missing slug:proj: %s\n' "$out1"; f=1 ;; esac
  case "$out1" in *"accept: test -f a"*) printf '  ok   child carries accept: verbatim\n' ;;
                 *) printf '  FAIL child missing accept: %s\n' "$out1"; f=1 ;; esac
  case "$out1" in *"\"new_rows\":3"*) printf '  ok   first project inserts 3 rows\n' ;;
                 *) printf '  FAIL first new_rows: %s\n' "$out1"; f=1 ;; esac
  out2="$(PROMISE_FILE="$dir/proj.md" "$S/do-project.sh" proj --existing "$dir/once.json")" || { echo "  FAIL second project exited $?"; f=1; out2=""; }
  case "$out2" in *"\"new_rows\":0"*) printf '  ok   second project new_rows=0\n' ;;
                 *) printf '  FAIL second diff not empty: %s\n' "$out2"; f=1 ;; esac
  set +e
  PROMISE_FILE="$dir/gap.md" "$S/do-project.sh" gap >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -ne 0 ] && printf '  ok   missing accept: refused (exit %s)\n' "$rc" \
    || { printf '  FAIL missing accept: should refuse\n'; f=1; }
  [ "$f" -eq 0 ] && echo "do-project: self-test green" || echo "do-project: self-test FAILED"
  exit "$f"
fi

slug="${1:-}"
[ -z "$slug" ] && { echo "usage: do-project.sh <slug> [--existing prior.json] | --self-test" >&2; exit 4; }
shift
existing=""
while [ $# -gt 0 ]; do
  case "$1" in
    --existing) existing="${2:-}"; shift 2 ;;
    *) echo "unknown flag $1" >&2; exit 4 ;;
  esac
done

file="${PROMISE_FILE:-$ROOT/text/$slug.md}"
[ -f "$file" ] || { echo "do-project: no promise at ${file#"$ROOT"/}" >&2; exit 3; }

block="$(deliverables_block "$file")"
[ -z "$block" ] && { echo "do-project: no deliverables: in ${file#"$ROOT"/}" >&2; exit 1; }

items=""; accepts=""
while IFS= read -r raw; do
  [ -z "$raw" ] && continue
  val="$(unquote "$(printf '%s' "$raw" | sed -E 's/^[[:space:]]*-[[:space:]]*item:[[:space:]]*//')")"
  items="${items}${val}
"
done <<EOF
$(printf '%s\n' "$block" | grep '^[[:space:]]*-[[:space:]]*item:' || true)
EOF
while IFS= read -r raw; do
  [ -z "$raw" ] && continue
  val="$(unquote "$(printf '%s' "$raw" | sed -E 's/^[[:space:]]*accept:[[:space:]]*//')")"
  accepts="${accepts}${val}
"
done <<EOF
$(printf '%s\n' "$block" | grep '^[[:space:]]*accept:' || true)
EOF

n_items="$(printf '%s' "$items" | grep -c . || true)"
n_acc="$(printf '%s' "$accepts" | grep -c . || true)"
if [ "$n_items" -lt 1 ] || [ "$n_items" -ne "$n_acc" ]; then
  echo "do-project: refuse — $n_items item(s) but $n_acc accept(s); every deliverable needs accept:" >&2
  exit 1
fi

title="$(fm "$file" | awk '/^title:/{sub(/^title:[[:space:]]*/,"");print;exit}')"
title="$(unquote "$title")"
[ -z "$title" ] && title="$slug"
proof="$(extract_proof "$file" || true)"

pairf="$(mktemp)"
paste -d $'\t' <(printf '%s' "$items" | grep -v '^$') <(printf '%s' "$accepts" | grep -v '^$') >"$pairf"
python3 - "$slug" "$title" "$proof" "$existing" "$pairf" <<'PY'
import json, sys
slug, title, proof, existing_path, pairf = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
pairs = [ln.rstrip("\n").split("\t", 1) for ln in open(pairf) if ln.strip()]
if not proof:
    proof = " && ".join(p[1] for p in pairs)
prior = {"parent": None, "children": []}
if existing_path:
    prior = json.load(open(existing_path))
prior_tags = (prior.get("parent") or {}).get("tags") or []
parent_exists = ("slug:%s" % slug) in prior_tags
prior_titles = {c.get("title") for c in (prior.get("children") or []) if c.get("title")}
parent = {
    "title": title,
    "tags": ["slug:%s" % slug],
    "notes": "accept: %s" % proof,
    "insert": not parent_exists,
    "create": "tasks:create",
}
children, new_rows = [], 1 if parent["insert"] else 0
for item, accept in pairs:
    ins = item not in prior_titles
    children.append({
        "title": item,
        "notes": "accept: %s" % accept,
        "insert": ins,
        "steps": ["tasks:subtask", "tasks:notes"],
    })
    if ins:
        new_rows += 1
print(json.dumps({"parent": parent, "children": children, "new_rows": new_rows}, separators=(",", ":")))
PY
rm -f "$pairf"
