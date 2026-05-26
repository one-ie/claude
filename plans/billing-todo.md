# billing-todo.md — wave-parallel TODO

Source: `billing.md` · `roles.md` · `groups.md` · `lifecycles.md` · `/Users/toc/Server/x402.md`

**Mode:** mixed · **Lifecycle:** construction · **Closure scalar:** V3 replay test passes (sum balance delta < 1 credit across full DB) AND B1 returns 402 within 50ms p95 on empty-pool synthetic AND LC6 emits a substrate signal on every observed transition in 24h soak.

---

## Audiences (who this billing system is for)

| Audience | Role | Code path |
|---|---|---|
| **Tony (me)** — platform owner | Set rate, plans, models, take floor | `/_platform/billing` (O-items) |
| **Agencies** — resell with markup | Plans, allocations, brand-lock, gates | `/u/[slug]/billing/{allocations,plans,gates}` (A/P/G items) |
| **Orgs / companies** — bill internal teams (no resell) | Same surface as agency, `markup_pct: 0`, `client_default_plan: internal` | Same code (no new path) |
| **End users** — logged-in customers | Pool, top-up, simple settings | `/u/[slug]/billing` Pool card (U-items) |
| **Public chatbots** — anonymous visitors | Burn from workspace owner's pool, IP-rate-limited | `/api/chat.ts` + `gates.public_chat` (B2) |

Org pattern is **the same code path as agency** — only intent differs (no markup, no resell). No new surfaces. Public chatbot is the only new burn shape: anonymous request → debit from slug owner's pool → 429 if rate-limited.

---

## How to run with `/do`

- `/do billing-todo.md --wave 0` — fan out **11 agents in one message** (all Wave-0 items, no deps)
- `/do billing-todo.md --wave N` — drive a wave end-to-end
- `/do billing-todo.md --item L1` — single item, own W1→W4 sandwich
- Each item closes with `/close --item <id>`; cycle closes with `/close --todo billing --cycle 1`

---

## Dependency graph

```
WAVE 0 (no deps — 11 parallel agents)
┌─────────────────────────────────────────────────────────────┐
│ M1 M2 M3 M4 M5 M6   L1   L2   L3   L4   L5                  │
│ migrations          lib  cfg  typ  def  rev                 │
└──────┬──────────────┬────┬────┬────┬────┬───────────────────┘
       │              │    │    │    │    │
       ▼              ▼    ▼    ▼    ▼    ▼
WAVE 1 (5 parallel — middleware + ingress)
┌─────────────────────────────────────────────────────────────┐
│ E1                W1 W2          B1 B2                      │
│ middleware        webhooks       chat (logged + public)     │
│ + cascade resolve + grant writes + 402 + anon burn          │
└──────┬─────────────┬─────────────┬──────────────────────────┘
       │             │             │
       ▼             ▼             ▼
WAVE 2 (9 parallel — UI + gates)                          ┌── WAVE 4 (5 parallel — lifecycle)
┌──────────────────────────────────────────────────────┐  │  ┌─────────────────────────────────┐
│ U1 U2 U3 U4 U5      G1 G2 G3 G4                      │  │  │ LC1 LC2 LC3 LC4-5 LC6           │
│ /billing surfaces   feature gates                    │  │  │ states · dunning · floor · cron │
└──────────┬───────────────────────────────────────────┘  │  └─────────────────────────────────┘
           │                                              │
           ▼                                              │
WAVE 3 (7 parallel — agency tier + lifecycle infra)──────┘
┌──────────────────────────────────────────────────────┐
│ A1 A2  P1 P2  C1 C2  T1                              │
│ allocations · plans · cron · sandbox                 │
└──────────┬───────────────────────────────────────────┘
           │
           ▼
WAVE 5 (5 parallel — verify + owner)
┌──────────────────────────────────────────────────────┐
│ V1-3   O1   O2-4   O5   PS1-2                        │
│ verify · platform · editors · alarm · simulator      │
└──────────┬───────────────────────────────────────────┘
           │
           ▼
WAVE 6 (3 parallel — author payouts)
┌──────────────────────────────────────────────────────┐
│ X1 (external)   X2 (after X1)   X3 (today)           │
│ oneFetch send   payout API/UI   cross-chain claim    │
└──────────┬───────────────────────────────────────────┘
           │
           ▼
WAVE 7 (5 parallel — gap closure from roles.md §17)
┌──────────────────────────────────────────────────────┐
│ GA1   GA2   GA3   GA4   GA5                          │
│ actor·burn  demote·suspend  seat·enforce             │
│ revenue·scope  billing·state·role·guard              │
└──────────────────────────────────────────────────────┘
```

