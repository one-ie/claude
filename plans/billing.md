# billing.md — One credit. Three verbs. One field per audience.

The whole billing system is a function: `cost(action, workspace) → credits`,
and a mutation: `debit(workspace, credits) → ok | rejected`. Everything
else — plans, subscriptions, agency markups, department budgets, brand
removal, inference pass-through — is *data that resolves through the same
cascade as design tokens* (`roles.md §4`, `groups.md §4`).

The elegance: **each audience sets exactly one field**. The cascade fills
in the rest.

```
   1 credit  =  $0.0001  (owner sets globally; immutable per grant)

   GRANT  →  POOL  →  BURN
                  │
                  └── GATE  (on | metered | off)
```

That's the model. Read it once; the rest of this doc is how it resolves.

---

## 1. Setup, by Audience

The whole pitch. Each audience writes one file (or clicks one button).

### Tony (owner) — `/_platform/billing.md`

```yaml
rate_usd_per_credit: 0.0001
platform_margin_pct:  10            # owner's default slice
platform_floor_pct:    5            # agencies cannot squeeze below this
billing_anchor: monthly             # grants and caps reset on the workspace's anchor day
tax: stripe                         # fiat tax: stripe | manual | none
plans:                              # free / starter / pro / agency are just bundles
  free:     { grant: 1_000,     gates: { brand_removal: off  } }
  starter:  { grant: 50_000,    gates: { brand_removal: on   } }
  pro:      { grant: 500_000,   gates: { brand_removal: on, premium_models: on } }
  agency:   { grant: 5_000_000, gates: { brand_removal: on, premium_models: on, sub_workspace_create: on, white_label_cascade: on } }
models:
  claude-haiku-4-5:  { upstream_per_1k_in: 25,   output_mult: 5  }
  claude-opus-4-7:   { upstream_per_1k_in: 1500, output_mult: 5  }
  gpt-5:             { upstream_per_1k_in: 1250, output_mult: 8  }
```

**Zero setup.** Defaults ship in repo. Every field above is mutable from
the owner dashboard; none are required to operate.

### Agency (acme) — `acme/billing.md`

```yaml
plan: agency
markup_pct: 20                      # ≥ platform_floor_pct (cascade enforces)
brand_lock: true                    # all my clients are white-labelled
client_default_plan: starter        # what new clients get
# optional:
display_currency: EUR               # default $; flips UI only — credits stay USD-anchored
tax: stripe                         # inherits platform; override 'manual' for self-managed VAT
```

**Three fields. Setup time: 30s.** Now sells to clients with 20% margin.

Seat limits cascade from `plan.ts PlanLimits.maxSeats` (0 = unlimited):

| Plan | maxSeats |
|------|:--------:|
| free | unlimited |
| starter | 5 |
| pro | 25 |
| agency | unlimited |
| enterprise | unlimited |

`invite_member` enforces this at write time: count current memberships for the
workspace and reject with 402 when at the seat ceiling. Agency and enterprise
plans never hit the ceiling — unlimited seats is the agency value prop.

### Client (startup1, child of acme) — `acme/clients/startup1/billing.md`

```yaml
plan: starter
monthly_cap: 50_000                 # optional — defaults to plan grant
```

**One field. Setup time: 10s.** Card on file. Teams under it share the pool.

### Team (startup1-eng, child of startup1) — `acme/clients/startup1/teams/eng/billing.md`

```yaml
allocation: 30_000                  # monthly slice from parent pool
cap_locked: true                    # eng can't overrun engineering's budget
```

**One field. Setup time: 5s.** Or omit the file entirely → team shares the parent pool.

### End user (alice) — one button

```
[ Top up $5 ]                       # opens Stripe / x402 modal
```

**One click. Setup time: 5s.** Or zero — if sponsored, no surface visible.

That is the entire user-facing system. Everything below is how it resolves.

---

## 2. The Three Verbs

### Grant — credits arrive

```ts
type Grant = {
  workspace: string
  source: 'subscription' | 'topup' | 'sponsorship' | 'promo' | 'refund' | 'payout'
  amount_credits: number
  cents_paid?: number               // null for sponsorship / promo / payout
  parent?: string                   // grantor slug (sponsorship only)
  expires_at?: number               // null = never; expiring credits burn first
  ts: number
}
```

D1 table: `credit_grants`. One row per Stripe `invoice.paid`, one per x402
receipt, one per agency → client allocation. Sources are labels; the pool
is rail-agnostic.

