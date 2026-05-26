# campaigns.md — brief → swarm → ship

You write one sentence. A team of agents builds the whole campaign for you — audience, creative, ad pushes, emails, SMS, organic social, blog posts, send schedule. You look it over and tap `[Approve & ship]`. The campaign runs across every channel itself, learns from what works, and keeps improving while you sleep.

Paid and organic, in one console. Lives on `/in?preset=campaigns` — the same screen as the rest of your inbox. Same composer, same charts, same keyboard shortcuts. **Zero new endpoints. Zero new entities.**

Everything in this doc is composed from what we already ship:
[`crm.md`](crm.md) (composer · templates · tags · status · roles),
[`tracking.md`](tracking.md) (events · pheromone · gates · vault),
[`agent-analytics.md`](agent-analytics.md) (`funnel_daily` · lift · attribution · `useWatch`),
[`one/marketing-ontology.md`](../plans/marketing-ontology.md) (the marketing-agent department · persona + offer schema · learning loops).
*Power through simplicity:* describe a campaign once, then compose what already works.

---

## 1. The shape

A campaign is a row with these fields. Most are optional — at minimum you need a persona, a north-star metric, and one touchpoint.

```
campaign           q4-founder-launch
persona            founder-eu/funded         who this is for (see §8)
north-star         mql-rate                  the one number it moves
budget             USD 50,000                what you'll spend
spend              auto-accrued              what's been spent (see §5)
holdout-fraction   0.10                      required when budget > $5k
start-at / end-at  2026-10-01 / 2026-12-31
audience           a question, not a list    answered at send time (see §4)
offers             one or more offers        created on /in?preset=offers
touchpoints        ordered sends             see §4
status             draft|scheduled|running|paused|shipped|killed   (a tag)
```

It lives at one URL with three views:

```
/in?preset=campaigns                          everything you've run
/in?preset=campaign:<id>                       one campaign, all sides
/in?preset=campaign:<id>&view=people|replies|sends|discovered
```

You can start one from anywhere. All four paths hit the same endpoint:

| From | Looks like |
|---|---|
| **Chat** | one sentence to claw → the swarm assembles the card → you tap approve |
| **Form** | open `/u/[slug]/campaigns`, add a row, fill the fields |
| **Composer** | mode `direct:me` + tag `kind:new-campaign` |
| **API / SDK / MCP / CLI** | `client.signal('group:campaign:<id>:create', { … })` |

All four call `POST /api/signal/[...receiver]`. There's no new endpoint in this doc. Two existing routes gain a query param (`?campaign=<id>` on `/api/agents/<id>/analytics` and `/api/export/conversations`) — that's it.

---

## 2. The default path — let the swarm do it

You tell the system what you want in one sentence. The `cmo` agent breaks the work into pieces and hands them out to the marketing department ([`marketing-ontology.md` §The 23-agent department](../plans/marketing-ontology.md)). The substrate's existing queue runs the whole thing — no workflow engine, no new infrastructure.

```
your brief  →  cmo
                ├──▶ strategist + researcher    refines the persona
                ├──▶ copywriter                 writes copy, posts, emails, SMS — 3 variants
                ├──▶ designer + voice           generates images, video, audio
                ├──▶ paid-meta + paid-google     audience + creative + bid push to ad managers
                │     + paid-linkedin + paid-tiktok
                ├──▶ email + sms                 sends via Klaviyo/Resend/Postmark + Twilio
                ├──▶ social-organic              schedules Twitter/LinkedIn/IG/TikTok organic
                ├──▶ content + seo               publishes blog posts, lands keywords
                ├──▶ compliance                  checks consent, region, caps, brand-safety
                └──▶ analyst                     projects reach, cost, ROAS, organic reach
                                │
                                ▼
            you get back a card (in chat, or on the detail pane):
            ┌────────────────────────────────────────┐
            │ ◉ Q4 Founder Launch                    │
            │   1,240 people · 12 touchpoints        │
            │   5 images + 2 videos · 4 blog posts   │
            │   ads + emails + SMS + social ready    │
            │   ~28k reach · CPA $87 · org reach 12k │
            │   [Edit ▾]    [✓ Approve & ship]       │
            └────────────────────────────────────────┘
```

