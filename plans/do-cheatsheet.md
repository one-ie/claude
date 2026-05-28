---
title: /do lifecycle cheat-sheet
slug: do-cheatsheet
type: spec
tier: feature
source_of_truth:
  - text/do-cheatsheet.md
  - text/000-do.md
  - plans/templates.md
  - .claude/commands/do-new.md
---

# /do lifecycle cheat-sheet

## Promise (from FRAME)
A developer reads one page and knows, per phase: purpose, template, skill/agent, model·effort, gate.

## Reuse verdict (from SURVEY)
**build** — the data exists across `000-do.md` (phases+gates), `templates.md` (templates+skills+agents), `do-new.md` (tier spines+gates), but no single consolidated page does. This synthesizes, it doesn't duplicate.

## Design
One doc, `docs/do-cheatsheet.md`. Three sections, each a join of the three sources:
1. **The phase table** — Phase · Purpose · Template · Skills+Agents · Model·Effort · Gate.
2. **Tier spines** — what each of PATCH/FIX/FEATURE/SCHEMA walks.
3. **The gates** — CLARIFY, ANALYZE, W4 rubric, doc-sync, PROVE-merge.

## Pre-mortem
- Risk: the cheat-sheet drifts from source docs over time → mitigation: it links each section back to its source-of-truth file.

## Decisions
- **One table, not three** over per-source tables — because the developer wants the join, not the seams.

## Out of scope
Anything beyond a read-only reference; no behavior change to `/do`.
