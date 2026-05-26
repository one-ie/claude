---
title: Chat-integrated — three views, one action layer
slug: chat-integrated
type: plan
tier: complex
mode: construction
tags: [chat, actions, layout, ui, split-view, generative-ui, roles]
source_of_truth:
  - web/chat-integrated.md
  - web/roles.md
  - web/src/layouts/Layout.astro
  - web/src/pages/api/chat.ts
  - web/src/components/ChatHost.tsx
show: false
escape:
  condition: "C2 W4 delta_tsc > 0 twice OR grep for direct DB writes outside actions/ returns > 0 after C2"
  action: "halt; re-scope action executor contract before retrying; verify all existing API routes are allowlisted or delegating"
context_triggers:
  - pattern: "chatLock|ChatHost|chat-mode|chatMode"
    inject: "web/chat-integrated.md § W1 — Findings"
  - pattern: "actions/|actionsForSurface|defineAction"
    inject: "web/chat-integrated.md § The action layer"
  - pattern: "roles.md|viewer|orgPattern|cascade"
    inject: "web/chat-integrated.md § W2 — Decisions"
---

# Chat-integrated — three views, one action layer

**Goal:** Ship one shared action layer plus three page-level view modes (split / chat-full / ui) so both the left UI and the right chat dispatch the same typed actions against the same state, ending the double-chat bug and drift between surfaces.

**Exit:** `bun run verify` green on all cycles AND browser-check confirms exactly one chat root per route AND `localStorage['one:chat-mode']='rail'` override does NOT bypass `chatLock` on any `chat="none"` page AND Lighthouse `/chat` still 100%.

---

## Dependency graph

### Cycle-level (what blocks what)

```
C1:layout ──→ C2:actions ──→ C3:split-view
                          └──→ C4:chat-full
                                   ↓
                              C5:primitives
C2:actions ──────────────────────────────→ C6:roles
```

```
C1 → C2 because C2 imports Layout.astro's new chatMode/chatSurface props (Layout.astro rewritten in C1).
C2 → C3 because C3 wires actionsForSurface() and useActionEvents() defined in C2's actions/ files.
C2 → C4 because C4 reads action.ui.inline renderer map defined in C2.
C4 → C5 because C5's per-page rebuild needs the chat-full view slot defined in C4 (Layout.astro Cycle-4 change).
C2 → C6 because C6 extends _types.ts and _filter.ts written in C2.
```

C3 and C4 run in parallel after C2. C6 runs in parallel with C3/C4/C5 after C2.

### W3 agent parallelism map (per cycle)

```
C1 W3a — parallel:
  agent-1  →  web/src/layouts/Layout.astro        # D1+D2: chatLock default + new props
  agent-2  →  web/src/components/ChatHost.tsx      # read surface/mode/entityId from dataset
  agent-3  →  web/src/components/Chat.tsx          # accept context; render ChatSurfaceIntro when empty

C1 W3b — sequential (after W3a: agent-4 needs Layout.astro from agent-1):
  agent-4  →  web/src/pages/index.astro            # migrate chat="wide" → chatMode="chat-full"
  agent-5  →  web/src/pages/studio/[agent].astro   # extend allowed chatMode values

C2 W3a — parallel:
  agent-1  →  web/src/actions/_types.ts            # defineAction, Action<I,O>, ActionContext
  agent-2  →  web/src/actions/_bus.ts              # BroadcastChannel + nanostores atoms + hook

C2 W3b — sequential (action files need _types.ts from agent-1):
  agent-3  →  web/src/actions/agents.ts
  agent-4  →  web/src/actions/skills.ts
  agent-5  →  web/src/actions/tools.ts
  agent-6  →  web/src/actions/billing.ts
  agent-7  →  web/src/actions/people.ts
  agent-8  →  web/src/actions/settings.ts
  agent-9  →  web/src/actions/index.ts             # registry + actionsForSurface
  agent-10 →  web/src/pages/api/chat.ts            # accept surface/entityId/viewer; build tools from actionsForSurface
  agent-11 →  web/src/actions/_inventory.md        # task 7.5: canonical verb list (pre-Cycle-2 task)

C3 W3a — parallel (all independent files):
  agent-1  →  web/src/components/chat/ChatSurfaceIntro.tsx
  agent-2  →  web/src/components/chat/ActionChips.tsx
  agent-3  →  web/src/pages/u/[slug]/index.astro + workspace.astro  # chatMode='split'
  agent-4  →  web/src/pages/u/[slug]/[kind]/index.astro + [name].astro
  agent-5  →  web/src/pages/u/[slug]/skills/index.astro + [name].astro
  agent-6  →  web/src/pages/u/[slug]/tools/index.astro
  agent-7  →  web/src/pages/u/[slug]/billing*.astro + people.astro + analytics.astro + settings.astro
  agent-8  →  web/src/pages/settings.astro + marketing pages

C3 W3b — sequential:
  agent-9  →  existing list components (AgentList, SkillList, …)    # useActionEvents subscriptions

C4 W3a — parallel:
  agent-1  →  web/src/components/chat/ToolResultPart.tsx
  agent-2  →  web/src/components/chat/ToolApprovalPart.tsx
  agent-3  →  web/src/components/chat/ChatModeToggle.tsx

C4 W3b — sequential (Chat.tsx reads ToolResultPart from agent-1):
  agent-4  →  web/src/components/Chat.tsx          # chat-full mode + scroll-anchor
  agent-5  →  web/src/layouts/Layout.astro         # full-bleed slot + mobile breakpoint

C5 W3a — parallel (all new component files):
  agent-1  →  web/src/components/layout/PageHeader.tsx
  agent-2  →  web/src/components/layout/SurfaceGrid.tsx
  agent-3  →  web/src/components/layout/DetailHeader.tsx
  agent-4  →  web/src/components/cards/ActionCard.tsx
  agent-5  →  web/src/components/cards/EmptyState.tsx
  agent-6  →  web/src/components/data/KeyValueGrid.tsx
  agent-7  →  web/src/components/data/MetricTile.tsx
  agent-8  →  web/src/components/data/ActivityFeed.tsx

C5 W3b — sequential (pages need primitives from W3a):
  agent-9  →  web/src/pages/u/[slug]/[kind]/index.astro              # SurfaceGrid + ActionCard
  agent-10 →  web/src/pages/u/[slug]/agents/new.astro                # scaffold wizard
  agent-11 →  web/src/pages/u/[slug]/agents/[id]/* + skills/* + tools/* + billing* + people* + analytics* + settings* + moderation* + history/* + workspace* + index*
  agent-12 →  marketing pages                                        # hero + ActionChips end-user

C6 W3a — parallel:
  agent-1  →  web/src/actions/_types.ts            # extend permission shape + ActionContext
  agent-2  →  web/src/lib/cascade.ts               # world→org→team→actor resolver

C6 W3b — sequential:
  agent-3  →  web/src/actions/_filter.ts           # actionsForSurface with orgPattern
  agent-4  →  web/src/actions/agents.ts + skills.ts + tools.ts + billing.ts + people.ts + settings.ts  # annotate scope + applyTo
  agent-5  →  web/src/components/data/KeyValueGrid.tsx  # scope-selector + 🔒 indicator
  agent-6  →  web/src/pages/api/chat.ts            # thread orgPattern + membership into context
```

