# /skill-create — crystallise a cycle's learnings into a reusable skill

Run after a `/do` cycle closes (or any meaningful session). Reads the recent git
diff and the last `learnings.md` entry, then drafts a `SKILL.md` under
`.claude/skills/<slug>/` — so the pattern compounds instead of evaporating.

---

## When to invoke

- After `/do` closes a cycle and `learnings.md` has a new entry
- When you notice a pattern being repeated across sessions
- Explicitly: `/skill-create [slug]`

If `[slug]` is omitted, derive it from the most recent `learnings.md` entry
(the slug of the last `/do` cycle).

---

## What it does

**Step 1 — Gather raw material (zero LLM)**

```bash
# Last learnings entry
tail -5 plans/learnings.md

# Recent cycle diff (what actually changed)
git diff HEAD~1 HEAD --stat
git diff HEAD~1 HEAD -- $(git diff HEAD~1 HEAD --name-only | grep -v 'plans/\|text/' | head -20)
```

**Step 2 — Extract the pattern (Haiku · low)**

From the diff + learnings entry, identify:
- What recurring problem this cycle solved
- The specific shape of the solution (code pattern, file layout, command sequence)
- When it applies (trigger condition)
- When it doesn't (anti-patterns / exclusions)

Ignore one-off specifics (feature names, slugs). Keep the reusable skeleton.

**Step 3 — Write `.claude/skills/<slug>/SKILL.md`**

Use this template:

```markdown
# <title> skill

<one-sentence description — what this skill does for the model>

## When to use
<trigger phrase or condition that should invoke this skill>

## Pattern
<the reusable shape — code snippet, command, or process>

## Don't
- <anti-pattern 1>
- <anti-pattern 2>

## Example
<minimal concrete example>
```

**Step 4 — Wire it (if applicable)**

- If the skill has a natural trigger phrase, append a row to the skills table in
  `.claude/CLAUDE.md` so it auto-loads.
- If it extends an existing skill, note the relation.

**Step 5 — Close**

Emit `signal("learning:harden", 1, "skill=<slug>")` and append one line to
`plans/learnings.md`:

```
- YYYY-MM-DD · skill:<slug> · crystallised from <source-slug> · source=skill-create
```

---

## Rules

- **Extract, don't invent.** The pattern must be in the diff or learnings entry — no
  generalising beyond what the cycle actually did.
- **One skill = one pattern.** If the cycle contains two independent patterns, create
  two skills.
- **Lean.** A skill that fits in 30 lines is more likely to be read than one that
  doesn't. Cut examples to the minimum that makes the pattern clear.
- **No cycle-specific names.** Slug and title describe the pattern, not the feature
  that spawned it (`worktree-isolation`, not `do-auto-fix`).

---

## Close

After writing the skill file: `[ ] skill-create:<slug> done` appended to
`plans/learnings.md`, signal emitted, session stop-reflect will pick it up as
a new primitive on the next session start.
