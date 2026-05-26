---
title: Education — ONE Education Ontology & Agent Analytics Platform
slug: education
type: plan
tier: complex
mode: construction
tags: [education, competence, irt, bkt, projection, d1, migration, schema, vocab]
source_of_truth:
  - one/education-ontology.md
  - one/education-schema.tql
  - web/agent-analytics.md
  - claw/src/substrate.ts
  - web/src/lib/eval/grader.ts
show: false
escape:
  condition: "any C W4 fails delta_tsc > 0 twice"
  action: "halt; re-scope failing cycle before retrying"
context_triggers:
  - pattern: "bkt|irt|mastery|attempt|competence"
    inject: "one/education-ontology.md §6 two inferences"
  - pattern: "\\.tql|TypeDB|typedb"
    inject: "one/education-schema.tql"
---

# Education — ONE Education Ontology & Agent Analytics Platform

**Goal:** Learning as a process, substrate-native — vocabulary locked, facts flowing, competence measured, value on-chain.

**Exit:** `curl localhost:4321/api/agents/tutor/competence?learner=alice` returns `{ skill, bktProb, masteryLevel, theta, sampleCount }[]` with real data after seeding 5 attempt events via POST `/api/agent-events`.

**Spec:** `one/education-ontology.md` (§1–§8) — signal contract, 6-dimension mapping, four analytics layers, two-inference architecture, Sui roadmap.

---

## Dependency graph

### Cycle-level

```
C1:vocab ──→ C2:migration ──→ C3:projection ──→ C4:competence-api
  [x done]
```

C1→C2: schema types (`EducationSignalData`) consumed by migration + projection.
C2→C3: projection writes to `attempts` table (C2 creates it).
C3→C4: competence API reads `learner_skills` written by projection actor.

### W3 agent parallelism map

```
C2 W3a — parallel:
  agent-1  →  web/migrations/0031_education_attempts.sql
  agent-2  →  one/education-ontology.md  (doc: add D1 schema section)

C3 W3a — parallel:
  agent-1  →  claw/src/projection/education.ts
  agent-2  →  web/src/lib/competence/bkt.ts
  agent-3  →  web/src/lib/competence/irt.ts
  agent-4  →  web/src/lib/competence/types.ts
  agent-5  →  web/src/lib/competence/index.ts
  agent-6  →  web/migrations/0032_learner_skills.sql

C4 W3a — parallel:
  agent-1  →  web/src/pages/api/agents/[id]/competence.ts
  agent-2  →  web/src/lib/competence/query.ts
  agent-3  →  one/education-ontology.md  (doc: update Phase 2→done)
```

---

## C1 — Vocabulary lock ✅ DONE

**Shipped:** 2026-05-14 · rubric=0.929

**What landed:**
- `one/education-schema.tql` — TypeDB schema, 11 attributes + 2 relations, 0 new dimensions
- `one/education-ontology.md` — authoritative domain doc
- `one/dictionary.md` — education vocabulary section (mastery tiers, signal kinds, group/thing discriminators)
- `one/dsl.md` — education signal conventions + 3 worked examples
- `sdk/src/types.ts` — `EducationTag`, `PheromoneDeposit`, `EducationSignalData`
- `CLAUDE.md` — `education-ontology.md` in canonical docs table

**Status:** - [x] W1 - [x] W2 - [x] W3 - [x] W4

---

## C2 — D1 attempts table

**Goal:** `attempts` table exists in D1; ingestion endpoint writes attempt rows from education-domain events.

**Exit:** `bun run typecheck` passes; migration file present; `POST /api/agent-events` with `data.tags[0].kind="attempt"` writes a row to `attempts`.

**Status:** - [ ] W1 - [ ] W2 - [ ] W3 - [ ] W4

### W1 targets
- `web/migrations/0030_discovery_calls.sql` — confirm latest migration number (next = 0031)
- `web/src/lib/agent-events.ts` — find ingestion logic; locate where to branch on `data.tags`
- `web/src/pages/api/agent-events.ts` — confirm ingestion endpoint shape
- `one/education-ontology.md §3.1` — D1 store spec

