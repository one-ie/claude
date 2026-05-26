# crm.md — tags, subscriptions, pheromone

**Principle.** ONE has one inbox at [`/in/[groupId]`](src/pages/in/[groupId].astro).
The substrate already has four primitives — actors, tags, signals,
pheromone. Every "CRM feature" is one of those primitives wearing a
different costume.

**Apple built a CRM. Discord built it for AI agents.** Three columns,
keyboard everything, sub-100 ms per action. Power through simplicity.

```
              ┌──────────────────────────────────────────────┐
              │     SUBSTRATE (signals.md is the contract)   │
              │                                              │
              │   actors  ←──────  tags  ──────→  signals    │
              │      ▲              │                ▲       │
              │      │              ▼                │       │
              │   subscribe     pheromone           emit     │
              │   (tag yours)   (remembers          (one     │
              │                  what worked)        verb)   │
              └──────────────────────────────────────────────┘
                                  │
                                  ▼
              ┌──────────────────────────────────────────────┐
              │                  /in surface                  │
              │   sidebar (subs) · inbox (matches) · detail   │
              └──────────────────────────────────────────────┘
```

The CRM is what the substrate does. The UI is three columns.

---

## 0. The contract — every CRM concept is a tag pattern

See [`one/signals.md`](../plans/signals.md) for the substrate primitive.
**Subscriptions are tags + pheromone.** An actor with tag
`sub:news:crypto` receives every signal sent to `sub:news:crypto`.
Engagement strengthens; ignoring fades; no unsubscribe needed.

| CRM word | Tag pattern |
| --- | --- |
| Channel · segment · audience · cohort · list | `sub:<name>` — actors subscribed to it |
| Status (now / top / todo / done) | `status:<x>` — computed per dimension rules (§3) |
| Lifecycle (anonymous → … → advocate) | `lifecycle:<stage>` on actor; transition = tag-swap signal |
| Owner / assignee | `owner:<actor>` on entity; claim = `c` shortcut |
| Reaction (👀 ✅ 🔥 ❌) | `react:<emoji>` on signal |
| Mention | signal to actor with `mention:<from>` |
| Internal note | `visibility:internal` — outbound adapters skip |
| Sequence step | signal tagged `seq:<id>:step:<n>` |
| Bulk email | `emit({ receiver: 'sub:seg:<x>', data: {...} })` |
| Task | signal to self with `kind:task` + `remind-at` |
| Meeting | thing with `kind:meeting` linked to actor |
| KB article | thing with `kind:knowledge`; search = tag match |
| SLA red/yellow/green | `sla:<colour>` computed from signal age |
| CSAT request / response | signal `kind:csat-request` / `csat:rating:<n>` |
| Pipeline column | `group_by=lifecycle` URL param |
| Discovered journey | signal `kind:hypothesis` from L6 KNOWLEDGE loop |
| Team chat room | `sub:team:<x>` — subscribers see + post |
| Lens (marketer / sales / service) | a default subscription pack (5–7 tags) |
| Handoff | `owner:<new> · reassigned-from:<me> · reason:<r>` |
| Snooze · send-later · remind | `snooze-until` · `send-at` · `remind-at` on signal |

**None of these need a new entity, table, route, or UI surface.** They
are signals carrying tags. The substrate's `emit` + tag + subscription
covers every workflow a CRM does.

---

## 1. The three columns

