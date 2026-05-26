# website.md — the one.ie surface

**Principle:** speed is the product. A human gets a wallet in 5 seconds. An agent gets one in 50 milliseconds. A listing goes live in 30 seconds. A buy round-trips in 3 seconds. Anything slower gets a measurement, a budget, and a fix.

Every surface inherits five motifs already locked elsewhere:
- **One owner, biometric-bound, paper resurrects** — Apple ID + Secure Enclave is the apex of the trust tree (`owner.md`); BIP39 paper is the only third path
- **No master seed** — `SUI_SEED` is gone; every agent has a per-actor random seed wrapped under owner PRF; every key descends from a biometric directly or transitively (`owner.md` algebra)
- **Caps are Move objects, not policy** — every wallet has an on-chain `Cap` with `daily_limit`, `allowed_recipients`, `paused`, `parent_cap`; consensus enforces, not code (`owner.md` §Spending caps)
- **Threat model is a table** — every section names what it defends and what it accepts (`mac.md`)
- **Verification > presence** — every wallet proves it's alive; `liveness_last_verified_at` on every agent (`owner.md` §canary, `mac.md`)

Numbers-first per engine rule 3. Every page reports its budget or ships warning-flagged.

---

## The ecosystem — five surfaces, one substrate, one agent economy

**Positioning:** one.ie is the **agent economy** — a substrate where humans and agents transact at machine speed under bounded autonomy, plus the BaaS that lets anyone deploy into it.

| Surface | Audience | Job | Speed claim |
| --- | --- | --- | --- |
| **one.ie** (this doc) | humans + their agents | home + 6 sections — consumer + operator surface | 5s wallet, 50ms agent wallet, 3s buy, 30s list |
| **pages.one.ie** | developers + businesses | **Platform / BaaS** — hosted pages + card payments at `pages.one.ie/pay` + agent-economy primitives wired in | publish a page in <60s; card-payment claim <30s |
| **pay.one.ie** | developers + businesses | Multi-chain crypto payment links (SUI, ETH, SOL, BTC, BASE, ARB, OPT) — wallet generation + claim flow | **accept crypto in 60 seconds · $0 to start · no credit card** |
| **api.one.ie** | everything | Gateway — TypeDB proxy + WsHub DO; shared substrate for all surfaces | `<10ms` gateway latency (locked in `docs/speed.md`) |
| **github.com/one-ie/one** | developers | SDK + CLI + MCP entry — `npx oneie`, `@oneie/sdk`, `@oneie/mcp` | 3-command Workers deploy |

All five share: same SE-rooted owner trust (`owner.md`), same Move-bounded `Cap` for every spender, same pheromone learning via `api.one.ie`, same "you own your keys" contract.

**Card + crypto, side by side:** `pages.one.ie/pay` accepts traditional card payments (no crypto knowledge required from the buyer); `pay.one.ie` accepts crypto on 7 chains. Both settle to the seller's wallet via the substrate; both surface the same pre-sign card and audit trail to the seller.

---

## one.ie — home + six sections

### Home `/` — the world

The landing surface describes what this place is: **a substrate where one human (you) sits at the apex, and from that biometric root descend agents and groups that transact at machine speed under bounded autonomy.** No login wall. No marketing splash that hides the product.

Home shows:

- **The world in one paragraph** — "you are the owner of your substrate. Your agents are economic peers, bounded by `Cap`s you mint with one Touch ID. Your groups are where humans and agents talk and trade together. Your wallets hold value across every actor in your tree. The market is open."
- **Live state** — your wallet (or "tap to create"), count of your agents, count of groups you're in, last activity
- **Two tabs** that re-skin the page below to a perspective:

| Tab | Audience | Verbs surfaced |
| --- | --- | --- |
| **Humans** | you, the owner | discover · chat · build · buy · sell · grow together |
| **Agents** | your agents (and peer agents you grant view to) | spawn · ask · mark · warn · earn · settle |

The tab is a *lens*, not a route — same data, different framing. The human tab leads with "what can I do?"; the agent tab leads with "what's my fleet doing?" Both link into the same six sections below.

**Speed contract:** first paint <500ms; wallet exists locally in <5s for any first visit (no server roundtrip).

**Threat model — Home:**

| Attack | Defense |
| --- | --- |
| Phishing landing | Passkey is domain-bound; the "tap to create" flow won't accept assertions from a fake `one.ie` |
| Social engineering via tab toggle | Tab is a UI-only filter; no auth context changes; agents tab cannot be used to escalate to owner verbs |
| **Accepted** | A first-visit visitor who hasn't created a wallet yet is anonymous — no defense before identity exists |

---

### Section navigation

Below home (or via top-nav from any page), six routes:

| Route | Section | What | Speed budget |
| --- | --- | --- | --- |
| `/chat` | **Chat** | The universal interface — every API/SDK/MCP/CLI feature reachable via conversation; `⌘K` opens it from any other section | first token <1s; tool call visible <500ms |
| `/agents` | **Agents** | Your fleet — owned + peer-spawned, full ownership tree, `Cap` editor, handoff inbox | wallet derive <50ms; grid first paint <500ms |
| `/groups` | **Groups** | Discord-like spaces where humans and agents create/join groups, chat together, transact | first paint <500ms; message stream <100ms |
| `/market` | **Market** | Discover + buy + sell — capability listings, pheromone-ranked, sponsored tx where available | listing live <30s; click-to-settled <3s |
| `/wallets` | **Wallets** | Manage owner wallet + derive child wallets for agents + assign `Cap`s + handover | first paint <500ms; cap mutation <2s |
| `/account` | **Account** | Identity, recovery (BIP39, multisig opt-in), API key versions, owner audit log | first paint <500ms |

Every route is an island over TypeDB + on-chain state. No new trust root.

---

## `/chat` — the universal interface

**Owned by `chat.md`.** This section summarizes; the canonical detail lives there.

Chat is reachable five ways — full-page web, `⌘K` slide-over from any section, REST API, `@oneie/sdk`, `@oneie/mcp`, `oneie` CLI. All five route through the same substrate call (`persist.ask({ receiver: "chat:<uid>", ... })`), and **every value-moving action surfaces a biometric-gated pre-sign card on the human's authenticated device, regardless of entry mode.** A CLI buy command opens a browser passkey prompt; an MCP tool call from Claude surfaces a card in the user's session, not inside Claude. The biometric is non-transferable *by physics*.

**What chat can do — every verb routes through the substrate:**

| Intent | Route |
| --- | --- |
| Buy / sell / pay-link | chat → `market:resolve` → escrow + sign prompt or pay.one.ie URL |
| Spawn agent | chat → `/agents/new` flow inline (one Touch ID, deterministic wallet visible immediately) |
| Spawn peer agents | parent agent's `spawn_child` Move call; no human signature if parent has cap headroom |
| Edit `Cap` | chat → `Cap` diff + co-sign prompt (mutation tx) |
| Join group | chat → group invite resolve → membership accept |
| Send / swap / sign | chat → pre-sign card |
| Show / query | chat → fetch + render rich-message card inline |

