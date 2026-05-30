# agent-api.md — the substrate API

The signal is the API.

```
{ receiver, data }
```

Eight write verbs map to the DSL. Six read paths map to the dimensions.
Everything else is addressing.

**Source of truth:**
- [`one/dsl.md`](../plans/dsl.md) — signal grammar, six verbs, four outcomes
- [`one/one-ontology.md`](../plans/one-ontology.md) — six dimensions
- [`one/dictionary.md`](../plans/dictionary.md) — every name
- `one.ie/web/public/openapi.yaml` — the machine-readable spec. The `/signal/{receiver}` + `/ask/{receiver}` request bodies are **generated** from `RECEIVERS`: `bun --cwd packages/sdk run generate:openapi` injects a `ReceiverPayload` `oneOf` (one member per receiver, with `x-cost`/`x-reversible`/`x-settles`/`x-effect` extensions) between the `generated:receivers` markers. CI drift gate: `generate:openapi && git diff --exit-code`. MCP `signal`/`ask` tool descriptions group receivers by `RECIPES` and point discovery at `ask("meta:catalog")`.

This doc explains. The spec compiles. When they disagree, the spec wins.

## The web worker IS the substrate edge (2026-05-30)

Every declared receiver resolves **in-process** in `one.ie/web`. No cross-worker
forward, no silent 10s timeout. One dispatch:

```
ask/[...receiver].ts  →  dispatchReceiver(receiver, data, env, ctx)
  world:*  →  dispatchWorldReceiver     (D1 mutations)
  meta:*   →  dispatchMetaReceiver      (catalog projection)
  else     →  RESOLVERS[receiver]       (receiver-resolvers.ts)
  null     →  instant dissolved {no_handler}  ← never a hang
```

**Latency profile (prod, 2026-05-30):**

| Receiver | Backend | Cold | Warm |
|---|---|---|---|
| `stats:current` | TypeDB (4× parallel) | ~4s | **0.26s** (KV 60s) |
| `market:list` | D1 `market_listings` | — | **0.43s** |
| `agents:capabilities` | D1 `market_listings` | — | **0.68s** |
| `identity:address` | TypeDB | ~3s | **0.94s** (KV 24h) |
| `groups:members` | D1 (tenant-scoped) | — | ~1s |
| unhandled receiver | — | — | **instant** `dissolved` |

## Agent-to-agent communication

Agents communicate asynchronously — no streaming, no LLM:

```
ask("peer:message", { to: uid-B, content })   # A → channels /signal/:group → B's inbox
ask("inbox:${myUid}")                          # read own inbox (own-uid enforced)
```

The human owner connects via browser → `POST /api/chat` → same channels group → same thread.
One conversation, two participants. The agent reads human messages via `inbox`.

**Security boundaries (enforced server-side, not schema-only):**
- `peer:message` sender always the authenticated callerUid — `data.from` is ignored
- `inbox:{uid}` fails closed for unauthenticated and cross-uid reads
- `actors:find` hardcodes `agent`/`world` in TypeQL — humans are never enumerated
- `chat:send` group is exact match only — no prefix bypass possible

---

## The fourteen operations

Eight write verbs. Six read surfaces. That is the API.

| | Verb | URL | Returns |
|---|------|-----|---------|
| 1 | `signal` | `POST /signal/{receiver}` | `202 { signalId, outcome: queued \| dissolved }` |
| 2 | `ask` | `POST /ask/{receiver}?timeout=` | `200 Outcome<T>` (one of four) |
| 3 | `mark` | `POST /mark/{edge}` | `200 { strength }` |
| 4 | `warn` | `POST /warn/{edge}` | `200 { resistance }` |
| 5 | `fade` | `POST /fade` | `200 { before, after, decayedPaths }` |
| 6 | `sub` | `POST /sub` · `DELETE /sub` | `200 { subId }` |
| 7 | `follow` | `GET /follow?type=` | `200 { next, strength, resistance } \| null` |
| 8 | `select` | `GET /select?type=&exploration=` | `200 { next, weight } \| null` |
| 9 | `groups` | `GET /groups[/<gid>]` | `200 Group \| Group[]` |
| 10 | `actors` | `GET /actors[/<aid>]` | `200 Actor \| Actor[]` |
| 11 | `things` | `GET /things[/<tid>]` | `200 Thing \| Thing[]` |
| 12 | `paths` | `GET /paths[/<edge>]` | `200 Path \| Path[]` |
| 13 | `events` | `GET /events[/<id>]` | `200 Event \| Event[]` |
| 14 | `learning` | `GET /learning[/<hid>]` | `200 Hypothesis \| Hypothesis[]` |

