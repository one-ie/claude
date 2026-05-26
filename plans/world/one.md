---
name: one
description: The whole business in one file — expressed as the world it runs on. 6 dimensions, 4 surfaces, 1 number.
classifier:
  spec_locked: Y
  variance_known: Y
  exit_scalar: Y
  files_known: Y
  mode: lean
  lifecycle: construction
---

# one — a world for agents

```
We are building a world for agents.
The world is 200 lines.   (one.ie/one/100-lines.md)
The business is one file. (this one)
Same shape: signals flow, paths strengthen, highways emerge.
```

---

## The business in 6 dimensions

The same 6 that lock the world ([`one.ie/src/schema/one.tql`](one.ie/src/schema/one.tql)). The business is not *metaphorically* a colony — it *is* a colony, running on the world it ships.

```
# ── DIMENSION 1: GROUPS ─────────────────────────────────────────────────────
# Containers. one.ie. pay.one.ie. api.one.ie. github.com/one-ie/one.

group "one"            type "company"   status "active"
group "one.ie"         type "surface"   parent "one"     # humans + agents
group "pay.one.ie"     type "surface"   parent "one"     # devs + businesses
group "api.one.ie"     type "world" parent "one"     # the gateway
group "one-ie/one"     type "surface"   parent "one"     # opensource

# ── DIMENSION 2: ACTORS ─────────────────────────────────────────────────────
# Who acts. owner (Anthony). humans. agents. developers.

unit "human:tony"      kind "owner"     wallet <Sui-pin>     # SubstrateOwner
unit "human:*"         kind "human"     wallet <SE-rooted>   # passkey PRF
unit "agent:*"         kind "agent"     wallet <wrapped>     # owner KEK
unit "dev:*"           kind "developer" wallet <self>        # SDK/MCP/CLI

# ── DIMENSION 3: THINGS ─────────────────────────────────────────────────────
# Tasks with prices. price > 0 = revenue.

skill "wallet:create"        price 0     # 5s, free, top of funnel
skill "wallet:agent-spawn"   price 0     # 50ms, free, peer-agent
skill "buy"                  price 0     # 3s, free, x402 settles
skill "sell"                 price 0     # 30s list
skill "x402:settle"          price bps   # take rate, pay.one.ie
skill "sponsor:gas"          price markup # sponsored-tx, any token in
skill "api:typedb-quota"     price tier  # managed api.one.ie
skill "agent:revenue-share"  price split # peer-agent commerce

# ── DIMENSION 4: PATHS ──────────────────────────────────────────────────────
# Weighted connections. mark() = revenue + retention. warn() = churn.

path  human → wallet:create                     # arrival highway
path  wallet → buy                              # first tx
path  buy → sell                                # closes loop
path  dev → npx-oneie → deploy → first-signal   # OSS funnel
path  business → pay.one.ie → integration-60s   # paid funnel

# ── DIMENSION 5: EVENTS ─────────────────────────────────────────────────────
# Every signal recorded. data, amount, success, latency.

signal { sender:human   receiver:"one.ie:wallet"  latency: <5000ms }
signal { sender:agent   receiver:"chat:peer"      latency: <50ms   }
signal { sender:business receiver:"pay:settle"    amount: $X       }

# ── DIMENSION 6: KNOWLEDGE ──────────────────────────────────────────────────
# What emerged. Not programmed — measured.

hypothesis "wallet→buy in <60s converts 3x" → testing
hypothesis "OSS deploy → paid api in 7d"    → confirmed
frontier   "agent-to-agent commerce volume" → exploring
```

---

## The 4 surfaces (units in the colony)

| Surface | URL | Units | Skills priced | Speed claim |
|---|---|---|---|---|
| **one.ie** | https://one.ie | humans + agents | wallet, buy, sell, chat | 5s · 50ms · 3s · 30s |
| **pay.one.ie** | https://pay.one.ie | devs + businesses | x402:settle, sponsor:gas | 60s integration |
| **api.one.ie** | https://api.one.ie | all surfaces | api:typedb-quota | <10ms gateway |
| **one-ie/one** | github.com/one-ie/one | developers | (free) → managed api | 3-command deploy |

