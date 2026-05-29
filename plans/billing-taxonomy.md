# Billing Taxonomy

Every billable surface in ONE, with implementation status.

**Status key**
- ✅ implemented — code exists, wired end-to-end
- 🟡 partial — type/DB/gate defined but not fully connected
- ⬜ not built — no code yet

---

## Credit unit

1 credit = $0.0001 USD. Everything below is expressed as a credit burn rate.  
Source of truth: `src/lib/billing-config.ts → PLATFORM_BILLING_CONFIG`

---

## AI Compute

| Item | Unit | Rate (credits) | Status | Where |
|------|------|----------------|--------|-------|
| Text inference — input | per 1K tokens | per-model `upstream_per_1k_in` | ✅ | `billing-config.ts` models map |
| Text inference — output | per 1K tokens | input × `output_mult` | ✅ | `billing-config.ts` models map |
| Voice input (STT) | per minute | 8 | 🟡 | `metered.voice_per_minute_in` rate defined; no STT route exists yet |
| Voice output (TTS) | per minute | 12 | ✅ | `metered.voice_per_minute_out`; gate `voice_output` checked; `debitPool` fires in `tts.ts` (duration from char count) |
| Premium model surcharge | per run | gate: on/metered/off | 🟡 | Gate + per-model rates defined; no premium model wired in `chat.ts` yet — gate has no call site |
| Image generation | per image | — | ⬜ | No burn reason, no model entry |
| Extended thinking tokens | per 1K tokens | — | ⬜ | |
| Embeddings | per 1K tokens | — | ⬜ | |
| Document parsing / OCR | per page | — | ⬜ | |
| Video analysis | per minute | — | ⬜ | |

---

## Agents

| Item | Unit | Rate (credits) | Status | Where |
|------|------|----------------|--------|-------|
| Agent run | per run | 10 base | ✅ | `metered.agent_run_base`; burn reason `agent_run` |
| Skill call | per invocation | 5 base | ✅ | `metered.skill_call_base`; burn reason `skill_call` |
| Tool call | per invocation | cost-based | ✅ | burn reason `tool_call` |
| Published agent slots | per agent over limit | plan limit | ✅ | `PUBLISH_LIMITS` (free 5 / starter 20 / pro 100 / agency ∞) |
| Agent creation | gate | on/off per plan | 🟡 | `FeatureKey.agent_create`; no overage billing |
| Scheduled / cron agent | per execution | — | ⬜ | Cron infra exists for billing jobs; not wired for user agents |
| Autonomous agent duration | per minute | — | ⬜ | |

---

## Skills

| Item | Unit | Rate (credits) | Status | Where |
|------|------|----------------|--------|-------|
| Skill call | per invocation | 5 base | ✅ | burn reason `skill_call` (shared with agent row above) |
| Skill publish slots | gate / plan limit | — | 🟡 | `FeatureKey.skill_publish` gate; no over-limit billing |
| x402 skill payment — platform fee | % of amount | `platform_usd` split | ✅ | `x402_payments` table; 4-way split wired |
| x402 skill payment — agency cut | % of amount | `agency_usd` split | ✅ | `x402_payments.agency_usd` column; wired |
| x402 skill payment — creator share | % of amount | `creator_usd` split | ✅ | `x402_payments.creator_usd`; wired |

---

## Storage

| Item | Unit | Rate (credits) | Status | Where |
|------|------|----------------|--------|-------|
| File storage | per GB/hour | 1 | ✅ | `metered.storage_per_gb_hour`; burn reason `storage` |
| Export archive | per export | 100 | ✅ | `metered.export_per_archive`; `FeatureKey.export` gate |
| Attachments | gate | on/off | 🟡 | `FeatureKey.attachments` gate; no per-file billing |
| Memory / KV snapshots | — | — | ⬜ | Not metered |
| Knowledge base (TypeDB) | per GB | — | ⬜ | Not metered |
| Media storage (R2) | per GB/month | — | ⬜ | Not metered |
| Backup retention beyond default | per GB/month | — | ⬜ | Backup worker exists; no billing |

---

## Channels & Comms

