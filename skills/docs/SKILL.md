---
name: docs
description: Pick the right documentation type and write it with the right discipline. Use whenever creating or editing any file in text/ that documents a feature — a marketing promise (.md), feature spec (-features.md), UI spec (-ui.md), architecture (-plan.md), explanation (-docs.md), tutorial (-tutorial.md), how-to (-how-to.md), reference (-reference.md), or agent briefing (-agents-docs.md). Invoke this BEFORE writing to choose the type and load its rules; it works on top of the `writer` skill (craft) and the templates (shape). Triggers — "write the docs for X", "document this feature", "write a tutorial/how-to/reference/explanation", "what doc type is this", "split this doc", "this doc mixes concerns".
---

# docs — the documentation discipline

This skill is the **middle layer** of three. It does not write prose (that's the `writer` skill) and it does not hold the section skeleton (that's the `template-*.md` files). It does one thing the other two can't: **it knows the ONE doc taxonomy, picks the right type for the reader, and enforces the one rule that type lives or dies by.**

A generic writing skill can make any paragraph clearer. It cannot tell you that the paragraph doesn't belong in a `-reference.md` at all. That judgment is this skill.

**The order:** invoke `docs` (pick type + rules) → copy the matching `template-*.md` (shape) → invoke `writer` (craft the prose) → invoke `voice` (pick + apply the register) → check `.claude/product-marketing.md` (product context).

The full taxonomy lives in [`text/docs.md`](../../../text/docs.md); the template map in [`text/templates.md`](../../../text/templates.md). This skill is how you *apply* them.

---

## First: which type?

Every doc answers **one reader's one question at one moment.** Find the reader and the question; the type falls out.

| The reader's question | Type | File |
|---|---|---|
| "What is this, and why does anyone want it?" | story + contract (the root) | `<slug>.md` |
| "What does it do?" | features | `<slug>-features.md` |
| "What does it look like?" | ui | `<slug>-ui.md` |
| "How is it built?" | plan | `<slug>-plan.md` |
| "How does it work, and why?" | explanation | `<slug>-docs.md` |
| "How do I succeed the first time?" | tutorial | `<slug>-tutorial.md` |
| "How do I do X?" | how-to | `<slug>-how-to.md` |
| "What's the exact spec?" | reference | `<slug>-reference.md` |
| "What does an agent need to operate it?" | agent briefing | `<slug>-agents-docs.md` |

If a single file is trying to answer two of these, **it's the wrong file** — split it. A doc that mixes "how do I" steps with "why it works" theory serves neither reader.

**Don't over-create.** Most features need only `.md` + `-plan.md` + `-docs.md`. Reach for tutorial / how-to / reference only when the feature outgrows one explanation file.

---

## The four user docs are a grid

