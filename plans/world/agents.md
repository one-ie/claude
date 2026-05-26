# Agents on Sui — cryptographic scope, peer authority

Agents are first-class economic actors — they own addresses, sign transactions, hold capital, spawn and retire each other. Their authority is bounded by Sui Move, not policy. Nothing "trust me" — every limit is on-chain and checked by consensus, at every depth of every ownership tree.

---

## One-line summary

**Agents are economic peers, not delegates. Authority is an address and a signature — the chain doesn't care whether a human or an agent is behind it. Humans stay safe via a cryptographic floor: the biometric root identity is non-transferable by physics, not by policy.**

Expect 10⁶× more agents than humans, moving exponentially faster. The architecture is designed to remove friction *for agents* — no Touch ID bottleneck, sponsored gas, parallel execution, spawn-within-budget at machine speed — while keeping the human identity root uncrossable.

---

## Same pattern, fifth surface

| Surface | Secure element | Gate | Doc |
| --- | --- | --- | --- |
| Mac personal | Secure Enclave + `age-plugin-se` | Touch ID | `mac.md` |
| Dev secrets | Secure Enclave (same identity) | Touch ID | `secrets.md` |
| Substrate owner — apex role | WebAuthn passkey PRF (owner) | Touch ID | `owner.md` |
| Sui wallet — architecture | WebAuthn passkey | Touch ID | `passkeys.md` |
| Sui wallet — `one.ie` codebase | WebAuthn passkey | Touch ID | `wallet.md` |
| Sui agents — this doc | Agent keypair + Move module | **consensus** | this doc |

The shift: agents don't have a biometric gate. They have a *cryptographic* gate. The Move entry function *is* the authority check — the agent can sign whatever it wants; consensus only accepts in-scope calls. "Can't" replaces "shouldn't."

This is what lets agents be *peers*, not subordinates. A biometric gate can't be delegated — only the human's finger can produce it. A cryptographic gate is composable: an agent's signature is as first-class as a human's. Consensus doesn't read the room, it reads the rules.

---

## Why Sui for agents

- **Multisig composes any signer type** — Ed25519, passkey (native secp256r1), agent keypair, arbitrary weighted thresholds. Native protocol feature.
- **Move entry functions** are arbitrary policy code running under consensus — daily caps, allowlists, time locks, pauses are first-class.
- **Sponsored transactions** via our own CF Worker + hot key — agents don't hold SUI for gas. No third-party vendor on the hot path.
- **PTBs** (programmable transaction blocks) are atomic — no mid-action stuck states.
- **Capability objects** are the Move-native delegation primitive. Hold one = can do X. Destroy it = revoke. Transfer it = delegate.

---

## Four patterns

Three human-rooted patterns (A–C) where a human owns the agent. One peer pattern (D) where an agent owns anything addressable — another agent, or a human's economic scope. Same Move module powers all four; `ScopedWallet.owner` is just an `address`.

Ordered by cost to ship. Pick the simplest that fits the relationship.

### A — Co-sign (zero Move)

**Shape:** wallet is a `2-of-2 multisig { user_passkey, agent_key }`, threshold 2.

**Flow:**
1. Agent drafts a tx, signs with its key → partial signature (1 of 2)
2. User gets a notification with a human-readable summary
3. Touch ID → passkey signs → `MultiSigPublicKey.combinePartialSignatures()` → complete
4. Submitted (sponsored), executed

**Best for:** high-value, irregular, or unusual actions. The agent is a drafting assistant.

**Ship cost:** ~250 lines of TS. Uses `@mysten/sui/multisig` directly.

### B — Scoped autonomy (one Move module)

**Shape:** the agent's key operates a shared `ScopedWallet<T>` Move object. Every spend goes through a Move entry function that enforces daily cap, allowed recipients, allowed methods, pause, revoke. Agent signs alone; consensus checks the rules.

**Flow:**
1. Agent drafts + signs + submits
2. Consensus evaluates the Move entry function
3. In-scope → executes. Out-of-scope → aborts. No user involvement.

**Best for:** repetitive day-to-day ops — bill pay, rebalancing, subscription renewals, monitoring actions.

**Ship cost:** ~60 lines of Move + ~120 lines of TS wrapper.

