#!/usr/bin/env bash
# m.sh — call ANY model from the terminal, in one line.
#
#   .claude/scripts/m.sh kimi "what is 2+2"
#   .claude/scripts/m.sh -m opus -f text/key.md "assess this document"
#   cat notes.md | .claude/scripts/m.sh grok "summarise"
#   .claude/scripts/m.sh --models kimi,opus,grok "one question, three answers"
#
# classification: needs-env
#
# WHY THIS EXISTS, AND WHY IT GOES THROUGH ONE.
# The repo's own OPENROUTER_API_KEY is REVOKED — `sk-or-v1-ced20…` answers 401
# {"message":"User not found"} and so does the auth-only GET /api/v1/key, so it
# is the credential and not the payload (swept 2026-09-20: no other live
# sk-or-v1- key exists in the monorepo, ~/Server, ~/.claude, the shell rc files
# or the macOS keychain). There is therefore ONE transport here, not two: the
# substrate's own `agent:run`, paid for by prod's OpenRouter key. A direct
# OpenRouter branch would be code nobody can drive green, so it is deliberately
# absent. If a live local key ever lands, add it then — it is ten lines.
#
# HOW THE MODEL IS CHOSEN. There is no per-call model parameter anywhere in the
# stack: `/run` reads `persona.model` and nothing else (channels/src/index.ts).
# The model is a property of the AGENT, set in its R2 frontmatter and read at
# channels/src/context.ts:592. So this script mints one throwaway passthrough
# persona per model — `m-<sanitised-model-id>` — and reuses it forever after.
# resolveBaseModel (channels/src/middleware.ts) hands an id with no provider
# prefix straight to `openrouter(modelId)` VERBATIM, and only the `openai/` and
# `cerebras/` branches carry fallback middleware, so a valid id cannot be
# silently answered by a different model.
#
# THE ONE THING THIS TRANSPORT CANNOT TELL YOU. `agent:run` returns
# {ok, text, actorId} — no finish_reason, no token counts. TRUNCATION IS
# UNDETECTABLE HERE. This script prints the character count to stderr on every
# call and never claims an answer is complete; do not infer completeness from
# an answer that ends in a full stop. (credit_burns.model records the real
# provider/model per turn, but the only receiver that surfaces that column is
# wallet:invoice, which MINTS an invoice to read it.)
set -uo pipefail

CACHE="${HOME}/.cache/one-m"; mkdir -p "$CACHE/personas" "$CACHE/out"
API="${ONE_API_URL:-https://one.ie}"
DEFAULT_MODEL="moonshotai/kimi-k3"

