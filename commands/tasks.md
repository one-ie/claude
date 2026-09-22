# /tasks

Take what someone wants and make it claimable. One pass: size it, say it in
human words, break it into the pieces its size implies, chain them so only the
first is ready, and hand each to the agent that answers for it.

```
/tasks                      drain every untriaged row on the board
/tasks "<a sentence>"       shape one captured thing
/tasks --dry                show the writes, apply nothing
/tasks --rewrite <tid>      re-say one existing row in human words
```

**Nothing parses those.** This file is instructions to a model, not a CLI —
there is no `tasks.sh`, and the words above are shapes a reader types so the
model knows which leg to run. `--dry` means *pass `dryRun: true` to the
workflow*; `--rewrite <tid>` means *run the shape leg against one existing row
and skip the drain*. Where a flag IS parsed the authority is a script and this
file says so: `do-triage.sh` and `do-tier.sh` below both take real arguments and
both have a real `--self-test`.

Saying that plainly matters here more than usual. A declared interface with no
implementation is the defect this whole command exists to catch — see the
`tasks:bulk` note under **Don't**, which is advertised with a full schema and
answers `unknown_receiver`.

---

## The one rule

**A task is a Want.** Not a label, not a ticket, not a cycle number — the thing
someone wants that is not true yet, written so a stranger knows what changes
when it is done.

`schema/story.tql` makes this the one refusal it enforces: `story_has_want()`,
and its comment — *a story with no Want is a log*. A row that cannot state its
Want is not small, it is **unshaped**, and it goes to `shaping:` rather than to
an agent.

That is what "human sounding" means here, and it is not cosmetic. `lifecycle-human C0`
tells a puller nothing. *A wallet backed up twice loses its key* tells them what
is wrong, who it hurts and when they are finished.

---

## The pipeline

The workflow already exists — **`/tasks` does not reimplement it.**

```
Workflow({ name: "triage", args: { dryRun: <bool>, tasks: [{title}] } })
```

`.claude/workflows/triage.js`, four phases:

| phase | does | cost |
|---|---|---|
| `Untriaged` | `do-rank.py --board-check`, then rows whose notes lack `accept:` | haiku |
| `findPaths` | **`do-triage.sh` first — zero LLM.** A model names paths only if it comes back empty | bash, then haiku |
| `tier` | **`do-tier.sh` on the paths.** Never re-size in JS | bash |
| `reshape` | original words to `tasks:comment` **before** any rename; `accept:` into notes | haiku |

**That order is load-bearing.** The original sentence is preserved as a comment
before anything overwrites the title, because a rewrite that loses what the
person actually said is not a rewrite, it is a deletion.

### What `/tasks` adds

`plannedWrites()` in `triage.js` today writes a comment and a note and **stops**
— it never renames, never makes a subtask, never assigns, never chains. The
workflow's own description says it renames; it does not. `/tasks` is that
missing half, and it runs only on rows the tier phase actually sized:

5. **say** — `tasks:rename` to the Want, in human words
6. **split** — `tasks:subtask` per piece, by tier (below)
7. **chain** — `blockedBy` so exactly one sibling is ready
8. **hand over** — `assignee` from the routing table (below)

A row that reaches step 5 unsized does not get steps 5–8. It gets
`shaping:` and waits for a person.

---

## Sizing decides the shape

`bash .claude/scripts/do-tier.sh --intent "<text>" <paths...>` is the authority.
Never guess a tier, and never let a model pick one.

| tier | subtasks | chained | who |
|---|---|---|---|
| `PATCH` | none — it is one piece | — | `implementer` |
| `FIX` | 2–3, only if they are separately checkable | yes | `implementer`, refuted by `review-engineer` |
| `FEATURE` | one per surface it touches | yes | `architect` writes the spec **first**, then `implementer` |
| `SCHEMA` | one per migration + one to prove it | yes | `architect`, W2 on Fable |
| `UNSIZED` | **none** | — | nobody — it goes to `shaping:` |

### UNSIZED is a state, not a default

`do-tier.sh` exits **3** and returns `{"tier":"UNSIZED","spine":"recon"}` when it
is given no paths, and its own header says why:

> *Absence of recon must not read as simplicity.*

A new task is a sentence with no diff, so **every** fresh capture is UNSIZED
until recon finds files. Two real mis-sizings are on record from treating that as
PATCH (`text/learnings.md:485`, `text/remote-suspend-todo.md:5`). So the pipeline
is **capture → recon → size → agent**, never capture → size → agent. `/tasks`
reports UNSIZED as its own outcome and files nothing under it.

---

## Who answers for it

Routing is by what the work *is*, not by who is free. Category comes from the
paths `do-triage.sh` found.

