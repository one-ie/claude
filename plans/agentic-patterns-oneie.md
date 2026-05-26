# Agentic Patterns — Product Agents

**Scope:** `one.ie/agents/` (420+ agents) and the web infrastructure serving them.
**Date:** 2026-05-26

See `agentic-patterns.md` for the Claude Code dev cycle (W1–W4) gaps.

## Status

| Pattern | Status |
|---|---|
| Persistent instruction file per agent | ✅ |
| Instruction file authoring contract | ✅ |
| Safety enforcement Tier 1 (tools: whitelist) | ✅ |
| Safety enforcement Tier 2 (hooks) | ❌ |
| Safety enforcement Tier 3 (runtime gates) | ❌ |
| Context window budgeting | ❌ |
| MCP tool protocol | ✅ |
| Coordinate through shared state | ✅ |
| Decompose before coherence cliff | ⚠️ Partial |
| Cost tracking per task | ❌ |
| Multi-agent: Orchestrator/Workers | ✅ |
| Multi-agent: Parallel Fan-Out | ✅ |
| Multi-agent: Handoff Chain | ⚠️ Partial |
| Multi-agent: Peer Mesh (A2A) | ❌ |
| Memory L1: context budgeting | ❌ |
| Memory L2: hierarchical compaction | ❌ |
| Memory L3: compaction-resistant identity | ❌ |
| Anti-pattern: Prompted routing | ❌ |
| Anti-pattern: Compaction-vulnerable goals | ❌ |
| Anti-pattern: Ungated background work | ❌ |
| Agent lifecycle gates | ❌ |
| Signal namespace convention | ❌ |
| Feedback → evolution loop | ❌ |

---

## Gaps

### GAP 1: CEO routing is prompted architecture
CEO dispatch table lives in the system prompt body — model routing errors are silent with no fallback.

**Fix:**
1. Add `POST /api/agents/route`: Haiku classifies intent → deterministic `switch` → emits correct signal.
2. CEO body becomes: gather intent, submit to `agents:route`. Model extracts intent; harness routes.

**Files:** `one.ie/web/src/pages/api/agents/route.ts` (new), `one.ie/agents/ceo.md`

---

### GAP 2: Agent identity is compaction-vulnerable
Persona, `reports_to`, domain, sensitivity are injected into system prompt body — compacted away after 40–60 turns.

**Fix:**
1. Compile frontmatter into a `runtime_context` block prepended every turn (separate from static body):
   ```
   [IDENTITY — not compactable]
   role: analyst | domain: marketing | reports_to: cmo | sensitivity: 0.3
   constraints: only emit campaign:*:report-ready | never route | never access billing
   ```

**Files:** `one.ie/agents/CLAUDE.md`, `one.ie/web/` agent pipeline

---

### GAP 3: No context budget per model tier
`pipeline.ts` assembles context pack without size budget — haiku agents receive full history and all highways.

**Fix:**
1. Derive `context_budget` from model tier in `pipeline.ts` `recall()`:
   - Haiku: last 10 turns, top 5 highways, no hypotheses
   - Opus: last 40 turns, top 20 highways, confirmed hypotheses only

**Files:** `one.ie/agents/CLAUDE.md`, `one.ie/agents/agents/pipeline.ts`

---

### GAP 4: Campaign fan-out has no convergence contract
CMO blocks on all 6 specialists but has no timeout or `dissolved` handling — one slow specialist stalls the whole campaign.

**Fix:**
1. CMO: 25s timeout per receiver; assemble with whatever resolves; emit `campaign:<id>:section-missing` for dissolved.
2. Mark `campaign:card-ready` with `{ complete: false, missing: [...] }` on partial assembly.

**Files:** `one.ie/agents/cmo.md`, `one.ie/agents/copywriter.md`, `one.ie/agents/strategist.md`, `one.ie/agents/analyst.md`

---

### GAP 5: `sensitivity` field is metadata, not enforcement
`sensitivity: 0.8` is documentation — no hook reads it to gate tool use at runtime.

**Fix:**
1. In AI SDK v6 tool approval: read `sensitivity` from context pack.
2. `>= 0.7` → substrate writes (`signal`, `mark`, `warn`) require user approval.
3. `>= 0.9` → external tools (crawl, email, search) blocked; read-only.

**Files:** `one.ie/agents/src/aitools.ts`, `one.ie/agents/agents/builder.ts`

---

### GAP 6: No L2 memory — conversation history is flat
`recall()` fetches last 20 raw turns from D1. After 40 turns, cost grows linearly and relevance drops.

**Fix:**
1. After every 20 turns, summarize prior 20 into D1 `checkpoints` table (inputs, outputs, decisions, artifacts).
2. `recall()` fetches: last 10 raw turns + most recent checkpoint + highways.
3. Checkpointing runs async in cron, not synchronous with chat.

