---
name: deploy
description: Run a deploy as tracked work — file the tasks template when the run opens, report each gate through deploy:event, and read what is still open or never ran. Use whenever a deploy is started, watched, or explained; when asked "did the tests actually run", "what is left in this deploy", "which gate bit", "why is the run still open"; or when wiring anything to the deploy tag. Refuses to call a run green while any gate is open. Does NOT ship — the ship door is release.sh.
---

# deploy — a deploy as work on a board, not lines in a log

**Purpose:** every deploy files its own work as ten open rows the moment it
starts, each owned by a named crew member, all joined by the run key the deploy
page already reads. Closing gates close rows. Gates that never fire stay open.

Source of truth: `one.ie/web/src/lib/deploy/event.ts` (the spine + mapper) ·
`one.ie/web/src/lib/deploy/tasks.ts` (the template) · `schema/deploy.tql` (the
questions) · promise: `text/deploy.md` · mechanism: `text/intake.md`.

---

## HARD RULES

- **An unrun gate is never a pass.** `deploy.sh` distinguishes four states
  (`pass|fail|unrun|n/a`) and a board that only knows open/done renders an unrun
  gate exactly like one still in flight. A gate is UNRUN when
  `deploy_gate_open($run,$stage)` is true and `deploy_gate_ran($gate,$target)` is
  empty — you join the two, because TypeQL cannot concatenate `"deploy:"+stage`
  and a function that pretended to would be vacuous. (It was, once: the first
  `deploy_unrun` asked for a *signal* per gate, but `deploy:event` writes to D1
  and paths, never a signal — so it returned every open gate, always.)
- **Green means every gate CLOSED, never "none failed".** A run where four gates
  never fired and none failed is **not** green. `deploy_green()` is defined as the
  absence of open work precisely so this asymmetry cannot be argued with.
- **File the template when the run OPENS.** Not as gates finish. Work that
  appears only once it is done is a changelog, not a board — and a gate that
  never runs would never get a row at all.
- **Never retype the gate names.** `DEPLOY_SPINE_STEPS` is the authority; the
  workflow diff, the event mapper and the tasks template all derive from it.
  A fourth copy is how a ten-gate run quietly files nine rows.
- **Bare words only.** The crew stakes are `health` (doctor), `ship`
  (release-manager), `deploy` (ceo). A namespaced subscribe tag matches zero
  signals and fails silently.
- **Chain with `call`, never `await`.** `__awaitParent` is written at
  `workflow-executor.ts:923` and read nowhere; `settle()` has no parent-resume
  leg, so an `await` chain step parks its parent forever, looking exactly like a
  slow step. Anything that runs after a deploy declares `deploy:done` as its own
  `trigger_source`.
- **A stale-but-clean tree makes every door script old.** `git status` clean says
  nothing about how old `release.sh`/`land.sh`/`deploy.sh` are — measured
  2026-09-14, the shared main tree was **479 commits behind `origin/main`** and
  clean, so `promote` ran a pre-fix version and refused a valid sha **4×**. Check
  first: `git rev-list --count HEAD..origin/main` — non-zero is exactly how many
  commits old the script you are about to run is.
- **`git merge-base --is-ancestor` proves REACHABLE, not EXECUTING.** Ancestry is
  a fact about the ref; which code runs is a fact about the checkout. A commit
  can be an ancestor of `main` and absent from the tree whose script you invoked.
- **A non-run must never read as a pass.** `gate-run.sh` exits **127** when its
  target is not on `PATH` (mechanism unconfirmed: govern.ts spawns with no env override, so PATH should inherit — measured anyway, twice) — invoke by
  absolute path. And never pipe a gate through `tail`: measured 2026-09-14,
  `verify` exited 1 while the pipeline reported **0**. `PIPESTATUS[0]`, or no pipe.
