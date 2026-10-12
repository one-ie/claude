---
name: planning
description: Turn a whole task board into a plan, and the plan into moved rows — tasks:board to see everything, tasks:bulk to act on it. Use whenever an agent has a goal and needs to know what already exists, what is ready, what is blocked and who owns it, or needs to file a plan tree, route unowned work, sweep a stale tag, or find the rows that became claimable when something closed. Triggers — "plan this", "what should I work on", "see the whole board", "what is ready", "what is blocked", "file the plan", "break this down into tasks", "route the unassigned work", "clean up these tasks", "how many tasks are there really".
---

# planning — the board is the plan

**Purpose:** one loop. **See it all → decide → shape → act → close.** Every step is a
receiver, none is a convention you can improvise, and the whole board is ONE request.

**A page of tasks is not the board.** Measured 2026-09-13 and written into the contract
(`packages/sdk/src/receivers.ts:2113-2118`): an agent asked for the board, hit a 200-row page,
paged by six tags, found 353 more rows **by name only**, and never learned the real total.
`tasks:board` exists so that cannot happen again — and so you can reason about 2,000 tasks
while reading 0 of them.

**The door is `one tasks`.** `one tasks board|brief|plan|bulk|set|sequence|depend|undepend`
(`packages/cli/src/tasks.ts`; the bin is `one` or `oneie`, and from the monorepo
`node packages/cli/dist/src/index.js tasks …`) walks the pages, chunks writes at 25, and previews
filter writes unless `--apply`. Pipe `--json` to a file and filter it with `node -e`/`jq`; never
read 2,000 rows through the context window.

**Never hand-roll a direct API call for board work while a `one tasks` verb covers it** — no
`curl` to `/api/ask/tasks:*`, no `ask` loop, no per-row MCP loop. Measured in the 2026-09-28
friction report (root `task:01a0e611a439062e48d1450a`): three hand-written HTML-error parsers,
custom retry loops and token maths in shell in one session — every one of them something
`one tasks` already does. The JSON recipes below are the payloads the CLI sends: read them to
understand a field, send them yourself only where no shell exists. A seat running the board
turn by turn (ceo, cto, cmo, cfo, cro, cxo, cco, chairman) loads the `orchestrate` skill
(`one.ie/ai/skills/orchestrate/SKILL.md`) — the loop on top of these verbs.

    node packages/cli/dist/src/index.js tasks board --workspace one --tree --summary          # 1 — see it all
    node packages/cli/dist/src/index.js tasks board --workspace one --tree --all --limit 2000 --include notes --json > board.json
    node packages/cli/dist/src/index.js tasks set --workspace one --where-tag <t> --set-status dissolved --comment "why"   # preview
    node packages/cli/dist/src/index.js tasks bulk --file plan.json --apply                   # file a whole plan tree
    node packages/cli/dist/src/index.js tasks brief --workspace one --tree                     # one screen + next five moves
    node packages/cli/dist/src/index.js tasks plan <goal-tid|tag> --workspace one --tree       # waves + critical path (hops)
    node packages/cli/dist/src/index.js tasks plan <goal> --emit dispatch --out wave.json     # hand-off for factory-executor / tasks:launch
    node packages/cli/dist/src/index.js tasks sequence <tid> <tid> <tid>                      # chain in order; preview unless --apply

`brief`, `board` and `plan` default to `--kind work`: rows tagged `approval` are parked workflow
runs, left out of the counts and COUNTED as excluded. Close one with `tasks_approve` /
`workflow:stop`, never by status — `set --apply` refuses a match that holds one unless `--kind all`.
`plan` reads a blocker's state from the server's `openBlockers`, never raw `blockedBy`: a closed
blocker is satisfied, an open one outside the goal is `waits outside plan` and never dispatched.
Dispatch hints ride in notes as labelled lines — `model:` `effort:` `touches:` `accept:` — and rows
in one wave that share a `touches:` path are serialised. Promise + plan: `text/tasks-cli.md`.

The raw HTTP door and the MCP tools below are the same receivers — the fallback for a turn with
no shell, never a second door beside the CLI. If `tasks` is an unknown command the CLI `dist/`
is stale — rebuild sdk then cli, and do not fall back to curl.

Every door: `POST https://one.ie/api/ask/<receiver>`, `Authorization: Bearer $GATEWAY_API_KEY`
(from `one.ie/web/.dev.vars`, **not `.env`**), body wrapped in `{"data":{…}}` or you get
`envelope_missing`. Via MCP, `tasks_board` / `tasks_bulk` take the same fields.

