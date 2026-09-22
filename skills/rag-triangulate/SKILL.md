---
name: rag-triangulate
description: Pattern 3 of the RAG query library - run the SAME question against all 3 vaults (oo-brain / agency-operator / personal-brain) plus a cross-vault pass, then compare what each surfaces. A vault that hits where another is silent = a knowledge/SOP/skill gap. Triggers when Donal says "triangulate this", "check all vaults for", "do we have an SOP for X", or when a single-vault search returns weak hits and the gap is unclear.
model: claude-sonnet-4-6
source: oo-internal
---

# Skill: /rag-triangulate - Cross-Vault Triangulation

**Purpose:** Ask one question of every vault and compare coverage. The output is both an answer AND a gap signal: if `oo-brain` (intel/courses) knows something `agency-operator` (our SOPs/skills) doesn't, that delta is a skill/SOP we should build. Pattern 3 of `docs/rag-query-pattern-library.md`.
**Output:** A 3-column coverage comparison + synthesized answer + explicit gap list, with per-vault `mark_retrieval` closing the loop.
**Time to run:** 1-3 min.
**Cost:** Tier 1 (in-chat, $0). Scripted: ~$0.50 (4 searches + Sonnet compare). Hard-cap $2.

---

## HARD RULES

- **Closed-loop non-negotiable.** Each of the (up to 4) `search_notes` calls gets its own `mark_retrieval(query_id, outcome)` before the skill returns. No orphan queries.
- **Same query string to every vault.** The whole point is a controlled comparison - do NOT re-word the query per vault. Vary the vault, hold the query constant.
- **personal-brain may be empty.** It currently holds 0 chunks. A zero-hit there is expected, not a gap - note it as "vault unpopulated" not "knowledge gap".
- **A gap is directional.** "oo-brain hits, agency-operator silent" = we have the intel but no operational asset = BUILD candidate. "agency-operator hits, oo-brain silent" = our SOP isn't backed by external intel = fine, or a research candidate. Always state the direction.
- **W1-W4 routing:** W1 (frame query) Haiku · W2/W3 (compare + synthesize) Sonnet · W4 (close loop) Haiku.

---

## When to use

- "Do we actually have an SOP / skill for <X>, or just intel about it?"
- A single-vault search returned weak hits and you can't tell if it's a query problem or a real gap
- Pre-build gap check before authoring a new skill (confirms the gap is real, not just mis-queried)
- Reconciling "the course says X" against "what our SOPs actually do"

**Not for:** broad multi-angle research (use `/rag-fanout`); narrow factual lookup (Pattern 1 single query); persona questions (`/persona-council`).

## Input

**Required:** `<question>` - the single query string to triangulate.
**Optional:**
- `--k <N>` chunks per vault (default 5, max 8)
- `--vaults <list>` override the default 3 (e.g. `oo-brain,agency-operator`)
- `--out <path>` write report to file
- `--dry-run` print the plan (query + vaults) without firing

## Process

### Step 1 (W1, Haiku): Lock the query
Take the question verbatim as the search string (lightly normalize to keywords if it's a long sentence - search_notes is hybrid vector+BM25, not Q&A). Confirm it's the SAME string for all vaults.

### Step 2 (W3): Fire one search per vault
For each vault in {oo-brain, agency-operator, personal-brain (skip if known-empty unless `--vaults` forces it), null/cross-vault}:
1. `mcp__search_notes(query=<q>, k=<k>, vault=<vault>)`
2. Capture query_id + top-k chunks (file_path, excerpt, score).

**Acceptance:** one query_id per vault attempted; zero-hits recorded explicitly.

### Step 3 (W2/W3, Sonnet): Compare + synthesize
Build the comparison:

```markdown
# Triangulation: "<question>"

## Coverage by vault
| Vault | Top hit (file) | Score | Verdict |
|---|---|---|---|
| oo-brain | <file> | <score> | strong / weak / silent |
| agency-operator | <file> | <score> | strong / weak / silent |
| personal-brain | - | - | unpopulated |
| cross-vault | <file> | <score> | strong / weak / silent |

## Synthesized answer
<the answer, citing which vault each claim came from>

## Gaps surfaced (directional)
- [BUILD] oo-brain has <X> but agency-operator is silent → candidate skill/SOP: <name>
- [RESEARCH] agency-operator has <Y> but no external backing in oo-brain
- [OK] both cover <Z>
```

**Acceptance:** every claim cites its source vault + file; every gap states direction + a candidate action.

### Step 4 (W4, Haiku): Close the loop
`mark_retrieval` per vault query: `mark` if a chunk fed the synthesis, `warn` if hits were useless, `unsure` if ambiguous. personal-brain zero-hit on an empty vault = `unsure` with note "vault unpopulated".

**Acceptance:** mark_retrieval count == search_notes count.

### Step 5: Emit
`--out` writes to file else stdout. Always print:
```
TRIANGULATE: <q> | vaults hit: <list> | gaps: <n> BUILD / <n> RESEARCH | closed-loop <m>/<m>.
```

## Quality Checks
- [ ] Same query string used for every vault
- [ ] One mark_retrieval per search_notes
- [ ] Each claim cites source vault + file
- [ ] Gaps are directional (BUILD vs RESEARCH vs OK) with a candidate action
- [ ] Empty-vault zero-hits labelled "unpopulated" not "gap"

## Escalation rules
Escalate to Donal if: vaults return CONTRADICTORY answers (oo-brain says X, agency-operator says not-X) - flag the contradiction, don't auto-resolve; all vaults silent (query or RAG-quality problem - try `/rag-fanout` to widen); a [BUILD] gap looks high-value (feed to `/rag-skill-discovery` + sub-plan 12 catalog).

## Cost note (Rule 15)
4 searches × k=5 + one Sonnet compare ≈ $0.50. Hard-cap $2. Tier 1 in-chat = $0.

## Composition
`composes_with_sesh: false`. Single-shot comparison. If a [BUILD] gap warrants a real build, run `/sesh new <slug>` separately.

## Cross-references

- Cost levers (sub-token / API): `docs/rag-cost-optimization.md` (Haiku cache floor ~4k empirical; dedup sub-queries + chunks; OpenAI-embedding vs Anthropic-synthesis surfaces)
- Pattern source: `docs/rag-query-pattern-library.md` (Pattern 3)
- Closed-loop: CLAUDE.md "OO-Brain MCP - Closed-Loop Retrieval Contract"
- Sibling: `/rag-fanout` (Pattern 2), `/rag-skill-discovery` (Pattern 6 - consumes the gaps this surfaces)
- Rules: 08 (routing), 15 (cost)
- Sub-plan: `Plans/2026-05-28/big-skill-overhaul/15-rag-query-pattern-library.md`

## Pickup Prompt
```
/rag-triangulate "do we have an SOP for Hostinger to CF Pages cutover"
/rag-triangulate "<question>" --k 8 --out /tmp/triangulate-<topic>.md
/rag-triangulate "<question>" --dry-run
```
