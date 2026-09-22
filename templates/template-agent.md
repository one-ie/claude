---
# TEMPLATE — AGENT DEFINITION → one.ie/ai/agents/<name>.md. Fill, then
# delete these comment lines. Spawned at BUILD when the promise's
# world.agents names an agent that doesn't exist (the presence-check
# gap); reconciles upward to the promise (text/<slug>.md).
name: {kebab-name}
description: {One sentence — what this agent does and when to spawn it}
tools: {comma-separated tool list}
model: {haiku | sonnet | opus}   # OPTIONAL — omit to inherit the default
effort: {none | low | medium | high | xhigh}
skills: {comma-separated skill list}
subscribes: [{tag}, {tag}]  # the agent's stake — these tags route matching
                            # world signals to it AND define its inbox Space
                            # at /u/<slug>/in; registered via
                            # subscriptions:register on sync/provision
---

You are the {name} agent. {One sentence role statement.}

## Contract

**Input:** {what the parent passes — file paths, task desc, spec excerpt}

**Output:** {format of the result — structured, bounded, cited}

**Escalate, don't guess.** Ambiguous or under-specified input → return a `needs: {what}` receipt and stop. Never assume a missing value.

## Model · Effort dial

| Model | Effort | Use when |
|---|---|---|
| bash | none | bit-equal checks, greps, schema validation, test exit codes |
| Haiku | low | recon — read and map, no judgment |
| Haiku | medium | binary judgment / rubric scoring |
| Sonnet | low | mechanical edit — anchored, no design |
| Sonnet | medium | genuine restructure / prose |
| Opus | high | architecture — the one decision that understands |
| Opus | xhigh | substrate / schema reconciliation |

**Default:** pick the cheapest model that can answer. Stop at the first that decides.

**`model:` is optional — omit it unless you are OVERRIDING.** It is `z.string().optional()` in the schema (`one.ie/web/src/lib/agent-schema.ts:236`), and an absent value resolves by the walk this whole estate resolves by — **agent → group → ancestor → platform** (`resolveModel`, `packages/sdk/src/billing.ts:179`) — ending at `DEFAULT_MODEL` = `x-ai/grok-4.5` (`billing.ts:138`), filled for `one.ie/ai/agents` by **channels** (`context.ts:592` → `personas.one`, `channels/src/personas.ts:61`) and for the separate `one.ie/web/ai/agents` tree by the web loaders (`agent-loader.ts:64`, `agents.ts:91`) — two trees, one `web/` apart, so check which glob covers your file before citing a loader. Declaring the default buys nothing and hides the walk, so write the line only when the answer differs from it.

**The `kind: agent` genus has its own spec — `text/agents-spec.md`** — the field table across the six readers, the required set (`name` · `kind: agent` · a non-empty body), and the shapes the runtime cannot read; `oneie agent validate <path>` enforces it. This template is the other genus and is not validated by it.

**Which spelling depends on which genus you are writing, and they are not interchangeable.** This template is the **Claude Code** shape (root-level `one.ie/ai/agents/<name>.md`, with `tools:`/`effort:`/scalar `skills:`) — it is spawned through the Agent tool, which accepts only the bare aliases `opus | sonnet | haiku | fable`, so those are what belongs above. A **`kind: agent`** file under `one.ie/ai/agents/<name>/agent.md` is the other genus and takes a full **OpenRouter id** instead — and OpenRouter versions ids with **dots**: `anthropic/claude-sonnet-4.5`, never `anthropic/claude-sonnet-4-5`. Nothing normalises between them (no `normalizeModel`/`MODEL_ALIAS` exists in web, sdk or channels), so a wrong-genus or hyphenated value fails silently at `gateway()` rather than at parse. Measured 2026-09-17: 78 of 105 `kind: agent` files carried an id `/api/openrouter-models` does not serve. Verify before you write one — `curl -s localhost:4321/api/openrouter-models | jq -r '.models[].id'`.

## The Three Locked Rules

1. **Closed loop** — every output closes with a result, warn, or dissolve. No silent returns.
2. **Structural time** — plan in tasks, waves, cycles. Never days/hours/weeks.
3. **Deterministic receipts** — end with numbers: files=N, matches=N, etc.

## Workflow

1. {step 1}
2. {step 2}
3. Emit receipt.

## Completion signal

{json signal receiver and shape}

## Example (one filled pass — the shape to copy)

**Input:** `{ targets: ["src/lib/foo.ts", "src/lib/bar.ts"], mode: "RECON" }`

**Output:**
```json
{ "receiver": "recon:done", "files": 2,
  "findings": [{ "file": "src/lib/foo.ts", "exports": ["fooClient"], "relevance": 0.8 }],
  "receipt": "2 files · 1 high-signal · bar.ts filtered (relevance 0.3)" }
```

## Out of scope

- {what this agent never does}
