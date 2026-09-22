---
slug: {{slug}}
written: {{YYYY-MM-DD}}
proven: true
audience: humans + agents
promise: text/{{slug}}.md
---

# {{Feature Name}}

> {{One line — the promise kept, in the reader's own words. This is the hook. Make them want the next sentence.}}

<!-- Spawned by the promise's derives.docs — authored at DOCS as the spec, validated at TEACH after PROVE passes, so every claim below ends proven, never planned. Reconciles upward to the promise (text/{{slug}}.md) — the spec this doc must match. -->

## Why this exists

{{2–4 sentences. The world *before* this feature — the friction, the wait, the thing that was hard or impossible. Name the pain the reader already feels, so everything after lands as relief. Plain English, no jargon. Earn the reader before you teach them.}}

## What you get

{{1–3 sentences. The capability in the reader's words — what they can do now that they couldn't before. This is the "after" to the "Why this exists" "before." One clean promise, no list of features.}}

## The mental model

{{The one idea that makes everything else obvious. One short paragraph — or the small diagram below. Hold this shape in your head and every step clicks. Great docs hand you the model first; weak docs make you reverse-engineer it from the steps. Use an analogy only if it is exact.}}

```
{{optional — a 3–6 line shape: the thing, what goes in, what comes out}}
```

## Your first win (60 seconds)

The shortest path to a working result. Copy, paste, watch it work — then you'll trust the rest.

```bash
# Copy-pasteable. Verified to work. The fastest route to a green result.
{{the one command — or 2–3 lines — that produce a visible win}}
```

You'll see {{the exact observable result: the line of output, the screen, the file that appears}}. That is the whole thing working. Everything below is depth, not prerequisite.

## The walkthrough

The full path, one step at a time. Each step says what you do, what you'll see, and why it matters — so you are never typing on faith.

### 1. {{Step name — start with a verb}}

{{What this step does and why, in 1–2 sentences.}}

```bash
{{command}}
```

{{What you see, and how you know it worked. Show the expected output — don't make the reader guess.}}

### 2. {{Step name}}

{{Repeat. Number every step. Show the result after each. Call out the one place readers slip — inline, right before they would hit it, not in a footnote.}}

### 3. {{Step name}}

{{The final step lands the reader exactly at the goal from "What you get." Close the loop out loud: "You now have {{the outcome}}."}}

## Reference

Everything you'll look up later, scannable at a glance. **Agents: this is the contract** — exact names, paths, signatures, no prose required.

| Thing | What it is | Where |
|---|---|---|
| {{name}} | {{one line}} | {{`file:line` or link}} |
| {{command / flag}} | {{what it does}} | {{usage}} |
| Script | {{what it runs}} | `.claude/scripts/{{script}}.sh` |

---

## Runbook

### Verify it's working

The proof command from PROVE, reusable as a health check. Green here means the feature is live.

```bash
{{the proof command}}
# Expected: {{the exact passing output}}
```

### When something breaks

| You see | It means | Do this |
|---|---|---|
| {{symptom}} | {{cause}} | {{the exact fix — a command, not advice}} |

### Rollback

{{The exact way back. Specific commands, in order. The reader is stressed when they reach this section — be precise, be calm, be complete. Leave nothing to infer.}}

## Where to go next

{{1–3 pointers: the adjacent feature, the deeper doc, the thing this unlocks. Leave the reader knowing which door to open next.}}

<!--
TEACH template — the doc that brings humans AND agents on a journey.

VOICE — friendly · authoritative · clear · succinct · complete:
- Talk to one reader. "You", never "the user." Warm, never chatty.
- Authoritative = you have done this and it works. Show, don't hedge. No "should probably", no "might."
- Succinct = every sentence earns its place. Cut adverbs. Depth through brevity — see .claude/product-marketing.md.
- Complete = no step assumed, no command untested, no output unshown. A reader holding ONLY this doc can succeed.
- Plain English. A CEO and an engineer read the same words. Banned-jargon list lives in .claude/product-marketing.md.

THE JOURNEY — why → what → model → first win → walkthrough → reference → runbook → next:
- Motivation before mechanics. The reader must WANT it before they learn it.
- Model before steps. Give the shape; the steps then click into it.
- A win before the depth. One fast success buys patience for everything after.
- Every command copy-pasteable and verified. Every step shows its expected output.
- Two audiences, one doc: humans read the prose top-to-bottom for the journey; agents jump to Reference + Runbook for the contract. Serve both — narrative for the journey, tables for the lookup. Never make a human scan a table for motivation, or an agent read prose for a path.

STOP RULES (from do.md):
- Write AFTER PROVE passes (proven: true in frontmatter). Proven behavior only — never planned.
- Match the promise: every user-facing claim appears in text/{{slug}}.md.
- Doc + runbook in one file. Presence check: test -f text/{{slug}}-docs.md.
- Run do-reconcile.sh dictionary on this file before committing (no dead names, no new synonyms).
- Draft with the `tutorial` skill, tighten with the `writer` skill.
-->
