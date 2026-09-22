---
name: rag-fanout
description: Pattern 2 of the RAG query library - decompose one broad question into 5-10 sub-queries, run search_notes for each in parallel across the chosen vault, synthesize across 15-30 chunks into a structured answer with per-chunk citations. Each sub-query fires its own mark_retrieval close-loop. Triggers when Donal asks a broad RAG question, says "fanout this", "fan out", "search RAG with multiple angles", or when /rag-deep-question delegates.
model: claude-sonnet-4-6
source: oo-internal
---

# Skill: /rag-fanout - Multi-Query RAG Fan-Out

**Purpose:** Convert one broad question into N targeted sub-queries, run them in parallel, synthesize the chunks into a cited answer. Pattern 2 of the RAG query library (`docs/rag-query-pattern-library.md`).
**Output:** Markdown answer with per-claim citations + per-sub-query `mark_retrieval` calls completing the closed-loop contract
**Time to run:** 2-4 min depending on N sub-queries
**Cost:** Tier 1 (Max sub, $0 Anthropic) if invoked in-chat. Hard-cap if scripted: ~$2 per invocation at N=6, k=3.

---

## HARD RULES

- **Closed-loop is non-negotiable.** Every `search_notes` call MUST be followed by `mark_retrieval(query_id, outcome)` before the skill returns. Skipping pollutes the `retrieval_outcomes` table. Outcomes: `mark` (chunks helped) / `warn` (didn't help) / `unsure` (couldn't tell).
- **Default vault per question.** Operational questions → `agency-operator`. Frameworks / courses / intel → `oo-brain`. Personal → `personal-brain`. Cross-cutting → `vault=null`. Skill auto-routes per question keywords; operator can override with `--vault`.
- **Sub-query cap = 10.** Above that, the synthesis loses coherence and cost climbs. Operator gets `--max-subqueries` flag but skill refuses N>15.
- **Dedup for cost (sub-token discipline, per `docs/rag-cost-optimization.md`).** (a) Before firing, drop near-duplicate sub-queries (same core terms) - saves OpenAI embeddings AND the duplicate chunks they'd return. (b) Before synthesis, dedup chunks by id / file+offset - fan-out's N×k returns overlap; ~18 raw → ~10-12 unique = ~35% fewer synthesis input-tokens for free. Cheapest win available; do it every run.
- **W1-W4 routing per `feedback_w1_w4_sandwich_default_for_multi_step_builds`:** W1 (decompose) = Haiku. W2 (judge sub-queries) = Sonnet. W3 (synthesize) = Sonnet. W4 (verify citations) = Haiku.
- **Citation traceability mandatory.** Every claim in the synthesis cites at least one source chunk by file path + chunk excerpt. No claim without source = hallucination risk.

---

## When to use

- Broad research questions: "How should we price the chatbot pilot?" / "What's the OO strategy for AI ranking 2026?" / "What patterns do we have for Hostinger cutovers?"
- Pre-call prep where one angle isn't enough
- Cross-topic synthesis (e.g. "what's our position on chatbot + ads + AI ranking combined")
- When Pattern 1 (single query) returns weak hits and you want to widen the net

**Not for:** narrow factual lookups (Pattern 1 is faster); time-sensitive recall tests (Pattern 7); persona-driven questions (Pattern 10 / `/persona-council`); adversarial framing (Pattern 12 / `/rag-adversarial`).

---

## Input

**Required:**
- `<question>` - natural-language broad question (positional arg or stdin)

**Optional:**
- `--vault <name>` - override auto-routing (oo-brain | agency-operator | personal-brain | null for cross-vault)
- `--max-subqueries <N>` - cap on sub-query count (default 6, max 10)
- `--k <N>` - chunks per sub-query (default 3, max 5)
- `--out <path>` - write synthesis to file instead of stdout
- `--dry-run` - emit the sub-query list without firing search_notes (preview the decomposition)
- `--no-mark` - skip mark_retrieval (DANGEROUS - violates closed-loop contract; only for debugging)

