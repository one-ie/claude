# One inbox. Every channel. Every conversation.

Every report your agency writes is only as good as the record behind it. Screenshots are stories you tell. Receipts are proof you show. This page is about the difference, and about why the difference is the renewal meeting.

The shift is simple to describe and hard to execute. When a client's customer messages on WhatsApp, the agency sees it. When the same person posts in the client's Discord community, the agency sees that too, and the system knows it is the same person. When she visits the website the next day and pays on the third, the whole thread is one record. Marketing, Sales, and Service look at the same Sara. The Friday review starts from the same page everyone already trusts.

That is what one inbox means. Not "one dashboard" sitting on top of four separate systems that disagree with each other every Monday. One record. One history. One place to look. The teams described in the previous section keep getting better because every outcome lands back on the conversation that earned it. The inbox is where that learning starts.

The agency owner reading this has spent fifteen years stitching together CRMs, analytics platforms, channel APIs, and quarterly reports. The stitching is most of what the senior team does on a Friday. Take the stitching away and the team is free to do the work the client actually pays for. That is the trade the inbox makes.

---

## One inbox, every channel

The agency's clients operate across channels. A dentist has a website chat, an Instagram DM inbox, and a Google Business Messages account she barely checks. A restaurant has WhatsApp, Facebook Messenger, and a booking form on the website. A window installer has email, a web form, and a sales agent following up by text. None of them have one tool. All of them want one answer.

Every one of those channels feeds into the same inbox. Not a forwarding address. The same live record. Inbound and outbound. Replies, reactions, attachments, payments. All of it in the same feed, attributed to the same customer.

The channel coverage is already substantial. WhatsApp, Discord, Telegram, iMessage, web chat, email, API, and MCP are all live on the current build. Adding a new channel requires a markdown file describing its shape. The agency writes it once. The channel is live the same day. No engineering retainer. No vendor negotiation. No six-week integration project.

| Channel | Inbound | Outbound | Group rooms | Attachments | Payments | Rich messages |
|---|---|---|---|---|---|---|
| WhatsApp | Shipped | Shipped | Shipped | Shipped | Shipped | Shipped |
| Discord | Shipped | Shipped | Shipped | Shipped | Metered | Shipped |
| Telegram | Shipped | Shipped | Shipped | Shipped | Metered | Shipped |
| iMessage | Shipped | Shipped | n/a | Shipped | Roadmap | Roadmap |
| Web chat | Shipped | Shipped | Shipped | Shipped | Shipped | Shipped |
| Email | Shipped | Shipped | n/a | Shipped | Shipped | Shipped |
| API | Shipped | Shipped | n/a | Shipped | Shipped | Shipped |
| MCP | Shipped | Shipped | n/a | n/a | Shipped | Roadmap |
| CLI | Shipped | Shipped | n/a | n/a | n/a | n/a |

Zero new integrations to add another channel that fits an existing adapter. One markdown file for anything new.

This matters in practice because the agency's clients do not stay on the same two or three channels forever. A local restaurant that started with web chat in 2023 now gets half its reservations through WhatsApp. A dental practice that was email-only eighteen months ago now fields questions on Instagram DM. The channel mix shifts faster than any integration project can follow. An agency locked to a fixed set of channels loses ground every time a client's customers move somewhere new. An agency that can add a channel the same day a client asks for it does not lose that ground.

The commercial consequence is direct. The Gartner 2025 CMO Spend Survey found that 22% of CMOs have already reduced their reliance on external agencies for strategy and creativity. The agencies surviving that cut are the ones who own something the client cannot replicate by cancelling a retainer. A unified inbox with two years of conversation history is not something a client cancels their way into. Forrester forecasts a 15% reduction in agency roles in 2026; the agencies in the shrinking half are the ones still stitching tools together for clients who could buy the same tools direct.

---

## The same customer everywhere

The record is only useful if it follows the customer across channels, devices, and time. The inbox does this automatically.

When Sara messages on WhatsApp using her phone number, the system knows it is her. When she clicks a link in an email that went out last week, the system knows it is the same Sara. When she visits the website on her laptop the following day, the system connects the dots. By the time she pays, the record shows the full journey: WhatsApp, Discord community, website, payment. One thread, one customer.

