# /do --show mode

Loaded by `do.md` when plan frontmatter has `show: true` or `--show` flag is passed.
Default behavior for `/do <plan> --auto` on show-plans. The loop runs every cycle without
intervention; pauses at each cycle close to render a cycle frame. Press Ctrl-C to stop;
otherwise auto-continues to the next cycle.

---

## The cycle frame format

```
╭──────────────── C{n} / {plan-slug} / {cycle-name} ────────────────╮
│  ✓ Cycle {n} of {N} complete                       rubric: 0.XX  │
│                                                                   │
│  Wave gates (W0 → W4)                                             │
│  ───────────────                                                  │
│    W0  bun run verify          ✓  {pass}/{total}                  │
│    W1  recon                   ✓  {N} files ({hits} cache hits)   │
│    W2  decide                  ✓  {decisions} decisions  ⬇ {Z} new │
│    W3  edit (parallel)         ✓  {marked}/{dissolved-retried}    │
│    W4  verify (scoped)         ✓  +{Δ} tests, biome+tsc clean     │
│                                                                   │
│  Rubric                                                           │
│  ───────                                                          │
│    security {0.XX}  stability {0.XX}  simplicity {0.XX}  speed {0.XX} │
│    composite {0.XX}    ✓ above 0.65 gate                          │
│                                                                   │
│  Speed                                                            │
│  ─────                                                            │
│    {metric}  {value}  (target {budget} {✓|✗})                     │
│                                                                   │
│  What this unlocks                                                │
│  ─────────────────                                                │
│    👤 customer  {one sentence — what a human can now do}          │
│    🤖 agent     {one sentence — what an agent can now do}         │
│                                                                   │
│  Lifecycle  [✓] {stage 1}  →  [✓] ...  →  [ ] {next stage}        │
│                                                                   │
│  Next: C{n+1} — {next cycle name + one-line preview}              │
│                                                                   │
│  Continuing in --auto... (Ctrl-C to stop)                         │
╰───────────────────────────────────────────────────────────────────╯
```

After the final cycle, render a **lifecycle replay**: a short narrative walking the
customer + agent through every stage the build now supports, in order.

---

## What goes in each section

| Section | Source | Rule |
|---|---|---|
| Wave gates | telemetry from each wave's logger | one line per wave, ✓/✗ + one number; W2 also shows `⬇ Z new` (new primitives through compress check) |
| Rubric | W4 markDims output | four numbers + composite + gate-pass |
| Speed | `/api/speed` budgets for this cycle | only metrics this cycle changed |
| What unlocks | plan's `lifecycle_show` frontmatter block | two sentences — customer + agent |
| Lifecycle | plan's `lifecycle: [stages]` frontmatter | checkbox row, ✓ done / [ ] pending |
| Next | next unchecked cycle + first task | one line; if last cycle, render lifecycle replay |

---

## Frontmatter required for show mode

```yaml
show: true
lifecycle: [stage-1, stage-2, stage-3, stage-4, stage-5]
lifecycle_show:
  C1:
    customer: "{one sentence — concrete user, concrete action}"
    agent: "{one sentence — concrete agent, concrete capability}"
    unlocks_stage: "stage-1"
  C2:
    customer: "..."
    agent: "..."
    unlocks_stage: "stage-2"
```

If `show: true` but no `lifecycle_show` block: render frame with `(no lifecycle narration)` and warn.

---

## Self-correcting hook

Each frame emits `ui:do:show:rendered { cycle, rubric, lifecycle_stage }`.
Ctrl-C'd frames → `warn(0.5)` on the cycle's tag — a rendered frame that's stopped is a
signal something looked wrong. Future cycles with similar tags raise their
security/stability bar at W2.
