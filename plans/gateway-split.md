# gateway-split — three domains, one job each

**Decision:** `one.ie` currently does everything. This spec assigns one job to each domain and eliminates the overlap.

---

## The three-domain contract (locked after this ships)

| Domain | Job | Worker name |
|--------|-----|-------------|
| `api.one.ie` | Substrate — all 14 operations, auth, rate-limit, versioning | `one-gateway` |
| `pay.one.ie` | Payments — x402, intents, wallets, webhooks, accept-links | `one-core-worker` |
| `one.ie` | Web app — UI, auth ceremonies, agents, skills, billing dashboard, chat | `one-prod` |

**Rule:** after this ships, `one.ie/api/*` has zero substrate routes accessible from the public internet, and zero Stripe payment routes. Every public-facing substrate call goes through `api.one.ie`. Violations are `CRITICAL` in every future W4.

---

## Why CF Service Bindings, not HTTP proxy

The first draft proposed HTTP proxying (Option A): `api.one.ie` → `fetch("https://one.ie/api/...")`. That adds a full network round-trip (~10–20ms) per substrate call, requires a shared secret that can leak, and leaves `one.ie` substrate routes reachable from the internet if the secret is guessed.

**CF Service Bindings** eliminate all three problems:

```toml
# api/wrangler.toml
[[services]]
binding = "UPSTREAM"
service  = "one-prod"   # one.ie's worker name
```

`env.UPSTREAM.fetch(request)` is an in-process call — no network, no latency. This is the right first implementation, not a future upgrade.

Both workers are already in the same Cloudflare account. Service Bindings are available today.

> **As-built correction (2026-05-29).** A Service Binding does **not** make `one-prod`'s routes unreachable — `one-prod` still serves the `one.ie` custom domain, and its own frontend calls those substrate routes same-origin (57 call sites). So the lockdown is a separate **app-layer guard** (`one.ie/web/src/lib/gateway-guard.ts`), gated by the `GATEWAY_SERVICE_SECRET` secret set on both workers. Once armed it allows a request that has the matching `X-Gateway-Key` (injected by the binding) **or** an `Origin`/`Referer` of `*.one.ie` **or** any `Authorization` header (the route's own auth still validates it); it 403s only anonymous foreign-origin hits. `Origin`/`Referer` are forgeable, so this is a **deterrent layered on the existing per-route auth** (`SERVER_SECRET`, role gates), not a hard wall. A true wall needs the full client reroute (see "Deferred" below). Rollback is one command: `wrangler secret delete GATEWAY_SERVICE_SECRET --name one-prod`.

---

## Canonical path table (frozen — never rewrite without updating this table)

The exact upstream path for each substrate op on `one-prod`:

| api.one.ie path | one-prod internal path | Method |
|-----------------|----------------------|--------|
| `/signal/:receiver` | `/api/signal/:receiver` | POST |
| `/ask/:receiver` | `/api/ask/:receiver` | POST |
| `/mark/:edge` | `/api/mark/:edge` | POST |
| `/warn/:edge` | `/api/warn/:edge` | POST |
| `/fade` | `/api/fade` | POST |
| `/sub` | `/api/sub` | POST |
| `/follow` | `/api/follow` | GET |
| `/select` | `/api/select` | GET |
| `/groups` | `/api/export/groups` | GET |
| `/actors` | `/api/export/actors` | GET |
| `/things` | `/api/things` | GET |
| `/paths` | `/api/export/paths` | GET |
| `/events` | `/api/events` | GET |
| `/learning` | `/api/learning` | GET |

Note the inconsistency in `one-prod` paths (some under `/export/`, some not) — this table is ground truth. The binding layer maps them; `one-prod` paths do not change.

---

## SDK is currently broken for signal/ask

`@oneie/sdk` defaults to `api.one.ie` but that host has no substrate routes today — `client.signal()` returns 404 in production. C1 (adding routes to the gateway) is an urgent bug fix, not just architectural cleanup. This is why the guard (C2) deploys first: it closes `one.ie/api/signal` to direct public access, then C1 opens the proper gateway entry point.

---

## Batch order — guard first, gateway second

The original spec had this backwards. Opening the gateway before the guard creates a window where both `api.one.ie` AND `one.ie/api/signal` are publicly accessible simultaneously. Correct order:

```
Batch 1: C2 (guard) + C4 (CLI URL) — defensive: close direct one.ie substrate access
Batch 2: C1 (service binding) — open api.one.ie substrate routes
Batch 3: C3a (pay routes except webhook) — move payment infrastructure
Batch 4: C3b (webhook drain) — dual-register, drain traffic, then delete
```

C2 guard on `one.ie/api/signal` with no `GATEWAY_SERVICE_SECRET` set → guard is a no-op (`if (!secret) return true`). So deploying the guard file first is safe — it does nothing until C1 sets the secret. After C1, the secret is set and the guard activates.

---

