---
name: mcp
description: Add or change a tool in @oneie/mcp — the MCP server exposing ONE to Claude Desktop, Cursor, and any MCP client. Use when adding an MCP tool, editing anything under packages/mcp/src/tools/, writing a tool inputSchema, fixing MCP_TOOLS manifest drift when `bun run check:tools` fails, or deciding whether a new capability needs a tool at all (usually it does not — signal/ask already reach every receiver). Triggers — "add an MCP tool", "new tool for the MCP server", "check:tools is failing", "MCP_TOOLS drift", "expose X to Claude Desktop", "wire the oneie MCP server".
---

# MCP tools — Model Context Protocol for agents

MCP tools give agents programmatic access to ONE capabilities. Each tool is a
plain object registered on a router; the router is served over stdio.

## Structure

```
packages/mcp/
├── src/
│   ├── index.ts    # createOneRouter() + MCP_TOOLS + bin
│   ├── serve.ts    # McpTool, McpRouter, apiCall(), serve()
│   ├── env.ts      # readEnv() → { baseUrl, apiKey }
│   ├── telemetry.ts
│   └── tools/      # one file per group: <group>Tools()
│       ├── substrate.ts     # 6 verbs + dims (locked)
│       ├── lifecycle.ts     # agents, skills, pay
│       ├── observability.ts # stats, health, export
│       ├── discovery · social · video · broadcast
│       ├── messaging · seo · views · workflow · tasks
│       └── fn.ts            # generated per allowlisted fn
```

There is no `src/schema.ts` and no per-domain subdirectory — a tool group is one
flat file exporting one `<group>Tools(): McpTool[]` function.

## Pattern: Adding an MCP tool

**First ask whether you need one.** `signal` and `ask` address any receiver by
name — the registry declares 273 of them today. (The registry is the capability
*catalog*; a receiver is only reachable once a handler is bound in
`world-receivers.ts` or a channels tool module. A declared-but-unbound name
type-checks and 404s.) A new product action needs a receiver, not a tool.
The documented exceptions (`views.ts`, `workflow.ts`, `tasks.ts`) exist because
those are first-class product objects other clients address by name — and even
they add no new receiver, they route through the `/api/ask` door.

### 1. Define the input schema (raw JSON Schema, not Zod)

`McpTool.inputSchema` is `Record<string, unknown>` and is handed to the MCP
client verbatim. Zod is an SDK dependency, not an MCP one.

```typescript
// inside packages/mcp/src/tools/broadcast.ts
const inputSchema = {
  type: "object",
  properties: {
    broadcastId: { type: "string" },
  },
  required: ["broadcastId"],
};
```

### 2. Implement the tool

```typescript
// packages/mcp/src/tools/broadcast.ts
import { apiCall, type McpTool } from "../serve.js";

function ask(env: { baseUrl: string; apiKey?: string }, receiver: string, data: unknown) {
  return apiCall(env.baseUrl, env.apiKey, `/api/ask/${encodeURIComponent(receiver)}`, {
    method: "POST",
    body: JSON.stringify({ data }),
  });
}

export function broadcastTools(): McpTool[] {
  return [
    {
      name: "broadcast_send",
      description: "Send a broadcast now (inline drain, suppression-checked).",
      inputSchema: {
        type: "object",
        properties: { broadcastId: { type: "string" } },
        required: ["broadcastId"],
      },
      handler: async (args, env) => ask(env, "broadcast:send", args),
    },
  ];
}
```

**Rules:**
- The tool shape is exactly `{ name, description, inputSchema, handler }` —
  the field is `handler`, not `execute`
- `handler(args, env)` receives `Record<string, unknown>` and the `readEnv()`
  result; it returns `Promise<unknown>` — **not** a string. Return the parsed
  JSON body; the transport serialises it
- Tools call `apiCall(env.baseUrl, env.apiKey, path, init)` from `serve.ts`.
  They do **not** construct a `SubstrateClient` — the SDK import in this package
  is for the `RECIPES` contract catalog, not for transport
- Every receiver a tool wraps must be a real key in `@oneie/sdk/receivers`
- `apiCall` throws with the response body on a non-2xx, so the API's structured
  error (`{error, field, expected, got, hint}`) reaches the agent. Let it throw

### 3. Register the tool — in two places

```typescript
// packages/mcp/src/index.ts
export function createOneRouter() {
  const router = createRouter();
  for (const tool of [...substrateTools(), ...broadcastTools(), /* … */]) {
    router.register(tool);
  }
  return router;
}

export const MCP_TOOLS = {
  broadcast: ["broadcast_create", "broadcast_list", "broadcast_get",
              "broadcast_send", /* … */] as const,
};
```

`MCP_TOOLS` is hand-maintained and drifts. `toolManifestDrift()` diffs the
manifest against the live router; `fn_*` is excluded by design because those are
generated at runtime from `FN_MAP`.

### 4. Check and test

```bash
cd packages/mcp && bun run check:tools
# builds, then reports "MCP_TOOLS matches the router" or exits 1 with the diff
```

There is no vitest suite in `packages/mcp` — `check:tools` and `bun run
typecheck` are the gates. Exercise a tool end-to-end through a live client:

```bash
claude mcp add oneie -e ONEIE_API_KEY=one-<key> -- npx -y @oneie/mcp
```

## Naming conventions

