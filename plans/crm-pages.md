# crm-pages.md — the CRM in pictures

Companion to [`crm.md`](crm.md). The CRM is **one shell, three URL
scopes**, all rendering `<Inbox>`:
- [`/in`](src/pages/in.astro) — operator (global, shipped)
- [`/in/[groupId]`](src/pages/in/%5BgroupId%5D.astro) — agency
  (workspace, shipped)
- `/u/[slug]/in` — client (per-workspace, QW13)

Every "page" below is a URL state of that one shell — the rail's rows
are **presets** (`?preset=<id>`), not separate Astro routes. Within-
preset state — focus, status, sort, view-mode, filter — also lives in
query params.

**Signals flow in from**: chat at `/u/[slug]/chat`, every channel
adapter (Telegram · Discord · Email · SMS · Web · Voice — all
brokered by claw), and tracked-link events per
[`tracking.md`](tracking.md). All write to one store
(`agent_events` D1 + substrate signals + TypeDB) keyed by slug. The
CRM reads from that store, scoped by the URL.

Built on the 6-token design system ([`design.md`](../design.md)) —
`background` = card, `foreground` = content, `primary/secondary/tertiary`
= brand, `font/60` = muted.

**Distinct from `/u/[slug]/*`.** The slug-rooted routes
(`/u/[slug]/chat`, `/people`, `/analytics`, `/agents/[id]/...`,
`/skills/*`, `/settings`, `/billing`) are **per-agent surfaces** —
each agent has its own pages. The CRM admin works inside `/in`. Both
read the same substrate; neither replaces the other.

**Reference points.** Apple Mail for the rail mail-metaphor, three-
column shell, list density, slide-up reply, space-peek, ⌘-everything.
Apple Contacts for the detail pane: stacked typed sections, label
namespaces, linked cards for merges, edit-in-place. Discord for
admin-curated channels. Substrate ([`one/signals.md`](../plans/signals.md))
for what flows: subscriptions are tags, status is computed, every
action closes its loop.

**Speed targets** — every interaction hits one of these or it doesn't
ship:

| Target | Time |
| --- | --- |
| keystroke → result on screen | < 50 ms |
| ⌘K → action committed | < 1 s |
| filter change → live count | < 200 ms |
| broadcast 10k actors → all queued | < 30 s |
| tracked link redirect | < 50 ms |
| `?focus=<id>` → detail rendered | < 100 ms (D1 hot path) |
| status tab switch | < 16 ms (in-memory filter, no fetch) |
| preset switch | < 200 ms (in-memory swap, no full reload) |

Source code lives in
[`web/src/pages/in/[groupId].astro`](src/pages/in/%5BgroupId%5D.astro) and
[`web/src/components/in/`](src/components/in/). Today's three-column
shell is already shipping — the work in this doc is the 12 quick wins
+ 15 cycles in [`crm-todo.md`](crm-done.md) that harden every section
into Apple-grade.

---

## 0. The shell — group · rail · list · detail

Three columns plus a 220px left rail with persistent chrome. Group
dropdown on top, five sidebar zones below it (Mail · Work · Channels ·
Tags + Learning · user card). The middle column lists the focused
preset. The right pane is detail + composer.

URL pattern at every breakpoint:

```
                       https://one.ie/in/w4fx1ev7?preset=inbox&s=now&sort=ltv:desc&focus=ada
                                      └──┬──┘ └─┬─┘ └────────── within-preset state ─────────┘
                                       shell  group        (no path segments past groupId)
```

```
┌─────────────────────┬─────────────────────────┬────────────────────────────┐
│ [Personal · grp ▾] │ ▣ Inbox          + New │ ← Back to Inbox            │
│ ─────────────────── ├─────────────────────────┤  ⊙ Tony O'Connell     ★ ⋯ │
│ MAIL                │ 🔍 Search…              │     Platform User          │
│ ┃📥 Inbox      42  │                          │     ● 0% complete  💬 Msg │
│  📝 Drafts      3  │ ┃NOW  TOP  TODO  DONE   │  ────────────────────────  │
│  📤 Sent           │ ──────────────────────  │  Profile Completion   0% │
│ ─────────────────── │  ▌ Ada Lovelace    2m  │  ─────────────────────    │
│ WORK                │   "MCP server?"         │  Overview · Personal ·   │
│  ✓ Tasks       12  │   ●●●●○ #vip            │  Professional · Social · │
│  📅 Calendar    5  │  ─────────────────────  │  AI Context · ┃Network   │
│  💳 Payments    8  │   Brad Pinto      12m  │  ────────────────────────  │
│  👥 People     40  │   "yearly invoice Q3?" │  ┌──────────────────────┐ │
│  🤖 Agents      6  │   ●●●○○                 │  │ Network & Activity   │ │
│  📊 Analytics      │  ─────────────────────  │  │                      │ │
│ ─────────────────── │   Cathy Min       18m  │  │  ┌─────┐  ┌─────┐    │ │
│ CHANNELS        +  │   "stuck on auth"       │  │  │  0  │  │  0  │    │ │
│  # leads       14  │   ●●○○○                 │  │  │Refs │  │Convs│    │ │
│  # cs-team      8  │  ─────────────────────  │  │  └─────┘  └─────┘    │ │
│  # vip          5  │   Dion Park       24m  │  │                      │ │
│  # apr-q2      47  │   "demo request"        │  │  Member Since        │ │
│ ─────────────────── │   ⋮ 38 more             │  │  📅 May 7, 2025       │ │
│ TAGS               │                          │  └──────────────────────┘ │
│  lifecycle:sql  7  │                          │                            │
│  owner:me      23  │                          │                            │
│  @mention       3  │                          │                            │
│  trial-d7-eu  412  │                          │                            │
│  ─── fading ───    │                          │                            │
│  trial-d14      ·  │                          │                            │
│  ─── learning ──   │                          │                            │
│  💡 discovered 12  │                          │                            │
│  🔬 frontier   47  │                          │                            │
│ ─────────────────── │                          │                            │
│ ⊙ L · Loading…  ⋯  │                          │                            │
│   dyl@one.ie       │                          │                            │
└─────────────────────┴─────────────────────────┴────────────────────────────┘
       220px                     340px                       flex
```

