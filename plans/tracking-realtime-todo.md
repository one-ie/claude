---
title: Tracking-realtime — Tier 1 + funnel rescue (use cases 1, 2, 3, 4, 9)
slug: tracking-realtime
type: plan
tier: complex
mode: construction
tags: [tracking, realtime, durable-object, chat, personalization, funnel-rescue, pheromone]
source_of_truth:
  - web/tracking-realtime.md
  - web/tracking.md
  - web/src/workers/analytics-relay.ts
  - web/src/pages/api/chat.ts
  - web/src/lib/use-watch.ts
existing_primitives:
  - web/src/workers/analytics-relay.ts:AnalyticsRelay: DO with /snapshot /follow /sense /highways /rollups /recent /connect endpoints + WebSocket hibernation + pheromone world in RAM; C1/C3/C4 compose, C2/C5 extend with new internal predicates + topics
  - web/src/lib/pheromone.ts:createWorld: in-RAM mark/warn/sense/follow/select/highways/fade; C3/C4 call via DO RPC, never re-implement
  - web/src/lib/use-watch.ts:useWatch: React hook `(topic, slug) → {events, summary, gap}` over SSE; C2/C4/C5 subscribe — never write a new client transport
  - web/src/pages/api/analytics/watch.ts:GET: SSE←WS bridge to DO; C2 piggybacks `agent:<id>` topic on the same channel
  - web/src/pages/api/chat.ts:POST + buildSystem: 5-layer system prompt composition with thread + variant + persona + personalisation + locale; C1 adds 6th layer (actor snapshot) via existing `streamText` call
  - web/src/lib/funnel.ts:resolveFunnelEvent + signalFunnelEvent + stageDropOff: stage/goal resolver and substrate signaller; C5 reads to compute baselines, never duplicates
  - web/src/workers/funnel-aggregate-cron.ts:runHourlyAggregate: hourly rollup of agent_events → funnel_hourly; C5 extends with dwell-baseline emission, never forks
  - web/src/lib/identity.ts:visitorHash + climbLadder + readCookieId: rung 0-1 identity; C1/C4 read `visitor_hash` from cookie/event, never re-derive
  - web/src/components/Chat.tsx:Chat: `useChat` from `@ai-sdk/react` + SSE streaming; C1 sends `visitor_hash` in chat body, C2 surfaces unsolicited messages via existing message list
  - web/src/components/Hero.tsx:Hero: static hero on `/`; C4 swaps copy via prop driven by `useWatch` first packet
show: true
escape:
  condition: "any cycle's W4 fails delta_tsc > 0 twice"
  action: "halt; re-recon the failing primitive; re-scope cycle to compose-only"
context_triggers:
  - pattern: "(analytics-relay|AnalyticsRelay|DurableObject)"
    inject: "web/tracking.md § 12 (Durable Object hot path) + web/tracking-realtime.md § 'realtime architecture'"
  - pattern: "(useWatch|/api/analytics/watch|SSE)"
    inject: "web/tracking-realtime.md § '#4 Live page personalization'"
  - pattern: "(funnel|stageDropOff|workflow.mining)"
    inject: "web/tracking.md § 6.1 Mined workflows + web/tracking-realtime.md § '#9 In-session funnel rescue'"
  - pattern: "(snapshotForActor|/snapshot|buildSystem)"
    inject: "web/tracking-realtime.md § '#1 Chat that already knows you'"
---

# Tracking-realtime — Tier 1 + funnel rescue

**Goal:** ship use cases 1, 2, 3, 4, 9 from `web/tracking-realtime.md` on top of the live substrate (`AnalyticsRelay` DO + `useWatch` + pheromone world). Each use case = one cycle. Latency budget: Tier 1 (C1-C4) `< 100 ms p99`, funnel rescue (C5) `< 500 ms p99`.

**Exit:** `bun run verify` green AND all five demo gates pass:
- C1: `bun vitest run tests/e2e/tracking-realtime/c1-snapshot-chat.test.ts`
- C2: `bun vitest run tests/e2e/tracking-realtime/c2-agent-trigger.test.ts`
- C3: `bun vitest run tests/e2e/tracking-realtime/c3-follow-api.test.ts`
- C4: `bun vitest run tests/e2e/tracking-realtime/c4-personalize.test.ts`
- C5: `bun vitest run tests/e2e/tracking-realtime/c5-funnel-rescue.test.ts`

---

## Reuse contract (read before any cycle)

**Power through simplicity.** All five cycles compose existing primitives. The only "new" code is:
- C1: wire existing `/snapshot` DO endpoint into `buildSystem()` in `chat.ts`
- C2: add a predicate evaluator inside `AnalyticsRelay.apply()` + `agent:<id>` topic emission
- C3: thin Astro API route over existing DO `/follow`
- C4: new `personalize()` method on the DO that calls `world.follow()` internally + first-packet enrichment in `/connect`
- C5: dwell-baseline emission in existing hourly cron + stall predicate in DO alarm

**Anti-patterns rejected on sight (per template):**
- ❌ New `<UnsolicitedAgent>` component for C2 — use existing `MessageList` + add an "agent-initiated" message kind
- ❌ New `useActorSnapshot` hook for C4 — `useWatch` already returns `summary`; extend summary shape
- ❌ New `/api/personalize` endpoint when DO `/snapshot` + `/follow` cover it via composition
- ❌ New funnel mining cron for C5 — `funnel-aggregate-cron.ts` already groups events; add one query + write
- ❌ New `Hero2.tsx` variant component — pass `variant` prop to existing `Hero.tsx`

---

## Testing — Vitest first, msw for the DO, Playwright only on C2/C5 SSE

