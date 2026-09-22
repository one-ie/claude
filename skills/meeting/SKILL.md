---
name: meeting
description: Host a meeting in /u/<slug>/in where heads claim, delegate, chat and chain rows — not report. Use whenever the chairman (or any convener) convenes heads on a plan, a board, a blocker, or a launch — "hold a meeting", "convene the team", "get the heads on this", "chairman hosts", "everyone claims tasks", "chain these tasks together", "run the board meeting". Writes a measurement pack, opens ONE thread, spawns heads that must each leave with a tid, and closes with a ledger read back from D1. Refuses a meeting whose output is a document and no moved row.
---

# meeting — the room where rows move

**Purpose:** a meeting is not where heads report. It is where they **take a row, hand a row,
argue on the row, and put the rows in order** — claim · delegate · chat · chain. The output is
the board's diff, not a document.

Shape: `text/template-meeting.md` — **copy it, never write a meeting from scratch.**

```
cp text/template-meeting.md text/meeting-<subject>-<yyyy-mm-dd>.md
```

**Why this skill exists, measured.** On 2026-09-11 four capable agents ran a full board meeting,
produced the best design document in the estate, and **closed zero rows** — net effect **+3**.
On 2026-09-12 five heads were spawned into a session budget that could not carry them and **all
five died mid-orientation**, before one number was reported. Both failures are in the template's
rules. Neither was a failure of the heads.

---

## §0 — THE FOUR LAWS

1. **The room is `/u/<slug>/in`, and there is ONE thread.** A meeting in a session transcript did
   not happen. A meeting whose record lives in `/tmp` dies with the session.
2. **Heads talk to each other, not to the convener.** Cross-examination (§4) is mandatory. Four
   heads reporting upward and never reading each other is four interviews, not a meeting.
3. **A document is not a deliverable. A moved row is.** Grade every attendee on the board, not
   the prose.
4. **Size the spawn to the budget before you write a brief.** Two heads that finish beat five
   that die. The convener checks capacity first; a rate-limited head reports nothing at all.

---

## §1 — THE DOORS  (measured; do not improvise)

