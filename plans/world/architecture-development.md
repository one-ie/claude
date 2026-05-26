---
title: Architecture Development Plan
type: plan
version: 2.0.0
status: WIRE
updated: 2026-04-29
companion: architecture.md
---

# architecture-development.md

> **Plan to get from where we are to the full stack in [`architecture.md`](architecture.md).** Wave-by-wave. Each wave ships one user-visible outcome with a measurable verify gate. Cites real paths in `one.ie/`, `apps/one-core/`, and on-chain Move modules. No aspirational scope.

---

## The shipping principle

> **One surface · one user · one paid call. Then the next.**

The fear of bigness is real. The answer isn't a smaller plan — it's a smaller *next step*. Three operations, that's the whole system (per [`one.ie/CLAUDE.md`](one.ie/CLAUDE.md)):

1. **spawn** — N parallel Sonnets, one per file, each gets its spec slice + speed budget + rule-file links
2. **verify** — single gate: `bun run verify` + `/speed` measure + rule-file compliance + threat-model row still holds
3. **close** — atomic; marks pheromone; emits `surface:shipped` with numbers

**Spec is immutable during build.** If a build trips a prior, *stop*, emit `spec-change`, reconcile the plan, resume. No silent drift.

---

## What's already shipped (don't rebuild)

The physics is done. What's left is exposure surfaces and one strategic decision (the wedge — see below).

| Layer | Status | Where |
| --- | --- | --- |
| Identity (human SE-rooted, agent owner-rooted, world federation) | ✓ | `one.ie/src/lib/auth-plugins/` |
| Routing (one formula, 194 tests, <0.005ms) | ✓ | `one.ie/one/routing.md` |
| **x402 server** (7 chains, USDC on EVM, signed coupons, stateless) | ✓ **prod** | `apps/one-core/backend/src/{x402.ts,protocol/handlers/x402.ts}` deployed at `pay.one.ie` |
| **x402 CLI tester** (challenge → pay → retry) | ✓ | `apps/one-core/tools/payment/x402.ts` |
| **`oneFetch()` SDK client** (drop-in `fetch()` replacement, auto-pays 402) | ☐ **the actual gap** | new `one-ie/one/packages/sdk/src/fetch.ts` |
| **`createServer()` SDK wrapper** (`{ price, handler }` → x402-decorated endpoint) | ☐ thin wrapper | new `one-ie/one/packages/sdk/src/server.ts`, wraps existing `apps/one-core` middleware |
| Marketplace (capability + price, escrow, branded AI, treasury 50bps) | ✓ | Move + TypeDB |
| Social (Path strength, Colony, toxicity gates) | ✓ | Move + routing |
| Settlement (Sui testnet `0xd064…4980`, 3s finality) | ✓ testnet | mainnet pending Wave 1 |
| Edge fabric (`one.ie`, `api.one.ie`, `pay.one.ie`, `nanoclaw`) | ✓ | per-domain Workers |
| State (TypeDB Cloud + D1 + KV + R2) | ✓ | substrate |
| Tools (MCP + SDK + CLI + REST + ADL bridge) | ✓ | `@oneie/*` |

**Translation:** the x402 *receive* path is production-grade and live at `pay.one.ie`. What's left is two thin SDK wrappers — `oneFetch()` (drop-in replacement for `fetch()` that auto-pays 402s) and `createServer()` (one-knob `{ price, handler }` for monetized endpoints). Both wrap code that already exists in `apps/one-core`. The bet is that **payment invisible at point of use** (a better `fetch`, not "a payment SDK") is what makes adoption involuntary.

---

## The wedge — closed-loop two-sided demo

The wedge is **agent-pays-agent, demonstrated as a closed economic loop in a single dev session**. Two repos, paired:

| Repo | Role | What runs | What dev sees |
| --- | --- | --- | --- |
| **`self-earning-agent`** | seller | `createServer({ price: 0.01, handler })` | "Your agent is live at `…/api/agent/abc123`. Earnings: $0.01, $0.02, $0.03…" |
| **`self-paying-agent`** | buyer | `oneFetch(url)` → auto-discover → auto-pay → return result | `→ paid $0.02 → "hola"` |

Run them in two terminals; watch money move between them. That's the demo. No staged seeding, no Stripe, no API keys.

**Why two repos, not one:** one-sided is "Stripe for APIs." Two-sided is a market. The "holy shit" moment is the *symmetry* — same SDK installs the buyer and the seller. That's the unsee-able thing.

**Trust ramp (non-negotiable):** both repos default to **testnet** with a faucet-funded ephemeral wallet. Real-money mode requires explicit `--mainnet` flag or `ONEIE_MAINNET=1`. The "holy shit" works just as well with testnet USDC for the first run; "auto-spends real money on `npm install`" is a trust cliff that kills half of first-time devs. Earn trust, then earn money.

**Wedge framing for marketing:** not "agent payments." Not "blockchain APIs." The line is:

> *Use any API without API keys or subscriptions.*

Payment is the means; key-free composable APIs is the felt value.

---

## Cold-start seed plan

Pheromone has zero signal at t=0. The closed-loop demo bypasses the cold start: the same dev who runs `self-paying-agent` also (typically) runs `self-earning-agent`, so the first calls are self-seeding by construction. But the network still needs sample skills to make the buyer demo *interesting*:

| Seed | What | Owner |
| --- | --- | --- |
| 1 | Three reference paid skills hosted on `pay.one.ie` (translate, summarize, scrape) — used by `self-paying-agent` default `task` | you, in a day |
| 2 | First 10 closed-loop receipts (each = one buyer + one seller run) pinned in `demo/receipts/` | you, manually — part of Wave 0 DoD |
| 3 | One canonical 60-second demo video (split-terminal, money moves) | you, before any external pitch |
| 4 | Optional: live earnings counter at `pay.one.ie/stats` ("Total spent by all agents: $X") | nice-to-have, not gating |

This isn't separate from Wave 0 — items 1–3 are deliverables 0.7 + the videos in the Wave 0 table.

---

## The waves

Three waves, in order. Don't start wave N+1 until wave N's verify gate is green and pheromone has been marked.

### Wave 0 — Closed economic loop (NOW · 0–2 weeks)

> **Goal:** a developer runs `self-earning-agent` in one terminal and `self-paying-agent` in another, watches money move between them autonomously, and can't unsee it. Testnet by default. Recordable in 60 seconds.

The receive side is shipped. This wave wraps it in two thin SDK helpers and ships two paired demo repos that exercise the full loop.

**Classifier:** `mode: lean` · `lifecycle: construction`
- Spec locked (`apps/one-core/backend/src/x402.ts:119-140` is the wire format; SDK is sugar)
- Variance known (CLI tester at `apps/one-core/tools/payment/x402.ts` already does steps 1+5 of `oneFetch`; missing 2-4)
- Exit scalar (paired-repo demo: one `oneFetch` → one `createServer` handler → testnet receipt → result returned, p50 < 3s)
- Files known (two SDK files, two demo repos, all paths cited below)

**Deliverables:**