**Rail chrome (always visible)**

| Zone | Contents | Maps to |
| --- | --- | --- |
| Top | groups dropdown — workspace + group picker | switches `groupId` (full reload, only point in the shell that does) |
| MAIL | Inbox · Drafts · Sent | `?preset=inbox\|drafts\|sent` (in-memory swap) |
| WORK | Tasks · Calendar · Payments · People · Agents · Analytics | `?preset=tasks\|calendar\|payments\|people\|agents\|analytics` |
| CHANNELS | admin-curated subscriptions | `?preset=channel:<slug>` |
| TAGS | every other tag, ranked by pheromone; learning pair (💡 Discovered, 🔬 Frontier) pinned at the tail | `?preset=tag:<tag>` · `?preset=learning:discovered\|frontier` |
| Bottom | user card — presence dot · email · `⋯` menu | menu opens to `/settings` |

**Keys, every screen** — `⌘K` spotlight · `⌘L` switch lens · `/` focus
search · `j/k` next/prev row · `␣` peek without committing focus · `e`
edit · `m` message · `c` claim · `t` add tag · `r` react · `.` row
action menu · `[` `]` collapse/expand rail · `⌘\` toggle rail.
**No mouse-only fast path.**

---

## 1. The omnibar — ⌘K is the navigation

Floating overlay (44px input + dropdown). Reads the URL; mutating it
changes the visible state. Fuzzy across presets, channels, tags,
entities, templates, verbs. Same overlay on every preset.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  ⌘K   message ada                                          Esc          │
│  ────────────────────────────────────────────────────────────────────    │
│  ▶ message       Ada Lovelace             ↵ open composer               │
│    open actor    Ada Lovelace             ↵ → ?preset=people&focus=ada  │
│    enrol         Ada → trial-rescue       ↵                              │
│    tag           Ada + #vip               ↵                              │
│    channel       create # ada-followers   ↵                              │
│  ─ recent ─────────────────────────────────────────────────────────       │
│    Brad Pinto · Cathy Min · Dion Park · # leads · trial-rescue           │
│  ─ verbs ──────────────────────────────────────────────────────────       │
│    /sub  /unsub  /mark  /warn  /forget  /merge  /export  /import         │
│    /template  /journey  /broadcast  /pulse  /settings                    │
└──────────────────────────────────────────────────────────────────────────┘
```

Natural-language end-to-end (claw routes the parse):

- `message ada about MCP` → composer opens, `to: ada`, channel auto-picked
- `subscribe trials in EU` → new admin channel proposal
- `enrol # vip in trial-rescue` → confirm modal, run
- `export # vip to meta` → 1-tap audience sync
- `/forget ada@l.org` → privacy cascade with receipt

Claw shows the substrate signals it's about to emit before it commits.

---

## 2. The rail — group · mail · work · channels · tags · user

220px, fixed. Six stacked zones.

### 2.1 Group dropdown (top)

```
┌────────────────────────────────┐
│  Personal · group:dental    ▾ │
└────────────────────────────────┘
```

One control, two scopes — top label is the **workspace** (Personal /
Team / Agency / Client per [`web/roles.md`](roles.md)); sub-label is
the **group** within that workspace. Each workspace × group has a
unique short groupId. Click opens:

```
┌────────────────────────────────┐
│ WORKSPACES                     │
│  ⦿ Personal       (current)    │
│  ⦿ ONE Team                    │
│  ⦿ Dental Co. (agency)         │
│  + Create workspace            │
│ ──────────────────             │
│ GROUPS in Personal             │
│   w4fx1ev7  group:dental (current) │
│   8nq2k9p3  group:hn-launch    │
│   3zt7m6b1  group:fam          │
│   + New group                  │
└────────────────────────────────┘
```

Picking a row navigates to `/in/<new-groupId>` (full reload). All
other rail interactions stay within the same shell via URL state.

### 2.2 MAIL — events split by state

The mail metaphor every CRM user already understands. Three presets,
all on the events dimension, split by tag-state.

| Preset | URL state | What it shows |
| --- | --- | --- |
| 📥 **Inbox** | `?preset=inbox` (default) | inbound signals not yet closed |
| 📝 **Drafts** | `?preset=drafts` | composed but unsent (auto-saved on `⌘D`) |
| 📤 **Sent** | `?preset=sent` | what I authored, read-only |

Visiting `/in/[groupId]` with no params lands on Inbox.

### 2.3 WORK — the six modules

The CRM's core nouns + analytics. Each preset pre-filters the
substrate by `kind:*` (events) or `kind:*` (actors).

| Preset | URL state | Substrate filter |
| --- | --- | --- |
| ✓ **Tasks** | `?preset=tasks` | events `kind:task` |
| 📅 **Calendar** | `?preset=calendar&group_by=date` | events `kind:meeting` |
| 💳 **Payments** | `?preset=payments` | events `kind:payment` |
| 👥 **People** | `?preset=people` | actors `kind:human` |
| 🤖 **Agents** | `?preset=agents` | actors `kind:agent` |
| 📊 **Analytics** | `?preset=analytics` | pulse KPI atlas |