die() { printf '%s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*" >&2; }

# ── THE MODEL REGISTRY ─ tags are the stake, latency is measured ───────────
# Same shape ONE routes signals with (CLAUDE.md § routing): a thing declares
# TAGS, a request carries tags, and the match is ranked. Here the rank is a
# MEASURED number, not an opinion — `ttft` is the p50 of the door's own
# server-timing `data` phase on a one-token answer (2026-09-20, sequential,
# unique prompt per call, n=5-7). A `?` means never measured; it ranks LAST
# rather than pretending to be fast.
#
# Tags are BARE words, never namespaced — the same law the substrate's
# subscribe tags obey (a namespaced tag matches zero signals).
#   open      open weights            frontier  top-tier intelligence
#   fast      sub-1.2s measured ttft  cheap     < $0.50/Mtok input
#   long      >= 1M context           code      tuned for code
#   reason    reasoning/thinking      cn        Chinese lab
#   vision    image input
#
# price and context are NOT stored here — `--filter` reads them live from
# OpenRouter, because a hardcoded price is a lie with a timestamp.
#
# TWO AXES, AND THEY DISAGREE. `ttft` is time to the FIRST token; `tps` is
# tokens per second AFTER it. A model can win one and lose the other badly:
# gpt-5.2 answers first (900ms) and finishes a 700-word answer LAST but one
# (20.4s), while gemini-3.5-flash-lite wins both (894ms, 259 tok/s, 3.9s total).
# Rank on `ttft` for a short interactive answer and on `tps` for generation
# (`--rank tps`). Ranking a long job by ttft picks the wrong model by 5x.
#
# tps measured 2026-09-20: ~700-word prose answer, n=3, median, tokens estimated
# as chars/4 and TTFT subtracted. Reasoning tokens are NOT in the response text,
# so a thinking model's true throughput is HIGHER than the figure here - read
# these as a floor for gpt-5.2 / sonnet-5 / grok, and as time-to-finished-answer
# for everyone.
#
# model|tags  — TAGS ONLY. The NUMBERS live in exactly one place:
#   one.ie/web/src/lib/chat/model-speed.json
# which one.ie/web/src/lib/chat/model-rank.ts also reads, so the `+` deck and
# this script can never disagree. Two tables drift, and the next reader has to
# re-measure to find out which one is true.
MODEL_REGISTRY="
google/gemini-3.5-flash-lite|fast,cheap,long,vision
openai/gpt-5.2|frontier,fast,reason,vision
anthropic/claude-haiku-4.5|fast,cheap,vision
minimax/minimax-m3|open,cn,fast,cheap,long
x-ai/grok-4.5|frontier,reason,vision
moonshotai/kimi-k3|open,cn,frontier,long,reason,vision
anthropic/claude-sonnet-5|frontier,code,reason,vision
deepseek/deepseek-v4-flash|open,cn,cheap,long
openai/gpt-6-astra|frontier,reason,long,vision
anthropic/claude-opus-5|frontier,code,reason,vision
google/gemini-3.8-flash|cheap,long,vision
z-ai/glm-5.3-flash|open,cn,cheap,long
z-ai/glm-5.3|open,cn,frontier,long
qwen/qwen3.8-flash|open,cn,cheap,long
google/gemini-3.1-pro-preview|frontier,long,vision
moonshotai/kimi-k2.7-code|open,cn,code
deepseek/deepseek-v4-pro|open,cn,frontier,long
qwen/qwen3.8-max-0902|open,cn,frontier,long
bytedance-seed/seed-2-1-turbo|open,cn,code
inclusionai/ling-3.0-flash|open,cn,cheap
tencent/hy3|open,cn,cheap
openai/gpt-6-astra-pro|frontier,reason,long,vision
"

# The measured numbers, read from that shared JSON. A model absent from it gets
# `?` on both axes and sorts LAST — never a bluff.
LIBDIR="$(dirname "$0")/../../one.ie/web/src/lib/chat"
# THREE axes, three shared files, none of them duplicated here:
#   model-speed.json  ttft + tok/s, measured through our own door
#   model-intel.json  the Artificial Analysis Intelligence Index (aa-sync.mjs)
# The `+` deck reads the same two, so the CLI and the UI cannot disagree.
speed_of() { # speed_of <model> -> "<ttft> <tokS> <intel>"; `?` for any absent
  python3 - "$LIBDIR" "$1" <<'PYEOF' 2>/dev/null || echo "? ? ?"
import json,sys,os
d,mid=sys.argv[1],sys.argv[2]
def load(f):
    try: return json.load(open(os.path.join(d,f)))["models"]
    except Exception: return {}
sp=load("model-speed.json").get(mid) or {}
it=load("model-intel.json").get(mid) or {}
print(f"{sp.get('ttftMs','?')} {sp.get('tokS','?')} {it.get('intelligence','?')}")
PYEOF
}

# every model whose tag set CONTAINS all of $1 (comma list), fastest measured first
# Emits: <sortkey>\t<model>\t<tags>\t<ttft>\t<tps>\t<intel>, best first.
# RANK=ttft -> lowest first. RANK=tps -> highest first (negated to keep one
# sort). An UNMEASURED value sorts LAST on either axis rather than bluffing.
rank_label() {
  case "${RANK:-ttft}" in
    tps)   echo "tokens/sec, highest first" ;;
    intel) echo "Artificial Analysis Intelligence Index, highest first" ;;
    *)     echo "time to first token, lowest first" ;;
  esac
}

