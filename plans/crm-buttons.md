# crm-buttons.md — the verbs

Apple Mail gave us the metaphor. Discord gave us channels. Superhuman put the keyboard on every action. The substrate runs the brain. This file is the **verb-to-endpoint contract** — every button on `/in`, what it does, how it talks to the substrate.

Companions:
- [`crm.md`](crm.md) — principles (tags + subscriptions + pheromone)
- [`crm-pages.md`](crm-pages.md) — visual layout (where you see things)
- [`crm-components.md`](crm-components.md) — implementation (which file)

**Reading guide.** Each row is tagged with its **QW#** (quick win) or **Cycle** code from [`crm.md §18`](crm.md). `QW1`-`QW12` are the 7-hour parallel ship. `QW13` = `/u/[slug]/in` client scope. Cycles: `CS` status · `CV` detail-pane · `CTagMgr` tags · `CComp` composer · `CTpl` templates · `CK` keyboard · `CPerf` perf · `CMcpInbox` MCP · `CJ` journey · `CP` pulse · `CSP` settings · `CX` importers · `CH` HubSpot write-through · `W7` identity merge · `W11` PII forget.

**The rule from [`crm.md §0`](crm.md).** Every CRM concept is a tag pattern. No new entities, no new tables, no new routes. Each button does one of five things to the substrate.

| Endpoint | What it's for | crm.md ref |
| --- | --- | --- |
| `POST /api/mark/<edge>` · `POST /api/warn/<edge>` | Pheromone on any path | §13 |
| `POST /api/signal/<receiver>` | Fire-and-forget — any CRM action | §13 |
| `POST /api/ask/<receiver>` | Synchronous (≤30s) — get a result | §13 |
| `GET/PUT /api/settings?scope=X` | Workspace config — add a `scope`, never a new file | §13 |
| `POST /api/forget` | PII cascade (multi-step, kept route) | §11 |

**Active state** (saved · pinned · archived · completed · followed · blocked) lives on the path — read it from `/api/export/highways?from=inbox:<ws>` and classify by strength/resistance. Never localStorage.

**Status legend** — ✅ wired · 🔄 toggle · 🧠 signal · 📎 browser · ⏳ planned · 🤖 worker · 📊 read-side · 🛡 compliance.

---

## §0 Role cascade — what each role sees ([`web/roles.md`](roles.md))

Four tiers. The dispatcher is the same; the UI gates which buttons render via `lib/viewer.ts`. Settings: `PUT /api/settings?scope=persona:<role>` controls visibility.

| Role | Scope | Hidden verbs | Hidden rails |
| --- | --- | --- | --- |
| **owner** | `/in` — workspace-wide | — | — |
| **agency** | `/in/[groupId]` — their clients | their clients only; no other-agency data | — |
| **client** (QW13) | `/u/[slug]/in` — own slug only | forget · block · suppress · spam · automation:* · DSAR · billing-admin · privacy-config · status-rule-edit | CHANNELS admin · TAGS admin namespace · Settings tree (most) |
| **end_user** | single conversation thread | everything except reply | every rail (no shell at all) |

Lens packs ([`crm.md §2.4`](crm.md)) layer on top — they promote which verbs surface for each role within their visible scope.

---

## §1 The Apple Mail mapping

Every mail verb has a CRM analog. The substrate makes them isomorphic.

| Apple Mail | CRM verb | Endpoint | How |
| --- | --- | --- | --- |
| Read (open) | open detail | URL `?focus=<id>` | shell swaps body |
| Reply | reply | `POST /api/signal/<sender>:reply` | universal composer ([crm.md §4](crm.md)) |
| Forward | forward | `POST /api/signal/<new-receiver>:reply` `{quoting:<id>}` | same composer, new receiver |
| New message | new | `/chat?prompt=…` (MVP) → inline composer (CComp, see §G) | per-preset HeroCTA (§7) |
| Flag / Star | save | `POST /api/mark/inbox:<ws>>id` strength=0.5 | toggle |
| Move to folder | tag | `POST /api/signal/<id>:tag` `{tag}` | folder = tag |
| Archive | archive | `POST /api/warn/inbox:<ws>>id` strength=0.5 | toggle |
| Delete | forget (actors) / archive-10 (others) | `POST /api/forget` / `POST /api/warn/.../10` | irreversible for people |
| Mark as junk | spam | `POST /api/warn/spam>actor` strength=2 | adapter gates |
| Mark all read | read-all | `POST /api/signal/me:read-all` | bulk |
| Snooze | snooze | `POST /api/signal/<id>:snooze` `{until}` | tag adds `snooze-until` |
| Schedule send | send-later | composer payload `{sendAt}` | tag adds `send-at` |
| Smart mailbox | saved view | `★` on list URL → tag `sub:<url>` → tag rail row | crm.md §2 "Adding a subscription" |
| Templates | templates | `GET /api/templates` + `settings/TemplateManager.tsx` | [crm.md §6](crm.md) |
| Signature | lens pack | `settings/PackEditor.tsx` | [crm.md §2.4](crm.md) |
| Threading | thread | events render as a `Conversation` body | already shipping (QW10) |