**FIFO on expiry.** When debiting, expiring credits are consumed before
non-expiring ones. Credits never expire if there's still debitable
balance left to use them. One line in `debitPool()`; zero user-facing
complexity.

### Burn — credits leave

```ts
type Burn = {
  workspace: string
  actor?: string | null             // member slug who triggered the burn; null = anonymous / system
  reason: 'inference' | 'agent_run' | 'skill_call' | 'tool_call'
        | 'storage' | 'voice' | 'api' | 'transfer'
  amount_credits: number            // gross — what the workspace pays
  cost_credits: number              // net — upstream provider + protocol fees
  agency_margin?: number            // captured by parent agency
  platform_margin: number           // captured by owner (≥ owner.platform_floor_pct)
  recipient_share?: number          // skill/agent author cut → posted as a Grant to author's pool
  ts: number
}
```

D1 table: `credit_burns`. **Invariant:** `amount = cost + agency_margin
+ platform_margin + recipient_share`. If the math doesn't balance, the
burn is rejected — same rule the existing `x402_payments` table
(`migrations/0015_x402_payments.sql`) already enforces.

**Existing 3-way split extends to 4-way.** Today `src/lib/x402.ts`
splits 85/10/5 (creator/platform/protocol). For agency-parented
workspaces, `computeSplit(amountCents, parentSlug?)` returns four slices
(default 75/10/10/5 = creator/agency/platform/protocol). The protocol
fee (5% x402) is folded into `cost_credits` because from ONE's
perspective it's an upstream cost — same shape as the OpenRouter token
cost. The `x402_payments` table gains an `agency_usd` column in Step 1.

**Author payouts ride x402 send.** When a burn names a `recipient`, the
same transaction writes a paired `payout` Grant to the author's
workspace pool — same ledger, no Stripe Connect, no payout cron, no $50
minimum. Authors withdraw to fiat by sending USDC from their pool to
their own off-platform wallet via x402 *send* side (`oneFetch()`, Wave 0
in `/Users/toc/Server/x402.md`). Until Wave 0 ships, authors keep
credits inside ONE — already a useful state because credits are spendable
on every paid surface. **Crypto-native by architecture, no fiat payout
infra needed.**

**Sui-rooted authors** (the ONE default per `passkeys.md`) get stable
payouts via the cross-chain claim path: ONE sends USDC on Base, author
redeems on Sui through the `x402_claim` coupon already in production.
When Wave 1 ships USDC-on-Sui (Coin-type verifier, TODO at
`protocol/handlers/x402.ts:293`), payouts become single-hop on Sui. No
billing-system change required — the rail layer absorbs it.

### Gate — feature is on / metered / off

```ts
type GateState = 'on' | 'metered' | 'off'
// 'on'      — covered by plan, no per-use charge
// 'metered' — available, charged per use against the pool
// 'off'     — unavailable, UI hidden or shows upgrade CTA
```

Three states. No fourth state. Resolved at request time in middleware,
read everywhere as `Astro.locals.workspaceContext.gates`.

---

## 3. The Cascade

Same 6-layer cascade as `groups.md §4`. Same merge function. Same lock
semantics. Two asymmetries are the whole policy engine:

```ts
mergeCap   (parent, child) = min(parent, child)         // children can only LOWER
mergeMarkup(parent, child) = max(parent, child)         // children can only RAISE
mergeGate  (parent, child) = locked ? parent : (child ?? parent)
floorMargin(margin, owner) = max(margin, owner.platform_floor_pct)  // platform floor wins
```

That's it. Six lines. Everything else is data in `billing.md` files.

The fourth rule is the platform's seatbelt: after every cascade resolves,
`platform_margin_pct` is clamped up to `owner.platform_floor_pct`. An
agency can squeeze its own markup to zero (give clients wholesale prices)
but can never starve the platform. Owner is the only layer that can
lower the floor.

### What cascades

| Property | Source layer | Override | Lock |
|----------|:------------:|:--------:|:----:|
| `plan` | self | sovereign | — |
| `monthly_cap` | parent | down only | ✓ |
| `markup_pct` | parent | up only | ✓ |
| `gates.*` | parent | yes | ✓ |
| `models[].enabled` | parent | yes | ✓ per model |
| `balance_credits` | self | sovereign | — |

### Why asymmetry

