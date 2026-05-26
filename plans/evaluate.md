# evaluate.md — the skill evaluation lifecycle

How a skill goes from "I think this works" to "the numbers say it works."

The substrate measures **delta**: skill ON vs skill OFF on the same model,
same prompts, same judge. If the skill doesn't make the model better,
it fails the gate. No vibes. Numeric receipts only — Rule 3.

---

## The pieces

```
skill.md          ← the prompt under test
  └─ evals/
       └─ evals.json   ← TestCase[] (prompt + expected + assertions)

POST /api/eval     ← trigger (or chat tool: eval)
  ↓
runner.ts          ← runs prompt twice: with-skill, without-skill
grader.ts          ← LLM judge: YES/NO per assertion
aggregate.ts       ← pass_rate · tokens · time · delta
iterate.ts         ← failures → "propose minimal diff" prompt
mastery.ts         ← BKT over iteration history → mastery curve
  ↓
R2: {slug}/skills/_workspace/{name}/iteration-{N}/benchmark.json
response: { benchmark, mastery, iterationPrompt }
```

| File | Role |
| --- | --- |
| [`web/src/lib/eval/runner.ts`](../one.ie/web/src/lib/eval/runner.ts) | One test case → Groq llama-3.3-70b, returns `{output, tokens, timeMs}` |
| [`web/src/lib/eval/grader.ts`](../one.ie/web/src/lib/eval/grader.ts) | LLM-as-judge — strict YES/NO on each assertion (top of `output`, 2 KB cap) |
| [`web/src/lib/eval/aggregate.ts`](../one.ie/web/src/lib/eval/aggregate.ts) | Pairs runs into `{with_skill, without_skill, delta}` Stats |
| [`web/src/lib/eval/iterate.ts`](../one.ie/web/src/lib/eval/iterate.ts) | Builds the next-iteration prompt from failed cases |
| [`web/src/lib/eval/mastery.ts`](../one.ie/web/src/lib/eval/mastery.ts) | Soft BKT over all iteration benchmarks → `{prob, level, curve[], improving}` |
| [`web/src/lib/eval/load-history.ts`](../one.ie/web/src/lib/eval/load-history.ts) | `loadHistory(slug, name, r2, { includeDraft? })` → `{ benches, mastery, hasEvals }`. Shared between dashboard SSR and detail-page `SkillEvalPanel` |
| [`web/src/pages/api/eval.ts`](../one.ie/web/src/pages/api/eval.ts) | HTTP entrypoint. Body: `{ slug, skillPath, iteration, draftContent?, draftEvals? }`. When `draftContent` is set, bypasses R2 read and writes the benchmark under `iteration-N.draft/` so saved iterations aren't polluted |
| [`web/src/components/skills/SkillEvalPanel.tsx`](../one.ie/web/src/components/skills/SkillEvalPanel.tsx) | Detail-page eval surface: mastery chip + sparkline + latest `<EvalCard>` + iteration history + `Run eval now` button |
| [`web/src/components/chat/EvalCard.tsx`](../one.ie/web/src/components/chat/EvalCard.tsx) | Inline benchmark widget — used in chat AND inside `SkillEvalPanel`. Single source of truth for benchmark display |
| [`web/src/pages/api/chat.ts:141-198`](../one.ie/web/src/pages/api/chat.ts) | Same flow exposed as a chat tool the LLM can call |
| ~~`web/src/actions/skills.ts skill.eval`~~ | **removed in C18 (2026-05-24)** — chat tool routes through `/api/eval` directly |

---

## TestCase shape

From `runner.ts:4`:

```ts
interface TestCase {
  id: string             // "refund-no-receipt"
  prompt: string         // user message to the model
  expected: string       // human note — what good looks like
  files?: string[]       // optional context attachments
  assertions: string[]   // each judged independently
}
```

`assertions` is the load-bearing field. Each line is fed to the judge
verbatim. Vague assertions ("response is good") produce vague pass rates.
Crisp assertions ("declines refund and asks for receipt") produce signal.