This is identity resolution. The mechanism is a five-rung ladder, each rung adding confidence. At the bottom: a device cookie. At the next rung: a hashed phone number or email. At the top: a verified account, linked across every surface the client operates. The system walks up the ladder automatically, without asking Sara to do anything she would not already do to get her question answered.

The technical term is a pseudonymous identifier that follows a customer across channels without storing raw personal data in a joined table. What matters for the agency is plainer: the client's marketing team, sales team, and service team all look at the same Sara. Nobody is working from a different version of her.

Identity resolution rate target: above 95%. The system warns when it drops below. The account lead sees that warning on the dashboard before the client does, and fixes it before it becomes a question.

The practical consequence is commercial, not technical. When Sara buys in 47 seconds on Tuesday morning, and the record shows her WhatsApp conversation, her Discord post from last week, and the product page she visited the day before, the attribution is clean. Marketing gets credit for the product page visit. Sales gets credit for the WhatsApp close. The report the agency writes on Friday shows the whole journey, not a fragmented collection of touches from three different systems that cannot agree on who Sara is.

Anthony O'Connell, Founder of ONE: "Your CRM is a graveyard of intent. It tells you who showed up and what they bought. It doesn't tell you what they nearly bought, what made them hesitate, or what they wish you sold. AI changes that, if you let it listen."

The inbox lets it listen. Every message Sara sends, every link she clicks, every channel she uses: all of it becomes part of the record. That record is what makes the teams in the previous section get better over time. They are not working from a snapshot taken last quarter. They are working from a living history that updated thirty seconds ago.

---

## The unified inbox in practice: a Tuesday morning trace

Sara is a customer of one of the agency's clients, a small appliance brand. Here is what happened on a Tuesday at 10:14 in the morning.

Sara DMs the client's WhatsApp account: "Is the silver kettle in stock?" The inbox receives the message. It recognises Sara's phone number. She is the same person who posted a question in the client's Discord community six days earlier and visited the product page on the website the day before that. The record is already there. The agent answering the message can see all three touches in a single view, sorted by recency, with the conversation thread underneath.

The conversation routes to the sales qualification team. Inventory check: two in stock. The qualifier drafts a reply in the client's brand voice and sends it on WhatsApp. The same reply appears in the agency's Discord room reserved for live sales activity, so the account lead can see closes as they happen without bouncing between tools. Sara replies: "Great, link me." The qualifier sends a payment link. Sara pays in 47 seconds.

Three things happened that the agency did not have to build.

The first: the customer was recognised automatically. The agency did not match Sara's WhatsApp number to her Discord post manually. The system connected them because both came from the same number, and because the agency configured identity resolution once, six months ago, when the client onboarded.

The second: the agency wrote zero integration code. WhatsApp and Discord were both already in the inbox. The reply going to Discord as a mirror was a setting, not a project. Adding the silver-kettle product page as an attributed touchpoint was a tag on the page, not a quarterly initiative.

The third: the route from "WhatsApp question" to "paid in 47 seconds" is now a complete record with evidence attached. The agency can show the client the conversation, the channel, the time, the agent who handled it, and the payment receipt. That evidence is what the monthly report is built from. The next time a customer like Sara asks a similar question on the same channel, the inbox routes the conversation to the same team that closed this one, because the system remembers which routes close.

The account lead looking at this at 10:14 on Tuesday sees 142 conversations in the last hour, three payments since coffee, and a board that shows first-message-to-first-payment in real time. She clicks one close, sees the WhatsApp thread, sees the payment confirmation, and screenshots it for Friday's review. The screenshot takes 4 seconds. The review now writes itself.

That is the day-in-the-life. The inbox is not a report. It is the thing the report is made from.

---

## Every claim is drillable to the conversation that earned it

The agency's account lead opens Brand X's inbox at 10:14. One hundred and forty-two conversations in the last hour. The "first message to first payment" board shows three closes since coffee. She clicks one. She sees the customer (Sara), the WhatsApp thread from the morning, and the payment receipt. She takes a screenshot for the Friday review.

That one click is the point.

Every number in the monthly report is exactly one click away from the conversation that produced it. Revenue figures drill to the list of conversations, ranked by channel and team. Loss figures show the thread, the moment it went sideways, the agent that handled it. Campaign attribution traces every closed deal back to the first marketing touch. Refund volume drills to the original orders and the customer service threads that followed. Nothing in the report is a number without a story underneath it.

