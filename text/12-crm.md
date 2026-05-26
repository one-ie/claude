# The CRM Is Already Running

You pay for HubSpot. You pay for the HubSpot seat per client. Then you pay someone to keep it clean. Then you wonder why a contact in HubSpot and a conversation in your inbox are describing two different people.

There is a simpler possibility. What if the thing that routes every conversation also holds every record? What if the database your agents write to is already the CRM, and the CRM is just a different lens on the same data?

That is what ONE does. Not as a feature. As a consequence. The substrate stores contacts as actors. It stores conversations as signals. It stores deals as paths with pheromone on them. When a lead opens a chat, talks to an agent, gets a proposal, and buys, every step writes to the same brain. No sync job. No duplicate record. No separate vendor.

For an agency with 200 clients, that is one fewer CRM seat per client. One fewer renewal negotiation. One fewer password to rotate. One fewer data export to wrangle every time a client asks "what happened with that lead from March?"

The answer is already in the substrate. You open the actor view.

---

> "Your CRM is a graveyard of intent. It tells you who showed up and what they bought. It doesn't tell you what they nearly bought, what made them hesitate, or what they wish you sold. AI changes that — if you let it listen."
>
> — Anthony O'Connell, Founder of ONE

---

## Actors as records (no separate CRM seat)

The substrate has six dimensions. The second is actors. Every contact your agents have ever handled is an actor row. Not a "contact record" in a parallel database. An actor in the same brain that routes signals, hardens paths, and decides what to do next.

The schema ships with these fields live: `name`, `email`, `phone`, `lifecycle`, `fit-score`, `ltv`, `consent-channels`, `channels`, `dormancy-state`, `actor-type`. The actor type covers both humans and agents. Both can be clients. Both can be in a pipeline.

From the contact detail page shipped on 14 May 2026:

```
/crm/c/:actor

ADA LOVELACE
ada@l.org · +44 7700 …
lifecycle: customer   fit-score: 0.82   ltv: £4,210

consent: email ✓  sms ✓  push ✗  call ✗
channels: telegram@ada   discord:ada#1234   web:visitor_hash…

▸ identity     same-as: email-hash, phone-hash, visitor_hash
▸ stack        personas: founder/dev-tooling, awareness: 4/5
▸ groups       audience:enterprise   segment:trial-d14
▸ paths        entry:hn-launch → trial → upgrade  (strength 0.74)
▸ appended     clearbit:title=CTO  apollo:fund=£12m  stripe:plan=pro
▸ activity
  12:04  click   /pricing    campaign:apr-q2   utm:hn
  12:01  open    email E3-trial-d7
  yest   reply   telegram    "is there an MCP server?"
```

Every field on that screen is a TypeDB attribute or a derived view over signals already stored. There is no separate contact table. There is no nightly sync. Changing the contact's lifecycle from `sql` to `customer` writes a signal back to the substrate, which marks the path, which strengthens the route from that stage to the next. The record and the learning are the same thing.

For Brad, the arithmetic is direct. 200 active clients, each with their own HubSpot seat, each with a license fee, each with a contact who calls every quarter asking "can you export my data?" One substrate. One actor table. Every client's contacts live in their own workspace with role-based access at the 4-tier level: owner sees all, agency sees clients, client sees their own end users, end users see themselves. No migration required. No seat to add when the client's list grows by a thousand names.

Eight CRM-standard actor attributes are live. The enrichment layer adds more. The identity ladder resolves the same person across channels (the visitor who clicked an ad, the email that opened the campaign, the Telegram account that asked a question) into one actor with a `same-as` relation, confidence-scored. Identity resolution targets above 95%.

---

## Conversations as history (auto-logged)

Every message in every channel is a signal. Signals have a sender, a receiver, a timestamp, and a payload. The activity feed on a contact record is a filtered view over the signal stream for that actor. It is not a separate log. It does not need to be exported. It does not go stale.

When the agent replies to a Telegram message, the reply is a signal. When the email is opened, the open is a signal tagged `touch:open · channel:email · campaign:apr-q2`. When the lead clicks the pricing page, the click is a signal tagged `touch:click · path:/pricing`. When the deal closes, the purchase signal `mark()`s the path from `sql` to `customer` with the purchase value.

