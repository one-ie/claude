# /close

Close the loop. One bounded pass, then a row for anything it could not close.

```bash
bash .claude/scripts/do-close.sh <slug> [--tid <tid>] [--composite 0.NN] [--dims k=v,…]
```

**That script is the authority.** It carries the leg table, the budgets, the
credential ladder and the remediation commands; this file does not restate them.
`--help` prints the flags, `--self-test` proves the red halves.

---

# The close is a conversation, not a status flip

A close that only writes `status=done` is a closed loop the substrate can read and
**no person can**. Since 2026-09-09 every close runs as a real thread in
`/u/one/in`, spoken by the agent that owns the work and answered by the agent it
reports to. The thread IS the record: an operator who was not here opens one room
and learns what was done, what it cost, what it disproved, and what is next.

The acts below run in order. None is optional; each names the door it uses.

## One close, many rooms

**A close that touches eight things belongs in eight conversations, not one.** This
is not extra work — it is already how the store is built. `tasks:comment` writes
the SAME D1 message store the inbox reads, keyed ``getOrCreateThread(env.DB, {
slug, agentId: `task:${tid}` })`` (`resolvers/tasks.ts:1815`). So a comment on a
task **is** a conversation in `/u/<slug>/in`, titled by that task. There is no
second store and no second step.

Two levels, and they carry different things:

| Room | Holds | Door |
|---|---|---|
| **the close thread** (`close-<slug>`) | the spine — what was closed as a whole, the superior's verdict, the rubric | `thread:append` |
| **each thing's own thread** (`task:<tid>`) | what THIS row's close means for THIS row, in the place its watchers already read | `tasks:comment` |

Post the whole close only to the spine, and post to each thing's room the one
paragraph that matters **there**. A watcher who follows one task must not have to
read a session-wide close to learn what happened to it — and a `@mention` in that
comment INSERTs a `follows` row (`tasks.ts:1686-1693`), so speaking in a room is
also how the next person gets subscribed to it.

The failure this prevents is measured: agents post without `replyTo` — 0 of 33 on
the launch board — and the board was invisible for two days that way. One lump
thread nobody is watching is the same defect wearing a tidier shape.

## Act 0 — the room exists before anyone speaks

Open the thread FIRST, then let the agents talk into it. A room minted after the
fact is a transcript; a room minted first is a place.

```bash
K=$(grep -m1 '^GATEWAY_API_KEY=' one.ie/web/.dev.vars | cut -d= -f2- | tr -d '"')
curl -s -X POST https://one.ie/api/ask/thread:append \
  -H "Authorization: Bearer $K" -H 'Content-Type: application/json' \
  -d '{"data":{"slug":"one","group":"close-<slug>","role":"user",
       "content":"<what is being closed, in one paragraph>"}}'
```

Four traps, each one measured, each one silent when you hit it:

| Trap | What happens |
|---|---|
| `.env`'s `GATEWAY_API_KEY` | prod REFUSES it. The working service key is in **`.dev.vars`** |
| python `urllib` | **403** from prod. Use `curl` |
| field named `text` | `validation … field: content`. The field is **`content`** |
| omitting `sender` | `validation … field: sender`. It is **required**, even for `role:"user"` |
| no `data` envelope | `envelope_missing`. Every payload is `{"data":{…}}` |

**`ok:true` is not proof.** This door can answer `ok` with nothing durable. Read
the row back before believing it:

```bash
npx wrangler d1 execute one-owners --remote --json --command \
  "SELECT role, substr(content_json,1,120), ts FROM messages
   WHERE thread_id='<tid>' ORDER BY ts DESC LIMIT 5;"
```

`chat:context` answers **forbidden** here — the service key is not a workspace
member. D1 is the read.

## Act 1 — every task has an owner, or the close assigns one

An unassigned task cannot report to anyone, so the close **fills the gap rather
than skipping it**. Resolution order, and it never invents a name — the roster is
`ls one.ie/ai/agents/`:

Resolution is a **script, not a judgment** — `bash .claude/scripts/close-owner.sh
--tags "<task tags>"` answers owner + the full chain above them, and
`--self-test` proves it can go red. Run it; do not reason it out.

1. **Match the task's tags against `subscribes:`** in each `one.ie/ai/agents/*/agent.md`.
   Bare words only — `marketing`, never `lifecycle:marketing`; a namespaced tag
   matches zero signals (root `CLAUDE.md`). Measured 2026-09-09: **56** agents,
   48 declare `subscribes:` — but only **30 carry a bare stake**, so 26 cannot be
   tag-matched at all and reach an owner only through the ladder below.
2. **Ties break DOWNWARD** — the lowest tier that matches wins. Sending a director
   to do specialist work is how a director stops being available for the judgment
   only they can make.
3. **No match → `world:route`**, which walks the staked tag→receiver paths and
   answers `reason:'ceo'` for a workspace with no history.
4. **Still nothing → the CEO.** Repo law: the CEO is the default receiver, always
   listening via a standing workflow.

Assign with `tasks:reassign` (or `tasks:claim` if the agent is taking it itself),
and say so in the room. An assignment nobody announced is an assignment nobody acts on.

**The owner does not have to be in this workspace.** `tasks:everywhere` admits a row
tagged `@actor` with **no workspace check** (`subscriptions.ts:81`, rule a), so an
assignment crosses the tenant line and lands on that actor's `/tasks` and `/plan`.
Use it when the right owner lives elsewhere — the ladder fallback exists for when
nobody fits, not for when the person who fits is simply somewhere else.

Two constraints that follow: the `@` tag is writable **only** through
create/claim/reassign (`tasks:tag` admits plain words only — `resolvers/tasks.ts:112`),
and each of those takes identity from `ctx`, never the payload. So you can reach
anyone, and the row always carries who sent it.