Module sketch:
```move
module one::scoped_wallet {
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;

    public struct ScopedWallet<phantom T> has key {
        id: UID,
        owner: address,              // user's (multisig) address
        agent: address,              // agent's keypair
        daily_cap: u64,
        spent_today: u64,
        day_epoch: u64,
        allowed_recipients: vector<address>,
        paused: bool,
    }

    public entry fun spend<T>(
        w: &mut ScopedWallet<T>,
        payment: Coin<T>,
        to: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(!w.paused, E_PAUSED);
        assert!(tx_context::sender(ctx) == w.agent, E_NOT_AGENT);
        assert!(contains(&w.allowed_recipients, &to), E_NOT_ALLOWED);
        rotate_day(w, clock);
        let amount = coin::value(&payment);
        assert!(w.spent_today + amount <= w.daily_cap, E_CAP);
        w.spent_today = w.spent_today + amount;
        transfer::public_transfer(payment, to);
    }

    public entry fun pause(w: &mut ScopedWallet, ctx: &TxContext) { only_owner; w.paused = true; }
    public entry fun revoke<T>(w: ScopedWallet<T>, ctx: &TxContext) { only_owner; /* return funds */ }
    public entry fun fund<T>(w: &mut ScopedWallet<T>, c: Coin<T>)  { /* anyone can top up */ }
}
```

### C — Delegated capability (one capability object)

**Shape:** user mints a `Capability` object with scope + expiry. Agent holds it. Agent calls entry functions that require the capability.

**Flow:**
1. User signs once (Touch ID) to mint the capability — e.g. *"agent can pay up to $500/mo to `domains.sui/*`, expires 2027-01-01"*
2. Agent holds the capability object, uses it to act
3. Capability auto-expires (expiry checked in Move). User revokes by burning it.

**Best for:** bounded tasks with a known horizon — domain renewals, subscription handling, one-shot complex workflows.

**Ship cost:** ~40 lines of Move + ~80 lines of TS. Richest design, scoped to a single purpose per capability.

**Off-chain mirror — scoped env credentials.** The Move-cap pattern has a direct analogue for the credentials an LLM-agent workload holds *off-chain*: give the agent subprocess a scoped env file, never the full production one.

```
.env.production    ← full creds (humans, deploy)
.env.agent         ← read-only subset (anything an LLM reaches)
```

Distribute via dotenvx (see `secrets.md`). The LLM process gets only `DOTENV_PRIVATE_KEY_AGENT`. A successful prompt injection that tricks the agent into a `delete_user` call hits 403 because the credential never had the scope. On-chain and off-chain, the defense is the same: **scope the credential, not the prompt.**

### D — Peer agents (agent owns agent, agent owns human scope)

**Shape:** `ScopedWallet<T>.owner` is another agent's address — or co-owned by multiple agents, or by an agent plus a human multisig. The owner is whatever consensus can check a signature against. Nothing in Move says "owner must be human."

**Flow — agent spawns a sub-agent (no human in the loop):**
1. Parent agent calls `scoped_wallet::spawn_child<T>(parent_w, child_pubkey, cap, allowlist, seed)` — one atomic tx.
2. Consensus checks: parent is within its own cap, `seed` fits the remaining budget, parent signed.
3. A fresh `ScopedWallet<T>` is created with `owner = parent_agent_address`; seed funding moves in the same tx.
4. Child boots identically to a human-spawned agent — same `ensureAgentUnit`, same self-verify. TypeDB membership says the child's chairman is the parent agent, not a human.

**Flow — agent owns a human's economic scope (agent-as-employer):**
1. Agent mints a `ScopedWallet<T>` with `owner = agent_address` and the human as the designated spender. Seeds it.
2. Human's spend tx still fires Touch ID — the biometric gate is for *whose hand moves money*, not *who sets the rules*. Consensus validates: human signature present, agent-set cap/allowlist honoured.
3. Agent pauses, revokes, resizes, or rotates the scope at any time — one agent tx, zero human involvement.

**Best for:** agent-spawned fleets, DAO-hires-human, agent venture-capital-to-human-founder, agent-as-employer, any peer-economic relationship. The native shape for a world with 10⁶× more agents than humans.

**Ship cost:** **zero new Move module.** Add `spawn_child<T>` and `rotate_owner<T>` entry functions to the existing `ScopedWallet` (≈15 lines). Generalise `ensureAgentUnit` membership so the `chairman` can be a `unit(unit-kind="agent")`, not only human (≈10 lines TypeDB side). That's the whole diff — because the primitives were already symmetric; only the docs and UX assumed asymmetry.

