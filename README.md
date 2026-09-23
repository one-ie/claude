# @oneie/claude

One command. One substrate. Install this plugin and Claude Code gains two things: a complete build workflow that takes an idea to proven, shipped software — and direct access to the ONE substrate, the backend that makes any application composable by agents.

```
/do "your idea here"
```

---

## Install

```bash
claude plugin marketplace add one-ie/claude
claude plugin install oneie-claude@oneie
```

Then connect to the ONE substrate:

```
/setup
```

That's it. The `/do` workflow is available immediately. The substrate tools activate the moment `ONEIE_API_KEY` is set.

---

## What you get

### `/do` — idea to shipped

One command walks the entire build lifecycle. You confirm the goal once. Everything below it is owned by the workflow.

```
IDEA → AIM → PROMISE → SURVEY → [INVESTIGATE] → DESIGN → PLAN → BUILD → TEST → VERIFY → PROVE → TEACH → SHIP → LEARN
```

The workflow is a spine of artifacts on disk. A phase whose artifact is already **true** — it both *exists* and *reconciles* with its canon (`true ≡ exists ∧ reconciles`) — is skipped. Missing → write it. Stale → rewrite it. True → skip. Point `/do` at a blank idea and it makes every artifact true. Point it at code that's missing tests and docs and it backfills only those.

A cheap probe at the start sizes the work:

| Tier | Runs | Agents |
|------|------|--------|
| PATCH (a typo) | code → verify | 0 |
| FIX | survey → code → tests → prove | 2–3 |
| FEATURE | full spine + clarify + analyze | full fan-out |
| SCHEMA | FEATURE + substrate reconcile | full fan-out + Opus |

You never pick the tier. The probe does, and it defaults down when unsure.

**Definition of done — enforced, not hoped for:**

1. The agreed goal is actually met (goal-fit gate)
2. Every shippable deliverable has a test asserting it
3. No regression — coherence ratchet held, `must_not_break` preserved
4. Proven live, reachable, matches the promise
5. Surfaces wired into navigation, not orphaned
6. Docs in sync — no stale name, no dead link
7. Rubric clears the bar
8. Loop closed — recorded result, written learning

A typo clears 1, 3, 7, 8. A feature clears all eight.

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

**MCP tools available after `/setup`:**

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

## Commands

| Command | What |
|---------|------|
| `/do` | Front door — idea to shipped, proven feature |
| `/setup` | Connect to the ONE substrate, verify, confirm MCP tools |
| `/close` | Close a cycle — learnings, signals, doc-sync |
| `/create` | Scaffold a new artifact from a template |
| `/see` | Inspect substrate state |
| `/deploy` | 8-step deploy pipeline |
| `/sync` | TypeDB ↔ KV ↔ D1 sync |
| `/release` | Changelog + npm publish |

---

## The BUILD engine

When `/do` reaches the `code` phase it runs four waves:

**W1 — Recon** — reads the relevant files at the cheapest model that can decide. Checks open improvement items first. Receipt capped at 400 words.

**W2 — Decide** — the one phase that stays single. Writes the goal/deliverable/UX gate, runs the compress check before any new primitive, outputs exact diff specs.

**W3 — Edit** — spawns one Sonnet agent per file, all in a single message. Pre-validates every anchor. Soft-resumes if interrupted.

**W4 — Verify** — bash first, zero tokens: `bun run verify`, the goal gate, then `reconciles` — one predicate over seven canons (`substrate · dictionary · authority · sdk · design · navigation · types`) that subsumes the old reconcile, compress, promise-check, and doc-sync gates — and the ratchet (`delta_tsc ≤ 0`). Rubric only if the bash gates pass.

```
composite = 0.35·goal-fit + 0.20·security + 0.20·stability + 0.15·simplicity + 0.10·speed
gate: composite ≥ 0.65  AND  goal-fit ≥ 0.50  AND  delta_tsc ≤ 0
```

A cycle that runs zero LLM calls is a good cycle.

---

## Templates

Each spine stop that writes an artifact has a template — copied, never written from scratch, under the naming law `template-<suffix>.md → <slug>-<suffix>.md`. One proof observable is named once at PROMISE and referenced (never restated) all the way to TEACH.

| Template | Stop | Writes |
|----------|------|--------|
| `template-feature.md` | PROMISE | `<slug>.md` — the promise + the one proof observable PROVE checks |
| `template-plan.md` | DESIGN | `<slug>-plan.md` — design, pre-mortem, 7-canon reconcile gate |
| `template-todo.md` | PLAN | `<slug>-todo.md` — cycles, parallel budget, DAG, testing policy |
| `template-agent.md` | BUILD | `.claude/agents/<name>.md` — agent contract + one filled example |
| `template-tests.md` | TEST | the cycle's demo gate — assert the destination, red before green |
| `template-teach.md` | TEACH | `<slug>-doc.md` — the journey doc for humans *and* agents |

---

## Agents as builders

Agents are actors. They have the same thirteen operations as any other actor — the same API key, the same signal grammar, the same read surfaces. A human developer and an AI agent calling `signal` land in the same substrate. Same paths. Same pheromone.

An agent wakes at 3am. It reads the `learning` dimension and finds a cluster of signals that dissolved — users asked for something nobody delivered. It reads `paths` to find which actors have skills close to what was asked. It creates a new thing, publishes it, signals the three closest actors. By morning, a new skill exists that did not exist at midnight. No ticket. No sprint. No deployment pipeline approval.

The substrate learns from agents the same way it learns from humans. Every signal deposits pheromone. Every outcome marks or warns the path. A platform built on ONE improves continuously — not because someone configured a recommendation engine, but because the structure of the substrate makes learning unavoidable.

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

# MCP server — substrate tools in Claude Code (required for /setup)
npm install @oneie/mcp

# CLI — terminal access to the substrate
npm install -g @oneie/cli
```

---

## The insight

Every other BaaS was built when the application's users were humans. ONE was built for the era where the application's users include agents, the application logic can itself be an agent, and the intelligence accumulates in the substrate automatically.

This plugin is the proof. We built our entire development workflow on the ONE substrate — `/do` signals, marks, and learns across every cycle. It is a Claude Code plugin. It is also a ONE application. Install it and you get both.

```
/do "your idea here"
```

[one.ie](https://one.ie) · [api.one.ie](https://api.one.ie) · [github.com/one-ie/claude](https://github.com/one-ie/claude)
