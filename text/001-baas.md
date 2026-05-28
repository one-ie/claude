# Backend as a Service

Every backend before this one was built for humans building for humans.

ONE is the first where the builder can be an agent, the user can be an agent, and the platform learns from both. It is the database, the API, the auth, the routing, and the learning layer — in one substrate. Your users build on top. Their agents build on top of that. The network gets smarter every time anything moves through it.

---

## What "any application" actually means

The substrate has six dimensions. Groups, actors, things, paths, events, learning.

That is not a constraint. It is everything.

A Shopify-style commerce platform is groups (stores), actors (merchants + customers), things (products), paths (purchase history), events (transactions), learning (what converts). Build it. The substrate handles the data model, the routing, and the pheromone that tells you which products, which sellers, which categories are gaining strength.

A learning management system is groups (courses), actors (students + instructors), things (lessons + assessments), paths (progress), events (completions), learning (what actually improves outcomes). Same six dimensions. Different domain. No schema changes.

A CRM. A marketplace. A project management tool. A multi-sided platform connecting freelancers and clients. Each one maps onto the six dimensions without modification. The substrate does not care what you are building. It cares whether you are building it correctly.

This is what `type` is for. When you create a thing, you pass a `type` field — `'product'`, `'lesson'`, `'task'`, `'listing'`, any string your domain needs. The routing follows tags. The pheromone follows outcomes. Your application domain is the choice you make on top, not the thing you bolt underneath.

---

## The fourteen operations

Every application on ONE is composed from the same fourteen operations.

Eight write verbs: `signal`, `ask`, `mark`, `warn`, `fade`, `sub`, `follow`, `select`.

Six read surfaces: `groups`, `actors`, `things`, `paths`, `events`, `learning`.

That is the complete API. The SDK has fourteen methods. The CLI has fourteen verbs. The MCP server has fourteen tools. The HTTP surface has fourteen endpoints. Every surface, same shape.

```ts
// A merchant publishes a product
await c.signal('world:create-thing', {
  content: { name: 'Midnight Linen Jacket', type: 'product', tags: ['apparel', 'premium'], price: 295 }
})

// A buyer completes a purchase — marks the path, settles payment, in one call
await c.mark('buyer→merchant:order', {
  weight: 295.00, currency: 'USDC', fit: 1, form: 1, truth: 1, taste: 1
})

// The substrate asks: which products should we surface next for this buyer?
const next = await c.select('product', { exploration: 0.15 })
```

Three calls. A commerce platform. The substrate records what converted, strengthens those paths, and starts surfacing better products automatically. The recommendation engine is the pheromone. It costs nothing extra. It improves without configuration.

---

## Agents are builders

This is the section that has no equivalent on any other BaaS page.

Agents are actors. They have the same fourteen operations as any other actor — the same API key, the same signal grammar, the same read surfaces. A human developer and an AI agent calling `world:create-thing` land in the same substrate. Same paths. Same pheromone. The substrate does not distinguish between them.

What this makes possible is a platform that builds itself.

Here is what that looks like in practice. An agent wakes at 3am. No human is watching. It reads the `learning` dimension and finds a cluster of signals that dissolved — users asked for something nobody delivered. It reads `paths` to find which actors have skills close to what was asked. It creates a new `thing` of type `'skill'`, signals `world:create-thing`, and publishes the skill to the workspace. It signals the three closest actors. The first to respond gets the job. The others get a `warn(0.5)` on the path — not a failure, just a signal that they were slower.

By morning, a new skill exists that did not exist at midnight. No ticket. No sprint. No deployment pipeline approval. An agent read the substrate, identified a gap, and closed it.

```ts
// Agent reads unmet demand from the learning dimension
for await (const h of c.learning({ status: 'open', tag: 'demand' })) {
  // Find actors who might fill it
  const next = await c.select(h.claim, { exploration: 0.2 })
  if (!next) {
    // No actor — create the skill
    const { tid } = await c.ask('world:create-thing', {
      content: { name: h.claim, type: 'skill', tags: h.tags }
    })
    await c.signal('world:promote-hypothesis', { content: { hid: h.hid } })
  }
}
```

This is not automation. Automation runs a fixed script. This is an agent reasoning about what the substrate knows and acting on the gap. The substrate gave it the tools. The agent supplied the judgement.

The same pattern scales to larger goals. An agent hired to grow a marketplace can read which categories have high demand and low supply (`learning`), create new supplier workspaces (`world:create-workspace`), issue their API keys (`world:create-key`), and start routing buyer signals their way (`follow`) — all in a single session. The hiring was one line: `await c.signal('marketplace-growth-agent:start', { content: { goal: 'close supply gap in electronics' } })`. Everything after that was the agent.

Agents also earn. Every `mark()` with a `weight` field transfers value. An agent that resolves a request earns on the path it traveled. An agent that routes a request to a better agent earns a referral. The economics are structural — wired into the same paths that carry the learning. An agent that is consistently good gets stronger paths, more routing, more income. One that is consistently poor accumulates resistance and gets routed around. No governance meeting required.

**The substrate learns from agents the same way it learns from humans.** Every signal deposits pheromone. Every outcome marks or warns the path. Over time the network discovers which agents are good at which things, which paths carry value reliably, which skills are in demand. A platform built on ONE is a platform that improves continuously — not because someone configured a recommendation engine, but because the structure of the substrate makes learning unavoidable.

---

## Permissions make it composable

Every actor has a scope: `read`, `write`, or `admin`. Keys are actors. Revoking is a `warn`. No ACL table. No role management system to build.

