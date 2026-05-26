---
classifier:
  spec-locked: true
  variance-known: true
  exit-scalar: B + M shipped end-to-end (self-mint endpoint + cap minting + claim link)
  files-known: yes
  mode: lean
  lifecycle: construction
owner: tony
date: 2026-04-27
decision: B + M (envelope wrap + capability-scoped caps) — locked 2026-04-27
---

# Agent Wallet — the full option space

> **DECISION (locked 2026-04-27): B + M.**
>
> - **B (envelope encryption)** — every agent self-mints with a random seed, wrapped under the substrate owner's pubkey, ciphertext stored in D1. Owner Touch ID unwraps any agent for recovery; agent never needs the owner online to mint.
> - **M (capability-scoped caps)** — actual fund-spending authority lives in revocable Move `Cap` objects, not raw wallet sigs. Owner mints caps with daily limits per agent.
> - **F (claim link)** — kept as the optional ownership-transfer flow.
> - **A (current owner-Touch-ID-at-mint)** — demoted to Class 5 treasury fallback; no longer the default path.
> - **D, C, E, G, H, I, J, K, N, O, P** — rejected as primary architecture (still available for specific classes if needed later).
>
> **Recovery story:** BIP39 paper + one always-current file (`~/.vault.age/agent_wallets.jsonl`), append-on-mint. See [§D1 backup](#open-questions) below.
>
> **Detachability:** B alone is trivially detachable (agent owns its keys after first unwrap); M scopes spending so detached agents lose delegated authority but keep the wallet itself. Substrate ethos: agents are peers, not captives.
>
> Implementation work moves to `TODO-agent-wallets.md`. Sections below are kept as the rationale.

---

# Agent Wallet — the full option space

> **The question.** When an agent comes into existence, how does it get a wallet?
> Today's answer (`/api/agents/register-owner` + owner-Mac daemon, `src/lib/owner-key.ts:97-135`) requires a human Touch ID per agent and a live daemon at every cold-start. We want better.
>
> **The constraint.** The user has stated: an agent should be able to self-mint without a human in the loop, but the *default* recovery authority should still be the substrate owner's biometric — with an optional claim link that transfers ownership to another human.
>
> **This doc** lists every plausible architecture, scores them, and ends with a composition recommendation. No single option fits all agent classes — the answer is probably 2 or 3 stacked.

---

## Decision dimensions

Every option scores on these axes:

| Axis | Why it matters |
| --- | --- |
| **Self-mint?** | Can an agent create its wallet without a human present? |
| **Owner online at mint?** | Does the substrate owner's daemon / browser need to be reachable? |
| **Owner has recovery authority?** | If the agent loses its keys, can the substrate owner restore? |
| **BIP39-only recovery?** | Can the substrate owner recover *only* with the paper seed, no D1/cloud needed? |
| **Per-agent seed isolation?** | Does compromising one agent's key expose others? |
| **On-chain coupling** | Does the wallet design require a specific Move contract? |
| **New crypto?** | New primitives (HPKE, MPC, etc.) vs. only AES-GCM/HKDF/Ed25519 |
| **Existing code in `one.ie/`** | What ships today vs. greenfield |
| **Touch ID at mint** | yes / no / optional |
| **Touch ID per signature** | yes / no / scoped |

---

## The options

### A. Owner Touch ID at mint *(current implementation)*

**Shape.** Owner browser does WebAuthn → PRF → `deriveAgentKEK(prf, uid)` (`src/lib/owner-key.ts:97-135`) → wraps random `agent_seed` → `POST /api/agents/register-owner` (`register-owner.ts:71-232`) → D1 row. Agent boots via `/unlock` + `/unwrap` daemon proxy (`unwrap.ts:57-169`).

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✗ | ✓ at mint | owner | ✗ (needs D1) | **shipped** |

**Pros.** Already works. Strongest possible binding (owner physically present per agent).
**Cons.** One Touch ID per agent. Daemon must be reachable for every cold-start. Doesn't scale to 1000s of agents.
**When.** High-stakes treasury agents. The current path is correct *for them*.

---

### B. Envelope encryption (asymmetric pubkey wrap)

**Shape.** Owner publishes a long-lived pubkey (X25519 or HPKE) at `/.well-known/owner-pubkey.json` (already partially shipped per `owner.md` gap 6 V2). Privkey is wrapped under owner PRF. Agent self-mints with random seed, wraps under owner pubkey, inserts D1 row. Recovery: owner Touch ID unwraps privkey → unwraps any agent.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ | owner | ✗ (needs D1) | partial (gap 6 V2) |

**Pros.** Standard KMS pattern. Scales infinitely. Owner can be offline for months. Composes with Pattern D peer-spawning trivially.
**Cons.** Needs HPKE or X25519 (new primitive — small but real). Recovery requires BIP39 + D1 ciphertext export. Pubkey rotation requires re-wrap pass.
**When.** Default for most agents.

---

### C. Spawn-KEK (pre-shared symmetric secret)

**Shape.** Owner derives `spawn_kek_v{N} = HKDF(owner_prf, "spawn-kek:v{N}")` once per epoch (daily/weekly), pushes to a worker secret. Workers wrap agent seeds under it. Old epoch KEKs archived in `~/.vault.age`. Recovery: owner Touch ID re-derives any epoch KEK by version.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ between rotations | owner | ✓ (KEK is HKDF-derived from PRF) | none |

**Pros.** Symmetric only — no new crypto. Recovery is pure-BIP39 (KEK derives from PRF deterministically). Worker push is a one-time thing per epoch.
**Cons.** Worker holds a live KEK = compromise of any worker exposes every agent minted in that epoch. Rotation hygiene is mandatory. Old epochs must be remembered or accept "agents older than retention can't be recovered."
**When.** Want pure-BIP39 recovery and accept worker-secret blast radius. Probably *not* the right choice for high-stakes.

---

### D. HKDF chain / Pattern D peer-spawn

**Shape.** Per `agents.md` Pattern D + `CLAUDE.md`. Move-side ships: `src/move/one/sources/scoped_wallet.move:142+` `spawn_child<T>()`. TS-side partial: `src/lib/peer/spawn-child.ts:68-126`. Child seed = `HKDF(parent_seed, "agent:" + spawn_nonce + ":child")` where `spawn_nonce` = on-chain `spawn_child` tx digest.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ (parent agent mints child) | ✗ | parent → root → owner | ✓ (deterministic chain) | partial |

**Pros.** No new crypto. Beautiful determinism — Sui is the history; replay any chain to recover any descendant. Composes with B (root parents are owner-rooted, leaves are deterministic). Existing Move infra.
**Cons.** Lose a parent's seed mid-chain → lose every descendant from that point. Self-mint requires a parent — can't bootstrap (need option B/C/E for root agents). The child wallet IS its place in the chain — re-parenting is impossible.
**When.** Within a fleet where one root parent owns thousands of leaves (e.g., one human, one root agent, 10000 task children).

---

### E. Pure self-sovereign random seed

**Shape.** Agent generates `crypto.getRandomValues(32)` → Sui keypair. Stores ciphertext locally (worker durable storage, IDB). BIP39 mnemonic emitted to agent's storage. No owner involvement at any layer.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | n/a | **none — agent must back up itself** | ✓ (agent's own BIP39) | shape exists in `lib/seed.ts` |