The CRM is mail + tags. Tags do the segmentation, status, lifecycle, owner, channel, campaign, holdout, schedule — every "feature" is a tag pattern.

---

## §2 The dispatcher — `useInboxActions.run(verb, entity)`

Single switch in `web/src/hooks/use-inbox-actions.ts`. Every button funnels through it.

```
verb            → endpoint                                              notes
─────────────── ──────────────────────────────────────────────────────  ─────────────────────────
mark            POST /api/mark/inbox:<ws>>id   strength=1                always strengthens
warn            POST /api/warn/inbox:<ws>>id   strength=1                always weakens
save (★)        POST /api/{mark,warn}/inbox:<ws>>id   strength=0.5       toggle
archive         POST /api/{warn,mark}/inbox:<ws>>id   strength=0.5       toggle
complete (✓)    POST /api/{mark,warn}/inbox:<ws>>id   strength=2         toggle
pin (📌)        POST /api/mark/inbox:<ws>>id   strength=10               one-way
claim (👤)      POST /api/mark/inbox:<ws>>id   strength=1                one-way
follow          POST /api/{mark,warn}/me>id    strength=0.5              toggle
block           POST /api/warn/block>actor     strength=10               permanent
spam            POST /api/warn/spam>actor      strength=2                adapter gate
share           navigator.clipboard.writeText                            browser only
forget          POST /api/forget                                         W11 cascade ([crm.md §11](crm.md))
reply           POST /api/signal/<target>:reply                          composer fires
broadcast       POST /api/signal/all:broadcast                           composer in `sub` mode
enrich          POST /api/signal/enricher:enrich                         [crm.md §10](crm.md)
edit field      POST /api/signal/<entityId>:update.<field>               EditableField
new entity      /chat?prompt=…  (MVP)  ·  inline composer (CComp)        HeroCTA + `+ New`
ask AI          POST /api/ask/<worker>:<task>                            [crm.md §13](crm.md)
settings flip   PUT /api/settings?scope=<scope>                          theme · density · packs · etc.
```

### Active-state thresholds (read from highways · CV)

```
strength ≥ 10                                  → pinned
strength ≥ 2.0                                 → completed
resistance ≥ 10                                → blocked
resistance ≥ 0.5 AND not completed/blocked     → archived
strength ≥ 0.5 AND resistance < 0.5            → saved
```

`me>entityId` → followed. `block>actor` → blocked. `spam>actor` → spam-flagged.

---

## §3 Receiver grammar

Full grammar lives in [`one/signals.md`](../plans/signals.md) §5 and [`crm.md §0`](crm.md). Shapes used by `/in`:

```
mark/warn path targets (edge format source>target, URL-encoded):
  inbox:<ws>>entityId          viewer engagement
  me>entityId                  personal follow
  priority:<level>>entityId    priority signal
  won>dealId · lost>dealId     outcome
  block>actorId · spam>actorId suppression
  role:<level>>actorId         role assignment

signal/ask receivers (URL path):
  <entityId>:<action>          mutate entity
  <actorId>:<action>:<target>? actor performs verb (claim, mention, merge, split)
  me:<action>:<entityId>?      personal queue (remind, read-all)
  all:<action>                 fanout (broadcast)
  sub:<topic>:<filter>         subscription fanout
  <worker>:<action>            worker call (enricher, summarizer, kb, quoter, scorer, predictor, dedupe, translator, classifier, runner)
  <role>:<action>:<id>         escalation (supervisor:escalate:ticketId)
  admin:<action>:<arg>         admin queue (promote-channel)
```

Bulk = client-side fan-out over the single-entity dispatcher. No bulk endpoint.

---

## §4 Live updates — `useSubstrateStream` (CPerf)

Six real-time streams per [`crm-pages.md §8`](crm-pages.md). Single hook subscribes to substrate events filtered by `slug + receiver pattern`. Reference pattern lives in `chat/MessageList` SSE consumer and `funnel/LiveEventStream`.

| Signal | Filter | Where shown |
| --- | --- | --- |
| activity blip | `slug:<ws>` | row dot · detail header · channel badge |
| sub count | `tag:<sub-tag>` | channel badge · status tab · gate row |
| pheromone bar | `path:*` | path nodes · actor dots · journey edges · tag ordering |
| presence | `actor:<id>:presence` | user-card dot · participant ring |
| profile completion | `actor:<id>:enriched` | top-bar % bar |
| frontier count | `learning:frontier` | 🔬 row badge |

Implementation: 1 hook, 6 consumers. No per-feature subscription endpoint.

---

# Part II — Buttons by zone (matches [`crm-pages.md`](crm-pages.md))