| Item | Unit | Rate (credits) | Status | Where |
|------|------|----------------|--------|-------|
| Public chat message | per message | 1 | ✅ | `metered.public_chat_per_msg`; burn reason `public_chat`; gate `public_chat` |
| API request overage | per request | 0.1 | ✅ | `metered.api_overage_per_request`; burn reason `api`; gate `api_access` |
| Webhooks | gate | on/off | 🟡 | `FeatureKey.webhooks` gate; no per-delivery billing |
| Email sends (via Resend) | per 1K | — | ⬜ | |
| SMS | per message | — | ⬜ | |
| Telegram / Discord messages | per 1K | — | ⬜ | Agent worker handles ingress; not billed per message |
| Push notifications | per 1K | — | ⬜ | |

---

## Platform Features

| Item | Unit | Rate (credits) | Status | Where |
|------|------|----------------|--------|-------|
| Brand removal | per day | 30 | ✅ | `metered.brand_removal_per_day`; burn reason `brand_removal_per_day`; gate `brand_removal` |
| Custom domain | gate | on/off | ✅ | `domain.ts` blocks registration for free/starter plans; pro+ required |
| White label cascade | gate | on/off | 🟡 | `FeatureKey.white_label_cascade`; agency plan only; no separate billing |
| Sub-workspace creation | gate | on/off | 🟡 | `FeatureKey.sub_workspace_create`; no per-workspace overage billing |
| Voice input/output | gate | on/off | 🟡 | `FeatureKey.voice_input/output` gates; burn rate exists; gates not checked at call site |
| File storage feature | gate | on/off | 🟡 | `FeatureKey.file_storage` gate; burn rate wired separately |
| Team creation | gate | on/off | 🟡 | `FeatureKey.team_create` gate; no per-seat billing |
| SSO / SAML | — | — | ⬜ | |

---

## Workspaces & Seats

| Item | Unit | Rate | Status | Where |
|------|------|------|--------|-------|
| Client workspaces | per workspace | plan limit | 🟡 | `maxClientWorkspaces` in `plan.ts` (agency: 50, enterprise: 999); no over-limit billing |
| Sub-agency workspaces | per workspace | agency plan | 🟡 | Plan gate only; no per-workspace fee |
| Staff / team members | per seat/month | — | ⬜ | `team_create` gate exists; no seat count or per-seat billing |
| End users / MAU | per active user | — | ⬜ | |
| Guest / viewer seats | per seat | — | ⬜ | |

---

## Payments & Transfers

| Item | Unit | Rate | Status | Where |
|------|------|------|--------|-------|
| Credit transfer between workspaces | per transfer | burn: `transfer` | ✅ | burn reason `transfer`; `billing/transfer.ts` route |
| Payout to creator | per payout | burn: `payout` | ✅ | burn reason `payout`; `billing/payout.ts`; `CrossChainPayout.tsx` |
| Stripe subscription | monthly / annual | plan price | ✅ | `billing.ts` checkout + webhook; maps price IDs → plans |
| Credit top-up | per $ | flat rate | ✅ | `billing/upgrade.ts`; `TopUpModal.tsx` |
| Agency markup on client credits | % over platform rate | `markup_pct` | ✅ | D1 column on `owners`; applied in `debitPool` via parent LEFT JOIN; editable via `billing/config.ts` |
| x402 transactions | % of amount | 4-way split | ✅ | `x402_payments` table; `billing-config.ts` margin model |

---

## Credit Grant Sources

| Source | Status | Where |
|--------|--------|-------|
| `subscription` — monthly plan allocation | ✅ | Stripe webhook → `billing/upgrade.ts` |
| `topup` — manual purchase | ✅ | `billing/upgrade.ts` |
| `payout` — creator earnings credited back | ✅ | `billing/payout.ts` |
| `sponsorship` — free grant to a workspace | ✅ | `POST /api/billing/grant` owner-only; also used internally by `billing/transfer.ts` |
| `promo` — discount / trial grant | ✅ | `POST /api/billing/grant` owner-only |
| `refund` — reversed charge | ✅ | `POST /api/billing/grant` owner-only |

---

## Billing State Machine

```
live → recovering → over_limit → suspended → archived
```

| State | Trigger | Status |
|-------|---------|--------|
| `live → recovering` | `payment_failed` | ✅ Stripe webhook |
| `recovering → over_limit` | `retry_failed_3x` | ✅ Stripe webhook |
| `over_limit → suspended` | `over_limit_30d` | ✅ `billing-lifecycle-cron.ts` daily |
| `suspended → archived` | `suspended_90d` | ✅ `billing-lifecycle-cron.ts` daily |
| Any → `live` | `paid` / `balance_restored` / `admin_restore` | ✅ |

