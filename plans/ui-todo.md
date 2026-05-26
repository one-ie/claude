---
title: UI — 7 surfaces, 11 moves, 4 primitives, parallel build + gap closure
type: roadmap
version: 1.1.0
priority: W1+W2+W4 parallel · W3 after W2 · W5+W6 next · W8+W9 close gaps
total_tasks: 73
completed: 49
open: 24  # W8 = 19, W9 = 5
status: OPEN
audited: 2026-05-08
mode: mixed
lifecycle: construction
spec: web/ui.md
---

# TODO: UI — `web/ui.md`

## Status snapshot (audited 2026-05-08)

**Legend:** ✅ done · 🟡 partial (verify) · ⬜ todo · ☐ task open · ☑ task done

| Wave | Status | Notes |
|------|--------|-------|
| Cycle 0 (Q1-Q5) | ✅ done | All 5 recon notes landed; conditional follow-throughs Q4F/Q5F absorbed into shipped routes |
| W1 — Primitives | ✅ done | Drawer, EmptyCard, all 13 cards, ChatDock, viewer.ts, surface-context.ts, PasskeyKeepThis all shipped |
| W2 — Schema | ✅ done | 15 migrations applied (0001-0015); db wrappers `lib/db/{agents,themes,tools}.ts` shipped |
| W3 — APIs | ✅ done | 31 API routes shipped incl agents/{deploy,generations,revenue}, themes/*, payments/{wallet,txs,accept-links}, notifications, recover, eval |
| W4 — Routing | ✅ done | middleware.ts + per-host context; domain verify endpoint shipped |
| W5 — Surfaces | ✅ done | 7 root pages shipped: chat, agents, skills, tools, payments, design, settings; AgentDrawer + InboxBell shipped |
| W6 — Chat protocol | 🟡 partial | chat.ts + starters.ts + MessageRenderer shipped; M5 chat-edit-frontmatter loop coverage uncertain — verify W6E5 |
| W7 — Docs | 🟡 partial | dictionary/lifecycle/routing referenced but unaudited; web/components/CLAUDE.md exists |
| **W8 — Backend gap surfaces** | **⬜ todo** | All 12 W8.edit tasks pending — `/themes`, `/notifications`, `/wallet`, `/recover` pages not present; ViewerSwitcher / AgentDetailTabs / BotsTab / SkillImport components not present |
| **W9 — Reverse-gap endpoints** | **⬜ todo** | `?action=delete`, `?action=redeem-invite`, recovery-codes wiring all open |

**Read order:** if you're picking up work today, jump to W8 + W9. The earlier
waves are reference for what's already shipped.

---

> **Time units:** tasks → waves → cycles. No calendar time.
>
> **Goal:** Ship every surface in [`ui.md`](ui.md) (33 pages, 9 flows).
> Spec is [`web/ui.md`](ui.md) — single source of truth.
>
> **Spawn shape:** 6 waves. Each task names a tier (`haiku`/`sonnet`/`opus`)
> and a fan-out group. `/do` reads the tier and spawns the matching subagent
> in parallel within each group.
>
> **Source of truth:** [DSL.md](DSL.md), [dictionary.md](dictionary.md),
> [rubrics.md](rubrics.md), [`.claude/rules/ui.md`](../.claude/rules/ui.md),
> [`.claude/rules/design.md`](../.claude/rules/design.md), [`.claude/rules/astro.md`](../.claude/rules/astro.md).

---

## Tier map (which model gets which kind of task)

```
haiku   recon, audits, file reads, schema introspection,
        small scaffolds, migration files, type wrappers
        — cheap, fast, parallelisable to N

sonnet  edits, component implementation, API route handlers,
        astro page shells, test wiring, click-test scripts
        — the default workhorse

opus    architectural decisions, protocol design, schema choices,
        adaptive starter algorithm, viewer-mask derivation,
        cross-wave reconciliation
        — load-bearing thinking
```

Within a wave, **same-tier tasks fan out in parallel** (one Agent call per task,
all sent in one message). Cross-tier order is recon → decide → edit → verify
inside each cycle, just like `/do`.

---

## Routing

```
   signal DOWN                                      result UP
   ──────────                                       ─────────
   /do ui-todo.md
       │
       ▼
   for each W in [W1, W2, W4]  (parallel start)
       │
       ▼ haiku recon ── parallel ──→ opus decide ── parallel ──→ sonnet edit
                                                                       │
   W3 unblocks when W2 lands ──┐                                       │
   W5/W6 unblock when W1+W3   ┘                                       │
                                                                       │
                                                                       ▼
                                                               sonnet verify
                                                                       │
                                                                       ▼
                                                          mark(plan→ui-todo, depth)
```

**Context accumulates down. Quality marks flow up. Width compounds when every
parallel branch deposits a mark.**

---

## Testing — The Deterministic Sandwich

| PRE (W0)                                              | POST (W4)                                                |
|-------------------------------------------------------|----------------------------------------------------------|
| `bun run verify` baseline green                       | `bun run verify` green; no regressions                   |
| Lighthouse 100% on `/chat` (project memory)           | Lighthouse 100% on `/chat` preserved                     |
| Count routes loading in `web/src/pages`               | All 7 surface routes load <300ms TTFB                    |
| Count drawer/card component files (=0)                | 13 cards + 1 drawer + EmptyCard render in `/design`      |
| `emitClick` call count in chat-v3 (existing)          | Every action button on every new card calls `emitClick`  |
| D1 migrations applied count                           | New migration applies clean to fresh DB                  |
| `STARTER_PROMPTS` hardcoded count                     | Replaced by `computeStarters(ctx)` lookup                |

**Deterministic numbers every cycle must report:**
- Components shipped: `N/13` cards + drawer + EmptyCard
- Routes shipped: `N/7` surfaces
- API routes shipped: `N/~20`
- D1 tables added: `N/5`
- Lighthouse on `/chat`: `100`
- Click-test: worked example (`ui.md` §Worked example) passes end-to-end
- `emitClick` coverage: `actions_emitting / actions_rendered` per surface

---

## Source of Truth

**[ui.md](ui.md)** — surfaces, moves, primitives, friction map.
**[web/ui.md](ui.md) §9** — backend coverage table (gap audit, reverse gaps).
**[`.claude/rules/ui.md`](../.claude/rules/ui.md)** — every onClick → `emitClick('ui:<surface>:<action>')`.
**[`.claude/rules/design.md`](../.claude/rules/design.md)** — 6 tokens, 3 depths; build kills wrong colors.
**[`.claude/rules/astro.md`](../.claude/rules/astro.md)** — islands, lazy imports, dark contrast.

| Item                  | Canonical                                                | Exception |
|-----------------------|----------------------------------------------------------|-----------|
| Click receiver        | `ui:<surface>:<action>`                                  | —         |
| Card emit             | `emitClick('ui:card:<type>:<action>')`                   | —         |
| Drawer route          | `?drawer=<id>` query param, never new path               | —         |
| Frontmatter edits     | chat-driven, M5; never settings forms per agent          | —         |
| Detail views          | drawer over grid, M3; never new route                    | —         |
| Marketplace           | `available` zone of surface, M6; never `/marketplace`    | —         |

---

## Wave dependency graph

```
W1 primitives (frontend)  ─┬─────────────────────────► W5 surfaces
                           │                                ▲
W2 schema (D1)  ──► W3 APIs (lenses) ───────────────────────┤
                                                            │
W4 routing (M10) ───────────────────────────────────────────┤
                                                            │
W1 + W3 ──────────────────────► W6 chat protocol (M11) ─────┘
```

**Parallelisable starts:** W1, W2, W4. **W3** unblocks when W2 lands.
**W5, W6** are the assembly waves.

---

## Cycle 0 — Resolve open questions (haiku, parallel × 5)  ✅ DONE

5 reverse-gap file reads (now folded into web/ui.md §9 — kept here for historical W0 trace). Knock them out before W3.

| id  | model   | task                                                                                       | exit                                                  |
|-----|---------|--------------------------------------------------------------------------------------------|-------------------------------------------------------|
| Q1  | haiku   | Find skill registry storage (KV / D1 / TypeDB) — read `web/src/pages/api/skill/import.ts`  | One-line note appended to web/ui.md §9               |
| Q2  | haiku   | Locate conversation storage schema — find D1 messages table or substrate path              | One-line note appended to web/ui.md §9               |
| Q3  | haiku   | Locate x402 receive event source for `/api/agents/[id]/revenue`                            | One-line note appended to web/ui.md §9               |
| Q4  | haiku   | Confirm Composio integration scope (none today; native Slack/Stripe/GitHub start?)         | One-line note appended to web/ui.md §9               |
| Q5  | haiku   | Verify L5 evolution events emitted by runtime (`src/engine/loop.ts`)                       | One-line note appended to web/ui.md §9               |

### Conditional follow-through (spawned only if the answer requires it)

| id   | model   | trigger                          | task                                                                            | exit                                |
|------|---------|----------------------------------|---------------------------------------------------------------------------------|-------------------------------------|
| Q4F  | sonnet  | Q4 = "native start"              | Stub `tool_connections` provider adapter for Slack/Stripe/GitHub only           | W3E3 unblocks                       |
| Q4F2 | opus    | Q4 = "Composio in scope"         | Decide Composio SDK integration shape; freeze adapter contract                  | W3E3 unblocks                       |
| Q5F  | sonnet  | Q5 = "events not emitted"        | Add L5 evolution event hook in `src/engine/loop.ts` per dictionary.md           | W6 generations tab unblocks         |

**Exit:** all 5 notes land. Spawn all 5 in one message. Conditional tasks queued
based on Q answers and unblocked at the next phase.

---

## W1 — Primitives (frontend foundation)  ✅ DONE

**Mode:** full. Wide variance per card. Many parallel tasks.

### W1.recon (haiku, parallel × 3)

| id    | model | task                                                                  | exit                         |
|-------|-------|-----------------------------------------------------------------------|------------------------------|
| W1R1  | haiku | Audit existing UI primitives in `web/src/components/ui/`              | List what exists vs needed   |
| W1R2  | haiku | Audit `ChatHost.tsx`, `MessageRenderer.tsx`, AI SDK v6 stream surface | Report current frame shape   |
| W1R3  | haiku | Read `.claude/rules/ui.md` + `design.md` + `astro.md`; report invariants for cards/drawer | Constraint list back to W1.decide |

### W1.decide (opus, sequential after W1.recon)

| id    | model | task                                                                                | exit                                |
|-------|-------|-------------------------------------------------------------------------------------|-------------------------------------|
| W1D1  | opus  | Decide Drawer API: props, deep-link via `?drawer=`, focus trap, ESC, keyboard tabs  | Drawer.tsx prop spec frozen         |
| W1D2  | opus  | Decide 13-card prop schema (one shape: `{ data, onAction, surface }` discriminated) | One union type emitted to `lib/cards.ts` |
| W1D3  | opus  | Decide viewer derivation rules (`viewer.ts`): no passkey → end_user; owner → developer; staff → creator | Pure function, no config |
| W1D4  | opus  | Decide surface-context payload shape `{url, selection, brand, viewer}` and signal emission contract | Hook spec for ChatDock |
| W1D5  | opus  | **Doc plan** per `.claude/rules/documentation.md` — list every doc touched per wave (`dictionary.md`: 13 card names, `Drawer`, `ChatDock`, `ChatFrame`, `computeStarters`, `trailing_chips`, viewer mask names; `lifecycle.md`: agent state machine `draft→live→paused→evolving`; `routing.md`: M10 host→context; new `web/src/components/CLAUDE.md` for card vocabulary) | Doc-edit table emitted; consumed by W2/W3/W5/W6 edit tasks |

### W1.edit (sonnet, parallel × 8)

| id    | model  | task                                                                       | exit                                              |
|-------|--------|----------------------------------------------------------------------------|---------------------------------------------------|
| W1E1  | sonnet | `web/src/components/ui/Drawer.tsx` per W1D1                                | Compiles; `?drawer=test` opens it                 |
| W1E2  | sonnet | `web/src/components/ui/EmptyCard.tsx` (M7 — chat-input-shaped empty)       | Renders with chat input slot                      |
| W1E3  | sonnet | `web/src/components/cards/AgentPreviewCard` + `DeployStatusCard` + `ResultCard` | Render in `/design` showcase strip            |
| W1E4  | sonnet | `web/src/components/cards/ChoiceChips` + `VerifyCard` + `PriceCard`        | Render in `/design` showcase strip                |
| W1E5  | sonnet | `web/src/components/cards/BrandPalette` + `SkillToggleRow` + `MarketplaceMini` | Render in `/design` showcase strip            |
| W1E6  | sonnet | `web/src/components/cards/TraceMini` + `CompareCard` + `OnboardingChecklist` + `EmptyStateCard` | Render in `/design` showcase strip |
| W1E7  | sonnet | `web/src/lib/viewer.ts` + `web/src/lib/surface-context.ts`                 | Unit tests pass for derivation table              |
| W1E8  | sonnet | `web/src/components/chat/ChatDock.tsx` (cmd-K, slide-up, surface ctx signal) | Toggles open on every surface; emits `ui:dock:*` |
| W1E9  | sonnet | `web/src/components/auth/PasskeyKeepThis.tsx` — M1 "Touch ID to keep this" card; fires when ephemeral wallet has equity (an agent or balance > 0); calls existing `/api/provision` | Renders in `/design` showcase; click triggers passkey ceremony |

### W1.verify (sonnet)

| id    | model  | task                                                                              | exit                                            |
|-------|--------|-----------------------------------------------------------------------------------|-------------------------------------------------|
| W1V1  | sonnet | Run `bun run verify`; render `/design` showcase; click-test cmd-K on /chat        | All compile; cmd-K toggles; Lighthouse `/chat`=100 |

**Exit gate:** 13 cards + Drawer + EmptyCard + ChatDock compile and render. Every card action calls `emitClick`. Lighthouse `/chat`=100 preserved.

---

## W2 — Schema (D1 migration)  ✅ DONE

**Mode:** lean. 5 tables, exit = migration applies + round-trip works.

### W2.edit (parallel × 2)

| id    | model  | task                                                                              | exit                                              |
|-------|--------|-----------------------------------------------------------------------------------|---------------------------------------------------|
| W2E1  | haiku  | Write `web/migrations/00NN_agents_skills_tools_themes.sql` (5 tables — agents/themes/tools/agent_skills/agent_generations) | `wrangler d1 migrations apply` succeeds |
| W2E2  | sonnet | `web/src/lib/db/{agents,themes,tools}.ts` — typed wrappers (`get`, `list`, `create`, `patchFrontmatter`) | Round-trip test passes                |

### W2.verify

| id    | model  | task                                                                              | exit                                            |
|-------|--------|-----------------------------------------------------------------------------------|-------------------------------------------------|
| W2V1  | sonnet | Round-trip: `createAgent` → `getAgent` → `patchAgentFrontmatter` → `getAgent`     | Returned frontmatter matches patch              |

**Exit gate:** migration applies clean. Round-trip works for agents + themes.

---

## W4 — Workspace routing (M10)  ✅ DONE

**Mode:** lean. Starts in parallel with W1/W2.

### W4.edit (sonnet)

| id    | model  | task                                                                                      | exit                                                  |
|-------|--------|-------------------------------------------------------------------------------------------|-------------------------------------------------------|
| W4E1  | sonnet | `web/src/middleware.ts` — host header → `(workspace, agent, viewer, brand)` on `Astro.locals` | `curl -H "Host: tony.one.ie" /refunds` returns chat HTML |
| W4E2  | sonnet | `chat.astro` consumes `Astro.locals.context`; theme tokens reflect workspace               | `<style>` block changes per host                      |
| W4E3  | sonnet | `web/src/pages/api/domains/[domain]/verify.ts` — CNAME + cert handshake                    | Verify endpoint returns ok for known CNAME            |

### W4.verify

| id    | model  | task                                                                                  | exit                                          |
|-------|--------|---------------------------------------------------------------------------------------|-----------------------------------------------|
| W4V1  | sonnet | curl-test 3 hosts: `one.ie`, `tony.one.ie/refunds`, custom CNAME → context correct    | Each route resolves to the right context      |

**Exit gate:** middleware sets context for all 3 host shapes. Theme follows workspace.

---

## W3 — API routes (the lenses)  ✅ DONE

**Unblocks when W2 lands.** Mode: mixed. Many thin routes; sequence with care.

### W3.recon (haiku, parallel × 2)

| id    | model | task                                                                            | exit                                       |
|-------|-------|---------------------------------------------------------------------------------|--------------------------------------------|
| W3R1  | haiku | Audit `/api/skill/import`, `/api/pay/*`, `/api/provision` — what shape do they return | Reuse table for W3 routes              |
| W3R2  | haiku | Read MCP substrate tools (`mcp/src/tools/substrate.ts`) — what's reusable from `web/` | Reuse table for trace/revenue tabs    |

### W3.edit (sonnet, parallel × 6, one group per surface)

| id    | model  | task                                                                                                              | exit                                            |
|-------|--------|-------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| W3E1  | sonnet | `web/src/pages/api/agents/{index,[id],[id]/deploy,[id]/trace,[id]/chats,[id]/revenue,[id]/generations}.ts`        | Route shapes match drawer prop types            |
| W3E2  | sonnet | `web/src/pages/api/skills/{index,[name],[name]/enable}.ts`                                                        | List + detail + enable flow works               |
| W3E3  | sonnet | `web/src/pages/api/tools/{index,[provider]/connect,[provider]/disconnect,[provider]/scopes}.ts`                   | Connect → list shows connected                  |
| W3E4  | sonnet | `web/src/pages/api/themes/{index,[id],[id]/fork,[id]/share}.ts`                                                   | Fork creates new row with `fork_of`             |
| W3E5  | sonnet | `web/src/pages/api/payments/{wallet,txs,accept-links/[slug]}.ts`                                                  | Wallet + txs + accept-link round-trip           |
| W3E6  | sonnet | `web/src/pages/api/notifications.ts` — substrate `mark`/`warn` filtered by salience                               | Returns top-N high-salience events              |
| W3E7  | sonnet | **Deploy gate + state machine** — `[id]/deploy.ts` runs 3-prompt eval *before* state flip; auto-transitions `draft→live`, `live→paused` (>10% error/100 chats), `live→evolving` (L5 fires); transitions emit substrate `mark`/`warn`; `chats` table column for error rollup | Eval failure blocks deploy with failing prompt as chat reply; transitions visible in agent drawer |

### W3.verify

| id    | model  | task                                                                                       | exit                                           |
|-------|--------|--------------------------------------------------------------------------------------------|------------------------------------------------|
| W3V1  | sonnet | Smoke-test: list → detail → patch → list reflects update for agents + themes               | All assertions pass                            |

**Exit gate:** each route returns a shape matching the corresponding card/drawer's TS prop type.

---

## W5 — Surface assembly  ✅ DONE (verify W5V8 emitClick coverage on shipped surfaces)

**Unblocks when W1 + W3 land.** Mode: full. 7 routes, each its own composition.

### W5.recon (haiku, parallel × 2)

| id    | model | task                                                                            | exit                                       |
|-------|-------|---------------------------------------------------------------------------------|--------------------------------------------|
| W5R1  | haiku | Audit `chat.astro`, `agents.astro`, `design.astro` — what to refresh vs replace | Refresh-vs-rebuild table                   |
| W5R2  | haiku | Read `Sidebar` audit — current state, viewer-mask hooks                         | Sidebar prop spec                          |

### W5.edit (sonnet, parallel × 7 per route + 1 sidebar + 1 mobile)

| id    | model  | task                                                                                              | exit                                            |
|-------|--------|---------------------------------------------------------------------------------------------------|-------------------------------------------------|
| W5E1  | sonnet | Refresh `chat.astro` — Sidebar + ChatDock + EmptyCard + viewer mask                               | Loads <300ms; Lighthouse=100                    |
| W5E2  | sonnet | Refresh `agents.astro` — Grid + EmptyCard + drawer trigger via `?drawer=<agent-id>`               | Loads <300ms; cards render                      |
| W5E2b | sonnet | `web/src/components/agents/AgentDrawer.tsx` — 6 tabs (definition · chats · trace · revenue · generations · connect); fetches W3E1 endpoints per tab | Drawer opens; all 6 tabs render real data       |
| W5E3  | sonnet | New `skills.astro` — agent picker + two-zone grid + skill drawer (4 tabs)                         | Toggle skill on agent works                     |
| W5E4  | sonnet | New `tools.astro` — connected/available zones + tool drawer (4 tabs)                              | OAuth flow stub round-trips                     |
| W5E5  | sonnet | New `payments.astro` — wallet card + revenue card + tx grid + 3 drawer types                      | Tx drawer shows substrate trace                 |
| W5E6  | sonnet | Refresh `design.astro` — live preview + theme drawer + community grid                             | "make it warm" via dock applies                 |
| W5E7  | sonnet | New `settings.astro` — left rail + 12 categories (forms + collection drawers)                     | Profile + Keys & devices reachable              |
| W5E8  | sonnet | `web/src/components/nav/Sidebar.tsx` — 220→56→hidden, viewer-aware                                | Width responds to viewport; hides on sm         |
| W5E9  | sonnet | `web/src/components/MobileHandoff.tsx` — sm + developer/creator non-`/chat` route                 | Toast renders with handoff URL                  |
| W5E10 | sonnet | **Dock badge + cmd-K search** — subscribe ChatDock to `/api/notifications`; render count badge; opening dock emits "⌬ N things happened" system reply with deep-links; cmd-K with text query routes through assistant ("opening refunds-bot drawer", highlight, summarize) | Badge updates on substrate mark/warn; cmd-K query opens correct drawer |

### W5.verify (sonnet, parallel × 7, one per surface)

| id     | model  | task                                                                                  | exit                                           |
|--------|--------|---------------------------------------------------------------------------------------|------------------------------------------------|
| W5V1-7 | sonnet | Click-test each surface: open drawer → switch tabs → close; primary action ≤2 clicks | Friction-map row passes per surface; LH≥95     |
| W5V8   | sonnet | **emitClick coverage gate** — grep every new surface: count action buttons vs `emitClick` calls; fail if any action button doesn't emit `ui:<surface>:<action>` first | `actions_emitting === actions_rendered` per surface |
| W5V9   | sonnet | **Cross-surface context verify (M3 + M4 killer demo)** — script: visit `/agents`, click refunds-bot card → drawer opens → open ChatDock → type "rename this to refund-buddy" → assert chat tool call patches `agents.refunds-bot.frontmatter.name` → drawer reflects new name | End-to-end pass; surface-context payload visible in network tab |

**Exit gate:** 7 surfaces ship. Each <300ms TTFB. Lighthouse ≥95 each. Friction map passes end-to-end. Every action button emits a signal. The "rename this" demo works from any surface.

---

## W6 — Chat protocol upgrade (M11)  🟡 PARTIAL (verify M5 frontmatter-edit loop coverage)

**Unblocks when W1 + W3 land.** Mode: full. Load-bearing.

### W6.recon (haiku)

| id    | model | task                                                                          | exit                                       |
|-------|-------|-------------------------------------------------------------------------------|--------------------------------------------|
| W6R1  | haiku | Read `web/src/pages/api/chat.ts`, `STARTER_PROMPTS`, AI SDK v6 stream surface | Frame-injection points listed              |

### W6.decide (opus)

| id    | model | task                                                                                                                                  | exit                                            |
|-------|-------|---------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| W6D1  | opus  | Card-frame stream protocol (NDJSON over SSE) — `{kind:'text'|'card'|'chips'}` schema, server validation, fallback rules               | Schema frozen in `lib/chat-frames.ts`           |
| W6D2  | opus  | Adaptive starter algorithm — lookup table → `world.select('ui:chat:starter:*')` filtered by `(surface, viewer, lifecycle)` once mark count ≥ N | Algorithm spec frozen in `lib/starters.ts` |
| W6D3  | opus  | Trailing-chip system rule — assistant declares `trailing_chips[]` per reply; schema-validated; fallback to surface-context defaults  | Prompt rule frozen                              |

### W6.edit (sonnet, parallel × 4)

| id    | model  | task                                                                                          | exit                                            |
|-------|--------|-----------------------------------------------------------------------------------------------|-------------------------------------------------|
| W6E1  | sonnet | Extend `web/src/pages/api/chat.ts` to emit typed frames per W6D1                              | Smoke: frames stream in order                   |
| W6E2  | sonnet | `web/src/lib/starters.ts` — `computeStarters(ctx)` per W6D2; replace `STARTER_PROMPTS`        | Onset chips change per `(surface, viewer)`      |
| W6E3  | sonnet | `web/src/components/chat/MessageRenderer.tsx` — switch on `frame.kind`; render W1 cards       | Card actions emit `ui:card:<type>:<action>`     |
| W6E4  | sonnet | Tool result auto-render rules (e.g. `agents.create` → `AgentPreviewCard`)                     | Worked example flow lands all 4 cards           |
| W6E5  | sonnet | **M5 chat-edit-frontmatter loop** — register `agents.patchFrontmatter`, `themes.patch`, `accept-link.patch`, `pay.create` as assistant tools; tool call → W3 PATCH endpoint → optimistic UI update → server reconciles → drawer/card rerender; "raise price to $1" / "make it warm" / "make it $10 monthly" all complete in chat | Three flows pass: agent rename, theme retint, accept-link price change |

### W6.verify

| id    | model  | task                                                                                                              | exit                                                |
|-------|--------|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------|
| W6V1  | sonnet | Streamed reply for "build me a refund bot" produces text → AgentPreviewCard → trailing chips                      | All 3 frames observed in NDJSON stream              |
| W6V2  | sonnet | All 13 card types reachable via at least one prompt path                                                          | Coverage script passes                              |
| W6V3  | sonnet | grep-gate: `emitClick` calls per surface ≥ rendered actions                                                       | gate green                                          |
| W6V4  | sonnet | Worked example end-to-end: 1 starter + 3 card actions = agent built/deployed/saved/priced                         | Click-test passes                                   |
| W6V5  | sonnet | Trailing chips on 100% of assistant replies in dev                                                                | No missing `trailing_chips` declarations            |
| W6V6  | sonnet | After 100 simulated chats per surface, `world.select('ui:chat:starter:*')` returns non-trivial top-3              | Substrate learning loop closed                      |

**Exit gate:** all 6 verify subtasks pass. Compounding payoff demonstrated — chips users pick rise; dead-end chips drop out.

---

## W7 — Docs reconciliation  🟡 PARTIAL (web/components/CLAUDE.md exists; dictionary/lifecycle/routing audit pending)

**Per `.claude/rules/documentation.md`:** W2 plan (W1D5) → W3 alongside-edit
threaded through every sonnet edit task → W7 verify consistency.

**Mode:** lean. Exit = grep finds zero stale terms; cross-references resolve.

### W7.edit (haiku, parallel × 4 — one per doc family)

| id    | model  | task                                                                                                                              | exit                                                |
|-------|--------|-----------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------|
| W7E1  | haiku  | Update `one/dictionary.md` — add 13 card names, `Drawer`, `ChatDock`, `ChatFrame`, `computeStarters`, `trailing_chips`, `viewer={creator,developer,end_user}` | Terms canonicalised; dead-name list updated         |
| W7E2  | haiku  | Update `one/lifecycle.md` — agent state machine `draft→live→paused→evolving`; viewer-mask derivation                              | State diagram added                                 |
| W7E3  | haiku  | Update `one/routing.md` — M10 host→`(workspace, agent, viewer, brand)` middleware path                                            | M10 entry lands                                     |
| W7E4  | haiku  | Create `web/src/components/CLAUDE.md` — directory contract for cards, drawer, EmptyCard, ChatDock                                 | File exists; auto-loads when working in `web/src/components/` |

### W7.verify (sonnet)

| id    | model  | task                                                                                                                            | exit                                          |
|-------|--------|---------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------|
| W7V1  | sonnet | Doc consistency — `grep -r` for dead names; `markdown-link-check` on all touched docs; verify TS interfaces in examples match `web/src/lib/cards.ts` and `web/src/types/*.ts` | Zero dead names; zero broken links; examples compile |
| W7V2  | sonnet | Append learnings entry to `one/learnings.md` per `.claude/rules/documentation.md` §Loop Close                                   | One-line entry per cycle closed               |

**Exit gate:** docs match code. No drift. Code rubric (security/stability/simplicity/speed) applies to docs — no sensitive data, no broken links, no bloat.

---

## W8 — Surfaces from backend gap audit  ⬜ TODO (19 tasks open)

**Source:** `web/ui.md §9 Backend coverage`. The audit
found **15 shipped backend endpoints with no UI consumer**. W1-W7 build the
core 7 surfaces; W8 closes the gap by shipping 4 new pages, 5 component
groups, and the agent-detail tab system. Mode: mixed. Unblocks once W1 lands
(needs Drawer, Card, ChatDock primitives).

### W8.recon (haiku, parallel × 2)

| done | id    | model | task                                                                                            | exit                                              |
|------|-------|-------|-------------------------------------------------------------------------------------------------|---------------------------------------------------|
| ☐    | W8R1  | haiku | Confirm each gap-audit endpoint exists + shape: `/api/themes/*`, `/api/notifications`, `/api/payments/{wallet,txs}`, `/api/recover`, `/api/skill/import`, `/api/eval`, `/api/agents/[id]/{generations,deploy,revenue}` | One-line shape table per endpoint; missing ones flagged into W9 |
| ☐    | W8R2  | haiku | Verify `agents.state` enum from migration 0007 includes `paused\|evolving`; verify `x402_payments` columns include `creator_usd\|platform_usd\|protocol_usd` | Schema confirmation table; mismatches → W9 |

### W8.decide (opus × 1, sequential)

| done | id    | model | task                                                                                                                            | exit                                            |
|------|-------|-------|---------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| ☐    | W8D1  | opus  | **ViewerSwitcher safety** — design the impersonation cookie shape, middleware gate (must check `staffRole === true` BEFORE honouring cookie), TTL (15min), audit-log requirement, banner contract per `web/ui.md §2a` | Frozen contract: cookie name, middleware diff, banner component spec; ready for W8E1 |

### W8.edit (sonnet, parallel × 12)

| done | id    | model  | task                                                                                                                                 | exit                                                  |
|------|-------|--------|--------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| ☐    | W8E1  | sonnet | `web/src/components/owner/ViewerSwitcher.tsx` + `ImpersonationBanner.tsx` + middleware diff (per W8D1)                               | Owner can pick agency/client/end_user → page reloads with viewer override; banner pinned; clears cleanly |
| ☐    | W8E2  | sonnet | `web/src/pages/recover.astro` + flow components — magic-link request + `?token` re-enrol; consumes `/api/recover` (GET ?token, POST ?slug ?email) | Lockout flow: email arrives → click link → Touch ID → row appended to `owners_keys` |
| ☐    | W8E3  | sonnet | `web/src/pages/themes/index.astro` + `[id].astro` — community gallery, fork & apply; `web/src/components/themes/{ThemeGallery,ThemeCard,ThemeDetail,ThemeForkButton,ThemeShareToggle}.tsx` | `/themes` lists community + mine; fork → row created with `fork_of`; "Apply" swaps tokens live |
| ☐    | W8E4  | sonnet | `web/src/pages/notifications.astro` + `web/src/components/notifications/{NotificationsPage,NotificationItem}.tsx`; wire existing `InboxBell` to same backend | Feed renders with ●/○ states; mark-read flips state; click row navigates to source |
| ☐    | W8E5  | sonnet | `web/src/pages/wallet.astro` + `web/src/components/wallet/{BalanceCard,TxList,PaymentMethods,TopUpModal}.tsx`; `?tab=transactions` deep-links ledger | Multi-asset balance renders; tx pagination works; row → drawer with full detail; CSV export downloads |
| ☐    | W8E6  | sonnet | `AgentDetailTabs.tsx` + 4 panels: `AgentVersions`, `AgentDeployPanel`, `AgentRevenue`, `AgentEvalPanel` (in `web/src/components/agents/`); wired to `/api/agents/[id]/{generations,deploy,revenue}` + `/api/eval` | All 4 tabs render real data on `/u/[slug]/agents/[name]`; rollback emits `mark`; eval re-run streams |
| ☐    | W8E7  | sonnet | Extend `web/src/pages/agents.astro` and workspace agents page with `[Live] [Paused] [Evolving]` tab filters; state badges on each agent row matching schema 0007 | Filter narrows the grid; badges accurate; pause/resume controls call `/api/agents/[id]` PATCH |
| ☐    | W8E8  | sonnet | `web/src/components/tools/{BotsTab,BotTokenInput,WebhookUrlDisplay}.tsx`; extend `tools.astro` with Bots tab (Telegram/Discord/HTTP API ingress); "Test message" probes through claw end-to-end | Bot token saves; webhook URL shown; test message round-trips and displays reply |
| ☐    | W8E9  | sonnet | `web/src/components/skills/{SkillImportMenu,SkillStartersGallery,SkillEvalRunner}.tsx`; extend `skills.astro` with `[Import ↓]` menu + Starters section; eval runner inside skill drawer | Import from URL/GitHub round-trips to R2; starters render the 4 shipped templates; eval shows rubric |
| ☐    | W8E10 | sonnet | Extend `payments.astro` (and workspace payments) — show x402 split breakdown (creator 85% / platform 10% / protocol 5%) reading from `x402_payments` columns; add Accept-links section | Splits accurate per row; accept-link rows link to `pay.<slug>.one.ie/...` URLs |
| ☐    | W8E11 | sonnet | InboxBell substrate wiring — subscribe to `/api/notifications` poll or SSE; render unread badge in sidebar header; clicking opens dropdown with last 5 + "[See all →]" → `/notifications` | Badge updates within 5s of new notification; dropdown matches feed |
| ☐    | W8E12 | sonnet | `emitClick` coverage for new surfaces — every action button on W8E1-E11 calls `emitClick('ui:<surface>:<action>')` per `.claude/rules/ui.md`; new receivers: `ui:wallet:*`, `ui:notifications:*`, `ui:themes:*`, `ui:viewer:impersonate`, `ui:tools:bot-*`, `ui:skills:import`, `ui:skills:run-eval` | grep gate: `actions_emitting === actions_rendered` per new surface |

### W8.verify (sonnet, parallel × 4)

| done | id    | model  | task                                                                                                | exit                                                |
|------|-------|--------|-----------------------------------------------------------------------------------------------------|-----------------------------------------------------|
| ☐    | W8V1  | sonnet | Click-test 4 new pages (`/recover`, `/themes`, `/notifications`, `/wallet`) — primary action ≤2 clicks each | Friction map row passes per page; LH ≥ 95     |
| ☐    | W8V2  | sonnet | Click-test agent detail tabs — Overview → Versions → Deploy → Revenue → Eval with real data         | All 5 tabs load < 300ms; rollback + re-eval work    |
| ☐    | W8V3  | sonnet | Impersonation flow end-to-end — owner picks agency, banner pins, sidebar reflects agency menu, "Stop" clears cookie + reloads | viewer override safe (non-owner sending cookie ignored); 15min TTL respected |
| ☐    | W8V4  | sonnet | Backend coverage gate — `web/ui.md §9` table: every "now exposed in" cell has a working route response | Zero unexposed endpoints in audit table             |

**Exit gate:** 4 new pages + 5 component groups ship. ViewerSwitcher works safely. Backend coverage table is 100% green except deferred admin-only endpoints.

---

## W9 — Reverse-gap endpoints (UI exists, backend missing)  ⬜ TODO (5 tasks open)

**Source:** `web/ui.md §8` Reverse gaps. Three handlers spec'd in
`web/ui.md` flows / `lifecycles-ui.md` whose backends were never wired or never
verified. Mode: lean. Each is < 1 day's edit.

### W9.recon (haiku × 1)

| done | id    | model | task                                                                                              | exit                                              |
|------|-------|-------|---------------------------------------------------------------------------------------------------|---------------------------------------------------|
| ☐    | W9R1  | haiku | Read `web/src/pages/api/{settings,provision}.ts` — confirm `?action=delete` + `?action=redeem-invite` handlers absent or partial | One-line status per handler; W9.edit tasks scoped accordingly |

### W9.edit (sonnet, parallel × 3)

| done | id    | model  | task                                                                                                            | exit                                                |
|------|-------|--------|-----------------------------------------------------------------------------------------------------------------|-----------------------------------------------------|
| ☐    | W9E1  | sonnet | `web/src/pages/api/settings.ts` add `?action=delete` — passkey re-challenge, owners row delete (CASCADE/SET NULL on domains/invites), async R2 purge of `{slug}/*`, sub-clients survive (parent_slug → NULL). Per `lifecycles-ui.md §7.2` | DangerSection.tsx call succeeds; `wrangler d1 execute` confirms row gone; sub-clients still resolvable |
| ☐    | W9E2  | sonnet | `web/src/pages/api/provision.ts` add/verify `?action=redeem-invite` — accepts `{ token, slug, pubkey }`, gates on `invites.expires_at`, marks `redeemed_at`, writes credential to `owners_keys`, locks `parent_slug`. Per `lifecycles-ui.md §4.2` | Invite link from agency → client passkey → invite redeemed in single round-trip |
| ☐    | W9E3  | sonnet | Decide + implement recovery-codes backend wiring — currently `/recovery-codes` page is spec'd but has no endpoint. Either: (a) BIP39 seed wraps the passkey-encrypted root in client-side WebCrypto (no backend), (b) seed hash stored on `owners.recovery_hash` for verify-only round-trip. Pick per `passkeys.md` 5-state lifecycle | Decision recorded in `passkeys.md`; if (b), `/api/recover?action=verify-codes` lands and `/recovery-codes` "Mark as saved" PATCHes a `recovery_codes_saved_at` column |

### W9.verify (sonnet × 1)

| done | id    | model  | task                                                                                                | exit                                              |
|------|-------|--------|-----------------------------------------------------------------------------------------------------|---------------------------------------------------|
| ☐    | W9V1  | sonnet | End-to-end: delete a test workspace; redeem a test invite; verify recovery codes path matches W9E3 decision | All 3 pass; `web/ui.md §8 Reverse gaps still open` table goes empty |

**Exit gate:** 3 missing handlers land. `web/ui.md §8` reverse-gap list is empty.

---

## Spawn protocol — how `/do` reads this file

```
/do web/ui-todo.md
   ↓
Phase 0: spawn 5 haiku in parallel for Q1-Q5 (one message, 5 Agent calls)
   ↓ (all return; conditional follow-throughs queued)
Phase 0b: spawn Q4F|Q4F2 + Q5F if their triggers fired
   ↓
Phase 1: W1.recon (3 haiku) + W2.edit.W2E1 (haiku) + W4.edit (sonnet)
         all in one message — parallel across waves
   ↓
Phase 2: W1.decide (opus, sequential 5 — W1D1..W1D5 chain via context)
         W2.edit.W2E2 (sonnet) starts when W2E1 lands
   ↓
Phase 3: W1.edit (9 sonnet in parallel, one message — incl W1E9 PasskeyKeepThis)
         W3.recon (2 haiku in parallel)
   ↓
Phase 4: W3.edit (7 sonnet in parallel — incl W3E7 deploy gate)
   ↓
Phase 5: W5.recon (2 haiku) + W6.recon (1 haiku)
   ↓
Phase 6: W6.decide (opus, 3 sequential)
   ↓
Phase 7: W5.edit (10 sonnet) + W6.edit (5 sonnet incl W6E5)
         — 15 sonnet across two messages (cap = 13/message)
   ↓
Phase 8: All verify tasks run (W1V1, W2V1, W3V1, W4V1, W5V1-9, W6V1-6)
         compute deterministic numbers; mark or warn paths
   ↓
Phase 9: W7 docs reconciliation — 4 haiku in parallel + W7V1-2 sonnet verify
   ↓
Phase 10: W8.recon (2 haiku) + W9.recon (1 haiku) in parallel
   ↓
Phase 11: W8.decide (1 opus — ViewerSwitcher contract)
   ↓
Phase 12: W8.edit (12 sonnet — split across 2 messages, cap 13/msg)
          + W9.edit (3 sonnet) — total 15 sonnet across 2 messages
   ↓
Phase 13: W8.verify (4 sonnet) + W9.verify (1 sonnet) in parallel
```

**Per-message parallelism cap:** ≤ 13 Agent calls per message. Beyond that, batch
across two messages — context cost outweighs the speedup.

**Cross-tier ordering rule:** within a wave, opus decides → sonnet edits → sonnet
verifies. haiku recon can run before opus or in parallel with another wave's edit.

**Closing rule:** every spawned agent MUST call `mark(edge, depth)` on success or
`warn(edge, 1)` on failure — width only compounds if every branch deposits.

---

## Anti-scope (NOT in this plan)

- New SDK methods beyond surface needs · Python changes · MCP additions
- New CLI verbs · multi-region D1 · real-time agent-edit collab
- Audit log surface UI (only the bare row in W5) · agent marketplace publishing

---

## See also

- [`ui.md`](ui.md) — single UI plan (33 surfaces, 9 flows, components, mobile, backend coverage)
- [`roles.md`](roles.md) — 4-tier viewer model
- [`cascade.md`](cascade.md) — sub-client agency hierarchy
- [`agents-lifecycle.md`](agents-lifecycle.md) — agent state machine
- [`emails.md`](emails.md) — transactional email templates
- [`lifecycles.md`](lifecycles.md) · [`lifecycles-ui.md`](lifecycles-ui.md) — journey + gap surfaces
- [`runbook.md`](runbook.md) — ops playbook
- [`../.claude/commands/do.md`](../.claude/commands/do.md) — wave orchestration
- [`../.claude/rules/ui.md`](../.claude/rules/ui.md) — every onClick → signal
- [`../.claude/rules/design.md`](../.claude/rules/design.md) — 6 tokens enforced at build
- [`../.claude/rules/astro.md`](../.claude/rules/astro.md) — islands, lazy, dark contrast
- [`../.claude/rules/documentation.md`](../.claude/rules/documentation.md) — W2 plan → W3 alongside → W7 verify
- [`../plans/learnings.md`](../plans/learnings.md) — append-only log; W7V2 writes here

---

*73 tasks. 9 waves. 3 tiers. Width = parallel sonnet edits. Depth = waves × cycles.
Docs and code edited in parallel. Every branch marks. The substrate learns the
chat surface itself. W8 closes 15 backend-gap surfaces; W9 lands the 3 missing
handlers — backend coverage table empties.*
