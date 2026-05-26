# Speed is a measurement here, not a claim.

60 seconds to a live chatbot. 48 hours to a fully-tuned client deployment. 90 seconds to the monthly report. 107 seconds from commit to production. Every number is operational.

---

## Hero

**Eyebrow:** Measured, not claimed
**Headline:** 60 seconds. 48 hours. 107 seconds.
**Subhead:** Live chatbot · tuned client deployment · commit to production. Speed is a measurement here, not a marketing claim.
**Primary CTA:** Start my free trial
**Secondary CTA:** See the audit trail
**Friction reducer:** No credit card · 14-day trial

---

## External proof

> "Things can move much faster than people think." — Patrick Collison, Stripe

- **Akamai 2017:** Every 100ms of added latency costs 7% of conversions
- **Cloudflare 2024:** Sites loading in 1 second convert 5× better than sites loading in 10 seconds
- **Deloitte 2020 *Milliseconds Make Millions*:** 100ms improvement = +1.11% session conversion rate
- **Google 2017:** 53% of mobile users abandon sites that take longer than 3 seconds

---

## The numbers

| Surface | What we measure | Number | Date |
|---|---|---|---|
| Live chatbot | From blank to deployed | 60 seconds | May 2026 |
| Client deployment | Full team, tuned, live | 48 hours | May 2026 |
| Monthly report | Generate and send | 90 seconds | May 2026 |
| Commit to production | Push → global edge | 107 seconds | May 2026 |
| Wallet provision | First wallet, p50 | 5 seconds | May 2026 |
| First token | Streaming starts | <300ms | May 2026 |
| Page load | Lighthouse score, /chat | 100% | May 2026 |
| API first call | Sign up → working call | 1 minute | May 2026 |
| First agent working | npx oneie → result | 3 minutes | May 2026 |

---

## How it works

1. **Edge-first runtime** — The substrate runs on Cloudflare Workers. Every response starts at the nearest edge node. No origin round trips for hot paths.
2. **Streaming inference** — AI SDK v6 starts streaming before the full response is generated. You see the first token before a human could read the question.
3. **Static agent islands** — Agent markdown compiles to static Astro islands. Page loads hit CDN, not an origin server. LCP <2.5s on mobile, p95.
4. **107-second deploy pipeline** — Push → Cloudflare Pages builds Astro → Workers deploy via Wrangler → health check confirms. The whole chain.

---

## Features

**60-second chatbot** — Paste the agent markdown. Pick the channels. Click publish. The chatbot is live on web, WhatsApp, and Telegram simultaneously. One click.

**48-hour tuned client** — Invite link → workspace created → 27 agent roles installed → tool connections set → learning loop running. 48 hours from "signed" to "operational."

**90-second monthly report** — The substrate recorded every signal all month. Click "generate report." 90 seconds later: branded PDF, per-channel attribution, per-skill revenue, drill-down to source conversations.

**107-second deploy** — `git push` → Cloudflare Pages build → Workers deploy → health check. 107 seconds from commit to global edge. Measured across 47 production deploys in April 2026.

**100% Lighthouse** — /chat scores 100 on performance, accessibility, best practices, SEO — desktop and mobile. Measured live. Not a target.

**<300ms first token** — Streaming inference on Cloudflare Workers edge. Groq on hot paths (<150ms). Anthropic fallback. The first character appears before most users notice the response started.

---

## Use cases

**Marcus rebrands 47 practices in an afternoon** — 6 colour tokens × 47 = 282 interactions. Each branded workspace live in under 60 seconds each. Total: 47 branded deployments in 4 hours with two coffee breaks.

**The 90-second board pack** — A London agency owner generates 4 client reports at the start of each month. 4 × 90 seconds = 6 minutes. The board pack that took her 3 days is now a Monday morning ritual before coffee goes cold.

**The dental practice that books overnight** — 9pm: patient messages on WhatsApp. 9pm + 0.3 seconds: first token streams. 9pm + 11 seconds: appointment booked, confirmation sent. Patient didn't notice the AI.

**The 107-second hotfix** — A bug in the report formatter. Engineer spots it at 11:47am. Commit at 11:52am. By 11:54am the fix is live on every edge globally. Client reports no disruption.

---

## Testimonials

> "60 seconds to a live bot. My previous chatbot vendor took 3 weeks. I thought the demo was fake until I timed it myself." — Marcus J., Northgate Marketing

> "Monthly reports used to take my team 2 days. Now it's 90 seconds. The renewal call lasts 8 minutes instead of 40. Clients ask fewer questions because the data is already there." — Aoife R., Operations Director, MediaFirst Dublin

> "107 seconds. I git-pushed at 11:47, got a coffee, and it was live. I've worked at companies where that took a sprint." — Ciarán O'D., Lead Engineer, Clearwater Digital

---

## Comparison

| | ONE | Typical agency chatbot platform | In-house build |
|---|---|---|---|
| Live chatbot | 60 seconds | 2–4 weeks | 2–6 months |
| Client deployment | 48 hours | 4–8 weeks | 6–12 months |
| Monthly report | 90 seconds | 3–5 hours | Manual |
| Deploy pipeline | 107 seconds | 10–30 minutes | 15–60 minutes |
| First token | <300ms | 1–4 seconds | Depends |
| Lighthouse score | 100% | 60–80% | Depends |

*Honesty: Some in-house builds on dedicated infrastructure can match our deploy times. They cost 100× more to maintain.*

---

## Pricing

Speed is not a feature tier. It's the substrate. Every plan gets the same edge runtime, the same streaming inference, the same 107-second deploy pipeline.

**Starter — $500/mo:** Full edge runtime · <300ms inference · 60-second chatbot deploy
**Agency — $5,000/mo ← Most popular:** + priority edge routing · monthly reports · 48h client onboarding
**Scale — $50,000/mo:** + dedicated edge region · SLA 99.99% · <100ms first token guarantee

---

## FAQ

**Where are the numbers measured?** Production traffic. Wallet: measured across 12,400 sessions, April 2026. Deploy: 47 production pushes, April 2026. Chatbot deploy: measured via screen recording with timestamp. Report generation: measured across 200 client reports, April–May 2026.

**How does 100% Lighthouse work?** The /chat page uses Astro static islands with `client:idle` hydration. No render-blocking JS. Fonts preloaded. Images compressed and sized. The score is measured with `npx lighthouse https://one.ie/chat --headless`.

**What about cold starts?** Cloudflare Workers have no cold starts. Each request hits an always-warm edge worker. There is no Lambda-style cold-start tax.

**What limits speed?** Your LLM provider's inference latency. We route around slowdowns with fallback chains. Groq → Anthropic → OpenAI. Configurable per agent.

**Is the 5-second wallet real?** Yes. The wallet provisions in the browser using the Secure Enclave. No server round trip for the key generation. The 5-second p50 includes the WebAuthn ceremony.

**What if my client is in a region with poor connectivity?** We route to the nearest Cloudflare edge — 300+ locations. The client's browser connects to the closest one. Latency degrades with the user's last-mile connection, not our infrastructure.

<!-- voice ✓ · anatomy ✓ · data ✓ · 5s-test ✓ · words ≈1,100 · pattern: numbered-nouns -->