An agency selling Pro at 30% markup must guarantee its clients can't set
their own 0% markup and undercut. Lock the field; cascade refuses the
write at resolve time; settings UI for the client shows the field
read-only with "set by acme" tooltip — same UX as `primary-locked` in
the design system.

A child can always **lower** a cap (you can choose to spend less than
your allocation). A child can always **raise** a markup (you can pay
your own staff a bigger cut). Anything else would let a child contradict
the parent's contract with its parent — and break the white-label promise.

---

## 4. Inference (the dominant burn)

80%+ of all burns are LLM tokens. The cost stack, made transparent:

```
upstream_cost          (provider price — OpenRouter / Groq / direct)
+ platform_margin      (owner's slice; ≥ owner.platform_floor_pct)
+ agency_markup        (parent workspace, cascades; default per plan)
+ workspace_buffer     (optional client cushion, default 0)
+ recipient_share      (skill / agent author cut, if applicable)
─────────────────────
= retail_cost          (debited from the pool; receipt shows this)
+ tax_collected        (Stripe Tax, pass-through; never margin)
─────────────────────
= invoiced_amount      (what the card statement / x402 receipt shows)
```

Every layer is visible in the burn ledger. A workspace can always
simulate "what would this cost?" at `/api/pricing/simulate` (to add) and
get the full stack echoed back. **No hidden fees, ever.**

**Tax never enters the burn ledger.** Stripe Tax computes VAT/GST at
invoice time using the customer's billing country and remits to the
appropriate authority. For x402 (crypto-to-crypto), most jurisdictions
treat the transaction as a transfer rather than a sale; agencies in
jurisdictions that classify it as a sale set `tax: manual` and remit
themselves.

**Currency is a UI flip with one source of truth.** Credits stay
USD-anchored. When a workspace sets `display_currency: EUR`, the price
shown is **`Price.unit_amount` from Stripe** for that currency — the
exact amount the customer's card will be charged, fetched live (cached
60s in KV). No ECB-vs-Stripe drift, no "quoted €4.50, charged €4.55"
surprise. For x402 top-ups the displayed amount is always USD because
USDC is dollar-stable; non-USD display is a Stripe-only concern.

### The burn flow

```ts
// src/pages/api/chat.ts (target)
const upstream = await callLLM(model, messages)
const burn = computeBurn({
  upstream:  toCredits(upstream),
  workspace: ctx.locals.workspaceContext.slug,
  parent:    ctx.locals.workspaceContext.parentWorkspace,
  reason:    'inference',
})
const ok = await debitPool(burn)    // atomic with response
if (!ok) throw new HttpError(402)   // Payment Required (same status x402 uses)
```

Caps are honoured **before** the LLM is called — never refund-after-the-fact
because the user already saw the half-streamed reply.

---

## 5. Allocations (department / team budgets)

One field, three values. Anything more is just nested groups.

```yaml
allocation:
  mode: pool | transfer | resell
  monthly_credits?: 30_000          # transfer mode
  retail_markup_pct?: 20            # resell mode (parent profits per credit)
  rollover?: none | unused | all
```

| Mode | Picture | When |
|------|---------|------|
| `pool` | Children draw from parent's pool directly | Trust-rich teams; central budget |
| `transfer` | Parent grants fixed monthly amount to each child | Department budgets; predictable spend |
| `resell` | Children buy at parent's price + markup | Agency selling to clients |

```
acme (5M pool, plan: agency)
├─ acme-marketing      pool                      → shares acme's pool
├─ acme-engineering    transfer 2M/mo, all-roll  → own pool, refilled monthly
├─ client-startup1     resell +20%               → buys from acme at markup
│   ├─ startup1-eng    pool                      → shares startup1's pool
│   └─ startup1-design pool                      → shares startup1's pool
└─ client-startup2     resell +20%
```

Each layer is its own `billing.md`. `cap_locked` lets the parent freeze a
child's monthly burn — engineering can't suddenly burn the marketing
budget. The cascade handles it for free.

---

## 6. Feature Gates (the enable/disable matrix)

Defaults per plan. Agencies override any of these for their clients. The "min
role" column is the minimum `MemberRole` that can trigger a burn for that
feature — role-check.ts enforces this before the gate is consulted. Both must
pass: gate must be `on` or `metered` AND caller must have the required role.
Full matrix: `roles.md §16 Feature gate × member role`.

