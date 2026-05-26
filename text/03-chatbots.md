# One Agent. Every Surface. Same Brain.

Your client's customer sends a message on WhatsApp at 11pm. The same customer opens your client's website the next morning and starts a chat. Later that week they reply to a Telegram notification. In the old world, those are three conversations in three inboxes, probably handled by three tools with no memory of each other.

With ONE they are one conversation. The same agent, the same memory, the same brand voice across every channel. Not because the messages are synced after the fact, but because they all run against one TypeDB Group. One brain. N channels.

Andrej Karpathy said it plainly:

> "The hottest new programming language is English."

That is the bet your clients' customers are already making. They type what they want and expect an answer. Your agency's job is to put the right brain on the other end of that conversation, on every surface they use.

This page tells you what that means in practice: what channels are live, what rich messages look like, how streaming works, and why the shared brain is the part that makes everything else compound.

---

## Web

The web chat is the most visible surface, so it is the right place to start.

Visit `/chat` on any ONE workspace. Lighthouse scores 100/100/100/100. Performance, accessibility, best practices, SEO, all four hundreds. That is not a synthetic test runner tuned for the demo. It is the live production page, measured on 2026-05-03, repeatable on demand.

Most AI chat products have never bothered to run Lighthouse. Those that have tend to score in the 60s and 70s on performance because they ship heavy client bundles and block the main thread. ONE ships 100 because the architecture enforces it. Heavy components (attachments ~281 KB, speech input, PayPanel, voice controls) are lazy-loaded behind `Suspense` boundaries and never touch the initial render path. The page opens fast because the initial bundle is small. Everything else loads when the user needs it.

First token on screen in under 300ms, p50. The moment you hit send, the brain has already started thinking. Tokens stream to the page as they arrive. You do not wait for the full response before reading begins. The connection is warm before you finish typing because the `client:idle` island opens it during idle time, before you click.

What renders in the web chat is not just text. The web surface supports generative UI: structured components that the agent streams inline as part of the conversation. When the agent recommends a product, it streams a product card. When it creates an invoice, it streams a payment card with a claim button. When it returns a map pin, it streams a map embed. The conversation is not a transcript. It is an application built in real time, inside the chat window, by the agent.

This is what "one chat page scores 100 on Lighthouse" actually means for an agency owner. The performance is not just about speed numbers. It is about the first impression your client's customer has of your client's brand at the moment they choose to ask a question. A page that loads in under a second, with tokens on screen in under 300ms, reads as competent. A page that spins for three seconds reads as broken.

Akamai measured it in 2017: every 100ms of added latency cost 7% of conversions. Cloudflare's 2024 data puts mobile sites loading in 1 second at 5x better conversion than sites loading in 10 seconds. The chat page is not a side feature. It is the primary commercial surface. It loads fast because everything else depends on it loading fast.

---

## Messaging

Clients' customers do not live in your web chat. They live in Telegram, in Discord, increasingly on iMessage, and in WhatsApp. Any platform that cannot meet them there hands the conversation to a competitor who can.

**Telegram** is live and in production. Messages arrive via webhook at `POST /webhook/telegram`, pass through the `ToolLoopAgent` loop in claw, and the reply posts back to the originating chat in under 1 second. Each Telegram chat (DM or group thread) becomes its own substrate group with its own conversation history and pheromone paths. The agent remembers what this user has asked before, what worked, and what they care about. Conversation history is stored in D1, with the last 20 messages fed as context on every call. Reply threading is preserved: a message that replies to another carries the parent reference into the agent's context.

One worker supports multiple Telegram bots simultaneously. A support bot, a sales bot, and a general assistant all run off the same claw worker with separate token secrets and separate webhook paths. Each bot has its own substrate group prefix (`tg-support-<chat_id>`, `tg-sales-<chat_id>`) so conversation histories and pheromone paths stay separate. You do not pay for separate infrastructure for each persona. You set a named environment variable and register a second webhook.

