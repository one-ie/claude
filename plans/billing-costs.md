# Billing Costs

Every cost ONE incurs to deliver a billable product. This is the floor — the minimum credit rate that covers cost before margin is applied.

**Conversion:** 1 credit = $0.0001. `credits_per_1k_tokens = usd_per_1m_tokens / 100`

*Inference prices sourced from OpenRouter API (`GET /api/v1/models`) on 2026-05-27. Re-fetch to verify before changing billing-config.ts.*

---

## Inference — OpenRouter

### Complete model catalogue (curated, priced models only)

| Model | OpenRouter ID | Input $/1M | Output $/1M | Input cr/1K | Output cr/1K |
|-------|--------------|:----------:|:-----------:|:-----------:|:------------:|
| **Anthropic** | | | | | |
| Claude Haiku 4.5 | `anthropic/claude-haiku-4.5` | $1.00 | $5.00 | 10 | 50 |
| Claude Haiku Latest | `~anthropic/claude-haiku-latest` | $1.00 | $5.00 | 10 | 50 |
| Claude Sonnet 4.5 | `anthropic/claude-sonnet-4.5` | $3.00 | $15.00 | 30 | 150 |
| Claude Sonnet 4.6 | `anthropic/claude-sonnet-4.6` | $3.00 | $15.00 | 30 | 150 |
| Claude Sonnet Latest | `~anthropic/claude-sonnet-latest` | $3.00 | $15.00 | 30 | 150 |
| Claude Opus 4.5 | `anthropic/claude-opus-4.5` | $5.00 | $25.00 | 50 | 250 |
| Claude Opus 4.6 | `anthropic/claude-opus-4.6` | $5.00 | $25.00 | 50 | 250 |
| Claude Opus 4.7 | `anthropic/claude-opus-4.7` | $5.00 | $25.00 | 50 | 250 |
| Claude Opus Latest | `~anthropic/claude-opus-latest` | $5.00 | $25.00 | 50 | 250 |
| Claude Opus 4 | `anthropic/claude-opus-4` | $15.00 | $75.00 | 150 | 750 |
| Claude Opus 4.1 | `anthropic/claude-opus-4.1` | $15.00 | $75.00 | 150 | 750 |
| Claude Opus 4.7 Fast | `anthropic/claude-opus-4.7-fast` | $30.00 | $150.00 | 300 | 1500 |
| Claude Opus 4.6 Fast | `anthropic/claude-opus-4.6-fast` | $30.00 | $150.00 | 300 | 1500 |
| **OpenAI** | | | | | |
| GPT-4o-mini | `openai/gpt-4o-mini` | $0.15 | $0.60 | 1.5 | 6 |
| GPT-4.1 Nano | `openai/gpt-4.1-nano` | $0.10 | $0.40 | 1 | 4 |
| GPT-4.1 Mini | `openai/gpt-4.1-mini` | $0.40 | $1.60 | 4 | 16 |
| GPT-4o | `openai/gpt-4o` | $2.50 | $10.00 | 25 | 100 |
| GPT-4.1 | `openai/gpt-4.1` | $2.00 | $8.00 | 20 | 80 |
| GPT-4o Audio | `openai/gpt-4o-audio-preview` | $2.50 | $10.00 | 25 | 100 |
| GPT-5 | not yet on OpenRouter | — | — | — | — |
| **Google** | | | | | |
| Gemini 2.0 Flash Lite | `google/gemini-2.0-flash-lite-001` | $0.08 | $0.30 | 0.75 | 3 |
| Gemini 2.0 Flash | `google/gemini-2.0-flash-001` | $0.10 | $0.40 | 1 | 4 |
| Gemini 2.5 Flash Lite | `google/gemini-2.5-flash-lite` | $0.10 | $0.40 | 1 | 4 |
| Gemini 2.5 Flash | `google/gemini-2.5-flash` | $0.30 | $2.50 | 3 | 25 |
| Gemini 2.5 Pro | `google/gemini-2.5-pro` | $1.25 | $10.00 | 12.5 | 100 |
| **Meta** | | | | | |
| Llama 3.3 70B | `meta-llama/llama-3.3-70b-instruct` | $0.10 | $0.32 | 1 | 3.2 |
| Llama 4 Scout | `meta-llama/llama-4-scout` | $0.08 | $0.30 | 0.8 | 3 |
| Llama 4 Maverick | `meta-llama/llama-4-maverick` | $0.15 | $0.60 | 1.5 | 6 |
| **DeepSeek** | | | | | |
| DeepSeek V3 | `deepseek/deepseek-chat` | $0.23 | $0.91 | 2.3 | 9.1 |
| DeepSeek V3 0324 | `deepseek/deepseek-chat-v3-0324` | $0.20 | $0.77 | 2 | 7.7 |
| DeepSeek V3.1 | `deepseek/deepseek-chat-v3.1` | $0.21 | $0.79 | 2.1 | 7.9 |
| DeepSeek R1 | `deepseek/deepseek-r1` | $0.70 | $2.50 | 7 | 25 |
| DeepSeek R1 0528 | `deepseek/deepseek-r1-0528` | $0.50 | $2.15 | 5 | 21.5 |
| DeepSeek R1 Distill 70B | `deepseek/deepseek-r1-distill-llama-70b` | $0.70 | $0.80 | 7 | 8 |
| **Mistral** | | | | | |
| Mistral Small 3 | `mistralai/mistral-small-24b-instruct-2501` | $0.05 | $0.08 | 0.5 | 0.8 |
| Mistral Small 3.2 | `mistralai/mistral-small-3.2-24b-instruct` | $0.08 | $0.20 | 0.75 | 2 |
| Mistral Small 4 | `mistralai/mistral-small-2603` | $0.15 | $0.60 | 1.5 | 6 |
| Mistral Large | `mistralai/mistral-large` | $2.00 | $6.00 | 20 | 60 |
| Mistral Large 3 | `mistralai/mistral-large-2512` | $0.50 | $1.50 | 5 | 15 |
| **Qwen** | | | | | |
| Qwen3 8B | `qwen/qwen3-8b` | $0.05 | $0.40 | 0.5 | 4 |
| Qwen3 14B | `qwen/qwen3-14b` | $0.10 | $0.24 | 1 | 2.4 |
| Qwen3 32B | `qwen/qwen3-32b` | $0.08 | $0.28 | 0.8 | 2.8 |
| Qwen3 30B A3B | `qwen/qwen3-30b-a3b` | $0.09 | $0.45 | 0.9 | 4.5 |
| Qwen3 235B A22B | `qwen/qwen3-235b-a22b` | $0.45 | $1.82 | 4.5 | 18.2 |
| Qwen3 Max | `qwen/qwen3-max` | $0.78 | $3.90 | 7.8 | 39 |
| Qwen3 Coder | `qwen/qwen3-coder` | $0.22 | $1.80 | 2.2 | 18 |

