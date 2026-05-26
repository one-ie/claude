# 04-models — gap analysis

## Promise

`text/04-models.md` sells:

1. **Any model on OpenRouter** (300+) reachable by changing one `model:` field in agent markdown.
2. **Per-agent AND per-skill model binding** — skills can override agent default (Haiku for triage, Opus for one-shot review).
3. **Routing fallback chain** — `OpenRouter → Groq direct (when opted-in) → AI SDK Gateway → degraded mode (cached response or graceful error)`.
4. **BYOK** — workspace setting accepts Anthropic / OpenAI / Google keys; routing per-agent honours them; platform keys are encrypted env vars.
5. **Daily cost cap per agent and per workspace** with auto-topup or graceful "I'll follow up" fallback.
6. **Aliases** (`haiku-latest`) with platform-maintained version-pin map; 90-day deprecation notice.
7. **Eval gate before model swap** ships with every agent; pass/fail is a number.
8. **Credit accounting** — fixed table (Haiku 25/k, Sonnet 300/k, Opus 1,500/k, GPT-5 1,250/k, 5–8× output multiplier).
9. **`gateway('<model>')` in `ToolLoopAgent`** is the canonical wire pattern shown in the prose.
10. **Clients optionally see which model is running** via response metadata.

## Code reality

| Promise | Where it lives | Status |
|---|---|---|
| Agent `model:` field in markdown | `web/src/lib/agent-md.ts`, parsed by `claw/src/personas.ts` & `web/src/pages/api/chat.ts` | partial — claw reads it; **web chat.ts ignores it** |
| Skill-level model override | nowhere | **missing** — schema in `parseAgentMd` has no per-skill `model` field; no template uses it |
| OpenRouter default | `claw/src/middleware.ts` `resolveBaseModel` → `createOpenAICompatible(openrouter)`; `web/src/pages/api/showcase-chat.ts` | partial — only `claw` and `showcase-chat`; **`/api/chat` (the live owner chat) hard-codes Groq llama-3.3-70b-versatile** |
| Groq direct opt-in | `claw/middleware.ts` `if (modelId.startsWith('groq/')...)` | works in claw; in `/api/chat` Groq is the only primary, not an opt-in |
| AI SDK Gateway fallback | `claw/middleware.ts` final `return gateway(modelId)` only if `OPENROUTER_API_KEY` missing | exists in claw; **not a runtime fallback chain — it's an env-key-availability branch at startup** |
| Gemini Flash fallback (commit 05ca5164) | `web/src/pages/api/chat.ts` lines 974-1046 | works — peeks SSE for `"type":"error"`, swaps to `google/gemini-2.0-flash-001` via OpenRouter |
| Workers AI route for public demos | `web/src/pages/api/chat.ts` `makeWorkersAIResult` | works — Llama 3.3 70B fp8-fast on `@cf/meta/...` |
| Fallback chain order matches doc | doc says OpenRouter → Groq → Gateway → degraded; code does Groq → Gemini-Flash (web) OR OpenRouter→Gateway (claw) | **chain shape diverges** between surfaces; no degraded-mode cache |
| BYOK (workspace provider key) | none — env vars only (`OPENROUTER_API_KEY`, `GROQ_API_KEY`) | **missing** — no per-workspace key storage, no key-routing logic |
| Daily cost cap per agent / per workspace | `web/src/lib/billing.ts` `currentBalance` + `if (balance < -1000)` 402 | partial — single workspace floor at -1000 credits; **no per-agent cap, no auto-topup, no "I'll follow up" fallback** |
| Aliases (`haiku-latest`) | none | **missing** — agent files pin exact versions (`claude-sonnet-4-5`, `claude-sonnet-4-6`, `claude-haiku-4-5`) |
| 90-day deprecation map | none | **missing** |
| Eval gate before swap | `web/src/lib/eval/runner.ts` exists; exposed as `evalTool` in chat | infra present but **not wired to model-swap workflow**; no "swap-then-verify" command |
| Credit table (Haiku 25/k etc.) | `billing.ts` uses flat `toCredits(usd, 0.0001)` on `usage.totalTokens * 0.000002` | **missing** — single hardcoded $/token rate; doesn't read model-specific pricing from OpenRouter (`promptPrice`/`completionPrice` are fetched in `openrouter-models.ts` but ignored at billing time) |
| `gateway('model')` ToolLoopAgent | `claw/src/agents/builder.ts` uses `wrappedModel` (which can return `gateway()`) | works in claw; **`/api/chat` does not use `ToolLoopAgent` at all** — uses raw `streamText` |
| Model selector UI | `web/src/components/showcase/ShowcaseModelPicker.tsx` + `openrouter-models.ts` | works — fetches live OpenRouter catalogue, cached 1h in KV, used by `/showcase` only |
| Model picker in agent editor / settings | none | **missing** — owner agents have no UI to pick model; must hand-edit markdown |
| Per-conversation model override | `showcase-chat.ts` accepts `body.model` | works for showcase; `/api/chat` ignores `body.model` |
| Response metadata exposing model | none | **missing** — Workers AI / Groq / Gemini swap is invisible to the client |

