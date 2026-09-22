#!/usr/bin/env bash
# close-owner.sh — resolve WHO owns a close and WHO they report to.
#
# manifest: needs-env
#   (reads $ROOT/one.ie/ai/agents — degrades to `owner=ceo via=fallback hits=0`
#    off-monorepo, which is a no-op, not a lie. Not `portable`: it names the path.)
#
# /close needs two deterministic facts before any model speaks: which agent owns
# the work, and which agent it reports to. Both are declared in the roster
# (one.ie/ai/agents/*/agent.md); neither is a judgment call. This script answers
# them so the command executes a fact instead of substituting for one.
#
#   close-owner.sh --tags "engineering,contracts"   -> owner + superior chain
#   close-owner.sh --owner cmo                      -> just the chain above cmo
#   close-owner.sh --roster                         -> coverage census
#   close-owner.sh --self-test                      -> proves it can go RED
#
# THE MATCH RULE, and why it is the bare words only:
# `subscribes:` carries TWO shapes and they are different lanes (root CLAUDE.md).
#   - signal: campaign:brief   <- workflow trigger_source, read by triggerWorkflows
#   - marketing                <- the routing STAKE, read by matchSubscribers
# A namespaced tag matches zero signals. Matching on it would hand work to an
# agent the world will never actually route to.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENTS="$ROOT/one.ie/ai/agents"

# specialist first: ties break DOWNWARD. Sending a director to do specialist work
# is how a director stops being available for the judgment only they can make.
_tier_rank() {
  case "${1:-}" in
    specialist) echo 0 ;; director) echo 1 ;; ceo) echo 2 ;; chairman) echo 3 ;;
    *) echo 9 ;;   # tool / undeclared — never an owner
  esac
}

_field() { grep -m1 "^$2:" "$1" 2>/dev/null | cut -d' ' -f2- | tr -d '\r' | xargs 2>/dev/null; }

# The bare stake words only — skip every `- signal:` line.
#
# TWO YAML SHAPES, and missing the second one made 24 agents invisible.
# Block:  subscribes:\n  - ship\n  - deploy
# Inline: subscribes: [engineering, do-event, ship, deploy, contracts]
# The old parser matched `/^subscribes:/` and immediately `next`ed — which for the
# inline shape SKIPS THE ONLY LINE THE TAGS ARE ON, so the agent parsed as having
# no stake and was silently unreachable by tag. Measured 2026-09-15: 24 of ~108
# agent files use the inline shape, and `close-owner.sh --tags ship` answered
# `hits=0 confidence=none` while release-manager/agent.md:18 stakes both `ship`
# and `deploy`. Every close on those tags fell through to the CEO fallback and
# read as "nobody owns this area" — the routing was wrong, not the roster.
_stakes() {
  awk '
    /^subscribes:/ {
      if ($0 ~ /\[/) {                      # inline flow list — tags are on THIS line
        l=$0; sub(/^[^[]*\[/,"",l); sub(/\].*$/,"",l)
        n=split(l,a,",")
        for (i=1;i<=n;i++) {
          t=a[i]; gsub(/^[ \t"]+|[ \t"]+$/,"",t)
          if (t !~ /^signal:/ && t !~ /:/ && t != "") print t
        }
        f=0; next
      }
      f=1; next                             # block list — tags are on following lines
    }
    f&&/^[a-zA-Z_]+:/{f=0}
    f&&/^[[:space:]]*-[[:space:]]/{
      line=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",line)
      if (line !~ /^signal:/ && line !~ /:/ && line != "") print line
    }' "$1" 2>/dev/null | tr -d '\r' | xargs -n1 2>/dev/null
}

_superior() {           # walk the declared chain, then the tier ladder
  local name="$1" hops=0 out=""
  while [ -n "$name" ] && [ "$hops" -lt 8 ]; do
    local f="$AGENTS/$name/agent.md"
    [ -f "$f" ] || break
    local rt; rt="$(_field "$f" reports_to)"
    if [ -z "$rt" ]; then
      case "$(_field "$f" tier)" in
        specialist) rt="ceo" ;;      # no director declared for its domain
        director)   rt="ceo" ;;
        ceo)        rt="chairman" ;;
        chairman)   rt="" ;;         # answers to the human
        *)          rt="ceo" ;;      # repo law: CEO is the standing receiver
      esac
    fi
    [ -z "$rt" ] && break
    out="$out $rt"; name="$rt"; hops=$((hops+1))
  done
  echo "$out" | xargs 2>/dev/null
}

