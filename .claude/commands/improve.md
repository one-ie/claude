# /improve

Close the feedback loop opened by `stop-reflect.sh` and `session-start.sh`. Reads `.claude/improvements.queue.md`, presents each proposal, promotes accepted ones to the right target.

The hooks open the loop. This command closes it.

---

## Loop

1. Read `.claude/improvements.queue.md`. Empty → emit `improve:none`, exit.
2. Parse: each `## YYYY-MM-DDTHH:MM:SSZ` header begins a session block; each `- **kind** ...` line is one proposal.
3. For each proposal (oldest first, batched by session):
   - Show the proposal verbatim
   - Ask the user: **apply** / **defer** / **drop**
4. On **apply**:
   - Detect target file from the proposal text (table below)
   - Apply the change via Edit (or surface the diff if it needs human anchoring)
   - Move the proposal to `.claude/improvements.archive.md` with footer `→ applied {target}:{line} {YYYY-MM-DD}`
5. On **defer**: skip; line stays in the queue for next pass.
6. On **drop**: move to archive with footer `→ dropped {YYYY-MM-DD} (reason)`.

---

## Target resolution

Proposals come in three kinds (set by `stop-reflect.sh`):

| Proposal kind | Detection | Target |
|---|---|---|
| `**convention**` | `\.claude/(rules\|skills\|agents)/...` or `CLAUDE\.md` in path | the named file — promote the rule into its body |
| `**new primitive**` | `\.claude/(skills\|rules\|agents\|hooks)/[^/]+\.(md\|sh)` | the index in `one-ie/.claude/CLAUDE.md` — add a one-line entry |
| `**doc-drift**` | `<subdir>/CLAUDE.md` named | that CLAUDE.md — surface a 3-line summary of the most impactful code changes and ask the user which (if any) belong in the contract |

If detection fails, the user is asked: "which file should this update?" Free-text answer accepted.

---

## Examples

**Convention proposal:**
```
- **convention** `.claude/rules/api.md` — review: did this change introduce a rule the broader team should know?
```
→ `apply` opens `.claude/rules/api.md`, asks user for the rule text (one sentence), appends to the closest section.

**New primitive proposal:**
```
- **new primitive** `.claude/skills/perf.md` — add a one-line entry to the index.
```
→ `apply` opens `one-ie/.claude/CLAUDE.md`, finds the skills index, appends `| /perf | ...` row.

**Doc-drift proposal:**
```
- **doc-drift** `agents/CLAUDE.md` not updated despite 5 file changes under `^agents/src/`. Review.
```
→ `apply` runs `git log --oneline -5 -- agents/src/` (or `find agents/src -mtime -7`), summarises the 5 changes, and asks: "Does `agents/CLAUDE.md` need any of these reflected? If yes, paste the line(s) to add." User pastes; command Edits.

---

## Closed-loop signal

```json
{
  "receiver": "improve:session:ok",
  "data": {
    "tags": ["improve"],
    "weight": 1,
    "content": {
      "applied": N,
      "deferred": M,
      "dropped": K,
      "archive_lines_added": APPLIED + DROPPED
    }
  }
}
```

`applied > 0` → also emit one `mark` per `target_file` so the substrate learns which docs absorb improvement signal most often.

---

## Out of scope

- Auto-applying without user review. The queue is a candidate list, not a worklist.
- Editing user-scoped memory (`~/.claude/projects/.../memory/`). That's manual.
- Pulling in changes from anywhere except `.claude/improvements.queue.md`.

---

## When to run

- After 3+ proposals accumulate (the `session-start.sh` banner will say so).
- Before any significant refactor — clearing the queue first prevents stale proposals against old code.
- After a quarterly skill / CLAUDE.md audit — surface what's accumulated.

---

*Stop-reflect writes. Session-start surfaces. Improve closes. The path remembers what the system learned about itself.*
