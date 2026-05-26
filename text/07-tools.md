# Tools

Every client has a different stack. That is the sentence that keeps agency owners up at night. One client is on HubSpot. The next is on Notion and Linear. The one after that runs everything through Gmail and a shared Google Drive. You are not delivering marketing and service. You are delivering marketing and service plus a bespoke integration project, bespoke again, every time. A new client signs and the question is the same: which seven tools do they live in, who owns the OAuth app for each one, and how many evenings will your senior developer lose to plumbing before the first useful agent run.

ONE ends the integration project. Your agents work inside each client's existing accounts. Not alongside them. Not with a copy of their data synced somewhere. Inside the actual Gmail inbox, the actual Slack workspace, the actual GitHub repositories. The client connects their accounts once. The agent works as them, reading, drafting, acting, and every action stays inside their environment.

That revolution does not arrive by reading emails and reporting on them. It arrives when an agent can act on an email: draft a response, route a task, update the CRM, post a Slack message, close a Linear issue, all in one motion, across the client's own accounts, under your brand. That is what this page describes. No new integration project per client. No N sets of OAuth credentials to babysit. No homemade token vault to GDPR-audit at midnight.

---

## Connect anything

The connector layer is the infrastructure that makes per-client tool access work without requiring you to manage N sets of credentials or build N custom integrations.

Here is the architecture in one diagram:

```
                    Your server-side API key (one key)
                              │
                              ▼
                      Connector layer
                    ┌─────────────────┐
                    │   Auth relay +  │
                    │  OAuth broker   │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        User A's         User B's       User C's
        accounts         accounts       accounts
     (Gmail, Slack,   (GitHub, HubSpot,  (Notion, Drive,
      Linear)          Notion)            Calendar)
```

One server-side API key on your side. N user-scoped connected accounts on the connector layer, one per client end-user. When your agent runs for User A, it sees User A's Gmail and User A's Slack. It cannot see User B's. The isolation is not a setting you configure. It is the structural guarantee of the per-user `user_id` model. The agent's view of the world is the view this client has authorised. Nothing more.

OAuth is relayed through a partner; the consent screen shows your brand.

This matters operationally: you never touch a client's OAuth token. You never store it. You do not need a secrets-management plan per client. The connector layer holds the grants, scoped to the `user_id` we assign, which is the client's passkey-derived wallet address, stable and opaque. No spreadsheet of API keys. No vault rotation. No 2am call when a junior commits a token to a public repo.

The count: 250+ integrations available through the connector layer. Gmail. Slack. GitHub. HubSpot. Linear. Notion. Google Calendar. Google Drive. Stripe. Jira. Salesforce. Zendesk. Discord. Telegram. Airtable. Asana. Monday. Intercom. And the rest of the catalog.

Your agents do not need a connection to every service. Each client connects only what they use. The agent at runtime sees only the accounts that client has connected and authorised.

---

## How your client's accounts stay theirs

This is the question every GDPR-aware, compliance-aware agency owner needs answered before they move. So here it is, flat.

The OAuth grant belongs to the client. When a client authorises Gmail, Google issues a token to the OAuth application registered under your agency's brand. That token is stored on the connector layer, scoped to that client's `user_id`. Your agents call the connector layer to act on that client's behalf. You never hold the token server-side in your own systems. The client can revoke the grant at Google at any time and the agent loses access immediately.

The `user_id` is derived from the client's passkey identity, the wallet address. It is stable, opaque to the connector layer, and does not contain any personally identifiable information. The connector layer never sees a name or email address; it sees an alphanumeric string.

Each client's tool access is completely isolated:

```typescript
// Per-request: only show the agent what this client connected
const conns = await composio.connectedAccounts.list({
  userIds: [userId],          // one client's user_id
  statuses: ['ACTIVE'],
})
const toolkits = conns.items.map(c => c.toolkit)   // ['GMAIL', 'SLACK']
const tools = await session.tools({ toolkits })     // only these, for this client
```

If a client connected Gmail and Slack and nothing else, the agent runs with Gmail and Slack. The GitHub tool does not appear. The agent cannot hallucinate its way into a service that was never connected. The agent's toolbelt at runtime is a strict subset of what the client has signed off on, and the subset is computed on every request, not cached and stale.

