---
paths:
  - "one.ie/web/src/pages/api/**/*.ts"
  - "one.ie/web/src/hooks/**/*.ts"
---

# API Rules

Apply to `src/pages/api/**/*.ts`, `src/hooks/**/*.ts`

## The contract: no new endpoints for product features

Four universal endpoints cover all product work. Before adding a new file to `src/pages/api/`, name which of these four cannot handle it and why.

| Endpoint | Use for |
|---|---|
| `POST /api/signal/:receiver` | Fire-and-forget — trigger a workflow, record an event |
| `POST /api/ask/:receiver` | Synchronous — get a result back (30s max) |
| `POST /api/mark/:edge` / `/api/warn/:edge` | Pheromone on any path (`source>target` URL-encoded) |
| `GET/PUT /api/settings?scope=X` | Any new setting — add a new `scope` value, not a new file |

## When a new endpoint IS justified

| Pattern | Why |
|---|---|
| Inbound webhook from external service | External system calls a fixed URL — cannot invert |
| OAuth / redirect flow | Browser redirect URI must be a stable route |
| Multi-step auth ceremony | Stateful challenge exchange (WebAuthn) |
| Binary or streaming response | SSE stream, image gen, file upload, CSV export |
| Resource-bound read/write (`/api/<resource>/:id`) | RESTful read/append against a specific persisted entity — e.g. `GET/POST /api/threads/:tid` for chat-thread history and owner inbox replies. The id is a stable handle (not a one-shot signal), and the same path participates in CDN cache + access control |
| `/api/export/<dim>` family | Bulk read of a substrate dimension shaped for the inbox/CRM — already established (`actors`, `groups`, `skills`, `highways`, `conversations`). New dimensions extend the family rather than create ad-hoc routes |

If the use case does not match one of these four patterns, route through `signal`, `ask`, `mark/warn`, or `settings?scope=`.

## Edge format for mark/warn

```ts
const edge = encodeURIComponent(`${source}>${target}`)
fetch(`/api/mark/${edge}`, { method: 'POST', body: JSON.stringify({ strength }) })
```

The `>` separator works as a fallback to `→`. Always pass `{ strength }` in the body.

## State from highways, not localStorage

Active state (saved, archived, completed) belongs on the pheromone path, not in `localStorage`. Poll `/api/export/highways?from=source&limit=200` and classify by strength/resistance thresholds. This keeps state honest across devices.

## Authorize off the context, never the body

Scope every read and write to `ctx.ownerSlug`. A `slug`, `actorId`, `gid`, or
`workspace` arriving in the request body or query string is **caller-supplied
input, not identity** — trusting one is an IDOR, and this family has had ~80 of
them fixed. A `?slug=` route must call `authorizeWorkspace` before it touches
data. Ownership questions resolve by the authority walk (`schema/roles.tql`),
not by comparing a body field to anything.

## No stubs

Do not create a no-op endpoint (one that always returns `[]` or `{ok:true}`) as a placeholder. If the backend isn't ready, the caller handles the empty response from `signal`/`ask`.