People and Agents are peers, not parent/child. Agents are first-class
collaborators — the rail reflects that.

### 2.4 CHANNELS — admin-curated subscriptions

Channels are named subscriptions composed of one or more tags
([`crm.md`](crm.md) §7). Each channel is a preset at
`?preset=channel:<slug>`. Admin authors the row at
`/settings/channels`:

```
┌── New channel ────────────────────────────┐
│ name      apr-q2-launch                   │
│ slug      apr-q2-launch                    │
│ emoji     ✨                                │
│ colour    primary                          │
│ tags      campaign:apr-q2 · status:running│
│ ACL       readers: workspace               │
│           writers: marketer pack           │
│ ────────────────────────────              │
│                       Cancel    Create     │
└────────────────────────────────────────────┘
```

Members are subscribers (humans **and** agents). Pheromone determines
unread weight.

| Channel row | What it shows |
| --- | --- |
| icon + name | `# leads`, `# cs-team`, `# vip`, `# apr-q2` |
| right-aligned badge | unread count (live SSE from claw) |
| dot prefix | colour from admin config |
| hover | description + tag definition |

Click → list column filters to that channel's tags; hero CTA flips
to `⌁ Broadcast` (composer opens with `to: sub:<channel-tag>`).

`+` next to CHANNELS — admin-only — opens the create modal.

### 2.5 TAGS — pheromone-ranked long tail

Every other tag the substrate has accumulated, ranked by engagement.
Each tag row is a preset at `?preset=tag:<tag>`.

```
TAGS
  lifecycle:sql      7
  owner:me          23
  @mention           3
  trial-d7-eu      412
  ─── fading ───
  trial-d14          ·
  ─── learning ──
  💡 discovered     12    ← always second-to-last, never fades
  🔬 frontier       47    ← always last, never fades
```

`★` next to a row promotes it: admin sees a "Promote to channel"
suggestion in their notifications.

**The learning pair (pinned tail).** Two permanent presets surfacing
the two slowest loops:

- `?preset=learning:discovered` — **💡 Discovered (L6 KNOWLEDGE).**
  Hardened highways — paths the substrate has marked with enough
  successful traversals to crystallise into a hypothesis. Each row is
  a *candidate journey* ready for one-click materialisation. Hovering
  shows lift and proposed sequence.
- `?preset=learning:frontier` — **🔬 Frontier (L7 FRONTIER).**
  Unexplored tag clusters. Each row is a *candidate experiment* with
  expected value. Hovering suggests the experiment to run.

Both never fade. Together they are how the substrate offers what to
ship next and what to learn next.

### 2.6 User card (bottom)

```
┌────────────────────┐
│ ⊙  Loading…    ⋯  │   ← presence + status
│    dyl@one.ie      │
└────────────────────┘
```

`⋯` opens: profile · preferences · keyboard help (`?`) · settings
(`⌘,` → `/settings`) · sign out. Presence dot: online (`success`) ·
away (`tertiary`) · offline (`muted`).

---

## 3. The list column — header · search · hero CTA · status · rows

340px. Four stacked zones above the row list. No smart-mailboxes fold
inside the list — the rail's Channels and Tags own that role.

```
┌─────────────────────────────────────┐
│ ▣  Inbox                 + New     │   ← 44px column header
├─────────────────────────────────────┤
│ 🔍 Search inbox…                   │   ← 36px scoped search
├─────────────────────────────────────┤
│      ⌁ Broadcast                    │   ← contextual hero CTA
├─────────────────────────────────────┤
│ ┃ NOW  TOP  TODO  DONE  View: ⊟▦📅 │   ← status tabs + view toggle
├─────────────────────────────────────┤
│ ▌ Ada Lovelace        2m            │   ← rows (density per preset)
│   "MCP server?"   ●●●●○ #vip       │
│ ─────────────────────────────────── │
│   Brad Pinto         12m            │
│   "yearly invoice Q3?"   ●●●○○      │
│   ⋮                                  │
└─────────────────────────────────────┘
```

### 3.1 Column header

`▣` collapse-rail toggle · preset title (16px semibold) · blue `+ New`
button right-aligned. The `+ New` action is contextual per preset:

| Preset | `+ New` does |
| --- | --- |
| inbox | new conversation, composer slides up |
| drafts | composer opens with `state:draft` seeded |
| sent | (hidden — Sent is read-only) |
| tasks | universal composer with `kind:task` + remind-at picker |
| calendar | composer with `kind:meeting` + slot picker |
| payments | invoice/charge composer |
| people | add-person modal (name + email + tag) |
| agents | agent template gallery |
| analytics | (hidden — dashboard view) |
| channel:* | composer with `to: sub:<channel-tag>` |
| tag:* | composer with that tag pre-seeded |

### 3.2 Search

Per-preset scoped (omnibar handles cross-preset search). Filters in
<16 ms; supports `key:value` and `#tag` (full grammar in §6.4). `⌥/`
focuses here from anywhere.

### 3.3 Hero CTA

One contextual primary-tinted pill below search.

| Preset | Hero CTA |
| --- | --- |
| inbox | (hidden — already lists what matters) |
| drafts | + New Draft |
| sent | (hidden) |
| tasks | + New Task |
| calendar | + New Event |
| payments | + Send Invoice |
| people | ✨ Invite · 📥 Import (CSV / HubSpot / Salesforce / GHL) |
| agents | ⌬ Spawn Agent |
| analytics | (hidden — full atlas in detail) |
| channel:* | ⌁ Broadcast |
| tag:* | ⌁ Broadcast to tag |
| learning:discovered | 🚀 Materialise as Journey |
| learning:frontier | 🧪 Run Experiment |