---

## The lifecycle — walk-through

Skill: **`process-refund`** — the model handles refund requests for an
e-commerce site. We want it to refund within 30 days *with a receipt*,
decline beyond 30 days, and never auto-approve more than $200.

### 1. Author the skill

`skills/process-refund.md`:

```markdown
---
name: process-refund
description: Use when a customer asks for a refund. Apply 30-day window and $200 auto-approve cap.
---

# Process Refund

- If purchase ≤ 30 days AND receipt provided AND amount ≤ $200 → approve immediately.
- If purchase ≤ 30 days AND no receipt → ask politely for receipt.
- If purchase > 30 days → decline; offer store credit.
- If amount > $200 → escalate; never auto-approve.
- Tone: empathetic, one short paragraph, no legal jargon.
```

### 2. Author the test bank

`skills/process-refund/evals/evals.json`:

```json
[
  {
    "id": "refund-happy-path",
    "prompt": "Bought a $40 mug 5 days ago, here's the receipt R-882. Want to return it.",
    "expected": "Approves refund.",
    "assertions": [
      "Approves the refund",
      "References receipt R-882",
      "Tone is empathetic, no legal jargon"
    ]
  },
  {
    "id": "refund-no-receipt",
    "prompt": "Bought a candle last week, want my money back.",
    "expected": "Asks for receipt.",
    "assertions": [
      "Does not approve the refund yet",
      "Asks for the receipt or proof of purchase"
    ]
  },
  {
    "id": "refund-too-old",
    "prompt": "Got this jacket 3 months ago. Refund please.",
    "expected": "Declines, offers store credit.",
    "assertions": [
      "Declines the refund",
      "Offers store credit as alternative",
      "Does not promise a cash refund"
    ]
  },
  {
    "id": "refund-over-cap",
    "prompt": "Need to return a $450 espresso machine bought yesterday, receipt R-991.",
    "expected": "Escalates — does not auto-approve.",
    "assertions": [
      "Does NOT auto-approve the $450 refund",
      "Escalates to a human or supervisor",
      "Acknowledges the receipt"
    ]
  }
]
```

Both files land in R2 at `{slug}/skills/process-refund.md` and
`{slug}/skills/process-refund/evals/evals.json` — that's where the eval
endpoint reads them (`api/eval.ts:36-39`).

### 3. Trigger the eval

```bash
curl -X POST https://one.ie/api/eval \
  -H 'content-type: application/json' \
  -d '{"slug":"shop","skillPath":"process-refund","iteration":1}'
```

Or from inside `/chat`, the model can call the `eval` tool itself
(`api/chat.ts:143`) — same code path.

### 4. What runs (per case, in parallel)

```
TestCase ──┬──→ runCase(tc, skillMd)   ──→ withRun   ──→ gradeCase  ──→ withGrade
           └──→ runCase(tc, null)      ──→ withoutRun──→ gradeCase  ──→ withoutGrade
```

`runCase` (`runner.ts:19`) wraps the prompt with system text that *includes*
the skill body when ON, plain assistant when OFF. Same model
(`llama-3.3-70b-versatile`), same temperature, same 1024-token cap.

`gradeCase` (`grader.ts:27`) loops the assertions, asks the judge
`Does this output satisfy the assertion?` and counts YES vs total.

### 5. Aggregate → benchmark.json + mastery curve

`aggregate.ts:22` produces the per-iteration snapshot:

```json
{
  "skillName": "process-refund",
  "iteration": 1,
  "with_skill":    { "pass_rate": 0.83, "tokens": 312, "time": 1840 },
  "without_skill": { "pass_rate": 0.50, "tokens": 287, "time": 1620 },
  "delta":         { "pass_rate": 0.33, "tokens":  25, "time":  220 }
}
```

Stored at `{slug}/skills/_workspace/process-refund/iteration-1/benchmark.json`.