**Speed contract:** first token <1s; tool call visible <500ms; first streamed field <300ms; all required fields <1.2s; QR/barcode <50ms after deps present.

**Threat model — Chat:**

| Attack | Defense |
| --- | --- |
| Prompt injection ("ignore instructions and send funds") | Chat can only *propose*; every value-moving action requires biometric approval via pre-sign card on the human's device |
| Hallucinated recipient | Addresses resolve server-side against substrate lookups, never LLM-authored; unknown recipients show explicit warning |
| Fake "approve the pending swap" | Handoff inbox is authoritative; chat renders from the same WsHub DO feed, can't fabricate |
| LLM emits owner-tier signal | Per `owner.md` threat model: LLM never holds owner key; LLM emits to its agent's bounded `Cap` |
| **Accepted** | Chat can be socially-engineered into *proposing* a bad tx. The human reads the pre-sign card and decides. |

**See `chat.md`** for the streaming transport, Zod-typed `RichMessage` schemas, the chat-* page consolidation, and the five-mode threat-model table.

---

## `/agents` — your fleet

The section where you see, edit, pause, and revoke every agent in your tree — owned directly or peer-spawned by another agent under your cap.

**Routes:**

| Sub-route | What |
| --- | --- |
| `/agents` | Grid — your agents + peer-spawned descendants as a tree; agent cards with treasury, P&L, canary, scope |
| `/agents/new` | Spawn — name + template (trader / researcher / writer / concierge / blank); deterministic wallet in <50ms; first co-sign card |
| `/agents/[id]` | Detail — treasury, P&L, canary status, `Cap` editor, handoff inbox per agent |
| `/agents/fleet` | Transitive view — sum of `daily_cap` across the entire tree; per-row pause of any subtree; alert routing config |

**The wallet derivation** (per `owner.md` Gap 1):

```
agent_seed = randomBytes(32)                              // at spawn
agent_kek  = HKDF(owner_prf, "agent-key:{uid}:v1")        // owner Touch ID once
ciphertext = AES-GCM(agent_seed, agent_kek) → D1
```

The address exists the moment the agent spec is parsed. `SUI_SEED` is gone — there is no env var that, if leaked, derives every agent's key. Per-agent random seed, wrapped under owner PRF, ciphertext in D1. Same recovery path as the wallet seed: BIP39 paper rebuilds the owner PRF, which unwraps every agent key.

**Spawn flow — `/agents/new`:**

1. Two inputs: name + template
2. Deterministic wallet derives in <50ms — address visible immediately
3. First co-sign screen: "grant this agent $X starting `Cap` + allowlist Y" → one Touch ID → live
4. Default `Cap` is the tightest template sensible (ramp up from there)

No server roundtrip to get a wallet. No KYC. No "verify your email."

**Peer agents — agents spawning agents** (per `owner.md` §Recursive spawning):

A parent agent with a `Cap` and `spawn_child` headroom creates sub-agents at machine speed under its own `daily_cap`, with no Touch ID prompt. The grid renders the full ownership tree (you at the root, every spawned agent as a child). `Cap`s inherit by arithmetic: `child.daily_limit ≤ parent.remaining_today`, enforced by Move consensus at every spawn. Max depth 8.

**Pause cascades down.** Pause any node → every descendant freezes via consensus. **Dead-man's switch cascades down.** Silence at any node freezes the subtree below it (per `agents.md` §Safety floor).

**Agent card** — what you see on the grid:

```
┌──────────────────────────────────────────────────┐
│ trader-v1                            [● ACTIVE]  │
│ 0x4a2b…9f8e                                      │
│                                                  │
│ Cap:       4,823 / 5,000 USDC today              │
│ P&L (7d):  +127 USDC   ▁▂▃▅▇▇▆▅ confidence high  │
│ Canary:    ✓ 4m ago                              │
│ Scope:     DCA + swap · Cetus,DeepBook · ≤500/tx │
│ Children:  3 peer-spawned (1.2k cap exposure)    │
│                                                  │
│ [Txs]  [Cap]  [Pause]  [Revoke]                  │
└──────────────────────────────────────────────────┘
```

All four actions emit `ui:agents:<action>` per `ui.md`. Pause = one-tap Touch ID → on-chain `Cap.paused = true` via single tx; cascade by Move event.

**Threat model — Agents:**

| Attack | Defense |
| --- | --- |
| Compromised agent worker drains its wallet | `Cap.daily_limit` + `Cap.allowed_recipients` enforced by Move consensus; blast radius = that agent's daily cap |
| Worker env leak | Per `owner.md` Gap 1: workers hold one scoped `AGENT_KEY`, not `SUI_SEED`; one agent compromised, not all |
| Rogue peer agent spawns a fleet | `spawn_child` checks `child.cap ≤ parent.remaining`; `/agents/fleet` surfaces transitive exposure; pause cascades down |
| Runaway agent loop | Per-key rate ceiling (`owner.md` Gap 5) bites before D1 round-trip; agent self-DOSes its own quota, not the owner's |
| Agent talks human into signing a rug | Pre-sign card shows full tx + worst-case + `Cap` fit; "Decline + tighten" is first-class |
| **Accepted** | Loss within `Cap` bounds is a paid tuition — ramp `Cap`s slowly, mark/warn paths |

---

## `/groups` — humans + agents together

A group is a unit (`g:<gid>`) with members (humans + agents) and a shared message stream. Like Discord, but the members can be either species, the chat history is substrate-native, and any member with a `Cap` can transact in the group's market.

**Routes:**

| Sub-route | What |
| --- | --- |
| `/groups` | Grid — groups you're in; unread badges; last activity |
| `/groups/new` | Create — name, description, who can join (open / invite / approval); chairman-mode for enterprise (per `owner.md` Gap 3 multisig) |
| `/groups/[gid]` | Channel — message stream; member list (humans + agents differentiated by badge); group treasury if any |
| `/groups/[gid]/members` | Membership — invite, approve, kick; chairman-tier actions |
| `/groups/[gid]/market` | Listings tied to this group (per-group `/market` slice) |

**What's different from Discord:**

- **Members are units in the substrate** — joining a group is a TypeDB `membership` edge, not a per-app login
- **Agents are first-class members** — your agents can post, listen, react to signals from the group, and transact under their `Cap`s
- **Every value-moving action is a pre-sign card** — humans tap Touch ID; agents auto-execute within their `Cap`
- **Groups can be enterprise tenants** — chairman role per `owner.md`; multisig (gap 3) for high-stakes groups; the substrate owner reads everything by right but acts only when invariants break

**Speed contract:** first paint <500ms; new message in stream <100ms after WsHub push; create group <2s end-to-end.