### W2 decisions
- Migration number: 0031
- `attempts` table shape:
  ```sql
  CREATE TABLE attempts (
    id              TEXT PRIMARY KEY,       -- ulid
    ts              INTEGER NOT NULL,       -- epoch ms
    slug            TEXT NOT NULL,
    agent_id        TEXT NOT NULL,
    learner_id      TEXT NOT NULL,          -- actor.aid
    item_id         TEXT NOT NULL,          -- thing.tid (thing-type='item')
    skill_id        TEXT,                   -- thing.tid (thing-type='skill') — nullable
    correct         INTEGER,               -- 0 | 1 | NULL (not scored)
    elapsed_ms      INTEGER,
    edu_verb        TEXT NOT NULL DEFAULT 'submitted',
    payload         TEXT NOT NULL DEFAULT '{}'
  );
  CREATE INDEX idx_attempts_learner  ON attempts(slug, agent_id, learner_id, ts);
  CREATE INDEX idx_attempts_skill    ON attempts(slug, agent_id, skill_id, ts);
  CREATE INDEX idx_attempts_item     ON attempts(item_id, ts);
  ```
- Branch in ingestion: `if (tags[0]?.domain === "education" && tags[0]?.kind === "attempt")` → also insert into `attempts`

### Diff specs

**spec-1: create migration**
- TARGET: `web/migrations/0031_education_attempts.sql`
- ACTION: create
- CONTENT: `attempts` table + 3 indexes per W2 shape above

**spec-2: branch ingestion in agent-events.ts**
- TARGET: `web/src/lib/agent-events.ts`
- ANCHOR: W1 confirms — after D1 insert block in `emitEvent()`
- ACTION: insert-after
- NEW: education-domain branch writing to `attempts`

**spec-3: doc update**
- TARGET: `one/education-ontology.md`
- ANCHOR: `D1 is already live. TypeDB competence layer is Phase 2.`
- ACTION: replace
- NEW: `D1 is live. \`attempts\` table added in C2 (migration 0031). TypeDB competence layer is Phase 3+.`

---

## C3 — BKT engine + projection actor

**Goal:** BKT engine estimates `bkt-prob` from a sequence of attempts; projection actor subscribes to education signals and upserts `learner_skills` in D1.

**Exit:** `bun run typecheck` passes; `bktUpdate({ prior: 0.1, params: defaultBktParams, correct: true })` returns `{ prob: number }`; `learner_skills` table exists and is populated by projection actor.

**Prerequisite:** C2 complete.

**Status:** - [ ] W1 - [ ] W2 - [ ] W3 - [ ] W4

### W1 targets
- `web/src/lib/eval/grader.ts` + `web/src/lib/eval/aggregate.ts` — existing eval pattern
- `claw/src/substrate.ts` — signal handler pattern in claw
- `one/education-ontology.md §6` — two-inference boundary (BKT stays in TS)
- `sdk/src/types.ts` — `EducationSignalData` (C1 output)

### W2 decisions
- BKT parameters (Corbett & Anderson 1994):
  - `P(L0)=0.10`, `P(T)=0.20`, `P(G)=0.25`, `P(S)=0.10`
  - Standard forward algorithm
- IRT θ: simple MLE stub returning 0.0 (Phase 3 fills full 2PL)
- `learner_skills` D1 table (migration 0032):
  ```sql
  CREATE TABLE learner_skills (
    id           TEXT PRIMARY KEY,
    slug         TEXT NOT NULL,
    agent_id     TEXT NOT NULL,
    learner_id   TEXT NOT NULL,
    skill_id     TEXT NOT NULL,
    bkt_prob     REAL NOT NULL DEFAULT 0.1,
    mastery_level TEXT NOT NULL DEFAULT 'novice',
    irt_theta    REAL NOT NULL DEFAULT 0.0,
    sample_count INTEGER NOT NULL DEFAULT 0,
    updated_ts   INTEGER NOT NULL,
    UNIQUE(slug, agent_id, learner_id, skill_id)
  );
  ```
- Projection actor: exported `handleEducationSignal(signal, env)` — reads tags, for `attempt` kind: loads recent attempts from D1, runs BKT, upserts `learner_skills`

### Diff specs

**spec-1: competence types**
- TARGET: `web/src/lib/competence/types.ts`
- ACTION: create
- CONTENT: `AttemptRecord`, `BktParams`, `LearnerSkillState`, `CompetenceProfile` interfaces