---

## Scheduled Jobs

| Job | Schedule | Status | Where |
|-----|----------|--------|-------|
| Auto top-up (below 10% of plan grant) | hourly | ✅ | `billing-autotopup-cron.ts` |
| Monthly credit allocation | daily 01:00 UTC | ✅ | `billing-allocation-cron.ts` |
| Usage alerts (50% / 80% / 95%) | daily 02:00 UTC | ✅ | `billing-alerts-cron.ts` |
| Lifecycle escalation | daily 03:00 UTC | ✅ | `billing-lifecycle-cron.ts` |
| Ledger integrity verify | daily 04:00 UTC | ✅ | `billing-verify-cron.ts` |

---

## Cascade / Multi-Tenant Config

| Layer | Status | Where |
|-------|--------|-------|
| `mergeBilling()` — cascade platform → agency → agency-template → client → team | ✅ / 🟡 | `billing-config.ts` — 4-layer cascade; agency-template layer ⬜ not yet inserted |
| `parseBilling()` — read workspace `billing.md` frontmatter | ✅ | `billing-config.ts` |
| Platform admin override (rate, margins) | ✅ | `_platform/billing.ts` API + `/billing/platform` page |
| Agency sets markup/cap/locks for clients | ✅ | `markup_pct`, `monthly_cap`, `brand_lock`, `cap_locked`, `client_default_plan` columns on `owners` (migration 0070); `GET/POST /api/billing/config` |
| Monthly cap enforced on burns | ✅ | `debitPool` checks `parent_monthly_cap` via JOIN before inserting; returns `floored` if exceeded |
| Per-client plan assignment | ✅ | `GET/POST /api/billing/clients`; verifies `parent_slug` before update; grants delta credits on upgrade |
| Agency plan templates — named configs stamped onto clients | ⬜ | New `agency_plan_templates` D1 table (migration 0071); `client_default_plan` on `owners` accepts template ID or base tier name; `mergeBilling()` resolves template overrides before client layer |

---

## UI Components

| Component | Status | Where |
|-----------|--------|-------|
| `/u/[slug]/billing` — overview dashboard | ✅ | `billing.astro` |
| `/u/[slug]/billing/plans` — agency config + client list | ✅ | `plans.astro` + `AgencyPlansManager.tsx` — markup/cap/brand form + client plan assignment |
| `/u/[slug]/billing/allocations` — team budget editor | 🟡 | `allocations.astro` + `AllocationEditor.tsx` |
| `/u/[slug]/billing/platform` — owner rate config | ✅ | `platform.astro` + `_platform/billing.ts` |
| `/u/[slug]/billing/simulate` — scenario simulator | 🟡 | `simulate.astro` — exists; scope unknown |
| `TopUpModal` | ✅ | `billing/TopUpModal.tsx` |
| `PaymentFailureBanner` | ✅ | `billing/PaymentFailureBanner.tsx` |
| `PoolCard` | ✅ | `billing/PoolCard.tsx` |
| `Ledger` — grant/burn history | ✅ | `billing/Ledger.tsx` |
| `DowngradeImpactModal` | ✅ | `billing/DowngradeImpactModal.tsx` |
| `CrossChainPayout` | ✅ | `billing/CrossChainPayout.tsx` |
| Client plan manager (agency assigns plan to client) | ✅ | `billing/AgencyPlansManager.tsx` — client list with usage bars + inline plan selector |
| Sub-agency plan delegation UI | ✅ | Sub-agencies appear in the same client list (they have `parent_slug` set); same assign flow |
| `/u/[slug]/billing/plans/new` — plan template builder | ⬜ | New page; name + base tier + override panel (credit ceiling, markup %, monthly cap, feature gate toggles); preview card shows effective config after cascade |
| `PlanTemplateEditor` — create/edit agency plan templates | ⬜ | `billing/PlanTemplateEditor.tsx`; only shows gates that differ from base tier as "customized" |
| `AgencyPlansManager` — template-aware client assignment | 🟡 | Extend `billing/AgencyPlansManager.tsx`; plan dropdown shows agency templates (with "Custom" badge) + base tiers |