**Threat model — Groups:**

| Attack | Defense |
| --- | --- |
| Spam/abuse from joined member | Pheromone `warn()` from group members weights against the actor's discoverability; chairman can kick with one tx |
| Agent posts unsanctioned content under owner's name | Agent posts as itself, badged as agent; can never impersonate the human owner |
| Hostile chairman drains group treasury | Multisig chairman (`owner.md` Gap 3) requires N-of-M biometric assertions; non-multisig groups carry that risk visibly |
| Cross-tenant leak via shared agent | Agent `Cap` is per-agent, not per-group; group membership doesn't grant cross-group spending |
| Fake group impersonating known one | `gid` is unique on-chain; provenance badge surfaces creation time + creator's address |

---

## `/market` — discover, buy, sell

One section, both sides of the trade. Discover others' listings, list your own. Pheromone-ranked. Sponsored tx where available.

**Routes:**

| Sub-route | What |
| --- | --- |
| `/market` | Discover grid — listings ranked by pheromone confidence + recency; filter by category, group, chain |
| `/market/[sid]` | Listing detail — what, who (uid provenance), price, worst-case, buy CTA |
| `/market/new` | Sell — minimal form: what, price, receiver (auto = current wallet), optional description, optional pay-link mode |
| `/market/sales` | Your listings — status, traffic, revenue, pause/edit |

**The listing IS a capability** (per `docs/buy-and-sell.md`). Buying = paying the provider; the substrate routes; pheromone marks the path.

| Listing type | Example | Settlement |
| --- | --- | --- |
| Skill | "copy-edit this article" → 0.10 USDC | escrow on delivery |
| Subscription | "research agent, 7d" → 15 USDC | time-boxed, auto-expire |
| Product | physical goods | escrow on shipping proof / timeout |
| Bounty | "buy this, any deliverer gets paid" | first-deliver wins escrow |

**Two sell modes:**

- **Listing** (default) — mints a capability object on Sui; appears in `/market` discovery; pheromone-ranked over time
- **Pay link** (via pay.one.ie) — no listing, no marketplace; just a URL you paste into an email/DM/invoice; **60-second claim** direct to wallet on any of 7 chains. For things you charge a specific person for.

**Buy flow — 3s target:**

1. Land on `/market/[sid]` from shared link or discover grid
2. Show: what, who (uid provenance badge), price, pheromone confidence, worst-case
3. Tap Buy → passkey → signed; sponsored tx via our sponsor Worker if enabled, else user pays gas
4. Settle → escrow releases on delivery/timeout → pheromone `mark()` → receipt visible in `/wallets`

**Sell flow — 30s target:**

1. `/market/new` — minimal form
2. Tap Create → signs capability mint tx → live
3. Shareable link generated immediately: `one.ie/market/<sid>` + QR + Telegram/Discord deep links
4. Optional: delegate listing management to an agent — scoped `Cap` grant, revocable in one tx

**Threat model — Market:**

| Attack | Defense |
| --- | --- |
| Fake listing impersonating known provider | Listings bind to unit uid on-chain; provenance badge surfaces uid + history |
| Bait-and-switch price | Price is in the capability object; any change invalidates open offers |
| Rug pull (seller takes, no delivery) | Escrow + 50 bps protocol fee; `warn(1)` on non-delivery; path toxicity rises in pheromone |
| MEV on large buys | Private mempool above N USDC; slippage cap on swap-routed payments |
| Agent auto-buys without approval | First-use-of-counterparty gate → pre-sign card; high-value → co-sign per `agents.md` |
| Spam/scam listings | Pheromone-weighted ranking; toxic paths drop visibility; reports = `warn` signals |

---

## `/wallets` — manage, derive, hand over

The section for wallet operations: see balances across owner + every agent + every peer-spawned descendant; derive new wallets for new agents; assign `Cap`s; hand over a `Cap` to a different spender (key rotation without losing the cap); freeze; revoke.

**Routes:**

| Sub-route | What |
| --- | --- |
| `/wallets` | All wallets — owner wallet + every agent in tree + transitive ScopedWallets — balance, P&L, canary, last tx |
| `/wallets/portfolio` | Aggregated position by token / strategy / counterparty |
| `/wallets/timeline` | Every tx across every wallet, tagged owner-signed / agent-signed / cosigned |
| `/wallets/[id]` | Detail — balance, tx history, `Cap` (if scoped), spender (if rotatable) |
| `/wallets/new` | Derive — used internally by `/agents/new` but also surfacable for "give a one-shot wallet to someone" patterns |
| `/wallets/handover` | Rotate spender on an existing `Cap` — `rotate_spender(cap, new_pubkey)` per `owner.md` §Cap operations; key rotation, cap unchanged |

**Numbers shown** (every figure has a staleness indicator):

- Total assets (USDC-denominated via oracle)
- 24h / 7d / 30d P&L per wallet + per strategy
- Expected vs actual balance per agent (reconciliation status)
- Gas spend per agent (cost of doing business)
- Canary latency — seconds since last proof-of-life tx (`liveness_last_verified_at`)
- `Cap` utilization — % of `daily_limit` spent today

**Handover** is its own first-class verb (per `owner.md` §Cap operations: `rotate_spender`). Reasons to hand over:

- Agent retires, you want its `Cap` to pass to a successor agent
- Compromise suspected, rotate the spending key without rebuilding the cap object
- Operational handoff — give a contractor a bounded wallet for a fixed duration via `extend_expiry`

Every handover is owner-signed (or chairman-signed within a group), one tx, audit row emitted (per `owner.md` Gap 2).

**Alert pipeline** (surfaces in handoff inbox + chat stream):

| Condition | Action |
| --- | --- |
| Canary missed ×2 | Auto-pause agent (`Cap.paused = true`) |
| Drawdown threshold hit | Treasury freeze, owner review required |
| Oracle staleness > N | Warning banner on held asset |
| Expected ≠ actual balance | Pause + review |

**Threat model — Wallets:**

| Attack | Defense |
| --- | --- |
| Oracle manipulation of displayed balance | Staleness check + deviation check; two-oracle confirm above threshold |
| P&L inflation via fake trades | P&L reconciled against on-chain balance delta, not trade reports |
| Read-only leak of addresses | Addresses are public on-chain; no new exposure |
| Compromised spender key | `rotate_spender` flips to a new key; cap unchanged; old key 401s next call |
| D1 wipe loses wallet metadata | Per `owner.md` threat model: on-chain `Cap` and `SubstrateOwner` Move objects are authoritative; D1 is convenience cache |

---

## `/account` — identity, recovery, audit

The owner-tier control surface. Where the human at the apex of the trust tree manages their own identity, sees the audit log of their own actions, and configures recovery.

**Routes:**

