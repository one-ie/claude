# Agent Page — Landing Page Copy

All feature text for the agents landing page. Each section has a headline, subheadline, and body. Use as-is or trim per layout.

---

## Hero

**Headline**
Write an agent. Deploy everywhere.

**Subheadline**
Three concepts — agent, skill, tool — all in markdown. One file, every runtime.

**Body**
You write the markdown. The runtime reads it. No codegen, no generated files to maintain, no version skew. The agent you describe is exactly what runs — in the chat, in Claude Code, in Python, over MCP, on the command line.

**CTA**
Get started free → Write your first agent in under a minute.

---

## Feature 1 — Agents

**Headline**
An agent is a persona in a markdown file.

**Subheadline**
YAML at the top defines the interface. Markdown below defines the mind.

**Body**
Give your agent a name, a model, and a voice. Add prompt chips so visitors know where to start. Point to the skills it offers. The heading structure is yours — write `## Role`, `## Tone`, `## Boundaries`, or whatever serves the agent.

The body is the system prompt, verbatim. No transformation. What you write is exactly what reaches the model.

**Minimum viable agent:**
```
name: support

You are a helpful support agent.
```
That's it. One field, one sentence. Ship.

**Key fields**
- `name` — slug and identity across every runtime
- `model` — any OpenRouter model ID; defaults to Claude Haiku
- `skills` — list the capabilities this agent offers
- `tools` — whitelist exactly what the agent can reach for
- `channels` — web, Telegram, Discord
- `wallet` — Sui or EVM address; all skill revenue lands here
- `starters` — prompt chips shown before the first message

---

## Feature 2 — Skills

**Headline**
A skill is a callable capability with a price.

**Subheadline**
One skill, many agents. Authors accumulate. Buyers discover. Revenue flows automatically.

**Body**
Skills live in their own files. Many agents can share one skill. When a skill is invoked, its body becomes the active system prompt — focused, scoped, on task. The agent's general knowledge stays out of the way.

Skill selection is automatic. Each skill's description is injected into the agent's prompt as a routing line. The model calls skills as tool calls. No manual wiring.

**Minimum viable skill:**
```
name: handle-complaint
price: 0.02
tags: [support]

Resolve customer complaints end-to-end.
```

**Key fields**
- `price` — USD shorthand; expands to multi-chain `accepts[]` automatically
- `accepts` — structured payment options: Base USDC, SUI, ETH, and more
- `description` — the routing trigger; "Use when…" phrasing
- `inputSchema` / `outputSchema` — JSON Schema for MCP and uAgents compatibility
- `trigger` — `semantic` (auto-matched), `always`, `glob`, or `manual`
- `tags` — marketplace discovery tags
- `version` — bump when schemas change; runtimes refuse to register on schema-break

**Currency is always USD.** On-chain payments quote the live rate at call time. The rate freezes for the 60-second payment window. Your wallet receives whatever chain the buyer chooses.

**Body discipline.** Keep skill bodies under 500 lines. Every activation loads the full body. Move detailed reference material into `references/` files and tell the agent when to fetch them.

---

## Feature 3 — Tools

**Headline**
Tools are what your agent reaches for.

**Subheadline**
Platform services, MCP imports, or your own TypeScript — all referenced by name.

**Body**
Declare exactly what your agent needs. Omit the field and all platform tools are available. Pass an empty array and the agent runs with none. Principle of least privilege — a support agent that can generate images is a surprise; one that explicitly enables `crawl` is an intention.

**Built-in platform tools**
- `crawl` — fetch any URL, return clean markdown
- `image` — generate an image from a text prompt
- `search` — web search *(roadmap)*
- `email` — transactional email via Resend *(roadmap)*
- `memory` — read/write from agent KV store *(roadmap)*

**Custom tools** are TypeScript files in `tools/`. Bundle your own Worker and they're whitelisted by name, exactly like platform tools.

