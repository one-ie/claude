# 05-agents — gap analysis

## Promise

`text/05-agents.md` — "An agent is a markdown file. Edit the file, redeploy in seconds, and the agency owns the IP."

Specific claims, in order:

1. **One file, seven fields**: name, model, skills (priced), sensitivity, journey, theme, ui. System prompt is the body. 30 lines = "complete, deployable sales agent."
2. **Studio page**: every agent renders at `/studio/[agent]` via ten section primitives (stat / card / grid / list / compare / cta / embed / code / timeline / hotel). Section `ask` buttons seed the chat.
3. **Learning**: pheromone deposits on every call; **highway after 50 successful signals** (LLM routing 1500ms → KV 10ms); **L5 evolution** rewrites system prompt when success rate < 0.50 over 20 calls; new generation deploys without engineer.
4. **Quality gate**: every deploy runs **3-prompt eval against rubric fit/form/truth/taste, composite ≥ 0.65** — fails block the `draft → live` transition; failing prompt returned as chat reply.
5. **Versioning**: 20 versions retained per agent; `oneie agent rollback --to <ts>`; rollback re-validates archived content.
6. **Signing**: `oneie agent sign` produces tamper-evident bundle (Sigstore implied); `oneie agent verify` checks signature; "agency publishing IP it can defend."
7. **CLI lifecycle**: `agent new/validate/lint/compile/serve/publish/pull/unpublish/sign/verify/eval/diff/dev/list/history/rollback/ai-edit/fork/templates`.
8. **Round-trip**: `pull` downloads live agent; account manager edits without engineer; "six minutes" loop.
9. **Compile targets**: `--target uagents | mcp | skill | web` — one source, four runtimes. Python uAgents file is "clean, documented, production-ready for Agentverse."
10. **Per-agent voice / animation / hero / starters / quickReplies / send-icon / typewriter** — every chat surface is text in frontmatter.
11. **Two consumers, one file** (per `agents/CLAUDE.md`): SDK reads → TypeDB unit + skills; AI SDK v6 reads → `ToolLoopAgent.instructions` + `tool({ needsApproval: price > 0 })`. Substrate middleware auto-closes the loop via `finishReason`+`usage` → `mark`/`warn`.

## Code reality

### Strong (matches promise)

- **Single-file frontmatter contract**: `web/agent-authoring.md` documents every field. `web/src/lib/agent-schema.ts` + `web/src/lib/agent-md.ts` parse it; `parseAgentMd` is the single source.
- **CLI surface coverage**: `cli/src/agent.ts` (~770 lines) implements `new`, `validate`, `lint`, `compile`, `serve`, `publish`, `pull`, `unpublish`, `sign`, `verify`, `eval`, `diff`, `dev`, `list`, `history`, `rollback`, `ai-edit`, `templates`, `fork`. Verb breadth matches promise.
- **Publish + versioning**: `web/src/pages/api/agents/publish.ts` writes `{slug}/agents/{name}.md` + archives `v{ts}.md`, prunes >20. `history.ts` lists; `rollback.ts` restores. Real, end-to-end. Per-plan publish limit honored (`parseBilling`, 402 on cap hit).
- **Round-trip + per-key tokens**: GET + DELETE on the same publish route; `agent-auth.ts` supports `slug:token` Bearer (CLI flow).
- **MCP coverage**: `mcp/src/tools/lifecycle.ts` exposes `publish_agent`, `pull_agent`, `unpublish_agent`, `list_agents`, `agent_history`, `rollback_agent`, `discover_skill`, `list_skills`. Mirrors CLI verb-for-verb.
- **AI SDK v6 builder**: `claw/src/agents/builder.ts` (~80 lines) builds `ToolLoopAgent` from a `Persona`; substrate + skill + composio tool layers compose; `stepCountIs` honors `persona.maxSteps`. Real and lean.
- **Studio page is markdown-driven**: `web/src/pages/studio/[agent].astro` renders journey + pills + sections + theme + ui from `loadAgent(id, slug)`; partner-overridable `chat`/`sidebar` layout; locale override via `i18n` block.
- **Analytics depth**: `web/src/pages/api/agents/[id]/{analytics,acquisition,engagement,retention,revenue,trace,paths,tool-calls,generations,stage-timing,audience,actor-events,chats,lifecycle}.ts` plus JSON/CSV/Parquet exports. The visitor-funnel + agent telemetry surface is substantially richer than the marketing text describes.
- **`agent dev`** — fs watch + structural revalidate; matches the "edit, redeploy in seconds" promise.
- **`agent ai-edit`** — Claude-driven natural-language edits with diff preview. Not in the text but extends the promise correctly.
- **Templates**: `agents/templates/` ships `sales-discovery.md`, `support-tier1.md`, `marketing-strategist.md`, `code-reviewer.md`, `ceo.md`, `travel-planner.md`, plus `marketing/*` and `community/*` (5 + 3 group templates).