```
┌─────────────────────┬─────────────────────────┬──────────────────────────┐
│  SUBSCRIPTIONS      │  INBOX                  │  DETAIL + COMPOSER       │
│  (what you watch)   │  (signals matching      │                          │
│                     │   the selected sub)     │                          │
│  ⌘K  search         │                         │   Ada Lovelace            │
│  +   subscribe      │  TODAY                  │   customer · ltv £4,210   │
│                     │  ada · telegram · 2m ●● │   fit 0.82                │
│  📥 inbox       42  │  brad · email · 12m     │                          │
│  ⭐ vip          5  │  cathy · discord · 18m  │   consent ✓✓✗✗            │
│  🔥 escalations  2  │                         │   channels: tg@ada …      │
│  💬 #leads      14  │  YESTERDAY              │   appended: clearbit:CTO  │
│  💬 #cs-team     8  │  dion · web · y'day     │                          │
│  🔍 lifecycle:sql 7 │                         │   activity                │
│  🔍 owner:me    23  │  THIS WEEK              │   12:04 click /pricing   │
│  🔍 mention:me   3  │  emily · telegram        │   12:01 open E3-d7        │
│  ─────────────      │                         │   yest reply telegram     │
│  pinned ▲           │                         │                          │
│  by pheromone ▼     │                         │  [compose ▾ ]              │
│                     │                         │  to:   ada                │
│                     │                         │  tags: reply · public     │
└─────────────────────┴─────────────────────────┴──────────────────────────┘
```

### Left — Subscriptions

The tags you've raised your hand for. Mix of channels, team rooms,
filter queries, identity queries — the substrate doesn't distinguish.

- Top section: **pinned** (manual drag-to-reorder); a user keeps
  load-bearing subs at the top (inbox, vip, escalations)
- Bottom section: **by pheromone** — subs you actually use rise; ones
  you ignore drift down and fade out (L3)
- `+` to subscribe to anything: type a tag (`sub:xxx`), pick from
  suggestions, or ★ from any list view to save the current URL as a sub
- Unread counts live via `useWatch()` SSE
- `⌘K` spotlights tags across the workspace

Subscription = `sub:<tag>` written to the actor's TypeDB row. Restored
on boot via `load()` per [`signals.md`](../plans/signals.md). No
"channel members" table. No "ACL" cycle. The tag IS membership.

### Middle — Inbox

Whatever signals/entities the current subscription is receiving. Date-
sectioned. Pheromone-aware sort (recent + strength). `j/k` walks.
`group_by=<attr>` URL param renders pipeline columns (`lifecycle`),
owner lanes (`owner`), thread cards (`actor+channel`), date sections
(default).

### Right — Detail + composer

Apple-Contacts-style for actors; thread-style for events; KB-style
for things. **Detail panels are tag-driven** — what you see is the
subset of tag namespaces present on the entity (`consent:*`,
`channels:*`, `appended.*`, `same-as`, `paths`, `groups`).

Click any field → edit in place; signal fires (`actor:update.<field>`);
optimistic UI sticks.

`e` toggles entity-detail · `c` toggles team chat (same channel's
right pane shows team conversation).

Composer at the bottom is universal — see §4.

---

## 2. Subscriptions — the only navigation primitive

```
            CAROL
              │   "subscribe me to bounces and escalations"
              ▼
            WORLD writes two tags on Carol's actor row:
              sub:bounce            (strength 1.0 seed)
              sub:escalation        (strength 1.0 seed)

          Now signals tagged `sub:bounce` route to Carol.
          Carol opens → pheromone grows. Carol ignores → L3 fades.
```

### Adding a subscription

| Path | When |
| --- | --- |
| Type tag in `+` | "I know the tag I want" |
| `★` on any list URL | "I want to keep this view" |
| `★` on any tag pill in any view | "show me more like this" |
| Workspace template at setup | "give me the marketer pack" |
| Owner override per role | "make sales team's default include #stuck" |

### Sidebar order

```
PINNED (manual drag)
  📥 inbox
  ⭐ vip
  🔥 escalations

BY PHEROMONE (auto-sorted, strongest first)
  💬 #leads       14   (engaged 47 times this week)
  💬 #cs-team      8   (engaged 12 times)
  🔍 lifecycle:sql 7   (engaged 5 times)
  🔍 owner:me     23   (engaged 60 times — should it be pinned?)
  🔍 mention:me    3   (engaged 2 times)
  ─────  fading  ─────
  🔍 trial-d14     ·   (haven't touched in 14d; will drop off)
```