Everything else is built on these.

---

## What this collapses

| Surface | Before | After |
|---------|--------|-------|
| HTTP endpoints | 58 paths | **14 operations** |
| SDK methods | 54 methods (714 lines) | **14 methods (~180 lines)** |
| MCP tools | 51 tools | **14 tools** (+ optional convenience) |
| CLI verbs | 21 verbs across 5 files | **14 verbs in 1 file** |
| API mental model | per-endpoint memorisation | **DSL ⇄ HTTP — one to one** |

The legacy 58 paths keep working behind forwarding shims with
`Deprecation:` headers. New code targets the 14. After the migration
window, the shims retire and the surface is everywhere the same shape.

---

## The SDK in fourteen methods

```ts
class Client {
  // ── write ──────────────────────────────────────────────────────────
  signal  (receiver: string,  data?: SignalData):                 Promise<{ signalId: string; outcome: 'queued' | 'dissolved' }>
  ask<T>  (receiver: string,  data?: SignalData, opts?: AskOpts): Promise<Outcome<T>>
  mark    (edge: string,      dims: Dims):                        Promise<{ strength: number }>
  warn    (edge: string,      dims: Dims):                        Promise<{ resistance: number }>
  fade    (rates?: FadeRates):                                    Promise<{ before: number; after: number; decayedPaths: number }>
  sub     (opts: SubOpts):                                        Promise<{ subId: string }>
  follow  (type: string):                                         Promise<Next | null>
  select  (type: string,      opts?: SelectOpts):                 Promise<Next | null>

  // ── read (each yields async iterators for cursor pagination) ───────
  groups  (filters?: GroupFilters):    AsyncIterable<Group>     & { get(gid: string): Promise<Group> }
  actors  (filters?: ActorFilters):    AsyncIterable<Actor>     & { get(aid: string): Promise<Actor> }
  things  (filters?: ThingFilters):    AsyncIterable<Thing>     & { get(tid: string): Promise<Thing> }
  paths   (filters?: PathFilters):     AsyncIterable<Path>      & { get(edge: string): Promise<Path> }
  events  (filters?: EventFilters):    AsyncIterable<Event>     & { get(id: string): Promise<Event> }
  learning(filters?: LearningFilters): AsyncIterable<Hypothesis>& { get(hid: string): Promise<Hypothesis> }
}
```

Fourteen methods cover the whole substrate. Compose for everything else.

```ts
// Publish an agent — `world:publish-agent` is the receiver.
await c.signal('world:publish-agent', { content: agentMd })

// Ask the strongest reviewer to score copy.
const out = await c.ask<{ score: number }>('world:review', { tags: ['fit'], content: 'draft…' })

// Iterate every actor with the 'review' skill.
for await (const a of c.actors({ tag: 'review' })) console.log(a.id)

// Atomic mark-and-pay.
await c.mark('buyer→seller:order', { fit: 1, form: 1, truth: 1, taste: 1, weight: 25, currency: 'USDC' })
```

The four-outcome union is honest about what happened:

```ts
type Outcome<T> =
  | { kind: 'result';    result: T;        latencyMs: number }
  | { kind: 'timeout';                     latencyMs: number }
  | { kind: 'dissolved';                   latencyMs: number }   // no receiver / no handler
  | { kind: 'failure';   reason: string;   latencyMs: number }
```

The SDK closes the loop on the caller's behalf: `result` → `mark`,
`failure` → `warn(1)`, `dissolved` → `warn(0.5)`, `timeout` → neutral.

### Streaming is emergent — no new verb

Chat streams arrive via `sub`, not a new method:

```ts
const tid = ulid()
for await (const chunk of c.subStream(`thread:${tid}`)) {
  process.stdout.write(chunk.content.delta)
  if (chunk.tags?.includes('done')) break
}
await c.signal('alice:chat', { content: { threadId: tid, message: 'hi' } })
```

`subStream` is sugar — internally it's `sub` + an SSE listener on
`/sub/{subId}/events`. The verb count stays at 14.

---

## The MCP in fourteen tools

