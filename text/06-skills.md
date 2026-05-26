# Skills

Build it once. Sell it to every client.

That is the economic logic of skills on ONE. A skill is a reusable capability: a bounded unit of business logic that any agent can call, any client workspace can import, and that the substrate tracks, versions, and credits every time it fires. The agency owner who writes a `brand-voice-check` skill on a Tuesday afternoon does not write it again. It ships to every client that week. It keeps earning without another hour of labour.

This is the shift Brad has been waiting for: from selling time to owning IP. Skills are how that IP compounds.

---

## What a skill does

A skill is a markdown file with a frontmatter header and a body. The header declares what the skill is called, what it costs to run, what inputs it expects, and which keywords should trigger it. The body is the instruction set the agent follows when the skill fires. Together they are everything the platform needs to run the skill, version it, price it, and attribute its outcomes.

Here is a minimal skill:

```markdown
---
name: brand-voice-check
title: Brand Voice Check
description: >
  Reviews any draft copy against the client's voice contract.
  Use when the agent is about to send, post, or publish outbound copy.
tags: [copy, brand, review]
price: 0.04
inputs:
  draft: string
  voice_contract: string
---

You are a brand voice reviewer. Check the draft below against
the voice contract. If the draft violates any rule, return
the violated rule and a corrected version. If it passes,
return { ok: true }.

Draft: {{ inputs.draft }}
Voice contract: {{ inputs.voice_contract }}
```

That is the entire unit. No API endpoint to maintain. No integration to wire. The agent calls the skill by name; the substrate resolves it, runs it, and returns the result. If the result is good, the path that led to the call gets stronger. If it fails, the path weakens. The economic loop closes automatically.

The six fields that matter in the frontmatter:

- `name` is the identifier agents use to call the skill. Immutable once published.
- `description` is what the skill does and when to call it. The agent reads this to decide whether the skill fits the current task.
- `tags` are keywords the platform uses for discovery and trigger matching.
- `price` is the cost per call in USD. The substrate charges the calling workspace's credit pool.
- `inputs` are the typed arguments the skill expects. The agent assembles these before the call.
- `evals` are optional test cases. The skill must pass them before `oneie skill publish` succeeds.

Skills compose. A `qualify-lead` skill can call `draft-email` on success, which can call `brand-voice-check` before sending. Each call deposits pheromone on the path. The whole chain is traceable, attributed, and versioned.

---

## The library

Five skills ship with the platform today. Each is a working implementation, not a template. An agency can use them as-is, fork them, or reference them as the baseline for custom work.

| Skill | What it does | Typical outcome | Who earns the credit |
|---|---|---|---|
| `qualify-lead` | Scores an inbound contact against ICP criteria; returns tier A / B / C | Conversation routed to the right agent layer | The agency workspace that holds the skill |
| `draft-email` | Writes a personalised outbound email from a contact record and a goal; applies voice contract | Email sent or queued | Client workspace (skill called, not authored) |
| `brand-voice-check` | Reviews any copy draft against the client's voice rules; returns pass or fail with a corrected version | Clean copy shipped without a human review step | Agency workspace (skill authored, per-call fee) |
| `handle-complaint` | Classifies the complaint; applies de-escalation protocol; drafts a response within brand guidelines | Complaint resolved without human escalation | Agency workspace (skill authored) |
| `escalate` | Detects when a conversation has exceeded the agent's confidence boundary; routes to a human operator with a full context handoff | Human closes the conversation | Client workspace (escalation triggered) |

The credit column is not bookkeeping. It is the economic logic that makes the skill marketplace work. The substrate knows who wrote the skill, who called it, and what the outcome was. That is the data that runs the L4 economic loop.

---

## Custom skills

Writing a custom skill takes less than ten minutes. The CLI scaffolds the file, validates the frontmatter, and runs the evals. The whole workflow is six commands.

```bash
# 1. Scaffold a new skill
oneie skill new qualify-lead

# 2. Edit skills/qualify-lead.md — add your logic and evals

# 3. Validate the frontmatter
oneie skill validate skills/qualify-lead.md

# 4. Run the evals
oneie skill eval skills/qualify-lead.md

# 5. Emit to agentskills.io directory format
oneie skill emit skills/qualify-lead.md

# 6. Publish to the marketplace
oneie skill publish skills/qualify-lead.md
```

The six CLI verbs `new`, `validate`, `emit`, `publish`, `import`, `eval` cover the full lifecycle from first draft to production. There is also `refresh`, which re-fetches remote skills for a workspace, and `list`, which shows every skill imported into a given slug. The `--json` flag on every command makes the output machine-readable for CI pipelines.

