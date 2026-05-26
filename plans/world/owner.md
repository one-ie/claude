# Owner — the substrate root

> The one human, biometric-bound, from whom all authority in this substrate descends.
> Anthony O'Connell. Apple ID + Secure Enclave. One per substrate. Non-transferable by physics.

This doc names the apex of the trust tree. It locks the role, the key derivation, the bypass rules, the audit obligations, and the recovery path. Every plan in `*.md` and every gate in `one.ie/` ultimately roots here.

**Classifier** (per [`one.ie/one/template-plan.md`](one.ie/one/template-plan.md) §0):
- `mode: full` (variance high, multiple files, security-critical)
- `lifecycle: construction`
- Exit scalar: 6 gap fixes shipped, owner can mint + revoke + audit own actions, agents no longer hold `SUI_SEED`.

---

## The axiom

```
SE root           (Apple Secure Enclave, never leaves chip)
  → Touch ID      (only gesture proving possession)
  → WebAuthn + PRF
  → 32B PRF secret  (deterministic per credential)
  → BIP39 paper backs the same input
```

**Invariants:**

1. **Exactly one `owner` per substrate.** Identified by Sui address registered at first-mint, derived from the owner's PRF: `address = Ed25519(HKDF(owner_prf, "wallet:owner:v1")).toSuiAddress()`. Once registered, the address is the immutable identity check.
2. **Owner is the only role bound to physical hardware.** Every other role (chairman / board / ceo / operator / agent / auditor) lives in the graph and can be granted, revoked, transferred. Owner cannot.
3. **Loss of biometric = BIP39 paper, no third path.** BIP39 reconstructs the seed input that derives PRF on a new device → same address re-derives → recovery completes. No support contact, no admin override, no recovery email.
4. **Owner sits *outside* tenant scopes.** Reads everything by right; acts only when an invariant breaks. Tenant chairmen are root *within their group*; owner is root *over the substrate*.
5. **No master derivation seed.** `SUI_SEED` is removed entirely. Every key in the substrate descends from a PRF (humans) or is generated per-actor (agents) and wrapped under the owner PRF. There is no env var that, if leaked, derives all keys.

**Owner vs. lower roles:**

