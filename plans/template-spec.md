<!--
TEMPLATE — SPEC (the design). Copy to plans/<feature>.md, fill, delete this comment.
Owner: Opus · high (the decider — never delegated). Skills: typedb, signal where the
substrate is touched. This is P3 of the /do cycle (see text/000-do.md).
Runs AFTER FRAME (text/<feature>.md) and SURVEY, BEFORE the todo (plans/<feature>-todo.md).
-->

---
title: {Human-readable title}
slug: {kebab-slug}
type: spec
tier: {trivial | simple | complex}
source_of_truth:
  - text/{feature}.md          # the promise this design must keep
  - plans/dictionary.md        # canonical names — reconcile against this
  - schema/one.tql             # only if the substrate is touched
---

# {Title}

## The promise (from FRAME)

{One line, copied from text/<feature>.md — the design exists to keep this promise.}

## Reuse verdict (from SURVEY)

{expose | extend | build | drop} — {what already exists, what the real gap is. Only the gap gets designed.}

## Design

### Data shape
{What extends the existing schema. Reuse relations; add the minimum field. NEVER a parallel model.}

### Types
{Flow from the schema. No hand-maintained second copy.}

### API
{Which existing route family this joins. New route only if SURVEY said `build`.}

### UI
{Which existing components / pages / navigation this composes. Empty / loading / error / edge states named here, not deferred to BUILD.}

## Substrate reconciliation (gate — zero new core concepts without justification)

- [ ] Names exist in `dictionary.md` (no dead names)
- [ ] No new dimension / verb / type — or one-sentence justification: {…}
- [ ] No locked-rule break (6 dims, 6 verbs, 3 rules)

## Pre-mortem (assume it shipped and failed — why?)

{Red-team the design. Walk every boundary. Name the assumptions that, if wrong, sink it.
Each failure mode below becomes a test in the todo's demo gate.}

| Failure mode | Likelihood | Becomes test |
|---|---|---|
| {how it could break} | {low/med/high} | {the assertion that catches it} |

## Decisions (this, not that, because)

{Every non-obvious choice gets one line. Favour boring, proven shapes over clever ones.
A decision nobody wrote down is one the next person re-litigates.}

- **{choice}** over **{alternative}** — because {reason}.

## Clarifications (CLARIFY gate — features/schema only)

{≤5 high-impact ambiguity questions and their answers, written here at design time.
NOT a second human gate — INTAKE is the one front-door checkpoint. This is decision capture.}

- **Q:** {scope / data-model / edge-case / naming question}
  **A:** {the decision}

## Out of scope

{What this explicitly does NOT do — the boundary that keeps the todo honest.}
