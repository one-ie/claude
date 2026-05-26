---
title: Memory UI — load company + customer context into the substrate
slug: memory-ui
type: plan
tier: complex
mode: construction
tags: [memory, ui, signals, hypothesis, company-context, customer-context]

parallel_budget:
  haiku:   10
  sonnet:  6
  opus:    1

batches:
  - [C0]                        # schema extension — memory-of relation (company + author)
  - [C1]                        # read-only browser — sidebar + page + list
  - [C2]                        # write path — assert via signal dispatch
  - [C3]                        # per-row actions — verify, erase

shared_recon:
  - schema/world.tql                    # actual deployed hypothesis shape (line 233-244)
  - schema/one.tql                      # dimension index — workspace-binding mechanism lives here
  - agents/src/substrate.ts             # rememberHypothesis + recallHypotheses — production write/read shape
  - one.ie/web/src/lib/substrate.ts
  - one.ie/web/src/lib/menu.ts
  - one.ie/web/src/pages/api/signal/[...receiver].ts
  - one.ie/web/src/pages/api/CLAUDE.md

source_of_truth:
  - schema/world.tql
  - one.ie/web/src/pages/api/CLAUDE.md
  - one.ie/web/src/lib/substrate.ts
  - agents/src/substrate.ts

existing_primitives:
  - one.ie/web/src/lib/substrate.ts: typedbQuery(tql, write?) hits api.one.ie via GATEWAY_API_KEY — read & write both supported; writeSignal records signal-row
  - one.ie/web/src/lib/menu.ts: getUserMenu(slug, viewer, ...) returns MenuGroup[]; viewer-gated; submenus supported — C1 extends this, does NOT add a new menu module
  - one.ie/web/src/pages/api/signal/[...receiver].ts: generic signal endpoint; writes signal, forwards to NANOCLAW_URL — C2 extends with receiver-prefix dispatch for memory:*
  - one.ie/web/src/components/ai-elements/prompt-input-textarea.tsx: PromptInputTextarea — C2 composes for the single-sentence input (NOT prompt-input.tsx)
  - one.ie/web/src/components/ui/: Card, Badge, Drawer, Button, Icon, dropdown-menu — C1/C2/C3 compose these, never reimplement
  - one.ie/web/src/lib/role-check.ts: read_memory / delete_memory actions already in RoleAction union — C1/C3 reuse for role gates
  - one.ie/web/src/lib/in/role-gates.ts: gateSignalByRole(receiver, viewer) — receiver-level role gating for the signal endpoint; C2/C3 extend
  - one.ie/web/src/layouts/Layout.astro: the only layout — C1 wraps page in it
  - agents/src/substrate.ts:rememberHypothesis: production insert pattern — C2 cribs the TypeQL shape verbatim (extended attrs from world.tql)
  - schema/world.tql line 233-244: hypothesis entity (hid, statement, hypothesis-status, observations-count, p-value, action-ready, source, scope, observed-at, valid-from, valid-until) — the deployed shape

show: false

escape:
  condition: "C0 W3: defining the memory-of relation against the deployed TypeDB gateway fails OR a follow-up query confirms the relation was not committed."
  action: "halt; investigate whether schema writes need elevated gateway credentials or a different deploy path (wrangler vs scripts/migrate-typedb-root.ts). Do not let C1/C2/C3 proceed against a schema without memory-of."

context_triggers:
  - pattern: "hypothesis|memory:"
    inject: "schema/world.tql § entity hypothesis (line 233-244) — the deployed shape, NOT the abbreviated one.tql:185 stub"
  - pattern: "signal|receiver"
    inject: "one.ie/web/src/pages/api/CLAUDE.md § The four universal endpoints"
  - pattern: "scope|workspace|tag"
    inject: "schema/world.tql § attribute scope (line 454) — value is enum 'private|group|public', NOT a slug. Workspace identity needs a relation."
---

# Memory UI

**The job this UI does:** load **context about the company and customers** into the substrate so every agent reply can pull from it. Brand voice, product facts, pricing, policies, customer history — facts that today live in the operator's head get persisted as hypothesis rows that agents read on the next turn.