## §5 Rail · group dropdown (QW12 · [`crm-pages.md §2.1`](crm-pages.md))

| Button | What it does | Endpoint | Status |
| --- | --- | --- | --- |
| Summary row | Toggle switcher | — | ✅ QW12 |
| Workspace row | Switch workspace | full reload | ✅ |
| Group row | Switch group within workspace | `window.location.href = /in/<gid>` | ✅ |
| `+ New group` | Create group | `POST /api/signal/group:new` | ⏳ |
| `+ Create workspace` | Create workspace | `/chat?prompt=…` | ⏳ |
| Presence dot | Online / Away / Focus / OOO | `POST /api/mark/status:<state>>me` | ⏳ |
| Account / Billing | Open `/settings` | nav | ⏳ |

## §6 Rail · MAIL · WORK · CHANNELS · TAGS (QW1 · QW2 · QW3 · QW11 · [`crm-pages.md §2.2-2.5`](crm-pages.md))

| Button | What it does | Endpoint | Status |
| --- | --- | --- | --- |
| Any rail row | Set `?preset=<id>` | URL state | ✅ QW1 |
| `+` next to CHANNELS (admin) | Open ChannelCreateForm | `POST /api/signal/channel:new` | ⏳ CTagMgr |
| Channel row hover | DistributionCard ([`crm-pages.md §6.4`](crm-pages.md)) | — | ⏳ |
| `★` on tag row | Promote tag → admin notification (see §I) | `POST /api/signal/admin:promote-channel:<tag>` | ⏳ CTagMgr |
| Right-click rail row | Pin · Hide · Rename | `PUT /api/settings?scope=rail-order` | ⏳ |
| Drafts row click | Resume draft into composer (see §B) | `GET /api/in/drafts` | ⏳ CComp |

Learning pair (`learning:discovered`, `learning:frontier`) pinned by `RAIL_ORDER` (QW11). "Fading" sub-band: tag with highway strength <0.1 (CTagMgr).

## §7 List column · top (`crm-pages.md §3.1-3.3`)

| Button | What it does | Endpoint | Status |
| --- | --- | --- | --- |
| `▣` collapse-rail | Hide rail (toggle) | `PUT /api/settings?scope=preferences` | ⏳ |
| Title | Static | — | ✅ |
| `+ New` (per preset) | Open universal composer with template | `/chat?prompt=…` (MVP) → inline (§G) | ✅ partial — QW4 |
| ScopedSearchBar | In-memory filter <16ms | — | ✅ |
| HeroCTA | Contextual primary action (see §8) | varies | ✅ partial — QW5 |

## §8 HeroCTA + `+ New` per preset (`crm-pages.md §3.3`)

Both buttons open the same universal composer ([crm.md §4](crm.md)). Source: `lib/in/create-prompts.ts`. **MVP redirects to `/chat`; CComp ships inline composer (see §G).**

| Preset | HeroCTA | Composer template |
| --- | --- | --- |
| `inbox` | — | empty composer |
| `drafts` | + New Draft | `state:draft` |
| `sent` | — (hidden) | — |
| `tasks` | + New Task | `kind:task` + `remind-at` |
| `calendar` | + New Event | `kind:meeting` + `attach:slots` |
| `payments` | + Send Invoice | `kind:invoice` |
| `people` | ✨ Invite · 📥 Import (CSV / HubSpot / Salesforce / GHL — see §L) | `kind:actor` |
| `agents` | ⌬ Spawn Agent | `kind:agent` |
| `analytics` | — | (atlas only, see §C) |
| `channel:*` | ⌁ Broadcast | `sub: sub:<channel-tag>` |
| `tag:*` | ⌁ Broadcast to tag | tag pre-seeded |
| `learning:discovered` | 🚀 Materialise | `kind:journey` + seeded steps |
| `learning:frontier` | 🧪 Run Experiment | `kind:experiment` |

Owner edits at `/settings/list-ctas`.

## §9 StatusTabs + ViewModeToggle (CS · `crm-pages.md §3.4`)

| Button | What it does | Endpoint |
| --- | --- | --- |
| NOW · TOP · TODO · DONE | Filter by computed status ([crm.md §3](crm.md)) | URL `?s=` |
| View-mode (⊟ List · ▦ Pipeline · ▦ Kanban · 📅 Cal · 🗺 Map · 📊 Funnel) | Switch list renderer | URL `?view=` |

## §10 List rows — EntityCard + Stub rows (`crm-pages.md §3.5-3.6`)

| Button | What it does | Endpoint |
| --- | --- | --- |
| Row click | Select / open | URL `?focus=<id>` | ✅ |
| **Stub row** `? Unknown` click (see §H) | Opens detail with ProfileCompletion 0% → EnrichmentPickerDrawer | reads stub data | ✅ load-bearing |
| Checkbox (hover) | Add to multi-select | local state | ⏳ |
| Hover quick-actions | Star · Reply · `⋯` | dispatcher | ⏳ |
| Swipe right (mobile) | Save (★) | mark | ⏳ |
| Swipe left (mobile) | Archive | warn | ⏳ |