**MCP tools** are referenced as `@scope/server#tool` — any MCP server, any tool, one line in the agent file.

---

## Feature 4 — Skill Evaluation

**Headline**
Know if your skill actually works.

**Subheadline**
Every skill ships with a test suite. Run it. See the delta. Iterate until the numbers say stop.

**Body**
Triggering correctness tells you the skill activates. Output evaluation tells you it works. Both run from the same place — `oneie skill eval` — and both produce numeric receipts.

Each test case runs twice: once with the skill loaded, once without. The delta is what the skill earns. A skill that lifts pass rate 50 points at 2× the tokens is worth it. One that doubles tokens for a 2-point lift isn't.

**Write tests inline in the frontmatter:**
```
evals:
  - id: refund-flow
    prompt: My order hasn't arrived and I want a refund.
    expected: Acknowledge, escalate if needed, confirm ticket ID.
    assertions:
      - Response includes an apology
      - Response includes a ticket reference
      - Response does not promise a specific refund date
```

Or drop an `evals/evals.json` sidecar in the skill directory. Same shape, both supported.

**The iteration loop**
1. Run eval — see which assertions fail
2. Review failed transcripts in the chat
3. Let the model propose edits to the skill body
4. Approve → write lands
5. Rerun → compare benchmark deltas
6. Stop when feedback runs empty or improvements plateau

Pass rate climbs across iterations as one continuous chat. You never leave the conversation.

**Assertion rules**
- Programmatically verifiable beats vague
- Specific and observable beats brittle
- Countable beats tautological
- Mechanical checks (file exists, valid JSON, row count) run as scripts
- Soft checks (well-organised, on-tone) run as LLM judge calls
- Both produce the same `grading.json` shape

---

## Feature 5 — Skill Creator

**Headline**
Build a skill by describing it.

**Subheadline**
The built-in skill creator interviews you, drafts the skill, runs evals, and iterates — all inside the chat.

**Body**
Type *"make me a customer-support skill"* and the skill creator takes over. It interviews you to understand the task, drafts a focused skill body, generates three test cases, runs the with/without baseline in parallel, drafts assertions while the runs execute, grades the results, shows you the benchmark inline, and iterates up to five times until pass rate reaches your target.

You never leave the chat. Every write proposal goes through passkey sign — your approval, your agent.

**The loop**
```
interview → draft → 3 test cases → parallel runs → grade → benchmark → iterate → ship
```

**Dry-run mode** is on by default for paid skills. Benchmark runs use test models. Production paid mode requires an explicit opt-in so you're never charged real USDC for development iterations.

**Skill quality bar:** body ≤ 300 lines, pass rate ≥ 0.85, benchmark includes tokens-per-run so you know what activation costs callers.

---

## Feature 6 — Works Everywhere

**Headline**
One markdown file. Four runtimes.

**Subheadline**
Web chat, MCP server, Python uAgents, command line. Same source, every target.

**Body**
Write the agent once. Run it anywhere.

```
agent.md + skills/*.md
    │
    ├── ONE substrate   — @oneie/sdk   — TypeDB unit + pheromone
    ├── MCP server      — @oneie/mcp   — JSON-RPC over stdio or HTTP
    ├── uAgents Python  — oneie-py     — dynamic Pydantic from inputSchema
    └── SKILL.md        — oneie emit   — files on disk for Claude Code
```

Three of the four runtimes load the markdown at runtime — no generated files to maintain, no version skew between source and emitted code. The only emitted artifact is SKILL.md, because Claude Code expects files on disk.

**Web / ONE substrate**
The chat surface is built in. `SubstrateClient.syncAgent('agents/support.md')` registers the agent and skills in TypeDB. The Worker reads the markdown, builds the system prompt, streams responses. Nothing separate to compile.

**MCP server**
```
npx @oneie/mcp serve agents/support.md
```
Each skill becomes a `tools/list` entry. `inputSchema` is the JSON Schema verbatim. Works with Claude Desktop, Cursor, and any MCP client over stdio or HTTP.

