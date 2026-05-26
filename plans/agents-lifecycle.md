---
mode: lean
lifecycle: construction
classifier:
  spec_locked: true
  variance_known: true
  exit_scalar: "every state in the agent state machine has a defined trigger, side effect, owner action, and UI copy"
  files_known: true
---

# agents-lifecycle.md — Agent state machine

Migration `0007_agents_skills_tools_themes.sql` defines `agents.state` as one
of: `draft | live | paused | evolving | archived`. The substrate's L5 evolution
loop transitions agents automatically. This doc names every transition, what
triggers it, what changes, and what the owner sees.

> Companion to `ui.md §3 C3` (agents tabs) and `C12` (agent detail tabs).
> `engine.md` Rule 2 enforces the substrate's role here — pheromone-driven,
> deterministic, auditable.

---

## 1. The state machine

```
                ┌──────────┐
                │  draft   │   ← created via /agents/new (form or chat)
                └─────┬────┘
                      │ owner: [Publish]
                      │  + deploy gate eval ≥ 0.65
                      ▼
        ┌─────►┌──────────┐◄───────┐
        │      │   live   │        │
        │      └─┬──┬───┬─┘        │
        │        │  │   │          │
        │ pause  │  │   │ unpause  │
        │ (mgr)  │  │   │ (owner)  │
        │        │  │   │          │
        ▼        │  │   │          │
   ┌──────────┐  │  │   │  ┌──────────┐
   │  paused  │  │  │   └──┤ evolving │
   └──┬───────┘  │  │      └─────┬────┘
      │ resume   │  │            │
      └──────────┘  │            │
                    │ archive    │ rewrite passes
                    │ (owner)    │ deploy gate
                    │            │
                    │            ▼
                    │      ┌──────────┐
                    │      │   live   │  (back, with v++ generation)
                    │      └──────────┘
                    │
                    ▼
              ┌──────────┐
              │ archived │  ← terminal; row kept for audit; agent un-callable
              └──────────┘
```

---

## 2. The 5 states

### draft

```
Trigger:        AgentForm.tsx submit OR chat-driven create
Side effects:   row in `agents` with state='draft', generation=0, frontmatter only
                no deploy, no callable
UI badge:       ◌ draft
Owner can:      [Edit] [Publish] [Delete]
Visible in:     "Drafts" tab on /agents
Substrate:      no pheromone yet (untrained)
```

### live

```
Trigger:        owner [Publish] + deploy gate eval ≥ 0.65 (per W3E7)
Side effects:   state='live', generation++, addressable at <slug>/<name>,
                tools registered, model pinned, pricing active
UI badge:       ● live
Owner can:      [Pause] [Edit] [Republish (new gen)] [Archive]
Visible in:     "Live" tab on /agents
Substrate:      collects mark/warn per call; ready for L5 evaluation
```

### paused

```
Trigger:        owner [Pause]    OR    deploy gate fails on republish
Side effects:   un-callable; tools deregistered; pricing suspended
                existing chats can still load history but new messages return
                "This agent is paused" rich-message
UI badge:       ⏸ paused
Owner can:      [Resume] [Edit] [Archive]
Visible in:     "Paused" tab on /agents
Substrate:      paths fade naturally; no new pheromone
Owner UI copy:  "Paused. Resume to make it callable again."
```

### evolving

```
Trigger:        substrate L5 fires when:
                  success_rate < 0.50 AND sample_count >= 20
                (per .claude/rules/engine.md §Agent Self-Improvement)
Side effects:   state='evolving', NEW generation row in `agent_generations`,
                prompt rewrite running in background (see runbook.md);
                agent STAYS callable during evolution — old prompt serves
                until new prompt passes its eval gate
UI badge:       ⟳ evolving
Owner can:      [Pause] (cancels evolution) [Watch progress] [Force rollback]
Visible in:     "Evolving" tab on /agents
Substrate:      L5 loop active; pheromone deposits inform the rewrite
Owner UI copy:  "Evolving — success rate {X}% triggered a prompt rewrite.
                Old prompt still serving. Estimated finish: {N} more chats."
Failure case:   rewrite fails 3 evals in a row → state → paused, owner notified
                via E5 (emails.md) + InboxBell
```

### archived

```
Trigger:        owner [Archive]
Side effects:   un-callable, hidden from default lists, row preserved for audit,
                still findable via /history search and direct URL,
                accept-links 410 Gone, refunds queued for last 7d revenue
UI badge:       ▢ archived
Owner can:      [Restore] (only if generation matches a still-valid model)
                [Permanently delete] (after 30d grace; W9 territory)
Visible in:     "Archived" tab on /agents
Substrate:      paths terminal; pheromone stops accumulating
```

---

## 3. Transition table

| From | To | Trigger | Owner-initiated? | Side effects |
|------|-----|---------|------------------|--------------|
| draft | live | [Publish] passes eval gate | yes | gen++; deploy active |
| draft | archived | [Delete] | yes | row kept 30d, then purge |
| live | paused | [Pause] OR republish fails gate | mixed | callable=false |
| live | evolving | L5 substrate trigger | no | rewrite spawned; old prompt serves |
| live | archived | [Archive] | yes | refunds last 7d |
| paused | live | [Resume] | yes | callable=true |
| paused | archived | [Archive] | yes | as above |
| evolving | live | rewrite passes eval gate | no | gen++; new prompt serves |
| evolving | paused | rewrite fails 3x OR owner [Pause] | mixed | E5 email |
| evolving | archived | owner [Force rollback]+[Archive] | yes | rewrite cancelled |
| archived | live | [Restore] (model still valid) | yes | gen++; deploy resumes |