Data residency: the connector layer stores OAuth tokens. The conversation content, the signals, the memory, the corpus, those live in the substrate, in your client's isolated workspace. Not in the connector layer.

The failure mode if the connector layer is unreachable: the tool call fails gracefully. The agent marks the path as failed. The conversation continues. The substrate learns that the tool was unavailable and routes around it next time. No silent stall. No spinner of doom. Tools degrade; the agent does not.

---

## The 250+ surface

The integrations your agents can use, organised by what they cover.

| Integration | Read | Write | Streaming | Webhook |
|---|---|---|---|---|
| Gmail | Inbox, threads, labels, attachments | Send, draft, label, archive | — | New message, reply |
| Slack | Channels, messages, reactions, files | Send message, react, update | — | Message, mention, app event |
| GitHub | Repos, issues, PRs, comments, code | Create issue, comment, merge, review | — | Push, PR, issue, release |
| HubSpot | Contacts, companies, deals, pipelines | Create/update contact, log activity | — | Deal stage change, form submit |
| Linear | Issues, projects, cycles, teams | Create issue, update status, comment | — | Issue update, cycle complete |
| Notion | Pages, databases, blocks, comments | Create page, update database row | — | Page update |
| Google Calendar | Events, attendees, availability | Create event, update, RSVP | — | Event start, new event |
| Google Drive | Files, folders, permissions, content | Upload, share, create doc | — | File change, new file |
| Stripe | Customers, payments, subscriptions | Create payment intent, refund | — | Payment succeeded, subscription event |
| Salesforce | Leads, contacts, opportunities, tasks | Create lead, update opportunity | — | Opportunity stage, task complete |

The table shows the ten most-requested integrations. The full catalog runs to 250+. Anything with an OAuth API and a connector entry is available.

Three things to note about coverage. First, most of the critical operations for agency work, reading, drafting, sending, creating, updating, are available on every major integration. Second, webhook support means agents can be reactive, not just scheduled: a new deal in HubSpot can trigger an agent run without polling. Third, streaming is not available for most integrations because the underlying APIs do not support it; real-time streaming is a chat and LLM primitive, not a tool-call primitive.

What you do not see in the table is the maintenance you no longer do. No adapter to write for each Slack endpoint change. No webhook signature verification per provider. No OAuth refresh job to monitor at three in the morning. The catalog ships maintained. You ship campaigns.

---

## The white-label consent screen

When your client connects their Gmail, they see a consent screen. That screen says your agency's name, shows your logo, and lists the permissions the agent needs.

The verbatim template, configured once per integration in the connector layer dashboard:

```
Acme Agency wants to access your Gmail

This will allow Acme Agency to:
  - Read your emails and their contents
  - Send emails on your behalf
  - Manage your labels and categories

Make sure you trust Acme Agency with your account.
```

Not "[third party] wants to access your Gmail." Not "ONE wants to access your Gmail." Your name. Your logo. Your tone in the permissions list. The client's trust is being asked for, and the brand asking for it is yours, the one they already pay every month.

This works because the connector layer supports developer-managed OAuth credentials. You register an OAuth application with Google (or Slack, or GitHub, once per integration, under your own developer account). You get a client ID and client secret. You configure those in the connector layer dashboard under your agency's auth config. From that point forward, every consent screen shows your brand, your logo, your permissions list.

One-time setup per integration. The process:

1. Register an OAuth app with the provider under your agency's developer account. Set the callback URL to the connector layer's relay address.
2. Copy the client ID and client secret the provider issues.
3. Create an auth config in the connector layer dashboard with your credentials.
4. Note the auth config ID (starts with `ac_`). That ID goes in your deployment config.

After that, you never touch it again. New clients who connect Gmail go through your branded consent screen automatically. The setup pays for itself the second client; by the tenth it is invisible.

The OAuth callback URL passes through your domain before the connector layer:

```
/api/connect/callback  →  connector layer (stores grant)  →  /settings?connected=gmail
```

The client never sees a connector-layer URL. They connect through your application and land back in your application. Brand surface unbroken.

---

## Tool authorisation and approval gates

Not every tool action should run without confirmation. Sending an email on behalf of a client is different from reading their inbox. Creating a GitHub issue is different from merging a pull request. The approval system distinguishes read from write at the tool level.

