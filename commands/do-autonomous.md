# /do autonomous loop

Invoked directly (`/do-autonomous`); `do.md` has no `--once` row in Step 0. The live
headless contract is `do.md` § *Autonomous gate resolution* (`--autonomous` /
`DO_AUTONOMOUS=1`), backed by `one.ie/web/src/lib/do-autonomous.ts` and
`text/do-autonomous-plan.md`. This file is the task-queue loop it runs.

---

## Loop

```bash
W0: bun run verify (once per session, skip if already passed)

ORIENT: Read text/TODO-plan.md
        → note the active front (Atomicity / Vocabulary / New Surfaces)
        → note the Top 15 priority list
        → let this shape which task you pick
        → every task traces UP to a promise (text/<slug>.md): the work is kept
          only when the promise's proof: still exits 0. Reconcile upward, never against it.
```

```
loop:
  SENSE:    POST http://localhost:4321/api/ask/tasks:mine     (or tasks:everywhere)
            (/api/tasks does not exist — tasks:* receivers are the only door,
             and /api/ask is POST-only)
            Sort by priority (effective = score + strength − resistance)
            Skip blocked tasks (blockedBy non-empty)

  SELECT:   Pick highest unblocked (P0 > P1, attractive > ready > exploratory)
            If all blocked: GET /api/export/highways → follow pheromone highways
            (deadlock escape; /api/state does not exist)

  EXECUTE:
    BRIEF (before touching any file):
      source = task.source
      If source missing: grep -l "{task.name}" text/*-todo.md
      Read text/{source}-todo.md:
        • frontmatter source_of_truth → spec docs to pre-load
        • find checkbox matching task.name → note exit criteria + "See also"
        Read each source_of_truth entry (first 80 lines each)
    WORK: run W1-W4 against the briefing above
      W1 targets files named in task description + source_of_truth
      W4 exit gate: composite ≥ 0.65 AND exit criteria from TODO section

  VERIFY:   bun tsc --noEmit on touched files

  MARK:     POST http://localhost:4321/api/ask/tasks:status
              { "data": { "tid", "status": "done", "workspace": "<slug>" } }
            (/api/tasks/{id}/complete does not exist — tasks:status is the only
             status door, same as /close)

  CLOSE:    Neither /api/loop/cycle-close nor /api/loop/close exists. The live
            cycle-close door is the world:do-event receiver:
            POST http://localhost:4321/api/signal/world:do-event
              { "data": { "type": "learn", "slug", "cycle", "composite", "tags": [...] } }
            composite = the `task` rubric — weights are data in
            .claude/scripts/rubric-weights.json (`task` block), which
            w4-rubric.ts reads. Today: 0.30·security + 0.25·stability +
            0.20·simplicity + 0.15·integration + 0.10·speed.
            This is the 5-axis TASK rubric — NOT the in-cycle W4 composite,
            which carries goal-fit at 0.30 and gates on it at >= 0.50
            (see do.md § W4). w4-rubric.ts prints it as `task-composite=`
            so the two can never be confused in a log.
            composite ≥ 0.65 → mark(loop:cycle:{slug}, composite × 5)
            composite < 0.65 → warn equivalents (route back to W3, max 3 W4 loops)

  FEEDBACK: POST http://localhost:4321/api/signal/loop:feedback {
              (receiver is a PATH segment — /api/signal bare returns 400)
              data: {
                tags: task.tags,
                strength: rubricAvg,
                content: { task_id, rubric, outcome: 'result' }
              }
            }
            strength >= 0.65 → mark each tag path
            strength < 0.65 → warn(0.5) each tag path
            Always emit — even timeout, even dissolved. Every loop closes.

  GROW:     GET http://localhost:4321/api/export/highways → report learned paths

  → repeat
```

After each task: report name, strength, priority, tests passed, unlocked tasks.

---

## `--once`

Single iteration: pick one task → execute → mark → stop.
Report: name, strength, priority, tests, deterministic outcome (result/timeout/dissolved/failure).
