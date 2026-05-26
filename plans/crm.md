# crm.md — tags, subscriptions, pheromone

**Principle.** ONE has one CRM shell, reachable at three scopes:
[`/in`](src/pages/in.astro) (operator-global, shipped),
[`/in/[groupId]`](src/pages/in/[groupId].astro) (workspace/agency,
shipped), and `/u/[slug]/in` (per-client, QW13). All three render
`<Inbox>` with the same data layer; scope is enforced by the role
cascade in [`web/roles.md`](roles.md). The substrate has four
primitives — actors, tags, signals, pheromone.
Every "CRM feature" is one of those primitives wearing a different
costume. The path forward is **not a rewrite**: extend the shell that
ships via focused quick wins ([`crm-todo.md`](crm-done.md) Phase 1).

**Apple built the mail metaphor. Discord built channels for AI agents.**
Three columns, keyboard everything, sub-100 ms per action. **Power
through simplicity** — within-noun state lives in URL params, not new
routes.

**The slug surfaces.** Routes under `/u/[slug]/*` are scoped to a
single workspace:
- `/u/[slug]/chat` — the public chat widget; signals from here flow
  to the inbox tagged with this slug
- `/u/[slug]/people`, `/analytics`, `/agents/[id]/...`,
  `/skills/*`, `/settings`, `/billing` — per-workspace admin pages
- **`/u/[slug]/in`** — the client's own CRM inbox (QW13). Same
  `<Inbox>` shell, filtered to `slug`. Each client sees only their
  own data.

**Signal sources, all writing to the same store
([`agent_events`](src/pages/u/%5Bslug%5D/people.astro) D1 table +
substrate signals + TypeDB graph):**
- chat at `/u/[slug]/chat` → `/api/chat` → D1 `threads` + `messages`
  (slug-scoped, keyed by visitor cookie); also tagged with slug for
  substrate signals
- channel adapters (Telegram · Discord · Email · SMS · Web · Voice)
  → claw → tagged with slug
- tracked links per [`tracking.md`](tracking.md) — `/go/:id` clicks,
  `/r?e=&u=` opens — also tagged with slug

**Chat ↔ Inbox loop (per-slug, bidirectional, ~3-4 s):**

```
/u/<slug>/chat ──POST /api/chat──▶ D1 threads/messages
       ▲                                   │
       │ poll 4s (GET /api/chat?slug=)     │
       │                                   ▼
       │                       GET /api/export/conversations
       │                                   │
       └──── owner reply ◀── /u/<slug>/in (Inbox polls every 3s)
              POST /api/threads/:tid
```

Owner replies from `/u/<slug>/in` land as `assistant`-role rows in the
same thread; the chat client polls `/api/chat?slug=` for unseen ids and
appends them inline.

The CRM inbox reads from that single store, scoped by the URL.
Operator sees `/in` (everything). Agency sees `/in/[groupId]` (their
clients). Client sees `/u/[slug]/in` (just their data). One brain,
three lenses.

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
              │           /in + /in/[groupId] shell           │
              │   rail (group · mail · work · channels ·      │
              │         tags + learning · user)               │
              │   list (rows by preset) · detail + composer   │
              └──────────────────────────────────────────────┘
