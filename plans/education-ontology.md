# education-ontology.md — ONE Education domain

Learning as a process, substrate-native. Six dimensions, one signal, four
analytics layers, two inference types. Caliper and xAPI are diff sources,
not foundations.

| Doc | Owns |
|-----|------|
| `education-ontology.md` (this) | Domain mapping · signal contract · inference split · layer roadmap |
| `education-schema.tql` | TypeDB 3.0 schema — attributes, relations, function stubs |
| `web/agent-analytics.md` | Event taxonomy this domain extends (Tier 1–4) |
| `one/one-ontology.md` | The 6 locked dimensions this domain specialises |

---

## 1. The 6 dimensions, education lens

The dimensions are locked. Education adds vocabulary, not structure.

| ONE dimension | Education specialisation | Discriminator |
|---------------|--------------------------|---------------|
| **Group** | Course · cohort · curriculum · institution | `group-type = 'course' \| 'cohort'` |
| **Actor** | Learner · instructor · item-author · institution | `education-role` attribute |
| **Thing** | Learning object — item · skill · course · module | `thing-type = 'item' \| 'skill'` |
| **Path** | Mastery path (learner→skill), prerequisite edge | `irt-theta`, `bkt-prob`, `mastery-level` |
| **Event** | Attempt · mastery-change · prerequisite-discovery | `edu-verb`, `attempt-correct` |
| **Learning** | Competence hypothesis — "A has mastered X" | `hypothesis` with tag `"mastery"` |

**Why no `learner` entity.** A learner is an actor with `education-role = "learner"`.
Adding a `learner` entity would duplicate actor's identity, auth, and pheromone
machinery. The pattern is discrimination, not proliferation — same as marketing's
`persona` (a group with `group-type = "persona"`).

**Why no `course` entity.** A course is a group with `group-type = "course"`.
Members are actors with `education-role = "learner"`. Containment already handles enrollment.

---

## 2. The signal contract

```
signal = { receiver, data }

data = {
  tags?:       { domain: "education", kind: "attempt"|"mastery-change"|"prerequisite" }
  pheromones?: { edge: {from, to}, strength?, resistance? }[]
  ontology?:   { learner: actor.aid, item: thing.tid, skill: thing.tid }
  weight?:     number    ← pheromone deposit strength; NOT a score
  content?:    unknown   ← attempt payload, mastery snapshot, etc.
}
```

`data.ontology` is optional pre-computed context. The emitter is never required
to be ontology-aware — the projection layer enriches if absent.

`data.weight` is pheromone deposit strength (mark/warn). Education scores
live in `data.content`, never in `data.weight`. The two must not collide
(weight=0.8 means "strong deposit", not "80% score").

**Signal vs Event:** signal = what moves (thin, fast). Event = what a signal
becomes once projected into the 6-dimension form. Never used interchangeably.

---

## 3. The three layers

The ontology is a consumer, not a gatekeeper. It never validates at emission.

```
Signal layer      {receiver, data} routing. No ontology here. Fast.
      │
      ▼
Projection layer  Actor subscribing to signal stream.
                  Maps tags→Event, pheromones→decaying Paths,
                  resolves ontology hints.
                  Statistical estimation runs HERE (IRT/BKT) — see §8.
      │
      ▼
Canonical layer   TypeDB (competence graph) + D1 (event log).
                  Split store — see §3.1.
```

### 3.1 Split canonical store

| Store | What | Why |
|-------|------|-----|
| **D1** | `agent_events` rows — projected Event stream, behavioural/ecological layers | High-throughput append; existing schema in `web/agent-analytics.md` |
| **TypeDB** | Actor/Thing/Path/hypothesis graph — competence model, KST, eligibility | Deterministic logic; explainable reasoning path; stakeable asset (§5) |

D1 is already live. TypeDB competence layer is Phase 2.

---

## 4. Four analytics layers

### 4.1 Behavioural — what happened

Five verb families (Caliper/xAPI diff, de-profiled):

| Family | Verbs |
|--------|-------|
| Lifecycle | started · paused · resumed · completed · abandoned · restarted |
| Traversal | navigated-to · seeked · returned-to · skipped |
| Engagement | viewed · interacted-with · annotated · bookmarked · tagged |
| Evaluation | submitted · scored · graded · rated · certified |
| Production | created · modified · derived |

These extend `agent-analytics.md` Tier 1–3. Education attempts emit
`edu-verb` on the Event; the same event row flows into D1 `agent_events`.

### 4.2 Competence — is the actor getting better

IRT 2-parameter model: each item is a psychometric item with difficulty (`irt-b`)
and discrimination (`irt-a`). Actor ability is latent `irt-theta` per skill domain,
estimated by the projection layer after each attempt batch.

