---
name: chat-integrated
description: Three view modes (split / chat-full / ui) over a shared action layer — left UI and chat stream the same verbs against the same state
status: planning
owner: web
mode: full
lifecycle: construction
---

# Chat-integrated — three views, one action layer

**One sentence.** Every page exposes the same verbs through two renderers (traditional UI on the left, chat on the right, or chat alone in full-bleed generative-UI mode), backed by one shared action layer and one event bus, so both surfaces see the same state.

---

## Problem

Today the chat is decorative. The page owns the real verbs (forms, buttons, API calls); the chat is a separate stack that talks to an LLM that talks to its own tools. They drift. Three concrete symptoms:

1. **Double-chat bug.** Pages that own a full-bleed `<Chat fullPage>` (e.g. `/u/[slug]/chat`, `share/[tid]`, `studio/ptcorp-dashboard`) can still get a rail chat stacked on top when `localStorage['one:chat-mode']` is set. They're missing `chatLock`.
2. **Generic rail chat.** `/u/[slug]/agents`, `…/skills`, `…/tools` show the same blank-prompt rail as the homepage. No page-aware suggestions, no entity context.
3. **No parity.** If a user creates an agent through the chat, the left-side list doesn't refresh. If they edit a form on the left, the chat doesn't know. Two surfaces, two stacks, drift.

**Outcome.** One chat per page. Three view modes the user can toggle. Both renderers dispatch the same typed actions against the same store. Destructive actions go through the same approval gate either way.

---

## Three view modes

```
┌────────────────────────────────────────────────────────────────┐
│ mode: 'split'      left = traditional UI    right = rail chat  │
│                    (forms, lists, cards)    (page-scoped)      │
├────────────────────────────────────────────────────────────────┤
│ mode: 'chat-full'  full-bleed chat. No page content visible —  │
│                    the chat IS the page. Agent streams the     │
│                    same action components into the conversation│
│                    (generative UI via AI SDK tool-result parts)│
├────────────────────────────────────────────────────────────────┤
│ mode: 'ui'         traditional UI only. No chat. (= today's    │
│                    chat='none' + chatLock)                     │
└────────────────────────────────────────────────────────────────┘
```

`chat-full` (renamed from the working draft's `chat`, and superseding today's `chat="wide"`) is the immersive mode: nothing else on the page, the conversation is the entire surface, and any UI the user needs streams in as components — same components the split view mounts on the left.

Header control toggles `split ↔ chat-full` on pages where both are wired. Frontmatter sets the page default. Mobile collapses `split` → `chat-full` below ~768px (chat is the primary surface; the same components stream inline).

Replaces the current `chat: 'wide' | 'rail' | 'icon' | 'none'` with `chat: 'split' | 'chat-full' | 'rail' | 'icon' | 'none'`. `'wide'` is dropped — superseded by `'chat-full'`.

---

## The action layer (the load-bearing piece)

Every page-level verb is an `Action`: a typed, permissioned, idempotent operation with two or three renderers and one executor.

```ts
// web/src/actions/agents.ts
export const agentCreate = defineAction({
  id: 'agent.create',
  surface: 'agents',
  input: z.object({ name: z.string().min(2), template: z.string().optional() }),
  permission: ['owner', 'agency'],
  destructive: false,
  execute: async (input, ctx) => {
    const agent = await ctx.api.agents.create(input)
    ctx.bus.emit({ type: 'agent.created', agent })
    return agent
  },
  ui: {
    form:   AgentCreateForm,    // left-side mount (split view)
    card:   AgentCard,          // list-item mount (split view)
    inline: AgentInlineEditor,  // streams into chat (chat-full view)
  },
  chat: {
    prompt: 'Help me create an agent — ask what it should do, then call agent.create.',
    expose: 'tool',             // exposed as an AI SDK v6 tool with the same input schema
  },
})
```

- **Same schema, same executor, two/three renderers.** Drift impossible.
- **`form` and `inline` are usually the same component** with different chrome. Wrap once.
- **`destructive: true`** routes the chat call through the AI SDK v6 tool-approval protocol — the user sees the same "Are you sure?" gate they'd see clicking a destructive button. Already supported by `claw`.
- **Filtering for chips/forms** is `actions.filter(a => a.surface === current && permitted(a, viewer))`. The "quick-action registry" from the prior draft of this doc collapses into this.

Files:

```
web/src/actions/
├── _types.ts          defineAction, Action<I,O>, ActionContext
├── _bus.ts            page-scoped event bus (BroadcastChannel + nanostores atoms)
├── agents.ts          agent.* verbs
├── skills.ts          skill.* verbs
├── tools.ts           tool.* verbs
├── billing.ts         billing.* verbs
├── people.ts          people.* verbs
└── index.ts           registry: all actions, keyed by surface
```

---

## The event bus (the parity glue)

One `BroadcastChannel('one:actions')` per tab, mirrored into nanostores atoms. Every `action.execute` emits a typed event. Both surfaces subscribe:

- Left UI: `<AgentList>` listens for `agent.created | agent.deleted | agent.updated`, re-fetches or patches optimistic state.
- Chat: when a tool-result lands, the action layer dispatches through the bus (not by direct call) — the left side updates as if the user had used the form. Symmetric.

Form mutations on the left also go through `action.execute`, so the chat sees them too (and the agent can narrate "Looks like you just published v3 — want me to run evals?").

---

## URL & selection contract

- Page route encodes which surface (`/u/:slug/agents/:id` → `surface=agent-edit`, `entityId=:id`).
- Lists with selection (e.g. agent list) update a query param on click (`?selected=…`) — the chat reads it as additional context without forcing a full route change.
- Chat-driven state changes that affect what's visible (filters, selection) push the matching URL — refresh and share work.

---

## What rides through `/api/chat`

The page sends a `tools` manifest derived from `actionsForSurface(surface, viewer)`. The LLM can only call those tools. Tool schemas come from the actions' `input` Zod. On the server, the chat endpoint dispatches matched tool calls through the **same** action executors the UI uses — so server-side tools and HTTP routes share one path. No two stacks.

```
client                          server
─────────────────────────────────────────────────
useChat({ body: { surface,
                  entityId,
                  viewer } })
                          ──▶  POST /api/chat
                                  loads actionsForSurface(...)
                                  builds AI SDK tools from action.input
                                  ToolLoopAgent runs
                                    tool call → action.execute
                                    emit bus event
                          ◀──  stream tool-result parts
useChat renders tool-result
  → tool.id maps to action.ui.inline
  → renders Component(result) inline
```

Generative UI is "the agent calls a tool, the tool's result includes structured data, the client renders the action's `inline` component with that data." Same components in both views.

---

## Groups, tiers, and per-segment UX

The role model is already locked in [`roles.md`](roles.md) — don't re-derive it here. The action layer must respect five mechanics from that spec.

### 1. The four tiers (current — locked)

```
owner ⊃ agency ⊃ client ⊃ end_user      (additive downward)
```

Derived in `src/lib/viewer.ts` from session + slug comparison. Every action carries a `permission: Viewer[]` list; `actionsForSurface(surface, viewer)` filters by viewer ∈ permission. Already covered by the plan.

### 2. Ownership predicate (gap — needs adding)

`permission: ['owner', 'agency']` is too coarse. An `agency` viewer can `agent.delete` *their own* agent but not another agency's. The action's permission check needs a predicate, not just a tier list:

```ts
permission: {
  tiers: ['owner', 'agency'],
  scope: 'self',      // 'self' | 'workspace' | 'platform'
  // executor receives ctx.actor + ctx.workspace; gate is owns(actor, target)
}
```

The viewer-tier filter (above) decides "is this action even visible." The scope predicate decides "does this specific instance apply." Both gates run server-side on `action.execute`; client-side renders the appropriate disabled/hidden state.

### 3. Cascade-aware actions (gap — needs adding)

`roles.md` §4 specifies the white-label cascade: world → org → team → individual. Many actions write to one of these scopes, and a higher scope can lock the lower one. The action layer needs an explicit `target` scope on inputs that participate:

```ts
settings.setTheme.input = z.object({
  theme: z.enum([...]),
  applyTo: z.enum(['workspace', 'me']).default('me'),  // 'workspace' = agency-only; 'me' = anyone
})
```

UI consequence: `<KeyValueGrid>` settings rows render a scope selector ("Apply to: workspace / just me") when the action permits both, and render a 🔒 indicator with the source scope when a higher tier has locked the value (per `roles.md` §9 locking grammar).

### 4. Org patterns shape navigation, not actions (clarification)

The 5 patterns in `roles.md` §3 (Solo / Agency / Team / Enterprise / Network) change *which actions are surfaced per page*, not the actions themselves. The filter becomes `actionsForSurface(surface, viewer, orgPattern)`. Concretely:

| Pattern | Adds | Hides |
| --- | --- | --- |
| Solo | nothing | `people.*`, team-billing splits |
| Agency | `client.*` (provisioning), white-label settings | nothing |
| Team | `team.create`, `team.changeRole` | client-onboarding flows |
| Enterprise | SSO config, audit log, billing-platform | self-service signup chips |
| Network | federation, cross-workspace path sharing | per-workspace billing |

Pattern is read from the workspace config (`siteConfig.pattern`) — already exists per `roles.md` §5.

### 5. Per-segment UX (what each viewer sees on each surface)

Roles.md §7 already has the full matrix. Mapping it to view modes:

| Surface | `owner` | `agency` | `client` | `end_user` |
| --- | --- | --- | --- | --- |
| `/u/[slug]/index` | `split` — platform admin tiles + workspace overview | `split` — workspace dashboard (their own) | `split` — read-only workspace profile | `chat-full` — public profile chat |
| `/u/[slug]/agents` | `split` — all agents + admin actions | `split` — own agents + CRUD | `split` — visible agents only, read-only cards | redirect → `/u/[slug]/chat` (already in code) |
| `/u/[slug]/skills` | `split` — full registry | `split` — own + imported | redirect → chat | redirect → chat |
| `/u/[slug]/tools` | `split` — connect any | `split` — connect for workspace | redirect → chat | redirect → chat |
| `/u/[slug]/billing` | `split` — platform view (`/billing/platform`) | `split` — own bills + plan | n/a | n/a |
| `/u/[slug]/people` | `split` — full member list across workspaces | `split` — workspace members + invite | read-only | n/a |
| `/u/[slug]/settings` | `split` — platform + workspace | `split` — workspace cascade | read-only own prefs | `split` (top-level `/settings` only) — own prefs |
| `/u/[slug]/chat` | `chat-full` — admin-toned chat | `chat-full` — workspace chat | `chat-full` — client chat | `chat-full` — public chat |
| Marketing pages (`/agents`, `/skills`, …) | `split`, viewer-filtered | `split` | `split` | `split` |

