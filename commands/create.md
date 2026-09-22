# /create

**Skills:** `/typedb` (write new entity) · `/signal` (emit creation, `ui:*` or `cli:create:*`)

Emit a new entity into the substrate.

## Nouns

| Noun | What | Loop |
|------|------|------|
| `task <name> [--tags T] [--weight W]` | Atomic task into TypeDB via API | L1 |
| `todo <source-doc?>` | TODO from template (Haiku extract + wave structure) | L1 |
| `agent <markdown-file>` | Parse agent.md frontmatter → TypeDB unit + skills | L1 |
| `signal <receiver> <data>` | Ad-hoc signal emission for testing | L1 |

## Routing

`/create` maps to `send()` — emit new entity or signal into the substrate.
Every noun writes to TypeDB and/or the in-memory queue.

| Noun | Primitive | Destination |
|------|-----------|-------------|
| task | `send()` | POST `/api/ask/tasks:create` (MCP tool `tasks_create`) |
| todo | `send()` | Write `text/{name}-todo.md` |
| agent | `send()` | `agent-md.ts` → TypeDB unit + skills + capabilities |
| signal | `send()` | POST `/api/signal/<receiver>` |

**Not built (do not invoke) — verified 2026-08-02:** `POST /api/tasks` and
`POST /api/tasks/sync`. There is no `/api/tasks*` route at all. The
`sync-todo-docs.sh` hook that best-effort-POSTed `/api/tasks/sync` was removed
2026-09-05 — it only ever no-op'd.

## Steps

### task

1. Parse `$ARGUMENTS` into task fields:
   - id (kebab-case from name), name
   - value: critical / high / medium
   - phase: C1-C7
   - persona: ceo / dev / investor / gamer / kid / freelancer / agent
   - tags (space-separated), blocks (other task IDs), exit condition
2. Compute priority: value + phase + persona + blocking weight (max 115, min 35)
3. POST to `http://localhost:4321/api/ask/tasks:create` with body
   `{ title, notes?, tags?, assignee?, workspace? }` — the `tasks:create` receiver
   (`packages/sdk/src/receivers.ts`). It writes one open task and announces it by
   its tags in the same act, returning the new `tid`. Tags are plain words: `:` and
   `@` are reserved for `workspace:`/assignee namespaces.
   Equivalent: the MCP tool `tasks_create`.
4. Confirm created task: tid, title, priority score + formula, tags
5. Suggest `/see tasks` to view ranked list

### todo

1. Resolve source doc from `$ARGUMENTS`: try full path → `text/$ARGUMENTS` → `text/$ARGUMENTS.md`. All docs live in `text/` — there is no `one/` directory, and `docs/` holds only two unrelated files.
2. Run Haiku one-shot to extract raw tasks (~$0.004):
   - Read doc, extract actionable items as checkbox tasks with metadata
3. Load base context: `text/dictionary.md`, `text/rubrics.md`, `text/template-todo.md`
4. Promote raw tasks into full wave template:
   - Group by cycles (Wire → Prove → Grow) and waves (W1=Haiku, W2=Opus, W3=Sonnet, W4=Sonnet)
   - Assign full metadata per task: id, value, effort, phase, persona, blocks, exit, tags
   - `outcome:` — when a promise exists (`text/<slug>.md` with `proof:`), the todo's `outcome:` is the promise's `proof:`, verbatim — never restated loosely
   - Include: routing diagram, schema reference, wave structure, rubric scoring in W4, self-checkoff
5. Write `text/{docname}-todo.md` — always by copying `text/template-todo.md` first (`cp text/template-todo.md text/{docname}-todo.md`), never from scratch; the template encodes the frontmatter contract `/do` reads at plan start
6. Verify: all tasks have 7 metadata fields, blocks references are valid, exit conditions are verifiable
7. Report: cycle count, tasks per cycle, critical path, cost estimate

### agent

1. Read `<markdown-file>` (frontmatter: name, model, channels, group, skills, sensitivity)
2. Parse via the shipped parser — `one.ie/web/src/lib/agent-md.ts` or `channels/src/lib/agent-md.ts` (there is no `src/engine/agent-md.ts`) → `AgentSpec`
3. Sync to TypeDB:
   - Unit: uid, name, model, system-prompt, tags
   - Skills: skill-id, name, price, tags per skill
   - Capabilities: (provider: unit, offered: skill) relation
   - Group membership: (group: $g, member: unit) relation
4. Report: uid, model, skills count, group, TypeDB insert count

### signal

1. Parse `<receiver>` and `<data>` from `$ARGUMENTS`
   - receiver: string (e.g. `bob:schema`, `analyst`)
   - data: JSON or plain string
2. POST to `http://localhost:4321/api/signal/<receiver>` with `{ data }` — the receiver is a **path segment**, not a body field (`src/pages/api/signal/[receiver].ts`, with `[...receiver].ts` handling multi-segment names)
3. Report: signal sent, response outcome (result / timeout / dissolved / failure), any path marks triggered

---

*Every `/create` is a `send()` call — a new signal enters the world.*