---

## Status

- [x] C1 — Layout plumbing + double-chat fix ✓ DONE
- [x] C2 — Action layer scaffolding ✓ DONE (types, filter, bus, registry — but execute() stubs; see C7)
- [x] C3 — Split view (pages wired with chatMode/chatSurface) ✓ DONE
- [x] C4 — Chat-full view (generative UI layout) ✓ DONE
- [x] C5 — Shared primitives (PageHeader, SurfaceGrid, DetailHeader, ActionCard, EmptyState, KeyValueGrid, MetricTile, ActivityFeed) ✓ DONE
- [x] C6 — Role & cascade types ✓ DONE (types + generic resolver; KV wiring in C7)
- [x] C7 — Gap close: real execute() delegation + surface-scoped tools + ToolResultPart renderers + cascade KV wiring ✓ DONE

### Gap-fill pass (2026-05-15)

- [x] `web/src/lib/db/skills.ts` created — skills.ts actions now delegate via `listSkills/getSkill/putSkill/deleteSkill`
- [x] ToolResultPart renderer map expanded — 16 entries: `agent.{list,create,update,delete,publish}`, `skill.{list,import,fork,refresh,delete}`, `tool.{connect,disconnect,mcp.listExposed}`, `people.invite`, `signals.trace`, `events.tail`
- [x] Action stub messages improved — `signals.trace`/`paths.trace`/`learning.list` blocked on TypeDB client (with unblock instructions); `settings.rotateKeys`/`billing.rotateRecovery` blocked on passkey ceremony
- [x] `_inventory.md` expanded 40 → 86 verbs (added: chat, analytics, payments, moderation, webhooks, domains, artifacts, funnels)
- [x] Minimal C5 primitive adoption — `u/[slug]/workspace.astro` + `u/[slug]/[kind]/index.astro` now wrap content in `<SurfaceGrid>`; `[kind]/index.astro` uses `<PageHeader>` with breadcrumb
- [ ] **Still open:** full C5 page rebuild (13 pages); TypeDB client wiring; passkey rotation ceremonies; W4 verification (Lighthouse, design-check, browser-check, rubric scores)

---

## C1 — Layout plumbing + double-chat fix  [tier: simple]

**Exit:** `bun run verify` green AND for every `chat="none"` page in the W1 audit table, exactly one chat root in DOM; `localStorage['one:chat-mode']='rail'` reload does NOT produce a second rail.

### W1 — Recon  [Haiku · parallel]