| Capability | `owner` | `chairman` | `ceo` | `operator` | `agent` |
|---|---|---|---|---|---|
| Bypass scope/network/sensitivity gates | ✅ | ❌ | ❌ | ❌ | ❌ |
| Mint root-tier keys | ✅ | ❌ | ❌ | ❌ | ❌ |
| Edit `role-check.ts` matrix at runtime | ❌ | ❌ | ❌ | ❌ | ❌ |
| Bypass tier rate limits | ❌ | ❌ | ❌ | ❌ | ❌ |
| Escape audit log | ❌ | ❌ | ❌ | ❌ | ❌ |
| Bound to one specific human | ✅ (Anthony O'Connell) | ❌ (transferable) | ❌ | ❌ | ❌ |

Owner is god *for what god is allowed to be*: the policy author, not the law-of-physics override.

---

## The algebra

Every key in the substrate traces back to a biometric — directly (humans) or transitively (agents, whose seed was authorized at creation by a biometric).

```
PRF secret (32B)
  → HKDF-SHA256(prf, info="api-key:{role}:{group}:{version}")
  → 32B key bytes
  → bearer token in Authorization header
```

**Properties:**

- **Deterministic.** Same biometric + same context always derives the same key. *Re-derivable, not retrievable.*
- **No server-side secret.** Server stores `hash(key)` only — like a password hash. Server compromise leaks nothing usable.
- **Recovery already exists.** Lose Mac → BIP39 paper rebuilds seed → rebuilds PRF → rebuilds key. Same path as the wallet seed (per [`passkeys.md`](passkeys.md)).
- **Per-role, per-group, per-version.** Rotation = bump `version`, re-register the new hash. Old key valid until its `expires-at`; new key valid from its `issued-at`. Both live during the cutover window.

**Reach across the graph — every actor has a wallet, every wallet has a spending cap.**

| Actor | API key | Wallet seed | Spending cap | Notes |
|---|---|---|---|---|
| Substrate owner (you) | `HKDF(your_prf, "api-key:owner:v1")` | `HKDF(your_prf, "wallet:owner:v1")` | unbounded (you set everyone else's) | One per substrate. Recovers via BIP39. |
| Enterprise chairman | `HKDF(their_prf, "api-key:chairman:g:acme:v1")` | `HKDF(their_prf, "wallet:chairman:g:acme:v1")` | bounded by group treasury | Root within `g:acme`. |
| Operator inside Acme | `HKDF(their_prf, "api-key:operator:g:acme:v1")` | `HKDF(their_prf, "wallet:operator:g:acme:v1")` | bounded by chairman | Their biometric, scoped to role + group. |
| Agent | `HKDF(agent_seed, "api-key:agent:v1")` where `agent_seed = randomBytes(32)` at spawn | `HKDF(agent_seed, "wallet:agent:v1")` | bounded by parent's remaining cap | Per-agent random seed, encrypted under owner PRF, ciphertext in D1. See gap 1. |
| Sub-agent (peer-spawned) | derived from parent agent's seed: `HKDF(parent_seed, "agent:{nonce}:child:api-key")` | `HKDF(parent_seed, "agent:{nonce}:child:wallet")` | bounded by parent agent's cap | Recursive spawning, machine-speed, no biometric per spawn. See [`agents.md`](agents.md) Pattern D. |
| Federation bridge | co-derived (both sides) | n/a — bridges don't hold funds | n/a | Cross-substrate trust handshake. See gap 6. |

**Invariant — the cap tree:** `child.cap ≤ parent.remaining_cap` at every spawn, enforced by Move consensus. A grandchild's spending decrements its parent's remaining, which decrements its grandparent's remaining, all the way up to the human at the root. The tree is *auditable arithmetic*, not a policy promise.

---

## Owner identity vs the consumer wallet

The owner has **one address, two surfaces**: the consumer `/u` wallet and the owner role bearer derive from the same root, but only one of them sets the address.

| Concern | Source | Bound to |
|---|---|---|
| **Owner address** (the immutable identity check) | The existing `/u` wallet seed — `crypto.getRandomValues(32)` per [`wallet.md`](wallet.md) State 1, then PRF-wrapped at State 2 | Same address as the user already sees in `/u`. No second wallet. |
| **Owner API key** | `HKDF(owner_prf, "api-key:owner:v1")` | Different key, same biometric gate. Bearer in `Authorization` header. Server stores hash only. |
| **Agent KEKs** | `HKDF(owner_prf, "agent-key:{uid}:v1")` | Wraps each agent's seed before D1 storage. |
| **Multi-chain** | `HKDF(owner_prf, "wallet:{chain}")` per [`passkeys.md`](passkeys.md) | Independent per-chain keypairs. |

**Why the wallet seed is random, not PRF-derived:** the consumer wallet shipped first and is already in production with random seeds. Forcing it to derive from PRF would (a) change every existing user's address (catastrophic), and (b) require the seed to be re-derivable on every sign, which adds latency without adding safety — once the seed is wrapped under PRF (State 2), the security property is identical. The PRF *wraps* the random seed; it doesn't *generate* it. This matches the algebra in `passkeys.md` exactly — owner is just one more salt on the same PRF.

**At first-mint, the substrate registers your `/u` wallet's address as the owner address.** From that point forward, owner-tier assertions verify: "the WebAuthn assertion's credential ID resolves to a passkey that wraps a seed whose Ed25519 derivation produces the registered owner address." One round-trip, no ambiguity.

---

## Bootstrap — first-mint without a race

**Decision:** the substrate operator (you) pre-seeds the expected owner address as a deploy-time env var. First-mint accepts only assertions from a credential whose derived address matches.

```
# one.ie/.env (owner machine; never committed)
OWNER_EXPECTED_ADDRESS = "0x...your-/u-wallet-address..."
```

```ts
// /api/auth/passkey/assert.ts (first-mint branch)
const isFirstMint = (await db.query("SELECT count(*) FROM owner_key").first()).count === 0
if (isFirstMint) {
  if (assertedAddress !== env.OWNER_EXPECTED_ADDRESS) {
    return new Response("first-mint address mismatch", { status: 403 })
  }
  // mint, register hash, lock owner identity, burn first-mint privilege
}
```

**Properties:**
- **No race.** Anyone hitting the endpoint before you registers nothing — their address won't match `OWNER_EXPECTED_ADDRESS`.
- **No second source of truth.** The env var only gates the *first* mint. After that, the registered address in D1 (and on Sui — see threat model) is authoritative.
- **Recovery.** BIP39 paper restores the seed → restores the address → matches `OWNER_EXPECTED_ADDRESS` again on a fresh deploy. Same identity, no re-registration ceremony.
- **Federation.** Each substrate has its own `OWNER_EXPECTED_ADDRESS`. Federation bridges hold each substrate's expected address as a constant of the trust handshake.

**On-chain pinning (hardens against D1 wipe):** at first-mint, the substrate also publishes a `SubstrateOwner` Move object whose `owner: address` field is set once and never written again. Reads of "who is owner" prefer the on-chain object over D1 — D1 wipe loses audit history but cannot transfer the role.

---

## Recursive spawning

The architecture allows arbitrary depth without a human in the loop after the root. Touch ID fires **once** — when the human spawns the top-level agent. Every descendant spawn is a parent agent's signature, bounded by the parent's own cap.

```
Owner (Anthony, Touch ID once)
  └─ market-maker (cap: $100k/day)              [human-spawned, Touch ID]
       ├─ worker-42  (cap: $200/day)            [agent-spawned, no biometric]
       │    ├─ scout-7   (cap: $20/day)         [agent-spawned, no biometric]
       │    └─ executor (cap: $100/day)         [agent-spawned, no biometric]
       └─ worker-43  (cap: $200/day)
            └─ ... (any depth, same pattern)
```

**Properties:**
- **Machine-speed spawning.** A parent agent with budget can spawn 1000 children in a second. Every spawn is a Move transaction, gas-sponsored, atomic.
- **Per-spawn keypair generation.** Child key = `HKDF(parent_seed, "agent:{nonce}:child")` — deterministic from parent + nonce, parent can recover/audit any descendant's key from its own seed + the spawn nonce recorded on-chain.
- **Cap inheritance, not duplication.** Parent cap is debited at spawn time by the child's cap allocation. If child returns funds, parent's remaining cap goes back up. If child is revoked, child's remaining cap returns to parent.
- **Max depth: 8 levels.** Move resolves the cap chain at each spend; deep chains burn gas. `spawn_child` aborts if `depth(parent) >= 8`. Practical limit; raise only if real fleets need it.
- **Pause cascades down.** Pause any node → every descendant freezes via consensus. One tx per immediate child, then the pause propagates by Move event.
- **Dead-man's switch cascades down.** Silence at any node freezes the subtree below it (per [`agents.md`](agents.md) §Safety floor and [`lifecycle.md`](lifecycle.md) §Dead-man's switch).
- **Human exposure is the sum across the tree.** `/u/fleet` shows the human's total worst-case daily loss = sum of `cap` across every ScopedWallet rooted transitively in their address.

**Compliance angle:** an enterprise chairman runs the same recursive shape inside their group. Owner sits outside. Compliance auditors can read the tree at any depth via `auditor` role.

---

## Spending caps

Spending caps are **Move objects on-chain**, not policy in code. They are the on-chain representation of bounded autonomy.

```move
struct Cap has key {
    id: UID,
    owner: address,           // human or parent agent
    spender: address,         // the actor this cap is for
    daily_limit: u64,         // resets every 24h
    spent_today: u64,
    day_epoch: u64,
    allowed_recipients: vector<address>,
    paused: bool,
    parent_cap: Option<ID>,   // None for root (human-owned), Some for child caps
    expires_epoch: u64,       // optional TTL
}
```

**Invariants enforced by consensus:**
- `spent_today + amount ≤ daily_limit` — every spend checked
- `recipient ∈ allowed_recipients` — allowlist enforced
- `!paused` — owner can freeze instantly
- `now < expires_epoch` — auto-expire if TTL set
- `child.daily_limit ≤ parent.remaining_today` at spawn — cap tree invariant

**Cap operations** (each is one entry function, one tx):
- `mint(owner, spender, daily_limit, allowlist)` — owner-signed, top-level
- `spawn_child(parent, child_pubkey, child_limit, ...)` — parent-signed, decrements parent.remaining
- `pause` / `unpause` — owner-signed
- `revoke` — owner-signed; remaining funds return upward
- `rotate_spender(cap, new_pubkey)` — owner-signed; key rotation, cap unchanged
- `extend_expiry` / `set_limit` — owner-signed; tighten or relax
- `ping(cap)` — heartbeat, refreshes `last_owner_ping`

The same `Cap` shape works for every actor in the substrate. Humans set caps for agents; agents set caps for sub-agents; enterprise chairmen set caps for employees; everything bottoms out at consensus arithmetic. *No off-chain "rules engine" anywhere in the system.*

---

## The six gaps

Each gap is a load-bearing fix. Listed in dependency order: 1 must land before 5 means anything; 2 must land alongside 1 to keep the bypass auditable.

### Gap 1 — `SUI_SEED` is god-mode material in `.env`

**Today:** `SUI_SEED` (32-byte base64) sits in `.env` and is shipped to every CF Worker that needs to derive an agent keypair. Whoever holds the env var can derive any agent's key.

**Fix:** Stop putting `SUI_SEED` in agent workers. Owner pre-derives each agent's key at creation time (one biometric tap), registers `hash(key)` to D1, and provisions only that one key into the agent's worker env. The seed lives only in the owner's biometric-gated key store on the owner's machine.

**Shipped files (v1 closed):**
- `one.ie/src/lib/sui.ts` — `deriveKeypair`/`addressFor` removed (sys-201); JSDoc marks Gap 1 status.
- `one.ie/src/lib/owner-key.ts` — `deriveAgentKEK(prf,uid)` / `deriveSyncKEK(prf)` / `deriveOwnerAPIKey(prf)`; worker guard.
- `one.ie/src/pages/api/agents/register-owner.ts` — owner-only POST; stores pre-wrapped ciphertext in D1 `agent_wallet`.
- `one.ie/src/pages/api/agents/[uid]/unlock.ts` — agent-bearer auth; HMAC-signed 60s token.
- `one.ie/src/pages/api/agents/[uid]/unwrap.ts` — proxies to owner-daemon for PRF unwrap.
- `one.ie/nanoclaw/src/lib/agent-key-load.ts` — `loadAgentToken()` with exp-backoff retry.
- `one.ie/nanoclaw/src/lib/boot.ts` — `ensureAgentKeypair()` full unlock → unwrap → Ed25519Keypair.
- `apps/owner-daemon/` (workspace root) — Bun.serve daemon; V2: audit log + per-bearer rate limit.
- `com.tonyoconnell.owner-daemon.plist` (workspace root) — launchctl auto-start.
- `one.ie/migrations/0031_agent_wallet.sql` — `agent_wallet (uid PK, ciphertext, iv, kdf_version, address, created_at, expires_at)`.
- `one.ie/docs/agent-boot-unlock.md`, `one.ie/docs/owner-daemon-runbook.md`, `one.ie/docs/owner-recovery-runbook.md`.

**Acceptance:** `grep -r "SUI_SEED" one.ie/nanoclaw one.ie/gateway one.ie/workers` returns nothing. ✅ verified.

### Gap 2 — Owner actions are invisible to audit by default

**Today:** Bypass would mean owner-tier signals skip every gate, including the gates that log.

**Fix:** Every owner-tier action emits `audit:owner:{action}` to D1 + TypeDB *before* the bypass executes. The bypass is recorded; the audit can't be bypassed.

**Files:**
- `one.ie/src/pages/api/signal.ts` — at the top of the gate stack, branch on `auth.role === 'owner'`, emit `audit:owner:signal`, then bypass.
- `one.ie/src/lib/role-check.ts` — `roleCheck()` wrapper that emits an audit signal for any owner-tier allow.
- `one.ie/src/engine/adl-cache.ts` — extend `audit()` to accept owner bypass entries.
- `migrations/00XX_owner_audit.sql` — new D1 table `owner_audit (ts, action, sender, receiver, gate, decision, payload_hash, payload_redacted)`.

**Schema details:**
- `payload_hash` — sha256 of the full payload (tamper evidence). 32 bytes hex.
- `payload_redacted` — JSON with PII / secrets stripped (readable trail). Redaction policy in `src/lib/audit-redact.ts`. Strip: bearer tokens, passkey credIds, BIP39 fragments, raw seeds. Keep: receiver, action, amount, group scope.
- Both stored. Hash for forensic integrity, redacted for human review. Auditor role can read both; owner sees own log too.

**Enforcement modes** (controlled by env `OWNER_AUDIT_MODE = audit | enforce`):
- `audit` (default during gap rollout) — log every owner allow but never block on audit failure (graceful degradation if D1 is slow).
- `enforce` (after gap is stable) — owner allow blocked if audit emit fails. No bypass without a record, hard rule.

**Acceptance:** every `auth.role === 'owner'` code path is preceded by an audit emit; `SELECT count(*) FROM owner_audit` increases on every owner-tier API call. Mode flip from `audit` → `enforce` requires no code change.

### Gap 3 — No multi-sig recovery for biometric+paper compromise

**Today:** Single-key recovery. If the biometric and BIP39 paper are both compromised (coercion, theft of safe), no defense.

**Fix:** Out of scope for the substrate owner (single-key by design — that's the price of being the apex). Mandatory for tenant chairmen who hold sensitive group state. Tenants opt their `chairman` role into N-of-M multi-sig where each board member's biometric is one share. Reconstruction requires N biometric assertions from N different humans.

**Shipped files (v1+v2 closed):**
- `one.ie/src/lib/role-check.ts` — `MultisigRequirement = false | {n, m}` type exported.
- `one.ie/src/pages/api/groups/[gid]/multisig.ts` — POST/GET; chairman-or-owner UPSERT; validates n≤m, m≤50, members.length===m.
- `one.ie/src/pages/api/auth/passkey/assert.ts` — batched-N flow (`action: 'multisig-action'`); V2: real `verifyAuthenticationResponse` from `@simplewebauthn/server`; `member_credentials` requires `pubKey` (COSE base64url).
- `one.ie/migrations/0033_chairman_multisig.sql` — `chairman_multisig (group_id PK, threshold_n, threshold_m, member_credentials JSON, configured_at, configured_by)`.
- [`compliance.md`](compliance.md) — why, threat model, locked decisions, V1 implementation notes, deferred W3+ shape.
- `one.ie/docs/recon-multisig.md` — WebAuthn multi-assertion timing, Sui multisig threshold semantics, 6 field decisions.

**Acceptance:** 11/11 config contract tests pass; assertion-flow tests deferred with 3.s3 (batched N-signature verification blocked on full passkey/assert rework). V3 carry: sign_count tracking for replay protection beyond 5-min bundle TTL. ✅ v1+v2 shipped at rubric 0.80.

### Gap 4 — HKDF context versioning isn't defined

**Today:** Algebra mentions `:{version}` but no rotation policy.

**Fix:** Versioning policy:
- Bump `version` in the HKDF info string → derive new key → register new hash.
- Old key stays valid until its registered `expires-at` (default: 30 days from rotation).
- New key valid from its `issued-at`.
- Both keys accepted during the cutover window. After cutover, old key 401s.
- Rotation cadence: voluntary for owner; scheduled (90-day) for chairman+; immediate on suspected compromise.

**Shipped files (v1 closed):**
- `one.ie/src/lib/api-key.ts` — `deriveKey(prf, role, group, version)` with HKDF info `api-key:{role}:{group}:v{version}`.
- `one.ie/src/pages/api/auth/owner-key-versions.ts` — POST/GET/DELETE (owner-only); UPSERTs D1 `owner_key` rows.
- `one.ie/src/lib/api-auth.ts` — auth middleware slow-path checks `expires_at`; rejects with `auth-fail:owner-key-revoked`.
- `one.ie/migrations/0032_owner_key_versions.sql` — adds `version`, `expires_at`, `role`, `group_id` + 3 indexes; backfills 0028 row to v=1.
- `one.ie/docs/key-rotation.md` — cadence + lifecycle + threat model.

**Acceptance:** Rotation test — derive v1, register, hit endpoint successfully; derive v2, register, both keys work for 5 min; force-expire v1, only v2 works. 9/9 tests pass. ✅

### Gap 5 — Owner bypassing tier rate limits enables self-DOS

**Today:** A runaway script signed with the owner key can DOS the owner's own substrate.

**Fix:** Hard ceiling per-key-hash regardless of role. Owner pays the cost of restraint.

**Files:**
- `one.ie/src/lib/tier-limits.ts` — `OWNER_HARD_CEILING = { perSec: 1000, perDay: 100_000 } as const`. Locked.
- `one.ie/src/lib/metering.ts` — `checkRateCeiling(keyId)` increments + checks both windows. In-memory per-isolate sliding-window (per-second + per-day buckets). Returns `{ok:true} | {ok:false, reason, count, limit, retryAfter}`.
- `one.ie/src/pages/api/signal.ts` — calls `checkRateCeiling(auth.keyId)` BEFORE tier check + role bypass; on `!ok` emits `security:rate-limit:hard-ceiling:{reason}` and returns 429 with code `OWNER_HARD_CEILING_EXCEEDED` + `Retry-After` header.

**Why in-memory (not D1):** D1 round-trip is ~10ms — too slow for a hot-path counter at 1k req/s. Per-isolate counting is imprecise across the CF Worker fleet, but the gate is "no self-DOS via single tight loop" — even imprecise counting catches that. Tier-based monthly limits (the existing `meter` D1 table) remain authoritative for billing.

**Acceptance:** `bunx vitest run src/__tests__/integration/owner-rate-ceiling.test.ts` — 7/7 pass:
- 1000-call burst within 1s → all ok
- 1001st call within 1s → 429 reason=sec-ceiling
- 1500-rps burst → exactly 1000 ok + 500 blocked
- distinct keys → independent buckets
- per-second window resets after rollover
- empty keyId → ungated no-op

### Gap 6 — Federation across substrates needs naming

**Today:** "Exactly one owner per substrate" is clear; behavior across two federated substrates is implied by `paths/bridge` but not stated.

**Fix:** Federation = bridge between two owners' groups. Neither owner is root over the union. Cross-substrate signals carry both substrates' provenance and respect scope on both sides. The receiving substrate's gates run as if the sender were a foreign chairman, not a foreign owner.

**Shipped files (v1+v2 closed):**
- `one.ie/src/pages/api/paths/bridge.ts` — peer assertion + version handshake.
- `one.ie/src/engine/federation.ts` — `inbound()` role downgrade owner→chairman.
- `one.ie/src/pages/.well-known/owner-pubkey.json.ts` — discovery endpoint for peer substrates (V2).
- `one.ie/src/lib/federation-discovery.ts` — `fetchPeerPubkey()` + in-process cache (V2).
- [`federation.md`](federation.md) — V1 protocol spec: handshake, inbound flow, why-chairman, threat model, deferred V3 shape.
- `one.ie/docs/recon-federation.md` — W1 recon: bridge shape, foreign-chairman mapping, 7 field decisions.

**Peer rotation:** when substrate-A's owner rotates (new key version after BIP39 recovery on a fresh device), every existing bridge to substrate-A is invalidated. Bridges carry `peer_owner_address` + `peer_owner_version` at handshake time. On version mismatch, substrate-B drops the signal and emits `federation:bridge:stale`. Re-handshake is one tx per side, owner-signed. *Bridges expire on rotation, by design.*

**Acceptance (partial — full E2E requires second substrate):** inbound downgrade verified in unit tests; discovery endpoint live; peer pubkey cache wired. Full E2E federation test deferred to V3 (needs a second live substrate). ✅ v1+v2 shipped at rubric 0.80.

---

## Five-state owner key lifecycle

Mirrors the wallet lifecycle in [`passkeys.md`](passkeys.md), but for the API key bearer:

| State | Description | Trigger to next |
|---|---|---|
| **0 — Pre-mint** | No owner key registered. Substrate accepts first-mint from any address. The first successful WebAuthn assertion locks owner identity to that credential ID + derived address. | Owner taps Touch ID, derives key, registers hash + address. Substrate burns first-mint privilege. |
| **1 — Active** | Key registered. Owner taps Touch ID per session to derive in-memory; bearer in `Authorization`. | Cache window expires (tab close / process exit). |
| **2 — Cached** | Derived key held in-memory after one Touch ID. | Cache eviction, manual lock, or rotation. |
| **3 — Rotating** | New version registered; old version still valid until `expires-at`. | Cutover window passes. |
| **4 — Revoked** | Old version `expires-at` passed; key returns 401. Hash kept for audit forensics. | (Terminal) |

**Recovery from total Mac loss:** BIP39 paper restores the seed input → PRF re-derives on the new device → same address re-derives → substrate matches incoming address against the registered owner address → grants assertion. New hash for the new key version registered alongside. Old hash kept for forensic audit.

---

## Threat model

| Threat | Defense | Accepted residual |
|---|---|---|
| Server compromise (D1, TypeDB) | Server stores only `hash(key)`; no plaintext keys. | Audit log accessible to attacker (logs are not sensitive). |
| **D1 wipe** (CF accident, migration failure) | Owner address pinned in immutable `SubstrateOwner` Move object on Sui at first-mint; reads prefer on-chain over D1. | Audit history lost; can be re-bootstrapped. |
| CF Worker env leak | Workers hold one scoped key, not `SUI_SEED` (gap 1). | One agent's traffic compromised; blast radius = that agent. |
| Mac stolen, biometric defeated | BIP39 paper recovery from secure physical location. | Window between theft and key rotation; mitigated by rate ceiling (gap 5). |
| Mac + paper both stolen | None for substrate owner (single-key by design). Multi-sig for tenants (gap 3). | Owner accepts catastrophic loss; tenants don't. |
| Coerced biometric | Out of scope. | Substrate owner declines high-coercion environments. |
| Replay of API call | Standard nonce + timestamp on assertion; bearer is short-lived in cache. | None. |
| Federated peer turns hostile | Foreign signals downgraded to `chairman` semantics (gap 6); bridge revocable. | Cross-tenant audit gap until revoke propagates. |
| Compromised LLM emits owner-tier signal on owner's behalf | LLM never holds owner key; LLM emits to its agent's key, which is scoped + bounded. | LLM can DOS its own agent quota; not owner's quota. |

---

## File map — invariants to code

All files shipped and on disk. V2 additions marked.

| Invariant | File | Function |
|---|---|---|
| One owner, address-locked | `one.ie/src/lib/role-check.ts` | `isOwner(addr) === addr === ownerAddress`; `ROLE_RANK owner=7`; `ownerBypass()` helper |
| First-mint bootstrap | `one.ie/src/pages/api/auth/passkey/assert.ts` | `OWNER_EXPECTED_ADDRESS` env gate; batched-N multisig flow (V2: real `verifyAuthenticationResponse`) |
| On-chain owner pin | `one.ie/src/move/one/sources/owner.move` | `SubstrateOwner` Move object, pkg `0x4dfa9cc1…220d` v3, pin `0x38a8f796…dde71` |
| Tony's role pivot | `one.ie/migrations/typedb/0029-tony-chairman-to-owner.tql` | chairman → owner membership; 22 role-grants in `seed-roles.tql` |
| Owner audit redaction | `one.ie/src/lib/audit-redact.ts` | `redactPayload()` — sha256 hash + strip bearer/credId/BIP39/seed/sig |
| Owner audit table | `one.ie/migrations/0030_owner_audit.sql` | D1 `owner_audit` (8 cols + 2 indexes); append-only |
| Owner audit ring | `one.ie/src/engine/adl-cache.ts` | `auditOwner()` / `ownerAuditMode()` / `flushAuditBuffer()` |
| Owner bypass + audit | `one.ie/src/pages/api/signal.ts` | 4 gate sites: network (~L235), sensitivity (~L301), scope-private (~L387), scope-group (~L447) |
| Rate ceiling pre-bypass | `one.ie/src/pages/api/signal.ts` + `one.ie/src/lib/metering.ts` | `checkRateCeiling(keyId)` before tier check + role bypass; `OWNER_HARD_CEILING = {perSec:1000, perDay:100_000}` |
| Per-agent key registration | `one.ie/src/pages/api/agents/register-owner.ts` | Owner-only POST; stores pre-wrapped ciphertext in D1 `agent_wallet` |
| Agent wallet D1 table | `one.ie/migrations/0031_agent_wallet.sql` | `agent_wallet (uid, ciphertext, iv, kdf_version, address, created_at, expires_at)` |
| Owner PRF → KEK derivation | `one.ie/src/lib/owner-key.ts` | `deriveAgentKEK(prf,uid)` / `deriveSyncKEK(prf)` / `deriveOwnerAPIKey(prf)`; worker guard |
| Boot-unlock protocol | `one.ie/src/pages/api/agents/[uid]/unlock.ts` | HMAC-signed 60s token; `one.ie/docs/agent-boot-unlock.md` for full spec |
| PRF-unwrap daemon (V2) | `apps/owner-daemon/` (workspace root) | Bun.serve at localhost; `/session/unlock`, `/unwrap`, `/session/status`; audit log to `~/Library/Logs/owner-daemon-audit.jsonl`; per-bearer rate limit 10/min 100/hr |
| Daemon autostart | `com.tonyoconnell.owner-daemon.plist` (workspace root) | launchctl auto-start |
| HKDF context versioning | `one.ie/src/lib/api-key.ts` | `deriveKey(prf, role, group, version)` info=`api-key:{role}:{group}:v{version}` |
| Key version rotation | `one.ie/src/pages/api/auth/owner-key-versions.ts` | POST/GET/DELETE; `migrations/0032_owner_key_versions.sql` |
| Key expiry enforcement | `one.ie/src/lib/api-auth.ts` | Middleware: SELECT D1 `owner_key.expires_at` on PBKDF2 match; reject if expired |
| Key rotation policy | `one.ie/docs/key-rotation.md` | Cadence + lifecycle + threat model |
| Multi-sig config | `one.ie/src/pages/api/groups/[gid]/multisig.ts` | POST/GET; `migrations/0033_chairman_multisig.sql`; chairman-or-owner UPSERT |
| Multi-sig assertion (V2) | `one.ie/src/pages/api/auth/passkey/assert.ts` | Batched-N flow; real `verifyAuthenticationResponse` from `@simplewebauthn/server` |
| Passkey capabilities | `one.ie/src/lib/passkey-capabilities.ts` | PRF feature detection; SigninForm upgrade hint |
| Federation bridge | `one.ie/src/pages/api/paths/bridge.ts` | Peer assertion + version handshake |
| Federation downgrade | `one.ie/src/engine/federation.ts` | `inbound()` role downgrade owner→chairman |
| Owner pubkey discovery (V2) | `one.ie/src/pages/.well-known/owner-pubkey.json.ts` | GET endpoint for peer substrates |
| Peer pubkey cache (V2) | `one.ie/src/lib/federation-discovery.ts` | `fetchPeerPubkey()` + in-process cache |
| Vault holds PRF only, never key | `one.ie/src/components/u/lib/vault/passkey.ts` | PRF unwrap; key computed on demand, never stored |

---

## Build sequence

Six gaps, ordered by dependency. Each is a `mode: full` cycle with W1-W4 waves per [`one.ie/one/template-plan.md`](one.ie/one/template-plan.md). **All six gaps are now shipped at V1+V2.**

1. **Gap 2** ✅ CLOSED v1 rubric 0.8875 — owner audit exists; `OWNER_AUDIT_MODE=audit|enforce` live; every owner-bypass gate emits before short-circuit. Files: `migrations/0030_owner_audit.sql`, `src/lib/audit-redact.ts`, `src/engine/adl-cache.ts`, `src/lib/role-check.ts`, `src/pages/api/signal.ts`.
2. **Gap 1** ✅ CLOSED v1 rubric 0.875 — `SUI_SEED` removed from all worker envs (sys-201); per-agent random seeds wrapped under owner PRF, ciphertext in D1; boot-unlock dance wired; owner-daemon ships (`apps/owner-daemon/`). Files: `migrations/0031_agent_wallet.sql`, `src/lib/owner-key.ts`, `src/pages/api/agents/register-owner.ts`, `src/pages/api/agents/[uid]/unlock.ts`, `src/pages/api/agents/[uid]/unwrap.ts`, `nanoclaw/src/lib/agent-key-load.ts`, `docs/agent-boot-unlock.md`, `docs/owner-daemon-runbook.md`.
3. **Gap 5** ✅ CLOSED v1 rubric 0.9125 — hard ceiling `OWNER_HARD_CEILING = {perSec:1000, perDay:100_000}` before role bypass; 7/7 tests pass. Files: `src/lib/tier-limits.ts`, `src/lib/metering.ts`, `src/pages/api/signal.ts`.
4. **Gap 4** ✅ CLOSED v1 rubric 0.825 — `deriveKey(prf, role, group, version)` with HKDF info string; `POST/GET/DELETE /api/auth/owner-key-versions`; expiry enforced on auth middleware cache miss. Files: `migrations/0032_owner_key_versions.sql`, `src/lib/api-key.ts`, `src/pages/api/auth/owner-key-versions.ts`, `src/lib/api-auth.ts`, `docs/key-rotation.md`.
5. **Gap 3** ✅ CLOSED v1+v2 rubric 0.80 — `chairman_multisig` D1 table; `POST/GET /api/groups/:gid/multisig`; passkey/assert batched-N with real `verifyAuthenticationResponse`; V2 adds `pubKey` (COSE base64url) requirement. Files: `migrations/0033_chairman_multisig.sql`, `src/lib/role-check.ts`, `src/pages/api/groups/[gid]/multisig.ts`, `src/pages/api/auth/passkey/assert.ts`, `compliance.md`.
6. **Gap 6** ✅ CLOSED v1+v2 rubric 0.80 — `paths/bridge.ts` peer assertion + version handshake; `federation.ts` inbound() role downgrade owner→chairman; `.well-known/owner-pubkey.json.ts` discovery; V2 adds `src/lib/federation-discovery.ts` fetchPeerPubkey + cache. Files: `src/pages/api/paths/bridge.ts`, `src/engine/federation.ts`, `src/pages/.well-known/owner-pubkey.json.ts`, `src/lib/federation-discovery.ts`, `federation.md`.

**V3 carries (none blocking):**
- Daemon log rotation (`apps/owner-daemon/` JSONL grows unbounded)
- Daemon mTLS (Astro ↔ daemon currently HMAC-only over localhost HTTP)
- Multisig sign_count tracking (replay protection beyond 5-min bundle TTL)
- Federation V2.2 JWKS publication + signature verify against peer pubkeys

Each cycle ends with a deterministic exit scalar (per [`engine.md`](one.ie/.claude/rules/engine.md) Rule 3):
- Tests passed/total
- Bundle size delta
- New audit row count under synthetic load
- Rate-limit verification
- 401 response on revoked key

---

## See also

- [`mac.md`](mac.md) — hardware root layer + paper recovery hygiene
- [`passkeys.md`](passkeys.md) — 5-state passkey lifecycle, PRF wrap, BIP39 break-glass
- [`secrets.md`](secrets.md) — Keychain + dotenvx + `~/.vault.age`; `SUI_SEED` belongs in vault, not in repo env
- [`agents.md`](agents.md) — 4 patterns for human↔agent transactions; owner sits outside the patterns as the seed-holder
- [`wallet.md`](wallet.md) — wallet phase model; owner key reuses the same envelope encryption pattern
- [`README.md`](README.md) — glossary entry for `owner` to be added on ratification
- `one.ie/src/schema/one.tql` — 6 dimensions; owner role is a value of `membership.role` on a special `g:substrate` group
- `one.ie/src/lib/role-check.ts` — role × action permission matrix
- `one.ie/src/pages/api/signal.ts` — gate stack where owner bypass lives
- `one.ie/CLAUDE.md` — product brief; `## Owner` section shipped with full gap table (6 gaps closed at V1+V2)

---

*One human. One Apple ID. One Secure Enclave. One paper backup.*
*Everything else lives in groups. Groups compose. The graph IS the policy.*
