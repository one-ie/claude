# /see

**Skills:** `/typedb` (read-only queries across all 6 dimensions)

Read the world — query substrate state without emitting signals.

## Nouns

| Noun | What | Loop |
|------|------|------|
| `tasks [--tag X] [--status Y]` | Open work sorted by effective priority | L1 |
| `highways [--limit N]` | Proven paths — strength ≥ 50 (default top 20) | L2 |
| `toxic` | Blocked paths — resistance > strength | L3 |
| `frontiers` | Unexplored tag clusters (<10% traversed) | L7 |
| `paths [--from X] [--to Y]` | Any path query by source/target | L2 |
| `hypotheses` | Hardened learning (persisted by L6) | L6 |
| `evolved` | Agents that rewrote their system prompts | L5 |
| `revenue` | Per-path earnings from L4 economic loop | L4 |
| `events [--since T]` | Signal history and Four Outcomes audit | L1 |
| `memory <uid>` | Unseal one PII field for an actor (reveal) — authenticated | L6 |

## Routing

`/see` maps to `follow()` — deterministic read along strongest paths.
No mark(), no warn(), no side effects. Every noun is read-only.

| Noun | Primitive | Source |
|------|-----------|--------|
| tasks | `follow()` queue read | `.claude/scripts/do-rank.py` |
| highways | `follow()` path read | `GET /api/export/highways` |
| toxic | `follow()` path read | `GET /api/export/toxic` |
| frontiers | `follow()` gap read | `GET /api/frontiers` |
| paths | `follow()` path query | `GET /api/paths` |
| hypotheses | TypeDB read | `GET /api/export/hypotheses` |
| evolved | TypeDB read | `GET /api/export/units`, filter `generation > 1` |
| revenue | TypeDB read | `GET /api/revenue` |
| events | TypeDB read | signal history — no GET route (see below) |
| memory | `reveal(uid)` | `GET /api/pii/reveal/:uid?field=` |

**Not built (do not invoke, do not describe as live) — verified 2026-08-02:**
`GET /api/tasks`, `GET /api/state`, `GET /api/memory/reveal/:uid`, and
`scanTodos()` in `src/engine/task-parse.ts` (the whole `src/engine/` dir holds
only `rubric.ts`). Every noun that used to name one has been repointed above.
`/api/events` exists but is **POST-only tracking ingest**, not a signal-history
read — do not GET it.

## Steps

### tasks

1. `python3 .claude/scripts/do-rank.py` — the ranker reads `text/*-todo.md` directly and needs no dev server. Add `--tasks` for the tagged-signal view, `--json` for machine output, `--top N` to cap.
   - **The one exception to this file's no-side-effects rule.** The ranker refreshes a `text/task-paths.json` memo as it runs. It does **not** write `todo.md` — that is the hourly `fade-toxic.sh` launchd loop (since 2026-09-05 the only writer). No substrate write, no `mark()`/`warn()`.
2. Filter by `$ARGUMENTS` if provided — tags or phase (e.g. `/see tasks build P0`, `/see tasks C1`)
3. Report tasks sorted by effective priority (priority score + pheromone strength − resistance):
   - Name, id, priority formula (e.g. `90 = critical=30 + C1=40 + dev=20`)
   - Phase, value, persona, tags
   - Category: attractive / ready / exploratory / repelled
   - Pheromone: strength, resistance (if any)
   - Blocks: what tasks this blocks
   - Exit condition
4. Group by phase (C1→C7), sorted by effective priority within each phase
5. Summary: total open/done, count per phase, count per value, top 5 by priority
6. Suggest what to work on next based on priority + pheromone state

### highways

1. GET `http://localhost:4321/api/export/highways?limit=50` — the route takes `limit` (default 50, capped 200) and an optional `from=<aid>` to scope to one source actor. There is no `context=` param and no `/api/state` fallback.
2. Show paths where `strength ≥ 50`, sorted by strength desc (default limit 20; use `--limit N` to override)
3. Each: from → to, strength, traversals, revenue — and `context: <docs>` if contextHint is present
4. Report:
   ```
   Highways:  N paths ≥ 50 strength
   Hardened:  N paths promoted to permanent (L6)
   Top path:  <from> → <to>  strength=N  traversals=M  revenue=$X
              context: dsl, dictionary  (docs that led to success on this path)
   ```