| Feature | Free | Starter | Pro | Agency | Min MemberRole |
|---------|:----:|:-------:|:---:|:------:|:--------------:|
| `brand_removal` | off | on | on | on | `admin` |
| `custom_domain` | off | on (1) | on (1) | on (n) | `owner` |
| `sub_workspace_create` | off | off | off | on | `owner` |
| `white_label_cascade` | off | off | off | on | `owner` |
| `premium_models` | off | metered | on | on | `member` |
| `agent_create` | metered (3) | on (10) | on (50) | on | `admin` |
| `skill_publish` | off | metered | on | on | `admin` |
| `team_create` | off | off | on (3) | on | `owner` |
| `voice_input/output` | metered | metered | on | on | `member` |
| `attachments` | metered (5/d) | on | on | on | `member` |
| `file_storage` | 100 MB | 1 GB | 25 GB | unlimited (metered) | `member` |
| `api_access` | metered (60/h) | on (600/h) | on (6k/h) | on (60k/h) | `member` |
| `webhooks` | off | on (1) | on (5) | on | `admin` |
| `export` | metered ($1) | on | on | on | `member` |

### Brand removal — the canonical upsell

```
gate.brand_removal = 'off'      → ONE footer + favicon + canonical visible
gate.brand_removal = 'metered'  → 30 cr/day to hide; auto-pays from pool
gate.brand_removal = 'on'       → never visible (covered by plan)
```

One `if` in `Layout.astro`, next to the existing `siteTokens` resolution.
When an agency locks `brand_removal: 'on'` for clients, the burn flows
**up** to the agency's pool — clients see clean branding even if they
never paid ONE a cent. **The white-label promise made financial.**

### Metered prices

Each metered feature publishes its rate in `billing.md`:

```yaml
metered:
  brand_removal_per_day: 30
  voice_per_minute_in: 8
  voice_per_minute_out: 12
  agent_run_base: 10                # plus inference burn
  skill_call_base: 5
  storage_per_gb_hour: 1
  api_overage_per_request: 0.1
  export_per_archive: 100
```

Defaults at Layer 0; agencies override at Layer 2; clients at Layer 3.
Same merge, same locks.

---

## 7. The UI (`/billing`)

One card every viewer ≥ `client` sees. Same shape as the brand card
pattern from `roles.md §5` — one `<article>`, three slots.

```
┌──────────────────────────────────────────────────────────┐
│ Pro plan                       Pool · 23 415 / 50 000 cr │
│ resets in 18d                                             │
│                                                            │
│   ████████████████████░░░░░░░░░░░  47% used              │
│   inference 11 200 · agents 8 100 · voice 4 115           │
│                                                            │
│ Auto-top-up off                              [Top up]    │
└──────────────────────────────────────────────────────────┘
```

Below the card, sections appear conditional on viewer:

```
/u/[slug]/billing
  ├─ Pool          (≥ client) — balance + grant + cap progress + top-up
  ├─ Ledger        (≥ client) — burn history, filter by reason/model/actor
  ├─ Allocations   (agency)   — per-client/team grant + cap + lock toggles
  ├─ Plans         (agency)   — define what you sell to clients
  ├─ Gates         (agency)   — feature on/off/metered (mirrors roles.md surfaces)
  ├─ Margins       (agency)   — markup + projected revenue
  └─ Platform      (owner)    — rate, default plans, model catalogue
```

The Settings page (`src/pages/u/[slug]/settings.astro`) gets one new
section: **Billing** with subsections Pool · Plan · Auto-top-up · Alerts.
Anything heavier lives at `/billing` so Settings stays scannable.

---

## 8. Payment Rails

Three rails, one ledger.

| Rail | Used for | Code |
|------|----------|------|
| Stripe | Subscriptions, fiat top-up, brand-removal upsell, author payouts out | `src/pages/api/pay/{create-intent,webhook}.ts` |
| x402 (multi-chain) | Crypto top-up, M2M, skill marketplace; USDC on Base/ETH/ARB/OPT (1:1 → credits), native SUI/SOL/ETH/BTC (spot oracle → credits at receipt time); cross-chain claim "pay on Base, settle on Sui" via x402_claim coupon. USDC-on-Sui + USDC-on-SOL ship Wave 1 | `src/lib/x402.ts`, `apps/one-core/backend/src/chains/{evm,sui,solana,bitcoin}.ts`, `migrations/0015_x402_payments.sql` (prod) |
| Internal transfer | Sponsorship, allocation, refund, author payout in | `src/pages/api/billing/transfer.ts` (to add) |
| Test / sandbox | Integration without real charges | `payment_method: 'test'` writes ledger rows tagged `test: true`; owner dashboard filters them out |

