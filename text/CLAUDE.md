# CLAUDE.md — `text/`

Marketing copy lives here. Headlines, taglines, hero sections, feature
blurbs, CTAs. Anything that needs to persuade or convert.

## How to work in this folder

**Always invoke the `writer` skill** when writing or editing anything in
this directory. It is our craft layer — the full method for drafting,
cutting, structuring, and polishing prose. Defined at
[`.claude/skills/writer/SKILL.md`](../.claude/skills/writer/SKILL.md).

**On top of that, the ONE voice contract** lives at
[`.claude/product-marketing.md`](../.claude/product-marketing.md):

- Audience: CEOs / C-level + engineers reading the same page
- Voice: very simple English; depth shown through brevity, not jargon
- Banned vocabulary, sentence rules, headline patterns

The split:
- `writer` skill = **how to write well** (craft, structure, cutting)
- `product-marketing.md` = **how ONE sounds** (voice, audience, banned words)

Read both before any non-trivial copy work.

Trigger phrases that auto-invoke `writer`:
- "write copy for…" · "improve this copy" · "rewrite this page"
- "headline / subheadline / tagline help"
- "make this more compelling" · "tighten this" · "polish this"

The older `copywriting` skill is still installed as a fallback specialist
for conversion-page frameworks (hero / proof / objection-handling
templates). Prefer `writer` for everything else.

## Files

| File | Purpose |
|------|---------|
| `contents.md` | Working draft of brand / agency / chatbots / models surface copy |

## See also

- Root `CLAUDE.md` — repo context
- `web/agent-authoring.md` — how copy maps onto studio pages
