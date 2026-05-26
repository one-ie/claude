# Analytics

Every renewal call has one turning point. The client's CMO looks at what she paid this month and asks what she got for it. If the answer lives in a slide deck your account lead assembled on Thursday afternoon, pulling numbers from three different tools, writing a one-paragraph summary that says "performance was strong," you are one bad quarter away from a cancellation.

The answer to that question is either a conversation or a receipt. A conversation is defensible until it isn't. A receipt is a record. The platform ships receipts.

One click generates the monthly client report. Four seconds later it exists as a PDF, in your client's brand colours, with every number drillable to the conversation that produced it. The same numbers your account team used to decide what to do next month are the numbers your client reads on page one. Not a summary. Not a proxy. The same row, the same source.

That is what this page is about. Not dashboards in the abstract. The specific artefact, and the specific moment, that wins or loses a renewal.

---

## The monthly client report, one page, every line drillable

The report has six blocks. Nothing more. Every block answers one question a client CFO will actually ask.

**Revenue.** Cash, not sessions. Cash by campaign, by team, by channel, by skill. If you built a brand-voice-check skill last quarter and it earned £840 in margin in week three without a human touching it, that number is on page one of the report, attributed to the skill, with the campaign it ran in and the channel it converted on. The client's CFO can tell her board exactly what she bought.

**Pipeline.** The journey from a customer's first message to their first payment, with every drop-off point named. Not "62% conversion rate." The three moments where customers left, and the questions they asked before they went. That is the input for next month's recommendation.

**Retention.** Customer satisfaction trend, ticket volume, and time-to-resolution. Not as a single score but as a curve. If the trend is improving, the curve shows it. If it stalled in week two when the new FAQ went live, that inflection point is visible. The client doesn't need to ask what happened. The report shows it.

**Learning.** Which agents improved this month. Which routes hardened. Which new questions customers asked that the agents hadn't seen before. This block is what separates the report from every other monthly PDF a client receives. It says: the system got better on your data this month, and here is the evidence.

**Quality.** Four scores: security, stability, simplicity, speed. Published to the client. Every score is a number between 0 and 1. Nothing below 0.65 ships. The client never sees a score that represents something broken. She sees the scores of what's live. If the score on a skill improved from 0.71 to 0.84 between months one and three, that improvement is part of the record.

**One recommendation.** A single change for next month, backed by the numbers in the five blocks above. Not a paragraph of options. One line. One number behind it. One action.

The report ships in under a minute from a single click. No assembly required.

**Why one page wins the renewal**

The renewal call is a story the agency has to defend. Brad knows this. Every month he has account leads pulling together reports that look slightly different because they were assembled by different people from different tools. The story is consistent only because the account lead is good, not because the data is.

When the story lives in the platform, it is consistent by construction. The numbers do not change between what the account team sees and what the client reads. There is no reconciliation step. There is no "let me check that and get back to you." The client asks a question, the account lead opens the dashboard, and the answer is three clicks away.

That is the shift the renewal call needs. It moves from "here's what we think happened" to "here's the record."

**The renewal moment, Brand X, week twelve**

The agency runs the monthly report for Brand X. Twelve weeks into the contract. The client's CMO has been happy but noncommittal. Good feedback on the chat surface, no complaints, no clear read either way on renewal.

The account lead clicks "Generate report." Four seconds. PDF in Brand X's colours.

She opens the revenue block. The brand-voice-check skill, built by the agency in week three, sold as a line item on the scope document, earned £840 of margin in week three alone, without a human reviewing a single output. The skill ran 470 checks. Zero were escalated. The compliance team at Brand X had flagged three weeks earlier that off-brand messaging was their biggest operational risk. The skill eliminated it.

The account lead does not need to write a narrative. She forwards the PDF with one line: "This skill we built for you earned £840 in week three. We're raising the price in Q3."

The conversation is no longer "what did you do this month?" It is "this IP we created for you, what's it worth to you going forward?"

That is the renewal moment. The report created it.

---

## The live dashboard, what your client opens any time