End-user redirects already enforced in page frontmatter (e.g. `pages/u/[slug]/[kind]/index.astro:31-33`). The action filter handles the rest — client tier sees the same `<ActionCard>` but with destructive actions disabled and a "Request access" chip in place of "Edit."

### 6. Open question — `partner` tier

The current viewer enum is `owner | agency | client | end_user` (locked in `viewer.ts`). User mentioned "partner." Two interpretations:

- **(a) A 5th tier between agency and client** — resellers, affiliates, BOQ-style JV collaborators who manage workspaces *for* an agency but aren't the workspace owner. Would land between `agency` and `client` in the additive chain.
- **(b) A group dimension, not a tier** — partner is a *relationship type* (membership role) within an existing tier, e.g. an `agency` who has `partner` membership in another org's workspace. No new tier; just richer group memberships.

Recommendation: **(b)**, because adding a 5th tier breaks the locked `roles.md` model and the `viewer.ts` derivation, and partners in practice are agencies operating on someone else's workspace — exactly what the group/membership dimension already captures. We'd add a `membership.role` field (`owner | member | partner`) on the workspace group, and the viewer tier stays the four locked. Action permission checks can additionally read `ctx.membership.role` for partner-specific gates.

If (a) is the right call, it's a `roles.md` change, not a `chat-integrated.md` change — flag back to the spec owner before extending here.

---

## Discoverability without clutter

**Two competing goals.** Every verb reachable from every surface (functional completeness). UI stays calm and gets the user to value fast (no button soup).

**Resolution: four tiers of prominence.** Every action picks exactly one tier per surface. The page never renders more than ~3 things at the top level.

```
┌──────────────────────────────────────────────────────────────────┐
│ Tier 1 — Hero          one primary CTA. The thing this user, on  │
│                        this page, in this state, most wants next.│
│                        Big button, brand fill, top-right.        │
├──────────────────────────────────────────────────────────────────┤
│ Tier 2 — Quick         2-3 secondary chips. Most-used verbs for  │
│                        this surface, by frequency. Calm chrome.  │
├──────────────────────────────────────────────────────────────────┤
│ Tier 3 — Overflow      "..." menu. Everything else available on  │
│                        this surface, grouped + searchable.       │
├──────────────────────────────────────────────────────────────────┤
│ Tier 4 — Palette /     Cmd-K opens fuzzy search over ALL verbs   │
│ Chat                   the user is permitted, anywhere. Chat     │
│                        rail's empty-state shows 3 chips; chat    │
│                        knows everything else via tools.          │
└──────────────────────────────────────────────────────────────────┘
```

### How an action picks a tier

Default tier is **Tier 3 (overflow)**. To earn promotion to Tier 1 or 2, the action's metadata must declare why:

```ts
prominence: {
  default: 'overflow',           // tier 3 unless promoted
  hero: ['agents:empty'],        // tier 1 when surface in this state
  quick: ['agents:populated'],   // tier 2 when surface in this state
}
```

Promotion is **state-aware**, not page-aware. On the agents page:

- **Empty workspace** → hero is "Create your first agent" (one big CTA, one chip below: "Or import from template"). Everything else hidden behind "...". Time-to-value: one click.
- **One agent, never published** → hero shifts to "Publish to marketplace". Quick chips: Edit, Eval.
- **Agent with regressions** → hero shifts to "Investigate failing evals". Quick chips: Diff, Retry last eval.

The hero changes with state. The user always sees the action that most likely advances them right now.

### What renders where (the constraint)

| Primitive | Max items at rest | Overflow behavior |
| --- | --- | --- |
| `<PageHeader>` | 1 hero + 2 quick | "..." menu for the rest |
| `<DetailHeader>` | 1 hero + 3 quick | "..." menu (grouped: Edit, Quality, Distribution, Danger) |
| `<ActionCard>` (list row) | 0 visible at rest; 2 on hover | row "..." revealed on hover/focus |
| `<EmptyState>` | 1 hero + 2 chips | nothing else; empty state is for getting started |
| Chat empty-state intro | 3 chips | inline `/help` reveals all permitted verbs as a list |

If a page can't decide what's hero, it has **no hero** — the layout shrinks. Better silent than crowded.

### Command palette (Cmd-K) — the universal discovery mechanism

One global primitive (`<CommandPalette>`) bound to Cmd-K / Ctrl-K. Lists every action the viewer is permitted, fuzzy-searchable, grouped by surface. Two purposes:

1. **Power-user shortcut** — type `eval`, hit enter, action runs (with form modal if input needed).
2. **Discovery** — new users hit Cmd-K, see the breadth, learn what's possible without scrolling pages.

Recent + most-used surface to the top per user.

### Chat as the always-on discovery layer

The chat rail is the second universal discovery mechanism. Two affordances:

- **Empty-state intro**: 3 chips per surface (the same Tier-2 quick actions, no more). Below: small text "...or ask anything."
- **/help in input**: typing `/` reveals a slash-command menu of all permitted verbs (same source as Cmd-K). Pick one → seeds the input with the right prompt.

The agent itself also lists capabilities when asked ("what can I do here?") — it has the full tool manifest. So the user never wonders what's possible: Cmd-K, slash-menu, or just ask.

### Speed-to-value rules

Every page passes these checks or doesn't ship:

1. **First meaningful action ≤ 1 click** — empty state's hero must move the user forward, not explain the product.
2. **Form fields ≤ 4 in default state** — anything more lives behind "Advanced" disclosure. Defaults must be smart enough that submit-with-defaults works.
3. **Optimistic UI everywhere** — `action.execute` returns a predicted result immediately; bus event reconciles when real result lands. No spinner unless > 400ms.
4. **No empty-state lecture** — show one chip and one sentence. The chat is where users go for explanation.
5. **No "feature tour" overlay** — features reveal themselves through Cmd-K, slash menu, and contextual hero promotion. Tours are clutter that ages badly.

### The "I want to do this" test

Looking at a page, the user should immediately think *"I want to do this"* — and the page's hero must be that verb. The page is the question; the hero is the answer.

If the user lands and thinks anything other than the verb the hero offers, the hero is wrong. We change it. We don't add more buttons hoping one fits.

Test for every page: write down the sentence the user thinks at first glance, then check the hero matches it.

### Per-page action prominence — anchored on user intent

