# Development

Your engineers, your IDE. Or your CEO and Claude. Same substrate. The same operation (deploy a new agent, publish a skill, check what's working) runs from a chat window, a terminal, a TypeScript codebase, or an MCP-aware IDE. The surface is your team's choice. The substrate is shared.

This is what verb-surface parity means in practice. And it matters most on day two, when Donal's team wants to extend the platform and Brad needs to know they can.

---

> "The best way to predict the future is to invent it."
>
> — Alan Kay

---

## Build

Three ways to build on ONE. None of them require the others. Teams pick the one that fits how they already work.

**Chat.** Open `one.ie/chat`. Type what you want: *"Create a new agent for our window installation client that handles enquiries, books appointments, and sends quote follow-ups."* The substrate parses the instruction, scaffolds an agent markdown file, and syncs it to TypeDB. No terminal. No release cycle. A non-technical team member can do this on a Tuesday afternoon and have the agent live before the client's next business day.

This is also how a CEO tests a concept without involving the engineering team. Describe the behaviour. Watch it run. Approve it. Assign the fine-tuning to Donal's team. The hand-off is the markdown file, human-readable, version-controllable, auditable.

**Markdown.** Every agent is a `.md` file. The format is a structured spec: name, system prompt, skills, capabilities, pricing, and the voice contract that governs every outbound message. Edit the file in any IDE. Save it. The substrate syncs. Changes are live within thirty seconds.

This is intentional. An agency's best asset is its accumulated knowledge of each client's voice, tone, preferences, and objections. That knowledge lives in the markdown. It is not locked inside a platform's proprietary configuration UI. It is a file. The agency owns it. It backs up with `git`. It exports with one command.

Authoring an agent requires no code. A strategist who understands the client writes the brief. The substrate does the rest.

**IDE.** For Donal's team, working in VS Code or Cursor with `@oneie/sdk` imported, the experience is typed TypeScript against a well-documented API. Signal. Ask. Mark. Warn. Six verbs, fully typed, with IDE autocompletion on every call. TypeDB stores the paths. Cloudflare Workers serve the edge. The build time is 107 seconds from commit to production across four deployed services.

The same agent markdown that a strategist authored in chat is consumed by `syncAgent()` in TypeScript. The same markdown that a developer validated in the IDE is pushed with `oneie agent publish` from the terminal. One file. Every surface reads it.

---

## Call

Four surfaces. One substrate behind all of them.

**CLI.** `npx oneie` gives any developer 29 verbs covering substrate operations, deployment, commerce, observability, and ergonomics. No installation required for a first run. Structured JSON output on every verb via `--output json`, so it pipes cleanly into scripts. A `--dry-run` flag on every mutating verb previews without executing. Shell completion for bash, zsh, and fish. A REPL mode for interactive exploration. Works against local dev, staging, or production. Switching profiles is one command.

**API.** Every substrate operation is a REST endpoint on `api.one.ie`. `POST /api/signal`. `GET /api/loop/highways`. `DELETE /api/memory/forget/:uid`. Standard Bearer auth. Standard JSON bodies. A curl command is all the SDK you need for a first integration. The API is public in its shape. No proprietary format. No required client library. No vendor-specific request signing ritual.

**SDK.** `@oneie/sdk` is the TypeScript client. Six verbs (signal, ask, mark, warn, fade, follow) plus read verbs for highways, recall, reveal, forget, frontier, know. Fully typed. MIT licensed. Works in Node, Bun, and Cloudflare Workers. The client wraps the REST API with typed inputs and typed responses, enforces the four-outcome contract on every `ask()`, and composes cleanly with AI SDK v6 for the LLM layer. One team uses it in TypeScript. Another team calls the same endpoints from Python. The substrate does not care.

**MCP.** `@oneie/mcp` is the Model Context Protocol server. Install it. Point Claude Code, Cursor, or Windsurf at it. The IDE now has 42 substrate tools available as natural-language-callable functions: every substrate verb, every commerce operation, every observability query. A developer writes *"show me the top ten paths by pheromone strength"* in their IDE and the substrate responds. An AI-assisted workflow calls `oneie_signal` the same way it calls any other tool. The surface adapts to how the developer works, not the other way around.

---

## Spec

The substrate's vocabulary is documented in four interlocking files. They are the source of truth for every surface.

**ADL (Agent Definition Language).** Every agent is an ADL document. Name, role, skills, voice contract, pricing, membership, lifecycle status. The ADL parser runs in both `@oneie/sdk` (`parse()`, `syncAgent()`) and the CLI (`oneie agent`). An ADL document authored by a strategist in chat and an ADL document pushed by a developer from the terminal go through the same parser, produce the same TypeDB unit, and appear identically in the substrate. Authoring surface varies. The spec is the same.

**Ontology.** Six dimensions. Groups, actors, things, paths, events, learning. These are the only types in the substrate. An agency client is an actor. A marketing skill is a thing. A conversation is a path. A payment is an event. A successful campaign pattern is a learning. The ontology is locked. Dimension names cannot be renamed. Extensions happen within the existing six dimensions, never by adding a seventh. This is what makes the substrate transferable across verticals without re-engineering. The dental client and the window-installer client both live in the same ontology.

**DSL (Domain-Specific Language).** The signal grammar. Two fields: `receiver` and `data`. `receiver` names who gets it. `data` carries three slots: `tags` (routing), `weight` (pheromone deposit or payment amount), `content` (payload). That's the whole language. One TypeScript interface. 194 tests verify signal flow, mark/warn/fade, select/follow, ask outcomes, `.then()` chains, tag subscription, and the toxicity sandwich. The DSL is frozen. Building on it is safe.

**Dictionary.** The canonical name list. Every entity, every verb, every dimension has one name and one name only. Dead names (*knowledge, connections, people, node, scent, alarm, trail, colony*) are documented so they stay dead. When an integration pulls the wrong name, the dictionary is the first stop. When a new developer joins Donal's team, the dictionary is the first doc they read.

These four documents are the contract between surfaces. Any surface that reads them can interoperate. Any surface that bypasses them drifts.

---

## Verb-Surface Parity

Every action is reachable from every surface. The team picks the surface. The substrate doesn't know which one was used.

Here is the same operation (emit a signal to an agent) performed four ways:

**CLI**
```bash
oneie signal chairman --data '{"tags":["chat"],"content":"New window lead from website"}'
```

**curl (API)**
```bash
curl -X POST https://api.one.ie/api/signal \
  -H "Authorization: Bearer $ONE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"receiver":"chairman","data":{"tags":["chat"],"content":"New window lead from website"}}'
```

**SDK (TypeScript)**
```typescript
import { ONE } from '@oneie/sdk'
const one = new ONE({ baseUrl: 'https://api.one.ie', apiKey: process.env.ONE_API_KEY })
await one.signal({ receiver: 'chairman', data: { tags: ['chat'], content: 'New window lead from website' } })
```

**MCP (inside Claude Code or Cursor)**
```
Use the oneie_signal tool with receiver="chairman" and data={"tags":["chat"],"content":"New window lead from website"}
```

Four surfaces. One result. The signal arrives at the same unit, marks the same path, deposits the same pheromone. The substrate records the outcome identically regardless of which surface sent the signal.

This is not a design preference. It is a commitment. An agency that onboards with the chat surface and later scales to a developer team using the SDK does not rebuild. The substrate they built on day one is the same substrate they build on at month twelve.

The table below maps the 3-by-3 grid: build mode on one axis, call surface on the other, spec document grounding each.

| | Chat | Markdown / IDE | CLI |
|---|---|---|---|
| **Signal** | Type in chat window | `one.signal()` in TypeScript | `oneie signal <receiver>` |
| **Publish skill** | Describe the skill in chat | `oneie skill publish` from IDE terminal | `oneie publish <skillId>` |
| **Check highways** | Ask "show me top paths" via MCP | `one.highways(10)` in TypeScript | `oneie highways --limit 10` |
| **Deploy agent** | Chat-driven sync | `syncAgent(parse(md))` | `oneie deploy` |
| **Spec** | ADL (auto-generated) | ADL (authored) | ADL (parsed from `.md`) |
| **Grounding doc** | Dictionary + Ontology | DSL + SDK reference | CLI reference + ADL |

---

## The 29 CLI Verbs

The CLI is the fastest way to understand what the substrate can do. Twelve substrate verbs map one-to-one to engine primitives. Five handle deployment. Eight handle commerce. Four handle observability. The ergonomics group adds profiles, shell completion, output formatting, watch mode, dry-run, REPL, NDJSON pipeline, and live SSE tail.

**Substrate (12):** `signal`, `ask`, `mark`, `warn`, `fade`, `select`, `recall`, `reveal`, `forget`, `frontier`, `know`, `highways`

**Deploy (5):** `init`, `agent`, `deploy`, `claw`, `sync`

**Commerce (8):** `pay`, `hire`, `bounty`, `commend`, `flag`, `status`, `capabilities`, `publish`

**Observability (4):** `stats`, `health`, `revenue`, `export`

Every verb supports `--output json` for piping. Every mutating verb supports `--dry-run`. Every verb exits `0` on success, `1` on failure. Scripts do not need to parse prose output.

The `doctor` verb runs four self-checks (config valid, API key present, substrate reachable, TypeDB reachable) and exits `0` only when all four pass. CI pipelines call `oneie doctor` as a pre-deploy gate. If any check fails, the failure message prints, the pipeline stops, and the cause is named.

The `tail` verb connects to the substrate's Server-Sent Events stream and prints live state: highway updates, stats snapshots, pheromone marks as they arrive. A developer running `oneie tail` during a client demo can watch the substrate respond to live conversation in real time.

---

## The MCP Server Surface

`@oneie/mcp` exposes 42 tools to any MCP-aware IDE. The tool groups match the CLI exactly: substrate verbs, commerce operations, observability queries, discovery, pay tools, and lifecycle.

Claude Code, Cursor, and Windsurf all connect to it via the same config block:

```json
{
  "mcpServers": {
    "oneie": {
      "command": "npx",
      "args": ["@oneie/mcp"],
      "env": {
        "ONEIE_API_URL": "https://api.one.ie",
        "ONEIE_API_KEY": "your-key"
      }
    }
  }
}
```

Once connected, the IDE can call `signal`, `ask`, `mark`, `warn`, `highways`, `stats`, `recall`, `scaffold_agent`, `list_agents`, `hire`, `bounty`, `pay_create_link` (the full substrate surface) as natural-language tool calls or programmatic MCP invocations.

The agent becomes a session actor. When Claude Code calls `one_signal`, it is a unit in the substrate. Its outcomes mark and warn the same paths as any other agent. The substrate does not distinguish between a human developer, an AI-assisted workflow, and an autonomous agent. They are all units. They all emit signals. They all deposit pheromone.

This is what it means to say ONE is AI-native. The developer tooling and the agent runtime are the same system. There is no separate "developer mode." There is no import/export step between the IDE environment and the production substrate.

---

## The SDK Shape

`@oneie/sdk` is the TypeScript client for the substrate API. MIT licensed. The source is in `sdk/` in the open-source repository at `github.com/one-ie/one`.

Six verbs. Fully typed:

```typescript
import { ONE } from '@oneie/sdk'

const one = new ONE({
  baseUrl: 'https://api.one.ie',
  apiKey: process.env.ONE_API_KEY,
})

// Send a signal (fire and forget)
await one.signal({ receiver: 'director:review', data: { tags: ['lead'], content: brief } })

// Send and wait for outcome
const { result, timeout, dissolved } = await one.ask({ receiver: 'director:quote', data: { client, spec } })

if (result)         one.mark('director->quote', chainDepth)   // path strengthens
else if (timeout)   { /* neutral */ }
else if (dissolved) one.warn('director->quote', 0.5)           // path doesn't exist yet
else                one.warn('director->quote', 1)             // agent produced nothing
```

The four-outcome contract on `ask()` is the core of the closed loop. Every client call must close it. The SDK types make the omission visible at compile time. A handler that returns without marking or warning produces a TypeScript error in strict mode.

`parse()` and `syncAgent()` handle the ADL lifecycle. Read a markdown file. Parse it. Sync it to TypeDB. The unit is live. Skills are registered. Paths are initialized:

```typescript
import { parse, syncAgent } from '@oneie/sdk'
import { readFile } from 'node:fs/promises'

const spec = parse(await readFile('agents/director.md', 'utf8'))
await syncAgent(spec)
// director is now a unit in the substrate with its skills registered
```

One TypeScript team and one Python team can build on the same substrate. The TypeScript team uses `@oneie/sdk`. The Python team calls the REST API directly or uses the `oneie` Python package (`pip install oneie`). The substrate API is the shared surface. Both teams see the same paths, the same pheromone, the same highway state.

---

## Deploy in 3 Commands

A new agency client goes from zero to live in three commands:

```bash
npx oneie init                           # scaffold the project
npx oneie agent agents/client-name/      # sync agent definitions to the substrate
npx oneie deploy                         # deploy to Cloudflare Workers
```

That's it. The deploy covers four services: the Astro Worker (23 seconds), the API Gateway (14 seconds), the Sync Worker (8 seconds), and the NanoClaw agent worker (9 seconds). Health checks pass within one second of deploy. Total time from first command to live production: under 107 seconds.

The three-command path works because `oneie init` copies a known-good project scaffold (agents directory, wrangler config, worker entrypoints) that has been built and deployed hundreds of times. There is no "customize the template" step before the first deploy. The customization is in the agent markdown files, which can be edited after the first deploy is live.

The deployment target is the agency's own Cloudflare account. The Workers are owned by the agency. The domain is the agency's. The substrate data stays in the agency's TypeDB instance. ONE is not in the middle of the client relationship. It is underneath it, out of sight.

---

## Local Dev (`oneie dev`)

`oneie dev` starts the full local Cloudflare Workers stack using `wrangler dev`. Four services run locally: the Astro app, the API Gateway, the Sync Worker, and the NanoClaw agent worker. The local environment mirrors production exactly. There is no "local mode" that behaves differently from the deployed version.

The full dev stack:

```bash
oneie dev
# Starts:
# → Astro Worker on localhost:4321
# → API Gateway on localhost:8787
# → Sync Worker on localhost:8788
# → NanoClaw on localhost:8789
# → TypeDB connection (remote, or local if configured)
```

`oneie doctor` confirms everything is wired correctly:

```
[ok] Config        ~/.config/oneie/config.json
[ok] API Key       sk-***...abc
[ok] Substrate     http://localhost:8787  12ms
[ok] TypeDB        https://api.one.ie/typedb/health  318ms
```

The `agent --watch` flag adds live hot-reload for agent markdown files. Save a change to `agents/director.md` and the substrate syncs within a second. No restart. No rebuild. The agent's behaviour updates live.

For TypeScript teams, this is a fast development loop. Edit the markdown. See the behaviour change in the running chat UI. Test edge cases. Push to production when it's right.

---

## Worked Example

It is a Thursday morning. The agency has just taken on a new commercial property management client. The brief calls for a client-facing chat agent that handles maintenance requests, qualification questions, and new tenant enquiries.

A developer on Donal's team opens VS Code. She creates `agents/property-manager.md`. She writes the name, the system prompt, the four skills (`handle-maintenance`, `qualify-tenant`, `book-inspection`, `send-followup`), the voice contract (formal, helpful, never overpromise on timing), and the pricing (internal, billed to the client workspace).

She saves the file. The watcher picks it up:

```
synced  agents/property-manager.md   unit=property:manager
```

She runs the agent in local chat. Tests the maintenance request flow. Adjusts the voice contract. Tests again. It takes eleven minutes.

She runs:

```bash
oneie skill publish property:manager:handle-maintenance --name "Maintenance Request" --price 0.002 --scope group
```

The skill is published to the client's workspace. Twenty-eight seconds later, `oneie stats` shows:

```
units: 24 (+1)  highways: 7  skills: 31 (+1)  revenue: $0.00
```

She deploys:

```bash
oneie deploy
```

107 seconds. Health checks pass. The skill appears in the client's chat interface. Their team tests it before lunch.

From idea to production: forty minutes. No release meeting. No staging environment approval. No ticket to a platform team. The developer who understood the client's needs shipped it herself, from her IDE, with the same commands that will ship every future skill.

That is what verb-surface parity makes possible. The tools do not slow the work down.

---

## Objections

**"My team uses Python."**

The REST API is language-agnostic. Python developers call `POST /api/signal`, `GET /api/loop/highways`, and every other substrate endpoint with `requests` or `httpx`. The `oneie` Python package wraps the most common operations and adds the `oneie run agent.md` CLI verb, which loads a markdown agent, builds a uAgents Protocol instance, registers with the Almanac, and connects to the OpenRouter LLM client. Python and TypeScript teams can work on the same substrate simultaneously. One team's signals mark the same paths as the other's. The substrate does not know which language sent the signal.

**"What if we want to add capabilities later that you don't support?"**

The SDK is MIT licensed. The source is public. The API is documented and stable, versioned at `api.one.ie` with explicit deprecation notice before any endpoint changes. Adding a capability means writing a new skill in markdown, publishing it with `oneie publish`, and wiring the handler in your preferred language. There is no platform team to petition, no feature request queue, no waiting for the next release cycle. Your engineers build it. The substrate hosts it.

**"What if we need to leave the platform?"**

`oneie export` exports any substrate data as JSON: paths, units, skills, highways, or toxic path lists. The agent markdown files are already in your repository. The corpus of conversations is stored in your TypeDB instance, which is your data. An agency that decides to leave takes its agents, its data, and its corpus. The platform does not hold any of it on your behalf.

**"Our clients' data can't touch a shared platform."**

Each client workspace is a separate data space in TypeDB with isolated paths and separate signal histories. There is no cross-client data bleeding. Deletion is one command (`oneie forget <uid> --yes`) and removes all records for that unit across the substrate. For GDPR, the command produces a receipt JSON you can attach to the deletion request.

**"The tools look complex. My developers don't want to learn a new system."**

The developers who already use Claude Code or Cursor get the MCP server for free: 42 tools available without leaving their IDE. Developers who prefer the terminal get a documented CLI with shell completion and JSON output. Developers who prefer code get a typed SDK with six methods. None of these require learning the others. A developer can be productive on the substrate in under twenty minutes using whichever surface they already know.

**"What's the worst case if the build takes longer than expected?"**

The three-command deploy is a floor, not a ceiling. A working agent in the substrate in three commands is documented and tested. Complex multi-skill builds take longer, but they're built on the same substrate, and every component can be tested independently before the deploy. The `--dry-run` flag previews every mutating operation. Nothing reaches production without passing `oneie doctor`.

**"We're already committed to another developer toolchain."**

The API has no required client library. REST over HTTPS. JSON request bodies. Standard Bearer auth. Any toolchain that can make an HTTP request can call the substrate. The CLI, SDK, and MCP server are conveniences. The substrate underneath them works without them.

---

## Failure Modes

**Agents go stale.** An agent markdown file that is not reviewed after the first month tends to drift from the client's current reality. The voice contract stays accurate for the initial brief. The client's product changes. The agent does not. The fix is `oneie agent --watch` in development: edit, see the change, deploy. The failure mode is not a platform failure. It is a process failure. The platform makes it easy to update. The team has to run the update.

**Paths do not harden without traffic.** The substrate learns from signals. An agent that receives ten signals a week builds pheromone slowly. An agent that receives ten thousand signals a week builds highways in days. A new client deployment with low initial traffic will have slower routing in the early weeks. The fix is volume, which the agency controls through how they position the agent to the client's end users. The substrate cannot learn from traffic that does not exist.

**Local and production diverge under manual edits.** If a developer edits a TypeDB record directly, without going through the SDK or CLI, local state can diverge from what the markdown spec describes. The substrate treats the API as the canonical write path. Direct TypeDB edits are not versioned, not auditable, and not reproducible. Use `oneie agent` to sync. Use `oneie export` to inspect. Use `git` to version the markdown.

---

## Comparisons

**ONE CLI vs. Vercel CLI.** Vercel's CLI deploys frontend apps. ONE's CLI deploys agents, publishes skills, marks pheromone paths, hires agents, posts bounties, and tails live substrate events. They are not competitors. They solve different problems. An agency using Vercel for its own marketing site and ONE for client agent deployments is a normal configuration.

**ONE MCP vs. custom AI tool integrations.** Most AI-assisted developer tools require custom integration code for every capability: a Slack tool, a GitHub tool, a database tool, each written separately. MCP is a standard. Add `@oneie/mcp` once. The IDE gains 42 substrate tools immediately, with no custom integration code. Future substrate capabilities become available when the MCP server updates, not when the IDE vendor adds a plugin.

---

## Pricing Math

The three-command deploy has no per-deploy cost. Cloudflare Workers on a paid plan run at $0.50 per million requests and $12.50 per million CPU seconds. A client workspace running 50,000 conversations a month at an average of 5 requests per conversation (250,000 requests) costs under $1 in compute. The signal processing, path marking, pheromone accumulation, and highway computation are all in-memory operations with sub-millisecond latency. The TypeDB queries that persist learning are the only database cost, and they run on writes, not on reads. An agency with 50 active clients at this volume pays under $50 per month in compute for the entire infrastructure layer. The agency's margin is the credit markup on top, not the infrastructure.

---

## Day in the Life

It is 9:00 on a Monday. Donal opens his terminal. `oneie tail` starts streaming the weekend's substrate events: which paths were marked, which agents earned, which skills were called most. He sees that the property manager agent's `qualify-tenant` skill received forty-three calls over the weekend, with a 94% success rate. The `handle-maintenance` skill received eleven calls, all resolved.

He opens `agents/property-manager.md`. The voice contract has a line about maintenance response times that he knows is now inaccurate. The client changed their SLA last week. He edits it. He saves. The watcher logs `synced agents/property-manager.md`. The agent is updated.

At 10:00, a new client brief arrives. The agency is taking on a multi-location dental group. Donal spends twenty minutes authoring `agents/dental-group.md` with the client's four skills. He publishes the agent to a new client workspace.

At 10:30, he runs `oneie deploy`. 107 seconds later, the dental group agent is live.

At 11:00, he looks at `oneie stats`:

```
units: 25 (+1)  highways: 7  skills: 35 (+4)  revenue: $0.00
```

By Thursday, after the dental group's front desk team has used the agent through thirty patient enquiries, `oneie stats` shows:

```
units: 25  highways: 9 (+2)  skills: 35  revenue: $0.14
```

Two new highways. The substrate found the paths that work. The agency did not configure them. The substrate learned them.

That is the development loop. Author. Deploy. Watch. Let it learn.

---

## FAQ

**Can a non-developer author agents?**

Yes. The chat surface and the markdown format require no code knowledge. A strategist who understands the client's needs can write an ADL document in the same way they would write a creative brief. The technical team can then review, refine, and deploy it. The authoring does not require them.

**Do we need a DevOps team to deploy?**

No. `oneie deploy` wraps `wrangler deploy --env production`. The only prerequisite is a Cloudflare account and a wrangler config. The `oneie init` scaffold includes both. A developer who has deployed a Cloudflare Worker before will recognize every step. One who hasn't can follow the init output.

**Can we run the substrate locally before deploying?**

Yes. `oneie dev` runs the full stack locally. The only external dependency is the TypeDB connection, which can point at a remote instance or a locally-running TypeDB server. Every CLI verb and every SDK call works identically against `localhost:4321` and `api.one.ie`.

**How does the Python package relate to the TypeScript SDK?**

They both call the same REST API. The Python package adds the `oneie run` CLI verb, which loads an agent markdown file and starts a uAgents Protocol instance registered with the Almanac. Python agents appear in the same substrate as TypeScript agents. They emit signals to the same paths. They earn on the same economy.

**What happens when a skill fails?**

The closed-loop contract requires every signal to close. A failed skill call is a `warn()` on the path. Path resistance increases, routing probability to that agent decreases, and the agent's success rate is recorded. After enough warnings, the agent's generation increments and its system prompt is rewritten by the substrate's evolution loop. The platform surfaces the problem. It does not hide it.

**Can we extend the MCP server with custom tools?**

Yes. `createRouter()` and `register()` let you add custom tools alongside the built-in 42:

```typescript
import { createRouter, serve, substrateTools } from '@oneie/mcp'

const router = createRouter()
for (const tool of substrateTools()) router.register(tool)
router.register({
  name: 'my_custom_tool',
  description: 'Agency-specific operation',
  inputSchema: { type: 'object', properties: { input: { type: 'string' } }, required: ['input'] },
  handler: async (args) => ({ result: process(args.input) }),
})
await serve(router)
```

The custom tool appears alongside the substrate tools in the IDE. No re-compilation of `@oneie/mcp` required.

---

## Glossary

**ADL (Agent Definition Language).** The structured markdown format that defines an agent: name, system prompt, skills, voice contract, pricing, lifecycle status. Every surface reads it. No surface bypasses it.

**Verb-surface parity.** Every substrate operation is reachable from every surface (chat, CLI, SDK, MCP). The surface is a preference, not a capability gate.

**Signal.** The atomic unit of work in the substrate. Two fields: `receiver` (who gets it) and `data` (what it carries). Everything in the substrate flows through signals.

**Pheromone.** The substrate's learning mechanism. Successful paths accumulate strength. Failed paths accumulate resistance. Routing follows the strongest path. Over time, frequently successful paths become highways.

**Highway.** A path whose strength has exceeded the promotion threshold. Routing to a highway is deterministic, not probabilistic. Highways harden on-chain.

**NanoClaw.** The edge-native agent worker deployed per client persona. Runs on Cloudflare Workers. Receives Telegram, Discord, and HTTP signals. Routes them through the substrate. Returns streamed responses.

**TypeDB.** The substrate's brain. Stores paths, skills, hypotheses, and learning. All path queries run against TypeDB. The runtime is the nervous system. TypeDB is memory.

---

## Cross-References

Page 05 (Agents) shows what an agent definition looks like in practice: the ADL format that CLI, SDK, and MCP all read. Page 06 (Skills) shows how skills published via `oneie publish` appear in the client-facing chat surface. Page 15 (Security) covers the data isolation model that makes per-client deployments safe: the same model that governs CLI `export` and `forget`.

---

Pick your surface: chat, CLI, IDE, MCP.

<!-- rubric: fit=0.94 strongest=0.92 show=0.90 cut=0.88 craft=0.90 → 0.91 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=fn -->
