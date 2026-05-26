# 02-agency — gap analysis

Source promise: `text/02-agency.md`. Source code: `web/src/lib/`, `web/src/pages/api/billing/`, `web/src/pages/u/[slug]/billing/`, `web/migrations/`. Roles spec: `web/roles.md`. JV context: `project-boq-donal-jv` memory (BOQ + Donal + Brad, 3-cofounder NewCo, Pilot 1 = 50 clients / 6 weeks).

---

## Promise

1. **4-tier cascade** owner → agency → client → end_user, resolved per request from R2 `site.md` files; clients never see other clients, agency internals, or "ONE" branding.
2. **`-locked` grammar** in `site.md` freezes a property at any tier; child tiers cannot override (`primary-locked`, `logo-locked`, `features-locked`).
3. **One credit pool, distributed to clients.** Agency buys 5M credits/$500, sets `markup_pct: 20`, grants each client a `monthly_cap`. Two cascade asymmetries: children only lower caps, only raise markups; platform floor 5%.
4. **Three-line `acme/billing.md`** + **one-line `acme/clients/brandx/billing.md`** = "30 seconds setup, 10 seconds per client".
5. **3 gate states**: `on` / `metered` / `off` resolved per request, per workspace, per feature. Agency-locked gates are non-overridable by clients.
6. **Provisioning**: `POST /api/provision?action=create-invite` → email → client lands at `/u/brandx/onboarding` → live in 48h, first conversation in 60s.
7. **Billing transparency**: `over_limit` → `suspended` (30d) → `archived` (90d) with R2 export emailed before deletion; abandoned clients become root-level workspaces, keeping corpus.
8. **Per-client real-time dashboard** at `/u/acme/billing#allocations` showing balance/cap/burn-rate per client.
9. **Bot quality gate**: rubric ≥ 0.65 before any outbound message ships; below threshold = no send.
10. **CLI export**: `oneie export --workspace brandx` works unconditionally (active, suspended, leaving). Substrate is MIT, escrow for product layer.
11. **Worked example** quotes 90% gross margin on substrate; auto-top-up via CF Worker cron.

---

## Code reality

### What ships

- **Viewer derivation** (`web/src/lib/viewer.ts`, 27 lines): clean 4-tier function. Owner/agency/client/end_user resolved from session + slug compare. Wired into middleware (`web/src/middleware.ts:136`, :167) so every request lands with `locals.workspaceContext.viewer`.
- **`parent_slug` column** on `owners` table (`web/migrations/0008_workspace_hierarchy.sql`) — the single primitive the cascade claims to derive from. Index present.
- **Invite-based provisioning** (`web/src/pages/api/provision.ts` `create-invite` + `redeem-invite`): plan-gated to `agency`/`enterprise`, 7-day expiry, email via Resend template, passkey ceremony for redemption. End-to-end works.
- **Bulk provisioning** at `web/src/pages/api/provision/bulk.ts`.
- **Site cascade** (`web/src/lib/site.ts` + `web/src/lib/config.ts`): `parseSite()` reads `-locked` suffixes; `merge()` respects parent locks for `tokens`, `font`, `name`, `tagline`, `attribution`. `resolveConfig()` reads `L1 workspace + L2 parent + L3 clients/{slug}.md + L4 teams/{gid}.md` from R2 and merges in spec order. Matches the promise for brand cascade.
- **Billing primitives** (`web/src/lib/billing.ts`, `web/src/lib/billing-config.ts`):
  - `computeBurn()` splits upstream into platform / agency / recipient margins.
  - `debitPool()` checks `billing_state`, balance, and a negative-balance floor; returns `402` or `floored`.
  - `creditPool()` writes grants. `currentBalance()` reads sum-grants minus sum-burns.
  - Platform billing config sets plan grants (`free 1k`, `starter 50k`, `pro 500k`, `agency 5M`) and platform_margin 10% / floor 5%.
  - `parseBilling()` reads `plan`, `markup_pct`, `monthly_cap`, `brand_lock`, `client_default_plan`, `cap_locked` from workspace `billing.md`.
  - `mergeBilling()` enforces the two asymmetries: `mergeCap = min`, `mergeMarkup = max`, floor at `platform_floor_pct`.
