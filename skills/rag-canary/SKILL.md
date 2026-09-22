---
name: rag-canary
description: Pattern 7 of the RAG query library - a recall canary. Run a fixed set of known-answer queries and assert the expected source file/chunk comes back in the top-k. If recall degrades (embedding drift, bad sync, data loss), it fails loud and halts downstream RAG work. Triggers when Donal says "rag canary", "is the RAG healthy", "recall test", or on the daily/pre-sprint cron.
model: claude-haiku-4-5-20251001
source: oo-internal
---

# Skill: /rag-canary - RAG Recall Health Check

**Purpose:** Cheap, deterministic confidence that the RAG still retrieves what it should. A set of known-answer queries each expect a specific source file in the top-k. Pass = RAG healthy. Fail = embedding drift / broken sync / data loss → halt downstream RAG-dependent work. Pattern 7 of `docs/rag-query-pattern-library.md`.
**Output:** `deliverables/_internal/skill-overhaul-2026-05-28/rag-canary-<date>.md` (PASS/FAIL per probe + overall verdict). Cron-safe.
**Time to run:** <1 min for the default ~12-probe set.
**Cost:** ~$0.10/run (searches only, no synthesis). Daily cron OK. Hard-cap $1.

---

## HARD RULES

- **Closed-loop non-negotiable.** Each canary probe = one `search_notes` + one `mark_retrieval`. Outcome `mark` if expected file in top-k, `warn` if not (a recall miss).
- **Deterministic assertion.** A probe PASSES iff the expected `file_path` (or chunk excerpt substring) appears in the top-k results. No fuzzy judgment - it's a regression gate, not an opinion.
- **Fail loud, halt downstream.** If overall pass-rate < the threshold (default 90%), emit a LOUD failure and recommend halting any RAG-dependent skill (`/rag-fanout`, `/rag-synthesize`, audits that cite RAG) until investigated. Do not silently proceed.
- **The canary set is version-controlled.** Probes live in `knowledge/rag/canary-set.yaml` (created on first run if absent). Each entry: `query`, `vault`, `expect_file` (or `expect_excerpt`), `k`. Adding/removing probes is a deliberate, reviewed change.
- **No API model call needed.** Pure retrieval + string assertion → Haiku/deterministic. Rule 15 cost is near-zero; still close the loop.

## When to use
- Daily / pre-sprint RAG health heartbeat (cron)
- Before any large RAG-dependent run (a 30-query `/rag-skill-discovery`, an audit that cites RAG)
- After a vault sync, re-embed, or schema change - confirm recall survived
- When a chat reports "the RAG isn't finding obvious things" - canary confirms drift vs query problem

**Not for:** answering questions; coverage auditing (that's `/rag-skill-discovery`).

## Input
**Optional:**
- `--set <path>` canary set (default `knowledge/rag/canary-set.yaml`)
- `--threshold <0-1>` min pass-rate before FAIL (default 0.90)
- `--out <path>` report destination
- `--add "<query>|<vault>|<expect_file>|<k>"` append a new probe to the set (then exit)

## Default canary set (seed - 12 probes, extend in canary-set.yaml)
Each is a known-answer fact whose source file is stable:
1. "OO retainer pricing baseline" → `knowledge/agency/revenue-model.md` (oo-brain or agency-operator)
2. "Cloudflare Pages 100 project cap" → `.claude/rules/14-cf-pages-economy.md`
3. "no auto-send client email rule" → `.claude/rules/12-no-auto-email.md`
4. "em dash ban client-facing" → `.claude/rules/06-output-style.md`
5. "competitor filtering blocklist Yelp BBB" → `.claude/rules/09-competitor-filtering.md`
6. "AI ranking GEO delivery SOP" → `sops/ai-ranking/`
7. "mover niche KPIs competitors" → `knowledge/niches/movers.md`
8. "form pipeline CF Worker Resend default" → `.claude/rules/16-form-pipeline-default.md`
9. "model routing Sonnet decides Haiku processes" → `.claude/rules/08-model-routing.md`
10. "Anthropic API cost preflight rule" → `.claude/rules/15-anthropic-api-cost.md`
11. "client data source of truth profile.md" → `.claude/rules/02-client-data.md`
12. "audit coverage gate Kiba Zucity" → `.claude/rules/18-audit-coverage-gate.md`

(All in agency-operator vault. On first run, write these to `knowledge/rag/canary-set.yaml`.)

## Process

### Step 1: Load (or seed) the canary set
If `knowledge/rag/canary-set.yaml` absent, write the 12 seed probes above. Else read it. Honor `--add`.

### Step 2: Run each probe
For each: `mcp__search_notes(query, k, vault)`. Record whether `expect_file` (or `expect_excerpt`) is in the top-k. PASS/FAIL per probe.

### Step 3: Verdict
```markdown
# RAG Canary - <date>
## Overall: <pass_count>/<total> = <pct>% — PASS | FAIL (threshold <t>%)
| # | Query | Vault | Expected | Found@rank | Verdict |
|---|---|---|---|---|---|
## On FAIL
HALT recommendation: do not run RAG-dependent skills until investigated.
Likely causes: embedding drift, failed sync (.rag-include), vault param wrong, data loss.
First check: re-run the failing probe with vault=null; check last sync commit.
```

### Step 4: Close the loop
`mark_retrieval` per probe: `mark` on PASS, `warn` on FAIL (recall miss is real signal).

### Step 5: Emit
Write report. Print one line: `RAG CANARY <date>: <pct>% PASS|FAIL (<n>/<total>). <halt note if FAIL>`. Non-zero exit on FAIL (cron-detectable).

## Quality Checks
- [ ] One mark_retrieval per probe
- [ ] Assertion is deterministic (expected file in top-k), not fuzzy
- [ ] FAIL emits a halt recommendation + first-check guidance
- [ ] canary-set.yaml exists + is the source of probes
- [ ] Non-zero exit on FAIL

## Escalation rules
Escalate to Donal immediately if: pass-rate < threshold (RAG integrity issue - this gates other work); a previously-passing probe newly fails (regression - name the probe + likely cause); the canary set itself can't load (missing/corrupt yaml).

## Cost note (Rule 15)
~12 searches, no synthesis ≈ $0.10. Daily cron ≈ $3/mo. Hard-cap $1. Pure retrieval = Haiku/deterministic.

## Composition
`composes_with_sesh: false`. A health probe, never a sprint.

## Cross-references

- Cost levers (sub-token / API): `docs/rag-cost-optimization.md` (Haiku cache floor ~4k empirical; dedup sub-queries + chunks; OpenAI-embedding vs Anthropic-synthesis surfaces)
- Pattern source: `docs/rag-query-pattern-library.md` (Pattern 7)
- Canary set: `knowledge/rag/canary-set.yaml`
- Gates: `/rag-fanout`, `/rag-synthesize`, `/rag-skill-discovery`, any RAG-citing audit
- Closed-loop: CLAUDE.md MCP contract
- Rules: 08, 15; Sub-plan 15

## Pickup Prompt
```
/rag-canary
/rag-canary --threshold 0.95 --out /tmp/canary.md
/rag-canary --add "OO chatbot pilot pricing|agency-operator|knowledge/agency/chatbot-pricing.md|5"
```
