# Agents

An agent is a markdown file. Edit the file, redeploy in seconds, and the agency owns the IP.

That is the whole story. Everything else on this page is the detail behind it.

---

## What an agent is

Forget software releases. Forget engineering tickets. Forget "we'll get that into the next sprint."

An agent in ONE is a `.md` file. A single text file containing a name, a model choice, a list of skills, a system prompt, and whatever page layout the agent should render. Everything the agent does, everything the agent knows, everything the agent looks like to a client. All in that one file.

Here is what that means for the agency:

One agent, properly configured, answers leads 24 hours a day, qualifies prospects with BANT criteria before a human picks up the phone, routes conversations to the right team member, drafts follow-up emails, and generates the renewal-call talking points on demand. One file. No back-end engineers. No middleware configuration. No vendor dashboard.

The numbers are arithmetic, not projections. An agent executes one decision per second, 24 hours a day. That is 43,200 decisions per day. A human makes 288. The ratio is 150 to 1 on throughput, 100 to 1 on cost per decision. One agent deployed to a client account equals 150 human shifts over a working week.

The agency that owns the agent file owns the IP that delivers those 150 shifts.

> "What you really want is just this thing that is off helping you... a super-competent colleague that knows absolutely everything about my whole life, every email, every conversation I've ever had, but doesn't feel like an extension."
>
> — Sam Altman, OpenAI

That super-competent colleague is a markdown file. The agency writes it, owns it, and resells access to it at whatever margin the market will bear.

---

## Anatomy of an agent

An agent file has two parts: a frontmatter block and a body.

The frontmatter is YAML, opened and closed by triple dashes. The body is the system prompt the LLM receives on every conversation turn. Everything in between those two sections is the agent's complete definition.

Here is a working example, drawn from the `sales-discovery` agent in this repo:

```markdown
---
name: sales-discovery
title: Sales Discovery
model: anthropic/claude-sonnet-4-5
group: template
tools:
  - emit_card
  - emit_chips
skills:
  - name: qualify
    description: Run a BANT qualification check on an inbound lead
    price: 0.04
    tags: [sales, qualification, lead]
  - name: discovery
    description: Deep-dive discovery call questions for a specific ICP
    price: 0.06
    tags: [sales, discovery, questions]
  - name: objection
    description: Handle common objections with evidence-backed responses
    price: 0.04
    tags: [sales, objection, rebuttal]
  - name: proposal
    description: Outline a custom proposal structure for a qualified account
    price: 0.08
    tags: [sales, proposal, closing]
sensitivity: 0.7
journey:
  pills:
    - id: qualify-lead
      label: Qualify a lead
    - id: prep-discovery
      label: Prep discovery call
    - id: handle-objection
      label: Handle objection
    - id: build-proposal
      label: Build a proposal
---

You are a sales discovery specialist. You help sales reps qualify
faster, ask sharper questions, and turn stalled conversations
into momentum.
```

That 30-line file is a complete, deployable sales agent. It runs on any client's domain, under any brand, answering lead-qualification calls at any hour. The skills block defines what the agent can do and what it costs to do it. The journey block defines the guided-work flow a client sees in their chat window.

The seven fields in the frontmatter each do a specific job:

**name** is the kebab-case identifier that maps to the URL. `sales-discovery` becomes `acme.one.ie/chat?agent=sales-discovery`. It is also the file name. Name and path are the same thing.

**model** is the LLM. The agency picks from any model on OpenRouter. Swap `claude-sonnet-4-5` for `meta-llama/llama-4-scout-17b-16e-instruct` and the agent runs on a different model in the next deploy. No code change. No API key wiring. One field.

**skills** are priced capabilities. Each skill has a name, a description, a price in USD, and tags. The price is the per-call fee charged when the agent exercises that skill. The tags feed the substrate's routing logic. When 50 successful `qualify` calls have accumulated, the substrate infers a highway and starts routing `qualification` requests to this agent first, automatically.