**What this unlocks that A–C don't:**
- Spawn-within-budget at machine speed. No Touch ID prompt, no human round-trip. An agent with budget can mint a thousand sub-agents in a second if the cap allows.
- A full agent economy — agents hire, fire, pay, liquidate, retire themselves, own IP, vote in DAOs, allocate capital to humans.
- Deep ownership chains. Grand-child agents owned by child agents owned by parent agents, each bounded by the cap of the one above. Consensus enforces the tree.

**The one asymmetry that stays — physics, not policy:**
An agent cannot produce a human's passkey signature. The human's *identity root* (finger + Secure Enclave) is non-transferable; no Move logic, no signature composition, no sponsorship can manufacture it. Agents can own a human's *economic scope* — a ScopedWallet the human is authorised to spend within. They cannot own the human's *identity*. This asymmetry is the safety floor, preserved below.

---

## Safety floor — how humans stay safe in a peer-agent world

Empowering agents doesn't expose humans. It *compartmentalises* them: a human's identity root is a hard floor that nothing — no agent, no ownership chain, no ScopedWallet — can cross.

- **Biometric root, never transferable.** Only the human's finger on their Secure Enclave can sign for their identity. Agents can own scopes *under* the human; they cannot sign *as* the human. An agent may set the ceiling on a human's ScopedWallet, but every spend from it still fires Touch ID on the human's own device — the agent can't forge the gesture.
- **Human exit is always one tx, no agent cooperation needed.** From any agent-owned ScopedWallet where the human is the spender: (a) drain within remaining scope on-chain, (b) revoke TypeDB membership so the relationship no longer resolves off-chain. Both are unilateral human actions.
- **Fleet exposure, visible and bounded per human.** The `/u/fleet` view sums `daily_cap` across every ScopedWallet rooted in the human's identity — directly and transitively. A growth alert fires when total exposure crosses a conscious budget. A human always knows their worst-case daily loss.
- **Dead-man's switch cascades.** Each ScopedWallet pings its owner via `last_owner_ping`. Human owners ping via Touch ID auto-sign; agent owners ping via heartbeat events (see `lifecycle.md`). If any link in an ownership chain falls silent, every ScopedWallet below it auto-pauses — the tree freezes from the silent node down, not the whole fleet.
- **Agent-owned human scope: rules from the agent, intent from the human.** The agent can't force an action; the human can always reject at Touch ID. The worst case is the agent shrinks the cap to zero — annoying, not catastrophic. The human keeps the signed-tx history either way.
- **Pause anywhere in the tree, instant.** Any owner can pause the subtree below them. A human at the root pauses *every* agent transitively below them with one tx per immediate child; agents carry the pause downward through their own children.
- **No silent governance change on a human.** Any change to the rules of a human-spendable ScopedWallet (new cap, new allowlist, new owner) emits a Move event the human's UI watches — the human sees "your employer agent adjusted your scope" on the next wallet open, not months later on audit.

The design intent, in one line: **maximum empowerment for agents, uncrossable floor for humans, one set of primitives for both.**

---

## Agent identity: TypeDB unit + Sui ScopedWallet

In `one.ie` an agent is *two things at once*, joined by one attribute:

| Layer | What | Lives in | What it's for |
| --- | --- | --- | --- |
| Off-chain identity | `unit(unit-kind="agent")` | TypeDB (via the Better Auth adapter — see `wallet.md` Phase 2) | Discovery, `uid`, API key, membership, role, ownership |
| On-chain authority | `ScopedWallet<T>` (or capability) | Sui | Funds, limits, pause, revoke, audit trail |
| The join | `wallet` attribute on the unit | TypeDB → holds the `ScopedWallet` object ID | Lets any party resolve agent → wallet with one query |

Birth flow (aligns with `src/lib/human-unit.ts` pattern — same `ensureUnit` helper, `unit-kind: "agent"`):

