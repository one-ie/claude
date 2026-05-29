# billing-software.md — Build on the Best, Fill the Gaps

**What this doc is:** a synthesis of four production billing systems (Flexprice, OpenMeter, Lago, CoAI)
mapped against ONE's existing billing primitives. It produces a phased build plan that copies and adapts
the best code from each reference app rather than rebuilding from scratch.

**What already exists (do not rebuild):** see `billing-costs-implementation.md` — ONE has a working
ledger, cascade, 4-way split, credit grants/burns, lifecycle states, Stripe + x402 rails, and a UI
shell. The gaps are specific and closeable.

---

## Reference App Map

| App | Language | Strongest contribution | Copy strategy |
|-----|----------|----------------------|---------------|
| **Flexprice** | Go / Ent ORM | Complete invoice lifecycle, tiered pricing, commitments, proration, credit wallets, entitlements | Port schemas → D1 + TypeDB; port algorithms → `billing.ts` |
| **OpenMeter** | Go / Ent ORM | CloudEvents ingestion, real-time meter aggregation, entitlement balance enforcement | Adapt meter model to ONE signal events; borrow enforcement middleware |
| **Lago** | Go (events-processor) | Subscription-aware event routing, charge filter cache, high-throughput event fan-out | Borrow event routing patterns for `channels/` tool-call capture |
| **CoAI** | Go | Quota increment/decrement atomics, per-user usage tracking, multi-model surcharge tables | Direct port of quota SQL patterns to D1 credit_grants/burns atomics |

---

## What ONE Has vs What Each App Adds

### Already solid in ONE
- `credit_grants` + `credit_burns` D1 tables — the one ledger
- `computeBurn()` — pure 4-way cost split (upstream / agency / platform / recipient)
- `debitPool()` — atomic debit with cascade, cap enforcement, 402 on empty
- `owners.parent_slug` — arbitrary-depth tenant tree (agency → client → team)
- 6-layer cascade (`mergeCap` / `mergeMarkup` / `mergeGate`)
- Billing lifecycle states: `live → recovering → over_limit → floored → suspended → archived`
- Stripe + x402 payment rails, both idempotent
- `/billing` UI shell with Pool card, Ledger, Allocations pages

### Gaps and which app closes them

| Gap | Consequence | Closes via |
|-----|-------------|-----------|
| **G1** Static model rates in `billing-config.ts` | Every burn mispriced (Opus 1500cr vs 50cr actual) | OpenRouter KV cron (already planned C1) |
| **G2** Agent runtime (`channels/`) never writes burns | All Telegram/Discord inference invisible | Lago event-routing pattern + CoAI atomic quota write |
| **G3** `tool_call` burn reason never fired | Tool costs unattributed | Lago charge filter cache adapted to `aitools.ts` |
| **G4** Rollup is one level — teams invisible to agency | Agency can't see team costs | Flexprice recursive subtree CTE (already designed C4) |
| **G5** No cost UI for four audiences | Owner/agency/client blind to true spend | Flexprice `<CostTree>` pattern |
| **G6** No invoice line items — burns are flat | Can't itemize a period's charges | Flexprice `InvoiceLineItem` model |
| **G7** No entitlement balance tracking | Gates are on/off; no "100 calls/month" limits | OpenMeter entitlement balance + reset period |
| **G8** No proration on mid-period plan changes | Upgrade/downgrade credit math is manual | Flexprice `LineItemProrationService` algorithm |
| **G9** No credit expiry FIFO enforcement in code | Promo credits never expire in practice | Flexprice wallet burn-down priority sort |
| **G10** No tiered pricing (per-model overrides by workspace) | Every workspace pays same rate | Flexprice `pricing-tier` per-workspace table |
| **G11** No idempotency key on invoice finalize | Risk of double-invoice on Stripe retry | Flexprice invoice sequence + idempotency key |
| **G12** No agency plan template builder | Agency can't define custom pricing bundles | Flexprice Plan + Price model + `billing-taxonomy.md §0071` |

---

## Copyable Code: What to Port, File by File

### From Flexprice

#### `ent/schema/meter.go` → D1 `meters` table + TypeDB `meter` entity

**Port the `MeterAggregation` struct verbatim as a TypeScript type:**

```typescript
// src/lib/billing/meter.ts
export type AggregationType = 'sum' | 'count' | 'avg' | 'min' | 'max' | 'unique_count'
export type ResetUsage = 'billing_period' | 'calendar_month' | 'calendar_year' | 'never'

export interface MeterAggregation {
  type: AggregationType
  field?: string          // event.properties key to aggregate
  expression?: string     // CEL expression — replaces field (e.g. "tokens * duration")
  multiplier?: number
  bucket_size?: 'HOUR' | 'DAY' | 'WEEK' | 'MONTH'
  group_by?: string       // e.g. "model" → per-model tiering
}

export interface MeterFilter {
  key: string
  values: string[]
}

export interface Meter {
  mid: string
  event_name: string      // matches signal.reason or tool name
  name: string
  aggregation: MeterAggregation
  filters: MeterFilter[]
  reset_usage: ResetUsage
  workspace: string       // tenant scope
}
```

**D1 table:**