Owner can edit at `/settings/list-ctas`.

### 3.4 Status tabs

`NOW · TOP · TODO · DONE` with live counts. Computed per [`crm.md`](crm.md)
§3 and shipping in
[`StatusTabs.tsx`](src/components/in/StatusTabs.tsx). Tab switch
<16 ms (in-memory, no fetch). URL: `?s=now|top|todo|done`. Hidden on
`analytics` (no list) and `tag:*` (filter is the tag).

### 3.4a View-mode toggle

A small segmented control right of the status tabs. Same column,
different rendering. URL: `?view=list|pipeline|kanban|calendar|map|funnel`.

| View | What it does |
| --- | --- |
| ⊟ List | virtualised rows, density per preset (default) |
| ▦ Pipeline | kanban columns by stage (`?view=pipeline&group_by=lifecycle`); drag-to-stage logs override signal |
| ▦ Kanban | columns by NOW/TOP/TODO/DONE (Tasks variant) |
| 📅 Calendar | week strip + day cells (Calendar default; available on Tasks) |
| 🗺 Map | actors plotted by location (People only) |
| 📊 Funnel | volumetric funnel with stage CVRs (Analytics) |

Modes available per preset:

| Preset | Modes |
| --- | --- |
| inbox / drafts / sent | List |
| tasks | List · Kanban · Calendar |
| calendar | Calendar · List |
| payments | List · Funnel (by status) |
| **people** | **List · Pipeline · Map** |
| agents | List |
| channel:* / tag:* | List |

The Pipeline view on `people` is what crm.md §17 calls
`?view=pipeline&group_by=lifecycle` — "what looks like a Kanban board
is pheromone." Drag-to-stage writes an `actor:lifecycle.update`
signal; the override rule logs on the actor record per
[`12-crm.md`](../text/12-crm.md) §Stage-transitions.

### 3.5 Row density per preset

Density follows the preset meaning.

**`people` and `agents` (Apple Contacts density, ~56px row)** —
avatar (40px circle) · name (13px semibold) · subtitle one line muted.
Initials fallback or `?` for unresolved. Pheromone dots `●●●●○` when
substrate has data.

```
◯ D   Dylan
◯ M   ME
◯ ⊙   Tony O'Connell
◯ ?   Unknown                   ← stub row (signal arrived, enrichment pending)
```

**`inbox` `drafts` `sent` `tasks` `channel:*` `tag:*` (Apple Mail
density, ~64px row)** — sender · time right · one-line preview · tag
pill row · pheromone dots when present.

```
▌ Ada Lovelace        2m
  "MCP server?"   ●●●●○ #vip
```

**`calendar` (week strip + day rows, ~80px row)** — date · title ·
time-of-day · attendees. Jump to today with `t`.

**`payments` (table-like, ~48px row)** — amount (mono, tabular) ·
status chip · counterparty · date.

**`analytics` (no list)** — the entire flex column is the atlas.

All rows share: unread dot left (4px primary) · selected state
`primary/12` bg · 2px primary left bar.

### 3.6 Stub rows

Unresolved actors render with `?` avatar and "Unknown" label — a
load-bearing pattern. Every interaction creates a stub immediately so
the list never blocks on enrichment. Clicking opens the detail with
`Profile Completion 0%` and the enrichment picker (§4.2).

---

## 4. The detail pane — top bar · tabs · sections · dimension-aware

The flex right column. Universal top bar (back · identity · status ·
action). Tabs route between namespace groupings. Body is dimension-
aware: **stacked Apple-Contacts sections** for actors, **threaded
messages** for events, **DAG** for paths, **KPI atlas** for analytics.

Per-entity detail is captured as URL state: `?focus=<entity-id>` on
the appropriate preset (`?preset=people&focus=ada-lovelace`,
`?preset=tasks&focus=<task-id>`). The right pane swaps body content
by entity kind; the URL captures everything needed to share or
reload.

### 4.1 Top bar (universal)

```
┌──────────────────────────────────────────────────────────────────────┐
│ ← Back to People    ⊙  Tony O'Connell           ● 0% complete 💬 Msg│
│                          Platform User                               │
└──────────────────────────────────────────────────────────────────────┘
```

Left: `← Back to <preset>` — clears `focus` from the URL. Centre: 32px
icon-avatar + name (15px semibold) + role/subtitle (12px muted)
stacked. Right: status chip + primary action.

**Status chip** — coloured dot + label:

- `● 0% complete` — sparse profile (destructive dot)
- `● online` — actor presence (success dot)
- `● running 412` — journey active (success dot)
- `● sla:red` — escalation (destructive dot)
- `● paid £79` — payment status (success dot)
- `● fading` — pheromone L3 decay (muted dot)

**Primary action** — outlined button with icon:

| Detail of | Primary action |
| --- | --- |
| Person | 💬 Message |
| Agent | ⌬ Chat |
| Conversation | ↵ Reply |
| Task | ✓ Complete |
| Meeting | 📅 Join |
| Payment | 💳 View Receipt |
| Channel | ⌁ Broadcast |
| Path / journey | ▶ Run |
| Frontier idea | 🧪 Experiment |
| Discovered highway | 🚀 Materialise |

### 4.2 Profile completion bar (optional)