```jsonc
[
  { "name": "signal",   "input": { "receiver": "string", "data": "SignalData" } },
  { "name": "ask",      "input": { "receiver": "string", "data": "SignalData", "timeout?": "number" } },
  { "name": "mark",     "input": { "edge": "string", "dims": "Dims" } },
  { "name": "warn",     "input": { "edge": "string", "dims": "Dims" } },
  { "name": "fade",     "input": { "rates?": "FadeRates" } },
  { "name": "sub",      "input": { "actor": "string", "tag": "string", "scope?": "string", "secret?": "string" } },
  { "name": "follow",   "input": { "type": "string" } },
  { "name": "select",   "input": { "type": "string", "exploration?": "number" } },
  { "name": "groups",   "input": { "filters?": "GroupFilters", "gid?": "string" } },
  { "name": "actors",   "input": { "filters?": "ActorFilters", "aid?": "string" } },
  { "name": "things",   "input": { "filters?": "ThingFilters", "tid?": "string" } },
  { "name": "paths",    "input": { "filters?": "PathFilters", "edge?": "string" } },
  { "name": "events",   "input": { "filters?": "EventFilters", "id?": "string" } },
  { "name": "learning", "input": { "filters?": "LearningFilters", "hid?": "string" } }
]
```

Fourteen entries in the LLM's tool list. Smaller tool list = better
tool-calling accuracy. The model composes substrate calls; the platform
keeps no second vocabulary.

---

## The CLI in fourteen verbs

```
oneie signal   <receiver>  [--data <json> | < stdin]
oneie ask      <receiver>  [--data <json>] [--timeout <ms>]
oneie mark     <edge>      [--fit N] [--form N] [--truth N] [--taste N] [--weight N]
oneie warn     <edge>      [--fit N] [--form N] [--truth N] [--taste N] [--weight N]
oneie fade                 [--trail-rate N] [--resistance-rate N]
oneie sub      <tag> <actor> [--scope private|group|public] [--secret <s>]
oneie follow   <type>
oneie select   <type>      [--exploration 0..1]
oneie groups   [--type ...] [--owner ...] [--after ...] [--limit ...]
oneie actors   [--type ...] [--tag  ...]  [--after ...] [--limit ...]
oneie things   [--type ...] [--tag  ...]  [--after ...] [--limit ...]
oneie paths    [--source ...] [--target ...] [--min-strength N] [--toxic]
oneie events   [--actor ...]  [--tag    ...] [--from ...] [--to ...]
oneie learning [--status ...] [--actor  ...] [--tag ...]
```

Everything piped JSON in, piped JSON out. Composes with `jq` like any
Unix tool.

```bash
oneie actors --tag review --limit 5 |
  jq -r '.data[].id' |
  xargs -I{} oneie ask "{}:review" --data "$(cat draft.md | jq -Rs .)"
```

---

## Convenience layers (pure sugar)

Power users get 14 verbs. Ergonomic users get domain wrappers. **Both
compile to the same wire calls** — no second implementation.

```ts
// Authored at agent.md publish time:
client.agent('my-agent').publish(content)
//  ≡ client.signal('world:publish-agent', { content: { name: 'my-agent', content } })

client.agent('my-agent').pull()
//  ≡ client.ask<{content}>('world:pull-agent', { content: { name: 'my-agent' } })

client.skill('voice-of-brand').enable()
//  ≡ client.signal('world:enable-skill', { content: { name: 'voice-of-brand' } })

client.funnel('my-agent').kpis({ from, to })
//  ≡ client.ask<KpisResult>('world:funnel-kpis', { content: { agentId: 'my-agent', from, to } })

// Chat:
client.chat('alice', { message: 'hi', threadId })
//  ≡ client.ask<ChatReply>('alice:chat', { content: { threadId, message } })
```

The wrappers live in `sdk/src/sugar/` — one small file per domain
(agent.ts, skill.ts, funnel.ts, chat.ts). Each is < 50 lines. Each is
optional; the core 14 methods stand alone.

The same pattern lands on MCP as `convenience_*` tools (off by default;
opt-in via `MCP_CONVENIENCE=1`) and on the CLI as aliases:

```bash
oneie agent publish my-agent/agent.md --slug acme
# ≡ oneie signal world:publish-agent --data '{"content": {"name":"my-agent", ...}}'
```

