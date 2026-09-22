#!/usr/bin/env bash
# key-seat.sh — one seat of the lean key meeting, on a NON-Claude model, posted to the row.
#
# manifest: needs-env   (reads OPENROUTER_API_KEY and GATEWAY_API_KEY from one.ie/web/.dev.vars,
#                        or the shell; ONE_ENV_FILE / DO_ENV_FILE override the file)
#
# WHY. Tony 2026-09-20: different models evaluate each other, and no model grades its own
# work. Kimi (CTO) writes the spec, Astra (security) reviews it and later refutes the diff,
# Kimi second-reads the refutation. Those seats have no filesystem — they read what this
# script hands them and answer on the ROW (tasks:comment), never in the thread. Every
# comment opens with the model id so the row shows who said what.
#
#   key-seat.sh <seat> <tid> <context-file> [diff-file]
#     seat  = cto | review | refute | second        (model is fixed per seat below)
#     tid   = task:<24hex>
#     context-file = the row's notes (KEY · WHY · FILES · INVARIANT … block) as text
#     diff-file    = `git diff` output (refute/second only)
#
# Exit 0 = comment posted and read back; 2 = model call failed; 3 = post failed.
# The comment is capped at 1800 chars and SAYS SO when it was cut (tasks:comment silently
# truncates at 4000 — we never get near it, and never silently).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENVF="${ONE_ENV_FILE:-${DO_ENV_FILE:-$ROOT/one.ie/web/.dev.vars}}"
_var() { local v="${!1:-}"; [ -n "$v" ] && { echo "$v"; return; }; grep -E "^$1=" "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'; }
OR_KEY="$(_var OPENROUTER_API_KEY)"; GW_KEY="$(_var GATEWAY_API_KEY)"
[ -n "$OR_KEY" ] && [ -n "$GW_KEY" ] || { echo "key-seat: missing OPENROUTER_API_KEY or GATEWAY_API_KEY (env or $ENVF)" >&2; exit 2; }

seat="${1:?seat}"; tid="${2:?tid}"; ctx="${3:?context-file}"; diff="${4:-}"
case "$seat" in
  cto)    model="moonshotai/kimi-k3";  role="You are the CTO. Write the SPEC for this subtask in at most 10 lines: files to touch (with the anchors given), the one invariant, the accept command, what must not break, and the single decision most likely to bite silently. No preamble." ;;
  review) model="openai/gpt-6-astra";  role="You are the security reviewer. The CTO's spec is the last comment in the context. Answer ACCEPT or AMEND in the first word, then at most 8 lines: what the spec misses that would let key material leak, an address render for an unkept key, or a frozen literal move. Quote the line you object to." ;;
  refute) model="openai/gpt-6-astra";  role="You are the security refuter. You are given the row context and a git diff. Default verdict is REFUTED. Answer PASS or REFUTED in the first word, then at most 10 lines naming file:line for each objection: key material in a fetch/URL/log/clipboard, an address rendered before a durable keep, sessionStorage treated as durable, a frozen derivation literal changed, an accept test that cannot go red. If PASS, name the one check you did not run." ;;
  second) model="moonshotai/kimi-k3";  role="You are the CTO second-reading the security refutation (the last comment) against your own spec and the diff. Answer AGREE or DISAGREE in the first word, then at most 6 lines. If DISAGREE, name the exact objection and why the diff already satisfies it." ;;
  *) echo "key-seat: unknown seat $seat" >&2; exit 2 ;;
esac

user="$(cat "$ctx")"
[ -n "$diff" ] && user="$user

=== GIT DIFF ===
$(head -c 60000 "$diff")"

body=$(python3 - "$model" "$role" "$user" <<'PY'
import json,sys
print(json.dumps({"model":sys.argv[1],"messages":[{"role":"system","content":sys.argv[2]+" Think briefly; the answer is what counts."},{"role":"user","content":sys.argv[3]}],"max_tokens":6000,"temperature":0.2,"reasoning":{"effort":"low"}}))
PY
)
resp=$(curl -s -m 300 https://openrouter.ai/api/v1/chat/completions -H "Authorization: Bearer $OR_KEY" -H "content-type: application/json" -d "$body") || { echo "key-seat: openrouter unreachable" >&2; exit 2; }
text=$(printf '%s' "$resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); c=d.get("choices") or []; m=c[0]["message"] if c else {}; t=(m.get("content") or "").strip(); print(t if t else "")')
[ -n "$text" ] || { echo "key-seat: no answer content (reasoning consumed the budget or the call errored) — NOTHING POSTED: $(printf '%s' "$resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("error") or (d.get("choices") or [{}])[0].get("finish_reason"))' 2>/dev/null | head -c 200)" >&2; exit 2; }
usage=$(printf '%s' "$resp" | python3 -c 'import json,sys; u=json.load(sys.stdin).get("usage",{}); print(str(u.get("prompt_tokens",0))+" in / "+str(u.get("completion_tokens",0))+" out")')

comment="[$model · $seat] $text"
if [ ${#comment} -gt 1800 ]; then comment="${comment:0:1750}
… (cut at 1800 chars by key-seat.sh; full answer in the session log)"; fi
post=$(python3 - "$tid" "$comment" <<'PY'
import json,sys; print(json.dumps({"data":{"tid":sys.argv[1],"workspace":"one","body":sys.argv[2]}}))
PY
)
out=$(curl -s -m 30 -X POST https://one.ie/api/ask/tasks:comment -H "Authorization: Bearer $GW_KEY" -H "content-type: application/json" -d "$post")
printf '%s' "$out" | grep -q '"ok":true' || { echo "key-seat: post failed: $(printf '%s' "$out" | head -c 300)" >&2; exit 3; }
echo "key-seat: $seat ($model) → $tid · ${#comment} chars · $usage"
echo "$text"