### Free / open-weight models (no inference cost)

These route via OpenRouter free tier or self-hosted. No upstream charge — cost is compute only (covered by Cloudflare Workers billing).

| Model | OpenRouter ID |
|-------|--------------|
| Llama 3.3 70B | `meta-llama/llama-3.3-70b-instruct:free` |
| Qwen3 Coder 480B | `qwen/qwen3-coder:free` |
| DeepSeek V4 Flash | `deepseek/deepseek-v4-flash:free` |
| Gemma 4 31B | `google/gemma-4-31b-it:free` |

### Typical conversation cost

300 input + 600 output tokens at each tier:

| Model | Total cost upstream | Credits |
|-------|:-------------------:|:-------:|
| Gemini 2.0 Flash Lite | $0.000206 | 2.1 cr |
| Llama 3.3 70B | $0.000222 | 2.2 cr |
| GPT-4.1 Nano | $0.000270 | 2.7 cr |
| GPT-4o-mini | $0.000390 | 3.9 cr |
| DeepSeek V3 | $0.000615 | 6.2 cr |
| **Claude Haiku 4.5** | $0.003300 | **33 cr** |
| GPT-4.1 Mini | $0.001080 | 10.8 cr |
| Gemini 2.5 Flash | $0.001590 | 15.9 cr |
| GPT-4.1 | $0.005400 | 54 cr |
| GPT-4o | $0.006750 | 67.5 cr |
| Claude Sonnet | $0.009900 | 99 cr |
| Claude Opus 4.5–4.7 | $0.016500 | 165 cr |
| Claude Opus 4 | $0.049500 | 495 cr |
| Claude Opus 4.7 Fast | $0.099000 | 990 cr |

### billing-config.ts calibration

