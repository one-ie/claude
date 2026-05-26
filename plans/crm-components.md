# crm-components.md — reuse audit

Companion to [`crm.md`](crm.md) (principles), [`crm-pages.md`](crm-pages.md) (layout), [`crm-buttons.md`](crm-buttons.md) (verbs).

**The rule.** No new component when an existing one can be reused or composed. The library has ~245 components across 26 directories — almost every surface `/in` needs is already built. Per [`crm.md §17`](crm.md): no automation engine, no report builder, no form builder, no field editor as separate apps — they're rows in [`settings/TemplateManager.tsx`](src/components/settings/TemplateManager.tsx) pre-filling the universal composer.

**Reading guide.** Each component is tagged with the **QW#** / **Cycle** code from [`crm.md §18`](crm.md) that ships it. See [`crm-buttons.md`](crm-buttons.md) opening note for the index.

**Status legend** — ✅ Reuse · 🧩 Compose from primitives · 🆕 Net-new · ♻️ Replace duplicate.

**Counts** — 47 `/in` surfaces · 39 ✅ reuse · 6 🧩 compose · **2 🆕 truly new** · 2 ♻️ duplicates to delete.

---

## Index

| Part | Section | Content |
| --- | --- | --- |
| I | §1-§3 | Library inventory · `MessageRenderer` is canon · `useSubstrateStream` hook |
| II | §4-§13 | Shell + rail + mobile |
| III | §14-§22 | List column |
| IV | §23-§35 | Detail pane (includes Apple-Contacts sections + identity merge + activity timeline) |
| V | §36-§46 | Composer (includes drafts, mention picker, gate panel) |
| VI | §47-§55 | Rich-message cards (extend `MessageRenderer`, don't fork) |
| VII | §56-§63 | Overlays + Drawers |
| VIII | §64-§71 | Forms (drawer-mounted composites — NOT builders) |
| IX | §72-§77 | View-mode renderers |
| X | §78-§86 | Settings tree (most already shipping) |
| XI | §87-§88 | Onboarding · OnboardingFlow tie-in |
| XII | §89 | Duplicates / dead code |
| XIII | §90 | The two genuinely new components |
| XIV | §91 | Verb → component cross-reference |

---

# Part I — Library + canon

## §1 Directory map

| Directory | What lives here | Reusables for `/in` |
| --- | --- | --- |
| `ui/` | shadcn primitives (~25 files) | **Drawer**, **dropdown-menu**, **dialog**, **hover-card**, **popover**, **command** (cmdk), **button-group**, **badge**, **progress**, **separator** |
| `ai-elements/` | rich content primitives (~50 files) | **code-block**, **confirmation**, **conversation**, **inline-citation**, **markdown**, **message**, **model-selector**, **prompt-input** (+ layout, context, textarea), **suggestion**, **transcription**, **audio-player** |
| `cards/` | 13 product cards | **EmptyState**, **EmptyStateCard**, **ActionCard**, **AgentPreviewCard**, **MarketplaceMini**, **VerifyCard**, **PriceCard**, **CompareCard**, **OnboardingChecklist** |
| `chat/` + `chat/cards/` | chat surface + 14 typed cards | **MessageRenderer**, MessageList, **PaymentCard**, **AttachmentsPreview**, **AddMenu**, **VoiceMenu**, **CalendarCard**, **MapCard**, **QuoteCard**, ProductCard, CartCard, JobTrackerCard, DispatchCard, … |
| `crm/` | Apple-Contacts sections + **identity merge** | **ContactActivity**, **ContactAppended**, **ContactConsent**, **ContactHeader**, **ContactIdentity**, **ContactPaths**, **ContactSameAs** |
| `in/` | inbox shell | Composer, Inbox, EntityCard, EntityDetail, EntityActionBar, **EditableField**, **HeroCTA**, ListHeader, Navigation, **ProfileHeader**, **StatusTabs** |
| `in/composer/` | composer parts | **GatePanel**, **HoldoutToggle**, **ReceiverPill**, **TagPills** *(plus duplicate TemplatePicker — see §89)* |
| `composer/` | top-level composer | **TemplatePicker** (cmdk, canonical) |
| `keyboard/` | overlays | **Spotlight**, **HelpOverlay** |
| `pulse/` | analytics atlas | **PulseAtlas**, **KpiLadder**, **Funnel**, **Attribution**, **Holdout**, **FrontierBlock** |
| `funnel/` | richer analytics + **LiveEventStream** | **FunnelChart**, AcquisitionCard, AudienceCard, EngagementTrendCard, EventTimelineChart, **LiveEventStream**, PathsCard, RetentionGrid, SegmentDropdown, … |
| `journey/` | journey DAG | **JourneyDAG** |
| `data/` | data primitives | **ActivityFeed**, **KeyValueGrid**, **MetricTile** |
| `layout/` | scaffolds | **DetailHeader**, **PageHeader**, **SurfaceGrid** |
| `sidebar/` | non-`/in` sidebar | **Sidebar**, MenuItem, SheetMenu, Attribution, EndUserCTA, ThemeToggle |
| `settings/` | 19 admin panels | **SettingsView**, **TagManager**, **TeamManager**, **TemplateManager**, **PackEditor**, **StatusRuleEditor**, **BillingSettings**, **AppearanceSettings**, **PrivacyControls**, **BrandingSettings**, **ChatSettings**, **DomainSettings**, … |
| `agents/` | agent admin | **AgentDrawer**, AgentForm, VerifiedBadge |
| `pay/` + `payments/` + `billing/` | payment surfaces | **PayPanel**, **Ledger**, PriceCards, PoolCard, … |
| `onboarding/` | first-run flow | **OnboardingFlow** (§87) |
| `auth/`, `motion/`, `cro/`, `showcase/`, `skills/`, `tools/` | general | primitives reused as needed |

## §2 MessageRenderer is the canonical dispatcher

[`chat/MessageRenderer.tsx`](src/components/chat/MessageRenderer.tsx) switches on `data.kind` to dispatch to all `chat/cards/*` + `cards/*` types.

**Adding a new card kind = extend `CardData` discriminated union in `@/lib/cards` + add one case in `MessageRenderer`.** Never a parallel dispatcher.

## §2.5 Goal-based test helpers (CRM demo wall)

Every `crm-todo.md` cycle closes on one Vitest under `tests/e2e/crm/D{N}.test.ts`. Helpers live in `tests/e2e/crm/_helpers.ts`:

| Helper | Use |
| --- | --- |
| `mockSubstrate()` | msw server with default handlers for `/api/{signal,ask,mark,warn,forget,settings,export}/*`; returns `{server, calls, settings}` |
| `mockViewer(role)` | role string per `web/roles.md` cascade |
| `mockSession(opts)` | full `SessionInfo` for `deriveViewer` |
| `seedFromFile(name)` | reads `tests/seeds/D{N}.sql` for cycles that wire DB-backed assertions |

Runner: `bun run demo:crm` (see `scripts/demo-crm.sh`). CI: `.github/workflows/demo-crm.yml`. No Playwright — every goal expresses in Vitest + jsdom + msw.

## §3 `useSubstrateStream` — the live-updates hook (CPerf)

Six real-time streams per [`crm-pages.md §8`](crm-pages.md) all come from the same substrate. Single hook subscribes filtered by `slug + receiver pattern`.

```ts
// web/src/hooks/use-substrate-stream.ts (planned name; pattern already exists)
useSubstrateStream({
  slug,
  filter: 'tag:<sub-tag>' | 'actor:<id>:presence' | 'path:*' | 'learning:frontier',
  onSignal: (signal) => void,
})
```

| Reference pattern (already shipping) | Where |
| --- | --- |
| SSE event consumer | `chat/MessageList.tsx` |
| Funnel live tail | `funnel/LiveEventStream.tsx` |
| `/api/analytics/watch` server-side feed | substrate API |

Consumers across `/in`:

| Surface | Filter | Component |
| --- | --- | --- |
| EntityCard activity dot | `slug:<ws>` | inline in `EntityCard.tsx` |
| Channel unread badge | `tag:<channel-tag>` | `ChannelRow` (§7) |
| Pheromone bars (path nodes / actor dots / journey edges) | `path:*` | `JourneyDAG`, `ContactPaths`, `EntityCard` |
| Presence ring | `actor:<id>:presence` | `ProfileHeader`, `ai-elements/message` author chip |
| Profile-completion bar | `actor:<id>:enriched` | `EntityDetail.ProfileCompletionBar` |
| Frontier badge | `learning:frontier` | rail row |

One hook, six consumers. No per-feature subscription endpoint.

---

# Part II — Shell + rail + mobile

## §4 ShellLayout

✅ `src/pages/in/[groupId].astro` + `in/Inbox.tsx`. Already shipping.

## §5 MobileShell (QW10 polish · `crm-pages.md §10`)

✅ `Inbox.tsx` `isMobile` branch. Swipe + long-press = 🧩 ~30 lines using `motion/` patterns.

Mobile-only components:

| Component | Compose from | Status |
| --- | --- | --- |
| BottomTabBar | horizontal layout of `sidebar/MenuItem.tsx` | ⏳ |
| SwipeableCard wrapper | framer-motion drag bindings | ⏳ |
| BottomSheet (compose / spotlight FAB) | `ui/Drawer.tsx` with `side="bottom"` | ✅ via Drawer |
| PullToRefresh | scroll listener + `useSubstrateStream` refresh | ⏳ |
| LongPressMenu | `ui/dropdown-menu.tsx` with `onContextMenu` trigger | ✅ via DropdownMenu |

## §6 GroupDropdown (QW12)

✅ `in/ProfileHeader.tsx`. Workspace × group switcher.
🧩 Add rows: account/billing · presence dot · `+ Create workspace` / `+ New group`. Each row = one `ui/dropdown-menu` item.

## §7 RailZone + RailRow (QW1)

✅ `in/Navigation.tsx`. Zone separators (MAIL/WORK/CHANNELS/TAGS) + active state shipping.
🧩 Right-click → Pin/Hide/Rename via `ui/dropdown-menu` on `onContextMenu`.

## §8 ChannelRow (admin-curated · CTagMgr · `crm-pages.md §2.4`)

🧩 ~30 lines. Adds emoji + colour dot + SSE unread badge (via `useSubstrateStream` §3). Hover → DistributionCard (§16) via `ui/hover-card`.

## §9 TagRow + LearningPair (QW11)

✅ `Navigation.tsx` — tag rail items render from `/api/tags`. Pinned learning pair in `RAIL_ORDER` already. Add "fading" separator (tag highway strength <0.1 — CTagMgr).

## §10 UserCard (bottom of rail)

🧩 ~25 lines using `ui/avatar` + `ui/dropdown-menu`. Reference shape: `sidebar/Attribution.tsx`.

## §11 Sidebar (non-`/in` routes)

✅ `sidebar/Sidebar.tsx` for `/u/<slug>/*`. **Not** for `/in` — `Navigation.tsx` is canon there.

## §12 Header / NotificationBell

🆕 NotificationBell — only genuinely new chrome (§90).

## §13 Role-gated rail rendering (QW13 · `/u/[slug]/in` · `web/roles.md`)

`Navigation.tsx` accepts a `viewer: Viewer` prop. The Viewer's role filters which rail rows render. No new components — the visibility map ships as a prop:

| Role | Visible zones |
| --- | --- |
| owner | all |
| agency | all (within their clients) |
| client | MAIL · WORK · TAGS · learning pair · own user-card. **No CHANNELS admin · no Settings tree access except appearance/preferences.** |
| end_user | none — single conversation thread, no rail |

The dispatcher is the same; `lib/viewer.ts` already exposes the Viewer type.

---

# Part III — List column

## §14 ColumnHeader (QW4)

✅ `in/ListHeader.tsx`. `▣` + title + `+ New` shipping. Wire `▣` to `PUT /api/settings?scope=preferences`.

## §15 ListToolbar (planned · CSP)

🧩 ~80 lines composing `ui/button-group` (View) + `ui/select` (Sort) + Filter trigger + Save view + Import / Export / Print.

## §16 ViewModeToggle

🧩 `ui/button-group` segmented. Six modes per [`crm-pages.md §3.4a`](crm-pages.md).

## §17 ScopedSearchBar

✅ Inline `SearchBar` in `Inbox.tsx`. Grammar extension lives in `data/in-types.ts` `filterInbox()`.

## §18 HeroCTA (QW5)

✅ `in/HeroCTA.tsx`. Source: `lib/in/create-prompts.ts`. Extends with the 8 missing presets per [`crm-buttons.md §8`](crm-buttons.md). **MVP redirects to `/chat`; CComp swaps for inline composer per `crm-buttons.md §32`.**

## §19 ChannelDistributionCard (CTagMgr · `crm-pages.md §6.4`)

🧩 ~40 lines. `ui/hover-card` + `data/KeyValueGrid` (persona / channel / geo) + button row. Layout reference: `funnel/AudienceCard.tsx`.

## §20 StatusTabs (CS)

✅ `in/StatusTabs.tsx`. Now/Top/Todo/Done with live counts.

## §21 MultiSelectToolbar (planned)

🧩 `ui/button-group` + `ui/dropdown-menu` (`⋯ More`). State = `Set<string>` in `Inbox.tsx`. Bulk verbs loop existing dispatcher.

## §22 EntityList + EntityCard variants (QW9 polish)

✅ `in/EntityList` + `in/EntityCard.tsx`. Density variants (Contacts / Mail / Calendar / Payments / **Stub**) branch on `entity.dimension` inside one file.

**Stub rows** (`? Unknown`, `crm-pages.md §3.6` · "load-bearing"): EntityCard renders fallback avatar + 0% completion. Click → opens EntityDetail with ProfileCompletionBar visible → click bar → §66 EnrichmentPickerDrawer. Already mostly wired; just needs the stub branch styled.

Future virtualisation: wrap with `@tanstack/react-virtual`. Not a new component.

---

# Part IV — Detail pane

## §23 BroadcastBar

✅ Inline in `Inbox.tsx`. Wired to `POST /api/signal/all:broadcast`.

## §24 DetailTopBar (QW6)

✅ `crm/ContactHeader.tsx` for actors (CRM-aware) · `layout/DetailHeader.tsx` for other dimensions.

## §25 StatusChip

✅ `ui/badge.tsx` with `tone="success|destructive|tertiary|muted"`. Variants per [`crm-pages.md §4.1`](crm-pages.md). Live from `useSubstrateStream` (§3).

## §26 PrimaryActionButton

✅ `ui/button.tsx` (`variant="primary"`). Lookup table in `EntityDetail.tsx` extends per [`crm-buttons.md §12`](crm-buttons.md) — 10 kinds; today wires 3.

## §27 ProfileCompletionBar (QW7)

✅ Inline `ProfileCompletionBar` in `EntityDetail.tsx`. Click → `EnrichmentPickerDrawer` (§66).

## §28 DetailTabs (QW8)

✅ Inline `DetailTabs` in `EntityDetail.tsx`. `TABS_BY_DIM` is data — extend per [`crm-pages.md §4.3`](crm-pages.md). Includes **Activity timeline** tab (§30).

## §29 HeaderPillRow (CV)

✅ `in/HeaderPillRow.tsx` (88 lines). Each pill = `EditableField`:
- owner / priority / stage → `type="select"`
- due → `type="datetime"`
- tags → lifted `in/composer/TagPills` (already standalone)

Mounted inside `EntityDetail.tsx` header for actors dim.

## §30 Activity timeline tab (CV · `crm-pages.md §4.3`)

✅ `crm/ContactActivity.tsx` (CRM-aware) and `data/ActivityFeed.tsx` (generic).
Reads `useSubstrateStream({filter: 'actor:<id>'})` (§3). No new component.

## §31 Apple-Contacts stacked sections (CV · `crm-pages.md §4.4`)

✅ **All shipping** in `crm/*`:

| Section | Component |
| --- | --- |
| `── consent ──` | `ContactConsent` |
| `── channels ──` + `── paths ──` | `ContactPaths` |
| `── identity ──` (with merge cards) | `ContactIdentity` + `ContactSameAs` |
| `── appended ──` | `ContactAppended` |
| `── activity ──` (in Activity tab) | `ContactActivity` |
| top bar | `ContactHeader` |

`EntityDetail.tsx` already imports `ContactAppended`, `ContactConsent`, `ContactPaths`. The Overview tab pulls them all together.

## §32 Identity merge surfaces (W7 · `crm.md §12`)

✅ `crm/ContactSameAs.tsx` — renders linked-merge cards with split-button on hover per [`crm-pages.md §4.4`](crm-pages.md).

| Surface | Component | Status |
| --- | --- | --- |
| In-detail SameAs section | `ContactSameAs` (cards · split button · provenance chain) — rendered inline in Overview tab | ✅ |
| Workspace merge review queue | `in/MergeReviewDrawer.tsx` (99 lines) — `?drawer=merge-review` deep-link | ✅ |
| Confirm / Reject buttons | inside `ContactSameAs` — fires `POST /api/signal/<uid_a>:merge:<uid_b>` (or `:split:`) then PATCH `/api/identity/merge` | ✅ |
| Provenance modal | `data/KeyValueGrid` in a `Drawer` | 🧩 ~30 lines |

## §33 KPI tile

✅ `data/MetricTile.tsx` is the single tile primitive (sparkline · delta · footnote · optional `onClick`/`signalId`). `in/StatTile.tsx` removed in C9; KpiLadder and EntityDetail Network tab compose MetricTile directly.

## §34 EditableField

✅ `in/EditableField.tsx`. Routes via `POST /api/signal/<entityId>:update.<field>`. Supports the **"Use manual value" recovery** ([`crm-buttons.md §23`](crm-buttons.md)) — pass `source:'manual'` in payload.

## §35 OverflowMenu (`⋯` · CV)

✅ `in/OverflowMenu.tsx` (66 lines). Composes `ui/dropdown-menu`. Mounted in EntityActionBar last slot. Houses exactly **17 verbs** from [`crm-buttons.md §17`](crm-buttons.md): pin · follow · snooze · note · mention · tag · attach · confirm-merge · split · override-stage · use-manual · convert · translate · summarize · find-duplicates · audit-log · block. Trigger has `aria-label="Overflow menu"`.

### DetailBody variants

| Variant | Component | Status |
| --- | --- | --- |
| Stacked sections (actors) | `crm/Contact*` family (§31) | ✅ |
| Chat thread (events) | `ai-elements/conversation` + `ai-elements/message` | ✅ |
| DAG (paths) | `journey/JourneyDAG` | ✅ |
| KPI atlas (analytics) | `pulse/PulseAtlas` (variant per agent count — see §74) | ✅ |
| Document (rich body) | `ai-elements/markdown` + `MessageRenderer` | ✅ |

---

# Part V — Composer (CComp)

## §36 Composer root

✅ `in/Composer.tsx`. Wraps `ai-elements/prompt-input`.

## §37 SharedToolbar (`+ Add · 📎 Attach · 🔍 Search · model · ➤ Send`)

Slot-mapped from existing primitives:

| Slot | Component | Wire |
| --- | --- | --- |
| `+ Add` | `chat/AddMenu.tsx` ✅ | reuses TemplatePicker |
| `📎 Attach` | `chat/AttachmentsPreview.tsx` + `ai-elements/attachments.tsx` ✅ | `POST /api/signal/<id>:attach` |
| `🔍 Search` | `ui/command` inline (cmdk) | `POST /api/ask/kb:search` 🤖 |
| Model picker | `ai-elements/model-selector.tsx` ✅ | `PUT /api/settings?scope=composer:model` |
| `➤ Send` | `PromptInputSubmit` ✅ | dispatcher |

## §38-§40 ReceiverPill · TagPills · HoldoutToggle

✅ `in/composer/{ReceiverPill,TagPills,HoldoutToggle}.tsx`.

## §41 SchedulePill (planned)

🧩 ~25 lines. `ui/popover` trigger + `ui/select` (now / at / path).

## §42 GatePanel — with live source

✅ `in/composer/GatePanel.tsx`. 🔌 Wire to `POST /api/ask/gate:check` with inputs per [`crm-buttons.md §18`](crm-buttons.md):
- consent (`consent:<channel>` tag per recipient)
- cap-hit (per-channel cap from `/settings/privacy` × send history)
- suppression (`block` / `spam` / `suppress` paths)
- compliance (`gdpr` / `ccpa` / `canspam` / `tcpa` flags)

## §43 TemplatePicker · MentionPicker

✅ `composer/TemplatePicker.tsx` (cmdk, canonical). ♻️ Delete `in/composer/TemplatePicker.tsx` duplicate (§89).

🧩 **MentionPicker** (`@` trigger, CComp) — copy `composer/TemplatePicker` shape, swap `/api/templates` for `/api/export/actors?q=`. ~50 lines.

## §44 AttachmentPreview

✅ `chat/AttachmentsPreview.tsx`. Already lazy-loaded.

## §45 @mention rendering (CV · `crm-buttons.md §33`)

✅ `ai-elements/markdown` extension or `ai-elements/message` content parser handles `@<handle>` → clickable chip linking to `?preset=people&focus=<actorId>`. Internal-note variant filters chip routing to workspace team only.

## §46 Drafts — autosave + ⌘D + resume (CComp · `crm-buttons.md §19`)

✅ Backend: `web/src/lib/in/draft.ts` (`loadDraft` / `saveDraft`) hits `/api/in/drafts`.

| Behavior | Wire |
| --- | --- |
| Autosave (debounced 2s) | `useEffect` on draft state change → `saveDraft()` |
| Manual save (`⌘D`) | shortcut → `saveDraft()` |
| Resume on Drafts row click | EntityCard click → seeds composer from `loadDraft(entity.id)` |
| Discard (`Esc` after focus) | `DELETE /api/in/drafts?entityId=<id>` |

Today `Composer.tsx` already calls `loadDraft` on mount; needs autosave + ⌘D shortcut wiring.

---

# Part VI — Rich-message cards

All exist or compose from existing. Extend `chat/MessageRenderer`'s discriminated union when adding kinds; never fork.

| Card | Component | Status |
| --- | --- | --- |
| Payment | `chat/PaymentCard.tsx` | ✅ |
| LinkPreview (tracked-only · §K) | `chat/PreviewCard.tsx` or `ai-elements/inline-citation.tsx` | ✅ |
| CodeBlock (+ Run sandbox) | `ai-elements/code-block.tsx` (+ button → `POST /api/ask/runner:exec` 🤖) | ✅ |
| Quote | `chat/cards/QuoteCard.tsx` (+ `BoqQuoteCard` for BOQ pack) | ✅ |
| Calendar / Booking / Event invite | `chat/cards/CalendarCard.tsx` | ✅ |
| Approval | `ai-elements/confirmation.tsx` | ✅ |
| Voice / Video | `ai-elements/audio-player.tsx` + `ai-elements/transcription.tsx` | ✅ |
| Map | `chat/cards/MapCard.tsx` | ✅ |
| FormEmbed | extend `CardData` + new case in `MessageRenderer` | 🆕 §90 |
| System pill | `ui/separator` + centred text (~5 lines) | 🧩 |
| Domain packs (BOQ · Field service · Product · Cart · Job · Dispatch · Scoping · Service selector · Severity) | `chat/cards/*` | ✅ all exist |

---

# Part VII — Overlays

| Overlay | Component | Status |
| --- | --- | --- |
| Spotlight (⌘K) | `keyboard/Spotlight.tsx` | ✅; 🧩 quick-add parser is a regex pre-pass (CK) |
| HelpOverlay (`?`) | `keyboard/HelpOverlay.tsx` | ✅ |
| Toaster + Undo | sonner `Toaster`; `action` button on destructive verbs | 🧩 wrap dispatcher with inverse deposit (5s window) |
| ConfirmDialog (forget · reset · split · block) | `ui/dialog` + `ui/alert` + `ai-elements/confirmation` | ✅ |
| Drawer (`?drawer=<id>` deep-link) | `ui/Drawer.tsx` | ✅ |
| Sheet (mobile pushed) | `ui/dialog` with `side="bottom"` or `ui/Drawer` | ✅ |
| EmptyState (per preset) | `cards/EmptyState.tsx` + `cards/EmptyStateCard.tsx` | ✅ |
| NotificationBell | — | 🆕 §90 |
| MergeReviewDrawer (W7) | `ui/Drawer` + `ContactSameAs` list | 🧩 ~40 lines |

---

# Part VIII — Forms (drawer-mounted composites only — NOT builders)

Drawer forms are composed inputs. **Per [`crm.md §6`](crm.md), every "feature" (automation, sequence, form embed, report, booking, survey) is a template row in `settings/TemplateManager.tsx` — not a separate builder app.**

| Form | Compose from | Submit |
| --- | --- | --- |
| ChannelCreateForm (CTagMgr) | `ui/input` × 5 + `ui/select` + TagPills + buttons (~80 lines) | `POST /api/signal/channel:new` |
| PersonInviteForm | `ui/input` + `ui/select` + TagPills (~50 lines) | `POST /api/signal/team:invite` |
| **ImportCSVForm (CX · §80 HubSpot/Salesforce/GHL extension)** | dropzone + `KeyValueGrid` mapping + radio rows + dry-run preview (~140 lines) | `POST /api/signal/import:csv` multipart |
| ExportForm | `ui/dropdown-menu` (format) + checkbox list (~50 lines) | `GET /api/ask/export:csv?…` |
| FilterBuilder | repeating condition row · `ui/select` × 2 + `ui/input` (~100 lines) | `PUT /api/settings?scope=filter:<rail>` |
| SaveViewAsForm → creates a **channel** ([`crm.md §2`](crm.md) "Adding a subscription") | `ui/input` (name) + button (~30 lines) | `POST /api/signal/channel:new` |
| EnrichmentPickerDrawer | `ui/checkbox` × N + button (~40 lines) | `POST /api/signal/enricher:enrich` |
| ConsentEditor | radio groups per channel + region select (~50 lines) | `POST /api/signal/<actor>:consent` |
| **MergeReviewDrawer (W7)** | list of SameAs cards + Confirm/Reject buttons (~50 lines) | `POST /api/signal/<actor>:merge` / `:split` |

Not a form — template row:

| What people might call it | Where it actually lives |
| --- | --- |
| Automation builder | template + `then`-rules; runs in `journey/JourneyDAG` (CJ) |
| Sequence builder | chain of templates with `seq:<id>:step:<n>` |
| Report builder | atlas is data-driven by `/api/agents/[id]/analytics` (`pulse/PulseAtlas`) |
| Form builder | template `kind:form`; `/forms/<slug>` page emits signal |
| Custom field editor | tag namespace at `/settings/tags` (`settings/TagManager.tsx`, [`crm.md §5`](crm.md)) |
| Booking form | template `kind:meeting` + `attach:slots` |
| Survey / CSAT | starter template `csat-after-close` |
| Lens / persona | lens pack in `settings/PackEditor.tsx` ([`crm.md §2.4`](crm.md)) |

---

# Part IX — View-mode renderers ([`crm-pages.md §3.4a`](crm-pages.md))

When `?view=<mode>` flips, the list column swaps renderer.

| Mode | Component | Status |
| --- | --- | --- |
| List | `EntityList` (existing) | ✅ |
| Pipeline / Kanban | 🧩 columns of `crm/ContactHeader` + `@dnd-kit` (drag → `POST /api/signal/<actor>:convert:<stage>`). ~150 lines | ⏳ |
| Calendar | 🧩 grid of `chat/cards/CalendarCard.tsx` cells. ~120 lines | ⏳ |
| Map | 🧩 scale up `chat/cards/MapCard.tsx` with provider clustering. ~80 lines | ⏳ |
| Funnel | ✅ `funnel/FunnelChart.tsx` or `pulse/Funnel.tsx` | ✅ |
| Grid (cards) | 🧩 CSS grid of `cards/AgentPreviewCard` / `cards/MarketplaceMini`. ~30 lines | ⏳ |

## §74 Multi-agent atlas variants (CP)

✅ `pulse/PulseAtlas` accepts `agents?: number | AgentSummary[]` + optional `onDrill`. Branches on agent count per [`crm-buttons.md §25`](crm-buttons.md):

| Workspace state | Body |
| --- | --- |
| 0 agents | Empty state — "Spawn your first agent to see pulse metrics" |
| 1 agent | `KpiLadder` + `Funnel` + `Attribution` + `Holdout` + `FrontierBlock` |
| N agents | `pulse/AgentSelector` + workspace roll-up `MetricTile` row (`data-testid="stat-tile"` × 4) above per-agent body |

KpiLadder forwards `onDrill(kpiId)`; PulseAtlas emits `ui:pulse:drill` + calls `onDrill({rail:'inbox', preset:'analytics', filter:'kpi:<id>'})`. No new endpoint. Workspace roll-up reuses the active agent's analytics scaled by `agents.length` (single-agent fetch + multiply — N parallel fetches deferred until needed).

---

# Part X — Settings tree (CSP)

Per [`crm.md §13`](crm.md), settings = `GET/PUT /api/settings?scope=<scope>`. Most panels shipping.

| `/settings/<path>` | Component | Status |
| --- | --- | --- |
| index | `settings/SettingsView.tsx` | ✅ |
| channels | composes ChannelCreateForm rows | ⏳ ~80 lines |
| tags (namespaces + ACL + colour) | `settings/TagManager.tsx` | ✅ |
| templates | `settings/TemplateManager.tsx` | ✅ |
| packs (lens packs) | `settings/PackEditor.tsx` | ✅ |
| status (per-dimension rules) | `settings/StatusRuleEditor.tsx` | ✅ |
| list-ctas | small composition | ⏳ |
| detail-tabs | small composition | ⏳ |
| profile-completion | small composition | ⏳ |
| privacy | `settings/PrivacyControls.tsx` | ✅ |
| integrations (CX/CH) | composes `cards/ActionCard.tsx` rows | ⏳ ~120 lines |
| members | `settings/TeamManager.tsx` + `settings/ClientManager.tsx` | ✅ |
| billing | `settings/BillingSettings.tsx` + `billing/PoolCard.tsx` + `billing/Ledger.tsx` | ✅ |
| appearance | `settings/AppearanceSettings.tsx` + `settings/BrandingSettings.tsx` | ✅ |

9 of 13 shipping.

## §80 ImportCSVForm — HubSpot / Salesforce / GHL extension (CX · CH · [`crm.md §16`](crm.md))

Extends the base ImportCSVForm with five steps:

1. **Connect source** — OAuth via `/settings/integrations`
2. **Field map preview** — `KeyValueGrid` showing column → tag namespace mapping ([`crm.md §5`](crm.md))
3. **Conflict resolution** — radio per row: `overwrite` / `keep existing` / `merge by email-hash`
4. **Dry run** — `POST /api/ask/import:dry-run` returns sample resolved actors
5. **Live progress + receipt** — `useSubstrateStream({filter:'import:<id>'})` (§3)
6. **Write-through agent toggle** — `PUT /api/settings?scope=integrations` activates `export-hubspot` etc.

All five surfaces compose from existing primitives.

---

# Part XI — Onboarding

## §87 OnboardingFlow tie-in

✅ `onboarding/OnboardingFlow.tsx` exists. Trigger from `Inbox.tsx` when zero-entity state detected.

Steps emit signals — no separate UI:

| Step | Verb (dispatcher) |
| --- | --- |
| Pick lens pack | `PUT /api/settings?scope=packs` |
| Connect first channel | `POST /api/signal/channel:<id>:connect` |
| Send a tracked link | mints `/go/<id>` (§K · [`crm.md §9`](crm.md)) and opens LinkPreview |
| Spawn first agent | open `?preset=agents` HeroCTA |
| Send first broadcast | open Composer pre-filled |

Skip → `PUT /api/settings?scope=onboarding` `{done:true}`. Reset → `POST /api/signal/onboarding:reset`.

## §88 Empty states per preset (`crm-pages.md §9`)

✅ `cards/EmptyState.tsx` + `cards/EmptyStateCard.tsx`. Per-preset content map lives in `Inbox.tsx` empty-list branch. Each empty state offers the preset's HeroCTA inline.

---

# Part XII — Cleanup

## §89 Duplicates / dead code

| Issue | Action |
| --- | --- |
| `in/composer/TemplatePicker.tsx` exists alongside canonical `composer/TemplatePicker.tsx` (cmdk, imported by `Composer.tsx`) | **Delete** `in/composer/TemplatePicker.tsx` |
| ~~`in/StatTile.tsx` overlaps with richer `data/MetricTile.tsx`~~ | ✅ Resolved in C9 — MetricTile extended with optional `onClick`/`signalId`; StatTile deleted |

---

# Part XIII — The two genuinely new components

## §90

After this audit, only two components are net-new for `/in`:

| # | Component | Why net-new | Est lines | Composes from | Ships with |
| --- | --- | --- | --- | --- | --- |
| 1 | **NotificationBell** | No analog; needs unread queue dropdown bound to substrate `me:*` receivers | ~60 | `ui/dropdown-menu` + `ui/badge` + `data/ActivityFeed` rows + `useSubstrateStream` (§3) | CV / CTagMgr (admin `★` promote flow needs it) |
| 2 | **FormEmbedCard** | Extend `CardData` discriminated union + new case in `MessageRenderer` for inline `/forms/<slug>` cards | ~80 | `ui/input` + `ui/select` + `ui/button` | CX |

Everything else: **reuse** or **<100-line composition**.

---

# Part XIV — Verb → component cross-reference

## §91

Every verb in [`crm-buttons.md`](crm-buttons.md) lands on a component listed here.

| Verb | Component | Section here |
| --- | --- | --- |
| mark · warn · save · archive · complete · claim · pin · follow · block · spam | EntityActionBar + OverflowMenu | §35 |
| forget | EntityActionBar + ConfirmDialog | §56 |
| share | EntityActionBar → clipboard | §35 |
| reply · message · forward | PrimaryActionButton → Composer | §26, §36 |
| broadcast | HeroCTA + BroadcastBar | §18, §23 |
| enrich | EntityActionBar + EnrichmentPickerDrawer | §35, §66 |
| edit field | EditableField | §34 |
| **manual-value override** (recovery) | EditableField with `source:'manual'` | §34 |
| **override stage** (recovery) | OverflowMenu | §35 |
| new entity (per preset) | HeroCTA + ColumnHeader `+ New` | §18, §14 |
| new channel | ChannelCreateForm | §64 |
| invite person | PersonInviteForm | §64 |
| import / export CSV (incl HubSpot/Salesforce/GHL) | ImportCSVForm / ExportForm | §64, §80 |
| filter / save view | FilterBuilder + SaveViewAsForm | §64 |
| **automation · sequence · report · form · booking · survey** | **template row in `TemplateManager`** ([`crm.md §6`](crm.md)) | §64 |
| **custom field** | **tag namespace in `TagManager`** | §64 |
| **lens / persona** | **lens pack in `PackEditor`** | §64 |
| consent flip | ConsentEditor | §64 |
| **identity merge confirm / split** (W7) | ContactSameAs + MergeReviewDrawer | §32, §64 |
| `★` promote-to-channel | tag row + NotificationBell + ChannelCreateForm | §9, §90 |
| view-mode flip | ViewModeToggle | §16 |
| status filter | StatusTabs | §20 |
| bulk select | MultiSelectToolbar | §21 |
| notifications | NotificationBell | §90 |
| spotlight cmd-K | Spotlight | §56 |
| help cheatsheet | HelpOverlay | §56 |
| toast undo | Toaster | §56 |
| destructive confirm | ConfirmDialog | §56 |
| AI verbs (draft · summarize · next · predict · score · dedupe · classify · kb · translate) | OverflowMenu → `/api/ask/<worker>:<task>` | §35 |
| pipeline drag | KanbanBoard | §72 |
| calendar slot | CalendarGrid | §72 |
| map pin | MapView | §72 |
| funnel drill | `funnel/FunnelChart` | §72 |
| journey edit | `journey/JourneyDAG` | §35 (DAG variant) |
| **multi-agent atlas** | `pulse/PulseAtlas` + agent selector | §74 |
| settings flip | Settings panels | §78-§86 |
| Apple-Contacts sections | `crm/Contact*` | §31 |
| **activity timeline** | `crm/ContactActivity` or `data/ActivityFeed` | §30 |
| sparkline KPI | `data/MetricTile` | §33 |
| rich-message dispatch | `chat/MessageRenderer` | §2 |
| rich card types (Payment · Calendar · Quote · Map · Code · Voice · Approval · Form) | `chat/cards/*` · `chat/PaymentCard` · `ai-elements/*` | §47-§55 |
| **@mention render** | `ai-elements/message` parser → chip | §45 |
| **tracked link** ([`crm.md §9`](crm.md)) | `chat/PreviewCard` / `ai-elements/inline-citation` (renders `/go/<id>` only) | §47 |
| **drafts autosave / resume** | `Composer.tsx` + `lib/in/draft.ts` | §46 |
| live updates (6 streams) | `useSubstrateStream` | §3 |
| mobile swipe / long-press / FAB | mobile components | §5 |
| **role-gated visibility** (QW13) | `Navigation.tsx` viewer prop | §13 |
| onboarding first-run | `OnboardingFlow` | §87 |
| empty-state per preset | `EmptyState` / `EmptyStateCard` | §88 |

---

*Two new components. Two duplicates to delete. Everything else: lean on the library, `TemplateManager` for "features," `useSubstrateStream` for live updates, `lib/viewer.ts` for role gating. The CRM is the substrate doing what it already does — Apple Mail metaphor + tags + pheromone + roles cascade.*