Pinned never fades. Unpinned subs fade at L3 cadence — substrate
remembers what you use; sidebar reflects it.

### Default subscription packs (lens replacement)

Workspace owner picks a pack at setup. Pack = a list of tags to
auto-subscribe the user to. Lens-switching = re-applying a pack.

**Marketer pack:**
```
inbox · vip · escalations
sub:campaign:running · sub:bounce · sub:unsub · sub:open-rate-anomaly
sub:team:marketing
```

**Sales pack:**
```
inbox · vip · escalations
sub:owner:me · sub:lifecycle:sql · sub:close-date:this-week
sub:hot · sub:stuck · sub:team:sales
```

**Service pack:**
```
inbox · vip · escalations
sub:sla:red · sub:sla:yellow · sub:owner:me
sub:csat:low · sub:team:cs
```

Owner can edit packs at `/settings/packs`. Adding a new "BDR" pack =
clone "Sales" + edit. No code change.

---

## 3. Status — computed per-tag rules

Status (`now / top / todo / done`) is not stored; it's derived from
tag patterns + thresholds. Workspace owner edits the rules at
`/settings/status`.

Defaults:

```
events (signals):
  now    receiver:human AND not has tag:mark
  top    has tag:actor.ltv:gte:high-value-threshold
  todo   has tag:confidence:lt:0.65 OR has tag:compliance:flag
  done   has tag:mark OR has tag:warn

actors:
  now    has tag:lifecycle in {lead, mql, sql}
  top    has tag:ltv:gte:high-value OR has tag:fit:gte:0.85
  todo   has tag:consent:missing OR has tag:dormancy:warming
  done   has tag:lifecycle in {customer, advocate, churned}

paths · groups · learning · things — see crm.md previous spec
```

Status itself is also a tag: filter `?d=actors&filter=status:top`.
Splits chip row above the inbox renders one chip per status with live
count.

---

## 4. The universal composer

One composer, one shape, every workflow.

```
┌─────────────────────────────────────────────────────────────┐
│ to:                                                          │
│   ○ direct       ada                       (one actor)       │
│   ● world        world:dental              (best by phero)   │
│   ○ all          all:reviewer              (every capable)   │
│   ○ subscribe    sub:seg:trial-d7          (every sub'r)     │
│                                                              │
│ tags:    public · campaign:apr-q2 · channel:auto             │
│          [+ tag]                                             │
│                                                              │
│ ┌──────────────────────────────────────────────────────────┐│
│ │ Hi @ada, here's the hygienist info you asked about…      ││
│ │                                                          ││
│ │ /go book → https://one.ie/go/4xZ                        ││
│ └──────────────────────────────────────────────────────────┘│
│                                                              │
│ schedule:   now  ·  ⌘⇧↵ pick                                │
│ holdout:    none · 10% control                              │
│                                                              │
│                                              ⌘↵  send       │
└─────────────────────────────────────────────────────────────┘
```

Five things to fill — most defaulted from context:

1. **Receiver mode** — direct / `world:` / `all:` / `sub:` (per
   [`signals.md`](../plans/signals.md) §5)
2. **Tags** — claw suggests; user adds via `+` (`campaign:*`,
   `channel:*`, `visibility:*`, `react:*`, etc.)
3. **Body** — text + attachments + tracked links + `@mention` +
   `/snippet` text expansion
4. **Schedule** — now or pick (`send-at` tag on the signal)
5. **Holdout** — for bulk sends

**This composer handles everything.** What I previously called bulk
email, sequences, tasks, meetings, internal notes, broadcasts — all
the same: pick receiver, pick tags, type body, send.

| Workflow | What you fill |
| --- | --- |
| Reply to Ada | direct: ada · tags: reply · public |
| Internal note about Ada | direct: ada · tags: reply · visibility:internal · mention:@dr-smith |
| Broadcast to trial-d7 | sub: sub:seg:trial-d7 · tags: campaign:apr-q2 · holdout:10% |
| Self-task | direct: me · tags: kind:task · remind-at:tomorrow-10am |
| Sequence step | direct: ada · tags: seq:trial-rescue:step:2 · send-at:+24h |
| Meeting invite | direct: ada · tags: kind:meeting · attach:available-slots |
| Send to CS team | sub: sub:team:cs · tags: handoff · reason:technical-question |
| Find a reviewer | world: world:review+security · tags: priority:high |