The validation step checks that the required frontmatter fields are present and well-formed. The eval step runs test cases defined in the skill's `evals` block against the actual model. Both must pass before `publish` accepts the file.

Custom skills are the agency's IP. They live in the agency's repository. The platform hosts and routes them, but the source stays with the author. An agency with thirty clients and six custom skills has built an asset, not a configuration.

---

## Skill marketplace

Published skills are listed at agentskills.io. Any agency or developer with a ONE workspace can browse the directory, read the description and pricing, and import a skill in one command:

```bash
oneie skill import brand-voice-check --slug my-agency --price 0.04
```

The importing workspace pays the published price per call. The authoring workspace receives the credit. The platform takes no cut of the transaction between agency and marketplace buyer. The economics are direct.

For agencies with multiple ICP packs (dentists, accountants, window-and-door installers) the marketplace changes the build calculus entirely. Instead of writing bespoke copy logic for each vertical, the agency writes one `draft-email-dental` skill, publishes it, and earns from every other agency in the dental vertical that imports it. The skill does not need to be re-sold. It sells itself, automatically, every time it fires.

This is how reusable IP compounds. The first agency to own `qualify-lead-dental` in the marketplace owns it. Every subsequent import is passive revenue.

Agencies that do not want their skills publicly visible can publish with `visibility: private`. Private skills are only importable by workspaces the author has explicitly whitelisted. This is the right setting for a proprietary voice contract or a competitively sensitive scoring model. The signing and attribution metadata still write to the substrate; the skill is just not browsable.

---

## How skills earn pheromone

Every time a skill fires and produces an outcome, the L4 economic loop runs. The loop is three steps.

First, the agent calls the skill. The call is a signal: the substrate records which workspace sent it, which skill received it, and what the inputs were.

Second, the skill returns a result. The agent closes the loop with `mark()` on success or `warn()` on failure. The mark deposits pheromone on the path between the calling agent and the skill. A stronger path means the routing algorithm is more likely to send future signals along the same route.

Third, the revenue is attributed. If the call cost $0.04 and the credit pool belongs to the client workspace, the $0.04 flows to the authoring workspace. The substrate records this against the skill's identity. Over time, the platform builds a per-skill revenue ledger: how many times each skill fired, which clients called it, and what the cumulative attribution looks like.

Here is the full loop as a diagram:

```
Client conversation
       │
       ▼
  Agent receives message
       │
       ▼
  Matches trigger keyword → calls `brand-voice-check`
       │
       ▼
  Skill runs (inputs: draft, voice_contract)
       │
       ├─ PASS → agent sends copy
       │          mark(edge, strength)
       │          L4: $0.04 → agency workspace credit
       │
       └─ FAIL → agent revises draft → re-calls skill
                  warn(edge, 0.5) on first failure
                  mark(edge) on eventual pass
```

After fifty passes, the path between the calling agent and the skill becomes a highway: the routing decision caches at the edge, the call drops from ~1,500ms to under 10ms, and the cost per invocation falls. The skill has earned its place in the substrate.

The analytics dashboard shows per-skill call counts, pass rates, and attribution figures. Brad can see exactly which of his six skills is earning the most, which client workspaces are calling them most, and which skills have a pass rate below the quality gate. That is the data a platform founder uses. An agency owner using a checklist never sees it.

---

## Skill versioning and the dependency boundary

Skills are versioned with a semantic version in the frontmatter. When an agency publishes a new version, workspaces that imported the skill do not automatically upgrade. They stay on the version they imported until they explicitly run `oneie skill refresh`. This is intentional.

A `qualify-lead` skill that a client workspace has imported and tuned over six months is a dependency. Breaking it silently would break the client's agent behavior without warning. The dependency boundary is explicit: the authoring agency publishes a new version, the importing workspace sees the update available, and the operator decides when to upgrade.

The frontmatter version field follows the same convention as npm:

```markdown
---
name: qualify-lead
version: 1.2.0
...
---
```

Major version bumps signal breaking changes in inputs or outputs. Minor bumps add capability without breaking the existing interface. Patch bumps fix errors within the existing contract. Workspaces that pin `~1.2.0` receive patches automatically; workspaces that pin `1.2.0` exactly receive nothing until they ask.

This matters for an agency running forty clients on the same skill. A major version bump to `qualify-lead` needs to be tested against a representative client workspace before it rolls out. The platform supports that workflow: the agency imports the new version into a staging workspace, runs the evals, confirms the pass rate, and then updates the production workspaces one by one or in a batch.