**Goal:** Ship a memory surface inside `one.ie/web/` — sidebar entry, list page, single-sentence assert, per-row verify/forget — all routed through the signal-receiver grammar (`/api/signal/memory:*`), no new route families, no agents/ changes required.

**Exit:** From `/u/{slug}/memory/`, an operator types "our brand voice is calm and technical" → presses Enter → row appears with derived confidence 0.30 (source = "asserted", p-value ≈ 0.70) → operator clicks ⋯ → Verify → row promotes to derived confidence 0.85 (source = "verified", p-value ≈ 0.15) → the next agent reply for that workspace quotes the fact. Verified by running all three cycle demos: `bun vitest run one.ie/web/tests/e2e/memory-ui-c1.test.tsx one.ie/web/tests/e2e/memory-ui-c2.test.ts one.ie/web/tests/e2e/memory-ui-c3.test.ts`.

**Scope-defending rule for every cycle:** if a feature doesn't make it faster to add a company-or-customer fact (or faster for an agent to read one), it's out of this plan.

---

## Why this plan exists

The prior `memory-ui-todo.md` was written against `apps/dev.one.ie/nanoclaw/` (now `plans/dev/`). That codebase has `agents/src/units/`, `.on(signal, handler)` dispatch, and `agents/core/*.md` markdown unit definitions. **None of that exists in `one-ie/`.** This plan targets the actual `one-ie/one.ie/web/` architecture:

- Receiver namespace IS the API (`api/CLAUDE.md`). No new `/api/memory/*` route family.
- Signal endpoint already exists; extend with receiver-prefix dispatch for `memory:*`.
- Web `lib/substrate.ts` can write to TypeDB directly via `typedbQuery(tql, write=true)`. No worker required.
- `agents/` worker is left untouched. If/when it later gains a `memory:assert` handler, web's inline dispatch becomes redundant — but the UI stays.

---

## Four cycles, narrow scope

| Cycle | What ships | What it does NOT ship |
|---|---|---|
| **C0** | Schema extension: `memory-of` relation in `schema/world.tql` ties every hypothesis to a company (required) and an author (optional). Deployed to the production TypeDB gateway. | no UI, no API, no handlers |
| **C1** | Sidebar Memory entry · `/u/[slug]/memory/` page · read-only `MemoryList` island — reads via `memory-of` scoped to the viewer's company + their own user memories | no write path, no per-row actions |
| **C2** | `POST /api/signal/memory:assert` with inline dispatch → TypeDB hypothesis insert + `memory-of` link · `MemoryInput` island | no extraction pipeline, no batching, no LLM |
| **C3** | `POST /api/signal/memory:verify` + `POST /api/signal/memory:erase` · ⋯ menu on each row | no agent self-emit, no connectors |

**Scope model (locked by C0):**
- Every hypothesis links to **one company** (`group`) via `memory-of:company` — mandatory
- Every hypothesis optionally links to **one author** (`actor`) via `memory-of:author` — set when a user typed it; absent when emitted by an agent or system
- A viewer sees memories where `company = their workspace` OR `author = their user` — companies never leak across workspaces, private user notes never leak across users
- Promotion path: a user-authored memory can be promoted to company-shared by C3's Verify (drops the `author` link OR keeps it as audit while adding visibility to the company)

Deferred (need `agents/` scope, not in this plan): paste-anything pipeline · in-chat card · agent appetite · agent self-emit · connectors. If `agents/` reopens, those go in `agents-memory-todo.md`.

---

## Status

```
Batch 0 (shared)
  - [ ] W0 baseline (plan-level)
  - [ ] W1 shared recon (plan-level)

Batch 1
  - [ ] C0 — memory-of schema extension          state: ready
    - [ ] W1 · W2 · W3 · W4

Batch 2 (fires after C0 closes)
  - [ ] C1 — read-only memory page                state: blocked-on-C0
    - [ ] W1 · W2 · W3 · W4

Batch 3 (fires after C1 closes)
  - [ ] C2 — assert via signal dispatch           state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4

Batch 4 (fires after C2 closes)
  - [ ] C3 — per-row verify + erase               state: blocked-on-C2
    - [ ] W1 · W2 · W3 · W4

Plan close
  - [ ] Final compress sweep
  - [ ] Append entry to plans/learnings.md
  - [ ] Plan rubric ≥ 0.65
```