Renders only when applicable — actors with sparse data, agents mid-
setup, things missing pricing. Thin progress bar + percentage:

```
Profile Completion ──────────────────────────────  0%
```

Click → enrichment picker (email · phone · social · stripe · clearbit).
Hides at 100%. Owner toggles at `/settings/profile-completion`.

### 4.3 Tabs (namespace router)

Tabs partition the entity's tag namespaces. Active tab = dark-filled
pill. URL: `?tab=<name>`. Owner can re-order or rename at
`/settings/detail-tabs`.

| Dimension / kind | Tabs |
| --- | --- |
| **actors:human** | Overview · Personal · Professional · Social · AI Context · Network |
| **actors:agent** | Overview · Capabilities · Skills · Channels · Audit |
| **events:reply** | Thread · Reactions · Tags · Replies · Audit |
| **events:task** | Detail · Subtasks · Activity · Audit |
| **events:meeting** | Detail · Attendees · Resources · Activity |
| **events:payment** | Detail · Items · Receipt · Refunds · Audit |
| **paths** | Diagram · Steps · KPIs · Cohort · Audit |
| **groups** | Members · Roles · Tags · Activity · Settings |
| **learning** | Hypothesis · Evidence · Experiments · Decision |

### 4.4 Stacked sections — Apple Contacts (the Overview tab)

```
── consent ──────────────────────────────────  edit
   ▣ email  ▣ telegram  ▣ sms  ◯ push
   gdpr ✓ · ccpa ✓ · gpc honoured

── channels ─────────────────────────────────  edit
   ✉ ada@l.org              ★ best · 0.81
   ⊙ @ada (telegram)         · 0.74
   ⌬ ada#1820 (discord)       · 0.41

── identity   3 merges ──────────────────────  edit
   ada@l.org                ← primary
   visitor_hash 4ab…        · merged 2026-04-02 · 0.97
   ada@engine.co            · merged 2026-04-18 · 0.91

── appended ─────────────────────────────────
   clearbit: CTO · 12 emp · YC W22
   stripe:   cus_… · MRR £79
   manual:   "intro from HN, July"          ← wins on display

── paths ────────────────────────────────────
   hn (0.40) → trial (0.40) → /pricing (0.20) → purchase
```

Apple Contacts moves we copy: **click-any-field edit-in-place** (no
edit toggle); **linked cards** for `same-as` merges with a split
button on hover; **manual overrides win on display**.

### 4.5 Stat tiles (Network tab, Analytics atlas, journey detail)

2-up grid inside a section card. Big number + small label:

```
┌──────────────────────────────────┐
│ Network & Activity                │
│  ┌────────┐  ┌────────┐          │
│  │   0    │  │   0    │          │
│  │Refrls  │  │Convos  │          │
│  └────────┘  └────────┘          │
│  Member Since                     │
│  📅 May 7, 2025                    │
└──────────────────────────────────┘
```

Click any tile → opens list filtered to that slice (Referrals →
`?preset=people&filter=referred-by:<id>`).

### 4.6 Events variant — chat thread

When the focused entity is a conversation, the body becomes a
threaded message view.

```
─── New Conversation ⚙ ─────────────────── ◐ Tony · 🤖 Director ──
                                                ┌─────────────────────────────────────┐
                                                │ browse the web and tell me the      │   ← user bubble (right)
                                                │ weather today in chiangmai          │   primary bg
                                                │ 11 months ago                  ⊙   │
                                                └─────────────────────────────────────┘

         ⓘ 👋 Director has joined the conversation. 11 months ago             ← system pill

┌──┐  Director
│🤖│  ┌─────────────────────────────────────────────────────────────────────────┐
└──┘  │ I currently don't have the capability to browse the web…              │   ← agent bubble (left)
      │ 11 months ago                                                          │
      └─────────────────────────────────────────────────────────────────────────┘

                                                ┌─────────────────────────────────────┐
                                                │ @Tony O'Connell h                   │   ← @-mention chip
                                                │ 11 months ago                  ⊙   │
                                                └─────────────────────────────────────┘

┌──┐  Director
│🤖│  🖼 Unknown Agent  The user is trying to get a response from you.                ← attachment chip
└──┘  11 months ago                                Please respond to them.
```

Patterns — **user bubble** right (`primary` bg) · **agent bubble** left
(`foreground` bg, author name above) · **system pill** centred (muted)
· **attachment chip** inline · **@-mention** autolinked chip ·
**stacked participant avatars** in top bar.

### 4.7 Paths variant

When `?preset=tasks&focus=<journey-id>&view=diagram`, the body is the
journey DAG (§6.6).

### 4.8 Analytics variant

`?preset=analytics` — the body is the KPI atlas (§6.5).

---

## 5. The composer — chat flavour and universal flavour, one toolbar

The composer is the bottom-of-detail input. Two flavours, one shared
toolbar (matching the prototype's
`+ Add · 📎 Attach · 🔍 Search · model · ➤ Send`).

### 5.1 Shared toolbar

```
┌──────────────────────────────────────────────────────────────────────┐
│ [ + Add ]  [ 📎 Attach ]  [ 🔍 Search ]    Gemini 2.5 Flash ▾  ➤ Send│
└──────────────────────────────────────────────────────────────────────┘
```

| Affordance | What |
| --- | --- |
| `+ Add` | insert template / `/cmd` palette / structured block |
| `📎 Attach` | file picker (lazy-loaded — see `.claude/rules/astro.md`) |
| `🔍 Search` | inline knowledge search; results paste as citation chips |
| Model picker | LLM for chat flavour; hidden in universal flavour |
| `➤ Send` | primary action; disabled until body has content and gate is green |