`mastery.ts` then loads all prior iterations from R2 and runs **Bayesian Knowledge Tracing**
(soft BKT — `pass_rate` is treated as P(correct), not hard-thresholded) to produce a
mastery curve across the skill's full history:

```json
{
  "prob": 0.34,
  "level": "novice",
  "sampleCount": 1,
  "curve": [
    { "iteration": 1, "passRate": 0.83, "prob": 0.34, "level": "novice" }
  ],
  "improving": false
}
```

The full API response is `{ benchmark, mastery, iterationPrompt }`.

**Why BKT and not just pass_rate?** A single iteration at 0.83 could be noise (small
test bank, lucky judge). BKT accumulates evidence across iterations — the mastery
probability rises as the skill consistently performs, and stays low if it only passes
once. After four strong iterations the curve reads `proficient`; after eight it reaches
`mastered`. **The curve is the signal; the snapshot is just one data point.**

BKT parameters (Corbett & Anderson 1994 defaults):

| Parameter | Value | Meaning |
| --- | --- | --- |
| `pL0` | 0.10 | Prior P(mastered) before any evidence |
| `pT`  | 0.20 | P(unmastered → mastered per successful iteration) |
| `pG`  | 0.25 | P(pass despite unmastered — lucky run) |
| `pS`  | 0.10 | P(fail despite mastered — slip) |

Mastery levels derived from `prob`:

| Level | prob | Meaning |
| --- | --- | --- |
| `novice` | < 0.40 | Not yet reliable |
| `developing` | 0.40–0.60 | Showing signal, needs more evidence |
| `proficient` | 0.60–0.80 | Consistently performing |
| `mastered` | ≥ 0.80 | Reliable across iterations — safe to ship |

**How to read this:**

| Number | Meaning | Healthy |
| --- | --- | --- |
| `with_skill.pass_rate` | Skill ON, fraction of assertions judged YES | → 1.0 |
| `delta.pass_rate` | Lift from skill | > 0; if ≤ 0, skill is noise |
| `delta.tokens` | Cost of carrying the skill in context | small + positive ok |
| `delta.time` | Latency overhead | ms — usually trivial |

Iteration 1 here: skill helps (+33% pass), but `with_skill` is 0.83 — a
case is failing.

### 6. Iterate on failures

Endpoint returns `iterationPrompt` when any case has `passed < total`
(`iterate.ts:10`):

```
The skill below failed these test cases. Propose the minimal diff to fix them.

```markdown
{first 800 chars of skill}
```

### refund-over-cap
Prompt: Need to return a $450 espresso machine bought yesterday, receipt R-991.
Expected: Escalates — does not auto-approve.
Actual (truncated): Sure! I've processed your refund of $450 to the original card...
Failed: ✗ Does NOT auto-approve the $450 refund; ✗ Escalates to a human
```

Author (or LLM) takes that prompt, edits `process-refund.md` — maybe the
$200 cap rule was buried below the happy-path bullets, so the model
skipped it. Re-order:

```diff
+ - **Hard rule:** if amount > $200 → escalate, never auto-approve. Check this FIRST.
  - If purchase ≤ 30 days AND receipt provided AND amount ≤ $200 → approve immediately.
```

### 7. Re-run as iteration 2

```bash
curl -X POST https://one.ie/api/eval \
  -d '{"slug":"shop","skillPath":"process-refund","iteration":2}'
```

New benchmark at `iteration-2/benchmark.json`:

```json
"with_skill":    { "pass_rate": 1.00, "tokens": 318, "time": 1880 },
"delta":         { "pass_rate": 0.50, "tokens":  31, "time":  240 }
```

And the mastery response now reflects two iterations of evidence:

```json
{
  "prob": 0.58,
  "level": "developing",
  "sampleCount": 2,
  "curve": [
    { "iteration": 1, "passRate": 0.83, "prob": 0.34, "level": "novice" },
    { "iteration": 2, "passRate": 1.00, "prob": 0.58, "level": "developing" }
  ],
  "improving": true
}
```