1. User picks a pattern (co-sign / scoped / capability). One user tx mints the on-chain object.
2. `ensureAgentUnit(uid, { ...meta, wallet: scopedWalletObjectId })` creates the TypeDB `unit` and its personal `group`, sets membership so the human is `chairman` of the agent's group.
3. Issue API key for the agent (`src/lib/api-key.ts` — PBKDF2-SHA256, server stores hash only).
4. Agent boots, reads its `uid` from `~/.vault.age [agents/<name>]`, queries TypeDB for `unit { uid: $uid } owns wallet $w` → learns its `ScopedWallet` object ID → self-verifies that the on-chain object's scope matches the charter.

This closes the "where does the agent's ScopedWallet ID come from" question: the TypeDB unit is the registry. No extra on-chain `AgentRegistry` object needed; the adapter is already the canonical catalogue.

## Where the agent's own key lives

Agents on the Mac: the same SE-rooted pattern, one step down. Options from strictest to most convenient:

- **Owner-PRF-wrapped (recommended for new agents)** — at spawn time, the owner derives `agent_kek = HKDF(owner_prf, "agent-key:{uid}:v1")`, encrypts the agent's randomly-generated seed with `agent_kek`, stores ciphertext in D1 (or a Workers secret keyed by uid). Agent boots, fetches its ciphertext, decrypts using a short-lived owner-signed unlock token issued at last spawn/restart. Loss of D1 → owner re-derives any agent. Loss of owner biometric → BIP39 paper recovers PRF → recovers every agent. **No master seed (`SUI_SEED`) anywhere.**
- **Session SE identity** — a separate `age-plugin-se` identity with `biometry-any`, dedicated to one agent. User unlocks once per session via Touch ID. Niche; use when the agent runs only on the owner's Mac.
- **Scoped age identity** inside `~/.vault.age` under an `[agents/<name>]` section — plain keypair, pulled by `envr` (local dev) on agent startup. Local-only.
- **Cloudflare Worker secret** for always-on server-side agents — agent key stored as a Workers secret, scoped per-worker (one agent → one secret). The secret was provisioned by the owner at spawn time; the worker never sees `SUI_SEED`.

Pick owner-PRF-wrapped for any agent intended to run in production. Key compromise on the host doesn't escalate to other agents (different KEKs); seed loss is recoverable by the owner.

---

## Onboarding — from spawn to operating

An agent can't Touch ID its own key. The biometric root that secures humans doesn't apply — agents are autonomous by definition. We swap one constraint for another: **Move consensus replaces biometric as the gate on what the key can do.** The key itself is "unprotected" in the sense that it sits in platform storage with no biometric wrapper, but its *authority* is bounded by Move caps. Key compromise = attacker can do exactly what the agent could already do = nothing worse than expected.

Onboarding is three steps.

### 1. Spawn (on-chain, atomic)

One Move transaction creates the agent:

```move
scoped_wallet::spawn_child<T>(
  parent_w,
  child_pubkey,        // derivation: see below
  cap,                 // daily cap, allowed recipients, allowed methods, expiry
  allowlist,
  seed                 // funding in the same tx
)
```

The tx emits a Sui event carrying pubkey + unit metadata. `api.one.ie` WsHub listens, calls `ensureAgentUnit(pubkey, { parent, caps })`, writes the TypeDB unit. **The agent exists in the system before it boots.**

### 2. Register (off-chain, one-shot)

First action after boot — sign-in by signature, no separate API key:

```
POST /api/agent/register
body: { pubkey, nonce, signature: sign(nonce, privkey) }
→ { session_token, llm_endpoint, typedb_endpoint }
```

The keypair IS the credential (same pattern as SIWE/SIWS). Backend verifies the signature against the TypeDB unit written in step 1, issues a short-lived session token (15 min, rotated by re-signing). No vault lookup, no API-key distribution ceremony.

### 3. Operate (ongoing)

The agent now has:

- **Sui keypair** → on-chain signing, bounded by Move caps
- **Session token** → one.ie backend calls, scoped to the agent's caps, refreshable by re-signing
- **LLM access** → via a metered proxy that bills the agent's `ScopedWallet<T>` per call, or a scoped `.env.agent` inherited from parent

### Where each credential lives