- **Stripe webhook** (`web/src/pages/api/pay/webhook.ts`): real Stripe SDK, signature verify, idempotent via `stripe_events` table (`migration 0019`), grants credits on `invoice.paid`, sets `billing_anchor_day` on first invoice.
- **Per-workspace billing UI**:
  - `/u/[slug]/billing.astro` — pool + ledger + topup, viewer-gated.
  - `/u/[slug]/billing/allocations.astro` — agency-only, lists children + `AllocationEditor` with `pool`/`transfer`/`resell` modes.
  - `/u/[slug]/billing/plans.astro` — read-only plan catalogue (notes: "update `_platform/billing.md` or use the platform dashboard").
  - `/u/[slug]/billing/platform.astro` and `simulate.astro` exist.
- **Settings UI**: `ClientManager.tsx` (invite flow, plan-gated for agency/enterprise), `BillingSettings.tsx` (pool view + auto-topup toggle), `PlanSection.tsx` (upgrade via Stripe checkout), `DowngradeImpactModal.tsx`.
- **Cron workers**: `billing-allocation-cron.ts` (monthly anchor reset for children), `billing-alerts-cron.ts`, `billing-autotopup-cron.ts`, `billing-verify-cron.ts`.
- **Billing state machine** (`web/src/lib/billing-state.ts`): states named in the promise (`live`, `recovering`, `over_limit`, `floored`, `suspended`, `archived`) are present in the type union and surfaced in `BillingSettings.tsx`.
- **CSV export per dimension** lives under `/api/export/*` (per `.claude/rules/api.md`).

### What's stubbed

- `web/src/pages/api/billing/payout.ts` — explicitly stub. Returns `202 queued`. Comment: "X1 (oneFetch send side) not yet deployed."
- `web/src/workers/billing-autotopup-cron.ts` — logs `[autotopup] {slug} below threshold` but does not actually charge Stripe. Comment: "Placeholder: in production, charge Stripe customer".

---

## Gaps

### G1 — Per-client billing files don't exist on disk

Promise: "`acme/clients/brandx/billing.md`" with `plan` + `monthly_cap`, edited by agency in 10 seconds. Reality: there is **no R2 read or write of `{parent}/clients/{child}/billing.md`** anywhere in `web/src/`. `mergeBilling()` is implemented; the loader that would assemble its `layers[]` argument from R2 is not. `parseBilling()` is dead code as far as the request path is concerned — middleware never invokes it, and there is no `resolveBilling(workspace)` that reads workspace + parent + override files.

`web/src/lib/config.ts` does read `clients/{clientSlug}` from R2 — but only for **brand site overrides**, not billing. The billing cascade ships in `mergeBilling()` but is never wired.

### G2 — `monthly_cap` is never enforced at request time

`debitPool()` enforces (a) workspace billing_state, (b) absolute balance, (c) plan-grant-sized negative-balance floor. It does **not** read or enforce `monthly_cap` — the promise's "client hits the cap → 402 → payment banner" mechanism. The cap is parsed but never read on the hot path.

### G3 — `markup_pct` never applied to client burns

`computeBurn()` accepts `config?: { markup_pct }` and computes `agencyMargin = upstream * markup_pct / 100`. But every call site that matters (`/api/billing/transfer.ts` and the chat path) passes `PLATFORM_BILLING_CONFIG` directly — there is no agency-resolved config injected. So `agency_margin` lands at 0 in the burn row; no margin ever flows to the parent. The 20% markup is parseable, mergeable, and ignored.

### G4 — No agency Stripe Connect / no client-direct billing

The promise: "Brad pays you. You keep your margin. … ONE never invoices your client." The implementation: one platform Stripe account (`STRIPE_SECRET_KEY`), one `invoice.paid` webhook, credits land on whichever workspace metadata names. There is **no Stripe Connect** (`grep -i 'Connect\|connect_account'` finds zero hits in billing). Agencies cannot collect from clients via ONE; they would have to bill out-of-band and top up the agency pool themselves. The "agency as merchant of record" story is undelivered.