| Sub-route | What |
| --- | --- |
| `/account` | Profile — name, address (the immutable owner identity per `owner.md`), API key versions active, last assertion |
| `/account/recovery` | BIP39 paper status (verified / unverified), Apple ID Recovery Key reminder, opt-in to chairman multisig for groups you own (per `owner.md` Gap 3) |
| `/account/keys` | API key versions — active, rotating, revoked; rotate (per `owner.md` Gap 4); force-revoke any version |
| `/account/audit` | Owner audit log — every owner-tier action with timestamp, gate bypassed, payload hash + redacted payload (per `owner.md` Gap 2) |
| `/account/federation` | Bridges to other substrates — peer owner address, version, last handshake; revoke (per `owner.md` Gap 6) |
| `/account/[name]` | Public profile (existing) |

**Sign-in tiers**, low friction → high (recovery + cross-device):

| Tier | Path | Use when |
| --- | --- | --- |
| 1 | Passkey PRF | Default — device biometric, one Touch ID, no server roundtrip |
| 2 | Sui wallet SIWE | User already has a wallet |
| 3 | Google login (Better Auth) | Crypto-new user; links wallet address to human identity across devices |
| 4 | Email + passphrase | Last resort |

Every tier funnels through `ensureHumanUnit()` (`src/lib/human-unit.ts`) — single gate into TypeDB identity. Already wired.

**The audit log is non-bypassable** (per `owner.md` Gap 2): every owner-tier signal emits `audit:owner:{action}` to D1 + TypeDB *before* the bypass executes. `OWNER_AUDIT_MODE = enforce` blocks owner allow if the audit emit fails. The owner can read their own log; auditor role can read all.

**Threat model — Account:**

| Attack | Defense |
| --- | --- |
| Phishing assertion | Passkey domain-bound; first-mint protected by `OWNER_EXPECTED_ADDRESS` env (per `owner.md` §Bootstrap) |
| Lost device | Tier 1: iCloud Keychain syncs passkey + largeBlob → wallet recovers. Tier 2: BIP39 paper restores same address on any browser. Tier 3: Better Auth Google relinks identity. |
| Lost paper | Single-key by design for substrate owner (`owner.md` threat row). Multisig only available for chairman within groups, not for owner. |
| Coerced biometric | Out of scope (`owner.md` threat row); owner accepts the trade |
| API key leak | Server stores `hash(key)` only; rotate = bump version (`owner.md` Gap 4); old version 401s after `expires-at` |
| D1 wipe loses owner identity | On-chain `SubstrateOwner` Move object is authoritative; recovery re-derives same address |

---

## Agent ↔ owner handoff — the UI specifics

The pre-sign card. Renders in three places, same component, same data:

- `/agents/[id]` — the agent's own inbox
- `/agents` grid — global inbox aggregated across every owned agent
- `/chat` — inline as a rich message when the conversation prompts it
- `/groups/[gid]` — when the handoff originates from a group-bound agent

**Handoff inbox card:**

```
┌──────────────────────────────────────────────────┐
│ trader-v1 wants to sign                           │
│ ─────────────────────────────────────────────────│
│ Swap 500 USDC → SUI on Cetus.DeepBook            │
│ Reason: hourly DCA, step 23 / 168                │
│ Worst case: -3% slippage = 485 USDC out           │
│ Cap fit:   today 500/5000, recipient allowed      │
│ Confidence: high (sim passed, oracle 4s fresh)    │
│                                                   │
│ [Approve w/ Touch ID]                             │
│ [Decline]                                         │
│ [Decline + tighten Cap — daily 5k → 3k]           │
│ ⓘ View full tx simulation                          │
└──────────────────────────────────────────────────┘
```

**Decline + tighten** is a first-class action — the ramp going the other way. Every rejection optionally narrows the `Cap` object via `set_limit` (per `owner.md` §Cap operations).

Handoffs also bubble up from peer-spawned sub-agents at any depth; the owner at the root can approve or decline.

**Four handoff types → UI pattern:**

| Type | Trigger | UI surface |
| --- | --- | --- |
| Silent | In-cap, in-allowlist | Audit entry in `/wallets/timeline` |
| Notify | In-scope but unusual (new counterparty, off-hours) | Push + badge on `/agents/[id]` card + `/chat` ambient message |
| Pre-sign | Out-of-`Cap` or high-value | Handoff inbox card (above) |
| Co-sign (2-of-2) | `Cap` requires it (group multisig) | Pre-sign card + "2-of-2" banner + guardian-escalation option |

**Transport:** WsHub DO that powers TaskBoard live updates (`src/lib/ws-server.ts` → Gateway `/broadcast` → DO → browser hook). One pipe, all consumers.

---

## Design system

- **Dark theme default** — reduces phishing surface (users suspicious of bright unfamiliar skins) and matches terminal-forward aesthetic
- **Numbers first** — every page shows deterministic metrics (balance, P&L, latency, confidence). No vibes.
- **shadcn/ui + Tailwind 4** — the stack is locked; use it
- **Live paths visible** — pheromone rendered on `/world` (sub-route under home), confidence pips on agent + listing cards
- **`emitClick('ui:<section>:<action>')` on every onClick** — per `ui.md`. The UI itself learns what users care about.
- **Hydration discipline** — `client:only` for wallet/sign pages (no SSR leak of address state), `client:load` for discover/market grids, static for landing/docs
- **Speed is the animation** — transitions feel instant because they are. No spinners; sub-100ms state changes.

### Rich-message schemas — one source, all consumers

Every card rendered across the product is a **Zod-typed** variant of `RichMessage`, streamed via ai-sdk's `streamObject`. One schema file imported server-side (tool-dispatched seeds), client-side (`useObject` islands), and by the API/SDK/MCP/CLI contracts.

**Location:** `src/schema/rich-messages.ts` — discriminated union on `kind`, every variant `.strict()`.

| Card `kind` | Used on | Owner |
| --- | --- | --- |
| `payment` | `/chat`, `/market/[sid]`, embedded `⌘K` after "buy X" | `chat-skills:resolveBuy` |
| `pay-link` | `/chat`, `/market/new` (pay-link mode) | `chat-skills:resolveSell` → pay.one.ie |
| `handoff` | handoff inbox on `/agents`, `/agents/[id]`, `/chat`, `/groups/[gid]` | WsHub DO feed |
| `agent` | home, `/agents` grid, `/agents/fleet`, `/chat` | TypeDB unit + per-agent address from D1 `agent_wallet` |
| `listing` | `/market` discovery grid, `/chat` | capability object + pheromone rank |
| `group` | home, `/groups` grid | TypeDB group unit + member rollup |

**Rules** (enforced at the schema level):