| Purpose | Door |
|---|---|
| post to the room | `thread:append` → `{"data":{"slug":"one","group":"space:one","sender":"<agent>","role":"assistant","content":"..."}}` |
| chat on a row | `tasks:comment` → `{"data":{"tid":"task:<24hex>","workspace":"one","body":"..."}}` |
| claim | `tasks:claim` → `{"data":{"tid":"task:<24hex>","workspace":"one"}}` **then** `tasks:reassign` → `{"data":{"tid":"…","assignee":"<your slug>","workspace":"one"}}` — under the shared gateway key every head claims as `@one`; the reassign is what puts YOUR name on the row. One act, two calls |
| delegate, in place | `tasks:reassign` → `{"data":{"tid":"...","assignee":"<slug>","workspace":"one"}}` |
| delegate, to the world | `tasks:announce` → `{"data":{"taskId":"...","tags":["bare","words"],"workspace":"one"}}` |
| chain — split | `tasks:subtask` → `{"data":{"parent":"task:...","title":"...","blockedBy":["task:..."],"workspace":"one"}}` |
| chain — order | `tasks:depend` → `{"data":{"tid":"<blocked>","blockedBy":"<blocker>","workspace":"one"}}` |
| close | `tasks:status` → `{"data":{"tid":"...","status":"done","workspace":"one"}}` |
| see the whole board | `tasks:board` → `{"data":{"workspace":"one","view":"summary","scope":"tree"}}` first (exact `total`, ready/blocked sets, counts — no rows), then `{"data":{"workspace":"one","ready":true,"tags":["<tag>"]}}` for rows; follow `nextCursor`, and say so if `truncated` is present |
| act on many rows | `tasks:bulk` → `creates` (with `ref`s) / `edits` / `where`+`set` — `where` is **dryRun by default**; put a `comment` on every change so the thread records why |
| read the rungs by tag | `tasks:list` → `{"data":{"workspace":"one","tag":"<tag>"}}` — exact tag, any string (`plan:<slug>` for a /do plan's cycle rows), uncapped; answers `{tid,status,name}` only, no assignee |

All writes: `POST https://one.ie/api/ask/<receiver>`, `Authorization: Bearer $GATEWAY_API_KEY`
(from `one.ie/web/.dev.vars`, **not `.env`** — prod refuses the `.env` key), body wrapped in
`{"data":{…}}` or you get `envelope_missing`.

**Read a post back from D1 before claiming it landed:**

```bash
cd one.ie/web && npx wrangler d1 execute one-owners --remote --json --command \
  "SELECT id, role, length(content_json) AS len, substr(content_json,1,80) AS head, ts \
   FROM messages WHERE thread_id='<THREAD>' ORDER BY ts DESC LIMIT 5"
```

### The doors that lie

- **BANNED — `space:post` and `chat:send`.** Both return `ok:true` and write **zero rows**;
  `live:0` is the tell. Six chairman reports were lost to `space:post` on 2026-09-11.
- **`tasks:notes` with an absent `notes` field CLEARS the row.** Reading a note deletes it.
- **`tasks:comment` truncates at 4000 bytes**, silently, and still returns `ok:true`.
- **`tasks:everywhere` is a follow-scoped queue, not the board** — it sorts by weight DESC and
  ignores the `tag` argument, so a weight-0 row can sit below any page. On 2026-09-12 fifteen
  filed rungs were invisible on that read, which is why they had all sat open. **See the board
  with `tasks:board`** (`total` is exact, `truncated` names any cut), or read rungs with
  `tasks:list` by tag. MCP `tasks_list` is one page of `/api/things` — never the whole board.
- **Only the FIRST `@mention` in a comment creates a follow** (no `g` flag,
  `resolvers/tasks.ts:1899`). Three heads pulled in = three separate comments.
- One shape under all of these: **a boundary that is silent on the way past it.** Report the cap
  you hit, always.

---

## §2 — THE PRE-READ  *(the convener writes this BEFORE any head is spawned)*

ONE measurement pack, identical for every attendee, **embedded verbatim in every brief.** Heads
given the same facts cannot drift; heads given only a task description always will.

- [ ] Every number carries the command that produced it.
- [ ] Every claim from a doc or a task note is marked **UNVERIFIED** until re-measured. Stale
      notes are the norm.
- [ ] The pack states what the convener did **not** check.
- [ ] The board's open count is recorded, **with the door that produced it** — a capped read is
      not a count.
- [ ] Capacity checked. Name how many heads the budget carries, and spawn that many.

**THE ONE QUESTION** — one sentence. If you cannot write it, you are calling a status update.

---

## §3 — ROUND 1 · WHAT EACH HEAD MEASURED

```
@<head> — ROUND 1
MEASURED:    <number> — <the exact command>
REFUTES:     <which pack line this contradicts, or "nothing">
DID NOT RUN: <every check skipped — an unrun check is not a pass>
I WAS WRONG ABOUT: <anything from earlier, corrected>
```

**Default REFUTED.** No quotable stopping line ⇒ not proven. A head that reports its own error
unprompted is doing the job.

---

## §4 — ROUND 2 · CROSS-EXAMINATION  *(the round that makes it a meeting)*

Mandatory. The convener does **not** relay it — heads post at each other.

```
@<head> → @<other-head>
YOUR NUMBER: … / MY NUMBER: … / THE GAP: <scoping? door? stale read?> / WHO RECONCILES: <name>
```

On 2026-09-11 one head measured **13** dependency edges and another **259**. Both competent;
neither had read the other. 13 was not a substrate count — it was what a door surfaced, ~5% of
the graph. That gap was the day's most important finding and nearly went unnoticed.

- [ ] Every contested number is reconciled or **explicitly parked with a named owner**.
- [ ] **Nobody quotes a contested number at the board until it is reconciled.**

---

## §5 — CHAIN THE WORK  *(before anyone fans out)*

**Chaining is not bookkeeping — it is what makes the board sequence itself.** `tasks:claim` is
**blocker-gated**, and `tasks:depend` writes the very `blocks` edge that gate reads. An unchained
board hands every head every row at once and nothing knows what comes first. **Chain first, or
the fan-out is a race.**

| verb | use |
|---|---|
| `tasks:subtask` | split a rung — writes row + notes + tags + `containment` + every `blockedBy` in ONE pipeline, so a child never appears claimable with an empty body or missing ordering |
| `tasks:depend` | order two existing rows. Refuses a self-edge and a reverse edge, so a cycle cannot be filed |

**Never split with `tasks:create`** — a child made that way is an orphan somebody claims before
it is ready.

Two rules keep a chain honest, and they are one rule twice:
- **A child's cast is a subset of its parent's.** Inherit by default, declare to narrow, **never
  to widen.**
- **Depth needs a floor.** A parent spawning children while none settle is a leak, not a big
  plan. Freeze the parent's outcome before children mint; let `fade`/`warn` decay what goes quiet.

---

## §6 — DECISIONS

| # | Decision | Owner | Recommendation + the measured reason | tid |
|---|---|---|---|---|

Split honestly:
- **Human-only** — needs a credential, money, or a judgement no measurement settles. **List these
  first, each with a recommendation.** The highest-value output of any meeting is the short list
  of decisions only the operator can make, each made cheap to answer.
- **Head-owned** — if it reached the convener, it was mis-routed. Hand it back.

---

## §7 — CLOSE · EVERY HEAD LEAVES WITH A TID

| Head | tid | Action | If not closed: the ONE thing that would close it |
|---|---|---|---|

Five honest exits, graded differently:

| | |
|---|---|
| **closed** | the row is done and proven |
| **claimed** | taken, in flight, named |
| **delegated** | handed on with `tasks:reassign` — **name who to.** Never by filing a second row |
| **chained** | split or ordered — **name the parent and the edge** |
| **declined** | refused on principle, **with an argument**. Sometimes the best act available |
| **blocked** | by something measured and **named** with a tid or `file:line`. "Blocked" with no named blocker is a shrug |
| **stale** | the row describes a problem that no longer exists. **This IS a close**, often the best outcome. Prove it |
| ⚠️ **artifact, not outcome** | produced a document instead of a change. A failure, however good the document — and the one that most looks like success |

---

## §8 — THE LEDGER  *(the convener posts it; it is the minutes)*

```
MEETING: <subject>    THREAD: <id>    ROWS: <before> → <after>
CLOSED:     <tids>
CLAIMED:    <tid — head>
DELEGATED:  <tid — from → to>
CHAINED:    <parent tid → child tids, and the blockedBy edges>
BLOCKED ON A HUMAN: <tid — the decision, one line>
STILL OPEN: <tid — why, named>
I GOT WRONG: <the convener's own errors, FIRST>
```

Read the ledger back from D1 and quote the row. **The convener is graded too, by name.** A
chairman who edits their own record is worth nothing. If a brief asked for a *report*, the open
row is a **convener** failure — what you ask for is what you get.

---

## Checklist — the convener runs this or the meeting does not start

- [ ] §2 pack written, one copy, embedded verbatim in every brief
- [ ] THE ONE QUESTION in a single sentence
- [ ] Capacity checked; spawn count sized to the budget
- [ ] Thread opened with `thread:append` **and read back from D1**
- [ ] Every brief says **CLAIM · DELEGATE · CHAIN · CLOSE** — never "report" or "return a summary"
- [ ] §4 cross-examination named as mandatory in every brief
- [ ] §5 chaining done before fan-out
- [ ] Board open count recorded before, with the door named
- [ ] §8 ledger posted, read back, convener's own errors first

---

## §9 — THE LEAN FORM  *(default from 2026-09-20 — Tony: "much more streamlined and token efficient")*

The eight sections above are the full form. Use them when heads must **reconcile contested
numbers**. For a build meeting — rows already filed, the question already answered in a doc —
run this instead. Same four laws, a tenth of the tokens.

1. **No meeting file.** The thread is the record; the rows are the minutes. Copy
   `template-meeting.md` only when a decision needs prose a row cannot carry.
2. **One post opens, one post closes.** The opening post IS the pack: ≤ 20 lines of
   `file:line` facts, the ONE QUESTION, the chained tids. The closing post is the §8 ledger.
   **One D1 readback, at close** — not after every post.
3. **Spawn only heads that change bytes.** A head whose output is a post is a cost, not a
   member. The CEO/chairman **convenes and chains**; it is not spawned to attend. A routing
   decision is a `tasks:reassign`, not a head.
4. **Two heads per cycle, in sequence: a builder and a refuter.** The builder's brief carries
   the spec inline (the doc section, by heading) and writes the accept test RED before code.
   The refuter reads the diff and the accept, and either closes the row or comments the one
   thing that blocks. Spec-writer, test-writer and builder collapse into one head when the
   spec already exists in `text/`. Never a fleet.
5. **Heads talk on the ROW, not in the thread.** `tasks:comment`, ≤ 600 chars, one per turn.
   Cross-examination (§4) is the refuter's comment and the builder's reply — two comments,
   not two rounds.
6. **A head's final report is ≤ 15 lines**: tid · files touched · the accept command and its
   exit code · lane run · DID NOT RUN. The convener reads those lines and nothing else; it
   never re-runs a green gate to check it.
7. **The convener embeds, never links.** The brief is self-contained (agents inherit no
   CLAUDE.md): worktree path, the doors as curl lines with the key's FILE PATH, the two
   hooks that bite (`gate-run.sh` for vitest, explicit-path `git add`), the invariant that
   must not break. ~40 lines. A head that has to orient is a head that burns the budget.

Measured cost of the full form on 2026-09-11: four heads, ~1.2M tokens, zero rows closed.
The lean form's floor: two heads per cycle, the accept line's exit code as the only proof.