Current config vs. verified API prices. `upstream_per_1k_in` should equal `input_usd_per_1m / 100`.

| Config model ID | Config upstream_per_1k_in | API actual cr/1K in | Delta | Status |
|-----------------|:-------------------------:|:-------------------:|:-----:|--------|
| `claude-haiku-4-5` | 25 cr | 10 cr | +15 cr | Over by 2.5× — intentional buffer or adjust to 10 |
| `claude-opus-4-7` | 1,500 cr | 50 cr (standard) / 300 cr (fast) | +1450 / +1200 cr | Far over — likely stale; update to 50 or 300 depending on which variant |
| `gpt-5` | 1,250 cr | not on OpenRouter yet | — | Keep disabled until available |

**Recommendation:** Set `upstream_per_1k_in` to the exact OpenRouter API cost. The platform margin (10%) and agency markup are applied on top — no need to bake extra margin into the upstream value itself. If you want a model to feel premium, raise the markup on that model, not the upstream.

---

## Tool integrations — Composio

Every external app tool call (Gmail, Slack, HubSpot, Notion, GitHub, etc.) routes through Composio.

| Plan | Included calls/month | Overage per 1K | Monthly cost |
|------|:--------------------:|:--------------:|:------------:|
| Free | 20,000 | — | $0 |
| Mid | 200,000 | $0.299 | $29 |
| Business | 2,000,000 | $0.249 | $229 |
| Enterprise | custom | custom | contact |

**Cost per call:**
- Mid plan included: $29 / 200,000 = **$0.000145/call = 1.45 cr/call**
- Mid overage: **$0.000299/call = 2.99 cr/call**
- Business overage: **$0.000249/call = 2.49 cr/call**

Current `tool_call` burn uses `cost-based` — pass the actual Composio per-call cost as `cost_credits` on each burn. Do not use a flat rate; the effective cost depends on which plan tier ONE is on at time of call.

---

## Infrastructure — Cloudflare

All compute, database, storage, and real-time runs on Cloudflare ($5/month paid plan base).

### Workers

| Resource | Included | Overage |
|----------|----------|---------|
| Requests | 10M/month | $0.30/M |
| CPU time | 30M CPU-ms/month | $0.02/M CPU-ms |

A chat API call uses ~5–20ms CPU. At 1M conversations/month: ~20M CPU-ms (within included). At 10M: ~200M CPU-ms → ~$3.40 overage.

### D1 (database)

| Resource | Included | Overage |
|----------|----------|---------|
| Rows read | 25B/month | $0.001/M |
| Rows written | 50M/month | $1.00/M |
| Storage | 5 GB | $0.75/GB-month |

### Workers KV (sessions, billing config, snapshots)

| Resource | Included | Overage |
|----------|----------|---------|
| Reads | 10M/month | $0.50/M |
| Writes | 1M/month | $5.00/M |
| Storage | 1 GB | $0.50/GB-month |

### R2 (backups, exports, corpus)

| Resource | Cost |
|----------|------|
| Storage | $0.015/GB-month |
| Write (Class A) | $4.50/M ops |
| Read (Class B) | $0.36/M ops |
| Egress | **free** |

### Durable Objects (WsHub, AnalyticsRelay)

| Resource | Included | Overage |
|----------|----------|---------|
| Requests | 1M/month | $0.15/M |
| Duration | 400K GB-seconds/month | $12.50/M GB-seconds |

**Total Cloudflare estimate:** $5–$50/month at early scale (sub-1M monthly active users). Model $100–$300/month at 10M+ monthly requests.

---

## Payments — Stripe

Pass-through cost on every fiat transaction. Does not enter the credit ledger; reduces net revenue.

| Transaction type | Fee |
|-----------------|-----|
| UK standard card | 1.5% + £0.20 |
| UK premium card | 1.9% + £0.20 |
| EEA card | 2.5% + £0.20 |
| International card | 3.25% + £0.20 |
| Currency conversion | +2.0% |
| Stripe Billing (subscriptions) | 0.7% of billing volume |

Impact by plan: $5 starter + UK card = £0.28 Stripe fee = **5.5% of revenue**. $500 agency + UK card = £7.70 = **1.5% of revenue**. Subscriptions are more margin-efficient at higher plan values.

x402 crypto top-ups carry no Stripe fee — only the 5% x402 protocol fee already in the burn model.

---

## Email — Resend

