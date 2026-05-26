# 13-learning — gap analysis

Comparison of the marketing promise in `text/13-learning.md` against the
runtime in `claw/`, `web/src/lib/`, `web/src/pages/api/`, and the UI.

---

## Promise

`text/13-learning.md` sells seven continuous loops as the moat:

| Loop | Promise | Cadence |
|------|---------|---------|
| L1 Signal   | every message routes, produces an outcome | per message |
| L2 Trail    | mark on result, warn on failure           | per outcome |
| L3 Fade     | asymmetric decay — **bad forgives 2× faster** | every 5 min |
| L4 Economic | revenue routes along earning paths        | per payment |
| L5 Evolution| agent rewrites own prompt when success<50% over 20 samples; `generation++` | every 10 min |
| L6 Knowledge| strong paths hardened into TypeDB hypotheses | every hour |
| L7 Frontier | unexplored tag clusters surfaced as opportunities | every hour |

Plus a "day in the life, month 12" report that quantifies path strength
deltas, prompt-rewrite events, frontier signals — implying clients SEE
the loop happen.

---

## Code reality

| Loop | Implemented? | Where | Evidence |
|------|--------------|-------|---------|
| L1 Signal   | YES (partial) | `claw/src/middleware.ts` `substrateMiddleware.wrapGenerate` | only fires on `wrapGenerate`; `wrapStream` passes through with NO mark/warn (`middleware.ts:39`) |
| L2 Trail    | YES — but only on generate | `claw/src/substrate.ts:81-150` mark/warn | hard-codes `claw:<group>` → `<provider/model>`; outcome judgement is binary `finishReason==='stop'`, not actual success |
| L3 Fade     | **NOT scheduled** | `web/src/lib/substrate.ts:283` `fade()` + `web/src/pages/api/fade.ts` | exists as POST endpoint; **no cron caller anywhere** (`claw/src/cron.ts:16-20` has journey/identity/export only). Marketing claims "every 5 min" → reality: only when someone manually POSTs |
| L3 Fade direction | **INVERTED vs promise** | `web/src/lib/pheromone.ts:99-102`, `web/src/lib/substrate.ts:291`, `web/src/lib/substrate.ts:301` | resistance is multiplied by `rate * 0.5` → resistance decays at **half** the rate of strength → resistance **persists longer** than strength. The marketing says "bad forgives 2× faster" but the code makes bad **stickier** than good. Code comment on `pheromone.ts:101` even says "resistance forgives 2× slower" — contradicts `engine.md:30`, `text/13-learning.md`, `mcp/src/tools/substrate.ts:77` |
| L4 Economic | NOT in claw | n/a | no payment→path mark path; capability/price exists in schema but `mark(strength)` on payment never fires |
| L5 Evolution| **NOT implemented** | `web/src/pages/api/agents/[id]/deploy.ts:127-132` returns "evolving state is set by the L5 runtime loop, not the deploy endpoint" | the referenced "L5 runtime loop" does not exist. `generation` is initialised to 0 in `substrate.ts:45` and never incremented. `AgentDrawer.tsx:280` fetches `/api/agents/:id/generations` — that endpoint exists but always returns empty because nothing writes new generations |
| L6 Knowledge| **NOT a loop** | `claw/src/substrate.ts:207` `rememberHypothesis` is called only from `tools.ts:102` and `aitools.ts:64` — i.e. only when the LLM explicitly calls a `remember` tool | path→hypothesis promotion based on strength threshold + observation count is missing; hypotheses are user-asserted, not substrate-derived |
| L7 Frontier | **wrong semantics + wrong source** | `web/src/pages/api/frontiers.ts:22-27` queries `hypothesis` table, not unexplored tag clusters; returns the same data as `/api/learning` (L6) with a renamed field. `claw/src/memory.ts:118-138` `handleExplore` does compute a real set-diff frontier but only on-demand for chat prompts, never persisted, never surfaced to the dashboard |

### Other code-truth gaps

- `wrapStream` (`middleware.ts:39`) — streaming requests bypass pheromone entirely. Most chat is streamed → most signals are unrecorded.
- Outcome judgement = `finishReason.unified === 'stop'` (`middleware.ts:29`). This is a structural completion check, not a success signal. The marketing claim ("path strengthens when the user gets an answer / the lead is captured / the appointment is booked") would require explicit business-outcome marking that does not exist.
- `mark` uses `claw:<group>` → `provider/model` edges. The substrate is learning which **model** to call, not which **route through the agent's skill graph** worked. The "Route A vs Route B" booking example in the marketing copy has no analog in code.
- `cron.ts` has 3 handlers, all named L1/L2-adjacent (`journey`, `identity`, `export`). None correspond to L3, L5, L6, L7.

---

## Visible-to-user gaps