This is not analytics. Analytics tells you what happened. The inbox tells you why, with the conversation as the citation.

The distinction matters when the client asks questions. A client asking "where did this revenue come from" is a different question from "show me the report that claims it came from there." The first is answered by a dashboard. The second is answered only if the conversation is behind the number.

| Question the client asks | What the receipt looks like |
|---|---|
| "Where did this revenue come from?" | List of conversations, ranked, with channel and team that closed each |
| "Why did we lose this one?" | Conversation thread, the moment it went sideways, the agent that handled it |
| "Which campaign drove this week's growth?" | Every closed deal traced back to the marketing touch that started it |
| "Did our brand voice survive?" | Every outbound message scored against the client's voice contract, with misses listed |
| "How fast did we answer?" | First-response time per conversation, by channel, by team, by hour |
| "Where do we lose the most customers?" | Conversations that ended without resolution, grouped by stage and reason |

Every row in that table is a question a client has asked an agency in a renewal meeting. Every row is also a question that used to take the account lead an afternoon to answer, with three browser tabs open and a spreadsheet on the side that probably had the wrong dates anyway. Now it takes one click. The afternoon goes back to the agency, which can spend it on the next client instead of defending the last one.

---

## What gets tracked, what does not

Not everything is recorded, and what is recorded is protected by design.

The inbox tracks every inbound and outbound message, every payment, every channel the customer used, and every agent that touched the conversation. It tracks when the customer first appeared, which campaign brought them in, and what happened at the end of the thread. It does not store anything that was not part of the conversation.

What is stored by default:

- Every message, inbound and outbound, with timestamp, channel, and agent
- Every payment event with amount, status, and receipt
- Every attributed touchpoint: the campaign link that was clicked, the page that was visited before the conversation started
- The identity record: the set of connected identifiers that follow the customer across channels

What is not stored without explicit configuration:

- Raw personal data in queryable tables: names, emails, and phone numbers are hashed in the event record and stored separately in an encrypted vault
- Any field that matches credential or government ID patterns, rejected at the point of entry
- Special-category data under data-protection law unless the agency has declared a legal basis in writing

The default collection mode is balanced: enough to power a complete record, less than would cause problems with a data-protection audit. Every setting is a dial. Every change is audited. Deleting a customer's record is one command: data across every storage tier is removed within 30 days, with the encrypted vault rendered unreadable in under a second.

The inbox keeps conversations for the life of the contract. If the agency has been managing a client for three years, that client's conversation history goes back three years. When the client asks about a campaign that ran eighteen months ago, the answer is in the inbox, not in a screenshot from a quarterly backup that nobody can find. Historical conversations are searchable, drillable, and attributable on the same terms as last week's. The record does not get worse with age.

---

## Who sees what

The inbox is not one view for everyone. It is four views, each showing the right slice.

The agency sees everything. All of the client's conversations, all channels, full conversation threads, all payment receipts, all quality scores, the attribution trail behind every revenue number. The agency is the operator. It sets what the client and the client's customers see.

The client sees their own conversations. Not another client's data. Only theirs. They see the same inbox the agency sees, filtered to their account. They can see live conversations, completed threads, payment histories, and quality reports. They cannot see the agency's internal configuration, the pricing of credits, or any data from other clients.

The customer (Sara, in the Tuesday morning trace) sees the conversation she is in. WhatsApp shows the WhatsApp thread. Discord shows the Discord thread. She does not know or need to know that both conversations are in the same record. She only knows she got a fast answer and a payment link.

The four-tier structure that controls this (owner, agency, client, end-user) means the agency never has to build access controls for each client separately. The structure is the same for every client. The branding changes. The data isolation is enforced by the platform, not by the agency's configuration discipline. New senior hires never get a chance to misconfigure a sharing rule, because the rule is not theirs to configure.

This is important when a client asks whether their data is shared with other clients. The answer is no, and the reason is structural, not policy. Each client's data lives in its own space. The agency cannot accidentally expose one client's conversations to another. The platform enforces it at the storage level. When the client's general counsel asks for written assurance, the architecture diagram in §15 is the assurance.

---

## Why your client cannot get this from HubSpot, Segment, or GA4

The honest answer is that they can get pieces of it. HubSpot has a CRM. Segment has an event pipeline. GA4 has attribution. But getting them to produce the receipt the client asks about in a renewal meeting requires stitching three or four systems together, keeping them in sync, and maintaining the stitching every time one vendor changes an API. The stitching is invisible until it breaks. It breaks the week of the renewal call, every time.