registry_match() {
  local want="$1" mid tags ok t key ttft tps iq sp
  printf '%s\n' "$MODEL_REGISTRY" | while IFS='|' read -r mid tags; do
    [ -n "$mid" ] || continue
    ok=1
    for t in ${want//,/ }; do
      case ",$tags," in *",$t,"*) : ;; *) ok=0 ;; esac
    done
    [ "$ok" = 1 ] || continue
    sp="$(speed_of "$mid")"
    ttft="$(printf '%s' "$sp" | cut -d' ' -f1)"
    tps="$(printf '%s' "$sp" | cut -d' ' -f2)"
    iq="$(printf '%s' "$sp" | cut -d' ' -f3)"
    case "${RANK:-ttft}" in
      tps)   case "$tps"  in '?') key=999999 ;; *) key=$(( 100000 - tps )) ;; esac ;;
      # intelligence is a decimal (e.g. 50.8); scale by 10 for integer sort
      intel) case "$iq"   in '?') key=999999 ;; *) key=$(( 100000 - ${iq%%.*} * 10 - 0 )) ;; esac ;;
      *)     case "$ttft" in '?') key=999999 ;; *) key="$ttft" ;; esac ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$key" "$mid" "$tags" "$ttft" "$tps" "$iq"
  done | sort -n
}

# ── aliases ───────────────────────────────────────────────────────────────
# Short names for the models actually reached for here. Anything not listed is
# passed through verbatim, so a full OpenRouter id always works.
alias_of() {
  case "$1" in
    # ── frontier ──────────────────────────────────────────────────────────
    opus)            echo "anthropic/claude-opus-5" ;;
    sonnet)          echo "anthropic/claude-sonnet-5" ;;
    haiku)           echo "anthropic/claude-haiku-4.5" ;;
    astra)           echo "openai/gpt-6-astra" ;;
    astra-pro|pro)   echo "openai/gpt-6-astra-pro" ;;
    gpt)             echo "openai/gpt-5.2" ;;
    grok)            echo "x-ai/grok-4.5" ;;
    gemini)          echo "google/gemini-3.1-pro-preview" ;;
    # ── measured latency, n=5-7, sequential, unique prompts, p50 of the
    #    door's own server-timing `data` phase (2026-09-20) ────────────────
    #      gemini-3.5-flash-lite 894ms | gpt-5.2  900ms | haiku-4.5 981ms
    #      minimax-m3           1182ms | grok-4.5 1348 | kimi-k3   1575
    #      sonnet-5             1587ms | astra    1685 | opus-5    1953
    #      glm-5.3              2455ms (min 1396, max 7050 — high variance)
    #    gpt-5.2 is the find: frontier intelligence at flash-lite latency.
    fast)            echo "google/gemini-3.5-flash-lite" ;;
    best)            echo "openai/gpt-5.2" ;;
    # Cerebras DIRECT (api.cerebras.ai via CEREBRAS_API_KEY, never OpenRouter).
    # WORKED twice on 2026-09-20 at ~1.6s, then failed 8/8 with channels_500 —
    # quota or rate limit, not a broken code path. Re-probe before reaching for it.
    cerebras)        echo "cerebras/gpt-oss-120b" ;;
    # ── gemini flash — 1M ctx, cents ──────────────────────────────────────
    flash)           echo "google/gemini-3.8-flash" ;;
    flash-lite)      echo "google/gemini-3.5-flash-lite" ;;
    # ── fast Chinese ──────────────────────────────────────────────────────
    kimi|k3)         echo "moonshotai/kimi-k3" ;;
    kimi-code)       echo "moonshotai/kimi-k2.7-code" ;;
    glm)             echo "z-ai/glm-5.3" ;;
    glm-flash)       echo "z-ai/glm-5.3-flash" ;;
    qwen)            echo "qwen/qwen3.8-max-0902" ;;
    qwen-flash)      echo "qwen/qwen3.8-flash" ;;
    deepseek|ds)     echo "deepseek/deepseek-v4-pro" ;;
    deepseek-flash)  echo "deepseek/deepseek-v4-flash" ;;
    minimax)         echo "minimax/minimax-m3" ;;
    ling)            echo "inclusionai/ling-3.0-flash" ;;
    seed)            echo "bytedance-seed/seed-2-1-turbo" ;;
    hunyuan)         echo "tencent/hy3" ;;
    *)               echo "$1" ;;
  esac
}
# Every alias above is checked against OpenRouter's LIVE catalog by `--list`.
# Run it after any edit here: ids rot, and three of the first thirteen written
# for this file were already dead on the day they were written.
ALIASES="opus sonnet haiku astra astra-pro gpt grok gemini fast best flash flash-lite \
kimi kimi-code glm glm-flash qwen qwen-flash deepseek deepseek-flash minimax ling seed hunyuan"