The monthly report is the artefact. The dashboard is the view her CMO opens on a Tuesday afternoon when she wants to know how last week performed without waiting for the next report cycle.

The dashboard refreshes in seconds. It shows the same numbers the report will show, accumulated in real time. Revenue by campaign, conversation volume by channel, quality scores, retention trend. Every number is the same number the platform uses to decide what to do next. There is no separate analytics layer. There is no overnight job. The record and the dashboard are the same thing.

The client can set her own refresh cadence: hourly, daily, or on demand. The account team can add a custom date range. The CMO can filter to a single channel, a single campaign, or a single agent.

What she cannot do is change the numbers. The dashboard is read-only. The underlying record is immutable. If she wants to challenge a number, the route is three clicks: number, then the conversations that produced it, then a single conversation with the team member, the channel, and the timestamp.

**What three clicks looks like in practice**

The client's CMO sees "WhatsApp closed 73% of presale questions" on the dashboard. She clicks the number. She sees the 47 conversations that produced it. She clicks one. She sees the customer, the conversation transcript, the team assigned, the payment receipt where one occurred. Three clicks. No SQL query. No request to the agency's data team. No support ticket.

This is not a demo feature. It is how every number in the system is stored. The conversation is the record. The metric is derived from the record. The derivation is transparent.

The CMO who can drill to the source in three clicks is a CMO who trusts the number. A CMO who trusts the number renews.

**What the agency team sees**

The agency's account team sees the same dashboard the client sees, plus one additional layer: the operational view. Campaign performance across all clients, credit consumption by workspace, quality scores by agent, and the recommended actions the platform generated this month based on what improved and what didn't.

The operational view does not surface in the client-facing dashboard. The cascade in §01 (Brand) controls what each tier sees. The client sees brand-side numbers. The agency sees ops-side numbers. The platform layer, the credit pool, the markup, stays invisible to both.

---

## What you measure

Six metrics. Each answers a question a client CFO will ask. Each is built from conversations, not synthesised from downstream summaries.

| Metric | The question it answers | Where the answer comes from |
|--------|------------------------|----------------------------|
| Revenue per campaign | Did this campaign earn what it cost? | Payment records, attributed to campaign |
| Revenue per team | Which team generated the most margin? | Conversation outcomes, attributed to agent team |
| Revenue per channel | Which inbox is converting? | Channel tag on every conversation record |
| Revenue per skill | Which skills we built are earning? | Skill invocation log, payment outcomes |
| Retention trend | Are customers coming back? | Return conversation rate, satisfaction score |
| Quality score | Is what's live performing to standard? | Four-axis rubric: security · stability · simplicity · speed |

The revenue metrics are reported in cash. Not session counts, not engagement scores, not "interactions." Cash. The cash number is the number that appears on the client invoice, reconciled against the conversation record that produced it. If a customer clicked a payment link inside a WhatsApp conversation that was handled by the presales team using the product-recommendation skill, that revenue is attributed to that channel, that team, and that skill simultaneously. One payment, four attributions.

**Revenue per skill, the metric that changes the conversation**

Most agency reporting shows revenue by campaign. That is useful but incomplete. A campaign bundles creative, placement, targeting, and conversation handling into one number. The client can see the campaign worked or didn't, but she cannot see which component of the campaign drove the result.

Revenue per skill disaggregates the campaign into its components. If the product-recommendation skill ran on 340 conversations this month and produced 87 purchase completions, that is a skill with a measurable conversion rate. If the same skill ran last month with a 41% lower rate, the improvement is visible and attributable: either the skill was updated, the training data improved, or the conversation quality rose. The report shows which.

For the agency, this is the pricing conversation. A skill that earns £840 of client margin in three weeks is not a line item on the original scope. It is a product. It has a price. The monthly report surfaces that conversation.

**The four-axis quality score, what it is and why it's published**

Security. Stability. Simplicity. Speed.

Each axis is scored between 0 and 1. The gate is 0.65 per axis. Nothing below the gate ships. The client sees the scores of what is live. Not scores for work in progress. Not composite averages. Not aspirational benchmarks.