## §11 Detail · top bar (QW6 · `crm-pages.md §4.1`)

| Button | What it does | Endpoint | Status |
| --- | --- | --- | --- |
| ← Back | Clear `?focus` | URL state | ✅ |
| StatusChip | Read-only from highways (§4) | poll | 🎨 |
| Primary action (per kind, §12) | varies | dispatcher | ✅ partial |
| `⋯` overflow (§17) | Long-tail verbs | dispatcher | ⏳ CV |

## §12 Primary action per entity kind (`crm-pages.md §4.1`)

| Detail of | Primary | Endpoint |
| --- | --- | --- |
| Person | 💬 Message | inline Composer `direct:<actor>` |
| Agent | ⌬ Chat | nav `/u/<slug>/chat` |
| Conversation | ↵ Reply | `POST /api/signal/<target>:reply` |
| Task | ✓ Complete | mark strength=2 |
| Meeting | 📅 Join | calendar link + signal |
| Payment | 💳 View Receipt | `GET /api/ask/payment:<id>:receipt` |
| Channel | ⌁ Broadcast | composer `sub` mode |
| Path / journey | ▶ Run | `POST /api/signal/<journey>:run` |
| Frontier | 🧪 Experiment | composer `kind:experiment` |
| Discovered | 🚀 Materialise | composer `kind:journey` |
| SameAs candidate (W7, §D) | ✓ Confirm merge / ✗ Reject (split) | merge/split signal |

## §13 Detail · header pills (CV · planned inline-edit)

Each pill is an `EditableField`.

| Pill | Edit type | Endpoint |
| --- | --- | --- |
| Owner | select (actors) | `POST /api/signal/<actor>:claim:<id>` |
| Priority | select (high/med/low) | `POST /api/mark/priority:<lvl>>id` |
| Due date | datetime | `POST /api/signal/<id>:schedule` `{due}` |
| Stage (sales) | select | `POST /api/signal/<id>:convert:<stage>` |
| Tags | TagPills | `POST /api/signal/<id>:tag` |

## §14 Detail · body — variant per kind (QW8 · QW10 · `crm-pages.md §4.4-4.8`)

- **Stacked sections** (actors) — `crm/Contact*`. Click any field to edit. Includes **SameAs merge cards** (W7, §D).
- **Chat thread** (events) — `ai-elements/conversation`. `@mention` renders as autolinked chip (§J).
- **DAG** (paths) — `journey/JourneyDAG`. `e` edit node · `y` YAML · `⌘.` dry-run.
- **KPI atlas** (analytics) — `pulse/PulseAtlas`. Variant per agent count (§C).

## §15 EntityActionBar footer

Dimension-scoped verbs. Active state from §4 highway stream. See §16.

---

## §16 The click-all matrix

| Rail (preset) | HeroCTA / `+ New` | Action-bar verbs |
| --- | --- | --- |
| `inbox` | new conv | Reply · ★ Save · Archive · Complete · Share · `⋯` |
| `drafts` (§B) | + New Draft | Resume · ★ Save · Archive · Delete · `⋯` |
| `sent` | — | ★ Save · Archive · `⋯` |
| `tasks` | + New Task | Reply · ★ Save · Archive · Complete · `⋯` |
| `calendar` | + New Event | Accept · Decline · Reschedule · `⋯` |
| `payments` | + Send Invoice | Receipt · Refund · Dispute · `⋯` |
| `people` | ✨ Invite / 📥 Import | Message · Mark · Warn · Broadcast · Enrich · Forget · `⋯` |
| `agents` | ⌬ Spawn Agent | Chat · Configure · Pause · Resume · `⋯` |
| `analytics` (§C) | — | (atlas only) |
| `channel:*` | ⌁ Broadcast | Subscribe · Unsubscribe · `⋯` |
| `tag:*` | ⌁ Broadcast to tag | Subscribe · Unsubscribe · Promote (`★`, §I) · `⋯` |
| `learning:frontier` | 🧪 Experiment | Mark · Explore · Refute · `⋯` |
| `learning:discovered` | 🚀 Materialise | Mark · Cite · Retire · `⋯` |

### §17 `⋯` overflow — the long tail (CV · W7 · W11)

