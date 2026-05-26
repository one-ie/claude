# 04 — Models: One Field. 300+ Models. Your Margin.

## Copy Pattern: Plain-truth

## Hero
- eyebrow: Model-agnostic AI platform
- headline: Pick the model. Swap it in one line.
- subhead: 300+ models. Haiku for triage. Sonnet for daily work. Opus for one-shot analysis. Change one field in the agent markdown and the platform routes accordingly. The margin stays with you.
- primaryCta: See the model catalogue
- frictionText: No vendor lock-in · 14-day free trial · BYOK supported

## Proof bar
- 300+ models available through one API key
- 95% price drop for comparable quality in 18 months (Claude Opus $15/M → Haiku $0.80/M)
- <300ms first token on Groq hot paths (<150ms)
- 1 field change = complete model migration

## How It Works (4 steps)
1. Pick a model — Set `model:` in the agent frontmatter. `anthropic/claude-haiku-4-5` for triage, `claude-sonnet-4-7` for daily work, `claude-opus-4-7` for deep analysis.
2. Set per-skill overrides — individual skills within an agent can override the default. Triage on Haiku, proposals on Opus. One conversation, two models.
3. Fallback chain — OpenRouter gateway → Groq direct → AI SDK Gateway → degraded mode. Your agents don't go silent when a provider has a bad hour.
4. Swap when better arrives — Change the `model:` string. Run the eval. Roll to clients. The tool definitions, the instructions, the substrate wiring — unchanged.

## Features
1. 300+ models, one API key — Claude, GPT-5, Gemini 2.5 Flash, Llama 4, Mistral, Qwen, Command R+. OpenRouter maintains the catalogue. You benefit from every addition.
2. Per-skill model binding — content-team default: Sonnet. draft-post skill override: Haiku (high-volume). strategy-review skill override: Opus (high-stakes). Cost-tune at task level, not agent level.
3. Groq for speed — sub-200ms first token on hot paths. Custom inference silicon. For interactive tasks where latency is felt.
4. Fallback chain — four-link chain. Provider down or rate-limited? Next in chain picks up. No silent failure, no conversation drop.
5. BYOK — existing Anthropic/OpenAI/Google enterprise agreement? Bring your own key. Same routing logic, your provider bill.
6. 18-month price collapse — intelligence cost drops every quarter. An agency on a flexible substrate earns the margin expansion automatically when model costs fall without renegotiating client rates.

## Credit table
- Haiku 4.5: 25 credits/1k input (5× output) — high-volume triage
- Sonnet 4.7: 300 credits/1k input (5× output) — daily agency work
- Opus 4.7: 1,500 credits/1k input (5× output) — one-shot deep analysis
- GPT-5: 1,250 credits/1k input (8× output) — code and structured reasoning

## Worked example (50 clients, 3-agent sales stack)
Total platform cost: ~129,617 credits/client/month
At 2× markup: ~259,234 credits billed. 50% gross margin on AI layer.
If model prices fall 50% (historical rate): margin expands from 50% to ~75%. No renegotiation.

## Comparison
vs single-model SaaS: they pick the model and pace, you wait for them to adopt better ones. You're locked to their pricing decisions.
vs building your own router: 4-6 weeks senior engineer + ongoing maintenance. This ships pre-built.
- Model flexibility: us yes / single-model SaaS no / build-own yes
- Pre-built fallback chain: yes / partial / no
- 300+ model catalogue: yes / no / depends
- BYOK: yes / partial / yes
- honesty: building your own router wins on total control — costs 4-6 weeks engineering + ongoing maintenance

## FAQ
1. How do I add a model that just shipped? If it's on OpenRouter, change the model field. Immediate.
2. What's the model field format? `{provider}/{model-id}` e.g. `anthropic/claude-haiku-4-5`
3. What if a model gets deprecated? 90 days' notice. Alias resolves to successor or requires one field update.
4. Can I mix commercial and open-weight in the same team? Yes. Each agent has its own binding.
5. What if I built around one model's behaviour and a swap breaks it? The eval gate catches it before rolling to clients.
6. Can clients see which model runs their agent? By default no. You surface it if needed.
