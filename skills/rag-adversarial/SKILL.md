---
name: rag-adversarial
description: Pattern 12 of the RAG query library - query the RAG twice with opposing framings (the case FOR and the case AGAINST), retrieve evidence for each side, then weigh them into a balanced verdict that names what the strongest counter-argument is. Kills confirmation bias in RAG-backed decisions. Triggers when Donal says "steelman both sides", "should we / should we not", "devil's advocate this", or before a contestable go/no-go call.
model: claude-sonnet-4-6
source: oo-internal
---

# Skill: /rag-adversarial - Two-Sided Evidence Weighing

**Purpose:** Defeat confirmation bias in RAG lookups. A single "why should we X" query retrieves only pro-X chunks. This fires BOTH framings (for and against), retrieves evidence for each, and weighs them - surfacing the strongest counter-argument the corpus holds. Pattern 12 of `docs/rag-query-pattern-library.md`.
**Output:** A balanced verdict: case FOR (cited) → case AGAINST (cited) → strongest counter → verdict + confidence. To `--out` (default `/tmp/adversarial-<slug>.md`).
**Time to run:** 2-4 min.
**Cost:** Tier 1 in-chat $0. Scripted ~$0.50 (2-4 searches + Sonnet weigh). Hard-cap $2.

---

## HARD RULES

- **Closed-loop non-negotiable.** Each framing query (and any per-side fan-out) gets its own `mark_retrieval`.
- **Genuinely opposing framings.** The two queries must be real opposites ("why X is right" / "why X is wrong"), not cosmetic rewordings. The whole value is retrieving evidence the affirmative query would never surface.
- **Steelman both sides.** Present the STRONGEST version of each side from the corpus, not a strawman of the side you suspect is weaker. If one side has no corpus support, say "the corpus offers no evidence against" - that itself is a finding.
- **Name the strongest counter explicitly.** The verdict must state the single best argument against its own conclusion. A verdict that hides its weakest point is bias, not analysis.
- **Verdict ≠ decision.** Output a reasoned verdict + confidence; the go/no-go is Donal's. For client/money/strategy calls, frame as input.
- **W1-W4:** W1 (build the two framings) Haiku · W3 (retrieve both + weigh) Sonnet · W4 (close loop) Haiku.

## When to use
- Contestable go/no-go: "should we take this client" / "should we add this offer" / "is this pricing right"
- Pre-decision bias check on something you already lean toward (most valuable here - it surfaces what you're discounting)
- Stress-testing a plan's assumption before committing
- When `/rag-deep-question` or a strategy doc reaches a binary fork

**Not for:** open-ended research (`/rag-fanout`); questions with no real "against" side (factual lookups); persona/values questions (`/persona-council`).

## Input
**Required:** `<proposition>` - the contestable claim/decision (e.g. "OO should take on the tax-prep niche").
**Optional:**
- `--vault <name>` (auto-routes; override)
- `--k <N>` chunks per side (default 5)
- `--fanout` run a small `/rag-fanout` per side instead of one query each (deeper, pricier)
- `--out <path>`
- `--dry-run` show the two framings without firing

## Process

### Step 1 (W1, Haiku): Build opposing framings
From the proposition, write:
- `for_q` = the affirmative case search ("reasons / evidence supporting <proposition>")
- `against_q` = the negative case search ("risks / reasons against / failure modes of <proposition>")
Confirm they're genuine opposites. If `--dry-run`: print both + vault + exit.

### Step 2 (W3): Retrieve both sides
- `search_notes(for_q, k, vault)` → pro chunks
- `search_notes(against_q, k, vault)` → con chunks
- If `--fanout`: run `/rag-fanout` per side with --max-subqueries 3 instead.

### Step 3 (W3, Sonnet): Weigh
```markdown
# Adversarial: "<proposition>" (<date>)
## Case FOR (steelmanned)
- <strongest pro> [source: <file>, "<excerpt>"]
## Case AGAINST (steelmanned)
- <strongest con> [source: <file>, "<excerpt>"]
## Strongest single counter-argument
<the one thing most likely to make the verdict wrong>
## Verdict: <lean for | lean against | genuinely balanced> — confidence <high|med|low>
<reasoning weighing both>
## Your call (Donal)
<what to decide + what evidence would flip it>
```

### Step 4 (W4, Haiku): Close the loop
`mark_retrieval` for each side's query (and fan-out sub-queries if `--fanout`).

### Step 5: Emit
Write `--out`. Print: `ADVERSARIAL: <proposition> | verdict <lean> conf <level> | for <n>/against <m> chunks | closed-loop <k>/<k>.`

## Quality Checks
- [ ] Framings are genuine opposites (not reworded)
- [ ] Both sides steelmanned from the corpus
- [ ] "Strongest single counter-argument" section present
- [ ] Verdict has a confidence level + "what would flip it"
- [ ] One mark_retrieval per search_notes
- [ ] If a side has no corpus support, said plainly

## Escalation rules
Escalate to Donal if: the AGAINST side is materially stronger than the lean Donal expressed (the bias-check fired - surface it clearly); evidence is thin on BOTH sides (decision is being made on vibes, not corpus - flag it); the proposition touches client/money/legal where a wrong call is costly (verdict is input only, recommend real diligence).

## Cost note (Rule 15)
2 searches + Sonnet weigh ≈ $0.50; `--fanout` mode ≈ $1.50. Hard-cap $2. Tier 1 in-chat $0.

## Composition
`composes_with_sesh: false`. Single-shot verdict.

## Cross-references

- Cost levers (sub-token / API): `docs/rag-cost-optimization.md` (Haiku cache floor ~4k empirical; dedup sub-queries + chunks; OpenAI-embedding vs Anthropic-synthesis surfaces)
- Pattern source: `docs/rag-query-pattern-library.md` (Pattern 12)
- Sibling: `/rag-deep-question` (multi-dimension), `/rag-fanout` (used per side in `--fanout` mode)
- Rules: 08, 15; Sub-plan 15

## Pickup Prompt
```
/rag-adversarial "OO should take on the tax-prep niche"
/rag-adversarial "<proposition>" --fanout --out /tmp/adversarial.md
/rag-adversarial "<proposition>" --dry-run
```
