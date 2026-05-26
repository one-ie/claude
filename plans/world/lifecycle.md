# Agent Lifecycle — birth to retirement, one state machine

Take one agent from "doesn't exist" to "retired" on the stack defined in `agents.md`. Every transition is a single Move entry function — the lifecycle itself is on-chain, auditable, atomic. Nothing important lives in a script you have to remember to run.

---

## One-line summary

**One agent = one state machine on Sui. Six states, six transitions, each a single *owner*-signed tx. The owner is whoever holds the agent's ScopedWallet — human (Touch ID) or parent agent (cryptographic signature). Every step is an event you can replay from the chain.**

> **Note on terminology:** "owner" in this document refers to *whoever owns this agent's wallet* — could be a human, could be a parent agent. The capital-O substrate **Owner** (one per deployment, biometric-bound, all-powerful) is a separate concept defined in `owner.md`. The substrate Owner is the root from which all human-spawned agent lifecycles descend; lifecycle transitions inside agent subtrees use peer-agent ownership.

---

## States and transitions

```
┌─────────┐  conceive  ┌───────────┐  birth (1 tx) ┌──────┐  act  ┌────┐
│ Absent  │ ─────────► │ Conceived │ ────────────► │ Live │ ────► │ …  │
└─────────┘            └───────────┘               └──┬───┘       └─┬──┘
                                                     │              │
                                             pause (1 tx)     rotate (1 tx)
                                                     │              │
                                                     ▼              ▼
                                                 ┌────────┐    ┌─────────┐
                                                 │ Paused │    │ Evolved │
                                                 └────┬───┘    └────┬────┘
                                                      │             │
                                                    resume        act…
                                                      │
                                                      ▼
                                                   Live …  ─── retire (1 tx) ──► Retired
```

One owner tx per transition. Touch ID fires once if the owner is human; for peer-owned agents (parent agent is the owner — see `agents.md` Pattern D), the parent signs cryptographically and no biometric fires at all. Machine-speed spawning under a parent's cap is the whole point.

No multi-step wizards either way.

---

## 1. Conception — on paper, not on chain

Before the first tx, decide:

- **Job** in one sentence ("renew my five `.sui` domains annually")
- **Pattern** from `agents.md` — co-sign, scoped autonomy, or capability
- **Limits** — daily cap, allowed recipients, allowed methods, expiry
- **Name** — `<namespace>/<purpose>`, e.g. `one.ie/domain-renewer`

Write these into the vault at `[agents/<name>]` first. That entry is the agent's charter.

## 2. Birth — one tx

Single owner signature. Touch ID if the owner is a human; a parent agent's signature if the owner is an agent (Pattern D in `agents.md`). The Move entry function doesn't know the difference — consensus checks that whoever signed has authority for this spawn, within their own cap.

Depending on pattern:

| Pattern | The tx |
| --- | --- |
| Co-sign | Create the `2-of-2 multisig { user_passkey, agent_key }` address; send seed funding |
| Scoped autonomy | `scoped_wallet::create<T>(agent_addr, cap, allowlist, …)` + `fund<T>()` |
| Capability | `mint_capability(scope, expiry, budget)`, transfer to agent |

Before the tx:
- Generate the child's keypair. For human-owned agents: scoped age identity in `~/.vault.age [agents/<name>]`; public key is what the human signs into Move. For agent-owned agents: the parent generates the child's keypair in its own process memory (or a Workers secret if the parent is server-side), records the pubkey in an on-chain event at spawn, and never touches the private key again — the child boots with it.

After the tx:
- Off-chain identity: `ensureAgentUnit(uid, { wallet: scopedWalletObjectId, … })` creates a TypeDB `unit(unit-kind="agent")` + personal `group` + membership (human is `chairman`). Issue an API key via `src/lib/api-key.ts`. (Mirror of `ensureHumanUnit` in `src/lib/human-unit.ts` — same adapter, same session-free write.)
- Agent boots via `envr` (local dev — `[agents/<name>]` section becomes its env) or platform secrets (prod — Cloudflare Workers secret per `secrets.md`).
- Agent reads its own `uid` from the env, queries TypeDB for its `unit`, reads the `wallet` attribute → that's its on-chain `ScopedWallet` object ID. No hard-coded IDs, no per-agent config baked into the agent binary.
- Agent then reads the on-chain object and self-verifies: *"chain says I can spend X/day to {Y}; matches my charter."* Mismatch → agent refuses to operate. Two-sided check (TypeDB and Sui) protects against a compromised launcher lying to either side.
- Agent emits an `AgentAlive` event on-chain. User gets one notification: *"agent X is online."*

## 3. Live — operation