| # | Deliverable | Files | Verify |
| --- | --- | --- | --- |
| 0.1 | **`oneFetch(url, opts?)` SDK function** — drop-in `fetch()` replacement; auto-discovers 402, loads/creates ephemeral testnet wallet, picks chain, pays, retries. Three error types only: `PaymentError`, `BudgetExceededError`, `NetworkError`. | `one-ie/one/packages/sdk/src/fetch.ts` (new); reuses 402 shape from `apps/one-core/backend/src/protocol/handlers/x402.ts` | unit: 402 → pay → retry → 200, mocked RPC; budget guard rejects when quote > maxSpendPerCall |
| 0.2 | **`createServer({ price, handler })` SDK wrapper** — one-knob monetized endpoint. Wraps existing `apps/one-core` middleware. Default treasury = ephemeral testnet wallet for the dev. | `one-ie/one/packages/sdk/src/server.ts` (new); thin wrapper over `apps/one-core/backend/src/x402.ts` | `npx self-earning-agent` exposes endpoint; `curl` returns 402 with correct `X-Payment-*` headers |
| 0.3 | **Trust ramp** — testnet by default, mainnet behind explicit flag | `packages/sdk/src/wallet.ts` (new); env `ONEIE_NETWORK=testnet\|mainnet` (default `testnet`); `--mainnet` CLI flag | first run on a clean machine spends 0 real $; `ONEIE_NETWORK=mainnet` required to spend real |
| 0.4 | **`self-paying-agent` repo** — buyer demo. README + minimal `index.ts` using `oneFetch()`. `npx self-paying-agent "summarize <url>"` works without setup. | `demo/self-paying-agent/` (scaffold here, extract to standalone repo at ship) | runs end-to-end against testnet `pay.one.ie`; output includes `→ paid $0.0X` line |
| 0.5 | **`self-earning-agent` repo** — seller demo. README + minimal `index.ts` using `createServer()`. `npx self-earning-agent` deploys + prints public URL + earnings tally. | `demo/self-earning-agent/` (scaffold here, extract to standalone repo at ship) | endpoint live, returns 402 unpaid, returns 200+result when paid; earnings counter increments |
| 0.6 | **60s recorded demo** — two terminals: earner deploys, buyer hits it, money moves. | video + READMEs link to it | clip shows full closed loop on testnet, no staged seeding |
| 0.7 | **First 10 closed-loop receipts** | `demo/receipts/*.json` pinned with on-chain links | 10 testnet receipts; each has both buyer + seller side recorded |

**Verify gate:**
```bash
bun run verify                                 # all tests green across SDK + demos
( cd demo/self-earning-agent && bun start ) & # terminal 1
sleep 2
( cd demo/self-paying-agent && bun run ) ;    # terminal 2 — paid call <3s p50
ls demo/receipts/*.json | wc -l               # >= 10
```

**Risks:**
- **Ephemeral wallet seed storage** — local file (`~/.oneie/dev-wallet`) is fine for testnet dev mode but must be explicit, not silent. Production agents go through PRF-wrapped owner flow per [`passkeys.md`](passkeys.md). Don't blur the line.
- **Sponsored-tx wiring** (read [`apps/enoki-play/src/routes/sponsored/`](apps/enoki-play/src/routes/sponsored/) first — shape only; sponsor Worker swaps for `EnokiClient`)
- **Receipt verification cache** (must be hash-gated 1-min per [`architecture.md`](architecture.md))
- **Auto-spend liability framing** — README copy must be unambiguous about testnet default + opt-in to mainnet. No surprise spends.

**Pheromone close:** `surface:x402-sdk:shipped` and `surface:closed-loop-demo:shipped` with `mode:lean`, `lifecycle:construction`, p50 ms attached.

---

### Wave 1 — Network effects (2–8 weeks)

> **Goal:** the network gets more useful as it grows. Names, visibility, federation, mainnet.

Each item is independently shippable. Order is by leverage, not dependency.

**Classifier per item:** mostly `mode: lean` (specs locked); one `mode: mixed` (heatmap UI variance unknown).

