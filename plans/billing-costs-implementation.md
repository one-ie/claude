---
title: Billing Cost Tracking — Implementation
source_of_truth: billing-costs.md · billing-products.md · billing-taxonomy.md
existing_primitives:
  - one.ie/web/migrations/0017_credit_burns.sql   # the cost ledger — already per-workspace
  - one.ie/web/src/lib/billing.ts                  # computeBurn (pure) + debitPool (cascade)
  - one.ie/web/src/lib/billing-config.ts           # static model rates (to be demoted to fallback)
  - one.ie/web/src/pages/api/openrouter-models.ts  # already fetches live OpenRouter pricing → KV
  - one.ie/web/migrations/0066_restore_owners.sql  # owners.parent_slug — the agency→client edge
  - channels/src/middleware.ts                     # wrapGenerate — has result.usage; binds ONE_DB
  - channels/src/aitools.ts                        # 7 tools — tool-call capture point
parallel_budget: 4
mode: extend
lifecycle: construction
closure_scalar: >
  Replay tolerance — Σ cost_credits over any window equals Σ (stored tokens × rate-at-burn) within
  1 credit. AND zero untracked inference — every doGenerate in a 24h soak has a matching burn row.
  AND the three audience rollups (client / agency / platform) reconcile to the same ledger total.
---

# Billing Cost Tracking — Implementation

**The principle:** the cost ledger already exists. We are not building a metering system — we are
closing three gaps so every inference and tool call lands in the ledger that's already there, and
so the rate it's priced at comes from OpenRouter instead of a hand-edited constant.

> Power through simplicity — the meta-layer obeys the rule the schema already obeys.
> Don't build a second ledger. `credit_burns` *is* the ledger. Make everything write to it.

---

## The one idea

Every cost — an inference, a tool call, a voice minute — is **one `credit_burns` row keyed by
`workspace`**. The row already carries the full split:

| Column | Meaning | Who reads it |
|---|---|---|
| `cost_credits` | upstream cost (what ONE paid the provider) | platform — true COGS |
| `platform_margin` | ONE's cut | platform P&L |
| `agency_margin` | the parent agency's markup | **agency revenue** |
| `amount_credits` | what the workspace was actually charged | **client's bill** |
| `model` | which model/tool incurred it | every audience, for breakdown |
| `reason` | `inference` / `tool_call` / `voice` / … | every audience, for breakdown |

And `owners.parent_slug` already encodes the whole tenant tree — it is a self-reference, so
`owner → agency → client → team` is *one chain of arbitrary depth*. A **team is not a new entity**:
it's an `owners` row whose `parent_slug` points at its client. The recursive walk already exists
(`resolveDescendants`, depth-capped at 16, in `web/src/middleware.ts`).

So **every cost report is the same query rooted at the viewer's workspace** — "the cost of my
subtree" — no rollup tables, no aggregation jobs, no per-audience code:

```sql
WITH RECURSIVE subtree(slug) AS (
  SELECT :root                                    -- the workspace being viewed
  UNION
  SELECT o.slug FROM owners o JOIN subtree s ON o.parent_slug = s.slug
)
SELECT … FROM credit_burns b JOIN subtree s ON s.slug = b.workspace …
```

| Audience | `:root` | Sees |
|---|---|---|
| **Owner** (Tony) | every top-level workspace (`parent_slug IS NULL`) | the whole tree — agencies → clients → teams |
| **Agency** | the agency slug | its clients, and the teams under them |
| **Client** | the client slug | itself + its teams |
| **Team** (leaf) | the team slug | just itself |

Attribution is a filter, and the filter is *"my subtree."* The only thing that changes per audience
is the root and the depth — not the query, not the schema.