Receiver mode + tags = the workflow. Body = the content. No mode
toggles, no internal-note tabs, no separate sequence editor.

### Tag pickers (Apple-Contacts polish)

- Click any tag in the pill row → quick-edit
- `+` opens picker → claw suggests based on receiver + body draft
- Recently-used + workspace canonicals at top
- Tags carry colour from `/settings/tags` taxonomy

---

## 5. Tag taxonomy — workspace-managed

Tags are the universal join key. Without a taxonomy they sprawl. With
one, they compose.

```
/settings/tags
─────────────────────────────────────────────────────────────
  NAMESPACE       USAGE              ACL          COLOUR
─────────────────────────────────────────────────────────────
  lifecycle:*     6 values · locked  any-write    blue
  channel:*       8 values · locked  any-write    grey
  campaign:*      open · workspace   marketer     orange
  seg:*           open · workspace   marketer     orange
  owner:*         actors only         any-write    green
  team:*          12 values           owner only   purple
  visibility:*    {internal,public}   any-write    yellow (int)
  react:*         emoji set           any-write    none
  sla:*           {red,yellow,green}  computed     red/y/g
  status:*        {now,top,todo,done} computed     none
  iab/*           IAB v3 catalogue    locked       none
  gdpr · ccpa     compliance flags    locked       red
  appended.*      enrichment source   import-only  faded
  ...

  + new namespace
─────────────────────────────────────────────────────────────
```

Owner curates. Some namespaces are locked (substrate-defined:
`lifecycle:*`, `iab/*`, `gdpr`, `ccpa`). Some are computed
(`status:*`, `sla:*`). Some are open per workspace.

Claw suggests new tags as patterns emerge in signals — workspace
owner can promote a frequent ad-hoc tag to a canonical namespace.

---

## 6. Signal templates — the standard CRM, as data

Every "feature" I previously planned (sequences, bulk email, tasks,
meetings, KB, CSAT, SLA, journeys) is a **signal template**:
pre-filled composer values + an optional schedule + optional reply
expectations.

```
/settings/templates
─────────────────────────────────────────────────────────────
  TEMPLATE                  RECEIVER MODE   TAGS               BODY
─────────────────────────────────────────────────────────────
  ◤ welcome-email           sub             campaign:welcome,  …mjml
                                            channel:email
  ◤ trial-d2-checkin        direct          seq:trial:step:1,  "Hi {name}, how's…"
                                            send-at:+24h
  ◤ proposal-followup       direct          kind:task,         "Follow up on…"
                                            remind-at:+3d
  ◤ csat-after-close        direct          kind:csat-request, "Rate 1-5"
                                            channel:auto
  ◤ meeting-booker          direct          kind:meeting,      [calendar widget]
                                            attach:slots
  ◤ internal-handoff        direct          visibility:internal,"…"
                                            handoff, reason:?
  ◤ kb-suggest              read-only       kind:knowledge     (claw search)
─────────────────────────────────────────────────────────────
  + new template
```

A **sequence** = a path of templates chained by `then`-rules; the
journey runtime (CJ) drains them. A **bulk-email campaign** = a
template with `sub:` receiver, scheduled. A **task** = a template
with `direct:me` + `remind-at`. There is no "sequence builder app",
no "bulk email composer", no "task manager" — they're all rows in
the templates table that pre-fill the universal composer.

Template library ships with 30 starters per role (marketer / sales /
service). Owner can author new ones. Templates can be ★ to a user's
quick-pick row in the composer.

---

## 7. Channels = team subscriptions

Every team channel is a tag (`team:cs`) and a subscription
(`sub:team:cs`). Members are whoever subscribed — humans + agents,
same primitive.