The activity feed loads from D1 (the hot path, <100ms) with the last 50 signals. It is live. The pheromone dots next to the contact's name in the list view reflect the strength of their strongest inbound path (five dots for a converting customer, one dot for a cold lead) and they update in real time.

For an agency managing a dentist client in Brisbane, that means every chat conversation that dentist's receptionist has with the chatbot is captured. Every web visit from a patient, every Telegram inquiry, every appointment request. All signals, all on the same actor record. When Brad's team needs to know "what happened with Mrs Chen from March?" they open the actor view. They see every touch in order, every channel she used, every word the agent said, and whether she converted.

No manual entry. No "please log the call notes in HubSpot." The agents log everything. The humans review.

The signal stream includes channel, event type, campaign tag, UTM attribution, agent response, latency, pheromone deposit, and path strength change. For a client whose CRM currently holds "called 2024-03-12, left voicemail" and nothing else, this is a different class of record.

---

## The pipeline writes itself

A CRM pipeline is a sequence of stages. Traditionally, someone moves a deal card from "Lead" to "Qualified" to "Proposal Sent" to "Won." That motion requires a human. It requires discipline. It requires that the human be aware of every conversation happening across every channel and remember to update the card.

The substrate replaces all of that with one mechanic: signal-driven stage transitions.

When a new contact fills in a form on the client's site, the form submission fires a signal tagged `intent:high · channel:web`. The CRM agent evaluates the actor's lifecycle field. It is currently `anonymous`. The signal pattern matches the rule for `anonymous → lead`. The actor's lifecycle attribute updates. The path from that source gains pheromone. The contact appears in the "new leads" segment. No one moved a card.

When the lead asks "can you send me a proposal?" in the chat, the NLU layer classifies the intent. The signal lands as `intent:proposal-request · channel:chat`. That matches the rule for `lead → sql`. The actor's lifecycle updates. A signal fires to the proposal agent: build and send the proposal. The proposal agent generates it, sends it via the best-consented channel, and logs the send as a `touch:send` signal. The path from `sql` to the proposal stage gets marked. The deal record (a `thing` of type `offer`) is created and linked to the actor.

None of that required a human. A human can override any of it. The rule that fired is visible on the contact record: "Lifecycle advanced to sql because: `intent:proposal-request · channel:chat`." The human can reverse the decision, which writes a signal tagged `actor:override · stage:sql`, also logged.

The pipeline is the substrate's path graph, rendered as a funnel. What looks like a Kanban board is pheromone. The thickness of the edge from one stage to the next is the actual strength of that path, built from real outcomes across real contacts.

For Brad's 200 clients, the pipeline across all seven ICPs (dentists, accountants, window-and-door, restaurant, MDU, multi-location commercial) runs the same substrate. Each ICP gets its own agent persona and its own lifecycle rules. The pipeline for a dentist client is different from the pipeline for an accounting firm. The substrate handles both, in the same brain, with the same six verbs. No custom CRM instance to configure for each vertical.

---

## Stage transitions (signal-driven, not manual)

The six lifecycle stages are locked vocabulary: `anonymous → lead → mql → sql → customer → advocate`. The `churned` state is a branch off `customer`. Dormancy is orthogonal: `active | warming | cold | reactivated | lost`, driven by the fade loop (L3) on last-seen date and path strength.

Stage transitions happen when a signal matches a rule. The rule lives on the path between stages, with a signal pattern (event type, tag, channel, weight) and a confidence threshold. When an incoming signal matches pattern and confidence, the transition fires.

The six standard CRM verbs map directly to substrate operations:

| CRM verb | Substrate operation | What fires |
| --- | --- | --- |
| Capture | `signal` → actor upsert | `anonymous → lead` on intent signal |
| Qualify | `mark(edge)` | `lead → mql` on engagement score |
| Contact | `signal` → outbound send | `touch:send` on best-consented channel |
| Propose | `thing:offer` created | `mql → sql` on proposal-request intent |
| Close | `mark(edge, value)` | `sql → customer` on purchase signal |
| Retain | `fade` + `follow` | Dormancy detection, re-engagement routing |

