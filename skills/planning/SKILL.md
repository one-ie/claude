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

**Use the CLI first.** `one tasks board|bulk|set` (`packages/cli/src/tasks.ts`) is the fast door —
it walks the pages, chunks writes at 25, and previews filter writes unless `--apply`. Pipe `--json`
to a file and filter it with `node -e`/`jq`; never read 2,000 rows through the context window.

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

The raw HTTP door and the MCP tools below are the same receivers; use them only without a shell.
If `tasks` is an unknown command the CLI `dist/` is stale — rebuild sdk then cli.

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
`.claude/agents/ceo.md § Seeing the whole board` · `text/tasks-inbox-plan.md` §5-§6 — the decided
doctrine and the unbuilt rungs.
