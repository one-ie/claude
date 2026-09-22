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
tail -5 text/learnings.md

# Recent cycle diff (what actually changed)
git diff HEAD~1 HEAD --stat
git diff HEAD~1 HEAD -- $(git diff HEAD~1 HEAD --name-only | grep -v 'text/' | head -20)
```

**Step 2 — Extract the pattern (Haiku · low)**

From the diff + learnings entry, identify:
- What recurring problem this cycle solved
- The specific shape of the solution (code pattern, file layout, command sequence)
- When it applies (trigger condition)
- When it doesn't (anti-patterns / exclusions)

Ignore one-off specifics (feature names, slugs). Keep the reusable skeleton.

**Step 3 — Write `.claude/skills/<slug>/SKILL.md`**

The path is `.claude/skills/<slug>/SKILL.md` — a **directory** containing
`SKILL.md`. A bare `.claude/skills/<slug>.md` is not loaded by the runtime
(several flat files there — `build.md`, `typecheck.md`, `dev.md`, `signal.md`,
`cloudflare.md`, the `rag-*.md` set — exist as canon but never trigger as skills).

The YAML frontmatter is **load-bearing, not decoration**: `name` and
`description` are what the runtime matches against to decide whether to surface
the skill. A SKILL.md with no frontmatter never triggers. Put the trigger phrases
in `description` — the `## When to use` body section is read only *after* the
skill has already been selected.

Use this template:

```markdown
---
name: <slug>
description: <what this does, then the trigger conditions — "Use when …". Include the literal phrases a user would type. This field is the whole triggering surface.>
---

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

- Auto-loading comes from the frontmatter `description`, not from any index —
  get the trigger phrases into that field or the skill stays dark.
- Then add the name to the `skills/` line in `.claude/CLAUDE.md` § Structure so
  the harness inventory stays true. That listing is documentation of what exists;
  it does not itself wire anything.
- If it extends an existing skill, note the relation.

**Step 5 — Close**

Append one line to `text/learnings.md`. That line **is** the close — it is
deterministic and it is what the next cycle reads.

Do **not** emit `learning:harden` or `learning:know`. Neither is a registered
receiver: `grep -c '"learning:' packages/sdk/src/receivers.ts` → **0**. The
earlier version of this step instructed `signal("learning:know", { skill })`,
which fails silently — the same defect its own warning described, one line
down. The whole `learning:` namespace is unregistered; `harden`'s only shipped
wire is `chat:harden`, which needs a threadable `entityId` and does not fit a
skill close.

If you want the creation recorded in the substrate, `skill:save` is real
(`packages/sdk/src/receivers.ts`). Check the receiver exists before emitting —
the signature is `signal(receiver, data)`, and there is no three-argument form.

The line:

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
`text/learnings.md`, signal emitted, session stop-reflect will pick it up as
a new primitive on the next session start.
