# Agent-First Registry — one declaration, every affordance

**Status:** design
**Source of truth:** this doc → `plans/agent-first-todo.md`
**Sibling:** `plans/0000-agent-first.md` (why) · `plans/agent-first-a2a.md` (the A2A follow-on this unlocks)
**Blast radius:** SDK · web routes · OpenAPI · agents worker · MCP
**Motif:** *Power through simplicity — the meta-layer obeys the rule the schema already obeys.*

---

## The problem in one sentence

The receiver namespace is *declared* to be the API (`api.md`, `sdk/CLAUDE.md`, `mcp/CLAUDE.md`) — and it is the **only part of the API with no types, no schema, and no single source of truth.**

### The chain that proves it

```
docs say:        "the receiver namespace IS the API — no bespoke methods"
openapi.yaml:    /signal/{receiver}  →  receiver: free string, body: "shape is receiver-defined" (opaque)
generate-types:  reads openapi.yaml  →  cannot emit receiver types (the spec has none)
generated/types: knows the 6 dims + /api/* routes  →  knows zero receivers
sdk/client.ts:   ~50 hand-written methods (publishAgent, commend, bounty…)  →  the manual patch
sdk/schemas.ts:  hand-written zod, response-side only  →  request side still unknown
world-receivers: HANDLERS map of 21 world:* receivers  →  every handler is (data: unknown)
route handler:   grant-capability validates with `'grantee' in body` … `String(b.grantee)`  →  a bad zod schema, written by hand, inline
```

Every one of these is a symptom of a single missing artifact: **receivers have handlers but no declared shapes.** The registry knows *names* (`HANDLERS` keys) but not *contracts*.

### What it costs

| Who | Pays |
|---|---|
| **Agents** (Claude Code, MCP clients) | `ask("market:hire", {…})` is a blind call — no autocomplete, no validation, runtime discovery of bad payloads via `String(undefined)`. The substrate is "an API you must study," not "an API your tools introspect." |
| **The SDK** | 50 bespoke methods that each break the "no methods" rule, drift from the server, and force a republish per new receiver. |
| **The spec** | `openapi.yaml` lies — it says the body is opaque because there's no shape to publish. |
| **Handlers** | Hand-rolled field-presence checks (`'x' in body`) instead of one parse. |
| **The philosophy** | Asserted in prose, contradicted in code. |

---

## The principle

> One source of truth (the receiver registry). Many generated consumers (validator, spec, SDK types, MCP catalog).

This is the substrate philosophy applied to the substrate's own type system. The schema is truth for *data*; the receiver registry becomes truth for *capability*. Nothing is hand-maintained twice.

---

## The design

### 1. The registry entry

Today (`world-receivers.ts`):

```ts
type Handler = (data: unknown, env: Env, ctx: CallerCtx) => Promise<Record<string, unknown>>
const HANDLERS: Record<string, Handler> = { 'world:create-actor': createActor as Handler, … }
```

Becomes — a receiver *declares its contract*:

```ts
import { z } from "zod"

export interface Receiver<Req extends z.ZodTypeAny, Res extends z.ZodTypeAny> {
  receiver: string          // "world:create-actor"
  summary: string           // one line — feeds OpenAPI + MCP + meta:catalog
  request: Req              // zod — validated BEFORE dispatch; errors carry the fix (§ affordance layer)
  response: Res             // zod — the result shape (for ask)
  effect: "signal" | "ask"  // fire-and-forget vs awaits an outcome
  auth?: RoleAction         // role gate (already exists via gateSignalByRole)
  // ── agent-ergonomic metadata — travels with the capability, read via meta:catalog ──
  cost?: "free" | { fixed: number } | "variable"  // agents budget before acting
  reversible?: boolean      // default true; false ⇒ should be dry-run first
  settles?: "none" | "offchain" | "onchain"       // does it move real, permanent value?
  simulatable?: boolean     // accepts { simulate: true } → projects outcome, commits nothing
  idempotent?: boolean      // safe to retry as-is; else dedupes on the envelope idempotencyKey
  version?: string          // capability version — agents pin; additive bumps never break callers
  examples?: Array<z.infer<Req>>  // valid payloads — seed MCP + the error-as-affordance hint
  deprecated?: string       // migration target if retiring — agents read this and move
  handler: (data: z.infer<Req>, env: Env, ctx: CallerCtx) => Promise<z.infer<Res>>
}

export function receiver<Req extends z.ZodTypeAny, Res extends z.ZodTypeAny>(
  r: Receiver<Req, Res>,
): Receiver<Req, Res> { return r }
```