| Cycle | Test stack | Tokens (fail) | Demo command |
|---|---|---|---|
| C1 | Vitest + msw (mock `/snapshot`) + render assertion on `buildSystem` output | ~500 | `bun vitest run tests/e2e/tracking-realtime/c1-snapshot-chat.test.ts` |
| C2 | Vitest unit (predicate eval) + Vitest + miniflare for DO `agent:*` topic emission | ~800 | `bun vitest run tests/e2e/tracking-realtime/c2-agent-trigger.test.ts` |
| C3 | Vitest + msw on DO `/follow` + Astro endpoint contract | ~400 | `bun vitest run tests/e2e/tracking-realtime/c3-follow-api.test.ts` |
| C4 | Vitest + miniflare for DO `personalize()` + render assertion that `useWatch.summary.recommendations` reaches `<Hero>` | ~700 | `bun vitest run tests/e2e/tracking-realtime/c4-personalize.test.ts` |
| C5 | Vitest + miniflare for DO alarm with stubbed clock + baseline query against in-memory D1 | ~1000 | `bun vitest run tests/e2e/tracking-realtime/c5-funnel-rescue.test.ts` |

**LOC budget per test file:** ≤ 100 LOC (C1, C3) · ≤ 150 LOC (C2, C4, C5). Five `expect()` total per test file or the cycle splits.

**No Playwright unless** a cycle adds `requires_playwright: true` (none do — SSE can be asserted via miniflare WebSocket).

---

## Dependency graph

```
C1 (snapshot→chat)  ──┐
C2 (agent triggers) ──┤
C3 (follow API)     ──┼── all parallel — none read files another writes
C4 (personalize)    ──┤
C5 (funnel rescue)  ──┘
```

**No arrows.** Every cycle touches disjoint files:
- C1 → `chat.ts`, `Chat.tsx`, `lib/actor-snapshot.ts` (new helper)
- C2 → `analytics-relay.ts` (trigger predicate + topic), `Chat.tsx` (unsolicited handler — different lines than C1)
- C3 → `pages/api/follow/[from].ts` (new), `analytics-relay.ts` (different method than C2)
- C4 → `analytics-relay.ts` (`personalize()` method), `use-watch.ts` (summary shape extension), `Hero.tsx`
- C5 → `funnel-aggregate-cron.ts`, `analytics-relay.ts` (alarm extension), `lib/funnel-baseline.ts` (new)

**Shared file = `analytics-relay.ts`** — C2/C3/C4/C5 each add a distinct method or branch. Order is irrelevant if W3 anchors are method-scoped (see W3 anchor rules below). All can run as W3a in parallel.

`/do --auto` spawns five cycles simultaneously. Five Opus W2 calls, ~16 Sonnet W3 edits across parallel cycles, single Haiku-or-bash W4 per cycle.

---

## Status

- [x] C1 — Chat-knows-you (snapshot wired into system prompt)
  - [x] W0 baseline · [x] W1 recon · [x] W2 decide · [x] W3 edit · [x] W4 verify
- [x] C2 — Surface-aware agent triggers (substrate; Chat.tsx UI deferred)
  - [x] W0 baseline · [x] W1 recon · [x] W2 decide · [x] W3 edit · [x] W4 verify
- [x] C3 — Next-best-action via `follow()`
  - [x] W0 baseline · [x] W1 recon · [x] W2 decide · [x] W3 edit · [x] W4 verify
- [x] C4 — Live page personalization (substrate; index.astro swap deferred)
  - [x] W0 baseline · [x] W1 recon · [x] W2 decide · [x] W3 edit · [x] W4 verify
- [x] C5 — In-session funnel rescue
  - [x] W0 baseline · [x] W1 recon · [x] W2 decide · [x] W3 edit · [x] W4 verify

---

## C1 — Chat-knows-you  [tier: simple]

**Exit:** `bun vitest run tests/e2e/tracking-realtime/c1-snapshot-chat.test.ts` exits 0 AND POST `/api/chat` with body `{visitor_hash}` produces a system prompt whose last layer contains `Recent activity:` followed by ≥1 event line (verified via test that asserts on the `system` string passed to `streamText`).

### W1 — Recon  [Haiku · parallel]

**Existing-code recon:**
- `web/src/pages/api/chat.ts` — find `buildSystem()` (line ~37), the `streamText` call (line ~910), and where `body` is parsed (line ~78); report exact line numbers and the suffix-stacking order
- `web/src/workers/analytics-relay.ts` — find the `/snapshot` POST handler; report its request body shape, response shape, and which fields it returns (`recent`, `persona`, `highways`)
- `web/src/components/Chat.tsx` — find the `useChat({api: '/api/chat', ...})` call; report `experimental_prepareRequestBody` or equivalent so we know where to inject `visitor_hash` into the request body

**Primitive-inventory recon:**
- `web/src/lib/identity.ts` — confirm `visitorHash(cookieId, salt)` and `readCookieId(request)` exports; note the cookie name `_one`
- `web/src/lib/agent-md.ts` — confirm `parseAgentMd()` is still the agent metadata loader; we will NOT touch it
- `web/src/lib/cro/personalisation.ts` — confirm `evaluateRules()` signature; the snapshot becomes one more context input alongside it

### W2 — Decide  [Sonnet · simple]

**Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `web/src/lib/actor-snapshot.ts` (new — 1 helper) | `analytics-relay.ts` `/snapshot` endpoint | endpoint exists; no typed client + no prompt-formatter | **new** — single 40-LOC helper: `fetchActorSnapshot(env, slug, visitorHash) → ActorSnapshot` + `formatSnapshotForPrompt(snap) → string` |
| `web/src/pages/api/chat.ts` | already the system-prompt builder | doesn't read actor state | **extend** — add 1 await + 1 suffix string in `buildSystem` consumer |
| `web/src/components/Chat.tsx` | already wires `useChat` to `/api/chat` | doesn't send `visitor_hash` | **extend** — add `visitor_hash` to request body via `prepareRequestBody` |