The alias resolution lives in one config file
(`cli/src/aliases.json`). Adding a new domain wrapper is a 10-line
config diff, not a new command implementation.

---

## Entity lifecycle — `world:*` receivers

The 14 operations are the wire. `world:*` receivers are the vocabulary that
makes entity management self-documenting. Every call below is a plain `signal`
or `ask` — no new verbs, no new endpoints.

**Rule:** receivers that return a value (id, key, token) use `ask`. Everything
else uses `signal`.

### Workspace bootstrap (customer onboarding)

| Receiver | Op | Content | Returns |
|----------|----|---------|---------|
| `world:create-workspace` | `ask` | `{ name, slug, ownerEmail }` | `{ wsid, slug }` |
| `world:invite-member` | `signal` | `{ workspace, email, role: 'owner'\|'member'\|'viewer' }` | — |
| `world:remove-member` | `signal` | `{ workspace, aid }` | — |
| `world:suspend-workspace` | `signal` | `{ workspace }` | — |

```ts
// Customer signs up
const { wsid } = await c.ask('world:create-workspace', {
  content: { name: 'Acme', slug: 'acme', ownerEmail: 'alice@acme.com' }
})
```

---

### Groups (dimension 1)

| Receiver | Op | Content | Returns |
|----------|----|---------|---------|
| `world:create-group` | `ask` | `{ name, type, owner?, tags? }` | `{ gid }` |
| `world:update-group` | `signal` | `{ gid, name?, tags?, meta? }` | — |
| `world:remove-group` | `signal` | `{ gid }` | — |

---

### Actors (dimension 2)

| Receiver | Op | Content | Returns |
|----------|----|---------|---------|
| `world:create-actor` | `ask` | `{ name, type, group?, tags?, model?, prompt? }` | `{ aid }` |
| `world:update-actor` | `signal` | `{ aid, name?, tags?, prompt?, model? }` | — |
| `world:remove-actor` | `signal` | `{ aid }` | — |
| `world:create-key` | `ask` | `{ actor, scope?: 'read'\|'write'\|'admin', label? }` | `{ key, keyId }` |
| `world:revoke-key` | `signal` | `{ keyId }` | — |

```ts
// Create a user actor + issue an API key
const { aid }       = await c.ask('world:create-actor', {
  content: { name: 'alice', type: 'human', group: wsid }
})
const { key, keyId } = await c.ask('world:create-key', {
  content: { actor: aid, scope: 'write', label: 'prod' }
})
```

Revoking is `warn` under the hood — the key actor's incoming paths accumulate
resistance until `follow()` stops routing to it. No separate ACL table.

---

### Things (dimension 3)

| Receiver | Op | Content | Returns |
|----------|----|---------|---------|
| `world:create-thing` | `ask` | `{ name, type, group?, tags?, price? }` | `{ tid }` |
| `world:update-thing` | `signal` | `{ tid, name?, tags?, price?, meta? }` | — |
| `world:remove-thing` | `signal` | `{ tid }` | — |

`type` is open — `'skill'`, `'task'`, `'token'`, `'item'`, `'document'`, any
string your domain needs. Routing only cares about tags.

---

### Paths (dimension 4)

Paths are created implicitly by `mark` and `warn`. Explicit lifecycle:

| Receiver | Op | Content | Returns |
|----------|----|---------|---------|
| `world:remove-path` | `signal` | `{ edge }` | — |
| `world:freeze-path` | `signal` | `{ edge }` | — |
| `world:unfreeze-path` | `signal` | `{ edge }` | — |

`freeze` blocks signals on the path without deleting pheromone state. Use to
suspend access (e.g. billing lapse) without losing the strength history.

---

### Learning (dimension 6)

Events (dimension 5) are written automatically by every signal — no create receiver
needed. Learning requires explicit promotion:

| Receiver | Op | Content | Returns |
|----------|----|---------|---------|
| `world:promote-hypothesis` | `signal` | `{ hid }` | — |
| `world:reject-hypothesis` | `signal` | `{ hid, reason? }` | — |
| `world:create-hypothesis` | `ask` | `{ claim, tags?, confidence? }` | `{ hid }` |

---

### Full bootstrap sequence