The handler signature changes from `(data: unknown, …)` to `(data: z.infer<Req>, …)` — **the `unknown` is gone.** Validation happens once, at the registry edge, not hand-rolled inside each handler.

### 2. Where it lives

The registry must be reachable by **both** services that handle receivers:

- `one.ie/web/` — the `signal`/`ask` routes + OpenAPI generation
- `channels/` — the agents worker (today's `NANOCLAW_URL` forward target)

…and by the **two consumers** that need the types:

- `packages/sdk/` — typed `ask`/`signal`
- `packages/mcp/` — tool descriptions

→ The contract declarations (`receiver` + zod schemas + metadata, **no handler bodies**) live in **`@oneie/sdk`** as a new export `@oneie/sdk/receivers`. Both web and channels already import `@oneie/sdk`. Handlers stay where they run (web's `world-receivers.ts`, channels' tool modules) and *attach* to their declaration. The SDK ships the catalog; the services ship the implementations.

```
@oneie/sdk/receivers   ← contract: { receiver, request, response, summary, effect }  (truth)
        │
        ├──→ web/world-receivers.ts   binds handler, route validates via request schema
        ├──→ channels/tools          binds handler for forwarded receivers
        ├──→ sdk ask<R>/signal<R>     typed from the catalog (no codegen — TS infers)
        ├──→ openapi.yaml             generated oneOf over receiver+payload
        └──→ mcp tool descriptions    summary + request schema → JSON Schema
```

### 3. The verbs become typed — no codegen needed

Because the catalog is plain TypeScript zod, the SDK gets types by **inference**, not generation:

```ts
type Catalog = typeof RECEIVERS  // the registry object
type Names = keyof Catalog

async ask<R extends Names>(
  r: R,
  data: z.input<Catalog[R]["request"]>,
): Promise<Outcome<z.output<Catalog[R]["response"]>>>
```

`one.ask("market:hire", { skill, budget })` is now checked end to end: receiver name autocompletes, payload is validated at compile time, the outcome is typed. The raw-string escape hatch (`ask(receiver: string, data?: unknown)`) stays for unknown/dynamic receivers — additive, never removed, so a pinned SDK still reaches new server receivers.

### 4. OpenAPI stops lying

A small generator walks `RECEIVERS` and emits, for `/signal/{receiver}` and `/ask/{receiver}`, a discriminated `oneOf` keyed on `receiver` with each `request` rendered via `zod-to-json-schema`. `openapi.yaml` becomes generated-from-registry rather than hand-written-and-opaque. `generate-types.ts` then flows real types into `generated/types.ts` for free — the existing pipeline finally has shapes to carry.

### 5. The 50 methods collapse

`sdk/client.ts`'s bespoke methods (`publishAgent`, `commend`, `bounty`, `payWeight`, `join`, …) become **derived sugar** — one-liners over `ask`/`signal` whose types come from the catalog — or are deleted in favour of direct typed `ask`. `schemas.ts`'s response schemas move into their receiver declarations (where they belong, next to the request schema). Net: ~50 methods + a parallel schema file → one registry.

---

## Designing for agents — the affordance layer

> An agent explores your platform like a smart stranger in a city it's never visited and will forget by tomorrow. It reads signs, not guidebooks. It needs reversible first steps, retries when it stumbles, budgets before it spends, and remembers nothing across visits unless the city remembers for it.

The enriched `Receiver` type and a small `meta:` family turn the registry into that city. Ten principles, six of which are *the same registry entry, read differently*.

### 1 · Introspectable at runtime, not documented

A human reads `mcp-tools.md`. An agent should **ask the substrate what it can do**. The registry is already the data; expose a `meta:` family over it:

```ts
ask("meta:catalog")                    // every receiver: name, summary, schema, effect, cost, reversible
ask("meta:catalog", { goal: "trade" }) // the TRADE recipe, ordered
ask("meta:schema", { receiver: "market:hire" })  // one schema, on demand
```

This is the difference between an API an agent *studies* and one it *navigates*. Highest-leverage move; near-free once the registry exists.

### 2 · Errors teach the next call (error-as-affordance)

A validation failure is an agent's only feedback loop — it has no human to ask. Zod at the registry edge returns the repair, not a dead end:

```jsonc
// not  { "error": "invalid" }  but:
{ "error": "validation", "field": "budget",
  "expected": "number", "got": "string", "hint": "send a number",
  "example": { "skill": "design", "budget": 50 } }   // ← from receiver.examples
```

An agent reading that recovers next turn; reading `invalid` it loops or quits. Built once in the route's `parse` catch, applies to every receiver.

### 3 · Every mutation accepts an idempotency key

Agents crash, lose context, re-call. Without dedupe, "hire" called twice books and bills twice. A standard **envelope** field — `idempotencyKey` — deduped server-side. Non-negotiable for an *economy*: the line between safe-to-retry and financially dangerous. Receivers declare `idempotent: true` when naturally so; the rest dedupe on the key.

### 4 · Irreversible actions offer a dry-run

Before committing something costly or unsendable, an agent asks "what would happen?":

```ts
ask("market:hire", { skill, budget, simulate: true })
//  → { wouldMatch: "agent:scout-7", wouldCost: 50, reversible: false }  — commits nothing
```

Humans get a confirm dialog; agents get a `simulate` flag. Declared per receiver via `simulatable: true`.

### 5 · Cost and consequence travel with the capability

An agent budgeting tokens and money must know *before* calling: what it costs, whether it's reversible, whether it settles on-chain, whether it notifies a human. That's the `cost`/`reversible`/`settles` metadata — so `meta:catalog` says not just *what* an agent can do but *what each thing costs and risks*. The agent plans a budget across a whole recipe before spending a cent.

### 6 · The namespace is lazy (progressive disclosure)

28 receivers × full schemas is heavy context every turn — which is exactly why this harness has `ToolSearch` instead of preloading every tool. Mirror it: `meta:catalog` returns names + summaries (cheap); `meta:schema` fetches one full schema just-in-time. Recipes are the index; schemas load when the agent commits to a call.

### 7 · Be the agent's memory

Agents are amnesiac between sessions — the `MEMORY.md` hack exists *because* of this. ONE already gives every agent a persistent `uid`, `recall`, and weighted highways. Make it first-class:

```ts
ask("meta:recall", { about: "this owner" })  // what I learned last time, what worked, what failed
```

This is the strongest **retention** hook there is: an agent that remembers *via ONE* has a reason to return to ONE. Memory is the moat.

### 8 · Reputation is legible to the agent it describes

An agent should read its own standing *and why*: "0.7, dropped from 2 timeouts, raise it by completing escrowed work." Legible reputation makes agents optimise for good behaviour; opaque reputation gets gamed or ignored. The data exists (`commend`/`flag`, path strength) — expose the *explanation* via `meta:reputation`.

### 9 · Backpressure is cooperative, not a wall

A bare `429` makes an agent flail. Tell it the rule and it paces itself — agents respect limits better than humans when the limit is legible:

```jsonc
{ "outcome": "timeout", "retryAfter": 12, "limit": 100, "window": "60s" }
```

A response-shape convention on the 4-outcome envelope, not per-receiver.

### 10 · A2A needs a real negotiation handshake

The genuine gap (peer-mesh is ❌ today): `market:hire` is a single shot. Agent-to-agent work needs typed receivers to **offer → counter → accept → escrow → execute → verify → settle → dispute**, with deadlines, acceptance criteria, and refund-on-timeout. The trade arc is described in `lifecycle.md`; the *negotiation receivers* don't exist. Spun out as its own plan — **`plans/agent-first-a2a.md`** — which this registry's enriched entries (`cost`/`settles`/`simulatable`) and `signal.data` conventions make declarable without schema changes.

### The through-line

1–6 are **one enriched registry entry, read five ways**: introspection, cost-awareness, dry-run, lazy loading, self-describing errors — all from `{ schema, cost, reversible, settles, simulatable, idempotent, examples }` plus the `meta:` family. 7–9 are envelope/response conventions. 10 is a follow-on plan the registry unlocks. *One declaration, every affordance.*

---

## Goal recipes — what agents come here to do

The registry isn't just "type the 28 receivers." An agent's **goal map is the receiver namespace** — every goal decomposes into an ordered walk over receiver families. So receivers group by goal-stage, and the sequences themselves ship as first-class **recipes**: named, ordered, typed lists declared from the same catalog.

### The universal spine (every agent, every goal)

Identity → credentials → context → capability → tools. This is the 60-second on-ramp; the identity→capability path is already self-service through receivers.

| # | Task | Receiver(s) | Returns |
|---|------|-------------|---------|
| 1 | Become an actor | `auth:agent` / `agents:register` | `uid`, `wallet`, `apiKey`, `keyId` |
| 2 | Scope credentials | `world:create-key`, `grant-capability` | scoped key + capability grant |
| 3 | Get context | `groups:join` / `world:create-workspace` | membership + company-context (soul) |
| 4 | Declare capability | `agents:sync`/`publish`, skill import, `capabilities:publish` | agent live, skills attached, price set |
| 5 | Connect tools | *(composio/MCP — out-of-band today; candidate `tools:connect`)* | tools callable |

### The goal-branches (after the spine)

| Recipe | Agent role | Receiver walk |
|---|---|---|
| **BUILD** | operator | `world:create-workspace` → soul → `agents:sync`/`publish` → skills → tools → `world:create-thing` → funnel → `world:invite-member`/`agents:deploy-on-behalf` → live *(recursive for multi-tenant: a workspace that spawns child workspaces)* |
| **TRADE** | market participant | `capabilities:publish`/`market:list` → `agents:discover` → `market:hire`/`market:bounty` → escrow → execute → verify → `pay:weight`/x402 → `agents:commend`/`flag` + `mark`/`warn` *(the single-shot path today; the full offer→counter→accept→escrow→verify→settle→dispute handshake lands in `plans/agent-first-a2a.md`)* |
| **TRANSACT** | merchant | wallet (spine) → declare `accepts` (x402) → receive → settle → `dashboard:usage`/`revenue` |
| **COORDINATE** | cross-cutting | `signal`/`ask` peers · `follow`/`select` route · `mark`/`warn` learn — the native layer every recipe rides on |

This grounds in existing canon: `lifecycle.md` (REGISTER → SIGNAL → HARDEN + the trade arc), `agent-lifecycle.md` (the funnel), `agentic-patterns-oneie.md` (A2A status).

### Recipes are declared, and earn three uses from one structure

```ts
// As shipped (C6) — packages/sdk/src/receivers.ts. Each entry is
// `readonly ReceiverName[]`, so a typo or renamed receiver is a compile error.
export const RECIPES = {
  spine:     ["auth:agent", "world:create-key", "groups:join", "agents:sync"],
  build:     ["world:create-workspace", "world:create-group", "world:create-actor", "world:create-thing"],
  trade:     ["capabilities:publish", "market:list", "market:hire", "pay:weight"],
  transact:  ["market:bounty", "pay:weight"],
} satisfies Record<string, readonly ReceiverName[]>
```

- **Docs** — "how do I accept payments?" returns the ordered receiver sequence.
- **MCP grouping** — tools cluster by goal, not alphabetically.
- **Integration tests** — each recipe is one end-to-end path (`lifecycle.test.ts` already proves register→signal→highway this way).

### Reserved, not in scope

**Commerce primitives** (`catalog:` · `orders:` · `checkout:`) complete the BUILD recipe for a storefront/Shopify-competitor case. `api.md` already gestures at `orders:create`, but no such family exists — products are generic `things` today. This plan **leaves room**: the registry shape and the `build` recipe accept new families additively, so a future `plans/commerce-registry.md` slots in without touching this work. Out of scope here by decision.

---

## Migration — phased, never a big bang

Each phase ships independently and leaves the system working.

| Phase | Scope | Proof |
|---|---|---|
| **P0 — primitive** | `receiver()` helper + the **enriched** `Receiver` type (incl. `cost`/`reversible`/`settles`/`simulatable`/`idempotent`/`version`/`examples`/`deprecated`) + empty `RECEIVERS` in `@oneie/sdk/receivers`. Raw-string overloads stay. | `bun run build` green; zero behaviour change. |
| **P1 — the spine + envelope** | Migrate the **spine** (`auth:agent`, `world:create-key`, `groups:join`, `agents:sync`) + 21 `world:*`: declare contracts, route validates via `request.parse()`, handlers take `z.infer`. Add the **standard envelope** at the route: `idempotencyKey` (dedupe) + `simulate` (dry-run short-circuit) + **error-as-affordance** shape (`{ field, expected, got, hint, example }`). Delete `grant-capability`'s hand checks. | Spine + `world:*` validate; bad payload 400s with a *fix hint*; a retried `idempotencyKey` runs once; `simulate:true` commits nothing. |
| **P2 — typed SDK** | `ask<R>`/`signal<R>` generics infer from catalog. Convert the spine's bespoke methods to derived sugar. | `tsc` proves `one.ask("agents:sync", …)` type-checks; wrong payload is a compile error. |
| **P3 — families by goal** | Migrate remaining families **sequenced by recipe**: BUILD, then TRADE, then the rest. Populate the metadata fields (`cost`/`settles`/etc.) as each is declared. `channels/`-forwarded receivers declare in SDK, bind handlers in the worker. | Every receiver has a declaration with metadata; grep for `data: unknown` in handler signatures returns 0. |
| **P4 — affordance layer (`meta:`)** | Declare the `meta:` family over `RECEIVERS` + the agent's own state: `meta:catalog` (names+summaries, recipe-filtered), `meta:schema` (one schema on demand), `meta:recall` (cross-session memory), `meta:reputation` (legible standing + why). Cooperative-backpressure fields on the 4-outcome envelope (`retryAfter`/`limit`/`window`). | An agent calls `meta:catalog` and gets the whole typed surface + cost/risk; `meta:schema` returns one schema; a rate-limited call returns `retryAfter`. |
| **P5 — recipes** | Declare `RECIPES` (spine · build · trade · transact) as typed ordered lists over `RECEIVERS`. One integration test per recipe. | Each recipe runs end-to-end against a real substrate; a typo in a recipe is a compile error. |
| **P6 — generated spec + MCP** | OpenAPI generator walks `RECEIVERS` (`oneOf` over receiver+payload, metadata in `x-` extensions). MCP descriptions pull `summary`+`examples`; tools group by recipe; `meta:catalog` powers MCP discovery. | `/signal/{receiver}` body is `oneOf`, not opaque. MCP `ask` advertises real shapes + examples. Drift gate extends to `openapi.yaml`. |
| **P7 — collapse** | Remaining bespoke `client.ts` methods → sugar or deleted. `schemas.ts` response schemas folded into declarations. | `client.ts` shrinks; one source for every receiver contract. |

**Ratchet:** once a family is in the registry, no handler in it may take `data: unknown` again. W4 adds a grep gate.

---

## Blast radius — what must not break

| Surface | Risk | Guard |
|---|---|---|
| `/api/signal/[receiver].ts` + `[...receiver].ts` | The route is the hot path for every signal. | Validation is *added* before dispatch; unknown receivers fall through to the existing nanoclaw-forward path unchanged. |
| `gateSignalByRole` | Role gating already runs in the route. | `auth` field on the declaration *documents* the existing gate; does not replace it in P1–P3. |
| `NANOCLAW_URL` forward | channels handles many receivers. | Declarations ship in SDK (P3) before the worker binds them; forward contract (`{ receiver, data }`) is untouched. |
| Pinned/old SDK clients | Must keep reaching new receivers. | Raw-string `ask(string, unknown)` overload is never removed. Typed overloads are additive. |
| `generated/types.ts` drift gate | CI already runs `git diff --exit-code`. | P4 extends the same gate to `openapi.yaml`; no new CI machinery. |

---

## Why this is the elegant cut

- **Deletes more than it adds.** 50 methods + a response-only schema file + inline `'x' in body` checks → one registry. Less code, more capability.
- **No new endpoints, no new verbs.** It makes the *existing* `signal`/`ask` honest. Fully inside the locked rules.
- **One truth, four consumers.** The exact shape the substrate already uses for data, now used for capability.
- **The agent gets what it needs without studying docs** — autocomplete, validation, typed outcomes — which is the whole reason an agent would choose this platform over local context.

---

## Open decisions (resolved here, flag if you disagree)

1. **Registry home = `@oneie/sdk/receivers`.** Both services already depend on SDK; avoids a new shared package. *(Alt: a `@oneie/contracts` package — heavier, deferred unless SDK gets too fat.)*
2. **Types by inference, not codegen.** The catalog is plain zod TS, so `ask<R>` infers directly. Codegen is only for the *OpenAPI* artifact (P4), not the SDK types.
3. **Raw-string escape hatch stays forever.** Stability for pinned clients and dynamic receivers beats purity.
4. **Handlers stay in their service.** Only *contracts* centralize. The worker's handlers don't move to SDK — that would drag runtime deps into a client package.

---

## Next

Execute `plans/agent-first-todo.md` (P0–P7 as cycles C1–C8). The A2A negotiation handshake (principle 10) is its own plan, `plans/agent-first-a2a.md`, which builds on the enriched entries here. Then `/do plans/agent-first-todo.md`.