## Act 2 — the owner analyses, and closes what it can prove

The owning agent reads the work and answers four questions in the thread, in its
own name (`role:"assistant"`, `sender:"<agent>"`):

- **What was asked**, quoted from the task's own `notes`, not paraphrased.
- **What was done**, as file:line or a receipt — never "implemented X".
- **What it disproved.** The most valuable line in any close. A close that
  disproved nothing usually measured nothing.
- **What it did NOT do**, and why. Scope declined on purpose is a result;
  scope silently dropped is a defect.

Then it acts on the board, and every act is a door that already exists:

| Act | Door |
|---|---|
| close a task it can prove | `tasks:status` → `done` |
| leave a comment on the task | `tasks:comment` — writes the SAME message store as the inbox thread |
| tag the row so it routes | `tasks:tag` (bare words) |
| file what it found | `tasks:subtask` — with `notes` AND `blockedBy` in the SAME call |
| rank it | `tasks:priority` |

**Never close a task on inference.** A task closed because it "looks done" is worse
than one left open — the board stops being a record of what is true. If the proof
is not in hand, comment what is missing and leave it open.

## Act 2b — the blast radius: what ELSE touches what you just closed

A thing is never closed alone. Sweep the four surfaces that reference it, and
**say what you found in each one's own room**. A close that names no neighbours
either touched nothing or did not look.

| Surface | The question | How to answer it |
|---|---|---|
| **tasks** | what did this unblock, and what is now orphaned? | `blockers-of($t)` · `ready-tasks($plan)` · `orphans($plan)` — a row with no `parent` is unreachable from any plan and the factory's walk will never find it |
| **workflows** | does a step still name what I changed? | a step's receiver is a literal string; a renamed receiver dissolves at run time as `unknown_receiver`, silently. Grep `trigger_source` and step receivers for the old name |
| **pages** | which surfaces render it? | Puck blocks + `PAGE_CHAT_META`. A block registered but never rendered is inert, and a page that names a dead receiver fails only when a person clicks |
| **agents** | who staked on these tags? | the bare words in `subscribes:` — those actors should hear it. `world:announce` fans it; silence is not routing |

Three substrate funs are the close's own auditors. Run them on what you touched:

- **`overclaimed()`** — an asserted hypothesis carrying more confidence than its
  evidence. If your close created one, you did not close, you claimed.
- **`well-made-wrong()`** — high craft, `rubric-fit 0.0`. The most expensive
  failure there is: it looks finished and it solved the wrong problem.
- **`unproven($plan)` / `covered-unproven($plan)`** — a deliverable that shipped
  and was never proven. Shipping is not proving.

## Act 3b — will anyone ever know if this was any good?

**This is the act most closes skip, and it is the one that decides whether the
world can learn.** Rule 1 says every signal closes with `mark`, `warn` or
`dissolve`. But a thing that emits no signal can never be marked or warned — so no
path to it ever moves, no outcome ever re-ranks it, and the substrate is blind to
it forever. Verification > presence: "it shipped" is a claim about the past.

So before writing `done`, answer: **what future event tells us this worked?**

| What shipped | What must emit |
|---|---|
| a UI affordance | `emitClick('ui:<surface>:<action>')` — every onClick is a signal |
| a page or block | a view event, and a lane if it is a choice — a block with no lane is scenery |
| money or a commitment | `recordConversion` with a real `ConversionStage` (`event-vocabulary.ts`) — the server narrates a purchase, never the client |
| a receiver | it closes with `mark`/`warn`, never a silent return |
| an agent's work | an attempt that closes with a rubric, so `craft-composite` has something to read |

If the honest answer is **nothing will emit** — say so in the room and file the
tracking rung. Do not launder it into `done`. An unmeasurable feature is a feature
the world cannot rank, and a substrate whose whole thesis is that outcomes re-rank
routing has just been handed a permanent blind spot.

Two traps worth naming because both read as success: a stage in `MARK_STAGES` that
excludes awareness means **reaching** something is deliberately not a `mark` — do
not upgrade a view into evidence. And a cron handler whose expression is missing
from `[triggers] crons` is **dark** — registered in code, never fired, and nothing
says so.

## Act 3 — the follow-ups are filed before the close, not after

Anything the analysis surfaced becomes a row **in the same act**, or it evaporates.
Use `tasks:subtask` and pass `notes` + `blockedBy` in the one call: between a bare
`tasks:create` and a later `tasks:notes`, the row sits on the board claimable, with
an empty body and no ordering, and the factory will take it.

Every row lands with its metadata filled — no bare titles:

| Field | Rule |
|---|---|
| `notes` | the goal in prose: what done looks like, and why. **A row with no notes is the row that sits untouched.** |
| `tags` | bare routing words that will actually reach a subscriber |
| `priority` | **0..1, a fraction** — `tasks:create`'s zod is `z.number().min(0).max(1)` and `55` is rejected outright as `validation … field: priority`. The registry is the spec; this table said `1–100` until 2026-09-15 and every row filed from it bounced. The rubric that decides the number: money/security bleeding NOW ≫ decisions blocking others ≫ critical path ≫ backlog |
| `parent` | omit it and the row is an orphan, unreachable from any plan |
| `blockedBy` | what stops ten siblings going ready at once |
| `dueAt` | **only where a real date exists.** Never invent one — a fabricated deadline is a lie the Today lens repeats every morning |

## Act 4 — it reports to its superior, and the superior answers

The chain is declared, not guessed: `reports_to:` in the agent's own frontmatter,
resolved by `close-owner.sh --owner <agent>`. Measured 2026-09-09 — **39 of 56**
agents carry it, so a third of the roster needs the fallback, and the fallback is
a ladder, not a default:

```
reports_to: in agent.md          →  use it
else  specialist → the director of its own `domain:`
      director   → ceo
      ceo        → chairman
      chairman   → the human, via human:notify
else  ceo        (repo law: the CEO is the standing receiver)
```

The superior does not rubber-stamp. It reads the thread and answers with one of
three verdicts, posted in its own name:

- **CLOSED** — the work is proven. The loop ends.
- **OPEN, with a named gap** — what is missing, as a task it files itself.
- **REFUTED** — the claim does not hold; the owner's close is reversed and the
  row goes back to open with the reason.

**The loop runs until the superior closes it, not until the owner is finished.**
Bound it at 3 rounds: the owner answers the gap, the superior re-reads. Still open
after 3 → escalate one rung and say so, rather than looping forever. A superior
that has not answered is not a close — it is an unrun gate, and an unrun gate is
never a pass.

**A verdict is not an account.** CLOSED ends the loop; it does not tell anyone
what happened. Act 4b is where the work is assessed and said out loud.

## Act 4b — the director assesses, and posts what the world reads

Act 4 answers **"is this proven?"** — a gate, and its three verdicts decide only
whether the loop may end. It does not answer **"does anyone outside this thread
know, and should they care?"** A close that stops at a verdict is legible to the
loop and invisible to the company: the superior said CLOSED, the row went green,
and nobody who was not in the room learned anything.

So the close hands the finished work to a **director**, who assesses it and posts
about it in its own name.

**The director is resolved, never chosen.** The same script Act 4 already runs
returns the whole chain; the DIRECTOR rung of it is the one that posts:

```bash
# COMMA-separated. Spaces do not split — "deploy release ship" is ONE tag named
# "deploy release ship", it matches nobody, and the answer is an entirely ordinary
# `hits=0 confidence=none` that reads exactly like a genuinely unowned area.
bash .claude/scripts/close-owner.sh --tags "deploy,release,ship"
#  owner=release-manager  via=subscribes  hits=2  specific=2  contenders=1  confidence=high
#  chain=cto ceo chairman
```

**The first entry of `chain=` is the director** — `cto` above. When the owner is
itself a director the chain starts one rung higher (`--owner cmo` → `chain=ceo
chairman`) and the director who posts is the OWNER; do not walk past it to the
CEO, or every close in the company arrives at one desk.

Two answers are NOT a director, and they are different — the script says which:

| It prints | Means | Who posts |
|---|---|---|
| `owner=REFUSED … confidence=low` + a `fallback=ceo` line | several agents staked equally — genuine ambiguity | the CEO decides who speaks, and says why |
| `owner=ceo via=fallback(no-tag-match) … confidence=none` | **nothing staked on these tags at all** | the CEO posts, and files the missing stake as a row |

The second is the interesting one: it is not a routing failure, it is the world
telling you a whole area has no owner. Closing it silently under the CEO hides
that. File the stake.

And the route follows the world rather than the org chart's fiat: emit
`signal("world", { tags })` and the director who **staked** on those tags gets it
(root `CLAUDE.md § the universal router`). Bare words only — a namespaced tag
matches zero subscribers, so `marketing`, never `lifecycle:marketing`. The CEO is
the receiver of LAST resort, for genuine ambiguity (no clear staker), not the
default addressee.

**Assessment is a different question from review.** Act 6's reviewer asks whether
the work is correct; the director asks whether it was worth doing and what it
changes. Four questions, answered in the post or explicitly declined:

| Question | What a non-answer looks like |
|---|---|
| **Who is better off, and at what?** | "improved the panel" — no persona, no verb |
| **What did it cost?** | no cycles, no tokens, no wall clock |
| **What did it disprove?** | every close that discovers nothing is a close that tested nothing |
| **What is now possible that was not?** | no next rung, or a rung with no owner |

Then it posts — one message, into `/u/one/in`, through the door the operator
already reads:

```bash
# space:post → the workspace inbox + every connected SSE listener
signal("chat:send", { space: "one", content: "<the assessment>", replyTo: "<the close thread>" })
```

### Five rules for that post, each one a defect this repo has already shipped

1. **Name the lane.** A fast pass is never reported as a full pass. `verify:fast`
   and `bun run verify` are different claims and the reader cannot tell them apart
   afterwards.
2. **Name where it landed.** "on `dev`" is not "in production". A post that says
   *shipped* about a branch is the same lie as a green cycle with an unrun gate,
   and it is the one a reader acts on.
3. **Name what did NOT ship.** A close post with no open items is a marketing
   post wearing a record's clothes. What was left out, and why, is the half a
   future reader needs — they already assume the rest worked.
4. **Quote a measurement, not a claim.** One number that was actually read —
   `816px 560px`, `998 tests`, `0 errors` — beats a paragraph of adjectives, and
   it is what makes the post checkable a month later.
5. **It does not post OUTWARD.** Customer-facing copy — blog, social, changelog —
   is a row the director FILES, never a thing the close publishes. `brand-guardian`
   holds a hard veto on creative, and a close that publishes has just routed
   around it.