api_key() {
  [ -n "${ONEIE_API_KEY:-}" ] && { printf '%s' "$ONEIE_API_KEY"; return; }
  python3 - <<'PY'
import json,sys
try: d=json.load(open(f"{__import__('os').path.expanduser('~')}/.claude.json"))
except Exception: sys.exit(0)
def w(o):
    if isinstance(o,dict):
        for k,v in o.items():
            if k=='mcpServers' and isinstance(v,dict):
                for n,c in v.items():
                    if n=='oneie':
                        print((c.get('env') or {}).get('ONEIE_API_KEY',''),end=''); sys.exit(0)
            else: w(v)
    elif isinstance(o,list):
        for i in o: w(i)
w(d)
PY
}
KEY="$(api_key)"
[ -n "$KEY" ] || die "m: no ONE credential. Set ONEIE_API_KEY, or configure the oneie MCP server in ~/.claude.json."

post() { # post <receiver> <json-file>  → body on stdout, http code on fd 3
  curl -s -o /dev/stdout -w '\n%{http_code}' --max-time "${M_TIMEOUT:-900}" \
    "$API/api/ask/$1" -H "Authorization: Bearer $KEY" \
    -H 'Content-Type: application/json' -d @"$2"
}

# ── the caller's slug ─────────────────────────────────────────────────────
# `runAgent` does requireSlug(ctx) = ctx.ownerSlug with NO authority walk, and a
# world key's ownerSlug IS its actor id, never a workspace
# (workflow-crud-receivers.ts:919). Publishing to the wrong slug therefore
# SUCCEEDS (publish walks authority and may well permit it) and then agent:run
# answers persona_not_found. So the door itself is the arbiter, never a guess:
# a candidate is accepted only when agent:run stops saying persona_not_found.
# The probe persona is pinned to a NONEXISTENT model on purpose — a correct slug
# then fails at the provider (channels_500) instead of buying a model call, so
# resolution is free.
probe_slug() {
  local s="$1" body
  python3 -c "
import json,sys
json.dump({'slug':sys.argv[1],'name':'m-probe','content':'---\nname: m-probe\nmodel: probe/nonexistent-'+sys.argv[1]+'\n---\nprobe\n'},open(sys.argv[2],'w'))" "$s" "$CACHE/.probe.json"
  curl -s --max-time 60 "$API/api/agents/publish" -H "Authorization: Bearer $KEY" \
    -H 'Content-Type: application/json' -d @"$CACHE/.probe.json" >/dev/null 2>&1
  printf '{"data":{"actorId":"m-probe","instructions":"x"}}' > "$CACHE/.proberun.json"
  body="$(curl -s --max-time 120 "$API/api/ask/agent:run" -H "Authorization: Bearer $KEY" \
    -H 'Content-Type: application/json' -d @"$CACHE/.proberun.json")"
  curl -s --max-time 60 -X DELETE "$API/api/agents/publish?slug=$s&name=m-probe" \
    -H "Authorization: Bearer $KEY" >/dev/null 2>&1
  case "$body" in *persona_not_found*) return 1 ;; *) return 0 ;; esac
}

