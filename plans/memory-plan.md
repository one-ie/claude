# Memory Plan — Close the Gaps

**Goal:** Make the memory system work end-to-end for production chat agents.
The design in `memory-agents.md` is correct. This plan closes the seven gaps
between what is designed and what is wired.

**Source of truth:** `memory-agents.md` (architecture), `one.tql` (schema),
`agents/src/substrate.ts` (engine), `agents/src/cron.ts` (process layer).

---

## Memory Operations

Memory is not CRUD on a store. Memory is **routing that learns from outcomes**.
A path you used successfully is a memory that strengthens. A path that led
nowhere is a memory that fades.

Every memory verb is already a substrate verb:

| Verb | What it does | Primitive |
|------|-------------|-----------|
| **remember** | record an episode | `signal()` |
| **recognize** | find a path | `sense(edge)` / `danger(edge)` |
| **recall** | query the brain | `persist().recall(match)` |
| **reinforce** | make memory stronger | `mark(edge)` |
| **suppress** | make memory weaker | `warn(edge)` |
| **forget** | decay unused memory | `fade()` — asymmetric, resistance 2× faster |
| **erase** | structural delete (GDPR) | TQL `delete $u isa actor` — ontology cascades |
| **generalize** | episode → hypothesis | `know()` — promote highway to law |
| **introspect** | what do I know? | `open()`, `highways()`, `recall()` |
| **reveal** | what do you know about *me*? | `persist.reveal(uid)` — full memory card |
| **imagine** | what *haven't* we learned? | `frontier(uid)` — tag clusters never touched |

No new primitives needed. The verbs are already there. The gaps below are
wiring gaps, not design gaps.

---

## Graph in Chat Context

For the memory verbs to work elegantly in a chat agent, the LLM needs the
graph state at the start of each turn — not as prose, but as typed structure
it can reason over. Two mechanisms together cover it.

### 1. Structured graph snapshot (pre-loaded, zero latency)

Inject a compact JSON block into the system prompt before the first turn.
TypeDB inference has already run — `status: "proven"` is a derived fact, not
a raw score for the LLM to interpret.

```ts
// pipeline.ts — buildGraphSnapshot(env, actorUid, groupId)
{
  "actor": {
    "uid": "telegram:brad123",
    "status": "proven",           // derived by TypeDB proven-actor rule
    "messageCount": 42
  },
  "highways": [
    { "to": "delivery", "strength": 18, "status": "highway" },
    { "to": "weekend",  "strength": 11, "status": "open"    }
  ],
  "hypotheses": [
    { "statement": "delivery concerns correlate with weekend orders",
      "confidence": 0.84, "scope": "group" },
    { "statement": "skill support is a proven capability",
      "confidence": 0.82, "scope": "group" }
  ],
  "skills": {
    "support":    "highway",
    "escalation": "at-risk"
  }
}
```

Injected as a `--- GRAPH ---` block in the system prompt. The LLM reads
derived facts, not numbers. It doesn't decide what "strength: 42" means —
the substrate already decided.

### 2. `query_graph` tool (live traversal, on demand)

For anything not in the snapshot, the agent calls a tool wrapping TypeDB TQL.

```ts
// agents/src/tools.ts
{
  name: 'query_graph',
  description: 'Run a deterministic query against the substrate. Returns derived facts. Use for: checking path status, finding proven actors, hypothesis confidence, toxic path detection.',
  input_schema: {
    type: 'object',
    properties: {
      question: { type: 'string', description: 'e.g. "is skill:delivery toxic?", "what skills are highways?", "group hypotheses confidence > 0.8"' }
    },
    required: ['question']
  }
}
```

`executeTool` translates to TQL using the existing TypeDB functions —
`proven()`, `highways(n)`, `toxic()`, `blocked()`. Returns `{ facts, derived: true }`.
`derived: true` tells the LLM this is deterministic — act on it directly.

```
Agent: "Is our delivery skill working well for weekend complaints?"
→ query_graph("path status of skill:delivery")
→ { facts: [{ path: "skill:delivery", status: "highway", strength: 52 }], derived: true }
→ "Delivery skill is a confirmed highway — 52 proven uses."
```