```sql
-- migration: 00NN_meters.sql
CREATE TABLE IF NOT EXISTS meters (
  mid          TEXT PRIMARY KEY,
  workspace    TEXT NOT NULL,
  event_name   TEXT NOT NULL,
  name         TEXT NOT NULL,
  aggregation  TEXT NOT NULL,  -- JSON: MeterAggregation
  filters      TEXT NOT NULL DEFAULT '[]',
  reset_usage  TEXT NOT NULL DEFAULT 'billing_period',
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
);
CREATE INDEX idx_meters_workspace ON meters(workspace);
```

---

#### `internal/service/billing.go` → extend `src/lib/billing.ts`

**Port `calculateBucketedMeterCost` algorithm:**

```typescript
// src/lib/billing/tiered.ts
export interface PriceTier {
  min_qty: number
  max_qty: number | null   // null = unlimited
  unit_price: number       // in credits
}

export function calculateTieredCost(usage: number, tiers: PriceTier[]): number {
  let total = 0
  for (const tier of tiers) {
    if (usage <= 0) break
    const max = tier.max_qty ?? Infinity
    const bucket = Math.min(usage, max - tier.min_qty)
    if (bucket <= 0) continue
    total += bucket * tier.unit_price
    usage -= bucket
  }
  return Math.ceil(total)
}

// Per-group tiering (Flexprice bucketedMeterCost pattern)
// When group_by is set, apply tiers per unique group, then sum
export function calculateGroupedTieredCost(
  groups: Record<string, number>,  // { "claude-opus": 5000, "haiku": 20000 }
  tiers: PriceTier[]
): number {
  return Object.values(groups).reduce((sum, usage) => sum + calculateTieredCost(usage, tiers), 0)
}
```

**Port invoice invariant check:**

```typescript
// src/lib/billing.ts — add to computeBurn
function assertBurnInvariant(burn: Burn): void {
  const sum = burn.cost_credits + (burn.agency_margin ?? 0) + burn.platform_margin + (burn.recipient_share ?? 0)
  if (Math.abs(sum - burn.amount_credits) > 1) {
    throw new Error(`burn invariant violated: ${burn.amount_credits} ≠ ${sum}`)
  }
}
```

---

#### `ent/schema/subscription.go` → extend `owners` table + D1

**Key fields to add from Flexprice subscription schema:**

```sql
-- migration: 00NN_subscription_fields.sql
ALTER TABLE owners ADD COLUMN billing_anchor     TEXT;        -- 'anniversary' | 'calendar'
ALTER TABLE owners ADD COLUMN billing_cadence    TEXT DEFAULT 'monthly';
ALTER TABLE owners ADD COLUMN billing_period     TEXT DEFAULT 'month';
ALTER TABLE owners ADD COLUMN trial_start        INTEGER;
ALTER TABLE owners ADD COLUMN trial_end          INTEGER;
ALTER TABLE owners ADD COLUMN cancel_at          INTEGER;     -- scheduled cancellation
ALTER TABLE owners ADD COLUMN cancel_at_period_end INTEGER DEFAULT 0;
ALTER TABLE owners ADD COLUMN pause_status       TEXT DEFAULT 'none';
ALTER TABLE owners ADD COLUMN collection_method  TEXT DEFAULT 'charge_automatically';
ALTER TABLE owners ADD COLUMN net_terms_days     INTEGER DEFAULT 0;
```

**Key insight from Flexprice:** `billing_anchor` (when the billing period resets) is the most important
field for proration correctness — without it, upgrade credits are ambiguous.

---

#### `ent/schema/creditgrant.go` → extend `credit_grants` D1 table

**Port credit expiry FIFO from Flexprice `WalletTransaction` burn-down:**

```sql
-- migration: 00NN_grant_expiry.sql
ALTER TABLE credit_grants ADD COLUMN expires_at  INTEGER;   -- unix ms; null = never
ALTER TABLE credit_grants ADD COLUMN priority     INTEGER DEFAULT 0;  -- lower = burns first
ALTER TABLE credit_grants ADD COLUMN conversion_rate REAL DEFAULT 0.0001;  -- USD per credit at grant time
ALTER TABLE credit_grants ADD COLUMN topup_conversion_rate REAL;  -- for prepaid topups vs promo
```

**Port the wallet burn-down sort (Flexprice wallet transaction priority):**

```typescript
// src/lib/billing.ts — replace naive FIFO with Flexprice priority sort
function sortGrantsForBurnDown(grants: CreditGrant[]): CreditGrant[] {
  return grants.sort((a, b) => {
    // Expiring credits burn first (soonest expiry first)
    if (a.expires_at && b.expires_at) return a.expires_at - b.expires_at
    if (a.expires_at) return -1
    if (b.expires_at) return 1
    // Within same expiry, lower priority number burns first
    return (a.priority ?? 0) - (b.priority ?? 0)
  })
}
```

---

#### `ent/schema/invoice.go` → new D1 `invoices` table

**Flexprice invoice lifecycle is exactly what ONE needs:**