Normal-day loop. Agents act under their pattern:
- **Co-sign** — draft → notify → Touch ID → submit (see `agents.md` § UX)
- **Scoped autonomy** — act → consensus validates → executes or aborts
- **Capability** — use the object until it expires

Every action emits a Move event. The user's audit view is just a Sui-explorer query over the agent's address or the ScopedWallet ID. No off-chain log to trust.

## 4. Evolve — rotate keys or update scope

Owner-only Move entry functions, one tx each:
- `rotate_agent(w, new_agent_addr)` — agent gets a new keypair; old one goes inert; wallet object and funds unchanged
- `set_cap(w, new_cap)` — raise/lower daily cap
- `add_recipient(w, addr)` / `remove_recipient(w, addr)` — adjust allowlist
- `extend_expiry(cap, new_ts)` — prolong a capability (shortening is free: burn + mint)

Default cadence: **rotate agent keys quarterly**, even without incident. Cheap hygiene.

## 5. Pause — incident response

`pause(w)` — one owner tx. Consensus immediately refuses every in-scope action from the agent. Agent detects the rejection on its next attempt, halts work, emits `AgentPaused`. Resume with `unpause(w)`.

If the agent's key is suspected compromised, pause *first*, rotate *second*. Pause is faster than rotation and limits the blast radius during investigation.

## 6. Retire — death, one tx

- **Scoped wallet**: `scoped_wallet::revoke(w)` destroys the shared object; remaining funds return to the user's address
- **Capability**: burn the capability object
- **Co-sign**: optionally move any residual balance out of the 2-of-2 address

Then locally:
- `v` → remove the `[agents/<name>]` section from `~/.vault.age`
- Archive the agent's event history (one Sui-explorer export) alongside its charter

Retirement is idempotent. Running it twice is a no-op — the object is already gone.

## 7. Postmortem — one paragraph per agent

After retirement, write a 3-line postmortem into the charter entry before deletion:
- **Actual spend vs. budget**
- **Any action blocked by scope** (and whether the block was correct)
- **What the next agent of this type should differ on**

Feed forward. Over time your charters get tighter.

---

## Worked example — `one.ie/domain-renewer`

| Phase | Action |
| --- | --- |
| Conceive | "Renew my 5 `.sui` domains annually. Budget $500/yr. Horizon 12 months." → pick **capability** (bounded horizon). Charter in `~/.vault.age [agents/one.ie/domain-renewer]`. |
| Birth | `mint_capability(scope="domain_registry::renew", budget=500_SUI, expiry=+12mo)`; transfer to agent. Agent boots, reads the capability, emits `AgentAlive`. |
| Live | Monthly: agent queries registry for soon-expiring domains, calls `renew(cap, domain)` until done. Events stream to Sui explorer. |
| Evolve | User adds a 6th domain → `add_scope(cap, "domain6.sui")`, one tx. |
| Retire | 12 months later, capability auto-expires. Agent next run detects expiry, emits `AgentRetired`, exits. User burns the capability object for tidiness; `v` removes the charter. |
| Postmortem | *"Spent 380 SUI of 500. Blocked once (wrong method name, bug in agent v0). Next version: enforce the registry method whitelist inside the capability too."* |

Six touchpoints over a year, each ≤ 10 seconds of user attention.

---

## Worked example — peer-agent fleet `one.ie/market-maker` spawns 1000 arbitrage workers

| Phase | Action |
| --- | --- |
| Conceive | Human conceives a **market-maker** agent with budget $100k/day, allowed to spawn children with caps up to $500/day each. One human Touch ID. |
| Birth | Parent `market_maker` created under Pattern B; charter includes `max_children = 1000`, `child_cap_ceiling = 500`. |
| Live | Parent detects a new opportunity. Calls `scoped_wallet::spawn_child<SUI>(parent_w, child_pubkey, cap=200, allowlist, seed=1000)`. **Zero human involvement.** Child boots, self-verifies against its on-chain scope, emits `AgentAlive`. At peak, parent holds 1000 children, each capped at $200/day, total tree exposure ≤ parent's own cap. |
| Evolve | Parent rotates an under-performing child: one agent tx — `rotate_agent(child_w, new_pubkey)`. Child's ScopedWallet and history unchanged. No human. |
| Pause | A child trips a substrate `warn()` threshold. Parent calls `pause(child_w)` automatically. No human. Subtree below that child freezes. |
| Retire | End of market window. Parent calls `revoke<SUI>(child_w)` on every child in parallel — gas-sponsored, atomic per child. Remaining funds flow back up to the parent. Parent emits a summary event. No human involved in any child's lifecycle. |
| Postmortem | Human reads the fleet's aggregate performance from on-chain events. One read, 1000 agents' worth of outcome. Adjust the parent's charter, repeat. |

The human signed **once** (to birth the parent). Everything below was agent-to-agent, at machine speed, bounded by consensus. This is the shape of an agent economy.