**Two buttons, that's it.** `[Edit ▾]` opens the card so you can change anything inline — each change goes back to the agent that wrote it and the card refreshes when they're done. `[Approve & ship]` flips it to running and pushes to your ad accounts within two minutes.

The system notices which fields you keep approving unchanged and stops showing them. After a handful of campaigns, you'll be tapping `[Approve & ship]` without opening the card.

**How fast?** A few hundred milliseconds to start the swarm, three to six minutes for it to finish (video generation is the slowest step), and another minute or two to push to the ad platforms. **End to end: 5–10 minutes** — versus 45–90 minutes opening HubSpot tabs.

**You can always take over.** Don't like an agent's voice? Edit its markdown file (§8). Want to skip the swarm entirely? Fill the form yourself. Want to send one-off under a campaign? Use the composer with the `campaign:<id>` tag. The swarm is the default, never a requirement.

---

## 3. Every channel — agents make the work, agents ship the work

A campaign isn't just paid ads. It's whatever channels your audience lives on. Six channel agents own six surfaces; each calls the provider you've connected.

| Agent | Owns | Providers we ship adapters for |
|---|---|---|
| `designer` + `voice` | images, video, voiceovers | Imagen · Flux · DALL·E · Midjourney · SDXL · Veo · Runway · Sora · Kling · Pika · ElevenLabs · OpenAI TTS · Cartesia |
| `copywriter` | all written content | Sonnet · Opus · GPT · Gemini via OpenRouter |
| `paid-meta` · `paid-google` · `paid-linkedin` · `paid-tiktok` | paid ads — audience · creative · ad-set · bid | Meta Marketing API · Google Ads API · LinkedIn Ads API · TikTok Marketing API |
| `email` | newsletter, drip, broadcast | Klaviyo · Resend · Postmark |
| `sms` | SMS broadcast + 2-way | Twilio |
| `social-organic` | organic posting + engagement | Twitter/X v2 · LinkedIn UGC · Instagram Graph · TikTok organic |
| `content` + `seo` | blog posts, landing pages, keyword targets | Webflow · WordPress · Ghost |

Each agent saves its work as `thing:creative-asset` (for media), `thing:content` (for written), or `thing:audience` (for ad-side) with provenance — what provider, what prompt, what seed, what cost. The cost accrues to the campaign's `spend` field (see §5.3) regardless of whether the work was a Meta ad or a Twitter thread or a blog post.

Pick provider defaults per modality (`creative:provider:<id>` tag on the campaign), or let the substrate's pheromone learn which combinations convert best for each persona and bias future choices that way. **No manual editor for anything:** you edit the prompt or the brief; the agent regenerates. The asset is the result, not the source.

You connect your accounts once at `/settings/integrations`. OAuth flows for Meta · Google · LinkedIn · TikTok · Twitter/X · LinkedIn organic · TikTok organic ship as part of this plan; API-key flows for Klaviyo · Resend · Postmark · Twilio · Webflow · WordPress · Ghost · ElevenLabs · the model providers — same surface, different auth shape. Once connected, every workspace agent inherits the credentials. **No copy-paste to ad manager, no manual upload to your blog, no swivel-chair between Klaviyo and your social scheduler.** The campaign card ships across every channel from one tap.

---

## 4. Touchpoints — a sequence of sends

A touchpoint is one send. Touchpoints chain in order. Each one is a row in `/settings/templates` (already shipping — see [`crm.md` §6](crm.md)) plus the tag `campaign:<id>:seq:<n>`.

```
1   enrol          ad-creative:hook-v3       meta-ads   holdout:auto
2   +24h           email:welcome             email      inherits
3   +3d            email:case-study          email      inherits
4   +5d            email:offer               email      inherits
5   on:reply       handoff: sub:team:sales   internal   skip
6   on:purchase    email:onboarding          email      skip
```