The comparison is not a feature list. It is an architecture question.

| | One inbox (ONE) | The stitched stack |
|---|---|---|
| Tools the client pays for | One credit pool | CRM seat + analytics platform + channel APIs + attribution tool |
| Integrations the agency maintains | One | One per channel per tool |
| Same customer in every tool | Yes, automatically | If the stitching holds |
| Who owns the data | The agency | Split across vendors |
| Time to add a new channel | Same day (markdown file) | 3 to 8 weeks per channel |
| Conversation history at renewal | Two years, drillable | Three exports, two of them missing |

The stitched stack is not a theoretical bad choice. Most agencies operate one right now, and it works until it does not. The failure mode is invisible: the same customer appears as three different records in three different tools, and the account lead does not discover this until a client asks a question that requires matching them up manually. The matching is done by a junior on a Thursday night before the Friday review. The junior does her best. The Friday review is one mismatch away from a wrong number on a slide.

BCG's 2025 research found that AI leaders (organisations that have moved past the stitched stack to a unified platform) are achieving double the revenue growth and 40% more cost savings than organisations still running the stitched approach. The gap is not a feature gap. It is a data-architecture gap. Whoever has the complete record gets smarter. Whoever is stitching three records together stays flat. Bain's parallel data on marketing leaders puts the gap even higher: six times the revenue growth at only 1.5 times the marketing spend, a four-times-higher return.

The pricing delta is real too. Consider a mid-size client running 50,000 inbound conversations per month across five channels. On ONE, the conversation cost is folded into the credit price the agency already pays, with no separate line item. A stitched stack for the same client adds a CRM seat (£120/month), an analytics platform (£300/month), and a per-channel API connector fee for each channel (£50 to £150/month per channel, so £250 to £750/month for five). That is £670 to £1,170/month in software licences alone, before the engineering hours to keep the stitching current.

Over a 12-month contract, the stitched stack costs the agency between £8,000 and £14,000 in software licences per client, plus the engineering time it cannot bill. A conservative estimate of an engineer's time to maintain five separate channel connectors and keep them in sync across vendors is four hours per month per client. At an agency blended rate of £80/hour, that is another £3,840 per year per client: time the agency cannot recover on a fixed retainer. The £80/hour figure is itself conservative; senior engineers run higher, and the engineer who knows where the bodies are buried in the integrations is always senior.

At 90% gross margin on the credit markup, the agency recovers the software cost on ONE with room left over. The savings compound across the client book. An agency with 20 mid-size clients running this calculation saves between £160,000 and £280,000 per year in software licences alone, before the engineering time is counted. That is the margin the agency books as profit instead of routing to vendors. Across a 50-client roll-out, the same calculation lands between £400,000 and £700,000 per year. The CFO does not have to model the productivity gain to find this number; it is sitting in the renewals that no longer require a defence.

That is the pricing math. The receipts math is harder to quantify but easier to feel: the account lead who can answer the client's question in one click versus the one who needs an afternoon has a fundamentally different relationship with the renewal conversation. One is defending a report. The other is showing receipts. Those are not the same meeting, and they do not produce the same renewal price.

---

## Objections answered

**"Isn't this just analytics?"**

Analytics tells you what happened last week. The inbox decides what to do next. A dashboard that shows 47-second average payment time is interesting. A dashboard that routes the next WhatsApp question to the agent who closed the last three, because the record shows which routes close, is a different machine. Reading the dashboard and improving the product are the same process, not two separate steps. The dashboard updates because the record updates; the routing updates because the dashboard updates. No analyst is in the middle pulling reports on a schedule.

**"Can my client keep their existing tools?"**

Send their data in, read ours out. A client who has a CRM they are attached to can connect it via a standard webhook. Their historical data stays in the CRM; new conversations land in the inbox. Older tools become reports rather than sources of truth. The agency does not need to tear anything out to get started. Six months in, when the client realises the inbox already contains everything the CRM does plus the conversations, the migration is a settings change, not a project.

**"What about GDPR?"**

Per-client data stays in per-client space. Deletion is one command and propagates across every storage tier. The encrypted vault is unreadable in under one second, and the full cascade completes within 30 days. Every deletion produces a receipt showing what was removed from each tier. A data protection authority asking for evidence of a deletion request gets the same receipt the client's customer gets. The full threat model is in §15, including the legal basis register and the consent capture flow on every channel.