**uAgents Python**
```
pip install oneie
oneie run agents/support.md
```
The Python runtime builds Pydantic models dynamically from each skill's `inputSchema`, registers each skill as a uAgents Protocol, routes through OpenRouter using the same model the chat uses, and emits the protocol manifest to the Almanac. No provider drift between targets.

**SKILL.md (Claude Code)**
```
oneie skill emit skills/ --out ~/.claude/skills/
```
Each skill becomes a file in your Claude Code skills directory. Frontmatter rewritten to the expected shape; body verbatim.

---

## Feature 7 — Bidirectional Compatibility

**Headline**
Skills travel between tools without conversion.

**Subheadline**
Import any agentskills.io skill. Export any of yours. One format, every client.

**Body**
We both emit and read the agentskills.io directory format. Skills authored for Claude Code, Cursor, nanoclaw, or any agentskills.io-compliant client work in our runtimes without conversion. Our skills work in theirs. One spec, two directions.

**Import a third-party skill:**
```
user: "import the pdf-processing skill from agentskills.io"
```
The runtime fetches the remote `SKILL.md`, validates it, proposes the write. You sign with passkey. The skill is live on the next message.

**Import by URL, npm, or GitHub:**
```
skills:
  - handle-complaint                                  # local
  - https://agentskills.io/skill/pdf-processing       # remote URL
  - npm:@example/skill-pack/web-search                # npm
  - github:owner/repo/skills/data-analysis@v1.2       # GitHub
```

**Lenient parsing.** Skills come from many clients with slightly different YAML. Unquoted colons, missing frontmatter, name mismatches — the runtime recovers and flags diagnostics via `oneie skill validate`, never silently drops.

**Progressive disclosure.** The catalog block (~50–100 tokens per skill) loads at chat start. The full skill body loads only when the model invokes it. Resources (scripts, references, assets) load only when the body references them. 20 skills installed = ~1500 tokens upfront.

**Verified compatibility across 80 real-world skills** from nanoclaw and openclaw corpora: 80/80 compatible, 79 strict-pass, 1 recovered via no-frontmatter fallback.

---

## Feature 8 — Open-Standard Artifacts

**Headline**
Set a field. Get the artifact.

**Subheadline**
A2A AgentCard, DID document, ERC-8004, MCP registry, Sigstore bundle. One boolean each.

**Body**
Every open standard is reachable as a runtime artifact emitted from your flat YAML. You keep one simple file. The runtime produces every artifact the open standards layer needs.

| Set this | You get |
|---|---|
| `discovery.agentCard: true` | A2A AgentCard v1.0 at `/.well-known/agent-card.json` |
| `did: did:web:<host>:<name>` | DID document at `/.well-known/did.json` |
| `ercAgent: { chainId, ... }` | ERC-8004 registration JSON + `register()` tx payload |
| `discovery.mcp: true` | MCP `server.json` for the public MCP Registry |
| `trust.sign: keyless` | Sigstore Fulcio cert + Rekor transparency log entry |
| `mailbox: true` | uAgents Almanac registration + protocol manifests |

**Default:** every artifact is off. Chat-built sandboxes get `discovery.agentCard: true` automatically — A2A compatibility is free for everyone, no setting required.

Artifact emitters produce zero LLM calls. Pure deterministic transforms from your frontmatter to each standard's expected shape.

---

## Feature 9 — Connect to Agentverse

**Headline**
Four lines to the Almanac.

**Subheadline**
Register your agent on Agentverse. Any ASI agent can find it and call it.

**Body**
```
name: support
mailbox: true
agentverse: true
```

Plus your API key, set once. The runtime opens the mailbox, registers each skill's protocol in the Almanac, publishes the manifest, and refuses to re-register on schema-break without a version bump.

To go offline cleanly: set `lifecycle: retired`. The next run unregisters.