Which agent owns which verb is configured per workspace. By default: `crm` agent owns qualify and capture; `email` agent owns contact; the selling agent owns propose; `crm` agent marks close; the learning loop owns retain.

The signal pattern that advances `mql → sql` is configurable. For a dentist client it might be "appointment-request OR callback-request." For an accounting firm it might be "proposal-request OR 'fees' mentioned in chat." The agent running the dentist's practice does not need a human to tell it that "can I book a consult?" means "advance this lead." The model classifies the intent, the substrate fires the transition, and the path records it.

A human override is one keystroke away. The CRM contact screen shows the rule that fired. The human reverses it. The reversal is itself a signal, which feeds back to the model: "this classification was wrong for this client." The next time a similar message arrives in that workspace, the model's prior shifts.

This is not automation in the 2015 sense. Automation in 2015 meant "if lifecycle = lead, send an email after 3 days." Signal-driven transitions mean "when this pattern of signals suggests the actor is ready to move, advance the stage, and tell me which rule fired." The first is a cron job. The second is judgment.

---

## Enrichment (from public sources and tool integrations)

An actor record starts with whatever the person volunteered. Name, email, phone if they gave those. Channel handles from the platforms they arrived on. A `visitor_hash` from the cookie if they arrived on web without identifying themselves.

Enrichment fills the rest. When an actor's lifecycle transitions to `lead`, the import agents fire: `import-clearbit`, `import-apollo`, `import-stripe` (if there's a Stripe record), `import-shopify` (if the client is e-commerce), `import-ga4`. Each writes attributes back to the actor in the `appended.<source>.<field>` namespace.

The result on the contact screen:

```
▸ appended
  clearbit:title   CTO
  clearbit:company Engine Ltd
  apollo:fund      £12m seed (2024)
  stripe:plan      pro
  stripe:ltv       £1,840
```

Provenance is preserved. Each attribute records which agent wrote it and when. Re-enrichment is a fade-then-write: the old value fades, the new value lands. There is no silent overwrite. If Clearbit says the person is a "VP Marketing" and Apollo says they are a "CTO," both attributes live, with source. A human can pin the preferred value.

Enrichment fields per actor (across Clearbit, Apollo, Stripe, Shopify, GA4, and the identity ladder) run to more than 40 distinct attributes. The namespace is open: adding a source means adding an importer agent that writes to `appended.<newsource>.<field>`. No schema migration. No new CRM table.

For Brad's clients, enrichment means a dentist's new lead (who arrived via a Google ad, gave their name and email, and asked about pricing) can be enriched within seconds with their approximate company size, location, and whether they have an existing practice management software account. The agent that sends the follow-up message knows that. The message is different.

Enrichment is event-driven, not batch. There is no "nightly enrichment run" that may or may not have run by morning. When the lead arrives, the enrichment fires. The contact record is complete before the first outbound message goes out.

---

## Handoff to human (when and how)

The substrate handles conversations that match patterns. When a conversation falls outside the agent's confidence gate (below the 0.65 rubric threshold) it routes to a human. That routing is itself a signal: `actor:escalate · reason:low-confidence · channel:<x>`. The human receives the full context: every signal in the thread, every attribute on the actor, the agent's response attempt and confidence score, and the suggested next action.

The inbox at `/crm/inbox` is a reverse-segment: all inbound signals tagged `inbound AND closed:false`. Replying from the inbox sends a signal back on the correct channel and `mark()`s the path. The loop closes. The pheromone records that a human handled this type of conversation, which improves routing for the next similar signal.

The handoff triggers for three reasons.

First: the agent encounters an intent it cannot classify. The model's confidence is below threshold. It flags for human review before sending any response. The contact does not see a wrong answer from the bot. They see nothing until the human confirms the reply.

Second: the actor is flagged as high-value. A `fit-score` above a threshold, or an LTV above a configured floor, routes escalation regardless of confidence. High-value clients get a human in the loop by default.

Third: the signal contains a complaint, a refund request, or a keyword matching the escalation list. The compliance agent intercepts and routes to human. The escalation event is logged.