### toxic

1. GET `http://localhost:4321/api/export/toxic?limit=200` (limit capped at 500; returns warned/faded paths with `resistance > 0`, sorted by resistance desc)
   - **Empty ≠ clean.** Every `/api/export/*` route scopes via `scopeToGroup(viewer, …)`, defaulting to `viewer='end_user'` / `workspace='default'`. An unauthenticated call returns an empty set, not a 401 — so "0 toxic paths" may mean "not authorized to see any". The same applies to `hypotheses` and `evolved` below. Authenticate, or read the count as unknown.
2. Show paths where `resistance > strength`
3. Each: from → to, resistance, strength, hypothesis (if any)
4. Report:
   ```
   Toxic:      N paths with resistance > strength
   Worst path: <from> → <to>  resistance=N  strength=M  reason="<hypothesis>"
   ```

### frontiers

1. GET `http://localhost:4321/api/frontiers` (optional `?limit=N`)
2. Show tag clusters with <10% traversal rate
3. Each: tag cluster, % explored, expected value
4. Report:
   ```
   Frontiers:       N clusters
   Least explored:  <cluster>  X% traversed  expected=$Y
   ```

### paths

1. GET `http://localhost:4321/api/paths` — params are `from=<aid>`, `to=<aid>`, `limit` (default 20), `min_strength` (default 1)
2. Filter by `--from` and/or `--to` if provided in `$ARGUMENTS` — pass them through as `from=`/`to=`
3. Show matching paths: from → to, strength, resistance, net weight (strength − resistance)
4. Report all matching paths with full pheromone state

### hypotheses

1. GET `http://localhost:4321/api/export/hypotheses?limit=100` (or query TypeDB directly for hypothesis entities)
2. Show each: pattern, confidence, created, reinforced count
3. Report:
   ```
   Hypotheses: N
   Top:        <pattern>  confidence=X  reinforced=M times
   ```

### evolved

1. GET `http://localhost:4321/api/export/units`, then filter to `generation > 1` client-side (the route has no generation filter) — or query TypeDB directly
2. Show each: uid, name, generation, current model, last evolution timestamp
3. Report:
   ```
   Evolved: N agents
   Most:    <uid>  gen=N  model=<model>
   ```

### revenue

1. GET `http://localhost:4321/api/revenue` (or query TypeDB for paths with a revenue attribute, sorted desc)
2. Show per-path earnings
3. Report:
   ```
   Revenue:  total=$X across N paths
   Top path: <from>→<to>  $Y
   ```

### events

1. Query TypeDB signals directly, optionally filtered by `--since T` from `$ARGUMENTS`. **No HTTP read route exists** — `/api/events` is POST-only tracking ingest and will not serve this.
2. Show each signal: receiver, data summary, outcome, timestamp
3. Report:
   ```
   Events:   N signals
   Outcomes: result=A  timeout=B  dissolved=C  failure=D
   ```

### memory

1. Extract `<uid>` from `$ARGUMENTS` (e.g. `/see memory person:a7f3`)
2. GET `http://localhost:4321/api/pii/reveal/<uid>?field=email` — this is the only
   shipped `reveal`. It unseals **one PII field at a time**
   (`email|phone|address|name|dob|custom`), not a memory card.
   - **Authenticated and audited.** It calls `requireAuth` + `requireContactOwner`,
     so an anonymous or non-owning caller gets denied. Rate-limited to 100
     reads/hour per reader; every read emits a `pii.read` audit event.
   - The MCP tool `reveal` is the same route.
3. Report:
   ```
   Reveal: <uid>  field=<field>
   ```

**The aggregate MemoryCard was never built.** There is no route returning
hypotheses + highways + last-200 signals + groups + capabilities + frontier for
one actor. To assemble that view today, compose the other nouns for that uid:
`/see hypotheses`, `/see highways` (`?from=<uid>`), `/see paths` (`?from=<uid>`),
`/see frontiers`. Do not describe a single-call memory card as live.

---

*Every `/see` query is a `follow()` call — the substrate answers without learning.*