---

## 1 — SEE IT ALL (always first, before any row read)

```json
{"data":{"workspace":"one","view":"summary","scope":"tree"}}
```

`view:"summary"` returns counts and sets and **no rows** — the cheapest way to see a 2,000-row
board. `scope:"tree"` is this group **and every descendant** (the CEO / agency lens); default is
`own`. Read the rows only once the summary told you which rows to ask for.

**Four honesty fields. Read all four before you plan.**

| Field | Means | Your next move |
|---|---|---|
| `total` | rows matching the filters **before paging**. Exact — *unless* `truncated.rows` is present, then it is a **floor** | quote it as the count, or as "at least N" |
| `nextCursor` | present **iff** more rows match. Absent = you have them all | page until it is absent; never stop early and call it the board |
| `truncated` | absent = nothing was cut. `.rows` = snapshot hit its budget · `.edges` = a row may read unblocked or orphaned when it is not · `.tags` = returned rows may be missing tags | **say so in your report** before planning on it |
| `asOf` | ISO time the snapshot was built; rows are at most this stale | it is a KV memo, not a live read. `fresh:true` asks for a rebuild and is honoured **at most once per memo window** |

**`summary` counts are over ALL matched rows; its id lists are a SAMPLE.**
`summarizeBoard` counts every matched row (`one.ie/web/src/lib/tasks/board.ts:531`), but
`readyIds` / `blockedIds` are the **top 50 by priority** (`board.ts:559-560`) and `byTag` is the
**top 100 tags by count** (`board.ts:553`). A board with `ready: 300` hands you 50 ids — take the
count from `summary`, take the rows from a filtered `view:"rows"` call with `nextCursor`.

**Row width.** Compact rows already carry `tid,name,status,priority,tags,assignee,workspace,
parent,blockedBy,openBlockers,ready,dueAt` — and `blockedBy`/`openBlockers` appear only when the
row actually has blockers (`one.ie/web/src/lib/resolvers/task-board.ts:170`). Widen with
`include: ["notes","graph","dates","thread"]`; `notes` is **clipped to 2000 chars per row**
(`task-board.ts:182`) — read a whole goal one task at a time.

---

## 2 — DECIDE what to do

Shipped in `summary` today (all computed in RAM over the matched set, no TypeDB):

- **`ready`** — open **and** every blocker closed; a blocker not on the board counts as open, so
  readiness is never reported on a guess (`board.ts:463-469`). The set a director can start now.
- **`blocked`** — status `blocked`, or active with at least one open blocker.
- **`unassigned`** · **`overdue`** — work with no owner, work past its date.
- **`orphans`** — no parent, unreachable from any plan's containment walk.
- **`noNotes`** — no prose goal: the rows a puller **cannot act on**. Not work, a title.

**The unblockable row is the highest-value row on any board.** Status `blocked`, every blocker
now closed — claimable in fact, invisible in practice, because `ready` requires
`status === 'open'` (`board.ts:465`) and **nothing promotes it automatically**. Derive it today:
ask `{"status":"blocked"}`, keep rows whose `openBlockers` is `0` or absent, then flip them with
`tasks:bulk edits` (recipe D).

**Designed, not built** — `summary.decisions` (`unrouted` · `unblocked` · `stalePicked` ·
`deadlocked`) is **R10** of `text/tasks-inbox-plan.md` §6 and is not in the zod. So are
`changedSince` (R9), `include:["route"]` + `summary.routes` (R11), and the CEO digest (R12).
Zod **strips undeclared keys**, so sending one of those fields does not error — it silently
degrades to a full cold read. Do not write payloads against them.

---

## 3 — SHAPE the work: chain before you fan out

`tasks:claim` is **blocker-gated**, and the edges you write are what that gate reads. An
unchained board hands every agent every row at once and nothing knows what comes first.

**One call files a whole plan tree.** `tasks:bulk` `creates` (max 25) with `ref` handles:

```json
{"data":{"workspace":"one","creates":[
  {"ref":"plan","title":"Launch the pricing page","notes":"Done when /pricing is live and converts"},
  {"ref":"copy","title":"Write pricing copy","parent":"plan","notes":"Three tiers, no jargon"},
  {"title":"Ship pricing page","parent":"plan","blockedBy":["copy"],"notes":"Deploy after copy lands"}]}}
```