resolve_slug() {
  # An explicit ONE_SLUG is taken as asserted AND cached, so it is needed once
  # rather than on every call.
  [ -n "${ONE_SLUG:-}" ] && { printf '%s' "$ONE_SLUG" > "$CACHE/slug"; printf '%s' "$ONE_SLUG"; return; }
  [ -s "$CACHE/slug" ] && { cat "$CACHE/slug"; return; }
  note "m: resolving the caller's workspace slug (once; cached at $CACHE/slug)…"
  local cands="" hash db
  hash="$(printf '%s' "$KEY" | shasum -a 256 | cut -d' ' -f1)"
  db="$(ls -t "$(git rev-parse --show-toplevel 2>/dev/null)"/one.ie/web/.wrangler/state/v3/d1/miniflare-D1DatabaseObject/*.sqlite 2>/dev/null | head -1)"
  # Two queries, not a UNION: SQLite refuses `ORDER BY COUNT(*)` in a compound
  # SELECT ("1st ORDER BY term does not match any column in the result set"),
  # and a failed lookup here is silent — it just yields no candidates.
  # Exact hash first (this key), then the busiest actors as fallbacks, because
  # the local D1 is a STALE sync and a recently minted key is simply absent.
  if [ -n "$db" ]; then
    cands="$(sqlite3 "$db" "SELECT actor_id FROM world_keys WHERE key_hash='$hash';" 2>/dev/null)
$(sqlite3 "$db" "SELECT actor_id FROM world_keys GROUP BY actor_id ORDER BY COUNT(*) DESC LIMIT 6;" 2>/dev/null)"
  fi
  cands="$(printf '%s\n' $cands | awk 'NF && !seen[$0]++')"
  [ -n "$cands" ] || note "m: no candidate slugs from the local D1 ($db)"
  local s
  for s in $cands; do
    if probe_slug "$s"; then printf '%s' "$s" > "$CACHE/slug"; note "m: slug = $s"; printf '%s' "$s"; return; fi
  done
  die "m: could not resolve the caller's slug.
     Override it:  ONE_SLUG=<slug> $0 …
     Or find it:   sqlite3 <local D1>.sqlite \\
                     \"SELECT actor_id FROM world_keys WHERE key_hash='$hash';\"
     (the local D1 is a STALE sync — a key minted since the last db:sync is absent)"
}

# ── does the live door honour a per-call `model`? ──────────────────────────
# agent:run gained `model` so a caller no longer has to MINT AN AGENT to change
# model (8.7s on a model's first use, against 1.3s warm). Until that ships, the
# field is STRIPPED BY ZOD and the turn silently runs the persona's own model —
# which is the dangerous failure, not a loud one: you would get a confident
# answer from the wrong model.
#
# So this never assumes. It probes with a NONEXISTENT model id against a real
# persona: a door that honours the field fails at the provider, a door that
# ignores it answers happily. Same control that proved which model was running
# in the first place. Cached; `rm $CACHE/model-param` re-probes.
model_param_supported() {
  [ -s "$CACHE/model-param" ] && { [ "$(cat "$CACHE/model-param")" = yes ]; return; }
  local r
  r="$(curl -s --max-time 120 "$API/api/ask/agent:run" -H "Authorization: Bearer $KEY" \
       -H 'Content-Type: application/json' \
       -d '{"data":{"actorId":"ceo","model":"probe/nonexistent-model-xyz","prompt":"Reply: A"}}' 2>/dev/null)"
  case "$r" in
    *'"ok":true'*) printf no  > "$CACHE/model-param"; return 1 ;;   # field ignored
    *'error'*)     printf yes > "$CACHE/model-param"; return 0 ;;   # field reached the provider
    *)             return 1 ;;                                      # unreachable: assume not
  esac
}

# ── one passthrough persona per model, minted once ────────────────────────
# The persona body never changes, so the persona KV cache
# (persona:{slug}:{agentId}) serving a warm copy is harmless here. `/run` also
# appends the workspace soul suffix and a no-tools notice to every system
# prompt — this is a thin passthrough, not a bare model.
persona_for() {
  local model="$1" slug="$2" id
  if [ "$model" = "__passthrough" ]; then id="m-passthrough"; else
  id="m-$(printf '%s' "$model" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-' '-' | sed 's/--*/-/g;s/-$//')"; fi
  [ -f "$CACHE/personas/$id" ] && { printf '%s' "$id"; return; }
  python3 -c "
import json,sys
m,i=sys.argv[1],sys.argv[2]
# The shared passthrough declares NO model: every call names its own.
mline = '' if m == '__passthrough' else f'model: {m}\n'
body=f'''---
name: {i}
description: Passthrough for .claude/scripts/m.sh.
{mline}---

Answer the request you are given, fully and directly. You have no persona and no
house style to maintain. Do not preface your answer, do not restate the request,
and do not close with an offer of further help.
'''
json.dump({'slug':sys.argv[3],'name':i,'content':body},open(sys.argv[4],'w'))" \
    "$model" "$id" "$slug" "$CACHE/.pub.json"
  local r; r="$(curl -s --max-time 60 "$API/api/agents/publish" -H "Authorization: Bearer $KEY" \
    -H 'Content-Type: application/json' -d @"$CACHE/.pub.json")"
  case "$r" in *'"key"'*) : ;; *) die "m: could not mint a persona for $model → $r" ;; esac
  printf '%s' "$model" > "$CACHE/personas/$id"
  note "m: minted persona $id → $model"
  printf '%s' "$id"
}

