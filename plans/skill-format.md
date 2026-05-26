---
lifecycle: stable
status: source-of-truth
last-updated: 2026-05-24
---

# skill-format.md — the substrate

**A skill is a single markdown file with YAML frontmatter. Tests live in `evals:`. Evaluate by POSTing it to `/api/eval`. That is the whole substrate.**

Every surface (web Studio, CLI, MCP, Claude Code, raw HTTP, your bash script) reads and writes this shape. No shared client library. No published package coordinates the schema. The schema is *this document*.

---

## The file

```yaml
---
name: refund-policy            # slug, [a-z0-9-]+, matches directory name
title: Refund Policy           # optional, human display
version: 1.0.0                 # optional semver
description: |                 # routing trigger (≤1024 chars) — what & when
  Use this skill when a customer asks for a refund. Apply the 30-day window
  and the $200 auto-approve cap.
price: 0.02                    # USD per call; 0 = free
tags: [policy, refund]         # optional
license: Apache-2.0            # optional
ref: https://…/SKILL.md        # optional; if set, `Refresh` pulls from here
trigger: semantic              # optional; "semantic" | "explicit"

evals:                         # test cases live here — NOT in a sidecar file
  - prompt: Bought a $40 mug 5 days ago, here's receipt R-882. Want to return.
    assertions:
      - Approves the refund
      - References receipt R-882
      - Tone is empathetic
  - prompt: Mug broke after 18 months, no receipt.
    assertions:
      - Declines politely
      - Suggests store credit
      - Does not mention auto-approve

# optional, rarely used:
inputSchema:  {}               # JSON schema for structured input
outputSchema: {}               # JSON schema for structured output
scripts:  []                   # file paths under scripts/
references: []                 # file paths under references/
assets: []                     # file paths under assets/
---

# Refund Policy

If purchase ≤ 30 days AND receipt provided AND amount ≤ $200 → approve.
If purchase ≤ 30 days AND no receipt → ask politely for receipt.
If purchase > 30 days → decline; offer store credit.
If amount > $200 → escalate; never auto-approve.

Tone: empathetic, one short paragraph, no legal jargon.
```

That's the whole skill. **One file.** No `evals/evals.json` sidecar. No `scripts/` directory unless you actually have scripts. Keep the body under ~500 lines / ~5000 tokens.

---

## The endpoint

```http
POST /api/eval
Authorization: Bearer <token>      # or session cookie
Content-Type: application/json

{
  "slug":         "<workspace>",
  "skillPath":   "<skill-name>",
  "iteration":    1,
  "draftContent": "<full SKILL.md>",   // optional — bypasses R2 read
  "draftEvals":   [...TestCase[]]      // optional — bypasses evals: in frontmatter
}
```

Returns:

```json
{
  "benchmark": {
    "skillName": "refund-policy",
    "iteration": 1,
    "with_skill":    { "pass_rate": 0.92, "tokens": 412, "time": 1832 },
    "without_skill": { "pass_rate": 0.50, "tokens": 380, "time": 1521 },
    "delta":         { "pass_rate": 0.42, "tokens":  32, "time":  311 }
  },
  "mastery": {
    "prob":        0.58,
    "level":       "developing",
    "sampleCount": 1,
    "curve":       [...],
    "improving":   true
  },
  "iterationPrompt": "…"   // optional — present when failures exist
}
```

Mastery `level`: `novice` (prob < 0.40) · `developing` (0.40–0.60) · `proficient` (0.60–0.80) · `mastered` (≥ 0.80). Detail: [`evaluate.md`](evaluate.md).

---

## How each surface uses it

### Web Studio (browser)

`/u/{slug}/skills/{name}/edit` already does this. `SkillProposalCard` (chat-led) or direct edit → `PUT /api/skills/[name]/save` → R2. "Evaluate" button → `POST /api/eval`.

### CLI

```bash
# the whole thing
oneie skill eval ./my-skill.md
```

```ts
// cli/src/skill.ts — ~15 LOC
cmd.command('eval <path>').action(async (path) => {
  const content = readFileSync(path, 'utf8')
  const { meta } = parseYaml(content.match(/^---\n([\s\S]*?)\n---/)?.[1] ?? '')
  const evals = Array.isArray(meta.evals) ? meta.evals : []
  const res = await fetch(`${baseUrl}/api/eval`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ slug, skillPath: meta.name, draftContent: content, draftEvals: evals }),
  })
  console.log(await res.json())
})
```

### MCP (Claude Code)

```ts
// packages/mcp/src/index.ts — one new tool, ~30 LOC
{
  name: 'skill_eval',
  description: 'Evaluate a SKILL.md against its frontmatter `evals:` and return mastery.',
  inputSchema: { content: 'string' },
  handler: async ({ content }) => {
    const { meta } = parseYaml(content.match(/^---\n([\s\S]*?)\n---/)?.[1] ?? '')
    const r = await fetch(`${BASE}/api/eval`, {
      method: 'POST', headers: { Authorization: `Bearer ${TOKEN}` },
      body: JSON.stringify({ slug, skillPath: meta.name, draftContent: content,
                              draftEvals: meta.evals ?? [] }),
    })
    return await r.json()
  }
}
```

Claude Code writes the file (its native job). Then calls `skill_eval` to measure it. Browser refresh shows the new file. No "live edit channel" infrastructure needed — the file IS the channel.

### Raw HTTP / your bash script

```bash
curl -X POST https://one.ie/api/eval \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -nR --arg c "$(cat my-skill.md)" '{slug:"me", skillPath:"x", draftContent:$c}')"
```

---

## What this format does NOT include

These were considered and rejected for v1. They live in `skills-scale-todo.md` for the "we have >10 skills per workspace" world.

| Feature | Why not in v1 |
|---|---|
| Sidecar `evals/evals.json` file | One file is simpler. `evals:` in frontmatter is the format. |
| `scripts/`, `references/`, `assets/` directories | Declared in frontmatter but no skill in our catalog uses them. Add when a real skill needs them. |
| Version history / rollback | `version:` field exists; storage of historical versions doesn't. Out of scope. |
| Marketplace publish metadata | Marketplace is a separate substrate. |
| Cross-workspace sharing | Permissions model is its own plan. |
| Skill rename | Would orphan R2 + D1 rows. Fork-and-redirect is the safe alternative. |
| `inputSchema` / `outputSchema` editor | Fields exist for future structured I/O; no UI yet. |

---

## The rule

**Markdown in, numbers out.** If a proposed change to the skill system doesn't preserve the property "any surface that can POST JSON can author and measure a skill," it's adding complexity that doesn't earn its place.

The schema is documented prose. Every surface speaks YAML + HTTP. There is no shared client library. There is no SDK coordination problem. There is no per-language drift, because every language has a YAML parser and an HTTP client.

That's the substrate.

---

## See also

- [`skills.md`](skills.md) — components, routes, architecture overview
- [`evaluate.md`](evaluate.md) — eval lifecycle, BKT mastery curve, worked example
- [`skills-todo.md`](skills-todo.md) — current plan + cycle status
- [`one.ie/agents/skill-creator/SKILL.md`](../one.ie/agents/skill-creator/SKILL.md) — methodology (the "how to author" prose)