**spec-2: BKT engine**
- TARGET: `web/src/lib/competence/bkt.ts`
- ACTION: create
- CONTENT: `bktUpdate(state, params, correct)` + `masteryLevel(prob)` — pure functions, no I/O

**spec-3: IRT θ stub**
- TARGET: `web/src/lib/competence/irt.ts`
- ACTION: create
- CONTENT: `irtTheta(attempts)` → `0.0` stub with TODO comment for Phase 3 2PL MLE

**spec-4: barrel export**
- TARGET: `web/src/lib/competence/index.ts`
- ACTION: create
- CONTENT: re-export from bkt, irt, types, query

**spec-5: learner_skills migration**
- TARGET: `web/migrations/0032_learner_skills.sql`
- ACTION: create
- CONTENT: `learner_skills` table per W2 shape

**spec-6: projection actor**
- TARGET: `claw/src/projection/education.ts`
- ACTION: create
- CONTENT: `handleEducationSignal(signal, env)` — branches on `kind`, runs BKT, upserts `learner_skills`

---

## C4 — Competence API endpoint

**Goal:** `GET /api/agents/[id]/competence?learner=<aid>` returns the learner's competence profile.

**Exit:** `curl localhost:4321/api/agents/tutor/competence?learner=alice` returns valid `CompetenceResponse` JSON; `bun run typecheck` passes.

**Prerequisite:** C3 complete.

**Status:** - [ ] W1 - [ ] W2 - [ ] W3 - [ ] W4

### W1 targets
- `web/src/pages/api/agents/[id]/analytics.ts` — existing agent endpoint pattern (auth gate, D1 query shape)
- `web/agent-analytics.md §Files this spec touches` — SHIPPED list to update

### W2 decisions
- Response shape:
  ```typescript
  interface CompetenceResponse {
    learnerId: string
    agentId: string
    skills: {
      skillId: string
      bktProb: number
      masteryLevel: "novice" | "developing" | "proficient" | "mastered"
      irtTheta: number
      sampleCount: number
      updatedTs: number
    }[]
    summary: {
      totalSkills: number
      mastered: number
      proficient: number
      developing: number
      novice: number
    }
  }
  ```
- Query: `SELECT * FROM learner_skills WHERE slug=? AND agent_id=? AND learner_id=?`
- Auth: same `Astro.locals.slug` gate as sibling endpoints

### Diff specs

**spec-1: query helper**
- TARGET: `web/src/lib/competence/query.ts`
- ACTION: create
- CONTENT: `queryLearnerSkills(db, { slug, agentId, learnerId })` → `LearnerSkillState[]`

**spec-2: API endpoint**
- TARGET: `web/src/pages/api/agents/[id]/competence.ts`
- ACTION: create
- CONTENT: GET handler, auth gate, `queryLearnerSkills`, returns `CompetenceResponse`

**spec-3: doc update**
- TARGET: `web/agent-analytics.md`
- ANCHOR: `web/src/pages/api/agents/[id]/analytics.ts` in SHIPPED section
- ACTION: insert-after
- NEW: `  web/src/pages/api/agents/[id]/competence.ts      — learner competence profile (bkt-prob, mastery-level, irt-theta)`

---

## W4 rubric targets (C2–C4)

| Dimension | Target |
|-----------|--------|
| Security | ≥ 0.90 — no PII beyond opaque actor.aid; auth-gated endpoints |
| Stability | ≥ 0.88 — 0 new tsc errors; BKT pure function; existing analytics unbroken |
| Simplicity | ≥ 0.85 — BKT ≤ 80 LOC; projection actor ≤ 100 LOC |
| Speed | ≥ 0.88 — competence endpoint < 50ms p95 (single D1 query); ingestion fire-and-forget |

---

## Phases 3 + 4 (future TODOs)

| Phase | Deliverable |
|-------|-------------|
| **3** | Behavioural verb taxonomy enforcement · full IRT 2PL MLE · Markov attribution · adaptive item selection (Fisher info) |
| **4** | KST `fun reachable-prerequisites()` TypeQL · Sui competence object · stake-eligible gate |

---

*Phase 1 done. Phase 2: facts flow. Phase 3: numbers compound. Phase 4: value on-chain.*