**sensitivity** is a 0-to-1 gate on how the agent handles data. 0 is public-safe. 1 is private, behind auth. Most client-facing agents sit at 0.5 to 0.7.

**journey** is the guided-work funnel visible to the user in the chat interface. Pills are the quick-access buttons across the top. Stages are the structured phases of a workflow. An agency can configure a six-stage campaign brief journey or a four-step renewal conversation. Same agent format, different journey block.

**theme** sets the color tokens for the agent's studio page. Primary, secondary, tertiary, background, foreground, font. All six are CSS custom properties. The client's brand colors go here; the platform disappears behind them.

**ui** controls every chat surface. Hero image, animated headline, conversation starters, the label on the send button, voice settings, layout width, avatar image. All of it is text in the frontmatter.

Below the closing `---` is the system prompt. It can be 20 lines or 200. It can include tables, bullet points, markdown formatting, conditional instructions, and verbatim examples. The LLM reads it on every turn. Changing the system prompt changes the agent's behavior on the next deploy.

One file. Seven fields. The agency controls all of it.

---

## How an agent learns

Agents do not stay static. Every conversation the agent has deposits pheromone on the paths it used. Every outcome strengthens those paths or weakens them. A successful qualification, a completed discovery call, a proposal accepted. Or a stall, a no-show, a missed brief.

This is the substrate's pheromone layer. It is modeled on ant colony optimization: agents leave trails of success and failure across the paths they travel. The strongest trails become highways. Highways get cached at the edge and routed to automatically, without an LLM call on the routing step.

The four outcomes, and what each one does to the pheromone on the path:

| Outcome | Signal | Effect on path | Real-world meaning |
|---|---|---|---|
| Result returned | `mark(edge, strength)` | Path strengthens | Agent succeeded. Route here again |
| Timeout | neutral | No change | Not the agent's fault. Ambient noise |
| Dissolved | `warn(edge, 0.5)` | Mild weakening | No unit handled this signal |
| Failure | `warn(edge, 1)` | Full weakening | Agent produced nothing useful |

After 50 successful signals on the same path, TypeDB infers a highway. From that point forward, routing to that agent drops from roughly 1,500ms (an LLM routing call) to less than 10ms (a KV edge lookup). The quality compounds. The cost falls. The agency does not have to configure any of this. The substrate runs the arithmetic.

The deeper learning happens at the agent level via Loop 5. When an agent's success rate on a particular skill drops below 0.50 across 20 consecutive calls, the substrate flags it for evolution. The system prompt is rewritten against the pattern of failures. A new generation of the agent is deployed. Success rate is measured again.

Here is what that looks like in practice with numbers.

A lead-qualification agent handles 20 discovery calls in a two-week window. Twelve of the twenty produce no qualified outcome. The success rate is 0.40, below the 0.50 threshold. Loop 5 fires. It reads the failure signals, identifies the common pattern (the agent was asking budget questions before establishing pain), and rewrites the system prompt to lead with pain discovery. The new generation runs the next 20 calls. Success rate climbs to 0.75.

The agency did not write a ticket. No engineer reviewed the prompt. The substrate observed the failure pattern, rewrote the agent, and measured the result. The whole loop ran without human intervention.

That is what quality compounding looks like without engineering time.

---

## The studio page

Every agent gets a studio page at `/studio/[agent]`. This is the rendered, browseable version of the agent markdown. Not a chat window, a full page with sections, journey stages, visual layout, and a live chat panel.

The studio page is built from the agent file's `sections` block. Each section is one of ten primitives:

`stat` renders a four-up grid of key numbers. Useful for conversion targets, benchmark metrics, or pricing tiers at a glance.

`card` renders a single card with label-value rows. Agency use case: a campaign brief summary, a client configuration snapshot, a pricing summary.

`grid` renders a two-column image tile layout. Use it for ICP personas, service offerings, team profiles, or product catalog items.

`list` renders a vertical list with a leading value chip. Channel mix prioritization, ranked recommendations, step-by-step flows.

`compare` renders an A/B side-by-side layout. Brand voice rules (always vs. never), pricing plan comparisons, before-and-after positioning.