# ── args ──────────────────────────────────────────────────────────────────
MODELS=(); FILES=(); SYSTEM=""; OUT=""; RAW=0; PROMPT=""; FRESH=0; TAGS=""; RANK="${RANK:-ttft}"
set +u  # bash 3.2: ${#EMPTY[@]} is "unbound" under set -u
usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; cat >&2 <<'U'

  -m, --model ID|alias   model (default: kimi). Any OpenRouter id works.
      --models a,b,c     fan out to several models in parallel
  -f, --file PATH        attach a file (repeatable)
  -s, --system TEXT      extra system instruction
  -o, --out PATH         write the answer to a file (fan-out: PATH.<model>)
      --json             print the raw response envelope
      --fresh            bypass the answer cache and re-ask (--no-cache)
      --tags a,b         ROUTE: run on the fastest model carrying every tag
      --rank ttft|tps|intel  which axis --tags ranks on. `intel` is the
                         Artificial Analysis Intelligence Index. ttft (default) = time to
                         FIRST token, for short interactive answers. tps = for
                         generation; ranking a long job by ttft misses by 5x.
      --filter a,b       list the models carrying every tag, with live price
                         tags: open frontier fast cheap long code reason cn vision
      --list             show aliases, checked against OpenRouter's live list
      --gc               delete every persona this script has minted
      --slug SLUG        override the caller's workspace slug

  stdin is read when piped. Truncation is UNDETECTABLE on this transport —
  the character count is printed to stderr and nothing here claims an answer
  is complete.
U
exit 0; }

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--model)  MODELS+=("$(alias_of "$2")"); shift 2 ;;
    --models)    IFS=, read -ra _ms <<< "$2"; for _m in "${_ms[@]}"; do MODELS+=("$(alias_of "$_m")"); done; shift 2 ;;
    -f|--file)   FILES+=("$2"); shift 2 ;;
    -s|--system) SYSTEM="$2"; shift 2 ;;
    -o|--out)    OUT="$2"; shift 2 ;;
    --slug)      export ONE_SLUG="$2"; shift 2 ;;
    --json)      RAW=1; shift ;;
    --tags)      TAGS="$2"; shift 2 ;;
    --rank)      RANK="$2"; shift 2 ;;
    --filter)
      want="$2"
      note "models tagged [$want], ranked by $RANK ($(rank_label); ? = never measured, sorts last):"
      live="$(curl -s --max-time 30 https://openrouter.ai/api/v1/models | python3 -c "
import json,sys
for m in json.load(sys.stdin)['data']:
    p=m['pricing']
    print('%s %s %s %s' % (m['id'], float(p['prompt'])*1e6, float(p['completion'])*1e6, m.get('context_length') or 0))")"
      printf '  %-32s %8s %7s %6s %15s %7s  %s\n' MODEL ttft tok/s AAiq '$in/$out per M' ctx TAGS
      registry_match "$want" | while IFS=$'\t' read -r _k mid tags t tp iq; do
        pr="$(printf '%s\n' "$live" | awk -v m="$mid" '$1==m{printf "$%.2f/$%.2f", $2, $3}')"
        cx="$(printf '%s\n' "$live" | awk -v m="$mid" '$1==m{printf "%dk", $4/1000}')"
        [ "$t" = '?' ] || t="${t}ms"
        printf '  %-32s %8s %7s %6s %15s %7s  %s\n' "$mid" "$t" "$tp" "$iq" "${pr:--}" "${cx:--}" "$tags"
      done
      exit 0 ;;
    --fresh|--no-cache) FRESH=1; shift ;;
    -h|--help)   usage ;;
    --list)
      note "aliases, checked against OpenRouter's live model list:"
      live="$(curl -s --max-time 30 https://openrouter.ai/api/v1/models | python3 -c "
