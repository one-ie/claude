---
title: Agent Integration — /org as live workspace agent UI
slug: agent-integration
type: plan
tier: complex              # 3 cycles, ~13 parallel agents, multi-surface
mode: construction
tags: [agents, org, chat, reactflow, multi-tenant, pheromone, signals]

# ─── PARALLELISM CONTRACT ────────────────────────────────────────────
parallel_budget:
  haiku:   24             # recon (5 per cycle) + verify (5 per cycle)
  sonnet:  13             # W3 edit agents — cycle 1 has 5, cycle 2 has 4, cycle 3 has 4
  opus:    2              # cycle 2 W2 (chat/picker UX) + cycle 3 W2 (pheromone routing)

batches:
  # Each batch closes before the next fires. Within a batch, all listed cycles run in parallel.
  - [C1]                  # batch 1: substrate — migration, roster, seed, consolidate slug
  - [C2]                  # batch 2: interaction — chat edit tool, picker, live updates, gallery, suggestions
  - [C3]                  # batch 3: living org — ReactFlow graph + delegate_to + team-message + pheromone analytics

shared_recon:             # /do reads ONCE at plan start (W0.5)
  - plans/agent-integration.md
  - plans/agent-spec.md
  - plans/agent-api.md
  - plans/agent-lifecycle.md
  - one.ie/web/src/components/org/OrgChartView.tsx
  - one.ie/web/src/components/org/RoleDetailPanel.tsx
  - one.ie/web/src/lib/agent-md.ts
  - schema/one.tql

source_of_truth:
  - plans/agent-integration.md
  - plans/agent-spec.md
  - plans/agent-api.md
  - .claude/rules/api.md
  - .claude/rules/ui.md