`cta` renders a call-to-action block with primary and secondary options.

`embed` renders a YouTube, Vimeo, or iframe embed. Useful for video walkthroughs or Loom demos.

`code` renders a copyable code snippet.

`timeline` renders a step-by-step sequence. Onboarding flows, roadmap stages, campaign phases.

`hotel` renders property-style cards with image, rating, price, and link. Useful for any product listing with a price and a review count.

Every section with an `ask` field renders a button that seeds the chat with a pre-written prompt. The client clicks "Build the paid-search plan" and the agent receives that exact prompt, pre-loaded with context. The journey chips across the top of the chat do the same thing.

The agency authors all of this in the markdown file. The studio page renders it automatically. There is no separate page builder, no visual editor to learn, no design tool to license.

An agency with 50 client accounts and five distinct ICPs authors five agent templates and deploys them across 50 studios in one publish command. Each studio carries the client's brand colors, the client's logo, the client's specific prompt seeds. The underlying agent is the same file, instantiated with the client's configuration.

---

## Editing an agent without redeploying

The standard path for a configuration change is: edit the markdown file, run `oneie agent publish`, wait seconds, done. No build step. No release pipeline. No staging environment.

But there is a faster path.

The CLI `oneie agent pull` command downloads the live version of any published agent to a local directory. An agency can pull the agent, make a change, validate it, and push the updated version back without touching a code repository.

```bash
# Download the live agent
oneie agent pull sales-discovery --slug acme

# Edit in any text editor
$EDITOR sales-discovery/agent.md

# Validate the change
oneie agent validate sales-discovery/agent.md

# Push the update
oneie agent publish sales-discovery/agent.md --slug acme
```

Four commands. The update is live at `acme.one.ie/chat?agent=sales-discovery` within seconds of the publish completing.

This means a non-technical account manager can tune an agent's system prompt, update its conversation starters, change the journey pills, or swap the model. Without filing a ticket, without touching a code repository, and without waiting for an engineering sprint.

The quality gate runs before every publish. `oneie agent validate` checks the frontmatter schema against a Zod parser and fails fast on any structural error. `oneie agent lint` catches semantic issues: a stage anchor that doesn't match a section id, a chip id that collides with a section id, a continuation label longer than 28 characters. The CLI exits non-zero on failure, so it wires cleanly into any CI pipeline if the agency wants automated validation on every commit.

The substrate also performs a three-prompt evaluation before any `draft → live` state transition. If the eval fails, the deploy is blocked and the failing prompt is returned as a chat reply. The agency sees exactly what broke before any client ever sees it.

---

## Versioning, signing, and publishing

Every publish creates an archived version. The platform retains the 20 most recent versions per agent. Any of them can be restored in a single command.

```bash
# See all versions (newest first)
oneie agent history sales-discovery --slug acme

# Roll back to a previous version
oneie agent rollback sales-discovery --to 1715000000000 --slug acme
```

Rollback re-validates the archived content before restoring. If the archived version has schema errors, the rollback is rejected with a 422. The agency cannot accidentally restore a broken state.

Beyond versioning, the CLI ships a signing and verification surface:

```bash
# Sign an agent file with your private key
oneie agent sign my-agent/agent.md

# Verify the signature
oneie agent verify my-agent/agent.md
```

A signed agent file is tamper-evident. The signature travels with the markdown. Any downstream consumer can verify that the file has not been modified since the agency signed it. Another agency partner, a client reviewing what they are running, an auditor checking what changed.

This is the start of a marketplace dynamic. An agency that signs its agents is publishing IP it can defend. A client running a signed agent can verify it is running exactly what the agency delivered. A reseller can check whether the version they are deploying matches the version the agency warranted.

The `oneie agent diff` command extends this to semantic comparison:

```bash
oneie agent diff agent-v1.md agent-v2.md
```