import json,sys; print(' '.join(m['id'] for m in json.load(sys.stdin)['data']))")"
      for a in $ALIASES; do
        id="$(alias_of "$a")"
        case "$id" in
          groq/*|cerebras/*|fireworks/*)
            printf '  direct  %-12s %s\n' "$a" "$id"; continue ;;
        esac
        case " $live " in *" $id "*) printf '  live    %-12s %s\n' "$a" "$id" ;;
                          *)          printf '  MISSING %-12s %s\n' "$a" "$id" ;; esac
      done
      exit 0 ;;
    --gc)
      slug="$(resolve_slug)"
      n=0; for p in "$CACHE"/personas/*; do [ -e "$p" ] || continue; id="$(basename "$p")"
        curl -s --max-time 60 -X DELETE "$API/api/agents/publish?slug=$slug&name=$id" \
          -H "Authorization: Bearer $KEY" >/dev/null
        rm -f "$p"; note "removed $id"; n=$((n+1)); done
      c=$(ls -1 "$CACHE/out" 2>/dev/null | wc -l | tr -d " "); rm -f "$CACHE"/out/*
      note "m: removed $n persona(s) and $c cached answer(s)"; exit 0 ;;
    --) shift; PROMPT="$PROMPT $*"; break ;;
    *)
      # The FIRST bare word is a model when it is a known alias or looks like an
      # OpenRouter id (`vendor/model`). Everything after it is prompt.
      # Without this, `m astra "hi"` put the word "astra" in the PROMPT and ran
      # the DEFAULT model, which then role-played as Astra and read exactly like
      # success — measured 2026-09-20. A positional model must bind to the model.
      if [ ${#MODELS[@]} -eq 0 ] && [ -z "$PROMPT" ]; then
        case " $ALIASES " in
          *" $1 "*) MODELS+=("$(alias_of "$1")"); shift; continue ;;
        esac
        case "$1" in */*) MODELS+=("$1"); shift; continue ;; esac
      fi
      PROMPT="$PROMPT $1"; shift ;;
  esac