## Gaps

1. **`/api/chat` ignores the `model:` frontmatter field.** Every owner-authored agent is force-routed to `groq/llama-3.3-70b-versatile` regardless of what their markdown declares. The promise "change one field, the agent switches" is false on the platform's main chat path. Only `claw` honours it.

2. **No skill-level model binding.** Doc shows `skills: [{name, model}]` overrides — not in the parser, not in any template, not in claw. The "Haiku for triage, Opus for review in one conversation" example does not exist in code.

3. **No BYOK.** Doc dedicates a section + objection-handling to bring-your-own-key. Code has only platform-wide env vars.

4. **Credit table is fiction.** Doc publishes a 4-row pricing table with specific per-model credit costs. `billing.ts` charges a flat `tokens × 0.000002 USD → credits` regardless of model. Haiku and Opus burn identical credits per token.

5. **Fallback chain does not match the diagram.** Doc: OpenRouter → Groq → Gateway → degraded. Reality:
   - `claw`: env-key branch (Groq if prefix + key, else OpenRouter, else Gateway) — *no runtime fallback*.
   - `web/api/chat`: Groq → Gemini Flash (via OpenRouter) — *Groq is the primary, not the fallback*.
   - No degraded mode anywhere; no cached-last-response, no graceful "I'll follow up".

6. **No model aliases or deprecation map.** Agent files pin exact versions and will break on provider deprecation.

7. **No daily cost caps per agent / per workspace.** Only a single global floor at -1000 credits per workspace. Auto-topup and per-agent caps are doc-only.

8. **Model picker is showcase-only.** Owners cannot pick a model in the agent editor; must hand-edit YAML. The doc's "one field" claim is a markdown edit, not a UI.

9. **Eval-gate-before-swap is not a workflow.** `runCase`/`gradeCase` exist as a chat tool but there is no `/eval --model=X` workflow that runs the suite, scores, and offers a one-click swap.

10. **`ToolLoopAgent` + `gateway()` pattern is claw-only.** Doc's named integration snippet shows `new ToolLoopAgent({ model: gateway(...), ... })`. `/api/chat` uses raw `streamText` with provider-specific factories. The two main runtime paths diverge.

## Recommended improvements

**P0 — make the promise true on the main chat path:**

1. Wire `web/src/pages/api/chat.ts` to read `parsed.meta.model` and route through `resolveBaseModel`-style helper. Move `claw/src/middleware.ts:resolveBaseModel` to a shared `web/src/lib/model-router.ts` and import from both surfaces. Owners' `model:` field becomes load-bearing.

2. Implement the documented 4-step fallback chain in shared `model-router.ts`: try primary → on error try secondary (Gemini Flash as today) → try `gateway()` → return a structured `"I'll follow up"` SSE error frame. Same chain for claw and web.