```

The CRM is what the substrate does. The UI is three columns; the rail
is six zones. See [`crm-pages.md`](crm-pages.md) for the visual spec
and [`crm-todo.md`](crm-done.md) for the ship order.

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
| Campaign / program | `group:campaign` + tag `campaign:<id>` — see [`campaigns.md`](campaigns.md) |
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

Three columns plus a 220px rail with six zones. The visual spec lives
in [`crm-pages.md`](crm-pages.md); this section describes the route
shape.

```
┌─────────────────────┬─────────────────────────┬──────────────────────────┐
│  RAIL (220px)       │  LIST (340px)           │  DETAIL + COMPOSER       │
│  ─────────────────  │  per-route rows         │                          │
│  [Personal · grp ▾] │                          │  Ada Lovelace             │
│                     │  ┃NOW TOP TODO DONE     │  customer · ltv £4,210    │
│  MAIL               │  ──────────────────────  │  fit 0.82                 │
│  ┃📥 Inbox      42  │  ▌ Ada Lovelace    2m  │                           │
│   📝 Drafts      3  │   "MCP server?"  ●●●●○  │  consent ✓✓✗✗             │
│   📤 Sent           │  ──────────────────────  │  channels: tg@ada …       │
│                     │   Brad Pinto      12m  │  appended: clearbit:CTO   │
│  WORK               │   "yearly invoice?"     │                           │
│   ✓ Tasks       12  │   ●●●○○                 │  ▾ activity               │
│   📅 Calendar    5  │  ──────────────────────  │   12:04 click /pricing   │
│   💳 Payments    8  │   ⋮ 38 more              │   12:01 open  E3-d7       │
│   👥 People    40   │                          │   yest  reply telegram    │
│   🤖 Agents     6   │                          │                           │
│   📊 Analytics      │                          │  [compose ▾ ]              │
│                     │                          │  to:   ada                │
│  CHANNELS       +   │                          │  tags: reply · public     │
│   # leads      14   │                          │                           │
│   # cs-team     8   │                          │                           │
│   # vip         5   │                          │                           │
│                     │                          │                           │
│  TAGS               │                          │                           │
│   lifecycle:sql 7   │                          │                           │
│   owner:me     23   │                          │                           │
│   @mention      3   │                          │                           │
│   ─── learning ─    │                          │                           │
│   💡 discovered 12  │                          │                           │
│   🔬 frontier  47   │                          │                           │
│                     │                          │                           │
│  ⊙ Loading…    ⋯    │                          │                           │
└─────────────────────┴─────────────────────────┴──────────────────────────┘
```

### Left — the rail (six zones)

Each zone maps to a URL **preset** on the `/in` shell. Presets are
captured as URL state (`?preset=<id>` plus `?s=`, `?view=`, `?sort=`,
`?focus=`). The shell is one shipped route; the rail just changes
what the list column filters.

| Zone | Presets |
| --- | --- |
| Group dropdown (top) | switches `groupId` — `/in/<new-groupId>` |
| **MAIL** | `inbox` (default) · `drafts` · `sent` |
| **WORK** | `tasks` · `calendar` · `payments` · `people` · `agents` · `analytics` |
| **CHANNELS** | one preset per admin-curated subscription (§7) |
| **TAGS** | one preset per pheromone-ranked tag. Learning pair pinned at tail: 💡 Discovered (L6) + 🔬 Frontier (L7) |
| User card (bottom) | presence dot · email · `⋯` menu (→ `/settings`) |

The 6 substrate dimensions (`groups · actors · things · paths ·
events · learning` from
[`web/src/data/in-types.ts`](src/data/in-types.ts)) are what each
preset filters; the rail re-frames them into the human nouns above.

**Routes that ship outside the CRM shell.** The `/u/[slug]/*` tree
is **per-agent** — each agent has its own chat, people, analytics,
agents, skills, settings, billing pages. Those are agent surfaces,
not the CRM. The CRM admin works inside `/in`.

### Middle — the list column

Whatever entities the focused route surfaces. Same shell, different
density per noun ([`crm-pages.md`](crm-pages.md) §3): Apple Contacts
rows for People/Agents, Apple Mail rows for Inbox/Tasks/Channels/Tags,
calendar strip for Calendar, table for Payments.

Above the rows: `▣` rail-toggle · noun title · blue `+ New` ·
scoped search · contextual hero CTA · status tabs (NOW/TOP/TODO/DONE)
· view-mode toggle (List/Pipeline/Kanban/Calendar/Map/Funnel).

`j/k` walks rows. `␣` peeks detail. `?s=`, `?view=`, `?sort=`,
`?group_by=` capture within-route state.

### Right — detail + composer

Apple-Contacts-style for actors; thread-style for events; DAG for
paths; KPI atlas for analytics. **Detail panels are tag-driven** —
what you see is the subset of tag namespaces present on the entity
(`consent:*`, `channels:*`, `appended.*`, `same-as`, `paths`).

Click any field → edit in place; signal fires (`actor:update.<field>`);
optimistic UI. Tabs partition namespaces (Overview · Personal ·
Professional · Social · AI Context · Network for human actors).

Per-entity detail is direct-linkable as URL state: `?focus=<entity-id>`
on the appropriate preset (`/in?preset=people&focus=ada-lovelace`,
`/in?preset=tasks&focus=<task-id>`, etc.). The right pane swaps body
content by entity kind; the URL captures everything needed to share
or reload the view.

Composer at the bottom — two flavours (chat / universal) sharing the
`+ Add · 📎 Attach · 🔍 Search · model · ➤ Send` toolbar. See §4.

---

## 2. Subscriptions — Channels (admin) + Tags (emergent)

Subscriptions live in **two rail zones**, each with a different
authoring model. The rail's nouns (MAIL, WORK) are fixed routes;
Channels and Tags are how the workspace teaches itself which
*subscriptions* deserve their own URL.

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

### Channels — admin-curated presets

Channels are named subscriptions with one or more tags, authored by
admin at `/settings/channels` (§7). Each channel gets:

- name + slug
- emoji, colour
- one or more tags (any combination from the namespace registry)
- ACL (readers / writers)
- description

The CHANNELS rail zone lists them with live unread counts. Clicking a
channel sets `/in?preset=channel:<slug>` — the list column filters to
signals tagged with the channel's tag(s). Members are subscribers —
humans **and** agents.

### Tags — pheromone-ranked long tail

Every other tag the substrate has accumulated, ranked by engagement.
Each tag row sets `/in?preset=tag:<tag>` URL state — the list column
filters to that tag. Pinned never fades; unpinned subs fade at L3
cadence.

```
TAGS
  lifecycle:sql      7
  owner:me          23
  @mention           3
  trial-d7-eu      412
  ─── fading ───
  trial-d14          ·
  ─── learning ──
  💡 discovered     12    ← preset=learning:discovered (L6)
  🔬 frontier       47    ← preset=learning:frontier (L7)
```

`★` next to a row → admin sees "Promote to channel" suggestion.
Discovered + Frontier are pinned permanently at the tail.

### Adding a subscription

| Path | When |
| --- | --- |
| Admin authors a Channel at `/settings/channels` | "this combination of tags is workspace-canon" |
| User types a tag in `+ subscribe` (Tags fold) | "I know the tag I want" |
| `★` on any list URL | "I want to keep this view" — promotes to Tag zone |
| `★` on any tag pill in any view | "show me more like this" |
| `⌘L` applies a lens pack | "give me the marketer pack" — auto-subscribes user to a pack's tags |
| Owner override per role | "make sales team's default include #stuck" |

### Lens packs (role-default subscriptions)

A lens pack is a list of tags to auto-subscribe a user to. Lens-
switching = re-applying a pack.

**Marketer pack:**
```
sub:campaign:running · sub:bounce · sub:unsub · sub:open-rate-anomaly
sub:team:marketing
```

**Sales pack:**
```
sub:owner:me · sub:lifecycle:sql · sub:close-date:this-week
sub:hot · sub:stuck · sub:team:sales
```

**Service pack:**
```
sub:sla:red · sub:sla:yellow · sub:owner:me
sub:csat:low · sub:team:cs
```

Owner edits packs at `/settings/packs`. Adding a new "BDR"
pack = clone "Sales" + edit. No code change.

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
GET    /api/export/{actors,groups,skills,highways,conversations}
GET    /api/frontiers                learning candidates
GET    /api/in/sessions              event feed for /in
GET    /api/chat?slug=&agentId=      resume visitor thread (starters + history)
GET    /api/threads/:tid             read a thread + messages (owner-gated)
POST   /api/threads/:tid             owner reply from /u/<slug>/in
                                     → appends assistant row, chat polls it back
GET    /api/actors/[id]              actor detail + activity
GET    /api/agents/[id]/analytics    KPI + funnel + attribution + holdout
GET/PUT /api/settings?scope=         workspace_settings dispatcher
                                     (status | privacy | packs | thresholds)
GET    /api/tags?workspace=          tag_namespace registry per workspace
GET/PUT/DELETE /api/templates        signal_templates CRUD
                                     (workspace=_starter is read-only, 90 seeds)
POST   <clawUrl>/broadcast            # legacy fan-out to claw conversations
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
| `inbox_list` | `GET /api/actors?tags=` (actors) · `GET /api/export/{dim}` (other dims) |
| `inbox_open` | `GET /api/actors/[id]` (Contact aggregate) |
| `inbox_send` | `POST /api/signal/[...receiver]` — receiver in URL path |
| `inbox_subscribe` | `POST /api/signal/actor:<id>:tag.add` with `data.tag=sub:<x>` |
| `inbox_mark` / `warn` | `POST /api/mark/[edge]` / `POST /api/warn/[edge]` |
| `inbox_react` | `POST /api/signal/entity:<id>:react` |
| `inbox_forget` | `POST /api/forget` — privacy cascade |
| `inbox_pulse` | `GET /api/agents/[id]/analytics` — requires `agentId` |
| `inbox_watch` | `GET /api/analytics/watch` SSE |

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

- **No `/crm/*` route tree.** The CRM shell is `/in` + `/in/[groupId]`.
- **No `/u/[slug]/{inbox,drafts,sent,tasks,calendar,payments,c/[channel],t/[tag],learning/…}` route tree either.** The `/u/[slug]/*` routes (chat, people, analytics, agents, skills, settings, billing) are **per-agent surfaces** — each agent has its own pages. The CRM is the workspace-wide shell at `/in`; agents' workspaces are separate. Don't duplicate.
- **No per-rail-row Astro route.** Each rail row sets URL state on the existing shell (`/in?preset=<id>&focus=<entity>&view=<mode>`); there is no `/inbox.astro`, `/tasks.astro`, etc. as separate pages.
- **No per-noun UI shell.** Every preset gets the same shell — rail · list · detail · composer. Density and detail-tab set vary by noun; the layout and interaction model do not.
- **No per-feature UI surface inside the composer.** Sequence builder,
  bulk email, task manager, meeting scheduler, internal-notes tab,
  reactions popover, mention dialog — all the universal composer with
  different receiver+tag combos.
- **No "channel members" table.** Members are subscribers; tag IS membership.
- **No "team" entity.** Team = `sub:team:<x>` subscribers.
- **No "ticket" entity.** Ticket = signal with `kind:ticket` + SLA tags.
- **No "deal" entity.** Deal = `thing:offer` linked to actor.
- **No "owner" table.** Owner = `owner:<actor>` tag on entity.
- **No "automation engine."** Templates + journey runtime + tag
  subscriptions cover every automation.
- **No "lens" surface.** Lens = subscription pack; switching = re-applying.
- **No "split" component.** Splits are channel/tag rail rows.
- **No "DM" surface separate from actor view.** DM = direct signal.
- **No saved-view storage outside the URL.** Stars on a list URL
  become tags (`sub:<url>`) → new `/t/[tag]` row — even your bookmarks
  are subscriptions.
- **No pipeline kanban app.** `/people?view=pipeline&group_by=lifecycle`
  renders columns inside the existing list column.
- **No mouse-only fast path.** Every action has a key under 100 ms.

---

## 18. Build order — 12 quick wins + 15 cycles

The substrate provides 80%. The shell at `/in` ships now. **Phase 1**
is 12 focused edits on the components that already ship (~7 hours).
**Phase 2** is 15 cycles for the deeper work. Full breakdown in
[`crm-todo.md`](crm-done.md).

### Phase 1 — Quick Wins on `/in` (≈7 hours, parallel)

Each is a single component edit, independently shippable. None
scaffold new routes; all evolve `Inbox.tsx`, `Navigation.tsx`, or
`EntityDetail.tsx` in place.

| QW | Ships | Effort |
| --- | --- | --- |
| **QW1** | Rail zones (rename Navigation rows into MAIL · WORK · CHANNELS · TAGS · LEARNING) | ≤30 min |
| **QW2** | Mail-state splits — Drafts + Sent rows | ≤45 min |
| **QW3** | Work modules — Tasks · Calendar · Payments rows | ≤45 min |
| **QW4** | `+ New` button in column header | ≤30 min |
| **QW5** | Hero CTA pill (per preset) | ≤30 min |
| **QW6** | Top-bar redesign in EntityDetail (back link · status chip · primary action) | ≤45 min |
| **QW7** | Profile completion bar | ≤20 min |
| **QW8** | Detail-pane tabs (Overview/Personal/Pro/Social/AI Context/Network) | ≤60 min |
| **QW9** | Stat tiles 2-up grid | ≤30 min |
| **QW10** | Chat-thread message variants (bubbles · system pills · attachment chips) | ≤45 min |
| **QW11** | Frontier + Discovered permanent rail rows | ≤30 min |
| **QW12** | Group dropdown at top of rail | ≤45 min |

### Phase 2 — Cycles (15)

| Cycle | Ships |
| --- | --- |
| **CS** | Status semantics — per-dimension tag-rule assignment + thresholds |
| **CV** | Entity detail-pane inline-edit + same-as merge (extends QW6–QW10) |
| **CTagMgr** | Workspace tag taxonomy — namespace registry + ACL + colour + claw suggestions |
| **CComp** | Universal composer — receiver picker (direct/world/all/sub) + tag picker + body + schedule + holdout + gate |
| **CTpl** | Signal templates — table-of-templates UI; 30 starters per role |
| **CK** | Keyboard contract — `⌘1…⌘N` preset jumps · `⌘K` spotlight · 30 shortcuts · `?` overlay |
| **CPerf** | <100 ms per-action + <200 ms preset-switch budget |
| **CMcpInbox** | `@oneie/mcp` `inbox_*` tools — 9 verbs |
| **CJ** | Journey runtime — DAG editor + path executor for sequence-template chains |
| **CP** | Pulse atlas — 4-tier KPI ladder + funnel + attribution + holdout + frontier |
| **CSP** | Settings hub — `/settings/{packs,templates,tags,status,channels,integrations,privacy}` |
| **CX** | Importers + exporters (google/tiktok/klaviyo/salesforce/hubspot/ghl + clearbit/apollo/stripe/shopify/ga4) |
| **CH** | HubSpot/Salesforce write-through agents |
| **W7** | Identity rungs 2–5 + `same-as` merge |
| **W11** | PII vault + `/api/forget` cascade + `pii.read` audit |

**Critical path after QW1–QW12 land:** CS · CV · CTagMgr · CComp ·
CTpl · CK · CPerf = 7 cycles. The rest layer integrations, privacy,
identity, and external surface.

---

## 19. One-line summary

> The CRM is tags + subscriptions + pheromone. The UI is three
> columns. Apple built the contacts pane; Discord built the channel
> sidebar; Superhuman put the keyboard on every action; the
> substrate already runs the brain. Power through simplicity.

---

*Built on [`one/signals.md`](../plans/signals.md) (the contract — subscriptions are tags),
[`web/crm-pages.md`](crm-pages.md) (the visual spec — every screen drawn),
[`web/crm-todo.md`](crm-done.md) (the build order — 12 QWs + 15 cycles),
shell at [`web/src/pages/in.astro`](src/pages/in.astro) + [`web/src/pages/in/[groupId].astro`](src/pages/in/%5BgroupId%5D.astro) (shipping),
components at [`web/src/components/in/`](src/components/in/),
types at [`web/src/data/in-types.ts`](src/data/in-types.ts),
[`one/marketing-ontology.md`](../plans/marketing-ontology.md) (attributes),
[`web/campaigns.md`](campaigns.md) (the marketing-campaigns chapter — programs, not pages),
[`web/tracking.md`](tracking.md) (wire format),
[`web/agent-analytics.md`](agent-analytics.md) (KPIs),
[`web/roles.md`](roles.md) (cascade),
[`one/one-ontology.md`](../plans/one-ontology.md) (dimensions),
[`one/dictionary.md`](../plans/dictionary.md) (names),
[`text/12-crm.md`](../text/12-crm.md) (voice + worked example).
No new entities. No new tables. No new routes. Each rail row sets URL
state on the existing shell; the substrate runs the CRM.*
