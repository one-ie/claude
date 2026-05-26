# Legacy Shims — web/src/pages/api/*

Full mapping of legacy `/api/*` endpoints to substrate verbs.
All shims emit `Deprecation: true` + `Sunset: 2026-11-13`.

`web/src/lib/shim.ts` exports `addDeprecationHeaders(response, verb)` and
`shimmed(successorVerb, handler)` — wrap any APIRoute with the shim.

---

## Mapping table

| Legacy endpoint | HTTP | Substrate verb | Status |
|-----------------|------|----------------|--------|
| `/api/agents/publish` | POST | `POST /signal/world:publish-agent` | shimmed |
| `/api/skill/import` | POST | `POST /signal/world:import-skill` | shimmed |
| `/api/agent-events` | POST | `POST /signal/world:event` | shimmed |
| `/api/x402` | POST | `POST /mark/{edge}` w/ weight+currency | shimmed |
| `/api/agents/discover` | GET | `GET /select?type=skill` | shimmed |
| `/api/agents/list` | GET | `GET /api/agents` | shimmed |
| `/api/chat` | POST | direct (chat is not a substrate verb) | keep |
| `/api/health` | GET | direct | keep |
| `/api/billing` | GET/POST | direct (billing is not substrate) | keep |
| `/api/commit` | POST | `POST /signal/world:commit` | shimmed |
| `/api/provision` | POST | `POST /signal/world:provision` | shimmed |
| `/api/auth` | POST | direct (auth is not substrate) | keep |
| `/api/skills` | GET | `GET /things?type=skill` | shimmed |
| `/api/keys` | GET/POST | direct (key management) | keep |
| `/api/branding` | GET/PUT | direct (workspace settings) | keep |
| `/api/settings` | GET/POST | direct | keep |
| `/api/domain` | GET/POST | direct | keep |
| `/api/report` | POST | `POST /signal/world:report` | shimmed |
| `/api/revenue` | GET | `GET /paths?type=revenue` | shimmed |
| `/api/notifications` | GET | `GET /events?receiver=me` | shimmed |
| `/api/eval` | POST | direct (eval is tooling, not substrate) | keep |
| `/api/link` | POST | direct | keep |
| `/api/tts` | POST | direct (speech synthesis) | keep |
| `/api/onboarding` | GET/POST | direct | keep |
| `/api/recover` | POST | direct | keep |
| `/api/agents/sync-from-git` | POST | `POST /signal/world:sync-git` | shimmed |
| `/api/agents/flag` | POST | `POST /signal/world:flag` | shimmed |
| `/api/artifacts/save` | POST | `POST /signal/world:artifact` | shimmed |
| `/api/peer/call` | POST | `POST /ask/{receiver}` | shimmed |
| `/api/peer/result` | POST | direct (result delivery) | keep |
| `/api/payments/txs` | GET | `GET /events?type=payment` | shimmed |
| `/api/payments/wallet` | GET | direct (wallet state) | keep |
| `/api/funnel/{id}/kpis` | GET | `GET /learning?funnel=` | shimmed |
| `/api/funnel/{id}/visitor-state` | GET | `GET /actors/{visitor}` | shimmed |
| `/api/visitor/{hash}` | GET | `GET /actors/{hash}` | shimmed |
| `/api/pricing/simulate` | POST | direct (pricing simulation) | keep |
| `/api/unlocks/grant` | POST | `POST /mark/unlock:{id}` | shimmed |
| `/api/webhook/telegram` | POST | direct (webhook ingress) | keep |
| `/api/webhook/discord` | POST | direct (webhook ingress) | keep |
| `/api/webhooks/deliveries` | GET | `GET /events?type=webhook` | shimmed |

## Shim implementation pattern

```typescript
import { shimmed } from '@/lib/shim'
import type { APIRoute } from 'astro'

// The original handler logic
async function handlePost(ctx: Parameters<APIRoute>[0]): Promise<Response> {
  // ... existing logic ...
  return Response.json({ ok: true })
}

// Export the shimmed version — clients see Deprecation headers
export const POST = shimmed('/signal/world:publish-agent', handlePost)
```

## Sunset timeline

| Date | Action |
|------|--------|
| 2025-11-13 | `Deprecation: true` + `Sunset:` headers added |
| 2026-05-13 | 6-month warning: clients should have migrated |
| 2026-11-13 | **Sunset** — handlers return 410 Gone |
| 2026-11-14 | Shim files deleted; substrate verbs are the only surface |