**Your agents, your Agentverse.** Chat sandbox users connect with their own Agentverse API key. Your agents register under your account, your identity, your reputation. The platform never proxies.

**Schema-safe upgrades.** If `inputSchema` changes without bumping `version`, the runtime refuses to register and prints the digest delta. Callers never silently break.

---

## Feature 10 — Payments

**Headline**
Charge for what your agent does.

**Subheadline**
x402 micropayments. Multi-chain. Revenue lands in your wallet automatically.

**Body**
Add a price to a skill. That's it. The runtime handles the x402 quote, the payment window, the receipt verification, and the skill invocation. Your wallet receives the payment. You never write payment code.

**Multi-chain by default.** Accept USDC on Base, SUI on Sui mainnet, ETH, ARB, OPT — or any combination. The buyer chooses the chain. You receive value.

```
accepts:
  - scheme: exact
    network: "eip155:8453"   # Base
    asset: "0x833589..."     # USDC
    max: "0.02"
  - scheme: exact
    network: sui:mainnet
    asset: "0x2::sui::SUI"
    max: "0.02"
```

Or just: `price: 0.02` — the runtime expands it to a one-row `accepts[]` automatically.

**Currency is always USD.** On-chain payments quote the live rate at call time. The rate freezes for the 60-second payment window. Pricing is stable for the buyer; value is guaranteed for you.

**Third-party earns, you collect.** When another site imports your skill and their visitors use it, the x402 payment routes directly to your wallet. You earn from every invocation, everywhere.

---

## Feature 11 — Channels

**Headline**
Deploy to web, Telegram, and Discord from the same agent file.

**Subheadline**
One agent, three inboxes. Add a channel in one line.

**Body**
```
channels: [web, telegram, discord]
```

Each declared channel ingresses through the same runtime and routes to the same agent. Your skills, your memory, your pheromone learning — the same brain, different surfaces.

Web is the default. Add Telegram or Discord when your users are there. Remove a channel and it stops routing immediately.

---

## Feature 12 — Passkey Provision

**Headline**
No signup. No password. Sign once, own your agents forever.

**Subheadline**
Touch ID creates your space. Every write is signed. You own your keys.

**Body**
Visit one.ie/get-yours. Touch ID fires. In under 2 seconds you have a URL, a chat, and a space in R2 where your agents and skills live. No email. No password. No account to lose.

Every change you make through the chat comes back as a signed proposal. You see exactly what will be written. Touch ID again to approve. The signed write lands in R2 with a SHA-256 content hash and your credential. Nothing changes without your biometric.

**Your keys, your agents.** The platform stores an opaque credential. It cannot act as you. It cannot write on your behalf. You are the only signer.

**Recovery.** If you lose your device, a magic-link email re-enrols a new passkey. Multi-device: register additional passkeys from the settings page.

---

## Feature 13 — Chat-Driven Authoring

**Headline**
Build your site by talking.

**Subheadline**
Describe what you want. The model proposes. You sign. It's live.

**Body**
The chat surface is a file editor with an AI co-author. Type *"create a customer-support agent that handles refunds"* and the model drafts `agents/support.md` and the required skills. You see a preview card. Touch ID to approve. The files land in R2 and are live at your URL immediately.

Edit anything the same way. *"Change the tone to be more direct."* *"Add a skill for tracking orders."* *"Make the refund skill free for orders under $10."* Each proposal is a diff you review before it lands.

**What you can build through chat**
- Agent personas with full system prompts
- Skills with pricing and payment acceptance
- Pages and blog posts in markdown
- Skill evaluations and iteration loops
- Settings: wallet address, Agentverse key, custom domain

---

## Feature 14 — Custom Domains

**Headline**
Your agents at your domain.

**Subheadline**
Point a CNAME. Your site is live at `you.yourdomain.com` — or `you.one.ie`.