What's missing is not storage. It's **capture** (the agent runtime doesn't write burns yet),
**live rates** (the rate is a stale constant), a **recursive rollup** (today's is one level — teams
are dropped), and **surfacing it in the UI** for the four audiences.

---

## What already exists (do not rebuild)

| Capability | Status | Location |
|---|---|---|
| Per-workspace cost ledger | ✅ | `credit_burns` (migration 0017) |
| Cost math (upstream + 3-way margin split) | ✅ pure fn | `billing.ts → computeBurn` |
| Debit + cascade + monthly cap + 402 | ✅ | `billing.ts → debitPool` |
| Agency→client hierarchy | ✅ | `owners.parent_slug` |
| Markup cascade (parent markup applied automatically) | ✅ | `debitPool` reads `parent.markup_pct` |
| Live OpenRouter price fetch → KV | ✅ | `openrouter-models.ts` (`openrouter:models:v1`, TTL 1h) |
| Inference usage exposed at runtime | ✅ | `middleware.ts` — `result.usage.{inputTokens,outputTokens}` |
| Channels worker can reach billing DB | ✅ | `channels/wrangler.toml` binds `ONE_DB = one-owners` |
| Web chat already burns inference | ⚠️ partial | `chat.ts` (`reason: 'inference'`) — uses **static** rate, stores **no** tokens |

## The three gaps

| # | Gap | Consequence today |
|---|---|---|
| **G1** | `billing-config.ts models:` is hand-edited and stale (Opus priced at 1500cr vs 50cr actual — 30× off, per `billing-costs.md`) | every inference burn is mispriced |
| **G2** | The **agent runtime** (`channels/`) only calls `mark()` on a generate — it never writes a burn | all Telegram/Discord/orchestrate inference is **invisible to billing** |
| **G3** | `tool_call` burn reason is defined but **never fired** anywhere | tool costs (Composio etc.) are unattributed |
| **G4** | rollup is **one level** (`WHERE parent_slug = ?`) — a team's cost never rolls up to its client/agency | teams (sub-groups under clients) are invisible to the tree above them |
| **G5** | no cost UI rooted at the viewer's subtree — owner has a flat platform table; agency/client/team have a pool but no "cost of everything beneath me" | the four audiences can't see their own costs |

Close G1→G5 and the existing ledger + hierarchy answer every audience's question with no new tables.

---

## Schema delta (the entire footprint)

One migration. Two nullable columns for auditability + re-pricing — so when OpenRouter prices change,
historical burns keep what they cost *at the time*, and we can still recompute from raw tokens.

```sql
-- 00NN_burn_usage.sql
ALTER TABLE credit_burns ADD COLUMN tokens_in  INTEGER;   -- null for non-token burns
ALTER TABLE credit_burns ADD COLUMN tokens_out INTEGER;
ALTER TABLE credit_burns ADD COLUMN unit_count REAL;      -- generic: tool calls, voice minutes, images
```

No new tables. `model_rates` lives in KV (cycle C1), not a table — it's a cache of an external truth,
not substrate.

---

## Cycles

### C1 — Live rates from OpenRouter (closes G1)

The user requirement: *"costs are going to change, we can update from the OpenRouter API."*

- Add `rateFor(model, env): { in_per_1k, out_per_1k }` in `billing.ts`. It reads the
  `openrouter:models:v1` KV blob that `openrouter-models.ts` already populates, converts
  `pricing.prompt`/`pricing.completion` (USD/token) → credits/1k (`usd × 1000 / 0.0001`), and falls
  back to `billing-config.ts models:` only on KV miss.
- Add a **cron in `sync/`** that hits `GET /api/v1/models` and refreshes the KV blob on schedule
  (the endpoint already caches 1h; the cron guarantees freshness even with no traffic).
- Demote `billing-config.ts models:` to a documented fallback. Stop hand-editing it.

**Closed loop:** `rateFor('anthropic/claude-opus-4.6')` returns 50cr/1k in, not 1500 — matches
`billing-costs.md` row.

### C2 — Capture inference in the agent runtime (closes G2)

The capture point already has everything: `middleware.ts → wrapGenerate` holds `result.usage` and the
worker binds `ONE_DB`. Today it only marks pheromone.

- After `doGenerate()`, build a burn:
  `cost = ceil(tokens_in/1000 × rate.in) + ceil(tokens_out/1000 × rate.out)`, then
  `computeBurn({ upstream: cost, workspace, parent, reason: 'inference', model })` → INSERT into
  `credit_burns` with `tokens_in`/`tokens_out` filled. The `mark()` call stays — billing is additive.
- **The one piece of glue:** resolve `group → owning workspace slug` (the `parent` for cascade comes
  from `owners.parent_slug`). The group→workspace map already exists in channels D1; surface it as
  `workspaceForGroup(group, env)`.
- Align web `chat.ts` to the same path: live rate (C1) + store tokens. It already burns — this just
  makes it accurate and auditable.
- **Reuse `computeBurn`** (it's already pure). To avoid logic drift across the two workers, the cost
  math is imported, not re-implemented — promote `computeBurn` + `rateFor` into `@oneie/sdk`
  (both workers already depend on it via `workspace:*`).

**Closed loop:** a Telegram turn produces exactly one `inference` burn whose `cost_credits` equals
the live-rate recomputation from its stored tokens.

### C3 — Capture tool calls (closes G3)

- Wrap each tool's `execute` in `aitools.ts` with a thin recorder: on completion, write a
  `reason: 'tool_call'` burn with `model = <tool name>`, `unit_count = 1`, and `cost_credits` = the
  tool's real per-call cost (Composio = live plan rate per `billing-costs.md §Composio`; substrate
  verbs = 0 upstream, pure infra).
- This naturally populates what the dormant `channels/migrations/0001 tool_calls` table was for —
  but as a billing burn, not a parallel log. One ledger.

**Closed loop:** an agent run that fires 3 Composio tools yields 3 `tool_call` burns attributed to
the same workspace as its inference.

### C4 — Recursive rollup (closes G4)

No new tables — one recursive read over `credit_burns ⋈ owners`, rooted at the viewer's workspace,
so a team's cost rolls all the way up. The subtree CTE reuses the shape of `resolveDescendants` in
`middleware.ts`. Expose via the **existing** billing API family (`/api/billing/clients.ts` already
exists for the agency view).

**Per-descendant cost** — one row per workspace in my subtree (the agency/client drill-down):
```sql
WITH RECURSIVE subtree(slug) AS (
  SELECT :root
  UNION
  SELECT o.slug FROM owners o JOIN subtree s ON o.parent_slug = s.slug
)
SELECT b.workspace,
       o.parent_slug,                          -- lets the UI nest team → client → agency
       SUM(b.tokens_in)  AS tin, SUM(b.tokens_out) AS tout,
       SUM(b.cost_credits)   AS upstream,       -- true COGS
       SUM(b.amount_credits) AS billed,         -- what this workspace paid
       SUM(b.agency_margin)  AS margin_earned   -- what the parent earned on it
FROM credit_burns b
JOIN subtree s ON s.slug = b.workspace
JOIN owners  o ON o.slug = b.workspace
WHERE b.test_mode = 0 AND b.ts > :since
GROUP BY b.workspace ORDER BY billed DESC;
```

**My own breakdown** — by reason + model (every audience, for their own card):
```sql
SELECT reason, model,
       SUM(tokens_in) AS tin, SUM(tokens_out) AS tout,
       SUM(cost_credits) AS upstream, SUM(amount_credits) AS billed
FROM credit_burns
WHERE workspace = :slug AND test_mode = 0 AND ts > :since
GROUP BY reason, model ORDER BY billed DESC;
```

**Owner (Tony) — COGS vs margin** across everything (`:root` = all top-level workspaces):
```sql
SELECT model,
       SUM(cost_credits)    AS cogs,            -- what ONE paid providers
       SUM(platform_margin) AS one_earned,
       SUM(agency_margin)   AS agencies_earned
FROM credit_burns WHERE test_mode = 0 AND ts > :since
GROUP BY model ORDER BY cogs DESC;
```

Every audience reads the **same ledger** with the **same query** — only `:root` changes. That's the
elegance: attribution is a recursive filter, not a pipeline, and "team" needed no new code.

### C5 — Surface to the UI (closes G5)

The billing pages already exist (`/u/[slug]/billing*`, gated by `BillingNav.astro`); the owner
already has `billing/platform.astro`. We **compose**, not rebuild:

- **One purpose-built component** — `<CostTree>` (React island), *not* a fork of `ClientsTable`. It
  answers one question — *"what's costing me, and where is it coming from?"* — on two axes at once:
  - **Who** (primary): a nested, expandable tree — agency → client → team — each row showing
    tokens, COGS, billed, and (for a parent) margin earned.
  - **What** (on expand): the model · reason breakdown for that workspace (inference / tool / voice).
  - A **summary band** on top (`HeroNumber` total + `RankedList` top cost sources) gives the answer
    at a glance before any drill-down.
  It's a new file but *composes* the existing `ui/` primitives (`Card`, `Badge`, `Table`, `Icon`) and
  dashboard cards (`RankedList`, `HeroNumber`) — no charting lib, matching `platform.astro`'s idiom.
- **Slot it into the billing pages by viewer:**

  | Route | Viewer | `:root` | What `<CostTree>` shows |
  |---|---|---|---|
  | `billing/platform.astro` | owner | all top-level | whole tree + COGS/margin (extends the existing owner page) |
  | `billing/costs.astro` (new) | agency | self | clients → teams, with margin earned per client |
  | `billing/costs.astro` | client | self | own spend + per-team breakdown |
  | `billing.astro` (pool) | team/leaf | self | own breakdown only (already there — add the by-model card) |

- **Subtree gating** — `<CostTree>` only ever receives the viewer's own subtree (the API roots the
  recursive CTE at the viewer's workspace and rejects a `:root` outside the viewer's chain), so a
  client can never see a sibling's costs. This closes the "no per-subtree gating" gap recon found.