---

## The Seven Gaps

| # | Gap | Impact | Cycle |
|---|-----|--------|-------|
| 1 | Hypothesis schema mismatch | Silent broken writes today | C1 |
| 2 | Skill signal paths not emitted | Skill evolution loop dead | C2 |
| 3 | `prompt`/`generation` not on `thing` | L5b can't run | C2 |
| 4 | No dreaming tick | Cold path is zero code | C5 |
| 5 | No L5b skill-evolution tick | Skill evolution loop dead | C4 |
| 6 | No KV snapshot for hypotheses | TypeDB hit on every LLM call | C3 |
| 7 | Scope not enforced on recall | Cross-group hypothesis bleed | C1 |

---

## Gap 1 — Hypothesis schema mismatch

**Problem:** `substrate.ts` inserts and queries four attributes that don't exist
in `one.tql`: `hypothesis-status`, `p-value`, `source`, `observed-at`.
The schema only defines `hid`, `statement`, `confidence`, `observations`, `scope`.

**Fix — `schema/one.tql`:**

```tql
entity hypothesis,
    owns hid @key,
    owns statement,
    owns confidence,
    owns observations,
    owns scope,
    owns hypothesis-status,   # add: pending | testing | confirmed | rejected
    owns p-value,             # add: statistical significance (0..1)
    owns source,              # add: observed | asserted | verified
    owns observed-at;         # add: unix ms timestamp

attribute hypothesis-status, value string;
attribute p-value, value double;
attribute source, value string;
attribute observed-at, value integer;
```

**What this unlocks:**
- `recallHypotheses` query stops querying phantom attributes
- `rememberHypothesis` inserts complete, valid entities
- Confidence gate (`p-value <= maxP`) works as designed
- `requireVerify` mode can filter on `hypothesis-status = "confirmed"`

---

## Gap 2 — Skill signal paths not emitted

**Problem:** `skill-tools.ts` executes skills but never calls `mark()` or
`warn()`. L6 has no skill path to harden. L5b has no resistance to trigger on.

**Fix — `agents/src/skill-tools.ts`:**

```ts
tools[safeName] = tool({
  description: `Imported skill: ${skillName}`,
  inputSchema: z.object({ input: z.string() }),
  execute: async ({ input }: { input: string }) => {
    const start = Date.now()
    try {
      const result = `[${skillName}] processed: ${input}`
      // Signal success on skill path
      await mark(env, 'skill-runner', `skill:${safeName}`, 1).catch(() => {})
      return { result }
    } catch (err) {
      // Signal failure on skill path
      await warn(env, 'skill-runner', `skill:${safeName}`, 1).catch(() => {})
      throw err
    }
  },
})
```

**What this unlocks:**
- `skill:ai-seo`, `skill:content-strategy` etc. become real paths in TypeDB
- L6 harden: after ~50 successful uses, skill path becomes a highway
- L5b: skill resistance > strength × 3 triggers prompt rewrite
- Dreaming: cross-session skill failure patterns become visible

**Practical — for chats:**

```
Turn 1: user asks about SEO → agent calls skill:ai-seo
  → mark('skill-runner', 'skill:ai-seo', 1)
  → D1: claw_paths row created, strength=1

Turn 20: skill used 20 times, 18 successes, 2 failures
  → strength=18, resistance=2
  → TypeDB rule: path-status = "open"

Turn 50: strength=47
  → TypeDB rule: path-status = "open" → approaching highway

Turn 60: strength=52
  → TypeDB rule: path-status = "highway"
  → L6 harden: "skill:ai-seo is a proven capability (confidence 0.87)"
  → Next sessions: context pack includes "skill ai-seo: proven"
```

---

## Gap 3 — `prompt` and `generation` not on `thing`

**Problem:** `prompt` and `generation` attributes are defined in `one.tql` but
only `actor` owns them. `thing` (skill entities) can't store an evolving prompt.

**Fix — `schema/one.tql`:**

```tql
entity thing,
    # existing...
    owns prompt,        # add: skill instruction content — mutable
    owns generation;    # add: rewrite iteration count
```