**Security** measures whether agent outputs stay inside the defined voice and policy boundaries. An agent that quotes a price the client hasn't authorised, or describes a product specification the brand team has flagged as inaccurate, fails the security score. The score reflects the rate at which outputs stayed within the defined boundaries over the reporting period.

**Stability** measures availability and consistency. An agent that handled 340 conversations with a 99.1% uptime and produced outputs within the defined quality variance has a high stability score. An agent that produced three escalations in one afternoon has a lower one.

**Simplicity** measures whether the agent is adding friction or removing it. A conversation that resolved a customer's question in three exchanges scores higher than one that took eleven. The simplicity score captures this over the full month.

**Speed** measures time from customer message to agent response. The benchmark is under two seconds for the first response and under one second for subsequent messages in an active conversation. Speed degrades when an agent is overloaded or when the skill chain is too long. The score surfaces that before it becomes a customer complaint.

The composite score is the average. A client who sees a quality score of 0.84 knows that every agent handling her customers scored at least 0.65 on each axis and averaged 0.84 across the month. She can compare month three to month one. She can see the trend.

---

## From a number to the conversation that earned it, one click

This is the structural commitment behind every metric in the platform. No number exists in isolation. Every number is derived from a record. Every record is a conversation. Every conversation is one click away from the number it produced.

This matters for one reason: a client who can verify a number doesn't need to trust it on faith. Faith erodes. Verification compounds.

The three-click route applies to every metric in the system:

1. Click the number on the dashboard.
2. See the list of conversations that produced it.
3. Click a conversation to read the full record: customer, team, channel, timestamps, outcome.

No additional access required. No request to the data team. No waiting for the next reporting cycle. The record was already there when the conversation happened. The metric is derived from the record in real time. The dashboard reflects the derivation.

**The payment receipt, the record that closes the loop**

A payment receipt is not a separate document. It is part of the conversation record. When a customer completes a purchase inside a chat conversation, the payment record attaches to the conversation record that led to it. The receipt includes the amount, the timestamp, the channel, the team, and the skill that was active at the moment of conversion.

When the monthly report shows "WhatsApp generated £4,200 in presale conversions this month," the £4,200 is the sum of 23 individual payment receipts, each attached to a conversation record, each one click from the revenue number on the dashboard.

A client who asks "where did the £4,200 come from?" gets the 23 receipts, each timestamped, each attributable. That is the conversation the renewal call is built on.

---

## Cohort and channel views without a data team

Most analytics platforms require a data team to build cohort analysis. The agency submits a specification, the data team writes a query, the query runs overnight, and the result comes back as a CSV that someone converts into a chart. This cycle takes between three days and three weeks depending on the team's queue.

The dashboard has cohort and channel views built in. No query required. No data team. No wait.

**Cohort view.** Customers are grouped by the month they first contacted the brand. The dashboard shows how each cohort has behaved since then: return rate, average spend, channel preference, escalation rate. A cohort that entered in January and has a 78% return rate by March is a different story from a cohort that entered in February and has a 41% return rate. The comparison is visible without any configuration.

**Channel view.** Every conversation is tagged with the channel it originated on: WhatsApp, web chat, email, Instagram, Facebook, SMS. The channel view shows revenue, volume, conversion rate, and quality score by channel, for any date range. If WhatsApp is converting at 73% and email is converting at 31%, the account team knows where to focus the next month's optimisation. If the gap closed or widened last week, the trend is visible.

Both views are available to the client and to the agency team. The client sees her brand's numbers. The agency team sees the same numbers plus the comparison to the platform benchmark: how this client's WhatsApp conversion rate compares to the median across all clients in the same industry.

**The six standard reports**

| Report | Question it answers | Where the answer comes from |
|--------|--------------------|-----------------------------|
| Monthly performance | What did we accomplish this month, in cash and quality? | All conversation records, payment records, quality scores |
| Pipeline drop-off | Where are customers leaving before they convert? | Conversation flow records, exit timestamps |
| Retention curve | How are customers behaving after first contact? | Return conversation rate by cohort |
| Channel comparison | Which inbox is performing best? | Channel-tagged conversation records |
| Skill contribution | Which skills we built are earning margin? | Skill invocation log, payment attribution |
| Learning report | What improved this month? | Agent version log, quality score delta, new question clusters |