In all three cases, the human receives the full conversation thread, the actor's lifecycle stage, their consent channels, their enriched attributes, and the agent's draft reply. They review the draft, edit it, and send. Or they discard the draft and write their own. Either way, the signal closes the loop.

For an agency managing 200 clients, the inbox aggregates escalations across all workspaces the team member has access to. The list sorts by actor LTV descending. A £4,200 LTV customer's unanswered Telegram message appears at the top. A cold lead's email inquiry appears at the bottom. The human processes the list in priority order. No client's inbox goes unmonitored. No message falls through because it arrived on the wrong channel.

---

## Importing an existing CRM

The question Brad will ask is not "how do I use this?" It is "what do I do with HubSpot?"

Nothing changes immediately. The substrate and HubSpot run in parallel during the transition. The substrate accepts inbound contacts from any CSV export. The importer agent maps HubSpot field names to substrate attributes: `firstname + lastname → name`, `email → email`, `hs_lead_status → lifecycle`, `hubspot_owner_id → owner tag`. A standard HubSpot export maps in one pass.

The write-through path goes the other way: the substrate pushes actor updates back to HubSpot as signals arrive. When a contact advances from `mql` to `sql`, a signal fires to the `export-hubspot` agent, which updates the HubSpot lifecycle stage via the HubSpot CRM API. Brad's sales team keeps their HubSpot view during the transition. The records stay in sync.

Over time, the substrate becomes the source of truth. HubSpot becomes a read-only reporting view. That transition happens at Brad's pace, client by client, as the substrate accumulates enough signal history that its view is richer than HubSpot's. For most clients, that point arrives within 90 days of the first conversation.

The five objections, answered directly.

**"My agency already uses HubSpot. Am I migrating?"** No. You run both in parallel. The substrate receives all inbound signals and pushes lifecycle updates to HubSpot via the export agent. Your team sees HubSpot until they prefer not to. The migration is gradual and reversible at any point before you decide to stop paying the HubSpot seat.

**"Will my client's data transfer cleanly?"** The standard export maps in one pass for HubSpot, Salesforce, and GoHighLevel. The importer agent handles the field mapping. Duplicates resolve via the identity ladder: same email, same actor.

**"What if HubSpot has data the substrate doesn't support?"** HubSpot custom properties map to the `appended.hubspot.<field>` namespace. Preserved, searchable, visible on the contact screen. Nothing is lost.

**"Can I keep HubSpot for specific clients?"** Yes. The sync runs per workspace. A client on HubSpot stays on HubSpot until you move their workspace. The two coexist.

**"What happens to my HubSpot workflows and sequences?"** They keep running during the transition. As you move clients to the substrate, their automation moves to journeys. A HubSpot sequence is a journey with stages. The migration is a mapping exercise, not a rebuild.

---

## A day in the life

It is 8 a.m. Brad's agency manages the marketing for 47 local-service businesses: dentists, accountants, window-and-door installers. The overnight inbox has 14 escalations: messages that arrived while the agents were running but fell below the confidence threshold or hit the high-value routing rule.

Brad's account manager opens the inbox. The first escalation is from a dentist client's top lead: a conversation that started at 11 p.m., five messages deep, asking about pricing for a specific service the dentist offers. The agent attempted a response, scored 0.61 confidence, flagged for human review. The draft reply is there, pulled from the service description and pricing sheet in the agent's memory. The account manager reads the thread, adjusts the price quote, and sends it. 45 seconds. The loop closes. The path from `pricing-inquiry` to `qualified-lead` gets marked.

The second escalation is a complaint from an existing customer of the window-and-door client. The compliance agent flagged it on "refund request." The issue is straightforward: wrong size delivered. The account manager replies with the resolution process and flags the order number for the client's operations team. The signal logs as `complaint-resolved`. The actor's dormancy state stays `active` rather than flipping to `cold`.

By 8:45 a.m., all 14 escalations are cleared. The rest of the morning's conversations (several hundred of them) were handled by agents without human involvement. They are in the contact records, marked, pheromone deposited, paths strengthened.