**Ref rules — earlier-only.** A ref must be created **earlier in the same `creates` array** and
its own create must have succeeded. A forward ref, a self ref, or a ref whose create failed is
`unknown_ref`, and **nothing is written for that row** — a typo never reaches the substrate as a
lookup (`one.ie/web/src/lib/resolvers/tasks.ts:2245-2252`). The receipt maps `ref → tid` in
`created`.

`tasks:subtask` does the same job **one row at a time** (row, notes, tags, containment edge and
every `blockedBy` in one pipeline) and `tasks:depend` orders rows that already exist. **Never file
a child with `tasks:create`** — it lands claimable, with no parent and no ordering.

**The claim gate is wider than the board's `ready` flag.** `blockersResolved` requires every
`blocks` blocker **AND every `containment` child** to be done|verified (`tasks.ts:614-619`,
called by claim at `tasks.ts:963`), while the board's `isReady` reads `blockedBy` only
(`board.ts:465-469`). So **a parent whose children are still open reads `ready:true` and
`tasks:claim` refuses it `blocked`.** That is the design working — a plan root is unclaimable
until its leaves close. Claim leaves, not roots.

---

## 4 — ACT

**`where`+`set` is a DRY RUN by default.** `dryRun` is true unless you say `false` in so many
words (`tasks.ts:2276-2278`). Read `matchedIds`, satisfy yourself they are the rows you meant,
then resend the identical call with `"dryRun":false`.

- The 25-row budget is **shared**: `where` pages at `MAX_BULK − (creates+edits)`
  (`tasks.ts:2525`), and a `where`+`set` sent alongside a full 25 rows errors `too_many`
  (`tasks.ts:2527`). Follow `nextCursor` to continue.
- On a truncated snapshot the envelope adds a `detail` saying **`matched` is a floor, not a
  total** (`tasks.ts:2577-2578`). Quote it that way.
- **Put a `comment` on every change**, saying why — it lands in the task's inbox thread where the
  humans already read. Side effect: **a comment heartbeats a `picked` lease**
  (`tasks.ts:1943-1946`), so commenting on stale `picked` rows fights `tasks:reap`.
- **`ok` is the CALL's outcome, never the rows'** (`tasks.ts:2687-2693`). Read
  `applied` / `failed` / `notAttempted` — a row never attempted says so by name. And `created`
  means **the row exists**, not that its later priority/dueAt/edge writes applied; that row's
  receipt in `results` can still be `ok:false` (`tasks.ts:2682-2684`).
- **Delegate in place** with `tasks:reassign` — never by filing a second task. Under a shared
  gateway key a claim lands as the workspace, so follow `tasks:claim` with
  `tasks:reassign {assignee:"<your slug>"}` or the ledger cannot say who took the row.