```sql
-- migration: 00NN_invoices.sql
CREATE TABLE IF NOT EXISTS invoices (
  iid              TEXT PRIMARY KEY,
  workspace        TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'draft',  -- draft | finalized | paid | void | uncollectible
  payment_status   TEXT NOT NULL DEFAULT 'pending', -- pending | succeeded | failed
  currency         TEXT NOT NULL DEFAULT 'usd',
  amount_credits   INTEGER NOT NULL DEFAULT 0,    -- gross charge
  amount_paid      INTEGER DEFAULT 0,
  amount_due       INTEGER DEFAULT 0,
  credits_applied  INTEGER DEFAULT 0,             -- prepaid credits deducted
  coupons_applied  INTEGER DEFAULT 0,
  tax_credits      INTEGER DEFAULT 0,
  idempotency_key  TEXT UNIQUE,                   -- Stripe event.id / x402 receipt
  billing_sequence INTEGER,                       -- invoice number (assigned at finalize only)
  period_start     INTEGER NOT NULL,
  period_end       INTEGER NOT NULL,
  invoice_date     INTEGER,                       -- null until finalized
  due_date         INTEGER,
  metadata         TEXT DEFAULT '{}',
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL
);
CREATE INDEX idx_invoices_workspace ON invoices(workspace, period_start);
CREATE INDEX idx_invoices_idem ON invoices(idempotency_key);

-- Invoice line items (Flexprice InvoiceLineItem pattern)
CREATE TABLE IF NOT EXISTS invoice_line_items (
  lid              TEXT PRIMARY KEY,
  iid              TEXT NOT NULL REFERENCES invoices(iid),
  workspace        TEXT NOT NULL,
  reason           TEXT NOT NULL,   -- 'inference' | 'tool_call' | 'voice' | 'storage' | etc.
  model            TEXT,
  quantity         REAL NOT NULL DEFAULT 1,
  unit_credits     INTEGER NOT NULL,
  amount_credits   INTEGER NOT NULL,
  credits_applied  INTEGER DEFAULT 0,
  period_start     INTEGER NOT NULL,
  period_end       INTEGER NOT NULL,
  metadata         TEXT DEFAULT '{}',
  created_at       INTEGER NOT NULL
);
CREATE INDEX idx_line_items_invoice ON invoice_line_items(iid);
```

**Invoice lifecycle state machine (ported from Flexprice):**

```typescript
// src/lib/billing/invoice.ts
type InvoiceStatus = 'draft' | 'finalized' | 'paid' | 'void' | 'uncollectible'
type PaymentStatus = 'pending' | 'succeeded' | 'failed'

async function createDraftInvoice(workspace: string, period: Period, env: Env): Promise<Invoice> {
  const iid = `inv_${nanoid()}`
  const idempotencyKey = `${workspace}:${period.start}:${period.end}`
  // Insert-or-ignore: replay safe
  await env.ONE_DB.prepare(
    `INSERT OR IGNORE INTO invoices (iid, workspace, status, period_start, period_end, idempotency_key, created_at, updated_at)
     VALUES (?, ?, 'draft', ?, ?, ?, ?, ?)`
  ).bind(iid, workspace, period.start, period.end, idempotencyKey, Date.now(), Date.now()).run()
  return getInvoice(iid, env)
}

async function computeInvoice(iid: string, env: Env): Promise<void> {
  // Aggregate credit_burns for the period → create line items → apply credits
  // Invoice number NOT assigned here (Flexprice pattern: only finalize assigns sequence)
}

async function finalizeInvoice(iid: string, env: Env): Promise<void> {
  const seq = await nextBillingSequence(env)
  await env.ONE_DB.prepare(
    `UPDATE invoices SET status = 'finalized', billing_sequence = ?, invoice_date = ?, updated_at = ?
     WHERE iid = ? AND status = 'draft'`
  ).bind(seq, Date.now(), Date.now(), iid).run()
}
```

---

#### `ent/schema/entitlement.go` + `ent/schema/feature.go` → D1 `entitlements` table

**Port OpenMeter's entitlement balance tracking for per-feature usage limits:**

```sql
-- migration: 00NN_entitlements.sql
CREATE TABLE IF NOT EXISTS entitlements (
  eid              TEXT PRIMARY KEY,
  workspace        TEXT NOT NULL,
  feature          TEXT NOT NULL,     -- e.g. 'api_access', 'agent_create', 'webhooks'
  plan_source      TEXT NOT NULL,     -- plan name that granted this
  is_enabled       INTEGER NOT NULL DEFAULT 1,
  usage_limit      INTEGER,           -- null = unlimited
  usage_reset      TEXT DEFAULT 'billing_period',  -- daily | monthly | billing_period
  is_soft_limit    INTEGER DEFAULT 0, -- 0 = hard block; 1 = warn only
  used             INTEGER DEFAULT 0, -- current period usage
  period_end       INTEGER,           -- when used resets
  created_at       INTEGER NOT NULL
);
CREATE UNIQUE INDEX idx_ent_workspace_feature ON entitlements(workspace, feature);
```

**Enforcement middleware (OpenMeter pattern):**

```typescript
// src/middleware/entitlement.ts
export async function checkEntitlement(
  workspace: string,
  feature: string,
  increment: number,
  env: Env
): Promise<{ allowed: boolean; remaining: number | null }> {
  const ent = await env.ONE_DB.prepare(
    `SELECT usage_limit, used, is_soft_limit FROM entitlements WHERE workspace = ? AND feature = ?`
  ).bind(workspace, feature).first<Entitlement>()
  if (!ent) return { allowed: true, remaining: null }   // no limit set = unlimited
  if (!ent.usage_limit) return { allowed: true, remaining: null }
  const remaining = ent.usage_limit - ent.used
  if (remaining < increment) {
    if (ent.is_soft_limit) return { allowed: true, remaining: 0 }   // warn, don't block
    return { allowed: false, remaining: 0 }
  }
  return { allowed: true, remaining: remaining - increment }
}

export async function recordEntitlementUsage(workspace: string, feature: string, used: number, env: Env): Promise<void> {
  await env.ONE_DB.prepare(
    `UPDATE entitlements SET used = used + ? WHERE workspace = ? AND feature = ?`
  ).bind(used, workspace, feature).run()
}
```