done
# THE ROUTER. Tags in, one model out: every model carrying ALL the requested
# tags, ranked by measured ttft, and the fastest wins. An unmeasured model
# (`?`) sorts last rather than bluffing. The pick and its runners-up are always
# printed, because a router that will not say why it chose is not auditable.
if [ -n "$TAGS" ] && [ ${#MODELS[@]} -eq 0 ]; then
  _pick="$(registry_match "$TAGS" | head -1)"
  [ -n "$_pick" ] || die "m: no model carries every tag in [$TAGS]. See: $0 --filter <tags>"
  _mid="$(printf '%s' "$_pick" | cut -f2)"
  _tt="$(printf '%s' "$_pick" | cut -f4)"; _tp="$(printf '%s' "$_pick" | cut -f5)"
  _iq="$(printf '%s' "$_pick" | cut -f6)"
  MODELS=("$_mid")
  note "m: routed [$TAGS] by $RANK -> $_mid (ttft ${_tt}ms, ${_tp} tok/s, AA ${_iq})$(registry_match "$TAGS" | sed -n '2,3p' | cut -f2 | tr '\n' ' ' | sed 's/^/  runners-up: /;s/ $//')"
fi
[ ${#MODELS[@]} -eq 0 ] && MODELS=("$DEFAULT_MODEL")
PROMPT="${PROMPT# }"
STDIN=""; [ ! -t 0 ] && STDIN="$(cat)"
[ -n "$PROMPT$STDIN${#FILES[@]}" ] || usage

SLUG="$(resolve_slug)"
[ -n "$SLUG" ] || exit 1

# The answer cache is keyed on EVERYTHING that can change the answer — model,
# system, prompt, stdin, and the BYTES of every attached file — so a hit can
# never be another question's answer. Only a SUCCESSFUL answer is stored; a
# failure must never be served back as one.
# The trade, stated: the same question returns the same words until --fresh.
# That is what you want while iterating on a document, and wrong when you want
# the answer re-rolled.
cache_key() {
  { printf '%s\0%s\0%s\0%s\0' "$1" "$SYSTEM" "$PROMPT" "$STDIN"
    for f in ${FILES[@]+"${FILES[@]}"}; do printf '%s\0' "$f"; cat "$f" 2>/dev/null; done
  } | shasum -a 256 | cut -c1-32
}

run_one() { # run_one <model> <outfile>
  local model="$1" dest="$2" id t0 t1 body ck cf age
  ck="$(cache_key "$model")"; cf="$CACHE/out/$ck"
  if [ "$FRESH" -eq 0 ] && [ -s "$cf" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$cf" 2>/dev/null || echo 0) ))
    cp "$cf" "$dest"
    note "m: $model — $(wc -c <"$cf" | tr -d ' ') chars, CACHED ${age}s ago (--fresh to re-ask)"
    return 0
  fi
  # FAST PATH: name the model on the call, reuse ONE shared persona, mint
  # nothing. SLOW PATH (door not yet deployed): a persona per model.
  local pass_model=""
  if model_param_supported; then
    id="$(persona_for "__passthrough" "$SLUG")" || return 1
    pass_model="$model"
  else
    id="$(persona_for "$model" "$SLUG")" || return 1
  fi
  python3 - "$id" "$SYSTEM" "$PROMPT" "$STDIN" "$CACHE/.body.$id.$$.json" "$pass_model" ${FILES[@]+"${FILES[@]}"} <<'PY'
import json,sys,os
aid,system,prompt,stdin,dest,model=sys.argv[1:7]
data={"actorId":aid}
if model: data["model"]=model
if system: data["instructions"]=system
inp={}
if prompt: inp["prompt"]=prompt
if stdin:  inp["input"]=stdin
files={}
for p in sys.argv[7:]:
    try: files[os.path.basename(p)]=open(p,encoding='utf-8',errors='replace').read()
    except Exception as e: print(f"m: cannot read {p}: {e}",file=sys.stderr); sys.exit(2)
if files: inp["files"]=files
data.update(inp)
json.dump({"data":data},open(dest,'w'))
PY
  [ $? -eq 0 ] || return 1
  t0=$(date +%s)
  body="$(curl -s --max-time "${M_TIMEOUT:-900}" "$API/api/ask/agent:run" \
    -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
    -d @"$CACHE/.body.$id.$$.json")"
  t1=$(date +%s)
  printf '%s' "$body" > "$dest.raw"
  python3 - "$dest.raw" "$dest" "$model" "$((t1-t0))" "$RAW" <<'PY'
import json,sys
raw,dest,model,secs,rawmode=sys.argv[1:6]
try: d=json.load(open(raw))
except Exception: print(f"m: {model}: unparseable response",file=sys.stderr); sys.exit(1)
if rawmode=="1":
    open(dest,'w').write(json.dumps(d,indent=1)); print(f"m: {model} — raw envelope, {secs}s",file=sys.stderr); sys.exit(0)
r=d.get("result") or {}
if not r.get("ok"):
    print(f"m: {model} FAILED — {r.get('error') or d.get('reason') or d}",file=sys.stderr); sys.exit(1)
t=r.get("text") or ""
open(dest,'w').write(t)
print(f"m: {model} — {len(t)} chars, {secs}s (truncation is undetectable on this transport)",file=sys.stderr)
PY
  [ $? -eq 0 ] && [ -s "$dest" ] && cp "$dest" "$cf"
  return 0
}

if [ ${#MODELS[@]} -eq 1 ]; then
  d="$CACHE/.out.$$"; run_one "${MODELS[0]}" "$d" || exit 1
  if [ -n "$OUT" ]; then cp "$d" "$OUT"; note "m: → $OUT"; else cat "$d"; fi
else
  note "m: fanning out to ${#MODELS[@]} models in parallel…"
  pids=(); outs=()
  for m in "${MODELS[@]}"; do
    d="$CACHE/.out.$$.$(printf '%s' "$m" | tr -c 'a-z0-9' '-')"
    outs+=("$d|$m"); run_one "$m" "$d" & pids+=("$!")
  done
  for p in "${pids[@]}"; do wait "$p"; done
  for om in "${outs[@]}"; do
    d="${om%%|*}"; m="${om##*|}"; [ -s "$d" ] || continue
    if [ -n "$OUT" ]; then cp "$d" "$OUT.$(printf '%s' "$m" | tr / -)"; note "m: → $OUT.$(printf '%s' "$m" | tr / -)"
    else printf '\n===== %s =====\n' "$m"; cat "$d"; fi
  done
fi