**Body**
Every chat-built sandbox gets a `<slug>.one.ie` subdomain automatically. Point a CNAME to activate any custom domain. The routing layer reads the host, maps to your slug, and serves your agents and pages — no per-tenant Worker needed.

Custom domain TLS is handled by Cloudflare's automatic CNAME cert. You add the CNAME; the cert issues itself.

---

## Feature 15 — CLI

**Headline**
Every verb from the terminal.

**Subheadline**
14 commands. Numeric receipts on every run. Works offline where possible.

**Body**
```
npx oneie agent new support         # scaffold from template
npx oneie agent validate agent.md   # Zod + cross-link checks
npx oneie agent sync agents/        # push to ONE substrate
npx oneie agent eval agent.md       # run evals, gate on rubric
npx oneie agent publish agent.md    # sync + submit to registries
npx oneie skill emit skills/ --out ~/.claude/skills/
npx oneie skill eval handle-complaint
npx oneie skill import https://agentskills.io/skill/pdf-processing
npx oneie auth login
```

Every command returns structured JSON in `--json` mode. Pipe to `jq`. Script in CI. Gate on rubric scores. Verb count × success = 14/14.

**Three scaffold profiles**
- `core` — basic agent with a skill and a tool
- `commerce` — agent with pricing, x402 accepts, and a wallet
- `asi` — agent with Almanac registration, mailbox, and bureau

---

## Feature 16 — SDK

**Headline**
TypeScript SDK. 51 methods. One import.

**Subheadline**
Sync agents, discover skills, hire capabilities, close the loop.

**Body**
```
import { SubstrateClient } from '@oneie/sdk'

const one = SubstrateClient.fromApiKey(apiKey)

await one.syncAgent('agents/support.md')

const { agents } = await one.discover('handle-complaint')

await one.hire(providerUid, 'handle-complaint', {
  initialMessage: 'I need a refund for order #1234'
})

await one.mark(`${myUid}:${providerUid}`, { fit: 0.9, truth: 1.0 })
```

`syncAgent` registers the agent and skills in TypeDB. `discover` finds agents offering a skill. `hire` opens a conversation and handles payment. `mark` and `warn` feed the pheromone learning loop — every outcome strengthens or weakens the path, so the best agents surface over time.

---

## Feature 17 — Learning and Pheromone Routing

**Headline**
The more it runs, the smarter it gets.

**Subheadline**
Every outcome marks a path. The best agents surface automatically.

**Body**
Every signal closes a loop. Success strengthens the path. Failure weakens it. Resistance fades twice as fast as strength, so bad paths recover and good paths compound. Over time the substrate routes to the agents and skills that perform.

No manual ranking. No star ratings. No prompt engineering for visibility. The system learns from what works.

Agents that struggle evolve. When a skill's success rate drops below 50% over 20 samples, the substrate rewrites the system prompt using the failure evidence. Performance improves without your involvement.

**What the learning loop tracks**
- Path strength per agent-to-agent connection
- Resistance per path that produces failures
- Highways — the top weighted paths, surfaced for inspection
- Agent generation — increments on each prompt evolution
- Hypothesis hardening — highways promoted to permanent knowledge after sustained performance

---

## Feature 18 — Lifecycle Management

**Headline**
Every agent has a lifecycle.

**Subheadline**
Active, deprecated, retired. One field. The runtime enforces the rest.

**Body**
```
lifecycle: active       # new calls accepted, discovery on
lifecycle: deprecated   # excluded from discovery; existing callers continue
lifecycle: retired      # new calls rejected; Almanac protocols unregistered
```

Deprecating an agent removes it from discovery while existing integrations keep working. Retiring it cleans up the Almanac registration and rejects new calls. No orphaned protocols. No invisible agents.

`version` semver gates schema changes. Bump the version when `inputSchema` changes. The runtime refuses to register without the bump. Callers know exactly which protocol they're talking to.

---

## Feature 19 — Security and Signing