### G5 — `agency_margin` column never settled to agency pool

Even if G3 were fixed and burns logged a real `agency_margin`, nothing reads the column to credit the parent's pool. There is no "agency revenue" grant source. `recipient_share` has the same problem — written but never paid out (G7).

### G6 — `features-locked` not enforced

`parseSite()` reads `-locked` for tokens, font, name, tagline, attribution. `features-locked: true` from the marketing copy has **no parser support and no enforcement**. The promise of "ACME locks `features: [chat,agents,tools,settings]` so clients cannot add skills or payments" does not hold — there is no feature-gate resolution against the cascade at all, only the plan-level `PLATFORM_BILLING_CONFIG.plans[plan].gates`.

### G7 — Payout to agency / recipient is a 202 stub

`POST /api/billing/payout` returns `queued` with "X1 not yet deployed". There is no path for an agency to extract their margin as USD/USDC. The agency makes margin in the burn row, never sees it as money. Combined with G3+G4+G5: the entire "Acme keeps $19.80/mo per client" arithmetic in the marketing page is not realisable on prod today.

### G8 — Auto-top-up cron does not charge

`runAutoTopUp()` walks workspaces and logs. No Stripe call, no `stripe.subscriptions.update`, no PaymentIntent. The promise of "auto-top-up via Cloudflare Worker cron" is shipped only as a scheduler skeleton.

### G9 — Quality gate (0.65 rubric) not enforced at outbound

Marketing claims "messages below 0.65 do not ship" as a contractual guarantee to clients. The rubric exists in `one/rubrics.md` and in `/do` close gates. There is **no per-message LLM-output rubric check in the chat path** (`web/src/pages/api/chat.ts` and `claw/`). The voice contract is design-only.

### G10 — 30/90-day suspension lifecycle not run

`billing_state` enum has `suspended` and `archived`; `debitPool()` blocks burns when state is set. But there is no cron that **transitions** workspaces `over_limit → suspended` at 30d or `suspended → archived` at 90d, and no R2-export-on-archive email job. `billing-verify-cron.ts` exists; the transition logic does not.

### G11 — `oneie export --workspace brandx` does not exist as a CLI verb

`cli/src/index.ts` lists 15 verbs including `agent`, `skill`, `auth`, `dev`. There is no `export` verb. The promise of "any workspace owner runs `oneie export --workspace brandx`" is undelivered. `/api/export/*` returns CSV per-dimension via HTTP, but the marketing-page-shaped one-command archive is absent.

### G12 — `parent_slug` becomes-root on agency cancel is documented, not coded

The doc promises: "abandoned clients' workspaces eventually become root-level workspaces. They lose the parent's brand locks but keep their corpus." No code path nulls `parent_slug` on agency cancellation. This is a real risk for the BOQ JV — if the JV NewCo were to dissolve, Brad's 50 clients have no automated demotion path.

### G13 — Per-client real-time billing dashboard is partial

`/u/[slug]/billing/allocations.astro` lists children with `plan` + `billing_state` only. It does **not** show per-client balance, monthly cap, or burn rate as the marketing page promises ("agency dashboard at `/u/acme/billing#allocations` shows per-client credit balance, monthly cap, and burn rate"). The data exists (per-workspace queries against `credit_grants` / `credit_burns`); the rollup query and component do not.

### G14 — Promise of 5 child workspace shape (`startup1.com CNAME → acme.one.ie`) is wired in `domains` table but not in onboarding UX

`web/migrations/0008_workspace_hierarchy.sql` adds `parent_slug` on `domains`, and `web/src/pages/api/domain.ts` exists. There is no agency-side UI to set "`brandx.acme.com` for this client" during the invite flow. Client must figure out custom-domain wiring themselves through `DomainSettings.tsx`. Adds onboarding friction vs the "48 hours" promise.