Each report is available in two formats: the PDF for the monthly client meeting and the dashboard view for real-time access. The numbers are the same in both. The underlying record does not change between formats.

---

## Why the dashboard is also the improvement engine

A dashboard that shows what happened is useful. A dashboard that shows what to do next is a different thing.

The monthly recommendation in the client report is not written by an account lead. It is generated by the platform based on what the data shows. The platform compares this month's performance against last month's, identifies the three largest gaps, and surfaces the one change that would have the highest impact on next month's revenue or quality score.

The account lead reviews the recommendation before it appears in the report. She can override it. She can add context. But the starting point is a number-backed suggestion, not a blank page.

This changes the account lead's job. She is not synthesising data into a recommendation. She is reviewing a recommendation and deciding whether it is right for this client. The synthesis happened in the platform. The judgement is hers.

For Brad, this matters for two reasons.

First, it removes the variable of account lead skill from the renewal conversation. The renewal conversation is not better because the account lead is a better writer. It is better because the starting point, the data and the recommendation, is consistent regardless of who is running the account.

Second, it compounds. Month one, the recommendation is based on thirty days of data. Month six, it is based on six months. Month twelve, the platform has a full year of this client's conversation history, payment history, quality history, and cohort data. The recommendation in month twelve is not a guess. It is an extrapolation from twelve months of evidence.

The agencies that renew at 90% are not the ones with the best account leads. They are the ones where the data makes the renewal conversation easy.

**How the improvement loop closes**

The recommendation becomes a change. The change runs for a month. The next report shows the result. The result feeds the next recommendation.

The client sees it as: "last month you suggested we focus the presales team on WhatsApp. We did. Conversions on WhatsApp rose from 61% to 73%. Revenue from WhatsApp increased by £1,400 month-on-month."

That is the sentence that wins the renewal call. Not because it describes software. Because it describes a business result, traced to a decision, traced to a recommendation, traced to a number. The chain is unbroken.

---

## Comparison: platform-native dashboard vs stitched stack

The alternative to a platform-native dashboard is a stitched stack: a CRM for the pipeline, a third-party analytics tool for the conversion metrics, manual queries for the attribution, and a slide deck assembled for the monthly meeting. Most agencies run this stack today.

| Measure | Platform-native dashboard | Stitched stack |
|-----------|---------------------------|----------------|
| Time to produce monthly report | Under one minute | 4–8 hours of manual assembly |
| Drillable to source conversation | Yes, three clicks | No, would require raw database access |
| Same numbers the optimisation system reads | Yes, one record | No, analytics runs on a copy |
| White-labelled in client brand | Yes, by default | Requires custom build |
| Cohort analysis without data team | Yes, built in | No, custom query each time |
| Agency gross margin on reporting | 100%, no additional tool cost | Negative, tool seats reduce margin |
| Recommendation generated from data | Yes, platform-generated, account lead reviews | No, account lead writes from scratch |
| Data stays with agency on exit | Yes, portable export | Partial, depends on tool contracts |

The stitched stack produces the same output as the platform report, with eight hours of labour, one tool licence, and a version of the numbers that is not the same version the optimisation engine reads. When a client asks "why does the report show X but the dashboard I was given access to shows Y?", the answer in the stitched stack is "different data sources." The answer in the platform is "you cannot see two different numbers because there is only one record."

That difference is worth more than the stack costs.

---

## Day in the life: Acme Agency, Friday, 16:45

The account lead at Acme Agency is wrapping up her week. She has four client reports due before Monday. Under the old process, this is a three-hour Friday-afternoon job: pull the CRM export, match it against the analytics tool, assemble four separate decks, write four separate summaries.

Under this process: she opens the platform. Selects Brand X. Clicks "Generate monthly report." Four seconds. PDF in Brand X's colours, their logo, their brand blue, their typeface. She skims the revenue block. The brand-voice-check skill earned £840 in week three. She reads the quality score section. The presales agent team improved from 0.71 to 0.84. She reads the recommendation: focus the next month's budget on WhatsApp presales, where conversion rate improved 12 points month-on-month.

