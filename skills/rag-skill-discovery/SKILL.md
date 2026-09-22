---
name: rag-skill-discovery
description: Pattern 6 of the RAG query library - run a batch of "what skill should I use for X" test queries against the agency-operator vault, score whether a clearly-matching skill description comes back, and emit a skill-coverage report. Weak/zero hits = skill gaps. Triggers when Donal says "what skills are we missing", "run skill discovery", "skill coverage report", or on the weekly cron (Phase 3).
model: claude-sonnet-4-6
source: oo-internal
---

# Skill: /rag-skill-discovery - RAG-Driven Skill Gap Finder

**Purpose:** Probe the skill library THROUGH the RAG. For each common "what do I do when X" ask, search the agency-operator vault; if the top hits aren't a clearly-matching skill, that's a gap. Turns the RAG into a coverage auditor. Pattern 6 of `docs/rag-query-pattern-library.md`.
**Output:** `deliverables/_internal/skill-overhaul-2026-05-28/skill-coverage-<date>.md` - per-query coverage verdict + ranked gap list feeding sub-plan 01 / 12 / `/skill-gap-finder`.
**Time to run:** 3-6 min for the default 30-query set.
**Cost:** Tier 1 in-chat $0. Scripted ~$2/run (30 searches + Sonnet grading). Hard-cap $5.

---

## HARD RULES

- **Closed-loop non-negotiable.** Each test query fires one `search_notes` + one `mark_retrieval`. 30 queries = 30 marks. No orphans.
- **Skills are OUT of RAG scope by design.** Per CLAUDE.md Phase 11, `.claude/skills/**` is NOT indexed. So this skill matches against skill DESCRIPTIONS via the live skill list (read `.claude/skills/*.md` frontmatter `description:` fields), NOT via search_notes on skill bodies. search_notes probes whether KNOWLEDGE/SOPs exist; the skill-name match is a separate file-read step. Do not expect search_notes to return skill files.
- **A gap = no clearly-matching skill description AND weak knowledge hits.** If a skill exists but its description doesn't match the ask, that's a DESCRIPTION gap (routing problem), logged separately from a CAPABILITY gap (no skill at all).
- **Never invent a skill that exists.** Before flagging a CAPABILITY gap, grep the live skill list - the gap is real only if no skill's description covers the ask.
- **W1-W4:** W1 (load query set + skill descriptions) Haiku · W2/W3 (grade coverage) Sonnet · W4 (close loop) Haiku.

## When to use
- Weekly skill-coverage heartbeat (Phase 3 cron)
- After a niche/ICP expansion ("we now take tax-prep clients - are we covered?")
- Pre-quarterly-review skill audit
- When `/rag-fanout` or `/rag-triangulate` surfaces a [BUILD] gap and you want to confirm it against the full query set

**Not for:** answering a real question (this probes coverage, not content); single-skill lookup.

## Input
**Optional:**
- `--query-set <path>` custom query file (one ask per line). Default: the built-in 30-ask set below.
- `--niche <slug>` inject niche-specific asks from `knowledge/niches/<slug>.md`
- `--out <path>` report destination
- `--threshold <0-1>` match-confidence below which an ask is flagged (default 0.5)

## Default query set (30 common Donal asks - extend over time)
Mover prospect · dentist niche · roofer niche · tax-prep niche (likely gap) · Hostinger→CF cutover · diagnostic snapshot dental · AI visibility audit cold prospect · warm lead closing package · monthly retainer report · client churn save · reprice conversation · cold email sequence · LinkedIn outreach · sales deck post-discovery · pre-call brief · DNS zone snapshot · form spam fix · schema deploy · GMB optimization · review-generation campaign · backlink audit · competitor SERP analysis · i18n/multilingual audit · ads account audit · landing page CRO · VSL video outreach · enterprise/RFP plan · strat hub for tier-1 lead · R&D idea capture · plan health check.

## Process

### Step 1 (W1, Haiku): Load
- Read the query set (default 30 or `--query-set`).
- Read live skill descriptions: `grep -h "^description:" .claude/skills/*.md .claude/skills/*/SKILL.md`.

### Step 2 (W3): Probe each ask
For each ask:
1. `mcp__search_notes(query="<ask> SOP process steps", k=5, vault="agency-operator")` - tests whether KNOWLEDGE backs the ask.
2. Match the ask against the loaded skill descriptions (keyword + intent). Record best-match skill + confidence.

### Step 3 (W2/W3, Sonnet): Grade coverage
Per ask, assign a verdict:
- **COVERED** - a skill description clearly matches AND/OR strong knowledge hits.
- **DESCRIPTION-GAP** - a capable skill exists but its `description:` wouldn't route this ask (fix the description).
- **CAPABILITY-GAP** - no matching skill AND weak/zero knowledge hits → BUILD candidate.

```markdown
# Skill Coverage Report - <date>
## Summary: <COVERED>/<DESC-GAP>/<CAP-GAP> of <N> asks
## Per-ask
| Ask | Best-match skill | Conf | Knowledge hits | Verdict |
|---|---|---|---|---|
## Capability gaps (BUILD candidates, ranked by ask-frequency)
## Description gaps (cheap fixes - reword the skill `description:`)
```

### Step 4 (W4, Haiku): Close the loop
`mark_retrieval` per probe: `mark` if knowledge hits informed the verdict, `warn` if zero/irrelevant, `unsure` if ambiguous.

### Step 5: Emit + route
Write report to `--out` (default `deliverables/_internal/skill-overhaul-2026-05-28/skill-coverage-<date>.md`). Print summary. Append CAPABILITY-GAPs to sub-plan 12 gap catalog + flag to `/skill-gap-finder`.

## Quality Checks
- [ ] One mark_retrieval per search_notes
- [ ] Every CAPABILITY-GAP verified against the live skill list (not a skill that already exists)
- [ ] DESCRIPTION-GAPs separated from CAPABILITY-GAPs
- [ ] Gaps ranked by ask-frequency / business value
- [ ] Report written + summary printed

## Escalation rules
Escalate to Donal if: >30% of asks are CAPABILITY-GAPs (library has a real hole or query set is mis-calibrated); a high-frequency ask (mover/dentist/roofer - core niches) is a gap; DESCRIPTION-GAPs cluster (the routing layer needs a sweep, not point fixes).

## Cost note (Rule 15)
30 searches × k=5 + Sonnet grading ≈ $2. Hard-cap $5. Weekly cron ~$8/mo. Tier 1 in-chat $0.

## Composition
`composes_with_sesh: false`. Produces a report, not a sprint. A confirmed cluster of gaps may spawn `/sesh new skill-gap-fill-<date>`.

## Cross-references

- Cost levers (sub-token / API): `docs/rag-cost-optimization.md` (Haiku cache floor ~4k empirical; dedup sub-queries + chunks; OpenAI-embedding vs Anthropic-synthesis surfaces)
- Pattern source: `docs/rag-query-pattern-library.md` (Pattern 6)
- Consumes gaps from: `/rag-fanout`, `/rag-triangulate`
- Feeds: sub-plan 01 (discovery wave), sub-plan 12 (gap catalog), `/skill-gap-finder`
- Niche data: `knowledge/niches/<slug>.md`
- Rules: 08, 15; Sub-plan 15
- Phase 3 cron: this skill is the weekly-run target.

## Pickup Prompt
```
/rag-skill-discovery
/rag-skill-discovery --niche movers
/rag-skill-discovery --query-set /tmp/my-asks.txt --out /tmp/coverage.md
```