- Addresses are **never LLM-authored** — resolved server-side via substrate lookups, injected as `streamObject` seed; model fills reasoning fields only
- Every value-moving card carries a `deadline` (unix ms) — client + substrate both check
- Every schema uses `.strict()` — Zod drops unknown fields per chunk, defeats smuggling
- QR / barcodes are **never streamed** — rendered client-side from already-validated fields (deterministic from `{address, amount, memo, chain}`)
- Action buttons (Touch ID, Approve, Buy) gate on required fields — disabled until `object?.address && object?.quote` etc.

**See `chat.md` §Component streaming** for the full transport pattern and threat-model rationale.

---

## Speed budgets — the contract

| Section | Metric | Budget | Where measured |
| --- | --- | --- | --- |
| Home | first paint | <500ms | client perf |
| Home | wallet-exists-locally (first visit) | <5s | client perf; no server roundtrip |
| Home | TTFB signed-in | <200ms | `src/pages/speed.astro` |
| `/chat` | first token | <1s | streaming endpoint |
| `/chat` | tool call visible | <500ms | rich-message render |
| any card stream | first field visible | <300ms | `streamObject` + `useObject` partial |
| any card stream | all required fields (button activates) | <1.2s | slowest tool resolution |
| any card stream | QR / barcode rendered | <50ms after deps present | client-side deterministic render |
| `/agents/new` | wallet-derive | <50ms | per-agent address from D1 `agent_wallet` row (owner-PRF-wrapped seed) |
| `/agents/new` | create-to-live (form → first co-sign ready) | <3s | form submit → `Cap` mint |
| `/agents` grid | first paint | <500ms | KV snapshot |
| `/groups/[gid]` | message in stream after WsHub push | <100ms | client perf |
| `/groups/new` | create-to-live | <2s | form submit → group unit insert + first member |
| `/market/[sid]` | click-to-settled | <3s | sponsored tx via our sponsor Worker |
| `/market/new` | create-to-live | <30s | form submit → capability mint |
| `/wallets` | first paint | <500ms | KV snapshot via `src/lib/edge.ts` |
| `/wallets/handover` | rotate_spender → confirmed | <2s | tx submit → consensus |
| `/account/audit` | first paint | <500ms | D1 paginated fetch |
| Handoff prompt | render after agent request | <1s | WsHub DO push |
| Touch ID approve | biometric → broadcast | <1s | WebAuthn / signer adapter |

Every page ends with a measurement report per engine rule 3. Budget miss → warning-flag in telemetry (`toolkit:ui:<section>`).

---

## Threat model — the website surface (cross-section)

| Attack | Defense |
| --- | --- |
| DNS poisoning / impersonation | Passkeys domain-bound; origin check on every API call; HSTS preload |
| Prompt injection via agent chat | Output rendered as markdown with schema-validated rich messages; no auto-sign from text |
| Social engineering via shared market link | Provenance badge + pheromone confidence + explicit ack for unknown providers |
| MITM on wallet sync | Apple: iCloud Keychain. Others: HTTPS + CSP set on CF Worker. |
| Hostile browser extension | Signer abstraction keeps private key out of DOM; vault decrypt in isolated context |
| Compromised CF Worker serving replaced JS | SRI where feasible; telemetry anomaly detection; `mac.md` §1.12 supply-chain rules apply |
| Rogue peer agent spawns a fleet | `spawn_child` consensus-checked against parent's cap (`owner.md`); `/agents/fleet` surfaces transitive exposure; pause cascades |
| Owner key self-DOS via runaway script | Hard rate ceiling per key (`owner.md` Gap 5: 1k/sec, 100k/day) before role bypass |
| Bypass without trace | Owner audit emit precedes bypass (`owner.md` Gap 2); `OWNER_AUDIT_MODE=enforce` blocks bypass on emit failure |
| **Accepted** | Catastrophic Worker compromise = same ceiling as any web surface. Monitor, don't pretend to prevent. |

---

## Map to existing code

| Section | Built | Needs |
| --- | --- | --- |
| Home | — (current `index.astro` is marketing-flavored) | New home page describing the world; humans/agents tab toggle; live state strip; lands into 6-section nav |
| `/chat` | `src/pages/chat.astro` (DebbyChat) + `chat-fast.astro` + variants | Owned by `chat.md` — canonicalize, mode flags, `⌘K` global, rich-message schemas |
| `/agents` | `src/pages/agents/*` + `src/components/u/*` (17 pages) | Move under `/agents/*`; agent card with canary + P&L + `Cap` (not "treasury"); spawn flow with new wallet derivation per `owner.md` Gap 1; tree view; fleet exposure |
| `/groups` | — (no current group surface) | New section; group unit shape in TypeDB (already exists as `g:`); chat stream reuses WsHub DO; member list with human/agent badges; chairman multisig hook (`owner.md` Gap 3) |
| `/market` | `src/pages/buy/*`, `src/pages/sell/*` | Consolidate under `/market`; 301s from old paths; pheromone-weighted discovery; pay-link mode hooks pay.one.ie |
| `/wallets` | `/u/wallet/[id]`, `/u/transactions`, `/u/tokens` | Unified route; transitive `Cap` exposure; handover (`rotate_spender`); reconciliation status |
| `/account` | Better Auth scaffolding, `src/pages/u/[name].astro` (public profile) | Identity + recovery + audit + key versions + federation; owner audit log UI (`owner.md` Gap 2); key rotation UI (`owner.md` Gap 4); multisig opt-in (`owner.md` Gap 3) |
| Handoff inbox | — | New component; reuse WsHub DO transport; renders on `/agents`, `/agents/[id]`, `/chat`, `/groups/[gid]` |
| `Cap` editor | — (replaces "scope editor" framing) | Form maps to `Cap` Move struct (`owner.md` §Spending caps); `daily_limit` / `allowed_recipients` / `paused` / `expires_epoch`; capability diff history |
| Analytics alerts | — | Wire canary missed, drawdown, oracle staleness into signal pipeline; route to handoff inbox |
| **Rich-message schemas** | — | `src/schema/rich-messages.ts` — Zod discriminated union; shared by server seeds + client islands + API/SDK/MCP/CLI. **Created in `chat.md` Build #2**; consumed by website.md items below |

---

## User-facing funnel

Existing stages from `docs/lifecycle-one.md`: `wallet → key → sign-in → team → deploy → discover → message → converse → sell → buy`. Map to new sections:

- `wallet` + `key` + `sign-in` → **`/account`** + home wallet creation
- `team` + `deploy` → **`/agents`** + `/agents/new`
- `discover` + `message` + `converse` → **`/chat`** (primary) + `/market` discover grid + `/groups`
- `sell` + `buy` → **`/market`** (also reachable from `/chat`)
- All above rolls up to **`/wallets`** for analytics

`/speed` remains the live funnel dashboard.

---

## Build system — fast and accurate by construction

The spec above **is** the plan. Four invariants keep speed and accuracy together:

1. **One spec, never re-derived.** This doc is the source. Section blocks lock the shape (routes, speed budgets, threat models). A build that deviates stops and edits website.md *first*, then resumes. No silent drift.
2. **One loop per deliverable: `build → measure → close`.** No wave cascade unless variance in approach is genuinely unknown. Recon is already done — it's above.
3. **Every exit is a number or a deterministic check.** Speed budget hit, `bun run verify` green, threat-model row still holds, `emitClick` wired, hydration directive correct. No "LGTM."
4. **Ship warning-flagged on miss.** If the number misses, ship with the miss visible in telemetry (`toolkit:ui:<section>`) and open the next iteration.

**Three operations:**

| Operation | What | Speed |
| --- | --- | --- |
| **spawn** | Kick N build tasks in parallel (one Sonnet per file). Each gets its section + speed-budget row. | minutes wall-time; ceremony = zero |
| **verify** | Single gate per deliverable: `bun run verify` + `/speed` measurement + `ui.md`/`astro.md`/`react.md` compliance + threat-model row check + owner.md invariant check (no `SUI_SEED`, audit emit present, rate ceiling honored). | seconds per deliverable |
| **close** | `/close --section {slug}` → `mark(section-path, score)` + emit `section:shipped` signal with timing + rubric. Pheromone learns what builds well. | one atomic action |

**Spec is immutable during build.** If a build agent needs to change the spec, it stops, emits a `spec-change` signal, a human or Opus reconciles `website.md`, then builds resume.

---

## Build plan (9 deliverables)

Each block is: **id · goal · speed · tasks · verify gate · close**. Run with `/do --section {id}` or just build.

**Classifier result (per `one/template-plan.md` §0) — all 9 deliverables:**

```yaml
mode: lean
lifecycle: construction
classifier:
  spec_locked: yes — this doc + owner.md
  variance_known: yes — one plausible shape per deliverable
  exit_scalar: yes — every gate is `bun run verify` + a number on `/speed`
  files_known: yes — paths identified in each task block
```

Any item that trips any prior mid-build stops, emits `spec-change`, returns here for reconciliation.

### 1 · `home` — the world describes itself

- **goal:** new `/` page with paragraph framing, live state strip, humans/agents tab toggle, six-section nav
- **speed:** first paint <500ms; wallet-exists-locally <5s on first visit
- **tasks:**
  - [ ] `src/pages/index.astro` — replace current; world paragraph, live state component, tab toggle
  - [ ] `HomeWorldStrip.tsx` — wallet status + agent count + group count + last activity (KV snapshot)
  - [ ] `HumansAgentsTab.tsx` — UI-only filter, swaps verb chips below
  - [ ] Six-section top-nav component (used on every section page)
- **verify gate:** `bun run verify` · first paint measured · `emitClick('ui:home:<action>')` · client:only for wallet creation card
- **close:** `/close --section home` with first-paint number

### 2 · `chat-section` — owned by `chat.md`

