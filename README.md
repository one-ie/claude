# @oneie/claude

Connect Claude Code to ONE. Install this plugin and Claude Code gets the ONE substrate as native tools, a handful of agents and skills that show how to build on it, and a door to the marketplace where the rest are sold.

---

## Install

```bash
claude plugin marketplace add one-ie/claude
claude plugin install oneie-claude@oneie
```

Then connect:

```
/oneie-claude:setup
```

The substrate tools switch on as soon as `ONEIE_API_KEY` is set.

---

## Privacy: the plugin installs no hooks

Installing the plugin adds a few commands, skills and agents, plus the `oneie` MCP tools. It adds
**no hooks**. Nothing runs on your prompts, and nothing is sent anywhere until you
call a tool. You can also install it for one project only:
`claude plugin install oneie-claude@oneie --scope project`.

## What you get

| Kind | Ships in the plugin |
|---|---|
| **Commands** | `/oneie-claude:setup` connects the plugin to ONE · `/oneie-claude:pair` pairs this Claude Code with your ONE chat panel |
| **Agents** | `guide` walks you through ONE · `onboarder` sets up a workspace · `ceo` routes work to the right agent · `support-agent` handles T1 support · `discovery-caller` runs sales discovery |
| **Skills** | `oneie` · `signal` · `sdk` · `mcp` · `cli` · `planning` · `workflow` · `sell` |
| **Rules** | `astro` · `react` · `ui`, the conventions of the ONE starter |
| **Template** | `template-agent.md`, the shape to copy when you write your own agent |

Each shipped agent shows a different way to use the substrate, so you can copy the shape and write your own.

## The rest are in the marketplace

ONE runs more than a hundred agents and skills across marketing, sales, service, education and engineering. They are sold in the ONE marketplace: [one.ie/marketplace](https://one.ie/marketplace). Buy one, and your workspace can use it through the same MCP tools this plugin already set up, with no extra install.

Built something good yourself? The `sell` skill lists your own tool or agent in the same marketplace.

---

### The ONE substrate — 13 operations via MCP

When `ONEIE_API_KEY` is set, Claude Code gains direct access to the ONE substrate as native tools.

Every application is composed from the same thirteen operations:

```ts
// A merchant publishes a product
await c.signal('world:create-thing', {
  name: 'Midnight Linen Jacket', type: 'product', price: 295
})

// A buyer completes a purchase — settle the payment, then mark the path that converted
await c.payWeight('buyer', 'merchant', 'order', 295.00)   // USDC settled
await c.mark('buyer→merchant:order')                      // strengthen what worked

// The substrate asks: what should we surface next?
const { target } = await c.select('product')
```

Four calls. A commerce platform. The substrate records what converted, strengthens those paths, and starts surfacing better results automatically.

**MCP tools available after `/oneie-claude:setup`:**

| Group | Tools |
|-------|-------|
| Substrate | `signal` · `ask` · `mark` · `warn` · `fade` · `follow` · `select` · `recall` · `reveal` · `forget` · `frontier` · `know` · `highways` |
| Lifecycle | `auth_agent` · `sync_agent` · `publish_agent` · `list_agents` · `list_skills` · `register` · `pay` |
| Observability | `stats` · `health` · `revenue` · `export_highways` |

The same operation — `signal`, `mark`, `select` — is available from TypeScript via `@oneie/sdk`, from the terminal via `@oneie/cli`, from any MCP-connected tool via `@oneie/mcp`, and now from Claude Code via this plugin. Your agents and your tools speak the same language.

---

## What this replaces

Building an application on ONE replaces seven separate services:

| Usually built separately | ONE equivalent |
|--------------------------|----------------|
| Database + ORM | TypeDB — six dimensions, typed schema |
| Auth + roles | Actors with scoped keys; revoking is a `warn` |
| Recommendation engine | `select()` — pheromone routing |
| Message queue | `signal()` — async, tagged, delivered |
| Webhooks | `sub()` — any HTTPS URL becomes a receiver |
| Payments | `mark()` with `weight` + `currency` |
| AI agent framework | Every actor is an agent; the substrate is the runtime |

You do not bolt these together. You get them as a consequence of using the substrate correctly.

---

---

## Environment

| Var | Default | What |
|-----|---------|------|
| `ONEIE_API_KEY` | required for substrate tools | Your workspace API key |
| `ONEIE_API_URL` | `https://one.ie` | Override for self-hosted — the app origin; `https://api.one.ie` 404s every `/api/*` call |

Get your API key at [one.ie/settings/keys](https://one.ie/settings/keys).

---

## Peer dependencies

The plugin wires up the MCP server automatically. Install the packages your project needs:

```bash
# SDK — TypeScript client
npm install @oneie/sdk

# MCP server — substrate tools in Claude Code (required for /oneie-claude:setup)
npm install @oneie/mcp

# CLI — terminal access to the substrate
npm install -g @oneie/cli
```

---

[one.ie](https://one.ie) · [marketplace](https://one.ie/marketplace) · [github.com/one-ie/claude](https://github.com/one-ie/claude)