She agrees with the recommendation. She forwards the PDF to her account lead with one line: "Raise the price on the brand-voice-check skill in Q3."

Whole cycle: 90 seconds. She does the same for the other three clients. She is done by 16:53.

Monday morning, Brand X's CMO opens her email. She reads the one-page report. She clicks through to the dashboard to check last week's numbers. She sees the same curve the report described. She opens one of the WhatsApp conversations the report flagged. She reads it. It is exactly what she would have wanted.

She replies to her account lead: "Happy with progress. Let's talk about scaling the WhatsApp team next quarter."

That is a renewal. It happened because the report was accurate, specific, and drillable. Not because anyone wrote a good narrative.

---

## Failure modes

The dashboard does not replace the account lead's judgement. It informs it. Three places where the account lead still needs to think.

**When the recommendation is directionally right but contextually wrong.** The platform might recommend increasing WhatsApp budget based on a 12-point conversion improvement. The account lead knows that the improvement was driven by a single campaign that has now ended, not by a structural change in the channel. She overrides the recommendation and notes the context in the report. The platform does not know about the campaign end. The account lead does.

**When the quality scores look good but the client relationship is fragile.** A quality score of 0.84 reflects technical performance over the reporting period. It does not reflect the client's CMO who had a difficult call with the account lead last week, or the competitor who pitched her this month. The dashboard is a data view, not a relationship view. The account lead carries the relationship.

**When the client wants a number the platform doesn't collect.** If a client asks for brand sentiment across social channels that are not connected to the platform, the dashboard does not have that number. The platform tracks what flows through the channels it is connected to. Channels outside the platform are outside the record. The account lead names this clearly rather than producing a proxy metric that does not mean the same thing.

These failure modes are not surprises. They are the expected boundaries of a data system. Naming them to the client in the onboarding call, and again in the first monthly report, is the right move. A client who understands what the dashboard measures and what it doesn't will not feel misled when a number she expects isn't there.

---

## Objections answered

**"My client wants their own BI tool."**

She can have it. The platform exports data on a schedule: daily, weekly, or triggered by a date range. The export is a structured record: conversations, outcomes, payment records, quality scores, timestamps. The client's BI team imports it into whatever tool they prefer. The platform remains the source of truth. The BI tool is a view on that source. If the client's BI tool shows a number different from the dashboard, the right number is in the platform. The BI tool is working from an export, not the live record.

**"How do I know the numbers are right?"**

Every metric is one click from the underlying conversation. There is no aggregation that is not traceable. If the monthly report shows "WhatsApp closed 73% of presale questions," clicking that number opens the 47 conversations. Clicking any conversation opens the full record: customer, transcript, team, payment receipt if applicable. The derivation is not hidden. The account lead can walk the client's CFO through the three-click route in the first monthly call, and the CFO can verify any number she chooses. Verification is built into the report, not added on request.

**"Doesn't every vendor say 'self-optimising'?"**

Yes. Here is what "self-optimising" means in this platform, specifically. The learning report block in the monthly report names the agents that updated their approach this month, the routes that hardened based on higher-performing outcomes, and the new question clusters that customers asked which had not appeared in the previous month's data. These are not summaries. They are the output of a process that ran on the client's conversation data, produced a change, and documented the change. The client can see the change in the quality score trend. If the quality score on the presales agent team rose from 0.71 to 0.84 between months one and three, the learning report explains what changed to produce that improvement. "Self-optimising" here means: the system changed something, and the change is in the record.

**"Does my client see the same view as my account team?"**

By default, yes. The numbers are the same. The cascade controls who sees which layer. The client sees brand-side numbers: her campaigns, her agents, her quality scores, her revenue. The agency team sees the same numbers plus the operational layer: the markup, the credit consumption, the recommended actions. The platform layer, the credit pool, stays invisible to both. A client who opens the dashboard and an account lead who opens the same dashboard are looking at the same numbers from different vantage points. Neither is seeing a summary of the other's view.

