---
name: agent-integration
description: Wire /org as a live view over shipped agent infrastructure. Chat becomes the third editor (after CLI and direct MD). ReactFlow shows signal collaboration.
mode: lean
lifecycle: construction
priors:
  spec_locked: true        # agent-spec.md + agent-api.md + agent-lifecycle.md hold the contract
  variance_known: true
  exit_scalar: true
  files_known: true
exit_scalar: "edit MD anywhere (CLI / chat / drag) → /org reflects it via SSE within 1s. ≥28 agents render. No new schema, no new publish pipeline."
---

# agent-integration

`/org` is a window onto the **already-shipped agent fleet**. Chat gains one new tool. ReactFlow gains a signal-graph view. No new schema, no new persistence, no new event bus. The substrate already does this.

---

## What this replaces

The org component **is** the per-workspace agent UI. All these routes consolidate into one mount of `<OrgChartView slug={slug} />` plus drawers in `RoleDetailPanel`:

| Today | Tomorrow |
|---|---|
| `/u/[slug]/agents/new` (AgentForm page) | `+ Add agent` button → modal hosting `AgentForm` |
| `/u/[slug]/agents/[id]/analytics` (funnel page) | "Analytics" tab inside `RoleDetailPanel` (or deep link kept) |
| `/u/[slug]/agents/[id]/funnel` | "Funnel" tab inside `RoleDetailPanel` |
| `/u/[slug]/agents/[id]/actor/[actorId]` | Drill-down from Analytics tab |
| Marketing `/org` (top-level, ONE fleet) | Stays — same component, no slug, hardcoded scope |

So `OrgChartView` gains a `slug?: string` prop. When set: scoped roster for that workspace. When absent: the ONE fleet (current behavior). One component, two surfaces.

`/u/[slug]/agents/index.astro` (new) is the only new page; it's a 12-line Astro file that resolves owner-gate (same pattern as today's `new.astro`) and mounts `<OrgChartView slug={slug} client:only="react" />`. The four existing pages get deleted in phase 5 once parity lands; their components (`AgentForm`, `LifecycleFunnel`, etc.) move into drawers and stay reused.

---

## Multi-tenancy — every workspace gets its own fleet

Two tiers, no live link between them:

| Tier | Where | Mutable by |
|---|---|---|
| **ONE master fleet** (28 agents) | `one.ie/agents/*.md` in git | Core team only — committed via PR |
| **Workspace fleet** | R2 at `${slug}/agents/*.md` + D1 `agents` table | The workspace owner (and their LLM via chat) |

**Hard-fork on workspace creation.** When `acme` signs up:

1. Workspace-create hook calls `seedAgents(slug, pack)`
2. `seedAgents` reads ONE fleet, filters by starter pack, deep-copies each `.md` to `R2:acme/agents/{name}.md`, upserts D1 row with `owner_id = acme.owner`
3. `acme/agents/cmo.md` is now a fully independent file — no pointer back. ONE updates to its master CMO don't propagate.

This is the agency-friendly model. Stability beats freshness. If a workspace wants to pull updates later, surface a "merge from master" button (deferred).

### Starter packs

Picked once at signup, controls which subset of the ONE fleet gets copied.

| Pack | Who it's for | Seeds |
|---|---|---|
| `solo` | Solo founder, consultant | chairman + ceo + 1 specialist (chosen) |
| `business` | SMB | + full marketing (7) + sales (4) + service (5) — the default |
| `agency` | Agency reselling ONE | full ONE fleet (28) + custom client templates (deferred) |

The home page already classifies visitors by persona (`lib/home-sections.ts:165-167` — agency / business / consultant). That signal carries through to signup and picks the pack.

### Add / edit / delete (already shipped — verify only)

| Op | Endpoint | Status |
|---|---|---|
| Add | `POST /api/agents` (D1 insert) + `POST /api/agents/publish` (R2 write) | ✓ shipped per [`agent-api.md`](agent-api.md) |
| Edit | `PATCH /api/agents/[id]` | ✓ shipped (`api/agents/[id].ts:GET+PATCH` confirmed) |
| Delete | `DELETE /api/agents/[id]` — soft-delete: set `state=retired`, archive R2 object | needs DELETE handler in `[id].ts` (~15 lines) |

All three flow through the same publish pipeline → same `agent:<uid>:updated` signal → same propagation.

### What this means for the agency persona