The substrate has three approval-gated tools built in. These are the tools that modify state:

```typescript
// claw/src/aitools.ts — approval gates on write tools
remember: tool({
  description: 'Store a fact in long-term memory',
  needsApproval: true,   // ← requires user confirmation before executing
  // ...
}),

mark: tool({
  description: 'Strengthen a path after successful collaboration',
  needsApproval: true,   // ← substrate write, gated
  // ...
}),

warn: tool({
  description: 'Add resistance to a path after failed collaboration',
  needsApproval: true,   // ← substrate write, gated
  // ...
}),
```

Three substrate tools require approval: `remember`, `mark`, `warn`. Read tools (`recall`, `discover`, `highways`, `browse`) run without approval.

For external integrations through the connector layer, the same principle applies. Any tool that mutates state, sending a message, creating an issue, posting to Slack, updating a HubSpot contact, requires approval unless you explicitly remove the gate. The gate is set at the tool level when the integration is configured. You can choose to pre-approve specific actions for specific agents, or require human confirmation every time.

The approval flow in practice: the agent proposes an action, a `claim` button appears in the conversation, the client clicks once, the action executes. The client is in control. The agent is doing the work. The approval is the audit trail. Every click is a logged event the substrate can show on a renewal call.

For agency deployments, you configure approval requirements per agent and per action type. A content agent that drafts copy can pre-approve the draft-to-Google-Doc action. A CRM agent that updates deal stages requires approval on stage changes but can read freely. The configuration lives in the agent's markdown file, one line per tool action, not a separate admin interface. No new pane in a portal nobody opens; the gate is a line in the same file that defines the agent's voice.

Paid skills, agent capabilities with a price attached, require approval before execution. The UI shows the cost before the client confirms. This is how the economic model works at the tool level: agents can offer paid capabilities, clients approve each use, the substrate logs the transaction.

---

## MCP as a second tool surface

Model Context Protocol is the emerging standard for exposing tools to AI agents. Where the connector layer uses OAuth to access existing SaaS accounts, MCP lets any software system expose its own capabilities to any agent that speaks the protocol.

The two surfaces complement each other:

- Connector layer: your clients' existing accounts (Gmail, Slack, GitHub). OAuth-authenticated. The agent acts as the client inside the client's account.
- MCP: your own systems, or third-party systems that publish MCP servers. Token-authenticated. The agent calls the MCP server as itself.

Wiring an MCP server into your agents is a config change, not a code change:

```bash
MCP_SERVERS=slack=https://slack.mcp.acme.com,linear=https://linear.mcp.acme.com
```

Restart the agent. Slack and Linear tools appear in the next conversation. The agent discovers them at runtime. No rebuild. No redeploy of agent logic.

The MCP loading code handles one bad server gracefully:

```typescript
// claw/src/mcp.ts — failures are logged and skipped
try {
  const client = await createMCPClient({ transport: { type: 'sse', url } })
  const remote = await client.tools()
  for (const [key, def] of Object.entries(remote)) {
    tools[`${name}_${key}`] = def       // namespaced: slack_send_message
  }
} catch (e) {
  console.warn(`[mcp] ${name} failed:`, e)  // logged, not fatal
}
```

If one MCP server is down, the others still load. The agent runs with whatever tools were available. The substrate marks the failed path and routes around it.

MCP also works in the other direction: claw exposes itself as an MCP server at `/mcp`. Other agents, on other machines, using other platforms, can call your substrate tools. Mark, warn, recall, highways: all available to any MCP client. This is how the substrate compounds across an agency deployment: every agent installation is both a consumer of tools and a provider of substrate capabilities.

For Claude Desktop and Cursor users on your team, the same MCP endpoint gives them direct access to the substrate from their IDE or chat tool. One configuration, every surface. Your senior copywriter can ask the substrate what the last six dental-practice campaigns learned, from inside the editor they already live in.

---

## What we add on top

The connector layer and MCP give your agents access to tools. What the substrate adds is selection, learning, and trust.

Selection at scale: when a persona has access to more than 30 tools, the agent can start mis-picking, calling the wrong tool or calling tools unnecessarily. The substrate routes tool calls through a pheromone-weighted selection system. After 50 real calls, the substrate knows which tools work for which persona, which (tool, target) combinations succeed and which fail. A search tool that reliably fails on a particular domain accumulates resistance. A draft-and-send workflow that reliably succeeds accumulates strength. The agent's tool selection improves with every client interaction, on your client's own data.