| Verb | Endpoint |
| --- | --- |
| Pin (📌) `p` | `POST /api/mark/inbox:<ws>>id` strength=10 |
| Follow `f` | `POST /api/mark/me>id` strength=0.5 |
| Snooze `s` | `POST /api/signal/<id>:snooze` `{until}` |
| Note (internal) `n` | `POST /api/signal/<id>:note` `{body, visibility:internal}` ([crm.md §7](crm.md)) |
| @ Mention | `POST /api/signal/<actor>:mention` |
| Tag `t` | `POST /api/signal/<id>:tag` |
| Attach file | `POST /api/signal/<id>:attach` multipart |
| **Confirm merge** (W7, §D) | `POST /api/signal/<actorA>:merge:<actorB>` |
| **Split actors** (W7, §D) | `POST /api/signal/<actorA>:split:<actorB>` |
| **Override stage** (recovery, §E) | `POST /api/signal/<actor>:override:<stage>` |
| **Use manual value** (recovery, §E) | `POST /api/signal/<entity>:update.<field>` `{source:manual}` |
| Convert (stage) | `POST /api/signal/<actor>:convert:<stage>` |
| Translate / Summarize / Draft reply / Suggest next / Find duplicates / Score | `POST /api/ask/<worker>:<task>` 🤖 |
| Escalate | `POST /api/signal/<role>:escalate:<id>` |
| Share (copy link) | clipboard |
| Activity / Timeline | reads `/api/export/highways?to=<id>` 📊 |
| Audit log | reads agent-events 📊 |
| Print | `window.print()` 📎 |
| Block / Spam / Suppress / Forget | `POST /api/warn/{block,spam,suppress}>actor` · `POST /api/forget` |

`⌘z` undo — last dispatcher action with primitive flipped (5s window).

---

## §18 Composer (CComp · `crm-pages.md §5`)

One composer, every workflow ([crm.md §4](crm.md)).

| Surface | What it does | Endpoint |
| --- | --- | --- |
| ReceiverPill (direct · world · all · sub) | Switch addressing mode | local |
| Channel auto-pick (direct mode) | Read actor's strongest channel; `⌘1/2/3` cycles | substrate |
| TagPills `+/×` | Add/remove tag | local |
| HoldoutToggle (sub mode only) | A/B holdout % | payload |
| SchedulePill | `now` / `at` / `path` | payload `{sendAt}` ⏳ |
| **GatePanel** | Pre-send checks — **consent · cap-hit · suppression · compliance** | `POST /api/ask/gate:check` 🛡 🔌 |
| TemplatePicker (`/`) | Apply template | `GET /api/templates` ✅ |
| MentionPicker (`@`) | Insert mention chip | `GET /api/export/actors?q=` ⏳ |
| AttachmentPreview | File chips | multipart payload ⏳ |
| `+ Add` | Template/cmd picker | reuses TemplatePicker |
| `📎 Attach` | File picker | `POST /api/signal/<id>:attach` |
| `🔍 Search` | KB search → citation chips | `POST /api/ask/kb:search` 🤖 |
| Model picker | LLM (chat flavour only) | `PUT /api/settings?scope=composer:model` |
| `➤ Send` | Submit | dispatcher |

**GatePanel inputs (each is a worker query):**

| Check | Source |
| --- | --- |
| consent | `consent:<channel>` tag on each recipient |
| cap-hit | per-channel send cap from `/settings/privacy` × actor's send history |
| suppression | `block` / `spam` / `suppress` paths on recipient |
| compliance | `gdpr` / `ccpa` / `canspam` / `tcpa` namespace flags |

Keys: `⌘↵` send · `⌘⇧↵` schedule · `Esc` collapse · `Shift+↵` newline · `⌘D` save draft (§B).

---

## §19 Drafts — autosave + resume + ⌘D (CComp)

| Action | Trigger | Endpoint |
| --- | --- | --- |
| Autosave | every 2s of inactivity after edits | `PUT /api/in/drafts` |
| Manual save | `⌘D` | `PUT /api/in/drafts` |
| Resume on Drafts row click | EntityCard click in `?preset=drafts` | `GET /api/in/drafts?entityId=<id>` → seeds composer |
| Discard | `Esc` after focus | `DELETE /api/in/drafts?entityId=<id>` |

Composer reads draft on mount if `entity.tags` contains `state:draft`.

## §20 BroadcastBar (top of detail)

| Button | Endpoint |
| --- | --- |
| Input + Enter / Send | `POST /api/signal/all:broadcast` ✅ |

---

## §21 Channels rail · DistributionCard hover (CTagMgr · `crm-pages.md §6.4`)

| Button | Endpoint |
| --- | --- |
| ⌁ Broadcast (⌘B) | open Composer `sub: sub:<channel-tag>` |
| 💾 Save audience | `POST /api/signal/channel:new` (new channel from current filter) |
| ⎘ Export CSV | `GET /api/ask/export:csv?channel=<slug>` |
| ↑ Export → Meta / Google / TikTok | `POST /api/signal/<integration>:audience-sync` (CX) |

---

## §22 Identity merge (W7 · `crm.md §12`)