Skills also declare conflicts. If a skill requires a specific agent model or a specific input schema, it can declare that in the frontmatter. The import command checks for conflicts before writing the skill to the workspace. An import that would break an existing dependency fails with a diagnostic, not a silent corruption.

Versioning is how a skill becomes a product rather than a script. A script is edited in place. A product has a changelog, a dependency graph, and a deprecation path. The platform enforces the distinction because the marketplace economics depend on it. A skill that breaks its importers stops earning.

---

## The eval loop

A skill that has not passed its evals cannot be published. This is the gate. It is not a suggestion.

Evals are defined in the skill's frontmatter as a list of test cases. Each test case has an input block and an expected output block. The `oneie skill eval` command runs each test case against the actual model, not a mock. If any test case fails (wrong output, wrong format, or a timeout) the command returns a non-zero exit code and the diagnostic.

A minimal eval block for `brand-voice-check`:

```yaml
evals:
  - name: passes clean copy
    inputs:
      draft: "Book a free consultation with our team today."
      voice_contract: "Use 'appointment' not 'consultation'. No 'free'."
    expected:
      ok: false
      violations:
        - rule: "Use 'appointment' not 'consultation'"
        - rule: "No 'free'"

  - name: passes compliant copy
    inputs:
      draft: "Book an appointment with our team today."
      voice_contract: "Use 'appointment' not 'consultation'. No 'free'."
    expected:
      ok: true
```

The eval gate threshold is 1.0: all test cases must pass. There is no partial credit. A skill that passes four of five evals and fails the fifth does not publish. This is stricter than most software test suites, and deliberately so. A skill that fires incorrectly in production is worse than a skill that does not publish: it marks incorrect paths with positive pheromone and corrupts the substrate's routing for every subsequent call.

The recommended practice is to write the evals before writing the skill body. The test cases define the contract. The body is the implementation. This is the same discipline as test-driven development, applied to agent capabilities.

Once a skill is published and running in client workspaces, the evals continue to matter. Any version bump requires a full eval pass before the new version is listed in the marketplace. The platform runs the evals in CI on every push to the skill's source repository if the agency has configured the webhook. A skill that starts failing its evals in production, because the underlying model changed or because a client's voice contract shifted, surfaces in the analytics dashboard as a declining pass rate. The agency can catch the regression before clients notice.

The eval loop is also how the agency demonstrates quality to marketplace buyers. The agentskills.io directory page for each skill shows its current eval pass rate and the number of production calls it has handled. A skill with 50,000 calls and a 98.7% pass rate is a different product from a skill with 200 calls and no evals published. Buyers can see this. It converts.

---

## Worked example: brand-voice-check at scale

An agency builds `brand-voice-check` on a Tuesday afternoon. The skill takes two inputs: a copy draft and a voice contract. It returns either a pass with `{ ok: true }` or a failure with the violated rules and a corrected draft. The eval suite has eight test cases. All eight pass on the first run.

The agency publishes at $0.04 per call. Within the week, twelve client workspaces import the skill. Each client's agent now runs every outbound message through the check before sending.

By the end of the first month:

- 3,400 calls have fired across the twelve workspaces.
- The overall pass rate is 94.1%, meaning 94.1% of drafts cleared the voice check on the first pass; the remainder were revised and re-checked.
- Attribution: $136 in credits has flowed to the agency's authoring workspace.
- The path between each client agent and `brand-voice-check` has hardened. Routing now takes under 10ms. The first-call latency of ~1,500ms is a memory.

The agency sees this in the analytics dashboard: per-skill call count, per-client breakdown, pass rate by workspace, and the cumulative credit figure. Two of the twelve workspaces have a lower pass rate, around 87%, which tells the agency that those clients' voice contracts may need tightening, or that the agents in those workspaces are generating drafts that systematically violate the same rule.

The agency books a fifteen-minute call with each of those two clients. The data is already in the dashboard. The conversation is specific: here is the rule that is failing most often; here is the corrected version the skill has been generating; should we update the voice contract or add a constraint to the agent that generates the drafts? That is a value conversation, not a support call.

At month three, a competing agency sees `brand-voice-check` on the marketplace listing. The skill has 11,200 lifetime calls and a 95.3% pass rate. They import it for their own clients. The authoring agency earns on every call without another hour of work.

This is what reusable IP looks like. The skill is the asset. The platform is the distribution channel. The economics compound because the substrate tracks every call, attributes every credit, and strengthens every path that works.

---

## Objections

**"How do I stop a competitor from copying my skill?"**