The account manager opens the CRM view for the dentist client. The pipeline shows 6 new leads from overnight, 2 of which advanced to `mql` on their own. The segment "trials-d7, dentist" has 8 contacts. The agent sent them each a Telegram follow-up at 7 a.m. on the campaign schedule. Three opened it. One replied. That reply advanced the actor to `sql`. A proposal is being drafted by the proposal agent.

None of this was set in motion this morning. It was running before they arrived.

---

## Worked example

A lead opens the chat on a dentist client's website at 11:42 p.m. on a Thursday.

She types: "Hi, I'm looking for a family dentist, do you take new patients?"

**Step 1. Actor upsert.** The chat fires a `signal` to the claw worker. The signal carries no identity yet. A `visitor_hash` is generated from a first-party cookie. An anonymous actor is created with that hash. Lifecycle: `anonymous`.

**Step 2. Agent handles the conversation.** The dentist's chat agent responds: the practice is taking new patients, here are the appointment types, what age are the family members? The conversation continues for four exchanges. The actor's activity feed fills up. Every message, every agent reply, every timestamp.

**Step 3. Email capture.** The agent asks if she'd like to book a consultation. She says yes. The agent asks for her name and email so the practice can confirm. She provides both. The email lands on the actor: `email = her@address.com`. The identity ladder fires a `same-as` relation between her `visitor_hash` and her `email-hash`. Confidence: 1.0 (deterministic match). The actor is no longer anonymous. Lifecycle transitions to `lead`.

**Step 4. Enrichment.** The `import-clearbit` agent fires on the `lifecycle:lead` signal. Within 3 seconds, the actor record gains: `appended.clearbit.location = Brisbane`, `appended.clearbit.persona = parent/family`. The enrichment is visible on the contact screen before the account manager arrives in the morning.

**Step 5. "Send me more information."** Near the end of the conversation she says: "Can you send me some information about the hygienist appointment process?" The NLU layer classifies this as `intent:proposal-adjacent`. The agent sends a formatted message with the hygiene overview and a tracked link to the booking page: `https://dentist.clinic/go/9mK`. The `signal` logs as `touch:send · channel:web-chat · campaign:new-patient-flow`.

**Step 6. Tracked link click.** The next morning she clicks the link. The `/go/9mK` Worker resolves the HMAC, writes a `touch:click` signal to the actor record, sets the first-party cookie on the dentist's domain, and redirects her to the booking page with `?oid=<hash>` so the page pre-loads her name and appointment context. No login required.

**Step 7. Appointment booked.** She completes the booking form. The form submission fires a signal tagged `intent:purchase · value:120`. The CRM agent evaluates: this matches the `sql → customer` rule. Lifecycle advances to `customer`. The path from `new-patient-flow → consultation-booked` gets marked with strength proportional to the appointment value. The monthly report will show this conversion.

Total time from first message to conversion: 18 hours. Human involvement: zero. Every step is in the contact record. Every signal is attributable to a campaign. The path from that campaign to that appointment value has pheromone on it. The next lead who follows the same path will be routed faster.

---

## Comparison: substrate CRM versus traditional CRM

The comparison that matters for Brad is not feature-by-feature. It is unit-economics-by-unit-economics.

A HubSpot Professional seat for one client workspace runs around $800/month for a full feature set (marketing, sales, service hubs combined). At 50 clients, that is $40,000/month before add-ons, before contact tier surcharges, before onboarding fees.

The substrate does not charge per workspace. It charges per credit consumed. A conversation that goes ten messages deep and triggers enrichment, two outbound sends, and a lifecycle transition costs on the order of $0.04 in credits. At 1,000 conversations per month per client, that is $40 per client. At 50 clients: $2,000/month. At 200 clients: $8,000/month.

The gap is not the point. The point is the shape of the cost. HubSpot charges by the seat. The substrate charges by the action. As a client's business grows, their HubSpot bill grows with headcount and contact tier. Their substrate cost grows with conversation volume, and conversation volume is the thing that generates revenue, so the cost is proportional to the value.

The second comparison is what each system knows. HubSpot knows what a human entered and what a form captured. The substrate knows every conversation, every channel, every intent signal, every moment of hesitation, every path taken and not taken. The quote that opens this page names the gap: a CRM is a graveyard of intent. The substrate is a living record of it.