| Verb | Where | Endpoint |
| --- | --- | --- |
| Merge candidates queue | saved view `?preset=people&filter=needs-review:merge` | reads paths with `same-as` confidence 0.6-0.95 |
| ✓ Confirm merge | actor detail SameAs section button | `POST /api/signal/<actorA>:merge:<actorB>` |
| ✗ Reject (split) | actor detail SameAs section button | `POST /api/signal/<actorA>:split:<actorB>` (writes `same-as NOT`) |
| View provenance | inline `merged-into` chain | reads ContactSameAs data |
| Split after auto-merge | actor detail → split button | same as Reject |

Auto-merge ≥0.95. Queue review 0.6-0.95. Drop <0.6. `crm/ContactSameAs.tsx` already renders the linked-merge cards with split-button on hover.

## §23 Failure-mode recovery (`crm.md §15`)

| Failure | Recovery verb | Endpoint |
| --- | --- | --- |
| Stage transition misfire | **Override stage** (on actor record) | `POST /api/signal/<actor>:override:<stage>` |
| Merge false-positive | **Split actors** (§22) | `POST /api/signal/<actorA>:split:<actorB>` |
| Enrichment overwrite | **Use manual value** (per field) | `POST /api/signal/<entity>:update.<field>` `{source:manual}` — wins on display ([crm.md §10](crm.md)) |
| Stale enrichment | **Re-enrich now** | `POST /api/signal/enricher:enrich:<id>` |
| Hot-fire signal | **`⌘z` Undo** | dispatcher with primitive flipped |

Each surfaces as a button on the relevant detail section; not a separate route.

## §24 `★` promote-to-channel admin flow (CTagMgr)

Per [`crm.md §2`](crm.md).

1. User clicks `★` on any tag row → `POST /api/signal/admin:promote-channel:<tag>`
2. Admin's NotificationBell (§28) shows "Promote `<tag>` to channel?"
3. Accept → opens ChannelCreateForm pre-filled with `tags: [<tag>]`
4. Dismiss → `POST /api/warn/admin:promote-channel:<tag>` strength=2 (suppresses future suggestions for 30d)

---

## §25 Multi-agent atlas variants (CP · `crm-pages.md §6.5`)

`?preset=analytics` body:

| Workspace state | Body |
| --- | --- |
| 0 agents | EmptyState card → "Spawn your first agent" → routes to Agents preset HeroCTA |
| 1 agent | `pulse/PulseAtlas` with that `agentId` |
| N agents | Agent selector pill at top + workspace roll-up tile row → drill into single-agent atlas |

No new endpoint — `pulse/PulseAtlas` already accepts `agentId`. Workspace roll-up is N parallel fetches + sum tiles.

---

## §26 Overlays

| Surface | Trigger | Endpoint |
| --- | --- | --- |
| Spotlight | `⌘K` | client search + dispatcher · quick-add parser ⏳ CK |
| HelpOverlay | `?` | client overlay |
| Toaster | dispatcher result | sonner; `Undo` action button on destructive verbs |
| ConfirmDialog | destructive (forget · reset · split · block) | client gate |
| NotificationBell | header | `GET /api/export/highways?to=me` 📊 + `POST /api/signal/me:read-all` |
| Drawer | settings · members · enrichment · filter · merge-candidates · ChannelCreateForm | `?drawer=<id>` deep-link |

## §27 Forms (drawer-mounted) vs templates

**Drawer forms = composed inputs.** **Templates = pre-filled composer values** ([crm.md §6](crm.md)). The composer handles everything.

Drawer forms:

| Form | Submit |
| --- | --- |
| ChannelCreateForm (CTagMgr) | `POST /api/signal/channel:new` |
| PersonInviteForm | `POST /api/signal/team:invite` |
| **ImportCSVForm** (CX, see §L) | `POST /api/signal/import:csv` multipart |
| ExportForm | `GET /api/ask/export:csv?…` |
| FilterBuilder | `PUT /api/settings?scope=filter:<rail>` |
| SaveViewAsForm → creates a **channel** | `POST /api/signal/channel:new` |
| EnrichmentPickerDrawer (§H) | `POST /api/signal/enricher:enrich` |
| ConsentEditor | `POST /api/signal/<actor>:consent` |
| **MergeReviewDrawer** (W7, §22) | `POST /api/signal/<actor>:merge` / `:split` |

NOT drawer forms — template rows in `settings/TemplateManager.tsx`:
"automation" · "sequence" · "report" · "form embed" · "booking" · "survey/CSAT" · "custom field" (→ tag namespace, `settings/TagManager.tsx`) · "lens/persona" (→ `settings/PackEditor.tsx`).

## §28 Settings tree (CSP)

Per [`crm.md §13`](crm.md), settings = `GET/PUT /api/settings?scope=<scope>`.