The journey runtime walks the chain. Conditions like `on:reply` and `on:purchase` are tag checks evaluated when the next send fires — the same checks the status engine uses elsewhere.

**A/B testing is free.** Mark variants with `variant:a | variant:b` on the template invocation. Per-visitor assignment is sticky (see [`agent-analytics.md`](agent-analytics.md)). No setup.

**The audience is a question, not a list.** It's resolved every time you send:

```
match $a isa actor;
  $a has tag "persona:founder-eu/funded";
  $a has tag "consent:email";
  $a has tag "lifecycle:lead" or has tag "lifecycle:mql";
  $a not has tag "suppression-reason:unsub";
  $a not has tag "campaign:q4-founder-launch:exposed";
```

The picker shows this as five rows of pill-builders. A live count above the picker tells you exactly how many people will receive this send after consent, region, frequency, and suppression checks.

**Edits during a live campaign are safe.** While the campaign is `draft` or `scheduled`, template changes apply right away. Once `running`, each person's enrolment locks the template version (`tpl-version:<v>`); new enrolments get the new version, in-flight enrolments keep theirs. You'll see a banner — `[Migrate all] / [Leave]` — when there's a split.

---

## 5. Tracking, KPIs, and self-optimisation — all on rails we already laid

### 5.1 Every send carries the campaign tag

When a send goes out, the substrate writes it with a standard tag order (per [`tracking.md` §9.1](tracking.md)):

```
touch:<verb> · channel:<x> · campaign:<id> · variant:<a|b>? ·
  persona:<id> · offer:<id>? · holdout:<control|treatment>
```

Every event the campaign generates inherits that order. The substrate strengthens the path between consecutive tags — so after a few hundred events, it knows which channel + variant + persona + offer combinations are working. Nobody has to write that query. You can read the top paths any time: `GET /highways?prefix=campaign:<id>:`.

### 5.2 KPIs reuse the agent-analytics page

`GET /api/agents/<id>/analytics?campaign=<id>` — every chart we already ship for agent analytics accepts a `{ campaign }` filter prop. The detail pane shows:

- 8 KPI tiles inline (exposed · CTR · CVR · spend · ROAS · lift · cap-hit rate · identity resolution)
- `FunnelChart` · `VariantCard` (z-test, needs 100 conversions per arm before showing lift) · `PathsCard` (top tag paths) · `LiveEventStream` (live tail) · `EventTimelineChart` · `AudienceCard` · `AcquisitionCard` · `RetentionGrid` · `StageTimingCard` · `ToolCallsCard`

No new charts. The only change is one filter prop on each existing one.

### 5.3 Spend is counted automatically; underperformers get rewritten

You never type a spend number. Three sources, one rule (sum cost from any event tagged `campaign:<id>`):

- ad-platform webhooks → `payload.spend`
- email/SMS adapter receipts → `payload.cost_msat`
- LLM-generated creative (`tool.completed` from designer/copywriter) → `payload.cost_msat`

When spend hits 95% of budget, the campaign auto-pauses. You'll get a notification at 80% so it's not a surprise. To resume, the campaign needs `spend < budget` again.

**Self-improvement is in the roadmap, not v1.** The L5 loop ([`marketing-ontology.md` §The 7 loops](../plans/marketing-ontology.md)) describes creative-fatigue detection → agent regeneration → ad-platform re-push every ten minutes. The schema exists (agent generations table, state machine) but the detect-trigger-push runtime ships in a follow-up plan (`l5-todo.md`). v1 of campaigns ships **manual creative rotation** — the variant card flags fatigue, you tap regenerate, the agent does the rewrite, you re-push. Same destination, one more click. L5 turns those clicks into a cron job.

---

## 6. Running it — lifecycle and the guardrails

```
draft  →  (review)*  →  scheduled  →  running  →  paused / shipped / killed
                                                       *only if you require approval
```

Each state change is a tag swap (`signal: group:campaign:<id>:status.set { to: <new> }`). Status itself is a tag, so you can filter and sort by it like anything else.