### Weak / partial (does not match promise)

- **The 3-prompt eval gate is a stub.** `web/src/pages/api/agents/[id]/deploy.ts` `runEval()` performs three checks: (1) has `system_prompt` field, (2) has `capabilities` or `skills` field, (3) `system_prompt` > 20 words. There is **no LLM call, no rubric scoring, no fit/form/truth/taste composite, no 0.65 threshold**. The text claims "the quality rubric scores fit, form, truth, and taste. The composite must clear 0.65" — that does not exist in the deploy gate.
- **`oneie agent eval` is keyword-match.** `cli/src/agent.ts` lines 184-241: local mode does `promptBody.includes(expect)`. Remote mode calls `/api/chat` and does `response.includes(expect)`. No rubric, no LLM-judge, no scoring. `web/agent-authoring.md` even calls it out: *"`agent eval` real implementation. The CLI command stubs to 0/0/0 today."*
- **L5 evolution (auto prompt rewriting) is absent.** No code in `claw/src/*.ts`, `web/src/lib/*.ts`, or the API routes runs prompt rewriting on `success_rate < 0.50 over 20 calls`. The text promises "Loop 5 fires. It reads the failure signals... rewrites the system prompt to lead with pain discovery." No such loop ships. `claw/src/substrate.ts` references `generation 0` for new agents but nothing increments it.
- **Highway-after-50-signals is a TypeDB claim, not measured in the agent path.** Substrate has `mark`/`warn`/`fade`/`follow` and the worker middleware auto-deposits pheromone. But the specific "50 successful signals → KV-cached highway, 1500ms → 10ms routing" measurement is not wired per-agent — there is no per-agent "highway state" surface in `web/src/pages/api/agents/[id]/`.
- **Signing is a placeholder.** `cli/src/agent.ts` `sign` returns `{ ok: true, bundle: 'pending — run oneie publish to trigger Sigstore' }`. `verify` returns `{ verified: existsSync ? 1 : 0, signatures: 0 }`. No actual Sigstore wiring, no real signature on disk, no verifier downstream. The "tamper-evident, marketplace dynamic" pitch is not backed by code today.
- **Compile target `uagents`** in the CLI returns the source file wrapped in a comment header (`'# Python uAgents output — run oneie-py for full compile\n' + content`). The real compile lives in `python/oneie/agent.py` and only builds Pydantic models from `skills/*.md` `inputSchema` blocks and includes them as uAgents `Protocol`s. It does **not** convert the agent body to a working uAgents script (no `agent.on_message`, no `agent.on_interval`, no handlers). The CLI compile is a placeholder; the Python loader is a partial runtime that requires sibling `skills/<name>.md` files with JSON Schema in frontmatter — those don't exist in any of the templates shipped in `agents/templates/`.
- **`agent serve`** prints `{ ok: true, port, status: 'listening' }` and exits. Does not start any server. The "Run agent as local A2A + MCP server on port 8000" is fictional.
- **`compile --target mcp`** returns `{ tools: [] }`. Compile-to-mcp doesn't actually convert skills to MCP tool definitions.
- **`compile --target skill`** is not handled at all (`compileTarget()` falls through to returning `content`). The "compiles to SKILL.md for AI assistant injection" promise has no implementation path.
- **Wallet / agents.md integration absent from agent.md.** `agents/CLAUDE.md` mentions optional `wallet` (Sui address) field; the schema (`agent-schema.ts`) and the CLI validator do not consume it. The four-pattern peer architecture from root `agents.md` (co-sign / scoped / capability / peer) has **no surface** in the agent markdown: no field declares which pattern an agent uses, no `daily_cap`, no `allowed_recipients`, no `spawn_child` policy. The Move integration described in `agents.md` is entirely external to the agent file the marketing copy treats as the "complete definition."
- **Two-consumer claim is partially true.** `claw/src/agents/builder.ts` reads a `Persona`, not an arbitrary `agent.md` from R2. `claw/src/personas.ts` ships two hardcoded personas (`one`, `concierge`). The "edit the file, redeploy in seconds, claw picks up the new prompt" loop is not wired to R2 — claw reads either built-in personas or KV-stored skill tools. The web side (`/api/chat` + `/studio/[agent]`) does read R2 and hot-pick the markdown; claw (the worker doing Telegram / Discord / API) does not.
- **`skills:` semantics drift.** In `text/05-agents.md` examples (and `sales-discovery.md`), `skills:` is a list of objects `{ name, description, price, tags }` — inline definitions. In `agents/CLAUDE.md` and the schema, `skills:` is a list of refs by id (`[draft-email, headline-variants]`) to standalone `skills/<id>.md` files. The frontmatter parser accepts both shapes (defensive), but downstream consumers treat them differently: paid-skill gating + Composio map work on string IDs; the studio page renders inline `{ name, price, description }` blocks. Two contracts under one field name.
- **No multi-channel "same agent answers Telegram + Discord + web from the same markdown."** `text/05-agents.md` cross-refs Chatbots page 03 for this; in code, `claw` (the worker that owns Telegram/Discord) does not load `agents/<name>.md` per request. The agent file's `channels:` field is documented but not enforced as a routing hint.
- **Plan classifier (`mode: lean | full | mixed`, four priors) referenced in root CLAUDE.md** is absent from any `agent.md` template — agents do not declare their build mode, despite the substrate-wide convention.