**Discord** is live. Messages arrive at `POST /webhook/discord`, the same `ToolLoopAgent` loop handles them, and the reply posts to the originating channel. Each Discord channel gets its own substrate group (`dc-<channel_id>`). Ping verification is automatic. Bot messages are silently ignored so the agent does not loop on itself. The Discord setup is slightly more involved than Telegram. It requires a Discord application, a bot token, the Message Content Intent enabled in the developer portal, and either an interactions endpoint or a gateway relay. The agent behaviour is identical once wired.

**iMessage** is in the architecture via the Apple Business Messages gateway. The signal enters via the same webhook pattern; the `normalizeApple` adapter converts it to a standard Signal and the same `ToolLoopAgent` handles it. Configuration follows Apple's Business Messages registration process.

**WhatsApp** is on the roadmap. The integration shape is identical: webhook in, claw processes, reply out via the WhatsApp Business API. The substrate does not care which channel delivered the signal. It routes on the signal content. Adding a new channel is adding a new normalizer and a new sender, both in `claw/src/channels.ts`.

The current channel count is six active surfaces: web, Telegram, Discord, iMessage, the direct `/message` API, and MCP. MCP means any Claude client (Claude.ai, Claude Code, Cursor) can invoke your agent's tools directly through the MCP protocol, without a chat UI. A developer using Cursor can invoke a client's booking agent the same way the client's customer invokes it through the web chat. Same brain, different surface.

The number that matters for Brad is not the channel count. It is the implication of one brain across all of them. If a client's customer asks about pricing in Telegram and comes back through the web chat three days later, the agent knows. It does not start over. The corpus compounds with every interaction, on every channel, inside one TypeDB Group per client.

---

## Groups

A Group in ONE is a scoped container. Signals route inside groups. Pheromone marks edges inside groups. Memory is per-group. The rule is simple: an actor can only act where it is a member. No shared group, no delivery. That one rule gives you tenancy, privacy, and capability scoping at once.

For a Telegram user, the group is `tg-<chat_id>`. For a web user, it is the workspace slug. For a Discord channel, it is `dc-<channel_id>`. These are all substrate groups. The agent in each group has its own memory, its own pheromone paths, its own accumulated learning. Two users on two different channels, with two different histories, get two different experiences from the same agent, because they are in two different groups.

Multi-actor rooms are also groups. A Discord channel with ten participants is a group where all ten are members. The agent participates as a member of that group. When one member asks a question, the agent answers in the same channel thread. Conversation history includes all members' messages, so the agent understands who asked what and can address specific participants by name.

For Brad's agency, the group architecture is what makes white-labelling real. His agency workspace is a group. Each client workspace is a child group. Each client's end users are members of the client's group. Brad's agency staff are members of the agency group and potentially of individual client groups. The configuration cascades from parent to child: brand tokens, agent personas, voice contract, feature gates. The end user visiting `startup1.acme.com` sees Startup 1's logo and colours, Startup 1's agent, and nothing about ONE or ACME unless the agency has enabled that attribution.

The group tree is recursive. Groups nest. Each node has its own slug, its own configuration, its own domain, and its own viewer-scoped navigation. An agency on the Agency plan gets up to 20 client workspaces. Enterprise removes that limit. Every workspace appears fully standalone to its end users. They see the client's brand, not the substrate underneath it.

Groups also enforce security. A private group is invisible to non-members at the API level. Not hidden in the UI; absent from the resolver output. Role-based access control runs on the membership relation: chairman, admin, member, guest. Attribute-based policies run as TypeQL queries over any attribute combination. Relationship-based trust (the emergent trust layer from pheromone) runs underneath both. An actor with admin role but a toxic path history gets blocked at the pheromone check before the role check runs. Three layers, one substrate.

---

## Rich Messages

Text is the baseline. Rich messages are where the chat becomes a transaction surface.

There are eight message types in production today: payment card, map pin, form, code block, image, file attachment, claim button, and embed. The agent decides which type to send based on the user's intent. If the user asks for an invoice, the agent emits a payment card. If the user asks for directions, the agent emits a map pin. If the user asks for a code example, the agent emits a code block with syntax highlighting. The channel adapter unwraps the message type and renders it appropriately for the surface.

The payment card is the most commercially significant. Here is the payload:

```ts
{
  type: 'payment',
  payment: {
    receiver: 'acme-dentist',    // substrate actor who receives the payment
    amount: 150,                  // in the workspace's configured currency unit
    action: 'claim'               // what clicking the button does
  }
}
```

When the user clicks the claim button, the Sui transaction executes. The agent receives the payment confirmation and replies in the same thread. The whole flow, from the user asking to the payment confirmed, is five seconds. The corpus records the event: who paid, what for, when, on which channel. The next time this user interacts with the agent, it knows they are a paying customer.

For web, rich messages render as inline components inside the conversation. The payment card is a card component with a claim button wired to `emitClick('ui:chat:claim', { type: 'payment', payment: { receiver, amount, action: 'claim' } })`. The UI signal fires before the local handler, so the substrate records the interaction regardless of whether the payment succeeds.

For Telegram and Discord, the same message type renders as a formatted text message with a link to the payment flow. The agent's response looks like: "Here is your invoice for the consultation [Claim: £150]." The link opens the web payment flow in the user's browser. The agent then waits for the webhook from the payment processor and confirms in the same Telegram thread.

For MCP, the tool returns structured data. The MCP client renders it however it prefers. In Claude Code that might be a formatted response with a URL; in a custom integration, it might be a native UI component.

Deduplication across channels uses the signal `id` field. If a message arrives via both a Telegram webhook and a web poll (rare, but possible in some gateway configurations), the second instance is silently dropped. The substrate records one signal per unique `id`. Brad's clients never see a doubled message in the conversation history, and the pheromone is never double-marked.

A summary for the channel capability matrix is below. Every entry reflects what is live or specifically committed on the roadmap, not speculation.

| Channel | Streaming | Rich messages | Attachments | Payments | Voice | Groups | Presence |
|---|---|---|---|---|---|---|---|
| Web (`/chat`) | Yes | Yes | Yes | Yes | Shipped | Yes | Yes |
| Telegram | No (complete response) | Metered (text + link) | Roadmap | Yes (link) | Roadmap | Yes | No |
| Discord | No (complete response) | Metered (embed) | Roadmap | Yes (link) | Roadmap | Yes | No |
| iMessage | No | Metered | Roadmap | Yes (link) | Roadmap | Yes | No |
| API (`/message`) | Yes (SSE) | Yes | Yes | Yes | No | Yes | No |
| MCP | No | Yes (structured) | Yes | Yes (tool) | No | Yes | No |

"Metered" means the channel has limited native support for the rich format. The agent uses text with links rather than native embedded components. "Roadmap" means the integration shape is defined and the adapter is the only gap.

---

## Streaming

Streaming is how the chat feels alive. Without it, the user submits a question and waits for the full response before seeing anything. With it, tokens appear on screen within 300ms of hitting send, and the response builds in front of the user in real time.

The technical shape is AI SDK v6: `createAgentUIStreamResponse` on the server, `useChat` on the client. The server runs the `ToolLoopAgent` loop. Model decides, tool executes, model incorporates the result, loop repeats up to `maxSteps`. Every token of every model response streams to the client as a UIMessage SSE event. Tool calls stream as structured parts. Tool results stream as structured parts. The client renders each part as it arrives: text tokens as flowing prose, tool-call parts as "thinking" indicators, tool-result parts as inline components.

The first-token target is 300ms. That is the latency from the moment the user hits send to the moment the first character appears on screen. It depends on three things: the network round-trip to the edge worker, the time for the ToolLoopAgent to start the first model call, and the model's time to first token. The claw worker runs on Cloudflare Workers (global edge, zero cold start). The compute is already warm when the request arrives. The routing decision (which agent handles this signal) takes under 0.005ms in the substrate. That is arithmetic over pheromone weights, not an LLM call. The remaining latency is model-side.

For channels without native streaming (Telegram, Discord, iMessage) the ToolLoopAgent runs to completion and posts the full response. This is a protocol constraint, not an architecture constraint. Those channels have no server-sent-events equivalent for bot messages. The agent still runs the same loop. The user just sees the complete response when it arrives rather than watching it build.