### G15 — Pricing inconsistency: marketing vs code

Marketing: agency plan $500/mo for 5M credits. `PlanSection.tsx`: `Agency €49/mo`, `Pro €12/mo`. The Stripe-facing plan tier prices in the UI are 10x lower than the unit economics in the spec, with no apparent reconciliation. Either the marketing copy is the future-state pricing or the UI is wrong. For Brad-facing demos this will be the first question asked.

---

## Recommended improvements

Ordered by dependency, not effort. Each delivers a promise that BOQ Pilot 1 will exercise.

### R1 — Wire `resolveBilling(workspace, parent)` into middleware  (closes G1, G2, G3, G5)

Mirror `resolveConfig()` shape. Read in order: `_platform/billing.md` → `{parent}/billing.md` → `{parent}/clients/{slug}/billing.md` → `{slug}/billing.md`. Pass through `mergeBilling()`. Attach to `locals.workspaceContext.billing`. Then:
- `debitPool()` reads `monthly_cap` from this object, enforces a per-period burn-sum check.
- `computeBurn()` is called with `config = resolvedBilling`, so `markup_pct` lands on the burn row.
- On every `agency_margin > 0` burn, write a paired grant to the parent pool with `source: 'agency_margin'`.

Tests: `mergeBilling()` already has correct asymmetries; the integration test is the missing piece.

Files: `web/src/middleware.ts`, `web/src/lib/billing.ts`, `web/src/pages/api/chat.ts` (and any other `debitPool()` caller), new `web/src/lib/resolve-billing.ts`.

### R2 — Settle agency margin and recipient share on a cadence  (closes G5, G7)

Cron job (`billing-settle-cron.ts`): sum `agency_margin` per parent + `recipient_share` per recipient since last settle, write payout-ready aggregates to a new `settlements` table. Surface in `/u/[slug]/billing` as "earned" balance. Defer USDC rail until X1; meanwhile expose Stripe Connect payout (R3).

### R3 — Stripe Connect for agency-as-merchant  (closes G4)

Onboard each agency as a Stripe Express account. Subscription + invoice for client workspaces sit on the agency's Connect account, with platform application_fee = `platform_margin_pct`. Webhook handler already idempotent; extend `invoice.paid` to differentiate platform vs Connect invoices and credit the right pool.

Files: `web/src/pages/api/pay/webhook.ts`, new `/api/billing/connect/onboard.ts`, new `connect_accounts` table.

### R4 — Real auto-top-up + 30/90 lifecycle crons  (closes G8, G10)

`billing-autotopup-cron.ts`: read `auto_topup` + `stripe_customer_id` from owner row; create off-session PaymentIntent; on success → `creditPool()`; on `requires_action` → email.
`billing-lifecycle-cron.ts` (new): nightly transition `over_limit > 30d → suspended`, `suspended > 60d → r2-export-email`, `suspended > 90d → archived`. Use R2 `list` + `oneie export`-equivalent to build archive.

### R5 — `features-locked` parser + middleware gate  (closes G6)

Extend `parseSite()` to read `features` array + `features-locked` boolean. Extend `merge()`. Add a `gate(featureName, resolved)` helper called from every feature-page top: chat/agents/skills/tools/payments. Returns 404/redirect on `off`. Cascade source of truth is plan gate ∪ workspace gate ∪ parent-locked override.

### R6 — Per-client billing dashboard rollup  (closes G13)

One SQL: `SELECT slug, plan, billing_state, (SELECT COALESCE(SUM(amount_credits),0) FROM credit_grants WHERE workspace=o.slug) - (SELECT COALESCE(SUM(amount_credits),0) FROM credit_burns WHERE workspace=o.slug) AS balance, (SELECT SUM(amount_credits) FROM credit_burns WHERE workspace=o.slug AND ts > strftime('%s','now','-7 days')) AS burn_7d FROM owners o WHERE parent_slug=?`. Wire into `allocations.astro` + extend `AllocationEditor.tsx` to show balance bar + 7-day sparkline per client.

### R7 — `oneie export` CLI verb  (closes G11)