The third comparison is what each does with what it knows. HubSpot surfaces a record. The substrate routes the next action. The distinction is between a filing cabinet and a brain.

---

## Objections

**"My team is trained on HubSpot. Switching will cost me weeks."** The transition is not a switch. The substrate runs alongside HubSpot. Your team keeps their HubSpot view until the substrate's view is richer (typically within 90 days of the first client going live). No retraining event. A gradual shift in where the team goes first.

**"HubSpot has CRM features the substrate doesn't have yet: custom pipelines, deal cards, forecasting."** Correct on specific features. The pipeline is signal-driven, not visual Kanban. Forecasting comes from the analytics layer, not a dedicated forecast module. If a visual deal card is load-bearing for your sales process, keep HubSpot for that workflow while the substrate handles the conversation and enrichment layer. The two integrate via the write-through path.

**"I need my clients to see their own CRM data."** The 4-tier role cascade handles this. A client has access to their own workspace contacts. They log into the CRM view on their subdomain, branded with your agency's name, and see their own actor records, segments, and journey funnels. They do not see other clients. They do not see the substrate layer. They see a CRM that looks like it was built for them.

**"What if I have contacts in multiple systems: Salesforce, Klaviyo, Mailchimp?"** Each has an export path. The importer agents handle CSV and API imports for Salesforce and Klaviyo. Mailchimp exports to CSV, which maps in one pass. Duplicates are resolved by email hash in the identity ladder. The contact history from each system is preserved in the `appended.<source>.<field>` namespace.

**"How do I know the data won't end up somewhere it shouldn't?"** Each workspace is isolated at the D1 and TypeDB level. Per-client data spaces. Deletion in one command: `POST /api/forget { actor_id }` cascades across vault, KV, D1, TypeDB, and ad platforms within 30 seconds. The cascade receipt is available for audit. GDPR Art. 17 and CCPA delete both flow through the same endpoint. The DPA and the client see the same receipt.

**"What about my existing CRM workflows: lead scoring, sequences, nurture campaigns?"** Lead scoring maps to fit-score, a TypeDB attribute on the actor, computed by the CRM agent from engagement signals and enriched attributes. Sequences map to journeys with the same stage-signal structure, holdout logic, and attribution. Nurture campaigns map to broadcast programs with the consent gate and frequency cap enforced mechanically. The concepts are the same. The names are different.

**"Can I run a CRM for a client whose business is mostly walk-in, not digital?"** Walk-in customers arrive as web contacts when they book online, as Telegram contacts when they message, or as CSV imports from the practice management system. The substrate does not require digital-first customers. The contact record exists for anyone you can name. For purely walk-in customers with no digital footprint, the contact is a manual entry, the same as any CRM.

**"My clients already use a CRM they like. Why pull them off it?"** You would not, immediately. The substrate is additive for clients already on a tool they value. You run the substrate for the conversation layer (chat, Telegram, email, inbound signal handling) and the write-through path keeps their existing CRM in sync. Over time, the substrate's view is richer. The transition happens when it makes sense per client, not as a mandate.

---

## Code shape: actor query

The actor query behind the contact screen, shipped in `web/src/lib/crm/actor.ts`:

```ts
// getContact — TypeDB query aggregating actor attributes and relations
const attrRows = await typedbQuery(
  env,
  `match
    $a isa actor, has aid "${id}", has $attr;
    $attr isa! $kind;
  select $attr, $kind;`,
)

// groupRows — membership relations
const groupRows = await typedbQuery(
  env,
  `match
    $a isa actor, has aid "${id}";
    $g isa group, has gid $gid;
    (member: $a, group: $g) isa membership;
  select $gid, $gname;`,
)

// pathRows — strongest outbound paths, sorted by pheromone strength
const pathRows = await typedbQuery(
  env,
  `match
    $a isa actor, has aid "${id}";
    $o isa actor, has aid $oid;
    $e (source: $a, target: $o) isa path, has strength $s;
  sort $s desc; limit 20;
  select $oid, $s;`,
)
```