All three write to **the same `credit_grants` and `credit_burns` tables**.
Rail is just a `source` label. A workspace funded half by Stripe and half
by x402 looks identical to one funded by either alone — which is what lets
a free user top up with crypto while their subscription auto-renews on a
card.

Internal transfer is a debit-credit pair: agency burns N credits with
`reason: 'transfer'`, recipient gets a grant with `source: 'sponsorship'`
and `parent: agencySlug`. One transaction, two rows, atomic. No third
party. Department allocations refresh monthly via a Cloudflare Worker
cron firing one transfer per child.

---

## 9. Lifecycle

```
balance >= 0                          →  live          (everything works)
balance < 0  + active card             →  recovering   (Stripe Smart Retries: 3 attempts / 7 days)
balance < 0  + retries exhausted       →  over_limit   (reads work; writes/inference gated; banner shown)
balance < -plan.grant                  →  floored      (HTTP 402 even on cheap calls — can't go further)
30 days at over_limit / floored        →  suspended    (workspace frozen; data preserved 90 days)
90 days suspended                      →  archived     (R2 export emailed; workspace deleted)
```

Stored as `owners.billing_state`. Middleware reads it and gates writes.
Reads always work — substrate pheromone learning depends on continuous
signal, and a paywall that blocks reads breaks too many invariants.

The **negative-balance floor** (`-plan.grant`) makes chargeback abuse
impossible: a refund can pull the workspace into the red, but never more
than one period's worth of value. The next subscription tick or top-up
clears it; until then, requests that would breach the floor return 402
immediately, even mid-recovery.

### Billing state × member role access

Middleware enforces: when `billing_state` is `over_limit` or worse, role-gated
write actions are blocked for roles below `admin`. Reads are never blocked.
Full matrix in `roles.md §16 Billing state × role access`.

| State | Write actions gated for | Who can still act |
|-------|------------------------|-------------------|
| `live` / `recovering` | nobody | all roles |
| `over_limit` | `member`, `viewer`, `agent` | `owner`, `admin`, `auditor` (reads) |
| `floored` | `member`, `viewer`, `agent` | `owner`, `admin` (billing mgmt only); `auditor` (reads) |
| `suspended` | all except `owner` | `owner` (read archive + contact) |
| `archived` | all | nobody |

Middleware implementation: `workspaceContext.billing_state` already available.
Add a guard in `requireAuth` (or a pre-check in middleware) before the PERMISSIONS
matrix: if `billing_state ∈ {over_limit, floored}` AND `role ∉ {owner, admin}` AND
`action ∉ SELF_ACTIONS` AND action is a write verb → return 402.

### `demoteOnSuspend` / `restoreOnResume`

When a workspace transitions to `suspended`, all non-owner sub-team memberships
are demoted to `viewer` via `demoteOnSuspend()` (mirrors `demoteOnDowngrade` in
`enrollment.ts`). On `admin_restore` (owner pays, state returns to `live`),
`restoreOnResume(orgGid, plan)` restores sub-team memberships to `member`.

```ts
// src/lib/enrollment.ts (to add)
export async function demoteOnSuspend(env, orgGid): Promise<void>
// Demotes all sub-team memberships to 'viewer'. Same TypeDB pattern as demoteOnDowngrade.

export async function restoreOnResume(env, orgGid, plan): Promise<void>
// Restores sub-team memberships to 'member' for the given plan's team set.
// Called by LC4 cron on admin_restore event.
```

These are called by `billing-lifecycle-cron.ts` (LC4) on the relevant state transitions.

Every state transition emits a substrate signal (Rule 1, closed loop), so
the pricing loop itself learns which transitions correlate with churn vs.
recovery — the billing system participates in its own optimisation.

### Plan changes (proration, all decided up-front)

- **Upgrade** — delta grant credited at the upgrade timestamp; Stripe
  pro-rates the dollar charge over the remainder of the period. Existing
  balance is preserved.
- **Downgrade** — existing balance preserved until period end; new (lower)
  grant size applies on the next billing anchor. The existing
  `DowngradeImpactModal.tsx` shows "you'll keep N credits until [date],
  then drop to N'/month".