| Concern | How it works |
|---|---|
| **Validation** | runs when you try to schedule. Blocks with a plain reason — "no persona," "audience is empty," "needs holdout (budget > $5k)," etc. |
| **Approval** | off by default. Flip `require-approval=true` and you get a `review` step that only owners or agency users can advance. |
| **Roles** | per [`web/roles.md`](roles.md): owner and agency can do anything · client can edit their own workspace (frozen once running) · end_user sees their own activity only. |
| **Notifications** | the `NotificationBell` lights up on status changes, validation failures, 80% and 95% spend, frequency cap hits over 5%, creative fatigue, approval requests, and high-LTV replies. |
| **Frequency caps** | `cap-impressions` and `cap-window-ms` on the campaign group. Over-cap sends are dropped quietly; the cap-hit rate shows on the detail pane. |
| **Holdout & lift** | required when budget > $5k. Lift is computed by `lib/funnel/stats.ts variantLift()` and only shown once there are 100 conversions per arm. We report incremental ROAS, never gross. |
| **Compliance** | three gates from [`tracking.md` §8.1](tracking.md): consent, region, suppression. Plus Art-9 rejection. These don't bend. |
| **Identity, attribution, forget** | nothing campaign-specific — the workspace's identity ladder, attribution windows, and PII vault apply. |
| **Replies** | inbound messages keep the `campaign:<id>` tag. `&view=replies` filters them in. Owner replies from a campaign-scoped thread are tagged automatically and count toward `on:reply` branches and the reply KPIs. |
| **Test before broadcast** | the composer's `Send ▾` button splits three ways: send to yourself (`⌥⏎`), send to a sample of 5 (no rollup impact), or dry-run (render and project cost, no actual send, no event). |

---

## 7. Discovered campaigns — the substrate finds funnels you didn't design

Every hour, the L6 loop scans the pheromone graph for patterns: sequences of tags that keep showing up and end in a conversion. Anything strong enough surfaces here:

```
0.84  touch:click → channel:linkedin → persona:founder-eu     12 mql
0.71  touch:open  → channel:email   → campaign:trial-rescue   9 mql
0.58  view:/pricing → submit:form    → persona:founder/de     7 mql

[⊕ Materialise]
```

Tap `Materialise` and we pre-fill `/u/[slug]/campaigns` with everything we already know: the goal verb becomes your north-star, the persona tag becomes your persona, the channel tags become your channel mix, the predicates become your audience query, and the closest matching template becomes your first touchpoint. You add an offer and a budget, then schedule. **The substrate found the funnel. You accept it.**

---

## 8. How clients change anything — by editing markdown

If a client of yours doesn't like how an agent writes, they edit a markdown file. About two seconds later, the swarm is using their version. Same for skills, tools, theme, knowledge, and credentials. The SDK call is `client.syncAgent(md)` — it's been there for a while.

```
client edits <workspace>/agents/<name>.md
    │
    ▼
client.syncAgent(md)  →  POST /api/ask/agents:sync   (existing endpoint)
    │
    ▼
parse (web/src/engine/agent-md.ts) → AgentSpec
    │
    ├──▶ R2          (the markdown)
    ├──▶ TypeDB      (unit, skills, capabilities)
    └──▶ KV          (per-user skill cache)
    │
    ▼
claw notices `agent:<name>:updated`, rebuilds the agent
(claw/src/agents/builder.ts → makeAgent())
    │
    ▼
the next call uses the new version
```

### 8.1 What changes where