| paths touch | agent |
|---|---|
| `schema/`, a receiver, an authority walk | `architect` — spec before code |
| a component, a route, a page | `implementer` |
| auth, keys, money, a bounded door | `security-auditor` |
| a gate, a ratchet, a proof | `test-engineer` |
| `text/` only | `tech-writer` |
| a deploy, a release, `.release/` | `release-manager` |
| a measurement, a budget, a clock | `perf-engineer` |
| prod is down | `incident-commander` |
| nothing matches | `cto` — ranks it into a rung and re-routes |

**Every row leaves `/tasks` with an assignee.** An unassigned row is the one that
sits — 219 of 452 rows on this board sat at priority 0 with empty notes and no
owner, and none of them moved. Assigning is not bureaucracy; it is the difference
between a row and a queue.

`agent` never means *autonomous*: `tool → skill → agent` is the autonomy ladder
(root `CLAUDE.md`). A money-moving or authority-changing row gets `human` in its
chain regardless of tier.

---

## Chaining: one ready sibling, not ten

`tasks:subtask` writes the row, its notes, its containment edge **and** its
`blockedBy` in one call — that is why it exists and why two calls are wrong. Its
own contract says it: *between the two calls the child sits on the board
claimable with an empty body and no ordering, and the factory will take it.*

So: subtask N is `blockedBy` subtask N−1, unless they are genuinely independent.
Ten unchained siblings is ten agents claiming the same ground.

Where a real chain already exists, mirror it rather than inventing one —
`lifecycle-human` is `C0 alone → C1 decides → C2 → C5/C6/C7`, with C3, C4 and C8
parallel throughout. That shape came from the plan, not from a rule.

---

## Story · promise · contract — the vocabulary, and what is not wired

The substrate already models this. Read it before inventing a fourth noun:

| word | is | where |
|---|---|---|
| **task** | a Want — what is not true yet | `story_tasks($origin)` |
| **story** | an origin plus its beats: world · cast · knock · want · way · turn · lesson | `story_members`, `story_missing` |
| **promise** | the frozen oath: terms plus exactly one checkable proof | `story_promise($origin)`, `text/promise.md` |
| **contract** | who may admit work here, and what facts are still missing | `contract-admissible`, `missing-facts` |

The arc is `promise → progress → payoff`, read off the promise rung's status
(`story_arc`). Tasks are the Wants between them; `story_next($origin)` picks the
next one the ant-colony way — strongest net trail (`strength − resistance`),
never toxic — and `story_unexplored` is what the colony explores when there is no
trail yet. Priority does not appear anywhere in that decision.

**None of it is wired, and `/tasks` must not pretend otherwise.** Measured
2026-09-12:

- `schema/story.tql` has **no migration** and nothing loads it. Its own header
  says blocks 3–5 are *NOT YET VALIDATED: no TypeDB was reachable from the
  session that wrote them* — 35 functions, unchecked.
- Its only consumer is a **prompt**: `.claude/agents/storyteller.md`.
- The SDK registry carries four story receivers — `story:chain`, `story:demo`,
  `story:event`, `story:view`. **Not one mints an origin or binds a task to a
  story.**
- `story_tasks` matches `has tag $g; $g == $origin` — the binding is a **bare
  tag**. So a renamed row keeps its story only if it still carries that tag, and
  today no row carries one because nothing writes one.

So `/tasks` uses the vocabulary and files rows a story could later adopt. It does
**not** call a story function, and it does not claim a story exists. Wiring it
means: a migration, a receiver that mints an origin, and the 35 functions
validated against a reachable TypeDB — in that order, as its own plan.

---

## Don't

- **Don't set priority.** `triage.js` refuses to, on purpose. The board ranks by
  learned weight where it has evidence; an authored number competes with a
  measurement and usually wins for the wrong reason. This board had 219 rows at
  priority 0 including *the ladder cannot be climbed* and *tasks:comment silently
  truncates*, and a panel layout tweak at 1.00.
- **Don't rename before the original text is a comment.** `tasks:comment`
  truncates at 4,000 bytes and returns `ok:true`, so a long capture must be split
  and read back, not trusted.
- **Don't clear notes by omission.** `tasks:notes` with an absent `notes` key is
  a silent DELETE returning `{ok:true, notes:null}`. Read-modify-write, always,
  with the full body.
- **Don't reach for `tasks:bulk`.** It is advertised by the MCP server with a
  full schema and answers `unknown_receiver` in production. One call per row.
- **Don't add a second sizing path or a second triage door.** `do-triage.sh` and
  `do-tier.sh` are the two, and both have `--self-test`.
- **Don't size from a title.** `do-tier.sh` sizes a **diff**. "Add a null check"
  and "add a settings page" share a verb.

---

## See also

- `.claude/workflows/triage.js` — the pipeline this command drives
- `.claude/scripts/do-triage.sh` · `do-tier.sh` — the two authorities, both `--self-test`
- `text/board-review-2026-09-12.md` — where the defects quoted above were measured
- `text/story-framework.md` · `schema/story.tql` — the vocabulary, unwired
- `.claude/commands/do.md` — what claims a shaped task and builds it