No new attribute definitions needed — `prompt` and `generation` are already
attributes in the schema. This is one line of `owns` per attribute on `thing`.

**What this unlocks:**
- Skill prompts stored in TypeDB, not just KV blobs
- `generation` counter tracks how many times the prompt has been rewritten
- L5b can update `thing.prompt` and increment `thing.generation`
- Dreaming diff targets `tid` (thing ID) not a filename

---

## Gap 4 — No dreaming tick

**Problem:** Cold path is entirely unimplemented. No `dreaming-tick` in
`cron.ts`, no `dreaming.ts` module.

**Fix — `agents/src/cron.ts`:**

```ts
{ cron: '0 2 * * *', handler: 'dreaming-tick' },
```

**Fix — `agents/src/agents/dreaming.ts`:**

```ts
export async function tick(env: Env): Promise<void> {
  const since = Date.now() - 7 * 86400_000

  // Pull last 7 days of transcripts grouped by session
  const rows = await env.DB.prepare(
    `SELECT group_id, role, content FROM messages WHERE ts > ? ORDER BY group_id, ts`
  ).bind(since).all()

  if (!rows.results?.length) return

  // Group by session
  const sessions = groupBySession(rows.results as MessageRow[])

  // Pull current hypotheses to diff against
  const existing = await recallAllHypotheses(env)

  // Pull skill entities
  const skills = await getSkillEntities(env)

  // LLM synthesis — one call, produces typed diff
  const diff = await synthesizeDiff(env, sessions, existing, skills)

  // Apply: auto-apply hypotheses above threshold, queue skill changes
  await applyDiff(env, diff)
}
```

**`synthesizeDiff` prompt (key lines):**

```
You are analysing agent session transcripts to improve a memory system.

Current hypotheses: {existing}
Current skill prompts (name + first 100 chars): {skills}

Transcripts from last 7 days ({count} sessions):
{transcripts}

Produce a JSON diff with this shape:
{
  "hypotheses": {
    "add":    [{ "statement": "...", "confidence": 0.0-1.0, "sessions": ["id"...] }],
    "update": [{ "hid": "...", "confidence": 0.0-1.0 }],
    "remove": [{ "hid": "...", "reason": "..." }],
    "verify": [{ "hid": "...", "sessions": ["id"...] }]
  },
  "skills": {
    "update": [{ "tid": "...", "name": "...", "prompt": "...", "reason": "...", "sessions": ["id"...] }],
    "retire": [{ "tid": "...", "reason": "..." }]
  }
}

Rules:
- Only add a hypothesis if 3+ sessions show the same pattern
- Only update confidence if new evidence is stronger than existing
- Only remove if directly contradicted in 3+ recent sessions
- Skill updates: describe the prompt change, not the full new prompt
- Never invent sessions IDs; use the group_id values provided
```

**Apply rules:**

```ts
async function applyDiff(env: Env, diff: DreamDiff): Promise<void> {
  // Hypotheses: auto-apply adds with confidence >= 0.75 from 3+ sessions
  for (const h of diff.hypotheses.add) {
    if (h.confidence >= 0.75 && h.sessions.length >= 3) {
      await insertHypothesis(env, h)
    } else {
      await queueForReview(env, 'hypothesis:add', h)
    }
  }

  // Hypothesis updates: auto-apply (non-destructive)
  for (const h of diff.hypotheses.update) {
    await updateHypothesisConfidence(env, h.hid, h.confidence)
  }

  // Removals: always queue for operator review
  for (const h of diff.hypotheses.remove) {
    await queueForReview(env, 'hypothesis:remove', h)
  }

  // Skill updates: always queue — never auto-apply prompt changes
  for (const s of diff.skills.update) {
    await queueForReview(env, 'skill:update', s)
  }
}
```

---

## Gap 5 — No L5b skill-evolution tick

**Problem:** L5 rewrites actor prompts when `success-rate < 0.50`. The same
logic for skills is designed but has no cron handler.

**Fix — `agents/src/cron.ts`:**

```ts
{ cron: '*/10 * * * *', handler: 'skill-evolution-tick' },
```

