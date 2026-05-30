---
title: Receiver resolvers — the web worker IS the substrate edge
slug: receiver-resolvers
type: plan
tier: feature
status: done
tags: [substrate, receivers, agent-first, ask-route]

goal: "An agent calling any declared receiver gets a real outcome immediately — never a silent 10s timeout — because the web worker resolves every receiver in-process against D1 + the TypeDB gateway, with no dead cross-worker forward."
outcome: "curl POST /api/ask/<read receiver> with a Bearer returns outcome:result instantly; unhandled receivers return an instant structured dissolve, never timeout."
---

# Receiver resolvers

## Why

The agent lifecycle test (2026-05-30) found that every receiver NOT handled
in-process (`world:*`, `meta:*`) **timed out**: the `ask`/`signal` routes forward
to `env.NANOCLAW_URL`, but the old "nanoclaw" signal-processor was replaced by
`channels` (the chat runtime, which exposes only `POST /signal/:group`, not a
general receiver processor that writes outcomes back). Prod sets `CHANNELS_URL`,
not `NANOCLAW_URL`, so the forward is dead → `awaitOutcomeHttp` waits 10s → timeout.

**Result:** ~half the typed catalog (C4 contracts) had no live handler. `market:list`,
`stats:current`, `pay:weight`, etc. all hung.

## The fix — power through simplicity

The web worker **is** the substrate edge. One unified dispatch resolves every
receiver in-process; nothing silently forwards-and-times-out.

```
ask/[...receiver].ts → dispatchReceiver(receiver, data, env, ctx)
  world:*  → dispatchWorldReceiver (D1)              [exists]
  meta:*   → dispatchMetaReceiver  (catalog)          [exists]
  else     → RESOLVERS[receiver]   (D1 + TypeDB gw)   [new]
  null     → instant honest `dissolved {error:no_handler, receiver, hint}`  ← kills the timeout
```

One registry, co-located with the contracts. The 10s KV-poll path only remains
for an explicitly-configured external processor (NANOCLAW_URL), which prod no
longer sets — so agents get an instant outcome on every call.

## Phase 1 — architecture + verifiable reads  ✅ DONE (2026-05-30)

- [x] `src/lib/receiver-resolvers.ts` — unified `RESOLVERS` registry + `dispatchReceiver`
- [x] `ask/[...receiver].ts` — one dispatch, instant `dissolved {no_handler}` kills the 10s hang
- [x] `signal/[receiver].ts` — in-process dispatch via `waitUntil` for fire-and-forget writes
- [x] Reads live: `stats:current` (KV 60s), `market:list` (D1), `agents:capabilities` (D1), `identity:address` (KV 24h), `groups:members` (D1, tenant-scoped), `world:state`
- [x] Verified live: `stats:current` warm 0.26s · `market:list` D1 0.43s · unhandled → instant dissolve

## Phase 2 — value writes + discovery + A2A  ✅ DONE (2026-05-30)

All shipped in `one.ie/web/src/lib/receiver-resolvers.ts`:

| Receiver | Handler | Notes |
|---|---|---|
| `capabilities:publish` | TypeDB capability + D1 `market_listings` | publish→discover round-trip proven |
| `agents:register` | TypeDB capability per skill + D1 | idempotent |
| `agents:commend` / `agents:flag` | `mark` / `warn` path strength | reputation signal |
| `agents:status` | D1 `world_actors.status` | active/inactive toggle |
| `groups:join` / `leave` / `invite` | D1 membership + TypeDB | membership writes |
| `signals:list` | D1 `agent_events` | tenant-scoped |
| `dashboard:usage` | D1 `owners` plan limits | auth-gated |
| `subscriptions:register` | acknowledged (BrainClient push layer owns delivery) | |
| `actors:find` | TypeDB — **agent/world only** (humans excluded — PII) | marketplace discovery |
| `peer:message` | channels `/signal/:group` — instant, no LLM | A2A async messaging |
| `inbox:{uid}` | channels `/messages/:group` — dynamic prefix receiver | own inbox only |
| `chat:send` | channels `/message` — SSE drain, sender = callerUid | human-facing |

**D1 migration 0082** (`market_listings`) applied to prod — backs `market:list` and `agents:capabilities` at sub-1s.

**Security verified live** (one-prod `7c0e9db1 / 09d6e43e`):
- `groups:members` IDOR: scoped to `ownerSlug` via `world_groups` join
- `actors:find` hardcoded `agent`/`world` in TypeQL (human not passable)
- `chat:send` sender always `callerUid` — spoofing impossible
- `inbox:uid` forbidden when suffix ≠ callerUid
- TypeQL injection: `safeId` allowlist replaces weak quote-stripping

## Phase 3 — economy transactions  [NEXT — design first]

These move real value. Each needs a design pass before the cut:

| Receiver | What it needs |
|---|---|
| `market:hire` | Open a shared group (buyer + seller) as a job context; escrow template until Sui wallet linked |
| `pay:weight` | Sui onchain settlement — requires wallet link via `identity:address` + Sui signing |
| `agents:sync` | Bulk agent+skill declaration from markdown; complex multi-step write |
| `agents:deploy-on-behalf` | Inherit owner paths — needs cross-actor capability proof |
| `loop:close` | Stage outcome + highway write — compose `mark`/`warn` from session result |