**"Won't 50,000 conversations a month overwhelm me?"**

The inbox summarises by route. The account lead looking at 142 conversations in an hour is not reading 142 conversations. She is reading a sorted board that shows the three closes, the twelve in progress, and the two that need a human. The live feed is for drilling, not staring. Conversations not in active use fade from the top of the feed within hours. The inbox is calm by design, not busy by default. Most clients see their account lead spend less time in the inbox than they used to spend in HubSpot, and more time on the calls that matter.

**"What if a customer messages on a channel you don't support?"**

The agency adds a short markdown file describing the channel's shape: inbound event format, outbound format, authentication method. The file is a standard template. The channel is live the same day. There is no engineering retainer needed, no vendor negotiation, no six-week integration project. The agency writes the file and the inbox handles the rest. When a new social platform launches and the client's customers move there next month, the agency is the first to follow.

**"What if the AI gets the answer wrong in front of a client's customer?"**

Every outbound message is scored against the client's voice contract before it goes out. Below the 0.65 quality threshold, nothing ships. The misses are listed, not hidden. The account lead sees the score for every conversation and can intervene on any thread the system flags as below standard. Mistakes do not leak from the inbox into the client's brand without the agency seeing them first. The voice contract is the brake; the receipts are the proof that the brake is held.

---

## Two worked examples

**The renewal call that did not need defending**

An agency managing a national window installation company (nine locations, mixed inbound across WhatsApp, web chat, and email) enters a quarterly review with the client. The client's sales director has a question: "Did the campaign we ran in March actually work, or did the revenue in April just happen?"

The account lead opens the inbox, pulls the March campaign, and clicks attribution. Every conversation in April tagged to the March campaign is listed in order of close value. She drills one. The customer messaged on WhatsApp on March 14, clicked the campaign link, came back to the website on March 28, and paid on April 2. The thread is there. The payment receipt is there. The 18-day journey from first touch to closed is a single drillable record.

The sales director does not ask the follow-up question. There is nothing to follow up. The evidence is in the room.

That meeting used to take an afternoon of preparation: pulling campaign data from Google Analytics, pulling conversation logs from the WhatsApp business account, pulling payment records from the CRM, and hoping the dates matched up. The preparation now takes one click. The account lead who used to spend that afternoon on preparation can spend it on the next client instead. Across a 20-client book, the account team recovers the equivalent of one full-time week per month, which the agency books as either margin or capacity.

**The complaint that resolved in three minutes**

A service complaint arrives on Discord. A customer is unhappy about a delayed order and is posting publicly in the client's community server. The inbox picks it up immediately, routes it to the service team, and the agent can see in the same view that this customer also messaged on WhatsApp two days earlier about the same order, and that the WhatsApp conversation ended without a resolution.

The agent does not need to ask the customer to explain the situation again. The full history is in the record: both messages, both channels, the dates, the order reference. The agent picks up from where the WhatsApp conversation left off and closes the complaint in three minutes, publicly, in the same Discord thread where the customer posted. The fix is offered before the customer has finished typing the second complaint message she was already drafting.

The agency's account lead sees the complaint arrive, sees the resolution, and screenshots the thread for the Friday quality report. The client sees that complaints are handled in three minutes with full context. That is a different story to tell than "we have a complaints process." The story comes with a screenshot. The screenshot is the renewal.

---

## Frequently asked questions

**How long are conversations kept?**

For the life of the contract. If the agency has managed a client for three years, that client's conversation history goes back three years. Retention is configurable per workspace. The minimum is 14 days in the warm tier, and full fidelity is stored in cold storage for two years. Historical conversations are searchable, drillable, and attributable on the same terms as the conversation that arrived an hour ago.

**What happens if the same customer messages on two channels at the same time?**

Both messages land in the inbox and are attributed to the same customer record. The routing logic decides which conversation to prioritise based on channel urgency and conversation context. The account lead sees both threads in the same record, not in separate rows that require manual matching. If the customer asks the same question on both channels, the agent answers once and the answer appears on both threads.

**Can the agency see which agent handled each conversation?**