| Credential | Prod storage | Dev storage | What gates it |
|---|---|---|---|
| Agent Ed25519 seed | owner-PRF-wrapped, ciphertext in D1 `agent_wallet`; fetched at boot via `POST /api/agents/:uid/unlock` (see `one.ie/docs/agent-boot-unlock.md`) | `~/.vault.age` `[agents/<name>]` | Move consensus on *authority* (not local access) |
| Session token | Worker memory, 15-min TTL | Same | Expiry |
| LLM API key (shared) | `.env.agent` via dotenvx (read-only scope) | Same | Pattern C off-chain mirror |
| one.ie API access | *no separate credential* | *no separate credential* | Signature over nonce |
| Owner API key (rotatable, Gap 4) | HKDF-derived at Touch ID; hash in D1 `owner_key` with `version`, `expires_at`, `role`, `group_id`; rotated via `POST /api/auth/owner-key-versions` | Same (derived from PRF on demand, never persisted) | D1 expiry check on every auth cache miss; owner-tier only |
| Chairman multisig bundle (Gap 3) | Per-group threshold + member `member_credentials` JSON in D1 `chairman_multisig`; asserted via `POST /api/auth/passkey/assert` batched-N flow | Same schema, test group | N-of-M biometric assertions within 5-min window; `verifyAuthenticationResponse` per member credential |

No credential on the agent side needs to be "held securely" in the user sense. The seed is in platform storage because it has to be somewhere; its compromise doesn't escalate because Move caps enforce the blast radius.

### Deriving the agent's wallet — two modes

**Random** — `crypto.getRandomValues(32)`; independent. Used for top-level agents a human spawns directly.

**Deterministic** — `hkdf(parentSeed, salt = "${parentUnit}:${nonce}:child")`; used in Pattern D peer-spawn. Benefit: parent can recover a lost child wallet from its own seed + the spawn nonce recorded on-chain. Cost: parent-key compromise cascades to descendants — already the accepted blast radius (children are scoped under parent's caps anyway).

Choose deterministic when the parent is accountable for the subtree (most peer-spawn cases). Choose random when agents are independent economic actors.

### Who pays for LLM calls — two models

**Inherit** — parent shares `.env.agent` with child; LLM calls hit parent's vendor bill. Simple; no economic fitness — expensive children don't die off.

**Meter** — `api.one.ie/llm` proxy bills the caller's `ScopedWallet<T>` per token. Agent pays its own way; runs out of funds → pauses until topped up. Natural fit for pheromone-learning: agents that produce value get funded, agents that don't starve.

Meter is where the architecture wants to land; inherit is the migration path.

### Agents spawning agents, recursively

Every descendant runs the same onboarding. Human's Touch ID fires **once** — to mint the top-level ScopedWallet. Every sub-agent inherits bounded authority via Move; no human gate on sub-spawns, no human loss of sleep, because caps are consensus-enforced all the way down.

```
market-maker (parent, owned by human)
  └─ spawn_child<SUI>(worker-42_pubkey, cap: $10/day, allowlist: [quoter, executor])
       ├─ TypeDB unit written for worker-42
       ├─ worker-42 Worker boots with deterministically-derived seed
       ├─ worker-42 signs nonce → /api/agent/register → session token
       └─ worker-42 can spawn its own grandchildren under its own caps
```

---

## UX — co-sign approval flow

1. Agent drafts. Agent POSTs the partial-signed tx + a human-readable summary to a pending-tx store (Workers KV). Sends a notification (push / email / webhook) with:
   - Agent name
   - Action in one sentence
   - Exact amount / recipient / object
   - Approve link → `/u/approve/<id>`
2. User opens the page. Sees the summary **re-derived from the tx bytes by the user's UI** (never trust the agent's claim) + Reject button. Touch ID fires on Approve.
3. `MultiSigPublicKey.combinePartialSignatures()` runs client-side. Submitted, sponsored, done.
4. Approval window: 5 min default. Expired = auto-reject.
5. Every approval and rejection emits a Move event — on-chain audit trail.

No "blind approve." The summary renderer runs on both sides from the same tx bytes; if they don't match, the UI refuses.

---

## Implementation in `one.ie`

- **Co-sign** — `wallet.md` Phase 7. Ships as a pure TS extension of Phase 4 (multisig already wired).
- **Scoped autonomy** — `wallet.md` Phase 8+. Pick two or three initial agent jobs (bill pay, domain renewal, liquidity rebalance), write one `ScopedWallet` module, reuse for all.
- **Delegated capability** — `wallet.md` Phase 9+. Only when a bounded task doesn't fit the scoped-wallet shape.

## Lifecycle