existing_primitives:
  # ≥3 entries — what we COMPOSE, never reimplement
  - one.ie/web/src/pages/api/agents/publish.ts: validates + R2 writes + D1 upserts + versions; cycle 1 reuses for seed write path
  - one.ie/web/src/pages/api/agents/[id].ts: GET + PATCH already shipped; cycle 2 extends with If-Match header + DELETE handler
  - one.ie/web/src/pages/api/agents/list.ts: reads R2 ${slug}/agents/*; cycle 1 wraps for the roster endpoint
  - one.ie/web/src/pages/api/agents/history.ts + rollback.ts: cycle 3 history drawer uses both as-is
  - one.ie/web/src/pages/api/signal/[receiver].ts: cycle 2 + 3 emit through this; never write a parallel event bus
  - one.ie/web/src/pages/api/mark/[edge].ts, warn/[edge].ts, fade.ts, follow/[from].ts: cycle 3 edge actions wire to these; never reimplement pheromone math
  - one.ie/web/src/hooks/use-substrate-stream.ts: cycle 2 + 3 SSE subscriber; one consumer, already shipped
  - one.ie/web/src/workers/analytics-relay.ts: cycle 3 listens to signal/mark/warn frames it already broadcasts; coalesce flag already exists
  - one.ie/web/src/lib/agent-md.ts: cycle 1 extends parser to use Zod; never write a second parser
  - one.ie/web/src/components/chat/ChatDock.tsx + ChatWidget.tsx + Chat.tsx: cycle 2 + 3 add tools to existing useChat surface — never new chat component
  - one.ie/web/src/components/ui/Command (cmdk via shadcn): cycle 2 EntityPicker is a thin wrapper, never a bespoke combobox
  - one.ie/web/src/pages/api/composio/{connect,callback,redirect}.ts: cycle 2 tool picker uses connect status; OAuth already shipped
  - schema/one.tql: actor.generation is the optimistic-lock primitive; cycle 2 PATCH uses If-Match — no new lock table

show: true                # render cycle frames in --auto for visibility on the demo moment
escape:
  condition: "any cycle W4 rubric < 0.65 twice OR L4 highway implementation status comes back as non-functional in cycle 1 W1"
  action: "halt; if L4 is non-functional, demote cycle 3 pheromone routing to flat round-robin and continue"
context_triggers:
  - pattern: "delegate_to|team-message|RichMessage"
    inject: "docs/rich-messages.md § PaymentMetadata pattern — reuse the same shape"
  - pattern: "pheromone|highway|path\\.weight"
    inject: "plans/agent-api.md § L4 routing loop"
  - pattern: "Composio.*OAuth|composio.*connection"
    inject: "skills/composio.md if exists, else investigate one.ie/web/src/pages/api/composio/*"
---

# Agent Integration

**Goal:** `/org` and `/u/[slug]/agents` become the canonical agent UI for every workspace. Users add/edit/delete agents via UI or chat; multi-agent collaboration is visible in chat; pheromones bias delegation routing; the ReactFlow graph is alive.

**Exit:** workspace `acme` lands with `business` starter pack (16 agents) at `/u/acme/agents`. Owner edits via chat ("give Account Manager Slack") — change appears in MD + UI within 1s via SSE. Drag agent between teams updates frontmatter. Chat shows team coordination for owners. Org graph shows pheromone-weighted edges that animate on signal traffic.

---

## /do execution model — proven timing from recent learnings

`/do --auto` recently closed **10 cycles in one sweep** (`crm-complete-todo`, 2026-05-16) and **6 cycles in one sweep** (`crm-todo C3-C8`, 2026-05-16). That's the baseline.

### Per-wave clock time (empirical from learnings + rubric history)

| Wave | Model | Parallelism | Typical clock |
|---|---|---|---|
| W1 recon | haiku | 5 parallel readers per cycle | **5–10 min** |
| W2 decide | sonnet (or opus when architectural) | 1 (synthesis) | **5–15 min** |
| W3 edit | sonnet | 4–5 parallel writers per cycle (one per file family) | **15–30 min** |
| W4 verify | haiku + 1 sonnet rubric | 5 parallel checks | **5–10 min** |
| **Per cycle total** | | | **30–60 min** |

### This plan's projected wall-clock

| Cycle | Files touched | Parallel agents in W3 | Projected clock |
|---|---|---|---|
| **C1 — substrate** | 7 (migration data + 4 new lib/api + 1 page consolidation + 1 hook + 1 deletion) | 5 | **~45 min** |
| **C2 — interaction** | 9 (chat tool + picker + 4 fetchers + SSE wiring + gallery + suggestions + plain-labels) | 4 | **~60 min** |
| **C3 — living org** | 8 (SignalGraph + AnimatedEdge + delegate_to + team-message + pheromone helpers + edge actions) | 4 | **~75 min** |
| **Batches are serial** | | | |
| **Grand total wall clock** | | | **~3 hours** |

**With one re-run on a < 0.65 cycle (historical: 1-in-4 cycles rerun)**: **~4 hours**.

**With L4 highway demotion fallback** (escape clause): **~4.5 hours**.

**This is feature complete, multi-tenant, chat-editable, drag-and-drop, multi-agent, pheromone-routed in one afternoon of `/do --auto`.**

### Why this is faster than "3 days"

- 13 sonnets work in parallel across the plan; only batch boundaries are serial
- Shared recon loaded once (W0.5) — no redundant file reads
- Existing primitives mean W3 agents do composition, not greenfield (no Zod schema authored from scratch, no event bus written, no SSE wired)
- Reuse audit kills 200+ LOC of bespoke `<Picker>` / `<Toolbar>` / `<Drawer>` before they're written

---

## Cycle 1 — Substrate (batch 1)

**Goal:** workspace lands with seeded team; `/u/[slug]/agents` renders live; legacy slug routes consolidated.

**Exit scalar:** `curl /api/agents/roster?slug=demo` returns ≥16 agents (business pack); `/u/demo/agents` renders OrgChartView with those agents; the 4 legacy `.astro` files deleted; static `lib/org-roster.ts` deleted.

### W1 — Recon (5 parallel haiku)

| Agent | Reads | Reports |
|---|---|---|
| R1 | `one.ie/agents/*.md` (all 23) | which files need `tone`/`icon`/`tagline`/`tier`/`reports_to`/`starters`/`kpis` backfilled; which have `kind: agent` vs other |
| R2 | `agent-api.md` + `api/agents/{publish,list,[id]}.ts` | confirm publish pipeline shape; identify exact PATCH signature; find If-Match support or absence |
| R3 | `lib/agent-md.ts` + `agent-spec.md` | exact Zod-extendable parser shape; existing field list; what `agentmd: "0.1"` validates |
| R4 | `pages/u/[slug]/agents/{new,[id]/{analytics,funnel,actor/[actorId]}}.astro` | what each renders; which components must move into drawers (AgentForm, LifecycleFunnel) |
| R5 | `home-sections.ts` + workspace-create flow (search for it) | how `persona: agency\|business\|consultant` flows through signup; where to hook seeding |

### W2 — Decide (sonnet)

**Reuse audit (mandatory):**
- `api/agents/publish.ts` covers R2 write + D1 upsert + versioning — seed reuses it
- `api/agents/list.ts` covers R2 read — roster endpoint wraps it with filter+project
- `lib/agent-md.ts` covers parse — extend with Zod, do not parallel-write

**Files to create/modify (5 W3 agents):**

| W3 # | File | Action | LOC | Justification |
|---|---|---|---|---|
| E1 | `one.ie/agents/*.md` × 19 backfills + 5 new (chairman, ceo, cro, cxo, cco) + 3 reclassifications (handle-complaint, tag-suggest, template-starters → kind:skill) | Data edits | ~0 code, ~24 file edits | All required for Zod parse to succeed |
| E2 | `one.ie/web/src/lib/agent-schema.ts` (NEW) + extend `agent-md.ts` to use it | Zod schema with org-placement fields; AgentDoc gains group/tier/reports_to/tone/icon/tagline/starters/kpis | ~80 | No existing schema covers the extended frontmatter |
| E3 | `one.ie/web/src/pages/api/agents/roster.ts` (NEW) | GET `?slug=` filters R2 agents by kind=agent + projects to Role[]; KV-cached 60s | ~50 | Roster shape is a derived view, list endpoint returns raw |
| E4 | `one.ie/web/src/lib/seed-agents.ts` (NEW) + hook into workspace-create + add DELETE to `api/agents/[id].ts` | seedAgents(slug, pack) reads ONE fleet, filters by pack, deep-copies to `R2:${slug}/agents/*` + D1 batch insert; DELETE soft-retires | ~95 | No existing seeder; DELETE handler missing per recon |
| E5 | `one.ie/web/src/pages/u/[slug]/agents/index.astro` (NEW) + delete `new.astro` + delete `[id]/{analytics,funnel,actor/[actorId]}.astro` (4 files) + delete `lib/org-roster.ts` + update `OrgChartView.tsx` (gains `slug?` prop, fetches from `/api/agents/roster?slug=${slug}`) | Consolidate slug routes; static→live | ~70 new, ~600 deleted | All legacy pages collapse into one mount |

**Total cycle 1: ~295 LOC new, ~600 deleted = net -305 LOC.**

### W3 — Edit (5 parallel sonnets, file-disjoint)

E1, E2, E3, E4, E5 run concurrently. No file overlap between agents.

### W4 — Verify

1. `bun run verify` (tsc + vitest) — must pass with delta 0 errors
2. `curl /api/agents/roster?slug=demo | jq '.[].uid' | wc -l` ≥ 16
3. All 28 `agents/*.md` Zod-validate (loop: `cat agents/*.md | parse | report`)
4. `git ls-files pages/u/\\[slug\\]/agents/` returns only `index.astro`
5. Rubric: security ≥ 0.8, stability ≥ 0.85, simplicity ≥ 0.8, speed ≥ 0.7

---

## Cycle 2 — Interaction surface (batch 2)

**Goal:** owner edits agents via UI or chat; changes propagate live; new agents added from gallery; AI suggests improvements.

**Exit scalar:** owner clicks "+ Add ability" on Account Manager → picker shows skills + tools → pick Slack → chip appears → MD updates → `/u/[slug]/agents` reflects within 1s via SSE. Also: owner types in chat "give Account Manager the Slack tool" → same outcome via `edit_agent`. Also: "+ Add team member" → role gallery → pick "Refund Specialist" → name it → appears in org.

### W1 — Recon (4 parallel haiku)

| Agent | Reads | Reports |
|---|---|---|
| R1 | `components/chat/{Chat,ChatDock,ChatWidget}.tsx` + AI SDK v6 tool docs | how tools register on useChat; tool-approval surface |
| R2 | `components/ui/Command` (cmdk) + any existing combobox patterns | EntityPicker base; what's already shadcn |
| R3 | `hooks/use-substrate-stream.ts` + `workers/analytics-relay.ts` | how to filter SSE receivers; coalesce window flag |
| R4 | `components/{cards,settings,agents}/*` — find existing modal/drawer/toast patterns | Sonner present? Drawer.tsx? AgentForm structure |

### W2 — Decide (sonnet, but opus called if EntityPicker design feels architectural)

**Reuse audit:**
- Command/cmdk covers picker UI — EntityPicker is ~50 LOC wrapper, not a new combobox
- Sonner if shipped; else add (~3KB, one Layout.astro mount)
- `useSubstrateStream` already exists — cycle 2 just subscribes to `agent:*:updated`
- Plain-language labels are a 30-LOC `lib/labels.ts` map, not a feature

**Files to create/modify (4 W3 agents):**

| W3 # | File | Action | LOC |
|---|---|---|---|
| F1 | `lib/chat-tools/edit-agent.ts` (NEW) + register in `api/chat.ts` + add `If-Match: generation` to PATCH in `api/agents/[id].ts` + server cycle check + permission matrix | `edit_agent` tool with discriminated-union input (patch_frontmatter / create_agent / delete_agent); owner-only gate | ~110 |
| F2 | `components/org/EntityPicker.tsx` (NEW) + 4 fetcher hooks (`useSkills`, `useTools`, `useAgents`, `useKpis`) + chip wiring in RoleDetailPanel for all 5 sections + plain-label map `lib/labels.ts` | One picker, source-parameterized; uniform `{id, label, badge?, subtitle?}` shape | ~180 |
| F3 | `OrgChartView.tsx` + RoleDetailPanel.tsx — add `useSubstrateStream(['agent:*:updated'], refetch)` + skeleton states + empty-state polling against `/api/workspace/[slug]/seed-status` | Live updates; cold-load cohesion | ~50 |
| F4 | `components/org/RoleGallery.tsx` (NEW modal) reading from `one.ie/agents/*.md` as templates + Sonner toast wiring + `/api/agents/[uid]/suggestions.ts` (NEW) + bottom-of-panel suggestions section | "+ Add team member" gallery; undo toast everywhere; AI suggestions | ~180 |

**Total cycle 2: ~520 LOC new.**

### W3 — Edit (4 parallel sonnets, file-disjoint)

F1 owns chat + api/agents; F2 owns picker + RoleDetailPanel sections; F3 owns OrgChartView + SSE; F4 owns gallery + suggestions + toast. No overlap on RoleDetailPanel because F2 owns the sections; F3 only adds SSE subscription at top.

### W4 — Verify

1. `bun run verify` — clean
2. Playwright: edit a skill on Account Manager via picker → MD file changes → assertion passes within 1500ms
3. Playwright: edit via chat "add Slack tool to Account Manager" → MD changes → /u/demo/agents reflects within 1500ms
4. Plain-language: no raw `composio:` or `one:` strings appear in panel HTML for non-`?dev=1` mode
5. Rubric: security ≥ 0.85 (chat tool is write surface!), stability ≥ 0.85, simplicity ≥ 0.75, speed ≥ 0.7

---

## Cycle 3 — Living org + multi-agent chat (batch 3)

**Goal:** owner sees their team work in real time; pheromones bias delegation; chat shows team coordination expanded view.

**Exit scalar:** `/org?view=signal-graph` (or `/u/demo/agents?view=signal-graph`) renders ReactFlow with pheromone-weighted edges that pulse on live signals. Owner in chat: "draft Q4 campaign" — CMO delegates to copywriter + strategist + SEO in parallel; team-message renders with collapsible children; mark/warn fires on completion; next delegation favors high-weight edges.

### W1 — Recon (5 parallel haiku — pheromone status is high-stakes)

| Agent | Reads | Reports |
|---|---|---|
| R1 | `agent-api.md` + L4 routing section + `api/mark/` `api/warn/` `api/fade.ts` `api/follow/` | exact pheromone semantics; is highway promotion live or partial? **If non-functional → escape clause kicks in** |
| R2 | `workers/analytics-relay.ts` | coalesce-window flag for signal storm; broadcast frame shape |
| R3 | ReactFlow usage in codebase (`grep -r "reactflow"`) + dnd-kit usage | base patterns; custom edge example if exists |
| R4 | `docs/rich-messages.md` + Chat.tsx MessageRenderer | RichMessage schema extension point for `team-message` kind |
| R5 | Composio identity mode docs/examples (workspace-bot vs owner-identity) | which mode for v1; one config flag |

### W2 — Decide (opus — routing semantics are architectural)

**Critical decisions documented here:**

1. **L4 status decides routing**: if R1 reports highways shipped → use `path.weight` directly. If partial → use raw mark counts. If absent → flat round-robin (escape clause).
2. **`delegate_to` auth**: parent agent's identity carries via `X-Parent-Agent` header; logged in `signal.sender` chain. Owner's session passes through cookies.
3. **`team-message` shape**: discriminated union extending RichMessage — `{ kind: 'team-message', from: uid, children: RichMessage[], summarized: boolean, elapsedMs: number }`.
4. **Sideways delegation grants**: `delegation_grants:` field in agent MD frontmatter (array of uids). Zod added in cycle 1's schema.
5. **Pheromone visuals**: CSS-only edge animations (transform + opacity) — no SVG path animation lib. ReactFlow + Tailwind keyframe.

**Files to create/modify (4 W3 agents):**

| W3 # | File | Action | LOC |
|---|---|---|---|
| G1 | `components/org/SignalGraph.tsx` (NEW) + `AnimatedSignalEdge.tsx` (NEW custom edge) + three-layer toggle in `pages/org/index.astro` and `pages/u/[slug]/agents/index.astro` + `lib/dnd-rules.ts` (cycle detection + tier rules) | ReactFlow with hierarchy/declared/learned edges; drag-drop on signal graph view | ~220 |
| G2 | `lib/pick-delegate.ts` (NEW, max-weight + ε-greedy) + `chat-tools/delegate-to.ts` (NEW) + register in `api/chat.ts` + depth/budget tracking in chat context + `lib/can-delegate.ts` (DFS on reports_to + delegation_grants) | Delegation tool + routing + auth gates | ~120 |
| G3 | `components/chat/TeamMessage.tsx` (NEW RichMessage renderer) + extend RichMessage discriminated union + collapse toggle in chat header + child SSE child-streams wiring | team-message rendering with collapse | ~85 |
| G4 | Pheromone analytics in `api/agents/[uid]/suggestions.ts` (extend cycle 2's endpoint) + edge-action handlers in SignalGraph (boost/suppress/pin → POST to shipped `mark`/`warn`/`harden` endpoints) + edge hover tooltip with weight/success-rate/recent-traffic | Pheromone-derived suggestions + edge interactions | ~75 |

**Total cycle 3: ~500 LOC new.**

### W3 — Edit (4 parallel sonnets, file-disjoint)

G1 owns SignalGraph + custom edge + toggle; G2 owns delegate tool + routing helpers + chat registration; G3 owns RichMessage renderer + extension + collapse; G4 owns suggestions extension + edge interactions. Only collision: G2 and G3 both touch `api/chat.ts` — split: G2 registers tool, G3 registers renderer; lock file separately.

### W4 — Verify

1. `bun run verify` — clean
2. Playwright: open `/u/demo/agents?view=signal-graph` → at least 5 edges visible with weight > 1 → fire 3 signals via `/api/signal/...` → edges pulse → screenshot diff < 5% threshold
3. Playwright: chat "draft Q4 campaign" → team-message renders with ≥3 child agents → collapse toggle works → mark fires for each closed child
4. Curl `/api/agents/[uid]/suggestions?slug=demo` → returns 1-3 actionable suggestions referencing pheromone state
5. Drag CMO node onto CFO node → 422 with cycle error message (CFO doesn't exist but pretend hierarchy) ; drag valid → PATCH 200 → graph updates
6. Rubric: security ≥ 0.85, stability ≥ 0.80, simplicity ≥ 0.75, speed ≥ 0.70 (signal pulses must not jank UI > 16ms frame)

---

## Plan close (after all 3 cycles green)

`/close --todo agent-integration`

Emits:
- pheromone `mode:complex lifecycle:construction` tag on the plan
- learnings entry: `2026-05-21 · agent-integration · gate · ...`
- removes obsolete `lib/org-roster.ts` references from any docs (`grep -rn org-roster` must return 0)
- updates `plans/agent-integration.md` "Phases" table with actual cycle clocks

---

## Realistic wall-clock projection (final)

| Phase | Clock |
|---|---|
| W0 plan-start + shared recon | 5 min |
| Cycle 1 (W1+W2+W3+W4) | ~45 min |
| Inter-batch gate | 2 min |
| Cycle 2 | ~60 min |
| Inter-batch gate | 2 min |
| Cycle 3 | ~75 min |
| Close + propagate | 5 min |
| **Total ideal path** | **~3h 14min** |
| With one cycle re-run (1-in-4 historical) | **~4h** |
| With L4 demotion fallback | **~4.5h** |

**Realistic target: feature-complete, multi-tenant, chat-editable, pheromone-routed agent fleet shipping today in one /do --auto session of 3-4.5 hours.**

---

## What ships when

| Feature | Cycle |
|---|---|
| Multi-tenant workspace fleet + starter packs | C1 |
| Live `/u/[slug]/agents` view from MD | C1 |
| Delete legacy slug routes | C1 |
| `edit_agent` chat tool (frontmatter only) | C2 |
| EntityPicker for skills/tools/agents/groups | C2 |
| SSE live updates | C2 |
| Role gallery for new agents | C2 |
| Plain-language labels + undo toast | C2 |
| AI suggestions per panel | C2 |
| ReactFlow signal graph (3 edge types) | C3 |
| Pheromone-weighted edge rendering | C3 |
| `delegate_to` + team-message multi-agent chat | C3 |
| Drag-drop reorg with cycle detection | C3 |
| Edge actions (boost/suppress/pin) | C3 |
| Pheromone-derived suggestions | C3 |

## Deferred to v1.5 (separate cycle 4 in a follow-up todo)

- Body editor (Monaco) — `edit_body` chat tool covers chat path
- Conversational onboarding (sketched prompt; ship after telemetry from C2's gallery)
- Composio full-catalog browser
- Power-user `?dev=1` mode + history drawer
- Softmax weighted routing (max-weight + ε-greedy is fine until ~50 samples per edge accumulate)
