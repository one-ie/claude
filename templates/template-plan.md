status: ACTIVE

<!--
TEMPLATE — DESIGN PHASE. Copy to text/<slug>-plan.md, fill, delete this comment.
Owner: Opus · high (the decider — never delegated). Skills: typedb, signal where the
substrate is touched. This is the DESIGN phase of /do (see text/do-refined.md).
Runs AFTER PROMISE (text/<slug>.md) and SURVEY, BEFORE the plan (text/<slug>-todo.md).
Spawned by the promise's derives.plan at DESIGN — it designs the promise's gap
list (only the gap gets designed) and reconciles upward to text/<slug>.md.
-->

---
title: {Human-readable title}
slug: {kebab-slug}
type: plan
tier: {trivial | simple | complex}
source_of_truth:
  - text/{feature}.md          # the promise this design must keep
  - text/dictionary.md        # canonical names — reconcile against this
  - schema/one.tql             # only if the substrate is touched
---

# {Title}

## The promise (from PROMISE)

{One line, copied from text/<feature>.md — the design exists to keep this promise.}
{The one proof observable, copied from the promise — every decision below is measured against keeping it true.}

## Reuse verdict (from SURVEY)

{expose | extend | build | drop} — {what already exists, what the real gap is. Only the gap gets designed.}

## Evidence (verified, dated)

Every claim this design makes about existing code carries `file:line` proof, verified on the day of writing — never recalled from memory or a previous plan. A claim without a citation is a guess; a stale citation is worse than none. State what was checked and what it showed:

| Claim | Status | Evidence |
|---|---|---|
| {what the design assumes exists / is absent} | ✅ shipped / ❌ gap | `{path}:{line}` — {one clause of what's there} |

## Design

### Data shape
{What extends the existing schema. Reuse relations; add the minimum field. NEVER a parallel model.}

### Types
{Flow from the schema. No hand-maintained second copy.}

### API
{Which existing route family this joins. New route only if SURVEY said `build`.}

### UI
{Which existing components / pages / navigation this composes. Empty / loading / error / edge states named here, not deferred to BUILD.}

## Reconciliation (gate — reconcile against every canon this design touches)

The 7 canons: `substrate · dictionary · authority · sdk · design · navigation · types`. Tick only those this design touches; each becomes a `do-reconcile.sh <canon>` gate at W4.

- [ ] **dictionary** — names exist in `text/dictionary.md`; no dead name, no synonym
- [ ] **substrate** — extends `schema/one.tql`, never forks; no new dimension/verb (or one-sentence justification: {…})
- [ ] **navigation** — every new surface names its manifest entry + ≥1 inbound link *here*, not deferred to BUILD
- [ ] **authority** — access resolves by the walk-up; no ad-hoc role-equality check
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