**`ok:true` is not proof here either.** Read the row back (Act 0's D1 query) before
believing the post landed.

The failure this prevents is measured, in this repo, twice. Agents post without
`replyTo` — **0 of 33** on the launch board — and the board was invisible for two
days. And a thread only holds the top of the inbox while it is LIVE
(`LIVE_WINDOW_MS`, `lib/in/live-pin.ts`): a close nobody posts is not merely quiet,
it is unreachable within the hour, sitting under every task row that spoke more
recently.

## Act 5 — the docs end true

The propagate matrix below (§ Loop Close) already lists which doc each trigger
touches. Two rules the conversation adds:

- **The promise is the first row reconciled**, before any derived doc.
- **A doc that still says the thing is unbuilt, after you built it, is a defect** —
  the W4 shipped-status check exists because this drifts on 3 of 3 runs.

## Act 6 — the rubric, and who reviews it

Score the **cycle** rubric. Weights and axis definitions live in
`.claude/scripts/rubric-weights.json` (`cycle` block) — read them there, **never
restate them here**, and never substitute `w4-rubric.ts`'s `task-composite=`
(five axes, no goal-fit, so the `goal-fit ≥ 0.50` gate becomes unevaluable).

Gate, all four conjuncts: `composite ≥ 0.65` **AND** `goal-fit ≥ 0.50` **AND**
no adversarial > 0.5 **AND** `delta_tsc ≤ 0`.

**Who reviews is decided by size × importance, and both are measured, not felt:**

| Size (`do-tier.sh`) × importance (task priority) | Model |
|---|---|
| the mechanical closes — status flips, comments, tag writes, doc-truth greps | **haiku**, fanned out in parallel, one per task |
| the analysis and the report | **sonnet** — the default |
| FEATURE, or priority ≥ 0.90 | **opus** reviews before the superior answers |
| SCHEMA, or it touched money / auth / custody / a locked name | **fable** reviews — apex judgment, once, fed a context pack |

The fan-out is real parallelism and it is where the cost goes: N tasks closing is
N haiku calls in ONE message, never a serial walk. The review is the opposite —
one call, at the end, on the whole thread.

**A reviewer defaults to REFUTED and must quote the line that changed its mind.**
No quotable line ⇒ not proven.

## Act 6b — the chain, when the promise was minted

A close that settles a **promise** settles it twice: off-chain, which runs the
loop, and on-chain, which holds the state and enforces the ratchet.

`.claude/scripts/do-promise-settle.sh <slug> --composite <n>` is the one door. It
re-runs the promise's own `proof:` and, when the promise carries an `object_id:`
in its `contract:` block, submits the generated `settle_promise` on the same run —
kept/broken, amount = strength×1000 bps. The Move object is **generated from
`schema/sui.tql`** by `schema/codegen/targets/move.ts`, never hand-written.

Read the exit code, not the vibe:

| Exit | Meaning | Verb |
|---|---|---|
| 0 | proof green | `mark` on `promise:<slug>→proof` + `world:announce` |
| **3** | **UNVERIFIABLE — a leg could not reach its substrate** | **neither. The promise stays open. Re-run later** |
| other non-zero | proof red | `warn` |
| no observable | dissolved — reported, never silent |

**Exit 3 is not a close.** A `proof:` is an `&&`-join, so one unreachable leg stops
the chain. Folding that into `warn` deposits resistance on a proven path for a
cluster blip — a promise recorded BROKEN for a reason its maker cannot fix.

**Measured 2026-09-09, and this is why the chain leg is usually a no-op today: the
mint door is sealed.** `NETWORK` is absent from `one.ie/web/wrangler.toml` (grep
count **0**) and the testnet gateway's `worker_public_key` is empty on-chain, so
nothing can be minted and therefore nothing can settle. The mechanism is wired and
the schema is real (`Promise` appears 6× in `schema/sui.tql`); the door is shut.
Arming it is one of Tony's open calls, and it sits deliberately BEHIND the three
custody decisions — arming a mint before deciding whether a master may derive an
agent's key is backwards.

So: attempt the chain leg, report what it answered, and **never report a sealed
door as a settled promise.** An unarmed chain degrades cleanly; the off-chain
settle stands on its own.

## Act 7 — what to do next is COMPUTED, not suggested

A close ends by naming the next work, and that name is read out of the graph
rather than invented. `schema/factory.tql` carries 43 funs; these answer "next":

| Question | Fun |
|---|---|
| what is now claimable? | `ready-tasks($plan)` · `ready-in-wave` |
| what did this close unblock? | `blockers-of($t)` — run it BEFORE and AFTER |
| what is stuck with nothing to wait on? | `deadlocked()` |
| what has no plan above it? | `orphans($plan)` |
| what is promised and not built? | `uncovered($plan)` · `incomplete()` |
| what is built and not proven? | `unproven($plan)` · `covered-unproven($plan)` |
| what did we settle wrongly? | `mis-settled()` |
| the single next thing | `next($plan)` |

**A recommendation the model composed is a guess wearing a receipt.** The rule is
the one the plan parser already enforces: any deterministic fact a close needs gets
a query, and the model executes it rather than substituting for it. Where a fun
answers, quote its answer. Where none does — a judgment call about sequencing,
say — mark it plainly as judgment and say what would settle it.

Report next work as **rows, not prose**: each one filed with `notes`, `tags`,
`priority`, `parent` and `blockedBy` per Act 3, so the recommendation IS the board
rather than a paragraph someone must re-type into it.

## The loop runs until CLOSED or a human is notified — never until tired

A close is a loop, and a loop needs a termination condition that is not fatigue.
There are exactly two exits:

| Exit | When | Door |
|---|---|---|
| **CLOSED** | the superior answered CLOSED | `mark` + `world:announce` |
| **NOTIFY** | the loop hit a decision it cannot make | `human:notify` — with the evidence AND the options |

Anything else is a round, and rounds are **bounded at 3**. Still open after three
→ escalate one rung and say so. A loop with no bound is not autonomy, it is a
process nobody can predict the cost of.

**A notification without options is an interruption.** When the loop escalates it
carries what it found, what it ruled out, and the shortlist it could not choose
between — the way `close-owner.sh` refuses: it prints `owner=REFUSED` *and*
`candidates=`, because a decision handed up without its options makes the human
redo the search the loop already did.

### Self-healing: every failure repairs itself, or names why it can't

The loop must survive its own failures without a person. The substrate already
does this in four places — copy the shape, don't invent one:

| Failure | Heals by |
|---|---|
| a worker died holding a slot | the claim **evaporates** — dead pid (`kill -0`) or an expired lease, checked on the READ path, so the next contender reclaims dead ground by itself |
| a proof leg cannot reach its substrate | **exit 3**, and the promise stays open to be re-run — never recorded BROKEN for a cluster blip |
| a gate already ran on this exact tree | the receipt is **content-addressed**, so a neighbour's pass counts and nothing recomputes |
| a check's premise went stale | the **red proof** — gut the mechanism and assert the check fails. A check that stays green against a gutted mechanism was never checking |

Three rules that keep a self-healing loop honest, because each has a failure mode
that looks exactly like success:

1. **Never heal by weakening the check.** When a test goes red after a change,
   decide first whether it is a *regression* or a *corrected belief*, and say
   which in the commit. Editing an assertion to match new behaviour is legitimate
   ONLY when the old assertion was wrong — and then the comment must say why it
   was wrong. Silently relaxing it is how a suite becomes decorative.
2. **Empty work ⇒ do the full thing, never ⇒ pass.** A loop that goes green by
   selecting nothing is worse than a slow one.
3. **A repair is a rung, not a detour.** If healing means touching code the close
   never owned, file it — a close that grows scope while running stops being
   something anyone can review.

### The loop's own three questions, each round

- What changed since the last round, and did the gate actually *run*? (an exit
  code is a claim about a command that may never have executed)
- Did this round's repair break something that was green? If so — regression or
  corrected belief?
- Is the remaining gap something I can decide, or something only the human can?
  If the latter, stop and notify **now**, with the shortlist. Looping past a
  decision you cannot make burns budget and changes nothing.

## Act 8 — the loop closes where it opened

Post the verdict into the same thread, `mark`/`warn` per the Four Outcomes, then
`world:announce` so whoever staked on those tags learns it happened. Read the
final row back from D1.

**This is not Act 4b again.** That act is the account a PERSON reads — prose, in
the director's name, in the room. This one is the machine close: the outcome the
substrate records and the fan-out to stakers. Skipping either leaves half a close
— a company that knows and a substrate that does not, or the reverse. The thread is now the durable record — a terminal
transcript is read once by one person; a room is read by everyone after.

---

## Steps

Six legs, four states each (`pass` · `fail` · `unrun` · `n/a` — do-w4-gates.sh's
law, unchanged: **an unrun leg is not a closed leg**, plus `skipped` for a leg
`--only` left out — which licenses nothing, because an operator narrowing the run
is not evidence about the tree), run in three waves because
there are exactly three dependency edges and no more.

| Leg | Closes | Wave |
|---|---|---|
| `gate` | is there a FULL-suite receipt for **this exact tree**? | 1 |
| `derives` | every `derives: … true` artifact is on disk | 1 |
| `dims` | the five rubric axes → `/api/mark-dims` | 1 |
| `task` | the board write — `tasks:status` (**needs `gate`**) | 2 |
| `promise` | `do-promise-settle.sh` (**needs `derives`**) | 2 |
| `feedback` | the return-path pheromone → `/api/signal/loop:feedback` (**needs everything**) | 3 |

Measured on a warm tree: **~1s** for the two network legs, **~5s** for the whole
battery. Every curl carries `--max-time`; the two legs that shell out to scripts
this one does not control go through `run_bounded`.

## The three rules it will not trade for speed

1. **It never runs a suite.** `/close` is a FULL-lane trigger and *a fast pass is
   never reported as a full pass*. So it asks `test-full.sh` (`TEST_CACHE_KEY_ONLY=1`,
   ~1s, cannot start vitest) whether this tree already carries a receipt. The key
   is content-addressed, so **a neighbour's suite counts as yours** — a memo HIT is
   free and it counts. No receipt is `unrun`, filed, and named.
2. **No receipt ⇒ the board is not told `done`.** That edge is the whole reason
   this repo once had cycles closed green at 0.92 with "tsc not measured".
3. **Exit 3 from the promise settle is UNVERIFIABLE, never `warn`.** A `proof:`
   is an `&&`-join; a leg that cannot reach its substrate has not broken a
   promise. The promise stays open and gets a row.

## The numbers it mines

Six leg states say the doors were knocked on. They do not say what changed,
whether this tree is proven, where the branch sits, or *why* something could not
be measured. So every close ends with a measured block —
`.claude/scripts/close-metrics.sh`, additive, **never a seventh leg**: it decides
nothing, it can turn nothing red, and its exit code is discarded. A metric that
could fail a close would make this a closer people route around, and the numbers
would leave with it.

| Section | Rows | Owner it composes |
|---|---|---|
| `work` | files changed · lines ± · new/deleted/renamed · untracked · test/doc/code split · tests-per-code-file · largest file | `git diff HEAD` |
| `tree` | branch · worktree kind · dirty paths · ahead/behind trunk · **landed** · worktree count | git; landed is `merge-base --is-ancestor`, an ancestry FACT, never a merge result |
| `gates` | full-suite receipt HIT/MISS per lane · W4 pack pass/fail/unrun · `delta_tsc` | `test-full.sh` (`TEST_CACHE_KEY_ONLY=1`) · `.w4-gates.json` if a cycle left one |
| `rubric` | composite vs gate · per-axis · **velocity** vs the last recorded composite | `rubric-weights.json` · `text/learnings.md` |
| `close` | ledger open rows · unlanded deploy rows · **`packages/claude` mirror drift** · derives | `do-close.sh --pending` · `deploy-record.sh --pending` · `sync-claude-mirror.sh --check` · `do-derives-check.sh` |
| `machine` | load/cores · free MB · gate slots held · locks | the governor's own dir |
| `substrate` | which door answered · promise has a `proof:` | `/api/health` · `text/<slug>.md` |

Three rules it inherits and one it adds.

1. **It composes, it never re-derives.** Every row names a script that already
   owns that number. A second opinion is drift with a delay on it — which is how
   the receipt row was born broken: it called `test-cached.sh` (which needs a
   `<folder>` and prints usage without one) instead of `test-full.sh`, and read
   `unrun` on trees that were proven.
2. **It never runs a gate.** `TEST_CACHE_KEY_ONLY=1` structurally cannot start
   vitest, and `.w4-gates.json` is READ, never regenerated — running
   `do-w4-gates.sh` bare would run `do-reconcile.sh types`, a tsc that queues
   minutes behind the governor. No metrics row is worth a gate slot.
3. **Four states, and `unrun` never prints a zero.** Measured in this repo:
   `grep -c "error TS" <file>` returned `0` against an output file a queued gate
   had not written yet. "Zero errors" and "never ran" were the same three
   characters. `--self-test` drives the unrun branch on purpose — point it at an
   absent base ref, an empty cache, no `--composite` — and fails if any of them
   answers with a number instead.
4. **The `machine` section is evidence, not vanity.** An `unrun` with no pressure
   reading beside it is a mystery; with one it is a reason. "tsc not measured,
   box saturated" once closed three cycles green at 0.92.

```bash
bash .claude/scripts/close-metrics.sh --json          # for a caller
bash .claude/scripts/close-metrics.sh --section gates # one section
bash .claude/scripts/do-close.sh <slug> --no-metrics  # legs + verdict only
```

## Blockers it decides, instead of asking

A blocker that resolves the same way every time is not a decision — it is a chore
with a human bolted to it. And a blocker that *is* a decision used to be filed as
bare prose ("gate unrun") with no options, no cost and no recommendation, so the
person re-derived the same fork every time.

`.claude/scripts/do-decide.sh` sits between "a leg is open" and "a human is
asked". For every open leg it names the fork, ranks the options, prices them,
recommends one — and **takes** it when, and only when, the substrate has already
watched that choice come good five times.

**The confidence is measured, and it is not this script's opinion.** The oracle
is the substrate's own routing verdict — `world:route decide:true`
(`subscriptions.ts:672`), the TS twin of `0043_route_verdict.tql`, a pure read
with no side effects and no tokens:

| verdict | means | /close does |
|---|---|---|
| `highway` | `best ≥ 5` **and** `best ≥ 2 × second` | **acts**, and notifies |
| `classified` | a candidate, not a proven one | recommends |
| `ceo` | no candidate at all | recommends |

`best` is `SUM(strength) − SUM(resistance)` over `claw_paths` from
`tag:one:decide:close:<id>` to each option. Measured against production
2026-09-09, the whole loop in three calls:

```
0 marks               → {"reason":"ceo","receiver":null,"rung":3}
5 marks of strength 1 → {"reason":"highway","receiver":"optionA","rung":1}
+ 1 warn              → {"reason":"ceo","receiver":null,"rung":3}
```

So the first five times a fork appears **a person answers it**; after that /close
answers it; and **one bad outcome takes the authority back on the very next
run.** That is the root `CLAUDE.md`'s "human gates that auto-skip when trust
earns it", applied to close blockers, on the mechanism G4 already uses for the
auto-ship gate.

**The evidence is written from outcomes, never from exit codes.** A taken
decision leaves `"decide":"taken:<option>"` on its ledger row. The *next* close
reads that row before overwriting it and settles it against what actually
happened to the leg — `pass` → `mark`, still open → `warn`. "The command exited
0" measures the command, not the choice.

**`strength` is always 1, and that is load-bearing.** `rankCandidates` sums
strength and cannot tell five marks of 1 from one mark of 5, so
`HARDEN_STRENGTH = 5` is a de-facto **n ≥ 5 sample floor** only while every
writer on `tag:one:decide:close:*` writes 1. `do-decide.sh` is the sole writer
and `--self-test` pins the literal.

### The table, and the two things no confidence can buy

```bash
bash .claude/scripts/do-decide.sh --table
```

| id | fires on | options | |
|---|---|---|---|
| `gate-mint` | `gate` unrun, no receipt | `mint` (~87s + a gate slot) · `file` | |
| `derives-retry` | `derives` unrun (out of clock) | `retry` · `file` | |
| `promise-retry` | `promise` unrun (exit 3 / clock) | `retry` · `file` | |
| `writeback` | `dims`/`feedback`/`task` door timeout | `file` | **VETO** |
| `task-gate` | `task` unrun, `gate` not pass | `file` | **VETO** |

A fork **not in this table is not a decision** — exit 5, and /close files the row
exactly as before. Adding a row is how this grows; generalising it is how it
starts guessing.

The two vetoes are checked **before the oracle is called**, so a vetoed fork is
structurally unreachable rather than reachable-and-outranked:

- **`writeback` — the self-poisoning veto.** `dims`, `feedback` and `task` write
  *through* doors. Their `unrun` is a curl timeout: the answer is UNKNOWN and the
  write may well have landed. A retry that double-writes deposits strength twice
  on exactly the `claw_paths` rows this layer reads back as confidence — it would
  inflate its own evidence, and look *more* certain the more it fired.
- **`task-gate`** — the board write must never be decided around its gate. Cycles
  once closed green at 0.92 with the suite unmeasured; that edge is why they
  can't again.

On top of the table there is a blanket class applied to the **command about to
run**, not to the table row — so a row edited to smuggle one in still cannot
fire: anything that ships, deploys, pushes, force-writes, deletes, rotates a
secret, or spends. **Blast radius is a second axis, and confidence does not buy
it.** That is the one place this layer deliberately does not do what "don't ask
if you're sure" would imply, and it is a boundary, not an omission.

**Every failure direction points at the human.** No oracle answer, a malformed
answer, an unreachable D1 mirror, a missing key, no `--apply`, no gate headroom —
all of them read `ceo` and recommend. A layer that acts when it cannot measure is
worse than the ask it replaced.

**A taken decision always pages, and always carries its undo.** The trade this
layer makes is moving the human's veto from *before* the action to *after* it,
and that is only honest while the reversal is actually in their hand:

```
gate → TAKEN mint (confidence: highway)
       undo: bash .claude/scripts/do-decide.sh --settle --leg gate --status mint --outcome open
```

A recommendation never pages — it is already on the board and in the report, and
a notifier that fires for things nobody must act on is a notifier the human
mutes.

`--no-decide` restores the old behaviour: every blocker waits for a person.
`--dry-run` prints what it *would* take and takes nothing (structural — the
script cannot act without `--apply`, and `--self-test` proves it).

## What the signal carries

`feedback` used to fire in wave 1 with four fields — slug, tid, composite,
outcome. That is a pheromone saying a close happened and nothing about what it
found, on the one channel the next agent's routing actually reads.

It is now **wave 3**, the third dependency edge (`feedback ← everything`), and it
carries the whole close:

| | |
|---|---|
| `legs[]` | all six, each with `status`, **`secs`**, and its detail |
| `closed` · `pass`/`fail`/`unrun`/`na` · `elapsed_s` · `door` · `branch` | the verdict and where it was taken |
| `decisions[]` | every fork: `taken`/`recommend`/`veto`, the choice, the confidence |
| `metrics` | the entire measured block, verbatim |

**Measured once, read twice.** The measured block is ~17s of real work. Running
it for the human and again for the machine would double it *and* measure two
different instants of a tree seven sessions are editing — so
`close-metrics.sh --json-out <file>` writes the machine copy while stdout stays
the table, and the report prints the run the signal carried.

### Tags are derived, and the close closes its own loop on them

Tags are how the world routes. A close tagged only `close,<slug>` is a close
nobody can route on, so the tags are **derived from what was measured** — bare
words, because a namespaced subscribe tag matches zero subscribers
(`subscribe-tags-parity.test.ts`):

```
close · <slug> · closed|unclosed · failing · unrun · decided · recommended
      · <each failing leg> · fast|slow · degraded
```

Then **Rule 1, on the tags themselves**: each one takes one verb on the edge
`tag:<workspace>:<tag> → close:kept|open`, carrying the whole tag set.

```
verbs:  mark=0 warn=8  on tag:one:<tag>→close:open
```

`closed` marks, open warns, and **`--status timeout` writes neither** — a held
lease is neutral by the same rule that makes `task` and `dims` `n/a` on a
timeout. A halt is not an outcome. These marks use a `tag:` source, deliberately
disjoint from the `decide:close:*` sources the decide layer reads: the close must
never vote on its own authority.

### Accretion, the trail, and the way back

*The operator, 2026-09-09: "every time a signal hits a node we should add
exponentially more metadata and data and images etc. to it… and we can combine
them back again."*

A signal that carries the same four fields at hop 5 as at hop 1 has learned
nothing from the journey, and the journey is the only thing that knows what
mattered. So the payload budget **doubles per hop** — `ACCRETE_BASE << hop`,
`CLOSE_SIGNAL_HOP` read from the caller and re-emitted incremented, so a signal
crossing four nodes arrives with 16× the room it started with.

Two bounds, because "exponentially more" without them is a signal nobody can
store and every door refuses:

1. **A hard ceiling** (`ACCRETE_MAX`, 256KB). The doubling is how fast the room
   grows, not a promise it grows forever.
2. **Bulk travels by reference.** Images, JSON dumps, diffs and gate packs go as
   `{path, bytes, sha256}`, each `test -s`-verified at emit time — never as
   bytes. That is what makes "and images etc." affordable: a screenshot costs
   ~120 bytes of envelope, and the node that wants the pixels reads the path. A
   reference to a file that is not there is "file exists is theater" with an
   extra hop of delay on it.

Numbers pack first, then details, then references — a budget that runs out drops
the biggest thing, never the verdict.

**Accretion alone is not enough, and this is the actual insight.** It makes every
node richer and leaves the one who *asked* knowing nothing. So the envelope
carries four more fields:

| | |
|---|---|
| `origin` | who started the work — survives every hop unchanged |
| `sender` | the previous node, one hop back |
| `reply_to` | where a return leg goes (`sender`, else `origin`) |
| `trail[]` | one entry per node crossed: hop, node, bytes added, artifacts, tags, verdict |

and `--reply` folds the enriched envelope **back one hop**, tagged `reply` and
`for:<node>` so the router delivers it to whoever staked on that node instead of
broadcasting. It returns the outbound payload **verbatim, not a summary** — the
sender asked for work, and a summary here would be this node deciding what the
previous node is allowed to know.

**This is the ant, and we already had half of it.** Outbound the trail gains
data; the return trail carries what was found back down the same path, and *the
return is what moves the weights*. `loop:feedback` has been called "the
return-path pheromone" for months while it returned four fields — the right name
for a leg that had nothing to return.

Three consequences worth stating, because they generalise past `/close`:

- **Routing quality is bounded by return quality.** Paths re-rank on `mark`/`warn`,
  so a mark deposited by a signal that carried no evidence is a vote cast blind.
  Enrich the return leg and the weights start meaning something.
- **The trail is append-only.** A node may add to the history it was handed; it
  may never rewrite it. A node that edits its own trail is a node whose trail
  cannot be trusted.
- **The close must never vote on its own authority.** The tag marks use a `tag:`
  source, deliberately disjoint from the `decide:close:*` sources the decide
  layer reads as confidence.

```
trail:  hop=3 origin=pannels sender=do-auto reply=do-auto  budget=32768B  artifacts=6
```

The return leg is **opt-in** (`--reply`): a close with no caller has nobody to
reply to, and a reply nobody asked for is one more signal in a world that already
routes.

### Speed is a row, not a feeling

Every leg is timed, and the measured block is timed separately — because "the
close was slow" and "the promise proof was slow" are different facts with
different fixes, and a fixed ~17s cost blamed on a door is a number nobody acts
on. `slow` is judged on the legs alone.

```
speed:  gate=2s derives=0s task=0s dims=0s feedback=1s promise=0s | metrics=17s  total=45s
tags:   close __probe__ unclosed unrun recommended gate fast degraded
```

The budget does not starve the closing signal: every other leg is skipped once
the wall clock is spent, `feedback` is exempt — it runs after the measured block,
so the guard would otherwise fire on the one leg that carries the whole close,
breaking Rule 1 by its own bound. It stays bounded by its own `--leg-budget`.

## What it cannot close, it files

Every non-pass leg lands in three places, in this order — each one a fallback for
the last failing:

1. **the local ledger** (`.claude/.close-pending.jsonl`) — this write cannot fail
   and it is what `--pending` reads back. Keyed by `<slug>:<leg>`, so a re-run
   replaces its own row: the ledger measures open work, never close attempts.
2. **a board task**, tagged `close,unclosed,leg:<name>`, whose `notes` **is the
   paste-able command** that finishes it — not prose. That is the difference
   between a task and a nag.
3. **the human** (`notify.sh`) — only when the board was *unreachable*, so the
   row reached nothing anyone watches. `--notify` forces it. `--no-file` (ledger
   only) is the operator's choice and never pages anyone.

```bash
bash .claude/scripts/do-close.sh --pending     # the open rows + each fix. exit 6 if any
```

## Run it at the end of every workflow

Last line, wrapped, always:

```bash
bash .claude/scripts/do-close.sh <slug> || true
```

It exits **0 even with open legs** — by design. A closer that fails its caller is
a closer callers stop calling, and a skipped close is Rule 1 broken: the signal
never closes and the paths never learn. `--strict` opts into exit 1 for a caller
that genuinely wants to stop. Re-running is cheap and safe: the ledger is keyed
by `<slug>:<leg>` so a row replaces itself, and a leg that passed clears its row.

Wired, verified 2026-09-09:

| Caller | Where | Status passed |
|---|---|---|
| `do-auto.sh` | plan complete (it replaced the bare `--task-link`) | `done` |
| `do-auto.sh` | `--max-cycles` halt | `timeout` — the lease stays held |
| `land.sh` | both exits | `--only dims,feedback` |
| `deploy.sh` | both exits | `--only dims,feedback` |
| `factory-executor.js` | Close stage, step 6 | `--only dims,feedback,promise,derives` |

**Three of the five pass `--only`, and the reason is the same each time: the
board write must have exactly one writer.**

- The factory executor's Close stage already owns it, and its status logic is
  richer than done/failed (a UI task stays `picked` until a person looks). Two
  writers on one row is how the first factory run reported `done` over a row the
  board read `picked`.
- `land.sh` and `deploy.sh` pass a **branch name** and the literal `deploy`. That
  is also why `_tag_add` sanitises: a branch name carries a `/`, the mark edge is
  a URL path segment, and `tag:one:feat/x→close:open` split into a route that does
  not exist — measured 2026-09-09 as 6 tags derived, 5 verbs landed, and the sixth
  gone with no error. Bare word chars only, pinned by `--self-test` check 13.
  Those names
  are not plan slugs — without `--tid` the task leg resolves by the `slug:` tag
  and would close whatever plan happens to share the name. And `land.sh` runs the
  *fast* lane, so the receipt gate is `unrun` on every land: filing that would
  fire a row on every land forever with nothing anyone can do — the EXPIRED class
  `deploy-record.sh --pending` exists to not be.

Only `do-auto.sh` passes a real plan slug, so only it runs the full battery.

`do-folder.sh` is deliberately NOT wired: it is a pure emitter whose stdout is
parsed JSON, and a close line printed there corrupts its only output.

## Outcome flags

`--status` picks the outcome word; the legs follow it.

```
result     --status done        mark()      strength++   chain strengthens
timeout    --status timeout     neutral     no change    lease HELD, status untouched
dissolved  --status dissolved   warn(0.5)   resist+=0.5  mild — path missing
failure    --status failed      warn(1)     resist+=1    full — agent failed
```

A non-`done` close asserts no green, so `gate` reports `n/a` and never blocks it.

## Three specifics that live in the script, not here

Moved into `do-close.sh` as code plus comment so they cannot rot apart from the
behaviour they govern — read them there:

- **the three doors take three different credentials** (`mark-dims` and `ask` want
  `GATEWAY_API_KEY`; `/api/signal/*` wants `SERVER_SECRET`, `signal-dispatch.ts:78`).
  Measured 2026-09-09: the feedback pheromone had been 401ing.
- **`mark-dims` Zod-parses a bare `{edge, dims}`** — a `{data:{…}}` wrapper is a 400.
- **`w4-rubric.ts`'s `task-composite` is not the cycle gate.** It scores five axes
  with no goal-fit, because a bare diff carries no plan context. The cycle gate is
  `composite ≥ 0.65` AND `goal-fit ≥ 0.50` AND no adversarial > 0.5 AND `delta_tsc ≤ 0`,
  weights in `.claude/scripts/rubric-weights.json` (`cycle` block). Pass the composite
  in with `--composite`; the script does not score judgment and never will.

---

*`/close` is `mark()` made bounded. Every outcome closes its loop — or leaves the command that does.*