| Surface | What it shows | Truthful? |
|---------|---------------|-----------|
| `web/src/pages/api/paths/index.ts` | path strengths | yes — but no user-facing page renders this for an end client |
| `web/src/pages/api/export/highways.ts` | top paths ≥ strength 10 | yes |
| `web/src/components/pulse/FrontierBlock.tsx` | "frontiers" | **misleading** — actually renders hypotheses |
| `web/src/components/agents/AgentDrawer.tsx` "generations" tab | prompt evolution history | **always empty** — no L5 writer |
| `web/src/components/pulse/PulseAtlas.tsx` | KPIs / funnel / attribution / holdout / frontier | KPI/funnel are real; frontier is L6 data; holdout/attribution are pulse-data hook outputs |
| Monthly report from "day in the life, month 12" | success-rate delta, prompt rewrites, frontier signal | **does not exist** as a generated artifact anywhere |
| User-visible "this conversation strengthened path X" trace | live pheromone deposit indicator | nowhere |

The marketing closes with "Watch a path harden into a highway." There
is no surface where a non-developer can watch this. Even
`/api/export/highways` requires authenticated curl.

---

## Gaps

Ordered by severity.

1. **Fade direction is inverted relative to the promise.** Code persists
   resistance longer than strength; marketing says the opposite. This
   silently biases the substrate against agents that struggle early —
   the exact thing "asymmetric fade" is sold as preventing. Either the
   docs lie or the code is wrong; both must agree.
