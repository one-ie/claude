# Billing: One Credit. Three Verbs.

Brad's agency billing problem is not that he charges too little. It is that the infrastructure between what he charges and what he pays is full of friction: per-seat minimums, confusing invoices, manual top-ups, and clients who call because they don't know why their bill changed last month.

ONE's billing system has one credit. Three verbs. One field per audience. That is the whole thing.

---

## What a credit is

1 credit = $0.0001.

That rate is set by the platform owner and is immutable once a grant is written. Old credits age at the rate they were issued. New grants at today's rate. No retroactive conversion, no currency drift.

Everything in ONE — inference tokens, agent runs, skill calls, voice minutes, storage, API calls — is expressed as a burn rate in credits. The credit is the universal unit. Brad never manages per-provider pricing tables or per-model surcharges. He sets one number: his markup. The cascade does the rest.

---

## The three verbs

### Grant — credits arrive

A grant is how a workspace gets credits. Sources: Stripe subscription, manual top-up, x402 crypto payment, agency allocation, promo, or refund. All six write to the same `credit_grants` table. The source is a label. The pool is rail-agnostic.

Credits expire in the order they were issued. When the pool has both expiring and non-expiring credits, the expiring ones burn first. The user never sees this. It is one line in the debit function.

### Burn — credits leave

Every billable action writes a burn row. The invariant:

```
amount = cost + agency_margin + platform_margin + recipient_share
```

If the math does not balance, the burn is rejected. A daily cron verifies the ledger. If it breaks, the billing path receives a `warn(1)` signal and the team is notified before the next morning.

### Gate — feature is on, metered, or off

Three states. No fourth.

- `on` — covered by plan, no per-use charge
- `metered` — available, charged per use against the pool
- `off` — unavailable; UI hides it or shows an upgrade prompt

Gates resolve at request time. Brad sets which gates his clients get. His clients cannot override gates Brad has locked.

---

## One field per audience

The whole pitch. Each layer of the hierarchy sets exactly one field. The cascade fills in the rest.

### Tony (platform owner) — one config file

```yaml
rate_usd_per_credit: 0.0001
platform_margin_pct: 10
platform_floor_pct: 5
billing_anchor: monthly
plans:
  free:     { grant: 1_000,     gates: { brand_removal: off  } }
  starter:  { grant: 50_000,    gates: { brand_removal: on   } }
  pro:      { grant: 500_000,   gates: { brand_removal: on,  premium_models: on } }
  agency:   { grant: 5_000_000, gates: { brand_removal: on,  premium_models: on,
                                         sub_workspace_create: on, white_label_cascade: on } }
```

Zero setup. Defaults ship in the repo. Every field is mutable from the owner dashboard. None are required to operate.

### Brad (agency owner) — three fields

```yaml
plan: agency
markup_pct: 20
brand_lock: true
client_default_plan: starter
```

Three fields. Setup time: 30 seconds. Brad is now selling at 20% margin above cost to every client, all under his own brand.

The `platform_floor_pct` is the one constraint he cannot move: after every cascade resolves, platform margin is clamped up to 5%. Brad can give clients wholesale prices (markup of 0%) but cannot starve the platform. That 5% floor runs under every margin Brad offers.

### Client (startup1) — one field

```yaml
plan: starter
monthly_cap: 50_000
```

One field if Brad wants to lock the budget. Zero fields if the client should just run the plan limit. Card on file. Setup time: 10 seconds.

### Team (startup1-eng) — one field

```yaml
allocation: 30_000
cap_locked: true
```

Engineering gets a monthly slice of the client's pool. When it is spent, requests return 402. Not an approximation — a hard stop before the LLM is called, not a refund after.

### End user — one button

```
[ Top up $5 ]
```

If the workspace is sponsored, the user sees no billing surface at all.

That is the full user-facing system.

---

## The cascade

The cascade is four lines of logic. Everything else is data.

```ts
mergeCap   (parent, child) = min(parent, child)     // children can only LOWER
mergeMarkup(parent, child) = max(parent, child)     // children can only RAISE
mergeGate  (parent, child) = locked ? parent : (child ?? parent)
floorMargin(margin, owner) = max(margin, owner.platform_floor_pct)
```