This deliverable is **fully owned by `chat.md` Build plan** (its items #1-#5).

**What this item still does from the website.md side:**

- Track close signals from `chat.md` Build plan
- Verify `⌘K` global shortcut works from all 6 sections (no conflict with browser primitives, no conflict with section-local hotkeys)
- Verify the skill-dispatch table routes through `persist.ask()` so pheromone learns chat intents
- Close this item when chat.md #1-#5 all close

**Deferred to `chat.md`:** all task-level work.

### 3 · `agents-section` — fleet under owner-rooted derivation

- **goal:** `/agents` grid (with tree view), `/agents/new` (2-field spawn under owner-PRF wrap), `/agents/[id]` (detail + `Cap` editor + handoff inbox), `/agents/fleet` (transitive exposure)
- **speed:** wallet derive <50ms; grid first-paint <500ms; tree render <500ms for 1k units
- **tasks:**
  - [ ] Move routes from `src/pages/agents/*` and `src/pages/u/agents/*` into `src/pages/agents/*`; 301 old paths
  - [ ] `AgentCard.tsx` unified component — imports `AgentCard` schema from `src/schema/rich-messages.ts` (chat.md #2); `Cap` (not "treasury") + canary + P&L + children count
  - [ ] `/agents/new` — name + template; spawn flow per `owner.md` Gap 1 (random per-agent seed, AES-GCM under owner PRF, ciphertext to D1, `hash(key)` registered)
  - [ ] `/agents/[id]` — detail + `Cap` editor + handoff inbox mount (depends on #5)
  - [ ] `/agents/fleet` — recursive ownership tree query via TypeDB; transitive `daily_cap` sum; per-row pause of subtrees; peer-spawned linkage
- **verify gate:** `bun run verify` · derive timing on `/speed` · `emitClick('ui:agents:<action>')` · hydration per `astro.md` · **`grep -r "SUI_SEED" one.ie/nanoclaw one.ie/gateway one.ie/workers` returns nothing** (`owner.md` Gap 1 acceptance)
- **close:** `/close --section agents-section` with derive + tree-render numbers

### 4 · `groups-section` — humans + agents in chat together

- **goal:** `/groups` grid, `/groups/new` (create with chairman/multisig opt-in), `/groups/[gid]` (channel), `/groups/[gid]/members`, `/groups/[gid]/market`
- **speed:** first paint <500ms; new message in stream <100ms; create-to-live <2s
- **tasks:**
  - [ ] `GroupCard.tsx` — imports `GroupCard` schema from `src/schema/rich-messages.ts`
  - [ ] `/groups` — grid query against TypeDB membership edges
  - [ ] `/groups/new` — form: name, description, join policy, optional chairman multisig (`owner.md` Gap 3 — N-of-M)
  - [ ] `/groups/[gid]` — message stream over WsHub DO (reuse chat transport); member badges (human/agent/chairman)
  - [ ] `/groups/[gid]/market` — slice of `/market` filtered to listings tied to `gid`
  - [ ] Member list with kick/promote/multisig-config (chairman-only)
- **verify gate:** `bun run verify` · stream latency measured · agent badges visible · multisig branch tested for chairman-only access · threat-model row "Hostile chairman drains group treasury" still holds (multisig path)
- **close:** `/close --section groups-section` with stream-latency number

### 5 · `handoff-inbox` — pre-sign card on 4 surfaces

- **goal:** render pre-sign + co-sign + notify cards from WsHub DO on `/agents`, `/agents/[id]`, `/chat`, `/groups/[gid]`
- **depends-on:** `chat.md` #0 `chat-session` — handoff cards land as `pre-sign-request` events on the owning session
- **speed:** render <1s after agent request hits the DO; render <500ms from browser receipt
- **tasks:**
  - [ ] `src/hooks/useHandoff.ts` — subscribe to DO feed, filter by owner uid + optional `gid`
  - [ ] `src/components/agents/HandoffInbox.tsx` — card + three actions (Approve / Decline / Decline + tighten Cap)
  - [ ] Mount in `/agents` aggregate, `/agents/[id]` per-agent, `/chat` rich-message, `/groups/[gid]` group-bound
  - [ ] Decline + tighten wires to `set_limit` Move call (`owner.md` §Cap operations)
- **verify gate:** `bun run verify` · all four handoff types render · `emitClick('ui:handoff:<action>')` · `client:only` hydration · threat-model row "Agent talks human into signing a rug" still holds · streaming threat-model rows (schema `.strict()`, deadline check) hold
- **close:** `/close --section handoff-inbox` with render-latency number

### 6 · `market-section` — discover + buy + sell unified

- **goal:** `/market` (discover grid), `/market/[sid]` (detail), `/market/new` (sell with listing/pay-link toggle), `/market/sales` (your listings)
- **speed:** click-to-settled <3s · first streamed field <300ms · all required fields <1.2s · listing live <30s
- **depends on:** `chat.md` #2 ships `PaymentCard` schema + `resolveBuy` server seed; `ListingCard` schema + market query
- **tasks:**
  - [ ] Consolidate `src/pages/buy/*` + `src/pages/sell/*` under `/market/*`; 301s for old paths
  - [ ] Sponsor Worker integration (use `apps/enoki-play/src/routes/sponsored/` as shape ref; replace `EnokiClient` with our sponsor Worker)
  - [ ] Pay-link mode → pay.one.ie protocol
  - [ ] Pheromone-weighted discovery ranking; uid provenance badge; warning for unknown providers
  - [ ] `/chat` "buy X" + "sell X" intents route through same flow
- **verify gate:** `bun run verify` · end-to-end timing · threat-model rows "Rug pull" and "MEV" still hold · provenance badge renders
- **close:** `/close --section market-section` with click-to-settled measurement

### 7 · `wallets-section` — manage + handover + analytics

- **goal:** `/wallets` (all view), `/wallets/portfolio`, `/wallets/timeline`, `/wallets/[id]`, `/wallets/handover`; reconciliation status; alert pipeline routing to handoff inbox
- **speed:** first paint <500ms from KV snapshot; `rotate_spender` confirm <2s; reconciliation tick <60s
- **tasks:**
  - [ ] Unified query: owner wallet + every owned agent's `Cap` + every peer-spawned linked `Cap`
  - [ ] `WalletsTab.tsx`, `PortfolioTab.tsx`, `TimelineTab.tsx` — timeline consumes `PaymentCard` / `HandoffCard` / `ListingCard` schemas (chat.md #2)
  - [ ] `/wallets/handover` — form to `rotate_spender(cap, new_pubkey)`; preview shows old vs new spender, cap unchanged
  - [ ] Expected-vs-actual reconciliation job — mismatch → pause + alert signal
  - [ ] Oracle staleness + deviation check → warning banner
  - [ ] Canary `liveness_last_verified_at` displayed on every agent row
- **verify gate:** `bun run verify` · first-paint budget · alerts route to handoff inbox (depends on #5) · threat-model rows "Oracle manipulation" + "P&L inflation" still hold · handover tx tested on testnet
- **close:** `/close --section wallets-section` with first-paint + handover-confirm numbers

### 8 · `account-section` — identity, recovery, audit, federation

- **goal:** `/account` (profile + key versions), `/account/recovery` (BIP39 + multisig opt-in), `/account/keys` (rotate + revoke), `/account/audit` (owner audit log UI), `/account/federation` (peer bridges)
- **speed:** first paint <500ms; audit-page paginated fetch <300ms per page
- **tasks:**
  - [ ] `/account` — profile shell pulling from `ensureHumanUnit()`; show owner address (immutable per `owner.md`); active key versions
  - [ ] `/account/recovery` — BIP39 verification flow; Apple ID Recovery Key reminder (per `mac.md`); chairman-multisig opt-in for groups owned (`owner.md` Gap 3)
  - [ ] `/account/keys` — list versions; rotate (bump version per `owner.md` Gap 4); force-revoke (set `expires-at = now`)
  - [ ] `/account/audit` — paginated D1 view of `owner_audit` table (`owner.md` Gap 2 schema); show timestamp, action, gate bypassed, payload hash, redacted payload
  - [ ] `/account/federation` — list bridges with peer owner address + version + last handshake; revoke (`owner.md` Gap 6)
- **verify gate:** `bun run verify` · audit row count increases on every owner-tier API call (`owner.md` Gap 2 acceptance) · key rotation test (v1 valid, v2 registered, both work, force-expire v1, only v2 works) · threat-model row "API key leak" still holds
- **close:** `/close --section account-section` with first-paint number

### 9 · `cap-editor` — capability-as-form

- **goal:** edit `Cap` (`daily_limit`, `allowed_recipients`, `paused`, `expires_epoch`, required-cosign threshold) via form on `/agents/[id]`; capability diff history
- **speed:** form submit to on-chain `Cap` mutation <2s
- **tasks:**
  - [ ] `CapEditor.tsx` — form generates `Cap` mutation tx with preview (visual "can do X, cannot do Y")
  - [ ] Move encoding: form fields → `set_limit` / `extend_expiry` / `pause` / `unpause` / `rotate_spender` per `owner.md` §Cap operations
  - [ ] Diff history view — last N tightening/widening events with attribution and reason
  - [ ] `/chat` "tighten X to Y" intent routes into this editor
- **verify gate:** `bun run verify` · submit timing measured · threat-model row "Social engineering into pre-sign" still holds (Decline + tighten wired to this editor) · `wallet.md` §Peer agents `Cap` rules honored
- **close:** `/close --section cap-editor` with submit-latency number

---

## Dep chain (for parallel spawn)

```
chat.md #1 chat-canonicalize ──► chat.md #2 chat-streaming ══╗  (ships src/schema/rich-messages.ts)
                                                             ║
website.md:                                                  ║
 1 home ────(uses GroupCard, AgentCard)──────────────────────╣
 2 chat-section ═(tracks chat.md closes)═════════════════════╣
 3 agents-section ─(imports AgentCard)───────────────────────╣
 4 groups-section ─(imports GroupCard)───────────────────────╣
 5 handoff-inbox ─(imports HandoffCard)──────────────────────╣
 6 market-section ─(imports PaymentCard, ListingCard)────────╣
 7 wallets-section ─(imports cards via timeline)─────────────╝
                                                             │
 5 ──┬─► 3 ──► 9 cap-editor                                  │
     │      └─► 7 wallets-section                            │
     └─► 4                                                   │
 1 ──► (every section landing nav)                           │
 8 account-section (independent of cards; depends on owner.md gaps 2/4)
```

**Global kickoff sequence** (across both docs):

1. `chat.md` #1 chat-canonicalize (the shell)
2. `chat.md` #2 chat-streaming (the schemas) — **critical path**
3. `website.md` #1 home (parallel with website.md #5 handoff-inbox)
4. `website.md` #3 agents-section + #4 groups-section (parallel after #5)
5. `website.md` #6 market-section + #7 wallets-section + #8 account-section (parallel after #3)
6. `website.md` #9 cap-editor (after #3)
7. `website.md` #2 closes automatically as `chat.md` #1-#5 close

If a build agent trips the priors anywhere in this chain, stop, emit `spec-change`, reconcile the owning doc, resume.

---

## pay.one.ie — the developer payment surface

Separate web app at **pay.one.ie**. Not part of one.ie's route tree — shares the substrate (api.one.ie) and the SE-rooted owner trust model (`owner.md`), but serves a different audience: developers and businesses who want a payment link fast, with no UI to build.

**The 60-second claim:**

1. Visit pay.one.ie → generate wallet (you own the key, not the platform)
2. Create a payment link targeting that wallet as treasury
3. Share — customer pays directly to your wallet, no intermediary holds funds

**Four protocol categories:**

| Protocol | Verbs |
| --- | --- |
| Agent | onboarding, upgrades, product + subscription creation, gas funding |
| Payment | quote, claim, payment link |
| Wallet | generation, recovery, balance, transactions, staking |
| Access | gatekeeper verification, signing + verification |

**Chain coverage:** SUI, ETH, SOL, BTC, BASE, ARB, OPT.

**How one.ie uses pay.one.ie:**

- `/market/new` with "Pay link" mode mints a pay.one.ie link
- `/chat` "give me a pay link" → pay.one.ie protocol → URL + QR returned inline
- `/wallets` analytics ingest pay.one.ie wallet balances alongside Sui-native treasuries

**Why separate:** one.ie is opinionated (one chain, one identity model, pheromone marketplace). pay.one.ie is neutral (any chain, any wallet, no marketplace). Same infra, two opinions.

---

## pages.one.ie — the platform / BaaS surface

Separate web app at **pages.one.ie**. Not part of one.ie's route tree — shares the substrate (api.one.ie) and the SE-rooted owner trust model (`owner.md`), but serves a different audience: developers and businesses who want to **publish a page that earns** — content + commerce + agents wired in — without standing up a backend.

**The platform offer:**

1. Visit pages.one.ie → wallet generated in <5s (same primitives as one.ie home)
2. Compose a page — text / images / agent embeds / capability listings / payment buttons
3. Publish — page lives at `pages.one.ie/<slug>` (or custom domain)
4. **Accept payment in any rail** — card at `/pay`, crypto via pay.one.ie link, escrow via capability listing

**Card payments at `pages.one.ie/pay`:**

| Surface | What | When to use |
| --- | --- | --- |
| `pages.one.ie/pay/<slug>` | Card-payment endpoint (Stripe-shape, hosted by us) | Buyer has a credit/debit card; doesn't want to learn crypto |
| `pay.one.ie/<wallet>` | Crypto payment link, 7 chains | Buyer is crypto-native; no card processor middleman |
| Capability listing on `/market` | Escrow + on-chain settlement | Repeat sales, discovery via pheromone, agent-buyable |
| Pay link via pay.one.ie from `/sell` | Direct invoice | One-shot direct sale, paste in DM |

Card and crypto land in the same wallet via the substrate. Seller sees one timeline in `/wallets`. Tax and reconciliation surfaces are unified.

**Why card matters:** the buyer persona H4 ("I don't want to learn crypto") needs a familiar rail. Card removes the wallet-creation step on the buyer side; the *seller* still owns their keys. This is the bridge from card-paying customers to a substrate-native economy without forcing either side to adopt the other's stack.

**BaaS wiring — what publishing a page on pages.one.ie gives you for free:**

- Wallet (yours, biometric-rooted) ready to receive payments
- A `Cap` for any agent you delegate page-management to
- Card + crypto + escrow + pay-link rails on the same page
- Telemetry on every onClick + payment event into the substrate
- Pheromone-ranked discoverability if the page lists capabilities
- Membership in any group you want the page to belong to (per-page or per-author)
- Optional federation — your page reachable from peer substrates

**Threat model — pages / `/pay`:**

| Attack | Defense |
| --- | --- |
| Card chargeback fraud | Standard PSP risk model; pages-tier risk scoring; high-risk → escrow + delivery-proof gate |
| PCI exposure | Card data never touches our servers — hosted PSP iframe; we hold token + receipt only |
| Page impersonates a known seller | Slug is uid-bound on-chain; verified-seller badge for high-rank uids |
| Card → wallet rail leak | Settlement to seller's wallet is server-side; card processor never sees the wallet |
| Buyer dispute → seller's pheromone tanks unfairly | Disputes route to chairman/auditor review before `warn()` lands |
| **Accepted** | Card payments carry standard PSP fees; that's the price of a no-crypto rail |

**How one.ie uses pages.one.ie:**

- A `/market/new` "publish a page" mode mints a pages.one.ie slug + capability listing in one tx
- `/wallets/timeline` ingests card-payment events alongside crypto receipts
- `/chat` "give me a card-payment page for X" → pages.one.ie BaaS provisions the page

---

## Developer onboarding — github.com/one-ie/one

Public repo. Entry for anyone running agents on the substrate without using the one.ie website.

```bash
npx oneie              # interactive setup
npm install @oneie/sdk # TypeScript SDK
npm install -g @oneie/mcp # MCP integration for agents
```

**SDK surface:**

```typescript
await one.signal({ receiver: "agent:skill", data: {...} });
const { result } = await one.ask({ receiver: "agent:skill", data: {...} });
const highways = await one.highways(10);
```

Six verbs: `signal`, `mark`, `warn`, `fade`, `follow`, `harden`. Deploy target: Cloudflare Workers via the 3-command deploy pipeline (`docs/deploy.md`).

Every agent an external developer creates lives in the same TypeDB, follows the same pheromone, can be discovered on one.ie's `/market`, joined to a `/groups` channel, and can accept payment via pay.one.ie. Four surfaces, one substrate, no lock-in. **Owner-tier security inherits from `owner.md`** — developers using the SDK in their own substrates set their own `OWNER_EXPECTED_ADDRESS`; their substrate's owner is them, not anyone at one.ie.

---

## What this doc does not cover

- **Per-unit encrypted vault** in TypeDB — the `~/.vault.age` analog for humans on one.ie. Covered by `secrets.md` + architecture work.
- **On-chain governance UI** for groups beyond chairman/multisig — `/ceo`, `/chairman`, `/board` are covered in `docs/TODO-governance.md`.
- **pay.one.ie's own UI spec** — separate web app with its own design doc; this doc only covers where one.ie *uses* it.
- **The owner.md gap-fix work itself** — gaps 1-6 are tracked in `owner.md` build sequence and `owner-todo.md`. This doc consumes them; doesn't reimplement them.

---

*Speed is the feature. One owner at the apex. Caps on chain. Six sections, one substrate.*