- **`tasks:announce` returns `matched`, and matched is NOT delivered** — it is `actors.length`
  from the fan-out (`one.ie/web/src/lib/resolvers/subscriptions.ts:1245` — the cite was
  `:990`, which is a `lane = 'explore'` branch, not a `matched` line at all; `:928` is
  `world:announce`'s). Quote it as reach.

Claim · delegate · chat · chain as a *meeting* is the `meeting` skill and
`.claude/agents/ceo.md § The four verbs`. Go there; don't restate it here.

---

## 5 — CLOSE THE LOOP

The three locked rules, applied to a board turn:

1. **Every signal closes** with `mark`, `warn` or `dissolve` — `tasks:bulk` marks on `applied`
   and warns on `failed` (`tasks.ts:2679-2680`); your *report* closes too.
2. **Structural time.** Tasks → waves → cycles. Never days, hours or weeks.
3. **Deterministic numbers, from the RECEIPT.** `applied` / `failed` / `notAttempted` are
   authoritative. **Do not re-read the board to verify your own write** — it is a KV memo stamped
   `asOf` and `fresh:true` is rate-limited, so it can answer with rows that predate your edit.

---

## The five mistakes

1. **Reading a page as the board** — six tag pages, 353 rows by name, no total. `view:"summary"` first, every time.
2. **Quoting `matched` as delivered** — `tasks:announce` reports reach, not action.
3. **Planning on a truncated board without saying so** — an unmentioned `truncated` turns a floor into a total.
4. **A bulk `ok:true` that hid failed rows** — `ok` is the call; rows live in `applied`/`failed`/`notAttempted`.
5. **Filing a child with `tasks:create`** — claimable, no parent, no ordering. Use `creates` or `tasks:subtask`.

---

## Recipes (valid against the zod)

**A — Plan a feature.** One call, whole tree, ordering included.

```json
{"data":{"workspace":"one","creates":[
 {"ref":"root","title":"Ship voice in chat","notes":"Done when a user can talk to a page and hear a reply","tags":["voice"],"priority":70},
 {"ref":"api","title":"Wire the TTS receiver","parent":"root","notes":"Receiver + contract + test"},
 {"title":"Voice bubble UI","parent":"root","blockedBy":["api"],"notes":"Push-to-talk and hands-free"}]}}
```

**B — Route unowned ready work.** Dry run, read `matchedIds`, then apply.

```json
{"data":{"workspace":"one","where":{"status":"open","ready":true,"assignee":"","tags":["launch"]},
 "set":{"assignee":"cmo","comment":"Routing unowned ready launch work to marketing"},"dryRun":true}}
```
Then the same body with `"dryRun":false`. Follow `nextCursor` until absent; read `applied`.

**C — Sweep a stale tag.** See it first, then dissolve with a reason.

```json
{"data":{"workspace":"one","tags":["q3-experiment"],"status":"active","view":"both","limit":100}}
```
```json
{"data":{"workspace":"one","where":{"tags":["q3-experiment"],"status":"active"},
 "set":{"status":"dissolved","comment":"Superseded by the Q4 plan — dissolved, not done"},"dryRun":false}}
```
A `picked` row in that sweep gets its lease heartbeat by the comment; reap it with `tasks:reap`
rather than commenting it back to life.

**D — Find what is unblockable.** The highest-value rows nobody knows are claimable.

```json
{"data":{"workspace":"one","scope":"tree","status":"blocked","limit":200}}
```
`openBlockers` is already on the compact row — no `include` needed. Keep rows whose
`openBlockers` is `0` or absent, then promote them by name:
```json
{"data":{"workspace":"one","edits":[
 {"tid":"task:<24hex>","status":"open","comment":"Every blocker closed — open and claimable"}]}}
```

**E — The CEO's turn, in its SHIPPED form.** Three calls.

```json
{"data":{"workspace":"one","scope":"tree","view":"summary"}}
```
```json
{"data":{"workspace":"one","where":{"status":"open","ready":true,"assignee":"","scope":"tree"},
 "set":{"assignee":"cto","comment":"Unowned and ready — routing to engineering"},"dryRun":true}}
```
…then the same call with `"dryRun":false`. **Designed, not built:** §6's faster turn
(`changedSince` watermark, `include:["route"]`, `summary.routes` ranked by who staked the tags)
is R9/R11/R12 of `text/tasks-inbox-plan.md` — until those ship, the CEO routes from its keyword
table and its own judgment, and unstaked work stays the CEO's call.

---

## See also

`packages/sdk/src/receivers.ts` — the contract; its `describe()` text is the spec, never invent a
field · `.claude/skills/meeting/SKILL.md` — the room where rows move ·
`one.ie/ai/skills/orchestrate/SKILL.md` — the seats' loop over these verbs · `text/tasks-inbox-plan.md` §5-§6 — the decided
doctrine and the unbuilt rungs.

## Seeing the work — a page of tasks is not the board

**The measured failure.** 2026-09-13: an agent asked for the board, hit a 200-row page,
paged by six tags, found **353 more rows by NAME ONLY**, and never learned the real
total. `tasks:list` has no cap but refuses without a `tag`, so the unfiltered question —
*every task in this group* — had no door at all. The account is in the contract itself
(the `WHY.` block above `"tasks:board"` in `packages/sdk/src/receivers.ts`).

**The door is the CLI, not the MCP and not hand-rolled `ask` calls (2026-09-19).** Read, plan and
edit tasks with `one tasks` — `board` (read), `bulk` (file a plan / edit named rows from a JSON
file), `set` (one edit to every row a filter matches). One process, the page walk done for you,
output to a file so 2,859 rows never enter a context window:

    node packages/cli/dist/src/index.js tasks board --workspace one --tree --all --limit 2000 --include notes --json > board.json

Measured the same day: the whole board in **2 pages / 14.5s**, where the MCP session made a dozen
`tasks_list` / `ask` calls because its server was a stale build that predated `tasks_board`. A
per-row `tasks_create`/`tasks_status` loop is the same mistake in the write direction — use
`tasks bulk` (`creates` chunks at 25) or `tasks set` (preview unless `--apply`). To decide and
sequence, `one tasks brief` is the one-screen digest (approvals excluded and counted, the open
blocker named, stale-DONE rows, next five moves, `total`/`truncated`/`asOf` always) and `one tasks
plan <goal|tag>` orders rows into waves with a hop-count critical path (`--emit dispatch` for
parallel agents); `sequence`/`depend`/`undepend` write the edges (`text/tasks-cli.md`). Reach for the MCP
tool only when no shell is available. **The CLI's `dist/` is a build, not the source** — if
`one tasks` answers `unknown command`, rebuild `packages/sdk` then `packages/cli` first
(§ npm packages); a `node_modules/@oneie/sdk` that resolves to the npm copy instead of the
workspace is the usual cause and its `tsc` errors are phantom.

**One request to read, one request to act.** `tasks:board` returns a whole group's board
(`scope:"tree"` = its whole subtree) plus a `summary` computed over **ALL** matched rows —
byStatus/byTag/byAssignee/byWorkspace, ready, blocked, overdue, unassigned, orphans,
noNotes — so a planner reasons about 2,000 tasks while reading 0 of them (`view:"summary"`).
`tasks:bulk` then moves them: `creates` files a whole plan tree in one call (`ref` handles
resolve within the call), `edits` changes named rows, and `where`+`set` applies one edit to
every row a board filter matches. **A filter-driven write is a dry run by default** — you
read `matchedIds` first, and `dryRun:false` is required in so many words
(`one.ie/web/src/lib/resolvers/tasks.ts:2276-2278`).

**Four honesty fields, each one an obligation.** `total` = rows matching *before* paging,
exact — *unless* `truncated.rows` is present, and then it is a **floor**. `nextCursor`
present ⟺ more rows match; absent = you have them all. `truncated` absent = nothing was
cut; present = **say so in your report** before you plan on it. `asOf` = when the snapshot
was built — it is a 60s KV memo, not a live read, and `fresh:true` is honoured at most once
per window (`one.ie/web/src/lib/tasks/board.ts:182`, `:217-226`). The snapshot is how this
obeys `one.ie/web/src/lib/CLAUDE.md § The brain and the edge`: `loadBoardSnapshot` is the only function that does I/O, and
the TypeDB read happens at most once per memo window, behind the memo — never per request.

**The law this puts on every receiver after it: a short answer must say it is short.**
A silent clamp is worse than a small one — a 595-row queue came back as 200 rows and read
as complete, which is why `tasks:everywhere`'s raised ceiling now ships with `total` and
`truncated` beside it (`resolvers/subscriptions.ts:1100`, `:1203-1204`). A receiver that
caps, pages or samples names the budget that bit, in the response, every time.

Contract: `packages/sdk/src/receivers.ts` — the zod `describe()` text is the spec, never
invent a field. How an agent uses it: `.claude/skills/planning/SKILL.md`. **Designed, not
built:** `changedSince`, `summary.decisions`, `include:["route"]` and the CEO digest are
R9–R12 of `text/tasks-inbox-plan.md` §6 — zod strips undeclared keys, so a payload written
against one degrades silently instead of erroring.

- Don't report a floor as a count — a `total` beside a present `truncated.rows` is a floor, and `tasks:bulk`'s `matched` on a truncated snapshot now says so in a TYPED FIELD you can branch on, not only in prose: `truncated` rides the response in `tasks:board`'s own `{rows, edges, tags}` shape (`resolvers/tasks.ts:3171`), with the human sentence still at `:3169`. **Absent is not `false`** — an untruncated snapshot carries no `truncated` key at all. Quote a floor as "at least N". (The cite here was `resolvers/tasks.ts:2577-2578` until 2026-09-15; those lines are the `tasks:list` header comment.)
- Don't quote `matched` as delivered — `tasks:announce`'s `matched` is `actors.length` from the fan-out (`resolvers/subscriptions.ts:1245`, inside the `'tasks:announce'` block that opens at `:1227`). It is reach, not action. **The cite was `:990` until 2026-09-15 and nothing at `:990` is a `matched` line — it is `lane = 'explore'`.** The neighbouring `matched: actors.length` at `:928` belongs to `world:announce` (opens `:876`), and `:1555` is a third. The contract now says it too: `tasks:announce`'s `matched` carries a `describe()` reading REACH, NEVER DELIVERY