| # | Deliverable | Files | Verify |
| --- | --- | --- | --- |
| 1.1 | **SuiNS — human handles** (`tony.sui` → address + agent registry) | `one.ie/src/lib/suins/resolver.ts` (new); `/u/[handle].astro` lookup | `tony.sui` resolves on testnet → wallet page renders |
| 1.2 | **SuiNS — agent hierarchical names** (`creative.tony.sui`) | `one.ie/src/lib/suins/agent-names.ts` (new); `agents.move` extension | `npx oneie name claim creative` succeeds |
| 1.3 | **x402 gateway as first-class Worker** (extract from `apps/one-core`) | `one.ie/workers/x402-gateway/` (new) | independent deploy; routes 402 enforcement off main api worker |
| 1.4 | **Sui mainnet cutover** | Move package re-deploy; `wrangler.toml` mainnet vars; snapshot tooling | dry-run with $1 SUI; rollback plan documented; testnet receipts migrated |
| 1.5 | **Live pheromone heatmap on `/world`** | `one.ie/src/pages/world.astro` (existing); `src/components/Heatmap.tsx` (new) | streams from WsHub DO; <100ms tick latency |
| 1.6 | **GitHub federation README** (clone → deploy → join in 3 commands) | `one-ie/one/README.md` (existing — expand); `wrangler.toml.example` | a stranger deploys + federates with `one.ie` in <1 hour, solo |

**Order discipline:** 1.1, 1.3, 1.6 are independent — parallelizable. 1.5 needs 1.3 (gateway emits the events). 1.4 (mainnet) gated on Wave 0 + 1.1–1.3 green.

**Wave 1 verify gate:** the README in `one-ie/one/` walks a stranger from zero to a federated peer world running their own x402-paid skill, in under an hour. If they can't do it solo, the wave isn't done.

---

### Wave 2 — Sovereign storage + on-chain markets (2–6 months)

> **Goal:** remove every remaining centralized dependency. Walrus for blobs, Seal for TEE-backed key custody, DeepBook for skill price discovery.

Mostly `mode: full` — these introduce new physics (storage substrate change, market mechanism, hardware key custody).

| # | Deliverable | Mode | Files | Verify |
| --- | --- | --- | --- | --- |
| 2.1 | **Walrus blob storage** (replace R2 for sovereign agent memory) | full | `one.ie/src/lib/walrus/client.ts` (new); R2 bridge for fallback | agent memory survives R2 deletion; reads from Walrus |
| 2.2 | **Seal TEE key custody** (optional hardware-backed seed backup) | full | `one.ie/src/lib/seal/custody.ts` (new); passkey integration | seed restorable from Seal even with paper + biometric lost |
| 2.3 | **DeepBook integration** (on-chain skill price discovery) | full | Move additions; `one.ie/src/lib/deepbook/orderbook.ts` (new) | bid/ask for "translate" skill resolves through DeepBook |
| 2.4 | **Branded AI marketplace polish** | mixed | `one.ie/src/pages/{buy,sell}.astro` (existing — extend) | end-to-end branded AI flow with metrics dashboard |

**Risk:** these depend on Sui ecosystem maturity. If Walrus or Seal slip, fall back to R2 + paper + biometric for one more cycle. **Don't build half-Walrus.**

---

## Cross-cutting (every wave)

Health lines, not deliverables.

| Concern | What | Where |
| --- | --- | --- |
| **Threat model** | Every new surface adds a row. No surface ships until its row holds. | [`mac.md`](mac.md), [`agents.md`](agents.md), per-spec |
| **Speed budget** | `/speed` measures p50/p95 on every shipped surface. Regress >20% → revert. | `.claude/skills/speed/` |
| **Verification > presence** | Canary decrypts (vault), canary txs (Sui), canary reconciliation (TypeDB ↔ Sui bridge). "File exists" is theater. | `one.ie/src/lib/canaries/` |
| **Rule files** | Closed loop, structural time, deterministic results — locked. Every PR honors them. | `one.ie/.claude/rules/engine.md` |
| **Doc-code sync** | When a plan changes, the author reconciles dependent plans in the same commit. No drift. | root `*.md` ↔ `one.ie/` paths |

---

## Definition of done (per wave)

A wave closes when **all five** are green:

1. ✅ **Verify gate passes** — the bash command in the wave's verify column returns 0
2. ✅ **Speed budget met** — `/speed` reports p50 within target
3. ✅ **Threat model holds** — every new surface has a threat row that still defends what it claims
4. ✅ **Pheromone marked** — `surface:{name}:shipped` emitted with `mode:` and `lifecycle:` tags
5. ✅ **Architecture.md updated** — status flips ☐ → ✓ in [`architecture.md`](architecture.md), with file paths cited