---

### From CoAI

#### `auth/quota.go` → atomic increment pattern for `credit_burns`

CoAI's `UseQuota` pattern (decrement + increment in one SQL) maps directly to ONE's debit atomics.
**Port the `ON DUPLICATE KEY UPDATE` atomic pattern to D1's `ON CONFLICT` equivalent:**

```typescript
// src/lib/billing.ts — atomic credit debit (CoAI UseQuota pattern)
async function atomicDebit(workspace: string, amount: number, env: Env): Promise<boolean> {
  const result = await env.ONE_DB.prepare(`
    UPDATE credit_pools
    SET balance = balance - ?
    WHERE workspace = ? AND balance >= ?
  `).bind(amount, workspace, amount).run()
  return result.meta.changes > 0  // 0 changes = insufficient balance → reject
}
```

CoAI's `PayedQuotaAsAmount` multiply-by-10 pattern also mirrors ONE's credit-to-USD conversion
(`amount_credits = cents / 0.01` → same shape).

---

### From Lago (events-processor)

#### `cache/charges.go` + `cache/subscriptions.go` → tool-call routing in `channels/aitools.ts`

Lago's event processor caches `billable_metrics → charges → subscriptions` in memory for fast
fan-out without DB hits on every event. For ONE's `aitools.ts`:

```typescript
// channels/src/billing-cache.ts — Lago charge cache pattern
// Warm at worker startup; refresh every 5 minutes via DO alarm

interface ToolBillingConfig {
  tool: string               // tool name → maps to Lago's billable_metric
  cost_per_call: number      // credits; 0 for substrate verbs
  meter_event?: string       // if tool maps to a meter: fire event too
}

// Cached in KV: 'billing:tools:v1'
const DEFAULT_TOOL_COSTS: ToolBillingConfig[] = [
  { tool: 'composio_*',       cost_per_call: 5  },  // dynamic: see billing-costs.md §Composio
  { tool: 'signal',           cost_per_call: 0  },  // substrate verb — no upstream cost
  { tool: 'mark',             cost_per_call: 0  },
  { tool: 'warn',             cost_per_call: 0  },
  { tool: 'web_search',       cost_per_call: 2  },
  { tool: 'code_interpreter', cost_per_call: 10 },
]
```

---

### From OpenMeter

#### Meter query endpoint pattern

OpenMeter's `/api/v1/meters/:id/query` — time-windowed aggregation over stored events — is the
pattern for ONE's `/api/billing/meters/:mid/query`:

```typescript
// src/pages/api/billing/meters/[mid]/query.ts
// Returns aggregated usage for a meter over a time window
// Backed by D1 SELECT with GROUP BY window (15-min, hourly, daily)
export interface MeterQueryRequest {
  workspace: string
  from: number    // unix ms
  to: number      // unix ms
  window: 'MINUTE' | 'HOUR' | 'DAY'
  group_by?: string
}

export interface MeterQueryResult {
  window_start: number
  window_end: number
  value: number
  group?: string
}
```

---

## Phased Build Plan

### Phase 0 — Foundation (already designed in billing-costs-implementation.md)

Close G1–G5 from `billing-costs-implementation.md`. These are pre-requisites for everything below.
Refer to that doc for cycle-by-cycle detail (C1–C5). Status: cycles C1, C2, C4 shipped; C3, C5 in flight.

---

### Phase 1 — Invoice Engine (closes G6, G11)

**Goal:** every billing period produces a real invoice with line items, not just a pool card.

**S1.1 — D1: add `invoices` + `invoice_line_items` tables** (migration above)
- File: `one.ie/web/migrations/00NN_invoices.sql`
- Idempotency key = `{workspace}:{period_start}:{period_end}` prevents double-invoice on webhook retry

**S1.2 — Port Flexprice invoice lifecycle to `src/lib/billing/invoice.ts`**
- `createDraftInvoice()` — insert-or-ignore (idempotent)
- `computeInvoice()` — aggregate `credit_burns` → `invoice_line_items`; apply sorted grants (FIFO expiry)
- `finalizeInvoice()` — assign `billing_sequence`; trigger Stripe invoice or x402 receipt
- State machine: draft → finalized → paid | void

**S1.3 — Cron: `sync/billing-invoice-cron.ts`**
- Fires on billing anchor date per workspace
- Creates + computes + finalizes invoice
- Emits `signal('billing:invoice_finalized')` (Rule 1: closed loop)

**Verification:** replay 30 days of `credit_burns`; assert every workspace has exactly one invoice per
period; `Σ invoice.amount_credits = Σ credit_burns.amount_credits` for that workspace+period.

---

### Phase 2 — Proration + Credit Expiry (closes G8, G9)

**Goal:** mid-period plan changes produce correct credits; promo grants actually expire.

**S2.1 — Port Flexprice proration algorithm to `src/lib/billing/proration.ts`**