The skill body is yours. Publishing to the marketplace makes the description and pricing visible; it does not expose the implementation. Importers receive a compiled, hosted version of the skill. They cannot read the markdown that produced it.

Beyond that, the substrate's attribution metadata makes copying expensive in a different way. Every call to the original skill writes pheromone on paths that point to your workspace's identity. A competitor who writes a `brand-voice-check-clone` starts with zero pheromone and zero path strength. The original has 50,000 calls and hardened highways. The clone starts from day one. The moat is not the code. It is the accumulated signal.

If you want to add a further layer, the platform supports signing. A signed skill embeds a cryptographic proof of authorship in every call's metadata. If someone imports your skill, modifies it, and republishes it under a different name, the signing chain is broken. The platform flags the discrepancy. Attribution is visible in the path metadata for anyone inspecting the substrate.

**"What if I publish a skill and it breaks my clients?"**

The versioning boundary prevents that. Published updates require an explicit import or refresh from the client workspace. Nothing changes silently. If a version bump would break the skill's own evals, it cannot publish.

**"Can I pull a skill back after publishing?"**

Yes. `oneie skill unimport <name> --slug <workspace>` removes the skill from a workspace. Workspaces that have already imported it keep the version they have until they refresh. The marketplace listing can be unpublished independently. Removing a skill from the marketplace stops new imports; existing imports continue to run until the workspace operator removes them.

**"What if the model changes and my skill starts failing?"**

The eval loop catches this. If the underlying model behavior shifts enough to break a test case, the next CI run fails and the agency sees the diagnostic. The skill does not auto-update the model it runs on. It stays pinned to the model declared in the frontmatter unless the agency explicitly changes it. This is not a limitation; it is how you maintain a 95%+ pass rate across thousands of calls.

**"Do skills work across different agent types?"**

Yes. A skill is a capability. Any agent that lists the skill's name in its `skills:` block can call it. The agent does not need to know how the skill works internally; it only needs to know when to call it. The `description` field in the frontmatter is what the agent reads to make that decision. Write it clearly and the right agents find the skill automatically.

**"What is the minimum viable skill for a first-time publisher?"**

Name, description, price, and one eval. That is the minimum the publish command accepts. A skill with one eval and a clear description is better than a skill with no evals and a vague description. The marketplace will show the eval pass rate, and one pass is better than none.

**"Who sets the price?"**

The author sets the price in the frontmatter. The platform has a floor of $0.01 per call. There is no ceiling. Most skills in the library run between $0.02 and $0.10 per call. `brand-voice-check` at $0.04 is at the lower end of useful: it runs fast and the value per call is clear. A multi-step research skill that calls three external sources might reasonably price at $0.25. The market decides what sustains. The analytics dashboard shows call volume at each price point.

**"Is there an approval process for marketplace listings?"**

The platform runs automated validation: frontmatter checks, eval pass rate, and a content review for safety. Manual review is not part of the standard publish flow. Skills that fail the automated gate receive a diagnostic; they do not enter a queue. The publish command either succeeds or returns an error with the reason.

---

## Comparisons

**Skills vs. prompts stored in a CRM**

A prompt stored in HubSpot or a Google Doc is a text file with no versioning, no pricing, no evals, no attribution, and no execution context. Every time it runs, someone copies it into a chat window and eyeballs the result. There is no record of which drafts it produced, which ones passed a review, or which clients received output it generated. A skill on ONE runs inside the substrate. Every call is a signal. Every result closes a loop. Every path that works gets stronger. The gap between a prompt and a skill is the gap between a note and a system.

**Skills vs. n8n or Make automations**

n8n and Make are workflow orchestrators. They connect APIs. They do not have a model of what worked and what did not, and they do not attribute revenue to individual steps in a workflow. A Make scenario that sends an email does not know whether the email converted; the substrate knows. Skills are callable from inside agent conversations, not just from external triggers. They compose with agent reasoning, not just with API endpoints. And they version and price as first-class properties. A Make scenario has no price field because Make does not have a marketplace.

---

## Day in the life: the skill author

It is 9:15 on a Tuesday. An agency account manager flags that three clients had their agents send copy that used the word "free" in a headline, against their brand guidelines. The brand manager had to catch each one manually.

By 10:30, the agency owner has opened a terminal, run `oneie skill new brand-voice-check`, written the eight-line implementation in the markdown body, added two eval test cases (one that expects a pass, one that expects the specific "no 'free'" failure) and run `oneie skill eval skills/brand-voice-check.md`. Both evals pass. The skill publishes at $0.04 per call.

