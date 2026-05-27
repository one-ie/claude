# Prompt: ONE Billing Spreadsheet

> Paste everything below this line into Claude.ai. It contains all the data, structure, formulas, and design requirements needed to generate the spreadsheet in one pass.

---

Build a complete, beautiful billing spreadsheet for ONE — a white-label AI platform for agencies. The spreadsheet is the financial brain of the billing system: it calculates costs, models agency margins, sizes plans, and generates client-facing invoice breakdowns.

Deliver it as a Google Sheets document with named sheets, working formulas, conditional formatting, and charts. Every number that could change lives in the **Config** sheet. Everything else references Config — no hardcoded values anywhere except Config itself.

---

## The model in one paragraph

ONE sells credits. 1 credit = $0.0001 USD. Every billable action (AI inference, agent runs, voice, storage, API calls) burns credits from a pool. The platform takes a 10% margin on top of upstream provider costs. Agencies buy credits at the platform rate and resell them to clients at a markup they set. The retail price a client pays = `upstream × (1 + platform_margin%) × (1 + agency_markup%)`. The cascade is: platform → agency → client → team. Children can only lower a cap or raise a markup; neither can break the other's contract.

---

## Sheet 1: Config

The only sheet with hardcoded values. Every other sheet references these cells.

| Parameter | Value | Notes |
|-----------|-------|-------|
| `rate_usd_per_credit` | 0.0001 | $1 = 10,000 credits |
| `platform_margin_pct` | 10 | ONE's cut above upstream cost |
| `platform_floor_pct` | 5 | Minimum platform margin; cannot be undercut |
| `default_agency_markup_pct` | 20 | Agency's default resale margin |
| `billing_anchor` | monthly | Grant and cap reset frequency |
| `autotopup_threshold_pct` | 10 | Auto top-up fires when pool falls below this % of plan grant |
| `negative_floor_multiplier` | 1 | Floor = -1 × plan grant (chargeback protection) |
| `x402_creator_share_pct` | 75 | Creator's cut of x402 skill payment |
| `x402_agency_share_pct` | 10 | Agency cut of x402 skill payment |
| `x402_platform_share_pct` | 10 | Platform cut of x402 skill payment |
| `x402_protocol_fee_pct` | 5 | x402 network fee |

---

## Sheet 2: Models

AI model catalogue. Every inference cost derives from this sheet.

Columns: `model_id` · `provider` · `upstream_per_1k_input_tokens_cr` · `output_multiplier` · `upstream_per_1k_output_tokens_cr` (formula: input × mult) · `platform_rate_per_1k_input_cr` (formula: input × (1 + platform_margin/100)) · `platform_rate_per_1k_output_cr` · `retail_per_1k_input_cr` (formula: platform × (1 + agency_markup/100)) · `retail_per_1k_output_cr` · `upstream_per_1k_input_usd` · `retail_per_1k_input_usd` · `enabled`

Seed data:

| model_id | provider | upstream_in (cr/1k) | output_mult | enabled |
|----------|----------|---------------------|-------------|---------|
| claude-haiku-4-5 | Anthropic | 25 | 5 | TRUE |
| claude-opus-4-7 | Anthropic | 1500 | 5 | TRUE |
| gpt-5 | OpenAI | 1250 | 8 | TRUE |
| gemini-2-flash | Google | TBD | — | FALSE |
| llama-3-70b | Meta/OpenRouter | TBD | — | FALSE |

Include a worked example row beneath the table showing: "A 300-token input + 600-token output conversation with claude-haiku-4-5 costs X cr upstream / Y cr platform / Z cr retail."

---

## Sheet 3: Products

Complete product catalogue with three cost columns for every metered item.

Columns: `category` · `product` · `unit` · `billing_model` · `upstream_cr` · `platform_rate_cr` (formula) · `retail_rate_cr` (formula) · `upstream_usd` (formula) · `retail_usd` (formula) · `notes`

Billing models: `metered` / `gated` / `slotted` / `revenue_share`

Seed data — metered products:

| category | product | unit | upstream_cr |
|----------|---------|------|-------------|
| AI Inference | Text input | per 1K tokens | per-model (reference Models sheet) |
| AI Inference | Text output | per 1K tokens | input × output_mult |
| AI Inference | Voice input (STT) | per minute | 8 |
| AI Inference | Voice output (TTS) | per minute | 12 |
| AI Inference | Image generation | per image | TBD |
| AI Inference | Extended thinking | per 1K tokens | TBD |
| AI Inference | Embeddings | per 1K tokens | TBD |
| AI Inference | Document OCR | per page | TBD |
| AI Inference | Video analysis | per minute | TBD |
| Agents | Agent run | per run | 10 |
| Agents | Skill call | per invocation | 5 |
| Agents | Tool call | per invocation | cost-based |
| Agents | Scheduled agent | per execution | TBD |
| Agents | Autonomous agent | per minute | TBD |
| Storage | File storage | per GB/hour | 1 |
| Storage | Export archive | per export | 100 |
| Storage | Memory / KV | per GB/month | TBD |
| Storage | Knowledge base | per GB | TBD |
| Storage | Media (R2) | per GB/month | TBD |
| Channels | Public chat message | per message | 1 |
| Channels | API request overage | per request | 0.1 |
| Channels | Email sends | per 1K | TBD |
| Channels | SMS | per message | TBD |
| Channels | Push notifications | per 1K | TBD |
| Platform | Brand removal | per day | 30 |
| Payments | Credit transfer | per transfer | burn: transfer |
| Payments | Creator payout | per payout | burn: payout |

Gated products (no per-use cost — plan eligibility only):

| product | free | starter | pro | agency | min_role |
|---------|:----:|:-------:|:---:|:------:|:--------:|
| Brand removal | off | on | on | on | admin |
| Custom domain | off | on (1) | on (1) | on (n) | owner |
| Sub-workspace create | off | off | off | on | owner |
| White-label cascade | off | off | off | on | owner |
| SSO / SAML | off | off | off | off | owner |
| Team create | off | off | on (3) | on | owner |
| Premium models | off | metered | on | on | member |
| Voice input/output | metered | metered | on | on | member |
| API access | metered (60/h) | on (600/h) | on (6k/h) | on (60k/h) | member |
| Webhooks | off | on (1) | on (5) | on | admin |
| Attachments | metered | on | on | on | member |
| Export | metered | on | on | on | member |

Color-code rows by category: inference (blue), agents (purple), storage (green), channels (orange), platform (gold), gated (grey).

---

## Sheet 4: Plans

Platform plan definitions. Each plan is a column; each row is a parameter.

| Parameter | free | starter | pro | agency | enterprise |
|-----------|:----:|:-------:|:---:|:------:|:----------:|
| Monthly credit grant | 1,000 | 50,000 | 500,000 | 5,000,000 | custom |
| Monthly price (USD) | $0 | $5 | $50 | $500 | custom |
| Price per credit (USD) | — | $0.0001 | $0.0001 | $0.0001 | negotiate |
| Max seats | unlimited | 5 | 25 | unlimited | unlimited |
| Max published agents | 5 | 20 | 100 | unlimited | unlimited |
| Max client workspaces | — | — | — | 50 | 999 |
| Skill publish slots | off | metered | on | on | on |
| Brand removal | off | on | on | on | on |
| Custom domain | off | 1 | 1 | unlimited | unlimited |
| Sub-workspace create | off | off | off | on | on |
| White-label cascade | off | off | off | on | on |
| Premium models | off | metered | on | on | on |
| Voice input/output | metered | metered | on | on | on |
| API access (req/hr) | 60 | 600 | 6,000 | 60,000 | custom |
| Webhooks | off | 1 | 5 | unlimited | unlimited |

Add a computed row for each plan: **cost per credit at platform rate** (grant × 0.0001 × 1.10 / plan price), **cost per credit at 20% agency markup**, and **break-even conversations** (plan price ÷ avg conversation cost at the default model).

Add a summary chart: Grant size vs. price per plan as a bar chart.

---

## Sheet 5: Agency Setup

One section for the agency owner to configure their resale parameters. Inputs in yellow cells.

**Agency config:**
- Agency slug (text input)
- Agency markup % (default: 20, min: platform_floor_pct from Config)
- Client default plan (dropdown: free / starter / pro / agency)
- Brand lock (TRUE/FALSE)
- Display currency (USD / EUR / GBP)

**Computed outputs (auto-calculated, not editable):**
- Effective credit rate to clients (USD) = `rate_usd_per_credit × (1 + platform_margin/100) × (1 + agency_markup/100)`
- Agency gross margin % = `agency_markup / (1 + agency_markup/100) × 100`
- Platform floor effective rate (USD)
- Minimum retail credit price (USD) — floor Brad cannot go below