| Plan | Monthly emails | Cost | Per-1K cost |
|------|:--------------:|:----:|:-----------:|
| Free | 3,000 (100/day cap) | $0 | $0 |
| Pro 50K | 50,000 | $20 | $0.40 |
| Pro 100K | 100,000 | $35 | $0.35 |
| Scale 500K | 500,000 | $90 | $0.18 |

**Per-email credit equivalent:** $0.40/1K = **4 cr/email** at the Pro tier.
Free tier covers ~600 workspaces at 5 emails/workspace/month.
Not yet metered in billing-config.ts — listed TBD in products.md. Add `email_send` burn reason at ≥4 cr/email before email volume scales.

---

## Voice — STT / TTS

Not yet fully wired. Costs exist from the moment they are. **Both current config values are below actual provider cost.**

### Speech-to-text

| Provider | Model | Cost/minute | Credits/minute |
|----------|-------|:-----------:|:--------------:|
| Deepgram | Nova-2 | $0.0043 | 43 cr |
| OpenAI | Whisper | $0.006 | 60 cr |
| AssemblyAI | Best | $0.0062 | 62 cr |

Current config `voice_per_minute_in: 8` covers nothing. **Minimum viable: 43–60 cr/min.**

### Text-to-speech

| Provider | Model | Cost/1M chars | Cost/minute (~3,750 chars) | Credits/minute |
|----------|-------|:-------------:|:--------------------------:|:--------------:|
| OpenAI | TTS | $15 | $0.056 | 563 cr |
| OpenAI | TTS HD | $30 | $0.113 | 1,125 cr |
| ElevenLabs | Flash | ~$11 | ~$0.041 | ~413 cr |
| Google | WaveNet | $16 | $0.060 | 600 cr |

Current config `voice_per_minute_out: 12` covers nothing. **Minimum viable: 400–600 cr/min.**

---

## TypeDB Cloud

Managed subscription for the substrate brain. Pricing varies by instance size — verify directly with TypeDB/Vaticle.

**Estimate for planning:** $200–$500/month for a production multi-tenant instance.

---

## Other costs

| Item | Estimate/month | Notes |
|------|:--------------:|-------|
| Domain (one.ie) | ~$8 | Annual, pro-rated |
| GitHub | $0–$21 | Free for public; Team plan if private |
| Sentry (error monitoring) | $0–$26 | Free tier sufficient at early scale |
| Uptime monitoring | $0–$20 | Better Uptime / UptimeRobot free tiers |

---

---

## Per-session cost stack

Assumptions: 3-turn conversation, 1,500 input + 900 output tokens total per session.

`upstream → + 10% platform → + 20% agency markup → client pays`

| Model | Upstream cr | Platform (×1.1) | Agency (×1.2) | Client pays | ONE earns | Agency earns |
|-------|:-----------:|:---------------:|:-------------:|:-----------:|:---------:|:------------:|
| Gemini 2.0 Flash | 4.9 cr | 5.4 cr | 6.5 cr | 6.5 cr | 0.5 cr | 1.1 cr |
| GPT-4.1 Nano | 5.1 cr | 5.6 cr | 6.7 cr | 6.7 cr | 0.5 cr | 1.1 cr |
| Llama 4 Scout (free) | 0 cr | 0 cr | 0 cr | 0 cr | 0 | 0 |
| Claude Haiku 4.5 | 55 cr | 60.5 cr | 72.6 cr | 72.6 cr | 5.5 cr | 12.1 cr |
| Gemini 2.5 Flash | 24.8 cr | 27.2 cr | 32.7 cr | 32.7 cr | 2.5 cr | 5.5 cr |
| Claude Sonnet | 180 cr | 198 cr | 237.6 cr | 237.6 cr | 18 cr | 39.6 cr |
| Claude Opus 4.5–4.7 | 300 cr | 330 cr | 396 cr | 396 cr | 30 cr | 66 cr |
| Claude Opus 4 | 900 cr | 990 cr | 1,188 cr | 1,188 cr | 90 cr | 198 cr |

_ONE earns = upstream × 0.10 (platform\_margin\_pct). Agency earns = platform\_cost × 0.20 (markup\_pct). No agency: client pays platform rate (×1.1 only)._

The free model tier (Llama, Gemini Flash free) earns nothing from inference — revenue depends entirely on plan subscription and metered product burns.