- `web/src/layouts/Layout.astro:119-134` — current `chatLock` wiring, `chat` prop enum, html dataset attrs
- `web/src/components/ChatHost.tsx` — how it reads mode, what it forwards to `<Chat>`
- `web/src/components/Chat.tsx` — what context props it accepts today
- `web/src/pages/index.astro:10` — current `chat="wide"` usage
- `web/src/pages/studio/[agent].astro:124` — dynamic `chat={chatMode}` wiring
- `web/src/pages/u/[slug]/chat.astro:19` — missing chatLock example (representative)

### W2 — Decide  [Sonnet]

- Confirm D1: does `chat='none'` → implicit `chatLock` require any callers to pass `chatLockOverride={false}`? (grep for `chat="none"` with intent to not lock)
- Is `'wide'` used anywhere else beyond `index.astro`? If so, does migrating all → `'chat-full'` break anything?
- Does `<html data-chat-surface data-chat-mode data-chat-entity-id>` conflict with any existing `data-*` attributes `ChatHost` reads?

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/layouts/Layout.astro` — D1: `chat='none'` implies `chatLock=true` (no `chatLockOverride` callers exist); D2: add `chatMode: 'split'|'chat-full'|'rail'|'icon'|'none'`, `chatSurface`, `chatEntityId` props; keep `chat=` alias; emit `<html data-chat-surface data-chat-mode data-chat-entity-id>`
- [ ] `web/src/components/ChatHost.tsx` — read surface/mode/entityId from `document.documentElement.dataset`; forward to `<Chat>`
- [ ] `web/src/components/Chat.tsx` — accept `context: { surface, entityId }`; render `<ChatSurfaceIntro>` (stub) when conversation empty

**W3b — sequential (depend on Layout.astro from W3a):**
- [ ] `web/src/pages/index.astro` — migrate `chat="wide"` → `chatMode="chat-full"`
- [ ] `web/src/pages/studio/[agent].astro` — extend `chatMode` allowed values to `'split'|'chat-full'`

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] For every page in the W1 audit table: one chat root in DOM (run `browser-check.mjs` per route)
- [ ] `localStorage['one:chat-mode']='rail'` + reload `/u/:slug/chat` → zero rail elements outside the locked page
- [ ] grep `chat="wide"` → zero remaining callers
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  pages_fixed=14`

---

## C2 — Action layer  [tier: complex]

**Exit:** `bun run verify` green AND grep for direct DB/TypeDB writes outside `web/src/actions/` returns zero (non-allowlisted routes delegating through action executors) AND `POST /api/chat` with `{ surface: 'agents', entityId: null, viewer: 'agency' }` returns a tools manifest with `agent.create`.

### W1 — Recon  [Haiku · parallel]

- `web/src/pages/api/chat.ts` — current body shape, tool-wiring, ToolLoopAgent call
- `web/src/pages/api/agents/` — existing create/update/delete/list handlers (representative sample)
- `web/src/pages/api/skills/` — same
- `web/src/lib/viewer.ts` — existing `Viewer` enum + derivation
- `web/src/actions/` — does directory exist? If so, what's there?
- `one-ie/one/claw/` — ToolLoopAgent + tool-approval protocol shape (existing)

### W2 — Decide  [Opus]