**Markup sensitivity table** (auto-generated):

| Agency markup % | Retail price per credit | Gross margin % | Monthly revenue on 5M credits |
|:---------------:|:----------------------:|:--------------:|:-----------------------------:|
| 5% (floor) | formula | formula | formula |
| 10% | formula | formula | formula |
| 15% | formula | formula | formula |
| 20% (default) | formula | formula | formula |
| 25% | formula | formula | formula |
| 30% | formula | formula | formula |
| 50% | formula | formula | formula |

Highlight the agency's current markup row in the table.

---

## Sheet 6: Client Calculator

Single-client cost and revenue model. All usage inputs in yellow cells.

**Client info:**
- Client name
- Plan (dropdown: free / starter / pro / agency)
- Monthly cap (credits, optional)
- Agency markup override % (defaults to Agency Setup value)

**Usage inputs (monthly estimates):**
- Primary model (dropdown from Models sheet)
- Number of conversations
- Avg input tokens per conversation
- Avg output tokens per conversation
- Agent runs
- Skill calls
- Voice input minutes
- Voice output minutes
- Storage GB
- API requests (overage only)
- Brand removal days (0–31)
- Export archives

**Computed outputs:**

| Line item | Credits (upstream) | Credits (platform rate) | Credits (retail) | USD (retail) |
|-----------|:-----------------:|:----------------------:|:----------------:|:------------:|
| Text inference (input) | formula | formula | formula | formula |
| Text inference (output) | formula | formula | formula | formula |
| Agent runs | formula | formula | formula | formula |
| Skill calls | formula | formula | formula | formula |
| Voice input | formula | formula | formula | formula |
| Voice output | formula | formula | formula | formula |
| Storage | formula | formula | formula | formula |
| API overage | formula | formula | formula | formula |
| Brand removal | formula | formula | formula | formula |
| Export | formula | formula | formula | formula |
| **Total burn** | **formula** | **formula** | **formula** | **formula** |
| Plan grant | — | — | — | plan price |
| **Balance after burn** | — | — | — | formula |
| **Agency margin ($)** | — | — | — | formula |
| **Agency margin (%)** | — | — | — | formula |

Add a donut chart showing burn breakdown by category (inference / agents / voice / storage / other).

Add a health indicator: GREEN if burn < 80% of plan grant, AMBER if 80–95%, RED if > 95%.

---

## Sheet 7: Agency Dashboard

Multi-client view. Brad's full book at a glance.

**Input table** — one row per client (add rows as needed):

Columns: `client_name` · `plan` · `monthly_cap` · `markup_override_%` · `conversations` · `avg_tokens_in` · `avg_tokens_out` · `agent_runs` · `voice_minutes` · `other_credits`

**Computed columns (formulas, no manual input):**
- `total_burn_credits`
- `total_burn_usd_upstream`
- `total_burn_usd_retail`
- `plan_price_usd`
- `total_revenue_usd` (retail burn + plan price)
- `gross_margin_usd`
- `gross_margin_%`
- `pool_health` (GREEN / AMBER / RED)

**Summary row (totals):**
- Total clients
- Total monthly revenue (USD)
- Total upstream cost (USD)
- Total platform margin captured by ONE (USD)
- Total agency gross profit (USD)
- Blended gross margin %