---

## Process

### Step 1 (W1, Haiku): Decompose the question

Read the question. Identify:
- The CORE concept (one phrase capturing the question's essence)
- 4-8 ANGLES that illuminate the question (different facets: pricing / competitive / historical / framework / niche / risk / etc.)

Generate sub-queries. Each sub-query is a focused search string (NOT a question - search_notes does keyword + vector search, not Q&A).

Example for "How should we price the chatbot pilot?":
- Core: "chatbot pilot pricing"
- Angles:
  - "chatbot pilot pricing tiers"
  - "BOQ pilot 1 spec pricing"
  - "Hormozi value-based pricing chatbot"
  - "Tony McKinsey chatbot economics"
  - "competitor chatbot retainer pricing 2026"
  - "OO retainer chatbot upsell pricing history"

**Acceptance check:** sub-query count between 4 and `--max-subqueries`. Each sub-query is concrete (not "things related to X" generic).

### Step 2 (--dry-run exit): Preview decomposition

If `--dry-run`: print the sub-query list + chosen vault + estimated cost. Exit. No search_notes calls.

### Step 3 (W2, Sonnet): Vault routing

Determine vault per question keywords:

| Question signal | Vault |
|---|---|
| "OO clients" / "retainer" / "Tomas" / "John" / specific skill / SOP | agency-operator |
| "course" / "Hormozi" / "Tony" / "framework" / "intel" / scraped content | oo-brain |
| Personal (health / lifestyle / cycle / persona) | personal-brain |
| Cross-cutting OR uncertain | null (search all vaults) |

If `--vault` flag passed: skip auto-routing, use the explicit vault.

### Step 4 (W3, Sonnet → Haiku fan-out): Run sub-queries in parallel

For each sub-query:
1. Call `mcp__search_notes(query=sub_query, k=<k>, vault=<vault>)`
2. Capture: `query_id`, top-k chunks (each: file_path, chunk_excerpt, score)
3. Track in working set

**Acceptance check:** every sub-query returned at least 1 chunk OR was tracked as zero-hit (zero-hit is meaningful signal for skill-discovery).

### Step 5 (W3, Sonnet): Synthesize across chunks

Aggregate all chunks (typically 15-30 chunks for N=6, k=3-5). Synthesize into a structured answer:

```markdown
# <question> - Fan-out Synthesis

## TL;DR
<2-3 sentence answer to the question>

## Per-angle findings

### <angle 1>
- <fact / framework / data point> [source: <file_path>, "<chunk excerpt>"]
- <fact / framework / data point> [source: <file_path>, "<chunk excerpt>"]

### <angle 2>
[same shape]

## Cross-angle synthesis
<what emerges when angles combine - the real answer to the broad question>

## Gaps surfaced (potential skill candidates)
<sub-queries that returned zero or weak hits = skill gaps - feed to /rag-skill-discovery>

## Sub-queries fired (with mark status)
| Sub-query | Vault | k | Chunks | Status |
|---|---|---|---|---|
| <q1> | <v> | <k> | <count> | mark/warn/unsure |
```

**Acceptance check:** every claim in TL;DR + Per-angle findings has at least one citation. Cross-angle synthesis cites at least 3 distinct files.

### Step 6 (W4, Haiku): Close the loop

For each sub-query in the working set, call `mcp__mark_retrieval(query_id, outcome, notes)`:
- `mark` if at least 1 chunk made it into the synthesis
- `warn` if 0 chunks were useful (low score AND no fit to synthesis)
- `unsure` if chunks returned but couldn't be classified

If `--no-mark` flag: SKIP this step + emit a loud warning to stdout. Default behavior: mark all.

**Acceptance check:** mark_retrieval count == search_notes count. No orphan queries.

### Step 7: Emit + log

If `--out <path>`: write synthesis to file.
Otherwise: print to stdout.

Always print summary:
```
RAG FAN-OUT: <N> sub-queries fired, <M> useful chunks, <K> gaps surfaced.
Synthesis: <path or "stdout">
Closed-loop: <N>/<N> marked (mark=<x> warn=<y> unsure=<z>).
```

---

## Quality Checks

Before marking done:

- [ ] Sub-query count 4-10
- [ ] Every search_notes had a paired mark_retrieval (unless --no-mark)
- [ ] Every claim in TL;DR + Per-angle has a citation
- [ ] Cross-angle synthesis cites at least 3 distinct files
- [ ] Zero-hit sub-queries flagged in "Gaps surfaced" section
- [ ] Vault auto-routing matches question signals (or --vault used)
- [ ] Summary printed to stdout

---

## Escalation rules

Escalate to Donal if:
- All sub-queries return zero hits (RAG quality issue OR vault choice wrong - try `--vault=null`)
- 50%+ sub-queries returned chunks but synthesis couldn't be cited (hallucination risk)
- Cost exceeds estimated cap (rate-limit or k=5 expansion)
- Cross-vault routing returns contradictions (e.g. agency-operator says X, oo-brain says NOT-X)
- Question is genuinely a Pattern 9 (decomposition agent) candidate - hand off to `/rag-deep-question` when that skill ships

---

## Cost note (per Rule 15)

- N=6 sub-queries × k=3 chunks each = ~18 chunks input to synthesis
- W1 decompose: Haiku, ~$0.05
- W3 synthesize: Sonnet, ~$0.30 for 18 chunks + Q + structure
- Total typical: ~$0.40 per invocation
- Hard-cap recommended: $2 (allows for N=10, k=5 if needed)
- Tier 1 in-chat: $0 (Max sub absorbs)

If invoked at batch / script time: pass `--hard-cap-usd 2` to the wrapping script.

---

## Composition

`composes_with_sesh: false`. /rag-fanout is a single-shot synthesis, not a multi-day sprint. Results live in stdout or `--out <path>`; sprint folder not needed.

If a particular fan-out reveals a multi-day investigation worth pursuing, operator runs `/sesh new <slug>` separately and references the fan-out output as input.

---

## Live test (post-ship)

Recommended first invocation (Pattern 6 cross-check):

```
/rag-fanout "what skills do we have for handling Hostinger to CF Pages cutovers"
```

Expected: 6 sub-queries fire, agency-operator vault auto-routes, synthesis surfaces /hosting-cutover + /cf-zone-runbook-generate + /mail-provider-preservation-table + /prelaunch-checklist + /form-spam-fix as the existing skill cluster. Any gaps surfaced = skill-discovery signal.

---

## Cross-references

- Cost levers (sub-token / API): `docs/rag-cost-optimization.md` (Haiku cache floor ~4k empirical; dedup sub-queries + chunks; OpenAI-embedding vs Anthropic-synthesis surfaces)

- Pattern source: `agency-operator/docs/rag-query-pattern-library.md` (Pattern 2)
- MCP tool spec: `agency-operator/docs/oo-brain-rag.md`
- Closed-loop contract: CLAUDE.md "OO-Brain MCP - Closed-Loop Retrieval Contract"
- Sibling skills (to be shipped): /rag-triangulate / /rag-skill-discovery / /rag-synthesize / /rag-deep-question / /rag-canary / /rag-adversarial / /persona-council
- Memory rules: `feedback_w1_w4_sandwich_default_for_multi_step_builds`, `feedback_dry_trigger_for_new_skills`
- Rule 08 (model routing - W1-W4 enforcement)
- Rule 15 (cost discipline - hard-cap)
- Sub-plan: `Plans/2026-05-28/big-skill-overhaul/15-rag-query-pattern-library.md`

---

## Pickup Prompt

```
/rag-fanout "<broad question>"
/rag-fanout "<broad question>" --vault=oo-brain --max-subqueries=8 --k=5
/rag-fanout "<question>" --dry-run    # preview the decomposition
/rag-fanout "<question>" --out /tmp/synthesis-<topic>.md
```