- **This skill does not ship, and neither do you.** It tracks. The ship is driven
  by **`release-manager`**, spawned as a subagent with `model: "opus"` — that holds
  however the ask arrived, `/deploy` or "ship it" in a sentence
  (`../../CLAUDE.md § The dev → prod loop` · `.claude/commands/deploy.md`). This
  skill reads what that agent reports and says what is still open. Production ships
  from `.release/` via `release.sh ship`; `./deploy --allow-dirty` ships every
  neighbour's uncommitted file and must never be suggested.

---

## The ten gates and who owns them

| # | Gate | Owner | The question it asks |
|---|---|---|---|
| 1 | `tree` | doctor | Can a receipt bind to this tree? A dirty tree hashes differently every second. |
| 2 | `credentials` | doctor | Are the secrets actually present — not merely named in a config? |
| 3 | `typecheck` | release-manager | Zero new type errors. The ratchet tightens, never loosens. |
| 4 | `tests` | release-manager | Did the FULL lane run, or be REUSED from a receipt for an identical tree? |
| 5 | `build` | release-manager | Does each target produce an artifact? A skipped build is not a passed build. |
| 6 | `smoke` | release-manager | Does it answer locally? The last cheap red. |
| 7 | `approval` | **human** (ceo notified) | The one gate no agent closes. |
| 8 | `migrations` | release-manager | Applied in order, and is the rollback known? |
| 9 | `ship` | release-manager | Shipped from `.release/`, where the receipt binds. |
| 10 | `health` | doctor | Do all five targets answer after the ship? "Deployed" is not "healthy". |

---

## The wire

```
signal("deploy:event", {
  run,            // the deploy's own id — the stamp in deploy.sh's log name
  target,         // one-prod | one-dev | pay | channels | api
  stage?,         // one of DEPLOY_SPINE_STEPS
  status?,        // start | ok | fail     (there is deliberately no `skip`)
  verdict?,       // green | red — final call only, closes the run
  sha?, door?, reason?, wallMs?, detail?
})
```

The run key is `deploy:<target>:<run>` (`deployRunKey`) — id **and**
idempotency_key, so a double-write returns the same row. It is also the `run:`
tag on every task the template files, so one string joins the board, the run
list and every `deploy_*()` function. **Never mint a second run-scoped key.**

Tasks are idempotent by a `slug:<runKey>:<stage>` tag — `tasks:create` returns
the existing row rather than inserting a twin, so a retried deploy does not pile
up duplicates. No dedupe logic to write.

---

## Asking the substrate

| Question | Function |
|---|---|
| What is left? | `deploy_open($run)` · `deploy_open_count($run)` |
| **What never ran?** | `deploy_gate_open($run,$stage)` ∧ NOT `deploy_gate_ran($gate,$target)` |
| Is it actually green? | `deploy_green($run)` |
| What can run now? | `deploy_ready($run)` |
| What is waiting on something? | `deploy_blocked($run)` |
| Which gate next? | `deploy_next($run)` — the ant's pick, strongest net trail |
| What does the doctor still owe? | `deploy_crew_open($run, "health")` |
| Which gate keeps biting? | `deploy_gate_trail($gate,$target)` — net, across runs |

`schema/deploy.tql` is **functions only, zero new types** — the `story.tql`
pattern. A deploy is the set of signals and tasks sharing one run key: a count,
not an entity. Never add a `deploy-run` entity; the row already exists.

---

## Reporting a deploy honestly

When asked how a deploy went, say in this order:

1. **Verdict** — green/red, and green only if `deploy_open_count() == 0`.
2. **Unrun gates, named.** If any, the run is not green no matter what the
   verdict field says. Say which.
3. **Which lane the tests took** — full, or REUSED from a receipt. A fast pass
   is never reported as a full pass.
4. **What bit**, in the gate's own words (`reason`).

Never report "deployed" as "healthy" — gate 10 is a separate question, and
`deploy.astro` probes it live rather than trusting the ship.