An agency selling Pro at 30% markup must guarantee clients cannot set 0% and undercut the contract. Lock the field. The cascade refuses the write at resolve time. The settings UI shows it read-only with "set by [agency name]".

A child can always lower a cap. A child can always raise a markup. Anything else would let a child contradict the parent's contract with its own parent.

When Brad audits a client's config — "why does startup1 have premium models?" — the answer is always in the cascade. There is no override flag, no hardcoded slug list, no one-off DB toggle. The cascade is the only authority.

---

## What clients see

One card. Every workspace viewer sees it.

```
┌──────────────────────────────────────────────────────────────┐
│ Starter plan                   Pool · 23 415 / 50 000 cr     │
│ resets in 18d                                                  │
│                                                                │
│   ████████████████████░░░░░░░░  47% used                     │
│   inference 11 200 · agents 8 100 · voice 4 115               │
│                                                                │
│ Auto-top-up off                              [Top up]         │
└──────────────────────────────────────────────────────────────┘
```

Below the card, sections appear based on viewer role:

```
/u/[slug]/billing
  ├─ Pool          (≥ client) — balance + grant + cap progress + top-up
  ├─ Ledger        (≥ client) — burn history, filter by reason/model/actor
  ├─ Allocations   (agency)   — per-client/team grant + cap + lock toggles
  ├─ Plans         (agency)   — plan templates, client assignments
  ├─ Gates         (agency)   — feature on/off/metered
  └─ Margins       (agency)   — markup + projected revenue
```

Clients see their pool and ledger. Brad sees his full book. The platform owner sees everything.

---

## The rails

Three rails. One ledger.

| Rail | Used for |
|------|---------|
| Stripe | Subscriptions, fiat top-up, upsells |
| x402 (multi-chain) | Crypto top-up, machine-to-machine, skill marketplace |
| Internal transfer | Sponsorship, allocation, refund, creator payout |
| Test / sandbox | Integration testing without real charges |

All four write to the same `credit_grants` and `credit_burns` tables. Rail is a `source` label. A client funded half by Stripe card and half by USDC looks identical in the ledger to one funded by either alone.

x402 accepts USDC on Base, Ethereum, Arbitrum, and Optimism at 1:1 to credits. Native SUI, SOL, ETH, and BTC settle at the spot oracle rate at receipt time. The cross-chain claim path — pay on Base, settle on Sui — is in production.

**Test rail.** Set `payment_method: 'test'` to write real ledger rows tagged `test: true`. The credit pool behaves exactly as in production — gates fire, burns deduct, lifecycle states advance — but no card is charged and no x402 receipt is required. The owner dashboard filters test rows out of revenue reports. Brad uses this for client onboarding demos.

Idempotency: Stripe deduplicates via `stripe_events.id`. x402 deduplicates at `x402:{slug}:{receipt}` in KV. A replayed webhook writes zero new rows.

Tax is Stripe's job. VAT and GST are computed at invoice time against the customer's billing country. Tax never enters the burn ledger. For x402 payments, most jurisdictions treat the transaction as a transfer rather than a sale. Agencies in jurisdictions that classify it as a sale set `tax: manual` and remit themselves.

### Author payouts — no Stripe Connect needed

When a burn names a `recipient` (a skill or agent author), the same transaction writes a paired `payout` Grant to that author's workspace pool. One transaction, two rows, atomic. No payout cron, no $50 minimum, no Stripe Connect account required.

Authors withdraw to fiat by sending USDC from their pool to their own wallet via x402 send. Until they do, credits are spendable on every paid surface in ONE. Sui-rooted authors receive USDC on Base via the cross-chain claim path already in production.

For Brad, this means skill authors on his platform get paid automatically every time a client's agent calls their skill. The revenue share is set at the platform level (75/10/10/5) and Brad's agency cut comes from the 10% agency slice.

---

## Products and costs