**Pros.** Maximally simple. Same model as a hardware wallet. No infrastructure.
**Cons.** **Owner has zero recovery authority.** Agent loses its storage → wallet gone forever. Doesn't satisfy "rooted in my biometrics."
**When.** Agents that genuinely belong to no one (federated peers, third-party agents in your substrate). Or: ephemeral demo agents.

---

### F. Self-sovereign + opt-in claim link

**Shape.** Same as E at mint. Agent can optionally generate `https://one.ie/u/claim?token=…`. When a human Touch IDs at the link, that human's pubkey is added as a recovery wrapping for the agent's seed (envelope, like B but added late). Pre-claim: no recovery. Post-claim: that human can recover.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ | none → human (post-claim) | ✗ post-claim | none |

**Pros.** True user-controlled binding. Most flexible. Human chooses which agents to adopt.
**Cons.** Default state has no recovery — agent must remember to send a claim link before it dies. Pre-claim agents are E.
**When.** Agents that *might* find a human owner but mostly don't. Marketplaces.

---

### G. Agent passkey (agent does its own WebAuthn)

**Shape.** Agent enrolls a WebAuthn credential against a *server-resident authenticator* (TPM-backed, HSM, or virtual). Same PRF model as humans, but the "biometric" is replaced by a server-policy gate (rate limits, attestation, KMS).

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ | depends on the authenticator vendor | depends | none |

