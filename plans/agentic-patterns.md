# Agentic Patterns — Claude Code Dev Cycle (W1–W4)

**Source:** https://veso.ai/research/agentic-patterns/ · **Date:** 2026-05-26

## Status

| Category | Status |
|---|---|
| Instruction layer (CLAUDE.md hierarchy, rules/, hooks) | ✅ |
| Enforcement Tier 1–2 (verb contracts, rubric gate) | ✅ |
| Enforcement Tier 3 (destructive-command blocking) | ⚠️ Partial |
| Multi-agent: Orchestrator/Workers | ✅ |
| Multi-agent: Parallel Fan-Out | ✅ |
| Multi-agent: Handoff Chain (W0→W4) | ✅ |
| Multi-agent: Peer Mesh (A2A) | ❌ |
| Memory L1: Context budgeting | ❌ |
| Memory L2: Hierarchical compaction | ❌ |
| Memory L3: Compaction-resistant state | ⚠️ Partial |
| Shared state coordination (TypeDB) | ✅ |
| Cost tracking per task | ❌ |
| Background work gating | ❌ |
| Observability | ⚠️ Partial |
| Soft resume | ❌ |
| Anti-pattern: Prompted Architecture | ✅ Clean |
| Anti-pattern: Vector-Default Memory | ✅ Clean |
| Anti-pattern: Premature Distribution | ✅ Clean |
| Anti-pattern: Compaction-Vulnerable State | ⚠️ Partial |
| Anti-pattern: Ungated Background Work | ❌ |

---

## Gaps

### GAP 1: No context window budget
W1 output passed verbatim to W2 — complex tasks can hit context limits. W4 is most at risk.

**Fix:**
1. Cap W1 receipt at 400 words; enforce with line count check before W2 spawns.
2. W2 writes `.w2-spec.json` instead of emitting text. W3 and W4 read the file.
3. W4 emits results to `.w4-report.json` before scoring; warns at 60% context.

**Files:** `.claude/agents/w1-recon.md`, `.claude/agents/w2-decide.md`, `.claude/commands/do.md`

---

### GAP 2: W2 plan lives in transcript (compaction-vulnerable)
W3 receives W2 spec as conversation text — partial compaction mid-W3 causes anchor mismatches.

**Fix:**
1. Enforce `.w2-spec.json` (from GAP 1). W3 receives file path, not transcript excerpt.
2. W4 reads `.w2-spec.json` to cross-check all diff specs were applied.
3. After W2: `cp .w2-spec.json .do-checkpoint.json`. Resume reads checkpoint.

**Files:** `.claude/commands/do.md`, `.claude/agents/w3-edit.md`, `.claude/agents/w4-verify.md`

---

### GAP 3: Trust level is prose — machine-unreadable
`/do` derives trust level from `docs/learnings.md` — fails silently if the file grows or is reformatted.

**Fix:**
1. Emit `.do-trust.json` at each cycle close: `{ "level": "trusted", "consecutive": 3, "composite": 0.88, "updated": "..." }`
2. `/do` reads this file first; absent → default `standard`. Learnings.md stays human history only.

**Files:** `.claude/commands/do.md`

---

### GAP 4: No per-cycle token budget
Tool ladder routes by complexity but token consumption is never measured or stored.

**Fix:**
1. W4 receipt: add `tokens` field (input/output/cache_read per wave).
2. `docs/learnings.md` entry: append `tokens=<total>`.
3. `signal("cost:cycle", { tokens, model, composite })` → substrate pheromone.

**Files:** `.claude/agents/w4-verify.md`, `.claude/commands/do.md`, `packages/sdk/src/client.ts`

---

### GAP 5: No signed Agent Cards (A2A)
`signal()` + `hire()` + `discover()` work within ONE; external agents can't discover ONE agents.

**Fix:**
1. Add `GET /agents/:slug/agent.json` returning Agent Card with `name`, `description`, `skills[]`, `url`, `authentication`.
2. Sign with actor's SE-rooted key.
3. `discover()` SDK: add `{ protocol: "a2a" }` option.

**Files:** `one.ie/web/src/pages/api/agents/`, `packages/sdk/src/client.ts`

---

### GAP 6: Ungated background work
`cron.ts` and `sync/` run on CF cron triggers with no system-state checks or backoff.

**Fix:**
1. `cron.ts`: check KV `last_run_ok` — if last run failed, exponential backoff before next LLM call.
2. `sync/`: `max_concurrent_syncs = 3` semaphore via KV atomic counters.
3. Emit `signal("cron:start")` + `mark`/`warn` on outcome.

**Files:** `agents/src/cron.ts`, `sync/src/index.ts`

---

### GAP 7: No intra-cycle checkpoint recovery
Interrupted W3 leaves partially applied edits with no recovery path. Next `/do` restarts from W1.

**Fix:**
1. W3 appends edit receipts to `.w3-receipts.json` as it goes (not at end).
2. `/do` startup: if `.w3-receipts.json` exists and W3 incomplete → skip W0/W1/W2, resume W3.
3. Delete `.w3-receipts.json` on cycle close.

**Files:** `.claude/commands/do.md`, `.claude/agents/w3-edit.md`

---

## ONE-native patterns (not in Veso)

| Pattern | Mechanism |
|---|---|
| Pheromone Ratchet | mark/warn/fade + path.strength |
| Verb Contract Gate | plans/contracts.md + W4 |
| Complexity Classifier | /do W0 tier gate (TRIVIAL/SIMPLE/COMPLEX) |
| Systemic Gap Detection | W4 3+ consecutive improve at same file:line |
| Composite Velocity | Δcomposite across cycles |
| Economic Pheromone | path.revenue as routing signal |

---

## Roadmap

| # | Gap | Effort | Impact |
|---|---|---|---|
| 1 | `.w2-spec.json` artifact | S | Fixes GAP 1, 2, 7 foundation |
| 2 | `.do-trust.json` | XS | Fixes GAP 3 |
| 3 | Token cost in W4 receipt | S | Fixes GAP 4 observability |
| 4 | Cron backoff + semaphore | S | Fixes GAP 6 |
| 5 | W3 receipt checkpointing | M | Fixes GAP 7 |
| 6 | Agent Card endpoint | M | Fixes GAP 5 |
| 7 | Cost signal → pheromone | L | Extends GAP 4 to routing |

Items 1–4 independent. Item 5 depends on 1. Item 7 depends on 3.