**Files:** `one.ie/agents/src/pipeline.ts`, `one.ie/agents/src/cron.ts`, `one.ie/web/migrations/`

---

### GAP 7: Skill economy is defined but not wired
`hire()` + `bounty()` exist; agents have prices. Revenue tab shows `$0`. `payWeight()` is never called.

**Fix:**
1. After successful priced skill call: emit `signal("pay:weight", { from, to, task, amount: skill.price })`.
2. Write `skill_calls` row to D1 per invocation.
3. AgentDrawer revenue tab reads from `skill_calls` by `agent_uid`.
4. `path.revenue += amount` after each success (already in schema; needs wiring).

**Files:** `one.ie/agents/src/aitools.ts`, `one.ie/web/migrations/`, `one.ie/web/src/pages/api/agents/[id]/revenue.ts`

---

### GAP 8: `needs_evolution()` not wired to agent update
TypeDB fires `needs_evolution()` at `success_rate < 0.50 AND samples >= 20`. Failing agents keep failing; substrate knows but nothing acts.

**Fix:**
1. Cron: query TypeDB for `needs_evolution()` actors each hour.
2. Emit `signal("agents:evolve", { uid, slug, success_rate, samples })` per flagged actor.
3. Receiver creates agent draft with `state: 'evolving'` + auto-flag note for operator.

**Files:** `one.ie/agents/src/cron.ts`, `one.ie/web/src/pages/api/agents/[id].ts`

---

### GAP 9: Agent lifecycle has no gates
States (`draft`, `live`, `paused`, `evolving`) exist in D1 but `publish` and `rollback` routes are stubs.

| Transition | Gate |
|---|---|
| draft → live | 1 test signal completes with `mark` |
| live → evolving | `needs_evolution()` fires or operator triggers |
| evolving → live | 3 test signals pass with `mark` |
| any → rollback | No gate (emergency) |

Implement `publish.ts`: write R2 archive entry + update D1 state + bust KV cache.

**Files:** `one.ie/web/src/pages/api/agents/publish.ts`, `one.ie/web/src/pages/api/agents/rollback.ts`

---

### GAP 10: No signed Agent Cards (A2A)
External agents (LangGraph, CrewAI, OpenAI Agents) can't discover ONE agents.

**Fix:**
1. Add `GET /api/agents/:slug/agent.json` returning Agent Card with `name`, `description`, `skills[]`, `url`, `authentication: { type: "bearer" }`.
2. Sign with actor's SE-rooted key.

**Files:** `one.ie/web/src/pages/api/agents/[slug]/agent.json.ts` (new)

---

## Signal namespace (missing convention)

Document in `agents/CLAUDE.md`:

| Pattern | When | Example |
|---|---|---|
| `<domain>:<id>:<event>` | Entity lifecycle events | `campaign:abc:brief` |
| `<domain>:<verb>` | Domain-level commands | `route:to-marketing` |
| `<system>:<verb>` | Platform operations | `agents:evolve` |
| `sub:<topic>:<subtopic>` | Subscription fan-out | `sub:news:crypto` |

---

## Anti-patterns

| Anti-Pattern | Status |
|---|---|
| Prompted Architecture | ❌ CEO routing, CMO convergence in model body |
| Vector-Default Memory | ✅ Clean |
| Premature Distribution | ✅ Clean |
| Compaction-Vulnerable State | ❌ Agent identity in system prompt body |
| Ungated Background Work | ❌ `journey-runner` every minute; no backoff |

---

## Roadmap

| # | Gap | Effort | Impact |
|---|---|---|---|
| 1 | Runtime identity block (GAP 2) | S | Prevents role drift in all agents |
| 2 | Signal namespace in `agents/CLAUDE.md` | XS | Prevents naming chaos |
| 3 | CEO routing as code (GAP 1) | S | Eliminates largest silent failure |
| 4 | Context budget per tier (GAP 3) | S | Cuts cost; improves specialist quality |
| 5 | `sensitivity` enforcement (GAP 5) | S | Makes Tier 1 safety real |
| 6 | Campaign convergence contract (GAP 4) | S | Prevents CMO hangs |
| 7 | Lifecycle publish gate (GAP 9) | M | Safe draft → live |
| 8 | Skill billing wired (GAP 7) | M | Activates economy |
| 9 | L2 conversation checkpointing (GAP 6) | M | Prevents context degradation |
| 10 | `needs_evolution()` → agent draft (GAP 8) | M | Closes learning loop |
| 11 | Signed Agent Cards / A2A (GAP 10) | M | Cross-framework interop |

Items 1–6 independent. Items 7–8 independent of each other.