**Slot map:**

| Primitive | Slot used | What this cycle puts in it |
|---|---|---|
| `streamText({system, ...})` in chat.ts | `system` string composition (after `personalisationSuffix`, before `bookingSuffix`) | `snapshotSuffix = formatSnapshotForPrompt(snap)` |
| `useChat({ ... })` in Chat.tsx | request body hook | `visitor_hash` from `document.cookie._one → visitorHash()` (already client-derivable; or pass via prop from Astro `<Chat client:idle visitorHash={...} />`) |

**Architectural questions:**
- Derive `visitor_hash` server-side (preferred — no client crypto) by reading the `_one` cookie in `chat.ts` POST and hashing with `env.WS_SALT`. **Decision: server-side.** Avoids client-side `crypto.subtle` race and salt exposure.
- Snapshot fetch timeout? **Decision: 50 ms — `Promise.race([fetchActorSnapshot(), timeout(50)])`**. Tier 1 budget is 100 ms p99; snapshot path budget is 50 ms; on timeout, chat continues without snapshot suffix (graceful degrade, log to `console.warn`).
- Prompt size cap? **Decision: snapshot suffix ≤ 800 chars** — top 10 recent events + top 3 persona tags + top 3 highways. Larger payloads truncated with `…+N more`.

**LOC budget:** new `actor-snapshot.ts` ≤ 60 LOC · `chat.ts` delta ≤ 20 LOC · `Chat.tsx` delta ≤ 0 LOC (cookie read happens server-side).

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `web/src/lib/actor-snapshot.ts` — **new** · exports `fetchActorSnapshot(env, slug, visitorHash, timeoutMs=50): Promise<ActorSnapshot | null>` (calls DO `/snapshot`) + `formatSnapshotForPrompt(snap): string`
- [ ] `web/src/pages/api/chat.ts` — **edit** at the `buildSystem` consumer site (anchor: `const personalisationSuffix =`): add `const snap = await fetchActorSnapshot(env, slug, visitorHash, 50)` + `const snapshotSuffix = snap ? formatSnapshotForPrompt(snap) : ''` + append `snapshotSuffix` between `personalisationSuffix` and `bookingSuffix` in the suffix join
- [ ] `web/src/pages/api/chat.ts` — **edit** at the body parse site (anchor: `const body = await request.json()`): derive `visitorHash` from `_one` cookie via `readCookieId(request)` + `visitorHash(cookieId, env.WS_SALT)`
- [ ] `web/tracking-realtime.md` — **edit** §"#1 Chat that already knows you": mark `Ready 5 → SHIPPED`, link to `web/src/lib/actor-snapshot.ts`
- [ ] `tests/e2e/tracking-realtime/c1-snapshot-chat.test.ts` — **new** · ≤ 80 LOC · 3 expects: (a) `fetchActorSnapshot` returns parsed shape, (b) `formatSnapshotForPrompt` produces `"Recent activity:"`-prefixed string ≤ 800 chars, (c) chat POST integration assembles system prompt including snapshot suffix when cookie present

**W3b:** *(empty — all edits independent files or non-overlapping anchors)*

### W4 — Verify  [inline composite]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/tracking-realtime/c1-snapshot-chat.test.ts` exits 0
- [ ] `curl -X POST /api/chat -H 'Cookie: _one=<uuid>' -d '{"messages":[...]}'` — system prompt visible in dev-mode log includes `Recent activity:`
- [ ] **Reuse audit:**
  - [ ] `grep -l "from '@/lib/identity'" web/src/lib/actor-snapshot.ts web/src/pages/api/chat.ts` returns both files
  - [ ] No new `useActorContext`/`useSnapshot` hooks (`grep -r "useActorSnapshot\|useSnapshot" web/src/lib web/src/hooks` returns 0)
  - [ ] `wc -l web/src/lib/actor-snapshot.ts` ≤ 60
  - [ ] `delta_loc_net ≤ +80` (60 new + ≤ 20 chat.ts delta)
- [ ] Rubric composite ≥ 0.65 (targets: security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.85 · speed ≥ 0.80)

Report: `delta_tsc=±N  delta_loc=±N  new_files=1  primitives_composed=3`

---

## C2 — Surface-aware agent triggers  [tier: complex]

**Exit:** `bun vitest run tests/e2e/tracking-realtime/c2-agent-trigger.test.ts` exits 0 AND simulated event (visitor_hash `H`, slug `S`, third pageview on `/pricing` with 30 s dwell) causes `AnalyticsRelay` to broadcast a frame to topic `agent:<agent_id>` containing `{kind:'agent-trigger', actor_id:H, surface:'/pricing', dwell:30, visits:3}` within `< 100 ms` of the event landing.

### W1 — Recon  [Haiku · parallel]

**Existing-code recon:**
- `web/src/workers/analytics-relay.ts` — find `apply()` (line ~135 region), the broadcast loop (lines ~191-195), and the `pending` Map structure; report the exact topic format (`${slug}:${agent_id}` vs `actor:${visitor_hash}`)
- `web/src/lib/use-watch.ts` — find how messages are dispatched to subscribers by topic prefix; report whether `agent:` topic would be auto-routed by existing match logic
- `web/src/components/Chat.tsx` — find the message-list render path; report how unsolicited messages (no user prompt) could be inserted into `messages` state — specifically if `setMessages` or equivalent is exposed by `useChat`
- `web/src/lib/agent-events.ts` — list the payload schemas; we will add `agent-trigger` as a new schema

