# Marketing Ontology — Data Assessment

The quality layer between scraped content and the substrate. **Before** chunks become `thing:knowledge`, gates score them. **After** they're embedded and indexed, gates score retrieval, tagging, grounding. **After** patterns extract from validated chunks, gates score pattern→skill emission. Every gate reports a number; every reject closes the loop with `warn()`; every accept compounds with `mark()`.

**See Also:** [marketing-ontology.md](marketing-ontology.md) — schema, tags, dimensions. [dictionary.md](dictionary.md) — names. [rubrics.md](rubrics.md) — generic 4-dim rubric this doc specialises. [.claude/rules/engine.md](../.claude/rules/engine.md) — the three locked rules. [skills-implementation.md](skills-implementation.md) — skill emission shape this pipeline feeds.

**Code paths (one.ie/web):**
- `src/lib/skill/parser.ts` — frontmatter + body parse, the shape every emitted skill must satisfy
- `src/lib/skill/import.ts` — R2 PUT with content-hash dedup; mirror this for knowledge chunks
- `src/lib/skill/loader.ts` — load-by-slug-and-name; knowledge loader follows the same pattern at `<slug>/knowledge/...`
- `src/pages/api/skill/import.ts` — shared backend for ingestion (auth + parse + write)
- `src/lib/eval/aggregate.ts` — pass_rate / time / token aggregation; reused for post-RAG sample grading
- `web/skills/qualify-lead.md` — reference shape for emitted skill bodies (3 imperative lines, not bureaucracy)

> Marketing-ontology.md says **what** the substrate stores.
> This doc says **how content earns its way in** — and **how skills get cut out the other side**.
> No new dimensions. New verbs: `assess`, `gate`, `harden`, `cut`.

---

## The Principle

```
SCRAPE   ─▶  PRE-RAG GATE   ─▶  EMBED   ─▶  POST-RAG GATE   ─▶  PATTERN   ─▶  SKILL GATE   ─▶  SKILL
 raw          (chunk-level)      vector       (corpus-level)      claim         (emit-level)      market

 books        7 rubrics          embed +      4 rubrics            evidence     trigger optim     SKILL.md
 video        score ≥ 0.65       tag-class    score ≥ 0.70         lift,        (skill-creator)   in slug/
 articles     mark / warn        store        mark / warn          confidence   pass ≥ 0.70       skills/
 podcasts     /dissolve          knowledge    sample-graded        ROI-rank
```

Each gate is a `dissolve|warn|mark` decision with deterministic numeric receipts. The pipeline never silently passes — every chunk leaves a trace in pheromone, every reject leaves a row in `dissolved.log`.

---

## What this doc owns vs. what `marketing-schema.tql` already has

`marketing-schema.tql` is authoritative. Knowledge, pattern, and hack are already `thing-subtype` discriminants, and most of the data attributes are declared there. This doc must layer onto that — never duplicate.

### Already in `marketing-schema.tql` (do NOT redeclare)

```tql
# thing already owns these when thing-subtype ∈ {knowledge|pattern|hack}:
chunk-text, embedding, source-url, published-at, medium, chunk-author,
claim, expected-lift, lift-confidence, evidence-count, persona-fit-tags,
conditions, cost-estimate, pattern-status (candidate|validated|refuted|retired)

# evidence relation already wires chunk ⇄ pattern:
relation evidence, relates supports, relates contradicts, owns evidence-type;
# evidence-type ∈ {case-study | data | anecdote | theory}

# Functions already shipping:
pattern_roi($p, $persona)              # ROI scoring
recommend_strategy($persona, $kpi)     # decision-framework entry point
best_pattern($persona, $kpi)           # single highest-ROI pick
patterns_by_framework($framework)      # knowledge-harvest reporting
persona_hardening_status($p)           # hardened|provisional|candidate|dissolve
marketing_path_status($e)              # highway|fresh|active|fading|toxic
ice_score($x), experiment_gate($x)     # Sean-Ellis high-tempo gating
value_score($o), offer_fits_to_ship($o)# Hormozi value-equation
```

### What this doc adds (the pure delta)

| Owns                                          | New in this doc                                         |
|-----------------------------------------------|---------------------------------------------------------|
| Pre-RAG, post-RAG, skill-gate **rubrics**     | 13 net-new quality attributes on `thing` (subtype-discriminated) |
| **Sample-grading protocol** (N=100)           | 1 new relation: `cuts-from` (skill audit trail)         |
| **Skill-cut criteria**                        | Reuses existing `evidence` relation for chunk→pattern grounding |
| **Re-ingestion / version-hash** behaviour     | Reuses existing `experiment` entity for holdout tests   |
| **Token budget** for the pre-RAG classifier   | Reuses `pattern_roi` / `marketing_path_status` / `persona_hardening_status` for gating |

No new dimensions. No new tag namespaces beyond `metric:*` (which doubles as the value space for `experiment.metric-target`). One new relation. 13 new attributes — all subtype-discriminated on the existing `thing` entity.

---

## Schema additions

Layer onto `thing` via subtype discrimination — same pattern as the offer attributes already in `marketing-schema.tql:154-227`. Pre-RAG attributes are meaningful when `thing-subtype = "knowledge"`; post-RAG attributes likewise; cut audit attributes likewise plus `thing-subtype = "pattern"`.