---

## Fleet — when you have many agents

- **Naming**: `<namespace>/<purpose>` keeps collisions out (`one.ie/bill-pay`, `one.ie/rebalance`, `personal/subscription-renewer`)
- **Registry**: the TypeDB adapter is already the registry. Each agent is a `unit(unit-kind="agent")` with `uid`, `wallet` (ScopedWallet object ID), `unit-kind`, and a `membership` linking it to the owner. One TypeQL query lists every active agent; no on-chain `AgentRegistry` object needed. Retirement removes the unit (or sets `status: "retired"` to keep the audit trail).
- **Budget aggregation**: sum `daily_cap` across all active agents → your true daily exposure. Alert if it grows past a threshold.
- **Health**: no `AgentAlive` or action event in 72h → stale. After 30 days stale, prompt retirement.

## Dead-man's switch — cascading, owner-agnostic

Add a `last_owner_ping: u64` field to `ScopedWallet`. Every `spend()` asserts `now() - last_owner_ping < 30 days`. The owner pings with a one-line tx.

**For human owners:** passkey auto-sign, biweekly. Touch ID prompt can be bundled with any routine action.

**For agent owners:** a periodic `ping_child(child_w)` call from parent to child, gas-sponsored, no user attention needed. Parents ping their own owners on the same cadence — pings travel *up* the tree.

**Cascade effect:** if any node goes silent for 30 days, every ScopedWallet transitively below it auto-pauses. The tree freezes from the silent node down, not the whole fleet. A human at the root going silent pauses everything rooted in them. An agent midway going silent pauses only its subtree — the sibling trees keep working.

This generalises the "zombie protection" invariant into peer mode cleanly: no branch of the ownership tree outlives attention, and attention doesn't have to flow through the human root for every subtree.

Cost: ~10 lines of Move, one habit per owner. Non-optional for any peer-owned agent fleet.

---

## Security invariants across the lifecycle

- **Birth requires an authorised owner signature** — human Touch ID *or* parent-agent signature within its own cap. Agents cannot self-spawn without an authorised owner; agents *can* spawn sub-agents at machine speed when they are the authorised owner.
- **Every state transition is an owner-signed tx** — no off-chain state drift, regardless of depth in the ownership tree
- **Consensus enforces scope on every `spend`** — bypass impossible, not merely hard
- **Pause takes effect in one tx, at any level** — owner pauses the subtree below them instantly
- **Retirement returns funds upward** — no stranded balances; a retired sub-agent's remainder flows to its parent, wherever that parent sits in the tree
- **Rotation preserves the wallet object** — history, audit trail, allowlist all survive, including when a parent rotates a child's key
- **A compromised key is bounded** by its own ScopedWallet's remaining daily cap + the time for its owner (human or agent) to pause — not by the whole tree's funds
- **Dead-man's switch cascades** — silence from any node pauses the subtree below it at 30 days; siblings and uncles keep working
- **Human biometric root is non-transferable** — no lifecycle transition anywhere in any tree can be authorised by an agent signing *as* a human; agents sign as themselves, humans sign as themselves, consensus checks both
- **No lifecycle step requires trust in off-chain logs** — everything material is a Move event, visible to any owner at any depth

---

## What this replaces

- Ad-hoc agent provisioning scripts
- "We'll pause them manually if something goes wrong" policies
- Off-chain budget spreadsheets
- Trust-based retirement ("did the agent actually stop?" — on-chain says yes/no)
- Per-agent runbooks — the state machine is the runbook

---

## Self-audit (per agent, once per lifecycle milestone)

- [ ] Charter written before the birth tx (in `~/.vault.age [agents/<name>]` for human-owned, on-chain as a parent-signed event for peer-owned)
- [ ] Birth tx signed with the correct owner — Touch ID for human-owned, parent-agent signature for peer-owned; tx hash recorded
- [ ] Agent's on-chain pubkey matches the charter entry
- [ ] Agent self-verification passed (chain scope matches charter) on first boot
- [ ] `AgentAlive`, `AgentPaused` (if triggered), `AgentRotated` (if triggered), `AgentRetired` events present
- [ ] Quarterly key rotation executed on schedule (parent agent can rotate child keys without human — tested)
- [ ] Dead-man's switch configured; heartbeat cadence below 30 days; cascade behaviour verified on testnet
- [ ] Retirement tested once on testnet before mainnet agents retire
- [ ] Postmortem written before the charter entry is removed
- [ ] Fleet daily-cap sum, recursive through the whole ownership subtree rooted in this agent (or human), ≤ the root owner's conscious risk budget
- [ ] If peer-owned: human at the ultimate root has `/u/fleet` visibility into this branch's transitive exposure