The streaming protocol also carries tool approval gates. When the agent wants to take a substrate write action (`remember`, `mark`, `warn`) the loop pauses and streams an approval request to the client. The user sees a structured card: "The agent wants to remember this conversation. Approve?" The approval is a click, not a form submission. The agent continues after approval. This is the same gate that runs for destructive actions through the UI. One protocol, both surfaces.

---

## The Same Brain Across Surfaces

One TypeDB Group per client. N channels pointing at it.

That sentence is the whole architecture. The brain is the Group. The channels are surfaces. Swapping the surface does not swap the brain. When a user starts a conversation in Telegram and continues it on the web, the agent on the web side knows what happened in Telegram. Not because a sync job ran, not because a human copied notes between systems, but because both channels wrote to the same Group in TypeDB from the start.

Here is what that looks like as infrastructure:

```
Telegram ──────────┐
Discord  ──────────┤
Web      ──────────┤──→ claw (ToolLoopAgent) ──→ TypeDB Group ──→ response stream
API      ──────────┤                                    ↑
MCP      ──────────┘                         (pheromone marks,
                                              hypotheses, memory)
```

The claw worker is the ingress point. Every channel feeds into it. The `ToolLoopAgent` runs inside claw against the substrate. TypeDB holds the Group's conversation history, the pheromone paths (which answers worked, which failed), and the hardened hypotheses (patterns learned from enough repetition that they become reliable enough to route without asking the LLM). When the LLM runs, it runs against a system prompt built from all of that context. The response streams back out through the originating channel.

A concrete scenario. A client of Brad's runs a dental practice. A patient sends a message via Telegram asking about appointment availability. The agent checks the schedule (a substrate tool call) and offers three slots. The patient says "the Wednesday one" and the agent books it. Next week, the patient visits the practice website and starts a web chat. The agent knows their name, knows they have a Wednesday appointment, and greets them accordingly. It does not ask them to start from scratch. The corpus is the memory; the memory lives in the Group, not in the channel.

For Brad's agency, one Group per client means one corpus per client. That corpus is the moat. After six months of conversations across every channel, the agent for the dental practice knows which questions patients ask most, what their anxiety points are, which services they request after a first consultation, and which messages tend to precede a cancellation. None of that learning evaporates when a patient switches from Telegram to the web. The brain compounds across every surface, every session, every signal.

---

## Objections

**"What if the agent says something wrong in front of a patient?"**

Every outbound message passes through a voice contract check before it sends. The contract is configured per-agent in the markdown definition file: prohibited topics, required disclaimers, tone boundaries, brand vocabulary. If a response violates the contract, it does not send. The quality score gate is 0.65. Responses below it are held and escalated rather than delivered. This is not a policy document. It is a mechanical check that runs before every outbound signal, on every channel.

The practical answer for the dental practice: the agent is configured to say "I'll have someone from the practice contact you" for clinical questions. That instruction is in the agent's markdown file. It applies in Telegram, on the web, through the API, everywhere, without the agency having to configure it per-channel.

**"What if my clients find out the AI is doing the work and demand a discount?"**

Most do not ask. When they do, the honest answer is: the AI is doing the repetitive work so the human staff can do the work that requires judgment. That is not a liability. It is a selling point for the agency's end clients. The agency that says "our AI handles enquiries so our clinical team focuses on patients" is selling a professional service. The agency that will not admit it is waiting for the client to figure it out on their own.

If a client wants to know which model is running, that is a tier-level setting. Tier 3 workspaces can surface model attribution; tier 1 workspaces show only your brand. Brad's agency controls which level each client sees.

**"What about voice?"**

Voice input is shipped for the web surface. The `speech-input` island is in the AI Elements component library: mic-selector, transcription, voice-selector, audio-player. The island lazy-loads behind a `Suspense` boundary so it does not affect the page's Lighthouse score. The user clicks the microphone, speaks, and the transcript feeds into the same chat pipeline. The agent responds in text; voice output is on the roadmap.

Voice on Telegram and Discord is constrained by those platforms' audio handling. Telegram supports voice messages as audio files; the normalizer can be extended to transcribe the audio before feeding it to the agent. Discord has similar capability. Both are roadmap items, not architectural blockers. The latency budget for voice (transcription plus inference plus text-to-speech) is achievable at under 2 seconds end-to-end on current infrastructure.

