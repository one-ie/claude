---
name: sdk
description: Extend or read @oneie/sdk — the receiver registry, SubstrateClient methods, and the barrel exports. Use when adding an SDK method, declaring a new receiver contract, checking whether a receiver name is real before writing signal()/ask(), picking the right import path (bare barrel vs subpath), or exporting a new SDK type. Triggers — "add an SDK method", "add a receiver", "is <x:y> a real receiver", "typed ask/signal", "export this from the SDK", "which @oneie/sdk import path", "signals-parity is failing".
---

# @oneie/sdk — SDK client methods and type exports

The SDK is the client-side interface to ONE. It's where agents and apps interact with the substrate.

## Structure

```
packages/sdk/
├── src/
│   ├── index.ts      # barrel — the public surface
│   ├── client.ts     # SubstrateClient — every method
│   ├── receivers.ts  # RECEIVERS + RECIPES — capability
│   ├── types.ts      # SdkConfig, Outcome, shared shapes
│   ├── schemas.ts    # hand-written zod schemas
│   ├── errors.ts     # SubstrateError + subclasses
│   ├── brain.ts      # BrainClient — graph-in-RAM
│   ├── gateway.ts    # GatewayClient — raw TypeQL
│   ├── generated/    # codegen from schema/*.tql
│   └── {domain}.ts   # pay, skills, broadcast, wallet…
├── scripts/
│   └── signals-parity.ts   # guards receiver counts
└── tests/            # vitest, 24 suites (+ test/, 3 more)
```

There is no `src/types/` directory and no `src/brain/` directory — types are one
flat `types.ts` plus per-domain files; brain and gateway are single modules.

## Pattern: Adding a new public method

### 1. Declare the receiver contract (in `packages/sdk/src/receivers.ts`)

Capability starts in the registry, not on the client. Each entry is a
`receiver({ … })` call with zod request/response plus agent-ergonomic metadata.

```typescript
// packages/sdk/src/receivers.ts
export const RECEIVERS = {
  "links:create": receiver({
    receiver: "links:create",
    summary: "Create an actor-bound tracked link.",
    request: z.object({
      actorId: z.string().describe("Contact the link is bound to"),
      destination: z.string().optional().describe("Path the click lands on"),
      expiresInDays: z.number().optional().describe("TTL in days"),
    }),
    response: z.object({ id: z.string(), sig: z.string(), url: z.string() }),
    effect: "ask", cost: "free", reversible: false,
    idempotent: false, auth: "member",
  }),
} as const;
```

The handler binds elsewhere — `one.ie/web/src/lib/world-receivers.ts` (and its
`resolvers/` modules) for web, channels tool modules for the agent worker. The
SDK ships the catalog; the services ship the implementations.

### 2. Add the method to SubstrateClient

Most receivers need no method at all — `one.ask("links:create", …)` is already
typed off the registry. Add a method only when you want sugar over the outcome.

```typescript
// packages/sdk/src/client.ts
export class SubstrateClient {
  /** Sugar over `ask("links:create", …)`; the receiver walks authority
   *  server-side. Returns the result outcome, or null otherwise. */
  async createLink(opts: {
    actorId: string;
    destination?: string;
    expiresInDays?: number;
  }): Promise<{ id: string; sig: string; url: string } | null> {
    const outcome = await this.ask("links:create", opts);
    return outcome.kind === "result"
      ? (outcome.result as { id: string; sig: string; url: string })
      : null;
  }
}
```

**Rules:**
- Method name matches the domain (`createLink`, `listGroups`, `authAgent`)
- Method calls `this.signal()` / `this.ask()` / the private `this.r()` — never
  a bare `fetch` to a URL it invents
- Input is typed (an inline options object or a named interface, not `any`)
- Return type is explicit — never `Promise<any>`
- `ask()` returns `Outcome<T>` with a `kind` of `result | timeout | dissolved |
  failure`. The caller MUST close the loop; a method that silently drops the
  three non-`result` kinds is a locked-rule violation

### 3. Export from the barrel

```typescript
// packages/sdk/src/index.ts
export { SubstrateClient } from "./client.js";
export { receiver, RECEIVERS, RECIPES } from "./receivers.js";
export type { Receiver, ReceiverName, ReqOf, ResOf } from "./receivers.js";
```

**Rules:**
- `.js` extensions in every relative import — the package is ESM-only
- Types are exported with `export type` so consumers can import types alone
- If the module must be importable from a Cloudflare Worker, add a subpath to
  `exports` in `package.json` (`"./receivers"`, `"./gateway"`, `"./wallet"`, …).
  Workers must import by module path — the bare `@oneie/sdk` barrel crashes them

## Pattern: Receiver registration

`RECEIVERS` is the one source of truth for capability. Every name you pass to
`signal()` or `ask()` must be a key in it — 273 receivers across 69 namespaces
as of 2026-08-02. Read the registry for the live number; never hand-type one.

Typing works by inference off the registry, with an escape hatch:

```typescript
await one.ask("world:create-actor", { name, type })  // typed request + Outcome
await one.ask("world:create-actor", { wrong: 1 })    // compile error
await one.ask("dynamic:thing", { anything: 1 })      // escape hatch (unknown)
```

The escape hatch is why a fictional receiver still type-checks and then 404s at
runtime. **Grep `receivers.ts` before writing any example.** Known non-receivers
that read plausibly: there is no `inbox:` namespace and no `learning:know` key.

**Rules:**
- Receiver name is `namespace:verb` — the colon lane is reserved (`text/dictionary.md`)
- `effect` declares `signal` (fire-and-forget) vs `ask` (awaits an outcome)
- `auth` declares who may call it (`public` · `member` · `owner` · `agent_key` · `none`)
- `request` / `response` are zod — they feed OpenAPI, MCP tool schemas, and `meta:catalog`
- After adding one, run `bun packages/sdk/scripts/signals-parity.ts` — it compares
  per-namespace counts against `text/signals-catalog.md` and exits non-zero on drift

## Pattern: Testing SDK methods

Client tests intercept `fetch` to verify the request shape — that is not a
substrate mock, it's a transport assertion.

```typescript
// packages/sdk/tests/group-ops.test.ts
import { beforeEach, describe, expect, it, vi } from "vitest";
import { SubstrateClient } from "../src/client.js";

let calls: Array<{ url: string; init: RequestInit }>;

beforeEach(() => {
  calls = [];
  globalThis.fetch = vi.fn(async (url, init) => {
    calls.push({ url: String(url), init: init ?? {} });
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as unknown as typeof fetch;
});

describe("createGroup", () => {
  it("threads parentGid through as parent_gid", async () => {
    const one = new SubstrateClient({ baseUrl: "https://one.ie", apiKey: "k" });
    await one.createGroup({ gid: "group:acme-mkt", name: "Marketing", parentGid: "group:acme" });
    const call = calls.find((c) => c.url.endsWith("/api/groups"));
    expect(JSON.parse(String(call?.init.body)).parent_gid).toBe("group:acme");
  });
});
```

**Rules:**
- `bun run test` in `packages/sdk` (vitest)
- Assert the request shape (path, method, body keys) — that's what the SDK owns
- Assert every `Outcome` kind the method branches on, not just `result`
- Don't mock TypeDB or Sui — real data or skip (`.claude/rules/engine.md`)
- `emit()` telemetry also posts to `/api/signal`; filter to the call under test

## Anti-patterns

**Direct HTTP calls in client methods**
```typescript
// WRONG
async getBroadcast(id: string) {
  return fetch('/api/broadcasts/' + id).then(r => r.json());
}
```
**Fix:** Use `this.ask('broadcast:get', { broadcastId: id })` — the receiver owns the route.

**Untyped inputs/outputs**
```typescript
// WRONG
async createLink(input: any): Promise<any> {
  return this.ask('links:create', input);
}
```
**Fix:** Type the options object and the return; let `ReqOf`/`ResOf` infer.

**Dropping the outcome**
```typescript
// WRONG
async createLink(opts: LinkOpts) {
  const outcome = await this.ask('links:create', opts);
  return outcome.result;  // undefined on timeout | dissolved | failure
}
```
**Fix:** Branch on `outcome.kind` and return a closed shape (`… | null`).

**SDK logic**
```typescript
// WRONG
async createLink(opts: LinkOpts) {
  const o = await this.ask('links:create', opts);
  return o.result?.url.toUpperCase();  // NO — logic in SDK
}
```
**Fix:** Logic lives in the receiver or the component, not the SDK.

**Method without a receiver**
```typescript
// WRONG — method exists, but no entry in RECEIVERS
async customAction() {
  return this.signal('custom:action', {});  // escape hatch → 404 at runtime
}
```
**Fix:** Add the receiver to `receivers.ts` first, then the method.

**Bare barrel import in a Worker**
```typescript
// WRONG — crashes on Cloudflare Workers
import { RECEIVERS } from '@oneie/sdk';
```
**Fix:** `import { RECEIVERS } from '@oneie/sdk/receivers'`.

## Composability rules

**New domain method composes existing types:**
```typescript
// GOOD — reuses the shipped Outcome + registry inference
async createLink(opts: LinkOpts): Promise<LinkResult | null> {
  const outcome = await this.ask("links:create", opts);
  return outcome.kind === "result" ? outcome.result : null;
}
```

**New domain introduces its own module:**
```typescript
// GOOD — a domain with its own transport (pay, skills, wallet, broadcast)
// lives in src/{domain}.ts, gets a package.json subpath, and is bound onto
// the client in the constructor:
//   this.pay = { accept: (o) => payAccept(o, cfg), … }
```

## See also

- `packages/sdk/CLAUDE.md` — SDK operating manual (verbs table, security boundaries)
- `packages/sdk/src/receivers.ts` — canonical receiver registry
- `text/signals-catalog.md` — the generated namespace map (parity-guarded)
- `text/agent-first-spec-plan.md` — why the registry is the capability contract
- `text/api.md` — API endpoint spec (SDK methods wrap endpoints)