```tql
# ── ASSESSMENT — pre-RAG (thing-subtype = knowledge) ──────────────────────
attribute source-credibility, value double;     # 0..1
attribute license-status, value string;         # public-domain|open|fair-use|restricted|unknown
attribute provenance, value string;             # url + scrape-method
attribute scraped-at, value datetime;
attribute dedup-cluster, value string;          # SHA-256 of normalized text
attribute novelty-score, value double;          # 0..1 vs existing corpus
attribute tag-coverage, value double;           # 0..1 of mandatory namespaces hit
attribute safety-flag, value string @card(0..); # toxic|medical-claim|financial-claim|unverifiable
attribute pre-rag-score, value double;          # composite; gate ≥ 0.65
attribute pre-rag-decision, value string;       # accepted|quarantine|rejected

# ── ASSESSMENT — post-RAG (thing-subtype = knowledge) ─────────────────────
attribute retrieval-precision, value double;    # 0..1 — sampled
attribute tag-accuracy, value double;           # 0..1 — sample-graded
attribute grounding-rate, value double;         # 0..1 — citation↔chunk match rate
attribute post-rag-score, value double;         # composite; gate ≥ 0.70
attribute post-rag-decision, value string;      # promoted|re-embed|refuted
```

The `thing` entity gets these via additive `owns` — no entity redefinition.

### One new relation — skill-cut audit trail

```tql
relation cuts-from,
    relates skill @card(1),
    relates pattern @card(1..),
    owns cut-confidence,                # 0..1
    owns cut-at,                        # datetime
    owns tag @card(0..);
# A skill emits from one or more validated patterns. The relation is the audit trail
# that survives even if the pattern is later refuted or retired (skill gets pulled,
# but the trace remains).
```

### What gets reused, not invented

| Need | Reuse |
|------|-------|
| Chunk supports / contradicts a claim | existing `evidence` relation (`marketing-schema.tql:316`) — supports/contradicts roles, evidence-type ∈ case-study/data/anecdote/theory |
| Pattern hardening | existing `pattern-status` attribute + L6 promotion criterion in `marketing-ontology.md` |
| Holdout test for lift-confidence | existing `experiment` entity (`marketing-schema.tql:367`) — owns p-value, observed-lift, sample-size-needed |
| ROI ranking for skill cuts | existing `pattern_roi($p, $persona)` function |
| Recommendation by KPI | existing `recommend_strategy($persona, $kpi)` function |
| Tag-spine for retrieval queries | existing `tag @card(0..)` on every entity |
| Path tier classification of a chunk | existing `marketing_path_status` function (highway/fresh/active/fading/toxic) |

`pattern-yield` and `pattern-skill-eligible` are **derived**, not stored — they're functions over the `evidence` relation and existing pattern attributes (see *Pattern → Skill* below). Nothing in TypeDB stores what can be computed.

That's the full schema delta: 13 attributes, 1 relation. Everything else is reuse.

---

## Pre-RAG Gate — 3 hard gates + 4 weighted dims

Every chunk runs through three **hard gates** first (binary AND). Any fail = reject before scoring. Surviving chunks then score on four **weighted dims**, composite ≥ **0.65** to accept.

This separation matters: license/safety/length are not "lower the score by 25%" — they're either fine or they kill the chunk. A mean-of-7 with binary inputs hides hard fails behind soft averages.

### Hard gates (any fail → reject)

| Gate | Rule | Detection method |
|------|------|------------------|
| **license-clean** | not `restricted`, not `unknown` for paid skills | (a) SPDX matcher in source repo / page; (b) URL-domain heuristic (`gutenberg.org` → public-domain, `*.gov` → public-domain, paywall hosts → restricted, fair-use ≤ 250-tok excerpts allowed); (c) LLM fallback on edge cases, output `{license, confidence}`, < 0.7 confidence → `unknown` |
| **safety-clean** | no flag at severity ≥ 0.7 (toxic / medical-claim / financial-claim / unverifiable) | classifier ensemble: keyword pattern + Workers AI moderation; both must agree to flag at severity ≥ 0.7 |
| **length-sane** | tokens ∈ [80, 4000] | tiktoken count; <80 = thin (drop), >4000 = re-chunk (split, re-run pipeline) |

Hard-fail action: `dissolve` (drop, log to `<slug>/knowledge/_dissolved.log`). Severity-0.9 safety hits → `warn(source-path, 2)` so the source's credibility decays for future ingests.

### Weighted dims (compose to 0.65 gate)

| # | Dim | Measures | Weight |
|---|-----|----------|-------:|
| 1 | **source-credibility** | author authority + publication tier + cross-citation count | 0.30 |
| 2 | **dedup-novelty** | 1 − max(cosine-sim) vs existing corpus; SHA-256 exact dedup runs first | 0.25 |
| 3 | **tag-coverage** | hits ≥ 1 from {framework, persona-fit, awareness, lever, lifecycle, metric}; coverage = hits / 6 | 0.25 |
| 4 | **claim-density** | claim-classifier hits per 1000 tokens; capped at 3 | 0.20 |

```
pre-rag-score = 0.30·source-credibility
              + 0.25·dedup-novelty
              + 0.25·tag-coverage
              + 0.20·min(claim-density / 3, 1)
```

### Decision table

| Outcome | Action | Pheromone |
|---------|--------|-----------|
| any hard gate fails | `dissolve` | `warn(source-path, 1)` (or `2` for severity-0.9 safety) |
| hard gates pass, score ≥ 0.65 | accepted → embed + store | `mark(source-path, score)` |
| hard gates pass, 0.50 ≤ score < 0.65 | quarantine → researcher-agent review queue | `warn(source-path, 0.5)` |
| hard gates pass, score < 0.50 | rejected | `warn(source-path, 1)` |

### Why each test exists