All four → one world ([`one.ie/CLAUDE.md`](one.ie/CLAUDE.md)). Marginal cost of a new surface is a route, not a backend.

---

## The moat — 4 motifs, mark()'d into the schema

```
1. Two roots, one biometric, paper resurrects.
   path: apple-id  ↔  SE-identity   gate: Touch-ID   recover: BIP39
   spec: mac.md, passkeys.md

2. Threat model is a table.
   Every surface row: { defends: …, accepts: … }
   spec: every surface doc

3. Verification > presence.
   canary-decrypt · canary-tx · reconciliation tick
   "file exists" warn(0.5). "canary green" mark(+depth).
   spec: mac.md (quarterly tick)

4. Four agent patterns.
   co-sign / scoped / capability / peer
   Humans safe by physics — biometric is non-transferable.
   spec: agents.md
```

A competitor copying the UI does not copy the moat. The moat is the threat-model table they're unwilling to write.

---

## How money is mark()'d

```
SOURCE              SURFACE          MECHANISM
─────────────────   ──────────────   ─────────────────────────────
take rate           pay.one.ie       bps × x402 settled volume
sponsored-tx        one.ie + pay     gas markup, any token in
managed quota       api.one.ie       SDK/MCP free → paid tier
agent revenue       one.ie /chat     split on peer-agent commerce
```

Every payment is a `signal` with `amount > 0`. Every retained user is a `path` whose `strength` survives `fade()`. The colony's `total_revenue()` ([`one.tql`](one.ie/src/schema/one.tql) `fun total_revenue()`) is the business.

---

## The one number

```
Q3-2026 target:  $1M annualized × pay.one.ie
                 AND 4 speed claims passing weekly canary

If the number hits and the canaries hold,
every other surface compounds for free off the same world.
If either fails, no other metric matters.
```

---

## What ships next (sequenced, lean mode each)

```
W1  /buy end-to-end                  → website.md         · 3s canary
W2  pay.one.ie 60s integration       → x402.md            · close Wave-0 SDK gap
W3  agent peer-wallet on /chat       → chat.md, agents.md · 50ms canary
W4  npx oneie 3-command deploy       → one-ie/one/README  · fresh CF smoke
W5  quarterly verification tick      → mac.md, passkeys   · canary dashboard
```

Each row = lean plan inside owning spec doc ([`one.ie/one/template-plan.md`](one.ie/one/template-plan.md) §0). Full mode only if a prior trips.

---

## What we will not do

```
✗ custody                       (passkeys.md — no zkLogin, no Mysten)
✗ third-party password managers (secrets.md — SE root only)
✗ trust-ramp for agents         (agents.md — 4 patterns are shapes, not levels)
✗ new root *.md without classifier (cluster near-saturated)
```

---

## The flywheel

```
human arrives ──signal──→ wallet ──5s──→ first buy ──mark(+1)──→ retention
       │                                                              │
       │                                                              ▼
       └──── /chat ──peer-agent──→ agent buys ──signal+amount──→ revenue
                                                                      │
                                                                      ▼
              dev sees OSS ←──npx oneie──── github.com/one-ie/one ←───┘
                   │
                   └──→ deploys ──→ paid api.one.ie quota ──→ recurring

 .  fade(0.05/tick) decays unused paths.
    What survives → highway.
    What highways → product roadmap.
```

The roadmap is `world.highways(10)`. Not opinion. Measurement.

---

## Where to start

```
new teammate     → README.md → simple.md → this file
implementing     → this file → surface spec → one.ie/CLAUDE.md
strategy         → this file is the only file
deciding tradeoff → the one number decides; if it doesn't move it, defer
```

---

*Plans in root. Code in `one.ie/`. Substrate at `api.one.ie`. SDK at `github.com/one-ie/one`.
6 dimensions, 4 surfaces, 4 motifs, 1 number, 0 drift.*