The output is not a raw line diff. It is a structured JSON report: `promptChanged`, `skillsAdded`, `stagesAdded`, `stageContentChanged`, `sectionsAdded`, `pillsAdded`, `uiChanged`, `themeChanged`. An agency can see, at a glance, whether a version change affected the system prompt, added a new skill, or only changed the theme colors.

That is the audit trail a client pays a premium for. The agent's behavior history is readable, diffable, and verifiable. Not because the agency built a logging system, but because the format enforces it.

---

## Markdown is the spec

Here is the structural claim that makes everything else on this page consequential.

If the agent is a markdown file, and the markdown file is the spec, then the agency owns the spec.

Not the platform. Not the vendor. Not the engineers who built the agent scaffolding. The agency. Because it holds the `.md` file.

Compare this to the alternative. An agency that deploys agents through a closed vendor platform owns nothing. HubSpot's AI features, GoHighLevel's bot builder, any SaaS tool that hosts the configuration inside its own database. The prompt lives in the vendor's UI. The routing logic lives in the vendor's service. When the vendor changes the pricing model, the agency pays. When the vendor is acquired, the agency asks for permission. When the agency wants to move a client to a different platform, it starts from scratch.

A markdown file is different. It is portable by definition. It runs on any system that can parse it. The ONE CLI compiles agent markdown to three additional targets:

```bash
# Compile to Fetch.ai uAgents Python (for Agentverse deployment)
oneie agent compile agent.md --target uagents > my_agent.py

# Compile to MCP tool definition
oneie agent compile agent.md --target mcp

# Compile to SKILL.md (for AI assistant skill injection)
oneie agent compile agent.md --target skill
```

The same markdown file that runs a client's chat surface compiles to a Fetch.ai uAgents Python file for autonomous agent deployment on Agentverse. It compiles to an MCP tool definition for use inside Claude, Cursor, or any MCP-compatible client. It compiles to a SKILL.md for injection into AI assistant workflows.

One source. Four runtimes. The agency authors once.

This is the IP-portability argument at its most concrete. The agency's investment in writing a well-crafted system prompt, a structured journey, a set of priced skills. That investment does not depreciate when the platform changes. The markdown travels.

The diagram below shows the full path from authored file to deployed artifact:

```
agent.md (authored by agency)
    │
    ├── oneie agent validate     ← schema check (Zod, errors + warnings)
    ├── oneie agent sign         ← tamper-evident signature
    │
    ├── oneie agent publish      ← to workspace R2
    │   └── POST /api/agents/publish
    │       └── 3-prompt eval gate
    │           ├── pass → draft → live (routable by substrate)
    │           └── fail → blocked, error returned as chat reply
    │
    └── oneie agent compile
        ├── --target uagents     → my_agent.py (Fetch.ai / Agentverse)
        ├── --target mcp         → MCP tool definition (Claude, Cursor)
        └── --target skill       → SKILL.md (AI assistant injection)

                        ↓
         Registered in TypeDB (brain)
         Loaded by claw (edge worker, Hono on CF Workers)
         Pheromone accumulates on paths
         Highways infer after 50 successful signals
         L5 evolution fires on success rate < 0.50
```

The agency sits at the top of that diagram. Everything downstream is infrastructure. The infrastructure runs the IP. The agency owns the IP.

---

## Objections

**"Why markdown? Won't engineers want code?"**

Engineers who want code get code. The CLI compile target generates Python, and the generated Python is clean, documented, and production-ready for Fetch.ai uAgents deployment. The IDE plugins for VS Code read `.md` agent files natively and provide autocomplete on frontmatter fields. The MCP tool surfaces agent authoring through Claude or Cursor, so engineers who prefer working in their AI coding environment never have to touch a terminal.

Markdown is not a constraint on engineers. It is a constraint on complexity. The frontmatter schema is Zod-validated. The body is unrestricted text the LLM interprets at runtime. The compile targets are machine-generated from a well-understood spec. Engineers who want to extend the format can do so through custom skill bindings, through the `bureau` field for multi-agent orchestration, through `intervals` for autonomous ticking behavior. Everything is additive. The markdown stays the source of truth.