```typescript
// Flexprice LineItemProrationService pattern
export function calculateProration(params: {
  changeDate: number       // unix ms — when the plan change happens
  periodStart: number
  periodEnd: number
  oldAmount: number        // credits/period on old plan
  newAmount: number        // credits/period on new plan
}): { creditBack: number; chargeForward: number } {
  const totalDays = (params.periodEnd - params.periodStart) / 86_400_000
  const daysRemaining = (params.periodEnd - params.changeDate) / 86_400_000
  const daysUsed = totalDays - daysRemaining

  const creditBack = Math.floor((daysRemaining / totalDays) * params.oldAmount)
  const chargeForward = Math.ceil((daysRemaining / totalDays) * params.newAmount)
  return { creditBack, chargeForward }
}
```

**S2.2 — Wire credit expiry FIFO into `debitPool()`**
- Add `expires_at` + `priority` columns to `credit_grants` (migration above)
- Replace naive SELECT in `debitPool` with `sortGrantsForBurnDown()` (Flexprice priority sort)
- Cron: `sync/credit-expiry-cron.ts` — marks expired grants as exhausted; emits signal

**Verification:** grant 1000cr expiring in 2 days + 5000cr non-expiring; burn 800cr; assert expiring
pool used first; advance clock past expiry; assert 200cr expired, 5000cr intact.

---

### Phase 3 — Entitlement Limits (closes G7)

**Goal:** "100 API calls/month" is enforced, not just a gate toggle.

**S3.1 — D1: add `entitlements` table** (migration above)
**S3.2 — Sync entitlements from plan on subscription change**
- When workspace changes plan, upsert `entitlements` rows from plan's feature matrix (`billing.md §6`)
- Reset `used = 0` on billing period rollover (cron)

**S3.3 — Wire `checkEntitlement()` into feature middleware**
- Add to `requireAuth` before gate check: `checkEntitlement(workspace, feature, 1, env)`
- On hard limit → 402 with `{ error: 'entitlement_exceeded', feature, limit, used }`
- On soft limit → proceed + emit `warn('billing:entitlement_warning')`

**S3.4 — UI: show per-feature usage in `/billing`**
- Add `<EntitlementBar>` to Pool card for metered features (API calls, webhooks, agents created)
- Same data source as `gates` — just adds `used / limit` progress

**Verification:** set workspace API entitlement to 5 calls; make 5 calls; 6th returns 402; `used = 5`
in D1; soft-limit variant: 6th call proceeds + emits warn signal.

---

### Phase 4 — Tiered Pricing (closes G10)

**Goal:** per-workspace, per-model pricing overrides (agency white-label pricing).

**S4.1 — D1: add `pricing_tiers` table**

```sql
-- migration: 00NN_pricing_tiers.sql
CREATE TABLE IF NOT EXISTS pricing_tiers (
  ptid           TEXT PRIMARY KEY,
  workspace      TEXT NOT NULL,         -- which workspace this applies to
  feature        TEXT NOT NULL,         -- 'inference' | 'tool_call' | 'voice_input' | etc.
  model          TEXT,                  -- null = applies to all models for this feature
  tiers          TEXT NOT NULL,         -- JSON: PriceTier[]
  currency       TEXT DEFAULT 'credits',
  valid_from     INTEGER NOT NULL,
  valid_until    INTEGER,               -- null = always valid
  created_at     INTEGER NOT NULL
);
CREATE UNIQUE INDEX idx_pt_workspace_feature_model ON pricing_tiers(workspace, feature, COALESCE(model, ''));
```

**S4.2 — Extend `rateFor()` to query workspace pricing tiers**
- Current: `rateFor(model, env)` → KV lookup → static fallback
- New: `rateFor(model, workspace, env)` → check `pricing_tiers` for workspace override → KV fallback → static fallback
- Flexprice pattern: tiered pricing is additive (per-tier brackets); flat rate is a single-tier table

**S4.3 — Agency plan template builder (billing-taxonomy.md §0071)**
- `GET /api/billing/plan-templates` — list templates for agency workspace
- `POST /api/billing/plan-templates` — create template (name + pricing_tiers overrides)
- `PUT /api/billing/plan-templates/:id/assign` — assign template to client workspace
- UI: `PlanTemplateEditor.tsx` (Shadcn form: plan name, feature rates, model overrides)

**Verification:** agency creates template with inference at 2× default; client workspace assigned
template; `rateFor('claude-opus', clientSlug, env)` returns 2× rate; `credit_burns.cost_credits`
reflects override.

---

### Phase 5 — Meter Aggregation (closes the CEL expression gap)

**Goal:** flexible usage meters for features beyond simple token counting.

**S5.1 — D1: add `meters` table** (migration above)
**S5.2 — `src/lib/billing/meter.ts` — meter evaluation engine**

```typescript
// Port from Flexprice MeterAggregation + OpenMeter meter event model
export async function evaluateMeter(mid: string, window: MeterQueryRequest, env: Env): Promise<MeterQueryResult[]> {
  const meter = await getMeter(mid, env)
  // For simple field meters: aggregate signal events in D1 by window
  // For expression meters: evaluate stored event.properties through expression parser
  // For group_by: partition by property, aggregate per group
}
```

**S5.3 — Wire meters to signal events**
- Each `signal()` call can optionally carry `{ meter: mid, properties: {...} }`
- `channels/` middleware: if signal has meter, call `evaluateMeter` + update entitlement `used`