| `/settings/<path>` | Component | Status |
| --- | --- | --- |
| index | `settings/SettingsView.tsx` | ✅ |
| channels | composes ChannelCreateForm rows | ⏳ |
| tags | `settings/TagManager.tsx` | ✅ |
| templates | `settings/TemplateManager.tsx` | ✅ |
| packs (lens packs) | `settings/PackEditor.tsx` | ✅ |
| status | `settings/StatusRuleEditor.tsx` | ✅ |
| list-ctas | small composition | ⏳ |
| detail-tabs | small composition | ⏳ |
| profile-completion | small composition | ⏳ |
| privacy | `settings/PrivacyControls.tsx` | ✅ |
| integrations (CX/CH) | composes `cards/ActionCard.tsx` rows | ⏳ |
| members | `settings/TeamManager.tsx` | ✅ |
| billing | `settings/BillingSettings.tsx` | ✅ |
| appearance | `settings/AppearanceSettings.tsx` | ✅ |

9 of 13 shipping. 4 small compositions to compose.

---

## §29 Keyboard (CK · 30 + Escape)

Single source: `Inbox.tsx` shortcut registry. Mirrors Apple Mail + Superhuman.

| Group | Keys |
| --- | --- |
| nav (4) | `j` `k` next/prev · `␣` peek · `↵` open |
| status (4) | `1` Now · `2` Top · `3` Todo · `4` Done |
| jump (9) | `⌘1`..`⌘9` rails |
| chord (4) | `g i` `g p` `g t` `g c` |
| action (6 today) | `r` reply · `c` compose · `m` mark · `w` warn · `a` archive · `⇧c` claim |
| action (planned CK) | `p` pin · `s` snooze · `n` note · `f` follow · `e` edit · `t` add tag · `⌘z` undo · `.` overflow · `⌘D` save draft |
| meta (3) | `⌘k` Spotlight · `?` Help · `/` Search |
| meta-extended | `⌘B` broadcast · `⌘D` save draft · `⌘,` settings · `⌘L` switch lens · `⌘\` toggle rail · `⌘.` dry-run journey · `⌘S` save view as channel |
| composer | `⌘↵` send · `⌘⇧↵` schedule · `Shift+↵` newline · `/` template · `@` mention |
| escape | `Esc` close overlay / back / clear search |

Lens pack visibility ([crm.md §2.4](crm.md)) decides which `action` keys are promoted without growing the visible 30.

---

## §30 Mobile (`crm-pages.md §10`)

| Surface | Behavior |
| --- | --- |
| Bottom rail pill | Set preset |
| `← Back` | Return to list |
| Swipe right on EntityCard | Save (★) ⏳ |
| Swipe left on EntityCard | Archive ⏳ |
| Long-press EntityCard | Open `⋯` overflow ⏳ |
| Pull-to-refresh | Re-poll highways + entities |
| Tap notification | Deep-link `/in?focus=<id>` |
| Compose FAB | Open Composer in bottom sheet |
| Spotlight FAB | Open Spotlight (`⌘K` parity) |

---

## §31 Endpoints map (full)

| Endpoint | Verbs |
| --- | --- |
| `POST /api/mark/<edge>` | mark · save (★) · complete (✓) · claim · pin · follow · path-Mark · win · priority · role · share-read · share-edit · channel-attribution · status |
| `POST /api/warn/<edge>` | warn · archive · all toggle counterparts · block · spam · suppress · lose · refute · revoke-share · pause-automation/campaign |
| `POST /api/signal/<receiver>` | message · reply · forward · broadcast · enrich · edit-field · install · join · leave · accept · decline · reschedule · refund · dispute · cite · note · mention · snooze · attach · tag · log · csat-request · cobrowse · convert · **merge · split · override-stage** · escalate · channel:new · ticket:open · feedback:report · admin:promote-channel · onboarding:* |
| `POST /api/ask/<receiver>` | draft · summarize · translate · advisor:next · predictor:close · scorer:score · dedupe:scan · classifier:tag · kb:search · quoter:generate · reporter:* · compliance:dsar · export:csv · runner:exec · channel:health · anomaly:scan · **gate:check** |
| `GET/PUT /api/settings?scope=<scope>` | persona · view-mode · sort · filter · view:<id> · channels · tags · templates · packs · status · list-ctas · detail-tabs · profile-completion · privacy · integrations · members · billing · appearance · preferences · workspace · quota · schema · rail-order · automations · forms · composer:model |
| `POST /api/forget` | PII cascade (W11) |
| `GET /api/export/highways` | active state · followed · notifications-unread · activity timeline · `useSubstrateStream` consumers |
| `GET /api/in/drafts` · `PUT /api/in/drafts` · `DELETE /api/in/drafts` | composer drafts (§19) |
| `GET /api/templates · /api/tags · /api/frontiers` | composer + nav data |
| `/chat?prompt=…` | MVP HeroCTA + `+ New` redirect (until CComp inline composer) |
| `/go/:id` · `/r?e=&c=&u=` | tracked-link redirects ([crm.md §9](crm.md), §K) |

**MCP cross-reference (CMcpInbox).** Every verb above is also reachable via `@oneie/mcp`'s `inbox_*` tools ([crm.md §13](crm.md)) — `inbox_list` · `inbox_open` · `inbox_send` · `inbox_subscribe` · `inbox_mark` · `inbox_warn` · `inbox_react` · `inbox_forget` · `inbox_pulse` · `inbox_watch`. The button is sugar; the substrate is the contract.

---

## §32 Inline composer migration (CComp)

**Today.** HeroCTA / `+ New` calls `window.location.href = /chat?prompt=…` — full page nav. Inbox context lost.

**Spec ([crm.md §4](crm.md)).** Universal composer slides up *in place* inside the detail pane with the preset's template pre-filled.

**Migration plan (CComp cycle):**
1. Mount `Composer.tsx` inside a Drawer-from-bottom that animates up on HeroCTA/`+ New` click
2. Pre-fill via `applyTemplate(presetTemplate)` — no new fetch
3. On send → existing dispatcher
4. On dismiss → restore inbox state from URL (no navigation)
5. Delete the `/chat` redirect call in `lib/in/create-prompts.ts`; replace with `openInlineComposer(template)`

Zero new endpoints. One callback added to `Inbox.tsx` state.

---

## §33 @mention rendering (CV)

In any rendered message body, `@<handle>` is parsed and rendered as a clickable chip linking to `?preset=people&focus=<actorId>`.

| Surface | Renderer |
| --- | --- |
| Chat thread message | `ai-elements/markdown` extension or `ai-elements/message` content parser |
| Internal note | same parser; chip routes only within workspace's team |
| Composer body (live) | parses to MentionPicker on `@<keystroke>` |
| Email outbound | rendered as plain `@<handle>` text (no link) |

Composer auto-suggests via `MentionPicker` (`@` trigger, §18).

## §34 Tracked-link receivers (`crm.md §9` · shipped)

**LinkPreview cards render only tracked URLs** — `/go/<id>` or `/r?e=&c=&u=`. The composer auto-rewrites pasted external URLs through the tracked-link minter (`POST /api/links:mint`). Never raw PII in URLs.

Adapters (Telegram · Discord · Email · SMS) emit signals when the link is clicked → substrate writes `touch:click · campaign:<c>` tag. The path strengthens.

## §35 HubSpot / Salesforce / GHL migration UI (CX · CH · `crm.md §16`)

ImportCSVForm (§27) extends:

| Step | What it does |
| --- | --- |
| Connect source | OAuth via `/settings/integrations` |
| Field map preview | shows column → tag namespace mapping (`crm.md §5`) |
| Conflict resolution | radio per row: `overwrite` / `keep existing` / `merge by email-hash` |
| Dry run | `POST /api/ask/import:dry-run` returns sample resolved actors |
| Live progress | `useSubstrateStream` (§4) on `import:<id>` |
| Receipt id | shown after submit; queryable at `/api/forget/:id` for cascade status |
| Write-through agent toggle | `PUT /api/settings?scope=integrations` activates `export-hubspot` etc. (CH) |

Substrate runs in parallel during migration. Importer agent subscribes to `actor:lifecycle` transitions and calls vendor CRM API within 30s.

## §36 Onboarding tie-in

First visit to `/in/<groupId>` with zero entities triggers `onboarding/OnboardingFlow.tsx` overlay:

| Step | Verb |
| --- | --- |
| Pick lens pack (Marketer / Sales / Service) | `PUT /api/settings?scope=packs` (applies a starter pack) |
| Connect first channel | `POST /api/signal/channel:<id>:connect` |
| Send a tracked link (`/go/<id>`) | mints + opens `LinkPreview` card |
| Spawn first agent | `/chat?prompt="Spawn an agent…"` |
| Send first broadcast | composer pre-filled |

Skip → `PUT /api/settings?scope=onboarding` `{done:true}`. Reset → `POST /api/signal/onboarding:reset`.

---

## §37 What still needs wiring (the practical gap, in QW/Cycle order)

1. **CV** — `⋯` overflow + header pills + identity merge confirm/split + activity tab
2. **CTagMgr** — Channels admin rail zone + DistributionCard hover + `★` promote flow
3. **CComp** — inline composer + SchedulePill + MentionPicker + AttachmentPreview + GatePanel live data + autosave hookup
4. **CK** — extend keyboard registry with `p`/`s`/`n`/`f`/`t`/`e`/`.`/`⌘z`/`⌘D`/`⌘S`
5. **CSP** — 4 settings panels left to compose
6. **CX/CH** — ImportCSVForm extensions + integration row UI
7. **CP** — `PulseAtlas` multi-agent variant
8. **W7** — MergeReviewDrawer wiring
9. **W11** — ConfirmDialog gating for forget
10. **QW13** — `/u/[slug]/in` client scope with role-gated verbs

Everything else: the substrate covers it. Zero new endpoints.

---

*Apple Mail metaphor. Five primitives. The composer handles everything. Templates are the standard CRM as data. Roles cascade; lenses promote. Power through simplicity.*