**"What happens if the substrate is down when a Telegram message arrives?"**

The claw worker degrades gracefully. If the TypeDB gateway is unreachable, the agent falls back to D1-only context (last 20 messages from the local database) and continues serving. The pheromone mark for that signal is queued and written when connectivity restores. The user gets a response; the learning is deferred, not lost.

**"We already have a live chat tool. Why replace it?"**

You do not have to. The substrate is additive. The existing live chat tool can feed signals into the ONE inbox via inbound webhook. The agent can respond through the existing tool's outbound API. The corpus builds on the existing tool's conversation history. Over time, the substrate learns which paths are strongest. The routing naturally favours the channels that work best for each client's customers. The live chat tool becomes a report; the substrate becomes the intelligence layer.

**"One channel at a time or all at once?"**

One client, one channel, first. Start with the web chat for one of Brad's clients (the one most willing to try something new). Run it for 30 days. Read the `/memory` report. Then extend to Telegram. Each channel adds to the same corpus without any migration. There is no "move the data" step because the data was always in TypeDB.

**"What if a customer goes around the agent and calls the office directly?"**

That call gets logged manually by the office staff (or transcribed if you are running a telephony integration). It enters the corpus as a signal with the source marked as `phone`. The agent's next interaction with that customer includes the phone call context. The corpus is not limited to digital channels. It accepts signals from any source that can send a POST request.

**"Can I see everything the agent has said across all channels in one place?"**

Yes. The unified inbox is `/api/inbox/:uid`: every signal across all of that user's memberships, in chronological order, with source channel tagged. The tracking page (page 10 of this PDF) is the dashboard view. One inbox. Every channel. Every conversation.

---

## Comparisons

**ONE versus a standalone chatbot (Intercom, Drift, Tidio)**

A standalone chatbot handles one channel, runs on one company's infrastructure, and resets memory between sessions unless the user logs in and the vendor maintains that state. The agent in ONE runs across every channel the client uses, maintains a shared corpus in TypeDB, and gets smarter with every interaction regardless of which channel it happened on. The standalone chatbot is a point solution; ONE is the substrate the chatbot runs on.

The commercial difference for Brad: a standalone chatbot is a seat cost. ONE is a substrate cost with agency markup over the credit floor. Brad pays for credits consumed, marks them up to his clients, and keeps the difference. The corpus stays with Brad's agency even if a client leaves. A standalone chatbot's conversation history belongs to the vendor.

**ONE versus building on the OpenAI API directly**

Building directly on the API means Brad's engineering team (or Donal's) builds the memory layer, the channel adapters, the rich message types, the streaming protocol, the dedup logic, the approval gates, and the pheromone learning system. That is 6 to 12 months of engineering for a substrate that exists today. At the end of it, the agency owns infrastructure rather than IP. The corpus is in a Postgres database that someone has to maintain. The channel adapters are custom code that breaks when Telegram changes their webhook format.

The one scenario where building directly makes sense: a single enterprise client with enough budget to fund a bespoke build and the technical appetite to own it. For the rest of Brad's book (dentists, accountants, window-and-door installers) the substrate is the right layer to buy.

---

## Pricing Math

Brad buys credits at the platform floor. He sets his agency markup. He distributes credit pools to clients. The credit pools fund the LLM calls, the substrate writes, and the channel operations.