---

## 4. Owner copy per transition (UI strings)

These power the badges, banners, and confirmation modals. Lock these once
shipped to keep substrate event vocabulary stable.

```
draft → live:       "Publish {agent}? Last eval: rubric {comp} (gate ≥ 0.65)."
                    Confirm: [Cancel] [Publish & deploy]

live → paused:      "Pause {agent}? It will stop accepting calls."
                    Confirm: [Cancel] [Pause]

live → evolving:    (no modal — substrate-driven; banner appears on agent detail)
                    "Substrate has started rewriting this agent's prompt.
                     Old prompt still serving. Watch progress in the Eval tab."

evolving → live:    (auto on rewrite pass — banner becomes a notification)
                    "Rewrite passed eval (rubric {comp}). New prompt is live."

evolving → paused:  (auto on 3 failed rewrites — modal on next owner visit)
                    "We tried to evolve this agent 3 times and the rubric
                     stayed below 0.65. Paused for your review.
                     [Open eval] [Resume anyway] [Archive]"

paused → live:      "Resume {agent}? It will start accepting calls again."
                    Confirm: [Cancel] [Resume]

* → archived:       "Archive {agent}? It will stop being callable. Refunds
                     queued for the last 7 days of revenue (${amount}).
                     You can restore within 30 days."
                    Confirm: [Cancel] [Archive]
```

---

## 5. Substrate signals emitted per transition

Every transition emits an `emitClick` (where owner-initiated) and a substrate
signal (always). These feed `/insights` (substrate observability surface):

| Transition | UI signal | Substrate signal |
|-----------|-----------|------------------|
| draft → live | `ui:agents:publish` | `agents:transition:live` |
| live → paused | `ui:agents:pause` | `agents:transition:paused:manual` |
| live → evolving | (none — substrate) | `agents:transition:evolving` + `mark` on the rewrite path |
| evolving → live | (none) | `agents:transition:live:auto` + `mark` |
| evolving → paused | (none) | `agents:transition:paused:auto` + `warn(1)` on the rewrite path |
| any → archived | `ui:agents:archive` | `agents:transition:archived` |

Per `engine.md` Rule 1: every transition closes its loop. `mark` on success,
`warn` on auto-failure, `dissolve` on missing-handler. Owner-initiated
transitions also emit `ui:agents:*` per `.claude/rules/ui.md`.

---

## 6. UI surfaces per state

| Surface | Shows |
|---------|-------|
| `/u/[slug]/agents` (C3) | tab filters per state; badge per row |
| `/u/[slug]/agents/[name]` Overview tab | current state badge + last transition timestamp |
| `/u/[slug]/agents/[name]` Versions tab | generation history; each row tagged with the transition that created it |
| `/u/[slug]/agents/[name]` Eval tab | rubric scores driving the gate; latest 5 evals |
| `<InboxBell>` + `/notifications` | substrate-emitted transitions (evolving→live, evolving→paused) |
| `/insights` (future, see ui.md gaps) | aggregate transitions across all owned agents; success-rate trends |
| email E5 (emails.md) | sent on evolving → paused (3 failed rewrites) |

---

## 7. Edge cases

**Plan downgrade kills paid features.** If owner downgrades from Pro → Free
and an agent uses paid skills, agent transitions to `paused` with copy:
*"This agent uses paid skills. Pausing until plan covers them again."*

**Skill removed mid-flight.** If a skill an agent depends on is deleted,
agent transitions `live → paused` with copy: *"Skill '{name}' was removed.
Replace it or remove from the agent to resume."*

**Model deprecated.** If `agents.model` references a model that retires
(e.g. claude-3-haiku replaced by claude-haiku-4-5), agent transitions
`live → paused` (NOT evolving — this is owner intervention) with copy:
*"Model '{old}' retired. Pick a replacement to resume."* + suggestion list.

**Substrate quiet period.** L5 only fires after `sample_count >= 20`. New
agents in `live` state with < 20 calls cannot transition to `evolving`.
This is intentional — small samples are noise.

---

## 8. Cross-references

- `web/migrations/0007_agents_skills_tools_themes.sql` — `agents.state` enum
- `.claude/rules/engine.md` Rule 2 + Agent Self-Improvement — substrate L5
- `ui.md §3 C3` — agents tab filters per state
- `ui.md §3 C12` — agent detail tabs (Versions, Eval)
- `ui-todo.md W3E7` — deploy gate state-machine task
- `ui-todo.md W8E7` — UI tab filters task
- `emails.md E5` — eval failure email
- `runbook.md` — operational triggers + thresholds (sample size, eval cadence)

---

*Five states. Eleven transitions. Owner-initiated emit `ui:*`; substrate-driven
emit `agents:transition:*`. Every transition closes a loop.*