```
HUMAN: bob.subscribe("team:cs")
AGENT: kb-agent.subscribe("team:cs")
       compliance-agent.subscribe("team:cs")

Signal tagged team:cs fans out to all 3.
Bob sees it in his inbox.
KB agent processes it (suggests reply).
Compliance agent watches for keywords.

Each delivery marks the path. Engaged subscribers rise.
Ignored agents fade (pheromone decay).
```

### Mentions

`@<handle>` in any composer body fires a direct signal to that actor
with `mention:<from>` tag. Recipients have subscribed to
`sub:mention:me` by default → their mentions inbox lights up.

### Internal notes

Tag `visibility:internal` on a signal. Outbound channel adapters
(email/SMS/telegram/discord) gate on this tag and skip. Internal
notes still log to the activity feed, render yellow. `@mentions` in
internal notes route only within the workspace's team.

### Agent collaboration

Agents are first-class subscribers. `@kb-agent` mentioned in a
channel chat → agent receives signal → posts back into the same
channel with `team:cs · reply:agent-kb · citations:[…]` tags.
Humans see the cited reply inline.

Permission per-tag: agents can subscribe but their action ACL
(what verbs they can call when handling a signal in this channel)
is set per agent at `/settings/agents`.

---

## 8. Channel integration — every external channel is an adapter

Telegram · Discord · Email · SMS · WhatsApp · Web chat · Voice ·
In-app push · Calendar. Same shape: adapter turns external events
into signals on the bus, outbound signals into platform API calls.
Tag `channel:<x>` records origin.

No CRM-specific branches. Inbound → `emit({...})`. Outbound →
adapter sees signal tag and calls API.

---

## 9. Tracked links — `/go/:id`   ✅ shipped

Every tracked link writes a `signal` with `touch:click · campaign:<c>`,
sets a first-party cookie keyed to `visitor_hash`, and redirects.
Email-hash form via `/r?e=&c=&u=` for forwarded-email arrivals.
**Never raw PII in URLs.**

---

## 10. Enrichment — `appended.<source>.<field>`

Importer agents subscribe to `sub:lifecycle:lead` transitions and
write attributes back into the `appended.*` namespace. Manual
overrides land in `appended.manual.*` and display logic prefers
manual.

Importers ship: Clearbit · Apollo · Stripe · Shopify · GA4 · Meta
Pixel · Segment · RudderStack · HubSpot · Salesforce.

---

## 11. Privacy posture — vault + forget + reveal

Three collection modes (`minimal | balanced | forensic`) per
workspace. Three key-custody modes (`one-managed | customer-managed |
bring-your-own`). Vault row KMS-shredded in <1s on `POST /api/forget`;
cascade across vault → KV → D1 → TypeDB → R2 → ad platforms.
`GET /api/forget/:request_id` returns receipt. Every raw-PII read
fires `pii.read` event with reader_id + scope + justification, rate-
limited 100/hr per reader.

`/settings/privacy` is the dial.

---

## 12. Identity merge   ⬜ W7

Five rungs: cookie · visitor_hash · email-hash · phone-hash ·
auth-provider sub. `same-as(a, b)` relation with confidence; merges
≥ 0.95 auto, 0.6–0.95 queued for human, < 0.6 dropped. KPI:
identity-resolution-rate > 95%. Below threshold → review queue at
`?d=actors&s=todo&filter=needs-review:merge`.

---

## 13. APIs + SDK + MCP

**Substrate routes (already shipped):**

```
POST   /api/signal/[...receiver]     emit any signal
GET    /api/ask/[...receiver]        request/reply
POST   /api/mark/[edge]   /warn/[edge]   /fade   /follow   /select
POST   /api/events                   typed AgentEvent ingest
GET    /api/analytics/watch          SSE — live tail
GET    /go/:id   /r?e=&c=&u=         tracked redirects
GET    /api/export/{actors,groups,skills,highways}
GET    /api/frontiers                learning candidates
GET    /api/in/sessions              event feed for /in
GET    /api/actors/[id]              actor detail + activity
POST   <clawUrl>/conversations/:id/reply
POST   <clawUrl>/broadcast
```