## Gateway-edge concerns (api.one.ie only)

These run at the gateway before forwarding. `one-prod` never sees them directly.

- **Auth** — *as-built (2026-05-29): NOT implemented at the gateway.* The gateway is transport-only: it forwards the caller's `Authorization` intact and lets `one-prod` own auth (`SERVER_SECRET`, role gates). It was deliberately left ungated so the unauthenticated public verbs (`select`/`follow`/`sub`) keep working through `api.one.ie`. The *planned* design below is deferred. *(planned)* `Authorization: Bearer <api-key>` validated against `world_keys` D1 / `GATEWAY_API_KEY`, invalid → `401` before forwarding.
- **Rate limiting** — *deferred (not implemented).* CF rate-limit binding: 600 req/min per key, burst 1200/min. Exceeded → `429` before forwarding.
- **CORS** — `one.ie`, `pay.one.ie`, `localhost` allowed; third-party origins allowed with valid key.
- **Versioning** — `Accept: application/vnd.one.v1+json` passed through; future `v2` forks here without touching `one-prod`.

---

## Payment route migration — Stripe webhook requires dual-registration

Moving `POST /api/pay/webhook` from `one.ie` to `pay.one.ie` is the riskiest step. Stripe sends webhooks to a fixed URL registered in the dashboard. The migration requires:

1. **C3a** — Add all payment routes to `pay.one.ie` *except* the webhook. Keep `one.ie/api/pay/webhook` alive.
2. **C3b** — Register `pay.one.ie/webhook` as a second endpoint in Stripe dashboard. Both URLs receive all events. Add deduplication on `stripe-signature` + event id in the handler.
3. **Drain period** — Monitor Stripe dashboard for zero delivery attempts to `one.ie/api/pay/webhook` (24–48h).
4. **Delete** — Remove `one.ie/api/pay/webhook` and the Stripe registration.

`x402.ts` on `one.ie` verifies Stripe x402 receipts. `apps/pay/backend/src/x402.ts` handles crypto x402. These are different handlers — W1 must diff them before merging.

---

## Stripe routes need D1 binding on pay worker

`one.ie/api/pay/create-intent` and `webhook` use `creditPool`, `toCredits`, `transition` from `one.ie`'s billing lib, which reads `DB` (D1 `one-owners`). `apps/pay/backend/wrangler.toml` must bind the same D1 database before these routes move there.

---

## Billing component URL updates

Four `one.ie` components currently fetch payment routes directly. After C3a these must be updated:

| Component | Fetch URL to update |
|-----------|-------------------|
| `components/payments/PaymentsView.tsx` | `/api/pay/create-intent` → `https://pay.one.ie/create-intent` |
| `components/pay/PayPanel.tsx` | `/api/pay/create-intent` → `https://pay.one.ie/create-intent` |
| `components/billing/TopUpModal.tsx` | `/api/pay/create-intent` → `https://pay.one.ie/create-intent` |
| `lib/x402.ts` | `/api/x402` → `https://pay.one.ie/x402` |

---

## Pre-mortems

| Risk | Mitigation |
|------|-----------|
| Service Binding cold-start cascades | CF SBs share isolate warmth — no additional cold start |
| Stripe webhooks drop during migration | Dual-registration + dedup in C3b; drain period before delete |
| `GATEWAY_SERVICE_SECRET` guard breaks dev | Guard no-ops when secret is unset — dev is always open |
| D1 `one-owners` not bound to pay worker | Add binding in `apps/pay/backend/wrangler.toml` before C3a |
| Path table drift (one-prod paths change) | Path table in this spec is the lock; W4 grep validates all 14 paths |
| SDK 404s in prod until C1 ships | Known — C1 is urgent; track as P0 until batch 2 deploys |

---

## Decisions locked

1. CF Service Binding, not HTTP proxy — no latency. (Correction: the binding alone does NOT make `one-prod` unreachable — that's done by the app-layer `gateway-guard` + `GATEWAY_SERVICE_SECRET`, an origin-allow *deterrent* over the existing per-route auth. See the as-built note under "Why Service Bindings".)
2. Guard deploys before gateway opens — batch order is `[C2+C4] → [C1] → [C3a] → [C3b]`.
3. Stripe webhook requires dual-registration drain — never delete old URL before Stripe confirms zero traffic.
4. `mark(weight+currency)` is substrate not payment — stays on `api.one.ie`.
5. SDK/MCP need zero code changes — they already default to `api.one.ie`.
6. CLI default URL: `one.ie` → `api.one.ie`, bump 0.2.0 → 0.2.1.
7. x402 handlers are different between `one.ie` and `pay.one.ie` — W1 must diff before merge decision.

---

## See also

- `plans/agent-api.md` — the 14 operations
- `api/src/index.ts` — current gateway (one-gateway worker)
- `apps/pay/backend/src/index.ts` — pay worker (one-core-worker)
- `one.ie/web/src/pages/api/` — current route map