---

## C0 — `memory-of` schema extension  [tier: complex · batch: 1]

**Exit:** `schema/world.tql` declares a `memory-of` relation linking hypothesis to group (company, mandatory) and actor (author, optional); the relation is deployed to the TypeDB gateway and a smoke query confirms it can be inserted + matched.

**Demo gate:**
```yaml
demo:
  command: "bun run one.ie/web/scripts/smoke-memory-of.ts"
  asserts:  "insert a hypothesis + memory-of(company,author); match it back; both roles bind"
  budget:   "<3s wall · <60 LOC test script"
```

### W1 — Recon  [Haiku · parallel]

1. **Schema-state recon (mandatory):**
   - [ ] `schema/world.tql` — lines 230-244 (current hypothesis def); lines 162-170 (group); lines 42-66 (actor) — confirm exact `plays` clause locations to add new lines
   - [ ] `schema/one.tql` — confirm `group` entity definition + the `gid @key` attribute name used to identify a workspace
   - [ ] grep `schema/world.tql` for existing `relation X, relates fact, relates owner` patterns to match style (line up with existing relation conventions)

2. **Deployment-path recon (mandatory — without this we can't ship the change):**
   - [ ] `one.ie/web/scripts/migrate-typedb-root.ts` — read end-to-end; what does it actually do? Does it execute `define` queries against the gateway?
   - [ ] `one.ie/web/scripts/seed-typedb.ts` — same; understand its envelope
   - [ ] `one.ie/web/src/lib/substrate.ts:typedbQuery` — does the gateway accept `define` queries when `write=true`, or is schema deploy a separate endpoint?
   - [ ] `api/src/index.ts` — the gateway worker; grep for `define\|schema` handlers to confirm the deploy path
   - [ ] Grep monorepo for `GATEWAY_API_KEY` usage in any schema-deploy script

3. **Existing-actor-id recon:**
   - [ ] How is a logged-in user's actor id resolved server-side? `one.ie/web/src/middleware.ts` (`locals.session`?), `lib/passkey.ts`, or `lib/human-actor.ts`. Memory writes need this on the request path.

### W2 — Decide  [Opus]

- [ ] **Relation file location** — append to `schema/world.tql` (single-file schema) OR new `schema/memory.tql` (composable layer). Decide based on whether other relations are split into files today.
- [ ] **Relation shape — lock the TypeQL:**
  ```typeql
  relation memory-of,
      relates fact     @card(1),     # exactly one hypothesis per memory-of
      relates company  @card(1),     # exactly one group — mandatory
      relates author   @card(0..1);  # zero or one actor — optional (system/agent writes may omit)
  ```
  And the `plays` additions:
  ```typeql
  entity hypothesis,
      ...                            # existing attrs unchanged
      plays memory-of:fact;          # NEW
  entity group,
      ...                            # existing attrs unchanged
      plays memory-of:company;       # NEW
  entity actor,
      ...                            # existing attrs unchanged
      plays memory-of:author;        # NEW
  ```
- [ ] **Identifier conventions** — confirm `group.gid` is the workspace's `slug` (so `gid = "{slug}"` in match clauses). If gid encoding differs (e.g. `group:slug` prefix), document the resolver C1/C2 will use.
- [ ] **Deployment method** — single `define` query through the gateway? Or a script step in `scripts/migrate-typedb-root.ts`? Pick one and document. The smoke test in W4 runs this method end-to-end.
- [ ] **Rollback** — if the define succeeds but smoke fails, what's the rollback? Likely `undefine` queries — or accept the relation as forward-only and fix-forward. Document.
- [ ] **Diff specs output**

### W3 — Edit  [Sonnet · parallel + a deploy step]

**W3a — independent:**
- [ ] `schema/world.tql` (or `schema/memory.tql`) — add the `relation memory-of` block + the three `plays` lines as decided in W2
- [ ] `one.ie/web/scripts/smoke-memory-of.ts` — the W4 demo script: insert a test group + actor + hypothesis + memory-of; match it back asserting both roles bind; clean up
- [ ] `one.ie/web/src/lib/substrate.ts` — add `linkMemoryOf(env, hid, gid, actorAid?)` helper that issues the `insert (...) isa memory-of` query (C2 will call this from the signal-handler)

**W3b — dependent (must follow W3a's schema commit):**
- [ ] Run the deploy step (W2's chosen method) against the gateway — adds the relation to the live schema
- [ ] Re-run smoke script; assert exit 0

### W4 — Verify  [Haiku × 5 — complex tier, schema surface]

- [ ] `cd one.ie/web && bun run verify` green (no type/test regressions from the lib helper)
- [ ] Demo gate exits 0 (smoke script confirms relation works end-to-end)
- [ ] **Schema-deploy audit:**
  - [ ] `match $r isa relation, has $name "memory-of"; ...` returns 1 row from the gateway
  - [ ] A direct query `match (fact: $h, company: $g, author: $a) isa memory-of; ...` parses without error
  - [ ] No other relations were modified (`git diff schema/` shows only the planned additions)
- [ ] **Live verification:** post-deploy, the same smoke insert/match runs against the production gateway URL (not a local stub)
- [ ] Composite ≥ 0.65 — targets: **stability ≥ 0.95** (schema is forever) · security ≥ 0.85 · simplicity ≥ 0.90 · speed ≥ 0.80

Report: `relation_added=memory-of  plays_added=3  smoke_passed=Y|N  gateway_url=...`

---

## C1 — read-only memory page  [tier: simple · batch: 2]

**Exit:** Logged-in user lands on `/u/{slug}/memory/`, sees a list of hypothesis rows for their scope, with statement + confidence badge + observations count. Sidebar shows a Memory entry under their workspace nav.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run one.ie/web/tests/e2e/memory-ui-c1.test.tsx"
  asserts:  "Memory page renders N seeded hypothesis rows from typedbQuery"
  budget:   "<2s wall · <80 LOC test"
```

### W1 — Recon  [Haiku · parallel]

Workspace + user scoping is shipped by C0's `memory-of` relation. C1 W1 only needs to confirm the relation deployed and find the existing pattern for resolving the viewer's actor id and workspace gid in an Astro page.

1. **C0-output verification:**
   - [ ] Hit the gateway: `match $r isa memory-of; ...` — confirm the relation exists in production schema
   - [ ] Read `one.ie/web/src/lib/substrate.ts:linkMemoryOf` (C0 output) — confirm signature C2 will use

2. **Existing-code recon**
   - [ ] `one.ie/web/src/lib/substrate.ts` — confirm `typedbQuery` read signature; check for existing `selectHypotheses` helper
   - [ ] `one.ie/web/src/lib/menu.ts` — `getUserMenu` shape (main array, submenus, viewer gates) — verified at recon time: viewer values `'owner'|'agency'|'client'|'end_user'`
   - [ ] `one.ie/web/src/pages/u/[slug]/` — pick the closest existing page as the layout template (e.g. `/u/[slug]/in/index.astro` or `/u/[slug]/dashboard.astro`)
   - [ ] `one.ie/web/src/middleware.ts` — confirm `locals.workspaceContext` carries `slug` + viewer
   - [ ] `schema/world.tql` lines 233-244 — re-confirm the deployed hypothesis attribute set (hid · statement · hypothesis-status · observations-count · p-value · action-ready · source · scope · observed-at · valid-from · valid-until)

3. **Primitive-inventory recon**
   - [ ] `one.ie/web/src/components/ui/` — confirm `Card`, `Badge`, `Button`, `Icon`, `dropdown-menu` shipped
   - [ ] `one.ie/web/src/components/` — grep for any existing list-pattern (`Inbox`, `Feed`, `List`) we should compose instead of reinventing

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict** filed per proposed file
- [ ] **TypeQL read query** finalized — disjunctive scope: company OR author. Sketch:
  ```typeql
  match $h isa hypothesis, has statement $s, has source $src, has hypothesis-status $st, has observations-count $oc;
  { (fact: $h, company: $c) isa memory-of; $c has gid "{slug}"; } or
  { (fact: $h, author:  $a) isa memory-of; $a has aid "{actorAid}"; };
  not { $h has hypothesis-status "rejected"; };
  sort $oc desc; limit 200;
  ```
  This shows the viewer everything their company owns AND everything they personally authored. No leak across companies; no leak across users for private rows.
- [ ] **Page hydration choice** — SSR fetch in `.astro` frontmatter (preferred — viewer-gated, no client fetch) OR `client:only` island with `useEffect`
- [ ] **Role gate** — `read_memory` (already in role-check.ts) via existing pattern from another auth-gated workspace page
- [ ] **UI distinction** — `MemoryRow` renders a "private" badge when the row has only `author` and no `company` link (or `company` differs from viewer's workspace); a "company" badge when shared. Decided here so C3's Verify (promote to company-shared) has a clear visual delta.
- [ ] **Diff specs output**

Proposed new files (≤4):

| File | Closest primitive | Verdict |
|---|---|---|
| `one.ie/web/src/pages/u/[slug]/memory/index.astro` | sibling page in `u/[slug]/{surface}/index.astro` | **new** — page route, no equivalent |
| `one.ie/web/src/components/memory/MemoryList.tsx` | `Card` + `Badge` + array.map | **compose** — slot-fill, no parallel `<List>` |
| `one.ie/web/src/components/memory/MemoryRow.tsx` | `Card` + `Badge` | **compose** — one row per Card, identical to other list-row patterns in the codebase |
| `one.ie/web/src/lib/memory-query.ts` | extension of `lib/substrate.ts` | **extend** — add `selectHypotheses(env, scope)` to substrate.ts instead of a new file UNLESS substrate.ts is already ≥200 LOC and we want to keep its scope tight. W2 decides. |

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/lib/menu.ts` — add `Memory` entry to `getUserMenu` (viewer: `['owner','agency','client']`)
- [ ] `one.ie/web/src/components/memory/MemoryList.tsx` — composes `Card` + `Badge` + a confidence color helper
- [ ] `one.ie/web/src/components/memory/MemoryRow.tsx` — one hypothesis per `Card`
- [ ] `one.ie/web/src/pages/u/[slug]/memory/index.astro` — SSR fetch via `typedbQuery`, mounts `MemoryList`
- [ ] `one.ie/web/src/lib/substrate.ts` — append `selectHypotheses(env, scope)` (or new helper file per W2 verdict)
- [ ] `one.ie/web/tests/e2e/memory-ui-c1.test.tsx` — render `MemoryList` with seeded rows, assert N cards with statement text

### W4 — Verify  [inline composite — simple tier]

- [ ] `cd one.ie/web && bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate exits 0
- [ ] **Reuse audit:**
  - [ ] `grep -l "from '@/components/ui/card'" one.ie/web/src/components/memory/` returns 1+
  - [ ] No new `<textarea>`, `<dialog>`, `<modal>` in `components/memory/` (`grep -nE "<textarea|<dialog|<modal" one.ie/web/src/components/memory/` returns 0)
  - [ ] `wc -l` new files ≤ 300
- [ ] Composite ≥ 0.65 — targets: security ≥ 0.90 · stability ≥ 0.85 · **simplicity ≥ 0.90** · speed ≥ 0.80

Report: `delta_tsc=±N  delta_loc=+N  new_files=N`

---

## C2 — assert via signal dispatch  [tier: complex · batch: 3]

**Exit:** `curl -X POST /api/signal/memory:assert -d '{"statement":"x","scope":"group:{slug}"}'` returns 202 with `signalId`, a hypothesis row with that statement appears in TypeDB, and reloading the C1 page shows it. The Inbox input on the memory page performs the same call with one keystroke (Enter).

**Demo gate:**
```yaml
demo:
  command: "bun vitest run one.ie/web/tests/e2e/memory-ui-c2.test.ts"
  asserts:  "POST /api/signal/memory:assert → typedbQuery for hypothesis with that statement returns ≥1 row"
  budget:   "<3s wall · <120 LOC test"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `one.ie/web/src/pages/api/signal/[...receiver].ts` — current dispatch shape (writeSignal + NANOCLAW_URL forward); confirm there's no per-receiver branch logic yet
   - [ ] `one.ie/web/src/lib/in/role-gates.ts` — `gateSignalByRole(receiver, viewer)` — what role does `memory:assert` need? (likely `member` or higher)
   - [ ] `one.ie/web/src/lib/substrate.ts` — confirm writeSignal signature + `typedbQuery(... write=true)` works for inserts
   - [ ] `one.ie/web/src/components/ai-elements/prompt-input-textarea.tsx` — confirm `PromptInputTextarea`'s `onSubmit` / `onKeyDown` surface
   - [ ] `agents/src/substrate.ts` — re-read `rememberHypothesis()` to crib the TypeQL insert shape; reconcile against locked one.tql attributes (the agents/ version uses extended attrs — see escape clause)

2. **Primitive-inventory recon**
   - [ ] grep for an existing `signal-handlers/` or `signal/dispatchers/` directory pattern — if it exists, extend; if not, decide where the dispatch table lives

### W2 — Decide  [Opus]

Hard architectural decisions — write them down:

- [ ] **Dispatch location** — inline in `signal/[...receiver].ts` (switch on receiver prefix) OR new `lib/signal-handlers/memory.ts` invoked from that route. Pick based on whether other receivers (`crm:`, `chat:`) will need the same pattern. If yes → `lib/signal-handlers/{namespace}.ts` module. If no → inline.
- [ ] **TypeQL insert shape** — match the deployed schema in `schema/world.tql:233-244`. Crib `agents/src/substrate.ts:rememberHypothesis` verbatim (it's production-correct): writes `hid, statement, hypothesis-status, observations-count, p-value, source, observed-at`. THEN call `linkMemoryOf(env, hid, viewer.workspaceGid, viewer.actorAid)` from C0 to bind both company + author.
- [ ] **Visibility default** — when an operator types into MemoryInput, do we link both `company` AND `author` (visible to everyone in the workspace + audited as theirs), or only `author` (private until promoted)? Recommend: **default to both** (company-shared by default) since the load-bearing job is loading company context. Add an optional "private" toggle on the input that drops the company link. Decide explicitly here.
- [ ] **Confidence model** — production schema uses `p-value` not `confidence`. The agents/ reader derives `confidence = 1 - p-value`. So "asserted at 0.30 confidence" = `p-value = 0.70`. "Verified at 0.85 confidence" = `p-value = 0.15`. Document this mapping once in the handler.
- [ ] **Default values for an asserted memory** — `hypothesis-status = "confirmed"` · `observations-count = 1` · `p-value = 0.70` (≈ 0.30 confidence) · `source = "asserted"` · `scope = "group"` (the enum value) · `observed-at = Date.now()`. Followed by the `memory-of` link insert.
- [ ] **Idempotency** — dedupe by `(statement, workspace-binding)`? Insert always with a unique `hid` from `crypto.randomUUID()`? Pick one; document.
- [ ] **Auth** — `gateSignalByRole('memory:assert', viewer)` must allow `member|admin|owner`. Confirm or extend `lib/in/role-gates.ts`.
- [ ] **Failure mode** — `signal/[...receiver].ts` dispatches inside `ctx.waitUntil(sideEffects)` — the route returns 202 BEFORE the TypeDB insert finishes. The demo test (C2 W4) MUST poll or await the side-effect promise. Decision: do we (a) make the dispatch synchronous (changes the signal-route contract — likely wrong), or (b) keep async + test polls? Default: (b). The 202 already means "queued", not "committed".
- [ ] **Cross-check agents/ recall path** — `agents/src/substrate.ts:recallHypotheses` filters by `$s contains "<searchTerm>"` and `$st != "rejected"`. Our writes must NOT set `hypothesis-status = "rejected"` and must use a string `statement` the agent's recall search term can match (no JSON encoding). Verify the demo test exercises this path end-to-end.
- [ ] **Diff specs output**

Proposed new files / extensions:

| File | Closest primitive | Verdict |
|---|---|---|
| `one.ie/web/src/pages/api/signal/[...receiver].ts` | itself | **extend** — add receiver-prefix dispatch |
| `one.ie/web/src/lib/signal-handlers/memory.ts` | `agents/src/substrate.ts:rememberHypothesis` | **new** — but lifts logic from existing rememberHypothesis; one file, ≤60 LOC |
| `one.ie/web/src/lib/in/role-gates.ts` | itself | **extend** — add `memory:assert` row if missing |
| `one.ie/web/src/components/memory/MemoryInput.tsx` | `PromptInputTextarea` | **compose** — single-sentence input, Enter submits |
| `one.ie/web/src/pages/u/[slug]/memory/index.astro` | C1 output | **extend** — slot `MemoryInput` above `MemoryList` |

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/lib/signal-handlers/memory.ts` — `dispatchMemory(receiver, data, env)`; first case: `memory:assert` → insert hypothesis
- [ ] `one.ie/web/src/pages/api/signal/[...receiver].ts` — extend `sideEffects` with `if (receiver.startsWith('memory:')) dispatchMemory(...)`
- [ ] `one.ie/web/src/lib/in/role-gates.ts` — confirm/add `memory:assert` requires `member`+
- [ ] `one.ie/web/src/components/memory/MemoryInput.tsx` — composes `PromptInputTextarea`, `onSubmit` → fetch `/api/signal/memory:assert`
- [ ] `one.ie/web/src/pages/u/[slug]/memory/index.astro` — mount `MemoryInput` above `MemoryList`
- [ ] `one.ie/web/tests/e2e/memory-ui-c2.test.ts` — POST signal, typedbQuery, assert row exists

**W3b — dependent:** (only if dispatch location is inline rather than module — then no W3b needed)

### W4 — Verify  [Haiku × 5 — complex tier]

- [ ] `cd one.ie/web && bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate exits 0
- [ ] **Reuse audit:**
  - [ ] `grep -l "from '@/components/ai-elements/prompt-input'" one.ie/web/src/components/memory/MemoryInput.tsx` returns 1
  - [ ] No new HTTP route family (`ls one.ie/web/src/pages/api/memory/` returns nothing — the rule)
  - [ ] No vector / embedding / chunk mention (`grep -rEi "vector|embedding|chunk|top-k" one.ie/web/src/lib/signal-handlers/ one.ie/web/src/components/memory/` returns 0)
  - [ ] `wc -l` new files ≤ 400
- [ ] **Live verification (deploy surface — signal/ is /api/**):** post-deploy smoke `curl -s -o /dev/null -w "%{http_code}" -X POST $DEPLOY/api/signal/memory:assert -H 'Content-Type: application/json' -d '{"statement":"smoke","scope":"group:demo"}'` returns 202 or 401 (never 500)
- [ ] Composite ≥ 0.65 — targets: **security ≥ 0.95** (signal endpoint is auth-gated) · stability ≥ 0.85 · simplicity ≥ 0.85 · speed ≥ 0.80

Report: `delta_tsc=±N  delta_loc=+N  assert_p95_ms=N`

---

## C3 — per-row verify + erase  [tier: simple · batch: 4]

**Exit:** Clicking ⋯ on a row exposes Verify (sets `source = "verified"` and drops `p-value` to ≈ 0.15 — i.e., promotes derived confidence from 0.30 to 0.85, available to operator viewers) and Forget (deletes the hypothesis). Both route through `/api/signal/memory:verify` and `/api/signal/memory:erase` using the same dispatch pattern as C2. Receiver named `erase` not `forget` to avoid visual collision with the existing `/api/forget/` GDPR route.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run one.ie/web/tests/e2e/memory-ui-c3.test.ts"
  asserts:  "memory:verify flips source→verified and p-value≤0.15; memory:erase removes the row"
  budget:   "<2s wall · <100 LOC test"
```

### W1 — Recon  [Haiku · parallel]

- [ ] `one.ie/web/src/components/ui/dropdown-menu.tsx` — confirm ⋯ menu primitive shipped
- [ ] `one.ie/web/src/lib/signal-handlers/memory.ts` (C2 output) — confirm `dispatchMemory` shape supports adding cases without refactor
- [ ] `one.ie/web/src/pages/api/forget/[id].ts` — existing forget pattern (GDPR-scoped actor erasure); confirm it's NOT what we want here (we want per-hypothesis erase, not actor forget). This is also why C3 uses receiver `memory:erase`, not `memory:forget`.

### W2 — Decide  [Sonnet]

- [ ] **Identifier choice** — pass `hid` in the signal payload: `{"hid":"...","action":"verify"}` OR receiver-suffixed: `memory:verify:{hid}`. Pick one; the latter aligns with the 5-mode receiver grammar but bloats receiver cardinality.
- [ ] **Verify promotion rule** — verify sets `source = "verified"` and `p-value = 0.15` (≈ 0.85 derived confidence). Or `min(0.15, current p-value)` so verifying twice can't regress. Pick one.
- [ ] **Privacy promotion rule** — if the row had only an `author` link (private), Verify also adds a `memory-of:company` link to promote it from private to company-shared. If it already has both, Verify only flips source + p-value. Document.
- [ ] **Erase semantics** — TypeDB hard delete (`match $h isa hypothesis, has hid "..."; delete $h;`) or soft delete via `hypothesis-status = "rejected"`. Soft delete preserves audit; hard delete satisfies GDPR for hypothesis content. Pick based on whether the row holds PII (likely yes for customer facts → hard delete).
- [ ] **Diff specs output**

Proposed:

| File | Verdict |
|---|---|
| `one.ie/web/src/lib/signal-handlers/memory.ts` | **extend** — two more cases in the switch |
| `one.ie/web/src/components/memory/MemoryRow.tsx` (C1 output) | **extend** — add ⋯ menu with two items |
| `one.ie/web/src/lib/in/role-gates.ts` | **extend** — `memory:verify` → `admin`+ · `memory:erase` → `member`+ (own rows) or `admin`+ (any row) |

### W3 — Edit  [Sonnet · parallel]

**W3a:**
- [ ] `one.ie/web/src/lib/signal-handlers/memory.ts` — add `memory:verify` + `memory:erase` cases
- [ ] `one.ie/web/src/lib/in/role-gates.ts` — add the two receiver rows
- [ ] `one.ie/web/src/components/memory/MemoryRow.tsx` — add `DropdownMenu` with Verify + Forget items (button label "Forget"; receiver `memory:erase`)
- [ ] `one.ie/web/tests/e2e/memory-ui-c3.test.ts` — seed row, verify → source = verified AND p-value ≤ 0.15; erase → row count decremented

### W4 — Verify  [inline composite — simple tier]

- [ ] `cd one.ie/web && bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate exits 0
- [ ] **Reuse audit:**
  - [ ] `grep -l "from '@/components/ui/dropdown-menu'" one.ie/web/src/components/memory/MemoryRow.tsx` returns 1
  - [ ] No second forget endpoint added under `pages/api/` (`ls one.ie/web/src/pages/api/memory/` still returns nothing)
- [ ] Composite ≥ 0.65

---

## What this plan must not produce

- ❌ A new `/api/memory/*` route family (violates the four-universal-endpoints rule)
- ❌ Any vector / embedding / chunk-size code
- ❌ A multi-form modal for memory entry — one input or it has failed
- ❌ A new sidebar module — `getUserMenu` extension only
- ❌ Worker-side handlers (`agents/src/*`) — out of scope; reopen later in a separate plan
- ❌ Touching `agents/src/substrate.ts:rememberHypothesis` — leave it; this plan's writes mirror its insert shape but live in `one.ie/web/src/lib/signal-handlers/memory.ts`

---

## See also

- `schema/world.tql` (line 233-244) — deployed hypothesis entity (NOT the abbreviated `one.tql:185` stub)
- `agents/src/substrate.ts` — production-correct `rememberHypothesis` + `recallHypotheses` shape; C2 cribs the insert verbatim
- `one.ie/web/src/pages/api/CLAUDE.md` — receiver-IS-the-API contract
- `one.ie/web/src/lib/substrate.ts` — typedbQuery + writeSignal
- `plans/dictionary.md` — canonical names
- `plans/rubrics.md` — scoring bands
- `plans/dev/memory-*.md` (archived) — prior plans against the dead apps/dev.one.ie codebase, not load-bearing here

---

*One sidebar entry. One page. One input. One signal receiver family. One new schema relation (`memory-of`) that makes the whole thing multi-tenant honest. Four cycles. No new routes. No new sidebar. No vectors. No agents/.*