**Primitive-inventory recon:**
- `web/src/pages/api/analytics/watch.ts` — confirm the SSE bridge passes topic transparently; we should NOT need to touch it
- `web/src/components/ai-elements/conversation.tsx` + `message.tsx` — confirm `Message` accepts `role: 'assistant'` with `parts: [{type:'text', text}]` for unsolicited inserts

### W2 — Decide  [Opus · complex]

**Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| Trigger predicate config (per-agent) | `agents/*.md` frontmatter | no `triggers:` field today | **extend** agent.md frontmatter — add optional `triggers: [{surface, dwell_ms, min_visits}]` array |
| Predicate evaluator (DO-side) | nothing equivalent | new — runs in `apply()` after pheromone marks, before broadcast | **new** — 1 pure function `evalTriggers(event, agentTriggers, rollups) → AgentTriggerHit[]` in `web/src/lib/agent-triggers.ts` (≤ 80 LOC) |
| Topic emission (DO-side) | `pending.get('actor:…')` pattern | needs `agent:<id>` topic | **extend** `apply()` — push hits into `pending.set('agent:'+id, ...)` |
| Client unsolicited handler | `Chat.tsx` already renders `messages` from `useChat` | no path to inject agent-initiated message | **extend** `Chat.tsx` — subscribe via `useWatch('agent:<agentId>', slug)` and on `agent-trigger`, append assistant message via existing useChat helper (or send a synthetic message-text into `setMessages` if exposed) |

**Slot map:**

| Primitive | Slot used | What this cycle puts in it |
|---|---|---|
| `AnalyticsRelay.apply()` | post-mark, pre-broadcast | `evalTriggers()` call + push results into `pending.get('agent:'+id)` |
| Agent `.md` frontmatter parser | meta extension | optional `triggers:` array |
| `useWatch(topic, slug)` (in Chat.tsx) | new subscription | listen for `kind:'agent-trigger'` frames |
| `Message` component | render path | reuse for assistant-initiated message |

**Architectural questions:**
- Where do triggers live? **Decision: agent.md frontmatter** — co-located with the agent that responds. Hot-reloaded by DO via R2 fetch + memoization (TTL 60 s).
- Cold-start cost? **Decision: per-DO trigger registry cached in RAM, refreshed on first relevant event or on `agent.md` change webhook** — trigger eval is then O(n_triggers) per event, n typically < 10.
- Topic naming? **Decision: `agent:<agent_id>` (lowercase, no slug prefix)** — agent IDs are globally unique; topic stays short.
- Dwell tracking? **Decision: store `lastPageviewAt` per `(visitor_hash, surface)` in `recent` buffer** — derive dwell at trigger-eval time. No new state structure.
- Visit-count? **Use existing `rollups` keyed `slug:view:web:<date>:<visitor_hash>:<surface>`** — already counted; extend rollup key if surface dimension missing (W1 confirms).

**LOC budget:** `agent-triggers.ts` ≤ 80 · `analytics-relay.ts` delta ≤ 40 · `Chat.tsx` delta ≤ 30 · agent-md parser delta ≤ 10. Total ≤ 160 LOC.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `web/src/lib/agent-triggers.ts` — **new** · `type AgentTrigger = {surface: string; dwell_ms?: number; min_visits?: number; cooldown_ms?: number}` + `evalTriggers(event, triggers, recent, rollups) → AgentTriggerHit[]` (pure function, no IO)
- [ ] `web/src/workers/analytics-relay.ts` — **edit** at `apply()` (anchor: pheromone mark loop end, `if (e.slug && e.event) this.world.mark...`): after marking, call `evalTriggers()` against in-RAM trigger registry; push hits into `this.pending.get('agent:'+hit.agent_id)`. **Add private method `loadTriggerRegistry(slug): Promise<Map<agentId, AgentTrigger[]>>`** with 60s TTL cache; populated from R2 agent.md frontmatter on first relevant event
- [ ] `web/src/lib/agent-md.ts` — **edit** at meta-parse site: pass through optional `triggers: AgentTrigger[]` field from frontmatter
- [ ] `web/src/components/Chat.tsx` — **edit** at `useChat({...})` consumer: add `useWatch('agent:'+agentId, slug)` subscription; on frame with `kind:'agent-trigger'`, append an assistant-role message via `useChat` helper (prefer `append({role:'assistant', content:...})` if available; else send via internal queue)
- [ ] `web/src/lib/event-vocabulary.ts` — **edit** add `'agent-trigger'` to `CRO_EVENTS` (or new category `AGENT_EVENTS`)
- [ ] `web/tracking-realtime.md` — **edit** §"#2 Surface-aware agent triggers": mark `SHIPPED`, link the new file
- [ ] `web/tracking.md` — **edit** the agent.md frontmatter contract section: document `triggers:` field
- [ ] `agents/CLAUDE.md` (in repo root) — **edit** to document `triggers:` field
- [ ] `tests/e2e/tracking-realtime/c2-agent-trigger.test.ts` — **new** · ≤ 150 LOC · 5 expects: (a) `evalTriggers` fires on 3rd visit with dwell ≥ threshold, (b) `evalTriggers` does NOT fire below threshold, (c) `evalTriggers` respects `cooldown_ms`, (d) miniflare-stubbed DO emits `agent:<id>` frame within 100 ms of `apply()`, (e) trigger registry refreshes when `agent.md` mtime advances