BKT (Bayesian Knowledge Tracing): `bkt-prob` = P(mastered) from a sequence
of attempts. Preferred over DKT because competence must be explainable — it
becomes a stakeable asset (§5) and staking requires an auditable proof.

Mastery tiers: `novice → developing → proficient → mastered`
(derived from `bkt-prob` thresholds: 0.4 / 0.6 / 0.80).

KST (Knowledge Space Theory): prerequisite-of relation defines the partial
order of skills. `fun reachable-prerequisites()` (Phase 2) gives the next
reachable states — the formal basis for adaptive item selection.

**Scope: prescriptive.** The competence layer selects the next item that most
reduces uncertainty about the learner's θ (Fisher information, ATLAS pattern).
Descriptive curve is the trivially-derived subset.

**Three actors, one mechanism:**
1. The agent improving at tasks
2. The eval/grader judging it
3. The human gaining mastery of the agent (onboarding = rising-difficulty assessment)

### 4.3 Economic — is it worth anything

Markov-chain attribution: credit assigned by removal effect across delegated
agent chains. Lives in projection layer (statistical). TypeDB holds the chain
topology; weighting computed outside TypeDB.

### 4.4 Ecological — what is the system doing as a whole

Fed directly from `data.pheromones`. Already live via substrate L2–L7 loops.
Education adds mastery-path pheromone (mark on competence gain, warn on repeated
failure) alongside the existing task-routing pheromone.

---

## 5. Sui — competence as market infrastructure

**Chain, stated once:**

| Layer | Collapses cost of | Result |
|-------|-------------------|--------|
| AI | Attention | Continuous individual tutoring |
| Competence layer | — (the valuation engine) | Only trustworthy, machine-readable capability measure |
| Blockchain | Trust & settlement | Competence = stakeable, tradeable, enforceable asset |

Competence object (Phase 4): a Sui object owned by the actor, carrying
`irt-theta[]`, `mastery-level`, `sample-count`, `provenance` (TypeDB query path).
Tradeable. The signal stream that feeds it is never tradeable (firewall).

---

## 6. The two inferences — hard boundary

```
Statistical (projection layer, TypeScript)          Deterministic (TypeDB, TypeQL functions)
─────────────────────────────────────────           ──────────────────────────────────────────
IRT θ estimation from attempt sequence              KST prerequisite closure
BKT P(mastered) from attempt sequence               mastery-eligible gate (bkt-prob ≥ 0.80, n ≥ 20)
Markov removal-effect attribution weights           stake-eligible gate
                                                    contract-requirement satisfaction
                                                    delegated-chain membership
```

The statistical layer **produces facts**; TypeDB **reasons over them as given**:

> Projection emits: *"actor A's θ on skill X = 1.4, bkt-prob = 0.83, as of T."*
> TypeDB ingests that as attribute values and runs deterministic logic downstream.

Everything touching money, stakes, contracts, or eligibility is deterministic
and auditable. The estimate is input; the economic logic is fully explainable.

TypeDB does not do statistical inference. TypeQL functions are logical, not probabilistic.

---

## 7. Build sequencing

| Phase | Deliverable | Files |
|-------|-------------|-------|
| **1 (done)** | Vocabulary lock — schema, ontology doc, dictionary/dsl/types | `education-schema.tql`, this doc, `dictionary.md`, `dsl.md`, `sdk/src/types.ts` |
| **BKT on evals (done)** | Soft BKT wired to existing skill eval loop — mastery curve on every eval run, no new infra | `web/src/lib/eval/mastery.ts`, `web/src/pages/api/eval.ts` |
| **2** | Projection actor + IRT/BKT engines + competence endpoints | `claw/src/projection/education.ts`, `web/src/lib/competence/`, D1 migration |
| **3** | Behavioural/economic/ecological analytics layers + verb taxonomy enforcement | `web/src/pages/api/agents/[id]/competence.ts`, Markov attribution |
| **4** | KST next-state prescription + Sui competence object | `contracts/competence.move`, TypeQL `fun reachable-prerequisites` |

---

## 8. Open decisions (carry forward)

- **`data.ontology` edge:** how much ontology work is allowed at the edge vs
  resolved by projector? Current: projector enriches if absent. Edge can include
  pre-computed fragments but is never required to.
- **BKT vs DKT:** BKT chosen for explainability. Revisit if accuracy gap
  proves material after Phase 2 data.
- **Statistical inference boundary:** IRT/BKT stays outside TypeDB permanently.
  Deliberate; flagged. Don't move statistical models into TypeDB-adjacent infra
  without explicit decision.
- **Prescriptive scope confirmation:** adaptive item selection + KST confirmed
  as Phase 3 target. Descriptive is a subset.

---

*Phase 1: names freeze. Phase 2: facts flow. Phase 3: numbers compound. Phase 4: value on-chain.*