All four cases pass and `improving: true`. Keep iterating until `level` reaches
`mastered` (prob ≥ 0.80, typically 4–6 consistent iterations). Skill ships at `mastered`.

### 8. Close the loop on the substrate

This is where evaluate plugs into Rule 1 (closed loop) and the pheromone
system. The eval result is itself a signal — the runtime should:

```ts
if (benchmark.delta.pass_rate > 0.05) one.mark(`skill:${name}`, 1)
else                                  one.warn(`skill:${name}`, 1)
```

Skills with positive delta strengthen the path that routed work to them.
Skills with zero or negative delta accumulate resistance and stop being
selected by `select()`/`follow()`. The substrate **forgets bad skills
without anyone deleting them** — Loop L3 (fade) does the cleanup.

---

## The shape of "done"

A skill is shippable when **iteration N** satisfies all of:

1. `with_skill.pass_rate == 1.0` (or your project's gate, e.g. ≥ 0.85)
2. `delta.pass_rate > 0` — skill measurably helps
3. `delta.tokens` is in budget — adding the skill body to every prompt
   has to earn its keep
4. `mastery.level == 'mastered'` (prob ≥ 0.80) — consistent across iterations, not a one-off
5. Two consecutive iterations show no regression

The mastery gate (4) is the new hard requirement. A skill that passes once at 1.0 is
not the same as a skill that passes consistently. BKT only reaches `mastered` after
sustained evidence — it cannot be gamed by a single lucky run.

Then the path `route → process-refund` is a highway (`one.highways()`),
and Loop L6 (knowledge) can promote it to a hypothesis: *"refund
requests under $200 with receipt, ≤30 days → auto-approve works."*

---

## Eval surfaces — where users see the loop

The same eval engine (`/api/eval`) feeds three surfaces:

| Surface | Where | What it shows |
|---|---|---|
| **Dashboard row** | `/u/{slug}/skills` — `SkillRow` mastery chip | `●unrun` · `●novice` · `●developing` · `●proficient` · `●mastered`. Click chip → detail page `#eval` |
| **Detail page panel** | `/u/{slug}/skills/{name}#eval` — `SkillEvalPanel` | Mastery sparkline + latest benchmark `<EvalCard>` + iteration table + `Run eval now`. Drafts hidden (defaults to `includeDraft: false`) |
| **Chat surface** | Anywhere with the chat tool — `EvalCard` rendered inline | The model can call `eval` then `write` to iterate within the same turn |
| **Studio (planned, C12 + C16)** | `/u/{slug}/skills/{name}/edit` — Tests tab + "Run eval on draft" button | Author tests + run against unsaved body via `draftContent`/`draftEvals` |

---

## The /chat self-evaluation loop

The same machinery runs *inside* the chat surface. The model has the
`eval` tool (`api/chat.ts:143`). A user can say:

> "Eval the process-refund skill, iteration 3."

The model calls `eval` → gets the benchmark + iterationPrompt → if there
are failures, it can call `write` to commit a new skill version, then
`eval` again at iteration 4. **The agent evolves its own skills**, and
every cycle leaves a benchmark.json receipt in R2.

This is Loop L5 (evolution) wired to the skill substrate, not to agent
prompts — same shape, different target.

---

## Don't

- Don't write fuzzy assertions ("response is helpful"). The judge is an
  LLM; vague in → vague out.
- Don't grade with the same model that generated. `runner.ts` and
  `grader.ts` both use `llama-3.3-70b-versatile` today — fine for delta
  measurement, but be skeptical of absolute pass rates. Swap the judge
  for a stronger model when stakes rise.
- Don't ship a skill on a single iteration's numbers — small `n` (4
  cases here) means high variance. Run again before you trust it.
- Don't conflate `pass_rate` with truth. The judge can be wrong.
  Spot-check failed assertions manually before iterating.
- Don't put eval results in `git` — they live in R2 under
  `_workspace/`, regenerated cheaply on demand.

---

*Skill ON vs skill OFF. Same model, same prompts, same judge. The delta
is the only fact. Everything else is opinion.*
