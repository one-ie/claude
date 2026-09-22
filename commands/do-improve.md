# /do --improve

Invoked directly (`/do-improve`); `do.md` has no `--improve` row in Step 0.
Runs meta-improvement on do.md itself when drift signals accumulate.

---

## Signal source (checks in order, first hit wins)

1. `signals.jsonl` — read `loop:drift:*` entries if file exists (none on disk today)
2. `text/learnings.md` — read all `drift:` entries (polling fallback)

Group by wave+dim+tag_combo. For each group with count ≥ 2, run a one-cycle
meta-improvement plan on `do.md`:

---

## The improvement cycle

**W1:** recon the drifting wave section (Haiku — what does the current instruction say?)

**W2:** decide a targeted edit to the agent prompt for that wave.
  W2 edit scope (hard limit): may only propose edits to agent instruction text
  (what agents are told to do, how to format output, what to read).
  **Never propose changes to:**
  - Gate thresholds (composite ≥ 0.65, severity > 0.5, relevance < 0.4 — these are numeric gate controls)
  - Escape conditions (zero-findings guard, max W4 loops = 3, double-anchor-miss halt)
  - The invariant list itself
  If in doubt: if the proposed change alters a number that controls when the loop stops or passes, it is forbidden. Escalate to user.

**Snapshot:** Before W3 spawns, record current do.md content in session dict `improve_snapshot`.

**W3:** edit do.md (anchor pre-validated first, within W2 scope constraints).

**W4:** adversarial verify — check these invariants are preserved:
  - never skip W2
  - always spawn W1+W3 in a single message
  - gate thresholds unchanged (0.65 / 0.5 / 0.4 values must appear verbatim)
  - relevance threshold unchanged (< 0.4 must appear verbatim)
  - escape conditions unchanged
  - W2 scope constraint present and unmodified
  **Threshold disguise check:** scan diff for protected values (0.65, 0.5, 0.4, 3) in control-flow or gate logic. Values in informational prose are fine; flag only if inside a conditional or gate definition.

---

## Outcomes

- **W4 pass:** mark drift entries `resolved` in learnings.md.
- **W4 fail:** restore `improve_snapshot`, log `improve: rollback`. Retry once — W2 re-reads W4 failure report, produces revised proposal; W3 applies; W4 re-verifies.
- **W4 fails on retry:** restore snapshot, escalate to user. Do not retry again.
- **W4 fails twice total:** escalate. Loop cannot self-fix this pattern.