### Missing entirely

- **Marketplace surface** ("agency that signs its agents is publishing IP it can defend… a reseller can check whether the version matches"): no signed-agent registry, no signature index, no public verifier endpoint, no "buy/install agent from another agency" flow.
- **Agent journey funnel telemetry per-stage actually feeding L5.** Stages emit telemetry (`stage-timing.ts`); nothing reads those numbers to fire prompt evolution.
- **`oneie agent unpublish` is in the CLI but the studio loader does not garbage-collect cached state when an agent is removed.**
- **Workspace-scoped skill registry** — listed as a known roadmap gap in `web/agent-authoring.md`.
- **Custom section kinds** — known roadmap gap.

## Gaps

| # | Gap | Severity | What the text promises | What ships |
|---|-----|----------|------------------------|------------|
| G1 | 3-prompt eval gate has no LLM rubric | high | "rubric scores fit/form/truth/taste, composite ≥ 0.65, blocks draft→live" | three structural field checks |
| G2 | `oneie agent eval` is keyword-match | high | "the same eval harness `/api/chat` uses for skill grading" | `includes(expect)` |
| G3 | L5 evolution does not run | high | "Loop 5 fires… rewrites the system prompt… success climbs to 0.75" | not implemented |
| G4 | Sigstore signing is a placeholder | high | "tamper-evident… marketplace dynamic… verify what the agency delivered" | `{bundle: 'pending'}` |
| G5 | `compile --target uagents/mcp/skill` are stubs | high | "one source, four runtimes" | CLI returns commented source; mcp returns `{tools:[]}`; skill unhandled |
| G6 | `agent serve` does nothing | medium | "Run agent as local A2A + MCP server on port 8000" | prints `status: listening`, exits |
| G7 | Claw does not hot-load agent.md from R2 | high | "edit the file, redeploy in seconds" (Telegram/Discord) | claw uses hardcoded `personas.ts` |
| G8 | Wallet / 4-patterns not declarable in frontmatter | medium | text 05 says agency owns full agent IP; root `agents.md` is the wallet authority story | `wallet` field documented, not consumed by schema or CLI |
| G9 | `skills:` field has two contracts | medium | text examples show inline `{name,price,tags}`; CLAUDE.md says refs to `skills/*.md` | parser accepts both; downstream differs |
| G10 | Per-agent highway state not surfaced | low | "50 successful signals → KV-cached highway, 10ms routing" | no `/api/agents/[id]/highway` endpoint |
| G11 | No marketplace / signed-agent registry | low | "agency publishing IP it can defend" | absent |
| G12 | Python uAgents compile is partial | medium | "clean, documented, production-ready" Python | requires sibling `skills/*.md` with JSON Schema; no handlers generated |
| G13 | `agent ai-edit` not documented in `text/05-agents.md` | low (positive) | n/a | exists in CLI |
| G14 | Multi-channel routing per agent absent | medium | implied by chatbots cross-ref | `channels:` field documented, not enforced |