**New for the CRM (CSP + W11):**

```
GET    /api/pii/reveal/:actor?fields=&justification=
POST   /api/forget    { actor_id | email_hash | visitor_hash }
GET    /api/forget/:request_id
```

**SDK** — same primitives. `signal()` / `mark()` / `warn()` /
`subscribe()` / `ask()` / `watch()` already cover every CRM verb.
Helpers: `emitTemplate(name, overrides)` fires a template.

**MCP** — `@oneie/mcp` exposes inbox primitives so any LLM (Claude
Desktop, Cursor, …) operates the CRM with sub-100ms calls:

| Tool | Wraps |
| --- | --- |
| `inbox_list` | filter by tag(s) + sort |
| `inbox_open` | actor / signal / thing / path detail |
| `inbox_send` | emit (direct / world / all / sub) with tags |
| `inbox_subscribe` | tag the calling actor with `sub:<x>` |
| `inbox_mark` / `warn` | close the loop |
| `inbox_react` | tag a signal `react:<emoji>` |
| `inbox_forget` | privacy cascade |
| `inbox_pulse` | KPI tile read |
| `inbox_watch` | SSE notifications by tag |

Same shape Superhuman ships at
[`superhuman.com/products/mail/mcp`](https://superhuman.com/products/mail/mcp).
LLM types "show me high-LTV escalations from today and draft replies"
→ `inbox_list({s:'todo', filter:['ltv:gte:1000','ts:today']})` →
`inbox_open(...)` → `inbox_send(...)`.

---

## 14. Standards as tag namespaces

```
iab/content/v3/<id>     openrtb/v2.6/<field>     ga4/event/<n>
iab/audience/v1/<id>    meta/audience/<id>       google/match/<list>
klaviyo/list/<id>       hubspot/list/<id>        salesforce/campaign/<id>
liveramp/rampid/<hash>  tcf/v2/<purpose>         schema.org/Person
gpc · ccpa · canspam · tcpa · gdpr
```

Adding a new standard = adding a namespace + an ACL row in tag
manager (§5). Nothing else changes.

---

## 15. Failure modes

**Stage transition misfires.** Model classifies "tell me more" as
`intent:proposal-request`, advances actor to `sql` prematurely. Rule
visible on contact record; override is one keystroke; override signal
shifts the model's prior.

**Identity merge false positive.** Probabilistic merge combines two
actors. Confidence logged; < 1.0 surfaces in review queue.
`split(a, b)` writes `same-as NOT` relation, preserves provenance via
`merged-into`.

**Enrichment overwrite.** Importer fetches stale data over a manual
correction. `appended.<source>.<field>` provenance shows who wrote
what when; `appended.manual.*` always wins on display.

---

## 16. HubSpot / Salesforce / GoHighLevel migration

Substrate runs in parallel during transition. Importer maps CSV/API
in one pass; custom props → `appended.<source>.<field>`; identity-
ladder dedupes by email-hash. Write-through agent (`export-hubspot`)
subscribes to `actor:lifecycle` transitions and calls HubSpot CRM API
within 30s. Team sees HubSpot until substrate's view is richer
(typically ~90 days). Cancel HubSpot seat when ready. No mandate.

---

## 17. What we explicitly don't build

- **No `/crm/*` route tree.** Everything lives at `/in/[groupId]`.
- **No per-feature UI surface.** Sequence builder, bulk email
  composer, task manager, meeting scheduler, internal-notes tab,
  reactions popover, mention dialog — all the universal composer.
- **No "channel members" table.** Members are subscribers; tag IS membership.
- **No "team" entity.** Team = `sub:team:<x>` subscribers.
- **No "ticket" entity.** Ticket = signal with `kind:ticket` + SLA tags.
- **No "deal" entity.** Deal = `thing:offer` linked to actor.
- **No "owner" table.** Owner = `owner:<actor>` tag on entity.
- **No "automation engine."** Templates + journey runtime + tag
  subscriptions cover every automation.
- **No "lens" surface.** Lens = subscription pack; switching = re-applying.
- **No "split" component.** Splits are subscriptions, sidebar entries.
- **No "channel" component separate from filter view.** They're one.
- **No "DM" surface separate from actor view.** DM = direct signal.
- **No saved-view storage outside the URL.** Stars become tags
  (`sub:<url>`) — even your bookmarks are subscriptions.
- **No pipeline kanban app.** `?group_by=lifecycle` renders columns.
- **No mouse-only fast path.** Every action has a key under 100 ms.

---

## 18. Build order — 17 cycles total

The substrate provides 80%. These 17 cycles ship the UI.

| Cycle | Ships |
| --- | --- |
| **CS** | Status semantics — per-dimension tag-rule assignment + thresholds |
| **CV** | Actor detail (tag-driven panels: consent / lifecycle / same-as / paths / appended) + click-to-edit |
| **CSub** | Subscription sidebar — pinned + pheromone sort; `+` / `★` / `✕`; unread counts; subscription packs per role; `⌘L` switch pack |
| **CComp** | Universal composer — receiver picker (direct/world/all/sub) + tag picker + body + schedule + holdout |
| **CTagMgr** | Workspace tag taxonomy — namespace registry + ACL + colour + claw suggestions |
| **CTpl** | Signal templates — table-of-templates UI; 30 starters per role; quick-pick row in composer |
| **CGroupBy** | `group_by=<attr>` URL param — date · thread · pipeline (lifecycle) · owner lanes |
| **CK** | Keyboard contract — `⌘K` spotlight + 30 shortcuts + `?` overlay |
| **CPerf** | <100 ms per-action perf budget |
| **CMcpInbox** | `@oneie/mcp` `inbox_*` tools — 9 verbs |
| **CJ** | Journey runtime — `path`/`funnel` executor for sequence-template chains |
| **CP** | Pulse — KPI lens over signal stream; 12 tiles |
| **CSP** | `/settings/privacy` + `/settings/packs` + `/settings/templates` + `/settings/tags` + `/settings/status` — five small admin pages |
| **CX** | Remaining exports + importers (google/tiktok/klaviyo/salesforce + clearbit/apollo/stripe/shopify/ga4) |
| **CH** | HubSpot write-through agent |
| **W7** | Identity rungs 2–5 + `same-as` merge |
| **W11** | PII vault + `/api/forget` cascade + `pii.read` audit |

**Critical path:** CS · CV · CSub · CComp · CTagMgr · CTpl · CK · CPerf = 8 cycles to call the CRM shipped end-to-end. The rest layer integrations, privacy, identity, and external surface.

---

## 19. One-line summary

> The CRM is tags + subscriptions + pheromone. The UI is three
> columns. Apple built the contacts pane; Discord built the channel
> sidebar; Superhuman put the keyboard on every action; the
> substrate already runs the brain. Power through simplicity.

---

*Built on [`one/signals.md`](../plans/signals.md) (the contract — subscriptions are tags),
[`web/src/pages/in/[groupId].astro`](src/pages/in/[groupId].astro) +
[`web/src/components/in/`](src/components/in/) (surface code, live),
[`one/marketing-ontology.md`](../plans/marketing-ontology.md) (attributes),
[`web/tracking.md`](tracking.md) (wire format),
[`web/agent-analytics.md`](agent-analytics.md) (KPIs),
[`web/roles.md`](roles.md) (cascade),
[`one/one-ontology.md`](../plans/one-ontology.md) (dimensions),
[`one/dictionary.md`](../plans/dictionary.md) (names),
[`text/12-crm.md`](../text/12-crm.md) (voice + worked example).
No new entities. No new routes. No new tables. The substrate runs the
CRM. The UI is three columns.*