| Test | Why marketing breaks without it |
|------|----------------------------------|
| license (gate) | Restricted text in a paid skill = legal risk, brand-safety warn |
| safety (gate) | Medical/financial/legal hallucinations on top of marketing claims = compliance incidents |
| length (gate) | <80 tok = no context; >4000 tok = retrieval recall craters |
| source-credibility | A pattern from a tier-3 affiliate blog overrides a Hormozi book = poisoned ROI |
| dedup-novelty | 90% of scraped content repeats. Without dedup, retrieval becomes parrot |
| tag-coverage | Untagged chunks can't be recommended to a persona — invisible to decision framework |
| claim-density | Pure narrative ("I once worked with Apple…") yields no extractable patterns |

### Token budget for the pre-RAG classifier

Pre-RAG runs three classifiers per chunk. Without a budget, scrape costs explode.

| Classifier | Model | Tokens (in/out) | Cost/1k chunks |
|------------|-------|-----------------|---------------:|
| tag-classifier (namespace assignment) | Workers AI Llama-3.1-8B | ~600 / ~80 | $0.04 |
| claim-classifier (binary + count) | Workers AI Llama-3.1-8B | ~600 / ~20 | $0.02 |
| safety-ensemble (keywords first; LLM only if pattern hits) | Workers AI on hits only | ~400 / ~20 | ~$0.005 |
| **Total per 1k chunks** | | | **~$0.065** |

Source-credibility uses a static lookup table (publication-tier registry maintained in `<slug>/knowledge/_credibility.json`); no LLM cost. Dedup-novelty is a vector search; cost rolls into embedding budget.

---

## Post-RAG Gate — 4 Rubrics

After chunks are embedded and indexed, sample N=100 per source per ingestion batch, score them, project to the corpus. Gate at **≥ 0.70** (higher than pre-RAG — embedded content has fewer false-positives but errors compound across many retrievals).

| # | Rubric | Measures | Pass |
|---|--------|----------|------|
| 1 | **retrieval-precision** | for K canonical queries, % of returned chunks judged relevant by `analyst` (judge mode) | ≥ 0.70 |
| 2 | **tag-accuracy** | sample N=100, judge-agent grades chunk tags against ground truth | ≥ 0.85 |
| 3 | **grounding-rate** | LLM citations in answer text point to chunks whose content supports the cite | ≥ 0.80 |
| 4 | **pattern-yield** | `pattern_yield($source)` — fraction of source chunks bound by `evidence` relation to ≥1 pattern within 2 cycles | ≥ 0.05 |

```
post-rag-score = mean(
  retrieval-precision,
  tag-accuracy,
  grounding-rate,
  min(pattern_yield($source) / 0.05, 1)
)
```

`pattern-yield` is computed via the function (defined below in *Pattern Extraction*), not stored as an attribute — TypeDB queries the `evidence` relation at sample time.

### Decision table

| Score | Action | Pheromone |
|-------|--------|-----------|
| ≥ 0.70 | promoted → eligible for pattern extraction | `mark(source, score)` |
| 0.55–0.70 | re-embed (tweak chunker, add tags, redo embed) | `warn(source, 0.5)` |
| < 0.55 | refuted → quarantine entire source from the corpus | `warn(source, 1)` |

### Sampling protocol

```
for each source S ingested in batch B:
  sample 100 chunks uniform random
  for each chunk c:
    1. retrieval-test: pick 5 queries the chunk ought to answer; rank c in top-K
    2. tag-grade: judge-agent compares c.tags to ground-truth tags
    3. grounding-test: synth 3 LLM answers citing c; verify citation supports answer
  pattern-yield: query patterns where c ∈ source, count survivors after 2 cycles
```

Sample size 100 ≈ ±10% confidence at p=0.05. Higher batches (paid sources, large books) get N=200.

### Why post-RAG matters

A chunk can pass pre-RAG (good source, novel, tagged, claim-dense) and still fail in production:

- Embedding-classifier mis-tagged it (`framework:hormozi` should have been `framework:brunson`)
- Chunk boundary cut the claim from its evidence
- Chunk surfaces for the wrong query (vector neighbors are misleading)
- LLM cites it, but the cite paraphrases something the chunk doesn't actually say

Post-RAG catches what pre-RAG can't see — the chunk in its retrieval context.

---

## Pattern Extraction — From Knowledge to Claim

After post-RAG promotion, knowledge chunks (`thing-subtype = "knowledge"`) feed pattern extraction. A pattern is a `thing` with `thing-subtype = "pattern"` and `pattern-status ∈ {candidate|validated|refuted|retired}` per `marketing-schema.tql`. This doc owns the gate that decides which clusters of chunks become a pattern, and which patterns are eligible for skill emission.

### Pattern candidate criteria

A cluster of ≥ 3 knowledge chunks becomes a **pattern candidate** if:

1. They share a `framework:*` tag
2. They share ≥ 2 persona-fit tags (e.g. `persona:b2b-saas`, `awareness:3`)
3. They share or imply a `claim` (extractable by `researcher` agent) — stored in the new pattern's `claim` attribute
4. They share a `metric:*` tag — which doubles as the value space for `experiment.metric-target`

When the cluster forms, create a new `thing` with `thing-subtype: "pattern"`, then bind each source chunk via the existing `evidence` relation:

```tql
insert
  $pat isa thing,
    has thing-subtype "pattern",
    has pattern-status "candidate",
    has claim "...",
    has expected-lift 0.0,                # awaits holdout
    has lift-confidence 0.0,
    has evidence-count $n,
    has persona-fit-tags $tags,
    has cost-estimate $c,
    has tag "framework:hormozi", has tag "metric:cvr", ...;
  (supports: $chunk1, contradicts: $chunk2) isa evidence,
    has evidence-type "case-study";
```

### Tag namespace: `metric:*` (new — additive to existing tag-spine)

Existing tag-spine in `marketing-ontology.md §Tags` does not enumerate `metric:*`. Add:

```
metric:ctr | metric:cvr | metric:aov | metric:ltv | metric:cac | metric:roas
metric:nps | metric:retention | metric:k-factor
metric:mql-rate | metric:sql-rate
metric:open-rate | metric:click-rate
metric:churn | metric:nrr
metric:share-of-voice | metric:brand-recall
metric:rank | metric:organic-sessions
metric:cpa | metric:cpm | metric:cpc
metric:funnel-velocity | metric:awareness-fit
```

The string after `metric:` is exactly the value used in `experiment.metric-target` (so `recommend_strategy($persona, "cvr")` matches `tag = "metric:cvr"`). Two surfaces, one vocabulary.

A chunk without a `metric:*` tag can still be ingested (background context, brand voice, etc.) but cannot enter a pattern candidate — `pattern-yield` would be zero. This is the load-bearing rule that makes patterns actionable.

### Hardening — uses the existing `experiment` entity

Every pattern candidate that targets a measurable lift gets bound to an `experiment` (already in schema, `marketing-schema.tql:367`). The experiment carries the holdout, observed-lift, p-value:

```tql
insert
  $exp isa experiment,
    has xid "exp-q4-value-stack",
    has hypothesis-statement "stacking value before price lifts CVR for SMB founders",
    has metric-target "cvr",
    has expected-lift 0.30,
    has sample-size-needed 2000,
    has experiment-status "running",
    has tag "framework:hormozi", has tag "persona:smb-founder";
```

Hardening rule (uses existing `experiment_gate` and `lift_confidence` functions):

- `experiment_gate($exp) == "ship"` AND
- `lift_confidence($exp) >= 0.90` AND
- `evidence-count($pattern) >= 30`

→ pattern updates `pattern-status` from `candidate` to `validated`, `expected-lift` and `lift-confidence` copy from the experiment.

If `experiment_gate == "kill"` after sample-size-needed observations: pattern → `refuted`. If still `inconclusive` after two cycles: pattern → `retired` (parked, not deleted; kept for retrospective comparison).

### Derived attributes — functions, not stored values

Pattern-yield and skill-eligibility are computed, not stored:

```tql
# % of chunks from one source that ended up supporting at least one pattern
fun pattern_yield($source: thing) -> double:
    match
        $chunk isa thing, has thing-subtype "knowledge",
            has source-url $u;
        $source has source-url $u;
        $supported isa thing, has thing-subtype "knowledge", has source-url $u;
        (supports: $supported, contradicts: $_) isa evidence;
    return first count($supported) / count($chunk);

# Boolean: pattern is ready for skill emission
fun pattern_skill_eligible($p: thing, $persona: group) -> boolean:
    match
        $p has pattern-status "validated";
        let $roi = pattern_roi($p, $persona);          # existing fn
        $roi >= 1.0;
        $p has lift-confidence $lc;
        $lc >= 0.90;
    return first true;
```

---

## Skill Gate — From Pattern to SKILL.md

The third and last gate. Marketing skills emit when:

1. **Pattern hardened** — `pattern-status == "validated"` (set by hardening rule above)
2. **ROI rank** — `pattern_roi($p, $persona)` (existing fn) is in the top decile across all personas
3. **Trigger-precision passed** — `skill-creator`'s description optimizer (60/40 train/test split per `agents/skill-creator/SKILL.md` §Description optimization) returns `test-score ≥ 0.70`
4. **Eval pass-rate** — ≥ 70% on the skill's eval set, baseline beaten by ≥ 10pp (aggregated by `web/src/lib/eval/aggregate.ts`)
5. **No safety regression** — running the skill against held-out prompts produces zero severity-≥0.7 safety hits

```tql
fun skill_cut_eligible($p: thing, $persona: group, $trigger: double, $pass: double, $base: double, $safe: integer) -> boolean:
    match
        $p has thing-subtype "pattern", has pattern-status "validated";
        let $roi = pattern_roi($p, $persona);
        $roi >= 1.0;                         # caller validates top-decile via percentile rank
        $trigger >= 0.70;
        $pass >= 0.70;
        ($pass - $base) >= 0.10;
        $safe == 0;
    return first true;
```

When eligible, `skill-creator` (per `agents/skill-creator/SKILL.md`) is invoked to produce a `SKILL.md` from the pattern. On commit, write a `cuts-from` relation linking the new skill to its source pattern(s); the skill artifact lands in `<slug>/skills/<name>/SKILL.md` via the existing `web/src/pages/api/skill/import.ts` write path (passkey-gated).

### Skill frontmatter from pattern

```yaml
---
name: <pattern.claim-tag-stem>
title: <human-readable from pattern.claim>
description: <triggers + when to use, optimised by description-optimizer>
price: <cost-estimate from pattern, marked up by margin>
tags: [<persona-fit-tags>, <framework>, <metric:*>]
provenance: <pattern.cuts-from chunks, R2 keys>
license: <pattern.source-license>
roi-rank: <percentile at cut time>
lift-confidence: <copied from pattern>
---
```

### Skill body from pattern

Match the shape already shipped in `web/skills/*.md` — 3 imperative lines, no headers. The reference is `web/skills/qualify-lead.md`:

```
Ask one question at a time. Start with what brought them here.
Don't pitch until you understand the problem they're trying to solve.
A bad fit discovered early saves everyone time.
```

For an extracted pattern: distil the grounding chunks down to three load-bearing imperatives. The first names the action, the second names the trap to avoid, the third names the verification. Anything longer is bureaucracy and bloats every invocation forever (per `.claude/rules/engine.md` — fewer tokens compound).

The skill-creator runs the eval loop (per `agents/skill-creator/SKILL.md`) before the skill is exposed to chat. Skills that fail trigger-optim or eval gate stay as `pattern-status: validated` but `skill-cut-at` stays null.