If any one is red, the wave is *not* done. Reconcile, then close.

---

## Anti-patterns (don't do these)

- ❌ **Marketing this as "agent payments" or "blockchain APIs".** The hook is *"use any API without API keys or subscriptions."* Payment is the means; key-free composable APIs is the felt value. If devs see "crypto" first, you lose them.
- ❌ **Mainnet by default.** Surprise auto-spends on `npm install` are a trust cliff. Testnet default; mainnet behind explicit flag. Always.
- ❌ **One-sided demo.** Buyer-only is Stripe-for-APIs. Seller-only is Gumroad. The closed loop (both repos, money moves) is the unsee-able moment. Don't ship one without the other.
- ❌ **Building a new x402 server.** It exists at `apps/one-core/backend/src/x402.ts`, in production. `createServer()` wraps; it does not replace.
- ❌ **Blurring ephemeral dev wallets with PRF-wrapped production wallets.** Local-file dev seed is fine for `oneFetch()` in testnet mode. Production agents go through the owner-PRF flow. Don't conflate them in code or docs.
- ❌ **Building Wave 2 before Wave 0 ships.** The first autonomous paid call is the unlock; everything compounds on it.
- ❌ **New top-level root `*.md`.** Cluster is near-saturated (12 files). Extend existing specs.
- ❌ **Mocked database in tests.** Real TypeDB or skip (prior incident; see [`CLAUDE.md`](CLAUDE.md)).
- ❌ **Half-Walrus / half-Seal.** Ship fully or fall back. Half-finished sovereignty is worse than honest centralization.
- ❌ **Greenfield sponsored-tx work.** Read [`apps/enoki-play/src/routes/sponsored/`](apps/enoki-play/src/routes/sponsored/) first — shape is verbatim, only the sponsor swaps.
- ❌ **Skipping hooks** (`--no-verify`, `--no-gpg-sign`) unless explicitly asked.
- ❌ **Suggesting third-party password managers.** SE-rooted setup is load-bearing across `mac.md`, `secrets.md`, `passkeys.md`.

---

## How to start a wave

1. **Confirm the wedge** (Wave 0 only) — one user, one funnel
2. Pick one item from the wave's deliverable table
3. Run the classifier ([`one.ie/one/template-plan.md`](one.ie/one/template-plan.md) §0)
4. If `mode: lean` → embed a 5-section plan in the owning spec doc (goal / speed / tasks / verify / close)
5. If `mode: full` or `mixed` → write the recon-first plan in `one.ie/one/`
6. Spawn agents per file, with the spec slice + rule-file links
7. Verify → close → mark pheromone → flip ☐ to ✓ in [`architecture.md`](architecture.md)
8. Next item

---

## Reading order — to actually start building

1. **This doc** (you're here) — the wave plan
2. [`architecture.md`](architecture.md) — what each layer is, what's shipped vs planned
3. [`apps/one-core/CLAUDE.md`](apps/one-core/CLAUDE.md) — the existing x402 implementation you're wiring into
4. [`one.ie/CLAUDE.md`](one.ie/CLAUDE.md) — codebase brief, path aliases, deploy pipeline
5. [`one.ie/one/template-plan.md`](one.ie/one/template-plan.md) §0 — classifier + lifecycle defaults
6. The spec doc for whichever item you picked (e.g., [`passkeys.md`](passkeys.md), [`agents.md`](agents.md), [`chat.md`](chat.md))

---

*Three waves. Two paired demo repos. One closed loop. Wrap the existing `apps/one-core` x402 server in `oneFetch()` and `createServer()`. Testnet default. Money moves between two terminals in 60 seconds. Each wave compounds. Spec is immutable during build. Pheromone marks every close. Architecture.md is the score.*