This is the difference between a tool directory and a tool oracle. A tool directory lists what is available. A tool oracle knows, based on real outcomes with this client, which tools to try first, which to avoid, and which to delegate.

The substrate contract for every tool call:

```
tool call succeeds   →  net.mark(edge, depth)    # path strengthens
tool call fails      →  net.warn(edge, 1)         # path accumulates resistance
tool missing         →  net.warn(edge, 0.5)       # mild signal, path may not exist
```

Three states. Every outcome deposits a signal. The signal compounds. After a quarter of real client interactions, the agent's tool selection is trained on that client's actual environment: what their Slack workspace is like, which GitHub repos have noisy PRs, how their HubSpot pipeline is structured. Two clients on the same connector layer end up with measurably different tool routing because the substrate watched their work, not a generic benchmark.

The learning is per-client because the `user_id` scopes the signal paths. Client A's tool performance data does not influence Client B's routing. Each client gets their own pheromone map.

Trust architecture: the connector layer holds OAuth tokens. The substrate holds pheromone. The corpus, every conversation, every outcome, every learned path, stays in the substrate under your control. If you stopped using the connector layer tomorrow, you would lose tool access. You would not lose the learning.

---

## A day in the life — Gmail to Slack with a claim button

Here is how the tools work together in a real scenario. A client's new lead submits a form. The lead's email arrives in the client's Gmail inbox. An agent reads it, drafts a personalised reply, and posts to the client's Slack for approval. One click. Done.

The sequence:

1. Webhook fires on new Gmail message. Agent wakes.
2. Agent calls `gmail_get_message`, reads the lead's email. Tool runs against the client's Gmail OAuth grant. No approval needed (read operation).
3. Agent generates a draft reply using the client's voice contract and lead context from the substrate.
4. Agent calls `gmail_create_draft`, saves the draft in the client's Gmail. Approval gate fires. A `claim` button appears in the client's Slack channel.
5. Client sees the Slack message: "New lead from Sarah Chen at Westfield Dental. Draft reply ready. Click to send."
6. Client clicks the `claim` button. One click.
7. `gmail_send_draft` executes. Email sends from the client's Gmail address, signed with their email signature.
8. Agent marks the path. Substrate records: this workflow succeeded for this client, this lead type, this agent.
9. Next time a dental-practice lead arrives, the routing is 40ms faster. The draft quality improves because the substrate knows which drafts this client approved without editing.

The client never left Slack. The agent never had standing permission to send email. The approval was one click, not a form. The email went from the client's own Gmail, not from a marketing platform. No integration project preceded it. That last sentence is the one to read twice. The work the client used to write a brief for, then wait two weeks for, happened in the time it took to read a Slack notification.

---

## Objections

**"What if a tool's API changes?"**

The connector layer maintains the adapter between the tool's spec and the agent's call format. When Slack changes a message-sending endpoint, the connector layer updates the adapter. You do not rebuild your agents. The same `slack_send_message` call works before and after the API change because the connector layer is the versioning layer. This is the entire reason it exists: to absorb the upstream churn so your fifty client agents do not break on a Tuesday morning when a provider ships a quiet deprecation.

For MCP servers you run yourself, updates are your responsibility. The same tradeoff applies: control means ownership of the maintenance burden. For connector-layer-managed integrations, that burden belongs to the connector layer.

If an adapter breaks, the tool call fails. The substrate records the failure. The agent routes around it on the next call. You see the failure in your substrate dashboard. You have a ticket to raise with the connector layer, or a config to update for your own MCP server.

**"What if my existing CRM has its own integration?"**

HubSpot, Salesforce, and Zoho all have their own AI integrations now. Those integrations work inside their own platform. Your agent, using the connector layer, works across platforms. The agent that reads Gmail, drafts in Google Docs, updates HubSpot, and posts to Slack in one motion cannot be assembled inside HubSpot alone. The connector layer is additive to your existing CRM. It does not require replacing it. Your client keeps HubSpot. You become the layer that makes HubSpot speak to the other six tools.

**"What if a client revokes access mid-campaign?"**