**Pros.** Cleanest mental model — agents are first-class citizens with the same primitive as humans. Vendor lock-in to KMS provider.
**Cons.** WebAuthn was designed for humans; "headless" passkey support is patchy across browsers and runtimes. Recovery story is now a KMS problem (AWS KMS, GCP KMS, HashiCorp Vault). Cloudflare Workers don't have a TPM.
**When.** If we run our own KMS (Vault on a Mac mini), this becomes attractive. Today: too much new infra.

---

### H. Threshold / MPC (Lit Protocol, Web3Auth, Coinbase MPC)

**Shape.** Wallet keypair is split (k-of-n) across a network of nodes. Agent signs by collecting threshold signatures. No single party holds the full key.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ | depends on quorum policy | ✗ (no single seed) | none |

**Pros.** No single point of compromise. Industry-standard for non-custodial wallets-as-a-service.
**Cons.** External dependency on MPC network. Latency per sig (multi-round). Costs real money. Not aligned with "your keys, your device, your seed phrase" ethos in `passkeys.md` / `wallet.md`.
**When.** If we ever want to be a custodial-ish service. Probably never for the substrate.

---

### I. Substrate master key (operator-rooted)

**Shape.** Substrate has a master keypair held by the operator (you). Same as B but the framing is "the substrate," not "the owner." Functionally identical for one-operator substrates. Differs when there are multiple operators (multisig of operators wraps every agent).

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ | operator(s) | ✗ | partial (B) |

**Pros.** Future-proofs for non-Tony substrates. Maps to the chairman/board/ceo role hierarchy already in `role-check.ts`.
**Cons.** Identical complexity to B for now. Adds multisig overhead later.
**When.** When the substrate has more than one operator.

---

### J. Group-rooted

**Shape.** Each `g:owns:{uid}` group has a group keypair. Agent wallets are wrapped under their group's pubkey. Group keypair is wrapped under the chairman's PRF (or multisig of group members).

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ | group chairman / quorum | ✗ | none |

**Pros.** Aligns with `role-check.ts` permission model (role × pheromone). Multi-tenant SaaS shape — different customers' agents wrapped under their own group keys.
**Cons.** N keys to manage where N = number of groups. Adds a layer over B.
**When.** Multi-tenant. For Tony-only substrate, B is simpler.

---

### K. zkLogin / OAuth-derived address

**Shape.** Agent identity comes from an OAuth provider (Google, Apple, Twitch, Facebook). zkLogin proof + ephemeral keypair = Sui address. Per existing `/zklogin` skill + `src/pages/api/auth/zklogin/**`.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ (with OAuth) | ✗ | OAuth account | ✗ | **shipped** |