Net UI surface: **1 component + 1 new route + 1 extended owner page.** Everything reads the C4 API.

---

## Why this is the simplest thing that works

- **No second ledger.** `credit_burns` already keys on workspace and splits the margins. We add
  capture, not storage.
- **Attribution is free.** `owners.parent_slug` already maps client→agency; rollup is `GROUP BY`.
- **Rate changes are a cache refresh,** not a code edit — and history is preserved because each burn
  stores its own tokens + the cost it computed at the time.
- **One capture point per cost type.** Inference: `wrapGenerate` (already runs on every call).
  Tool: `execute` wrapper. Both reuse the one pure `computeBurn`.
- **Reports reuse the existing `/api/billing/*` family** — no new route shapes (per `api.md`).
- **Teams are free.** The tenant tree is already arbitrary-depth `owners.parent_slug`; the recursive
  CTE already exists in `middleware.ts`. "Sub-groups under clients" needed *zero* new data model.
- **The UI already exists.** Four audiences, but one `<CostTree>` composed into the billing pages
  that ship today — the only difference between owner/agency/client/team is the subtree root.

Net new surface: **1 migration (3 columns), 1 cron, 1 KV-backed `rateFor`, 2 burn-capture wrappers,
1 recursive rollup query, 1 `<CostTree>` component + 1 route.** Everything else already exists.

---

## Documentation updates (W2)

| Doc | Change |
|---|---|
| `billing-costs.md` | note rates are now KV-sourced from OpenRouter (cron); config is fallback |
| `billing-taxonomy.md` | add `tokens_in/out`, `unit_count` to the burn-row contract |
| `channels/CLAUDE.md` | `substrateMiddleware` now also records an inference burn (not just mark) |
| `one.ie/web/src/components/CLAUDE.md` | new `<CostTree>` island — where it lives, which routes slot it |
| root `README.md` | if `/api/billing/*` gains a client-self + platform cost view, sync the row |

## Verification (W4)

1. **Replay:** for a 24h window, `Σ cost_credits == Σ rateFor(model)·tokens/1000` within 1 credit.
2. **No untracked inference:** count `doGenerate` traces in soak == count of `inference` burns.
3. **Recursive reconciliation:** a team's burn appears in its client's *and* its agency's subtree
   total; `Σ` per-descendant billed == the owner total for that root.
4. **Subtree gating:** a client requesting a sibling's `:root` is rejected; `<CostTree>` only renders
   the viewer's own chain.
5. `bun run verify` (tsc + vitest) green in both `one.ie/web` and `channels`; billing routes return
   2xx/401 post-deploy.