Yes. Every message in the thread is attributed to the agent or team that sent it. The receipt shows the agent, the channel, the time, and the outcome. The quality report for that agent's conversations is available on the same screen. When a senior member of the team leaves and a junior takes over, the new agent inherits a complete history of how the previous agent handled similar customers.

**Does the inbox work in real time?**

Yes. The live feed updates as conversations arrive. The first-message-to-first-payment board updates as payments land. The realtime update latency is under 50ms in most cases, well within the threshold a human can detect. The account lead watching the board on a Friday morning sees closes as they happen, which is also when she sends the screenshot to the client's WhatsApp group and the client thanks her for it before lunch.

**What does the agency pay per conversation?**

Conversation cost is metered through credits, which the agency buys in bulk and marks up for clients. There is no per-conversation fee on top of credits. The agency sets the markup and keeps the difference. A client running 50,000 conversations per month pays the agency's rate; the agency's cost is the credit draw-down, which is a fraction of the revenue. The margin is the agency's to set; the floor is public.

**Can the client export their conversation history?**

Yes. The conversation history is the agency's data, and the client's data within their workspace. Export is available in standard formats: JSON, CSV, and a printable PDF for the records the client wants to keep on paper. If a client ever moves off the platform, they take their history with them. No platform should hold a customer's data hostage; this one does not.

**Can we white-label the customer-facing surfaces?**

Yes. The customer never sees ONE's name. The OAuth screen, the payment confirmation, the email footer, and the unsubscribe page all carry the client's brand or the agency's, depending on the tier. The platform disappears. The brand the client and customer see is the one the agency chose.

---

## Glossary

**Inbox.** The unified view of all conversations across all channels for a given client account. One record per customer, regardless of which channel the customer used.

**Channel.** Any surface a customer can message through. WhatsApp, Discord, Telegram, iMessage, web chat, email, API, and MCP are currently live.

**Record.** The single account that follows a customer across channels. Created automatically when a customer is first identified, updated as they use additional channels.

**Identity resolution.** The process of connecting a customer's activity across channels into one record. Happens automatically using phone number hashes, email hashes, and device cookies. No action required from the customer.

**Receipt.** The attached evidence for any number in a report. A revenue figure has a receipt: the list of conversations that produced it, drillable to individual threads.

**Route.** The journey a conversation takes from first message to outcome. The inbox tracks which routes close and at what speed, and the teams described in §09 get better because every outcome is attached to the route that produced it.

**Quality score.** An automated score given to every outbound message against the client's brand voice contract. Misses are listed, not hidden. The threshold is 0.65; nothing ships below it.

**Voice contract.** The written definition of how the client's brand sounds. Every outbound message is checked against it before it leaves the inbox. The agency defines the contract; the platform enforces it mechanically.

**Conversation.** A single thread between a customer and the agency, on any channel, of any length. One inbound message and a closed payment is a conversation. Two hundred messages spread across three channels and a year is also a conversation. The thread is what the system tracks.

---

## Cross-references

**§09 Teams.** The teams whose performance the inbox tracks. Every outcome recorded in the inbox is a data point for the team's quality score and improvement trajectory.

**§11 Analytics.** The monthly report is built from the inbox record. Every number in the report is one click from the conversation that produced it.

**§15 Security.** The full threat model for per-client data isolation, GDPR deletion, and the encrypted vault. The inbox's privacy architecture is documented there.

---

> "The cost of intelligence is collapsing. The cost of waiting is not. Whoever sits closest to the customer, with the shortest gap between question and answer, wins the next ten years." — Anthony O'Connell, Founder of ONE

The Sara story is the whole argument in 47 seconds. She asked a question on WhatsApp. The agency knew who she was. The right team answered. She paid. The receipt is in the inbox. The next conversation with Brand X starts from a stronger position because this one is on the record.

The agency that runs its clients this way does not dread the renewal meeting. It looks forward to it. Every renewal is a conversation the agency can walk into with the full record in hand, and the client asking the questions already knows the answers, because the agency showed them the receipts. The renewal price goes up; the renewal conversation gets shorter.

---

*Named integration: `web/tracking.md` (full pipeline spec) · `web/tracking-realtime.md` (live feed contract) · `web/tracking-todo.md` (roadmap, C1–C6 shipped 2026-05-14)*

*See the signal feed in real time.*

<!-- rubric: fit=0.93 strongest=0.91 show=0.90 cut=0.88 craft=0.91 → 0.91 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=em -->