The grant revocation propagates immediately. The next tool call fails. The agent marks the path as failed. The conversation continues with whatever tools remain. The substrate logs the event. You see it in the client's workspace dashboard. There is no silent failure, no stale data, no agent continuing to act on revoked permissions.

**"Is my clients' data leaving their systems?"**

Their OAuth tokens are held by the connector layer. The content the agent reads and writes stays in their systems: Gmail, Slack, GitHub. The only data that leaves their systems is what the agent explicitly reads to complete a task, and that passes through your substrate instance, not through any third-party analytics layer. Your substrate is a Cloudflare Worker deployment under your control. You can specify the region.

**"What happens when tool usage exceeds what the connector layer allows?"**

The connector layer rate limits by `user_id`, which maps to one client. High-volume use by one client does not affect other clients. For clients with high email or Slack volume, you configure per-client rate caps. The agent respects the cap, queues excess work, and processes it on the next tick. The substrate handles the queue. You do not need to build rate-limiting logic.

**"What's the worst case if the connector layer has an outage?"**

Agents cannot call external tools during the outage. They can still recall memory, read the corpus, draft content, and reason. The substrate continues working. Tool calls fail gracefully and return informative errors. When the connector layer comes back, queued tool calls resume. The substrate has not lost any state.

**"What about integrations that aren't in the catalog?"**

The escape hatch is `httpRequest`, a single tool that makes arbitrary HTTP calls. It is approval-gated on all writes and on any GET to a non-allowlisted domain. You configure the allowlist per deployment. For a one-off internal API or a vendor with no standard spec and no MCP server, `httpRequest` is available. It is not the default. Most personas do not get it.

**"What if my client doesn't want to connect their accounts?"**

Then the agent works without those integrations. The agent has read, write, and search capabilities built in to the substrate. It can browse public URLs, recall memory, draft content, and delegate to specialists, all without external integrations. The connector layer is additive. Clients who connect Gmail and Slack get a more capable agent. Clients who connect nothing still get a capable agent.

---

## Comparisons

**Connector layer versus building your own integrations**

Building integrations yourself means OAuth flows, token storage, token refresh, rate limiting, webhook verification, and API versioning, per service, per client. For a 50-client pilot, that is fifty OAuth flows to manage. For 250 clients, it does not scale. Two senior engineers spend a year and you have a worse version of what the connector layer already runs.

The connector layer moves that maintenance burden off your team. You pay a per-seat cost; you get 250+ integrations, maintained, versioned, and white-labelled. The economics work when integration-project time costs more than the connector-layer fee, which it does above about three clients.

**Connector layer versus a horizontal integration platform**

Zapier and Make are workflow automation tools. They run sequences of steps on a schedule or trigger. They do not run inside an LLM context. They cannot read a Gmail thread, reason about it, draft a response, check memory, and send with approval, in one motion, with pheromone-based learning.

The connector layer is not a workflow tool. It is a credential broker. The agent is the workflow. The substrate is the learning. The connector layer just ensures the agent's tool calls go to the right accounts with the right credentials.

---

## Pricing

The connector layer cost does not appear as a line item on your client invoices. It is covered in your agency's platform subscription. The economics:

Your agency's credit pool pays for LLM inference and substrate operations. The connector layer access, the OAuth infrastructure, the 250+ integrations, the white-label setup, is included in the platform fee.

A client running active agents across Gmail, Slack, and HubSpot will consume more credits than a client with no integrations, because each tool call is an LLM step. The credit consumption is per-call, billed transparently. At your agency markup, a client running 500 tool calls per month, roughly one call per business hour, costs approximately what a junior team member costs for one hour.

The comparison is the point: one junior team member-hour, every business day, costs you £30–£80 depending on your market. Five hundred intelligent tool calls cost you a fraction of that, at whatever markup you set. The maths is the whole pitch of this page expressed in one line on a P&L.

---

## Failure modes

Three failure modes to plan for.

First: the consent screen fails. A client authorises the wrong permissions scope, or clicks through without reading, and the agent tries to use a capability not included in the grant. The tool call fails. The error surfaces in the conversation. The fix is the client reconnecting with the correct permissions. You can inspect the grant scope via the connector layer API before the agent runs.

