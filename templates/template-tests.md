---
slug: {{slug}}
cycle: {{C1}}
folder: {{one.ie/web|packages/sdk|channels}}
demo:                                  # this file IS the cycle's demo gate — the todo references it by this command
  command: "bun vitest run {{folder}}/tests/e2e/{{cycle}}.test.ts"
  asserts: "{{the promise's one proof observable — what passing means}}"
  budget:  "<2s wall · ≤80 LOC"
deliverables:
  - {{D1 — what it asserts}}
---

# Tests — {{slug}} · {{cycle}}

> Spawned by the promise's derives.tests at TEST — before code.
> One `expect()` per documented observable — **assert the destination, not the path.**
> The FIRST assertion is the promise's `proof:` restated as code — nothing new
> (if `proof:` needs a live surface, note here that PROVE's oracle asserts it).
> Write it FIRST: it must **fail before W3 lands (red), pass after (green).**
> Run: `bun run verify` in `{{folder}}/`.

## {{D1 — user-facing outcome}}

```typescript
import { describe, it, expect } from 'vitest'
// import { {{thing}} } from '{{path}}'   // one import per file — no cross-cycle coupling

describe('{{slug}} · {{deliverable}}', () => {
  it('{{the outcome a user cares about}}', async () => {
    const result = await {{run the real thing}}
    expect(result).toBe({{the destination}})
    // ✓ destination:  expect(getStrength(edge)).toBe(1)
    // ✗ not the path: expect(button).toHaveClass('bg-primary')
  })
})
```

## The three verdicts — inherited from the promise, missing here until 2026-09-22

`template-feature.md` already carries this law for a promise's `proof:`:

```
0  ok         — the thing is built and behaves
1  RED        — the thing is genuinely missing or wrong
3  CANNOT RUN — the check could not reach its evidence. NOT a red.
```

> red and cannot-run send a human to opposite places: red means fix the build,
> cannot run means fix the environment.

The resolvers obey it too — `taskAccess` answers `operate | read | none |
**undetermined**`, and the comment above it calls collapsing `undetermined` into
`not_found` "a semantic verdict manufactured out of a transient fault."

**Tests never inherited it, and `expect()` only has two outcomes.** So every
unreachable read became a RED about a promise that was never exercised. Three
measured on one gate (2026-09-22, `one.ie/web`):

| What actually happened | What the test reported |
|---|---|
| the gateway refused a read (`ok:false`) | "a marked outcome does not move a weight" |
| `tasks:create` inserted the atom, then lost its response at the 10s bound | "the slug wire is broken" — while claim+link **by slug** were at that moment returning the real tid |
| the task row was readable, its `workspace:` tag not yet | "a member cannot claim a task" |

Not one was a defect in the thing under test. The third-verdict rules:

- **A refused read is not evidence.** Guard the READ before you assert anything
  about its rows: `expect(res, 'the door never answered — infra, not <promise>').toMatchObject({ ok: true })`.
  `not.toContain` is vacuously true against the `[]` a refusal normalises to, so
  without this a closed-queue claim goes GREEN on a 503.
- **Never let one lost premise speak for N tests.** Record what later tests need
  BEFORE asserting it — `tid = String(first.tid ?? again.tid ?? '')`, then assert.
  A dependent test with no premise calls `t.skip()` with a loud reason; it has not
  failed, it never ran. A skip is not a pass (`tests/helpers/substrate-armed.ts`).
- **Say which verdict you are reporting, in the assertion message.** A bare
  `expected undefined to be true` sent two sessions after a code regression that
  did not exist.

## Wait for what the code READS, not for the row

A visibility wait must name the observable the code under test actually queries.

Measured the same day: a suite waited on all four of its fixtures with
`tdb.visible` and the first claim still answered `not_found`, which reads as "the
cluster is not read-after-write consistent even after a confirmed visible read."
It was not. `tasks:claim` gates on one read — the task's **tag** — and the wait
asserted `has tid`. In TypeDB an attribute is its own concept with its own
ownership edge, so the row can be readable while its tag is not. The wait stopped
one edge short of the fact authorization depends on: **incomplete, not
insufficient.** One line, and the difference between blaming your infrastructure
and fixing your fixture.

Before you write a wait, read the resolver and copy the query it issues.

## The cheapest read that shows it

`template-promise.md` asks for "proof that flips green — evidence, not a status."
Add the second half: **the cheapest read that shows the one observable.** Proof
cost is part of the proof, because an expensive proof is a proof that degrades.

Worked, from `tasks-do-roundtrip.test.ts`:

```
#: 1
What is achieved: a marked outcome deposits weight on the tag path
Proof that flips green: readTagNodeStrength — a keyed read of two tag nodes
                        MEASURED 0.45-0.59s
────────────────────────────────────────
#: 2
What is achieved: the open queue orders by that weight, dropping nothing
Proof that flips green: tests/unit/loop/tasks-everywhere-order.test.ts
                        pure, no substrate, already green
```

Both were proved by ONE assertion polling `tasks:everywhere` — a four-branch
fan-out over the whole task table (5,912 rows; branches 0.8-4.4s each against a
10s gateway bound), every 4s, three times per file. Roughly **156 full-corpus
reads to prove two rows moved**, and under the full gate the polling manufactured
the 5×5xx-in-10s that opens the breaker for 30s — which its own 55s budget could
not outlive. The test became a load generator on the door it was measuring.

Two-thirds of that claim was already provable for free. Ask of every proof:

- **what is the one observable** — the destination, in the code's own terms
- **what is the cheapest read that shows it** — keyed beats scanned; pure beats
  keyed; a poll is a last resort, and it backs off
- **can it be split** — if the claim has a pure half, prove that half purely and
  leave the substrate to prove only what needs a substrate

## Before you ship the test

- [ ] The first assertion is the promise's `proof:` restated as code
- [ ] It failed before the code landed and passes after (red before green)
- [ ] Every read is guarded before its rows are asserted — a refusal cannot read as an empty answer
- [ ] No test asserts a premise a previous test failed to record; dependents skip loudly
- [ ] Every wait names the observable the code under test actually queries
- [ ] The proof is the cheapest read that shows the observable, and the pure half is proved purely

<!--
Rules (from do.md testing policy):
- ≤1 test file per cycle
- Goal-based: assert shipped outcome, not implementation detail
- Vitest-first; add requires_playwright: true in todo frontmatter if browser needed
- UI states: if the cycle has a text/<slug>-ui.md, EVERY row of its component-states
  table gets a render test (vitest + @testing-library — empty/loading/error/populated),
  and the todo outcome includes `do-prove.sh --route <path>` per route in the -ui.md's
  Proof section. A table row with no test is a build gap.
- N-variant split-test → winner mark(), losers warn(0.5)
- One import per test file (avoid cross-cycle coupling)
-->
