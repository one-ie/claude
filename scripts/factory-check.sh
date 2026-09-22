#!/usr/bin/env bash
# factory-check.sh — the factory's acceptance checks, against the LIVE substrate.
#
# Every check here QUERIES TypeDB. None of them greps a file for a symbol,
# because a grep passes on a symbol that is defined and never called — and the
# whole point of this promise is that "built" and "live" are different axes
# (text/vision.md). A check that cannot go red for the reason it claims to test
# is not a proof.
#
# Usage: factory-check.sh <check> [--verbose]
#   schema-live    the ladder is in the DEPLOYED thing-type @values
#   sdk-enum       the generated zod enum accepts the ladder (2nd gate)
#   tracer         ONE hand-seeded row proves schema->query->surface end to end
#   write-path     an objective row created THROUGH A RECEIVER (excludes the tracer)
#   seeded         vision.md's rows exist as objective things
#   driver         ready-tasks() returns at least one real row
#   gaps-visible   uncovered() names the dark wires — absence made visible
#   belief-guard   the belief functions refuse to gate while their edge is empty
#   fn-exposed     the factory funs are in FN_MAP and on all THREE allowlists
#   fn-entity-args fn:run can actually bind an entity param (the driver funs)
#   fn-one-allowlist  web + MCP + CLI read ONE allowlist source, not three copies
#   view-gaps      the gaps board queries the ladder AND is honest when empty
#   stream         /factory streams what is being built AND can stop it
#   walk-speed     the deterministic lifecycle walk passes, with per-stop speed budgets
#   templates      text/template-*.md teach the corrected contract; YAML ratchet holds
#   docs           plan/vision/docs no longer claim the factory is unarmed
#   all            every check above, in order
#   json           run them all and write the receipt /factory renders
#                  (one.ie/web/src/data/factory-check.json; FACTORY_RECEIPT_OUT
#                   overrides). ALWAYS exits 0 — the verdicts are inside the file.
#
# Exit: 0 = green · 1 = red (with the reason) · 3 = cannot run (no creds/reach)
#
# 1 vs 3 IS THE POINT. A red check failed for a reason you can act on; a 3 means
# the substrate was unreachable and NOTHING was proven either way. The promise's
# `proof:` && -join flattens both to non-zero, so a settle that sees non-zero
# must not assume "broken" — see text/factory.md § A note on "red" vs "cannot
# run". Never widen a `cannot run` into a `red` to make a chain simpler.
set -uo pipefail

# _GATE — route a heavy compute through the machine governor. A gate_lock only
# dedupes IDENTICAL work; a SLOT is what bounds N worktrees each running one of
# these at once (measured 2026-09-07: three concurrent 2.5GB typecheckers, every
# lock uncontended, load 171). Empty when already inside a gate, so a nested call
# inherits the outer slot rather than taking a second one.
#
# Resolves gate-run.sh from its OWN directory, deliberately: an earlier version
# keyed off $ROOT and got inserted above the line that sets it, so _GATE was
# silently empty and every call ran ungoverned -- a fail-OPEN, which is the exact
# defect this preamble exists to close.
_GATE=()
if [ "${GOVERN_IN_GATE:-0}" != "1" ]; then
  _GR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-run.sh"
  [ -f "$_GR" ] && _GATE=( bash "$_GR" "compute:$(basename "${BASH_SOURCE[0]}")" -- )
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:-all}"
VERBOSE=0; [[ "${2:-}" == "--verbose" ]] && VERBOSE=1
say() { [ $VERBOSE -eq 1 ] && echo "      $*" >&2; return 0; }
red() { echo "RED  $1" >&2; return 1; }
# A check that cannot reach its evidence is NOT red — red sends someone to fix
# the build, cannot-run sends them to fix the environment. Returns 3 so a single
# -check invocation (what a promise `accept:` runs) keeps the distinction.
cannot() { echo "CANNOT RUN: $1" >&2; return 3; }

# ── receipt (json mode) ───────────────────────────────────────────────────
# The /factory board renders THIS FILE, never a shell-out: the page runs on
# Workers, which cannot fork a process, and a board that re-ran thirteen network
# checks per request would be its own outage. One source of truth for the
# verdicts — the checker — and a static receipt the page reads.
#
# Reasons are sanitized HERE, not on the page. A cannot-run reason that carried
# $TYPEDB_URL would put infrastructure on a public page, and a page-side scrub
# would arrive after the value was already committed to disk in this receipt.
# The sanitizer is python (literal str.replace), NOT sed: a password carrying a
# sed metacharacter would kill the pipeline, and with pipefail-but-no-errexit the
# reason would silently come back empty — thirteen rows with no reasons, which is
# exactly the deliverable failing quietly.
#
# Exit is ALWAYS 0 in json mode: writing a receipt is not a verdict. The verdicts
# live inside it. A caller that wants a verdict runs a check by name.
CHECK_ORDER="schema-live sdk-enum tracer write-path seeded driver gaps-visible belief-guard fn-exposed fn-entity-args fn-one-allowlist view-gaps stream walk-speed templates docs"
RECEIPT_OUT="${FACTORY_RECEIPT_OUT:-$ROOT/one.ie/web/src/data/factory-check.json}"