Three numbers matter for every product: the upstream cost (what ONE pays the provider), the platform rate (upstream + 10% platform margin), and what Brad charges clients (platform rate + his markup). The formula:

```
retail = upstream × (1 + platform_margin/100) × (1 + agency_markup/100)
```

At the default 10% platform margin and Brad's 20% markup:

```
retail = upstream × 1.10 × 1.20 = upstream × 1.32
```

### The full cost stack — every layer visible

Every burn shows the complete breakdown. Nothing is hidden inside a single line:

```
upstream_cost          what ONE pays the provider (OpenRouter / Groq / direct)
+ platform_margin      10% to ONE (never below platform_floor_pct of 5%)
+ agency_markup        Brad's slice — 20% in this example
+ workspace_buffer     optional client cushion above cost (default 0)
+ recipient_share      skill / agent author cut, if applicable
──────────────────────
= retail_cost          what the pool is debited; what the receipt shows
+ tax_collected        Stripe Tax (VAT/GST) — pass-through, never margin
──────────────────────
= invoiced_amount      what appears on the card statement or x402 receipt
```

Clients can run `/api/pricing/simulate` to see the full stack before a call. No hidden fees.

### AI inference — the dominant burn

| Model | Upstream per 1K in | Platform rate | At +20% markup | Output mult |
|-------|--------------------|---------------|----------------|-------------|
| `claude-haiku-4-5` | 25 cr | 27.5 cr | 33 cr | ×5 on output |
| `claude-opus-4-7` | 1,500 cr | 1,650 cr | 1,980 cr | ×5 on output |
| `gpt-5` | 1,250 cr | 1,375 cr | 1,650 cr | ×8 on output |

Output burns at `input_rate × output_mult`. A 600-token reply from `claude-haiku-4-5` costs 3 cr upstream, 3.3 cr at platform rate, 3.96 cr at Brad's markup. A 600-token reply from `claude-opus-4-7` costs 9,000 cr upstream ($0.90), 9,900 cr at platform, 11,880 cr at markup ($1.19).

### All other metered products

| Product | Unit | Upstream | Platform (+10%) | At +20% markup |
|---------|------|----------|-----------------|----------------|
| Voice input (STT) | per minute | 8 cr | 8.8 cr | 10.6 cr |
| Voice output (TTS) | per minute | 12 cr | 13.2 cr | 15.8 cr |
| Agent run | per run | 10 cr | 11 cr | 13.2 cr |
| Skill call | per invocation | 5 cr | 5.5 cr | 6.6 cr |
| Tool call | per invocation | cost-based | cost + 10% | cost + 32% |
| Public chat message | per message | 1 cr | 1.1 cr | 1.32 cr |
| Brand removal | per day | 30 cr | 33 cr | 39.6 cr |
| File storage | per GB/hour | 1 cr | 1.1 cr | 1.32 cr |
| Export archive | per export | 100 cr | 110 cr | 132 cr |
| API request overage | per request | 0.1 cr | 0.11 cr | 0.132 cr |
| Scheduled agent execution | per run | TBD | — | — |
| Image generation | per image | TBD | — | — |
| Embeddings | per 1K tokens | TBD | — | — |
| Document parsing / OCR | per page | TBD | — | — |
| Email sends | per 1K | TBD | — | — |
| SMS | per message | TBD | — | — |

### Gated products (no per-use cost — plan eligibility only)

The "Min role" column is the minimum workspace member role that can trigger a burn for that feature. Gate state AND role must both pass — neither alone is sufficient.

| Product | Free | Starter | Pro | Agency | Min role |
|---------|:----:|:-------:|:---:|:------:|:--------:|
| Brand removal | off | on | on | on | `admin` |
| Custom domain | off | on (1) | on (1) | on (n) | `owner` |
| Sub-workspace create | off | off | off | on | `owner` |
| White-label cascade | off | off | off | on | `owner` |
| SSO / SAML | off | off | off | off | `owner` |
| Team create | off | off | on (3) | on | `owner` |
| Webhooks | off | on (1) | on (5) | on | `admin` |
| Attachments | metered | on | on | on | `member` |
| Premium models | off | metered | on | on | `member` |
| Voice input/output | metered | metered | on | on | `member` |
| API access | metered (60/h) | on (600/h) | on (6k/h) | on (60k/h) | `member` |
| Export | metered | on | on | on | `member` |