- Agency `agency.one.ie` workspace gets the `agency` pack (full 28 agents).
- They edit copywriter.md → "Sarah's brand voice" — this only changes `agency/agents/copywriter.md`.
- They spin up `client-1.one.ie` for a client → that workspace gets the `business` pack from the ONE master (not from the agency's customizations — for now).
- Phase 7+ (deferred): "Spawn client workspace from THIS workspace's fleet" — uses an agency's customized fleet as the template for new client signups.

---

## The interaction surface — one pattern, every field

Owners edit through the **right panel** (`RoleDetailPanel.tsx`) that already opens on agent click. Every editable field uses the same two-mode shape: **chip when reading, picker when writing**. No bespoke widgets per field.

| Field | Read state | Write action |
|---|---|---|
| Skills | Chips with ✕-on-hover | "+ Add skill" → search picker over `/api/skills` |
| Tools | Chips grouped by app, status dot (●=connected, ○=connect first) | "+ Add tool" → search picker; OAuth flow inline if app needs connection |
| Reports to | Badge with manager's name | Click badge → searchable agent dropdown → pick → done |
| Group (team) | Tone-colored badge | Click badge → 6-group dropdown (marketing/sales/service/eng/community/governance) |
| Tagline | Inline text | Click → contenteditable → blur saves |
| Starters | Bulleted list | "+ Add starter" → text input → enter saves |
| KPIs | Chips | Same chip + picker |
| Body (system prompt) | "Edit prompt" button | Opens Monaco drawer (phase 7) |

**One reusable picker component**: `<EntityPicker source="skills|tools|agents|groups" onPick={...} />`. cmdk-style search (shadcn `Command`), keyboard-driven. Different `source` swaps the data fetch and chip renderer; everything else is identical. **~80 lines total for the picker**, shared across all five fields.

**The optimistic loop** (same for every field):

```
user picks → chip appears immediately
           → PATCH /api/agents/[uid] with { skills: [...prev, new] } + If-Match: generation
           → 200 → chip stays, generation++
           → 409 → chip rolls back, toast "Someone else just edited — refresh"
           → 422 (cycle, bad data) → chip rolls back, toast with reason
```

Optimistic UI means the panel feels instant; the server is the only judge.

### Drag-drop is a *shortcut*, not a feature

In the ReactFlow Signal Graph view (phase 4), the user can drag a node onto another node:

- **Drop on agent** → modal "Make X report to Y?" → confirm → same `PATCH { reports_to: 'one:y' }`.
- **Drop on team column** → no modal needed → `PATCH { group: 'sales' }`.

Drag-drop covers 100% of structural moves. The click-picker covers 100% of the same moves *plus* skills/tools/etc. We ship the picker first (phase 3); drag-drop layers on (phase 4) as a power-user shortcut, never as the only path.

### Composio: one OAuth, many tools

Adding a Composio tool flows through one connection per app per workspace:

1. User picks `composio:slack.send_message` in the Tools picker.
2. If Slack not connected: picker shows "Connect Slack" button inline.
3. Click → `GET /api/composio/connect?app=slack` (shipped) → OAuth window → callback (shipped) → workspace row gets `composio_connections.slack: { id, scopes }`.
4. Picker re-checks status, shows ● Connected, attaches the tool to the agent's `tools:` array.
5. Subsequent Slack tools (`slack.list_channels`, `slack.upload_file`) just attach — no new OAuth.

The agency adds one Composio connection at the workspace level; every agent under that workspace can use any tool from that app. Tools-per-agent is the whitelist; connection-per-workspace is the auth.

### The same edit from chat

"Make Account Manager report to the CXO" in chat → LLM calls `edit_agent({ uid, patch: { reports_to: 'one:cxo' }, expectedGeneration })` → identical PATCH → identical signal → panel updates live via SSE.

**The picker and the chat are two faces of the same edit.** Any field reachable by click is reachable by sentence.

---

## ReactFlow as a living org — three edge types, pheromone-weighted

The graph isn't a diagram. It's a **real-time picture of the substrate**. Three edge types overlay the same node set. Pheromones (the `path.weight` field in `one.tql`) decide which connections are real and which are decorative.

### Three edge types, three meanings

| Layer | Source | Meaning | Visual |
|---|---|---|---|
| **Hierarchy** | `reports_to` in MD | Formal org chart | Solid gray, thin, always visible |
| **Declared** | `emits ∩ subscribes` in MD | Designed collaboration routes | Dashed, light, on Signal Graph view |
| **Learned** | `path.weight` (pheromone) | Actual usage — where work flows | Bold; thickness = weight, color = success rate, glow = recent traffic |

Toggle in the `/org` header: **Org** · **Signals** · **Heatmap** · **Overlay** (shows all three at once for power users).

The **Learned** layer is what makes this alive. An agency owner can *see* their team work — the CMO→Sarah edge is thick and green; the CMO→Alex edge is thin and yellow; that tells them more than any metric dashboard.

### Pheromone visuals — one rule per attribute

| Edge attribute | Visual mapping | Source field |
|---|---|---|
| Thickness | `clamp(weight / 10, 1, 8)` px | `path.weight` |
| Color | hue = `success-rate` (0=red → 1=green); saturation = `confidence` (low samples = pale) | derived from mark/warn counts |
| Opacity | `1 - resistance` | `path.resistance` |
| Glow / pulse | one pulse per signal in the last 5s | live SSE feed |
| Dotted decay | `path.fade-rate > threshold` and no recent traffic | derived |
| Hidden | weight < 0.5 and no recent traffic | derived — keeps graph readable |

The pulses are **the chat happening, drawn**. When the CMO delegates to Sarah, the CMO→Sarah edge pulses with the signal's color. When Sarah replies, it pulses back. The org isn't a snapshot; it's a heartbeat.

### Pheromones determine delegation routing

The `delegate_to` tool from the chat section asks: *"who should handle this?"* The answer comes from pheromones, not from MD config.

```ts
function pickDelegate(callerUid: string, intent: string, roster: Roster): string {
  const candidates = roster.filter(r =>
    canDelegate(callerUid, r.uid, roster) &&
    (r.subscribes.includes(intent) || r.skills.some(s => matches(s, intent)))
  )
  // weighted softmax over learned paths
  const scores = candidates.map(c => {
    const path = getPath(callerUid, c.uid)
    return Math.exp(path.weight) * path.successRate
  })
  return weightedSample(candidates, scores)  // ε=0.1 exploration
}
```

This is the L4 routing loop documented in [`agent-api.md`](agent-api.md) — paths shift to KV-cached highways after 50 successful marks. **`delegate_to` doesn't pick the declared route; it picks the proven route.** The MD's `emits:` field defines what *could* happen; pheromones decide what *does*.

When delegation closes:
- Success → `POST /api/mark/[edge]` → `weight += 0.5`
- Failure → `POST /api/warn/[edge]` → `resistance += 0.5`

Both endpoints already exist. Every chat turn that uses `delegate_to` produces one mark or warn. The graph re-renders next SSE tick. **Learning loop = chat loop.**

### Edit affordances directly on the graph

Right-click an edge or a node:

| Action | What it does | Where it lands |
|---|---|---|
| **Boost** | manual `mark(+5)` to nudge routing | `POST /api/mark/[edge]?delta=5` (shipped) |
| **Suppress** | manual `warn(+5)` | `POST /api/warn/[edge]?delta=5` (shipped) |
| **Pin** | freeze weight against decay | `POST /api/harden/[edge]` (shipped — `harden` is one of the 6 verbs) |
| **Cut** | manual `fade` to 0 | `POST /api/fade/[edge]` (shipped) |
| **Reroute** | drag edge endpoint from A→B to A→C | atomic: fade A→B + mark A→C (UI sugar) |
| **Inspect** | open side drawer with full history | reads `api/agents/history.ts` |

The agency owner can shape their org's pheromones without touching MD frontmatter. The MD describes *capability*; the pheromones describe *trust*. Owner overrides change trust, not capability.

### Pheromone-derived suggestions

The "Suggestions" panel from the non-tech section pulls insights directly from path weights:

- *"Sarah delegates 81% to Alex. Want to make Alex her direct report?"* → one-click `PATCH { reports_to: 'one:alex' }`
- *"The CMO→Old-Strategist edge has decayed to 0.3 over 30 days. Retire that link?"* → one-click `fade`
- *"Three agents subscribe to `campaign:brief` but only Sarah responds. Remove the others?"* → one-click batch unsubscribe
- *"You have no learned path from Sales → Service yet. Want a test handoff?"* → simulated signal

Each suggestion is a query against the substrate's signal history. The endpoint that generates them (`/api/agents/[uid]/suggestions` from earlier, ~70 LOC) gains one more data source — the pheromone table — and ~30 LOC of analytics queries.

### Live signal stream → ReactFlow updates

The graph already has `useSubstrateStream` from phase 2. Extending it to drive edge animation:

```ts
useSubstrateStream(['agent:*:updated', 'signal:*', 'mark:*', 'warn:*'], (event) => {
  if (event.kind === 'signal') pulseEdge(event.edge, event.color)
  if (event.kind === 'mark')   updateEdgeWeight(event.edge, +event.delta)
  if (event.kind === 'warn')   updateEdgeResistance(event.edge, +event.delta)
  if (event.kind === 'agent:updated') refetchNode(event.uid)
})
```

Edges animate without a re-fetch. The SSE relay already broadcasts these — we just subscribe to more receivers. ~40 LOC.

### Why this is feasible

Every primitive is shipped:

| Primitive | Where |
|---|---|
| `path` entity with weight/resistance | `schema/one.tql` |
| `mark` / `warn` / `fade` / `harden` endpoints | `api/mark/`, `api/warn/`, `api/fade.ts`, `api/follow/` |
| SSE event stream for path mutations | `workers/analytics-relay.ts` |
| Client SSE consumer | `hooks/use-substrate-stream.ts` |
| L4 highway promotion | documented in `agent-api.md`, executed by `agents/` worker |
| `harden` verb (pin a path) | one of the 6 locked verbs |

What this section adds: a **custom ReactFlow edge renderer** (`AnimatedSignalEdge.tsx`, ~80 LOC), the **routing helper** `pickDelegate` (~25 LOC, used by `delegate_to`), the **subscription wiring** in the graph component (~40 LOC), and the **pheromone analytics queries** in suggestions (~30 LOC). **~175 LOC total.**

### The end-to-end vision in one sentence

The org chart is the *design*; the signal graph is the *contract*; the heatmap is the *truth* — and chat delegations move along the truth, not the contract.

---

## Chat — what it means when agents collaborate

When the user asks the CMO for a Q4 campaign, the CMO doesn't write everything alone — it pulls in the copywriter, strategist, and SEO specialist. The chat surface must show this **simply enough for an end-user, fully enough for the agency owner**.

### One mechanism: `delegate_to` tool + `team-message` RichMessage

Inter-agent collaboration is just a **chat tool** the LLM can call:

```ts
delegate_to: tool({
  description: "Hand off a sub-task to another agent in your org. Use sparingly — only for work outside your direct skills.",
  inputSchema: z.object({
    agent: z.string(),                       // uid, validated against caller's permitted-targets list
    task: z.string(),                        // plain-English brief
    return_format: z.enum(['summary','verbatim','structured']).default('summary'),
  }),
  execute: async ({ agent, task, return_format }, ctx) => {
    if (!canDelegate(ctx.callerUid, agent)) return { ok: false, reason: 'not_authorized' }
    const result = await runAgentTurn(agent, task, { parent: ctx.callerUid, depth: ctx.depth + 1 })
    return { type: 'team-message', from: agent, content: result, summarized: return_format === 'summary' }
  },
})
```

The tool's `execute` calls the same `/api/chat` pipeline recursively for the delegated agent. The return is a `RichMessage` of kind `team-message` (extending the shipped RichMessage schema in `docs/rich-messages.md` — one new kind, ~15 LOC of renderer). **No new endpoint, no new event bus, no parallel chat protocol.**

### What each user actually sees

**End user** (visitor on `acme.one.ie`, chatting with Account Manager about a refund):

```
You: I need a refund on order #4421.

[Account Manager] Looking into your account... I've processed the refund
                  for $89.99 — you'll see it in 3 business days. Anything else?
```

Team coordination collapsed by default. A subtle footnote *"Coordinated with Refund Specialist"* appears under the message if they care to read it. Single voice. No cognitive load.

**Business owner / agency owner** (in their workspace's `/chat` or `/org` chat panel):

```
You: Draft me a Q4 campaign for the new espresso machine.

[CMO] Coordinating with the team...

  ▼ Team work (3 agents · 4.2s)
    ├ Sarah (Copywriter): "3 headline options — 'Coffee shop quality...' ..."
    ├ Alex (Strategist):  "Position vs. Breville. Lean into the 'kitchen counter convenience' frame..."
    └ Jordan (SEO):       "Top keywords: home espresso machine, barista quality coffee..."

  Here's the campaign:
  Position: Premium home barista
  Hook: "Coffee shop quality, kitchen counter convenience"
  Channels: paid social (IG/TikTok), SEO content, email nurture
```

Expanded by default. Each agent's contribution is a nested message under the orchestrator. Owner can click any contributor's name → opens that agent's panel → "Talk to" → direct conversation. Owner can also interject mid-stream ("actually, position against Nespresso instead") — the CMO re-delegates with the correction.

**Agency owner managing multiple workspaces**: same as business owner, plus a workspace switcher above the chat. Each workspace has its own org, its own agents, its own conversations.

### Toggle: "Show team coordination"

A single boolean per chat surface. Defaults:

| Surface | Default |
|---|---|
| `/u/[slug]/chat` (anon visitor) | **off** — single voice |
| `/chat` for logged-in owner | **on** — expanded team view |
| `/org` side-rail chat | **on** — owner is exploring their team |
| Embedded chat widget (3rd party site) | **off** — branded as one agent |

User can flip the toggle per session. Stored in `localStorage`, surfaced in chat header. ~10 LOC.

### Who can delegate to whom

The org chart **is** the delegation graph. By default:

- An agent can delegate **down** (direct reports + their descendants) freely.
- An agent can delegate **sideways** (same tier, different group) only if granted a `delegation` capability (per `agents.md` capability pattern). E.g., CMO ↔ CRO is one cross-link, configurable.
- An agent **cannot** delegate **up**. The CEO is asked, not bossed.

Enforcement is one helper: `canDelegate(callerUid, targetUid, roster)` — DFS on `reports_to`, returns boolean. ~15 LOC. Server-side; the LLM doesn't get to bypass.

### Depth, cost, and termination

- **Depth limit**: 3. Caller → delegate → sub-delegate → leaf. Stops infinite chains. Configurable per workspace, hard-capped at 5.
- **Fan-out**: parallel by default. CMO's 6 emits all stream concurrently; the synthesizer waits for all (or hits a 30s timeout and synthesizes from what it has, marking missing).
- **Cost budget**: each turn carries a token budget that decrements per delegation. Default 50K tokens per top-level turn. If budget hits zero mid-tree, deeper delegates return `{ok: false, reason: 'budget'}` and the orchestrator synthesizes from received fragments.
- **Streaming**: delegated agent's response streams into the team-message child slot as it arrives. User sees agents typing in parallel. ~20 LOC to wire SSE child streams into the parent RichMessage renderer.

### Signal-driven (auto) vs tool-driven (LLM-decided) collaboration

Both already exist in the substrate; chat exposes the LLM-decided path.

| Path | When it fires | User-visible? |
|---|---|---|
| **Tool-driven** (`delegate_to`) | LLM judges current request needs another agent | yes — team-message in chat |
| **Signal-driven** (`emits:` in MD frontmatter) | Async background — campaign briefs, scheduled tasks, webhooks | only if the user is watching that agent's activity feed |

For the chat user, only tool-driven matters. Signal-driven is the substrate doing background work (e.g., the CMO's nightly campaign-performance signal to the analyst). It surfaces as notifications, not as chat messages, unless the user opens the agent's activity log.

### Chat as the editor — the recursive trick

The user can also chat with the CMO and say: *"From now on, when someone asks about Q4 planning, always loop in the analyst."* The CMO calls `edit_agent({ uid: 'one:cmo', patch: { delegation_rules: [...] } })`. The CMO has just edited itself based on user instruction. **The chat is simultaneously the conversation surface, the editor, and the orchestration trace.**

This is the same `edit_agent` tool from phase 3, scoped to the calling agent's own uid (or anywhere the chatting user has owner permission). No new infrastructure.

### What ships in this scope

| Piece | LOC |
|---|---|
| `delegate_to` chat tool + `canDelegate` helper | ~50 |
| `team-message` RichMessage kind + renderer | ~40 |
| Depth/budget tracking in chat context | ~20 |
| Parallel child SSE streams | ~30 |
| Toggle in chat header + localStorage | ~10 |
| Delegation footnote for collapsed view | ~10 |
| **Total** | **~160 LOC** |

---

## For non-tech users — what makes it feel easy

The agency owner is not reading YAML. The shop owner doesn't know what a "frontmatter" is. Every visible label, default, and flow optimizes for *them*. Most of these are wording and defaults — not new code.

### 1. Chat is the universal easy mode

Anything reachable by clicking is reachable by sentence. "Give my account manager the Slack tool", "Make her report to the CXO", "Add a refund specialist". The chat-side `edit_agent` tool (phase 3) handles all of it. **For users who can't find a button, the answer is always: type what you want.** Surface this in onboarding as the primary tip.

### 2. Merge "skills" and "tools" into **abilities**

Non-techies don't know (or care) why one is internal-MD and the other is OAuth-wired. The UI shows one section: **Abilities**. One picker. One add button. Behind the scenes it routes to `skills:` or `tools:` based on type. *No mental load.*

### 3. Plain-language labels — no jargon ever surfaces

| Internal | What the user sees |
|---|---|
| `uid: one:account-manager` | (hidden by default; "Show technical details" toggle for power users) |
| `composio:slack.send_message` | "Send a Slack message" |
| `builtin:web-browse` | "Browse the web" |
| `kind: skill` / `kind: tool` | "Ability" |
| `frontmatter` | "Settings" |
| `publish / draft / generation` | (hidden — every edit goes live; undo toast handles regret) |
| `409 generation conflict` | "Someone just made changes. Refresh to see them." |
| `cycle detected` | "Can't do that — your CEO would end up reporting to one of their reports." |

A small `lib/labels.ts` (~30 LOC) maps internal IDs to display strings. The chat tool also reads it so the LLM uses the friendly names.

### 4. Role gallery instead of blank "+ New agent"

"+ Add team member" opens a gallery of **8–10 pre-built roles** (Support, Closer, Account Manager, SEO Specialist, Bookkeeper, Recruiter, Onboarder, Refund Specialist). Each is a copy of a `one.ie/agents/*.md` template. Pick → name them ("Sarah") → tone toggle (friendly / professional / snappy) → done. Three clicks instead of a form.

Blank-MD authoring stays available for power users — behind a "Start from scratch" link at the bottom of the gallery.

### 5. AI-suggested actions in every panel

Bottom of `RoleDetailPanel`, a small section: **Suggestions for this agent**. Examples:

- *"Connect Slack so Account Manager can message your team — Connect"*
- *"This agent has no abilities yet. Add the standard ones for an Account Manager? — Add 4 abilities"*
- *"You don't have anyone handling refunds. Add a Refund Specialist? — Add agent"*

Suggestions come from a single `/api/agents/[uid]/suggestions` endpoint (~40 LOC) that prompts the LLM with the agent's current state + workspace context and returns 0–3 one-click actions. Each action is a pre-baked PATCH call.

### 6. Conversational onboarding (optional, high-impact)

First-time agency owner lands on `/u/acme/agents` — empty state offers two paths:

- **"Start with a template team"** → seeds the `business` pack instantly (phase 6 default)
- **"Tell me about your business"** → opens chat → LLM asks 4 questions → builds the org chart from conversation → reviews "Here's your team — keep, edit, or add."

The chat path uses the same `edit_agent` tool repeatedly. **No new endpoints.** Just a system prompt that knows how to interview and build.

### 7. No "publish" concept ever shown

Every chip add, picker pick, drag, and chat-edit goes live immediately. Versioning is silent (already shipped via `api/agents/history.ts`). Undo toast for 8 seconds after any change. "Saved 2 minutes ago · View history" link for power users who want the audit trail.

Removes draft/publish confusion. Removes the "Save" button. Removes dirty-state tracking on the client.

### 8. Defaults eliminate choice paralysis

| Decision | Default |
|---|---|
| Starter pack at signup | `business` (full marketing+sales+service). No picker. They delete what they don't need. |
| Agent model | `anthropic/claude-sonnet-4` (set in template) |
| Tone | "Friendly" (overridable) |
| Voice | `alloy` |
| Lifecycle | `active` on create |
| Reports-to for new agent | Group's director (auto-derived from `group:` field) |

Every default is overridable, but no default is asked at the time of decision. Decision count drops from ~8 questions to ~1 (just name).

### What this adds (LOC honest count)

| Piece | LOC |
|---|---|
| `lib/labels.ts` — internal→display name map | ~30 |
| Role gallery component (10 cards from `agents/*.md`) | ~80 |
| Suggestions endpoint + bottom-of-panel section | ~70 |
| Conversational onboarding system prompt | ~0 code; pure prompt engineering |
| Undo toast (one component, reused everywhere) | ~25 |
| Plain-language error mapper in PATCH responses | ~20 |
| **Total added for non-tech polish** | **~225 LOC** |

Combined with the simplified ~410 LOC base from earlier, the whole owner-facing surface is **~635 LOC**. That's about a week of focused work for one engineer.

### Speed wins (perceived + real)

- **Bulk-fetch the panel data** alongside the roster: `/api/agents/roster?slug=X&include=skills,tools` returns everything for all agents in one round trip. Opening a panel is then 0ms — data is already client-side. (~10 LOC server-side join.)
- **Skeleton screens** everywhere fetching happens (`<RolePanelSkeleton />` ~15 LOC).
- **Prefetch on hover**: hovering an agent card kicks off the `useAgent(uid)` fetch before click. Net: click feels instant.
- **No multi-step where one click works**: role gallery commits on pick (auto-names), not after a 5-field form.
- **Sensible defaults** above mean no spinner at all for 90% of common actions.

---

## The kernel

An agent is `actor` in `schema/one.tql:41`. Its `.md` file is the editorial form; R2 holds the published copy (versioned, rollback-capable per [`agent-spec.md`](agent-spec.md)). **Any edit, anywhere, ends in `POST /api/agents/publish` and emits `agent:<uid>:updated`.** Every view subscribes to that signal via the existing SSE relay.

```
edit (CLI publish | chat tool | ReactFlow drag)
        │
        ▼
POST /api/agents/publish   ← already shipped: Zod validate, version, R2 write, D1 upsert
        │
        ▼
signal: agent:<uid>:updated   ← already shipped: /api/signal/[receiver]
        │
        ▼
AnalyticsRelay DO broadcasts  ← already shipped
        │
        ├──►  /org (re-renders via useSubstrateStream — already shipped)
        ├──►  active chat session (re-keys system prompt on next turn)
        └──►  ReactFlow graph (edges recomputed from emits/subscribes)
```

---

## What we leverage (shipped)

| Need | Lives at | Status |
|---|---|---|
| MD schema + parser + Zod | [`agent-spec.md`](agent-spec.md), `lib/agent-md.ts` | ✓ |
| Publish pipeline + versioning + rollback | [`agent-api.md`](agent-api.md), `api/agents/{publish,rollback,history}.ts` | ✓ |
| Lifecycle (active/beta/deprecated) | [`agent-lifecycle.md`](agent-lifecycle.md), `lifecycle:` frontmatter field | ✓ |
| MD body = system prompt (verbatim) | [`agent-spec.md`](agent-spec.md) | ✓ — resolves the "two prompts" worry |
| Bearer-token write auth (workspace-scoped) | [`agent-api.md`](agent-api.md) | ✓ |
| Signal endpoint + SSE relay + client hook | `api/signal/[receiver].ts`, `workers/analytics-relay.ts`, `hooks/use-substrate-stream.ts` | ✓ |
| Composio OAuth | `api/composio/{connect,callback,redirect}.ts` | ✓ |
| Tool-approval protocol in chat | AI SDK v6 in `Chat.tsx` | ✓ |
| `actor.generation` (optimistic-lock primitive) | `schema/one.tql:47` | ✓ |

---

## What's actually new

Three things. That's the whole plan.

### 1. `edit_agent` chat tool — ~30 lines

```ts
// one.ie/web/src/lib/chat-tools/edit-agent.ts
export const editAgent = tool({
  description: 'Patch an agent\'s frontmatter (skills, tools, group, reports_to, tagline, starters).',
  inputSchema: z.object({ uid: z.string(), patch: AgentPatch, expectedGeneration: z.number() }),
  execute: async ({ uid, patch, expectedGeneration }, { request }) => {
    const r = await fetch(`/api/agents/${uid}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', 'if-match': String(expectedGeneration), cookie: request.headers.get('cookie') ?? '' },
      body: JSON.stringify(patch),
    })
    if (r.status === 409) return { ok: false, reason: 'stale', current: await r.json() }
    return r.ok ? { ok: true } : { ok: false, error: await r.text() }
  },
})
```

Registered in `api/chat.ts` tools array. Tool approval (existing) gates execution. `If-Match: generation` is the only concurrency control — server returns 409 if generation drifted; chat re-reads and retries. Reuses the publish pipeline; no new write path.

### 2. `/org` becomes live — ~50 lines changed

- `pages/api/agents/roster.ts` — NEW (one route): reads agents, filters `kind: agent`, projects to `Role[]`, KV-cached 60s.
- `components/org/OrgChartView.tsx` — replace `import { rosterFor }` with `useEffect(fetch + useSubstrateStream('agent:*:updated'))`.
- `lib/org-roster.ts` — DELETE after migration.

### 3. ReactFlow signal graph — ~80 lines

- `components/org/SignalGraph.tsx` — NEW. Nodes from roster; edges derived from `emits ∩ subscribes`. Drag = `PATCH /api/agents/[uid]` with `{ group }` or `{ reports_to }`. Existing publish pipeline.
- `pages/org/index.astro` — add view toggle: Tree | Signal Graph.

That's it. **No new endpoints beyond `/api/agents/roster.ts`.** No new DB tables. No new workers.

---

## Migration (phase 0 — authoring, not code)

Pure markdown editing. No deploy needed.

1. Backfill 8 org fields (`group`, `tier`, `reports_to`, `tone`, `icon`, `tagline`, `starters`, `kpis`) across 19 agents in `one.ie/agents/` that lack them.
2. Scaffold 5 missing senior agents: `chairman.md`, `ceo.md`, `cro.md`, `cxo.md`, `cco.md` (`cmo.md` and `cto.md` already exist — verify).
3. Mark `handle-complaint.md`, `tag-suggest.md`, `template-starters.md` as `kind: skill` so the roster derivation skips them.

Existing publish pipeline validates all edits.

---

## Lifecycle of an edit — the only thing worth tracing

Same path for every editor:

| Step | What | Where |
|---|---|---|
| 1. Intent | User in chat / drag in ReactFlow / `oneie agent publish` | UI or CLI |
| 2. Authz | Bearer token (CLI) or session role check (UI) | `api/agents/[id].ts` PATCH |
| 3. Validate | Zod parse — fail loudly | `lib/agent-schema.ts` (exists) |
| 4. ETag check | `If-Match: generation`, 409 on drift | NEW: one line in PATCH handler |
| 5. Persist | R2 write, D1 upsert, increment `generation` | `api/agents/publish.ts` (exists) |
| 6. Announce | `signal: agent:<uid>:updated` | `api/signal/[receiver].ts` (exists) |
| 7. Propagate | AnalyticsRelay DO → SSE | `workers/analytics-relay.ts` (exists) |
| 8. Reflect | `/org` re-renders; chat re-keys prompt on next turn; ReactFlow recomputes edges | client hooks (exist) |

L5 prompt evolution (when shipped — see [`agent-lifecycle.md`](agent-lifecycle.md)) follows the same 8 steps; it just originates from the learning loop instead of a human.

---

## Phases — each ≤ 1 day

| # | Goal | Files touched | Exit |
|---|---|---|---|
| 0 | Migration (markdown only) | 19 backfills + 5 scaffolds + 3 reclassifications | All MD files Zod-valid; roster derivation yields ≥28 agents |
| 1 | `roster` endpoint (slug-aware) + delete static roster | `api/agents/roster.ts` (accepts `?slug=`), `OrgChartView.tsx` (gains `slug?` prop), `-org-roster.ts` | `GET /api/agents/roster?slug=acme` returns workspace agents; `/org` renders ONE fleet |
| 2 | SSE on `/org` | `OrgChartView.tsx` adds `useSubstrateStream('agent:*:updated')` | Edit any MD → view updates within 1s, no reload |
| 3 | `edit_agent` chat tool | `lib/chat-tools/edit-agent.ts`, register in `api/chat.ts`, add `If-Match` to PATCH | Chat: "give X the Slack skill" → file changes, view reflects |
| 4 | ReactFlow signal graph | `components/org/SignalGraph.tsx`, view toggle | Real `emits ∩ subscribes` edges; drag updates frontmatter |
| 5 | Consolidate `/u/[slug]/agents/*` into OrgChartView | NEW `pages/u/[slug]/agents/index.astro`; move `AgentForm` + `LifecycleFunnel` into drawers in `RoleDetailPanel`; delete old `new.astro` + `[id]/{analytics,funnel,actor}.astro` once parity verified | `/u/[slug]/agents` shows workspace org chart; create + analytics + funnel reachable from panel; old routes 301 to deep links |
| 6 | Seed-on-create + delete handler | NEW `lib/seed-agents.ts` (~50 LOC: read ONE fleet, filter by pack, deep-copy to `R2:${slug}/agents`, batch-insert D1); call from workspace-create hook; add `DELETE` handler to `api/agents/[id].ts` (~15 LOC) | New workspace lands on `/u/[slug]/agents` and sees their full team. Owner deletes agent → soft-retire, signal fires |

Phases 7+ (Composio tool picker UI, inline Monaco body editor, history panel exposing `rollback.ts`, agency "spawn workspace from my fleet" template flow) are pure UI / config on top of shipped APIs — defer until 0–6 prove out.

---

## Feature-complete — the remaining gaps, each in one line

Every open question gets a minimum-viable answer. None deferred without being named.

| Gap | Resolution |
|---|---|
| **Signal storm** when chat makes 5 edits in 10s | `AnalyticsRelay` DO coalesces per receiver in a 250ms window (its alarm pattern already does this — flag with `coalesce:true` on emit). One SSE frame, not five. |
| **Toast system** | Use **Sonner** if present in `package.json`; else add it (~3 KB, one provider mount in `Layout.astro`). One toast component drives undo + errors + success. |
| **MD serializer idempotency** | `js-yaml` (already in deps) with `noRefs: true` + fixed key order list in `agent-schema.ts`. Golden-file tests: `parse(serialize(parse(x))) === parse(x)` for all 23 existing files. ~120 LOC for serializer + ~30 LOC for tests. |
| **Group delete cascade** | Six groups are **fixed in v1** (marketing/sales/service/engineering/community/governance). No delete UI. Custom groups deferred to phase 7+. Eliminates cascade entirely. |
| **Tool execution end-to-end** (Composio call from chat) | When LLM calls `composio:slack.send_message`: chat runtime looks up workspace's `composio_connections.slack.id`, calls Composio's `executeAction(toolName, params, connectionId)`. ~20 LOC adapter in `lib/composio.ts`. Returns result to LLM as tool output. |
| **Seed bootstrap atomicity** | `seedAgents(slug, pack)` writes to a temp prefix `${slug}/.seeding/agents/*`, then atomically renames on D1-transaction commit. On failure: cleanup + retry once + mark `workspace.seed_status='failed'` + show "Set up your team manually" CTA. |
| **First-load empty state** while seed runs | `/u/[slug]/agents` shows skeleton + banner: "Setting up your team — this takes about 5 seconds." Polls `/api/workspace/[slug]/seed-status` every 500ms. Mounts OrgChartView when ready. |
| **Skill catalog source** | `one.ie/agents/skills/*.md` — same MD pattern as agents (`kind: skill`). Workspace forks on signup just like agents. One filesystem, two `kind` values. No second storage layer. |
| **Reports-to cycle check** (server) | In `patchAgentFrontmatter`: BFS `target.reports_to` chain. If source.uid appears → 422 with plain message. ~10 LOC, one helper `wouldCycle(roster, source, newManager)`. |
| **Reports-to filter** (client picker) | `validManagersFor(agent, roster)` = `roster.filter(r => r.tier > agent.tier && !descendantsOf(agent).has(r.uid))`. ~15 LOC pure function. |
| **Auto-default reports-to** for new agents | New specialist's `reports_to` = director of their `group`. If group has no director: chairman. Computed at create-time, written into MD. |
| **Permission matrix** | Three checks total in PATCH/POST/DELETE handlers: `owner` for create/delete + structural changes (reports_to, group); `admin|owner` for edits (skills, tools, tagline); `viewer` for read. Maps to existing `member-role` in `one.tql:270`. |
| **Power-user technical details** | `?dev=1` query param on `/u/[slug]/agents` reveals UID, generation, raw MD link, history panel. No toggle UI to maintain. |
| **History panel** (lightweight) | Drawer tab in `RoleDetailPanel` lists last 20 versions from `api/agents/history.ts` (shipped). Each row: timestamp + author + "Restore" button (calls `rollback.ts`). ~35 LOC. |
| **Suggestions caching** (LLM cost) | Cache per `(uid, version)` in KV for 1 hour. Bust on edit (signal already fires). Most workspaces hit cache 95%+ after first opens. |
| **CLI vs UI concurrency** | Same `If-Match: generation`. CLI publish reads current generation, increments, publishes; UI sees signal, refetches. Last-edit wins; loud 409 keeps both honest. |
| **Mobile beyond drag-drop** | Pickers work on mobile (cmdk handles touch). Suggestions buttons work. Only drag-drop disabled — fallback is the "Move to..." button in the panel. |
| **`edit_agent` tool surface** | Four sub-actions in one tool's `inputSchema` (discriminated union): `patch_frontmatter`, `create_agent`, `delete_agent`, `apply_template`. Bounds the LLM's authority explicitly. No "free MD edit" — body changes use `edit_body` (deferred). |
| **Conversational onboarding** | Single system prompt loads `prompts/onboarding-interviewer.md` (new). LLM asks ≤4 questions then calls `edit_agent` repeatedly to build the org. ~80 lines of prompt, **zero code beyond what phase 3 ships**. |

---

## Deferred (named, not hidden)

Things we know we won't do in this sweep — each has a phase where it lives:

| Deferred | Lands in |
|---|---|
| Body editor (Monaco for system prompt) | Phase 7 |
| L5 pheromone-driven prompt evolution sync | Whenever L5 ships (separate plan) |
| Custom user-defined groups | Phase 7 |
| Mobile drag-drop on signal graph | Phase 7 |
| Avatar/photo upload (replaces Lucide icon) | Phase 8 |
| ONE-master rename/delete migration for forked workspaces | Phase 8 — "Import from master" button covers the additive case in phase 6 |
| Composio's full 500-tool catalog browser | Phase 8 — connected-apps-only covers v1 |
| Multi-tab/multi-user real-time presence in panel | Phase 9 — out of scope |
| Workflow editor (changing signal connections visually) | Separate plan `agent-workflows.md` |

---

## Final LOC accounting

| Bucket | LOC |
|---|---|
| Core wiring (phases 1–6) | ~410 |
| Non-tech UX polish | ~225 |
| Feature-complete gap fixes | ~250 |
| Multi-agent chat collaboration | ~160 |
| ReactFlow living-org + pheromone routing | ~175 |
| **Grand total new code** | **~1,220 LOC** |
| Lines deleted (legacy slug pages, static roster, dead components) | ~600 |
| **Net code added** | **~620 LOC** |

The whole agency-ready, multi-tenant, chat-editable, drag-and-drop, AI-suggested agent fleet ships as **net +285 lines** of code over the existing substrate. Two weeks of focused work for one engineer.

---

## Decisions resolved (not punted)

| Question | Answer | Source |
|---|---|---|
| MD body vs `actor.prompt`? | MD body **is** the prompt, verbatim. Always. | [`agent-spec.md`](agent-spec.md) |
| Concurrency model? | `If-Match: generation`. 409 on conflict. UI prompts merge. | `schema/one.tql:47` + this plan |
| R2 vs git canonicality? | R2 is canonical at runtime. Git is upstream seed via `sync-from-git.ts`. | [`agent-api.md`](agent-api.md) |
| Permissions? | Bearer token, workspace-scoped. `member-role` matrix from `one.tql:270` gates PATCH. | [`agent-api.md`](agent-api.md) |
| Stale chat sessions? | Current turn finishes with old prompt; next turn re-loads. Acceptable. | This plan |
| filename ↔ uid? | kebab filename = `<name>`; uid = `one:<name>`. Zod rejects mismatch. | [`agent-spec.md`](agent-spec.md) |

---

## What this is not

- Not a new schema. Schema is in [`agent-spec.md`](agent-spec.md).
- Not a new publish pipeline. Pipeline is in [`agent-api.md`](agent-api.md).
- Not a new lifecycle. Lifecycle is in [`agent-lifecycle.md`](agent-lifecycle.md).
- Not a workflow engine. Editing signal *connections* is config; running them is the `agents/` worker (existing).

**This plan is ~200 lines of new code (three files + small wiring + one Astro page) over a substrate that's already complete. Net file count *decreases* once phase 5 deletes the four legacy slug routes.**

---

## See also

- [`agent-spec.md`](agent-spec.md) — the frontmatter contract
- [`agent-api.md`](agent-api.md) — the 14 substrate operations
- [`agent-lifecycle.md`](agent-lifecycle.md) — stages and L5 evolution
- [`agent-authoring.md`](agent-authoring.md) — the CLI pull/edit/publish loop
- [`agents-how-they-work.md`](agents-how-they-work.md) — pheromone learning
- [`improve/05-agents.md`](improve/05-agents.md) — honest gap analysis between shipped and claimed