3. Replace flat `toCredits(tokens * 0.000002)` with a per-model price table sourced from the cached OpenRouter `/models` response (`promptPrice`/`completionPrice` are already fetched in `openrouter-models.ts`). Burn input/output tokens at model-specific rates. Publish the table in `lib/billing.ts` so the doc and code stay in sync.

**P1 — fill the BYOK and cap stories:**

4. Add `provider_keys` D1 table keyed by workspace; encrypt at rest. In `resolveBaseModel`, check workspace-key before env-key. Surface a `/settings/providers` page where owners paste keys.

5. Add `agent_daily_cap_credits` and `workspace_daily_cap_credits` columns on `agents` and `owners`. Check in the billing gate before `streamText`. On cap hit, swap model to the cheapest in the chain and prepend a `[degraded: cap]` system note.

**P2 — close the UX gap:**

6. Reuse `ShowcaseModelPicker` in the agent-editor drawer. Wire `onChange` to `/api/agents/:id` PATCH with `{ frontmatter: 'model: <id>' }` — the `patch_agent` chat tool already exists.

7. Add per-skill `model?` field to `parseAgentMd` schema. In the tool-execution path, override the agent's model for that one tool call. Update the marketing director template to demonstrate.

8. Add an alias table: `aliases.json` mapping `haiku-latest → anthropic/claude-haiku-4-5`. Resolve at agent load. Ship a CLI `oneie model alias list` and a doc/code drift check that fails CI if the doc claims an alias that doesn't exist.

9. Add a `oneie agent eval --swap=<model>` command: runs existing `runCase`/`gradeCase` on the agent's evals, compares scores against current model, prints pass/fail and a diff. Block production swap if score drops > 5 points.

10. Surface the active model on every response: add `x-one-model` response header + a `model` field on assistant message metadata. Owners can opt clients in via a `expose_model: true` frontmatter flag.

## Files to touch

| Path | Change |
|---|---|
| `web/src/pages/api/chat.ts` | Replace hardcoded `groq('llama-3.3-70b-versatile')` with `resolveBaseModel(env, parsed.meta.model)`; reuse middleware fallback chain; drop bespoke Gemini-Flash peek path |
| `web/src/lib/model-router.ts` *(new)* | Extracted from `claw/src/middleware.ts`; single source of truth for `resolveBaseModel`, fallback chain, alias resolution, BYOK lookup |
| `claw/src/middleware.ts` | Import from shared `model-router.ts`; delete duplicated `resolveBaseModel`; keep `substrateMiddleware` |
| `web/src/lib/agent-md.ts` | Extend schema: `skills[].model?: string`, `expose_model?: boolean`, `daily_cap_credits?: number` |
| `web/src/lib/billing.ts` | Replace flat `toCredits` with `priceFromModel(modelId, tokens, kind)` reading from cached OR pricing; add per-agent and per-workspace cap check |
| `web/src/pages/api/openrouter-models.ts` | Already exists; expose a typed `getModelPricing(id)` helper for billing to import |
| `web/src/lib/aliases.json` *(new)* | `{ "haiku-latest": "anthropic/claude-haiku-4-5", ... }`; loaded at agent parse time |
| `web/src/components/agents/AgentEditor*.tsx` | Add `ShowcaseModelPicker` to the editor; wire to `patch_agent` |
| `web/src/pages/settings/providers.astro` *(new)* | BYOK paste-key UI; encrypted write to `provider_keys` D1 table |
| `web/migrations/00XX_provider_keys_and_caps.sql` *(new)* | `provider_keys`, `agent_daily_cap_credits`, `workspace_daily_cap_credits` |
| `cli/src/commands/agent.ts` | Add `eval --swap=<model>` subcommand reusing `web/src/lib/eval/*` |
| `agents/templates/marketing/director.md` | Demonstrate per-skill `model:` override |
| `text/04-models.md` | Trim Gemini-Flash from doc since fallback chain is being refactored; bring credit-table numbers in line with whatever `priceFromModel` actually computes |
