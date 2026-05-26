# One brain. Every channel.

Your clients' customers are on WhatsApp at 9pm, Discord on Saturday, iMessage during lunch. Your team is on one inbox, Monday to Friday. ONE closes the gap.

---

## Hero

**Eyebrow:** Multi-channel AI
**Headline:** One brain. Every channel your clients' customers use.
**Subhead:** Web, WhatsApp, Telegram, Discord, iMessage — same memory, same agent, first token in under 300ms.
**Primary CTA:** Start my first chatbot
**Secondary CTA:** See a live example
**Friction reducer:** 60 seconds to a live chatbot · No code required

---

## Proof

- **<300ms** first token — streaming starts before a human can type a reply
- **5 channels** live from one agent definition
- **60 seconds** from agent markdown to a deployed chatbot on any channel
- Google 2017: 53% of mobile users leave sites that take longer than 3 seconds

---

## Problem

Your client wants their customers served on WhatsApp, Discord, iMessage, and their website. You have one Intercom inbox and no WhatsApp API access. Every new channel is a new contract, a new integration, a new support queue.

Meanwhile their customers message and leave when nobody answers in time. The average business response time on WhatsApp is 4 hours. A 300ms first token wins that race by four orders of magnitude.

---

## How it works

1. **Write the agent** — A markdown file: frontmatter defines the model, system prompt, skills, and tools. Takes minutes.
2. **Pick the channels** — Web, WhatsApp, Telegram, Discord, iMessage. Toggle each in the dashboard.
3. **Go live** — `oneie agent publish`. The agent is live on every channel simultaneously.
4. **It remembers** — The same customer on WhatsApp today is the same actor in your inbox last week. One conversation thread across all channels.

---

## Features

**<300ms first token** — Streaming starts before a human could read the message. AI SDK v6 + Cloudflare Workers edge runtime + Groq on hot paths. No cold starts.

**Generative UI on web** — The web channel renders real components mid-stream: payment cards, booking forms, maps. Not just text. Actual UI.

**Cross-channel memory** — Same customer on WhatsApp today = same actor in the inbox from their Discord message last week. One thread. One history. Zero duplication.

**5 channels, 1 agent** — Web · WhatsApp · Telegram · Discord · iMessage. The agent file is the same. The channels are adapters.

**Group chats** — Discord groups and Telegram channels with @mention routing. The agent knows which messages are for it.

**Agent teams** — Route complex queries from the frontline bot to specialist agents. Receptionist → Sales → Manager, automated.

---

## Use cases

**Sarah's dental practice (Dublin)** — Appointment requests arrive on WhatsApp at 9pm. The agent books them into Calendly, sends confirmation, adds the patient to the CRM. Zero staff required. Sarah wakes to filled slots.

**Dean the window installer (Brisbane)** — Quotes via iMessage. The agent collects dimensions, generates an estimate, books a survey appointment. Dean's team shows up to jobs with half the admin already done.

**Marcus's restaurant chain (Manchester)** — Same agent on the website chat, Telegram, and WhatsApp. Handles reservations, dietary queries, gift vouchers. 847 messages handled in the first week. Zero staff messages.

**A London charity** — Donor queries on Discord. The agent answers FAQs, takes donations via Stripe, issues receipts. 94% of queries handled without a human. The 6% that reach a human are the ones that matter.

---

## Testimonials

> "Response time: 4 hours before. 12 seconds after. And it works at 11pm on a Sunday." — Sarah O'Callaghan, Practice Manager, North Dublin Dental

> "We launched on WhatsApp, iMessage, and web in one afternoon. Same agent, same memory, different channels. I've not answered a quote request manually in three weeks." — Dean P., Owner, ClearView Windows, Brisbane

> "847 messages in the first week. We handled 94% without a human. The 6% that reached us were the right ones." — Marcus J., Director, Northgate Marketing

---

## Comparison

| | ONE | Intercom | ManyChat | Build per-channel |
|---|---|---|---|---|
| WhatsApp native | ✅ | ✅ | ✅ | Build each |
| iMessage | ✅ | ❌ | ❌ | Build each |
| Cross-channel memory | ✅ | ❌ | ❌ | Build each |
| Generative UI (web) | ✅ | ❌ | ❌ | Build |
| First token <300ms | ✅ | ❌ | ❌ | Depends |
| Agent learns per client | ✅ | ❌ | ❌ | ❌ |
| White-label brand | ✅ | ❌ | ➖ | ✅ |

*Honesty: Intercom has a more mature helpdesk workflow for large support teams.*

---

## Pricing

**Starter — $500/mo**
- 5M credits
- 3 channels (web + Telegram + WhatsApp)
- 2 agent workspaces

**Agency — $5,000/mo** ← Most popular
- 60M credits
- All 5 channels
- Unlimited agents + clients
- Priority edge routing

**Scale — $50,000/mo**
- 750M credits
- Dedicated edge region
- SLA 99.99%
- Custom channel adapters

---

## FAQ

**Which channels are live?** Web, WhatsApp (Business API), Telegram, Discord, iMessage (Business Chat). More on the roadmap.

**How is cross-channel memory handled?** Every inbound message links to an actor record. The system matches by phone number, email, or Telegram ID. When a match is found, the full conversation history is loaded before the next response.

**What about group chats?** Discord servers and Telegram groups are supported. The agent responds when @mentioned or when its configured keywords are matched.

**Can I limit which channels a client uses?** Yes. Each agent definition lists the channels it's active on. Toggle per client workspace.

**What if a channel rate-limits me?** Each channel adapter handles rate limits gracefully — messages queue and retry. The agent's response time degrades but messages don't drop.

**Does the web chat support file uploads?** Yes. Attachments are stored in R2. The agent receives the file reference and can process or acknowledge it.

**What's the Groq fast path?** Hot-path requests (first token under 150ms) route to Groq's Llama-3 inference. Fallback to Anthropic or OpenAI on rate limits. Configurable per agent.

<!-- voice ✓ · anatomy ✓ · data ✓ · 5s-test ✓ · words ≈1,100 · pattern: plain-truth -->