| You want to… | Edit | How long until it's live |
|---|---|---|
| Change how an agent writes, thinks, or behaves | `<workspace>/agents/<name>.md` | ~2 seconds |
| Add a skill (free or priced) | the `skills:` block in the agent file | ~2 seconds |
| Give an agent a new tool | the `tools:` block, or connect via Composio for accounts like Gmail or Slack | ~2 seconds (instant for OAuth flows that are already set up) |
| Restyle the chat or studio surface | the `theme:` / `ui:` / `sections:` / `journey:` blocks ([`web/agent-authoring.md`](agent-authoring.md)) | next page load |
| Connect your ad / email / SMS / LLM accounts | `/settings/integrations` | immediate |
| Add your own knowledge (case studies, voice guide, catalogue) | upload markdown or PDFs — they become `thing:knowledge` rows | a few minutes to embed and index |
| Define or edit personas and offers | rows on `/in?preset=personas` and `/in?preset=offers` | ~2 seconds |
| Change the attribution model | the `analytics:` block in the agent file | next campaign |
| Add a tag namespace, template, or lens pack | `/settings/{tags,templates,packs}` (see [`crm.md`](crm.md)) | immediate |
| Switch which provider makes the images or video | `creative:provider:<id>` tag on the campaign | next render |
| Rewrite how the swarm thinks about briefs | the `system-prompt:` block of `<workspace>/agents/cmo.md` | ~2 seconds |

**Cascade order.** When claw needs an agent, it looks in this order:

```
1. workspace/<slug>/agents/<name>.md       (your override)
2. agency/<group>/agents/<name>.md         (your agency's shared version)
3. platform/agents/<name>.md               (our defaults)
4. agents/templates/<role>.md              (last-resort scaffold)
```

That's the four-tier roles model from [`web/roles.md`](roles.md) doing the white-labelling. There's no `if (workspace)` branching in code — the cascade *is* the customisation.

### 8.2 What stays locked

Three things never bend. Keeping them frozen is what lets everything else stay open.

| Locked | Why |
|---|---|
| The 7 verbs (`signal · ask · mark · warn · fade · follow · select`) | the substrate's nervous system ([`one/dictionary.md`](../plans/dictionary.md)) |
| The 6 dimensions (`groups · actors · things · paths · events · learning`) | the TypeDB schema ([`one/one-ontology.md`](../plans/one-ontology.md)) |
| The 3 ingest gates (consent · region · suppression) | privacy and compliance, no exceptions |

Clients can extend receivers (`<workspace>:custom:<x>`), tags (`<workspace>:<ns>:<value>`), and any markdown surface. The verbs and dimensions stay; everything else composes on top.

---

## 9. What we don't build

- No `/campaigns/*` route tree — campaigns live on `/in`
- No campaign builder, no sequence editor canvas, no audience entity, no experiment UI
- No campaign analytics page — same charts as agent analytics, filtered by `?campaign=<id>`
- No manual creative editor — edit prompts, agents regenerate
- No campaign orchestration engine — the substrate's queue is enough
- No per-campaign credentials — connect once at `/settings/integrations`
- No "copy to ad manager" button — agents push directly
- No new endpoints — every verb is `signal`, `ask`, `mark|warn`, `settings`, or existing exports

---

## 10. Build order — 5 quick wins, 6 cycles, 1 new file

The substrate primitives are all in place: composer, templates, tags, tracking, `funnel_daily`, the funnel charts, `EditableField`, `EntityDetail`, `Inbox`, `BulkBar`, `NotificationBell`, `useWatch`, `LiveEventStream`, `Navigation`, the claw agent runtime, the SDK's `syncAgent`. The plan ships **5 UI surfaces and 6 wired cycles**, mostly by extending what we have.

### Phase 1 — Value prop first (build what demonstrates the product)

| What | Ships | Reuses |
|---|---|---|
| **CSwarm-core** | `cmo` · `strategist` · `copywriter` · `analyst` agents + `CampaignCardRenderer` + `[Approve & ship]` | `builder.ts` makeAgent · `BoqCardRenderer` pattern |
| **CQW1** | `groups:campaigns` preset in `/in` rail + `groups:personas` + `things:offers` presets | `RAIL_ORDER` — three new entries, no new files |
| **CIntegrations** | OAuth + credential lifecycle for all channel providers | `composio.ts` pattern · existing `integrations` scope |

### Phase 2 — Shell (needs the campaign preset to exist)