**W3b:** *(empty — `analytics-relay.ts` edits are scoped to new method + `apply()` tail anchor that doesn't collide with C3/C4/C5)*

### W4 — Verify  [Haiku × 5 rubric · 1 demo gate]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate: `bun vitest run tests/e2e/tracking-realtime/c2-agent-trigger.test.ts` exits 0
- [ ] End-to-end (miniflare): trigger config in test agent.md → simulated 3rd pageview → SSE frame on `agent:<id>` topic captured within 100 ms
- [ ] **Reuse audit:**
  - [ ] `Chat.tsx` reuses `useWatch` (`grep "useWatch" web/src/components/Chat.tsx` returns ≥ 1)
  - [ ] No new SSE/WebSocket client transport (`grep -r "new EventSource\|new WebSocket" web/src/components/Chat.tsx` returns 0 new lines)
  - [ ] `wc -l web/src/lib/agent-triggers.ts` ≤ 80
  - [ ] `delta_loc_net ≤ +180`
- [ ] Rubric composite ≥ 0.65 (5-Haiku spawn — security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.80 · speed ≥ 0.85 because hot-path latency is load-bearing)

Report: `delta_tsc=±N  delta_loc=±N  new_files=2  primitives_composed=4`

---

## C3 — Next-best-action via `follow()`  [tier: simple]

**Exit:** `bun vitest run tests/e2e/tracking-realtime/c3-follow-api.test.ts` exits 0 AND `curl /api/follow?from=persona:founder&slug=demo` returns `{from:'persona:founder', to:'thing:doc:quickstart-go', strength:0.84}` in `< 50 ms p99` (measured via vitest perf hook).

### W1 — Recon  [Haiku · parallel]

**Existing-code recon:**
- `web/src/workers/analytics-relay.ts` — find `/follow` GET handler; report exact request shape and response shape; confirm it accepts `?from=` query
- `web/src/lib/substrate.ts` — find existing `follow(env, tag)` export and where it's used; report whether it reads from DO or D1 fallback
- `web/src/pages/api/` — list any existing `follow*` or `highways*` routes to avoid name collision

**Primitive-inventory recon:**
- `web/src/pages/api/mark/[edge].ts` — confirm the URL-encoded edge pattern and POST shape — we will mirror it for `/api/follow/[from].ts` (or query-param variant — W2 decides)

### W2 — Decide  [Sonnet · simple]

**Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `web/src/pages/api/follow/[from].ts` (new — thin Astro route) | DO `/follow` endpoint exists; `substrate.ts:follow()` exists | no public Astro route that fronts DO `/follow` for browser/SDK callers | **new** — 25-LOC pass-through. Reads `slug` from `?slug=` or referer host, calls DO via `env.ANALYTICS_HUB.idFromName(slug).fetch('/follow?from=...')`, returns JSON |

**Slot map:**

| Primitive | Slot used | What this cycle puts in it |
|---|---|---|
| `AnalyticsRelay./follow` | DO-internal RPC | unchanged — we wrap it |
| URL-encoding pattern from `/api/mark/[edge].ts` | tag escape | reuse for `from` param |

**Architectural questions:**
- Path vs query? **Decision: dynamic `[from].ts` segment + URL-decode** — mirrors `mark/[edge].ts` style; SDK callers prefer URL clarity over query-string opacity.
- Cache headers? **Decision: `Cache-Control: max-age=5, stale-while-revalidate=30`** — `follow()` is stable across seconds for a given tag; 5 s freshness with SWR keeps DO load down.
- Slug resolution? **Decision: `?slug=` query is canonical; fall back to `request.headers.get('referer')` host → slug map**. Reject unknown slug with 404.

**LOC budget:** ≤ 30 LOC for `[from].ts` · 0 LOC delta for `analytics-relay.ts`.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `web/src/pages/api/follow/[from].ts` — **new** · `export const GET: APIRoute = async ({params, url, request, locals}) => {...}` — URL-decode `params.from`, resolve slug, call DO, JSON-respond with `{from, to, strength}`
- [ ] `web/tracking-realtime.md` — **edit** §"#3 Next-best-action": link to `web/src/pages/api/follow/[from].ts`, mark `SHIPPED`
- [ ] `web/tracking.md` — **edit** API surface table (§9 if present): add `GET /api/follow/:from?slug=...`
- [ ] `tests/e2e/tracking-realtime/c3-follow-api.test.ts` — **new** · ≤ 60 LOC · 3 expects: (a) GET with seeded DO returns expected `{from, to, strength}`, (b) returns 404 for unknown slug, (c) median latency over 100 calls < 50 ms (vitest `bench` or manual perf hook)

**W3b:** *(empty)*

### W4 — Verify  [inline composite]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate: `bun vitest run tests/e2e/tracking-realtime/c3-follow-api.test.ts` exits 0
- [ ] `curl -i 'http://localhost:8788/api/follow/persona:founder?slug=demo'` returns 200 + valid JSON in < 50 ms
- [ ] **Reuse audit:**
  - [ ] No reimplementation of `world.follow()` (`grep -r "function follow\b" web/src/pages/api/` returns 0 NEW hits)
  - [ ] Pass-through only (file contains the `ANALYTICS_HUB.idFromName(...).fetch('/follow?...')` call)
  - [ ] `wc -l web/src/pages/api/follow/[from].ts` ≤ 30
  - [ ] `delta_loc_net ≤ +30`
- [ ] Rubric composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  new_files=1  primitives_composed=2`

---

## C4 — Live page personalization  [tier: complex]

**Exit:** `bun vitest run tests/e2e/tracking-realtime/c4-personalize.test.ts` exits 0 AND `<Hero />` mounted via `client:idle` renders the `founder` variant copy when `useWatch('actor:<H>', slug)` first packet contains `summary.recommendations.hero='founder'` (within 100 ms of first paint in test env).

### W1 — Recon  [Haiku · parallel]

**Existing-code recon:**
- `web/src/workers/analytics-relay.ts` — find `/connect` WebSocket handler; report the first-message-sent-after-accept logic; identify where we hook `personalize()` enrichment
- `web/src/lib/use-watch.ts` — find the `summary` shape returned to React (currently `{persona, highways}`); report the consumer pattern
- `web/src/components/Hero.tsx` — current props, current copy strings; report whether copy lives inline or in a constants module
- `web/src/pages/index.astro` — how `<Hero />` is mounted, whether `visitorHash` is currently passed as a prop

**Primitive-inventory recon:**
- `web/src/lib/pheromone.ts:World` — confirm `follow()` + `highways()` signatures (already mapped, just verify in case of upstream change)
- `web/src/lib/cro/personalisation.ts` — confirm we DO NOT duplicate locale/variant logic; this cycle only adds the `recommendations` field

### W2 — Decide  [Opus · complex]

**Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `personalize()` DO method | DO `/snapshot` returns `recent + persona + highways`; no `follow()` invocations bundled | needs DO-internal helper that calls `world.follow()` + maps to content keys | **extend** `analytics-relay.ts` — add private `personalize(actorId)` that returns `{hero_variant, cta_variant, doc_recommendations: string[]}` |
| Content map (variant→copy) | none | inline JSX in `Hero.tsx` today | **new** `web/src/lib/personalize-map.ts` (≤ 50 LOC) — pure constant map keyed by tag-prefix |
| First-packet enrichment | `/connect` handler sends only events on connect | needs initial summary frame with `recommendations` | **extend** `/connect` — on `actor:<H>` topic, send first frame `{kind:'summary', persona, highways, recommendations}` |
| `useWatch` summary shape | already returns `{persona, highways}` | needs `recommendations` field | **extend** `WatchSummary` type and assign field |
| `Hero.tsx` | static copy today | needs variant prop | **extend** — add `variant?: 'founder'|'default'` prop, read via parent island consuming `useWatch` |
| New `<Personalized*>` wrapper | `Hero` already exists | wrapping it loses SSR shell; islanding the hero data fetch via useWatch is the clean path | **new** `web/src/components/PersonalizedHero.tsx` — 30-LOC React island that consumes `useWatch('actor:<H>')` and renders `<Hero variant={summary?.recommendations?.hero ?? 'default'} />` |

**Slot map:**

| Primitive | Slot used | What this cycle puts in it |
|---|---|---|
| `AnalyticsRelay./connect` first-packet | initial summary frame | `recommendations` derived from `personalize(actorId)` |
| `world.follow()` (in pheromone.ts) | called from DO `personalize()` | `follow('persona:'+top_persona) → content_key` |
| `useWatch` `summary` field | extended shape | `recommendations: {hero, cta, docs[]}` |
| `Hero.tsx` | new `variant` prop slot | `variant` selects copy from `personalize-map.ts` |

**Architectural questions:**
- Where does the actor's `visitor_hash` come from in the Astro page? **Decision: Astro middleware reads `_one` cookie + `env.WS_SALT`, passes via `<PersonalizedHero client:idle visitorHash={...} slug={...} />` props.** No client-side cookie parsing.
- Cold-start (no path yet)? **Decision: `personalize()` returns `{hero:'default'}` if no `persona:*` tags seen** — `<Hero>` accepts `variant='default'` as the SSR-rendered fallback. **No flash-of-default** because `<Hero>` defaults to `default` in SSR; if first packet arrives in < 200 ms and assigns a different variant, React diff swaps copy without layout shift (CSS height locked).
- Frame size? **Decision: first packet ≤ 1 KB** — cap `doc_recommendations` to 5 entries, copy keys only (string ids, not blobs).
- Cache? **Decision: no cache on `/connect`** — but DO-side `personalize()` results memoized per actorId for 5 s.

**LOC budget:** `analytics-relay.ts` delta ≤ 50 · `personalize-map.ts` ≤ 50 · `PersonalizedHero.tsx` ≤ 30 · `Hero.tsx` delta ≤ 15 · `use-watch.ts` delta ≤ 10 · `index.astro` delta ≤ 5. Total ≤ 160 LOC.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `web/src/lib/personalize-map.ts` — **new** · `export const HERO_VARIANTS: Record<string, {headline: string; sub: string; cta: string}>` + `export function pickHeroVariant(personaTags: string[]): string` (pure)
- [ ] `web/src/workers/analytics-relay.ts` — **edit** add private `personalize(actorId): {hero_variant, cta_variant, doc_recommendations}` method (calls `world.follow('persona:'+top)` + `world.highways(prefix:'thing:doc:', n:5)`); **edit** `/connect` handler to send initial summary frame including `recommendations: this.personalize(actorId)` when topic is `actor:<H>`
- [ ] `web/src/lib/use-watch.ts` — **edit** `WatchSummary` type to include `recommendations?: {hero: string; cta: string; docs: string[]}` (no behavior change otherwise)
- [ ] `web/src/components/Hero.tsx` — **edit** add `variant?: string` prop; read copy from `HERO_VARIANTS[variant ?? 'default']`; default-export unchanged
- [ ] `web/src/components/PersonalizedHero.tsx` — **new** · React island; consumes `useWatch('actor:'+visitorHash, slug)`; renders `<Hero variant={summary?.recommendations?.hero}>` inside `<Suspense fallback={<Hero variant="default"/>}>` (preserves SSR shell)
- [ ] `web/src/pages/index.astro` — **edit** swap `<Hero />` for `<PersonalizedHero client:idle visitorHash={...} slug={...} />`; cookie read in Astro frontmatter via `readCookieId(Astro.request)` + `visitorHash(cookieId, runtime.env.WS_SALT)`
- [ ] `web/tracking-realtime.md` — **edit** §"#4 Live page personalization": link the new files, mark `SHIPPED`
- [ ] `tests/e2e/tracking-realtime/c4-personalize.test.ts` — **new** · ≤ 130 LOC · 5 expects: (a) `pickHeroVariant(['persona:founder'])` returns `'founder'`, (b) DO `personalize()` returns shape with `hero_variant` derived from seeded world, (c) miniflare WS `/connect` first frame includes `recommendations`, (d) React test renders `<PersonalizedHero>` and asserts founder copy appears after summary arrives, (e) SSR default copy renders when no `recommendations` (no flash)

**W3b:** *(empty — `analytics-relay.ts` `personalize` method + `/connect` edit are scoped to handler tail and don't collide with C2's `apply()` tail edit)*

### W4 — Verify  [Haiku × 5 rubric · 1 demo gate]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate: `bun vitest run tests/e2e/tracking-realtime/c4-personalize.test.ts` exits 0
- [ ] Manual: `wrangler dev`, visit `/` with seeded actor cookie → DevTools network shows `/api/analytics/watch` SSE first frame containing `recommendations`; visible variant copy matches
- [ ] **Reuse audit:**
  - [ ] `PersonalizedHero.tsx` imports `useWatch` (`grep "from '@/lib/use-watch'" web/src/components/PersonalizedHero.tsx`)
  - [ ] No `useEffect(() => fetch(...))` pattern in `PersonalizedHero.tsx` (must use `useWatch`)
  - [ ] No duplication of `world.follow` in `personalize-map.ts` (pure constant map only)
  - [ ] `wc -l` totals: `personalize-map.ts` ≤ 50, `PersonalizedHero.tsx` ≤ 30
  - [ ] `delta_loc_net ≤ +180`
- [ ] Rubric composite ≥ 0.65 (5-Haiku — security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.85 · speed ≥ 0.85 — first paint must hold)

Report: `delta_tsc=±N  delta_loc=±N  new_files=3  primitives_composed=5`

---

## C5 — In-session funnel rescue  [tier: complex]

**Exit:** `bun vitest run tests/e2e/tracking-realtime/c5-funnel-rescue.test.ts` exits 0 AND when a simulated visitor exceeds `mined_baseline × 3` dwell on a known funnel step, `AnalyticsRelay` emits `{kind:'rescue-trigger', actor_id, surface, dwell, stage}` to topic `agent:<id>` (reusing C2 plumbing) within `< 500 ms p99` of the threshold crossing.

### W1 — Recon  [Haiku · parallel]

**Existing-code recon:**
- `web/src/workers/funnel-aggregate-cron.ts` — find `runHourlyAggregate()`; report the existing GROUP BY columns; identify where dwell baselines can be computed and written
- `web/src/lib/funnel.ts` — confirm `resolveFunnelEvent`, `signalFunnelEvent`, `stageDropOff` signatures; report what funnel step identification looks like (event names, payload fields)
- `web/migrations/` — confirm 0025_funnel_hourly + 0026_funnel_daily schemas; report column lists so we can decide on a new `funnel_baselines` migration
- `web/src/workers/analytics-relay.ts` — find the alarm handler; report cadence (50 ms drain, 5 s WAL flush, 60 s KV snap) — we'll piggyback stall detection on the 5 s tick

**Primitive-inventory recon:**
- `web/src/lib/agent-events.ts` — confirm `idle-nudge-fired` payload shape (we will mirror it for `rescue-trigger`)
- Confirm C2's `agent:<id>` topic plumbing exists (or is being built in parallel) — reuse the same dispatch

### W2 — Decide  [Opus · complex]

**Compose-or-construct verdict:**

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `web/migrations/0047_funnel_baselines.sql` | `funnel_hourly`/`funnel_daily` tables exist | no `(stage_id, p50_dwell_ms, p95_dwell_ms, sample_count)` table | **new** — 1 SQL migration, 1 CREATE TABLE |
| `web/src/lib/funnel-baseline.ts` | `funnel.ts` exists but doesn't compute baselines | needs `computeBaselines(db, window) → BaselineRow[]` + `getBaseline(db, stageId) → BaselineRow | null` | **new** — ≤ 80 LOC pure SQL wrapper |
| Baseline write in cron | `runHourlyAggregate` exists | doesn't compute or write baselines | **extend** — add one query + INSERT in the same hourly tick |
| Stall predicate in DO | `apply()` exists; alarm exists | no dwell tracking per (actor, stage) | **extend** — track `stageEnteredAt` in `recent` buffer; on alarm 5-s tick, scan for stalled visitors; on cross, push `rescue-trigger` to `pending.get('agent:'+id)` |
| `rescue-trigger` payload schema | `agent-events.ts` has `idle-nudge-fired` | new payload type | **extend** add to schema map |

**Slot map:**

| Primitive | Slot used | What this cycle puts in it |
|---|---|---|
| `funnel-aggregate-cron.runHourlyAggregate` | extend body | + compute baselines via `computeBaselines()` + INSERT into `funnel_baselines` |
| `AnalyticsRelay` alarm (5-s tick) | extend body | + scan `recent` for stalled funnel-step visitors; emit `rescue-trigger` |
| C2's `pending.get('agent:'+id)` dispatch | same | reuse to deliver `rescue-trigger` frames |
| `signalFunnelEvent` from `funnel.ts` | unchanged | stays the substrate signal source |

**Architectural questions:**
- Where does the DO learn baselines? **Decision: lazy-load from D1 `funnel_baselines` on first relevant event, cache 5 min in RAM.** No new push channel needed.
- Baseline freshness? **Decision: hourly rollup is good enough** — funnel dwell drifts slowly; if a baseline is missing, no rescue fires (graceful skip).
- Stall detection algorithm? **Decision: when `recent` shows `stage-start` for actor on stage X and no `stage-complete` after `baseline.p95_dwell_ms × 3`, fire once per (actor, stage) with cooldown 30 min.** Per-actor map `stalled: Map<actorId:stageId, lastFiredAt>`.
- Why not use C2's predicate engine? **Decision: stall detection is time-based, not event-based** — needs scheduled scan, not per-event eval. Lives in alarm tick.

**LOC budget:** migration ≤ 15 SQL · `funnel-baseline.ts` ≤ 80 · `funnel-aggregate-cron.ts` delta ≤ 30 · `analytics-relay.ts` delta ≤ 60 · `agent-events.ts` delta ≤ 10. Total ≤ 200 LOC.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `web/migrations/0047_funnel_baselines.sql` — **new** · `CREATE TABLE funnel_baselines (slug TEXT, stage_id TEXT, p50_dwell_ms INTEGER, p95_dwell_ms INTEGER, sample_count INTEGER, updated_at INTEGER, PRIMARY KEY (slug, stage_id));`
- [ ] `web/src/lib/funnel-baseline.ts` — **new** · `computeBaselines(db, slug, windowMs) → BaselineRow[]` (SQL: `SELECT stage_id, ... FROM agent_events ... WHERE ts > ? GROUP BY stage_id` using percentile_disc or sorted-array fallback for D1) + `getBaseline(db, slug, stageId) → BaselineRow | null` + `upsertBaselines(db, rows): Promise<void>`
- [ ] `web/src/workers/funnel-aggregate-cron.ts` — **edit** at `runHourlyAggregate` tail: call `computeBaselines()` + `upsertBaselines()`
- [ ] `web/src/workers/analytics-relay.ts` — **edit** at alarm handler (5-s tick anchor): scan `recent` for stalled funnel visitors; on cross, push `{kind:'rescue-trigger', actor_id, surface, dwell, stage}` into `pending.get('agent:'+responder_agent_id)`. **Add private `baselineCache` Map with 5-min TTL.** Reuse C2's topic emission path
- [ ] `web/src/lib/agent-events.ts` — **edit** add `'rescue-trigger'` payload schema `{actor_id, surface, dwell_ms, stage_id, baseline_p95_ms}`
- [ ] `web/src/lib/event-vocabulary.ts` — **edit** add `'rescue-trigger'` to `CRO_EVENTS`
- [ ] `web/tracking-realtime.md` — **edit** §"#9 In-session funnel rescue": mark `Ready 3 → SHIPPED`, link new files
- [ ] `web/tracking.md` — **edit** §6.1 with link to `funnel-baseline.ts` showing the mined-baseline implementation
- [ ] `tests/e2e/tracking-realtime/c5-funnel-rescue.test.ts` — **new** · ≤ 150 LOC · 5 expects: (a) `computeBaselines` returns expected p50/p95 from seeded D1, (b) `getBaseline` reads back the row, (c) miniflare cron pass writes baselines, (d) DO alarm with stubbed clock + seeded baseline emits `rescue-trigger` after `p95 × 3` elapsed since `stage-start`, (e) cooldown prevents duplicate fires within 30 min

**W3b:** *(empty)*

### W4 — Verify  [Haiku × 5 rubric · 1 demo gate]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate: `bun vitest run tests/e2e/tracking-realtime/c5-funnel-rescue.test.ts` exits 0
- [ ] Migration applied: `wrangler d1 execute web --remote --command="SELECT name FROM sqlite_master WHERE type='table' AND name='funnel_baselines'"` returns the table
- [ ] **Reuse audit:**
  - [ ] No new SSE/topic plumbing (`grep "agent:" web/src/workers/analytics-relay.ts` shows reuse of C2's pattern)
  - [ ] No duplicate dwell/percentile logic outside `funnel-baseline.ts`
  - [ ] `wc -l web/src/lib/funnel-baseline.ts` ≤ 80
  - [ ] `delta_loc_net ≤ +200`
- [ ] Rubric composite ≥ 0.65 (5-Haiku — security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.80 · speed ≥ 0.85)

Report: `delta_tsc=±N  delta_loc=±N  new_files=3  migrations=1  primitives_composed=4`

---

## Anchor-collision rules for `analytics-relay.ts`

Four cycles edit this file in parallel (C2 / C3-not / C4 / C5). To make W3a parallel-safe:

| Cycle | Anchor | What it adds |
|---|---|---|
| C2 | `apply()` tail (after `this.world.mark` loop) | trigger-eval + push to `pending.get('agent:'+id)` |
| C4 | `/connect` first-packet sender + new `personalize()` private method | initial summary enrichment |
| C5 | alarm handler (5-s tick branch) + new `baselineCache` field | stall scan + push to `pending.get('agent:'+id)` |

No two cycles edit the same line. C2 and C5 both push to `pending.get('agent:'+id)` — but at different anchors. If sandbox edit detects a collision, route the second edit through W3b (sequential).

---

## See also

- `web/tracking-realtime.md` — source for ranking and architecture diagrams (§"realtime architecture", §"implementation order")
- `web/tracking.md` — §6.1 workflow mining, §9.1 tags-become-paths, §12 DO hot path
- `web/src/workers/analytics-relay.ts` — the DO that hosts every primitive
- `one/dictionary.md` — canonical names (always)
- `one/rubrics.md` — scoring bands (always)
- `.claude/rules/api.md` — API endpoint policy (we add `/api/follow/[from]` per the "binary or streaming response" / multi-step-auth exception? **No — C3 is a thin proxy needed for SDK clarity**; W2 of C3 records the justification line)