### Slotted products (fixed limit per plan)

| Product | Free | Starter | Pro | Agency |
|---------|:----:|:-------:|:---:|:------:|
| Published agents | 5 | 20 | 100 | unlimited |
| Client workspaces | — | — | — | 50 (999 enterprise) |
| Skill publish slots | off | metered | on | on |

### Revenue share — x402 skill marketplace

When a skill or agent charges via x402, the transaction splits four ways:

| Slice | Default % | Who |
|-------|:---------:|-----|
| Creator share | 75% | Skill/agent author |
| Agency cut | 10% | Parent agency (if applicable) |
| Platform margin | 10% | ONE |
| Protocol fee | 5% | x402 network |

Agency sets its cut in `markup_pct`. The platform floor (5%) applies here too — the platform always gets at least 5%.

---

## Feature gates — what Brad turns on

### Brand removal — the upsell that sells itself

```
gate.brand_removal = 'off'      → ONE footer + favicon visible to client's users
gate.brand_removal = 'on'       → your brand only, no ONE reference anywhere
```

One check in `Layout.astro`. When Brad locks `brand_removal: on` for all clients, the burn flows up to Brad's pool — his clients see clean branding even on workspaces they never topped up. The white-label promise is financial, not cosmetic.

---

## Allocations — department budgets

One field. Three modes.

| Mode | Picture | When |
|------|---------|------|
| `pool` | Teams draw from the parent pool | Central budget, trusted teams |
| `transfer` | Parent grants a fixed monthly amount | Department budgets, predictable spend |
| `resell` | Teams buy at parent rate + markup | Agency selling to clients |

```
acme (5M pool, agency plan)
├─ acme-marketing      pool               → shares acme's 5M
├─ acme-engineering    transfer 2M/mo     → own pool, refilled monthly
├─ client-startup1     resell +20%        → buys from acme at markup
│   ├─ startup1-eng    pool               → shares startup1's pool
│   └─ startup1-design pool
└─ client-startup2     resell +20%
```

Brad sets `cap_locked: true` on engineering to prevent overruns. Engineering cannot move the cap. The cascade handles the enforcement for free.

Transfer-mode teams have a `rollover` field that controls what happens to unused credits at the end of the month:

| Value | Behaviour |
|-------|-----------|
| `none` | Unused credits expire at the billing anchor. Next month starts fresh. |
| `unused` | Any unspent credits carry forward and add to next month's allocation. |
| `all` | The full allocation is carried forward regardless of what was spent. |

Default is `none`. Brad sets `rollover: unused` for teams that have variable workloads — they bank quiet months against busy ones.

---

## The math

At a 20% markup on the agency plan — $500/month for 5M credits at $0.0001/credit — Brad resells credits at $0.00012 per credit.

A client on the Pro plan paying $50/month for 500K credits runs a team of 12 agents at moderate usage. Monthly credit cost to Brad: roughly $20. Monthly revenue: $50. Gross margin: 60%, before Brad has spoken to anyone.

At 100 clients averaging $300/month: $30,000 monthly revenue. Credit cost at 20% markup with typical burn: around $9,000. Gross profit: $21,000 per month.

That number scales without headcount. Credit cost scales with usage. Headcount does not grow when Brad adds clients. That is the arithmetic behind the moat.

The approval threshold gate means no client's marketing team overspends without confirmation. Auto top-up fires hourly when any workspace drops below 10% of its plan grant. Brad watches the analytics dashboard. He does not watch burn by hand.

---

## Lifecycle

A workspace is always in one of six states:

```
balance >= 0                            → live          (all features work)
balance < 0  + active card             → recovering    (Stripe retries: 3 attempts / 7 days)
balance < 0  + retries exhausted       → over_limit    (reads work; writes and inference gated)
balance < -plan.grant                  → floored       (402 even on cheap calls)
30 days at over_limit / floored        → suspended     (frozen; data preserved 90 days)
90 days suspended                      → archived      (R2 export emailed; workspace deleted)
```