- Confirm `@nanostores/react` is in `package.json`; if not, what's the install cost and does it conflict with anything?
- Does the current `api/chat.ts` `ToolLoopAgent` call pass tools statically or dynamically? Need dynamic per-surface manifest.
- Should `action.execute` be a server-only function (Worker) or importable client-side? (Answer: server-only; client never calls execute directly — it dispatches through the HTTP route or chat tool path.)
- Confirm task 7.5: walk CLI/API/MCP/SDK surfaces to produce `actions/_inventory.md` before writing action files — this is the canonical verb list that prevents missing verbs in Cycle 2.
- Is `BroadcastChannel` available in CF Workers SSR? (No — it's browser-only; nanostores atoms are SSR-safe; bus must be browser-only init.)

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/actions/_types.ts` — `defineAction`, `Action<I,O>`, `ActionContext { api, bus, viewer, slug }`; `permission: { tiers: Viewer[]; scope: 'self'|'workspace'|'platform' }` (spec D10 shape already decided)
- [ ] `web/src/actions/_bus.ts` — browser-only `BroadcastChannel('one:actions')` + nanostores atoms; `useActionEvents(filter)` hook
- [ ] `web/src/actions/_inventory.md` — task 7.5: walk `cli/src/`, `web/src/pages/api/`, `mcp/`, `sdk/src/`; one row per verb: source surfaces · target surfaces · current web/chat presentation · proposed prominence

**W3b — sequential (need _types.ts from W3a):**
- [ ] `web/src/actions/agents.ts` — `agent.{create,update,publish,delete,eval,validate,lint,compile,sign,verify,diff,scaffold}`
- [ ] `web/src/actions/skills.ts` — `skill.{import,fork,refresh,emit,delete,eval}`
- [ ] `web/src/actions/tools.ts` — `tool.{connect,disconnect,mcp.exposeWorkspace,mcp.toggleTool,mcp.listExposed}`
- [ ] `web/src/actions/billing.ts` — `billing.{upgrade,openInvoice,rotateRecovery,usage.bySurface}`
- [ ] `web/src/actions/people.ts` — `people.{invite,changeRole,remove}`
- [ ] `web/src/actions/settings.ts` — `settings.{rotateKeys,setTheme,setDomain}`
- [ ] `web/src/actions/auth.ts` — `auth.{listSessions,revokeSession,mintToken}`
- [ ] `web/src/actions/diagnostics.ts` — `signals.trace`, `paths.trace`, `learning.list`, `events.tail`
- [ ] `web/src/actions/index.ts` — registry keyed by surface; `actionsForSurface(surface, viewer)`
- [ ] `web/src/pages/api/chat.ts` — accept `{ surface, entityId, viewer }` in body; build AI SDK tools from `actionsForSurface`; dispatch tool calls through action executors
- [ ] existing `web/src/pages/api/agents/*`, `api/skills/*`, `api/tools/*`, `api/billing/*`, `api/people/*`, `api/settings/*` — refactor to ~5-line thin adapters calling `action.execute`

### W4 — Verify  [Haiku×5]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] grep direct DB writes outside `actions/` (non-allowlisted) → zero
- [ ] `POST /api/chat { surface:'agents', viewer:'agency' }` → tools manifest includes `agent.create`
- [ ] `agent.delete` (destructive) chat tool call → response contains `tool-approval` part, not `tool-result`
- [ ] `_inventory.md` exists with ≥ 80 verb rows
- [ ] Rubric composite ≥ 0.65 (security ≥ 0.90 — authz gate on every execute)

Report: `delta_tsc=±N  delta_loc=±N  actions_registered=N  api_routes_refactored=N`

---

## C3 — Split view  [tier: simple]

**Exit:** `bun run verify` green AND chat tool-call `agent.create` → `AgentList` re-renders with new item within 500ms (no full reload) AND form-submit on left → chat assistant receives bus event.

### W1 — Recon  [Haiku · parallel]

- `web/src/components/chat/` — existing files; is `ChatSurfaceIntro` stubbed or absent?
- `web/src/pages/u/[slug]/[kind]/index.astro:50` — current `chat="none"` + page structure
- `web/src/pages/u/[slug]/agents/` — AgentList component location and subscription pattern today
- `web/src/pages/u/[slug]/workspace.astro:52` — current page structure

### W2 — Decide  [Sonnet]

- Does `@nanostores/react` `useStore` work across `.astro` island boundaries for the bus atoms?
- Which pages already have meaningful left-side content vs. placeholder lists? (Determines rebuild scope delta C3 vs. C5.)
- `ChatSurfaceIntro` chips — pull from `actionsForSurface` at render time (server-side) or at mount (client-side)? (Answer: server-side for SSR; client can re-filter if viewer changes.)

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/components/chat/ChatSurfaceIntro.tsx` — chips from `actionsForSurface(surface, viewer)`; chip click seeds input with `action.chat.prompt`
- [ ] `web/src/components/chat/ActionChips.tsx` — reusable chip row; used by ChatSurfaceIntro + left-side EmptyState CTAs
- [ ] `web/src/pages/u/[slug]/index.astro` + `workspace.astro` — `chatMode='split'` + `chatSurface`
- [ ] `web/src/pages/u/[slug]/[kind]/index.astro` + `[name].astro` — `chatMode='split'` + `chatSurface={kind}|{kind}-detail`
- [ ] `web/src/pages/u/[slug]/skills/index.astro` + `[name].astro` — `chatMode='split'`
- [ ] `web/src/pages/u/[slug]/tools/index.astro` — `chatMode='split'`
- [ ] `web/src/pages/u/[slug]/billing*.astro` + `people.astro` + `analytics.astro` + `settings.astro` + `moderation.astro` + `history/[entry].astro` — `chatMode='split'` + matching surface
- [ ] `web/src/pages/settings.astro` + marketing pages (`agents.astro`, `skills.astro`, `tools.astro`, `payments.astro`, `marketplace.astro`, etc.) — `chatMode='split'` + `viewer='end_user'`

**W3b — sequential (need chatSurface on pages from W3a for routing):**
- [ ] left-side list components (`AgentList`, `SkillList`, any others) — subscribe via `useActionEvents`; refresh/patch on `agent.created | agent.deleted | agent.updated` etc.

### W4 — Verify  [inline]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `document.documentElement.dataset.chatSurface` matches expected value on each split-mode page
- [ ] Chat tool `agent.create` → `AgentList` re-renders within 500ms (no reload)
- [ ] Left form-submit → chat bus event received (check `BroadcastChannel` listener fires)
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  pages_wired=N`

---

## C4 — Chat-full view (generative UI)  [tier: complex]

**Exit:** `bun run verify` green AND on `/u/:slug/agents` in `chat-full` mode, `agent.list` tool-result renders `AgentList` inline AND `split ↔ chat-full` toggle preserves chat history without remount jank AND Lighthouse `/chat` still 100%.

### W1 — Recon  [Haiku · parallel]

- `web/src/components/Chat.tsx` — current render tree; how tool-result parts are handled today
- `one-ie/one/claw/` — AI SDK v6 tool-approval part shape + `createAgentUIStreamResponse`
- `web/src/layouts/Layout.astro` — main/aside slots; how content and chat are rendered (post-C1)
- `web/src/pages/u/[slug]/chat.astro:19` — existing full-page chat (model for `chat-full` mode)

### W2 — Decide  [Opus]

- How does AI SDK v6 `tool-approval` part reach the client? Is the existing `claw` streaming response format compatible, or does `chat.ts` need changes?
- Full-bleed in Layout: does the existing slot system support conditionally hiding `<main>` and stretching the chat slot, or does it need a new layout variant?
- Scroll-anchor: which scroll-anchor approach (IntersectionObserver vs. scroll-lock flag) is already in `Chat.tsx`? Extend or replace?
- `ChatModeToggle` — persists per-surface in localStorage. Key format: `one:chat-mode:{surface}`.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/components/chat/ToolResultPart.tsx` — maps `tool.id` → `action.ui.inline`; renders `Component(result)` inline; lazy-imports renderer per tool-id
- [ ] `web/src/components/chat/ToolApprovalPart.tsx` — destructive-action confirm gate; "Approve" → calls executor; "Deny" → no-op; `bg-destructive text-on-destructive` per `design.md`
- [ ] `web/src/components/chat/ChatModeToggle.tsx` — header control; toggles `split ↔ chat-full`; persists `one:chat-mode:{surface}` in localStorage

**W3b — sequential (Chat.tsx needs ToolResultPart from W3a; Layout needs chat-full slot logic):**
- [ ] `web/src/components/Chat.tsx` — `chatMode='chat-full'`: full-bleed; render `ToolResultPart` + `ToolApprovalPart` per stream part; scroll-anchor: don't yank viewport when tall component streams and user is scrolled up
- [ ] `web/src/layouts/Layout.astro` — `chatMode='chat-full'`: hide `<main>` slot, stretch chat full-bleed; `<768px` force `chatMode='chat-full'`

### W4 — Verify  [Haiku×5]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `/u/:slug/agents` in `chat-full`: `agent.list` tool-result renders `AgentList` inline
- [ ] Destructive action via chat → `tool-approval` part; "Approve" runs; "Deny" leaves state unchanged
- [ ] `split ↔ chat-full` toggle: chat history preserved, page content hides/shows, no remount jank
- [ ] Reload mid-conversation: tool-result components rehydrate from message history with same props
- [ ] Lighthouse `/chat` 100% (run via `npx lighthouse`)
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  lighthouse_chat=100  tool_renderers=N`

---

## C5 — Shared primitives + per-page rebuild  [tier: complex]

**Exit:** `bun run verify` green AND Lighthouse ≥95 perf / 100 a11y / 100 best / 100 seo on every rebuilt page AND `.claude/hooks/design-check.sh` emits zero violations across `web/**/*.{tsx,astro,css}`.

### W1 — Recon  [Haiku · parallel]

- `web/src/components/` — existing component tree; what's already in `cards/`, `layout/`, `data/`?
- `web/src/pages/u/[slug]/[kind]/index.astro` — current bare `<ul>` structure (representative)
- `web/src/pages/u/[slug]/billing.astro` — existing `PoolCard` + `Ledger` + `TopUpModal` structure to preserve
- `web/design.md` — token list, card/input patterns (confirm current)
- `.claude/hooks/design-check.sh` — what it greps and what it allows

### W2 — Decide  [Opus]

- Do any existing components (`PoolCard`, `Ledger`, `AgentList`) map cleanly onto the 9 new primitives, or do they need to be wrapped vs. replaced?
- `<MetricTile>` sparkline — use a third-party lib (e.g. `recharts`) or CSS-only? (`recharts` is large; prefer CSS clip-path sparkline or SVG polyline from raw data — confirm bundle budget: chat-view delta < 30 KB gzip per W4.)
- `<EmptyState>` illustration — SVG inline or lucide icon arrangement? (Lucide only per `design.md`.)
- `<DetailHeader>` sticky: CF Workers SSR doesn't support `position:sticky` differently — confirm it's a pure CSS concern.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (all new files):**
- [ ] `web/src/components/layout/PageHeader.tsx` — title + breadcrumb + 1 hero chip + overflow "..." + `<ChatModeToggle>`
- [ ] `web/src/components/layout/SurfaceGrid.tsx` — 12-col grid; main + optional aside; collapses < 1024px
- [ ] `web/src/components/layout/DetailHeader.tsx` — sticky entity header: name + status + slug + 3-4 primary actions + last-changed
- [ ] `web/src/components/cards/ActionCard.tsx` — L1 card shell per `design.md`; badge/meta/primary/destructive props; `bg-background border rounded-2xl`
- [ ] `web/src/components/cards/EmptyState.tsx` — lucide icon + headline + `<ActionChips>` (sourced from action registry)
- [ ] `web/src/components/data/KeyValueGrid.tsx` — label/value pairs; copy button; inline-edit on hover; scope-selector stub (scope lock lands in C6)
- [ ] `web/src/components/data/MetricTile.tsx` — big number + delta + sparkline (SVG polyline) + footnote
- [ ] `web/src/components/data/ActivityFeed.tsx` — reverse-chrono entries: icon + actor + verb + target + timestamp

**W3b — sequential (pages need primitives from W3a):**
- [ ] `web/src/pages/u/[slug]/[kind]/index.astro` — `<SurfaceGrid>` of `<ActionCard>`s + `<EmptyState>` + `<PageHeader>` with "New {kind}" primary
- [ ] `web/src/pages/u/[slug]/agents/new.astro` — two-column wizard: template gallery (left) + live scaffolded preview (right)
- [ ] `web/src/pages/u/[slug]/agents/[id]/{analytics,funnel}.astro` + `actor/[actorId].astro` — unified `<DetailHeader>` + tab strip
- [ ] `web/src/pages/u/[slug]/skills/{index,[name]}.astro` — grid + detail tabs (Spec/Versions/Calls/Forks)
- [ ] `web/src/pages/u/[slug]/tools/index.astro` — grouped Connected/Available/MCP sections; MCP-exposure toggle
- [ ] `web/src/pages/u/[slug]/billing.astro` + sub-billing — 3-card hero (Balance/Plan/Recovery) + ledger feed + tabs
- [ ] `web/src/pages/u/[slug]/people.astro` — members table + pending-invite section
- [ ] `web/src/pages/u/[slug]/analytics.astro` — 4 `<MetricTile>`s + path leaderboard + hypothesis log
- [ ] `web/src/pages/u/[slug]/settings.astro` + `web/src/pages/settings.astro` — sectioned `<KeyValueGrid>` with danger zone
- [ ] `web/src/pages/u/[slug]/moderation.astro` — flagged-queue `<ActivityFeed>` with inline action buttons
- [ ] `web/src/pages/u/[slug]/history/[entry].astro` — metadata grid + signal-trail feed
- [ ] `web/src/pages/u/[slug]/{workspace,index}.astro` — 4 metric tiles + next-best-action chips
- [ ] `web/src/pages/u/[slug]/onboarding.astro` — switch to `chatMode='chat-full'`
- [ ] marketing pages — hero + 3-step explainer + `<ActionChips>` end-user filtered
- [ ] `web/src/pages/index.astro` — `chatMode='chat-full'`; "Skip to website" toggle

### W4 — Verify  [Haiku×5]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `.claude/hooks/design-check.sh` → zero violations across `web/**/*.{tsx,astro,css}`
- [ ] Lighthouse ≥95 perf / 100 a11y / 100 best / 100 seo on every rebuilt page (run batch via `browser-check.mjs`)
- [ ] Visual regression: every rebuilt page in split + chat-full + ui modes — no layout breaks
- [ ] Action chips on every page resolve through `actionsForSurface` — grep for hardcoded action label strings → zero
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  pages_rebuilt=N  lighthouse_min_perf=N`

---

## C6 — Role & cascade plumbing  [tier: complex]

**Exit:** `bun run verify` green AND negative test: `client` tier direct API call to agency-only action → 403 AND cascade lock test: `agency` locks theme at workspace scope → `client` viewing same workspace sees 🔒 on theme picker AND pattern test: toggle `siteConfig.pattern` from `solo` to `team` → `people.*` actions appear in registry filter.

### W1 — Recon  [Haiku · parallel]

- `web/src/lib/viewer.ts` — current `Viewer` enum, derivation logic
- `web/src/actions/_types.ts` — current `permission` shape (post-C2)
- `web/src/actions/index.ts` — current `actionsForSurface` signature (post-C2)
- `web/roles.md` — §4 (cascade), §7 (per-surface matrix), §9 (locking grammar)
- `web/src/components/data/KeyValueGrid.tsx` — current scope-selector stub (post-C5)

### W2 — Decide  [Opus]

- `lib/cascade.ts` — does it need to hit TypeDB or is workspace config (D1/KV) sufficient for v1? (Answer: KV snapshot for speed; TypeDB query for precision on first load only.)
- `partner` tier: confirm interpretation (b) — membership role on group, not 5th tier — and that `ctx.membership.role` is sufficient for gate checks. If (a) is needed, flag to `roles.md` owner and halt C6.
- Server-side scope gate location: middleware in action executor wrapper, or per-action? (Wrapper preferred — zero chance of action forgetting to check.)

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/actions/_types.ts` — extend `permission` to `{ tiers: Viewer[]; scope: 'self'|'workspace'|'platform' }`; `ActionContext` adds `workspace: { slug, pattern, ownerSlug }`, `membership?: { role: 'owner'|'member'|'partner' }`
- [ ] `web/src/lib/cascade.ts` — resolver: world → org → team → actor; returns `{ value, lockedBy?: 'world'|'org'|'team' }`; reads KV snapshot first, TypeDB on miss

**W3b — sequential:**
- [ ] `web/src/actions/_filter.ts` — `actionsForSurface(surface, viewer, orgPattern)` — orgPattern from `siteConfig.pattern`; pattern hides non-applicable actions (Solo hides `people.*`, Enterprise hides self-service signup, etc.)
- [ ] `web/src/actions/agents.ts` + `skills.ts` + `tools.ts` + `billing.ts` + `people.ts` + `settings.ts` — annotate each with correct `scope`; add `applyTo: z.enum(['workspace','me'])` on cascade-participating inputs
- [ ] `web/src/components/data/KeyValueGrid.tsx` — scope-selector pill when action permits both; 🔒 indicator + tooltip when `lockedBy` set
- [ ] `web/src/pages/api/chat.ts` — thread `orgPattern` and `membership` into `ActionContext` so server-side gate matches client-side filter
- [ ] server-side gate in action executor wrapper — enforce `scope='self'` ⇒ `target.ownerSlug === ctx.actor.slug`; emit substrate `warn` on denied (Rule 1 compliance)

### W4 — Verify  [Haiku×5]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Negative test per scope: `client` tier HTTP call to `agent.delete` (agency-only) → 403; via chat tool-call → tool result `denied`
- [ ] Cascade lock: agency locks theme at workspace scope → client sees 🔒 on theme picker; client's `applyTo='me'` for non-locked attrs still works
- [ ] Pattern test: `siteConfig.pattern = 'solo'` → `people.*` absent in registry; `'team'` → present
- [ ] Every denied action emits substrate `warn` (grep for `warn(` calls in gate path)
- [ ] Rubric composite ≥ 0.65 (security ≥ 0.92 — scope gate + deny logging)

Report: `delta_tsc=±N  delta_loc=±N  actions_annotated=N  denied_events_verified=yes`

---

## C7 — Gap close: real delegation + surface-scoped tools + renderers + cascade KV  [tier: complex]

**Exit:** `bun run verify` green AND `POST /api/chat { surface:'agents', viewer:'agency' }` tool call `agent.create` executes without throwing AND `ToolResultPart` renders `AgentList` inline for `agent.list` result AND `siteConfig.pattern='solo'` hides `people.*` from chat tools AND cascade KV wired end-to-end.

### What's actually done (verified)

- Layout props + data-* attrs: ✓
- ChatHost reads dataset: ✓
- ChatModeToggle localStorage: ✓
- _types.ts, _filter.ts, _bus.ts: ✓
- actionsForSurface registry: ✓
- All UI primitives (PageHeader, SurfaceGrid, DetailHeader, ActionCard, EmptyState, KeyValueGrid, MetricTile, ActivityFeed): ✓
- API adapters (agents/skills/tools): thin but real ✓
- Pages wired with chatMode/chatSurface: ✓

### What's stubbed (needs real implementation)

| File | Gap |
|------|-----|
| `web/src/actions/agents.ts` | All 12 execute() throw — need to call existing api/agents handlers or D1 directly |
| `web/src/actions/skills.ts` | All 6 execute() throw — call api/skills |
| `web/src/actions/tools.ts` | All 5 execute() throw — call api/tools |
| `web/src/actions/billing.ts` | All 4 execute() throw |
| `web/src/actions/people.ts` | All 3 execute() throw |
| `web/src/actions/settings.ts` | All 3 execute() throw |
| `web/src/actions/auth.ts` | All 3 execute() throw |
| `web/src/actions/diagnostics.ts` | All 4 execute() throw |
| `web/src/pages/api/chat.ts` | Tools are inline ad-hoc defs — not wired to actionsForSurface(); surface/entityId not used to scope tools |
| `web/src/components/chat/ToolResultPart.tsx` | Renders JSON string only — no action.ui.inline renderer map |
| `web/src/lib/cascade.ts` | Generic stub — not wired to CF KV; resolveWithCascade() takes abstract store not env.KV |

### W1 — Recon  [Haiku · parallel]

- `web/src/pages/api/chat.ts:80-120` — exact body shape, tool definitions, ToolLoopAgent call
- `web/src/pages/api/agents/index.ts` + `[id].ts` — exact D1 query signatures available to delegate to
- `web/src/pages/api/skills/index.ts` + `[name].ts` — same
- `web/src/pages/api/tools/index.ts` — same
- `web/src/lib/viewer.ts` — Viewer enum values (owner/agency/client/end_user + how derived from request)
- CF env types — confirm `env.DB` (D1), `env.KV` (KVNamespace) types available in Workers context

### W2 — Decide  [Sonnet]

- Action execute() strategy: (a) call existing api handler functions directly (import and call), (b) duplicate D1 query inline, or (c) call self via fetch('/api/agents')? → (a) preferred — extract shared query functions from api handlers into `lib/db/agents.ts` etc., both api route and action execute() call those.
- ToolResultPart renderer map: (a) static map `{ 'agent.list': AgentList, 'skill.list': SkillList }` lazy-imported, or (b) dynamic import by tool id? → (a) static map, lazy() per entry.
- chat.ts tool wiring: replace inline tool defs with `actionsForSurface(surface, viewer).map(actionToAITool)` helper — confirm AI SDK tool shape matches.
- cascade.ts KV wiring: wrap `env.KV` in the `CascadeStore` interface at call site (in api/chat.ts or action executor) — no need to change cascade.ts itself.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `web/src/lib/db/agents.ts` — extract `listAgents(db, slug)`, `createAgent(db, slug, data)`, `getAgent(db, id)`, `updateAgent(db, id, data)`, `deleteAgent(db, id)` from api/agents handlers
- [ ] `web/src/lib/db/skills.ts` — extract `listSkills(r2, slug)`, `getSkill(r2, name)` from api/skills handlers
- [ ] `web/src/lib/db/tools.ts` — extract `listConnections(db, slug)` from api/tools handlers
- [ ] `web/src/lib/actions-to-tools.ts` — `actionToAITool(action, ctx)` converts Action → AI SDK tool definition; wraps execute() with auth gate; emits substrate warn on denied
- [ ] `web/src/components/chat/ToolResultPart.tsx` — static renderer map: `agent.list → AgentList`, `agent.create → AgentPreviewCard`, `skill.list → SkillList`; each lazy-imported; fallback to JSON display

**W3b — sequential (need lib/db/* from W3a):**
- [ ] `web/src/actions/agents.ts` — real execute(): `agent.create` → `createAgent(ctx.api.env.DB, ctx.slug, input)`; `agent.list` → `listAgents()`; `agent.update/delete/publish` → matching db helpers; `agent.eval/validate/lint/compile/sign/verify/diff/scaffold` → delegate to existing api routes via fetch or stub with meaningful error
- [ ] `web/src/actions/skills.ts` — real execute(): `skill.import` → `getSkill()`; `skill.list` → `listSkills()`; others fetch existing api routes
- [ ] `web/src/actions/tools.ts` — real execute(): `tool.connect/disconnect` → `listConnections()` + D1 writes; `mcp.*` → KV writes
- [ ] `web/src/actions/people.ts` — real execute(): D1 membership table reads/writes
- [ ] `web/src/actions/billing.ts` — real execute(): `billing.upgrade` → existing billing route; `billing.usage` → D1 query
- [ ] `web/src/actions/settings.ts` — real execute(): `settings.setTheme` → KV write via cascade; `settings.setDomain` → D1 write; `settings.rotateKeys` → stub with explicit TODO
- [ ] `web/src/actions/auth.ts` — real execute(): `auth.listSessions` → Better Auth session query; `auth.revokeSession` → Better Auth revoke; `auth.mintToken` → stub with explicit TODO
- [ ] `web/src/actions/diagnostics.ts` — real execute(): `signals.trace` + `paths.trace` → TypeDB queries; `events.tail` → D1 query; `learning.list` → TypeDB query
- [ ] `web/src/pages/api/chat.ts` — replace inline tool defs with `actionsForSurface(surface, viewer).map(a => actionToAITool(a, ctx))`; wire `orgPattern` from KV/D1 site config; keep existing Groq/Workers routing, billing, threading untouched
- [ ] `web/src/lib/cascade.ts` — add `kvStore(kv: KVNamespace): CascadeStore` factory so call sites can do `resolveWithCascade(key, base, kvStore(env.KV))`

### W4 — Verify  [inline]

- [ ] `bun run verify` (typecheck) green, delta_tsc ≤ 0
- [ ] `POST /api/chat { surface:'agents', viewer:'agency' }` → tools manifest includes `agent.create` and `agent.list`
- [ ] Chat tool call `agent.list` → result returned (no throw); `ToolResultPart` renders AgentList inline
- [ ] Chat tool call `agent.delete` → `tool-approval` part (destructive gate fires)
- [ ] `siteConfig.pattern = 'solo'` → `people.*` absent from chat tools list
- [ ] `cascade.ts` KV round-trip: set `cascade:team:theme`, call `resolveWithCascade` → returns locked value
- [ ] `client` tier HTTP call to `agent.delete` → 403
- [ ] Rubric composite ≥ 0.65 (security ≥ 0.90)

Report: `delta_tsc=±N  execute_stubs_closed=N  tool_renderers=N  cascade_wired=yes`

---

## See also

- `web/chat-integrated.md` — full spec with W1 findings, W2 decisions, W3 task table, W4 checks
- `web/roles.md` — four-tier model, cascade spec, locking grammar (§4, §9)
- `web/design.md` — 6 tokens, card/input/button patterns (enforced by design-check.sh hook)
- `one/dictionary.md` — canonical names (always)
- `one/rubrics.md` — scoring bands (always)
- `one-ie/one/claw/` — ToolLoopAgent + tool-approval protocol shape (AI SDK v6 reference)
