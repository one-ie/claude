#!/usr/bin/env bash
# do-analyze.sh — ANALYZE coverage gate (ex-Spec-Kit /analyze), read-only. Run at the
# todo→code boundary, BEFORE build spends worktree tokens. Verifies the plan against the
# current template-todo.md contract: a `deliverables:` frontmatter block, and per-cycle
# `**Deliverable:**` + (`demo:` | `**Cycle outcome:**`) lines.
#
# CRITICAL (exit 1, blocks build):
#   - deliverables: frontmatter is empty            → plan ships nothing
#   - a ## C# cycle has no **Deliverable:** line     → cycle ships nothing (coverage hole)
#   - a ## C# cycle has no `- [ ] W` wave checkbox   → do-auto/do-engine read the cycle as
#                                                      already-done and FALSE-COMPLETE the plan
#                                                      (built nothing; verified done-ui 2026-07-23)
# HIGH (warn, does not block):
#   - a cycle has no demo:/Cycle outcome line        → AC→test gap (no planned verification)
#   - a promise deliverable's accept: appears in NO cycle → the promise ships broken even
#                                                      though every cycle closes green
#                                                      (verified factory 2026-07-28: stream,
#                                                      walk-speed, tracer had no cycle at all —
#                                                      they existed only in the todo's outcome:)
#     `--strict-promise` promotes this to CRITICAL (exit 1).
# Never edits.
# Usage:  do-analyze.sh <todo.md> [--strict-promise]
set -euo pipefail
todo=""; strict=0
for a in "$@"; do
  case "$a" in
    --strict-promise) strict=1 ;;
    -*) echo "CRITICAL: unknown flag: $a"; exit 1 ;;
    *) [ -n "$todo" ] || todo="$a" ;;
  esac
done
[ -n "$todo" ] || { echo "usage: do-analyze.sh <todo.md> [--strict-promise]"; exit 1; }
[ -f "$todo" ] || { echo "CRITICAL: todo not found: $todo"; exit 1; }

crit=0; high=0