**Real same-file constraints** (don't claim two on one file — Wave 7 adds):

```
src/lib/enrollment.ts               → GA2 owns (demoteOnSuspend + restoreOnResume)
src/lib/types.ts                    → GA1 owns actor field + M7 migration
src/middleware.ts / api-auth.ts     → GA5 owns billing-state role guard
src/pages/api/billing/revenue.ts   → GA4 owns read_revenue scope check
src/pages/api/identity/invite.ts   → GA3 owns maxSeats enforcement
```

```
src/lib/billing.ts          → L1 owns (B3,B4,B5 folded in)
src/lib/billing-config.ts   → L2 owns (E1's mergeBilling folded in)
src/lib/revenue-split.ts    → L5 owns (W5+W6 folded in)
src/middleware.ts           → E1 owns (G1's gates resolve folded in)
src/pages/api/pay/webhook.ts→ W1 owns (W2,W3 events folded in)
src/pages/api/x402.ts       → W2 owns
src/pages/api/chat.ts       → B1 owns (anonymous burn forks to B2's helper)
src/layouts/Layout.astro    → G1 owns (brand_removal one-line check)
src/pages/_platform/billing.astro → O2 owns (O3,O4 folded in)
src/workers/billing-cron.ts → cron items grouped by wave
```

---

## Already shipped ✓ (don't rework)

- [x] **x402-recv** — receive side prod (`src/lib/x402.ts`, `src/pages/api/x402.ts`, `chains/{evm,sui,solana,bitcoin}.ts`)
- [x] **x402-dedup** — KV at `x402:{slug}:{receipt}` 90d TTL
- [x] **stripe-scaffold** — `src/pages/api/pay/{webhook,create-intent}.ts` event dispatch wired
- [x] **plan-col** — `owners.plan` (`migrations/0009_owners_plan.sql`)
- [x] **payment-status** — `migrations/0012_payment_status.sql`
- [x] **revenue-split-3way** — 85/10/5 in `src/lib/revenue-split.ts`
- [x] **failure-banner** — `src/components/billing/PaymentFailureBanner.tsx`
- [x] **downgrade-modal** — `src/components/billing/DowngradeImpactModal.tsx`

---

## Wave 0 — 11 parallel agents (no deps)

### Migrations (haiku × 6)

- [x] **M1** `migrations/0016_credit_grants.sql` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **M2** `migrations/0017_credit_burns.sql` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **M3** `migrations/0018_billing_state.sql` (col on `owners`) · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **M4** `migrations/0019_stripe_events.sql` (idempotency) · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **M5** `migrations/0020_x402_agency_usd.sql` (cols on `x402_payments`) · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **M6** `migrations/0021_billing_anchor.sql` (`billing_anchor_day`, `display_currency` on `owners`) · `haiku` · w1[x] w2[x] w3[x] w4[x]

### Lib + Types (sonnet × 2, opus × 1, haiku × 2)

- [x] **L1** `src/lib/billing.ts` — `toCredits, computeBurn, debitPool, creditPool, currentBalance` + FIFO + per-model lookup + protocol-fee folding · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **L2** `src/lib/billing-config.ts` — `parseBilling, mergeBilling` (cascade w/ floor) · `opus` · w1[x] w2[x] w3[x] w4[x]
- [x] **L3** `src/lib/types.ts` + `src/env.d.ts` — `BillingConfig, Grant, Burn, GateState, FeatureKey` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **L4** `_platform/billing.md` defaults shipping in repo · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **L5** `src/lib/revenue-split.ts` — extend `computeSplit(amount, parentSlug?)` to 4-way + `platform_floor_pct` clamp · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 1 — 5 parallel agents (deps: Wave 0)

- [x] **E1** `src/middleware.ts` extend — load `_platform/billing.md` (KV) → parent → workspace → team → resolve via `mergeBilling` → write `Astro.locals.workspaceContext.{billing,gates}` · deps: L1,L2,L3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **W1** `src/pages/api/pay/webhook.ts` extend — idempotent via `INSERT OR IGNORE INTO stripe_events`, then dispatch `invoice.paid` (subscription grant + anchor sticky), `charge.refunded` (negative grant), `invoice.payment_failed` (state→recovering), `charge.dispute.created` (flag+freeze) · deps: M1,M4,L1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **W2** `src/pages/api/x402.ts` extend — after `INSERT OR IGNORE INTO x402_payments` write paired `credit_grants` row using L5's 4-way split · deps: M1,M5,L1,L5 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **B1** `src/pages/api/chat.ts` extend — wrap LLM call with `debitPool({reason:'inference'})`; on empty pool / negative-floor breach throw 402; mid-stream halts at next safe boundary · deps: L1,E1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **B2** `src/pages/api/chat.ts` + `src/pages/api/showcase-chat.ts` — public chatbot anonymous burn: no session → debit from slug-owner pool, IP rate-limit via KV (`chat-rl:{ip}:{slug}`), gate `public_chat: on|metered|off`, 429 on burst · deps: B1,L1,E1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

> B1 and B2 land in same file; sequence within ONE agent OR run B1 first then B2 extends. Mark file lock to prevent concurrent claim.

---

## Wave 2 — 9 parallel agents (deps: E1)

### `/billing` surfaces

- [x] **U1** `src/pages/u/[slug]/billing.astro` + `src/components/billing/PoolCard.tsx` — Pool card (balance · grant · cap · breakdown · top-up CTA) · deps: E1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **U2** `src/components/billing/Ledger.tsx` — burn ledger table + filters (reason, model, actor, ts) + CSV export · deps: U1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **U3** `src/components/billing/TopUpModal.tsx` — Stripe Elements tab + crypto tab (chain picker Base/ETH/ARB/OPT/SUI/SOL/BTC; currency picker USDC where supported else native; QR + cross-chain claim path surfaced) · deps: E1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **U4** `src/components/settings/BillingSettings.tsx` + extend `src/pages/u/[slug]/settings.astro` — Plan, Auto-top-up, Alerts subsections · deps: E1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **U5** `src/lib/currency.ts` + extend PoolCard — Stripe `Price.unit_amount` lookup, 60s KV cache at `stripe-price:{plan}:{ccy}`, render exact charge amount · deps: U1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Gates

- [x] **G1** `src/layouts/Layout.astro` — `brand_removal` check beside `siteTokens` resolution; metered → 30 cr/UTC-day debit via L1 · deps: E1,L1 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **G2** `src/components/ai-elements/model-selector.tsx` — filter by `BillingConfig.models[id].enabled` and `gates.premium_models` · deps: E1 · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **G3** `src/pages/u/[slug]/agents/new.astro` + `src/pages/u/[slug]/skills/new.astro` — server-side gate + UI hide CTA when off · deps: E1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **G4** voice/attachments per-feature meter — `src/pages/api/tts.ts`, `src/pages/api/commit-media.ts` wrap with `debitPool({reason})` at metered prices from `BillingConfig.metered` · deps: E1,L1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 3 — 7 parallel agents (deps: U1+U4 for surfaces; M3 for state)

### Allocations (agency / org)

- [x] **A1** `src/pages/u/[slug]/billing/allocations.astro` + `src/components/billing/AllocationEditor.tsx` + `src/pages/api/billing/{allocation,transfer}.ts` — agency-only viewer guard; mode picker (pool/transfer/resell); locked-cap toggles; atomic debit-credit transfer (parent burn `reason:transfer` + child grant `source:sponsorship`) · deps: U1,U4 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **A2** `src/workers/billing-allocation-cron.ts` + wrangler.toml cron — daily walk; for each `mode:transfer` allocation whose `billing_anchor_day == today`, fire one `transfer.ts` per child · deps: A1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Plans + proration

- [x] **P1** `src/pages/u/[slug]/billing/plans.astro` + extend `src/pages/api/provision.ts` — agency plan editor; `client_default_plan` applied on workspace provision · deps: U1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **P2** `src/pages/api/billing/{upgrade,downgrade}.ts` + extend `DowngradeImpactModal.tsx` — upgrade: delta grant immediate + Stripe pro-rate; downgrade: preserve balance to anchor; switch-from-over_limit: atomic credit + state→live · deps: U4,W1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Auto-top-up + alerts

- [x] **C1** `src/workers/billing-autotopup-cron.ts` + wrangler.toml hourly cron — if `balance < threshold && month_spent < monthly_max_cents`, charge Stripe customer for `topup_credits`, write grant · deps: U4,W1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **C2** `src/workers/billing-alerts-cron.ts` + extend `src/lib/email.ts` — daily 50/80/95% boundary alerts via email/webhook/in-app · deps: U4 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Sandbox

- [x] **T1** Sandbox/test — `payment_method:'test'` → ledger rows tagged `test_mode:1`; Stripe `livemode:false` events propagate; owner dashboard filters · deps: M1,M2,W1 · `haiku` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 4 — 5 parallel agents (deps: M3, B1)

- [x] **LC1** `src/lib/billing-state.ts` — pure state machine: `nextState(current, event)` over `live | recovering | over_limit | floored | suspended | archived` · deps: M3 · `opus` · w1[x] w2[x] w3[x] w4[x]
- [x] **LC2** extend `src/pages/api/pay/webhook.ts` — `invoice.payment_failed` → `recovering`; after Stripe Smart Retries final fail → `over_limit` · deps: LC1,W1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **LC3** extend `src/lib/billing.ts` + `src/middleware.ts` — `floored` 402: check `balance >= -plan.grant` before debit; breach returns 402 even mid-recovery · deps: LC1,B1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **LC4** `src/workers/billing-lifecycle-cron.ts` daily — `over_limit > 30d` → `suspended`; `suspended > 90d` → R2 export → email → delete `owners` row + R2 prefix purge (queue) · deps: LC1,C2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **LC5** every transition fires `one.signal({receiver:'billing:'+state, data:{workspace,from,to,ts}})` via L1 · deps: LC1 · `haiku` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 5 — 5 parallel agents (deps: A1, M2)

### Verification

- [x] **V1** `src/workers/billing-verify-cron.ts` daily — assert `Σgrants − Σburns == cached_balance` per workspace; assert burn split balance per row; emit `warn(1)` on mismatch · deps: M1,M2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **V2** `tests/billing-replay.test.ts` — reconstruct every workspace's balance from full grant/burn log; sum delta < 1 credit across DB; runs nightly · deps: V1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Owner dashboard

- [x] **O1** `src/pages/u/[slug]/billing/platform.astro` — owner-only; Revenue · Costs · Margin per agency · per model · anomaly alerts (O3 folded in) · `test_mode=0` filter · deps: A1 · `opus` · w1[x] w2[x] w3[x] w4[x]
- [x] **O2** `src/pages/api/_platform/billing.ts` — owner editor for rate/margin/floor: KV write at `billing:_platform` · deps: L4,O1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **O3** margin-floor alarm — folded into O1 platform.astro model table (⚠ marker when margin < floor) · deps: O1,L5 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

### Pricing simulator

- [x] **PS1** `src/pages/api/pricing/simulate.ts` + `/u/[slug]/billing/simulate` UI — echoes full cost stack for `(action, workspace)` with no side effects · deps: L1,E1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Wave 6 — 3 agents (author payouts; X1 external)

- [ ] **X1** `apps/one-core/src/sdk/oneFetch.ts` — Wave 0 in `/Users/toc/Server/x402.md §97`, **external repo**. Don't claim until apps/one-core schedules it. · `opus`
- [x] **X2** `src/pages/api/billing/payout.ts` — GET returns earned/available; POST queues claim (202 stub until X1 ships); min $1 enforced · deps: X1,W2 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **X3** `src/components/billing/CrossChainPayout.tsx` — earned credits display + claim form (Base wallet, amount picker); queues against POST /api/billing/payout; x402 Sui redemption note · deps: U3 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

> **X3 ships today** even if X1 doesn't. Cross-chain claim is in production.

---

## Wave 7 — 5 parallel agents (gap closure; deps: Wave 1)

These items close the gaps documented in `roles.md §17` and the billing ×
roles integration gaps identified in the gap audit (2026-05-26).

### GA1 — `actor` on `Burn` · `sonnet`

**Files:** `migrations/0071_burn_actor.sql`, `src/lib/types.ts` (done),
`src/lib/billing.ts`, `src/components/billing/Ledger.tsx`

**Migration:**
```sql
-- 0071_burn_actor.sql
ALTER TABLE credit_burns ADD COLUMN actor TEXT;
CREATE INDEX idx_burns_actor ON credit_burns(workspace, actor, ts);
```

**billing.ts:** Add `actor` param to `computeBurn`; write to INSERT. Pull actor
from `ctx.locals.session?.slug` at each call site (chat.ts, tts.ts, agent routes).
Anonymous burns (`public_chat`, `brand_removal_per_day`) write `actor: null`.

**Ledger.tsx:** Add optional `actor` filter chip beside `reason`/`model` filters.
When `viewer === 'member'`, pre-filter to `actor = session.slug` (members only
see their own spend). When `viewer === 'agency'` or `auditor`, show all with per-member
breakdown row at the bottom.

Exit criterion: `SELECT actor, SUM(amount_credits) FROM credit_burns WHERE workspace=? GROUP BY actor` returns non-null actor rows for every authenticated burn after GA1 ships.

- [ ] **GA1** · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

---

### GA2 — `demoteOnSuspend` + `restoreOnResume` · `haiku`

**File:** `src/lib/enrollment.ts`

Add two functions mirroring the existing `demoteOnDowngrade` / `restoreOnUpgrade`:

```ts
/** Called by LC4 cron when workspace transitions to 'suspended'. */
export async function demoteOnSuspend(env, orgGid): Promise<void>
// Demotes ALL sub-team memberships (marketing/sales/service/community) to 'viewer'.
// Same TypeDB pattern as demoteOnDowngrade but unconditional on plan.

/** Called by LC4 cron on admin_restore event (state → 'live'). */
export async function restoreOnResume(env, orgGid, plan: string): Promise<void>
// Restores sub-team memberships to 'member' for the plan's team set.
// Delegates to restoreOnUpgrade(env, orgGid, <all-members-slug>, plan)
// after querying current member list from TypeDB.
```

**billing-lifecycle-cron.ts (LC4):** Call `demoteOnSuspend` when `nextState` returns
`'suspended'`. Call `restoreOnResume` when `event === 'admin_restore'`.

Exit criterion: unit tests for both functions with mock TypeDB (same pattern as
`plan-downgrade.test.ts`); LC4 integration test verifies calls fire on correct transitions.

- [ ] **GA2** · `haiku` · w1[ ] w2[ ] w3[ ] w4[ ]

---

### GA3 — seat-limit enforcement at `invite_member` · `haiku`

**File:** `src/pages/api/identity/invite.ts` (or wherever `invite_member` action lands)

Before writing the TypeDB `membership` row, check:

```ts
const limits = getPlanLimits(plan as Plan)
if (limits.maxSeats > 0) {
  const count = await currentSeatCount(env, orgGid)  // SELECT COUNT(*) FROM memberships
  if (count >= limits.maxSeats) {
    return Response.json(
      { error: 'seat_limit_reached', max: limits.maxSeats, upgrade_to: 'agency' },
      { status: 402 }
    )
  }
}
```

`currentSeatCount` queries TypeDB: `match $m (group: $g, member: $a) isa membership; $g has gid "${orgGid}"; get $a; count;`

Return 402 (not 403) — this is a billing limit, not an auth limit. UI shows
an upgrade CTA when 402 arrives with `error: 'seat_limit_reached'`.

Exit criterion: integration test — create workspace on `starter` plan, invite 5
members (all succeed), invite 6th (returns 402 with seat_limit_reached). Upgrade
to `agency`, invite 6th again (succeeds).

- [ ] **GA3** · `haiku` · w1[ ] w2[ ] w3[ ] w4[ ]

---

### GA4 — `read_revenue` workspace scope in auditor route · `haiku`

**File:** whichever route serves revenue data to the `auditor` role (likely
`src/pages/api/billing/revenue.ts` or the Ledger endpoint)

Add a workspace scope check before returning revenue data:

```ts
// Auditor can read revenue for their own workspace only.
// Owner (staffRole) can read platform-wide.
const viewer = ctx.locals.workspaceContext.viewer
if (viewer !== 'owner' && slug !== ctx.locals.slug) {
  return Response.json({ error: 'scope_violation' }, { status: 403 })
}
```

The `auditor` role already has `read_revenue` in `PERMISSIONS` — this adds the
workspace scope guard that the role matrix doesn't enforce by itself.

Exit criterion: test with auditor session on workspace A trying to read revenue
for workspace B → 403. Same auditor on workspace A reading workspace A → 200.

- [ ] **GA4** · `haiku` · w1[ ] w2[ ] w3[ ] w4[ ]

---

### GA5 — billing-state role guard in middleware / requireAuth · `sonnet`

**Files:** `src/middleware.ts` or `src/lib/api-auth.ts`

When `billing_state ∈ {over_limit, floored}`, gate write-verb actions for roles
below `admin`. Add after the owner-bypass check, before the PERMISSIONS matrix:

```ts
// billing-state write gate
const bs = ctx.locals.workspaceContext?.billing_state
if (bs === 'over_limit' || bs === 'floored') {
  const role = ctx.locals.workspaceContext?.role
  if (role !== 'owner' && role !== 'admin' && !SELF_ACTIONS.has(action)) {
    // Allow reads through; block writes
    const isWrite = WRITE_ACTIONS.has(action)   // new set: mark, warn, chat_write, etc.
    if (isWrite) return { allowed: false, reason: 'billing_over_limit' }
  }
}
```

`WRITE_ACTIONS` set: `mark`, `warn`, `chat_write`, `add_unit`, `remove_unit`,
`invite_member`, `change_role`, `add_attribute`, `vault_sync`, `mcp_register`.
Read actions (`chat_read`, `read_highways`, `read_memory`, `discover`, `view_onchain`,
`read_revenue`, `read_toxic`, `read_self`) always pass.

`suspended` state: block ALL actions for non-owner roles (owner sees read-only archive).

Route handlers that return 402 due to billing-state emit `billing_over_limit` in the
response body so the UI can show the correct banner (not the generic auth denied).

Exit criterion: mock middleware test — workspace with `billing_state: 'over_limit'`,
`role: 'member'`, action `chat_write` → 402. Same workspace, `role: 'admin'`,
action `chat_write` → allowed. Same workspace, `role: 'member'`, action `chat_read` → allowed.

- [ ] **GA5** · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

---

## Item details (compact)

### Migrations

```sql
-- M1: 0016_credit_grants.sql
CREATE TABLE credit_grants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  workspace TEXT NOT NULL,
  source TEXT NOT NULL,                      -- subscription|topup|sponsorship|promo|refund|payout
  amount_credits INTEGER NOT NULL,
  cents_paid INTEGER,
  parent TEXT,
  expires_at INTEGER,                        -- FIFO burns first
  rail TEXT,                                 -- stripe|x402|internal|test
  rail_ref TEXT,                             -- stripe event.id, x402 receipt, transfer id
  test_mode INTEGER NOT NULL DEFAULT 0,
  ts INTEGER DEFAULT (unixepoch())
);
CREATE INDEX idx_grants_ws ON credit_grants(workspace, ts);
CREATE INDEX idx_grants_exp ON credit_grants(workspace, expires_at);

-- M2: 0017_credit_burns.sql
CREATE TABLE credit_burns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  workspace TEXT NOT NULL,
  reason TEXT NOT NULL,                      -- inference|agent_run|skill_call|tool_call|storage|voice|api|transfer|public_chat
  amount_credits INTEGER NOT NULL,
  cost_credits INTEGER NOT NULL,             -- includes upstream + protocol fee
  agency_margin INTEGER NOT NULL DEFAULT 0,
  platform_margin INTEGER NOT NULL,
  recipient_share INTEGER NOT NULL DEFAULT 0,
  recipient TEXT,                            -- author workspace slug
  model TEXT,
  test_mode INTEGER NOT NULL DEFAULT 0,
  ts INTEGER DEFAULT (unixepoch())
);
CREATE INDEX idx_burns_ws ON credit_burns(workspace, ts);
CREATE INDEX idx_burns_reason ON credit_burns(reason, ts);
-- Constraint amount = cost + agency + platform + recipient enforced in debitPool() pre-INSERT

-- M3: 0018_billing_state.sql
ALTER TABLE owners ADD COLUMN billing_state TEXT NOT NULL DEFAULT 'live';
ALTER TABLE owners ADD COLUMN billing_state_since INTEGER DEFAULT (unixepoch());

-- M4: 0019_stripe_events.sql
CREATE TABLE stripe_events (
  id TEXT PRIMARY KEY,                       -- evt_xxx
  type TEXT NOT NULL,
  processed_at INTEGER DEFAULT (unixepoch())
);

-- M5: 0020_x402_agency_usd.sql
ALTER TABLE x402_payments ADD COLUMN agency_usd REAL NOT NULL DEFAULT 0;
ALTER TABLE x402_payments ADD COLUMN agency_slug TEXT;

-- M6: 0021_billing_anchor.sql
ALTER TABLE owners ADD COLUMN billing_anchor_day INTEGER;          -- 1-28
ALTER TABLE owners ADD COLUMN display_currency TEXT;               -- ISO 4217; null = USD
```

### L1 — billing.ts contract

```ts
// src/lib/billing.ts
export type Grant = { /* per billing.md §2 */ }
export type Burn  = { /* per billing.md §2 */ }

export const toCredits = (usd: number, rate = currentRate()): number => Math.round(usd / rate)

export async function computeBurn(p: {
  upstream: number; workspace: string; parent?: string
  reason: Burn['reason']; model?: string; recipient?: string
}): Promise<Burn>

export async function debitPool(b: Burn, env: Env):
  Promise<{ ok: true } | { ok: false, reason: '402' | 'floored' }>
// FIFO: ORDER BY (expires_at IS NULL), expires_at ASC
// Atomic: single D1 batch. Reject if amount != cost + margins + recipient.
// Floor: reject if (current - amount) < -plan.grant

export async function creditPool(g: Grant, env: Env): Promise<void>
export async function currentBalance(workspace: string, env: Env): Promise<number>
```

### L2 — billing-config.ts contract

```ts
// src/lib/billing-config.ts
export function parseBilling(md: string): Partial<BillingConfig>      // YAML frontmatter → typed
export function mergeBilling(layers: Partial<BillingConfig>[]): BillingConfig

// 6-line policy engine — billing.md §3:
const mergeCap    = (p?: number, c?: number) => Math.min(p ?? Infinity, c ?? Infinity)
const mergeMarkup = (p?: number, c?: number) => Math.max(p ?? 0, c ?? 0)
const mergeGate   = (p: G, c: G | undefined, locked: boolean) => locked ? p : (c ?? p)
const floorMargin = (m: number, floor: number) => Math.max(m, floor)
```

### L5 — revenue-split.ts contract

```ts
// src/lib/revenue-split.ts (extend existing)
export function computeSplit(amountCents: number, parentSlug?: string): {
  creatorAmount: number; agencyAmount: number   // 0 if no parent
  platformAmount: number; protocolAmount: number
}
// Default: 75/10/10/5 with parent; 85/10/0/5 without.
// Floor: clamp platformAmount up to amount × platform_floor_pct / 100;
//        deduct from agency first then creator. Emit warn if creator < 50%.
```

### W1 — webhook idempotency contract

```ts
// src/pages/api/pay/webhook.ts (extend)
const ins = await env.DB.prepare(
  'INSERT OR IGNORE INTO stripe_events (id, type) VALUES (?, ?)'
).bind(event.id, event.type).run()
if (ins.meta.changes === 0) return Response.json({ ok: true, deduped: true })

// Then dispatch by event.type → write to credit_grants:
// invoice.paid       → grant {source:'subscription', amount:plan.grant, expires_at:period_end}
//                      + sticky owners.billing_anchor_day if null
// charge.refunded    → grant {source:'refund', amount:-refunded_cents/rate}
// invoice.payment_failed → owners.billing_state := 'recovering' (LC2)
// charge.dispute.created → flag + freeze writes (PaymentFailureBanner reads flag)
```

### B1 — chat.ts inference burn contract

```ts
// src/pages/api/chat.ts (extend)
const upstream = await callLLM(model, messages)
const burn = await computeBurn({
  upstream: toCredits(upstream),
  workspace: ctx.locals.workspaceContext.slug,
  parent: ctx.locals.workspaceContext.parentWorkspace,
  reason: 'inference', model
})
const r = await debitPool(burn, env)
if (!r.ok) throw new HttpError(402, r.reason)
```

### B2 — public chatbot anonymous burn contract

```ts
// src/pages/api/chat.ts (anonymous branch) + src/pages/api/showcase-chat.ts
if (!ctx.locals.session) {
  const slug = ctx.locals.workspaceContext.slug      // who hosts this chatbot
  const gates = ctx.locals.workspaceContext.gates
  if (gates.public_chat === 'off') return new Response('public chat disabled', { status: 403 })

  // IP rate-limit (KV)
  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown'
  const rlKey = `chat-rl:${ip}:${slug}`
  const used = parseInt((await env.KV.get(rlKey)) ?? '0', 10)
  const cap = gates.public_chat === 'metered' ? 5 : 60   // /min
  if (used >= cap) return new Response('rate limited', { status: 429 })
  await env.KV.put(rlKey, String(used + 1), { expirationTtl: 60 })

  // Burn from slug-owner pool
  const burn = await computeBurn({
    upstream, workspace: slug, parent: ctx.locals.workspaceContext.parentWorkspace,
    reason: 'public_chat', model
  })
  const r = await debitPool(burn, env)
  if (!r.ok) return new Response('host pool empty', { status: 402 })
}
```

`public_chat` gate added to `FeatureKey` (L3) and `metered` defaults (L4).

### G1 — Layout brand_removal contract

```astro
{ gates.brand_removal === 'on'
  || (gates.brand_removal === 'metered' && balance >= 30 && (await debitOnceUtcDay({ reason: 'brand_removal_per_day', amount: 30 })))
  ? null
  : <Attribution /> }
```

### LC1 — state machine contract

```ts
// src/lib/billing-state.ts — pure function, fully unit-tested
type State  = 'live'|'recovering'|'over_limit'|'floored'|'suspended'|'archived'
type Event  =
  | { kind:'balance_change'; balance:number; planGrant:number }
  | { kind:'retry_failed_3x' } | { kind:'top_up_succeeded' }
  | { kind:'upgrade_paid'; deltaCredits:number; planGrant:number }
  | { kind:'cron_30d_expired' } | { kind:'cron_90d_expired' }

export function nextState(s: State, e: Event): State
// Transitions per billing.md §9. ~30 cases; each tested.
```

### Cron triggers (wrangler.toml)

```toml
[[triggers.crons]]
schedule = "0 * * * *"             # hourly — auto-top-up (C1)
[[triggers.crons]]
schedule = "0 0 * * *"             # daily 00:00 UTC — allocations + alerts + lifecycle + verify
                                   # (A2, C2, LC4, V1) — single worker, branches by check
```

### `_platform/billing.md` (L4 default)

```yaml
rate_usd_per_credit: 0.0001
platform_margin_pct: 10
platform_floor_pct:  5
billing_anchor: monthly
tax: stripe
plans:
  free:     { grant: 1_000,     gates: { brand_removal: off,  public_chat: metered, premium_models: off } }
  starter:  { grant: 50_000,    gates: { brand_removal: on,   public_chat: metered, premium_models: metered } }
  pro:      { grant: 500_000,   gates: { brand_removal: on,   public_chat: on,      premium_models: on } }
  agency:   { grant: 5_000_000, gates: { brand_removal: on,   public_chat: on,      premium_models: on, sub_workspace_create: on, white_label_cascade: on } }
models:
  claude-haiku-4-5:  { upstream_per_1k_in: 25,   output_mult: 5  }
  claude-opus-4-7:   { upstream_per_1k_in: 1500, output_mult: 5  }
  gpt-5:             { upstream_per_1k_in: 1250, output_mult: 8  }
metered:
  brand_removal_per_day: 30
  voice_per_minute_in:    8
  voice_per_minute_out:  12
  agent_run_base:        10
  skill_call_base:        5
  storage_per_gb_hour:    1
  api_overage_per_request: 0.1
  export_per_archive:    100
  public_chat_per_msg:    1            # metered public-chatbot per-visitor-message
```

---

## Removed imaginary blockers (what I'm explicitly NOT gating on)

| Was blocked by | Now | Reason |
|---|---|---|
| L1 needed M1/M2 to land | parallel | Schema is in spec; code writes against types, deploy needs migration but writing doesn't |
| L2 mergeBilling needed L1 | parallel | Independent file, only shares types from L3 |
| L5 needed M5 | parallel | Same — column add doesn't gate writing the split fn |
| W1/W2/W3 each separate | folded into W1 | Same file `webhook.ts`; one agent owns the dispatch |
| B3 FIFO, B4 model lookup, B5 protocol fee | folded into L1 | Same file `billing.ts`; one agent |
| O0 owner editor + O2/O3/O4 | folded into O2 | Same file `_platform/billing.astro`; one editor |
| LC4 + LC5 separate crons | folded into LC4 | Same cron worker, branched by date check |
| V1 + V2 + V3 | folded into V1+V2 | V1 = production cron, V2 = test runner; both small |
| PS1 + PS2 | folded into PS1 | Tiny surface; one agent |
| A1 + A2 + A4 | folded into A1 | All allocations API + UI shipped together |
| C2 + C3 | folded into C2 | Email templates inline with cron |
| External X1 blocking X3 | unblocked | X3 (cross-chain claim) ships today via existing `x402_claim` |
| External X5 (Sui USDC Wave 1) | deferred | Not needed; X3 covers Sui authors today |

---

## Deferred (later cycles, not in this build)

- Stripe Connect Express (we chose crypto-native via x402 send)
- Sui mainnet cutover (config swap, not a billing concern)
- TypeDB persistence of billing paths (D1 is enough for Cycle 1)
- Multi-region pricing (single-region today)
- Volume discount tiers (out-of-band negotiation)
- USDC-on-Sui Coin verifier (X5 — Wave 1 in apps/one-core)
- Alternative tax modes beyond Stripe Tax (manual VAT remitting handled by `tax: manual` flag)

---

## Close

```
/close --item <id>                 # mark pheromone for that item only
/close --todo billing --cycle 1    # hard gate — appends one entry to learnings.md
```

Per-item rubric (security / stability / simplicity / speed) scored at item close. Below 0.65 re-enters its own W3 (max 3 loops) — does not block siblings.

**Cycle exit:** V2 replay test passes (Σbalance delta < 1 cr across full DB) AND B1 returns 402 within 50ms p95 on synthetic empty-pool AND LC5 emits a substrate signal on every observed transition in 24h soak.

*One TODO. Seven waves. 11+5+9+7+5+5+3+5 = 50 items. No imaginary blockers. Both rails write the same rows. Public chatbots burn from the host's pool. Orgs are agencies with markup zero. Wave 7 closes the billing × roles gaps: actor attribution, seat enforcement, suspension demotion, revenue scope, billing-state write gate.*
