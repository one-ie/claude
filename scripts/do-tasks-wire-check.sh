#!/usr/bin/env bash
# do-tasks-wire-check — assert the /do ⇄ substrate-task wires are actually connected.
#
# Why this exists: text/tasks-do.md's deliverables were all `grep -q '<receiver-name>'`
# checks. Every one stayed GREEN for months while three of the wires were dead in prod —
# a grep for "tasks:everywhere" passes just as happily when the call authenticates with
# the wrong secret, parses the wrong envelope key, and addresses the lease by a tid that
# can never resolve. Presence is not connection. These checks assert the SHAPE that was
# broken, so a regression to any of the four known-bad forms turns the promise red.
#
# Usage: bash .claude/scripts/do-tasks-wire-check.sh   → exit 0 all wired, 1 otherwise.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

FAIL=0
ok()   { printf '  ✓ %s\n' "$1"; }
bad()  { printf '  ✗ %s\n' "$1"; FAIL=1; }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1 — $3"; fi; }

echo "[tasks-wire] /do ⇄ substrate task wires"

# 1. The ranker authenticates as a SERVICE CALLER.
#    /api/ask/<receiver> decides isServiceCaller off env.GATEWAY_API_KEY. SERVER_SECRET
#    is what /api/signal/ checks — the two routes do not share a secret.
check "do-rank reads the board with GATEWAY_API_KEY" \
  "grep -q 'secret = _gateway_key()' .claude/scripts/do-rank.py" \
  "fetch_tasks_everywhere must call _gateway_key(), not _server_secret()"

# 2. The ranker nominates a workspace. A service call carries no session actor, so
#    ctx.ownerSlug comes solely from payload.slug|payload.workspace. Omit it and
#    tasks:everywhere answers {ok:false,error:"forbidden: authentication required"}.
check "do-rank nominates a workspace on the board read" \
  "grep -q '\"workspace\": ws' .claude/scripts/do-rank.py" \
  "the tasks:everywhere payload must carry workspace"

# 3. The ranker parses the /api/ask ENVELOPE. Answers are wrapped
#    {outcome, result:{ok, tasks}, signalId, receiver} — reading ok/tasks off the top
#    level makes even a good answer look like a failure, so the merge never fires.
check "do-rank unwraps the /api/ask result envelope" \
  "grep -qF 'payload.get(\"result\")' .claude/scripts/do-rank.py" \
  "must read ok/tasks from payload['result'], not the top level"

# 4. Cloudflare answers the stock urllib User-Agent with 403 "error code: 1010" before
#    the Worker ever runs. curl is unaffected, which is why only the ranker hit this.
check "do-rank sends a real User-Agent (CF bot block)" \
  "grep -q 'User-Agent' .claude/scripts/do-rank.py" \
  "the board request must set a User-Agent header"

# 5. The fleet addresses the lease by SLUG. Real tids are minted task:<traceId>
#    (resolvers/tasks.ts insertTaskRow), so a guessed "task:<slug>" resolves not_found
#    for every plan and the cross-agent lease can never gate.
check "do-fleet claims the lease by slug, not a guessed tid" \
  "grep -qF '\\\"slug\\\":\\\"\$slug\\\"' .claude/scripts/do-fleet.sh" \
  "claim_task must post data.slug"
check "do-fleet no longer guesses tid=task:<slug>" \
  "! grep -qF 'tid=\"task:\${1}\"' .claude/scripts/do-fleet.sh" \
  "the guessed-tid form is back"

# 6. The fleet lease actually GATES. Every non-already-claimed response used to degrade
#    to "ok to launch", so two runs could both think they owned the same task.
check "do-fleet distinguishes not_found from already-claimed" \
  "grep -q 'error\":\"not_found' .claude/scripts/do-fleet.sh" \
  "claim_task must branch on not_found separately from the generic error case"

# 7. /close routes the task close through a route that EXISTS. There is no
#    /api/tasks/{id}/complete anywhere in one.ie/web/src/pages/api/.
check "/close has no dead /api/tasks/{id}/complete POST" \
  "! grep -qE 'POST .(http://localhost:4321)?/api/tasks/\{id\}/complete' .claude/commands/close.md" \
  "close.md still posts to a route that does not exist"
check "/close closes the task through tasks:status" \
  "grep -q 'api/ask/tasks:status' .claude/commands/close.md" \
  "close.md must use the tasks:status door"

if [ "$FAIL" -eq 0 ]; then
  echo "[tasks-wire] OK — all wires connected"
else
  echo "[tasks-wire] BROKEN — see ✗ above"
fi
exit "$FAIL"