**Pros.** Already shipped. Familiar UX. Recovery = "remember your Google password."
**Cons.** Trust shifted to Google/Apple. Salt management is a known footgun (per `passkeys.md` we explicitly ruled out zkLogin's salt path). OAuth account compromise = wallet compromise. Centralized.
**When.** Humans who don't want to manage keys at all. **Probably not for agents** — agents don't have email accounts.

---

### L. Tiered (testnet-self-sovereign / mainnet-owner-rooted)

**Shape.** Composition, not a primitive. Testnet agents = E (no recovery, throwaway). Mainnet agents = B/C/D (owner-rooted). Promotion from testnet to mainnet = explicit re-wrap step that costs one Touch ID.

**Pros.** Cheap experimentation. Forces a deliberate moment when an agent gets real authority.
**Cons.** Two code paths. Promotion is friction.
**When.** Always — it's an orthogonal policy on top of any other option.

---

### M. Capability-scoped subkeys

**Shape.** Per `agents.md` Pattern C. Agent doesn't hold a wallet; it holds a `Cap` Move object that authorizes specific actions up to a daily cap. Master wallet held elsewhere (owner). Per `src/move/one/sources/scoped_wallet.move`.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ (cap minting) | ✓ once for cap | owner (revoke cap) | n/a (no seed) | partial |

**Pros.** Strongest authorization model. Caps are revocable on-chain. Owner physics-bound to cap minting (one Touch ID per cap, not per agent action).
**Cons.** Doesn't replace a wallet — composes on top of one. The agent still needs *some* keypair to sign Move txs that consume the cap.
**When.** **Always layer this on top of B/C/D for actual money flows.** It's not "how does an agent get a wallet" — it's "how does an agent get *authority* to spend without holding the master wallet."

---

### N. Sponsored-tx-only (no agent wallet)

**Shape.** Agent has no Sui keypair. It builds a tx, signs with an ephemeral key, sends to a sponsor Worker (per `apps/enoki-play/src/routes/sponsored/sponsored.remote.ts` shape). Sponsor pays gas and signs as fee-payer. Agent identity is its bearer token, not a Sui address.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ (sponsor is) | n/a | n/a | reference at `apps/enoki-play/` |

**Pros.** Cheapest agent — no wallet management at all. Aligns with the existing sponsored-tx work.
**Cons.** Agent can't *own* anything on-chain. Can only do gasless ops via the sponsor. Limits agent economics (no peer-to-peer payments between agents, no agent-owned NFTs).
**When.** Read-mostly agents. Bots that emit signals but never custody assets.

---

### O. Sui multisig (agent + owner)

**Shape.** Wallet is a 1-of-2 or 2-of-2 Sui multisig of (agent_key, owner_key). Agent can sign small txs alone (1-of-2 with daily cap enforced off-chain or via Move guard). Big txs need owner co-sign.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ | ✗ for small txs | owner | depends on owner key | none |

**Pros.** On-chain enforcement of "agent has limited authority, owner has veto." No off-chain trust.
**Cons.** Multisig adds tx weight + complexity. Sui multisig is reasonable but every dapp must understand it. Can't easily transfer ownership.
**When.** Agents that custody real value and want on-chain co-sign rather than trusting the worker / cap layer.

---

### P. Object-bound capability (no agent wallet at all)

**Shape.** Per `agents.md` Pattern A/C. Authority is a Move `Cap` object owned by parent agent's wallet. Child has no wallet; it asks the parent to sign on its behalf, presenting cap proof.

| Self-mint | Owner online | Recovery | BIP39-only | Existing |
|---|---|---|---|---|
| ✓ (parent mints cap) | ✗ | parent → owner | n/a | partial |

**Pros.** Zero key management for child. Pure on-chain authorization.
**Cons.** Every action is a parent round-trip. Parent compromise = child compromise. No peer-to-peer between siblings.
**When.** Tight subordinate hierarchies (parent agent runs 100 worker tasks). Same shape as M but more extreme.

---

## Composition matrix

These options *layer*. Not "pick one" — pick a stack.

|  | as **identity layer** (creates the seed) | as **authority layer** (governs spending) | as **recovery layer** (who restores) |
|---|---|---|---|
| A | ✓ | — | self |
| B | ✓ | — | owner |
| C | ✓ | — | owner (per epoch) |
| D | ✓ | — | parent chain → root |
| E | ✓ | — | self (BIP39) |
| F | ✓ | — | post-claim human |
| G | ✓ | — | KMS vendor |
| H | ✓ | — | quorum policy |
| I | ✓ | — | operator multisig |
| J | ✓ | — | group |
| K | ✓ | — | OAuth account |
| L | n/a | n/a | n/a *(meta-policy)* |
| M | — | ✓ | n/a |
| N | n/a (no wallet) | ✓ via sponsor | n/a |
| O | — | ✓ on-chain | composes with id-layer |
| P | n/a (no wallet) | ✓ via cap object | n/a |

Read: **identity** (how does the seed come to exist) + **authority** (what can it do) + **recovery** (how is it restored). The current implementation (A) collapses all three into one path. A proper architecture separates them.

---

## Recommendation framework

No single answer fits all agents. **Pick a stack per agent class:**

### Class 1 — Substrate-internal agents (default)
*Marketing bots, channel agents, task workers — born inside the substrate, owned by you.*

> **B + M + L.** Envelope-wrap under owner pubkey at mint (no Touch ID). Layer capability-scoped Move caps for actual fund movements. Apply tier policy (testnet wallets are throwaway, mainnet wallets get owner-rooted).

Recovery: BIP39 paper + `~/.vault.age` D1 export. Minted-by: agent itself via `/api/auth/agent` extension. Touch ID: only when minting caps with real funds, not per agent.

### Class 2 — Peer-spawned children (high fanout)
*A root agent spawns thousands of task workers.*

> **B (for root) + D (for descendants) + M.** Root agents are envelope-wrapped under owner pubkey. Descendants use HKDF chain (Pattern D) — deterministic, recoverable from owner via root replay.

Recovery: owner unwraps root, replays Sui spawn chain. Pure-BIP39 below the root.

### Class 3 — Marketplace / federated agents
*Agents that arrive in your substrate from elsewhere, or might be claimed by an external human.*

> **F + M.** Self-sovereign at mint. Optional claim link to bind to a human later. Caps gate actual spending until claimed.

Recovery: pre-claim, none. Post-claim, the claimer.

### Class 4 — Read-only / signal-only bots
*Agents that emit signals but never custody assets.*

> **N.** No wallet at all. Bearer token is identity. Sponsored tx for any rare on-chain need.

Recovery: re-mint the bearer.

### Class 5 — Treasury / high-stakes
*Agents that hold real funds, run pay.one.ie, etc.*

> **A (current) + O.** Owner Touch ID at mint. Sui multisig with owner co-sign on big txs. Per-agent rate limits.

Recovery: owner, on-chain.

---

## What this means for the codebase

If we adopt **B + M + D + F + N** as the unified stack across the five classes:

| Need | Lives at | Status |
| --- | --- | --- |
| Owner pubkey publish | `src/pages/.well-known/owner-pubkey.json.ts` | ✅ shipped (gap 6 V2) |
| `deriveAgentKEK` (PRF → symmetric) | `src/lib/owner-key.ts:97-135` | ✅ keep for option A & cap minting |
| Envelope wrap helper (HPKE/X25519) | new `src/lib/owner-envelope.ts` | **needed** |
| `POST /api/auth/agent` *with self-mint wallet* | extend `src/pages/api/auth/agent.ts:95-276` | **needed** |
| Pattern D child seed derivation | extend `src/lib/peer/spawn-child.ts:68-126` | **needed** |
| `POST /u/claim?token=…` | new `src/pages/u/claim.astro` | **needed** |
| Re-wrap on claim | new helper alongside owner-key | **needed** |
| Cap minting flow | `src/move/one/sources/scoped_wallet.move:142+` | partial |
| Sponsor tx flow | reference at `apps/enoki-play/` | reference only |
| Multisig flow (option O) | new — defer to class-5 work | not yet |

**Net new code:** ~5 files. **Net deletion candidates:** the `POST /api/agents/register-owner` browser-side wrap dance becomes a fallback path for class-5 only — most agents never touch it.

---

## Open questions

1. **Pubkey choice.** X25519 (raw, simpler) vs. HPKE (RFC 9180, standard envelope). HPKE is more verbose but standardizes on a vetted construction. Probably HPKE.
2. **Pubkey rotation.** Single forever pubkey, or rotated periodically with old keys archived for unwrap? Suggest: rotate yearly, keep all history.
3. **D1 export cadence.** How often do we snapshot `agent_wallet` rows to `~/.vault.age` for the recovery story? Suggest: weekly, automated by `mac-agent`.
4. **Claim link expiry & revocation.** TTL on `/u/claim?token=…`. One-shot or re-issuable? Suggest: 24h TTL, one-shot, revocable from `/u/agents`.
5. **What happens when an agent self-mints under owner pubkey, then *you* lose your PRF + paper?** With B alone: agent wallet is dead. Unavoidable consequence of owner-rooted recovery. Mitigation: every Class-1 agent also keeps its *own* BIP39 in worker durable storage, gated by a "self-recovery code" the agent chose at mint. Belt + suspenders. Make this explicit policy.

---

## Decision (closed 2026-04-27)

- [x] **Single-stack: B + M** — envelope-wrap default + capability-scoped caps + F as opt-in claim. A retained only for Class 5 treasury fallback.
- [ ] ~~Tiered (5 classes with D, N layered)~~ — rejected; complexity not justified
- [ ] ~~Status quo (A only)~~ — rejected; doesn't scale past tens of agents

**Open sub-questions still to resolve in `TODO-agent-wallets.md`:**

1. **Pubkey choice.** HPKE (RFC 9180) vs. X25519 raw. Defaulting to HPKE unless we hit bundle-size pressure.
2. **Pubkey rotation.** Annual rotation, old keys archived for unwrap. Confirm.
3. **D1 export cadence.** Append-on-mint to `~/.vault.age/agent_wallets.jsonl` (synchronous, owner-daemon-mediated). Confirm.
4. **Claim link TTL.** 24h, one-shot, revocable from `/u/agents`. Confirm.
5. **Self-recovery code for agents.** Belt + suspenders (agent also keeps own BIP39 in worker storage gated by an agent-chosen code) vs. owner-only. Defaulting to owner-only — agents are detachable by design (see "Detachability" above), so belt+suspenders adds complexity for a problem agents can solve themselves by self-exporting.

---

## Plain English — one sentence each

**Options:**

- **A. Owner Touch ID at mint** — You tap Touch ID once for every agent that wants a wallet.
- **B. Envelope encryption** — Agent makes its own wallet, locks it with your public key, only your fingerprint can unlock it later.
- **C. Spawn-KEK** — You hand the workers a shared password each week; agents use it to lock their wallets.
- **D. HKDF chain (Pattern D)** — Each child agent's wallet is mathematically born from its parent's, like family DNA.
- **E. Pure self-sovereign** — Agent makes its own wallet and you have zero way to recover it.
- **F. Self-sovereign + claim link** — Agent makes its own wallet now; later, a human can tap Touch ID on a link to adopt it.
- **G. Agent passkey** — Give the agent its own fake fingerprint, stored in a server vault.
- **H. MPC / threshold** — Split the wallet across many computers so no single one ever holds the whole key.
- **I. Substrate master key** — Same as B, but framed as "the substrate's key" instead of "your key" — matters when there's more than one operator.
- **J. Group-rooted** — Each team has its own master key; agents in that team are locked under it.
- **K. zkLogin / OAuth** — The agent logs in with Google and Google becomes its recovery.
- **L. Tiered (testnet vs mainnet)** — Test agents are throwaway; real agents get owner-rooted.
- **M. Capability-scoped caps** — Don't give the agent a wallet; give it a permission slip with a daily spending limit.
- **N. Sponsored tx** — Agent has no wallet; another worker pays the gas and signs for it.
- **O. Sui multisig** — Wallet needs both agent and owner signatures; agent does small things alone, big things need you.
- **P. Object-bound capability** — Agent has no wallet at all; it just borrows its parent's authority via an on-chain permission slip.

**Classes (recommended stacks):**

- **Class 1 — default agents (B + M + L)** — Agent self-mints, locked under your public key, with permission-slip caps for spending — no Touch ID per agent.
- **Class 2 — peer-spawned children (B + D + M)** — A parent agent spawns thousands of kids; each kid's wallet is derived from the parent's seed.
- **Class 3 — marketplace agents (F + M)** — Agent makes its own wallet and waits for a human to claim it via a link.
- **Class 4 — read-only bots (N)** — No wallet at all; signals only.
- **Class 5 — treasury agents (A + O)** — Owner Touch ID at mint, plus on-chain co-sign for big spends.

---

## See also

- [`agents.md`](agents.md) — 4 agent patterns; this doc extends Pattern D and clarifies wallet provenance
- [`passkeys.md`](passkeys.md) — user wallet 5-state lifecycle; agents do *not* follow this directly
- [`wallet.md`](wallet.md) — wallet phases and quality bar; option choice changes which phases apply
- [`/Users/toc/Server/owner.md`](/Users/toc/Server/owner.md) — substrate root; owner pubkey publishing (gap 6 V2)
- `apps/enoki-play/` — sponsored-tx shape reference (option N)
- `src/lib/owner-key.ts:97-135` — current PRF→KEK derivation
- `src/pages/api/agents/register-owner.ts:71-232` — current owner-Touch-ID-at-mint flow
- `src/move/one/sources/scoped_wallet.move:142+` — Move side of Pattern D + caps
