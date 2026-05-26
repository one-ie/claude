---
title: stripe-agents — agents provision infrastructure and pay via Stripe Projects
type: spec
version: 1.0.0
status: PLAN
updated: 2026-05-06
classifier:
  spec_locked: no
  variance_known: yes
  exit_scalar: "agent builds + deploys Worker to new Cloudflare account + buys domain, zero human steps beyond initial budget approval"
  files_known: partial
  mode: full
  lifecycle: construction
companion: agents.md, wallet.md, x402.md, website.md
---

# stripe-agents.md

> **Agents that provision their own infrastructure.** Stripe Projects (open beta, 2026-04-30) gives agents a standard protocol to discover cloud services, create accounts on behalf of users, and spend against a pre-approved budget — no human copy-paste of API tokens, no credit card handed to the agent. This doc is the plan to wire that protocol into the one.ie agent stack.

**Mental model:** an agent is given a goal ("ship this to production"). It queries the service catalog, provisions a Cloudflare account (or links an existing one), registers a domain, deploys the Worker — all in one uninterrupted loop. The human approved a $100/month budget once. The chain does the rest.

---

## What Stripe Projects adds (the three components)

### 1. Discovery — `stripe projects catalog`

A REST endpoint returns a JSON catalog of available provider services. The agent queries it, reads what's on offer, and picks what it needs — no prior knowledge required from the user.

```
GET /v1/projects/catalog
→ [{ provider: "cloudflare", service: "registrar:domain", ... }, ...]
```

### 2. Authorization — identity attestation + instant account creation

The orchestrating platform (Stripe) attests to the user's identity via OIDC. The provider (Cloudflare) either:
- Creates a new account for that identity (new user) — no signup page
- Runs a standard OAuth flow to link an existing account

Either way, a scoped API token is returned to the Stripe Projects CLI (and thus to the agent) — never the raw credential, never exposed to the LLM.

### 3. Payment — tokenized budget, not raw card

When an agent provisions a paid service, Stripe includes a payment token in the request. Raw card details never leave Stripe. A default cap of **$100 USD/month** per provider prevents runaway spend. Budget alerts can be configured on the Cloudflare side.

---

## Why this matters for one.ie agents

The one.ie agent architecture (→ `agents.md`) defines four patterns: co-sign, scoped, capability, peer. Infrastructure provisioning fits **pattern B — scoped autonomy**:

- The user approves a budget once (Move entry function or Stripe Projects budget cap)
- The agent operates freely within that scope
- Consensus (or the payment cap) is the authority check — not a human in the loop per action

Stripe Projects removes the last manual friction: obtaining cloud credentials. Once wired, an agent can go from goal to running production app without touching a dashboard.

**Relationship to x402:** x402 (→ `x402.md`) handles agent-to-agent micropayments (SUI/ETH/etc.). Stripe Projects handles agent-to-platform provisioning payments (fiat card on file). They are complementary: x402 for runtime API calls between agents; Stripe Projects for one-time or subscription infrastructure provisioning.

---

## What needs to be built

### Wave 0 — gap audit (not yet started)

| Gap | Where | Notes |
| --- | --- | --- |
| Stripe Projects CLI integration | new `apps/stripe-agent/` or `one-ie/one/claw/` | `stripe projects init` + `stripe projects add cloudflare/*` |
| Orchestrator API | `one.ie/src/pages/api/provision.ts` | Receives Stripe identity token, calls Cloudflare Account Provisioning API, returns scoped CF token |
| Catalog endpoint | `one.ie/src/pages/api/catalog.ts` | Returns available services in Stripe Projects catalog format |
| Budget gate | `one.ie/src/pages/api/budget.ts` | Checks/enforces per-provider monthly cap before provisioning |
| Agent skill | `one-ie/one/agents/provision-infra.md` | Markdown agent definition: goal → catalog query → provision → deploy loop |
| Claw tool | `one-ie/one/claw/src/tools/provision.ts` | `provision_cloudflare_account`, `register_domain`, `deploy_worker` substrate tools |
| Auth flow | `one.ie/src/pages/auth/stripe-link.astro` | OAuth callback page for existing CF account linking |