**Fix — `runScheduled` in `cron.ts`:**

```ts
case 'skill-evolution-tick': {
  ctx.waitUntil((async () => {
    // Find skill paths where resistance > strength (struggling skills)
    const rows = await env.DB.prepare(
      `SELECT source, target, strength, resistance FROM claw_paths
       WHERE source = 'skill-runner' AND target LIKE 'skill:%'
       AND resistance > strength AND (strength + resistance) >= 10
       ORDER BY resistance DESC LIMIT 20`
    ).all()

    for (const row of (rows.results ?? []) as SkillPathRow[]) {
      const skillName = (row.target as string).replace('skill:', '')
      const skillTid = await getSkillTid(env, skillName)
      if (!skillTid) continue

      // Fetch recent failures for this skill from D1
      const failures = await env.DB.prepare(
        `SELECT content FROM messages
         WHERE group_id LIKE ? AND role = 'assistant'
         ORDER BY ts DESC LIMIT 20`
      ).bind(`%${skillName}%`).all()

      if (!failures.results?.length) continue

      // Rewrite skill prompt using failures as training material
      const newPrompt = await rewriteSkillPrompt(
        env,
        skillName,
        row as SkillPathRow,
        failures.results as { content: string }[],
      )
      if (!newPrompt) continue

      // Update thing.prompt and increment thing.generation in TypeDB
      await updateSkillPrompt(env, skillTid, newPrompt)
      // Invalidate KV cache
      await env.KV.delete(`skill:${skillName}:prompt`)
    }
  })())
  break
}
```

---

## Gap 6 — No KV snapshot for hypotheses

**Problem:** `recallHypotheses` queries TypeDB on every LLM call. For agents
handling 100+ concurrent chats this is a TypeDB round-trip per turn.

**Fix — add a snapshot layer to `substrate.ts`:**

```ts
const HYPOTHESIS_CACHE_TTL = 300  // 5 minutes

export const recallHypotheses = async (
  env: Env,
  searchTerm: string,
): Promise<HypothesisRow[]> => {
  const cacheKey = `hyp:${searchTerm.slice(0, 64)}`

  // Hot path: KV snapshot
  const cached = await env.KV.get(cacheKey, 'json') as HypothesisRow[] | null
  if (cached) return cached

  // Warm path: TypeDB query (existing logic)
  const rows = await queryTypeDB(env, searchTerm)

  // Write back to KV
  await env.KV.put(cacheKey, JSON.stringify(rows), { expirationTtl: HYPOTHESIS_CACHE_TTL })
  return rows
}
```

Invalidate on write:

```ts
// In rememberHypothesis and applyDiff:
await env.KV.delete(`hyp:${actorUid.slice(0, 64)}`).catch(() => {})
```

---

## Gap 7 — Scope not enforced on hypothesis recall

**Problem:** `recallHypotheses` returns any hypothesis matching the string,
regardless of `scope`. Group A's private hypotheses are visible to group B agents.

**Fix — add scope filter to `recallHypotheses`:**

```ts
export const recallHypotheses = async (
  env: Env,
  actorUid: string,
  groupId?: string,
): Promise<HypothesisRow[]> => {
  const safe = actorUid.replace(/"/g, '')
  const safeGroup = (groupId ?? '').replace(/"/g, '')

  // scope filter: return private hypotheses for this actor,
  // group hypotheses for actors in this group, and public hypotheses
  const scopeClause = safeGroup
    ? `{ $sc == "public"; } or { $sc == "group"; $s contains "${safeGroup}"; } or { $sc == "private"; $s contains "${safe}"; };`
    : `{ $sc == "public"; } or { $sc == "private"; $s contains "${safe}"; };`

  // ... rest of query with scopeClause injected
}
```

---

## Practical Example: Chat Memory Lifecycle

Brad uses a delivery platform's support agent on Telegram.
Each step names which memory verb fires.

### Session 1 — First contact

```
Brad: "My order hasn't arrived. It was a weekend delivery."

ingest()
  uid   = telegram:brad123
  group = conv:telegram:brad123:support
  tags  = ["delivery", "complaint"]

graph snapshot: empty — new actor, no paths, no hypotheses

LLM call: generic delivery response

outcome: success

remember()   → signal written to D1 (episode stored)
reinforce()  → mark('skill-runner', 'skill:support', 1) → strength=1

verbs this turn: remember, reinforce
```

