---
title: Skills at scale — versioning, marketplace, telemetry, sharing
slug: skills-scale
type: plan
tier: complex
mode: evolution
tags: [skills, scale, versioning, marketplace, telemetry, sharing]

# ─── GOAL CONTRACT ─────────────────────────────────────────────────────
# This plan is the home for deferred work from skills-todo. It activates
# when a workspace passes ~10 installed skills and the dashboard needs to
# behave less like a manage page and more like a catalog.

goal: "When a workspace has >10 installed skills, the user can find, evaluate, version, share, and earn from skills without the dashboard becoming a wall of cards."
outcome: ""                # filled in when the first cycle is scoped
outcome_asserts: ""

deliverables:
  # filled per cycle as work begins

ux_before: "Skills dashboard works fine at 3–8 skills but breaks down past ~10: no search, no filter, no usage signal, no way to share a skill with another workspace, no rollback if a published skill regresses."
ux_after:  "Skills dashboard scales: search/filter/sort, usage + cost roll-up, drift indicator, bulk actions, version history with rollback, cross-workspace sharing, marketplace publish, rename support."
ux_delta:  "Workspace owners can manage a portfolio of skills, not just a small set."

parallel_budget:
  haiku:   20
  sonnet:  10
  opus:    2

# Cycles are not yet scoped — this is a backlog of deferred items inherited
# from skills-todo.md. They become cycles only when user pressure justifies.
---

# Skills at scale — versioning, marketplace, telemetry, sharing

**Purpose:** Container for everything `skills-todo.md` explicitly deferred. Nothing here ships until a real workspace hits the threshold described in `ux_before`.

---

## Why this plan exists

`skills-todo.md` (closed 2026-05-24) built the substrate — markdown contract + one HTTP endpoint + four authoring surfaces (web Studio, CLI, MCP, raw HTTP). It deliberately stopped short of scale features. The architectural rule from root `CLAUDE.md` drove the cut:

> Power through simplicity — the meta-layer should obey the rule the schema already obeys.

The schema has a grammar, not an SDK. Skills follow the same rule: markdown grammar + one endpoint, every surface speaks it locally. Scale features add weight and only earn their place when a real workspace can't function without them.

**Heuristic:** a scale cycle starts when one of these is true:
- A workspace has >10 installed skills and the dashboard is unusable
- A user has asked for the feature twice in two different threads
- A skill in production silently regressed and nobody noticed

---

## Deferred backlog (inherited from skills-todo.md)

Each row is a future cycle. Order is roughly by likely demand, not commitment.

| # | Topic | Source-doc deferral note | First trigger to watch for |
|---|---|---|---|
| 1 | Search + filter chips + sort dropdown | "doesn't matter until installed > ~10 per workspace" | First workspace with ≥10 skills |
| 2 | Usage count + cost roll-up per row | "needs usage tracking primitive first" | Stripe rollup or pheromone log shows real per-skill cost |
| 3 | Drift indicator on each row | implicit in "telemetry" deferral | First confirmed regression-not-noticed incident |
| 4 | Bulk select + bulk actions | follows from #1 — only useful at scale | Same trigger as #1 |
| 5 | Group-by-tag view | follows from #1 | First user who installs >5 tags worth |
| 6 | Inline eval progress UI on a row | "today: link to detail page; revisit when authoring volume grows" | A user authoring 3+ skills in a session |
| 7 | Versioning + rollback | "skills have `version:` but no R2 snapshot history" | First "I published a regression" report |
| 8 | Marketplace publish | "product question, not editor scope" | Marketplace product decision lands |
| 9 | Scripts / references / assets editor UI | "data model declares the dirs; no skill in the catalog uses them" | First skill that actually needs `scripts/` |
| 10 | Telemetry: usage count + cost roll-up | "needs usage tracking primitive first" | After #2 lands |
| 11 | Legacy `one.ie/web/skills/*.md` migration | "one-shot script, not a cycle" | When the legacy directory is the last blocker on the new path |
| 12 | Multi-workspace skill sharing | "permissions model work — separate plan" | First "can I share my skill with another workspace?" request |
| 13 | Skill rename + R2 move + D1 cascade | "out of scope for v1" | First user who tries to rename and breaks their wiring |
| 14 | Live edit channel (WsHub DO + SSE) | "MCP authoring + browser refresh covers the use case" | First user asking for sub-second live-cursor parity |
| 15 | Description optimizer surface | "today chat-invoked; defer until measurements show users want a button" | Eval data shows desc-tuning is the dominant edit type |

---

## Inherited blockers (from skills-todo.md cycle close)

These shipped as "deferred with a recorded reason" — they have a known unblocker before they become cycles.

| Item | Blocked on | What unblocks it |
|---|---|---|
| `/api/eval` reads `meta.evals` as primary, sidecar as fallback | `lib/skill/parser.ts` only supports flat `- string` arrays | Extend the parser (or pull in a YAML lib) to handle nested `evals: [{prompt, assertions[]}]` — same parser is duplicated in `packages/cli/src/skill-parser.ts` |
| Eval-the-draft button from Studio | UI surface for sending `draftContent` + `draftEvals` from `studioStore` | Wire a `Run eval (draft)` button into `SkillStudio` that calls `/api/eval` with the current draft instead of the persisted file |

---

## How to start a cycle here

1. Confirm the first-trigger condition has actually fired (a user request, an incident, a measurement — not speculation).
2. Copy `plans/template-todo.md` to define a real `goal:` + `outcome:` for the cycle.
3. Move the row from the backlog table above into the new todo's cycles section.
4. Re-evaluate priority — old rows that haven't triggered may have been wrong calls and can be dropped.

---

## See also

- `plans/skills-todo.md` — the closed substrate plan
- `plans/skills.md` — current state of the skills surface
- `plans/skill-format.md` — the locked markdown grammar
- `plans/evaluate.md` — the eval lifecycle