### Wave 1 — Stripe Projects orchestrator

One.ie acts as the orchestrator (same role Stripe plays in the demo). The user is signed in via passkey; one.ie attests their identity to Cloudflare.

**New files:**

```
one.ie/src/pages/api/provision/
  account.ts      POST — create or link CF account for authenticated user
  catalog.ts      GET  — proxy CF service catalog
  domain.ts       POST — register domain via CF Registrar (charges Stripe card on file)
  token.ts        POST — issue scoped CF API token for agent use
```

**Auth flow:** passkey-authed session → `one.ie/api/provision/account` → Cloudflare Account Provisioning API → return `{ cf_account_id, cf_token }` stored in D1 against user.

### Wave 2 — Agent skill definition

```markdown
<!-- one-ie/one/agents/provision-infra.md -->
# provision-infra

Goal: given a CF Workers project, provision all required infrastructure and deploy.

Steps:
1. Query catalog → select needed services
2. Call provision/account → get cf_account_id + cf_token
3. Call provision/domain → register domain
4. Use CF token + Wrangler API to deploy Worker
5. Emit pheromone: mark(provision:deploy, depth)
```

The claw `ToolLoopAgent` runs this with approval gating on spend actions (→ `claw/README.md`).

### Wave 3 — Claw substrate tools

Three new approval-gated tools in `one-ie/one/claw/src/tools/`:

```ts
// provision.ts
export const provisionCloudflareAccount = tool({
  name: 'provision_cloudflare_account',
  requiresApproval: false,     // identity only, no spend
  execute: (_, ctx) => fetch('/api/provision/account', { headers: ctx.auth })
})

export const registerDomain = tool({
  name: 'register_domain',
  requiresApproval: true,      // spend action — human approves first time
  execute: ({ domain }, ctx) => fetch('/api/provision/domain', { body: { domain }, headers: ctx.auth })
})

export const deployWorker = tool({
  name: 'deploy_worker',
  requiresApproval: false,     // uses already-provisioned token
  execute: ({ script, name }, ctx) => cfWorkersDeploy(script, name, ctx.cfToken)
})
```

### Wave 4 — Budget gate + pheromone

Spend actions go through `api/provision/budget.ts`:
- Check D1 `monthly_spend` table for user + provider + month
- Reject if > cap (default $100)
- Record spend on success
- Emit `mark(provision:domain, 1)` or `warn(provision:domain, 1)` to substrate

---

## The protocol (wire-level)

### Account provisioning request (one.ie → Cloudflare)

```http
POST https://api.cloudflare.com/client/v4/accounts/provision
Authorization: Bearer CF_PROVISIONER_TOKEN
Content-Type: application/json

{
  "identity": {
    "provider": "one.ie",
    "oidc_token": "<signed JWT — user's passkey identity>",
    "email": "user@example.com"
  },
  "payment": {
    "stripe_payment_token": "<tokenized card — no raw PAN>"
  }
}
```

Response: `{ account_id, api_token, expires_at }`

### Catalog format (one.ie catalog endpoint)

```json
[
  {
    "provider": "cloudflare",
    "service": "workers:deploy",
    "label": "Deploy a Cloudflare Worker",
    "price": null,
    "requires_account": true
  },
  {
    "provider": "cloudflare",
    "service": "registrar:domain",
    "label": "Register a domain",
    "price": "varies",
    "requires_payment": true,
    "requires_account": true
  }
]
```

---

## Security model

| Threat | Mitigation |
| --- | --- |
| Agent with runaway spend | $100/month cap enforced in `budget.ts` + Cloudflare budget alerts |
| Raw CF API token in LLM context | Token stored in D1/KV, injected at tool execution — never in prompt |
| OIDC spoofing | CF verifies JWT signature against one.ie JWKS endpoint |
| Domain squatting by agent | `register_domain` is approval-gated (first time); subsequent same-TLD purchases auto-approved within budget |
| Leaked Stripe payment token | Token is single-use, provider-scoped; Stripe invalidates after provisioning |