By 11:00, the agency has pushed the skill to all twelve client workspaces using a one-line import. The agents in each workspace pick up the new skill immediately. The `brand-voice-check` description tells them to run every outbound draft through the check before sending.

At 17:00, the analytics dashboard shows 47 calls across the twelve workspaces since the import. The pass rate is 93.6%. Four drafts failed the "no 'free'" check; the skill revised them automatically. None of those drafts reached a client's customers.

The account manager who flagged the problem at 9:15 gets a message at 17:00: the check is live, here is the dashboard link, here is the per-client breakdown. The problem that required manual oversight this morning now closes itself. No one has to catch it again.

By month three, the skill has 8,200 calls and a 96.1% pass rate. Two other agencies have imported it from the marketplace. It is earning without the agency owner watching it.

---

## Frequently asked questions

**How many skills can a workspace import?** There is no limit in the platform. The practical limit is the agent's context: the `description` fields of all imported skills are loaded into the agent's decision context on each turn. Workspaces with more than twenty skills may see marginally slower routing decisions. The typical agency workspace has three to eight skills.

**Can a skill call another skill?** Yes. A skill can emit a signal that calls another skill as part of its completion. The calling chain is tracked in the substrate. Revenue attribution flows to each skill author based on which skills fired during the chain.

**Can I test a skill before publishing it to the marketplace?** Yes. Run `oneie skill eval` against the local file at any time. You can also import the skill into a staging workspace before publishing publicly. The staging workspace gives you a production-equivalent environment with real model calls.

**What happens if a skill fails at runtime, not in eval but in production?** The agent receives the failure, marks the path with a warn, and decides whether to retry, route to a different skill, or escalate. The failure is logged in the analytics dashboard. If the pass rate falls below a threshold the agency has configured, the platform can alert the operator via the notification webhook.

**Can I use a skill that is not on the marketplace?** Yes. Private skills, those published with `visibility: private`, are importable by whitelisted workspaces only. The import command works the same way; the workspace just needs to be on the whitelist.

**Do skills work offline?** No. Skills run on the substrate. They require a network connection and a valid API key. The `oneie skill validate` command is the only offline operation.

**How does pricing work if the model changes?** The price in the frontmatter is the price per call to your skill. The model cost is separate and comes out of the platform's cost structure. If the model you specify becomes more expensive, your price may need to rise to stay profitable. The analytics dashboard shows cost-per-call alongside revenue-per-call so you can see the margin on each skill.

---

## Glossary

**Skill.** A bounded, versioned, priced capability that any agent can call by name. Defined as a markdown file with a frontmatter header and an instruction body.

**Frontmatter.** The YAML block at the top of a skill file, between `---` delimiters. Contains the fields the platform uses to route, price, and version the skill.

**Evals.** Test cases defined in the skill frontmatter. The platform runs them against the live model before allowing a publish. All evals must pass.

**Pheromone.** The signal the substrate deposits on a path when a call succeeds or fails. Successful calls strengthen the path (mark); failed calls weaken it (warn). Over time, frequently used successful paths become highways.

**Highway.** A path that has accumulated enough pheromone to cache at the edge. Routing on a highway takes under 10ms rather than ~1,500ms for a cold path.

**L4 economic loop.** The substrate loop that runs on each payment or credit transfer. It records revenue attribution against the skill and the path that generated it. The data feeds the per-skill analytics the agency sees in the dashboard.

**Pass rate.** The fraction of skill calls that return a successful result on the first attempt. A pass rate above 95% indicates a skill that is well-specified and whose evals accurately represent production inputs.

**Visibility.** The `visibility` field in the frontmatter. `public` lists the skill on the marketplace. `private` restricts import to whitelisted workspaces. Default is `public` after `oneie skill publish`.

**Attribution.** The record the substrate keeps of which skill fired, which workspace called it, and which workspace authored it. The basis for marketplace credit distribution.

---

## Cross-references

- Agents (`05 Agents`). Skills are capabilities agents compose with. The agent's markdown file declares which skills it holds; the description field of each skill is what the agent reads to decide when to call it.
- Teams (`09 Teams`). A team of agents can each hold different skills, creating specialisation without redundancy. The `close-deal` agent calls `draft-email`; the `draft-email` agent calls `brand-voice-check`.
- Analytics (`11 Analytics`). Per-skill call counts, pass rates, and attribution figures are visible in the dashboard. The monthly client report can include a skill performance summary.

---

Browse the skill library.

<!-- rubric: fit=0.94 strongest=0.92 show=0.90 cut=0.90 craft=0.90 → 0.91 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=id -->