# 1. plan ships something: deliverables: frontmatter has >=1 real entry (- kind: ...)
ndel=$(awk '
  /^deliverables:/ {f=1; next}
  f && /^[a-z_]+:/ {f=0}
  f && /^[[:space:]]*-[[:space:]]/ {n++}
  END {print n+0}
' "$todo")
if [ "$ndel" -eq 0 ]; then
  echo "CRITICAL: deliverables: frontmatter is empty — plan ships nothing"; crit=1
fi

# 2. every cycle ships a deliverable AND has a planned test. Walk each ## C# section
#    (header to the next ## header — ### W-waves and **bold** lines stay inside).
ncyc=0; nodeliv=0; notest=0; nowave=0
for c in $(grep -oE '^## C[0-9]+' "$todo" | grep -oE 'C[0-9]+'); do
  ncyc=$((ncyc+1))
  block=$(awk -v c="$c" '
    $0 ~ "^## "c"( |$)" {f=1; print; next}
    f && /^## / {exit}
    f {print}
  ' "$todo")
  printf '%s' "$block" | grep -qE '^\*\*Deliverable' || {
    echo "CRITICAL: $c has no **Deliverable:** line (cycle ships nothing — coverage hole)"; crit=1; nodeliv=$((nodeliv+1))
  }
  # Wave-checkbox presence: do-auto.sh _sync_status (IC3) and do-engine.js openCyclesFromTodo
  # decide a cycle is done when its ## C# SECTION has zero `- [ ] W` lines. A cycle with NO
  # `- [ ] W`/`- [x] W`/`- [~] W` line at all is read as already-complete → the loop builds
  # nothing and reports "plan complete". Refuse it before build.
  printf '%s' "$block" | grep -qE '^[[:space:]]*- \[[ x~]\] W' || {
    echo "CRITICAL: $c has no '- [ ] W' wave checkbox in its section — do-auto/do-engine will read it as already-done and false-complete the plan (add a '### Definition of done' with '- [ ] W1..W4')"; crit=1; nowave=$((nowave+1))
  }
  printf '%s' "$block" | grep -qiE 'demo:|^\*\*Cycle outcome' || {
    echo "HIGH: $c has no planned test (demo: or **Cycle outcome:** line)"; high=$((high+1)); notest=$((notest+1))
  }
done

# 3. PROMISE coverage: every deliverable in text/<slug>.md is served by some cycle.
#    Checks 1-2 only ever compare the todo against ITSELF, so a plan can be internally
#    consistent, pass ANALYZE, close every cycle green — and still leave the promise
#    broken, discovered first at settle. This reads the promise.
#    Matching rule: the deliverable's whole `accept:` command, whitespace-normalised, must
#    appear inside a `## C<n>` SECTION (its demo.command or body). Frontmatter (where
#    `outcome:` restates every accept: verbatim) and `Correct-course` blocks are NOT corpus —
#    that is exactly where the three missing factory deliverables did appear, which is why
#    the gap was invisible. Trailing boundary stops `... view` matching `... view-gaps`.
promise="$(dirname "$todo")/$(basename "$todo" -todo.md).md"
pndel=0; pcov=0; puncov=0
if [ -f "$promise" ]; then
  accepts=$(awk '
    /^---[[:space:]]*$/ { d++; if (d>=2) exit; next }
    d!=1 { next }
    /^deliverables:[[:space:]]*$/ { f=1; next }
    f && /^[A-Za-z_][A-Za-z0-9_-]*:/ { f=0 }
    !f { next }
    /^[[:space:]]*-?[[:space:]]*item:[[:space:]]*/ {
      it=$0; sub(/^[[:space:]]*-?[[:space:]]*item:[[:space:]]*/,"",it); item=unq(it); next
    }
    /^[[:space:]]*accept:[[:space:]]*/ {
      ac=$0; sub(/^[[:space:]]*accept:[[:space:]]*/,"",ac); ac=unq(ac)
      gsub(/[[:space:]]+/," ",ac); sub(/^ /,"",ac); sub(/ $/,"",ac)
      if (ac != "") printf "%s\t%s\n", ac, item
    }
    # strip the YAML quote wrapper, then unescape \" so a single-quoted promise and a
    # double-quoted todo demo of the SAME command still compare equal
    function unq(s) {
      sub(/[[:space:]]+$/,"",s)
      if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/) s=substr(s,2,length(s)-2)
      gsub(/\\"/,"\"",s)
      return s
    }
  ' "$promise")
  # cycle corpus: ## C<n> sections only, whitespace-normalised, one line per source line
  corpus=$(awk '
    /^---[[:space:]]*$/ { d++; next }
    d<2 { next }
    # depth-aware: a cycle section runs until a heading at the SAME-OR-SHALLOWER depth.
    # `#### W3 edit` inside `### C1` stays in; `## Cycles`/`### C2` ends it. Correct-course
    # is excluded at ANY depth (a `#### Correct-course` nested inside a cycle would
    # otherwise re-open the exact blind spot this check exists to close).
    /^#+[[:space:]]*C[0-9]+([[:space:]]|$)/ { match($0,/^#+/); opd=RLENGTH; inc=1; next }
    tolower($0) ~ /^#+[[:space:]]*.*correct-course/ { inc=0; next }
    /^#+[[:space:]]/ { match($0,/^#+/); if (RLENGTH<=opd) { inc=0; next } }
    inc { gsub(/\\"/,"\""); gsub(/[[:space:]]+/," "); sub(/^ /,""); sub(/ $/,""); if ($0 != "") print }
  ' "$todo")
  pndel=$(printf '%s' "$accepts" | grep -c . || true)
  # cycles as the CORPUS sees them — `### C1` under a `## Cycles` parent is a real cycle
  # even though check #2's `^## C#` scan (unchanged) doesn't count it.
  pcyc=$(grep -cE '^#+[[:space:]]*C[0-9]+([[:space:]]|$)' "$todo" || true)
  if [ "$pndel" -gt 0 ] && [ "$pcyc" -eq 0 ]; then
    echo "HIGH: promise-coverage CANNOT RUN — $promise has $pndel deliverables but no 'C<n>' cycle section parsed in $todo"
    high=$((high+1)); pndel=0
  elif [ "$pndel" -gt 0 ]; then
    while IFS=$'\t' read -r ac item; do
      [ -n "$ac" ] || continue
      if printf '%s\n' "$corpus" | awk -v s="$ac" '
        { p=index($0,s); while (p>0) {
            c=substr($0,p+length(s),1)
            if (c=="" || c !~ /[A-Za-z0-9_.\/-]/) { found=1; exit }
            rest=substr($0,p+1); q=index(rest,s); if (q==0) break; p=p+q
          } }
        END { exit !found }
      '; then
        pcov=$((pcov+1))
      else
        puncov=$((puncov+1))
        lvl="HIGH"; [ "$strict" -eq 1 ] && lvl="CRITICAL"
        echo "$lvl: promise deliverable has NO cycle — accept: $ac"
        [ -n "${item:-}" ] && echo "        item: $item"
        if [ "$strict" -eq 1 ]; then crit=1; else high=$((high+1)); fi
      fi
    done <<< "$accepts"
  fi
fi

echo "----"
echo "coverage: $ndel deliverables / $ncyc cycles · cycles-without-deliverable=$nodeliv · cycles-without-wave=$nowave · cycles-without-test=$notest · high=$high"
if [ "$pndel" -gt 0 ]; then
  echo "promise-coverage: $pndel promised / $pcov covered / $puncov uncovered · promise=$promise$([ "$strict" -eq 1 ] && echo ' · strict')"
fi
if [ "$crit" -ne 0 ]; then echo "ANALYZE: CRITICAL — fix coverage before build"; exit 1; fi
echo "ANALYZE: pass (every cycle ships + is testable)"; exit 0