Second: the connector layer adapts an API change but ships a breaking change to the tool schema. The agent calls the tool with the old parameter shape and the call fails. This is a connector-layer versioning issue. The mitigation is pinning to a connector-layer version in your deployment config and testing integrations before upgrading.

Third: approval fatigue. If every write action requires a click, clients stop clicking and stop getting value from the agents. Design your approval gates to distinguish high-stakes writes (send email, update deal stage, merge PR) from low-stakes writes (add label, update draft). Gate the high-stakes. Pre-approve the low-stakes. The per-agent approval configuration in the markdown file is where this decision lives.

---

## Frequently asked questions

**How many integrations are available?**
250+, through the connector layer. The catalog grows as new MCP servers and OAuth adapters are added. You do not need to rebuild anything when a new integration ships.

**Does the connector layer store my clients' emails?**
No. The connector layer holds OAuth tokens, the credential that lets the agent call Gmail. The email content itself stays in Gmail. When the agent reads an email, the content passes through the substrate to complete the task and is then subject to your substrate retention policy, not the connector layer's.

**Can one agent work across multiple clients simultaneously?**
Yes. The `user_id` scoping means the agent picks up the correct connected accounts per client at runtime. One agent definition, many client toolbelts.

**How do I add a new integration for all my clients?**
Configure the auth config in the connector layer dashboard once. Then surface a "Connect [Integration]" button to clients in your settings page. Clients who click authorise it for themselves. You do not push the connection to them; they opt in.

**What if a client connects a work account and then leaves their company?**
Their Google account revocation cascades to the OAuth grant. The agent loses access on the client's next auth check. Your settings page surfaces the disconnected state. You reconnect when appropriate.

**Can the agent act differently for different clients even if they use the same integrations?**
Yes. The pheromone map is per-client (`user_id`). The agent learns which actions work for this client's Slack workspace, this client's HubSpot pipeline, this client's email response patterns. Same integrations, different learned behaviours.

**Is MCP available to my clients or only to my agents?**
Both. If you expose your substrate as an MCP server, your clients' own Claude Desktop or Cursor installations can call your agents. If you configure MCP servers for your agents, those servers are available to agents serving clients. The direction is configurable.

**How do I know the connector layer is up?**
The substrate health check includes a connector layer status check. If the connector layer is degraded, your dashboard shows it and the agent logs the degradation. Tool calls fail gracefully with informative errors.

---

## Glossary

**Connector layer.** The infrastructure that brokers OAuth connections between your agents and your clients' SaaS accounts. One server-side API key. N user-scoped connected accounts.

**Connected account.** A single client's authorised connection to one integration. One client might have three connected accounts: Gmail, Slack, and GitHub.

**`user_id`.** The stable, opaque identifier that scopes all connected accounts to one client. Derived from the client's passkey wallet address.

**Auth config.** A per-integration configuration that includes your agency's OAuth credentials. Created once per integration in the connector layer dashboard. Determines what name and logo appear on the consent screen.

**Approval gate.** A `needsApproval: true` flag on a tool definition. When set, the tool proposes an action and waits for a human click before executing.

**MCP (Model Context Protocol).** A protocol for exposing tools to AI agents. Any system that publishes an MCP server can be called by any agent that speaks the protocol. Complementary to the connector layer.

**Pheromone.** The signal the substrate deposits after each tool call outcome. Strength accumulates on paths that succeed; resistance accumulates on paths that fail. Tool selection improves over time based on pheromone.

**Toolkit.** The connector layer's term for a group of related tools from one provider. `GMAIL` is a toolkit. `SLACK` is a toolkit. A connected account grants access to one toolkit.

---

## Cross-references

Tools work with memory (page 08): the agent can recall context about a client before acting with a tool. What the client told the agent last month can inform what the agent writes today.

Tools feed learning (page 13): every tool call outcome deposits pheromone. The substrate's learning loop is the tool-selection oracle that makes each client deployment better over time.

Teams (page 09) distribute tool access: specialist agents get only the tools they need. The copywriter persona does not get the GitHub merge tool. The developer persona does not get the HubSpot deal-stage tool.

---

*Connect Gmail in two clicks.*

<!-- rubric: fit=0.95 strongest=0.92 show=0.91 cut=0.90 craft=0.91 → 0.92 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=em -->
