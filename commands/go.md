# /go — the standing "yes"

One word for everything the operator types over and over: **fill the gaps · do it · yessssss · continue · merge and deploy · fan out.**

`/go` means: you already have consent. Stop narrating options, stop asking, move.

---

## Modes

| Invocation | Meaning |
|---|---|
| `/go` | Resolve state and advance NOW (one push, this turn) |
| `/go on [max] [mission…]` | Arm auto-continue — the Stop hook re-prompts you until done |
| `/go off` | Disarm auto-continue |
| `/go status` | Report flag state + continuation count |
| `/go <slug>` | `/go` scoped to one todo slug (= consent for its whole arc) |

---

## `/go` (no args) — the advance algorithm

Work the first matching rung, then close with numbers:

1. **In-flight work exists** (uncommitted changes, failing test you just saw, half-done todo cycle) → finish it. A failed command is a step, not a stop: diagnose, fix, retry.
2. **Work is done and green** (tsc + tests + kill-switch pass) → close the loop without being asked:
   - `git branch --show-current` FIRST (shared-tree law), commit by explicit path
   - merge to main, `/deploy`, verify live (real request, not "file exists")
3. **Idle** → read `todo.md`, take the top unblocked slug, run `/do <slug>`.
4. **Multiple independent, file-disjoint items** → fan out: spawn parallel agents in ONE message (or `do-fleet.sh --slots N --go` for whole waves).

"Fill the gaps" = before building, presence-check the promise's `deliverables:`/`world:` manifests and the plan's artifacts — missing → write, stale → rewrite, true → skip. That is the /do lifecycle; `/go` just skips the part where you wait for permission.

### What /go does NOT consent to

Still ask, even under /go:

- destructive/irreversible actions (data deletion, prod schema drops, force-push)
- spending money beyond already-established rails
- genuine scope changes (new promise, killing a feature)
- publishing to external surfaces not already in the task's arc

Everything else — edits, tests, commits on the right branch, merge, deploy, fan-out — is pre-approved.

## `/go on [max] [mission…]`

Write the flag file the Stop hook (`hooks/auto-continue.sh`) reads:

```bash
printf 'max=%s\n%s' "${max:-12}" "${mission:+mission=$mission}" > .claude/auto-continue.local
```

Then behave as `/go` (advance now — the hook keeps you advancing on every stop until done or budget spent). Budget is per-session; counter lives in `/tmp/oneie-auto-continue-<session>.count`.

## `/go off`

```bash
rm -f .claude/auto-continue.local
```

## `/go status`

Report: flag present? max? mission? current count from the /tmp counter. One line.

---

## Numeric close

Every `/go` invocation ends with a countable line:

```
/go closed: rung=<1|2|3|4> actions=<n> merged=<0|1> deployed=<0|1> next=<slug|none>
```

`/go on|off|status` close with: `auto-continue=<on|off> max=<n> count=<n>`.