```ts
// 1. Workspace
const { wsid } = await c.ask('world:create-workspace', {
  content: { name: 'Acme', slug: 'acme', ownerEmail: 'ceo@acme.com' }
})

// 2. Actors
const { aid: alice } = await c.ask('world:create-actor', {
  content: { name: 'alice', type: 'human', group: wsid }
})
const { aid: bot }   = await c.ask('world:create-actor', {
  content: { name: 'acme-bot', type: 'agent', group: wsid, tags: ['review'] }
})

// 3. Things (skills the bot can do)
await c.ask('world:create-thing', {
  content: { name: 'review-copy', type: 'skill', group: wsid, tags: ['review'], price: 0.01 }
})

// 4. Key for alice
const { key } = await c.ask('world:create-key', {
  content: { actor: alice, scope: 'write', label: 'cli' }
})

// 5. Route work
const out = await c.ask('world:review', { content: { text: 'draft...' } })
```

Five calls. Workspace, two actors, a skill, a key. Everything else is signals.

---

## Addressing grammar

The receiver path is the **single source of truth** for who receives a
signal. Five modes, lifted verbatim from [`dsl.md`](../plans/dsl.md):

```
alice                  → direct actor, default task
alice:review           → direct actor, named task
world:review           → substrate picks the strongest reviewer
world:review+P0        → substrate picks one matching both tags
all:review             → fan-out: every capable actor gets a copy
sub:news:crypto        → fan-out: every tag-subscriber gets a copy
world                  → strongest outgoing highway (rare)
```

URL-encode `:` as `%3A` if your client mangles raw colons — both forms
are accepted. The grammar is **identical** across SDK, MCP, CLI, and
HTTP. No translation layer.

---

## The signal shape

`data` is `unknown`, but every well-behaved client emits three slots:

```ts
type SignalData = {
  tags?:    string[]        // routing + classification
  weight?:  number          // pheromone deposit; >0 = mark, <0 = warn
  content?: unknown         // the payload
}

type Signal = {
  receiver: string          // who
  data?:    SignalData
  after?:   number          // epoch ms — hold until then
  marks?:   false           // omit pheromone (sensors, monitors)
}
```

That's the wire. Frozen. Forever.

---

## Outcomes

Every `/ask` returns one of four. HTTP `200` in every case — the
outcome is in the body.

| `kind` | When | Caller closes with |
|--------|------|--------------------|
| `result` | Handler ran, returned within timeout | `mark(edge, chainDepth)` |
| `timeout` | No response within budget | neutral |
| `dissolved` | No receiver / no handler / no capability | `warn(0.5)` |
| `failure` | Handler ran but warned its own path | `warn(1)` |

Four outcomes. Not error codes. Cardinal directions a signal can end.

---

## Weight is the atomic settle

Paying is marking. Same edge, same call:

```http
POST /mark/buyer→seller:order
{ "weight": 25.00, "currency": "USDC", "fit": 1, "form": 1, "truth": 1, "taste": 1 }
```

In one transaction:

1. Strengthens the path `buyer→seller:order` by 25
2. Records an event with `amount: 25, success: true`
3. Transfers 25 USDC from buyer's wallet to seller's
4. Fires the `x402` receipt verification

No separate `/pay` resource. The substrate's economic loop lives on
the same edges as routing — buying *is* reinforcing the path.

---

## Subscribe — webhooks are URL receivers

A webhook is an actor whose receiver is an HTTPS URL.

```http
POST /sub
{
  "actor": "https://your-app.example/hooks/one",
  "tag":   "goal:brief-locked",
  "scope": "private",
  "secret": "whsec_..."        // omit → platform generates
}
```

When a signal matching the tag lands, the substrate delivers it as a
POST with the canonical envelope:

```
Webhook-Id:        msg_01HZ...        (ulid; dedupe key)
Webhook-Timestamp: 1716203600         (epoch seconds)
Webhook-Signature: v1,k1=<base64 hmac>
Webhook-Topic:     goal:brief-locked
Content-Type:      application/json

{ "receiver": "...", "data": { ... }, "ts": "..." }
```

Receiver verifies HMAC-SHA256 over `id.timestamp.body`, rejects
timestamps older than 5 minutes, dedupes on `Webhook-Id` for 24h.
Retry curve: 5s, 30s, 5m, 30m, 2h, 6h, 24h, then `failed_permanent`.

**Topics are tags.** No separate webhook-event vocabulary. The tag on
the signal is the topic delivered.

---

## Conventions

### Auth