---

## Client usage profiles

Five recurring client archetypes. Credits are upstream cost before margins; what the client is billed = upstream × 1.1 (platform) × 1.2 (agency, if applicable).

### Profile A — Embedded chatbot (small business)

Website FAQ / support widget. Light usage, budget model.

| Item | Volume | Upstream cr/unit | Monthly credits |
|------|-------:|:----------------:|----------------:|
| Haiku inference | 200 sessions × 2,400 tokens | 55 cr/session | 11,000 cr |
| Public chat burns | 200 × 4 msgs | 1 cr/msg | 800 cr |
| Brand removal | 30 days | 30 cr/day | 900 cr |
| **Total upstream** | | | **12,700 cr** |

- Client billed: ~17,000 cr (×1.32 with agency markup)
- Plan fit: **starter** (50,000 cr grant) — uses 34% of grant
- ONE earns from burns: ~1,155 cr = **$0.12/month** + plan subscription margin

---

### Profile B — Team workspace (5-person startup)

Daily AI assistant for a small team. Mixed models, some automation.

| Item | Volume | Upstream cr/unit | Monthly credits |
|------|-------:|:----------------:|----------------:|
| Haiku inference | 140 sessions | 55 cr | 7,700 cr |
| Sonnet inference | 60 sessions | 180 cr | 10,800 cr |
| Agent runs | 50 runs | 10 cr | 500 cr |
| Skill calls | 100 calls | 5 cr | 500 cr |
| Tool calls (Composio) | 20 calls | 1.45 cr | 29 cr |
| **Total upstream** | | | **19,529 cr** |

- Client billed: ~25,800 cr (×1.32)
- Plan fit: **starter** (50,000 cr) — uses 52% of grant
- ONE earns from burns: ~1,775 cr = **$0.18/month** + plan margin

---

### Profile C — Power user (freelancer / heavy daily use)

One person, 20 sessions/day × 22 working days. Sonnet default.

| Item | Volume | Upstream cr/unit | Monthly credits |
|------|-------:|:----------------:|----------------:|
| Sonnet inference | 440 sessions | 180 cr | 79,200 cr |
| Agent runs | 100 runs | 10 cr | 1,000 cr |
| Tool calls (Composio) | 200 calls | 1.45 cr | 290 cr |
| Export archives | 2 | 100 cr | 200 cr |
| **Total upstream** | | | **80,690 cr** |

- Client billed: ~106,500 cr (×1.32)
- Plan fit: **pro** (500,000 cr) — uses 21% of grant. Significant headroom for growth.
- ONE earns from burns: ~7,335 cr = **$0.73/month** + plan margin

---

### Profile D — Voice assistant client (support centre, 100 calls/day)

High-volume voice; TTS dominates cost. Pricing must reflect actual TTS rates, not current config.

| Item | Volume | Upstream cr/unit | Monthly credits |
|------|-------:|:----------------:|----------------:|
| STT (Deepgram Nova-2) | 2,200 calls × 5 min | 43 cr/min | 473,000 cr |
| TTS (OpenAI TTS) | 2,200 calls × 5 min | 563 cr/min | 6,193,000 cr |
| Haiku inference | 2,200 sessions | 55 cr | 121,000 cr |
| Agent runs | 2,200 | 10 cr | 22,000 cr |
| **Total upstream** | | | **6,809,000 cr** |

- Client billed: ~9,000,000 cr (×1.32) = **$900/month**
- Plan fit: **agency** (5M cr) not enough — requires enterprise or credit top-ups
- ONE earns from burns: ~618,000 cr = **$61.8/month** from this one client
- _Note: current billing-config.ts voice rates (8/12 cr) would lose $670+/month on this client._

---

### Profile E — E-commerce agent (automated order/support)

Agent-heavy, tool-heavy. No voice.

| Item | Volume | Upstream cr/unit | Monthly credits |
|------|-------:|:----------------:|----------------:|
| Haiku inference | 11,000 agent runs × 2K tokens | 24 cr/run | 264,000 cr |
| Agent run base | 11,000 | 10 cr | 110,000 cr |
| Skill calls | 33,000 (3/run) | 5 cr | 165,000 cr |
| Tool calls (Composio) | 22,000 (2/run) | 1.45 cr | 31,900 cr |
| Public chat | 11,000 × 3 msgs | 1 cr | 33,000 cr |
| **Total upstream** | | | **603,900 cr** |