Typing `/` in the body opens the same template/cmd picker as `+ Add`.

### 5.2 Chat flavour (inbox · drafts · channel · tag presets)

Single textarea, hint-rich placeholder. No receiver picker — thread or
channel implies receiver.

```
┌──────────────────────────────────────────────────────────────────────┐
│ Type a message… Use @ to mention, + to invite                       │
└──────────────────────────────────────────────────────────────────────┘
[ + Add ]  [ 📎 Attach ]  [ 🔍 Search ]    Gemini 2.5 Flash ▾  ➤ Send
```

Keys: `⌘↵` send · `⌘⇧↵` schedule · `Esc` collapse · `Shift+↵` newline.

### 5.3 Universal flavour (broadcast · task · meeting · sequence)

Adds receiver picker, tag pill row, schedule, holdout, and the gate
panel for `to: sub:*` broadcasts (per [`crm.md`](crm.md) §4).

```
┌──────────────────────────────────────────────────────────────────────┐
│ to:  ◉ direct  ○ world  ○ all  ○ subscribe       ada (tg · 0.74) ▾  │
│ tags: public · campaign:apr-q2 · channel:auto              + tag    │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ Hi @ada, here's the hygienist info you asked about…              │ │
│ │ /go book → https://one.ie/go/4xZ                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
│ schedule:  ◉ now  ○ at  ○ path           holdout: 0% ▾              │
│ ── gate ─────────────────────────────────────────────                │
│   consent     ✓ 412/412    cap        ✓ ok                          │
│   suppression ✓ 0           compliance ✓ ok                          │
└──────────────────────────────────────────────────────────────────────┘
[ + Add ]  [ 📎 Attach ]  [ 🔍 Search ]                       ➤ Send 371
```

Gate row only renders when `to: sub:*`. Send button shows resolved
recipient count — no surprises.

### 5.4 Channel auto-pick (universal · direct mode)

When `to: direct`, composer reads the actor's strongest channel and
shows it inline (`ada (tg · best 0.74)`). One-key swap: `⌘1/2/3` cycles
email/telegram/discord/sms.

---

## 6. Presets — the URL-state table

The "pages" of the old draft are presets on the `/in/[groupId]`
shell. No new routes; the shell composes them.

### 6.1 Inbox — `?preset=inbox`

```
/in/[groupId]?preset=inbox&s=now&sort=ltv:desc
```

**Default landing** (no params → inbox). Inbound signals where the
loop isn't closed. Replying = `emit + mark(edge)` — closes the loop
([`one/signals.md`](../plans/signals.md)). Claw drafts a suggested reply
on rows that need a human; `↵` accepts, `e` opens in composer.

**Sort order.** Default `sort=ltv:desc` — high-LTV escalations float
to the top per [`12-crm.md`](../text/12-crm.md) §Handoff. Other sorts:
`recency`, `confidence:asc`, `sla:red-first`. Sort picker right of the
view-mode toggle.

Drafts (`?preset=drafts`) and Sent (`?preset=sent`) are sibling
presets — same shell, different filter and read-only flag.

### 6.2 People — `?preset=people`

Apple Contacts row density. Detail at `?preset=people&focus=<actorId>`
with stacked sections (Overview tab) or namespace tabs. Default preset
for the People row.

### 6.3 Agents — `?preset=agents`

Same shell as People. Detail tabs swap to **Overview · Capabilities ·
Skills · Channels · Audit**. (The per-agent `/u/[slug]/*` surfaces are
separate from this preset; this is the CRM admin's view of agents as
actors.)

### 6.4 Channel & Tag presets — `?preset=channel:*` and `?preset=tag:*`

```
?preset=channel:cs-team                # Channel: # cs-team
?preset=tag:lifecycle:sql               # Tag: lifecycle:sql
```

Channels (admin-curated, named, CHANNELS rail zone) and Tags
(pheromone-ranked, anonymous, TAGS rail zone) share the same view
shape: filtered list column + chat composer at the bottom of detail
(or universal flavour for broadcasts).

Hover any channel/tag row in the rail → distribution card:

```
┌── # apr-q2-launch  412 ●  ─────────────┐
│  persona  founder    62%                │
│            ic-dev     24%                │
│  channel  email      91%                 │
│            telegram   54%                 │
│  geo      US         48%                  │
│            EU         31%                  │
│                                          │
│  ⌁ broadcast (⌘B)   ⌬ save audience      │
│  ⎘ csv   ↑ export → meta                 │
└──────────────────────────────────────────┘
```

`⌘B` opens the universal composer with that subscription pre-loaded.

### 6.5 Analytics — `?preset=analytics`

KPI atlas. 4-tier ladder + funnel + attribution + holdout + frontier:

```
─── pulse · last 30d                workspace: w4fx1ev7 ────
  L1 activity     L2 output    L3 outcome   L4 impact
  ┌────────┐    ┌────────┐    ┌────────┐   ┌──────┐
  │ 41,202 │    │ 12,108 │    │  612   │   │ £48k │
  │signals │    │touches │    │convert │   │ rev  │
  │ +12% ▲ │    │ +9%  ▲ │    │ +18% ▲ │   │+22% ▲│
  └────────┘    └────────┘    └────────┘   └──────┘

  funnel                      identity
   anon ████ 38,210            resolution 96.4% ✓
   lead ██   14,402            consent    88.1%
   mql  █    5,820             attribution 84.2%
   sql  ▏    1,940             cap-hit      2.1%
   cust ▏      612

  attribution                  holdout
   hn-launch    38%             trial-res +18.7pp
   /pricing     27%             winback   +9.1pp
   E3-trial-d7  19%             ent-upg  +14.2pp

  frontier (unexplored)
   persona:devops · channel:slack · 47 actors
```