Add to `cli/src/index.ts`. Implementation: fan-out to `/api/export/{actors,groups,skills,highways,conversations}?workspace=X`, concat into `brandx-export.zip` + R2 dump of `{slug}/*`. Marketing copy literally quotes this command; until it works, Brad cannot demo "data is portable" in a sales call.

### R8 — Agency-managed child custom domain in invite flow  (closes G14)

`create-invite` POST accepts optional `customDomain`. On `redeem-invite`, populate `domains` row with `parent_slug = agencySlug`, surface "DNS records to set" in onboarding. Removes a friction point that compounds for Brad's 50-client cohort.

### R9 — Quality-gate hook on outbound  (closes G9)

Insert `scoreAndGate(message, rubric)` before each `assistant` message flush in the streaming chat path. Below 0.65 → replace with safe fallback + log to a `quality_gate` D1 table. Rubric scorer can be a small Haiku call; spec already exists in `one/rubrics.md`. Mark as "metered" so agencies see the cost on their pool.

### R10 — Auto-demote `parent_slug` on agency archive  (closes G12)

In R4's lifecycle cron, when an agency workspace transitions to `archived`, run `UPDATE owners SET parent_slug = NULL WHERE parent_slug = ?` for all children. Email children's owners 14 days before with the demotion notice. Removes JV-dissolution risk for BOQ.

### R11 — Reconcile pricing copy vs `PlanSection.tsx`  (closes G15)

Sales-blocker for Brad demos. Either:
- (a) Update `PlanSection.tsx` to use $500 agency / $50 growth / $5 starter to match `text/02-agency.md` and `PLATFORM_BILLING_CONFIG`, or
- (b) Update marketing copy to reflect €49 / €12 / €0 today with a stated "agency-plus on request" upgrade.
Pick one before any BOQ demo deck cites a price.

---

## Files to touch

### New
- `web/src/lib/resolve-billing.ts` (R1)
- `web/src/lib/feature-gate.ts` (R5)
- `web/src/workers/billing-settle-cron.ts` (R2)
- `web/src/workers/billing-lifecycle-cron.ts` (R4)
- `web/src/pages/api/billing/connect/onboard.ts` (R3)
- `web/src/pages/api/billing/connect/dashboard.ts` (R3)
- `web/migrations/0049_settlements.sql` (R2)
- `web/migrations/0050_connect_accounts.sql` (R3)
- `web/migrations/0051_quality_gate.sql` (R9)
- `cli/src/commands/export.ts` (R7)

### Modified
- `web/src/middleware.ts` — attach resolved billing + feature gate to `locals.workspaceContext` (R1, R5)
- `web/src/lib/billing.ts` — `debitPool()` reads `monthly_cap`; emit `agency_margin` settlement grant (R1, R2)
- `web/src/lib/billing-config.ts` — extend `parseBilling()` for `features-locked` (R5)
- `web/src/lib/site.ts` — extend `parseSite()` + `merge()` for `features` + `features-locked` (R5)
- `web/src/lib/config.ts` — propagate `features` through cascade (R5)
- `web/src/pages/api/chat.ts` — quality gate at flush (R9), use resolved billing (R1)
- `web/src/pages/api/pay/webhook.ts` — Connect-vs-platform invoice branching (R3)
- `web/src/pages/api/provision.ts` — accept `customDomain` in `create-invite` (R8)
- `web/src/pages/u/[slug]/billing/allocations.astro` — per-child rollup query (R6)
- `web/src/components/billing/AllocationEditor.tsx` — balance bar + sparkline (R6)
- `web/src/components/settings/ClientManager.tsx` — show per-client balance + cap (R6)
- `web/src/components/settings/PlanSection.tsx` OR `text/02-agency.md` — pricing reconciliation (R11)
- `web/src/workers/billing-autotopup-cron.ts` — actually charge Stripe (R4)
- `cli/src/index.ts` — register `export` verb (R7)
- `web/wrangler.toml` — new cron triggers for settle + lifecycle (R2, R4)