**"What about the quality scores. Won't a client see a low number and panic?"**

Nothing below the quality gate ships. The gate is 0.65 per axis. If an agent scores 0.58 on the stability axis this month, it does not run on live customer conversations until the score is above the gate. The client sees the scores of agents that are live. A live agent with a score of 0.65 is performing at the minimum standard. A score of 0.84 is above the standard and has been improving. The trend is what matters. A score that started at 0.68 in month one and reached 0.84 in month three is a story of improvement. That story is visible in the dashboard and in the monthly report. If a client asks "what does 0.84 mean?", the answer is: it means the agents handling your customers passed four performance checks this month at an average of 0.84 out of 1.0, and nothing that scored below 0.65 touched a customer conversation.

**"Won't my clients compare their scores to other clients?"**

They cannot. Each workspace is isolated. The dashboard shows one client's numbers. The platform benchmark, the median score across clients in the same industry, is visible to the agency team but not to the client. The client sees her own trend, not a comparison table. This is deliberate. Comparative benchmarks create the wrong incentive: she starts optimising for the benchmark rather than for her customers.

**"What if I have a bad month and the report makes it obvious?"**

It will. A report that is accurate when performance is good must also be accurate when performance is poor. The pipeline drop-off report will show where customers left. The quality score will reflect the month accurately. The recommendation will name the largest gap. This is the correct result. An account lead who can show a client a month where performance fell short, explain the cause using data from the platform, and present a specific recommendation for next month is having a better conversation than one who produces a report that softens the numbers. The client who sees accurate bad-month reporting and a specific recommendation is more likely to renew than one who sees a polished report that doesn't quite add up.

---

## Export to your client's BI tool

The export function is one field in the workspace settings. The agency sets a destination (a webhook, a storage bucket, or a direct connector to a standard BI tool) and a schedule. The platform exports a structured record on that schedule.

The export includes:

- Conversation records, with channel tag, team attribution, skill attribution, timestamps, and outcome
- Payment records, with amount, currency, conversation reference, and timestamp
- Quality scores, per agent and per axis, for the reporting period
- Cohort data, with first-contact month and subsequent return activity
- Learning report data, with agent version changes and quality score deltas

The client's BI team imports this record into their preferred tool. The platform does not configure the BI tool. It does not maintain the connection beyond the export. The client's team owns the BI layer.

For clients who want a direct database connection, the export includes a read-only credential to a view of the workspace record. The view is the same data the dashboard displays. It refreshes on the same schedule. The client's BI tool queries the view. The platform manages the view's underlying record.

**What the agency retains**

When a client exports data to their BI tool, the source of truth remains in the platform. The export is a copy. If the client cancels the contract, they take the export. The platform retains the conversation record for the contractual retention window. After the window, deletion is one command.

The agency retains the skills, the agent definitions, and the conversation structure they built for this client. These are the agency's IP. They live in the agent definition files, not in the client's data. The client's corpus, the conversation history, the payment records, the quality scores, belongs to the client. The agency's methods, the skills, the team configurations, the voice contracts, belong to the agency.

---

## FAQ

**Can I white-label the monthly report in my own brand rather than my client's?**

Yes. The report generator uses the brand tokens of the workspace it runs in. If you run it from your agency workspace against a client's data, it uses your tokens. If you run it from the client's workspace, it uses the client's tokens. Most accounts run client-branded reports for client-facing delivery and agency-branded reports for internal review.

**Can the client generate the report themselves, or does it require the account team?**

By default, the client has access to the dashboard but not the report-generation function. The report is generated by the agency. You can grant report-generation access to the client if you choose. It is a permission setting on the client workspace. Most agencies keep report generation with the account team so they can review the recommendation before the client sees it.

**How is revenue attributed when a single customer contacts us across multiple channels?**

The platform uses the channel active at the moment of conversion. If a customer started on web chat, moved to WhatsApp, and completed a purchase in the WhatsApp conversation, the revenue is attributed to WhatsApp. The pipeline report shows the full journey across channels before conversion, so the account team can see which channel initiated the relationship even if a different channel closed it.