Click any tile → list filtered to that slice.

### 6.6 Journey — `?preset=tasks&focus=<journey-id>&view=diagram`

Journeys live inside Tasks (a running journey enrols actors into
tasks). The detail body swaps to DAG; edge weight is live pheromone.

```
┌── trial-rescue-d14    ● running 412 ──────────────────────┐
│  ┌─INVITE────┐      ┌─NUDGE────┐       ┌─CONV────┐        │
│  │ telegram   │0.62 │ email E3  │0.41   │ purchase │        │
│  │ 412 enter  │═══▶ │ 248 sent  │────▶ │  47 paid │        │
│  │ ●●●●●      │     │ ●●●○○     │       │ ●●○○○    │        │
│  └────────────┘     └──────────┘       └──────────┘        │
│        │                  │                                 │
│        └─drop 164─▶ REWARM (sms 48h, ●●○○○)                │
│                  └─drop 147─▶ SUPPRESS (4 unsub)            │
│                                                            │
│  KPIs ┃ entered 412 · cvr 11.4% · holdout +18.7pp ✓        │
└────────────────────────────────────────────────────────────┘
```

`e` on a node edits its template · `y` flips to YAML · `⌘.` dry-runs
on sample cohort.

### 6.7 Learning — `?preset=learning:discovered` and `?preset=learning:frontier`

Two presets for the L6/L7 surfaces:

- `?preset=learning:discovered` — L6 hardened highways with
  "🚀 Materialise" CTA per row
- `?preset=learning:frontier` — L7 unexplored clusters with
  "🧪 Experiment" CTA per row

### 6.8 Settings — `/settings/*`