**S5.4 — Meter query API**
- `GET /api/billing/meters/:mid/query?workspace=&from=&to=&window=`
- Returns `MeterQueryResult[]` for dashboards and external integrations

---

### Phase 6 — Agency Revenue Dashboard (closes G5 fully)

**Goal:** the owner and agencies see their actual economics in real time.

**S6.1 — Extend `<CostTree>` (billing-costs-implementation.md C5) with margin view**
- Per-row: tokens | COGS | billed | margin_earned
- Summary band: gross_revenue | COGS | gross_margin | net_margin (after platform floor)

**S6.2 — Revenue forecast widget**
- Based on current period burn rate → projected month-end
- Flexprice `costsheet.go` pattern: per-subscription cost projection

**S6.3 — Model cost breakdown**
- Owner sees COGS by model (which models are expensive vs. profitable)
- OpenRouter rate is the variable; agency markup is the lever

---

## TypeDB Schema Extensions

Add to `schema/world.tql` (or a new `billing.tql` file):

```tql
# Billing dimension extensions

entity meter,
    owns mid @key,
    owns mid @values(string),
    owns event-name,
    owns name,
    owns aggregation-config,   # JSON: MeterAggregation
    owns filter-config,        # JSON: MeterFilter[]
    owns reset-period,
    owns workspace-slug,
    plays metering:measured;

entity invoice,
    owns iid @key,
    owns workspace-slug,
    owns invoice-status,       # draft | finalized | paid | void
    owns payment-status,
    owns amount-credits,
    owns credits-applied,
    owns billing-sequence,
    owns idempotency-key,
    owns period-start,
    owns period-end,
    plays billing:invoiced;

entity entitlement,
    owns eid @key,
    owns workspace-slug,
    owns feature-name,
    owns usage-limit,
    owns used-credits,
    owns soft-limit,
    plays access:granted;

# Billing relations
relation metering,
    relates measured,        # meter
    relates event;           # signal

relation billing,
    relates invoiced,        # invoice
    relates workspace;       # group (workspace)

relation access,
    relates granted,         # entitlement
    relates workspace;       # group
```

**TypeDB powers the audit layer:** D1 handles hot-path reads/writes; TypeDB answers compliance questions
("what was this workspace entitled to on date X?", "show me every invoice for this agency subtree").

---

## Migration Sequence

Run in order; each is idempotent:

| # | File | What | Dependency |
|---|------|------|-----------|
| C1 | `00NN_burn_usage.sql` | `tokens_in/out`, `unit_count` on `credit_burns` | none (already planned) |
| C2 | `00NN_grant_expiry.sql` | `expires_at`, `priority`, `conversion_rate` on `credit_grants` | none |
| C3 | `00NN_subscription_fields.sql` | `billing_anchor`, trial dates, pause_status, collection_method on `owners` | none |
| C4 | `00NN_invoices.sql` | new `invoices` + `invoice_line_items` tables | C1 |
| C5 | `00NN_entitlements.sql` | new `entitlements` table | none |
| C6 | `00NN_meters.sql` | new `meters` table | none |
| C7 | `00NN_pricing_tiers.sql` | new `pricing_tiers` table | none |

---

## Phase 7 — Complete the Customer Experience

These six features were missing from Phases 1–6. They close the gap between "operational billing system" and "complete billing product."

---

### S7.1 — Invoice PDF download

Every finalized invoice gets a downloadable PDF. B2B clients expect this. It's also the proof document for their own accounting.

**Implementation:**
- Worker-rendered HTML template → `@react-pdf/renderer` or a lightweight HTML-to-PDF edge Worker
- Route: `GET /api/billing/invoices/:iid/pdf` → streams PDF bytes
- Template: workspace name, billing period, line items (reason + model + quantity + amount), credits applied, total, Stripe reference
- Linked from the Ledger UI ("Download invoice") next to each finalized invoice row

**D1 addition:**
```sql
ALTER TABLE invoices ADD COLUMN pdf_url TEXT;  -- R2 path after generation
ALTER TABLE invoices ADD COLUMN pdf_generated_at INTEGER;
```

**Verification:** `GET /api/billing/invoices/:iid/pdf` returns `Content-Type: application/pdf` with correct workspace + period in the metadata; invoice table shows `pdf_generated_at` set.

---

### S7.2 — Coupon / discount codes (Flexprice port)

Direct port of Flexprice's coupon engine — the simplest part of their schema — into ONE's credit model.

**D1 table:**
```sql
CREATE TABLE IF NOT EXISTS coupons (
  cid            TEXT PRIMARY KEY,
  workspace      TEXT NOT NULL,         -- issuing workspace (agency or platform)
  code           TEXT NOT NULL UNIQUE,
  name           TEXT NOT NULL,
  discount_type  TEXT NOT NULL,         -- 'percentage' | 'fixed_credits'
  discount_value REAL NOT NULL,         -- % or credits
  cadence        TEXT NOT NULL DEFAULT 'once',  -- 'once' | 'repeating' | 'forever'
  duration_months INTEGER,              -- for 'repeating'
  max_redemptions INTEGER,              -- null = unlimited
  redemptions    INTEGER DEFAULT 0,
  valid_from     INTEGER NOT NULL,
  valid_until    INTEGER,               -- null = no expiry
  created_at     INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS coupon_redemptions (
  rid            TEXT PRIMARY KEY,
  cid            TEXT NOT NULL REFERENCES coupons(cid),
  workspace      TEXT NOT NULL,         -- workspace that redeemed
  amount_off     INTEGER NOT NULL,      -- credits saved
  applied_at     INTEGER NOT NULL,
  invoice_id     TEXT                   -- which invoice it applied to
);
```