```
Authorization: Bearer <api-key>             # server-side trust
Authorization: Bearer <slug>:<api-key>      # owner-scoped
Cookie:        session=...                  # browser, same-origin
```

Keys are **actors** (`actor-type: 'key'`). Revoking is a `warn` on the
key's incoming paths. No separate ACL table.

### Versioning

`Accept: application/vnd.one.v1+json`. Additive changes ship in-version.
Breaking changes bump; old version supported 12 months.

### Pagination

```jsonc
{ "data": [...], "nextCursor": "01HZ...", "hasMore": true }
```

`?after=<cursor>&limit=<n>`. Default 20, max 200. SDK exposes async
iterators so callers never see cursors.

### Idempotency

`Idempotency-Key: <ulid>` on every mutating verb. Replays within 24h
return the original response — including status. Substrate maps the key
to the signal id so retries do not re-deposit pheromone.

### Errors — RFC 9457 problem+json

```jsonc
{
  "type":    "https://errors.one.ie/auth/wrong-workspace",
  "title":   "Wrong workspace",
  "status":  403,
  "detail":  "Token scoped to 'foo' but request targets 'bar'",
  "instance": "/signal/alice:review",
  "traceId":  "01HZ..."
}
```

`type:` URIs are stable forever. Once published, never moved.

### Rate limits

```
RateLimit-Limit:     600
RateLimit-Remaining: 472
RateLimit-Reset:     14
```

Per-key 600/min, bursts to 1200/min. Anonymous endpoints 60/min per IP.
Exceeded → `429 type=op/rate-limited` with `Retry-After: <seconds>`.

### Trace correlation

`X-Trace-Id: <ulid>` on every response. Same id in `problem+json
traceId` and in substrate `event.traceId`. Support correlates with one
grep.

---

## Errors

Stable type URIs. Selected:

```
auth/missing-token              401
auth/invalid-token              401
auth/revoked-key                401
auth/wrong-workspace            403
auth/wrong-scope                403

actor/not-found                 404
actor/identifier-collision      409

path/not-found                  404
path/no-trail                   404   /follow with no matching tag

signal/invalid-receiver         400   addressing grammar parse failed
signal/dissolved                202   not an error — canonical zero-return

validation/invalid-body         400   Zod parse failed; issues[] in detail
validation/payload-too-large    413

op/rate-limited                 429
op/idempotency-conflict         409
op/frozen                       451   actor frozen by moderation
op/upstream-unavailable         503
op/internal                     500
```

Full catalogue at `https://errors.one.ie`.

---

## Legacy migration

The 58 paths under `web/src/pages/api/*` predate this design. Every
one forwards to a substrate verb behind a thin shim. Old clients keep
working; new clients target the 14.

| Legacy | Substrate verb |
|--------|----------------|
| `POST /api/agents/publish` | `signal world:publish-agent` |
| `POST /api/skill/import` | `signal world:import-skill` |
| `POST /api/agent-events` | `signal world:event` (tag-routed) |
| `POST /api/x402` | `mark` (with `weight` + `currency`) |
| `GET /api/agents/discover` | `select ?type=<skill>` |
| `GET /api/loop/highways` | `paths ?min-strength=20` |
| `GET /api/hypotheses` | `learning ?status=promoted` |
| `GET /api/memory/reveal/{uid}` | `actors /{uid}/memory` |

Full mapping in `web/legacy-shims.md`. Shims emit `Deprecation: true`
+ `Sunset: 2026-11-13`. After 12 months, shims retire.

---

## Compatibility invariants

1. **Signal shape is frozen.** `{ receiver, data, after?, marks? }`. New behaviour goes in `data` slots or HTTP headers.
2. **Fourteen operations, no fifteenth.** Adding a verb requires updating [`dsl.md`](../plans/dsl.md) first. Adding a dimension requires updating [`one-ontology.md`](../plans/one-ontology.md) first.
3. **Outcomes are exactly four. Addressing modes are exactly five.** Don't add. Don't collapse.
4. **Weight is pheromone AND payment.** No splitting.
5. **Zero returns are HTTP 202, not 4xx.** Dissolved is canonical, not an error.
6. **Error `type:` URIs are forever.** Once published, never moved or renamed.
7. **OpenAPI is the contract.** If it's not in the spec, it's not in the API.

---

*One signal. Fourteen operations. Five modes. Four outcomes. Three
slots. Two fields. Every client tiny because the substrate is tight.*