- Client billed: ~797,200 cr (×1.32) = **$79.7/month**
- Plan fit: **pro** (500K) runs over; **agency** (5M) uses 16% of grant
- ONE earns from burns: ~54,900 cr = **$5.49/month**

---

## Agency economics

### Small agency (10 clients, mixed: 7 starter + 3 pro)

| Line | Credits/month | USD |
|------|:-------------:|:----|
| Client burns (starter × 7) | 7 × 19,529 = 136,703 cr | — |
| Client burns (pro × 3) | 3 × 80,690 = 242,070 cr | — |
| **Total client burns** | **378,773 cr** | — |
| Agency markup revenue (20%) | 75,755 cr | **$7.58/month** |
| ONE platform margin (10%) | 34,434 cr | ONE earns $3.44/month |
| Agency infrastructure cost (plan) | — | plan subscription |

Agency earns $7.58/month in credit markup. Most revenue is from plan subscriptions billed to clients — markup is supplemental.

---

### Mid agency (50 clients: 20 free, 20 starter, 10 pro)

| Line | Credits/month | USD |
|------|:-------------:|:----|
| Free clients (20) | 20 × 5,000 ≈ 100,000 cr | — |
| Starter clients (20) | 20 × 19,529 = 390,580 cr | — |
| Pro clients (10) | 10 × 80,690 = 806,900 cr | — |
| **Total burns** | **1,297,480 cr** | — |
| Agency markup (20%) | 259,496 cr | **$25.95/month** |
| ONE platform margin | 117,953 cr | ONE earns $11.80/month |

---

### Large agency (200 clients: 50 free, 100 starter, 40 pro, 10 voice/enterprise)

| Line | Credits/month | USD |
|------|:-------------:|:----|
| Free (50) | 50 × 5,000 = 250,000 cr | — |
| Starter (100) | 100 × 19,529 = 1,952,900 cr | — |
| Pro (40) | 40 × 80,690 = 3,227,600 cr | — |
| Voice (10) | 10 × 6,809,000 = 68,090,000 cr | — |
| **Total burns** | **73,520,500 cr** | — |
| Agency markup (20%) | 14,704,100 cr | **$1,470/month** |
| ONE platform margin | 6,683,682 cr | ONE earns **$668/month** |

Voice clients dominate: 10 voice clients = 93% of all burns in the large agency scenario.

---

## ONE platform P&L

### Break-even on fixed costs

Fixed baseline: $215–$610/month (TypeDB + Cloudflare + misc).

| Scale | Monthly burns (platform-wide) | ONE margin (10%) | Fixed cost | Net |
|-------|:----------------------------:|:----------------:|:----------:|:---:|
| 5 agency plans | 5 × 1.3M = 6.5M cr | 650K cr = **$65** | $415 | –$350 |
| 20 agency plans | 20 × 1.3M = 26M cr | 2.6M cr = **$260** | $415 | –$155 |
| 50 agency plans | 50 × 1.3M = 65M cr | 6.5M cr = **$650** | $415 | **+$235** |
| 3 voice enterprise clients | 3 × 68M = 204M cr | 20.4M cr = **$2,040** | $415 | **+$1,625** |

Three large voice-enabled enterprise clients cover ONE's entire fixed infrastructure. At typical agency scale (no voice), break-even requires ~35–45 active agency-plan workspaces purely from burn margins — ignoring plan subscription revenue which arrives before burns happen.

### Revenue from plan subscriptions vs. burns

Plan subscription revenue (upfront, recurring) is the predictable base. Burn margins are the variable layer that scales with client activity.

| Plan | Grant value | ONE's COGS at 100% burn (Haiku) | ONE's gross (sub - COGS) |
|------|:-----------:|:-------------------------------:|:------------------------:|
| Free | $0.10 | $0.091 | –$0.09 (loss leader) |
| Starter | $5.00 | $0.45/month if fully burned on Haiku | $4.55+ |
| Pro | $50.00 | $4.55 if fully burned on Haiku | $45.45+ |
| Agency | $500.00 | $45.50 if fully burned on Haiku | $454.50+ |

_COGS = grant × (upstream / platform\_rate) = grant × (1/1.1). Most grants are never fully burned; ONE's actual COGS is lower than the worst case above._

---

## Non-inference product margins