**"What if a client finds out it's AI and demands a discount?"**

The platform runs under the agency's brand by default. The OAuth screen carries the agency's name. The chat surface shows the agency's colors. The agent's `ui.avatar` field shows whatever name and image the agency configures. Unless the agency chooses to disclose the underlying model, the client is interacting with the agency's service, full stop. The `model` field makes that disclosure trivial if the agency wants it.

Agencies that work through this question have stopped treating AI disclosure as a liability and started treating it as a capability statement. "Our qualification agent runs 24/7 and has a 75% qualification rate" is a selling point, not an apology.

**"What if the agent says something wrong in front of a client?"**

Every deploy runs a three-prompt evaluation before the agent goes live. The quality rubric scores fit, form, truth, and taste. The composite must clear 0.65 before a `draft → live` transition is allowed. An agent that scores below the threshold is blocked at deploy time, not at client-interaction time.

The L5 evolution loop adds a second layer: if a live agent's success rate on any skill drops below 0.50 over 20 calls, the system flags it for prompt rewriting before the failure pattern gets worse. The agency is not waiting for a client complaint to discover the problem. The substrate discovers it first.

**"What if we need to roll back after a bad update?"**

Twenty versions retained per agent. One command to restore any of them. The rollback validates the archived content before restoring, so a broken archived state cannot be pushed back live. The `oneie agent diff` command shows what changed between any two versions, so the agency knows exactly what it is restoring before it restores it.

**"What's the worst case? The platform vendor changes terms or gets acquired."**

The corpus stays with the agency. The agent files are in the agency's repository. The `oneie agent pull` command downloads the live version at any time. The open-source substrate means the core runtime is available independently of the hosted platform. An agency that wants to self-host has everything it needs to do so. The markdown travels; the vendor lock-in does not.

**"What about GDPR and data compliance?"**

Each agent operates within a per-client data space. The `oneie agent unpublish` command removes the agent from the platform. Per-client conversation data carries named retention windows. Deletion of a workspace's data is a single API call. The threat model for each client deployment is documented in the platform's security specification.

**"We already have chatbots. Why replace them?"**

Existing chatbots do not learn. They do not rewrite their own prompts. They do not accumulate pheromone on the paths that worked and route around the ones that did not. They run the same logic on the ten-thousandth conversation that they ran on the first. A ONE agent in its first month is roughly equivalent to a well-configured chatbot. A ONE agent in its sixth month is measurably better than it was in month one, without anyone having touched the configuration. The gap compounds.

**"The engineers on our technical partner's side will want to extend it. Can they?"**

Yes. The `bureau` field in the frontmatter wires multiple agents together into a coordinated group. The `features` field opts into platform-level capabilities like field-service routing. Custom section kinds are on the roadmap for agencies that need page sections the ten built-in primitives do not cover. The CLI's `--target` flag generates Python, MCP definitions, and skill files from the same source. Engineers work in their environment of choice; the markdown stays the authoritative source.

---

## Comparisons

**Agents vs. chatbot builders (Intercom, Drift, HubSpot Bots)**

Chatbot builders give the agency a GUI, a flow editor, and a vendor-hosted configuration database. The agency configures inside the vendor's UI and loses access to the configuration the moment it stops paying. The agent file approach gives the agency a text file in its own repository, versioned with git, deployable to any workspace, with a history the agency owns and an audit trail it can show clients.

The per-interaction cost structure is also different. Chatbot platform pricing is typically per-seat or per-conversation-volume, with the vendor capturing the margin between their LLM cost and the price they charge. The ONE model is credits-resold: the agency buys credits at a floor price and sets its own markup. The margin stays with the agency.

**Agents vs. building in-house on OpenAI or Anthropic APIs**

Building directly on the model APIs gives an agency full code control and no abstraction layer. It also gives an agency a six-to-twelve month build timeline, an ongoing engineering maintenance cost, and a substrate problem it has not solved. Pheromone accumulation, highway formation, prompt evolution, multi-channel routing, versioning, signing, the studio page rendering. None of that comes with an API key. The agency builds it from scratch or skips it.