The user-facing types aren't a list — they're the four cells of [Diátaxis](https://diataxis.fr/), split by what the reader is *doing* (practical vs. theoretical) and where they *are* (learning vs. working):

```
                  PRACTICAL (doing)        THEORETICAL (knowing)
              ┌─────────────────────────┬─────────────────────────┐
 LEARNING     │  tutorial               │  explanation (-docs)    │
 (studying)   │  succeed first time     │  understand how & why   │
              ├─────────────────────────┼─────────────────────────┤
 WORKING      │  how-to                 │  reference              │
 (applying)   │  get this task done     │  look up the exact spec │
              └─────────────────────────┴─────────────────────────┘
```

The most common failure is mixing two cells in one doc. The grid is the cure: when a section feels off, name its cell. If it's a different cell than the doc, move it.

---

## The discipline per type

Each type has **one cardinal rule** — the thing it must never do. Break it and the type collapses into another.

### explanation (`-docs.md`) — understanding-oriented
Background, the mental model, the why. The page that makes every other page click.
- **Cardinal rule: no steps.** The moment you write "first… then…" you've drifted to tutorial/how-to.
- Tell: "therefore", "because", "the reason is", "this fits the system by…"
- Default for most features: this is the one doc you write. (Template `template-teach.md` makes it a complete guide — model + first win + runbook — when no split is needed.)

### tutorial (`-tutorial.md`) — learning-oriented
One complete story, beginning to a guaranteed success. The reader follows; the doc leads.
- **Cardinal rule: never fork on reader state.** No "if you have X, do Y." One path. If the reader's setup varies, that's a how-to, not a tutorial.
- Every command exact and verified. Show the expected output after each step. End on the win.
- It's about *learning by doing*, not about the task — the result can be a toy; the point is the reader's confidence.

### how-to (`-how-to.md`) — task-oriented
A practitioner who already knows the concept needs the steps for one real task.
- **Cardinal rule: no concept-explaining.** No teaching what a campaign is — link to `-docs.md`. Straight to the recipe.
- Title is a task: "How to…", "Running a…". Assumes competence. Numbered steps + a verify.

### reference (`-reference.md`) — information-oriented
Complete, precise, neutral. Field types, signal names, limits, defaults, error codes.
- **Cardinal rule: no opinions, no prose explanation.** If you're tempted to explain *why*, link to `-docs.md`. Reference states *what*.
- Structure mirrors the code's structure (a table per surface). Exhaustive over readable.

---

## The ONE-specific types

Not Diátaxis — but they obey the same "one reader, one question" law.

### story + contract (`<slug>.md`) — the root document
**The story is the top-level document.** It is the **first file** — everything else
derives from it and reconciles **upward** to it. It tells the thing in seven beats and
carries the contract those beats commit to: marketing copy on the surface, a story
underneath it, and a schedule of work underneath that.

The beats come first and the schedule answers them. `want` names what is wanted, `way`
names the mechanisms the deliverables compose, `turn` seeds the lifecycle. **A
`deliverables:` line that answers no beat is scope nobody asked for; a beat with no
deliverable is a story the contract does not keep.** That two-way check is the one thing
this merge buys, and it is why the `story:` block is no longer optional or last.

Register stays **commercial** here. The separate book-register file
(`template-story.md`, worked example `text/ants.md`) is a different artifact for when the
telling itself is the point, and it sells nothing — see `text/templates.md` § A promise's
`story:` field vs a standalone story.
- **Cardinal rule: every deliverable answers a beat.** Persuade, don't specify. Lead with what the persona gets (hire, sell, ship, earn). Drop internal words — `mark`/`warn`/`substrate`/`pheromone` belong nowhere near it (see `.claude/product-marketing.md`).
- This is the spec the `/do` PROVE stage checks shipped behavior against. Every claim must be true.
- **Frontmatter is the contract — four machine-read manifests, read like an agency SOW:** `deliverables:` (the exhaustive schedule of work — every item the client receives, each with its own `accept:` bash check; not listed = not promised, listed = ships or the promise settles broken, acceptance indivisible; `assumes:` alongside lists client-side dependencies, green at the making) + `proof:` (the acceptance test — **derived, not authored**: the `&&`-join of every `accept:`, verbatim; it becomes the todo `outcome:`, the TEST assertion, and the PROVE oracle) + `derives:` (the manifest of which files to spawn) + `world:` (the runtime the kept promise puts into the substrate — lifecycle moves + recording signals, workflow steps, agents + `subscribes:` tags, skills, task tags, tracking marks/warns, routing paths). The schedule ⇄ proof law is linted by `.claude/scripts/do-promise-lint.sh <slug>` — the PROMISE gate. Body must carry **"The deliverables (the schedule of work)"** (the SOW table + completeness clause) and **"Out of scope (excluded, in writing)"** (enumerated exclusions). **`derives:` is authoritative** for which conditional docs exist — this skill *confirms/refines* that choice, it does not override it. `/do` presence-checks every `world:` entry like an artifact: missing agent → a `template-agent.md` cycle (+ `subscriptions:register` for its tags) · missing skill → `/skill-creator` · missing workflow/lifecycle stage → a todo cycle · present → skip. Design: `text/promise-plan.md`.
- **Contract-backed form:** a promise uncomments the `contract:` block in `text/template-feature.md` and mints a generated Move Promise at PROMISE; `do-promise-settle.sh` settles it at close from the proof exit code. Worked example: `text/playbook.md`.
- Craft is `writer` + `copywriting`, not this skill — but `docs` keeps it from absorbing feature-spec detail (that's `-features.md`).

### features (`<slug>-features.md`) — the builder/PM
WHAT the feature does: capabilities, scope, use cases, and **non-goals**.
- **Cardinal rule: no implementation.** What it does, not how it's built (that's `-plan.md`).
- Non-goals are load-bearing — they're how scope stops creeping.

### ui (`<slug>-ui.md`) — the builder/designer
WHAT it looks like: screens, component states (empty · loading · error · success · edit), user flows.
- **Cardinal rule: no backend wiring.** Pair with the `frontend-design` skill for layout quality.

### plan (`<slug>-plan.md`) — the builder
HOW it's built: signals, TypeDB schema, the authority walk, the reuse verdict.
- **Cardinal rule: no selling and no user-facing "what it does"** — that's `.md` and `-features.md`.

### agent briefing (`<slug>-agents-docs.md`) — the agent
A dense, token-lean briefing for an AI agent that must *act*: the signal chain, schema types and their fields, receivers, authority (role → can), compact task recipes, and error → recovery-signal.
- **Cardinal rule: briefing, not background.** No essays, no motivation, no journey. Tables and signal chains. Optimized for tokens, not warmth.
- Verify every signal name, receiver, and field against the code (`packages/sdk/src/receivers.ts`, `schema/*.tql`) — invoke `sdk`/`typedb` for accuracy. A wrong signal name here breaks a real agent.

---

## How it composes with the other layers

1. **Pick the type** (this skill) — reader + question → type. If the content spans two types, split before writing.
2. **Copy the template** — the type → template map is the table in [`text/templates.md`](../../../text/templates.md); most types are `template-<type>.md`, with two exceptions worth knowing before you `cp` the wrong file: the **promise** copies `template-feature.md` for its frontmatter contract (`deliverables:`/`proof:`/`derives:`) — `template-promise.md` is a separate CRAFT template (the honesty-first + numbered-scorecard prose pattern), read alongside it, never copied in its place — and the **explanation** copies `template-teach.md` (there is no `template-docs.md`). The template is the shape; never write a doc-spine artifact from scratch.
3. **Write with `writer`** — apply the craft loop (cut, show-don't-tell, structure, sentence polish). This skill says *what goes where*; `writer` makes each sentence land.
4. **Check voice** — `.claude/product-marketing.md`: ONE's audience (CEOs + engineers), simple English, banned words. Run `bash .claude/scripts/do-reconcile.sh dictionary text/<file>.md` before committing (no dead names, no new synonyms) — the scripts are not on PATH.

---

## Self-check before shipping any doc

- [ ] **One reader, one question.** Name them. If you name two, split the file.
- [ ] **Cardinal rule held.** The type's one forbidden thing is absent (no steps in explanation, no fork in tutorial, no opinion in reference, no essay in agent briefing).
- [ ] **Right file name.** The suffix matches the type (`-docs` vs `-reference` vs `-how-to`).
- [ ] **No duplication across files.** If two docs say the same thing, one should link to the other.
- [ ] **Links resolve.** Cross-references to sibling docs and `file:line` anchors are real.
- [ ] **Facts verified.** For reference/agent-briefing, every name/signal/field checked against code.
- [ ] **Voice clean.** No banned words; dictionary reconcile passes.

---

## Common fixes

| Symptom | Fix |
|---|---|
| `-docs.md` has numbered steps | Move them to `-how-to.md` (a task) or `-tutorial.md` (a first run); keep only the why |
| `-tutorial.md` says "if you have X…" | It forks — either pick one path, or it's actually a how-to |
| `-reference.md` opens with a paragraph of context | Move the prose to `-docs.md`; reference is facts only |
| `.md` reads like a spec | Move the spec to `-features.md`; the `.md` tells the story and sells |
| `.md` has deliverables but no beats | Write the seven beats first. A schedule with no story is scope nobody asked for |
| A beat has no deliverable | Either deliver it, or move it to "Out of scope" in writing |
| `-agents-docs.md` reads like a guide | Cut the narration to tables + signal chains |
| One doc serves both a beginner and an expert | Split: tutorial for the beginner, reference for the expert |

---

*Taxonomy: [`text/docs.md`](../../../text/docs.md). Templates: [`text/templates.md`](../../../text/templates.md). Craft: `writer` skill. Register: `voice` skill → [`text/voice-and-tone.md`](../../../text/voice-and-tone.md) (senior) + [`text/writing-style-guide.md`](../../../text/writing-style-guide.md). Product context: [`.claude/product-marketing.md`](../../product-marketing.md).*