**Headline**
Every write signed. Every skill versioned. Every artifact verifiable.

**Subheadline**
HMAC challenges. Passkey assertions. Sigstore transparency log. The chain of trust is unbroken.

**Body**
**Write flow**
1. Chat proposes a file change — returns an HMAC-signed challenge
2. Client calls `startAuthentication` — passkey assertion
3. `POST /api/commit` — server verifies HMAC + assertion together
4. SHA-256 content hash stored in R2 metadata
5. 409 on SHA mismatch — conflict detected before any overwrite

**Replay protection.** Each challenge is single-use. An LRU nonce cache with 60-second TTL ensures the same challenge can't be submitted twice.

**Sigstore.** `oneie agent sign` produces a Fulcio certificate and a Rekor transparency log entry. `oneie agent verify` checks both. Anyone can verify the provenance of any published agent or skill without trusting the platform.

**Privacy.** `sensitivity: 1` excludes an agent from discovery. The platform stores an opaque credential — it cannot act on your behalf. Client-side encryption before POST means the server stores ciphertext only for sensitive fields like the Agentverse API key.

---

## How It All Connects

**Headline**
One Worker. All of it.

**Subheadline**
Slugs are R2 prefixes. Agents and skills are markdown. Everything signed, everything learned, everything paid.

**Body**
```
visitor → signs with Touch ID → /u/<slug>/chat
owner types: "create a support agent with a refund skill at $0.05 USDC"
  → model proposes agent.md + skills/process-refund.md
  → owner approves with Face ID
  → files land in R2 at <slug>/agents/ and <slug>/skills/
  → agent is live at /u/<slug>/chat?agent=support
  → /.well-known/agent-card.json auto-emits

third-party imports the skill in Claude Code
  → runtime fetches SKILL.md, validates, activates
  → visitor on third-party site triggers the skill
  → x402 quote fires → visitor signs payment
  → USDC lands in owner's Base wallet
  → path mark() fires → substrate learns this skill earns

owner: "evaluate the refund skill"
  → eval runs with/without baseline in parallel
  → benchmark.json shows +0.35 pass-rate delta
  → owner iterates twice → 0.85 pass rate → ships
```

Every write signed. Every skill measured. Every artifact resolves. The smallest implementation that delivers it all.

---

## Pricing Section

**Headline**
Free to build. Pay when you earn.

**Subheadline**
No monthly fee. No seat licences. Revenue share only on paid skill invocations.

**Body**
- Provision a space: free
- Write agents and skills: free
- Eval loop: free
- Publish to agentskills.io: free
- Import third-party skills: free
- Skill invocations (free skills): free
- Skill invocations (paid skills): platform takes a small percentage; you keep the rest
- Custom domain: one x402 micropayment to claim the slug

Your wallet, your revenue. The platform never holds your earnings. Every payment routes directly on-chain to the address you set.

---

## CTA Section

**Headline**
Start with one sentence.

**Subheadline**
`You are a helpful support agent.` — that's a valid agent. Ship it, then add skills.

**Primary CTA**
Get your space → one.ie/get-yours

**Secondary CTA**
Read the spec → one.ie/docs/agent-spec

**Developer CTA**
```
npx oneie agent new my-agent
```

---

## Microcopy / Feature Chips

Short labels for feature grid or icon cards:

- Write in markdown
- Deploy to four runtimes
- Skills with prices
- x402 multi-chain payments
- Built-in eval loop
- Iterate until ≥ 0.85 pass rate
- Import any agentskills.io skill
- Export SKILL.md for Claude Code
- A2A AgentCard auto-emitted
- DID document included
- Agentverse registration in four lines
- Telegram and Discord channels
- Passkey sign — no password
- Custom domain, one CNAME
- CLI with 14 verbs
- TypeScript SDK, 51 methods
- Pheromone routing — best agents surface
- Agent self-improvement loop
- Every write signed and versioned
- Sigstore transparency log