json_str() { python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().strip()))'; }
# NOTE: sanitize takes the reason as $1, NOT piped stdin. `python3 - <<HEREDOC`
# makes the heredoc BE stdin (the script text) — a second, piped stdin never
# reaches sys.stdin.read() underneath it, so the reason silently comes back
# empty. Passing it base64-encoded through argv sidesteps both that trap and
# any shell-metacharacter risk in a raw reason string reaching argv unescaped.
sanitize() {
  local b64; b64=$(printf '%s' "$1" | base64 | tr -d '\n')
  python3 - "$ROOT" "${TYPEDB_URL:-}" "${TYPEDB_PASSWORD:-}" "${TOK:-}" "$b64" <<'PY'
import base64,re,sys
root,url,pw,tok,b64 = sys.argv[1:6]
s = base64.b64decode(b64).decode('utf-8', 'replace').strip()
for needle,repl in ((url,'<substrate>'),(pw,'<redacted>'),(tok,'<redacted>'),(root+'/','')):
    if needle: s = s.replace(needle, repl)
print(re.sub(r'^(RED\s+|CANNOT RUN:\s*)','',s))
PY
}
# `source` names the RAIL, not just the tool. A board of sixteen green rows means
# something different depending on whether they were answered by TypeDB Cloud or
# by a container on the operator's laptop, and this whole promise exists to stop
# those two being read as the same claim. Host only — never the credentials,
# which is why this is derived here rather than printing $TYPEDB_URL.
emit_receipt() {
  local rail host
  host=$(printf '%s' "${TYPEDB_URL:-}" | sed -E 's#^[a-z]+://##; s#[:/].*##')
  case "$host" in
    ''|localhost|127.0.0.1) rail="local substrate" ;;
    *)                      rail="cloud substrate ${host%%.*}" ;;
  esac
  mkdir -p "$(dirname "$RECEIPT_OUT")"
  printf '{\n  "generated_at": "%s",\n  "source": "factory-check.sh json · %s",\n  "checks": [\n%s\n  ]\n}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rail" "$1" > "$RECEIPT_OUT"
  echo "receipt: $RECEIPT_OUT ($rail)" >&2
}
receipt_all_cannot_run() {
  local body="" c r; r=$(printf '%s' "$1" | json_str)
  for c in $CHECK_ORDER; do
    [ -n "$body" ] && body="$body,"$'\n'
    body="$body    {\"name\": \"$c\", \"state\": \"cannot-run\", \"reason\": $r}"
  done
  emit_receipt "$body"
}
run_receipt() {
  local body="" c out rc state reason
  for c in $CHECK_ORDER; do
    out=$("check_${c//-/_}" 2>&1 >/dev/null); rc=$?
    case $rc in
      0) state="ok";         reason="" ;;
      3) state="cannot-run"; reason="$(sanitize "$out")" ;;
      *) state="red";        reason="$(sanitize "$out")" ;;
    esac
    [ "$state" != "ok" ] && [ -z "$reason" ] && reason="no reason reported"
    [ -n "$body" ] && body="$body,"$'\n'
    body="$body    {\"name\": \"$c\", \"state\": \"$state\", \"reason\": $(printf '%s' "$reason" | json_str)}"
  done
  emit_receipt "$body"
}

# ── creds ─────────────────────────────────────────────────────────────────
# Only the checks that QUERY the production graph need a cluster. `templates`
# and `docs` read files; `belief-guard` (rewritten 2026-07-28) proves a wire
# against a SCRATCH database, never `one`. Signing in for those turned a
# perfectly answerable file check into `CANNOT RUN` during the 2026-07-28
# TypeDB outage — an availability dependency the check never actually had.
# `all`/`json` still sign in: most of their checks need it.
# Verified by inspection 2026-07-28: these call no q(), so a cluster outage must
# not turn an answerable file check into CANNOT RUN. Re-verify with:
#   sed -n "/^check_<name>()/,/^}/p" $0 | grep -c 'q '
case "$MODE" in
  templates|docs|belief-guard|sdk-enum|fn-exposed|fn-entity-args|fn-one-allowlist|view-gaps|stream|walk-speed) NEEDS_CLUSTER=0 ;;
  *)                                                                              NEEDS_CLUSTER=1 ;;
esac

# NOT `set -a && . .env` — that file carries a hyphenated key and an unquoted
# value, so sourcing it aborts the shell. Pull only what we need.
#
# PARSING is unconditional; only the SIGN-IN is gated on NEEDS_CLUSTER. Reading a
# local file has no availability dependency — that was never the thing an outage
# broke. Gating the parse too left `belief-guard` (NEEDS_CLUSTER=0, but it hands
# TYPEDB_URL to vitest) with an unset variable, which under `set -u` aborted the
# check and surfaced as a RED about the evidence wire.
eval "$(python3 - "$ROOT/one.ie/web/.env" <<'PY'
import re,sys,shlex
for line in open(sys.argv[1], errors="replace"):
    m = re.match(r'^\s*(TYPEDB_(?:URL|DATABASE|USERNAME|PASSWORD))\s*=\s*(.*?)\s*$', line)
    if m: print(f"{m.group(1)}={shlex.quote(m.group(2).strip(chr(34)+chr(39)))}")
PY
)"
: "${TYPEDB_URL:=}" "${TYPEDB_DATABASE:=}" "${TYPEDB_USERNAME:=}" "${TYPEDB_PASSWORD:=}" "${TOK:=}"

if [ "$NEEDS_CLUSTER" = 1 ]; then
if [ -z "$TYPEDB_URL" ]; then
  [ "$MODE" = json ] && { receipt_all_cannot_run "no substrate credentials in this environment"; exit 0; }
  echo "CANNOT RUN: no TYPEDB_URL in one.ie/web/.env" >&2; exit 3
fi

# Same retry contract as q(). A cloud sign-in is the single point every clustered
# check hangs off, and it is BOTH flaky and slow: measured 2026-07-29, a cold auth
# against TypeDB Cloud took 4.1s, and a single-shot attempt reported "TypeDB signin
# failed" while the very next invocation authenticated fine. One transient blip here
# turns every substrate check in the run into a cannot-run — an infrastructure
# verdict pronounced on one dropped request. -m 30, not 15, for the cold case.
for attempt in 1 2 3; do
  TOK=$(curl -s -m 30 -X POST "$TYPEDB_URL/v1/signin" -H 'Content-Type: application/json' \
    -d "{\"username\":\"$TYPEDB_USERNAME\",\"password\":\"$TYPEDB_PASSWORD\"}" \
    | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))' 2>/dev/null)
  [ -n "$TOK" ] && break
  [ "$attempt" -lt 3 ] && sleep "$attempt"
done
if [ -z "$TOK" ]; then
  [ "$MODE" = json ] && { receipt_all_cannot_run "substrate unreachable — sign-in failed"; exit 0; }
  echo "CANNOT RUN: TypeDB signin failed at $TYPEDB_URL" >&2; exit 3