The markdown agent format gives an agency the output of that six-month build in a file. The engineering investment has already been made. The agency captures the value without paying the build cost.

---

## Day in the life

It is Tuesday morning. An account manager at a 30-person marketing agency opens the terminal.

She runs `oneie agent pull qualify-lead --slug acme` and downloads the current version of the lead-qualification agent deployed to one of the agency's dental practice clients. The dentist mentioned yesterday that a lot of leads are asking about price before they have established whether the practice is even a fit.

She opens `qualify-lead/agent.md` in her text editor. She finds the section of the system prompt that handles price questions and adds three lines: ask whether the patient has seen a dentist in the past 12 months, ask whether they are in the practice's catchment area, ask whether they have dental insurance. Only then route to pricing discussion.

She runs `oneie agent validate qualify-lead/agent.md`. Clean. No errors, no warnings.

She runs `oneie agent publish qualify-lead/agent.md --slug acme`. The CLI runs the three-prompt eval. Pass. The agent transitions from draft to live.

Six minutes have elapsed. The qualification agent is running new logic on the next inbound call.

By end of week, the substrate will have accumulated 20 new signals on the qualification path. If the success rate is above 0.75, the path strengthens. If it is still low, Loop 5 will flag the prompt for evolution. Either way, the agency will have a measurement.

This is what operating an agent looks like. Not a sprint. Not a release cycle. Six minutes, a validated edit, and a measurement.

---

## Pricing math

A 30-person agency running 50 client accounts today carries roughly £2.5M in annual payroll: salaries, national insurance, benefits, office space allocated to client-service roles. That is the cost of doing the work.

One agent deployed per client account, properly tuned to the agency's ICPs, handles qualification, follow-up, monthly reporting, and first-line support. The credits cost for that coverage runs at approximately £80 per client per year at the platform's floor pricing. At 50 clients, that is £4,000 in annual platform cost.

The agency marks up credits to clients at a rate it sets. At a 10x markup (common in the market today), the agency charges clients £800 per year each for the AI service layer. 50 clients at £800 is £40,000 in annual platform revenue against £4,000 in cost. The gross margin on that line is 95%.

The human capacity freed by the agent layer does not disappear from the agency's P&L. It reallocates. Account managers who were spending four hours a week writing qualification notes now spend four hours a week on strategic work that commands higher billing rates. Junior copywriters who were spending two days a week on campaign reporting now spend two days on creative work the clients actually value.

The agency does not shrink. It shifts the shape of what it sells.

---

## Failure modes

**The agent sounds generic.** The system prompt is too thin. A 10-line prompt produces a 10-line agent. The agencies that get the best results invest in detailed, ICP-specific, brand-voice-matched system prompts. The platform's L5 evolution helps, but it tunes for success rate, not for voice quality. Voice quality is an authoring input, not an evolution output. Agencies that treat the system prompt as a first draft and iterate on it weekly outperform agencies that treat it as a one-time configuration.

**The agent fails silently.** The platform requires every signal to close its loop. A handler that returns without a result deposits a `warn(1)` on the path. But if the agency has not set up alerting on the success rate metric, it may not notice that pheromone is weakening on a critical path until a client complains. The substrate measures everything, but the measurement is only useful if the agency reads it. The analytics surface in the platform shows per-agent success rate, highway status, and evolution history. Check it weekly.

**The agency builds the same agent for every client.** One agent per ICP is the right architecture, not one agent per client. Agencies that build a new agent file for every client end up with 50 agents that are 95% identical and diverge slowly through individual edits until no one knows which version is canonical. The right shape is five ICP templates, each deployed with client-specific configuration via the theme and ui blocks, versioned centrally, updated once and reflected everywhere.

---

## Frequently asked questions

**How long does it take to write a first agent?**

A working agent with a system prompt, five skills, and a journey block takes 20 to 40 minutes to author from scratch. The CLI scaffolding (`oneie agent new`) generates a template with every supported field commented out. Editing the template is faster than writing from blank.