**Annual projection section:**
- Monthly revenue × 12
- Monthly cost × 12
- Annual gross profit
- At 50 clients (scale simulation)
- At 200 clients (scale simulation)
- At 5,400 clients (Brad's target from the pitch)

**Charts:**
1. Revenue vs. cost by client (grouped bar)
2. Gross margin % per client (horizontal bar, sorted descending)
3. Monthly revenue growth curve (line chart, with 50/200/5400 client milestones)

---

## Sheet 8: Scenario Planner

What-if modelling. Every cell is a formula or a yellow input.

**Three scenarios side by side:** Conservative / Base / Optimistic

Inputs per scenario:
- Number of clients
- Average monthly revenue per client (USD)
- Blended agency markup %
- Average conversations per client per month
- Average tokens per conversation (input + output)
- Primary model mix (% haiku / % opus / % gpt-5)
- Churn rate % per month

Computed outputs per scenario:
- Gross monthly revenue
- Upstream cost (USD)
- Platform margin (USD, captured by ONE)
- Agency gross profit (USD)
- Agency gross margin %
- Annual recurring revenue
- Monthly new clients needed to offset churn
- Break-even client count (where agency profit > agency plan cost)

**Markup sensitivity chart** — line chart showing gross margin % across markup % values from 5% to 50%, for each of the three scenarios.

**Model mix impact table** — how gross margin changes as haiku vs. opus usage shifts:

| Haiku % | Opus % | GPT-5 % | Blended upstream/conv | Retail/conv | Margin/conv |
|:-------:|:------:|:-------:|:---------------------:|:-----------:|:-----------:|
| 100% | 0% | 0% | formula | formula | formula |
| 80% | 20% | 0% | formula | formula | formula |
| 60% | 30% | 10% | formula | formula | formula |
| 40% | 40% | 20% | formula | formula | formula |
| 20% | 60% | 20% | formula | formula | formula |

---

## Sheet 9: Invoice Preview

What a client sees. No markup, no platform margin, no internal rates visible.

**Header section (branded):**
- Client name
- Agency name (white-label — ONE never appears)
- Invoice period
- Plan name and monthly grant

**Line items:**
- AI usage (conversations × model) — credits consumed + USD at client rate
- Agent and skill activity — credits + USD
- Voice — credits + USD
- Storage — credits + USD
- Other — credits + USD
- **Total usage (credits)**
- **Total usage (USD)**
- Plan subscription (USD)
- **Total due (USD)**

**Pool status:**
- Opening balance
- Credits granted this period
- Credits consumed this period
- Closing balance
- Auto top-up events (if any)

**Note at bottom:** "Credit rate: $X per credit. All rates fixed at grant time."

The client never sees upstream costs, platform margin, or agency markup. Only the retail rate they agreed to.

---

## Visual design requirements

- **Color palette:** Dark navy headers (#0F172A), white text on headers, light grey alternating rows (#F8FAFC / white), category accent colors per product group
- **Fonts:** Use a clean sans-serif. Headers bold. Data cells regular weight.
- **Input cells:** Yellow fill (#FEF9C3) with a light border so users know what to edit
- **Computed cells:** No fill (white/grey row alternation). Locked from editing.
- **Health indicators:** Conditional formatting — GREEN (#DCFCE7 fill, #166534 text), AMBER (#FEF9C3, #854D0E), RED (#FEE2E2, #991B1B)
- **Currency formatting:** $#,##0.00 for USD cells; #,##0 for credit cells; 0.0% for percentage cells
- **Charts:** Clean, minimal. No 3D. No grid lines on charts. Subtle drop shadows on summary cards.
- **Sheet tabs:** Color-coded. Config (grey), Models (blue), Products (indigo), Plans (violet), Agency Setup (amber), Client Calculator (green), Dashboard (teal), Scenarios (orange), Invoice (white)
- **Freeze panes:** Freeze the header row on every sheet. Freeze the first column on wide sheets (Dashboard, Products).
- **Print area:** Invoice Preview sheet should be print-ready at A4/Letter.

---

## Formula conventions

- All percentage inputs stored as whole numbers (20 = 20%, not 0.20). Convert in formulas.
- Credit → USD conversion: `=credits * Config!rate_usd_per_credit`
- Platform rate: `=upstream_cr * (1 + Config!platform_margin_pct/100)`
- Retail rate: `=platform_cr * (1 + agency_markup_pct/100)`
- Gross margin %: `=agency_markup_pct / (100 + agency_markup_pct)` (markup on cost → margin on revenue)
- Health check: `=IF(burn/grant > 0.95, "RED", IF(burn/grant > 0.80, "AMBER", "GREEN"))`
- Use named ranges for all Config values so formulas read `platform_margin_pct` not `Config!B3`

---

## Delivery

Produce the full spreadsheet. For each sheet:
1. Show the column headers
2. Show the seed data rows
3. Show the key formulas (written out in full, using named ranges)
4. Show the conditional formatting rules
5. Describe any charts (type, data range, axes)

Where a formula depends on a user input that hasn't been filled yet, use a placeholder value that makes the formula testable (e.g., assume 500 conversations, 300 tokens in, 600 tokens out, claude-haiku-4-5 as the model).

The finished spreadsheet should answer three questions in under 30 seconds:
1. What does it cost ONE to deliver any given product?
2. What does Brad charge a client for it, at his markup?
3. What is Brad's gross profit across his whole book, this month?