Per crm.md §18. Settings is its own route tree (admin pages, not part
of the CRM's `/in` shell). Reached via user-card `⋯` menu or `⌘,`:

- `/settings` — index
- `/settings/channels` — channel taxonomy (name + tags + ACL + colour)
- `/settings/integrations` — importer + write-through agents (HubSpot · Salesforce · GoHighLevel · Klaviyo · Stripe · Shopify · Clearbit · Apollo · GA4 · Meta · Google · TikTok). Each row: connect / disconnect, last sync, signal count, field map preview
- `/settings/packs` — lens packs
- `/settings/templates` — signal templates
- `/settings/tags` — tag namespace registry
- `/settings/status` — per-dimension status rules
- `/settings/privacy` — collection mode + key custody + forget cascade
- `/settings/list-ctas` — `+ New` + hero-CTA per preset
- `/settings/detail-tabs` — tab order + naming per dimension
- `/settings/profile-completion` — toggle the profile bar per preset

---

## 7. Status semantics — the four tabs

Computed, not stored ([`crm.md`](crm.md) §3). Live counts on the tabs.
Defaults (excerpt):

| Dim | now | top | todo | done |
| --- | --- | --- | --- | --- |
| events | `receiver:human AND NOT mark` | `actor.ltv:gte:high` | `confidence:lt:0.65 OR compliance:flag` | `mark OR warn` |
| actors | `lifecycle in {lead, mql, sql}` | `ltv:gte:high OR fit:gte:0.85` | `consent:missing OR dormancy:warming` | `lifecycle in {customer, advocate, churned}` |
| paths | `traversals:gte:10 AND last-traversal:<7d` | `cvr:gte:p95` | `last-mark:age:>14d` | — |

Rules engine is the **CS** cycle.

---

## 8. Live everywhere

Six real-time signals on every preset — WebSocket fan-out from claw,
not polling.

| Signal | Where shown | Source |
| --- | --- | --- |
| activity blip | row dot, detail header, channel badge | signal stream SSE |
| sub count | channel badge, status tab, gate row | re-eval on signal append |
| pheromone bar | path nodes, actor dots, journey edges, tag ordering | TypeDB tick, 1s coalesced |
| presence | user-card dot, participant avatar ring | session SSE |
| profile completion | top-bar % bar | recomputed on enrichment |
| frontier count | 🔬 row badge | L7 loop tick (hourly) |

Rows update in place. Dot pulses primary for 400 ms, settles to muted.

---

## 9. Empty states

Per preset:

| Preset | Empty body |
| --- | --- |
| inbox | "All caught up." Zen state with a `Send a tracked link` hint below |
| drafts | "No drafts." `+ New Draft` button |
| sent | "Nothing sent yet." Hint to compose first message |
| tasks | "No tasks." `+ New Task` + 5 template suggestions |
| calendar | "No upcoming." `+ New Event` |
| payments | "No payments yet." `+ Set up Stripe` / `+ Set up Sui` |
| people | `+ Invite` modal pre-opened; below: connect channels · paste emails · send a tracked link |
| agents | "No agents yet" + ⌬ Spawn from template (5 starters) |
| analytics | "Send your first tracked link to see signals here." |
| channel:* | Admin only: "Create a channel to organise signals by tag." |
| tag:* | "Tags surface as the substrate accumulates them. Send a signal to seed." |

Stub rows ("? Unknown") are the visible-but-incomplete state — a
signal arrived but enrichment hasn't landed.

---

## 10. Mobile (≤640 px)

Single column. Rail collapses to a bottom tab bar (5 most-used presets
+ `⋯` overflow — typically Inbox · Tasks · People · Agents ·
Analytics). Compose and spotlight are FABs. List → detail uses pushed
sheets. Group dropdown moves into a top-left account menu; user-card
menu joins it.

```
┌──────────────────────────┐   ┌──────────────────────────┐
│ ⌘K  Inbox          ⚙    │   │ ← Ada Lovelace      ⋯   │
├──────────────────────────┤   ├──────────────────────────┤
│ 🔍 Search inbox…        │   │ ⊙ Ada Lovelace          │
│ ┃NOW  TOP  TODO  DONE   │   │   CTO · customer         │
│                          │   │ ● 0% complete  💬 Msg   │
│ ▌ Ada Lovelace      2m  │   │                          │
│   "MCP server?"          │   │ Profile ──────── 0%     │
│   ●●●●○                  │   │ Overview · Personal ·   │
│ ─────────────────────    │   │ Pro · Social · ┃Net    │
│   Brad Pinto       12m  │   │                          │
│   "yearly invoice Q3?"   │   │ ┌─ Network ─────────┐   │
│   ●●●○○                  │   │ │ ┌──┐  ┌──┐         │   │
│  ⋮                       │   │ │ │0 │  │0 │         │   │
│                          │   │ │ └──┘  └──┘         │   │
│                          │   │ │ Member · May 7    │   │
│                          │   │ └────────────────────┘  │
├──────────────────────────┤   ├──────────────────────────┤
│ 📥 ✓ 👥 🤖 📊      +   │   │ 📥 ✓ 👥 🤖 📊      + │
└──────────────────────────┘   └──────────────────────────┘
```

---

## 11. Keyboard reference

Every action under 100 ms. Single source for the `?` overlay.

**Jump to preset** (`⌘<n>` mutates URL state):

| Key | Preset |
| --- | --- |
| `⌘1` | inbox |
| `⌘2` | drafts |
| `⌘3` | sent |
| `⌘4` | tasks |
| `⌘5` | calendar |
| `⌘6` | payments |
| `⌘7` | people |
| `⌘8` | agents |
| `⌘9` | analytics |

Channels and Tags via `⌘K` or `g` + name.

**Global actions:**

| Key | Action |
| --- | --- |
| `⌘K` | spotlight |
| `⌘,` | `/settings` |
| `⌘L` | switch lens |
| `⌘B` | broadcast — composer with current channel/tag pre-loaded |
| `⌘\` | toggle rail |
| `⌘D` | save draft |
| `⌘S` | save current view as tag-subscription |
| `⌘.` | dry-run focused journey on sample cohort |
| `?` | shortcut overlay |

**Row navigation:**

| Key | Action |
| --- | --- |
| `j` `k` | next / prev row |
| `␣` | peek detail without committing focus |
| `↵` | open / accept suggested reply |
| `Esc` | collapse composer / clear search / back on mobile |
| `t` | jump Calendar to Today |

**Per-row actions:**

| Key | Action |
| --- | --- |
| `e` | edit focused field / template / status rule |
| `m` | message (open composer, `to: direct: <focused>`) |
| `c` | claim (`owner:me`) |
| `t` | add tag |
| `r` | react |
| `s` | snooze |
| `.` | row action menu (merge · suppress · forget · export · open chat) |

**Composer:**

| Key | Action |
| --- | --- |
| `⌘↵` | send |
| `⌘⇧↵` | schedule |
| `Shift+↵` | newline |
| `/` | template / cmd picker |
| `@` | mention picker |

---

## 12. The shell, in one paragraph

**One shipped shell** — `/in` + `/in/[groupId]`. **One rail** — groups
dropdown on top (switches `groupId`), five zones below it: Mail
(inbox / drafts / sent presets), Work (tasks / calendar / payments /
people / agents / analytics), Channels (admin-curated, one preset per
channel), Tags (pheromone-ranked, one preset per tag, with `💡
learning:discovered` + `🔬 learning:frontier` pinned at the tail),
user card on the bottom. **One list column** — `▣ collapse · title ·
+ New` header, search, contextual hero CTA, status tabs + view-mode
toggle, dimension-density rows. **One detail pane** — `← back ·
avatar · title · status chip · primary action` top bar, profile-
completion bar, namespace tabs, stacked Apple-Contacts sections in
Overview, chat thread for events, DAG for paths, KPI atlas for
analytics. **One composer** — two flavours (chat / universal) sharing
the `+ Add · 📎 Attach · 🔍 Search · model · ➤ Send` toolbar. **One
keyboard** — `⌘1…⌘9` for the nine fixed presets, ⌘K does anything
else, j/k walks, ␣ peeks, ⌘↵ ships. **Everything reads from the same
brain** — claw signals, TypeDB pheromone,
[`signals.md`](../plans/signals.md) subscriptions. The `/u/[slug]/*`
routes are per-agent surfaces, separate from the CRM admin shell.
Apple Mail gave us the mail metaphor. Apple Contacts gave us the
detail pane. Discord gave us channels. Superhuman put the keyboard on
every action. The substrate runs the brain. Power through simplicity.

---

*One shell. One rail. One list. One detail. One composer. One
keyboard. Grounded in
[`web/src/pages/in.astro`](src/pages/in.astro) +
[`web/src/pages/in/[groupId].astro`](src/pages/in/%5BgroupId%5D.astro)
+ [`web/src/components/in/`](src/components/in/), built on
[`crm.md`](crm.md), shipped via [`crm-todo.md`](crm-done.md) (12 QWs +
15 cycles), rendered with [`design.md`](../design.md) tokens, driven
by [`one/signals.md`](../plans/signals.md) subscriptions.*