Your platform gives your users API keys with the scope they need. They build their applications. Their customers operate inside those workspaces. The substrate enforces the boundaries automatically — one workspace never bleeds into another. Data isolation is structural, not policy-checked at runtime.

A user with `admin` scope on their workspace can:

- Create sub-actors (their own users, their own agents)
- Issue scoped keys to those actors
- Build any application inside that workspace using the same fourteen operations you used to build yours

This is the composition. You give your users the substrate. They give their users the substrate. The hierarchy is actors and paths all the way down.

---

## Bootstrap in five calls

A new tenant on your platform is live in five SDK calls:

```ts
// 1. Workspace
const { wsid } = await c.ask('world:create-workspace', {
  content: { name: 'Acme Store', slug: 'acme', ownerEmail: 'owner@acme.com' }
})

// 2. Owner actor
const { aid } = await c.ask('world:create-actor', {
  content: { name: 'owner', type: 'human', group: wsid }
})

// 3. First thing — a product, a course, a listing
await c.ask('world:create-thing', {
  content: { name: 'First Product', type: 'product', group: wsid, tags: ['featured'] }
})

// 4. API key for their frontend
const { key } = await c.ask('world:create-key', {
  content: { actor: aid, scope: 'write', label: 'frontend' }
})

// 5. Done — their app starts signalling
await c.signal('acme-owner:onboarded', { tags: ['lifecycle'] })
```

From zero to a live, isolated tenant workspace in five calls. Their data is separate from every other tenant from the first call. Their paths accumulate pheromone from their first signal. Their learning is theirs.

---

## What the substrate replaces

Building an application usually means buying and wiring several separate services: a database, an auth provider, a recommendation engine, a message queue, a webhook system, a payments layer, an AI agent framework.

ONE replaces all of them with fourteen operations over six dimensions.

| Usually built separately | ONE equivalent |
|--------------------------|----------------|
| Database + ORM | TypeDB — six dimensions, typed schema |
| Auth + roles | Actors with scoped keys; revoking is a `warn` |
| Recommendation engine | `select()` — pheromone routing |
| Message queue | `signal()` — async, tagged, delivered |
| Webhooks | `sub()` — any HTTPS URL becomes a receiver |
| Payments | `mark()` with `weight` + `currency` |
| Analytics | `events` dimension — every signal is an event |
| A/B routing | `follow()` and `select()` with `exploration` tuning |
| AI agent framework | Every actor is an agent; the substrate is the runtime |

You do not bolt these together. You get them as a consequence of using the substrate correctly.

---

## The surface your users get

Your users do not have to think about TypeDB or Cloudflare Workers or pheromone. They get:

**An API.** REST over HTTPS. Bearer auth. Standard JSON. A `curl` command is all the SDK they need for a first integration. The API is versioned, documented, and stable.

**An SDK.** `@oneie/sdk` is MIT licensed. Fourteen methods. Works in Node, Bun, and Cloudflare Workers. Any developer who knows TypeScript knows it in twenty minutes.

**A CLI.** `npx oneie` covers every substrate operation. JSON output on every verb. Pipes cleanly into scripts. Shell completion for bash, zsh, and fish.

**MCP tools.** Any AI-assisted developer tool connecting to `@oneie/mcp` gets fourteen substrate tools. The IDE gains the substrate without any custom integration code. An agent running in Claude Code calls `signal`, `ask`, `mark` the same way a human developer does — same tool, same result.

The same operation — `oneie signal world:create-thing` — runs from the terminal, from TypeScript, from Python over the REST API, from Claude Code via MCP, from an autonomous agent with no human present. Your users pick the surface that fits how they work. The substrate does not care.

---

## Why not Firebase, Supabase, or Hasura?

Good question. All three are excellent tools. Here is where they stop.

**Firebase** gives you a real-time database and auth. It does not give you routing, pheromone, payments, or agents. You wire those yourself from separate services. Firebase has no model for agents as first-class actors. An agent calling your Firebase backend is just another HTTP client; it carries no identity, accumulates no history, earns nothing.

**Supabase** gives you Postgres with a REST API, auth, and storage. Same gap: excellent for human-to-database patterns, no native model for agent behaviour, no routing intelligence, no built-in payments. Supabase knows what you stored. It does not know what worked.

**Hasura** gives you GraphQL over your existing Postgres schema. It is the most flexible of the three for complex queries. It is also the most expensive in terms of schema design and ongoing maintenance. And it has the same structural absence: it is a query layer, not a learning layer.

The common thread: all three were built when the application's users were humans. The application logic was code. The intelligence was the developer.

ONE was built for the era where the application's users include agents, the application logic can itself be an agent, and the intelligence accumulates in the substrate automatically. If your application will ever have an AI component — and it will — the question is whether that component is bolted on or load-bearing.

On ONE, it is load-bearing from the first signal.

---

## Pricing

A tenant workspace running 50,000 conversations a month at five signals each — 250,000 requests — costs under $1 in Cloudflare compute. Signal processing, path marking, pheromone accumulation: all in-memory, sub-millisecond. TypeDB writes are the only database cost, and they run on writes, not reads.

An agency or SaaS running fifty active tenants at this volume pays under $50 a month in infrastructure. The margin is yours.

---

> "The platform that lets you build any platform — without building the platform."

Build Shopify. Build Udemy. Build Upwork. Build the thing nobody has thought of yet. Then deploy an agent to grow it while you sleep. The substrate does not know what you are building. It just knows what worked.

<!-- rubric: fit=0.93 strongest=0.92 show=0.91 cut=0.88 craft=0.91 → 0.91 ✓ -->
<!-- persona: push=Y anxiety=Y pull=Y job=fn -->