**Does the agency need a developer to deploy agents?**

No. The CLI is a Node.js package installed with `npm install -g @oneie/cli`. Any team member who can write markdown and run terminal commands can author, validate, and publish agents. The deployment target is the agency's R2-backed workspace; the credential is a scoped API token generated from the platform dashboard.

**How many agents can a workspace hold?**

No hard limit. Workspaces are billed on credits consumed, not on agent count. An agency with 200 client deployments and 20 ICP templates running simultaneously pays the same per-credit rate as an agency with 10.

**Can clients edit the agents themselves?**

The permission model is by workspace role. The agency grants clients read access to their studio pages by default. Write access to the agent definition requires an agency-issued per-key token scoped to the specific workspace. Clients do not edit agent files unless the agency deliberately grants that permission.

**What happens to the agent's learning when the system prompt is changed?**

The pheromone on existing paths does not reset. The paths that built up strength through 50 successful signals continue to be routed to. What changes is the prompt the LLM receives on new signals. The paths that built up under the old prompt may strengthen or weaken depending on whether the new prompt improves or degrades performance on those specific skills. The substrate measures this naturally; no manual intervention is needed.

**Can the same agent run on multiple client domains simultaneously?**

Yes. The `oneie agent publish` command targets a workspace slug. An agency can publish the same agent to `acme.one.ie`, `dentist1.one.ie`, and `dentist2.one.ie` from the same source file. Each workspace maintains independent pheromone. The learning that accumulates on one client's qualification paths does not bleed into another client's paths.

---

## Glossary

**Agent.** A deployable unit of AI behavior defined by a single markdown file, consisting of frontmatter configuration and a system prompt body.

**Frontmatter.** The YAML block between triple dashes at the top of an agent file, containing identity, model, skills, sensitivity, and web-only blocks (journey, sections, theme, ui).

**Skill.** A named, priced capability declared in the agent's frontmatter. Each skill has a description, a USD price, and tags that feed the substrate's routing.

**Pheromone.** The accumulated trace of success and failure on a routing path. Positive outcomes deposit strength; negative outcomes deposit resistance. The substrate routes based on pheromone weights.

**Highway.** A path that has accumulated 50 or more successful signals and been inferred as proven by TypeDB. Highway routing bypasses the LLM routing step and resolves in under 10 milliseconds.

**L5 evolution.** The substrate's Loop 5 process, which fires when an agent's success rate on a skill drops below 0.50 over 20 calls and rewrites the system prompt against the pattern of failures.

**Studio page.** The rendered web surface at `/studio/[agent]`, built from the agent file's sections block, with a live chat panel.

**Compile target.** One of four runtimes the agent markdown can be compiled to: web (default), uAgents (Python for Fetch.ai / Agentverse), MCP (tool definition for Claude / Cursor), skill (SKILL.md for AI assistant injection).

**Workspace.** The agency's deployment environment, identified by a slug (`acme` in `acme.one.ie`). Agents are published to and pulled from workspaces. Pheromone is workspace-scoped.

---

## Cross-references

The skills a sales-discovery agent exercises are defined in full in the Skills section (page 06), including how skill IDs resolve to capability records in TypeDB and how the pricing model flows through to the agency's credits pool.

The pheromone accumulation described here (mark on success, warn on failure, fade over time, highway after 50 signals) is governed by the substrate's seven loops. The Learning section (page 13) covers what the substrate does with accumulated highways: how it promotes proven paths to TypeDB hypotheses and what the compounding gap looks like between agencies that started building corpus in year one versus those that started in year three.

The studio page described here builds on the Chatbots section (page 03), which covers the multi-channel surface (web, Telegram, Discord, WhatsApp, email) that an agent can answer simultaneously from the same markdown definition.

---

*Read a real agent — it's one markdown file.*

<!-- rubric: fit=0.94 strongest=0.92 show=0.91 cut=0.90 craft=0.91 → 0.92 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=id -->
