# /do autonomous loop

Loaded by `do.md` for empty invocation or `--once` flag.

---

## Loop

```bash
W0: bun run verify (once per session, skip if already passed)

ORIENT: Read docs/TODO.md
        → note the active front (Atomicity / Vocabulary / New Surfaces)
        → note the Top 15 priority list
        → let this shape which task you pick
```

```
loop:
  SENSE:    GET http://localhost:4321/api/tasks
            Sort by priority (effective = score + strength − resistance)
            Skip blocked tasks (blockedBy non-empty)

  SELECT:   Pick highest unblocked (P0 > P1, attractive > ready > exploratory)
            If all blocked: GET /api/state → follow pheromone highways (deadlock escape)

  EXECUTE:
    BRIEF (before touching any file):
      source = task.source
      If source missing: grep -l "{task.name}" docs/*-todo.md
      Read docs/{source}-todo.md:
        • frontmatter source_of_truth → spec docs to pre-load
        • find checkbox matching task.name → note exit criteria + "See also"
        Read each source_of_truth entry (first 80 lines each)
    WORK: run W1-W4 against the briefing above
      W1 targets files named in task description + source_of_truth
      W4 exit gate: composite ≥ 0.65 AND exit criteria from TODO section

  VERIFY:   bun tsc --noEmit on touched files

  MARK:     POST http://localhost:4321/api/tasks/{id}/complete

  CLOSE:    POST http://localhost:4321/api/loop/cycle-close {
              slug,
              kind: "code",
              scores: { security, stability, simplicity, speed }
            }
            composite = 0.35·security + 0.30·stability + 0.25·simplicity + 0.10·speed
            composite ≥ 0.65 → mark(loop:cycle:{slug}, composite × 5)
            composite < 0.65 → warn equivalents (route back to W3, max 3 W4 loops)
            Response: { ok, slug, kind, composite, gate: "pass"|"fail", marks: { cycle, namespaced } }

            Note: /api/loop/close (without "cycle-") is a different endpoint —
            it manages WorkLoop session/stage tracking. Don't confuse them.

  FEEDBACK: POST http://localhost:4321/api/signal {
              receiver: 'loop:feedback',
              data: {
                tags: task.tags,
                strength: rubricAvg,
                content: { task_id, rubric, outcome: 'result' }
              }
            }
            strength >= 0.65 → mark each tag path
            strength < 0.65 → warn(0.5) each tag path
            Always emit — even timeout, even dissolved. Every loop closes.

  GROW:     GET http://localhost:4321/api/highways → report learned paths

  → repeat
```

After each task: report name, strength, priority, tests passed, unlocked tasks.

---

## `--once`

Single iteration: pick one task → execute → mark → stop.
Report: name, strength, priority, tests, deterministic outcome (result/timeout/dissolved/failure).