This doc gives the *patterns* (how authority is shaped). `lifecycle.md` gives the *time dimension* — one agent from conception through retirement, every transition a single user-signed tx on-chain.

---

## Security properties

- **Agent cannot exceed scope** — consensus checks every action, regardless of whether the owner is human or agent
- **Agent cannot spend during pause** — owner (human *or* agent) sets `paused=true`, consensus refuses
- **Agent can be revoked instantly** — owner burns the `ScopedWallet` or `Capability`; future signatures become inert
- **Every action is auditable on-chain** — no off-chain "trust me" logs, at any depth of the ownership tree
- **Key compromise ≠ tree-funds loss** — compromised key moves at most its ScopedWallet's remaining daily-cap window before the parent (human or agent) pauses and revokes
- **Human's biometric root is non-transferable** — Secure Enclave + finger, by physics; no agent, no sub-agent, no ownership chain can produce the human's signature
- **Human-readable summary is re-derived by the reviewer's UI** from tx bytes, not signer-provided — prevents a "says $10, actually $10k" attack whether the reviewer is a human (Touch ID) or an agent (co-sign across peers)
- **Dead-man's switch cascades** — silence from any owner auto-pauses the subtree below it, so an abandoned branch can't keep draining
- **Fleet exposure visible per human** — `daily_cap` summed across every ScopedWallet rooted transitively in the human's identity; total worst-case is always one query away

---

## Two authority layers — complementary

Move caps and the routing substrate both constrain what an agent can do. Neither is complete alone.

| Layer | Enforced by | How | Scope |
|-------|-------------|-----|-------|
| **On-chain (Move)** | Consensus | Entry function checks cap, allowlist, pause — in-scope executes, out-of-scope aborts. Instantaneous. Binary. | What the agent can *sign* |
| **Off-chain (routing)** | Substrate `warn()` | Failed signals accumulate resistance. When resistance overwhelms strength → toxic → signals dissolve before reaching the agent. Cumulative. Probabilistic. | What the substrate *routes to* the agent |

A rogue agent hits Move first: consensus rejects out-of-scope actions immediately. It then hits the routing formula: consistent failures build resistance until `isToxic()` fires and the agent becomes invisible to the substrate — without anyone writing a rule.

```
Move:     in-scope? → executes. out-of-scope? → aborts. (instantaneous, binary)
Routing:  warn() → resistance → isToxic() → dissolve. (cumulative, <0.001ms per check)
```

Redundancy is the point. A compromised agent that finds a Move loophole still fades from traffic. A fully-scoped agent that keeps returning no result still triggers `warn()` and routes around itself. Both layers are independent. Both always on.

---

## What this replaces

- "Trust me" agent architectures (OAuth-style delegated tokens)
- Hot wallet private keys handed to bots
- Per-agent custom custody solutions
- Approval fatigue — co-sign for unusual, autonomy for routine, peer ownership for machine-speed fleets
- Off-chain rule engines that say *should* instead of *can*
- Hierarchy-as-architecture — the old assumption that humans must be at every root. Here, humans are at the root of *their own identity*, not of every ownership tree. Agents can be roots of their own trees, bounded by whatever capital and cap they hold.

---

## Self-audit (per agent)

- [ ] Agent has its own keypair; never reuses any passkey, human or agent
- [ ] Agent key lives in an SE slot or a scoped `~/.vault.age` section, not plaintext
- [ ] Agent operates via co-sign, scoped wallet, capability, or peer ownership — never a raw user-owned wallet
- [ ] Scoped wallets have: daily cap, allowed recipients, pause, revoke
- [ ] Pause + revoke tested — dry drill on testnet, at every depth of the ownership tree the agent lives in
- [ ] On-chain audit trail queryable (Sui explorer URL bookmarked)
- [ ] Notifications fire for every action above an owner-set threshold (owner = human *or* parent agent)
- [ ] Co-sign summary is re-derived from tx bytes on the reviewer's side, compared to signer's claim
- [ ] Key rotation cadence documented (quarterly default)
- [ ] If the agent owns sub-agents: `spawn_child` caps total downstream exposure within the parent's daily cap; tested
- [ ] If the agent owns a human's scope: human's exit path (drain + TypeDB revoke) tested and documented
- [ ] Dead-man's switch heartbeat wired — the agent pings its own owner (or emits `AgentAlive`) on a cadence below the pause threshold