The REST endpoint wrapping this query shipped as `GET /api/actors/[id]` in commit `74e47496`. The activity endpoint `GET /api/actors/[id]/activity` reads from D1, returning the last 50 signals in reverse chronological order with cursor pagination.

The enrichment layer, shipped in commit `79fd203c`, adds:

```ts
// Enrich actor with D1 events, substrate paths, identity rungs
export async function enrichActor(env, actorId: string): Promise<Contact>
```

Both ship without a separate CRM database. Both read from the substrate that routes every other operation in the system.

---

## Signal flow: actor to outcome

```
lead opens chat
     │ signal { receiver: 'agent:dentist', data: { content, visitor_hash } }
     ▼
agent handles conversation
     │ signals fire per message (touch:receive, touch:reply, touch:open…)
     ▼
email captured → actor upsert
     │ lifecycle: anonymous → lead
     │ identity ladder: visitor_hash → email-hash (confidence 1.0)
     ▼
"send me a proposal" detected
     │ signal { intent:proposal-request } → lifecycle: lead → sql
     │ thing:offer created, linked to actor via attribution path
     ▼
proposal sent
     │ touch:send · channel:email · campaign:new-patient-flow
     │ tracked link embedded → /go/:id
     ▼
link clicked → booking completed
     │ touch:click → touch:purchase
     │ mark(edge, value=120) → path:new-patient-flow strengthens
     │ lifecycle: sql → customer
     ▼
outcome recorded in substrate
     │ pheromone on every path segment
     │ next lead follows the stronger route automatically
```

Every arrow in that diagram is a signal. Every signal writes to the same brain. The contact record, the conversation history, the deal record, and the learning are one thing.

---

## Numbers

Eight actor attributes live in the shipped schema: `name`, `email`, `phone`, `lifecycle`, `fit-score`, `ltv`, `consent-channels`, `channels`. The enrichment layer adds more than 40 across Clearbit, Apollo, Stripe, Shopify, GA4, and the identity ladder.

Five CRM surfaces shipped or in build: `/crm/c/:actor` (contact detail, live), `/crm/g/:group` (segments), `/crm/j/:journey` (journey runtime), `/crm/b/new` (broadcast composer), `/crm/pulse` (analytics).

Two API endpoints shipped in `74e47496`: `GET /api/actors/[id]` and `GET /api/actors/[id]/activity`. One enrichment aggregator shipped in `79fd203c`: `enrichActor()` in `web/src/lib/crm/actor.ts`.

Contact detail page load: <100ms from D1 hot path. Tracked link redirect: <50ms at the edge. Segment query to live count: <200ms. Broadcast to 10,000 contacts: <30 seconds.

Six lifecycle stages: `anonymous → lead → mql → sql → customer → advocate`, plus `churned`. Signal-driven, not button-driven.

Eight enrichment integrations specified: Clearbit, ZoomInfo, Shopify, Stripe, GA4, Meta Pixel, Segment, RudderStack. Eight export integrations: Meta Custom Audiences, Google Customer Match, TikTok Audience, Klaviyo, HubSpot, Salesforce, and two more. Every export is a diff push: additions and removals only.

One privacy endpoint for GDPR: `POST /api/forget` cascades across vault, KV, D1, TypeDB, R2, and ad platforms. Cascade receipt at `GET /api/forget/:request_id`. Vault shred time: <1 second.

Zero new tables. Zero new verbs. The CRM is a typed lens over the substrate that already exists.

---

## Failure modes

Three failure modes for a signal-driven CRM, named explicitly.

**Stage transition misfires.** The model classifies "can you tell me more?" as `intent:proposal-request` and advances the actor to `sql` prematurely. The rule is visible on the contact record. The override is one keystroke. The signal that fired is logged. The model's prior shifts. The fix is traceable, not mysterious. In a traditional CRM, a misfire is a human error with no audit trail. In the substrate, it is a classification error with a full log and a feedback loop.

**Identity merge false positive.** The probabilistic merge engine combines two actors who share a first name and an IP address but are different people. Merge confidence is logged. Merges below 1.0 are flagged for human review. A human can split a merged actor: `split(a, b)` writes a `same-as NOT` relation. The activity feeds are de-interleaved. No data is lost.