**API:**
- `POST /api/billing/coupons` — create coupon (agency/owner only)
- `POST /api/billing/coupons/redeem` — apply coupon code to subscription
- Applied at invoice compute time: coupon discount → `coupons_applied` on invoice

**UI:**
- Coupon input on the TopUpModal and plan checkout flow
- Agency billing panel: coupon manager (create, view redemptions, disable)

**Verification:** create a 20%-off coupon with `max_redemptions: 1`; redeem it; invoice shows discount; second redemption returns 409.

---

### S7.3 — Public pricing page + plan picker

The customer-facing page where someone visits one.ie/pricing and subscribes. Not the same as `/billing/plans` (which is the agency management view).

**Route:** `one.ie/pricing` (new Astro page)

**Components:**
- `<PlanCards>` — four columns (Free / Starter / Pro / Agency), feature comparison table, monthly/annual toggle
- `<PlanCheckout>` — Stripe Checkout Session redirect or embedded Stripe Elements for the selected plan
- `<CurrentPlanBadge>` — shown if already subscribed; links to `/u/[slug]/billing`

**API wiring:**
- `GET /api/billing/plans/public` — returns plan definitions (name, price, credits, features) for the pricing page; no auth required
- `POST /api/billing/plans/subscribe` — creates Stripe Checkout Session for the plan; redirects to Stripe-hosted page

**Annual billing toggle:**
- Annual = 2 months free (16.7% discount)
- Stripe Price objects for both monthly and annual per plan
- Toggle persists to localStorage

**Verification:** unauthenticated visitor can see pricing page; clicking "Get started" on Pro redirects to Stripe Checkout; successful payment → workspace plan updated via webhook.

---

### S7.4 — Cancel subscription flow

Customers need a clean way to cancel. Missing cancel = churn through support email.

**API:**
- `POST /api/billing/cancel` — sets `cancel_at_period_end: true` on Stripe subscription; updates `owners.cancel_at_period_end`; emits `signal('billing:cancel_requested')`
- `POST /api/billing/cancel/undo` — reverses if still within period; clears flag

**UI:**
- Cancel button in `/u/[slug]/billing` (plan section, owner-only)
- `<CancelModal>` — shows what the user keeps until period end; "You'll keep N credits until [date]" (same pattern as `DowngradeImpactModal`); confirms intent
- After cancel: banner in pool card "Subscription ends [date] — [Renew]"
- Webhook `customer.subscription.deleted` → sets `billing_state: 'over_limit'` immediately if balance is zero

**Verification:** owner cancels; `cancel_at_period_end = true` in D1; banner appears; undo clears it; Stripe subscription shows `cancel_at_period_end: true`.

---

### S7.5 — Trial period management

`trial_start` and `trial_end` fields land in Phase 2 schema but have no management UI or enforcement logic.

**API:**
- `POST /api/billing/trial/start` — creates trial for workspace (owner-initiated or auto on signup)
- Trial end: cron checks `owners.trial_end`; when past, if no payment method → `billing_state: 'over_limit'`; if card on file → auto-convert to paid subscription

**UI:**
- Trial banner in pool card: "Trial ends in 7 days — [Add payment method]"
- `<TrialConvertModal>` — plan selector + Stripe Elements for payment method; converts trial to subscription on submit
- Trial days remaining shown in the pool card `<PoolCard>` `resetInDays` slot (already exists)

**Verification:** workspace created with `trial_end = now + 14d`; banner shows; Stripe payment method added + modal submitted → trial ends immediately and subscription created; no card + trial expired → `over_limit` state.

---

### S7.6 — Stripe Customer Portal + dunning UI

**Stripe Customer Portal:**
- One API call: `POST /api/billing/portal` → `stripe.billingPortal.sessions.create({ customer, return_url })` → redirect
- Exposes: invoice history, payment method management, subscription management (Stripe-hosted)
- Button in `/u/[slug]/billing`: "Manage payment method" → portal redirect

**Dunning / retry management UI:**
- Currently handled silently by cron; no user visibility
- Add to pool card when `billing_state === 'recovering'`:
  - "Payment failed — we'll retry in N days"
  - "Update payment method" button → portal redirect
  - Retry count + next attempt date (from Stripe subscription `latest_invoice.next_payment_attempt`)