| CQW | Ships | Reuses |
|---|---|---|
| CQW3 | Detail pane | `EntityDetail` + the 10 funnel charts with a `{ campaign }` filter prop |
| CQW4 | Composer pre-fills from `?preset=campaign:<id>` | `Composer.tsx` URL reader |
| CQW5 | Discovered candidates row | `GET /api/frontiers?kind=campaign-candidate`; `[⊕ Materialise]` navigates to `/in?preset=campaigns&new=true` |
| CQW6 | `[+ New campaign]` HeroCTA + empty state | `HeroCTA.tsx` · `EntityCard.tsx` |
| CQW7 | Swarm progress + connection warnings | `useWatch` · `ActionChips.tsx` |

### Phase 3 — Depth (needs the detail pane)

| Cycle | What ships |
|---|---|
| **CCV** | Validation engine — blocks at schedule time with plain-language reasons |
| **CCSeq** | Sequence touchpoint table — drag to reorder, `on:*` branch rules |
| **CCLift** | Variant card with z-test, gated on 100 conversions per arm; incremental ROAS |
| **CCAttr** | Attribution rollup — first/last/linear toggle, per-channel weights |
| **CCNotif** | NotificationBell topic wiring for all campaign events |

### Phase 4 — Channels (needs CIntegrations + CSwarm-core)

| Cycle | What ships |
|---|---|
| **CMediaCreative** | Image/video/voice provider adapters + `designer` + `voice` agents |
| **CMediaAds** | Meta/Google/LinkedIn/TikTok push adapters + `paid-*` agents |
| **CMediaEmail** | Klaviyo/Resend/Postmark adapter + `email` agent |
| **CMediaSMS** | Twilio adapter + `sms` agent |
| **CMediaSocial** | Organic social adapter + `social-organic` agent |
| **CMediaContent** | CMS adapters + `content` + `seo` agents |

**L5 self-optimisation ships in a follow-up plan** (`l5-todo.md`) — the schema and state machine exist; the detect-trigger-push runtime is separate work. v1 ships manual creative regeneration via the variant card.

**Campaigns have no dedicated page or route.** They live in `/in?preset=campaigns` — the `groups` dimension filtered by `kind:campaign`. The entire UI is RAIL_ORDER entries + EntityDetail tabs. **The minimum demo-able unit is CSwarm-core + CQW1 — brief → card → approve — before any analytics, validation, or channel wiring exists.**

---

## 11. The one-liner

> You write one sentence. The marketing-agent department builds the whole campaign — audience, copy, images, video, voiceovers, ad creatives, emails, SMS, organic social posts, blog content, the lot. You tap `[Approve & ship]`. The campaign runs across every channel — Meta, Google, LinkedIn, TikTok, Klaviyo, Twilio, Twitter/X, LinkedIn organic, Instagram, TikTok organic, Webflow — watches what works, and surfaces winners as you go. Lives on `/in`, uses the existing composer and charts, takes ~2 seconds to honour any change a client makes to a markdown file. **Brief to live: 5–10 minutes. One console, every channel, paid and organic.**

---

*Built on
[`one/marketing-ontology.md`](../plans/marketing-ontology.md) (the marketing-agent department · persona + offer schema · learning loops · KPI ladder),
[`web/tracking.md`](tracking.md) (`AgentEvent.campaign` · `/go/:id` · tag-pair pheromone · consent gates · vault · forget cascade),
[`web/agent-analytics.md`](agent-analytics.md) (`funnel_daily` filtered by campaign · `variantLift()` · `attribution()` · `useWatch`),
[`web/crm.md`](crm.md) (the composer · signal templates · tag taxonomy · status engine · lens packs · channels · roles cascade per [`web/roles.md`](roles.md)).
Shell at [`web/src/pages/in.astro`](src/pages/in.astro).
Components from [`web/src/components/in/`](src/components/in/) and [`web/src/components/funnel/`](src/components/funnel/).
Client customisation via `client.syncAgent()` in `sdk/` → `web/src/engine/agent-md.ts` → `claw/src/agents/builder.ts`.
No new entities. No new tables. No new routes. The substrate runs the campaign; the swarm authors it; the client extends it; you ship it.*