**Tool names:** snake_case, `group_verb`
- Correct: `broadcast_send`, `tasks_list`, `chat_send`, `workflow_run`
- Wrong: `send-broadcast`, `Memory`, `CREATE_TASK` (nothing shipped uses kebab or caps)
- The universal verbs are the bare exception — `signal`, `ask`, `mark`, `warn`,
  `fade`, `follow` keep the locked verb name with no prefix

**Tool descriptions:** one sentence, agent-perspective, and say what comes back
- Correct: "Send a broadcast now (inline drain, suppression-checked)."
- Correct: "Get one broadcast by id. Returns { broadcast }."
- Wrong: "Calls the broadcast API" (implementation detail, no return shape)

**Input fields:** match the receiver's zod request field-for-field
- The handler forwards `args` straight through, so a renamed field is a silent
  400. `broadcast:send` takes `broadcastId`; the tool takes `broadcastId`

## Tool categories

| Category | Purpose | Example |
|----------|---------|---------|
| **Universal** | Reach any receiver by name | `signal`, `ask` |
| **Read** | Fetch data without side effects | `broadcast_list`, `tasks_list`, `stats` |
| **Create** | Add new entity | `broadcast_create`, `tasks_create`, `create_view` |
| **Update** | Modify existing entity | `newsletter_update`, `tasks_status` |
| **Delete** | Remove entity (rare) | `delete_room`, `unpublish_agent` |
| **Execute** | Run an action with side effects | `broadcast_send`, `chat_send`, `workflow_run` |

## Anti-patterns

**A new tool for a new product action**
```typescript
// WRONG — a receiver already reaches this
{ name: "commend_agent", handler: (a, e) => ask(e, "agents:commend", a) }
```
**Fix:** Let the agent call `signal` with `receiver: "agents:commend"`. Only add
a tool for a first-class object clients address by name, and document why.

**Zod in inputSchema**
```typescript
// WRONG — inputSchema is raw JSON Schema
inputSchema: z.object({ broadcastId: z.string() })
```
**Fix:** Write the JSON Schema object literal, or derive it from the receiver
with `ask("meta:schema", { receiver })`.

**Returning a hand-serialised string**
```typescript
// WRONG
handler: async (args, env) => JSON.stringify(await ask(env, "broadcast:get", args))
```
**Fix:** Return the value. `handler` is `Promise<unknown>`; double-encoding
gives the agent a string it has to re-parse.

**Tool builds its own fetch**
```typescript
// WRONG
const res = await fetch(`${base}/api/ask/broadcast:send`, { … });
return res.json();
```
**Fix:** Use `apiCall()` — it sets Accept/Content-Type/Authorization, handles
204, and surfaces the structured error body on failure.

**Registered in the router but not in MCP_TOOLS**
```typescript
// WRONG — check:tools exits 1 with "missing: [ 'broadcast_send' ]"
router.register(broadcastSendTool);  // and nothing added to the manifest
```
**Fix:** Add the name to its `MCP_TOOLS` group in the same edit.

**Tool that modifies global state**
```typescript
// WRONG
let cached: unknown;
handler: async (args, env) => (cached ??= await ask(env, "broadcast:list", args))
```
**Fix:** No caching in tools. Each invocation is independent.

## Composability rules

**New tool wraps an existing receiver:**
```typescript
// GOOD — the receiver owns validation, authority, and persistence
{
  name: "segment_preview",
  description:
    "Preview an audience segment definition — live count + up to 10 sample " +
    "addresses (read-only). Pass a SegmentDef ({all,any?}), not an id.",
  inputSchema: {
    type: "object",
    properties: {
      definition: { type: "object", description: "SegmentDef {all: SegmentRule[], any?: SegmentRule[]}" },
      channel: { type: "string", enum: ["email", "sms", "whatsapp"] },
    },
    required: ["definition"],
  },
  handler: async (args, env) => ask(env, "segment:preview", args),
}
```

**New tool is generated from a catalog:**
```typescript
// GOOD — fn.ts builds one tool per FN_ALLOWLIST entry (20 today) from
// @oneie/sdk/generated/fn-map, all routing through ask("fn:run"). Extending the
// surface means allowlisting the fun in @oneie/sdk/fn-allowlist — one edit
// reaches web, MCP, CLI, and channels. Never hand-write an fn_* tool.
```

## Error handling

```typescript
handler: async (args, env) => {
  const res = await ask(env, "broadcast:get", args) as { broadcast?: unknown };
  if (!res.broadcast) {
    return { ok: false, error: "not_found", hint: "Call broadcast_list for valid ids." };
  }
  return res;
}
```

**Rules:**
- Let `apiCall` throw on a non-2xx — its message already carries the API's
  structured detail, which is what an agent self-corrects from
- Return an error *shape* (`{ ok: false, error, hint }`) for domain-empty cases
  the API considers a legitimate 200
- Never expose the API key, raw TypeQL, or a stack trace in a returned value
- Don't validate what the receiver already validates — the zod contract runs
  server-side before dispatch

## See also

- `packages/mcp/CLAUDE.md` — the tool-file map, wiring, and the base-URL trap
- `packages/mcp/src/serve.ts` — `McpTool`, `McpRouter`, `apiCall`
- `packages/sdk/src/receivers.ts` — receiver registry (every tool wraps a receiver)
- `text/signals-catalog.md` — the generated namespace map
- `@modelcontextprotocol/sdk` — MCP protocol docs