fi
fi   # NEEDS_CLUSTER

# read-transaction query → raw JSON on stdout
#
# RETRIES, because the code this repo already ships retries. src/lib/substrate.ts
# documents its own RETRYABLE set — {404, 429, 502, 503, 504} — with the note that
# TypeDB Cloud "intermittently answers a perfectly valid query with 404 page not
# found, observed twice in ~60 requests (≈3%), non-deterministic: the SAME query
# string that 404s succeeds on the next attempt."
#
# This checker talks to the cluster DIRECTLY rather than through that helper, so
# it inherited none of it. At ~3% per query and ~10 queries in an `all` run, the
# odds of at least one spurious failure are ~26% — and measured 2026-07-29 that is
# exactly what happened: `all` reported four checks as CANNOT RUN against
# production, and every one of those four queries answered first-try when run
# individually seconds later. Three earlier cloud attempts were written up as
# substrate outages on this same evidence. Two of them were up-windows.
#
# Read-only by construction (transactionType is hardcoded "read"), so retrying a
# 404 carries none of the non-idempotency risk substrate.ts scopes out for writes.
# Backoff matches substrate.ts: 500ms then 1000ms.
q() {
  python3 - "$1" "$TYPEDB_DATABASE" > /tmp/fc-q.json <<'PY'
import json,sys
print(json.dumps({"databaseName":sys.argv[2],"transactionType":"read","query":sys.argv[1]}))
PY
  local body code attempt
  for attempt in 1 2 3; do
    body=$(curl -s -m 60 -w $'\n%{http_code}' -X POST "$TYPEDB_URL/v1/query" \
             -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
             --data-binary @/tmp/fc-q.json)
    code="${body##*$'\n'}"; body="${body%$'\n'*}"
    case "$code" in
      404|429|502|503|504|000|"") [ "$attempt" -lt 3 ] && { sleep "0.$((attempt*5))"; continue; } ;;
    esac
    printf '%s' "$body"; return 0
  done
  printf '%s' "$body"
}
rows() { python3 -c '
import sys,json
try:
    d=json.load(sys.stdin)
    a=d.get("answers") or d.get("data") or []
    print(len(a) if isinstance(a,list) else 0)
except Exception: print(0)'; }

# extracts the numeric value from a `reduce $n = count(...)` answer row —
# TypeDB 3.x has no `return count($x)` (TQL03 syntax error); `reduce` is the
# only aggregate form, and it always answers ONE row holding the value, so
# rows() (which counts answer rows) reports 1-or-0 regardless of the count.
# val prints the reduce VALUE, or the literal string ERR when the response is not a
# readable answer envelope.
#
# It used to `except Exception: print(0)`. That made a 503 body, an HTML error page,
# a dropped connection and a genuine count of zero ALL indistinguishable — and every
# caller reads 0 as "empty", so an unreachable substrate reported RED. That is the
# red-vs-cannot-run confusion this promise exists to eliminate, living inside the
# checker that polices it. (Same trap the gaps board avoided by using
# typedbQueryDetail instead of typedbQuery, which answers [] on failure.)
#
# A `reduce` ALWAYS answers exactly one row holding the value, so a missing/short
# answers list is a failed query, never an empty result. Counting answer ROWS here
# would report 1-or-0 regardless of the count — a separate trap, documented above.
val() { python3 -c '
import sys,json
try:
    d=json.load(sys.stdin)
except Exception:
    print("ERR"); raise SystemExit
if not isinstance(d, dict) or d.get("err") or d.get("error"):
    print("ERR"); raise SystemExit
a=d.get("answers")
if not isinstance(a, list) or not a:
    print("ERR"); raise SystemExit
try:
    v=next(iter(a[0]["data"].values()))
    print(v.get("value", 0) if isinstance(v, dict) else v)
except Exception:
    print("ERR")'; }

# Guard for every `q ... | val` caller: turn ERR into cannot-run (3), never red (1).
# Usage:  n=$(q '...' | val); num "$n" "what was being counted" || return $?
num() {
  case "$1" in
    ''|ERR) cannot "substrate query failed while counting $2 — nothing was proven either way"; return 3 ;;
  esac
  return 0
}

# ── checks ────────────────────────────────────────────────────────────────

check_schema_live() {
  local s; s=$(curl -s -m 30 "$TYPEDB_URL/v1/databases/$TYPEDB_DATABASE/schema" \
                 -H "Authorization: Bearer $TOK")
  for v in objective deliverable attempt; do
    echo "$s" | grep -q "\"$v\"" || return $(red "thing-type @values lacks \"$v\" — migration 0044 not deployed")
  done
  echo "$s" | grep -q "provenance" || return $(red "hypothesis lacks provenance — 0044 not deployed")
  say "deployed schema carries the ladder"; echo "ok   schema-live"
}

# Counts objectives THE RECEIVER WROTE, which is not the same as objectives.
#
# The discriminator is the `rung:<type>:<slug>:<ordinal>` tag. `factory:elaborate`
# stamps it (resolvers/factory.ts: `const tag = rungTag(type, slug, ordinal)`),
# and `cleanTags()` strips `rung:` from caller-supplied tags, so it cannot be
# forged through the API. A `.tql` migration insert carries none of it.
#
# It used to count bare `thing-type "objective"` and report the shortfall as
# "zero receiver-written objective things". Measured 2026-07-29:
#   local rail  9 objectives, 0 carrying a rung: tag  -> check was GREEN
#   prod  rail 10 objectives, 1 carrying a rung: tag
# The 9 are `schema/migrations/seed-factory-vision.tql` — raw inserts. So on the
# local rail this check passed while the receiver had written NOTHING, which is
# precisely the sentence its own red says is impossible.
#
# Same defect, same day, as the tracer seeder that raw-inserted instead of
# calling the receiver. Both were green on scaffolding. main's
# `not { $t has tag "tracer:hand-seeded"; }` exclusion did not help and is now
# redundant: the tracer is a DELIVERABLE, so it never matched this query at all.
# An exclusion list cannot answer "did a receiver write this" — only a tag the
# receiver alone can stamp can.
check_write_path() {
  local n; n=$(q 'match $t isa thing, has thing-type "objective", has tag $g;
                        $g like "rung:objective:.*";
                  reduce $n = count($t);' | val)
  num "$n" "receiver-written objective things" || return 3
  [ "${n:-0}" -gt 0 ] || return $(red "zero objectives carry a rung: tag — every objective row was inserted by hand or by migration, so nothing proves factory:elaborate writes the ladder")
  say "$n receiver-written objective rows"; echo "ok   write-path"
}

check_seeded() {
  local n; n=$(q 'match $t isa thing, has thing-type "objective", has tag "vision:row"; reduce $n = count($t);' | val)
  num "$n" "vision:row objectives" || return 3
  [ "${n:-0}" -ge 9 ] || return $(red "only ${n:-0} vision:row objectives — expected >= 9 (vision.md's map)")
  say "$n vision rows seeded"; echo "ok   seeded"
}

check_driver() {
  local n; n=$(q 'match $p isa thing, has thing-type "do-plan", has tag "slug:factory";
                        let $t in ready-tasks($p); reduce $n = count($t);' | val)
  num "$n" "ready tasks" || return 3
  [ "${n:-0}" -gt 0 ] || return $(red "ready-tasks() empty — the driver has nothing to schedule")
  say "$n ready tasks"; echo "ok   driver"
}

check_gaps_visible() {
  # The proof that downward completeness works: the dark wires are UNCOVERED
  # deliverables — present in the graph, served by no task. Absence made visible.
  local n; n=$(q 'match $p isa thing, has thing-type "do-plan", has tag "slug:factory";
                        let $d in uncovered($p); reduce $n = count($d);' | val)
  num "$n" "uncovered deliverables" || return 3
  [ "${n:-0}" -gt 0 ] || return $(red "uncovered() empty — either nothing is seeded, or absence is still invisible")
  say "$n uncovered deliverables named"; echo "ok   gaps-visible"
}

check_belief_guard() {
  # Question 4 fails OPEN: with no signal->hypothesis edges, ungrounded() returns
  # empty, which reads as "nothing ungrounded".
  #
  # REWRITTEN 2026-07-28 — the original form asserted DATA:
  #   match (source: $s, target: $h) isa path; $s isa signal; $h isa hypothesis;
  # against the production `one` db, and required count > 0. That check could
  # never go green by working, for a structural reason, not a timing one:
  #   * the runtime writes signals to D1, not TypeDB (root CLAUDE.md: "D1 for
  #     signals/messages"). `one` holds ZERO `signal` relations — measured.
  #   * writeEvidenceEdges() (resolvers/learning.ts) grounds a belief by matching
  #     `$sig isa signal` IN TYPEDB. With no signal there, it writes no edge —
  #     so the count stays 0 no matter how much real traffic flows.
  # A kill-switch that cannot pass by working gates nothing. Same failure class
  # as the `node --check` proof that false-failed forever (learnings 2026-07-04):
  # the red was for the wrong reason, so the switch was decorative.
  #
  # What the deliverable actually promises is the WIRE — "ungrounded() returning
  # empty means grounded rather than unwired". So assert the wire, against a REAL
  # substrate (repo rule: never mock TypeDB), in a SCRATCH database, never `one`.
  local t="$ROOT/one.ie/web/src/lib/resolvers/learning-evidence.test.ts"
  [ -f "$t" ] || return $(red "no learning-evidence.test.ts — the evidence wire is unproven")
  [ -n "${TYPEDB_TEST_DB:-}" ] \
    || return $(cannot "no TYPEDB_TEST_DB scratch database — the evidence wire needs a real substrate to prove, and must never be proven against the production db")
  local out
  # Hand the test the SAME credentials this script already parsed out of .env.
  # vitest does not read that file, so without this the test builds `${''}/v1/signin`
  # and dies on "Failed to parse URL" — which the pass-grep below then reports as a
  # RED ("ungrounded() does not discriminate"). That is an environment gap wearing
  # a red's clothes, the exact 1-vs-3 conflation this script's header forbids.
  # `:-` on every expansion: this script runs under `set -u`, and an assignment
  # prefix that dereferences a possibly-unset name aborts the whole check with
  # "unbound variable" — which surfaces as a RED for a reason that has nothing to
  # do with the evidence wire.
  out=$(cd "$ROOT/one.ie/web" && \
        TYPEDB_URL="${TYPEDB_URL:-}" \
        TYPEDB_USERNAME="${TYPEDB_USERNAME:-}" \
        TYPEDB_PASSWORD="${TYPEDB_PASSWORD:-}" \
        TYPEDB_TEST_DB="${TYPEDB_TEST_DB:-}" \
        "${_GATE[@]}" bunx vitest run src/lib/resolvers/learning-evidence.test.ts 2>&1)
  # The scratch db needs the schema loaded; the test defines none of its own. An
  # empty db answers "Type label 'hypothesis' not found", which is cannot-run.
  printf '%s' "$out" | grep -qE "Type label '(hypothesis|group|path)' not found" \
    && return $(cannot "scratch db $TYPEDB_TEST_DB has no schema — load it first (see text/typedb-production-problem-solutions.md)")
  printf '%s' "$out" | grep -qE 'Failed to parse URL|ERR_INVALID_URL' \
    && return $(cannot "scratch db reachable but TYPEDB_URL/credentials did not reach vitest")
  # A SKIPPED test is not a proof. learning-evidence.test.ts is
  # `describe.skipIf(!TYPEDB_TEST_DB)`, so without the guard above vitest exits 0
  # having run nothing — the exact fail-open this check exists to forbid.
  printf '%s' "$out" | grep -qE 'Tests[[:space:]]+.*skipped' \
    && return $(red "evidence-wire tests SKIPPED — a skipped test is not a proof (fail-open)")
  printf '%s' "$out" | grep -qE 'Tests[[:space:]]+[1-9][0-9]*[[:space:]]+passed' \
    || return $(red "evidence-wire tests did not pass — ungrounded() does not discriminate an edged belief from an edgeless one")
  say "evidence wire proven against scratch db $TYPEDB_TEST_DB"; echo "ok   belief-guard"
}

# The SDK's generated zod enum is a SECOND gate in front of TypeDB: it rejects
# a thing-type it doesn't know before the write ever reaches the database.
# Deploying 0044 without regenerating leaves the ladder unwritable and the
# failure looks like a validation error, not a migration gap.
check_sdk_enum() {
  local f="$ROOT/packages/sdk/src/generated/schemas.ts"
  [ -f "$f" ] || return $(red "no generated/schemas.ts")
  for v in objective deliverable attempt; do
    grep -qE "\"thing-type\": z\.enum\(\[[^]]*\"$v\"" "$f" \
      || return $(red "generated zod thing-type enum lacks \"$v\" — codegen not re-run after 0044")
  done
  say "sdk enum carries the ladder"; echo "ok   sdk-enum"
}

# The factory's read side reaches every surface through ONE door: fn:run + its
# ALLOWLIST. Adding a fun to the allowlist lights it up on SDK, MCP, CLI, react,
# channels chat and workflow tool-steps at once — text/generate-from-tql-plan.md
# § Decision 3. A fun in FN_MAP but not on the allowlist is generated, typed, and
# unreachable.
#
# This used to grep each of the four consumer files for the fun name, because the
# allowlist WAS four literal copies. C8 consolidated them into one exported
# source, and check_fn_one_allowlist now FORBIDS a surface from carrying its own
# literal list — so the old grep could only be satisfied by re-adding quoted
# names to files its sibling check forbids from holding them. Two checks in the
# same proof: join cannot both be honoured that way, and a green bought with a
# comment naming a fun would be exactly the symbol-that-is-never-called this
# script's header rails against.
#
# So the name-grep moved to the ONE source, and the per-surface half became "does
# this surface read that source". That is strictly stronger than four independent
# copies: four copies could each pass while drifting apart, whereas one source +
# four readers cannot.
check_tracer() {
  # PORTED FROM MAIN 2026-07-28 + FIXED. Main's version counted with
  #   return count($t) ... | rows
  # which is broken twice over, and this script documents both traps itself:
  #   * TypeDB 3.x has NO `return count($x)` — it is a TQL03 syntax error;
  #     `reduce` is the only aggregate form. So the query never answered.
  #   * rows() counts ANSWER ROWS, and a reduce always answers exactly one,
  #     so it reported 1-or-0 regardless of the actual count.
  # Net effect: check_tracer reported RED no matter what the graph held — a
  # fifth check in this plan that could not pass by working. Now uses the same
  # reduce/val/num path as every other counting check, so an unreachable
  # substrate is cannot-run (3) and a genuine zero is red (1).
  local n; n=$(q 'match $t isa thing, has thing-type "deliverable", has tag "tracer:hand-seeded"; reduce $c = count($t);' | val)
  num "$n" "tracer:hand-seeded deliverables" || return 3
  [ "${n:-0}" -gt 0 ] || return $(red "no tracer:hand-seeded deliverable — the chain has not been proven end to end")
  local u; u=$(q 'match $p isa thing, has thing-type "do-plan", has tag "slug:factory";
                        let $d in uncovered($p); $d has tag "tracer:hand-seeded"; reduce $c = count($d);' | val)
  num "$u" "tracer deliverables returned by uncovered()" || return 3
  [ "${u:-0}" -gt 0 ] || return $(red "the tracer deliverable exists but uncovered() does not return it — the query half of the chain is broken")
  say "tracer row seeded and returned by uncovered()"; echo "ok   tracer"
}

# check_stream and check_walk_speed used to be defined HERE as well as below.
# Both sides of the C6 merge carried byte-identical bodies, so git auto-merged
# them in twice with no conflict — and bash takes the LAST definition silently.
# Two live copies of an assertion is how one of them drifts unnoticed. The
# surviving pair is main's, which carries the rationale comments this one lacked.

check_fn_exposed() {
  local m="$ROOT/packages/sdk/src/generated/fn-map.ts"
  local a="$ROOT/packages/sdk/src/fn-allowlist.ts"
  [ -f "$a" ] || return $(red "no packages/sdk/src/fn-allowlist.ts — there is no allowlist to be on")
  # Kept identical to check_fn_one_allowlist's list on purpose: two checks
  # disagreeing about how many surfaces exist is how a fifth copy gets in.
  local surfaces=(
    "$ROOT/one.ie/web/src/lib/resolvers/fn.ts"
    "$ROOT/packages/mcp/src/tools/fn.ts"
    "$ROOT/packages/cli/src/fn.ts"
    "$ROOT/channels/src/tools/fn.ts"
  )
  for fn in ready-tasks uncovered unrealised incomplete; do
    # Anchored to the ENTRY, not to a mention. fn-map.ts ends with a `FnName`
    # union listing every name, so a bare `grep "$fn"` stays green with the entry
    # deleted — measured: the red-proof for this arm passed with `uncovered`
    # removed from FN_MAP. A grep that cannot go red for the reason it claims is
    # not a proof (this script's header).
    grep -qE "^[[:space:]]*\"$fn\": \{" "$m" \
      || return $(red "fn-map has no $fn entry — codegen not re-run after the factory .tql files landed")
    # Quote-agnostic: the source is double-quoted today, but a re-format to
    # single quotes must not fake a red on an allowlist that carries the fun.
    grep -qE "['\"]$fn['\"]" "$a" \
      || return $(red "the shared allowlist lacks $fn — generated and typed, unreachable from every surface")
  done
  for s in "${surfaces[@]}"; do
    [ -f "$s" ] || return $(red "$s is missing — a declared allowlist consumer does not exist")
    # An IMPORT statement, not a mention. Every one of the four surfaces names
    # `@oneie/sdk/fn-allowlist` in a comment as well, so the unanchored form its
    # sibling check uses stays green on a file that has stopped importing it.
    grep -qE "^[[:space:]]*import .*(fn-allowlist|FN_ALLOWLIST)" "$s" \
      || return $(red "$(basename "$(dirname "$s")")/$(basename "$s") does not import the shared allowlist — the factory funs are invisible from that surface")
  done
  say "factory funs in FN_MAP and on the one allowlist all four surfaces read"; echo "ok   fn-exposed"
}

# The driver funs take an ENTITY param — ready-tasks($plan: thing). buildTypeQL
# in the web resolver binds params by their JS runtime type and emits
# `let $plan = "..."`, which cannot bind an entity; the `isEntity` flag the
# generator already writes into FN_MAP is read by nothing. So the door is built
# and will not open for any fun with an entity param — which includes three
# funs ALREADY on the allowlist (optimal_route, cheapest_provider,
# actor_classification). Fixing it is shared work, not factory-only.
check_fn_entity_args() {
  # tests/unit/ is relative to the WEB package — that is where vitest.config.ts
  # lives and where `tests/unit/**` is already on the include list. The repo root
  # has no package.json and no vitest binary, so a root-relative path could never
  # go green (`bun vitest` there answers "Script not found").
  local t="$ROOT/one.ie/web/tests/unit/fn-entity-args.test.ts"
  [ -f "$t" ] || return $(red "no one.ie/web/tests/unit/fn-entity-args.test.ts — entity-param binding unproven")
  (cd "$ROOT/one.ie/web" && bunx vitest run tests/unit/fn-entity-args.test.ts >/dev/null 2>&1) \
    || return $(red "buildTypeQL does not bind entity params by match — the driver funs cannot execute through fn:run")
  say "fn:run binds entity params"; echo "ok   fn-entity-args"
}

# ONE allowlist, not three. generate-from-tql-plan.md § Wave 4 promised "no
# sixth copy of the truth" and the implementation shipped three — so a fun
# reachable from chat can be invisible to the CLI. This asserts a single
# exported source AND that no surface still declares its own literal Set.
check_fn_one_allowlist() {
  local src="$ROOT/packages/sdk/src/fn-allowlist.ts"
  [ -f "$src" ] || return $(red "no packages/sdk/src/fn-allowlist.ts — the allowlists have no shared source")
  # FOUR surfaces, not three. The plan, the promise and this check all said three;
  # `channels/src/tools/fn.ts` was a pre-existing fourth copy nobody counted, and it
  # was STALE — missing the four driver funs, so chat could not name them. A check
  # that stops at three would have gone green with that copy alive, which is the
  # exact failure this deliverable exists to prevent ("allowlisting a fun lights up
  # EVERY surface"). Adding a fifth consumer? Add it here in the same commit.
  local surfaces=(
    "$ROOT/one.ie/web/src/lib/resolvers/fn.ts"
    "$ROOT/packages/mcp/src/tools/fn.ts"
    "$ROOT/packages/cli/src/fn.ts"
    "$ROOT/channels/src/tools/fn.ts"
  )
  for s in "${surfaces[@]}"; do
    [ -f "$s" ] || return $(red "$s is missing — a declared allowlist consumer does not exist")
    grep -qE "fn-allowlist|FN_ALLOWLIST" "$s" \
      || return $(red "$(basename "$(dirname "$s")")/$(basename "$s") does not import the shared allowlist")
    # Unanchored + name-agnostic: the old form was `^const ALLOWLIST = new Set<string>\(\[`,
    # which a rename or a re-indent walked straight past. Any local Set-of-strings
    # literal assigned to an ALLOWLIST-ish name is copy N of the truth.
    grep -qE "(const|let|var)[[:space:]]+[A-Za-z_]*ALLOW[A-Za-z_]*[[:space:]]*(:[^=]*)?=[[:space:]]*new Set" "$s" \
      && return $(red "$(basename "$(dirname "$s")")/$(basename "$s") still declares its own literal allowlist — that is copy N of the truth")
  done
  say "one allowlist, four consumers"; echo "ok   fn-one-allowlist"
}

# The gaps board must be HONEST WHEN EMPTY. A board that renders zero rows as a
# clean slate is the fail-open trap in visual form — the operator reads "no gaps"
# when the truth is "nothing seeded". So the component must distinguish the two
# and the check asserts the empty-state copy exists alongside the query wiring.
# NAMED FILES, never `ls | head -1`.
#
# This check and check_stream both used to glob components/factory/*.tsx and read
# whichever sorted FIRST. On 2026-09-01 `FactoryFlow.tsx` landed in that directory,
# sorted before `GapsBoard.tsx`, and silently stole both checks: view-gaps went RED
# against a canvas that was never the board, and stream went GREEN against the same
# canvas, because a play loop contains `setInterval` and the word `stop`. A check
# aimed at "whatever sorts first" is a check anyone can re-aim by adding a file.
#
# So each check names the file it means. Adding a component to that directory is now
# a free action; renaming or deleting one of THESE is what has to fail loudly.
#
# RE-AIMED 2026-09-04. Naming the file was the right fix and it was aimed at the
# wrong file: `IdeaBoard.tsx` was mounted by NO page — `factory.astro` mounts
# `FactoryFlow` and nothing else — so this check was green against a component a
# person could not open. Deleted with R3. The surface that ships is the canvas,
# and the empty-state copy lives in its `ideasNote`.
check_view_gaps() {
  local board read
  board="$ROOT/one.ie/web/src/components/factory/FactoryFlow.tsx"
  read="$ROOT/one.ie/web/src/lib/factory/board-read.ts"
  [ -f "$board" ] || return $(red "no FactoryFlow.tsx — /factory has no canvas to render")
  [ -f "$read" ] || return $(red "no board-read.ts — the board has nothing to read the ladder with")
  grep -qE "derived-from|thing-type \"(deliverable|objective|task)\"" "$read" \
    || return $(red "the board's read does not walk the ladder — it renders nothing real")
  grep -qiE "nothing is seeded yet|no rows yet|not seeded|graph is empty" "$board" \
    || return $(red "the canvas has no distinct EMPTY state — zero rows would read as 'nothing missing', which is the fail-open trap in visual form")
  grep -qiE "could not read the board" "$board" \
    || return $(red "the canvas cannot say it failed to read — an outage would render as an empty board")
  say "the board walks the ladder and is honest when empty"; echo "ok   view-gaps"
}

# The templates are where every FUTURE plan inherits or repeats this session's
# mistakes. Three concrete ones, all hit live while authoring this promise:
#   1. tier: — the template teaches "trivial|simple|complex" while /do resolves
#      tier from this field as PATCH|FIX|FEATURE|SCHEMA (do.md:189 + :205).
#      The corpus is split across both vocabularies, which is the tell.
#   2. deliverables: — the example shows UNQUOTED values, so any value carrying
#      a backtick, colon or brace makes the frontmatter invalid YAML.
#   3. proof: — no mention that a check can exit "cannot run" (3) rather than
#      red (1), so an outage reads as a broken promise.
#
# The RATCHET is the instrument, not a cleanup: 102 of 294 filled todos already
# fail to parse. Demanding all be fixed would stall this promise; demanding the
# number never RISES is enforceable per cycle and costs nothing (factory-plan
# §6.1). Baseline is recorded, and the check fails if it grows.
FACTORY_YAML_BASELINE=102
check_templates() {
  local tt="$ROOT/text/template-todo.md" tf="$ROOT/text/template-feature.md"
  grep -qE 'PATCH.*FIX.*FEATURE.*SCHEMA' "$tt" \
    || return $(red "template-todo.md tier: does not name the vocabulary /do actually reads (PATCH|FIX|FEATURE|SCHEMA)")
  grep -qE '^\s*#?\s*-\s+\w+:\s+"' "$tt" \
    || return $(red "template-todo.md deliverables: example is unquoted — it teaches the shape that produces invalid YAML")
  grep -qiE 'cannot run|exit 3' "$tf" \
    || return $(red "template-feature.md does not distinguish a red proof from one that could not run")
  local n
  n=$(cd "$ROOT/text" && python3 -c "
import glob,yaml,sys
b=0
for f in glob.glob('*-todo.md'):
    s=open(f, errors='replace').read()
    if not s.startswith('---'): continue
    try: yaml.safe_load(s.split('---')[1])
    except Exception: b+=1
print(b)")
  [ "${n:-999}" -le "$FACTORY_YAML_BASELINE" ] \
    || return $(red "unparseable todo frontmatter rose to $n (baseline $FACTORY_YAML_BASELINE) — a new plan learned the broken shape")
  say "templates corrected; unparseable todos $n <= $FACTORY_YAML_BASELINE"; echo "ok   templates"
}

# THE HUMAN IS A MONITOR, NOT A GATE. The factory runs without anyone; the
# operator watches a stream and can stop it. Review as a GATE is serial and
# becomes the bottleneck — that is the failure mode of every "just add more
# review" factory. Streaming + stop is parallel: it never blocks a cycle, and
# it never lets one run unwatched either.
# Named, for the reason spelled out above check_view_gaps.
#
# RE-AIMED 2026-09-04, same defect as check_view_gaps and worse: this one was
# GREEN. `RunPanel.tsx` was mounted by no page, so "factory streams and can be
# stopped" was asserted about a file nobody could open while the canvas that
# ships had `grep -c 'do:halt\|workflow:stop'` = 0. Deleted with R3; the stop now
# lives in `RunTrack.tsx` (the panel FactoryFlow renders) over `stop-run.ts`.
#
# The three greps are now aimed at three DIFFERENT files on purpose: the stream
# is the hook, the control is the rendered panel, and the receiver is the
# resolver. A single file satisfying all three is what let a play loop pass as a
# stream control.
check_stream() {
  local panel hook
  panel="$ROOT/one.ie/web/src/components/factory/RunTrack.tsx"
  hook="$ROOT/one.ie/web/src/lib/use-workflow-stream.ts"
  [ -f "$panel" ] || return $(red "no RunTrack.tsx — nothing shows what is running")
  [ -f "$hook" ] || return $(red "no use-workflow-stream.ts — the panel has nothing to stream from")
  grep -qiE "EventSource|text/event-stream" "$hook" \
    || return $(red "/factory does not stream — a static page cannot show what is being built RIGHT NOW")
  grep -qF "stopRun" "$panel" \
    || return $(red "/factory has no stop control — the operator can watch but not intervene, which is lights-off with a window")
  grep -qiE "not permitted" "$ROOT/one.ie/web/src/lib/factory/stop-run.ts" 2>/dev/null \
    || return $(red "the stop control does not render its refusal — a stop that silently no-ops for an anonymous reader tells the operator nothing")
  grep -rqE '"(do:halt|workflow:stop)"' "$ROOT/one.ie/web/src/lib/resolvers/" 2>/dev/null \
    || return $(red "the stop control is not wired to a receiver that actually halts a run")
  say "factory streams and can be stopped"; echo "ok   stream"
}

# THE DETERMINISTIC LIFECYCLE WALK is what replaces human review. Not a model
# judging a diff — a script driving the real feature through its real lifecycle
# (signup -> purchase -> ...) against a running system, asserting it WORKS and
# is FAST. Zero LLM tokens, exits 0 iff every stop is green.
#
# Two things this check demands that do-walk.sh cannot do today:
#   1. max_ms: per stop — a lifecycle that works but takes 9s is a regression
#      no pass/fail assert can see.
#   2. stops that DRIVE the lifecycle rather than grep for a symbol. A
#      `grep -q ComponentName` stop passes on a component that is imported
#      nowhere — presence is not proof, and most existing walks are greps.
check_walk_speed() {
  grep -q "max_ms" "$ROOT/.claude/scripts/do-walk.sh" \
    || return $(red "do-walk.sh has no max_ms — the walk can prove a lifecycle works but never that it is fast")
  [ -f "$ROOT/text/factory-agents.md" ] \
    || return $(red "no text/factory-agents.md — no deterministic lifecycle walk exists")
  grep -q "max_ms" "$ROOT/text/factory-agents.md" \
    || return $(red "the factory walk has no speed budget on any stop")
  (cd "$ROOT" && bash .claude/scripts/do-walk.sh factory --agents >/dev/null 2>&1) \
    || return $(red "do-walk.sh factory --agents did not exit 0 — the lifecycle does not pass its own walk")
  say "lifecycle walk passes with speed budgets"; echo "ok   walk-speed"
}

# The docs must stop saying the factory is unarmed once it is.
check_docs() {
  [ -f "$ROOT/text/factory-docs.md" ] || return $(red "text/factory-docs.md missing")
  grep -qiE 'nothing here is armed|no .?text/factory\.md.? promise' "$ROOT/text/factory-plan.md" \
    && return $(red "factory-plan.md still says the factory is unarmed")
  grep -qiE 'live +0%|LIVE +░{20}' "$ROOT/text/vision.md" \
    && return $(red "vision.md still scores the factory at 0% LIVE")
  # The public page was outside this gate, which is how it kept claiming "one of
  # thirteen" while production ran fifteen of sixteen. This asserts the WIRE, not
  # the prose: /do is the page about the factory, so it must carry a door to the
  # board. Delete the link and this goes red.
  local do_page="$ROOT/one.ie/web/src/pages/do.astro"
  [ -f "$do_page" ] || return $(red "one.ie/web/src/pages/do.astro missing")
  grep -q 'href="/factory"' "$do_page" \
    || return $(red "/do describes the factory but has no door to /factory — the board is unreachable from the page that explains it")
  grep -qiE 'one of thirteen|thirteen checks, and .*all thirteen were red' "$do_page" \
    && return $(red "do.astro still reports the pre-ship tally — the board says otherwise")
  # The promise's OWN canon was outside this gate — which is how § The honest
  # status went on calling `stream` and `walk-speed` "genuinely red — not built"
  # and `tracer` "defective" after all three had gone green. A doc that reports a
  # stale verdict on its own proof is precisely the drift this promise exists to
  # catch, sitting in the promise. So gate it against the CHECKER, not against a
  # frozen phrase: any check the canon calls red must actually BE red.
  #
  # Only red-shaped claims are gated. A "cannot run" claim is NOT stale when the
  # check passes here — cannot-run is a property of the machine you are standing
  # on (TYPEDB_TEST_DB, a reachable cluster), so asserting it would make this go
  # red on a laptop that merely has more provisioned than the writer's did.
  local promise="$ROOT/text/factory.md"
  [ -f "$promise" ] || return $(red "text/factory.md missing — the promise has no canon")
  local claimed name crc
  claimed=$(python3 - "$promise" <<'PY'
import re, sys
s = open(sys.argv[1], errors="replace").read()
m = re.search(r'^## The honest status$(.*?)(?=^## |\Z)', s, re.M | re.S)
names = set()
if m is None:
    # The gate anchors on this heading. Rename the heading and every claim under
    # it stops being read — the gate would pass while checking nothing, which is
    # the `all`-runs-13-of-16 fail-open in a second costume. Missing anchor is a
    # RED, not a skip.
    print("__NO_HONEST_STATUS_SECTION__")
else:
    for para in re.split(r'\n(?=- )', m.group(1)):
        if not re.search(r'genuinely red|not built|defective|\bis red\b', para, re.I):
            continue
        # A paragraph that RECORDS a past red and its fix is reconciled history,
        # not a stale verdict — "was defective, now passes by working" must stay
        # writable. Only an unreconciled claim of CURRENT redness is drift.
        if re.search(r'now (?:green|passes)|since fixed|fixed,|was red|no longer', para, re.I):
            continue
        names.update(re.findall(r'`([^`]+)`', para))
print(" ".join(sorted(names)))
PY
)
  [ "$claimed" = "__NO_HONEST_STATUS_SECTION__" ] \
    && return $(red "text/factory.md has no '## The honest status' section — the canon gate anchors on that heading and would pass while reading nothing")
  for name in $claimed; do
    # Only names that are real checks; `docs` itself never (infinite recursion).
    case " $CHECK_ORDER " in *" $name "*) ;; *) continue ;; esac
    [ "$name" = "docs" ] && continue
    "check_${name//-/_}" >/dev/null 2>&1; crc=$?
    [ $crc -eq 0 ] \
      && return $(red "text/factory.md § The honest status still calls \`$name\` red or unbuilt, and it passes — the promise's own canon is stale")
  done
  say "docs reconciled; canon carries no stale red verdict"; echo "ok   docs"
}

case "${1:-all}" in
  schema-live)   check_schema_live ;;
  sdk-enum)      check_sdk_enum ;;
  docs)          check_docs ;;
  fn-exposed)    check_fn_exposed ;;
  fn-entity-args) check_fn_entity_args ;;
  fn-one-allowlist) check_fn_one_allowlist ;;
  view-gaps)     check_view_gaps ;;
  tracer)        check_tracer ;;
  stream)        check_stream ;;
  walk-speed)    check_walk_speed ;;
  templates)     check_templates ;;
  tracer)        check_tracer ;;
  stream)        check_stream ;;
  walk-speed)    check_walk_speed ;;
  write-path)    check_write_path ;;
  seeded)        check_seeded ;;
  driver)        check_driver ;;
  gaps-visible)  check_gaps_visible ;;
  belief-guard)  check_belief_guard ;;
  json)          run_receipt ;;
  # `all` iterates CHECK_ORDER — the SAME list json mode runs. It used to carry
  # its own hand-maintained copy, and that copy was left at 13 while CHECK_ORDER
  # grew to 16: tracer, stream and walk-speed were silently skipped, so `all`
  # exited 0 while three legs of the promise's own proof were red or unrun. A
  # fail-open in the aggregate runner of the script whose whole purpose is to
  # stop fail-opens. There is now ONE list; a new check cannot be half-added.
  #
  # Exit preserves the 1-vs-3 distinction the header calls the point: any red
  # wins (1), else any cannot-run (3), else green (0). Collapsing a cannot-run
  # into a red here would send someone to fix the build when the substrate was
  # simply unreachable.
  all) rc=0
       for c in $CHECK_ORDER; do
         "check_${c//-/_}"; crc=$?
         case $crc in
           0) ;;
           3) [ $rc -eq 0 ] && rc=3 ;;
           *) rc=1 ;;
         esac
       done; exit $rc ;;
  *) echo "unknown check: $1" >&2; exit 3 ;;
esac