### Session 5 — same week

```
graph snapshot:
  highways: [{ to: "delivery", strength: 4, status: "open" }]
  hypotheses: []

recognize()  → sense('actor→skill:delivery') = 4 → open path, growing

Agent proactively mentions weekend cut-off times.
Brad didn't ask. The agent recognized the pattern.

reinforce()  → mark strength to 5, 6

verbs: recognize, reinforce
```

### L6 harden — hourly, after session 20

```
claw_paths: skill:support strength=18

generalize()  →  L6 inserts hypothesis:
  statement:  "skill:support is a proven capability"
  confidence: 0.82
  source:     "observed"
  scope:      "group"

introspect()  →  skill:support status = "open" (approaching highway)

graph snapshot next session includes:
  [fact] skill support proven (82%)

verbs: generalize (automated, L6)
```

### Session 21 — Brad returns after a month

```
graph snapshot:
  actor.status:  "proven"              ← TypeDB proven-actor rule
  highways:      [delivery(18), weekend(11)]
  hypotheses:
    [fact] skill support proven (82%)
    [hint] delivery correlates with weekend orders (71%)

recall()     → context pack assembled from snapshot
recognize()  → agent sees highway to delivery, highway to weekend

Agent: "Hi Brad — any weekend delivery questions?"
Brad has not said a word yet.

verbs: recall, recognize
```

### Dreaming — 2am, week 4

```
imagine()  →  L7 frontier across all groups:
  Brad + Maria + Javier — 25 sessions, delivery + weekend clustering
  no hypothesis captures Monday morning pattern yet

generalize()  →  synthesizeDiff produces:
  "delivery complaints peak Monday morning, source: weekend orders"
  confidence: 0.84, sessions: 25

auto-applied.

Next Monday context pack:
  [fact] delivery complaints peak Monday morning (84%)

Agent pre-empts the call.

verbs: imagine (L7), generalize (dreaming)
```

### Skill struggling — escalation

```
skill:escalation  strength=3, resistance=12

suppress()  signals have accumulated across 3 failed sessions

L5b tick:
  resistance > strength, sample >= 10

generalize()  →  rewriteSkillPrompt() from failure transcripts
  → generation: 1 → 2
  → KV cache invalidated

Next escalation session uses generation 2 prompt.

verbs: suppress (accumulated), generalize (L5b)
```

---

## Implementation Order

| Cycle | What | Files | Unblocks |
|-------|------|-------|----------|
| C1 | Schema fix (Gap 1) | `schema/one.tql` | Everything — broken today |
| C1 | Scope enforcement (Gap 7) | `agents/src/substrate.ts` | Security — broken today |
| C2 | Skill signal paths (Gap 2) | `agents/src/skill-tools.ts` | reinforce/suppress verbs, L6, L5b, dreaming |
| C2 | `prompt`/`generation` on `thing` (Gap 3) | `schema/one.tql` | L5b |
| C2 | Graph snapshot + `query_graph` tool | `agents/src/pipeline.ts`, `agents/src/tools.ts` | Deterministic chat context, introspect verb |
| C3 | KV hypothesis snapshot (Gap 6) | `agents/src/substrate.ts` | recall verb on hot path |
| C4 | L5b skill-evolution tick (Gap 5) | `agents/src/cron.ts` | generalize verb for skills |
| C5 | Dreaming tick (Gap 4) | `agents/src/cron.ts`, `agents/src/agents/dreaming.ts` | imagine + generalize at scale |

C1 is a hotfix. After C2 the memory loop is closed end-to-end for the first
time — all 11 verbs have a live wire.

---

## See Also

- [memory-agents.md](memory-agents.md) — Full process layer architecture
- [world-memory.md](world-memory.md) — L1-L7 loops in detail
- [memory.md](memory.md) — The "no RAG" claim
- 08-memory.md 
- [dictionary.md](dictionary.md) — Canonical names