- `<DunningBanner>` component — replaces the existing `PaymentFailureBanner.tsx` (compose, don't create)

**Verification:** workspace in `recovering` state shows `DunningBanner` with retry date; "Update payment method" redirects to Stripe portal; successful payment → banner disappears.

---

## What NOT to Port

| Reference app feature | Why skip |
|----------------------|---------|
| Flexprice ClickHouse real-time aggregation | ONE's D1 + KV is sufficient for current scale; adds operational complexity |
| Flexprice CreditNote (void + reissue) | ONE's simple void → new-invoice covers the case |
| OpenMeter Kafka event streaming | CF Workers + D1 handles ONE's throughput; Kafka is over-engineering |
| Lago Ruby components | ONE is TypeScript-only; Go events-processor was the only relevant part |
| CoAI per-model surcharge table | ONE's `pricing_tiers` + `rateFor()` supersedes this cleanly |
| Flexprice Coupon rule engine (CEL) | ONE's promo grants cover the simple cases; save for Phase 7 |
| Flexprice multi-currency conversion tables | ONE's `display_currency` flip via Stripe covers the use case |

---

## Build Order Summary

```
Phase 0   C1-C5 (already planned, billing-costs-implementation.md)

Batch 1 — Foundation
  C1  Schema migrations (invoices, entitlements, meters, pricing_tiers, grant_expiry)  (1 day)

Batch 2 — Service layer (all parallel after C1)
  C2  Invoice engine           — S1.2 + S1.3  (2 days)
  C3  Proration + credit FIFO  — S2.1 + S2.2  (1 day)
  C4  Entitlement enforcement  — S3.2 + S3.3  (1 day)
  C5  Tiered pricing engine    — S4.2          (1 day)
  C6  Meter aggregation        — S5.2 + S5.3  (2 days)

Batch 3 — UI + customer-facing (all parallel after Batch 2)
  C7  CostTree agency dashboard      — S6.1 + S6.2  (2 days)
  C8  Public pricing page + checkout — S7.3          (2 days)
  C9  Cancel + trial flows           — S7.4 + S7.5  (1 day)
  C10 Plan template builder UI       — S4.3          (1 day)

Batch 4 — Final features
  C11 Invoice PDF + coupons              — S7.1 + S7.2  (2 days)
  C12 Stripe Portal + dunning UI         — S7.6          (1 day)
  C13 Entitlement UI + meter query API   — S3.4 + S5.4  (1 day)
```

**Total: ~3 weeks of focused construction on top of the existing foundation.**
**Result: complete billing product — backend, frontend, credit system, plans, subscriptions, invoices, coupons, trial, cancel, dunning.**

Each phase closes with a deterministic number (Rule 3). Each signal emitted closes the loop (Rule 1).
No new verbs — billing participates in the existing `signal/mark/warn/fade` system (Rule 2).

---

## Source Files to Copy First (Absolute Paths)

When starting a cycle, read these files for the algorithm before writing any TypeScript:

| Purpose | Source file |
|---------|------------|
| Invoice lifecycle | `/Users/toc/Server/apps/flexprice/internal/service/billing.go` |
| Proration math | `/Users/toc/Server/apps/flexprice/internal/service/line_item_proration.go` |
| Tiered cost calc | `/Users/toc/Server/apps/flexprice/internal/service/price.go` |
| Commitment overage | `/Users/toc/Server/apps/flexprice/internal/service/billing_commitment.go` |
| Meter aggregation types | `/Users/toc/Server/apps/flexprice/ent/schema/meter.go` |
| Subscription fields | `/Users/toc/Server/apps/flexprice/ent/schema/subscription.go` |
| Credit wallet burn-down | `/Users/toc/Server/apps/flexprice/ent/schema/wallet.go` |
| Entitlement balance | `/Users/toc/Server/apps/openmeter/openmeter/meter/meter.go` |
| Event routing cache | `/Users/toc/Server/apps/lago/events-processor/cache/charges.go` |
| Quota atomic SQL | `/Users/toc/Server/apps/coai/auth/quota.go` |

---

*One ledger. Four reference apps. Three weeks. The substrate already knows what to charge — we're
giving it the vocabulary to say so precisely.*

---

## Build status — 2026-05-29 (all 9 cycles shipped)

The full system is built and locally proven (`tsc --noEmit` = 0 · 51 vitest in `one.ie/web/tests/billing/*`). See `plans/billing-software-todo.md` for the cycle-by-cycle record and carry-forward decisions. Engine + surfaces:

- **Ledger (C1):** migrations 0076–0081 (invoices, coupons, entitlements+meters, pricing_tiers, grants ALTER, owners ALTER).
- **Three verbs + document (C2–C5):** `src/lib/billing/{grant,burn,gate,invoice}.ts` (+ `index.ts`).
- **Pricing (C6):** `/pricing` + `PlanCards` + `plans/{public,subscribe}`.
- **Lifecycle (C7):** trial / cancel / cancel-undo as `action=` branches on `api/billing.ts` (portal reused); `CancelModal`, `TrialConvertModal`, dunning `retryAt` on `PaymentFailureBanner`, trial slot in `PoolCard`, trial-expiry cron; pure core `lib/billing/lifecycle.ts`.
- **Client surface (C8):** dependency-free `lib/pdf.ts` → `GET /api/billing/invoices/:iid/pdf`; `/entitlements`; `/coupons/redeem`; `EntitlementBar` slot in `PoolCard`; `/u/[slug]/billing/invoices` list; Invoices tab.
- **Agency surface (C9):** recursive-CTE `GET /api/billing/costs`; `plan-templates` create/list/assign (keyed `tmpl:<agency>:<name>`); coupon issue; `CostTree` + `CouponManager`; template panel in `AgencyPlansManager`; `/u/[slug]/billing/costs` + Costs tab.

Every new workspace route is tenant-scoped (derive from `ctx.workspace`; param allowed only if in `ctx.descendants`; else 403). **Remaining = deploy** (the plan `outcome:` hits live one.ie/api.one.ie) + minor wiring (entitlement middleware, tiered rateFor live path, /pricing nav link).