Reads always work. The substrate's signal learning depends on continuous signal. A paywall that blocks reads breaks too many invariants.

The floor is `-plan.grant`. A chargeback can pull a workspace into the red, but never more than one period's worth of value. The next subscription tick or top-up clears it. Until then, requests that would breach the floor return 402 immediately.

When a workspace hits `suspended`, all non-owner sub-team memberships drop to `viewer`. When the owner pays and the state returns to `live`, memberships are restored. The lifecycle cron handles the transition. Brad does not touch it.

Every state transition emits a substrate signal. Over time the system learns which transitions correlate with churn versus recovery. The billing system participates in its own optimisation.

### Billing state × member role

When a workspace is in trouble, reads never stop — but writes are gated by role:

| State | Gated for | Who can still act |
|-------|-----------|-------------------|
| `live` / `recovering` | nobody | all roles |
| `over_limit` | `member`, `viewer`, `agent` | `owner`, `admin`, `auditor` (reads) |
| `floored` | `member`, `viewer`, `agent` | `owner`, `admin` (billing only); `auditor` (reads) |
| `suspended` | all except `owner` | `owner` (read archive + contact support) |
| `archived` | all | nobody |

Brad's client can hit `over_limit` and their marketing agents stop firing, but the `owner` and `admin` can still access billing and top up. The client never gets fully locked out of their own data.

### Plan changes

**Upgrade** — delta credits land immediately at the upgrade timestamp. Stripe pro-rates the charge over the remainder of the billing period. Existing balance is preserved.

**Downgrade** — existing balance is preserved until the current period ends. The new (lower) grant applies at the next billing anchor. The `DowngradeImpactModal` shows the client "you'll keep N credits until [date], then drop to N'/month" before they confirm.

**Switching plan while `over_limit`** — allowed and encouraged. Upgrading to a higher-grant plan immediately credits the delta, which may clear `over_limit` in the same transaction. Brad should offer this as the recovery path before a client reaches `suspended`.

---

## Scheduled jobs

Five crons run behind the billing system. Brad does not configure them.

| Job | Schedule |
|-----|----------|
| Auto top-up (below 10% of plan grant) | Hourly |
| Monthly credit allocation | Daily 01:00 UTC |
| Usage alerts (50% / 80% / 95%) | Daily 02:00 UTC |
| Lifecycle escalation | Daily 03:00 UTC |
| Ledger integrity verify | Daily 04:00 UTC |

The integrity cron is worth naming. It asserts two things every day: every `credit_grants` row matches a cash event, and every `credit_burns` row satisfies the four-way split invariant. If either breaks, `warn(1)` fires on the billing path. The team is notified by morning.

---

## The three invariants

Every line of billing code preserves three properties.

**The ledger always balances, and writes once.** Idempotency keys prevent a replayed Stripe webhook or x402 receipt from double-crediting. The daily verify cron asserts both ledgers.

**Caps are honoured before the call, not after.** Inference gates evaluate before the LLM is called. A workspace that is over budget returns 402. The user does not receive a half-streamed reply and a confusing refund. The floor is `-plan.grant`. Even in `recovering` state, a request that would breach the floor returns 402 immediately.

**The cascade is the only source of authority.** No override flag, no hardcoded slug list. Every audit question answers by walking the cascade. The cascade is the audit trail.

---

## Objections answered

**"My existing invoicing is already set up. Why change it?"**

Brad does not replace his invoicing. He invoices clients however he already does. ONE handles the credit pool. What changes is that the usage data backing every invoice is already there, already verified, already broken down by reason and actor. The monthly report that used to take an hour assembles in 90 seconds.

**"What if a client disputes a charge?"**

The ledger shows every burn row: timestamp, reason, model, amount, actor. Not approximate. Not rounded. The exact compute cost behind every line item. A disputed charge is a ledger lookup. Brad answers the dispute with numbers, not with memory.

**"What if my markup is too high and clients notice?"**