- **Plan switch during over_limit** — allowed and encouraged; switching
  to a higher-grant plan immediately credits the delta and may exit
  `over_limit` in the same transaction.

---

## 10. The Three Invariants

Three properties every line of billing code must preserve.

**A. The ledger always balances, and writes once.** Every `credit_grants`
row matches a cash event (Stripe charge, x402 receipt, or sponsorship
transfer) — keyed for idempotency: Stripe via `stripe_events.id`, x402
via the existing `x402:{slug}:{receipt}` KV dedup. A replayed webhook
writes zero new rows. Every `credit_burns` row satisfies `amount = cost
+ agency_margin + platform_margin + recipient_share`. A daily cron
asserts both and emits `warn(1)` to the billing path if either breaks.

**B. Caps are honoured before the call, not after.** Inference gates
evaluate **before** the LLM is called. Out-of-budget requests return HTTP
402 (the same status x402 uses). Refunding a half-streamed response is
the worst possible UX. Negative balance is bounded at `-plan.grant`;
requests that would breach the floor return 402 immediately, even in
`recovering` state — so a chargeback can never run a workspace
infinitely negative.

**C. The cascade is the only source of authority.** No "billing override"
flag, no hardcoded slug list, no one-off DB toggle. If a workspace shows
`brand_removal: 'on'`, it's because some layer in the resolved chain set
it that way. Every audit question ("why does X have premium models?")
answers by walking the cascade.

---

## 11. Build Sequence

```
Step 1   D1 migrations: credit_grants, credit_burns, billing_state on owners
Step 2   src/lib/billing.ts — toCredits, computeBurn, debitPool, creditPool
Step 3   src/middleware.ts — load BillingConfig into workspaceContext.billing
Step 4   Stripe webhook → credit_grants rows on invoice.paid / failed / refunded
         (idempotent via stripe_events(id PK) insert-or-ignore on event.id;
          x402 KV dedup at x402:{slug}:{receipt} already covers crypto side)
Step 5   /billing Pool card + Ledger (viewer ≥ client)
Step 6   src/pages/api/chat.ts — wrap LLM call with debitPool + 402 on empty
Step 7   Gate evaluation in middleware; brand_removal check in Layout.astro
Step 8   Auto-top-up — Cloudflare Worker cron + Stripe Customer.charge
Step 9   /billing/allocations — agency UI for client/team grants + locked caps
Step 10  Custom plan editor — agency creates plans for its own client tier
Step 11  Owner dashboard — platform-wide revenue, costs, model catalogue
Step 12  Lifecycle state machine + substrate signals on every transition
```

Each step closes with a deterministic number (Rule 3). E.g. Step 4 done
= "Replay last 30d of webhook payloads against fresh DB; assert sum of
new credit_grants rows equals known revenue." No vibes.

---

## 12. Resolved Decisions (so they're not asked again)

- **Credit-to-USD rate volatility.** Rate is set at grant time and stays
  with the credit. Old credits at old rate; new grants at new rate. No
  retroactive conversion.
- **Cross-agency credit transfer.** No. Credits are workspace-bound.
- **Sponsorship-only end users.** `/billing` is hidden when payment_method
  is `sponsored` and balance is non-positive; user sees chat and nothing else.
- **Refund window.** A `charge.refunded` writes a negative grant. Balance
  may go negative; next subscription tick clears it. No retroactive
  feature loss for users who already used the value.

---

## 13. Surfaces Replaced

Once `/billing` ships, these get retired or absorbed (no churn for
existing users; migration is component-by-component):

- `Pricing.tsx` → plan editor + `/billing/plans`
- `pay/PriceCards.tsx` → `/billing` Pool card
- `pay/PayPanel.tsx` → kept as a rail picker, used inside `/billing`
- `billing/PaymentFailureBanner.tsx` → reads `billing_state === 'over_limit'`
- `billing/DowngradeImpactModal.tsx` → moves into plan-change confirm

---

*One credit. Three verbs. Six cascade layers (already built for design).
Two asymmetries plus one platform floor. Tax is pass-through. Fiat
display is Stripe's quote. Crypto is multi-chain — USDC where it's
stable, native tokens at spot, cross-chain claim where the wallet is on
Sui. Both rails are idempotent at the row that matters. Each audience
writes one field; the substrate learns from every transition. That's
the whole system.*