---

## Closed Loop — Retrieval Outcomes Update Chunk Strength

This is the substrate verb that makes the corpus learn. Every time a chunk is retrieved AND used in an LLM answer, the runtime emits an `ai-citation` signal (already in the schema's `touch-type` enum, weight 1.5 per `touch_weight()`) — no new edge type needed. The chunk plays `attribution:touch` (already declared on `thing` at `marketing-schema.tql:236`):

```ts
// chunk c is retrieved, included in context, the answer leads to a closed-loop outcome
const { result, timeout, dissolved } = await net.ask({ receiver: handler })

const ts = Date.now()
if (result) {
  // emit ai-citation signal; insert attribution edge from chunk to conversion
  net.signal({ touchType: 'ai-citation', citationRank: c.rank, ts },
             { from: c.id, to: handler })
  net.mark(`chunk:${c.id}`, touch_weight('ai-citation'))   // = 1.5
} else if (timeout) {
  /* neutral — not the chunk's fault */
} else if (dissolved) {
  net.warn(`chunk:${c.id}`, 0.5)                            // chunk surfaced wrong context
} else {
  net.warn(`chunk:${c.id}`, 1)                              // chunk surfaced for wrong query
}
```

After fade (L3, every 5 min), `marketing_path_status($edge)` reclassifies the chunk's path:

- `highway` (strength ≥ 50) → keep, surface preferentially
- `fresh` / `active` → normal weighting
- `fading` (strength < 5) → re-grade post-RAG; if score drops, demote `post-rag-decision` to `re-embed`
- `toxic` (resistance > strength, resistance ≥ 10) → quarantine the chunk; if 3+ chunks from one source go toxic in 1 cycle, drop the source's `source-credibility` and re-evaluate all its chunks

Same compounding mechanic the substrate uses everywhere. Knowledge is just `thing` with `thing-subtype = "knowledge"` and 13 quality attributes.

---

## Operational Invariants — The Five Floors

Match the five from marketing-ontology.md, restated for data:

### 1. Source identity — one source, many surfaces

A book exists as a PDF, an EPUB, a YouTube summary, a podcast cover, a blog excerpt. `same-as` collapses them. Pheromone collapses to the survivor. Without this, "Hormozi $100M Offers" votes for itself 5×.

**KPI:** `source-resolution-rate`. Target > 95%.

### 2. License compliance — what we're allowed to use

Every chunk carries `license-status`. Restricted licenses → can be ingested for personal use only, never emitted as a paid skill, never exported. Unknown licenses → quarantine until resolved. Audit log retained.

**KPI:** `license-clean-rate` per emitted skill. Must be 100% for paid skills.

### 3. Sample size — gates trust

Pre-RAG gates run on every chunk. Post-RAG gates sample 100/source/batch. Pattern hardening requires ≥ 30 observations. Below these, `lift-confidence` capped at 0.5 — the gate output cannot exceed sample-size-implied confidence.

**KPI:** `sample-size-met-rate`. Below 80% means pipeline is shipping low-confidence assessments.

### 4. Retrieval window — how stale is too stale

Marketing tactics decay. A 2009 SEO pattern is dangerous. Every chunk owns `published-at` (from source) and the post-RAG gate weights `retrieval-precision` by recency-fit per topic:

| Topic | Half-life |
|-------|-----------|
| Paid social tactics | 6 cycles |
| SEO tactics | 12 cycles |
| Email tactics | 24 cycles |
| Persona psychology (Cialdini, Schwartz) | ∞ |
| Offer mechanics (Hormozi value equation) | ∞ |
| Specific ad-platform features | 3 cycles |

Chunks past their topic half-life: `retrieval-precision × recency-fit`. Drops fast.

**KPI:** `corpus-recency-fit`. Per-topic. Surfaces stale clusters.

### 5. Holdouts — proof patterns work

Pattern hardening requires holdouts (per marketing-ontology.md §Operational Invariants 5). Without them, pattern `lift-confidence` is capped at 0.5, which means it cannot pass the skill gate (which requires `lift-confidence ≥ 0.90`). **Patterns from un-tested books cannot become skills.** They can inform; they can't ship.

**KPI:** `holdout-tested-pattern-rate`. % of validated patterns whose lift was measured against a holdout. Target > 90%.

---

## Worked example — `Hormozi 100M Offers, Ch. 4 "Value Equation"`

### Source

```
title:        "$100M Offers"
author:       "Alex Hormozi"
medium:       "book"
chapter:      "Ch.4 Value Equation"
chunk-count:  18
published-at: 2021-07-13
source-url:   <obtained legitimately, fair-use excerpt>
```

### Pre-RAG (per-chunk, 18 runs)

Hard gates first (license / safety / length), then weighted dims:

| Chunk | license | safety | length | cred | novelty | tag-cov | claim-d | weighted | decision |
|-------|---------|--------|--------|------|---------|---------|---------|---------:|----------|
| ch4-c01 (intro) | open-fair | clean | sane | 0.95 | 0.62 | 0.33 | 0.5/1k | 0.61 | quarantine |
| ch4-c05 (formula) | open-fair | clean | sane | 0.95 | 0.91 | 0.83 | 4/1k | 0.92 | accept |
| ch4-c08 (likelihood) | open-fair | clean | sane | 0.95 | 0.78 | 0.67 | 3/1k | 0.85 | accept |
| ch4-c12 (dream) | open-fair | clean | sane | 0.95 | 0.88 | 0.83 | 5/1k | 0.93 | accept |
| ch4-c17 (refund risk) | open-fair | flag-0.6 (under 0.7) | sane | 0.95 | 0.55 | 0.67 | 2/1k | 0.74 | accept-with-flag |
| … 13 more | | | | | | | | | |

Result: 16 of 18 accepted, 2 quarantine, 0 hard-rejected. Tags applied: `framework:hormozi`, `awareness:3-4`, `sophistication:3-5`, `lever:value-anchor`, `metric:cvr`, `metric:aov`. Stored at `<slug>/knowledge/hormozi-100m/ch4/<chunk-id>.md` (R2). Each chunk file has frontmatter (tags, license, scores) + body (the chunk text).

### Post-RAG (sampled batch)

After embed + 1 cycle of retrieval traffic, sample 18 chunks (small source — full sample):

| Rubric | Score | Notes |
|--------|-------|-------|
| retrieval-precision | 0.83 | 5/6 canonical queries surface ch4-c05 in top-3 |
| tag-accuracy | 0.92 | judge-agent confirms 17/18 chunks correctly tagged |
| grounding-rate | 0.78 | 14/18 cite-spans match chunk substance |
| pattern-yield | 0.22 | 4 of 18 chunks already in candidate patterns |
| **composite** | **0.81** | **promoted** |

`mark(source: hormozi-100m, 0.81)`.

### Pattern emerges

5 chunks (ch4-c05, c08, c12 + ch5-c02 + ch7-c11) cluster on `framework:hormozi ∧ metric:cvr ∧ persona:smb-founder ∧ lever:value-anchor`. The `researcher` agent produces:

```tql
insert
  $pat isa thing,
    has thing-subtype "pattern",
    has pattern-status "candidate",
    has claim "Stack value-anchors (dream, likelihood, time, effort) before price reveal lifts CVR for SMB founders at awareness 3+",
    has expected-lift 0.0,                   # awaits holdout
    has lift-confidence 0.0,
    has evidence-count 5,
    has persona-fit-tags "persona:smb-founder",
    has cost-estimate 0.05,
    has tag "framework:hormozi", has tag "lever:value-anchor",
    has tag "awareness:3+", has tag "metric:cvr", has tag "persona:smb-founder";
  (supports: $c05, supports: $c08, supports: $c12, supports: $c5_02, supports: $c7_11) isa evidence,
    has evidence-type "case-study";
```

### Holdout tests it — via the `experiment` entity

A `experiment` is inserted (Sean-Ellis style) bound to the candidate pattern by shared tags:

```tql
insert
  $exp isa experiment,
    has xid "exp-q4-value-stack",
    has hypothesis-statement "stacking value before price lifts CVR for SMB founders at awareness 3+",
    has metric-target "cvr",
    has expected-lift 0.30,
    has sample-size-needed 2000,
    has ice-impact 8, has ice-confidence 7, has ice-ease 6,    # ice_score = 3.36
    has experiment-status "running",
    has tag "framework:hormozi", has tag "persona:smb-founder", has tag "metric:cvr";
```

After 2400 observations across 3 campaigns:

```
observed-lift:     0.42
p-value:           0.012
lift_confidence($exp) = 1 − 0.012 = 0.988
experiment_gate($exp) = "ship"   (p ≤ 0.05 ∧ lift > 0)
```

→ `pattern-status` updates from `candidate` to `validated`; pattern's `expected-lift = 0.42`, `lift-confidence = 0.988` (copied from experiment).

### Skill gate

```
pattern_roi($p, persona:smb-founder) = (0.42 × 0.988) / (0.05 + 1.0) = 0.395
roi-rank vs all validated patterns: 96th percentile (top decile ✓)
trigger-test-score (60/40 split): 0.78 ✓
eval pass-rate: 0.81 (baseline 0.62 → +19pp ✓)
safety-regressions: 0 ✓
license-status: fair-use → free skill only (no paid emission allowed) ✓
skill_cut_eligible($p, persona:smb-founder, 0.78, 0.81, 0.62, 0) = true
```

→ skill emits. `cuts-from` relation inserted: `(skill: $sk, pattern: $p) isa cuts-from, has cut-confidence 0.96, has cut-at <now>`.

### Skill artifact

```yaml
---
name: stack-value-before-price
title: Stack value before price
description: Use when writing offer copy, sales pages, or pitches for SMB founders at solution-aware level. Apply when revealing price feels premature, when CVR is below 8%, or when prospects bounce before commitment.
price: 0.0
tags: [framework:hormozi, lever:value-anchor, awareness:3+, persona:smb-founder, metric:cvr]
provenance: [hormozi-100m/ch4/c05, ch4/c08, ch4/c12, ch5/c02, ch7/c11]
license: fair-use
roi-rank: 0.96
lift-confidence: 0.988
---

Before the price, stack four anchors in order: dream outcome, likelihood, time-to-value, effort removed.
Don't reveal the number until the anchors land — order matters more than the words.
Mark on CVR uplift ≥ 25% over baseline in the next holdout-tested send; warn if it holds or drops.
```

The substrate `cuts-from` relation links the new skill to its 5 source chunks. Audit trail intact. Body parses cleanly through `web/src/lib/skill/parser.ts`.

---

## Pipeline KPIs — The Numbers This Doc Owns

Every cycle (post-RAG batch, pattern review, skill emission), the pipeline reports:

| KPI | Definition | Healthy |
|-----|-------------|---------|
| `pre-rag-pass-rate` | accepted / total chunks ingested | 0.40–0.70 (too high = lax; too low = wasting scrape) |
| `pre-rag-quarantine-rate` | quarantine / total | < 0.20 |
| `post-rag-promote-rate` | promoted / sampled | > 0.70 |
| `post-rag-refute-rate` | refuted / sampled | < 0.10 |
| `chunk-pattern-yield` | chunks → at-least-1-pattern within 2 cycles | > 0.05 |
| `pattern-validation-rate` | validated / candidate within 3 cycles | > 0.40 |
| `pattern-refute-rate` | refuted / candidate | < 0.20 (high = bad pattern criteria) |
| `skill-cut-rate` | cut / validated-pattern | > 0.30 |
| `skill-trigger-test-mean` | avg description-optim test-score across emitted skills | > 0.75 |
| `skill-eval-uplift-mean` | avg pass-rate − baseline across emitted skills | > 0.15 |
| `corpus-recency-fit` | per-topic, weighted by traffic | > 0.70 |
| `holdout-tested-pattern-rate` | validated-with-holdout / validated-total | > 0.90 |
| `license-clean-rate` (paid skills) | paid-skills-with-clean-license / paid-skills | 1.00 |

These feed the dashboard, the harden hourly L6 cycle, and the frontier hourly L7 cycle. Drift on any of them is the pipeline talking.

---

## Failure modes — what to watch for

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `pre-rag-pass-rate` > 0.80 | Gate too lax, or scrape source very high quality | Sample 50 quarantine + 50 accept; recalibrate |
| `pre-rag-pass-rate` < 0.30 | Gate too strict, or scrape source garbage | Audit dissolved.log; either fix scrape or relax claim-density floor |
| `post-rag-refute-rate` rising | Embedder mis-tagging | Re-train tag-classifier on recent quarantines |
| `chunk-pattern-yield` < 0.02 | Chunks tagged but not metric-tagged | Strengthen metric-detector; metric:* is load-bearing |
| `pattern-refute-rate` > 0.30 | Holdouts rejecting patterns | Patterns over-fit to source; require ≥ 4 distinct sources before candidate |
| `skill-trigger-test-mean` < 0.65 | Description optimizer underfit | Increase eval set size; rotate adversarial near-miss queries |
| `skill-eval-uplift-mean` < 0.10 | Skills not adding value over baseline | Pattern wasn't real; demote validated → refuted, retract skill |
| `license-clean-rate` < 1.00 | Restricted content slipped into paid skill | Hard-block emit; manual review of license detector |
| `holdout-tested-pattern-rate` < 0.80 | Pipeline shipping pattern→skill without lift evidence | Block skill emit on missing holdout; increase priority of running tests |

Each failure mode has a substrate signal: `mark`/`warn` on the pipeline path. The pipeline learns its own failure shape over time.

---

## How this connects to the 7 loops

| Loop | This doc's role |
|------|-----------------|
| **L1 TOUCH** | Per-retrieval, chunks `mark()` or `warn()` based on outcome. Closed loop. |
| **L2 ATTRIBUTION** | Multi-chunk answers spread weight across cited chunks (per `grounded-in` relation). |
| **L3 FATIGUE** | Chunks fade; resistance accumulates 2× faster on warned chunks. |
| **L4 ECONOMIC** | Skills cut from patterns produce revenue; revenue marks pattern → marks source-chunks. |
| **L5 OPTIMIZATION** | Embedder evolves: re-classify chunks where tag-accuracy drops. |
| **L6 PERSONA** | This doc's pattern-extraction = the L6 hardening for marketing knowledge. |
| **L7 FRONTIER** | Untouched tag combinations → run scrapes for under-covered persona×metric cells. |

The data pipeline is the marketing-substrate's L6+L7 hardening loop, made concrete.

---

## Storage layout (R2)

```
<slug>/
├── knowledge/
│   ├── _credibility.json              # publication-tier registry, hand-maintained
│   ├── _dissolved.log                 # one row per dropped chunk, audit trail
│   ├── _quarantine.json               # chunks awaiting researcher-agent review
│   ├── <source-id>/
│   │   ├── manifest.json              # source metadata: title, author, license, ingested-at, version-hash
│   │   ├── <chunk-id>.md              # frontmatter (tags + scores) + body
│   │   └── ...
│   └── _patterns/
│       ├── <pattern-id>.md            # claim, evidence-chunks, lift, status
│       └── ...
└── skills/
    ├── <emitted-skill>/SKILL.md       # cuts-from links back to _patterns/<id>
    └── ...
```

Same R2 bucket and access pattern as `web/src/lib/skill/import.ts`. Knowledge loader mirrors `web/src/lib/skill/loader.ts`.

---

## Agent ownership — which of the 23 runs each gate

The 23-agent department from marketing-ontology.md owns this pipeline. No new agents.

| Gate / step | Owner agent | KPI it owns |
|-------------|-------------|-------------|
| Scrape + chunk | `researcher` | source-coverage, chunks-per-cycle |
| Pre-RAG hard gates | `compliance` | license-clean-rate, safety-flag-rate |
| Pre-RAG weighted dims | `researcher` | pre-rag-pass-rate |
| Tag-classifier training & drift | `analyst` | tag-accuracy |
| Embed + store | `ops` | bytes-stored, embed-latency |
| Post-RAG sample grading | `analyst` (judge mode) | retrieval-precision, grounding-rate |
| Pattern extraction | `strategist` | pattern-yield, candidate→validated rate |
| Holdout test design | `growth` | lift-confidence, holdout-tested-rate |
| Skill emission (description optim + eval) | `cmo` (approves) + `skill-creator` (executes) | skill-cut-rate, trigger-test-mean |
| Quarantine review | `researcher` | quarantine-clear-time |

Quarantine items (0.50–0.65 pre-RAG, or post-RAG 0.55–0.70) sit in `_quarantine.json` until `researcher` either upgrades the source-credibility entry, fixes a chunk boundary, or dissolves them.

---

## Re-ingestion — when sources update

Every source carries `version-hash` in `manifest.json` (SHA-256 of normalized full text). On scrape:

1. Hash unchanged → skip; mark `last-checked-at`.
2. Hash changed → diff old/new chunks. Unchanged chunks keep their pheromone; new chunks run pre-RAG; removed chunks are tombstoned (kept for audit, marked `superseded-at`, excluded from retrieval).
3. License changed (open → restricted) → all chunks demoted; emitted skills with `cuts-from` to this source go to `pattern-status: refuted` and are pulled.
4. Author retracts a claim → researcher flags chunk; cluster re-runs pattern hardening; if cluster falls below 3 surviving chunks, pattern → `refuted`.

The `version-hash` lives next to the source, not in TypeDB — TypeDB stores the relations, not the bytes.

---

## Anti-patterns

| Don't | Why |
|-------|-----|
| Add an 8th pre-RAG dim | Noise. Three hard gates + four weighted dims is the cap. |
| Run pre-RAG with only LLM classifiers | Cost explodes; static lookups (license URLs, credibility tiers) carry the load |
| Skip post-RAG sampling because pre-RAG was strict | Embedding mis-tagging is invisible at chunk-time; only retrieval surfaces it |
| Write skill bodies as templated tutorials | Real skills are 3 imperative lines (see `web/skills/qualify-lead.md`); templates produce bloat |
| Cut a skill from a candidate (un-hardened) pattern | `lift-confidence < 0.90` means you don't know if it works; shipping caches superstition as code |
| Treat `metric:*` as optional | Without it, no pattern can extract → corpus becomes a parrot |
| Re-embed on every chunk update | Expensive and pheromone-erasing; only re-embed when score < 0.55 |
| Delete refuted sources | Tombstone, don't delete. Audit trail must survive. |
| Run paid-skill eval against the production model by default | Bills compound; default to dry-run (per `agents/skill-creator/SKILL.md`) |

---

## The core loop, repeated

```
SCRAPE ─▶ PRE-RAG  (3 hard gates + 4 weighted dims, ≥ 0.65)  ─▶ EMBED + STORE
                                                                    │
                                                                    ▼
                                                             POST-RAG  (4 dims, ≥ 0.70, sample 100)
                                                                    │
                                                                    ▼
                                                             PATTERN EXTRACT  (≥3 chunks, shared metric)
                                                                    │
                                                                    ▼
                                                             HOLDOUT TEST  (lift-conf ≥ 0.90, n ≥ 30)
                                                                    │
                                                                    ▼
                                                             SKILL GATE  (roi top-decile, trigger ≥ 0.70,
                                                                          eval +10pp, safety 0)
                                                                    │
                                                                    ▼
                                                             SKILL.md emits → pheromone on every invocation
```

Three gates. 3+4 in pre-RAG. 4 in post-RAG. 5 in skill emit. One closed loop on every retrieval. **The corpus earns its size.**

---

## Schema map — every concept to a `marketing-schema.tql` line

Quick reference for implementers: every name in this doc points to either an existing schema declaration, an additive declaration, or a derived function.

| Concept in this doc | Lives in `marketing-schema.tql` |
|---------------------|---------------------------------|
| Knowledge chunk | `entity thing` with `thing-subtype = "knowledge"` (line 133, 213) |
| Pattern | `entity thing` with `thing-subtype = "pattern"`, owns `pattern-status` ∈ {candidate\|validated\|refuted\|retired} |
| Hack | `entity thing` with `thing-subtype = "hack"` |
| Chunk → pattern grounding | `relation evidence, relates supports, relates contradicts` (line 316) |
| Holdout test | `entity experiment` (line 367) — owns `xid`, `metric-target`, `p-value`, `observed-lift`, `experiment-status` |
| ROI scoring | `fun pattern_roi($p, $persona)` (line 689) |
| Recommend by KPI | `fun recommend_strategy($persona, $kpi)` (line 702) |
| Hardening readiness | `fun lift_confidence($exp)` + `fun experiment_gate($exp)` (lines 734, 794) |
| Path tier (chunk fade tier) | `fun marketing_path_status($edge)` (line 774) |
| Persona fit | `fun persona_match($p, $a)` + `fun persona_hardening_status($p)` |
| AI-citation touch (the closed-loop verb) | `relation signal` with `touch-type = "ai-citation"` (line 333), weight 1.5 via `touch_weight()` |
| Tag-spine for chunks/patterns/skills | `attribute tag` on every entity, including `relation path` (line 32, 249) |
| Pre-RAG / post-RAG attributes | **NEW** — additive `owns` on `thing` (this doc) |
| `cuts-from` skill audit | **NEW** relation (this doc) |
| `metric:*` tag namespace | **NEW** namespace; values match `experiment.metric-target` (this doc) |
| `pattern_yield` / `pattern_skill_eligible` | **NEW** functions (this doc) |
| `skill_cut_eligible` | **NEW** function (this doc) |

13 net-new attributes + 1 new relation + 3 new functions + 1 new tag namespace. Everything else is reuse.

---

## Receipt

*Populated on close. Each ingestion batch appends a row. Each emitted skill appends a row.*

| Date | Source | Chunks in / accepted / quarantined / dissolved | Pre-RAG mean | Post-RAG mean | Patterns yielded / hardened | Skills cut |
|------|--------|------------------------------------------------|--------------|---------------|------------------------------|-----------|
| _(empty)_ | | | | | | |

| Date | Pattern | Sources | Personas | Lift / confidence / n | Skill emitted | Skill eval pass-rate |
|------|---------|---------|----------|------------------------|----------------|----------------------|
| _(empty)_ | | | | | | |

---

*Pre-RAG gates the chunk. Post-RAG gates the corpus. Skill gate cuts the artifact. Every step reports a number. Every accept compounds. Every reject leaves a trace. The library doesn't grow — it earns.*