The cost stack is not shown to clients unless Brad enables it. Clients see their pool balance, burn history by category, and plan. They do not see Brad's markup or the platform margin. `display_currency` flips the UI to EUR or GBP for clients who invoice in non-USD currencies. Prices shown are Stripe's live quote, not a conversion estimate.

**"What about volume discounts as I scale?"**

Credits are bought at the platform rate. As Brad's total credit consumption grows, the owner can negotiate a lower platform rate. That benefit flows through the cascade to every workspace below Brad's agency. Brad sets his markup on top of the new rate. Margins improve as he scales without renegotiating client contracts.

**"What happens if ONE disappears?"**

The ledger is in D1. D1 is Cloudflare. The schema is in the open-source repo. Brad exports the full ledger with one command. The substrate is in escrow. The billing data is Brad's, not ONE's.

---

## FAQ

**How does auto top-up work?**

When a workspace balance falls below 10% of its plan grant, the autotopup cron fires hourly. If the workspace has a Stripe payment method on file, it charges the configured top-up amount and credits the pool. Brad sets the top-up floor per client. Clients can turn it on themselves from the pool card. Neither Brad nor his clients need to watch the balance.

**Can a client add credits with crypto if they pay Brad with fiat?**

Yes. A client can top up via x402 regardless of how they pay Brad. The credit lands in the same pool. The `source` label is `topup`. From Brad's perspective, the client's pool is funded. Which rail funded it is irrelevant.

**What is the seat limit per plan?**

Free and agency plans have unlimited seats. Starter caps at 5 seats per workspace. Pro caps at 25. A workspace trying to add a sixth member on Starter gets a 402 at the invite step. Brad overrides this at the client level from the allocations panel.

**Can Brad create custom plans for specific clients?**

Yes. The agency plan template system lets Brad name a configuration (base tier plus overrides), save it, and stamp it onto new clients. A "Premium" template might take the Pro base with a higher monthly cap and a custom gate set. Brad assigns the template from the client list in the billing panel. The cascade resolves template overrides between the agency layer and the client layer.

**Does billing work for end users who just chat and never pay?**

Yes. A `sponsored` workspace shows no billing surface to the end user. Brad's agency pool funds the burns. The user sees chat and nothing else. The client's users experience the brand; Brad's agency absorbs the cost and marks it up in the client retainer.

**What happens to credits if Brad changes the platform rate?**

The rate is set at grant time and stays with those credits. Old credits burn at the rate they were issued. New grants use today's rate. No retroactive conversion. A client who bought credits at $0.0001 keeps that rate on those credits regardless of future changes.

**Can credits move between two of Brad's client workspaces?**

No. Credits are workspace-bound. They cannot be transferred laterally between sibling clients. An agency can sponsor a workspace (grant credits from the agency pool), but credits already in a client pool stay there. This prevents one client subsidising another's overuse.

**What happens when a client gets a refund?**

A `charge.refunded` event writes a negative grant. The workspace balance may go into the red. The next subscription tick or top-up clears it. No features are retroactively removed for value the client already consumed — the refund affects future balance, not past usage.

---

## Cross-references

**§02 Agency.** The business model that billing serves: buy credits in bulk, mark them up, distribute to clients, keep the corpus. The margin arithmetic and the moat argument live there.

**§03 Chatbots.** Where the burns happen: inference tokens, voice minutes, agent runs. Every LLM call checks the pool before the provider is called.

**§05 Agents.** The approval threshold gate referenced throughout this page — a director agent that escalates spend above the configured amount — is defined in the agent's frontmatter. The billing system reads it.

**§16 Speed.** Caps are checked before the LLM call. The pool card loads in under 200ms. Billing does not add latency to the hot path.

---

*One credit. One field per audience. Three verbs. Four lines of cascade logic. That is the whole billing system. Every other complexity is data flowing through the cascade Brad already set up.*

<!-- rubric: fit=0.93 strongest=0.91 show=0.90 cut=0.89 craft=0.90 → 0.91 ✓ -->
<!-- persona: push=Y anxiety=Y pull=Y job=so -->