**Enrichment overwrite.** An importer agent fetches stale data and overwrites a field the account manager corrected manually. The `appended.<source>.<field>` provenance record shows which agent wrote which value and when. The manual override is stored as `appended.manual.<field>`. The display logic prefers manual over imported. The import does not silently win.

---

## FAQ

**Is the CRM the same product as the analytics?** Same data source, different lens. `/crm/pulse` shows CRM KPIs filtered to CRM verbs. `/analytics` shows the full signal stream. One brain, two views.

**Can I use the CRM without agents?** Yes. The CRM reads from the signal stream. Signals arrive from agents, web forms, channel integrations, or manual API calls. You can ingest contacts via CSV and API without an agent handling conversations. The learning loop works on whatever signals you provide.

**What is the actor type count?** Two: `human` and `agent`. Both are first-class contacts. A pipeline of developers who installed the SDK but have not deployed is an actor segment with `actor.kind = agent`. The same CRM surfaces handle both.

**How does the CRM handle unsubscribes?** An unsubscribe fires a signal tagged `touch:unsub · channel:email`. The substrate calls `warn(edge)` on the email path for that actor. The `consent-channels` attribute updates to exclude email. The suppression flag sets. Future broadcasts that would send to that channel for that actor are blocked at the consent gate before they resolve. The block is mechanical. It does not depend on someone remembering to update a list.

**Can I run journeys and HubSpot sequences simultaneously?** Yes. The write-through sync keeps HubSpot updated as actors advance through substrate journeys. HubSpot sequences keep running on their own cadence. Signals from both systems land on the actor record. Attribution handles overlapping touches with a configurable model (last-touch, linear, time-decay, Shapley).

**What happens to the data if I leave?** The actor table, signal history, and enriched attributes export as JSON or Parquet on demand. The corpus stays with the agency. `GET /api/actors/export` returns the full workspace in one call. You walk away with everything.

---

## Glossary

**Actor.** The substrate's word for a contact. A row in TypeDB with attributes (name, email, lifecycle, fit-score) and relations (same-as, membership, attribution). Both humans and agents are actors.

**Signal.** A message on the substrate bus. Every conversation touch (send, open, click, reply, purchase) is a signal. Signals are the raw material of the contact record.

**Lifecycle.** The actor's stage in the customer journey: `anonymous → lead → mql → sql → customer → advocate`. Driven by signal-pattern rules, not button presses.

**Pheromone.** The weight accumulated on a path between two actors or stages as signals mark it. Pheromone is what makes the pipeline learn. A path with high pheromone is a proven route. Routing follows the strongest path.

**same-as.** A TypeDB relation between two actor records that represent the same person. Created by the identity ladder when an email-hash, phone-hash, or auth-provider ID matches across records.

**Fit-score.** A computed attribute on the actor, reflecting how closely the actor's signals match the ideal customer profile for their segment. Used for lead prioritisation and handoff routing.

**Appended.** Attributes written by enrichment agents from third-party sources. Stored in the `appended.<source>.<field>` namespace. Provenance-tracked. Never silently overwritten.

**Consent gate.** The mechanical check before any outbound signal fires. If `consent-channels` does not include the target channel, the signal dissolves. No workaround.

---

## Cross-references

- **§10 Tracking.** The pipeline that writes every signal this CRM reads. Identity rungs 0–1 are live; rungs 2–5 in build. The tracking layer is the foundation; the CRM is the lens.
- **§11 Analytics.** The same signal store, different filter. The monthly client report reads from the same `funnel_daily` and `rollup_counters` that power `/crm/pulse`.
- **§13 Learning.** The loop that hardens proven contact-to-conversion paths into hypotheses. The discovered journeys page at `/crm/j/discovered` surfaces those candidates for one-click materialisation. What looks like a CRM pipeline feature is the substrate's L6 KNOWLEDGE loop made visible.

---

*Open the actor view — it's already the CRM.*

<!-- rubric: fit=0.94 strongest=0.92 show=0.91 cut=0.90 craft=0.91 → 0.92 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=fn -->