**What this does NOT defend:** an authorized agent hitting its $100 cap buying junk domains. Budget alerts + monthly review are the mitigation — agent authority is scoped, not zero.

---

## Build classifier check

| Prior | Status | Note |
| --- | --- | --- |
| Spec locked | **partial** | Stripe Projects protocol spec not yet published; wire format above is from the blog post + Stripe/CF APIs |
| Variance known | yes | One shape: orchestrator API + claw tools + agent skill |
| Exit scalar | yes | Agent deploys Worker + domain, zero human steps beyond budget approval |
| Files known | **partial** | New files identified; CF Provisioning API endpoints need confirmation |

**3 yes → mode: mixed** — full plan with lean cycles where certain. W1-W4 wave structure applies; catalog/budget endpoints are lean; provisioning API is full (needs CF endpoint confirmation first).

---

## Dependencies

| Dependency | Status | Blocker? |
| --- | --- | --- |
| Stripe Projects open beta | Live (2026-04-30) | No — CLI available now |
| Cloudflare Account Provisioning API | Gated — email agenticpartnerships@cloudflare.com | **Yes for Wave 1** |
| one.ie passkey identity as OIDC issuer | Not yet built | Yes — need JWKS endpoint |
| Stripe card on file for one.ie users | Partial — x402 has Stripe wiring | No for MVP (can use Stripe Projects CLI auth) |

**Critical path:** CF Provisioning API access → then OIDC issuer → then Wave 1.

**MVP path (no CF API access yet):** implement the Stripe Projects CLI flow directly — user runs `stripe projects init` once, agents use the resulting stored credentials. Loses the zero-setup UX but ships the agent skill immediately.

---

## Lean plan — MVP (Stripe CLI path, no CF Provisioning API needed)

**Goal:** agent deploys to Cloudflare via stored Stripe Projects credentials  
**Speed:** 1 wave, 4 tasks  
**Exit:** `bun run test:provision` passes; agent deploys a hello-world Worker

### Tasks

1. `one-ie/one/agents/provision-infra.md` — agent skill definition (catalog → provision → deploy loop)
2. `one-ie/one/claw/src/tools/provision.ts` — 3 substrate tools: `provision_cloudflare_account`, `register_domain`, `deploy_worker`
3. `one-ie/one/web/src/pages/api/provision/token.ts` — reads stored Stripe Projects CF credentials from D1, returns scoped token
4. `one-ie/one/web/src/pages/api/provision/catalog.ts` — static catalog JSON (no CF API needed for MVP)

**Verify:** `bun run verify` + agent integration test (mock Stripe Projects CLI)  
**Close:** tag `provision:mvp:shipped`, emit pheromone

---

## Full plan — production (CF Provisioning API path)

W1 recon: confirm CF Provisioning API endpoints + Stripe Projects webhook shape  
W2 decide: finalize `api/provision/` file list, OIDC issuer shape, D1 schema  
W3 edit: implement all 4 `api/provision/` routes + claw tools + agent skill  
W4 verify: `bun run verify` + integration test (real CF sandbox account) + threat model row audit  

**Rubric targets:** security ≥ 0.90 (no raw tokens in prompts), stability ≥ 0.85, simplicity ≥ 0.85, speed ≥ 0.80

---

## See also

- `agents.md` — four patterns; scoped autonomy (pattern B) is the shape here
- `wallet.md` — agent wallet lifecycle; provisioned CF account is an agent-controlled resource
- `x402.md` — runtime micropayments (complementary, not overlapping)
- `website.md` — `/sell` surface is where provisioning UX lives for human-facing flows
- Stripe Projects docs: `stripe.com/docs/projects` (open beta)
- CF Agentic Partnerships: `agenticpartnerships@cloudflare.com`