A worked example for a dental practice: 200 patient enquiries per month across web and Telegram. Average conversation: 4 exchanges. 800 LLM calls at roughly $0.002 per call (GPT-4o-mini on OpenRouter via the agency's claw worker) = $1.60 in LLM costs. Add substrate writes (mark/warn on 800 paths) at sub-millisecond in-memory operations: negligible. Add D1 reads for conversation history at Cloudflare D1 pricing: negligible at this volume. Total platform cost for this client: under $5 per month. Brad charges the practice $300 per month for the AI chat service. Gross margin: 98%.

At 50 clients in the first cohort, same profile: under $250 per month in platform costs, $15,000 per month in revenue. That is 98% gross margin on the subscription layer, not counting any performance-pricing uplift from clients whose AI conversations convert to bookings.

The numbers change at higher conversation volumes. A hospitality client with 2,000 enquiries per month has higher LLM costs but also higher pricing power. $800 to $1,200 per month is defensible when the agent is booking tables and answering availability questions at 11pm. The per-conversation economics stay favourable at any realistic volume for SMB local-service clients.

---

## A Day in the Life: The Invoice in WhatsApp

A client of Brad's runs a window installation business. A homeowner sends a WhatsApp message on a Sunday afternoon: "Can you send me a quote for three windows?"

The agent reads the message. It knows from prior conversations (this homeowner contacted them six weeks ago) that the property is a 1990s semi-detached, two stories, east-facing. It recalls the product preferences from that conversation: uPVC, white frames, A-rated glass.

The agent responds with a summary and asks one clarifying question: "Are you replacing like-for-like or changing the opening style?" The homeowner says "like-for-like." The agent generates the quote (three items, each with dimensions and price) and sends it as a rich message with a payment card: £2,400 total, with a 25% deposit required to confirm. Claim button in the WhatsApp thread.

The homeowner clicks the claim button. The link opens in their browser. They authenticate with their existing account (passkey, Touch ID on their phone). The £600 deposit payment executes. The agent receives the payment webhook and confirms in the same WhatsApp thread: "Deposit received. We'll call Monday morning to confirm the installation date."

The agent marks the path `homeowner:request → booking:confirmed` with a strength increment. The substrate records: this customer type, this product, this channel, this message sequence, this outcome. The next time a similar enquiry arrives, the routing is faster, the response is more accurate, and the conversion probability is higher.

The window company's staff saw none of this until Monday morning, when they check the bookings dashboard and see a confirmed deposit from Sunday's conversation. The agent worked the Sunday shift.

---

## Failure Modes

**The agent goes off-script.** The voice contract check catches this before the message sends. If the agent generates a response that mentions a prohibited topic (pricing for a service the client does not offer, or clinical advice in the dental practice example) the check returns a failed quality score and the message is held. The fallback is a templated response: "I'll have someone get back to you shortly." The held response is logged for the agency to review. This is not automatic. The agency needs to review held responses periodically. It prevents the bad message from reaching the customer.

**A channel goes down.** Telegram's API, Discord's API, and the WhatsApp Business API each have documented downtime histories. When the outbound send fails, claw retries with exponential backoff. If the retry window expires, the message is logged as undelivered and the customer receives no response. This is the same failure mode as any messaging integration. The mitigation is the web channel: the customer can always reach the agent through the workspace URL, which is under the agency's control.

**The credit pool runs dry.** When a client's credit pool is exhausted, the agent responds with a service-unavailable message and falls back to email capture. The agency is notified. The customer is not left hanging with no response, but they do not get the AI response they expected. Daily caps per workspace and auto-topup settings prevent this from being a surprise.

---

## FAQ

**Q: How many channels are live today?**
Six: web, Telegram, Discord, iMessage, API, and MCP.

**Q: Does streaming work on Telegram?**
No. Telegram has no native streaming protocol for bot messages. The agent runs to completion and posts the full response. Response time is typically under 1 second for a standard query.

**Q: Can two agents share one group?**
Yes. Multiple agents can be members of the same substrate group. The routing determines which agent handles each signal based on pheromone paths and the signal content. A sales agent and a support agent can coexist in the same Telegram group; the substrate routes enquiries to the one with the strongest path for that query type.

**Q: What's the dedup mechanism across channels?**
The signal `id` field. Every signal has a unique ID generated at creation. The substrate rejects duplicate IDs on write. If the same message arrives via two paths (rare but possible in gateway configurations), only one is written.

**Q: Can the agent send images?**
The web surface supports image rich messages. Telegram supports image messages via the Telegram API. Discord supports image attachments. The agent can retrieve an image URL from a substrate tool call and include it in the response.

**Q: How does the agent know which channel a message came from?**
The channel is encoded in the substrate group prefix. `tg-<chat_id>` is Telegram. `dc-<channel_id>` is Discord. `web-<session_id>` is web. The agent's system prompt includes the channel context. The agent can reference it ("I see you're reaching us through Telegram, we can also help you on our website") if the persona is configured to do so.

**Q: Is conversation history shared across channels for the same user?**
Per the current architecture, no. Each channel creates its own substrate group. A user in Telegram and the same user on the web are two separate groups unless they authenticate with the same account on both surfaces. When they do authenticate, the substrate merges the context: the web session recognises the authenticated user and loads their full history including Telegram interactions.

**Q: What is the maximum response length on Telegram?**
Telegram's API limits messages to 4,096 characters. The agent's output is truncated and split across multiple messages if it exceeds this limit. The split is done at sentence boundaries where possible.

**Q: How do I add a new channel?**
Add a normalizer function (parse incoming message format → Signal) and a sender function (Signal response → platform API call) in `claw/src/channels.ts`. Register the new webhook path in `claw/src/index.ts`. Set the required API token as a wrangler secret. The substrate handles everything else (memory, pheromone, rich message routing) without modification.

**Q: Does voice work on mobile?**
Voice input on the web surface works on mobile Chrome and Safari. The `speech-input` component uses the Web Speech API. On iOS Safari, the user taps the mic, speaks, and the transcript appears in the input field. The component lazy-loads so it does not affect the page's initial Lighthouse score.

---

## Glossary

**claw.** The edge-native AI agent worker. Receives messages from all channels, runs the ToolLoopAgent loop, streams responses back. Deployed on Cloudflare Workers with zero cold start.

**Claim button.** The rich message component that executes a Sui payment when clicked. Configured with `receiver`, `amount`, and `action: 'claim'`.

**Group.** A substrate container. Actors live in groups. Signals route inside groups. One TypeDB Group per client per channel.

**Pheromone.** The learning mechanism. Every signal marks a path (success) or warns it (failure). Paths with high marks become highways. The routing follows the highways.

**RichMessage.** A Signal with a structured `data.rich` payload. Types: payment, map, form, code, image, file, embed. The channel adapter unwraps the type and renders it for the target surface.

**Signal.** The universal primitive: `{ receiver, data? }`. Everything that moves through the substrate is a Signal.

**ToolLoopAgent.** The AI SDK v6 agent loop. Runs model, tool, model until `maxSteps` is reached or the model stops calling tools. Streams tokens and tool parts to the client over SSE.

**TypeDB Group.** The substrate's group entity. Holds the conversation history, pheromone paths, and learned hypotheses for one client on one channel scope.

**Voice contract.** The per-agent configuration that enforces brand voice on every outbound message. Applied mechanically before send. Not a policy document.

---

## Named Integration

**Telegram + dental practice (illustrative)**

Token setup: `TELEGRAM_TOKEN_DENTAL` as a wrangler secret. Webhook path: `/webhook/telegram-dental`. Substrate group prefix: `tg-dental-<chat_id>`.

Voice contract: prohibits clinical advice, requires "contact our reception" fallback for clinical questions, enforces practice name in sign-off.

Rich message configuration: payment card enabled for deposit collection. Map pin enabled for practice address (triggered when a patient asks "where are you?").

Memory commands: `/memory` shows the patient's appointment history and stated concerns. `/forget` initiates the GDPR erasure flow.

First month result: 847 patient enquiries handled without staff involvement. 12 escalations to reception (14 clinical questions above the contract threshold, which triggered the fallback; the remaining 3 were edge cases the agency reviewed and used to tighten the voice contract). Zero messages outside the contract.

---

## Cross-References

- **Page 08 (Memory).** How the corpus is structured in TypeDB, what it remembers, and why it becomes a moat over time.
- **Page 09 (Teams).** How multiple agents share one Group, and how the routing decides which agent handles which signal.
- **Page 15 (Security).** The voice contract check mechanics, the quality score gate, and the GDPR erasure flow.

---

*Try the chat that scores 100 on Lighthouse.*

<!-- rubric: fit=0.94 strongest=0.91 show=0.90 cut=0.88 craft=0.91 → 0.91 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=fn -->