2. **L5 evolution is vapor.** The promise ("agents rewrite their own
   instructions, generation++, no engineer required") has zero
   implementation. The deploy endpoint even rejects manual triggers
   pointing at a runtime loop that does not exist. This is the most
   load-bearing claim in the section ("the one that most people don't
   believe until they see it") — and it is currently not buildable.
3. **L3 fade is unscheduled.** No cron calls `/api/fade`. Path strengths
   accumulate without decay → the "recent results count more" property
   is false. After a few weeks, every active path saturates near 1000
   (the mark cap).
4. **L6 knowledge has no promotion loop.** Hypotheses only exist when an
   LLM tool call writes one. The "highways harden into hypotheses every
   hour" loop is missing. `/api/frontiers` reads from the wrong table
   and conflates L6 with L7.
5. **L7 frontier is a chat helper, not a substrate loop.** The real
   set-diff exists in `claw/src/memory.ts` `handleExplore` but is
   ephemeral and never surfaced. The Pulse UI's "Frontier" panel reads
   from the hypothesis table.
6. **Streaming bypasses pheromone.** `wrapStream` is a passthrough.
   Probably the majority of production traffic. Whatever learning is
   happening is built on a heavily-biased sample (non-streaming only).
7. **Outcome signal is structural, not semantic.** `finishReason==='stop'`
   is not "appointment booked." The "Route A closes faster" example in
   the marketing is unachievable without a per-conversation success
   signal (booking confirmed, lead captured, payment succeeded).
8. **Per-client / per-workspace isolation is unverified.** The promise
   "pheromone is per-client, not shared across the platform" relies on
   the `claw:<group>` actor prefix uniquely identifying a workspace. No
   tests enforce this. A workspace collision (same `groupId`) would
   silently pool learning.
9. **No user-visible learning surface.** A non-developer client cannot
   open one page and see (a) their top highways, (b) prompt-rewrite
   events, (c) frontier opportunities, (d) week-over-week success-rate
   delta. The "monthly report" central to the section's narrative is
   not a real artifact.
10. **L4 economic loop is absent.** Revenue does not deposit pheromone
    on the path that earned it. Cited in `engine.md` and `dictionary.md`
    but no `mark()` on Stripe / payment success.

---

## Recommended improvements

In order of payback.

### Wave 1 — make the promise true (small code, big credibility)

- **Flip resistance fade rate**. Change `rate * 0.5` → `rate * 2` in
  `web/src/lib/pheromone.ts:101`, `web/src/lib/substrate.ts:291`,
  `web/src/lib/substrate.ts:301`. Fix the comment. Update the
  contradictory `pheromone.ts:101` comment. Add one test asserting
  resistance fades twice as fast as strength.
- **Schedule the fade**. Add `{ cron: '*/5 * * * *', handler: 'fade-tick' }`
  to `claw/src/cron.ts`. The handler POSTs `/api/fade` with `rate=0.05`.
  This alone makes L3 real.
- **Move pheromone into wrapStream**. The current `wrapStream`
  passthrough is silent learning loss. Mirror the `wrapGenerate` logic
  on `doStream` finish — strength + cacheRatio on stop, warn on error.

### Wave 2 — build the missing loops (real work, biggest pheromone)

- **L5 evolution loop**. New cron handler `evolve-tick` (every 10 min):
  query agents with `success-rate < 0.5 AND sample-count >= 20`, fetch
  their recent warned signals, call LLM with current prompt + failure
  digest, write new prompt + `generation + 1`, emit
  `evolve.triggered` event. Wire `AgentDrawer.tsx` "generations" tab to
  the now-real `/api/agents/:id/generations` endpoint.
- **L6 knowledge loop**. New cron handler `know-tick` (hourly): query
  paths where `strength > THRESHOLD AND traversals > N`, write
  `hypothesis` rows derived from path+context, link via
  `derived-from` relation. The `/api/learning` endpoint already reads
  the right table.
- **L7 frontier loop**. Promote `handleExplore`'s set-diff into a
  scheduled job that writes `frontier` entities (new entity type, not
  `hypothesis`). Fix `/api/frontiers` to query that table. Rename the
  hypothesis-reader path or merge into `/api/learning`.

### Wave 3 — make learning visible

- **`/learning` page** (or tab in `/dashboard`). Three panes:
  Highways (top 10 paths, strength bars, traversal count), Generations
  (prompt-rewrite timeline per agent, `generation` increments,
  before/after diff), Frontier (unexplored tag clusters with
  observation count). All three already have API endpoints; the page
  ties them together.
- **Monthly report generator**. Cron job (1st of month) computes
  delta across `claw_paths` D1 mirror, prompt-rewrite count from
  `generations` table, top 5 frontier signals; renders HTML+text
  template; emails workspace owner. Matches the "day in the life,
  month 12" narrative.
- **In-chat learning trace**. After each turn, optionally render a
  small "pheromone +0.4 on tag:booking" badge. Already partially
  scaffolded by `emitClick('ui:chat:*')` infrastructure.

### Wave 4 — semantic outcomes

- **Business-outcome marking**. Define a per-agent
  `success-event` (booking confirmed, lead captured, message
  acknowledged). Wire the agent's tool handlers to call mark with
  semantic outcome instead of (or in addition to)
  `finishReason==='stop'`. This is what makes "Route A vs Route B"
  achievable — without it the L1/L2 loop is learning routing-to-models,
  not routing-to-outcomes.
- **Workspace isolation test**. Vitest: spin up two workspaces, run
  10 conversations on each, assert that fade/mark on one cannot affect
  paths in the other. Pheromone-as-moat needs this guarantee proven.

---

## Files to touch

### Wave 1
- `web/src/lib/pheromone.ts` (line 101: invert + fix comment)
- `web/src/lib/substrate.ts` (lines 291, 301: invert)
- `claw/src/cron.ts` (add `fade-tick` to `CRON_JOBS` + dispatch case)
- `claw/src/middleware.ts` (implement `wrapStream` mirror of `wrapGenerate`)
- `web/src/lib/pheromone.test.ts` (new — fade direction test)

### Wave 2
- `claw/src/cron.ts` (add `evolve-tick`, `know-tick`, `frontier-tick`)
- `claw/src/agents/evolve.ts` (new — L5 prompt rewrite)
- `claw/src/agents/know.ts` (new — L6 path→hypothesis promotion)
- `claw/src/agents/frontier-tick.ts` (new — L7 scheduled set-diff)
- `claw/src/substrate.ts` (add `promotePath`, `recordFrontier`, `incrementGeneration`)
- `web/src/pages/api/agents/[id]/generations.ts` (new — read writer's output)
- `web/src/pages/api/frontiers.ts` (rewrite to read frontier table, not hypothesis)
- `gateway` / TypeDB schema — add `frontier` entity if not present, add `derived-from` between hypothesis and path

### Wave 3
- `web/src/pages/learning.astro` (new) OR new tab in `web/src/pages/dashboard.astro`
- `web/src/components/learning/HighwaysPanel.tsx` (new)
- `web/src/components/learning/GenerationsPanel.tsx` (new — wire AgentDrawer tab)
- `web/src/components/learning/FrontierPanel.tsx` (new — fix `pulse/FrontierBlock.tsx`)
- `claw/src/agents/monthly-report.ts` (new)
- `web/src/components/chat/PheromoneBadge.tsx` (new, optional)

### Wave 4
- `claw/src/types.ts` (add `success-event` type to signal payload)
- `claw/src/pipeline.ts` (semantic outcome hook before mark/warn)
- `web/agents/*.md` per-agent `success-event` declaration
- `web/src/lib/substrate.test.ts` (new — workspace isolation test)

### Cross-cutting doc updates (W3/W4 of any cycle above)
- `text/13-learning.md` (re-state fade direction if code stays as-is, or re-test claims after fix)
- `CLAUDE.md` line 30 (fade direction)
- `.claude/rules/engine.md` line 198 (fade direction)
- `.claude/skills/tutorial.md` line 53 (says "4x faster" — pick one number)
- `one/agent-communication.md` line 384 (resistance decay rate)
- `mcp/src/tools/substrate.ts` line 77 (tool description vs reality)
