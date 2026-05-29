# Products

Every sellable unit in ONE. Products are the atoms — plans and packages compose them into offers.

**Relationship to other docs**
- Implementation status and code locations → `billing-taxonomy.md`
- Credit unit definition → `billing-taxonomy.md` (1 credit = $0.0001 USD)
- Plan templates (agency packaging) → `billing-taxonomy.md#agency-plan-templates--next`

---

## What is a product?

A product is a discrete, billable capability with a defined unit and credit rate. Three billing models:

| Model | What | Examples |
|-------|------|---------|
| **Metered** | Burns credits per unit consumed | inference tokens, agent runs, storage GB |
| **Gated** | On/off per plan; overage not billed | brand removal, custom domain, SSO |
| **Slotted** | Fixed limit per plan; overages blocked or billed | published agents, client workspaces |

Products compose into **plans** (platform-defined tiers) and **packages** (agency-defined bundles for clients).

---

## AI Inference

| Product | Unit | Credits | Billing model |
|---------|------|---------|---------------|
| Text inference — input | per 1K tokens | per-model rate | metered |
| Text inference — output | per 1K tokens | input × output_mult | metered |
| Voice input (speech-to-text) | per minute | 8 | metered |
| Voice output (text-to-speech) | per minute | 12 | metered |
| Premium model surcharge | per run | per-model rate | metered (gate: on/metered/off) |
| Image generation | per image | TBD | metered |
| Extended thinking tokens | per 1K tokens | TBD | metered |
| Embeddings | per 1K tokens | TBD | metered |
| Document parsing / OCR | per page | TBD | metered |
| Video analysis | per minute | TBD | metered |

Agencies reselling inference set a `markup_pct` — clients are billed at `platform_rate × (1 + markup_pct / 100)`.

---

## Agents

| Product | Unit | Credits | Billing model |
|---------|------|---------|---------------|
| Agent run | per run | 10 base | metered |
| Skill call | per invocation | 5 base | metered |
| Tool call | per invocation | cost-based | metered |
| Published agent slots | per agent (over plan limit) | — | slotted (free 5 / starter 20 / pro 100 / agency ∞) |
| Scheduled / cron agent execution | per execution | TBD | metered |
| Autonomous agent duration | per minute | TBD | metered |
| Agent creation | — | — | gated (on/off per plan) |

---

## Skills

| Product | Unit | Credits | Billing model |
|---------|------|---------|---------------|
| Skill call | per invocation | 5 base | metered (shared with agent skill calls) |
| Skill publish slots | per skill (over plan limit) | — | slotted |
| x402 skill payment — platform fee | % of amount | `platform_usd` split | revenue share |
| x402 skill payment — agency cut | % of amount | `agency_usd` split | revenue share |
| x402 skill payment — creator share | % of amount | `creator_usd` split | revenue share |

---

## Storage

| Product | Unit | Credits | Billing model |
|---------|------|---------|---------------|
| File storage | per GB/hour | 1 | metered |
| Export archive | per export | 100 | metered |
| Attachments | — | — | gated |
| Memory / KV snapshots | per GB/month | TBD | metered (not yet wired) |
| Knowledge base (TypeDB) | per GB | TBD | metered (not yet wired) |
| Media storage (R2) | per GB/month | TBD | metered (not yet wired) |
| Backup retention beyond default | per GB/month | TBD | metered (not yet wired) |

---

## Channels & Comms

| Product | Unit | Credits | Billing model |
|---------|------|---------|---------------|
| Public chat message | per message | 1 | metered |
| API request overage | per request | 0.1 | metered |
| Webhooks | — | — | gated |
| Email sends (via Resend) | per 1K | TBD | metered |
| SMS | per message | TBD | metered |
| Telegram / Discord messages | per 1K | TBD | metered |
| Push notifications | per 1K | TBD | metered |

---

## Platform Features

| Product | Unit | Credits | Billing model |
|---------|------|---------|---------------|
| Brand removal | per day | 30 | metered |
| Custom domain | — | — | gated (pro+ only) |
| White label cascade | — | — | gated (agency only) |
| Sub-workspace creation | — | — | gated |
| SSO / SAML | — | — | gated |
| Team creation | — | — | gated |
| Voice input/output features | — | — | gated (burn rate separate) |

---

## Workspaces & Seats

| Product | Unit | Credits | Billing model |
|---------|------|---------|---------------|
| Client workspaces | per workspace | — | slotted (agency: 50, enterprise: 999) |
| Sub-agency workspaces | per workspace | — | slotted (agency plan gate) |
| Staff / team members | per seat/month | TBD | slotted (not yet metered) |
| End users / MAU | per active user | TBD | metered (not yet wired) |
| Guest / viewer seats | per seat | TBD | slotted (not yet wired) |

---

## Payments & Transfers

| Product | Unit | Credits | Billing model |
|---------|------|---------|---------------|
| Credit transfer between workspaces | per transfer | burn: `transfer` | metered |
| Payout to creator | per payout | burn: `payout` | metered |
| Credit top-up | per $ purchase | flat rate | transactional |
| x402 transactions | % of amount | 4-way split | revenue share |

---

## How products compose into plans

Platform-defined tiers bundle products into fixed offers. Each tier sets a monthly credit grant, gate states, and slot limits:

| Plan | Monthly credits | Notes |
|------|----------------|-------|
| `free` | 1,000 | public_chat metered; brand_removal off; premium_models off |
| `starter` | 50,000 | brand_removal on; premium_models metered |
| `pro` | 500,000 | all gated features on |
| `agency` | 5,000,000 | all on + sub_workspace_create + white_label_cascade |
| `enterprise` | custom | full limits (999 clients); custom Stripe |

---

## How agencies package products for clients

Agencies on the `agency` or `enterprise` plan can:

1. **Set markup** — apply `markup_pct` over platform rates; applied automatically in `debitPool`
2. **Set a monthly cap** — hard ceiling on client credit burns per month
3. **Lock brand** — prevent clients from removing the agency brand
4. **Assign a plan** — map a client to a base tier or an agency plan template
5. **Create plan templates** — named configs that inherit a base tier and override specific products/gates (see `billing-taxonomy.md#agency-plan-templates--next`)

### Template composition

```
platform rates
  └── agency defaults (markup, cap, gate overrides)
        └── agency plan template (named bundle: "E-commerce Starter", "Enterprise Voice", …)
              └── client workspace (inherits template; can be further restricted)
                    └── team (inherits client; budget sub-allocation only)
```

A template defines:
- **Base tier** — the floor (free / starter / pro / agency)
- **Credit ceiling** — override the base tier's monthly grant
- **Markup %** — agency margin on this template's clients
- **Monthly cap** — maximum burn per client on this template
- **Gate overrides** — turn specific features on or off relative to the base tier

Templates are stored in `agency_plan_templates` (D1, migration 0071). `client_default_plan` on `owners` accepts a template ID or a base tier name.

---

## Agency-sellable product bundles (examples)

These are illustrative packages agencies might create using plan templates:

| Bundle name | Base tier | Key inclusions | Target client |
|-------------|-----------|----------------|---------------|
| Chat Starter | `starter` | Text inference + public chat + 50K credits/mo | Small business adding AI chat |
| Voice Pro | `pro` | All inference + voice in/out + 500K credits/mo | Call centre / support tool |
| E-commerce Agent | `pro` | Agents + skills + x402 payments + tool calls | Online store with AI checkout |
| White Label Agency | `agency` | All features + brand removal + custom domain + sub-workspaces | Reseller building their own product |
| Developer API | `starter` | API access + embeddings + webhooks | Developer integrating ONE into their app |