Products whose cost to ONE is near-zero, making them pure-margin additions to any subscription.

| Product | Billed rate | ONE's infra cost | Gross margin |
|---------|:-----------:|:----------------:|:------------:|
| Brand removal | 30 cr/day ($0.09/month) | ~0 (config flag) | **~100%** |
| API overage | 0.1 cr/request | ~0.005 cr (Worker CPU) | **95%** |
| Public chat message | 1 cr/msg | ~0.015 cr (D1 write + Worker) | **98.5%** |
| Export archive | 100 cr | ~0.05 cr (R2 write, ~500KB) | **99.9%** |
| File storage | 1 cr/GB-hour | $0.015/GB-month → 2.1 cr/GB-month → 0.003 cr/hour | **99.7%** |

These products generate margin with no upstream supplier dependency. They should be included in every plan.

---

## Missing cost estimates (TBD products)

Products listed in products.md with no upstream cost nailed down. Estimates for planning:

| Product | Best provider | Estimated cost | Suggested floor rate |
|---------|--------------|:--------------:|:--------------------:|
| Image generation | OpenAI DALL-E 3 | $0.04/image (1024px) | 400 cr/image |
| Image generation | Stability AI | $0.002–$0.01/image | 20–100 cr/image |
| Embeddings | OpenAI text-embedding-3-small | $0.02/1M tokens | 0.2 cr/1K tokens |
| Embeddings | OpenAI text-embedding-3-large | $0.13/1M tokens | 1.3 cr/1K tokens |
| Extended thinking tokens | Anthropic (Claude) | same as standard tokens | same as model rate |
| Document parsing / OCR | AWS Textract | $0.0015/page | 15 cr/page |
| Document parsing / OCR | Zerox / GPT-4o | ~$0.005/page | 50 cr/page |
| Video analysis | Gemini 2.5 Flash | $0.30/1M video tokens | 3 cr/1K video tokens |
| SMS | Twilio | $0.0085/msg (US) | 85 cr/msg |
| Telegram/Discord msgs | Telegram Bot API | free | 0–1 cr/msg (infra only) |
| Push notifications | Expo / Firebase FCM | free | 0–0.1 cr/msg (infra only) |
| Memory/KV snapshots | CF KV | $5/M writes, $0.50/M reads | 50 cr/snapshot write |
| TypeDB knowledge base | TypeDB Cloud | included in subscription | bill as premium feature flat rate |
| Scheduled agent execution | CF Cron Triggers | free | 1 cr/execution base + inference |
| Autonomous agent duration | CF DO | $12.50/M GB-sec | ~0.1 cr/min at 128MB |

---

## Cost summary

| Category | Monthly (early scale) | Scales with |
|----------|-----------------------|-------------|
| Inference | variable | Conversations × tokens × model cost |
| Composio | $0–$229 | Tool call volume |
| Cloudflare | $5–$50 | Request + storage volume |
| TypeDB Cloud | $200–$500 | Fixed (until instance scaling) |
| Resend | $0–$20 | Workspace count |
| Stripe fees | ~2% of fiat revenue | Fiat transaction volume |
| Domain + misc | ~$10 | Fixed |
| **Fixed baseline** | **~$215–$610/month** | |

Inference is fully variable and covered by the credit burn system. The fixed baseline is what ONE pays before a single conversation happens. Break-even on two to three active agency plans ($500/month each).

---

## Issues requiring action before launch

| Issue | Current config | Actual cost | Action |
|-------|:----------:|:--------:|--------|
| Voice STT rate | 8 cr/min | 43–60 cr/min | Recalibrate to ≥43 before enabling STT route |
| Voice TTS rate | 12 cr/min | 400–600 cr/min | Recalibrate to ≥400 before enabling TTS |
| `claude-opus-4-7` upstream | 1,500 cr/1K | 50 cr/1K (standard) | Update to 50; or 300 for the Fast variant |
| `claude-haiku-4-5` upstream | 25 cr/1K | 10 cr/1K | Deliberate buffer or reduce to 10 — decide |
| `gpt-5` upstream | 1,250 cr/1K | not available | Keep `enabled: false` |
| Email not metered | — | 4 cr/email | Add `email_send` burn reason ≥4 cr/email |
| Composio flat rate | 5 cr/call | 1.45–3 cr/call (varies by plan) | Pass actual per-call cost dynamically |