## Recommended improvements

In rough cost order (smallest first), each closing one gap. Numbers are task counts, not days.

### Lean (3 tasks each)

1. **G6 — kill `agent serve` or make it real.** Either remove the verb, or wire it to spin up a local Hono server that loads the markdown and routes `POST /ask` through `ToolLoopAgent` — the builder already exists in `claw/src/agents/builder.ts`. Two-file change: `cli/src/agent.ts` + a new `cli/src/serve-local.ts`.
2. **G13 — document `agent ai-edit`** in `text/05-agents.md` § Editing-without-redeploying as a CLI shortcut. One paragraph.
3. **G9 — unify the `skills:` field.** Pick one shape (inline objects, since that's what the public-facing copy shows), update `web/src/lib/agent-schema.ts` to canonicalize on parse, deprecate the string-id form with a `lint` warning. Update `agents/CLAUDE.md` and `web/agent-authoring.md` to match.
4. **G14 — make `channels:` route in claw.** Read `channels: [telegram, discord, web]` from the published markdown; reject inbound when the channel isn't listed. ~30 lines in `claw/src/index.ts`.

### Mixed

5. **G2 + G1 — real eval + rubric.** Replace `runEval` in `web/src/pages/api/agents/[id]/deploy.ts` with a 3-prompt LLM-judge against the rubric from `one/rubrics.md`. The composite already exists as a doc; needs (a) 3 prompts to score fit/form/truth/taste, (b) a judge model call (default `claude-haiku-4-5`), (c) composite math with 0.65 gate. ~150 lines.  Mirror it in `cli/src/agent.ts agent eval` so local and remote produce the same number.
6. **G5 — make `compile --target` produce real artifacts.**  
   - `mcp`: walk `skills[]`, emit a JSON tool definition per skill with `inputSchema` derived from `tags` or skill body — even a simple `{name, description, inputSchema: {type:'object'}}` shape unblocks downstream wiring.  
   - `skill`: write a `SKILL.md` with `description: <body first line>` + `triggers: <tags>` + the prompt body — matches the existing skill format in `.claude/skills/*`.  
   - `uagents`: emit a Python script that imports `oneie.agent.Agent`, instantiates with the markdown path, and calls `.run()` — matches what `python/oneie/cli.py` already does. Three small templates in `cli/src/compile-targets.ts`.
7. **G12 — finish the Python runtime.** In `python/oneie/agent.py`, add an `@agent.on_message` handler that routes incoming messages to an `OpenRouterClient` (`python/oneie/openrouter.py` already exists) with the body as system prompt. Without this, `oneie run agent.md` builds Protocols that never receive messages.

### Full (recon-first)

8. **G7 — hot-load agents in claw from R2.** Today `claw/src/personas.ts` ships two built-ins. Build a `loadAgentFromR2(slug, name)` that mirrors `web/src/lib/agent-loader.ts`, cache in KV (60s TTL), wire to `builder.ts` so `makeAgent(env, await loadAgent(slug, name), group, userId)` produces a per-request agent. This is the load-bearing fix — it's what the "edit, redeploy, Telegram replies update" promise rests on.  
   Recon: confirm KV size budget, confirm builder accepts dynamic prompts, confirm Telegram/Discord adapters can pass `slug` + `agentId` per inbound.
9. **G3 — L5 evolution loop.** New `web/src/lib/agent-evolve.ts`: query `agent_events` (last 20 signals for skill X), compute success rate, if < 0.50 call judge LLM with failure pattern + current prompt, write candidate prompt as a new version (R2 archive), set `pending_eval` flag, run eval gate, on pass auto-publish + bump `generation`. Cron via Workers Triggers, hourly per workspace.  
   Recon: confirm agent_events has skill-level success/fail, confirm CRON-able, decide promotion policy (auto-publish vs draft-for-review).
10. **G4 — real Sigstore signing.** Use `@sigstore/sign` (Node) in the CLI; emit `agent.md.sig` next to the file. Add `web/src/pages/api/agents/verify.ts` that calls `@sigstore/verify`. Index signed agents in D1 (`signed_agents` table) for the eventual marketplace.  
   Recon: confirm Sigstore works without a CI OIDC token (it doesn't — needs an `--oidc-token` flow); decide between Sigstore-keyless (requires GitHub Actions context) vs an Ed25519 long-lived key (simpler, fits the existing keypair story in `agents.md`).
11. **G8 — wire `wallet` + 4-patterns into the agent file.** Extend the schema with `wallet: { pattern: 'co-sign' | 'scoped' | 'capability' | 'peer', daily_cap?: USD, allowed_recipients?: address[], expires_at?: iso8601 }`. CLI `validate` checks consistency. Publish API persists to D1 `agent_wallet`. Studio page renders a "Wallet · scoped · $50/day cap" card. This is the bridge between `text/05-agents.md` and `agents.md` (root).
12. **G11 — public agent registry / marketplace.** Out of scope for the gap-closing pass; design doc only. The signing work (G4) is the prerequisite.

## Files to touch

### Closing the eval/rubric gap (G1, G2)
- `/Users/toc/Server/one-ie/one/web/src/pages/api/agents/[id]/deploy.ts` — replace `runEval` with LLM-judge rubric
- `/Users/toc/Server/one-ie/one/web/src/lib/agent-eval.ts` — new: judge prompt + scoring math
- `/Users/toc/Server/one-ie/one/cli/src/agent.ts` — `eval` command: call same judge via API
- `/Users/toc/Server/one-ie/one/one/rubrics.md` — promote to authoritative scoring spec

### Closing the compile gap (G5, G12)
- `/Users/toc/Server/one-ie/one/cli/src/agent.ts` — `compileTarget` fan-out
- `/Users/toc/Server/one-ie/one/cli/src/compile-targets.ts` — new: mcp / skill / uagents emitters
- `/Users/toc/Server/one-ie/one/python/oneie/agent.py` — add `on_message` LLM handler
- `/Users/toc/Server/one-ie/one/python/oneie/openrouter.py` — already exists; wire in

### Closing the hot-reload gap (G7)
- `/Users/toc/Server/one-ie/one/claw/src/personas.ts` — replace with dynamic loader
- `/Users/toc/Server/one-ie/one/claw/src/agents/loader.ts` — new: R2 + KV cache mirror of `web/src/lib/agent-loader.ts`
- `/Users/toc/Server/one-ie/one/claw/src/agents/builder.ts` — accept dynamic persona
- `/Users/toc/Server/one-ie/one/claw/src/channels.ts` — pass slug + agentId per inbound

### Closing the L5 gap (G3)
- `/Users/toc/Server/one-ie/one/web/src/lib/agent-evolve.ts` — new
- `/Users/toc/Server/one-ie/one/web/src/pages/api/cron/evolve.ts` — new (Workers cron trigger)
- `/Users/toc/Server/one-ie/one/web/wrangler.jsonc` — add cron trigger
- `/Users/toc/Server/one-ie/one/web/src/lib/db/agent_events.ts` — query helpers if missing

### Closing the signing gap (G4)
- `/Users/toc/Server/one-ie/one/cli/src/agent.ts` — real `sign` + `verify`
- `/Users/toc/Server/one-ie/one/cli/package.json` — add `@sigstore/sign` (or `@noble/ed25519` for the simpler path)
- `/Users/toc/Server/one-ie/one/web/src/pages/api/agents/verify.ts` — new
- `/Users/toc/Server/one-ie/one/web/migrations/NNNN_signed_agents.sql` — new

### Closing the wallet/4-patterns gap (G8)
- `/Users/toc/Server/one-ie/one/web/src/lib/agent-schema.ts` — `wallet` block
- `/Users/toc/Server/one-ie/one/cli/src/agent.ts` — validate wallet shape
- `/Users/toc/Server/one-ie/one/web/src/pages/api/agents/publish.ts` — persist wallet config
- `/Users/toc/Server/one-ie/one/web/src/components/journey/SectionRenderer.astro` — render wallet card
- `/Users/toc/Server/one-ie/one/agents/templates/sales-discovery.md` + peers — add wallet examples
- `/Users/toc/Server/one-ie/one/agents/CLAUDE.md` + `/Users/toc/Server/one-ie/one/web/agent-authoring.md` — document

### Doc reconciliation
- `/Users/toc/Server/one-ie/one/text/05-agents.md` — soften L5 / rubric / signing claims to "shipped" vs "roadmap" until G1–G4 land; add `ai-edit` paragraph
- `/Users/toc/Server/one-ie/one/web/agent-authoring.md` — already lists roadmap gaps; cross-link to this file
- `/Users/toc/Server/one-ie/one/agents/CLAUDE.md` — pick one shape for `skills:` and document