| Page (and state) | User thinks… | Hero (the verb that answers) | Quick (≤3) | Overflow ("...") |
| --- | --- | --- | --- | --- |
| `u/[slug]/[kind]/index` (empty) | "I want to create my first {kind}" | **Create {kind}** | Import, Browse examples | — |
| `u/[slug]/[kind]/index` (populated) | "I want to find or make a {kind}" | **New {kind}** (top-right; search bar is the real first thing) | Filter, Sort | Bulk publish, Export, Archive selected |
| `u/[slug]/agents/[id]` (healthy) | "I want to ship the change I just made" | **Publish update** | Edit, Eval, View live | Validate, Lint, Compile, Diff, Sign/Verify, Fork, Archive, Delete |
| `u/[slug]/agents/[id]` (regressing) | "I want to know what broke" | **Investigate failing evals** | Diff vs. last good, Rollback, Retry eval | Edit, Publish |
| `u/[slug]/agents/new` | "I want to describe what this agent does and have it built" | **Scaffold from prompt** (one big textarea, one big button — that's the page) | Pick template, Fork existing | — |
| `u/[slug]/skills/[name]` (source ahead) | "I want my workspace caught up with the source" | **Refresh from source** | Edit, Emit | Eval, Fork, Versions, Delete |
| `u/[slug]/skills/[name]` (in sync) | "I want to edit or share this skill" | **Edit** | Emit, Versions | Eval, Fork, Refresh, Delete |
| `u/[slug]/tools` (none connected) | "I want to plug in a tool" | **Connect tool** | Browse MCP, See examples | — |
| `u/[slug]/tools` (some connected) | "I want to see what's wired up" | (no hero — the grid IS the answer) | Connect tool, Expose workspace | Manage exposed, Logs, Disconnect |
| `u/[slug]/billing` (low balance) | "I want more credit so things keep working" | **Top up** | Plan, Allocations | Recovery, Simulate, Export, Audit |
| `u/[slug]/billing` (healthy) | "I want to see where my money goes" | (no hero — the balance + ledger IS the answer) | View invoice, Plan | Top up, Allocations, Recovery, Simulate, Export |
| `u/[slug]/settings` | "I want to change one specific thing" | (no hero — sections ARE the answer; user scans, finds row, edits inline) | — | Keys, Sessions, Tokens, Danger zone |
| `u/[slug]/analytics` | "I want to understand how I'm doing this week" | (no hero — last-7d tiles ARE the answer) | Last 30d, Custom range | Inspect signals, Path trace, Hypotheses, Export |
| `u/[slug]/people` (seats free) | "I want to invite someone" | **Invite** | Pending invites, Roles | Remove, Audit |
| `u/[slug]/people` (full) | "I want to see who's on this team / upgrade seats" | **Upgrade seats** | Pending invites, Roles | Remove, Audit |
| `u/[slug]/admin` | "I want to see what's happening right now" | (no hero — live log tail IS the answer) | Health, Env | Bundle, Replay |

**Two patterns emerge:**

1. **Action pages** — the user comes to *do* something. Hero is a verb. (`/agents`, `/people`, `/billing` when low, `/agents/new`, `/agents/[id]` when state demands action.)
2. **Read pages** — the user comes to *see* something. No hero. The content itself answers. (`/settings`, `/analytics`, `/admin`, healthy `/billing`, healthy `/tools`.) Adding a hero here adds noise, not value.

Knowing which type a page is, is itself a design decision. When in doubt, drop the hero.

Every CLI/API/MCP verb is still reachable — most through Cmd-K, chat, or the row-level "...". Pages stay calm. The user lands and thinks one thing.

---

## Functional completeness — every verb on every surface

**Principle.** A workspace owner who only uses the website should be able to do everything a power user does from the CLI. A chat user should be able to do everything a developer does with the SDK. Verbs are *available* on every surface; only their *prominence* differs (see "Discoverability without clutter" above for the four-tier model).

| Surface | Best at | Where it shines |
| --- | --- | --- |
| CLI | batch / scripting / dev-loop | `oneie agent eval --suite=…` in a watch loop |
| Web page | discovery, visual ops | scrolling a list, comparing diffs, exploring |
| Chat | natural-language operation | "evaluate this agent against last week's traffic" |
| SDK | programmatic embedding | apps that ship ONE inside their product |
| MCP | external client integration | Claude/Cursor calling workspace tools |
| API | infra-level integrations | webhooks, batch importers, custom UIs |

### Today's gap (verified)

Per `one-ie/one/CLAUDE.md` the CLI ships 15 verbs (`agent` × 10, `skill` × 6, `auth` × 2, `dev` × 1). The web UI exposes a small subset. Concrete missing:

| Surface | Verbs with no web/chat path today |
| --- | --- |
| CLI `agent` | `validate`, `lint`, `compile`, `serve`, `sign`, `verify`, `eval`, `diff` |
| CLI `skill` | `emit`, `refresh`, `eval` |
| CLI `dev` | log tail, env inspect (REPL is genuinely terminal-only — flag it) |
| MCP | "expose this workspace as an MCP server"; manage exposed tool list |
| SDK | streaming-response inspection, batch ops, embeddings management |
| Read-only API | path/signal trace, learning hypothesis log, raw event stream |

These exist as code paths. They just aren't reachable from the website.

### The fix — inventory before Cycle 2

Before registering actions, walk every surface and produce the canonical verb list. **Pre-Cycle-2 task (new task 7.5):**

1. `cli/src/` — every command and subcommand
2. `web/src/pages/api/` — every route folder
3. `mcp/` — every exposed tool
4. `sdk/src/` — every exported function
5. Cross-reference; produce `actions/_inventory.md` — one row per verb with source surfaces, target surfaces, current web/chat presentation (if any), proposed prominence

Each row becomes either an Action in Cycle 2 or an explicit "terminal-only" flag with reason.

Expected count: roughly **80 actions** (vs. the ~25 in the current Cycle 2 draft). Same shape per action; just more rows.

### Per-page expansions (delta on Cycle 5 per-page plan)

Adding the previously-missing verbs to the pages where they belong:

| Page | Added verbs (chip / button / chat tool) |
| --- | --- |
| `u/[slug]/agents/[id]/*` | `validate`, `lint`, `compile`, `eval`, `diff`, `sign`, `verify` — surfaced in `<DetailHeader>` actions row; results in inline cards |
| `u/[slug]/agents/new.astro` | "Scaffold from prompt" wizard step that runs `agent new --from <prompt>` server-side and streams output |
| `u/[slug]/skills/[name].astro` | `emit`, `refresh`, `eval` — tab strip adds these; each tab shows last-run result + "run again" chip |
| `u/[slug]/tools/index.astro` | New section: **MCP exposure** — toggle workspace-as-MCP-server, copy the URL, see which actions are exposed externally, per-tool on/off |
| `u/[slug]/settings.astro` | New section: **API keys & sessions** — list active sessions, revoke, mint scoped tokens (the CLI `auth login/logout` surface) |
| `u/[slug]/analytics.astro` | "Inspect signals" tile — query → table of recent signals with drill-in; path-trace view; hypothesis log |
| `u/[slug]/billing.astro` | Usage-by-surface tile — web / chat / CLI / SDK / MCP / API split (helps owners see which integrations spend) |
| New: `u/[slug]/admin.astro` (owner/agency only) | Live log tail + env snapshot + dev-stack health — the parts of `oneie dev` that aren't a REPL |
| Every page's chat rail | Inherits every action permitted for that surface — so the agent can `eval`, `diff`, `validate` without the user leaving conversation |

### What stays terminal-only (explicit exception list)

Some CLI features are genuinely terminal-native; no web equivalent makes sense. Flag them so reviewers don't keep asking:

| CLI feature | Why terminal-only |
| --- | --- |
| `oneie dev` (interactive wrangler REPL) | needs local file system + stdin; could ship a web log-tail but not the REPL itself |
| File-system-bound `agent new <dir>` scaffolding | the website creates in R2/D1; CLI for local-file workflows is separate by design |
| Local git-bound `agent diff` against working copy | versus *registry* diff which is web-friendly |

Even these get a web-surfaced *equivalent* (log tail, registry diff, R2 scaffold) — just not a 1:1 port.

### W3 task additions

| # | File | Change |
| --- | --- | --- |
| 7.5 | `actions/_inventory.md` | walk CLI/API/MCP/SDK; produce canonical verb list before action registry build (blocks Cycle 2) |
| 10b | `actions/agents.ts` | expand from {create,update,publish,delete,eval} to add `validate`, `lint`, `compile`, `sign`, `verify`, `diff`, `scaffold` |
| 11b | `actions/skills.ts` | add `emit`, `refresh`, `eval` to the existing set |
| 12b | `actions/tools.ts` | add `mcp.exposeWorkspace`, `mcp.toggleTool`, `mcp.listExposed` |
| 13b | `actions/billing.ts` | add `usage.bySurface` (read-only diagnostic) |
| 14b | `actions/auth.ts` (new) | `auth.listSessions`, `auth.revokeSession`, `auth.mintToken` |
| 15b | `actions/diagnostics.ts` (new) | `signals.trace`, `paths.trace`, `learning.list`, `events.tail` — read-only verbs that today exist only as raw API |
| 49b | `pages/u/[slug]/agents/[id]/*` | render the added agent verbs as `<DetailHeader>` actions |
| 50b | `pages/u/[slug]/skills/[name].astro` | render emit/refresh/eval tabs |
| 51b | `pages/u/[slug]/tools/index.astro` | render MCP-exposure section |
| 52b | `pages/u/[slug]/settings.astro` | render sessions + tokens section |
| 53b | `pages/u/[slug]/analytics.astro` | render signal/path trace + hypothesis log |
| 67 (new) | `pages/u/[slug]/admin.astro` | log tail + env snapshot + health |

---

## API integration map

`web/src/pages/api/` already has 67 route folders covering every verb this plan needs. The action layer doesn't replace them — it **wraps them as the one canonical caller**, so HTTP routes, chat tools, and left-side forms all funnel through the same executor. Every existing route either becomes an action's `execute` body, or is allowlisted as non-action infrastructure (auth, health, oauth, webhooks).

| Action surface | Existing API routes | Notes |
| --- | --- | --- |
| `agent.*` | `api/agents/*`, `api/agent-write.ts`, `api/agent-events.ts`, `api/actors/*` | create/update/publish/eval/delete/list; actor sub-resource for runtime instances |
| `skill.*` | `api/skills/*`, `api/skill/*` | import/fork/refresh/emit/delete/list |
| `tool.*` | `api/tools/*`, `api/composio/*` | connect (composio OAuth), disconnect, list-mcp |
| `billing.*` | `api/billing/*`, `api/pricing/*`, `api/unlocks/*` | balance, top-up, plans, allocations, simulate, unlock |
| `payment.*` | `api/payments/*`, `api/pay/*` | quote, claim, list, refund |
| `people.*` | `api/groups/*` (workspace members live in groups) | invite, change role, remove |
| `settings.*` | `api/themes/*`, `api/domains/*`, `api/admin/*` | theme, custom domain, key rotation |
| `analytics.*` | `api/analytics/*`, `api/funnel/*`, `api/learning/*`, `api/paths/*` | summary, drill, path-trace, hypothesis-list |
| `moderation.*` | `api/abuse/*` | flag, review, dismiss |
| `field-service.*` | `api/field-service/*` | sector-specific verbs (ptcorp etc.) |
| substrate (no UI form, chat-only narration) | `api/signal`, `api/mark`, `api/warn`, `api/ask`, `api/peer/*`, `api/events/*` | the agent can call these; left UI rarely needs to |
| Non-action (allowlist) | `api/auth`, `api/visitor`, `api/webhook/*`, `api/og/*`, `api/logo/*`, `api/_platform/*`, `api/artifacts/*`, `api/threads/*` | infra, identity, webhooks, asset rendering, conversation persistence |

Practical consequence: **Cycle 2 task 18** is "refactor existing API handler bodies to delegate to `action.execute`," not "rewrite the API." Each route becomes ~5 lines: parse input, call action, return result. Auth/permission checks live on the action; the route is a thin adapter.

---

## Per-page UI plan (the left side, made beautiful and functional)

Today most pages are a centered `max-w-2xl` column with bare `<ul><li><a>name</a></li></ul>` lists. The action layer lets us replace these with rich, consistent card-driven UIs that match `design.md` (L0 page → L1 card → L2 content, six tokens, lucide icons, `--shadow-card`). One pattern per page-type; surfaces just bind their actions to it.

### Shared layout primitives (build once, reuse everywhere)

| Primitive | What it is | Used by |
| --- | --- | --- |
| `<PageHeader>` | title + breadcrumb + primary action chip + secondary actions overflow + view-mode toggle (split / chat-full) | every split-mode page |
| `<SurfaceGrid>` | responsive 12-col grid; main column + optional aside; collapses to single column < 1024px | list + detail surfaces |
| `<ActionCard>` | L1 card shell (header / body / footer) per `design.md`; props for badge, meta, primary, destructive | every list item, every form |
| `<EmptyState>` | illustration + headline + 2-3 action chips (sourced from the action registry) | every list page when empty |
| `<DetailHeader>` | sticky entity header: name + status + slug + 3-4 primary actions + last-changed | every `[id]/*` page |
| `<KeyValueGrid>` | label-value pairs with copy buttons, link affordances, inline-edit on hover | settings, billing, people |
| `<MetricTile>` | big number + delta + sparkline + footnote | analytics, billing, funnel |
| `<ActivityFeed>` | reverse-chrono entries with icon, actor, verb, target, timestamp | history, agent/[id], moderation |
| `<ActionChips>` | row of chips bound to `actionsForSurface(...)` | every empty state, every chat intro, every primary-action footer |

### Per-page improvements

| Page | Today | Becomes |
| --- | --- | --- |
| `u/[slug]/[kind]/index.astro` (agents/skills/tools/payments) | bare `<ul>` of names | `<SurfaceGrid>` of `<ActionCard>`s — each shows icon, name, 1-line description, status badge, last-edited; hover reveals row-level actions (edit, eval, publish, delete) bound to the action registry. `<EmptyState>` when none. `<PageHeader>` carries "New X" primary + filter chips (status, tag). |
| `u/[slug]/agents/new.astro` | minimal `AgentForm` in a center column | two-column wizard: left = template gallery (from `agents/templates/`), right = scaffolded preview that updates live as user picks template/answers; bottom = action chips ("Scaffold from prompt", "Fork existing"). Persists draft to localStorage. |
| `u/[slug]/agents/[id]/{analytics,funnel}.astro` + `actor/[actorId]` | varied | unified `<DetailHeader>` (name + version + status + actions); tab strip (Overview / Analytics / Funnel / Actors / History); each tab = a card stack of `<MetricTile>`s and `<ActivityFeed>` slices. URL = `?tab=analytics`. |
| `u/[slug]/skills/index.astro` | bare list | `<SurfaceGrid>` of skill cards: icon, surface (chat/api/sdk/cli badges), import-source link, last-refreshed; `import` and `new` primaries. |
| `u/[slug]/skills/[name].astro` | bare detail | `<DetailHeader>` + tabs (Spec / Versions / Calls / Forks); spec tab renders markdown with action chips inline ("Refresh from source", "Emit", "Fork"). |
| `u/[slug]/tools/index.astro` | bare list | grouped sections: Connected · Available · MCP servers. Each tool is an `<ActionCard>` with provider logo (lucide), scope summary, connect/disconnect action. Composio OAuth flow stays a redirect, but result returns to this page and shows a fresh card. |
| `u/[slug]/billing.astro` | already has `PoolCard` + `Ledger` + `TopUpModal` | reorganize into 3-card hero: Balance (with sparkline of burns last 30d), Plan (current + upgrade chip), Recovery (rotate keys chip); below = `<ActivityFeed>` of burns with model-cost breakdown; right aside = upcoming reset countdown + breakdown donut. |
| `u/[slug]/billing/{plans,allocations,platform,simulate}.astro` | minimal | each becomes a focused panel with one `<MetricTile>` cluster + one form card; cross-link via tab strip across the billing surfaces. |
| `u/[slug]/people.astro` | flat list | members table with avatar, role badge, last-active, per-row role-select dropdown (bound to `people.changeRole`); `<EmptyState>` invites; pending-invite section above active members. |
| `u/[slug]/analytics.astro` | minimal | top row of 4 `<MetricTile>`s (signals, marks, warns, revenue); below = path-strength leaderboard (top 10) + hypothesis log (`learning` table). Period picker in `<PageHeader>`. |
| `u/[slug]/settings.astro` | minimal | sectioned `<KeyValueGrid>`: Workspace (slug, name, logo), Branding (theme picker → `/api/themes`), Domain (custom domain → `/api/domains`), Keys (rotate → `/api/admin`), Danger zone (destructive actions). Each section is one card. |
| `u/[slug]/onboarding.astro` | uses `chat-full` mode (chat IS the page) | no left UI needed — agent walks user via streamed action forms (passkey commit → workspace name → theme → first agent). |
| `u/[slug]/moderation.astro` | bare | queue of flagged items as `<ActivityFeed>` with inline approve/dismiss/escalate buttons (bound to `moderation.*`); filters in header. |
| `u/[slug]/history/[entry].astro` | bare | reuse `<ActivityFeed>` for the entry's signal trail; left = entry metadata in `<KeyValueGrid>`; right rail (chat) can answer "what happened here?" against the entry's substrate path. |
| `u/[slug]/workspace.astro` & `u/[slug]/index.astro` | bare | workspace dashboard: 4 `<MetricTile>`s (agents, skills, signals last 7d, revenue), recent activity feed, "next-best-action" chips from the action registry. |
| `pages/{agents,skills,tools,payments}.astro` (marketing) | varies | hero + 3-step explainer + `<ActionChips>` ("Try it", "See how it works", "Install CLI"); chat rail is end-user filtered (no admin verbs). |
| `pages/settings.astro` (top-level, end-user) | minimal | end-user account settings (theme, language, notifications) — same `<KeyValueGrid>` primitive, filtered actions. |
| `pages/index.astro` | currently `chat="wide"`, becomes `chat-full` | no left UI; immersive landing; visible header toggle to "Skip to website" (forces `split` with marketing surface). |

**Design invariants** (from `design.md`, enforced by `.claude/hooks/design-check.sh`):

- 6 tokens only; no Tailwind palette (`bg-zinc-*` etc. emit no CSS by design)
- Cards = `bg-background border rounded-2xl shadow-card`; bodies = inner `bg-foreground rounded-xl` panel
- Brand fills use `text-on-{primary|secondary|tertiary}` auto-contrast labels
- Icons: `lucide-react` via `<Icon>` / `<IconBadge>` wrappers in `components/ui/`
- Inputs sink to `bg-background` (against `foreground` card body)
- 3 depth levels only — never tint a card header/footer differently
- Animations ≤ 200ms; use `var(--ease)` for color/border/filter

**What this buys:**

- Every list-of-things page looks like every other (same card pattern, same actions footer) — users learn one surface and know all of them.
- Action chips on every page are pulled from one registry, so adding a new action surfaces it everywhere it belongs without per-page edits.
- `chat-full` view "just works" — `<ActionCard>` and `<MetricTile>` are the same components the agent streams inline, so the right side renders exactly what the left side would.
- API routes stay thin; UI gets richer; logic lives in one place.

---

## W1 — Findings (carried over and extended)

### Layout / ChatHost (existing)

- `Layout.astro` accepts `chat: 'wide' | 'rail' | 'icon' | 'none'` + `chatLock`. localStorage ignored when `chatLock` (Layout.astro:119-134).
- `ChatHost` renders `null` (none), `<ChatWidget>` (icon), or rail `<Chat>` (rail/wide).
- **No `surface` / `context` / `entityId` prop anywhere.** No event bus. No shared action layer. No tool manifest plumbing.

### Pages owning a chat surface (need `chatLock`)

Audit run against `one-ie/one/web/src/pages/` — actual `chat=` values verified by grep, not assumed.

| Page | `chat=` | `chatLock` |
| --- | --- | --- |
| `pages/chat.astro:11` | `none` | ✅ yes (only one that's right) |
| `pages/u/[slug]/chat.astro:19` | `none` | ❌ missing |
| `pages/share/[tid].astro:25` | `none` | ❌ missing |
| `pages/studio/ptcorp-dashboard.astro:112` | `none` | ❌ missing |
| `pages/create.astro:79` | `none` | ❌ missing |
| `pages/recovery-codes.astro:6` | `none` | ❌ missing |
| `pages/u/[slug]/workspace.astro:52` | `none` | ❌ missing |
| `pages/u/[slug]/analytics.astro:84` | `none` | ❌ missing |
| `pages/u/[slug]/people.astro:81` | `none` | ❌ missing |
| `pages/u/[slug]/[kind]/index.astro:50` | `none` | ❌ missing |
| `pages/u/[slug]/[kind]/[name].astro:21` | `none` | ❌ missing |
| `pages/u/[slug]/tools/index.astro:55` | `none` | ❌ missing |
| `pages/u/[slug]/skills/index.astro:41` | `none` | ❌ missing |
| `pages/u/[slug]/skills/[name].astro:19` | `none` | ❌ missing |
| `pages/u/[slug]/history/[entry].astro:23` | `none` | ❌ missing |
| `pages/404.astro:19`, `pages/500.astro:6` | `none` | n/a (trivial pages, no rail conflict) |

D1 (default-locked `chat='none'`) is the right fix — patching 14 individual files leaves the next page to be added vulnerable to the same bug. One Layout change closes the whole class.

### Pages currently using `chat="wide"`

| Page | Treatment |
| --- | --- |
| `pages/index.astro:10` | renames to `chatMode='chat-full'` (the new full-bleed generative-UI mode) |

### Pages with dynamic `chat={...}`

| Page | Notes |
| --- | --- |
| `pages/studio/[agent].astro:124` | `chat={chatMode}` driven by agent frontmatter — extend the per-agent frontmatter to allow `'split' \| 'chat-full'` |

### Pages that should be split-mode by default

Real paths verified against `one-ie/one/web/src/pages/`.

| Page | Wanted | Notes |
| --- | --- | --- |
| `u/[slug]/index.astro` | `split`, `surface='workspace-home'` | profile/workspace landing |
| `u/[slug]/workspace.astro` | `split`, `surface='workspace'` | replace current `chat="none"` |
| `u/[slug]/[kind]/index.astro` (agents/skills/tools/payments) | `split`, `surface={kind}` | list + create chip |
| `u/[slug]/[kind]/[name].astro` | `split`, `surface={kind}-detail`, entityId | thing view |
| `u/[slug]/agents/new.astro` | `split`, `surface='agent-new'` | template scaffolding |
| `u/[slug]/agents/[id]/analytics.astro` | `split`, `surface='agent-edit'`, entityId | |
| `u/[slug]/agents/[id]/funnel.astro` | `split`, `surface='agent-edit'`, entityId | |
| `u/[slug]/agents/[id]/actor/[actorId].astro` | `split`, `surface='agent-actor'`, entityId | |
| `u/[slug]/skills/index.astro` | `split`, `surface='skills'` | |
| `u/[slug]/skills/[name].astro` | `split`, `surface='skill'`, entityId | |
| `u/[slug]/tools/index.astro` | `split`, `surface='tools'` | |
| `u/[slug]/billing.astro` | `split`, `surface='billing'` | |
| `u/[slug]/billing/{plans,allocations,platform,simulate}.astro` | `split`, `surface='billing-{sub}'` | |
| `u/[slug]/people.astro` | `split`, `surface='people'` | |
| `u/[slug]/analytics.astro` | `split`, `surface='analytics'` | |
| `u/[slug]/settings.astro` | `split`, `surface='settings'` | |
| `u/[slug]/onboarding.astro` | `chat`, `surface='onboarding'` | immersive — full-bleed makes sense here |
| `u/[slug]/moderation.astro` | `split`, `surface='moderation'` | |
| `u/[slug]/history/[entry].astro` | `split`, `surface='history'`, entityId | |
| `settings.astro` (top-level) | `split`, `surface='settings'`, `viewer='end_user'` | |
| `agents.astro`, `skills.astro`, `tools.astro`, `payments.astro` | `split`, matching surface, `viewer='end_user'` | onboarding chips |
| `marketplace.astro`, `marketing-studio.astro`, `partners.astro`, `showcase.astro`, `get-yours.astro` | `split`, `surface='marketing-{name}'`, `viewer='end_user'` | |
| `motion.astro`, `vietnam.astro`, `design.astro` | leave as-is | demo/showcase, no action verbs |
| `studio/[agent].astro` | unchanged — already dynamic | extend allowed values to `'split'\|'chat'` |
| `studio/ptcorp-dashboard.astro` | stays `ui` mode (no chat) | full-page dashboard owns the surface |
| `share/[tid].astro` | stays `ui` mode | read-only shared transcript |
| `chat.astro` | stays `chat` mode | the chat *is* the page |
| `u/[slug]/chat.astro` | stays `chat` mode | workspace chat *is* the page |

End-user role still sees a chat, but the action filter strips admin verbs — same registry, different output.

---

## W2 — Decisions

### D1. Default `chat='none'` to imply `chatLock`

Today you have to set both. The audit shows **only one** of 15+ `chat="none"` pages got it right (`pages/chat.astro`) — every other workspace page is double-chat-bug-vulnerable. Patching them individually is busywork; the next added page would hit the same bug. New rule: `chat='none'` locks by default; pass `chatLockOverride={false}` if anyone ever needs the old behavior (no current callers will).

### D2. Add `'split'` and `'chat-full'` modes, drop `'wide'`

`'wide'` is what `/chat` uses today. It becomes `'chat-full'`. `'split'` is the new default for most workspace pages.

### D3. Action layer is mandatory before view modes

`split` view depends on having form/list renderers per action. `chat-full` view depends on having inline renderers + the tool manifest. So actions ship first; both views land on top.

### D4. Event bus is `BroadcastChannel` + nanostores atoms, page-scoped

**State lib: nanostores.** No Zustand in `package.json`; introducing one is a fresh choice. Picking nanostores because (a) Astro's official guide recommends it, (b) ~1KB and tree-shakes per-island, (c) atoms can be imported across `.astro` and `.tsx` boundaries without provider plumbing, (d) `@nanostores/react` gives the hook surface React 19 expects. Zustand would add ~3KB and React-only coupling for no upside here.

Survives nothing across page navigations — that's fine; surface remount resubscribes. No SSE needed for v1 (same-tab only). Multi-tab and multi-device come later via the substrate's existing WsHub.

### D5. Tool-approval = AI SDK v6 protocol

`destructive: true` actions return a `tool-approval` part instead of `tool-result`. Client renders the same confirmation UI used by left-side destructive buttons. `claw` already supports this.

### D6. Marketing surfaces share the registry

No separate `surface: 'marketing'`. Marketing pages set `viewer='end_user'`, get filtered action set with onboarding/help verbs, can transition to authenticated state mid-conversation (passkey provisioning) without leaving the chat.

### D7. Shared UI primitives before per-page rebuild

Nine primitives (`<PageHeader>`, `<SurfaceGrid>`, `<ActionCard>`, `<EmptyState>`, `<DetailHeader>`, `<KeyValueGrid>`, `<MetricTile>`, `<ActivityFeed>`, `<ActionChips>`) build once, every split-mode page composes them. Each binds to the action registry where it surfaces verbs, so adding an action propagates without per-page edits. Same primitives are what the agent streams inline in `chat-full` view — one component tree, two delivery mechanisms.

### D8. API routes become thin adapters

Each existing route under `web/src/pages/api/<resource>/*` is rewritten as ~5 lines: parse, call `action.execute`, return. Auth and permission live on the action. Allowlisted routes (auth, webhooks, oauth callbacks, asset rendering) stay as-is. No two stacks.

### D10. Action permissions = tier + scope predicate (per `roles.md`)

Coarse `permission: Viewer[]` was Cycle 2's draft. Real shape:

```ts
permission: { tiers: Viewer[], scope: 'self' | 'workspace' | 'platform' }
```

Server-side gate on `action.execute` runs both: viewer tier ∈ `tiers` AND `scope` check (e.g. `scope='self'` ⇒ `target.ownerSlug === ctx.actor.slug`). Client filter uses tiers only for visibility; scope is checked server-side because it's the security boundary. Adds one cycle of refactor on the action layer but closes a real authz gap.

### D11. Cascade-aware inputs

Actions that participate in the white-label cascade (`roles.md` §4) carry an `applyTo` enum on their input schema (`'workspace' | 'me'`), and the executor writes to the correct scope. UI surfaces the choice via the shared `<KeyValueGrid>` primitive's scope selector; locked-by-higher-scope renders the 🔒 indicator (`roles.md` §9).

### D12. Org pattern filters the action list

`actionsForSurface(surface, viewer, orgPattern)` — pattern read from `siteConfig.pattern` (already exists). Same registry; pattern hides actions that don't apply to that org shape (Solo hides team verbs, Enterprise hides self-service signup). Zero new actions needed.

### D9. Page-as-default `chat-full` for immersive surfaces

Three pages own the chat as their *content* (chat IS the page, no left UI): `pages/index.astro` (marketing immersive landing), `pages/chat.astro`, `pages/u/[slug]/chat.astro`, `pages/u/[slug]/onboarding.astro`. Header toggle reveals split view when the page has one defined; otherwise toggle is hidden.

---

## W3 — Tasks

Grouped in four waves; each wave is one cycle.

### Cycle 1 — Bug fixes + Layout plumbing (lean, shippable alone)

One Layout change closes the entire double-chat class instead of patching 14 pages.

| # | File | Change |
| --- | --- | --- |
| 1 | `layouts/Layout.astro:119-134` | D1: `chat='none'` implies `chatLock=true` unless `chatLockOverride={false}` |
| 2 | `layouts/Layout.astro` | new props: `chatMode: 'split'\|'chat-full'\|'rail'\|'icon'\|'none'`, `chatSurface`, `chatEntityId`. Keep `chat=` accepted as alias for one release. Emit `<html data-chat-surface data-chat-mode data-chat-entity-id>` |
| 3 | `pages/index.astro:10` | migrate `chat="wide"` → `chatMode="chat-full"` |
| 4 | `pages/studio/[agent].astro:124` | extend `chatMode` allowed values to include `'split'\|'chat'` |
| 5 | `components/ChatHost.tsx` | read surface+mode+entityId from dataset; forward to `<Chat>` |
| 6 | `components/Chat.tsx` | accept `context`; render `<ChatSurfaceIntro>` when conversation empty |
| 7 | sweep | grep `chat="wide"` and `chat="none"` post-change — confirm `wide` callers all migrated; `none` callers all auto-locked |

**Verify:** for every `chat="none"` page in the audit table above, exactly one chat root in DOM; setting `localStorage['one:chat-mode']='rail'` and reloading does not bypass the auto-lock.

### Cycle 2 — Action layer (full mode)

| # | File | Change |
| --- | --- | --- |
| 8  | `actions/_types.ts` | `defineAction`, `Action<I,O>`, `ActionContext { api, bus, viewer, slug }` |
| 9  | `actions/_bus.ts` | `BroadcastChannel('one:actions')` + nanostores atoms, `useActionEvents(filter)` hook |
| 10 | `actions/agents.ts` | `agent.create`, `agent.update`, `agent.publish` (destructive), `agent.delete` (destructive), `agent.eval` |
| 11 | `actions/skills.ts` | `skill.import`, `skill.fork`, `skill.refresh`, `skill.emit`, `skill.delete` (destructive) |
| 12 | `actions/tools.ts` | `tool.connect`, `tool.disconnect` |
| 13 | `actions/billing.ts` | `billing.upgrade`, `billing.openInvoice`, `billing.rotateRecovery` |
| 14 | `actions/people.ts` | `people.invite`, `people.changeRole`, `people.remove` (destructive) |
| 15 | `actions/settings.ts` | `settings.rotateKeys`, `settings.setTheme`, `settings.setDomain` |
| 16 | `actions/index.ts` | registry; `actionsForSurface(surface, viewer)` |
| 17 | `api/chat.ts` | accept `{ surface, entityId, viewer }` in body; build tools from `actionsForSurface`; dispatch tool calls through action executors |
| 18 | existing API routes (`api/agents/*`, `api/skills/*`, …) | refactor to call action executors instead of duplicating logic |

**Verify:** every left-side form-submit and every API route goes through `action.execute`. Grep for direct DB writes outside `actions/` → zero.

### Cycle 3 — Split view (the existing UX, now powered by the layer)

| # | File | Change |
| --- | --- | --- |
| 19 | `components/chat/ChatSurfaceIntro.tsx` | renders chips from `actionsForSurface(surface, viewer)`; chip click seeds input with action's prompt template |
| 20 | `components/chat/ActionChips.tsx` | same primitive, reused on the left for empty-state CTAs |
| 21 | `pages/u/[slug]/index.astro`, `workspace.astro` | `chatMode='split'`, `chatSurface={workspace-home\|workspace}` |
| 22 | `pages/u/[slug]/[kind]/{index,[name]}.astro` | `chatMode='split'`, `chatSurface={kind}\|{kind}-detail` |
| 23 | `pages/u/[slug]/agents/new.astro` | `chatMode='split'`, `chatSurface='agent-new'` |
| 24 | `pages/u/[slug]/agents/[id]/{analytics,funnel}.astro`, `actor/[actorId].astro` | `chatMode='split'`, `chatSurface='agent-edit\|agent-actor'`, `chatEntityId={id}` |
| 25 | `pages/u/[slug]/skills/{index,[name]}.astro` | `chatMode='split'`, `chatSurface={skills\|skill}` |
| 26 | `pages/u/[slug]/tools/index.astro` | `chatMode='split'`, `chatSurface='tools'` |
| 27 | `pages/u/[slug]/{billing,settings,analytics,people,moderation}.astro` | `chatMode='split'`, matching surface |
| 28 | `pages/u/[slug]/billing/{plans,allocations,platform,simulate}.astro` | `chatMode='split'`, `chatSurface='billing-{sub}'` |
| 29 | `pages/u/[slug]/history/[entry].astro` | `chatMode='split'`, `chatSurface='history'`, entityId |
| 30 | `pages/settings.astro` | `chatMode='split'`, `chatSurface='settings'`, `viewer='end_user'` |
| 31 | `pages/{agents,skills,tools,payments}.astro` (marketing) | `chatMode='split'`, matching surface, `viewer='end_user'` |
| 32 | `pages/{marketplace,marketing-studio,partners,showcase,get-yours}.astro` | `chatMode='split'`, `chatSurface='marketing-{name}'`, `viewer='end_user'` |
| 33 | Left-side list components (`AgentList`, `SkillList`, …) | subscribe via `useActionEvents`; refresh/patch on event |

**Verify:** chat tool-call creates an agent → left list updates without reload. Form-submit on the left → chat sees the bus event.

### Cycle 4 — Chat-full view (generative UI)

| # | File | Change |
| --- | --- | --- |
| 28 | `components/Chat.tsx` | when `chatMode='chat-full'`: full-bleed, hide page content slot; render tool-result parts via action `inline` renderer map |
| 29 | `components/chat/ToolResultPart.tsx` | maps `tool.id` → `action.ui.inline`; renders with result props |
| 30 | `components/chat/ToolApprovalPart.tsx` | renders destructive-action confirm gate from AI SDK v6 `tool-approval` part |
| 31 | `components/chat/ChatModeToggle.tsx` | header control; toggles split ↔ chat; persists per-surface in localStorage |
| 32 | `layouts/Layout.astro` | when `chatMode='chat-full'`, render chat slot full-bleed, hide main content slot |
| 33 | mobile breakpoint logic | `<768px` force `chatMode='chat-full'` regardless of frontmatter default |
| 34 | scroll-anchor logic in `Chat.tsx` | don't yank viewport when a tall inline component streams and user is scrolled up |

**Verify:** in chat-full view on `/u/:slug/agents`, the agent says "let me show you your agents" → `agent.list` tool-result renders `AgentList` inline → clicking a row navigates and updates `entityId` context.

### Cycle 5 — Shared primitives + per-page rebuild (D7)

Build the 9 shared primitives, then rebuild each split-mode page on top. Lighthouse-100 invariant on `/chat` carries through; each page targets ≥95 perf, 100 a11y.

| # | File | Change |
| --- | --- | --- |
| 35 | `components/layout/PageHeader.tsx` | title + breadcrumb + primary chip + overflow + view-mode toggle |
| 36 | `components/layout/SurfaceGrid.tsx` | 12-col grid, main + aside, responsive collapse |
| 37 | `components/cards/ActionCard.tsx` | L1 card shell per `design.md`; badge/meta/primary/destructive props |
| 38 | `components/cards/EmptyState.tsx` | illustration + headline + `<ActionChips>` |
| 39 | `components/layout/DetailHeader.tsx` | sticky entity header for `[id]/*` pages |
| 40 | `components/data/KeyValueGrid.tsx` | label/value with copy + inline-edit on hover |
| 41 | `components/data/MetricTile.tsx` | big number + delta + sparkline; props read from `/api/analytics` |
| 42 | `components/data/ActivityFeed.tsx` | reverse-chrono entries (icon, actor, verb, target, ts) |
| 43 | `components/chat/ActionChips.tsx` | reused on left (already added in Cycle 3); finalize as shared primitive |
| 44 | `pages/u/[slug]/[kind]/index.astro` | rebuild on `SurfaceGrid` + `ActionCard` + `EmptyState` |
| 45 | `pages/u/[slug]/agents/new.astro` | two-column scaffold wizard (template gallery + live preview) |
| 46 | `pages/u/[slug]/agents/[id]/{analytics,funnel}.astro`, `actor/[actorId]` | unified `DetailHeader` + tab strip |
| 47 | `pages/u/[slug]/skills/{index,[name]}.astro` | grid + detail tabs (Spec/Versions/Calls/Forks) |
| 48 | `pages/u/[slug]/tools/index.astro` | grouped Connected/Available/MCP sections |
| 49 | `pages/u/[slug]/billing.astro` + sub-billing | hero of 3 metric tiles + ledger feed + tab strip across sub-billing |
| 50 | `pages/u/[slug]/people.astro` | members table + pending-invite section |
| 51 | `pages/u/[slug]/analytics.astro` | 4 metric tiles + path leaderboard + hypothesis log |
| 52 | `pages/u/[slug]/settings.astro` + `pages/settings.astro` | sectioned `KeyValueGrid` with destructive zone |
| 53 | `pages/u/[slug]/moderation.astro` | flagged-queue feed with inline action buttons |
| 54 | `pages/u/[slug]/history/[entry].astro` | metadata grid + signal-trail feed |
| 55 | `pages/u/[slug]/{workspace,index}.astro` | dashboard tiles + next-best-action chips |
| 56 | `pages/u/[slug]/onboarding.astro` | switch to `chatMode='chat-full'`; agent walks user via streamed action forms |
| 57 | `pages/{agents,skills,tools,payments,marketplace,marketing-studio,partners,showcase,get-yours}.astro` | hero + explainer + `<ActionChips>` end-user filtered |
| 58 | `pages/index.astro` | `chatMode='chat-full'`; "Skip to website" header toggle |

**Verify:**
- Visual regression: snapshot every rebuilt page in split + chat-full + ui modes; diff against committed baselines.
- Lighthouse ≥95 perf / 100 a11y / 100 best / 100 seo on every rebuilt page.
- Design hook (`.claude/hooks/design-check.sh`) emits zero violations across `web/**/*.{tsx,astro,css}`.
- Action coverage: every primitive that renders an action chip resolves it through `actionsForSurface` — no hardcoded labels.

### Cycle 6 — Role & cascade plumbing (D10 / D11 / D12)

Lands the richer permission model from `roles.md`. Pure refactor on the action layer + one new UI affordance.

| # | File | Change |
| --- | --- | --- |
| 59 | `actions/_types.ts` | extend `permission` shape: `{ tiers: Viewer[]; scope: 'self' \| 'workspace' \| 'platform' }` |
| 60 | `actions/_types.ts` | `ActionContext` adds `workspace: { slug, pattern, ownerSlug }`, `membership?: { role }` for partner-style relationships |
| 61 | `actions/_filter.ts` | `actionsForSurface(surface, viewer, orgPattern)` — pattern read from `siteConfig.pattern` |
| 62 | `actions/agents.ts`, `skills.ts`, `tools.ts`, `billing.ts`, `people.ts`, `settings.ts` | annotate each action with the right `scope` and (where applicable) `applyTo` input field |
| 63 | `lib/cascade.ts` | resolve "where does this setting come from": walks world → org → team → actor; returns `{ value, lockedBy?: scope }` |
| 64 | `components/data/KeyValueGrid.tsx` | scope-selector pill ("Apply to: workspace / just me") for cascade-aware fields; 🔒 indicator + tooltip when `lockedBy` set (per `roles.md` §9) |
| 65 | `api/chat.ts` | thread `orgPattern` and `membership` into action context so server-side gate matches client-side filter |
| 66 | server-side gate (in `action.execute` wrapper) | enforce `scope='self'` ⇒ `target.ownerSlug === ctx.actor.slug`; emit `403 forbidden` event on violation so the bus can surface it |

**Verify:**
- Negative test per scope: client tier attempts agency-only action via direct API call → 403; via chat tool-call → tool result is `denied`.
- Cascade lock test: `agency` locks theme at workspace scope; `client` viewing same workspace sees 🔒 on theme picker; their `applyTo='me'` still works for non-locked attributes.
- Pattern test: switch a workspace's `siteConfig.pattern` from `solo` to `team` → `people.*` actions appear in registry filter; reverse hides them.
- Audit log: every denied action emits a substrate `warn` so denials become learnable (per Rule 1).

---

## W4 — Verify (deterministic checks)

1. **Single chat per route** — for each row in the page tables, exactly one chat root in DOM. (Browser script in `.claude/scripts/browser-check.mjs`.)
2. **Surface plumbing** — `document.documentElement.dataset.chatSurface` matches expected per route; `dataset.chatMode` matches the page frontmatter.
3. **Action coverage** — every API route under `web/src/pages/api/` either (a) calls `action.execute` for a registered action, or (b) is on an allowlist of non-action routes (auth, health, oauth callbacks). Lint script enforces.
4. **Bus parity test** — `agent.create` via chat tool → assert `AgentList` re-renders with new item within 500ms (no full reload). Same test inversely: form-submit → chat assistant receives the bus event.
5. **Approval gate** — destructive action via chat must produce a `tool-approval` part; clicking "Approve" runs executor; "Deny" leaves state unchanged.
6. **Replay** — reload page mid-conversation; tool-result components rehydrate from message history with the same props.
7. **Mode toggle** — `split ↔ chat` toggle: chat history preserved, page content hides/shows, no remount jank.
8. **localStorage override neutralised** — set `localStorage['one:chat-mode']='rail'`, reload `/u/:slug/chat`, confirm rail chat does NOT appear.
9. **Lighthouse `/chat` still 100%** — load-bearing per pheromone; re-run after each cycle.
10. **Rubric ≥ 0.65** —
    - security: approval gate, no privilege escalation through tool-call path
    - stability: existing routes work; no orphan code paths (single executor per verb)
    - simplicity: one registry, one bus, one renderer-map; chat-view code reuses split-view components
    - speed: `actions/` tree-shakes per-surface; chat-view bundle size delta < 30 KB gzip

---

## Lazy-load / performance rules

- `Chat.tsx` already lazy in `client:idle` islands; `ToolResultPart` map lives inside that bundle.
- Action `inline` renderers are lazy-imported per tool-id; only loaded when first emitted in the stream.
- `actions/` is per-surface code-split — homepage doesn't ship `actions/people.ts`.
- Mobile `chat`-mode default: keeps the bundle the same as split-mode (no second chat surface to mount).

---

## Design rules (from `design.md`)

- Inline action components use the same card/form patterns — `bg-background border` shell, `bg-foreground` inner. No new tints.
- Chat-mode full-bleed uses `--color-page`; inline components keep their normal card surfaces inside it (depth reads correctly: page → card → content).
- Destructive approval gate uses `bg-destructive text-on-destructive` for the confirm button per `design.md`.
- Chips: `bg-foreground border`, hover `bg-primary/10`.

---

## The system in synchrony

### One goal

**Every visit advances someone toward something they wanted.** The verb is segment-specific; the mechanic is universal: page is the question, hero is the answer, action runs, substrate learns, cascade adjusts, next visit is sharper. Repeat. The platform gets smarter while the user gets faster.

### How the pieces interlock

```
            6 DIMENSIONS  (Groups · Actors · Things · Paths · Events · Learning)
                              │
                  ┌───────────┼─────────────────────────────┐
                  │           │                             │
              4 TIERS    5 ORG PATTERNS              CASCADE: world→org→team→actor
        owner⊃agency⊃     Solo/Agency/Team/         (settings flow DOWN, locked at any level)
        client⊃end_user   Enterprise/Network        (evidence flows UP as pheromone)
                  │           │                             │
                  └─────┬─────┘                             │
                        ▼                                   │
              ACTION FOR THIS USER, ON THIS PAGE, IN THIS STATE
                        │                                   │
            ┌───────────┼───────────┐                       │
            │           │           │                       │
        SPLIT       CHAT-FULL      UI                       │
       (3 views, header toggle, segment + frontmatter chooses default)
                        │                                   │
                        ▼                                   │
                 4 PROMINENCE TIERS                         │
                  Hero / Quick / Overflow / (Palette+Chat)  │
                        │                                   │
                        ▼                                   │
                 action.execute(input, ctx)                 │
                        │                                   │
            ┌───────────┼───────────┐                       │
            ▼           ▼           ▼                       │
        HTTP route   SDK fn      MCP tool   CLI cmd   ◄─ same registry, same gates
            │           │           │            │          │
            └───────────┼───────────┘            │          │
                        ▼                        │          │
                  EVENT BUS  ────────────────────┘          │
                  (BroadcastChannel + nanostores)           │
                        │                                   │
                        ▼                                   │
              ┌────────────────────┐                        │
              │ left UI re-renders │  ←── same state, two   │
              │ chat narrates      │      delivery surfaces │
              └────────────────────┘                        │
                        │                                   │
                        ▼                                   │
                 substrate mark()/warn()                    │
                        │                                   │
                        ▼                                   │
                 7 LOOPS run on the path   ─────────────────┘
                  L1 signal / L2 trail / L3 fade
                  L4 economic / L5 evolution
                  L6 knowledge / L7 frontier
                        │
                        ▼
            next visit's hero is sharper
            (state-aware promotion uses learned paths)
```

Nothing in the system stands alone. Each piece is either *carrying intent down* (cascade, view mode, hero promotion) or *carrying evidence up* (action result, bus event, pheromone, hypothesis).

### What flows DOWN (intent)

| From | To | Carrier |
| --- | --- | --- |
| World defaults | Org | siteConfig.cascade (`roles.md` §4) |
| Org settings | Team | siteConfig.cascade, locked levels marked |
| Team settings | Actor | localStorage prefs override unless locked |
| Page route | Action registry | `surface`, `entityId`, `viewer`, `orgPattern` |
| Page state | Hero promotion | empty/populated/regressing/healthy gates which verb is Tier 1 |
| Action def | All surfaces | input zod, permission, execute — codegen targets HTTP/SDK/MCP/CLI from one source |
| Action result | UI components | tool-result parts render `action.ui.inline` in chat or list/form on left |

### What flows UP (evidence)

| From | To | Carrier |
| --- | --- | --- |
| User click | Action executor | `emitClick('ui:<surface>:<action>')` + action invocation |
| Action result | Event bus | typed event on `BroadcastChannel('one:actions')` |
| Bus event | Both surfaces | left UI re-fetches, chat may narrate |
| Action outcome | Substrate | `mark()` on result, `warn()` on failure (Rule 1) |
| Substrate paths | Hero promotion logic | strong paths bubble actions to Tier 1 for matching state |
| Aggregated learning | Owner dashboards | hypothesis log surfaces patterns across workspaces |
| Failures / denials | Substrate `warn` | denials are learning too — pheromone weakens bad paths |

### Synchrony — what propagates when something happens

| Trigger | Within 100ms | Within 500ms | Within 5 min | Within 1 hr |
| --- | --- | --- | --- | --- |
| User clicks hero | optimistic UI update; `emitClick` fires | action.execute returns; bus event; both surfaces reconcile | path mark accumulates; fade tick | L6 knowledge harden runs |
| Agency locks a setting at workspace scope | cascade write succeeds; `<KeyValueGrid>` shows 🔒 on dependent rows | clients viewing workspace see locked indicator | new sessions inherit; cached overrides cleared | L5 evolution may rewrite agents that hit the new constraint |
| Action denied by permission gate | 403 + bus emits "denied" | chat surfaces "you can't do that here" if visible | substrate warn(0.5) on the denied path | L7 frontier may flag unexplored access cluster |
| End_user lands on marketing page | hero = "Try it now"; chat shows 3 onboarding chips | chip click runs `auth.passkey.create` → cascade applies workspace defaults | first signal on personal path | first eval cycle; activation event |
| Agency adds new agent | `agent.create` runs everywhere it appears (web, chat, CLI, MCP, SDK) | bus event; sidebar count updates; chat suggests next step | first signals start accumulating | L4 economic loop tags revenue if paid use |

### Per-segment unified journey

Each segment's experience IS the same machine, viewed through a different lens:

```
end_user      →  chat-full IS the product. Action filter strips admin verbs.
                 Hero = "try this now." Chat = the agent that was built FOR them.
                 Cascade: receives org's brand, theme, tone — invisibly.
                 Funnel: arrive → try → succeed → ask to save (passkey) → become client.

client        →  split view, read-only cards + their own settings.
                 Hero = the work they're here to do (use the agent, see analytics).
                 Cascade: receives workspace defaults; can override at "me" scope only.
                 Funnel: invited → activated → using → succeeding → renewing or churning.

agency        →  split view, full action chips, white-label cascade controls.
                 Hero = whatever advances THIS workspace right now
                 (publish, evaluate, invite, top up, fix a regression).
                 Cascade: writes at workspace scope; their settings cascade to clients.
                 Funnel: signup → first agent shipped → first client added → recurring revenue.

owner (Tony)  →  every workspace at once. Platform admin verbs.
                 Hero = "what's broken or interesting right now" (anomaly, hypothesis).
                 Cascade: writes at world scope; defaults cascade to every workspace.
                 Funnel: not in the funnel — observes all funnels; tunes the system.
```

**One system, four lenses.** The action registry, event bus, cascade, and 7 loops are identical for all four. Only the filter (`actionsForSurface(surface, viewer, orgPattern)`) and the cascade scope (`'me' | 'workspace' | 'platform'`) differ. Add a verb once → it lights up in every lens where its permission allows.

### What "achieves the goal" looks like in numbers

The 4 outcomes (`result | timeout | dissolved | warn`) and the 3 locked rules give us deterministic receipts. The synthesis works when these all trend in the same direction across cycles:

- **Time-to-first-action** per segment, per surface (target: end_user < 5s, client < 10s, agency < 3s after auth)
- **Hero match rate** — % of visits where the user clicks the hero vs. a Quick chip vs. overflow (high hero rate = page intent is calibrated)
- **Path strength on segment journeys** — pheromone accumulates on (segment, surface, action) tuples; the strong paths ARE the validated user journey
- **Cascade churn** — how often a setting is overridden at lower scope (high churn = cascade default is wrong)
- **Denial rate** per (surface, viewer) — high denial = action exposed wrongly OR permission too tight
- **L6 hypothesis log growth** — system is learning if hypotheses accumulate; static = stuck
- **Lighthouse** — every page ≥95 perf, 100 a11y across all view modes (existing invariant on `/chat` extends)

If hero match rate is high, path strength compounds, cascade churn is low, denial rate is calibrated, hypotheses accumulate, and Lighthouse holds — the system is in synchrony.

If any one of these slips, it points to a specific place: hero match low → page intent wrong; cascade churn high → default wrong; denial rate high → permission miscoded; hypotheses static → substrate isn't seeing closed loops. The metric itself diagnoses.

### The single sentence

> The action layer makes every verb available on every surface. The four-tier prominence keeps each page calm. The cascade carries personality down and evidence up. The substrate learns which heroes work for which segments. Each visit advances someone, leaves a trace, and sharpens the next visit. That's the whole machine.

---

## Out of scope (explicit)

- **Cross-tab / cross-device sync.** Page-scoped bus only. Multi-device via WsHub is a later cycle.
- **Re-skinning floating `<ChatWidget>` (icon mode) per surface.** Stays generic; rail/split is where the contextual work lives.
- **New routes.** Pure refactor + view modes.
- **Reverse narration as default.** Bus events reach the chat assistant, but the assistant only narrates when explicitly prompted in its system prompt for that surface — no chatty interruptions during silent UI work.

---

## Open questions

- **Marketing homepage `/index.astro`** — already `chat="wide"`, migrating to `chatMode='chat-full'`. Does the immersive default need a visible "skip to website" affordance for the brand-pitch crowd, or is the toggle in the chat header enough?
- **Action input forms for the chat-full view** — when an action needs input the agent hasn't gathered, does it (a) ask in natural language and call the tool when ready, or (b) emit the form component inline and let the user fill it directly? Recommend (b) — fewer turns, more direct. The agent only narrates *around* the form, doesn't re-ask its fields.
- **`studio/[agent].astro`** — frontmatter currently picks `chatMode` per agent; should the schema enforce one of `'split' | 'chat-full'` only, or keep `'rail' | 'icon' | 'none'` available for legacy agents?

---

## Lifecycle & funnel — page by page

The action layer only pays off if every page advances *someone* toward *something*. Two funnels run in parallel:

```
USER funnel:    arrive → understand → try → trust → use → succeed → invite/share
OUR  funnel:    visitor → activated → paying → retained → advocate
```

Every page is a checkpoint. The chat is the conversion mechanism — it shortens the path between "I'm here" and "I did the thing." The action filter per surface IS the funnel step: only surface the verbs that move them forward from where they are.

### Stages, in order

| # | Stage | User feels | We measure | Failure mode |
| --- | --- | --- | --- | --- |
| S0 | **Arrive** | "What is this?" | landing route, referrer, time-to-first-paint | bounce |
| S1 | **Understand** | "Why should I care?" | scroll-depth, primary CTA hover | confusion |
| S2 | **Try** | "Show me it works" | chat opened, first message sent | dead chat (no reply / generic reply) |
| S3 | **Trust** | "Is this safe for me / my money / my brand?" | passkey provisioned, recovery codes saved | bail at biometric |
| S4 | **Activate** | "I made my own thing" | first agent created, first skill imported, first payment received | abandoned scaffold |
| S5 | **Use** | "It's part of my day" | weekly active surfaces, tool runs, signal volume | silent drop-off |
| S6 | **Succeed** | "I got the outcome I wanted" | money received / agent shipped / customer served | activity without outcome |
| S7 | **Expand** | "I want more / different / for my team" | upgrade, invite, second workspace | plan ceiling, can't invite |
| S8 | **Advocate** | "Look what I made" | share link opened, studio page traffic, referrals | shareable artifact not shipped |

The chat exists to close the gap from one stage to the next *on the same page*, without route changes. Quick-action chips are stage-appropriate; the agent's system prompt for that surface is stage-appropriate.

### Page → stage → verbs

`viewer` column collapses to: **V** = anonymous visitor, **EU** = end_user (signed-in customer of a workspace), **O** = owner, **A** = agency, **C** = client.

| Page | Stage(s) | User goal here | Our goal here | Chat surface | Key actions exposed (filtered by viewer) |
| --- | --- | --- | --- | --- | --- |
| `pages/index.astro` (`/`) | S0→S2 | "Decide if this is for me in 10 seconds" | First chat message sent | `home-marketing` (V) | `demo.try`, `agent.peek`, `signup.start`, `pricing.show` |
| `pages/agents.astro` | S1→S2 | "See what agents do" | Click into a live agent demo | `marketing-agents` (V/EU) | `demo.try('agent')`, `agent.template.list`, `signup.start` |
| `pages/skills.astro` | S1→S2 | "Skills explained with examples" | Skill marketplace click | `marketing-skills` (V/EU) | `skill.preview`, `skill.docs`, `signup.start` |
| `pages/tools.astro` | S1→S2 | "What tools can my agent use" | Click connect-tool demo | `marketing-tools` (V/EU) | `tool.preview`, `signup.start` |
| `pages/payments.astro` | S1→S2 | "Show me 'accept crypto in 60s'" | Open a payment link demo | `marketing-payments` (V/EU) | `payment.demo`, `payment.docs`, `signup.start` |
| `pages/marketplace.astro` | S1→S4 | "Find an agent/skill I want" | Install or fork to my workspace | `marketplace` (V/EU/O) | `agent.install`, `skill.fork`, `signup.start` |
| `pages/showcase.astro` | S1, S8 | "Proof this works" | Sign up; also: showcase advocates | `showcase` (V) | `case.read`, `signup.start`, `submit.case` (advocates) |
| `pages/partners.astro` | S7 (agency lane) | "Can I resell this?" | Agency signup | `partners` (V/A) | `partner.apply`, `pricing.agency` |
| `pages/vietnam.astro` | S0→S2 (regional) | local-language onboarding | Region-tagged signup | `regional-vn` (V) | `signup.start`, `demo.try` |
| `pages/get-yours.astro` | S2→S3 | "Claim my slug" | Reserve handle, start provision | `claim` (V) | `slug.check`, `claim.start` |
| `pages/create.astro` | S3→S4 | "Provision me end-to-end" | Passkey provisioned + first agent | `onboarding` (V→EU/O) | `passkey.provision`, `recovery.save`, `workspace.scaffold` |
| `pages/recovery-codes.astro` | S3 | "Save my paper backup" | Recovery codes acknowledged | none (locked, sensitive) | — |
| `pages/chat.astro` (`/chat`) | S2 / S4 | "Talk to ONE about anything" | Convert visitors; deepen owners | `chat-generic` (any) | viewer-aware: visitor → `signup.start`, owner → `agent.list`, `skill.find` |
| `pages/u/[slug]/index.astro` | S4→S6 | "Workspace dashboard" | Daily-active surface | `workspace-home` (EU/O/A/C) | owner: `agent.list`, `pheromone.summary`, `payment.summary`; EU: `chat.start` |
| `pages/u/[slug]/chat.astro` | S2→S6 | "The product, full-bleed" | Engagement + retention | `chat` (any) | viewer-scoped — EU: support verbs; O: admin verbs |
| `pages/u/[slug]/[kind]/index.astro` (agents) | S4, S5 | "Manage my agents" | First agent + edits | `agents` (O/A) | `agent.create`, `agent.eval`, `agent.publish`, `agent.delete` |
| `pages/u/[slug]/agents/new.astro` | S4 | "Make one fast" | Activation event | `agent-new` (O/A) | `agent.scaffold`, `agent.fromTemplate`, `agent.import` |
| `pages/u/[slug]/agents/[id]/*` | S5, S6 | "Improve & ship this agent" | Eval pass, publish | `agent-edit` (O/A) | `agent.update`, `agent.eval`, `agent.publish`, `agent.diff`, `agent.sign` |
| `pages/u/[slug]/[kind]/index.astro` (skills) | S4, S5 | "Give agents new powers" | Skill imported + used | `skills` (O/A) | `skill.import`, `skill.fork`, `skill.refresh` |
| `pages/u/[slug]/skills/[name].astro` | S5 | "Tune this skill" | Skill emit/publish | `skill` (O/A) | `skill.edit`, `skill.emit`, `skill.delete` |
| `pages/u/[slug]/tools/index.astro` | S4, S5 | "Connect external tools" | First tool connected | `tools` (O/A) | `tool.connect`, `tool.disconnect`, `tool.test` |
| `pages/u/[slug]/people.astro` | S7 | "Bring my team" | Invite sent / role set | `people` (O/A) | `people.invite`, `people.changeRole`, `people.remove` |
| `pages/u/[slug]/billing.astro` | S3, S7 | "Upgrade / receive money" | Plan upgrade / first payout | `billing` (O) | `billing.upgrade`, `billing.openInvoice`, `billing.payout` |
| `pages/u/[slug]/analytics.astro` | S6 | "Did it work?" | Outcome visibility = retention | `analytics` (O/A/C) | `analytics.summary`, `path.inspect`, `cohort.compare` |
| `pages/u/[slug]/settings.astro` | S3, S5 | "Make it mine / safe" | Domain claimed, theme set | `settings` (O) | `settings.setDomain`, `settings.setTheme`, `settings.rotateKeys` |
| `pages/u/[slug]/workspace.astro` | S7 | "Spin up another / structure" | Second workspace, hierarchy | `workspace-admin` (O) | `workspace.create`, `workspace.archive` |
| `pages/u/[slug]/moderation.astro` | S5, S6 | "Keep it clean" | Trust signal | `moderation` (O/A) | `moderate.review`, `moderate.escalate` |
| `pages/u/[slug]/onboarding.astro` | S3→S4 | "First-run wizard" | Activation in <5 min | `onboarding-workspace` (O) | `tour.next`, `agent.firstScaffold`, `recovery.confirm` |
| `pages/u/[slug]/history/[entry].astro` | S5, S6 | "What happened?" | Audit trust | `history` (O/A/C) | `history.explain`, `history.replay` |
| `pages/share/[tid].astro` | S8, S0→S2 (recipient) | "Show others / discover via share" | Inbound activation | `share` (V/EU) | for recipient: `signup.start`, `clone.thread`; locked for owner |
| `pages/studio/[agent].astro` / `studio/ptcorp-dashboard.astro` | S8, S0→S2 | "Branded landing for my agent" | Agent owner gets traffic; visitors convert | `studio` (V/EU) | `chat.with(agent)`, `agent.book`, `agent.pay` |
| `pages/design.astro`, `motion.astro`, `marketing-studio.astro` | internal showcase | — | internal | none / `icon` only | — |

### Where the funnel currently leaks (and what this plan does about it)

| Leak | Today | After chat-integrated |
| --- | --- | --- |
| S2 → S3: visitor talks to `/chat` then bounces because there's no clear "this is how I get my own" | Generic chat, no surface-aware CTA | `chat-generic` filtered for V: chips include `signup.start`, `slug.check` — chat itself converts |
| S4: agents page is just a list; user doesn't know what to do | Static list, generic rail chat | `agents` surface chips: `Create new agent`, `From template`, `Import` — first-action obvious; chat narrates if user idle |
| S5: edits drift because two stacks | Form on left, chat on right, neither knows what the other did | Shared action layer + bus: every edit visible to both surfaces; assistant can proactively offer next verb |
| S6: outcomes invisible | Analytics page is a wall of numbers | `analytics` surface chips: `What worked this week?`, `Compare cohorts` — chat synthesises into a sentence |
| S7: invites buried in settings | Multi-click flow | `people` surface chip: `Invite my team` — one prompt, action.execute, done |
| S8: shareable artifacts don't drive traffic back | Share pages exist but flat | `share` + `studio` surfaces: visitor-mode rail chat with `Sign up`, `Clone thread`, `Chat with agent` — share IS a funnel entry |

### Implications for the action registry

The funnel map adds three things that weren't in the prior cycle list:

1. **Anonymous-visitor actions** — `signup.start`, `slug.check`, `claim.start`, `demo.try`. These belong in `actions/onboarding.ts` (new file in Cycle 2). They execute against the public API only (no auth assumed).
2. **Stage transitions as first-class actions** — `passkey.provision`, `recovery.save`, `workspace.scaffold`, `agent.firstScaffold`. These are the S3 → S4 hinges; instrument them so we can see drop-off per stage, not per page.
3. **Per-surface agent system prompt** — the assistant on `agents` is not the same as on `analytics`. Each surface ships a short system-prompt fragment (`actions/agents.ts` exports a `systemPrompt` string) that frames the verbs in that stage's language ("Let's get your first agent live" vs. "Let's see what worked this week").

Add to `actions/_types.ts`:

```ts
interface ActionSurfaceMeta {
  stage: 'S0'|'S1'|'S2'|'S3'|'S4'|'S5'|'S6'|'S7'|'S8'
  systemPrompt: string
  emptyState: { title: string, hint: string }
}
```

Each surface module exports its `ActionSurfaceMeta` alongside its actions. `actionsForSurface(surface, viewer)` returns `{ actions, meta }`. Cycle 3's `ChatSurfaceIntro` uses `meta.emptyState`; `/api/chat` injects `meta.systemPrompt`.

### What to instrument

Per-stage events emitted onto the action bus (and into the substrate via existing pheromone):

```
funnel.S0.arrive   — first paint with referrer
funnel.S2.first-message
funnel.S3.passkey-saved
funnel.S4.first-agent
funnel.S6.first-outcome   — agent ran end-to-end with mark()
funnel.S7.invite-sent
funnel.S8.share-opened
```

These are deterministic counters (per Rule 3). Reports go on `analytics` surface; the chat there can answer "where am I leaking?" by reading them.

---

## Cycle ordering rationale

Cycle 1 unblocks the bug. Cycle 2 is the structural investment — everything else depends on it. Cycle 3 makes the existing split UX work. Cycle 4 unlocks chat-full. Cycle 5 is the UI rebuild on shared primitives. Cycle 6 hardens authz with the role/cascade model from `roles.md` — should land **early** (right after Cycle 2) for security, but documented last because it's a refinement of Cycle 2's draft. Each cycle gates on the prior cycle's W4 numbers.

Shippability:
- **Cycle 1** alone — ships, fixes the bug.
- **Cycles 2–3** — must ship together. Partial action layer = drift.
- **Cycle 6** — should ship together with Cycle 2's first release (security boundary; coarse `permission: Viewer[]` is acceptable in dev but not in prod).
- **Cycle 4** — can ship after 2–3 land, independently per page.
- **Cycle 5** — can ship per page or per-primitive-group. Each rebuilt page is its own shippable unit.
