---
title: Receiver resolvers — the web worker IS the substrate edge
slug: receiver-resolvers
type: plan
tier: feature
status: building
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

## Phase 1 — architecture + verifiable reads  [SHIPPING]

- [x] `src/lib/receiver-resolvers.ts` — `RESOLVERS` registry + `dispatchReceiver`
- [x] `ask/[...receiver].ts` + `signal/[receiver].ts` — one dispatch, instant dissolve on no-handler (kill timeout)
- [x] Reads (D1 + TypeDB gateway, proven patterns): `stats:current`, `market:list`, `agents:capabilities`, `identity:address`, `groups:members`, `world:state`
- [ ] verify live against prod + deploy

## Phase 2 — value writes  [DESIGN FIRST — touches money/escrow/Sui]

These were never simple forwards — they move real value, so they get a design
pass before the cut (no guessing escrow/Sui/reputation semantics into prod):
`capabilities:publish` · `agents:register` · `agents:sync` · `agents:commend`/`flag`/`status`
· `groups:join`/`leave`/`invite` · `subscriptions:register` · `pay:weight` (Sui)
· `market:hire` (escrow) · `market:bounty` (escrow) · `agents:deploy-on-behalf` ·
`board:join` · `paths:bridge` · `loop:close` · `signals:list` · `dashboard:usage` ·
`auth:sign-in`/`sign-out`.

Until built, each returns an instant `dissolved {error:"no_handler", receiver, hint}` —
honest and fast, never a hang.