---

## Plans

| Plan | Monthly grant | Key gates | Stripe |
|------|---------------|-----------|--------|
| `free` | 1,000 credits | public_chat: metered; brand_removal: off; premium_models: off | ✅ |
| `starter` | 50,000 credits | brand_removal: on; premium_models: metered | ✅ |
| `pro` | 500,000 credits | all on | ✅ |
| `agency` | 5,000,000 credits | all on + sub_workspace_create + white_label_cascade | ✅ |
| `enterprise` | custom | full limits (999 clients) | ⬜ custom Stripe |

---

## Agency billing — closed 2026-05-24

All three gaps that blocked agency → client billing are now closed:

1. ✅ **Write path for agency config** — `markup_pct`, `monthly_cap`, `brand_lock`, `cap_locked`, `client_default_plan` added to `owners` table (migration 0070). `GET/POST /api/billing/config` is the write path.
2. ✅ **Markup applied in `debitPool`** — `debitPool` JOINs the parent workspace to resolve `markup_pct` and `monthly_cap` on every burn. `agency_margin` is now computed internally; callers no longer set it.
3. ✅ **Client plan assignment UI** — `AgencyPlansManager.tsx` at `/u/[slug]/billing/plans` shows the config form and the full client list with inline plan selectors and monthly usage bars.

---

## Agency plan templates — next

Agencies create named plan configs that inherit from a base tier and override specific gates/credits. Templates are stamped onto clients instead of assigning a raw tier.

**Model:**
- New D1 table `agency_plan_templates` (migration 0071): `id`, `agency_slug`, `name`, `base_plan`, `overrides` (JSON), `created_at`
- `client_default_plan` on `owners` accepts a template ID or a base tier name — `mergeBilling()` resolves which
- `mergeBilling()` gains a 4th layer: `platform → agency → agency-template → client → team`

**UI:**
- `/u/[slug]/billing/plans/new` — template builder: name + base tier + override panel + preview card
- `PlanTemplateEditor.tsx` — only customized gates shown as overrides; others inherit from base
- `AgencyPlansManager.tsx` — plan dropdown gains template entries with "Custom" badge

**Open gaps:** migration 0071, `mergeBilling()` template resolution, `GET/POST /api/billing/plan-templates` routes, `PlanTemplateEditor.tsx`

---

## Billing software schema — migrations 0076–0081 (billing-software-todo C1)

The complete-system build (invoices, coupons, entitlements, tiered rates, grant FIFO, subscription
lifecycle) adds these tables/columns. All idempotent on a fresh DB.

| Migration | Adds | Columns of note |
|-----------|------|-----------------|
| `0076_invoices.sql` | `invoices` + `invoice_line_items` | `idempotency_key` UNIQUE = `{ws}:{period_start}:{period_end}`; `billing_sequence` assigned only at finalize; `pdf_url`/`pdf_generated_at` for C8 |
| `0077_coupons.sql` | `coupons` + `coupon_redemptions` | `discount_type` (percentage\|fixed_credits); `cadence` (once\|repeating\|forever); `redemptions` counter |
| `0078_entitlements.sql` | `entitlements` + `meters` | `entitlements.usage_limit`/`used`/`is_soft_limit` (numeric gate limits); `meters.aggregation` JSON (MeterAggregation) |
| `0079_pricing_tiers.sql` | `pricing_tiers` | `tiers` JSON PriceTier[]; `metadata` holds C9 plan-template defs; UNIQUE(workspace, feature, COALESCE(model,'')) |
| `0080_grants.sql` | ALTER `credit_grants` | `priority`, `conversion_rate`, `topup_conversion_rate` — `expires_at` already existed (0016) |
| `0081_subscriptions.sql` | ALTER `owners` | `billing_anchor` (mode, vs existing `billing_anchor_day`), `trial_start/end`, `cancel_at`, `cancel_at_period_end`, `pause_status`, `collection_method`, `net_terms_days` |

**Reads:** `src/lib/billing/{grant,burn,gate,invoice}.ts` (the policy layer) over `src/lib/billing.ts`
(`computeBurn`/`debitPool`/`creditPool`, never reimplemented). All use `env.DB` against the `one-owners` D1.