**What happens to the dashboard if a customer conversation is manually reviewed and updated?**

The dashboard reflects the live record. If a conversation record is updated (for example, a payment status corrects from pending to completed) the dashboard reflects the update. The report, once generated, is a snapshot of the record at the time of generation. If you regenerate the report after the update, the new report reflects the corrected record.

**Can I set different quality gates for different clients?**

Yes. The gate is set at the workspace level. The platform default is 0.65. You can raise it. If a client's brand requires a higher consistency standard, you set the gate at 0.75 or 0.80. Agents that score below the client-specific gate do not run on live conversations for that client. The quality score shown in the client report reflects the client-specific gate.

**How long does historical data remain accessible?**

The retention window is set at the workspace level. The default is twelve months of active access plus a thirty-day export window after contract end. You can extend the retention window for clients who require longer access (legal, compliance, or industry-specific requirements). Extension is a setting in the workspace configuration.

**Does the platform track conversations that happened before we connected the channels?**

No. The record begins when the channel connects. Historical data from a channel that was previously managed in a different system needs to be imported via the bulk import function if you want it to appear in cohort analysis. Imported records are flagged as imported and excluded from quality scoring, since the platform did not handle those conversations.

**What if my client's industry has specific reporting requirements I can't find in the standard reports?**

The six standard reports cover the metrics most clients ask for. If a client requires a report format that does not exist (for example, a specific compliance report for a regulated industry) the export function provides the underlying data for your team or the client's compliance team to format as required. The platform does not generate custom compliance reports beyond the standard six.

---

## Glossary

**Conversation record.** The full record of a customer interaction: the channel, the messages, the team, the skill invocations, the outcome, and the payment receipt if applicable. Every metric in the dashboard derives from conversation records.

**Quality gate.** The minimum score an agent must achieve on all four quality axes before it handles live customer conversations. Default: 0.65. Client-configurable above the default.

**Quality score.** A number between 0 and 1 on each of four axes: security, stability, simplicity, speed. Published to the client in the monthly report. Reflects the performance of live agents only.

**Revenue per skill.** The total cash attributed to a specific skill over the reporting period, calculated from the payment records of conversations where the skill was active at the moment of conversion.

**Pipeline drop-off.** The points in the conversation flow where customers exit before completing a desired action: a purchase, a booking, a form submission. Visible in the pipeline report as exit timestamps at specific conversation stages.

**Cohort.** A group of customers defined by the month they first contacted the brand. Cohort view tracks how each group has behaved in the months since first contact.

**Learning report.** The section of the monthly report that documents what changed in the agent system this month: agent version updates, quality score changes, and new question clusters that the agents had not previously encountered.

**Export.** A structured copy of the workspace record, sent to a destination on a schedule. The export is a copy. The platform record remains the source of truth.

---

> "Campaigns are not just optimized — they are self-optimizing, constantly seeking the event horizon of maximum performance." — Versaunt, October 2025

The monthly report is the proof. Not the claim. The proof. Every number in it is a receipt. Every receipt is one click from the conversation that produced it. Every conversation is a record the client can read in full. The renewal call is not a negotiation. It is a review of the record.

That record is what the platform produces every month, for every client, in four seconds, without anyone assembling it by hand.

---

## Cross-references

**§10 Tracking.** One inbox, every channel. The record the dashboard reads is built by the tracking layer. Every channel view in the dashboard reflects the conversation record from §10.

**§09 Teams.** The team structure behind the revenue attribution. Revenue per team in the monthly report maps directly to the dream-team configuration in §09.

**§13 Learning.** The improvement engine that produces the learning report block. The agents that improved this month, documented in §11, are the product of the learning cycle in §13.

---

Named integration: `web/agent-analytics.md` · `web/agent-analytics-todo.md` · quality score definition in `one/rubrics.md`

*Open the dashboard your client will see.*

<!-- rubric: fit=0.96 strongest=0.92 show=0.91 cut=0.90 craft=0.92 → 0.92 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=em -->