cmd_roster() {
  local tot=0 rt=0 ti=0 sub=0 bare=0
  for d in "$AGENTS"/*/; do
    local f="$d/agent.md"; [ -f "$f" ] || continue
    tot=$((tot+1))
    [ -n "$(_field "$f" reports_to)" ] && rt=$((rt+1))
    [ -n "$(_field "$f" tier)" ] && ti=$((ti+1))
    grep -q '^subscribes:' "$f" && sub=$((sub+1))
    [ -n "$(_stakes "$f")" ] && bare=$((bare+1))
  done
  echo "agents=$tot reports_to=$rt tier=$ti subscribes=$sub bare_stakes=$bare"
  echo "note: agents WITHOUT bare stakes cannot be matched by tag — they need the ladder fallback."
}

# How many agents stake a given word. A word many agents carry cannot single one
# out — `marketing` is on 16 of them, so one hit against it is a tie broken by
# directory order, not a match.
GENERIC_AT=${CLOSE_OWNER_GENERIC_AT:-3}

# THE INDEX — one awk pass over the whole roster, built once, reused by every
# lookup. It replaced a per-agent `_stakes` fork called from inside two nested
# loops: a --self-test spawned ~1300 awk processes and took 101s. Same answers,
# one pass. Rows are `name<TAB>tier<TAB>reports_to<TAB>stake`, one per stake.
# The memo is a FILE, not a variable. Every `$(_index)` runs in a subshell, so a
# variable assignment inside it is discarded the moment the subshell exits — the
# memo silently never hit and awk re-ran on every call (measured: no improvement
# at all, 101s -> 70s, when the whole point was one pass).
_INDEX_FILE="${TMPDIR:-/tmp}/close-owner-index.$$"
trap 'rm -f "$_INDEX_FILE"' EXIT
_index() {
  [ -s "$_INDEX_FILE" ] && { cat "$_INDEX_FILE"; return; }
  awk '
    FNR==1 { name=""; tier=""; rt=""; insub=0
             n=split(FILENAME,p,"/"); dir=p[n-1] }
    /^name:/        { sub(/^name:[[:space:]]*/,"");        name=$0 }
    /^tier:/        { sub(/^tier:[[:space:]]*/,"");        tier=$0 }
    /^reports_to:/  { sub(/^reports_to:[[:space:]]*/,"");  rt=$0 }
    # Both YAML shapes — see _stakes() above for why the inline one is not optional.
    # `name:` precedes `subscribes:` in every agent.md, so name is already bound here.
    /^subscribes:/  {
      if ($0 ~ /\[/) {
        il=$0; sub(/^[^[]*\[/,"",il); sub(/\].*$/,"",il)
        ic=split(il,ia,",")
        for (ii=1;ii<=ic;ii++) {
          it=ia[ii]; gsub(/^[ \t"]+|[ \t"]+$/,"",it)
          if (it !~ /^signal:/ && it !~ /:/ && it != "")
            print (name==""?dir:name) "\t" tier "\t" rt "\t" it
        }
        insub=0; next
      }
      insub=1; next
    }
    insub && /^[a-zA-Z_]+:/ { insub=0 }
    insub && /^[[:space:]]*-[[:space:]]/ {
      l=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",l); gsub(/[[:space:]]+$/,"",l)
      if (l !~ /^signal:/ && l !~ /:/ && l != "") {
        print (name==""?dir:name) "\t" tier "\t" rt "\t" l
      }
    }
  ' "$AGENTS"/*/agent.md 2>/dev/null > "$_INDEX_FILE"
  cat "$_INDEX_FILE"
}

_tag_breadth() {
  _index | awk -F'\t' -v T="$1" '$4==T{a[$1]=1} END{print length(a)}'
}

# Every agent whose stakes intersect the tags, tier-ranked. This is what a refusal
# hands upward — a decision without the options is not a decision.
_candidates() {
  local tags="$1"; local IFS=,; read -ra want <<< "$tags"; unset IFS
  local agent tier_w
  while IFS=$'\t' read -r agent tier_w; do
    [ -n "$agent" ] || continue
    local rank; rank="$(_tier_rank "$tier_w")"
    [ "$rank" -ge 9 ] && continue
    local hits=0 s w
    for s in $(_index | awk -F'\t' -v A="$agent" '$1==A{print $4}'); do
      for w in "${want[@]}"; do [ "$(echo "$w" | xargs)" = "$s" ] && hits=$((hits+1)); done
    done
    [ "$hits" -gt 0 ] && echo "$rank:$agent($hits)"
  done <<< "$(_index | awk -F'\t' '{print $1"\t"$2}' | sort -u)" | sort | cut -d: -f2
}

cmd_resolve() {
  local tags="$1" best="" best_rank=9 best_hits=0 best_specific=0 contenders=0
  local IFS=,; read -ra want <<< "$tags"; unset IFS

  # Breadth is a property of the TAG, not of the agent being examined, and only
  # the requested tags matter — so it is computed once here rather than inside
  # the agent loop. Calling _tag_breadth per matching stake made this quadratic
  # over file reads (a --self-test went from ~1s to >120s); bash 3.2 has no
  # associative arrays, so the answers ride a parallel indexed array.
  local -a want_breadth=()
  local i
  for i in "${!want[@]}"; do
    want[$i]="$(echo "${want[$i]}" | xargs)"
    want_breadth[$i]="$(_tag_breadth "${want[$i]}")"
  done

  # One pass over the index: agent -> its stakes, already parsed.
  local line agent tier_w
  while IFS=$'\t' read -r agent tier_w; do
    [ -n "$agent" ] || continue
    local rank; rank="$(_tier_rank "$tier_w")"
    [ "$rank" -ge 9 ] && continue                    # tool / undeclared: not an owner
    local hits=0 specific=0 s j
    for s in $(_index | awk -F'\t' -v A="$agent" '$1==A{print $4}'); do
      for j in "${!want[@]}"; do
        if [ "${want[$j]}" = "$s" ]; then
          hits=$((hits+1))
          [ "${want_breadth[$j]}" -le "$GENERIC_AT" ] && specific=$((specific+1))
        fi
      done
    done
    [ "$hits" -eq 0 ] && continue
    contenders=$((contenders+1))
    if [ "$specific" -gt "$best_specific" ] \
       || { [ "$specific" -eq "$best_specific" ] && [ "$hits" -gt "$best_hits" ]; } \
       || { [ "$specific" -eq "$best_specific" ] && [ "$hits" -eq "$best_hits" ] && [ "$rank" -lt "$best_rank" ]; }; then
      best="$agent"; best_rank="$rank"; best_hits="$hits"; best_specific="$specific"
    fi
  done <<< "$(_index | awk -F'\t' '{print $1"\t"$2}' | sort -u)"

  if [ -z "$best" ]; then
    # Not a failure — the documented fallback. world:route answers reason:'ceo'
    # for a workspace with no history, and the CEO is the standing receiver.
    echo "owner=ceo  via=fallback(no-tag-match)  hits=0  confidence=none"
    echo "chain=$(_superior ceo)"
    return 0
  fi

  # THE REFUSAL. Evidence that cannot separate one candidate from several is not
  # a match — it is directory order wearing a receipt. Modelled on factory:size
  # returning `unsized` for an empty path set (resolvers/factory.ts:206) rather
  # than guessing a tier. Refusing routes to the ladder, which explains itself.
  if [ "$best_specific" -eq 0 ] && [ "$contenders" -gt 1 ]; then
    echo "owner=REFUSED  via=ambiguous  hits=$best_hits  contenders=$contenders  confidence=low"
    echo "reason=only generic tags matched (each carried by >$GENERIC_AT agents); $contenders candidates were indistinguishable"
    # A refusal that names nothing forces the asker to redo the search. The whole
    # point of refusing is to hand the decision UP with the evidence attached, so
    # the shortlist rides with it — this is the notify-a-human payload.
    echo "candidates=$(_candidates "$tags" | tr '\n' ' ' | xargs)"
    echo "fallback=ceo  chain=$(_superior ceo)"
    return 0
  fi

  local conf="high"; [ "$best_specific" -eq 0 ] && conf="medium"
  echo "owner=$best  via=subscribes  hits=$best_hits  specific=$best_specific  contenders=$contenders  confidence=$conf"
  echo "chain=$(_superior "$best")"
}

cmd_self_test() {
  local fails=0
  _expect() { # name, actual, expected-substring
    if grep -q -- "$3" <<< "$2"; then echo "  ok   $1"; else echo "  RED  $1 — got: $2"; fails=$((fails+1)); fi
  }
  echo "close-owner --self-test"

  # The case that shipped broken: this close's own tags named one of five
  # candidates on a single generic hit, and the tie broke on directory order.
  #
  # FIXTURE REPOINTED, not relaxed (2026-09-21). It read 'engineering,inbox,tasks'
  # and depended on `tasks` being staked by NOBODY — which is precisely the gap
  # task:01a0b93c9a30bd09d9b73d85 closed by giving cto the bare stake
  # `tasks`/`cli`/`planning`. One owned specific tag is enough to separate a
  # candidate, so those tags now resolve `owner=cto confidence=high` and the
  # assertion inverted. That is the RESOLVER WORKING: the area has an owner now.
  # What the assertion is FOR — a tag set whose only hits are generic words must
  # REFUSE rather than pick by directory order — is unchanged, so the fixture
  # drops the word that graduated and keeps the shape: `engineering` (17 agents)
  # + `inbox` (0), measured hits=1 specific=0 contenders=17, the same evidence
  # the original had. Same lesson as the red proof below: repoint a fixture when
  # the world it sampled moves, never weaken what it asserts. If a future stake
  # makes `inbox` specific too, repoint again — do not delete the case.
  _expect "the tags THIS close used are REFUSED, not confidently answered" \
    "$(cmd_resolve 'engineering,inbox')" "owner=REFUSED"
  _expect "a refusal still routes — it names the ladder fallback" \
    "$(cmd_resolve 'engineering,inbox')" "fallback=ceo"
  # The graduated half, asserted directly so the stake cannot silently regress:
  # an area with a real owner must resolve, not fall back to the CEO.
  _expect "a staked board-tooling tag set names its owner with high confidence" \
    "$(cmd_resolve 'tasks,cli,planning')" "owner=cto"
  _expect "a bare generic tag alone is ambiguous, not a match" \
    "$(cmd_resolve engineering)" "owner=REFUSED"
  # CORRECTED BELIEF, not a weakened test. This assertion used to read "a
  # marketing tag reaches a marketing agent". It does not and never did:
  # `marketing` is staked by 16 agents, `sql` by 17. The old test passed because
  # the resolver picked one by directory order and the assertion only checked
  # that SOMETHING was picked. The truthful assertion is that it refuses — and
  # that the refusal carries the shortlist, so the decision can be made upward.
  _expect "a 16-agent tag refuses rather than picking by directory order" \
    "$(cmd_resolve marketing)" "owner=REFUSED"
  _expect "the refusal hands up a candidate shortlist, not just a no" \
    "$(cmd_resolve marketing)" "candidates="
  _expect "a specific tag (1 agent stakes it) still resolves with high confidence" \
    "$(cmd_resolve spec)" "confidence=high"
  _expect "an unknown tag falls back to the CEO, it does not fail" \
    "$(cmd_resolve zzz-no-such-tag)" "owner=ceo"
  _expect "the chain from a director ends at the chairman" \
    "chain=$(_superior cmo)" "chairman"
  _expect "the chain from the ceo is just the chairman" \
    "chain=$(_superior ceo)" "chairman"

  # A namespaced trigger word must NEVER match — it is the other lane.
  local ns; ns="$(cmd_resolve 'campaign:brief')"
  _expect "a namespaced trigger word matches NOBODY (falls back)" "$ns" "owner=ceo"

  # THE INLINE-YAML SHAPE. `subscribes:` is written two ways across the roster and
  # for a long time only one was parsed: `/^subscribes:/ … next` skipped the very
  # line an inline `[a, b, c]` keeps its tags on, so those agents had NO stake as
  # far as this resolver was concerned. Measured 2026-09-15 — 24 of ~108 agent
  # files use the inline shape, and `--tags deploy,release,ship` answered
  # `hits=0 confidence=none` while release-manager/agent.md:18 reads
  # `subscribes: [engineering, do-event, ship, deploy, contracts]`. It did not look
  # like a bug: "no agent staked this" is a legitimate answer this script gives on
  # purpose, so every close on those tags fell through to the CEO and read as an
  # unowned area of the company rather than a parser that could not see the roster.
  # These two assert the inline shape resolves; the file they depend on is a real
  # one, so a rewrite of that frontmatter to the block shape keeps them green.
  _expect "an INLINE subscribes: [a, b] list is parsed (not skipped)" \
    "$(cmd_resolve 'deploy,ship')" "owner=release-manager"
  _expect "an inline stake carries full confidence, like a block one" \
    "$(cmd_resolve 'deploy,ship')" "confidence=high"

  # RED PROOF: gut the mechanism the resolver ACTUALLY reads and assert the
  # matches stop working. A checker that stays green against a gutted mechanism
  # proves nothing — and this one caught exactly that on itself: it used to gut
  # `_stakes`, and when the resolver was rewired onto `_index` the proof went on
  # passing while guarding a function nothing called any more. It was repointed,
  # never relaxed. If you move the mechanism again, move this with it.
  echo "  -- red proof --"
  _index() { echo ""; }
  local gutted; gutted="$(cmd_resolve spec)"
  if grep -q "via=fallback" <<< "$gutted"; then
    echo "  ok   gutted index falls back — the check is load-bearing"
  else
    echo "  RED  gutted index STILL matched: $gutted"; fails=$((fails+1))
  fi

  echo
  [ "$fails" -eq 0 ] && { echo "PASS"; return 0; } || { echo "FAIL ($fails)"; return 1; }
}

case "${1:---help}" in
  --tags)      shift; cmd_resolve "${1:-}" ;;
  --owner)     shift; echo "chain=$(_superior "${1:-}")" ;;
  --roster)    cmd_roster ;;
  --self-test) cmd_self_test ;;
  *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
